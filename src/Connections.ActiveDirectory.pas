{ =============================================================================
  Connections.ActiveDirectory - Adapter IConnection para LDAP/ActiveDirectory

  TConnectionsActiveDirectory implementa IConnection delegando ao núcleo do módulo
  ActiveDirectory (TActiveDirectory builder + TActiveDirectoryService/Synapse
  patched). Com isso, conexões LDAP seguem a MESMA metodologia dos bancos
  (fluente, FromConfig, Connect/IsConnected) e entram no PoolConnections
  sem nenhuma alteração no pool.

  Semântica (ver também Connections.Interfaces):
    - Database = BaseDN · Schema = BaseAuth · DatabaseType = dtLDAP · Engine = teNone
    - Connect: socket (Login) + Bind (AuthenticateUser se Username contém '=';
      senão Authenticate — busca DN e binda)
    - ExecuteQuery(AFilter): busca com filtro RFC 4515 sob BaseDN; devolve
      TDataSet em memória com coluna 'dn' (uma linha por entrada encontrada)
    - ExecuteScalar(AFilter): contagem de entradas do filtro
    - ExecuteCommand: NÃO suportado — escrita LDAP é responsabilidade da API
      tipada IActiveDirectoryService (SetAttributeValue/AddObject/...)
    - Transações: no-op (LDAP não tem transações); InTransaction = False
    - Metadados SQL (GetTableNames etc.): arrays vazios (sem equivalente LDAP)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.23
  FileVersion:    1.0.1
  Author:         Claiton de Souza Linhares
  Date:           22/07/2026

  Changelog (file):
  - 1.0.1 (22/07/2026): implementado DllDownloadUrl(AValue)/DllDownloadUrl
    (IConnection ganhou o método na auditoria F7, Onda 7.0) — no-op semântico
    (sem significado em LDAP, Synapse é source-only), mesmo padrão de DllBasePath.
  - 1.0.0 (06/07/2026): absorvido de ProvidersORM v2.3.0 (Onda 4.2) — unit de
    UTILIZAÇÃO do kernel ActiveDirectory (reaproveitamento por uses, ZERO cópia de
    lógica; Modulos/ActiveDirectory intacto). Renomes: TLdapConnection→
    TConnectionsActiveDirectory, ILdapConnection→IConnectionsActiveDirectory (em
    Connections.Interfaces); ELdapConnectionError→EConnectionException (Exceptions.Base);
    ActiveDirectory.Types→Commons.ActiveDirectory.Types.
  - (origem v2.3.0) 1.0.0 (02/07/2026): adapter IConnection sobre TActiveDirectory
    + TActiveDirectoryService; poolável; dataset TFDMemTable/TBufDataset.
  ============================================================================= }

unit Connections.ActiveDirectory;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_ACTIVEDIRECTORY}

uses
{$IF DEFINED(FPC)}
  SysUtils, Classes, Variants, DB,
{$ELSE}
  System.SysUtils, System.Classes, System.Variants, Data.DB,
{$ENDIF}
  Commons.Types,
  Connections.Interfaces,
  ActiveDirectory.Main.Interfaces;

