{ =============================================================================
  Database - Fachada de UM banco (TDatabase, IDatabase)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.4.0
  FileVersion:    2.8.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           11/08/2026

  FASE 5 Onda 4-cont (revisao F5), Fatia B-e (ULTIMA fatia da Fatia B) - ver
  comentario completo em Databases.Interfaces.IDatabase. TDatabase COMPOE
  ISchemas (campo FSchemas, TSchemas.New) e USA ICatalogReader/IDialect
  INTERNAMENTE (unidades gated por USE_DATABASE, importadas num bloco
  proprio no uses - mesmo padrao ja usado por Database.Schema para
  Database.Dialect). Sem heranca de TTables/TSchemas - sem destructor
  proprio (FSchemas e uma interface, libertada automaticamente pelo
  TInterfacedObject).

  FASE 5 Onda 5 (fachada do modulo): TDatabase ganha `class function`
  factories - ponto unico de criacao do modulo inteiro, DELEGANDO as
  factories ja existentes de cada peca (Databases/Metadata/QueryBuilder/
  QueryTransformer/SchemaSync/UnitOfWork/EntityManager + criacao trivial de
  Table/Tables/Schema/Field/Fields). Ver comentario completo na declaracao
  da classe (secao "Onda 5") e em Databases.Interfaces (barrel do modulo).

  Changelog (file):
  - 2.8.0 (11/08/2026): F8 Onda 8.6 -- SetLogger(const ALogger: ILogger):
    IDatabase acrescentado a TDatabase, guardado por define USE_LOGGERS.
    Apenas na CLASSE (nao no contrato IDatabase) - mesmo padrao "classe
    apenas" de TConnection: IDatabase nao expoe nenhum evento/hook fluente
    (ao contrario de IPoolConnections, cujos 11 hooks sao contrato), entao
    SetLogger e' aditivo puro e NAO altera o contrato publico. Piggyback nos
    3 pontos operacionais DDL mais representativos (nenhum ponto de chamada
    novo, sem try/except inventado - o modulo nao tinha nenhum): CreateDatabase
    (Debug antes / Success apos ExecuteCommand), DropDatabase (Warning antes -
    destrutivo / Success apos), ApplyStructure (Debug antes / Success apos a
    materializacao de todos os schemas). As restantes operacoes (6x schema-por-
    nome, ~15x serializacao JSON/lancadores fluentes) ficam NAO instrumentadas
    de proposito (nao e' preciso instrumentar tudo para observabilidade util,
    mesmo criterio de AD/Connections/PoolConnections). Default = TNullLogger
    (Loggers.NullLogger, zero overhead); SetLogger(nil) reverte ao default.
    Novo uses (interface, gated USE_LOGGERS): Loggers.Interfaces + Loggers.
    NullLogger. Validado isolado: src/testes/Loggers/spike_database_setlogger.dpr
    + patch em .workspace/patches/f8-onda8.6-database-setlogger/ (pasta bloqueada).
  - 2.7.0 (30/07/2026): Onda S3b (ADITIVO - materializacao do merge, ver
    Databases.Interfaces 3.3.0) - ApplyStructure(AConnection): IDatabase
    agrega o ISchema.ApplyStructure de todos os schemas de
    FSchemas.GetSchemasList; zero SQL novo, so orquestracao (mesmo padrao de
    ToDDL, acima).
  - 2.6.0 (30/07/2026): Onda S4 (ADITIVO - eixo FULL, ver Databases.Interfaces
    3.2.0) - ToFullJSON (COMPOE StructureToJSON+ToJSON)/FromFullJSON/
    MergeFullFromJSON (decompoem via Database.Helpers.JSON.JSONExtractMember,
    estrutura antes de dado) + Export(AWithData)/Import(AJSON, AWithData,
    AMerge) ergonomicos. Sem covariancia (TDatabase implementa SO IDatabase)
    - declaracao directa. Novo overload Export(AWithData, AQuery:
    IQueryBuilder), gated USE_DATABASE - delega a TryExportQueryData (novo
    helper Database.Helpers.Export, SSOT partilhado com ITable/ISchema.
    Export - isola Data.DB/Serialize numa unit PROPRIA sem TRowStatus, ver
    comentario completo no uses de Database.Table.pas); fallback na
    Connection fluente deste IDatabase (FConnection). Novo uses
    (implementation, dentro do bloco USE_DATABASE ja existente):
    Database.Helpers.Export. Zero mudanca nos metodos pre-existentes.
  - 2.5.0 (29/07/2026): Onda S3 (ADITIVO - eixo SQL, ver Databases.Interfaces
    3.1.0) - ToDDL: string (agrega o ISchema.ToDDL de todos os schemas de
    FSchemas.GetSchemasList; zero SQL novo, so orquestracao - mesmo padrao ja
    usado por ToJSON/StructureToJSON, que delegam integralmente a ISchemas).
  - 2.4.0 (29/07/2026): Onda S2-a (ADITIVO, simetria To/From/Merge) -
    IDatabase ganha StructureMergeFromJSON - le "database" em modo patch
    (mantem FDatabaseName se ausente) e delega a ISchemas.
    StructureMergeFromJSON (localiza/cria schemas por SchemaName, nunca
    remove); mesmo padrao de composicao de StructureFromJSON. Zero mudanca
    nos metodos pre-existentes.
  - 2.3.0 (26/07/2026): conformidade F5 (onda C1, plano
    providersorm-v3-f5-conformidade) - A1: as class functions de FACHADA
    QueryBuilder/QueryTransformer(AConnection) passam a ser gated por
    USE_QUERY_BUILDER/USE_QUERY_TRANSFORMER (deixam de ser decorativas - o mesmo
    define que o modulo Printers ja honra); a interface IQueryBuilder e o
    TQueryBuilder.New permanecem NUCLEO sob USE_DATABASE (o F7 Parameters.Database
    consome-os diretamente, nao por esta fachada). ModuleVersion re-sincronizado
    2.9.0 -> 3.0.0. Gate: 4 alvos ProvidersV3 EXIT=0 + smoke_parameters_db FAIL=0.
  - 2.2.0 (25/07/2026): Onda R2 (f5-repair, re-layering por responsabilidade,
    ADITIVO) - TDatabase ganha 3 lancadores NOVOS (Views: IViews/Procedures:
    IProcedures/Functions: IFunctions), Connection-bound a FConnection, no
    MESMO bloco gated USE_DATABASE dos lancadores ja existentes (Metadata/
    Synchronize/QueryBuilder/UnitOfWork/Dialect, Onda 7) - cada um so agrega
    (Database.Views.TViews.New.Connection(FConnection) e equivalentes), sem
    logica propria. Novo uses (implementation, dentro do bloco USE_DATABASE
    ja existente): Database.Views + Database.Procedures + Database.Functions
    (units NOVAS). Zero mudanca nos lancadores/factories pre-existentes.
  - 2.1.0 (15/07/2026): Onda 7 (camada de lancadores fluentes, ADITIVO) -
    IDatabase ganha metodos de INSTANCIA (Connection-bound a FConnection,
    zero parametros) que DELEGAM aos mesmos modulos ja usados pelas class
    functions da Onda 5: Metadata/Synchronize/QueryBuilder/UnitOfWork/
    Dialect/EntityManager (gated USE_ENTITY_MANAGER, "em branco" - so
    Connection-bound, sem MapTable/Table) - todos gated USE_DATABASE - +
    IdentityMap<TObject>/TypeDatabase (ungated). COLISAO DE NOME resolvida
    com `overload`: as class functions Metadata/QueryBuilder/Synchronize/
    UnitOfWork/EntityManager(AConnection: IConnection) ja existentes (Onda 5)
    ganham `overload;` para coexistir com os novos metodos de INSTANCIA
    homonimos sem parametros - verificado por compilacao real (dcc32+fpc32
    mode delphi) que Object Pascal resolve `TDatabase.Foo(conn)` (chamada
    via CLASSE) para a class function e `instancia.Foo` (chamada via
    OBJECTO) para o metodo de instancia, sem ambiguidade. Novo uses
    (interface): Databases.Interfaces (ITypeDatabase, ungated) +
    Databases.Interfaces (IDialect, gated USE_DATABASE - precisos
    aqui porque os METODOS que os devolvem sao declarados na seccao
    interface da classe). Novo uses (implementation): Database.IdentityMap +
    Database.TypeDatabase (Database.Dialect ja presente). Zero mudanca nas
    class functions/criacao trivial pre-existentes (Onda 5 intacta).
  - 2.0.0 (14/07/2026): Onda 5 - fachada do modulo: class functions
    Databases/Metadata/QueryBuilder/QueryTransformer/SchemaSync/UnitOfWork/
    EntityManager(AConnection) + Table/Tables/Schema/Field/Fields (sem
    parametros); uses ganha Database.Table/Tables/Field/Fields[.Interfaces],
    Databases[.Interfaces], Database.UnitOfWork[.Interfaces] (sempre) +
    Database.QueryBuilder/QueryTransformer/SchemaSync[.Interfaces] +
    Database.EntityManager[.Interfaces] (gated); Database.CatalogReader[.Interfaces]
    mudou do uses da implementation para o da interface (ICatalogReader passou a
    tipo de retorno publico). Zero mudanca no comportamento de IDatabase
    (Fatia B-e preservada tal e qual).
  - 1.0.0 (14/07/2026): versao inicial (Fatia B-e).
  ============================================================================= }
