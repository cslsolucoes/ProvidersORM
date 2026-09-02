{ =============================================================================
  Printers.FortesReport.Builder - Motor fluente do FortesReport CE (TFortesReportProvider)

  Descrição:
  Implementa IReportProvider para o FortesReport CE (motor RLReport). Tal como o
  QuickReport, o FortesReport NÃO tem formato de template externo (.rtm/.fr3) — os
  relatórios são componentes VCL (TRLReport) definidos em código. Por isso este
  motor MONTA o relatório em runtime a partir do TDataSet do ProvidersORM
  (IQueryBuilder primário; IConnection.ExecuteQuery parametrizado para ad-hoc):
  banda de título (opcional, via SetText) + cabeçalho de colunas + banda de
  detalhe com um TRLDBText por campo. Emite preview/impressora/PDF.

  Modelo de dados RLReport (confirmado nos demos "Com Dados"): o TRLReport tem uma
  propriedade DataSource que dirige a iteração da banda btDetail; cada TRLDBText
  liga-se ao mesmo DataSource + DataField. PDF: Report.Prepare + TRLPDFFilter
  (FileName + FilterPages(Report.Pages)).

  Os tipos RL* ficam encapsulados nesta camada — a fachada Printers.Main e a
  interface IReportProvider permanecem neutras.

  Template()/TemplateStream()/AutoBind() não se aplicam ao FortesReport (sem
  template externo) → lançam exceção explicativa.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.1.0 (03/08/2026): absorvido de ProvidersORM v2.3.0 para
    `src/Modulos/Printers/FortesReport/` (Onda 9.2). Superfície de
    `IReportProvider` inalterada. `uses` actualizados para os nomes v3
    (`Providers.Connection.Interfaces`→`Connections.Interfaces`;
    `Database.QueryBuilder.Interfaces`→`Databases.Interfaces`;
    `Printers.Types`→`Commons.Printers.Types`). `EnsureConnection` deixa de
    fazer fallback a `TProviders.DefaultConnection` (fachada `TProviders`
    ainda não existe em v3 — F10 depende de F9, não o contrário) — passa a
    exigir `.Connection(AConn)` explícito, lançando
    `EPrintersConfigurationException`/`ERR_PRINTERS_CONNECTION_NOT_ASSIGNED`
    quando omitido. Nomes de classe/factory preservados (mesma decisão da
    9.0/9.2 QuickReport).
  Changelog (fonte v2.3.0):
  - 1.0.0 (16/07/2026): Versão inicial — 4.º motor (RLReport), ponte
    build-from-dataset + preview/impressora/PDF, sob a umbrella Printers.
  ============================================================================= }

unit Printers.FortesReport.Builder;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../../ORM.Defines.inc}

{$IFDEF USE_FORTESREPORT}

uses
{$IF DEFINED(FPC)}
  Classes, SysUtils, Variants, DB,
{$ELSE}
  System.Classes, System.SysUtils, System.Variants, Data.DB,
{$ENDIF}
  RLReport,
  Commons.Printers.Types,
  Printers.Interfaces,
  Connections.Interfaces
{$IFDEF USE_QUERY_BUILDER}
  , Databases.Interfaces
{$ENDIF}
  ;

type
  { Motor fluente do FortesReport CE. Implementa o contrato neutro IReportProvider. }
  TFortesReportProvider = class(TInterfacedObject, IReportProvider)
  private
    FConn: IConnection;
    FReport: TRLReport;
    FDataSource: TDataSource;
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

{$IFDEF USE_FORTESREPORT}

uses
{$IF DEFINED(FPC)}
  Graphics,
{$ELSE}
  Vcl.Graphics,
{$ENDIF}
  RLPDFFilter,   // TRLPDFFilter — regista o filtro PDF (DefaultExt '.pdf')
  Exceptions.Printers;

{ TFortesReportProvider }

constructor TFortesReportProvider.Create(const AConn: IConnection);
begin
  inherited Create;
  FConn := AConn;
  FReport := nil;
  FDataSource := nil;
  FOwnsReport := True;
  FUseSQL := False;
end;

