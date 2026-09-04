{ =============================================================================
  Database.Table - Tabela (TTable, ITable)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.3.0
  FileVersion:    1.17.0
  Author:         Claiton de Souza Linhares
  Date:           30/07/2026

  Changelog (file):
  - 1.10.0 (01/09/2026): bug-1170 - CHAVE PRIMARIA COMPOSTA no DML.
    WhereByPrimaryKey deixa de usar GetPrimaryKey (singular) e passa a
    compor a condicao com TODAS as colunas IsPKey; EnsurePrimaryKeyPresent
    passa a exigir todas preenchidas e a nomear as que faltam. Sem isto,
    ExecuteDelete/ExecuteUpdate atingiam as linhas IRMAS (perda de dados
    silenciosa) em qualquer tabela de PK composta. PK simples: SQL gerado
    identico ao anterior, zero mudanca de comportamento.
  - 1.17.0 (30/07/2026): Onda S3b (ADITIVO - materializacao do merge, ver
    Databases.Interfaces 3.3.0) - 2 novos getters read-only Uniques:
    TSchemaUniques/Indexes: TSchemaIndexes (devolvem FUniques/FIndexes,
    Onda S2-b1, tal-qual - sem round-trip JSON) - necessarios para o bridge
    ITable->ISchemaDefinition de ISchema.ApplyStructure (Database.Schema.pas)
    construir o ISchemaDefinition sem depender de StructureToJSON. Zero
    mudanca nos metodos pre-existentes (FUniques/FIndexes continuam
    populados/lidos exactamente como antes por StructureToJSON/
    TableStructureFromJSON/TableStructureMergeFromJSON).
  - 1.16.0 (30/07/2026): Onda S4 (ADITIVO - eixo FULL, ver Databases.Interfaces
    3.2.0) - ToFullJSON (COMPOE StructureToJSON+ToJSON)/TableFromFullJSON/
    TableMergeFullFromJSON (decompoem via Database.Helpers.JSON.
    JSONExtractMember, estrutura antes de dado, delegando DIRECTAMENTE aos
    metodos "Table*" irmaos ja existentes) + Export(AWithData)/TableImport
    ergonomicos, vinculados aos slots ITable.FromFullJSON/MergeFullFromJSON/
    Import via clausula de resolucao de interface (mesma tecnica de
    TableFromJSON/TableMergeFromJSON). Novo overload Export(AWithData,
    AQuery: IQueryBuilder), gated USE_DATABASE - delega a TryExportQueryData
    (novo helper Database.Helpers.Export) para resolver Connection/executar
    AQuery/serializar o TDataSet via TDataSetSerializeHelper.
    ToJSONArrayString; sem Connection viva ou AQuery=nil, cai graciosamente
    em ToFullJSON (NUNCA lanca). ACHADO durante a implementacao: Data.DB
    (necessario para TDataSet) NAO pode entrar directamente no uses desta
    unit - Data.DB.TDataSetState (dsInactive/dsInsert/dsEdit) colide POR
    NOME com Commons.Database.Types.TRowStatus (FStatus/Status/Execute, ja
    existentes), tornando ambiguos os `case FStatus of dsInsert: dsEdit:
    ...` pre-existentes (confirmado por compilacao real, E2010 Incompatible
    types) - resolvido isolando TDataSet/Serialize na nova unit
    Database.Helpers.Export (sem TRowStatus), consumida so por
    TableFullJSON/TableFromFullJSON e por este overload. Novo uses
    (implementation, dentro do bloco USE_DATABASE ja existente):
    Database.Helpers.Export. Zero mudanca nos metodos pre-existentes.
  - 1.15.0 (29/07/2026): Onda S3 (ADITIVO - eixo SQL, ver Databases.Interfaces
    3.1.0) - ToDDL: string (script DDL desta tabela, agregando CreateTableSQL
    - colunas+PK/NOT NULL+FK POR-CAMPO inline - com AddUniqueSQL/AddIndexSQL
    para cada FUniques/FIndexes, Onda S2-b1; NAO repete AddForeignKeySQL para
    os campos com ReferencedTable preenchido - duplicaria a MESMA constraint
    ja embutida por CreateTableSQL, invalidando o script - ver comentario
    completo no corpo do metodo) + ToSQL: string (DML - INSERT do registo
    actual via IQueryBuilder.InsertInto/Value/ToSQL, NUNCA SQL a mao; dialect-
    aware sem exigir conexao ligada via o novo overload IQueryBuilder.
    DatabaseTypes quando FConnection nao esta injectada; skip do mesmo
    criterio Optimized de InsertSQL para campos nao-nulaveis sem valor). Novo
    uses: nenhum (Database.QueryBuilder ja estava no bloco USE_DATABASE do
    uses da implementation, Onda 7). Zero mudanca em CreateTableSQL/
    AddUniqueSQL/AddIndexSQL/InsertSQL pre-existentes.
  - 1.14.0 (29/07/2026): Onda S2-b1 (ADITIVO, cobertura serializacao UNIQUE/
    INDEX) - preparacao da serializacao de ESTRUTURA para versionamento de
    banco: FUniques/FIndexes (novos campos privados, reusam TSchemaUnique/
    TSchemaIndex/TSchemaUniques/TSchemaIndexes de Commons.Database.Types -
    mesmo "dado puro" ja usado pelo SchemaSync/ISchemaTable, regra #14 anti-
    duplicacao) guardam as constraints UNIQUE nomeadas/compostas e os INDEXES
    (nome+colunas[+unique]) definidos ao nivel da tabela - ate agora so
    existiam operacoes IMPERATIVAS (ITable.AddUnique/AddIndex, "Onda D") que
    executam DDL mas nao guardavam a definicao para serializar. StructureToJSON
    passa a emitir +"uniques" (array de objectos name/columns[]) e +"indexes"
    (array de objectos name/columns[]/unique:bool); TableStructureFromJSON reconstroi
    FUniques/FIndexes por completo (Clear+substitui, mesma semantica de
    "fields"/"primaryKey"); TableStructureMergeFromJSON aplica PATCH aditivo
    POR NOME (TableIndexOfUnique/TableIndexOfIndex - existente e actualizado
    no lugar, ausente e acrescentado, NUNCA remove). Novos helpers de unit
    (implementation, fora da classe): TableSchemaColumnsToJSON (encode,
    generico) + TableSchemaColumnsFromJSON (decode, duplicado por compilador
    - fpjson TJSONData / System.JSON TJSONValue, mesmo padrao de
    TableJSONNodeToVariant) + TableIndexOfUnique/TableIndexOfIndex (busca por
    nome case-insensitive, mesmo criterio de TFields.IndexOfField). PK/FK
    continuam cobertos POR-CAMPO (isPKey/referencedTable/... em cada
    elemento de "fields", Onda S2-a) - inalterado. Sem API fluente nova de
    construcao em memoria (fora do escopo desta onda) e sem materializacao no
    banco (Onda S3b, futura) - so MODELO + serializacao. Zero mudanca de
    assinatura nos 3 metodos estendidos (StructureToJSON/StructureFromJSON/
    StructureMergeFromJSON) nem em qualquer outro metodo pre-existente.
  - 1.13.0 (29/07/2026): Onda S2-a (ADITIVO, simetria To/From/Merge) - ITable
    ganha StructureMergeFromJSON (TableStructureMergeFromJSON, vinculado via
    clausula de resolucao de interface) - PATCH aditivo de metadata: "table"
    patch (Get default=FTableName), "fields" delega a `inherited
    StructureMergeFromJSON` (TFields, Onda S2-a - patch por nome de coluna),
    "primaryKey" so acrescenta IsPKey=True (nunca desmarca). Ao contrario de
    TableStructureFromJSON (Clear + reconstroi tudo), esta versao preserva
    campos existentes e nunca remove. Zero mudanca nos metodos
    pre-existentes.
  - 1.12.3 (27/07/2026): conformidade F5 (onda C5, M7) - TableJSONQuoteString
    local removida; delega ao SSOT unico Database.Helpers.JSON.JSONQuoteString
    (regra #14). Sem mudanca de comportamento.
  - 1.12.2 (26/07/2026): conformidade F5 (onda C1, plano
    providersorm-v3-f5-conformidade) - B11: comentario obsoleto na seccao de
    introspeccao ("substitui o extinto ICatalogReader") corrigido - os helpers
    Cat* DELEGAM ao TCatalogReader (SSOT, regra transversal 14, ver corpos
    1708-1836); o que foi dissolvido do publico foi o IMetadata, NAO o
    ICatalogReader. Sem mudanca de codigo. ModuleVersion re-sincronizado
    2.8.0 -> 3.0.0.
  - 1.12.1 (25/07/2026): R2.3 (f5-repair, Onda R2 - re-layering por
    responsabilidade) - ADITIVO, extend existing: ITable ganha introspeccao
    de SI MESMA - TableStructure/ColumnExists/PrimaryKeyColumns/
    PrimaryKeyExists/ForeignKeys/ResolveFK/ForeignKeyNames/ForeignKeyExists/
    UniqueNames/IndexNames/UniqueExists/IndexExists - cada uma delega a
    TCatalogReader.New(Connection).<Metodo>(TableName, [args,] '') - schema fixo
    '' por agora, Connection/TableName sao os getters fluentes ja existentes
    nesta propria classe. Gated USE_DATABASE no corpo (degrada para vazio/
    False quando OFF, mesmo padrao das facetas Onda D). Sem uses novo -
    Database.CatalogReader ja estava na seccao implementation (gated
    USE_DATABASE) desde a Onda D.
  - 1.12.0 (15/07/2026): Onda 7 (camada de lancadores fluentes, ADITIVO) -
    ITable ganha QueryBuilder (Database.QueryBuilder.TQueryBuilder.New.
    Connection(FConnection).From(FTableName) - PRE-CONFIGURADO com a propria
    tabela; gated USE_DATABASE) + UnitOfWork (Database.UnitOfWork.
    TUnitOfWork.New.Connection(FConnection) - so Connection-bound, o REGISTO
    fica ao cargo do caller; ungated, Database.UnitOfWork.pas nao depende de
    USE_DATABASE) + EntityManager (mapeado a Self via a factory-function
    GTableEntityManagerFactory - Databases.Interfaces 2.11.0 - registada por
    Database.EntityManager.pas na sua `initialization`; guarda Assigned
    devolve nil se essa unit nunca foi linkada; gated USE_ENTITY_MANAGER).
    Novo uses (implementation): Database.QueryBuilder (gated USE_DATABASE) +
    Database.UnitOfWork (ungated) - nenhum dos 2 usa Database.Table, sem
    ciclo (confirmado por grep antes da implementacao).
  - 1.11.0 (15/07/2026): Onda 6-e Estagio 4 (F5 revisao, A3+A4, ADITIVO) -
    A3: EnsureSafeDML passa a incluir o SQL bloqueado em
    EDatabaseUnsafeDMLException.SQLContext (Exceptions.Database 1.6.0;
    mensagem/ErrorCode inalterados). A4: ITable ganha um HOOK de validacao
    CUSTOMIZADA - FOnValidate: TOnTableValidate (Databases.Interfaces) +
    OnValidate(AValue)/OnValidate (getter/setter fluente, padrao ReadOnly) +
    RunCustomValidation (privado) chamado por Execute IMEDIATAMENTE APOS a
    validacao embutida (ValidateFields) passar, nos MESMOS 4 pontos
    (dsInsert, dsEdit, e os 2 ramos dsInactive inferidos insert/update) -
    NUNCA em dsDeleted (mesmo escopo do guard embutido: DELETE nao valida).
    O hook devolve False (+ AErrors opcional, "Field,Message") para bloquear
    a operacao - RunCustomValidation lanca EDatabaseValidationException/
    ERR_DATABASE_VALIDATION (reusado, sem novo codigo), mensagem via novo
    helper de unit TableBuildCustomValidationMessage. Sem OnValidate
    configurado (default nil) -> RunCustomValidation e no-op (0 chamadas
    extra, comportamento 100% inalterado).
  - 1.10.0 (14/07/2026): Onda 6-b I7 - LogicalName em IField/ITable (nome
    logico) + ITable.PhysicalColumn (resolucao logico->fisico,
    case-insensitive, fallback ao nome dado); ListWhere delega. Aditivo
    (default '' -> inalterado).
  - 1.9.0 (14/07/2026): Sub-passo 4.5 (continuacao Onda 4, revisao F5) -
    validacao no save + guardas read-only (modelo v1.6.1), ADITIVO (sem
    ReadOnly/FieldIsDeleted configurados e com PK preenchida em dsEdit/
    dsDeleted, comportamento 100% inalterado). ValidateFields(out AErrors:
    TFieldValidationErrors): Boolean - novo; percorre GetFieldsList, ignora
    campos FieldAllowsNull=True e os nomes configurados em FieldDateCreated/
    FieldDateUpdated (carimbados por InsertSQL/UpdateSQL DEPOIS desta
    validacao correr dentro de Execute - nunca acusados como obrigatorio em
    falta); cada obrigatorio vazio/Unassigned/Null vira 1 TFieldValidationError
    (Field,Message) em AErrors. ValidateNotNullFields passa a WRAPPER aditivo
    (Result := ValidateFields(LErrors) descartando o detalhe) - mesma
    semantica booleana, zero uso pre-existente no codebase (grep confirmado).
    FReadOnly (campo novo) + ReadOnly(AValue)/ReadOnly (getter/setter
    fluente, padrao AuditFields) - guarda equivalente ao FDeletedBlock
    v1.6.1. TTable.Execute(AConnection) ganha, logo apos resolver LConn e
    ANTES do "case FStatus": (1) EnsureNotReadOnly (privado, novo) - lanca
    EDatabaseReadOnlyException/ERR_DATABASE_READONLY quando FReadOnly=True OU
    quando FieldIsDeleted esta configurado E o campo existe E o seu VALOR
    CORRENTE (no proprio objecto, nao no banco) "parece verdadeiro"
    (TableValueLooksTrue, reusado do helper de serializacao JSON da Fatia
    B-b) - aplica-se a QUALQUER Status (Insert/Edit/Delete/inferido); dentro
    do case, dsEdit/dsDeleted passam a chamar EnsurePrimaryKeyPresent
    (privado, novo) ANTES de ExecuteUpdate/ExecuteDelete - lanca
    EDatabaseInvalidStatusException/ERR_DATABASE_INVALID_STATUS quando
    GetPrimaryKey e nil OU o seu valor e vazio/Unassigned/Null (sem PK nao ha
    como localizar a linha - WhereByPrimaryKey geraria WHERE "pk"='' e o
    UPDATE/DELETE afetaria 0 linhas silenciosamente); os ramos dsInsert,
    dsEdit e os 2 ramos inferidos de dsInactive (insert/update por PK vazia/
    preenchida) chamam ValidateFields ANTES de ExecuteInsert/ExecuteUpdate -
    lanca EDatabaseValidationException/ERR_DATABASE_VALIDATION (mensagem via
    novo helper de unit TableBuildValidationMessage, lista os nomes dos
    campos) quando ha obrigatorios em falta; dsDeleted NUNCA valida
    obrigatorios (so INSERT/UPDATE, conforme a ordem do owner). Guardas
    aplicadas SO dentro de Execute (nao em ExecuteInsert/ExecuteUpdate/
    ExecuteDelete chamados diretamente, ex.: TEntityManager.Update/Delete) -
    escopo igual ao pedido (Execute/Save; Save ja delega para Execute desde a
    Fatia B-e/1.4.0).
  - 1.8.0 (14/07/2026): Sub-passo 4.4 (continuacao Onda 4, revisao F5) - soft
    delete + auditoria (modelo v1.6.1 form-driven), ADITIVO (so ativa quando
    os respetivos campos de configuracao estao definidos E a coluna existe na
    tabela; sem configuracao, comportamento fisico/inalterado). DeleteSQL:
    quando FieldIsDeleted configurado, gera 'UPDATE ... SET "<deleted>"=1 [,
    "<updated>"=<now>]' (soft) em vez de 'DELETE FROM ...' (fisico) - design
    composable preservado (sem WHERE embutido; ExecuteDelete continua a
    compor + WhereByPrimaryKey e a guarda EnsureSafeDML aplica-se igual, pois
    deteta o prefixo 'UPDATE '). InsertSQL: quando FieldDateCreated/
    FieldIsActive configurados, carimba Now()/1 antes de montar o INSERT.
    UpdateSQL: quando FieldDateUpdated configurado, carimba Now() antes de
    montar o SET (entra no UPDATE dinamico Optimized=True porque
    SetColumnValue marca IsChanged=True). Carimbo de data/hora sempre via
    Object Pascal (FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)) fluindo pelo
    MESMO pipeline SetColumnValue+QuoteIdent+QuotedStr de qualquer outro
    campo - nunca uma expressao SQL literal tipo NOW()/CURRENT_TIMESTAMP/
    GETDATE(). Os 3 metodos passam a ter efeito colateral (mutam os campos de
    auditoria via SetColumnValue) alem de gerar texto SQL - simetrico ao
    padrao ja existente de ler o estado vivo dos campos (IsChanged) nestes
    mesmos geradores.
  - 1.7.0 (13/07/2026): Fatia B-b (continuacao Onda 4, revisao F5) -
    serializacao PROPRIA da Table (registo/linha), sobrepondo os 4 metodos
    herdados de TFields/IFields. ToJSON/StructureToJSON (mesma assinatura
    string do herdado) sobrepostos por simples reintroducao de nome (padrao
    ja usado por HasChanges). FromJSON/StructureFromJSON precisam de retorno
    ITable (covariante sobre IFields), o que Object Pascal nao permite via
    reintroducao simples (2 metodos com o MESMO nome e MESMOS parametros
    diferindo so no tipo de retorno) - resolvido com implementacoes de nome
    distinto (TableFromJSON/TableStructureFromJSON) + clausula de resolucao
    de interface (function ITable.FromJSON = TableFromJSON; e idem para
    StructureFromJSON). Helpers locais de escaping RFC 8259
    (TableJSONQuoteString/TableJSONBoolLiteral/TableJSONNodeToVariant) -
    mesma tecnica do escaper da Fatia B-a (Database.Field.pas), duplicados
    localmente por nao serem exportados por aquela unit (fora do boundary
    desta tarefa); NUNCA QuotedStr para JSON (bug-293). MergeFromJSON (novo)
    - patch via SetColumnValue (dirty inteligente). object_state <->
    TRowStatus (RowStatusToObjectState/ObjectStateToRowStatus).
  - 1.6.0 (13/07/2026): Fatia A (continuacao Onda 4, revisao F5) - FConnection
    na ITable (ja existia como campo/property crua, mas colidia com os
    metodos fluentes homonimos Status/AuditFields/FieldDate*/FieldIs* - bug de
    compilacao pre-existente E2004/E2291 corrigido removendo o bloco inteiro
    de properties cruas, que duplicava os getters/setters fluentes ja
    implementados nesta mesma classe). Connection/Connection(v) fluente
    (padrao IField.Value) substitui a property; Execute(AConnection) passa a
    cair no fallback FConnection quando AConnection=nil, lancando
    EDatabaseException (ERR_DATABASE_NO_CONNECTION=410001, reusado - ja
    existente e usado no mesmo sentido por Dialect/Metadata/QueryBuilder/
    QueryTransformer/SchemaSync) se nenhuma das duas estiver disponivel; novo
    overload Execute (sem parametro) usa so a conexao fluente.
  - 1.5.0 (13/07/2026): Ajustes de API (ordem do owner). (1) Execute(AConnection):
    Integer - executa Insert/Update/Delete conforme FStatus (TRowStatus);
    dsInactive infere pela PK (sem PK -> insert; com PK -> update); reseta
    FStatus para dsInactive apos executar com sucesso (mesma logica que estava
    duplicada em TEntityManager.Save, agora centralizada aqui). (2) Rename
    GetSQLCreateTable -> CreateTableSQL e GetSQLDropTable -> DropTableSQL (os
    metodos que EXECUTAM, CreateTable/DropTable, mantiveram o nome; so as suas
    chamadas internas foram atualizadas).
  - 1.4.0 (13/07/2026): Fusao dos geradores de SQL por parametro Optimized
    (ordem do owner) - GenerateInsertSQL/GenerateInsertSQLOptimized fundidos em
    InsertSQL(const Optimized: Boolean = True) (skip de colunas NOT NULL vazias
    quando Optimized); GenerateUpdateSQL/GenerateUpdateSQLOptimized fundidos em
    UpdateSQL(const Optimized: Boolean = True) (SET so das colunas IsChanged
    quando Optimized) - ambas SEM WHERE (composable); GenerateWhereByPrimaryKey
    -> WhereByPrimaryKey(const Optimized: Boolean = True) e GenerateDeleteSQL ->
    DeleteSQL(const Optimized: Boolean = True) - parametro por uniformidade,
    sem variante otimizada nestes 2. ExecuteInsert/Update/Delete passam a
    chamar InsertSQL(True)/UpdateSQL(True)/DeleteSQL(True) + WhereByPrimaryKey.
  - 1.3.0 (13/07/2026): Onda 4.2 - Status (getter/setter fluente TRowStatus,
    campo FStatus, default dsInactive por zero-init da RTL) - estado de
    operacao por registo (modelo v1.6.1); uses Commons.Database.Types.
  - 1.2.0 (13/07/2026): fix bug AV no Find do EntityManager (Onda 4) - TTable.New(AFields,
    ATableName) usava uma variavel de classe crua para chamadas fluentes que devolvem
    interface (AddField/DatabaseTypes/TableName), causando destruicao prematura do
    objeto (refcount 0->1->0) na primeira chamada e use-after-free/double-free nas
    seguintes - perdia campos (ex.: PK) e corrompia o heap. Corrigido capturando em
    Result (ITable) logo apos o Create e encadeando tudo atraves da interface.
  - 1.1.0 (12/07/2026): absorcao v3 (FASE 5 Onda 5.1) - uses
    Providers.Connection.Interfaces -> Connections.Interfaces; header v3.
  - 1.0.9 (07/04/2026): Compatibilidade FPC: MODE DELPHI adicionado antes da seção interface.
  - 1.0.0 (03/02/2026): Versão inicial.
  - 1.0.1 (22/02/2026): TTable(TFields) implementando ITable; TableName, Alias, GenerateInsertSQL, GenerateUpdateSQL, GenerateWhereByPrimaryKey.
  - 1.0.2 (26/02/2026): DML ExecuteInsert/ExecuteUpdate/ExecuteDelete; DDL GetSQLCreateTable, GetSQLDropTable, CreateTable, DropTable (Fase 1).
  - 1.0.3 (26/02/2026): NewForDDL e NewForDML na unit responsavel (retornar DDL/DML da tabela).
  - 1.0.4 (26/02/2026): GetSQLCreateTable/GetSQLDropTable(ASchema): DDL formatado como na imagem (identificadores entre aspas, schema, CONSTRAINT, FK, ON DELETE/UPDATE NO ACTION, ALTER OWNER).
  - 1.0.5 (26/02/2026): Firebird: nao gerar token NULL em colunas (nullable por padrao); evita SQL Error -104 Invalid token.
  - 1.0.6 (26/02/2026): DDL/DML para todos os tipos de banco: QuoteIdent (PostgreSQL/Firebird/SQLite ", MySQL `, SQL Server/Access []), QualifiedTableName, UseExplicitNullInDDL, UseDropTableIfExists; CREATE/DROP e INSERT/UPDATE/DELETE com identificadores por engine.
  - 1.0.7 (28/02/2026): GetSQLCreateTable: ReferencedTable no formato schema.tabela (ev.pessoa) passa a ser emitido como "schema"."tabela".
  - 1.0.8 (27/02/2026): GetSQLCreateTable: OnUpdateRule/OnDeleteRule por campo em vez de NO ACTION fixo (assimilação DatabaseORM).
  ============================================================================= }

