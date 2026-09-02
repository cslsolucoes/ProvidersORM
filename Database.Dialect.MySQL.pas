{ =============================================================================
  Database.Dialect.MySQL - Dialecto MySQL/MariaDB (TDialectMySQL)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.0.0
  FileVersion:    1.8.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           27/07/2026

  Onda 5.2: crase no quoting; CONCAT() funcional (nao ||); BOOLEAN = TINYINT(1)
  (sem tipo nativo - capability OFF); AUTO_INCREMENT (sintaxe propria, nao
  IDENTITY); LIMIT/OFFSET; CTE (MySQL 8+/MariaDB 10.2+).

  Changelog (file):
  - 1.8.0 (27/07/2026): conformidade F5 (onda C6, #4) - FunctionsSQL override:
    INFORMATION_SCHEMA.ROUTINES, ROUTINE_TYPE='FUNCTION' (ASchema=banco, vazio
    -> DATABASE(); espelho de ProceduresSQL/1.4.0).
  - 1.7.0 (25/07/2026): F5-FU.1 (populacao de IsIdentity por dialecto, ADITIVO) -
    IdentityColumnsSQL override: INFORMATION_SCHEMA.COLUMNS.EXTRA LIKE
    '%auto_increment%' (ASchema=banco, vazio -> DATABASE(), mesma semantica de
    ColumnDescriptionSQL).
  - 1.6.0 (16/07/2026): Onda 5.5-B fix: schema-scoping (fallback ao schema
    corrente em UniquesSQL/IndexesSQL quando ASchema vazio).
  - 1.5.0 (16/07/2026): Onda 5.5-B (ADITIVO) - scUnique adicionado as
    capabilities (Setup); IndexesSQL override: INFORMATION_SCHEMA.STATISTICS,
    DISTINCT index_name (UniquesSQL/AddUniqueSQL ficam na BASE).
  - 1.4.0 (15/07/2026): Onda 6-f Estagio 1 (I10, ADITIVO) - ProceduresSQL
    override: INFORMATION_SCHEMA.ROUTINES, ROUTINE_TYPE='PROCEDURE' (ASchema
    aqui e o BANCO, mesma semantica de ColumnDescriptionSQL/CreateSchemaSQL -
    vazio usa DATABASE()). CallProcedureSQL override: 'CALL <proc>(:p0, :p1,
    ...)'. LinkedServersSQL fica na BASE (MySQL nao tem o conceito nativo).
  - 1.3.0 (15/07/2026): Onda 6-d PARTE 2 (I24, ADITIVO) - ColumnDescriptionSQL
    override: INFORMATION_SCHEMA.COLUMNS.COLUMN_COMMENT; ASchema (aqui, o
    banco - schema~=database no MySQL, mesma semantica de CreateSchemaSQL)
    vazio -> DATABASE() (banco da conexao corrente).
  - 1.2.0 (14/07/2026): Onda 6-a (F5 revisao, modernizacao AQB/EMS - I23,
    ADITIVO) - capabilities ESTATICAS (sem overload de versao, ao contrario
    de PostgreSQL/SQLServer): scRecursiveCTE/scWindowFunctions/scJSON/
    scUpsert/scFullText ON (assume MySQL 8.0+/MariaDB 10.2+ - mesmo piso ja
    assumido pelo scCTE estatico pre-existente); scMerge/scSequences/scArrays
    OFF (sem equivalente nativo no MySQL). Decisao documentada (owner): o
    fork MySQL/MariaDB tem numeracoes de versao INDEPENDENTES que colidem no
    mesmo major (ex.: MySQL 8.x vs MariaDB 10.x/11.x sao ramos distintos, nao
    uma linha temporal unica) - version-gating por (Major,Minor) fica
    AMBIGUO sem saber tambem o VENDOR; por I22 ("se ambiguo, deixa a
    capability estatica e documenta"), fica estatica aqui (ao contrario de
    PostgreSQL, vendor unico e linear, e SQLServer, versionado por marketing
    year/major interno sem fork).
  - 1.1.0 (13/07/2026): Fatia B-d (continuacao Onda 4, revisao F5) - override
    de CreateSchemaSQL/DropSchemaSQL: no MySQL, "CREATE SCHEMA"/"DROP SCHEMA"
    sao sinonimos documentados de "CREATE DATABASE"/"DROP DATABASE"
    (schema~=database) - gera sempre, SEM depender da capability scSchemas
    (que continua OFF neste dialecto de proposito - nao alterada, para nao
    afetar TQueryBuilder.RenderTableRef, fora do boundary desta fatia).
  - 1.0.0 (12/07/2026): versao inicial (Onda 5.2).
  ============================================================================= }
