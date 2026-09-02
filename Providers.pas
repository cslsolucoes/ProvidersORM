{ =============================================================================
  Providers - Fachada RAIZ do ecossistema ProvidersORM v3 (TProviders)

  Ponto de entrada UNICO do ecossistema para o consumidor: 'uses Providers;'
  devolve as factories de todos os modulos activos, sem o consumidor precisar
  de conhecer a arvore interna (Modulos/<Modulo>) nem os slices intermedios
  (Providers.<Modulo>). Zero logica propria: cada class function AGREGA (nao
  reimplementa) a factory ja existente no respectivo slice de Main/, que por
  sua vez delega 1:1 na factory do modulo (Onda 5, "so agregam").

  AMBITO desta onda (10.1-a, decisao do owner 03/08 - "foco inicial seria
  Connections/PoolConnections/Database/Parameters o resto vamos depois"):
  compoe SO os 4 modulos ja fechados (F4/F4/F5/F7) - Connections,
  PoolConnections, Database (+Synchronize/QueryBuilder/EntityManager/Dialect)
  e Parameters. Os 6 modulos CONGELADOS (Loggers/Printers/Attributers/
  GraphQL/ActiveDirectory/ZipFile - Onda 10.1-b) NAO tem member nesta classe
  ainda - nao ha placeholder/stub para eles (a fachada simplesmente ainda nao
  chegou a esses modulos; ver plano F10 v2.3.0, Onda 10.1-b, para a
  distincao "congelado" vs "stub tipado com USE_* OFF").

  EXTENSAO (10.1-a2, decisao do owner 03/08 - "ActiveDirectory, ZipFile nao
  estao congelados?" - o owner corrigiu a inferencia inicial de que "o resto"
  em 10.1-a incluia estes 2 modulos): acrescenta NewActiveDirectory
  (USE_ACTIVEDIRECTORY, delega em Providers.ActiveDirectory) e NewZip (sem
  gate proprio, ZipFile e modulo CORE - delega em Providers.ZipFile). Os
  restantes 4 modulos CONGELADOS (Loggers/Printers/Attributers/GraphQL -
  Onda 10.1-b) continuam sem member nesta classe.

  NewMetadata/IMetadata NAO EXISTE nesta fachada - o plano previa esse nome
  (ex-IMetadataProvider), mas o contrato foi DISSOLVIDO (nao renomeado) na
  propagacao F5 (26/07/2026, ver Database.Version.pas changelog 3.4.1). O
  SSOT real de metadados/catalogo e ICatalogReader (Providers.Database.
  NewCatalogReader) - a fachada raiz NAO fabrica um simbolo falso so para
  bater com o plano; ver nota completa em Providers.Database.pas.

  EXTENSAO (10.1-b retomada parcialmente, 11/08 - F8/Loggers descongelada e
  concluida, deixa de bloquear): acrescenta NewLogger (USE_LOGGERS, delega em
  Providers.Loggers.TProvidersLoggers.New) - caso de uso universal obvio
  (qualquer modulo pode querer um ILogger). Printers e Attributers NAO ganham
  member na raiz nesta onda (decisao documentada, nao esquecimento): Printers
  expoe 4 factories por MOTOR (NewFastReport/NewQuickReport/NewReportBuilder/
  NewFortesReport, cada um aninhado sob o seu proprio USE_* - todos OFF por
  omissao nesta bancada) - nao ha 'o' motor universal para a raiz escolher sem
  ambiguidade, mesmo padrao que a raiz ja aplica a Database (NewDialect/
  NewCatalogReader ficam so' na slice, nao na raiz). Attributers expoe 3
  parsers por MODULO mapeado (NewDatabaseParser/NewParametersParser/
  NewLoggerParser) - idem, sem candidato universal obvio. Ambos ficam so' em
  Providers.Printers/Providers.Attributers directamente - mesmo padrao ja
  usado por Providers.Database para metodos alem do conjunto minimo da raiz.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.3.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           12/08/2026

  Changelog (file):
  - 1.3.0 (12/08/2026): FASE 10, Onda 10.1-b (ligacao do modulo GraphQL, fechado
    na FASE 13) - ACRESCENTA (aditivo puro, sem alterar membros existentes)
    NewGraphQLServer (USE_GRAPHQL_SERVER, delega em Providers.GraphQL.
    TProvidersGraphQL.NewServer -> builder fluente IProvidersGraphQLServer) e
    NewGraphQLClient (USE_GRAPHQL_CLIENT, delega em ...NewClient -> IGraphQLClient),
    ambos aninhados sob o gate mestre USE_GRAPHQL. Providers.GraphQL adicionado
    ao uses sob USE_GRAPHQL. Nenhum outro member/logica alterado.
  - 1.2.0 (11/08/2026): FASE 10, Onda 10.1-b retomada parcialmente (F8/Loggers
    e F9/Printers descongeladas 11/08, deixam de bloquear; Attributers - F6 -
    fechada 03/08 mas ainda por commitar, ja disponivel para leitura) -
    acrescenta NewLogger (USE_LOGGERS, delega em Providers.Loggers.
    TProvidersLoggers.New). Printers/Attributers NAO ganham member na raiz -
    decisao documentada acima (sem candidato universal sem ambiguidade de
    motor/modulo); os slices Providers.Printers/Providers.Attributers
    (novos nesta onda) sao consumidos directamente pelo caller que sabe qual
    motor/modulo quer. GraphQL (F13) continua CONGELADA - fora de ambito.
  - 1.1.0 (03/08/2026): FASE 10, Onda 10.1-a2 (ActiveDirectory/ZipFile,
    decisao do owner) - acrescenta NewActiveDirectory (USE_ACTIVEDIRECTORY,
    delega em Providers.ActiveDirectory.TProvidersActiveDirectory.New) e
    NewZip (sem gate proprio - ZipFile e modulo CORE, delega em
    Providers.ZipFile.TProvidersZipFile.NewArchive/OpenArchive via a
    interface IZipFileBuilder). Nao mexe em nenhum member ja existente da
    10.1-a. Os 4 slices congelados (10.1-b: Loggers/Printers/Attributers/
    GraphQL) continuam por ligar, sem placeholder.
  - 1.0.0 (03/08/2026): criacao (FASE 10, Onda 10.1-a - ambito parcial,
    decisao do owner) - TProviders raiz compondo os 4 slices activos desta
    onda (Providers.Connections/.PoolConnections/.Database/.Parameters):
    NewConnection, NewPoolConnections (USE_POOLCONNECTIONS), NewSynchronize/
    NewQueryBuilder/NewDialect/NewEntityManager (USE_DATABASE, o ultimo
    tambem sob USE_ENTITY_MANAGER aninhado) e NewParameters
    (USE_PARAMETERS). Desvio de plano documentado (sem NewMetadata/
    IMetadata - dissolvido na F5). Os 6 slices congelados (10.1-b) ficam
    por ligar, sem placeholder.
  ============================================================================= }

unit Providers;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../ORM.Defines.inc}

uses
  Providers.Connections // core, sem gate USE_* (sempre presente)
  , Providers.ZipFile   // core, sem gate USE_* proprio (sempre presente - ver nota no cabecalho de Providers.ZipFile.pas)
{$IFDEF USE_POOLCONNECTIONS}
  , Providers.PoolConnections
{$ENDIF}
{$IFDEF USE_DATABASE}
  , Providers.Database
{$ENDIF}
{$IFDEF USE_PARAMETERS}
  , Providers.Parameters
{$ENDIF}
{$IFDEF USE_ACTIVEDIRECTORY}
  , Providers.ActiveDirectory
{$ENDIF}
{$IFDEF USE_LOGGERS}
  , Providers.Loggers
{$ENDIF}
{$IFDEF USE_GRAPHQL}
  , Providers.GraphQL
{$ENDIF}
  ;

type
  { Fachada raiz do ecossistema. Sem heranca (herdavel - nao "sealed"); todos
    os membros class function/class procedure ... static. Compoe os modulos
    activos das Ondas 10.1-a/10.1-a2 - ver nota de ambito no cabecalho do
    ficheiro. }
  TProviders = class
  public
    { --- Connections (core, sem gate) --- }
    class function NewConnection: Providers.Connections.IConnection; static;

    { --- ZipFile (core, sem gate USE_* proprio - 10 formatos; Onda 10.1-a2) --- }
    class function NewZip(const APath: string): Providers.ZipFile.IZipFileBuilder; static;

{$IFDEF USE_POOLCONNECTIONS}
    { --- PoolConnections (Broker Elastico, F4) --- }
    class function NewPoolConnections: Providers.PoolConnections.IPoolConnections; static;
{$ENDIF}

{$IFDEF USE_DATABASE}
    { --- Database (F5) --- }
    class function NewSynchronize(const AConnection: Providers.Connections.IConnection):
      Providers.Database.ISynchronize; static;
    class function NewQueryBuilder: Providers.Database.IQueryBuilder; static;
    class function NewDialect(const AConnection: Providers.Connections.IConnection):
      Providers.Database.IDialect; static;
  {$IFDEF USE_ENTITY_MANAGER}
    class function NewEntityManager: Providers.Database.IEntityManager; static;
  {$ENDIF}
{$ENDIF}

{$IFDEF USE_PARAMETERS}
    { --- Parameters (F7) --- }
    class function NewParameters: Providers.Parameters.IParameters; static;
{$ENDIF}

{$IFDEF USE_ACTIVEDIRECTORY}
    { --- ActiveDirectory (F3, Onda 10.1-a2) --- }
    class function NewActiveDirectory: Providers.ActiveDirectory.IActiveDirectoryConnection; static;
{$ENDIF}

{$IFDEF USE_LOGGERS}
    { --- Loggers (F8, Onda 10.1-b retomada parcialmente 11/08) --- }
    class function NewLogger: Providers.Loggers.ILogger; static;
{$ENDIF}

{$IFDEF USE_GRAPHQL}
    { --- GraphQL (F13, Onda 10.1-b) - server/client cada um sob o seu sub-gate --- }
  {$IFDEF USE_GRAPHQL_SERVER}
    { Builder fluente do servidor GraphQL (host Indy HTTP). Uso tipico:
        TProviders.NewGraphQLServer.FromConnection(conn, 'public').Port(8080).Start; }
    class function NewGraphQLServer: Providers.GraphQL.IProvidersGraphQLServer; static;
  {$ENDIF}
  {$IFDEF USE_GRAPHQL_CLIENT}
    { Cliente GraphQL fluente para consumir APIs remotas. }
    class function NewGraphQLClient: Providers.GraphQL.IGraphQLClient; static;
  {$ENDIF}
{$ENDIF}
  end;

implementation

{ TProviders }

class function TProviders.NewConnection: Providers.Connections.IConnection;
begin
  Result := Providers.Connections.TProvidersConnections.New;
end;

class function TProviders.NewZip(const APath: string): Providers.ZipFile.IZipFileBuilder;
begin
  Result := Providers.ZipFile.TProvidersZipFile.NewArchive(APath);
end;

{$IFDEF USE_POOLCONNECTIONS}
class function TProviders.NewPoolConnections: Providers.PoolConnections.IPoolConnections;
begin
  Result := Providers.PoolConnections.TProvidersPoolConnections.New;
end;
{$ENDIF}

{$IFDEF USE_DATABASE}
class function TProviders.NewSynchronize(const AConnection: Providers.Connections.IConnection):
  Providers.Database.ISynchronize;
begin
  Result := Providers.Database.TProvidersDatabase.NewSynchronize(AConnection);
end;

class function TProviders.NewQueryBuilder: Providers.Database.IQueryBuilder;
begin
  Result := Providers.Database.TProvidersDatabase.NewQueryBuilder;
end;

class function TProviders.NewDialect(const AConnection: Providers.Connections.IConnection):
  Providers.Database.IDialect;
begin
  Result := Providers.Database.TProvidersDatabase.NewDialect(AConnection);
end;

  {$IFDEF USE_ENTITY_MANAGER}
class function TProviders.NewEntityManager: Providers.Database.IEntityManager;
begin
  Result := Providers.Database.TProvidersDatabase.NewEntityManager;
end;
  {$ENDIF}
{$ENDIF}

{$IFDEF USE_PARAMETERS}
class function TProviders.NewParameters: Providers.Parameters.IParameters;
begin
  Result := Providers.Parameters.TProvidersParameters.New;
end;
{$ENDIF}

{$IFDEF USE_ACTIVEDIRECTORY}
class function TProviders.NewActiveDirectory: Providers.ActiveDirectory.IActiveDirectoryConnection;
begin
  Result := Providers.ActiveDirectory.TProvidersActiveDirectory.New;
end;
{$ENDIF}

{$IFDEF USE_LOGGERS}
class function TProviders.NewLogger: Providers.Loggers.ILogger;
begin
  Result := Providers.Loggers.TProvidersLoggers.New;
end;
{$ENDIF}

{$IFDEF USE_GRAPHQL}
  {$IFDEF USE_GRAPHQL_SERVER}
class function TProviders.NewGraphQLServer: Providers.GraphQL.IProvidersGraphQLServer;
begin
  Result := Providers.GraphQL.TProvidersGraphQL.NewServer;
end;
  {$ENDIF}
  {$IFDEF USE_GRAPHQL_CLIENT}
class function TProviders.NewGraphQLClient: Providers.GraphQL.IGraphQLClient;
begin
  Result := Providers.GraphQL.TProvidersGraphQL.NewClient;
end;
  {$ENDIF}
{$ENDIF}

end.
