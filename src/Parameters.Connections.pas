{ =============================================================================
  Parameters.Connections - adaptador de perfis de conexao (seam do modulo Connections)

  Preenche o seam de DI aberto na FASE 4 (Connections.FromConfig / Onda 4.1):
  IConnection.FromConfig delega num IConnectionConfigureLoader externo; sem loader
  registado lanca EConnectionConfigurationException (codigo 400017). Este
  adaptador E esse loader - le um PERFIL de conexao (BD ou LDAP) do modulo
  Parameters (cascata configuravel Database > INI > JSON) e devolve-o como
  TConnectionData ao Connections, sem que o Connections importe Parameters
  (zero dependencia circular, D10).

  Perfil = grupo de parametros identificado por um Titulo (seccao no INI, objeto
  no JSON, valor da coluna 'titulo' na tabela). O solicitante escolhe o perfil
  via IConnection.ConfigFilePath(<perfil>) antes de chamar FromConfig; se vazio,
  usa a seccao default 'databases' (DEFAULT_SECTION_DATABASE_NAME). Um path
  fisico legado (ex.: C:\app\config.ini) e reduzido ao nome-base sem extensao.

  Chaves lidas (snake_case canonico = CONNECTION_CONFIG_KEYS, SSOT do Connections;
  aceita tambem o equivalente camelCase quando difere):
    host . port . username/userName . password . database . schema .
    database_type/databaseType . database_dll/dllBasePath
  O tipo de banco vem como texto e e convertido por TDatabaseTypeClass.FromString
  (reconhece 'PostgreSQL', 'SQLite', ..., 'LDAP' - perfil LDAP = mesmo mapeamento,
  database_type='ldap').

  Greenfield: nao existe antecessor no standalone ParametersORM v1.0.7 (sem sufixo
  Legacy). Depende so de Commons.Types + Connections.Interfaces + Parameters.Interfaces
  (contratos); o registo concreto usa Connections.FromConfig na implementation.
  Gated por USE_PARAMETERS.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  2.0.0
  FileVersion:    1.1.2
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           22/07/2026

  Changelog (file):
  - 1.1.2 (22/07/2026): LoadConfigure le dll_download_url (indice 8 de
    CONNECTION_CONFIG_KEYS, Commons.Consts 1.2.2) para TConnectionData.
    DllDownloadUrl (Commons.Types 1.3.2) - fecha a decisao pendente da Onda 7.0
    do F7 ("URL CDN do DllBootstrap - LE do Parameters"), encontrada em auditoria
    file-a-file/onda-a-onda do F7 (22/07). Distinto do dll_path/dll_name
    revertido em 1.1.1: aqui so se le uma URL (string simples), sem qualquer
    array de resolucao de path/nome por banco - zero sobreposicao com
    Commons.DynamicLibrary.pas. Sem consumidor de auto-download ainda
    (USE_DLL_AUTODOWNLOAD/autoDownloadDlls runtime continua "pendente, nao
    critico" - decisao da Onda 7.0 inalterada); o campo fica disponivel no
    perfil para quando esse consumidor for construido.
  - 1.1.1 (22/07/2026): REVERTIDA a leitura de dll_path/dll_name (indices 8/9)
    e o fallback em DatabaseTypeDllPaths/DatabaseTypeDllNames introduzidos em
    1.1.0 (F8 Onda 8.3, seam 400017) - decisao do owner apos pesquisa confirmar
    que a resolucao de DLL por vendor/plataforma/versao ja esta coberta por
    Commons.DynamicLibrary.pas, sem consumidor real para um override por
    conexao; CONNECTION_CONFIG_KEYS voltou a 8 entradas (Commons.Consts 1.2.1),
    TConnectionData.DllNames removido (Commons.Types 1.3.1). LoadConfigure
    volta a ler so ate ao indice 7 (database_dll/dllBasePath).
  - 1.1.0 (22/07/2026): LoadConfigure le dll_path/dll_name (indices 8/9 de
    CONNECTION_CONFIG_KEYS, F8 Onda 8.3, extensao aditiva do seam 400017) -
    database_dll/dllBasePath mantidos como aliases legados; dll_name parseado
    como CSV (ParseDllNamesCSV) para TConnectionData.DllNames; quando o perfil
    nao traz path/nome, cai em fallback nos arrays SSOT ja existentes
    DatabaseTypeDllPaths/DatabaseTypeDllNames (Commons.Consts) - zero
    duplicacao. Extensao aditiva, sem quebra de consumidores existentes;
    ModuleVersion do modulo Parameters mantido em 2.0.0 (mudanca aditiva
    isolada a este ficheiro, nao ao modulo como um todo).
  - 1.0.0 (17/07/2026): criacao (FASE 7, Onda 7.5) - adaptador de perfis
    TParametersConnectionLoader (perfil Parameters -> TConnectionData; implementa
    IConnectionConfigureLoader; Register/Unregister no seam do Connections).
  ============================================================================= }

unit Parameters.Connections;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_PARAMETERS}

