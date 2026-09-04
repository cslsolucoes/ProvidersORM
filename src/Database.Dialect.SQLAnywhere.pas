{ =============================================================================
  Database.Dialect.SQLAnywhere - Dialecto SQL Anywhere (TDialectSQLAnywhere)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.0.0
  FileVersion:    1.4.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           25/07/2026

  F5 Onda 10 (SQL Anywhere 17 - SAP/Sybase). Modelo copiado de
  Database.Dialect.PostgreSQL (schemas/aspas duplas), NAO de SQLServer
  (TOP/[]) - decisao do relatorio de entendimento (.workspace/reports/
  providersorm-v3-f5-entendimento-database-sqlanywhere-odbc_v1.0.md, decisao 7).

  Capabilities CONSERVADORAS de proposito (risco documentado no relatorio,
  secao 8: "capabilities optimistas (RETURNING/JSON) - ligar so o que for
  testado"): scSchemas/scCTE/scIdentity/scUnique confirmados por conhecimento
  de dominio do motor; scUpsert/scJSON/scMerge/scWindowFunctions/
  scRecursiveCTE/scFullText/scArrays/scSequences ficam OFF ate validacao
  empirica contra um SQL Anywhere 17 real (nao fazem parte do MVP da Onda 10).

  Paginacao CONFIRMADA EMPIRICAMENTE (16/07, dbisql contra servidor real,
  10.0.74.3:2638): 'SELECT ... LIMIT n OFFSET m' -> SQLCODE=-131 (syntax
  error); 'SELECT TOP n START AT m ...' -> funciona. psTopStartAt (novo,
  Commons.Database.Types 1.10.0) - distinto do psTop do SQLServer (TOP puro,
  SEM offset).

  Boolean: SQL Anywhere NAO tem tipo BOOLEAN nativo - usa BIT (0/1); por isso
  scBoolean fica OFF (a flag significa "tipo booleano nativo", nao "coluna
  0/1") e ColumnTypeFor(ckBoolean) mapeia para 'BIT' via override.

  Identity: 'DEFAULT AUTOINCREMENT' (sintaxe classica SQL Anywhere) - Zeos/
  FireDAC/UniDAC nativos (dbcapi.dll) confirmam via spike_sqlanywhere*.dpr.

  Changelog (file):
  - 1.4.0 (26/07/2026): conformidade F5 (onda C3, M6) - par capability-chamada de
    procedures corrigido: Setup passa a setar scStoredProcedures/scUserFunctions
    (a introspeccao SYS.SYSPROCEDURE ja estava validada por sonda) + novo override
    CallProcedureSQL = CALL "proc"(:p0, ...) (formato PostgreSQL; nome vazio -> '').
    Antes a introspeccao "via" procedures mas IQueryBuilder.CallProcedure ficava
    sem efeito (par incoerente). FunctionSQL fica na BASE ANSI (LENGTH/SUBSTRING/
    COALESCE validos em SA); ColumnDescriptionSQL fica '' (SA tem comentarios em
    SYS.SYSCOLUMN.remarks mas nao validado por sonda - N/A documentado). ASchema
    mantido em owner corrente (validado por sonda; filtro cross-owner adiado para
    validacao multi-owner real). smoke_dialects +3 goldens SA. ModuleVersion 3.0.0.
  - 1.3.0 (25/07/2026): F5-FU.1 (populacao de IsIdentity por dialecto, ADITIVO) -
    IdentityColumnsSQL override -> '' com TODO documentado (SYS.SYSCOLUMN
    "default"='autoincrement' nao validado empiricamente contra servidor real -
    principio do owner "nao adivinhar SQL que rebente"; override explicito so
    para documentar a limitacao no proprio ficheiro - o resultado efectivo e
    identico ao da BASE ate uma onda futura confirmar a sintaxe exacta, mesmo
    padrao conservador do resto do ficheiro).
  - 1.2.0 (18/07/2026): Onda D (API-B) - IndexesSQL override (SYS.SYSIDX/SYS.SYSTAB,
    lista todos os index_name da tabela). A base devolvia '' -> IndexExists ficava
    conservador (TRUE), o que fazia o ITable.AddIndex saltar (nunca criar) e o
    DropIndex falhar ("Cannot find index"). Agora IndexExists e preciso no SA. (bug-593)
  - 1.1.0 (18/07/2026): Onda D (manipulacao DDL, validado contra SQL Anywhere 17
    real + docs SQL Reference oficiais). Overrides de faceta: FieldAddSQL/
    FieldAlterSQL/FieldDropSQL (ADD/ALTER/DROP de coluna SEM a keyword 'COLUMN';
    ALTER sem 'TYPE'); FieldRenameSQL ('RENAME old TO new' - sem 'COLUMN', com
    'TO'); TableRenameSQL ('RENAME newname' - SEM 'TO'). UNIQUE: AddUniqueSQL ->
    CREATE UNIQUE INDEX (a UNIQUE CONSTRAINT do SA exige NOT NULL; o UNIQUE INDEX
    permite NULL) + UniqueDropSQL -> DROP INDEX (coerente) + UniquesSQL reescrito
    para o catalogo SYS.SYSIDX/SYS.SYSTAB ("unique" IN (1,2,5)) em vez do
    information_schema (que nao lista o unique index). scRenameTable adicionada as
    capabilities. (bug-577)
  - 1.0.0 (16/07/2026): versao inicial (F5 Onda 10, sub-passo 10.c).
  ============================================================================= }
unit Database.Dialect.SQLAnywhere;

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
  TDialectSQLAnywhere = class(TDialect)
  strict private
    FMajorVersion: Integer;
  strict protected
    procedure Setup; override;
  public
    class function New: IDialect; overload;
    { Version-aware (decisao 6 do relatorio): New(17) = default "SQL Anywhere
      17"; a estrutura fica pronta para versoes futuras (18+) mesmo sem
      capabilities version-gated ainda (nenhuma confirmada empiricamente). }
    class function New(const AMajorVersion: Integer): IDialect; overload;
    function ServerVersionMajor(out AMajor: Integer): Boolean;
    function ColumnTypeFor(const AKind: TSQLColumnKind; const ASize: Integer = 0;
      const AScale: Integer = 0): string; override;
    { Onda D - SQL Anywhere: sintaxe DDL propria (SQL Reference oficial). ADD/
      ALTER/DROP/RENAME de coluna SEM a keyword 'COLUMN' (ALTER e sem 'TYPE');
      RENAME de tabela SEM a keyword 'TO'. }
    function FieldAddSQL(const ATable, AField, AFieldType: string;
      const ANotNull: Boolean): string; override;
    function FieldAlterSQL(const ATable, AField, ANewType: string;
      const ANotNull: Boolean): string; override;
    function FieldDropSQL(const ATable, AField: string): string; override;
    function FieldRenameSQL(const ATable, AOldName, ANewName: string): string; override;
    function TableRenameSQL(const AOldName, ANewName: string): string; override;
    { Onda D - UNIQUE via CREATE UNIQUE INDEX: a UNIQUE CONSTRAINT do SA exige
      colunas NOT NULL (SQL Reference); o UNIQUE INDEX permite NULL. }
    function AddUniqueSQL(const ATable, AName: string;
      const AColumns: array of string): string; override;
    function UniqueDropSQL(const ATable, AName: string): string; override;
    function UniquesSQL(const ATable, ASchema: string): string; override;
    function IndexesSQL(const ATable, ASchema: string): string; override;
    function ViewsSQL(const ASchema: string): string; override;
    function ProceduresSQL(const ASchema: string): string; override;
    { M6 (conformidade F5 C3): SQL Anywhere usa CALL "proc"(args) - override para
      o par capability<->chamada ficar coerente (scStoredProcedures no Setup). }
    function CallProcedureSQL(const AProcName: string; const AArgCount: Integer): string; override;
    function IdentityColumnsSQL(const ATableName, ASchema: string): string; override;
    { Onda F1 - builder de rotinas (procedure/function parentizados; function
      RETURNS t BEGIN RETURN expr END - Watcom SQL, sem 'AS'). }
    function RoutineDefCreateSQL(const ADef: IRoutineDefinition): string; override;
    { Onda F3 - triggers (multi-evento por virgula, FOR EACH ROW; SYS.SYSTRIGGER).
      DROP herda a base (SA 12+ suporta DROP TRIGGER IF EXISTS n, scDropIfExists). }
    function TriggersSQL(const ASchema: string): string; override;
    function TriggerDefCreateSQL(const ADef: ITriggerDefinition): string; override;
  end;

{$ENDIF}

implementation

{$IFDEF USE_DATABASE}

class function TDialectSQLAnywhere.New: IDialect;
begin
  Result := TDialectSQLAnywhere.New(17); // SQL Anywhere 17 - default do lab (F5 Onda 10)
end;

class function TDialectSQLAnywhere.New(const AMajorVersion: Integer): IDialect;
var
  LDialect: TDialectSQLAnywhere;
begin
  LDialect := TDialectSQLAnywhere.Create(dtSQLAnywhere);
  LDialect.FMajorVersion := AMajorVersion;
  LDialect.Setup; // re-executa com a versao definida
  Result := LDialect;
end;

function TDialectSQLAnywhere.ServerVersionMajor(out AMajor: Integer): Boolean;
begin
  AMajor := FMajorVersion;
  Result := FMajorVersion > 0;
end;

procedure TDialectSQLAnywhere.Setup;
begin
  { Conservador de proposito - ver comentario de topo do ficheiro. }
  FCapabilities := [scDerivedTables, scUnion, scUnionAll, scSchemas, scCTE,
    scIdentity, scUnique];
  { Onda D - DDL (validado contra SQL Anywhere 17 real, docs SQL Reference):
    drop-if-exists, alter/drop/rename column, rename table, FK, views, check. }
  { M6 (conformidade F5 C3): SQL Anywhere suporta stored procedures E funcoes (a
    introspeccao SYS.SYSPROCEDURE ja estava validada por sonda) - as capabilities
    scStoredProcedures/scUserFunctions faltavam, deixando IQueryBuilder.CallProcedure
    sem efeito (par capability-chamada incoerente). Corrigido: capabilities +
    override de CallProcedureSQL (abaixo). }
  FCapabilities := FCapabilities + [scDropIfExists, scAlterColumn, scDropColumn,
    scRenameColumn, scRenameTable, scForeignKeys, scViews, scCheck,
    scStoredProcedures, scUserFunctions];
  FPagination := psTopStartAt;
  FMaxIdentLen := 128; // limite de identificador documentado do SQL Anywhere
  if FMajorVersion > 0 then
    FVersionText := Format('SQL Anywhere %d', [FMajorVersion])
  else
    FVersionText := 'SQL Anywhere';
end;

function TDialectSQLAnywhere.ColumnTypeFor(const AKind: TSQLColumnKind;
  const ASize: Integer; const AScale: Integer): string;
begin
  case AKind of
    ckBoolean:  Result := 'BIT'; // SQL Anywhere NAO tem BOOLEAN nativo
    ckIdentity: Result := 'INTEGER DEFAULT AUTOINCREMENT';
  else
    Result := inherited ColumnTypeFor(AKind, ASize, AScale);
  end;
end;

function TDialectSQLAnywhere.RoutineDefCreateSQL(const ADef: IRoutineDefinition): string;
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
  { SQL Anywhere (Watcom SQL): procedure -> (params) BEGIN..END; function ->
    (params) RETURNS t BEGIN RETURN expr END (sem 'AS'). Parametros sempre
    parentizados; direccao IN/OUT/INOUT antes do nome. Tipo via ColumnTypeFor. }
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
      rbmReturn: LBody := 'BEGIN RETURN ' + ADef.BodyText + ' END';
    else
      LBody := 'BEGIN RETURN NULL END';
    end;
    Result := 'CREATE FUNCTION ' + LName + '(' + LParams + ') RETURNS ' + LType + ' ' + LBody;
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

function TDialectSQLAnywhere.FieldAddSQL(const ATable, AField, AFieldType: string;
  const ANotNull: Boolean): string;
begin
  { SQL Anywhere: 'ALTER TABLE t ADD col type' - SEM a keyword 'COLUMN' (SQL
    Reference: ADD column-name column-data-type). }
  Result := '';
  if (Trim(ATable) = '') or (Trim(AField) = '') then Exit;
  Result := 'ALTER TABLE ' + QuoteIdentifier(Trim(ATable)) + ' ADD ' +
    QuoteIdentifier(Trim(AField)) + ' ' + AFieldType;
  { bug-1172 (02/09/2026) - NULIDADE EXPLICITA, obrigatoria no SQL Anywhere.
    Ao contrario do padrao SQL (e de PostgreSQL/MySQL/Firebird), o SQL Anywhere
    cria a coluna NOT NULL quando o ALTER TABLE ... ADD NAO declara nulidade.
    Como este metodo so acrescentava " NOT NULL" quando ANotNull=True, TODA a
    coluna NULLABLE acrescentada por merge/sync nascia NOT NULL no SA, e o
    primeiro INSERT que a omitisse falhava com
      "SQL Anywhere Error -195: Column 'x' in table 'y' cannot be NULL".
    Provado por spike Zeos CRU, sem units do projecto (tests/
    spike_bug1172_sa_addcolumn_null.dpr), com uma tabela isolada por cenario:
      A) ADD col INTEGER            -> INSERT que omite a coluna FALHA (-195)
      B) ADD col INTEGER NULL       -> INSERT que omite a coluna PASSA
      C) ADD col INTEGER NOT NULL   -> FALHA (controlo negativo)
    Sintoma no produto: test_serialize x sqlanywhere (coluna "preco",
    NUMERIC(18,4), acrescentada no merge) - 4 celulas da matriz F5.
    NOTA (nao alterado aqui, por nao estar provado): FieldAlterSQL ignora
    completamente ANotNull - nao emite NULL nem NOT NULL. Fica por verificar
    se um ALTER de tipo preserva ou repoe a nulidade no SA. }
  if ANotNull then
    Result := Result + ' NOT NULL'
  else
    Result := Result + ' NULL';
