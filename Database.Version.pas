{ =============================================================================
  Database.Version - ModuleVersion do modulo Database

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.4.0
  FileVersion:    3.4.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           11/08/2026

  ModuleVersion do modulo Database (FASE 5): 1.0.0 metadados (5.1) -> 1.1.0
  dialectos IDialect (5.2) -> 1.2.0 QueryBuilder v3 (5.3) -> 1.3.0
  QueryTransformer B3 (5.4) -> 1.4.0 SchemaSync nucleo (5.5) + reconstrucao do
  modulo na pasta limpa, sem Legacy (Onda 0, revisao F5) -> 1.5.0 compat nomenclatura
  QueryBuilder (Onda 1) -> 1.6.0 absorcao IdentityMap (Onda 2) -> 1.7.0 absorcao
  UnitOfWork (Onda 3) -> 1.8.0 absorcao EntityManager (Onda 4) -> 1.9.0 Fatia A
  (continuacao Onda 4) - Connection fluente na ITable -> 1.10.0 Fatia B-a
  (continuacao Onda 4) - Size/Precision/Scale + serializacao IField/IFields em
  2 eixos (Estrutura/Dado) -> 1.11.0 Fatia B-b (continuacao Onda 4) -
  serializacao PROPRIA da Table (registo/linha) em 2 eixos, object_state,
  MergeFromJSON -> 1.12.0 Fatia B-c (continuacao Onda 4) - serializacao
  PROPRIA da Tables (grupo de registos) em 2 eixos, reconciliacao por PK ->
  1.13.0 Fatia B-d (continuacao Onda 4) - serializacao PROPRIA do
  Schema/Schemas em formato chave-nomeada (2 eixos) + DDL de nivel
  CreateSchema/DropSchema via IDialect -> 1.14.0 Fatia B-e (continuacao
  Onda 4, ULTIMA fatia da Fatia B) - fachada do modulo Database (IDatabase/
  IDatabases) + DDL de nivel CreateDatabase/DropDatabase via IDialect ->
  1.15.0 Passo 4 Fatia C (continuacao Onda 4) - UnitOfWork.Commit alinhado a
  ITable.Status/Execute (despacho DML unico) -> 1.16.0 Sub-passo 4.4
  (continuacao Onda 4) - soft delete + auditoria (modelo v1.6.1 form-driven)
  -> 1.17.0 Sub-passo 4.5 (continuacao Onda 4, ULTIMO sub-passo antes do gate
  final) - validacao no save + guardas read-only (modelo v1.6.1) -> 1.18.0
  Onda 5 - fachada do modulo Database (barrel Databases.Interfaces + class
  functions TDatabase.*) -> 1.19.0 Onda 6-a - modernizacao AQB/EMS dos
  dialectos SQL (I21 DateLiteral/TimestampLiteral/TryParseDateLiteral, I22
  DetectVersion + capabilities version-aware PostgreSQL/SQLServer, I23
  capability-flags SUPERSET). As ondas seguintes incrementam a MINOR.

  Changelog (file):
  - 3.4.0 (11/08/2026): F8 Onda 8.6 -- SetLogger reintroduzido/adicionado em
    TDatabase (ver Database.pas changelog 2.8.0). Bump aditivo MINOR: o
    contrato IDatabase permanece inalterado (SetLogger e' so' da classe, padrao
    "classe apenas"). Alinha tambem as numeracoes divergentes que existiam
    (header ModuleVersion 3.3.1 vs const DATABASE_VERSION 3.3.0) -> ambas 3.4.0.
  - 3.3.1 (30/07/2026): auditoria adversarial (owner, verificacao independente
    Opus) ao ApplyStructure (3.3.0, Onda S3b) - o test_serialize.dpr MASCARAVA
    2 defeitos reais via Skip condicionado a GFkReliable=False. Fixes
    (ModuleVersion PATCH - hardening/correcao, nao feature nova):
    (#1(CRITICO)/#3) ApplyStructure (Database.Schema.pas 1.10.0) NAO
    isolava os 6 passos (tabelas/FK/views/procedures+functions/triggers/
    rules) - uma UNICA excepcao (tipicamente no passo FK, cujo guard de
    idempotencia ITable.AddForeignKey->ICatalogReader.ForeignKeyExists so' e'
    fiavel em PostgreSQL - os outros 6 motores nao preenchem ConstraintName
    de forma fiavel na introspeccao de TableStructure) ABORTAVA todos os
    passos seguintes da MESMA chamada; uma 2a ApplyStructure sobre a MESMA
    estrutura em QUALQUER motor que nao PostgreSQL deixava o DB
    "meio-migrado" (views/procedures/functions/triggers/rules nunca
    re-tentados). FIX: cada objecto (cada FK, cada view, cada procedure/
    function, cada trigger, cada rule, + o passo de tabelas via Sync) ganhou
    um try/except PROPRIO que tolera a falha e continua para o proximo -
    idempotencia real em QUALQUER motor, nao so' PostgreSQL. (#2)
    DECIMAL/NUMERIC(p,s) materializava sempre (p,0) - SchemaAddTableToDefinition
    passava Size (=0 para estes campos) em vez de Precision/Scale (onde o
    tamanho real vive - ver Database.Field.ParseColumnTypeDimensions).
    ISchemaColumn ganhou Scale + ISchemaTable.AddColumn ganhou AScale
    (Databases.Interfaces 3.3.1, ADITIVO - default 0, zero quebra de
    call-site); BuildCreateTable/BuildAddColumn (Database.Synchronize 2.6.0)
    passam a repassar a Scale ao IDialect.ColumnTypeFor. (#6, incidental -
    achado do mesmo laudo) CommitResidualSQLAnywhere (Database.Synchronize
    2.6.0) ganhou o gate FConn.InTransaction - o COMMIT cru SQL Anywhere
    corria incondicionalmente e podia terminar uma transaccao EXPLICITA do
    consumidor. Teste des-mascarado: test_serialize.dpr deixa de dar Skip
    condicionado a GFkReliable=False na 2a ApplyStructure (idempotencia) -
    passa a EXIGIR 0 excepcao em TODOS os motores; ganhou uma coluna
    NUMERIC(18,4) real via merge (antes evitada de proposito) com
    verificacao de criacao (sempre) e de escala introspeccionada (Skip
    honesto so' quando o motor nao a reporta). #4 (DefaultValue nao
    serializa) e #5 (heuristica SchemaColumnTypeToKind: CHARACTER
    VARYING->ckChar, UUID/JSON->ckInteger) permanecem LIMITACAO ASSUMIDA,
    NAO corrigidos nesta onda (fora do escopo autorizado). Gate: 4 alvos
    EXIT=0 + test_serialize (dcc32/UniDAC + fpc64/UniDAC) 0 FAIL nos 7
    perfis reais (postgresql/sqlserver/mariadb/firebird5/sqlanywhere/sqlite/
    access-share), incl. 2x seguidas em sqlserver/sqlite (motores sem
    ForeignKeyExists fiavel) provando a idempotencia do fix #1.
  - 3.3.0 (30/07/2026): Onda S3b (ADITIVO - MATERIALIZACAO do merge, "a peca
    que torna o Merge util") - ModuleVersion 3.2.0 -> 3.3.0: ISchema/
    IDatabase ganham ApplyStructure(AConnection: IConnection): ISchema/
    IDatabase - aplica a estrutura guardada em memoria (FGroups/FViews/
    FRoutines/FTriggers/FRules, Onda S2-b2) a uma conexao REAL, criando os
    objectos em falta, IDEMPOTENTE, ZERO SQL novo: (1) tabelas+colunas+PK+
    uniques+indexes via bridge SchemaAddTableToDefinition (novo helper
    privado de Database.Schema.pas) + TSynchronize.Sync (Onda 5.5/5.5-B,
    idempotente por Compare); (2) FK via ITable.AddForeignKey(conn,...)
    (Onda D, ja idempotente), so DEPOIS de (1); (3) views/(4) procedures+
    functions/(5) triggers/(6) rules via os LANCADORES Connection-bound ja
    existentes (TViews/TProcedures/TFunctions/TTriggers/TRules - mesmo motor
    de IDatabase.Views/Procedures/Functions/Triggers/Rules, Onda R2/F1/F3/
    F4). ISchemas/IDatabases ganham a agregacao trivial. Novo par de
    getters em ITable - Uniques: TSchemaUniques/Indexes: TSchemaIndexes
    (simetricos aos ja existentes em ISchemaTable, MESMO tipo de Commons.
    Database.Types, regra #14) - ate esta onda FUniques/FIndexes (Onda
    S2-b1) so eram legiveis via StructureToJSON; o bridge precisa do MODELO
    tal-qual, sem round-trip JSON. UNICA peca genuinamente nova desta onda
    (sem SSOT preexistente, confirmado por grep global): SchemaColumnTypeToKind,
    heuristica que classifica o ColumnType RAW (string livre, dialect-
    specific, ja usado por CreateTableSQL) no TSQLColumnKind ABSTRACTO que
    TSynchronize/IDialect.ColumnTypeFor exige - IField.IsIdentity resolve o
    caso ckIdentity sem heuristica. Fluente; nunca lanca (degrada 0/no-op
    quando USE_DATABASE esta OFF, sem Connection ligada, ou o motor nao
    suporta um objecto). Ficheiros: Databases.Interfaces (3.3.0), Database.
    Table (1.17.0), Database.Schema (1.9.0), Database.Schemas (1.6.0),
    Database (2.7.0), Databases (1.4.0). Gate desta onda: so COMPILACAO (4
    alvos ProvidersV3 EXIT=0: dcc32/dcc64 -DUSE_UNIDAC; fpc32/fpc64
    -dUSE_ZEOS) - validacao contra banco real (2 conexoes concorrentes,
    engines multiplos) fica para a proxima onda (S4).
  - 3.2.0 (30/07/2026): Onda S4 (ADITIVO - eixo FULL = Metadata+Data num so
    JSON) - ModuleVersion 3.1.0 -> 3.2.0: trio ToFullJSON/FromFullJSON/
    MergeFullFromJSON nos 8 niveis (IField/IFields/ITable/ITables/ISchema/
    ISchemas/IDatabase/IDatabases) - ToFullJSON COMPOE os 2 eixos JA
    EXISTENTES (ESTRUTURA e DADO) sem reimplementar nenhum; FromFullJSON/
    MergeFullFromJSON decompoem via novo helper SSOT
    Database.Helpers.JSON.JSONExtractMember e delegam, estrutura sempre
    antes de dado, aos metodos ja existentes. Export(AWithData)/
    Import(AJSON, AWithData, AMerge) ergonomicos nos 8 niveis; ITable/
    ISchema/IDatabase ganham ainda o overload Export(AWithData, AQuery:
    IQueryBuilder) (gated USE_DATABASE) - a parte "data" vem das LINHAS de
    AQuery.Execute (TDataSet), serializadas via
    TDataSetSerializeHelper.ToJSONArrayString (unit Serialize, reutilizado);
    sem Connection viva ou AQuery=nil, cai graciosamente em ToFullJSON
    (NUNCA lanca). ACHADO durante a implementacao: Data.DB nao pode entrar
    directamente no uses de Database.Table.pas/Database.Schema.pas (
    Data.DB.TDataSetState colide POR NOME com Commons.Database.Types.
    TRowStatus - dsInactive/dsInsert/dsEdit em ambos, confirmado por
    compilacao real E2010) - resolvido com nova unit isolada
    Database.Helpers.Export (TryExportQueryData), sem TRowStatus, consumida
    pelos 3 niveis Connection-bound. Covariancia sobre IFields/ITables
    (retorno ITable/ISchema/etc.) resolvida por clausula de resolucao de
    interface nas implementacoes (TTable/TSchema), MESMA tecnica ja usada
    por FromJSON/MergeFromJSON/StructureFromJSON/StructureMergeFromJSON.
    Ficheiros: Databases.Interfaces (3.2.0), Database.Helpers.JSON (1.1.0,
    +JSONExtractMember), Database.Helpers.Export (1.0.0, NOVO), Database.Field
    (1.8.0), Database.Fields (1.4.0), Database.Table (1.16.0), Database.Tables
    (1.6.0), Database.Schema (1.8.0), Database.Schemas (1.5.0), Database
    (2.6.0), Databases (1.3.0). Gate: 4 alvos ProvidersV3 EXIT=0 (dcc32/
    dcc64 -DUSE_UNIDAC; fpc32/fpc64 -dUSE_ZEOS). FromDDL/FromSQL continuam
    fora de escopo (follow-up ja documentado na Onda S3).
  - 3.1.0 (29/07/2026): Onda S3 (ADITIVO - eixo SQL) - ModuleVersion 3.0.0 ->
    3.1.0: ITable/ISchema/IDatabase ganham ToDDL: string (script DDL REAL na
    ordem de aplicacao, agregando os geradores *SQL ja existentes - zero SQL
    novo); ISchemas/IDatabases ganham ToDDL trivial (agregacao); ITable/
    ITables ganham ToSQL: string (DML - INSERT via IQueryBuilder); IQueryBuilder
    ganha o overload DatabaseTypes(TDatabaseTypes) (dialecto sem exigir
    conexao viva, mesmo padrao de ITable/ITables/ISchema/IDatabase). ACHADO
    durante a implementacao: TTables.GetTablesList/FList (estrutural, so
    alimentado por LoadFromConnection) e' PARALELO a TSchema.FGroups (o
    modelo por-tabela usado por ToJSON/StructureToJSON/Structure*FromJSON, o
    UNICO caminho fluente hoje sem conexao viva) - ISchema/TSchema SOBREPOE
    ToDDL/ToSQL para usar FGroups (nao herda TTables.ToSQL verbatim), senao
    o eixo SQL sairia sempre vazio para qualquer schema construido via JSON.
    Ficheiros: Databases.Interfaces (3.1.0), Database.Table (1.15.0),
    Database.Tables (1.5.0), Database.Schema (1.7.0), Database.Schemas
    (1.4.0), Database (2.5.0), Databases (1.2.0), Database.QueryBuilder
    (2.11.0). FromDDL/FromSQL fora de escopo (follow-up - parse de SQL
    nao-trivial cross-banco).
  - 3.0.0 (26/07/2026): FASE 5 conformidade - onda C1 (plano
    providersorm-v3-f5-conformidade). BUMP MAJOR 2.9.0 -> 3.0.0: marca
    oficialmente o re-layering breaking ja entregue pelo F5-repair/followups e
    alinha o SSOT de versao (ficara em 2.9.0/16-07 apesar da onda de 25-07).
    ModuleVersion re-sincronizado para 3.0.0 nos 32 cabecalhos do modulo
    (drift: 23 estavam desalinhados). O item da auditoria "4 units sem a
    diretiva include (I) ORM.Defines.inc" (esta + 3 stubs EntityManager) foi
    RE-AVALIADO como falso-positivo: a regra obrigatoria #1 exige o include so
    em units COM USE_*; estas nao usam USE_* -> nao o requerem. Comentario
    obsoleto em Database.Table.pas ("substitui o extinto ICatalogReader")
    corrigido - os Cat* delegam ao TCatalogReader (SSOT); o dissolvido foi o
    IMetadata publico, nao o ICatalogReader.
    A1 (esclarecimento de gating): IQueryBuilder/ICaseBuilder/IQueryTransformer/
    IFilterValueProvider sao NUCLEO sob USE_DATABASE; os defines
    USE_QUERY_BUILDER/USE_QUERY_TRANSFORMER gateiam as pecas OPCIONAIS da fachada
    (class functions TDatabase.QueryBuilder/QueryTransformer) + integracoes
    externas (Printers) - corrige a descricao do changelog 1.18.0.
  - 2.9.0 (16/07/2026): Onda 5.5-B (indices/constraints, ADITIVO - a onda de
    indices que ficara adiada na 5.5) - UNIQUE composto + INDEX generico via
    SchemaSync. ISchemaTable.AddUnique/AddIndex + records TSchemaUnique/
    TSchemaIndex/TSchemaColumnNames + TSchemaChange.Name (Commons.Database.Types
    1.9.0). IDialect ganha AddUniqueSQL/CreateIndexSQL/UniquesSQL/IndexesSQL +
    capability scUnique (Databases.Interfaces 1.7.0; base ANSI +
    overrides SQLite/Firebird/Access/PostgreSQL/MySQL/SQLServer). ICatalogReader
    ganha UniqueNames/IndexNames/UniqueExists/IndexExists (introspecao robusta
    por engine - [] em erro/sem suporte; conservador True sem introspecao,
    Database.CatalogReader 1.6.0). Database.Synchronize: TSchemaChangeKind
    +sckAddUnique/sckCreateIndex; Compare idempotente por NOME (statement
    SEPARADO com nome deterministico - evita o sqlite_autoindex que quebraria a
    idempotencia de um UNIQUE inline). Pre-requisito da FASE 7 (Parameters -
    chave unica composta contrato_id/produto_id/titulo/chave). Gate 16 builds +
    smoke_schemasync estendido. Via ITable.CreateTableSQL directa (UNIQUE/INDEX
    inline) fica como FOLLOW-UP (o SchemaSync ja e o caminho idiomatico v3).
    VERIFICACAO ADVERSARIAL (workflow) apanhou e CORRIGIU 2 bugs de robustez:
    (bug-505) nome de constraint/indice anonimo passa a derivar das COLUNAS (nao
    do ordinal K) - idempotente a reordenacao/insercao de AddUnique anonimos;
    (bug-506) UniquesSQL/IndexesSQL de PG/MySQL/SQLServer ganham fallback ao schema
    CORRENTE (current_schema()/DATABASE()/SCHEMA_NAME()) quando ASchema='' - evita
    misturar tabelas homonimas de outros schemas no information_schema. LIMITACAO
    conhecida (documentada): Access sem introspecao de indices -> UniqueExists
    conservador (True) NAO adiciona UNIQUE a tabela ja EXISTENTE (so na criacao).
    smoke_schemasync 22/22 (dcc32+fpc32); Dialect.MySQL/PostgreSQL/SQLServer +0.1.0.
  - 2.8.0 (15/07/2026): Onda 7 (camada de LANCADORES fluentes na hierarquia
    de estrutura, ADITIVO) - IDatabase/ISchema/ITable ganham metodos que
    DELEGAM aos modulos de OPERACAO do Database (lei de nomenclatura: nome
    do lancador = nome do modulo = I<Modulo>); estrutura = infra/forma
    serializavel, operacoes CONSOMEM essa forma, nunca a possuem. Mapa
    implementado: IDatabase.Metadata/Synchronize/QueryBuilder/UnitOfWork/
    Dialect (gated USE_DATABASE) + EntityManager "em branco" (gated
    USE_ENTITY_MANAGER) + IdentityMap<TObject>/TypeDatabase (ungated);
    ISchema.Synchronize/QueryBuilder/Metadata (gated USE_DATABASE);
    ITable.QueryBuilder (PRE-CONFIGURADO com From(<tabela>), gated
    USE_DATABASE) + EntityManager (mapeado a Self, gated USE_ENTITY_MANAGER)
    + UnitOfWork (Connection-bound, ungated). IField/IFields permanecem
    FOLHA (sem lancadores, por desenho). 2 renames governance de sessoes
    anteriores ja aplicados (ISQLDialect->IDialect/TSQLDialect*->TDialect*;
    ISchemaMigrator->ISynchronize) sao pre-requisito assumido desta onda.
    Ciclo REAL unico resolvido: ITable.EntityManager <-> Database.
    EntityManager (que ja usa Database.Table para TTable.New) - factory-
    function registada TTableEntityManagerFactory/var
    GTableEntityManagerFactory (Databases.Interfaces 2.11.0), atribuida na
    `initialization` de Database.EntityManager.pas (1.9.0); TTable.
    EntityManager so chama a var com guarda Assigned. ITable.UnitOfWork
    NAO precisou de factory - Database.UnitOfWork.pas (1.5.0) tinha um
    `uses Database.Table` MORTO (grep confirmou zero uso de TTable.* fora
    de comentario), removido nesta onda. Colisao de nome nas class
    functions pre-existentes de TDatabase (Onda 5: Metadata/QueryBuilder/
    Synchronize/UnitOfWork/EntityManager(AConnection): I...) resolvida com
    `overload` (verificado por compilacao real dcc32+fpc32 mode delphi:
    Object Pascal distingue `TDatabase.Foo(conn)` via CLASSE da class
    function de `instancia.Foo` via OBJECTO do metodo de instancia, sem
    ambiguidade). Ficheiros tocados: Databases.Interfaces (2.11.0 - forward
    declarations + metodos + factory-var), Database.pas (2.1.0),
    Database.Table.pas (1.12.0), Database.Schema.pas (1.3.0),
    Database.EntityManager.pas (1.9.0), Database.UnitOfWork.pas (1.5.0 -
    cleanup do uses morto). Novo smoke_launchers.dpr. Design aprovado pelo
    owner em 15/07/2026 (memory database-launchers-design). Zero mudanca de
    comportamento pre-existente (100% aditivo).
  - 2.7.0 (15/07/2026): Onda 6-f Estagio 2 (I11/A2, execucao assincrona,
    ADITIVO) - nova interface generica IORMTask<T> (Databases.Interfaces
    2.10.0: Await/IsCompleted/IsFaulted/Error) + implementacao TORMTask<T>
    sobre TThread CRU + TEvent (SyncObjs), unit NOVA Database.QueryBuilder.Sychronize
    (Modulos/Database/Async) - a FPC 3.3.1 nao tem System.Threading/TTask.
    IQueryBuilder ganha ExecuteAsync: IORMTask<TDataSet> (Database.
    QueryBuilder 2.8.0) - corre o SELECT actual numa thread de fundo,
    captura por CLOSURE (mantem a propria IQueryBuilder viva enquanto a
    tarefa corre). Novo erro ERR_DATABASE_ASYNC=410095/
    EDatabaseAsyncException (Exceptions.Database 1.7.0) - Await relanca a
    MENSAGEM da excecao capturada em segundo plano (o objecto Exception
    original nao atravessa threads em Object Pascal). Nova pasta Async/
    registada em dcc32/dcc64.cfg, fpc32/fpc64.opts, ProvidersV3.dpr/.lpr e no
    dproj-sync. Novo smoke_async.dpr (SQLite local: ExecuteAsync com sucesso
    + polling IsCompleted + Await; e ExecuteAsync sobre SQL invalido ->
    IsFaulted/Error/Await relanca). Gate 4 builds + smoke verde.
  - 2.6.0 (15/07/2026): Onda 6-f Estagio 1 (I10, linked servers + stored
    procedures tipadas, aditivo) - IDialect ganha LinkedServersSQL/
    ProceduresSQL(ASchema)/CallProcedureSQL(AProcName,AArgCount) (base '';
    overrides SQLServer completo, PostgreSQL/MySQL/Firebird em Procedures/
    CallProcedure - LinkedServersSQL so SQLServer, PostgreSQL fica na BASE de
    proposito, ambiguo entre pg_foreign_server/dblink); ICatalogReader ganha
    LinkedServerNames/ProcedureNames (descoberta, robusta - [] em erro/sem
    suporte); IQueryBuilder ganha CallProcedure(nome,args) (novo TQBKind
    qbCall, args sempre bindados via o mesmo mecanismo Bind; dialecto sem
    suporte -> Execute/ExecuteMutation no-op gracioso). smoke_dialects
    estendido (CallProcedureSQL golden); smoke_metadata estendido
    (ProcedureNames/LinkedServerNames em SQLite -> [] gracioso). Gate 4
    builds + smokes verde.
  - 2.5.0 (15/07/2026): Onda 6-e (query intelligence AQB/EMS, aditivo, 8
    features via workflow de 4 estagios) - I3 estatisticas (TQueryStatistics em
    Commons + IQueryBuilder.Statistics; Execute instrumentado) + I15 formatter
    (IQueryBuilder.ToSQLFormatted) + I18 grupos de filtro (IFilterGroup +
    OrWhere/WhereGroup/OrHaving; RenderWhere recursivo com parenteses e AND/OR/
    NOT) + I13 funcoes SQL por dialecto (IDialect.FunctionSQL, base ANSI + 4
    overrides SQLServer/Firebird/SQLite/Access) + I19 operadores semanticos
    (IQueryBuilder.WhereOp: eq/neq/contains/startsWith... -> ILIKE/LIKE bindado;
    erro 410081) + I17 presets JSON (IQueryBuilder.SavePreset/LoadPreset,
    essencial) + A3 SQLContext nas excecoes (EDatabaseException, param opcional
    backward-compat) + A4 hook de validacao (ITable.OnValidate). smoke_dialects
    177->201, smoke_querybuilder ->111. Gate 16 builds + 34 smokes verde.
  - 2.4.0 (15/07/2026): Onda 6-d PARTE 2 (I24 descricoes, aditivo) -
    IField.Description (getter/setter fluente; Clone copia) + TDatabaseFields.
    Description (Commons.Types) + IDialect.ColumnDescriptionSQL (base '';
    overrides PostgreSQL/SQLServer/Firebird/MySQL; SQLite/Access no-op) +
    ICatalogReader popula Description no TableStructure (robusto, try/except).
    NOTA: Description ainda NAO entra na serializacao StructureToJSON/snapshot
    (follow-up). Gate 16 builds + 34 smokes verde.
  - 2.3.0 (15/07/2026): Onda 6-d PARTE 1 (I9/I12/I6, aditivo) - ICatalogReader.Filter
    (I9, TMetadataFilter de Commons.Database.Types; filtro server-side) +
    DescribeQuery (I12, colunas de um SELECT arbitrario, cacheado) + SaveToFile/
    LoadFromFile/WorkOffline (I6, snapshot offline do catalogo em JSON). Novo
    smoke_metadata. Defaults inalterados.
  - 2.2.0 (15/07/2026): Onda 6-c (I5 AutoJoin por FK + I20 relacoes, aditivo) -
    TRelationInfo/TRelationCardinality em Commons.Database.Types (dado);
    ICatalogReader.ResolveFK (descoberta de FK a partir do TableStructure);
    IQueryBuilder.JoinByFK(relacao) + AutoJoin(tabela, acoplado ao Metadata,
    sem ciclo) + DistinctValuesQuery(coluna). NOTA: o metadata SQLite
    (pragma_table_info) NAO expoe FK -> ResolveFK vazio em SQLite (AutoJoin
    no-op ai; funciona onde a metadata expoe FK). Novo smoke_relations. Gate
    16 builds + 32 smokes verdes.
  - 2.1.0 (14/07/2026): Onda 6-b (modernizacao AQB/EMS, aditivo) - I7 nomes
    logicos na HIERARQUIA (IField/ITable.LogicalName + ITable.PhysicalColumn,
    resolucao logico->fisico case-insensitive; o EntityManager DELEGA) + I8 no
    QueryBuilder (SelectComputed(nome,expr) -> expr AS ident(nome); FromVirtual
    (subquerySQL,alias) -> FROM (sql) ident(alias); decisao owner: computado/
    virtual sao conceitos de query, nao da estrutura). Gate 8 builds x4
    compiladores + 30 smokes verdes.
  - 2.0.0 (14/07/2026): Reorg 1 (owner) - consolidacao das 14 units
    *.Interfaces.pas do modulo Database num UNICO Databases.Interfaces.pas
    (22 interfaces copiadas VERBATIM + 4 re-exports de Commons.Database.Types:
    TRowStatus/TSQLColumnKind/TFieldValidationError(s)). IDialect
    (Dialects\Databases.Interfaces) e ITypeDatabase
    (Databases.Interfaces) ficam em ficheiros SEPARADOS (contratos
    fundacionais do subsistema Dialect - evitam inversao de dependencia). Os 14
    ficheiros antigos eliminados; consumidores (17 impls + 15 smokes + 4
    Printers + ProvidersV3.dpr/.lpr) passam a usar Databases.Interfaces. SEM
    shims (B-freeze). Gate: 16 builds USE_DEPRECATED ON/OFF x 4 compiladores
    (ProvidersV3+ParametersV3) + 30 smoke runs (15 x dcc32 + 15 x fpc32) verdes.
    Reorg 2: unit Database.SchemaSync -> Database.Synchronize (pasta SchemaSync/
    -> Synchronize/); factory TDatabase.SchemaSync -> TDatabase.Synchronize.
    Reorg 3: Database.QueryTransformer ABSORVIDO por Database.QueryBuilder
    (TQueryTransformer/TFilterValueProvider passam a residir nessa unit; pasta
    QueryTransformer/ eliminada). Gate Reorg 2+3: 16 builds + 30 smokes verdes.
  - 1.19.0 (14/07/2026): Onda 6-a (F5 revisao, modernizacao AQB/EMS dos
    dialectos SQL, ADITIVO - ZERO regressao dos 88 casos golden pre-
    existentes). I23: TSQLCapability (Commons.Database.Types 1.5.0) ganha 8
    flags SUPERSET (scRecursiveCTE/scWindowFunctions/scMerge/scUpsert/
    scSequences/scArrays/scJSON/scFullText); cada TDialect<Banco> so
    acrescenta os que suporta. I22: IDialect.DetectVersion(AConnection):
    string - implementacao BASE uniforme (delega a IConnection.GetServerVersion,
    kernel F4 intacto); PostgreSQL/SQLServer ganham overload New(versao) -
    New sem args preserva EXACTAMENTE o comportamento anterior (delega ao
    default "moderno": PG New(16,0), SQLServer New(15)) - capabilities
    version-aware por threshold historico bem documentado (PG: window/CTE
    recursivo>=8.4, JSON>=9.4, upsert>=9.5, merge>=15.0; SQLServer: OFFSET-
    FETCH+sequences>=major interno 11/2012, JSON>=13/2016). ForConnection
    tenta auto-detectar a versao via GetServerVersion; sem conexao activa
    (golden tests, nunca chamam Connect) cai no default "moderno" - ZERO
    regressao. MySQL/SQLite/Access ficam com capabilities ESTATICAS
    (decisao documentada: fork MySQL/MariaDB e versionamento sem exposicao
    pratica tornam o gate por versao AMBIGUO - "se ambiguo, fica estatico e
    documenta"). Firebird ganha scWindowFunctions version-aware (fb30+,
    reusa o enum TFirebirdVersion 2-D ja existente) + 5 capabilities
    estaticas (scUpsert/scMerge/scSequences/scArrays/scRecursiveCTE, sempre
    presentes desde o piso fb25). I21: DateLiteral(ADate)/TimestampLiteral
    (ADateTime)/TryParseDateLiteral(ALiteral, out ADate) - implementacao BASE
    ANSI ('aaaa-mm-dd'[ hh:nn:ss] entre aspas simples, MySQL/SQLServer/
    SQLite/Firebird usam-na sem override); PostgreSQL prefixa DATE '...'/
    TIMESTAMP '...' (override); Access usa delimitador #...# (override,
    Jet/ACE); TryParseDateLiteral e um parser UNICO na base que reconhece os
    3 formatos (nenhum dialecto precisa de override para o parse). Ficheiros
    tocados: Commons.Database.Types (1.5.0), Databases.Interfaces
    (1.3.0), Database.Dialect (1.3.0, base+ForConnection+TryParseMajorMinor),
    Database.Dialect.PostgreSQL (1.1.0), Database.Dialect.MySQL (1.2.0),
    Database.Dialect.SQLServer (1.1.0), Database.Dialect.SQLite (1.2.0),
    Database.Dialect.Firebird (1.2.0), Database.Dialect.Access (1.2.0).
    smoke_dialects estendido (>=88, novos casos secoes 10-12).
  - 1.18.0 (14/07/2026): Onda 5 (fachada do modulo Database) - Database.
    Interfaces.pas (FileVersion 2.0.0) passa de "so IDatabase" a BARREL do
    modulo inteiro: re-exporta (via `type IX = <Unit>.IX`) IField/IFields/
    ITable/ITables/ISchema (sempre) + IUnitOfWork/IIdentityMap<T> (sempre,
    units-fonte sem gate) + IEntityManager (USE_ENTITY_MANAGER) + ICatalogReader/
    IDialect/ISchemaColumn/ISchemaTable/ISchemaDefinition/ISchemaInspector/
    ISchemaComparer/ISynchronize/TRowStatus/TSQLColumnKind/
    TFieldValidationError(s) (USE_DATABASE - gate real das units-fonte) +
    IQueryBuilder/ICaseBuilder (USE_QUERY_BUILDER) + IQueryTransformer/
    IFilterValueProvider (USE_QUERY_TRANSFORMER). IDatabases (Databases.
    Interfaces) FICA DE FORA do barrel de proposito - ja depende de
    Databases.Interfaces (TDatabaseArray/Add(IDatabase)), reimportar de volta
    criava um ciclo de INTERFACE (E2029); consumidor acrescenta Databases.
    Interfaces ao proprio uses quando precisar de IDatabases. Database.pas
    ganha `class function` factories (ponto unico de criacao do modulo,
    delegam as factories ja existentes, sem logica nova): Databases
    (AConnection): IDatabases; Metadata/QueryBuilder/QueryTransformer/
    UnitOfWork(AConnection); SchemaSync(AConnection): ISynchronize (a
    peca do submodulo SchemaSync que efectivamente aplica a sincronizacao -
    nao existe uma interface unica "ISchemaSync"); EntityManager(AConnection)
    sob USE_ENTITY_MANAGER; + criacao trivial de Table/Tables/Schema/Field/
    Fields (sem parametros - "Schemas" plural fica de fora, colidiria com o
    getter de instancia Schemas: ISchemas ja existente). Novo smoke
    smoke_database_facade.dpr prova o barrel sozinho (so `uses Database.
    Interfaces`) + as factories da fachada com IConnection SQLite real.
  - 1.17.0 (14/07/2026): Sub-passo 4.5 (continuacao Onda 4, revisao F5) -
    validacao no save + guardas read-only (modelo v1.6.1), ADITIVO.
    Database.Table 1.9.0/Database.Table.Interfaces 1.8.0: ITable.ValidateFields
    (out AErrors: TFieldValidationErrors): Boolean - novo, detalha
    (field,message) dos obrigatorios em falta (ValidateNotNullFields vira
    wrapper aditivo, zero uso pre-existente); ITable.ReadOnly (getter/setter
    fluente) - novo flag equivalente ao FDeletedBlock v1.6.1;
    TTable.Execute(AConnection) ganha 3 guardas antes/durante o despacho por
    Status: (1) read-only/soft-deleted (ReadOnly=True OU FieldIsDeleted=1 no
    proprio registo) -> EDatabaseReadOnlyException (ERR_DATABASE_READONLY);
    (2) dsEdit/dsDeleted sem PK preenchida -> EDatabaseInvalidStatusException
    (ERR_DATABASE_INVALID_STATUS); (3) obrigatorios em falta no INSERT/UPDATE
    (nunca DELETE) -> EDatabaseValidationException (ERR_DATABASE_VALIDATION).
    Commons.Database.Types 1.4.0: TFieldValidationError/TFieldValidationErrors
    (dado puro). Exceptions.Database 1.3.0: +3 codigos (410004/005/006) + 3
    classes. Sem ReadOnly/FieldIsDeleted configurados e com PK preenchida em
    dsEdit/dsDeleted, comportamento 100% inalterado (todos os smokes/
    regressoes preexistentes preservados). Nota: corrigido tambem o desvio
    pre-existente entre o cabecalho (ModuleVersion 1.16.0) e a const
    DATABASE_VERSION (ainda '1.15.0') desta unit - ambos alinhados a 1.17.0.
  - 1.16.0 (14/07/2026): Sub-passo 4.4 (continuacao Onda 4, revisao F5) - soft
    delete + auditoria (modelo v1.6.1 form-driven), ADITIVO. Database.Table
    1.8.0/Database.Table.Interfaces 1.7.0: DeleteSQL gera 'UPDATE ... SET
    "<deleted>"=1 [, "<updated>"=<now>]' em vez de 'DELETE FROM ...' quando
    FieldIsDeleted esta configurado (design composable preservado, guarda
    EnsureSafeDML inalterada); InsertSQL carimba FieldDateCreated/
    FieldIsActive; UpdateSQL carimba FieldDateUpdated (entra no UPDATE
    dinamico Optimized=True). Database.EntityManager 1.7.0/.Interfaces 1.4.0:
    novo IncludeDeleted (getter/setter fluente, default False, padrao
    ICatalogReader.IncludeSystemObjects) + ApplySoftDeleteFilter aplicado em
    Find/List/ListWhere - acrescenta Where(FieldIsDeleted,'=',0) [bindado] a
    query quando a ITable mapeada tem FieldIsDeleted configurado e a coluna
    existe. UnitOfWork.Commit e EntityManager.Save beneficiam automaticamente
    (ja despacham via ITable.Execute/DeleteSQL, Fatia C 1.15.0) - zero mudanca
    nesses 2 ficheiros. Sem os campos de auditoria configurados, comportamento
    100% inalterado (todos os smokes/regressoes preexistentes preservados).
  - 1.15.0 (14/07/2026): Passo 4 Fatia C (continuacao Onda 4, revisao F5) -
    Database.UnitOfWork.pas 1.4.0: RegisterNew/RegisterDirty/RegisterDeleted
    passam a setar o Status (TRowStatus dsInsert/dsEdit/dsDeleted) na ITable
    registada; Commit deixa de compor SQL manualmente e passa a chamar
    ITable.Execute(FConnection) para cada item das 3 listas, dentro da mesma
    transacao - mesmo caminho DML unico ja usado por TEntityManager.Save
    (Fatia B-e/1.9.0). Zero mudanca de API publica ou de SQL gerado.
  - 1.14.0 (14/07/2026): Fatia B-e (continuacao Onda 4, revisao F5, ULTIMA
    fatia da Fatia B) - fachada do MODULO Database: IDatabase/TDatabase (UM
    banco - Database[.Interfaces].pas, raiz do modulo) compoe ISchemas e usa
    ICatalogReader (Onda 5.1, intacto) para descobrir os schemas via
    LoadSchemasFromConnection; serializacao ToJSON/FromJSON/MergeFromJSON
    delegada integralmente a ISchemas (banco completo, ja chave-nomeada por
    SchemaName); StructureToJSON/StructureFromJSON acrescentam a chave
    "database". IDatabases/TDatabases (GRUPO de bancos - unit
    Databases[.Interfaces].pas, SEM prefixo "Database." - plural da raiz,
    ordem do owner) aplica a mesma tecnica chave-nomeada por DatabaseName um
    nivel acima (mesmo modelo de ISchemas sobre ISchema, Fatia B-d), descobre
    os bancos via ICatalogReader.DatabaseNames. IDialect ganha CreateDatabaseSQL/
    DropDatabaseSQL (aditivos, SEM gate de capability - PostgreSQL/MySQL/
    SQLServer geram DDL real via QuoteIdentifier na implementacao BASE;
    SQLite/Access fazem override -> vazio; Firebird faz override -> sintaxe
    ISQL propria, CREATE DATABASE 'file' com STRING LITERAL, DROP DATABASE
    sem argumento). IDatabase ganha CreateDatabaseSQL/DropDatabaseSQL
    (string) + CreateDatabase/DropDatabase(AConnection): Integer (mesmo
    padrao ISchema.CreateSchema/DropSchema, Fatia B-d). Corolario bug-315
    (Database.Dialect.MySQL): Database.Dialect.Firebird ganhou
    SysUtils/System.SysUtils no uses proprio da implementation (Trim/
    StringReplace, nunca antes chamados directamente por aquela unit).
  - 1.13.0 (13/07/2026): Fatia B-d (continuacao Onda 4, revisao F5) -
    ISchema/TSchema ganham serializacao PROPRIA em formato CHAVE-NOMEADA
    (master-detail): cada tabela do schema e um grupo ITables independente
    (TableName -> ITables), reusando a reconciliacao por PK/object_state do
    B-c DENTRO de cada grupo. ISchemas/TSchemas ganham a mesma tecnica um
    nivel acima (SchemaName -> ISchema.ToJSON). IDialect ganha
    CreateSchemaSQL/DropSchemaSQL (aditivos) + TDialect.ForDatabaseType
    (factory por TDatabaseTypes puro, sem IConnection); gate pela capability
    scSchemas (PostgreSQL/SQLServer geram DDL real; SQLite/Firebird/Access
    devolvem vazio); MySQL override (schema~=database, gera sempre, sem
    alterar Capabilities). ISchema ganha CreateSchemaSQL/DropSchemaSQL
    (string) + CreateSchema/DropSchema(AConnection): Integer.
  - 1.12.0 (13/07/2026): Fatia B-c (continuacao Onda 4, revisao F5) -
    ITables/TTables ganham StructureToJSON/StructureFromJSON (novos) +
    MergeFromJSON (novo) somando-se ao ToJSON/FromJSON ja existentes (FromJSON
    deixa de ser stub). FromJSON ("replace")/MergeFromJSON ("patch")
    partilham a reconciliacao por PK privada (ImportJSON) - arvore de import
    por object_state: INSERTED->adiciona novo; UNMODIFIED->nao edita;
    MODIFIED->localiza por PK e edita (se nao achar, adiciona); DELETED->
    localiza e marca (Status=dsDeleted). Registos novos clonam a ESTRUTURA do
    1o registo existente (round-trip StructureToJSON->StructureFromJSON)
    antes de hidratar os dados.
  - 1.11.0 (13/07/2026): Fatia B-b (continuacao Onda 4, revisao F5) -
    ITable/TTable ganham serializacao PROPRIA (Database.Table[.Interfaces]),
    sobrepondo os 4 metodos herdados de IFields (que operam so a nivel dos
    campos, sem TableName/object_state). EIXO DADO: ToJSON emite objeto JSON
    com par coluna/valor por campo mais a chave object_state, com valor
    tipado por ColumnType; FromJSON (retorno ITable, "replace") hidrata
    limpo; MergeFromJSON (novo, "patch") hidrata dirty por campo. EIXO
    ESTRUTURA: StructureToJSON emite objeto JSON com as chaves
    table/fields/primaryKey; StructureFromJSON (retorno ITable) reconstroi.
    object_state <-> TRowStatus (Status). FromJSON/StructureFromJSON com retorno covariante
    (ITable em vez de IFields) resolvidos via clausula de resolucao de
    interface (function ITable.FromJSON = TableFromJSON; e idem para
    StructureFromJSON) - Object Pascal nao permite 2 metodos com o MESMO nome
    e MESMOS parametros diferindo so no tipo de retorno.
  - 1.10.0 (13/07/2026): Fatia B-a (continuacao Onda 4, revisao F5) - metadados
    de dimensao Size/Precision/Scale em IField/TField (parser automatico no
    setter ColumnType, decompoe o conteudo entre parenteses); TFieldList
    (Database.Fields) ganha size/precision/scale sincronizados a partir de
    IField. Serialize em 2 EIXOS: IField/IFields.StructureToJSON +
    StructureFromJSON (ESTRUTURA pura, novos) somam-se a ToJSON (passa a DADO
    puro, so "value") + LoadFromJSON/FromJSON (deixam de ser stub - parser
    real cross-compiler fpjson+jsonparser/System.JSON, padrao de
    Connections.pas.LoadFromJSON).
  - 1.9.0 (13/07/2026): Fatia A (continuacao Onda 4, revisao F5) - Connection
    fluente na ITable (getter/setter, fallback do Execute) + overload Execute
    sem parametro; corrigido bug de compilacao pre-existente em Database.Table
    (property Status/AuditFields/FieldDate*/FieldIs*/Connection colidindo com
    os metodos fluentes homonimos - E2004/E2291); EntityManager (CloneTableStructure/
    MapTable) e UnitOfWork (Register*) passam a propagar FConnection para as
    ITable materializadas/registadas (aditivo, sem mudar assinaturas publicas
    nem a semantica do Commit).
  - 1.8.0 (13/07/2026): Onda 4 (revisao F5) - absorcao do modulo EntityManager
    (TEntityManager/IEntityManager, do legado v2.3.0) com header v3 + uses
    Providers.Connection.Interfaces -> Connections.Interfaces; migracao interna
    p/ API v3 do QueryBuilder (ja compativel sem rename: Select/From/Where/
    Limit/Execute identicos); excecoes integradas na faixa 41 (Exceptions.Database,
    ERR_DATABASE_ENTITYMANAGER=410070); stubs Types/Consts/Exceptions mantidos
    (sem conteudo exclusivo na fonte legada); registo no build gated por
    USE_ENTITY_MANAGER dentro de USE_DATABASE.
  - 1.7.1 (13/07/2026): Onda 3 refino - design COMPOSABLE (GenerateUpdateSQL/
    GenerateDeleteSQL deixam de embutir o WHERE; caller compoe + GenerateWhereByPrimaryKey)
    + guarda TTable.EnsureSafeDML (ERR_DATABASE_UNSAFE_DML=410003, bloqueia UPDATE/DELETE
    sem WHERE) + UnitOfWork.Commit usa GenerateUpdateSQLOptimized (UPDATE dinamico).
  - 1.7.0 (13/07/2026): Onda 3 (revisao F5) - absorcao do modulo UnitOfWork
    (TUnitOfWork/IUnitOfWork, do legado) com header v3 + uses Providers.Connection.
    Interfaces -> Connections.Interfaces + registo no build; modernizacao aditiva
    PendingCount/HasPending; corrigido bug-232 (Commit duplicava a clausula WHERE
    em UPDATE/DELETE - GenerateUpdateSQL/GenerateDeleteSQL v3 ja a incluem).
  - 1.6.0 (13/07/2026): Onda 2 (revisao F5) - absorcao do modulo IdentityMap
    (IIdentityMap<T>/TIdentityMap<T> autonomo, do legado) com header v3 + registo
    no build; modernizacao aditiva TryGet(AId, out T): Boolean.
  - 1.5.0 (13/07/2026): Onda 1 (revisao F5) - compat de nomenclatura do QueryBuilder
    v3 com a v2.3.0 (overload-first, ZERO deprecacoes): overloads GroupBy/OrderBy
    (TStringArray); WhereNull/WhereNotNull -> WhereIsNull/WhereIsNotNull; agregados
    mantidos como Count/Sum/Max/Min/Avg (nomes curtos, fluencia).
  - 1.4.0 (12/07/2026): Onda 5.5 - SchemaSync nucleo (Definition/Inspector/
    Comparer/Migrator idempotente + schema_version) + Onda 0 (revisao F5):
    reconstrucao do modulo na pasta Database limpa - QueryBuilder classe unica
    sob USE_DEPRECATED, sem units .Legacy; TVariableType gated.
  - 1.3.0 (12/07/2026): Onda 5.4 - QueryTransformer (B3): filtros tipados
    bindados, Include/Visible, paginacao por wrap sobre o QueryBuilder v3.
  - 1.2.0 (12/07/2026): Onda 5.3 - QueryBuilder v3 (params bindados, mutations,
    subqueries/UNION/CTE/CASE sobre IDialect).
  - 1.1.0 (12/07/2026): Onda 5.2 - dialectos SQL (IDialect).
  - 1.0.0 (12/07/2026): versao inicial (FASE 5 Onda 5.1).
  ============================================================================= }
unit Database.Version;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

const
  DATABASE_VERSION_MAJOR = 3;
  DATABASE_VERSION_MINOR = 4;
  DATABASE_VERSION_PATCH = 0;
  DATABASE_VERSION       = '3.4.0';
  DATABASE_VERSION_DATE  = '11/08/2026';

  { Forma legivel para logs / About box. }
  DATABASE_VERSION_FULL  = 'Database ' + DATABASE_VERSION +
                           ' (' + DATABASE_VERSION_DATE + ')';

implementation

end.
