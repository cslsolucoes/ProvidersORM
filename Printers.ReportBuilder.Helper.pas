{ =============================================================================
  Printers.ReportBuilder.Helper - Class helper drop-in para TppReport

  Descrição:
  Conveniência drop-in: estende TppReport com BindProviders, que liga um
  TppDBPipeline alimentado pelo ProvidersORM (IQueryBuilder primário; SQL
  parametrizado para ad-hoc) e o atribui ao DataPipeline do relatório.
  Alternativa fluente: TReportProvider.New (fachada Printers), sem helper.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.1.0 (03/08/2026): absorvido de ProvidersORM v2.3.0 para
    `src/Modulos/Printers/ReportBuilder/` (Onda 9.2). Zero alteração de
    lógica — `uses` actualizado (`Providers.Connection.Interfaces`→
    `Connections.Interfaces`) — só cabeçalho v3.
  Changelog (fonte v2.3.0):
  - 1.0.0 (28/06/2026): Versão inicial — TReportProviderHelper.BindProviders (SQL + IQueryBuilder).
  ============================================================================= }

unit Printers.ReportBuilder.Helper;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../../ORM.Defines.inc}

{$IFDEF USE_REPORTBUILDER}

uses
{$IF DEFINED(FPC)}
  Classes, SysUtils, DB,
{$ELSE}
  System.Classes, System.SysUtils, Data.DB,
{$ENDIF}
  ppReport, ppDBPipe,
  Connections.Interfaces
{$IFDEF USE_QUERY_BUILDER}
  , Databases.Interfaces
{$ENDIF}
  ;

type
  { Drop-in helper sobre a classe de relatório do ReportBuilder. }
  TReportProviderHelper = class helper for TppReport
    { SQL textual (ad-hoc/legado) — parametrizar input via ExecuteQuery a montante. }
    function BindProviders(const AConn: IConnection; const ASQL, APipelineName: string): TppDBPipeline; overload;
{$IFDEF USE_QUERY_BUILDER}
    { Caminho primário (sem SQL puro): IQueryBuilder gera o SQL por dialeto. }
    function BindProviders(const AQuery: IQueryBuilder; const APipelineName: string): TppDBPipeline; overload;
{$ENDIF}
  end;

{$ENDIF}

implementation

{$IFDEF USE_REPORTBUILDER}

uses
  Printers.ReportBuilder.Pipeline.Db;

{ TReportProviderHelper }

function TReportProviderHelper.BindProviders(const AConn: IConnection;
  const ASQL, APipelineName: string): TppDBPipeline;
var
  LDataSet: TDataSet;
begin
  LDataSet := AConn.ExecuteQuery(ASQL);
  Result := TReportDbPipeline.Build(Self, LDataSet, APipelineName);
  Self.DataPipeline := Result;
end;

{$IFDEF USE_QUERY_BUILDER}
function TReportProviderHelper.BindProviders(const AQuery: IQueryBuilder;
  const APipelineName: string): TppDBPipeline;
var
  LDataSet: TDataSet;
begin
  LDataSet := AQuery.Execute;
  Result := TReportDbPipeline.Build(Self, LDataSet, APipelineName);
  Self.DataPipeline := Result;
end;
{$ENDIF}

{$ENDIF}

end.
