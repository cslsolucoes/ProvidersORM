{ =============================================================================
  Printers.ReportBuilder.Builder - Motor fluente do ReportBuilder (TReportProvider)

  Descrição:
  Implementa IReportProvider para o ReportBuilder 2027. Factory fluente
  (TReportProvider.New) que carrega um template .rtm, alimenta-o exclusivamente
  com dados do ProvidersORM (IQueryBuilder primário; IConnection.ExecuteQuery
  parametrizado só para ad-hoc) via TppDBPipeline, e emite preview/impressora/PDF.

  Os tipos pp* do ReportBuilder ficam encapsulados nesta camada — a fachada
  Printers e a interface IReportProvider permanecem neutras.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.1.0 (03/08/2026): absorvido de ProvidersORM v2.3.0 para
    `src/Modulos/Printers/ReportBuilder/` (Onda 9.2). Superfície de
    `IReportProvider` inalterada. `uses` actualizados para os nomes v3
    (`Providers.Connection.Interfaces`→`Connections.Interfaces`;
    `Printers.Types`→`Commons.Printers.Types`); ganhou um ramo condicional
    dedicado a FPC para `TPath` (antes só `System.IOUtils`, Delphi-only — D.7) via
    `Commons.IOUtils` (F1, ganhou `TPath.GetTempPath` nesta mesma onda).
    `EnsureConnection` deixa de fazer fallback a `TProviders.DefaultConnection`
    (fachada `TProviders` ainda não existe em v3 — F10 depende de F9, não o
    contrário) — passa a exigir `.Connection(AConn)` explícito, lançando
    `EPrintersConfigurationException`/`ERR_PRINTERS_CONNECTION_NOT_ASSIGNED`
    quando omitido (no AutoBind, `EnsureConnection.DatabaseType` também passa
    a exigir conexão prévia). Nomes de classe/factory preservados.
  Changelog (fonte v2.3.0):
  - 1.0.0 (28/06/2026): Versão inicial — M1 ponte (template + Query/DataView + preview/PDF),
    SetText (rótulos por UserName), AutoBind (reaproveitamento de .rtm legado via
    introspeção + tradução de dialeto) e multi-dataset (Query/DataView acumuláveis →
    pipelines homónimos, p/ master-detail/subreports).
  ============================================================================= }

unit Printers.ReportBuilder.Builder;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../../ORM.Defines.inc}

{$IFDEF USE_REPORTBUILDER}

uses
{$IF DEFINED(FPC)}
  Classes, SysUtils, Variants,
{$ELSE}
  System.Classes, System.SysUtils, System.Variants,
{$ENDIF}
  ppReport,
  Commons.Printers.Types,
  Printers.Interfaces,
  Printers.ReportBuilder.AutoBind,   // TReportDataSpecs
  Connections.Interfaces
{$IFDEF USE_QUERY_BUILDER}
  , Databases.Interfaces
{$ENDIF}
  ;

type
  { Fonte de dados nomeada (suporta múltiplas — master-detail / subreports). }
  TReportDataSrc = record
    Name: string;
    UseSQL: Boolean;
    SQL: string;
    Params: array of Variant;
{$IFDEF USE_QUERY_BUILDER}
    Query: IQueryBuilder;
{$ENDIF}
  end;

  { Motor fluente do ReportBuilder. Implementa o contrato neutro IReportProvider. }
  TReportProvider = class(TInterfacedObject, IReportProvider)
  private
    FConn: IConnection;
    FReport: TppReport;
    FOwnsReport: Boolean;
    FSources: array of TReportDataSrc;
    FTxtName: array of string;
    FTxtValue: array of string;
    FTemplateFile: string;
    FTemplateLoaded: Boolean;
    FAutoBind: Boolean;
    FAutoSpecs: TReportDataSpecs;
    function EnsureConnection: IConnection;
    procedure EnsureReport;
    procedure EnsureTemplateLoaded;
    procedure ApplyData;
    procedure ApplyTexts;
    procedure DoRender(const ADeviceType: string);
  public
    constructor Create(const AConn: IConnection = nil); reintroduce;
    destructor Destroy; override;

    class function New: IReportProvider; overload; static;
    class function New(const AConn: IConnection): IReportProvider; overload; static;

    { IReportProvider }
    function Connection(const AConn: IConnection): IReportProvider;
    function Template(const AFileName: string): IReportProvider;
    function TemplateStream(const AStream: TStream): IReportProvider;
{$IFDEF USE_QUERY_BUILDER}
    function Query(const AName: string; const AQuery: IQueryBuilder): IReportProvider;
{$ENDIF}
    function DataView(const AName, ASQL: string): IReportProvider;
    function Param(const AName: string; const AValue: Variant): IReportProvider;
    function SetText(const AComponentName, AValue: string): IReportProvider;
    function AutoBind: IReportProvider;

    function Build: TComponent;
    procedure PrintPreview;
    procedure PrintToPrinter(const ACopies: Integer = 1);
    procedure SaveToPDF(const AFileName: string);
    procedure Execute(const AOutput: TReportOutput);
  end;

