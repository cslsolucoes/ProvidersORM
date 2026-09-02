{ ==========================================================================
  PROVENANCE NOTE (ProvidersORM v3, FASE 10 Onda 10.2 - USE_PROVIDERS_V161):
  Absorbed VERBATIM from FontesReferencias/ProvidersORM.v1.6.1/Providers.v161.pas
  into this v3 tree as part of the USE_PROVIDERS_V161 compatibility subsystem
  (legacy ProvidersORM v1.6.1, mechanical port only - zero logic/behavior/
  symbol-name changes; see the unit's own original header below for the
  authorial history). Reachable via uses Providers.v161 - NOT part of the
  unified TProviders facade (Main/Providers.pas).

  NOTE ON THIS COMMENT BLOCK (12/08/2026): earlier in this same wave a
  concurrent edit added prose here quoting literal IFDEF/ENDIF directive
  syntax inside backticks - since that text sat inside THIS SAME curly-brace
  comment, the embedded closing brace of the quoted directive prematurely
  terminated the comment and broke compilation (E2038/E2280 cascade,
  confirmed empirically via dcc32). Rewritten below without embedded braces
  to fix that self-inflicted syntax bug; substance preserved.

  MECHANICAL FIXES APPLIED (zero logic/behavior/symbol-name change, only
  conditional-compilation guards corrected to match what the file's own
  uses clause actually imports per compiler):
  - 6 sites changed the MSWINDOWS-only IFDEF guard to also exclude FPC
    (equivalent to MSWINDOWS and not FPC), and 1 LINUX-only IFDEF guard was
    widened to also include FPC (equivalent to LINUX or FPC). Rationale: FPC
    auto-defines MSWINDOWS on Windows targets too (confirmed project-wide,
    e.g. Loggers.pas guards MSWINDOWS-only VCL code with an outer NOT-FPC
    check), but this unit's own uses clause only imports Vcl.*/cxTextEdit/
    RzPanel under the Delphi+MSWINDOWS branch, never under FPC - so a bare
    MSWINDOWS-only guard was leaking VCL/DevExpress/Raize-typed code
    (Changedfields overloads, ShowMessage, FillInData, ...) into the
    FPC+Windows compile path where those units/types are not imported. This
    mirrors the guard pattern already used elsewhere in this project.
  - Encoding: file re-saved as UTF-8 with BOM (project rule, was UTF-8
    without BOM in the source snapshot; content itself was already valid
    UTF-8, no re-encoding of characters was necessary here).

  KNOWN LIMITATION (FPC target, documented per task instruction, not fixed):
  USE_PROVIDERS_V161 does not compile under FPC in this toolchain. The
  file's own FPC branch of the uses clause (near the top of the interface
  section) references a bare unit named JSon that does not exist anywhere in
  this project's FPC search paths (FPC/Lazarus ships fpjson/jsonparser,
  never a unit literally named JSon). Even past that, the unit uses Delphi's
  fluent System.JSON API (TJSONObject.Create.AddPair(...).AddPair(...),
  TJSONArray, TJSONValue.ParseJSONValue) pervasively and unconditionally
  (not gated by an FPC check) - fpjson's API is not source-compatible with
  this fluent chaining style. Bridging this would require a new
  System.JSON-compatible shim over fpjson (substantial new code, not a
  mechanical fix, and not authorized by the verbatim-transport mandate for
  this unit). This subsystem is Delphi+Windows-only in practice (dcc32/
  dcc64), matching its own header's admission that it depends on
  UniDAC/DevExpress/Raize.
  ========================================================================== }

{
  Provider para banco de dados Firebird, MySQL, MariaDB, PostgreSQL, SQLite, SQL Server (UNIDAC)
  Versão: 1.6.1
  Autor: Claiton de Souza Linhares
  Criação: 27/01/2025

  NOTA (ProvidersORM v2.3.0): unit SUPERSEDED pela fachada unificada
  src/Main/Providers.pas — mantida por compatibilidade, sem remoção agendada.
  Acesso via fachada: TProviders.LegacyV161 sob USE_PROVIDERS_V161 (modo
  EXCLUDENTE — desativa os demais módulos da fachada; ver ORM.Defines.inc).

  REFATORAÇÃO v1.6.1:
  - Utiliza módulos e commons criados (Providers.Common.* e Providers.Module.*)
  - Mantém 100% de compatibilidade com v1.6.0
  - Código mais organizado e modular
  - Melhor manutenibilidade e testabilidade
}
unit Providers.v161;

{$ifdef FPC}
  {$MODE DELPHI}{$H+}
{$endif}

interface

uses
{$IFDEF FPC}
  Classes, SysUtils, StrUtils, DateUtils, DB, JSon, Inifiles,
{$ELSE}
  {$IFDEF MSWINDOWS}
    Winapi.Windows, Winapi.Messages,
    Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
    cxTextEdit, cxCurrencyEdit,
    RzPanel, RzTabs, RzEdit, RzDTP,
  {$ENDIF}
    System.SysUtils, System.Variants, System.Classes, System.JSON, system.JSON.Utils, System.StrUtils,
    System.DateUtils, Data.DB, System.Generics.Collections, System.IniFiles, System.IOUtils,
    System.RegularExpressions,
{$ENDIF}
  // UNIDAC Components
  DBAccess, Uni, MemDS, UniProvider, PostgreSQLUniProvider, SQLServerUniProvider, MySQLUniProvider,
  InterBaseUniProvider, SQLiteUniProvider, VirtualTable, VirtualQuery, IdHashMessageDigest,
  
  // Pacote Indy
  IdHTTP, IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient,
  IdExplicitTLSClientServerBase, IdFTP, IdURI, IdException, IdFTPCommon, IdSMTP, IdSSLOpenSSL, IdMessage,
  IdText, IdAttachmentFile, IdIOHandler, IdIOHandlerSocket, IdIOHandlerStack, IdSSL, IdMessageClient,
  
  // Horse
  DataSet.Serialize, DataSet.Serialize.Config,
  
  // Additional Units
  Utilities.Strings, Utilities.Types,
  
  // Módulos e Commons v1.6.1
  Providers.Common.SQLBuilder,
  Providers.Common.TypeConverter,
  Providers.Common.Connection,
  Providers.Common.FieldHelper,
  Providers.Module.CRUD,
  Providers.Module.FieldManager;

const
{$IFDEF FPC}
  ;
{$ELSE}
  LineEnding = #13#10;
  EmptyStr = '';

  {$IFDEF MSWINDOWS}
    DirectorySeparator = '\';
  {$ELSE}
    DirectorySeparator = '/';
  {$ENDIF}
{$ENDIF}

{$IFDEF DEBUG}
  Debug = True;
{$ELSE}
  Debug = False;
{$ENDIF}

  StatusMsg = #13'Baixando arquivo em %s of %s ( %s ) ';
  FVersaoProvider = '1.6.1';

type
  TProviders = class(TDataModule)
    FPostgresSQL         : TPostgreSQLUniProvider;
    ReturnQry            : TUniQuery;
    Qry                  : TUniQuery;
    FConnL               : TUniConnection;
    FMySQL               : TMySQLUniProvider;
    FSQLServer           : TSQLServerUniProvider;
    FSQLite              : TSQLiteUniProvider;
    FInterBase           : TInterBaseUniProvider;
    FField               : TVirtualTable;
    qryVirutal           : TVirtualQuery;
    FFieldPKey           : TVirtualTable;
    FConn: TUniConnection;

    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
    procedure On_AfterScroll(DataSet: TDataSet);

  private
    FId : Integer;
    Const
      FVersaoProvider = '1.6.1';

  Protected
    FFileINI              : String;
    FSession              : String;
    FDadosINIJson         : TJSONObject;

    FStatus               : TProviderstatus;
    FProvider             : TDatabaseProvider;
    FProviderName         : String;
    FHost                 : String;
    FPort                 : Integer;
    FDataBase             : String;
    FUsername             : String;
    FPassword             : String;
    FURL_Base             : String;

    // Table Properties
    FSchema               : String;
    FTable                : String;
    FTableAlias           : String;
    FTableTexto           : String;
    FSQLText              : String;
    FPrimaryKey           : String;
    FPrimaryKeySQL        : String;
    FSchemaTable          : TJSONArray;
    FFields               : TJSONArray;
    FFieldsList           : String;
    FFieldsFilter         : String;
    FFieldsAdditional     : String;
    FFieldsPKey           : String;
    FFilterSQL            : String;
    FFilterSQLAdditional  : String;
    FOrder                : String;
    FFieldsIdFormat       : Boolean;
    FFieldsUpdate         : String;
    FFieldsInsert         : String;

    // Properties dados
    FFieldsType           : String;
    FDeleted              : Boolean;
    FTablePrefix          : String;
    FDeletedBlock         : Boolean;
    FFieldActived         : String;
    FFieldDate            : String;
    FFieldDateUpdate      : String;
    FFieldsExcluded       : String;
    FFieldsExcludedFilter : String;
    FFieldsDeleted        : String;
    FTipoVariavel         : TTipoVariavel;

    // Return Properties
    FReturn               : String;
    FReturnJsonArr        : TJSONArray;
    FReturnJsonObj        : TJSONObject;
    FReturnJsonVle        : TJSONValue;

    FConnectionString     : String;

    function getFConn          : Boolean;
    function getSQLTables      : String;
    function getSQLPrimaryKey  : TDataSet;
    function getSQLFields      : TDataSet;
    function getSQLFieldsList  : TDataSet;
    function getFilterArrayStr : TStringArray;
    function geTProvidersMasterName(AProvider: TDatabaseProvider): String;
    function getLast12Months   : TJSONArray;
    Function CreateQuery(const ASQL: String): TUniQuery;
    function LoadINI: Boolean;
    function SaveINI: Boolean;

  public
    constructor Create; reintroduce;
    destructor Destroy; override;

    // Properties - Connection
    property Conn                : TUniConnection    read FConn                write FConn;
    property ConnStatus          : Boolean           read getFConn;
    property DbStatus            : TProviderstatus   read FStatus              write FStatus;
    property Status              : TProviderstatus   read FStatus              write FStatus;
    property Provider            : TDatabaseProvider read FProvider            write FProvider;
    property ProviderName        : String            read FProviderName;
    property Porta               : Integer           read FPort                write FPort;
    property Host                : String            read FHost                write FHost;
    property Usuario             : String            read FUsername            write FUsername;
    property Senha               : String            read FPassword            write FPassword;
    property DataBase            : String            read FDataBase            write FDataBase;

    // Properties - Table
    property Schema              : String            read FSchema              write FSchema;
    property TabelaPrefix        : String            read FTablePrefix         write FTablePrefix;
    property Tabela              : String            read FTable               write FTable;
    property TabelaAlias         : String            read FTableAlias          write FTableAlias;
    property TabelaTexto         : String            read FTableTexto          Write FTableTexto;
    property TablePrefix         : String            read FTablePrefix         write FTablePrefix;
    property Table               : String            read FTable               write FTable;
    property TableAlias          : String            read FTableAlias          write FTableAlias;
    property TableTexto          : String            read FTableTexto          Write FTableTexto;
    property SQLText             : String            read FSQLText             write FSQLText;
    property PrimaryKey          : String            read FPrimaryKey          write FPrimaryKey;
    property PrimaryKeySQL       : String            read FPrimaryKeySQL       write FPrimaryKeySQL;
    property Deleted             : Boolean           read FDeleted             write FDeleted;
    property DeletedBlock        : Boolean           read FDeletedBlock        write FDeletedBlock;

    property Fields              : TJSONArray        read FFields              write FFields;
    property FieldsList          : String            read FFieldsList          write FFieldsList;
    property FieldsFilter        : String            read FFieldsFilter        write FFieldsFilter;
    property FieldsIdFormat      : Boolean           read FFieldsIdFormat      write FFieldsIdFormat;
    property FieldActived        : String            read FFieldActived        Write FFieldActived;
    property FilterSQLAdditional : String            read FFilterSQLAdditional write FFilterSQLAdditional;
    property FieldsUpdate        : String            read FFieldsUpdate        write FFieldsUpdate;
    property FieldsInsert        : String            read FFieldsInsert        write FFieldsInsert;

    property FilterSQL           : String            read FFilterSQL           write FFilterSQL;
    property FieldsType          : String            read fFieldsType          write FFieldsType;
    property Order               : String            read FOrder               write FOrder;
    property FieldsStrArr        : TStringArray      read getFilterArrayStr;

    // Properties - Configuration
    property INIArquivo          : String            read FFileINI             write FFileINI;
    property INISessao           : String            read FSession             write FSession;

    property Id                  : Integer           read FId                  write FId;

    // Properties - Return
    property ReturnJsonObj       : TJSONObject       read FReturnJsonObj       write FReturnJsonObj;
    property ReturnJsonArr       : TJSONArray        read FReturnJsonArr       write FReturnJsonArr;
    property ReturnJsonVle       : TJSONValue        read FReturnJsonVle       write FReturnJsonVle;
    property Return              : String            read FReturn              write FReturn;

    // Public Methods - Initialization
    Function InitTable( ASchema,ATabela,ATabelaAlias : String; Const  ASQL : String = ''  ) : String; overload;
    Function InitTable : String; overload;
    Function InitTable( ASql : String ) : String; overload;
    Function InitQuery( ASql : String ) : TUniQuery; overload;
    Function InitQuery : TUniQuery; overload;

    // Public Methods - Connection
    function Conectar: Boolean;
    procedure Disconectar;
    Procedure Initializar;
    Procedure Finalizar;
    Procedure ExecuteThread( proc: TProc; procTerminate:  TProviderThreadMethod );
    Procedure ExecuteThreadSyncrono( proc: TThreadMethod; Const  procTerminate:  TProviderThreadMethod = nil);
    function EncriptMD5(APassword: String): String;

    {$IF DEFINED(MSWINDOWS) AND NOT DEFINED(FPC)}
    Procedure Changedfields(AObject: TcxTextEdit);       overload;
    Procedure Changedfields(AObject: TcxCurrencyEdit);   overload;
    Procedure Changedfields(AObject: TEdit);             overload;
    Procedure Changedfields(AObject: TMemo);             overload;
    Procedure Changedfields(AObject: TComboBox; Const ACodigo : string = ''); overload;
    Procedure Changedfields(AObject: TRzDateTimeEdit);   overload;
    Procedure Changedfields(AObject: TRzDateTimePicker); overload;
    function FillInData(Aform : TForm; procTerminate:  TProviderThreadMethod) : Boolean;
    function SelecionaTipoDocumento(const AId: Integer = -1): String;
    function SelecionaSetor(const AId: Integer = -1): String;
    procedure ChangedFieldsComboBox(AObject: TComboBox);
    Function  ChangedActiveComboBox(AObject: TComboBox) : String;
    {$ENDIF}

    function SQLChangedfieldsUpdate(Const AColunas : String = ''; Const AValores : String = '') : String;
    function SQLChangedfieldsUpdateA(Const AColunas : String = ''; Const AValores : String = '') : String;
    function SQLChangedFieldsInsert(Const AColunas : String = ''; Const AValores : String = '') : String;
    function SQLChangedFieldsInsertA(Const AColunas : String = ''; Const AValores : String = '') : String;

    function SQLConditionPrimaryKey(Const ADataSource : TUniDataSource; Const ATableAlias : Boolean = True) : String; overload;
    function SQLConditionPrimaryKey(Const ATableAlias : Boolean = True) : String; overload;
    function SQLConditionFilterField(AIndex : Integer; ACondicao : String) : String;

    function List  (Const ASql : String = '')  : Boolean;
    function Insert(Const ASql : String = '')  : Boolean;
    function Update(Const ASql : String = '')  : Boolean;
    function Delete(Const ASql : String = '')  : Boolean;
    function ResetFFields : Boolean;
  end;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R Providers.v161.dfm}

