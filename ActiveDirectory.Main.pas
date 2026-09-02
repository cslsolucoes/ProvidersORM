{ =============================================================================
  ActiveDirectory.Main - Núcleo LDAP (API principal)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.8.0 (ActiveDirectory absorvido do SSOT v1.7.6)
  FileVersion:    1.8.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           24/04/2026

  Changelog (file):
  - 1.8.0 (06/07/2026): removida a classe factory TActiveDirectoryConfig; GetDefaultConfig
    passou a class function static do record TActiveDirectoryConfig (Commons.ActiveDirectory.Types).
    Rename TLDAPConfig -> TActiveDirectoryConfig.
  - 1.0.0 (07/03/2026): TActiveDirectoryConnection, TActiveDirectory, TActiveDirectoryConfig; conversão do Exemplo para núcleo.
  - 1.1.0 (2026-04-13): Fluentes TlsMode/CAFile/PageSize/UseGlobalCatalog; inicialização dos novos campos de TActiveDirectoryConfig.
  ============================================================================= }

unit ActiveDirectory.Main;

interface

uses
  ActiveDirectory.Main.Interfaces,
  Commons.ActiveDirectory.Types,
  Commons.ActiveDirectory.Consts,
  Exceptions.ActiveDirectory,
{$IFDEF FPC}
  SysUtils, Classes, fpjson;
{$ELSE}
  System.SysUtils, System.Classes, System.JSON;
{$ENDIF}

{$IFDEF FPC}
type
  // cross-compiler: base JSON value type (Delphi = System.JSON.TJSONValue; FPC = fpjson.TJSONData)
  TJSONValue = fpjson.TJSONData;
{$ENDIF}

type
  TActiveDirectoryConnection = class(TInterfacedObject, IActiveDirectoryConnection)
  private
    FConfig: TActiveDirectoryConfig;
    procedure ValidatePort(APort: Integer);
    procedure ValidateTimeOut(ATimeOut: Integer);
    procedure ValidateVersion(AVersion: Integer);
    procedure ValidateConfig;
    procedure EnsureSearchOUs;
  public
    constructor Create;
    destructor Destroy; override;
    function Host(const AValue: string): IActiveDirectoryConnection;
    function Port(AValue: Integer): IActiveDirectoryConnection;
    function BaseDN(const AValue: string): IActiveDirectoryConnection;
    function BaseAuth(const AValue: string): IActiveDirectoryConnection;
    function Username(const AValue: string): IActiveDirectoryConnection;
    function Password(const AValue: string): IActiveDirectoryConnection;
    function UseSSL(AValue: Boolean): IActiveDirectoryConnection;
    function TlsMode(AMode: TTlsMode): IActiveDirectoryConnection;
    function CAFile(const APath: string): IActiveDirectoryConnection;
    function PageSize(ASize: Integer): IActiveDirectoryConnection;
    function UseGlobalCatalog(AValue: Boolean): IActiveDirectoryConnection;
    function TimeOut(AValue: Integer): IActiveDirectoryConnection;
    function Version(AValue: Integer): IActiveDirectoryConnection;
    function AddSearchOU(const AOU: string): IActiveDirectoryConnection; overload;
    function AddSearchOU(const AOU: TStringList): IActiveDirectoryConnection; overload;
    function AddSearchOU(const AOU: TJSONArray): IActiveDirectoryConnection; overload;
    function AddSearchOU(const AOU: TJSONObject): IActiveDirectoryConnection; overload;
    function GetConfig: TActiveDirectoryConfig;
    function SetConfig(const AConfig: TJSONObject): IActiveDirectoryConnection; overload;
    function SetConfig(const AConfig: TJSONArray): IActiveDirectoryConnection; overload;
    function SetConfig(const AConfig: TStringList): IActiveDirectoryConnection; overload;
    function SetConfig(const AConfig: TActiveDirectoryConfig): IActiveDirectoryConnection; overload;
  end;

  TActiveDirectory = class
  public
    class function New: IActiveDirectoryConnection;
  end;

implementation

{ TActiveDirectoryConnection }

constructor TActiveDirectoryConnection.Create;
begin
  inherited Create;
  FConfig.Host     := '';
  FConfig.Port     := LDAP_PORT_DEFAULT;
  FConfig.BaseDN   := '';
  FConfig.BaseAuth := '';
  FConfig.Username := '';
  FConfig.Password := '';
  FConfig.UseSSL   := False;
  FConfig.TimeOut  := 30;
  FConfig.Version  := 3;
  FConfig.TlsMode  := tmNone;
  FConfig.CAFile   := '';
  FConfig.PageSize := 1000;
  FConfig.SearchOUs := TStringList.Create;
