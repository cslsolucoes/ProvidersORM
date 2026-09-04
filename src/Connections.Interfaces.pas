{ =============================================================================
  Connections.Interfaces - TODAS as interfaces do módulo Connections

  Ficheiro central das interfaces do módulo (regra do owner "centralizar as
  interfaces"): IConnection (contrato de conexão, absorvido verbatim de
  ProvidersORM v2.3.0 com paridade 100%) + IConnectionConfigureLoader (seam de DI do
  FromConfig). Sem dependência de Parameters/Attributers/Loggers — usa só
  Commons.Types. Novas interfaces do módulo (ex.: LDAP na Onda 4.2) entram aqui.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.23
  FileVersion:    1.3.1
  Author:         Claiton de Souza Linhares
  Date:           22/07/2026

  Changelog (file):
  - 1.3.1 (22/07/2026): IConnection ganha DllDownloadUrl(AValue)/DllDownloadUrl
    (override opcional do URL de Commons.DllBootstrap; auditoria F7, Onda 7.0).
    Aditivo; default '' preserva o comportamento anterior. Implementado nos 3
    concretizadores (TConnection, TConnectionProxy, TConnectionsActiveDirectory).
  - 1.3.0 (16/07/2026): IConnection ganha ServerName (F5 Onda 10 — SQL Anywhere 17;
    ENG e distinto do Host/IP). Aditivo; default '' preserva o comportamento
    anterior para os outros engines/tipos.
  - 1.2.0 (08/07/2026): IConnection ganha FirebirdVersion (3 overloads) — seleção
    da versão do cliente fbclient.dll por subpasta dll/<plat>/FireBird/2-3-4-5
    (Onda 4.2b). Aditivo; default fb50 preserva o comportamento anterior.
  - 1.1.0 (06/07/2026): centralização das interfaces do módulo (regra do owner) —
    IConnectionConfigureLoader movido de Connections.FromConfig para aqui.
  - 1.0.0 (06/07/2026): absorvido de ProvidersORM v2.3.0 (FileVersion origem
    1.0.5) para src/Modulos/Connections (Onda 4.1). Zero alteração de contrato —
    cabeçalho v3 apenas.
  Changelog (fonte v2.3.0):
  - 1.0.0 (03/02/2026): Versão inicial.
  - 1.0.1 (01/02/2026): IConnection completa - config fluente, Connect, Ping, Execute*, transações (Fase 1).
  - 1.0.2 (26/02/2026): GetSchemaNames(const ADatabase) para listagem de schemas (PostgreSQL, SQL Server).
  - 1.0.3 (26/02/2026): GetColumnNames(ATableName, ASchema) para listagem de colunas (information_schema / PRAGMA / sys.columns).
  - 1.0.4 (26/02/2026): GetTableStructure para gerar DDL de tabela existente; retorno usa TDatabaseFields (Commons.Types).
  - 1.0.5 (03/04/2026): Overloads parametrizados: ExecuteQuery, ExecuteCommand, ExecuteScalar com array of Variant.
  ============================================================================= }

unit Connections.Interfaces;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

uses
{$IF DEFINED(FPC)}
  SysUtils, Classes, Variants, DB,
{$ELSE}
  System.SysUtils, System.Classes, System.Variants, Data.DB,
{$ENDIF}
  Commons.Types
{$IFDEF USE_ACTIVEDIRECTORY}
  , ActiveDirectory.Main.Interfaces   // kernel AD: IActiveDirectoryService/Connection p/ IConnectionsActiveDirectory (Onda 4.2)
{$ENDIF}
  ;