// Helper para liberação segura de objetos
procedure SafeFree(var Obj: TObject);
begin
  if Assigned(Obj) then
  begin
    try
      Obj.Free;
    except
      // Log error mas não interrompe liberação
    end;
    Obj := nil;
  end;
end;

{ TProviders }

constructor TProviders.Create;
begin
  Try inherited Create(nil); except end;
  Initializar;
end;

destructor TProviders.Destroy;
begin
  Finalizar;
  inherited Destroy;
end;

procedure TProviders.DataModuleCreate(Sender: TObject);
begin
  inherited;
  Initializar;
end;

procedure TProviders.DataModuleDestroy(Sender: TObject);
begin
  Finalizar;
end;

procedure TProviders.On_AfterScroll(DataSet: TDataSet);
begin
  // Implementação se necessário
end;

function TProviders.getFConn: Boolean;
begin
  Result := Assigned(FConn) and FConn.Connected;
end;

function TProviders.geTProvidersMasterName(AProvider: TDatabaseProvider): String;
begin
  // v1.6.1: Usa o helper de conexão
  Result := TProviderConnectionHelper.GetProviderMasterName(AProvider);
end;

function TProviders.getFilterArrayStr: TStringArray;
begin
  result := FstrSplit(FFieldsList, ',', false);
end;

function TProviders.getLast12Months: TJSONArray;
var
  _SQL: String;
  QryAux: TUniQuery;
begin
  // v1.6.1: Usa o SQL Builder
  _SQL := TProviderSQLBuilder.GetSQLLast12Months(FProvider);
  
  if _SQL.IsEmpty then
    raise Exception.Create('error_no_SQL_Last_12_Months: ' + FProviderName);

  QryAux := CreateQuery(_SQL);
  try
    {$IFDEF DEBUG}
      QryAux.SQL.SaveToFile(copy(INIArquivo, 1, length(INIArquivo) - 3) + '_TProviders.getLast12Months.sql');
    {$ENDIF}
    try
      QryAux.Open;
    except
      On ex: Exception do
      begin
        {$IF DEFINED(MSWINDOWS) AND NOT DEFINED(FPC)}
          ShowMessage('Erro: ' + ex.Message);
        {$ELSE}
          Writeln('Erro: ' + ex.Message);
        {$ENDIF}
      end;
    end;
    {$IFDEF DEBUG}
      QryAux.SaveToXML(copy(INIArquivo, 1, length(INIArquivo) - 3) + '_TProviders.getLast12Months.xml');
    {$ENDIF}
    Result := QryAux.ToJSONArray;
  finally
    QryAux.Free;
  end;
end;

function TProviders.getSQLTables: String;
var
  _SQL: String;
  QryAux: TUniQuery;
begin
  // v1.6.1: Usa o SQL Builder
  _SQL := TProviderSQLBuilder.GetSQLTables(FProvider, FSchema, FDataBase);
  
  QryAux := CreateQuery(_SQL);
  try
    {$IFDEF DEBUG}
      QryAux.SQL.SaveToFile(copy(INIArquivo, 1, length(INIArquivo) - 3) + '_TProviders.getSQLTables.sql');
    {$ENDIF}
    QryAux.Open;
    {$IFDEF DEBUG}
      QryAux.SaveToXML(copy(INIArquivo, 1, length(INIArquivo) - 3) + '_TProviders.getSQLTables.xml');
    {$ENDIF}
    if Assigned(FSchemaTable) then
      FSchemaTable.Free;
    FSchemaTable := QryAux.ToJSONArray;
    Result := FSchemaTable.ToString;
  finally
    QryAux.Free;
  end;
end;

function TProviders.getSQLPrimaryKey: TDataSet;
var
  _SQL: String;
  QryAux: TUniQuery;
  i: integer;
begin
  Result := nil;
  
  // v1.6.1: Usa o SQL Builder
  _SQL := TProviderSQLBuilder.GetSQLPrimaryKey(FProvider, FSchema, FTable);

  QryAux := CreateQuery(_SQL);
  try
    {$IFDEF DEBUG}
      QryAux.SQL.SaveToFile(copy(INIArquivo, 1, length(INIArquivo) - 3) + '_TProviders.getSQLPrimaryKey.sql');
    {$ENDIF}
    QryAux.Open;
    {$IFDEF DEBUG}
      QryAux.SaveToXML(copy(INIArquivo, 1, length(INIArquivo) - 3) + '_TProviders.getSQLPrimaryKey.xml');
    {$ENDIF}

    if (not QryAux.IsEmpty) OR (Not FFieldsPKey.IsEmpty) Then
    begin
      FPrimaryKey := QryAux.FieldByName('column_name').AsString;
      FFieldPKey.LoadStructure(QryAux.SaveStructure);
      FFieldPKey.Active := true;
      FFieldPKey.IndexFieldNames := 'position, column_name ';
      FFieldPKey.LoadFromJSON(QryAux.ToJSONArray);

      If Not FFieldsPKey.IsEmpty Then
      Begin
        While Not FFieldPKey.Eof do
        Begin
          For i := 1 to ArrayFieldCount(FFieldsPKey, ',') do
          Begin
            if UpperCase(FFieldPKey.FieldByName('column_name').AsString) = UpperCase(ArrayField(FFieldsPKey, ',', i)) then
            Begin
              FFieldPKey.Edit;
              FFieldPKey.FieldByName('Pkey').AsInteger := 1;
              FFieldPKey.Post;
              Break;
            End;
          End;
          FFieldPKey.Next;
        End;
      End;

      Result := QryAux;
    end
    else
      raise Exception.Create('error_no_primary_key_table: ' + FTable);
  finally
    // Não liberar QryAux aqui, é retornado como Result
  end;
end;

function TProviders.getSQLFieldsList: TDataSet;
var
  _SQL: String;
  QryAux: TUniQuery;
  _String: String;
