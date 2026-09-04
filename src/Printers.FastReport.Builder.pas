{ =============================================================================
  Printers.FastReport.Builder - Motor fluente do FastReport (TFastReportProvider)

  Descrição:
  Implementa IReportProvider para o FastReport VCL. Factory fluente
  (TFastReportProvider.New) que carrega um template .fr3, alimenta-o
  exclusivamente com dados do ProvidersORM (IQueryBuilder primário;
  IConnection.ExecuteQuery parametrizado só para ad-hoc) via TfrxDBDataset, e
  emite preview/impressora/PDF.

  Os tipos frx* do FastReport ficam encapsulados nesta camada — a fachada
  Printers.Main e a interface IReportProvider permanecem neutras.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.1.0 (03/08/2026): absorvido de ProvidersORM v2.3.0 para
    `src/Modulos/Printers/FastReport/` (Onda 9.2). Superfície de
    `IReportProvider` inalterada. `uses` actualizados para os nomes v3
    (`Providers.Connection.Interfaces`→`Connections.Interfaces`;
    `Printers.Types`→`Commons.Printers.Types`; `Databases.Interfaces` já
    estava correcto). `EnsureConnection` deixa de fazer fallback a
    `TProviders.DefaultConnection` (fachada `TProviders` ainda não existe em
    v3 — F10 depende de F9, não o contrário) — passa a exigir
    `.Connection(AConn)` explícito, lançando
    `EPrintersConfigurationException`/`ERR_PRINTERS_CONNECTION_NOT_ASSIGNED`
    quando omitido. Nomes de classe/factory preservados.
  Changelog (fonte v2.3.0):
  - 1.0.0 (28/06/2026): Versão inicial — ponte (template .fr3 + Query/DataView + SetText +
    preview/impressora/PDF); LinkBands liga o TfrxDBDataset às bandas de dados após o load.
    AutoBind não se aplica (específico do .rtm legado do ReportBuilder).
  ============================================================================= }

unit Printers.FastReport.Builder;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_FASTREPORT}

uses
{$IF DEFINED(FPC)}
  Classes, SysUtils, Variants,
{$ELSE}
  System.Classes, System.SysUtils, System.Variants,
{$ENDIF}
  frxClass,
  Commons.Printers.Types,
  Printers.Interfaces,
  Connections.Interfaces
{$IFDEF USE_QUERY_BUILDER}
  , Databases.Interfaces
{$ENDIF}
  ;

type
  { Motor fluente do FastReport. Implementa o contrato neutro IReportProvider. }
  TFastReportProvider = class(TInterfacedObject, IReportProvider)
  private
    FConn: IConnection;
    FReport: TfrxReport;
    FOwnsReport: Boolean;
    FPipelineName: string;
    FSQL: string;
    FUseSQL: Boolean;
    FParams: array of Variant;
    FTxtName: array of string;
    FTxtValue: array of string;
    FTemplateFile: string;
    FTemplateLoaded: Boolean;
    FFrxDS: TfrxDataSet;
{$IFDEF USE_QUERY_BUILDER}
    FQuery: IQueryBuilder;
{$ENDIF}
    function EnsureConnection: IConnection;
    procedure EnsureReport;
    procedure EnsureTemplateLoaded;
    procedure ApplyData;
    procedure ApplyTexts;
    procedure LinkBands;
    function PrepareOrRaise: Boolean;
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

{$IFDEF USE_FASTREPORT}

uses
{$IF DEFINED(FPC)}
  DB,
{$ELSE}
  Data.DB,
{$ENDIF}
  frxDBSet,
  frxExportPDF,
  frxBarcode,   // regista TfrxBarCodeView (templates com código de barras)
  Exceptions.Printers,
  Printers.FastReport.Template,
  Printers.FastReport.Pipeline.Db;

{ TFastReportProvider }

constructor TFastReportProvider.Create(const AConn: IConnection);
begin
  inherited Create;
  FConn := AConn;
  FReport := nil;
  FOwnsReport := True;
  FUseSQL := False;
  FTemplateLoaded := False;
end;

destructor TFastReportProvider.Destroy;
begin
  if FOwnsReport and Assigned(FReport) then
    FReport.Free;
  inherited Destroy;
end;

class function TFastReportProvider.New: IReportProvider;
begin
  Result := TFastReportProvider.Create(nil);
end;