{$ENDIF}

implementation

{$IFDEF USE_REPORTBUILDER}

uses
{$IF DEFINED(FPC)}
  DB, Commons.IOUtils,
{$ELSE}
  Data.DB, System.IOUtils,
{$ENDIF}
  ppDBPipe,
  ppClass,     // TppBand / TppComponent (Bands/Objects) para SetText
  ppCtrls,     // TppLabel
  ppMemo,      // TppMemo
  ppBarCod,    // TppDBBarCode (templates legados com código de barras)
  ppDevice,    // TppPrinterDevice / TppTextFileDevice (DeviceType 'Printer')
  ppViewr,     // preview (DeviceType 'Screen')
  ppPDFDevice, // export PDF (DeviceType 'PDF')
  Exceptions.Printers,
  Printers.ReportBuilder.Consts,
  Printers.ReportBuilder.Template,
  Printers.ReportBuilder.Sql.Dialect,
  Printers.ReportBuilder.Pipeline.Db;

{ TReportProvider }

constructor TReportProvider.Create(const AConn: IConnection);
begin
  inherited Create;
  FConn := AConn;
  FReport := nil;
  FOwnsReport := True;
end;

destructor TReportProvider.Destroy;
begin
  if FOwnsReport and Assigned(FReport) then
    FReport.Free;
  inherited Destroy;
end;

class function TReportProvider.New: IReportProvider;
begin
  Result := TReportProvider.Create(nil);
end;

class function TReportProvider.New(const AConn: IConnection): IReportProvider;
begin
  Result := TReportProvider.Create(AConn);
end;

function TReportProvider.EnsureConnection: IConnection;
begin
  if FConn = nil then
    raise EPrintersConfigurationException.Create(
      'Conexão não atribuída — chame .Connection(AConn) antes de gerar o relatório.',
      ERR_PRINTERS_CONNECTION_NOT_ASSIGNED, 'EnsureConnection');
  Result := FConn;
end;

procedure TReportProvider.EnsureReport;
begin
  if FReport = nil then
  begin
    FReport := TppReport.Create(nil);
    FOwnsReport := True;
  end;
end;

procedure TReportProvider.ApplyData;
var
  LDataSet: TDataSet;
  LPipeline: TppDBPipeline;
  I: Integer;
  LSql: string;