end;

function TDialectSQLAnywhere.FieldAlterSQL(const ATable, AField, ANewType: string;
  const ANotNull: Boolean): string;
begin
  { SQL Anywhere: 'ALTER TABLE t ALTER col newtype' - SEM 'COLUMN' e SEM 'TYPE'
    (SQL Reference: ALTER column-name column-data-type). }
  Result := '';
  if (Trim(ATable) = '') or (Trim(AField) = '') then Exit;
  Result := 'ALTER TABLE ' + QuoteIdentifier(Trim(ATable)) + ' ALTER ' +
    QuoteIdentifier(Trim(AField)) + ' ' + ANewType;
end;

function TDialectSQLAnywhere.FieldDropSQL(const ATable, AField: string): string;
begin
  { SQL Anywhere: 'ALTER TABLE t DROP col' - SEM a keyword 'COLUMN'. }
  Result := '';
  if (Trim(ATable) = '') or (Trim(AField) = '') then Exit;
  Result := 'ALTER TABLE ' + QuoteIdentifier(Trim(ATable)) + ' DROP ' +
    QuoteIdentifier(Trim(AField));
end;

function TDialectSQLAnywhere.FieldRenameSQL(const ATable, AOldName, ANewName: string): string;
begin
  { SQL Anywhere: 'ALTER TABLE t RENAME old TO new' - SEM 'COLUMN', COM 'TO'. }
  Result := '';
  if (Trim(ATable) = '') or (Trim(AOldName) = '') or (Trim(ANewName) = '') then Exit;
  Result := 'ALTER TABLE ' + QuoteIdentifier(Trim(ATable)) + ' RENAME ' +
    QuoteIdentifier(Trim(AOldName)) + ' TO ' + QuoteIdentifier(Trim(ANewName));