unit Database.Dialect.MySQL;

{$I ../../../ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$IFDEF USE_DATABASE}

uses
  Commons.Types,
  Commons.Database.Types,
  Commons.Database.Consts,
  Databases.Interfaces,
  Database.Dialect;

type
  TDialectMySQL = class(TDialect)
  strict protected
    procedure Setup; override;
  public
    class function New: IDialect;
    function ColumnTypeFor(const AKind: TSQLColumnKind; const ASize: Integer = 0;
      const AScale: Integer = 0): string; override;
    function CreateSchemaSQL(const ASchema: string): string; override;
    function DropSchemaSQL(const ASchema: string): string; override;
    function ColumnDescriptionSQL(const ATable, ASchema: string): string; override;
    function IdentityColumnsSQL(const ATableName, ASchema: string): string; override;
    function ProceduresSQL(const ASchema: string): string; override;
    function FunctionsSQL(const ASchema: string): string; override;
    function CallProcedureSQL(const AProcName: string; const AArgCount: Integer): string; override;
    function IndexesSQL(const ATable, ASchema: string): string; override;
    function UniquesSQL(const ATable, ASchema: string): string; override;
    { Onda D - COLUMN: MySQL usa MODIFY COLUMN (nao ALTER COLUMN..TYPE). ADD/DROP
      COLUMN e RENAME COLUMN (MySQL 8+/MariaDB 10.5+) herdam a base. }
    function FieldAlterSQL(const ATable, AColumn, ANewType: string;
      const ANotNull: Boolean): string; override;
    { Onda D - facetas: MySQL DROP PRIMARY/FOREIGN KEY, DROP INDEX ON t, unique->DROP INDEX. }
    function PKeyDropSQL(const ATable, AName: string): string; override;
    function FKeyDropSQL(const ATable, AName: string): string; override;
    function IndexDropSQL(const ATable, AName: string): string; override;
    function UniqueDropSQL(const ATable, AName: string): string; override;
    { Onda F1 - builder de rotinas (procedure BEGIN..END; function DETERMINISTIC RETURN). }
    function RoutineDefCreateSQL(const ADef: IRoutineDefinition): string; override;
    { Onda F3 - triggers (single-event, FOR EACH ROW; introspecao INFORMATION_SCHEMA.TRIGGERS). }
    function TriggersSQL(const ASchema: string): string; override;
    function TriggerDefCreateSQL(const ADef: ITriggerDefinition): string; override;
  end;

{$ENDIF}

implementation

{$IFDEF USE_DATABASE}

uses
{$IFDEF FPC}
  SysUtils;
{$ELSE}
  System.SysUtils;
{$ENDIF}

class function TDialectMySQL.New: IDialect;
begin
  Result := TDialectMySQL.Create(dtMySQL);
end;

procedure TDialectMySQL.Setup;
begin
  FCapabilities := [scCTE, scDerivedTables, scUnion, scUnionAll, scLimitOffset,
    { Onda 6-a (I23) - estaticas, assume MySQL 8.0+/MariaDB 10.2+ (mesmo piso
      ja assumido pelo scCTE pre-existente); ver changelog do file p/ a
      decisao documentada de NAO fazer version-gating (fork MySQL/MariaDB). }
    scRecursiveCTE, scWindowFunctions, scJSON, scUpsert, scFullText,
    { Onda 5.5-B - todos os engines suportam unicidade. }
    scUnique];
  { Onda D - DDL: MySQL/MariaDB modernos suportam toda a manipulacao DDL. }
  FCapabilities := FCapabilities + [scDropIfExists, scAlterColumn, scDropColumn,
    scRenameColumn, scRenameTable, scForeignKeys, scViews, scStoredProcedures,
    scUserFunctions, scCheck];
  FPagination := psLimitOffset;
  FMaxIdentLen := 64;
  FVersionText := 'MySQL/MariaDB';
  DefineOperator(SQLOP_CONCAT, 'CONCAT(', ', ', '', ')', 2);
