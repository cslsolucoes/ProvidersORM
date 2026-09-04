{ =============================================================================
  Providers.GraphQL - slice da fachada TProviders para o modulo GraphQL
  (FASE 13 - Server + Client)

  Ponto de entrada unico do modulo para o ecossistema: o consumidor faz
  'uses Providers.GraphQL;' e obtem as factories + os contratos sem ter de
  conhecer a arvore interna do modulo (Modulos/GraphQL/Core, /Server, /Client -
  22 units). Espelha o padrao dos demais slices (ex.: Providers.Database ->
  TProvidersDatabase, Providers.ActiveDirectory -> TProvidersActiveDirectory).

  Este slice ANTECIPA a camada Main/: a FASE 10 (Onda 10.1-b, ligacao do modulo
  GraphQL fechado na FASE 13) apenas liga TProviders.NewGraphQLServer/
  NewGraphQLClient a TProvidersGraphQL aqui definido. Re-exporta por alias os
  contratos publicos mais usados dos dois lados (IGraphQLSchema no servidor;
  IGraphQLClient/IGraphQLResponse/IGraphQLQuery/IGraphQLRemoteSchema no cliente).

  GATES (owner: sub-gates aninhados dentro do gate mestre):
    USE_GRAPHQL          gate mestre (Core + Schema + Executor)
      USE_GRAPHQL_SERVER   expor o ORM como servidor GraphQL (host Indy HTTP)
      USE_GRAPHQL_CLIENT   consumir APIs GraphQL remotas
  Nota de leitura (empirica): no modulo, os ficheiros do lado SERVIDOR sao
  gated apenas por USE_GRAPHQL (nao por USE_GRAPHQL_SERVER - so o CLIENTE usa
  USE_GRAPHQL_CLIENT internamente). Esta slice, por decisao do owner, aplica
  na mesma o sub-gate USE_GRAPHQL_SERVER ao seu lado servidor, alinhando a
  intencao dos dois sub-gates ao nivel da fachada (o modulo interno e mais
  permissivo, mas a fachada expoe server/client cada um sob o seu sub-gate).

  --- FORMA DA API (decisao documentada) -------------------------------------
  LADO CLIENTE (simples, delegacao 1:1): o modulo ja expoe factories fluentes
  livres (NewGraphQLClient: IGraphQLClient, NewGraphQLQuery: IGraphQLQuery,
  FetchSchema). O slice delega 1:1 - TProvidersGraphQL.NewClient/NewQuery/
  FetchRemoteSchema - e re-exporta os contratos por alias. Sem logica propria.

  LADO SERVIDOR (construcao multi-passo -> builder fluente): expor o ORM como
  servidor NAO e uma factory de 1 chamada. A construcao real (provada pelos
  smokes smoke_graphql_orm_exec / smoke_graphql_server) e uma SEQUENCIA:
    1) ICatalogReader do catalogo ORM         (TCatalogReader.New / Providers.Database.NewCatalogReader)
    2) IGraphQLSchema a partir do catalogo     (TGraphQLSchemaFactory.FromMetadata)
    3) resolvers ORM anexados ao schema        (InstallOrmResolvers, anti-N+1)
    4) [opcional] resolvers de introspection   (InstallIntrospectionResolvers)
    5) host HTTP                               (TGraphQLIndyServer.Create/Start/Stop)
  Como o modulo expoe estes 5 PASSOS como pecas separadas (nenhum ponto unico
  os compoe - cada smoke reescreve a sequencia a mao), a fachada oferece um
  BUILDER FLUENTE IProvidersGraphQLServer que os AGREGA num unico fluxo, sem
  esconder nenhum passo obrigatorio (cada passo tem o seu metodo fluente:
  FromConnection/FromSchema -> Port/Validate/WithIntrospection -> Start/Stop).
  O builder detem o TGraphQLIndyServer (classe concreta do modulo) e liberta-o
  no seu Destroy - o consumidor so' mantem a interface. Zero reimplementacao de
  logica GraphQL: o builder apenas ORQUESTRA as pecas existentes do modulo.

  Uso tipico (servidor ORM):
    var LSrv: IProvidersGraphQLServer;
    LSrv := TProviders.NewGraphQLServer
              .FromConnection(TProviders.NewConnection...Connect, 'public')
              .WithIntrospection
              .Port(8080)
              .Start;
    // ... LSrv.Active ...
    LSrv.Stop;

  Uso tipico (cliente):
    var LResp: IGraphQLResponse;
    LResp := TProviders.NewGraphQLClient.Endpoint('http://host/graphql')
               .Execute(TProviders.NewGraphQLQuery... );  // via NewClient/NewQuery no slice

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0 (GraphQL fechado na FASE 13 - GraphQL.Version)
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           12/08/2026

  Changelog (file):
  - 1.0.0 (12/08/2026): criacao (FASE 10, Onda 10.1-b - ligacao do modulo
    GraphQL, fechado na FASE 13) - slice de fachada Providers.GraphQL. Lado
    SERVIDOR: builder fluente IProvidersGraphQLServer (FromConnection/FromSchema
    -> Port/Validate/WithIntrospection -> Start/Stop/Active/Schema) que agrega
    TGraphQLSchemaFactory.FromMetadata + InstallOrmResolvers +
    InstallIntrospectionResolvers + TGraphQLIndyServer (sub-gate
    USE_GRAPHQL_SERVER; FromConnection sob USE_DATABASE + USE_QUERY_BUILDER).
    Lado CLIENTE: NewClient (+overload com endpoint) / NewQuery /
    FetchRemoteSchema, delegacao 1:1 em NewGraphQLClient/NewGraphQLQuery/
    FetchSchema (sub-gate USE_GRAPHQL_CLIENT). Re-export por alias de
    IGraphQLSchema/TGraphQLSchemaBuilder(/TGraphQLSchemaFactory/ICatalogReader)
    e IGraphQLClient/IGraphQLResponse/IGraphQLQuery/IGraphQLRemoteSchema. A
    ligacao TProviders.NewGraphQLServer/NewGraphQLClient fecha na mesma onda
    (Main/Providers.pas). Zero logica propria (orquestracao de pecas do modulo).
  ============================================================================= }