end;

function TDialectSQLAnywhere.TableRenameSQL(const AOldName, ANewName: string): string;
begin
  { SQL Anywhere: 'ALTER TABLE t RENAME newname' - SEM a keyword 'TO'. }
  Result := '';
  if (Trim(AOldName) = '') or (Trim(ANewName) = '') then Exit;
  Result := 'ALTER TABLE ' + QuoteIdentifier(Trim(AOldName)) + ' RENAME ' +
    QuoteIdentifier(Trim(ANewName));
end;

function TDialectSQLAnywhere.AddUniqueSQL(const ATable, AName: string;
  const AColumns: array of string): string;
begin
  { SQL Anywhere: uma UNIQUE CONSTRAINT exige colunas NOT NULL (SQL Reference:
    "columns in a unique constraint are not allowed to be NULL"); um UNIQUE INDEX
    permite NULL. Para homogeneidade com os restantes dialetos (que aceitam UNIQUE
    em coluna nullable), mapeia-se 'unique' para CREATE UNIQUE INDEX. }
  Result := CreateIndexSQL(ATable, AName, AColumns, True);
end;

function TDialectSQLAnywhere.UniqueDropSQL(const ATable, AName: string): string;
begin
  { Coerente com AddUniqueSQL (unique = INDEX): 'DROP INDEX name' (SQL Anywhere
    aceita so o nome, sem 'ON table'). }
  Result := IndexDropSQL(ATable, AName);