type
  TConnectionsActiveDirectory = class(TInterfacedObject, IConnection, IConnectionsActiveDirectory)
  strict private
    FHost           : string;
    FPort           : Integer;
    FUsername       : string;
    FPassword       : string;
    FBaseDN         : string;   // IConnection.Database
    FBaseAuth       : string;   // IConnection.Schema
    FConfigFilePath : string;
    FDllBasePath    : string;
    FDllDownloadUrl : string;
    FConnected      : Boolean;
    FBuilder        : IActiveDirectoryConnection;
    FService        : IActiveDirectoryService;
    function EnsureBuilder: IActiveDirectoryConnection;
    procedure ApplyParams(var AFilter: string; const AParams: array of Variant);
  public
    constructor Create;
    destructor Destroy; override;

    { IConnection — configuração fluente }
    function Engine(const AValue: TDatabaseEngine): IConnection; overload;
    function Engine: TDatabaseEngine; overload;
    function DatabaseType(const AValue: TDatabaseTypes): IConnection; overload;
    function DatabaseType(const AValue: string): IConnection; overload;
    function DatabaseType: TDatabaseTypes; overload;
    function Host(const AValue: string): IConnection; overload;
    function Host: string; overload;
    function Port(const AValue: Integer): IConnection; overload;
    function Port: Integer; overload;
    function Username(const AValue: string): IConnection; overload;
    function Username: string; overload;
    function Password(const AValue: string): IConnection; overload;
    function Password: string; overload;
    function Database(const AValue: string): IConnection; overload;
    function Database: string; overload;
    function Schema(const AValue: string): IConnection; overload;
    function Schema: string; overload;
    function ConfigFilePath(const AValue: string): IConnection; overload;
    function ConfigFilePath: string; overload;
    function DllBasePath(const AValue: string): IConnection; overload;
    function DllBasePath: string; overload;
    function AutoDownloadDlls(const AValue: Boolean): IConnection; overload;
    function AutoDownloadDlls: Boolean; overload;
    function DllDownloadUrl(const AValue: string): IConnection; overload;
    function DllDownloadUrl: string; overload;
    function FirebirdVersion(const AValue: TFirebirdVersion): IConnection; overload;
    function FirebirdVersion(const AValue: string): IConnection; overload;
    function FirebirdVersion: TFirebirdVersion; overload;
    function ServerName(const AValue: string): IConnection; overload;
    function ServerName: string; overload;
    function SQLAnywhereDriver(const AValue: string): IConnection; overload;
    function SQLAnywhereDriver: string; overload;
    function IsRequiredDllFound: Boolean;

    { IConnection — carregamento de configuração }
    function FromIniFile(const AFilePath, ASection: string): IConnection;
    function FromConfig: IConnection;
    function FromJSON(const AJSON: string): IConnection;
{$IFDEF USE_ATTRIBUTES}
    function FromClass(const AClass: TClass): IConnection;
{$ENDIF}

    { IConnection — conexão }
    function Connect: IConnection;
    function Disconnect: IConnection;
    function IsConnected: Boolean;
    function Ping: Boolean;

    { IConnection — execução (ASQL = filtro LDAP RFC 4515) }
    function ExecuteQuery(const ASQL: string): TDataSet; overload;
    function ExecuteCommand(const ASQL: string): Integer; overload;
    function ExecuteScalar(const ASQL: string): Variant; overload;
    function ExecuteQuery(const ASQL: string;
      const AParams: array of Variant): TDataSet; overload;
    function ExecuteCommand(const ASQL: string;
      const AParams: array of Variant): Integer; overload;
    function ExecuteScalar(const ASQL: string;
      const AParams: array of Variant): Variant; overload;

    { IConnection — transações (no-op em LDAP) }
    function BeginTransaction: IConnection;
    function Commit: IConnection;
    function Rollback: IConnection;
    function InTransaction: Boolean;
    function LockWait(const AValue: Boolean): IConnection; overload; // F5-FU.3 (no-op LDAP)
    function LockWait: Boolean; overload;

    { IConnection — versões }
    function GetServerVersion: string;
    function GetClientVersion: string;

    { IConnection — dados de conexão }
    function GetConnectionData: TConnectionData;

    { IConnection — metadados (sem equivalente LDAP; vazios) }
    function GetTableNames(const ASchema: string = ''): TStringArray;
    function GetDatabaseNames: TStringArray;
    function GetSchemaNames(const ADatabase: string = ''): TStringArray;
    function GetColumnNames(const ATableName: string; const ASchema: string = ''): TStringArray;
    function GetTableStructure(const ATableName: string; const ASchema: string = ''): TArray<TDatabaseFields>;

    { IConnectionsActiveDirectory }
    function Service: IActiveDirectoryService;
    function Builder: IActiveDirectoryConnection;

    class function New: IConnectionsActiveDirectory;
  end;

{$ENDIF}

implementation

{$IFDEF USE_ACTIVEDIRECTORY}

uses
{$IF DEFINED(FPC)}
  IniFiles, BufDataset, fpjson, jsonparser,
{$ELSE}
  System.IniFiles, System.JSON,
  FireDAC.Comp.Client,   // TFDMemTable (dataset em memória neutro de engine SQL)
{$ENDIF}
  Exceptions.Base,                 // EConnectionException (reaproveitada, Onda 4.2)
  Commons.ActiveDirectory.Types,   // TActiveDirectoryConfig
  ActiveDirectory.Main,      // TActiveDirectory (builder)
  ActiveDirectory.Service;   // TActiveDirectoryService.New(TActiveDirectoryConfig)

