{ =============================================================================
  Printers.Interfaces - TODAS as interfaces do módulo Printers (relatórios)

  Ficheiro central das interfaces do módulo (regra do owner "centralizar as
  interfaces", mesmo padrão de Connections.Interfaces/Databases.Interfaces):
  IReportProvider — contrato fluente único, neutro de motor (sem tipos
  pp*/frx*/QR*/RL*), absorvido verbatim de ProvidersORM v2.3.0 com paridade
  100% de superfície (decisão do owner, 02-03/08/2026 — reutilizar o contrato
  já provado em produção em vez de desenhar um par IPrinter/IReportEngine do
  zero; ver Onda 9.0 do plano F9). Os 4 motores (ReportBuilder/FastReport/
  QuickReport/FortesReport CE) implementam esta MESMA interface, cada um no
  seu ficheiro `Printers.<Motor>.Builder.pas` (Onda 9.2).

  Em v2.3.0 este contrato vivia em `Main/Printers.Interfaces.pas` (fora do
  módulo); em v3 desce para a raiz de `src/Modulos/Printers/` — mesma
  convenção `<Módulo>.Interfaces.pas` já usada por Connections e Database.

  Fonte de dados (ordem de preferência — skill developer-delphi-providers-orm-usage):
    1) Query(IQueryBuilder)  — primário (gera SQL por dialecto, via Databases.Interfaces);
    2) DataView(SQL)         — só ad-hoc/legado, SEMPRE parametrizado (:p0).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.0.0 (03/08/2026): absorvido de ProvidersORM v2.3.0 (`Main/Printers.Interfaces.pas`,
    FileVersion origem 1.0.0) para `src/Modulos/Printers/Printers.Interfaces.pas`
    (Onda 9.0). Zero alteração de contrato/superfície — só cabeçalho v3 +
    placement (raiz do módulo, não Main/) + uses actualizados para os módulos
    v3 (`Connections.Interfaces` em vez de `Providers.Connection.Interfaces`;
    `Databases.Interfaces` em vez de `Database.QueryBuilder.Interfaces`;
    `Commons.Printers.Types` — já migrado na F1 Onda 1.4 — em vez do
    `Printers.Types` local do módulo em v2.3.0).
  Changelog (fonte v2.3.0):
  - 1.0.0 (28/06/2026): Versão inicial — IReportProvider, contrato neutro multi-motor
    (ReportBuilder/FastReport/QuickReport): Connection/Template/TemplateStream/Query/
    DataView/Param/SetText/AutoBind + terminais Build/PrintPreview/PrintToPrinter/SaveToPDF/Execute.
  ============================================================================= }

unit Printers.Interfaces;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../ORM.Defines.inc}

{$IFDEF USE_PRINTERS}

uses
{$IF DEFINED(FPC)}
  Classes, SysUtils, Variants,
{$ELSE}
  System.Classes, System.SysUtils, System.Variants,
{$ENDIF}
  Commons.Printers.Types,
  Connections.Interfaces
{$IFDEF USE_QUERY_BUILDER}
  , Databases.Interfaces
{$ENDIF}
  ;

type
  { Contrato fluente, neutro de motor, para montar e emitir um relatório.
    Fonte de dados (ordem de preferência — skill developer-delphi-providers-orm-usage):
      1) Query(IQueryBuilder)  — primário (gera SQL por dialeto);
      2) DataView(SQL)         — só ad-hoc/legado, SEMPRE parametrizado (:p0). }
  IReportProvider = interface
    ['{B2C3D4E5-F6A7-4B8C-9D0E-1F2A3B4C5D60}']
    { --- configuração (fluente, retornam Self) --- }
    function Connection(const AConn: IConnection): IReportProvider;
    function Template(const AFileName: string): IReportProvider;
    function TemplateStream(const AStream: TStream): IReportProvider;
{$IFDEF USE_QUERY_BUILDER}
    function Query(const AName: string; const AQuery: IQueryBuilder): IReportProvider;
{$ENDIF}
    function DataView(const AName, ASQL: string): IReportProvider;
    function Param(const AName: string; const AValue: Variant): IReportProvider;
    { Define o texto (Caption) de um rótulo do template por UserName — para
      cabeçalhos/títulos estáticos calculados pelo consumidor (sem código RAP). }
    function SetText(const AComponentName, AValue: string): IReportProvider;
    { Reaproveitamento de .rtm legado (Hábil/Access): introspeciona o template
      indicado em Template(), extrai cada SQL embutido + pipeline, traduz o SQL
      para o dialeto do engine activo e religa pela ponte do ProvidersORM. O
      DataView ADO/RAP/AutoSearch do legado é removido (layout preservado).
      Só o motor ReportBuilder implementa de facto (FastReport/QuickReport/
      FortesReport lançam EPrintersConfigurationException — sem template
      externo nos 2 últimos, ver Onda 9.2). }
    function AutoBind: IReportProvider;

    { --- terminais --- }
    { Devolve o objeto-relatório montado (tipo neutro TComponent; o caller passa a ser dono). }
    function Build: TComponent;
    procedure PrintPreview;
    procedure PrintToPrinter(const ACopies: Integer = 1);
    procedure SaveToPDF(const AFileName: string);
    procedure Execute(const AOutput: TReportOutput);
  end;

{$ENDIF}

implementation

end.