unit Providers.GraphQL;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IF DEFINED(USE_GRAPHQL) AND (DEFINED(USE_GRAPHQL_SERVER) OR DEFINED(USE_GRAPHQL_CLIENT))}

uses
{$IFDEF USE_GRAPHQL_SERVER}
  Providers.Connections           // IConnection (core, sem gate) - parametro de FromConnection
  , GraphQL.Schema                // IGraphQLSchema, TGraphQLSchemaBuilder (construcao manual)
  , GraphQL.Server.Indy           // TGraphQLIndyServer (host Indy TIdHTTPServer)
  , GraphQL.Server.Introspection  // InstallIntrospectionResolvers
  , GraphQL.Exceptions            // EGraphQLSchemaException + ERR_GRAPHQL_SCHEMA (guard do builder)
  {$IF DEFINED(USE_DATABASE) AND DEFINED(USE_QUERY_BUILDER)}
  , Providers.Database            // ICatalogReader + TProvidersDatabase.NewCatalogReader (slice Main/)
  , GraphQL.Schema.Factory        // TGraphQLSchemaFactory.FromMetadata (schema a partir do ORM)
  , GraphQL.Server.OrmResolvers   // InstallOrmResolvers (resolvers ORM, anti-N+1)
  {$ENDIF}
{$ENDIF}
{$IFDEF USE_GRAPHQL_CLIENT}
  {$IFDEF USE_GRAPHQL_SERVER}, {$ENDIF}GraphQL.Value  // TGraphQLValue (Data/Variables no cliente)
  , GraphQL.Client                // IGraphQLClient, IGraphQLResponse, NewGraphQLClient
  , GraphQL.Client.Query          // IGraphQLQuery, NewGraphQLQuery
  , GraphQL.Client.Introspection  // IGraphQLRemoteSchema, FetchSchema
{$ENDIF}
  ;