const
  LDAP_DEFAULT_PORT = 389;

{ TConnectionsActiveDirectory }

constructor TConnectionsActiveDirectory.Create;
begin
  inherited Create;
  FPort := LDAP_DEFAULT_PORT;
  FConnected := False;
end;

destructor TConnectionsActiveDirectory.Destroy;
begin
  if FConnected and (FService <> nil) then
    FService.Disconnect;
  FService := nil;
  FBuilder := nil;
  inherited;
end;

class function TConnectionsActiveDirectory.New: IConnectionsActiveDirectory;
begin
  Result := TConnectionsActiveDirectory.Create;
end;

function TConnectionsActiveDirectory.EnsureBuilder: IActiveDirectoryConnection;
begin
  if FBuilder = nil then
    FBuilder := TActiveDirectory.New;
  Result := FBuilder;
end;

{ --- configuração fluente --- }

function TConnectionsActiveDirectory.Engine(const AValue: TDatabaseEngine): IConnection;
begin
  // Engine não se aplica a LDAP (sempre teNone) — aceito e ignorado por fluência.
  Result := Self;
end;

function TConnectionsActiveDirectory.Engine: TDatabaseEngine;
begin
  Result := teNone;
end;

function TConnectionsActiveDirectory.DatabaseType(const AValue: TDatabaseTypes): IConnection;
begin
  if AValue <> dtLDAP then
    raise EConnectionException.Create('TConnectionsActiveDirectory: DatabaseType é fixo em dtLDAP');
  Result := Self;
end;

function TConnectionsActiveDirectory.DatabaseType(const AValue: string): IConnection;
begin
  if not SameText(AValue, 'LDAP') then
    raise EConnectionException.Create('TConnectionsActiveDirectory: DatabaseType é fixo em LDAP');
  Result := Self;
end;

function TConnectionsActiveDirectory.DatabaseType: TDatabaseTypes;
begin
  Result := dtLDAP;
end;

function TConnectionsActiveDirectory.Host(const AValue: string): IConnection;
begin
  FHost := AValue;
  Result := Self;
end;

function TConnectionsActiveDirectory.Host: string;
begin
  Result := FHost;
end;

function TConnectionsActiveDirectory.Port(const AValue: Integer): IConnection;
begin
  FPort := AValue;
  Result := Self;
end;

function TConnectionsActiveDirectory.Port: Integer;
begin
  Result := FPort;
end;

function TConnectionsActiveDirectory.Username(const AValue: string): IConnection;
begin
  FUsername := AValue;
  Result := Self;
end;

function TConnectionsActiveDirectory.Username: string;
begin
  Result := FUsername;
end;

function TConnectionsActiveDirectory.Password(const AValue: string): IConnection;
begin
  FPassword := AValue;
  Result := Self;
end;

function TConnectionsActiveDirectory.Password: string;
begin
  Result := FPassword;
end;

function TConnectionsActiveDirectory.Database(const AValue: string): IConnection;
begin
  FBaseDN := AValue;
  Result := Self;
end;

function TConnectionsActiveDirectory.Database: string;
begin
  Result := FBaseDN;
end;

function TConnectionsActiveDirectory.Schema(const AValue: string): IConnection;
begin
  FBaseAuth := AValue;
  Result := Self;
end;

function TConnectionsActiveDirectory.Schema: string;
begin
  Result := FBaseAuth;
end;

function TConnectionsActiveDirectory.ConfigFilePath(const AValue: string): IConnection;
begin
  FConfigFilePath := AValue;
  Result := Self;
end;

function TConnectionsActiveDirectory.ConfigFilePath: string;
begin
  Result := FConfigFilePath;
end;

function TConnectionsActiveDirectory.DllBasePath(const AValue: string): IConnection;
begin
  FDllBasePath := AValue;  // sem significado em LDAP (Synapse é source-only)
  Result := Self;
end;

function TConnectionsActiveDirectory.DllBasePath: string;
begin
  Result := FDllBasePath;
end;

function TConnectionsActiveDirectory.AutoDownloadDlls(const AValue: Boolean): IConnection;
begin
  Result := Self;  // no-op: LDAP nao usa DLL cliente (Synapse source-only)
end;

function TConnectionsActiveDirectory.AutoDownloadDlls: Boolean;
begin
  Result := False;
end;

