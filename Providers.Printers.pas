{ =============================================================================
  Providers.Printers - slice da fachada TProviders para o modulo Printers

  Ponto de entrada unico do modulo para o ecossistema: o consumidor faz
  'uses Providers.Printers;' e obtem o contrato + os motores activos sem ter
  de conhecer a arvore interna (Printers.Interfaces / Printers.<Motor>.*).
  Espelha o padrao dos demais modulos (ex.: Providers.Database ->
  TProvidersDatabase, com USE_ENTITY_MANAGER aninhado sob USE_DATABASE).

  ACHADO REAL (diverge da premissa do pedido original desta onda) - CONFIRMADO
  POR LEITURA DIRECTA, nao assumido: o pedido descrevia 'src/Modulos/Printers/'
  como tendo APENAS Printers.Interfaces.pas + Printers.Version.pas (sem
  factory concreta), com base no estado da F9 quando ainda estava CONGELADA
  (03/08). Entretanto a F9 foi DESCONGELADA E CONCLUIDA (11/08, ver
  .wolf/STATUS.md e plano F10 v2.9.0) - o modulo JA TEM os 4 motores
  implementados (Onda 9.2, 03/08): Printers.ReportBuilder.Builder
  (TReportProvider), Printers.FastReport.Builder (TFastReportProvider),
  Printers.QuickReport.Builder (TQuickReportProvider) e
  Printers.FortesReport.Builder (TFortesReportProvider) - cada um com
  'class function New: IReportProvider' + 'New(const AConn: IConnection):
  IReportProvider' (confirmado por grep nos 4 ficheiros antes de escrever
  este slice). Por isso esta fachada NAO fica reduzida a so' re-exportar o
  contrato (o que seria a leitura honesta SE a premissa do pedido fosse
  verdadeira) - expoe tambem as 4 factories, cada uma aninhada sob o seu
  proprio sub-gate (USE_FASTREPORT/USE_QUICKREPORT/USE_REPORTBUILDER/
  USE_FORTESREPORT dentro de USE_PRINTERS), mesmo padrao de aninhamento ja
  usado por Providers.Database (USE_ENTITY_MANAGER dentro de USE_DATABASE).

  ESTADO REAL DOS 4 SUB-GATES (ORM.Defines.inc, confirmado por leitura): TODOS
  OFF por omissao (defines comentados na fonte, prefixo duplo-barra antes do
  DEFINE) - nenhuma lib comercial/CE (FastReport/QuickReport/ReportBuilder/FortesReport CE)
  esta vendorizada nesta bancada (ver plano F10 v2.9.0, linha F9: "GUI+smoke
  motor real pendentes, dependem de lib comercial/CE instalada, nao
  bloqueante"). Com o build por omissao (USE_PRINTERS ON, os 4 sub-gates OFF),
  TProvidersPrinters compila com ZERO factories de motor (so' os tipos
  re-exportados) - reflecte a realidade do ambiente, sem fabricar uma
  factory-fantasma. Quando um motor for vendorizado e o seu USE_* activado,
  a factory correspondente entra a compilar sem alterar este ficheiro.

  Gated por USE_PRINTERS (contrato) + sub-gates USE_FASTREPORT/USE_QUICKREPORT/
  USE_REPORTBUILDER/USE_FORTESREPORT (cada motor, aninhados). Zero logica
  propria: delega 1:1 em TReportProvider.New/TFastReportProvider.New/
  TQuickReportProvider.New/TFortesReportProvider.New.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           11/08/2026

  Changelog (file):
  - 1.0.0 (11/08/2026): criacao (FASE 10, Onda 10.1-b retomada parcialmente -
    F9/Printers descongelada 11/08, deixa de bloquear) - slice de fachada
    Providers.Printers (re-export de IReportProvider/TReportOutput + 4
    factories de motor, cada uma aninhada sob o seu proprio USE_* - todos OFF
    por omissao nesta bancada, ambiente sem lib comercial/CE vendorizada).
    Desvio real de premissa documentado acima (o modulo tem MAIS do que o
    pedido original assumia - 4 motores implementados, nao so' o contrato).
  ============================================================================= }

unit Providers.Printers;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../ORM.Defines.inc}

{$IFDEF USE_PRINTERS}