type
{$IFDEF USE_GRAPHQL_SERVER}
  { --- Re-export dos contratos do lado servidor (o consumidor nomeia-os via este slice) --- }
  IGraphQLSchema        = GraphQL.Schema.IGraphQLSchema;
  TGraphQLSchemaBuilder = GraphQL.Schema.TGraphQLSchemaBuilder;   // construcao manual de schema (fluent-ish)
  {$IF DEFINED(USE_DATABASE) AND DEFINED(USE_QUERY_BUILDER)}
  TGraphQLSchemaFactory = GraphQL.Schema.Factory.TGraphQLSchemaFactory;  // schema a partir do catalogo ORM
  ICatalogReader        = Providers.Database.ICatalogReader;             // catalogo normalizado (SSOT de metadados)
  {$ENDIF}

  { Builder fluente do servidor GraphQL - contrato NOVO desta slice (o modulo
    NAO tem uma IGraphQLServer: expoe pecas - FromMetadata / InstallOrmResolvers /
    InstallIntrospectionResolvers / TGraphQLIndyServer - que TEM de ser
    compostas). Esta interface compoe essas pecas num fluxo fluente, com um
    metodo por passo real (sem esconder passos obrigatorios). Materializa e
    detem o TGraphQLIndyServer no Start; liberta-o no Destroy da implementacao. }
  IProvidersGraphQLServer = interface
    ['{A7C3F1E8-2B94-4D06-9E7A-3F5B1C8D0426}']
    {$IF DEFINED(USE_DATABASE) AND DEFINED(USE_QUERY_BUILDER)}
    { ORM-backed (caso de uso principal): gera o schema a partir do catalogo da
      conexao (FromMetadata) e anexa os resolvers ORM (InstallOrmResolvers) sobre
      a MESMA conexao + schema (anti-N+1). @param ACatalogSchema schema/owner do
      catalogo ('' = default do driver). }
    function FromConnection(const AConnection: Providers.Connections.IConnection;
      const ACatalogSchema: string = ''): IProvidersGraphQLServer;
    {$ENDIF}
    { Schema ja construido (TGraphQLSchemaBuilder manual ou SDL) + resolvers ja
      anexados pelo chamador. }
    function FromSchema(const ASchema: IGraphQLSchema): IProvidersGraphQLServer;
    function Port(const APort: Integer): IProvidersGraphQLServer;
    function Validate(const AValidate: Boolean): IProvidersGraphQLServer;
    function WithIntrospection(const AEnabled: Boolean = True): IProvidersGraphQLServer;
    { Materializa o TGraphQLIndyServer (se ainda nao existir) e inicia-o. Instala
      os resolvers de introspection uma unica vez, se WithIntrospection(True). }
    function Start: IProvidersGraphQLServer;
    function Stop: IProvidersGraphQLServer;
    function Active: Boolean;
    { Schema construido (para PrintSDL/FindType/...); nil antes de FromConnection/FromSchema. }
    function Schema: IGraphQLSchema;
  end;
{$ENDIF}

