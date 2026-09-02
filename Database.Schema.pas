{ =============================================================================
  Database.Schema - Schema (TSchema, ISchema)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.3.1
  FileVersion:    1.10.0
  Author:         Claiton de Souza Linhares
  Date:           30/07/2026

  Changelog (file):
  - 1.10.0 (30/07/2026): auditoria adversarial (owner) ao ApplyStructure -
    mascarava idempotencia real fora do PostgreSQL. 2 fixes: (#1(CRITICO)/#3)
    ApplyStructure ganha try/except ISOLADO por-objecto em TODOS os passos
    (Sync das tabelas, cada FK, cada view, cada procedure/function, cada
    trigger, cada rule) - ANTES, uma unica excepcao (tipicamente a FK - ver
    comentario do passo (2) no corpo do metodo, ForeignKeyExists so' e'
    fiavel em PostgreSQL) ABORTAVA todos os passos seguintes da MESMA
    chamada; agora cada objecto e' independente, e uma 2a ApplyStructure
    sobre a MESMA estrutura, em QUALQUER motor, e' um no-op seguro (nunca
    lanca) - prova de idempotencia real, nao so' em PostgreSQL. (#2)
    SchemaAddTableToDefinition passa a usar IField.Precision/Scale (quando
    Precision>0) em vez de so' Size ao chamar ISchemaTable.AddColumn (ganhou
    o parametro AScale, ver Databases.Interfaces 3.3.1/Database.Synchronize
    2.6.0) - antes, colunas DECIMAL/NUMERIC com escala real (ex.: NUMERIC
    (18,4)) materializavam sempre DECIMAL(18,0) por omissao, porque o
    tamanho delas vive em Precision/Scale, nao em Size (Size fica 0 - ver
    Database.Field.ParseColumnTypeDimensions). Zero mudanca nos restantes
    metodos; gate: 4 alvos EXIT=0 + test_serialize (des-mascarado) contra
    os 7 bancos reais.
  - 1.9.0 (30/07/2026): Onda S3b (ADITIVO - MATERIALIZACAO do merge, ver
    Databases.Interfaces 3.3.0) - ApplyStructure(AConnection): ISchema
    aplica a estrutura em memoria (FGroups/FViews/FRoutines/FTriggers/
    FRules) a uma conexao real, IDEMPOTENTE, ZERO SQL novo: (1) tabelas via
    bridge SchemaAddTableToDefinition (novo helper privado - GetFieldsList+
    Uniques/Indexes desta propria ITable, SEM round-trip JSON) + TSynchronize.
    Sync; (2) FK via ITable.AddForeignKey(conn,...), depois de (1); (3)
    views/(4) procedures+functions/(5) triggers/(6) rules via os lancadores
    Connection-bound ja existentes (TViews/TProcedures/TFunctions/TTriggers/
    TRules - mesmo motor de Database.pas). Novo helper SchemaColumnTypeToKind
    (heuristica ColumnType RAW -> TSQLColumnKind, UNICA peca genuinamente
    nova - ver comentario completo no corpo). Novo uses (implementation,
    dentro do bloco USE_DATABASE ja existente): Database.Synchronize +
    Database.Views + Database.Procedures + Database.Functions +
    Database.Triggers + Database.Rules. Gate desta onda: so COMPILACAO (4
    alvos) - validacao contra banco real fica para a proxima onda. Zero
    mudanca nos metodos pre-existentes.
  - 1.8.0 (30/07/2026): Onda S4 (ADITIVO - eixo FULL, ver Databases.Interfaces
    3.2.0) - ToFullJSON (COMPOE StructureToJSON+ToJSON)/SchemaFromFullJSON/
    SchemaMergeFullFromJSON (decompoem via Database.Helpers.JSON.
    JSONExtractMember, estrutura antes de dado, delegando DIRECTAMENTE aos
    metodos "Schema*" irmaos ja existentes) + Export(AWithData)/SchemaImport
    ergonomicos, vinculados aos slots ISchema.FromFullJSON/MergeFullFromJSON/
    Import via clausula de resolucao de interface. Novo overload
    Export(AWithData, AQuery: IQueryBuilder), gated USE_DATABASE - delega a
    TryExportQueryData (novo helper Database.Helpers.Export, SSOT
    partilhado com ITable/IDatabase.Export - isola Data.DB/Serialize numa
    unit PROPRIA sem TRowStatus, ver comentario completo no uses de
    Database.Table.pas) - a Connection de fallback usa o GETTER publico
    Connection (herdado de TTables), NAO um campo FConnection directo
    (privado a Database.Tables.pas, unit diferente). Novo uses
    (implementation, dentro do bloco USE_DATABASE ja existente):
    Database.Helpers.Export. Zero mudanca nos metodos pre-existentes.
  - 1.7.0 (29/07/2026): Onda S3 (ADITIVO - eixo SQL, ver Databases.Interfaces
    3.1.0) - ToDDL: string (script DDL completo do schema, na ordem tabelas ->
    views -> procedures/functions -> triggers -> rules). ACHADO durante a
    implementacao: o GetTablesList herdado de TTables (FList) e' um contentor
    ESTRUTURAL PARALELO a FGroups, so alimentado por LoadFromConnection
    (introspeccao de conexao viva) - NUNCA por Structure*FromJSON, o UNICO
    caminho fluente hoje para popular FUniques/FIndexes/FTriggers/FRules/
    FRoutines/FViews; usar FList em ToDDL deixaria o script SEMPRE vazio de
    tabelas para qualquer schema construido pelo eixo JSON (o cenario "golden/
    SQL sem servidor" que esta Onda visa). CORRIGIDO: tabelas vem de FGroups
    (1 ITable "representante" por grupo - FGroups[I].group.GetTablesList[0] -
    MESMA fonte ja usada por StructureToJSON/SchemaStructureFromJSON, Onda
    S2-b2/B-d). Views/procedures/functions/triggers/rules a partir de
    FViews/FRoutines/FTriggers/FRules via IDialect.View/Routine/Trigger/Rule.
    CreateSQL. Novo helper de unit SchemaAppendDDLStatement (divide '#0' -
    PostgreSQL FUNCTION+TRIGGER/RULE - e acrescenta ';' por statement, mesma
    tecnica de split ja usada por TTriggers.ExecMulti). ToSQL: string (DML) -
    MESMO achado exigiu OVERRIDE deliberado de TTables.ToSQL (reintroducao de
    nome, herdar sem override devolveria '' pelo mesmo motivo do FList acima)
    - agrega ITables.ToSQL de cada FGroups[I].group. Zero mudanca nos metodos
    pre-existentes/no MODELO de FGroups (eixo JSON chave-nomeada, inalterado).
  - 1.6.0 (29/07/2026): Onda S2-b2 (ADITIVO - versionamento de banco cobre
    triggers/rules/procedures/functions/views ao nivel do SCHEMA) - novos
    contentores privados FTriggers (TTriggerDefinitionArray)/FRules
    (TRuleDefinitionArray)/FRoutines (TRoutineDefinitionArray, procedures+
    functions unificados por Kind)/FViews (TSchemaViews, Commons.Database.
    Types) - MESMA lacuna que motivou FUniques/FIndexes em Database.Table.pas
    (Onda S2-b1), agora ao nivel do SCHEMA: ate esta onda estes 5 objectos so
    existiam como launchers IMPERATIVOS Connection-bound (IDatabase.Triggers/
    Rules/Procedures/Functions/Views), sem NENHUM contentor que guardasse a
    definicao em si, impossivel de serializar. Reusa INTEGRALMENTE os
    builders zero-SQL ja existentes (ITriggerDefinition/IRuleDefinition/
    IRoutineDefinition, Databases.Interfaces + Database.Trigger/Database.
    Rule/Database.Routine, ambos UNGATED) para TRIGGER/RULE/PROCEDURE/
    FUNCTION - NENHUM tipo paralelo novo (regra #14); VIEW e' o unico dos 5
    sem builder proprio, novo record TSchemaView/TSchemaViews (Commons.
    Database.Types 1.11.0, dado puro Name/SelectSQL/OrReplace, mesmo padrao
    de TSchemaUnique/TSchemaIndex). StructureToJSON passa a emitir
    +"triggers"/+"rules"/+"procedures"/+"functions"/+"views" (procedures/
    functions particionam o MESMO FRoutines por Kind); SchemaStructureFromJSON
    reconstroi os 4 contentores por completo (nil+substitui, mesma semantica
    de FGroups); SchemaStructureMergeFromJSON aplica PATCH aditivo POR NOME
    (SchemaIndexOfTrigger/Rule/Routine/View, novos helpers de unit) -
    existente e substituido no lugar (objecto completo, mesma granularidade
    de FUniques/FIndexes - nao ha merge campo-a-campo dentro do objecto),
    ausente e acrescentado, NUNCA remove. Novos helpers de unit (encode
    generico + decode duplicado por compilador, fpjson vs System.JSON, mesmo
    padrao de TableSchemaColumnsFromJSON): enum<->string (SchemaTrigger*/
    SchemaRule*/SchemaRoutine*/SchemaParamDirection*/SchemaColumnKind*),
    SchemaJSONBoolLiteral, Schema*DefToJSON/Schema*DefFromJSON por tipo, e
    SchemaRoutineLiteralToVariant (reconstroi o Variant original a partir do
    literal SQL ja renderizado, para round-trip fiel do modo rbmReturn de
    IRoutineDefinition.BodyReturn sem re-processar um texto ja rendido).
    Novo uses (interface): Commons.Database.Types (TSchemaView/TSchemaViews);
    novo uses (implementation): Variants/System.Variants (reconstrucao do
    literal RETURN) + Database.Trigger/Database.Rule/Database.Routine
    (factories .New dos builders). Sem API fluente nova de construcao em
    memoria (fora do escopo) - o contentor e' lido/escrito SO pelos 3
    Structure*; sem materializacao no banco (Onda S3b futura). Propagacao
    para ISchemas/IDatabase/IDatabases e' AUTOMATICA e TRANSPARENTE (zero
    mudanca de codigo nesses 3 niveis) - ambos ja delegam integralmente ao
    ISchema.StructureToJSON/StructureFromJSON/StructureMergeFromJSON de cada
    schema (Database.Schemas.pas/Database.pas/Databases.pas, confirmado por
    leitura antes desta onda).
  - 1.5.0 (29/07/2026): Onda S2-a (ADITIVO, simetria To/From/Merge) - ISchema
    ganha StructureMergeFromJSON (SchemaStructureMergeFromJSON, vinculado via
    clausula de resolucao de interface) - PATCH aditivo: localiza (ou CRIA
    via GetOrCreateGroup, nunca remove) o grupo pelo TableName de cada
    elemento de "tables" e delega a ITables.StructureMergeFromJSON nesse
    grupo. Ao contrario de SchemaStructureFromJSON (SetLength(FGroups,0) +
    reconstroi tudo), esta versao preserva os grupos existentes. Zero
    mudanca nos metodos pre-existentes.
  - 1.4.1 (27/07/2026): conformidade F5 (onda C5, M7) - SchemaJSONQuoteString
    local removida; delega ao SSOT unico Database.Helpers.JSON.JSONQuoteString
    (regra #14).
  - 1.4.0 (25/07/2026): Onda R2.1 (f5-repair) - ISchema reduzido a
    responsabilidade PROPRIA; DropTable/RenameTable -> ITables (ja
    implementados por TTables, herdados por TSchema sem alteracao), Views/
    Procedures -> IViews/IProcedures, lancadores Synchronize/QueryBuilder/
    Metadata removidos (duplicatas de IDatabase). REMOVIDOS (declaracao +
    implementacao): DropTableSQL/RenameTableSQL/DropTable/RenameTable;
    CreateViewSQL/DropViewSQL/CreateView/DropView; CreateProcedureSQL/
    DropProcedureSQL/CreateProcedure/DropProcedure; Synchronize/QueryBuilder/
    Metadata. `uses` (implementation, bloco USE_DATABASE) perdeu Database.
    Synchronize/Database.QueryBuilder/Database.CatalogReader (orfaos - nenhum
    metodo restante os referencia; Databases.Interfaces/Database.
    Dialect mantidos, ainda usados por CreateSchemaSQL/DropSchemaSQL).
    Mantido: SchemaName/Database (get/set), CreateSchemaSQL/DropSchemaSQL/
    CreateSchema/DropSchema, bloco de serialize completo. Breaking
    INTENCIONAL (ver Databases.Interfaces.pas 2.13.0) - NAO compilado nesta
    onda (remocao cirurgica; correcao de consumidores fica para a onda
    seguinte).
  - 1.3.0 (15/07/2026): Onda 7 (camada de lancadores fluentes, ADITIVO;
    gated USE_DATABASE - ICatalogReader/ISynchronize/IQueryBuilder so existem sob
    esse define) - ISchema ganha Synchronize (Database.Synchronize.
    TSynchronize.New(Connection)) + QueryBuilder (Database.QueryBuilder.
    TQueryBuilder.New.Connection(Connection) - sem From, ISchema nao e uma
    unica tabela) + Metadata (Database.CatalogReader.TCatalogReader.New(Connection)),
    todos Connection-bound (getter herdado de TTables, sem ciclo - nenhuma
    das 3 units de operacao usa Database.Schema). Novo uses (implementation,
    dentro do bloco USE_DATABASE ja existente): Database.Synchronize +
    Database.QueryBuilder + Database.CatalogReader.
  - 1.2.0 (13/07/2026): Fatia B-d (continuacao Onda 4-cont, revisao F5) -
    serializacao PROPRIA do Schema em formato CHAVE-NOMEADA (ver comentario
    completo em Database.Schema.Interfaces.ISchema): FGroups (novo campo,
    TSchemaGroups) mantem um grupo ITables INDEPENDENTE por TableName -
    ToJSON/FromJSON/MergeFromJSON delegam integralmente a reconciliacao por
    PK/object_state de cada grupo (ja existente em ITables, Fatia B-c), sem
    misturar tabelas diferentes; StructureToJSON/StructureFromJSON idem para
    o eixo estrutura (1 registo-molde por grupo). Helper local de escaping
    RFC 8259 (SchemaJSONQuoteString) - mesma tecnica dos escapers da Fatia
    B-a/B-b/B-c, duplicado localmente por nao ser exportado por aquelas
    units; NUNCA QuotedStr para JSON (bug-293). DDL de nivel schema
    (CreateSchemaSQL/DropSchemaSQL/CreateSchema/DropSchema) via
    TDialect.ForDatabaseType (novo, Database.Dialect) - gated por
    USE_DATABASE (submodulo Dialects), degrada graciosamente (vazio/0)
    quando OFF.
  - 1.1.0 (12/07/2026): absorcao v3 (FASE 5 Onda 5.1) - uses
    Providers.Connection.Interfaces -> Connections.Interfaces; header v3.
  - 1.0.0 (07/04/2026): Compatibilidade FPC: MODE DELPHI adicionado
    antes da seção interface.
  ============================================================================= }

unit Database.Schema;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}
interface

