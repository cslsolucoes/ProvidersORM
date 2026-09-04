{ =============================================================================
  Providers.Commons.Consts - Constantes do projeto Providers ORM

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  FileVersion:    1.2.2
  Author:         Claiton de Souza Linhares
  Date:           22/07/2026

  Changelog (file):
  - 1.2.2 (22/07/2026): CONNECTION_CONFIG_KEYS estendido de 8 para 9 entradas
    (+8=dll_download_url). NAO e reintroducao da tentativa revertida em 1.2.1
    (aquela criava um array paralelo de resolucao de path/nome de DLL, que
    duplicava Commons.DynamicLibrary.pas - por isso foi revertida). Esta e
    DIFERENTE: preenche a decisao pendente da Onda 7.0 do F7 ("URL CDN do
    DllBootstrap - LE do Parameters, mecanica fica no DllBootstrap, URL vira
    parametro com fallback") - o valor lido so populariza TConnectionData.
    DllDownloadUrl (Commons.Types 1.3.2); zero logica de resolucao de path
    nova, zero duplicacao de Commons.DynamicLibrary. Sem consumidor de
    auto-download ainda (USE_DLL_AUTODOWNLOAD/autoDownloadDlls runtime
    continua "pendente, nao critico" - decisao inalterada); o campo fica
    disponivel para quando esse consumidor for construido.
  - 1.2.1 (22/07/2026): REVERTIDA a extensao de CONNECTION_CONFIG_KEYS para 10
    entradas (introduzida em 1.2.0, F8 Onda 8.3, seam 400017) - decisao do owner
    apos pesquisa confirmar que a resolucao de DLL por vendor/plataforma/versao
    ja esta coberta por Commons.DynamicLibrary.pas, sem consumidor real para um
    override por conexao (dll_path/dll_name); array volta a 8 entradas (0-7).
  - 1.2.0 (22/07/2026): CONNECTION_CONFIG_KEYS estendido de 8 para 10 entradas
    (F8 Onda 8.3, seam 400017 aditivo) - +8=dll_path +9=dll_name; database_dll
    (indice 7) fica como alias legado de dll_path. Indices 0-7 inalterados.
  - 1.1.1 (16/07/2026): CORRECAO de posicao (owner) - dtSQLAnywhere reposicionado
    ANTES de dtODBC/dtLDAP no enum (que ficam sempre por ultimo); os 5 arrays
    posicionais (Names/Inverse/IsFileBased/HasSchema/Config) realinhados na
    coluna 8 (era a 10, ultima) - ODBC/LDAP voltam a ser as colunas 9/10.
  - 1.1.0 (16/07/2026): TDatabaseTypeNames/Inverse/IsFileBased/HasSchema/Config
    expandidos para 10 posicoes (dtSQLAnywhere - F5 Onda 10, SQL Anywhere 17).
    Conectividade NATIVA via dbcapi.dll (Zeos protocolo 'asa_capi', FireDAC
    DriverName/UniDAC ProviderName 'SQLAnywhere') - NAO ODBC (dbodbc17.dll so
    fallback SQLdb). Novas consts: DEFAULT_DATABASE_HOST/PORT/USERNAME/PASSWORD/
    NAME/SCHEMA/SERVERNAME_SQLANYWHERE (porta 2638) + DLL_SUBDIR_SQLANYWHERE +
    DEFAULT_DLL_NAME/PATH_SQLANYWHERE (dbcapi.dll, single-folder). Ver
    .workspace/reports/providersorm-v3-f5-entendimento-database-sqlanywhere-odbc_v1.0.md.
  - 1.0.0 (04/07/2026): migrado para o v3 (plano F1 Onda 1.1) - header 3.0.0;
    referencia da fonte v2.3.0 preservada abaixo. Correcao de paths de DLL:
    removidas constantes absolutas (System32/Program Files, nao usadas);
    DEFAULT_DLL_PATH_SQLITE passa a levar o prefixo dll/plat/ como os demais
    bancos. Padrao canonico unico: exe/dll/(win32 ou win64)/(banco)/.
  Changelog (fonte v2.3.0):
  - 1.0.0 (03/02/2026): Versão inicial.
  - 1.0.1 (22/02/2026): TDatabaseTypePair e TDatabaseTypeInverse (lookup inverso string -> TDatabaseTypes).
  - 1.0.2 (22/02/2026): Preenchimento dinâmico em initialization; DatabaseTypeConfigs, DatabaseTypeDllPaths, DatabaseTypeDllNames; TDatabaseTypeIsFileBased, TDatabaseTypeHasSchema.
  - 1.0.3 (22/02/2026): Prevalece DEFAULT_DATABASE_ENGINE_NAME (nome do engine atual); removido TDatabaseEngineNames (redundante).
  - 1.0.7 (22/02/2026): Removida GetDatabaseEngineName; engine definido por diretiva de compilação, usar DEFAULT_DATABASE_ENGINE_NAME.
  - 1.0.4 (22/02/2026): DEFAULT_CONNECTION_TIMEOUT e DEFAULT_QUERY_TIMEOUT (centralizados; antes em Providers.Connection.Consts). Comentários para uso por Connection (DEFAULT_DATABASE_PATH + DEFAULT_INI_FILENAME, DEFAULT_SECTION_NAME).
  - 1.0.5 (22/02/2026): Constantes de mensagens (exception.db) migrados de Exceptions.Commons.Consts.
  - 1.0.6 (22/02/2026): SQL CREATE TABLE messages migrado para Commons.Exceptions.SQL.
  - 1.0.7 (22/02/2026): Removida GetDatabaseEngineName; nome do engine apenas via DEFAULT_DATABASE_ENGINE_NAME (diretiva).
  - 1.0.8 (22/02/2026): DatabaseDefaultPath e DefaultMessagesDatabasePath em InitializeDatabaseTypeVariables; removida GetDefaultMessagesDatabasePath da interface.
  - 1.0.9 (22/02/2026): TMessageColumns e MESSAGES_COL (record com nomes das colunas da tabela messages).
  - 1.0.10 (22/02/2026): TMessageColumns, MESSAGES_COL_*, MESSAGES_COL e ExceptionsColumns movidos para Commons.Exceptions.
  - 1.0.11 (22/02/2026): Removidas DEFAULT_MESSAGES_DATABASE_PATH e DEFAULT_MESSAGES_DATABASE_PATH_ALT; uso de DEFAULT_DATABASE_PATH + DEFAULT_EXCEPTIONS_DATABASE_FILENAME onde necessário.
  - 1.0.12 (23/04/2026): TDatabaseTypeNames, TDatabaseTypeInverse, TDatabaseTypeIsFileBased, TDatabaseTypeHasSchema e TDatabaseTypeConfig expandidos para 9 posições (dtODBC, dtLDAP) — absorção Loggers; Onda 2 do plano loggers-parameters-master-absorption-v1.0.
  - 1.0.13 (28/06/2026): PROVIDERORM_VERSION (deprecated) sincronizada 2.1.6 → 2.2.0 (SSOT em Commons.Version).
  - 1.0.14 (02/07/2026): PROVIDERORM_VERSION (deprecated) sincronizada 2.2.0 → 2.3.0 (fachada unificada Providers).
  ============================================================================= }

unit Commons.Consts;

{$IF DEFINED(FPC)}
  {$MODE DELPHI} // Ensures DEFINED() and other Delphi features work
{$ENDIF}

interface

uses
  Commons.Types;

  {$I ORM.Defines.inc}

  type

  { Par (Name, DatabaseType) para lookup inverso: string -> TDatabaseTypes }
  TDatabaseTypePair = record
    Name: string;
    DatabaseType: TDatabaseTypes;
  end;

const
  {$IFDEF FPC}
    sLineBreak = LineEnding;
    {$IF NOT DEFINED(LINUX)}
      PathDelim = '\';
    {$ELSE}
      PathDelim = '/';
    {$ENDIF}
  {$ELSE}
    LineEnding = sLineBreak;
    EmptyStr = '';

    {$IF NOT DEFINED(LINUX)}
      DirectorySeparator = '\';
    {$ELSE}
      DirectorySeparator = '/';
    {$ENDIF}
  {$ENDIF}

  { Versão do projeto: use Commons.Version.PROVIDERORM_VERSION (SSOT em ORM.Version.inc).
    Mantida aqui apenas para retrocompatibilidade de units que ainda não migraram. }
  PROVIDERORM_VERSION = '3.0.0' deprecated 'Use Commons.Version.PROVIDERORM_VERSION';

  // Configurações de conexão padrão (engine atual: nome e enum)
  DEFAULT_DATABASE_ENGINE_NAME = {$IF DEFINED(USE_UNIDAC)}
                        'UniDAC'
                      {$ELSE} {$IF DEFINED(USE_FIREDAC)}
                                'FireDAC'
                              {$ELSE} {$IF DEFINED(USE_ZEOS)}
                                        'Zeos'
                                      {$ELSE}{$IF DEFINED(USE_SQLDB)}
                                               'SQLdb'
                                             {$ELSE}
                                               'None'
                                             {$ENDIF}
                                      {$ENDIF}
                              {$ENDIF}
                      {$ENDIF};

  DEFAULT_DATABASE_ENGINE : TDatabaseEngine = {$IF DEFINED(USE_UNIDAC)}
                        teUnidac
                      {$ELSE} {$IF DEFINED(USE_FIREDAC)}
                                teFireDAC
                              {$ELSE} {$IF DEFINED(USE_ZEOS)}
                                        teZeos
                                      {$ELSE}{$IF DEFINED(USE_SQLDB)}
                                               teSQLdb
                                             {$ELSE}
                                               teNone
                                             {$ENDIF}
                                      {$ENDIF}
                              {$ENDIF}
                      {$ENDIF};

  // Nomes genéricos de DatabaseTypes (usado para conversão de enum para string)
  // Ordem do enum TDatabaseTypes: dtNone, dtFireBird, dtMySQL, dtPostgreSQL, dtSQLite, dtSQLServer, dtAccess, dtSQLAnywhere, dtODBC, dtLDAP
  // (dtODBC/dtLDAP ficam sempre por ultimo - nao sao dialectos SQL "reais"; novos bancos entram ANTES deles)
  TDatabaseTypeNames: Array [TDatabaseTypes] of string = (
    'None',         // dtNone
    'Firebird',     // dtFireBird
    'MySQL',        // dtMySQL
    'PostgreSQL',   // dtPostgreSQL
    'SQLite',       // dtSQLite
    'SQL Server',   // dtSQLServer
    'Access',       // dtAccess
    'SQL Anywhere', // dtSQLAnywhere
    'ODBC',         // dtODBC
    'LDAP'          // dtLDAP
  );

  { Lookup inverso: string -> TDatabaseTypes. Iterar e comparar Name para obter DatabaseType. }
  TDatabaseTypeInverse: array[TDatabaseTypes] of TDatabaseTypePair = (
    (Name: 'None'; DatabaseType: dtNone),
    (Name: 'Firebird'; DatabaseType: dtFireBird),
    (Name: 'MySQL'; DatabaseType: dtMySQL),
    (Name: 'PostgreSQL'; DatabaseType: dtPostgreSQL),
    (Name: 'SQLite'; DatabaseType: dtSQLite),
    (Name: 'SQL Server'; DatabaseType: dtSQLServer),
    (Name: 'Access'; DatabaseType: dtAccess),
    (Name: 'SQL Anywhere'; DatabaseType: dtSQLAnywhere),
    (Name: 'ODBC'; DatabaseType: dtODBC),
    (Name: 'LDAP'; DatabaseType: dtLDAP)
  );

  { Baseado em arquivo (SQLite, Access) vs servidor; ODBC, LDAP e SQL Anywhere sao servidores }
  TDatabaseTypeIsFileBased: array[TDatabaseTypes] of Boolean = (
    False, False, False, False, True, False, True, False, False, False
  );

  { Suporta schema (PostgreSQL, SQL Server, SQL Anywhere - owner); ODBC e LDAP nao tem schema }
  TDatabaseTypeHasSchema: array[TDatabaseTypes] of Boolean = (
    False, False, False, True, False, True, False, True, False, False
  );

  // Mapeamento Bidimensional
  // Linhas  = TDatabaseEngine (teNone, teUnidac, teFireDAC, teZeos, teSQLdb)
  // Colunas = TDatabaseTypes  (dtNone, dtFireBird, dtMySQL, dtPostgreSQL, dtSQLite, dtSQLServer, dtAccess, dtSQLAnywhere, dtODBC, dtLDAP)
  // SQL Anywhere (F5 Onda 10): Zeos e UniDAC ligam NATIVO via dbcapi.dll; o
  // FireDAC usa o driver 'ASA' (FireDAC.Phys.ASA), que HERDA de
  // TFDPhysODBCDriverBase - ou seja, no FireDAC o SQL Anywhere e ODBC-based
  // internamente (dbodbc17.dll), confirmado no source FireDAC.Phys.ASA.pas
  // (16/07). Protocolo Zeos = 'asa_capi' (ZPlainSQLAnywhere.pas); FireDAC
  // DriverName = 'ASA'. UniDAC: o pacote VENDORIZADO neste lab
  // (Packages/UniDAC) NAO tem provider dedicado SQL Anywhere (so ASE, produto
  // Sybase DIFERENTE) - usa provider 'ODBC' generico (SpecificOptions
  // ODBC.ConnectString), confirmado empiricamente 16/07.
  // SQLdb (FPC puro) nao tem conector nativo na FCL -> cai em ODBC (dbodbc17.dll).
  TDatabaseTypeConfig: array [TDatabaseEngine, TDatabaseTypes] of string = (
    { teNone }    ('None', 'None',       'None',  'None',       'None',   'None',       'None',   'None',  'None',  'None'),
    { teUnidac }  ('None', 'InterBase',  'MySQL', 'PostgreSQL', 'SQLite', 'SQL Server', 'Access', 'ODBC',  'ODBC',  'LDAP'),
    { teFireDAC } ('None', 'FB',         'MySQL', 'PG',         'SQLite', 'MSSQL',      'MSAcc',  'ASA',        'ODBC',  'LDAP'),
    { teZeos }    ('None', 'firebird',   'mysql', 'postgresql', 'sqlite', 'mssql',      'OleDB',  'asa_capi',   'odbc_a','ldap'),
    { teSQLdb }   ('None', 'firebird',   'mysql', 'postgres',   'sqlite', 'mssql',      'odbc',   'odbc',       'odbc',  'ldap')
  );

 {=============================================================================
  CONSTANTES DE CONFIGURAÇÃO DE ARQUIVOS
  ============================================================================= }

  { Timeout padrão de conexão e de query (segundos). Usados por Connection e módulos que precisam de limite de tempo. }
  DEFAULT_CONNECTION_TIMEOUT = 30;
  DEFAULT_QUERY_TIMEOUT = 30;

  { Nome padrão da seção/path/tabela de configuração para INI ou JSon}
  DEFAULT_SECTION_DATABASE_NAME  = 'databases';
  DEFAULT_SECTION_EXCEPTION_NAME = 'exceptions';
  DEFAULT_SECTION_PARAMETER_NAME = 'parameters';   // sempre no plural (D11; unico canonico)
  { Fallback do typo historico 'paramenters' (leitura de configs antigos em IniFiles/JsonObject). }
  DEFAULT_SECTION_PARAMETER_NAME_LEGACY = 'paramenters' deprecated 'use DEFAULT_SECTION_PARAMETER_NAME';
  DEFAULT_SECTION_LOGGER_NAME    = 'loggers';
  { Seção do INI/JSON usada pelo módulo Exceptions (Exception.Connection, Exceptions.Database). }
  EXCEPTIONS_CONFIG_SECTION            = DEFAULT_SECTION_EXCEPTION_NAME;

  { Nome padrão do arquivo INI de configuração (Connection.FromConfig usa DEFAULT_DATABASE_PATH + DEFAULT_INI_FILENAME, seção DEFAULT_SECTION_NAME). }
  DEFAULT_CONFIG_INI_FILENAME          = 'config.ini';
  DEFAULT_INI_FILENAME                 = DEFAULT_CONFIG_INI_FILENAME;

  { Nome padrão do arquivo JSON de configuração }
  DEFAULT_CONFIG_JSON_FILENAME         = 'config.json';

  { Nome padrão do arquivo Database de configuração (SQLite) }
  DEFAULT_CONFIG_DATABASE_FILENAME     = 'config.db';

  { Nome padrão do arquivo Database de mensagens (SQLite) }
  DEFAULT_EXCEPTIONS_DATABASE_FILENAME = 'exception.db';

  { =============================================================================
    CAMINHOS PADRÃO PARA CONFIG (LEITURA database_dll) E PASTA DE DLLs
    Usados por GetDatabaseDllBasePath quando não definidos via ConfigFilePath/DllBasePath.
    Connection.FromConfig usa DEFAULT_DATABASE_PATH + DEFAULT_INI_FILENAME e seção DEFAULT_SECTION_NAME.
    ============================================================================= }
  DEFAULT_DATABASE          = 'data' ;
  DEFAULT_DATABASE_PATH     = DEFAULT_DATABASE + DirectorySeparator;
  DEFAULT_DATABASE_PATH_ALT = '.' + DirectorySeparator;
  DEFAULT_DATABASE_PATH_DLL = DEFAULT_DATABASE + DirectorySeparator + 'dll';

  { =============================================================================
    CONNECT ZERO-CONFIG (tipo de banco padrão quando nada informado)
    FromConfig usa DEFAULT_CONFIG_DATABASE_FILENAME (psDatabase).
    String para conexão: TDatabaseTypeNames[DEFAULT_PARAMETERS_CONNECT_DATABASE_TYPE].
    ============================================================================= }
  DEFAULT_DATABASE_TYPE: TDatabaseTypes = dtSQLite;

  // Valores padrão de tipo de banco SQLite
  DEFAULT_SQLITE_HOST         = '';
  DEFAULT_SQLITE_PORT         = 0;
  DEFAULT_SQLITE_USERNAME     = '';
  DEFAULT_SQLITE_PASSWORD     = '';
  DEFAULT_SQLITE_NAME         = DEFAULT_DATABASE_PATH + DEFAULT_CONFIG_DATABASE_FILENAME;
  DEFAULT_SQLITE_SCHEMA       = '';
  DEFAULT_SQLITE_TYPE         = TDatabaseTypes.dtSQLite;

  { =============================================================================
    DEFAULTS DE CONEXAO POR BANCO (transversal - D11)
    Host/Port/Username/Password/Name/Schema padrao por tipo de banco. Usados por
    Connection, Parameters e Loggers.Database. Movidos de Commons.Parameters.Consts
    (Onda 1.2 revisitada) por serem partilhados por 2+ modulos.
    ============================================================================= }
  { Tipos de banco suportados pelo engine SQLdb (FPC). Transversal (Connection/Parameters). }
  SQLDB_SUPPORTED_TYPES: set of TDatabaseTypes = [dtFireBird, dtMySQL, dtPostgreSQL, dtSQLite, dtSQLServer];

  { Chaves da seccao de conexao no config (INI/JSON). Lidas por Connection.FromConfig e Parameters.
    Indice 8 (dll_download_url) - so o Parameters le (override do URL de download de
    Commons.DllBootstrap por perfil; mecanica de download continua centralizada la). }
  CONNECTION_CONFIG_KEYS: array[0..8] of string = (
    'host', 'port', 'username', 'password', 'database', 'schema', 'database_type', 'database_dll',
    'dll_download_url');

  DEFAULT_DATABASE_HOST_FIREBIRD       = 'localhost';
  DEFAULT_DATABASE_HOST_MYSQL          = 'localhost';
  DEFAULT_DATABASE_HOST_POSTGRESQL     = 'localhost';
  DEFAULT_DATABASE_HOST_SQLSERVER      = 'localhost';
  DEFAULT_DATABASE_HOST_SQLITE         = '';
  DEFAULT_DATABASE_HOST_ACCESS         = '';
  DEFAULT_DATABASE_HOST_SQLANYWHERE    = 'localhost';

  DEFAULT_DATABASE_PORT_FIREBIRD       = 3050;
  DEFAULT_DATABASE_PORT_MYSQL          = 3306;
  DEFAULT_DATABASE_PORT_POSTGRESQL     = 5432;
  DEFAULT_DATABASE_PORT_SQLSERVER      = 1433;
  DEFAULT_DATABASE_PORT_SQLITE         = 0;
  DEFAULT_DATABASE_PORT_ACCESS         = 0;
  DEFAULT_DATABASE_PORT_SQLANYWHERE    = 2638;

  DEFAULT_DATABASE_USERNAME_FIREBIRD   = 'SYSDBA';
  DEFAULT_DATABASE_USERNAME_MYSQL      = 'root';
  DEFAULT_DATABASE_USERNAME_POSTGRESQL = 'postgres';
  DEFAULT_DATABASE_USERNAME_SQLSERVER  = 'sa';
  DEFAULT_DATABASE_USERNAME_SQLITE     = '';
  DEFAULT_DATABASE_USERNAME_ACCESS     = '';
  DEFAULT_DATABASE_USERNAME_SQLANYWHERE = 'DBA';

  DEFAULT_DATABASE_PASSWORD_FIREBIRD   = 'masterkey';
  DEFAULT_DATABASE_PASSWORD_MYSQL      = '';
  DEFAULT_DATABASE_PASSWORD_POSTGRESQL = '';
  DEFAULT_DATABASE_PASSWORD_SQLSERVER  = '';
  DEFAULT_DATABASE_PASSWORD_SQLITE     = '';
  DEFAULT_DATABASE_PASSWORD_ACCESS     = '';
  DEFAULT_DATABASE_PASSWORD_SQLANYWHERE = 'sql';

  DEFAULT_DATABASE_NAME_FIREBIRD       = 'config.fdb';
  DEFAULT_DATABASE_NAME_MYSQL          = 'csl_versao';
  DEFAULT_DATABASE_NAME_POSTGRESQL     = 'facilitycar';
  DEFAULT_DATABASE_NAME_SQLSERVER      = 'Comercial';
  DEFAULT_DATABASE_NAME_SQLITE         = 'config.db';
  DEFAULT_DATABASE_NAME_ACCESS         = 'config.mdb';
  DEFAULT_DATABASE_NAME_SQLANYWHERE    = 'demo';

  DEFAULT_DATABASE_SCHEMA_FIREBIRD     = '';
  DEFAULT_DATABASE_SCHEMA_MYSQL        = '';
  DEFAULT_DATABASE_SCHEMA_POSTGRESQL   = 'public';
  DEFAULT_DATABASE_SCHEMA_SQLSERVER    = 'dbo';
  DEFAULT_DATABASE_SCHEMA_SQLITE       = '';
  DEFAULT_DATABASE_SCHEMA_ACCESS       = '';
  DEFAULT_DATABASE_SCHEMA_SQLANYWHERE  = '';

  { ServerName/ENG (F5 Onda 10) - SQL Anywhere distingue o nome logico do servidor
    (ENG) do Host/IP; API dedicada na IConnection (nao so chave solta em JSON). }
  DEFAULT_DATABASE_SERVERNAME_SQLANYWHERE = '';

{ =============================================================================
  CONSTANTES DE CAMINHOS DE DLLs POR TIPO DE BANCO E ENGINE
  ============================================================================= }

  { Caminhos padrão para diretório @dll (32/64 bits) }
  { Prioridade máxima: busca primeiro no diretório @dll conforme arquitetura }

  { Subpasta de plataforma — UNICO sitio que decide win32/win64 (usado por
    DEFAULT_DLL_DIRECTORY e pelas free functions de Commons.DynamicLibrary). }
  DLL_PLATFORM_SUBDIR = {$IFDEF WIN32} 'win32' {$ELSE} 'win64' {$ENDIF};

  { Subpastas de vendor por banco (relativas a dll/<plat>/) — SSOT unico reutilizado
    pelas DEFAULT_DLL_PATH_* abaixo e por Commons.DynamicLibrary (zero literais la). }
  DLL_SUBDIR_POSTGRESQL        = 'PostgreSQL' + DirectorySeparator + 'lib';
  DLL_SUBDIR_MYSQL             = 'MySql';
  DLL_SUBDIR_SQLSERVER_FREETDS = 'FreeTDS';
  DLL_SUBDIR_SQLITE            = 'SQLite';
  DLL_SUBDIR_FIREBIRD          = 'FireBird';
  DLL_SUBDIR_SQLANYWHERE       = 'SQLAnywhere';

  DEFAULT_DLL_NAME_UNRAR       = 'unrar.dll';    // modulo ZipFile (RAR, F1-A/D12); solto em dll/{plat}/

  { URL do pacote de DLLs cliente de banco (Commons.DllBootstrap, F1-A/A.5; opt-in
    USE_DLL_AUTODOWNLOAD). O zip traz a arvore dll/win32-ou-win64/banco/... que e
    extraida para a pasta do executavel pelo modulo ZipFile. }
  DEFAULT_DLL_DOWNLOAD_URL     = 'https://download.cslsolucoes.com.br/dll.zip';

  DEFAULT_DLL_DIRECTORY = DEFAULT_DATABASE_PATH_DLL + DirectorySeparator +
                          DLL_PLATFORM_SUBDIR + DirectorySeparator;

  DEFAULT_DLL_PATH_POSTGRESQL = DEFAULT_DLL_DIRECTORY + DLL_SUBDIR_POSTGRESQL + DirectorySeparator;
  DEFAULT_DLL_NAME_POSTGRESQL = 'libpq.dll';

  { Caminhos padrão para DLLs do MySQL }
  DEFAULT_DLL_NAME_MYSQL = 'libmysql.dll';
  DEFAULT_DLL_NAME_MYSQL_MARIADB = 'libmariadb.dll'; // preferida; fallback -> libmysql
  DEFAULT_DLL_PATH_MYSQL = DEFAULT_DLL_DIRECTORY + DLL_SUBDIR_MYSQL + DirectorySeparator;

  { Caminhos padrão para DLLs do SQL Server }
  { Zeos usa FreeTDS empacotado (dll\<plat>\FreeTDS); UniDAC/FireDAC usam o driver
    do sistema (sqlncli/msodbcsql) — DEFAULT_DLL_PATH_SQLSERVER fica relativo ao PATH. }
  DEFAULT_DLL_NAME_SQLSERVER = 'sqlncli11.dll'; // SQL Server Native Client (UniDAC)
  DEFAULT_DLL_PATH_SQLSERVER = '.' + DirectorySeparator;
  DEFAULT_DLL_NAME_SQLSERVER_FREETDS = 'libsybdb-5.dll'; // FreeTDS para Zeos (substitui NTWDBLIB.DLL)
  DEFAULT_DLL_PATH_SQLSERVER_FREETDS = DEFAULT_DLL_DIRECTORY + DLL_SUBDIR_SQLSERVER_FREETDS + DirectorySeparator;

  { Caminhos padrão para DLLs do SQLite }
  DEFAULT_DLL_NAME_SQLITE = 'sqlite3.dll';
  DEFAULT_DLL_PATH_SQLITE = DEFAULT_DLL_DIRECTORY + DLL_SUBDIR_SQLITE + DirectorySeparator;

  { Caminhos das DLLs do FireBird - MULTI-VERSAO (plano 2-D).
    Estrutura: dll\plat\FireBird\N\  onde N = 2|3|4|5 (major: 2.5/3.0/4.0/5.0).
    Cada subpasta traz fbclient.dll + as dependencias dessa versao (ICU/MSVC/zlib/OpenSSL).
    DEFAULT_DLL_PATH_FIREBIRD e a BASE; a resolucao acrescenta a subpasta da versao
    (FIREBIRD_VERSION_SUBDIR de v) - implementada na Commons.DynamicLibrary (Onda 1.3). }
  DEFAULT_DLL_NAME_FIREBIRD = 'fbclient.dll';   // 2.5+ usam fbclient.dll (GDS32 = alias legado)
  DEFAULT_DLL_PATH_FIREBIRD = DEFAULT_DLL_DIRECTORY + DLL_SUBDIR_FIREBIRD + DirectorySeparator;

  { Subpasta por versao de Firebird (indexada por TFirebirdVersion: fb25/fb30/fb40/fb50) }
  FIREBIRD_VERSION_SUBDIR: array[TFirebirdVersion] of string = ('2', '3', '4', '5');
  DEFAULT_FIREBIRD_VERSION: TFirebirdVersion = fb50;

  { Caminho padrao para a DLL do SQL Anywhere 17 (F5 Onda 10). Cliente NATIVO
    (dbcapi.dll) usado por Zeos ('asa_capi')/FireDAC/UniDAC - NAO e ODBC (dbodbc17.dll
    fica so de fallback do SQLdb). Single-folder (sem multi-versao como o Firebird -
    sem evidencia de incompatibilidade binaria entre versoes do dbcapi ate agora). }
  DEFAULT_DLL_NAME_SQLANYWHERE = 'dbcapi.dll';
  DEFAULT_DLL_PATH_SQLANYWHERE = DEFAULT_DLL_DIRECTORY + DLL_SUBDIR_SQLANYWHERE + DirectorySeparator;

  { =============================================================================
    BANCO DE MENSAGENS (Data/exception.db) — usado pelo módulo Exceptions
    ============================================================================= }
  DEFAULT_MESSAGES_TABLE = 'messages';

  DEFAULT_LANGUAGE = 'pt-BR';
  LANGUAGE_PT_BR = 'pt-BR';
  LANGUAGE_EN = 'en';
  LANGUAGE_ES = 'es';

  { DDL da tabela `messages`: NAO existe mais template SQL. A tabela e criada por fluencia (ITable + IDialect) em Exceptions.Messages.EnsureMessagesTable. }

  { =============================================================================
    BANCO DE PARAMETROS (config) - usado pelo modulo Parameters
    Constantes de API publica (o consumidor passa/le ao usar IParameters).
    Tipos correspondentes (TParameter/Source/Config/ValueType) em Commons.Types.
    ============================================================================= }
  { Q16: default do FRAMEWORK v3 = 'parameters' (o v2.3.0/producao GestorERP usa
    'config' via TableName override - a instancia decide, o default nao). Alinhado
    21/07 ao default real do codigo (TParametersDatabase.FTableName := 'parameters'). }
  DEFAULT_PARAMETERS_TABLE = 'parameters';

  { Nomes dos tipos de valor de parametro (TParameterValueType). }
  ParameterValueTypeNames: array[TParameterValueType] of string =
    ('String', 'Integer', 'Float', 'Boolean', 'DateTime', 'JSON');

  { Fonte, tipo de valor e configuracao de fontes padrao. }
  DEFAULT_PARAMETER_SOURCE: TParameterSource = psDatabase;
  DEFAULT_PARAMETER_VALUE_TYPE = pvtString;
  DEFAULT_PARAMETER_CONFIG: TParameterConfig = [psDatabase, psInifiles];
  DEFAULT_PARAMETER_CONFIG_DATABASE_ONLY: TParameterConfig = [psDatabase];
  DEFAULT_PARAMETER_CONFIG_INIFILE_ONLY: TParameterConfig = [psInifiles];
  DEFAULT_PARAMETER_CONFIG_JSON_ONLY: TParameterConfig = [psJsonObject];
  DEFAULT_PARAMETER_CONFIG_ALL: TParameterConfig = [psDatabase, psInifiles, psJsonObject];
  DEFAULT_PARAMETER_PRIORITY: array[0..2] of string = ('Database', 'Inifiles', 'JsonObject');

  { Mensagens de parametros (PARAMETER_NOT_FOUND usada tambem por Exceptions). }
  PARAMETER_NOT_FOUND             = 'Parameter not found';
  PARAMETER_SOURCE_NOT_CONFIGURED = 'Parameter source not configured';
  PARAMETER_TABLE_NOT_EXISTS      = 'Parameter table does not exist';
  PARAMETER_FILE_NOT_EXISTS       = 'Parameter file does not exist';

  SOURCE_PROJECT_ORM = 'ORM';
  SOURCE_PROJECT_LOGGERS = 'LoggersORM';
  SOURCE_PROJECT_PARAMETERS = 'ParamentersORM';
  SOURCE_PROJECT_ACTIVEDIRECTORY = 'ActiveDirectoryORM';
  SOURCE_PROJECT_PRINTER = 'PrinterORM';
  SOURCE_PROJECT_POOLCONECTION = 'PoolConectionORM';
  SOURCE_PROJECT_CONNECTIONS = 'ConnectionsORM';
  SOURCE_PROJECT_DATABASES = 'DatabasesORM';
  SOURCE_PROJECT_EXCEPTIONS = 'ExceptionsORM';
  SOURCE_PROJECT_VERSION = 'VersionORM';  

  minusculo = ['a' .. 'z'];
  maiusculo = ['A' .. 'Z'];

  // Outras constantes
  ProgramDetailsMax = 13;

  ProgramDetailsEn : array [1 .. ProgramDetailsMax] of string = (
    'CompanyName', 'FileDescription', 'FileVersion', 'InternalName', 'LegalCopyright',
    'OriginalFilename', 'ProductName', 'ProductVersion', 'Comments', 'LegalTrademarks',
    'ProductID', 'ContractID', 'Key');
  ProgramDetailsBr : array [1 .. ProgramDetailsMax] of string = (
    'Empresa', 'Descricao', 'Versao do Arquivo', 'Nome Interno', 'Copyright',
    'Nome Original do Arquivo', 'Produto', 'Versao do Produto', 'Comentarios', 'Autor',
    'ProdutoID', 'ContratoID', 'Chave');

  semanaBr : array [0 .. 6]  of string[3] = ('Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab');
  semanaEn : array [0 .. 6]  of string[3] = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');

  mesesBr  : array [1 .. 12] of string[3] = ('Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez');
  mesesEn  : array [1 .. 12] of string[3] = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');

var
{
// Acesso direto sem lookup 2D
LConfig := DatabaseTypeConfigs[dtPostgreSQL];

// Valores do tipo padrão
LConfig := DatabaseTypeDefaultConfig;
LDisplay := DatabaseTypeDefaultDisplayName;

// Verificações por tipo
if TDatabaseTypeIsFileBased[dtSQLite] then ...
if TDatabaseTypeHasSchema[dtPostgreSQL] then ...

// Caminhos de DLL
LDllPath := DatabaseTypeDllPaths[dtMySQL];
LDllName := DatabaseTypeDllNames[dtPostgreSQL];
}

  { Arrays preenchidos dinamicamente em initialization a partir de TDatabaseTypeConfig e DEFAULT_DATABASE_ENGINE }
  DatabaseTypeConfigs            : array[TDatabaseTypes] of string;
  DatabaseTypeDllPaths           : array[TDatabaseTypes] of string;
  DatabaseTypeDllNames           : array[TDatabaseTypes] of string;
  { Valores do tipo padrão (DEFAULT_DATABASE_TYPE) para acesso direto }
  DatabaseTypeDefaultConfig      : string;
  DatabaseTypeDefaultDisplayName : string;
  DatabaseDefaultPath            : string;
  { Caminho completo do banco de mensagens (exception.db), definido em initialization. }
  DefaultMessagesDatabasePath    : string;

implementation

uses
  {$IF DEFINED(FPC)}
  SysUtils;
{$ELSE}
  System.SysUtils;
{$ENDIF}

procedure InitializeDatabaseTypeVariables;
var
  I: TDatabaseTypes;
  LExePath, LPathData, LPathDataAlt: string;
begin
  for I := Low(TDatabaseTypes) to High(TDatabaseTypes) do
  begin
    DatabaseTypeConfigs[I] := TDatabaseTypeConfig[DEFAULT_DATABASE_ENGINE, I];
    case I of
      dtPostgreSQL:
        begin
          DatabaseTypeDllPaths[I] := DEFAULT_DLL_PATH_POSTGRESQL;
          DatabaseTypeDllNames[I] := DEFAULT_DLL_NAME_POSTGRESQL;
        end;
      dtMySQL:
        begin
          DatabaseTypeDllPaths[I] := DEFAULT_DLL_PATH_MYSQL;
          DatabaseTypeDllNames[I] := DEFAULT_DLL_NAME_MYSQL;
        end;
      dtSQLServer:
        begin
          if DEFAULT_DATABASE_ENGINE = teZeos then
          begin
            DatabaseTypeDllPaths[I] := DEFAULT_DLL_PATH_SQLSERVER_FREETDS;
            DatabaseTypeDllNames[I] := DEFAULT_DLL_NAME_SQLSERVER_FREETDS;
          end
          else
          begin
            DatabaseTypeDllPaths[I] := DEFAULT_DLL_PATH_SQLSERVER;
            DatabaseTypeDllNames[I] := DEFAULT_DLL_NAME_SQLSERVER;
          end;
        end;
      dtFireBird:
        begin
          DatabaseTypeDllPaths[I] := DEFAULT_DLL_PATH_FIREBIRD;
          DatabaseTypeDllNames[I] := DEFAULT_DLL_NAME_FIREBIRD;
        end;
      dtSQLite:
        begin
          DatabaseTypeDllPaths[I] := DEFAULT_DLL_PATH_SQLITE;
          DatabaseTypeDllNames[I] := DEFAULT_DLL_NAME_SQLITE;
        end;
      dtSQLAnywhere:
        begin
          DatabaseTypeDllPaths[I] := DEFAULT_DLL_PATH_SQLANYWHERE;
          DatabaseTypeDllNames[I] := DEFAULT_DLL_NAME_SQLANYWHERE;
        end;
    else
      begin
        DatabaseTypeDllPaths[I] := '';
        DatabaseTypeDllNames[I] := '';
      end;
    end;
  end;
  DatabaseTypeDefaultConfig      := DatabaseTypeConfigs[DEFAULT_DATABASE_TYPE];
  DatabaseTypeDefaultDisplayName := TDatabaseTypeNames[DEFAULT_DATABASE_TYPE];
  DatabaseDefaultPath            := DEFAULT_DATABASE_PATH;

  { Caminho do banco de mensagens (exception.db): relativo. Prioridade "data" (minúsculo) para alinhar à pasta do exe; depois "Data". }
  LExePath := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  LPathDataAlt := LExePath + DEFAULT_DATABASE + DirectorySeparator + DEFAULT_EXCEPTIONS_DATABASE_FILENAME;
  LPathData := LExePath + DEFAULT_DATABASE_PATH + DEFAULT_EXCEPTIONS_DATABASE_FILENAME;
  if FileExists(LPathDataAlt) or DirectoryExists(LExePath + DEFAULT_DATABASE) then
    DefaultMessagesDatabasePath := DEFAULT_DATABASE + DirectorySeparator + DEFAULT_EXCEPTIONS_DATABASE_FILENAME
  else if FileExists(LPathData) or DirectoryExists(LExePath + DEFAULT_DATABASE) then
    DefaultMessagesDatabasePath := DEFAULT_DATABASE_PATH + DEFAULT_EXCEPTIONS_DATABASE_FILENAME
  else
    DefaultMessagesDatabasePath := DEFAULT_DATABASE + DirectorySeparator + DEFAULT_EXCEPTIONS_DATABASE_FILENAME;
end;

initialization
  InitializeDatabaseTypeVariables;

end.