begin
  _String := '';
  Result := nil;

  if FFieldsFilter.IsEmpty then
  begin
    // v1.6.1: Usa o SQL Builder (simplificado - precisa implementar GetSQLFieldsList no builder)
    // Por enquanto, mantém lógica original
    case FProvider of
      dpPostgreSQL:
        _SQL := 'SELECT STRING_AGG(column_name, '','' ORDER BY ordinal_position) AS COLUMN_NAMES ' +
                'FROM information_schema.columns ' +
                'WHERE table_name = ''' + FTable + ''' ' +
                'AND table_schema = ''' + FSchema + '''';
      dpMySQL, dpMariaDB:
        _SQL := 'SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION SEPARATOR '','') AS COLUMN_NAMES ' +
                'FROM information_schema.columns ' +
                'WHERE TABLE_NAME = ''' + FTable + ''' ' +
                'AND TABLE_SCHEMA = DATABASE()';
      dpSQLServer:
        _SQL := 'SELECT STRING_AGG(c.name, '', '') AS COLUMN_NAMES ' +
                'FROM sys.columns c ' +
                'JOIN sys.tables t ON c.object_id = t.object_id ' +
                'WHERE t.name = ''' + FTable + '''';
      dpFireBird, dpFireBird3:
        _SQL := 'SELECT LIST(TRIM(rf.RDB$FIELD_NAME), '', '') AS COLUMN_NAMES ' +
                'FROM RDB$RELATION_FIELDS rf ' +
                'WHERE rf.RDB$RELATION_NAME = ''' + FTable + '''';
      dpSQLite:
        _SQL := 'SELECT GROUP_CONCAT(name, '','') AS COLUMN_NAMES ' +
                'FROM pragma_table_info(''' + FTable + ''')';
    else
      _SQL := '';
    end;

    QryAux := CreateQuery(_SQL);
    try
      {$IFDEF DEBUG}
        QryAux.SQL.SaveToFile(copy(INIArquivo, 1, length(INIArquivo) - 3) + '_TProviders.getSQLFieldsList.sql');
      {$ENDIF}
      QryAux.Open;
      FFieldsList := QryAux.FieldByName('COLUMN_NAMES').AsString;
      {$IFDEF DEBUG}
        QryAux.SaveToXML(copy(INIArquivo, 1, length(INIArquivo) - 3) + '_TProviders.getSQLFieldsList.xml');
      {$ENDIF}
      Result := QryAux;
    finally
      // Não liberar aqui, é retornado
    end;
  End
  Else
  Begin
    FFieldsList := FFieldsFilter;
    Result := nil;
  End;
end;

function TProviders.getSQLFields: TDataSet;
var
  _SQL: String;
  QryAux: TUniQuery;
  LFilter, LFilterColomn: String;
  Coluna: String;
  i: integer;
begin
  Result := nil;

  // v1.6.1: Usa o SQL Builder
  _SQL := TProviderSQLBuilder.GetSQLFields(FProvider, FSchema, FTable);

  // Aplicar filtros
  case FProvider of
    dpPostgreSQL: Coluna := 'column_name';
    dpMariaDB, dpMySQL: Coluna := 'COLUMN_NAME';
    dpSQLServer: Coluna := 'COLUMN_NAME';
    dpFireBird, dpFireBird3: Coluna := 'rf.RDB$FIELD_NAME';
    dpSQLite: Coluna := 'name';
  else
    Coluna := 'column_name';
  end;

  LFilterColomn := '';
  If Not FFieldsExcluded.IsEmpty Then
  Begin
    for var j := 1 to ArrayFieldCount(FFieldsExcluded, ',') do
    Begin
      LFilterColomn := LFilterColomn + '''' + ArrayField(FFieldsExcluded, ',', j) + ''',';
    End;
    LFilterColomn := 'AND Not ' + Coluna + ' IN (' + copy(LFilterColomn, 1, Length(LFilterColomn) - 1) + ')';
  End;

  LFilter := '';
  If Not FFieldsFilter.IsEmpty Then
  Begin
    for var j := 1 to ArrayFieldCount(FFieldsFilter, ',') do
    Begin
      LFilter := LFilter + '''' + ArrayField(FFieldsFilter, ',', j) + ''',';
    End;
    LFilter := 'AND ' + Coluna + ' IN (' + copy(LFilter, 1, Length(LFilter) - 1) + ')';
  End;

  _SQL := StringReplace(_SQL, '[VFilterColumn]', LFilterColomn, [rfReplaceAll, rfIgnoreCase]);
  _SQL := StringReplace(_SQL, '[VFilter]', LFilter, [rfReplaceAll, rfIgnoreCase]);

  QryAux := CreateQuery(_SQL);
  try
    {$IFDEF DEBUG}
      QryAux.SQL.SaveToFile(copy(INIArquivo, 1, length(INIArquivo) - 3) + '_TProviders.getSQLFields.sql');
    {$ENDIF}
    try
      QryAux.Open;
    except
      On ex: Exception do
      begin
        {$IF DEFINED(LINUX) OR DEFINED(FPC)}
          Writeln('Erro: ' + ex.Message);
        {$ELSE}
          ShowMessage('Erro: ' + ex.Message);
        {$ENDIF}
      end;
    end;

    If (not QryAux.IsEmpty) OR (Not FFieldsPKey.IsEmpty) Then
    Begin
      if Assigned(FFields) then
      Begin
        FFields.free;
        FField := TVirtualTable.Create(nil);
      End;

      FFields := QryAux.ToJSONArray;
      FField.LoadStructure(QryAux.SaveStructure);
      FField.Active := true;
      FField.IndexFieldNames := 'position, column_name ';
      FField.LoadFromJSON(QryAux.ToJSONArray.ToString);

      If Not FFieldsPKey.IsEmpty Then
      Begin
        While Not FField.Eof do
        Begin
          For i := 1 to ArrayFieldCount(FFieldsPKey, ',') do
          Begin
            if UpperCase(FField.FieldByName('column_name').AsString) = UpperCase(ArrayField(FFieldsPKey, ',', i)) then
            Begin
              FField.Edit;
              FField.FieldByName('Pkey').AsInteger := 1;
              FField.FieldByName('constraint_name').AsString := 'PK Manual';
              FField.Post;
              Break;
            End;
          End;
          FField.Next;
        End;
      End;

      If Not FFieldsAdditional.IsEmpty then
      Begin
        For i := 1 to ArrayFieldCount(FFieldsAdditional, ',') do
        Begin
          FField.Insert;
          FField.FieldByName('changed').AsInteger := 0;
          FField.FieldByName('table_catalog').AsString := FDataBase;
          FField.FieldByName('table_schema').AsString := FSchema;
          FField.FieldByName('table_name').AsString := FTable;
          FField.FieldByName('position').AsInteger := 80 + i;
          FField.FieldByName('column_name').AsString := ArrayField(ArrayField(FFieldsAdditional, ',', i), ':', 1);
          FField.FieldByName('data_type').AsString := ArrayField(ArrayField(FFieldsAdditional, ',', i), ':', 2);
          FField.FieldByName('data_type_code').Value := null;
          FField.FieldByName('character_maximum_length').Value := null;
          FField.FieldByName('is_nullable').AsString := 'YES';
          FField.FieldByName('column_default').Value := null;
          FField.FieldByName('value').AsString := '';
          FField.FieldByName('valuedefault').AsString := '';
          FField.FieldByName('pkey').Value := null;
          FField.FieldByName('constraint_name').Value := null;
          FField.Post;
        End;
        TFile.WriteAllText(copy(INIArquivo, 1, length(INIArquivo) - 3) + '.FField.xml', FField.ToJSONArray.ToString, TEncoding.ANSI);
      End;

      {$IFDEF DEBUG}
        FField.SaveToXML(copy(INIArquivo, 1, length(INIArquivo) - 3) + '_TProviders.getSQLFields.FField.xml');
        QryAux.SaveToXML(copy(INIArquivo, 1, length(INIArquivo) - 3) + '_TProviders.getSQLFields.xml');
      {$ENDIF}
      Result := QryAux;
    end
    else
      raise Exception.Create('error_no_Fields_table: ' + FTable);
  finally
    // Não liberar aqui, é retornado
  end;
end;

function TProviders.CreateQuery(const ASQL: String): TUniQuery;
var
  QryAux: TUniQuery;
begin
  if not Assigned(FConn) then
    raise Exception.Create('Erro de Conexão com o Banco!');

  if not FConn.Connected then
    raise Exception.Create('Banco Não conectado!');

  QryAux := TUniQuery.Create(Self);
  try
    with QryAux do
    begin
      Connection := FConn;
      CachedUpdates := True;
      Options.AutoPrepare := True;
      Options.QueryRecCount := True;
      Options.RequiredFields := True;
      Options.SetFieldsReadOnly := False;
      Options.ReturnParams := True;
      If FProvider = dpPostgreSQL Then
        SpecificOptions.Values['UnknownAsString'] := 'true';

      Close;
      SQL.Clear;
      SQL.Add(ASQL);
    end;
    Result := QryAux;
  except
    on E: Exception do
    begin
      QryAux.Free;
      raise;
    end;
  end;
end;

function TProviders.InitQuery(ASql: String): TUniQuery;
begin
  Result := CreateQuery(ASql);
end;

function TProviders.InitQuery: TUniQuery;
begin
  Result := InitQuery(FSQLText);
end;

function TProviders.InitTable(ASQL: String): String;
begin
  InitTable(FSchema, FTable, FTableAlias, ASQL);
end;

function TProviders.InitTable: String;
begin
  if FSchema.IsEmpty and Not (FProvider in [dpSQLite, dpMariaDB, dpFireBird, dpNone]) then
    raise Exception.Create('FSchema não tem dados');

  if FTable.IsEmpty then
    raise Exception.Create('error_table_no_data');

  if FTableAlias.IsEmpty and Not (FProvider in [dpSQLite, dpFireBird, dpNone]) then
    raise Exception.Create('error_table_alias_no_data');

  Result := InitTable(FSchema, FTable, FTableAlias);
end;

function TProviders.InitTable(ASchema, ATabela, ATabelaAlias: String; const ASQL: String): String;
Var
  _String: String;
begin
  if not Assigned(FConn) then
    raise Exception.Create('Erro de Conexão com o Banco!');

  if not FConn.Connected then
    raise Exception.Create('Banco Não conectado!');

  FTableTexto := '';
  _String := '*';

  if not ASchema.IsEmpty then
  begin
    FSchema := ASchema;
    FTableTexto := FSchema + '.';
  end
  else
  begin
    FTableTexto := '';
  end;

  FTable := ATabela;
  FTableAlias := ATabelaAlias;
  FTableTexto := FTableTexto + FTable;

  If FPrimaryKey.IsEmpty then getSQLPrimaryKey;
  If FFieldsList.IsEmpty then getSQLFieldsList;

  if Not FFieldsFilter.IsEmpty then
    _String := FFieldsList;

  getSQLFields;

  if not ASQL.IsEmpty then
    FSQLText := ASQL
  else
    If FSQLText.IsEmpty Then
      FSQLText := Format('SELECT %s FROM %s %s', [_String, FTableTexto, FTableAlias]);

  Qry := InitQuery(FSQLText);
  Result := FSQLText;
end;

function TProviders.Conectar: Boolean;
var
  Status: TJSONObject;
begin
  Status := TJSONObject.Create;
  try
    if not Assigned(FConn) then
      FConn := TUniConnection.Create(nil);

    with FConn do
    begin
      Close;
      LoginPrompt := False;
      ProviderName := FProviderName;
      Database := FDataBase;

      if FProvider <> dpSQLite then
      begin
        Server := FHost;
        Port := FPort;
        Username := FUsername;
        Password := FPassword;
      end;

      Options.KeepDesignConnected := True;

      {$IFDEF MSWINDOWS}
      If FProvider = dpSQLServer Then
      Begin
        SpecificOptions.Values['Provider'] := 'prDirect';
        SpecificOptions.Values['Authentication'] := 'auServer';
      End;
      {$ENDIF}

      FConnectionString := TProviderConnectionHelper.GetConnectionString(FProvider, FHost, FPort, FDataBase, FUsername);

      {$IFDEF DEBUG}
        {$IFDEF MSWINDOWS}
          // ShowMessage(FConnectionString);
        {$ELSE}
          writeln(FConnectionString);
        {$ENDIF}
      {$ENDIF}

      try
        Connect;
        Result := True;
      except
        on ex: Exception do
        begin
          writeln(ex.Message);
          Result := False;
        end;
      end;
    end;
  finally
    Status.Free;
  end;
end;

procedure TProviders.Disconectar;
begin
  if Assigned(FConn) and FConn.Connected then
  begin
    FConn.Close;
  end;
end;

procedure TProviders.Initializar;
begin
  If Not Assigned(FPostgresSQL) Then FPostgresSQL := TPostgreSQLUniProvider.Create(nil);
  If Not Assigned(FInterBase) Then FInterBase := TInterBaseUniProvider.Create(nil);
  If Not Assigned(FSQLServer) Then FSQLServer := TSQLServerUniProvider.Create(nil);
  If Not Assigned(FSQLite) Then FSQLite := TSQLiteUniProvider.Create(nil);
  If Not Assigned(FMySQL) Then FMySQL := TMySQLUniProvider.Create(nil);

  If Not Assigned(ReturnQry) Then ReturnQry := TUniQuery.Create(nil);
  If Not Assigned(Qry) Then Qry := TUniQuery.Create(nil);

  If Not Assigned(FConn) Then FConn := TUniConnection.Create(nil);
  If Not Assigned(FConnL) Then FConnL := TUniConnection.Create(nil);

  If Not Assigned(FField) Then FField := TVirtualTable.Create(nil);
  If Not Assigned(FFieldPKey) Then FFieldPKey := TVirtualTable.Create(nil);
  If Not Assigned(qryVirutal) Then qryVirutal := TVirtualQuery.Create(nil);

  TDataSetSerializeConfig.GetInstance.CaseNameDefinition := cndLower;
  TDataSetSerializeConfig.GetInstance.Import.DecimalSeparator := '.';

  FFileINI := ExtractFilePath(ParamStr(0)) + ChangeFileExt((ExtractFileName(ParamStr(0))), '.ini');

  FDadosINIJson := TJSONObject.Create.ParseJSONValue('{}') as TJSONObject;
  FSchemaTable := TJSONArray.Create.ParseJSONValue('[{}]') as TJSONArray;
  FFields := TJSONArray.Create.ParseJSONValue('[{}]') as TJSONArray;
  FReturnJsonObj := TJSONObject.Create.ParseJSONValue('{}') as TJSONObject;
  FReturnJsonArr := TJSONArray.Create.ParseJSONValue('[{}]') as TJSONArray;
  FReturnJsonVle := TJSONValue.Create.ParseJSONValue('{}') as TJSONValue;

  FId := -1;
  FStatus := TProviderstatus.dsInactive;
  FTablePrefix := '';
  FFilterSQLAdditional := '';
  FFieldActived := '';
  FFieldsDeleted := 'DELETED';
  FFieldDate := 'DATA_CADASTRO';
  FFieldDateUpdate := 'DATA_ALTERACAO';
  FFieldsExcluded := 'DATA_CADASTRO,DATA_ALTERACAO,DELETED';
  FFieldsExcludedFilter := '';

  FFieldsIdFormat := True;
  FFieldsAdditional := '';
  FFieldsPKey := '';

  FOrder := FPrimaryKey;

  FDeleted := False;
  FDeletedBlock := True;

  FProvider := dpNone;
  FProviderName := '';
  FSession := '';
  FHost := '';
  FPort := -1;
  FDataBase := '';
  FUsername := '';
  FPassword := '';
  FURL_Base := '';

  FSQLText := '';
  FTable := '';
  FSchema := '';
  FTableAlias := '';
  FPrimaryKey := '';
  FFieldsList := '';
  FFieldsFilter := '';
  FFilterSQL := '';

  // Default provider
  FProvider := dpSQLServer;
  FProviderName := geTProvidersMasterName(FProvider);

  // v1.6.1: Usa o Type Converter
  FTipoVariavel := TProviderTypeConverter.GetTipoVariavel(FProvider);

  FFieldsType := 'SMALLINT,INTEGER,INT,TINYINT,BIGINT,FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY,DATE,TIME,TIMESTAMP,DATETIME,CHAR,VARCHAR,BLOB,TEXT,SMALLDATETIME';

  // Initialize properties
  {$IFDEF RELEASE}
    {$I ConexaoBanco.inc}
  {$ELSE}
    FSession := 'Banco Cliente';
    FHost := '';
    FPort := 1433;
    FUsername := 'sa';
    FPassword := '';
    FDatabase := 'Comercial';
    FURL_Base := 'http://' + FHost + ':9000';
  {$ENDIF}
  SaveINI;