begin
  EnsureTemplateLoaded;

  { AutoBind: religa cada (pipeline, SQL) extraído do .rtm legado, traduzindo o
    SQL Access para o dialeto do engine activo. Multi-pipeline (subreports). }
  if FAutoBind then
  begin
    for I := 0 to High(FAutoSpecs) do
    begin
      LSql := TDialect.FromAccess(FAutoSpecs[I].Sql, EnsureConnection.DatabaseType);
      LDataSet := EnsureConnection.ExecuteQuery(LSql);
      LPipeline := TReportDbPipeline.Build(FReport, LDataSet, FAutoSpecs[I].Pipeline);
      if I = 0 then
        FReport.DataPipeline := LPipeline;
    end;
    Exit;
  end;

  { Sem fonte declarada → template auto-suficiente; nada a ligar. }
  if Length(FSources) = 0 then
    Exit;

  { Liga cada fonte nomeada ao pipeline homónimo (suporta master-detail/subreports). }
  for I := 0 to High(FSources) do
  begin
    if FSources[I].UseSQL then
    begin
      if FSources[I].SQL = '' then
        raise EPrintersDataSourceException.Create('SQL do DataView "' + FSources[I].Name + '" não informado.',
          ERR_PRINTERS_DATASOURCE_EMPTY, 'ApplyData');
      if Length(FSources[I].Params) > 0 then
        LDataSet := EnsureConnection.ExecuteQuery(FSources[I].SQL, FSources[I].Params)
      else
        LDataSet := EnsureConnection.ExecuteQuery(FSources[I].SQL);
    end
    else
    begin
{$IFDEF USE_QUERY_BUILDER}
      if FSources[I].Query = nil then
        raise EPrintersDataSourceException.Create('IQueryBuilder não informado para "' + FSources[I].Name + '".',
          ERR_PRINTERS_DATASOURCE_EMPTY, 'ApplyData');
      LDataSet := FSources[I].Query.Execute;
{$ELSE}
      raise EPrintersDataSourceException.Create('Fonte de dados não informada.',
        ERR_PRINTERS_DATASOURCE_EMPTY, 'ApplyData');
{$ENDIF}
    end;

    LPipeline := TReportDbPipeline.Build(FReport, LDataSet, FSources[I].Name);
    if I = 0 then
      FReport.DataPipeline := LPipeline;   // pipeline principal
  end;
end;

procedure TReportProvider.DoRender(const ADeviceType: string);
begin
  ApplyData;
  ApplyTexts;
  FReport.ShowPrintDialog := False;
  FReport.ShowCancelDialog := False;
  FReport.ShowAutoSearchDialog := False;   // headless: nunca abrir diálogo de busca
  FReport.DeviceType := ADeviceType;
  try
    // Print cria o device a partir do DeviceType (Screen/Printer/PDF) e gera.
    // (PrintToDevices assume devices ja anexados — nao serve p/ DeviceType dinamico.)
    FReport.Print;
  except
    on E: Exception do
      raise EPrintersRenderException.Create('Falha ao gerar relatório (' + ADeviceType + '): ' + E.Message,
        ERR_PRINTERS_RENDER_FAILED, 'DoRender');
  end;
end;

function TReportProvider.Connection(const AConn: IConnection): IReportProvider;
begin
  FConn := AConn;
  Result := Self;
end;

function TReportProvider.Template(const AFileName: string): IReportProvider;
begin
  { Carregamento lazy: o AutoBind precisa de processar o ficheiro ANTES de o RB
    o carregar (o .rtm bruto traz classes daADO/RAP não linkadas). }
  FTemplateFile := AFileName;
  FTemplateLoaded := False;
  Result := Self;
end;

function TReportProvider.TemplateStream(const AStream: TStream): IReportProvider;
begin
  EnsureReport;
  TReportTemplate.LoadFromStream(FReport, AStream);
  FTemplateLoaded := True;
  Result := Self;
end;

procedure TReportProvider.EnsureTemplateLoaded;
begin
  EnsureReport;
  if FTemplateLoaded then
    Exit;
  if FTemplateFile <> '' then
  begin
    TReportTemplate.LoadFromFile(FReport, FTemplateFile);
    FTemplateLoaded := True;
  end;
end;

function TReportProvider.AutoBind: IReportProvider;
var
  LCleaned, LTmpFile: string;
  LTmp: TStringList;
begin
  if FTemplateFile = '' then
    raise EPrintersTemplateException.Create('AutoBind requer Template(<.rtm>) antes.',
      ERR_PRINTERS_TEMPLATE_NOT_INFORMED, 'AutoBind');
  EnsureReport;
  // 1. introspeção: extrai (pipeline, SQL) + template limpo
  TReportAutoBind.Parse(FTemplateFile, LCleaned, FAutoSpecs);
  // 2. grava o template limpo (ASCII, sem BOM) e carrega-o (só classes pp* standard)
  LTmpFile := TPath.Combine(TPath.GetTempPath,
    'porm_autobind_' + TPath.GetFileNameWithoutExtension(FTemplateFile) + '.rtm');
  LTmp := TStringList.Create;
  try
    LTmp.Text := LCleaned;
    LTmp.SaveToFile(LTmpFile, TEncoding.ANSI);
  finally
    LTmp.Free;
  end;
  TReportTemplate.LoadFromFile(FReport, LTmpFile);
  FTemplateLoaded := True;
  FAutoBind := True;
  Result := Self;
end;

