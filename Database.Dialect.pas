{ =============================================================================
  Database.Dialect - Base dos dialectos SQL (TDialect) + factory ForConnection

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.0.0
  FileVersion:    1.10.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           27/07/2026

  FASE 5 Onda 5.2. TDialect (base ANSI): registry de operadores decompostos
  (E3) pre-carregado com o nucleo ANSI (=, <>, LIKE, IN, BETWEEN, IS NULL,
  CAST, CONCAT por ||, UPPER/LOWER/TRIM/COALESCE); quoting via TTypeDatabase
  (5.1); paginacao por estilo; ColumnTypeFor ANSI - os descendentes ajustam
  capabilities, estilo, tipos e operadores.

  Factory: TDialect.ForConnection(IConnection) resolve o dialecto pelo
  DatabaseType da conexao; Firebird usa AConnection.FirebirdVersion
  (version-aware 2-D); PostgreSQL/SQLServer tentam auto-detectar a versao via
  DetectVersion/AConnection.GetServerVersion (Onda 6-a, I22) - se a conexao
  nao estiver ligada (GetServerVersion=''), cai no dialecto "moderno" default
  (mesmo comportamento pre-Onda-6-a, ZERO regressao). DI transparente: pooled
  vs directa e invisivel.

  Changelog (file):
  - 1.10.0 (27/07/2026): conformidade F5 (onda C6, #4, ADITIVO) - FunctionsSQL
    (ASchema): string; virtual - SQL de listagem das FUNCTIONS de utilizador
    do banco/schema (paridade com ProceduresSQL); implementacao BASE devolve
    '' (SQLite/Access/SQL Anywhere); overrides em PostgreSQL/SQLServer/MySQL/
    Firebird.
  - 1.9.0 (25/07/2026): F5-FU.1 (populacao de IsIdentity por dialecto, ADITIVO) -
    IdentityColumnsSQL(ATableName, ASchema) - implementacao BASE devolve '' (nao
    suportado); os dialectos com catalogo de colunas autoincremento (Firebird/
    SQLServer/PostgreSQL/MySQL) fazem override nas suas proprias units;
    SQLAnywhere/SQLite/Access ficam na BASE (sem catalogo dedicado fiavel).
    Consumido por ICatalogReader.TableStructure (Database.CatalogReader.ApplyColumnIdentity).
  - 1.8.0 (17/07/2026): Onda 10-D (marshalling de VALOR cross-DB, ADITIVO) -
    EncodeBoolean: representacao do boolean DERIVADA da capability scBoolean do
    proprio dialecto (fonte unica, sem hardcode por-banco) - boolean nativo
    (PG/FB3+) -> boolean; senao 0/1. Override so Access (-1/0). Consumido por
    QueryBuilder.Bind (todo write bindado do projeto).
  - 1.7.0 (16/07/2026): F5 Onda 10 (SQL Anywhere 17, sub-passo 10.c) - registado
    Database.Dialect.SQLAnywhere/TDialectSQLAnywhere em ForConnection/
    ForDatabaseType (version-aware via TryParseMajorMinor, mesmo padrao
    PostgreSQL/SQLServer). ApplyPagination ganha o case psTopStartAt ('SELECT
    TOP n START AT m ...', START AT 1-based -> +1 no offset) - confirmado
    empiricamente contra servidor real (LIMIT/OFFSET da SQLCODE=-131).
  - 1.6.0 (15/07/2026): Onda 6-f Estagio 1 (I10, ADITIVO) - LinkedServersSQL/
    ProceduresSQL(ASchema)/CallProcedureSQL(AProcName,AArgCount) - implementacao
    BASE devolve '' para as 3 (no-op gracioso; SQLite/Access ficam sempre na
    BASE); os dialectos com o recurso fazem override na sua propria unit (ver
    changelog de Database.Dialect.SQLServer/PostgreSQL/MySQL/Firebird).
  - 1.5.0 (15/07/2026): Onda 6-e Estagio 3 (I13, ADITIVO) - FunctionSQL(AName,
    AArgs) - implementacao BASE generica: UpperCase(AName) + '(' + args
    unidos por ', ' + ')' (cobre UPPER/LOWER/COALESCE/LENGTH/SUBSTRING ANSI
    e qualquer outra funcao ANSI-compativel sem precisar de caso dedicado);
    os descendentes com sintaxe divergente fazem override (ver changelog dos
    ficheiros SQLServer/Firebird/SQLite/Access).
  - 1.4.0 (15/07/2026): Onda 6-d PARTE 2 (I24, ADITIVO) - ColumnDescriptionSQL
    (ATable, ASchema) - implementacao BASE devolve '' (nao suportado); os
    dialectos com catalogo de comentarios de coluna (PostgreSQL/SQLServer/
    Firebird/MySQL) fazem override nas suas proprias units; SQLite/Access
    mantem-se na BASE (sem override).
  - 1.3.0 (14/07/2026): Onda 6-a (F5 revisao, modernizacao AQB/EMS, ADITIVO) -
    I22: DetectVersion(AConnection) - implementacao BASE uniforme (devolve
    AConnection.GetServerVersion, kernel F4 intacto; '' se nil/desligada);
    TryParseMajorMinor (helper interno, NAO exposto na interface) - extrai
    major/minor de uma string de versao livre (primeiro grupo de digitos +
    opcional ".minor"); usado por ForConnection para PostgreSQL/SQLServer
    (Firebird continua a usar AConnection.FirebirdVersion, config explicita -
    inalterado). ForConnection: dtPostgreSQL/dtSQLServer tentam
    DetectVersion+parse; falha (sem conexao activa) -> New() default (mesmo
    dialecto "moderno" de sempre, ZERO regressao dos golden ForConnection
    existentes, que nunca chamam Connect). I21: DateLiteral/TimestampLiteral/
    TryParseDateLiteral - implementacao BASE ANSI ('aaaa-mm-dd'[ hh:nn:ss]
    entre aspas simples); TryParseDateLiteral reconhece tambem os prefixos
    DATE/TIMESTAMP (PostgreSQL) e o delimitador #...# (Access) - parser unico
    partilhado por TODOS os dialectos (nenhum precisa de override).
  - 1.2.0 (14/07/2026): Fatia B-e (continuacao Onda 4, revisao F5) -
    CreateDatabaseSQL/DropDatabaseSQL (aditivos, virtual) - implementacao
    base SEM gate de capability (ao contrario de CreateSchemaSQL/scSchemas) -
    gera 'CREATE|DROP DATABASE ' + QuoteIdentifier(AName) para QUALQUER
    dialecto; SQLite/Access/Firebird fazem override na sua propria unit
    (ver Database.Dialect.SQLite/Access/Firebird).
  - 1.1.0 (13/07/2026): Fatia B-d (continuacao Onda 4, revisao F5) -
    CreateSchemaSQL/DropSchemaSQL (aditivos, virtual) - implementacao base
    gate pela capability scSchemas (vazio quando OFF); nova factory
    ForDatabaseType(ADatabaseType, AFirebirdVersion=fb50) - resolve o
    dialecto SO pelo enum TDatabaseTypes, SEM IConnection (mesmo padrao dos
    golden de dialects - TDialect*.New direto); usada pelo Schema
    (Database.Schema.pas) para gerar CreateSchemaSQL/DropSchemaSQL sem
    depender de uma conexao viva.
  - 1.0.0 (12/07/2026): versao inicial (Onda 5.2).
  ============================================================================= }
unit Database.Dialect;

{$I ../../../ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$IFDEF USE_DATABASE}

uses
{$IFDEF FPC}
  SysUtils, Classes, Generics.Collections,
{$ELSE}
  System.SysUtils, System.Classes, System.Generics.Collections,
{$ENDIF}
  Commons.Types,
  Commons.Database.Types,
  Commons.Database.Consts,
  Exceptions.Database,
  Connections.Interfaces,
  Databases.Interfaces,
  Database.TypeDatabase;

type
  TDialect = class(TInterfacedObject, IDialect)
  strict private
    FTypeDb : ITypeDatabase;
    FOps    : TDictionary<string, TSQLOperatorDef>;
  strict protected
    FDatabaseType : TDatabaseTypes;
    FCapabilities : TSQLCapabilities;
    FPagination   : TSQLPaginationStyle;
    FMaxIdentLen  : Integer;
    FVersionText  : string;
    procedure Setup; virtual;               // descendentes: caps/estilo/ops
    procedure RegisterAnsiOperators;
    procedure DefineOperator(const AName, APrefix, ARelate, ARelate2,
      APostfix: string; const AArity: Integer);
    { helper 5.5-B: junta AColumns quotadas por ', ' (via QuoteIdentifier);
      colunas vazias sao ignoradas. Reutilizado pelos overrides SQLite/Access. }
    function QuoteColumnList(const AColumns: array of string): string;
    { helpers F3 (triggers) - reutilizados pelos overrides por banco. }
    function TriggerTimingWord(const ATiming: TTriggerTiming): string;
    function TriggerEventsClause(const AEvents: TTriggerEvents; const ASeparator: string): string;
    function TriggerFirstEventWord(const AEvents: TTriggerEvents): string;
  public
    constructor Create(const ADatabaseType: TDatabaseTypes);
    destructor Destroy; override;

    { factory por conexao (Firebird version-aware via FirebirdVersion) }
    class function ForConnection(const AConnection: IConnection): IDialect;
    { factory por TDatabaseTypes puro, SEM IConnection (Fatia B-d) - usada
      quando so o enum esta disponivel (ex.: ISchema.CreateSchemaSQL, que nao
      recebe conexao); AFirebirdVersion so tem efeito quando ADatabaseType =
      dtFireBird (default fb50, mesmo default usado noutros pontos do
      ecossistema - ver Commons.Consts.DEFAULT_FIREBIRD_VERSION). }
    class function ForDatabaseType(const ADatabaseType: TDatabaseTypes;
      const AFirebirdVersion: TFirebirdVersion = fb50): IDialect;

    { IDialect }
    function DatabaseType: TDatabaseTypes;
    function DialectName: string; virtual;
    function ServerVersionText: string;
    function Capabilities: TSQLCapabilities;
    function Supports(const ACapability: TSQLCapability): Boolean;
    function PaginationStyle: TSQLPaginationStyle;
    function MaxIdentifierLength: Integer;
    function QuoteOpen: string;
    function QuoteClose: string;
    function QuoteIdentifier(const AName: string): string;
    function ApplyPagination(const ASelectSQL: string; const ALimit: Integer;
      const AOffset: Integer = 0): string; virtual;
    function ColumnTypeFor(const AKind: TSQLColumnKind; const ASize: Integer = 0;
      const AScale: Integer = 0): string; virtual;
    function EncodeBoolean(const AValue: Boolean): Variant; virtual;
    function EncodeDateTime(const AValue: TDateTime): Variant; virtual;
    function HasOperator(const AName: string): Boolean;
    function RenderOperator(const AName: string;
      const AOperands: array of string): string;
    function RegisterOperator(const ADef: TSQLOperatorDef): IDialect;
    function CreateSchemaSQL(const ASchema: string): string; virtual;
    function DropSchemaSQL(const ASchema: string): string; virtual;
    function CreateDatabaseSQL(const AName: string): string; virtual;
    function DropDatabaseSQL(const AName: string): string; virtual;
    function DetectVersion(const AConnection: IConnection): string; virtual;
    function DateLiteral(const ADate: TDateTime): string; virtual;
    function TimestampLiteral(const ADateTime: TDateTime): string; virtual;
    function TryParseDateLiteral(const ALiteral: string; out ADate: TDateTime): Boolean; virtual;
    function ColumnDescriptionSQL(const ATable, ASchema: string): string; virtual;
    function IdentityColumnsSQL(const ATableName, ASchema: string): string; virtual;
    function FunctionSQL(const AName: string; const AArgs: array of string): string; virtual;
    function LinkedServersSQL: string; virtual;
    function ProceduresSQL(const ASchema: string): string; virtual;
    function FunctionsSQL(const ASchema: string): string; virtual;
    function ViewsSQL(const ASchema: string): string; virtual;
    function TriggersSQL(const ASchema: string): string; virtual;
    function RulesSQL(const ASchema: string): string; virtual;
    function CallProcedureSQL(const AProcName: string; const AArgCount: Integer): string; virtual;
    function AddUniqueSQL(const ATable, AName: string;
      const AColumns: array of string): string; virtual;
    function CreateIndexSQL(const ATable, AName: string;
      const AColumns: array of string; const AUnique: Boolean): string; virtual;
    function UniquesSQL(const ATable, ASchema: string): string; virtual;
    function IndexesSQL(const ATable, ASchema: string): string; virtual;
    { Onda D - faceta FIELD: acessor (IDialect) + rotinas polimorficas (publicas
      na CLASSE, nao no IDialect; a faceta TFieldDialect forwarda para estas). }
    function Field: IFieldDialect;
    function FieldAddSQL(const ATable, AField, AFieldType: string;
      const ANotNull: Boolean): string; virtual;
    function FieldDropSQL(const ATable, AField: string): string; virtual;
    function FieldAlterSQL(const ATable, AField, ANewType: string;
      const ANotNull: Boolean): string; virtual;
    function FieldRenameSQL(const ATable, AOldName, ANewName: string): string; virtual;
    { Onda D - acessores das facetas restantes }
    function Table: ITableDialect;
    function Schema: ISchemaDialect;
    function Database: IDatabaseDialect;
    function Index: IIndexDialect;
    function Unique: IUniqueDialect;
    function PKey: IPKeyDialect;
    function FKey: IFKeyDialect;
    function View: IViewDialect;
    function Routine: IRoutineDialect;
    function Trigger: ITriggerDialect;
    function Rule: IRuleDialect;
    { Onda D - rotinas polimorficas novas (as create/drop/add flat existentes -
      CreateSchemaSQL/CreateDatabaseSQL/CreateIndexSQL/AddUniqueSQL - sao reusadas
      pelas facetas Schema/Database/Index/Unique). }
    function TableCreateSQL(const ATable, AColumnsClause, ASchema: string): string; virtual;
    function TableDropSQL(const ATable, ASchema: string; const AIfExists: Boolean): string; virtual;
    function TableRenameSQL(const AOldName, ANewName: string): string; virtual;
    function SchemaRenameSQL(const AOldName, ANewName: string): string; virtual;
    function DatabaseRenameSQL(const AOldName, ANewName: string): string; virtual;
    function IndexDropSQL(const ATable, AName: string): string; virtual;
    function UniqueDropSQL(const ATable, AName: string): string; virtual;
    function PKeyAddSQL(const ATable, AName: string; const AColumns: array of string): string; virtual;
    function PKeyDropSQL(const ATable, AName: string): string; virtual;
    function FKeyAddSQL(const ATable, AName: string; const AColumns: array of string;
      const ARefTable: string; const ARefColumns: array of string;
      const AOnDelete, AOnUpdate: string): string; virtual;
    function FKeyDropSQL(const ATable, AName: string): string; virtual;
    function ViewCreateSQL(const AName, ASelectSQL: string; const AOrReplace: Boolean): string; virtual;
    function ViewDropSQL(const AName: string; const AIfExists: Boolean): string; virtual;
    function ViewAlterSQL(const AName, ASelectSQL: string): string; virtual;
    function RoutineCreateSQL(const AName, ABody: string; const AIsFunction: Boolean): string; virtual;
    { Onda F1 - zero-SQL: compoe o CREATE PROCEDURE/FUNCTION a partir do builder
      IRoutineDefinition. BASE devolve '' (SQLite/Access = motores sem rotinas);
      PostgreSQL/MySQL/SQLServer/Firebird/SQLAnywhere fazem override. }
    function RoutineDefCreateSQL(const ADef: IRoutineDefinition): string; virtual;
    function RoutineDropSQL(const AName: string; const AIsFunction, AIfExists: Boolean): string; virtual;
    { Onda F3 - zero-SQL: compoe o CREATE TRIGGER (e, no PostgreSQL, a FUNCTION
      trigger) a partir do builder ITriggerDefinition; pode devolver varios
      statements separados por #0. BASE devolve '' (Access = sem triggers);
      PostgreSQL/MySQL/SQLServer/Firebird/SQLite/SQLAnywhere fazem override.
      TriggerDropSQL: BASE 'DROP TRIGGER [IF EXISTS] n' (SQLite/MySQL/SQLServer);
      PostgreSQL/Firebird/SQLAnywhere fazem override (ON table / sem IF EXISTS /
      drop da FUNCTION companheira). }
    function TriggerDefCreateSQL(const ADef: ITriggerDefinition): string; virtual;
    function TriggerDropSQL(const AName, ATable: string; const AIfExists: Boolean): string; virtual;
    { Onda F4 - zero-SQL: compoe o CREATE RULE a partir do builder
      IRuleDefinition. BASE '' (so PostgreSQL/SQL Server fazem override).
      RuleDropSQL: BASE '' (idem). }
    function RuleDefCreateSQL(const ADef: IRuleDefinition): string; virtual;
    function RuleDropSQL(const AName, ATable: string; const AIfExists: Boolean): string; virtual;
  end;

{ Onda 6-a (I22) - helper de parsing (NAO exposto na interface); extrai o
  primeiro par major[.minor] de uma string de versao livre (ex.: '15.0.2000.5'
  -> 15/0; '16.1 (Debian 16.1-1)' -> 16/1; '' ou sem digitos -> False). Usado
  por TDialect.ForConnection para PostgreSQL/SQLServer (Onda 6-a). }
function TryParseMajorMinor(const AVersionText: string; out AMajor, AMinor: Integer): Boolean;

{$ENDIF}

implementation

{$IFDEF USE_DATABASE}

uses
  Database.Dialect.PostgreSQL,
  Database.Dialect.MySQL,
  Database.Dialect.SQLServer,
  Database.Dialect.SQLite,
  Database.Dialect.Firebird,
  Database.Dialect.Access,
  Database.Dialect.SQLAnywhere;

{ TDialect }

constructor TDialect.Create(const ADatabaseType: TDatabaseTypes);
begin
  inherited Create;
  FDatabaseType := ADatabaseType;
  FTypeDb := TTypeDatabase.New.DatabaseType(ADatabaseType);
  FOps := TDictionary<string, TSQLOperatorDef>.Create;
  FCapabilities := [scDerivedTables, scUnion, scUnionAll];
  FPagination := psNone;
  FMaxIdentLen := 0;
  FVersionText := '';
  RegisterAnsiOperators;
  Setup;
end;

destructor TDialect.Destroy;
begin
  FOps.Free;
  inherited;
end;

procedure TDialect.Setup;
begin
  { base ANSI - descendentes fazem override }
end;

procedure TDialect.DefineOperator(const AName, APrefix, ARelate, ARelate2,
  APostfix: string; const AArity: Integer);
var
  LDef: TSQLOperatorDef;
begin
  LDef.Name := AName;
  LDef.Prefix := APrefix;
  LDef.Relate := ARelate;
  LDef.Relate2 := ARelate2;
  LDef.Postfix := APostfix;
  LDef.Arity := AArity;
  FOps.AddOrSetValue(UpperCase(AName), LDef);
end;

procedure TDialect.RegisterAnsiOperators;
begin
  DefineOperator(SQLOP_EQ,       '', ' = ',  '', '', 2);
  DefineOperator(SQLOP_NEQ,      '', ' <> ', '', '', 2);
  DefineOperator(SQLOP_GT,       '', ' > ',  '', '', 2);
  DefineOperator(SQLOP_GTE,      '', ' >= ', '', '', 2);
  DefineOperator(SQLOP_LT,       '', ' < ',  '', '', 2);
  DefineOperator(SQLOP_LTE,      '', ' <= ', '', '', 2);
  DefineOperator(SQLOP_LIKE,     '', ' LIKE ', '', '', 2);
  DefineOperator(SQLOP_NOT_LIKE, '', ' NOT LIKE ', '', '', 2);
  DefineOperator(SQLOP_IN,       '', ' IN (', '', ')', 2);
  DefineOperator(SQLOP_NOT_IN,   '', ' NOT IN (', '', ')', 2);
  DefineOperator(SQLOP_BETWEEN,  '', ' BETWEEN ', ' AND ', '', 3);
  DefineOperator(SQLOP_IS_NULL,  '', '', '', ' IS NULL', 1);
  DefineOperator(SQLOP_NOT_NULL, '', '', '', ' IS NOT NULL', 1);
  DefineOperator(SQLOP_CAST,     'CAST(', ' AS ', '', ')', 2);
  DefineOperator(SQLOP_CONCAT,   '', ' || ', '', '', 2);
  DefineOperator(SQLOP_UPPER,    'UPPER(', '', '', ')', 1);
  DefineOperator(SQLOP_LOWER,    'LOWER(', '', '', ')', 1);
  DefineOperator(SQLOP_TRIM,     'TRIM(', '', '', ')', 1);
  DefineOperator(SQLOP_COALESCE, 'COALESCE(', ', ', '', ')', 2);
end;

function TryParseMajorMinor(const AVersionText: string; out AMajor, AMinor: Integer): Boolean;
var
  I, LLen: Integer;
  LMajorStr, LMinorStr: string;
begin
  AMajor := 0;
  AMinor := 0;
  LLen := Length(AVersionText);
  I := 1;
  while (I <= LLen) and not ((AVersionText[I] >= '0') and (AVersionText[I] <= '9')) do
    Inc(I);
  LMajorStr := '';
  while (I <= LLen) and (AVersionText[I] >= '0') and (AVersionText[I] <= '9') do
  begin
    LMajorStr := LMajorStr + AVersionText[I];
    Inc(I);
  end;
  LMinorStr := '';
  if (I <= LLen) and (AVersionText[I] = '.') then
  begin
    Inc(I);
    while (I <= LLen) and (AVersionText[I] >= '0') and (AVersionText[I] <= '9') do
    begin
      LMinorStr := LMinorStr + AVersionText[I];
      Inc(I);
    end;
  end;
  AMajor := StrToIntDef(LMajorStr, 0);
  AMinor := StrToIntDef(LMinorStr, 0);
  Result := AMajor > 0;
end;

class function TDialect.ForConnection(const AConnection: IConnection): IDialect;
var
  LType: TDatabaseTypes;
  LVerText: string;
  LMajor, LMinor: Integer;
begin
  if AConnection = nil then
    raise EDatabaseDialectException.Create(
      'ForConnection: IConnection nao injectada', ERR_DATABASE_NO_CONNECTION);
  LType := AConnection.GetConnectionData.DatabaseType;
  case LType of
    dtPostgreSQL:
      begin
        { Onda 6-a (I22): tenta detectar a versao real do servidor; sem
          conexao activa (GetServerVersion='') cai no default "moderno" -
          MESMO dialecto de sempre, zero regressao. }
        LVerText := AConnection.GetServerVersion;
        if TryParseMajorMinor(LVerText, LMajor, LMinor) then
          Result := TDialectPostgreSQL.New(LMajor, LMinor)
        else
          Result := TDialectPostgreSQL.New;
      end;
    dtMySQL:      Result := TDialectMySQL.New;
    dtSQLServer:
      begin
        LVerText := AConnection.GetServerVersion;
        if TryParseMajorMinor(LVerText, LMajor, LMinor) then
          Result := TDialectSQLServer.New(LMajor)
        else
          Result := TDialectSQLServer.New;
      end;
    dtSQLite:     Result := TDialectSQLite.New;
    dtFireBird:   Result := TDialectFirebird.New(AConnection.FirebirdVersion);
    dtAccess:     Result := TDialectAccess.New;
    dtSQLAnywhere:
      begin
        { F5 Onda 10 - version-aware (decisao 6), mas sem deteccao real de
          versao ainda (TryParseMajorMinor generico assume formato numerico
          simples; o GetServerVersion do SQL Anywhere devolve string tipo
          '17.0.11.8360', TryParseMajorMinor extrai 17/0 correctamente). }
        LVerText := AConnection.GetServerVersion;
        if TryParseMajorMinor(LVerText, LMajor, LMinor) then
          Result := TDialectSQLAnywhere.New(LMajor)
        else
          Result := TDialectSQLAnywhere.New;
      end;
  else
    raise EDatabaseDialectException.Create(
      Format(DB_ERR_DIALECT_UNSUPPORTED_MSG,
        [TDatabaseTypeClass.ConfigString(LType)]), ERR_DATABASE_DIALECT);
  end;
end;

class function TDialect.ForDatabaseType(const ADatabaseType: TDatabaseTypes;
  const AFirebirdVersion: TFirebirdVersion): IDialect;
begin
  { Fatia B-d - mesma resolucao de ForConnection, mas so pelo enum
    TDatabaseTypes (sem IConnection); padrao "TDialect*.New sem .Connect"
    ja usado pelos golden tests de dialects (smoke_dialects). }
  case ADatabaseType of
    dtPostgreSQL: Result := TDialectPostgreSQL.New;
    dtMySQL:      Result := TDialectMySQL.New;
    dtSQLServer:  Result := TDialectSQLServer.New;
    dtSQLite:     Result := TDialectSQLite.New;
    dtFireBird:   Result := TDialectFirebird.New(AFirebirdVersion);
    dtAccess:     Result := TDialectAccess.New;
    dtSQLAnywhere: Result := TDialectSQLAnywhere.New;
  else
    raise EDatabaseDialectException.Create(
      Format(DB_ERR_DIALECT_UNSUPPORTED_MSG,
        [TDatabaseTypeClass.ConfigString(ADatabaseType)]), ERR_DATABASE_DIALECT);
  end;
end;

{ ---- identidade / capabilities ---- }

function TDialect.DatabaseType: TDatabaseTypes;
begin
  Result := FDatabaseType;
end;

function TDialect.DialectName: string;
begin
  Result := TDatabaseTypeClass.ConfigString(FDatabaseType);
end;

function TDialect.ServerVersionText: string;
begin
  Result := FVersionText;
end;

function TDialect.Capabilities: TSQLCapabilities;
begin
  Result := FCapabilities;
end;

function TDialect.Supports(const ACapability: TSQLCapability): Boolean;
begin
  Result := ACapability in FCapabilities;
end;

function TDialect.PaginationStyle: TSQLPaginationStyle;
begin
  Result := FPagination;
end;

function TDialect.MaxIdentifierLength: Integer;
begin
  Result := FMaxIdentLen;
end;

{ ---- quoting ---- }

function TDialect.QuoteOpen: string;
begin
  Result := FTypeDb.GetIdentifierQuote;
end;

function TDialect.QuoteClose: string;
begin
  Result := FTypeDb.GetIdentifierQuoteClose;
end;

function TDialect.QuoteIdentifier(const AName: string): string;
var
  LParts: TStringList;
  I: Integer;
begin
  if (Trim(AName) = '') or (AName = '*') then
    Exit(AName);
  LParts := TStringList.Create;
  try
    LParts.Delimiter := '.';
    LParts.StrictDelimiter := True;
    LParts.DelimitedText := AName;
    Result := '';
    for I := 0 to LParts.Count - 1 do
    begin
      if I > 0 then
        Result := Result + '.';
      if LParts[I] = '*' then
        Result := Result + '*'
      else
        Result := Result + QuoteOpen + LParts[I] + QuoteClose;
    end;
  finally
    LParts.Free;
  end;
end;

{ ---- paginacao ---- }

function TDialect.ApplyPagination(const ASelectSQL: string;
  const ALimit: Integer; const AOffset: Integer): string;
var
  LPos: Integer;
begin
  case FPagination of
    psLimitOffset:
      begin
        Result := ASelectSQL + ' LIMIT ' + IntToStr(ALimit);
        if AOffset > 0 then
          Result := Result + ' OFFSET ' + IntToStr(AOffset);
      end;
    psOffsetFetch:
      Result := ASelectSQL + ' OFFSET ' + IntToStr(AOffset) +
        ' ROWS FETCH NEXT ' + IntToStr(ALimit) + ' ROWS ONLY';
    psRowsTo:
      Result := ASelectSQL + ' ROWS ' + IntToStr(AOffset + 1) + ' TO ' +
        IntToStr(AOffset + ALimit);
    psTop:
      begin
        if AOffset > 0 then
          raise EDatabaseDialectException.Create(
            Format(DB_ERR_PAGINATION_MSG, [DialectName + ' (TOP sem OFFSET)']),
            ERR_DATABASE_PAGINATION);
        LPos := Pos('SELECT ', UpperCase(ASelectSQL));
        if LPos <> 1 then
          raise EDatabaseDialectException.Create(
            Format(DB_ERR_PAGINATION_MSG, [DialectName]), ERR_DATABASE_PAGINATION);
        Result := 'SELECT TOP ' + IntToStr(ALimit) + ' ' +
          Copy(ASelectSQL, LPos + Length('SELECT '), MaxInt);
      end;
    psTopStartAt:
      begin
        { SQL Anywhere (F5 Onda 10) - 'SELECT TOP n START AT m ...'; START AT
          e 1-based (START AT 1 = primeira linha), por isso +1 no offset.
          Confirmado empiricamente contra servidor real (dbisql). }
        LPos := Pos('SELECT ', UpperCase(ASelectSQL));
        if LPos <> 1 then
          raise EDatabaseDialectException.Create(
            Format(DB_ERR_PAGINATION_MSG, [DialectName]), ERR_DATABASE_PAGINATION);
        Result := 'SELECT TOP ' + IntToStr(ALimit) + ' START AT ' +
          IntToStr(AOffset + 1) + ' ' +
          Copy(ASelectSQL, LPos + Length('SELECT '), MaxInt);
      end;
  else
    raise EDatabaseDialectException.Create(
      Format(DB_ERR_PAGINATION_MSG, [DialectName]), ERR_DATABASE_PAGINATION);
  end;
end;

{ ---- tipos (base ANSI; descendentes ajustam) ---- }

function TDialect.ColumnTypeFor(const AKind: TSQLColumnKind;
  const ASize: Integer; const AScale: Integer): string;
var
  LSize, LScale: Integer;
begin
  LSize := ASize;
  LScale := AScale;
  case AKind of
    ckInteger:  Result := 'INTEGER';
    ckBigInt:   Result := 'BIGINT';
    ckSmallInt: Result := 'SMALLINT';
    ckDecimal:
      begin
        if LSize <= 0 then LSize := 18;
        if LScale < 0 then LScale := 4;
        Result := Format('DECIMAL(%d,%d)', [LSize, LScale]);
      end;
    ckFloat:    Result := 'DOUBLE PRECISION';
    ckBoolean:  Result := 'BOOLEAN';
    ckVarChar:
      begin
        if LSize <= 0 then LSize := 255;
        Result := Format('VARCHAR(%d)', [LSize]);
      end;
    ckChar:
      begin
        if LSize <= 0 then LSize := 1;
        Result := Format('CHAR(%d)', [LSize]);
      end;
    ckText:     Result := 'TEXT';
    ckDate:     Result := 'DATE';
    ckTime:     Result := 'TIME';
    ckDateTime: Result := 'TIMESTAMP';
    ckBlob:     Result := 'BLOB';
    ckIdentity: Result := 'INTEGER GENERATED BY DEFAULT AS IDENTITY';
  else
    Result := 'VARCHAR(255)';
  end;
end;

{ Onda 10-D - representacao correcta de um boolean para BIND, DERIVADA da
  capability do proprio dialecto (FONTE UNICA: a mesma flag scBoolean="tipo
  BOOLEAN nativo" que governa ColumnTypeFor; a decisao por-banco NAO se duplica
  aqui): banco com BOOLEAN nativo (PostgreSQL; Firebird 3+, version-aware pela
  propria capability) recebe o valor como boolean (bind ftBoolean, exigido pela
  tipagem ESTRITA do PostgreSQL - "column is of type boolean but expression is
  of type smallint"); caso contrario 0/1 (bit/smallint/integer/tinyint: SQL
  Server, SQL Anywhere, SQLite, MySQL, Firebird 2.5). Access (yes/no = -1/0)
  sobrepoe. Simetrico ao READ (Parameters.FieldAsBool). }
function TDialect.EncodeBoolean(const AValue: Boolean): Variant;
begin
  if Supports(scBoolean) then
    Result := AValue
  else if AValue then
    Result := 1
  else
    Result := 0;
end;

function TDialect.EncodeDateTime(const AValue: TDateTime): Variant;
begin
  { base: passthrough varDate - aceite pelos drivers de PG/MySQL/SQLServer/FB/
    SQLite/SA no bind. Access/Jet sobrepoe (ADO rejeita varDate -> string). }
  Result := AValue;
end;

{ ---- registry E3 ---- }

function TDialect.HasOperator(const AName: string): Boolean;
begin
  Result := FOps.ContainsKey(UpperCase(AName));
end;

function TDialect.RenderOperator(const AName: string;
  const AOperands: array of string): string;
var
  LDef: TSQLOperatorDef;
begin
  if not FOps.TryGetValue(UpperCase(AName), LDef) then
    raise EDatabaseDialectException.Create(
      Format(DB_ERR_OPERATOR_UNKNOWN_MSG, [AName, DialectName]),
      ERR_DATABASE_OPERATOR);
  if Length(AOperands) <> LDef.Arity then
    raise EDatabaseDialectException.Create(
      Format(DB_ERR_OPERATOR_ARITY_MSG, [AName, LDef.Arity, Length(AOperands)]),
      ERR_DATABASE_OPERATOR_ARITY);
  case LDef.Arity of
    1: Result := LDef.Prefix + AOperands[0] + LDef.Postfix;
    2: Result := LDef.Prefix + AOperands[0] + LDef.Relate + AOperands[1] + LDef.Postfix;
    3: Result := LDef.Prefix + AOperands[0] + LDef.Relate + AOperands[1] +
                 LDef.Relate2 + AOperands[2] + LDef.Postfix;
  else
    raise EDatabaseDialectException.Create(
      Format(DB_ERR_OPERATOR_ARITY_MSG, [AName, LDef.Arity, Length(AOperands)]),
      ERR_DATABASE_OPERATOR_ARITY);
  end;
end;

function TDialect.RegisterOperator(const ADef: TSQLOperatorDef): IDialect;
begin
  DefineOperator(ADef.Name, ADef.Prefix, ADef.Relate, ADef.Relate2,
    ADef.Postfix, ADef.Arity);
  Result := Self;
end;

{ ---- DDL de nivel schema (Fatia B-d) ---- }

function TDialect.CreateSchemaSQL(const ASchema: string): string;
begin
  { implementacao BASE - gate pela capability scSchemas: PostgreSQL/SQLServer
    (scSchemas ON) caem aqui e geram DDL real; SQLite/Firebird/Access
    (scSchemas OFF) devolvem vazio. MySQL faz override (ver
    Database.Dialect.MySQL - schema~=database, gera sempre). }
  Result := '';
  if (Trim(ASchema) = '') or not Supports(scSchemas) then
    Exit;
  Result := 'CREATE SCHEMA ' + QuoteIdentifier(Trim(ASchema)) + ';';
end;

function TDialect.DropSchemaSQL(const ASchema: string): string;
begin
  Result := '';
  if (Trim(ASchema) = '') or not Supports(scSchemas) then
    Exit;
  Result := 'DROP SCHEMA ' + QuoteIdentifier(Trim(ASchema)) + ';';
end;

{ ---- DDL de nivel database (Fatia B-e) ---- }

function TDialect.CreateDatabaseSQL(const AName: string): string;
begin
  { implementacao BASE - SEM gate de capability (ao contrario de
    CreateSchemaSQL/scSchemas): PostgreSQL/MySQL/SQLServer caem aqui e geram
    DDL real via QuoteIdentifier. SQLite/Access fazem override (bases-
    ficheiro, devolvem vazio); Firebird faz override (sintaxe ISQL propria -
    ver Database.Dialect.Firebird). }
  Result := '';
  if Trim(AName) = '' then
    Exit;
  Result := 'CREATE DATABASE ' + QuoteIdentifier(Trim(AName)) + ';';
end;

function TDialect.DropDatabaseSQL(const AName: string): string;
begin
  Result := '';
  if Trim(AName) = '' then
    Exit;
  Result := 'DROP DATABASE ' + QuoteIdentifier(Trim(AName)) + ';';
end;

{ ---- Onda 5.5-B (indices/constraints) ---- }

function TDialect.QuoteColumnList(const AColumns: array of string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AColumns) do
  begin
    if Trim(AColumns[I]) = '' then
      Continue;
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + QuoteIdentifier(Trim(AColumns[I]));
  end;
end;

function TDialect.AddUniqueSQL(const ATable, AName: string;
  const AColumns: array of string): string;
var
  LCols: string;
begin
  { base ANSI: ALTER TABLE ... ADD CONSTRAINT ... UNIQUE (...) - PostgreSQL/
    MySQL/SQLServer/Firebird. SQLite/Access fazem override (CREATE UNIQUE
    INDEX - nao suportam ALTER TABLE ADD CONSTRAINT). }
  Result := '';
  if (Trim(ATable) = '') or (Trim(AName) = '') then
    Exit;
  LCols := QuoteColumnList(AColumns);
  if LCols = '' then
    Exit;
  Result := 'ALTER TABLE ' + QuoteIdentifier(Trim(ATable)) +
    ' ADD CONSTRAINT ' + QuoteIdentifier(Trim(AName)) +
    ' UNIQUE (' + LCols + ')';
end;

function TDialect.CreateIndexSQL(const ATable, AName: string;
  const AColumns: array of string; const AUnique: Boolean): string;
var
  LCols: string;
begin
  { universal: CREATE [UNIQUE] INDEX name ON table (cols) - a base cobre os 6. }
  Result := '';
  if (Trim(ATable) = '') or (Trim(AName) = '') then
    Exit;
  LCols := QuoteColumnList(AColumns);
  if LCols = '' then
    Exit;
  Result := 'CREATE ';
  if AUnique then
    Result := Result + 'UNIQUE ';
  Result := Result + 'INDEX ' + QuoteIdentifier(Trim(AName)) +
    ' ON ' + QuoteIdentifier(Trim(ATable)) + ' (' + LCols + ')';
end;

function TDialect.UniquesSQL(const ATable, ASchema: string): string;
begin
  { base ANSI (information_schema.table_constraints WHERE constraint_type=
    'UNIQUE') - PostgreSQL/MySQL/SQLServer. Resultado 1 coluna [0]=
    constraint_name. Literais escapados (aspas simples duplicadas). SQLite/
    Firebird fazem override; Access -> '' (override). }
  Result := '';
  if Trim(ATable) = '' then
    Exit;
  Result := 'SELECT constraint_name FROM information_schema.table_constraints' +
    ' WHERE constraint_type = ''UNIQUE'' AND table_name = ''' +
    StringReplace(Trim(ATable), '''', '''''', [rfReplaceAll]) + '''';
  if Trim(ASchema) <> '' then
    Result := Result + ' AND table_schema = ''' +
      StringReplace(Trim(ASchema), '''', '''''', [rfReplaceAll]) + '''';
end;

function TDialect.IndexesSQL(const ATable, ASchema: string): string;
begin
  { base '' - nao ha catalogo ANSI universal de indices; cada dialect faz
    override. Access fica na base ('' - sem introspecao fiavel). }
  Result := '';
end;

{ ---- Onda D - faceta FIELD: rotinas polimorficas (base ANSI) + forwarder ---- }

function TDialect.FieldAddSQL(const ATable, AField, AFieldType: string;
  const ANotNull: Boolean): string;
begin
  { base ANSI 'ALTER TABLE t ADD COLUMN col type [NOT NULL]' - PostgreSQL/MySQL/
    SQLite/Access. Firebird e SQL Server sobrepoem (ADD SEM 'COLUMN'). }
  Result := '';
  if (Trim(ATable) = '') or (Trim(AField) = '') then Exit;
  Result := 'ALTER TABLE ' + QuoteIdentifier(Trim(ATable)) + ' ADD COLUMN ' +
    QuoteIdentifier(Trim(AField)) + ' ' + AFieldType;
  if ANotNull then Result := Result + ' NOT NULL';
end;

function TDialect.FieldDropSQL(const ATable, AField: string): string;
begin
  { base ANSI 'ALTER TABLE t DROP COLUMN col'. Firebird sobrepoe (DROP SEM
    'COLUMN'). }
  Result := '';
  if (Trim(ATable) = '') or (Trim(AField) = '') then Exit;
  Result := 'ALTER TABLE ' + QuoteIdentifier(Trim(ATable)) + ' DROP COLUMN ' +
    QuoteIdentifier(Trim(AField));
end;

function TDialect.FieldAlterSQL(const ATable, AField, ANewType: string;
  const ANotNull: Boolean): string;
begin
  { base 'ALTER TABLE t ALTER COLUMN col TYPE x' (PostgreSQL/Firebird). O SET
    NOT NULL no PG e statement separado -> a base NAO o embute. MySQL (MODIFY),
    SQL Server (ALTER COLUMN sem TYPE) e SQLite ('' -> rebuild) sobrepoem. }
  Result := '';
  if (Trim(ATable) = '') or (Trim(AField) = '') then Exit;
  Result := 'ALTER TABLE ' + QuoteIdentifier(Trim(ATable)) + ' ALTER COLUMN ' +
    QuoteIdentifier(Trim(AField)) + ' TYPE ' + ANewType;
end;

function TDialect.FieldRenameSQL(const ATable, AOldName, ANewName: string): string;
begin
  { base ANSI 'ALTER TABLE t RENAME COLUMN a TO b' (PostgreSQL/SQLite 3.25+/
    MySQL 8+). Firebird ('ALTER COLUMN a TO b') e SQL Server ('sp_rename')
    sobrepoem. }
  Result := '';
  if (Trim(ATable) = '') or (Trim(AOldName) = '') or (Trim(ANewName) = '') then Exit;
  Result := 'ALTER TABLE ' + QuoteIdentifier(Trim(ATable)) + ' RENAME COLUMN ' +
    QuoteIdentifier(Trim(AOldName)) + ' TO ' + QuoteIdentifier(Trim(ANewName));
end;

{ forwarder: expoe as rotinas Field* do dialeto sob a API curta AddSQL/DropSQL/
  AlterSQL/RenameSQL. FDialect e back-ref nao-contada (o forwarder e transiente
  - criado por TDialect.Field, usado no mesmo statement). }
type
  TFieldDialect = class(TInterfacedObject, IFieldDialect)
  private
    FDialect: TDialect;
  public
    constructor Create(const ADialect: TDialect);
    function AddSQL(const ATable, AField, AFieldType: string; const ANotNull: Boolean): string;
    function DropSQL(const ATable, AField: string): string;
    function AlterSQL(const ATable, AField, ANewType: string; const ANotNull: Boolean): string;
    function RenameSQL(const ATable, AOldName, ANewName: string): string;
  end;

constructor TFieldDialect.Create(const ADialect: TDialect);
begin
  inherited Create;
  FDialect := ADialect;
end;

function TFieldDialect.AddSQL(const ATable, AField, AFieldType: string; const ANotNull: Boolean): string;
begin Result := FDialect.FieldAddSQL(ATable, AField, AFieldType, ANotNull); end;

function TFieldDialect.DropSQL(const ATable, AField: string): string;
begin Result := FDialect.FieldDropSQL(ATable, AField); end;

function TFieldDialect.AlterSQL(const ATable, AField, ANewType: string; const ANotNull: Boolean): string;
begin Result := FDialect.FieldAlterSQL(ATable, AField, ANewType, ANotNull); end;

function TFieldDialect.RenameSQL(const ATable, AOldName, ANewName: string): string;
begin Result := FDialect.FieldRenameSQL(ATable, AOldName, ANewName); end;

function TDialect.Field: IFieldDialect;
begin
  Result := TFieldDialect.Create(Self);
end;

{ ===== Onda D - rotinas polimorficas base: TABLE/PK/FK/INDEX/UNIQUE/VIEW/ROUTINE ===== }

function TDialect.TableCreateSQL(const ATable, AColumnsClause, ASchema: string): string;
var LQual: string;
begin
  Result := '';
  if (Trim(ATable) = '') or (Trim(AColumnsClause) = '') then Exit;
  if Trim(ASchema) <> '' then
    LQual := QuoteIdentifier(Trim(ASchema)) + '.' + QuoteIdentifier(Trim(ATable))
  else
    LQual := QuoteIdentifier(Trim(ATable));
  Result := 'CREATE TABLE ' + LQual + ' (' + AColumnsClause + ')';
end;

function TDialect.TableDropSQL(const ATable, ASchema: string; const AIfExists: Boolean): string;
var LQual: string;
begin
  Result := '';
  if Trim(ATable) = '' then Exit;
  if Trim(ASchema) <> '' then
    LQual := QuoteIdentifier(Trim(ASchema)) + '.' + QuoteIdentifier(Trim(ATable))
  else
    LQual := QuoteIdentifier(Trim(ATable));
  if AIfExists and Supports(scDropIfExists) then
    Result := 'DROP TABLE IF EXISTS ' + LQual
  else
    Result := 'DROP TABLE ' + LQual;
end;

function TDialect.TableRenameSQL(const AOldName, ANewName: string): string;
begin
  { base ANSI (PostgreSQL/SQLite/MySQL): ALTER TABLE old RENAME TO new. SQL
    Server (sp_rename) e Firebird ('' - sem rename de tabela) sobrepoem. }
  Result := '';
  if (Trim(AOldName) = '') or (Trim(ANewName) = '') then Exit;
  Result := 'ALTER TABLE ' + QuoteIdentifier(Trim(AOldName)) + ' RENAME TO ' +
    QuoteIdentifier(Trim(ANewName));
end;

function TDialect.SchemaRenameSQL(const AOldName, ANewName: string): string;
begin
  Result := ''; { rename de schema raro/nao-portavel -> override onde suportado. }
end;

function TDialect.DatabaseRenameSQL(const AOldName, ANewName: string): string;
begin
  Result := ''; { rename de database raro/nao-portavel. }
end;

function TDialect.IndexDropSQL(const ATable, AName: string): string;
begin
  { base 'DROP INDEX name' (PostgreSQL/SQLite/Firebird). MySQL/SQL Server
    ('DROP INDEX name ON t') sobrepoem. }
  Result := '';
  if Trim(AName) = '' then Exit;
  Result := 'DROP INDEX ' + QuoteIdentifier(Trim(AName));
end;

function TDialect.UniqueDropSQL(const ATable, AName: string): string;
begin
  { base 'ALTER TABLE t DROP CONSTRAINT name' (PostgreSQL/SQL Server/Firebird).
    MySQL/SQLite/Access ('DROP INDEX') sobrepoem. }
  Result := '';
  if (Trim(ATable) = '') or (Trim(AName) = '') then Exit;
  Result := 'ALTER TABLE ' + QuoteIdentifier(Trim(ATable)) + ' DROP CONSTRAINT ' +
    QuoteIdentifier(Trim(AName));
end;

function TDialect.PKeyAddSQL(const ATable, AName: string; const AColumns: array of string): string;
var LCols: string;
begin
  Result := '';
  if (Trim(ATable) = '') or (Trim(AName) = '') then Exit;
  LCols := QuoteColumnList(AColumns);
  if LCols = '' then Exit;
  Result := 'ALTER TABLE ' + QuoteIdentifier(Trim(ATable)) + ' ADD CONSTRAINT ' +
    QuoteIdentifier(Trim(AName)) + ' PRIMARY KEY (' + LCols + ')';
end;

function TDialect.PKeyDropSQL(const ATable, AName: string): string;
begin
  { base 'ALTER TABLE t DROP CONSTRAINT name'. MySQL ('DROP PRIMARY KEY') sobrepoe. }
  Result := '';
  if Trim(ATable) = '' then Exit;
  Result := 'ALTER TABLE ' + QuoteIdentifier(Trim(ATable)) + ' DROP CONSTRAINT ' +
    QuoteIdentifier(Trim(AName));
end;

function TDialect.FKeyAddSQL(const ATable, AName: string; const AColumns: array of string;
  const ARefTable: string; const ARefColumns: array of string;
  const AOnDelete, AOnUpdate: string): string;
var LCols, LRefCols: string;
begin
  Result := '';
  if (Trim(ATable) = '') or (Trim(AName) = '') or (Trim(ARefTable) = '') then Exit;
  LCols := QuoteColumnList(AColumns);
  LRefCols := QuoteColumnList(ARefColumns);
  if (LCols = '') or (LRefCols = '') then Exit;
  Result := 'ALTER TABLE ' + QuoteIdentifier(Trim(ATable)) + ' ADD CONSTRAINT ' +
    QuoteIdentifier(Trim(AName)) + ' FOREIGN KEY (' + LCols + ') REFERENCES ' +
    QuoteIdentifier(Trim(ARefTable)) + ' (' + LRefCols + ')';
  if Trim(AOnDelete) <> '' then Result := Result + ' ON DELETE ' + Trim(AOnDelete);
  if Trim(AOnUpdate) <> '' then Result := Result + ' ON UPDATE ' + Trim(AOnUpdate);
end;

function TDialect.FKeyDropSQL(const ATable, AName: string): string;
begin
  { base 'ALTER TABLE t DROP CONSTRAINT name'. MySQL ('DROP FOREIGN KEY') sobrepoe. }
  Result := '';
  if Trim(ATable) = '' then Exit;
  Result := 'ALTER TABLE ' + QuoteIdentifier(Trim(ATable)) + ' DROP CONSTRAINT ' +
    QuoteIdentifier(Trim(AName));
end;

function TDialect.ViewCreateSQL(const AName, ASelectSQL: string; const AOrReplace: Boolean): string;
begin
  { base 'CREATE [OR REPLACE] VIEW n AS s' (PostgreSQL/MySQL/SQLite/Firebird).
    SQL Server (CREATE OR ALTER VIEW) sobrepoe. }
  Result := '';
  if (Trim(AName) = '') or (Trim(ASelectSQL) = '') then Exit;
  Result := 'CREATE ';
  if AOrReplace then Result := Result + 'OR REPLACE ';
  Result := Result + 'VIEW ' + QuoteIdentifier(Trim(AName)) + ' AS ' + ASelectSQL;
end;

function TDialect.ViewDropSQL(const AName: string; const AIfExists: Boolean): string;
begin
  Result := '';
  if Trim(AName) = '' then Exit;
  if AIfExists and Supports(scDropIfExists) then
    Result := 'DROP VIEW IF EXISTS ' + QuoteIdentifier(Trim(AName))
  else
    Result := 'DROP VIEW ' + QuoteIdentifier(Trim(AName));
end;

function TDialect.ViewAlterSQL(const AName, ASelectSQL: string): string;
begin
  Result := ViewCreateSQL(AName, ASelectSQL, True); { alterar = CREATE OR REPLACE. }
end;

function TDialect.RoutineCreateSQL(const AName, ABody: string; const AIsFunction: Boolean): string;
begin
  { corpo de procedure/function e especifico de cada banco -> pass-through do
    ABody (o caller fornece o CREATE completo, "conforme cada banco"). }
  Result := Trim(ABody);
end;

function TDialect.RoutineDefCreateSQL(const ADef: IRoutineDefinition): string;
begin
  { Onda F1 - BASE: motores sem stored routines (SQLite/Access) -> '' (o
    lancador degrada para no-op/0). Os 5 motores com rotinas fazem override e
    compoem o CREATE por-banco a partir do builder (nome via QuoteIdentifier,
    tipos via ColumnTypeFor). }
  Result := '';
end;

function TDialect.RoutineDropSQL(const AName: string; const AIsFunction, AIfExists: Boolean): string;
var LKind: string;
begin
  Result := '';
  if Trim(AName) = '' then Exit;
  if AIsFunction then LKind := 'FUNCTION' else LKind := 'PROCEDURE';
  if AIfExists and Supports(scDropIfExists) then
    Result := 'DROP ' + LKind + ' IF EXISTS ' + QuoteIdentifier(Trim(AName))
  else
    Result := 'DROP ' + LKind + ' ' + QuoteIdentifier(Trim(AName));
end;

{ ===== Onda F3 - triggers (helpers + base) ===== }

function TDialect.TriggerTimingWord(const ATiming: TTriggerTiming): string;
begin
  case ATiming of
    ttAfter:     Result := 'AFTER';
    ttInsteadOf: Result := 'INSTEAD OF';
  else
    Result := 'BEFORE';
  end;
end;

function TDialect.TriggerEventsClause(const AEvents: TTriggerEvents; const ASeparator: string): string;
var
  LEv: TTriggerEvents;
begin
  { conjunto vazio -> assume INSERT (nunca gerar CREATE TRIGGER sem evento). }
  LEv := AEvents;
  if LEv = [] then
    LEv := [teInsert];
  Result := '';
  if teInsert in LEv then Result := 'INSERT';
  if teUpdate in LEv then
  begin
    if Result <> '' then Result := Result + ASeparator;
    Result := Result + 'UPDATE';
  end;
  if teDelete in LEv then
  begin
    if Result <> '' then Result := Result + ASeparator;
    Result := Result + 'DELETE';
  end;
end;

function TDialect.TriggerFirstEventWord(const AEvents: TTriggerEvents): string;
begin
  { motores mono-evento (MySQL/SQLite): usa o primeiro evento presente. }
  if teInsert in AEvents then Result := 'INSERT'
  else if teUpdate in AEvents then Result := 'UPDATE'
  else if teDelete in AEvents then Result := 'DELETE'
  else Result := 'INSERT';
end;

function TDialect.TriggersSQL(const ASchema: string): string;
begin
  { BASE - motor sem catalogo de triggers introspetavel (Access) -> ''. Os
    6 motores com triggers fazem override. }
  Result := '';
end;

function TDialect.TriggerDefCreateSQL(const ADef: ITriggerDefinition): string;
begin
  { BASE - motor sem triggers (Access) -> '' (o lancador degrada para no-op/0).
    PostgreSQL/MySQL/SQLServer/Firebird/SQLite/SQLAnywhere fazem override. }
  Result := '';
end;

function TDialect.TriggerDropSQL(const AName, ATable: string; const AIfExists: Boolean): string;
begin
  { BASE ANSI - 'DROP TRIGGER [IF EXISTS] n' (cobre SQLite/MySQL/SQLServer).
    PostgreSQL (ON table + drop FUNCTION), Firebird/SQLAnywhere (sem IF EXISTS)
    fazem override. }
  Result := '';
  if Trim(AName) = '' then
    Exit;
  if AIfExists and Supports(scDropIfExists) then
    Result := 'DROP TRIGGER IF EXISTS ' + QuoteIdentifier(Trim(AName))
  else
    Result := 'DROP TRIGGER ' + QuoteIdentifier(Trim(AName));
end;

{ ===== Onda F4 - rules (base '' - so PostgreSQL/SQL Server fazem override) ===== }

function TDialect.RulesSQL(const ASchema: string): string;
begin
  Result := '';
end;

function TDialect.RuleDefCreateSQL(const ADef: IRuleDefinition): string;
begin
  Result := '';
end;

function TDialect.RuleDropSQL(const AName, ATable: string; const AIfExists: Boolean): string;
begin
  Result := '';
end;

{ ===== Onda D - forwarders das facetas (verbos curtos -> rotinas do dialeto) ===== }
type
  TTableDialect = class(TInterfacedObject, ITableDialect)
  private FDialect: TDialect;
  public
    constructor Create(const ADialect: TDialect);
    function CreateSQL(const ATable, AColumnsClause, ASchema: string): string;
    function DropSQL(const ATable, ASchema: string; const AIfExists: Boolean): string;
    function RenameSQL(const AOldName, ANewName: string): string;
  end;
  TSchemaDialect = class(TInterfacedObject, ISchemaDialect)
  private FDialect: TDialect;
  public
    constructor Create(const ADialect: TDialect);
    function CreateSQL(const ASchema: string): string;
    function DropSQL(const ASchema: string): string;
    function RenameSQL(const AOldName, ANewName: string): string;
  end;
  TDatabaseDialect = class(TInterfacedObject, IDatabaseDialect)
  private FDialect: TDialect;
  public
    constructor Create(const ADialect: TDialect);
    function CreateSQL(const AName: string): string;
    function DropSQL(const AName: string): string;
    function RenameSQL(const AOldName, ANewName: string): string;
  end;
  TIndexDialect = class(TInterfacedObject, IIndexDialect)
  private FDialect: TDialect;
  public
    constructor Create(const ADialect: TDialect);
    function CreateSQL(const ATable, AName: string; const AColumns: array of string; const AUnique: Boolean): string;
    function DropSQL(const ATable, AName: string): string;
  end;
  TUniqueDialect = class(TInterfacedObject, IUniqueDialect)
  private FDialect: TDialect;
  public
    constructor Create(const ADialect: TDialect);
    function AddSQL(const ATable, AName: string; const AColumns: array of string): string;
    function DropSQL(const ATable, AName: string): string;
  end;
  TPKeyDialect = class(TInterfacedObject, IPKeyDialect)
  private FDialect: TDialect;
  public
    constructor Create(const ADialect: TDialect);
    function AddSQL(const ATable, AName: string; const AColumns: array of string): string;
    function DropSQL(const ATable, AName: string): string;
  end;
  TFKeyDialect = class(TInterfacedObject, IFKeyDialect)
  private FDialect: TDialect;
  public
    constructor Create(const ADialect: TDialect);
    function AddSQL(const ATable, AName: string; const AColumns: array of string;
      const ARefTable: string; const ARefColumns: array of string;
      const AOnDelete, AOnUpdate: string): string;
    function DropSQL(const ATable, AName: string): string;
  end;
  TViewDialect = class(TInterfacedObject, IViewDialect)
  private FDialect: TDialect;
  public
    constructor Create(const ADialect: TDialect);
    function CreateSQL(const AName, ASelectSQL: string; const AOrReplace: Boolean): string;
    function DropSQL(const AName: string; const AIfExists: Boolean): string;
    function AlterSQL(const AName, ASelectSQL: string): string;
  end;
  TRoutineDialect = class(TInterfacedObject, IRoutineDialect)
  private FDialect: TDialect;
  public
    constructor Create(const ADialect: TDialect);
    function CreateSQL(const AName, ABody: string; const AIsFunction: Boolean): string; overload;
    function CreateSQL(const ADef: IRoutineDefinition): string; overload;
    function DropSQL(const AName: string; const AIsFunction, AIfExists: Boolean): string;
  end;
  TTriggerDialect = class(TInterfacedObject, ITriggerDialect)
  private FDialect: TDialect;
  public
    constructor Create(const ADialect: TDialect);
    function CreateSQL(const ADef: ITriggerDefinition): string;
    function DropSQL(const AName, ATable: string; const AIfExists: Boolean): string;
  end;
  TRuleDialect = class(TInterfacedObject, IRuleDialect)
  private FDialect: TDialect;
  public
    constructor Create(const ADialect: TDialect);
    function CreateSQL(const ADef: IRuleDefinition): string;
    function DropSQL(const AName, ATable: string; const AIfExists: Boolean): string;
  end;

constructor TTableDialect.Create(const ADialect: TDialect); begin inherited Create; FDialect := ADialect; end;
function TTableDialect.CreateSQL(const ATable, AColumnsClause, ASchema: string): string;
begin Result := FDialect.TableCreateSQL(ATable, AColumnsClause, ASchema); end;
function TTableDialect.DropSQL(const ATable, ASchema: string; const AIfExists: Boolean): string;
begin Result := FDialect.TableDropSQL(ATable, ASchema, AIfExists); end;
function TTableDialect.RenameSQL(const AOldName, ANewName: string): string;
begin Result := FDialect.TableRenameSQL(AOldName, ANewName); end;

constructor TSchemaDialect.Create(const ADialect: TDialect); begin inherited Create; FDialect := ADialect; end;
function TSchemaDialect.CreateSQL(const ASchema: string): string;
begin Result := FDialect.CreateSchemaSQL(ASchema); end;
function TSchemaDialect.DropSQL(const ASchema: string): string;
begin Result := FDialect.DropSchemaSQL(ASchema); end;
function TSchemaDialect.RenameSQL(const AOldName, ANewName: string): string;
begin Result := FDialect.SchemaRenameSQL(AOldName, ANewName); end;

constructor TDatabaseDialect.Create(const ADialect: TDialect); begin inherited Create; FDialect := ADialect; end;
function TDatabaseDialect.CreateSQL(const AName: string): string;
begin Result := FDialect.CreateDatabaseSQL(AName); end;
function TDatabaseDialect.DropSQL(const AName: string): string;
begin Result := FDialect.DropDatabaseSQL(AName); end;
function TDatabaseDialect.RenameSQL(const AOldName, ANewName: string): string;
begin Result := FDialect.DatabaseRenameSQL(AOldName, ANewName); end;

constructor TIndexDialect.Create(const ADialect: TDialect); begin inherited Create; FDialect := ADialect; end;
function TIndexDialect.CreateSQL(const ATable, AName: string; const AColumns: array of string; const AUnique: Boolean): string;
begin Result := FDialect.CreateIndexSQL(ATable, AName, AColumns, AUnique); end;
function TIndexDialect.DropSQL(const ATable, AName: string): string;
begin Result := FDialect.IndexDropSQL(ATable, AName); end;

constructor TUniqueDialect.Create(const ADialect: TDialect); begin inherited Create; FDialect := ADialect; end;
function TUniqueDialect.AddSQL(const ATable, AName: string; const AColumns: array of string): string;
begin Result := FDialect.AddUniqueSQL(ATable, AName, AColumns); end;
function TUniqueDialect.DropSQL(const ATable, AName: string): string;
begin Result := FDialect.UniqueDropSQL(ATable, AName); end;

constructor TPKeyDialect.Create(const ADialect: TDialect); begin inherited Create; FDialect := ADialect; end;
function TPKeyDialect.AddSQL(const ATable, AName: string; const AColumns: array of string): string;
begin Result := FDialect.PKeyAddSQL(ATable, AName, AColumns); end;
function TPKeyDialect.DropSQL(const ATable, AName: string): string;
begin Result := FDialect.PKeyDropSQL(ATable, AName); end;

constructor TFKeyDialect.Create(const ADialect: TDialect); begin inherited Create; FDialect := ADialect; end;
function TFKeyDialect.AddSQL(const ATable, AName: string; const AColumns: array of string;
  const ARefTable: string; const ARefColumns: array of string; const AOnDelete, AOnUpdate: string): string;
begin Result := FDialect.FKeyAddSQL(ATable, AName, AColumns, ARefTable, ARefColumns, AOnDelete, AOnUpdate); end;
function TFKeyDialect.DropSQL(const ATable, AName: string): string;
begin Result := FDialect.FKeyDropSQL(ATable, AName); end;

constructor TViewDialect.Create(const ADialect: TDialect); begin inherited Create; FDialect := ADialect; end;
function TViewDialect.CreateSQL(const AName, ASelectSQL: string; const AOrReplace: Boolean): string;
begin Result := FDialect.ViewCreateSQL(AName, ASelectSQL, AOrReplace); end;
function TViewDialect.DropSQL(const AName: string; const AIfExists: Boolean): string;
begin Result := FDialect.ViewDropSQL(AName, AIfExists); end;
function TViewDialect.AlterSQL(const AName, ASelectSQL: string): string;
begin Result := FDialect.ViewAlterSQL(AName, ASelectSQL); end;

constructor TRoutineDialect.Create(const ADialect: TDialect); begin inherited Create; FDialect := ADialect; end;
function TRoutineDialect.CreateSQL(const AName, ABody: string; const AIsFunction: Boolean): string;
begin Result := FDialect.RoutineCreateSQL(AName, ABody, AIsFunction); end;
function TRoutineDialect.CreateSQL(const ADef: IRoutineDefinition): string;
begin Result := FDialect.RoutineDefCreateSQL(ADef); end;
function TRoutineDialect.DropSQL(const AName: string; const AIsFunction, AIfExists: Boolean): string;
begin Result := FDialect.RoutineDropSQL(AName, AIsFunction, AIfExists); end;

constructor TTriggerDialect.Create(const ADialect: TDialect); begin inherited Create; FDialect := ADialect; end;
function TTriggerDialect.CreateSQL(const ADef: ITriggerDefinition): string;
begin Result := FDialect.TriggerDefCreateSQL(ADef); end;
function TTriggerDialect.DropSQL(const AName, ATable: string; const AIfExists: Boolean): string;
begin Result := FDialect.TriggerDropSQL(AName, ATable, AIfExists); end;

constructor TRuleDialect.Create(const ADialect: TDialect); begin inherited Create; FDialect := ADialect; end;
function TRuleDialect.CreateSQL(const ADef: IRuleDefinition): string;
begin Result := FDialect.RuleDefCreateSQL(ADef); end;
function TRuleDialect.DropSQL(const AName, ATable: string; const AIfExists: Boolean): string;
begin Result := FDialect.RuleDropSQL(AName, ATable, AIfExists); end;

function TDialect.Table: ITableDialect; begin Result := TTableDialect.Create(Self); end;
function TDialect.Schema: ISchemaDialect; begin Result := TSchemaDialect.Create(Self); end;
function TDialect.Database: IDatabaseDialect; begin Result := TDatabaseDialect.Create(Self); end;
function TDialect.Index: IIndexDialect; begin Result := TIndexDialect.Create(Self); end;
function TDialect.Unique: IUniqueDialect; begin Result := TUniqueDialect.Create(Self); end;
function TDialect.PKey: IPKeyDialect; begin Result := TPKeyDialect.Create(Self); end;
function TDialect.FKey: IFKeyDialect; begin Result := TFKeyDialect.Create(Self); end;
function TDialect.View: IViewDialect; begin Result := TViewDialect.Create(Self); end;
function TDialect.Routine: IRoutineDialect; begin Result := TRoutineDialect.Create(Self); end;
function TDialect.Trigger: ITriggerDialect; begin Result := TTriggerDialect.Create(Self); end;
function TDialect.Rule: IRuleDialect; begin Result := TRuleDialect.Create(Self); end;

{ ---- Onda 6-a (I22) - deteccao de versao ---- }

function TDialect.DetectVersion(const AConnection: IConnection): string;
begin
  { implementacao BASE uniforme - reusa IConnection.GetServerVersion (kernel
    F4, engine-aware); '' se nil ou sem conexao activa (mesma semantica do
    kernel). Nenhum dialecto precisa de override - a deteccao NAO e SQL
    proprio do dialecto, e delegacao pura ao kernel de Connections. }
  Result := '';
  if AConnection = nil then
    Exit;
  Result := AConnection.GetServerVersion;
end;

{ ---- Onda 6-a (I21) - literais de data/timestamp ---- }

function TDialect.DateLiteral(const ADate: TDateTime): string;
begin
  { base ANSI - MySQL/SQLServer/SQLite/Firebird usam esta implementacao sem
    override (mesmo formato 'aaaa-mm-dd'); PostgreSQL prefixa DATE (override);
    Access usa #...# (override). }
  Result := '''' + FormatDateTime('yyyy-mm-dd', ADate) + '''';
end;

function TDialect.TimestampLiteral(const ADateTime: TDateTime): string;
begin
  Result := '''' + FormatDateTime('yyyy-mm-dd hh:nn:ss', ADateTime) + '''';
end;

function TDialect.TryParseDateLiteral(const ALiteral: string; out ADate: TDateTime): Boolean;
var
  LCore: string;
  LYear, LMonth, LDay, LHour, LMin, LSec: Integer;
  LHasTime: Boolean;
begin
  { parser UNICO partilhado por todos os dialectos - reconhece os 3 formatos
    emitidos por DateLiteral/TimestampLiteral: ANSI simples ('aaaa-mm-dd'),
    tipado PostgreSQL (DATE '...'/TIMESTAMP '...') e Access (#...#). }
  Result := False;
  ADate := 0;
  LCore := Trim(ALiteral);
  if (Length(LCore) > 5) and (UpperCase(Copy(LCore, 1, 5)) = 'DATE ') then
    LCore := Trim(Copy(LCore, 6, MaxInt))
  else if (Length(LCore) > 10) and (UpperCase(Copy(LCore, 1, 10)) = 'TIMESTAMP ') then
    LCore := Trim(Copy(LCore, 11, MaxInt));
  if (Length(LCore) >= 2) and (LCore[1] = '''') and (LCore[Length(LCore)] = '''') then
    LCore := Copy(LCore, 2, Length(LCore) - 2)
  else if (Length(LCore) >= 2) and (LCore[1] = '#') and (LCore[Length(LCore)] = '#') then
    LCore := Copy(LCore, 2, Length(LCore) - 2)
  else
    Exit(False);
  LHasTime := Length(LCore) = 19;
  if (Length(LCore) <> 10) and not LHasTime then
    Exit(False);
  if (LCore[5] <> '-') or (LCore[8] <> '-') then
    Exit(False);
  LYear := StrToIntDef(Copy(LCore, 1, 4), -1);
  LMonth := StrToIntDef(Copy(LCore, 6, 2), -1);
  LDay := StrToIntDef(Copy(LCore, 9, 2), -1);
  if (LYear < 1) or (LMonth < 1) or (LMonth > 12) or (LDay < 1) or (LDay > 31) then
    Exit(False);
  LHour := 0; LMin := 0; LSec := 0;
  if LHasTime then
  begin
    if (LCore[11] <> ' ') or (LCore[14] <> ':') or (LCore[17] <> ':') then
      Exit(False);
    LHour := StrToIntDef(Copy(LCore, 12, 2), -1);
    LMin := StrToIntDef(Copy(LCore, 15, 2), -1);
    LSec := StrToIntDef(Copy(LCore, 18, 2), -1);
    if (LHour < 0) or (LHour > 23) or (LMin < 0) or (LMin > 59) or (LSec < 0) or (LSec > 59) then
      Exit(False);
  end;
  try
    ADate := EncodeDate(LYear, LMonth, LDay) + EncodeTime(LHour, LMin, LSec, 0);
    Result := True;
  except
    Result := False;
  end;
end;

{ ---- Onda 6-d PARTE 2 (I24) - descricoes de coluna ---- }

function TDialect.ColumnDescriptionSQL(const ATable, ASchema: string): string;
begin
  { implementacao BASE - nao suportado (SQLite/Access, sem catalogo de
    descricoes de coluna padrao) - devolve vazio; ICatalogReader.TableStructure
    trata vazio como no-op gracioso (Description fica ''). }
  Result := '';
end;

{ ---- F5-FU.1 - colunas AUTOINCREMENTO/IDENTITY ---- }

function TDialect.IdentityColumnsSQL(const ATableName, ASchema: string): string;
begin
  { implementacao BASE - nao suportado (SQLAnywhere/SQLite/Access, sem
    catalogo dedicado fiavel de colunas autoincremento) - devolve vazio;
    ICatalogReader.TableStructure/ApplyColumnIdentity trata vazio como no-op
    gracioso (IsIdentity fica 0). }
  Result := '';
end;

{ ---- Onda 6-e Estagio 3 (I13) - chamada de funcao escalar canonica ---- }

function TDialect.FunctionSQL(const AName: string; const AArgs: array of string): string;
var
  I: Integer;
  LJoined: string;
begin
  { implementacao BASE generica ANSI - cobre UPPER(x)/LOWER(x)/COALESCE(a,b,..)/
    LENGTH(x)/SUBSTRING(x,p,n) (forma com virgulas, aceite por MySQL/PostgreSQL/
    SQLServer) e qualquer outra funcao ANSI-compativel: "NOME(arg0, arg1, ...)"
    maiusculizado - os descendentes com sintaxe divergente fazem override
    (SQLServer: LEN; Firebird: CHAR_LENGTH + SUBSTRING FROM/FOR; SQLite:
    SUBSTR; Access: UCASE/LCASE/LEN/MID/NZ aninhado). }
  LJoined := '';
  for I := 0 to High(AArgs) do
  begin
    if LJoined <> '' then LJoined := LJoined + ', ';
    LJoined := LJoined + AArgs[I];
  end;
  Result := UpperCase(Trim(AName)) + '(' + LJoined + ')';
end;

{ ---- Onda 6-f Estagio 1 (I10) - linked servers + stored procedures ---- }

function TDialect.LinkedServersSQL: string;
begin
  { implementacao BASE - nao suportado (PostgreSQL fica aqui de proposito -
    ver comentario na interface; MySQL/Firebird/SQLite/Access idem) -
    devolve vazio; ICatalogReader.LinkedServerNames trata vazio como [] gracioso. }
  Result := '';
end;

function TDialect.ProceduresSQL(const ASchema: string): string;
begin
  { implementacao BASE - nao suportado (SQLite/Access, sem stored procedures)
    - devolve vazio; ICatalogReader.ProcedureNames trata vazio como [] gracioso. }
  Result := '';
end;

function TDialect.FunctionsSQL(const ASchema: string): string;
begin
  { implementacao BASE (Onda C6, #4) - nao suportado (SQLite/Access/SQL
    Anywhere, sem catalogo de functions de utilizador introspetavel/validado)
    - devolve vazio; ICatalogReader.FunctionNames trata vazio como [] gracioso. }
  Result := '';
end;

function TDialect.ViewsSQL(const ASchema: string): string;
begin
  { Onda D (D.1) BASE - information_schema.views (PG/MySQL/SQLServer/SQL Anywhere).
    Firebird/SQLite fazem override. 1 coluna [0]=view name. }
  Result := 'SELECT table_name FROM information_schema.views';
  if Trim(ASchema) <> '' then
    Result := Result + ' WHERE table_schema = ''' +
      StringReplace(Trim(ASchema), '''', '''''', [rfReplaceAll]) + '''';
end;

function TDialect.CallProcedureSQL(const AProcName: string; const AArgCount: Integer): string;
begin
  { implementacao BASE - no-op (SQLite/Access, sem sintaxe de chamada de
    procedure) - devolve vazio; IQueryBuilder.CallProcedure trata vazio como
    ToSQL=''/Execute no-op. }
  Result := '';
end;

{$ENDIF}

end.
