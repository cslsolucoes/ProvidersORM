{ =============================================================================
  Database.Metadata - Catalogo normalizado sobre IConnection (TCatalogReader)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.0.0
  FileVersion:    1.9.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           27/07/2026

  FASE 5 Onda 5.1. Normalizacao por engine (matriz apurada na Onda 4.2d):
  - Firebird/Interbase: filtra RDB$ / MON$ / SEC$ (Zeos lista-as em GetTableNames);
  - SQLite: filtra sqlite_* (sqlite_sequence, sqlite_master, ...);
  - PostgreSQL: filtra pg_* / sql_* (defensivo - o kernel ja restringe ao schema);
  - SQL Server: filtra spt_* / MSreplication* / sysdiagrams;
  - nomes QUALIFICADOS (FireDAC "schema.tabela"): usa a parte final.
  Cache LAZY por schema/tabela (TDictionary) com Refresh explicito.
  DI transparente (Prompt Database): recebe IConnection - pooled ou directa,
  invisivel; datasets ja chegam DESCONECTADOS do kernel (Etapa A1 da F4).

  Changelog (file):
  - 1.9.0 (27/07/2026): conformidade F5 (onda C6, B2) - MetadataColumnToJSON/
    MetadataColumnFromJSON (snapshot offline SaveToFile/LoadFromFile) ganham
    "description" - fechava a assimetria: TDatabaseFields.Description ja
    existia desde a I24 (populado por ApplyColumnDescriptions) mas nunca
    persistia no snapshot JSON. Snapshots antigos (sem a chave) continuam a
    carregar via default '' do proprio Get/GetValue.
  - 1.8.0 (27/07/2026): conformidade F5 (onda C6, #4) - FunctionNames(ASchema)/
    FunctionExists(AFuncName,ASchema) NOVOS, byte-espelho de ProcedureNames/
    ProcedureExists trocando ProceduresSQL por IDialect.FunctionsSQL; fecha
    o stub de TFunctions (Database.Functions.pas) - paridade completa com
    Views/Procedures.
  - 1.7.0 (26/07/2026): conformidade F5 (onda C4) - B3: IsSystemObject deixa de
    ser no-op SILENCIOSO em MySQL/Access/SQLAnywhere - agora EXPLICITO (Access:
    prefixo MSys; MySQL: catalogos sao bases separadas, nada a filtrar por
    prefixo; SQL Anywhere: RS_/ISYS conservador). Habilita o TTables (M2) a
    filtrar objectos de sistema tambem nesses engines. ModuleVersion 3.0.0 (onda C1).
  - 1.6.0 (16/07/2026): Onda 5.5-B (indices/constraints, ADITIVO) - UniqueNames/
    IndexNames (nomes de constraints UNIQUE / indices via IDialect.UniquesSQL/
    IndexesSQL, mesmo padrao ROBUSTO de LinkedServerNames - [] em erro/sem
    suporte, coluna [0] com Trim) + UniqueExists/IndexExists (por nome, case-
    insensitive; CONSERVADOR: sem conexao ou dialecto sem introspecao -> True,
    para o SchemaSync nao re-tentar criar). Consumidos por Database.Synchronize.
    Compare (idempotencia do UNIQUE/INDEX). Nao participam do cache lazy.
  - 1.5.0 (15/07/2026): Onda 6-f Estagio 1 (I10, ADITIVO) - LinkedServerNames/
    ProcedureNames(ASchema): TStringArray - corre IDialect.LinkedServersSQL/
    ProceduresSQL (Database.Dialect.Interfaces) via FConnection.ExecuteQuery
    quando o SQL nao vier vazio E a conexao estiver ligada; le a coluna [0]
    (posicional) de cada linha. ROBUSTO - todo o bloco em try/except: sem
    Connection, conexao desligada, dialecto sem suporte (SQL vazio) ou
    qualquer erro na consulta -> [] (nunca lanca; mesmo padrao de
    ApplyColumnDescriptions/I24). Nao participam do cache lazy (chamada
    directa, mesmo padrao de DescribeQuery antes de ser cacheado - aqui sem
    cache de proposito, lista curta e pouco chamada).
  - 1.4.0 (15/07/2026): Onda 6-d PARTE 2 (I24, ADITIVO) - ApplyColumnDescriptions
    (metodo privado): apos TableStructure buscar as colunas no kernel, SE
    IDialect.ColumnDescriptionSQL(ATableName,ASchema) nao for vazio E a
    conexao estiver ligada (IsConnected), corre esse SQL (via
    FConnection.ExecuteQuery) e preenche TDatabaseFields.Description por
    coluna (match por nome, case-insensitive, SameText). ROBUSTO - todo o
    bloco envolvido em try/except silencioso: qualquer erro (dialecto sem
    suporte, SQL falha, tabela sem descricoes) deixa Description='' em todas
    as colunas SEM derrubar o TableStructure (comportamento pre-existente
    inalterado). ForeignKeys/ResolveFK herdam a enriquecao de graca (delegam a
    TableStructure).
  - 1.3.0 (15/07/2026): Onda 6-d (I9+I12+I6, ADITIVO). (a) I9 - Filter
    (TMetadataFilter): SchemaName (fallback quando ASchema nao e fornecido em
    TableNames/ColumnNames/TableStructure - server-side, via GetTableNames/
    GetColumnNames/GetTableStructure(schema)) + NamePrefix (restringe
    TableNames por prefixo, client-side, apos FilterNames) + IncludeSystemObjects
    (fonte da verdade unica de FIncludeSystem quando aplicado via Filter);
    guarda de igualdade evita Refresh redundante. (b) I12 - DescribeQuery(ASQL):
    abre ASQL via IConnection.ExecuteQuery (dataset ja desconectado), le SO a
    estrutura de Fields (GetEnumName(TypeInfo(TFieldType)) p/ ColumnType RTTI) -
    cacheado por texto exato de ASQL (FDescribeCache; limpo por Refresh).
    (c) I6 - SaveToFile/LoadFromFile/WorkOffline: snapshot JSON chave-nomeada
    (chave=nome da tabela, valor=array de colunas de estrutura) (mesma
    tecnica de escaping RFC 8259 de Database.Field.pas/Database.Table.pas,
    copia local); FSnapshot
    (TDictionary<string,TArray<TDatabaseFields>>) SEPARADO do cache online (NAO
    limpo por Refresh); WorkOffline(True) desvia SO TableStructure para o
    snapshot (vazio se a tabela nao existir la). Default (Filter zerado,
    WorkOffline=False) = comportamento pre-existente inalterado.
  - 1.2.0 (15/07/2026): Onda 6-c (I20 relacoes) - ResolveFK(ATableName,ASchema):
    TArray<TRelationInfo>, sobre o proprio TableStructure/ForeignKeys (so os
    campos com ReferencedTable preenchida; NAO inventa FKs); Cardinality
    sempre rcManyToOne (FK->PK e tipicamente N:1). Consumido por
    IQueryBuilder.AutoJoin (Database.QueryBuilder).
  - 1.1.0 (14/07/2026): renomeacao mecanica (Provider suffix removido): T/ICatalogReader.
  - 1.0.0 (12/07/2026): versao inicial (FASE 5 Onda 5.1).
  ============================================================================= }
unit Database.CatalogReader;

{$I ../../../ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$IFDEF USE_DATABASE}

uses
{$IFDEF FPC}
  SysUtils, Classes, Generics.Collections, TypInfo, DB, fpjson, jsonparser,
  Commons.IOUtils, // TFile (FPC) - SaveToFile/LoadFromFile (Onda 6-d, I6)
{$ELSE}
  System.SysUtils, System.Classes, System.Generics.Collections, System.TypInfo,
  Data.DB, System.JSON, System.IOUtils,
{$ENDIF}
  Commons.Types,
  Commons.Database.Types,
  Exceptions.Database,
  Connections.Interfaces,
  Databases.Interfaces,        // barrel consolidado - IDialect (ex-Database.Dialect.Interfaces)
  Database.Dialect,            // TDialect.ForConnection
  Database.Helpers.JSON;       // Onda C5 (M7) - JSONQuoteString (SSOT unico)

type

  ICatalogReader = interface
    ['{D4E5F6A7-B8C9-4012-9DEF-456789012345}']

    { DI (fluente): a conexao pertence ao CALLER (directa OU pooled). }
    function Connection(const AValue: IConnection): ICatalogReader; overload;
    function Connection: IConnection; overload;

    { Normalizacao: incluir objectos de SISTEMA (default False). }
    function IncludeSystemObjects(const AValue: Boolean): ICatalogReader; overload;
    function IncludeSystemObjects: Boolean; overload;

    { Catalogo (cache lazy por chamada; Refresh limpa). }
    function DatabaseNames: TStringArray;
    function SchemaNames(const ADatabase: string = ''): TStringArray;
    function TableNames(const ASchema: string = ''): TStringArray;
    function ColumnNames(const ATableName: string; const ASchema: string = ''): TStringArray;
    function TableStructure(const ATableName: string; const ASchema: string = ''): TArray<TDatabaseFields>;
    { So os campos com relacao FK (ReferencedTable preenchida). }
    function ForeignKeys(const ATableName: string; const ASchema: string = ''): TArray<TDatabaseFields>;
    { Descobre as relacoes de chave estrangeira de ATableName (Onda 6-c, I20):
      para cada campo de ForeignKeys, monta um TRelationInfo (FromTable=
      ATableName, FromColumn=Column, ToTable=ReferencedTable, ToColumn=
      ReferencedColumn, Cardinality=rcManyToOne - FK->PK e tipicamente N:1).
      Vazio se a tabela nao tiver FKs (ou se o engine nao as expuser). }
    function ResolveFK(const ATableName: string; const ASchema: string = ''): TArray<TRelationInfo>;

    { Consultas de existencia (case-insensitive; usam o cache). }
    function TableExists(const ATableName: string; const ASchema: string = ''): Boolean;
    function ColumnExists(const ATableName, AColumnName: string; const ASchema: string = ''): Boolean;

    { Onda 5.5-B - introspecao de constraints UNIQUE / indices (idempotencia do
      SchemaSync). UniqueNames/IndexNames listam os NOMES (via IDialect.Uniques
      SQL/IndexesSQL - execucao ROBUSTA, [] em erro/sem suporte). UniqueExists/
      IndexExists testam um nome (case-insensitive). Semantica CONSERVADORA:
      quando o dialecto nao expoe introspecao (SQL vazio - ex. Access UNIQUE),
      UniqueExists/IndexExists devolvem TRUE (assume presente -> o SchemaSync
      nao re-tenta criar, evita erro de objecto duplicado). }
    function UniqueNames(const ATableName: string; const ASchema: string = ''): TStringArray;
    function IndexNames(const ATableName: string; const ASchema: string = ''): TStringArray;
    function UniqueExists(const ATableName, AConstraintName: string; const ASchema: string = ''): Boolean;
    function IndexExists(const ATableName, AIndexName: string; const ASchema: string = ''): Boolean;

    { Onda D (D.1) - introspecao de PK/FK, pre-requisito da idempotencia da
      manipulacao imperativa por nivel (ITable.AddPrimaryKey/DropForeignKey...).
      PrimaryKeyColumns = colunas marcadas IsPKey no TableStructure (ordem do
      catalogo); ForeignKeyNames = nomes DISTINTOS de constraint em ForeignKeys
      (so os campos com ConstraintName preenchido). *Exists testam presenca
      (case-insensitive, TRIM). Reusam os metodos ja existentes -> valem em todos
      os engines que expoem TableStructure/ForeignKeys, sem SQL novo de dialecto. }
    function PrimaryKeyColumns(const ATableName: string; const ASchema: string = ''): TStringArray;
    function PrimaryKeyExists(const ATableName: string; const ASchema: string = ''): Boolean;
    function ForeignKeyNames(const ATableName: string; const ASchema: string = ''): TStringArray;
    function ForeignKeyExists(const ATableName, AConstraintName: string; const ASchema: string = ''): Boolean;

    { Onda D (D.1) - introspecao de VIEWS (schema-level). ViewNames via
      IDialect.ViewsSQL (BASE information_schema.views; FB/SQLite override);
      ViewExists por nome (case-insensitive). Vazio/False onde nao suportado. }
    function ViewNames(const ASchema: string = ''): TStringArray;
    function ViewExists(const AViewName: string; const ASchema: string = ''): Boolean;

    { Invalida TODOS os caches (proxima chamada rele o catalogo). }
    function Refresh: ICatalogReader;

    { Filtro de catalogo (Onda 6-d, I9; fluente, com guarda de igualdade -
      so invalida os caches quando o filtro efetivamente muda). SchemaName
      serve de FALLBACK quando o parametro ASchema de TableNames/ColumnNames/
      TableStructure e omitido/vazio (e, por delegacao, ForeignKeys/ResolveFK/
      TableExists/ColumnExists); NamePrefix restringe TableNames por prefixo
      de nome (case-insensitive, client-side); IncludeSystemObjects passa a
      ser a fonte da verdade de ICatalogReader.IncludeSystemObjects quando o
      Filter e aplicado. Default (record zerado) = sem restricao
      (comportamento pre-existente inalterado). }
    function Filter(const AFilter: TMetadataFilter): ICatalogReader;

    { Descreve as COLUNAS do resultado de um SELECT arbitrario (Onda 6-d,
      I12): abre ASQL via a IConnection injectada (dataset ja chega
      DESCONECTADO do kernel) e le a ESTRUTURA de Fields (sem percorrer
      linhas) - Column=FieldName, ColumnType=nome RTTI do TFieldType,
      ColumnTypeCode=Ord(DataType), IsNull='NO' quando Field.Required, senao
      'YES'. Cacheado por texto exato de ASQL. }
    function DescribeQuery(const ASQL: string): TArray<TDatabaseFields>;

    { Snapshot OFFLINE do catalogo (Onda 6-d, I6). SaveToFile grava em APath
      um JSON chave-nomeada (chave=nome da tabela, valor=array de colunas de
      estrutura) com o TableStructure de cada tabela devolvida por
      TableNames; LoadFromFile
      relê o ficheiro para um cache interno (substitui o snapshot anterior);
      WorkOffline(True) faz TableStructure devolver desse cache em vez de
      consultar a IConnection (array vazio se a tabela nao estiver no
      snapshot). Default WorkOffline=False (comportamento pre-existente
      inalterado; as restantes operacoes de ICatalogReader continuam online mesmo
      com WorkOffline(True) - so TableStructure e desviada). }
    function SaveToFile(const APath: string): ICatalogReader;
    function LoadFromFile(const APath: string): ICatalogReader;
    function WorkOffline(const AValue: Boolean): ICatalogReader; overload;
    function WorkOffline: Boolean; overload;

    { Onda 6-f Estagio 1 (I10) - linked/remote servers e stored procedures
      tipadas do motor. SQL por banco vem de IDialect.LinkedServersSQL/
      ProceduresSQL (Database.Dialect.Interfaces - unico sitio com SQL
      especifico de motor); AQUI so a descoberta (execucao + normalizacao em
      array de nomes). Robusto: sem Connection injectada, conexao nao ligada,
      dialecto sem suporte (SQL vazio - ver overrides por banco) ou qualquer
      erro na consulta -> [] (nunca lanca; mesmo padrao de
      ApplyColumnDescriptions/I24). }
    function LinkedServerNames: TStringArray;
    function ProcedureNames(const ASchema: string = ''): TStringArray;
    { Onda D (D.1) - existe uma stored procedure? (olho idempotente sobre
      ProcedureNames; SameText). Dialecto sem SQL de procedures -> False. }
    function ProcedureExists(const AProcName: string; const ASchema: string = ''): Boolean;

    { Onda C6 (#4, paridade Views/Procedures) - FUNCTIONS de utilizador do
      motor. SQL por banco vem de IDialect.FunctionsSQL (unico sitio com SQL
      especifico de motor); AQUI so a descoberta (execucao + normalizacao em
      array de nomes), mesmo padrao ROBUSTO de ProcedureNames/ViewNames -
      sem Connection injectada, conexao nao ligada, dialecto sem suporte (SQL
      vazio - SQLite/Access/SQL Anywhere) ou qualquer erro na consulta -> []
      (nunca lanca). }
    function FunctionNames(const ASchema: string = ''): TStringArray;
    { existe uma function de utilizador? (olho idempotente sobre
      FunctionNames; SameText). Dialecto sem SQL de functions -> False. }
    function FunctionExists(const AFuncName: string; const ASchema: string = ''): Boolean;

    { Onda F3 - TRIGGERS do motor. SQL por banco vem de IDialect.TriggersSQL
      (unico sitio com SQL especifico de motor); AQUI so a descoberta (execucao
      + normalizacao em array de nomes), mesmo padrao ROBUSTO de ProcedureNames/
      ViewNames - sem Connection, conexao nao ligada, dialecto sem suporte (SQL
      vazio - Access) ou erro na consulta -> [] (nunca lanca). TriggerExists e
      olho idempotente (SameText/Trim). }
    function TriggerNames(const ASchema: string = ''): TStringArray;
    function TriggerExists(const ATriggerName: string; const ASchema: string = ''): Boolean;

    { Onda F4 - RULES do motor (so PostgreSQL/SQL Server). SQL por banco vem de
      IDialect.RulesSQL; mesmo padrao ROBUSTO de TriggerNames -> [] onde nao
      suportado (MySQL/Firebird/SQLite/SQLAnywhere/Access) ou erro. RuleExists
      e olho idempotente (SameText/Trim). }
    function RuleNames(const ASchema: string = ''): TStringArray;
    function RuleExists(const ARuleName: string; const ASchema: string = ''): Boolean;
  end;

  TCatalogReader = class(TInterfacedObject, ICatalogReader)
  strict private
    FConnection    : IConnection;
    FIncludeSystem : Boolean;
    FTablesCache   : TDictionary<string, TStringArray>;          // key: schema
    FColumnsCache  : TDictionary<string, TStringArray>;          // key: schema|tabela
    FStructCache   : TDictionary<string, TArray<TDatabaseFields>>; // key: schema|tabela
    { Onda 6-d (I9) }
    FFilter        : TMetadataFilter;
    { Onda 6-d (I12) }
    FDescribeCache : TDictionary<string, TArray<TDatabaseFields>>; // key: SQL exato
    { Onda 6-d (I6) }
    FWorkOffline   : Boolean;
    FSnapshot      : TDictionary<string, TArray<TDatabaseFields>>; // key: tabela (lowercase)
    procedure CheckConnection(const AOp: string);
    function CacheKey(const ASchema, ATable: string): string;
    function BaseName(const AName: string): string;
    function IsSystemObject(const AName: string): Boolean;
    function FilterNames(const ANames: TStringArray): TStringArray;
    { Onda 6-d (I9) }
    function EffectiveSchema(const ASchema: string): string;
    function FilterByPrefix(const ANames: TStringArray): TStringArray;
    { Onda 6-d PARTE 2 (I24) }
    procedure ApplyColumnDescriptions(const ATableName, ASchema: string;
      var AStructure: TArray<TDatabaseFields>);
    { F5-FU.1 - popula IsIdentity por dialecto (IdentityColumnsSQL). }
    procedure ApplyColumnIdentity(const ATableName, ASchema: string;
      var AStructure: TArray<TDatabaseFields>);
  public
    constructor Create;
    destructor Destroy; override;
    class function New: ICatalogReader; overload;
    class function New(const AConnection: IConnection): ICatalogReader; overload;

    { ICatalogReader }
    function Connection(const AValue: IConnection): ICatalogReader; overload;
    function Connection: IConnection; overload;
    function IncludeSystemObjects(const AValue: Boolean): ICatalogReader; overload;
    function IncludeSystemObjects: Boolean; overload;
    function DatabaseNames: TStringArray;
    function SchemaNames(const ADatabase: string = ''): TStringArray;
    function TableNames(const ASchema: string = ''): TStringArray;
    function ColumnNames(const ATableName: string; const ASchema: string = ''): TStringArray;
    function TableStructure(const ATableName: string; const ASchema: string = ''): TArray<TDatabaseFields>;
    function ForeignKeys(const ATableName: string; const ASchema: string = ''): TArray<TDatabaseFields>;
    function ResolveFK(const ATableName: string; const ASchema: string = ''): TArray<TRelationInfo>;
    function TableExists(const ATableName: string; const ASchema: string = ''): Boolean;
    function ColumnExists(const ATableName, AColumnName: string; const ASchema: string = ''): Boolean;
    { Onda 5.5-B - introspecao de UNIQUE/indices (idempotencia do SchemaSync) }
    function UniqueNames(const ATableName: string; const ASchema: string = ''): TStringArray;
    function IndexNames(const ATableName: string; const ASchema: string = ''): TStringArray;
    function UniqueExists(const ATableName, AConstraintName: string; const ASchema: string = ''): Boolean;
    function IndexExists(const ATableName, AIndexName: string; const ASchema: string = ''): Boolean;
    { Onda D (D.1) - introspecao de PK/FK (derivada de TableStructure/ForeignKeys). }
    function PrimaryKeyColumns(const ATableName: string; const ASchema: string = ''): TStringArray;
    function PrimaryKeyExists(const ATableName: string; const ASchema: string = ''): Boolean;
    function ForeignKeyNames(const ATableName: string; const ASchema: string = ''): TStringArray;
    function ForeignKeyExists(const ATableName, AConstraintName: string; const ASchema: string = ''): Boolean;
    function ViewNames(const ASchema: string = ''): TStringArray;
    function ViewExists(const AViewName: string; const ASchema: string = ''): Boolean;
    function Refresh: ICatalogReader;
    { Onda 6-d (I9) }
    function Filter(const AFilter: TMetadataFilter): ICatalogReader;
    { Onda 6-d (I12) }
    function DescribeQuery(const ASQL: string): TArray<TDatabaseFields>;
    { Onda 6-d (I6) }
    function SaveToFile(const APath: string): ICatalogReader;
    function LoadFromFile(const APath: string): ICatalogReader;
    function WorkOffline(const AValue: Boolean): ICatalogReader; overload;
    function WorkOffline: Boolean; overload;
    { Onda 6-f Estagio 1 (I10) }
    function LinkedServerNames: TStringArray;
    function ProcedureNames(const ASchema: string = ''): TStringArray;
    function ProcedureExists(const AProcName: string; const ASchema: string = ''): Boolean;
    function FunctionNames(const ASchema: string = ''): TStringArray;
    function FunctionExists(const AFuncName: string; const ASchema: string = ''): Boolean;
    { Onda F3 - triggers }
    function TriggerNames(const ASchema: string = ''): TStringArray;
    function TriggerExists(const ATriggerName: string; const ASchema: string = ''): Boolean;
    { Onda F4 - rules }
    function RuleNames(const ASchema: string = ''): TStringArray;
    function RuleExists(const ARuleName: string; const ASchema: string = ''): Boolean;
  end;

{$ENDIF}

implementation

{$IFDEF USE_DATABASE}

{ TCatalogReader }

constructor TCatalogReader.Create;
begin
  inherited Create;
  FIncludeSystem := False;
  FWorkOffline := False;
  FTablesCache := TDictionary<string, TStringArray>.Create;
  FColumnsCache := TDictionary<string, TStringArray>.Create;
  FStructCache := TDictionary<string, TArray<TDatabaseFields>>.Create;
  FDescribeCache := TDictionary<string, TArray<TDatabaseFields>>.Create;
  FSnapshot := TDictionary<string, TArray<TDatabaseFields>>.Create;
end;

destructor TCatalogReader.Destroy;
begin
  FSnapshot.Free;
  FDescribeCache.Free;
  FStructCache.Free;
  FColumnsCache.Free;
  FTablesCache.Free;
  inherited;
end;

class function TCatalogReader.New: ICatalogReader;
begin
  Result := TCatalogReader.Create;
end;

class function TCatalogReader.New(const AConnection: IConnection): ICatalogReader;
begin
  Result := TCatalogReader.Create;
  Result.Connection(AConnection);
end;

procedure TCatalogReader.CheckConnection(const AOp: string);
begin
  if FConnection = nil then
    raise EDatabaseMetadataException.Create(
      'ICatalogReader sem IConnection injectada - ' + AOp,
      ERR_DATABASE_NO_CONNECTION);
end;

function TCatalogReader.CacheKey(const ASchema, ATable: string): string;
begin
  Result := LowerCase(Trim(ASchema)) + '|' + LowerCase(Trim(ATable));
end;

{ nomes QUALIFICADOS (ex.: FireDAC "dbo.tabela"): normaliza para a parte final }
function TCatalogReader.BaseName(const AName: string): string;
var
  LDot: Integer;
begin
  Result := Trim(AName);
  LDot := LastDelimiter('.', Result);
  if LDot > 0 then
    Result := Copy(Result, LDot + 1, MaxInt);
end;

function TCatalogReader.IsSystemObject(const AName: string): Boolean;
var
  LName, LUpper: string;
  LType: TDatabaseTypes;
begin
  Result := False;
  LName := BaseName(AName);
  LUpper := UpperCase(LName);
  LType := dtNone;
  if FConnection <> nil then
    LType := FConnection.GetConnectionData.DatabaseType;
  case LType of
    dtFireBird:
      Result := (Pos('RDB$', LUpper) = 1) or (Pos('MON$', LUpper) = 1) or
                (Pos('SEC$', LUpper) = 1);
    dtSQLite:
      Result := Pos('SQLITE_', LUpper) = 1;
    dtPostgreSQL:
      Result := (Pos('PG_', LUpper) = 1) or (Pos('SQL_', LUpper) = 1);
    dtSQLServer:
      Result := (Pos('SPT_', LUpper) = 1) or (Pos('MSREPLICATION', LUpper) = 1) or
                SameText(LName, 'sysdiagrams');
    { B3 (conformidade F5 C4): os 3 engines abaixo eram no-op SILENCIOSO
      (IncludeSystemObjects(False) nao filtrava nada) - agora EXPLICITOS. }
    dtMySQL:
      { MySQL/MariaDB: os catalogos de sistema (information_schema/mysql/
        performance_schema/sys) sao BASES separadas, nao tabelas da base do
        utilizador - o GetTableNames ja lista so a base corrente; nada a filtrar
        por prefixo. }
      Result := False;
    dtAccess:
      { Access/Jet: tabelas de sistema tem o prefixo 'MSys' (MSysObjects,
        MSysQueries, ...) e podem vir no GetTableNames via ODBC/OLEDB. }
      Result := Pos('MSYS', LUpper) = 1;
    dtSQLAnywhere:
      { SQL Anywhere: os catalogos vivem no owner SYS (SYS.SYSTABLE...) e nao
        aparecem no GetTableNames do owner do utilizador; prefixos internos
        'RS_' (replicacao) / 'ISYS' filtrados conservadoramente. }
      Result := (Pos('RS_', LUpper) = 1) or (Pos('ISYS', LUpper) = 1);
  end;
end;

function TCatalogReader.FilterNames(const ANames: TStringArray): TStringArray;
var
  I, N: Integer;
begin
  if FIncludeSystem then
    Exit(ANames);
  SetLength(Result, Length(ANames));
  N := 0;
  for I := 0 to High(ANames) do
    if not IsSystemObject(ANames[I]) then
    begin
      Result[N] := ANames[I];
      Inc(N);
    end;
  SetLength(Result, N);
end;

{ Onda 6-d (I9) - quando o caller nao fornece ASchema explicitamente, cai no
  SchemaName do Filter (server-side: participa da chamada real ao
  GetTableNames/GetColumnNames/GetTableStructure); com ASchema explicito, o
  Filter NUNCA sobrepoe a escolha do caller. }
function TCatalogReader.EffectiveSchema(const ASchema: string): string;
begin
  if Trim(ASchema) <> '' then
    Result := ASchema
  else
    Result := FFilter.SchemaName;
end;

{ Onda 6-d (I9) - restringe TableNames por prefixo de nome (case-insensitive,
  sobre a parte final de nomes qualificados via BaseName); client-side (o
  GetTableNames do kernel nao aceita prefixo). NamePrefix vazio = sem
  restricao (Exit rapido, identidade). }
function TCatalogReader.FilterByPrefix(const ANames: TStringArray): TStringArray;
var
  I, N: Integer;
  LPrefix: string;
begin
  LPrefix := UpperCase(Trim(FFilter.NamePrefix));
  if LPrefix = '' then
    Exit(ANames);
  SetLength(Result, Length(ANames));
  N := 0;
  for I := 0 to High(ANames) do
    if Pos(LPrefix, UpperCase(BaseName(ANames[I]))) = 1 then
    begin
      Result[N] := ANames[I];
      Inc(N);
    end;
  SetLength(Result, N);
end;

{ Onda 6-d PARTE 2 (I24) - preenche TDatabaseFields.Description por coluna
  (match por nome, case-insensitive) a partir do SQL devolvido por
  IDialect.ColumnDescriptionSQL. ADITIVO e ROBUSTO: sem conexao ligada,
  dialecto sem suporte (SQL vazio - SQLite/Access) ou qualquer erro na
  consulta -> Description fica '' em todas as colunas (no-op gracioso) e
  AStructure (chamado por TableStructure) continua a funcionar normalmente -
  uma falha na descricao NUNCA pode derrubar a descoberta de estrutura. }
procedure TCatalogReader.ApplyColumnDescriptions(const ATableName, ASchema: string;
  var AStructure: TArray<TDatabaseFields>);
var
  LDialect: IDialect;
  LSQL: string;
  LDS: TDataSet;
  I: Integer;
  LColumn, LDescription: string;
begin
  if (FConnection = nil) or (not FConnection.IsConnected) then
    Exit;
  try
    LDialect := TDialect.ForConnection(FConnection);
    LSQL := LDialect.ColumnDescriptionSQL(ATableName, ASchema);
    if Trim(LSQL) = '' then
      Exit; // dialecto sem suporte (BASE - ex.: SQLite/Access)
    LDS := FConnection.ExecuteQuery(LSQL);
    try
      while not LDS.Eof do
      begin
        LColumn := LDS.Fields[0].AsString;
        LDescription := LDS.Fields[1].AsString;
        for I := 0 to High(AStructure) do
          if SameText(Trim(AStructure[I].Column), Trim(LColumn)) then
          begin
            AStructure[I].Description := LDescription;
            Break;
          end;
        LDS.Next;
      end;
    finally
      LDS.Free;
    end;
  except
    { silencioso (ADITIVO/ROBUSTO) - qualquer falha na consulta de descricoes
      nao pode derrubar o TableStructure; colunas ficam com Description=''. }
  end;
end;

{ F5-FU.1 - popula IsIdentity (autoincremento/IDENTITY) por dialecto; espelho
  EXATO de ApplyColumnDescriptions: corre IDialect.IdentityColumnsSQL (1 coluna
  POSICIONAL = nome), casa por nome (case-insensitive) e marca IsIdentity:=1.
  Robusto: dialecto sem catalogo dedicado (SQLite/Access/SQL Anywhere) devolve
  SQL vazio -> no-op (IsIdentity fica 0); qualquer falha e silenciosa. }
procedure TCatalogReader.ApplyColumnIdentity(const ATableName, ASchema: string;
  var AStructure: TArray<TDatabaseFields>);
var
  LDialect: IDialect;
  LSQL: string;
  LDS: TDataSet;
  I: Integer;
  LColumn: string;
begin
  if (FConnection = nil) or (not FConnection.IsConnected) then
    Exit;
  try
    LDialect := TDialect.ForConnection(FConnection);
    LSQL := LDialect.IdentityColumnsSQL(ATableName, ASchema);
    if Trim(LSQL) = '' then
      Exit;
    LDS := FConnection.ExecuteQuery(LSQL);
    try
      while not LDS.Eof do
      begin
        LColumn := LDS.Fields[0].AsString;
        for I := 0 to High(AStructure) do
          if SameText(Trim(AStructure[I].Column), Trim(LColumn)) then
          begin
            AStructure[I].IsIdentity := 1;
            Break;
          end;
        LDS.Next;
      end;
    finally
      LDS.Free;
    end;
  except
    { silencioso (ADITIVO/ROBUSTO) - IsIdentity fica 0 em falha. }
  end;
end;

{ ---- DI / opcoes ---- }

function TCatalogReader.Connection(const AValue: IConnection): ICatalogReader;
begin
  FConnection := AValue;
  Refresh; // conexao nova = catalogo novo
  Result := Self;
end;

function TCatalogReader.Connection: IConnection;
begin
  Result := FConnection;
end;

function TCatalogReader.IncludeSystemObjects(const AValue: Boolean): ICatalogReader;
begin
  if FIncludeSystem <> AValue then
  begin
    FIncludeSystem := AValue;
    Refresh; // o filtro participa do cache
  end;
  Result := Self;
end;

function TCatalogReader.IncludeSystemObjects: Boolean;
begin
  Result := FIncludeSystem;
end;

{ Onda 6-d (I9) - setter fluente com guarda: so aplica (e Refresh, ja que o
  schema/prefixo/sistema participam do cache) quando o filtro efetivamente
  muda. AFilter.IncludeSystemObjects passa a ser a fonte da verdade de
  FIncludeSystem (o Filter e um "setter atomico" do conjunto completo). }
function TCatalogReader.Filter(const AFilter: TMetadataFilter): ICatalogReader;
var
  LNew: TMetadataFilter;
begin
  LNew.SchemaName := Trim(AFilter.SchemaName);
  LNew.NamePrefix := Trim(AFilter.NamePrefix);
  LNew.IncludeSystemObjects := AFilter.IncludeSystemObjects;
  if (LNew.SchemaName <> FFilter.SchemaName) or
     (LNew.NamePrefix <> FFilter.NamePrefix) or
     (LNew.IncludeSystemObjects <> FIncludeSystem) then
  begin
    FFilter := LNew;
    FIncludeSystem := LNew.IncludeSystemObjects;
    Refresh; // schema/prefixo/sistema participam do cache -> catalogo novo
  end
  else
    FFilter := LNew;
  Result := Self;
end;

{ ---- catalogo (cache lazy) ---- }

function TCatalogReader.DatabaseNames: TStringArray;
begin
  CheckConnection('DatabaseNames');
  Result := FConnection.GetDatabaseNames;
end;

function TCatalogReader.SchemaNames(const ADatabase: string): TStringArray;
begin
  CheckConnection('SchemaNames');
  Result := FConnection.GetSchemaNames(ADatabase);
end;

function TCatalogReader.TableNames(const ASchema: string): TStringArray;
var
  LKey: string;
  LSchema: string;
begin
  CheckConnection('TableNames');
  LSchema := EffectiveSchema(ASchema); // Onda 6-d (I9): fallback ao SchemaName do Filter
  LKey := LowerCase(Trim(LSchema));
  if not FTablesCache.TryGetValue(LKey, Result) then
  begin
    Result := FilterByPrefix(FilterNames(FConnection.GetTableNames(LSchema)));
    FTablesCache.Add(LKey, Result);
  end;
end;

function TCatalogReader.ColumnNames(const ATableName: string;
  const ASchema: string): TStringArray;
var
  LKey: string;
  LSchema: string;
begin
  CheckConnection('ColumnNames');
  if Trim(ATableName) = '' then
    raise EDatabaseMetadataException.Create(
      'ColumnNames: nome de tabela vazio', ERR_DATABASE_INVALID_NAME);
  LSchema := EffectiveSchema(ASchema); // Onda 6-d (I9)
  LKey := CacheKey(LSchema, ATableName);
  if not FColumnsCache.TryGetValue(LKey, Result) then
  begin
    Result := FConnection.GetColumnNames(ATableName, LSchema);
    FColumnsCache.Add(LKey, Result);
  end;
end;

function TCatalogReader.TableStructure(const ATableName: string;
  const ASchema: string): TArray<TDatabaseFields>;
var
  LKey: string;
  LSchema: string;
begin
  { Onda 6-d (I6) - WorkOffline(True) desvia para o snapshot carregado por
    LoadFromFile, SEM consultar a conexao; array vazio se a tabela nao
    constar do snapshot. Guarda de nome vazio preservada (mesma mensagem/
    codigo do caminho online, so nao exige CheckConnection). }
  if FWorkOffline then
  begin
    if Trim(ATableName) = '' then
      raise EDatabaseMetadataException.Create(
        'TableStructure: nome de tabela vazio', ERR_DATABASE_INVALID_NAME);
    if not FSnapshot.TryGetValue(LowerCase(Trim(ATableName)), Result) then
      SetLength(Result, 0);
    Exit;
  end;
  CheckConnection('TableStructure');
  if Trim(ATableName) = '' then
    raise EDatabaseMetadataException.Create(
      'TableStructure: nome de tabela vazio', ERR_DATABASE_INVALID_NAME);
  LSchema := EffectiveSchema(ASchema); // Onda 6-d (I9)
  LKey := CacheKey(LSchema, ATableName);
  if not FStructCache.TryGetValue(LKey, Result) then
  begin
    Result := FConnection.GetTableStructure(ATableName, LSchema);
    ApplyColumnDescriptions(ATableName, LSchema, Result); // Onda 6-d PARTE 2 (I24)
    ApplyColumnIdentity(ATableName, LSchema, Result);      // F5-FU.1 - popula IsIdentity
    FStructCache.Add(LKey, Result);
  end;
end;

function TCatalogReader.ForeignKeys(const ATableName: string;
  const ASchema: string): TArray<TDatabaseFields>;
var
  LAll: TArray<TDatabaseFields>;
  I, N: Integer;
begin
  LAll := TableStructure(ATableName, ASchema);
  SetLength(Result, Length(LAll));
  N := 0;
  for I := 0 to High(LAll) do
    if Trim(LAll[I].ReferencedTable) <> '' then
    begin
      Result[N] := LAll[I];
      Inc(N);
    end;
  SetLength(Result, N);
end;

{ Onda 6-c (I20) - descoberta de FK -> TRelationInfo, sobre o proprio
  TableStructure (NAO inventa FKs; so os campos que ja chegam com
  ReferencedTable preenchida, reusando o filtro de ForeignKeys). }
function TCatalogReader.ResolveFK(const ATableName: string;
  const ASchema: string): TArray<TRelationInfo>;
var
  LFks: TArray<TDatabaseFields>;
  I: Integer;
begin
  LFks := ForeignKeys(ATableName, ASchema);
  SetLength(Result, Length(LFks));
  for I := 0 to High(LFks) do
  begin
    Result[I].FromTable := ATableName;
    Result[I].FromColumn := LFks[I].Column;
    Result[I].ToTable := LFks[I].ReferencedTable;
    Result[I].ToColumn := LFks[I].ReferencedColumn;
    Result[I].Cardinality := rcManyToOne;
  end;
end;

{ ---- existencia (case-insensitive, via cache) ---- }

function TCatalogReader.TableExists(const ATableName: string;
  const ASchema: string): Boolean;
var
  LNames: TStringArray;
  I: Integer;
begin
  Result := False;
  LNames := TableNames(ASchema);
  for I := 0 to High(LNames) do
    if SameText(BaseName(LNames[I]), BaseName(ATableName)) then
      Exit(True);
end;

function TCatalogReader.ColumnExists(const ATableName, AColumnName: string;
  const ASchema: string): Boolean;
var
  LNames: TStringArray;
  I: Integer;
begin
  Result := False;
  LNames := ColumnNames(ATableName, ASchema);
  for I := 0 to High(LNames) do
    if SameText(LNames[I], AColumnName) then
      Exit(True);
end;

function TCatalogReader.Refresh: ICatalogReader;
begin
  FTablesCache.Clear;
  FColumnsCache.Clear;
  FStructCache.Clear;
  FDescribeCache.Clear; // Onda 6-d (I12) - cache do DescribeQuery participa do Refresh
  { NOTA: FSnapshot (Onda 6-d, I6) NAO e limpo aqui de proposito - e um
    snapshot OFFLINE independente do catalogo online, so substituido por um
    novo LoadFromFile. }
  Result := Self;
end;

{ ---- Onda 6-d (I12) - DescribeQuery ---- }

function TCatalogReader.DescribeQuery(const ASQL: string): TArray<TDatabaseFields>;
var
  LDS: TDataSet;
  I: Integer;
  LResult: TArray<TDatabaseFields>;
  LFld: TField;
begin
  CheckConnection('DescribeQuery');
  if Trim(ASQL) = '' then
    raise EDatabaseMetadataException.Create(
      'DescribeQuery: SQL vazio', ERR_DATABASE_INVALID_NAME);
  if FDescribeCache.TryGetValue(ASQL, Result) then
    Exit;
  LDS := FConnection.ExecuteQuery(ASQL);
  try
    SetLength(LResult, LDS.FieldCount);
    for I := 0 to LDS.FieldCount - 1 do
    begin
      LFld := LDS.Fields[I];
      LResult[I].Table := '';
      LResult[I].Column := LFld.FieldName;
      LResult[I].ColumnType := GetEnumName(TypeInfo(TFieldType), Integer(LFld.DataType));
      LResult[I].ColumnTypeCode := Integer(LFld.DataType);
      if LFld.Required then
        LResult[I].IsNull := 'NO'
      else
        LResult[I].IsNull := 'YES';
      LResult[I].Value := '';
      LResult[I].ToDefault := '';
      LResult[I].IsChanged := 0;
      LResult[I].IsPKey := 0;
      LResult[I].Position := I + 1;
      LResult[I].ConstraintName := '';
      LResult[I].ReferencedTable := '';
      LResult[I].ReferencedColumn := '';
      LResult[I].OnUpdateRule := '';
      LResult[I].OnDeleteRule := '';
    end;
  finally
    LDS.Free;
  end;
  Result := LResult;
  FDescribeCache.Add(ASQL, Result);
end;

{ ---- Onda 6-d (I6) - snapshot offline (JSON chave-nomeada) ----
  Escaping RFC 8259 - Onda C5 (M7, conformidade F5): delega ao SSOT unico
  Database.Helpers.JSON.JSONQuoteString (antes copia local
  MetadataJSONQuoteString - regra #14). }

{ ESTRUTURA completa de 1 coluna (TDatabaseFields) -> objeto JSON; usada por
  SaveToFile (1 objeto por elemento do array de cada tabela). }
function MetadataColumnToJSON(const AField: TDatabaseFields): string;
begin
  Result := '{' +
    '"table":' + JSONQuoteString(AField.Table) + ',' +
    '"column":' + JSONQuoteString(AField.Column) + ',' +
    '"columnType":' + JSONQuoteString(AField.ColumnType) + ',' +
    '"columnTypeCode":' + IntToStr(AField.ColumnTypeCode) + ',' +
    '"isNull":' + JSONQuoteString(AField.IsNull) + ',' +
    '"value":' + JSONQuoteString(AField.Value) + ',' +
    '"toDefault":' + JSONQuoteString(AField.ToDefault) + ',' +
    '"isChanged":' + IntToStr(AField.IsChanged) + ',' +
    '"isPKey":' + IntToStr(AField.IsPKey) + ',' +
    '"position":' + IntToStr(AField.Position) + ',' +
    '"constraintName":' + JSONQuoteString(AField.ConstraintName) + ',' +
    '"referencedTable":' + JSONQuoteString(AField.ReferencedTable) + ',' +
    '"referencedColumn":' + JSONQuoteString(AField.ReferencedColumn) + ',' +
    '"onUpdateRule":' + JSONQuoteString(AField.OnUpdateRule) + ',' +
    '"onDeleteRule":' + JSONQuoteString(AField.OnDeleteRule) + ',' +
    { B2 (conformidade F5, onda C6) - Description entra no snapshot offline
      (fechava a assimetria: TDatabaseFields.Description ja existia desde a
      I24, mas o SaveToFile/LoadFromFile do snapshot nunca a persistia). }
    '"description":' + JSONQuoteString(AField.Description) +
  '}';
end;

{$IF DEFINED(FPC)}
function MetadataColumnFromJSON(const AObj: TJSONObject): TDatabaseFields;
begin
  Result.Table := AObj.Get('table', '');
  Result.Column := AObj.Get('column', '');
  Result.ColumnType := AObj.Get('columnType', '');
  Result.ColumnTypeCode := AObj.Get('columnTypeCode', 0);
  Result.IsNull := AObj.Get('isNull', 'YES');
  Result.Value := AObj.Get('value', '');
  Result.ToDefault := AObj.Get('toDefault', '');
  Result.IsChanged := AObj.Get('isChanged', 0);
  Result.IsPKey := AObj.Get('isPKey', 0);
  Result.Position := AObj.Get('position', 0);
  Result.ConstraintName := AObj.Get('constraintName', '');
  Result.ReferencedTable := AObj.Get('referencedTable', '');
  Result.ReferencedColumn := AObj.Get('referencedColumn', '');
  Result.OnUpdateRule := AObj.Get('onUpdateRule', '');
  Result.OnDeleteRule := AObj.Get('onDeleteRule', '');
  Result.Description := AObj.Get('description', '');
end;
{$ELSE}
function MetadataColumnFromJSON(const AObj: TJSONObject): TDatabaseFields;
begin
  Result.Table := AObj.GetValue<string>('table', '');
  Result.Column := AObj.GetValue<string>('column', '');
  Result.ColumnType := AObj.GetValue<string>('columnType', '');
  Result.ColumnTypeCode := AObj.GetValue<Integer>('columnTypeCode', 0);
  Result.IsNull := AObj.GetValue<string>('isNull', 'YES');
  Result.Value := AObj.GetValue<string>('value', '');
  Result.ToDefault := AObj.GetValue<string>('toDefault', '');
  Result.IsChanged := AObj.GetValue<Integer>('isChanged', 0);
  Result.IsPKey := AObj.GetValue<Integer>('isPKey', 0);
  Result.Position := AObj.GetValue<Integer>('position', 0);
  Result.ConstraintName := AObj.GetValue<string>('constraintName', '');
  Result.ReferencedTable := AObj.GetValue<string>('referencedTable', '');
  Result.ReferencedColumn := AObj.GetValue<string>('referencedColumn', '');
  Result.OnUpdateRule := AObj.GetValue<string>('onUpdateRule', '');
  Result.OnDeleteRule := AObj.GetValue<string>('onDeleteRule', '');
  Result.Description := AObj.GetValue<string>('description', '');
end;
{$ENDIF}

function TCatalogReader.SaveToFile(const APath: string): ICatalogReader;
var
  LNames: TStringArray;
  I, J: Integer;
  LStruct: TArray<TDatabaseFields>;
  LBody, LColsJSON: string;
begin
  CheckConnection('SaveToFile');
  LNames := TableNames;
  LBody := '';
  for I := 0 to High(LNames) do
  begin
    LStruct := TableStructure(LNames[I]);
    LColsJSON := '';
    for J := 0 to High(LStruct) do
    begin
      if LColsJSON <> '' then
        LColsJSON := LColsJSON + ',';
      LColsJSON := LColsJSON + MetadataColumnToJSON(LStruct[J]);
    end;
    if LBody <> '' then
      LBody := LBody + ',';
    LBody := LBody + JSONQuoteString(LNames[I]) + ':[' + LColsJSON + ']';
  end;
  try
    TFile.WriteAllText(APath, '{' + LBody + '}');
  except
    on E: Exception do
      raise EDatabaseMetadataException.Create(
        'SaveToFile: falha ao gravar snapshot em "' + APath + '" - ' + E.Message,
        ERR_DATABASE_METADATA_FILE);
  end;
  Result := Self;
end;

function TCatalogReader.LoadFromFile(const APath: string): ICatalogReader;
var
  LJSON: string;
{$IF DEFINED(FPC)}
  LData: TJSONData;
  LObj: TJSONObject;
  LArr: TJSONArray;
  I, J: Integer;
  LCols: TArray<TDatabaseFields>;
{$ELSE}
  LVal: TJSONValue;
  LObj: TJSONObject;
  LPair: TJSONPair;
  LArr: TJSONArray;
  J: Integer;
  LCols: TArray<TDatabaseFields>;
{$ENDIF}
begin
  Result := Self;
  if not TFile.Exists(APath) then
    raise EDatabaseMetadataException.Create(
      'LoadFromFile: ficheiro nao encontrado - ' + APath, ERR_DATABASE_METADATA_FILE);
  try
    LJSON := TFile.ReadAllText(APath);
  except
    on E: Exception do
      raise EDatabaseMetadataException.Create(
        'LoadFromFile: falha ao ler "' + APath + '" - ' + E.Message,
        ERR_DATABASE_METADATA_FILE);
  end;
  FSnapshot.Clear;
  if Trim(LJSON) = '' then
    Exit;
{$IF DEFINED(FPC)}
  LData := GetJSON(LJSON);
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
      LArr := TJSONArray(LObj.Items[I]);
      SetLength(LCols, LArr.Count);
      for J := 0 to LArr.Count - 1 do
        if LArr.Items[J] is TJSONObject then
          LCols[J] := MetadataColumnFromJSON(TJSONObject(LArr.Items[J]));
      FSnapshot.AddOrSetValue(LowerCase(Trim(LObj.Names[I])), LCols);
    end;
  finally
    LObj.Free;
  end;
{$ELSE}
  LVal := TJSONObject.ParseJSONValue(LJSON);
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
      LArr := TJSONArray(LPair.JsonValue);
      SetLength(LCols, LArr.Count);
      for J := 0 to LArr.Count - 1 do
        if LArr.Items[J] is TJSONObject then
          LCols[J] := MetadataColumnFromJSON(TJSONObject(LArr.Items[J]));
      FSnapshot.AddOrSetValue(LowerCase(Trim(LPair.JsonString.Value)), LCols);
    end;
  finally
    LObj.Free;
  end;
{$ENDIF}
end;

function TCatalogReader.WorkOffline(const AValue: Boolean): ICatalogReader;
begin
  FWorkOffline := AValue;
  Result := Self;
end;

function TCatalogReader.WorkOffline: Boolean;
begin
  Result := FWorkOffline;
end;

{ ---- Onda 6-f Estagio 1 (I10) - linked servers + stored procedures ---- }

function TCatalogReader.LinkedServerNames: TStringArray;
var
  LDialect: IDialect;
  LSQL: string;
  LDS: TDataSet;
  N: Integer;
begin
  SetLength(Result, 0);
  if (FConnection = nil) or (not FConnection.IsConnected) then
    Exit;
  try
    LDialect := TDialect.ForConnection(FConnection);
    LSQL := LDialect.LinkedServersSQL;
    if Trim(LSQL) = '' then
      Exit; // dialecto sem suporte (BASE - todos exceto SQLServer)
    LDS := FConnection.ExecuteQuery(LSQL);
    try
      N := 0;
      while not LDS.Eof do
      begin
        SetLength(Result, N + 1);
        Result[N] := LDS.Fields[0].AsString;
        Inc(N);
        LDS.Next;
      end;
    finally
      LDS.Free;
    end;
  except
    { silencioso (ROBUSTO) - qualquer falha na consulta devolve [] ; nunca
      derruba o chamador (mesmo padrao de ApplyColumnDescriptions/I24). }
    SetLength(Result, 0);
  end;
end;

function TCatalogReader.ProcedureNames(const ASchema: string): TStringArray;
var
  LDialect: IDialect;
  LSQL: string;
  LSchema: string;
  LDS: TDataSet;
  N: Integer;
begin
  SetLength(Result, 0);
  if (FConnection = nil) or (not FConnection.IsConnected) then
    Exit;
  try
    LDialect := TDialect.ForConnection(FConnection);
    LSchema := EffectiveSchema(ASchema); // Onda 6-d (I9): fallback ao SchemaName do Filter
    LSQL := LDialect.ProceduresSQL(LSchema);
    if Trim(LSQL) = '' then
      Exit; // dialecto sem suporte (BASE - SQLite/Access)
    LDS := FConnection.ExecuteQuery(LSQL);
    try
      N := 0;
      while not LDS.Eof do
      begin
        SetLength(Result, N + 1);
        Result[N] := LDS.Fields[0].AsString;
        Inc(N);
        LDS.Next;
      end;
    finally
      LDS.Free;
    end;
  except
    SetLength(Result, 0);
  end;
end;

function TCatalogReader.ProcedureExists(const AProcName, ASchema: string): Boolean;
var
  LNames: TStringArray;
  I: Integer;
begin
  { Onda D (D.1) - olho idempotente sobre ProcedureNames (mesmo padrao de
    ViewExists). Dialecto sem SQL de procedures (SQLite/Access) -> [] -> False. }
  Result := False;
  LNames := ProcedureNames(ASchema);
  for I := 0 to High(LNames) do
    if SameText(Trim(LNames[I]), Trim(AProcName)) then
      Exit(True);
end;

function TCatalogReader.FunctionNames(const ASchema: string): TStringArray;
var
  LDialect: IDialect;
  LSQL: string;
  LSchema: string;
  LDS: TDataSet;
  N: Integer;
begin
  { Onda C6 (#4) - byte-espelho de ProcedureNames, trocando ProceduresSQL por
    FunctionsSQL. }
  SetLength(Result, 0);
  if (FConnection = nil) or (not FConnection.IsConnected) then
    Exit;
  try
    LDialect := TDialect.ForConnection(FConnection);
    LSchema := EffectiveSchema(ASchema);
    LSQL := LDialect.FunctionsSQL(LSchema);
    if Trim(LSQL) = '' then
      Exit; // dialecto sem suporte (BASE - SQLite/Access/SQL Anywhere)
    LDS := FConnection.ExecuteQuery(LSQL);
    try
      N := 0;
      while not LDS.Eof do
      begin
        SetLength(Result, N + 1);
        Result[N] := LDS.Fields[0].AsString;
        Inc(N);
        LDS.Next;
      end;
    finally
      LDS.Free;
    end;
  except
    SetLength(Result, 0);
  end;
end;

function TCatalogReader.FunctionExists(const AFuncName, ASchema: string): Boolean;
var
  LNames: TStringArray;
  I: Integer;
begin
  { Onda C6 (#4) - olho idempotente sobre FunctionNames (mesmo padrao de
    ProcedureExists). Dialecto sem SQL de functions -> [] -> False. }
  Result := False;
  LNames := FunctionNames(ASchema);
  for I := 0 to High(LNames) do
    if SameText(Trim(LNames[I]), Trim(AFuncName)) then
      Exit(True);
end;

function TCatalogReader.TriggerNames(const ASchema: string): TStringArray;
var
  LDialect: IDialect;
  LSQL: string;
  LSchema: string;
  LDS: TDataSet;
  N: Integer;
begin
  { Onda F3 - byte-espelho de ProcedureNames, trocando ProceduresSQL por
    TriggersSQL. Robusto: [] em erro/sem suporte (Access). }
  SetLength(Result, 0);
  if (FConnection = nil) or (not FConnection.IsConnected) then
    Exit;
  try
    LDialect := TDialect.ForConnection(FConnection);
    LSchema := EffectiveSchema(ASchema);
    LSQL := LDialect.TriggersSQL(LSchema);
    if Trim(LSQL) = '' then
      Exit; // dialecto sem suporte (BASE - Access)
    LDS := FConnection.ExecuteQuery(LSQL);
    try
      N := 0;
      while not LDS.Eof do
      begin
        SetLength(Result, N + 1);
        Result[N] := Trim(LDS.Fields[0].AsString);
        Inc(N);
        LDS.Next;
      end;
    finally
      LDS.Free;
    end;
  except
    SetLength(Result, 0);
  end;
end;

function TCatalogReader.TriggerExists(const ATriggerName, ASchema: string): Boolean;
var
  LNames: TStringArray;
  I: Integer;
begin
  { Onda F3 - olho idempotente sobre TriggerNames (SameText/Trim). Dialecto sem
    SQL de triggers (Access) -> [] -> False. }
  Result := False;
  LNames := TriggerNames(ASchema);
  for I := 0 to High(LNames) do
    if SameText(Trim(LNames[I]), Trim(ATriggerName)) then
      Exit(True);
end;

function TCatalogReader.RuleNames(const ASchema: string): TStringArray;
var
  LDialect: IDialect;
  LSQL: string;
  LSchema: string;
  LDS: TDataSet;
  N: Integer;
begin
  { Onda F4 - byte-espelho de TriggerNames, trocando TriggersSQL por RulesSQL.
    Robusto: [] em erro/sem suporte (so PostgreSQL/SQL Server devolvem SQL). }
  SetLength(Result, 0);
  if (FConnection = nil) or (not FConnection.IsConnected) then
    Exit;
  try
    LDialect := TDialect.ForConnection(FConnection);
    LSchema := EffectiveSchema(ASchema);
    LSQL := LDialect.RulesSQL(LSchema);
    if Trim(LSQL) = '' then
      Exit; // dialecto sem RULE (todos menos PG/SQL Server)
    LDS := FConnection.ExecuteQuery(LSQL);
    try
      N := 0;
      while not LDS.Eof do
      begin
        SetLength(Result, N + 1);
        Result[N] := Trim(LDS.Fields[0].AsString);
        Inc(N);
        LDS.Next;
      end;
    finally
      LDS.Free;
    end;
  except
    SetLength(Result, 0);
  end;
end;

function TCatalogReader.RuleExists(const ARuleName, ASchema: string): Boolean;
var
  LNames: TStringArray;
  I: Integer;
begin
  { Onda F4 - olho idempotente sobre RuleNames (SameText/Trim). Dialecto sem
    RULE -> [] -> False. }
  Result := False;
  LNames := RuleNames(ASchema);
  for I := 0 to High(LNames) do
    if SameText(Trim(LNames[I]), Trim(ARuleName)) then
      Exit(True);
end;

{ ---- Onda 5.5-B - introspecao de UNIQUE/indices (idempotencia SchemaSync) ---- }

function TCatalogReader.UniqueNames(const ATableName: string;
  const ASchema: string): TStringArray;
var
  LDialect: IDialect;
  LSQL: string;
  LDS: TDataSet;
  N: Integer;
begin
  SetLength(Result, 0);
  if (FConnection = nil) or (not FConnection.IsConnected) then
    Exit;
  try
    LDialect := TDialect.ForConnection(FConnection);
    LSQL := LDialect.UniquesSQL(ATableName, EffectiveSchema(ASchema));
    if Trim(LSQL) = '' then
      Exit; // dialecto sem introspecao (ex. Access)
    LDS := FConnection.ExecuteQuery(LSQL);
    try
      N := 0;
      while not LDS.Eof do
      begin
        SetLength(Result, N + 1);
        Result[N] := Trim(LDS.Fields[0].AsString);
        Inc(N);
        LDS.Next;
      end;
    finally
      LDS.Free;
    end;
  except
    { robusto (mesmo padrao de LinkedServerNames/I24) - [] em qualquer falha. }
    SetLength(Result, 0);
  end;
end;

function TCatalogReader.IndexNames(const ATableName: string;
  const ASchema: string): TStringArray;
var
  LDialect: IDialect;
  LSQL: string;
  LDS: TDataSet;
  N: Integer;
begin
  SetLength(Result, 0);
  if (FConnection = nil) or (not FConnection.IsConnected) then
    Exit;
  try
    LDialect := TDialect.ForConnection(FConnection);
    LSQL := LDialect.IndexesSQL(ATableName, EffectiveSchema(ASchema));
    if Trim(LSQL) = '' then
      Exit;
    LDS := FConnection.ExecuteQuery(LSQL);
    try
      N := 0;
      while not LDS.Eof do
      begin
        SetLength(Result, N + 1);
        Result[N] := Trim(LDS.Fields[0].AsString);
        Inc(N);
        LDS.Next;
      end;
    finally
      LDS.Free;
    end;
  except
    SetLength(Result, 0);
  end;
end;

function TCatalogReader.UniqueExists(const ATableName, AConstraintName: string;
  const ASchema: string): Boolean;
var
  LDialect: IDialect;
  LNames: TStringArray;
  I: Integer;
begin
  { CONSERVADOR: sem conexao OU dialecto sem introspecao (SQL vazio, ex. Access)
    -> True (assume presente; o SchemaSync nao re-tenta criar em tabela
    existente). Em tabela NOVA o Compare curto-circuita com LNewTable, por isso
    o UNIQUE e sempre emitido na criacao mesmo que aqui devolva True. }
  Result := True;
  if (FConnection = nil) or (not FConnection.IsConnected) then
    Exit;
  LDialect := TDialect.ForConnection(FConnection);
  if Trim(LDialect.UniquesSQL(ATableName, EffectiveSchema(ASchema))) = '' then
    Exit;
  LNames := UniqueNames(ATableName, ASchema);
  Result := False;
  for I := 0 to High(LNames) do
    if SameText(Trim(LNames[I]), Trim(AConstraintName)) then
      Exit(True);
end;

function TCatalogReader.IndexExists(const ATableName, AIndexName: string;
  const ASchema: string): Boolean;
var
  LDialect: IDialect;
  LNames: TStringArray;
  I: Integer;
begin
  Result := True;
  if (FConnection = nil) or (not FConnection.IsConnected) then
    Exit;
  LDialect := TDialect.ForConnection(FConnection);
  if Trim(LDialect.IndexesSQL(ATableName, EffectiveSchema(ASchema))) = '' then
    Exit;
  LNames := IndexNames(ATableName, ASchema);
  Result := False;
  for I := 0 to High(LNames) do
    if SameText(Trim(LNames[I]), Trim(AIndexName)) then
      Exit(True);
end;

function TCatalogReader.PrimaryKeyColumns(const ATableName: string;
  const ASchema: string): TStringArray;
var
  LStruct: TArray<TDatabaseFields>;
  I, N: Integer;
begin
  { Deriva do TableStructure ja existente (campo IsPKey, preenchido pelo
    GetTableStructureSQLForType de cada engine). Vazio se sem PK / sem conexao. }
  SetLength(Result, 0);
  LStruct := TableStructure(ATableName, ASchema);
  N := 0;
  for I := 0 to High(LStruct) do
    if LStruct[I].IsPKey <> 0 then
    begin
      SetLength(Result, N + 1);
      Result[N] := Trim(LStruct[I].Column);
      Inc(N);
    end;
end;

function TCatalogReader.PrimaryKeyExists(const ATableName: string;
  const ASchema: string): Boolean;
begin
  Result := Length(PrimaryKeyColumns(ATableName, ASchema)) > 0;
end;

function TCatalogReader.ForeignKeyNames(const ATableName: string;
  const ASchema: string): TStringArray;
var
  LFKs: TArray<TDatabaseFields>;
  I, J, N: Integer;
  LName: string;
  LDup: Boolean;
begin
  { Nomes DISTINTOS de constraint FK, a partir do ForeignKeys ja existente (so
    campos com ConstraintName preenchido). Vazio se o engine nao expuser o nome
    da constraint. }
  SetLength(Result, 0);
  LFKs := ForeignKeys(ATableName, ASchema);
  N := 0;
  for I := 0 to High(LFKs) do
  begin
    LName := Trim(LFKs[I].ConstraintName);
    if LName = '' then
      Continue;
    LDup := False;
    for J := 0 to N - 1 do
      if SameText(Result[J], LName) then
      begin
        LDup := True;
        Break;
      end;
    if LDup then
      Continue;
    SetLength(Result, N + 1);
    Result[N] := LName;
    Inc(N);
  end;
end;

function TCatalogReader.ForeignKeyExists(const ATableName, AConstraintName: string;
  const ASchema: string): Boolean;
var
  LNames: TStringArray;
  I: Integer;
begin
  Result := False;
  LNames := ForeignKeyNames(ATableName, ASchema);
  for I := 0 to High(LNames) do
    if SameText(Trim(LNames[I]), Trim(AConstraintName)) then
      Exit(True);
end;

function TCatalogReader.ViewNames(const ASchema: string): TStringArray;
var
  LDialect: IDialect;
  LSQL: string;
  LSchema: string;
  LDS: TDataSet;
  N: Integer;
begin
  { Onda D (D.1) - mesmo padrao ROBUSTO de ProcedureNames: pede o SQL de views
    ao dialecto (ViewsSQL), corre e le a coluna [0]. Vazio (dialecto sem SQL) ou
    erro -> [] gracioso. }
  SetLength(Result, 0);
  if (FConnection = nil) or (not FConnection.IsConnected) then
    Exit;
  try
    LDialect := TDialect.ForConnection(FConnection);
    LSchema := EffectiveSchema(ASchema);
    LSQL := LDialect.ViewsSQL(LSchema);
    if Trim(LSQL) = '' then
      Exit;
    LDS := FConnection.ExecuteQuery(LSQL);
    try
      N := 0;
      while not LDS.Eof do
      begin
        SetLength(Result, N + 1);
        Result[N] := Trim(LDS.Fields[0].AsString);
        Inc(N);
        LDS.Next;
      end;
    finally
      LDS.Free;
    end;
  except
    SetLength(Result, 0);
  end;
end;

function TCatalogReader.ViewExists(const AViewName, ASchema: string): Boolean;
var
  LNames: TStringArray;
  I: Integer;
begin
  Result := False;
  LNames := ViewNames(ASchema);
  for I := 0 to High(LNames) do
    if SameText(Trim(LNames[I]), Trim(AViewName)) then
      Exit(True);
end;

{$ENDIF}

end.
