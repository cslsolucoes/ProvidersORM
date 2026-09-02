{ =============================================================================
  Printers.QuickReport.Builder - Motor fluente do QuickReport (TQuickReportProvider)

  Descrição:
  Implementa IReportProvider para o QuickReport. Ao contrário do ReportBuilder
  (.rtm) e do FastReport (.fr3), o QuickReport NÃO tem formato de template externo
  — os relatórios são componentes VCL (forms) definidos em código. Por isso este
  motor MONTA o relatório em runtime a partir do TDataSet do ProvidersORM
  (IQueryBuilder primário; IConnection.ExecuteQuery parametrizado para ad-hoc):
  banda de título (opcional, via SetText) + cabeçalho de colunas + banda de
  detalhe com um TQRDBText por campo. Emite preview/impressora/PDF.

  Os tipos QR* ficam encapsulados nesta camada — a fachada Printers.Main e a
  interface IReportProvider permanecem neutras.

  Template()/TemplateStream()/AutoBind() não se aplicam ao QuickReport (sem
  template externo) → lançam exceção explicativa.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.1.0 (03/08/2026): absorvido de ProvidersORM v2.3.0 para
    `src/Modulos/Printers/QuickReport/` (Onda 9.2). Superfície de
    `IReportProvider` inalterada. `uses` actualizados para os nomes v3
    (`Providers.Connection.Interfaces`→`Connections.Interfaces`;
    `Printers.Types`→`Commons.Printers.Types`). `EnsureConnection` deixa de
    fazer fallback a `TProviders.DefaultConnection` (fachada `TProviders`
    ainda não existe em v3 — F10 depende de F9, não o contrário) — passa a
    exigir `.Connection(AConn)` explícito, lançando
    `EPrintersConfigurationException`/`ERR_PRINTERS_CONNECTION_NOT_ASSIGNED`
    (código já reservado para este cenário em `Exceptions.Printers`) quando
    omitido. Nomes de classe/factory preservados tal como estão (decisão do
    owner na Onda 9.0: absorver sem redesenhar).
  Changelog (fonte v2.3.0):
  - 1.0.0 (28/06/2026): Versão inicial — ponte (build-from-dataset + preview/PDF).
  ============================================================================= }

unit Printers.QuickReport.Builder;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../../ORM.Defines.inc}

{$IFDEF USE_QUICKREPORT}

uses
{$IF DEFINED(FPC)}
  Classes, SysUtils, Variants,
{$ELSE}
  System.Classes, System.SysUtils, System.Variants,
{$ENDIF}
  QuickRpt,
  Commons.Printers.Types,
  Printers.Interfaces,
  Connections.Interfaces
{$IFDEF USE_QUERY_BUILDER}
  , Databases.Interfaces
{$ENDIF}
  ;

type
  { Motor fluente do QuickReport. Implementa o contrato neutro IReportProvider. }
  TQuickReportProvider = class(TInterfacedObject, IReportProvider)
  private
    FConn: IConnection;
    FReport: TQuickRep;
    FOwnsReport: Boolean;
    FPipelineName: string;
    FSQL: string;
    FUseSQL: Boolean;
    FTitle: string;
    FParams: array of Variant;
{$IFDEF USE_QUERY_BUILDER}
    FQuery: IQueryBuilder;
{$ENDIF}
    function EnsureConnection: IConnection;
    function FetchDataSet: TObject;
    procedure BuildReport;
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

{$IFDEF USE_QUICKREPORT}

uses
{$IF DEFINED(FPC)}
  DB, Graphics,
{$ELSE}
  Data.DB, Vcl.Graphics,
{$ENDIF}
  QRCtrls,      // TQRLabel / TQRDBText
  qrpdffilt,    // TQRPDFDocumentFilter
  qrexport,     // TQRExportFilter (base do ExportToFilter)
  Exceptions.Printers;

{ TQuickReportProvider }

constructor TQuickReportProvider.Create(const AConn: IConnection);
begin
  inherited Create;
  FConn := AConn;
  FReport := nil;
  FOwnsReport := True;
  FUseSQL := False;
end;