end;

function TDialectSQLAnywhere.UniquesSQL(const ATable, ASchema: string): string;
begin
  { SQL Anywhere - catalogo de sistema (SQL Reference, SYS.SYSIDX/SYS.SYSTAB;
    prefixo SYS. como no GetColumnNames da conexao): lista os indices UNIQUE da
    tabela - coluna "unique" IN (1=unique index, 2=unique constraint, 5=unique
    index WITH NULLS NOT DISTINCT). Cobre tanto a UNIQUE CONSTRAINT como o UNIQUE
    INDEX que AddUniqueSQL cria. 1 coluna [0]=index_name. ASchema ignorado
    (owner corrente - mesma semantica dos restantes metodos SA). }
  Result := '';
  if Trim(ATable) = '' then Exit;
  Result := 'SELECT i.index_name FROM SYS.SYSIDX i' +
    ' JOIN SYS.SYSTAB t ON i.table_id = t.table_id' +
    ' WHERE t.table_name = ''' +
    StringReplace(Trim(ATable), '''', '''''', [rfReplaceAll]) +
    ''' AND i."unique" IN (1, 2, 5)';
end;

function TDialectSQLAnywhere.IndexesSQL(const ATable, ASchema: string): string;
begin
  { SQL Anywhere - catalogo de sistema (SYS.SYSIDX/SYS.SYSTAB): lista TODOS os
    indices da tabela (index_name), para IndexExists ser preciso (a base devolve
    '' -> conservador, quebrava a idempotencia do AddIndex/DropIndex). 1 coluna
    [0]=index_name. }
  Result := '';
  if Trim(ATable) = '' then Exit;
  Result := 'SELECT i.index_name FROM SYS.SYSIDX i' +
    ' JOIN SYS.SYSTAB t ON i.table_id = t.table_id' +
    ' WHERE t.table_name = ''' +
    StringReplace(Trim(ATable), '''', '''''', [rfReplaceAll]) + '''';
end;

function TDialectSQLAnywhere.ViewsSQL(const ASchema: string): string;
begin
  { SQL Anywhere: catalogo compat SYS.SYSTABLE (table_type STRING: 'BASE'/
    'VIEW'; creator > 0 filtra o sistema) - o MESMO catalogo comprovado do
    fallback de GetTableNamesFromDriver. NOTA (Fase 1 repasse): o "devolveu
    vazio" anterior NAO era a query - era o TZQuery editavel do ExecuteQuery
    generico a falhar nas sp_jdbc_* (erro engolido -> []); com o SELECT do SA
    delegado ao TZReadOnlyQuery (Connections.ExecuteQuery) o catalogo responde. }
  Result := 'SELECT table_name FROM SYS.SYSTABLE WHERE table_type = ''VIEW'' AND creator > 0';
end;

function TDialectSQLAnywhere.ProceduresSQL(const ASchema: string): string;
begin
  { SQL Anywhere: catalogo dedicado SYS.SYSPROCEDURE (coluna proc_name). 1 coluna
    [0]=proc_name. ASchema ignorado (lista todas; ProcedureExists filtra por
    SameText). Habilita idempotencia do API-B de procedures no SA. }
  Result := 'SELECT proc_name FROM SYS.SYSPROCEDURE';
end;

function TDialectSQLAnywhere.TriggersSQL(const ASchema: string): string;
begin
  { SQL Anywhere: SYS.SYSTRIGGER (coluna trigger_name). Os triggers de
    integridade referencial (FK) tem trigger_name NULL -> filtra. 1 coluna
    [0]=trigger_name. ASchema ignorado (TriggerExists filtra por SameText). }
  Result := 'SELECT trigger_name FROM SYS.SYSTRIGGER WHERE trigger_name IS NOT NULL';
end;

function TDialectSQLAnywhere.TriggerDefCreateSQL(const ADef: ITriggerDefinition): string;
var
  LName, LTable, LTiming, LEvents, LRow, LBody: string;
begin
  { SQL Anywhere: CREATE TRIGGER n [BEFORE|AFTER|INSTEAD OF] ev [, ev...] ON t
    [FOR EACH ROW|STATEMENT] compound-statement. Corpo vazio (Watcom-SQL) =
    BEGIN DECLARE dummy INT; SET dummy = 0 END (bloco valido sem efeito). }
  Result := '';
  if (ADef = nil) or (Trim(ADef.Name) = '') or (Trim(ADef.OnTable) = '') then
    Exit;
  LName  := QuoteIdentifier(Trim(ADef.Name));
  LTable := QuoteIdentifier(Trim(ADef.OnTable));
  LTiming := TriggerTimingWord(ADef.Timing);
  LEvents := TriggerEventsClause(ADef.Events, ', ');
  if ADef.ForEachRow then
    LRow := ' FOR EACH ROW'
  else
    LRow := ' FOR EACH STATEMENT';
  if ADef.BodyMode = tbmRaw then
    LBody := 'BEGIN ' + ADef.BodyText + ' END'
  else
    LBody := 'BEGIN DECLARE dummy INT; SET dummy = 0 END';
  Result := 'CREATE TRIGGER ' + LName + ' ' + LTiming + ' ' + LEvents +
    ' ON ' + LTable + LRow + ' ' + LBody;
end;

function TDialectSQLAnywhere.CallProcedureSQL(const AProcName: string;
  const AArgCount: Integer): string;
var
  I: Integer;
  LArgs: string;
begin
  { SQL Anywhere: CALL "proc"(:p0, :p1, ...) - sintaxe CALL com parenteses (SQL
    Reference); AProcName vazio -> '' (M6, conformidade F5 C3). O QueryBuilder
    substitui os :pN posicionais via BuildCallSQL. Mesmo formato do PostgreSQL. }
  if Trim(AProcName) = '' then
    Exit('');
  LArgs := '';
  for I := 0 to AArgCount - 1 do
  begin
    if I > 0 then
      LArgs := LArgs + ', ';
    LArgs := LArgs + ':p' + IntToStr(I);
  end;
  Result := 'CALL ' + QuoteIdentifier(AProcName) + '(' + LArgs + ')';
end;

function TDialectSQLAnywhere.IdentityColumnsSQL(const ATableName, ASchema: string): string;
begin
  { F5-FU.1 - TODO: SQL Anywhere marca colunas 'DEFAULT AUTOINCREMENT' no
    catalogo SYS.SYSCOLUMN (coluna "default" - documentacao SQL Reference
    indica o literal 'autoincrement', mas o formato exato (case/whitespace/
    presenca de outros defaults compostos) NAO foi validado contra um servidor
    real (ao contrario de UniquesSQL/IndexesSQL/ViewsSQL/ProceduresSQL acima,
    todos confirmados por sonda - ver changelog do file). Por principio do
    owner ("nao adivinhar SQL que rebente"), fica '' ate validacao empirica
    (mesmo padrao conservador documentado no cabecalho do ficheiro, secao
    "Capabilities CONSERVADORAS de proposito"); limitacao documentada. }
  Result := '';
end;

{$ENDIF}

end.