unit Database;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}
interface

{$I ORM.Defines.inc}

uses
  Commons.Types,
  Database.Schemas,
  Database.Schema,
  Database.Table,
  Database.Tables,
  Database.Field,
  Database.Fields,
  Databases.Interfaces,
  Databases,
  Database.UnitOfWork,
  Connections.Interfaces
{$IFDEF USE_LOGGERS}
  { F8 Onda 8.6 -- SetLogger (observabilidade estrutural, ver header). ILogger
    e' tipo do campo FLogger e do parametro de SetLogger (ambos na seccao
    INTERFACE da classe), por isso Loggers.Interfaces fica no uses da interface;
    Loggers.NullLogger (default zero-overhead) segue junto. Nenhuma das 2
    depende de USE_DATABASE nem do modulo Database (sem ciclo). }
  , Loggers.Interfaces
  , Loggers.NullLogger
{$ENDIF}
  { Onda 7 (camada de lancadores) - ITypeDatabase e' sempre disponivel (a
    unit-fonte nao tem gate proprio), usada pelo metodo de instancia
    TDatabase.TypeDatabase. }
{$IFDEF USE_DATABASE}
  , Database.CatalogReader
  , Database.QueryBuilder
  , Database.Synchronize
  { Onda 7 - IDialect precisa de estar na seccao INTERFACE (nao so na
    implementation, ja presente mais abaixo) porque TDatabase.Dialect e' um
    metodo PUBLICO declarado na classe, aqui na interface do ficheiro. }
{$IFDEF USE_ENTITY_MANAGER}
  , Database.EntityManager
{$ENDIF}
{$ENDIF}
  ;