destructor TQuickReportProvider.Destroy;
begin
  if FOwnsReport and Assigned(FReport) then
    FReport.Free;
  inherited Destroy;
end;

class function TQuickReportProvider.New: IReportProvider;
begin
  Result := TQuickReportProvider.Create(nil);
end;

class function TQuickReportProvider.New(const AConn: IConnection): IReportProvider;
begin
  Result := TQuickReportProvider.Create(AConn);
end;

function TQuickReportProvider.EnsureConnection: IConnection;
begin
  if FConn = nil then
    raise EPrintersConfigurationException.Create(
      'Conexão não atribuída — chame .Connection(AConn) antes de gerar o relatório.',
      ERR_PRINTERS_CONNECTION_NOT_ASSIGNED, 'EnsureConnection');
  Result := FConn;
end;

function TQuickReportProvider.FetchDataSet: TObject;
var
  LDataSet: TDataSet;
begin
  if FUseSQL then
  begin
    if FSQL = '' then
      raise EPrintersDataSourceException.Create('SQL do DataView não informado.',
        ERR_PRINTERS_DATASOURCE_EMPTY, 'FetchDataSet');
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
        ERR_PRINTERS_DATASOURCE_EMPTY, 'FetchDataSet');
    LDataSet := FQuery.Execute;
{$ELSE}
    raise EPrintersDataSourceException.Create('Fonte de dados não informada.',
      ERR_PRINTERS_DATASOURCE_EMPTY, 'FetchDataSet');
{$ENDIF}
  end;
  Result := LDataSet;
end;

procedure TQuickReportProvider.BuildReport;
var
  LDataSet: TDataSet;
  LBandHdr, LBandDetail, LBandTitle: TQRCustomBand;
  LLbl: TQRLabel;
  LTxt: TQRDBText;
  I, X, LColW: Integer;
  LField: TField;
begin
  if FReport <> nil then
    FreeAndNil(FReport);
  FReport := TQuickRep.Create(nil);
  FOwnsReport := True;
  FReport.Units := Pixels;   // coordenadas em pixels (consistente com VCL)

  LDataSet := TDataSet(FetchDataSet);
  if LDataSet = nil then
    raise EPrintersDataSourceException.Create('TDataSet nulo do ProvidersORM.',
      ERR_PRINTERS_DATASOURCE_EMPTY, 'BuildReport');

  { Ownership (C-03): o dataset cai em cascata com o relatório. }
  if LDataSet.Owner = nil then
    FReport.InsertComponent(LDataSet);
  if not LDataSet.Active then
    LDataSet.Open;
  FReport.DataSet := LDataSet;

  { Bandas NATIVAS — o QuickReport trata o empilhamento vertical. }
  FReport.Bands.HasColumnHeader := True;
  FReport.Bands.HasDetail := True;

  { Banda de título (opcional). }
  if FTitle <> '' then
  begin
    FReport.Bands.HasTitle := True;
    LBandTitle := FReport.Bands.TitleBand;
    LBandTitle.Height := 40;
    LLbl := TQRLabel.Create(LBandTitle);
    LLbl.Parent := LBandTitle;
    LLbl.Caption := FTitle;
    LLbl.Font.Size := 14;
    LLbl.Font.Style := [fsBold];
    LLbl.Left := 8;
    LLbl.Top := 8;
    LLbl.AutoSize := True;
  end;

  LBandHdr := FReport.Bands.ColumnHeaderBand;
  LBandHdr.Height := 22;
  LBandDetail := FReport.Bands.DetailBand;
  LBandDetail.Height := 20;

  X := 8;
  for I := 0 to LDataSet.FieldCount - 1 do
  begin
    LField := LDataSet.Fields[I];
    LColW := LField.DisplayWidth * 8;           // ~8px por caractere
    if LColW < 60 then LColW := 60;
    if LColW > 360 then LColW := 360;

    LLbl := TQRLabel.Create(LBandHdr);
    LLbl.Parent := LBandHdr;
    LLbl.Caption := LField.DisplayName;
    LLbl.Font.Style := [fsBold];
    LLbl.AutoSize := False;
    LLbl.Left := X;
    LLbl.Top := 4;
    LLbl.Width := LColW;

    LTxt := TQRDBText.Create(LBandDetail);
    LTxt.Parent := LBandDetail;
    LTxt.DataSet := LDataSet;
    LTxt.DataField := LField.FieldName;
    LTxt.AutoSize := False;
    LTxt.Color := clWhite;                      // evitar fundo preto (default clBlack)
    LTxt.Font.Color := clBlack;
    LTxt.Left := X;
    LTxt.Top := 3;
    LTxt.Width := LColW;

    Inc(X, LColW + 8);
  end;
