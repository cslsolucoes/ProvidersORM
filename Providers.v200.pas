{ =============================================================================
  Providers.v200 - PONTE de compatibilidade v2.0/v2.3 -> v3.0

  Esta unit NAO e' uma absorcao verbatim do ficheiro homonimo em
  FontesReferencias/ProvidersORM.v2.3.0/Main/Providers.v200.pas (read-only,
  so' consultado como referencia de FORMA da API publica). Aqui a API publica
  do TProviders v2.3.0 e' TRADUZIDA para delegar na fachada v3 REAL ja
  existente (Providers.pas + os slices Providers.Parameters/Providers.Loggers/
  Providers.Printers, FASE 10). Zero logica nova reimplementada - so'
  traducao/delegacao (a unica excepcao e' a MECANICA de cache de
  DefaultConnection, que e' comportamento do proprio v200 desde sempre, nao
  logica do modulo Connections - ver nota abaixo).

  SIMBOLOS COM O MESMO NOME DA FACHADA V3 SAO INTENCIONAIS: esta unit declara
  a sua PROPRIA classe TProviders (mesmo nome de Providers.TProviders, a
  fachada raiz v3). API de compatibilidade, uso EXCLUSIVO: 'uses
  Providers.v200;' sozinho, NUNCA junto com 'uses Providers;' no mesmo
  consumidor (mesma filosofia do Providers.v161 legado - standalone/
  exclusivo). Sempre que este ficheiro precisa de chamar a fachada raiz v3,
  qualifica por nome de unit (Providers.TProviders.NewConnection) para
  desambiguar - padrao ja usado no proprio ficheiro de referencia v2.3.0
  ('Result := Providers.TProviders.DefaultConnection;') e universal nesta
  codebase (Providers.Connections.TProvidersConnections.New, etc. em
  Providers.pas).

  GATE (decisao desta onda, Onda 10.2 Tarefa B): USE_PROVIDERS_V200 dedicado
  (novo, ORM.Defines.inc, Layer 3), ON por omissao nesta bancada. Ha agora um
  precedente REAL no proprio ORM.Defines.inc para o padrao "gate proprio por
  versao de ponte de compat": USE_PROVIDERS_V161 (Layer 2, "modo excludente",
  gate/unit/.dfm de src/Main/Providers.v161.* concretizados pela Tarefa A
  DESTA MESMA onda, em paralelo a esta Tarefa B) - confirmado por leitura
  directa do ficheiro no momento em que esta unit foi escrita, nao apenas
  citado como intencao do CLAUDE.md. Esta ponte segue a MESMA convencao de
  nomenclatura (um define por versao de ponte), mas fica FORA da cascata
  EXCLUSIVE-mode da secao 4.3a (que so' desliga USE_PROVIDERS_V161 + os
  gates Layer 2 quando este esta' ON): ao contrario do Providers.v161 (100%
  self-contained, nao toca a pilha v3), o Providers.v200 DELEGA na pilha v3 -
  quando USE_PROVIDERS_V161 desliga Parameters/Loggers/Printers (Layer 2), os
  membros correspondentes desta ponte ja ficam excluidos pelos seus proprios
  IFDEFs aninhados (degrada com gracas para NewConnection/DefaultConnection
  so', sem conflito nenhum a acautelar). Fica ao criterio do consumidor
  desligar esta ponte fina (sem dependencias proprias alem dos slices v3 que
  ja estariam activos de qualquer forma) se nao precisar da API legada
  v2.0/v2.3.

  DECISOES DE TRADUCAO (ver changelog abaixo para o detalhe):
  1. USE_PARAMENTERS (grafia legada, com N extra) NAO EXISTE no v3 -
     ORM.Defines.inc confirma que foi removida na v3 B-freeze (secao
     Changelog, 1.2.0/05/07/2026: "v3 code uses USE_PARAMETERS only"). Esta
     ponte usa SEMPRE USE_PARAMETERS (sem o N extra).
  2. DefaultConnection: a fachada raiz v3 (Providers.pas) NAO tem singleton
     'DefaultConnection' - so' NewConnection stateless. Mantida a MECANICA de
     cache (class var privado, lazy, delega em Providers.TProviders.
     NewConnection na 1a chamada) como comportamento PROPRIO desta ponte -
     preserva o "shared connection" documentado no v2.3.0 sem reimplementar
     nada da logica de Connections (so' cria uma vez e cacheia).
  3. Logger(ACategory, ALevel): ILogger v3 (Loggers.Interfaces.ILogger) NAO
     tem conceito de Category (confirmado por leitura directa - so' MinLevel
     fluente). ACategory e' DESCARTADO nesta traducao; ALevel e' aplicado via
     ILogger.MinLevel(ALevel) sobre o resultado de TProvidersLoggers.New.
  4. Nao foi criado Providers.v200.Interfaces.pas companheiro: ao contrario
     do v2.3.0 (onde 'uses' de units de interface nao re-exporta simbolos -
     'uses' nao e' transitivo em Pascal, por isso aquele v2.3.0 precisava de
     uma unit .Interfaces dedicada so' para trazer os tipos ao alcance), os
     slices v3 consumidos aqui (Providers.Connections/.Parameters/.Loggers/
     .Printers) JA re-exportam os seus contratos por type-alias explicito -
     'uses Providers.Parameters;' nesta propria unit ja da' acesso a
     IParameters, por exemplo. Nao ha necessidade de uma unit companheira so'
     para re-exportar o que os slices v3 ja re-exportam.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           12/08/2026

  Changelog (file):
  - 1.0.0 (12/08/2026): criacao (FASE 10, Onda 10.2, Tarefa B) - ponte de
    compatibilidade v2.0/v2.3 -> v3.0, gate USE_PROVIDERS_V200 (novo). Traduz
    a API publica de FontesReferencias/ProvidersORM.v2.3.0/Main/
    Providers.v200.pas para delegar na fachada v3 real: NewConnection/
    DefaultConnection (cache local, sem singleton equivalente na raiz v3),
    Parameter (USE_PARAMETERS, delega em Providers.Parameters.
    TProvidersParameters.New), Logger/Logger(ACategory,ALevel) (USE_LOGGERS,
    o overload com categoria descarta ACategory - sem equivalente no ILogger
    v3 - e aplica so' ALevel via MinLevel), ReportBuilder/FastReport/
    QuickReport/FortesReport (USE_PRINTERS + sub-gates, delegam em
    Providers.Printers.TProvidersPrinters.New<Motor>). Zero logica nova
    reimplementada.
  ============================================================================= }

unit Providers.v200;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../ORM.Defines.inc}

{$IFDEF USE_PROVIDERS_V200}

uses
  Providers.Connections // IConnection (re-exportado; core, sem gate proprio)
  , Providers           // fachada raiz v3 (NewConnection) - qualificar sempre por 'Providers.TProviders.*'
{$IFDEF USE_PARAMETERS}
  , Providers.Parameters // IParameters, TProvidersParameters.New
{$ENDIF}
{$IFDEF USE_LOGGERS}
  , Providers.Loggers     // ILogger, TProvidersLoggers.New
  , Commons.Loggers.Types // TLogLevel, llInfo - 'uses' nao e' transitivo (mesmo padrao do v2.3.0 original)
{$ENDIF}
{$IFDEF USE_PRINTERS}
  , Providers.Printers    // IReportProvider, TProvidersPrinters.New<Motor>
{$ENDIF}
  ;

type
  { Classe de ponte v2.0/v2.3 -> v3.0. Nome IGUAL a' fachada raiz v3
    (Providers.TProviders) de proposito - ver nota no cabecalho do ficheiro
    ("uso exclusivo"). Sem heranca; todos os membros class function static. }
  TProviders = class
  private
    { Cache singleton LOCAL da connection default - mecanica de bridge (ver
      nota 2 no cabecalho), nao logica do modulo Connections. Lazy,
      inicializada na 1a chamada de DefaultConnection. Thread-safety: uso
      tipicamente single-thread no setup inicial (mesma nota do v2.3.0
      original). }
    class var FDefaultConnection: Providers.Connections.IConnection;
  public
    { Nova conexao (IConnection), sempre uma instancia nova. Delega em
      Providers.TProviders.NewConnection (fachada raiz v3, stateless). }
    class function NewConnection: Providers.Connections.IConnection; static;

    { Connection default cacheada, criada lazy na 1a chamada (ver nota 2 no
      cabecalho - sem singleton equivalente na fachada raiz v3; a cache e'
      propria desta ponte). Use quando quiser a mesma instancia de conexao em
      varios submodulos (Parameter/Logger) sem passar explicitamente. }
    class function DefaultConnection: Providers.Connections.IConnection; static;

{$IFDEF USE_PARAMETERS}
    { Sistema de parametros unificado (IParameters). Delega em
      Providers.Parameters.TProvidersParameters.New. Nome SINGULAR
      'Parameter' preservado da API v2.3.0 (o v3 nativo usa o plural
      'TProviders.NewParameters' na fachada raiz - nomes diferentes,
      mesma factory por baixo). }
    class function Parameter: Providers.Parameters.IParameters; static;
{$ENDIF}

{$IFDEF USE_LOGGERS}
    { Logger sem categoria (ILogger). Delega em
      Providers.Loggers.TProvidersLoggers.New. }
    class function Logger: Providers.Loggers.ILogger; overload; static;

    { Logger com categoria + nivel minimo (assinatura da API v2.3.0). SEM
      equivalente directo no v3 (ver nota 3 no cabecalho do ficheiro):
      ILogger v3 nao tem conceito de Category, so' MinLevel fluente.
      ACategory e' DESCARTADO nesta traducao; ALevel e' aplicado via
      ILogger.MinLevel sobre o resultado de TProvidersLoggers.New. }
    class function Logger(const ACategory: string;
      ALevel: Commons.Loggers.Types.TLogLevel = Commons.Loggers.Types.llInfo):
      Providers.Loggers.ILogger; overload; static;
{$ENDIF}

{$IFDEF USE_PRINTERS}
  {$IFDEF USE_REPORTBUILDER}
    { Motor de relatorio ReportBuilder (IReportProvider). Delega em
      Providers.Printers.TProvidersPrinters.NewReportBuilder. }
    class function ReportBuilder: Providers.Printers.IReportProvider; overload; static;
    class function ReportBuilder(const AConn: Providers.Connections.IConnection):
      Providers.Printers.IReportProvider; overload; static;
  {$ENDIF}

  {$IFDEF USE_FASTREPORT}
    { Motor de relatorio FastReport (IReportProvider). Delega em
      Providers.Printers.TProvidersPrinters.NewFastReport. }
    class function FastReport: Providers.Printers.IReportProvider; overload; static;
    class function FastReport(const AConn: Providers.Connections.IConnection):
      Providers.Printers.IReportProvider; overload; static;
  {$ENDIF}

  {$IFDEF USE_QUICKREPORT}
    { Motor de relatorio QuickReport (IReportProvider), monta a partir do
      dataset (sem template externo). Delega em Providers.Printers.
      TProvidersPrinters.NewQuickReport. }
    class function QuickReport: Providers.Printers.IReportProvider; overload; static;
    class function QuickReport(const AConn: Providers.Connections.IConnection):
      Providers.Printers.IReportProvider; overload; static;
  {$ENDIF}

  {$IFDEF USE_FORTESREPORT}
    { Motor de relatorio FortesReport CE (IReportProvider), monta a partir do
      dataset (sem template externo). Delega em Providers.Printers.
      TProvidersPrinters.NewFortesReport. }
    class function FortesReport: Providers.Printers.IReportProvider; overload; static;
    class function FortesReport(const AConn: Providers.Connections.IConnection):
      Providers.Printers.IReportProvider; overload; static;
  {$ENDIF}
{$ENDIF}
  end;

{$ENDIF USE_PROVIDERS_V200}

implementation

{$IFDEF USE_PROVIDERS_V200}

{ TProviders }

class function TProviders.NewConnection: Providers.Connections.IConnection;
begin
  Result := Providers.TProviders.NewConnection;
end;

class function TProviders.DefaultConnection: Providers.Connections.IConnection;
begin
  if not Assigned(FDefaultConnection) then
    FDefaultConnection := Providers.TProviders.NewConnection;
  Result := FDefaultConnection;
end;

{$IFDEF USE_PARAMETERS}
class function TProviders.Parameter: Providers.Parameters.IParameters;
begin
  Result := Providers.Parameters.TProvidersParameters.New;
end;
{$ENDIF}

{$IFDEF USE_LOGGERS}
class function TProviders.Logger: Providers.Loggers.ILogger;
begin
  Result := Providers.Loggers.TProvidersLoggers.New;
end;

class function TProviders.Logger(const ACategory: string;
  ALevel: Commons.Loggers.Types.TLogLevel): Providers.Loggers.ILogger;
begin
  // ACategory sem equivalente no ILogger v3 (ver nota 3 no cabecalho) - descartado.
  Result := Providers.Loggers.TProvidersLoggers.New.MinLevel(ALevel);
end;
{$ENDIF}

{$IFDEF USE_PRINTERS}
  {$IFDEF USE_REPORTBUILDER}
class function TProviders.ReportBuilder: Providers.Printers.IReportProvider;
begin
  Result := Providers.Printers.TProvidersPrinters.NewReportBuilder;
end;

class function TProviders.ReportBuilder(const AConn: Providers.Connections.IConnection):
  Providers.Printers.IReportProvider;
begin
  Result := Providers.Printers.TProvidersPrinters.NewReportBuilder(AConn);
end;
  {$ENDIF}

  {$IFDEF USE_FASTREPORT}
class function TProviders.FastReport: Providers.Printers.IReportProvider;
begin
  Result := Providers.Printers.TProvidersPrinters.NewFastReport;
end;

class function TProviders.FastReport(const AConn: Providers.Connections.IConnection):
  Providers.Printers.IReportProvider;
begin
  Result := Providers.Printers.TProvidersPrinters.NewFastReport(AConn);
end;
  {$ENDIF}

  {$IFDEF USE_QUICKREPORT}
class function TProviders.QuickReport: Providers.Printers.IReportProvider;
begin
  Result := Providers.Printers.TProvidersPrinters.NewQuickReport;
end;

class function TProviders.QuickReport(const AConn: Providers.Connections.IConnection):
  Providers.Printers.IReportProvider;
begin
  Result := Providers.Printers.TProvidersPrinters.NewQuickReport(AConn);
end;
  {$ENDIF}

  {$IFDEF USE_FORTESREPORT}
class function TProviders.FortesReport: Providers.Printers.IReportProvider;
begin
  Result := Providers.Printers.TProvidersPrinters.NewFortesReport;
end;

class function TProviders.FortesReport(const AConn: Providers.Connections.IConnection):
  Providers.Printers.IReportProvider;
begin
  Result := Providers.Printers.TProvidersPrinters.NewFortesReport(AConn);
end;
  {$ENDIF}
{$ENDIF}

initialization
  // FDefaultConnection inicia nil (class var); cacheada lazy na 1a chamada
  // de DefaultConnection - ver nota 2 no cabecalho do ficheiro.

finalization
  TProviders.FDefaultConnection := nil;

{$ENDIF USE_PROVIDERS_V200}

end.
