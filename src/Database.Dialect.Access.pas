{ =============================================================================
  Database.Dialect.Access - Dialecto MS Access Jet/ACE (TDialectAccess)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.3.1
  FileVersion:    1.7.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           30/07/2026

  Onda 5.2: [quoting]; & para concatenacao; YESNO/COUNTER (sintaxe Jet);
  TOP (unica paginacao - sem OFFSET); sem CTE/RETURNING.

  Changelog (file):
  - 1.7.0 (30/07/2026): auditoria adversarial ao ApplyStructure (fix #2) -
    ColumnTypeFor ganha o caso ckDecimal -> 'NUMERIC' (bare, sem parenteses).
    Achado REAL contra o servidor Access real (sonda dedicada): o driver ODBC
    "Microsoft Access Driver" rejeita a palavra 'DECIMAL' em qualquer forma
    (mesmo bare) e rejeita 'NUMERIC(p,s)' COM escala em CREATE/ALTER TABLE -
    so' 'NUMERIC' bare e' aceite. Sem este fix, a materializacao de uma coluna
    NUMERIC/DECIMAL com escala (nova nesta onda - SchemaAddTableToDefinition
    passa a repassar Precision/Scale reais) abortava TODO o TSynchronize.Sync
    (transaccional) contra Access com "Syntax error in field definition",
    levando embora tambem outras alteracoes na MESMA chamada (ex.: CREATE
    TABLE de uma tabela nova sem qualquer relacao com o campo decimal).
    Ver tambem Database.Schema.pas 1.10.0 (isolamento por-passo do
    ApplyStructure) e test_serialize.dpr (coluna DEC_COL). Gate: sonda
    isolada (4 variantes DDL) + test_serialize access-share 0 FAIL.
  - 1.6.0 (25/07/2026): F5-FU.1 (populacao de IsIdentity por dialecto, ADITIVO) -
    IdentityColumnsSQL override -> '' (MSysObjects protegido, mesma limitacao
    conhecida de UniquesSQL/ViewsSQL - introspecao de coluna COUNTER nao
    fiavel; documentado no proprio metodo).
  - 1.5.0 (17/07/2026): Onda 10-D (marshalling de VALOR cross-DB, ADITIVO) -
    EncodeBoolean override: YES/NO = -1 (True) / 0 (False), o True canonico do
    Jet/ACE (a base scBoolean-derivada daria 0/1). Consumido por QueryBuilder.Bind.
  - 1.4.0 (16/07/2026): Onda 5.5-B (ADITIVO) - scUnique adicionado as
    capabilities; AddUniqueSQL override -> CREATE UNIQUE INDEX (ADD
    CONSTRAINT UNIQUE nao e fiavel em Jet/ACE); UniquesSQL override -> ''
    (MSysObjects protegido, introspecao nao fiavel).
  - 1.3.0 (15/07/2026): Onda 6-e Estagio 3 (I13, ADITIVO) - FunctionSQL
    override: UPPER->UCASE, LOWER->LCASE, LENGTH->LEN, SUBSTRING->MID
    (mesma semantica posicional x,p[,n]) - sintaxe Jet/ACE; COALESCE(a,b,...)
    -> NZ(...) aninhado (Jet/ACE nao tem COALESCE nativo; Nz(valor,default)
    so aceita 2 argumentos, por isso o encadeamento).
  - 1.2.0 (14/07/2026): Onda 6-a (F5 revisao, modernizacao AQB/EMS, ADITIVO) -
    I21: DateLiteral/TimestampLiteral override - delimitador #...# (Jet/ACE
    exige #aaaa-mm-dd#/#aaaa-mm-dd hh:nn:ss#, NAO aspas simples); precisou de
    SysUtils/System.SysUtils no uses da implementation (FormatDateTime, nunca
    chamado directamente por esta unit antes - corolario bug-315). I23: SEM
    novas capabilities ON - Jet/ACE nao tem CTE recursivo, window functions,
    JSON nativo, upsert de 1 statement, MERGE, SEQUENCE autonomo, ARRAY nem
    full-text SQL-padrao; todos os 8 flags novos ficam OFF por omissao (set
    of - nao precisam de codigo), documentado aqui por completude do I23.
  - 1.1.0 (14/07/2026): Fatia B-e (continuacao Onda 4, revisao F5) - override
    de CreateDatabaseSQL/DropDatabaseSQL -> vazio (Access = banco-FICHEIRO
    .mdb/.accdb, criado por API propria/template, nao por DDL SQL).
  - 1.0.0 (12/07/2026): versao inicial (Onda 5.2).
  ============================================================================= }
unit Database.Dialect.Access;

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
  TDialectAccess = class(TDialect)
  strict protected
    procedure Setup; override;
  public
    class function New: IDialect;
    function ColumnTypeFor(const AKind: TSQLColumnKind; const ASize: Integer = 0;
      const AScale: Integer = 0): string; override;
    function EncodeBoolean(const AValue: Boolean): Variant; override;
    function EncodeDateTime(const AValue: TDateTime): Variant; override;
    function CreateDatabaseSQL(const AName: string): string; override;
    function DropDatabaseSQL(const AName: string): string; override;
    function DateLiteral(const ADate: TDateTime): string; override;
    function TimestampLiteral(const ADateTime: TDateTime): string; override;
    function FunctionSQL(const AName: string; const AArgs: array of string): string; override;
    function AddUniqueSQL(const ATable, AName: string;
      const AColumns: array of string): string; override;
    function UniquesSQL(const ATable, ASchema: string): string; override;
    { Onda D / matriz Access - DDL Jet/ACE:
      - FieldAlterSQL: Jet usa 'ALTER COLUMN col <tipo>' (SEM a palavra 'TYPE').
      - FieldRenameSQL: Jet SQL NAO tem RENAME COLUMN -> '' (N/A; so via DAO/ADOX).
      - IndexDropSQL: Jet exige 'DROP INDEX name ON tabela'.
      - TableRenameSQL: Jet SQL NAO tem RENAME TABLE -> '' (N/A; so via DAO/SELECT INTO).
      - ViewCreateSQL: Jet nao tem CREATE OR REPLACE VIEW -> sempre 'CREATE VIEW'. }
    function FieldAlterSQL(const ATable, AColumn, ANewType: string;
      const ANotNull: Boolean): string; override;
    function FieldRenameSQL(const ATable, AOldName, ANewName: string): string; override;
    function IndexDropSQL(const ATable, AName: string): string; override;
    function TableRenameSQL(const AOldName, ANewName: string): string; override;
    function ViewCreateSQL(const AName, ASelectSQL: string; const AOrReplace: Boolean): string; override;
    { Jet/ACE: information_schema nao existe e MSysObjects e protegido -> sem
      introspecao fiavel de views -> '' (o consumidor degrada: ViewExists=False,
      o smoke salta a asercao). }
    function ViewsSQL(const ASchema: string): string; override;
    function IdentityColumnsSQL(const ATableName, ASchema: string): string; override;
  end;

{$ENDIF}

implementation

{$IFDEF USE_DATABASE}

class function TDialectAccess.New: IDialect;
begin
  Result := TDialectAccess.Create(dtAccess);
end;

procedure TDialectAccess.Setup;
begin
  { Onda 6-a (I23): Jet/ACE nao suporta nenhum dos 8 flags novos (scRecursiveCTE/
    scWindowFunctions/scMerge/scUpsert/scSequences/scArrays/scJSON/scFullText) -
    ficam OFF por omissao (set of - nao entram no literal). }
  FCapabilities := [scDerivedTables, scUnion, scUnionAll, scTop];
  { Todos os engines suportam unicidade (Onda 5.5-B). }
  FCapabilities := FCapabilities + [scUnique];
  { Onda D - DDL (best-effort, Jet/ACE): FK e views (queries) + ALTER/DROP column
    (Jet suporta ALTER TABLE ALTER/DROP COLUMN). NAO tem: DROP..IF EXISTS, RENAME
    COLUMN/TABLE (so via DAO/ADOX), procedures/functions SQL. }
  FCapabilities := FCapabilities + [scForeignKeys, scViews, scAlterColumn, scDropColumn];
  FPagination := psTop;
  FMaxIdentLen := 64;
  FVersionText := 'Access (Jet/ACE)';
  DefineOperator(SQLOP_CONCAT, '', ' & ', '', '', 2);
end;

function TDialectAccess.ColumnTypeFor(const AKind: TSQLColumnKind;
  const ASize: Integer; const AScale: Integer): string;
begin
  case AKind of
    ckBoolean:  Result := 'YESNO';
    ckFloat:    Result := 'DOUBLE';
    ckText:     Result := 'LONGTEXT';
    ckDateTime: Result := 'DATETIME';
    ckBlob:     Result := 'LONGBINARY';
    ckIdentity: Result := 'COUNTER';
    { Jet/ACE nao tem BIGINT (o .mdb Jet 4.0 nao suporta INT64 nativo) -> DECIMAL
      de precisao 20 (aproxima o alcance de um int de 64 bits). }
    ckBigInt:   Result := 'DECIMAL(20, 0)';
    { fix #2 (auditoria adversarial ao ApplyStructure) - achado REAL contra o
      servidor Access real (sonda dedicada, ver test_serialize.dpr): o driver
      ODBC "Microsoft Access Driver" usado neste ambiente rejeita a palavra
      'DECIMAL' em QUALQUER forma - mesmo BARE, sem parenteses ("Syntax error in
      field definition") - e rejeita 'NUMERIC(p,s)' COM parenteses/escala, tanto
      em CREATE TABLE como em ALTER TABLE ADD COLUMN ("Syntax error in [CREATE
      TABLE/ALTER TABLE] statement"); so' a forma BARE 'NUMERIC' (sem parenteses)
      e' aceite nos 2 contextos. Antes deste fix, ASize/AScale nunca eram
      passados > 0 por nenhum caminho do modulo (SchemaAddTableToDefinition so'
      passou a repassar Precision/Scale reais nesta mesma onda - ver
      Database.Schema.SchemaAddTableToDefinition) - por isso este gap NUNCA se
      manifestara antes. Degrada para o tipo BARE (mesmo principio dos overrides
      acima, ex.: ckBoolean/ckFloat) - a escala fica sob gestao INTERNA do
      proprio motor Jet (Access atribui Precision=18/Scale=0 por omissao a um
      campo Numeric sem parametros explicitos), nao expressavel via este driver
      ODBC especifico; ICatalogReader.TableStructure deste motor tambem nao a
      reporta (ver Skip honesto em VerifyMergedObjects, test_serialize.dpr). }
    ckDecimal:  Result := 'NUMERIC';
  else
    Result := inherited ColumnTypeFor(AKind, ASize, AScale);
  end;
end;

function TDialectAccess.EncodeBoolean(const AValue: Boolean): Variant;
begin
  { Access (Jet/ACE) via bind ADO (Zeos): a coluna YES/NO aceita INTEIRO
    (-1=True/0=False, o True canonico do Jet) e REJEITA varBoolean e string -
    "Data type mismatch in criteria expression". PROVADO POR SONDA 19/07
    (probe_access: Boolean=FAIL, Integer -1/0=OK) - corrige a versao anterior
    (1.5.0) que devolvia o Boolean cru e nunca tinha sido validada no caminho
    BINDADO real. }
  if AValue then
    Result := -1
  else
    Result := 0;
end;

function TDialectAccess.EncodeDateTime(const AValue: TDateTime): Variant;
begin
  { Access (Jet/ACE) via bind ADO (Zeos): DATETIME REJEITA varDate e Double no
    parametro ("Data type mismatch") e ACEITA string - provado por sonda 19/07
    (probe_access: TDateTime/Double=FAIL, 'yyyy-mm-dd hh:nn:ss'=OK; o Jet faz a
    coercao da string). Mesmo racional do DateLiteral #...# (I21), aqui na via
    bindada. }
  Result := FormatDateTime('yyyy-mm-dd hh:nn:ss', AValue);
end;

function TDialectAccess.CreateDatabaseSQL(const AName: string): string;
begin
  { Access: banco = FICHEIRO .mdb/.accdb, criado por API/template proprio
    (nao por DDL SQL) - sem DDL de criacao (Fatia B-e). }
  Result := '';
end;

function TDialectAccess.DropDatabaseSQL(const AName: string): string;
begin
  { Access: apagar o banco = apagar o FICHEIRO (fora do dominio SQL) - sem
    DDL de remocao (Fatia B-e). }
  Result := '';
end;

function TDialectAccess.DateLiteral(const ADate: TDateTime): string;
begin
  { Access (Jet/ACE): delimitador PROPRIO #...#, NAO aspas simples (Onda 6-a,
    I21). }
  Result := '#' + FormatDateTime('yyyy-mm-dd', ADate) + '#';
end;

function TDialectAccess.TimestampLiteral(const ADateTime: TDateTime): string;
begin
  Result := '#' + FormatDateTime('yyyy-mm-dd hh:nn:ss', ADateTime) + '#';
end;

function TDialectAccess.FunctionSQL(const AName: string; const AArgs: array of string): string;
var
  I: Integer;
  LName: string;
begin
  { Access (Jet/ACE): nomenclatura propria - UCASE/LCASE (nao UPPER/LOWER),
    LEN (nao LENGTH), MID (nao SUBSTRING - mesma semantica posicional x,p[,n]);
    sem COALESCE nativo -> encadeamento de Nz(valor,default) (2 args cada),
    Onda 6-e Estagio 3 (I13). }
  LName := Trim(AName);
  if SameText(LName, 'UPPER') then
  begin
    if Length(AArgs) >= 1 then Result := 'UCASE(' + AArgs[0] + ')' else Result := 'UCASE()';
    Exit;
  end;
  if SameText(LName, 'LOWER') then
  begin
    if Length(AArgs) >= 1 then Result := 'LCASE(' + AArgs[0] + ')' else Result := 'LCASE()';
    Exit;
  end;
  if SameText(LName, 'LENGTH') then
  begin
    if Length(AArgs) >= 1 then Result := 'LEN(' + AArgs[0] + ')' else Result := 'LEN()';
    Exit;
  end;
  if SameText(LName, 'SUBSTRING') then
  begin
    if Length(AArgs) >= 3 then
      Result := 'MID(' + AArgs[0] + ', ' + AArgs[1] + ', ' + AArgs[2] + ')'
    else if Length(AArgs) = 2 then
      Result := 'MID(' + AArgs[0] + ', ' + AArgs[1] + ')'
    else
      Result := inherited FunctionSQL(AName, AArgs);
    Exit;
  end;
  if SameText(LName, 'COALESCE') then
  begin
    if Length(AArgs) = 0 then
      Result := ''
    else
    begin
      Result := AArgs[0];
      for I := 1 to High(AArgs) do
        Result := 'NZ(' + Result + ', ' + AArgs[I] + ')';
    end;
    Exit;
  end;
  Result := inherited FunctionSQL(AName, AArgs);
end;

function TDialectAccess.AddUniqueSQL(const ATable, AName: string;
  const AColumns: array of string): string;
begin
  { Jet/ACE: usar CREATE UNIQUE INDEX (ADD CONSTRAINT UNIQUE nao e fiavel). }
  Result := CreateIndexSQL(ATable, AName, AColumns, True);
end;

function TDialectAccess.UniquesSQL(const ATable, ASchema: string): string;
begin
  { MSysObjects protegido - introspecao nao fiavel; '' -> consumidor assume presente. }
  Result := '';
end;

function TDialectAccess.FieldAlterSQL(const ATable, AColumn, ANewType: string;
  const ANotNull: Boolean): string;
begin
  { Jet/ACE: 'ALTER TABLE t ALTER COLUMN col <tipo>' - SEM a palavra 'TYPE' (a
    base ANSI usa 'ALTER COLUMN col TYPE x', que o Jet rejeita). NOT NULL nao e
    aplicavel de forma fiavel no ALTER COLUMN do Jet -> best-effort so o tipo. }
  Result := '';
  if (Trim(ATable) = '') or (Trim(AColumn) = '') then Exit;
  Result := 'ALTER TABLE ' + QuoteIdentifier(Trim(ATable)) + ' ALTER COLUMN ' +
    QuoteIdentifier(Trim(AColumn)) + ' ' + ANewType;
end;

function TDialectAccess.FieldRenameSQL(const ATable, AOldName, ANewName: string): string;
begin
  { Jet/ACE SQL NAO tem RENAME COLUMN (so via DAO/ADOX, fora do dominio SQL) -> ''
    (N/A). O nivel que executa trata '' como no-op; o smoke salta a asercao. }
  Result := '';
end;

function TDialectAccess.IndexDropSQL(const ATable, AName: string): string;
begin
  { Jet/ACE exige 'DROP INDEX name ON tabela' (a base 'DROP INDEX name' e rejeitada). }
  Result := '';
  if (Trim(ATable) = '') or (Trim(AName) = '') then Exit;
  Result := 'DROP INDEX ' + QuoteIdentifier(Trim(AName)) + ' ON ' + QuoteIdentifier(Trim(ATable));
end;

function TDialectAccess.TableRenameSQL(const AOldName, ANewName: string): string;
begin
  { Jet/ACE SQL NAO tem RENAME TABLE (so via DAO ou SELECT ... INTO) -> '' (N/A). }
  Result := '';
end;

function TDialectAccess.ViewCreateSQL(const AName, ASelectSQL: string; const AOrReplace: Boolean): string;
begin
  { Jet/ACE NAO tem CREATE OR REPLACE VIEW -> sempre 'CREATE VIEW' (para "replace"
    o caller faz DROP VIEW antes). }
  Result := '';
  if (Trim(AName) = '') or (Trim(ASelectSQL) = '') then Exit;
  Result := 'CREATE VIEW ' + QuoteIdentifier(Trim(AName)) + ' AS ' + ASelectSQL;
end;

function TDialectAccess.ViewsSQL(const ASchema: string): string;
begin
  { Jet/ACE: sem information_schema; MSysObjects protegido -> introspecao de views
    nao fiavel -> '' (ViewExists degrada; smoke salta a asercao). }
  Result := '';
end;

function TDialectAccess.IdentityColumnsSQL(const ATableName, ASchema: string): string;
begin
  { F5-FU.1 - Jet/ACE: sem information_schema; MSysObjects protegido -> mesma
    limitacao conhecida de UniquesSQL/ViewsSQL acima - introspecao de colunas
    COUNTER (identity) nao fiavel via SQL -> '' (IsIdentity fica 0; limitacao
    documentada). }
  Result := '';
end;

{$ENDIF}

end.