end;

destructor TActiveDirectoryConnection.Destroy;
begin
  if FConfig.SearchOUs <> nil then
    FConfig.SearchOUs.Free;
  inherited;
end;

procedure TActiveDirectoryConnection.EnsureSearchOUs;
begin
  if FConfig.SearchOUs = nil then
    FConfig.SearchOUs := TStringList.Create;
end;

procedure TActiveDirectoryConnection.ValidatePort(APort: Integer);
begin
  if (APort < 1) or (APort > 65535) then
    raise EADValidationException.Create('Porta LDAP inválida: ' + IntToStr(APort) + '. Use 1-65535.', ERR_LDAP_VALIDATION);
end;

procedure TActiveDirectoryConnection.ValidateTimeOut(ATimeOut: Integer);
begin
  if ATimeOut < 0 then
    raise EADValidationException.Create('TimeOut não pode ser negativo.', ERR_LDAP_VALIDATION);
end;

procedure TActiveDirectoryConnection.ValidateVersion(AVersion: Integer);
begin
  if (AVersion <> 2) and (AVersion <> 3) then
    raise EADValidationException.Create('Versão LDAP deve ser 2 ou 3.', ERR_LDAP_VALIDATION);
end;

procedure TActiveDirectoryConnection.ValidateConfig;
begin
  if Trim(FConfig.Host) = '' then
    raise EADConfigurationException.Create('Host não pode ser vazio.', ERR_LDAP_CONFIGURATION);
  ValidatePort(FConfig.Port);
  ValidateTimeOut(FConfig.TimeOut);
  ValidateVersion(FConfig.Version);
end;

function TActiveDirectoryConnection.Host(const AValue: string): IActiveDirectoryConnection;
begin
  FConfig.Host := AValue;
  Result := Self;
end;

function TActiveDirectoryConnection.Port(AValue: Integer): IActiveDirectoryConnection;
begin
  ValidatePort(AValue);
  FConfig.Port := AValue;
  Result := Self;
end;

function TActiveDirectoryConnection.BaseDN(const AValue: string): IActiveDirectoryConnection;
begin
  FConfig.BaseDN := AValue;
  Result := Self;
end;

function TActiveDirectoryConnection.BaseAuth(const AValue: string): IActiveDirectoryConnection;
begin
  FConfig.BaseAuth := AValue;
  Result := Self;
end;

function TActiveDirectoryConnection.Username(const AValue: string): IActiveDirectoryConnection;
begin
  FConfig.Username := AValue;
  Result := Self;
end;

function TActiveDirectoryConnection.Password(const AValue: string): IActiveDirectoryConnection;
begin
  FConfig.Password := AValue;
  Result := Self;
end;

function TActiveDirectoryConnection.UseSSL(AValue: Boolean): IActiveDirectoryConnection;
begin
  FConfig.UseSSL := AValue;
  if AValue then
  begin
    { retrocompatibilidade: ativa tmLDAPSNoCertCheck e ajusta porta }
    if FConfig.TlsMode = tmNone then
      FConfig.TlsMode := tmLDAPSNoCertCheck;
    if FConfig.Port = LDAP_PORT_DEFAULT then
      FConfig.Port := LDAPS_PORT_DEFAULT;
  end
  else
  begin
    FConfig.TlsMode := tmNone;
    if FConfig.Port = LDAPS_PORT_DEFAULT then
      FConfig.Port := LDAP_PORT_DEFAULT;
  end;
  Result := Self;
end;

function TActiveDirectoryConnection.TlsMode(AMode: TTlsMode): IActiveDirectoryConnection;
begin
  FConfig.TlsMode := AMode;
  { Ajustar UseSSL para retrocompatibilidade e porta padrão }
  case AMode of
    tmNone:
    begin
      FConfig.UseSSL := False;
      if (FConfig.Port = LDAPS_PORT_DEFAULT) or
         (FConfig.Port = LDAPS_GC_PORT_DEFAULT) then
        FConfig.Port := LDAP_PORT_DEFAULT;
    end;
    tmStartTLS:
    begin
      FConfig.UseSSL := True;
      if (FConfig.Port = LDAPS_PORT_DEFAULT) or
         (FConfig.Port = LDAPS_GC_PORT_DEFAULT) then
        FConfig.Port := LDAP_PORT_DEFAULT;
    end;
    tmLDAPSNoCertCheck, tmLDAPSWithCA:
    begin
      FConfig.UseSSL := True;
      if FConfig.Port = LDAP_PORT_DEFAULT then
        FConfig.Port := LDAPS_PORT_DEFAULT;
    end;
  end;
  Result := Self;