type
  //Interface da conexão com o banco. TPoolConnections mantém um container de IConnection.
  IConnection = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']

    { Configuração fluente }
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
    { Override opcional do URL de download (Commons.DllBootstrap); '' = usa
      Commons.Consts.DEFAULT_DLL_DOWNLOAD_URL. Populado via perfil Parameters
      (dll_download_url/dllDownloadUrl, F7 Onda 7.0) ou setado diretamente. }
    function DllDownloadUrl(const AValue: string): IConnection; overload;
    function DllDownloadUrl: string; overload;
    { Versão do cliente Firebird (fbclient.dll) → subpasta dll/<plat>/FireBird/2-3-4-5.
      Default fb50; usar fb30 p/ servidor Firebird 3.x. Ignorado por outros engines.
      Overload string aceita '2'/'3'/'4'/'5' (ou '2.5'/'3.0'/'4.0'/'5.0'). }
    function FirebirdVersion(const AValue: TFirebirdVersion): IConnection; overload;
    function FirebirdVersion(const AValue: string): IConnection; overload;
    function FirebirdVersion: TFirebirdVersion; overload;
    { ServerName (ENG) do SQL Anywhere — nome LOGICO do servidor, distinto do
      Host/IP (ex.: ENG=srvcontabil, Host=10.0.74.3). Ignorado por outros engines.
      F5 Onda 10. }
    function ServerName(const AValue: string): IConnection; overload;
    function ServerName: string; overload;
    { Vertente SQL Anywhere sob UniDAC: 'native' (dbcapi.dll, default) ou 'odbc'. }
    function SQLAnywhereDriver(const AValue: string): IConnection; overload;
    function SQLAnywhereDriver: string; overload;
    function IsRequiredDllFound: Boolean;

    { Carregamento de configuração }
    function FromIniFile(const AFilePath, ASection: string): IConnection;
    function FromConfig: IConnection;
    function FromJSON(const AJSON: string): IConnection;
{$IFDEF USE_ATTRIBUTES}
    function FromClass(const AClass: TClass): IConnection;
{$ENDIF}

    { Conexão }
    function Connect: IConnection;
    function Disconnect: IConnection;
    function IsConnected: Boolean;
    function Ping: Boolean;

    { Execução }
    function ExecuteQuery(const ASQL: string): TDataSet; overload;
    function ExecuteCommand(const ASQL: string): Integer; overload;
    function ExecuteScalar(const ASQL: string): Variant; overload;

    { Execução parametrizada — :param0, :param1, ... (Zeos usa ? posicional) }
    function ExecuteQuery(const ASQL: string;
      const AParams: array of Variant): TDataSet; overload;
    function ExecuteCommand(const ASQL: string;
      const AParams: array of Variant): Integer; overload;
    function ExecuteScalar(const ASQL: string;
      const AParams: array of Variant): Variant; overload;

    { Transações }
    function BeginTransaction: IConnection;
    function Commit: IConnection;
    function Rollback: IConnection;
    function InTransaction: Boolean;

    { F5-FU.3 - modo de espera por lock (rede de seguranca anti-hang no DDL do
      Firebird). True (DEFAULT) = WAIT: a transacao espera pelo lock (comportamento
      atual, inalterado). False = NO WAIT: no Firebird a transacao aborta de
      imediato ao encontrar um lock (isc_tpb_nowait), e o ExecuteCommand converte
      esse erro em EDatabaseObjectLockedException (410030) em vez de pendurar.
      Fluent. Definir ANTES de Connect (aplicado em ConfigureNativeConnection).
      OPT-IN: sem chamada, o comportamento e 100% o de hoje. }
    function LockWait(const AValue: Boolean): IConnection; overload;
    function LockWait: Boolean; overload;

    { Versões }
    function GetServerVersion: string;
    function GetClientVersion: string;

    { Dados de conexão }
    function GetConnectionData: TConnectionData;

    { Metadados (delegação via ITables). Mantidos aqui para uso interno por TTables. }
    function GetTableNames(const ASchema: string = ''): TStringArray;
    function GetDatabaseNames: TStringArray;
    function GetSchemaNames(const ADatabase: string = ''): TStringArray;
    function GetColumnNames(const ATableName: string; const ASchema: string = ''): TStringArray;
    function GetTableStructure(const ATableName: string; const ASchema: string = ''): TArray<TDatabaseFields>;
  end;

  { Seam de DI para IConnection.FromConfig: implementado externamente (Parameters,
    F7) e registado via TConnectionConfigureLoaderRegistry (unit Connections.FromConfig).
    Devolve True se a fonte concreta (Database/Inifiles/JsonObject, por prioridade
    do loader) encontrou configuração para AConfigFilePath; False = fonte sem dados. }
  IConnectionConfigureLoader = interface
    ['{7A1E2F30-4B5C-4D6E-9F80-1A2B3C4D5E6F}']
    function LoadConfigure(const AConfigFilePath: string;
      out AData: TConnectionData): Boolean;
  end;

{$IFDEF USE_ACTIVEDIRECTORY}
  { Adapter IConnection para ActiveDirectory (utilizador do kernel AD, Onda 4.2).
    Dá a uma conexão LDAP/AD o contrato uniforme de IConnection → poolável como
    qualquer conexão. Implementação em Connections.ActiveDirectory
    (TConnectionsActiveDirectory); reaproveita o kernel do módulo ActiveDirectory
    sem duplicar lógica. }
  IConnectionsActiveDirectory = interface(IConnection)
    ['{B7C8D9E0-F1A2-4B3C-8D4E-5F6A7B8C9D01}']
    { Serviço LDAP subjacente (nil antes de Connect) — API tipada do kernel AD. }
    function Service: IActiveDirectoryService;
    { Builder de configuração LDAP subjacente (TlsMode/CAFile/OUs antes do Connect). }
    function Builder: IActiveDirectoryConnection;
  end;
{$ENDIF}

implementation

end.