{$I ../../../ORM.Defines.inc}

uses
  Database.Tables,
  Databases.Interfaces,
  Connections.Interfaces,
  Commons.Database.Types;

type
  { Grupo NOMEADO de registos de UMA tabela do schema (Fatia B-d) - o VALOR e
    uma ITables independente (reusa integralmente a reconciliacao por PK/
    object_state ja existente em ITables, Fatia B-c) DENTRO desse grupo. }
  TSchemaGroup = record
    tablename: string;
    group: ITables;
  end;

  TSchemaGroups = array of TSchemaGroup;

  { Onda S2-b2 (versionamento de banco - triggers/rules/procedures/functions/
    views ao nivel do SCHEMA) - arrays de DEFINICOES reutilizando os builders
    fluentes zero-SQL JA EXISTENTES (ITriggerDefinition/IRuleDefinition/
    IRoutineDefinition, Databases.Interfaces, UNGATED - Database.Trigger/
    Database.Rule/Database.Routine implementam .New) - NENHUM tipo paralelo
    novo (regra #14 anti-duplicacao). PROCEDURES e FUNCTIONS reusam o MESMO
    IRoutineDefinition (distinguidos pelo campo Kind, rkProcedure/rkFunction)
    - um UNICO contentor FRoutines, tal como o proprio builder ja unifica os
    dois. Tipos declarados AQUI (nao em Databases.Interfaces) por serem
    detalhe de implementacao PRIVADO de TSchema - mesmo criterio ja usado por
    TSchemaGroup/TSchemaGroups, acima (nao fazem parte da API publica de
    ISchema; o contentor e' lido/escrito SO pelos 3 Structure*). }
  TTriggerDefinitionArray = array of ITriggerDefinition;
  TRuleDefinitionArray    = array of IRuleDefinition;
  TRoutineDefinitionArray = array of IRoutineDefinition;

  TSchema = class(TTables, ISchema)
  private
    FGroups: TSchemaGroups;
    { Onda S2-b2 (ADITIVO) - MODELO em memoria dos objectos de nivel
      schema/banco ate agora so acessiveis como launchers IMPERATIVOS
      Connection-bound (IDatabase.Triggers/Rules/Procedures/Functions/Views) -
      sem NENHUM contentor que guardasse a definicao em si, impossivel de
      serializar (mesma lacuna que motivou FUniques/FIndexes em
      Database.Table.pas, Onda S2-b1, ao nivel da TABELA). Populado
      exclusivamente por SchemaStructureFromJSON (Clear+reconstroi tudo)/
      SchemaStructureMergeFromJSON (patch aditivo POR NOME, nunca remove) e
      lido por StructureToJSON - esta onda cobre SO o round-trip de
      estrutura (sem API fluente nova de construcao em memoria, fora do
      escopo; sem materializacao no banco, Onda S3b futura). }
    FTriggers: TTriggerDefinitionArray;
    FRules: TRuleDefinitionArray;
    FRoutines: TRoutineDefinitionArray;  // procedures + functions (Kind distingue)
    FViews: TSchemaViews;                // dado puro (Commons.Database.Types) - sem builder proprio
    function IndexOfGroupName(const AName: string): Integer;
    { Localiza o grupo pelo TableName (case-insensitive); cria (TTables.New,
      vazio) e regista em FGroups se ainda nao existir. }
    function GetOrCreateGroup(const AName: string): ITables;
    { Fatia B-d - implementacoes concretas de FromJSON/MergeFromJSON/
      StructureFromJSON com nome DISTINTO do herdado de ITables (retorno
      ISchema em vez de ITables; Object Pascal nao permite 2 metodos com o
      MESMO nome e MESMOS parametros diferindo so no retorno) - vinculadas
      aos slots ISchema.FromJSON/MergeFromJSON/StructureFromJSON via
      clausula de resolucao de interface na seccao public (mesma tecnica do
      B-b para ITable sobre IFields).}
    function SchemaFromJSON(const AJSON: string): ISchema;
    function SchemaMergeFromJSON(const AJSON: string): ISchema;
    function SchemaStructureFromJSON(const AJSON: string): ISchema;
    { Onda S2-a (ADITIVO) - implementacao concreta de StructureMergeFromJSON,
      mesmo padrao de nome distinto + clausula de resolucao de interface das
      3 acima. }
    function SchemaStructureMergeFromJSON(const AJSON: string): ISchema;
    { Onda S4 (ADITIVO) - implementacoes concretas de FromFullJSON/
      MergeFullFromJSON/Import com nome DISTINTO do herdado de ITables
      (retorno ISchema em vez de ITables) - vinculadas aos slots
      ISchema.FromFullJSON/MergeFullFromJSON/Import via clausula de
      resolucao de interface na seccao public (mesma tecnica das 4 acima).
      Chamam DIRECTAMENTE os metodos "Schema*" irmaos (nao-virtuais). }
    function SchemaFromFullJSON(const AJSON: string): ISchema;
    function SchemaMergeFullFromJSON(const AJSON: string): ISchema;
    function SchemaImport(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): ISchema;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: ISchema;
    function SchemaName(const AValue: string): ISchema; overload;
    function SchemaName: string; overload;
    function Database(const AValue: string): ISchema; overload;
    function Database: string; overload;

    { Serialize PROPRIA do Schema (Fatia B-d) - ver comentario completo em
      Database.Schema.Interfaces.ISchema. ToJSON/StructureToJSON tem a MESMA
      assinatura (string) do herdado de ITables - sobrepostos por simples
      reintroducao de nome (mesmo padrao ja usado por ITable.ToJSON/
      StructureToJSON, Fatia B-b). FromJSON/MergeFromJSON/StructureFromJSON
      precisam de retorno ISchema (covariante) - resolvidos via clausula de
      resolucao de interface para as implementacoes de nome distinto
      declaradas na seccao private. }
    function ToJSON: string;
    function StructureToJSON: string;
    function ISchema.FromJSON = SchemaFromJSON;
    function ISchema.MergeFromJSON = SchemaMergeFromJSON;
    function ISchema.StructureFromJSON = SchemaStructureFromJSON;
    function ISchema.StructureMergeFromJSON = SchemaStructureMergeFromJSON;

    { DDL de nivel schema (Fatia B-d) - ver comentario completo em
      Database.Schema.Interfaces.ISchema. }
    function CreateSchemaSQL: string;
    function DropSchemaSQL: string;
    function CreateSchema(const AConnection: IConnection): Integer;
    function DropSchema(const AConnection: IConnection): Integer;

    { Onda S3 - eixo SQL (ver comentario completo em
      Databases.Interfaces.ISchema.ToDDL). }
    function ToDDL: string;
    { Onda S3 - OVERRIDE deliberado de TTables.ToSQL (herdado seria '' -
      opera sobre FList, vazio para schemas construidos pelo eixo JSON; ver
      comentario completo no corpo do metodo). }
    function ToSQL: string;

    { Onda S3b (ADITIVO) - MATERIALIZACAO do merge (ver comentario completo
      em Databases.Interfaces.ISchema.ApplyStructure). }
    function ApplyStructure(const AConnection: IConnection): ISchema;

    { Onda S4 (ADITIVO) - eixo FULL - ver comentario completo em
      Databases.Interfaces.ISchema. ToFullJSON tem a MESMA assinatura
      (string) do herdado de ITables - sobreposto por simples reintroducao
      de nome (mesmo padrao de ToJSON/StructureToJSON, acima).
      FromFullJSON/MergeFullFromJSON precisam de retorno ISchema
      (covariante) - resolvidos via clausula de resolucao de interface para
      as implementacoes de nome distinto declaradas na seccao private. }
    function ToFullJSON: string;
    function ISchema.FromFullJSON = SchemaFromFullJSON;
    function ISchema.MergeFullFromJSON = SchemaMergeFullFromJSON;

    { Export/Import ergonomicos (Onda S4, ADITIVO) - ver comentario completo
      em Databases.Interfaces.ITable.Export/Import (mesma semantica, incl. o
      overload Export(AWithData, AQuery)). Import precisa de retorno ISchema
      (covariante), resolvido via clausula de resolucao de interface. }
    function Export(const AWithData: Boolean): string; overload;
{$IFDEF USE_DATABASE}
    function Export(const AWithData: Boolean; const AQuery: IQueryBuilder): string; overload;
{$ENDIF}
    function ISchema.Import = SchemaImport;
  end;

{ Onda 13A.3 (FASE 13 GraphQL) - PROMOCAO para a interface (autorizada pelo
  owner 11/08/2026 via patch). Mudanca puramente ADITIVA: o corpo permanece
  inalterado na implementation, so passa a ser visivel fora desta unit.
  Classifica um ColumnType RAW dialect-specific (ex.: 'NUMERIC(18,4)',
  'VARCHAR(40)') no enum abstracto TSQLColumnKind. Reusado pelo GraphQL
  SchemaFactory (Modulos/GraphQL/Server) para mapear coluna -> scalar GraphQL,
  evitando duplicar a heuristica (regra #14 anti-duplicacao). Patch versionado
  em .workspace/patches/graphql-13a3-promote-schemacolumntypetokind/. }
function SchemaColumnTypeToKind(const AColumnType: string; const AIsIdentity: Boolean): TSQLColumnKind;

implementation

uses
{$IF DEFINED(FPC)}
  SysUtils, Variants, fpjson, jsonparser,
{$ELSE}
  System.SysUtils, System.Variants, System.JSON,
{$ENDIF}
  Commons.Types,
  Database.Table,
  Database.Helpers.JSON,
  { Onda S2-b2 - builders zero-SQL reutilizados (ver comentario da seccao
    private/type, acima); UNGATED, sem dependencia de USE_DATABASE. }
  Database.Trigger,
  Database.Rule,
  Database.Routine
{$IFDEF USE_DATABASE}
  , Database.Dialect
  , Database.CatalogReader    // motor de catalogo centralizado (SSOT)
  { Onda S4 - Export(AWithData, AQuery) delega a TryExportQueryData
    (Database.Helpers.Export - SSOT partilhado com ITable/IDatabase.Export;
    isola Data.DB/Serialize numa unit PROPRIA, sem TRowStatus, ver
    comentario completo no uses de Database.Table.pas). }
  , Database.Helpers.Export
  { Onda S3b - ApplyStructure (materializacao do merge): TSynchronize/
    TSchemaDefinition (tabelas+colunas+PK+uniques+indexes, idempotente) +
    os LANCADORES Connection-bound ja existentes para views/procedures/
    functions/triggers/rules (mesmo motor que IDatabase.Views/Procedures/
    Functions/Triggers/Rules ja usa - ver Database.pas). }
  , Database.Synchronize
  , Database.Views
  , Database.Procedures
  , Database.Functions
  , Database.Triggers
  , Database.Rules
{$ENDIF}
  ;

{ Escaper RFC 8259 - Onda C5 (M7, conformidade F5): delega ao SSOT unico
  Database.Helpers.JSON.JSONQuoteString (antes copia local
  SchemaJSONQuoteString - regra #14). Usado so para as CHAVES do objeto
  chave-nomeada (TableName/SchemaName) - os VALORES sao sempre delegados a
  ITables.ToJSON/ITable.StructureToJSON dos grupos, que ja escapam por
  conta propria. }

{ ===== Onda S2-b2 - helpers de serializacao dos objectos de nivel SCHEMA/
  BANCO (triggers/rules/procedures/functions/views), RFC 8259, NUNCA
  QuotedStr (bug-293). Bool literal local (SchemaJSONBoolLiteral) - Database.
  Helpers.JSON so centraliza o escaper de STRING (JSONQuoteString); mesmo
  criterio ja usado por TableJSONBoolLiteral (Database.Table.pas). ===== }

function SchemaJSONBoolLiteral(const AValue: Boolean): string;
begin
  if AValue then
    Result := 'true'
  else
    Result := 'false';
end;

{ ---- enum <-> string (nomes estaveis no JSON, independentes da ordinal do
  enum Pascal) ---- }

function SchemaTriggerTimingToStr(const AValue: TTriggerTiming): string;
begin
  case AValue of
    ttBefore:    Result := 'before';
    ttInsteadOf: Result := 'insteadOf';
  else
    Result := 'after';
  end;
end;

function SchemaStrToTriggerTiming(const AValue: string): TTriggerTiming;
begin
  if CompareText(AValue, 'before') = 0 then
    Result := ttBefore
  else if CompareText(AValue, 'insteadOf') = 0 then
    Result := ttInsteadOf
  else
    Result := ttAfter;
end;

function SchemaTriggerEventToStr(const AValue: TTriggerEvent): string;
begin
  case AValue of
    teUpdate: Result := 'update';
    teDelete: Result := 'delete';
  else
    Result := 'insert';
  end;
end;

function SchemaStrToTriggerEvent(const AValue: string): TTriggerEvent;
begin
  if CompareText(AValue, 'update') = 0 then
    Result := teUpdate
  else if CompareText(AValue, 'delete') = 0 then
    Result := teDelete
  else
    Result := teInsert;
end;

{ Codifica o SET TTriggerEvents como CSV de strings quotadas (SEM colchetes -
  mesmo padrao "encode generico" de TableSchemaColumnsToJSON, Database.
  Table.pas - o chamador envolve em [...]). }
function SchemaTriggerEventsToJSON(const AEvents: TTriggerEvents): string;
var
  LEv: TTriggerEvent;
begin
  Result := '';
  for LEv := Low(TTriggerEvent) to High(TTriggerEvent) do
    if LEv in AEvents then
    begin
      if Result <> '' then
        Result := Result + ',';
      Result := Result + JSONQuoteString(SchemaTriggerEventToStr(LEv));
    end;
end;

function SchemaTriggerBodyModeToStr(const AValue: TTriggerBodyMode): string;
begin
  if AValue = tbmRaw then
    Result := 'raw'
  else
    Result := 'empty';
end;

function SchemaStrToTriggerBodyMode(const AValue: string): TTriggerBodyMode;
begin
  if CompareText(AValue, 'raw') = 0 then
    Result := tbmRaw
  else
    Result := tbmEmpty;
end;

function SchemaRuleEventToStr(const AValue: TRuleEvent): string;
begin
  case AValue of
    reSelect: Result := 'select';
    reUpdate: Result := 'update';
    reDelete: Result := 'delete';
  else
    Result := 'insert';
  end;
end;

function SchemaStrToRuleEvent(const AValue: string): TRuleEvent;
begin
  if CompareText(AValue, 'select') = 0 then
    Result := reSelect
  else if CompareText(AValue, 'update') = 0 then
    Result := reUpdate
  else if CompareText(AValue, 'delete') = 0 then
    Result := reDelete
  else
    Result := reInsert;
end;

function SchemaRoutineKindToStr(const AValue: TRoutineKind): string;
begin
  if AValue = rkFunction then
    Result := 'function'
  else
    Result := 'procedure';
end;

function SchemaStrToRoutineKind(const AValue: string): TRoutineKind;
begin
  if CompareText(AValue, 'function') = 0 then
    Result := rkFunction
  else
    Result := rkProcedure;
end;

function SchemaRoutineBodyModeToStr(const AValue: TRoutineBodyMode): string;
begin
  case AValue of
    rbmReturn: Result := 'return';
    rbmRaw:    Result := 'raw';
  else
    Result := 'empty';
  end;
end;

function SchemaStrToRoutineBodyMode(const AValue: string): TRoutineBodyMode;
begin
  if CompareText(AValue, 'return') = 0 then
    Result := rbmReturn
  else if CompareText(AValue, 'raw') = 0 then
    Result := rbmRaw
  else
    Result := rbmEmpty;
end;

function SchemaParamDirectionToStr(const AValue: TParamDirection): string;
begin
  case AValue of
    pdOut:   Result := 'out';
    pdInOut: Result := 'inout';
  else
    Result := 'in';
  end;
end;

function SchemaStrToParamDirection(const AValue: string): TParamDirection;
begin
  if CompareText(AValue, 'out') = 0 then
    Result := pdOut
  else if CompareText(AValue, 'inout') = 0 then
    Result := pdInOut
  else
    Result := pdIn;
end;

function SchemaColumnKindToStr(const AValue: TSQLColumnKind): string;
begin
  case AValue of
    ckBigInt:   Result := 'bigint';
    ckSmallInt: Result := 'smallint';
    ckDecimal:  Result := 'decimal';
    ckFloat:    Result := 'float';
    ckBoolean:  Result := 'boolean';
    ckVarChar:  Result := 'varchar';
    ckChar:     Result := 'char';
    ckText:     Result := 'text';
    ckDate:     Result := 'date';
    ckTime:     Result := 'time';
    ckDateTime: Result := 'datetime';
    ckBlob:     Result := 'blob';
    ckIdentity: Result := 'identity';
  else
    Result := 'integer';
  end;
end;

function SchemaStrToColumnKind(const AValue: string): TSQLColumnKind;
begin
  if CompareText(AValue, 'bigint') = 0 then Result := ckBigInt
  else if CompareText(AValue, 'smallint') = 0 then Result := ckSmallInt
  else if CompareText(AValue, 'decimal') = 0 then Result := ckDecimal
  else if CompareText(AValue, 'float') = 0 then Result := ckFloat
  else if CompareText(AValue, 'boolean') = 0 then Result := ckBoolean
  else if CompareText(AValue, 'varchar') = 0 then Result := ckVarChar
  else if CompareText(AValue, 'char') = 0 then Result := ckChar
  else if CompareText(AValue, 'text') = 0 then Result := ckText
  else if CompareText(AValue, 'date') = 0 then Result := ckDate
  else if CompareText(AValue, 'time') = 0 then Result := ckTime
  else if CompareText(AValue, 'datetime') = 0 then Result := ckDateTime
  else if CompareText(AValue, 'blob') = 0 then Result := ckBlob
  else if CompareText(AValue, 'identity') = 0 then Result := ckIdentity
  else Result := ckInteger;
end;

{ Reconstroi um Variant a partir do LITERAL SQL ja renderizado (FBodyText de
  um IRoutineDefinition em modo rbmReturn, produzido por Database.Routine.
  VariantToRoutineLiteral) - o INVERSO dessa funcao, unico caminho para
  reconstruir fielmente este modo via o setter publico BodyReturn(Variant),
  que RE-renderiza o Variant recebido (nao ha setter que aceite o par
  modo+texto directamente sem passar pela conversao). Dominio coberto (o
  mesmo que VariantToRoutineLiteral produz): NULL, inteiro, decimal
  (separador '.') ou string entre aspas simples (com '' escapado) -
  suficiente para o round-trip JSON->modelo->JSON permanecer estavel
  (materializacao no banco fica para a Onda S3b futura). }
function SchemaRoutineLiteralToVariant(const AText: string): Variant;
var
  LInt: Int64;
  LFloat: Double;
  LFS: TFormatSettings;
  LInner: string;
begin
  if CompareText(Trim(AText), 'NULL') = 0 then
  begin
    Result := Null;
    Exit;
  end;
  if TryStrToInt64(AText, LInt) then
  begin
    Result := LInt;
    Exit;
  end;
{$IF DEFINED(FPC)}
  LFS := DefaultFormatSettings;
{$ELSE}
  LFS := FormatSettings;
{$ENDIF}
  LFS.DecimalSeparator := '.';
  if TryStrToFloat(AText, LFloat, LFS) then
  begin
    Result := LFloat;
    Exit;
  end;
  LInner := AText;
  if (Length(LInner) >= 2) and (LInner[1] = '''') and (LInner[Length(LInner)] = '''') then
  begin
    LInner := Copy(LInner, 2, Length(LInner) - 2);
    LInner := StringReplace(LInner, '''''', '''', [rfReplaceAll]);
  end;
  Result := LInner;
end;

{ ---- encode de objecto completo (generico, so produz texto) ---- }

function SchemaTriggerDefToJSON(const ADef: ITriggerDefinition): string;
begin
  Result := '{"name":' + JSONQuoteString(ADef.Name) +
    ',"onTable":' + JSONQuoteString(ADef.OnTable) +
    ',"timing":' + JSONQuoteString(SchemaTriggerTimingToStr(ADef.Timing)) +
    ',"events":[' + SchemaTriggerEventsToJSON(ADef.Events) + ']' +
    ',"forEachRow":' + SchemaJSONBoolLiteral(ADef.ForEachRow) +
    ',"bodyMode":' + JSONQuoteString(SchemaTriggerBodyModeToStr(ADef.BodyMode)) +
    ',"body":' + JSONQuoteString(ADef.BodyText) +
  '}';
end;

function SchemaRuleDefToJSON(const ADef: IRuleDefinition): string;
begin
  Result := '{"name":' + JSONQuoteString(ADef.Name) +
    ',"onTable":' + JSONQuoteString(ADef.OnTable) +
    ',"event":' + JSONQuoteString(SchemaRuleEventToStr(ADef.Event)) +
    ',"body":' + JSONQuoteString(ADef.BodyText) +
  '}';
end;

function SchemaRoutineParamsToJSON(const AParams: TRoutineParamArray): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AParams) do
  begin
    if Result <> '' then
      Result := Result + ',';
    Result := Result + '{"name":' + JSONQuoteString(AParams[I].Name) +
      ',"kind":' + JSONQuoteString(SchemaColumnKindToStr(AParams[I].Kind)) +
      ',"size":' + IntToStr(AParams[I].Size) +
      ',"direction":' + JSONQuoteString(SchemaParamDirectionToStr(AParams[I].Direction)) +
    '}';
  end;
end;

function SchemaRoutineDefToJSON(const ADef: IRoutineDefinition): string;
begin
  Result := '{"name":' + JSONQuoteString(ADef.Name) +
    ',"kind":' + JSONQuoteString(SchemaRoutineKindToStr(ADef.Kind)) +
    ',"params":[' + SchemaRoutineParamsToJSON(ADef.Params) + ']' +
    ',"returns":' + JSONQuoteString(SchemaColumnKindToStr(ADef.ReturnKind)) +
    ',"returnSize":' + IntToStr(ADef.ReturnSize) +
    ',"bodyMode":' + JSONQuoteString(SchemaRoutineBodyModeToStr(ADef.BodyMode)) +
    ',"body":' + JSONQuoteString(ADef.BodyText) +
  '}';
end;

function SchemaViewDefToJSON(const AView: TSchemaView): string;
begin
  Result := '{"name":' + JSONQuoteString(AView.Name) +
    ',"select":' + JSONQuoteString(AView.SelectSQL) +
    ',"orReplace":' + SchemaJSONBoolLiteral(AView.OrReplace) +
  '}';
end;

{ ---- decode de objecto completo (duplicado por compilador - fpjson
  TJSONObject/TJSONData vs System.JSON TJSONObject/TJSONValue, mesmo padrao
  de TableSchemaColumnsFromJSON/TableJSONNodeToVariant, Database.Table.pas).
  Cada decode cria SEMPRE uma instancia NOVA via o builder (T*Definition.New)
  - tanto SchemaStructureFromJSON ("replace", sempre acrescenta) como
  SchemaStructureMergeFromJSON ("patch por nome", substitui o slot inteiro no
  array quando o nome ja existe) reusam a MESMA funcao; a granularidade do
  patch e' o OBJECTO completo por nome (mesmo criterio ja estabelecido por
  FUniques/FIndexes em Database.Table.pas, Onda S2-b1 - nao ha merge campo-a-
  campo dentro do objecto, so ao nivel do array). }
{$IF DEFINED(FPC)}
function SchemaTriggerDefFromJSON(AObj: TJSONObject): ITriggerDefinition;
var
  LEventsNode: TJSONData;
  LEventsArr: TJSONArray;
  LEvents: TTriggerEvents;
  I: Integer;
begin
  Result := TTriggerDefinition.New;
  Result.Name(AObj.Get('name', ''));
  Result.OnTable(AObj.Get('onTable', ''));
  Result.Timing(SchemaStrToTriggerTiming(AObj.Get('timing', 'after')));
  LEvents := [];
  LEventsNode := AObj.Find('events');
  if Assigned(LEventsNode) and (LEventsNode is TJSONArray) then
  begin
    LEventsArr := TJSONArray(LEventsNode);
    for I := 0 to LEventsArr.Count - 1 do
      Include(LEvents, SchemaStrToTriggerEvent(LEventsArr.Items[I].AsString));
  end;
  if LEvents = [] then
    LEvents := [teInsert];
  Result.Events(LEvents);
  Result.ForEachRow(AObj.Get('forEachRow', True));
  if SchemaStrToTriggerBodyMode(AObj.Get('bodyMode', 'empty')) = tbmRaw then
    Result.BodyRaw(AObj.Get('body', ''))
  else
    Result.BodyEmpty;
end;

function SchemaRuleDefFromJSON(AObj: TJSONObject): IRuleDefinition;
begin
  Result := TRuleDefinition.New;
  Result.Name(AObj.Get('name', ''));
  Result.OnTable(AObj.Get('onTable', ''));
  Result.Event(SchemaStrToRuleEvent(AObj.Get('event', 'insert')));
  Result.BodyRaw(AObj.Get('body', ''));
end;

function SchemaRoutineParamsFromJSON(ANode: TJSONData): TRoutineParamArray;
var
  LArr: TJSONArray;
  LItemObj: TJSONObject;
  I: Integer;
begin
  Result := nil;
  if (not Assigned(ANode)) or (not (ANode is TJSONArray)) then
    Exit;
  LArr := TJSONArray(ANode);
  SetLength(Result, LArr.Count);
  for I := 0 to LArr.Count - 1 do
  begin
    if not (LArr.Items[I] is TJSONObject) then
      Continue;
    LItemObj := TJSONObject(LArr.Items[I]);
    Result[I].Name := LItemObj.Get('name', '');
    Result[I].Kind := SchemaStrToColumnKind(LItemObj.Get('kind', 'integer'));
    Result[I].Size := LItemObj.Get('size', 0);
    Result[I].Direction := SchemaStrToParamDirection(LItemObj.Get('direction', 'in'));
  end;
end;

function SchemaRoutineDefFromJSON(AObj: TJSONObject; const ADefaultKind: TRoutineKind): IRoutineDefinition;
var
  LParams: TRoutineParamArray;
  I: Integer;
begin
  Result := TRoutineDefinition.New;
  Result.Name(AObj.Get('name', ''));
  Result.Kind(SchemaStrToRoutineKind(AObj.Get('kind', SchemaRoutineKindToStr(ADefaultKind))));
  LParams := SchemaRoutineParamsFromJSON(AObj.Find('params'));
  for I := 0 to High(LParams) do
    Result.Param(LParams[I].Name, LParams[I].Kind, LParams[I].Size, LParams[I].Direction);
  Result.Returns(SchemaStrToColumnKind(AObj.Get('returns', 'integer')), AObj.Get('returnSize', 0));
  case SchemaStrToRoutineBodyMode(AObj.Get('bodyMode', 'empty')) of
    rbmReturn: Result.BodyReturn(SchemaRoutineLiteralToVariant(AObj.Get('body', '')));
    rbmRaw:    Result.BodyRaw(AObj.Get('body', ''));
  else
    Result.BodyEmpty;
  end;
end;

function SchemaViewDefFromJSON(AObj: TJSONObject): TSchemaView;
begin
  Result.Name := AObj.Get('name', '');
  Result.SelectSQL := AObj.Get('select', '');
  Result.OrReplace := AObj.Get('orReplace', True);
end;
{$ELSE}
function SchemaTriggerDefFromJSON(AObj: TJSONObject): ITriggerDefinition;
var
  LEventsVal: TJSONValue;
  LEventsArr: TJSONArray;
  LEvents: TTriggerEvents;
  I: Integer;
begin
  Result := TTriggerDefinition.New;
  Result.Name(AObj.GetValue<string>('name', ''));
  Result.OnTable(AObj.GetValue<string>('onTable', ''));
  Result.Timing(SchemaStrToTriggerTiming(AObj.GetValue<string>('timing', 'after')));
  LEvents := [];
  LEventsVal := AObj.GetValue('events');
  if Assigned(LEventsVal) and (LEventsVal is TJSONArray) then
  begin
    LEventsArr := TJSONArray(LEventsVal);
    for I := 0 to LEventsArr.Count - 1 do
      Include(LEvents, SchemaStrToTriggerEvent(LEventsArr.Items[I].Value));
  end;
  if LEvents = [] then
    LEvents := [teInsert];
  Result.Events(LEvents);
  Result.ForEachRow(AObj.GetValue<Boolean>('forEachRow', True));
  if SchemaStrToTriggerBodyMode(AObj.GetValue<string>('bodyMode', 'empty')) = tbmRaw then
    Result.BodyRaw(AObj.GetValue<string>('body', ''))
  else
    Result.BodyEmpty;
end;

function SchemaRuleDefFromJSON(AObj: TJSONObject): IRuleDefinition;
begin
  Result := TRuleDefinition.New;
  Result.Name(AObj.GetValue<string>('name', ''));
  Result.OnTable(AObj.GetValue<string>('onTable', ''));
  Result.Event(SchemaStrToRuleEvent(AObj.GetValue<string>('event', 'insert')));
  Result.BodyRaw(AObj.GetValue<string>('body', ''));
end;

function SchemaRoutineParamsFromJSON(ANode: TJSONValue): TRoutineParamArray;
var
  LArr: TJSONArray;
  LItemObj: TJSONObject;
  I: Integer;
begin
  Result := nil;
  if (not Assigned(ANode)) or (not (ANode is TJSONArray)) then
    Exit;
  LArr := TJSONArray(ANode);
  SetLength(Result, LArr.Count);
  for I := 0 to LArr.Count - 1 do
  begin
    if not (LArr.Items[I] is TJSONObject) then
      Continue;
    LItemObj := TJSONObject(LArr.Items[I]);
    Result[I].Name := LItemObj.GetValue<string>('name', '');
    Result[I].Kind := SchemaStrToColumnKind(LItemObj.GetValue<string>('kind', 'integer'));
    Result[I].Size := LItemObj.GetValue<Integer>('size', 0);
    Result[I].Direction := SchemaStrToParamDirection(LItemObj.GetValue<string>('direction', 'in'));
  end;
end;

function SchemaRoutineDefFromJSON(AObj: TJSONObject; const ADefaultKind: TRoutineKind): IRoutineDefinition;
var
  LParams: TRoutineParamArray;
  I: Integer;
begin
  Result := TRoutineDefinition.New;
  Result.Name(AObj.GetValue<string>('name', ''));
  Result.Kind(SchemaStrToRoutineKind(AObj.GetValue<string>('kind', SchemaRoutineKindToStr(ADefaultKind))));
  LParams := SchemaRoutineParamsFromJSON(AObj.GetValue('params'));
  for I := 0 to High(LParams) do
    Result.Param(LParams[I].Name, LParams[I].Kind, LParams[I].Size, LParams[I].Direction);
  Result.Returns(SchemaStrToColumnKind(AObj.GetValue<string>('returns', 'integer')), AObj.GetValue<Integer>('returnSize', 0));
  case SchemaStrToRoutineBodyMode(AObj.GetValue<string>('bodyMode', 'empty')) of
    rbmReturn: Result.BodyReturn(SchemaRoutineLiteralToVariant(AObj.GetValue<string>('body', '')));
    rbmRaw:    Result.BodyRaw(AObj.GetValue<string>('body', ''));
  else
    Result.BodyEmpty;
  end;
end;

function SchemaViewDefFromJSON(AObj: TJSONObject): TSchemaView;
begin
  Result.Name := AObj.GetValue<string>('name', '');
  Result.SelectSQL := AObj.GetValue<string>('select', '');
  Result.OrReplace := AObj.GetValue<Boolean>('orReplace', True);
end;
{$ENDIF}

{ ---- busca por NOME (case-insensitive, mesmo criterio de TableIndexOfUnique/
  TableIndexOfIndex, Database.Table.pas) - usada pelo patch aditivo de
  SchemaStructureMergeFromJSON (substitui o slot inteiro no lugar quando ja
  existe um elemento com o mesmo nome; -1 sinaliza ao chamador para
  acrescentar um elemento novo). ---- }

function SchemaIndexOfTrigger(const AArr: TTriggerDefinitionArray; const AName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(AArr) do
    if CompareText(AArr[I].Name, AName) = 0 then
      Exit(I);
end;

function SchemaIndexOfRule(const AArr: TRuleDefinitionArray; const AName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(AArr) do
    if CompareText(AArr[I].Name, AName) = 0 then
      Exit(I);
end;

function SchemaIndexOfRoutine(const AArr: TRoutineDefinitionArray; const AName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(AArr) do
    if CompareText(AArr[I].Name, AName) = 0 then
      Exit(I);
end;

function SchemaIndexOfView(const AArr: TSchemaViews; const AName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(AArr) do
    if CompareText(AArr[I].Name, AName) = 0 then
      Exit(I);
end;

function TSchema.IndexOfGroupName(const AName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FGroups) do
    if CompareText(FGroups[I].tablename, AName) = 0 then
    begin
      Result := I;
      Exit;
    end;
end;

function TSchema.GetOrCreateGroup(const AName: string): ITables;
var
  LIdx: Integer;
begin
  LIdx := IndexOfGroupName(AName);
  if LIdx >= 0 then
  begin
    Result := FGroups[LIdx].group;
    Exit;
  end;
  Result := TTables.New;
  SetLength(FGroups, Length(FGroups) + 1);
  FGroups[High(FGroups)].tablename := AName;
  FGroups[High(FGroups)].group := Result;
end;

constructor TSchema.Create;
begin
  inherited Create;
  SetLength(FGroups, 0);
  SetLength(FTriggers, 0);
  SetLength(FRules, 0);
  SetLength(FRoutines, 0);
  SetLength(FViews, 0);
end;

destructor TSchema.Destroy;
begin
  SetLength(FGroups, 0);
  SetLength(FTriggers, 0);
  SetLength(FRules, 0);
  SetLength(FRoutines, 0);
  SetLength(FViews, 0);
  inherited;
end;

class function TSchema.New: ISchema;
begin
  Result := TSchema.Create;
end;

function TSchema.SchemaName(const AValue: string): ISchema;
begin
  inherited Schema(AValue);
  Result := Self;
end;

function TSchema.SchemaName: string;
begin
  Result := inherited Schema;
end;

function TSchema.Database(const AValue: string): ISchema;
begin
  inherited Database(AValue);
  Result := Self;
end;

function TSchema.Database: string;
begin
  Result := inherited Database;
end;

function TSchema.ToJSON: string;
var
  I: Integer;
  LBody: string;
begin
  { EIXO DADO PROPRIO do Schema (Fatia B-d) - chave-nomeada: uma chave por
    grupo (TableName), valor = ITables.ToJSON desse grupo (array de registos
    com object_state, reconciliacao por PK ja resolvida a nivel do grupo). }
  LBody := '';
  for I := 0 to High(FGroups) do
  begin
    if LBody <> '' then
      LBody := LBody + ',';
    LBody := LBody + JSONQuoteString(FGroups[I].tablename) + ':' + FGroups[I].group.ToJSON;
  end;
  Result := '{' + LBody + '}';
end;

function TSchema.StructureToJSON: string;
var
  I: Integer;
  LTablesBody: string;
  LList: TTableArray;
  LTriggersBody, LRulesBody, LProceduresBody, LFunctionsBody, LViewsBody: string;
begin
  { EIXO ESTRUTURA PROPRIO do Schema (Fatia B-d) - chaves schema (SchemaName)
    e tables (1 ITable.StructureToJSON "representante" por grupo - todos os
    registos de um grupo partilham a mesma estrutura). Onda S2-b2 (ADITIVO) -
    +"triggers"/+"rules"/+"procedures"/+"functions"/+"views" (objectos de
    NIVEL SCHEMA/BANCO, FTriggers/FRules/FRoutines/FViews - ver comentario da
    seccao private). PROCEDURES/FUNCTIONS particionam o MESMO FRoutines por
    Kind (rkProcedure/rkFunction) - o proprio builder ja unifica os dois. }
  LTablesBody := '';
  for I := 0 to High(FGroups) do
  begin
    LList := FGroups[I].group.GetTablesList;
    if Length(LList) > 0 then
    begin
      if LTablesBody <> '' then
        LTablesBody := LTablesBody + ',';
      LTablesBody := LTablesBody + LList[0].StructureToJSON;
    end;
  end;
  LTriggersBody := '';
  for I := 0 to High(FTriggers) do
  begin
    if LTriggersBody <> '' then
      LTriggersBody := LTriggersBody + ',';
    LTriggersBody := LTriggersBody + SchemaTriggerDefToJSON(FTriggers[I]);
  end;
  LRulesBody := '';
  for I := 0 to High(FRules) do
  begin
    if LRulesBody <> '' then
      LRulesBody := LRulesBody + ',';
    LRulesBody := LRulesBody + SchemaRuleDefToJSON(FRules[I]);
  end;
  LProceduresBody := '';
  LFunctionsBody := '';
  for I := 0 to High(FRoutines) do
  begin
    if FRoutines[I].Kind = rkFunction then
    begin
      if LFunctionsBody <> '' then
        LFunctionsBody := LFunctionsBody + ',';
      LFunctionsBody := LFunctionsBody + SchemaRoutineDefToJSON(FRoutines[I]);
    end
    else
    begin
      if LProceduresBody <> '' then
        LProceduresBody := LProceduresBody + ',';
      LProceduresBody := LProceduresBody + SchemaRoutineDefToJSON(FRoutines[I]);
    end;
  end;
  LViewsBody := '';
  for I := 0 to High(FViews) do
  begin
    if LViewsBody <> '' then
      LViewsBody := LViewsBody + ',';
    LViewsBody := LViewsBody + SchemaViewDefToJSON(FViews[I]);
  end;
  Result := '{"schema":' + JSONQuoteString(SchemaName) + ',' +
    '"tables":[' + LTablesBody + '],' +
    '"triggers":[' + LTriggersBody + '],' +
    '"rules":[' + LRulesBody + '],' +
    '"procedures":[' + LProceduresBody + '],' +
    '"functions":[' + LFunctionsBody + '],' +
    '"views":[' + LViewsBody + ']}';
end;

function TSchema.SchemaFromJSON(const AJSON: string): ISchema;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
  I: Integer;
  LGroup: ITables;
begin
  { EIXO DADO PROPRIO do Schema, "replace" (Fatia B-d) - para cada chave do
    objeto de entrada (TableName), localiza (ou cria) o grupo e delega a
    ITables.FromJSON (arvore de import por object_state ja existente,
    Fatia B-c, inalterada). Vinculado ao slot ISchema.FromJSON via clausula
    de resolucao de interface (ver seccao public da classe). }
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
      if not (LObj.Items[I] is TJSONArray) then
        Continue;
      LGroup := GetOrCreateGroup(LObj.Names[I]);
      LGroup.FromJSON(LObj.Items[I].AsJSON);
    end;
  finally
    LObj.Free;
  end;
end;
{$ELSE}
var
  LVal: TJSONValue;
  LObj: TJSONObject;
  LPair: TJSONPair;
  LGroup: ITables;
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
      if not (LPair.JsonValue is TJSONArray) then
        Continue;
      LGroup := GetOrCreateGroup(LPair.JsonString.Value);
      LGroup.FromJSON(LPair.JsonValue.ToJSON);
    end;
  finally
    LObj.Free;
  end;
end;
{$ENDIF}

function TSchema.SchemaMergeFromJSON(const AJSON: string): ISchema;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
  I: Integer;
  LGroup: ITables;
begin
  { EIXO DADO PROPRIO do Schema, "patch" (Fatia B-d) - mesma arvore de
    SchemaFromJSON, mas delega a ITables.MergeFromJSON (dirty por campo)
    em vez de ITables.FromJSON (hidratacao limpa) nos grupos localizados/
    criados. }
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
      if not (LObj.Items[I] is TJSONArray) then
        Continue;
      LGroup := GetOrCreateGroup(LObj.Names[I]);
      LGroup.MergeFromJSON(LObj.Items[I].AsJSON);
    end;
  finally
    LObj.Free;
  end;
end;
{$ELSE}
var
  LVal: TJSONValue;
  LObj: TJSONObject;
  LPair: TJSONPair;
  LGroup: ITables;
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
      if not (LPair.JsonValue is TJSONArray) then
        Continue;
      LGroup := GetOrCreateGroup(LPair.JsonString.Value);
      LGroup.MergeFromJSON(LPair.JsonValue.ToJSON);
    end;
  finally
    LObj.Free;
  end;
end;
{$ENDIF}

function TSchema.SchemaStructureFromJSON(const AJSON: string): ISchema;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
  LTablesNode: TJSONData;
  LTablesArr: TJSONArray;
  I: Integer;
  LItemObj: TJSONObject;
  LName: string;
  LGroup: ITables;
  LDefaultName: string;
  LNode: TJSONData;
  LArr: TJSONArray;
begin
  { EIXO ESTRUTURA PROPRIO do Schema (Fatia B-d) - reconstroi os grupos por
    completo (substitui): 1 grupo por elemento de "tables", semeado como
    registo-molde via ITables.StructureFromJSON (bug-306, herdado do B-c -
    eixo estrutura nunca carrega "value", so estrutura pura). Vinculado ao
    slot ISchema.StructureFromJSON via clausula de resolucao de interface
    (ver seccao public da classe). Onda S2-b2 (ADITIVO) - reconstroi tambem
    FTriggers/FRules/FRoutines/FViews por completo (nil+reconstroi tudo,
    mesma semantica "replace" de FGroups) a partir das novas chaves
    "triggers"/"rules"/"procedures"/"functions"/"views". FRoutines e' UNICO
    (procedures+functions) - "procedures" forca Kind=rkProcedure default,
    "functions" forca Kind=rkFunction default, ambos ACRESCENTAM ao MESMO
    array (nao ha reset entre os 2 loops). }
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
    LDefaultName := SchemaName;
    SchemaName(LObj.Get('schema', LDefaultName));
    SetLength(FGroups, 0);
    LTablesNode := LObj.Find('tables');
    if Assigned(LTablesNode) and (LTablesNode is TJSONArray) then
    begin
      LTablesArr := TJSONArray(LTablesNode);
      for I := 0 to LTablesArr.Count - 1 do
      begin
        if not (LTablesArr.Items[I] is TJSONObject) then
          Continue;
        LItemObj := TJSONObject(LTablesArr.Items[I]);
        LName := LItemObj.Get('table', '');
        LGroup := TTables.New;
        LGroup.StructureFromJSON('[' + LItemObj.AsJSON + ']');
        SetLength(FGroups, Length(FGroups) + 1);
        FGroups[High(FGroups)].tablename := LName;
        FGroups[High(FGroups)].group := LGroup;
      end;
    end;
    FTriggers := nil;
    LNode := LObj.Find('triggers');
    if Assigned(LNode) and (LNode is TJSONArray) then
    begin
      LArr := TJSONArray(LNode);
      for I := 0 to LArr.Count - 1 do
      begin
        if not (LArr.Items[I] is TJSONObject) then
          Continue;
        SetLength(FTriggers, Length(FTriggers) + 1);
        FTriggers[High(FTriggers)] := SchemaTriggerDefFromJSON(TJSONObject(LArr.Items[I]));
      end;
    end;
    FRules := nil;
    LNode := LObj.Find('rules');
    if Assigned(LNode) and (LNode is TJSONArray) then
    begin
      LArr := TJSONArray(LNode);
      for I := 0 to LArr.Count - 1 do
      begin
        if not (LArr.Items[I] is TJSONObject) then
          Continue;
        SetLength(FRules, Length(FRules) + 1);
        FRules[High(FRules)] := SchemaRuleDefFromJSON(TJSONObject(LArr.Items[I]));
      end;
    end;
    FRoutines := nil;
    LNode := LObj.Find('procedures');
    if Assigned(LNode) and (LNode is TJSONArray) then
    begin
      LArr := TJSONArray(LNode);
      for I := 0 to LArr.Count - 1 do
      begin
        if not (LArr.Items[I] is TJSONObject) then
          Continue;
        SetLength(FRoutines, Length(FRoutines) + 1);
        FRoutines[High(FRoutines)] := SchemaRoutineDefFromJSON(TJSONObject(LArr.Items[I]), rkProcedure);
      end;
    end;
    LNode := LObj.Find('functions');
    if Assigned(LNode) and (LNode is TJSONArray) then
    begin
      LArr := TJSONArray(LNode);
      for I := 0 to LArr.Count - 1 do
      begin
        if not (LArr.Items[I] is TJSONObject) then
          Continue;
        SetLength(FRoutines, Length(FRoutines) + 1);
        FRoutines[High(FRoutines)] := SchemaRoutineDefFromJSON(TJSONObject(LArr.Items[I]), rkFunction);
      end;
    end;
    FViews := nil;
    LNode := LObj.Find('views');
    if Assigned(LNode) and (LNode is TJSONArray) then
    begin
      LArr := TJSONArray(LNode);
      for I := 0 to LArr.Count - 1 do
      begin
        if not (LArr.Items[I] is TJSONObject) then
          Continue;
        SetLength(FViews, Length(FViews) + 1);
        FViews[High(FViews)] := SchemaViewDefFromJSON(TJSONObject(LArr.Items[I]));
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
  LTablesVal: TJSONValue;
  LTablesArr: TJSONArray;
  I: Integer;
  LItemObj: TJSONObject;
  LName: string;
  LGroup: ITables;
  LDefaultName: string;
  LNodeVal: TJSONValue;
  LArr: TJSONArray;
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
    LDefaultName := SchemaName;
    SchemaName(LObj.GetValue<string>('schema', LDefaultName));
    SetLength(FGroups, 0);
    LTablesVal := LObj.GetValue('tables');
    if Assigned(LTablesVal) and (LTablesVal is TJSONArray) then
    begin
      LTablesArr := TJSONArray(LTablesVal);
      for I := 0 to LTablesArr.Count - 1 do
      begin
        if not (LTablesArr.Items[I] is TJSONObject) then
          Continue;
        LItemObj := TJSONObject(LTablesArr.Items[I]);
        LName := LItemObj.GetValue<string>('table', '');
        LGroup := TTables.New;
        LGroup.StructureFromJSON('[' + LItemObj.ToJSON + ']');
        SetLength(FGroups, Length(FGroups) + 1);
        FGroups[High(FGroups)].tablename := LName;
        FGroups[High(FGroups)].group := LGroup;
      end;
    end;
    FTriggers := nil;
    LNodeVal := LObj.GetValue('triggers');
    if Assigned(LNodeVal) and (LNodeVal is TJSONArray) then
    begin
      LArr := TJSONArray(LNodeVal);
      for I := 0 to LArr.Count - 1 do
      begin
        if not (LArr.Items[I] is TJSONObject) then
          Continue;
        SetLength(FTriggers, Length(FTriggers) + 1);
        FTriggers[High(FTriggers)] := SchemaTriggerDefFromJSON(TJSONObject(LArr.Items[I]));
      end;
    end;
    FRules := nil;
    LNodeVal := LObj.GetValue('rules');
    if Assigned(LNodeVal) and (LNodeVal is TJSONArray) then
    begin
      LArr := TJSONArray(LNodeVal);
      for I := 0 to LArr.Count - 1 do
      begin
        if not (LArr.Items[I] is TJSONObject) then
          Continue;
        SetLength(FRules, Length(FRules) + 1);
        FRules[High(FRules)] := SchemaRuleDefFromJSON(TJSONObject(LArr.Items[I]));
      end;
    end;
    FRoutines := nil;
    LNodeVal := LObj.GetValue('procedures');
    if Assigned(LNodeVal) and (LNodeVal is TJSONArray) then
    begin
      LArr := TJSONArray(LNodeVal);
      for I := 0 to LArr.Count - 1 do
      begin
        if not (LArr.Items[I] is TJSONObject) then
          Continue;
        SetLength(FRoutines, Length(FRoutines) + 1);
        FRoutines[High(FRoutines)] := SchemaRoutineDefFromJSON(TJSONObject(LArr.Items[I]), rkProcedure);
      end;
    end;
    LNodeVal := LObj.GetValue('functions');
    if Assigned(LNodeVal) and (LNodeVal is TJSONArray) then
    begin
      LArr := TJSONArray(LNodeVal);
      for I := 0 to LArr.Count - 1 do
      begin
        if not (LArr.Items[I] is TJSONObject) then
          Continue;
        SetLength(FRoutines, Length(FRoutines) + 1);
        FRoutines[High(FRoutines)] := SchemaRoutineDefFromJSON(TJSONObject(LArr.Items[I]), rkFunction);
      end;
    end;
    FViews := nil;
    LNodeVal := LObj.GetValue('views');
    if Assigned(LNodeVal) and (LNodeVal is TJSONArray) then
    begin
      LArr := TJSONArray(LNodeVal);
      for I := 0 to LArr.Count - 1 do
      begin
        if not (LArr.Items[I] is TJSONObject) then
          Continue;
        SetLength(FViews, Length(FViews) + 1);
        FViews[High(FViews)] := SchemaViewDefFromJSON(TJSONObject(LArr.Items[I]));
      end;
    end;
  finally
    LObj.Free;
  end;
end;
{$ENDIF}

function TSchema.SchemaStructureMergeFromJSON(const AJSON: string): ISchema;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
  LTablesNode: TJSONData;
  LTablesArr: TJSONArray;
  I, LPos: Integer;
  LItemObj: TJSONObject;
  LName: string;
  LGroup: ITables;
  LDefaultName: string;
  LNode: TJSONData;
  LArr: TJSONArray;
  LTriggerDef: ITriggerDefinition;
  LRuleDef: IRuleDefinition;
  LRoutineDef: IRoutineDefinition;
  LViewDef: TSchemaView;
begin
  { Onda S2-a (ADITIVO) - PATCH aditivo (ao contrario de
    SchemaStructureFromJSON, que faz SetLength(FGroups,0) e reconstroi
    tudo): "schema" segue o mesmo padrao patch de Get(default=valor
    CORRENTE); "tables" localiza (ou CRIA, via GetOrCreateGroup - nunca
    remove um grupo existente) o grupo pelo "table" de cada elemento e
    delega a ITables.StructureMergeFromJSON NESSE grupo (patch por nome de
    coluna a nivel dos campos - reusa integralmente a logica aditiva ja
    implementada em TTables, Onda S2-a). Vinculado ao slot ISchema.
    StructureMergeFromJSON via clausula de resolucao de interface (ver
    seccao public da classe). Onda S2-b2 (ADITIVO) - "triggers"/"rules"/
    "procedures"/"functions"/"views" seguem a MESMA logica aditiva PATCH POR
    NOME (SchemaIndexOfTrigger/Rule/Routine/View): existe um elemento com
    esse "name" -> substitui o slot INTEIRO do array no lugar (decode gera
    sempre uma instancia nova via o builder - mesma granularidade "objecto
    completo por nome" ja estabelecida por FUniques/FIndexes, Database.
    Table.pas, Onda S2-b1); nao existe -> acrescenta um elemento novo. NUNCA
    remove um elemento existente que nao apareca no JSON de entrada. }
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
    LDefaultName := SchemaName;
    SchemaName(LObj.Get('schema', LDefaultName));
    LTablesNode := LObj.Find('tables');
    if Assigned(LTablesNode) and (LTablesNode is TJSONArray) then
    begin
      LTablesArr := TJSONArray(LTablesNode);
      for I := 0 to LTablesArr.Count - 1 do
      begin
        if not (LTablesArr.Items[I] is TJSONObject) then
          Continue;
        LItemObj := TJSONObject(LTablesArr.Items[I]);
        LName := LItemObj.Get('table', '');
        LGroup := GetOrCreateGroup(LName);
        LGroup.StructureMergeFromJSON('[' + LItemObj.AsJSON + ']');
      end;
    end;
    LNode := LObj.Find('triggers');
    if Assigned(LNode) and (LNode is TJSONArray) then
    begin
      LArr := TJSONArray(LNode);
      for I := 0 to LArr.Count - 1 do
      begin
        if not (LArr.Items[I] is TJSONObject) then
          Continue;
        LTriggerDef := SchemaTriggerDefFromJSON(TJSONObject(LArr.Items[I]));
        LPos := SchemaIndexOfTrigger(FTriggers, LTriggerDef.Name);
        if LPos < 0 then
        begin
          SetLength(FTriggers, Length(FTriggers) + 1);
          LPos := High(FTriggers);
        end;
        FTriggers[LPos] := LTriggerDef;
      end;
    end;
    LNode := LObj.Find('rules');
    if Assigned(LNode) and (LNode is TJSONArray) then
    begin
      LArr := TJSONArray(LNode);
      for I := 0 to LArr.Count - 1 do
      begin
        if not (LArr.Items[I] is TJSONObject) then
          Continue;
        LRuleDef := SchemaRuleDefFromJSON(TJSONObject(LArr.Items[I]));
        LPos := SchemaIndexOfRule(FRules, LRuleDef.Name);
        if LPos < 0 then
        begin
          SetLength(FRules, Length(FRules) + 1);
          LPos := High(FRules);
        end;
        FRules[LPos] := LRuleDef;
      end;
    end;
    LNode := LObj.Find('procedures');
    if Assigned(LNode) and (LNode is TJSONArray) then
    begin
      LArr := TJSONArray(LNode);
      for I := 0 to LArr.Count - 1 do
      begin
        if not (LArr.Items[I] is TJSONObject) then
          Continue;
        LRoutineDef := SchemaRoutineDefFromJSON(TJSONObject(LArr.Items[I]), rkProcedure);
        LPos := SchemaIndexOfRoutine(FRoutines, LRoutineDef.Name);
        if LPos < 0 then
        begin
          SetLength(FRoutines, Length(FRoutines) + 1);
          LPos := High(FRoutines);
        end;
        FRoutines[LPos] := LRoutineDef;
      end;
    end;
    LNode := LObj.Find('functions');
    if Assigned(LNode) and (LNode is TJSONArray) then
    begin
      LArr := TJSONArray(LNode);
      for I := 0 to LArr.Count - 1 do
      begin
        if not (LArr.Items[I] is TJSONObject) then
          Continue;
        LRoutineDef := SchemaRoutineDefFromJSON(TJSONObject(LArr.Items[I]), rkFunction);
        LPos := SchemaIndexOfRoutine(FRoutines, LRoutineDef.Name);
        if LPos < 0 then
        begin
          SetLength(FRoutines, Length(FRoutines) + 1);
          LPos := High(FRoutines);
        end;
        FRoutines[LPos] := LRoutineDef;
      end;
    end;
    LNode := LObj.Find('views');
    if Assigned(LNode) and (LNode is TJSONArray) then
    begin
      LArr := TJSONArray(LNode);
      for I := 0 to LArr.Count - 1 do
      begin
        if not (LArr.Items[I] is TJSONObject) then
          Continue;
        LViewDef := SchemaViewDefFromJSON(TJSONObject(LArr.Items[I]));
        LPos := SchemaIndexOfView(FViews, LViewDef.Name);
        if LPos < 0 then
        begin
          SetLength(FViews, Length(FViews) + 1);
          LPos := High(FViews);
        end;
        FViews[LPos] := LViewDef;
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
  LTablesVal: TJSONValue;
  LTablesArr: TJSONArray;
  I, LPos: Integer;
  LItemObj: TJSONObject;
  LName: string;
  LGroup: ITables;
  LDefaultName: string;
  LNodeVal: TJSONValue;
  LArr: TJSONArray;
  LTriggerDef: ITriggerDefinition;
  LRuleDef: IRuleDefinition;
  LRoutineDef: IRoutineDefinition;
  LViewDef: TSchemaView;
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
    LDefaultName := SchemaName;
    SchemaName(LObj.GetValue<string>('schema', LDefaultName));
    LTablesVal := LObj.GetValue('tables');
    if Assigned(LTablesVal) and (LTablesVal is TJSONArray) then
    begin
      LTablesArr := TJSONArray(LTablesVal);
      for I := 0 to LTablesArr.Count - 1 do
      begin
        if not (LTablesArr.Items[I] is TJSONObject) then
          Continue;
        LItemObj := TJSONObject(LTablesArr.Items[I]);
        LName := LItemObj.GetValue<string>('table', '');
        LGroup := GetOrCreateGroup(LName);
        LGroup.StructureMergeFromJSON('[' + LItemObj.ToJSON + ']');
      end;
    end;
    LNodeVal := LObj.GetValue('triggers');
    if Assigned(LNodeVal) and (LNodeVal is TJSONArray) then
    begin
      LArr := TJSONArray(LNodeVal);
      for I := 0 to LArr.Count - 1 do
      begin
        if not (LArr.Items[I] is TJSONObject) then
          Continue;
        LTriggerDef := SchemaTriggerDefFromJSON(TJSONObject(LArr.Items[I]));
        LPos := SchemaIndexOfTrigger(FTriggers, LTriggerDef.Name);
        if LPos < 0 then
        begin
          SetLength(FTriggers, Length(FTriggers) + 1);
          LPos := High(FTriggers);
        end;
        FTriggers[LPos] := LTriggerDef;
      end;
    end;
    LNodeVal := LObj.GetValue('rules');
    if Assigned(LNodeVal) and (LNodeVal is TJSONArray) then
    begin
      LArr := TJSONArray(LNodeVal);
      for I := 0 to LArr.Count - 1 do
      begin
        if not (LArr.Items[I] is TJSONObject) then
          Continue;
        LRuleDef := SchemaRuleDefFromJSON(TJSONObject(LArr.Items[I]));
        LPos := SchemaIndexOfRule(FRules, LRuleDef.Name);
        if LPos < 0 then
        begin
          SetLength(FRules, Length(FRules) + 1);
          LPos := High(FRules);
        end;
        FRules[LPos] := LRuleDef;
      end;
    end;
    LNodeVal := LObj.GetValue('procedures');
    if Assigned(LNodeVal) and (LNodeVal is TJSONArray) then
    begin
      LArr := TJSONArray(LNodeVal);
      for I := 0 to LArr.Count - 1 do
      begin
        if not (LArr.Items[I] is TJSONObject) then
          Continue;
        LRoutineDef := SchemaRoutineDefFromJSON(TJSONObject(LArr.Items[I]), rkProcedure);
        LPos := SchemaIndexOfRoutine(FRoutines, LRoutineDef.Name);
        if LPos < 0 then
        begin
          SetLength(FRoutines, Length(FRoutines) + 1);
          LPos := High(FRoutines);
        end;
        FRoutines[LPos] := LRoutineDef;
      end;
    end;
    LNodeVal := LObj.GetValue('functions');
    if Assigned(LNodeVal) and (LNodeVal is TJSONArray) then
    begin
      LArr := TJSONArray(LNodeVal);
      for I := 0 to LArr.Count - 1 do
      begin
        if not (LArr.Items[I] is TJSONObject) then
          Continue;
        LRoutineDef := SchemaRoutineDefFromJSON(TJSONObject(LArr.Items[I]), rkFunction);
        LPos := SchemaIndexOfRoutine(FRoutines, LRoutineDef.Name);
        if LPos < 0 then
        begin
          SetLength(FRoutines, Length(FRoutines) + 1);
          LPos := High(FRoutines);
        end;
        FRoutines[LPos] := LRoutineDef;
      end;
    end;
    LNodeVal := LObj.GetValue('views');
    if Assigned(LNodeVal) and (LNodeVal is TJSONArray) then
    begin
      LArr := TJSONArray(LNodeVal);
      for I := 0 to LArr.Count - 1 do
      begin
        if not (LArr.Items[I] is TJSONObject) then
          Continue;
        LViewDef := SchemaViewDefFromJSON(TJSONObject(LArr.Items[I]));
        LPos := SchemaIndexOfView(FViews, LViewDef.Name);
        if LPos < 0 then
        begin
          SetLength(FViews, Length(FViews) + 1);
          LPos := High(FViews);
        end;
        FViews[LPos] := LViewDef;
      end;
    end;
  finally
    LObj.Free;
  end;
end;
{$ENDIF}

{ Onda S3 - divide ASQL por '#0' (PostgreSQL FUNCTION+TRIGGER/RULE, ver
  IDialect.Trigger/Rule.CreateSQL) e acrescenta cada parte (Trim, nao-vazia)
  a AResult como um statement terminado por ';', separado por sLineBreak dos
  statements ja existentes - mesma tecnica de split ja usada por TTriggers.
  ExecMulti (Database.Triggers.pas), aqui para MONTAR o script (ToDDL) em vez
  de EXECUTAR. View/Routine nunca devolvem '#0' - Split fica com 1 elemento,
  inocuo. ASQL vazio/so espacos -> no-op (AResult inalterado). }
procedure SchemaAppendDDLStatement(var AResult: string; const ASQL: string);
var
  LParts: TArray<string>;
  I: Integer;
  LPart: string;
begin
  if Trim(ASQL) = '' then
    Exit;
  LParts := ASQL.Split([#0]);
  for I := 0 to High(LParts) do
  begin
    LPart := Trim(LParts[I]);
    if LPart = '' then
      Continue;
    if AResult <> '' then
      AResult := AResult + sLineBreak;
    AResult := AResult + LPart + ';';
  end;
end;

function TSchema.CreateSchemaSQL: string;
{$IFDEF USE_DATABASE}
var
  LDialect: IDialect;
{$ENDIF}
begin
  { DDL de nivel schema (Fatia B-d) - resolve o dialecto SO por DatabaseTypes
    (herdado de ITables), sem exigir conexao (TDialect.ForDatabaseType);
    degrada graciosamente para string vazia se USE_DATABASE estiver OFF, se
    SchemaName estiver vazio, ou se DatabaseTypes nunca tiver sido definido
    (dtNone). }
  Result := '';
{$IFDEF USE_DATABASE}
  if (Trim(SchemaName) = '') or (DatabaseTypes = dtNone) then
    Exit;
  LDialect := TDialect.ForDatabaseType(DatabaseTypes);
  Result := LDialect.CreateSchemaSQL(SchemaName);
{$ENDIF}
end;

function TSchema.DropSchemaSQL: string;
{$IFDEF USE_DATABASE}
var
  LDialect: IDialect;
{$ENDIF}
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (Trim(SchemaName) = '') or (DatabaseTypes = dtNone) then
    Exit;
  LDialect := TDialect.ForDatabaseType(DatabaseTypes);
  Result := LDialect.DropSchemaSQL(SchemaName);
{$ENDIF}
end;

function TSchema.CreateSchema(const AConnection: IConnection): Integer;
var
  LSQL: string;
begin
  Result := 0;
  if (AConnection = nil) or not AConnection.IsConnected then
    Exit;
  LSQL := CreateSchemaSQL;
  if LSQL <> '' then
    Result := AConnection.ExecuteCommand(LSQL);
end;

function TSchema.DropSchema(const AConnection: IConnection): Integer;
var
  LSQL: string;
begin
  Result := 0;
  if (AConnection = nil) or not AConnection.IsConnected then
    Exit;
  LSQL := DropSchemaSQL;
  if LSQL <> '' then
    Result := AConnection.ExecuteCommand(LSQL);
end;

function TSchema.ToDDL: string;
var
  I: Integer;
  LList: TTableArray;
  LStmt: string;
{$IFDEF USE_DATABASE}
  LDialect: IDialect;
{$ENDIF}
begin
  { Onda S3 - ver comentario completo em Databases.Interfaces.ISchema.ToDDL.
    (1) tabelas - a partir de FGroups (1 ITable "representante" por grupo,
    MESMA fonte ja usada por StructureToJSON/SchemaStructureFromJSON, acima -
    NAO o GetTablesList herdado de TTables/FList: esse e' um contentor
    ESTRUTURAL PARALELO, so alimentado por LoadFromConnection/introspeccao de
    uma conexao viva, nunca por Structure*FromJSON - usar FList aqui deixaria
    o ToDDL silenciosamente vazio para QUALQUER schema construido pelo eixo
    JSON, que e' o UNICO caminho fluente hoje para popular FUniques/FIndexes/
    FTriggers/FRules/FRoutines/FViews). Cada ITable.ToDDL ja cobre colunas+
    PK+FK inline+uniques/indexes (Database.Table.pas). Nao depende de
    USE_DATABASE/DatabaseTypes - sai sempre que houver tabelas, mesmo sem
    SchemaName/dialecto definidos. }
  Result := '';
  for I := 0 to High(FGroups) do
  begin
    LList := FGroups[I].group.GetTablesList;
    if Length(LList) = 0 then
      Continue;
    { ACHADO (validado por execucao real, demo owner) - o representante vem
      de um round-trip StructureToJSON->StructureFromJSON (TTable.New por
      dentro de TTables.StructureFromJSON), que NUNCA carrega DatabaseTypes
      (nao e uma chave do JSON de estrutura, por design - "independente da
      conexao", cada objecto define a sua) - fica dtNone por omissao. Sem
      este alinhamento, CreateTableSQL (via ITable.ToDDL) chamaria
      TDialect.ForDatabaseType(dtNone) e lancaria EDatabaseDialectException
      ("Dialecto nao suportado para o banco None"). Interfaces sao
      referencia - mutar LList[0] afecta a MESMA instancia guardada no grupo. }
    LList[0].DatabaseTypes(DatabaseTypes);
    LStmt := Trim(LList[0].ToDDL);
    if LStmt = '' then
      Continue;
    if Result <> '' then
      Result := Result + sLineBreak;
    Result := Result + LStmt;
  end;
{$IFDEF USE_DATABASE}
  { (2) views/(3) procedures+functions/(4) triggers/(5) rules - FViews/
    FRoutines/FTriggers/FRules (Onda S2-b2), so preenchidos hoje via
    Structure*FromJSON (sem builder fluente proprio ainda - ver comentario da
    seccao private) - precisam do dialecto (TDialect.ForDatabaseType), logo
    dependem de DatabaseTypes estar definido; sem isso, so a parte de tabelas
    (acima) sai do ToDDL. }
  if DatabaseTypes = dtNone then
    Exit;
  LDialect := TDialect.ForDatabaseType(DatabaseTypes);
  for I := 0 to High(FViews) do
    SchemaAppendDDLStatement(Result,
      LDialect.View.CreateSQL(FViews[I].Name, FViews[I].SelectSQL, FViews[I].OrReplace));
  for I := 0 to High(FRoutines) do
    SchemaAppendDDLStatement(Result, LDialect.Routine.CreateSQL(FRoutines[I]));
  for I := 0 to High(FTriggers) do
    SchemaAppendDDLStatement(Result, LDialect.Trigger.CreateSQL(FTriggers[I]));
  for I := 0 to High(FRules) do
    SchemaAppendDDLStatement(Result, LDialect.Rule.CreateSQL(FRules[I]));
{$ENDIF}
end;

function TSchema.ToSQL: string;
var
  I, J: Integer;
  LStmt: string;
  LRows: TTableArray;
begin
  { Onda S3 - OVERRIDE deliberado (reintroducao de nome, mesmo padrao ja usado
    por ToJSON/StructureToJSON acima) de TTables.ToSQL: o herdado opera sobre
    FList (GetTablesList), o mesmo contentor ESTRUTURAL PARALELO discutido no
    comentario de ToDDL - vazio para schemas construidos pelo eixo JSON, o
    UNICO caminho fluente hoje. Aqui agrega ITables.ToSQL de CADA GRUPO
    (FGroups[I].group - ja um ITables, com 0..N registos/linhas da MESMA
    tabela - delega a Fatia B-c, sem SQL novo), MESMA fonte de dados que
    ToJSON/StructureToJSON/ToDDL ja usam. MESMO alinhamento de DatabaseTypes
    do ToDDL (acima) - cada linha (round-trip FromJSON) fica dtNone por
    omissao; sem o alinhar, ITable.ToSQL cairia no fallback ANSI do
    IQueryBuilder (aspas duplas genericas) em vez do dialecto real do
    schema. Cada FGroups[I].group.ToSQL ja vem terminado por ';' por linha
    (TTables.ToSQL) - so concatena os grupos. }
  Result := '';
  for I := 0 to High(FGroups) do
  begin
    LRows := FGroups[I].group.GetTablesList;
    for J := 0 to High(LRows) do
      LRows[J].DatabaseTypes(DatabaseTypes);
    LStmt := Trim(FGroups[I].group.ToSQL);
    if LStmt = '' then
      Continue;
    if Result <> '' then
      Result := Result + sLineBreak;
    Result := Result + LStmt;
  end;
end;

{$IFDEF USE_DATABASE}
{ Onda S3b - UNICA peca genuinamente NOVA desta onda (sem SSOT preexistente -
  grep global confirmado antes de escrever, regra #14 anti-duplicacao):
  classifica o ColumnType RAW desta ITable (string livre, dialect-specific,
  usada DIRECTAMENTE por TTable.CreateTableSQL - nunca um TSQLColumnKind,
  essa abstracao so existe do lado TSynchronize/IDialect.ColumnTypeFor) no
  enum TSQLColumnKind que ISchemaTable.AddColumn exige. AIsIdentity (campo
  dedicado, IField.IsIdentity - populado pela introspeccao do catalogo ou
  manualmente) resolve o caso ckIdentity SEM heuristica; so o RESTO do
  texto precisa de classificacao por substring (case-insensitive). Fallback
  ckInteger para texto desconhecido/vazio - MESMA convencao de
  SchemaStrToColumnKind (acima), que ja usa ckInteger como "else" para nomes
  de Kind desconhecidos no eixo JSON. }
function SchemaColumnTypeToKind(const AColumnType: string; const AIsIdentity: Boolean): TSQLColumnKind;
var
  LU: string;
begin
  if AIsIdentity then
  begin
    Result := ckIdentity;
    Exit;
  end;
  LU := UpperCase(Trim(AColumnType));
  if (Pos('SERIAL', LU) > 0) or (Pos('IDENTITY', LU) > 0) or
     (Pos('AUTOINCREMENT', LU) > 0) or (Pos('AUTO_INCREMENT', LU) > 0) then
    Result := ckIdentity
  else if Pos('BIGINT', LU) > 0 then
    Result := ckBigInt
  else if (Pos('SMALLINT', LU) > 0) or (Pos('TINYINT', LU) > 0) then
    Result := ckSmallInt
  else if (Pos('DECIMAL', LU) > 0) or (Pos('NUMERIC', LU) > 0) or
          (Pos('MONEY', LU) > 0) or (Pos('CURRENCY', LU) > 0) then
    Result := ckDecimal
  else if (Pos('FLOAT', LU) > 0) or (Pos('DOUBLE', LU) > 0) or (Pos('REAL', LU) > 0) then
    Result := ckFloat
  else if (Pos('BOOL', LU) > 0) or (LU = 'BIT') then
    Result := ckBoolean
  else if (Pos('DATETIME', LU) > 0) or (Pos('TIMESTAMP', LU) > 0) then
    Result := ckDateTime
  else if Pos('DATE', LU) > 0 then
    Result := ckDate
  else if Pos('TIME', LU) > 0 then
    Result := ckTime
  else if (Pos('BLOB', LU) > 0) or (Pos('BYTEA', LU) > 0) or
          (Pos('BINARY', LU) > 0) or (Pos('IMAGE', LU) > 0) then
    Result := ckBlob
  else if (Pos('TEXT', LU) > 0) or (Pos('CLOB', LU) > 0) or (Pos('MEMO', LU) > 0) then
    Result := ckText
  else if Pos('CHAR', LU) > 0 then
  begin
    if Pos('VARCHAR', LU) > 0 then
      Result := ckVarChar
    else
      Result := ckChar;
  end
  else if Pos('INT', LU) > 0 then
    Result := ckInteger
  else
    Result := ckInteger;
end;

{ Onda S3b - bridge MINIMO ITable->ISchemaDefinition (ver comentario completo
  em Databases.Interfaces.ISchema.ApplyStructure) - popula UMA ISchemaTable
  (dentro do ADef recebido) a partir do MODELO PUBLICO ja existente desta
  ITable: GetFieldsList (herdado de IFields) para colunas + Uniques/Indexes
  (Onda S3b, novos getters de ITable) para constraints - SEM SQL novo, SEM
  round-trip JSON. Uniques/Indexes reusam TSchemaUnique/TSchemaIndex
  TAL-QUAL (MESMO tipo que ISchemaTable.AddUnique/AddIndex ja consome -
  regra #14, zero conversao extra alem do Kind das colunas). Colunas/
  Uniques/Indexes sao leitura PURA de modelo (Column/ColumnType/Size/IsPKey/
  FieldAllowsNull) - nao dependem de dialecto/DatabaseTypes, ao contrario de
  ITable.ToDDL (que tambem gera AddUniqueSQL/AddIndexSQL via IDialect). }
procedure SchemaAddTableToDefinition(const ATable: ITable; const ADef: ISchemaDefinition);
var
  LFields: TFieldArray;
  LSchemaTable: ISchemaTable;
  LUniques: TSchemaUniques;
  LIndexes: TSchemaIndexes;
  LKind: TSQLColumnKind;
  LSize, LScale: Integer;
  I: Integer;
begin
  if (ATable = nil) or (Trim(ATable.TableName) = '') then
    Exit;
  LSchemaTable := ADef.Table(ATable.TableName);
  LFields := ATable.GetFieldsList;
  for I := 0 to High(LFields) do
  begin
    LKind := SchemaColumnTypeToKind(LFields[I].ColumnType, LFields[I].IsIdentity);
    { fix #2 (auditoria adversarial ao ApplyStructure) - colunas cujo
      ColumnType de origem tem 2 numeros entre parenteses (DECIMAL(10,2)/
      NUMERIC(18,4)) guardam o tamanho em Precision/Scale, NAO em Size (Size
      fica 0 nesses casos - ver Database.Field.ParseColumnTypeDimensions).
      Passar so' Size (=0) aqui, como antes, materializava sempre
      DECIMAL(18,0) via TDialect.ColumnTypeFor (que so' assume Scale=4
      quando o AScale recebido e' NEGATIVO, nao 0) - perdendo a escala real
      do campo de origem em QUALQUER re-materializacao (ApplyStructure/
      Sync). Quando Precision>0 (2 numeros detectados no parse), usa
      Precision como tamanho e Scale como escala; senao mantem o
      comportamento PRE-EXISTENTE (Size, Scale=0 - 1 numero ou nenhum). }
    if LFields[I].Precision > 0 then
    begin
      LSize := LFields[I].Precision;
      LScale := LFields[I].Scale;
    end
    else
    begin
      LSize := LFields[I].Size;
      LScale := 0;
    end;
    LSchemaTable.AddColumn(LFields[I].Column, LKind, LSize,
      LFields[I].FieldAllowsNull, LFields[I].IsPKey, LScale);
  end;
  LUniques := ATable.Uniques;
  for I := 0 to High(LUniques) do
    LSchemaTable.AddUnique(LUniques[I].Columns, LUniques[I].Name);
  LIndexes := ATable.Indexes;
  for I := 0 to High(LIndexes) do
    LSchemaTable.AddIndex(LIndexes[I].Columns, LIndexes[I].Name, LIndexes[I].Unique);
end;
{$ENDIF}

function TSchema.ApplyStructure(const AConnection: IConnection): ISchema;
{$IFDEF USE_DATABASE}
var
  I, J: Integer;
  LList: TTableArray;
  LFields: TFieldArray;
  LDef: ISchemaDefinition;
  LConstraintName, LRefTable: string;
  LViewsLauncher: IViews;
  LProcLauncher: IProcedures;
  LFuncLauncher: IFunctions;
  LTrgLauncher: ITriggers;
  LRuleLauncher: IRules;
{$ENDIF}
begin
  Result := Self;
{$IFDEF USE_DATABASE}
  if (AConnection = nil) or (not AConnection.IsConnected) then
    Exit;
  { (1) TABELAS + COLUNAS + PK + UNIQUES + INDEXES - constroi UM
    ISchemaDefinition com o "representante" de CADA grupo (mesma fonte de
    FGroups usada por ToDDL/StructureToJSON, acima) e delega a
    TSynchronize.Sync (Onda 5.5/5.5-B - Compare so aplica o que FALTA,
    idempotente por definicao; ver comentario completo em Databases.
    Interfaces.ISchema.ApplyStructure). }
  LDef := TSchemaDefinition.New;
  for I := 0 to High(FGroups) do
  begin
    LList := FGroups[I].group.GetTablesList;
    if Length(LList) = 0 then
      Continue;
    SchemaAddTableToDefinition(LList[0], LDef);
  end;
  { fix #1(CRITICO)/#3 (auditoria adversarial) - try/except ISOLADO por PASSO,
    a comecar pelas tabelas: Sync ja e' idempotente por si (Compare so'
    emite o que FALTA - ver Database.Synchronize.pas), mas aplica TODAS as
    tabelas de LDef numa unica chamada; se algo mesmo assim falhar aqui
    (ex.: DDL invalido nalgum motor), isolar este passo garante que os
    passos (2)-(6) seguintes sao SEMPRE tentados, em vez de o ApplyStructure
    INTEIRO abortar no primeiro erro (era o comportamento antes deste fix -
    ver detalhe completo no comentario do passo (2), abaixo, onde o
    problema e' mais frequente/reproduzivel). }
  try
    TSynchronize.New(AConnection).Sync(LDef);
  except
    { tolerado - ver comentario acima; os passos (2)-(6) continuam. }
  end;
  { (2) FOREIGN KEYS - so DEPOIS de todas as tabelas existirem (owner); por
    campo (IField.ReferencedTable/ReferencedColumn), via
    ITable.AddForeignKey(conn,...) - o proprio AddForeignKey CONSULTA
    ICatalogReader.ForeignKeyExists antes de executar (Database.Table.pas),
    mas essa consulta so' e' FIAVEL em PostgreSQL: ForeignKeyNames extrai o
    ConstraintName da introspeccao de TableStructure, que os restantes 6
    motores (SQL Server/MariaDB/Firebird/SQL Anywhere/SQLite/Access) NAO
    preenchem de forma fiavel por este caminho - ForeignKeyExists fica
    CEGO (devolve sempre False) e o ALTER TABLE ADD CONSTRAINT e'
    re-executado numa 2a chamada de ApplyStructure sobre a MESMA estrutura,
    e o motor rejeita por constraint duplicada. SEM o try/except por-FK
    abaixo, essa excepcao ABORTAVA os passos (3)-(6) seguintes (views/
    procedures/functions/triggers/rules nunca chegavam a ser tentados numa
    2a aplicacao) - este era o achado CRITICO #1 da auditoria. Mesmo
    fallback de NOME de CreateTableSQL quando ConstraintName vem vazio
    ('fk_'+tabela+'_'+coluna) - AddForeignKey exige um nome nao-vazio (sai
    sem efeito senao); ON DELETE/ON UPDATE vazios sao tolerados pelo
    proprio dialecto (FKeyAddSQL so acrescenta a clausula quando
    nao-vazia, ver Database.Dialect.pas). Tolerado POR-FK (cada constraint
    e' independente das restantes e dos proximos passos). }
  for I := 0 to High(FGroups) do
  begin
    LList := FGroups[I].group.GetTablesList;
    if Length(LList) = 0 then
      Continue;
    LFields := LList[0].GetFieldsList;
    for J := 0 to High(LFields) do
      if (Trim(LFields[J].ReferencedTable) <> '') and (Trim(LFields[J].ReferencedColumn) <> '') then
      begin
        LConstraintName := Trim(LFields[J].ConstraintName);
        if LConstraintName = '' then
          LConstraintName := 'fk_' + LList[0].TableName + '_' + LFields[J].Column;
        LRefTable := Trim(LFields[J].ReferencedTable);
        try
          LList[0].AddForeignKey(AConnection, LConstraintName, [LFields[J].Column],
            LRefTable, [LFields[J].ReferencedColumn],
            LFields[J].OnDeleteRule, LFields[J].OnUpdateRule);
        except
          { tolerado - idempotencia real fora do PostgreSQL depende disto
            (ver comentario completo acima); continua para a proxima FK/o
            proximo passo. }
        end;
      end;
  end;
  { (3) VIEWS - lancador IViews (Onda R2, Connection-bound - resolve o
    dialecto pela propria AConnection, ja idempotente - ViewExists por
    dentro de CreateView, ver Database.Views.pas). Try/except por-view
    (fix #1(CRITICO)/#3) - defesa em profundidade: mesmo ja idempotente, uma
    falha isolada (ex.: motor best-effort a rejeitar sintaxe, ver Access)
    nao pode abortar (4)-(6). }
  LViewsLauncher := TViews.New.Connection(AConnection);
  for I := 0 to High(FViews) do
    try
      LViewsLauncher.CreateView(FViews[I].Name, FViews[I].SelectSQL, FViews[I].OrReplace);
    except
      { tolerado - ver comentario acima. }
    end;
  { (4) PROCEDURES / FUNCTIONS - FRoutines particionado por Kind (mesmo
    criterio de StructureToJSON, acima); lancadores zero-SQL (Onda F1 - o
    dialecto compoe o CREATE, degradam para 0 onde o motor nao suporta,
    ja idempotentes - bug-965). Try/except por-routine (fix #1(CRITICO)/#3),
    mesmo motivo do passo (3). }
  LProcLauncher := TProcedures.New.Connection(AConnection);
  LFuncLauncher := TFunctions.New.Connection(AConnection);
  for I := 0 to High(FRoutines) do
    try
      if FRoutines[I].Kind = rkFunction then
        LFuncLauncher.Create(FRoutines[I])
      else
        LProcLauncher.Create(FRoutines[I]);
    except
      { tolerado - ver comentario do passo (3). }
    end;
  { (5) TRIGGERS - lancador ITriggers (Onda F3, ja idempotente -
    TriggerExists por dentro de CreateTrigger). Try/except por-trigger
    (fix #1(CRITICO)/#3), mesmo motivo do passo (3). }
  LTrgLauncher := TTriggers.New.Connection(AConnection);
  for I := 0 to High(FTriggers) do
    try
      LTrgLauncher.CreateTrigger(FTriggers[I]);
    except
      { tolerado - ver comentario do passo (3). }
    end;
  { (6) RULES - lancador IRules (Onda F4, ja idempotente - RuleExists por
    dentro de CreateRule); no-op nos motores sem o objecto RULE (so
    PostgreSQL/SQL Server suportam). Try/except por-rule (fix #1(CRITICO)/#3) -
    ultimo passo, mantido pelo mesmo principio (uniformidade/robustez a
    futuras extensoes depois deste). }
  LRuleLauncher := TRules.New.Connection(AConnection);
  for I := 0 to High(FRules) do
    try
      LRuleLauncher.CreateRule(FRules[I]);
    except
      { tolerado - ver comentario do passo (3). }
    end;
{$ENDIF}
end;

function TSchema.ToFullJSON: string;
begin
  { Onda S4 (ADITIVO) - COMPOE os 2 eixos JA EXISTENTES (StructureToJSON/
    ToJSON), sem reimplementar nenhum dos 2. }
  Result := '{"structure":' + StructureToJSON + ',"data":' + ToJSON + '}';
end;

function TSchema.SchemaFromFullJSON(const AJSON: string): ISchema;
var
  LStructure, LData: string;
begin
  { Onda S4 (ADITIVO) - decompoe via JSONExtractMember (SSOT, Database.
    Helpers.JSON) e delega, NESTA ORDEM (estrutura antes de dado - o eixo
    dado reconcilia por PK sobre os grupos FGroups JA CRIADOS pelo eixo
    estrutura), aos metodos "Schema*" irmaos (chamada directa, sem
    indirecao por interface). Tolerante: chave ausente nao aplica esse
    eixo. }
  Result := Self;
  LStructure := JSONExtractMember(AJSON, 'structure');
  if LStructure <> '' then
    SchemaStructureFromJSON(LStructure);
  LData := JSONExtractMember(AJSON, 'data');
  if LData <> '' then
    SchemaFromJSON(LData);
end;

function TSchema.SchemaMergeFullFromJSON(const AJSON: string): ISchema;
var
  LStructure, LData: string;
begin
  { Onda S4 (ADITIVO) - mesma decomposicao/ordem de SchemaFromFullJSON,
    delegando aos "patch" SchemaStructureMergeFromJSON/SchemaMergeFromJSON. }
  Result := Self;
  LStructure := JSONExtractMember(AJSON, 'structure');
  if LStructure <> '' then
    SchemaStructureMergeFromJSON(LStructure);
  LData := JSONExtractMember(AJSON, 'data');
  if LData <> '' then
    SchemaMergeFromJSON(LData);
end;

function TSchema.SchemaImport(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): ISchema;
begin
  { Onda S4 (ADITIVO) - despacha pelas 2 flags para o metodo "Schema*" ja
    existente correspondente. }
  Result := Self;
  if AWithData then
  begin
    if AMerge then
      SchemaMergeFullFromJSON(AJSON)
    else
      SchemaFromFullJSON(AJSON);
  end
  else
  begin
    if AMerge then
      SchemaStructureMergeFromJSON(AJSON)
    else
      SchemaStructureFromJSON(AJSON);
  end;
end;

function TSchema.Export(const AWithData: Boolean): string;
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
function TSchema.Export(const AWithData: Boolean; const AQuery: IQueryBuilder): string;
var
  LFullJSON: string;
begin
  { Onda S4 (ADITIVO) - ver comentario completo em TTable.Export(AWithData,
    AQuery); delega a TryExportQueryData (Database.Helpers.Export). Fallback
    de Connection = Connection (getter publico, herdado de TTables - SEM
    acesso directo a um campo FConnection, que e' privado a
    Database.Tables.pas, unit diferente). }
  if not AWithData then
    Exit(StructureToJSON);
  if TryExportQueryData(AQuery, Connection, StructureToJSON, LFullJSON) then
    Exit(LFullJSON);
  Result := ToFullJSON;
end;
{$ENDIF}

end.