class function TFastReportProvider.New(const AConn: IConnection): IReportProvider;
begin
  Result := TFastReportProvider.Create(AConn);
end;

function TFastReportProvider.EnsureConnection: IConnection;
begin
  if FConn = nil then
    raise EPrintersConfigurationException.Create(
      'Conexão não atribuída — chame .Connection(AConn) antes de gerar o relatório.',
      ERR_PRINTERS_CONNECTION_NOT_ASSIGNED, 'EnsureConnection');
  Result := FConn;
end;

procedure TFastReportProvider.EnsureReport;
begin
  if FReport = nil then
  begin
    FReport := TfrxReport.Create(nil);
    FReport.EngineOptions.SilentMode := True;            // headless: sem caixas de erro
    FReport.EngineOptions.UseGlobalDataSetList := True;  // resolve DataSetName na lista global (onde o TfrxDBDataset se regista)
    FOwnsReport := True;
  end;
end;

procedure TFastReportProvider.EnsureTemplateLoaded;
begin
  EnsureReport;
  if FTemplateLoaded then
    Exit;
  if FTemplateFile <> '' then
  begin
    TFastReportTemplate.LoadFromFile(FReport, FTemplateFile);
    FTemplateLoaded := True;
  end;
end;

procedure TFastReportProvider.ApplyData;
var
  LDataSet: TDataSet;
begin
  { No FastReport o dataset tem de estar registado ANTES do LoadFromFile, para a
    banda resolver DataSetName. Por isso aqui só garantimos o report (não o template). }
  EnsureReport;

  { Sem fonte declarada → template auto-suficiente; nada a ligar. }
  if FPipelineName = '' then
    Exit;

  if FUseSQL then
  begin
    if FSQL = '' then
      raise EPrintersDataSourceException.Create('SQL do DataView não informado.',
        ERR_PRINTERS_DATASOURCE_EMPTY, 'ApplyData');
    if Length(FParams) > 0 then
      LDataSet := EnsureConnection.ExecuteQuery(FSQL, FParams)
    else
      LDataSet := EnsureConnection.ExecuteQuery(FSQL);
  end
  else
  begin
{$IFDEF USE_QUERY_BUILDER}
    if FQuery = nil then
      raise EPrintersDataSourceException.Create('IQueryBuilder não informado (use .Query ou .DataView).',
        ERR_PRINTERS_DATASOURCE_EMPTY, 'ApplyData');
    LDataSet := FQuery.Execute;
{$ELSE}
    raise EPrintersDataSourceException.Create('Fonte de dados não informada.',
      ERR_PRINTERS_DATASOURCE_EMPTY, 'ApplyData');
{$ENDIF}
  end;

  FFrxDS := TFastReportDataSet.Build(FReport, LDataSet, FPipelineName);
end;

procedure TFastReportProvider.LinkBands;
var
  P, J: Integer;
  LPage, LObj: TfrxComponent;
begin
  { Liga explicitamente o DataSet às bandas de dados do template. Necessário
    porque, ao carregar o .fr3, a resolução de DataSetName pode ocorrer antes de a
    banda ter o Report (Owner) atribuído, deixando DataSet=nil → 0 linhas.
    Aplica-se a todas as bandas de dados (relatório single-pipeline). }
  if FFrxDS = nil then
    Exit;
  for P := 0 to FReport.PagesCount - 1 do
  begin
    LPage := FReport.Pages[P];
    if LPage = nil then
      Continue;
    for J := 0 to LPage.Objects.Count - 1 do
    begin
      LObj := TfrxComponent(LPage.Objects[J]);
      if LObj is TfrxDataBand then
        TfrxDataBand(LObj).DataSet := FFrxDS;
    end;
  end;
end;

procedure TFastReportProvider.ApplyTexts;
var
  I: Integer;
  LComp: TfrxComponent;
begin
  if (FReport = nil) or (Length(FTxtName) = 0) then
    Exit;
  for I := 0 to High(FTxtName) do
  begin
    LComp := FReport.FindObject(FTxtName[I]);
    if LComp is TfrxMemoView then
      TfrxMemoView(LComp).Text := FTxtValue[I];
  end;
end;