end;

procedure TProviders.Finalizar;
begin
  if Assigned(FConn) and FConn.Connected then
  begin
    try
      Disconectar;
    except
      // Silenciar erros de desconexão
    end;
  end;

  SafeFree(TObject(FDadosINIJson));
  SafeFree(TObject(FSchemaTable));
  SafeFree(TObject(FFields));
  SafeFree(TObject(FReturnJsonObj));
  SafeFree(TObject(FReturnJsonArr));
  SafeFree(TObject(FReturnJsonVle));

  SafeFree(TObject(FPostgresSQL));
  SafeFree(TObject(FSQLServer));
  SafeFree(TObject(FMySQL));
  SafeFree(TObject(FInterBase));
  SafeFree(TObject(FSQLite));
  SafeFree(TObject(FConn));
  SafeFree(TObject(FConnL));
end;

function TProviders.LoadINI: Boolean;
var
  Ini: TIniFile;
  ProviderStr: String;
begin
  Result := False;

  If Not FileExists(FFileINI) Then
    Exit;

  try
    Ini := TIniFile.Create(FFileINI);
    try
      ProviderStr := Ini.ReadString(FSession, 'Provider', 'PostgreSQL');

      if ProviderStr = 'FireBird' then FProvider := dpFireBird else
      if ProviderStr = 'MariaDB' then FProvider := dpMariaDB else
      if ProviderStr = 'PostgreSQL' then FProvider := dpPostgreSQL else
      if ProviderStr = 'SQLite' then FProvider := dpSQLite else
      if ProviderStr = 'SQL Server' then FProvider := dpSQLServer;

      FHost := Ini.ReadString(FSession, 'Server', FHost);
      FPort := Ini.ReadInteger(FSession, 'Port', FPort);
      FDataBase := Ini.ReadString(FSession, 'Database', FDataBase);
      FUsername := Ini.ReadString(FSession, 'Username', FUsername);
      FPassword := Ini.ReadString(FSession, 'Password', FPassword);
      FSchema := Ini.ReadString(FSession, 'Schema', 'public');
      FURL_Base := 'http://' + FHost + ':9000';
      Result := True;
    finally
      Ini.Free;
    end;
  except
    on ex: Exception do
    begin
      Result := False;
    end;
  end;
end;

function TProviders.SaveINI: Boolean;
var
  Ini: TIniFile;
begin
  try
    Ini := TIniFile.Create(FFileINI);
    try
      Ini.WriteString(FSession, 'Provider', FProviderName);
      Ini.WriteInteger(FSession, 'Port', FPort);
      Ini.WriteString(FSession, 'Database', FDataBase);
      Ini.WriteString(FSession, 'Username', FUsername);
      Ini.WriteString(FSession, 'Server', FHost);
      Ini.WriteString(FSession, 'Password', FPassword);
      Ini.WriteString(FSession, 'Schema', FSchema);
      Result := True;
    finally
      Ini.Free;
    end;
  except
    on ex: Exception do
    begin
      Result := False;
    end;
  end;
end;

function TProviders.EncriptMD5(APassword: String): String;
var
  MD5: TIdHashMessageDigest5;
begin
  MD5 := TIdHashMessageDigest5.Create;
  try
    Result := MD5.HashStringAsHex(APassword);
  finally
    MD5.Free;
  end;
end;

procedure TProviders.ExecuteThread(proc: TProc; procTerminate: TProviderThreadMethod);
var
  t: TThread;
begin
  t := TThread.CreateAnonymousThread(proc);
  if Assigned(procTerminate) then
    t.OnTerminate := procTerminate;
  t.Start;
end;

procedure TProviders.ExecuteThreadSyncrono(proc: TThreadMethod; Const procTerminate: TProviderThreadMethod);
var
  t: TThread;
begin
  t := TThread.Create;
  t.Synchronize(nil, proc);
  if Assigned(procTerminate) then
    t.OnTerminate := procTerminate;
  t.Start;
end;

// Métodos CRUD - v1.6.1: Implementação completa mantendo compatibilidade com v1.5.0

function TProviders.List(const ASql: String): Boolean;
var
  LQuery: TUniQuery;
  LJSonArray: TJSONArray;
  LJSonObj: TJSONObject;
  _SQL: String;
begin
  If Not ASql.IsEmpty Then
    _SQL := ASql
  Else
    _SQL := SQLText;
    
  If FFieldsIdFormat then
    case FProvider of
      dpSQLServer:
        begin
          if not (pos('RIGHT', _SQL) > 0) then
            _SQL := StringReplace(_SQL, FPrimaryKey + ',', 'RIGHT(REPLICATE(''0'', 6) + Cast(' + FPrimaryKey + ' as VARCHAR), 6) AS ' + FPrimaryKey + ',', [rfReplaceAll, rfIgnoreCase]);
        end;
    else
      if not (pos('LPAD', _SQL) > 0) then
        _SQL := StringReplace(_SQL, FPrimaryKey + ',', 'LPAD(' + FPrimaryKey + ', 6, ''0'') AS ' + FPrimaryKey + ',', [rfReplaceAll, rfIgnoreCase]);
    end;

  try
    try
      ReturnQry.Close;
      ReturnQry := InitQuery(_SQL);
      ReturnQry.SQL.Add('Where 1 = 1 ');
      Try
        If not FFilterSQL.IsEmpty Then
          If (FDeleted = False) Then
            ReturnQry.SQL.add('And Deleted = 0 ' + LineEnding + FFilterSQL)
          Else
            ReturnQry.SQL.add(FFilterSQL)
        Else
          If (FDeleted = False) Then
            ReturnQry.SQL.add('And Deleted = 0 ' + LineEnding);

        ReturnQry.SQL.Add(FFilterSQLAdditional);

        If Not FOrder.IsEmpty then
          ReturnQry.SQL.Add(FOrder);

        if FId > -1 then
          ReturnQry.SQL.Add(' And ' + FPrimaryKey + ' = ' + FId.ToString);

        {$IFDEF DEBUG}
          ReturnQry.SQL.SaveToFile(copy(INIArquivo, 1, length(INIArquivo) - 3) + '.TProviders.List' + '.sql');
        {$ENDIF}

        ReturnQry.Open;

        {$IFDEF DEBUG}
          ReturnQry.SaveToXML(copy(INIArquivo, 1, length(INIArquivo) - 3) + '.TProviders.List.xml');
        {$ENDIF}

        if Not ReturnQry.IsEmpty then
        begin
          try
            LJSonObj := TJSONObject.Create.
              AddPair('success', true).
              AddPair('message', 'Dados encontrada!').
              AddPair('data', ReturnQry.ToJSONArray);
            FReturn := LJSonObj.ToString;
            FReturnJsonArr := ReturnQry.ToJSONArray;
            FReturnJsonObj := TJSONValue.Create.ParseJSONValue(LJSonObj.ToString) as TJSONObject;
            FReturnJsonVle := TJSONValue.Create.ParseJSONValue(ReturnQry.ToJSONObjectString) as TJSONValue;
            Result := True;
          finally
            If Assigned(LJSonObj) Then
              FreeAndNil(LJSonObj);
          end;
        end
        Else Begin
          LJSonObj := TJSONObject.Create.
            AddPair('success', false).
            AddPair('message', 'Nenhum dado encontrada!').
            AddPair('data', TJSONArray.Create.ParseJSONValue('[{}]') as TJSONArray);
          FReturn := LJSonObj.ToString;
        End;
      except
        LJSonObj := TJSONObject.Create.
          AddPair('success', false).
          AddPair('message', 'Erro no Filter: ' + FFilterSQL).
          AddPair('data', TJSONArray.Create.ParseJSONValue('[{}]') as TJSONArray);
        FReturn := LJSonObj.ToString;
        ReturnQry.Close;
        Exit;
      End;
    finally
      If Assigned(LJSonObj) Then
        FreeAndNil(LJSonObj);
    end;
  except
    on E: Exception do begin
      LJSonObj := TJSONObject.Create.
        AddPair('success', false).
        AddPair('message', 'Erro ao listar: ' + E.Message).
        AddPair('data', TJSONArray.Create.ParseJSONValue('[{}]') as TJSONArray);
      FReturn := LJSonObj.ToString;
    end;
  end;
end;

function TProviders.Insert(const ASql: String): Boolean;
var
  LQuery: TUniQuery;
  LJSonArray: TJSONArray;
  LJSonObj: TJSONObject;
  _SQL: String;
Begin
  if Not (FStatus = TProviderStatus.dsInsert) then
    raise Exception.Create('Status não está em modo INSERT, verifique o código novamente!');

  FStatus := TProviderStatus.dsInactive;

  If Not ASql.IsEmpty Then
    _SQL := ASql
  Else If FVersaoProvider = '1.5.0' Then
    _SQL := SQLChangedFieldsInsertA
  Else
    _SQL := SQLChangedFieldsInsert;

  If _SQL.IsEmpty Then Begin
    {$IFDEF DEBUG}
      {$IF DEFINED(MSWINDOWS) AND NOT DEFINED(FPC)}
        ShowMessage('SQL vazio!');
      {$ELSE}
        writeln('SQL Vazio!');
      {$ENDIF}
    {$ENDIF}
    Exit;
  End;

  {$IFDEF DEBUG}
    {$IFDEF MSWINDOWS}
      // ShowMessage(_SQL);
    {$ELSE}
      writeln(_SQL);
    {$ENDIF}
  {$ENDIF}

  try
    try
      ReturnQry.Close;
      ReturnQry := InitQuery(_SQL);
      Try
        {$IFDEF DEBUG}
          ReturnQry.SQL.SaveToFile(copy(INIArquivo, 1, length(INIArquivo) - 3) + '.TProviders.Insert' + '.sql');
        {$ENDIF}
        If FProvider = dpPostgreSQL Then
          ReturnQry.Open
        Else
          ReturnQry.ExecSQL;
        {$IFDEF DEBUG}
          If FProvider = dpPostgreSQL Then
            ReturnQry.SaveToXML(copy(INIArquivo, 1, length(INIArquivo) - 3) + '.TProviders.Insert.xml');
        {$ENDIF}
        LJSonObj := TJSONObject.Create.
          AddPair('success', True).
          AddPair('message', 'Inserido com sucesso!');
        If FProvider = dpPostgreSQL Then
          LJSonObj.AddPair('data', ReturnQry.ToJSONArray)
        Else
          LJSonObj.AddPair('data', TJSONArray.Create.ParseJSONValue('[{}]') as TJSONArray);

        FReturn := LJSonObj.ToString;
        Result := True;
      except
        on E: Exception do begin
          LJSonObj := TJSONObject.Create.
            AddPair('success', false).
            AddPair('message', 'Erro ao inserir: ' + E.Message).
            AddPair('data', TJSONArray.Create.ParseJSONValue('[{}]') as TJSONArray);
          FReturn := LJSonObj.ToString;
          ReturnQry.Close;
          Exit;
        end;
      End;
    finally
      If Assigned(LJSonObj) Then
        FreeAndNil(LJSonObj);
    end;
  except
    on E: Exception do begin
      LJSonObj := TJSONObject.Create.
        AddPair('success', false).
        AddPair('message', 'Erro ao listar: ' + E.Message).
        AddPair('data', TJSONArray.Create.ParseJSONValue('[{}]') as TJSONArray);
      FReturn := LJSonObj.ToString;
    end;
  end;
end;

function TProviders.Update(const ASql: String): Boolean;
var
  LQuery: TUniQuery;
  LJSonArray: TJSONArray;
  LJSonObj: TJSONObject;
  _SQL: String;
