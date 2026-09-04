{ =============================================================================
  Database.Dialect.SQLite - Dialecto SQLite (TDialectSQLite)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.0.0
  FileVersion:    1.6.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           25/07/2026

  Onda 5.2: sem schemas; BOOLEAN = INTEGER (afinidade); ckIdentity =
  INTEGER PRIMARY KEY AUTOINCREMENT (EMBUTE a PK - o SchemaSync 5.5 nao deve
  emitir PRIMARY KEY adicional para essa coluna); RETURNING (3.35+);
  LIMIT/OFFSET; ALTER limitado -> padrao recreate-table fica no SchemaSync.

  Changelog (file):
  - 1.6.0 (25/07/2026): F5-FU.1 (populacao de IsIdentity por dialecto, ADITIVO) -
    IdentityColumnsSQL override -> '' (identity = INTEGER PRIMARY KEY implicito,
    sem catalogo dedicado - limitacao documentada no proprio metodo).
  - 1.5.0 (17/07/2026): bug-574 - CreateIndexSQL override: CREATE [UNIQUE] INDEX
    IF NOT EXISTS (idempotencia NATIVA do motor, "verificar se ja existe antes de
    criar" ao nivel do SQL). Corrige "index already exists" no 2o Sync quando a
    introspecao pragma_index_list falha em runtime (sqlite3.dll < 3.16). AddUniqueSQL
    passa a herdar essa idempotencia.
  - 1.4.0 (16/07/2026): Onda 5.5-B (ADITIVO) - scUnique nas capabilities;
    overrides AddUniqueSQL (delega a CreateIndexSQL, SQLite nao suporta
    ALTER TABLE ADD CONSTRAINT)/UniquesSQL/IndexesSQL via pragma_index_list.
  - 1.3.0 (15/07/2026): Onda 6-e Estagio 3 (I13, ADITIVO) - FunctionSQL
    override: SUBSTRING -> SUBSTR(x, p, n) (SQLite so tem SUBSTR nativo;
    LENGTH/UPPER/LOWER/COALESCE ja sao compativeis com a base ANSI).
  - 1.2.0 (14/07/2026): Onda 6-a (F5 revisao, modernizacao AQB/EMS - I23,
    ADITIVO) - capabilities ESTATICAS (SQLite nao expoe versao por conexao de
    forma pratica no ecossistema - fica sem overload de versao, decisao
    documentada): scWindowFunctions (3.25+)/scRecursiveCTE (3.8.3+, ja coberto
    por scCTE pre-existente)/scJSON (extensao JSON1)/scUpsert (3.24+, INSERT
    ... ON CONFLICT)/scFullText (modulo FTS5) ON - assume um SQLite moderno
    com as extensoes de compilacao PADRAO (JSON1/FTS5 vem compiladas por
    omissao nos binarios oficiais amalgamation desde ha varios anos).
    scMerge/scSequences/scArrays ficam OFF (sem equivalente nativo).
  - 1.1.0 (14/07/2026): Fatia B-e (continuacao Onda 4, revisao F5) - override
    de CreateDatabaseSQL/DropDatabaseSQL -> vazio (SQLite = banco-FICHEIRO,
    criado implicitamente na 1a conexao; sem DDL de criacao/remocao).
  - 1.0.0 (12/07/2026): versao inicial (Onda 5.2).
  ============================================================================= }
unit Database.Dialect.SQLite;

{$I ORM.Defines.inc}

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
  TDialectSQLite = class(TDialect)
  strict protected
    procedure Setup; override;
  public
    class function New: IDialect;
    function ColumnTypeFor(const AKind: TSQLColumnKind; const ASize: Integer = 0;
      const AScale: Integer = 0): string; override;
    function CreateDatabaseSQL(const AName: string): string; override;
    function DropDatabaseSQL(const AName: string): string; override;
    function FunctionSQL(const AName: string; const AArgs: array of string): string; override;
    function CreateIndexSQL(const ATable, AName: string;
      const AColumns: array of string; const AUnique: Boolean): string; override;
    function AddUniqueSQL(const ATable, AName: string;
      const AColumns: array of string): string; override;
    function UniquesSQL(const ATable, ASchema: string): string; override;
    function IndexesSQL(const ATable, ASchema: string): string; override;
    function ViewsSQL(const ASchema: string): string; override;
    function IdentityColumnsSQL(const ATableName, ASchema: string): string; override;
    { Onda D - COLUMN: SQLite NAO suporta ALTER COLUMN (mudar tipo) -> '' (o
      nivel usa o table-rebuild D.2). ADD/DROP (3.35+) e RENAME (3.25+) herdam
      a base (o sqlite3.dll canonico e 3.53.3). }
    function FieldAlterSQL(const ATable, AColumn, ANewType: string;
      const ANotNull: Boolean): string; override;
    { Onda D - SQLite: unique = indice -> DROP INDEX. }
    function UniqueDropSQL(const ATable, AName: string): string; override;
    { Onda D - SQLite nao tem CREATE OR REPLACE VIEW -> sempre CREATE VIEW. }
    function ViewCreateSQL(const AName, ASelectSQL: string; const AOrReplace: Boolean): string; override;
    { Onda F3 - triggers (single-event, corpo obrigatorio >=1 statement). }
    function TriggersSQL(const ASchema: string): string; override;
    function TriggerDefCreateSQL(const ADef: ITriggerDefinition): string; override;
    { Onda F5 (revisao facets) - SQLite NAO suporta ALTER TABLE ADD/DROP
      CONSTRAINT (so RENAME/ADD COLUMN/DROP COLUMN); PK/FK so no CREATE TABLE.
      Override -> '' (N/A explicito; ITable.Add/DropPrimaryKey|ForeignKey
      viram no-op/0, tal como FieldAlterSQL ja faz). }
    function PKeyAddSQL(const ATable, AName: string; const AColumns: array of string): string; override;
    function PKeyDropSQL(const ATable, AName: string): string; override;
    function FKeyAddSQL(const ATable, AName: string; const AColumns: array of string;
      const ARefTable: string; const ARefColumns: array of string;
      const AOnDelete, AOnUpdate: string): string; override;
    function FKeyDropSQL(const ATable, AName: string): string; override;
  end;

{$ENDIF}

implementation

{$IFDEF USE_DATABASE}

uses
{$IFDEF FPC}
  SysUtils; // SameText/Trim (Onda 6-e Estagio 3, I13 - corolario bug-315)
{$ELSE}
  System.SysUtils;
{$ENDIF}

class function TDialectSQLite.New: IDialect;
begin
  Result := TDialectSQLite.Create(dtSQLite);
end;

procedure TDialectSQLite.Setup;
begin
  FCapabilities := [scCTE, scDerivedTables, scUnion, scUnionAll, scReturning,
    scConcatPipes, scLimitOffset,
    { Onda 6-a (I23) - estaticas, assume SQLite moderno com JSON1/FTS5
      compiladas (padrao dos binarios oficiais); ver changelog do file. }
    scWindowFunctions, scRecursiveCTE, scJSON, scUpsert, scFullText,
    { Onda 5.5-B - todos os engines suportam unicidade. }
    scUnique];
  { Onda D - DDL: SQLite suporta drop-if-exists, drop/rename column (3.35+/3.25+;
    dll canonico e 3.53.3), rename table, FK (via PRAGMA), views, check; NAO tem
    alter-column (rebuild) nem procedures/functions em SQL. }
  FCapabilities := FCapabilities + [scDropIfExists, scDropColumn, scRenameColumn,
    scRenameTable, scForeignKeys, scViews, scCheck];
  FPagination := psLimitOffset;
  FMaxIdentLen := 0; // sem limite documentado
  FVersionText := 'SQLite';
end;

function TDialectSQLite.ColumnTypeFor(const AKind: TSQLColumnKind;
  const ASize: Integer; const AScale: Integer): string;
begin
  case AKind of
    ckBoolean:  Result := 'INTEGER';
    ckFloat:    Result := 'REAL';
    ckDateTime: Result := 'DATETIME';
    ckIdentity: Result := 'INTEGER PRIMARY KEY AUTOINCREMENT';
  else
    Result := inherited ColumnTypeFor(AKind, ASize, AScale);
  end;
end;

function TDialectSQLite.CreateDatabaseSQL(const AName: string): string;
begin
  { SQLite: banco = FICHEIRO, criado implicitamente na 1a conexao - sem DDL
    de criacao (Fatia B-e). }
  Result := '';
end;

function TDialectSQLite.DropDatabaseSQL(const AName: string): string;
begin
  { SQLite: apagar o banco = apagar o FICHEIRO (fora do dominio SQL) - sem
    DDL de remocao (Fatia B-e). }
  Result := '';
end;

function TDialectSQLite.FunctionSQL(const AName: string; const AArgs: array of string): string;
var
  I: Integer;
  LJoined: string;
begin
  { SQLite: so tem SUBSTR nativo (sem alias SUBSTRING); LENGTH/UPPER/LOWER/
    COALESCE ja sao compativeis com a base ANSI (Onda 6-e Estagio 3, I13). }
  if SameText(Trim(AName), 'SUBSTRING') then
  begin
    LJoined := '';
    for I := 0 to High(AArgs) do
    begin
      if LJoined <> '' then LJoined := LJoined + ', ';
      LJoined := LJoined + AArgs[I];
    end;
    Result := 'SUBSTR(' + LJoined + ')';
    Exit;
  end;
  Result := inherited FunctionSQL(AName, AArgs);
end;

function TDialectSQLite.CreateIndexSQL(const ATable, AName: string;
  const AColumns: array of string; const AUnique: Boolean): string;
var
  LCols: string;
begin
  { SQLite: CREATE [UNIQUE] INDEX IF NOT EXISTS - o proprio motor VERIFICA a
    existencia antes de criar (idempotencia NATIVA, valida em qualquer versao do
    SQLite desde 3.3). NAO depende da introspecao runtime pragma_index_list (que
    exige sqlite3.dll >= 3.16 - a table-valued function nao existe em DLLs
    antigas, a query lanca e o Metadata devolve [] -> UniqueExists=False -> o
    SchemaSync re-emitia -> "index ChaveUnica already exists"). Implementa o
    principio do owner "verificar se ja existe antes de criar" ao nivel do SQL
    (bug-574). Espelha a base TDialect.CreateIndexSQL + "IF NOT EXISTS". }
  Result := '';
  if (Trim(ATable) = '') or (Trim(AName) = '') then
    Exit;
  LCols := QuoteColumnList(AColumns);
  if LCols = '' then
    Exit;
  Result := 'CREATE ';
  if AUnique then
    Result := Result + 'UNIQUE ';
  Result := Result + 'INDEX IF NOT EXISTS ' + QuoteIdentifier(Trim(AName)) +
    ' ON ' + QuoteIdentifier(Trim(ATable)) + ' (' + LCols + ')';
end;

function TDialectSQLite.AddUniqueSQL(const ATable, AName: string;
  const AColumns: array of string): string;
begin
  { SQLite nao suporta ALTER TABLE ADD CONSTRAINT -> CREATE UNIQUE INDEX IF NOT
    EXISTS (via CreateIndexSQL - idempotencia nativa, bug-574). }
  Result := CreateIndexSQL(ATable, AName, AColumns, True);
end;

function TDialectSQLite.UniquesSQL(const ATable, ASchema: string): string;
var
  LTable: string;
begin
  Result := '';
  if Trim(ATable) = '' then
    Exit;
  LTable := StringReplace(Trim(ATable), '''', '''''', [rfReplaceAll]);
  Result := 'SELECT name FROM pragma_index_list(''' + LTable + ''') WHERE "unique" = 1';
end;

function TDialectSQLite.IndexesSQL(const ATable, ASchema: string): string;
var
  LTable: string;
begin
  Result := '';
  if Trim(ATable) = '' then
    Exit;
  LTable := StringReplace(Trim(ATable), '''', '''''', [rfReplaceAll]);
  Result := 'SELECT name FROM pragma_index_list(''' + LTable + ''')';
end;

function TDialectSQLite.ViewsSQL(const ASchema: string): string;
begin
  { SQLite: views no catalogo sqlite_master (sem information_schema). 1 coluna
    [0]=view name. ASchema ignorado (SQLite sem schemas). }
  Result := 'SELECT name FROM sqlite_master WHERE type = ''view''';
end;

function TDialectSQLite.TriggersSQL(const ASchema: string): string;
begin
  { SQLite: triggers no catalogo sqlite_master. 1 coluna [0]=trigger name.
    ASchema ignorado (SQLite sem schemas). }
  Result := 'SELECT name FROM sqlite_master WHERE type = ''trigger''';
end;

function TDialectSQLite.TriggerDefCreateSQL(const ADef: ITriggerDefinition): string;
var
  LName, LTable, LTiming, LEvent, LBody: string;
begin
  { SQLite: CREATE TRIGGER n [BEFORE|AFTER|INSTEAD OF] ev ON t [FOR EACH ROW]
    BEGIN stmt; END. UM evento por trigger (usa o primeiro); o corpo TEM de
    ter pelo menos um statement terminado por ';' -> vazio = SELECT NULL. }
  Result := '';
  if (ADef = nil) or (Trim(ADef.Name) = '') or (Trim(ADef.OnTable) = '') then
    Exit;
  LName  := QuoteIdentifier(Trim(ADef.Name));
  LTable := QuoteIdentifier(Trim(ADef.OnTable));
  LTiming := TriggerTimingWord(ADef.Timing);
  LEvent := TriggerFirstEventWord(ADef.Events);
  if ADef.BodyMode = tbmRaw then
    LBody := 'BEGIN ' + ADef.BodyText + ' END'
  else
    LBody := 'BEGIN SELECT NULL; END';
  Result := 'CREATE TRIGGER ' + LName + ' ' + LTiming + ' ' + LEvent +
    ' ON ' + LTable + ' FOR EACH ROW ' + LBody;
end;

function TDialectSQLite.IdentityColumnsSQL(const ATableName, ASchema: string): string;
begin
  { F5-FU.1 - SQLite: identity = INTEGER PRIMARY KEY implicito (rowid alias,
    ver ColumnTypeFor/ckIdentity acima); sem catalogo dedicado - limitacao
    documentada. }
  Result := '';
end;

function TDialectSQLite.FieldAlterSQL(const ATable, AColumn, ANewType: string;
  const ANotNull: Boolean): string;
begin
  { SQLite NAO tem ALTER COLUMN (mudar tipo) -> '' (o nivel/Synchronize aplica
    o table-rebuild D.2). }
  Result := '';
end;

function TDialectSQLite.UniqueDropSQL(const ATable, AName: string): string;
begin
  { SQLite: unique = indice -> DROP INDEX name. }
  Result := '';
  if Trim(AName) = '' then Exit;
  Result := 'DROP INDEX ' + QuoteIdentifier(Trim(AName));
end;

function TDialectSQLite.PKeyAddSQL(const ATable, AName: string; const AColumns: array of string): string;
begin
  { SQLite: PRIMARY KEY so no CREATE TABLE (sem ALTER ADD CONSTRAINT) -> N/A. }
  Result := '';
end;

function TDialectSQLite.PKeyDropSQL(const ATable, AName: string): string;
begin
  Result := '';
end;

function TDialectSQLite.FKeyAddSQL(const ATable, AName: string; const AColumns: array of string;
  const ARefTable: string; const ARefColumns: array of string;
  const AOnDelete, AOnUpdate: string): string;
begin
  { SQLite: FOREIGN KEY so no CREATE TABLE (sem ALTER ADD CONSTRAINT) -> N/A. }
  Result := '';
end;

function TDialectSQLite.FKeyDropSQL(const ATable, AName: string): string;
begin
  Result := '';
end;

function TDialectSQLite.ViewCreateSQL(const AName, ASelectSQL: string; const AOrReplace: Boolean): string;
begin
  { SQLite NAO tem CREATE OR REPLACE VIEW -> sempre CREATE VIEW (para "replace"
    o caller faz DROP VIEW IF EXISTS antes). }
  Result := '';
  if (Trim(AName) = '') or (Trim(ASelectSQL) = '') then Exit;
  Result := 'CREATE VIEW ' + QuoteIdentifier(Trim(AName)) + ' AS ' + ASelectSQL;
end;

{$ENDIF}

end.