type
  TDatabase = class(TInterfacedObject, IDatabase)
  private
    FConnection: IConnection;
    FDatabaseName: string;
    FDatabaseTypes: TDatabaseTypes;
    FSchemas: ISchemas;
{$IFDEF USE_LOGGERS}
    FLogger: ILogger; // F8 Onda 8.6 - default TNullLogger (zero overhead)
{$ENDIF}
  public
    constructor Create;
    class function New: IDatabase; overload;
    class function New(const AConnection: IConnection): IDatabase; overload;

    { Onda 5 - fachada do MODULO (class functions, ponto unico de criacao das
      operacoes do ecossistema; DELEGAM integralmente as factories ja
      existentes de cada peca - "so agregam", nao reimplementam logica). }
    class function Databases(const AConnection: IConnection): IDatabases;
{$IFDEF USE_DATABASE}
    class function Metadata(const AConnection: IConnection): ICatalogReader; overload;
  {$IFDEF USE_QUERY_BUILDER}
    { A1 (conformidade F5): a ENTRADA DE FACHADA do builder e OPCIONAL - gated por
      USE_QUERY_BUILDER (o mesmo define que o modulo Printers honra). A interface
      IQueryBuilder e o TQueryBuilder.New permanecem NUCLEO sob USE_DATABASE (o F7
      Parameters.Database consome-os diretamente, nao por esta fachada). }
    class function QueryBuilder(const AConnection: IConnection): IQueryBuilder; overload;
  {$ENDIF}
    { IQueryTransformer nao tem Connection(AConnection) propria (so
      Source(AQuery: IQueryBuilder) - a conexao vem do builder envolvido);
      a fachada devolve um transformer ja com um QueryBuilder vazio ligado a
      AConnection como Source por omissao (o caller substitui livremente
      via .Source(outroBuilder) se preferir construir a query base a mao). }
  {$IFDEF USE_QUERY_TRANSFORMER}
    class function QueryTransformer(const AConnection: IConnection): IQueryTransformer;
  {$ENDIF}
    { SchemaSync (Onda 5.5) expoe 4 pecas (ISchemaDefinition/ISchemaInspector/
      ISchemaComparer/ISynchronize) - nao ha uma interface unica
      "ISchemaSync" no codigo-fonte. O ISynchronize e devolvido aqui por
      ser o ponto de entrada que efectivamente APLICA a sincronizacao
      (Plan/Sync) e a UNICA das 4 pecas cuja factory corresponde 1:1 a
      assinatura (const AConnection): I... pedida pela fachada; as outras 3
      continuam acessiveis directamente via TSchemaDefinition.New/
      TSchemaInspector.New(AConn)/TSchemaComparer.New (Database.Synchronize). }
    class function Synchronize(const AConnection: IConnection): ISynchronize; overload;
    class function UnitOfWork(const AConnection: IConnection): IUnitOfWork; overload;
{$IFDEF USE_ENTITY_MANAGER}
    class function EntityManager(const AConnection: IConnection): IEntityManager; overload;
{$ENDIF}
{$ENDIF}

    { Onda 5 - criacao trivial das pecas de composicao (ponto unico de
      criacao do modulo). "Schemas" (plural) NAO tem factory de classe aqui
      de proposito - colidiria com o metodo de INSTANCIA Schemas: ISchemas
      ja existente (getter dos schemas DESTE banco, abaixo); para criar um
      ISchemas vazio autonomo usar TSchemas.New directamente
      (unit Database.Schemas). }
    class function Table: ITable;
    class function Tables: ITables;
    class function Schema: ISchema;
    class function Field: IField; overload;
    class function Field(const AColumn, AColumnType: string; AIsNull, AIsPKey: Boolean): IField; overload;
    class function Fields: IFields;

    { IDatabase }
    function Connection(const AConnection: IConnection): IDatabase; overload;
    function Connection: IConnection; overload;
    function DatabaseName(const AValue: string): IDatabase; overload;
    function DatabaseName: string; overload;
    function DatabaseTypes(const AValue: TDatabaseTypes): IDatabase; overload;
    function DatabaseTypes: TDatabaseTypes; overload;

    function Schemas: ISchemas;
    function LoadSchemasFromConnection: IDatabase;

    function ToJSON: string;
    function FromJSON(const AJSON: string): IDatabase;
    function MergeFromJSON(const AJSON: string): IDatabase;
    function StructureToJSON: string;
    function StructureFromJSON(const AJSON: string): IDatabase;
    { Onda S2-a (ADITIVO) - ver comentario completo em
      Databases.Interfaces.IDatabase.StructureMergeFromJSON. }
    function StructureMergeFromJSON(const AJSON: string): IDatabase;

    function CreateDatabaseSQL: string;
    function DropDatabaseSQL: string;
    function CreateDatabase(const AConnection: IConnection): Integer;
    function DropDatabase(const AConnection: IConnection): Integer;
    { Onda D - manipulacao de SCHEMA (por nome) neste banco. }
    function CreateSchemaSQL(const ASchemaName: string): string;
    function DropSchemaSQL(const ASchemaName: string): string;
    function RenameSchemaSQL(const AOldName, ANewName: string): string;
    function CreateSchema(const AConnection: IConnection; const ASchemaName: string): Integer;
    function DropSchema(const AConnection: IConnection; const ASchemaName: string): Integer;
    function RenameSchema(const AConnection: IConnection; const AOldName, ANewName: string): Integer;

    { Onda S3 - eixo SQL - ver comentario completo em
      Databases.Interfaces.IDatabase.ToDDL. }
    function ToDDL: string;

    { Onda S3b (ADITIVO) - MATERIALIZACAO do merge - ver comentario completo
      em Databases.Interfaces.IDatabase.ApplyStructure. }
    function ApplyStructure(const AConnection: IConnection): IDatabase;

    { Onda S4 (ADITIVO) - eixo FULL - ver comentario completo em
      Databases.Interfaces.IDatabase. Sem covariancia (TDatabase implementa
      SO IDatabase, sem heranca de ISchemas/ITables/IFields) - declaracao
      directa, sem clausula de resolucao de interface. }
    function ToFullJSON: string;
    function FromFullJSON(const AJSON: string): IDatabase;
    function MergeFullFromJSON(const AJSON: string): IDatabase;

    { Export/Import ergonomicos (Onda S4, ADITIVO) - ver comentario completo
      em Databases.Interfaces.ITable.Export/Import (mesma semantica, incl.
      o overload Export(AWithData, AQuery)). }
    function Export(const AWithData: Boolean): string; overload;
{$IFDEF USE_DATABASE}
    function Export(const AWithData: Boolean; const AQuery: IQueryBuilder): string; overload;
{$ENDIF}
    function Import(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): IDatabase;

    { Onda 7 - camada de lancadores fluentes: metodos de INSTANCIA
      (Connection-bound a FConnection, zero parametros); ver comentario
      completo em Databases.Interfaces.IDatabase e no changelog (topo do
      ficheiro) sobre a colisao de nome com as class functions da Onda 5
      (resolvida com `overload`). }
{$IFDEF USE_DATABASE}
    function Metadata: ICatalogReader; overload;
    function Synchronize: ISynchronize; overload;
    function QueryBuilder: IQueryBuilder; overload;
    function UnitOfWork: IUnitOfWork; overload;
    function Dialect: IDialect;
    { Onda R2 (f5-repair) - colecoes de objectos de BANCO, Connection-bound
      a FConnection (mesmo padrao dos lancadores acima). }
    function Views: IViews;
    function Procedures: IProcedures;
    function Functions: IFunctions;
    function Triggers: ITriggers;
    function Rules: IRules;
{$IFDEF USE_ENTITY_MANAGER}
    function EntityManager: IEntityManager; overload;
{$ENDIF}
{$ENDIF}
    function IdentityMap: IIdentityMap<TObject>;
    function TypeDatabase: ITypeDatabase;