Begin
  if Not (FStatus = TProviderStatus.dsEdit) then
    raise Exception.Create('Status não está em modo EDIT, verifique o código novamente!');

  FStatus := TProviderStatus.dsInactive;

  If Not ASql.IsEmpty Then
    _SQL := ASql
  Else If FVersaoProvider = '1.5.0' Then
    _SQL := SQLChangedfieldsUpdateA
  Else
    _SQL := SQLChangedfieldsUpdate;

  If _SQL.IsEmpty Then Begin
    {$IFDEF DEBUG}
      {$IF DEFINED(MSWINDOWS) AND NOT DEFINED(FPC)}
        ShowMessage('SQL vazio!');
      {$ELSE}
        writeln('SQL Vazio!');
      {$ENDIF}
    {$ENDIF}
    Exit;
  End;

  {$IFDEF DEBUG}
    {$IFDEF MSWINDOWS}
      //ShowMessage(_SQL);
    {$ELSE}
      writeln(_SQL);
    {$ENDIF}
  {$ENDIF}

  try
    try
      ReturnQry.Close;
      ReturnQry := InitQuery(_SQL);
      Try
        {$IFDEF DEBUG}
          ReturnQry.SQL.SaveToFile(copy(INIArquivo, 1, length(INIArquivo) - 3) + '.TProviders.Update' + '.sql');
        {$ENDIF}
        If FProvider = dpPostgreSQL Then
          ReturnQry.Open
        Else
          ReturnQry.ExecSQL;
        {$IFDEF DEBUG}
          If FProvider = dpPostgreSQL Then
            ReturnQry.SaveToXML(copy(INIArquivo, 1, length(INIArquivo) - 3) + '.TProviders.Insert.xml');
        {$ENDIF}

        LJSonObj := TJSONObject.Create.
          AddPair('success', True).
          AddPair('message', 'Alterado com sucesso!');
        If FProvider = dpPostgreSQL Then
          LJSonObj.AddPair('data', ReturnQry.ToJSONArray)
        Else
          LJSonObj.AddPair('data', TJSONArray.Create.ParseJSONValue('[{}]') as TJSONArray);

        FReturn := LJSonObj.ToString;
        Result := True;
      except
        on E: Exception do begin
          LJSonObj := TJSONObject.Create.
            AddPair('success', false).
            AddPair('message', 'Erro ao alterar: ' + E.Message).
            AddPair('data', TJSONArray.Create.ParseJSONValue('[{}]') as TJSONArray);
          FReturn := LJSonObj.ToString;
          ReturnQry.Close;
          Exit;
        end;
      End;
    finally
      If Assigned(LJSonObj) Then
        FreeAndNil(LJSonObj);
    end;
  except
    on E: Exception do begin
      LJSonObj := TJSONObject.Create.
        AddPair('success', false).
        AddPair('message', 'Erro ao alterar: ' + E.Message).
        AddPair('data', TJSONArray.Create.ParseJSONValue('[{}]') as TJSONArray);
      FReturn := LJSonObj.ToString;
    end;
  end;
end;

function TProviders.Delete(const ASql: String): Boolean;
var
  LQuery: TUniQuery;
  LJSonArray: TJSONArray;
  LJSonObj: TJSONObject;
  _SQL: String;
  LId: String;
begin
  If FTablePrefix.IsEmpty Then
    if (FDeletedBlock = True) then
      raise Exception.Create('Não é permitido DELETAR registro na TABELA: ' + FTable + ' !');

  if Not (FStatus = TProviderstatus.dsDeleted) then
    raise Exception.Create('Status não está em modo DELETE, verifique o código novamente!');

  FStatus := TProviderstatus.dsInactive;

  FField.Filter := 'position=''1''';
  FField.Filtered := true;

  If FId > -1 Then
    LId := FId.ToString
  Else
    LId := FField.FieldByName('value').AsString;

  If FDeleted Then
    _SQL := Format('Delete from %s Where %s = %s ', [FTableTexto, PrimaryKey, LId])
  Else
    _SQL := Format('Update %s Set DELETED = 1 Where %s = %s ', [FTableTexto, PrimaryKey, LId]);

  FField.Filtered := false;

  If Not ASql.IsEmpty Then
    _SQL := ASql;

  try
    try
      ReturnQry.Close;
      ReturnQry := InitQuery(_SQL);
      Try
        {$IFDEF DEBUG}
          ReturnQry.SQL.SaveToFile(copy(INIArquivo, 1, length(INIArquivo) - 3) + '.TProviders.Delete' + '.sql');
        {$ENDIF}

        ReturnQry.ExecSQL;

        {$IFDEF DEBUG}
          //ReturnQry.SaveToXML(copy(INIArquivo,1,length(INIArquivo) - 3 ) + '.TProviders.Insert.xml');
        {$ENDIF}

        LJSonObj := TJSONObject.Create.
          AddPair('success', True).
          AddPair('message', 'Deletado com sucesso!').
          AddPair('data', TJSONArray.Create.ParseJSONValue('[{}]') as TJSONArray);
        FReturn := LJSonObj.ToString;
        Result := True;
      except
        LJSonObj := TJSONObject.Create.
          AddPair('success', false).
          AddPair('message', 'Erro no Filter: ' + FFilterSQL).
          AddPair('data', TJSONArray.Create.ParseJSONValue('[{}]') as TJSONArray);
        FReturn := LJSonObj.ToString;
        ReturnQry.Close;
        Exit;
      End;
    finally
      If Assigned(LJSonObj) Then
        FreeAndNil(LJSonObj);
    end;
  except
    on E: Exception do begin
      LJSonObj := TJSONObject.Create.
        AddPair('success', false).
        AddPair('message', 'Erro ao listar: ' + E.Message).
        AddPair('data', TJSONArray.Create.ParseJSONValue('[{}]') as TJSONArray);
      FReturn := LJSonObj.ToString;
    end;
  end;
end;

function TProviders.ResetFFields: Boolean;
begin
  Result := getSQLFields <> nil;
end;

// Métodos SQL - v1.6.1: Implementação completa mantendo compatibilidade com v1.5.0

function TProviders.SQLChangedFieldsInsert(const AColunas: String; const AValores: String): String;
Var
  i: integer;
  Str: String;
  StrValor: String;
  _SQL: String;
  Campo: TCampo;
  Campos: Tlist<TCampo>;
begin
  FField.Refresh;
  FField.First;
  FField.Filter := 'PKey is null';
  FField.Filtered := True;
  Str := '';
  StrValor := '';
  If Not FField.IsEmpty Then Begin
    Try
      campo := TCampo.Create;
      Campos := Tlist<TCampo>.Create;
      While Not FField.Eof do
      Begin
        campo.Coluna := FField.FieldByName('column_name').AsString;
        campo.Tipo := FField.FieldByName('data_type').AsString;
        campo.Nulo := FField.FieldByName('is_nullable').AsString;
        campo.Valor := FField.FieldByName('value').AsString;
        campo.Padrao := FField.FieldByName('valuedefault').AsString;
        campo.Alterado := FField.FieldByName('changed').AsInteger;
        Campos.Add(campo);

        If (campo.Nulo = 'NO') and (campo.Valor.IsEmpty) and Not (FPrimaryKey = Campo.Coluna) Then Begin
          raise Exception.Create('Campo ' + campo.Coluna + ' Não pode ser nulo!');
          Exit;
        End;

        If (campo.Nulo = 'YES') and (campo.Valor.IsEmpty) and Not (FPrimaryKey = Campo.Coluna) Then Begin
          campo.Valor := 'NULL'
        End;

        If Not (FPrimaryKey = Campo.Coluna) then
        Begin
          Str := Str + campo.Coluna + ', ';
          //'SMALLINT,INTEGER,INT,TINYINT,BIGINT,FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY,DATE,TIME,TIMESTAMP,DATETIME,CHAR,VARCHAR,BLOB,TEXT';
          //    0       1      2    3       4     5      6               7      8         9    10    11       12       13    14     15   16
          Case AnsiIndexStr(UpperCase(campo.Tipo), FstrSplit(FFieldsType, ',', false)) of
            0, 1, 2, 3, 4: StrValor := StrValor + campo.Valor + ','; //SMALLINT,INTEGER,INT,TINYINT,BIGINT
            5, 6, 7, 8: StrValor := StrValor + campo.Valor + ','; //FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY
            9: //DATE
              Begin
                StrValor := StrValor + QuotedStr(FormatDateTime('yyyy-mm-dd', StrToDate(campo.Valor))) + ',';
              end;
            10: //TIME
              Begin
                StrValor := StrValor + QuotedStr(FormatDateTime('hh:nn:mm', StrToTime(campo.Valor))) + ',';
              end;
            11, 12: //TIMESTAMP,DATETIME
              Begin
                StrValor := StrValor + QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:mm.zzz', StrToDateTime(campo.Valor))) + ',';
              end;
            13, 14: StrValor := StrValor + QuotedStr(campo.Valor) + ','; //CHAR,VARCHAR
            15, 16: StrValor := StrValor + QuotedStr(campo.Valor) + ','; //BLOB,TEXT
          End;
        End;
        FField.Next;
      End;

      Str := copy(Str, 1, Length(Str) - 2);
      StrValor := copy(StrValor, 1, Length(StrValor) - 1);
    Finally
      campo.Free;
      campos.Free;
    End;
    FField.Filtered := False;

    Str := 'INSERT INTO ' + FTable + ' (' + Str + ')  ' + LineEnding +
      'VALUES (' + StrValor + ') ;' + LineEnding;
  End;

  Result := Str
end;

function TProviders.SQLChangedFieldsInsertA(const AColunas: String; const AValores: String): String;
Var
  i: integer;
  Str: String;
  StrValor: String;
  _SQL: String;
  Campo: TCampo;
  Campos: Tlist<TCampo>;
  tabela: String;
begin
  FField.Refresh;
  FField.First;
  FField.Filter := 'pkey is null and changed = ''1'' ';
  FField.Filtered := True;
  Str := '';
  StrValor := '';
  If Not FField.IsEmpty Then Begin
    Try
      campo := TCampo.Create;
      Campos := Tlist<TCampo>.Create;
      While Not FField.Eof do
      Begin
        campo.Coluna := FField.FieldByName('column_name').AsString;
        campo.Tipo := lowercase(FField.FieldByName('data_type').AsString);
        campo.Nulo := FField.FieldByName('is_nullable').AsString;
        campo.Valor := FField.FieldByName('value').AsString;
        campo.Padrao := FField.FieldByName('valuedefault').AsString;
        campo.Alterado := FField.FieldByName('changed').AsInteger;
        Campos.Add(campo);

        If (campo.Nulo = 'NO') and (campo.Valor.IsEmpty) and Not (FPrimaryKey = Campo.Coluna) Then Begin
          raise Exception.Create('Campo ' + campo.Coluna + ' Não pode ser nulo!');
          Exit;
        End;

        If (campo.Nulo = 'YES') and (campo.Valor.IsEmpty) and Not (FPrimaryKey = Campo.Coluna) Then Begin
          campo.Valor := 'NULL'
        End;

        If Not (FPrimaryKey = Campo.Coluna) then
        Begin
          Str := Str + campo.Coluna + ', ';

          i := FTipoVariavel.tipo(campo.Tipo);

          Try
            Case i of
              0: StrValor := StrValor + campo.Valor + ','; //tipo numerico
              1: StrValor := StrValor + QuotedStr(campo.Valor) + ','; //tipo carecter
              2: StrValor := StrValor + QuotedStr(FormatDateTime('hh:nn:mm', StrToDate(campo.Valor))) + ',';
              3: StrValor := StrValor + QuotedStr(FormatDateTime('yyyy-mm-dd', StrToDate(campo.Valor))) + ',';
              4: StrValor := StrValor + QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:mm.zzz', StrToDate(campo.Valor))) + ',';
              5:;
            End;
          Finally

          End;
        End;
        FField.Next;
      End;

      Str := copy(Str, 1, Length(Str) - 2);
      StrValor := copy(StrValor, 1, Length(StrValor) - 1);
    Finally
      campo.Free;
      campos.Free;
    End;
    FField.Filtered := False;

    Str := 'INSERT INTO ' + FTableTexto + ' (' + Str + ')  ' + LineEnding +
      'VALUES (' + StrValor + ')  ' + LineEnding;
  End;

  If FProvider = dpPostgreSQL Then
    Str := StringReplace(
      '''
            WITH Insercao AS (
                [VInsert]
                RETURNING * -- Retorna todas as colunas da linha inserida para a CTE
            )
            SELECT ni.*, 'Inserção Concluída' AS status_mensagem -- Você pode adicionar colunas extras no SELECT final
            FROM insercao ni;
          ''', '[VInsert]', Str, [rfReplaceAll, rfIgnoreCase]);

  Result := Str + ';';
end;

function TProviders.SQLChangedfieldsUpdate(const AColunas: String; const AValores: String): String;
Var
  i: integer;
  Str: String;
  _SQL: String;
  Campo: TCampo;
  Campos: Tlist<TCampo>;
  StrKey: String;