end;

function TDialectMySQL.ColumnTypeFor(const AKind: TSQLColumnKind;
  const ASize: Integer; const AScale: Integer): string;
begin
  case AKind of
    ckBoolean:  Result := 'TINYINT(1)';
    ckFloat:    Result := 'DOUBLE';
    ckText:     Result := 'LONGTEXT';
    ckDateTime: Result := 'DATETIME';
    ckBlob:     Result := 'LONGBLOB';
    ckIdentity: Result := 'INTEGER NOT NULL AUTO_INCREMENT';
  else
    Result := inherited ColumnTypeFor(AKind, ASize, AScale);
  end;
end;

function TDialectMySQL.RoutineDefCreateSQL(const ADef: IRoutineDefinition): string;
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
  { MySQL: procedure -> BEGIN..END; function -> RETURNS t DETERMINISTIC RETURN expr.
    Parametros sempre parentizados; direccao IN/OUT/INOUT antes do nome. Tipo via
    ColumnTypeFor (SSOT de mapeamento de tipos). }
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
      rbmReturn: LBody := 'RETURN ' + ADef.BodyText;
    else
      LBody := 'RETURN NULL';
    end;
    Result := 'CREATE FUNCTION ' + LName + '(' + LParams + ') RETURNS ' + LType +
      ' DETERMINISTIC ' + LBody;
  end
  else
  begin
    case ADef.BodyMode of
      rbmRaw: LBody := ADef.BodyText;
    else
      LBody := 'BEGIN END';
    end;
    Result := 'CREATE PROCEDURE ' + LName + '(' + LParams + ') ' + LBody;
  end;
end;

function TDialectMySQL.CreateSchemaSQL(const ASchema: string): string;
begin
  { MySQL: "CREATE SCHEMA" e sinonimo documentado de "CREATE DATABASE"
    (schema~=database) - gera sempre, independente de scSchemas (Fatia B-d). }
  Result := '';
  if Trim(ASchema) = '' then
    Exit;
  Result := 'CREATE SCHEMA ' + QuoteIdentifier(Trim(ASchema)) + ';';
end;

function TDialectMySQL.DropSchemaSQL(const ASchema: string): string;
begin
  Result := '';
  if Trim(ASchema) = '' then
    Exit;
  Result := 'DROP SCHEMA ' + QuoteIdentifier(Trim(ASchema)) + ';';
end;