{$IFDEF USE_QUERY_BUILDER}
function TReportProvider.Query(const AName: string; const AQuery: IQueryBuilder): IReportProvider;
begin
  SetLength(FSources, Length(FSources) + 1);
  FSources[High(FSources)].Name := AName;
  FSources[High(FSources)].Query := AQuery;
  FSources[High(FSources)].UseSQL := False;
  Result := Self;
end;
{$ENDIF}

function TReportProvider.DataView(const AName, ASQL: string): IReportProvider;
begin
  SetLength(FSources, Length(FSources) + 1);
  FSources[High(FSources)].Name := AName;
  FSources[High(FSources)].SQL := ASQL;
  FSources[High(FSources)].UseSQL := True;
  Result := Self;
end;

function TReportProvider.Param(const AName: string; const AValue: Variant): IReportProvider;
var
  K: Integer;
begin
  { O parâmetro associa-se à última fonte declarada (DataView/Query). }
  if Length(FSources) = 0 then
    raise EPrintersDataSourceException.Create('Param sem DataView/Query anterior.',
      ERR_PRINTERS_DATASOURCE_EMPTY, 'Param');
  K := High(FSources);
  SetLength(FSources[K].Params, Length(FSources[K].Params) + 1);
  FSources[K].Params[High(FSources[K].Params)] := AValue;
  Result := Self;
end;

function TReportProvider.SetText(const AComponentName, AValue: string): IReportProvider;
begin
  SetLength(FTxtName, Length(FTxtName) + 1);
  SetLength(FTxtValue, Length(FTxtValue) + 1);
  FTxtName[High(FTxtName)] := AComponentName;
  FTxtValue[High(FTxtValue)] := AValue;
  Result := Self;
end;

procedure TReportProvider.ApplyTexts;
var
  LBandIdx, LObjIdx, I: Integer;
  LBand: TppBand;
  LComp: TppComponent;
begin
  if (FReport = nil) or (Length(FTxtName) = 0) then
    Exit;
  for LBandIdx := 0 to FReport.BandCount - 1 do
  begin
    LBand := FReport.Bands[LBandIdx];
    for LObjIdx := 0 to LBand.ObjectCount - 1 do
    begin
      LComp := LBand.Objects[LObjIdx];
      for I := 0 to High(FTxtName) do
        if SameText(LComp.UserName, FTxtName[I]) then
        begin
          if LComp is TppLabel then
            TppLabel(LComp).Caption := FTxtValue[I]
          else if LComp is TppMemo then
            TppMemo(LComp).Caption := FTxtValue[I];
        end;
    end;
  end;
end;

function TReportProvider.Build: TComponent;
begin
  ApplyData;
  FOwnsReport := False; // o caller passa a ser dono do TppReport
  Result := FReport;
end;

procedure TReportProvider.PrintPreview;
begin
  DoRender(RB_DEVICE_SCREEN);
end;

procedure TReportProvider.PrintToPrinter(const ACopies: Integer);
begin
  { ACopies fica reservado para versão futura (TppPrinterSetup.Copies via ppPrintr);
    o M1 emite 1 job para a impressora default. }
  DoRender(RB_DEVICE_PRINTER);
end;

procedure TReportProvider.SaveToPDF(const AFileName: string);
begin
  if AFileName = '' then
    raise EPrintersExportException.Create('Nome do ficheiro PDF não informado.',
      ERR_PRINTERS_EXPORT_FILE_NOT_INFORMED, 'SaveToPDF');
  EnsureTemplateLoaded;             // carregar ANTES: LoadFromFile sobrescreve TextFileName/OpenFile
  FReport.AllowPrintToFile := True;
  FReport.OpenFile := False;        // não abrir o PDF no visualizador (headless/servidor)
  FReport.TextFileName := AFileName;
  DoRender(RB_DEVICE_PDF);
end;

procedure TReportProvider.Execute(const AOutput: TReportOutput);
begin
  case AOutput of
    roPreview: PrintPreview;
    roPrinter: PrintToPrinter(1);
  else
    raise EPrintersExportException.Create('Para PDF/arquivo use SaveToPDF(<ficheiro>).',
      ERR_PRINTERS_EXPORT_FILE_NOT_INFORMED, 'Execute');
  end;
end;

{$ENDIF}

end.