begin
  FId := ReturnQry.FieldByName(FPrimaryKey).AsInteger;
  FField.Filter := 'changed = 1';
  FField.Filtered := true;
  Str := '';
  If Not FField.IsEmpty Then Begin
    try
      campo := TCampo.Create;
      Campos := Tlist<TCampo>.Create;
      While Not FField.Eof do
      Begin
        campo.Coluna := FField.FieldByName('column_name').AsString;
        campo.Tipo := FField.FieldByName('data_type').AsString;
        campo.Nulo := FField.FieldByName('is_nullable').AsString;
        campo.Valor := FField.FieldByName('value').AsString;
        campo.Padrao := FField.FieldByName('valuedefault').AsString;
        campo.Alterado := FField.FieldByName('changed').AsInteger;
        Campos.Add(campo);

        //'SMALLINT,INTEGER,INT,TINYINT,BIGINT,FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY,DATE,TIME,TIMESTAMP,DATETIME,CHAR,VARCHAR,BLOB,TEXT, SMALLDATETIME';
        //    0       1      2    3       4     5      6               7      8         9    10    11       12       13    14     15   16      17
        Case AnsiIndexStr(UpperCase(campo.Tipo), FstrSplit(FFieldsType, ',', false)) of
          0, 1, 2, 3, 4: Str := Str + campo.Coluna + ' = ' + campo.Valor + ','; //SMALLINT,INTEGER,INT,TINYINT,BIGINT
          5, 6, 7, 8: Str := Str + campo.Coluna + ' = ' + campo.Valor + ','; //FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY
          9, 10, 11, 12, 17: Str := Str + campo.Coluna + ' = ' + QuotedStr(campo.Valor) + ','; //DATE,TIME,TIMESTAMP,DATETIME
          13, 14: Str := Str + campo.Coluna + ' = ' + QuotedStr(campo.Valor) + ','; //CHAR,VARCHAR
          15, 16: Str := Str + campo.Coluna + ' = ' + QuotedStr(campo.Valor) + ','; //BLOB,TEXT
        End;

        FField.Next;
      End;
      Str := copy(Str, 1, Length(Str) - 1);
    finally
      Campo.Free;
      campos.Free;
    end;
    FField.Filtered := False;

    campo := TCampo.Create;
    Campos := Tlist<TCampo>.Create;

    try
      FField.Filter := 'PKey =  1';
      FField.Filtered := true;
      FField.First;
      StrKey := '';
      i := 1;
      While Not FField.Eof do
      Begin
        If i = 1 Then StrKey := StrKey + 'Where ' Else StrKey := StrKey + 'And ';
        campo.Coluna := FField.FieldByName('column_name').AsString;
        campo.Tipo := FField.FieldByName('data_type').AsString;
        campo.Nulo := FField.FieldByName('is_nullable').AsString;
        campo.Valor := FField.FieldByName('value').AsString;
        campo.Padrao := FField.FieldByName('valuedefault').AsString;
        campo.Alterado := FField.FieldByName('changed').AsInteger;
        Campos.Add(campo);
        //'SMALLINT,INTEGER,INT,TINYINT,BIGINT,FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY,DATE,TIME,TIMESTAMP,DATETIME,CHAR,VARCHAR,BLOB,TEXT';
        //    0       1      2    3       4     5      6               7      8         9    10    11       12       13    14     15   16
        Case AnsiIndexStr(UpperCase(campo.Tipo), FstrSplit(FFieldsType, ',', false)) of
          0, 1, 2, 3, 4: StrKey := StrKey + campo.Coluna + ' = ' + campo.Valor + LineEnding; //SMALLINT,INTEGER,INT,TINYINT,BIGINT
          5, 6, 7, 8: StrKey := StrKey + campo.Coluna + ' = ' + campo.Valor + LineEnding; //FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY
          9, 10, 11, 12: StrKey := StrKey + campo.Coluna + ' = ' + QuotedStr(campo.Valor) + LineEnding; //DATE,TIME,TIMESTAMP,DATETIME
          13, 14: StrKey := StrKey + campo.Coluna + ' = ' + QuotedStr(campo.Valor) + LineEnding; //CHAR,VARCHAR
          15, 16: StrKey := StrKey + campo.Coluna + ' = ' + QuotedStr(campo.Valor) + LineEnding; //BLOB,TEXT
        End;
        inc(i);
        FField.Next;
      End;
      FField.Filtered := False;
    finally
      Campo.Free;
      campos.Free;
    end;

    Str := 'UPDATE ' + FTable + '  Set ' + LineEnding + Str + LineEnding +
      Strkey + ' ;';
  End;

  Result := Str
end;

function TProviders.SQLChangedfieldsUpdateA(const AColunas: String; const AValores: String): String;
Var
  i, j: integer;
  Str: String;
  _SQL: String;
  Campo: TCampo;
  Campos: Tlist<TCampo>;
  StrKey: String;
begin
  FId := ReturnQry.FieldByName(FPrimaryKey).AsInteger;
  FField.Filter := 'changed = 1';
  FField.Filtered := true;
  Str := '';
  If Not FField.IsEmpty Then Begin
    try
      campo := TCampo.Create;
      Campos := Tlist<TCampo>.Create;
      While Not FField.Eof do
      Begin
        campo.Coluna := FField.FieldByName('column_name').AsString;
        campo.Tipo := LowerCase(FField.FieldByName('data_type').AsString);
        campo.Nulo := FField.FieldByName('is_nullable').AsString;
        campo.Valor := FField.FieldByName('value').AsString;
        campo.Padrao := FField.FieldByName('valuedefault').AsString;
        campo.Alterado := FField.FieldByName('changed').AsInteger;
        campo.PKey := FField.FieldByName('PKey').AsInteger;
        Campos.Add(campo);

        If (campo.Nulo = 'NO') and (campo.Valor.IsEmpty) Then Begin
          raise Exception.Create('Campo ' + campo.Coluna + 'Não pode ser nulo!');
          Exit;
        End;

        j := FTipoVariavel.tipo(campo.Tipo);

        Try
          Case j of
            0: Str := Str + campo.Coluna + ' = ' + campo.Valor + ','; //SMALLINT,INTEGER,INT,TINYINT,BIGINT
            1: Str := Str + campo.Coluna + ' = ' + QuotedStr(campo.Valor) + ','; //CHAR,VARCHAR
            2: Str := Str + campo.Coluna + ' = ' + QuotedStr(campo.Valor) + ','; //DATE,TIME,TIMESTAMP,DATETIME
            3: Str := Str + campo.Coluna + ' = ' + QuotedStr(campo.Valor) + ','; //DATE,TIME,TIMESTAMP,DATETIME
            4: Str := Str + campo.Coluna + ' = ' + QuotedStr(campo.Valor) + ','; //DATE,TIME,TIMESTAMP,DATETIME
          End;
        Finally

        End;

        FField.Next;
      End;
      Str := copy(Str, 1, Length(Str) - 1);
    finally
      Campo.Free;
      campos.Free;
    end;
    FField.Filtered := False;

    campo := TCampo.Create;
    Campos := Tlist<TCampo>.Create;

    try
      FField.First;
      FField.Filter := 'PKey =  1';
      FField.Filtered := true;
      StrKey := '';
      i := 1;
      While Not FField.Eof do
      Begin
        If i = 1 Then StrKey := StrKey + 'Where ' Else StrKey := StrKey + 'And ';
        campo.Coluna := FField.FieldByName('column_name').AsString;
        campo.Tipo := LowerCase(FField.FieldByName('data_type').AsString);
        campo.Nulo := FField.FieldByName('is_nullable').AsString;
        campo.Valor := FField.FieldByName('value').AsString;
        campo.Padrao := FField.FieldByName('valuedefault').AsString;
        campo.Alterado := FField.FieldByName('changed').AsInteger;
        Campos.Add(campo);

        j := FTipoVariavel.tipo(campo.Tipo);

        Case j of
          0: StrKey := StrKey + campo.Coluna + ' = ' + campo.Valor + LineEnding; //SMALLINT,INTEGER,INT,TINYINT,BIGINT
          1: StrKey := StrKey + campo.Coluna + ' = ' + QuotedStr(campo.Valor) + LineEnding; //DATE,TIME,TIMESTAMP,DATETIME
          2: StrKey := StrKey + campo.Coluna + ' = ' + QuotedStr(campo.Valor) + LineEnding; //CHAR,VARCHAR
          3: StrKey := StrKey + campo.Coluna + ' = ' + QuotedStr(campo.Valor) + LineEnding; //BLOB,TEXT
          4: StrKey := StrKey + campo.Coluna + ' = ' + QuotedStr(campo.Valor) + LineEnding; //BLOB,TEXT
        End;

        inc(i);
        FField.Next;
      End;
      FField.Filtered := False;
    finally
      Campo.Free;
      campos.Free;
    end;

    Str := 'UPDATE ' + FTableTexto + '  Set ' + LineEnding + Str + LineEnding + Strkey;
  End;

  If FProvider = dpPostgreSQL Then
    Str := StringReplace(
      '''
            WITH Alteracao AS (
                [VAlteracao]
                RETURNING * -- Retorna todas as colunas da linha alteradas para a CTE
            )
            SELECT ni.*, 'Alteracao Concluída' AS status_mensagem -- Você pode adicionar colunas extras no SELECT final
            FROM Alteracao ni;
          ''', '[VAlteracao]', Str, [rfReplaceAll, rfIgnoreCase]);
  Result := Str + ' ;'
end;

function TProviders.SQLConditionPrimaryKey(const ADataSource: TUniDataSource; const ATableAlias: Boolean): String;
Var
  i: integer;
  Str: String;
  _SQL: String;
  Campo: TCampo;
  Campos: Tlist<TCampo>;
  StrKey: String;
  TabAlias: String;
begin
  FField.First;
  FField.Filter := 'PKey = 1';
  FField.Filtered := true;
  Str := '';
  If ATableAlias Then
    TabAlias := FTableAlias + '.'
  Else
    TabAlias := '';

  If Not FField.IsEmpty Then Begin
    try
      campo := TCampo.Create;
      Campos := Tlist<TCampo>.Create;
      While Not FField.Eof do
      Begin
        campo.Coluna := FField.FieldByName('column_name').AsString;
        campo.Tipo := FField.FieldByName('data_type').AsString;
        campo.Nulo := FField.FieldByName('is_nullable').AsString;
        campo.Valor := Trim(TUniQuery(ADataSource.DataSet).FieldByName(campo.Coluna).AsString);
        campo.Padrao := Trim(TUniQuery(ADataSource.DataSet).FieldByName(campo.Coluna).AsString);
        campo.Alterado := FField.FieldByName('changed').AsInteger;
        Campos.Add(campo);

        //'SMALLINT,INTEGER,INT,TINYINT,BIGINT,FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY,DATE,TIME,TIMESTAMP,DATETIME,CHAR,VARCHAR,BLOB,TEXT';
        //    0       1      2    3       4     5      6               7      8         9    10    11       12       13    14     15   16
        Case AnsiIndexStr(UpperCase(campo.Tipo), FstrSplit(FFieldsType, ',', false)) of
          0, 1, 2, 3, 4: Str := Str + 'And ' + TabAlias + campo.Coluna + ' = ' + campo.Valor + LineEnding; //SMALLINT,INTEGER,INT,TINYINT,BIGINT
          5, 6, 7, 8: Str := Str + 'And ' + TabAlias + campo.Coluna + ' = ' + campo.Valor + LineEnding; //FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY
          9, 10, 11, 12: Str := Str + 'And ' + TabAlias + campo.Coluna + ' = ' + QuotedStr(Trim(campo.Valor)) + LineEnding; //DATE,TIME,TIMESTAMP,DATETIME
          13, 14: Str := Str + 'And ' + TabAlias + campo.Coluna + ' = ' + QuotedStr(Trim(campo.Valor)) + LineEnding; //CHAR,VARCHAR
          15, 16: Str := Str + 'And ' + TabAlias + campo.Coluna + ' = ' + QuotedStr(Trim(campo.Valor)) + LineEnding; //BLOB,TEXT
        End;
        FField.Next;
      End;
      //Str := copy(Str,1,Length(Str) - 3) ;
    finally
      Campo.Free;
      campos.Free;
    end;
    FField.Filtered := False;
  End;
  Result := Str
end;

function TProviders.SQLConditionPrimaryKey(const ATableAlias: Boolean): String;
Var
  Coluna, Tipo, ValorDefault, Alteracao, Str: String;
  Valor: String;
  TabAlias: String;