uses
  Commons.Types,          // TConnectionData, TParameter, TDatabaseTypes
  Connections.Interfaces, // IConnectionConfigureLoader (seam de DI)
  Parameters.Interfaces;  // IParameters (fonte configurada, cascata)

type
  { Loader de configuracao do seam Connections.FromConfig, alimentado pelo modulo
    Parameters. Resolve um perfil (Titulo) em TConnectionData. Instancia gerida
    por interface (TInterfacedObject); mantem viva a IParameters que envolve. }
  TParametersConnectionLoader = class(TInterfacedObject, IConnectionConfigureLoader)
  strict private
    FParameters: IParameters;
    function ProfileTitle(const AConfigFilePath: string): string;
    procedure ApplyTitle(const ATitle: string);
    function ReadValue(const AKeyPrimary, AKeyAlt: string; out AFound: Boolean): string;
  public
    constructor Create(const AParameters: IParameters);
    class function New(const AParameters: IParameters): IConnectionConfigureLoader; static;

    { IConnectionConfigureLoader - devolve True se o perfil trouxe alguma chave. }
    function LoadConfigure(const AConfigFilePath: string; out AData: TConnectionData): Boolean;

    { Registo do adaptador no seam do modulo Connections (uma unica vez, na
      inicializacao da fachada/aplicacao). Devolve a instancia registada. }
    class function Register(const AParameters: IParameters): IConnectionConfigureLoader; static;
    class procedure Unregister; static;
  end;

{$ENDIF USE_PARAMETERS}

implementation

{$IFDEF USE_PARAMETERS}

uses
{$IF DEFINED(FPC)}
  SysUtils,
{$ELSE}
  System.SysUtils,
{$ENDIF}
  Commons.Consts,         // CONNECTION_CONFIG_KEYS, DEFAULT_SECTION_DATABASE_NAME
  Connections.FromConfig; // TConnectionConfigureLoaderRegistry (registo global do seam)

{ TParametersConnectionLoader }

constructor TParametersConnectionLoader.Create(const AParameters: IParameters);
begin
  inherited Create;
  FParameters := AParameters;
end;

class function TParametersConnectionLoader.New(const AParameters: IParameters): IConnectionConfigureLoader;
begin
  Result := TParametersConnectionLoader.Create(AParameters);
end;

function TParametersConnectionLoader.ProfileTitle(const AConfigFilePath: string): string;
var
  LExt: string;
begin
  Result := Trim(AConfigFilePath);
  if Result = '' then
  begin
    Result := DEFAULT_SECTION_DATABASE_NAME;
    Exit;
  end;
  { Path fisico legado -> nome-base sem extensao (perfil logico). }
  if (Pos(PathDelim, Result) > 0) or (Pos('/', Result) > 0) then
    Result := ExtractFileName(Result);
  LExt := LowerCase(ExtractFileExt(Result));
  if (LExt = '.ini') or (LExt = '.json') or (LExt = '.db') then
    Result := ChangeFileExt(Result, '');
  if Trim(Result) = '' then
    Result := DEFAULT_SECTION_DATABASE_NAME;
end;

procedure TParametersConnectionLoader.ApplyTitle(const ATitle: string);
begin
  { So configura o Titulo nas fontes ATIVAS (nao force-enable fontes desligadas;
    Section/ObjectName/Title mapeiam o mesmo campo interno de cada fonte). }
  if FParameters.HasSource(psDatabase) then
    FParameters.Database.Title(ATitle);
  if FParameters.HasSource(psInifiles) then
    FParameters.IniFile.Title(ATitle);
  if FParameters.HasSource(psJsonObject) then
    FParameters.JsonObject.Title(ATitle);
