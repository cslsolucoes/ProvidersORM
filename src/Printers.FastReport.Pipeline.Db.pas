{ =============================================================================
  Printers.FastReport.Pipeline.Db - Ponte TDataSet -> TfrxDBDataset

  Descrição:
  Cria um TfrxDBDataset (FastReport VCL) sobre um TDataSet já produzido pelo
  ProvidersORM (IConnection.ExecuteQuery / IQueryBuilder.Execute). Resolve o
  contrato de ownership (C-03, opção c): o TDataSet e o TfrxDBDataset passam a
  ser *owned* pelo TfrxReport — libertação em cascata, sem leaks, sem alterar o
  core do ORM. O dataset é registado em AReport.DataSets (UserName = nome usado
  no template .fr3).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.1.0 (03/08/2026): absorvido de ProvidersORM v2.3.0 para
    `src/Modulos/Printers/FastReport/` (Onda 9.2). Zero alteração de código
    (`uses` já não tinha nenhuma referência v2.3.0-specific) — só cabeçalho v3.
  Changelog (fonte v2.3.0):
  - 1.0.0 (28/06/2026): Versão inicial — TFastReportDataSet.Build (ownership em cascata).
  ============================================================================= }

unit Printers.FastReport.Pipeline.Db;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_FASTREPORT}

uses
{$IF DEFINED(FPC)}
  Classes, SysUtils, DB,
{$ELSE}
  System.Classes, System.SysUtils, Data.DB,
{$ENDIF}
  frxClass, frxDBSet;

type
  { Construtor da ponte de dados do FastReport. }
  TFastReportDataSet = class
  public
    { Cria um TfrxDBDataset *owned* por AReport, liga ao ADataSet e regista-o em
      AReport.DataSets com UserName = AName (o nome referido no template .fr3). }
    class function Build(const AReport: TfrxReport; const ADataSet: TDataSet;
      const AName: string): TfrxDBDataset;
  end;

{$ENDIF}

implementation

{$IFDEF USE_FASTREPORT}

uses
  Exceptions.Printers;

{ TFastReportDataSet }

class function TFastReportDataSet.Build(const AReport: TfrxReport;
  const ADataSet: TDataSet; const AName: string): TfrxDBDataset;
begin
  if AReport = nil then
    raise EPrintersRenderException.Create('TfrxReport não informado para a ponte de dados.',
      ERR_PRINTERS_RENDER_FAILED, 'TFastReportDataSet.Build');

  if ADataSet = nil then
    raise EPrintersDataSourceException.Create('TDataSet nulo: a fonte de dados do ProvidersORM não devolveu dataset.',
      ERR_PRINTERS_DATASOURCE_EMPTY, 'TFastReportDataSet.Build');

  { Ownership (C-03): o dataset cai em cascata com o relatório. }
  if ADataSet.Owner = nil then
    AReport.InsertComponent(ADataSet);

  if not ADataSet.Active then
    ADataSet.Open;

  Result := TfrxDBDataset.Create(AReport);   // owned pelo TfrxReport
  Result.DataSet := ADataSet;
  Result.UserName := AName;
  Result.Enabled := True;

  { Regista no relatório para resolução por nome (DataSetName no .fr3). }
  AReport.DataSets.Add(Result);
end;

{$ENDIF}

end.