destructor TFortesReportProvider.Destroy;
begin
  if FOwnsReport and Assigned(FReport) then
    FReport.Free;   // liberta em cascata o DataSource e o TDataSet (owned pelo report)
  inherited Destroy;
end;

class function TFortesReportProvider.New: IReportProvider;
begin
  Result := TFortesReportProvider.Create(nil);
end;

class function TFortesReportProvider.New(const AConn: IConnection): IReportProvider;
begin
  Result := TFortesReportProvider.Create(AConn);
end;

function TFortesReportProvider.EnsureConnection: IConnection;
begin
  if FConn = nil then
    raise EPrintersConfigurationException.Create(
      'Conexão não atribuída — chame .Connection(AConn) antes de gerar o relatório.',
      ERR_PRINTERS_CONNECTION_NOT_ASSIGNED, 'EnsureConnection');
  Result := FConn;
end;

function TFortesReportProvider.FetchDataSet: TObject;
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

procedure TFortesReportProvider.BuildReport;
var
  LDataSet: TDataSet;
  LBandTitle, LBandHdr, LBandDetail: TRLBand;
  LLbl: TRLLabel;
  LTxt: TRLDBText;
  I, X, LColW: Integer;
  LField: TField;
begin
  if FReport <> nil then
    FreeAndNil(FReport);
  FReport := TRLReport.Create(nil);
  FReport.ShowProgress := False;   // headless: nao criar form de progresso (AV em consola)
  // Owner e nil (Create(nil)); UpdateMacros acede Owner.Name quando JobTitle e vazio.
  // Definir Title/JobTitle nao-vazios evita o AV (Owner.Name com Owner nil).
  FReport.Title := 'ProvidersORM';
  FReport.JobTitle := 'ProvidersORM';
  FOwnsReport := True;

  LDataSet := TDataSet(FetchDataSet);
  if LDataSet = nil then
    raise EPrintersDataSourceException.Create('TDataSet nulo do ProvidersORM.',
      ERR_PRINTERS_DATASOURCE_EMPTY, 'BuildReport');

  { Ownership (C-03): dataset + datasource caem em cascata com o relatório. }
  if LDataSet.Owner = nil then
    FReport.InsertComponent(LDataSet);
  if not LDataSet.Active then
    LDataSet.Open;

  FDataSource := TDataSource.Create(FReport);   // owned pelo report
  FDataSource.DataSet := LDataSet;
  FReport.DataSource := FDataSource;             // dirige a iteração da banda de detalhe

  { Banda de título (opcional). }
  if FTitle <> '' then
  begin
    LBandTitle := TRLBand.Create(FReport);
    LBandTitle.Parent := FReport;
    LBandTitle.BandType := btTitle;
    LBandTitle.Height := 40;
    LLbl := TRLLabel.Create(LBandTitle);
    LLbl.Parent := LBandTitle;
    LLbl.Caption := FTitle;
    LLbl.Font.Size := 14;
    LLbl.Font.Style := [fsBold];
    LLbl.Left := 8;
    LLbl.Top := 8;
    LLbl.AutoSize := True;
  end;

  { Cabeçalho de colunas. }
  LBandHdr := TRLBand.Create(FReport);
  LBandHdr.Parent := FReport;
  LBandHdr.BandType := btColumnHeader;
  LBandHdr.Height := 22;

  { Banda de detalhe (repete por registo via DataSource do report). }
  LBandDetail := TRLBand.Create(FReport);
  LBandDetail.Parent := FReport;
  LBandDetail.BandType := btDetail;
  LBandDetail.Height := 20;

  X := 8;
  for I := 0 to LDataSet.FieldCount - 1 do
  begin
    LField := LDataSet.Fields[I];
    LColW := LField.DisplayWidth * 8;           // ~8px por caractere
    if LColW < 60 then LColW := 60;
    if LColW > 360 then LColW := 360;

    LLbl := TRLLabel.Create(LBandHdr);
    LLbl.Parent := LBandHdr;
    LLbl.Caption := LField.DisplayName;
    LLbl.Font.Style := [fsBold];
    LLbl.AutoSize := False;
    LLbl.Left := X;
    LLbl.Top := 4;
    LLbl.Width := LColW;

    LTxt := TRLDBText.Create(LBandDetail);
    LTxt.Parent := LBandDetail;
    LTxt.DataSource := FDataSource;
    LTxt.DataField := LField.FieldName;
    LTxt.AutoSize := False;
    LTxt.Left := X;
    LTxt.Top := 3;
    LTxt.Width := LColW;

    Inc(X, LColW + 8);
  end;