end;

function TParametersConnectionLoader.ReadValue(const AKeyPrimary, AKeyAlt: string;
  out AFound: Boolean): string;
var
  LParam: TParameter;
begin
  Result := '';
  AFound := False;
  LParam := FParameters.Select(AKeyPrimary);
  if (LParam = nil) and (AKeyAlt <> '') and not SameText(AKeyAlt, AKeyPrimary) then
    LParam := FParameters.Select(AKeyAlt);
  if LParam <> nil then
  try
    Result := LParam.Value;
    AFound := True;
  finally
    LParam.Free;
  end;
end;

function TParametersConnectionLoader.LoadConfigure(const AConfigFilePath: string;
  out AData: TConnectionData): Boolean;
var
  LTitle, LRaw: string;
  LFound, LAny: Boolean;
  LPort: Integer;
begin
  { Inicializa o registo (out) por completo - campos de valor e geridos. }
  AData.Engine         := teNone;
  AData.DatabaseType   := dtNone;
  AData.Host           := '';
  AData.Port           := 0;
  AData.Username       := '';
  AData.Password       := '';
  AData.Database       := '';
  AData.Schema         := '';
  AData.ServerName     := '';
  AData.ConfigFilePath := AConfigFilePath;
  AData.DllBasePath    := '';
  AData.DllDownloadUrl := '';

  LTitle := ProfileTitle(AConfigFilePath);
  ApplyTitle(LTitle);
  LAny := False;

  { CONNECTION_CONFIG_KEYS (SSOT): 0=host 1=port 2=username 3=password
    4=database 5=schema 6=database_type 7=database_dll 8=dll_download_url. }
  AData.Host := ReadValue(CONNECTION_CONFIG_KEYS[0], '', LFound);
  if LFound then LAny := True;

  LRaw := ReadValue(CONNECTION_CONFIG_KEYS[1], '', LFound);
  if LFound then
  begin
    LAny := True;
    if TryStrToInt(Trim(LRaw), LPort) then
      AData.Port := LPort;
  end;

  AData.Username := ReadValue(CONNECTION_CONFIG_KEYS[2], 'userName', LFound);
  if LFound then LAny := True;

  AData.Password := ReadValue(CONNECTION_CONFIG_KEYS[3], '', LFound);
  if LFound then LAny := True;

  AData.Database := ReadValue(CONNECTION_CONFIG_KEYS[4], '', LFound);
  if LFound then LAny := True;

  AData.Schema := ReadValue(CONNECTION_CONFIG_KEYS[5], '', LFound);
  if LFound then LAny := True;

  LRaw := ReadValue(CONNECTION_CONFIG_KEYS[6], 'databaseType', LFound);
  if LFound then
  begin
    LAny := True;
    AData.DatabaseType := TDatabaseTypeClass.FromString(Trim(LRaw));
  end;

  AData.DllBasePath := ReadValue(CONNECTION_CONFIG_KEYS[7], 'dllBasePath', LFound);
  if LFound then LAny := True;

  { URL CDN do Commons.DllBootstrap - override opcional por perfil (Onda 7.0 do F7,
    decisao "LE do Parameters"; mecanica de download continua so no DllBootstrap). }
  AData.DllDownloadUrl := ReadValue(CONNECTION_CONFIG_KEYS[8], 'dllDownloadUrl', LFound);
  if LFound then LAny := True;

  { ServerName/ENG do SQL Anywhere (F5 Onda 10) - snake_case + camelCase. }
  AData.ServerName := ReadValue('server_name', 'serverName', LFound);
  if LFound then LAny := True;

  Result := LAny;
end;

class function TParametersConnectionLoader.Register(const AParameters: IParameters): IConnectionConfigureLoader;
begin
  Result := New(AParameters);
  TConnectionConfigureLoaderRegistry.Register(Result);
end;

class procedure TParametersConnectionLoader.Unregister;
begin
  TConnectionConfigureLoaderRegistry.Unregister;
end;

{$ENDIF USE_PARAMETERS}

end.