end;

function TActiveDirectoryConnection.CAFile(const APath: string): IActiveDirectoryConnection;
begin
  FConfig.CAFile := APath;
  Result := Self;
end;

function TActiveDirectoryConnection.PageSize(ASize: Integer): IActiveDirectoryConnection;
begin
  if ASize < 1 then
    raise EADValidationException.Create(
      'PageSize deve ser >= 1.', ERR_LDAP_VALIDATION);
  FConfig.PageSize := ASize;
  Result := Self;
end;

function TActiveDirectoryConnection.UseGlobalCatalog(AValue: Boolean): IActiveDirectoryConnection;
begin
  if AValue then
  begin
    { Porta GC conforme modo TLS atual }
    if FConfig.TlsMode in [tmLDAPSNoCertCheck, tmLDAPSWithCA] then
      FConfig.Port := LDAPS_GC_PORT_DEFAULT
    else
      FConfig.Port := LDAP_GC_PORT_DEFAULT;
  end
  else
  begin
    { Restaura porta padrão conforme TLS }
    if FConfig.TlsMode in [tmLDAPSNoCertCheck, tmLDAPSWithCA] then
      FConfig.Port := LDAPS_PORT_DEFAULT
    else
      FConfig.Port := LDAP_PORT_DEFAULT;
  end;
  Result := Self;
end;

function TActiveDirectoryConnection.TimeOut(AValue: Integer): IActiveDirectoryConnection;
begin
  ValidateTimeOut(AValue);
  FConfig.TimeOut := AValue;
  Result := Self;
end;

function TActiveDirectoryConnection.Version(AValue: Integer): IActiveDirectoryConnection;
begin
  ValidateVersion(AValue);
  FConfig.Version := AValue;
  Result := Self;
end;

function TActiveDirectoryConnection.AddSearchOU(const AOU: string): IActiveDirectoryConnection;
begin
  EnsureSearchOUs;
  if (AOU <> '') and (FConfig.SearchOUs.IndexOf(AOU) < 0) then
    FConfig.SearchOUs.Add(AOU);
  Result := Self;
end;

function TActiveDirectoryConnection.AddSearchOU(const AOU: TStringList): IActiveDirectoryConnection;
var
  I: Integer;
begin
  if AOU = nil then
    raise EADValidationException.Create('TStringList não pode ser nil em AddSearchOU.', ERR_LDAP_VALIDATION);
  EnsureSearchOUs;
  for I := 0 to AOU.Count - 1 do
    AddSearchOU(Trim(AOU[I]));
  Result := Self;
end;

function TActiveDirectoryConnection.AddSearchOU(const AOU: TJSONArray): IActiveDirectoryConnection;
var
  I: Integer;
{$IFDEF FPC}
  LElem: TJSONData;
{$ELSE}
  LVal: TJSONValue;
{$ENDIF}
begin
  if AOU = nil then
    raise EADValidationException.Create('TJSONArray não pode ser nil em AddSearchOU.', ERR_LDAP_VALIDATION);
  EnsureSearchOUs;
  for I := 0 to AOU.Count - 1 do
  begin
{$IFDEF FPC}
    LElem := AOU.Items[I];
    if LElem <> nil then
      AddSearchOU(LElem.AsString);
{$ELSE}
    LVal := AOU.Items[I];
    if (LVal <> nil) and (LVal is TJSONString) then
      AddSearchOU((LVal as TJSONString).Value);
{$ENDIF}
  end;
  Result := Self;
end;