end;

function TFortesReportProvider.Connection(const AConn: IConnection): IReportProvider;
begin
  FConn := AConn;
  Result := Self;
end;

function TFortesReportProvider.Template(const AFileName: string): IReportProvider;
begin
  raise EPrintersTemplateException.Create(
    'FortesReport não usa template externo. O relatório é montado a partir do ' +
    'dataset (Query/DataView). Use SetText(''titulo'', ...) para o título.',
    ERR_PRINTERS_TEMPLATE_NOT_INFORMED, 'Template');
end;

function TFortesReportProvider.TemplateStream(const AStream: TStream): IReportProvider;
begin
  raise EPrintersTemplateException.Create(
    'FortesReport não usa template externo. O relatório é montado a partir do dataset.',
    ERR_PRINTERS_TEMPLATE_NOT_INFORMED, 'TemplateStream');
end;

{$IFDEF USE_QUERY_BUILDER}
function TFortesReportProvider.Query(const AName: string; const AQuery: IQueryBuilder): IReportProvider;
begin
  FPipelineName := AName;
  FQuery := AQuery;
  FUseSQL := False;
  Result := Self;
end;
{$ENDIF}

function TFortesReportProvider.DataView(const AName, ASQL: string): IReportProvider;
begin
  FPipelineName := AName;
  FSQL := ASQL;
  FUseSQL := True;
  Result := Self;
end;

function TFortesReportProvider.Param(const AName: string; const AValue: Variant): IReportProvider;
begin
  SetLength(FParams, Length(FParams) + 1);
  FParams[High(FParams)] := AValue;
  Result := Self;
end;

function TFortesReportProvider.SetText(const AComponentName, AValue: string): IReportProvider;
begin
  { No FortesReport (build-from-dataset) o único rótulo nomeável é o título. }
  if SameText(AComponentName, 'titulo') or SameText(AComponentName, 'title')
     or SameText(AComponentName, 'ReportTitle') then
    FTitle := AValue;
  Result := Self;
end;

function TFortesReportProvider.AutoBind: IReportProvider;
begin
  raise EPrintersConfigurationException.Create(
    'AutoBind é específico do ReportBuilder (.rtm legado). O FortesReport monta o ' +
    'relatório a partir do dataset (Query/DataView).',
    ERR_PRINTERS_ENGINE_NOT_ENABLED, 'AutoBind');
end;

function TFortesReportProvider.Build: TComponent;
begin
  BuildReport;
  FOwnsReport := False; // o caller passa a ser dono do TRLReport
  Result := FReport;
end;

procedure TFortesReportProvider.PrintPreview;
begin
  BuildReport;
  FReport.Preview;
end;

procedure TFortesReportProvider.PrintToPrinter(const ACopies: Integer);
begin
  BuildReport;
  FReport.Print;   // FortesReport imprime na impressora default; cópias via setup do SO
end;

procedure TFortesReportProvider.SaveToPDF(const AFileName: string);
var
  LFilter: TRLPDFFilter;
begin
  if AFileName = '' then
    raise EPrintersExportException.Create('Nome do ficheiro PDF não informado.',
      ERR_PRINTERS_EXPORT_FILE_NOT_INFORMED, 'SaveToPDF');
  BuildReport;
  if not FReport.Prepare then
    raise EPrintersRenderException.Create('Falha ao preparar o relatório (Prepare).',
      ERR_PRINTERS_RENDER_FAILED, 'SaveToPDF');
  LFilter := TRLPDFFilter.Create(nil);
  try
    LFilter.ShowProgress := False;
    LFilter.FileName := AFileName;
    LFilter.FilterPages(FReport.Pages);   // idioma dos demos FortesReport
  finally
    LFilter.Free;
  end;
end;

procedure TFortesReportProvider.Execute(const AOutput: TReportOutput);
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