function TConnectionsActiveDirectory.DllDownloadUrl(const AValue: string): IConnection;
begin
  FDllDownloadUrl := AValue;  // sem significado em LDAP (Synapse é source-only)
  Result := Self;
end;

function TConnectionsActiveDirectory.DllDownloadUrl: string;
begin
  Result := FDllDownloadUrl;
end;

function TConnectionsActiveDirectory.FirebirdVersion(const AValue: TFirebirdVersion): IConnection;
begin
  Result := Self;  // no-op: LDAP não usa cliente Firebird
end;

function TConnectionsActiveDirectory.FirebirdVersion(const AValue: string): IConnection;
begin
  Result := Self;  // no-op
end;

function TConnectionsActiveDirectory.FirebirdVersion: TFirebirdVersion;
begin
  Result := fb50;  // default; irrelevante para LDAP
end;

function TConnectionsActiveDirectory.ServerName(const AValue: string): IConnection;
begin
  Result := Self;  // no-op: LDAP não usa ENG do SQL Anywhere
end;

function TConnectionsActiveDirectory.ServerName: string;
begin
  Result := '';  // irrelevante para LDAP
end;

function TConnectionsActiveDirectory.SQLAnywhereDriver(const AValue: string): IConnection;
begin
  Result := Self;  // no-op: LDAP nao usa SQL Anywhere
end;

function TConnectionsActiveDirectory.SQLAnywhereDriver: string;
begin
  Result := '';  // irrelevante para LDAP
end;

function TConnectionsActiveDirectory.IsRequiredDllFound: Boolean;
begin
  Result := True;  // LDAP puro via Synapse não exige DLL de cliente (SSL opcional via OpenSSL)
end;

{ --- carregamento de configuração --- }

function TConnectionsActiveDirectory.FromIniFile(const AFilePath, ASection: string): IConnection;
var
  LIni: TIniFile;
begin
  LIni := TIniFile.Create(AFilePath);
  try
    FHost     := LIni.ReadString(ASection, 'host', FHost);
    FPort     := LIni.ReadInteger(ASection, 'port', FPort);
    FUsername := LIni.ReadString(ASection, 'username', FUsername);
    FPassword := LIni.ReadString(ASection, 'password', FPassword);
    FBaseDN   := LIni.ReadString(ASection, 'database',
                 LIni.ReadString(ASection, 'basedn', FBaseDN));
    FBaseAuth := LIni.ReadString(ASection, 'schema',
                 LIni.ReadString(ASection, 'baseauth', FBaseAuth));
    FConfigFilePath := AFilePath;
  finally
    LIni.Free;
  end;
  Result := Self;
end;

function TConnectionsActiveDirectory.FromConfig: IConnection;
var
  LPath: string;
begin
  // Mesma metodologia dos bancos: config.ini local, seção LDAP.
  LPath := FConfigFilePath;
  if LPath = '' then
    LPath := 'Data' + PathDelim + 'config.ini';
  Result := FromIniFile(LPath, 'LDAP');
end;

function TConnectionsActiveDirectory.FromJSON(const AJSON: string): IConnection;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
begin
  LData := GetJSON(AJSON);
  try
    if LData is TJSONObject then
    begin
      LObj := TJSONObject(LData);
      FHost     := LObj.Get('host', FHost);
      FPort     := LObj.Get('port', FPort);
      FUsername := LObj.Get('username', FUsername);
      FPassword := LObj.Get('password', FPassword);
      FBaseDN   := LObj.Get('database', LObj.Get('basedn', FBaseDN));
      FBaseAuth := LObj.Get('schema', LObj.Get('baseauth', FBaseAuth));
    end;
  finally
    LData.Free;
  end;
  Result := Self;
end;
{$ELSE}
var
  LObj: TJSONObject;
  LVal: TJSONValue;
  function ReadStr(const AName, ADefault: string): string;
  begin
    LVal := LObj.GetValue(AName);
    if LVal <> nil then
      Result := LVal.Value
    else
      Result := ADefault;
  end;
begin
  LObj := TJSONObject.ParseJSONValue(AJSON) as TJSONObject;
  if LObj = nil then
    raise EConnectionException.Create('TConnectionsActiveDirectory.FromJSON: JSON inválido');
  try
    FHost     := ReadStr('host', FHost);
    FPort     := StrToIntDef(ReadStr('port', IntToStr(FPort)), FPort);
    FUsername := ReadStr('username', FUsername);
    FPassword := ReadStr('password', FPassword);
    FBaseDN   := ReadStr('database', ReadStr('basedn', FBaseDN));
    FBaseAuth := ReadStr('schema', ReadStr('baseauth', FBaseAuth));
  finally
    LObj.Free;
  end;
  Result := Self;