function TFastReportProvider.PrepareOrRaise: Boolean;
begin
  EnsureTemplateLoaded;  // 1) carrega o .fr3 PRIMEIRO (LoadFromFile limpa o report)
  ApplyData;             // 2) cria+regista o dataset DEPOIS (senão é libertado pelo load)
  LinkBands;             // 3) liga o DataSet à banda (resolução explícita)
  ApplyTexts;            // 4) ajusta rótulos por nome (FindObject)
  Result := FReport.PrepareReport;
  if not Result then
    raise EPrintersRenderException.Create('FastReport: PrepareReport devolveu falso.',
      ERR_PRINTERS_RENDER_FAILED, 'PrepareOrRaise');
end;

function TFastReportProvider.Connection(const AConn: IConnection): IReportProvider;
begin
  FConn := AConn;
  Result := Self;
end;

function TFastReportProvider.Template(const AFileName: string): IReportProvider;
begin
  FTemplateFile := AFileName;
  FTemplateLoaded := False;
  Result := Self;
end;

function TFastReportProvider.TemplateStream(const AStream: TStream): IReportProvider;
begin
  EnsureReport;
  TFastReportTemplate.LoadFromStream(FReport, AStream);
  FTemplateLoaded := True;
  Result := Self;
end;

{$IFDEF USE_QUERY_BUILDER}
function TFastReportProvider.Query(const AName: string; const AQuery: IQueryBuilder): IReportProvider;
begin
  FPipelineName := AName;
  FQuery := AQuery;
  FUseSQL := False;
  Result := Self;
end;
{$ENDIF}

function TFastReportProvider.DataView(const AName, ASQL: string): IReportProvider;
begin
  FPipelineName := AName;
  FSQL := ASQL;
  FUseSQL := True;
  Result := Self;
end;

function TFastReportProvider.Param(const AName: string; const AValue: Variant): IReportProvider;
begin
  SetLength(FParams, Length(FParams) + 1);
  FParams[High(FParams)] := AValue;
  Result := Self;
end;

function TFastReportProvider.SetText(const AComponentName, AValue: string): IReportProvider;
begin
  SetLength(FTxtName, Length(FTxtName) + 1);
  SetLength(FTxtValue, Length(FTxtValue) + 1);
  FTxtName[High(FTxtName)] := AComponentName;
  FTxtValue[High(FTxtValue)] := AValue;
  Result := Self;
end;

function TFastReportProvider.AutoBind: IReportProvider;
begin
  { AutoBind (introspeção + tradução de dialeto) é específico do legado .rtm do
    ReportBuilder. Para FastReport, carregue um .fr3 e use Query/DataView. }
  raise EPrintersConfigurationException.Create(
    'AutoBind é específico do ReportBuilder (.rtm legado). No FastReport use Template(.fr3) + Query/DataView.',
    ERR_PRINTERS_ENGINE_NOT_ENABLED, 'AutoBind');
end;

function TFastReportProvider.Build: TComponent;
begin
  ApplyData;             // regista dataset antes do template
  EnsureTemplateLoaded;
  FOwnsReport := False;  // o caller passa a ser dono do TfrxReport
  Result := FReport;
end;

procedure TFastReportProvider.PrintPreview;
begin
  if PrepareOrRaise then
    FReport.ShowPreparedReport;
end;

procedure TFastReportProvider.PrintToPrinter(const ACopies: Integer);
begin
  if PrepareOrRaise then
  begin
    FReport.PrintOptions.ShowDialog := False;
    FReport.PrintOptions.Copies := ACopies;
    FReport.Print;
  end;
end;

procedure TFastReportProvider.SaveToPDF(const AFileName: string);
var
  LPdf: TfrxPDFExport;
begin
  if AFileName = '' then
    raise EPrintersExportException.Create('Nome do ficheiro PDF não informado.',
      ERR_PRINTERS_EXPORT_FILE_NOT_INFORMED, 'SaveToPDF');
  if not PrepareOrRaise then
    Exit;
  LPdf := TfrxPDFExport.Create(nil);
  try
    LPdf.FileName := AFileName;
    LPdf.ShowDialog := False;
    LPdf.ShowProgress := False;
    LPdf.OpenAfterExport := False;
    if not FReport.Export(LPdf) then
      raise EPrintersExportException.Create('FastReport: falha ao exportar PDF.',
        ERR_PRINTERS_EXPORT_FAILED, 'SaveToPDF');
  finally
    LPdf.Free;
  end;
end;

procedure TFastReportProvider.Execute(const AOutput: TReportOutput);
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
