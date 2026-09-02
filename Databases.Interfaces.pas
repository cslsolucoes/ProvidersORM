{ =============================================================================
  Databases.Interfaces - Superficie UNICA de interfaces do modulo Database

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.4.1
  FileVersion:    3.4.1
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           01/08/2026

  Consolidacao FINAL (25/07/2026): fusao das 3 units de interface que ainda
  restavam separadas no modulo Database num UNICO ficheiro Databases.Interfaces
  (singular, convencao <Module>.Interfaces.pas). Absorve VERBATIM:
    - Database.TypeDatabase.Interfaces  -> ITypeDatabase (ungated)
    - Database.Dialect.Interfaces       -> IDialect + 10 facetas DDL (USE_DATABASE)
    - Databases.Interfaces (plural, ex-Reorg 1) -> as 22+ interfaces do modulo
  Ordem topologica de dependencia: TypeDatabase -> Dialect -> Databases (o bloco
  Databases referencia IDialect/ITypeDatabase, agora declarados ACIMA no mesmo
  ficheiro; nenhuma das 2 pecas de baixo nivel depende do bloco Databases, sem
  ciclo). Sem shims/aliases (B-freeze). Estrategia C (quebra interna deliberada):
  os consumidores trocam `uses Databases.Interfaces[, Database.Dialect.Interfaces]
  [, Database.TypeDatabase.Interfaces]` por `uses Databases.Interfaces`. Todos os
  consumidores sao INTERNOS (src/ + tests) - v3 e pre-merge, sem consumidores
  externos. Gating preservado do fisico das fontes: ITypeDatabase e as interfaces
  ungated de Databases ficam sem IFDEF; IDialect/facetas + ICatalogReader + SchemaSync
  + QueryBuilder/QueryTransformer + Async ficam sob USE_DATABASE.

  Changelog (file):
  - 3.4.1 (01/08/2026): bug-1083 (FPC 3.2.2 Internal error 200602034) - REMOVE
    o forward declaration `IIdentityMap<T: class> = interface;` (secao dos
    forwards da Onda 7). Causa raiz isolada em repro minimo de 12 linhas
    (.workspace/fpc-ice-repro/unit-repro/): o FPC 3.2.2 ICEa em
    FindUnitSymtable (symtype.pas:257, symtable nil) ao finalizar a seccao
    interface de uma UNIT que contenha um forward de interface GENERICA -
    mesmo nunca usado; programas (.lpr) nao disparam (nao ha CRC/deref de
    interface), razao por que os repros-programa anteriores nunca o
    reproduziram. Diferente e independente do bug-1074 (2012101001,
    especializacao antes da decl completa). Fix = Padrao A completo: a decl
    completa (movida para antes de IDatabase no 3.4.0) passa a ser a UNICA
    declaracao - sem forward. Nada referencia IIdentityMap entre a antiga
    posicao do forward e a decl completa (verificado por grep), logo a
    remocao e inerte para Delphi/FPC 3.3.1. Gate provado em mirror isolado:
    unit real completa compila limpa nos 6 alvos (dcc32/dcc64 + fpc 3.2.2
    win32/64 + fpc 3.3.1 win32/64), PPU/DCU gerados.
  - 3.4.0 (01/08/2026): bug-1074 (FPC 3.2.2 Internal error 2012101001) - move a
    declaracao COMPLETA de IIdentityMap<T: class> (era mais abaixo, apos
    IDatabase) para ANTES de IDatabase (antes do ponto de especializacao
    IIdentityMap<TObject> em IDatabase.IdentityMap). O FPC 3.2.2 ICEa ao
    especializar um generico forward-declarado ANTES da sua declaracao
    completa; o FPC 3.3.1 e o Delphi aceitam ambos os moldes (bug exclusivo
    do compilador 3.2.2). Causa raiz + solucao provadas isoladamente (30
    compilacoes, 5 .lpr x 6 alvos, incl. molde realista de 5 forwards
    interleaved) em .workspace/fpc-ice-repro/ ANTES desta aplicacao - ver
    .workspace/fpc-ice-repro/README.md. Reordenacao PURA - contrato publico
    IDatabase.IdentityMap: IIdentityMap<TObject> inalterado, GUID/metodos de
    IIdentityMap<T> inalterados; IUnitOfWork/IEntityManager/ISynchronize/
    IQueryBuilder continuam forward-declarados no MESMO bloco `type`
    continuo (nao reaberto), completando-se como antes. Gate obrigatorio
    antes de fechar: 6 alvos (dcc32/dcc64 + fpc 3.2.2 win32/64 + fpc 3.3.1
    win32/64) EXIT=0 + regressao da suite Database sem FAIL (ver
    .workspace/plans/providersorm-v3-f5-fpc322-ice-identitymap_v1.0.plan.md).
  - 3.3.1 (30/07/2026): auditoria adversarial ao ApplyStructure (fix #2) -
    ISchemaColumn ganha Scale: Integer (getter, ADITIVO) e ISchemaTable.
    AddColumn ganha o parametro AScale: Integer = 0 (ADITIVO, default 0 -
    nenhum call-site existente muda de assinatura efectiva). Motivo: colunas
    DECIMAL/NUMERIC com escala (ex.: NUMERIC(18,4)) guardam o tamanho em
    IField.Precision/Scale, NAO em Size (ver Database.Field.ParseColumnType
    Dimensions) - sem este par, SchemaAddTableToDefinition (Database.Schema.
    pas) so' tinha acesso a Size (=0 para estes campos) e ApplyStructure
    materializava sempre DECIMAL(18,0), perdendo a escala real. Ver tambem
    Database.Synchronize.pas (TSchemaColumn/TSchemaComparer, unico
    implementador/consumidor) e Database.Schema.pas (SchemaAddTableToDefinition).
  - 3.3.0 (30/07/2026): Onda S3b (ADITIVO - MATERIALIZACAO do merge, o
    "apply" do versionamento) - ISchema/IDatabase ganham ApplyStructure
    (const AConnection: IConnection): ISchema/IDatabase - aplica a ESTRUTURA
    guardada em memoria (FGroups/FViews/FRoutines/FTriggers/FRules) a uma
    conexao REAL, criando os objectos em falta, de forma IDEMPOTENTE - ZERO
    SQL novo, reusa 100% os motores ja existentes: (1) tabelas+colunas+PK+
    uniques+indexes via TSynchronize.Sync (Onda 5.5/5.5-B, idempotente por
    Compare); (2) FK via ITable.AddForeignKey(conn,...) (Onda D, idempotente
    via ICatalogReader.ForeignKeyExists), so DEPOIS de todas as tabelas
    existirem; (3) views/procedures/functions/triggers/rules via os
    LANCADORES Connection-bound ja existentes (IViews/IProcedures/
    IFunctions/ITriggers/IRules, Onda R2/F1/F3/F4 - todos ja idempotentes,
    todos ja degradam graciosamente onde o motor nao suporta o objecto).
    ISchemas/IDatabases ganham a agregacao trivial (ApplyStructure em cada
    elemento). Novo par de getters em ITable - Uniques: TSchemaUniques/
    Indexes: TSchemaIndexes (Onda S3b, ADITIVO) - simetricos aos ja
    existentes em ISchemaTable (Database.Synchronize, MESMO tipo de
    Commons.Database.Types, regra #14 anti-duplicacao); ate esta onda
    FUniques/FIndexes (Onda S2-b1) so eram legiveis via StructureToJSON - o
    bridge ITable->ISchemaDefinition (SchemaAddTableToDefinition, novo helper
    privado de Database.Schema.pas) precisa do MODELO tal-qual, sem round-
    trip JSON. UNICA peca genuinamente NOVA desta onda (sem SSOT preexistente,
    confirmado por grep global antes de escrever): SchemaColumnTypeToKind,
    heuristica por substring que classifica o ColumnType RAW (string livre,
    dialect-specific, ja usado por CreateTableSQL) no TSQLColumnKind
    ABSTRACTO que TSynchronize/IDialect.ColumnTypeFor exige - isIdentity
    (campo dedicado, IField.IsIdentity) resolve o caso ckIdentity SEM
    heuristica. Fluente (devolve Self); nunca lanca (degrada 0/no-op quando
    USE_DATABASE esta OFF, sem Connection ligada, ou o motor nao suporta um
    objecto - mesmo padrao de robustez de ToDDL/CreateSchema). Gate exigido:
    so COMPILACAO nos 4 alvos (validacao contra banco real fica para a
    proxima onda, S4). Zero mudanca de assinatura em qualquer metodo
    pre-existente.
  - 3.2.0 (30/07/2026): Onda S4 (ADITIVO - eixo FULL = Metadata+Data num so
    JSON, ModuleVersion 3.1.0 -> 3.2.0) - trio ToFullJSON/FromFullJSON/
    MergeFullFromJSON nos 8 niveis (IField/IFields/ITable/ITables/ISchema/
    ISchemas/IDatabase/IDatabases): ToFullJSON COMPOE os 2 eixos JA
    EXISTENTES (ESTRUTURA e DADO) sem reimplementar nenhum - objecto JSON de
    topo com as chaves "structure" (valor = StructureToJSON) e "data" (valor
    = ToJSON); FromFullJSON
    ("replace")/MergeFullFromJSON ("patch") decompoem via novo helper SSOT
    Database.Helpers.JSON.JSONExtractMember (extrai o texto JSON bruto de
    "structure"/"data" do objecto de entrada) e delegam, NESTA ORDEM
    (estrutura sempre antes de dado - a hidratacao de dado de alguns niveis,
    ex.: ITable/IFields, opera sobre campos JA EXISTENTES no container),
    a Structure*FromJSON e depois *FromJSON; tolerante - uma chave ausente
    simplesmente nao aplica esse eixo, nunca lanca. Export(AWithData)/
    Import(AJSON, AWithData, AMerge) ergonomicos nos 8 niveis - despacham
    para StructureToJSON/StructureFromJSON/StructureMergeFromJSON/
    ToFullJSON/FromFullJSON/MergeFullFromJSON conforme as 2 flags (ver
    comentario completo em IField.Export/Import). ITable/ISchema/IDatabase
    ganham ainda o overload Export(AWithData, AQuery: IQueryBuilder) (gated
    USE_DATABASE) - quando AWithData=True e AQuery<>nil, a parte "data" vem
    das LINHAS de AQuery.Execute (TDataSet), serializadas via
    TDataSetSerializeHelper.ToJSONArrayString (unit Serialize, Modulos/
    Database/Serialize - reutilizado, NUNCA SQL/parse novo); precisa de
    IConnection viva (AQuery.Connection, com fallback na Connection fluente
    do proprio objecto) - sem conexao viva ou AQuery=nil, cai graciosamente
    em ToFullJSON (NUNCA lanca, ao contrario de Execute). Covariancia sobre
    IFields/ITables (retorno ITable/ISchema/etc.) resolvida por clausula de
    resolucao de interface nas implementacoes (TTable/TSchema), MESMA
    tecnica ja usada por FromJSON/MergeFromJSON/StructureFromJSON/
    StructureMergeFromJSON. FromDDL/FromSQL continuam FORA de escopo
    (follow-up ja documentado na Onda S3). Zero mudanca de assinatura em
    qualquer metodo pre-existente.
  - 3.1.0 (29/07/2026): Onda S3 (ADITIVO - eixo SQL, ModuleVersion 3.0.0 ->
    3.1.0) - script DDL/DML REAL agregando os geradores *SQL JA EXISTENTES
    (zero SQL novo, so orquestracao): ITable/ISchema/IDatabase ganham ToDDL:
    string (script DDL na ordem de aplicacao - tabelas com PK/FK-por-campo
    inline+uniques/indexes -> views -> procedures/functions -> triggers ->
    rules); ISchemas/IDatabases ganham ToDDL trivial (agregam o ToDDL dos
    elementos). ITable/ITables ganham ToSQL: string (DML - INSERT do registo/
    de todos os registos, reutilizando IQueryBuilder.InsertInto/Value/ToSQL -
    ISchema herda ToSQL de ITables TAL-QUAL, sem override, mesmo padrao de
    DropTableSQL/RenameTableSQL). IQueryBuilder ganha o overload
    DatabaseTypes(TDatabaseTypes): IQueryBuilder/DatabaseTypes: TDatabaseTypes
    (dialecto INDEPENDENTE da conexao, MESMO padrao ja usado por ITable/
    ITables/ISchema/IDatabase - necessario para ToSQL ser dialect-aware sem
    exigir uma IConnection viva, sem depender do modulo Connections
    concreto/TConnection - so a INTERFACE IConnection e usada, boundary do
    modulo preservado). Decisao deliberada: ITable.ToDDL NAO repete
    AddForeignKeySQL para os campos com ReferencedTable preenchido -
    CreateTableSQL JA embute essa MESMA FK inline (mesma fonte de dados
    por-campo) - repetir duplicaria a constraint num 2o statement ALTER TABLE,
    tornando o script INVALIDO; documentado no corpo de ITable.ToDDL e no
    changelog de Database.Table.pas. FromDDL/FromSQL (parse de SQL->modelo) -
    FORA de escopo desta onda (parse de SQL e nao-trivial cross-banco) -
    follow-up documentado, sem TODO no codigo publico (nada foi prometido/
    declarado). Zero mudanca de assinatura em qualquer metodo pre-existente.
  - 3.0.6 (29/07/2026): Onda S2-b1 (ADITIVO, comentario/contrato - SEM mudanca
    de assinatura) - documenta as novas chaves "uniques"/"indexes" de
    ITable.StructureToJSON/StructureFromJSON/StructureMergeFromJSON
    (implementacao em Database.Table.pas 1.14.0): TTable ganha o MODELO em
    memoria (FUniques/FIndexes, reusando TSchemaUnique/TSchemaIndex de
    Commons.Database.Types - SchemaSync/ISchemaTable ja usava o mesmo "dado
    puro", regra #14 anti-duplicacao) das constraints UNIQUE nomeadas/
    compostas e dos INDEXES (nome+colunas[+unique]) ao nivel da tabela - ate
    agora so existiam as operacoes IMPERATIVAS AddUnique/AddIndex (executam
    DDL, Onda D) sem nenhum contentor serializavel. PK/FK continuam POR-CAMPO
    (isPKey/referencedTable/...), inalterados. Zero mudanca de assinatura
    nesta unit (so comentario) - a implementacao concreta fica inteiramente
    em Database.Table.pas.
  - 3.0.5 (29/07/2026): Onda S2-a (ADITIVO, sem mudar contratos existentes) -
    simetria do trio To/From/Merge na serializacao JSON. IField ganha
    FromJSON (delega a LoadFromJSON, fluente), MergeFromJSON (patch do
    valor, dirty-aware) e StructureMergeFromJSON (patch de metadata por
    chave presente). IFields ganha MergeFromJSON (patch posicional dos
    valores) e StructureMergeFromJSON (patch aditivo por nome de coluna -
    existentes recebem StructureMergeFromJSON, ausentes sao criados, nada e
    removido). ITable/ITables/ISchema/ISchemas/IDatabase/IDatabases ganham
    StructureMergeFromJSON (ja tinham MergeFromJSON no eixo dado) - mesma
    semantica de patch aditivo por chave-nomeada/nome em cada nivel (tabela
    por TableName, schema por SchemaName, database por DatabaseName, campo
    por column), espelhando a composicao/delegacao ja usada pelo
    MergeFromJSON existente. Zero mudanca nos metodos pre-existentes.
  - 3.0.4 (27/07/2026): conformidade F5 (onda C5, B9) - TENTADO E REVERTIDO.
    Removido o re-export gated de TRowStatus/TSQLColumnKind/
    TFieldValidationError(s) por "dead code" (grep so pela forma qualificada
    Databases.Interfaces.TRowStatus, sem consumidores) - REPRODUZIU falha real
    em smoke_database_facade.dpr (E2003 Undeclared identifier), que testa
    DELIBERADAMENTE o contrato do barrel: `uses Databases.Interfaces` SOZINHO
    expoe estes 3 tipos pelo nome BARE. Revertido ao original; comentario
    ampliado com a prova empirica. Nenhuma mudanca de comportamento no
    ficheiro final.
  - 3.0.3 (27/07/2026): conformidade F5 (onda C5, B1, doc-only) - comentario
    marcando SetAsChanged/SetAsUnchanged/IsFieldChanged/IsFieldPrimaryKey como
    aliases de compat/ergonomia mantidos por decisao do owner (nao podados).
    Sem mudanca de assinatura/comportamento.
  - 3.0.2 (27/07/2026): conformidade F5 (onda C6, #4) - IDialect ganha
    FunctionsSQL(ASchema) (paridade com ProceduresSQL): SQL de listagem das
    FUNCTIONS de utilizador do banco/schema. Base '' (SQLite/Access/SQL
    Anywhere); overrides em PostgreSQL/SQLServer/MySQL/Firebird.
  - 3.0.1 (26/07/2026): conformidade F5 (onda C2, doc-only) - M10: aviso de SQL
    injection no IQueryBuilder cobrindo os metodos de SQL cru (SelectRaw/
    SelectComputed/FromVirtual/Join/LeftJoin/RightJoin/WhereRaw/Having/OrHaving).
    M8/M9: gotchas do ExecuteAsync na decl (descartar o IORMTask degenera em
    sincrono bloqueante; nao reutilizar a mesma instancia ate Await). Sem mudanca
    de codigo.
  - 3.0.0 (25/07/2026): consolidacao final (3 units -> 1). Fusao de
    Database.TypeDatabase.Interfaces + Database.Dialect.Interfaces dentro da
    ex-Databases.Interfaces, renomeada para Databases.Interfaces (singular). Os
    changelogs das 3 fontes ficam preservados nos blocos VERBATIM abaixo.
  ============================================================================= }

unit Databases.Interfaces;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}
interface

{$I ../../ORM.Defines.inc}

uses
{$IF DEFINED(FPC)}
  SysUtils,
  Variants,
{$ELSE}
  System.SysUtils,
  System.Variants,
{$ENDIF}
  Commons.Types,
  Commons.Database.Types,
  Connections.Interfaces
{$IFDEF USE_DATABASE}
  {$IF DEFINED(FPC)}
  , DB
  {$ELSE}
  , Data.DB
  {$ENDIF}
{$ENDIF}
  ;

type
  { ===== TypeDatabase (ungated) - absorvido de Database.TypeDatabase.Interfaces ===== }
  ITypeDatabase = interface
    ['{B8C9D0E1-F234-5678-9012-345678901234}']

    function DatabaseType(const AValue: TDatabaseTypes): ITypeDatabase; overload;
    function DatabaseType: TDatabaseTypes; overload;

    function SupportsSchema: Boolean;
    function GetIdentifierQuote: string;
    function GetIdentifierQuoteClose: string;
  end;

  { ===== Onda F1 (DDL fluente zero-SQL) - builder de ROTINAS (procedure/
    function). Tipos UNGATED de proposito: sao referenciados tanto por
    IRoutineDialect (gated USE_DATABASE, mais abaixo) como pelos launchers
    IProcedures/IFunctions (ungated). O DIALECTO compoe o CREATE especifico de
    cada banco a partir desta definicao - ver IRoutineDialect.CreateSQL(ADef)
    (overload) + TDialect.RoutineDefCreateSQL nos 5 motores com rotinas
    (PostgreSQL/MySQL/SQLServer/Firebird/SQLAnywhere; SQLite/Access = N/A ->
    BASE devolve ''). Impl do builder: Database.Routine (TRoutineDefinition). }

  { Tipo de rotina de banco. }
  TRoutineKind = (rkProcedure, rkFunction);

  { Direccao de um parametro de rotina (IN/OUT/INOUT, onde o banco distingue). }
  TParamDirection = (pdIn, pdOut, pdInOut);

  { Modo do corpo da rotina: vazio (no-op minimo por banco), RETURN <valor>
    (funcao/expressao simples) ou RAW (texto do corpo usado tal-qual). }
  TRoutineBodyMode = (rbmEmpty, rbmReturn, rbmRaw);

  { Parametro de rotina - dado puro (nome, tipo abstracto TSQLColumnKind,
    dimensao, direccao). O tipo fisico e resolvido por IDialect.ColumnTypeFor. }
  TRoutineParam = record
    Name      : string;
    Kind      : TSQLColumnKind;
    Size      : Integer;
    Direction : TParamDirection;
  end;
  TRoutineParamArray = array of TRoutineParam;

  { Builder FLUENTE de rotinas (procedure/function) - descreve a rotina (nome,
    tipo, parametros, tipo de retorno, corpo) sem uma unica linha de SQL cru; o
    dialecto compoe o CREATE especifico do banco. Setters devolvem a propria
    interface (estilo fluente). Impl: Database.Routine.TRoutineDefinition.New. }
  IRoutineDefinition = interface
    ['{F1A2B3C4-D5E6-47A8-9B0C-1D2E3F4A5B6C}']
    function Name(const AValue: string): IRoutineDefinition; overload;
    function Name: string; overload;
    function Kind(const AValue: TRoutineKind): IRoutineDefinition; overload;
    function Kind: TRoutineKind; overload;
    function Param(const AName: string; const AKind: TSQLColumnKind;
      const ASize: Integer = 0; const ADirection: TParamDirection = pdIn): IRoutineDefinition;
    function Params: TRoutineParamArray;
    function Returns(const AKind: TSQLColumnKind; const ASize: Integer = 0): IRoutineDefinition;
    function ReturnKind: TSQLColumnKind;
    function ReturnSize: Integer;
    function BodyEmpty: IRoutineDefinition;
    function BodyReturn(const AValue: Variant): IRoutineDefinition;
    function BodyRaw(const AValue: string): IRoutineDefinition;
    function BodyMode: TRoutineBodyMode;
    function BodyText: string;
  end;

  { ===== Onda F3 (triggers, zero-SQL) - builder + tipos UNGATED ===== }

  { Momento de disparo do trigger relativo ao evento DML. }
  TTriggerTiming = (ttBefore, ttAfter, ttInsteadOf);

  { Evento DML que arma o trigger. Combinavel via conjunto (onde o banco
    suporta multi-evento - PostgreSQL/Firebird 'OR', SQLServer/SQLAnywhere
    ','; MySQL/SQLite so um evento por trigger -> usa-se o PRIMEIRO do set). }
  TTriggerEvent  = (teInsert, teUpdate, teDelete);
  TTriggerEvents = set of TTriggerEvent;

  { Modo do corpo do trigger: vazio (no-op minimo composto por banco) ou RAW
    (texto do corpo usado tal-qual, dentro do wrapper BEGIN/END do banco). }
  TTriggerBodyMode = (tbmEmpty, tbmRaw);

  { Builder FLUENTE de triggers - descreve o trigger (nome, tabela, momento,
    eventos, granularidade, corpo) SEM uma unica linha de SQL cru; o dialecto
    compoe o CREATE TRIGGER especifico do banco (ITriggerDialect.CreateSQL ->
    TDialect.TriggerDefCreateSQL). Setters devolvem a propria interface (estilo
    fluente). Impl: Database.Trigger.TTriggerDefinition.New. UNGATED (paralelo a
    IRoutineDefinition), sempre disponivel para o lancador ITriggers. }
  ITriggerDefinition = interface
    ['{A7B8C9D0-E1F2-4A3B-8C4D-5E6F7A8B9C0D}']
    function Name(const AValue: string): ITriggerDefinition; overload;
    function Name: string; overload;
    function OnTable(const AValue: string): ITriggerDefinition; overload;
    function OnTable: string; overload;
    function Timing(const AValue: TTriggerTiming): ITriggerDefinition; overload;
    function Timing: TTriggerTiming; overload;
    { Adiciona UM evento ao conjunto (fluente, acumulativo). }
    function Event(const AValue: TTriggerEvent): ITriggerDefinition; overload;
    { Substitui o conjunto de eventos inteiro. }
    function Events(const AValue: TTriggerEvents): ITriggerDefinition; overload;
    function Events: TTriggerEvents; overload;
    function ForEachRow(const AValue: Boolean): ITriggerDefinition; overload;
    function ForEachRow: Boolean; overload;
    function BodyEmpty: ITriggerDefinition;
    function BodyRaw(const AValue: string): ITriggerDefinition;
    function BodyMode: TTriggerBodyMode;
    function BodyText: string;
  end;

  { ===== Onda F4 (rules, zero-SQL) - builder + tipos UNGATED ===== }

  { Evento de reescrita associado a uma RULE (semantica PostgreSQL query-rewrite;
    o SQL Server ignora - a RULE do SQL Server e uma constraint de valor de
    coluna, sem evento). }
  TRuleEvent = (reSelect, reInsert, reUpdate, reDelete);

  { Builder FLUENTE de RULES - objecto RULE existente APENAS em PostgreSQL
    (query-rewrite) e SQL Server (constraint de valor, legado). Semanticas
    divergentes -> o builder modela o minimo comum (nome, tabela, evento) +
    BodyRaw para o especifico do banco (PostgreSQL: accao DO, ex.: 'INSTEAD
    NOTHING'; SQL Server: expressao de condicao, ex.: '@val >= 0'). Nos outros
    5 motores a faceta devolve '' (N/A explicito). Impl:
    Database.Rule.TRuleDefinition.New. UNGATED (paralelo a ITriggerDefinition). }
  IRuleDefinition = interface
    ['{C1D2E3F4-A5B6-47C8-9D0E-1F2A3B4C5D6E}']
    function Name(const AValue: string): IRuleDefinition; overload;
    function Name: string; overload;
    function OnTable(const AValue: string): IRuleDefinition; overload;
    function OnTable: string; overload;
    function Event(const AValue: TRuleEvent): IRuleDefinition; overload;
    function Event: TRuleEvent; overload;
    function BodyRaw(const AValue: string): IRuleDefinition;
    function BodyText: string;
  end;

{$IFDEF USE_DATABASE}
  { ===== Dialect (gated USE_DATABASE) - absorvido de Database.Dialect.Interfaces ===== }
type
  { Onda D - facetas de manipulacao DDL por objeto (forward). }
  IFieldDialect    = interface;
  ITableDialect    = interface;
  ISchemaDialect   = interface;
  IDatabaseDialect = interface;
  IIndexDialect    = interface;
  IUniqueDialect   = interface;
  IPKeyDialect     = interface;
  IFKeyDialect     = interface;
  IViewDialect     = interface;
  IRoutineDialect  = interface;
  ITriggerDialect  = interface;
  IRuleDialect     = interface;

  IDialect = interface
    ['{E5F6A7B8-C9D0-4123-9EF0-56789012345A}']

    { identidade }
    function DatabaseType: TDatabaseTypes;
    function DialectName: string;
    function ServerVersionText: string; // ex.: 'Firebird 3.0+' (informativo)

    { Onda 6-a (I22) - deteccao da versao REAL do servidor via IConnection
      (reusa IConnection.GetServerVersion, kernel F4; SEM SQL proprio aqui).
      Devolve '' se AConnection=nil ou nao ligada (mesma semantica do kernel). }
    function DetectVersion(const AConnection: IConnection): string;

    { capabilities (consultar SEMPRE antes de emitir SQL especifico) }
    function Capabilities: TSQLCapabilities;
    function Supports(const ACapability: TSQLCapability): Boolean;
    function PaginationStyle: TSQLPaginationStyle;
    function MaxIdentifierLength: Integer; // 0 = sem limite documentado

    { quoting (via TTypeDatabase da 5.1) }
    function QuoteOpen: string;
    function QuoteClose: string;
    { quota cada parte de um nome qualificado ("schema"."tabela"); '*' passa }
    function QuoteIdentifier(const AName: string): string;

    { paginacao por estilo do dialecto (410023 se nao suportada) }
    function ApplyPagination(const ASelectSQL: string; const ALimit: Integer;
      const AOffset: Integer = 0): string;

    { mapeamento de tipos abstractos -> tipo SQL do banco/versao }
    function ColumnTypeFor(const AKind: TSQLColumnKind; const ASize: Integer = 0;
      const AScale: Integer = 0): string;

    { Onda 10-D (marshalling de VALOR cross-DB, ADITIVO) - representacao correcta
      de um valor BOOLEAN para BIND (parametro), homogenea por banco/versao. O
      write path (QueryBuilder.Bind) encaminha por aqui QUALQUER valor boolean
      antes de o bindar, para o gravar no formato que a COLUNA do banco aceita:
      bancos com BOOLEAN nativo (PostgreSQL; Firebird 3+) recebem um Variant
      boolean (ftBoolean); bancos que modelam boolean como bit/smallint/integer/
      tinyint (SQL Server, SQL Anywhere, SQLite, MySQL, Firebird 2.5) recebem
      0/1; Access (yes/no) recebe -1/0. Fecha o erro de tipagem estrita do
      PostgreSQL ("column is of type boolean but expression is of type
      smallint"). Simetrico ao READ (FieldAsBool). A implementacao BASE DERIVA
      da capability scBoolean (fonte unica - PostgreSQL/Firebird3+ ON, os demais
      OFF); so Access sobrepoe (-1/0). }
    function EncodeBoolean(const AValue: Boolean): Variant;
    { Fase 1 repasse - marshalling de DATETIME bindado por-banco (mesmo padrao
      do EncodeBoolean/Onda 10-D): base = passthrough (varDate, aceite pelos
      drivers); Access/Jet via ADO REJEITA varDate/Double no bind -> override
      devolve string 'yyyy-mm-dd hh:nn:ss' (aceite, provado por sonda 19/07).
      Consumido por TQueryBuilder.Bind (funil dos INSERT/UPDATE bindados). }
    function EncodeDateTime(const AValue: TDateTime): Variant;

    { registry de operadores decompostos (E3) }
    function HasOperator(const AName: string): Boolean;
    function RenderOperator(const AName: string;
      const AOperands: array of string): string;
    function RegisterOperator(const ADef: TSQLOperatorDef): IDialect;

    { DDL de nivel schema (Fatia B-d, Onda 4-cont) - CREATE/DROP SCHEMA por
      banco; ASchema e o nome (nao qualificado) do schema. Gate pela
      capability scSchemas na implementacao base: string vazia quando OFF
      (SQLite/Firebird/Access - sem schemas nativos). PostgreSQL/SQLServer
      (scSchemas ON) geram DDL real. MySQL faz override (schema~=database)
      e gera sempre, independente de scSchemas. }
    function CreateSchemaSQL(const ASchema: string): string;
    function DropSchemaSQL(const ASchema: string): string;

    { DDL de nivel database (Fatia B-e) - CREATE/DROP DATABASE por banco;
      AName e o nome (ou path/ficheiro, no caso Firebird) da base. SEM gate
      de capability (ao contrario de CreateSchemaSQL/scSchemas) - a
      implementacao BASE gera DDL real via QuoteIdentifier para QUALQUER
      dialecto: PostgreSQL/MySQL/SQLServer caem directamente nela. SQLite/
      Access (bases orientadas a FICHEIRO, sem DDL de criacao) fazem
      override -> devolvem string vazia. Firebird faz override -> sintaxe
      ISQL propria (CREATE DATABASE 'file' recebe STRING LITERAL entre
      aspas simples, nao um identificador QuoteIdentifier; DROP DATABASE
      nao recebe argumento - opera sobre a conexao ATIVA). }
    function CreateDatabaseSQL(const AName: string): string;
    function DropDatabaseSQL(const AName: string): string;

    { Onda 6-a (I21) - literais de DATA/TIMESTAMP por dialecto (bindar SQL
      literal ISO local, SEM depender de FormatSettings/locale do SO). Base
      ANSI (implementacao TDialect): 'aaaa-mm-dd' / 'aaaa-mm-dd hh:nn:ss'
      (MySQL/SQLServer/SQLite/Firebird usam a base sem override). PostgreSQL
      prefixa DATE '...' / TIMESTAMP '...' (literal tipado). Access usa
      delimitador #...# (Jet/ACE): #aaaa-mm-dd# / #aaaa-mm-dd hh:nn:ss#. }
    function DateLiteral(const ADate: TDateTime): string;
    function TimestampLiteral(const ADateTime: TDateTime): string;
    { faz o percurso inverso de DateLiteral/TimestampLiteral (reconhece os 3
      formatos - ANSI simples, DATE/TIMESTAMP prefixado, #...# Access);
      devolve False (ADate inalterado) se ALiteral nao corresponder a nenhum. }
    function TryParseDateLiteral(const ALiteral: string; out ADate: TDateTime): Boolean;

    { Onda 6-d PARTE 2 (I24) - descricoes de coluna (COMMENT ON COLUMN /
      MS_Description / RDB$DESCRIPTION / COLUMN_COMMENT, conforme o banco).
      Devolve o SQL que lista as colunas de ATable com a respetiva descricao;
      o resultado tem SEMPRE 2 colunas POSICIONAIS - [0]=nome da coluna,
      [1]=descricao (nunca NULL - dialectos usam COALESCE) - o consumidor
      (ICatalogReader.TableStructure) le por posicao, nao por nome (evita
      divergencia de casing entre drivers/providers). ASchema e opcional
      (fallback por dialecto quando omitido). Implementacao BASE devolve ''
      (nao suportado); SQLite/Access mantem-se na BASE (sem catalogo de
      descricoes de coluna padrao) - string vazia = no-op gracioso para o
      chamador (Description fica ''). }
    function ColumnDescriptionSQL(const ATable, ASchema: string): string;

    { F5-FU.1 (populacao de IsIdentity por dialecto, ADITIVO) - SQL que lista
      os NOMES das colunas AUTOINCREMENTO/IDENTITY de ATable (IDENTITY/SERIAL/
      AUTO_INCREMENT/GENERATED AS IDENTITY, conforme o dialecto). O resultado
      tem SEMPRE 1 COLUNA POSICIONAL - [0]=nome da coluna (mesmo padrao de
      LinkedServersSQL/ProceduresSQL/ViewsSQL); o consumidor (ICatalogReader.
      TableStructure, via ApplyColumnIdentity) le por posicao, casa por nome
      (case-insensitive) e marca TDatabaseFields.IsIdentity:=1. ASchema e
      opcional (fallback por dialecto quando omitido, mesma semantica de
      ColumnDescriptionSQL). Implementacao BASE devolve '' (nao suportado) -
      string vazia = no-op gracioso para o chamador (IsIdentity fica 0). }
    function IdentityColumnsSQL(const ATableName, ASchema: string): string;

    { Onda 6-e Estagio 3 (I13) - chamada de uma funcao ESCALAR canonica na
      sintaxe do dialecto. AName e o nome CANONICO ANSI ('UPPER'/'LOWER'/
      'COALESCE'/'LENGTH'/'SUBSTRING', case-insensitive) - qualquer outro
      nome cai na implementacao BASE (generica, "NOME(arg0, arg1, ...)"
      maiusculizado), o que cobre de graca toda a funcao ANSI-compativel
      SEM precisar de mais casos. AArgs sao expressoes SQL JA PRONTAS
      (identificadores ja quotados, literais/params ja formatados) - este
      metodo so compoe a chamada, NUNCA quota nem binda; o caller (ex.:
      QueryBuilder) e responsavel por Q()/Bind() antes de chamar. Overrides
      por banco so onde a sintaxe diverge da base ANSI - ver TDialect*. }
    function FunctionSQL(const AName: string; const AArgs: array of string): string;

    { Onda 6-f Estagio 1 (I10) - linked servers + stored procedures tipadas.
      Descoberta em ICatalogReader (Database.CatalogReader); SQL por banco AQUI (unico
      sitio com SQL especifico de motor); chamada em
      IQueryBuilder.CallProcedure. }

    { SQL que lista os linked/remote servers do motor. Base '' (nao
      suportado). Override: SQLServer (sys.servers WHERE is_linked=1).
      PostgreSQL fica na BASE de proposito - pg_foreign_server (postgres_fdw)
      e dblink sao extensoes OPCIONAIS e semanticamente distintas ("foreign
      server" generico vs "linked server" concreto) - AMBIGUO sem saber qual
      extensao esta instalada (regra "se ambiguo, base '' e documenta");
      MySQL/Firebird/SQLite/Access nao tem o conceito nativo - todos ficam na
      BASE. O resultado tem 1 COLUNA POSICIONAL - [0]=nome do servidor. }
    function LinkedServersSQL: string;

    { SQL que lista as stored procedures do banco/schema. Base '' (nao
      suportado). Overrides: SQLServer (sys.procedures), PostgreSQL
      (information_schema.routines, routine_type='PROCEDURE'), MySQL
      (INFORMATION_SCHEMA.ROUTINES, ROUTINE_TYPE='PROCEDURE' - ASchema e o
      BANCO, mesma semantica de ColumnDescriptionSQL), Firebird
      (RDB$PROCEDURES - ASchema ignorado, Firebird nao tem schemas). SQLite/
      Access ficam na BASE (sem o conceito de stored procedure). O resultado
      tem 1 COLUNA POSICIONAL - [0]=nome da procedure. }
    function ProceduresSQL(const ASchema: string): string;

    { Onda C6 (#4, paridade Views/Procedures) - SQL que lista as FUNCTIONS
      definidas pelo utilizador do banco/schema (scalar/table). Base ''
      (nao suportado). Overrides: PostgreSQL/SQLServer/MySQL
      (information_schema.routines / INFORMATION_SCHEMA.ROUTINES,
      routine_type='FUNCTION' - mesma semantica de schema/banco de
      ProceduresSQL), Firebird (RDB$FUNCTIONS - ASchema ignorado, Firebird
      nao tem schemas). SQLite/Access/SQL Anywhere ficam na BASE (sem
      catalogo de functions de utilizador introspetavel/validado). O
      resultado tem 1 COLUNA POSICIONAL - [0]=nome da function. }
    function FunctionsSQL(const ASchema: string): string;

    { Onda D (D.1) - SQL de LISTAGEM de VIEWS de um schema (introspecao). BASE =
      information_schema.views (PG/MySQL/SQLServer/SQL Anywhere); Firebird
      (RDB$RELATIONS com RDB$VIEW_SOURCE) e SQLite (sqlite_master type='view')
      fazem override. Resultado 1 COLUNA POSICIONAL - [0]=nome da view. }
    function ViewsSQL(const ASchema: string): string;

    { Onda F3 - SQL de LISTAGEM dos TRIGGERS (introspecao; 1 COLUNA POSICIONAL
      [0]=nome do trigger). BASE '' (nao suportado). Overrides: PostgreSQL
      (pg_trigger, WHERE NOT tgisinternal), MySQL (INFORMATION_SCHEMA.TRIGGERS,
      ASchema=banco), SQLServer (sys.triggers), Firebird (RDB$TRIGGERS, sem
      system flag), SQLite (sqlite_master type='trigger'), SQLAnywhere
      (SYS.SYSTRIGGER). Access -> BASE (sem triggers). }
    function TriggersSQL(const ASchema: string): string;

    { Onda F4 - SQL de LISTAGEM das RULES (introspecao; 1 COLUNA POSICIONAL
      [0]=nome da rule). BASE '' (nao suportado - MySQL/Firebird/SQLite/
      SQLAnywhere/Access). Overrides: PostgreSQL (pg_rules, excluindo o
      _RETURN implicito das views), SQLServer (sys.objects type='R'). }
    function RulesSQL(const ASchema: string): string;

    { SQL de CHAMADA de uma stored procedure, com AArgCount placeholders
      POSICIONAIS ':p0', ':p1', ..., ':p<AArgCount-1>' (NAO bindados por este
      metodo - o caller, IQueryBuilder.CallProcedure, substitui cada ':pN'
      pelo placeholder REAL do seu proprio mecanismo Bind, na mesma ordem -
      ver comentario completo em Databases.Interfaces.IQueryBuilder.
      CallProcedure). Base '' (no-op - SQLite/Access, sem sintaxe de chamada
      de procedure). Overrides: SQLServer 'EXEC <proc> :p0, :p1, ...' (sem
      parenteses); PostgreSQL/MySQL 'CALL <proc>(:p0, :p1, ...)'; Firebird
      'EXECUTE PROCEDURE <proc> :p0, :p1, ...' (sem parenteses). AProcName
      vazio -> '' em qualquer dialecto (mesmo guard nos 4 overrides).
      Identificador de AProcName sempre quotado via QuoteIdentifier (helper
      do proprio dialecto). }
    function CallProcedureSQL(const AProcName: string; const AArgCount: Integer): string;

    { ===== Onda 5.5-B (indices/constraints, ADITIVO) ===== }

    { SQL para adicionar uma constraint UNIQUE composta (AColumns na ordem) a
      uma tabela EXISTENTE. Base ANSI: 'ALTER TABLE t ADD CONSTRAINT name
      UNIQUE (c1, c2, ...)' (PostgreSQL/MySQL/SQLServer/Firebird). SQLite e
      Access fazem override -> 'CREATE UNIQUE INDEX name ON t (cols)' (nao
      suportam ALTER TABLE ADD CONSTRAINT). AName ou AColumns vazio -> ''.
      Identificadores quotados via QuoteIdentifier. }
    function AddUniqueSQL(const ATable, AName: string;
      const AColumns: array of string): string;

    { SQL para criar um indice (unico ou nao) sobre AColumns: 'CREATE [UNIQUE]
      INDEX name ON t (c1, c2, ...)'. Universal (a base cobre os 6 dialectos).
      AName ou AColumns vazio -> ''. }
    function CreateIndexSQL(const ATable, AName: string;
      const AColumns: array of string; const AUnique: Boolean): string;

    { SQL que lista os NOMES das constraints/indices UNICOS de ATable (para a
      idempotencia do SchemaSync). Resultado 1 COLUNA POSICIONAL - [0]=nome do
      objecto unico. Base ANSI (information_schema.table_constraints WHERE
      constraint_type='UNIQUE') cobre PostgreSQL/MySQL/SQLServer; SQLite
      (pragma_index_list WHERE "unique"=1) e Firebird (rdb$relation_constraints)
      fazem override; Access -> '' (introspecao de indices nao fiavel via SQL;
      o consumidor assume presente - ver ICatalogReader.UniqueExists). }
    function UniquesSQL(const ATable, ASchema: string): string;

    { SQL que lista os NOMES de TODOS os indices de ATable. Resultado 1 COLUNA
      POSICIONAL - [0]=nome do indice. NAO ha catalogo ANSI universal de
      indices -> base '' ; overrides PostgreSQL (pg_indexes), MySQL
      (information_schema.statistics), SQLServer (sys.indexes), SQLite
      (pragma_index_list), Firebird (rdb$indices). Access -> '' (base). }
    function IndexesSQL(const ATable, ASchema: string): string;

    { ===== Onda D - facetas de manipulacao DDL (API por objeto, verbos curtos) =====
      Cada faceta (Field/Table/...) agrupa add/drop/alter/rename do seu objeto
      com sintaxe homogeneizada por-banco; devolvem SQL (string). Simetria com a
      API-B de nivel: nivel `fields.add(...)` <-> dialeto `Field.AddSQL(...)`. }
    function Field: IFieldDialect;
    function Table: ITableDialect;
    function Schema: ISchemaDialect;
    function Database: IDatabaseDialect;
    function Index: IIndexDialect;
    function Unique: IUniqueDialect;
    function PKey: IPKeyDialect;
    function FKey: IFKeyDialect;
    function View: IViewDialect;
    function Routine: IRoutineDialect;
    function Trigger: ITriggerDialect;
    function Rule: IRuleDialect;
  end;

  { ===== Onda D - faceta FIELD =====
    add/drop/alter/rename de uma coluna (AField) de uma tabela (ATable). Sintaxe
    homogeneizada por-banco: Firebird/SQL Server ADD/DROP SEM 'COLUMN'; MySQL
    MODIFY; SQL Server sp_rename; SQLite ALTER->'' (o nivel usa table-rebuild
    D.2). AField/ATable vazio -> ''. }
  IFieldDialect = interface
    ['{A1B2C3D4-D001-4001-8001-0F1E2D3C4B5A}']
    function AddSQL(const ATable, AField, AFieldType: string; const ANotNull: Boolean): string;
    function DropSQL(const ATable, AField: string): string;
    function AlterSQL(const ATable, AField, ANewType: string; const ANotNull: Boolean): string;
    function RenameSQL(const ATable, AOldName, ANewName: string): string;
  end;

  { Faceta TABLE: create/drop/rename. DropSQL usa IF EXISTS onde scDropIfExists;
    RenameSQL PG/SQLite/MySQL 'RENAME TO', SQL Server sp_rename, Firebird ''. }
  ITableDialect = interface
    ['{A1B2C3D4-D002-4002-8002-0F1E2D3C4B5A}']
    function CreateSQL(const ATable, AColumnsClause, ASchema: string): string;
    function DropSQL(const ATable, ASchema: string; const AIfExists: Boolean): string;
    function RenameSQL(const AOldName, ANewName: string): string;
  end;

  { Faceta SCHEMA: create/drop delegam aos metodos flat (gated scSchemas); rename raro. }
  ISchemaDialect = interface
    ['{A1B2C3D4-D003-4003-8003-0F1E2D3C4B5A}']
    function CreateSQL(const ASchema: string): string;
    function DropSQL(const ASchema: string): string;
    function RenameSQL(const AOldName, ANewName: string): string;
  end;

  { Faceta DATABASE: create/drop delegam aos metodos flat; rename raro. }
  IDatabaseDialect = interface
    ['{A1B2C3D4-D004-4004-8004-0F1E2D3C4B5A}']
    function CreateSQL(const AName: string): string;
    function DropSQL(const AName: string): string;
    function RenameSQL(const AOldName, ANewName: string): string;
  end;

  { Faceta INDEX: create (delega CreateIndexSQL) / drop (base 'DROP INDEX n';
    MySQL/SQLServer 'DROP INDEX n ON t'). }
  IIndexDialect = interface
    ['{A1B2C3D4-D005-4005-8005-0F1E2D3C4B5A}']
    function CreateSQL(const ATable, AName: string; const AColumns: array of string; const AUnique: Boolean): string;
    function DropSQL(const ATable, AName: string): string;
  end;

  { Faceta UNIQUE: add (delega AddUniqueSQL) / drop (base 'ALTER TABLE t DROP
    CONSTRAINT n'; SQLite/Access 'DROP INDEX n'). }
  IUniqueDialect = interface
    ['{A1B2C3D4-D006-4006-8006-0F1E2D3C4B5A}']
    function AddSQL(const ATable, AName: string; const AColumns: array of string): string;
    function DropSQL(const ATable, AName: string): string;
  end;

  { Faceta PRIMARY KEY: add 'ALTER TABLE t ADD CONSTRAINT n PRIMARY KEY (cols)';
    drop 'ALTER TABLE t DROP CONSTRAINT n' (MySQL 'DROP PRIMARY KEY'). }
  IPKeyDialect = interface
    ['{A1B2C3D4-D007-4007-8007-0F1E2D3C4B5A}']
    function AddSQL(const ATable, AName: string; const AColumns: array of string): string;
    function DropSQL(const ATable, AName: string): string;
  end;

  { Faceta FOREIGN KEY: add 'ALTER TABLE t ADD CONSTRAINT n FOREIGN KEY (cols)
    REFERENCES rt (rc) [ON DELETE d] [ON UPDATE u]'; drop 'ALTER TABLE t DROP
    CONSTRAINT n' (MySQL 'DROP FOREIGN KEY'). }
  IFKeyDialect = interface
    ['{A1B2C3D4-D008-4008-8008-0F1E2D3C4B5A}']
    function AddSQL(const ATable, AName: string; const AColumns: array of string;
      const ARefTable: string; const ARefColumns: array of string;
      const AOnDelete, AOnUpdate: string): string;
    function DropSQL(const ATable, AName: string): string;
  end;

  { Faceta VIEW: create 'CREATE [OR REPLACE] VIEW n AS s'; drop 'DROP VIEW
    [IF EXISTS] n'; alter (CREATE OR REPLACE / ALTER VIEW). }
  IViewDialect = interface
    ['{A1B2C3D4-D009-4009-8009-0F1E2D3C4B5A}']
    function CreateSQL(const AName, ASelectSQL: string; const AOrReplace: Boolean): string;
    function DropSQL(const AName: string; const AIfExists: Boolean): string;
    function AlterSQL(const AName, ASelectSQL: string): string;
  end;

  { Faceta ROUTINE (procedure/function): o CORPO e especifico de cada banco - o
    dialeto compoe/passa o CREATE e o DROP 'DROP PROCEDURE|FUNCTION [IF EXISTS] n'. }
  IRoutineDialect = interface
    ['{A1B2C3D4-D00A-400A-800A-0F1E2D3C4B5A}']
    { legado (pass-through do corpo - o caller fornece o CREATE completo) }
    function CreateSQL(const AName, ABody: string; const AIsFunction: Boolean): string; overload;
    { Onda F1 - zero-SQL: o dialecto compoe o CREATE a partir do builder de
      rotinas (delega a TDialect.RoutineDefCreateSQL). '' quando o motor nao
      suporta rotinas (SQLite/Access). }
    function CreateSQL(const ADef: IRoutineDefinition): string; overload;
    function DropSQL(const AName: string; const AIsFunction, AIfExists: Boolean): string;
  end;

  { Onda F3 - faceta TRIGGER: compoe o CREATE TRIGGER a partir do builder
    ITriggerDefinition (corpo/wrapper especifico por banco - PostgreSQL emite
    FUNCTION + TRIGGER); drop 'DROP TRIGGER [IF EXISTS] n [ON t]'. CreateSQL e
    DropSQL podem devolver MULTIPLOS statements separados pelo caractere NUL
    (#0) - o lancador ITriggers executa cada parte por ExecuteCommand (unica
    forma limpa de cobrir o par FUNCTION+TRIGGER do PostgreSQL sem SQL cru fora
    do dialecto). BASE '' onde o banco nao tem triggers (Access). }
  ITriggerDialect = interface
    ['{A1B2C3D4-D00B-400B-800B-0F1E2D3C4B5A}']
    function CreateSQL(const ADef: ITriggerDefinition): string;
    function DropSQL(const AName, ATable: string; const AIfExists: Boolean): string;
  end;

  { Onda F4 - faceta RULE (so PostgreSQL + SQL Server): compoe o CREATE RULE a
    partir do builder IRuleDefinition; drop 'DROP RULE [IF EXISTS] n [ON t]'
    (PostgreSQL exige ON table). BASE '' nos outros 5 motores (N/A). }
  IRuleDialect = interface
    ['{A1B2C3D4-D00C-400C-800C-0F1E2D3C4B5A}']
    function CreateSQL(const ADef: IRuleDefinition): string;
    function DropSQL(const AName, ATable: string; const AIfExists: Boolean): string;
  end;
{$ENDIF}

  { ===== Databases (superficie consolidada, ex-Reorg 1) - VERBATIM ===== }
type
  { ===== Onda 7 - camada de lancadores fluentes: forward declarations =====
    IDatabase/ISchema/ITable (declarados nas seccoes seguintes deste
    ficheiro) ganham metodos lancadores que DELEGAM aos modulos de operacao
    do Database (nome do lancador = nome do modulo = I<Modulo> - ver memory
    database-launchers-design). As interfaces de operacao completas so
    aparecem MAIS ABAIXO neste mesmo ficheiro (IUnitOfWork/IEntityManager,
    seccao ungated; ICatalogReader/ISynchronize/IQueryBuilder, seccao
    USE_DATABASE) - forward declarations padrao Object Pascal (mesma tecnica
    ja usada abaixo para "ITable = interface;"/"IQueryBuilder = interface;"
    mutuamente referenciados), para nao ter de reordenar/mover nenhum bloco
    ja existente (risco zero sobre a Reorg 1). }
  { NOTA (bug-1083, 01/08/2026): IIdentityMap<T: class> NAO pode ser
    forward-declarada aqui - um forward de interface GENERICA numa unit
    dispara Internal error 200602034 no FPC 3.2.2 ao fechar a seccao
    interface (FindUnitSymtable/symtable nil), mesmo que nunca usado.
    A declaracao completa vive antes de IDatabase (ver bloco IdentityMap
    mais abaixo, pos bug-1074); forwards de interfaces NAO-genericas
    continuam seguros. }
  IUnitOfWork = interface;
  IEntityManager = interface;
{$IFDEF USE_DATABASE}
  ISynchronize = interface;
  IQueryBuilder = interface;
{$ENDIF}

  { ===== Fields (Database.Field/Fields.Interfaces) ===== }

  IField = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-F23456789012}']

    { Metadados (get/set fluente) }
    function Table(const AValue: string): IField; overload;
    function Table: string; overload;
    function Column(const AValue: string): IField; overload;
    function Column: string; overload;
    { Nome logico (Onda 6-b I7) - identidade de negocio do campo, independente
      do nome fisico da coluna (Column); resolvido pela ITable dona do campo
      (ver ITable.PhysicalColumn). Default '' (sem LogicalName configurado -
      comportamento inalterado). }
    function LogicalName(const AValue: string): IField; overload;
    function LogicalName: string; overload;
    { Descricao do campo (Onda 6-d PARTE 2, I24) - texto legivel associado a
      coluna no catalogo do banco (COMMENT ON COLUMN / MS_Description /
      RDB$DESCRIPTION / COLUMN_COMMENT, conforme o dialecto - ver
      IDialect.ColumnDescriptionSQL). Preenchida automaticamente por
      ICatalogReader.TableStructure quando o dialecto suporta e a conexao esta
      ligada (Database.CatalogReader); tambem pode ser definida manualmente.
      Default '' (sem Description - comportamento inalterado). }
    function Description(const AValue: string): IField; overload;
    function Description: string; overload;
    function ColumnType(const AValue: string): IField; overload;
    function ColumnType: string; overload;
    function ColumnTypeCode(const AValue: Integer): IField; overload;
    function ColumnTypeCode: Integer; overload;

    { Metadados de dimensao (get/set fluente). Populados automaticamente pelo
      parser do setter ColumnType(AValue) - decompoe o conteudo entre parenteses:
      1 numero -> Size (ex.: VARCHAR(50) -> Size=50; NUMERIC(18) -> Size=18);
      2 numeros separados por virgula -> Precision,Scale (ex.: DECIMAL(10,2));
      sem parenteses -> 0,0,0. Os setters abaixo permitem override manual
      explicito depois do parse (ex.: StructureFromJSON aplica os valores
      persistidos por cima do parse derivado do texto de ColumnType). }
    function Size(const AValue: Integer): IField; overload;
    function Size: Integer; overload;
    function Precision(const AValue: Integer): IField; overload;
    function Precision: Integer; overload;
    function Scale(const AValue: Integer): IField; overload;
    function Scale: Integer; overload;

    function IsNull(const AValue: Boolean): IField; overload;
    function IsNull: Boolean; overload;
    function IsPKey(const AValue: Boolean): IField; overload;
    function IsPKey: Boolean; overload;
    { R2.5 (f5-repair): flag de coluna autoincremento (IDENTITY / GENERATED AS
      IDENTITY / generator+trigger), populada pela introspeção do catálogo
      (TCatalogReader) por dialecto. Default False; parte do EIXO ESTRUTURA. }
    function IsIdentity(const AValue: Boolean): IField; overload;
    function IsIdentity: Boolean; overload;
    function Position(const AValue: Integer): IField; overload;
    function Position: Integer; overload;
    function ConstraintName(const AValue: string): IField; overload;
    function ConstraintName: string; overload;
    function ReferencedTable(const AValue: string): IField; overload;
    function ReferencedTable: string; overload;
    function ReferencedColumn(const AValue: string): IField; overload;
    function ReferencedColumn: string; overload;
    function OnUpdateRule(const AValue: string): IField; overload;
    function OnUpdateRule: string; overload;
    function OnDeleteRule(const AValue: string): IField; overload;
    function OnDeleteRule: string; overload;

    { Valor e estado }
    function Value: Variant; overload;
    function Value(const AValue: Variant): IField; overload;
    function OriginalValue: Variant; overload;                       // valor original carregado (referencia do dirty inteligente - modelo v1.6.1)
    function OriginalValue(const AValue: Variant): IField; overload; // define o valor original e recalcula o IsChanged
    function ToDefault: IField;
    function IsChanged: Boolean;
    function SetColumnValue(const AValue: Variant): IField;
    function SetColumnValueWithoutChange(const AValue: Variant): IField;
    function MarkChanged: IField;
    function MarkUnchanged: IField;
    { B1 (conformidade F5, onda C5) - SetAsChanged/SetAsUnchanged sao ALIASES
      de MarkChanged/MarkUnchanged (0 call-sites de producao). Decisao do
      owner: MANTER (nao podar) por compat/ergonomia - nao sao os metodos
      CANONICOS da hierarquia mas ficam disponiveis. }
    function SetAsChanged: IField;
    function SetAsUnchanged: IField;

    { Helpers }
    { B1 (conformidade F5, onda C5) - IsFieldChanged/IsFieldPrimaryKey sao
      ALIASES de IsChanged/IsPKey (0 call-sites de producao). Decisao do
      owner: MANTER por compat/ergonomia (mesma nota de SetAsChanged, acima). }
    function IsFieldChanged: Boolean;
    function IsFieldPrimaryKey: Boolean;
    function FieldAllowsNull: Boolean;

    { Serialização em 2 EIXOS (Fatia B-a).
      ESTRUTURA (metadados de esquema, sem valor): column/columnType/size/
      precision/scale/isNull/isPKey/position/columnTypeCode/constraintName/
      referencedTable/referencedColumn/onUpdateRule/onDeleteRule.
      DADO (so o valor corrente do campo): value. }
    function StructureToJSON: string;
    function StructureFromJSON(const AJSON: string): IField;
    { Onda S2-a (ADITIVO, simetria To/From/Merge) - PATCH de metadata: aplica
      SO as chaves presentes no JSON (column/columnType/size/precision/scale/
      isNull/isPKey/isIdentity/position/columnTypeCode/constraintName/
      referencedTable/referencedColumn/onUpdateRule/onDeleteRule/description/
      logicalName), mantendo as ausentes com o valor ATUAL do campo - NUNCA
      reseta (ao contrario do "reset" que StructureFromJSON faria se o JSON
      de entrada vier incompleto). Fluente. }
    function StructureMergeFromJSON(const AJSON: string): IField;
    function ToJSON: string;
    function LoadFromJSON(const AJSON: string): IField;
    { Onda S2-a (ADITIVO, simetria To/From/Merge) - "replace" no eixo DADO,
      mesmo mecanismo de LoadFromJSON (SetColumnValueWithoutChange -
      hidratacao limpa, IsChanged fica false), devolvendo a interface
      (fluente) - nome canonico do trio To/From/Merge esperado nos restantes
      niveis (Fields/Table/Tables/Schema/Schemas/Database/Databases). }
    function FromJSON(const AJSON: string): IField;
    { Onda S2-a (ADITIVO) - "patch" no eixo DADO: mesmo parse de FromJSON/
      LoadFromJSON, mas hidrata via SetColumnValue (dirty inteligente - so
      fica IsChanged=True quando o valor realmente difere de OriginalValue)
      em vez de SetColumnValueWithoutChange. Um campo tem um so valor -> o
      "patch" fica no TRACKING de dirty, nao na selectividade de chaves (essa
      fica em StructureMergeFromJSON, aplicada aos METADADOS). }
    function MergeFromJSON(const AJSON: string): IField;

    { Onda S4 (ADITIVO) - eixo FULL (Metadata + Data num so JSON, ver header
      do ficheiro) - COMPOE os 2 eixos JA EXISTENTES (ESTRUTURA e DADO), SEM
      reimplementar nenhum dos 2: ToFullJSON emite um objecto JSON de topo
      com as chaves "structure" (valor = StructureToJSON) e "data" (valor =
      ToJSON); FromFullJSON
      ("replace") le as chaves "structure"/"data" do JSON de entrada e
      delega, NESTA ORDEM (estrutura antes de dado - mesma disciplina dos
      restantes niveis, ver Databases.Interfaces.ITable.FromFullJSON), a
      StructureFromJSON e depois FromJSON; MergeFullFromJSON ("patch") idem
      com StructureMergeFromJSON+MergeFromJSON. Tolerante: uma chave ausente
      no JSON de entrada simplesmente NAO aplica esse eixo (o outro continua
      a ser aplicado normalmente) - nunca lanca por falta de "structure" ou
      "data". }
    function ToFullJSON: string;
    function FromFullJSON(const AJSON: string): IField;
    function MergeFullFromJSON(const AJSON: string): IField;

    { Export/Import ergonomicos (Onda S4, ADITIVO) - atalho sobre os eixos
      ESTRUTURA/FULL: Export(False) = StructureToJSON; Export(True) =
      ToFullJSON. Import despacha pelas 2 flags (AWithData, AMerge): False+
      False -> StructureFromJSON; False+True -> StructureMergeFromJSON;
      True+False -> FromFullJSON; True+True -> MergeFullFromJSON. }
    function Export(const AWithData: Boolean): string;
    function Import(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): IField;

    { Cópia }
    function Clone: IField;
  end;

  TFieldArray = array of IField;

  IFields = interface
    ['{C3D4E5F6-A7B8-9012-CDEF-345678901234}']

    function AddField(const AField: IField): IFields; overload;
    function AddField(const AColumn, AColumnType: string; AIsNull: Boolean): IFields; overload;
    function Add(const AField: IField): IFields;
    function Remove(const AFieldName: string): IFields;
    function Clear: IFields;

    function Fields(const AFieldName: string): IField;
    function GetFields(const AFieldName: string): IField;
    function GetFieldsByIndex(AIndex: Integer): IField;
    function GetFieldsList: TFieldArray;
    function FieldsCount: Integer;
    function FieldExist(const AFieldName: string): Boolean;

    function DatabaseTypes(const AValue: TDatabaseTypes): IFields; overload;
    function DatabaseTypes: TDatabaseTypes; overload;

    function HasChanges: Boolean;
    function ClearAllChanges: IFields;
    function GetAllChangedFieldNames: TStringArray;
    function GetPrimaryKey: IField;

    { Serialize em 2 EIXOS (Fatia B-a). ESTRUTURA: array de IField.StructureToJSON,
      hidratado (cria os IField) por StructureFromJSON. DADO: array de IField.ToJSON
      (so "value" por posicao), hidratado por FromJSON POSICIONALMENTE sobre os
      campos ja existentes no container (a estrutura ja tem de estar montada -
      o eixo dado nao carrega nome de coluna). }
    function StructureToJSON: string;
    function StructureFromJSON(const AJSON: string): IFields;
    { Onda S2-a (ADITIVO, simetria To/From/Merge) - PATCH aditivo POR NOME de
      coluna (ao contrario de StructureFromJSON, que faz Clear e reconstroi
      tudo por posicao): para cada elemento do array, se ja existe um IField
      com esse "column", aplica IField.StructureMergeFromJSON nele; se nao
      existe, cria via TField.New.StructureFromJSON e adiciona. NUNCA remove
      um campo existente que nao apareca no JSON de entrada. }
    function StructureMergeFromJSON(const AJSON: string): IFields;
    function ToJSON: string;
    function FromJSON(const AJSON: string): IFields;
    { Onda S2-a (ADITIVO) - "patch" posicional: mesmo percurso de FromJSON
      (hidrata os campos JA EXISTENTES no container, por posicao - o eixo
      dado de IField so carrega "value", sem nome de coluna), mas delega a
      IField.MergeFromJSON (dirty inteligente) em vez de IField.LoadFromJSON
      (hidratacao limpa) - sem exigir que o array de entrada cubra TODOS os
      campos (tolerante a tamanhos diferentes, mesma guarda de FromJSON). }
    function MergeFromJSON(const AJSON: string): IFields;

    { Onda S4 (ADITIVO) - eixo FULL (Metadata + Data num so JSON) - COMPOE os
      2 eixos JA EXISTENTES desta propria IFields, SEM reimplementar (mesmo
      padrao/ordem de composicao de IField.ToFullJSON/FromFullJSON/
      MergeFullFromJSON, acima, um nivel abaixo). }
    function ToFullJSON: string;
    function FromFullJSON(const AJSON: string): IFields;
    function MergeFullFromJSON(const AJSON: string): IFields;

    { Export/Import ergonomicos (Onda S4, ADITIVO) - ver comentario completo
      em IField.Export/Import, acima (mesma semantica de despacho). }
    function Export(const AWithData: Boolean): string;
    function Import(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): IFields;
  end;

  { ===== Tables (Database.Table/Tables.Interfaces) ===== }

  ITable = interface;

  { Onda 6-e Estagio 4 (A4) - hook de validacao CUSTOMIZADA (regras de
    negocio que ValidateFields, focado so em "obrigatorio sem valor", nao
    cobre), disparado por TTable.Execute IMEDIATAMENTE APOS a validacao
    embutida (ValidateFields) ter passado, SO para INSERT/UPDATE (dsInsert,
    dsEdit, os 2 ramos dsInactive inferidos insert/update) - NUNCA para
    DELETE (mesmo escopo do guard embutido). Devolve False (+ AErrors
    opcional, mesmo formato "Field,Message" de ValidateFields) para bloquear
    a operacao - Execute lanca EDatabaseValidationException/
    ERR_DATABASE_VALIDATION (reusado, sem novo codigo de erro), como se fosse
    um obrigatorio em falta. "of object" (padrao TOnLoadTablesProgress/
    TOnLoadFieldsProgress desta mesma unit - cross-compiler Delphi+FPC, sem
    "reference to"). }
  TOnTableValidate = function(const ATable: ITable; out AErrors: TFieldValidationErrors): Boolean of object;

  ITable = interface(IFields)
    ['{D4E5F6A7-B8C9-0123-DEF0-456789012345}']

    function TableName(const AValue: string): ITable; overload;
    function TableName: string; overload;
    { Nome logico da tabela (Onda 6-b I7), mesmo padrao de TableName. }
    function LogicalName(const AValue: string): ITable; overload;
    function LogicalName: string; overload;
    { Resolucao nome logico -> nome fisico (Onda 6-b I7): percorre os campos
      da tabela; se ALGUM campo tiver IField.LogicalName (apos Trim,
      case-insensitive via SameText) igual a AName, devolve o IField.Column
      (nome fisico) desse campo. Sem match (nenhum campo com esse
      LogicalName, ou nenhum campo com LogicalName configurado) -> devolve o
      proprio AName (fallback, comportamento identico a usar o nome dado
      directamente). }
    function PhysicalColumn(const AName: string): string;
    function Alias(const AValue: string): ITable; overload;
    function Alias: string; overload;
    { Fatia A (continuacao Onda 4) - conexao fluente da tabela; usada como
      fallback por Execute quando nenhuma IConnection e passada por parametro. }
    function Connection(const AConnection: IConnection): ITable; overload;
    function Connection: IConnection; overload;

    { Auditoria automatica (sub-passo 4.4): quando FieldDateCreated/
      FieldIsActive estao configurados (nome de coluna nao vazio) e a coluna
      existe na tabela, carimba Now()/1 nesses campos antes de montar o
      INSERT (efeito colateral aditivo; sem configuracao, comportamento
      inalterado). }
    function InsertSQL(const Optimized: Boolean = True): string;
    { Auditoria automatica (sub-passo 4.4): quando FieldDateUpdated esta
      configurado e a coluna existe, carimba Now() antes de montar o SET
      (entra no UPDATE dinamico Optimized=True). }
    function UpdateSQL(const Optimized: Boolean = True): string;
    { parametro por uniformidade; sem efeito - nao ha variante otimizada }
    function WhereByPrimaryKey(const Optimized: Boolean = True): string;
    { Soft delete (sub-passo 4.4): quando FieldIsDeleted esta configurado e a
      coluna existe na tabela, gera 'UPDATE ... SET "<deleted>"=1 [,
      "<updated>"=<now>]' em vez de 'DELETE FROM ...' fisico (design
      composable preservado - sem WHERE embutido). Sem FieldIsDeleted
      configurado, comportamento fisico inalterado. }
    function DeleteSQL(const Optimized: Boolean = True): string;

    function ExecuteInsert(const AConnection: IConnection): Integer;
    function ExecuteUpdate(const AConnection: IConnection): Integer;
    function ExecuteDelete(const AConnection: IConnection): Integer;
    { Executa a operacao (Insert/Update/Delete) conforme o Status (TRowStatus)
      do proprio registo; dsInactive infere pela PK (sem PK -> insert; com PK
      -> update). Reseta o Status para dsInactive apos executar com sucesso.
      AConnection tem prioridade; se nil, cai no fallback da conexao fluente
      Connection(v) (Fatia A). Se nenhuma das duas estiver disponivel, lanca
      EDatabaseException (ERR_DATABASE_NO_CONNECTION).
      Sub-passo 4.5 - guardas aplicadas ANTES de despachar por Status: (1)
      read-only/soft-deleted (ReadOnly=True OU FieldIsDeleted=1 no registo) ->
      EDatabaseReadOnlyException (ERR_DATABASE_READONLY); (2) dsEdit/dsDeleted
      sem chave primaria preenchida -> EDatabaseInvalidStatusException
      (ERR_DATABASE_INVALID_STATUS); (3) obrigatorios em falta no INSERT/UPDATE
      (nunca no DELETE) -> EDatabaseValidationException (ERR_DATABASE_VALIDATION),
      ver ValidateFields. }
    function Execute(const AConnection: IConnection): Integer; overload;
    { Overload sem parametro - usa exclusivamente a conexao fluente
      Connection(v) (mesma validacao/excecao do overload acima). }
    function Execute: Integer; overload;

    function CreateTableSQL(const ASchema: string = ''): string;
    function DropTableSQL(const ASchema: string = ''): string;
    function CreateTable(const AConnection: IConnection): Integer;
    function DropTable(const AConnection: IConnection): Integer;

    { ===== Onda D - manipulacao IMPERATIVA de CAMPO na estrutura VIVA =====
      Mesma semantica do par CreateTableSQL/CreateTable, aplicada a um campo:
      <Op>FieldSQL monta o SQL via a faceta IDialect.Field (dialecto resolvido
      pelo DatabaseTypes, sem exigir conexao - como CreateSchemaSQL); <Op>Field(
      conn) EXECUTA e e IDEMPOTENTE (consulta ICatalogReader antes: Add so se a coluna
      NAO existir; Drop/Alter so se existir; Rename so se a origem existir e o
      destino nao). Devolve as linhas afetadas por ExecuteCommand, ou 0 quando
      nada ha a fazer / dialecto sem suporte (mesma convencao de CreateTable/
      CreateSchema). AddField(conn,...) e overload distinto do AddField(...) em-
      memoria (IFields) pela IConnection inicial + retorno Integer. }
    function AddFieldSQL(const AName, AFieldType: string; const ANotNull: Boolean = False): string;
    function DropFieldSQL(const AName: string): string;
    function AlterFieldSQL(const AName, ANewType: string; const ANotNull: Boolean = False): string;
    function RenameFieldSQL(const AOldName, ANewName: string): string;
    function AddField(const AConnection: IConnection; const AName, AFieldType: string; const ANotNull: Boolean = False): Integer; overload;
    function DropField(const AConnection: IConnection; const AName: string): Integer;
    function AlterField(const AConnection: IConnection; const AName, ANewType: string; const ANotNull: Boolean = False): Integer;
    function RenameField(const AConnection: IConnection; const AOldName, ANewName: string): Integer;

    { ===== Onda D - CONSTRAINTS da tabela na estrutura VIVA (index/unique/PK/FK)
      ===== Mesma semantica dos campos: <Op>...SQL monta via a faceta do dialecto
      (Index/Unique/PKey/FKey); <Op>...(conn) executa e e IDEMPOTENTE (consulta
      ICatalogReader antes). Colunas em array of string. }
    function AddIndexSQL(const AName: string; const AColumns: array of string; const AUnique: Boolean): string;
    function DropIndexSQL(const AName: string): string;
    function AddIndex(const AConnection: IConnection; const AName: string; const AColumns: array of string; const AUnique: Boolean): Integer;
    function DropIndex(const AConnection: IConnection; const AName: string): Integer;
    function AddUniqueSQL(const AName: string; const AColumns: array of string): string;
    function DropUniqueSQL(const AName: string): string;
    function AddUnique(const AConnection: IConnection; const AName: string; const AColumns: array of string): Integer;
    function DropUnique(const AConnection: IConnection; const AName: string): Integer;
    function AddPrimaryKeySQL(const AName: string; const AColumns: array of string): string;
    function DropPrimaryKeySQL(const AName: string): string;
    function AddPrimaryKey(const AConnection: IConnection; const AName: string; const AColumns: array of string): Integer;
    function DropPrimaryKey(const AConnection: IConnection; const AName: string): Integer;
    function AddForeignKeySQL(const AName: string; const AColumns: array of string; const ARefTable: string; const ARefColumns: array of string; const AOnDelete, AOnUpdate: string): string;
    function DropForeignKeySQL(const AName: string): string;
    function AddForeignKey(const AConnection: IConnection; const AName: string; const AColumns: array of string; const ARefTable: string; const ARefColumns: array of string; const AOnDelete, AOnUpdate: string): Integer;
    function DropForeignKey(const AConnection: IConnection; const AName: string): Integer;

    { Onda S3b (ADITIVO) - leitura do MODELO em memoria de constraints
      UNIQUE/INDEX nomeadas/compostas (FUniques/FIndexes, Onda S2-b1) - ate
      esta onda so eram legiveis via StructureToJSON (round-trip JSON); estes
      2 getters devolvem o MESMO tipo (TSchemaUniques/TSchemaIndexes,
      Commons.Database.Types) ja usado por ISchemaTable.Uniques/Indexes
      (Database.Synchronize, regra #14 anti-duplicacao) - necessario para o
      bridge ITable->ISchemaDefinition de ApplyStructure (ver ISchema.
      ApplyStructure, abaixo) construir o ISchemaDefinition sem round-trip
      JSON. Read-only (a mutacao continua a ser AddUnique/AddIndex, Onda D). }
    function Uniques: TSchemaUniques;
    function Indexes: TSchemaIndexes;

    { ===== Onda S3 - eixo SQL (script DDL/DML REAL, para validar) =====
      ToDDL agrega os geradores *SQL JA EXISTENTES desta propria ITable (zero
      SQL novo), dialect-aware SEM exigir conexao ligada (via DatabaseTypes +
      TDialect.ForDatabaseType, herdado de IFields - mesmo padrao de
      CreateTableSQL/AddUniqueSQL/AddIndexSQL): CreateTableSQL (colunas+PK/NOT
      NULL - e FK POR-CAMPO INLINE, quando IField.ReferencedTable esta
      preenchido, ver corpo de TTable.CreateTableSQL) + AddUniqueSQL para cada
      FUniques + AddIndexSQL para cada FIndexes (Onda S2-b1, unico par de
      constraints que CreateTableSQL NAO cobre inline). NAO repete
      AddForeignKeySQL para os campos com ReferencedTable preenchido -
      CreateTableSQL JA embute essa MESMA FK inline (mesma origem de dados,
      IField.ReferencedTable/ReferencedColumn/OnDeleteRule/OnUpdateRule/
      ConstraintName) - repetir duplicaria a constraint (mesmo nome) num
      segundo statement ALTER TABLE ADD CONSTRAINT, tornando o script
      INVALIDO (erro "constraint ja existe" na generalidade dos motores) -
      documentado tambem no corpo de TTable.ToDDL. Cada statement sai
      terminado por ';', um por linha (script legivel, "um statement por
      linha" pedido pelo owner). }
    function ToDDL: string;
    { ToSQL (eixo DADOS - DML) - INSERT do registo actual, reutilizando
      IQueryBuilder (TQueryBuilder.New.InsertInto/Value/ToSQL - NUNCA SQL
      escrito a mao); gated USE_DATABASE (IQueryBuilder so existe sob esse
      define - degrada para '' quando OFF, mesmo padrao de QueryBuilder,
      acima). Dialect-aware sem exigir conexao ligada: usa a Connection
      fluente desta ITable se ja estiver injectada (fallback identico a
      Execute), senao passa DatabaseTypes ao IQueryBuilder (novo overload
      IQueryBuilder.DatabaseTypes, ver comentario completo nessa interface).
      Skip do MESMO criterio Optimized de InsertSQL (nao-nulavel + valor
      vazio - tipicamente a PK auto-increment ainda sem valor, para o motor a
      gerar). O SQL devolvido usa placeholders ':paramN' (contrato SEMPRE
      bindado do IQueryBuilder - Value nunca emite literal); os valores REAIS
      ficam disponiveis via IQueryBuilder.Params, nao substituidos aqui (faze-
      lo exigiria uma nova rotina de renderizacao literal - fora do escopo
      "reutilizar, zero SQL novo" desta onda). Tabela sem nome, sem campos, ou
      com TODOS os campos saltados pelo skip -> '' (mesma degradacao graciosa
      de InsertSQL quando Optimized deixa LCols vazio). }
    function ToSQL: string;

    { Compat (Sub-passo 4.5) - wrapper aditivo sobre ValidateFields; mesma
      semantica booleana de sempre (True = sem obrigatorios em falta). }
    function ValidateNotNullFields: Boolean;
    { Validacao no save (Sub-passo 4.5, novo) - percorre os campos
      obrigatorios (not FieldAllowsNull) e devolve em AErrors o detalhe
      (field,message) de cada um sem valor (vazio/Unassigned/Null). NUNCA
      acusa: (1) a chave primaria (IsPKey=True) - padrao AUTOINCREMENT/
      IDENTITY/SERIAL, PK vazia no INSERT e semantica ja estabelecida em
      Execute (dsInactive infere Insert); para dsEdit/dsDeleted a PK
      preenchida ja e exigida por uma guarda propria e mais precisa
      (EnsurePrimaryKeyPresent); (2) os 4 campos de auditoria/soft-delete
      configurados (FieldDateCreated/FieldDateUpdated/FieldIsDeleted/
      FieldIsActive, Sub-passo 4.4), mesmo quando NOT NULL na DDL: sao
      geridos pelo proprio TTable, nunca pelo chamador (DateCreated/IsActive
      carimbados por InsertSQL, DateUpdated por UpdateSQL, ambos DEPOIS
      desta validacao dentro de Execute; IsDeleted fica de proposito por
      preencher no INSERT para o DEFAULT da DDL prevalecer - so DeleteSQL o
      toca). Result = True quando AErrors fica vazio (nenhum obrigatorio em
      falta). }
    function ValidateFields(out AErrors: TFieldValidationErrors): Boolean;

    function HasChanges: Boolean;
    function GetChangedFieldNames: TStringArray;

    function Status: TRowStatus; overload;
    function Status(const AValue: TRowStatus): ITable; overload;

    { Guarda read-only (Sub-passo 4.5, novo; equivalente ao FDeletedBlock
      v1.6.1) - quando True, Execute/Save bloqueia INCONDICIONALMENTE
      qualquer operacao (Insert/Update/Delete) com EDatabaseReadOnlyException
      (ERR_DATABASE_READONLY). Default False (comportamento inalterado). }
    function ReadOnly(const AValue: Boolean): ITable; overload;
    function ReadOnly: Boolean; overload;

    { Onda 6-e Estagio 4 (A4) - hook de validacao CUSTOMIZADA (padrao fluente
      identico a ReadOnly); ver comentario completo em TOnTableValidate,
      acima. Default nil - Execute nao chama nada extra (comportamento
      inalterado). }
    function OnValidate(const AValue: TOnTableValidate): ITable; overload;
    function OnValidate: TOnTableValidate; overload;

    function AuditFields(const AValue: Boolean): ITable; overload;
    function AuditFields: Boolean; overload;
    function FieldDateCreated(const AValue: string): ITable; overload;
    function FieldDateCreated: string; overload;
    function FieldDateUpdated(const AValue: string): ITable; overload;
    function FieldDateUpdated: string; overload;
    function FieldIsDeleted(const AValue: string): ITable; overload;
    function FieldIsDeleted: string; overload;
    function FieldIsActive(const AValue: string): ITable; overload;
    function FieldIsActive: string; overload;

    { R2.3 (f5-repair) - introspeccao de SI mesma (delega ao catalogo interno,
      ICatalogReader) - schema fixo '' por agora, usa sempre a Connection/
      TableName fluentes ja existentes desta propria ITable. Assinatura
      UNGATED (nenhum destes 12 tipos referencia ICatalogReader); a implementacao
      (TTable) delega sob gate USE_DATABASE, degradando para vazio/False
      quando esse define esta OFF (mesmo padrao das facetas Onda D acima). }
    function TableStructure: TArray<TDatabaseFields>;
    function ColumnExists(const AColumnName: string): Boolean;
    function PrimaryKeyColumns: TStringArray;
    function PrimaryKeyExists: Boolean;
    function ForeignKeys: TArray<TDatabaseFields>;
    function ResolveFK: TArray<TRelationInfo>;
    function ForeignKeyNames: TStringArray;
    function ForeignKeyExists(const AConstraintName: string): Boolean;
    function UniqueNames: TStringArray;
    function IndexNames: TStringArray;
    function UniqueExists(const AConstraintName: string): Boolean;
    function IndexExists(const AIndexName: string): Boolean;

    { Serialize PROPRIA da Table (Fatia B-b, Onda 4-cont) - sobrepoe os 4
      metodos herdados de IFields (Database.Fields), que operam so a nivel dos
      campos (array posicional, sem TableName nem object_state).

      EIXO DADO (registo): ToJSON emite um objeto JSON com um par
      coluna/valor por campo mais a chave object_state (valores possiveis:
      UNMODIFIED, INSERTED, MODIFIED, DELETED), com o valor de cada campo
      tipado por ColumnType (case-insensitive): int/serial -> inteiro;
      num/dec/float/double/real/money/currency -> decimal (normaliza "," para
      "."); bool/bit/logical -> true/false; date/time/timestamp -> string
      ISO8601 LOCAL (UTC opt-in=False, sem deslocar fuso); resto -> string
      escapada RFC 8259; sem valor (IsNull/vazio) -> null. object_state
      deriva de Status (TRowStatus). FromJSON (retorno ITable - covariante
      sobre IFields.FromJSON: IFields; "replace" quando acedido via ITable)
      hidrata LIMPO por coluna (SetColumnValueWithoutChange - IsChanged fica
      false; coluna ausente no JSON e ignorada) + aplica object_state a
      Status. MergeFromJSON (novo, "patch") hidrata por coluna via
      SetColumnValue (dirty inteligente - so fica IsChanged quem realmente
      difere de OriginalValue) + aplica object_state a Status.

      EIXO ESTRUTURA: StructureToJSON emite um objeto JSON com as chaves
      table (nome da tabela), fields (array de IField.StructureToJSON),
      primaryKey (array com o nome das colunas PK), uniques (Onda S2-b1,
      ADITIVO - array de objectos name/columns[], constraints UNIQUE
      nomeadas/compostas ao nivel da tabela) e indexes (Onda S2-b1, ADITIVO -
      array de objectos name/columns[]/unique:bool, indices nomeados/multi-
      coluna). PK/FK
      continuam cobertos POR-CAMPO (isPKey/referencedTable/referencedColumn/
      onUpdateRule/onDeleteRule em cada elemento de "fields") - uniques/
      indexes cobrem apenas o que nao cabia por-campo (nome proprio +
      multi-coluna). StructureFromJSON (retorno ITable - covariante sobre
      IFields.StructureFromJSON: IFields) reconstroi TableName + campos (cria
      um IField por elemento de "fields" via IField.StructureFromJSON) +
      aplica IsPKey=True as colunas listadas em "primaryKey" + reconstroi por
      completo as uniques/indexes a partir de "uniques"/"indexes". }
    function ToJSON: string;
    function FromJSON(const AJSON: string): ITable;
    function MergeFromJSON(const AJSON: string): ITable;
    function StructureToJSON: string;
    function StructureFromJSON(const AJSON: string): ITable;
    { Onda S2-a (ADITIVO, simetria To/From/Merge) - PATCH aditivo de metadata
      da propria Table: mantem os campos EXISTENTES (identificados por
      Column - delega a IFields.StructureMergeFromJSON, herdado), cria os
      AUSENTES, NUNCA remove (ao contrario de StructureFromJSON, que
      reconstroi tudo por completo). "table"/"primaryKey" seguem a mesma
      logica aditiva (nome mantido se ausente; PK so acrescenta, nunca
      desmarca). Covariante sobre IFields.StructureMergeFromJSON - resolvida
      por clausula de resolucao de interface (mesma tecnica de
      StructureFromJSON, acima). Onda S2-b1 (ADITIVO) - "uniques"/"indexes"
      seguem a MESMA logica aditiva: PATCH por "name" (existente e
      actualizado no lugar - Columns[/Unique] - ausente e acrescentado, NUNCA
      remove um unique/index existente que nao apareca no JSON de entrada). }
    function StructureMergeFromJSON(const AJSON: string): ITable;

    { Onda S4 (ADITIVO) - eixo FULL (Metadata + Data num so JSON) - COMPOE os
      2 eixos JA EXISTENTES desta propria ITable, SEM reimplementar (mesmo
      padrao/ordem de composicao de IField.ToFullJSON/FromFullJSON/
      MergeFullFromJSON e IFields.ToFullJSON/FromFullJSON/MergeFullFromJSON,
      acima). Covariante sobre IFields.FromFullJSON/MergeFullFromJSON
      (retorno ITable) - resolvida por clausula de resolucao de interface
      (mesma tecnica de FromJSON/MergeFromJSON, acima). }
    function ToFullJSON: string;
    function FromFullJSON(const AJSON: string): ITable;
    function MergeFullFromJSON(const AJSON: string): ITable;

    { Export/Import ergonomicos (Onda S4, ADITIVO). Export(AWithData): atalho
      sobre StructureToJSON/ToFullJSON (ver IField.Export). Export(AWithData,
      AQuery) (overload, gated USE_DATABASE - IQueryBuilder so existe sob
      esse define) - quando AWithData=True e AQuery<>nil, a parte "data" NAO
      vem do ToJSON do modelo em memoria, vem das LINHAS devolvidas por
      AQuery.Execute (TDataSet), serializadas via
      TDataSetSerializeHelper.ToJSONArrayString (unit Serialize, Modulos/
      Database/Serialize - DataSet->JSON, reutilizado, NUNCA reimplementado);
      precisa de uma IConnection viva - se AQuery ja tiver a sua propria
      Connection(v) injectada, essa prevalece, senao e injectada a Connection
      fluente desta ITable (fallback FConnection, mesmo criterio de Execute/
      QueryBuilder, acima); sem Connection viva (nem em AQuery, nem nesta
      ITable) ou AQuery=nil, a parte "data" cai graciosamente no ToJSON do
      modelo (ToFullJSON simples, comportamento base) - NUNCA lanca por
      falta de conexao (ao contrario de Execute). Import despacha pelas 2
      flags (AWithData, AMerge) - mesma semantica de IField.Import, acima;
      retorno ITable (covariante), resolvido por clausula de resolucao de
      interface. }
    function Export(const AWithData: Boolean): string; overload;
{$IFDEF USE_DATABASE}
    function Export(const AWithData: Boolean; const AQuery: IQueryBuilder): string; overload;
{$ENDIF}
    function Import(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): ITable;

    { ===== Onda 7 - camada de lancadores fluentes =====
      DELEGAM aos modulos de OPERACAO do Database (nome do lancador = nome
      do modulo = I<Modulo>); a estrutura (ITable) e' a forma serializavel,
      as operacoes CONSOMEM essa forma, nunca a possuem. }

    { QueryBuilder PRE-CONFIGURADO com From(<nome fisico da tabela>) e
      Connection(v) desta ITable (fallback FConnection, tal como Execute) -
      ponto de partida pronto para .Where/.OrderBy/etc. sem repetir
      TableName/Connection a mao. Gated USE_DATABASE (IQueryBuilder so
      existe sob esse define). }
{$IFDEF USE_DATABASE}
    function QueryBuilder: IQueryBuilder;
{$ENDIF}
    { EntityManager MAPEADO a esta PROPRIA ITable (Table(Self) - sem
      MapTable/discovery via ICatalogReader, reusa os campos/valores ja
      presentes nesta instancia) e Connection(v) desta ITable. Resolucao de
      ciclo: Database.EntityManager.pas (que ja usa Database.Table para
      TTable.New em CloneTableStructure/MapTable) regista uma factory-
      function na var GTableEntityManagerFactory (declarada mais abaixo
      neste ficheiro, a seguir a IQueryBuilder - TEM de ficar apos a
      definicao COMPLETA de todos os forward types que usa, incl. o
      generico IIdentityMap<T>; um `var` intercalado ANTES de completar um
      forward type causa E2086 "not yet completely defined", confirmado por
      compilacao real) na sua secao `initialization`; esta guarda
      Assigned(...) devolve nil se essa unit nunca chegou a ser linkada no
      executavel. Gated USE_DATABASE+USE_ENTITY_MANAGER (a var so existe
      nessa combinacao - ver declaracao). }
{$IFDEF USE_DATABASE}
{$IFDEF USE_ENTITY_MANAGER}
    function EntityManager: IEntityManager;
{$ENDIF}
{$ENDIF}
    { UnitOfWork Connection-bound a esta ITable (fallback FConnection); o
      REGISTO da propria tabela (RegisterNew/Dirty/Deleted) fica ao cargo do
      caller - este lancador so poupa "TUnitOfWork.New.Connection(v)".
      Ungated (IUnitOfWork e Database.UnitOfWork.pas nao dependem de
      USE_DATABASE). }
    function UnitOfWork: IUnitOfWork;
  end;

  TTableArray = array of ITable;

  { Chamado a cada tabela carregada (ACurrent = índice 1-based, ATotal = total, ATableName = nome da tabela atual). }
  TOnLoadTablesProgress = procedure(const ACurrent, ATotal: Integer; const ATableName: string) of object;
  { Chamado ao carregar campos de cada tabela (ATableName, ACurrent/ATotal por tabela, AColumnName opcional). }
  TOnLoadFieldsProgress = procedure(const ATableName: string; const ACurrent, ATotal: Integer; const AColumnName: string) of object;

  ITables = interface
    ['{E5F6A7B8-C9D0-1234-EF01-567890123456}']
    function Connection(const AConnection: IConnection): ITables; overload;
    function Connection: IConnection; overload;
    function DatabaseTypes(const AValue: TDatabaseTypes): ITables; overload;
    function DatabaseTypes: TDatabaseTypes; overload;
    function Database(const AValue: string): ITables; overload;
    function Database: string; overload;
    function Schema(const AValue: string): ITables; overload;
    function Schema: string; overload;
    function SetOnLoadTablesProgress(const AValue: TOnLoadTablesProgress): ITables;
    function SetOnLoadFieldsProgress(const AValue: TOnLoadFieldsProgress): ITables;
    function LoadFromConnection(const ASchema: string = ''): ITables;
    function LoadTables: ITables;
    function Table(const AName: string): ITable;
    function GetTablesList: TTableArray;
    function TablesCount: Integer;
    function TableExists(const AName: string): Boolean;
    function GetTableNames(const ASchema: string = ''): TStringArray;
    function GetDatabaseNames: TStringArray;
    function GetSchemaNames(const ADatabase: string = ''): TStringArray;
    function GetColumnNames(const ATableName: string; const ASchema: string = ''): TStringArray;
    function GetTableStructure(const ATableName: string; const ASchema: string = ''): TArray<TDatabaseFields>;
    { R2.2 (f5-repair) - manipulacao IMPERATIVA de TABELA (por nome) neste
      container, POR NOME - mesma semantica de ISchema.DropTableSQL/
      RenameTableSQL/DropTable/RenameTable (nivel schema, acima), aqui
      aplicada ao proprio Schema fluente de ITables (getter Schema, ja
      existente). <Op>TableSQL monta via a faceta IDialect.Table (dialecto
      por DatabaseTypes); <Op>Table(conn) executa e e IDEMPOTENTE (consulta
      ICatalogReader.TableExists). Gated USE_DATABASE no corpo da implementacao
      (degrada para ''/0 quando OFF). }
    function DropTableSQL(const ATableName: string): string;
    function RenameTableSQL(const AOldName, ANewName: string): string;
    function DropTable(const AConnection: IConnection; const ATableName: string): Integer;
    function RenameTable(const AConnection: IConnection; const AOldName, ANewName: string): Integer;
    function HasChanges: Boolean;
    function ClearAllChanges: ITables;

    { Serialize PROPRIA da Tables (Fatia B-c, Onda 4-cont) - grupo de
      tabelas/registos; cada elemento do array delega a ITable (Database.Table,
      Fatia B-b).

      EIXO DADO: ToJSON emite um array JSON puro com um ITable.ToJSON por
      elemento (registo/linha, com object_state). FromJSON (retorno ITables,
      "replace") e MergeFromJSON (novo, "patch") fazem a reconciliacao por
      PK (IsPKey) descrita acima na arvore de import por object_state -
      MergeFromJSON difere de FromJSON so por delegar a ITable.MergeFromJSON
      (dirty por campo) em vez de ITable.FromJSON (hidratacao limpa) nos
      registos localizados/adicionados.

      EIXO ESTRUTURA: StructureToJSON emite um array JSON com um
      ITable.StructureToJSON por elemento; StructureFromJSON (novo)
      reconstroi o FList por completo (substitui), criando um ITable por
      elemento via ITable.StructureFromJSON. }
    function ToJSON: string;
    function FromJSON(const AJSON: string): ITables;
    function MergeFromJSON(const AJSON: string): ITables;
    function StructureToJSON: string;
    function StructureFromJSON(const AJSON: string): ITables;
    { Onda S2-a (ADITIVO, simetria To/From/Merge) - PATCH aditivo POR NOME de
      tabela (TableName): para cada elemento do array, se ja existe uma
      ITable com esse "table", aplica ITable.StructureMergeFromJSON nela; se
      nao existe, cria via ITable.StructureFromJSON e adiciona. NUNCA remove
      uma tabela existente que nao apareca no JSON de entrada. }
    function StructureMergeFromJSON(const AJSON: string): ITables;

    { Onda S3 - eixo SQL (DML) - INSERT de TODOS os registos do container
      (grupo de tabelas/registos, Fatia B-c), reutilizando ITable.ToSQL de
      cada elemento (zero SQL novo, so orquestracao). Elementos sem SQL
      (TableName vazio, sem campos, ou todos os campos saltados pelo skip de
      ITable.ToSQL) sao omitidos silenciosamente. Cada statement sai
      terminado por ';', um por linha. NOTA: ISchema/TSchema SOBREPOE este
      metodo (nao herda TAL-QUAL, ao contrario de DropTableSQL/RenameTableSQL/
      DropTable/RenameTable) - o FList operado aqui e um contentor ESTRUTURAL
      PARALELO a FGroups (o modelo de registos por-tabela do Schema, ver
      Database.Schema.ToDDL/ToSQL); herdar sem override devolveria '' para
      qualquer schema construido pelo eixo JSON. }
    function ToSQL: string;

    { Onda S4 (ADITIVO) - eixo FULL (Metadata + Data num so JSON) - COMPOE os
      2 eixos JA EXISTENTES deste proprio ITables, SEM reimplementar (mesmo
      padrao de composicao de ITable.ToFullJSON/FromFullJSON/
      MergeFullFromJSON, um nivel abaixo). }
    function ToFullJSON: string;
    function FromFullJSON(const AJSON: string): ITables;
    function MergeFullFromJSON(const AJSON: string): ITables;

    { Export/Import ergonomicos (Onda S4, ADITIVO) - ver comentario completo
      em IField.Export/Import; SEM overload de AQuery:IQueryBuilder (essa
      fica reservada a ITable/ISchema/IDatabase - ver ITable.Export, acima). }
    function Export(const AWithData: Boolean): string;
    function Import(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): ITables;
  end;

  { ===== Schemas (Database.Schema/Schemas.Interfaces) ===== }

  ISchema = interface(ITables)
    ['{F6A7B8C9-D0E1-2345-F012-678901234567}']
    function SchemaName(const AValue: string): ISchema; overload;
    function SchemaName: string; overload;
    function Database(const AValue: string): ISchema; overload;
    function Database: string; overload;

    { Serialize PROPRIA do Schema (Fatia B-d) - formato CHAVE-NOMEADA
      (master-detail): cada CHAVE do objeto e um TableName, o VALOR e o
      conjunto de registos dessa tabela (delegado a um grupo ITables
      independente por nome - reusa a reconciliacao por PK/object_state da
      Fatia B-c SEM misturar tabelas diferentes).

      EIXO DADO: ToJSON emite um objeto onde cada chave e um nome de tabela
      (TableName) e o valor e o array de registos dessa tabela (delegado ao
      ITables.ToJSON do grupo correspondente, com object_state por registo).
      FromJSON ("replace")/MergeFromJSON ("patch") localizam (ou criam, se
      ainda nao existir) o grupo pelo TableName e delegam a
      ITables.FromJSON/MergeFromJSON desse grupo (arvore de import por
      object_state herdada de ITables, inalterada).

      EIXO ESTRUTURA: StructureToJSON emite um objeto com as chaves schema
      (SchemaName) e tables (um array com 1 ITable.StructureToJSON
      "representante" por grupo - todos os registos de um grupo partilham a
      mesma estrutura). StructureFromJSON reconstroi os grupos por completo
      (substitui) - 1 grupo por elemento de tables, semeado como
      registo-molde (eixo estrutura nunca carrega "value" - bug-306, herdado
      do B-c) ate receber dados reais via FromJSON/MergeFromJSON com
      object_state=INSERTED.

      Covariancia sobre ITables - resolvida por clausula de resolucao de
      interface (mesma tecnica do B-b para ITable sobre IFields). }
    function ToJSON: string;
    function FromJSON(const AJSON: string): ISchema;
    function MergeFromJSON(const AJSON: string): ISchema;
    function StructureToJSON: string;
    function StructureFromJSON(const AJSON: string): ISchema;
    { Onda S2-a (ADITIVO, simetria To/From/Merge) - PATCH aditivo: localiza
      (ou CRIA, nunca remove) o grupo pelo TableName de cada elemento de
      "tables" e delega a ITables.StructureMergeFromJSON nesse grupo (patch
      por nome de coluna a nivel dos campos). Covariante sobre
      ITables.StructureMergeFromJSON - resolvida por clausula de resolucao
      de interface (mesma tecnica de StructureFromJSON, acima). }
    function StructureMergeFromJSON(const AJSON: string): ISchema;

    { DDL de nivel schema (Fatia B-d) - CREATE SCHEMA/DROP SCHEMA, gerado via
      IDialect (Dialects, Onda 5.2) a partir do proprio SchemaName +
      DatabaseTypes (herdado de ITables); TDialect.ForDatabaseType resolve
      o dialecto SO pelo enum TDatabaseTypes, sem exigir conexao (mesmo
      padrao dos golden de dialects - TDialect*.New sem .Connect). Gate
      pela capability scSchemas do dialecto: PostgreSQL/SQLServer geram DDL
      real; MySQL (schema~=database) gera sempre (override no dialecto);
      SQLite/Firebird/Access (scSchemas OFF) devolvem string vazia -
      CreateSchema/DropSchema tornam-se no-op (devolvem 0). Degradam
      graciosamente (string vazia / 0) se USE_DATABASE estiver OFF
      (submodulo Dialects indisponivel). }
    function CreateSchemaSQL: string;
    function DropSchemaSQL: string;
    function CreateSchema(const AConnection: IConnection): Integer;
    function DropSchema(const AConnection: IConnection): Integer;

    { Onda S3 - eixo SQL (script DDL completo do schema, para validar) -
      agrega, NESTA ORDEM (owner - FK so depois de TODAS as tabelas
      existirem): (1) ITable.ToDDL de CADA tabela do schema (a partir de
      FGroups - 1 ITable "representante" por grupo, MESMA fonte ja usada por
      StructureToJSON/SchemaStructureFromJSON - NAO o GetTablesList herdado
      de ITables/FList, contentor estrutural PARALELO so alimentado por
      LoadFromConnection - colunas+PK/NOT NULL+FK POR-CAMPO inline+uniques/
      indexes, ver ITable.ToDDL); (2) VIEWS (FViews, IDialect.View.CreateSQL);
      (3) PROCEDURES/FUNCTIONS (FRoutines, IDialect.Routine.CreateSQL);
      (4) TRIGGERS (FTriggers, IDialect.Trigger.CreateSQL); (5) RULES
      (FRules, IDialect.Rule.CreateSQL) - os 4 contentores populados por
      StructureFromJSON/StructureMergeFromJSON (Onda S2-b2, ver comentario
      completo na secao private de TSchema). Trigger/Rule podem devolver 2
      statements juntos por '#0' (PostgreSQL FUNCTION+TRIGGER) - divididos e
      emitidos como statements SEPARADOS (nunca deixa '#0' no texto). Dialect-
      aware SEM exigir conexao ligada (TDialect.ForDatabaseType(DatabaseTypes),
      herdado de ITables - mesmo padrao de CreateSchemaSQL, acima); ''
      (schema/dialecto ainda nao definidos) so afecta a parte
      Views/Routines/Triggers/Rules - as tabelas (que nao dependem de
      SchemaName) continuam a sair. Zero SQL novo - so agregacao. }
    function ToDDL: string;

    { Onda S3b (ADITIVO) - MATERIALIZACAO do merge (o "apply" do
      versionamento) - aplica a ESTRUTURA guardada em memoria (FGroups +
      FViews/FRoutines/FTriggers/FRules, Onda S2-b2) a uma conexao REAL,
      criando TODOS os objectos em falta, IDEMPOTENTE - ZERO SQL novo,
      delega 100% aos motores ja existentes, NESTA ORDEM (owner - FK so
      depois de todas as tabelas existirem):
      (1) tabelas+colunas+PK+uniques+indexes - constroi UM ISchemaDefinition
      (Database.Synchronize) com o "representante" de CADA grupo (mesma
      fonte de FGroups usada por ToDDL/StructureToJSON, acima; bridge
      SchemaAddTableToDefinition, helper privado desta unit - GetFieldsList
      para colunas + ITable.Uniques/Indexes, Onda S3b, para constraints) e
      delega a TSynchronize.Sync (Onda 5.5/5.5-B - Compare so aplica o que
      FALTA, idempotente por definicao);
      (2) FK - por-campo (IField.ReferencedTable/ReferencedColumn), via
      ITable.AddForeignKey(conn,...) (Onda D - ja IDEMPOTENTE, consulta
      ICatalogReader.ForeignKeyExists antes), SO depois do passo (1) (todas
      as tabelas ja existem);
      (3) VIEWS - FViews, via o lancador IViews.CreateView (Onda R2,
      Connection-bound, ja idempotente - ViewExists por dentro);
      (4) PROCEDURES/FUNCTIONS - FRoutines particionado por Kind (mesmo
      criterio de StructureToJSON, acima), via IProcedures.Create/
      IFunctions.Create (Onda F1 - lancadores zero-SQL, o dialecto compoe o
      CREATE, degradam para 0 onde o motor nao suporta);
      (5) TRIGGERS - FTriggers, via ITriggers.CreateTrigger (Onda F3, ja
      idempotente - TriggerExists por dentro);
      (6) RULES - FRules, via IRules.CreateRule (Onda F4, ja idempotente -
      RuleExists por dentro; no-op nos motores sem RULE - so PostgreSQL/
      SQLServer suportam).
      Fluente (devolve Self); nunca lanca - no-op gracioso sem Connection
      ligada, com USE_DATABASE OFF (TSynchronize/os lancadores so existem
      sob esse define), ou onde um motor especifico nao suporta um dado
      objecto (mesmo padrao de robustez de CreateSchema/ToDDL, acima). Gate
      desta onda: so COMPILACAO (validacao contra banco real fica para a
      proxima onda). }
    function ApplyStructure(const AConnection: IConnection): ISchema;

    { Onda S4 (ADITIVO) - eixo FULL (Metadata + Data num so JSON) - COMPOE os
      2 eixos JA EXISTENTES deste proprio ISchema, SEM reimplementar (mesmo
      padrao de composicao de ITable.ToFullJSON/FromFullJSON/
      MergeFullFromJSON, acima). Covariante sobre ITables.FromFullJSON/
      MergeFullFromJSON (retorno ISchema) - resolvida por clausula de
      resolucao de interface (mesma tecnica de FromJSON/MergeFromJSON,
      acima). }
    function ToFullJSON: string;
    function FromFullJSON(const AJSON: string): ISchema;
    function MergeFullFromJSON(const AJSON: string): ISchema;

    { Export/Import ergonomicos (Onda S4, ADITIVO) - ver comentario completo
      em ITable.Export/Import (mesma semantica, incl. o overload
      Export(AWithData, AQuery), gated USE_DATABASE - a parte "data" vem das
      LINHAS de AQuery.Execute via TDataSetSerializeHelper.ToJSONArrayString
      quando ha Connection viva, senao cai em ToFullJSON). Import: retorno
      ISchema (covariante), resolvido por clausula de resolucao de
      interface. }
    function Export(const AWithData: Boolean): string; overload;
{$IFDEF USE_DATABASE}
    function Export(const AWithData: Boolean; const AQuery: IQueryBuilder): string; overload;
{$ENDIF}
    function Import(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): ISchema;

  end;

  TSchemaArray = array of ISchema;

  ISchemas = interface
    ['{A7B8C9D0-E1F2-3456-0123-789012345678}']
    function Connection(const AConnection: IConnection): ISchemas; overload;
    function Connection: IConnection; overload;
    function Add(const ASchema: ISchema): ISchemas;
    function Schema(const AName: string): ISchema;
    function GetSchemasList: TSchemaArray;
    function SchemasCount: Integer;
    function SchemaExists(const AName: string): Boolean;
    function LoadSchemasFromConnection: ISchemas;
    { R2.6 (f5-repair) - lista os nomes de schema via ICatalogReader.SchemaNames
      (Connection-bound, ja existente); vazio se USE_DATABASE estiver OFF,
      sem Connection injectada, ou conexao nao ligada (mesmo padrao de
      degradacao dos restantes lancadores desta unit). }
    function SchemaNames: TStringArray;

    { Serialize PROPRIA da Schemas (Fatia B-d) - formato CHAVE-NOMEADA por
      SchemaName (ver comentario completo no header do ficheiro).

      EIXO DADO: ToJSON emite um objeto onde cada chave e um SchemaName e o
      valor e o ISchema.ToJSON desse schema. FromJSON ("replace")/
      MergeFromJSON ("patch") localizam (por SchemaName, via Schema) ou
      criam (TSchema.New.SchemaName) o schema e delegam a
      ISchema.FromJSON/MergeFromJSON.

      EIXO ESTRUTURA: StructureToJSON emite um objeto com a chave schemas
      (array de ISchema.StructureToJSON). StructureFromJSON reconstroi a
      lista de schemas por completo (substitui) - 1 ISchema por elemento,
      via ISchema.StructureFromJSON. }
    function ToJSON: string;
    function FromJSON(const AJSON: string): ISchemas;
    function MergeFromJSON(const AJSON: string): ISchemas;
    function StructureToJSON: string;
    function StructureFromJSON(const AJSON: string): ISchemas;
    { Onda S2-a (ADITIVO, simetria To/From/Merge) - PATCH aditivo: localiza
      (ou CRIA, nunca remove) o schema pelo SchemaName de cada elemento de
      "schemas" e delega a ISchema.StructureMergeFromJSON nesse schema. }
    function StructureMergeFromJSON(const AJSON: string): ISchemas;

    { Onda S3 - eixo SQL - agrega o ISchema.ToDDL de todos os schemas do
      container (GetSchemasList), na ordem em que foram adicionados; zero SQL
      novo, so orquestracao (mesmo padrao trivial de propagacao ja usado
      pelo eixo JSON, acima). }
    function ToDDL: string;

    { Onda S3b (ADITIVO) - agrega o ISchema.ApplyStructure de todos os
      schemas do container (GetSchemasList); zero SQL novo, so orquestracao
      (mesmo padrao trivial de ToDDL, acima). }
    function ApplyStructure(const AConnection: IConnection): ISchemas;

    { Onda S4 (ADITIVO) - eixo FULL (Metadata + Data num so JSON) - COMPOE os
      2 eixos JA EXISTENTES deste proprio ISchemas, SEM reimplementar (mesmo
      padrao de composicao de ISchema.ToFullJSON/FromFullJSON/
      MergeFullFromJSON, acima). }
    function ToFullJSON: string;
    function FromFullJSON(const AJSON: string): ISchemas;
    function MergeFullFromJSON(const AJSON: string): ISchemas;

    { Export/Import ergonomicos (Onda S4, ADITIVO) - ver comentario completo
      em IField.Export/Import; SEM overload de AQuery:IQueryBuilder (essa
      fica reservada a ITable/ISchema/IDatabase - ver ITable.Export). }
    function Export(const AWithData: Boolean): string;
    function Import(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): ISchemas;
  end;

  { ===== Onda R2 (f5-repair, re-layering por responsabilidade) - colecoes de
    objectos de BANCO (Views/Procedures/Functions) =====
    Views/Procedures/Functions NAO pertencem a uma tabela - sao objectos de
    nivel IDatabase (ao contrario de campos/indices/constraints, que vivem na
    ITable dona). As 3 interfaces abaixo sao Connection-bound (Connection
    getter/setter fluente, SEM parametro de conexao nos metodos Create/Drop -
    a colecao ja "sabe" a conexao onde vai operar), paralelas as operacoes
    HOMONIMAS ja existentes em ISchema (CreateView/DropView/CreateProcedure/
    DropProcedure, acima) - ADITIVO PURO, nada foi removido de ISchema (essa
    remocao fica para a Fase C do f5-repair). Implementacoes (TViews/
    TProcedures/TFunctions, Modulos/Database/Database.Views|Procedures|
    Functions.pas) delegam a TDialect.ForConnection(FConnection).View/Routine
    (SQL) e a TCatalogReader.New(FConnection) (introspeccao), degradando
    graciosamente (''/0/False/[]) quando USE_DATABASE esta OFF, sem Connection
    injectada, ou conexao desligada - mesmo padrao de robustez de
    Database.Schema.pas (TSchema.CreateView/DropView/CreateProcedure/
    DropProcedure). }

  IViews = interface
    ['{B1C2D3E4-F5A6-4789-9ABC-DEF012345601}']
    function Connection(const AConnection: IConnection): IViews; overload;
    function Connection: IConnection; overload;
    function ViewNames: TStringArray;
    function ViewExists(const AViewName: string): Boolean;
    function CreateViewSQL(const AViewName, ASelectSQL: string; const AOrReplace: Boolean = True): string;
    function DropViewSQL(const AViewName: string; const AIfExists: Boolean = True): string;
    function CreateView(const AViewName, ASelectSQL: string; const AOrReplace: Boolean = True): Integer; {$IFDEF USE_DATABASE}overload;{$ENDIF}
    {$IFDEF USE_DATABASE}
    { overload zero-SQL: o SELECT da view vem de um IQueryBuilder (AQB.ToSQL) - o
      chamador NAO escreve SQL. Usar um QueryBuilder SEM parametros bindados (uma
      view nao resolve :paramN). }
    function CreateView(const AViewName: string; const ASelect: IQueryBuilder; const AOrReplace: Boolean = True): Integer; overload;
    {$ENDIF}
    function DropView(const AViewName: string): Integer;
  end;

  IProcedures = interface
    ['{B1C2D3E4-F5A6-4789-9ABC-DEF012345602}']
    function Connection(const AConnection: IConnection): IProcedures; overload;
    function Connection: IConnection; overload;
    function ProcedureNames: TStringArray;
    function ProcedureExists(const AName: string): Boolean;
    function CreateProcedureSQL(const AName, ABody: string): string;
    function DropProcedureSQL(const AName: string; const AIfExists: Boolean = True): string;
    function CreateProcedure(const AName, ABody: string): Integer;
    function DropProcedure(const AName: string): Integer;
    { Onda F1 - lancador zero-SQL: cria a procedure a partir do builder de
      rotinas (o dialecto compoe o CREATE). Devolve linhas afectadas (0 quando
      o motor nao suporta procedures - SQLite/Access). }
    function Create(const ADef: IRoutineDefinition): Integer;
  end;

  { Faceta ROUTINE com AIsFunction=True (ver Database.Dialect.Interfaces.
    IRoutineDialect). FunctionNames/FunctionExists ficam STUB por agora - o
    catalogo ICatalogReader (Database.CatalogReader) ainda so expoe introspeccao de
    PROCEDURES (ProcedureNames); introspeccao de FUNCTIONS fica como
    FOLLOW-UP (ver TODO no corpo de TFunctions.FunctionNames/FunctionExists,
    Database.Functions.pas). CreateFunction/DropFunction/CreateFunctionSQL/
    DropFunctionSQL ja funcionam (nao dependem de introspeccao de funcoes -
    so de DatabaseTypes/Connection, mesmo padrao de IProcedures). }
  IFunctions = interface
    ['{B1C2D3E4-F5A6-4789-9ABC-DEF012345603}']
    function Connection(const AConnection: IConnection): IFunctions; overload;
    function Connection: IConnection; overload;
    function FunctionNames: TStringArray;
    function FunctionExists(const AName: string): Boolean;
    function CreateFunctionSQL(const AName, ABody: string): string;
    function DropFunctionSQL(const AName: string; const AIfExists: Boolean = True): string;
    function CreateFunction(const AName, ABody: string): Integer;
    function DropFunction(const AName: string): Integer;
    { Onda F1 - lancador zero-SQL: cria a function a partir do builder de
      rotinas (o dialecto compoe o CREATE). Devolve linhas afectadas (0 quando
      o motor nao suporta functions - SQLite/Access). }
    function Create(const ADef: IRoutineDefinition): Integer;
  end;

  { Onda F3 - colecao de TRIGGERS do banco, Connection-bound (mesmo padrao de
    IViews/IProcedures/IFunctions). CreateTrigger consome o builder
    ITriggerDefinition (o dialecto compoe o CREATE, zero-SQL); TriggerNames/
    TriggerExists via ICatalogReader (IDialect.TriggersSQL). Degradam
    graciosamente (''/0/False/[]) quando o motor nao tem triggers (Access),
    sem Connection injectada, ou conexao desligada. }
  ITriggers = interface
    ['{B1C2D3E4-F5A6-4789-9ABC-DEF012345604}']
    function Connection(const AConnection: IConnection): ITriggers; overload;
    function Connection: IConnection; overload;
    function TriggerNames: TStringArray;
    function TriggerExists(const AName: string): Boolean;
    function CreateTriggerSQL(const ADef: ITriggerDefinition): string;
    function DropTriggerSQL(const AName, ATable: string; const AIfExists: Boolean = True): string;
    function CreateTrigger(const ADef: ITriggerDefinition): Integer;
    function DropTrigger(const AName, ATable: string): Integer;
  end;

  { Onda F4 - colecao de RULES do banco, Connection-bound (mesmo padrao de
    ITriggers). So PostgreSQL/SQL Server tem o objecto RULE; nos outros 5
    motores CreateRule/DropRule sao no-op (0) e TriggerNames vem [] (o dialecto
    devolve SQL ''). }
  IRules = interface
    ['{B1C2D3E4-F5A6-4789-9ABC-DEF012345605}']
    function Connection(const AConnection: IConnection): IRules; overload;
    function Connection: IConnection; overload;
    function RuleNames: TStringArray;
    function RuleExists(const AName: string): Boolean;
    function CreateRuleSQL(const ADef: IRuleDefinition): string;
    function DropRuleSQL(const AName, ATable: string; const AIfExists: Boolean = True): string;
    function CreateRule(const ADef: IRuleDefinition): Integer;
    function DropRule(const AName, ATable: string): Integer;
  end;

  { ===== IdentityMap (Database.IdentityMap.Interfaces) - generico, autonomo =====
    NOTA (bug-1074, FPC 3.2.2 Internal error 2012101001, fix 01/08/2026):
    declaracao completa movida para AQUI (antes de IDatabase - era mais
    abaixo, perto da seccao Databases) porque o FPC 3.2.2 ICEa ao
    especializar um generico forward-declarado (IIdentityMap<TObject>,
    usado em IDatabase.IdentityMap logo a seguir) ANTES da sua declaracao
    completa - bug do COMPILADOR 3.2.2 (corrigido no 3.3.1; Delphi sempre
    aceitou ambos os moldes). NAO reabrir a keyword `type` entre aqui e a
    completude de IUnitOfWork/IEntityManager/ISynchronize/IQueryBuilder
    mais abaixo (mesmo bloco `type` continuo, aberto na linha ~179) -
    dcc32/fpc32 tratam reabertura de `type` como fronteira que abandona
    forwards pendentes (E2086 "not yet completely defined" no PROPRIO
    forward decl). Repro + solucao provados isoladamente em
    .workspace/fpc-ice-repro/ (30 compilacoes, incl. molde realista de 5
    forwards interleaved) antes desta aplicacao.
    NOTA 2 (bug-1083, 3.4.1): esta e a UNICA declaracao de IIdentityMap<T>
    - o forward que existia na seccao da Onda 7 foi removido (Padrao A):
    um forward de interface generica numa unit dispara Internal error
    200602034 no FPC 3.2.2 ao fechar a seccao interface, mesmo sem uso.
    NAO reintroduzir o forward. }

  IIdentityMap<T: class> = interface
    ['{C9D0E1F2-3456-7890-1234-567890ABCDEF}']

    procedure Add(const AId: Variant; const AEntity: T);
    function Get(const AId: Variant): T;
    function TryGet(const AId: Variant; out AEntity: T): Boolean;
    function Contains(const AId: Variant): Boolean;
    procedure Remove(const AId: Variant);
    procedure RemoveEntity(const AEntity: T);
    procedure Update(const AId: Variant; const AEntity: T);
    procedure Clear;
    function Count: Integer;
    function GetAll: TArray<T>;
  end;

  { ===== Databases (Databases.Interfaces / Databases.Interfaces) ===== }

  IDatabase = interface
    ['{C8D9E0F1-A2B3-4C5D-8E9F-0A1B2C3D4E5F}']

    { DI (fluente): a conexao pertence ao CALLER (directa OU pooled). Ao
      injectar a conexao, DatabaseTypes e resolvido automaticamente a partir
      dela (AConnection.DatabaseType) e DatabaseName recebe o valor de
      AConnection.Database COMO DEFAULT (so se ainda nao tiver sido definido
      explicitamente) - ambos podem ser sobrepostos depois via os setters
      fluentes proprios. }
    function Connection(const AConnection: IConnection): IDatabase; overload;
    function Connection: IConnection; overload;

    { Identidade do banco. }
    function DatabaseName(const AValue: string): IDatabase; overload;
    function DatabaseName: string; overload;

    { DatabaseTypes independente da conexao (golden/DDL SEM servidor - mesmo
      padrao de ITables.DatabaseTypes/ISchema.DatabaseTypes, Fatia B-d);
      permite override manual mesmo depois de Connection ja o ter resolvido. }
    function DatabaseTypes(const AValue: TDatabaseTypes): IDatabase; overload;
    function DatabaseTypes: TDatabaseTypes; overload;

    { Schemas do banco (ISchemas, Fatia B-d) - COMPOSICAO, nao heranca. }
    function Schemas: ISchemas;
    { Descobre os schemas via ICatalogReader.SchemaNames (Onda 5.1, intacto) e
      substitui o conteudo de Schemas por completo (requer Connection ligada;
      no-op silencioso se nao ligada ou se USE_DATABASE estiver OFF). }
    function LoadSchemasFromConnection: IDatabase;

    { Serialize do banco completo - delega integralmente a ISchemas (ja
      chave-nomeada por SchemaName, Fatia B-d).

      EIXO DADO: ToJSON/FromJSON ("replace")/MergeFromJSON ("patch") sao
      passagem DIRECTA para Schemas.ToJSON/FromJSON/MergeFromJSON - sem
      wrapper adicional (mesmo padrao "eixo dado puro, sem identificador"
      ja usado por ISchema.ToJSON/ISchemas.ToJSON, Fatia B-d).

      EIXO ESTRUTURA: StructureToJSON emite um objeto com as chaves database
      (DatabaseName) e schemas (array com 1 ISchema.StructureToJSON por
      schema) - mesmo padrao do wrapper "schema"+"tables" do ISchema (Fatia
      B-d) um nivel acima. StructureFromJSON reconstroi Schemas por completo
      (substitui) a partir da chave "schemas" e actualiza DatabaseName a
      partir da chave "database". }
    function ToJSON: string;
    function FromJSON(const AJSON: string): IDatabase;
    function MergeFromJSON(const AJSON: string): IDatabase;
    function StructureToJSON: string;
    function StructureFromJSON(const AJSON: string): IDatabase;
    { Onda S2-a (ADITIVO, simetria To/From/Merge) - le a chave "database"
      (patch - mantem FDatabaseName se ausente) e delega integralmente a
      ISchemas.StructureMergeFromJSON (localiza/cria schemas por SchemaName,
      nunca remove), no MESMO padrao de composicao ja usado por
      StructureFromJSON/MergeFromJSON, acima. }
    function StructureMergeFromJSON(const AJSON: string): IDatabase;

    { DDL de nivel database (Fatia B-e) - CREATE/DROP DATABASE, gerado via
      IDialect (Onda 5.2) a partir do proprio DatabaseName + DatabaseTypes;
      TDialect.ForDatabaseType resolve o dialecto SO pelo enum, sem exigir
      conexao (mesmo padrao de ISchema.CreateSchemaSQL). CreateDatabaseSQL/
      DropDatabaseSQL SEM gate de capability - PostgreSQL/MySQL/SQLServer
      geram DDL real; SQLite/Access (bases-ficheiro) devolvem string vazia ->
      CreateDatabase/DropDatabase tornam-se no-op (devolvem 0); Firebird usa
      sintaxe ISQL propria (ver Database.Dialect.Firebird). Degradam
      graciosamente (string vazia/0) se USE_DATABASE estiver OFF (submodulo
      Dialects indisponivel). CreateDatabase/DropDatabase executam via
      AConnection.ExecuteCommand quando a SQL gerada nao e vazia e a conexao
      esta ligada (mesmo padrao ISchema.CreateSchema/DropSchema). }
    function CreateDatabaseSQL: string;
    function DropDatabaseSQL: string;
    function CreateDatabase(const AConnection: IConnection): Integer;
    function DropDatabase(const AConnection: IConnection): Integer;

    { ===== Onda D - manipulacao IMPERATIVA de SCHEMA (por nome) neste banco =====
      <Op>SchemaSQL monta via a faceta IDialect.Schema (gated scSchemas no
      dialecto - SQLite/Firebird/Access devolvem '' -> no-op); <Op>Schema(conn)
      executa e e IDEMPOTENTE (consulta ICatalogReader.SchemaNames). Difere de
      ISchema.CreateSchema/DropSchema (que operam sobre o proprio SchemaName)
      por receber o NOME do schema alvo. }
    function CreateSchemaSQL(const ASchemaName: string): string;
    function DropSchemaSQL(const ASchemaName: string): string;
    function RenameSchemaSQL(const AOldName, ANewName: string): string;
    function CreateSchema(const AConnection: IConnection; const ASchemaName: string): Integer;
    function DropSchema(const AConnection: IConnection; const ASchemaName: string): Integer;
    function RenameSchema(const AConnection: IConnection; const AOldName, ANewName: string): Integer;

    { Onda S3 - eixo SQL - agrega o ISchema.ToDDL de TODOS os schemas deste
      banco (Schemas.GetSchemasList - composicao, nao heranca); zero SQL
      novo, so orquestracao (mesmo padrao de ToJSON/StructureToJSON, acima,
      que ja delegam integralmente a ISchemas/ISchema). }
    function ToDDL: string;

    { Onda S3b (ADITIVO) - MATERIALIZACAO do merge - agrega o ISchema.
      ApplyStructure de TODOS os schemas deste banco (Schemas.GetSchemasList
      - composicao, nao heranca); ver comentario completo em ISchema.
      ApplyStructure, acima. Zero SQL novo, so orquestracao. }
    function ApplyStructure(const AConnection: IConnection): IDatabase;

    { Onda S4 (ADITIVO) - eixo FULL (Metadata + Data num so JSON) - COMPOE os
      2 eixos JA EXISTENTES deste proprio IDatabase, SEM reimplementar (mesmo
      padrao de composicao de ISchema.ToFullJSON/FromFullJSON/
      MergeFullFromJSON, acima). }
    function ToFullJSON: string;
    function FromFullJSON(const AJSON: string): IDatabase;
    function MergeFullFromJSON(const AJSON: string): IDatabase;

    { Export/Import ergonomicos (Onda S4, ADITIVO) - ver comentario completo
      em ITable.Export/Import (mesma semantica, incl. o overload
      Export(AWithData, AQuery), gated USE_DATABASE - a parte "data" vem das
      LINHAS de AQuery.Execute via TDataSetSerializeHelper.ToJSONArrayString
      quando ha Connection viva, senao cai em ToFullJSON). }
    function Export(const AWithData: Boolean): string; overload;
{$IFDEF USE_DATABASE}
    function Export(const AWithData: Boolean; const AQuery: IQueryBuilder): string; overload;
{$ENDIF}
    function Import(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): IDatabase;

    { ===== Onda 7 - camada de lancadores fluentes (ver comentario completo
      em ITable, acima) - Connection-bound a este IDatabase (FConnection). }
{$IFDEF USE_DATABASE}
    function Synchronize: ISynchronize;
    function QueryBuilder: IQueryBuilder;
    function UnitOfWork: IUnitOfWork;
    { Resolve o dialecto pela Connection ligada (ForConnection); sem conexao
      ligada, cai no fallback por DatabaseTypes puro (ForDatabaseType, mesmo
      padrao ja usado por CreateDatabaseSQL/DropDatabaseSQL). }
    function Dialect: IDialect;
    { Onda R2 (f5-repair, re-layering por responsabilidade) - colecoes de
      objectos de BANCO (Views/Procedures/Functions), Connection-bound a
      FConnection (mesmo padrao dos lancadores acima); ver comentario
      completo em IViews/IProcedures/IFunctions (declaradas mais acima neste
      ficheiro, entre ISchemas e IDatabases). ADITIVO - ISchema.CreateView/
      DropView/CreateProcedure/DropProcedure continuam intactos (a remocao
      fica para a Fase C do f5-repair). }
    function Views: IViews;
    function Procedures: IProcedures;
    function Functions: IFunctions;
    { Onda F3 - colecao de TRIGGERS do banco (ITriggers, Connection-bound). }
    function Triggers: ITriggers;
    { Onda F4 - colecao de RULES do banco (IRules, Connection-bound; PG/SQLServer). }
    function Rules: IRules;
{$IFDEF USE_ENTITY_MANAGER}
    { EntityManager "em branco" - so Connection-bound (SEM MapTable/Table
      configurados); o caller chama .MapTable(...) ou .Table(...) a seguir. }
    function EntityManager: IEntityManager;
{$ENDIF}
{$ENDIF}
    { IdentityMap<TObject> generico (ungated - IIdentityMap<T> e
      Database.IdentityMap.pas nao dependem de USE_DATABASE); nova instancia
      a cada chamada (sem estado partilhado por omissao). }
    function IdentityMap: IIdentityMap<TObject>;
    { Tipo de banco (ITypeDatabase - quoting/schema por DatabaseTypes);
      ungated (Database.TypeDatabase.pas nao depende de USE_DATABASE). }
    function TypeDatabase: ITypeDatabase;
  end;

  TDatabaseArray = array of IDatabase;

  IDatabases = interface
    ['{D9E0F1A2-B3C4-4D5E-9F0A-1B2C3D4E5F60}']
    function Connection(const AConnection: IConnection): IDatabases; overload;
    function Connection: IConnection; overload;
    function Add(const ADatabase: IDatabase): IDatabases;
    function Database(const AName: string): IDatabase;
    function GetDatabasesList: TDatabaseArray;
    function DatabasesCount: Integer;
    function DatabaseExists(const AName: string): Boolean;
    { Descobre os bancos via ICatalogReader.DatabaseNames (Onda 5.1, intacto) e,
      para cada banco, ja carrega os respectivos schemas
      (IDatabase.LoadSchemasFromConnection) - substitui o conteudo por
      completo. No-op silencioso se USE_DATABASE estiver OFF, se nao houver
      Connection injectada, ou se a conexao nao estiver ligada. }
    function LoadDatabasesFromConnection: IDatabases;
    { R2.6 (f5-repair) - lista os nomes de banco via ICatalogReader.DatabaseNames
      (Connection-bound, ja existente); vazio se USE_DATABASE estiver OFF,
      sem Connection injectada, ou conexao nao ligada (mesmo padrao de
      degradacao de LoadDatabasesFromConnection, acima). }
    function DatabaseNames: TStringArray;

    { Serialize PROPRIA da Databases (Fatia B-e) - formato CHAVE-NOMEADA
      por DatabaseName (mesma tecnica de ISchemas sobre ISchema, um nivel
      abaixo).

      EIXO DADO: ToJSON emite um objeto onde cada chave e um DatabaseName e
      o valor e o IDatabase.ToJSON desse banco (que, por sua vez, ja e
      chave-nomeada por SchemaName). FromJSON ("replace")/MergeFromJSON
      ("patch") localizam (por DatabaseName, via Database) ou criam
      (TDatabase.New.DatabaseName) o banco e delegam a
      IDatabase.FromJSON/MergeFromJSON.

      EIXO ESTRUTURA: StructureToJSON emite um objeto com a chave databases
      (array de IDatabase.StructureToJSON). StructureFromJSON reconstroi a
      lista de bancos por completo (substitui) - 1 IDatabase por elemento,
      via IDatabase.StructureFromJSON. }
    function ToJSON: string;
    function FromJSON(const AJSON: string): IDatabases;
    function MergeFromJSON(const AJSON: string): IDatabases;
    function StructureToJSON: string;
    function StructureFromJSON(const AJSON: string): IDatabases;
    { Onda S2-a (ADITIVO, simetria To/From/Merge) - PATCH aditivo: localiza
      (ou CRIA, nunca remove) o banco pelo DatabaseName de cada elemento de
      "databases" e delega a IDatabase.StructureMergeFromJSON nesse banco. }
    function StructureMergeFromJSON(const AJSON: string): IDatabases;

    { Onda S3 - eixo SQL - agrega o IDatabase.ToDDL de todos os bancos do
      container (GetDatabasesList); zero SQL novo, so orquestracao. }
    function ToDDL: string;

    { Onda S3b (ADITIVO) - agrega o IDatabase.ApplyStructure de todos os
      bancos do container (GetDatabasesList); zero SQL novo, so
      orquestracao. }
    function ApplyStructure(const AConnection: IConnection): IDatabases;

    { Onda S4 (ADITIVO) - eixo FULL (Metadata + Data num so JSON) - COMPOE os
      2 eixos JA EXISTENTES deste proprio IDatabases, SEM reimplementar
      (mesmo padrao de composicao de IDatabase.ToFullJSON/FromFullJSON/
      MergeFullFromJSON, acima). }
    function ToFullJSON: string;
    function FromFullJSON(const AJSON: string): IDatabases;
    function MergeFullFromJSON(const AJSON: string): IDatabases;

    { Export/Import ergonomicos (Onda S4, ADITIVO) - ver comentario completo
      em IField.Export/Import; SEM overload de AQuery:IQueryBuilder (essa
      fica reservada a ITable/ISchema/IDatabase - ver ITable.Export). }
    function Export(const AWithData: Boolean): string;
    function Import(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): IDatabases;
  end;

  { ===== UnitOfWork (Database.UnitOfWork.Interfaces) ===== }

  IUnitOfWork = interface
    ['{D5E6F7A8-4567-8901-2345-678901BCDEF0}']

    function Connection(const AConnection: IConnection): IUnitOfWork; overload;
    function Connection: IConnection; overload;

    function RegisterNew(const ATable: ITable): IUnitOfWork;
    function RegisterDirty(const ATable: ITable): IUnitOfWork;
    function RegisterDeleted(const ATable: ITable): IUnitOfWork;

    function PendingCount: Integer;   // total de operacoes pendentes (New+Dirty+Deleted)
    function HasPending: Boolean;     // PendingCount > 0

    procedure Commit;
    procedure Rollback;
  end;

  { ===== EntityManager (Database.EntityManager.Interfaces) ===== }

  IEntityManager = interface
    ['{F7A8B9C0-6789-0123-4567-890123DEF012}']

    function Connection(const AConnection: IConnection): IEntityManager; overload;
    function Connection: IConnection; overload;

    function Table(const ATable: ITable): IEntityManager; overload;
    function Table: ITable; overload;

    { Auto-mapeamento: descobre a estrutura da tabela via ICatalogReader e
      constroi a ITable (FTable) automaticamente - o consumidor deixa de
      construir a shape a mao (modelo v1.6.1 InitTable). }
    function MapTable(const ATableName: string; const ASchema: string = ''): IEntityManager;

    { Sub-passo 4.4: quando False (default), Find/List/ListWhere excluem os
      registos com soft delete marcado (FieldIsDeleted=1) - so se a ITable
      mapeada tiver FieldIsDeleted configurado; sem essa configuracao, este
      flag nao tem efeito (comportamento inalterado). True inclui todos. }
    function IncludeDeleted(const AValue: Boolean): IEntityManager; overload;
    function IncludeDeleted: Boolean; overload;

    function Find(const AId: Variant): ITable;
    function List: TArray<ITable>;
    function ListWhere(const AColumn, AOp: string; const AValue: Variant): TArray<ITable>;

    function Save(const ATable: ITable): Integer;
    function Delete(const ATable: ITable): Integer; overload;
    function Delete(const AId: Variant): Integer; overload;
    function Update(const ATable: ITable): Integer;
  end;


{$IFDEF USE_DATABASE}
  { ===== Records/enums de Commons.Database.Types de uso frequente pelo
    consumidor (re-export do antigo barrel Databases.Interfaces, Onda 5 -
    paridade preservada na Reorg 1). B9 (conformidade F5, onda C5) - TENTOU-SE
    remover por "dead code" (grep so pela forma QUALIFICADA
    Databases.Interfaces.TRowStatus, sem consumidores) - REPRODUZIU falha real
    em smoke_database_facade.dpr, que testa DELIBERADAMENTE que `uses
    Databases.Interfaces` SOZINHO (sem Commons.Database.Types direto) expoe
    estes 3 tipos pelo NOME BARE (nao qualificado) - exatamente o contrato do
    barrel. Revertido; prova empirica de que "ausencia de consumidores nao se
    prova por grep local" (regra da skill governance-refactoring-compatibility-
    policy) tambem se aplica a re-exports/aliases de tipo, nao so a
    metodos/classes. }
  TRowStatus             = Commons.Database.Types.TRowStatus;
  TSQLColumnKind         = Commons.Database.Types.TSQLColumnKind;
  TFieldValidationError  = Commons.Database.Types.TFieldValidationError;
  TFieldValidationErrors = Commons.Database.Types.TFieldValidationErrors;

  { ===== SchemaSync (Database.SchemaSync.Interfaces) - USE_DATABASE ===== }

  ISchemaColumn = interface
    ['{F1B2C3D4-8293-44A5-BEB6-70819203A4B5}']
    function ColumnName: string;
    function Kind: TSQLColumnKind;
    function Size: Integer;
    { fix #2 (auditoria ApplyStructure) - escala de colunas DECIMAL/NUMERIC
      (ex.: NUMERIC(18,4) -> Scale=4); 0 para tipos sem escala (comportamento
      pre-existente inalterado - ver TDialect.ColumnTypeFor). ADITIVO. }
    function Scale: Integer;
    function IsNullable: Boolean;
    function IsPrimaryKey: Boolean;
  end;

  ISchemaTable = interface
    ['{02C3D4E5-9304-45B6-CFC7-819203A4B5C6}']
    function TableName: string;
    { adiciona uma coluna ao estado desejado (fluent). AScale (ADITIVO,
      default 0) - so' relevante para AKind=ckDecimal (ou similares com
      escala); ver ISchemaColumn.Scale. }
    function AddColumn(const AName: string; const AKind: TSQLColumnKind;
      const ASize: Integer = 0; const ANullable: Boolean = True;
      const APrimaryKey: Boolean = False; const AScale: Integer = 0): ISchemaTable;
    function Columns: TArray<ISchemaColumn>;
    { Onda 5.5-B - constraint UNIQUE composta / indice DESEJADOS (fluent). AName
      vazio -> nome derivado deterministicamente pelo SchemaSync (BuildXxx). }
    function AddUnique(const AColumns: array of string; const AName: string = ''): ISchemaTable;
    function AddIndex(const AColumns: array of string; const AName: string = '';
      const AUnique: Boolean = False): ISchemaTable;
    function Uniques: TSchemaUniques;
    function Indexes: TSchemaIndexes;
  end;

  ISchemaDefinition = interface
    ['{13D4E5F6-A415-46C7-D0D8-9203A4B5C6D7}']
    { cria (ou devolve) a definicao de uma tabela para lhe adicionar colunas }
    function Table(const AName: string): ISchemaTable;
    function Tables: TArray<ISchemaTable>;
  end;

  ISchemaInspector = interface
    ['{24E5F607-B526-47D8-E1E9-03A4B5C6D7E8}']
    function Connection(const AConn: IConnection): ISchemaInspector; overload;
    function Connection: IConnection; overload;
    function TableExists(const ATable: string): Boolean;
    function ColumnExists(const ATable, AColumn: string): Boolean;
    function Refresh: ISchemaInspector;
  end;

  ISchemaComparer = interface
    ['{35F60718-C637-48E9-F2FA-14B5C6D7E8F9}']
    { report-only: diferencas entre o desejado (ADef) e o real (AConn) }
    function Compare(const ADef: ISchemaDefinition;
      const AConn: IConnection): TArray<TSchemaChange>;
  end;

  ISynchronize = interface
    ['{46071829-D748-49FA-030B-25C6D7E8F90A}']
    function Connection(const AConn: IConnection): ISynchronize;
    { R2-B (verificacao pos-DDL) - liga/desliga a rede de seguranca do Sync
      (DEFAULT ON): apos aplicar as mudancas, re-corre o Compare sobre o mesmo
      ISchemaDefinition; como o Compare so reporta o que FALTA do desejado, um
      Sync bem-sucedido deixa-o VAZIO - se sobrar diferenca (o DDL "executou"
      mas o catalogo nao reflecte o alvo, ex.: coluna nao criada por coercao
      silenciosa do driver) lanca EDatabaseSchemaVerificationException (410031).
      Fluent - devolve Self para encadear com Connection/Sync. }
    function VerifyAfterSync(const AValue: Boolean): ISynchronize;
    { report-only (nao aplica) - o mesmo que ISchemaComparer.Compare }
    function Plan(const ADef: ISchemaDefinition): TArray<TSchemaChange>;
    { aplica as mudancas em transaccao, regista em schema_version; devolve o nr
      de mudancas aplicadas. IDEMPOTENTE: 2a chamada sobre esquema igual = 0.
      Com VerifyAfterSync ON (default) verifica o resultado no fim (R2-B). }
    function Sync(const ADef: ISchemaDefinition): Integer;
  end;

  { ===== Async (Database.QueryBuilder.Sychronize) - USE_DATABASE, Onda 6-f Estagio 2 (I11/A2) =====
    Execucao assincrona de operacoes do modulo Database (consumida por
    IQueryBuilder.ExecuteAsync, abaixo). Implementacao concreta (TORMTask<T>)
    em unit PROPRIA - Database.QueryBuilder.Sychronize (Modulos/Database/Async) - sobre TThread
    CRU (Classes/System.Classes) + TEvent (SyncObjs/System.SyncObjs): a FPC
    3.3.1 nao tem System.Threading/TTask, por isso o desenho cross-compiler
    usa so a base TThread comum aos 2 compiladores. Await BLOQUEIA a thread
    chamadora ate a tarefa terminar e devolve o RESULTADO, ou RELANCA (como
    EDatabaseAsyncException, ERR_DATABASE_ASYNC, Exceptions.Database) se a
    funcao de trabalho tiver levantado uma excecao em segundo plano - a
    excecao ORIGINAL nao atravessa threads em Object Pascal (nao existe forma
    segura de repassar o proprio objecto Exception entre threads/heaps), por
    isso Await embrulha a MENSAGEM original (ClassName+Message) numa NOVA
    excecao da faixa 41. IsCompleted/IsFaulted/Error sao consulta PASSIVA
    (nunca lancam, nunca bloqueiam) - polling seguro num loop de UI enquanto
    se espera pela conclusao sem chamar Await. }
  IORMTask<T> = interface
    ['{F1A2B3C4-D5E6-4708-9192-A3B4C5D6E7F8}']
    { Bloqueia ate a tarefa concluir; devolve o resultado (T) OU relanca
      EDatabaseAsyncException se a funcao de trabalho tiver falhado em
      segundo plano (ver comentario da interface, acima). Chamadas
      subsequentes sao seguras (a tarefa ja concluiu - devolve/relanca
      sempre o MESMO desfecho, TEvent manual-reset) e devolvem a MESMA
      referencia de T - quando T e' um objecto que o CALLER possui (ex.:
      TDataSet, ver IQueryBuilder.ExecuteAsync), o caller so pode chamar Free
      UMA vez; libertar apos uma 2a chamada a Await opera sobre um objecto ja
      destruido. }
    function Await: T;
    { True assim que a tarefa de fundo termina (com sucesso ou falha) -
      SEM bloquear (consulta o estado, nao espera). }
    function IsCompleted: Boolean;
    { True so apos IsCompleted=True E a funcao de trabalho ter lancado uma
      excecao; False enquanto ainda a correr OU se concluiu com sucesso. }
    function IsFaulted: Boolean;
    { Mensagem da excecao capturada em segundo plano (ClassName+': '+Message);
      '' enquanto a tarefa ainda nao concluiu OU se concluiu sem falhar. }
    function Error: string;
  end;

  { ===== QueryBuilder (Database.QueryBuilder.Interfaces) - USE_DATABASE ===== }

  { CASE ... WHEN ... THEN ... ELSE ... END - conveniencia para colunas
    computadas. Os operandos sao EXPRESSOES SQL do programador (thresholds/
    colunas), NAO input de utilizador; para valores de utilizador usar Where. }
  ICaseBuilder = interface
    ['{C8B2D3E4-5F60-4172-9B83-4D5E6F708192}']
    function WhenThen(const ACondition, AResult: string): ICaseBuilder;
    function ElseResult(const AResult: string): ICaseBuilder;
    function EndAs(const AAlias: string = ''): string; // devolve a expressao CASE completa
  end;

  { IQueryBuilder ja' forward-declarado no topo do ficheiro (Onda 7, camada
    de lancadores) - nao repetir aqui (2a forward decl do MESMO tipo antes
    de completar a 1a e' E2004 "Identifier redeclared"). }

  { I18 (Onda 6-e Estagio 2) - grupo de filtros PARENTIZADO, obtido via
    IQueryBuilder.WhereGroup. AndWhere/OrWhere acrescentam condicoes DENTRO do
    grupo (combinadas por AND/OR entre si, na ordem de chamada; a 1a condicao
    do grupo nao leva combinador); NotGroup nega o grupo inteiro ('NOT (...)');
    EndGroup fecha o grupo (anexa-o ao WHERE do IQueryBuilder DONO, combinado
    por AND com os itens irmaos do nivel de topo) e devolve o IQueryBuilder
    para continuar a cadeia fluente. Grupo sem condicoes = no-op (nao aparece
    no SQL, tal como WhereRaw('')). }
  IFilterGroup = interface
    ['{E1F2A3B4-5C6D-4E7F-8091-A2B3C4D5E6F7}']
    function AndWhere(const AColumn, AOp: string; const AValue: Variant): IFilterGroup; overload;
    function AndWhere(const AColumn: string; const AValue: Variant): IFilterGroup; overload; // op '='
    function OrWhere(const AColumn, AOp: string; const AValue: Variant): IFilterGroup; overload;
    function OrWhere(const AColumn: string; const AValue: Variant): IFilterGroup; overload; // op '='
    function NotGroup: IFilterGroup; // nega o grupo inteiro: NOT (...)
    function EndGroup: IQueryBuilder; // fecha o grupo, devolve o QueryBuilder dono
  end;

  IQueryBuilder = interface
    ['{B7A1C2D3-4E5F-4061-8A72-3C4D5E6F7081}']
    { AVISO DE SEGURANCA (SQL injection) - M10/conformidade F5: os metodos que
      aceitam SQL/expressao/condicao CRUA do chamador NAO fazem bind e emitem o
      texto verbatim: SelectRaw / SelectComputed(AExpression) / FromVirtual
      (ASubQuerySQL) / Join / LeftJoin / RightJoin(ACondition) / WhereRaw /
      Having / OrHaving. NUNCA construir esses argumentos concatenando input de
      utilizador final. Para VALORES de utilizador usar sempre Where / OrWhere /
      WhereIn / WhereOp / Value / SetValue (bindados como :paramN). Mesmo
      criterio ja documentado no ICaseBuilder. }

    { conexao (fornece o dialecto via IDialect.ForConnection) }
    function Connection(const AConnection: IConnection): IQueryBuilder; overload;
    function Connection: IConnection; overload;

    { Onda S3 (eixo SQL - ToDDL/ToSQL) - dialecto INDEPENDENTE da conexao
      (golden/SQL SEM servidor), MESMO padrao ja usado por ITable/ITables/
      ISchema/IDatabase.DatabaseTypes - permite resolver ToSQL/ToSQLFormatted
      so pelo enum TDatabaseTypes, sem exigir uma IConnection viva (Execute/
      ExecuteMutation continuam a precisar de Connection real - so o RENDER de
      SQL fica desacoplado). Precedencia sobre Connection quando ambos estao
      definidos (mesmo criterio de override manual ja documentado em
      IDatabase.DatabaseTypes, acima neste ficheiro) - permite trocar so o
      dialecto sem perder uma Connection ja injectada para Execute. Aditivo,
      100% retrocompativel (nenhum metodo pre-existente muda de assinatura). }
    function DatabaseTypes(const AValue: TDatabaseTypes): IQueryBuilder; overload;
    function DatabaseTypes: TDatabaseTypes; overload;

    { SELECT }
    function Select(const AColumns: TStringArray): IQueryBuilder; overload;
    function Select(const AColumns: string = '*'): IQueryBuilder; overload;
    function SelectRaw(const AExpression: string): IQueryBuilder; // expressao livre (CASE, funcoes)
    function SelectComputed(const AName, AExpression: string): IQueryBuilder; // <AExpression> AS <ident(AName)> - AExpression CRU (nao quotado); AName quotado
    function Distinct(const AValue: Boolean = True): IQueryBuilder;
    function Count(const AColumn: string = '*'; const AAlias: string = ''): IQueryBuilder;
    function Sum(const AColumn: string; const AAlias: string = ''): IQueryBuilder;
    function Max(const AColumn: string; const AAlias: string = ''): IQueryBuilder;
    function Min(const AColumn: string; const AAlias: string = ''): IQueryBuilder;
    function Avg(const AColumn: string; const AAlias: string = ''): IQueryBuilder;

    { FROM (tabela+schema OU subquery = derived table) }
    function From(const ATable: string; const ASchema: string = ''): IQueryBuilder; overload;
    function From(const ASubQuery: IQueryBuilder; const AAlias: string): IQueryBuilder; overload;
    function FromVirtual(const ASubQuerySQL, AAlias: string): IQueryBuilder; // FROM (<ASubQuerySQL>) <ident(AAlias)> - ASubQuerySQL CRU (fonte virtual); ultimo From*/FromVirtual chamado vence

    { JOIN }
    function Join(const ATable, ACondition: string): IQueryBuilder;
    function LeftJoin(const ATable, ACondition: string): IQueryBuilder;
    function RightJoin(const ATable, ACondition: string): IQueryBuilder;
    { AutoJoin por FK (Onda 6-c, I5/I20) - acrescenta um INNER JOIN a partir de
      uma relacao ja conhecida (TRelationInfo, descoberta via ICatalogReader.ResolveFK
      ou construida manualmente): 'INNER JOIN <ToTable> ON <FromTable>.
      <FromColumn> = <ToTable>.<ToColumn>' (identificadores quotados pelo
      dialecto). Fluente; reutiliza o mesmo mecanismo de Join. }
    function JoinByFK(const ARelation: TRelationInfo): IQueryBuilder;
    { Descobre a FK entre a tabela FROM atual e ATableName via ICatalogReader
      (consulta ResolveFK nas 2 direcoes - FROM->ATableName e, se nao achar,
      ATableName->FROM com a relacao invertida) e chama JoinByFK. No-op
      (devolve Self sem alterar) se a Connection/From nao estiverem definidas
      ou se nao houver FK entre as 2 tabelas. }
    function AutoJoin(const ATableName: string; const ASchema: string = ''): IQueryBuilder;

    { WHERE - BINDADO (o valor vira :paramN; nunca literal) }
    function Where(const AColumn, AOp: string; const AValue: Variant): IQueryBuilder; overload;
    function Where(const AColumn: string; const AValue: Variant): IQueryBuilder; overload; // op '='
    { I18 (Onda 6-e Estagio 2) - condicao de topo combinada com OR (em vez do
      AND implicito de Where); a 1a condicao do WHERE nunca leva combinador
      (seja ela Where ou OrWhere). }
    function OrWhere(const AColumn, AOp: string; const AValue: Variant): IQueryBuilder; overload;
    function OrWhere(const AColumn: string; const AValue: Variant): IQueryBuilder; overload; // op '='
    function WhereIn(const AColumn: string; const AValues: array of Variant): IQueryBuilder;
    function WhereNotIn(const AColumn: string; const AValues: array of Variant): IQueryBuilder;
    function WhereBetween(const AColumn: string; const ALow, AHigh: Variant): IQueryBuilder;
    function WhereInSubQuery(const AColumn: string; const ASubQuery: IQueryBuilder): IQueryBuilder;
    function WhereIsNull(const AColumn: string): IQueryBuilder;
    function WhereIsNotNull(const AColumn: string): IQueryBuilder;
    { Onda 6-e Estagio 3 (I19) - operador SEMANTICO, independente do dialecto:
      ASemanticOp (case-insensitive) e um dos 'eq'/'neq'/'gt'/'ge'/'lt'/'le'
      (mapeados directamente para =/<>/>/>=/</<=) ou 'contains'/'startsWith'/
      'endsWith' (viram LIKE - ou ILIKE se o dialecto suportar scILike, ex.:
      PostgreSQL - com AValue envolvido em wildcards '%'). Sempre bindado
      (:paramN, nunca literal). Nome semantico desconhecido -> 410081
      (ERR_DATABASE_QB_UNKNOWN_OP). }
    function WhereOp(const AColumn, ASemanticOp: string; const AValue: Variant): IQueryBuilder;
    function WhereRaw(const ACondition: string): IQueryBuilder; // sem bind - responsabilidade do caller
    { I18 (Onda 6-e Estagio 2) - abre um grupo de filtros PARENTIZADO
      (IFilterGroup.AndWhere/OrWhere/NotGroup); IFilterGroup.EndGroup fecha o
      grupo, anexa-o ao WHERE (combinado por AND com os itens irmaos de topo)
      e devolve Self. Suporta 1 nivel de agrupamento; para condicoes SQL
      arbitrarias (incl. parenteses manuais) usar WhereRaw. }
    function WhereGroup: IFilterGroup;

    { GROUP / HAVING / ORDER }
    function GroupBy(const AColumns: string): IQueryBuilder; overload;
    function GroupBy(const AColumns: TStringArray): IQueryBuilder; overload;
    function Having(const ACondition: string): IQueryBuilder;
    { I18 (Onda 6-e Estagio 2) - WHERE vs HAVING: combina ACondition com o
      HAVING ja existente via OR ('(<existente>) OR (<ACondition>)'); se ainda
      nao houver HAVING, comporta-se como Having (define isolado). Having(...)
      continua a SOBRESCREVER (comportamento pre-existente inalterado). }
    function OrHaving(const ACondition: string): IQueryBuilder;
    function OrderBy(const AColumns: string): IQueryBuilder; overload;
    function OrderBy(const AColumns: TStringArray): IQueryBuilder; overload;
    function OrderByDesc(const AColumns: string): IQueryBuilder;

    { paginacao (delega a IDialect.ApplyPagination - capability-gated) }
    function Limit(const AValue: Integer): IQueryBuilder;
    function Offset(const AValue: Integer): IQueryBuilder;

    { composicao }
    function UnionWith(const AOther: IQueryBuilder; const AAll: Boolean = False): IQueryBuilder;
    function WithCTE(const AName: string; const AQuery: IQueryBuilder): IQueryBuilder;

    { Smart Distinct (Onda 6-c, I5) - configura a query atual como
      'SELECT DISTINCT <AColumn> FROM <tabela atual> ORDER BY <AColumn>'
      (reutiliza Select/Distinct/OrderBy; opera sobre o From ja definido). Fluente. }
    function DistinctValuesQuery(const AColumn: string): IQueryBuilder;

    { mutations - BINDADAS (fecham o GAP GestorERP) }
    function InsertInto(const ATable: string; const ASchema: string = ''): IQueryBuilder;
    function Value(const AColumn: string; const AValue: Variant): IQueryBuilder;     // INSERT
    function Update(const ATable: string; const ASchema: string = ''): IQueryBuilder;
    function SetValue(const AColumn: string; const AValue: Variant): IQueryBuilder;  // UPDATE
    { UPDATE por auto-incremento dialect-aware: SET col = col + ADelta (ambos os lados
      quotados pelo dialeto). Reordenacao/contadores SEM SQL manual no chamador. }
    function SetValueDelta(const AColumn: string; const ADelta: Integer): IQueryBuilder;  // UPDATE col=col+/-N
    function DeleteFrom(const ATable: string; const ASchema: string = ''): IQueryBuilder;

    { formatacao }
    function Pretty(const AValue: Boolean = True): IQueryBuilder;
    { I15 (Onda 6-e Estagio 1) - SQL SEMPRE formatado (indentacao/quebras de
      linha), independente do estado de Pretty/FPretty. Nao altera Pretty. }
    function ToSQLFormatted: string;

    { saida }
    function ToSQL: string;                 // SQL com placeholders :paramN
    function Params: TArray<Variant>;       // valores na ordem dos placeholders
    function Execute: TDataSet;             // SELECT (execucao parametrizada)
    function ExecuteMutation: Integer;      // INSERT/UPDATE/DELETE -> RowsAffected
    { Onda 6-f Estagio 2 (I11/A2) - corre Execute (o SELECT actual) NUMA
      THREAD de fundo (TORMTask<TDataSet>, Database.QueryBuilder.Sychronize) e devolve
      IMEDIATAMENTE (nao bloqueia); IORMTask<TDataSet>.Await bloqueia ate
      terminar e devolve o mesmo TDataSet DESCONECTADO que Execute devolveria
      (F4 - seguro de atravessar threads), ou relanca se a query tiver
      falhado em segundo plano. NOTA DE THREAD-SAFETY: a IConnection
      injectada (Connection) e usada PELA THREAD DE FUNDO enquanto a tarefa
      corre - o caller NAO deve usar a MESMA IConnection concorrentemente
      antes de Await(); a propria IQueryBuilder e mantida viva (captura por
      closure) ate a tarefa terminar, mesmo que o caller nao guarde outra
      referencia. }
    { AVISO (async) - M8/M9/conformidade F5, dois GOTCHAS do ExecuteAsync:
      1) NAO thread-safe por instancia: enquanto a tarefa corre, NAO reutilizar
         a MESMA IQueryBuilder (ToSQL / Params / Where / Statistics / novo
         Execute) ate Await() retornar - ha corrida sobre o estado interno
         (FBound / FDialect / FStatistics). Usar outra instancia se precisar em
         paralelo.
      2) DESCARTAR o IORMTask<TDataSet> devolvido (nao capturar a interface) faz
         o refcount cair a zero de imediato -> Destroy chama WaitFor -> degenera
         em execucao SINCRONA BLOQUEANTE (anula o "devolve imediatamente").
         Capturar sempre num LTask: IORMTask<TDataSet> ate Await(). }
    function ExecuteAsync: IORMTask<TDataSet>;
    { I3 (Onda 6-e Estagio 1) - estatisticas do ULTIMO Execute/ExecuteMutation
      (TQueryStatistics de Commons.Database.Types). Sem execucao ainda -> record
      zerado (RowsAffected=0, ElapsedMs=0, LastSQL=''). }
    function Statistics: TQueryStatistics;

    { I17 (Onda 6-e Estagio 4) - presets JSON: serializa/reconstroi o ESTADO
      ESSENCIAL da query (kind/table/schema/select/where/orderby/limit/offset)
      em JSON (fpjson/System.JSON) - persistir/recuperar filtros de UI (grids,
      relatorios parametrizaveis, favoritos de consulta). SavePreset cobre:
      kind (select/insert/update/delete); table/schema; select (SO colunas
      simples por nome - Select(AColumns), NAO SelectRaw/SelectComputed/
      agregados Count/Sum/Max/Min/Avg); where (SO comparacao simples - whCmp,
      de Where/OrWhere, incl. o combinador AND/OR de topo; NAO WhereIn/
      WhereNotIn/WhereBetween/WhereIsNull/WhereIsNotNull/WhereRaw/
      WhereInSubQuery/WhereGroup); orderby (as strings JA RENDERIZADAS -
      quotadas pelo dialecto ATUAL no momento de cada OrderBy/OrderByDesc; o
      preset fica atado ao MESMO dialecto/conexao com que foi montado -
      LoadPreset NAO re-quota); limit/offset. NAO cobre (fica de fora,
      silenciosamente): Join/AutoJoin, GroupBy/Having, Distinct, Union/CTE,
      INSERT/UPDATE Value/SetValue (so kind/table/schema sao restaurados - o
      caller tem de chamar Value/SetValue de novo antes de ToSQL/Execute).
      LoadPreset SUBSTITUI (nao faz merge) o estado essencial do builder ONDE
      FOR CHAMADO - devolve Self para continuar a cadeia fluente (ex.: um
      Connection/Join aplicado depois de recarregar o preset). JSON invalido/
      vazio -> no-op (Self inalterado), mesmo padrao defensivo de
      IField.StructureFromJSON. }
    function SavePreset: string;
    function LoadPreset(const AJSON: string): IQueryBuilder;

    { Onda 6-f Estagio 1 (I10) - chamada de uma STORED PROCEDURE tipada, com
      argumentos POSICIONAIS sempre BINDADOS (:paramN, nunca literal - mesmo
      mecanismo Bind das mutations INSERT/UPDATE). Sintaxe por banco delegada
      a IDialect.CallProcedureSQL (Database.Dialect.Interfaces - unico
      sitio com SQL especifico de motor: SQLServer 'EXEC <proc> ...'/
      PostgreSQL/MySQL 'CALL <proc>(...)'/Firebird 'EXECUTE PROCEDURE
      <proc> ...'). Muda o estado do builder para uma CHAMADA (kind proprio,
      substitui qualquer Select/InsertInto/Update/DeleteFrom anterior - mesma
      semantica de "ultimo From*/InsertInto/Update/DeleteFrom vence" ja usada
      pelos outros modos). Dialecto sem suporte (SQLite/Access -
      CallProcedureSQL='') -> ToSQL devolve '' e Execute/ExecuteMutation
      ficam NO-OP (Result=nil/0, sem chamar a IConnection) - no-op gracioso,
      nunca lanca. }
    function CallProcedure(const AName: string; const AArgs: array of Variant): IQueryBuilder;
  end;

{$IFDEF USE_ENTITY_MANAGER}
  { Onda 7 - resolucao do ciclo ITable.EntityManager <-> Database.
    EntityManager (que ja usa Database.Table para TTable.New em
    CloneTableStructure/MapTable - Database.Table.pas NAO pode `uses
    Database.EntityManager` diretamente, seria uma referencia circular de
    unit). Factory-function REGISTADA: Database.EntityManager.pas atribui
    GTableEntityManagerFactory na sua secao `initialization` (essa unit ja
    conhece Database.Table); TTable.EntityManager (Database.Table.pas) so
    CHAMA a var, com guarda Assigned - devolve nil se a unit Database.
    EntityManager nunca chegou a ser linkada no executavel (ex.: um
    programa que so `uses Database.Table` isolado, sem passar pela fachada
    Database/Database.pas). DECLARADA AQUI (apos IQueryBuilder completar) e
    NAO logo a seguir a IEntityManager (secao ungated, mais acima) porque um
    `var` intercalado ANTES de completar um forward type causa E2086 "not
    yet completely defined" (confirmado por compilacao real, dcc32+fpc32) -
    IIdentityMap<T>/ICatalogReader/ISynchronize/IQueryBuilder so ficam COMPLETOS
    mais abaixo no ficheiro; esta e' a primeira posicao segura apos todos. }
  TTableEntityManagerFactory = function(const ATable: ITable): IEntityManager;

var
  GTableEntityManagerFactory: TTableEntityManagerFactory;

type
{$ENDIF}
  { ===== QueryTransformer (Database.QueryTransformer.Interfaces) - USE_DATABASE ===== }

  IFilterValueProvider = interface;

  IQueryTransformer = interface
    ['{D9C3E4F5-6071-4283-AC94-5E6F70819203}']

    { query base a transformar (envolvida como derived table) }
    function Source(const AQuery: IQueryBuilder): IQueryTransformer;

    { filtros TIPADOS - bindados (:paramN); operador por dialecto (N1) }
    function Equal(const AColumn: string; const AValue: Variant): IQueryTransformer;
    function NotEqual(const AColumn: string; const AValue: Variant): IQueryTransformer;
    function GreaterThan(const AColumn: string; const AValue: Variant): IQueryTransformer;
    function GreaterOrEqual(const AColumn: string; const AValue: Variant): IQueryTransformer;
    function LessThan(const AColumn: string; const AValue: Variant): IQueryTransformer;
    function LessOrEqual(const AColumn: string; const AValue: Variant): IQueryTransformer;
    function Between(const AColumn: string; const ALow, AHigh: Variant): IQueryTransformer;
    function Contains(const AColumn, AText: string): IQueryTransformer;   // %texto% (ILIKE/LIKE)
    function StartsWith(const AColumn, AText: string): IQueryTransformer; // texto%
    function EndsWith(const AColumn, AText: string): IQueryTransformer;   // %texto
    function IsIn(const AColumn: string; const AValues: array of Variant): IQueryTransformer;
    function IsNull(const AColumn: string): IQueryTransformer;
    function IsNotNull(const AColumn: string): IQueryTransformer;

    { sorting }
    function OrderByAsc(const AColumn: string): IQueryTransformer;
    function OrderByDesc(const AColumn: string): IQueryTransformer;

    { projecao soft (N5): Include gera SQL; Visible so informa a UI }
    function Column(const AName: string; const AInclude: Boolean = True;
      const AVisible: Boolean = True; const AAlias: string = ''): IQueryTransformer;

    { paginacao por wrap }
    function Page(const APageIndex, APageSize: Integer): IQueryTransformer; // 1-based
    function Limit(const AValue: Integer): IQueryTransformer;
    function Offset(const AValue: Integer): IQueryTransformer;

    { saida }
    function ToSQL: string;                 // SQL do wrap, com placeholders
    function Params: TArray<Variant>;       // params da base + filtros, na ordem
    function VisibleColumns: TStringArray;  // N5: colunas marcadas Visible (para a UI)
    function Execute: TDataSet;

    { T5 - descricao legivel das condicoes aplicadas (templates, sem ML) }
    function ToHumanText: string;
    { T1 - provider de valores distintos por campo (filtros de grid), com cache }
    function FilterValues: IFilterValueProvider;
  end;

  { T1 - Smart Distinct: SELECT DISTINCT <campo> FROM (<base>) ORDER BY <campo>,
    com cache por coluna (invalidavel). Popula dropdowns de filtro de grid sem
    lookups hardcoded. }
  IFilterValueProvider = interface
    ['{EAF40132-7182-4394-BDA5-6F70819203A4}']
    function ForColumn(const AColumn: string): TArray<Variant>;
    function Invalidate: IFilterValueProvider;                     // limpa toda a cache
    function InvalidateColumn(const AColumn: string): IFilterValueProvider;
  end;
{$ENDIF}

implementation

end.