function TActiveDirectoryConnection.AddSearchOU(const AOU: TJSONObject): IActiveDirectoryConnection;
var
  LArr: TJSONArray;
  I: Integer;
{$IFDEF FPC}
  LData: TJSONData;
{$ELSE}
  LVal: TJSONValue;
{$ENDIF}
begin
  if AOU = nil then
    raise EADValidationException.Create('TJSONObject não pode ser nil em AddSearchOU.', ERR_LDAP_VALIDATION);
  EnsureSearchOUs;
  LArr := nil;
{$IFDEF FPC}
  if AOU.Find('SearchOUs', LData) then
    LArr := LData as TJSONArray
  else if AOU.Find('searchOUs', LData) then
    LArr := LData as TJSONArray
  else if AOU.Find('Data', LData) then
    LArr := LData as TJSONArray;
{$ELSE}
  LVal := AOU.GetValue('SearchOUs');
  if LVal = nil then
    LVal := AOU.GetValue('searchOUs');
  if LVal = nil then
    LVal := AOU.GetValue('Data');
  if (LVal <> nil) and (LVal is TJSONArray) then
    LArr := TJSONArray(LVal);
{$ENDIF}
  if LArr <> nil then
    for I := 0 to LArr.Count - 1 do
    begin
{$IFDEF FPC}
      AddSearchOU(LArr.Items[I].AsString);
{$ELSE}
      if (LArr.Items[I] <> nil) and (LArr.Items[I] is TJSONString) then
        AddSearchOU((LArr.Items[I] as TJSONString).Value);
{$ENDIF}
    end;
  Result := Self;
end;

function TActiveDirectoryConnection.GetConfig: TActiveDirectoryConfig;
begin
  ValidateConfig;
  Result := FConfig;
end;

function TActiveDirectoryConnection.SetConfig(const AConfig: TActiveDirectoryConfig): IActiveDirectoryConnection;
begin
  FConfig.Host     := AConfig.Host;
  FConfig.Port     := AConfig.Port;
  FConfig.BaseDN   := AConfig.BaseDN;
  FConfig.BaseAuth := AConfig.BaseAuth;
  FConfig.Username := AConfig.Username;
  FConfig.Password := AConfig.Password;
  FConfig.UseSSL   := AConfig.UseSSL;
  FConfig.TimeOut  := AConfig.TimeOut;
  FConfig.Version  := AConfig.Version;
  FConfig.TlsMode  := AConfig.TlsMode;
  FConfig.CAFile   := AConfig.CAFile;
  FConfig.PageSize := AConfig.PageSize;
  if AConfig.SearchOUs <> nil then
    FConfig.SearchOUs.Assign(AConfig.SearchOUs)
  else
    FConfig.SearchOUs.Clear;
  Result := Self;
end;

function TActiveDirectoryConnection.SetConfig(const AConfig: TStringList): IActiveDirectoryConnection;
var
  I, P: Integer;
  LKey, LVal, LLine: string;
begin
  if AConfig = nil then
    raise EADValidationException.Create('TStringList não pode ser nil em SetConfig.', ERR_LDAP_VALIDATION);
  EnsureSearchOUs;
  FConfig.SearchOUs.Clear;
  for I := 0 to AConfig.Count - 1 do
  begin
    LLine := AConfig[I];
    P := Pos('=', LLine);
    if P > 0 then
    begin
      LKey := Trim(Copy(LLine, 1, P - 1));
      LVal := Trim(Copy(LLine, P + 1, MaxInt));
      if SameText(LKey, 'Host') then FConfig.Host := LVal
      else if SameText(LKey, 'Port') then FConfig.Port := StrToIntDef(LVal, LDAP_PORT_DEFAULT)
      else if SameText(LKey, 'BaseDN') then FConfig.BaseDN := LVal
      else if SameText(LKey, 'BaseAuth') then FConfig.BaseAuth := LVal
      else if SameText(LKey, 'Username') then FConfig.Username := LVal
      else if SameText(LKey, 'Password') then FConfig.Password := LVal
      else if SameText(LKey, 'UseSSL') then FConfig.UseSSL := SameText(LVal, 'True') or SameText(LVal, '1')
      else if SameText(LKey, 'TimeOut') then FConfig.TimeOut := StrToIntDef(LVal, 30)
      else if SameText(LKey, 'Version') then FConfig.Version := StrToIntDef(LVal, 3);
    end
    else if Trim(LLine) <> '' then
      FConfig.SearchOUs.Add(Trim(LLine));
  end;
  Result := Self;
end;

function TActiveDirectoryConnection.SetConfig(const AConfig: TJSONArray): IActiveDirectoryConnection;
var
  I: Integer;
begin
  if AConfig = nil then
    raise EADValidationException.Create('TJSONArray não pode ser nil em SetConfig.', ERR_LDAP_VALIDATION);
  EnsureSearchOUs;
  FConfig.SearchOUs.Clear;
  for I := 0 to AConfig.Count - 1 do
  begin
{$IFDEF FPC}
    FConfig.SearchOUs.Add(AConfig.Items[I].AsString);
{$ELSE}
    if (AConfig.Items[I] <> nil) and (AConfig.Items[I] is TJSONString) then
      FConfig.SearchOUs.Add((AConfig.Items[I] as TJSONString).Value);
{$ENDIF}
  end;
  Result := Self;