end;

function TQuickReportProvider.Connection(const AConn: IConnection): IReportProvider;
begin
  FConn := AConn;
  Result := Self;
end;

function TQuickReportProvider.Template(const AFileName: string): IReportProvider;
begin
  raise EPrintersTemplateException.Create(
    'QuickReport não usa template externo (.qr). O relatório é montado a partir do ' +
    'dataset (Query/DataView). Use SetText(''titulo'', ...) para o título.',
    ERR_PRINTERS_TEMPLATE_NOT_INFORMED, 'Template');
end;

function TQuickReportProvider.TemplateStream(const AStream: TStream): IReportProvider;
begin
  raise EPrintersTemplateException.Create(
    'QuickReport não usa template externo. O relatório é montado a partir do dataset.',
    ERR_PRINTERS_TEMPLATE_NOT_INFORMED, 'TemplateStream');
end;

{$IFDEF USE_QUERY_BUILDER}
function TQuickReportProvider.Query(const AName: string; const AQuery: IQueryBuilder): IReportProvider;
begin
  FPipelineName := AName;
  FQuery := AQuery;
  FUseSQL := False;
  Result := Self;
end;
{$ENDIF}

function TQuickReportProvider.DataView(const AName, ASQL: string): IReportProvider;
begin
  FPipelineName := AName;
  FSQL := ASQL;
  FUseSQL := True;
  Result := Self;
end;

function TQuickReportProvider.Param(const AName: string; const AValue: Variant): IReportProvider;
begin
  SetLength(FParams, Length(FParams) + 1);
  FParams[High(FParams)] := AValue;
  Result := Self;
end;

function TQuickReportProvider.SetText(const AComponentName, AValue: string): IReportProvider;
begin
  { No QuickReport (build-from-dataset) o único rótulo nomeável é o título. }
  if SameText(AComponentName, 'titulo') or SameText(AComponentName, 'title')
     or SameText(AComponentName, 'ReportTitle') then
    FTitle := AValue;
  Result := Self;
end;

function TQuickReportProvider.AutoBind: IReportProvider;
begin
  raise EPrintersConfigurationException.Create(
    'AutoBind é específico do ReportBuilder (.rtm legado). O QuickReport monta o ' +
    'relatório a partir do dataset (Query/DataView).',
    ERR_PRINTERS_ENGINE_NOT_ENABLED, 'AutoBind');
end;

function TQuickReportProvider.Build: TComponent;
begin
  BuildReport;
  FOwnsReport := False; // o caller passa a ser dono do TQuickRep
  Result := FReport;
end;

procedure TQuickReportProvider.PrintPreview;
begin
  BuildReport;
  FReport.Preview;
end;

procedure TQuickReportProvider.PrintToPrinter(const ACopies: Integer);
begin
  BuildReport;
  FReport.ShowProgress := False;
  FReport.PrinterSettings.Copies := ACopies;
  FReport.Print;
end;

procedure TQuickReportProvider.SaveToPDF(const AFileName: string);
var
  LFilter: TQRPDFDocumentFilter;
begin
  if AFileName = '' then
    raise EPrintersExportException.Create('Nome do ficheiro PDF não informado.',
      ERR_PRINTERS_EXPORT_FILE_NOT_INFORMED, 'SaveToPDF');
  BuildReport;
  FReport.ShowProgress := False;
  LFilter := TQRPDFDocumentFilter.Create(AFileName);
  try
    FReport.ExportToFilter(LFilter);
  finally
    LFilter.Free;
  end;
end;

procedure TQuickReportProvider.Execute(const AOutput: TReportOutput);
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
