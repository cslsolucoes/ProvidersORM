{ =============================================================================
  Database.Dialect.SQLServer - Dialecto SQL Server (TDialectSQLServer)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.0.0
  FileVersion:    1.9.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           27/07/2026

  Onda 5.2: [quoting]; + para concatenacao; BIT (sem BOOLEAN nativo);
  IDENTITY(1,1); OFFSET..FETCH (2012+; exige ORDER BY - responsabilidade do
  caller) e TOP; schemas (dbo).

  Changelog (file):
  - 1.9.0 (27/07/2026): conformidade F5 (onda C6, #4) - FunctionsSQL override:
    information_schema.routines WHERE routine_type='FUNCTION' (functions NAO
    estao em sys.procedures; ASchema vazio -> 'dbo'; espelho de ProceduresSQL).
  - 1.8.0 (26/07/2026): conformidade F5 (onda C3, M5) - scDropIfExists MOVIDO
    para o gate de versao FMajorVersion >= 13 (SQL Server 2016); antes era
    incondicional e emitia DROP ... IF EXISTS, que falha em <2016. scStoredProcedures/
    scUserFunctions ficam incondicionais (SQL Server sempre os teve). Default
    New(15) inalterado; smoke_dialects verde. ModuleVersion 3.0.0 (onda C1).
  - 1.7.0 (25/07/2026): F5-FU.1 (populacao de IsIdentity por dialecto, ADITIVO) -
    IdentityColumnsSQL override: sys.columns.is_identity=1, ligado a sys.tables/
    sys.schemas (ASchema vazio -> 'dbo', mesmo fallback de ColumnDescriptionSQL).
  - 1.6.0 (16/07/2026): Onda 5.5-B fix: schema-scoping (fallback ao schema
    corrente em UniquesSQL/IndexesSQL quando ASchema vazio).
  - 1.5.0 (16/07/2026): Onda 5.5-B (ADITIVO) - scUnique adicionado as
    capabilities (todos os engines suportam unicidade). IndexesSQL override:
    sys.indexes + sys.tables (ASchema opcional via SCHEMA_NAME(t.schema_id));
    UniquesSQL/AddUniqueSQL ficam na base (nao overriden).
  - 1.4.0 (15/07/2026): Onda 6-f Estagio 1 (I10, ADITIVO) - LinkedServersSQL
    override: sys.servers WHERE is_linked=1 (1 coluna posicional - nome do
    servidor). ProceduresSQL override: sys.procedures + sys.schemas (ASchema
    vazio -> 'dbo'). CallProcedureSQL override: 'EXEC <proc> :p0, :p1, ...'
    (sem parenteses; identificador quotado via QuoteIdentifier).
  - 1.3.0 (15/07/2026): Onda 6-e Estagio 3 (I13, ADITIVO) - FunctionSQL
    override: LENGTH -> LEN(x) (SQL Server nao tem LENGTH; SUBSTRING usa a
    forma com virgulas, identica a base ANSI - sem override para essa).
  - 1.2.0 (15/07/2026): Onda 6-d PARTE 2 (I24, ADITIVO) - ColumnDescriptionSQL
    override: sys.extended_properties (name='MS_Description', class=1) ligado
    a sys.columns/sys.tables/sys.schemas; ASchema vazio -> 'dbo' (default do
    SQL Server).
  - 1.1.0 (14/07/2026): Onda 6-a (F5 revisao, modernizacao AQB/EMS, ADITIVO) -
    I22: version-aware real por MAJOR VERSION INTERNO do SQL Server (o mesmo
    numero devolvido por SERVERPROPERTY('ProductVersion') - 11=2012, 12=2014,
    13=2016, 14=2017, 15=2019, 16=2022; ver GetServerVersionBySQL no kernel
    Connections - sem mapeamento/tabela extra, reuso directo): New(AMajorVersion)
    overload aditivo (New sem args = New(15), "moderno" 2019+, preserva 100%
    o comportamento anterior a esta onda) - scOffsetFetch + FPagination
    passam a psTop quando AMajorVersion<11 (pre-2012, OFFSET..FETCH nao
    existe - TOP e a UNICA paginacao); scSequences (>=11, 2012+); scJSON
    (>=13, 2016+, funcoes JSON_VALUE/ISJSON/FOR JSON). I23: capabilities
    estaveis (sempre presentes desde o nosso piso 2008) scMerge (MERGE
    statement, 2008+)/scWindowFunctions (ranking functions, 2005+)/
    scRecursiveCTE (WITH cte AS (...) recursivo, 2005+)/scFullText (Full-Text
    Search, feature instalavel desde 2000). I21: DateLiteral/TimestampLiteral
    usam a base ANSI (aspas simples, sem prefixo) - SQL Server aceita
    'aaaa-mm-dd'/'aaaa-mm-dd hh:nn:ss' directamente.
  - 1.0.0 (12/07/2026): versao inicial (Onda 5.2).
  ============================================================================= }
unit Database.Dialect.SQLServer;

{$I ../../../ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$IFDEF USE_DATABASE}

uses
  {$IF DEFINED(FPC)}
  SysUtils,
  {$ELSE}
  System.SysUtils,
  {$ENDIF}
  Commons.Types,
  Commons.Database.Types,
  Commons.Database.Consts,
  Databases.Interfaces,
  Database.Dialect;

type
  TDialectSQLServer = class(TDialect)
  strict private
    FMajorVersion: Integer; // versao interna (11=2012, 13=2016, 15=2019, ...)
  strict protected
    procedure Setup; override;
  public
    class function New: IDialect; overload;
    { Onda 6-a (I22) - version-aware: AMajorVersion e a versao INTERNA do SQL
      Server (mesma que SERVERPROPERTY('ProductVersion') devolve como 1o
      numero - 11=2012 ... 16=2022). Default do overload sem args = New(15)
      ("moderno" 2019+ - preserva o comportamento pre-Onda-6-a). }
    class function New(const AMajorVersion: Integer): IDialect; overload;
    function ServerVersionMajor: Integer;
    function ColumnTypeFor(const AKind: TSQLColumnKind; const ASize: Integer = 0;
      const AScale: Integer = 0): string; override;
    function ColumnDescriptionSQL(const ATable, ASchema: string): string; override;
    function IdentityColumnsSQL(const ATableName, ASchema: string): string; override;
    function FunctionSQL(const AName: string; const AArgs: array of string): string; override;
    function LinkedServersSQL: string; override;
    function ProceduresSQL(const ASchema: string): string; override;
    function FunctionsSQL(const ASchema: string): string; override;
    function CallProcedureSQL(const AProcName: string; const AArgCount: Integer): string; override;
    function IndexesSQL(const ATable, ASchema: string): string; override;
    function UniquesSQL(const ATable, ASchema: string): string; override;
    { Onda D - COLUMN: SQL Server usa ADD SEM 'COLUMN', ALTER COLUMN SEM 'TYPE',
      e RENAME via sp_rename. (DROP COLUMN herda a base.) }
    function FieldAddSQL(const ATable, AColumn, AColumnType: string;
      const ANotNull: Boolean): string; override;
    function FieldAlterSQL(const ATable, AColumn, ANewType: string;
      const ANotNull: Boolean): string; override;
    function FieldRenameSQL(const ATable, AOldName, ANewName: string): string; override;
    { Onda D - facetas: SQL Server sp_rename (table), DROP INDEX ON t, CREATE OR ALTER VIEW. }
    function TableRenameSQL(const AOldName, ANewName: string): string; override;
    function IndexDropSQL(const ATable, AName: string): string; override;
    function ViewCreateSQL(const AName, ASelectSQL: string; const AOrReplace: Boolean): string; override;
    { Onda F1 - builder de rotinas (procedure AS <body>; function RETURNS t AS BEGIN..END). }
    function RoutineDefCreateSQL(const ADef: IRoutineDefinition): string; override;
    { Onda F3 - triggers (statement-level, ON table AS BEGIN; introspecao sys.triggers). }
    function TriggersSQL(const ASchema: string): string; override;
    function TriggerDefCreateSQL(const ADef: ITriggerDefinition): string; override;
    { Onda F4 - RULES (constraint de valor legada; sys.objects type='R'). }
    function RulesSQL(const ASchema: string): string; override;
    function RuleDefCreateSQL(const ADef: IRuleDefinition): string; override;
    function RuleDropSQL(const AName, ATable: string; const AIfExists: Boolean): string; override;
  end;

{$ENDIF}

implementation

{$IFDEF USE_DATABASE}

class function TDialectSQLServer.New: IDialect;
begin
  Result := TDialectSQLServer.New(15); // "moderno" 2019+ - preserva o comportamento pre-Onda-6-a
end;

class function TDialectSQLServer.New(const AMajorVersion: Integer): IDialect;
var
  LDialect: TDialectSQLServer;
begin
  LDialect := TDialectSQLServer.Create(dtSQLServer);
  LDialect.FMajorVersion := AMajorVersion;
  LDialect.Setup; // re-executa com a versao definida
  Result := LDialect;
end;

function TDialectSQLServer.ServerVersionMajor: Integer;
begin
  Result := FMajorVersion;
end;

procedure TDialectSQLServer.Setup;
begin
  FCapabilities := [scSchemas, scCTE, scDerivedTables, scUnion, scUnionAll,
    scIdentity, scTop,
    { Onda 6-a (I23) - sempre presentes desde o nosso piso (SQLServer 2008+) }
    scMerge, scWindowFunctions, scRecursiveCTE, scFullText,
    { Onda 5.5-B - todos os engines suportam unicidade }
    scUnique];
  { Onda 6-a (I22) - version-aware por major interno (11=2012) }
  if FMajorVersion >= 11 then
  begin
    FCapabilities := FCapabilities + [scOffsetFetch, scSequences];
    FPagination := psOffsetFetch;
  end
  else
    FPagination := psTop; // pre-2012: OFFSET..FETCH nao existe, so TOP
  if FMajorVersion >= 13 then
    { 2016+ (major 13): JSON (JSON_VALUE/ISJSON/FOR JSON) e DROP ... IF EXISTS.
      M5 (conformidade F5 C3): scDropIfExists MOVIDO para ca - antes era
      incondicional e fazia emitir DROP ... IF EXISTS, que FALHA em SQL Server
      < 2016. O default New(15) mantem-no ON (sem regressao nos golden). }
    FCapabilities := FCapabilities + [scJSON, scDropIfExists];
  { Onda D - DDL: manipulacao DDL suportada desde o piso (2008+); o
    DROP ... IF EXISTS fica no gate >= 13 acima. }
  FCapabilities := FCapabilities + [scAlterColumn, scDropColumn,
    scRenameColumn, scRenameTable, scForeignKeys, scViews, scStoredProcedures,
    scUserFunctions, scCheck];
  FMaxIdentLen := 128;
  if FMajorVersion > 0 then
    FVersionText := Format('SQL Server (major %d)', [FMajorVersion])
  else
    FVersionText := 'SQL Server';
  DefineOperator(SQLOP_CONCAT, '', ' + ', '', '', 2);
end;

function TDialectSQLServer.ColumnTypeFor(const AKind: TSQLColumnKind;
  const ASize: Integer; const AScale: Integer): string;
begin
  case AKind of
    ckBoolean:  Result := 'BIT';
    ckFloat:    Result := 'FLOAT';
    ckText:     Result := 'NVARCHAR(MAX)';
    { DATETIME (nao DATETIME2): tipo universalmente legivel pelos 4 engines. O
      Zeos vendorizado NAO mapeia DATETIME2 e DESCARTA a coluna do result set
      (SELECT * devolve tudo menos as datetime2) -> "Field data_cadastro not
      found" no read. DATETIME (precisao ~3ms, range 1753+) chega para timestamps
      e e lido por Zeos/FireDAC/SQLdb. Homogeneidade cross-engine > precisao 100ns
      nao usada. (Bug B, validacao dialectos 4 engines.) }
    ckDateTime: Result := 'DATETIME';
    ckBlob:     Result := 'VARBINARY(MAX)';
    ckIdentity: Result := 'INT IDENTITY(1,1)';
  else
    Result := inherited ColumnTypeFor(AKind, ASize, AScale);
  end;
end;

function TDialectSQLServer.RoutineDefCreateSQL(const ADef: IRoutineDefinition): string;
var
  LName, LParams, LBody, LType: string;
  LPs: TRoutineParamArray;
  I: Integer;
begin
  { SQL Server: procedure -> AS <body> (parametros @p SEM parenteses, OUTPUT
    para saida); function -> (@p t) RETURNS t AS BEGIN RETURN expr END. Tipo via
    ColumnTypeFor (SSOT). }
  Result := '';
  if (ADef = nil) or (Trim(ADef.Name) = '') then
    Exit;
  LName := QuoteIdentifier(Trim(ADef.Name));
  LPs := ADef.Params;
  if ADef.Kind = rkFunction then
  begin
    LParams := '';
    for I := 0 to High(LPs) do
    begin
      if LParams <> '' then LParams := LParams + ', ';
      LParams := LParams + '@' + Trim(LPs[I].Name) + ' ' + ColumnTypeFor(LPs[I].Kind, LPs[I].Size);
    end;
    LType := ColumnTypeFor(ADef.ReturnKind, ADef.ReturnSize);
    case ADef.BodyMode of
      rbmRaw:    LBody := ADef.BodyText;
      rbmReturn: LBody := 'BEGIN RETURN ' + ADef.BodyText + ' END';
    else
      LBody := 'BEGIN RETURN NULL END';
    end;
    Result := 'CREATE FUNCTION ' + LName + '(' + LParams + ') RETURNS ' + LType +
      ' AS ' + LBody;
  end
  else
  begin
    LParams := '';
    for I := 0 to High(LPs) do
    begin
      if LParams <> '' then LParams := LParams + ', ';
      LParams := LParams + '@' + Trim(LPs[I].Name) + ' ' + ColumnTypeFor(LPs[I].Kind, LPs[I].Size);
      if LPs[I].Direction in [pdOut, pdInOut] then
        LParams := LParams + ' OUTPUT';
    end;
    if LParams <> '' then LParams := ' ' + LParams;
    case ADef.BodyMode of
      rbmRaw: LBody := ADef.BodyText;
    else
      LBody := 'SELECT 1';
    end;
    Result := 'CREATE PROCEDURE ' + LName + LParams + ' AS ' + LBody;
  end;
end;

function TDialectSQLServer.ColumnDescriptionSQL(const ATable, ASchema: string): string;
var
  LSchema: string;
begin
  { SQL Server: sys.extended_properties com name='MS_Description' (comentario
    de coluna via sp_addextendedproperty/SSMS), class=1 (objeto/coluna),
    ligado a sys.columns/sys.tables/sys.schemas; 2 colunas POSICIONAIS -
    column_name, description (ISNULL evita NULL). ASchema vazio -> 'dbo'
    (default do SQL Server). }
  LSchema := Trim(ASchema);
  if LSchema = '' then
    LSchema := 'dbo';
  Result :=
    'SELECT col.name AS column_name, CAST(ISNULL(ep.value, '''') AS NVARCHAR(MAX)) AS description ' +
    'FROM sys.columns col ' +
    'JOIN sys.tables tbl ON tbl.object_id = col.object_id ' +
    'JOIN sys.schemas sch ON sch.schema_id = tbl.schema_id ' +
    'LEFT JOIN sys.extended_properties ep ON ep.major_id = col.object_id ' +
    'AND ep.minor_id = col.column_id AND ep.class = 1 AND ep.name = ''MS_Description'' ' +
    'WHERE tbl.name = ''' + StringReplace(Trim(ATable), '''', '''''', [rfReplaceAll]) + ''' ' +
    'AND sch.name = ''' + StringReplace(LSchema, '''', '''''', [rfReplaceAll]) + ''' ' +
    'ORDER BY col.column_id';
end;

function TDialectSQLServer.IdentityColumnsSQL(const ATableName, ASchema: string): string;
var
  LSchema: string;
begin
  { F5-FU.1 - SQL Server: sys.columns.is_identity=1 (IDENTITY(seed,increment)),
    ligado a sys.tables/sys.schemas (mesmo padrao de ColumnDescriptionSQL acima);
    1 coluna POSICIONAL - nome da coluna. ASchema vazio -> 'dbo' (default do SQL
    Server, mesmo fallback usado nos restantes metodos deste dialecto). }
  LSchema := Trim(ASchema);
  if LSchema = '' then
    LSchema := 'dbo';
  Result :=
    'SELECT col.name AS column_name ' +
    'FROM sys.columns col ' +
    'JOIN sys.tables tbl ON tbl.object_id = col.object_id ' +
    'JOIN sys.schemas sch ON sch.schema_id = tbl.schema_id ' +
    'WHERE tbl.name = ''' + StringReplace(Trim(ATableName), '''', '''''', [rfReplaceAll]) + ''' ' +
    'AND sch.name = ''' + StringReplace(LSchema, '''', '''''', [rfReplaceAll]) + ''' ' +
    'AND col.is_identity = 1';
end;

function TDialectSQLServer.FunctionSQL(const AName: string; const AArgs: array of string): string;
begin
  { SQL Server: LEN(x), nao LENGTH(x); SUBSTRING(x, p, n) usa a mesma forma
    com virgulas da base ANSI (sem override) - Onda 6-e Estagio 3 (I13). }
  if SameText(Trim(AName), 'LENGTH') then
  begin
    if Length(AArgs) >= 1 then
      Result := 'LEN(' + AArgs[0] + ')'
    else
      Result := 'LEN()';
    Exit;
  end;
  Result := inherited FunctionSQL(AName, AArgs);
end;

function TDialectSQLServer.LinkedServersSQL: string;
begin
  { SQL Server: sys.servers com is_linked=1 (linked server real - EXEC
    sp_addlinkedserver); 1 coluna POSICIONAL - name (Onda 6-f Estagio 1, I10). }
  Result := 'SELECT name AS server_name FROM sys.servers WHERE is_linked = 1 ORDER BY name';
end;

function TDialectSQLServer.ProceduresSQL(const ASchema: string): string;
var
  LSchema: string;
begin
  { SQL Server: sys.procedures ligado a sys.schemas; ASchema vazio -> 'dbo'
    (mesmo default de ColumnDescriptionSQL); 1 coluna POSICIONAL - nome da
    procedure (Onda 6-f Estagio 1, I10). }
  LSchema := Trim(ASchema);
  if LSchema = '' then
    LSchema := 'dbo';
  Result :=
    'SELECT p.name AS procedure_name ' +
    'FROM sys.procedures p ' +
    'JOIN sys.schemas s ON s.schema_id = p.schema_id ' +
    'WHERE s.name = ''' + StringReplace(LSchema, '''', '''''', [rfReplaceAll]) + ''' ' +
    'ORDER BY p.name';
end;

function TDialectSQLServer.TriggersSQL(const ASchema: string): string;
begin
  { sys.triggers dos triggers DML de tabela (parent_class = 1); is_ms_shipped=0
    exclui os do sistema. 1 coluna posicional - name. }
  Result :=
    'SELECT name FROM sys.triggers WHERE parent_class = 1 AND is_ms_shipped = 0';
end;

function TDialectSQLServer.TriggerDefCreateSQL(const ADef: ITriggerDefinition): string;
var
  LName, LTable, LTiming, LEvents, LBody: string;
begin
  { SQL Server: trigger statement-level (sem FOR EACH ROW); sem BEFORE (so
    AFTER/INSTEAD OF - BEFORE cai em AFTER); multi-evento por virgula; corpo
    'AS BEGIN SET NOCOUNT ON; ... END'. }
  Result := '';
  if (ADef = nil) or (Trim(ADef.Name) = '') or (Trim(ADef.OnTable) = '') then
    Exit;
  LName  := QuoteIdentifier(Trim(ADef.Name));
  LTable := QuoteIdentifier(Trim(ADef.OnTable));
  if ADef.Timing = ttInsteadOf then
    LTiming := 'INSTEAD OF'
  else
    LTiming := 'AFTER';
  LEvents := TriggerEventsClause(ADef.Events, ', ');
  if ADef.BodyMode = tbmRaw then
    LBody := 'AS BEGIN SET NOCOUNT ON; ' + ADef.BodyText + ' END'
  else
    LBody := 'AS BEGIN SET NOCOUNT ON; END';
  Result := 'CREATE TRIGGER ' + LName + ' ON ' + LTable + ' ' + LTiming + ' ' +
    LEvents + ' ' + LBody;
end;

function TDialectSQLServer.RulesSQL(const ASchema: string): string;
begin
  { sys.objects type='R' = RULE (objecto legado standalone). 1 coluna
    posicional - name. }
  Result := 'SELECT name FROM sys.objects WHERE type = ''R''';
end;

function TDialectSQLServer.RuleDefCreateSQL(const ADef: IRuleDefinition): string;
var
  LName, LCond: string;
begin
  { SQL Server: CREATE RULE n AS <condicao> (a RULE e uma constraint de valor
    legada; a expressao referencia UMA variavel @). Sem OR REPLACE (idempotencia
    a cargo do lancador). O evento/tabela do builder nao se aplicam (a RULE
    liga-se a colunas via sp_bindrule, passo separado NAO coberto aqui - o
    objecto existe e e introspetavel logo apos o CREATE). Corpo vazio = '@val >= 0'
    (condicao trivialmente valida). }
  Result := '';
  if (ADef = nil) or (Trim(ADef.Name) = '') then
    Exit;
  LName := QuoteIdentifier(Trim(ADef.Name));
  if Trim(ADef.BodyText) <> '' then
    LCond := ADef.BodyText
  else
    LCond := '@val >= 0';
  Result := 'CREATE RULE ' + LName + ' AS ' + LCond;
end;

function TDialectSQLServer.RuleDropSQL(const AName, ATable: string; const AIfExists: Boolean): string;
begin
  { SQL Server: DROP RULE [IF EXISTS] n (sem ON table; a RULE nao esta ligada
    neste teste, logo o drop directo funciona). }
  Result := '';
  if Trim(AName) = '' then
    Exit;
  if AIfExists and Supports(scDropIfExists) then
    Result := 'DROP RULE IF EXISTS ' + QuoteIdentifier(Trim(AName))
  else
    Result := 'DROP RULE ' + QuoteIdentifier(Trim(AName));
end;

function TDialectSQLServer.FunctionsSQL(const ASchema: string): string;
var
  LSchema: string;
begin
  { SQL Server (Onda C6, #4): functions NAO estao em sys.procedures - usa
    information_schema.routines, routine_type='FUNCTION' (valido para
    scalar/table functions); ASchema vazio -> 'dbo' (mesmo default de
    ProceduresSQL/ColumnDescriptionSQL); 1 coluna POSICIONAL - nome da
    function. }
  LSchema := Trim(ASchema);
  if LSchema = '' then
    LSchema := 'dbo';
  Result :=
    'SELECT routine_name AS function_name ' +
    'FROM information_schema.routines ' +
    'WHERE routine_type = ''FUNCTION'' AND routine_schema = ''' +
    StringReplace(LSchema, '''', '''''', [rfReplaceAll]) + ''' ' +
    'ORDER BY routine_name';
end;

function TDialectSQLServer.CallProcedureSQL(const AProcName: string; const AArgCount: Integer): string;
var
  I: Integer;
  LArgs: string;
begin
  { SQL Server: EXEC <proc> :p0, :p1, ... (SEM parenteses); AProcName vazio
    -> '' (Onda 6-f Estagio 1, I10). }
  if Trim(AProcName) = '' then
    Exit('');
  LArgs := '';
  for I := 0 to AArgCount - 1 do
  begin
    if LArgs <> '' then LArgs := LArgs + ', ';
    LArgs := LArgs + ':p' + IntToStr(I);
  end;
  Result := 'EXEC ' + QuoteIdentifier(Trim(AProcName));
  if LArgs <> '' then
    Result := Result + ' ' + LArgs;
end;

function TDialectSQLServer.IndexesSQL(const ATable, ASchema: string): string;
var
  LSch: string;
begin
  Result := '';
  if Trim(ATable) = '' then
    Exit;
  if Trim(ASchema) <> '' then
    LSch := '''' + StringReplace(Trim(ASchema), '''', '''''', [rfReplaceAll]) + ''''
  else
    LSch := 'SCHEMA_NAME()';
  Result := 'SELECT i.name FROM sys.indexes i' +
    ' INNER JOIN sys.tables t ON i.object_id = t.object_id' +
    ' WHERE t.name = ''' +
    StringReplace(Trim(ATable), '''', '''''', [rfReplaceAll]) +
    ''' AND i.name IS NOT NULL AND SCHEMA_NAME(t.schema_id) = ' + LSch;
end;

function TDialectSQLServer.UniquesSQL(const ATable, ASchema: string): string;
var
  LSch: string;
begin
  Result := '';
  if Trim(ATable) = '' then
    Exit;
  if Trim(ASchema) <> '' then
    LSch := '''' + StringReplace(Trim(ASchema), '''', '''''', [rfReplaceAll]) + ''''
  else
    LSch := 'SCHEMA_NAME()';
  Result := 'SELECT constraint_name FROM information_schema.table_constraints' +
    ' WHERE constraint_type = ''UNIQUE'' AND table_name = ''' +
    StringReplace(Trim(ATable), '''', '''''', [rfReplaceAll]) +
    ''' AND table_schema = ' + LSch;
end;

{ Onda D - COLUMN: SQL Server usa 'ADD col' (sem COLUMN), 'ALTER COLUMN col
  newtype' (sem TYPE) e rename via sp_rename. DROP COLUMN herda a base. }

function TDialectSQLServer.FieldAddSQL(const ATable, AColumn, AColumnType: string;
  const ANotNull: Boolean): string;
begin
  Result := '';
  if (Trim(ATable) = '') or (Trim(AColumn) = '') then Exit;
  Result := 'ALTER TABLE ' + QuoteIdentifier(Trim(ATable)) + ' ADD ' +
    QuoteIdentifier(Trim(AColumn)) + ' ' + AColumnType;
  if ANotNull then Result := Result + ' NOT NULL';
end;

function TDialectSQLServer.FieldAlterSQL(const ATable, AColumn, ANewType: string;
  const ANotNull: Boolean): string;
begin
  Result := '';
  if (Trim(ATable) = '') or (Trim(AColumn) = '') then Exit;
  Result := 'ALTER TABLE ' + QuoteIdentifier(Trim(ATable)) + ' ALTER COLUMN ' +
    QuoteIdentifier(Trim(AColumn)) + ' ' + ANewType;
  if ANotNull then Result := Result + ' NOT NULL';
end;

function TDialectSQLServer.FieldRenameSQL(const ATable, AOldName, ANewName: string): string;
begin
  Result := '';
  if (Trim(ATable) = '') or (Trim(AOldName) = '') or (Trim(ANewName) = '') then Exit;
  { sp_rename: 1o arg = 'tabela.coluna' (literal); 3o arg = 'COLUMN'. }
  Result := 'EXEC sp_rename ' + QuotedStr(Trim(ATable) + '.' + Trim(AOldName)) +
    ', ' + QuotedStr(Trim(ANewName)) + ', ' + QuotedStr('COLUMN');
end;

function TDialectSQLServer.TableRenameSQL(const AOldName, ANewName: string): string;
begin
  Result := '';
  if (Trim(AOldName) = '') or (Trim(ANewName) = '') then Exit;
  Result := 'EXEC sp_rename ' + QuotedStr(Trim(AOldName)) + ', ' + QuotedStr(Trim(ANewName));
end;

function TDialectSQLServer.IndexDropSQL(const ATable, AName: string): string;
begin
  Result := '';
  if (Trim(ATable) = '') or (Trim(AName) = '') then Exit;
  Result := 'DROP INDEX ' + QuoteIdentifier(Trim(AName)) + ' ON ' + QuoteIdentifier(Trim(ATable));
end;

function TDialectSQLServer.ViewCreateSQL(const AName, ASelectSQL: string; const AOrReplace: Boolean): string;
begin
  { SQL Server nao tem CREATE OR REPLACE; usa CREATE OR ALTER (2016+). }
  Result := '';
  if (Trim(AName) = '') or (Trim(ASelectSQL) = '') then Exit;
  if AOrReplace then
    Result := 'CREATE OR ALTER VIEW ' + QuoteIdentifier(Trim(AName)) + ' AS ' + ASelectSQL
  else
    Result := 'CREATE VIEW ' + QuoteIdentifier(Trim(AName)) + ' AS ' + ASelectSQL;
end;

{$ENDIF}

end.