{$IFDEF USE_GRAPHQL_CLIENT}
  { --- Re-export dos contratos do lado cliente --- }
  IGraphQLClient       = GraphQL.Client.IGraphQLClient;
  IGraphQLResponse     = GraphQL.Client.IGraphQLResponse;
  IGraphQLQuery        = GraphQL.Client.Query.IGraphQLQuery;
  IGraphQLRemoteSchema = GraphQL.Client.Introspection.IGraphQLRemoteSchema;
{$ENDIF}

  { Slice da fachada TProviders para o modulo GraphQL. A F10 liga
    TProviders.NewGraphQLServer/NewGraphQLClient a estes membros - sem duplicar
    logica. }
  TProvidersGraphQL = class
  public
{$IFDEF USE_GRAPHQL_SERVER}
    { Builder fluente do servidor (IProvidersGraphQLServer). Uso tipico:
        TProviders.NewGraphQLServer.FromConnection(conn, 'public').Port(8080).Start; }
    class function NewServer: IProvidersGraphQLServer; static;
{$ENDIF}
{$IFDEF USE_GRAPHQL_CLIENT}
    { Cliente GraphQL fluente (IGraphQLClient) - delega em NewGraphQLClient
      (GraphQL.Client). }
    class function NewClient: IGraphQLClient; overload; static;
    { Conveniencia: cliente ja com o endpoint definido. }
    class function NewClient(const AEndpoint: string): IGraphQLClient; overload; static;
    { Builder fluente do documento GraphQL (IGraphQLQuery) - delega em
      NewGraphQLQuery (GraphQL.Client.Query). }
    class function NewQuery: IGraphQLQuery; static;
    { Introspecao remota: modelo do schema do servidor via cliente - delega em
      FetchSchema (GraphQL.Client.Introspection). }
    class function FetchRemoteSchema(const AClient: IGraphQLClient): IGraphQLRemoteSchema; static;
{$ENDIF}
  end;

{$ENDIF} // USE_GRAPHQL AND (USE_GRAPHQL_SERVER OR USE_GRAPHQL_CLIENT)

implementation

{$IF DEFINED(USE_GRAPHQL) AND (DEFINED(USE_GRAPHQL_SERVER) OR DEFINED(USE_GRAPHQL_CLIENT))}

{$IFDEF USE_GRAPHQL_SERVER}

const
  DEFAULT_GRAPHQL_PORT = 8080;

type
  { Implementacao do builder fluente do servidor. Orquestra as pecas do modulo;
    detem o TGraphQLIndyServer (classe concreta) e liberta-o no Destroy. }
  TProvidersGraphQLServer = class(TInterfacedObject, IProvidersGraphQLServer)
  private
    FSchema: IGraphQLSchema;
    FServer: TGraphQLIndyServer;        // owned; criado em Start, liberto em Destroy
    FPort: Integer;
    FValidate: Boolean;
    FIntrospection: Boolean;
    FIntrospectionInstalled: Boolean;
  {$IF DEFINED(USE_DATABASE) AND DEFINED(USE_QUERY_BUILDER)}
    FConnection: Providers.Connections.IConnection;  // mantida viva enquanto os resolvers ORM existirem
    FMeta: ICatalogReader;
  {$ENDIF}
  public
    constructor Create;
    destructor Destroy; override;
  {$IF DEFINED(USE_DATABASE) AND DEFINED(USE_QUERY_BUILDER)}
    function FromConnection(const AConnection: Providers.Connections.IConnection;
      const ACatalogSchema: string = ''): IProvidersGraphQLServer;
  {$ENDIF}
    function FromSchema(const ASchema: IGraphQLSchema): IProvidersGraphQLServer;
    function Port(const APort: Integer): IProvidersGraphQLServer;
    function Validate(const AValidate: Boolean): IProvidersGraphQLServer;
    function WithIntrospection(const AEnabled: Boolean = True): IProvidersGraphQLServer;
    function Start: IProvidersGraphQLServer;
    function Stop: IProvidersGraphQLServer;
    function Active: Boolean;
    function Schema: IGraphQLSchema;
  end;

{ TProvidersGraphQLServer }

constructor TProvidersGraphQLServer.Create;
begin
  inherited Create;
  FServer := nil;
  FPort := DEFAULT_GRAPHQL_PORT;
  FValidate := True;
  FIntrospection := True;
  FIntrospectionInstalled := False;
end;

destructor TProvidersGraphQLServer.Destroy;
begin
  if Assigned(FServer) then
    FServer.Free;
  inherited Destroy;