end;
{$ENDIF}

{$IFDEF USE_ATTRIBUTES}
function TConnectionsActiveDirectory.FromClass(const AClass: TClass): IConnection;
begin
  raise EConnectionException.Create(
    'TConnectionsActiveDirectory.FromClass não é suportado — mapeamento por atributos LDAP é do módulo ActiveDirectory (TActiveDirectoryMapper<T>)');
end;
{$ENDIF}

{ --- conexão --- }

function TConnectionsActiveDirectory.Connect: IConnection;
var
  LCfg: TActiveDirectoryConfig;
  LOk: Boolean;
begin
  if not FConnected then
  begin
    LCfg := EnsureBuilder
      .Host(FHost)
      .Port(FPort)
      .Username(FUsername)
      .Password(FPassword)
      .BaseDN(FBaseDN)
      .BaseAuth(FBaseAuth)
      .GetConfig;
    FService := TActiveDirectoryService.New(LCfg);
    if not FService.Connect then
      raise EConnectionException.CreateFmt(
        'TConnectionsActiveDirectory: falha ao conectar em %s:%d — %s',
        [FHost, FPort, FService.GetConnectionStatus]);
    if FUsername <> '' then
    begin
      // DN completo → Bind direto; senão busca o DN nas SearchOUs e binda.
      if Pos('=', FUsername) > 0 then
        LOk := FService.AuthenticateUser(FUsername, FPassword)
      else
        LOk := FService.Authenticate(FUsername, FPassword);
      if not LOk then
        raise EConnectionException.CreateFmt(
          'TConnectionsActiveDirectory: Bind falhou para "%s" — %s',
          [FUsername, FService.GetConnectionStatus]);
    end;
    FConnected := True;
  end;
  Result := Self;
end;

function TConnectionsActiveDirectory.Disconnect: IConnection;
begin
  if FService <> nil then
    FService.Disconnect;
  FConnected := False;
  Result := Self;
end;

function TConnectionsActiveDirectory.IsConnected: Boolean;
begin
  Result := FConnected and (FService <> nil);
end;

function TConnectionsActiveDirectory.Ping: Boolean;
begin
  Result := IsConnected;
end;

{ --- execução --- }

procedure TConnectionsActiveDirectory.ApplyParams(var AFilter: string; const AParams: array of Variant);
var
  i: Integer;
begin
  for i := Low(AParams) to High(AParams) do
    AFilter := StringReplace(AFilter, ':param' + IntToStr(i),
      VarToStr(AParams[i]), [rfReplaceAll, rfIgnoreCase]);
end;

function TConnectionsActiveDirectory.ExecuteQuery(const ASQL: string): TDataSet;
var
  LList: TStringList;
  LDS: {$IF DEFINED(FPC)}TBufDataset{$ELSE}TFDMemTable{$ENDIF};
  i: Integer;
begin
  if not IsConnected then
    raise EConnectionException.Create('TConnectionsActiveDirectory.ExecuteQuery: não conectado');
  LDS := {$IF DEFINED(FPC)}TBufDataset{$ELSE}TFDMemTable{$ENDIF}.Create(nil);
  try
    LDS.FieldDefs.Add('dn', ftWideString, 512);
    LDS.CreateDataSet;
    LList := FService.SearchWithCustomFilter(ASQL, FBaseDN);
    try
      if LList <> nil then
        for i := 0 to LList.Count - 1 do
        begin
          LDS.Append;
          LDS.FieldByName('dn').AsString := LList[i];
          LDS.Post;
        end;
    finally
      LList.Free;
    end;
    LDS.First;
    Result := LDS;
  except
    LDS.Free;
    raise;
  end;
end;

function TConnectionsActiveDirectory.ExecuteCommand(const ASQL: string): Integer;
begin
  raise EConnectionException.Create(
    'TConnectionsActiveDirectory.ExecuteCommand não é suportado — operações de escrita LDAP ' +
    'usam a API tipada IActiveDirectoryService (Service.SetAttributeValue/AddObject/...)');