begin
  FField.Filter := 'Pkey = 1';
  FField.Filtered := True;
  FPrimaryKey := '';
  FPrimaryKeySQL := '';

  If ATableAlias Then
    TabAlias := FTableAlias + '.'
  Else
    TabAlias := '';

  If Not FFields.IsEmpty Then Begin
    While Not FField.Eof do
    Begin
      Coluna := FField.FieldByName('column_name').AsString;
      Tipo := FField.FieldByName('data_type').AsString;
      Valor := Trim(ReturnQry.FieldByName(coluna).AsString);

      FField.edit;
      FField.FieldByName('value').AsString := Valor;
      FField.FieldByName('valuedefault').AsString := Valor;
      FField.FieldByName('changed').AsInteger := 0;
      FField.Post;

      FPrimaryKey := FPrimaryKey + Coluna + ',';
      //'SMALLINT,INTEGER,INT,TINYINT,BIGINT,FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY,DATE,TIME,TIMESTAMP,DATETIME,CHAR,VARCHAR,BLOB,TEXT';
      //    0       1      2    3       4     5      6               7      8         9    10    11       12       13    14     15   16
      Case AnsiIndexStr(UpperCase(Tipo), FstrSplit(FFieldsType, ',', false)) of
        0, 1, 2, 3, 4: Str := Str + 'And ' + TabAlias + Coluna + ' = ' + Valor + LineEnding; //SMALLINT,INTEGER,INT,TINYINT,BIGINT
        5, 6, 7, 8: Str := Str + 'And ' + TabAlias + Coluna + ' = ' + Valor + LineEnding; //FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY
        9, 10, 11, 12: Str := Str + 'And ' + TabAlias + Coluna + ' = ' + QuotedStr(Trim(Valor)) + LineEnding; //DATE,TIME,TIMESTAMP,DATETIME
        13, 14: Str := Str + 'And ' + TabAlias + Coluna + ' = ' + QuotedStr(Trim(Valor)) + LineEnding; //CHAR,VARCHAR
        15, 16: Str := Str + 'And ' + TabAlias + Coluna + ' = ' + QuotedStr(Trim(Valor)) + LineEnding; //BLOB,TEXT
      End;
      FField.Next;
    End;
  End;
  FPrimaryKey := copy(PrimaryKey, 1, Length(PrimaryKey) - 1);
  FPrimaryKeySQL := Str;
  Result := Str;
  FField.Filtered := False;
end;

function TProviders.SQLConditionFilterField(AIndex: Integer; ACondicao: String): String;
Var
  i: integer;
  Str: String;
  _SQL: String;
  Campo: TCampo;
  Campos: Tlist<TCampo>;
  StrFiltro: String;
  S: String;
begin
  Str := '';
  FField.First;
  If Not FField.IsEmpty Then Begin
    try
      campo := TCampo.Create;
      Campos := Tlist<TCampo>.Create;
      If (AIndex = 0) then Begin
        S := '';
        var TotalReg: Integer := FField.RecordCount;
        FField.Filter := ' data_type = ''VARCHAR'' OR ' +
          ' data_type = ''CHAR''    OR ' +
          ' data_type = ''BLOD''    OR ' +
          ' data_type = ''TEXT''       ';

        FField.Filtered := True;
        TotalReg := FField.RecordCount;
        While Not FField.Eof do
        Begin
          campo.Coluna := FField.FieldByName('column_name').AsString;
          campo.Tipo := FField.FieldByName('data_type').AsString;
          Campos.Add(campo);

          //'SMALLINT,INTEGER,INT,TINYINT,BIGINT,FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY,DATE,TIME,TIMESTAMP,DATETIME,CHAR,VARCHAR,BLOB,TEXT';
          //    0       1      2    3       4     5      6               7      8         9    10    11       12       13    14     15   16
          Case AnsiIndexStr(UpperCase(campo.Tipo), FstrSplit(FFieldsType, ',', false)) of
            13, 14, 15, 16: Str := Str + S + campo.Coluna + ' LIKE ' + QuotedStr(ACondicao) + LineEnding; //CHAR,VARCHAR,BLOB,TEXT
          End;
          S := 'OR ';
          FField.Next;
        End;
        FField.Filtered := false;
        Str := 'And(' + LineEnding + Str + ' ) ';
      End
      Else Begin
        While Not FField.Eof do
        Begin
          campo.Coluna := FField.FieldByName('column_name').AsString;
          campo.Tipo := FField.FieldByName('data_type').AsString;
          Campos.Add(campo);

          //'SMALLINT,INTEGER,INT,TINYINT,BIGINT,FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY,DATE,TIME,TIMESTAMP,DATETIME,CHAR,VARCHAR,BLOB,TEXT';
          //    0       1      2    3       4     5      6               7      8         9    10    11       12       13    14     15   16
          Case AnsiIndexStr(UpperCase(campo.Tipo), FstrSplit(FFieldsType, ',', false)) of
            13, 14, 15, 16: StrFiltro := StrFiltro + campo.Coluna + ','; //CHAR,VARCHAR,BLOB,TEXT
          End;
          FField.Next;
        End;
        StrFiltro := copy(StrFiltro, 1, Length(StrFiltro) - 1);
        Str := Str + 'And ' + ArrayField(StrFiltro, ',', AIndex) + ' LIKE ' + QuotedStr(ACondicao) + LineEnding
      End;
    finally
      Campo.Free;
      campos.Free;
    end;
    FField.Filtered := False;
  End;
  Result := Str
end;

{$IF DEFINED(MSWINDOWS) AND NOT DEFINED(FPC)}
// Métodos Windows - v1.6.1: Implementação completa mantendo compatibilidade com v1.5.0

procedure TProviders.ChangedFieldsComboBox(AObject: TComboBox);
Var
  i: integer;
  Str: String;
  _SQL: String;
  Campo: TCampo;
  StrFiltro: String;
  VName: String;
begin
  Str := '';
  FField.First;
  If Not FField.IsEmpty Then Begin
    try
      campo := TCampo.Create;
      AObject.Clear;
      AObject.Items.Add('Selecionar');

      While Not FField.Eof do
      Begin
        campo.Coluna := FField.FieldByName('column_name').AsString;
        campo.Tipo := FField.FieldByName('data_type').AsString;

        //'SMALLINT,INTEGER,INT,TINYINT,BIGINT,FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY,DATE,TIME,TIMESTAMP,DATETIME,CHAR,VARCHAR,BLOB,TEXT';
        //    0       1      2    3       4     5      6               7      8         9    10    11       12       13    14     15   16
        Case AnsiIndexStr(UpperCase(campo.Tipo), FstrSplit(FFieldsType, ',', false)) of
          13, 14, 15, 16: AObject.Items.Add(campo.Coluna); //CHAR,VARCHAR,BLOB,TEXT
        End;
        FField.Next;
      End;
      AObject.ItemIndex := 0
    finally
      Campo.Free;
    end;
    FField.Filtered := False;
    VName := 'edt' + copy(AObject.Name, 3, length(AObject.Name));
    AObject.ItemIndex := 0;
    TcxTextEdit(self.FindComponent(VName)).Text := 'Selecionar';
  End;
end;

procedure TProviders.Changedfields(AObject: TcxTextEdit);
Var
  LCampo: String;
  i: integer;
  Str: String;
begin
  LCampo := copy(AObject.Name, 4, length(AObject.Name));
  If AObject.Tag < 5 Then
  Begin
    with AObject do Begin
      FField.First;
      FField.Filter := 'column_name = ' + QuotedStr(LCampo);
      FField.Filtered := True;
      If Not FField.IsEmpty then
      Begin
        FField.Edit;
        //'SMALLINT,INTEGER,INT,TINYINT,BIGINT,FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY,DATE,TIME,TIMESTAMP,DATETIME,CHAR,VARCHAR,BLOB,TEXT';
        //    0       1      2    3       4     5      6               7      8         9    10    11       12       13    14     15   16
        Case AnsiIndexStr(UpperCase(FField.FieldByName('data_type').AsString), FstrSplit(FFieldsType, ',', false)) of
          0, 1, 2, 3, 4: //SMALLINT,INTEGER,INT,TINYINT,BIGINT
          Begin
            Try
              If Not (Text = EmptyStr) Then
              Begin
                If (Parent.FindChildControl('cb' + LCampo) is TComboBox) Then
                  FField.FieldByName('value').AsInteger := TComboBox(Parent.FindChildControl('cb' + LCampo)).ItemIndex
                Else
                  FField.FieldByName('value').AsInteger := Trim(Text).ToInteger;
              End
              Else
                ;
            except
              ShowMessage('Não é TComboBox' + LineEnding +
                'column_name = ' + QuotedStr(LCampo) + LineEnding +
                'Valor: ' + Trim(Text))
            End;
          End;
          5, 6, 7, 8: //FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY
            If Not (Text = EmptyStr) Then
            Begin
              FField.FieldByName('value').AsFloat := StrToFloat(Text);
            End;
          9, 10, 11, 12:; //DATE,TIME,TIMESTAMP,DATETIME
          13, 14: FField.FieldByName('value').AsString := Trim(Text); //CHAR,VARCHAR
          15, 16: FField.FieldByName('value').AsString := Trim(Text); //BLOB,TEXT
          Else FField.FieldByName('value').AsString := Trim(Text);
        End;
        FField.FieldByName('changed').AsInteger := IfThen(
          (Not (Trim(FField.FieldByName('value').AsString) =
          Trim(FField.FieldByName('valuedefault').AsString))), '1', '0').ToInteger;
        FField.Post;
      End;
      FField.Filtered := False;
    End; //With
  End; //if
end;

procedure TProviders.Changedfields(AObject: TComboBox; Const ACodigo: string = '');
Var
  LCampo: String;
  i: integer;
  Str: String;
begin
  LCampo := copy(AObject.Name, 3, length(AObject.Name));
  If AObject.Tag < 5 Then
  Begin
    with AObject do Begin
      FField.First;
      FField.Filter := 'column_name = ' + QuotedStr(LCampo);
      FField.Filtered := True;
      If Not FField.IsEmpty then
      Begin
        FField.Edit;
        //'SMALLINT,INTEGER,INT,TINYINT,BIGINT,FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY,DATE,TIME,TIMESTAMP,DATETIME,CHAR,VARCHAR,BLOB,TEXT';
        //    0       1      2    3       4     5      6               7      8         9    10    11       12       13    14     15   16
        Case AnsiIndexStr(UpperCase(FField.FieldByName('data_type').AsString), FstrSplit(FFieldsType, ',', false)) of
          0, 1, 2, 3, 4: //SMALLINT,INTEGER,INT,TINYINT,BIGINT
          Begin
            Try
              If (Parent.FindChildControl('cb' + LCampo) is TComboBox) Then
                FField.FieldByName('value').AsInteger := TComboBox(Parent.FindChildControl('cb' + LCampo)).ItemIndex
              Else
                FField.FieldByName('value').AsInteger := Trim(Text).ToInteger;
            except
              ShowMessage('Não é tcombobox')
            End;
          End;
          5, 6, 7, 8: //FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY
            FField.FieldByName('value').AsFloat := Trim(Text).ToDouble;
          9, 10, 11, 12:; //DATE,TIME,TIMESTAMP,DATETIME
          13, 14: Begin
            FField.FieldByName('value').AsString := ACodigo;
          End; //CHAR,VARCHAR
          15, 16:; //BLOB,TEXT
          Else FField.FieldByName('value').AsString := Trim(Text);
        End;

        FField.FieldByName('changed').AsInteger := IfThen(
          (Not (Trim(FField.FieldByName('value').AsString) =
          Trim(FField.FieldByName('valuedefault').AsString))), '1', '0').ToInteger;
        FField.Post;
      End;
      FField.Filtered := False;
    End; //With
  End; //if
end;

procedure TProviders.Changedfields(AObject: TEdit);
Var
  LCampo: String;
  i: integer;
  Str: String;
begin
  LCampo := copy(AObject.Name, 4, length(AObject.Name));
  If AObject.Tag < 5 Then
  Begin
    with AObject do Begin
      FField.First;
      FField.Filter := 'column_name = ' + QuotedStr(LCampo);
      FField.Filtered := True;
      If Not FField.IsEmpty then
      Begin
        FField.Edit;
        //'SMALLINT,INTEGER,INT,TINYINT,BIGINT,FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY,DATE,TIME,TIMESTAMP,DATETIME,CHAR,VARCHAR,BLOB,TEXT';
        //    0       1      2    3       4     5      6               7      8         9    10    11       12       13    14     15   16
        Case AnsiIndexStr(UpperCase(FField.FieldByName('data_type').AsString), FstrSplit(FFieldsType, ',', false)) of
          0, 1, 2, 3, 4: //SMALLINT,INTEGER,INT,TINYINT,BIGINT
          Begin
            Try
              If (Parent.FindChildControl('cb' + LCampo) is TComboBox) Then
                FField.FieldByName('value').AsInteger := TComboBox(Parent.FindChildControl('cb' + LCampo)).ItemIndex
              Else
                FField.FieldByName('value').AsInteger := Trim(Text).ToInteger;
            except
              ShowMessage('Não é tcombobox')
            End;
          End;
          5, 6, 7, 8: //FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY
            FField.FieldByName('value').AsFloat := Trim(Text).ToDouble;
          9, 10, 11, 12:; //DATE,TIME,TIMESTAMP,DATETIME
          13, 14:; //CHAR,VARCHAR
          15, 16:; //BLOB,TEXT
          Else FField.FieldByName('value').AsString := Trim(Text);
        End;
        FField.FieldByName('changed').AsInteger := IfThen(
          (Not (Trim(FField.FieldByName('value').AsString) =
          Trim(FField.FieldByName('valuedefault').AsString))), '1', '0').ToInteger;
        FField.Post;
      End;
      FField.Filtered := False;
    End; //With
  End; //if