function TDialectMySQL.ColumnDescriptionSQL(const ATable, ASchema: string): string;
begin
  { MySQL/MariaDB: INFORMATION_SCHEMA.COLUMNS.COLUMN_COMMENT (preenchido via
    a clausula COMMENT '...' na definicao da coluna); ASchema aqui e o nome
    do BANCO (schema~=database no MySQL, mesma semantica de CreateSchemaSQL/
    DropSchemaSQL acima) - vazio usa DATABASE() (banco da conexao corrente).
    2 colunas POSICIONAIS - column_name, description (COALESCE evita NULL). }
  Result :=
    'SELECT COLUMN_NAME AS column_name, COALESCE(COLUMN_COMMENT, '''') AS description ' +
    'FROM INFORMATION_SCHEMA.COLUMNS ' +
    'WHERE TABLE_NAME = ''' + StringReplace(Trim(ATable), '''', '''''', [rfReplaceAll]) + '''';
  if Trim(ASchema) <> '' then
    Result := Result + ' AND TABLE_SCHEMA = ''' +
      StringReplace(Trim(ASchema), '''', '''''', [rfReplaceAll]) + ''''
  else
    Result := Result + ' AND TABLE_SCHEMA = DATABASE()';
  Result := Result + ' ORDER BY ORDINAL_POSITION';
end;

function TDialectMySQL.IdentityColumnsSQL(const ATableName, ASchema: string): string;
begin
  { F5-FU.1 - MySQL/MariaDB: INFORMATION_SCHEMA.COLUMNS.EXTRA contendo
    'auto_increment' (unica marca de identity do catalogo ANSI deste motor -
    nao ha coluna is_identity dedicada); ASchema aqui e o nome do BANCO
    (schema~=database no MySQL, mesma semantica de ColumnDescriptionSQL/
    CreateSchemaSQL acima) - vazio usa DATABASE() (banco da conexao corrente).
    1 coluna POSICIONAL - nome da coluna. }
  Result :=
    'SELECT COLUMN_NAME AS column_name ' +
    'FROM INFORMATION_SCHEMA.COLUMNS ' +
    'WHERE TABLE_NAME = ''' + StringReplace(Trim(ATableName), '''', '''''', [rfReplaceAll]) + ''' ' +
    'AND EXTRA LIKE ''%auto_increment%''';
  if Trim(ASchema) <> '' then
    Result := Result + ' AND TABLE_SCHEMA = ''' +
      StringReplace(Trim(ASchema), '''', '''''', [rfReplaceAll]) + ''''
  else
    Result := Result + ' AND TABLE_SCHEMA = DATABASE()';
end;

function TDialectMySQL.ProceduresSQL(const ASchema: string): string;
begin
  { MySQL/MariaDB: INFORMATION_SCHEMA.ROUTINES, ROUTINE_TYPE='PROCEDURE';
    ASchema aqui e o nome do BANCO (schema~=database no MySQL, mesma
    semantica de ColumnDescriptionSQL/CreateSchemaSQL acima) - vazio usa
    DATABASE() (banco da conexao corrente); 1 coluna POSICIONAL - nome da
    procedure (Onda 6-f Estagio 1, I10). }
  Result :=
    'SELECT ROUTINE_NAME AS procedure_name ' +
    'FROM INFORMATION_SCHEMA.ROUTINES ' +
    'WHERE ROUTINE_TYPE = ''PROCEDURE''';
  if Trim(ASchema) <> '' then
    Result := Result + ' AND ROUTINE_SCHEMA = ''' +
      StringReplace(Trim(ASchema), '''', '''''', [rfReplaceAll]) + ''''
  else
    Result := Result + ' AND ROUTINE_SCHEMA = DATABASE()';
  Result := Result + ' ORDER BY ROUTINE_NAME';
end;

function TDialectMySQL.TriggersSQL(const ASchema: string): string;
begin
  { INFORMATION_SCHEMA.TRIGGERS; TRIGGER_SCHEMA e o BANCO (mesma semantica de
    ProceduresSQL) - vazio usa DATABASE(). 1 coluna posicional - TRIGGER_NAME. }
  Result := 'SELECT TRIGGER_NAME FROM INFORMATION_SCHEMA.TRIGGERS';
  if Trim(ASchema) <> '' then
    Result := Result + ' WHERE TRIGGER_SCHEMA = ''' +
      StringReplace(Trim(ASchema), '''', '''''', [rfReplaceAll]) + ''''
  else
    Result := Result + ' WHERE TRIGGER_SCHEMA = DATABASE()';
end;

function TDialectMySQL.TriggerDefCreateSQL(const ADef: ITriggerDefinition): string;
var
  LName, LTable, LTiming, LEvent, LBody: string;
begin
  { MySQL/MariaDB: sem INSTEAD OF (so BEFORE/AFTER); UM evento por trigger
    (usa o primeiro do conjunto); FOR EACH ROW obrigatorio; corpo vazio =
    BEGIN END (bloco composto vazio, valido). }
  Result := '';
  if (ADef = nil) or (Trim(ADef.Name) = '') or (Trim(ADef.OnTable) = '') then
    Exit;
  LName  := QuoteIdentifier(Trim(ADef.Name));
  LTable := QuoteIdentifier(Trim(ADef.OnTable));
  if ADef.Timing = ttBefore then
    LTiming := 'BEFORE'
  else
    LTiming := 'AFTER';
  LEvent := TriggerFirstEventWord(ADef.Events);
  if ADef.BodyMode = tbmRaw then
    LBody := 'BEGIN ' + ADef.BodyText + ' END'
  else
    LBody := 'BEGIN END';
  Result := 'CREATE TRIGGER ' + LName + ' ' + LTiming + ' ' + LEvent +
    ' ON ' + LTable + ' FOR EACH ROW ' + LBody;
end;

function TDialectMySQL.FunctionsSQL(const ASchema: string): string;
begin
  { MySQL/MariaDB (Onda C6, #4): INFORMATION_SCHEMA.ROUTINES, ROUTINE_TYPE=
    'FUNCTION' (espelho de ProceduresSQL, PROCEDURE->FUNCTION); ASchema aqui
    e o nome do BANCO (schema~=database no MySQL); vazio usa DATABASE(). }
  Result :=
    'SELECT ROUTINE_NAME AS function_name ' +
    'FROM INFORMATION_SCHEMA.ROUTINES ' +
    'WHERE ROUTINE_TYPE = ''FUNCTION''';
  if Trim(ASchema) <> '' then
    Result := Result + ' AND ROUTINE_SCHEMA = ''' +
      StringReplace(Trim(ASchema), '''', '''''', [rfReplaceAll]) + ''''
  else
    Result := Result + ' AND ROUTINE_SCHEMA = DATABASE()';
  Result := Result + ' ORDER BY ROUTINE_NAME';
end;

function TDialectMySQL.CallProcedureSQL(const AProcName: string; const AArgCount: Integer): string;
var
  I: Integer;
  LArgs: string;
begin
  { MySQL: CALL <proc>(:p0, :p1, ...); AProcName vazio -> '' (Onda 6-f
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

function TDialectMySQL.UniquesSQL(const ATable, ASchema: string): string;
var
  LSch: string;
begin
  Result := '';
  if Trim(ATable) = '' then
    Exit;
  if Trim(ASchema) <> '' then
    LSch := '''' + StringReplace(Trim(ASchema), '''', '''''', [rfReplaceAll]) + ''''
  else
    LSch := 'DATABASE()';
  Result := 'SELECT constraint_name FROM information_schema.table_constraints' +
    ' WHERE constraint_type = ''UNIQUE'' AND table_name = ''' +
    StringReplace(Trim(ATable), '''', '''''', [rfReplaceAll]) +
    ''' AND table_schema = ' + LSch;
end;

function TDialectMySQL.IndexesSQL(const ATable, ASchema: string): string;
var
  LSch: string;
begin
  Result := '';
  if Trim(ATable) = '' then
    Exit;
  if Trim(ASchema) <> '' then
    LSch := '''' + StringReplace(Trim(ASchema), '''', '''''', [rfReplaceAll]) + ''''
  else
    LSch := 'DATABASE()';
  Result := 'SELECT DISTINCT index_name FROM information_schema.statistics' +
    ' WHERE table_name = ''' +
    StringReplace(Trim(ATable), '''', '''''', [rfReplaceAll]) +
    ''' AND table_schema = ' + LSch;
end;

function TDialectMySQL.FieldAlterSQL(const ATable, AColumn, ANewType: string;
  const ANotNull: Boolean): string;
begin
  Result := '';
  if (Trim(ATable) = '') or (Trim(AColumn) = '') then Exit;
  Result := 'ALTER TABLE ' + QuoteIdentifier(Trim(ATable)) + ' MODIFY COLUMN ' +
    QuoteIdentifier(Trim(AColumn)) + ' ' + ANewType;
  if ANotNull then Result := Result + ' NOT NULL';
end;

function TDialectMySQL.PKeyDropSQL(const ATable, AName: string): string;
begin
  Result := '';
  if Trim(ATable) = '' then Exit;
  Result := 'ALTER TABLE ' + QuoteIdentifier(Trim(ATable)) + ' DROP PRIMARY KEY';
end;

function TDialectMySQL.FKeyDropSQL(const ATable, AName: string): string;
begin
  Result := '';
  if (Trim(ATable) = '') or (Trim(AName) = '') then Exit;
  Result := 'ALTER TABLE ' + QuoteIdentifier(Trim(ATable)) + ' DROP FOREIGN KEY ' +
    QuoteIdentifier(Trim(AName));
end;

function TDialectMySQL.IndexDropSQL(const ATable, AName: string): string;
begin
  Result := '';
  if (Trim(ATable) = '') or (Trim(AName) = '') then Exit;
  Result := 'DROP INDEX ' + QuoteIdentifier(Trim(AName)) + ' ON ' + QuoteIdentifier(Trim(ATable));
end;

function TDialectMySQL.UniqueDropSQL(const ATable, AName: string): string;
begin
  Result := '';
  if (Trim(ATable) = '') or (Trim(AName) = '') then Exit;
  Result := 'ALTER TABLE ' + QuoteIdentifier(Trim(ATable)) + ' DROP INDEX ' +
    QuoteIdentifier(Trim(AName));
end;

{$ENDIF}

end.