end;

function TConnectionsActiveDirectory.ExecuteScalar(const ASQL: string): Variant;
var
  LList: TStringList;
begin
  if not IsConnected then
    raise EConnectionException.Create('TConnectionsActiveDirectory.ExecuteScalar: não conectado');
  LList := FService.SearchWithCustomFilter(ASQL, FBaseDN);
  try
    if LList <> nil then
      Result := LList.Count
    else
      Result := 0;
  finally
    LList.Free;
  end;
end;

function TConnectionsActiveDirectory.ExecuteQuery(const ASQL: string;
  const AParams: array of Variant): TDataSet;
var
  LFilter: string;
begin
  LFilter := ASQL;
  ApplyParams(LFilter, AParams);
  Result := ExecuteQuery(LFilter);
end;

function TConnectionsActiveDirectory.ExecuteCommand(const ASQL: string;
  const AParams: array of Variant): Integer;
begin
  Result := ExecuteCommand(ASQL);  // sempre levanta EConnectionException
end;

function TConnectionsActiveDirectory.ExecuteScalar(const ASQL: string;
  const AParams: array of Variant): Variant;
var
  LFilter: string;
begin
  LFilter := ASQL;
  ApplyParams(LFilter, AParams);
  Result := ExecuteScalar(LFilter);
end;

{ --- transações (no-op em LDAP) --- }

function TConnectionsActiveDirectory.BeginTransaction: IConnection;
begin
  Result := Self;  // LDAP não tem transações — no-op documentado
end;

function TConnectionsActiveDirectory.Commit: IConnection;
begin
  Result := Self;
end;

function TConnectionsActiveDirectory.Rollback: IConnection;
begin
  Result := Self;
end;

function TConnectionsActiveDirectory.InTransaction: Boolean;
begin
  Result := False;
end;

function TConnectionsActiveDirectory.LockWait(const AValue: Boolean): IConnection;
begin
  Result := Self;  // LDAP não tem transações/locks — no-op documentado (F5-FU.3)
end;

function TConnectionsActiveDirectory.LockWait: Boolean;
begin
  Result := True;  // WAIT (default) — irrelevante em LDAP
end;

{ --- versões / dados --- }

function TConnectionsActiveDirectory.GetServerVersion: string;
begin
  if FService <> nil then
    Result := FService.GetServerInfo
  else
    Result := Format('LDAP %s:%d (desconectado)', [FHost, FPort]);
end;

function TConnectionsActiveDirectory.GetClientVersion: string;
begin
  Result := 'Synapse LDAP (vendored ActiveDirectoryORM)';
end;

function TConnectionsActiveDirectory.GetConnectionData: TConnectionData;
begin
  Result := Default(TConnectionData);
  Result.Engine       := teNone;
  Result.DatabaseType := dtLDAP;
  Result.Host         := FHost;
  Result.Port         := FPort;
  Result.Username     := FUsername;
  Result.Password     := FPassword;
  Result.Database     := FBaseDN;
  Result.Schema       := FBaseAuth;
  Result.ConfigFilePath := FConfigFilePath;
  Result.DllBasePath  := FDllBasePath;
  Result.DllDownloadUrl := FDllDownloadUrl;
end;

{ --- metadados (sem equivalente LDAP) --- }

function TConnectionsActiveDirectory.GetTableNames(const ASchema: string): TStringArray;
begin
  SetLength(Result, 0);
end;

function TConnectionsActiveDirectory.GetDatabaseNames: TStringArray;
begin
  SetLength(Result, 0);
end;

function TConnectionsActiveDirectory.GetSchemaNames(const ADatabase: string): TStringArray;
begin
  SetLength(Result, 0);
end;

function TConnectionsActiveDirectory.GetColumnNames(const ATableName, ASchema: string): TStringArray;
begin
  SetLength(Result, 0);
end;

function TConnectionsActiveDirectory.GetTableStructure(const ATableName, ASchema: string): TArray<TDatabaseFields>;
begin
  SetLength(Result, 0);
end;

{ --- IConnectionsActiveDirectory --- }

function TConnectionsActiveDirectory.Service: IActiveDirectoryService;
begin
  Result := FService;
end;

function TConnectionsActiveDirectory.Builder: IActiveDirectoryConnection;
begin
  Result := EnsureBuilder;
end;

{$ENDIF}

end.