{$IFDEF USE_LOGGERS}
    { F8 Onda 8.6 - SetLogger (observabilidade estrutural). Apenas na CLASSE,
      NAO no contrato IDatabase - IDatabase nao expoe eventos/hooks fluentes
      (padrao "classe apenas" de TConnection, ao contrario de IPoolConnections).
      Aditivo puro: o contrato publico nao muda. Piggyback nos 3 pontos DDL
      mais representativos (CreateDatabase/DropDatabase/ApplyStructure) - sem
      pontos de chamada novos. Default = TNullLogger; SetLogger(nil) reverte. }
    function SetLogger(const ALogger: ILogger): IDatabase;
{$ENDIF}
  end;

implementation

uses
{$IF DEFINED(FPC)}
  SysUtils, fpjson, jsonparser,
{$ELSE}
  System.SysUtils, System.JSON,
{$ENDIF}
  { Onda 7 (camada de lancadores) - IdentityMap<TObject>/TypeDatabase sao
    ungated (nao dependem de USE_DATABASE), so usadas dentro dos corpos dos
    metodos (implementation chega). }
  Database.IdentityMap,
  Database.TypeDatabase,
  Database.Helpers.JSON
{$IFDEF USE_DATABASE}
  { Onda S4 - Export(AWithData, AQuery) delega a TryExportQueryData
    (Database.Helpers.Export - SSOT partilhado com ITable/ISchema.Export;
    isola Data.DB/Serialize numa unit PROPRIA, sem TRowStatus, ver
    comentario completo no uses de Database.Table.pas). }
  , Database.Helpers.Export
  { Database.CatalogReader[.Interfaces] mudou para o uses da INTERFACE (Onda 5) -
    ICatalogReader passou a tipo de retorno publico em TDatabase.Metadata; fica
    automaticamente visivel aqui, sem reimportar. Databases.Interfaces
    (IDialect) idem, ja movida para o uses da INTERFACE na Onda 7 (Dialect e'
    tambem um metodo publico) - so Database.Dialect (concreto) precisa de
    ficar aqui. }
  , Database.Dialect
  { Onda R2 (f5-repair) - colecoes de objectos de BANCO (Views/Procedures/
    Functions), so usadas dentro dos corpos dos metodos (implementation
    chega - IViews/IProcedures/IFunctions ja visiveis via Databases.
    Interfaces, presente no uses da INTERFACE). }
  , Database.Views
  , Database.Procedures
  , Database.Functions
  , Database.Triggers              // Onda F3 - TTriggers (colecao de TRIGGERS do banco, Connection-bound)
  , Database.Rules                 // Onda F4 - TRules (colecao de RULES do banco, Connection-bound; PG/SQLServer)
{$ENDIF}
  ;