unit Database.Table;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}
interface

{$I ORM.Defines.inc}

uses
{$IF DEFINED(FPC)}
  SysUtils, Classes, Variants, DateUtils, fpjson, jsonparser,
{$ELSE}
  System.SysUtils, System.Classes, System.Variants, System.DateUtils, System.JSON,
{$ENDIF}
  Commons.Types,
  Commons.Database.Types,
  Databases.Interfaces,
  Database.Fields,
  Connections.Interfaces,
  Exceptions.Database;

type
  TTable = class(TFields, ITable)
  private
    FTableName: string;
    FLogicalName: string;
    FAlias: string;
    FAuditFields: Boolean;
    FFieldDateCreated: string;
    FFieldDateUpdated: string;
    FFieldIsDeleted: string;
    FFieldIsActive: string;
    FStatus: TRowStatus;
    FConnection: IConnection;
    FReadOnly: Boolean;
    FOnValidate: TOnTableValidate;
    { Onda S2-b1 (ADITIVO, cobertura de serializacao UNIQUE/INDEX) - MODELO em
      memoria das constraints UNIQUE nomeadas/compostas e dos INDEXES (nome +
      colunas [+ unique]) definidos ao nivel da tabela. Ate esta onda so
      existiam operacoes IMPERATIVAS (AddUnique/AddIndex, "Onda D" - executam
      DDL contra uma IConnection e sao idempotentes via ICatalogReader) sem
      NENHUM contentor que guardasse a definicao em si - impossivel de
      serializar (o par UniqueNames/IndexNames tambem NAO serve: introspeccao
      do banco VIVO via TCatalogReader, exige IConnection, nao e o MODELO
      desejado). Reusa os records TSchemaUnique/TSchemaIndex
      (Commons.Database.Types, "dado puro" ja existente, usado pelo
      SchemaSync/ISchemaTable para o MESMO formato nome+colunas[+unique]) em
      vez de criar um tipo paralelo (regra #14 anti-duplicacao) - o tipo
      TSchemaUniques/TSchemaIndexes ja chega desta unit via Commons.Database.
      Types (uses ja existente). Populado exclusivamente por
      TableStructureFromJSON (Clear+reconstroi tudo)/TableStructureMergeFromJSON
      (patch aditivo por nome, nunca remove) e lido por StructureToJSON - esta
      onda cobre SO o round-trip de estrutura (sem API fluente nova de
      construcao em memoria, fora do escopo; sem materializacao no banco,
      Onda S3b). }
    FUniques: TSchemaUniques;
    FIndexes: TSchemaIndexes;
    function QuoteIdent(const AName: string): string;
    function QualifiedTableName(const ASchema: string): string;
    function UseExplicitNullInDDL: Boolean;
    function UseDropTableIfExists: Boolean;
    { Sub-passo 4.5 (guardas de Execute, privados - nao expostos por ITable) }
    procedure EnsureNotReadOnly;
    procedure EnsurePrimaryKeyPresent(const AOperation: string);
    { Onda 6-e Estagio 4 (A4) - dispara FOnValidate (se configurado) logo apos
      ValidateFields passar, so nos ramos INSERT/UPDATE de Execute; no-op sem
      hook configurado. }
    procedure RunCustomValidation;
    { Fatia B-b (Onda 4-cont) - implementacoes concretas de FromJSON/
      StructureFromJSON com nome DISTINTO do herdado de IFields (retorno
      ITable em vez de IFields; Object Pascal nao permite 2 metodos com o
      MESMO nome e MESMOS parametros diferindo so no retorno) - vinculadas
      ao slot ITable.FromJSON/ITable.StructureFromJSON via clausula de
      resolucao de interface na secao public (ver "function ITable.FromJSON
      = TableFromJSON;" abaixo). }
    function TableFromJSON(const AJSON: string): ITable;
    function TableStructureFromJSON(const AJSON: string): ITable;
    { Onda S2-a (fix cross-compiler, FPC) - TTable.MergeFromJSON (Fatia B-b,
      ja existente) precisou de passar pela MESMA tecnica de nome distinto +
      clausula de resolucao: ao acrescentar IFields.MergeFromJSON (Onda
      S2-a, TFields), o metodo publico "MergeFromJSON: ITable" ja declarado
      nesta classe passou a ESCONDER (por nome) o slot herdado
      TFields.MergeFromJSON: IFields para efeitos de resolucao de interface
      - dcc32 tolerou, mas o fpc32 (mais estrito) acusou "No matching
      implementation for interface method MergeFromJSON(...):IFields":
      Database.Table.pas, confirmado por compilacao real (onda S2-a). Fix:
      renomear para TableMergeFromJSON + vincular via clausula (mesmo padrao
      de TableFromJSON/TableStructureFromJSON) - IFields.MergeFromJSON volta
      a resolver para o herdado de TFields sem ambiguidade. }
    function TableMergeFromJSON(const AJSON: string): ITable;
    { Onda S2-a (ADITIVO) - implementacao concreta de StructureMergeFromJSON
      com nome DISTINTO do herdado de IFields (retorno ITable em vez de
      IFields), vinculada ao slot ITable.StructureMergeFromJSON via clausula
      de resolucao de interface na seccao public (mesma tecnica de
      TableFromJSON/TableStructureFromJSON, acima). }
    function TableStructureMergeFromJSON(const AJSON: string): ITable;
    { Onda S4 (ADITIVO) - implementacoes concretas de FromFullJSON/
      MergeFullFromJSON/Import com nome DISTINTO do herdado de IFields
      (retorno ITable em vez de IFields) - vinculadas aos slots
      ITable.FromFullJSON/MergeFullFromJSON/Import via clausula de resolucao
      de interface na seccao public (mesma tecnica de TableFromJSON, acima).
      Chamam DIRECTAMENTE os metodos "Table*" irmaos (nao-virtuais, sem
      indirecao por interface) para compor estrutura+dado, ver corpos. }
    function TableFromFullJSON(const AJSON: string): ITable;
    function TableMergeFullFromJSON(const AJSON: string): ITable;
    function TableImport(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): ITable;
{$IFDEF USE_DATABASE}
    { Introspeccao ao nivel da propria ITable: cada helper DELEGA ao motor de
      catalogo centralizado TCatalogReader (SSOT, regra #14 - ver os corpos
      abaixo, ~1708-1836, e :393), com uma IConnection explicita (a propria
      Connection desta ITable ou a AConnection que executa o DDL). Robustos:
      degradam a []/False/True em falha. NOTA: o que foi dissolvido/extinto do
      publico foi o IMetadata, NAO o ICatalogReader (que e o SSOT vivo). }
    function CatStructure(const AConn: IConnection; const ATable: string): TArray<TDatabaseFields>;
    function CatColumnExists(const AConn: IConnection; const ATable, AColumn: string): Boolean;
    function CatPrimaryKeyExists(const AConn: IConnection; const ATable: string): Boolean;
    function CatForeignKeyExists(const AConn: IConnection; const ATable, AName: string): Boolean;
    function CatUniqueExists(const AConn: IConnection; const ATable, AName: string): Boolean;
    function CatIndexExists(const AConn: IConnection; const ATable, AName: string): Boolean;
{$ENDIF}
  public
    class function New(const AFields: IFields; const ATableName: string): ITable; overload;
    class function New: ITable; overload;
    { Retorna ITable configurada para gerar/executar DDL (Create/Drop) ou DML (Insert/Update/Delete). }
    class function NewForDDL(ADatabaseType: TDatabaseTypes): ITable;
    class function NewForDML(ADatabaseType: TDatabaseTypes): ITable;

    function TableName(const AValue: string): ITable; overload;
    function TableName: string; overload;
    function LogicalName(const AValue: string): ITable; overload;
    function LogicalName: string; overload;
    function PhysicalColumn(const AName: string): string;
    function Alias(const AValue: string): ITable; overload;
    function Alias: string; overload;
    function Connection(const AConnection: IConnection): ITable; overload;
    function Connection: IConnection; overload;

    function InsertSQL(const Optimized: Boolean = True): string;
    function UpdateSQL(const Optimized: Boolean = True): string;
    { parametro por uniformidade; sem efeito - nao ha variante otimizada }
    function WhereByPrimaryKey(const Optimized: Boolean = True): string;
    { parametro por uniformidade; sem efeito - nao ha variante otimizada }
    function DeleteSQL(const Optimized: Boolean = True): string;

    function ExecuteInsert(const AConnection: IConnection): Integer;
    function ExecuteUpdate(const AConnection: IConnection): Integer;
    function ExecuteDelete(const AConnection: IConnection): Integer;
    function Execute(const AConnection: IConnection): Integer; overload;
    function Execute: Integer; overload;

    { Guarda de seguranca: bloqueia UPDATE/DELETE sem clausula WHERE antes de executar
      (protecao contra afetar a tabela inteira). Nao valida INSERT/SELECT/DDL. }
    class procedure EnsureSafeDML(const ASQL: string);

    function CreateTableSQL(const ASchema: string = ''): string;
    function DropTableSQL(const ASchema: string = ''): string;
    function CreateTable(const AConnection: IConnection): Integer;
    function DropTable(const AConnection: IConnection): Integer;
    { Onda D - manipulacao imperativa de CAMPO (faceta IDialect.Field + idempotencia ICatalogReader). }
    function AddFieldSQL(const AName, AFieldType: string; const ANotNull: Boolean = False): string;
    function DropFieldSQL(const AName: string): string;
    function AlterFieldSQL(const AName, ANewType: string; const ANotNull: Boolean = False): string;
    function RenameFieldSQL(const AOldName, ANewName: string): string;
    function AddField(const AConnection: IConnection; const AName, AFieldType: string; const ANotNull: Boolean = False): Integer; overload;
    function DropField(const AConnection: IConnection; const AName: string): Integer;
    function AlterField(const AConnection: IConnection; const AName, ANewType: string; const ANotNull: Boolean = False): Integer;
    function RenameField(const AConnection: IConnection; const AOldName, ANewName: string): Integer;
    { Onda D - constraints (index/unique/PK/FK) na estrutura viva. }
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

    { Onda S3b (ADITIVO) - getters read-only do MODELO FUniques/FIndexes
      (ver comentario completo em Databases.Interfaces.ITable.Uniques/
      Indexes). }
    function Uniques: TSchemaUniques;
    function Indexes: TSchemaIndexes;

    { Onda S3 - eixo SQL (ver comentario completo em Databases.Interfaces.ITable). }
    function ToDDL: string;
    function ToSQL: string;

    function ValidateNotNullFields: Boolean;
    function ValidateFields(out AErrors: TFieldValidationErrors): Boolean;

    function HasChanges: Boolean;
    function GetChangedFieldNames: TStringArray;

    function Status: TRowStatus; overload;
    function Status(const AValue: TRowStatus): ITable; overload;

    function ReadOnly(const AValue: Boolean): ITable; overload;
    function ReadOnly: Boolean; overload;

    { Onda 6-e Estagio 4 (A4) - hook de validacao CUSTOMIZADA (padrao fluente
      identico a ReadOnly); ver comentario completo em
      Databases.Interfaces.ITable.OnValidate / TOnTableValidate. }
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
      ICatalogReader) - ver comentario completo em Databases.Interfaces.ITable. }
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

    { Serialize PROPRIA da Table (Fatia B-b) - ver comentario completo em
      Database.Table.Interfaces.ITable. ToJSON/StructureToJSON tem a MESMA
      assinatura (string) do herdado de IFields - sobrepostos por simples
      reintroducao de nome (mesmo padrao ja usado por HasChanges, acima).
      FromJSON/StructureFromJSON precisam de retorno ITable (covariante) -
      resolvidos via clausula de resolucao de interface para as
      implementacoes de nome distinto TableFromJSON/TableStructureFromJSON
      (declaradas na secao private). }
    function ToJSON: string;
    function StructureToJSON: string;
    function ITable.FromJSON = TableFromJSON;
    function ITable.MergeFromJSON = TableMergeFromJSON;
    function ITable.StructureFromJSON = TableStructureFromJSON;
    function ITable.StructureMergeFromJSON = TableStructureMergeFromJSON;

    { Onda S4 (ADITIVO) - eixo FULL - ver comentario completo em
      Databases.Interfaces.ITable. ToFullJSON tem a MESMA assinatura
      (string) do herdado de IFields - sobreposto por simples reintroducao
      de nome (mesmo padrao de ToJSON/StructureToJSON, acima).
      FromFullJSON/MergeFullFromJSON precisam de retorno ITable (covariante) -
      resolvidos via clausula de resolucao de interface para as
      implementacoes de nome distinto declaradas na seccao private. }
    function ToFullJSON: string;
    function ITable.FromFullJSON = TableFromFullJSON;
    function ITable.MergeFullFromJSON = TableMergeFullFromJSON;

    { Export/Import ergonomicos (Onda S4, ADITIVO) - ver comentario completo
      em Databases.Interfaces.ITable.Export/Import. Export(AWithData) e
      Export(AWithData, AQuery) tem a MESMA assinatura (string) do herdado de
      IFields.Export - sobrepostos por simples reintroducao de nome +
      overload; Import precisa de retorno ITable (covariante), resolvido
      via clausula de resolucao de interface para TableImport (seccao
      private). }
    function Export(const AWithData: Boolean): string; overload;
{$IFDEF USE_DATABASE}
    function Export(const AWithData: Boolean; const AQuery: IQueryBuilder): string; overload;
{$ENDIF}
    function ITable.Import = TableImport;

    { Onda 7 - camada de lancadores fluentes (ver comentario completo em
      Databases.Interfaces.ITable). }
{$IFDEF USE_DATABASE}
    function QueryBuilder: IQueryBuilder;
{$ENDIF}
{$IFDEF USE_ENTITY_MANAGER}
    function EntityManager: IEntityManager;
{$ENDIF}
    function UnitOfWork: IUnitOfWork;
  end;

implementation

uses
  Database.Field,
  Database.Helpers.JSON
{$IFDEF USE_DATABASE}
  , Database.QueryBuilder
  , Database.Dialect          // Onda D - faceta IDialect.Field + TDialect.ForConnection
  , Database.CatalogReader    // motor de catalogo centralizado (SSOT) - delegacao da introspeccao
  { Onda S4 - Export(AWithData, AQuery) delega a TryExportQueryData
    (Database.Helpers.Export) - NAO importa Data.DB/DB directamente nesta
    unit: TRowStatus (Commons.Database.Types, usado por FStatus/Status/
    Execute acima) colide POR NOME com Data.DB.TDataSetState (dsInactive/
    dsInsert/dsEdit em ambos) - confirmado por compilacao real (E2010
    Incompatible types nos `case FStatus of dsInsert: dsEdit: ...` ja
    existentes, onda S4). TryExportQueryData isola o unico ponto que precisa
    de Data.DB/Serialize numa unit PROPRIA sem TRowStatus - zero colisao. }
  , Database.Helpers.Export
{$ENDIF}
  , Database.UnitOfWork;

{ Helpers de serializacao JSON (Fatia B-b, Onda 4-cont) - RFC 8259, NUNCA
  QuotedStr (bug-293). Onda C5 (M7, conformidade F5): TableJSONQuoteString
  local removida; delega ao SSOT unico Database.Helpers.JSON.JSONQuoteString
  (regra #14). }

function TableJSONBoolLiteral(const AValue: Boolean): string;
begin
  if AValue then
    Result := 'true'
  else
    Result := 'false';
end;

{ Onda S2-b1 (ADITIVO) - codificacao/descodificacao do array de nomes de
  coluna (TSchemaColumnNames, Commons.Database.Types) de/para JSON, reusado
  pelas novas chaves "uniques"/"indexes" de StructureToJSON/
  StructureFromJSON/StructureMergeFromJSON. Encode e generico (so produz
  texto, sem depender da API de JSON do compilador); decode e duplicado por
  compilador (mesmo padrao de TableJSONNodeToVariant, acima - fpjson
  TJSONData vs System.JSON TJSONValue). }
function TableSchemaColumnsToJSON(const AColumns: TSchemaColumnNames): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AColumns) do
  begin
    if Result <> '' then
      Result := Result + ',';
    Result := Result + JSONQuoteString(AColumns[I]);
  end;
end;

{$IF DEFINED(FPC)}
function TableSchemaColumnsFromJSON(ANode: TJSONData): TSchemaColumnNames;
var
  LArr: TJSONArray;
  I: Integer;
begin
  Result := nil;
  if (not Assigned(ANode)) or (not (ANode is TJSONArray)) then
    Exit;
  LArr := TJSONArray(ANode);
  SetLength(Result, LArr.Count);
  for I := 0 to LArr.Count - 1 do
    Result[I] := LArr.Items[I].AsString;
end;
{$ELSE}
function TableSchemaColumnsFromJSON(ANode: TJSONValue): TSchemaColumnNames;
var
  LArr: TJSONArray;
  I: Integer;
begin
  Result := nil;
  if (not Assigned(ANode)) or (not (ANode is TJSONArray)) then
    Exit;
  LArr := TJSONArray(ANode);
  SetLength(Result, LArr.Count);
  for I := 0 to LArr.Count - 1 do
    Result[I] := LArr.Items[I].Value;
end;
{$ENDIF}

{ Busca por NOME (case-insensitive, mesmo criterio de TFields.IndexOfField) em
  FUniques/FIndexes - usada pelo patch aditivo de TableStructureMergeFromJSON
  (substitui Columns[/Unique] no lugar quando ja existe um elemento com o
  mesmo nome; -1 sinaliza ao chamador para acrescentar um elemento novo). }
function TableIndexOfUnique(const AUniques: TSchemaUniques; const AName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(AUniques) do
    if CompareText(AUniques[I].Name, AName) = 0 then
      Exit(I);
end;

function TableIndexOfIndex(const AIndexes: TSchemaIndexes; const AName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(AIndexes) do
    if CompareText(AIndexes[I].Name, AName) = 0 then
      Exit(I);
end;

{ object_state <-> TRowStatus (modelo v1.6.1: dsInactive/dsInsert/dsEdit/dsDeleted). }
function RowStatusToObjectState(const AStatus: TRowStatus): string;
begin
  case AStatus of
    dsInsert:  Result := 'INSERTED';
    dsEdit:    Result := 'MODIFIED';
    dsDeleted: Result := 'DELETED';
  else
    Result := 'UNMODIFIED'; // dsInactive
  end;
end;

function ObjectStateToRowStatus(const AState: string): TRowStatus;
begin
  if CompareText(AState, 'INSERTED') = 0 then
    Result := dsInsert
  else if CompareText(AState, 'MODIFIED') = 0 then
    Result := dsEdit
  else if CompareText(AState, 'DELETED') = 0 then
    Result := dsDeleted
  else
    Result := dsInactive;
end;

{ "sem valor" (Fatia B-b) - mesmo criterio ja usado por TTable.InsertSQL
  (Optimized)/ValidateNotNullFields (VarToStr(Value) = ''), somado a
  VarIsNull/VarIsEmpty explicitos - determina quando o eixo dado emite JSON
  null. }
function TableFieldHasNoValue(const AField: IField): Boolean;
var
  LValue: Variant;
begin
  LValue := AField.Value;
  Result := VarIsNull(LValue) or VarIsEmpty(LValue) or (VarToStr(LValue) = '');
end;

function TableColumnTypeIsAnyOf(const AColumnType: string; const AKeywords: array of string): Boolean;
var
  LUpper: string;
  I: Integer;
begin
  Result := False;
  LUpper := UpperCase(AColumnType);
  for I := Low(AKeywords) to High(AKeywords) do
    if Pos(AKeywords[I], LUpper) > 0 then
    begin
      Result := True;
      Exit;
    end;
end;

function TableValueLooksTrue(const AValue: Variant): Boolean;
var
  LStr: string;
begin
  if (VarType(AValue) and varTypeMask) = varBoolean then
    Result := Boolean(AValue)
  else
  begin
    LStr := Trim(VarToStr(AValue));
    Result := (LStr = '1') or (CompareText(LStr, 'TRUE') = 0) or
      (CompareText(LStr, 'T') = 0) or (CompareText(LStr, 'YES') = 0);
  end;
end;

{ Converte o valor corrente de um IField para o literal JSON do EIXO DADO da
  Table, tipado por ColumnType (case-insensitive) - diferente de
  IField.ToJSON (que so olha o VarType do Variant, sem ColumnType). Mapa:
  int/serial -> inteiro; num/dec/float/double/real/money/currency -> decimal
  (normaliza "," -> "."); bool/bit/logical -> true/false; date/time/timestamp
  -> string ISO8601 LOCAL (UTC opt-in=False); resto -> string escapada;
  IsNull/vazio -> null. }
function TableFieldValueToJSONLiteral(const AField: IField): string;
begin
  if TableFieldHasNoValue(AField) then
    Exit('null');
  if TableColumnTypeIsAnyOf(AField.ColumnType, ['INT', 'SERIAL']) then
    Result := Trim(VarToStr(AField.Value))
  else if TableColumnTypeIsAnyOf(AField.ColumnType, ['NUM', 'DEC', 'FLOAT', 'DOUBLE', 'REAL', 'MONEY', 'CURRENCY']) then
    Result := StringReplace(Trim(VarToStr(AField.Value)), ',', '.', [rfReplaceAll])
  else if TableColumnTypeIsAnyOf(AField.ColumnType, ['BOOL', 'BIT', 'LOGICAL']) then
    Result := TableJSONBoolLiteral(TableValueLooksTrue(AField.Value))
  else if TableColumnTypeIsAnyOf(AField.ColumnType, ['DATE', 'TIME', 'TIMESTAMP']) then
    Result := JSONQuoteString(DateToISO8601(VarToDateTime(AField.Value), False))
  else
    Result := JSONQuoteString(VarToStr(AField.Value));
end;

{ Converte o node JSON (ja localizado no objecto) de volta a Variant. Numero
  com fracao 0 -> Int64 (preserva o round-trip de inteiros); numero com fracao
  -> Double; boolean/string/null tratados directamente. Implementacao
  duplicada por compilador (mesmo padrao de Database.Field.pas.JSONNodeToVariant). }
{$IF DEFINED(FPC)}
function TableJSONNodeToVariant(ANode: TJSONData): Variant;
var
  LFloat: Double;
begin
  if (not Assigned(ANode)) or (ANode.JSONType = jtNull) then
    Result := Null
  else
    case ANode.JSONType of
      jtBoolean:
        Result := ANode.AsBoolean;
      jtNumber:
        begin
          LFloat := ANode.AsFloat;
          if Frac(LFloat) = 0 then
            Result := ANode.AsInt64
          else
            Result := LFloat;
        end;
    else
      Result := ANode.AsString;
    end;
end;
{$ELSE}
function TableJSONNodeToVariant(ANode: TJSONValue): Variant;
var
  LFloat: Double;
  LBool: Boolean;
begin
  if (not Assigned(ANode)) or (ANode is TJSONNull) then
    Result := Null
  else if ANode is TJSONNumber then
  begin
    LFloat := TJSONNumber(ANode).AsDouble;
    if Frac(LFloat) = 0 then
      Result := TJSONNumber(ANode).AsInt64
    else
      Result := LFloat;
  end
  else if ANode.TryGetValue<Boolean>(LBool) then
    Result := LBool
  else if ANode is TJSONString then
    Result := TJSONString(ANode).Value
  else
    Result := ANode.Value;
end;
{$ENDIF}

{ Sub-passo 4.5 - monta a mensagem de EDatabaseValidationException a partir do
  detalhe devolvido por ValidateFields (lista os nomes das colunas em falta,
  separados por virgula). }
function TableBuildValidationMessage(const AErrors: TFieldValidationErrors): string;
var
  I: Integer;
  LNames: string;
begin
  LNames := '';
  for I := 0 to High(AErrors) do
  begin
    if LNames <> '' then
      LNames := LNames + ', ';
    LNames := LNames + AErrors[I].Field;
  end;
  Result := 'Validacao falhou: campo(s) obrigatorio(s) sem valor: ' + LNames + '.';
end;

{ Onda 6-e Estagio 4 (A4) - monta a mensagem de EDatabaseValidationException a
  partir do detalhe (opcional) devolvido pelo hook FOnValidate; sem detalhe
  (AErrors vazio - o hook so devolveu False) usa uma mensagem generica; com
  detalhe, lista "Field: Message" por erro (ao contrario de
  TableBuildValidationMessage, que so lista nomes de campo - aqui a Message e
  do CALLER, pode nao ser sobre um campo obrigatorio). }
function TableBuildCustomValidationMessage(const AErrors: TFieldValidationErrors): string;
var
  I: Integer;
  LParts: string;
begin
  if Length(AErrors) = 0 then
    Exit('Validacao (OnValidate) falhou: operacao rejeitada pela regra de validacao customizada.');
  LParts := '';
  for I := 0 to High(AErrors) do
  begin
    if LParts <> '' then
      LParts := LParts + '; ';
    if AErrors[I].Message <> '' then
      LParts := LParts + AErrors[I].Field + ': ' + AErrors[I].Message
    else
      LParts := LParts + AErrors[I].Field;
  end;
  Result := 'Validacao (OnValidate) falhou: ' + LParts + '.';
end;

function TTable.TableName(const AValue: string): ITable;
begin
  FTableName := AValue;
  Result := Self;
end;

function TTable.TableName: string;
begin
  Result := FTableName;
end;

function TTable.LogicalName(const AValue: string): ITable;
begin
  FLogicalName := AValue;
  Result := Self;
end;

function TTable.LogicalName: string;
begin
  Result := FLogicalName;
end;

function TTable.PhysicalColumn(const AName: string): string;
var
  LArr: TFieldArray;
  I: Integer;
  LWanted: string;
begin
  { Onda 6-b I7 - resolucao nome logico -> nome fisico: percorre os campos da
    tabela (mesmo acesso GetFieldsList usado pelos outros geradores/
    validadores desta unit); o primeiro campo cujo LogicalName (apos Trim,
    case-insensitive via SameText) coincida com AName devolve o seu Column
    (nome fisico). Sem match -> fallback ao proprio AName (equivalente a usar
    o nome dado directamente, comportamento pre-existente). }
  Result := AName;
  LWanted := Trim(AName);
  if LWanted = '' then
    Exit;
  LArr := GetFieldsList;
  for I := 0 to High(LArr) do
    if SameText(Trim(LArr[I].LogicalName), LWanted) then
    begin
      Result := LArr[I].Column;
      Exit;
    end;
end;

function TTable.Alias(const AValue: string): ITable;
begin
  FAlias := AValue;
  Result := Self;
end;

function TTable.Alias: string;
begin
  Result := FAlias;
end;

function TTable.Connection(const AConnection: IConnection): ITable;
begin
  { Fatia A (continuacao Onda 4) - conexao fluente, usada como fallback pelo
    Execute quando nenhuma IConnection e passada por parametro. }
  FConnection := AConnection;
  Result := Self;
end;

function TTable.Connection: IConnection;
begin
  Result := FConnection;
end;

function TTable.InsertSQL(const Optimized: Boolean): string;
var
  i: Integer;
  LCols, LVals: string;
  LArr: TFieldArray;
  LField: IField;
  LAuditField: IField;
begin
  { Fusao (13/07/2026) de GenerateInsertSQL (Optimized=False, todas as
    colunas) + GenerateInsertSQLOptimized (Optimized=True, salta colunas NOT
    NULL com valor vazio). O separador ',' usa LCols<>'' em vez de i>0 para
    funcionar identicamente nos 2 modos (no modo nao-optimized nenhuma coluna
    e saltada, pelo que o resultado e o mesmo de usar i>0). }
  { Auditoria - carimbo automatico (sub-passo 4.4, Onda 4-cont): quando
    FieldDateCreated/FieldIsActive estao configurados (nome de coluna nao
    vazio) E a coluna existe na tabela, carimba a data/hora corrente (Object
    Pascal Now, formatada 'yyyy-mm-dd hh:nn:ss' - literal portavel entre
    engines, nunca uma expressao SQL tipo NOW()/CURRENT_TIMESTAMP/GETDATE())
    em FieldDateCreated e 1 em FieldIsActive, ANTES de montar o INSERT - os 2
    campos passam pelo MESMO pipeline (SetColumnValue) de qualquer outro
    campo, entrando no INSERT como qualquer valor bindado ao campo (QuoteIdent
    + QuotedStr(VarToStr(Value))). Sem FieldDateCreated/FieldIsActive
    configurados (ou coluna inexistente) -> comportamento inalterado
    (aditivo). }
  if Trim(FFieldDateCreated) <> '' then
  begin
    LAuditField := GetFields(FFieldDateCreated);
    if LAuditField <> nil then
      LAuditField.SetColumnValue(FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
  end;
  if Trim(FFieldIsActive) <> '' then
  begin
    LAuditField := GetFields(FFieldIsActive);
    if LAuditField <> nil then
      LAuditField.SetColumnValue(1);
  end;
  LArr := GetFieldsList;
  LCols := '';
  LVals := '';
  for i := 0 to Length(LArr) - 1 do
  begin
    LField := LArr[i];
    if Optimized and not LField.FieldAllowsNull and (VarToStr(LField.Value) = '') then
      Continue;
    if LCols <> '' then begin LCols := LCols + ','; LVals := LVals + ','; end;
    LCols := LCols + QuoteIdent(LField.Column);
    LVals := LVals + QuotedStr(VarToStr(LField.Value));
  end;
  if (FTableName = '') or (Optimized and (LCols = '')) then
    Result := ''
  else
    Result := 'INSERT INTO ' + QuoteIdent(FTableName) + ' (' + LCols + ') VALUES (' + LVals + ')';
end;

function TTable.UpdateSQL(const Optimized: Boolean): string;
var
  i: Integer;
  LSet: string;
  LArr: TFieldArray;
  LAuditField: IField;
begin
  { Fusao (13/07/2026) de GenerateUpdateSQL (Optimized=False, SET de todas as
    colunas) + GenerateUpdateSQLOptimized (Optimized=True, SET so das colunas
    IsChanged). SEM WHERE embutido (design composable ja existente - Onda 3);
    o caller compoe '+ WhereByPrimaryKey'. }
  { Auditoria - carimbo automatico (sub-passo 4.4, Onda 4-cont): quando
    FieldDateUpdated esta configurado E a coluna existe na tabela, carimba a
    data/hora corrente ANTES de montar o SET - o SetColumnValue marca o campo
    IsChanged=True (o novo carimbo quase sempre difere do valor original
    carregado), garantindo que entra no SET mesmo em modo Optimized=True
    (dinamico, so campos IsChanged). Sem FieldDateUpdated configurado (ou
    coluna inexistente) -> comportamento inalterado (aditivo). }
  if Trim(FFieldDateUpdated) <> '' then
  begin
    LAuditField := GetFields(FFieldDateUpdated);
    if LAuditField <> nil then
      LAuditField.SetColumnValue(FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
  end;
  LArr := GetFieldsList;
  LSet := '';
  for i := 0 to Length(LArr) - 1 do
  begin
    if Optimized and not LArr[i].IsChanged then
      Continue;
    if LSet <> '' then LSet := LSet + ',';
    LSet := LSet + QuoteIdent(LArr[i].Column) + '=' + QuotedStr(VarToStr(LArr[i].Value));
  end;
  if (FTableName = '') or (LSet = '') then
    Result := ''
  else
    Result := 'UPDATE ' + QuoteIdent(FTableName) + ' SET ' + LSet;
end;

function TTable.WhereByPrimaryKey(const Optimized: Boolean): string;
var
  LArr : TFieldArray;
  i    : Integer;
  LCond: string;
begin
  { parametro por uniformidade; sem efeito - nao ha variante otimizada }

  { bug-1170 (01/09/2026) - CHAVE PRIMARIA COMPOSTA.
    A versao anterior resolvia GetPrimaryKey (SINGULAR) e gerava
    'WHERE <1a coluna da PK>=<valor>'. Numa tabela de PK COMPOSTA isso faz
    o UPDATE/DELETE atingir TODAS as linhas irmas (as que partilham a 1a
    coluna) - PERDA DE DADOS SILENCIOSA, sem excecao e sem aviso.
    Apanhado no catalogo `messages` (PK code+language): semear o idioma
    `en` de um codigo apagava o `pt-BR` do MESMO codigo.
    O DDL desta mesma unit (GetSQLCreateTable) ja compunha a PRIMARY KEY
    composta correctamente - era so o DML que ficara por acompanhar.
    Em tabela de PK SIMPLES o SQL gerado e IDENTICO ao anterior, logo nao
    ha mudanca de comportamento nesse caso. }
  Result := '';
  LCond  := '';
  LArr   := GetFieldsList;
  for i := 0 to High(LArr) do
    if LArr[i].IsPKey then
    begin
      if LCond <> '' then
        LCond := LCond + ' AND ';
      LCond := LCond + QuoteIdent(LArr[i].Column) + '=' +
        QuotedStr(VarToStr(LArr[i].Value));
    end;
  if LCond <> '' then
    Result := 'WHERE ' + LCond;
end;

function TTable.DeleteSQL(const Optimized: Boolean): string;
var
  LDeletedField, LUpdatedField: IField;
  LSet: string;
begin
  { parametro por uniformidade; sem efeito - nao ha variante otimizada.
    Soft delete (sub-passo 4.4, Onda 4-cont): quando FieldIsDeleted esta
    configurado (nome de coluna nao vazio) E a coluna existe na tabela, gera
    UPDATE SET "<FieldIsDeleted>"=1 [, "<FieldDateUpdated>"=<now>] em vez de
    DELETE FROM fisico - design composable preservado (SEM WHERE embutido; o
    caller [ExecuteDelete] compoe '+ WhereByPrimaryKey', identico ao caminho
    fisico), e a guarda EnsureSafeDML continua a aplicar-se (deteta o prefixo
    'UPDATE ' e exige WHERE, igual a qualquer outro UPDATE). Os 2 campos
    passam pelo MESMO pipeline (SetColumnValue) + QuoteIdent/QuotedStr de
    qualquer outro campo. Sem FieldIsDeleted configurado (ou coluna
    inexistente na tabela) -> comportamento fisico inalterado (aditivo). }
  Result := '';
  if FTableName = '' then
    Exit;
  LDeletedField := nil;
  if Trim(FFieldIsDeleted) <> '' then
    LDeletedField := GetFields(FFieldIsDeleted);
  if LDeletedField = nil then
  begin
    Result := 'DELETE FROM ' + QuoteIdent(FTableName);
    Exit;
  end;
  LDeletedField.SetColumnValue(1);
  LSet := QuoteIdent(LDeletedField.Column) + '=' + QuotedStr(VarToStr(LDeletedField.Value));
  if Trim(FFieldDateUpdated) <> '' then
  begin
    LUpdatedField := GetFields(FFieldDateUpdated);
    if LUpdatedField <> nil then
    begin
      LUpdatedField.SetColumnValue(FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
      LSet := LSet + ',' + QuoteIdent(LUpdatedField.Column) + '=' + QuotedStr(VarToStr(LUpdatedField.Value));
    end;
  end;
  Result := 'UPDATE ' + QuoteIdent(FTableName) + ' SET ' + LSet;
end;

class procedure TTable.EnsureSafeDML(const ASQL: string);
var
  LUp: string;
begin
  LUp := UpperCase(TrimLeft(ASQL));
  { So valida comandos destrutivos (UPDATE/DELETE); INSERT/SELECT/DDL passam.
    Heuristica p/ DML gerado internamente por PK: exige a clausula WHERE. }
  if (Copy(LUp, 1, 7) = 'UPDATE ') or (Copy(LUp, 1, 7) = 'DELETE ') then
    if Pos(' WHERE ', ' ' + LUp + ' ') = 0 then
      { A3 (Onda 6-e Estagio 4) - SQLContext=ASQL: o SQL bloqueado fica
        disponivel em E.SQLContext (Exceptions.Database 1.6.0); mensagem/
        ErrorCode inalterados. }
      raise EDatabaseUnsafeDMLException.Create(
        'UPDATE/DELETE sem clausula WHERE bloqueado (protecao contra afetar a tabela inteira).',
        ERR_DATABASE_UNSAFE_DML, ASQL);
end;

procedure TTable.EnsureNotReadOnly;
var
  LDeletedField: IField;
begin
  { Sub-passo 4.5 (continuacao Onda 4, revisao F5) - guarda equivalente ao
    FDeletedBlock v1.6.1: uma tabela marcada ReadOnly(True) OU um registo ja
    soft-deleted nao pode ser editado/gravado via Execute/Save. Chamada logo
    apos resolver a IConnection, ANTES do "case FStatus" - aplica-se a
    QUALQUER operacao (Insert/Edit/Delete/inferido).
    IMPORTANTE: o "ja soft-deleted" testa OriginalValue (a BASELINE - o que
    foi hidratado do banco via SetColumnValueWithoutChange, ex.: EntityManager.
    Find/List), NUNCA Value (o que esta prestes a ser escrito). DeleteSQL
    (Sub-passo 4.4) tem o efeito colateral documentado de chamar
    LDeletedField.SetColumnValue(1) para MONTAR o proprio soft-delete em
    curso - isso muda so Value, nunca OriginalValue (SetColumnValue nao toca
    OriginalValue) - testar Value aqui apanharia o proprio DeleteSQL/
    ExecuteDelete em curso (ou uma inspecao previa de DeleteSQL, como o smoke
    faz) como se o registo ja estivesse soft-deleted ANTES desta operacao,
    bloqueando indevidamente o primeiro soft-delete de uma linha ativa. }
  if FReadOnly then
    raise EDatabaseReadOnlyException.Create(
      'Execute: tabela "' + FTableName + '" esta marcada ReadOnly (guarda equivalente ' +
      'ao FDeletedBlock v1.6.1) - operacao bloqueada.',
      ERR_DATABASE_READONLY);
  if Trim(FFieldIsDeleted) <> '' then
  begin
    LDeletedField := GetFields(FFieldIsDeleted);
    if (LDeletedField <> nil) and TableValueLooksTrue(LDeletedField.OriginalValue) then
      raise EDatabaseReadOnlyException.Create(
        'Execute: registo de "' + FTableName + '" ja esta soft-deleted (coluna "' +
        FFieldIsDeleted + '"=1) - nao pode ser editado/gravado.',
        ERR_DATABASE_READONLY);
  end;
end;

procedure TTable.EnsurePrimaryKeyPresent(const AOperation: string);
var
  LArr   : TFieldArray;
  i      : Integer;
  LTemPk : Boolean;
  LFaltam: string;
  LMsg   : string;
begin
  { Sub-passo 4.5 (continuacao Onda 4, revisao F5) - status invalido:
    dsEdit/dsDeleted exigem chave primaria preenchida para localizar a linha;
    sem ela, WhereByPrimaryKey geraria 'WHERE "pk"=''''' (clausula presente,
    passa a EnsureSafeDML) e o UPDATE/DELETE afetaria 0 linhas SILENCIOSAMENTE
    - esta guarda troca o silencio por uma excecao clara.

    bug-1170 (01/09/2026): a guarda passa a exigir TODAS as colunas da PK
    preenchidas. Antes bastava a 1a estar preenchida para passar, e o WHERE
    saia incompleto - exactamente o caso que apagava linhas irmas. A mensagem
    passa a nomear as colunas em falta. }
  LTemPk  := False;
  LFaltam := '';
  LArr    := GetFieldsList;
  for i := 0 to High(LArr) do
    if LArr[i].IsPKey then
    begin
      LTemPk := True;
      if VarIsNull(LArr[i].Value) or VarIsEmpty(LArr[i].Value) or
         (VarToStr(LArr[i].Value) = '') then
      begin
        if LFaltam <> '' then
          LFaltam := LFaltam + ', ';
        LFaltam := LFaltam + LArr[i].Column;
      end;
    end;

  if (not LTemPk) or (LFaltam <> '') then
  begin
    LMsg := 'Execute: ' + AOperation + ' exige chave primaria preenchida para ' +
      'localizar a linha (tabela "' + FTableName + '"';
    if LFaltam <> '' then
      LMsg := LMsg + '; coluna(s) da PK em falta: ' + LFaltam;
    LMsg := LMsg + ').';
    raise EDatabaseInvalidStatusException.Create(LMsg, ERR_DATABASE_INVALID_STATUS);
  end;
end;

{ Onda 6-e Estagio 4 (A4) - dispara o hook FOnValidate (regra de validacao
  CUSTOMIZADA, ex.: regras de negocio que ValidateFields nao cobre) logo apos
  a validacao embutida (ValidateFields, obrigatorios) ter passado; chamado
  pelos MESMOS 4 pontos de Execute onde ValidateFields ja corre (dsInsert,
  dsEdit, os 2 ramos dsInactive inferidos insert/update) - NUNCA em
  dsDeleted (o guard embutido tambem nunca valida DELETE). O hook devolve
  False (+ AErrors opcional, "Field,Message") para bloquear a operacao;
  Result e ignorado por Execute (RunCustomValidation lanca a excecao, nunca
  devolve False silenciosamente). Sem FOnValidate configurado -> no-op
  (0 chamadas extra, comportamento 100% inalterado). }
procedure TTable.RunCustomValidation;
var
  LErrors: TFieldValidationErrors;
begin
  if not Assigned(FOnValidate) then
    Exit;
  SetLength(LErrors, 0);
  if not FOnValidate(Self, LErrors) then
    raise EDatabaseValidationException.Create(
      TableBuildCustomValidationMessage(LErrors), ERR_DATABASE_VALIDATION);
end;

function TTable.ExecuteInsert(const AConnection: IConnection): Integer;
var
  LSQL: string;
begin
  Result := 0;
  if (AConnection = nil) or not AConnection.IsConnected then
    Exit;
  LSQL := InsertSQL(True);
  if LSQL <> '' then
    Result := AConnection.ExecuteCommand(LSQL);
end;

function TTable.ExecuteUpdate(const AConnection: IConnection): Integer;
var
  LSQL: string;
begin
  Result := 0;
  if (AConnection = nil) or not AConnection.IsConnected then
    Exit;
  LSQL := UpdateSQL(True);
  if LSQL <> '' then
  begin
    LSQL := LSQL + ' ' + WhereByPrimaryKey;
    EnsureSafeDML(LSQL);
    Result := AConnection.ExecuteCommand(LSQL);
  end;
end;

function TTable.ExecuteDelete(const AConnection: IConnection): Integer;
var
  LSQL: string;
begin
  Result := 0;
  if (AConnection = nil) or not AConnection.IsConnected then
    Exit;
  LSQL := DeleteSQL(True);
  if LSQL <> '' then
  begin
    LSQL := LSQL + ' ' + WhereByPrimaryKey;
    EnsureSafeDML(LSQL);
    Result := AConnection.ExecuteCommand(LSQL);
  end;
end;

function TTable.Execute(const AConnection: IConnection): Integer;
var
  LConn: IConnection;
  LPk: IField;
  LErrors: TFieldValidationErrors;
begin
  { Onda 5.x - Ajuste de API (ordem do owner): executa a operacao conforme o
    Status (TRowStatus) do proprio registo, sem depender do EntityManager.
    Fatia A (continuacao Onda 4): AConnection tem prioridade; se nil, cai no
    fallback FConnection (setada via Connection(v)); se nenhuma das duas
    estiver disponivel, lanca EDatabaseException. }
  Result := 0;
  LConn := AConnection;
  if LConn = nil then
    LConn := FConnection;
  if LConn = nil then
    raise EDatabaseException.Create(
      'Execute: sem IConnection (nem parametro nem Connection(v) fluente).',
      ERR_DATABASE_NO_CONNECTION);

  { Sub-passo 4.5 (continuacao Onda 4, revisao F5) - guarda read-only/soft-
    deleted (equivalente ao FDeletedBlock v1.6.1); aplica-se a QUALQUER
    Status (Insert/Edit/Delete/inferido), ANTES de despachar. }
  EnsureNotReadOnly;

  case FStatus of
    dsInsert:
      begin
        if not ValidateFields(LErrors) then
          raise EDatabaseValidationException.Create(TableBuildValidationMessage(LErrors), ERR_DATABASE_VALIDATION);
        RunCustomValidation; // A4 (Onda 6-e Estagio 4) - hook customizado, apos ValidateFields passar
        Result := ExecuteInsert(LConn);
      end;
    dsEdit:
      begin
        { status invalido (Sub-passo 4.5): sem PK preenchida nao ha como
          localizar a linha a atualizar. }
        EnsurePrimaryKeyPresent('UPDATE (Status=dsEdit)');
        if not ValidateFields(LErrors) then
          raise EDatabaseValidationException.Create(TableBuildValidationMessage(LErrors), ERR_DATABASE_VALIDATION);
        RunCustomValidation; // A4 (Onda 6-e Estagio 4)
        Result := ExecuteUpdate(LConn);
      end;
    dsDeleted:
      begin
        { status invalido (Sub-passo 4.5): sem PK preenchida nao ha como
          localizar a linha a apagar. DELETE nunca valida obrigatorios. }
        EnsurePrimaryKeyPresent('DELETE (Status=dsDeleted)');
        Result := ExecuteDelete(LConn);
      end;
  else
    { dsInactive: infere pela PK (sem PK -> insert; com PK -> update). }
    LPk := GetPrimaryKey;
    if (LPk = nil) or VarIsNull(LPk.Value) or VarIsEmpty(LPk.Value) or (VarToStr(LPk.Value) = '') then
    begin
      if not ValidateFields(LErrors) then
        raise EDatabaseValidationException.Create(TableBuildValidationMessage(LErrors), ERR_DATABASE_VALIDATION);
      RunCustomValidation; // A4 (Onda 6-e Estagio 4)
      Result := ExecuteInsert(LConn);
    end
    else
    begin
      if not ValidateFields(LErrors) then
        raise EDatabaseValidationException.Create(TableBuildValidationMessage(LErrors), ERR_DATABASE_VALIDATION);
      RunCustomValidation; // A4 (Onda 6-e Estagio 4)
      Result := ExecuteUpdate(LConn);
    end;
  end;
  if Result > 0 then
    FStatus := dsInactive;  // reset apos executar (modelo v1.6.1)
end;

function TTable.Execute: Integer;
begin
  { Overload sem parametro (Fatia A) - usa exclusivamente a conexao fluente
    (Connection(v)); cai no mesmo fallback/excecao do overload acima. }
  Result := Execute(nil);
end;

function TTable.QuoteIdent(const AName: string): string;
begin
{$IFDEF USE_DATABASE}
  { Onda D (D.4 consolidacao): fonte UNICA de quoting = o dialecto (o MESMO
    primitivo QuoteIdentifier que o QueryBuilder e o Metadata usam - provado por
    banco no smoke_querybuilder). Alimenta tanto o DDL (CreateTableSQL/...) como o
    pipeline DML (INSERT/UPDATE/DELETE). Aqui nunca se passa nome com ponto
    (QualifiedTableName e o FK fazem o split), logo o split-on-'.' interno do
    QuoteIdentifier e inocuo. }
  Result := TDialect.ForDatabaseType(DatabaseTypes).QuoteIdentifier(Trim(AName));
{$ELSE}
  { fallback quando o modulo Database/Dialect nao esta compilado (USE_DATABASE
    off): mapeamento minimo por banco (identico ao do dialecto). }
  case DatabaseTypes of
    dtMySQL:
      Result := '`' + Trim(AName) + '`';
    dtSQLServer, dtAccess:
      Result := '[' + Trim(AName) + ']';
  else
    Result := '"' + Trim(AName) + '"';
  end;
{$ENDIF}
end;

function TTable.QualifiedTableName(const ASchema: string): string;
var
  LSchema: string;
begin
  LSchema := Trim(ASchema);
  if LSchema <> '' then
    Result := QuoteIdent(LSchema) + '.' + QuoteIdent(FTableName)
  else
    Result := QuoteIdent(FTableName);
end;

function TTable.UseExplicitNullInDDL: Boolean;
begin
  Result := DatabaseTypes <> dtFireBird;
end;

function TTable.UseDropTableIfExists: Boolean;
begin
  { dtSQLAnywhere confirmado empiricamente (F5 Onda 10, 16/07, dbisql contra
    servidor real) - 'DROP TABLE IF EXISTS' executa sem erro de sintaxe. }
  Result := DatabaseTypes in [dtPostgreSQL, dtMySQL, dtSQLite, dtSQLServer, dtSQLAnywhere];
end;

function TTable.CreateTableSQL(const ASchema: string): string;
var
  i: Integer;
  LPos: Integer;
  LArr: TFieldArray;
  LQualName: string;
  LCols: string;
  LPkCols: string;
  LFk: string;
  LConstraintName: string;
  LRefTable: string;
  LOnDelete: string;
  LOnUpdate: string;
begin
  Result := '';
  if FTableName = '' then
    Exit;
  LArr := GetFieldsList;
  LQualName := QualifiedTableName(ASchema);
  LCols := '';
  for i := 0 to High(LArr) do
  begin
    if LCols <> '' then LCols := LCols + ',' + sLineBreak + '  ';
    LCols := LCols + QuoteIdent(LArr[i].Column) + ' ' + LArr[i].ColumnType;
    if LArr[i].FieldAllowsNull then
    begin
      if UseExplicitNullInDDL then
        LCols := LCols + ' NULL';
    end
    else
      LCols := LCols + ' NOT NULL';
  end;
  LPkCols := '';
  for i := 0 to High(LArr) do
    if LArr[i].IsPKey then
    begin
      if LPkCols <> '' then LPkCols := LPkCols + ', ';
      LPkCols := LPkCols + QuoteIdent(LArr[i].Column);
    end;
  if LPkCols <> '' then
  begin
    if LCols <> '' then LCols := LCols + ',';
    LCols := LCols + sLineBreak + '  CONSTRAINT ' + QuoteIdent(FTableName + '_pkey') + ' PRIMARY KEY (' + LPkCols + ')';
  end;
  for i := 0 to High(LArr) do
    if (Trim(LArr[i].ReferencedTable) <> '') and (Trim(LArr[i].ReferencedColumn) <> '') then
    begin
      LConstraintName := LArr[i].ConstraintName;
      if LConstraintName = '' then
        LConstraintName := 'fk_' + FTableName + '_' + LArr[i].Column;
      LRefTable := Trim(LArr[i].ReferencedTable);
      LPos := Pos('.', LRefTable);
      if LPos > 0 then
        LRefTable := QuoteIdent(Copy(LRefTable, 1, LPos - 1)) + '.' + QuoteIdent(Trim(Copy(LRefTable, LPos + 1, Length(LRefTable))))
      else if Trim(ASchema) <> '' then
        LRefTable := QuoteIdent(Trim(ASchema)) + '.' + QuoteIdent(LRefTable)
      else
        LRefTable := QuoteIdent(LRefTable);
      LOnDelete := Trim(LArr[i].OnDeleteRule);
      if LOnDelete = '' then LOnDelete := 'NO ACTION';
      LOnUpdate := Trim(LArr[i].OnUpdateRule);
      if LOnUpdate = '' then LOnUpdate := 'NO ACTION';
      LFk := sLineBreak + '  CONSTRAINT ' + QuoteIdent(LConstraintName) + ' FOREIGN KEY (' + QuoteIdent(LArr[i].Column) + ') REFERENCES ' + LRefTable + ' (' + QuoteIdent(LArr[i].ReferencedColumn) + ') ON DELETE ' + LOnDelete + ' ON UPDATE ' + LOnUpdate;
      if LCols <> '' then LCols := LCols + ',';
      LCols := LCols + LFk;
    end;
  Result := 'CREATE TABLE ' + LQualName + ' (' + sLineBreak + '  ' + LCols + sLineBreak + ');';
  if (DatabaseTypes = dtPostgreSQL) and (Trim(ASchema) <> '') then
    Result := Result + sLineBreak + 'ALTER TABLE ' + LQualName + ' OWNER TO "postgres";';
end;

function TTable.DropTableSQL(const ASchema: string): string;
var
  LQualName: string;
begin
  Result := '';
  if FTableName = '' then
    Exit;
  LQualName := QualifiedTableName(ASchema);
  if UseDropTableIfExists then
    Result := 'DROP TABLE IF EXISTS ' + LQualName
  else
    Result := 'DROP TABLE ' + LQualName;
  Result := Result + ';';
end;

function TTable.CreateTable(const AConnection: IConnection): Integer;
var
  LSQL: string;
begin
  Result := 0;
  if (AConnection = nil) or not AConnection.IsConnected then
    Exit;
  LSQL := CreateTableSQL;
  if LSQL <> '' then
    Result := AConnection.ExecuteCommand(LSQL);
end;

function TTable.DropTable(const AConnection: IConnection): Integer;
var
  LSQL: string;
begin
  Result := 0;
  if (AConnection = nil) or not AConnection.IsConnected then
    Exit;
  LSQL := DropTableSQL;
  if LSQL <> '' then
    Result := AConnection.ExecuteCommand(LSQL);
end;

{ ===== Onda D - manipulacao IMPERATIVA de CAMPO na estrutura VIVA =====
  <Op>FieldSQL: monta o SQL via a faceta IDialect.Field (dialecto resolvido pelo
  DatabaseTypes, sem conexao). <Op>Field(conn): executa, IDEMPOTENTE via ICatalogReader.
  Gated USE_DATABASE (Dialect/Metadata so existem sob esse define); OFF -> ''/0. }

function TTable.AddFieldSQL(const AName, AFieldType: string; const ANotNull: Boolean): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (FTableName = '') or (Trim(AName) = '') then Exit;
  Result := TDialect.ForDatabaseType(DatabaseTypes).Field.AddSQL(FTableName, Trim(AName), AFieldType, ANotNull);
{$ENDIF}
end;

function TTable.DropFieldSQL(const AName: string): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (FTableName = '') or (Trim(AName) = '') then Exit;
  Result := TDialect.ForDatabaseType(DatabaseTypes).Field.DropSQL(FTableName, Trim(AName));
{$ENDIF}
end;

function TTable.AlterFieldSQL(const AName, ANewType: string; const ANotNull: Boolean): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (FTableName = '') or (Trim(AName) = '') then Exit;
  Result := TDialect.ForDatabaseType(DatabaseTypes).Field.AlterSQL(FTableName, Trim(AName), ANewType, ANotNull);
{$ENDIF}
end;

function TTable.RenameFieldSQL(const AOldName, ANewName: string): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (FTableName = '') or (Trim(AOldName) = '') or (Trim(ANewName) = '') then Exit;
  Result := TDialect.ForDatabaseType(DatabaseTypes).Field.RenameSQL(FTableName, Trim(AOldName), Trim(ANewName));
{$ENDIF}
end;

function TTable.AddField(const AConnection: IConnection; const AName, AFieldType: string;
  const ANotNull: Boolean): Integer;
{$IFDEF USE_DATABASE}
var
  LSQL: string;
{$ENDIF}
begin
  Result := 0;
{$IFDEF USE_DATABASE}
  if (AConnection = nil) or not AConnection.IsConnected then Exit;
  if (FTableName = '') or (Trim(AName) = '') then Exit;
  { idempotente: so adiciona se a coluna ainda NAO existir }
  if CatColumnExists(AConnection, FTableName, Trim(AName)) then Exit;
  LSQL := TDialect.ForConnection(AConnection).Field.AddSQL(FTableName, Trim(AName), AFieldType, ANotNull);
  if Trim(LSQL) <> '' then
    Result := AConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

function TTable.DropField(const AConnection: IConnection; const AName: string): Integer;
{$IFDEF USE_DATABASE}
var
  LSQL: string;
{$ENDIF}
begin
  Result := 0;
{$IFDEF USE_DATABASE}
  if (AConnection = nil) or not AConnection.IsConnected then Exit;
  if (FTableName = '') or (Trim(AName) = '') then Exit;
  { idempotente: so remove se a coluna existir }
  if not CatColumnExists(AConnection, FTableName, Trim(AName)) then Exit;
  LSQL := TDialect.ForConnection(AConnection).Field.DropSQL(FTableName, Trim(AName));
  if Trim(LSQL) <> '' then
    Result := AConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

function TTable.AlterField(const AConnection: IConnection; const AName, ANewType: string;
  const ANotNull: Boolean): Integer;
{$IFDEF USE_DATABASE}
var
  LSQL: string;
{$ENDIF}
begin
  Result := 0;
{$IFDEF USE_DATABASE}
  if (AConnection = nil) or not AConnection.IsConnected then Exit;
  if (FTableName = '') or (Trim(AName) = '') then Exit;
  { so altera se a coluna existir }
  if not CatColumnExists(AConnection, FTableName, Trim(AName)) then Exit;
  LSQL := TDialect.ForConnection(AConnection).Field.AlterSQL(FTableName, Trim(AName), ANewType, ANotNull);
  if Trim(LSQL) <> '' then
    Result := AConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

function TTable.RenameField(const AConnection: IConnection; const AOldName, ANewName: string): Integer;
{$IFDEF USE_DATABASE}
var
  LSQL: string;
{$ENDIF}
begin
  Result := 0;
{$IFDEF USE_DATABASE}
  if (AConnection = nil) or not AConnection.IsConnected then Exit;
  if (FTableName = '') or (Trim(AOldName) = '') or (Trim(ANewName) = '') then Exit;
  { so renomeia se a origem existir E o destino ainda NAO (mesmo snapshot) }
  if not CatColumnExists(AConnection, FTableName, Trim(AOldName)) then Exit;
  if CatColumnExists(AConnection, FTableName, Trim(ANewName)) then Exit;
  LSQL := TDialect.ForConnection(AConnection).Field.RenameSQL(FTableName, Trim(AOldName), Trim(ANewName));
  if Trim(LSQL) <> '' then
    Result := AConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

{ ===== Onda D - CONSTRAINTS (index/unique/PK/FK) na estrutura VIVA =====
  Mesmo padrao dos campos: <Op>...SQL monta via a faceta (Index/Unique/PKey/FKey);
  <Op>...(conn) executa idempotente (IndexExists/UniqueExists/PrimaryKeyExists/
  ForeignKeyExists). Gated USE_DATABASE (OFF -> ''/0). }

function TTable.AddIndexSQL(const AName: string; const AColumns: array of string; const AUnique: Boolean): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (FTableName = '') or (Trim(AName) = '') then Exit;
  Result := TDialect.ForDatabaseType(DatabaseTypes).Index.CreateSQL(FTableName, Trim(AName), AColumns, AUnique);
{$ENDIF}
end;

function TTable.DropIndexSQL(const AName: string): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (FTableName = '') or (Trim(AName) = '') then Exit;
  Result := TDialect.ForDatabaseType(DatabaseTypes).Index.DropSQL(FTableName, Trim(AName));
{$ENDIF}
end;

function TTable.AddIndex(const AConnection: IConnection; const AName: string; const AColumns: array of string; const AUnique: Boolean): Integer;
{$IFDEF USE_DATABASE}
var
  LSQL: string;
{$ENDIF}
begin
  Result := 0;
{$IFDEF USE_DATABASE}
  if (AConnection = nil) or not AConnection.IsConnected then Exit;
  if (FTableName = '') or (Trim(AName) = '') then Exit;
  if CatIndexExists(AConnection, FTableName, Trim(AName)) then Exit;
  LSQL := TDialect.ForConnection(AConnection).Index.CreateSQL(FTableName, Trim(AName), AColumns, AUnique);
  if Trim(LSQL) <> '' then Result := AConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

function TTable.DropIndex(const AConnection: IConnection; const AName: string): Integer;
{$IFDEF USE_DATABASE}
var
  LSQL: string;
{$ENDIF}
begin
  Result := 0;
{$IFDEF USE_DATABASE}
  if (AConnection = nil) or not AConnection.IsConnected then Exit;
  if (FTableName = '') or (Trim(AName) = '') then Exit;
  if not CatIndexExists(AConnection, FTableName, Trim(AName)) then Exit;
  LSQL := TDialect.ForConnection(AConnection).Index.DropSQL(FTableName, Trim(AName));
  if Trim(LSQL) <> '' then Result := AConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

function TTable.AddUniqueSQL(const AName: string; const AColumns: array of string): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (FTableName = '') or (Trim(AName) = '') then Exit;
  Result := TDialect.ForDatabaseType(DatabaseTypes).Unique.AddSQL(FTableName, Trim(AName), AColumns);
{$ENDIF}
end;

function TTable.DropUniqueSQL(const AName: string): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (FTableName = '') or (Trim(AName) = '') then Exit;
  Result := TDialect.ForDatabaseType(DatabaseTypes).Unique.DropSQL(FTableName, Trim(AName));
{$ENDIF}
end;

function TTable.AddUnique(const AConnection: IConnection; const AName: string; const AColumns: array of string): Integer;
{$IFDEF USE_DATABASE}
var
  LSQL: string;
{$ENDIF}
begin
  Result := 0;
{$IFDEF USE_DATABASE}
  if (AConnection = nil) or not AConnection.IsConnected then Exit;
  if (FTableName = '') or (Trim(AName) = '') then Exit;
  if CatUniqueExists(AConnection, FTableName, Trim(AName)) then Exit;
  LSQL := TDialect.ForConnection(AConnection).Unique.AddSQL(FTableName, Trim(AName), AColumns);
  if Trim(LSQL) <> '' then Result := AConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

function TTable.DropUnique(const AConnection: IConnection; const AName: string): Integer;
{$IFDEF USE_DATABASE}
var
  LSQL: string;
{$ENDIF}
begin
  Result := 0;
{$IFDEF USE_DATABASE}
  if (AConnection = nil) or not AConnection.IsConnected then Exit;
  if (FTableName = '') or (Trim(AName) = '') then Exit;
  if not CatUniqueExists(AConnection, FTableName, Trim(AName)) then Exit;
  LSQL := TDialect.ForConnection(AConnection).Unique.DropSQL(FTableName, Trim(AName));
  if Trim(LSQL) <> '' then Result := AConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

function TTable.AddPrimaryKeySQL(const AName: string; const AColumns: array of string): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (FTableName = '') or (Trim(AName) = '') then Exit;
  Result := TDialect.ForDatabaseType(DatabaseTypes).PKey.AddSQL(FTableName, Trim(AName), AColumns);
{$ENDIF}
end;

function TTable.DropPrimaryKeySQL(const AName: string): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (FTableName = '') or (Trim(AName) = '') then Exit;
  Result := TDialect.ForDatabaseType(DatabaseTypes).PKey.DropSQL(FTableName, Trim(AName));
{$ENDIF}
end;

function TTable.AddPrimaryKey(const AConnection: IConnection; const AName: string; const AColumns: array of string): Integer;
{$IFDEF USE_DATABASE}
var
  LSQL: string;
{$ENDIF}
begin
  Result := 0;
{$IFDEF USE_DATABASE}
  if (AConnection = nil) or not AConnection.IsConnected then Exit;
  if (FTableName = '') or (Trim(AName) = '') then Exit;
  { uma tabela tem no maximo uma PK: so adiciona se ainda nao existir nenhuma }
  if CatPrimaryKeyExists(AConnection, FTableName) then Exit;
  LSQL := TDialect.ForConnection(AConnection).PKey.AddSQL(FTableName, Trim(AName), AColumns);
  if Trim(LSQL) <> '' then Result := AConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

function TTable.DropPrimaryKey(const AConnection: IConnection; const AName: string): Integer;
{$IFDEF USE_DATABASE}
var
  LSQL: string;
{$ENDIF}
begin
  Result := 0;
{$IFDEF USE_DATABASE}
  if (AConnection = nil) or not AConnection.IsConnected then Exit;
  if (FTableName = '') or (Trim(AName) = '') then Exit;
  if not CatPrimaryKeyExists(AConnection, FTableName) then Exit;
  LSQL := TDialect.ForConnection(AConnection).PKey.DropSQL(FTableName, Trim(AName));
  if Trim(LSQL) <> '' then Result := AConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

function TTable.AddForeignKeySQL(const AName: string; const AColumns: array of string; const ARefTable: string; const ARefColumns: array of string; const AOnDelete, AOnUpdate: string): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (FTableName = '') or (Trim(AName) = '') then Exit;
  Result := TDialect.ForDatabaseType(DatabaseTypes).FKey.AddSQL(FTableName, Trim(AName), AColumns, ARefTable, ARefColumns, AOnDelete, AOnUpdate);
{$ENDIF}
end;

function TTable.DropForeignKeySQL(const AName: string): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (FTableName = '') or (Trim(AName) = '') then Exit;
  Result := TDialect.ForDatabaseType(DatabaseTypes).FKey.DropSQL(FTableName, Trim(AName));
{$ENDIF}
end;

function TTable.AddForeignKey(const AConnection: IConnection; const AName: string; const AColumns: array of string; const ARefTable: string; const ARefColumns: array of string; const AOnDelete, AOnUpdate: string): Integer;
{$IFDEF USE_DATABASE}
var
  LSQL: string;
{$ENDIF}
begin
  Result := 0;
{$IFDEF USE_DATABASE}
  if (AConnection = nil) or not AConnection.IsConnected then Exit;
  if (FTableName = '') or (Trim(AName) = '') then Exit;
  if CatForeignKeyExists(AConnection, FTableName, Trim(AName)) then Exit;
  LSQL := TDialect.ForConnection(AConnection).FKey.AddSQL(FTableName, Trim(AName), AColumns, ARefTable, ARefColumns, AOnDelete, AOnUpdate);
  if Trim(LSQL) <> '' then Result := AConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

function TTable.DropForeignKey(const AConnection: IConnection; const AName: string): Integer;
{$IFDEF USE_DATABASE}
var
  LSQL: string;
{$ENDIF}
begin
  Result := 0;
{$IFDEF USE_DATABASE}
  if (AConnection = nil) or not AConnection.IsConnected then Exit;
  if (FTableName = '') or (Trim(AName) = '') then Exit;
  if not CatForeignKeyExists(AConnection, FTableName, Trim(AName)) then Exit;
  LSQL := TDialect.ForConnection(AConnection).FKey.DropSQL(FTableName, Trim(AName));
  if Trim(LSQL) <> '' then Result := AConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

function TTable.Uniques: TSchemaUniques;
begin
  { Onda S3b (ADITIVO) - devolve o MODELO em memoria tal-qual (FUniques,
    Onda S2-b1) - read-only; a mutacao continua a ser AddUnique (Onda D). }
  Result := FUniques;
end;

function TTable.Indexes: TSchemaIndexes;
begin
  Result := FIndexes;
end;

function TTable.ToDDL: string;
var
  I: Integer;
  LStmt: string;
begin
  { Onda S3 - agrega os geradores *SQL JA EXISTENTES desta propria tabela
    (zero SQL novo): CreateTableSQL ja cobre colunas+PK/NOT NULL E a FK
    POR-CAMPO (CONSTRAINT ... FOREIGN KEY INLINE dentro do proprio CREATE
    TABLE, ver corpo de CreateTableSQL acima - dispara sempre que
    IField.ReferencedTable/ReferencedColumn estao preenchidos); FUniques/
    FIndexes (Onda S2-b1, modelo em memoria) sao o UNICO par de constraints
    que CreateTableSQL nao cobre inline - emitidos aqui via AddUniqueSQL/
    AddIndexSQL (facetas do dialecto, "Onda D").
    DECISAO DELIBERADA: NAO se repete AddForeignKeySQL para os campos com
    ReferencedTable preenchido - seria a MESMA constraint (mesmo nome
    derivado, mesma origem de dados por-campo) já embutida por CreateTableSQL,
    e repeti-la num 2o statement ALTER TABLE ADD CONSTRAINT tornaria o script
    INVALIDO (a generalidade dos motores rejeita constraint duplicada) - o
    objectivo desta feature (owner) e devolver SQL REAL executavel para
    validar, nao um script que falharia ja no 2o statement. }
  Result := '';
  LStmt := CreateTableSQL;
  if Trim(LStmt) = '' then
    Exit;
  Result := Trim(LStmt);
  for I := 0 to High(FUniques) do
  begin
    LStmt := Trim(AddUniqueSQL(FUniques[I].Name, FUniques[I].Columns));
    if LStmt <> '' then
      Result := Result + sLineBreak + LStmt + ';';
  end;
  for I := 0 to High(FIndexes) do
  begin
    LStmt := Trim(AddIndexSQL(FIndexes[I].Name, FIndexes[I].Columns, FIndexes[I].Unique));
    if LStmt <> '' then
      Result := Result + sLineBreak + LStmt + ';';
  end;
end;

function TTable.ToSQL: string;
{$IFDEF USE_DATABASE}
var
  LQB: IQueryBuilder;
  LArr: TFieldArray;
  I: Integer;
  LAdded: Boolean;
{$ENDIF}
begin
  { Onda S3 - eixo DADOS (DML): INSERT do registo actual, reutilizando
    IQueryBuilder (InsertInto/Value/ToSQL - NUNCA SQL escrito a mao). Dialect-
    aware sem exigir conexao ligada: usa a Connection fluente desta ITable se
    ja injectada (fallback identico a Execute), senao passa DatabaseTypes ao
    IQueryBuilder (Onda S3, novo overload). Skip do MESMO criterio Optimized
    de InsertSQL (campo nao-nulavel + valor vazio - tipicamente a PK auto-
    increment ainda sem valor, para o motor gerar). O SQL devolvido usa
    placeholders ':paramN' (contrato SEMPRE bindado do IQueryBuilder.Value -
    nunca literal); os valores reais ficam em IQueryBuilder.Params (nao
    substituidos aqui - renderizar literal exigiria uma rotina nova, fora do
    escopo "reutilizar, zero SQL novo" desta onda). }
  Result := '';
  if FTableName = '' then
    Exit;
{$IFDEF USE_DATABASE}
  LArr := GetFieldsList;
  if Length(LArr) = 0 then
    Exit;
  LQB := Database.QueryBuilder.TQueryBuilder.New;
  if FConnection <> nil then
    LQB.Connection(FConnection)
  else
    LQB.DatabaseTypes(DatabaseTypes);
  LQB.InsertInto(FTableName);
  LAdded := False;
  for I := 0 to High(LArr) do
  begin
    if not LArr[I].FieldAllowsNull and (VarToStr(LArr[I].Value) = '') then
      Continue;
    LQB.Value(LArr[I].Column, LArr[I].Value);
    LAdded := True;
  end;
  if LAdded then
    Result := LQB.ToSQL;
{$ENDIF}
end;

function TTable.ValidateNotNullFields: Boolean;
var
  LErrors: TFieldValidationErrors;
begin
  { Compat (Sub-passo 4.5): wrapper aditivo sobre ValidateFields - mesma
    semantica booleana de sempre (True = sem obrigatorios em falta); o
    detalhe (field,message) fica disponivel via ValidateFields. }
  Result := ValidateFields(LErrors);
end;

function TTable.ValidateFields(out AErrors: TFieldValidationErrors): Boolean;
var
  i: Integer;
  LArr: TFieldArray;
  LCol: string;
begin
  { Sub-passo 4.5 (continuacao Onda 4, revisao F5) - percorre os campos
    obrigatorios (not FieldAllowsNull) e devolve em AErrors o detalhe
    (field,message) de cada um sem valor (vazio/Unassigned/Null - mesmo
    criterio ja usado por InsertSQL(Optimized)/TableFieldHasNoValue, Fatia
    B-b). 2 categorias de campo NUNCA sao acusadas, mesmo quando NOT NULL na
    DDL, porque a ausencia de valor no OBJECTO e intencional/normal (nao e
    "o chamador esqueceu-se"):
    (1) Chave primaria (IsPKey=True) - o padrao AUTOINCREMENT/IDENTITY/SERIAL
        (id deliberadamente por atribuir no INSERT, o BD gera - ver
        NewPessoaForInsert nos smokes de EntityManager/UnitOfWork) e de
        LONGE o mais comum; a PK vazia no INSERT ja e semantica estabelecida
        no proprio Execute (dsInactive infere Insert quando a PK esta vazia).
        Para dsEdit/dsDeleted a PK preenchida ja e exigida por uma guarda
        PROPRIA e mais precisa (EnsurePrimaryKeyPresent, Sub-passo 4.5) -
        ValidateFields nao duplica essa responsabilidade.
    (2) Os 4 campos de auditoria/soft-delete configurados (FieldDateCreated/
        FieldDateUpdated/FieldIsDeleted/FieldIsActive, Sub-passo 4.4) - sao
        geridos pelo proprio TTable, nunca pelo chamador: FieldDateCreated/
        FieldIsActive sao carimbados automaticamente por InsertSQL (que so
        corre DEPOIS desta validacao dentro de Execute); FieldDateUpdated
        idem por UpdateSQL; FieldIsDeleted e o caso mais subtil - fica de
        proposito por preencher no INSERT (InsertSQL Optimized=True salta
        colunas NOT NULL vazias, ver NewAuditTable no smoke) para o DEFAULT
        da DDL prevalecer - so DeleteSQL o toca. }
  SetLength(AErrors, 0);
  LArr := GetFieldsList;
  for i := 0 to Length(LArr) - 1 do
  begin
    if LArr[i].FieldAllowsNull then
      Continue;
    if LArr[i].IsPKey then
      Continue;
    LCol := LArr[i].Column;
    if (Trim(FFieldDateCreated) <> '') and SameText(LCol, FFieldDateCreated) then
      Continue;
    if (Trim(FFieldDateUpdated) <> '') and SameText(LCol, FFieldDateUpdated) then
      Continue;
    if (Trim(FFieldIsDeleted) <> '') and SameText(LCol, FFieldIsDeleted) then
      Continue;
    if (Trim(FFieldIsActive) <> '') and SameText(LCol, FFieldIsActive) then
      Continue;
    if VarIsNull(LArr[i].Value) or VarIsEmpty(LArr[i].Value) or (VarToStr(LArr[i].Value) = '') then
    begin
      SetLength(AErrors, Length(AErrors) + 1);
      AErrors[High(AErrors)].Field := LCol;
      AErrors[High(AErrors)].Message := 'Campo obrigatorio "' + LCol + '" sem valor.';
    end;
  end;
  Result := Length(AErrors) = 0;
end;

function TTable.HasChanges: Boolean;
begin
  Result := inherited HasChanges;
end;

function TTable.GetChangedFieldNames: TStringArray;
begin
  Result := GetAllChangedFieldNames;
end;

function TTable.Status: TRowStatus;
begin
  { Sem constructor Create explicito em TTable - o campo nasce zerado pela
    RTL (NewInstance), pelo que o valor por omissao ja e dsInactive (ordinal
    0, 1o membro de TRowStatus). Onda 4.2 - status por registo (modelo
    v1.6.1). }
  Result := FStatus;
end;

function TTable.Status(const AValue: TRowStatus): ITable;
begin
  FStatus := AValue;
  Result := Self;
end;

function TTable.ReadOnly(const AValue: Boolean): ITable;
begin
  { Sub-passo 4.5 (continuacao Onda 4, revisao F5) - guarda equivalente ao
    FDeletedBlock v1.6.1 (padrao fluente identico a AuditFields). }
  FReadOnly := AValue;
  Result := Self;
end;

function TTable.ReadOnly: Boolean;
begin
  Result := FReadOnly;
end;

function TTable.OnValidate(const AValue: TOnTableValidate): ITable;
begin
  { Onda 6-e Estagio 4 (A4) - hook de validacao CUSTOMIZADA (padrao fluente
    identico a ReadOnly/AuditFields). }
  FOnValidate := AValue;
  Result := Self;
end;

function TTable.OnValidate: TOnTableValidate;
begin
  Result := FOnValidate;
end;

function TTable.AuditFields(const AValue: Boolean): ITable;
begin
  FAuditFields := AValue;
  Result := Self;
end;

function TTable.AuditFields: Boolean;
begin
  Result := FAuditFields;
end;

function TTable.FieldDateCreated(const AValue: string): ITable;
begin
  FFieldDateCreated := AValue;
  Result := Self;
end;

function TTable.FieldDateCreated: string;
begin
  Result := FFieldDateCreated;
end;

function TTable.FieldDateUpdated(const AValue: string): ITable;
begin
  FFieldDateUpdated := AValue;
  Result := Self;
end;

function TTable.FieldDateUpdated: string;
begin
  Result := FFieldDateUpdated;
end;

function TTable.FieldIsDeleted(const AValue: string): ITable;
begin
  FFieldIsDeleted := AValue;
  Result := Self;
end;

function TTable.FieldIsDeleted: string;
begin
  Result := FFieldIsDeleted;
end;

function TTable.FieldIsActive(const AValue: string): ITable;
begin
  FFieldIsActive := AValue;
  Result := Self;
end;

function TTable.FieldIsActive: string;
begin
  Result := FFieldIsActive;
end;

{$IFDEF USE_DATABASE}
{ Helpers Cat* - idempotencia dos metodos *Field (que executam DDL com uma
  AConnection explicita); delegam ao motor de catalogo centralizado
  TCatalogReader (SSOT, regra #14). }
function TTable.CatStructure(const AConn: IConnection; const ATable: string): TArray<TDatabaseFields>;
begin
  SetLength(Result, 0);
  if AConn <> nil then
    Result := TCatalogReader.New(AConn).TableStructure(ATable, '');
end;

function TTable.CatColumnExists(const AConn: IConnection; const ATable, AColumn: string): Boolean;
begin
  Result := (AConn <> nil) and TCatalogReader.New(AConn).ColumnExists(ATable, AColumn, '');
end;

function TTable.CatPrimaryKeyExists(const AConn: IConnection; const ATable: string): Boolean;
begin
  Result := (AConn <> nil) and TCatalogReader.New(AConn).PrimaryKeyExists(ATable, '');
end;

function TTable.CatForeignKeyExists(const AConn: IConnection; const ATable, AName: string): Boolean;
begin
  Result := (AConn <> nil) and TCatalogReader.New(AConn).ForeignKeyExists(ATable, AName, '');
end;

function TTable.CatUniqueExists(const AConn: IConnection; const ATable, AName: string): Boolean;
begin  { conservador: sem conexao -> True (o SchemaSync nao re-tenta criar) }
  Result := (AConn = nil) or TCatalogReader.New(AConn).UniqueExists(ATable, AName, '');
end;

function TTable.CatIndexExists(const AConn: IConnection; const ATable, AName: string): Boolean;
begin
  Result := (AConn = nil) or TCatalogReader.New(AConn).IndexExists(ATable, AName, '');
end;
{$ENDIF}

{ ===== ITable - introspeccao de SI mesma: Connection/TableName proprios;
  delega ao TCatalogReader centralizado. Gated USE_DATABASE. ===== }
function TTable.TableStructure: TArray<TDatabaseFields>;
begin
  SetLength(Result, 0);
{$IFDEF USE_DATABASE}
  Result := TCatalogReader.New(Connection).TableStructure(TableName, '');
{$ENDIF}
end;

function TTable.ColumnExists(const AColumnName: string): Boolean;
begin
  Result := False;
{$IFDEF USE_DATABASE}
  Result := TCatalogReader.New(Connection).ColumnExists(TableName, AColumnName, '');
{$ENDIF}
end;

function TTable.PrimaryKeyColumns: TStringArray;
begin
  SetLength(Result, 0);
{$IFDEF USE_DATABASE}
  Result := TCatalogReader.New(Connection).PrimaryKeyColumns(TableName, '');
{$ENDIF}
end;

function TTable.PrimaryKeyExists: Boolean;
begin
  Result := False;
{$IFDEF USE_DATABASE}
  Result := TCatalogReader.New(Connection).PrimaryKeyExists(TableName, '');
{$ENDIF}
end;

function TTable.ForeignKeys: TArray<TDatabaseFields>;
begin
  SetLength(Result, 0);
{$IFDEF USE_DATABASE}
  Result := TCatalogReader.New(Connection).ForeignKeys(TableName, '');
{$ENDIF}
end;

function TTable.ResolveFK: TArray<TRelationInfo>;
begin
  SetLength(Result, 0);
{$IFDEF USE_DATABASE}
  Result := TCatalogReader.New(Connection).ResolveFK(TableName, '');
{$ENDIF}
end;

function TTable.ForeignKeyNames: TStringArray;
begin
  SetLength(Result, 0);
{$IFDEF USE_DATABASE}
  Result := TCatalogReader.New(Connection).ForeignKeyNames(TableName, '');
{$ENDIF}
end;

function TTable.ForeignKeyExists(const AConstraintName: string): Boolean;
begin
  Result := False;
{$IFDEF USE_DATABASE}
  Result := TCatalogReader.New(Connection).ForeignKeyExists(TableName, AConstraintName, '');
{$ENDIF}
end;

function TTable.UniqueNames: TStringArray;
begin
  SetLength(Result, 0);
{$IFDEF USE_DATABASE}
  Result := TCatalogReader.New(Connection).UniqueNames(TableName, '');
{$ENDIF}
end;

function TTable.IndexNames: TStringArray;
begin
  SetLength(Result, 0);
{$IFDEF USE_DATABASE}
  Result := TCatalogReader.New(Connection).IndexNames(TableName, '');
{$ENDIF}
end;

function TTable.UniqueExists(const AConstraintName: string): Boolean;
begin
  Result := False;
{$IFDEF USE_DATABASE}
  Result := TCatalogReader.New(Connection).UniqueExists(TableName, AConstraintName, '');
{$ENDIF}
end;

function TTable.IndexExists(const AIndexName: string): Boolean;
begin
  Result := False;
{$IFDEF USE_DATABASE}
  Result := TCatalogReader.New(Connection).IndexExists(TableName, AIndexName, '');
{$ENDIF}
end;


function TTable.ToJSON: string;
var
  I: Integer;
  LArr: TFieldArray;
  LBody: string;
begin
  { EIXO DADO PROPRIO da Table (Fatia B-b) - objeto JSON com par coluna/valor
    por campo mais a chave object_state, valor tipado por ColumnType;
    sobrepoe (mesma assinatura string, reintroducao de nome) o array
    posicional generico herdado de IFields.ToJSON. }
  LArr := GetFieldsList;
  LBody := '';
  for I := 0 to High(LArr) do
  begin
    if LBody <> '' then
      LBody := LBody + ',';
    LBody := LBody + JSONQuoteString(LArr[I].Column) + ':' + TableFieldValueToJSONLiteral(LArr[I]);
  end;
  if LBody <> '' then
    LBody := LBody + ',';
  Result := '{' + LBody + '"object_state":' + JSONQuoteString(RowStatusToObjectState(FStatus)) + '}';
end;

function TTable.TableFromJSON(const AJSON: string): ITable;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
  LField: IField;
  I: Integer;
  LStateNode: TJSONData;
begin
  { EIXO DADO PROPRIO da Table, "replace" (Fatia B-b) - hidrata LIMPO por
    coluna (SetColumnValueWithoutChange), coluna ausente no JSON e ignorada;
    aplica object_state a Status. Vinculado ao slot ITable.FromJSON via
    clausula de resolucao de interface (ver secao public da classe). }
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
    for I := 0 to Pred(LObj.Count) do
    begin
      if CompareText(LObj.Names[I], 'object_state') = 0 then
        Continue;
      LField := GetFields(LObj.Names[I]);
      if LField <> nil then
        LField.SetColumnValueWithoutChange(TableJSONNodeToVariant(LObj.Items[I]));
    end;
    LStateNode := LObj.Find('object_state');
    if Assigned(LStateNode) then
      Status(ObjectStateToRowStatus(LStateNode.AsString));
  finally
    LObj.Free;
  end;
end;
{$ELSE}
var
  LVal: TJSONValue;
  LObj: TJSONObject;
  LField: IField;
  LPair: TJSONPair;
  LStateVal: TJSONValue;
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
    for LPair in LObj do
    begin
      if CompareText(LPair.JsonString.Value, 'object_state') = 0 then
        Continue;
      LField := GetFields(LPair.JsonString.Value);
      if LField <> nil then
        LField.SetColumnValueWithoutChange(TableJSONNodeToVariant(LPair.JsonValue));
    end;
    LStateVal := LObj.GetValue('object_state');
    if Assigned(LStateVal) then
      Status(ObjectStateToRowStatus(LStateVal.Value));
  finally
    LObj.Free;
  end;
end;
{$ENDIF}

function TTable.TableMergeFromJSON(const AJSON: string): ITable;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
  LField: IField;
  I: Integer;
  LStateNode: TJSONData;
begin
  { EIXO DADO PROPRIO da Table, "patch" (Fatia B-b, novo) - hidrata por coluna
    via SetColumnValue (dirty inteligente: so fica IsChanged quem realmente
    difere de OriginalValue); coluna ausente no JSON e ignorada (preserva o
    valor/estado corrente); aplica object_state a Status. }
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
    for I := 0 to Pred(LObj.Count) do
    begin
      if CompareText(LObj.Names[I], 'object_state') = 0 then
        Continue;
      LField := GetFields(LObj.Names[I]);
      if LField <> nil then
        LField.SetColumnValue(TableJSONNodeToVariant(LObj.Items[I]));
    end;
    LStateNode := LObj.Find('object_state');
    if Assigned(LStateNode) then
      Status(ObjectStateToRowStatus(LStateNode.AsString));
  finally
    LObj.Free;
  end;
end;
{$ELSE}
var
  LVal: TJSONValue;
  LObj: TJSONObject;
  LField: IField;
  LPair: TJSONPair;
  LStateVal: TJSONValue;
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
    for LPair in LObj do
    begin
      if CompareText(LPair.JsonString.Value, 'object_state') = 0 then
        Continue;
      LField := GetFields(LPair.JsonString.Value);
      if LField <> nil then
        LField.SetColumnValue(TableJSONNodeToVariant(LPair.JsonValue));
    end;
    LStateVal := LObj.GetValue('object_state');
    if Assigned(LStateVal) then
      Status(ObjectStateToRowStatus(LStateVal.Value));
  finally
    LObj.Free;
  end;
end;
{$ENDIF}

function TTable.StructureToJSON: string;
var
  I: Integer;
  LArr: TFieldArray;
  LFieldsJSON, LPkJSON, LUniquesJSON, LIndexesJSON: string;
begin
  { EIXO ESTRUTURA PROPRIO da Table (Fatia B-b) - objeto JSON com as chaves
    table/fields/primaryKey; sobrepoe (mesma assinatura string, reintroducao
    de nome) o array puro herdado de IFields.StructureToJSON. Onda S2-b1
    (ADITIVO) - +"uniques"/+"indexes" (constraints/indices NOMEADOS e MULTI-
    COLUNA a nivel da tabela, FUniques/FIndexes - ver comentario da seccao
    private). PK/FK continuam cobertos POR-CAMPO (isPKey/referencedTable/...
    dentro de cada elemento de "fields") - inalterado. }
  LArr := GetFieldsList;
  LFieldsJSON := '';
  LPkJSON := '';
  for I := 0 to High(LArr) do
  begin
    if LFieldsJSON <> '' then
      LFieldsJSON := LFieldsJSON + ',';
    LFieldsJSON := LFieldsJSON + LArr[I].StructureToJSON;
    if LArr[I].IsPKey then
    begin
      if LPkJSON <> '' then
        LPkJSON := LPkJSON + ',';
      LPkJSON := LPkJSON + JSONQuoteString(LArr[I].Column);
    end;
  end;
  LUniquesJSON := '';
  for I := 0 to High(FUniques) do
  begin
    if LUniquesJSON <> '' then
      LUniquesJSON := LUniquesJSON + ',';
    LUniquesJSON := LUniquesJSON + '{"name":' + JSONQuoteString(FUniques[I].Name) +
      ',"columns":[' + TableSchemaColumnsToJSON(FUniques[I].Columns) + ']}';
  end;
  LIndexesJSON := '';
  for I := 0 to High(FIndexes) do
  begin
    if LIndexesJSON <> '' then
      LIndexesJSON := LIndexesJSON + ',';
    LIndexesJSON := LIndexesJSON + '{"name":' + JSONQuoteString(FIndexes[I].Name) +
      ',"columns":[' + TableSchemaColumnsToJSON(FIndexes[I].Columns) + ']' +
      ',"unique":' + TableJSONBoolLiteral(FIndexes[I].Unique) + '}';
  end;
  Result := '{"table":' + JSONQuoteString(FTableName) + ',' +
    '"fields":[' + LFieldsJSON + '],' +
    '"primaryKey":[' + LPkJSON + '],' +
    '"uniques":[' + LUniquesJSON + '],' +
    '"indexes":[' + LIndexesJSON + ']}';
end;

function TTable.TableStructureFromJSON(const AJSON: string): ITable;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
  LFieldsNode, LPkNode, LUniquesNode, LIndexesNode: TJSONData;
  LFieldsArr, LPkArr, LUniquesArr, LIndexesArr: TJSONArray;
  LUniqueObj, LIndexObj: TJSONObject;
  I: Integer;
  LField: IField;
begin
  { EIXO ESTRUTURA PROPRIO da Table (Fatia B-b) - reconstroi TableName +
    campos (cria um IField por elemento de "fields" via
    IField.StructureFromJSON) + aplica IsPKey=True as colunas listadas em
    "primaryKey". Onda S2-b1 (ADITIVO) - reconstroi tambem FUniques/FIndexes
    (Clear+reconstroi tudo, mesma semantica "replace" do resto do metodo) a
    partir das novas chaves "uniques"/"indexes". Vinculado ao slot
    ITable.StructureFromJSON via clausula de resolucao de interface (ver
    secao public da classe). }
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
    Clear;
    FUniques := nil;
    FIndexes := nil;
    TableName(LObj.Get('table', FTableName));
    LFieldsNode := LObj.Find('fields');
    if Assigned(LFieldsNode) and (LFieldsNode is TJSONArray) then
    begin
      LFieldsArr := TJSONArray(LFieldsNode);
      for I := 0 to LFieldsArr.Count - 1 do
      begin
        LField := TField.New;
        LField.StructureFromJSON(LFieldsArr.Items[I].AsJSON);
        AddField(LField);
      end;
    end;
    LPkNode := LObj.Find('primaryKey');
    if Assigned(LPkNode) and (LPkNode is TJSONArray) then
    begin
      LPkArr := TJSONArray(LPkNode);
      for I := 0 to LPkArr.Count - 1 do
      begin
        LField := GetFields(LPkArr.Items[I].AsString);
        if LField <> nil then
          LField.IsPKey(True);
      end;
    end;
    LUniquesNode := LObj.Find('uniques');
    if Assigned(LUniquesNode) and (LUniquesNode is TJSONArray) then
    begin
      LUniquesArr := TJSONArray(LUniquesNode);
      for I := 0 to LUniquesArr.Count - 1 do
      begin
        if not (LUniquesArr.Items[I] is TJSONObject) then
          Continue;
        LUniqueObj := TJSONObject(LUniquesArr.Items[I]);
        SetLength(FUniques, Length(FUniques) + 1);
        FUniques[High(FUniques)].Name := LUniqueObj.Get('name', '');
        FUniques[High(FUniques)].Columns := TableSchemaColumnsFromJSON(LUniqueObj.Find('columns'));
      end;
    end;
    LIndexesNode := LObj.Find('indexes');
    if Assigned(LIndexesNode) and (LIndexesNode is TJSONArray) then
    begin
      LIndexesArr := TJSONArray(LIndexesNode);
      for I := 0 to LIndexesArr.Count - 1 do
      begin
        if not (LIndexesArr.Items[I] is TJSONObject) then
          Continue;
        LIndexObj := TJSONObject(LIndexesArr.Items[I]);
        SetLength(FIndexes, Length(FIndexes) + 1);
        FIndexes[High(FIndexes)].Name := LIndexObj.Get('name', '');
        FIndexes[High(FIndexes)].Columns := TableSchemaColumnsFromJSON(LIndexObj.Find('columns'));
        FIndexes[High(FIndexes)].Unique := LIndexObj.Get('unique', False);
      end;
    end;
  finally
    LObj.Free;
  end;
end;
{$ELSE}
var
  LVal: TJSONValue;
  LObj: TJSONObject;
  LFieldsVal, LPkVal, LUniquesVal, LIndexesVal: TJSONValue;
  LFieldsArr, LPkArr, LUniquesArr, LIndexesArr: TJSONArray;
  LUniqueObj, LIndexObj: TJSONObject;
  I: Integer;
  LField: IField;
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
    Clear;
    FUniques := nil;
    FIndexes := nil;
    TableName(LObj.GetValue<string>('table', FTableName));
    LFieldsVal := LObj.GetValue('fields');
    if Assigned(LFieldsVal) and (LFieldsVal is TJSONArray) then
    begin
      LFieldsArr := TJSONArray(LFieldsVal);
      for I := 0 to LFieldsArr.Count - 1 do
      begin
        LField := TField.New;
        LField.StructureFromJSON(LFieldsArr.Items[I].ToJSON);
        AddField(LField);
      end;
    end;
    LPkVal := LObj.GetValue('primaryKey');
    if Assigned(LPkVal) and (LPkVal is TJSONArray) then
    begin
      LPkArr := TJSONArray(LPkVal);
      for I := 0 to LPkArr.Count - 1 do
      begin
        LField := GetFields(LPkArr.Items[I].Value);
        if LField <> nil then
          LField.IsPKey(True);
      end;
    end;
    LUniquesVal := LObj.GetValue('uniques');
    if Assigned(LUniquesVal) and (LUniquesVal is TJSONArray) then
    begin
      LUniquesArr := TJSONArray(LUniquesVal);
      for I := 0 to LUniquesArr.Count - 1 do
      begin
        if not (LUniquesArr.Items[I] is TJSONObject) then
          Continue;
        LUniqueObj := TJSONObject(LUniquesArr.Items[I]);
        SetLength(FUniques, Length(FUniques) + 1);
        FUniques[High(FUniques)].Name := LUniqueObj.GetValue<string>('name', '');
        FUniques[High(FUniques)].Columns := TableSchemaColumnsFromJSON(LUniqueObj.GetValue('columns'));
      end;
    end;
    LIndexesVal := LObj.GetValue('indexes');
    if Assigned(LIndexesVal) and (LIndexesVal is TJSONArray) then
    begin
      LIndexesArr := TJSONArray(LIndexesVal);
      for I := 0 to LIndexesArr.Count - 1 do
      begin
        if not (LIndexesArr.Items[I] is TJSONObject) then
          Continue;
        LIndexObj := TJSONObject(LIndexesArr.Items[I]);
        SetLength(FIndexes, Length(FIndexes) + 1);
        FIndexes[High(FIndexes)].Name := LIndexObj.GetValue<string>('name', '');
        FIndexes[High(FIndexes)].Columns := TableSchemaColumnsFromJSON(LIndexObj.GetValue('columns'));
        FIndexes[High(FIndexes)].Unique := LIndexObj.GetValue<Boolean>('unique', False);
      end;
    end;
  finally
    LObj.Free;
  end;
end;
{$ENDIF}

function TTable.TableStructureMergeFromJSON(const AJSON: string): ITable;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
  LFieldsNode, LPkNode, LUniquesNode, LIndexesNode: TJSONData;
  LPkArr, LUniquesArr, LIndexesArr: TJSONArray;
  LUniqueObj, LIndexObj: TJSONObject;
  I, LPos: Integer;
  LName: string;
  LField: IField;
begin
  { Onda S2-a (ADITIVO) - PATCH aditivo de metadata da propria Table: ao
    contrario de TableStructureFromJSON (que faz Clear e reconstroi TODOS os
    campos por posicao), aqui os campos EXISTENTES sao preservados. "table"
    segue o mesmo padrao patch de Get(default=valor CORRENTE) ja usado por
    TableStructureFromJSON (ausente no JSON -> mantem FTableName); "fields"
    delega ao StructureMergeFromJSON HERDADO de TFields via `inherited`
    (patch por NOME de coluna - existentes recebem StructureMergeFromJSON,
    ausentes sao criados, nada e removido - ja implementado em
    Database.Fields.pas, Onda S2-a); "primaryKey" so ACRESCENTA IsPKey=True
    as colunas listadas (nunca desmarca as ausentes - mesma logica aditiva
    ja usada por TableStructureFromJSON, que tambem nunca desmarca).
    Onda S2-b1 (ADITIVO) - "uniques"/"indexes" seguem a MESMA logica aditiva
    PATCH POR NOME (TableIndexOfUnique/TableIndexOfIndex): existe um elemento
    de FUniques/FIndexes com esse "name" -> substitui Columns[/Unique] no
    lugar; nao existe -> acrescenta um elemento novo. NUNCA remove um
    unique/index existente que nao apareca no JSON de entrada (mesma
    semantica aditiva de "fields"/"primaryKey", acima). Vinculado ao slot
    ITable.StructureMergeFromJSON via clausula de resolucao de interface (ver
    seccao public da classe). }
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
    TableName(LObj.Get('table', FTableName));
    LFieldsNode := LObj.Find('fields');
    if Assigned(LFieldsNode) and (LFieldsNode is TJSONArray) then
      inherited StructureMergeFromJSON(LFieldsNode.AsJSON);
    LPkNode := LObj.Find('primaryKey');
    if Assigned(LPkNode) and (LPkNode is TJSONArray) then
    begin
      LPkArr := TJSONArray(LPkNode);
      for I := 0 to LPkArr.Count - 1 do
      begin
        LField := GetFields(LPkArr.Items[I].AsString);
        if LField <> nil then
          LField.IsPKey(True);
      end;
    end;
    LUniquesNode := LObj.Find('uniques');
    if Assigned(LUniquesNode) and (LUniquesNode is TJSONArray) then
    begin
      LUniquesArr := TJSONArray(LUniquesNode);
      for I := 0 to LUniquesArr.Count - 1 do
      begin
        if not (LUniquesArr.Items[I] is TJSONObject) then
          Continue;
        LUniqueObj := TJSONObject(LUniquesArr.Items[I]);
        LName := LUniqueObj.Get('name', '');
        LPos := TableIndexOfUnique(FUniques, LName);
        if LPos < 0 then
        begin
          SetLength(FUniques, Length(FUniques) + 1);
          LPos := High(FUniques);
          FUniques[LPos].Name := LName;
        end;
        FUniques[LPos].Columns := TableSchemaColumnsFromJSON(LUniqueObj.Find('columns'));
      end;
    end;
    LIndexesNode := LObj.Find('indexes');
    if Assigned(LIndexesNode) and (LIndexesNode is TJSONArray) then
    begin
      LIndexesArr := TJSONArray(LIndexesNode);
      for I := 0 to LIndexesArr.Count - 1 do
      begin
        if not (LIndexesArr.Items[I] is TJSONObject) then
          Continue;
        LIndexObj := TJSONObject(LIndexesArr.Items[I]);
        LName := LIndexObj.Get('name', '');
        LPos := TableIndexOfIndex(FIndexes, LName);
        if LPos < 0 then
        begin
          SetLength(FIndexes, Length(FIndexes) + 1);
          LPos := High(FIndexes);
          FIndexes[LPos].Name := LName;
        end;
        FIndexes[LPos].Columns := TableSchemaColumnsFromJSON(LIndexObj.Find('columns'));
        FIndexes[LPos].Unique := LIndexObj.Get('unique', False);
      end;
    end;
  finally
    LObj.Free;
  end;
end;
{$ELSE}
var
  LVal: TJSONValue;
  LObj: TJSONObject;
  LFieldsVal, LPkVal, LUniquesVal, LIndexesVal: TJSONValue;
  LPkArr, LUniquesArr, LIndexesArr: TJSONArray;
  LUniqueObj, LIndexObj: TJSONObject;
  I, LPos: Integer;
  LName: string;
  LField: IField;
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
    TableName(LObj.GetValue<string>('table', FTableName));
    LFieldsVal := LObj.GetValue('fields');
    if Assigned(LFieldsVal) and (LFieldsVal is TJSONArray) then
      inherited StructureMergeFromJSON(LFieldsVal.ToJSON);
    LPkVal := LObj.GetValue('primaryKey');
    if Assigned(LPkVal) and (LPkVal is TJSONArray) then
    begin
      LPkArr := TJSONArray(LPkVal);
      for I := 0 to LPkArr.Count - 1 do
      begin
        LField := GetFields(LPkArr.Items[I].Value);
        if LField <> nil then
          LField.IsPKey(True);
      end;
    end;
    LUniquesVal := LObj.GetValue('uniques');
    if Assigned(LUniquesVal) and (LUniquesVal is TJSONArray) then
    begin
      LUniquesArr := TJSONArray(LUniquesVal);
      for I := 0 to LUniquesArr.Count - 1 do
      begin
        if not (LUniquesArr.Items[I] is TJSONObject) then
          Continue;
        LUniqueObj := TJSONObject(LUniquesArr.Items[I]);
        LName := LUniqueObj.GetValue<string>('name', '');
        LPos := TableIndexOfUnique(FUniques, LName);
        if LPos < 0 then
        begin
          SetLength(FUniques, Length(FUniques) + 1);
          LPos := High(FUniques);
          FUniques[LPos].Name := LName;
        end;
        FUniques[LPos].Columns := TableSchemaColumnsFromJSON(LUniqueObj.GetValue('columns'));
      end;
    end;
    LIndexesVal := LObj.GetValue('indexes');
    if Assigned(LIndexesVal) and (LIndexesVal is TJSONArray) then
    begin
      LIndexesArr := TJSONArray(LIndexesVal);
      for I := 0 to LIndexesArr.Count - 1 do
      begin
        if not (LIndexesArr.Items[I] is TJSONObject) then
          Continue;
        LIndexObj := TJSONObject(LIndexesArr.Items[I]);
        LName := LIndexObj.GetValue<string>('name', '');
        LPos := TableIndexOfIndex(FIndexes, LName);
        if LPos < 0 then
        begin
          SetLength(FIndexes, Length(FIndexes) + 1);
          LPos := High(FIndexes);
          FIndexes[LPos].Name := LName;
        end;
        FIndexes[LPos].Columns := TableSchemaColumnsFromJSON(LIndexObj.GetValue('columns'));
        FIndexes[LPos].Unique := LIndexObj.GetValue<Boolean>('unique', False);
      end;
    end;
  finally
    LObj.Free;
  end;
end;
{$ENDIF}

function TTable.TableFromFullJSON(const AJSON: string): ITable;
var
  LStructure, LData: string;
begin
  { Onda S4 (ADITIVO) - decompoe via JSONExtractMember (SSOT, Database.
    Helpers.JSON) e delega, NESTA ORDEM (estrutura antes de dado - FromJSON
    hidrata por NOME de coluna sobre os campos JA CRIADOS pela estrutura),
    aos metodos "Table*" irmaos (chamada directa, sem indirecao por
    interface - ambos nao-virtuais). Tolerante: chave ausente nao aplica
    esse eixo. }
  Result := Self;
  LStructure := JSONExtractMember(AJSON, 'structure');
  if LStructure <> '' then
    TableStructureFromJSON(LStructure);
  LData := JSONExtractMember(AJSON, 'data');
  if LData <> '' then
    TableFromJSON(LData);
end;

function TTable.TableMergeFullFromJSON(const AJSON: string): ITable;
var
  LStructure, LData: string;
begin
  { Onda S4 (ADITIVO) - mesma decomposicao/ordem de TableFromFullJSON,
    delegando aos "patch" TableStructureMergeFromJSON/TableMergeFromJSON. }
  Result := Self;
  LStructure := JSONExtractMember(AJSON, 'structure');
  if LStructure <> '' then
    TableStructureMergeFromJSON(LStructure);
  LData := JSONExtractMember(AJSON, 'data');
  if LData <> '' then
    TableMergeFromJSON(LData);
end;

function TTable.ToFullJSON: string;
begin
  { Onda S4 (ADITIVO) - COMPOE os 2 eixos JA EXISTENTES (StructureToJSON/
    ToJSON), sem reimplementar nenhum dos 2. }
  Result := '{"structure":' + StructureToJSON + ',"data":' + ToJSON + '}';
end;

function TTable.TableImport(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): ITable;
begin
  { Onda S4 (ADITIVO) - despacha pelas 2 flags para o metodo "Table*" ja
    existente correspondente. }
  Result := Self;
  if AWithData then
  begin
    if AMerge then
      TableMergeFullFromJSON(AJSON)
    else
      TableFromFullJSON(AJSON);
  end
  else
  begin
    if AMerge then
      TableStructureMergeFromJSON(AJSON)
    else
      TableStructureFromJSON(AJSON);
  end;
end;

function TTable.Export(const AWithData: Boolean): string;
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
function TTable.Export(const AWithData: Boolean; const AQuery: IQueryBuilder): string;
var
  LFullJSON: string;
begin
  { Onda S4 (ADITIVO) - quando AWithData=True e AQuery<>nil, a parte "data"
    vem das LINHAS de AQuery.Execute (TDataSet), serializadas via
    TDataSetSerializeHelper.ToJSONArrayString - NAO do ToJSON do modelo em
    memoria - delegado a TryExportQueryData (Database.Helpers.Export, SSOT
    partilhado com ISchema/IDatabase.Export; isola Data.DB/Serialize numa
    unit sem TRowStatus, ver comentario do uses no topo do ficheiro).
    Connection: se AQuery ja tiver a sua propria Connection(v) injectada,
    essa prevalece; senao e injectada a Connection fluente desta ITable
    (fallback FConnection, mesmo criterio de Execute/QueryBuilder, ver corpo
    de TTable.QueryBuilder abaixo). Sem Connection viva (nem em AQuery, nem
    nesta ITable), AQuery=nil, ou AQuery.Execute devolve nil, cai
    graciosamente no ToFullJSON (comportamento base) - NUNCA lanca por falta
    de conexao (ao contrario de AQuery.Execute cru, que lanca
    EDatabaseQueryBuilderException). }
  if not AWithData then
    Exit(StructureToJSON);
  if TryExportQueryData(AQuery, FConnection, StructureToJSON, LFullJSON) then
    Exit(LFullJSON);
  Result := ToFullJSON;
end;
{$ENDIF}

class function TTable.New(const AFields: IFields; const ATableName: string): ITable;
var
  LArr: TFieldArray;
  i: Integer;
begin
  { FIX (13/07/2026, bug AV Find/Onda 4): a construcao anterior usava uma
    variavel de classe crua (LTable: TTable) para chamar metodos fluentes que
    devolvem interface (AddField/DatabaseTypes/TableName) ANTES de capturar o
    objeto em Result (ITable). Cada chamada fluente descartada fazia o
    refcount subir 0->1 (Result:=Self dentro do metodo) e descer 1->0 no fim
    da expressao -> TInterfacedObject destruia o objeto prematuramente na
    PRIMEIRA chamada (AddField do 1o campo), e as chamadas seguintes operavam
    sobre memoria ja libertada (use-after-free/double-free), corrompendo o
    heap e perdendo campos (ex.: o PK "id") - manifestava-se como
    EAccessViolation mais tarde, nalgum ponto nao relacionado (Find). Fix:
    capturar em Result logo apos o Create (refcount>=1 desde o inicio) e
    encadear tudo atraves de Result (interface), nunca de uma var de classe
    crua. }
  Result := TTable.Create;
  if AFields <> nil then
  begin
    LArr := AFields.GetFieldsList;
    for i := 0 to Length(LArr) - 1 do
      Result.AddField(LArr[i]);
    Result.DatabaseTypes(AFields.DatabaseTypes);
  end;
  Result.TableName(ATableName);
end;

class function TTable.New: ITable;
begin
  Result := TTable.Create;
end;

class function TTable.NewForDDL(ADatabaseType: TDatabaseTypes): ITable;
begin
  Result := TTable.New;
  Result.TableName('test_ddl').DatabaseTypes(ADatabaseType)
    .AddField('id', 'integer', False)
    .AddField('nome', 'varchar(100)', True);
  Result.Fields('id').IsPKey(True);
end;

class function TTable.NewForDML(ADatabaseType: TDatabaseTypes): ITable;
begin
  Result := TTable.New;
  Result.TableName('test_dml').DatabaseTypes(ADatabaseType)
    .AddField('id', 'integer', False)
    .AddField('nome', 'varchar(100)', True);
  Result.Fields('id').IsPKey(True);
  Result.Fields('id').SetColumnValue(1);
  Result.Fields('nome').SetColumnValue('Test DML');
end;

{$IFDEF USE_DATABASE}
function TTable.QueryBuilder: IQueryBuilder;
begin
  { Onda 7 - lancador PRE-CONFIGURADO com a propria tabela (From(FTableName))
    e a conexao fluente desta ITable (FConnection, mesmo fallback usado por
    Execute); o caller encadeia .Where/.OrderBy/.Limit/etc a partir daqui. }
  Result := Database.QueryBuilder.TQueryBuilder.New.Connection(FConnection).From(FTableName);
end;
{$ENDIF}

{$IFDEF USE_ENTITY_MANAGER}
function TTable.EntityManager: IEntityManager;
begin
  { Onda 7 - EntityManager MAPEADO a esta PROPRIA ITable (Table(Self), sem
    MapTable/discovery via ICatalogReader - reusa os campos/valores ja presentes
    nesta instancia). Resolucao de ciclo: TTable.pas nao pode `uses
    Database.EntityManager` diretamente (essa unit ja usa Database.Table
    para TTable.New) - chama a factory-function registada
    GTableEntityManagerFactory (Databases.Interfaces, atribuida na
    `initialization` de Database.EntityManager.pas); nil se essa unit nunca
    foi linkada no executavel. }
  Result := nil;
  if Assigned(GTableEntityManagerFactory) then
    Result := GTableEntityManagerFactory(Self);
end;
{$ENDIF}

function TTable.UnitOfWork: IUnitOfWork;
begin
  { Onda 7 - lancador so Connection-bound (FConnection, mesmo fallback usado
    por Execute); o REGISTO da propria tabela (RegisterNew/Dirty/Deleted)
    fica ao cargo do caller. Ungated - Database.UnitOfWork.pas nao depende
    de USE_DATABASE. }
  Result := Database.UnitOfWork.TUnitOfWork.New.Connection(FConnection);
end;

end.