end;

{$IF DEFINED(USE_DATABASE) AND DEFINED(USE_QUERY_BUILDER)}
function TProvidersGraphQLServer.FromConnection(
  const AConnection: Providers.Connections.IConnection;
  const ACatalogSchema: string): IProvidersGraphQLServer;
begin
  FConnection := AConnection;
  FMeta := Providers.Database.TProvidersDatabase.NewCatalogReader(AConnection);
  FSchema := GraphQL.Schema.Factory.TGraphQLSchemaFactory.FromMetadata(FMeta, ACatalogSchema);
  GraphQL.Server.OrmResolvers.InstallOrmResolvers(FSchema, FMeta, AConnection, ACatalogSchema);
  Result := Self;
end;
{$ENDIF}

function TProvidersGraphQLServer.FromSchema(const ASchema: IGraphQLSchema): IProvidersGraphQLServer;
begin
  FSchema := ASchema;
  Result := Self;
end;

function TProvidersGraphQLServer.Port(const APort: Integer): IProvidersGraphQLServer;
begin
  FPort := APort;
  Result := Self;
end;

function TProvidersGraphQLServer.Validate(const AValidate: Boolean): IProvidersGraphQLServer;
begin
  FValidate := AValidate;
  Result := Self;
end;

function TProvidersGraphQLServer.WithIntrospection(const AEnabled: Boolean): IProvidersGraphQLServer;
begin
  FIntrospection := AEnabled;
  Result := Self;
end;

function TProvidersGraphQLServer.Start: IProvidersGraphQLServer;
begin
  if not Assigned(FSchema) then
    raise EGraphQLSchemaException.Create(
      'GraphQL server: schema nao definido. Chame FromConnection ou FromSchema antes de Start.',
      ERR_GRAPHQL_SCHEMA);
  if FIntrospection and (not FIntrospectionInstalled) then
  begin
    GraphQL.Server.Introspection.InstallIntrospectionResolvers(FSchema);
    FIntrospectionInstalled := True;
  end;
  if not Assigned(FServer) then
    FServer := TGraphQLIndyServer.Create(FSchema, FPort, FValidate);
  FServer.Start;
  Result := Self;
end;

function TProvidersGraphQLServer.Stop: IProvidersGraphQLServer;
begin
  if Assigned(FServer) then
    FServer.Stop;
  Result := Self;
end;

function TProvidersGraphQLServer.Active: Boolean;
begin
  Result := Assigned(FServer) and FServer.Active;
end;

function TProvidersGraphQLServer.Schema: IGraphQLSchema;
begin
  Result := FSchema;
end;

{$ENDIF} // USE_GRAPHQL_SERVER

{ TProvidersGraphQL }

{$IFDEF USE_GRAPHQL_SERVER}
class function TProvidersGraphQL.NewServer: IProvidersGraphQLServer;
begin
  Result := TProvidersGraphQLServer.Create;
end;
{$ENDIF}

{$IFDEF USE_GRAPHQL_CLIENT}
class function TProvidersGraphQL.NewClient: IGraphQLClient;
begin
  Result := GraphQL.Client.NewGraphQLClient;
end;

class function TProvidersGraphQL.NewClient(const AEndpoint: string): IGraphQLClient;
begin
  Result := GraphQL.Client.NewGraphQLClient.Endpoint(AEndpoint);
end;

class function TProvidersGraphQL.NewQuery: IGraphQLQuery;
begin
  Result := GraphQL.Client.Query.NewGraphQLQuery;
end;

class function TProvidersGraphQL.FetchRemoteSchema(
  const AClient: IGraphQLClient): IGraphQLRemoteSchema;
begin
  Result := GraphQL.Client.Introspection.FetchSchema(AClient);
end;
{$ENDIF}

{$ENDIF} // USE_GRAPHQL AND (USE_GRAPHQL_SERVER OR USE_GRAPHQL_CLIENT)

end.