{ Escaper RFC 8259 - Onda C5 (M7, conformidade F5): delega ao SSOT unico
  Database.Helpers.JSON.JSONQuoteString (antes era uma copia local
  DatabaseJSONQuoteString, byte-identica as outras 7 do modulo - regra #14).
  Usado so para as chaves "database" do eixo estrutura - os VALORES
  (schemas) sao sempre delegados a ISchema.StructureToJSON, que ja escapa
  por conta propria. }

constructor TDatabase.Create;
begin
  inherited Create;
  FDatabaseTypes := dtNone;
  FSchemas := TSchemas.New;
{$IFDEF USE_LOGGERS}
  FLogger := TNullLogger.New; // F8 Onda 8.6 - default zero-overhead
{$ENDIF}
end;

{$IFDEF USE_LOGGERS}
function TDatabase.SetLogger(const ALogger: ILogger): IDatabase;
begin
  if Assigned(ALogger) then
    FLogger := ALogger
  else
    FLogger := TNullLogger.New;
  Result := Self;
end;
{$ENDIF}

class function TDatabase.New: IDatabase;
begin
  Result := TDatabase.Create;
end;

class function TDatabase.New(const AConnection: IConnection): IDatabase;
begin
  Result := TDatabase.Create;
  Result.Connection(AConnection);
end;

{ ===== Onda 5 - fachada do MODULO (ponto unico de criacao; cada factory
  DELEGA integralmente a factory ja existente da respectiva peca - "so
  agrega", nao reimplementa logica). ===== }

class function TDatabase.Databases(const AConnection: IConnection): IDatabases;
begin
  Result := TDatabases.New.Connection(AConnection);
end;

{$IFDEF USE_DATABASE}
class function TDatabase.Metadata(const AConnection: IConnection): ICatalogReader;
begin
  Result := TCatalogReader.New(AConnection);
end;

{$IFDEF USE_QUERY_BUILDER}
class function TDatabase.QueryBuilder(const AConnection: IConnection): IQueryBuilder;
begin
  Result := Database.QueryBuilder.TQueryBuilder.New.Connection(AConnection);
end;
{$ENDIF}

{$IFDEF USE_QUERY_TRANSFORMER}
class function TDatabase.QueryTransformer(const AConnection: IConnection): IQueryTransformer;
begin
  Result := Database.QueryBuilder.TQueryTransformer.New;
  Result.Source(Database.QueryBuilder.TQueryBuilder.New.Connection(AConnection));
end;
{$ENDIF}

class function TDatabase.Synchronize(const AConnection: IConnection): ISynchronize;
begin
  Result := Database.Synchronize.TSynchronize.New(AConnection);
end;

class function TDatabase.UnitOfWork(const AConnection: IConnection): IUnitOfWork;
begin
  Result := Database.UnitOfWork.TUnitOfWork.New.Connection(AConnection);
end;

{$IFDEF USE_ENTITY_MANAGER}
class function TDatabase.EntityManager(const AConnection: IConnection): IEntityManager;
begin
  Result := Database.EntityManager.TEntityManager.New.Connection(AConnection);
end;
{$ENDIF}
{$ENDIF}

{ ===== Onda 5 - criacao trivial das pecas de composicao (ponto unico de
  criacao do modulo; "Schemas" plural fica de fora de proposito - ver
  comentario na declaracao da classe). ===== }

class function TDatabase.Table: ITable;
begin
  Result := Database.Table.TTable.New;
end;

class function TDatabase.Tables: ITables;
begin
  Result := Database.Tables.TTables.New;
end;

class function TDatabase.Schema: ISchema;
begin
  Result := Database.Schema.TSchema.New;
end;

class function TDatabase.Field: IField;
begin
  Result := Database.Field.TField.New;
end;

class function TDatabase.Field(const AColumn, AColumnType: string; AIsNull, AIsPKey: Boolean): IField;
begin
  Result := Database.Field.TField.New(AColumn, AColumnType, AIsNull, AIsPKey);
end;

class function TDatabase.Fields: IFields;
begin
  Result := Database.Fields.TFields.New;
end;

function TDatabase.Connection(const AConnection: IConnection): IDatabase;
begin
  FConnection := AConnection;
  FSchemas.Connection(AConnection);
  if AConnection <> nil then
  begin
    FDatabaseTypes := AConnection.DatabaseType;
    if Trim(FDatabaseName) = '' then
      FDatabaseName := AConnection.Database;
  end;
  Result := Self;
end;

function TDatabase.Connection: IConnection;
begin
  Result := FConnection;
end;

function TDatabase.DatabaseName(const AValue: string): IDatabase;
begin
  FDatabaseName := AValue;
  Result := Self;
end;

function TDatabase.DatabaseName: string;
begin
  Result := FDatabaseName;
end;

function TDatabase.DatabaseTypes(const AValue: TDatabaseTypes): IDatabase;
begin
  FDatabaseTypes := AValue;
  Result := Self;
end;

function TDatabase.DatabaseTypes: TDatabaseTypes;
begin
  Result := FDatabaseTypes;
end;

function TDatabase.Schemas: ISchemas;
begin
  Result := FSchemas;
end;

function TDatabase.LoadSchemasFromConnection: IDatabase;
{$IFDEF USE_DATABASE}
var
  LMeta: ICatalogReader;
  LNames: TStringArray;
  I: Integer;
  LSchema: ISchema;
{$ENDIF}
begin
  { Descobre os schemas do banco via ICatalogReader (Onda 5.1, intacto) -
    substitui o conteudo de Schemas por completo. No-op silencioso se
    USE_DATABASE estiver OFF, se nao houver Connection injectada, ou se a
    conexao nao estiver ligada. }
  Result := Self;
  FSchemas := TSchemas.New.Connection(FConnection);
{$IFDEF USE_DATABASE}
  if (FConnection = nil) or not FConnection.IsConnected then
    Exit;
  LMeta := TCatalogReader.New(FConnection);
  LNames := LMeta.SchemaNames(FDatabaseName);
  for I := 0 to High(LNames) do
  begin
    LSchema := TSchema.New.SchemaName(LNames[I]).Database(FDatabaseName);
    LSchema.Connection(FConnection);
    LSchema.DatabaseTypes(FDatabaseTypes);
    FSchemas.Add(LSchema);
  end;
{$ENDIF}
end;

function TDatabase.ToJSON: string;
begin
  { EIXO DADO - banco completo, delega integralmente a ISchemas (ja
    chave-nomeada por SchemaName, Fatia B-d); sem wrapper adicional (mesmo
    padrao "eixo dado puro" das fatias anteriores - o nome do banco fica so
    no eixo estrutura). }
  Result := FSchemas.ToJSON;
end;

function TDatabase.FromJSON(const AJSON: string): IDatabase;
begin
  Result := Self;
  FSchemas.FromJSON(AJSON);
end;

function TDatabase.MergeFromJSON(const AJSON: string): IDatabase;
begin
  Result := Self;
  FSchemas.MergeFromJSON(AJSON);
end;

function TDatabase.StructureToJSON: string;
var
  I: Integer;
  LBody: string;
  LList: TSchemaArray;
begin
  { EIXO ESTRUTURA - chaves database (DatabaseName) e schemas (array de
    ISchema.StructureToJSON, 1 por schema) - mesmo padrao do wrapper
    "schema"+"tables" do ISchema (Fatia B-d) um nivel acima. }
  LList := FSchemas.GetSchemasList;
  LBody := '';
  for I := 0 to High(LList) do
  begin
    if LBody <> '' then
      LBody := LBody + ',';
    LBody := LBody + LList[I].StructureToJSON;
  end;
  Result := '{"database":' + JSONQuoteString(FDatabaseName) +
    ',"schemas":[' + LBody + ']}';
end;

function TDatabase.StructureFromJSON(const AJSON: string): IDatabase;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
begin
  { EIXO ESTRUTURA - le a chave "database" (DatabaseName) diretamente aqui e
    delega a reconstrucao completa dos schemas a ISchemas.StructureFromJSON,
    que localiza a chave "schemas" no MESMO objeto AJSON, ignorando a chave
    "database" irma (StructureFromJSON de ISchemas so procura "schemas" -
    tolera chaves extra no objeto). Evita duplicar o parsing do array de
    schemas ja implementado em Database.Schemas. }
  Result := Self;
  if Trim(AJSON) = '' then
    Exit;
  LData := GetJSON(AJSON);
  if (not Assigned(LData)) or (not (LData is TJSONObject)) then
  begin
    if Assigned(LData) then
      LData.Free;
    Exit;
  end;
  LObj := TJSONObject(LData);
  try
    FDatabaseName := LObj.Get('database', FDatabaseName);
  finally
    LObj.Free;
  end;
  FSchemas.StructureFromJSON(AJSON);
end;
{$ELSE}
var
  LVal: TJSONValue;
  LObj: TJSONObject;
begin
  Result := Self;
  if Trim(AJSON) = '' then
    Exit;
  LVal := TJSONObject.ParseJSONValue(AJSON);
  if (not Assigned(LVal)) or (not (LVal is TJSONObject)) then
  begin
    if Assigned(LVal) then
      LVal.Free;
    Exit;
  end;
  LObj := TJSONObject(LVal);
  try
    FDatabaseName := LObj.GetValue<string>('database', FDatabaseName);
  finally
    LObj.Free;
  end;
  FSchemas.StructureFromJSON(AJSON);
end;
{$ENDIF}

function TDatabase.StructureMergeFromJSON(const AJSON: string): IDatabase;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
begin
  { Onda S2-a (ADITIVO) - le a chave "database" (patch - mantem
    FDatabaseName se ausente) e delega integralmente a
    ISchemas.StructureMergeFromJSON (localiza/cria schemas por SchemaName,
    nunca remove) - mesmo padrao de composicao de StructureFromJSON, acima,
    trocando so o metodo delegado (Merge em vez de replace). Evita duplicar
    o parsing do array de schemas ja implementado em Database.Schemas. }
  Result := Self;
  if Trim(AJSON) = '' then
    Exit;
  LData := GetJSON(AJSON);
  if (not Assigned(LData)) or (not (LData is TJSONObject)) then
  begin
    if Assigned(LData) then
      LData.Free;
    Exit;
  end;
  LObj := TJSONObject(LData);
  try
    FDatabaseName := LObj.Get('database', FDatabaseName);
  finally
    LObj.Free;
  end;
  FSchemas.StructureMergeFromJSON(AJSON);
end;
{$ELSE}
var
  LVal: TJSONValue;
  LObj: TJSONObject;
begin
  Result := Self;
  if Trim(AJSON) = '' then
    Exit;
  LVal := TJSONObject.ParseJSONValue(AJSON);
  if (not Assigned(LVal)) or (not (LVal is TJSONObject)) then
  begin
    if Assigned(LVal) then
      LVal.Free;
    Exit;
  end;
  LObj := TJSONObject(LVal);
  try
    FDatabaseName := LObj.GetValue<string>('database', FDatabaseName);
  finally
    LObj.Free;
  end;
  FSchemas.StructureMergeFromJSON(AJSON);
end;
{$ENDIF}

function TDatabase.CreateDatabaseSQL: string;
{$IFDEF USE_DATABASE}
var
  LDialect: IDialect;
{$ENDIF}
begin
  { DDL de nivel database (Fatia B-e) - resolve o dialecto SO por
    DatabaseTypes, sem exigir conexao (TDialect.ForDatabaseType); degrada
    graciosamente para string vazia se USE_DATABASE estiver OFF, se
    DatabaseName estiver vazio, ou se DatabaseTypes nunca tiver sido
    definido (dtNone). }
  Result := '';
{$IFDEF USE_DATABASE}
  if (Trim(FDatabaseName) = '') or (FDatabaseTypes = dtNone) then
    Exit;
  LDialect := TDialect.ForDatabaseType(FDatabaseTypes);
  Result := LDialect.CreateDatabaseSQL(FDatabaseName);
{$ENDIF}
end;

function TDatabase.DropDatabaseSQL: string;
{$IFDEF USE_DATABASE}
var
  LDialect: IDialect;
{$ENDIF}
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (Trim(FDatabaseName) = '') or (FDatabaseTypes = dtNone) then
    Exit;
  LDialect := TDialect.ForDatabaseType(FDatabaseTypes);
  Result := LDialect.DropDatabaseSQL(FDatabaseName);
{$ENDIF}
end;

function TDatabase.CreateDatabase(const AConnection: IConnection): Integer;
var
  LSQL: string;
begin
  Result := 0;
  if (AConnection = nil) or not AConnection.IsConnected then
    Exit;
  LSQL := CreateDatabaseSQL;
  if LSQL <> '' then
  begin
{$IFDEF USE_LOGGERS}
    FLogger.Debug(Format('CreateDatabase: iniciando (Database=%s)', [FDatabaseName]));
{$ENDIF}
    Result := AConnection.ExecuteCommand(LSQL);
{$IFDEF USE_LOGGERS}
    FLogger.Success(Format('CreateDatabase: OK (Database=%s)', [FDatabaseName]));
{$ENDIF}
  end;
end;

function TDatabase.DropDatabase(const AConnection: IConnection): Integer;
var
  LSQL: string;
begin
  Result := 0;
  if (AConnection = nil) or not AConnection.IsConnected then
    Exit;
  LSQL := DropDatabaseSQL;
  if LSQL <> '' then
  begin
{$IFDEF USE_LOGGERS}
    FLogger.Warning(Format('DropDatabase: removendo banco (Database=%s)', [FDatabaseName]));
{$ENDIF}
    Result := AConnection.ExecuteCommand(LSQL);
{$IFDEF USE_LOGGERS}
    FLogger.Success(Format('DropDatabase: OK (Database=%s)', [FDatabaseName]));
{$ENDIF}
  end;
end;

{ ===== Onda D - manipulacao de SCHEMA (por nome) neste banco =====
  <Op>SchemaSQL monta via a faceta IDialect.Schema (gated scSchemas: SQLite/
  Firebird/Access -> '' -> no-op); <Op>Schema(conn) executa idempotente via
  ICatalogReader.SchemaNames. Gated USE_DATABASE. }

function TDatabase.CreateSchemaSQL(const ASchemaName: string): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (Trim(ASchemaName) = '') or (FDatabaseTypes = dtNone) then Exit;
  Result := TDialect.ForDatabaseType(FDatabaseTypes).Schema.CreateSQL(Trim(ASchemaName));
{$ENDIF}
end;

function TDatabase.DropSchemaSQL(const ASchemaName: string): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (Trim(ASchemaName) = '') or (FDatabaseTypes = dtNone) then Exit;
  Result := TDialect.ForDatabaseType(FDatabaseTypes).Schema.DropSQL(Trim(ASchemaName));
{$ENDIF}
end;

function TDatabase.RenameSchemaSQL(const AOldName, ANewName: string): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (Trim(AOldName) = '') or (Trim(ANewName) = '') or (FDatabaseTypes = dtNone) then Exit;
  Result := TDialect.ForDatabaseType(FDatabaseTypes).Schema.RenameSQL(Trim(AOldName), Trim(ANewName));
{$ENDIF}
end;

function TDatabase.CreateSchema(const AConnection: IConnection; const ASchemaName: string): Integer;
{$IFDEF USE_DATABASE}
var
  LNames: TStringArray;
  I: Integer;
  LSQL: string;
{$ENDIF}
begin
  Result := 0;
{$IFDEF USE_DATABASE}
  if (AConnection = nil) or not AConnection.IsConnected then Exit;
  if Trim(ASchemaName) = '' then Exit;
  { idempotente: so cria se ainda NAO existir }
  LNames := Database.CatalogReader.TCatalogReader.New(AConnection).SchemaNames;
  for I := 0 to High(LNames) do
    if SameText(Trim(LNames[I]), Trim(ASchemaName)) then Exit;
  LSQL := TDialect.ForConnection(AConnection).Schema.CreateSQL(Trim(ASchemaName));
  if Trim(LSQL) <> '' then Result := AConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

function TDatabase.DropSchema(const AConnection: IConnection; const ASchemaName: string): Integer;
{$IFDEF USE_DATABASE}
var
  LNames: TStringArray;
  I: Integer;
  LFound: Boolean;
  LSQL: string;
{$ENDIF}
begin
  Result := 0;
{$IFDEF USE_DATABASE}
  if (AConnection = nil) or not AConnection.IsConnected then Exit;
  if Trim(ASchemaName) = '' then Exit;
  { idempotente: so remove se existir }
  LNames := Database.CatalogReader.TCatalogReader.New(AConnection).SchemaNames;
  LFound := False;
  for I := 0 to High(LNames) do
    if SameText(Trim(LNames[I]), Trim(ASchemaName)) then
    begin
      LFound := True;
      Break;
    end;
  if not LFound then Exit;
  LSQL := TDialect.ForConnection(AConnection).Schema.DropSQL(Trim(ASchemaName));
  if Trim(LSQL) <> '' then Result := AConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

function TDatabase.RenameSchema(const AConnection: IConnection; const AOldName, ANewName: string): Integer;
{$IFDEF USE_DATABASE}
var
  LNames: TStringArray;
  I: Integer;
  LOld, LNew: Boolean;
  LSQL: string;
{$ENDIF}
begin
  Result := 0;
{$IFDEF USE_DATABASE}
  if (AConnection = nil) or not AConnection.IsConnected then Exit;
  if (Trim(AOldName) = '') or (Trim(ANewName) = '') then Exit;
  LNames := Database.CatalogReader.TCatalogReader.New(AConnection).SchemaNames;
  LOld := False;
  LNew := False;
  for I := 0 to High(LNames) do
  begin
    if SameText(Trim(LNames[I]), Trim(AOldName)) then LOld := True;
    if SameText(Trim(LNames[I]), Trim(ANewName)) then LNew := True;
  end;
  if (not LOld) or LNew then Exit;
  LSQL := TDialect.ForConnection(AConnection).Schema.RenameSQL(Trim(AOldName), Trim(ANewName));
  if Trim(LSQL) <> '' then Result := AConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

function TDatabase.ToDDL: string;
var
  I: Integer;
  LList: TSchemaArray;
  LStmt: string;
begin
  { Onda S3 - agrega o ISchema.ToDDL de todos os schemas do banco (zero SQL
    novo, so orquestracao); ver comentario completo em
    Databases.Interfaces.IDatabase.ToDDL. }
  Result := '';
  LList := FSchemas.GetSchemasList;
  for I := 0 to High(LList) do
  begin
    LStmt := Trim(LList[I].ToDDL);
    if LStmt = '' then
      Continue;
    if Result <> '' then
      Result := Result + sLineBreak;
    Result := Result + LStmt;
  end;
end;

function TDatabase.ApplyStructure(const AConnection: IConnection): IDatabase;
var
  I: Integer;
  LList: TSchemaArray;
begin
  { Onda S3b - agrega o ISchema.ApplyStructure de TODOS os schemas deste
    banco (zero SQL novo, so orquestracao); ver comentario completo em
    Databases.Interfaces.IDatabase.ApplyStructure. }
  Result := Self;
  LList := FSchemas.GetSchemasList;
{$IFDEF USE_LOGGERS}
  FLogger.Debug(Format('ApplyStructure: materializando %d schema(s) (Database=%s)',
    [Length(LList), FDatabaseName]));
{$ENDIF}
  for I := 0 to High(LList) do
    LList[I].ApplyStructure(AConnection);
{$IFDEF USE_LOGGERS}
  FLogger.Success(Format('ApplyStructure: OK (%d schema(s), Database=%s)',
    [Length(LList), FDatabaseName]));
{$ENDIF}
end;

function TDatabase.ToFullJSON: string;
begin
  { Onda S4 (ADITIVO) - COMPOE os 2 eixos JA EXISTENTES (StructureToJSON/
    ToJSON), sem reimplementar nenhum dos 2. }
  Result := '{"structure":' + StructureToJSON + ',"data":' + ToJSON + '}';
end;

function TDatabase.FromFullJSON(const AJSON: string): IDatabase;
var
  LStructure, LData: string;
begin
  { Onda S4 (ADITIVO) - decompoe via JSONExtractMember (SSOT, Database.
    Helpers.JSON) e delega, NESTA ORDEM (estrutura antes de dado), a
    StructureFromJSON/FromJSON ja existentes. Tolerante: chave ausente nao
    aplica esse eixo. }
  Result := Self;
  LStructure := JSONExtractMember(AJSON, 'structure');
  if LStructure <> '' then
    StructureFromJSON(LStructure);
  LData := JSONExtractMember(AJSON, 'data');
  if LData <> '' then
    FromJSON(LData);
end;

function TDatabase.MergeFullFromJSON(const AJSON: string): IDatabase;
var
  LStructure, LData: string;
begin
  { Onda S4 (ADITIVO) - mesma decomposicao/ordem de FromFullJSON, delegando
    aos "patch" StructureMergeFromJSON/MergeFromJSON. }
  Result := Self;
  LStructure := JSONExtractMember(AJSON, 'structure');
  if LStructure <> '' then
    StructureMergeFromJSON(LStructure);
  LData := JSONExtractMember(AJSON, 'data');
  if LData <> '' then
    MergeFromJSON(LData);
end;

function TDatabase.Export(const AWithData: Boolean): string;
begin
  { Onda S4 (ADITIVO) - atalho ergonomico: False -> so ESTRUTURA; True ->
    FULL (estrutura+dado do modelo em memoria - ver overload com AQuery,
    abaixo, para dado vindo de uma query real). }
  if AWithData then
    Result := ToFullJSON
  else
    Result := StructureToJSON;
end;

{$IFDEF USE_DATABASE}
function TDatabase.Export(const AWithData: Boolean; const AQuery: IQueryBuilder): string;
var
  LFullJSON: string;
begin
  { Onda S4 (ADITIVO) - ver comentario completo em TTable.Export(AWithData,
    AQuery); delega a TryExportQueryData (Database.Helpers.Export), fallback
    na Connection fluente deste IDatabase (FConnection, campo privado DESTA
    MESMA unit). }
  if not AWithData then
    Exit(StructureToJSON);
  if TryExportQueryData(AQuery, FConnection, StructureToJSON, LFullJSON) then
    Exit(LFullJSON);
  Result := ToFullJSON;
end;
{$ENDIF}

function TDatabase.Import(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): IDatabase;
begin
  { Onda S4 (ADITIVO) - despacha pelas 2 flags para o metodo To/From/Merge ja
    existente correspondente. }
  Result := Self;
  if AWithData then
  begin
    if AMerge then
      MergeFullFromJSON(AJSON)
    else
      FromFullJSON(AJSON);
  end
  else
  begin
    if AMerge then
      StructureMergeFromJSON(AJSON)
    else
      StructureFromJSON(AJSON);
  end;
end;

{ ===== Onda 7 - camada de lancadores fluentes (metodos de INSTANCIA,
  Connection-bound a FConnection; ver comentario completo na declaracao da
  classe e no changelog, topo do ficheiro). ===== }

{$IFDEF USE_DATABASE}
function TDatabase.Metadata: ICatalogReader;
begin
  Result := Database.CatalogReader.TCatalogReader.New(FConnection);
end;

function TDatabase.Synchronize: ISynchronize;
begin
  Result := Database.Synchronize.TSynchronize.New(FConnection);
end;

function TDatabase.QueryBuilder: IQueryBuilder;
begin
  Result := Database.QueryBuilder.TQueryBuilder.New.Connection(FConnection);
end;

function TDatabase.UnitOfWork: IUnitOfWork;
begin
  Result := Database.UnitOfWork.TUnitOfWork.New.Connection(FConnection);
end;

function TDatabase.Dialect: IDialect;
begin
  { Resolve pela Connection LIGADA quando disponivel (ForConnection -
    version-aware, ex.: Firebird fb25/30/40/50); sem conexao ligada, cai no
    fallback por DatabaseTypes puro (ForDatabaseType, mesmo padrao ja usado
    por CreateDatabaseSQL/DropDatabaseSQL, acima). }
  if (FConnection <> nil) and FConnection.IsConnected then
    Result := Database.Dialect.TDialect.ForConnection(FConnection)
  else
    Result := Database.Dialect.TDialect.ForDatabaseType(FDatabaseTypes);
end;

{ Onda R2 (f5-repair, re-layering por responsabilidade) - colecoes de
  objectos de BANCO (Views/Procedures/Functions), Connection-bound a
  FConnection (mesmo padrao dos lancadores acima); ver comentario completo em
  Databases.Interfaces.IViews/IProcedures/IFunctions. ADITIVO - ISchema.
  CreateView/DropView/CreateProcedure/DropProcedure continuam intactos (a
  remocao fica para a Fase C do f5-repair). }
function TDatabase.Views: IViews;
begin
  Result := Database.Views.TViews.New.Connection(FConnection);
end;

function TDatabase.Procedures: IProcedures;
begin
  Result := Database.Procedures.TProcedures.New.Connection(FConnection);
end;

function TDatabase.Functions: IFunctions;
begin
  Result := Database.Functions.TFunctions.New.Connection(FConnection);
end;

function TDatabase.Triggers: ITriggers;
begin
  Result := Database.Triggers.TTriggers.New.Connection(FConnection);
end;

function TDatabase.Rules: IRules;
begin
  Result := Database.Rules.TRules.New.Connection(FConnection);
end;

{$IFDEF USE_ENTITY_MANAGER}
function TDatabase.EntityManager: IEntityManager;
begin
  { "Em branco" - so Connection-bound (SEM MapTable/Table configurados); o
    caller chama .MapTable(...) ou .Table(...) a seguir. }
  Result := Database.EntityManager.TEntityManager.New.Connection(FConnection);
end;
{$ENDIF}
{$ENDIF}

function TDatabase.IdentityMap: IIdentityMap<TObject>;
begin
  { Nova instancia a cada chamada (sem estado partilhado por omissao); o
    caller que precisar de partilhar o mapa entre chamadas guarda o
    resultado (ex.: campo proprio) em vez de chamar IdentityMap de novo. }
  Result := Database.IdentityMap.TIdentityMap<TObject>.New;
end;

function TDatabase.TypeDatabase: ITypeDatabase;
begin
  Result := Database.TypeDatabase.TTypeDatabase.New.DatabaseType(FDatabaseTypes);
end;

end.
