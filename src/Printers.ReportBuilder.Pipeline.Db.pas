{ =============================================================================
  Printers.ReportBuilder.Pipeline.Db - Ponte TDataSet -> TppDBPipeline

  Descrição:
  Cria um TppDBPipeline (ReportBuilder) sobre um TDataSet já produzido pelo
  ProvidersORM (IConnection.ExecuteQuery / IQueryBuilder.Execute). Resolve o
  contrato de ownership (C-03, opção c): o TDataSet, o TDataSource e o pipeline
  passam a ser *owned* pelo TppReport — libertação em cascata, sem leaks, sem
  alterar o core do ORM.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.1.0 (03/08/2026): absorvido de ProvidersORM v2.3.0 para
    `src/Modulos/Printers/ReportBuilder/` (Onda 9.2). Zero alteração de
    código (`uses` já não tinha nenhuma referência v2.3.0-specific) — só
    cabeçalho v3.
  Changelog (fonte v2.3.0):
  - 1.0.0 (28/06/2026): Versão inicial — TReportDbPipeline.Build (ownership em cascata).
  ============================================================================= }

unit Printers.ReportBuilder.Pipeline.Db;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_REPORTBUILDER}

uses
{$IF DEFINED(FPC)}
  Classes, SysUtils, DB,
{$ELSE}
  System.Classes, System.SysUtils, Data.DB,
{$ENDIF}
  ppReport, ppDBPipe;

type
  { Construtor da ponte de dados do ReportBuilder. }
  TReportDbPipeline = class
  public
    { Cria TDataSource + TppDBPipeline *owned* por AReport e liga ao ADataSet.
      Se ADataSet ainda não tiver Owner, é inserido em AReport (cascata).
      APipelineName deve coincidir com o pipeline esperado pelo .rtm (UserName). }
    class function Build(const AReport: TppReport; const ADataSet: TDataSet;
      const APipelineName: string): TppDBPipeline;
  end;

{$ENDIF}

implementation

{$IFDEF USE_REPORTBUILDER}

uses
  Exceptions.Printers;

{ TReportDbPipeline }

class function TReportDbPipeline.Build(const AReport: TppReport;
  const ADataSet: TDataSet; const APipelineName: string): TppDBPipeline;
var
  LDataSource: TDataSource;
begin
  if AReport = nil then
    raise EPrintersRenderException.Create('TppReport não informado para a ponte de dados.',
      ERR_PRINTERS_RENDER_FAILED, 'TReportDbPipeline.Build');

  if ADataSet = nil then
    raise EPrintersDataSourceException.Create('TDataSet nulo: a fonte de dados do ProvidersORM não devolveu dataset.',
      ERR_PRINTERS_DATASOURCE_EMPTY, 'TReportDbPipeline.Build');

  { Ownership (C-03): o dataset cai em cascata com o relatório. }
  if ADataSet.Owner = nil then
    AReport.InsertComponent(ADataSet);

  if not ADataSet.Active then
    ADataSet.Open;

  LDataSource := TDataSource.Create(AReport);
  LDataSource.DataSet := ADataSet;

  Result := TppDBPipeline.Create(AReport);
  Result.DataSource := LDataSource;
  Result.UserName := APipelineName;
end;

{$ENDIF}

end.