end;

procedure TProviders.Changedfields(AObject: TRzDateTimeEdit);
Var
  LCampo: String;
  VName: String;
  i: integer;
  Str: String;
begin
  LCampo := copy(AObject.Name, 3, length(AObject.Name));
  If AObject.Tag < 5 Then
  Begin
    with AObject do Begin
      FField.First;
      FField.Filter := 'column_name = ' + QuotedStr(LCampo);
      FField.Filtered := True;
      If Not FField.IsEmpty then
      Begin
        FField.Edit;
        //'SMALLINT,INTEGER,INT,TINYINT,BIGINT,FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY,DATE,TIME,TIMESTAMP,DATETIME,CHAR,VARCHAR,BLOB,TEXT';
        //    0       1      2    3       4     5      6               7      8         9    10    11       12       13    14     15   16
        Case AnsiIndexStr(UpperCase(FField.FieldByName('data_type').AsString), FstrSplit(FFieldsType, ',', false)) of
          0, 1, 2, 3, 4:; //SMALLINT,INTEGER,INT,TINYINT,BIGINT
          5, 6, 7, 8:; //FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY
          9, 10, 11, 12: FField.FieldByName('value').AsDateTime := AObject.AsDateTime; //DATE,TIME,TIMESTAMP,DATETIME
          13, 14:; //CHAR,VARCHAR
          15, 16:; //BLOB,TEXT
          Else FField.FieldByName('value').AsString := Trim(Text);
        End;
        FField.FieldByName('changed').AsInteger := IfThen(
          (Not (Trim(FField.FieldByName('value').AsString) =
          Trim(FField.FieldByName('valuedefault').AsString))), '1', '0').ToInteger;
        FField.Post;
      End;
      FField.Filtered := False;
    End; //With
  End; //if
end;

procedure TProviders.Changedfields(AObject: TcxCurrencyEdit);
Var
  LCampo: String;
  i: integer;
  Str: String;
begin
  LCampo := copy(AObject.Name, 4, length(AObject.Name));
  If AObject.Tag < 5 Then
  Begin
    with AObject do Begin
      FField.First;
      FField.Filter := 'column_name = ' + QuotedStr(LCampo);
      FField.Filtered := True;
      If Not FField.IsEmpty then
      Begin
        FField.Edit;
        //'SMALLINT,INTEGER,INT,TINYINT,BIGINT,FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY,DATE,TIME,TIMESTAMP,DATETIME,CHAR,VARCHAR,BLOB,TEXT';
        //    0       1      2    3       4     5      6               7      8         9    10    11       12       13    14     15   16
        Case AnsiIndexStr(UpperCase(FField.FieldByName('data_type').AsString), FstrSplit(FFieldsType, ',', false)) of
          0, 1, 2, 3, 4: //SMALLINT,INTEGER,INT,TINYINT,BIGINT
            Begin
              Try
                If (Parent.FindChildControl('cb' + LCampo) is TComboBox) Then
                  FField.FieldByName('value').AsInteger := TComboBox(Parent.FindChildControl('cb' + LCampo)).ItemIndex
                Else
                  FField.FieldByName('value').AsFloat := Value;
              except
                on ex: Exception do
                begin
                  ShowMessage('Não é TComboBox: ' + ex.Message);
                end;
              End;
            End;
          5, 6, 7, 8: //FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY
            FField.FieldByName('value').AsFloat := Value;
          9, 10, 11, 12:; //DATE,TIME,TIMESTAMP,DATETIME
          13, 14:; //CHAR,VARCHAR
          15, 16:; //BLOB,TEXT
          Else FField.FieldByName('value').AsFloat := Value;
        End;
        FField.FieldByName('changed').AsInteger := IfThen(
          (Not (Trim(FField.FieldByName('value').AsString) =
          Trim(FField.FieldByName('valuedefault').AsString))), '1', '0').ToInteger;
        FField.Post;
      End;
      FField.Filtered := False;
    End; //With
  End; //if
end;

procedure TProviders.Changedfields(AObject: TMemo);
Var
  LCampo: String;
  i: integer;
  Str: String;
begin
  LCampo := copy(AObject.Name, 4, length(AObject.Name));
  If AObject.Tag < 5 Then
  Begin
    with AObject do Begin
      FField.First;
      FField.Filter := 'column_name = ' + QuotedStr(LCampo);
      FField.Filtered := True;
      If Not FField.IsEmpty then
      Begin
        FField.Edit;
        //'SMALLINT,INTEGER,INT,TINYINT,BIGINT,FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY,DATE,TIME,TIMESTAMP,DATETIME,CHAR,VARCHAR,BLOB,TEXT';
        //    0       1      2    3       4     5      6               7      8         9    10    11       12       13    14     15   16
        Case AnsiIndexStr(UpperCase(FField.FieldByName('data_type').AsString), FstrSplit(FFieldsType, ',', false)) of
          0, 1, 2, 3, 4:; //SMALLINT,INTEGER,INT,TINYINT,BIGINT
          5, 6, 7, 8:; //FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY
          9, 10, 11, 12:; //DATE,TIME,TIMESTAMP,DATETIME
          13, 14: //CHAR,VARCHAR
            FField.FieldByName('value').AsString := copy(Lines.GetText, 1, FField.FieldByName('character_maximum_length').AsInteger);
          15, 16: //BLOB,TEXT
            FField.FieldByName('value').AsString := Lines.GetText;
          Else FField.FieldByName('value').AsString := Lines.GetText;
        End;
        FField.FieldByName('changed').AsInteger := IfThen(
          (Not (Trim(FField.FieldByName('value').AsString) =
          Trim(FField.FieldByName('valuedefault').AsString))), '1', '0').ToInteger;
        FField.Post;
      End;
      FField.Filtered := False;
    End; //With
  End; //if
end;

Function TProviders.ChangedActiveComboBox(AObject: TComboBox): String;
Var
  VName: String;
  _SQL: String;
begin
  VName := copy(AObject.Name, 3, length(AObject.Name));
  AObject.Clear;
  AObject.Items.Add('Selecionar');
  AObject.Items.Add('Ativo');
  AObject.Items.Add('Inativos');
  AObject.ItemIndex := 0;
  TcxTextEdit(AObject.Parent.FindChildControl('edt' + VName)).Text := AObject.Text;

  If Not FieldActived.IsEmpty Then
    Case AObject.ItemIndex of
      1: {ATIVO}
      Begin
        _SQL := _SQL +
          ' And   ' + FieldActived + ' = 0 ' + LineEnding;
      End;
      2: {INATIVO}
      Begin
        _SQL := _SQL +
          ' And   ' + FieldActived + ' = 1  ' + LineEnding;
      End;
    End;
  Result := _SQL
end;

procedure TProviders.Changedfields(AObject: TRzDateTimePicker);
Var
  LCampo: String;
  VName: String;
  i: integer;
  Str: String;
begin
  LCampo := copy(AObject.Name, 3, length(AObject.Name));
  If AObject.Tag < 5 Then
  Begin
    with AObject do Begin
      FField.First;
      FField.Filter := 'column_name = ' + QuotedStr(LCampo);
      FField.Filtered := True;
      If Not FField.IsEmpty then
      Begin
        FField.Edit;
        //'SMALLINT,INTEGER,INT,TINYINT,BIGINT,FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY,DATE,TIME,TIMESTAMP,DATETIME,CHAR,VARCHAR,BLOB,TEXT';
        //    0       1      2    3       4     5      6               7      8         9    10    11       12       13    14     15   16
        Case AnsiIndexStr(UpperCase(FField.FieldByName('data_type').AsString), FstrSplit(FFieldsType, ',', false)) of
          0, 1, 2, 3, 4:; //SMALLINT,INTEGER,INT,TINYINT,BIGINT
          5, 6, 7, 8:; //FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY
          9, 10, 11, 12: FField.FieldByName('value').AsDateTime := AObject.DateTime; //DATE,TIME,TIMESTAMP,DATETIME
          13, 14:; //CHAR,VARCHAR
          15, 16:; //BLOB,TEXT
          Else FField.FieldByName('value').AsDateTime := AObject.DateTime;
        End;
        FField.FieldByName('changed').AsInteger := IfThen(
          (Not (Trim(FField.FieldByName('value').AsString) =
          Trim(FField.FieldByName('valuedefault').AsString))), '1', '0').ToInteger;
        FField.Post;
      End;
      FField.Filtered := False;
    End; //With
  End; //if
end;

function TProviders.FillInData(Aform: TForm; procTerminate: TProviderThreadMethod): Boolean;
Var
  Coluna: String;
  Valor: String;
  Tipo: String;
  Str: String;
  VName: String;
  PKey: Boolean;
  i: Integer;
begin
  FField.Filtered := False;
  FField.First;
  While Not FField.Eof do
  Begin
    FField.Edit;
    Coluna := FField.FieldByName('column_name').AsString;
    Valor := UpperCase(ReturnQry.FieldByName(Coluna).AsString);
    Tipo := UpperCase(FField.FieldByName('data_type').AsString);
    PKey := (FField.FieldByName('PKey').AsInteger = 1);

    FField.FieldByName('value').AsString := Valor;
    FField.FieldByName('valuedefault').AsString := Valor;
    FField.FieldByName('changed').AsInteger := 0;

    try
      //'SMALLINT,INTEGER,INT,TINYINT,BIGINT,FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY,DATE,TIME,TIMESTAMP,DATETIME,CHAR,VARCHAR,BLOB,TEXT';
      //    0       1      2    3       4     5      6               7      8         9    10    11       12       13    14     15   16
      Case AnsiIndexStr(Tipo, FstrSplit(FieldsType, ',', false)) of
        0, 1, 2, 3, 4: //SMALLINT,INTEGER,INT,TINYINT,BIGINT
          Begin
            if (Aform.FindComponent('cb' + Coluna) is TComboBox) Then begin
              TComboBox(Aform.FindComponent('cb' + Coluna)).ItemIndex := Valor.ToInteger;
              TcxTextEdit(Aform.FindComponent('edt' + Coluna)).Text := TComboBox(Aform.FindComponent('cb' + Coluna)).Text;
            end
            Else Begin
              TcxTextEdit(Aform.FindComponent('edt' + Coluna)).Text := Valor;
            End;
          End;
        5, 6, 7, 8: //FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY
          TcxCurrencyEdit(Aform.FindComponent('edt' + Coluna)).Value := Valor.ToDouble;
        9, 10, 11, 12: //DATE,TIME,TIMESTAMP,DATETIME
          TcxTextEdit(Aform.FindComponent('edt' + Coluna)).Text := Valor;
        13, 14: //CHAR,VARCHAR
          Begin
            if (Aform.FindComponent('cb' + Coluna) is TComboBox) Then begin
              Case AnsiIndexStr(UpperCase(Aform.FindComponent('cb' + Coluna).Name), ['CBCONTA', 'CBTIPO']) of
                0:;
                1:;
              End;
            end
            Else Begin
              TcxTextEdit(Aform.FindComponent('edt' + Coluna)).Text := Valor;
            End;
          End;
        15, 16: //BLOB,TEXT
          TcxTextEdit(Aform.FindComponent('edt' + Coluna)).Text := Valor;
        Else Begin
          if (Aform.FindComponent('cb' + Coluna) is TComboBox) Then begin
            TComboBox(Aform.FindComponent('cb' + Coluna)).ItemIndex := Valor.ToInteger;
            TcxTextEdit(Aform.FindComponent('edt' + Coluna)).Text := TComboBox(Aform.FindComponent('cb' + Coluna)).Text;
          end
          Else Begin
            TcxTextEdit(Aform.FindComponent('edt' + Coluna)).Text := Valor;
          End;
        End;
      End;
    except
      TcxTextEdit(Aform.FindComponent('edt' + Coluna)).Text := Valor;
    end;
    FField.Post;
    FField.Next;
  End;
  FField.Refresh;

  procTerminate(AForm);

  if (ReturnQry.FieldByName(FFieldActived).AsInteger = 0)
    OR (ReturnQry.FieldByName(FFieldActived).IsNull) then begin
    //      lbAtivo.Caption := 'Ativo';
    //      lbAtivo.Font.Color := clGreen;
  end
  Else Begin
    //      lbAtivo.Caption := 'Inativo';
    //      lbAtivo.Font.Color := clRed;
  End;
end;

function TProviders.SelecionaSetor(const AId: Integer): String;
begin
  Result := '';
end;

function TProviders.SelecionaTipoDocumento(const AId: Integer): String;
begin
  Result := '';
end;

{$ENDIF}

end.

