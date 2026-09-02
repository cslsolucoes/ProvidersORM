{ =============================================================================
  Database.QueryBuilder - Query Builder v3 (TQueryBuilder, TCaseBuilder, TQueryTransformer)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.1.0
  FileVersion:    2.12.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           01/08/2026

  FASE 5 Onda 5.3 (B1/B4) - REESCRITA v3 (B-freeze; owner autorizou "reescrever
  agora"). Constroi SQL sobre o IDialect (5.2) - quoting/paginacao/operadores
  por dialecto - com PARAMETROS FIRST-CLASS BINDADOS:

    * setters guardam DADOS BRUTOS; o render (BuildSQL) e a UNICA passagem que
      quota identificadores e binda valores (Bind -> :paramN, na ordem textual);
    * subqueries/UNION/CTE absorvidos com AbsorbSub (shift dos placeholders do
      sub para continuar a numeracao global);
    * mutations INSERT/UPDATE/DELETE NUNCA emitem literais (fecha o GAP
      GestorERP: datas por locale) - Execute usa a execucao PARAMETRIZADA do
      IConnection (:param0,:param1,...).

  Changelog (file):
  - 2.12.0 (01/08/2026): bug-1088 (FPC 3.2.2 nao suporta closures/anonymous
    methods) - TQueryBuilder.ExecuteAsync deixa de construir uma closure
    (function: TDataSet begin Result := LSelf.Execute; end) e passa a
    chamar TORMTask<TDataSet>.Run(Self.Execute, LSelf) - Self.Execute e o
    metodo of object (mesma assinatura function: TDataSet), LSelf e o
    AKeepAlive explicito (ver Database.QueryBuilder.Sychronize 1.2.0).
    Comportamento e API publica (IQueryBuilder.ExecuteAsync) inalterados -
    so a implementacao interna. Provado com execucao real nos 6 alvos
    antes desta aplicacao.
  - 2.11.0 (29/07/2026): Onda S3 (ADITIVO - eixo SQL do modulo, ver
    Databases.Interfaces 3.1.0) - novo overload DatabaseTypes(TDatabaseTypes):
    IQueryBuilder / DatabaseTypes: TDatabaseTypes (FDatabaseTypeOverride, novo
    campo, default dtNone) - dialecto INDEPENDENTE da conexao, MESMO padrao
    ja usado por ITable/ITables/ISchema/IDatabase.DatabaseTypes; Dialect()
    passa a resolver por FDatabaseTypeOverride (TDialect.ForDatabaseType)
    ANTES de Connection/fallback ANSI, quando o override <> dtNone (precedencia
    manual, mesmo criterio de IDatabase.DatabaseTypes). Motivacao: ITable.
    ToSQL/ITables.ToSQL (Database.Table.pas/Database.Tables.pas) precisam de
    um IQueryBuilder dialect-aware SEM exigir uma IConnection viva (script
    DDL/DML golden), e o modulo Database nao pode depender do TConnection
    CONCRETO (Connections.pas) - so da interface IConnection (boundary do
    modulo, ver CLAUDE.md) - o override resolve isto sem tocar Connections.
    100% aditivo/retrocompativel - Connection(AConnection)/Dialect
    pre-existentes inalterados quando o override nunca e chamado (default
    dtNone -> caminho antigo intacto, confirmado por leitura do corpo).
  - 2.10.2 (27/07/2026): conformidade F5 (onda C5, M7) - QBJSONQuoteString
    local removida; delega ao SSOT unico Database.Helpers.JSON.JSONQuoteString
    (regra #14).
  - 2.10.1 (26/07/2026): conformidade F5 (onda C2, doc-only) - M8/M9: gotchas do
    ExecuteAsync no comentario da impl (descartar o IORMTask -> WaitFor no
    Destroy -> sincrono bloqueante; corrida sobre FBound/FDialect/FStatistics se
    a instancia for reutilizada antes de Await). Sem mudanca de codigo.
  - 2.10.0 (21/07/2026): novo SetValueDelta(AColumn, ADelta) - UPDATE por
    auto-incremento "SET col = col +/- N" com AMBOS os lados quotados pelo dialeto
    (novo IsDelta/Delta no record TColVal; BuildUpdateSQL emite a expressao). Permite
    reordenacao/contadores SEM SQL manual no chamador (pedido do owner "zero SQL
    hardcore"); declarado tambem em Databases.Interfaces.IQueryBuilder. Usado no
    reorder on-insert/on-update do Parameters (F7). Gate: smoke_querybuilder verde;
    smoke_parameters_db 49/49 (reorder) em Zeos/FireDAC/SQLdb; S1 52/52.
  - 2.9.0 (17/07/2026): Onda 10-D (marshalling de VALOR cross-DB, ADITIVO) - Bind
    passa a homogeneizar o VALOR: quando e um BOOLEAN encaminha-o por
    Dialect.EncodeBoolean (PG/FB3+ boolean nativo; bit/smallint/integer nos
    demais; Access -1/0), no UNICO ponto por onde passa todo INSERT/UPDATE/WHERE
    bindado. Fecha o bug PG "column is of type boolean but expression is of type
    smallint". Callers passam Boolean natural (sem Ord()). Nao-booleanos intactos.
  - 2.8.0 (15/07/2026): Onda 6-f Estagio 2 (I11/A2, ADITIVO) -
    ExecuteAsync: IORMTask<TDataSet> - corre Execute NUMA THREAD de fundo
    (TORMTask<TDataSet>.Run, nova unit Database.QueryBuilder.Sychronize, ADITIVO no uses da
    implementation) e devolve IMEDIATAMENTE; ver comentario completo no
    metodo e em Databases.Interfaces.IQueryBuilder.ExecuteAsync (2.10.0).
  - 2.7.0 (15/07/2026): Onda 6-f Estagio 1 (I10, ADITIVO) - CallProcedure(AName,
    AArgs): novo TQBKind qbCall (aditivo, no FIM do enum - ordinais
    pre-existentes preservados) + FCallProc/FCallArgs (novos campos) +
    BuildCallSQL (novo, despachado por BuildSQL no case qbCall) - pede a
    Dialect.CallProcedureSQL(FCallProc, Length(FCallArgs)) o TEMPLATE com
    placeholders posicionais ':p0'..':p<N-1>' e substitui cada um pelo
    placeholder REAL do proprio Bind (:paramN, mesmo mecanismo das mutations -
    nunca literal), em ordem DESCENDENTE de indice (evita colisao de
    substring ':p1' dentro de ':p10' quando N>=11). Dialecto sem suporte
    (SQLite/Access - CallProcedureSQL='') -> BuildCallSQL devolve '' (ToSQL
    fica ''); Execute/ExecuteMutation ganham guarda ADITIVA (FKind=qbCall E
    SQL vazio) -> no-op gracioso (Result=nil/0, SEM chamar a IConnection,
    Statistics zeradas) em vez de tentar executar SQL vazio. Databases.
    Interfaces (2.9.0): novo IQueryBuilder.CallProcedure.
  - 2.6.0 (15/07/2026): Onda 6-e Estagio 4 (F5 revisao, I17, ADITIVO) -
    SavePreset: string / LoadPreset(AJSON): IQueryBuilder - serializa/
    reconstroi o estado ESSENCIAL da query (kind/table/schema/select/where/
    orderby/limit/offset) em JSON (fpjson/System.JSON, parser real - mesmo
    padrao GetJSON/TJSONObject.ParseJSONValue de Database.Field.pas); SELECT
    simples (skColumn) + WHERE de comparacao simples (whCmp, com o
    combinador Logic AND/OR de topo) + OrderBy (strings JA quotadas pelo
    dialecto - preset atado ao dialecto de origem) + Limit/Offset. NAO
    cobre SelectRaw/SelectComputed/agregados, WhereIn/Between/Null/Raw/
    InSubQuery/WhereGroup, Join/GroupBy/Having/Union/CTE/Distinct, valores
    de INSERT/UPDATE (Value/SetValue) - ver comentario completo no metodo e
    em Databases.Interfaces.IQueryBuilder.SavePreset. Helpers de unit novos
    (prefixo QB, mesmo padrao TableJSON*/JSON* duplicado por unit):
    QBJSONQuoteString/QBJSONBoolLiteral/QBVariantToJSONLiteral (SavePreset,
    RFC 8259) + QBJSONNodeToVariant (LoadPreset, dual FPC/Delphi).
    Databases.Interfaces (2.8.0): novo IQueryBuilder.SavePreset/LoadPreset.
  - 2.5.0 (15/07/2026): Onda 6-e Estagio 3 (F5 revisao, I19, ADITIVO) -
    WhereOp(AColumn, ASemanticOp, AValue): recebe um nome SEMANTICO
    ('eq'/'neq'/'gt'/'ge'/'lt'/'le'/'contains'/'startsWith'/'endsWith',
    case-insensitive) e delega a Where existente (mesmo mecanismo bindado -
    whCmp, :paramN); contains/startsWith/endsWith consultam
    Dialect.Supports(scILike) (ILIKE no PostgreSQL; LIKE nos restantes) e
    envolvem AValue em wildcards '%' ANTES de bindar (o wildcard faz parte do
    VALOR, nao do SQL - continua 100% parametrizado). Nome desconhecido ->
    EDatabaseQueryBuilderException (410081, ERR_DATABASE_QB_UNKNOWN_OP).
    Databases.Interfaces (2.7.0): novo IQueryBuilder.WhereOp.
  - 2.4.0 (15/07/2026): Onda 6-e Estagio 2 (F5 revisao, I18, ADITIVO) -
    grupos de filtro And/Or/Not aninhados no WHERE: TWhKind ganha whGroup +
    TWhLogic (wlAnd/wlOr, default wlAnd - zero-init preserva o AND-puro pre-
    existente) + TWhItem ganha Logic/Negate/Items (auto-referencia via array
    dinamico); RenderWhere vira wrapper de RenderWhereItems (RECURSIVO,
    trata whGroup emitindo parenteses + 'NOT ' se Negate; grupo sem itens =
    no-op, nao aparece no SQL). IQueryBuilder.OrWhere (condicao de topo
    combinada com OR) + WhereGroup (abre um novo TFilterGroup, classe local
    que implementa IFilterGroup - AndWhere/OrWhere acumulam dentro do grupo,
    NotGroup nega o grupo inteiro, EndGroup fecha e anexa ao WHERE do OWNER
    via o AddWhere privado, mesma unit). WHERE vs HAVING: OrHaving combina
    com o HAVING existente via OR ('(<existente>) OR (<novo>)'); sem HAVING
    previo comporta-se como Having; Having(...) continua a SOBRESCREVER
    (inalterado). 100% aditivo - todos os Where/WhereIn/WhereBetween/etc.
    pre-existentes continuam AND-puro top-level, zero mudanca de SQL gerado.
    Databases.Interfaces (2.6.0): novo IFilterGroup.
  - 2.3.0 (15/07/2026): Onda 6-e Estagio 1 (F5 revisao, I3+I15, ADITIVO) -
    Statistics: TQueryStatistics [devolve RowsAffected/ElapsedMs/LastSQL do
    ultimo Execute/ExecuteMutation; medido com GetTickCount64 (Winapi.Windows/
    Windows); RowsAffected=-1 em Execute (SELECT - dataset vivo, nao aplicavel),
    =Result em ExecuteMutation; sem execucao ainda -> record zerado] +
    ToSQLFormatted: string [SQL SEMPRE formatado (indentacao/quebras de linha),
    independente do estado de FPretty - reutiliza BuildSQL(NL) sem alterar
    FPretty]. Aditivo.
  - 2.2.0 (15/07/2026): Onda 6-c I5/I20 - JoinByFK(ARelation: TRelationInfo)
    [INNER JOIN a partir de uma relacao ja conhecida, identificadores quotados
    pelo dialecto, reutiliza Join] + AutoJoin(ATableName,ASchema) [descobre a
    FK entre a tabela FROM atual e ATableName via ICatalogReader.ResolveFK nas 2
    direccoes (FTable->ATableName; se nao achar, ATableName->FTable invertida)
    e chama JoinByFK; no-op sem Connection/From/FK] + DistinctValuesQuery
    (AColumn) [Smart Distinct: SELECT DISTINCT AColumn FROM <From atual> ORDER
    BY AColumn, reutiliza Select/Distinct/OrderBy]. Aditivo. uses Commons.
    Database.Types passa para a INTERFACE (TRelationInfo na assinatura de
    JoinByFK) + Database.CatalogReader na implementation (AutoJoin instancia
    TCatalogReader.New(FConnection) - sem ciclo, Database.CatalogReader NAO usa
    QueryBuilder).
  - 2.1.0 (14/07/2026): Onda 6-b I8 - SelectComputed(nome,expr) [coluna computada: expr AS ident(nome)] + FromVirtual(subquerySQL,alias) [FROM (sql) ident(alias)]. Aditivo; primitivas de query (decisao owner: computado/virtual sao conceitos de QueryBuilder, nao da hierarquia).
  - 2.0.0 (14/07/2026): Reorg 3 (owner) - ABSORVIDO o ex-Database.QueryTransformer (TQueryTransformer + TFilterValueProvider + tipos TQT*): a unit Database.QueryTransformer deixa de existir; IQueryTransformer/IFilterValueProvider continuam em Databases.Interfaces (Reorg 1); TQueryTransformer.New inalterado (agora reside nesta unit).
  - 2.0.0 (12/07/2026): reescrita v3 (Onda 5.3). Substitui a v1.1.1 (SELECT-only,
    EscapeValue literal). Params bindados, mutations, subqueries/UNION/CTE/CASE,
    paginacao via IDialect, pretty-print, erros 410080.
  ============================================================================= }
unit Database.QueryBuilder;

{$I ../../../ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$IFDEF USE_DATABASE}

uses
{$IFDEF FPC}
  SysUtils, Classes, Variants, DB, Generics.Collections,
{$ELSE}
  System.SysUtils, System.Classes, System.Variants, Data.DB,
  System.Generics.Collections,
{$ENDIF}
  Commons.Types,
  Commons.Database.Types,
  Connections.Interfaces,
  Databases.Interfaces;

type
  { qbCall (Onda 6-f Estagio 1, I10) - ADITIVO no FIM do enum: ordinais das 4
    variantes pre-existentes preservados (qbSelect=0/qbInsert=1/qbUpdate=2/
    qbDelete=3), zero impacto em qualquer "case FKind of" pre-existente que
    ja tinha "else" para o ramo SELECT (ver BuildSQL). }
  TQBKind  = (qbSelect, qbInsert, qbUpdate, qbDelete, qbCall);
  TSelKind = (skColumn, skRaw, skAgg);
  TWhKind  = (whCmp, whIn, whNotIn, whBetween, whNull, whNotNull, whRaw, whInSub, whGroup);
  { I18 (Onda 6-e Estagio 2) - combinador do item com o(s) item(ns) anterior(es)
    no MESMO nivel (top-level FWhere ou dentro de um whGroup.Items); ignorado
    no 1o item de cada nivel. Default (zero-init) = wlAnd - preserva o
    comportamento AND-puro pre-existente sem alterar nenhum caller antigo. }
  TWhLogic = (wlAnd, wlOr);

  TSelItem = record
    Kind  : TSelKind;
    Expr  : string;   // coluna (skColumn) / expr livre (skRaw) / coluna do agg (skAgg)
    Func  : string;   // COUNT/SUM/... (skAgg)
    Alias : string;
  end;

  TWhItem = record
    Kind   : TWhKind;
    Logic  : TWhLogic;           // combinador com o item anterior no mesmo nivel (I18)
    Negate : Boolean;            // whGroup: nega o grupo -> NOT (...) (I18)
    Column : string;
    Op     : string;
    Val1   : Variant;
    Val2   : Variant;           // whBetween (limite superior)
    Vals   : array of Variant;  // whIn / whNotIn
    Raw    : string;            // whRaw
    Sub    : IQueryBuilder;     // whInSub
    Items  : array of TWhItem;  // whGroup (I18) - itens do grupo parentizado
  end;

  TColVal = record
    Column  : string;
    Value   : Variant;
    IsDelta : Boolean;   // True: SET col = col + Delta (auto-incremento dialect-aware; o CALLER nao escreve SQL)
    Delta   : Integer;
  end;

  TUnionItem = record
    QB  : IQueryBuilder;
    All : Boolean;
  end;

  TCTEItem = record
    Name : string;
    QB   : IQueryBuilder;
  end;

  TQueryBuilder = class(TInterfacedObject, IQueryBuilder)
  private
    FConnection   : IConnection;
    FDialect      : IDialect;
    { Onda S3 - dialecto INDEPENDENTE da conexao (golden/SQL SEM servidor,
      mesmo padrao ja usado por ITable/ITables/ISchema/IDatabase.DatabaseTypes);
      dtNone (default) = sem override, Dialect() cai no caminho pre-existente
      (Connection ou fallback ANSI). Ver DatabaseTypes(AValue)/DatabaseTypes,
      publico, abaixo. }
    FDatabaseTypeOverride: TDatabaseTypes;
    FKind         : TQBKind;
    FDistinct     : Boolean;
    FPretty       : Boolean;
    FSel          : array of TSelItem;
    FTable        : string;
    FSchema       : string;
    FFromSub      : IQueryBuilder;
    FFromSubAlias : string;
    FFromRawSub      : string;  // FromVirtual: SQL cru (fonte virtual); '' = inactivo
    FFromRawSubAlias : string;
    FJoins        : TStringList;
    FWhere        : array of TWhItem;
    FGroupBy      : string;
    FHaving       : string;
    FOrderBy      : TStringList;
    FLimit        : Integer;
    FOffset       : Integer;
    FUnions       : array of TUnionItem;
    FCTEs         : array of TCTEItem;
    FColVals      : array of TColVal;
    FBound        : TList<Variant>;
    FStatistics   : TQueryStatistics;  // I3 (Onda 6-e) - do ultimo Execute/ExecuteMutation
    FCallProc     : string;            // I10 (Onda 6-f) - nome da procedure (qbCall)
    FCallArgs     : array of Variant;  // I10 (Onda 6-f) - argumentos POSICIONAIS (qbCall)
    function  Dialect: IDialect;
    function  Q(const AName: string): string;                 // quota 1 identificador
    function  QCsv(const ACsv: string; const ASuffix: string = ''): string;
    function  Bind(const AValue: Variant): string;            // valor -> :paramN
    function  AbsorbSub(const ASub: IQueryBuilder): string;   // SQL do sub, params re-numerados
    procedure AddWhere(const AItem: TWhItem);
    procedure NeedTable(const AOp: string);
    procedure NeedColumns(const AOp: string);
    function  RenderSelectColumns: string;
    function  RenderTableRef(const ATable, ASchema: string): string;
    function  RenderWhereItems(const AItems: array of TWhItem): string; // I18 - recursivo (whGroup)
    function  RenderWhere: string;
    function  BuildSelectSQL(const NL: string): string;
    function  BuildInsertSQL: string;
    function  BuildUpdateSQL(const NL: string): string;
    function  BuildDeleteSQL(const NL: string): string;
    function  BuildCallSQL: string;    // I10 (Onda 6-f)
    function  BuildSQL: string;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: IQueryBuilder;

    function Connection(const AConnection: IConnection): IQueryBuilder; overload;
    function Connection: IConnection; overload;
    { Onda S3 - ver comentario completo em Databases.Interfaces.IQueryBuilder. }
    function DatabaseTypes(const AValue: TDatabaseTypes): IQueryBuilder; overload;
    function DatabaseTypes: TDatabaseTypes; overload;

    function Select(const AColumns: TStringArray): IQueryBuilder; overload;
    function Select(const AColumns: string = '*'): IQueryBuilder; overload;
    function SelectRaw(const AExpression: string): IQueryBuilder;
    function SelectComputed(const AName, AExpression: string): IQueryBuilder;
    function Distinct(const AValue: Boolean = True): IQueryBuilder;
    function Count(const AColumn: string = '*'; const AAlias: string = ''): IQueryBuilder;
    function Sum(const AColumn: string; const AAlias: string = ''): IQueryBuilder;
    function Max(const AColumn: string; const AAlias: string = ''): IQueryBuilder;
    function Min(const AColumn: string; const AAlias: string = ''): IQueryBuilder;
    function Avg(const AColumn: string; const AAlias: string = ''): IQueryBuilder;

    function From(const ATable: string; const ASchema: string = ''): IQueryBuilder; overload;
    function From(const ASubQuery: IQueryBuilder; const AAlias: string): IQueryBuilder; overload;
    function FromVirtual(const ASubQuerySQL, AAlias: string): IQueryBuilder;

    function Join(const ATable, ACondition: string): IQueryBuilder;
    function LeftJoin(const ATable, ACondition: string): IQueryBuilder;
    function RightJoin(const ATable, ACondition: string): IQueryBuilder;
    function JoinByFK(const ARelation: TRelationInfo): IQueryBuilder;
    function AutoJoin(const ATableName: string; const ASchema: string = ''): IQueryBuilder;

    function Where(const AColumn, AOp: string; const AValue: Variant): IQueryBuilder; overload;
    function Where(const AColumn: string; const AValue: Variant): IQueryBuilder; overload;
    function OrWhere(const AColumn, AOp: string; const AValue: Variant): IQueryBuilder; overload;
    function OrWhere(const AColumn: string; const AValue: Variant): IQueryBuilder; overload;
    function WhereIn(const AColumn: string; const AValues: array of Variant): IQueryBuilder;
    function WhereNotIn(const AColumn: string; const AValues: array of Variant): IQueryBuilder;
    function WhereBetween(const AColumn: string; const ALow, AHigh: Variant): IQueryBuilder;
    function WhereInSubQuery(const AColumn: string; const ASubQuery: IQueryBuilder): IQueryBuilder;
    function WhereIsNull(const AColumn: string): IQueryBuilder;
    function WhereIsNotNull(const AColumn: string): IQueryBuilder;
    function WhereOp(const AColumn, ASemanticOp: string; const AValue: Variant): IQueryBuilder;
    function WhereRaw(const ACondition: string): IQueryBuilder;
    function WhereGroup: IFilterGroup;

    function GroupBy(const AColumns: string): IQueryBuilder; overload;
    function GroupBy(const AColumns: TStringArray): IQueryBuilder; overload;
    function Having(const ACondition: string): IQueryBuilder;
    function OrHaving(const ACondition: string): IQueryBuilder;
    function OrderBy(const AColumns: string): IQueryBuilder; overload;
    function OrderBy(const AColumns: TStringArray): IQueryBuilder; overload;
    function OrderByDesc(const AColumns: string): IQueryBuilder;

    function Limit(const AValue: Integer): IQueryBuilder;
    function Offset(const AValue: Integer): IQueryBuilder;

    function UnionWith(const AOther: IQueryBuilder; const AAll: Boolean = False): IQueryBuilder;
    function WithCTE(const AName: string; const AQuery: IQueryBuilder): IQueryBuilder;

    function DistinctValuesQuery(const AColumn: string): IQueryBuilder;

    function InsertInto(const ATable: string; const ASchema: string = ''): IQueryBuilder;
    function Value(const AColumn: string; const AValue: Variant): IQueryBuilder;
    function Update(const ATable: string; const ASchema: string = ''): IQueryBuilder;
    function SetValue(const AColumn: string; const AValue: Variant): IQueryBuilder;
    { UPDATE por auto-incremento: SET col = col + ADelta (dialect-aware, ambos os lados
      quotados pelo dialeto). Permite reordenacao/contadores SEM SQL manual no chamador. }
    function SetValueDelta(const AColumn: string; const ADelta: Integer): IQueryBuilder;
    function DeleteFrom(const ATable: string; const ASchema: string = ''): IQueryBuilder;

    function Pretty(const AValue: Boolean = True): IQueryBuilder;
    function ToSQLFormatted: string;

    function ToSQL: string;
    function Params: TArray<Variant>;
    function Execute: TDataSet;
    function ExecuteMutation: Integer;
    { I11/A2 (Onda 6-f Estagio 2) - ver comentario completo em
      Databases.Interfaces.IQueryBuilder.ExecuteAsync. }
    function ExecuteAsync: IORMTask<TDataSet>;
    function Statistics: TQueryStatistics;

    { I17 (Onda 6-e Estagio 4) - presets JSON (ver comentario completo em
      Databases.Interfaces.IQueryBuilder.SavePreset). }
    function SavePreset: string;
    function LoadPreset(const AJSON: string): IQueryBuilder;

    { I10 (Onda 6-f Estagio 1) }
    function CallProcedure(const AName: string; const AArgs: array of Variant): IQueryBuilder;
  end;

  { I18 (Onda 6-e Estagio 2) - grupo de filtros PARENTIZADO (IFilterGroup).
    FOwner e o TQueryBuilder CONCRETO (nao a interface) - mesma unit, acesso
    directo ao AddWhere private (nao ha "friend class" em Object Pascal, mas
    "private" e unit-scoped: qualquer classe DESTA unit acede aos privados de
    outra classe DESTA unit). EndGroup monta 1 TWhItem (Kind=whGroup) com os
    itens acumulados em FItems e chama FOwner.AddWhere - o mesmo mecanismo do
    WHERE top-level, sem duplicar logica de render (RenderWhereItems e
    recursivo e trata whGroup). }
  TFilterGroup = class(TInterfacedObject, IFilterGroup)
  private
    FOwner  : TQueryBuilder;
    FItems  : array of TWhItem;
    FNegate : Boolean;
    procedure AddItem(const AItem: TWhItem);
  public
    constructor Create(const AOwner: TQueryBuilder);
    function AndWhere(const AColumn, AOp: string; const AValue: Variant): IFilterGroup; overload;
    function AndWhere(const AColumn: string; const AValue: Variant): IFilterGroup; overload;
    function OrWhere(const AColumn, AOp: string; const AValue: Variant): IFilterGroup; overload;
    function OrWhere(const AColumn: string; const AValue: Variant): IFilterGroup; overload;
    function NotGroup: IFilterGroup;
    function EndGroup: IQueryBuilder;
  end;

  TCaseBuilder = class(TInterfacedObject, ICaseBuilder)
  private
    FExpr : string;
    FElse : string;
  public
    class function New: ICaseBuilder;
    function WhenThen(const ACondition, AResult: string): ICaseBuilder;
    function ElseResult(const AResult: string): ICaseBuilder;
    function EndAs(const AAlias: string = ''): string;
  end;

  { ===== QueryTransformer (B3) - absorvido do ex-Database.QueryTransformer (Reorg 3) ===== }
  TQTFKind = (qfEq, qfNeq, qfGt, qfGe, qfLt, qfLe, qfBetween, qfLike, qfIn,
    qfNull, qfNotNull);
  TQTLikeMode = (lmContains, lmStarts, lmEnds);

  TQTFilter = record
    Kind  : TQTFKind;
    Col   : string;
    V1    : Variant;
    V2    : Variant;              // qfBetween
    Vals  : array of Variant;     // qfIn
    Text  : string;               // qfLike - texto original (T5 ToHumanText)
    LMode : TQTLikeMode;          // qfLike - modo (contains/starts/ends)
  end;

  TQTSort = record
    Col  : string;
    Desc : Boolean;
  end;

  TQTColumn = record
    Name    : string;
    Alias   : string;
    Include : Boolean;   // gera SQL
    Visible : Boolean;   // so UI (N5)
  end;

  TQueryTransformer = class(TInterfacedObject, IQueryTransformer)
  private
    FSource  : IQueryBuilder;
    FFilters : array of TQTFilter;
    FSorts   : array of TQTSort;
    FColumns : array of TQTColumn;
    FLimit   : Integer;
    FOffset  : Integer;
    FValueProvider : IFilterValueProvider;
    procedure AddFilter(const AKind: TQTFKind; const ACol: string;
      const AV1: Variant); overload;
    procedure AddLike(const ACol, APattern, AText: string; const AMode: TQTLikeMode);
    function  BuildQB: IQueryBuilder;
    function  HumanValue(const AValue: Variant): string;
  public
    constructor Create;
    class function New: IQueryTransformer;

    function Source(const AQuery: IQueryBuilder): IQueryTransformer;

    function Equal(const AColumn: string; const AValue: Variant): IQueryTransformer;
    function NotEqual(const AColumn: string; const AValue: Variant): IQueryTransformer;
    function GreaterThan(const AColumn: string; const AValue: Variant): IQueryTransformer;
    function GreaterOrEqual(const AColumn: string; const AValue: Variant): IQueryTransformer;
    function LessThan(const AColumn: string; const AValue: Variant): IQueryTransformer;
    function LessOrEqual(const AColumn: string; const AValue: Variant): IQueryTransformer;
    function Between(const AColumn: string; const ALow, AHigh: Variant): IQueryTransformer;
    function Contains(const AColumn, AText: string): IQueryTransformer;
    function StartsWith(const AColumn, AText: string): IQueryTransformer;
    function EndsWith(const AColumn, AText: string): IQueryTransformer;
    function IsIn(const AColumn: string; const AValues: array of Variant): IQueryTransformer;
    function IsNull(const AColumn: string): IQueryTransformer;
    function IsNotNull(const AColumn: string): IQueryTransformer;

    function OrderByAsc(const AColumn: string): IQueryTransformer;
    function OrderByDesc(const AColumn: string): IQueryTransformer;

    function Column(const AName: string; const AInclude: Boolean = True;
      const AVisible: Boolean = True; const AAlias: string = ''): IQueryTransformer;

    function Page(const APageIndex, APageSize: Integer): IQueryTransformer;
    function Limit(const AValue: Integer): IQueryTransformer;
    function Offset(const AValue: Integer): IQueryTransformer;

    function ToSQL: string;
    function Params: TArray<Variant>;
    function VisibleColumns: TStringArray;
    function Execute: TDataSet;
    function ToHumanText: string;
    function FilterValues: IFilterValueProvider;
  end;

  { T1 - provider de valores distintos por campo (SELECT DISTINCT via
    QueryBuilder), com cache invalidavel. }
  TFilterValueProvider = class(TInterfacedObject, IFilterValueProvider)
  private
    FSource : IQueryBuilder;
    FCache  : TDictionary<string, TArray<Variant>>;
  public
    constructor Create(const ASource: IQueryBuilder);
    destructor Destroy; override;
    function ForColumn(const AColumn: string): TArray<Variant>;
    function Invalidate: IFilterValueProvider;
    function InvalidateColumn(const AColumn: string): IFilterValueProvider;
  end;

{$ENDIF}

implementation

{$IFDEF USE_DATABASE}

uses
{$IFDEF FPC}
  Windows,        // GetTickCount64 (I3 - Onda 6-e Estagio 1)
  DateUtils, fpjson, jsonparser, // I17 (Onda 6-e Estagio 4) - presets JSON
{$ELSE}
  Winapi.Windows, // GetTickCount64 (I3 - Onda 6-e Estagio 1)
  System.DateUtils, System.JSON, // I17 (Onda 6-e Estagio 4) - presets JSON
{$ENDIF}
  Commons.Database.Consts,
  Exceptions.Database,
  Database.Dialect,
  Database.CatalogReader,
  Database.Helpers.JSON,
  Database.QueryBuilder.Sychronize; // I11/A2 (Onda 6-f Estagio 2) - TORMTask<T> (ExecuteAsync)

{ ---- helper de split por virgula (cross-compiler, sem StrUtils) ---- }

function SplitCsv(const ACsv: string): TStringArray;
var
  LList: TStringList;
  I: Integer;
begin
  LList := TStringList.Create;
  try
    LList.StrictDelimiter := True;
    LList.Delimiter := ',';
    LList.DelimitedText := ACsv;
    SetLength(Result, LList.Count);
    for I := 0 to LList.Count - 1 do
      Result[I] := Trim(LList[I]);
  finally
    LList.Free;
  end;
end;

{ join manual - NAO usar TStringList.DelimitedText (re-quota itens que ja tem
  aspas/espacos, ex.: "name" -> """name""") }
function JoinList(const AList: TStringList; const ASep: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to AList.Count - 1 do
  begin
    if Result <> '' then Result := Result + ASep;
    Result := Result + AList[I];
  end;
end;

{ ---- helpers JSON (I17, Onda 6-e Estagio 4) - RFC 8259, NUNCA QuotedStr
  (bug-293). Onda C5 (M7, conformidade F5): QBJSONQuoteString local removida;
  delega ao SSOT unico Database.Helpers.JSON.JSONQuoteString (regra #14). ---- }

function QBJSONBoolLiteral(const AValue: Boolean): string;
begin
  if AValue then
    Result := 'true'
  else
    Result := 'false';
end;

{ Converte um Variant (valor de 1 filtro whCmp) para o literal JSON
  equivalente - mesmo mapa de Database.Field.pas.VariantToJSONLiteral: datas
  -> ISO-8601 LOCAL (o round-trip de volta NAO reconstroi TDateTime - fica
  string, mesma limitacao de QBJSONNodeToVariant/JSONNodeToVariant nas outras
  units); numericos -> literal numerico (separador decimal '.' forcado);
  Null/Unassigned -> "null"; resto -> string escapada. }
function QBVariantToJSONLiteral(const AValue: Variant): string;
var
  LFS: TFormatSettings;
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
    Exit('null');
  {$IF DEFINED(FPC)}
  LFS := DefaultFormatSettings;
  {$ELSE}
  LFS := FormatSettings;
  {$ENDIF}
  LFS.DecimalSeparator := '.';
  case VarType(AValue) and varTypeMask of
    varBoolean:
      Result := QBJSONBoolLiteral(Boolean(AValue));
    varDate:
      Result := JSONQuoteString(DateToISO8601(VarToDateTime(AValue), False));
    varByte, varSmallInt, varInteger, varShortInt, varWord, varLongWord,
    varInt64{$IFNDEF FPC}, varUInt64{$ENDIF}:
      Result := IntToStr(Int64(AValue));
    varSingle, varDouble, varCurrency:
      Result := FloatToStr(Double(AValue), LFS);
  else
    Result := JSONQuoteString(VarToStr(AValue));
  end;
end;

{ Converte o node JSON (ja localizado) de volta a Variant - numero com fracao
  0 -> Int64; numero com fracao -> Double; boolean/string/null diretos.
  Implementacao duplicada por compilador (mesmo padrao de
  Database.Field.pas.JSONNodeToVariant). }
{$IF DEFINED(FPC)}
function QBJSONNodeToVariant(ANode: TJSONData): Variant;
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
function QBJSONNodeToVariant(ANode: TJSONValue): Variant;
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

{ TQueryBuilder }

constructor TQueryBuilder.Create;
begin
  inherited Create;
  FKind := qbSelect;
  FDatabaseTypeOverride := dtNone;
  FDistinct := False;
  FPretty := False;
  FLimit := -1;
  FOffset := 0;
  FGroupBy := '';
  FHaving := '';
  FJoins := TStringList.Create;
  FOrderBy := TStringList.Create;
  FBound := TList<Variant>.Create;
end;

destructor TQueryBuilder.Destroy;
begin
  FJoins.Free;
  FOrderBy.Free;
  FBound.Free;
  inherited Destroy;
end;

class function TQueryBuilder.New: IQueryBuilder;
begin
  Result := TQueryBuilder.Create;
end;

function TQueryBuilder.Dialect: IDialect;
begin
  if FDialect = nil then
  begin
    { Onda S3 - o override por DatabaseTypes (golden/SQL sem servidor) tem
      PRECEDENCIA sobre Connection quando ambos estao definidos - mesmo
      criterio de override manual ja documentado em IDatabase.DatabaseTypes. }
    if FDatabaseTypeOverride <> dtNone then
      FDialect := TDialect.ForDatabaseType(FDatabaseTypeOverride)
    else if FConnection <> nil then
      FDialect := TDialect.ForConnection(FConnection)
    else
      FDialect := TDialect.Create(dtNone); // fallback ANSI (quoting ")
  end;
  Result := FDialect;
end;

function TQueryBuilder.Q(const AName: string): string;
begin
  Result := Dialect.QuoteIdentifier(AName);
end;

function TQueryBuilder.QCsv(const ACsv: string; const ASuffix: string): string;
var
  LCols: TStringArray;
  I: Integer;
begin
  LCols := SplitCsv(ACsv);
  Result := '';
  for I := 0 to High(LCols) do
  begin
    if LCols[I] = '' then Continue;
    if Result <> '' then Result := Result + ', ';
    Result := Result + Q(LCols[I]) + ASuffix;
  end;
end;

function TQueryBuilder.Bind(const AValue: Variant): string;
var
  LValue: Variant;
begin
  { Onda 10-D (marshalling de VALOR cross-DB) - homogeneizacao do valor no UNICO
    ponto por onde passa todo INSERT/UPDATE/WHERE bindado do projeto: quando o
    valor e um BOOLEAN, o DIALECTO decide a representacao correcta para o seu
    banco/versao (PostgreSQL/Firebird3+ -> boolean nativo; bit/smallint/integer
    nos demais; Access -> -1/0). Sem isto o PostgreSQL (tipagem estrita) rejeita
    "column is of type boolean but expression is of type smallint". Os callers
    passam o Boolean NATURAL (nunca Ord()). Nao-booleanos passam intactos. }
  if VarType(AValue) = varBoolean then
    LValue := Dialect.EncodeBoolean(AValue)
  else if VarType(AValue) = varDate then
    { Fase 1 repasse - mesmo padrao do boolean para DATETIME: o dialecto decide
      a representacao bindavel (base passthrough; Access/Jet -> string, o ADO
      rejeita varDate no parametro - "Data type mismatch", sonda 19/07). }
    LValue := Dialect.EncodeDateTime(VarToDateTime(AValue))
  else
    LValue := AValue;
  FBound.Add(LValue);
  Result := ':param' + IntToStr(FBound.Count - 1);
end;

{ desloca os placeholders :paramN do sub para continuar a numeracao global e
  absorve os valores do sub na ordem (parse manual - evita colisao param1/param10) }
function TQueryBuilder.AbsorbSub(const ASub: IQueryBuilder): string;
var
  LSql: string;
  LParams: TArray<Variant>;
  LOffset, I, LStart: Integer;
  LNum: string;
  C: Char;
begin
  LOffset := FBound.Count;
  LSql := ASub.ToSQL;
  LParams := ASub.Params;
  for I := 0 to High(LParams) do
    FBound.Add(LParams[I]);
  Result := '';
  I := 1;
  while I <= Length(LSql) do
  begin
    if (LSql[I] = ':') and (Copy(LSql, I, 6) = ':param') then
    begin
      LStart := I + 6;
      LNum := '';
      while LStart <= Length(LSql) do
      begin
        C := LSql[LStart];
        if (C >= '0') and (C <= '9') then
        begin
          LNum := LNum + C;
          Inc(LStart);
        end
        else
          Break;
      end;
      if LNum <> '' then
      begin
        Result := Result + ':param' + IntToStr(StrToInt(LNum) + LOffset);
        I := LStart;
        Continue;
      end;
    end;
    Result := Result + LSql[I];
    Inc(I);
  end;
end;

procedure TQueryBuilder.AddWhere(const AItem: TWhItem);
var
  N: Integer;
begin
  N := Length(FWhere);
  SetLength(FWhere, N + 1);
  FWhere[N] := AItem;
end;

procedure TQueryBuilder.NeedTable(const AOp: string);
begin
  if (FTable = '') and (FFromSub = nil) and (FFromRawSub = '') then
    raise EDatabaseQueryBuilderException.Create(
      Format(DB_ERR_QB_NO_TABLE_MSG, [AOp]), ERR_DATABASE_QUERYBUILDER);
end;

procedure TQueryBuilder.NeedColumns(const AOp: string);
begin
  if Length(FColVals) = 0 then
    raise EDatabaseQueryBuilderException.Create(
      Format(DB_ERR_QB_NO_COLUMNS_MSG, [AOp]), ERR_DATABASE_QUERYBUILDER);
end;

{ ---- setters (guardam dados brutos) ---- }

function TQueryBuilder.Connection(const AConnection: IConnection): IQueryBuilder;
begin
  FConnection := AConnection;
  FDialect := nil; // forca re-resolucao do dialecto
  Result := Self;
end;

function TQueryBuilder.Connection: IConnection;
begin
  Result := FConnection;
end;

function TQueryBuilder.DatabaseTypes(const AValue: TDatabaseTypes): IQueryBuilder;
begin
  { Onda S3 - ver comentario completo em Databases.Interfaces.IQueryBuilder.
    DatabaseTypes. Nao mexe em FConnection (as duas via podem coexistir -
    Execute/ExecuteMutation continuam a usar FConnection; so o dialecto passa
    a ser resolvido pelo override, com precedencia - ver Dialect, acima). }
  FDatabaseTypeOverride := AValue;
  FDialect := nil; // forca re-resolucao do dialecto
  Result := Self;
end;

function TQueryBuilder.DatabaseTypes: TDatabaseTypes;
begin
  Result := FDatabaseTypeOverride;
end;

function TQueryBuilder.Select(const AColumns: TStringArray): IQueryBuilder;
var
  I, N: Integer;
begin
  for I := 0 to High(AColumns) do
  begin
    N := Length(FSel);
    SetLength(FSel, N + 1);
    FSel[N].Kind := skColumn;
    FSel[N].Expr := Trim(AColumns[I]);
  end;
  Result := Self;
end;

function TQueryBuilder.Select(const AColumns: string): IQueryBuilder;
begin
  Result := Select(SplitCsv(AColumns));
end;

function TQueryBuilder.SelectRaw(const AExpression: string): IQueryBuilder;
var
  N: Integer;
begin
  N := Length(FSel);
  SetLength(FSel, N + 1);
  FSel[N].Kind := skRaw;
  FSel[N].Expr := AExpression;
  Result := Self;
end;

{ coluna computada: AExpression e SQL CRU (nao quotado); AName e o alias,
  quotado como identificador no render (RenderSelectColumns honra FSel.Alias
  tambem para skRaw, emitindo "<AExpression> AS <ident(AName)>") }
function TQueryBuilder.SelectComputed(const AName, AExpression: string): IQueryBuilder;
var
  N: Integer;
begin
  N := Length(FSel);
  SetLength(FSel, N + 1);
  FSel[N].Kind := skRaw;
  FSel[N].Expr := AExpression;
  FSel[N].Alias := Trim(AName);
  Result := Self;
end;

function TQueryBuilder.Distinct(const AValue: Boolean): IQueryBuilder;
begin
  FDistinct := AValue;
  Result := Self;
end;

function TQueryBuilder.Count(const AColumn, AAlias: string): IQueryBuilder;
var
  N: Integer;
begin
  N := Length(FSel);
  SetLength(FSel, N + 1);
  FSel[N].Kind := skAgg;
  FSel[N].Func := 'COUNT';
  FSel[N].Expr := AColumn;
  FSel[N].Alias := AAlias;
  Result := Self;
end;

function TQueryBuilder.Sum(const AColumn, AAlias: string): IQueryBuilder;
var
  N: Integer;
begin
  N := Length(FSel);
  SetLength(FSel, N + 1);
  FSel[N].Kind := skAgg;
  FSel[N].Func := 'SUM';
  FSel[N].Expr := AColumn;
  FSel[N].Alias := AAlias;
  Result := Self;
end;

function TQueryBuilder.Max(const AColumn, AAlias: string): IQueryBuilder;
var
  N: Integer;
begin
  N := Length(FSel);
  SetLength(FSel, N + 1);
  FSel[N].Kind := skAgg;
  FSel[N].Func := 'MAX';
  FSel[N].Expr := AColumn;
  FSel[N].Alias := AAlias;
  Result := Self;
end;

function TQueryBuilder.Min(const AColumn, AAlias: string): IQueryBuilder;
var
  N: Integer;
begin
  N := Length(FSel);
  SetLength(FSel, N + 1);
  FSel[N].Kind := skAgg;
  FSel[N].Func := 'MIN';
  FSel[N].Expr := AColumn;
  FSel[N].Alias := AAlias;
  Result := Self;
end;

function TQueryBuilder.Avg(const AColumn, AAlias: string): IQueryBuilder;
var
  N: Integer;
begin
  N := Length(FSel);
  SetLength(FSel, N + 1);
  FSel[N].Kind := skAgg;
  FSel[N].Func := 'AVG';
  FSel[N].Expr := AColumn;
  FSel[N].Alias := AAlias;
  Result := Self;
end;

function TQueryBuilder.From(const ATable, ASchema: string): IQueryBuilder;
begin
  FKind := qbSelect;
  FTable := Trim(ATable);
  FSchema := Trim(ASchema);
  FFromRawSub := '';       // ultimo From*/FromVirtual chamado vence - limpa a fonte virtual
  FFromRawSubAlias := '';
  Result := Self;
end;

function TQueryBuilder.From(const ASubQuery: IQueryBuilder; const AAlias: string): IQueryBuilder;
begin
  FKind := qbSelect;
  FFromSub := ASubQuery;
  FFromSubAlias := Trim(AAlias);
  FFromRawSub := '';       // ultimo From*/FromVirtual chamado vence - limpa a fonte virtual
  FFromRawSubAlias := '';
  Result := Self;
end;

{ fonte virtual: ASubQuerySQL e um SELECT completo CRU (nao quotado/nao
  parametrizado por este QB); AAlias e quotado. Ultimo From()/FromVirtual()
  chamado vence - limpa o outro estado de FROM (FTable/FSchema/FFromSub) para
  nao acumular. }
function TQueryBuilder.FromVirtual(const ASubQuerySQL, AAlias: string): IQueryBuilder;
begin
  FKind := qbSelect;
  FFromRawSub := ASubQuerySQL;
  FFromRawSubAlias := Trim(AAlias);
  FTable := '';
  FSchema := '';
  FFromSub := nil;
  FFromSubAlias := '';
  Result := Self;
end;

function TQueryBuilder.Join(const ATable, ACondition: string): IQueryBuilder;
begin
  FJoins.Add('INNER JOIN ' + ATable + ' ON ' + ACondition);
  Result := Self;
end;

function TQueryBuilder.LeftJoin(const ATable, ACondition: string): IQueryBuilder;
begin
  FJoins.Add('LEFT JOIN ' + ATable + ' ON ' + ACondition);
  Result := Self;
end;

function TQueryBuilder.RightJoin(const ATable, ACondition: string): IQueryBuilder;
begin
  FJoins.Add('RIGHT JOIN ' + ATable + ' ON ' + ACondition);
  Result := Self;
end;

{ Onda 6-c (I5) - JOIN a partir de uma relacao ja conhecida (identificadores
  quotados pelo dialecto, ao contrario de Join/LeftJoin/RightJoin que recebem
  ATable/ACondition crus do caller); reutiliza o mesmo mecanismo (Join). }
function TQueryBuilder.JoinByFK(const ARelation: TRelationInfo): IQueryBuilder;
var
  LCondition: string;
begin
  LCondition := Q(ARelation.FromTable) + '.' + Q(ARelation.FromColumn) + ' = ' +
                Q(ARelation.ToTable) + '.' + Q(ARelation.ToColumn);
  Result := Join(Q(ARelation.ToTable), LCondition);
end;

{ Onda 6-c (I5) - descobre a FK entre a tabela FROM atual (FTable) e
  ATableName via ICatalogReader, nas 2 direcoes: (1) FTable->ATableName (ResolveFK
  de FTable, procura ToTable=ATableName); (2) se nao achar, ATableName->FTable
  (ResolveFK de ATableName, procura ToTable=FTable) INVERTIDA (troca From/To)
  para o ON ficar sempre "FTable.col = ATableName.col". No-op (Self, sem
  alterar) se FConnection/FTable nao estiverem definidos ou sem FK entre as 2. }
function TQueryBuilder.AutoJoin(const ATableName: string; const ASchema: string): IQueryBuilder;
var
  LMeta      : ICatalogReader;
  LRelations : TArray<TRelationInfo>;
  LRelation  : TRelationInfo;
  LFound     : Boolean;
  I          : Integer;
begin
  Result := Self;
  if (FConnection = nil) or (Trim(FTable) = '') or (Trim(ATableName) = '') then
    Exit;

  LMeta := TCatalogReader.New(FConnection);
  LFound := False;

  { direccao 1: FK de FTable -> ATableName }
  LRelations := LMeta.ResolveFK(FTable, FSchema);
  for I := 0 to High(LRelations) do
    if SameText(LRelations[I].ToTable, ATableName) then
    begin
      LRelation := LRelations[I];
      LFound := True;
      Break;
    end;

  { direccao 2: FK de ATableName -> FTable, invertida (From/To trocados) }
  if not LFound then
  begin
    LRelations := LMeta.ResolveFK(ATableName, ASchema);
    for I := 0 to High(LRelations) do
      if SameText(LRelations[I].ToTable, FTable) then
      begin
        LRelation.FromTable   := LRelations[I].ToTable;
        LRelation.FromColumn  := LRelations[I].ToColumn;
        LRelation.ToTable     := LRelations[I].FromTable;
        LRelation.ToColumn    := LRelations[I].FromColumn;
        LRelation.Cardinality := LRelations[I].Cardinality;
        LFound := True;
        Break;
      end;
  end;

  if LFound then
    Result := JoinByFK(LRelation);
end;

function TQueryBuilder.Where(const AColumn, AOp: string; const AValue: Variant): IQueryBuilder;
var
  LItem: TWhItem;
begin
  LItem.Kind := whCmp;
  LItem.Column := Trim(AColumn);
  LItem.Op := Trim(AOp);
  if LItem.Op = '' then LItem.Op := '=';
  LItem.Val1 := AValue;
  AddWhere(LItem);
  Result := Self;
end;

function TQueryBuilder.Where(const AColumn: string; const AValue: Variant): IQueryBuilder;
begin
  Result := Where(AColumn, '=', AValue);
end;

{ I18 (Onda 6-e Estagio 2) - condicao de topo combinada com OR; a 1a condicao
  do WHERE nunca leva combinador (RenderWhereItems), portanto OrWhere como
  1o item equivale a Where. }
function TQueryBuilder.OrWhere(const AColumn, AOp: string; const AValue: Variant): IQueryBuilder;
var
  LItem: TWhItem;
begin
  LItem.Kind := whCmp;
  LItem.Logic := wlOr;
  LItem.Column := Trim(AColumn);
  LItem.Op := Trim(AOp);
  if LItem.Op = '' then LItem.Op := '=';
  LItem.Val1 := AValue;
  AddWhere(LItem);
  Result := Self;
end;

function TQueryBuilder.OrWhere(const AColumn: string; const AValue: Variant): IQueryBuilder;
begin
  Result := OrWhere(AColumn, '=', AValue);
end;

function TQueryBuilder.WhereIn(const AColumn: string; const AValues: array of Variant): IQueryBuilder;
var
  LItem: TWhItem;
  I: Integer;
begin
  LItem.Kind := whIn;
  LItem.Column := Trim(AColumn);
  SetLength(LItem.Vals, Length(AValues));
  for I := 0 to High(AValues) do
    LItem.Vals[I] := AValues[I];
  AddWhere(LItem);
  Result := Self;
end;

function TQueryBuilder.WhereNotIn(const AColumn: string; const AValues: array of Variant): IQueryBuilder;
var
  LItem: TWhItem;
  I: Integer;
begin
  LItem.Kind := whNotIn;
  LItem.Column := Trim(AColumn);
  SetLength(LItem.Vals, Length(AValues));
  for I := 0 to High(AValues) do
    LItem.Vals[I] := AValues[I];
  AddWhere(LItem);
  Result := Self;
end;

function TQueryBuilder.WhereBetween(const AColumn: string; const ALow, AHigh: Variant): IQueryBuilder;
var
  LItem: TWhItem;
begin
  LItem.Kind := whBetween;
  LItem.Column := Trim(AColumn);
  LItem.Val1 := ALow;
  LItem.Val2 := AHigh;
  AddWhere(LItem);
  Result := Self;
end;

function TQueryBuilder.WhereInSubQuery(const AColumn: string; const ASubQuery: IQueryBuilder): IQueryBuilder;
var
  LItem: TWhItem;
begin
  LItem.Kind := whInSub;
  LItem.Column := Trim(AColumn);
  LItem.Sub := ASubQuery;
  AddWhere(LItem);
  Result := Self;
end;

function TQueryBuilder.WhereIsNull(const AColumn: string): IQueryBuilder;
var
  LItem: TWhItem;
begin
  LItem.Kind := whNull;
  LItem.Column := Trim(AColumn);
  AddWhere(LItem);
  Result := Self;
end;

function TQueryBuilder.WhereIsNotNull(const AColumn: string): IQueryBuilder;
var
  LItem: TWhItem;
begin
  LItem.Kind := whNotNull;
  LItem.Column := Trim(AColumn);
  AddWhere(LItem);
  Result := Self;
end;

{ Onda 6-e Estagio 3 (I19) - operador SEMANTICO, independente do dialecto;
  delega sempre a Where (mesmo mecanismo bindado - :paramN, nunca literal).
  contains/startsWith/endsWith consultam Dialect.Supports(scILike) (ILIKE no
  PostgreSQL; LIKE nos restantes) e envolvem AValue em wildcards '%' ANTES de
  bindar - o wildcard e parte do VALOR (Bind), nao do SQL. }
function TQueryBuilder.WhereOp(const AColumn, ASemanticOp: string; const AValue: Variant): IQueryBuilder;
var
  LSemantic: string;
  LSqlOp: string;
  LPattern: string;
begin
  LSemantic := LowerCase(Trim(ASemanticOp));
  if LSemantic = 'eq' then
    Exit(Where(AColumn, '=', AValue));
  if LSemantic = 'neq' then
    Exit(Where(AColumn, '<>', AValue));
  if LSemantic = 'gt' then
    Exit(Where(AColumn, '>', AValue));
  if LSemantic = 'ge' then
    Exit(Where(AColumn, '>=', AValue));
  if LSemantic = 'lt' then
    Exit(Where(AColumn, '<', AValue));
  if LSemantic = 'le' then
    Exit(Where(AColumn, '<=', AValue));
  if (LSemantic = 'contains') or (LSemantic = 'startswith') or (LSemantic = 'endswith') then
  begin
    if Dialect.Supports(scILike) then LSqlOp := 'ILIKE' else LSqlOp := 'LIKE';
    if LSemantic = 'contains' then
      LPattern := '%' + VarToStr(AValue) + '%'
    else if LSemantic = 'startswith' then
      LPattern := VarToStr(AValue) + '%'
    else
      LPattern := '%' + VarToStr(AValue);
    Exit(Where(AColumn, LSqlOp, LPattern));
  end;
  raise EDatabaseQueryBuilderException.Create(
    Format(DB_ERR_QB_UNKNOWN_OP_MSG, [ASemanticOp]), ERR_DATABASE_QB_UNKNOWN_OP);
end;

function TQueryBuilder.WhereRaw(const ACondition: string): IQueryBuilder;
var
  LItem: TWhItem;
begin
  LItem.Kind := whRaw;
  LItem.Raw := ACondition;
  AddWhere(LItem);
  Result := Self;
end;

{ I18 (Onda 6-e Estagio 2) - abre um grupo de filtros PARENTIZADO; o grupo so
  e anexado ao WHERE quando IFilterGroup.EndGroup for chamado. }
function TQueryBuilder.WhereGroup: IFilterGroup;
begin
  Result := TFilterGroup.Create(Self);
end;

function TQueryBuilder.GroupBy(const AColumns: string): IQueryBuilder;
begin
  FGroupBy := AColumns;
  Result := Self;
end;

function TQueryBuilder.GroupBy(const AColumns: TStringArray): IQueryBuilder;
var
  LCsv: string;
  I: Integer;
begin
  LCsv := '';
  for I := 0 to High(AColumns) do
  begin
    if I > 0 then LCsv := LCsv + ', ';
    LCsv := LCsv + AColumns[I];
  end;
  Result := GroupBy(LCsv);
end;

function TQueryBuilder.Having(const ACondition: string): IQueryBuilder;
begin
  FHaving := ACondition;
  Result := Self;
end;

{ I18 (Onda 6-e Estagio 2) - WHERE vs HAVING: combina com o HAVING existente
  via OR; sem HAVING previo comporta-se como Having (define isolado, sem
  parenteses supérfluos). Having(...) continua a SOBRESCREVER - inalterado. }
function TQueryBuilder.OrHaving(const ACondition: string): IQueryBuilder;
begin
  if FHaving = '' then
    FHaving := ACondition
  else
    FHaving := '(' + FHaving + ') OR (' + ACondition + ')';
  Result := Self;
end;

function TQueryBuilder.OrderBy(const AColumns: string): IQueryBuilder;
begin
  FOrderBy.Add(QCsv(AColumns));
  Result := Self;
end;

function TQueryBuilder.OrderBy(const AColumns: TStringArray): IQueryBuilder;
var
  LCsv: string;
  I: Integer;
begin
  LCsv := '';
  for I := 0 to High(AColumns) do
  begin
    if I > 0 then LCsv := LCsv + ', ';
    LCsv := LCsv + AColumns[I];
  end;
  Result := OrderBy(LCsv);
end;

function TQueryBuilder.OrderByDesc(const AColumns: string): IQueryBuilder;
begin
  FOrderBy.Add(QCsv(AColumns, ' DESC'));
  Result := Self;
end;

function TQueryBuilder.Limit(const AValue: Integer): IQueryBuilder;
begin
  FLimit := AValue;
  Result := Self;
end;

function TQueryBuilder.Offset(const AValue: Integer): IQueryBuilder;
begin
  FOffset := AValue;
  Result := Self;
end;

function TQueryBuilder.UnionWith(const AOther: IQueryBuilder; const AAll: Boolean): IQueryBuilder;
var
  N: Integer;
begin
  N := Length(FUnions);
  SetLength(FUnions, N + 1);
  FUnions[N].QB := AOther;
  FUnions[N].All := AAll;
  Result := Self;
end;

function TQueryBuilder.WithCTE(const AName: string; const AQuery: IQueryBuilder): IQueryBuilder;
var
  N: Integer;
begin
  N := Length(FCTEs);
  SetLength(FCTEs, N + 1);
  FCTEs[N].Name := Trim(AName);
  FCTEs[N].QB := AQuery;
  Result := Self;
end;

{ Onda 6-c (I5) - Smart Distinct: configura a query atual como 'SELECT
  DISTINCT <AColumn> FROM <tabela atual> ORDER BY <AColumn>' (reutiliza
  Select/Distinct/OrderBy; opera sobre o From ja definido pelo caller). }
function TQueryBuilder.DistinctValuesQuery(const AColumn: string): IQueryBuilder;
begin
  Select(AColumn);
  Distinct(True);
  Result := OrderBy(AColumn);
end;

function TQueryBuilder.InsertInto(const ATable, ASchema: string): IQueryBuilder;
begin
  FKind := qbInsert;
  FTable := Trim(ATable);
  FSchema := Trim(ASchema);
  Result := Self;
end;

function TQueryBuilder.Value(const AColumn: string; const AValue: Variant): IQueryBuilder;
var
  N: Integer;
begin
  N := Length(FColVals);
  SetLength(FColVals, N + 1);
  FColVals[N].Column := Trim(AColumn);
  FColVals[N].Value := AValue;
  Result := Self;
end;

function TQueryBuilder.Update(const ATable, ASchema: string): IQueryBuilder;
begin
  FKind := qbUpdate;
  FTable := Trim(ATable);
  FSchema := Trim(ASchema);
  Result := Self;
end;

function TQueryBuilder.SetValue(const AColumn: string; const AValue: Variant): IQueryBuilder;
begin
  Result := Value(AColumn, AValue); // mesmo armazenamento (FColVals)
end;

function TQueryBuilder.SetValueDelta(const AColumn: string; const ADelta: Integer): IQueryBuilder;
var
  N: Integer;
begin
  { auto-incremento: SET col = col + ADelta. O SQL (quoting do dialeto em AMBOS os
    lados) e' emitido em BuildUpdateSQL - o chamador NAO escreve SQL. }
  N := Length(FColVals);
  SetLength(FColVals, N + 1);
  FColVals[N].Column := Trim(AColumn);
  FColVals[N].IsDelta := True;
  FColVals[N].Delta := ADelta;
  Result := Self;
end;

function TQueryBuilder.DeleteFrom(const ATable, ASchema: string): IQueryBuilder;
begin
  FKind := qbDelete;
  FTable := Trim(ATable);
  FSchema := Trim(ASchema);
  Result := Self;
end;

{ I10 (Onda 6-f Estagio 1) - guarda DADOS BRUTOS (nome + argumentos); o
  render (BuildCallSQL) e a UNICA passagem que pede a sintaxe ao dialecto e
  binda os argumentos - mesmo padrao dos restantes setters desta classe. }
function TQueryBuilder.CallProcedure(const AName: string; const AArgs: array of Variant): IQueryBuilder;
var
  I: Integer;
begin
  FKind := qbCall;
  FCallProc := Trim(AName);
  SetLength(FCallArgs, Length(AArgs));
  for I := 0 to High(AArgs) do
    FCallArgs[I] := AArgs[I];
  Result := Self;
end;

function TQueryBuilder.Pretty(const AValue: Boolean): IQueryBuilder;
begin
  FPretty := AValue;
  Result := Self;
end;

{ I15 (Onda 6-e Estagio 1) - SQL SEMPRE formatado, independente do estado
  actual de FPretty (nao o altera); reutiliza o BuildSQL(NL) existente. }
function TQueryBuilder.ToSQLFormatted: string;
var
  LWasPretty: Boolean;
begin
  LWasPretty := FPretty;
  FPretty := True;
  try
    Result := BuildSQL;
  finally
    FPretty := LWasPretty;
  end;
end;

{ ---- render ---- }

function TQueryBuilder.RenderTableRef(const ATable, ASchema: string): string;
begin
  if (ASchema <> '') and Dialect.Supports(scSchemas) then
    Result := Q(ASchema) + '.' + Q(ATable)
  else
    Result := Q(ATable);
end;

function TQueryBuilder.RenderSelectColumns: string;
var
  I: Integer;
  LExpr: string;
begin
  if Length(FSel) = 0 then
    Exit('*');
  Result := '';
  for I := 0 to High(FSel) do
  begin
    if Result <> '' then Result := Result + ', ';
    case FSel[I].Kind of
      skColumn:
        if (FSel[I].Expr = '') or (FSel[I].Expr = '*') then
          Result := Result + '*'
        else
          Result := Result + Q(FSel[I].Expr);
      skRaw:
        begin
          Result := Result + FSel[I].Expr;
          if FSel[I].Alias <> '' then          // SelectComputed: expr AS ident(alias)
            Result := Result + ' AS ' + Q(FSel[I].Alias);
        end;
      skAgg:
        begin
          if (FSel[I].Expr = '') or (FSel[I].Expr = '*') then
            LExpr := FSel[I].Func + '(*)'
          else
            LExpr := FSel[I].Func + '(' + Q(FSel[I].Expr) + ')';
          if FSel[I].Alias <> '' then
            LExpr := LExpr + ' AS ' + Q(FSel[I].Alias);
          Result := Result + LExpr;
        end;
    end;
  end;
end;

{ I18 (Onda 6-e Estagio 2) - render RECURSIVO (whGroup chama-se a si proprio
  para os Items aninhados); cada item combina-se com os anteriores DO MESMO
  NIVEL via o seu proprio .Logic (AND/OR - ignorado no 1o item nao-vazio do
  nivel, tal como o comportamento AND-puro pre-existente). }
function TQueryBuilder.RenderWhereItems(const AItems: array of TWhItem): string;
var
  I, J: Integer;
  LCond, LList, LInner, LSep: string;
begin
  Result := '';
  for I := 0 to High(AItems) do
  begin
    case AItems[I].Kind of
      whCmp:
        LCond := Q(AItems[I].Column) + ' ' + AItems[I].Op + ' ' + Bind(AItems[I].Val1);
      whBetween:
        LCond := Q(AItems[I].Column) + ' BETWEEN ' + Bind(AItems[I].Val1) +
                 ' AND ' + Bind(AItems[I].Val2);
      whIn, whNotIn:
        begin
          if Length(AItems[I].Vals) = 0 then
          begin
            if AItems[I].Kind = whIn then LCond := '1 = 0' else LCond := '1 = 1';
          end
          else
          begin
            LList := '';
            for J := 0 to High(AItems[I].Vals) do
            begin
              if LList <> '' then LList := LList + ', ';
              LList := LList + Bind(AItems[I].Vals[J]);
            end;
            if AItems[I].Kind = whIn then
              LCond := Q(AItems[I].Column) + ' IN (' + LList + ')'
            else
              LCond := Q(AItems[I].Column) + ' NOT IN (' + LList + ')';
          end;
        end;
      whInSub:
        LCond := Q(AItems[I].Column) + ' IN (' + AbsorbSub(AItems[I].Sub) + ')';
      whNull:
        LCond := Q(AItems[I].Column) + ' IS NULL';
      whNotNull:
        LCond := Q(AItems[I].Column) + ' IS NOT NULL';
      whRaw:
        LCond := AItems[I].Raw;
      whGroup:
        begin
          LInner := RenderWhereItems(AItems[I].Items);
          if LInner = '' then
            LCond := ''           // grupo vazio - no-op, nao aparece no SQL
          else
          begin
            LCond := '(' + LInner + ')';
            if AItems[I].Negate then
              LCond := 'NOT ' + LCond;
          end;
        end;
    else
      LCond := '';
    end;
    if LCond = '' then Continue;
    if Result <> '' then
    begin
      if AItems[I].Logic = wlOr then LSep := ' OR ' else LSep := ' AND ';
      Result := Result + LSep;
    end;
    Result := Result + LCond;
  end;
end;

function TQueryBuilder.RenderWhere: string;
begin
  Result := RenderWhereItems(FWhere);
end;

function TQueryBuilder.BuildSelectSQL(const NL: string): string;
var
  LCte, LBody, LUnion, LSel, LFrom: string;
  I: Integer;
begin
  NeedTable('SELECT');

  { CTEs (params ABSORVIDOS primeiro - aparecem no inicio do SQL) }
  LCte := '';
  for I := 0 to High(FCTEs) do
  begin
    if LCte <> '' then LCte := LCte + ', ';
    LCte := LCte + Q(FCTEs[I].Name) + ' AS (' + AbsorbSub(FCTEs[I].QB) + ')';
  end;
  if LCte <> '' then LCte := 'WITH ' + LCte + NL;

  { SELECT }
  LSel := 'SELECT ';
  if FDistinct then LSel := LSel + 'DISTINCT ';
  LSel := LSel + RenderSelectColumns;

  { FROM (tabela, derived table ou fonte virtual = subquery SQL crua) }
  if FFromRawSub <> '' then
    LFrom := 'FROM (' + FFromRawSub + ') ' + Q(FFromRawSubAlias)
  else if FFromSub <> nil then
    LFrom := 'FROM (' + AbsorbSub(FFromSub) + ') ' + Q(FFromSubAlias)
  else
    LFrom := 'FROM ' + RenderTableRef(FTable, FSchema);

  LBody := LSel + NL + LFrom;

  for I := 0 to FJoins.Count - 1 do
    LBody := LBody + NL + FJoins[I];

  if Length(FWhere) > 0 then
    LBody := LBody + NL + 'WHERE ' + RenderWhere;

  if FGroupBy <> '' then
    LBody := LBody + NL + 'GROUP BY ' + QCsv(FGroupBy);

  if FHaving <> '' then
    LBody := LBody + NL + 'HAVING ' + FHaving;

  if FOrderBy.Count > 0 then
    LBody := LBody + NL + 'ORDER BY ' + JoinList(FOrderBy, ', ');

  { UNIONs (params absorvidos por ultimo) }
  LUnion := '';
  for I := 0 to High(FUnions) do
  begin
    if FUnions[I].All then
      LUnion := LUnion + NL + 'UNION ALL' + NL + AbsorbSub(FUnions[I].QB)
    else
      LUnion := LUnion + NL + 'UNION' + NL + AbsorbSub(FUnions[I].QB);
  end;

  Result := LCte + LBody + LUnion;

  { paginacao pelo dialecto (capability-gated) }
  if (FLimit > 0) or (FOffset > 0) then
    Result := Dialect.ApplyPagination(Result, FLimit, FOffset);
end;

function TQueryBuilder.BuildInsertSQL: string;
var
  I: Integer;
  LCols, LVals: string;
begin
  NeedTable('INSERT');
  NeedColumns('INSERT');
  LCols := '';
  LVals := '';
  for I := 0 to High(FColVals) do
  begin
    if LCols <> '' then LCols := LCols + ', ';
    if LVals <> '' then LVals := LVals + ', ';
    LCols := LCols + Q(FColVals[I].Column);
    LVals := LVals + Bind(FColVals[I].Value);
  end;
  Result := 'INSERT INTO ' + RenderTableRef(FTable, FSchema) +
            ' (' + LCols + ') VALUES (' + LVals + ')';
end;

function TQueryBuilder.BuildUpdateSQL(const NL: string): string;
var
  I: Integer;
  LSet: string;
begin
  NeedTable('UPDATE');
  NeedColumns('UPDATE');
  LSet := '';
  for I := 0 to High(FColVals) do  // SET binda ANTES do WHERE (ordem textual)
  begin
    if LSet <> '' then LSet := LSet + ', ';
    if FColVals[I].IsDelta then          // SET col = col +/- N (auto-incremento; ambos os lados quotados)
    begin
      if FColVals[I].Delta >= 0 then
        LSet := LSet + Q(FColVals[I].Column) + ' = ' + Q(FColVals[I].Column) + ' + ' + IntToStr(FColVals[I].Delta)
      else
        LSet := LSet + Q(FColVals[I].Column) + ' = ' + Q(FColVals[I].Column) + ' - ' + IntToStr(-FColVals[I].Delta);
    end
    else
      LSet := LSet + Q(FColVals[I].Column) + ' = ' + Bind(FColVals[I].Value);
  end;
  Result := 'UPDATE ' + RenderTableRef(FTable, FSchema) + NL + 'SET ' + LSet;
  if Length(FWhere) > 0 then
    Result := Result + NL + 'WHERE ' + RenderWhere;
end;

function TQueryBuilder.BuildDeleteSQL(const NL: string): string;
begin
  NeedTable('DELETE');
  Result := 'DELETE FROM ' + RenderTableRef(FTable, FSchema);
  if Length(FWhere) > 0 then
    Result := Result + NL + 'WHERE ' + RenderWhere;
end;

{ I10 (Onda 6-f Estagio 1) - pede a Dialect.CallProcedureSQL o TEMPLATE com
  placeholders posicionais ':p0'..':p<N-1>' e substitui cada um pelo
  placeholder REAL do proprio Bind (:paramN - mesmo mecanismo das mutations,
  nunca literal), em ordem DESCENDENTE de indice (evita ':p1' casar dentro de
  ':p10' quando N>=11 - ao processar do maior indice para o menor, ':p10' ja
  foi substituido antes de se procurar ':p1'). Dialecto sem suporte (SQLite/
  Access - CallProcedureSQL='') -> devolve '' (BuildSQL/ToSQL ficam '';
  Execute/ExecuteMutation tratam como no-op, ver guardas dedicadas). }
function TQueryBuilder.BuildCallSQL: string;
var
  LTemplate: string;
  LTokens: array of string;
  I: Integer;
begin
  LTemplate := Dialect.CallProcedureSQL(FCallProc, Length(FCallArgs));
  if Trim(LTemplate) = '' then
    Exit(''); // dialecto sem suporte (SQLite/Access) - no-op gracioso
  SetLength(LTokens, Length(FCallArgs));
  for I := 0 to High(FCallArgs) do
    LTokens[I] := Bind(FCallArgs[I]);
  Result := LTemplate;
  for I := High(FCallArgs) downto 0 do
    Result := StringReplace(Result, ':p' + IntToStr(I), LTokens[I], [rfReplaceAll]);
end;

function TQueryBuilder.BuildSQL: string;
var
  LNL: string;
begin
  FBound.Clear;
  if FPretty then LNL := sLineBreak else LNL := ' ';
  case FKind of
    qbInsert: Result := BuildInsertSQL;
    qbUpdate: Result := BuildUpdateSQL(LNL);
    qbDelete: Result := BuildDeleteSQL(LNL);
    qbCall:   Result := BuildCallSQL;
  else
    Result := BuildSelectSQL(LNL);
  end;
end;

function TQueryBuilder.ToSQL: string;
begin
  Result := BuildSQL;
end;

function TQueryBuilder.Params: TArray<Variant>;
begin
  BuildSQL; // popula FBound na ordem
  Result := FBound.ToArray;
end;

function TQueryBuilder.Execute: TDataSet;
var
  LSql: string;
  LParams: TArray<Variant>;
  LT0: UInt64;
begin
  if FConnection = nil then
    raise EDatabaseQueryBuilderException.Create(
      Format(DB_ERR_QB_NO_CONN_MSG, ['Execute']), ERR_DATABASE_NO_CONNECTION);
  LSql := BuildSQL;
  if (FKind = qbCall) and (Trim(LSql) = '') then
  begin
    { I10 (Onda 6-f) - CallProcedureSQL nao suportado pelo dialecto (SQLite/
      Access) - no-op gracioso, SEM chamar a IConnection com SQL vazio. }
    Result := nil;
    FStatistics.RowsAffected := -1;
    FStatistics.ElapsedMs := 0;
    FStatistics.LastSQL := '';
    Exit;
  end;
  LParams := FBound.ToArray;
  LT0 := GetTickCount64;
  if Length(LParams) = 0 then
    Result := FConnection.ExecuteQuery(LSql)
  else
    Result := FConnection.ExecuteQuery(LSql, LParams);
  { I3 (Onda 6-e) - RowsAffected nao aplicavel a um dataset vivo (SELECT) }
  FStatistics.RowsAffected := -1;
  FStatistics.ElapsedMs := Int64(GetTickCount64 - LT0);
  FStatistics.LastSQL := LSql;
end;

function TQueryBuilder.ExecuteMutation: Integer;
var
  LSql: string;
  LParams: TArray<Variant>;
  LT0: UInt64;
begin
  if FConnection = nil then
    raise EDatabaseQueryBuilderException.Create(
      Format(DB_ERR_QB_NO_CONN_MSG, ['ExecuteMutation']), ERR_DATABASE_NO_CONNECTION);
  LSql := BuildSQL;
  if (FKind = qbCall) and (Trim(LSql) = '') then
  begin
    { I10 (Onda 6-f) - CallProcedureSQL nao suportado pelo dialecto (SQLite/
      Access) - no-op gracioso, SEM chamar a IConnection com SQL vazio. }
    Result := 0;
    FStatistics.RowsAffected := 0;
    FStatistics.ElapsedMs := 0;
    FStatistics.LastSQL := '';
    Exit;
  end;
  LParams := FBound.ToArray;
  LT0 := GetTickCount64;
  if Length(LParams) = 0 then
    Result := FConnection.ExecuteCommand(LSql)
  else
    Result := FConnection.ExecuteCommand(LSql, LParams);
  { I3 (Onda 6-e) - estatisticas do ultimo Execute/ExecuteMutation }
  FStatistics.RowsAffected := Result;
  FStatistics.ElapsedMs := Int64(GetTickCount64 - LT0);
  FStatistics.LastSQL := LSql;
end;

{ I11/A2 (Onda 6-f Estagio 2) - corre Execute (o SELECT actual) NUMA THREAD de
  fundo (TORMTask<TDataSet>, Database.QueryBuilder.Sychronize) e devolve IMEDIATAMENTE.
  NOTA (bug-1088, 01/08/2026): TORMTask<T>.Run ja NAO usa closure ("reference to
  function" - FPC 3.2.2 nao suporta) - passa-se Self.Execute (metodo "of object",
  mesma assinatura function: TDataSet) + LSelf (IQueryBuilder) como AKeepAlive
  explicito, retido pelo Worker durante a thread (ver Database.QueryBuilder.
  Sychronize). LSelf continua a manter o proprio TQueryBuilder VIVO (contagem de
  referencias da interface) enquanto a tarefa corre em segundo plano - mesmo que
  o caller nao guarde outra referencia; a protecao e agora EXPLICITA (parametro),
  nao implicita (captura por closure). NOTA DE THREAD-SAFETY: a IConnection
  injectada (FConnection/Dialect) e usada PELA THREAD DE FUNDO enquanto a tarefa
  corre - o caller NAO deve usar a MESMA IConnection concorrentemente antes de
  Await(); o TDataSet devolvido por Await e o mesmo dataset DESCONECTADO ja
  devolvido por Execute (F4, seguro de atravessar threads).
  GOTCHAS (M8/M9, conformidade F5 C2): (1) DESCARTAR o IORMTask devolvido (nao
  capturar a interface) faz o refcount cair a zero -> Destroy chama WaitFor ->
  degenera em execucao SINCRONA BLOQUEANTE; capturar sempre num LTask ate Await.
  (2) alem da IConnection, NAO reutilizar a MESMA IQueryBuilder (ToSQL/Params/
  Where/Statistics/novo Execute) ate Await retornar - corrida sobre FBound/
  FDialect/FStatistics. }
function TQueryBuilder.ExecuteAsync: IORMTask<TDataSet>;
var
  LSelf: IQueryBuilder;
begin
  LSelf := Self;
  Result := TORMTask<TDataSet>.Run(Self.Execute, LSelf);
end;

{ I3 (Onda 6-e Estagio 1) - estatisticas do ULTIMO Execute/ExecuteMutation;
  sem execucao ainda -> record zerado (RowsAffected=0, ElapsedMs=0, LastSQL=''). }
function TQueryBuilder.Statistics: TQueryStatistics;
begin
  Result := FStatistics;
end;

{ I17 (Onda 6-e Estagio 4) - serializa o estado ESSENCIAL da query (ver
  comentario completo em Databases.Interfaces.IQueryBuilder.SavePreset):
  kind/table/schema; select (SO FSel[I].Kind=skColumn - SelectRaw/
  SelectComputed/agregados ficam de fora, silenciosamente); where (SO
  FWhere[I].Kind=whCmp - inclui Logic AND/OR de topo; whIn/whBetween/
  whNull/whNotNull/whRaw/whInSub/whGroup ficam de fora); orderby (FOrderBy
  JA CONTEM as strings RENDERIZADAS/quotadas pelo dialecto usado em cada
  chamada OrderBy/OrderByDesc - gravadas tal-e-qual, sem re-render); limit/
  offset. Construido via TJSONObject/TJSONArray (nao concatenacao manual -
  os valores WHERE sao Variant de tipo variavel, o construtor tipado evita
  reimplementar o dispatch de tipo aqui). }
function TQueryBuilder.SavePreset: string;
var
  LRoot, LWhereItem: TJSONObject;
  LSelArr, LWhereArr, LOrderArr: TJSONArray;
  I: Integer;
  LKind, LLogic: string;
  LFirstWhere: Boolean;
begin
  case FKind of
    qbInsert: LKind := 'insert';
    qbUpdate: LKind := 'update';
    qbDelete: LKind := 'delete';
  else
    LKind := 'select';
  end;

  {$IFDEF FPC}
  { fpjson.AsJSON usa formato "espacado" por defeito (chaves/colchetes com
    espacos ao redor); True produz o mesmo formato COMPACTO do
    TJSONObject.ToJSON do Delphi (determinismo do preset entre
    compiladores). Class var estatica (TJSONData) - sem impacto noutras
    units, nenhuma usa AsJSON. }
  TJSONData.CompressedJSON := True;
  {$ENDIF}
  LRoot := TJSONObject.Create;
  try
    {$IFDEF FPC}
    LRoot.Add('kind', LKind);
    LRoot.Add('table', FTable);
    LRoot.Add('schema', FSchema);
    {$ELSE}
    LRoot.AddPair('kind', LKind);
    LRoot.AddPair('table', FTable);
    LRoot.AddPair('schema', FSchema);
    {$ENDIF}

    LSelArr := TJSONArray.Create;
    for I := 0 to High(FSel) do
      if FSel[I].Kind = skColumn then
        LSelArr.Add(FSel[I].Expr);
    {$IFDEF FPC}
    LRoot.Add('select', LSelArr);
    {$ELSE}
    LRoot.AddPair('select', LSelArr);
    {$ENDIF}

    LWhereArr := TJSONArray.Create;
    LFirstWhere := True;
    for I := 0 to High(FWhere) do
      if FWhere[I].Kind = whCmp then
      begin
        { o Logic do 1o item EXPORTADO nunca e lido no render (RenderWhereItems
          so usa Logic a partir do 2o item de cada nivel) - normaliza para
          'and' em vez de serializar o valor cru (Where/WhereIn/etc. NAO
          inicializam Logic explicitamente quando o combinador e o AND
          implicito - o campo so importa a partir do 2o item, mas fica com
          lixo de pilha ate la; sem esta normalizacao o preset gravaria esse
          lixo no 1o item, inofensivo para o SQL mas confuso para quem le o
          JSON). }
        if LFirstWhere then
          LLogic := 'and'
        else if FWhere[I].Logic = wlOr then
          LLogic := 'or'
        else
          LLogic := 'and';
        LFirstWhere := False;
        LWhereItem := TJSONObject.Create;
        {$IFDEF FPC}
        LWhereItem.Add('column', FWhere[I].Column);
        LWhereItem.Add('op', FWhere[I].Op);
        LWhereItem.Add('value', GetJSON(QBVariantToJSONLiteral(FWhere[I].Val1)));
        LWhereItem.Add('logic', LLogic);
        {$ELSE}
        LWhereItem.AddPair('column', FWhere[I].Column);
        LWhereItem.AddPair('op', FWhere[I].Op);
        LWhereItem.AddPair('value', TJSONObject.ParseJSONValue(QBVariantToJSONLiteral(FWhere[I].Val1)));
        LWhereItem.AddPair('logic', LLogic);
        {$ENDIF}
        LWhereArr.Add(LWhereItem);
      end;
    {$IFDEF FPC}
    LRoot.Add('where', LWhereArr);
    {$ELSE}
    LRoot.AddPair('where', LWhereArr);
    {$ENDIF}

    LOrderArr := TJSONArray.Create;
    for I := 0 to FOrderBy.Count - 1 do
      LOrderArr.Add(FOrderBy[I]);
    {$IFDEF FPC}
    LRoot.Add('orderby', LOrderArr);
    LRoot.Add('limit', FLimit);
    LRoot.Add('offset', FOffset);
    {$ELSE}
    LRoot.AddPair('orderby', LOrderArr);
    LRoot.AddPair('limit', TJSONNumber.Create(FLimit));
    LRoot.AddPair('offset', TJSONNumber.Create(FOffset));
    {$ENDIF}

    {$IFDEF FPC}
    Result := LRoot.AsJSON;
    {$ELSE}
    Result := LRoot.ToJSON;
    {$ENDIF}
  finally
    LRoot.Free;
  end;
end;

{ I17 (Onda 6-e Estagio 4) - reconstroi o estado ESSENCIAL a partir do JSON de
  SavePreset; SUBSTITUI (nao faz merge) kind/table/schema/select/where/
  orderby/limit/offset - o resto do estado do builder (Connection/Joins/
  GroupBy/Having/Unions/CTEs/ColVals/Distinct) fica INTOCADO. JSON invalido/
  vazio -> no-op (Self inalterado), mesmo padrao defensivo de
  IField.StructureFromJSON. }
function TQueryBuilder.LoadPreset(const AJSON: string): IQueryBuilder;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
  LSelArr, LWhereArr, LOrderArr: TJSONArray;
  LWhereItem: TJSONObject;
  LKind: string;
  I: Integer;
  LSelItem: TSelItem;
  LWhItem: TWhItem;
begin
  Result := Self;
  if Trim(AJSON) = '' then
    Exit;
  { GetJSON (fpjson/jsonparser) LANCA EJSONParser em JSON malformado (ao
    contrario de TJSONObject.ParseJSONValue no Delphi, que devolve nil) -
    apanhar aqui mantem o mesmo contrato defensivo "invalido -> no-op" nos 2
    compiladores. }
  try
    LData := GetJSON(AJSON);
  except
    Exit;
  end;
  if (not Assigned(LData)) or (not (LData is TJSONObject)) then
  begin
    if Assigned(LData) then LData.Free;
    Exit;
  end;
  LObj := TJSONObject(LData);
  try
    LKind := LObj.Get('kind', 'select');
    if LKind = 'insert' then FKind := qbInsert
    else if LKind = 'update' then FKind := qbUpdate
    else if LKind = 'delete' then FKind := qbDelete
    else FKind := qbSelect;
    FTable := LObj.Get('table', '');
    FSchema := LObj.Get('schema', '');

    SetLength(FSel, 0);
    if LObj.Find('select', jtArray) <> nil then
    begin
      LSelArr := TJSONArray(LObj.Find('select'));
      for I := 0 to LSelArr.Count - 1 do
      begin
        LSelItem.Kind := skColumn;
        LSelItem.Expr := LSelArr.Strings[I];
        LSelItem.Func := '';
        LSelItem.Alias := '';
        SetLength(FSel, Length(FSel) + 1);
        FSel[High(FSel)] := LSelItem;
      end;
    end;

    SetLength(FWhere, 0);
    if LObj.Find('where', jtArray) <> nil then
    begin
      LWhereArr := TJSONArray(LObj.Find('where'));
      for I := 0 to LWhereArr.Count - 1 do
      begin
        LWhereItem := TJSONObject(LWhereArr.Items[I]);
        LWhItem.Kind := whCmp;
        if LWhereItem.Get('logic', 'and') = 'or' then LWhItem.Logic := wlOr else LWhItem.Logic := wlAnd;
        LWhItem.Column := LWhereItem.Get('column', '');
        LWhItem.Op := LWhereItem.Get('op', '=');
        LWhItem.Val1 := QBJSONNodeToVariant(LWhereItem.Find('value'));
        AddWhere(LWhItem);
      end;
    end;

    FOrderBy.Clear;
    if LObj.Find('orderby', jtArray) <> nil then
    begin
      LOrderArr := TJSONArray(LObj.Find('orderby'));
      for I := 0 to LOrderArr.Count - 1 do
        FOrderBy.Add(LOrderArr.Strings[I]);
    end;

    FLimit := LObj.Get('limit', -1);
    FOffset := LObj.Get('offset', 0);
  finally
    LObj.Free;
  end;
end;
{$ELSE}
var
  LVal: TJSONValue;
  LObj: TJSONObject;
  LSelArr, LWhereArr, LOrderArr: TJSONArray;
  LWhereItem: TJSONObject;
  LKind: string;
  I: Integer;
  LSelItem: TSelItem;
  LWhItem: TWhItem;
begin
  Result := Self;
  if Trim(AJSON) = '' then
    Exit;
  LVal := TJSONObject.ParseJSONValue(AJSON);
  if (not Assigned(LVal)) or (not (LVal is TJSONObject)) then
  begin
    if Assigned(LVal) then LVal.Free;
    Exit;
  end;
  LObj := TJSONObject(LVal);
  try
    LKind := LObj.GetValue<string>('kind', 'select');
    if LKind = 'insert' then FKind := qbInsert
    else if LKind = 'update' then FKind := qbUpdate
    else if LKind = 'delete' then FKind := qbDelete
    else FKind := qbSelect;
    FTable := LObj.GetValue<string>('table', '');
    FSchema := LObj.GetValue<string>('schema', '');

    SetLength(FSel, 0);
    if LObj.TryGetValue<TJSONArray>('select', LSelArr) then
      for I := 0 to LSelArr.Count - 1 do
      begin
        LSelItem.Kind := skColumn;
        LSelItem.Expr := LSelArr.Items[I].Value;
        LSelItem.Func := '';
        LSelItem.Alias := '';
        SetLength(FSel, Length(FSel) + 1);
        FSel[High(FSel)] := LSelItem;
      end;

    SetLength(FWhere, 0);
    if LObj.TryGetValue<TJSONArray>('where', LWhereArr) then
      for I := 0 to LWhereArr.Count - 1 do
      begin
        LWhereItem := TJSONObject(LWhereArr.Items[I]);
        LWhItem.Kind := whCmp;
        if LWhereItem.GetValue<string>('logic', 'and') = 'or' then LWhItem.Logic := wlOr else LWhItem.Logic := wlAnd;
        LWhItem.Column := LWhereItem.GetValue<string>('column', '');
        LWhItem.Op := LWhereItem.GetValue<string>('op', '=');
        LWhItem.Val1 := QBJSONNodeToVariant(LWhereItem.GetValue('value'));
        AddWhere(LWhItem);
      end;

    FOrderBy.Clear;
    if LObj.TryGetValue<TJSONArray>('orderby', LOrderArr) then
      for I := 0 to LOrderArr.Count - 1 do
        FOrderBy.Add(LOrderArr.Items[I].Value);

    FLimit := LObj.GetValue<Integer>('limit', -1);
    FOffset := LObj.GetValue<Integer>('offset', 0);
  finally
    LObj.Free;
  end;
end;
{$ENDIF}

{ TFilterGroup - I18 (Onda 6-e Estagio 2) }

constructor TFilterGroup.Create(const AOwner: TQueryBuilder);
begin
  inherited Create;
  FOwner := AOwner;
end;

procedure TFilterGroup.AddItem(const AItem: TWhItem);
var
  N: Integer;
begin
  N := Length(FItems);
  SetLength(FItems, N + 1);
  FItems[N] := AItem;
end;

function TFilterGroup.AndWhere(const AColumn, AOp: string; const AValue: Variant): IFilterGroup;
var
  LItem: TWhItem;
begin
  LItem.Kind := whCmp;
  LItem.Logic := wlAnd;
  LItem.Column := Trim(AColumn);
  LItem.Op := Trim(AOp);
  if LItem.Op = '' then LItem.Op := '=';
  LItem.Val1 := AValue;
  AddItem(LItem);
  Result := Self;
end;

function TFilterGroup.AndWhere(const AColumn: string; const AValue: Variant): IFilterGroup;
begin
  Result := AndWhere(AColumn, '=', AValue);
end;

function TFilterGroup.OrWhere(const AColumn, AOp: string; const AValue: Variant): IFilterGroup;
var
  LItem: TWhItem;
begin
  LItem.Kind := whCmp;
  LItem.Logic := wlOr;
  LItem.Column := Trim(AColumn);
  LItem.Op := Trim(AOp);
  if LItem.Op = '' then LItem.Op := '=';
  LItem.Val1 := AValue;
  AddItem(LItem);
  Result := Self;
end;

function TFilterGroup.OrWhere(const AColumn: string; const AValue: Variant): IFilterGroup;
begin
  Result := OrWhere(AColumn, '=', AValue);
end;

function TFilterGroup.NotGroup: IFilterGroup;
begin
  FNegate := True;
  Result := Self;
end;

{ fecha o grupo: monta 1 TWhItem (Kind=whGroup) com os itens acumulados e
  anexa-o ao WHERE top-level do OWNER via o mesmo AddWhere privado usado por
  Where/OrWhere/etc. - o grupo combina-se por AND com os itens irmaos de
  topo (LGroupItem.Logic = wlAnd, tal como um Where(...) normal). }
function TFilterGroup.EndGroup: IQueryBuilder;
var
  LGroupItem: TWhItem;
  I: Integer;
begin
  LGroupItem.Kind := whGroup;
  LGroupItem.Logic := wlAnd;
  LGroupItem.Negate := FNegate;
  { FItems (TFilterGroup) e LGroupItem.Items (TWhItem) sao 2 tipos "array of
    TWhItem" declarados em SITIOS diferentes (campo de classe vs campo de
    record self-referente) - Object Pascal NAO os trata como o MESMO tipo
    dinamico para atribuicao directa (E2008), mesmo com elemento identico;
    copia elemento-a-elemento (TWhItem := TWhItem, mesmo tipo nomeado, sem
    ambiguidade). }
  SetLength(LGroupItem.Items, Length(FItems));
  for I := 0 to High(FItems) do
    LGroupItem.Items[I] := FItems[I];
  FOwner.AddWhere(LGroupItem);
  Result := FOwner;
end;

{ TCaseBuilder }

class function TCaseBuilder.New: ICaseBuilder;
begin
  Result := TCaseBuilder.Create;
end;

function TCaseBuilder.WhenThen(const ACondition, AResult: string): ICaseBuilder;
begin
  FExpr := FExpr + ' WHEN ' + ACondition + ' THEN ' + AResult;
  Result := Self;
end;

function TCaseBuilder.ElseResult(const AResult: string): ICaseBuilder;
begin
  FElse := ' ELSE ' + AResult;
  Result := Self;
end;

function TCaseBuilder.EndAs(const AAlias: string): string;
begin
  Result := 'CASE' + FExpr + FElse + ' END';
  if AAlias <> '' then
    Result := Result + ' AS ' + AAlias;
end;

{ ===== QueryTransformer (B3) - absorvido do ex-Database.QueryTransformer (Reorg 3) ===== }

{ TQueryTransformer }

constructor TQueryTransformer.Create;
begin
  inherited Create;
  FLimit := -1;
  FOffset := 0;
end;

class function TQueryTransformer.New: IQueryTransformer;
begin
  Result := TQueryTransformer.Create;
end;

procedure TQueryTransformer.AddFilter(const AKind: TQTFKind; const ACol: string;
  const AV1: Variant);
var
  N: Integer;
begin
  N := Length(FFilters);
  SetLength(FFilters, N + 1);
  FFilters[N].Kind := AKind;
  FFilters[N].Col := Trim(ACol);
  FFilters[N].V1 := AV1;
end;

procedure TQueryTransformer.AddLike(const ACol, APattern, AText: string;
  const AMode: TQTLikeMode);
var
  N: Integer;
begin
  N := Length(FFilters);
  SetLength(FFilters, N + 1);
  FFilters[N].Kind := qfLike;
  FFilters[N].Col := Trim(ACol);
  FFilters[N].V1 := APattern;
  FFilters[N].Text := AText;
  FFilters[N].LMode := AMode;
end;

function TQueryTransformer.Source(const AQuery: IQueryBuilder): IQueryTransformer;
begin
  FSource := AQuery;
  Result := Self;
end;

{ ---- filtros ---- }

function TQueryTransformer.Equal(const AColumn: string; const AValue: Variant): IQueryTransformer;
begin AddFilter(qfEq, AColumn, AValue); Result := Self; end;

function TQueryTransformer.NotEqual(const AColumn: string; const AValue: Variant): IQueryTransformer;
begin AddFilter(qfNeq, AColumn, AValue); Result := Self; end;

function TQueryTransformer.GreaterThan(const AColumn: string; const AValue: Variant): IQueryTransformer;
begin AddFilter(qfGt, AColumn, AValue); Result := Self; end;

function TQueryTransformer.GreaterOrEqual(const AColumn: string; const AValue: Variant): IQueryTransformer;
begin AddFilter(qfGe, AColumn, AValue); Result := Self; end;

function TQueryTransformer.LessThan(const AColumn: string; const AValue: Variant): IQueryTransformer;
begin AddFilter(qfLt, AColumn, AValue); Result := Self; end;

function TQueryTransformer.LessOrEqual(const AColumn: string; const AValue: Variant): IQueryTransformer;
begin AddFilter(qfLe, AColumn, AValue); Result := Self; end;

function TQueryTransformer.Between(const AColumn: string; const ALow, AHigh: Variant): IQueryTransformer;
var N: Integer;
begin
  N := Length(FFilters);
  SetLength(FFilters, N + 1);
  FFilters[N].Kind := qfBetween;
  FFilters[N].Col := Trim(AColumn);
  FFilters[N].V1 := ALow;
  FFilters[N].V2 := AHigh;
  Result := Self;
end;

function TQueryTransformer.Contains(const AColumn, AText: string): IQueryTransformer;
begin AddLike(AColumn, '%' + AText + '%', AText, lmContains); Result := Self; end;

function TQueryTransformer.StartsWith(const AColumn, AText: string): IQueryTransformer;
begin AddLike(AColumn, AText + '%', AText, lmStarts); Result := Self; end;

function TQueryTransformer.EndsWith(const AColumn, AText: string): IQueryTransformer;
begin AddLike(AColumn, '%' + AText, AText, lmEnds); Result := Self; end;

function TQueryTransformer.IsIn(const AColumn: string; const AValues: array of Variant): IQueryTransformer;
var N, I: Integer;
begin
  N := Length(FFilters);
  SetLength(FFilters, N + 1);
  FFilters[N].Kind := qfIn;
  FFilters[N].Col := Trim(AColumn);
  SetLength(FFilters[N].Vals, Length(AValues));
  for I := 0 to High(AValues) do
    FFilters[N].Vals[I] := AValues[I];
  Result := Self;
end;

function TQueryTransformer.IsNull(const AColumn: string): IQueryTransformer;
begin AddFilter(qfNull, AColumn, Null); Result := Self; end;

function TQueryTransformer.IsNotNull(const AColumn: string): IQueryTransformer;
begin AddFilter(qfNotNull, AColumn, Null); Result := Self; end;

{ ---- sorting ---- }

function TQueryTransformer.OrderByAsc(const AColumn: string): IQueryTransformer;
var N: Integer;
begin
  N := Length(FSorts);
  SetLength(FSorts, N + 1);
  FSorts[N].Col := Trim(AColumn);
  FSorts[N].Desc := False;
  Result := Self;
end;

function TQueryTransformer.OrderByDesc(const AColumn: string): IQueryTransformer;
var N: Integer;
begin
  N := Length(FSorts);
  SetLength(FSorts, N + 1);
  FSorts[N].Col := Trim(AColumn);
  FSorts[N].Desc := True;
  Result := Self;
end;

{ ---- colunas (N5) ---- }

function TQueryTransformer.Column(const AName: string; const AInclude, AVisible: Boolean;
  const AAlias: string): IQueryTransformer;
var N: Integer;
begin
  N := Length(FColumns);
  SetLength(FColumns, N + 1);
  FColumns[N].Name := Trim(AName);
  FColumns[N].Alias := Trim(AAlias);
  FColumns[N].Include := AInclude;
  FColumns[N].Visible := AVisible;
  Result := Self;
end;

{ ---- paginacao ---- }

function TQueryTransformer.Page(const APageIndex, APageSize: Integer): IQueryTransformer;
var LIdx: Integer;
begin
  LIdx := APageIndex;
  if LIdx < 1 then LIdx := 1;
  FLimit := APageSize;
  FOffset := (LIdx - 1) * APageSize;
  Result := Self;
end;

function TQueryTransformer.Limit(const AValue: Integer): IQueryTransformer;
begin FLimit := AValue; Result := Self; end;

function TQueryTransformer.Offset(const AValue: Integer): IQueryTransformer;
begin FOffset := AValue; Result := Self; end;

{ ---- render (delega ao QueryBuilder v3) ---- }

function TQueryTransformer.BuildQB: IQueryBuilder;
var
  LConn    : IConnection;
  LDialect : IDialect;
  LQB      : IQueryBuilder;
  I        : Integer;
  LOp, LExpr : string;
  LHasIncl : Boolean;
begin
  if FSource = nil then
    raise EDatabaseTransformerException.Create(
      Format(DB_ERR_QT_NO_SOURCE_MSG, ['ToSQL']), ERR_DATABASE_TRANSFORMER);
  LConn := FSource.Connection;
  if LConn = nil then
    raise EDatabaseTransformerException.Create(
      Format(DB_ERR_QT_NO_CONN_MSG, ['ToSQL']), ERR_DATABASE_NO_CONNECTION);

  LDialect := TDialect.ForConnection(LConn);
  LQB := TQueryBuilder.New.Connection(LConn);

  { SELECT das colunas Include (N5) - quotadas via dialecto; * se nenhuma }
  LHasIncl := False;
  for I := 0 to High(FColumns) do
    if FColumns[I].Include then
    begin
      LHasIncl := True;
      LExpr := LDialect.QuoteIdentifier(FColumns[I].Name);
      if FColumns[I].Alias <> '' then
        LExpr := LExpr + ' AS ' + LDialect.QuoteIdentifier(FColumns[I].Alias);
      LQB.SelectRaw(LExpr);
    end;
  if not LHasIncl then
    LQB.Select; // SELECT *

  { FROM (a query base como derived table) }
  LQB.From(FSource, QT_SUBQUERY_ALIAS);

  { filtros TIPADOS -> Where/WhereBetween/WhereIn... (bindados) }
  for I := 0 to High(FFilters) do
    case FFilters[I].Kind of
      qfEq:      LQB.Where(FFilters[I].Col, '=',  FFilters[I].V1);
      qfNeq:     LQB.Where(FFilters[I].Col, '<>', FFilters[I].V1);
      qfGt:      LQB.Where(FFilters[I].Col, '>',  FFilters[I].V1);
      qfGe:      LQB.Where(FFilters[I].Col, '>=', FFilters[I].V1);
      qfLt:      LQB.Where(FFilters[I].Col, '<',  FFilters[I].V1);
      qfLe:      LQB.Where(FFilters[I].Col, '<=', FFilters[I].V1);
      qfBetween: LQB.WhereBetween(FFilters[I].Col, FFilters[I].V1, FFilters[I].V2);
      qfLike:
        begin
          if LDialect.Supports(scILike) then LOp := 'ILIKE' else LOp := 'LIKE';
          LQB.Where(FFilters[I].Col, LOp, FFilters[I].V1);
        end;
      qfIn:      LQB.WhereIn(FFilters[I].Col, FFilters[I].Vals);
      qfNull:    LQB.WhereIsNull(FFilters[I].Col);
      qfNotNull: LQB.WhereIsNotNull(FFilters[I].Col);
    end;

  { sorting }
  for I := 0 to High(FSorts) do
    if FSorts[I].Desc then
      LQB.OrderByDesc(FSorts[I].Col)
    else
      LQB.OrderBy(FSorts[I].Col);

  { paginacao por wrap }
  if FLimit > 0 then LQB.Limit(FLimit);
  if FOffset > 0 then LQB.Offset(FOffset);

  Result := LQB;
end;

function TQueryTransformer.ToSQL: string;
begin
  Result := BuildQB.ToSQL;
end;

function TQueryTransformer.Params: TArray<Variant>;
begin
  Result := BuildQB.Params;
end;

function TQueryTransformer.VisibleColumns: TStringArray;
var
  I, N: Integer;
begin
  SetLength(Result, 0);
  N := 0;
  for I := 0 to High(FColumns) do
    if FColumns[I].Visible then
    begin
      SetLength(Result, N + 1);
      if FColumns[I].Alias <> '' then
        Result[N] := FColumns[I].Alias
      else
        Result[N] := FColumns[I].Name;
      Inc(N);
    end;
end;

function TQueryTransformer.Execute: TDataSet;
begin
  Result := BuildQB.Execute;
end;

{ ---- T5: ToHumanText ---- }

function TQueryTransformer.HumanValue(const AValue: Variant): string;
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
    Result := '?'
  else
    Result := VarToStr(AValue);
end;

function TQueryTransformer.ToHumanText: string;
var
  I, J: Integer;
  LPart, LList: string;
begin
  Result := '';
  for I := 0 to High(FFilters) do
  begin
    case FFilters[I].Kind of
      qfEq:      LPart := Format(QT_HT_EQUAL,    [FFilters[I].Col, HumanValue(FFilters[I].V1)]);
      qfNeq:     LPart := Format(QT_HT_NOTEQUAL, [FFilters[I].Col, HumanValue(FFilters[I].V1)]);
      qfGt:      LPart := Format(QT_HT_GT,       [FFilters[I].Col, HumanValue(FFilters[I].V1)]);
      qfGe:      LPart := Format(QT_HT_GE,       [FFilters[I].Col, HumanValue(FFilters[I].V1)]);
      qfLt:      LPart := Format(QT_HT_LT,       [FFilters[I].Col, HumanValue(FFilters[I].V1)]);
      qfLe:      LPart := Format(QT_HT_LE,       [FFilters[I].Col, HumanValue(FFilters[I].V1)]);
      qfBetween: LPart := Format(QT_HT_BETWEEN,  [FFilters[I].Col,
                   HumanValue(FFilters[I].V1), HumanValue(FFilters[I].V2)]);
      qfLike:
        case FFilters[I].LMode of
          lmContains: LPart := Format(QT_HT_CONTAINS, [FFilters[I].Col, FFilters[I].Text]);
          lmStarts:   LPart := Format(QT_HT_STARTS,   [FFilters[I].Col, FFilters[I].Text]);
        else
          LPart := Format(QT_HT_ENDS, [FFilters[I].Col, FFilters[I].Text]);
        end;
      qfIn:
        begin
          LList := '';
          for J := 0 to High(FFilters[I].Vals) do
          begin
            if LList <> '' then LList := LList + ', ';
            LList := LList + HumanValue(FFilters[I].Vals[J]);
          end;
          LPart := Format(QT_HT_IN, [FFilters[I].Col, LList]);
        end;
      qfNull:    LPart := Format(QT_HT_NULL,    [FFilters[I].Col]);
      qfNotNull: LPart := Format(QT_HT_NOTNULL, [FFilters[I].Col]);
    else
      LPart := '';
    end;
    if LPart = '' then Continue;
    if Result <> '' then Result := Result + QT_HT_AND;
    Result := Result + LPart;
  end;
  if Result = '' then
    Result := QT_HT_EMPTY;
end;

{ ---- T1: FilterValues ---- }

function TQueryTransformer.FilterValues: IFilterValueProvider;
begin
  if FSource = nil then
    raise EDatabaseTransformerException.Create(
      Format(DB_ERR_QT_NO_SOURCE_MSG, ['FilterValues']), ERR_DATABASE_TRANSFORMER);
  if FValueProvider = nil then
    FValueProvider := TFilterValueProvider.Create(FSource);
  Result := FValueProvider;
end;

{ TFilterValueProvider }

constructor TFilterValueProvider.Create(const ASource: IQueryBuilder);
begin
  inherited Create;
  FSource := ASource;
  FCache := TDictionary<string, TArray<Variant>>.Create;
end;

destructor TFilterValueProvider.Destroy;
begin
  FCache.Free;
  inherited Destroy;
end;

function TFilterValueProvider.ForColumn(const AColumn: string): TArray<Variant>;
var
  LKey : string;
  LQB  : IQueryBuilder;
  LDs  : TDataSet;
  LList: TArray<Variant>;
  N    : Integer;
begin
  LKey := LowerCase(Trim(AColumn));
  if FCache.TryGetValue(LKey, Result) then
    Exit;
  { SELECT DISTINCT <col> FROM (<base>) q ORDER BY <col> }
  LQB := TQueryBuilder.New.Connection(FSource.Connection)
    .Select(AColumn).Distinct.From(FSource, QT_SUBQUERY_ALIAS).OrderBy(AColumn);
  SetLength(LList, 0);
  N := 0;
  LDs := LQB.Execute;
  try
    LDs.First;
    while not LDs.Eof do
    begin
      SetLength(LList, N + 1);
      LList[N] := LDs.Fields[0].AsVariant;
      Inc(N);
      LDs.Next;
    end;
  finally
    LDs.Free;
  end;
  FCache.AddOrSetValue(LKey, LList);
  Result := LList;
end;

function TFilterValueProvider.Invalidate: IFilterValueProvider;
begin
  FCache.Clear;
  Result := Self;
end;

function TFilterValueProvider.InvalidateColumn(const AColumn: string): IFilterValueProvider;
begin
  FCache.Remove(LowerCase(Trim(AColumn)));
  Result := Self;
end;

{$ENDIF}

end.
