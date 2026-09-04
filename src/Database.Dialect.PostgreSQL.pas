{ =============================================================================
  Database.Dialect.PostgreSQL - Dialecto PostgreSQL (TDialectPostgreSQL)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.0.0
  FileVersion:    1.8.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           27/07/2026

  Onda 5.2: schemas, CTE, RETURNING multi-linha, BOOLEAN/IDENTITY nativos,
  ILIKE (capability exclusiva), || ANSI, LIMIT/OFFSET (+ OFFSET..FETCH).

  Changelog (file):
  - 1.8.0 (27/07/2026): conformidade F5 (onda C6, #4) - FunctionsSQL override:
    information_schema.routines WHERE routine_type='FUNCTION' (ASchema vazio
    -> 'public'; espelho de ProceduresSQL/1.3.0).
  - 1.7.0 (26/07/2026): conformidade F5 (onda C3, M5) - scStoredProcedures gated
    por AtLeast(11,0) (CREATE PROCEDURE so existe no PostgreSQL 11+); antes era
    incondicional e o CREATE PROCEDURE falhava em PG<11. scUserFunctions/
    scDropIfExists ficam incondicionais (funcoes e DROP IF EXISTS existem desde
    os pisos). Default New(16) inalterado; smoke_dialects verde. ModuleVersion
    3.0.0 (onda C1).
  - 1.6.0 (25/07/2026): F5-FU.1 (populacao de IsIdentity por dialecto, ADITIVO) -
    IdentityColumnsSQL override: information_schema.columns.is_identity='YES'
    (ASchema vazio -> 'public'); nao cobre SERIAL/BIGSERIAL classico (limitacao
    do catalogo ANSI, documentada no proprio metodo).
  - 1.5.0 (16/07/2026): Onda 5.5-B fix: schema-scoping (fallback ao schema
    corrente em UniquesSQL/IndexesSQL quando ASchema vazio).
  - 1.4.0 (16/07/2026): Onda 5.5-B (ADITIVO) - scUnique adicionado
    incondicionalmente as capabilities (todos os engines suportam
    unicidade). IndexesSQL override: pg_indexes (tablename/schemaname);
    UniquesSQL/AddUniqueSQL ficam na BASE (information_schema).
  - 1.3.0 (15/07/2026): Onda 6-f Estagio 1 (I10, ADITIVO) - ProceduresSQL
    override: information_schema.routines WHERE routine_type='PROCEDURE'
    (ASchema vazio -> 'public'). CallProcedureSQL override: 'CALL
    <proc>(:p0, :p1, ...)'. LinkedServersSQL fica na BASE de proposito (NAO
    override) - pg_foreign_server (postgres_fdw) e dblink sao extensoes
    OPCIONAIS e semanticamente distintas de "linked server" (regra "se
    ambiguo, base '' e documenta" - ver Databases.Interfaces).
  - 1.2.0 (15/07/2026): Onda 6-d PARTE 2 (I24, ADITIVO) - ColumnDescriptionSQL
    override: pg_catalog.pg_description (COMMENT ON COLUMN) ligado por
    (objoid,objsubid) a pg_attribute/pg_class/pg_namespace; ASchema vazio ->
    'public' (default do PostgreSQL).
  - 1.1.0 (14/07/2026): Onda 6-a (F5 revisao, modernizacao AQB/EMS, ADITIVO) -
    I23: capabilities estaveis (sem gate de versao, sempre presentes desde
    sempre no PostgreSQL) scArrays/scSequences/scFullText. I22: version-aware
    real (FMajorVersion/FMinorVersion, thresholds bem documentados - unico
    vendor, sem ambiguidade de fork): New(AMajorVersion, AMinorVersion=0)
    overload aditivo (New sem args = New(16,0), "moderno", preserva 100% o
    comportamento anterior a esta onda) - scWindowFunctions/scRecursiveCTE
    (>=8.4), scJSON (>=9.4, JSONB), scUpsert (>=9.5, ON CONFLICT), scMerge
    (>=15.0). I21: DateLiteral/TimestampLiteral prefixam DATE '...'/
    TIMESTAMP '...' (literal tipado PostgreSQL); TryParseDateLiteral usa o
    parser BASE (reconhece o prefixo).
  - 1.0.0 (12/07/2026): versao inicial (Onda 5.2).
  ============================================================================= }
unit Database.Dialect.PostgreSQL;

{$I ORM.Defines.inc}

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
  TDialectPostgreSQL = class(TDialect)
  strict private
    FMajorVersion: Integer;
    FMinorVersion: Integer;
    function AtLeast(const AMajor, AMinor: Integer): Boolean;
  strict protected
    procedure Setup; override;
  public
    class function New: IDialect; overload;
    { Onda 6-a (I22) - version-aware: AMajorVersion/AMinorVersion (ex.: 9,4
      para PostgreSQL 9.4). Default do overload sem args = New(16, 0)
      ("moderno" - preserva o comportamento pre-Onda-6-a). }
    class function New(const AMajorVersion: Integer;
      const AMinorVersion: Integer = 0): IDialect; overload;
    function ServerVersionMajorMinor(out AMajor, AMinor: Integer): Boolean;
    function ColumnTypeFor(const AKind: TSQLColumnKind; const ASize: Integer = 0;
      const AScale: Integer = 0): string; override;
    function DateLiteral(const ADate: TDateTime): string; override;
    function TimestampLiteral(const ADateTime: TDateTime): string; override;
    function ColumnDescriptionSQL(const ATable, ASchema: string): string; override;
    function IdentityColumnsSQL(const ATableName, ASchema: string): string; override;
    function ProceduresSQL(const ASchema: string): string; override;
    function FunctionsSQL(const ASchema: string): string; override;
    function CallProcedureSQL(const AProcName: string; const AArgCount: Integer): string; override;
    function IndexesSQL(const ATable, ASchema: string): string; override;
    function UniquesSQL(const ATable, ASchema: string): string; override;
    { Onda F1 - builder de rotinas (procedure LANGUAGE plpgsql; function LANGUAGE sql). }
    function RoutineDefCreateSQL(const ADef: IRoutineDefinition): string; override;
    { Onda F3 - triggers (FUNCTION plpgsql + TRIGGER; introspecao pg_trigger). }
    function TriggersSQL(const ASchema: string): string; override;
    function TriggerDefCreateSQL(const ADef: ITriggerDefinition): string; override;
    function TriggerDropSQL(const AName, ATable: string; const AIfExists: Boolean): string; override;
    { Onda F4 - RULES (query-rewrite; pg_rules). }
    function RulesSQL(const ASchema: string): string; override;
    function RuleDefCreateSQL(const ADef: IRuleDefinition): string; override;
    function RuleDropSQL(const AName, ATable: string; const AIfExists: Boolean): string; override;
  end;

{$ENDIF}

implementation

{$IFDEF USE_DATABASE}

class function TDialectPostgreSQL.New: IDialect;
begin
  Result := TDialectPostgreSQL.New(16, 0); // "moderno" - preserva o comportamento pre-Onda-6-a
end;

class function TDialectPostgreSQL.New(const AMajorVersion: Integer;
  const AMinorVersion: Integer): IDialect;
var
  LDialect: TDialectPostgreSQL;
begin
  LDialect := TDialectPostgreSQL.Create(dtPostgreSQL);
  LDialect.FMajorVersion := AMajorVersion;
  LDialect.FMinorVersion := AMinorVersion;
  LDialect.Setup; // re-executa com a versao definida
  Result := LDialect;
end;

function TDialectPostgreSQL.ServerVersionMajorMinor(out AMajor, AMinor: Integer): Boolean;
begin
  AMajor := FMajorVersion;
  AMinor := FMinorVersion;
  Result := FMajorVersion > 0;
end;

function TDialectPostgreSQL.AtLeast(const AMajor, AMinor: Integer): Boolean;
begin
  Result := (FMajorVersion > AMajor) or
    ((FMajorVersion = AMajor) and (FMinorVersion >= AMinor));
end;

procedure TDialectPostgreSQL.Setup;
begin
  FCapabilities := [scSchemas, scCTE, scDerivedTables, scUnion, scUnionAll,
    scReturning, scReturningMulti, scBoolean, scIdentity, scILike,
    scConcatPipes, scLimitOffset, scOffsetFetch,
    { Onda 6-a (I23) - sempre presentes no PostgreSQL, sem gate de versao }
    scArrays, scSequences, scFullText];
  { Onda 5.5-B - scUnique incondicional (todos os engines suportam
    unicidade), independente de version-aware gates. }
  FCapabilities := FCapabilities + [scUnique];
  { Onda 6-a (I22) - version-aware (thresholds historicos do PostgreSQL) }
  if AtLeast(8, 4) then
    FCapabilities := FCapabilities + [scWindowFunctions, scRecursiveCTE];
  if AtLeast(9, 4) then
    FCapabilities := FCapabilities + [scJSON];
  if AtLeast(9, 5) then
    FCapabilities := FCapabilities + [scUpsert];
  if AtLeast(15, 0) then
    FCapabilities := FCapabilities + [scMerge];
  { M5 (conformidade F5 C3): CREATE PROCEDURE so existe a partir do PostgreSQL 11
    - scStoredProcedures gated por versao (antes era incondicional e o
    CREATE PROCEDURE falhava em PG < 11; as FUNCOES existem desde sempre, por
    isso scUserFunctions fica incondicional). O default New(16) mantem-no ON. }
  if AtLeast(11, 0) then
    FCapabilities := FCapabilities + [scStoredProcedures];
  { Onda D - DDL: restante manipulacao DDL suportada desde os pisos suportados
    (DROP ... IF EXISTS existe no PG desde 8.2). }
  FCapabilities := FCapabilities + [scDropIfExists, scAlterColumn, scDropColumn,
    scRenameColumn, scRenameTable, scForeignKeys, scViews,
    scUserFunctions, scCheck];
  FPagination := psLimitOffset;
  FMaxIdentLen := 63;
  if FMajorVersion > 0 then
    FVersionText := Format('PostgreSQL %d.%d', [FMajorVersion, FMinorVersion])
  else
    FVersionText := 'PostgreSQL';
  DefineOperator(SQLOP_ILIKE, '', ' ILIKE ', '', '', 2);
end;

function TDialectPostgreSQL.ColumnTypeFor(const AKind: TSQLColumnKind;
  const ASize: Integer; const AScale: Integer): string;
begin
  case AKind of
    ckBlob:     Result := 'BYTEA';
    ckIdentity: Result := 'INTEGER GENERATED BY DEFAULT AS IDENTITY';
  else
    Result := inherited ColumnTypeFor(AKind, ASize, AScale);
  end;
end;

function TDialectPostgreSQL.RoutineDefCreateSQL(const ADef: IRoutineDefinition): string;
var
  LName, LParams, LBody, LType: string;
  LPs: TRoutineParamArray;
  I: Integer;
  function DirWord(const AD: TParamDirection): string;
  begin
    case AD of
      pdOut:   Result := 'OUT';
      pdInOut: Result := 'INOUT';
    else
      Result := 'IN';
    end;
  end;
begin
  { PostgreSQL: procedure -> LANGUAGE plpgsql AS $$ BEGIN..END $$; function ->
    RETURNS t LANGUAGE sql AS $$ SELECT expr $$. Parametros sempre parentizados;
    direccao IN/OUT/INOUT antes do nome. Tipo via ColumnTypeFor (SSOT). }
  Result := '';
  if (ADef = nil) or (Trim(ADef.Name) = '') then
    Exit;
  LName := QuoteIdentifier(Trim(ADef.Name));
  LPs := ADef.Params;
  LParams := '';
  for I := 0 to High(LPs) do
  begin
    if LParams <> '' then LParams := LParams + ', ';
    LParams := LParams + DirWord(LPs[I].Direction) + ' ' +
      QuoteIdentifier(Trim(LPs[I].Name)) + ' ' + ColumnTypeFor(LPs[I].Kind, LPs[I].Size);
  end;
  if ADef.Kind = rkFunction then
  begin
    LType := ColumnTypeFor(ADef.ReturnKind, ADef.ReturnSize);
    case ADef.BodyMode of
      rbmRaw:    LBody := ADef.BodyText;
      rbmReturn: LBody := 'SELECT ' + ADef.BodyText;
    else
      LBody := 'SELECT NULL';
    end;
    Result := 'CREATE FUNCTION ' + LName + '(' + LParams + ') RETURNS ' + LType +
      ' LANGUAGE sql AS $$ ' + LBody + ' $$';
  end
  else
  begin
    case ADef.BodyMode of
      rbmRaw: LBody := ADef.BodyText;
    else
      LBody := 'BEGIN END';
    end;
    Result := 'CREATE PROCEDURE ' + LName + '(' + LParams + ') LANGUAGE plpgsql AS $$ ' +
      LBody + ' $$';
  end;
end;

function TDialectPostgreSQL.TriggersSQL(const ASchema: string): string;
var
  LSchema: string;
begin
  { pg_trigger sem os triggers internos (tgisinternal); filtra pelo schema
    (default 'public'). 1 coluna posicional - tgname. }
  LSchema := Trim(ASchema);
  if LSchema = '' then
    LSchema := 'public';
  Result :=
    'SELECT t.tgname FROM pg_catalog.pg_trigger t ' +
    'JOIN pg_catalog.pg_class c ON c.oid = t.tgrelid ' +
    'JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace ' +
    'WHERE NOT t.tgisinternal AND n.nspname = ''' + LSchema + '''';
end;

function TDialectPostgreSQL.TriggerDefCreateSQL(const ADef: ITriggerDefinition): string;
var
  LName, LFn, LTable, LTiming, LEvents, LRow, LFuncBody: string;
begin
  { PostgreSQL: um trigger precisa de uma FUNCTION trigger (plpgsql) - emite-se
    a FUNCTION (CREATE OR REPLACE = idempotente) e depois o TRIGGER, separados
    por #0 (o lancador ITriggers executa cada statement). EXECUTE PROCEDURE e
    sinonimo aceite em todas as versoes (EXECUTE FUNCTION so em PG 11+). }
  Result := '';
  if (ADef = nil) or (Trim(ADef.Name) = '') or (Trim(ADef.OnTable) = '') then
    Exit;
  LName   := QuoteIdentifier(Trim(ADef.Name));
  LFn     := QuoteIdentifier(Trim(ADef.Name) + '_fn');
  LTable  := QuoteIdentifier(Trim(ADef.OnTable));
  LTiming := TriggerTimingWord(ADef.Timing);
  LEvents := TriggerEventsClause(ADef.Events, ' OR ');
  if ADef.ForEachRow then
    LRow := ' FOR EACH ROW'
  else
    LRow := ' FOR EACH STATEMENT';
  if ADef.BodyMode = tbmRaw then
    LFuncBody := 'BEGIN ' + ADef.BodyText + ' END'
  else
    LFuncBody := 'BEGIN RETURN NULL; END';
  Result :=
    'CREATE OR REPLACE FUNCTION ' + LFn + '() RETURNS trigger LANGUAGE plpgsql AS $$ ' +
      LFuncBody + ' $$' +
    #0 +
    'CREATE TRIGGER ' + LName + ' ' + LTiming + ' ' + LEvents + ' ON ' + LTable +
      LRow + ' EXECUTE PROCEDURE ' + LFn + '()';
end;

function TDialectPostgreSQL.TriggerDropSQL(const AName, ATable: string; const AIfExists: Boolean): string;
var
  LName, LFn, LTable: string;
begin
  { DROP TRIGGER precisa de ON table no PostgreSQL; drop tambem a FUNCTION
    companheira. IF EXISTS sempre (idempotente). Dois statements (#0). }
  Result := '';
  if (Trim(AName) = '') or (Trim(ATable) = '') then
    Exit;
  LName  := QuoteIdentifier(Trim(AName));
  LFn    := QuoteIdentifier(Trim(AName) + '_fn');
  LTable := QuoteIdentifier(Trim(ATable));
  Result :=
    'DROP TRIGGER IF EXISTS ' + LName + ' ON ' + LTable +
    #0 +
    'DROP FUNCTION IF EXISTS ' + LFn + '()';
end;

function TDialectPostgreSQL.RulesSQL(const ASchema: string): string;
var
  LSchema: string;
begin
  { pg_rules: exclui a rule implicita _RETURN das views; filtra pelo schema
    (default 'public'). 1 coluna posicional - rulename. }
  LSchema := Trim(ASchema);
  if LSchema = '' then
    LSchema := 'public';
  Result :=
    'SELECT rulename FROM pg_catalog.pg_rules ' +
    'WHERE schemaname = ''' + LSchema + ''' AND rulename <> ''_RETURN''';
end;

function TDialectPostgreSQL.RuleDefCreateSQL(const ADef: IRuleDefinition): string;
var
  LName, LTable, LEvent, LBody: string;
begin
  { PostgreSQL: CREATE OR REPLACE RULE n AS ON ev TO t DO <accao>. Corpo vazio =
    'INSTEAD NOTHING' (valido para INSERT/UPDATE/DELETE numa tabela). OR REPLACE
    torna idempotente. }
  Result := '';
  if (ADef = nil) or (Trim(ADef.Name) = '') or (Trim(ADef.OnTable) = '') then
    Exit;
  LName  := QuoteIdentifier(Trim(ADef.Name));
  LTable := QuoteIdentifier(Trim(ADef.OnTable));
  case ADef.Event of
    reSelect: LEvent := 'SELECT';
    reUpdate: LEvent := 'UPDATE';
    reDelete: LEvent := 'DELETE';
  else
    LEvent := 'INSERT';
  end;
  if Trim(ADef.BodyText) <> '' then
    LBody := ADef.BodyText
  else
    LBody := 'INSTEAD NOTHING';
  Result := 'CREATE OR REPLACE RULE ' + LName + ' AS ON ' + LEvent + ' TO ' +
    LTable + ' DO ' + LBody;
end;

function TDialectPostgreSQL.RuleDropSQL(const AName, ATable: string; const AIfExists: Boolean): string;
begin
  { PostgreSQL: DROP RULE [IF EXISTS] n ON table (ON table obrigatorio). }
  Result := '';
  if (Trim(AName) = '') or (Trim(ATable) = '') then
    Exit;
  if AIfExists then
    Result := 'DROP RULE IF EXISTS ' + QuoteIdentifier(Trim(AName)) + ' ON ' + QuoteIdentifier(Trim(ATable))
  else
    Result := 'DROP RULE ' + QuoteIdentifier(Trim(AName)) + ' ON ' + QuoteIdentifier(Trim(ATable));
end;

function TDialectPostgreSQL.DateLiteral(const ADate: TDateTime): string;
begin
  { PostgreSQL: literal TIPADO - DATE 'aaaa-mm-dd' (Onda 6-a, I21). }
  Result := 'DATE ' + inherited DateLiteral(ADate);
end;

function TDialectPostgreSQL.TimestampLiteral(const ADateTime: TDateTime): string;
begin
  Result := 'TIMESTAMP ' + inherited TimestampLiteral(ADateTime);
end;

function TDialectPostgreSQL.ColumnDescriptionSQL(const ATable, ASchema: string): string;
var
  LSchema: string;
begin
  { PostgreSQL: pg_catalog.pg_description (comentarios via COMMENT ON COLUMN)
    ligado a pg_attribute/pg_class pelo par (objoid,objsubid); 2 colunas
    POSICIONAIS - column_name, description (COALESCE evita NULL). ASchema
    vazio -> 'public' (default do PostgreSQL, mesmo fallback usado noutros
    pontos do ecossistema). }
  LSchema := Trim(ASchema);
  if LSchema = '' then
    LSchema := 'public';
  Result :=
    'SELECT a.attname AS column_name, COALESCE(d.description, '''') AS description ' +
    'FROM pg_catalog.pg_attribute a ' +
    'JOIN pg_catalog.pg_class c ON c.oid = a.attrelid ' +
    'JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace ' +
    'LEFT JOIN pg_catalog.pg_description d ON d.objoid = a.attrelid AND d.objsubid = a.attnum ' +
    'WHERE c.relname = ''' + StringReplace(Trim(ATable), '''', '''''', [rfReplaceAll]) + ''' ' +
    'AND n.nspname = ''' + StringReplace(LSchema, '''', '''''', [rfReplaceAll]) + ''' ' +
    'AND a.attnum > 0 AND NOT a.attisdropped ' +
    'ORDER BY a.attnum';
end;

function TDialectPostgreSQL.IdentityColumnsSQL(const ATableName, ASchema: string): string;
var
  LSchema: string;
begin
  { F5-FU.1 - PostgreSQL: information_schema.columns.is_identity='YES' (GENERATED
    ALWAYS/BY DEFAULT AS IDENTITY, 10+); colunas SERIAL/BIGSERIAL classicas (so
    DEFAULT nextval(sequence), sem IDENTITY) NAO ficam marcadas aqui - limitacao
    conhecida do catalogo ANSI (is_identity so cobre a sintaxe IDENTITY moderna).
    1 coluna POSICIONAL - nome da coluna. ASchema vazio -> 'public' (default do
    PostgreSQL, mesmo fallback de ColumnDescriptionSQL acima). }
  LSchema := Trim(ASchema);
  if LSchema = '' then
    LSchema := 'public';
  Result :=
    'SELECT column_name FROM information_schema.columns ' +
    'WHERE table_name = ''' + StringReplace(Trim(ATableName), '''', '''''', [rfReplaceAll]) + ''' ' +
    'AND table_schema = ''' + StringReplace(LSchema, '''', '''''', [rfReplaceAll]) + ''' ' +
    'AND is_identity = ''YES''';
end;

function TDialectPostgreSQL.ProceduresSQL(const ASchema: string): string;
var
  LSchema: string;
begin
  { PostgreSQL: information_schema.routines, routine_type='PROCEDURE' (PG11+;
    catalogo padrao SQL); ASchema vazio -> 'public' (default do PostgreSQL,
    mesmo fallback de ColumnDescriptionSQL); 1 coluna POSICIONAL - nome da
    procedure (Onda 6-f Estagio 1, I10). }
  LSchema := Trim(ASchema);
  if LSchema = '' then
    LSchema := 'public';
  Result :=
    'SELECT routine_name AS procedure_name ' +
    'FROM information_schema.routines ' +
    'WHERE routine_type = ''PROCEDURE'' AND routine_schema = ''' +
    StringReplace(LSchema, '''', '''''', [rfReplaceAll]) + ''' ' +
    'ORDER BY routine_name';
end;

function TDialectPostgreSQL.FunctionsSQL(const ASchema: string): string;
var
  LSchema: string;
begin
  { PostgreSQL (Onda C6, #4): information_schema.routines, routine_type=
    'FUNCTION' (espelho de ProceduresSQL, PROCEDURE->FUNCTION); ASchema vazio
    -> 'public' (mesmo fallback de ProceduresSQL/ColumnDescriptionSQL); 1
    coluna POSICIONAL - nome da function. }
  LSchema := Trim(ASchema);
  if LSchema = '' then
    LSchema := 'public';
  Result :=
    'SELECT routine_name AS function_name ' +
    'FROM information_schema.routines ' +
    'WHERE routine_type = ''FUNCTION'' AND routine_schema = ''' +
    StringReplace(LSchema, '''', '''''', [rfReplaceAll]) + ''' ' +
    'ORDER BY routine_name';
end;

function TDialectPostgreSQL.CallProcedureSQL(const AProcName: string; const AArgCount: Integer): string;
var
  I: Integer;
  LArgs: string;
begin
  { PostgreSQL: CALL <proc>(:p0, :p1, ...); AProcName vazio -> '' (Onda 6-f
    Estagio 1, I10). }
  if Trim(AProcName) = '' then
    Exit('');
  LArgs := '';
  for I := 0 to AArgCount - 1 do
  begin
    if LArgs <> '' then LArgs := LArgs + ', ';
    LArgs := LArgs + ':p' + IntToStr(I);
  end;
  Result := 'CALL ' + QuoteIdentifier(Trim(AProcName)) + '(' + LArgs + ')';
end;

function TDialectPostgreSQL.UniquesSQL(const ATable, ASchema: string): string;
var
  LSch: string;
begin
  Result := '';
  if Trim(ATable) = '' then
    Exit;
  if Trim(ASchema) <> '' then
    LSch := '''' + StringReplace(Trim(ASchema), '''', '''''', [rfReplaceAll]) + ''''
  else
    LSch := 'current_schema()';
  Result := 'SELECT constraint_name FROM information_schema.table_constraints' +
    ' WHERE constraint_type = ''UNIQUE'' AND table_name = ''' +
    StringReplace(Trim(ATable), '''', '''''', [rfReplaceAll]) +
    ''' AND table_schema = ' + LSch;
end;

function TDialectPostgreSQL.IndexesSQL(const ATable, ASchema: string): string;
var
  LSch: string;
begin
  Result := '';
  if Trim(ATable) = '' then
    Exit;
  if Trim(ASchema) <> '' then
    LSch := '''' + StringReplace(Trim(ASchema), '''', '''''', [rfReplaceAll]) + ''''
  else
    LSch := 'current_schema()';
  Result := 'SELECT indexname FROM pg_indexes WHERE tablename = ''' +
    StringReplace(Trim(ATable), '''', '''''', [rfReplaceAll]) +
    ''' AND schemaname = ' + LSch;
end;

{$ENDIF}

end.