uses
  Commons.Printers.Types, // TReportOutput (tipo re-exportado)
  Connections.Interfaces, // IConnection (parametro das factories connection-bound)
  Printers.Interfaces     // IReportProvider (contrato re-exportado)
{$IFDEF USE_REPORTBUILDER}
  , Printers.ReportBuilder.Builder // TReportProvider (adapter ReportBuilder)
{$ENDIF}
{$IFDEF USE_FASTREPORT}
  , Printers.FastReport.Builder    // TFastReportProvider (adapter FastReport)
{$ENDIF}
{$IFDEF USE_QUICKREPORT}
  , Printers.QuickReport.Builder   // TQuickReportProvider (adapter QuickReport)
{$ENDIF}
{$IFDEF USE_FORTESREPORT}
  , Printers.FortesReport.Builder  // TFortesReportProvider (adapter FortesReport CE)
{$ENDIF}
  ;

type
  { --- Re-export dos contratos/tipos do modulo (o consumidor nomeia-os via este slice) --- }
  IReportProvider = Printers.Interfaces.IReportProvider;
  TReportOutput   = Commons.Printers.Types.TReportOutput;

  { Slice da fachada TProviders para o modulo Printers. Cada factory de motor
    fica aninhada sob o seu proprio USE_* (ver nota no cabecalho - todos OFF
    por omissao nesta bancada; a classe compila com ZERO membros de motor
    quando os 4 sub-gates estao OFF, so' os tipos re-exportados ficam
    disponiveis). }
  TProvidersPrinters = class
  public
{$IFDEF USE_REPORTBUILDER}
    { TReportProvider (Onda 9.2) - motor ReportBuilder (unico com AutoBind
      real, reaproveitamento de .rtm legado). }
    class function NewReportBuilder: IReportProvider; overload; static;
    class function NewReportBuilder(const AConn: IConnection): IReportProvider; overload; static;
{$ENDIF}
{$IFDEF USE_FASTREPORT}
    { TFastReportProvider (Onda 9.2) - motor FastReport (.fr3). }
    class function NewFastReport: IReportProvider; overload; static;
    class function NewFastReport(const AConn: IConnection): IReportProvider; overload; static;
{$ENDIF}
{$IFDEF USE_QUICKREPORT}
    { TQuickReportProvider (Onda 9.2) - motor QuickReport (build-from-dataset). }
    class function NewQuickReport: IReportProvider; overload; static;
    class function NewQuickReport(const AConn: IConnection): IReportProvider; overload; static;
{$ENDIF}
{$IFDEF USE_FORTESREPORT}
    { TFortesReportProvider (Onda 9.2) - motor FortesReport CE (build-from-dataset). }
    class function NewFortesReport: IReportProvider; overload; static;
    class function NewFortesReport(const AConn: IConnection): IReportProvider; overload; static;
{$ENDIF}
  end;

{$ENDIF USE_PRINTERS}

implementation

{$IFDEF USE_PRINTERS}

{ TProvidersPrinters }

{$IFDEF USE_REPORTBUILDER}
class function TProvidersPrinters.NewReportBuilder: IReportProvider;
begin
  Result := Printers.ReportBuilder.Builder.TReportProvider.New;
end;

class function TProvidersPrinters.NewReportBuilder(const AConn: IConnection): IReportProvider;
begin
  Result := Printers.ReportBuilder.Builder.TReportProvider.New(AConn);
end;
{$ENDIF}

{$IFDEF USE_FASTREPORT}
class function TProvidersPrinters.NewFastReport: IReportProvider;
begin
  Result := Printers.FastReport.Builder.TFastReportProvider.New;
end;

class function TProvidersPrinters.NewFastReport(const AConn: IConnection): IReportProvider;
begin
  Result := Printers.FastReport.Builder.TFastReportProvider.New(AConn);
end;
{$ENDIF}

{$IFDEF USE_QUICKREPORT}
class function TProvidersPrinters.NewQuickReport: IReportProvider;
begin
  Result := Printers.QuickReport.Builder.TQuickReportProvider.New;
end;

class function TProvidersPrinters.NewQuickReport(const AConn: IConnection): IReportProvider;
begin
  Result := Printers.QuickReport.Builder.TQuickReportProvider.New(AConn);
end;
{$ENDIF}

{$IFDEF USE_FORTESREPORT}
class function TProvidersPrinters.NewFortesReport: IReportProvider;
begin
  Result := Printers.FortesReport.Builder.TFortesReportProvider.New;
end;

class function TProvidersPrinters.NewFortesReport(const AConn: IConnection): IReportProvider;
begin
  Result := Printers.FortesReport.Builder.TFortesReportProvider.New(AConn);
end;
{$ENDIF}

{$ENDIF USE_PRINTERS}

end.