end;

function TActiveDirectoryConnection.SetConfig(const AConfig: TJSONObject): IActiveDirectoryConnection;
var
  I: Integer;
  LVal: TJSONValue;
  LArr: TJSONArray;
{$IFDEF FPC}
  LData: TJSONData;
{$ENDIF}
begin
  if AConfig = nil then
    raise EADValidationException.Create('TJSONObject não pode ser nil em SetConfig.', ERR_LDAP_VALIDATION);
{$IFDEF FPC}
  if AConfig.Find('Host', LData) then FConfig.Host := LData.AsString;
  if AConfig.Find('Port', LData) then FConfig.Port := LData.AsInteger;
  if AConfig.Find('BaseDN', LData) then FConfig.BaseDN := LData.AsString;
  if AConfig.Find('BaseAuth', LData) then FConfig.BaseAuth := LData.AsString;
  if AConfig.Find('Username', LData) then FConfig.Username := LData.AsString;
  if AConfig.Find('Password', LData) then FConfig.Password := LData.AsString;
  if AConfig.Find('UseSSL', LData) then FConfig.UseSSL := LData.AsBoolean;
  if AConfig.Find('TimeOut', LData) then FConfig.TimeOut := LData.AsInteger;
  if AConfig.Find('Version', LData) then FConfig.Version := LData.AsInteger;
{$ELSE}
  LVal := AConfig.GetValue('Host'); if (LVal <> nil) and (LVal is TJSONString) then FConfig.Host := (LVal as TJSONString).Value;
  LVal := AConfig.GetValue('Port'); if (LVal <> nil) and (LVal is TJSONNumber) then FConfig.Port := (LVal as TJSONNumber).AsInt;
  LVal := AConfig.GetValue('BaseDN'); if (LVal <> nil) and (LVal is TJSONString) then FConfig.BaseDN := (LVal as TJSONString).Value;
  LVal := AConfig.GetValue('BaseAuth'); if (LVal <> nil) and (LVal is TJSONString) then FConfig.BaseAuth := (LVal as TJSONString).Value;
  LVal := AConfig.GetValue('Username'); if (LVal <> nil) and (LVal is TJSONString) then FConfig.Username := (LVal as TJSONString).Value;
  LVal := AConfig.GetValue('Password'); if (LVal <> nil) and (LVal is TJSONString) then FConfig.Password := (LVal as TJSONString).Value;
  LVal := AConfig.GetValue('UseSSL'); if (LVal <> nil) and (LVal is TJSONBool) then FConfig.UseSSL := (LVal as TJSONBool).AsBoolean;
  LVal := AConfig.GetValue('TimeOut'); if (LVal <> nil) and (LVal is TJSONNumber) then FConfig.TimeOut := (LVal as TJSONNumber).AsInt;
  LVal := AConfig.GetValue('Version'); if (LVal <> nil) and (LVal is TJSONNumber) then FConfig.Version := (LVal as TJSONNumber).AsInt;
{$ENDIF}
  EnsureSearchOUs;
  FConfig.SearchOUs.Clear;
{$IFDEF FPC}
  if AConfig.Find('SearchOUs', LData) then
    LArr := LData as TJSONArray
  else if AConfig.Find('searchOUs', LData) then
    LArr := LData as TJSONArray
  else if AConfig.Find('Data', LData) then
    LArr := LData as TJSONArray
  else
    LArr := nil;
{$ELSE}
  LVal := AConfig.GetValue('SearchOUs'); if LVal = nil then LVal := AConfig.GetValue('searchOUs'); if LVal = nil then LVal := AConfig.GetValue('Data');
  if (LVal <> nil) and (LVal is TJSONArray) then LArr := TJSONArray(LVal) else LArr := nil;
{$ENDIF}
  if LArr <> nil then
    for I := 0 to LArr.Count - 1 do
    begin
{$IFDEF FPC}
      FConfig.SearchOUs.Add(LArr.Items[I].AsString);
{$ELSE}
      if (LArr.Items[I] <> nil) and (LArr.Items[I] is TJSONString) then
        FConfig.SearchOUs.Add((LArr.Items[I] as TJSONString).Value);
{$ENDIF}
    end;
  Result := Self;
end;

{ TActiveDirectory }

class function TActiveDirectory.New: IActiveDirectoryConnection;
begin
  Result := TActiveDirectoryConnection.Create;
end;

end.
