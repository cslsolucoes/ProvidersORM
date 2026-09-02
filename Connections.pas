{ =============================================================================
  Connections - Implementação da conexão com o banco (TConnection, IConnection)

  Absorção Onda 4.1 (F4 Connections) de ProvidersORM v2.3.0. Cortes/substituições
  vs a fonte (decisão do owner, plano parametersorm-providers-v3-refactor):
  - Parameters.Interfaces/Commons.Parameters.Types/Commons.Parameters.Consts/
    Exceptions.Parameters/Parameters.JsonObject removidos do uses — eram imports
    mortos (nenhum símbolo usado no corpo do ficheiro; confirmado por análise).
  - DataSet.Serialize removido do uses — idem, import morto.
  - SetExceptions/SetLogger (+ campos FExceptions/FLogger + a chamada
    FLogger.Error dentro de Connect) removidos — não fazem parte do contrato
    IConnection; ILogger/IExceptions ainda não existem em src/ (waves futuras).
    Reintrodução é aditiva quando Loggers/Exceptions-service chegarem.
    SetLogger REINTRODUZIDO em 09/08/2026 (F8 Onda 8.6, ver changelog 1.9.0
    abaixo) — SetExceptions continua removido (Exceptions-service ainda não
    tem um seam equivalente a SetLogger/ILogger).
  - ConnectionAttribute passa a vir de Attributers.Connections (não
    Attributers.Providers.Interfaces — essa depende de Database.Table.Interfaces,
    módulo que só chega na wave Database, posterior a Connections).
  - FromConfig passa a usar o seam de DI Connections.FromConfig
    (IConnectionConfigureLoader/TConnectionConfigureLoaderRegistry) — sem loader
    registado, lança EConnectionConfigurationException (antes falhava em
    silêncio ao tentar um path INI default). FromIniFile/FromJSON/FromClass
    continuam diretos, sem passar pelo seam.
  - AddDllDirectoryToPath (função local) substituída por
    Commons.DynamicLibrary.AppendPathEnv (já existia, centralizada; documentada
    como "consumido por Connections (F4)"). SyncObjs/Math/StrUtils nativo (FPC)/
    ComObj/ActiveX/System.Win.ComObj/Winapi.ActiveX/Windows removidos do uses —
    também imports mortos (confirmado por análise: zero chamada no corpo).
  - Variants adicionado ao branch FPC do uses (fix defensivo: Null/Unassigned
    vêm dessa unit; o branch FPC original não a listava).
  - EConnectionException e subclasses continuam a vir de Exceptions.Base (Opção
    A da análise — módulo Exceptions, wave F2, já as tem prontas; nenhuma
    Exceptions.Connections.pas nova foi criada).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.2.0
  FileVersion:    1.9.0
  Author:         Claiton de Souza Linhares
  Date:           09/08/2026

  Changelog (file):
  - 1.9.0 (09/08/2026): F8 Onda 8.6 -- SetLogger(const ALogger: ILogger):
    IConnection reintroduzido (removido na absorcao Onda 4.1, ver nota no
    topo deste header), guardado por define USE_LOGGERS. Apenas na classe
    TConnection, mesmo padrao dos 5 eventos OnBefore/AfterConnect/
    Disconnect/OnConnectionError (nao faz parte do contrato IConnection).
    Piggyback nos MESMOS pontos onde esses eventos ja disparam (Connect/
    Disconnect) -- nenhum ponto de chamada novo. Default = TNullLogger
    (Loggers.NullLogger, zero overhead). Validado isolado antes desta
    aplicacao: src/testes/Loggers/spike_connections_setlogger.dpr (10/10
    OK, 4 alvos) + patch em .workspace/patches/f8-onda8.6-connections-setlogger/
    (aplicado com autorizacao expressa do owner, pasta bloqueada).
  - 1.8.6 (30/07/2026): bug-986 (test_serialize.dpr, UniDAC x fpc32/dcc32 x
    sqlanywhere - "Item 'valor' already exists" numa 2a chamada de
    TSynchronize.Sync, na MESMA ligacao da 1a) - mesma raiz do bug-884/983.
    TConnection.ExecuteQuery (overload simples, sem parametros) fechava a
    leitura fora de transaccao explicita so' quando o bookkeeping NATIVO
    TUniConnection.InTransaction reportava uma transaccao activa - suficiente
    para Firebird (achado original desta guarda), mas NAO para SQL Anywhere:
    GetColumnNames/GetTableStructure correm o SELECT de catalogo por este
    metodo (sem ramo dedicado como GetTableNamesFromDriver), e o bookkeeping
    NATIVO pode NAO reportar a transaccao residual real aberta pelo dbcapi
    para este motor. TENTATIVA 1 (refutada empiricamente): acrescentar so' um
    OR "(FDatabaseType=dtSQLAnywhere) or InTransaction" a chamar
    TUniConnection.Commit (a mesma API nativa) - NAO resolveu (3/3 FAIL
    manteve-se identico); a chamada nativa continua a ser no-op quando o
    driver "acha" que nao ha transaccao para commitar. FIX DE RAIZ (validado):
    para dtSQLAnywhere, substituido por um "COMMIT" em SQL CRU via
    Self.ExecuteCommand('COMMIT') - MESMO mecanismo ja provado em
    TSynchronize.VerifyShape/CommitResidualSQLAnywhere (bug-983/990) - que
    bypassa esse bookkeeping por completo (fecha SEMPRE, mesmo quando o
    driver diz que nao ha nada para fechar). Gated ao motor: Firebird mantem-
    se pelo InTransaction nativo (linha acima, inalterada), zero mudanca nos
    restantes engines. Validado: test_serialize 3x dcc32 + 3x fpc32 x
    sqlanywhere = 0 FAIL (era 3/3 FAIL, "Item 'valor' already exists" na 2a
    aplicacao/merge); test_catalogreader sem regressao; postgresql/sqlite
    sem regressao; 4 alvos ProvidersV3 EXIT=0.
  - 1.8.5 (27/07/2026): F5-pendencias - bug-820 FIX DE RAIZ (framework, NAO package).
    BindParams (ramo USE_ZEOS) passa a TIPAR cada parametro (DataType por VarType,
    antes do Value) espelhando o ramo UniDAC. Root cause provado por A/B isolado:
    raw Zeos asa_capi + params TIPADOS (ParamByName.AsX) corre limpo em win64 sob
    D12 E D13; so o Variant CRU do BindParams (esp. varDate de data_cadastro/
    alteracao e varBoolean de ativo) corrompia o heap em win64 (AV em SysGetMem) no
    ramo dblib/SACAPI - o UniDAC ja tipava e por isso passava 13/13 no MESMO
    dbcapi.dll. Corrige tambem o INSERT parametrizado do caminho freetds/sybase
    (erro 'column 16 Unknown->Integer', mesma raiz). Principio do owner: trabalhar
    o mais tipado possivel sempre. Estrategia A (comportamento so muda no que
    estava a corromper). Refuta o anterior 'bug-820 = package deferido'.
  - 1.8.4 (27/07/2026): F5-pendencias - bug-820 SIDESTEP (opt-in, ADITIVO,
    ModuleVersion 1.0.24->1.1.0): nova variante IConnection.SQLAnywhereDriver=
    'freetds' (junta-se a 'native'|'odbc') que liga o SQL Anywhere via FreeTDS
    db-lib (protocolo Zeos 'sybase' -> dpSybase -> TDS 5.0 automatico por-login em
    ZDbcDbLib, sem env-var global) em vez do 'asa_capi'/dbcapi.dll win64 que
    corrompe o heap (bug-820, confirmado package). No ramo USE_ZEOS de
    ConfigureNativeConnection, quando dtSQLAnywhere+freetds: Protocol:='sybase',
    Database:='' (SA nao suporta USE), sem ENG (TDS routeia por host:port),
    LibLocation/PATH := libsybdb-5.dll do SQL Server (GetVendorLibPath(dtSQLServer),
    regra #14 - MESMA DLL FreeTDS). Default 'native' inalterado. Provado por
    spike_sa_freetds.dpr (dcc64: liga + SYS.SYSTABLE 359 + CRUD/overlap SEM AV).
    Governanca rule #7 = Estrategia A (aditivo, nenhum simbolo alterado).
  - 1.8.3 (27/07/2026): F5-pendencias Onda 1 (bug-819, D1-A opcao a) - no ramo
    USE_ZEOS de GetTableNamesFromDriver, o SQL Server passa a introspecionar os
    nomes de tabela por SQL directo a sys.tables WITH (NOLOCK) via
    ExecuteQueryZeosReadOnly (na PROPRIA sessao), em vez do TZSQLMetadata (mdTables)
    - o metadata-driver abria um contexto de metadata separado que PENDURAVA no
    Sch-M lock de um CREATE TABLE ainda por libertar (mesmo padrao anti-hang do
    bug-768/Firebird e do contorno ja existente para SQL Anywhere/Firebird acima).
    Cirurgico, cross-compiler, so-SQL-Server; nao mexe no transaction handling do
    Sync (opcao b, nao escolhida). Limitacao aceite da opcao (a): o Sch-M so liberta
    a sessoes EXTERNAS no disconnect do criador - esta correcao cobre a introspeccao
    do proprio modulo. GetTableNames/GetTableNamesFromDriver preservam assinatura e
    semantica (backward-compat total, governanca rule #7 = Estrategia A).
  - 1.8.2 (26/07/2026): F8 Onda 8.7 (matriz de conformidade) - bug-789: no ramo
    USE_FIREDAC de GetTableNamesFromDriver, o SQLite passa a introspecionar por SQL
    directo a sqlite_master (type='table', exclui sqlite_%) em vez da metadata do
    TFDConnection - que nao devolve tabelas de um ficheiro SQLite de rede (SMB) /
    criadas por outro driver, deixando TableExists cego e o Sync a repetir CREATE
    TABLE ("already exists"). Mesmo padrao ja usado para o Firebird acima (SQL vs
    metadata do driver); reference-aligned (FontesReferencias/Database usa
    sqlite_master para views). FireDAC passou de 4/7 -> 7/7 (dcc32+dcc64) na matriz.
  - 1.8.1 (22/07/2026): TConnection ganha FDllDownloadUrl + IConnection.
    DllDownloadUrl(AValue)/DllDownloadUrl (override opcional do URL de download
    de Commons.DllBootstrap; fecha o gap real encontrado na auditoria F7 - a
    Onda 7.0 tinha decidido "URL CDN do DllBootstrap - LE do Parameters" mas o
    campo nunca chegara a Connections.pas). FromConfig copia LData.
    DllDownloadUrl -> FDllDownloadUrl; GetConnectionData exporta de volta;
    ValidateRequiredDll passa a usar FDllDownloadUrl (quando setado) em vez de
    sempre TDllBootstrap.EnsureDlls (URL default), via DownloadAndExtract
    explicito. Validado end-to-end: smoke_parameters_db ganhou o teste "seam
    perfil dllDownloadUrl" (perfil->TConnectionData->FromConfig->IConnection),
    93/93 verde.
  - 1.8.0 (19/07/2026): UniDAC+SQL Server — remover Prepared:=True antes do
    BindParams (ExecuteQuery/ExecuteCommand parametrizados) e tipar TUniParam
    a partir do VarType (evita sql_variant→varchar no LogMigration/EnsureTable).
  - 1.7.0 (12/07/2026): Onda 5.2 (bug-167) - InvalidateDriverMetadata: DDL em
    ExecuteCommand limpa o metadata cache do Zeos (DbcConnection.GetMetadata.
    ClearCache) para o catalogo ser relido sem reconnect.
  - 1.6.0 (10/07/2026): Etapa A1 do broker (Onda 4.3, Prompt Connections) —
    Memory DataSets: ExecuteQuery (simples e parametrizado, 4 engines) passa a
    executar a query física, copiar para um dataset em memória totalmente
    DESCONECTADO (TBufDataset no FPC; TClientDataSet estático/MidasLib no
    Delphi) via novo helper CreateDisconnectedCopy, libertar a física e
    devolver só a memória — sem cursor vivo preso à conexão, seguro no
    cruzamento de threads Worker→solicitante. Mesma assinatura (TDataSet);
    ftAutoInc normalizado para ftInteger no container.
  - 1.5.0 (09/07/2026): validação multi-engine, parte SQLdb (FPC) — o branch
    nunca tinha compilado/corrido; 7 fixes de paridade: (1) TParam.Value em vez
    de AsVariant (fcl-db não tem AsVariant); (2) wiring da DLL cliente via
    TSQLDBLibraryLoader (sqldblib) por tipo de banco + AppendPathEnv das deps
    ANTES do LoadLibrary — sem isto o fcl-db procurava dblib.dll/libmysql.dll/
    libpq.dll no PATH/System32; (3) MySQL usa o cliente clássico libmysql.dll
    (GetVendorLibPathMySQLAlt) — o fcl-db não injeta mysql_options e o
    libmariadb 3.4.x exige TLS (raiz do bug-120) — mais
    SkipLibraryVersionCheck; (4) TSQLConnection.Transaction passa a ser
    atribuída (GetTableNames/GetDBInfo do sqldb ficavam sem transação);
    (5) GetTableNamesFromDriver era stub vazio — implementado via
    TSQLConnection.GetTableNames; (6) transações: BeginTransaction fecha a
    transação implícita activa; ExecuteCommand emula autocommit com
    CommitRetaining/RollbackRetaining fora de transação explícita (um comando
    falhado abortava o bloco inteiro no PostgreSQL); (7) Ping real por SELECT
    dialect-aware (antes devolvia só IsConnected) e GetServerVersion via
    GetServerVersionBySQL. Cobertura SQLdb: OK=172 FAIL=0.
  - 1.4.0 (09/07/2026): validação multi-engine — 3 fixes de paridade no branch
    FireDAC, descobertos pelo sweep de cobertura com USE_FIREDAC: (1) Firebird
    sem wiring de VendorLib (carregava fbclient antigo do sistema e o servidor
    rejeitava 'connection rejected by remote interface') — VendorLib versionado
    (GetVendorLibPath) aplicado via TFDPhysFBDriverLink global, pois no FireDAC
    VendorLib é configuração do driver e Params é ignorado; (2) SQL Server via ODBC Driver
    18+ falhava na validação do certificado — ODBCAdvanced
    TrustServerCertificate=yes; (3) GetServerVersion devolvia stub vazio —
    novo GetServerVersionBySQL (SQL portável por DatabaseType), usado também
    pelo branch SQLdb.
  - 1.3.0 (09/07/2026): tratamento SSL Zeos 8 para MySQL/MariaDB (fix do owner,
    fecha bug-120): em ConfigureNativeConnection, para dtMySQL, Properties
    recebem MYSQL_OPT_SSL_VERIFY_SERVER_CERT=0, MYSQL_OPT_SSL_ENFORCE=0, ssl=0
    e skip-ssl=1 — desliga a exigencia de TLS do libmariadb Connector/C 3.4.8
    (que passou a impor SSL por default). Validado contra MariaDB 10.11.18 real:
    cobertura total OK=174 FAIL=0 (9/9 perfis ligam, ciclo CRUD/DDL incluido).
  - 1.2.0 (09/07/2026): Onda 4.2c (cobertura total IConnection) — 2 kernel-fixes
    descobertos pelo sweep, aditivos, sem mudança de contrato. (1) Ping (branch
    Zeos) usava 'SELECT 1' hardcoded — inválido em Firebird (exige FROM
    RDB$DATABASE) e devolvia False mesmo conectado; passa a escolher o SQL por
    DatabaseType. (2) GetColumnNames/GetTableStructure (e os builders
    GetColumnsSQLForType/GetTableStructureSQLForType) forçavam schema default
    'public' para TODOS os bancos — no SQL Server o filtro s.name='public'
    devolvia 0 colunas/campos (tabelas em dbo) e o branch sem-schema nunca era
    atingido; default 'public' passa a aplicar-se apenas a dtPostgreSQL.
  - 1.1.0 (08/07/2026): Onda 4.2b (teste real Connections). (1) FirebirdVersion
    (3 overloads) — seleção da versão do cliente fbclient.dll por subpasta
    dll/<plat>/FireBird/2-3-4-5; wiring em ConfigureZeosLibraryLocation,
    ValidateRequiredDll e IsRequiredDllFound (agora inclui dtFireBird no set de
    DLL obrigatória → cobre auto-download). (2) LoadFromJSON/LoadFromIniFile
    passam a aceitar chaves camelCase (databaseType/dllBasePath/firebirdVersion)
    além das snake_case — corrige o desalinhamento que fazia FDatabaseType ficar
    dtNone e cair no protocolo sqlite (falsos positivos nos bancos SQL). Aditivo.
  - 1.0.0 (06/07/2026): absorvido de ProvidersORM v2.3.0 (FileVersion origem
    1.0.22) para src/Modulos/Connections (Onda 4.1) com os cortes/substituições
    descritos acima. Paridade de métodos públicos de IConnection preservada.
  Changelog (fonte v2.3.0, resumo):
  - 1.0.0 (03/02/2026): Versão inicial.
  - 1.0.1 (01/02/2026): Conexão real com Zeos (Connect, Ping, Execute*) - Fase 1.
  - 1.0.2 (01/02/2026): Suporte a todos os engines (UniDAC, FireDAC, Zeos, SQLdb).
  - 1.0.3 (22/02/2026): Validação de DLL obrigatória antes de Connect (PostgreSQL, MySQL, SQL Server).
  - 1.0.4 (22/02/2026): IsRequiredDllFound movida para esta unit (competencia da Connections).
  - 1.0.5 (22/02/2026): Attributers no Connections (USE_ATTRIBUTES): FromClass/LoadFromClass com [Connections].
  - 1.0.6 (22/02/2026): Eventos OnBeforeConnect, OnAfterConnect, OnBeforeDisconnect, OnAfterDisconnect, OnConnectionError.
  - 1.0.7..1.0.16 (26/02/2026-27/02/2026): GetSchemaNames/GetColumnNames/GetDatabaseNames/GetTableNames/GetTableStructure (metadados multi-banco).
  - 1.0.17 (28/02/2026): LoadFromJSON implementado — parse JSON (fpjson/FPC, System.JSON/Delphi).
  - 1.0.18 (12/03/2026): Ecossistema unificado: SetExceptions, SetLogger (injeção opcional); log de erro em Connect. (removido nesta absorção - ver acima)
  - 1.0.19 (03/04/2026): Overloads parametrizados — ExecuteQuery/ExecuteCommand/ExecuteScalar com array of Variant; helpers privados BindParams e NormalizeParams (multi-engine).
  - 1.0.20 (03/07/2026): FIX Zeos+params — NormalizeParams passa a preservar :paramN no Zeos (nativo); BindParams Zeos usa ParamByName('paramN') como os demais engines.
  - 1.0.21 (03/07/2026): FIX ExecuteCommand(parametrizado) — query LOCAL por chamada em todos os engines.
  - 1.0.22 (03/07/2026): ExecuteQuery Zeos — removido Prepare explícito antes do bind; BindParams + Open.
  ============================================================================= }

unit Connections;


{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}
interface

{$I ../../ORM.Defines.inc}

Uses
{$IF DEFINED(FPC)}
  SysUtils, Classes, Variants, DB, FmtBCD, fpjson, jsonparser, TypInfo, IniFiles,
  BufDataset, // Memory DataSets desconectados (Etapa A1 do broker)
  Commons.IOUtils, Commons.StrUtils, // TFile, TPath, IfThen (FPC)
{$ELSE}
  System.SysUtils, System.Classes, System.Variants, Data.DB, Data.FmtBCD,
  System.JSON, System.DateUtils, System.StrUtils, System.TypInfo,
  System.IniFiles,
  System.IOUtils, // Para TPath e operações de arquivo (não existe no FPC)
  Datasnap.DBClient, MidasLib, // TClientDataSet estático (Memory DataSets, Etapa A1)
{$ENDIF}
  // Engines de banco de dados (independente)
{$IF DEFINED(USE_UNIDAC)}
  Uni, UniProvider, PostgreSQLUniProvider, SQLServerUniProvider,
  MySQLUniProvider,
  InterBaseUniProvider, SQLiteUniProvider, AccessUniProvider,
  ODBCUniProvider,        // SQL Anywhere - vertente ODBC (driver ODBC do SO) + dtODBC
  SQLAnywhereUniProvider, // SQL Anywhere - vertente NATIVA (fork CSL 10.3.0A, dbcapi.dll)
{$ELSE}
{$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)}
  // FireDAC - Units essenciais para registro de factories e drivers
  FireDAC.Stan.Def, // Registra todas as factories do FireDAC (OBRIGATÓRIO)
  FireDAC.DApt, // Data Access Pattern - necessário para TFDQuery (OBRIGATÓRIO)

  // FireDAC - Core
  FireDAC.Stan.Intf, // Interfaces padrão
  FireDAC.Stan.Option, // Opções de configuração
  FireDAC.Stan.Error, // Tratamento de erros
  FireDAC.Stan.Param, // Parâmetros SQL
  FireDAC.Stan.Pool, // Pool de conexões
  FireDAC.Stan.Async, // Operações assíncronas
  FireDAC.Stan.ExprFuncs, // Funções de expressão

  // FireDAC - Data Access
  FireDAC.DatS, // Data Structures
  FireDAC.DApt.Intf, // Interfaces do Data Access Pattern

  // FireDAC - Physical Layer (Drivers)
  FireDAC.Phys.Intf, // Interfaces físicas
  FireDAC.Phys, // Implementação física base

  // FireDAC - Driver Definitions (registram os drivers)
  FireDAC.Phys.PGDef, // PostgreSQL driver definition
  FireDAC.Phys.MSSQLDef, // SQL Server driver definition
  FireDAC.Phys.MySQLDef, // MySQL driver definition
  FireDAC.Phys.FBDef, // FireBird driver definition
  FireDAC.Phys.SQLiteDef, // SQLite driver definition
  FireDAC.Phys.MSAccDef, // Access driver definition
  FireDAC.Phys.ASADef, // SQL Anywhere driver definition (F5 Onda 10)

  // FireDAC - Driver Implementations (implementações dos drivers)
  FireDAC.Phys.PG, // PostgreSQL implementation
  FireDAC.Phys.MSSQL, // SQL Server implementation
  FireDAC.Phys.MySQL, // MySQL implementation
  FireDAC.Phys.FB, // FireBird implementation
  FireDAC.Phys.SQLite, // SQLite implementation
  FireDAC.Phys.MSAcc, // Access implementation
  FireDAC.Phys.ASA, // SQL Anywhere implementation (F5 Onda 10) - TFDPhysASADriver
                     // herda de TFDPhysODBCDriverBase (ASA e ODBC-based no
                     // FireDAC, ao contrario do Zeos que e nativo asa_capi)

  // FireDAC - Componentes
  FireDAC.Comp.Client, // TFDConnection
  FireDAC.Comp.DataSet, // TFDQuery, TFDStoredProc, etc.

  // FireDAC - UI (opcional, mas recomendado)
  FireDAC.UI.Intf, // Interfaces de UI
  FireDAC.VCLUI.Wait, // Wait cursor para VCL
  FireDAC.Comp.UI, // Componentes de UI (TFDGUIxWaitCursor)

  // FireDAC - SQLite Wrapper (para SQLite)
  FireDAC.Phys.SQLiteWrapper.Stat,

  // FireDAC - IBBase (base para InterBase/FireBird)
  FireDAC.Phys.IBBase,
{$ELSE}
{$IF DEFINED(USE_ZEOS)}
  ZConnection, ZDataset, ZAbstractRODataset, ZSqlMetadata, ZDbcIntfs, //bug-1171: ZAbstractRODataset = ancestral comum de TZQuery e TZReadOnlyQuery
{$ELSE} {$IF DEFINED(USE_SQLDB)}
  sqldb, sqldblib, sqlite3conn, pqconnection, mysql51conn, mssqlconn,
  ibconnection, odbcconn, // odbcconn: fallback SQL Anywhere + Access (Jet/ACE)
  sqlanywhereconn,        // F5 Fase 4: conector NATIVO SQL Anywhere (dbcapi, sem ODBC)
{$ENDIF} {$ENDIF} {$ENDIF} {$ENDIF}

  Commons.Types,
  Commons.Consts,
  Commons.DynamicLibrary, // AppendPathEnv (substitui AddDllDirectoryToPath local)
  Commons.DllBootstrap,   // download on-demand da DLL cliente (AutoDownloadDlls -> EnsureDlls)

  Connections.Interfaces,
  Connections.FromConfig, // seam DI de FromConfig (IConnectionConfigureLoader)
  Exceptions.Base
{$IFDEF USE_LOGGERS}
  , Loggers.Interfaces  // F8 Onda 8.6 -- SetLogger (reintroduzido, ver header)
  , Loggers.NullLogger  // default zero-overhead do FLogger
{$ENDIF}
{$IFDEF USE_DATABASE}
  , Exceptions.Database     // F5-FU.3 - EDatabaseObjectLockedException / ERR_DATABASE_OBJECT_LOCKED (lock DDL Firebird em NO WAIT)
  , Commons.Database.Consts // F5-FU.3 - DB_ERR_OBJECT_LOCKED_MSG
{$ENDIF}
{$IFDEF USE_ATTRIBUTES}
  , Attributers.Connections // ConnectionAttribute (não Attributers.Providers.Interfaces - essa
                             // depende de Database.Table.Interfaces, wave posterior)
  , {$IFDEF FPC}Rtti{$ELSE}System.Rtti{$ENDIF}
{$ENDIF};

type
  { Disparado quando uma exceção ocorre durante Connect; Sender = TConnection, E = exceção. }
  TConnectionErrorEvent = procedure(Sender: TObject; E: Exception) of object;

  TConnection = class(TInterfacedObject, IConnection)
  strict private
    FOnBeforeConnect   : TNotifyEvent;
    FOnAfterConnect    : TNotifyEvent;
    FOnBeforeDisconnect: TNotifyEvent;
    FOnAfterDisconnect : TNotifyEvent;
    FOnConnectionError : TConnectionErrorEvent;
{$IFDEF USE_LOGGERS}
    FLogger          : ILogger; // F8 Onda 8.6 - default TNullLogger (zero overhead)
{$ENDIF}
    FConnected       : Boolean;
    FInTransaction   : Boolean;
    FLockWait        : Boolean; // F5-FU.3 - True (default) = WAIT (atual); False = NO WAIT no DDL Firebird (falha-rapido catchable)
    FEngine          : TDatabaseEngine;
    FDatabaseType    : TDatabaseTypes;
    FDatabaseTypeStr : string;
    FFirebirdVersion : TFirebirdVersion; // versão do cliente fbclient.dll (subpasta FireBird/N)
    FServerName      : string; // ENG do SQL Anywhere - nome logico do servidor (F5 Onda 10)
    FSQLAnywhereDriver : string; // vertente SA sob UniDAC: 'native' (dbcapi.dll, default) | 'odbc'
    FHost            : string;
    FPort            : Integer;
    FUsername        : string;
    FPassword        : string;
    FDatabase        : string;
    FSchema          : string;
    FConfigFilePath  : string;
    FDllBasePath     : string;
    FDllDownloadUrl  : string;
    FAutoDownloadDlls: Boolean;
    procedure CreateNativeConnection;
    procedure ConfigureNativeConnection;
    procedure InvalidateDriverMetadata(const ASQL: string);
    procedure DestroyNativeConnection;
    procedure LoadFromIniFile(const AFilePath, ASection: string);
    procedure LoadFromJSON(const AJSON: string);
    procedure ValidateRequiredDll;
    {$IFDEF USE_ATTRIBUTES}
    procedure LoadFromClass(const AClass: TClass);
    {$ENDIF}
    procedure GetTableNamesFromDriver(var AResult: TStringArray);
    {$IF DEFINED(USE_ZEOS)}
    { F5 Onda 10 - SQL Anywhere: o Zeos (ZDbcASAMetadata) e o TZQuery editavel
      dependem de stored procedures de catalogo JDBC (sp_jdbc_tables/columns)
      que podem nao existir/sem permissao no banco alvo (SQLCODE=-265, provado
      contra servidor real). TZReadOnlyQuery evita essa resolucao "smart" -
      usado pelos SQL de catalogo directo (GetTableNamesFromDriver, GetColumnNames,
      GetTableStructure) quando FDatabaseType = dtSQLAnywhere. }
    function ExecuteQueryZeosReadOnly(const ASQL: string): TDataSet;
    {$ENDIF}
    { Helpers para overloads parametrizados }
    procedure BindParams(AQuery: TObject; const AParams: array of Variant);
    function  NormalizeParams(const ASQL: string): string;
    {$IF (DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)) OR DEFINED(USE_SQLDB)}
    function  GetServerVersionBySQL: string;
    {$ENDIF}
  private
    FConnection  : TObject;
    FQuery       : TObject;
    FExecQuery   : TObject;
    {$IF DEFINED(USE_SQLDB)}
    FTransaction : TObject;
    {$ENDIF}
  public
    constructor Create;
    destructor Destroy; override;

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
    { Download on-demand da DLL cliente quando falta (opt-in; so baixa se nao existir). }
    function AutoDownloadDlls(const AValue: Boolean): IConnection; overload;
    function AutoDownloadDlls: Boolean; overload;
    { Override opcional do URL de download (Commons.DllBootstrap); '' = usa
      Commons.Consts.DEFAULT_DLL_DOWNLOAD_URL. Populado via perfil Parameters
      (dll_download_url/dllDownloadUrl, F7 Onda 7.0) ou setado diretamente. }
    function DllDownloadUrl(const AValue: string): IConnection; overload;
    function DllDownloadUrl: string; overload;
    { Versão do cliente Firebird (fbclient.dll): subpasta dll/<plat>/FireBird/2-3-4-5. }
    function FirebirdVersion(const AValue: TFirebirdVersion): IConnection; overload;
    function FirebirdVersion(const AValue: string): IConnection; overload;
    function FirebirdVersion: TFirebirdVersion; overload;
    { ServerName (ENG) do SQL Anywhere - distinto do Host/IP. F5 Onda 10. }
    function ServerName(const AValue: string): IConnection; overload;
    function ServerName: string; overload;
    { Vertente SQL Anywhere sob UniDAC: 'native' (dbcapi.dll, default) ou 'odbc'. }
    function SQLAnywhereDriver(const AValue: string): IConnection; overload;
    function SQLAnywhereDriver: string; overload;
    { Retorna True se o tipo de banco nao exige DLL ou se a DLL esperada existe. }
    function IsRequiredDllFound: Boolean; overload;
    { Sem criar instancia: TConnection.IsRequiredDllFound('E:\CSL\ORM\dll', 'PostgreSQL') }
    class function IsRequiredDllFound(const ADllBasePath: string; ADatabaseType: TDatabaseTypes; AFirebirdVersion: TFirebirdVersion = fb50): Boolean; overload;
    class function IsRequiredDllFound(const ADllBasePath, ADatabaseTypeName: string): Boolean; overload;

    function FromIniFile(const AFilePath, ASection: string): IConnection;
    function FromConfig: IConnection;
    function FromJSON(const AJSON: string): IConnection;
    {$IFDEF USE_ATTRIBUTES}
    function FromClass(const AClass: TClass): IConnection;
    {$ENDIF}

    function Connect: IConnection;
    function Disconnect: IConnection;
    function IsConnected: Boolean;
    function Ping: Boolean;

    function ExecuteQuery(const ASQL: string): TDataSet; overload;
    function ExecuteCommand(const ASQL: string): Integer; overload;
    function ExecuteScalar(const ASQL: string): Variant; overload;
    function ExecuteQuery(const ASQL: string;
      const AParams: array of Variant): TDataSet; overload;
    function ExecuteCommand(const ASQL: string;
      const AParams: array of Variant): Integer; overload;
    function ExecuteScalar(const ASQL: string;
      const AParams: array of Variant): Variant; overload;

    function BeginTransaction: IConnection;
    function Commit: IConnection;
    function Rollback: IConnection;
    function InTransaction: Boolean;
    function LockWait(const AValue: Boolean): IConnection; overload; // F5-FU.3
    function LockWait: Boolean; overload;                            // F5-FU.3

    function GetServerVersion: string;
    function GetClientVersion: string;

    function GetConnectionData: TConnectionData;
    function GetTableNames(const ASchema: string = ''): TStringArray;
    function GetDatabaseNames: TStringArray;
    function GetSchemaNames(const ADatabase: string = ''): TStringArray;
    function GetColumnNames(const ATableName: string; const ASchema: string = ''): TStringArray;
    function GetTableStructure(const ATableName: string; const ASchema: string = ''): TArray<TDatabaseFields>;

    { Eventos (apenas na classe; não expostos na interface). Disparo conforme planejamento no skill. }
    property OnBeforeConnect   : TNotifyEvent read FOnBeforeConnect   write FOnBeforeConnect;
    property OnAfterConnect    : TNotifyEvent read FOnAfterConnect    write FOnAfterConnect;
    property OnBeforeDisconnect: TNotifyEvent read FOnBeforeDisconnect write FOnBeforeDisconnect;
    property OnAfterDisconnect : TNotifyEvent read FOnAfterDisconnect write FOnAfterDisconnect;
    property OnConnectionError : TConnectionErrorEvent read FOnConnectionError write FOnConnectionError;

{$IFDEF USE_LOGGERS}
    { F8 Onda 8.6 - reintroduz SetLogger (removido na absorcao F4, ver header
      do ficheiro). Apenas na classe, mesmo padrao dos eventos acima (nao faz
      parte do contrato IConnection). Piggyback nos hooks Connect/Disconnect
      ja existentes - nenhum ponto de chamada novo. Default = TNullLogger. }
    function SetLogger(const ALogger: ILogger): IConnection;
{$ENDIF}

    class function New: IConnection;
  end;

implementation

uses
  Commons.Diagnostics;

{$HINTS OFF}
{ AddDllDirectoryToPath local removida (Onda 4.1) - substituída por
  Commons.DynamicLibrary.AppendPathEnv nos call-sites de ConfigureNativeConnection. }

{$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)}
var
  // No FireDAC, VendorLib e configuracao do DRIVER (nao da conexao):
  // Params.Values['VendorLib'] e ignorado; o caminho certo e o driver link
  // fisico. Instancia global do processo, criada on-demand no configure do
  // Firebird e libertada na finalization.
  FDFBDriverLink: TFDPhysFBDriverLink = nil;
{$ENDIF}

{$IF DEFINED(USE_SQLDB)}
var
  // Loader oficial do fcl-db (sqldblib) que aponta cada connector a DLL
  // cliente do repo (paridade com Zeos LibLocation / FireDAC VendorLib).
  // Sem ele o fcl-db procura dblib.dll/libmysql.dll/libpq.dll/fbclient.dll
  // no exe-dir/System32/PATH (nomes que nem existem no dll/ empacotado, ex.
  // libsybdb-5.dll e libmariadb.dll). Um loader por tipo; vive ate ao fim do
  // processo (o binding fica inicializado).
  GSqldbLoaders: array[TDatabaseTypes] of TSQLDBLibraryLoader;

procedure EnsureSqldbVendorLib(const ADatabaseType: TDatabaseTypes;
  const ALibPath, AConnectionType: string);
begin
  if (ALibPath = '') or not FileExists(ALibPath) then
    Exit;
  if GSqldbLoaders[ADatabaseType] <> nil then
    Exit; // binding ja inicializado para este tipo
  GSqldbLoaders[ADatabaseType] := TSQLDBLibraryLoader.Create(nil);
  GSqldbLoaders[ADatabaseType].ConnectionType := AConnectionType;
  GSqldbLoaders[ADatabaseType].LibraryName := ExpandFileName(ALibPath);
  GSqldbLoaders[ADatabaseType].LoadLibrary;
end;

procedure FreeSqldbLoaders;
var
  T: TDatabaseTypes;
begin
  for T := Low(TDatabaseTypes) to High(TDatabaseTypes) do
    FreeAndNil(GSqldbLoaders[T]);
end;
{$ENDIF}

{$IF DEFINED(USE_ZEOS)}

function GetZeosAccessConnectionString(const AFilePath: string;
  const APassword: string): string;
var
  LExt: string;
begin
  // Em processo 64-bit: Jet.OLEDB.4.0 nao existe no Windows (apenas 32-bit). Usar sempre ACE em 64-bit.
  // Em 32-bit: Jet para .mdb, ACE para .accdb.
  LExt := LowerCase(ExtractFileExt(AFilePath));
  if (LExt = '.accdb') or (SizeOf(Pointer) = 8) then
    Result := 'Provider=Microsoft.ACE.OLEDB.12.0;Data Source=' + AFilePath
  else
    Result := 'Provider=Microsoft.Jet.OLEDB.4.0;Data Source=' + AFilePath;
  if Trim(APassword) <> '' then
    Result := Result + ';Jet OLEDB:Database Password=' + APassword;
end;
{$ENDIF}

{$IFDEF USE_DATABASE}
{ F5-FU.3 - deteccao do erro de LOCK do Firebird POR PADRAO DE MENSAGEM: cada
  engine lanca um tipo proprio (Zeos EZSQLException / FireDAC EFDDBEngineException
  / UniDAC EIBError / SQLdb EIBDatabaseError) e NENHUM e capturado por tipo no
  projeto - a correspondencia por substring da mensagem/GDS e a via portavel.
  Cobre 'lock conflict on no wait transaction' + 'deadlock' + 'object ... in use'
  + os GDS codes equivalentes. So consultado quando LockWait=False (NO WAIT). }
function IsFirebirdLockError(const AMessage: string): Boolean;
var
  L: string;
begin
  L := LowerCase(AMessage);
  Result := (Pos('lock conflict', L) > 0)      // isc_lock_conflict (no wait)
         or (Pos('deadlock', L) > 0)           // isc_deadlock
         or (Pos('in use', L) > 0)             // "object ZZZ is in use" / "Table ... in use"
         or (Pos('335544345', L) > 0)          // isc_lock_conflict
         or (Pos('335544336', L) > 0)          // isc_deadlock
         or (Pos('335544475', L) > 0)          // isc_no_meta_update (metadata update bloqueado)
         or (Pos('335544510', L) > 0);         // isc_lock_timeout
end;
{$ENDIF}

{ TConnection }

constructor TConnection.Create;
begin
  inherited Create;
  FConnected := False;
  FInTransaction := False;
  FLockWait := True; // F5-FU.3 - WAIT por defeito (comportamento atual inalterado)
  FEngine := teNone;
  FDatabaseType := dtNone;
  FFirebirdVersion := DEFAULT_FIREBIRD_VERSION;
  FPort := -1;
  FConnection := nil;
  FQuery := nil;
  FExecQuery := nil;
  {$IF DEFINED(USE_SQLDB)}
  FTransaction := nil;
  {$ENDIF}
{$IFDEF USE_LOGGERS}
  FLogger := TNullLogger.New;
{$ENDIF}
{$IF DEFINED(USE_UNIDAC)}
  FEngine := teUnidac;
{$ELSE} {$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)}
  FEngine := teFireDAC;
{$ELSE} {$IF DEFINED(USE_ZEOS)}
  FEngine := teZeos;
{$ELSE} {$IF DEFINED(USE_SQLDB)}
  FEngine := teSQLdb;
{$ENDIF}
{$ENDIF}
{$ENDIF}
{$ENDIF}
end;

destructor TConnection.Destroy;
begin
  if FConnected then
    Disconnect;
  DestroyNativeConnection;
  inherited;
end;

{$IFDEF USE_LOGGERS}
function TConnection.SetLogger(const ALogger: ILogger): IConnection;
begin
  if Assigned(ALogger) then
    FLogger := ALogger
  else
    FLogger := TNullLogger.New;
  Result := Self;
end;
{$ENDIF}

procedure TConnection.CreateNativeConnection;
{$IF DEFINED(USE_UNIDAC)}
var
  LConn: TUniConnection;
  LQry: TUniQuery;
{$ENDIF}
{$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)}
var
  LConn: TFDConnection;
  LQry: TFDQuery;
{$ENDIF}
{$IF DEFINED(USE_ZEOS)}
var
  LConn: ZConnection.TZConnection;
  LQry: ZDataset.TZQuery;
{$ENDIF}
{$IF DEFINED(USE_SQLDB)}
var
  LConn: TSQLConnection;
  LTrans: TSQLTransaction;
  LQry: TSQLQuery;
{$ENDIF}
begin
  if Assigned(FConnection) then
    Exit;
{$IF DEFINED(USE_UNIDAC)}
  LConn := TUniConnection.Create(nil);
  LConn.LoginPrompt := False;
  { AutoCommit por-engine. Default do UniDAC = True (mantido em PostgreSQL/MySQL/
    SQL Server/SQL Anywhere - o standalone auto-committa). SO' o Firebird usa False:
    com AutoCommit=True o provider FB committava o INSERT IMEDIATAMENTE mesmo DENTRO
    de um BeginTransaction explicito (o Rollback nao desfazia nada); com False as
    transacoes explicitas funcionam e a persistencia STANDALONE fica garantida pelos
    POST-commit em ExecuteCommand/ExecuteQuery (gated 'not FInTransaction'), que
    tambem fecham a read-transaction do FB que bloquearia o DDL seguinte. (O commit
    do DML preparado do SQL Anywhere - bug-884 - e' ADICIONAL, no ExecuteCommand.)
    Gate a FB porque AutoCommit=False no PostgreSQL reabria o problema "active
    transaction" no DROP->CREATE da mesma sessao. }
  LConn.AutoCommit := (FDatabaseType <> dtFireBird);
  FConnection := LConn;
  LQry := TUniQuery.Create(nil);
  LQry.Connection := LConn;
  FQuery := LQry;
  LQry := TUniQuery.Create(nil);
  LQry.Connection := LConn;
  FExecQuery := LQry;
{$ENDIF}
{$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)}
  LConn := TFDConnection.Create(nil);
  LConn.LoginPrompt := False;
  FConnection := LConn;
  LQry := TFDQuery.Create(nil);
  LQry.Connection := LConn;
  FQuery := LQry;
  LQry := TFDQuery.Create(nil);
  LQry.Connection := LConn;
  FExecQuery := LQry;
{$ENDIF}
{$IF DEFINED(USE_ZEOS)}
  LConn := ZConnection.TZConnection.Create(nil);
  LConn.LoginPrompt := False;
  LConn.AutoCommit := True;
  FConnection := LConn;
  LQry := ZDataset.TZQuery.Create(nil);
  LQry.Connection := LConn;
  FQuery := LQry;
  LQry := ZDataset.TZQuery.Create(nil);
  LQry.Connection := LConn;
  FExecQuery := LQry;
{$ENDIF}
{$IF DEFINED(USE_SQLDB)}
  case FDatabaseType of
    dtSQLite:
      LConn := TSQLite3Connection.Create(nil);
    dtPostgreSQL:
      LConn := TPQConnection.Create(nil);
    dtMySQL:
      begin
        LConn := TMySQL51Connection.Create(nil);
        // libmariadb reporta versao de cliente diferente de 5.1; o check
        // estrito do fcl-db rejeitaria a conexao (a API C usada e compativel).
        TMySQL51Connection(LConn).SkipLibraryVersionCheck := True;
      end;
    dtSQLServer:
      LConn := TMSSQLConnection.Create(nil);
    dtFireBird:
      LConn := TIBConnection.Create(nil);
    dtAccess:
      // Access nao tem conector nativo na FCL -> ODBC (driver Jet/ACE do SO).
      // best-effort: depende do "Microsoft Access Driver" instalado (32/64).
      LConn := TODBCConnection.Create(nil);
    dtSQLAnywhere:
      // F5 Fase 4 - vertente NATIVA (dbcapi.dll, default) via TSQLAnywhereConnection
      // (conector do projeto, USE_SQLDB-only), cumprindo o objetivo do owner "SQLdb
      // FPC sem ODBC"; 'odbc' mantem o fallback TODBCConnection ('SQL Anywhere 17').
      if SameText(FSQLAnywhereDriver, 'odbc') then
        LConn := TODBCConnection.Create(nil)
      else
        LConn := TSQLAnywhereConnection.Create(nil);
  else
    LConn := TSQLite3Connection.Create(nil);
  end;
  FConnection := LConn;
  LTrans := TSQLTransaction.Create(nil);
  TSQLTransaction(LTrans).Database := TSQLConnection(LConn);
  // Sem esta atribuicao o GetTableNames/GetDBInfo do sqldb (que usa a
  // Transaction default da conexao) fica sem transacao e devolve vazio.
  TSQLConnection(LConn).Transaction := TSQLTransaction(LTrans);
  FTransaction := LTrans;
  LQry := TSQLQuery.Create(nil);
  TSQLQuery(LQry).Database := TSQLConnection(LConn);
  TSQLQuery(LQry).Transaction := TSQLTransaction(LTrans);
  FQuery := LQry;
  LQry := TSQLQuery.Create(nil);
  TSQLQuery(LQry).Database := TSQLConnection(LConn);
  TSQLQuery(LQry).Transaction := TSQLTransaction(LTrans);
  FExecQuery := LQry;
  if FDatabaseType = dtAccess then
  begin
    // O driver ODBC Jet do Access (32-bit) NAO suporta SQLPrimaryKeys (IM001);
    // o ORM faz o seu proprio DML dialect-aware e nao usa os server index defs,
    // por isso desligar UsePrimaryKeyAsKey evita a chamada UpdateServerIndexDefs
    // no open do SELECT (unica dependencia de SQLPrimaryKeys neste caminho).
    TSQLQuery(FQuery).UsePrimaryKeyAsKey := False;
    TSQLQuery(FExecQuery).UsePrimaryKeyAsKey := False;
  end;
{$ENDIF}
end;

procedure TConnection.ConfigureNativeConnection;
var
  LProtocol: string;
  LDatabasePath: string;
  {$IF DEFINED(USE_UNIDAC) OR (DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC))}
  LDriverName: string;
  {$ENDIF}
  {$IF DEFINED(USE_SQLDB)}
  LAltPath: string;
  {$ENDIF}
  LPath: string;
  LExePath: string;
begin
  if not Assigned(FConnection) then
    Exit;
  LExePath := ExtractFilePath(ParamStr(0));
  LDatabasePath := Trim(FDatabase);
  if (LDatabasePath <> '') and (Pos(PathDelim, LDatabasePath) > 0) and
    ((Length(LDatabasePath) < 2) or ((Length(LDatabasePath) >= 2) and
    (LDatabasePath[1] <> PathDelim) and (LDatabasePath[2] <> ':'))) then
    LDatabasePath := ExpandFileName
      (IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
      LDatabasePath)
  else
    LDatabasePath := FDatabase;
{$IF DEFINED(USE_UNIDAC)}
  LDriverName := TDatabaseTypeClass.ConfigString(FDatabaseType);
  if (LDriverName <> '') and (LDriverName <> 'None') then
    TUniConnection(FConnection).ProviderName := LDriverName
  else
    TUniConnection(FConnection).ProviderName := 'PostgreSQL';
  if (FDatabaseType = dtSQLite) or (FDatabaseType = dtAccess) then
  begin
    TUniConnection(FConnection).Server := '';
    TUniConnection(FConnection).Port := 0;
    TUniConnection(FConnection).Username := FUsername;
    TUniConnection(FConnection).Password := FPassword;
    TUniConnection(FConnection).Database := LDatabasePath;
    if FDatabaseType = dtSQLite then
    begin
      // UniDAC LiteProvider NAO cria o .db por default (ao contrario de Zeos/
      // FireDAC/SQLdb, que criam) -> "unable to open database file" quando o
      // ficheiro ainda nao existe (ex.: bootstrap zero-config do Parameters, que
      // cria um config.db novo). ForceCreateDatabase=True cria-o. ClientLibrary
      // aponta a sqlite3.dll versionada do repo (paridade com FireBird/SA abaixo).
      TUniConnection(FConnection).SpecificOptions.Values['SQLite.ForceCreateDatabase'] := 'True';
      // bug-792/967 (06/08/2026): SQLiteUniProvider.DefValLockingMode = lmExclusive
      // (LiteConstsUni.pas) - cada ligacao agarra um lock exclusivo do ficheiro
      // inteiro apos o 1o INSERT/UPDATE, e uma 2a ligacao concorrente (ex.:
      // verificacao de persistencia) falha com EUniError 'database is locked' -
      // especialmente sobre SQLite de rede/SMB. lmNormal usa o locking POSIX
      // normal do SQLite (multiplos leitores, escalada de lock so' durante o
      // proprio commit) - resolve sem custo conhecido para o uso deste projecto
      // (sem multiplos processos a escrever em simultaneo no mesmo ficheiro).
      // Validado isolado (spike_bug792_sqlite_lockingmode.dpr, ficheiro proprio
      // descartavel na mesma partilha SMB): lmExclusive reproduz o lock,
      // lmNormal resolve.
      TUniConnection(FConnection).SpecificOptions.Values['SQLite.LockingMode'] := 'lmNormal';
      LPath := GetVendorLibPath(FDllBasePath, LExePath, dtSQLite);
      if FileExists(LPath) then
        TUniConnection(FConnection).SpecificOptions.Values['SQLite.ClientLibrary'] := LPath;
    end;
  end
  else
  begin
    TUniConnection(FConnection).Server := FHost;
    TUniConnection(FConnection).Port := FPort;
    TUniConnection(FConnection).Username := FUsername;
    TUniConnection(FConnection).Password := FPassword;
    TUniConnection(FConnection).Database := FDatabase;
  end;
  if FDatabaseType = dtSQLAnywhere then
  begin
    if SameText(FSQLAnywhereDriver, 'odbc') then
    begin
      // VERTENTE ODBC: provider 'ODBC' generico (ConfigString) + driver ODBC
      // "SQL Anywhere 17" do SO. Comportamento historico - o UniDAC stock nao
      // tinha provider SA nativo. Preservado para compat/fallback.
      TUniConnection(FConnection).SpecificOptions.Values['ODBC.ConnectString'] :=
        'Driver={SQL Anywhere 17};ENG=' + FServerName +
        ';LINKS=tcpip(host=' + FHost + ';port=' + IntToStr(FPort) + ')' +
        ';DBN=' + FDatabase + ';UID=' + FUsername + ';PWD=' + FPassword;
    end
    else
    begin
      // VERTENTE NATIVA (default): fork CSL 10.3.0A - provider 'SQL Anywhere'
      // conecta direto por dbcapi.dll (sem ODBC). Sobrepoe o ProviderName 'ODBC'
      // generico setado acima (ConfigString). ServerName=ENG; ClientLibrary
      // aponta o dbcapi.dll versionado no repo (dll/<plat>/SQLAnywhere).
      TUniConnection(FConnection).ProviderName := 'SQL Anywhere';
      TUniConnection(FConnection).SpecificOptions.Values['SQL Anywhere.ServerName'] := FServerName;
      LPath := GetVendorLibPath(FDllBasePath, LExePath, dtSQLAnywhere);
      if FileExists(LPath) then
        TUniConnection(FConnection).SpecificOptions.Values['SQL Anywhere.ClientLibrary'] := LPath;
    end;
  end;
  if FDatabaseType = dtFireBird then
  begin
    // Cliente fbclient versionado do repo (dll/<plat>/FireBird/N/fbclient.dll);
    // sem isto o InterBase provider do UniDAC carrega o fbclient default do
    // sistema (versao antiga) e o servidor FB5 devolve "connection rejected by
    // remote interface". Aponta o cliente fb5 do repo (padrao do SA acima).
    LPath := GetVendorLibPath(FDllBasePath, LExePath, dtFireBird, FFirebirdVersion);
    if FileExists(LPath) then
      TUniConnection(FConnection).SpecificOptions.Values['InterBase.ClientLibrary'] := LPath;
  end;
{$ENDIF}
{$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)}
  // IMPORTANTE: VendorLib e PATH devem ser configurados ANTES de DriverName (como em Parameters.Database).
  // O FireDAC tenta carregar a DLL ao definir DriverName; dependências (libintl, libeay32, etc.) precisam do PATH.
  if FDatabaseType = dtMySQL then
  begin
    LPath := GetVendorLibPath(FDllBasePath, LExePath, dtMySQL);
    if FileExists(LPath) then
      TFDConnection(FConnection).Params.Values['VendorLib'] := LPath
    else
    begin
      LPath := GetVendorLibPathMySQLAlt(FDllBasePath, LExePath);
      if FileExists(LPath) then
        TFDConnection(FConnection).Params.Values['VendorLib'] := LPath
      else
        TFDConnection(FConnection).Params.Values['VendorLib'] := GetVendorLibPath(FDllBasePath, LExePath, dtMySQL);
    end;
    LPath := GetVendorLibDirectory(FDllBasePath, LExePath, dtMySQL);
    if (LPath <> '') and (TFDConnection(FConnection).Params.Values['VendorLib'] <> '') then
      AppendPathEnv(LPath);
  end
  else if FDatabaseType = dtPostgreSQL then
  begin
    LPath := GetVendorLibPath(FDllBasePath, LExePath, dtPostgreSQL);
    if LPath <> '' then
    begin
      TFDConnection(FConnection).Params.Values['VendorLib'] := LPath;
      LPath := GetVendorLibDirectory(FDllBasePath, LExePath, dtPostgreSQL);
      if LPath <> '' then
        AppendPathEnv(LPath);
    end;
  end
  else if FDatabaseType = dtFireBird then
  begin
    // Cliente Firebird versionado do repo (dll/<plat>/FireBird/N/fbclient.dll);
    // sem isto o FireDAC carrega o fbclient default do sistema (antigo) e o
    // servidor rejeita: 'connection rejected by remote interface'. VendorLib
    // tem de ir no DRIVER LINK (Params.Values['VendorLib'] e ignorado).
    LPath := GetVendorLibPath(FDllBasePath, LExePath, dtFireBird, FFirebirdVersion);
    if FileExists(LPath) then
    begin
      if FDFBDriverLink = nil then
        FDFBDriverLink := TFDPhysFBDriverLink.Create(nil);
      FDFBDriverLink.VendorLib := ExpandFileName(LPath);
      LPath := GetVendorLibDirectory(FDllBasePath, LExePath, dtFireBird, FFirebirdVersion);
      if LPath <> '' then
        AppendPathEnv(LPath);
    end;
    { F5-FU.3 - NO WAIT no FireDAC: a versao RAD ativa nao expoe TxOptions.LockWait
      (a config TPB nowait far-se-ia via TxOptions.Params, sintaxe nao validada
      empiricamente) - fica como FOLLOW-UP por engine. Fallback = disciplina de
      ciclo de vida de R1.3 (ja em producao). A CONVERSAO do erro de lock em
      EDatabaseObjectLockedException (ExecuteCommand) funciona na mesma se o driver
      devolver o erro; o NO WAIT verificado vive no Zeos (engine default). }
  end
  else if FDatabaseType = dtSQLAnywhere then
  begin
    // SQL Anywhere no FireDAC: driver 'ASA' (FireDAC.Phys.ASA) HERDA de
    // TFDPhysODBCDriverBase - e ODBC-based internamente, ao contrario do Zeos
    // (nativo asa_capi/dbcapi.dll). VendorLib aqui aponta para o DRIVER ODBC
    // (dbodbc17.dll), nao o cliente nativo. Confirmado no source
    // FireDAC.Phys.ASA.pas (16/07); NAO validado em runtime nesta sessao
    // (driver so foi registado, connect ainda nao testado com estes params).
    LPath := GetVendorLibDirectory(FDllBasePath, LExePath, dtSQLAnywhere);
    if LPath <> '' then
    begin
      LPath := IncludeTrailingPathDelimiter(LPath) + 'dbodbc17.dll';
      if FileExists(LPath) then
      begin
        TFDConnection(FConnection).Params.Values['VendorLib'] := LPath;
        AppendPathEnv(ExtractFilePath(LPath));
      end;
    end;
  end;

  LDriverName := TDatabaseTypeClass.ConfigString(FDatabaseType);
  if (LDriverName <> '') and (LDriverName <> 'None') then
    TFDConnection(FConnection).DriverName := LDriverName
  else
    TFDConnection(FConnection).DriverName := 'PG';
  if (FDatabaseType = dtSQLite) or (FDatabaseType = dtAccess) then
  begin
    TFDConnection(FConnection).Params.Values['Database'] := LDatabasePath;
    TFDConnection(FConnection).Params.Values['Server'] := '';
    TFDConnection(FConnection).Params.Values['Port'] := '';
    TFDConnection(FConnection).Params.Values['User_Name'] := FUsername;
    TFDConnection(FConnection).Params.Values['Password'] := FPassword;
  end
  else
  begin
    TFDConnection(FConnection).Params.Values['Server'] := FHost;
    TFDConnection(FConnection).Params.Values['Port'] := IntToStr(FPort);
    TFDConnection(FConnection).Params.Values['User_Name'] := FUsername;
    TFDConnection(FConnection).Params.Values['Password'] := FPassword;
    TFDConnection(FConnection).Params.Values['Database'] := FDatabase;
    if FDatabaseType = dtSQLServer then
      // ODBC Driver 18+ liga com Encrypt=yes por default e valida o certificado
      // do servidor; confiar no certificado (equivalente ao FreeTDS/Zeos, que
      // nao verifica). Sem isto: 'A cadeia de certificacao ... nao e de confianca'.
      TFDConnection(FConnection).Params.Values['ODBCAdvanced'] := 'TrustServerCertificate=yes';
    if FDatabaseType = dtSQLAnywhere then
    begin
      // ASA (ODBC-based no FireDAC): 'Server' (S_FD_ConnParam_Common_Server)
      // mapeia para a terminologia PROPRIA do SQL Anywhere - "Server" ali
      // significa o NOME DO MOTOR (ENG), nao o host/IP (legado Sybase; SQL
      // Anywhere fala de "server name" para o motor com muito antes de TCP/IP
      // ser o transporte principal) - por isso FHost estava errado ali.
      // Host/porta vao SO via LINKS=tcpip (ODBCAdvanced); testado 16/07:
      // "HOST and LINKS cannot both be specified" confirmou que ha conflito
      // se os dois caminhos coexistirem.
      TFDConnection(FConnection).Params.Values['Server'] := FServerName;
      TFDConnection(FConnection).Params.Values['Port'] := '';
      TFDConnection(FConnection).Params.Values['ODBCAdvanced'] :=
        'LINKS=tcpip(host=' + FHost + ';port=' + IntToStr(FPort) + ')';
    end;
  end;
{$ENDIF}
{$IF DEFINED(USE_ZEOS)}
  if FDatabaseType = dtAccess then
  begin
    ZConnection.TZConnection(FConnection).Protocol := 'ado';
    ZConnection.TZConnection(FConnection).Database :=
      GetZeosAccessConnectionString(LDatabasePath, FPassword);
    ZConnection.TZConnection(FConnection).HostName := '';
    ZConnection.TZConnection(FConnection).Port := 0;
    ZConnection.TZConnection(FConnection).User := '';
    ZConnection.TZConnection(FConnection).Password := '';
  end
  else
  begin
    LProtocol := TDatabaseTypeClass.ConfigString(FDatabaseType);
    if LProtocol = 'None' then
      LProtocol := 'sqlite';
    { bug-820 SIDESTEP (opt-in SQLAnywhereDriver='freetds'): ligar o SQL Anywhere
      via FreeTDS db-lib (protocolo Zeos 'sybase' -> provider dpSybase -> TDS 5.0
      automatico por-login em ZDbcDbLib, sem env-var/estado global) em vez do
      'asa_capi' nativo (dbcapi.dll win64 corrompe o heap - bug-820). O SA suporta
      TDS 5.0 nativo e o FreeTDS trata-o (login.c is_sql_anywhere). Reutiliza o MESMO
      libsybdb-5.dll do SQL Server (regra #14; LibLocation abaixo). Default continua
      'native' (asa_capi) - puramente ADITIVO. }
    if (FDatabaseType = dtSQLAnywhere) and SameText(FSQLAnywhereDriver, 'freetds') then
      LProtocol := 'sybase';
    ZConnection.TZConnection(FConnection).Protocol := LProtocol;
    ZConnection.TZConnection(FConnection).HostName := FHost;
    ZConnection.TZConnection(FConnection).Port := FPort;
    ZConnection.TZConnection(FConnection).User := FUsername;
    ZConnection.TZConnection(FConnection).Password := FPassword;
    if FDatabaseType = dtSQLite then
      ZConnection.TZConnection(FConnection).Database := LDatabasePath
    else if (FDatabaseType = dtSQLAnywhere) and SameText(FSQLAnywhereDriver, 'freetds') then
      // SA via TDS: sem USE/DBN (o listener jConnect/TDS no host:port serve a DB default)
      ZConnection.TZConnection(FConnection).Database := ''
    else
      ZConnection.TZConnection(FConnection).Database := FDatabase;
  end;
  if (FDatabaseType = dtSQLAnywhere) and not SameText(FSQLAnywhereDriver, 'freetds') then
    // ENG (ServerName) - SQL Anywhere distingue o nome logico do servidor do
    // Host/IP (ex.: ENG=srvcontabil, Host=10.0.74.3). Validado no spike
    // src/tests/spike_sqlanywhere.dpr contra servidor real (F5 Onda 10).
    // So no caminho asa_capi nativo: via FreeTDS/TDS (freetds) o host:port routeia,
    // ENG nao se aplica (o TDS liga ao listener jConnect no porto).
    ZConnection.TZConnection(FConnection).Properties.Values['ENG'] := FServerName;
{$IF DEFINED(FPC)}
  if FDatabaseType = dtFireBird then
    // Zeos-FPC (bug-612): o caminho default do protocolo 'firebird' usa a API
    // OO/CORBA nova do Firebird (ZDbcFirebird/ZPlainFirebird - binding "cloop"
    // com pointer-punning de vtable C++), que da EInvalidPointer no Connect com
    // FPC 3.3.1. Forcar a C API legacy (isc_attach_database, caminho
    // TZInterbase6Connection) - estavel em FPC. No Delphi mantem-se o OO API.
    ZConnection.TZConnection(FConnection).Properties.Values['FirebirdAPI'] := 'legacy';
{$ENDIF}
  { F5-FU.3 - NO WAIT opt-in (Zeos, ambos compiladores): com LockWait(False), a
    transaccao Firebird aborta de imediato ao encontrar um lock em vez de esperar
    (isc_tpb_nowait e lido por TZInterbaseFirebirdConnection.GenerateTPB das
    Properties; default e isc_tpb_wait). Default LockWait=True -> nao toca nada
    (comportamento atual). O lock resultante e convertido em
    EDatabaseObjectLockedException no ExecuteCommand (gate USE_DATABASE). }
  if (not FLockWait) and (FDatabaseType = dtFireBird) then
    if ZConnection.TZConnection(FConnection).Properties.IndexOf('isc_tpb_nowait') < 0 then
      ZConnection.TZConnection(FConnection).Properties.Add('isc_tpb_nowait');
// === TRATAMENTO DE SSL PARA ZEOS 8.0 (MARIADB) ===
  if FDatabaseType = dtMySQL then
  begin
    // Desativa a verificação e a exigência de certificado SSL nativa do MariaDB
    ZConnection.TZConnection(FConnection).Properties.Values['MYSQL_OPT_SSL_VERIFY_SERVER_CERT'] := '0';
    ZConnection.TZConnection(FConnection).Properties.Values['MYSQL_OPT_SSL_ENFORCE'] := '0';

    // Parâmetros genéricos de fallback
    ZConnection.TZConnection(FConnection).Properties.Values['ssl'] := '0';
    ZConnection.TZConnection(FConnection).Properties.Values['skip-ssl'] := '1';
  end;
//  if FDatabaseType = dtMySQL then
//  begin
    // Desabilita o requerimento de SSL/TLS para conexões MySQL/MariaDB
//    ZConnection.TZConnection(FConnection).Properties.Values['ssl-mode'] := 'DISABLED';
//  end
//  else if FDatabaseType = dtPostgreSQL then // Caso você utilize Postgres futuramente
//  begin
    // Para PostgreSQL, a chave e o valor mudam um pouquinho
//    ZConnection.TZConnection(FConnection).Properties.Values['sslmode'] := 'disable';
//  end;

//  if FDatabaseType = dtMySQL then
//  begin
//    ZConnection.TZConnection(FConnection).Properties.Values['MYSQL_SSL'] := '0';
//    ZConnection.TZConnection(FConnection).Properties.Values['UseSSL'] := '0';
//  end;
  if (FDatabaseType = dtSQLServer) and ({$IF DEFINED(FPC)} True {$ELSE} False
    {$ENDIF}) and ({$IF DEFINED(WINDOWS)} True {$ELSE} False {$ENDIF}) then
  begin
    // FPC+Windows (bug-612): o dblib/FreeTDS do Zeos falha ([20011] Maximum
    // DBPROCESSes). Usar o protocolo ODBC do Zeos com o driver nativo da
    // Microsoft. TRES requisitos (todos obrigatorios): (1) trocar o Protocol
    // (antes so a Database era trocada e o dblib recebia a string ODBC);
    // (2) connection string COMPLETA (UID/PWD embutidos) com Host/User limpos;
    // (3) NAO setar LibLocation (guard abaixo) - senao o Zeos carrega a DLL do
    // FreeTDS como se fosse o odbc32 -> simbolos ODBC nil -> EAccessViolation.
    ZConnection.TZConnection(FConnection).Protocol := 'odbc_w';
    // Driver 18 (instalado em 32 E 64-bit nesta stack; o 17 so existia em
    // 64-bit -> IM002 no exe win32). O 18 muda o default para Encrypt=yes ->
    // 'Encrypt=no' explicito (servidor de teste sem certificado confiavel).
    // UID/PWD NAO vao na string: o Zeos odbc_w anexa-os a partir das
    // propriedades User/Password (limpa-los dava "Login failed for user ''").
    ZConnection.TZConnection(FConnection).Database :=
      'Driver={ODBC Driver 18 for SQL Server};Server=' + FHost + ',' +
      IntToStr(FPort) + ';Database=' + FDatabase +
      ';Encrypt=no;MARS_Connection=yes';
    ZConnection.TZConnection(FConnection).HostName := '';
    ZConnection.TZConnection(FConnection).Port := 0;
  end;
  // Respeita DllBasePath para carregar libpq/libmariadb/libmysql/FreeTDS (como Parameters.Database ConfigureZeosLibraryLocation)
  LPath := GetVendorLibPath(FDllBasePath, LExePath, FDatabaseType, FFirebirdVersion);
  { bug-820 sidestep: SA via FreeTDS carrega o libsybdb-5.dll do SQL Server (regra
    #14 - a MESMA DLL cliente FreeTDS ja usada para o mssql), nao o dbcapi.dll nativo. }
  if (FDatabaseType = dtSQLAnywhere) and SameText(FSQLAnywhereDriver, 'freetds') then
    LPath := GetVendorLibPath(FDllBasePath, LExePath, dtSQLServer, FFirebirdVersion);
  {$IF DEFINED(FPC) AND DEFINED(WINDOWS)}
  if FDatabaseType = dtSQLServer then
    // requisito (3) do bloco ODBC acima: LibLocation vazio -> o plain driver
    // odbc_w usa o odbc32.dll default do Windows (Driver Manager), que
    // despacha para o msodbcsql17 via a connection string.
    LPath := '';
  {$ENDIF}
  if LPath <> '' then
  begin
    if FDatabaseType = dtMySQL then
    begin
      if FileExists(LPath) then
        ZConnection.TZConnection(FConnection).LibLocation := LPath
      else
      begin
        LPath := GetVendorLibPathMySQLAlt(FDllBasePath, LExePath);
        if FileExists(LPath) then
          ZConnection.TZConnection(FConnection).LibLocation := LPath;
      end;
    end
    else if FileExists(LPath) then
      ZConnection.TZConnection(FConnection).LibLocation := LPath;
    LPath := GetVendorLibDirectory(FDllBasePath, LExePath, FDatabaseType, FFirebirdVersion);
    { bug-820 sidestep: SA via FreeTDS -> pasta FreeTDS no PATH (deps libiconv/
      libssl/libcrypto vivem ao lado do libsybdb-5.dll), nao a pasta SQLAnywhere. }
    if (FDatabaseType = dtSQLAnywhere) and SameText(FSQLAnywhereDriver, 'freetds') then
      LPath := GetVendorLibDirectory(FDllBasePath, LExePath, dtSQLServer, FFirebirdVersion);
    if (LPath <> '') and (ZConnection.TZConnection(FConnection).LibLocation <> '') then
      AppendPathEnv(LPath);
  end
  else
    ZConnection.TZConnection(FConnection).LibLocation := '';
{$ENDIF}
{$IF DEFINED(USE_SQLDB)}
  // Dependencias (libiconv/libcrypto/ICU) no PATH ANTES do LoadLibrary — o
  // Windows nao procura deps na pasta da propria DLL carregada por path.
  LPath := GetVendorLibDirectory(FDllBasePath, LExePath, FDatabaseType, FFirebirdVersion);
  if LPath <> '' then
    AppendPathEnv(LPath);
  // DLL cliente do repo ANTES do primeiro connect (loader por tipo).
  LPath := GetVendorLibPath(FDllBasePath, LExePath, FDatabaseType, FFirebirdVersion);
  case FDatabaseType of
    dtSQLite:     EnsureSqldbVendorLib(dtSQLite, LPath, 'SQLite3');
    dtPostgreSQL: EnsureSqldbVendorLib(dtPostgreSQL, LPath, 'PostgreSQL');
    dtMySQL:
      begin
        // fcl-db nao permite injectar mysql_options (SSL): com libmariadb
        // 3.4.x o connect falha por TLS enforce (mesma raiz do bug-120, sem
        // as Properties do Zeos como escape). Preferir o cliente classico
        // libmysql.dll (5.6, nao exige SSL); fallback ao nome default.
        LAltPath := GetVendorLibPathMySQLAlt(FDllBasePath, LExePath);
        if FileExists(LAltPath) then
          EnsureSqldbVendorLib(dtMySQL, LAltPath, 'MySQL 5.1')
        else
          EnsureSqldbVendorLib(dtMySQL, LPath, 'MySQL 5.1');
      end;
    dtSQLServer:  EnsureSqldbVendorLib(dtSQLServer, LPath, 'MSSQLServer');
    dtFireBird:   EnsureSqldbVendorLib(dtFireBird, LPath, 'Firebird');
  else
    ; // dtAccess/dtNone: sem DLL empacotada
  end;
  with TSQLConnection(FConnection) do
  begin
    if FDatabaseType = dtSQLite then
    begin
      DatabaseName := LDatabasePath;
      HostName := '';
      Username := FUsername;
      Password := FPassword;
    end
    else if FDatabaseType = dtAccess then
    begin
      // Access via ODBC DSN-less: DBQ = ficheiro .mdb; DatabaseName vazio (senao
      // o odbcconn mapeia-o para DSN). Driver Jet/ACE do SO (best-effort 32/64);
      // .mdb protegido por senha (ex.: config.mdb) via PWD.
      DatabaseName := '';
      HostName := '';
      Username := FUsername;
      Password := FPassword;
      // Nome do driver ODBC depende da plataforma (caveat Jet/ACE): em 32-bit o
      // que ha' e' o Jet classico 'Microsoft Access Driver (*.mdb)'; em 64-bit e'
      // o ACE 'Microsoft Access Driver (*.mdb, *.accdb)'. best-effort: se o driver
      // correspondente nao estiver instalado -> N/A documentado (nao FAIL de codigo).
      {$IFDEF WIN64}
      TODBCConnection(FConnection).Driver := 'Microsoft Access Driver (*.mdb, *.accdb)';
      {$ELSE}
      TODBCConnection(FConnection).Driver := 'Microsoft Access Driver (*.mdb)';
      {$ENDIF}
      Params.Values['DBQ'] := LDatabasePath;
      if FPassword <> '' then
        Params.Values['PWD'] := FPassword;
    end
    else
    begin
      HostName := FHost;
      DatabaseName := FDatabase;
      Username := FUsername;
      Password := FPassword;
      if FDatabaseType in [dtPostgreSQL, dtMySQL, dtSQLServer] then
        Params.Values['port'] := IntToStr(FPort);
      if FDatabaseType = dtSQLAnywhere then
      begin
        if SameText(FSQLAnywhereDriver, 'odbc') then
        begin
          // VERTENTE ODBC (fallback): TODBCConnection + driver ODBC 'SQL Anywhere
          // 17' do SO. HostName e IGNORADO por este connector; DatabaseName mapeia
          // DSN (vazio p/ ligacao DSN-less); DBN/ENG/Host via Params (raw).
          DatabaseName := '';
          TODBCConnection(FConnection).Driver := 'SQL Anywhere 17';
          Params.Values['DBN'] := FDatabase;
          Params.Values['ENG'] := FServerName;
          // "Host=ip:porta" flat evita LINKS=tcpip(host=..;port=..) que o driver
          // ODBC SA nao respeita bem entre chavetas (erro nativo -832).
          Params.Values['Host'] := FHost + ':' + IntToStr(FPort);
        end
        else
        begin
          // VERTENTE NATIVA (default): TSQLAnywhereConnection via dbcapi.dll (sem
          // ODBC). HostName=FHost, DatabaseName=DBN, User/Password ja setados
          // acima; falta ENG (ServerName), Port e a ClientLibrary versionada do
          // repo (dll/<plat>/SQLAnywhere/dbcapi.dll). Mesma semantica do UniDAC.
          Params.Values['ServerName'] := FServerName;
          Params.Values['Port'] := IntToStr(FPort);
          if FileExists(LPath) then
            TSQLAnywhereConnection(FConnection).ClientLibrary := LPath;
        end;
      end;
    end;
  end;
{$ENDIF}
end;

procedure TConnection.DestroyNativeConnection;
begin
{$IF DEFINED(USE_UNIDAC)}
  if Assigned(FExecQuery) then
  begin
    try
      if TUniQuery(FExecQuery).Active then
        TUniQuery(FExecQuery).Close;
    except
      { 15.3/T10: engolir aqui e deliberado (cleanup best-effort),
        mas nao pode ser MUDO - sem rasto o defeito fica invisivel. }
      on E: Exception do
        TraceSwallowed('TConnection.DestroyNativeConnection', 'cleanup best-effort', E);
    end;
    TUniQuery(FExecQuery).Free;
    FExecQuery := nil;
  end;
  if Assigned(FQuery) then
  begin
    try
      if TUniQuery(FQuery).Active then
        TUniQuery(FQuery).Close;
    except
      { 15.3/T10: engolir aqui e deliberado (cleanup best-effort),
        mas nao pode ser MUDO - sem rasto o defeito fica invisivel. }
      on E: Exception do
        TraceSwallowed('TConnection.DestroyNativeConnection', 'cleanup best-effort', E);
    end;
    TUniQuery(FQuery).Free;
    FQuery := nil;
  end;
  if Assigned(FConnection) then
  begin
    try
      if TUniConnection(FConnection).Connected then
        TUniConnection(FConnection).Disconnect;
    except
      { 15.3/T10: engolir aqui e deliberado (cleanup best-effort),
        mas nao pode ser MUDO - sem rasto o defeito fica invisivel. }
      on E: Exception do
        TraceSwallowed('TConnection.DestroyNativeConnection', 'cleanup best-effort', E);
    end;
    TUniConnection(FConnection).Free;
    FConnection := nil;
  end;
{$ENDIF}
{$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)}
  if Assigned(FExecQuery) then
  begin
    try
      if TFDQuery(FExecQuery).Active then
        TFDQuery(FExecQuery).Close;
    except
      { 15.3/T10: engolir aqui e deliberado (cleanup best-effort),
        mas nao pode ser MUDO - sem rasto o defeito fica invisivel. }
      on E: Exception do
        TraceSwallowed('TConnection.DestroyNativeConnection', 'cleanup best-effort', E);
    end;
    TFDQuery(FExecQuery).Free;
    FExecQuery := nil;
  end;
  if Assigned(FQuery) then
  begin
    try
      if TFDQuery(FQuery).Active then
        TFDQuery(FQuery).Close;
    except
      { 15.3/T10: engolir aqui e deliberado (cleanup best-effort),
        mas nao pode ser MUDO - sem rasto o defeito fica invisivel. }
      on E: Exception do
        TraceSwallowed('TConnection.DestroyNativeConnection', 'cleanup best-effort', E);
    end;
    TFDQuery(FQuery).Free;
    FQuery := nil;
  end;
  if Assigned(FConnection) then
  begin
    try
      if TFDConnection(FConnection).Connected then
        TFDConnection(FConnection).Connected := False;
    except
      { 15.3/T10: engolir aqui e deliberado (cleanup best-effort),
        mas nao pode ser MUDO - sem rasto o defeito fica invisivel. }
      on E: Exception do
        TraceSwallowed('TConnection.DestroyNativeConnection', 'cleanup best-effort', E);
    end;
    TFDConnection(FConnection).Free;
    FConnection := nil;
  end;
{$ENDIF}
{$IF DEFINED(USE_ZEOS)}
  if Assigned(FExecQuery) then
  begin
    try
      if ZDataset.TZQuery(FExecQuery).Active then
        ZDataset.TZQuery(FExecQuery).Close;
    except
      { 15.3/T10: engolir aqui e deliberado (cleanup best-effort),
        mas nao pode ser MUDO - sem rasto o defeito fica invisivel. }
      on E: Exception do
        TraceSwallowed('TConnection.DestroyNativeConnection', 'cleanup best-effort', E);
    end;
    ZDataset.TZQuery(FExecQuery).Free;
    FExecQuery := nil;
  end;
  if Assigned(FQuery) then
  begin
    try
      if ZDataset.TZQuery(FQuery).Active then
        ZDataset.TZQuery(FQuery).Close;
    except
      { 15.3/T10: engolir aqui e deliberado (cleanup best-effort),
        mas nao pode ser MUDO - sem rasto o defeito fica invisivel. }
      on E: Exception do
        TraceSwallowed('TConnection.DestroyNativeConnection', 'cleanup best-effort', E);
    end;
    ZDataset.TZQuery(FQuery).Free;
    FQuery := nil;
  end;
  if Assigned(FConnection) then
  begin
    try
      if ZConnection.TZConnection(FConnection).Connected then
        ZConnection.TZConnection(FConnection).Disconnect;
    except
      { 15.3/T10: engolir aqui e deliberado (cleanup best-effort),
        mas nao pode ser MUDO - sem rasto o defeito fica invisivel. }
      on E: Exception do
        TraceSwallowed('TConnection.DestroyNativeConnection', 'cleanup best-effort', E);
    end;
    ZConnection.TZConnection(FConnection).Free;
    FConnection := nil;
  end;
{$ENDIF}
{$IF DEFINED(USE_SQLDB)}
  if Assigned(FExecQuery) then
  begin
    try
      if TSQLQuery(FExecQuery).Active then
        TSQLQuery(FExecQuery).Close;
    except
      { 15.3/T10: engolir aqui e deliberado (cleanup best-effort),
        mas nao pode ser MUDO - sem rasto o defeito fica invisivel. }
      on E: Exception do
        TraceSwallowed('TConnection.DestroyNativeConnection', 'cleanup best-effort', E);
    end;
    TSQLQuery(FExecQuery).Free;
    FExecQuery := nil;
  end;
  if Assigned(FQuery) then
  begin
    try
      if TSQLQuery(FQuery).Active then
        TSQLQuery(FQuery).Close;
    except
      { 15.3/T10: engolir aqui e deliberado (cleanup best-effort),
        mas nao pode ser MUDO - sem rasto o defeito fica invisivel. }
      on E: Exception do
        TraceSwallowed('TConnection.DestroyNativeConnection', 'cleanup best-effort', E);
    end;
    TSQLQuery(FQuery).Free;
    FQuery := nil;
  end;
  if Assigned(FTransaction) then
  begin
    TSQLTransaction(FTransaction).Free;
    FTransaction := nil;
  end;
  if Assigned(FConnection) then
  begin
    try
      if TSQLConnection(FConnection).Connected then
        TSQLConnection(FConnection).Connected := False;
    except
      { 15.3/T10: engolir aqui e deliberado (cleanup best-effort),
        mas nao pode ser MUDO - sem rasto o defeito fica invisivel. }
      on E: Exception do
        TraceSwallowed('TConnection.DestroyNativeConnection', 'cleanup best-effort', E);
    end;
    TSQLConnection(FConnection).Free;
    FConnection := nil;
  end;
{$ENDIF}
end;

procedure TConnection.LoadFromIniFile(const AFilePath, ASection: string);
var
  LIni: TIniFile;
  LVal: string;
begin
  if (Trim(AFilePath) = '') or not FileExists(AFilePath) then
    Exit;
  LIni := TIniFile.Create(AFilePath);
  try
    LVal := Trim(LIni.ReadString(ASection, 'host', ''));
    if LVal <> '' then
      FHost := LVal;
    LVal := Trim(LIni.ReadString(ASection, 'port', ''));
    if LVal <> '' then
      FPort := StrToIntDef(LVal, -1);
    LVal := Trim(LIni.ReadString(ASection, 'username', ''));
    if LVal <> '' then
      FUsername := LVal;
    LVal := Trim(LIni.ReadString(ASection, 'password', ''));
    if LVal <> '' then
      FPassword := LVal;
    LVal := Trim(LIni.ReadString(ASection, 'database', ''));
    if LVal <> '' then
      FDatabase := LVal;
    LVal := Trim(LIni.ReadString(ASection, 'schema', ''));
    if LVal <> '' then
      FSchema := LVal;
    LVal := Trim(LIni.ReadString(ASection, 'database_type', ''));
    if LVal = '' then
      LVal := Trim(LIni.ReadString(ASection, 'databaseType', ''));
    if LVal <> '' then
    begin
      FDatabaseTypeStr := LVal;
      FDatabaseType := TDatabaseTypeClass.FromString(LVal);
    end;
    LVal := Trim(LIni.ReadString(ASection, 'database_dll', ''));
    if LVal = '' then
      LVal := Trim(LIni.ReadString(ASection, 'dllBasePath', ''));
    if LVal <> '' then
      FDllBasePath := LVal;
    LVal := Trim(LIni.ReadString(ASection, 'firebird_version', ''));
    if LVal = '' then
      LVal := Trim(LIni.ReadString(ASection, 'firebirdVersion', ''));
    if LVal <> '' then
      FirebirdVersion(LVal);
    { ServerName/ENG do SQL Anywhere (F5 Onda 10) - snake_case e camelCase. }
    LVal := Trim(LIni.ReadString(ASection, 'server_name', ''));
    if LVal = '' then
      LVal := Trim(LIni.ReadString(ASection, 'serverName', ''));
    if LVal <> '' then
      FServerName := LVal;
    { Vertente SQL Anywhere sob UniDAC (dual-driver): 'native' (default) | 'odbc'. }
    LVal := Trim(LIni.ReadString(ASection, 'sql_anywhere_driver', ''));
    if LVal = '' then
      LVal := Trim(LIni.ReadString(ASection, 'sqlAnywhereDriver', ''));
    if LVal <> '' then
      FSQLAnywhereDriver := LowerCase(LVal);
  finally
    LIni.Free;
  end;
end;

procedure TConnection.LoadFromJSON(const AJSON: string);
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
  LVal: string;
begin
  if Trim(AJSON) = '' then
    Exit;
  LData := GetJSON(AJSON);
  if not Assigned(LData) or not (LData is TJSONObject) then
  begin
    if Assigned(LData) then
      LData.Free;
    Exit;
  end;
  LObj := TJSONObject(LData);
  try
    LVal := Trim(LObj.Get('host', ''));
    if LVal <> '' then
      FHost := LVal;
    if Assigned(LObj.Find('port')) then
      FPort := LObj.Get('port', FPort);
    LVal := Trim(LObj.Get('username', ''));
    if LVal <> '' then
      FUsername := LVal;
    LVal := Trim(LObj.Get('password', ''));
    if LVal <> '' then
      FPassword := LVal;
    LVal := Trim(LObj.Get('database', ''));
    if LVal <> '' then
      FDatabase := LVal;
    LVal := Trim(LObj.Get('schema', ''));
    if LVal <> '' then
      FSchema := LVal;
    LVal := Trim(LObj.Get('database_type', ''));
    if LVal = '' then
      LVal := Trim(LObj.Get('databaseType', ''));
    if LVal <> '' then
    begin
      FDatabaseTypeStr := LVal;
      FDatabaseType := TDatabaseTypeClass.FromString(LVal);
    end;
    LVal := Trim(LObj.Get('database_dll', ''));
    if LVal = '' then
      LVal := Trim(LObj.Get('dllBasePath', ''));
    if LVal <> '' then
      FDllBasePath := LVal;
    LVal := Trim(LObj.Get('firebird_version', ''));
    if LVal = '' then
      LVal := Trim(LObj.Get('firebirdVersion', ''));
    if LVal <> '' then
      FirebirdVersion(LVal);
    { ServerName/ENG do SQL Anywhere (F5 Onda 10) - snake_case e camelCase. }
    LVal := Trim(LObj.Get('server_name', ''));
    if LVal = '' then
      LVal := Trim(LObj.Get('serverName', ''));
    if LVal <> '' then
      FServerName := LVal;
    { Vertente SQL Anywhere sob UniDAC (dual-driver): 'native' (default) | 'odbc'. }
    LVal := Trim(LObj.Get('sql_anywhere_driver', ''));
    if LVal = '' then
      LVal := Trim(LObj.Get('sqlAnywhereDriver', ''));
    if LVal <> '' then
      FSQLAnywhereDriver := LowerCase(LVal);
  finally
    LObj.Free;
  end;
end;
{$ELSE}
var
  LVal: TJSONValue;
  LObj: TJSONObject;
  LStr: string;
begin
  if Trim(AJSON) = '' then
    Exit;
  LVal := TJSONObject.ParseJSONValue(AJSON);
  if not Assigned(LVal) or not (LVal is TJSONObject) then
  begin
    if Assigned(LVal) then
      LVal.Free;
    Exit;
  end;
  LObj := TJSONObject(LVal);
  try
    LStr := Trim(LObj.GetValue<string>('host', ''));
    if LStr <> '' then
      FHost := LStr;
    if Assigned(LObj.GetValue('port')) then
      FPort := LObj.GetValue<Integer>('port', FPort);
    LStr := Trim(LObj.GetValue<string>('username', ''));
    if LStr <> '' then
      FUsername := LStr;
    LStr := Trim(LObj.GetValue<string>('password', ''));
    if LStr <> '' then
      FPassword := LStr;
    LStr := Trim(LObj.GetValue<string>('database', ''));
    if LStr <> '' then
      FDatabase := LStr;
    LStr := Trim(LObj.GetValue<string>('schema', ''));
    if LStr <> '' then
      FSchema := LStr;
    LStr := Trim(LObj.GetValue<string>('database_type', ''));
    if LStr = '' then
      LStr := Trim(LObj.GetValue<string>('databaseType', ''));
    if LStr <> '' then
    begin
      FDatabaseTypeStr := LStr;
      FDatabaseType := TDatabaseTypeClass.FromString(LStr);
    end;
    LStr := Trim(LObj.GetValue<string>('database_dll', ''));
    if LStr = '' then
      LStr := Trim(LObj.GetValue<string>('dllBasePath', ''));
    if LStr <> '' then
      FDllBasePath := LStr;
    LStr := Trim(LObj.GetValue<string>('firebird_version', ''));
    if LStr = '' then
      LStr := Trim(LObj.GetValue<string>('firebirdVersion', ''));
    if LStr <> '' then
      FirebirdVersion(LStr);
    { ServerName/ENG do SQL Anywhere (F5 Onda 10) - snake_case e camelCase. }
    LStr := Trim(LObj.GetValue<string>('server_name', ''));
    if LStr = '' then
      LStr := Trim(LObj.GetValue<string>('serverName', ''));
    if LStr <> '' then
      FServerName := LStr;
    { Vertente SQL Anywhere sob UniDAC (dual-driver): 'native' (default) | 'odbc'. }
    LStr := Trim(LObj.GetValue<string>('sql_anywhere_driver', ''));
    if LStr = '' then
      LStr := Trim(LObj.GetValue<string>('sqlAnywhereDriver', ''));
    if LStr <> '' then
      FSQLAnywhereDriver := LowerCase(LStr);
  finally
    LObj.Free;
  end;
end;
{$ENDIF}

function TConnection.Engine(const AValue: TDatabaseEngine): IConnection;
begin
  FEngine := AValue;
  Result := Self;
end;

function TConnection.Engine: TDatabaseEngine;
begin
  Result := FEngine;
end;

function TConnection.DatabaseType(const AValue: TDatabaseTypes): IConnection;
begin
  FDatabaseType := AValue;
  FDatabaseTypeStr := '';
  Result := Self;
end;

function TConnection.DatabaseType(const AValue: string): IConnection;
begin
  FDatabaseTypeStr := AValue;
  FDatabaseType := TDatabaseTypeClass.FromString(AValue);
  Result := Self;
end;

function TConnection.DatabaseType: TDatabaseTypes;
begin
  Result := FDatabaseType;
end;

function TConnection.Host(const AValue: string): IConnection;
begin
  FHost := AValue;
  Result := Self;
end;

function TConnection.Host: string;
begin
  Result := FHost;
end;

function TConnection.Port(const AValue: Integer): IConnection;
begin
  FPort := AValue;
  Result := Self;
end;

function TConnection.Port: Integer;
begin
  Result := FPort;
end;

function TConnection.Username(const AValue: string): IConnection;
begin
  FUsername := AValue;
  Result := Self;
end;

function TConnection.Username: string;
begin
  Result := FUsername;
end;

function TConnection.Password(const AValue: string): IConnection;
begin
  FPassword := AValue;
  Result := Self;
end;

function TConnection.Password: string;
begin
  Result := FPassword;
end;

function TConnection.Database(const AValue: string): IConnection;
begin
  FDatabase := AValue;
  Result := Self;
end;

function TConnection.Database: string;
begin
  Result := FDatabase;
end;

function TConnection.Schema(const AValue: string): IConnection;
begin
  FSchema := AValue;
  Result := Self;
end;

function TConnection.Schema: string;
begin
  Result := FSchema;
end;

function TConnection.ConfigFilePath(const AValue: string): IConnection;
begin
  FConfigFilePath := AValue;
  Result := Self;
end;

function TConnection.ConfigFilePath: string;
begin
  Result := FConfigFilePath;
end;

function TConnection.DllBasePath(const AValue: string): IConnection;
begin
  FDllBasePath := AValue;
  Result := self;
end;

function TConnection.DllBasePath: string;
begin
  Result := FDllBasePath;
end;

function TConnection.AutoDownloadDlls(const AValue: Boolean): IConnection;
begin
  FAutoDownloadDlls := AValue;
  Result := Self;
end;

function TConnection.AutoDownloadDlls: Boolean;
begin
  Result := FAutoDownloadDlls;
end;

function TConnection.DllDownloadUrl(const AValue: string): IConnection;
begin
  FDllDownloadUrl := AValue;
  Result := Self;
end;

function TConnection.DllDownloadUrl: string;
begin
  Result := FDllDownloadUrl;
end;

function TConnection.FirebirdVersion(const AValue: TFirebirdVersion): IConnection;
begin
  FFirebirdVersion := AValue;
  Result := Self;
end;

function TConnection.FirebirdVersion(const AValue: string): IConnection;
var
  LVal: string;
begin
  LVal := Trim(AValue);
  if (LVal = '2') or (LVal = '2.5') then
    FFirebirdVersion := fb25
  else if (LVal = '3') or (LVal = '3.0') then
    FFirebirdVersion := fb30
  else if (LVal = '4') or (LVal = '4.0') then
    FFirebirdVersion := fb40
  else if (LVal = '5') or (LVal = '5.0') then
    FFirebirdVersion := fb50;
  // valor vazio/desconhecido: mantém a versão atual
  Result := Self;
end;

function TConnection.FirebirdVersion: TFirebirdVersion;
begin
  Result := FFirebirdVersion;
end;

function TConnection.ServerName(const AValue: string): IConnection;
begin
  FServerName := AValue;
  Result := Self;
end;

function TConnection.ServerName: string;
begin
  Result := FServerName;
end;

function TConnection.SQLAnywhereDriver(const AValue: string): IConnection;
begin
  FSQLAnywhereDriver := AValue;
  Result := Self;
end;

function TConnection.SQLAnywhereDriver: string;
begin
  Result := FSQLAnywhereDriver;
end;

function TConnection.FromIniFile(const AFilePath, ASection: string)
  : IConnection;
begin
  LoadFromIniFile(AFilePath, ASection);
  Result := Self;
end;

{ FromConfig - via seam de DI (Connections.FromConfig). Sem loader
  registado (modulo Parameters, F7, ainda nao existe em src/), lanca excecao
  tipada em vez de tentar um path INI default em silencio (comportamento da
  fonte v2.3.0). FromIniFile/FromJSON/FromClass continuam diretos, sem seam. }
function TConnection.FromConfig: IConnection;
var
  LData: TConnectionData;
begin
  if not TConnectionConfigureLoaderRegistry.HasLoader then
    raise EConnectionConfigurationException.Create(
      'FromConfig: nenhum loader de configuracao registado (modulo Parameters ' +
      'indisponivel ate F7). Use FromIniFile/FromJSON/FromClass diretamente, ou ' +
      'registe um loader via TConnectionConfigureLoaderRegistry.Register.',
      ERR_CONFIG_INVALID, 'FromConfig');
  if not TConnectionConfigureLoaderRegistry.CurrentLoader.LoadConfigure(FConfigFilePath, LData) then
    raise EConnectionConfigurationException.Create(
      Format('FromConfig: loader registado nao encontrou configuracao para "%s".',
      [FConfigFilePath]), ERR_CONFIG_FILE_NOT_FOUND, 'FromConfig');
  FHost := LData.Host;
  FPort := LData.Port;
  FUsername := LData.Username;
  FPassword := LData.Password;
  FDatabase := LData.Database;
  FSchema := LData.Schema;
  FServerName := LData.ServerName;   { ENG do SQL Anywhere (F5 Onda 10). }
  FDatabaseType := LData.DatabaseType;
  FDllBasePath := LData.DllBasePath;
  FDllDownloadUrl := LData.DllDownloadUrl;   { override do URL (F7 Onda 7.0, seam 400017). }
  Result := Self;
end;

function TConnection.FromJSON(const AJSON: string): IConnection;
begin
  LoadFromJSON(AJSON);
  Result := Self;
end;

{$IFDEF USE_ATTRIBUTES}
procedure TConnection.LoadFromClass(const AClass: TClass);
var
  LCtx: TRttiContext;
  LType: TRttiType;
  LAttr: TCustomAttribute;
  LConnAttr: ConnectionAttribute;
begin
  if AClass = nil then
    Exit;
  LCtx := TRttiContext.Create;
  LType := LCtx.GetType(AClass);
  if LType = nil then
    Exit;
  for LAttr in LType.GetAttributes do
  begin
    if LAttr is ConnectionAttribute then
    begin
      LConnAttr := ConnectionAttribute(LAttr);
      if Trim(LConnAttr.IniFile) <> '' then
      begin
        LoadFromIniFile(LConnAttr.IniFile,
          IfThen(Trim(LConnAttr.Section) <> '', LConnAttr.Section, DEFAULT_SECTION_DATABASE_NAME));
        Exit;
      end;
      if Trim(LConnAttr.DllBasePath) <> '' then
        FDllBasePath := LConnAttr.DllBasePath;
      if Trim(LConnAttr.DatabaseType) <> '' then
      begin
        FDatabaseTypeStr := LConnAttr.DatabaseType;
        FDatabaseType := TDatabaseTypeClass.FromString(LConnAttr.DatabaseType);
      end;
      if Trim(LConnAttr.Host) <> '' then
        FHost := LConnAttr.Host;
      if LConnAttr.Port >= 0 then
        FPort := LConnAttr.Port;
      if Trim(LConnAttr.Username) <> '' then
        FUsername := LConnAttr.Username;
      if Trim(LConnAttr.Password) <> '' then
        FPassword := LConnAttr.Password;
      if Trim(LConnAttr.Database) <> '' then
        FDatabase := LConnAttr.Database;
      if Trim(LConnAttr.Schema) <> '' then
        FSchema := LConnAttr.Schema;
      Break;
    end;
  end;
end;

function TConnection.FromClass(const AClass: TClass): IConnection;
begin
  LoadFromClass(AClass);
  Result := Self;
end;
{$ENDIF}

function TConnection.IsRequiredDllFound: Boolean;
begin
  Result := TConnection.IsRequiredDllFound(FDllBasePath, FDatabaseType, FFirebirdVersion);
end;

class function TConnection.IsRequiredDllFound(const ADllBasePath: string; ADatabaseType: TDatabaseTypes; AFirebirdVersion: TFirebirdVersion = fb50): Boolean;
var
  LExePath, LPath, LPathAlt: string;
begin
  Result := True;
  if not (ADatabaseType in [dtPostgreSQL, dtMySQL, dtSQLServer, dtFireBird, dtSQLAnywhere]) then
    Exit;
  LExePath := ExtractFilePath(ParamStr(0));
  LPath := GetVendorLibPath(ADllBasePath, LExePath, ADatabaseType, AFirebirdVersion);
  if LPath = '' then
    Exit;
  if ADatabaseType = dtMySQL then
  begin
    if FileExists(LPath) then
      Exit;
    LPathAlt := GetVendorLibPathMySQLAlt(ADllBasePath, LExePath);
    Result := FileExists(LPathAlt);
  end
  else
    Result := FileExists(LPath);
end;

class function TConnection.IsRequiredDllFound(const ADllBasePath, ADatabaseTypeName: string): Boolean;
begin
  Result := TConnection.IsRequiredDllFound(ADllBasePath, TDatabaseTypeClass.FromString(ADatabaseTypeName));
end;

procedure TConnection.ValidateRequiredDll;
var
  LExePath, LPath, LPathAlt: string;
begin
  if IsRequiredDllFound then
    Exit;
  { Download-if-missing (opt-in; owner: "so baixar se nao existir"). So dispara quando
    a DLL nao existe E o autodownload esta ligado: EnsureDlls extrai dll.zip para
    <exe>/dll/ e re-valida. No-op (Enabled=False) sem USE_DLL_AUTODOWNLOAD. }
  if FAutoDownloadDlls and TDllBootstrap.Enabled then
  begin
    { FDllDownloadUrl (override por perfil Parameters, F7 Onda 7.0) tem prioridade;
      '' = usa Commons.Consts.DEFAULT_DLL_DOWNLOAD_URL via EnsureDlls/DefaultUrl. }
    if FDllDownloadUrl <> '' then
      TDllBootstrap.DownloadAndExtract(FDllDownloadUrl, ExtractFilePath(ParamStr(0)))
    else
      TDllBootstrap.EnsureDlls;
    if IsRequiredDllFound then
      Exit;
  end;
  LExePath := ExtractFilePath(ParamStr(0));
  LPath := GetVendorLibPath(FDllBasePath, LExePath, FDatabaseType, FFirebirdVersion);
  if FDatabaseType = dtMySQL then
  begin
    LPathAlt := GetVendorLibPathMySQLAlt(FDllBasePath, LExePath);
    raise EConnectionConfigurationException.Create(
      Format('DLL necessaria nao encontrada. PostgreSQL/MySQL/SQL Server exigem a biblioteca cliente. Esperado: %s ou %s',
        [LPath, LPathAlt]), ERR_CONNECTION_FAILED, 'ValidateRequiredDll');
  end
  else
    raise EConnectionConfigurationException.Create(
      Format('DLL necessaria nao encontrada: %s', [LPath]), ERR_CONNECTION_FAILED, 'ValidateRequiredDll');
end;

function TConnection.Connect: IConnection;
begin
  if FConnected then
  begin
    Result := Self;
    Exit;
  end;
  ValidateRequiredDll;
  CreateNativeConnection;
  ConfigureNativeConnection;
  if Assigned(FOnBeforeConnect) then
    FOnBeforeConnect(Self);
{$IFDEF USE_LOGGERS}
  FLogger.Debug(Format('Connect: iniciando (Host=%s Database=%s DatabaseType=%s)',
    [FHost, FDatabase, FDatabaseTypeStr]));
{$ENDIF}
  try
{$IF DEFINED(USE_UNIDAC)}
    if Assigned(FConnection) then
    begin
      TUniConnection(FConnection).Connect;
      FConnected := TUniConnection(FConnection).Connected;
    end
    else
      FConnected := False;
{$ENDIF}
{$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)}
    if Assigned(FConnection) then
    begin
      TFDConnection(FConnection).Connected := True;
      FConnected := TFDConnection(FConnection).Connected;
    end
    else
      FConnected := False;
{$ENDIF}
{$IF DEFINED(USE_ZEOS)}
    if Assigned(FConnection) then
    begin
      ZConnection.TZConnection(FConnection).Connect;
      FConnected := ZConnection.TZConnection(FConnection).Connected;
    end
    else
      FConnected := False;
{$ENDIF}
{$IF DEFINED(USE_SQLDB)}
    if Assigned(FConnection) then
    begin
      TSQLConnection(FConnection).Connected := True;
      FConnected := TSQLConnection(FConnection).Connected;
    end
    else
      FConnected := False;
{$ENDIF}
{$IF NOT DEFINED(USE_UNIDAC)}
{$IF NOT DEFINED(USE_FIREDAC)}
{$IF NOT DEFINED(USE_ZEOS)}
{$IF NOT DEFINED(USE_SQLDB)}
    FConnected := False;
    raise EConnectionConnectionException.Create
      ('Nenhum engine definido. Defina USE_ZEOS, USE_UNIDAC, USE_FIREDAC ou USE_SQLDB em ORM.Defines.inc.',
      ERR_ENGINE_NOT_SUPPORTED, 'Connect');
{$ENDIF}
{$ENDIF}
{$ENDIF}
{$ENDIF}
    if FConnected and Assigned(FOnAfterConnect) then
      FOnAfterConnect(Self);
{$IFDEF USE_LOGGERS}
    if FConnected then
      FLogger.Success(Format('Connect: OK (Host=%s Database=%s DatabaseType=%s)',
        [FHost, FDatabase, FDatabaseTypeStr]));
{$ENDIF}
  except
    on E: Exception do
    begin
      { F8 Onda 8.6 - logging de erro via ILogger reintroduzido (era removido
        na Onda 4.1 - ver header do ficheiro); OnConnectionError continua a
        cobrir a notificacao ao caller, os 2 mecanismos coexistem. }
      if Assigned(FOnConnectionError) then
        FOnConnectionError(Self, E);
{$IFDEF USE_LOGGERS}
      FLogger.Error(Format('Connect: falhou (Host=%s Database=%s DatabaseType=%s)',
        [FHost, FDatabase, FDatabaseTypeStr]), E);
{$ENDIF}
      raise;
    end;
  end;
  Result := Self;
end;

function TConnection.Disconnect: IConnection;
begin
  if FInTransaction then
    Rollback;
  if Assigned(FOnBeforeDisconnect) then
    FOnBeforeDisconnect(Self);
{$IFDEF USE_LOGGERS}
  FLogger.Debug('Disconnect: iniciando');
{$ENDIF}
{$IF DEFINED(USE_UNIDAC)}
  if Assigned(FConnection) and TUniConnection(FConnection).Connected then
    TUniConnection(FConnection).Disconnect;
{$ENDIF}
{$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)}
  if Assigned(FConnection) and TFDConnection(FConnection).Connected then
    TFDConnection(FConnection).Connected := False;
{$ENDIF}
{$IF DEFINED(USE_ZEOS)}
  if Assigned(FConnection) and ZConnection.TZConnection(FConnection).Connected
  then
    ZConnection.TZConnection(FConnection).Disconnect;
{$ENDIF}
{$IF DEFINED(USE_SQLDB)}
  if Assigned(FConnection) and TSQLConnection(FConnection).Connected then
    TSQLConnection(FConnection).Connected := False;
{$ENDIF}
  FConnected := False;
  if Assigned(FOnAfterDisconnect) then
    FOnAfterDisconnect(Self);
{$IFDEF USE_LOGGERS}
  FLogger.Debug('Disconnect: OK');
{$ENDIF}
  Result := Self;
end;

function TConnection.IsConnected: Boolean;
begin
{$IF DEFINED(USE_UNIDAC)}
  if Assigned(FConnection) then
    Result := TUniConnection(FConnection).Connected
  else
    Result := FConnected;
{$ELSE} {$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)}
  if Assigned(FConnection) then
    Result := TFDConnection(FConnection).Connected
  else
    Result := FConnected;
{$ELSE} {$IF DEFINED(USE_ZEOS)}
  if Assigned(FConnection) then
    Result := ZConnection.TZConnection(FConnection).Connected
  else
    Result := FConnected;
{$ELSE} {$IF DEFINED(USE_SQLDB)}
  if Assigned(FConnection) then
    Result := TSQLConnection(FConnection).Connected
  else
    Result := FConnected;
{$ELSE}
  Result := FConnected;
{$ENDIF}
{$ENDIF}
{$ENDIF}
{$ENDIF}
end;

function TConnection.Ping: Boolean;
begin
{$IF DEFINED(USE_ZEOS)}
  Result := False;
  try
    if not IsConnected then
      Exit;
    if DatabaseType = dtFireBird then
      ExecuteScalar('SELECT 1 FROM RDB$DATABASE')
    else
      ExecuteScalar('SELECT 1');
    Result := True;
  except
    on E: Exception do
      Result := False;
  end;
{$ELSE}
  if not IsConnected then
    Result := False
  else
{$IF DEFINED(USE_UNIDAC)}
    try
      TUniConnection(FConnection).Ping;
      Result := True;
    except
      Result := False;
    end
{$ELSE} {$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)}
    try
      Result := TFDConnection(FConnection).Ping;
    except
      Result := False;
    end
{$ELSE} {$IF DEFINED(USE_SQLDB)}
    { paridade com o Zeos: ping real por SELECT dialect-aware (IsConnected
      sozinho nao toca no servidor) }
    try
      if FDatabaseType = dtFireBird then
        ExecuteScalar('SELECT 1 FROM RDB$DATABASE')
      else
        ExecuteScalar('SELECT 1');
      Result := True;
    except
      Result := False;
    end
{$ELSE}
      Result := False
{$ENDIF}
{$ENDIF}
{$ENDIF}
{$ENDIF};
end;

{ Etapa A1 do broker (Onda 4.3, Prompt Connections): copia um dataset vivo para
  um Memory DataSet totalmente DESCONECTADO (TBufDataset no FPC; TClientDataSet
  estático/MidasLib no Delphi — uniforme para todos os engines). A query física
  é libertada pelo caller logo a seguir — o resultado não tem cursor vivo preso
  à conexão e é seguro atravessar a fronteira Worker→solicitante. }
function CreateDisconnectedCopy(ASource: TDataSet): TDataSet;
var
  LMem: {$IFDEF FPC}TBufDataset{$ELSE}TClientDataSet{$ENDIF};
  LSrcF: TField;
  LDstF: TField;
  LDef: TFieldDef;
  LDT: TFieldType;
  LSize: Integer;
  I: Integer;
begin
  LMem := {$IFDEF FPC}TBufDataset{$ELSE}TClientDataSet{$ENDIF}.Create(nil);
  try
    { FieldDefs a partir dos FIELDS abertos (não dos FieldDefs do driver):
      normaliza tipos problemáticos para um container writable. }
    for I := 0 to ASource.FieldCount - 1 do
    begin
      LSrcF := ASource.Fields[I];
      LDT := LSrcF.DataType;
      LSize := LSrcF.Size;
      if LDT = ftAutoInc then
        LDT := ftInteger;
{$IFNDEF FPC}
      { TClientDataSet (MIDAS) NAO aceita alguns tipos/tamanhos que os drivers
        devolvem (FireDAC+SQLite em particular) - coage-os a equivalentes
        suportados; senao CreateDataSet lanca "Invalid field type". }
      case LDT of
        ftByte, ftShortint:                   LDT := ftSmallint;
        ftLongWord:                           LDT := ftLargeint;
        Data.DB.ftSingle, Data.DB.ftExtended: LDT := ftFloat;   { colidem com TypInfo.TFloatType }
        ftTimeStampOffset:                    LDT := ftTimeStamp;
        ftString, ftFixedChar:
          { FireDAC devolve TEXT como string com size enorme (32767) - o CDS recusa;
            string sobre-dimensionada/ilimitada -> memo (sem truncar dados). }
          if (LSize <= 0) or (LSize > 8192) then begin LDT := ftMemo; LSize := 0; end;
        ftWideString, ftFixedWideChar:
          if (LSize <= 0) or (LSize > 8192) then begin LDT := ftWideMemo; LSize := 0; end;
      end;
{$ENDIF}
      LMem.FieldDefs.Add(LSrcF.FieldName, LDT, LSize, False);
      LDef := LMem.FieldDefs[LMem.FieldDefs.Count - 1];
      { bug-1001: os tipos de largura VARIAVEL (BCD/FmtBCD/Float/Currency) precisam
        da PRECISION propagada para o TFieldDef - sem ela o container aloca o campo
        com Precision=0 e o buffer de registo fica mal dimensionado; um DECIMAL(18,4)
        ao lado de outras colunas escreve fora dos limites e corrompe os vizinhos
        (EAccessViolation em UniDAC x SQL Anywhere no SELECT *). Le a Precision da
        ORIGEM por cast de classe - MESMO padrao/lista de Serialize.Utils.
        NewDataSetField (SSOT), sem duplicar tabela de tipos. }
      case LSrcF.DataType of
        ftBCD:      LDef.Precision := TBCDField(LSrcF).Precision;
        ftFMTBcd:   LDef.Precision := TFMTBCDField(LSrcF).Precision;
        ftFloat:    LDef.Precision := TFloatField(LSrcF).Precision;
        ftCurrency: LDef.Precision := TCurrencyField(LSrcF).Precision;
      {$IFNDEF FPC}
        Data.DB.ftSingle:   LDef.Precision := TSingleField(LSrcF).Precision;
        Data.DB.ftExtended: LDef.Precision := TExtendedField(LSrcF).Precision;
      {$ENDIF}
      end;
    end;
    LMem.CreateDataSet;
    ASource.First;
    while not ASource.Eof do
    begin
      LMem.Append;
      for I := 0 to ASource.FieldCount - 1 do
      begin
        LSrcF := ASource.Fields[I];
        if not LSrcF.IsNull then
        begin
          LDstF := LMem.Fields[I];
          { bug-1001: copia FORTEMENTE TIPADA por tipo de campo - NUNCA via Variant
            (.Value := .Value). O BCD/decimal exige AsBCD: a via Variant converte
            para o buffer BCD mal-dimensionado e corrompe memoria (raiz do EAV em
            UniDAC x SQL Anywhere). Alinhado ao principio do owner: tipar sempre,
            nao deixar o driver inferir de Variant cru. }
          case LSrcF.DataType of
            ftBCD, ftFMTBcd:
              LDstF.AsBCD := LSrcF.AsBCD;
            ftBoolean:
              LDstF.AsBoolean := LSrcF.AsBoolean;
            ftSmallint, ftInteger, ftWord, ftAutoInc, ftLargeint:
              LDstF.AsLargeInt := LSrcF.AsLargeInt;
            ftFloat, ftCurrency{$IFNDEF FPC}, Data.DB.ftSingle, Data.DB.ftExtended{$ENDIF}:
              LDstF.AsFloat := LSrcF.AsFloat;
            ftDate, ftTime, ftDateTime, ftTimeStamp:
              LDstF.AsDateTime := LSrcF.AsDateTime;
            ftBytes, ftVarBytes, ftBlob, ftGraphic:
              LDstF.AsBytes := LSrcF.AsBytes;
          else
            LDstF.AsString := LSrcF.AsString;
          end;
        end;
      end;
      LMem.Post;
      ASource.Next;
    end;
    LMem.First;
    Result := LMem;
  except
    LMem.Free;
    raise;
  end;
end;

function TConnection.ExecuteQuery(const ASQL: string): TDataSet;
var
  LQ: TObject;
begin
  Result := nil;
  if not Assigned(FConnection) or not IsConnected then
    raise EConnectionConnectionException.Create('Conexão não estabelecida.',
      ERR_CONNECTION_NOT_CONNECTED, 'ExecuteQuery');
{$IF DEFINED(USE_UNIDAC)}
  LQ := TUniQuery.Create(nil);
  try
    TUniQuery(LQ).Connection := TUniConnection(FConnection);
    TUniQuery(LQ).SQL.Text := ASQL;
    TUniQuery(LQ).Open;
    { Etapa A1: devolve copia em memoria DESCONECTADA; a fisica liberta-se ja }
    Result := CreateDisconnectedCopy(TDataSet(LQ));
  finally
    TUniQuery(LQ).Free;
  end;
  { FB+UniDAC: o Open abre uma read-transaction que fica ATIVA e bloquearia o DDL
    seguinte na mesma sessao ("Can't perform operation on active transaction").
    A copia ja esta em memoria - fechar a leitura fora de transacao explicita
    (mesmo padrao de GetTableNames/SchemaNames). }
  if (not FInTransaction) and TUniConnection(FConnection).InTransaction then
    TUniConnection(FConnection).Commit;
  { F5 onda C8 (bug-986/test_serialize - mesma raiz do bug-884/983) - SO' para
    SQL Anywhere, fecha a leitura com um "COMMIT" em SQL CRU (nao a chamada
    TUniConnection.Commit acima): GetColumnNames/GetTableStructure (Connections.
    pas) correm QUALQUER SELECT de catalogo SQL Anywhere/UniDAC por ESTE metodo
    (sem ramo dedicado como GetTableNamesFromDriver), e o bookkeeping NATIVO
    TUniConnection.InTransaction pode NAO reportar a transaccao residual real
    aberta pelo path do dbcapi para este motor (mesma assimetria ja confirmada
    em ExecuteCommand/VerifyShape - bug-884/983); TENTAR primeiro so' com o OR
    "(FDatabaseType=dtSQLAnywhere) or InTransaction" a chamar
    TUniConnection.Commit NAO resolveu (validado empiricamente aqui) - a
    chamada nativa continua a nao-op quando o driver "acha" que nao ha
    transaccao. Um "COMMIT" em SQL CRU (via Self.ExecuteCommand, MESMO
    mecanismo ja provado em TSynchronize.VerifyShape/CommitResidualSQLAnywhere)
    bypassa esse bookkeeping por completo - fecha SEMPRE, mesmo quando o driver
    diz que nao ha nada para fechar. Sem isto, um SELECT de catalogo (ex.:
    ColumnExists numa 2a chamada de TSynchronize.Sync logo a seguir a 1a, na
    MESMA ligacao) deixava uma leitura residual aberta que STALED a PROXIMA
    introspeccao - reproduzido em test_serialize.dpr ("Item 'valor' already
    exists": Compare() da 2a Sync tentava ADD COLUMN de uma coluna que
    ColumnExists devia ter visto como ja existente). Gated ao motor: zero
    mudanca de comportamento nos restantes engines (Firebird mantem-se so'
    pelo InTransaction nativo, acima, como antes). }
  if (not FInTransaction) and (FDatabaseType = dtSQLAnywhere) then
  begin
    try
      ExecuteCommand('COMMIT');
    except
      { inocuo - nada para commitar, ou a ligacao rejeita um COMMIT solto; as
        leituras seguintes continuam a decidir o resultado real. }
    end;
  end;
{$ENDIF}
{$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)}
  LQ := TFDQuery.Create(nil);
  try
    TFDQuery(LQ).Connection := TFDConnection(FConnection);
    TFDQuery(LQ).SQL.Text := ASQL;
    TFDQuery(LQ).Open;
    Result := CreateDisconnectedCopy(TDataSet(LQ));
  finally
    TFDQuery(LQ).Free;
  end;
{$ENDIF}
{$IF DEFINED(USE_ZEOS)}
  // SQL Anywhere (Fase 1 repasse): TODO o SELECT via TZReadOnlyQuery - o TZQuery
  // editavel resolve metadados "smart" pelas stored procedures sp_jdbc_* que
  // podem nao existir/sem permissao no banco (SQLCODE=-265). Antes so os
  // catalogos de TableNames/ColumnNames usavam o caminho read-only; as
  // introspeccoes do IMetadata (ViewNames/ProcedureNames/...) passavam pelo
  // generico e o erro era ENGOLIDO pelo padrao robusto -> introspeccao "cega"
  // (ViewsSQL "vazio" no dcc32; ProcedureExists cego no dcc64).
  if FDatabaseType = dtSQLAnywhere then
  begin
    Result := ExecuteQueryZeosReadOnly(ASQL);
    Exit;
  end;
  LQ := ZDataset.TZQuery.Create(nil);
  try
    ZDataset.TZQuery(LQ).Connection := ZConnection.TZConnection(FConnection);
    ZDataset.TZQuery(LQ).SQL.Text := ASQL;
    ZDataset.TZQuery(LQ).Open;
    Result := CreateDisconnectedCopy(TDataSet(LQ));
  finally
    ZDataset.TZQuery(LQ).Free;
  end;
{$ENDIF}
{$IF DEFINED(USE_SQLDB)}
  LQ := TSQLQuery.Create(nil);
  try
    TSQLQuery(LQ).Database := TSQLConnection(FConnection);
    TSQLQuery(LQ).Transaction := TSQLTransaction(FTransaction);
    // ORM faz o proprio DML dialect-aware -> nao precisa dos server index defs;
    // desligar evita SQLPrimaryKeys (nao suportado pelo driver ODBC Jet/Access).
    TSQLQuery(LQ).UsePrimaryKeyAsKey := False;
    TSQLQuery(LQ).SQL.Text := ASQL;
    TSQLQuery(LQ).Open;
    Result := CreateDisconnectedCopy(TDataSet(LQ));
  finally
    TSQLQuery(LQ).Free;
  end;
{$ENDIF}
end;

{ bug-167 (Onda 5.2): o Zeos cacheia o CATALOGO por conexao - DDL executado
  na propria conexao nao invalida GetTableNames/GetColumnNames. Limpa o cache
  de metadados do driver quando o comando e DDL (CREATE/ALTER/DROP), para o
  IMetadata.Refresh reler o catalogo real SEM reconnect. No-op nos
  engines sem cache persistente conhecido. }
procedure TConnection.InvalidateDriverMetadata(const ASQL: string);
{$IF DEFINED(USE_ZEOS)}
var
  LHead: string;
{$ENDIF}
begin
{$IF DEFINED(USE_ZEOS)}
  LHead := UpperCase(Copy(TrimLeft(ASQL), 1, 5));
  { bug-594: o SQL Server renomeia tabelas/colunas com 'EXEC sp_rename ...' (nao
    e um CREATE/ALTER/DROP) - sem isto o cache do driver ficava stale e o
    IMetadata.Refresh nao via a tabela renomeada. Qualquer EXEC limpa o cache
    (raro; no pior caso e' so uma releitura de catalogo). }
  if (LHead = 'CREAT') or (LHead = 'ALTER') or (Copy(LHead, 1, 4) = 'DROP') or
     (Copy(LHead, 1, 4) = 'EXEC') then
    if Assigned(FConnection) and ZConnection.TZConnection(FConnection).Connected then
      ZConnection.TZConnection(FConnection).DbcConnection.GetMetadata.ClearCache;
{$ENDIF}
end;

function TConnection.ExecuteCommand(const ASQL: string): Integer;
begin
  Result := 0;
  if not Assigned(FExecQuery) or not Assigned(FConnection) or not IsConnected
  then
    raise EConnectionConnectionException.Create('Conexão não estabelecida.',
      ERR_CONNECTION_NOT_CONNECTED, 'ExecuteCommand');
{$IFDEF USE_DATABASE}
  try  // F5-FU.3 - converte lock Firebird (NO WAIT) em EDatabaseObjectLockedException
{$ENDIF}
{$IF DEFINED(USE_UNIDAC)}
  { FB+UniDAC: consultas anteriores (catalogo/versao/SELECT) deixam uma read-
    transaction ATIVA que bloqueia o DDL seguinte ("Can't perform operation on
    active transaction" - AutoCommit nao a fecha). Fora de transacao explicita,
    fechar ANTES de executar (mesmo padrao do GetTableNames/SchemaNames). }
  if (not FInTransaction) and TUniConnection(FConnection).InTransaction then
    TUniConnection(FConnection).Commit;
  TUniQuery(FExecQuery).SQL.Text := ASQL;
  TUniQuery(FExecQuery).ExecSQL;
  Result := TUniQuery(FExecQuery).RowsAffected;
  { POST-commit fora de transacao explicita: SQL Anywhere (o provider nativo nao
    autocommita o path preparado - bug-884) OU qualquer transacao nativa ainda
    aberta (Firebird: DDL/SELECT deixa uma transacao ATIVA que bloquearia o
    comando seguinte na MESMA ligacao com "Can't perform operation on active
    transaction"). Fecha aqui para o proximo comando/Sync partir limpo. }
  if (not FInTransaction) and
     ((FDatabaseType = dtSQLAnywhere) or TUniConnection(FConnection).InTransaction) then
    TUniConnection(FConnection).Commit;
{$ENDIF}
{$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)}
  TFDQuery(FExecQuery).SQL.Text := ASQL;
  TFDQuery(FExecQuery).ExecSQL;
  Result := TFDQuery(FExecQuery).RowsAffected;
{$ENDIF}
{$IF DEFINED(USE_ZEOS)}
  ZDataset.TZQuery(FExecQuery).SQL.Text := ASQL;
  ZDataset.TZQuery(FExecQuery).ExecSQL;
  Result := ZDataset.TZQuery(FExecQuery).RowsAffected;
{$ENDIF}
  InvalidateDriverMetadata(ASQL); // bug-167 (no-op fora do Zeos)
{$IF DEFINED(USE_SQLDB)}
  TSQLQuery(FExecQuery).SQL.Text := ASQL;
  try
    TSQLQuery(FExecQuery).ExecSQL;
    Result := TSQLQuery(FExecQuery).RowsAffected;
    { autocommit emulado: fora de transacao explicita, reter o commit — senao
      a transacao partilhada do sqldb fica aberta (e um comando falhado aborta
      o bloco inteiro no PostgreSQL). }
    if not FInTransaction then
      TSQLTransaction(FTransaction).CommitRetaining;
  except
    if not FInTransaction then
      TSQLTransaction(FTransaction).RollbackRetaining;
    raise;
  end;
{$ENDIF}
{$IFDEF USE_DATABASE}
  except
    on E: Exception do
    begin
      { F5-FU.3 - so quando o consumidor pediu NO WAIT (LockWait(False)) e o
        banco e Firebird: converte o erro de lock em EDatabaseObjectLockedException
        catchable. Fora disso re-lanca a excecao original (comportamento atual). }
      if (not FLockWait) and (FDatabaseType = dtFireBird) and IsFirebirdLockError(E.Message) then
        raise EDatabaseObjectLockedException.Create(
          Format(DB_ERR_OBJECT_LOCKED_MSG, [Trim(Copy(ASQL, 1, 60)), E.Message]),
          ERR_DATABASE_OBJECT_LOCKED, ASQL);
      raise;
    end;
  end;
{$ENDIF}
end;

function TConnection.ExecuteScalar(const ASQL: string): Variant;
begin
  Result := Null;
  if not Assigned(FQuery) or not Assigned(FConnection) or not IsConnected then
    raise EConnectionConnectionException.Create('Conexão não estabelecida.',
      ERR_CONNECTION_NOT_CONNECTED, 'ExecuteScalar');
{$IF DEFINED(USE_UNIDAC)}
  TUniQuery(FQuery).SQL.Text := ASQL;
  TUniQuery(FQuery).Open;
  try
    if not TUniQuery(FQuery).IsEmpty and (TUniQuery(FQuery).FieldCount > 0) then
      Result := TUniQuery(FQuery).Fields[0].Value;
  finally
    TUniQuery(FQuery).Close;
  end;
{$ENDIF}
{$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)}
  TFDQuery(FQuery).SQL.Text := ASQL;
  TFDQuery(FQuery).Open;
  try
    if not TFDQuery(FQuery).IsEmpty and (TFDQuery(FQuery).FieldCount > 0) then
      Result := TFDQuery(FQuery).Fields[0].Value;
  finally
    TFDQuery(FQuery).Close;
  end;
{$ENDIF}
{$IF DEFINED(USE_ZEOS)}
  ZDataset.TZQuery(FQuery).SQL.Text := ASQL;
  ZDataset.TZQuery(FQuery).Open;
  try
    if not ZDataset.TZQuery(FQuery).IsEmpty and
      (ZDataset.TZQuery(FQuery).FieldCount > 0) then
      Result := ZDataset.TZQuery(FQuery).Fields[0].Value;
  finally
    ZDataset.TZQuery(FQuery).Close;
  end;
{$ENDIF}
{$IF DEFINED(USE_SQLDB)}
  TSQLQuery(FQuery).SQL.Text := ASQL;
  TSQLQuery(FQuery).Open;
  try
    if not TSQLQuery(FQuery).IsEmpty and (TSQLQuery(FQuery).FieldCount > 0) then
      Result := TSQLQuery(FQuery).Fields[0].Value;
  finally
    TSQLQuery(FQuery).Close;
  end;
{$ENDIF}
end;

function TConnection.BeginTransaction: IConnection;
begin
{$IF DEFINED(USE_UNIDAC)}
  if Assigned(FConnection) and IsConnected then
  begin
    TUniConnection(FConnection).StartTransaction;
    FInTransaction := True;
  end;
{$ENDIF}
{$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)}
  if Assigned(FConnection) and IsConnected then
  begin
    TFDConnection(FConnection).StartTransaction;
    FInTransaction := True;
  end;
{$ENDIF}
{$IF DEFINED(USE_ZEOS)}
  if Assigned(FConnection) and IsConnected then
  begin
    ZConnection.TZConnection(FConnection).StartTransaction;
    FInTransaction := True;
  end;
{$ENDIF}
{$IF DEFINED(USE_SQLDB)}
  if Assigned(FTransaction) and Assigned(FConnection) and IsConnected then
  begin
    { o sqldb activa a transacao partilhada implicitamente em qualquer query;
      fechar a implicita (leituras/comandos ja retidos) antes do Start
      explicito — senao 'Transaction already active'. }
    if TSQLTransaction(FTransaction).Active then
      TSQLTransaction(FTransaction).Commit;
    TSQLTransaction(FTransaction).StartTransaction;
    FInTransaction := True;
  end;
{$ENDIF}
  Result := Self;
end;

function TConnection.Commit: IConnection;
begin
{$IF DEFINED(USE_UNIDAC)}
  if Assigned(FConnection) and FInTransaction then
  begin
    TUniConnection(FConnection).Commit;
    FInTransaction := False;
  end;
{$ENDIF}
{$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)}
  if Assigned(FConnection) and FInTransaction then
  begin
    TFDConnection(FConnection).Commit;
    FInTransaction := False;
  end;
{$ENDIF}
{$IF DEFINED(USE_ZEOS)}
  if Assigned(FConnection) and FInTransaction then
  begin
    ZConnection.TZConnection(FConnection).Commit;
    FInTransaction := False;
    { bug-976 - SQL Anywhere (Zeos asa_capi, TZSQLAnywhereConnection.Commit em
      ZDbcSQLAnywhere.pas): apos StartTransaction desligar o AUTO_COMMIT do
      SERVIDOR ('SET TEMPORARY OPTION AUTO_COMMIT=Off'/chained=On), o Commit()
      do PROVIDER so' actualiza o FLAG local Delphi (AutoCommit:=True) - NUNCA
      reenvia o 'SET TEMPORARY OPTION AUTO_COMMIT=On' que o StartTransaction
      tinha desligado (assimetria confirmada no source do driver: StartTransaction
      emite o SET, Commit/Rollback nao). A sessao do SERVIDOR fica
      PERMANENTEMENTE em modo chained (manual-commit) depois da 1a transacao
      explicita nesta ligacao (ex.: TSynchronize.Sync) - o proprio driver
      "acha" que esta em autocommit (o campo mente), mas TODO INSERT/UPDATE/
      DELETE seguinte "autocommit" fica por confirmar server-side; ao
      desligar a ligacao sem COMMIT/ROLLBACK explicito, o servidor descarta
      esse trabalho (perda de dados silenciosa - confirmado por dbisql em 2a
      ligacao independente, spike isolado: com Sync=0 FAIL, com Sync=2 FAIL).
      FIX: forcar o driver a REENVIAR o SET (False->True fuerza o
      TZSQLAnywhereConnection.SetAutoCommit a executar o ExecuteImmediat que
      falta) - sem isto qualquer DML "autocommit" POS-Sync neste engine perde-se
      silenciosamente no Disconnect. Aditivo, so' dtSQLAnywhere, nao afecta os
      restantes bancos Zeos (Firebird/PostgreSQL/MySQL/SQLite/SQLServer/Access). }
    if FDatabaseType = dtSQLAnywhere then
    begin
      ZConnection.TZConnection(FConnection).AutoCommit := False;
      ZConnection.TZConnection(FConnection).AutoCommit := True;
    end;
  end;
{$ENDIF}
{$IF DEFINED(USE_SQLDB)}
  if Assigned(FTransaction) and FInTransaction then
  begin
    TSQLTransaction(FTransaction).Commit;
    FInTransaction := False;
  end;
{$ENDIF}
  Result := Self;
end;

function TConnection.Rollback: IConnection;
begin
{$IF DEFINED(USE_UNIDAC)}
  if Assigned(FConnection) and FInTransaction then
  begin
    TUniConnection(FConnection).Rollback;
    FInTransaction := False;
  end;
{$ENDIF}
{$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)}
  if Assigned(FConnection) and FInTransaction then
  begin
    TFDConnection(FConnection).Rollback;
    FInTransaction := False;
  end;
{$ENDIF}
{$IF DEFINED(USE_ZEOS)}
  if Assigned(FConnection) and FInTransaction then
  begin
    ZConnection.TZConnection(FConnection).Rollback;
    FInTransaction := False;
    { bug-976 - mesma assimetria do Commit (ver comentario completo em
      TConnection.Commit): TZSQLAnywhereConnection.Rollback tambem so' actualiza
      o FLAG local (AutoCommit:=True) sem reenviar 'SET TEMPORARY OPTION
      AUTO_COMMIT=On' ao servidor - o toggle False->True forca o driver a
      reemitir o SET em falta. Aditivo, so' dtSQLAnywhere. }
    if FDatabaseType = dtSQLAnywhere then
    begin
      ZConnection.TZConnection(FConnection).AutoCommit := False;
      ZConnection.TZConnection(FConnection).AutoCommit := True;
    end;
  end;
{$ENDIF}
{$IF DEFINED(USE_SQLDB)}
  if Assigned(FTransaction) and FInTransaction then
  begin
    TSQLTransaction(FTransaction).Rollback;
    FInTransaction := False;
  end;
{$ENDIF}
  Result := Self;
end;

function TConnection.InTransaction: Boolean;
begin
  Result := FInTransaction;
end;

function TConnection.LockWait(const AValue: Boolean): IConnection;
begin
  { F5-FU.3 - guarda o modo; a config NO WAIT do Firebird e aplicada em
    ConfigureNativeConnection (ler ANTES de Connect). Se ja ligado, o Zeos
    reconstroi o TPB a cada transaccao (GenerateTPB le Properties), por isso
    reaplicamos a property aqui para o efeito ser imediato nas proximas tx. }
  FLockWait := AValue;
{$IF DEFINED(USE_ZEOS)}
  if (not FLockWait) and (FDatabaseType = dtFireBird) and Assigned(FConnection) then
    if ZConnection.TZConnection(FConnection).Properties.IndexOf('isc_tpb_nowait') < 0 then
      ZConnection.TZConnection(FConnection).Properties.Add('isc_tpb_nowait');
{$ENDIF}
  Result := Self;
end;

function TConnection.LockWait: Boolean;
begin
  Result := FLockWait;
end;

{$IF (DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)) OR DEFINED(USE_SQLDB)}
{ Versao do servidor por SQL portavel — para engines sem propriedade nativa
  equivalente (FireDAC devolvia stub vazio; SQLdb idem). }
function TConnection.GetServerVersionBySQL: string;
begin
  Result := '';
  try
    case FDatabaseType of
      dtSQLServer:
        Result := VarToStr(ExecuteScalar(
          'SELECT CAST(SERVERPROPERTY(''ProductVersion'') AS VARCHAR(64))'));
      dtMySQL:
        Result := VarToStr(ExecuteScalar('SELECT VERSION()'));
      dtPostgreSQL:
        Result := VarToStr(ExecuteScalar('SELECT current_setting(''server_version'')'));
      dtFireBird:
        Result := VarToStr(ExecuteScalar(
          'SELECT rdb$get_context(''SYSTEM'', ''ENGINE_VERSION'') FROM rdb$database'));
      dtSQLite:
        Result := VarToStr(ExecuteScalar('SELECT sqlite_version()'));
    else
      Result := '';
    end;
  except
    on E: Exception do
      Result := '';
  end;
end;
{$ENDIF}

function TConnection.GetServerVersion: string;
begin
  Result := '';
{$IF DEFINED(USE_UNIDAC)} if Assigned(FConnection) and IsConnected then
    Result := TUniConnection(FConnection).ServerVersion; {$ENDIF}
{$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)} if Assigned(FConnection) and IsConnected then
    Result := GetServerVersionBySQL; {$ENDIF}
{$IF DEFINED(USE_ZEOS)} if Assigned(FConnection) and IsConnected then
    Result := ZConnection.TZConnection(FConnection).ServerVersionStr; {$ENDIF}
{$IF DEFINED(USE_SQLDB)} if Assigned(FConnection) and IsConnected then
    Result := GetServerVersionBySQL; {$ENDIF}
end;

function TConnection.GetClientVersion: string;
begin
  Result := '';
{$IF DEFINED(USE_UNIDAC)} if Assigned(FConnection) then
    Result := TUniConnection(FConnection).ClientVersion; {$ENDIF}
{$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)} if Assigned(FConnection) then
    Result := TFDConnection(FConnection).DriverName; {$ENDIF}
{$IF DEFINED(USE_ZEOS)} if Assigned(FConnection) then
    Result := ZConnection.TZConnection(FConnection).ClientVersionStr; {$ENDIF}
{$IF DEFINED(USE_SQLDB)} Result := ''; {$ENDIF}
end;

function TConnection.GetConnectionData: TConnectionData;
begin
  Result.Engine := FEngine;
  Result.DatabaseType := FDatabaseType;
  Result.Host := FHost;
  Result.Port := FPort;
  Result.Username := FUsername;
  Result.Password := FPassword;
  Result.Database := FDatabase;
  Result.Schema := FSchema;
  Result.ConfigFilePath := FConfigFilePath;
  Result.DllBasePath := FDllBasePath;
  Result.DllDownloadUrl := FDllDownloadUrl;
end;

function GetTablesSQLForType(const ADatabaseType: TDatabaseTypes; const ASchema: string): string;
begin
  Result := '';
  if ASchema = '' then
    Exit;
  case ADatabaseType of
    dtPostgreSQL:
      Result := 'SELECT table_name FROM information_schema.tables WHERE table_schema = ' + QuotedStr(ASchema) + ' AND table_type = ''BASE TABLE'' ORDER BY table_name';
    dtSQLServer:
      Result := 'SELECT t.name FROM sys.tables t INNER JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = ' + QuotedStr(ASchema) + ' ORDER BY t.name';
    dtMySQL, dtSQLite, dtFireBird, dtAccess, dtNone:
      Result := '';
  else
    Result := '';
  end;
end;

function TConnection.GetTableNames(const ASchema: string): TStringArray;
var
  LSQL: string;
  LDS: TDataSet;
  LCount: Integer;
begin
  SetLength(Result, 0);
  if not Assigned(FConnection) or not IsConnected then
    Exit;
  if ASchema <> '' then
  begin
    LSQL := GetTablesSQLForType(DatabaseType, ASchema);
    if LSQL <> '' then
    begin
      LDS := ExecuteQuery(LSQL);
      try
        LCount := 0;
        while not LDS.Eof do
        begin
          if LDS.Fields.Count > 0 then
          begin
            SetLength(Result, LCount + 1);
            Result[LCount] := Trim(LDS.Fields[0].AsString);
            Inc(LCount);
          end;
          LDS.Next;
        end;
      finally
        LDS.Free;
      end;
      Exit;
    end;
  end;
  GetTableNamesFromDriver(Result);
end;

{$IF DEFINED(USE_ZEOS)}
function TConnection.ExecuteQueryZeosReadOnly(const ASQL: string): TDataSet;
var
  LQ: ZDataset.TZReadOnlyQuery;
begin
  Result := nil;
  if not Assigned(FConnection) or not IsConnected then
    raise EConnectionConnectionException.Create('Conexão não estabelecida.',
      ERR_CONNECTION_NOT_CONNECTED, 'ExecuteQueryZeosReadOnly');
  LQ := ZDataset.TZReadOnlyQuery.Create(nil);
  try
    LQ.Connection := ZConnection.TZConnection(FConnection);
    LQ.SQL.Text := ASQL;
    LQ.Open;
    Result := CreateDisconnectedCopy(TDataSet(LQ));
  finally
    LQ.Free;
  end;
end;
{$ENDIF}

procedure TConnection.GetTableNamesFromDriver(var AResult: TStringArray);
{$IF DEFINED(USE_UNIDAC)}
var
  LList: TStringList;
  LDS: TDataSet;
  i: Integer;
begin
  SetLength(AResult, 0);
  if not Assigned(FConnection) or not IsConnected then
    Exit;
  LList := TStringList.Create;
  try
    // Firebird: o GetTableNames built-in do UniDAC/InterBase nao ve tabelas
    // recem-criadas na mesma sessao (visibilidade DDL do catalogo, como no
    // FireDAC) -> TableExists(schema_version) falhava e o CREATE dava
    // "unsuccessful metadata update: table already exists". Usar SEMPRE o
    // catalogo por SQL para FB (TRIM + filtro de sistema/views), consistente
    // com o ramo FireDAC.
    if FDatabaseType = dtFireBird then
    begin
      LDS := ExecuteQuery('SELECT TRIM(rdb$relation_name) AS table_name ' +
        'FROM rdb$relations WHERE rdb$view_blr IS NULL ' +
        'AND COALESCE(rdb$system_flag, 0) = 0 ORDER BY 1');
      try
        while not LDS.Eof do
        begin
          LList.Add(Trim(LDS.Fields[0].AsString));
          LDS.Next;
        end;
      finally
        LDS.Free;
      end;
      // FB/UniDAC: o SELECT acima abre uma read-transaction que fica ATIVA e
      // bloqueia o DDL seguinte do EnsureTable ("Can't perform operation on
      // active transaction"). Fechar a leitura antes de devolver.
      if TUniConnection(FConnection).InTransaction then
        TUniConnection(FConnection).Commit;
    end
    else if FDatabaseType = dtSQLAnywhere then
    begin
      // SA nativo (fork CSL): o GetTableNames built-in do provider crasha
      // (AV - bug-598). Ler o catalogo SYS.SYSTABLE por SQL direto (mesmo
      // padrao do FB/Zeos), evitando o metadata built-in que rebenta.
      LDS := ExecuteQuery('SELECT table_name FROM SYS.SYSTABLE ' +
        'WHERE creator > 0 ORDER BY table_name');
      try
        while not LDS.Eof do
        begin
          LList.Add(Trim(LDS.Fields[0].AsString));
          LDS.Next;
        end;
      finally
        LDS.Free;
      end;
      if TUniConnection(FConnection).InTransaction then
        TUniConnection(FConnection).Commit;
    end
    else
      TUniConnection(FConnection).GetTableNames(LList);
    SetLength(AResult, LList.Count);
    for i := 0 to LList.Count - 1 do
      AResult[i] := Trim(LList[i]);
  finally
    LList.Free;
  end;
end;
{$ENDIF}
{$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)}
var
  LList: TStringList;
  LDS: TDataSet;
  i: Integer;
begin
  SetLength(AResult, 0);
  if not Assigned(FConnection) or not IsConnected then
    Exit;
  LList := TStringList.Create;
  try
    // Scope default [osMy] filtra pelo owner atual (devolvia so dbo no SQL
    // Server); [osMy, osOther] alinha com o Zeos (objetos de utilizador de
    // todos os owners, sem os de sistema).
    // Firebird: o metadata do driver FireDAC NAO ve tabelas recem-criadas na
    // mesma sessao (visibilidade DDL/transacao do catalogo) -> TableExists
    // falhava logo apos um CREATE, embora ColumnExists (via SQL) funcionasse.
    // Usar SEMPRE o catalogo por SQL para FB (consistente com GetColumnNames;
    // TRIM + filtro de sistema; sem views). Nos restantes engines/bancos o
    // metadata do FireDAC funciona ([osMy, osOther] alinha com o Zeos - objetos
    // de utilizador de todos os owners, sem os de sistema).
    if FDatabaseType = dtFireBird then
    begin
      LDS := ExecuteQuery('SELECT TRIM(rdb$relation_name) AS table_name ' +
        'FROM rdb$relations WHERE rdb$view_blr IS NULL ' +
        'AND COALESCE(rdb$system_flag, 0) = 0 ORDER BY 1');
      try
        while not LDS.Eof do
        begin
          LList.Add(Trim(LDS.Fields[0].AsString));
          LDS.Next;
        end;
      finally
        LDS.Free;
      end;
    end
    else if FDatabaseType = dtSQLite then
    begin
      // F8 Onda 8.7: o metadata de SQLite do FireDAC nao devolve de forma fiavel
      // as tabelas num ficheiro de REDE (SMB) / criadas por outro driver ->
      // TableExists ficava cego e o Sync repetia CREATE TABLE ("already exists").
      // sqlite_master e' o catalogo UNIVERSAL do SQLite (engine-agnostico) - mesmo
      // padrao (SQL directo em vez da metadata do driver) ja aplicado ao Firebird
      // acima. Objectos sqlite_* filtrados a jusante (TCatalogReader.FilterNames).
      LDS := ExecuteQuery('SELECT name FROM sqlite_master ' +
        'WHERE type = ''table'' AND name NOT LIKE ''sqlite_%'' ORDER BY name');
      try
        while not LDS.Eof do
        begin
          LList.Add(Trim(LDS.Fields[0].AsString));
          LDS.Next;
        end;
      finally
        LDS.Free;
      end;
    end
    else
      TFDConnection(FConnection).GetTableNames('', '', '', LList, [osMy, osOther]);
    SetLength(AResult, LList.Count);
    for i := 0 to LList.Count - 1 do
      AResult[i] := Trim(LList[i]);
  finally
    LList.Free;
  end;
end;
{$ENDIF}
{$IF DEFINED(USE_ZEOS)}
var
  LMeta: ZSqlMetadata.TZSQLMetadata;
  LDS: TDataSet;
  LCount: Integer;
  LCol: string;
  LName: string;
begin
  SetLength(AResult, 0);
  if not Assigned(FConnection) or not IsConnected then
    Exit;
  if FDatabaseType = dtSQLAnywhere then
  begin
    // SQL Anywhere: TZSQLMetadata (mdTables) chama internamente a stored
    // procedure de catalogo 'sp_jdbc_tables' - pode nao existir/sem permissao
    // de EXECUTE no banco alvo (SQLCODE=-265, provado contra servidor real -
    // F5 Onda 10, spike_sqlanywhere_connections.dpr). Fallback: query directa
    // ao catalogo SYS.SYSTABLE via TZReadOnlyQuery (ExecuteQueryZeosReadOnly -
    // evita a resolucao "smart" de metadados do TZQuery editavel, que tambem
    // falha pelo mesmo motivo).
    LDS := ExecuteQueryZeosReadOnly(
      'SELECT table_name FROM SYS.SYSTABLE WHERE creator > 0 ORDER BY table_name');
    try
      LCount := 0;
      while not LDS.Eof do
      begin
        LName := Trim(LDS.FieldByName('table_name').AsString);
        if LName <> '' then
        begin
          SetLength(AResult, LCount + 1);
          AResult[LCount] := LName;
          Inc(LCount);
        end;
        LDS.Next;
      end;
    finally
      LDS.Free;
    end;
    Exit;
  end;
  if FDatabaseType = dtSQLServer then
  begin
    // bug-819 (D1-A opcao a): a introspeccao de nomes de tabela do SQL Server via
    // TZSQLMetadata (mdTables) PENDURA quando uma sessao mantem um CREATE TABLE com
    // Sch-M lock por libertar (DDL do EnsureTable/TSynchronize) - o metadata-driver
    // do Zeos abre um contexto de metadata separado que colide com o Sch-M do criador
    // (mesmo padrao anti-hang do bug-768/Firebird). Fix cirurgico: ler o catalogo por
    // SQL DIRETO na PROPRIA sessao (ExecuteQueryZeosReadOnly - mesmo padrao ja usado
    // acima para SQL Anywhere e no ramo Firebird), com WITH (NOLOCK) para nao bloquear
    // em Sch-M (dirty-read aceitavel para enumeracao de nomes; D1-A opcao a). sys.tables
    // ja lista SO tabelas de utilizador de todos os schemas, alinhado com [osMy, osOther]
    // do ramo FireDAC. Nao mexe no transaction handling do Sync (opcao b, nao escolhida):
    // a tabela continua a exigir disconnect do criador para libertar o Sch-M a sessoes
    // EXTERNAS - esta correcao cobre a introspeccao do proprio modulo, nao terceiros.
    LDS := ExecuteQueryZeosReadOnly(
      'SELECT t.name AS table_name FROM sys.tables t WITH (NOLOCK) ORDER BY t.name');
    try
      LCount := 0;
      while not LDS.Eof do
      begin
        LName := Trim(LDS.FieldByName('table_name').AsString);
        if LName <> '' then
        begin
          SetLength(AResult, LCount + 1);
          AResult[LCount] := LName;
          Inc(LCount);
        end;
        LDS.Next;
      end;
    finally
      LDS.Free;
    end;
    Exit;
  end;
  LMeta := ZSqlMetadata.TZSQLMetadata.Create(nil);
  try
    LMeta.Connection := ZConnection.TZConnection(FConnection);
    LMeta.MetadataType := mdTables;
    LMeta.Open;
    LCount := 0;
    if LMeta.FindField('TABLE_NAME') <> nil then
      LCol := 'TABLE_NAME'
    else if LMeta.FindField('TABLE_NAME_') <> nil then
      LCol := 'TABLE_NAME_'
    else if LMeta.FieldCount > 0 then
      LCol := LMeta.Fields[0].FieldName
    else
      LCol := '';
    while (LCol <> '') and not LMeta.Eof do
    begin
      LName := Trim(LMeta.FieldByName(LCol).AsString);
      if (LName <> '') and (Pos('MSys', LName) <> 1) then
      begin
        SetLength(AResult, LCount + 1);
        AResult[LCount] := LName;
        Inc(LCount);
      end;
      LMeta.Next;
    end;
  finally
    LMeta.Free;
  end;
end;
{$ENDIF}
{$IF DEFINED(USE_SQLDB)}
var
  LList: TStringList;
  i: Integer;
begin
  SetLength(AResult, 0);
  if not Assigned(FConnection) or not IsConnected then
    Exit;
  LList := TStringList.Create;
  try
    // era stub (devolvia sempre vazio) — paridade com os outros engines:
    // lista via fcl-db (sem tabelas de sistema).
    TSQLConnection(FConnection).GetTableNames(LList, False);
    SetLength(AResult, LList.Count);
    for i := 0 to LList.Count - 1 do
      AResult[i] := Trim(LList[i]);
  finally
    LList.Free;
  end;
end;
{$ENDIF}

function GetDatabasesSQLForType(const ADatabaseType: TDatabaseTypes): string;
begin
  case ADatabaseType of
    dtPostgreSQL:
      Result := 'SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname';
    dtMySQL:
      Result := 'SELECT schema_name FROM information_schema.schemata ORDER BY schema_name';
    dtSQLServer:
      Result := 'SELECT name FROM sys.databases ORDER BY name';
    dtSQLite, dtFireBird, dtAccess:
      Result := '';
  else
    Result := '';
  end;
end;

function TConnection.GetDatabaseNames: TStringArray;
var
  LSQL: string;
  LDS: TDataSet;
  LCount: Integer;
begin
  SetLength(Result, 0);
  if not Assigned(FConnection) or not IsConnected then
    Exit;
  LSQL := GetDatabasesSQLForType(DatabaseType);
  if LSQL = '' then
  begin
    if FDatabase <> '' then
    begin
      SetLength(Result, 1);
      Result[0] := FDatabase;
    end;
    Exit;
  end;
  LDS := ExecuteQuery(LSQL);
  try
    LCount := 0;
    while not LDS.Eof do
    begin
      if LDS.Fields.Count > 0 then
      begin
        SetLength(Result, LCount + 1);
        Result[LCount] := Trim(LDS.Fields[0].AsString);
        Inc(LCount);
      end;
      LDS.Next;
    end;
  finally
    LDS.Free;
  end;
end;

function GetSchemasSQLForType(const ADatabaseType: TDatabaseTypes; const ADatabase: string): string;
begin
  case ADatabaseType of
    dtPostgreSQL:
      if ADatabase <> '' then
        Result := 'SELECT DISTINCT schema_name FROM information_schema.schemata WHERE catalog_name = ' + QuotedStr(ADatabase) + ' ORDER BY schema_name'
      else
        Result := 'SELECT DISTINCT schema_name FROM information_schema.schemata ORDER BY schema_name';
    dtMySQL:
      Result := ''; { MySQL: schema = database }
    dtSQLServer:
      Result := 'SELECT name FROM sys.schemas ORDER BY name';
    dtSQLite, dtFireBird, dtAccess:
      Result := '';
  else
    Result := '';
  end;
end;

function TConnection.GetSchemaNames(const ADatabase: string): TStringArray;
var
  LSQL: string;
  LDS: TDataSet;
  LCount: Integer;
  LDb: string;
  LName: string;
  LSystemSchemas: array of string;
  j: Integer;
  LSkip: Boolean;
begin
  SetLength(Result, 0);
  if not Assigned(FConnection) or not IsConnected then
    Exit;
  LDb := Trim(ADatabase);
  if LDb = '' then
    LDb := FDatabase
  else if not SameText(LDb, FDatabase) then
    Exit;
  LSQL := GetSchemasSQLForType(DatabaseType, LDb);
  if LSQL = '' then
    Exit;
  LDS := ExecuteQuery(LSQL);
  try
    LCount := 0;
    if DatabaseType = dtPostgreSQL then
      SetLength(LSystemSchemas, 3)
    else
      SetLength(LSystemSchemas, 0);
    if DatabaseType = dtPostgreSQL then
    begin
      LSystemSchemas[0] := 'information_schema';
      LSystemSchemas[1] := 'pg_catalog';
      LSystemSchemas[2] := 'pg_toast';
    end;
    while not LDS.Eof do
    begin
      if LDS.Fields.Count > 0 then
      begin
        LName := Trim(LDS.Fields[0].AsString);
        LSkip := False;
        if DatabaseType = dtPostgreSQL then
          for j := 0 to High(LSystemSchemas) do
            if SameText(LName, LSystemSchemas[j]) then
            begin
              LSkip := True;
              Break;
            end;
        if not LSkip and (LName <> '') then
        begin
          SetLength(Result, LCount + 1);
          Result[LCount] := LName;
          Inc(LCount);
        end;
      end;
      LDS.Next;
    end;
  finally
    LDS.Free;
  end;
end;

{ Separa um nome possivelmente qualificado (catalog.schema.tabela | schema.tabela).
  O GetTableNames do FireDAC devolve nomes qualificados para objetos fora do
  schema/owner atual; as queries de metadados casam por nome simples. ASchema
  só é preenchido a partir da qualificação quando vem vazio do caller. }
procedure SplitQualifiedTableName(const AQualified: string;
  var ATable, ASchema: string);
var
  LDot: Integer;
  LQualifier: string;
begin
  ATable := AQualified;
  LDot := LastDelimiter('.', ATable);
  if LDot <= 0 then
    Exit;
  LQualifier := Copy(ATable, 1, LDot - 1);
  ATable := Copy(ATable, LDot + 1, MaxInt);
  if Trim(ASchema) = '' then
    ASchema := Copy(LQualifier, LastDelimiter('.', LQualifier) + 1, MaxInt);
end;

function GetColumnsSQLForType(const ADatabaseType: TDatabaseTypes; const ATableName, ASchema: string): string;
var
  LSchema: string;
  LTable: string;
begin
  Result := '';
  if ATableName = '' then
    Exit;
  LTable := QuotedStr(ATableName);
  LSchema := ASchema;
  // Default 'public' e especifico do PostgreSQL; nos restantes bancos, schema
  // vazio significa "sem filtro de schema" (SQL Server usa o branch sem s.name).
  if (LSchema = '') and (ADatabaseType = dtPostgreSQL) then
    LSchema := 'public';
  case ADatabaseType of
    dtPostgreSQL:
      Result := 'SELECT column_name FROM information_schema.columns WHERE table_schema = ' + QuotedStr(LSchema) + ' AND table_name = ' + LTable + ' ORDER BY ordinal_position';
    dtMySQL:
      Result := 'SELECT column_name FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = ' + LTable + ' ORDER BY ordinal_position';
    dtSQLServer:
      if LSchema <> '' then
        Result := 'SELECT c.name FROM sys.columns c INNER JOIN sys.tables t ON c.object_id = t.object_id INNER JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = ' + QuotedStr(LSchema) + ' AND t.name = ' + LTable + ' ORDER BY c.column_id'
      else
        Result := 'SELECT c.name FROM sys.columns c INNER JOIN sys.tables t ON c.object_id = t.object_id WHERE t.name = ' + LTable + ' ORDER BY c.column_id';
    dtSQLite:
      Result := 'PRAGMA table_info(' + LTable + ')';
    dtFireBird:
      // Onda D (bug-578): aceitar tanto o nome literal (tabela criada com aspas
      // = case preservado, minusculas) como o UPPERCASE (tabela sem aspas =
      // default do Firebird). TRIM porque RDB$RELATION_NAME e CHAR(31/63) padded.
      Result := 'SELECT rdb$field_name FROM rdb$relation_fields WHERE (TRIM(rdb$relation_name) = ' + QuotedStr(Trim(ATableName)) + ' OR TRIM(rdb$relation_name) = ' + QuotedStr(UpperCase(Trim(ATableName))) + ') ORDER BY rdb$field_position';
    dtSQLAnywhere:
      // F5 Onda 10 - catalogo SYS.SYSTABCOL/SYS.SYSTAB, confirmado contra
      // servidor real (16/07). Schema/owner NAO filtrado (mesmo criterio do
      // Firebird acima - sem schemas nativos relevantes aqui na pratica).
      // Executar via ExecuteQueryZeosReadOnly (TZReadOnlyQuery), NAO
      // ExecuteQuery generico - ver comentario em GetColumnNames.
      Result := 'SELECT c.column_name FROM SYS.SYSTABCOL c ' +
        'JOIN SYS.SYSTAB t ON t.table_id = c.table_id ' +
        'WHERE t.table_name = ' + LTable + ' ORDER BY c.column_id';
    dtAccess, dtNone:
      Result := '';
  else
    Result := '';
  end;
end;

function GetTableStructureSQLForType(const ADatabaseType: TDatabaseTypes; const ATableName, ASchema: string): string;
var
  LSchema: string;
  LTable: string;
begin
  Result := '';
  if ATableName = '' then
    Exit;
  LTable := QuotedStr(ATableName);
  LSchema := ASchema;
  // Default 'public' e especifico do PostgreSQL; nos restantes bancos, schema
  // vazio significa "sem filtro de schema" (SQL Server usa o branch sem s.name).
  if (LSchema = '') and (ADatabaseType = dtPostgreSQL) then
    LSchema := 'public';
  case ADatabaseType of
    dtPostgreSQL:
      Result := 'SELECT c.column_name, c.data_type, c.is_nullable, ' +
        'COALESCE((SELECT 1 FROM information_schema.key_column_usage k JOIN information_schema.table_constraints tc ON tc.constraint_name = k.constraint_name AND tc.table_schema = k.table_schema ' +
        'WHERE tc.constraint_type = ''PRIMARY KEY'' AND tc.table_schema = c.table_schema AND tc.table_name = c.table_name AND k.column_name = c.column_name LIMIT 1), 0) AS pkey, ' +
        '(SELECT k.constraint_name FROM information_schema.key_column_usage k INNER JOIN information_schema.referential_constraints rc ON rc.constraint_schema = k.constraint_schema AND rc.constraint_name = k.constraint_name ' +
        'WHERE k.table_schema = c.table_schema AND k.table_name = c.table_name AND k.column_name = c.column_name LIMIT 1) AS fk_constraint_name, ' +
        '(SELECT (ccu.table_schema || ''.'' || ccu.table_name) FROM information_schema.key_column_usage k INNER JOIN information_schema.referential_constraints rc ON rc.constraint_schema = k.constraint_schema AND rc.constraint_name = k.constraint_name ' +
        'INNER JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_schema = rc.unique_constraint_schema AND ccu.constraint_name = rc.unique_constraint_name ' +
        'WHERE k.table_schema = c.table_schema AND k.table_name = c.table_name AND k.column_name = c.column_name LIMIT 1) AS fk_referenced_table, ' +
        '(SELECT ccu.column_name FROM information_schema.key_column_usage k INNER JOIN information_schema.referential_constraints rc ON rc.constraint_schema = k.constraint_schema AND rc.constraint_name = k.constraint_name ' +
        'INNER JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_schema = rc.unique_constraint_schema AND ccu.constraint_name = rc.unique_constraint_name ' +
        'WHERE k.table_schema = c.table_schema AND k.table_name = c.table_name AND k.column_name = c.column_name LIMIT 1) AS fk_referenced_column ' +
        'FROM information_schema.columns c WHERE c.table_schema = ' + QuotedStr(LSchema) + ' AND c.table_name = ' + LTable + ' ORDER BY c.ordinal_position';
    dtMySQL:
      if LSchema = '' then
        Result := 'SELECT column_name, data_type, is_nullable, CASE WHEN column_key = ''PRI'' THEN 1 ELSE 0 END AS pkey ' +
          'FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = ' + LTable + ' ORDER BY ordinal_position'
      else
        Result := 'SELECT column_name, data_type, is_nullable, CASE WHEN column_key = ''PRI'' THEN 1 ELSE 0 END AS pkey ' +
          'FROM information_schema.columns WHERE table_schema = ' + QuotedStr(LSchema) + ' AND table_name = ' + LTable + ' ORDER BY ordinal_position';
    dtSQLServer:
      if LSchema <> '' then
        Result := 'SELECT c.name AS column_name, t.name AS data_type, CASE WHEN c.is_nullable = 1 THEN ''YES'' ELSE ''NO'' END AS is_nullable, ' +
          'CASE WHEN pk.column_id IS NOT NULL THEN 1 ELSE 0 END AS pkey FROM sys.columns c INNER JOIN sys.types t ON c.user_type_id = t.user_type_id ' +
          'INNER JOIN sys.tables tb ON c.object_id = tb.object_id INNER JOIN sys.schemas s ON tb.schema_id = s.schema_id AND s.name = ' + QuotedStr(LSchema) + ' ' +
          'LEFT JOIN (SELECT ic.object_id, ic.column_id FROM sys.index_columns ic INNER JOIN sys.indexes i ON ic.object_id = i.object_id AND ic.index_id = i.index_id AND i.is_primary_key = 1) pk ON c.object_id = pk.object_id AND c.column_id = pk.column_id ' +
          'WHERE tb.name = ' + LTable + ' ORDER BY c.column_id'
      else
        Result := 'SELECT c.name AS column_name, t.name AS data_type, CASE WHEN c.is_nullable = 1 THEN ''YES'' ELSE ''NO'' END AS is_nullable, ' +
          'CASE WHEN pk.column_id IS NOT NULL THEN 1 ELSE 0 END AS pkey FROM sys.columns c INNER JOIN sys.types t ON c.user_type_id = t.user_type_id ' +
          'INNER JOIN sys.tables tb ON c.object_id = tb.object_id ' +
          'LEFT JOIN (SELECT ic.object_id, ic.column_id FROM sys.index_columns ic INNER JOIN sys.indexes i ON ic.object_id = i.object_id AND ic.index_id = i.index_id AND i.is_primary_key = 1) pk ON c.object_id = pk.object_id AND c.column_id = pk.column_id ' +
          'WHERE tb.name = ' + LTable + ' ORDER BY c.column_id';
    dtSQLite:
      Result := 'SELECT name AS column_name, type AS data_type, CASE WHEN "notnull" = 0 THEN ''YES'' ELSE ''NO'' END AS is_nullable, pk AS pkey FROM pragma_table_info(' + LTable + ') ORDER BY cid';
    dtFireBird:
      Result := 'SELECT TRIM(rf.RDB$FIELD_NAME) AS column_name, ' +
        'UPPER(CASE f.RDB$FIELD_TYPE WHEN 7 THEN ''SMALLINT'' WHEN 8 THEN ''INTEGER'' WHEN 10 THEN ''FLOAT'' WHEN 12 THEN ''DATE'' WHEN 13 THEN ''TIME'' WHEN 14 THEN ''CHAR'' WHEN 16 THEN ''BIGINT'' ' +
        'WHEN 27 THEN ''DOUBLE PRECISION'' WHEN 35 THEN ''TIMESTAMP'' WHEN 37 THEN ''VARCHAR'' WHEN 261 THEN ''BLOB'' ELSE ''UNKNOWN'' END) AS data_type, ' +
        'CASE WHEN rf.RDB$NULL_FLAG = 1 THEN ''NO'' ELSE ''YES'' END AS is_nullable, ' +
        'CASE WHEN (SELECT 1 FROM RDB$RELATION_CONSTRAINTS rc JOIN RDB$INDEX_SEGMENTS ise ON rc.RDB$INDEX_NAME = ise.RDB$INDEX_NAME ' +
        'WHERE rc.RDB$CONSTRAINT_TYPE = ''PRIMARY KEY'' AND rc.RDB$RELATION_NAME = rf.RDB$RELATION_NAME AND TRIM(ise.RDB$FIELD_NAME) = TRIM(rf.RDB$FIELD_NAME)) IS NOT NULL THEN 1 ELSE 0 END AS pkey ' +
        'FROM RDB$RELATION_FIELDS rf JOIN RDB$FIELDS f ON rf.RDB$FIELD_SOURCE = f.RDB$FIELD_NAME WHERE (TRIM(rf.RDB$RELATION_NAME) = ' + QuotedStr(Trim(ATableName)) + ' OR TRIM(rf.RDB$RELATION_NAME) = ' + QuotedStr(UpperCase(Trim(ATableName))) + ') ORDER BY rf.RDB$FIELD_POSITION';
    dtSQLAnywhere:
      // F5 Onda 10 - base_type_str da SYS.SYSTABCOL ja vem pronto para leitura
      // ('char(128)', 'unsigned int', 'timestamp', ...), confirmado contra
      // servidor real. PK NAO detectada (pkey sempre 0) - deteccao via
      // SYS.SYSIDX/SYS.SYSIDXCOL nao foi validada nesta sessao (a tabela de
      // teste acessivel ao EXTERNO nao tinha indice registado no catalogo);
      // follow-up documentado no relatorio/plano da Onda 10.
      Result := 'SELECT c.column_name, CAST(c.base_type_str AS VARCHAR(255)) AS data_type, ' +
        'CAST(CASE WHEN c."nulls" = ''Y'' THEN ''YES'' ELSE ''NO'' END AS VARCHAR(3)) AS is_nullable, ' +
        'CAST(0 AS INTEGER) AS pkey ' +
        'FROM SYS.SYSTABCOL c JOIN SYS.SYSTAB t ON t.table_id = c.table_id ' +
        'WHERE t.table_name = ' + LTable + ' ORDER BY c.column_id';
    dtAccess, dtNone:
      Result := '';
  else
    Result := '';
  end;
end;

function TConnection.GetColumnNames(const ATableName: string; const ASchema: string): TStringArray;
var
  LSQL: string;
  LDS: TDataSet;
  LCount: Integer;
  LColIndex: Integer;
  LSchema: string;
  LTable: string;
  LResolveSchema: string;
  LCallerProvidedSchema: Boolean;
begin
  SetLength(Result, 0);
  if not Assigned(FConnection) or not IsConnected or (ATableName = '') then
    Exit;
  LCallerProvidedSchema := (Trim(ASchema) <> '');
  LSchema := ASchema;
  SplitQualifiedTableName(ATableName, LTable, LSchema);
  if not LCallerProvidedSchema then
    LCallerProvidedSchema := Trim(LSchema) <> ''; // schema veio da qualificação
  if (LSchema = '') and (DatabaseType = dtPostgreSQL) then
  begin
    LSchema := FSchema;
    if LSchema = '' then
      LSchema := 'public';
  end;
  LSQL := GetColumnsSQLForType(DatabaseType, LTable, LSchema);
  if LSQL = '' then
  begin
    { Access/Jet: sem SQL de catalogo de colunas (MSysColumns protegido) -> fallback
      UNIVERSAL: abre 'SELECT * FROM [t] WHERE 1=0' e le os NOMES dos campos do
      dataset. Re-consulta a estrutura VIVA (ve colunas recem-adicionadas, ao
      contrario de metadata cacheada pelo driver). Sem linhas -> so a estrutura. }
    if DatabaseType = dtAccess then
    begin
      LDS := ExecuteQuery('SELECT * FROM [' + LTable + '] WHERE 1=0');
      try
        for LColIndex := 0 to LDS.Fields.Count - 1 do
        begin
          SetLength(Result, Length(Result) + 1);
          Result[High(Result)] := Trim(LDS.Fields[LColIndex].FieldName);
        end;
      finally
        LDS.Free;
      end;
    end;
    Exit;
  end;
  {$IF DEFINED(USE_ZEOS)}
  if DatabaseType = dtSQLAnywhere then
    LDS := ExecuteQueryZeosReadOnly(LSQL)
  else
  {$ENDIF}
    LDS := ExecuteQuery(LSQL);
  try
    LCount := 0;
    if (DatabaseType = dtSQLite) and (Pos('PRAGMA', LSQL) > 0) then
      LColIndex := 1
    else
      LColIndex := 0;
    while not LDS.Eof do
    begin
      if LDS.Fields.Count > LColIndex then
      begin
        SetLength(Result, LCount + 1);
        Result[LCount] := Trim(LDS.Fields[LColIndex].AsString);
        Inc(LCount);
      end;
      LDS.Next;
    end;
  finally
    LDS.Free;
  end;
  { Fallback only when caller did NOT pass schema: resolve schema and retry (e.g. table in information_schema). }
  if (DatabaseType = dtPostgreSQL) and (Length(Result) = 0) and not LCallerProvidedSchema then
  begin
    LSQL := 'SELECT table_schema FROM information_schema.tables WHERE table_name = ' + QuotedStr(LTable) + ' LIMIT 1';
    LDS := ExecuteQuery(LSQL);
    try
      if not LDS.Eof and (LDS.Fields.Count > 0) then
      begin
        LResolveSchema := Trim(LDS.Fields[0].AsString);
        if LResolveSchema <> '' then
        begin
          LSQL := GetColumnsSQLForType(DatabaseType, LTable, LResolveSchema);
          if LSQL <> '' then
          begin
            LDS.Free;
            LDS := nil;
            LDS := ExecuteQuery(LSQL);
            try
              LCount := 0;
              while not LDS.Eof do
              begin
                if LDS.Fields.Count > 0 then
                begin
                  SetLength(Result, LCount + 1);
                  Result[LCount] := Trim(LDS.Fields[0].AsString);
                  Inc(LCount);
                end;
                LDS.Next;
              end;
            finally
              LDS.Free;
              LDS := nil;
            end;
          end;
        end;
      end;
    finally
      if LDS <> nil then
        LDS.Free;
    end;
  end;
end;

function TConnection.GetTableStructure(const ATableName: string; const ASchema: string): TArray<TDatabaseFields>;
var
  LSQL: string;
  LDS: TDataSet;
  LSchema: string;
  LTable: string;
  LResolveSchema: string;
  LCallerProvidedSchema: Boolean;
  LList: TArray<TDatabaseFields>;
  LCount: Integer;
  FColName, FDataType, FNullable, FPkey, FFkConstraint, FFkRefTable, FFkRefCol: TField;
begin
  SetLength(Result, 0);
  if not Assigned(FConnection) or not IsConnected or (ATableName = '') then
    Exit;
  LCallerProvidedSchema := (Trim(ASchema) <> '');
  LSchema := ASchema;
  SplitQualifiedTableName(ATableName, LTable, LSchema);
  if not LCallerProvidedSchema then
    LCallerProvidedSchema := Trim(LSchema) <> ''; // schema veio da qualificação
  if (LSchema = '') and (DatabaseType = dtPostgreSQL) then
  begin
    LSchema := FSchema;
    if LSchema = '' then
      LSchema := 'public';
  end;
  LSQL := GetTableStructureSQLForType(DatabaseType, LTable, LSchema);
  if LSQL = '' then
  begin
    { bug-969 (30/07/2026, .wolf/buglog.json): Access/Jet nao tem SQL de
      catalogo de colunas fiavel (MSysColumns protegido) - o "case" acima
      devolve sempre '' para dtAccess, o que fazia esta funcao (e por
      extensao TCatalogReader.TableStructure) devolver SEMPRE 0 colunas,
      mesmo com TableExists=True (confirmado com ligacao FRESCA - nao e'
      cache/timing). Mesma familia do fallback ja aplicado a GetColumnNames
      (commit 4f9234f7, 18/07/2026): reabre a estrutura VIVA via
      'SELECT * FROM [t] WHERE 1=0' e le os metadados de TField (nome, tipo,
      nullable, posicao). PKey NAO detectada (fica 0) - mesma limitacao ja
      documentada para dtSQLAnywhere neste ficheiro (introspeccao de PK via
      catalogo Access nao e' fiavel/nao foi validada; ITable/EntityManager
      continuam a funcionar com PK definida do lado fluente). }
    if DatabaseType = dtAccess then
    begin
      LDS := ExecuteQuery('SELECT * FROM [' + LTable + '] WHERE 1=0');
      try
        SetLength(LList, LDS.Fields.Count);
        for LCount := 0 to LDS.Fields.Count - 1 do
        begin
          LList[LCount].Table := LTable;
          LList[LCount].Column := Trim(LDS.Fields[LCount].FieldName);
          LList[LCount].ColumnType := UpperCase(GetEnumName(TypeInfo(TFieldType), Ord(LDS.Fields[LCount].DataType)));
          LList[LCount].ColumnTypeCode := Ord(LDS.Fields[LCount].DataType);
          if LDS.Fields[LCount].Required then
            LList[LCount].IsNull := 'NO'
          else
            LList[LCount].IsNull := 'YES';
          LList[LCount].Value := '';
          LList[LCount].ToDefault := '';
          LList[LCount].IsChanged := 0;
          LList[LCount].IsPKey := 0; // best-effort - ver comentario acima
          LList[LCount].IsIdentity := 0;
          LList[LCount].Position := LCount + 1;
          LList[LCount].ConstraintName := '';
          LList[LCount].ReferencedTable := '';
          LList[LCount].ReferencedColumn := '';
          LList[LCount].OnUpdateRule := '';
          LList[LCount].OnDeleteRule := '';
          LList[LCount].Description := '';
        end;
        Result := LList;
      finally
        LDS.Free;
      end;
    end;
    Exit;
  end;
  {$IF DEFINED(USE_ZEOS)}
  if DatabaseType = dtSQLAnywhere then
    LDS := ExecuteQueryZeosReadOnly(LSQL)
  else
  {$ENDIF}
    LDS := ExecuteQuery(LSQL);
  try
    LCount := 0;
    SetLength(LList, 0);
    while not LDS.Eof do
    begin
      SetLength(LList, LCount + 1);
      LList[LCount].Table := LTable;
      LList[LCount].Column := '';
      LList[LCount].ColumnType := '';
      LList[LCount].ColumnTypeCode := 0;
      LList[LCount].IsNull := 'YES';
      LList[LCount].Value := '';
      LList[LCount].ToDefault := '';
      LList[LCount].IsChanged := 0;
      LList[LCount].IsPKey := 0;
      LList[LCount].Position := LCount + 1;
      LList[LCount].ConstraintName := '';
      LList[LCount].ReferencedTable := '';
      LList[LCount].ReferencedColumn := '';
      LList[LCount].OnUpdateRule := '';
      LList[LCount].OnDeleteRule := '';
      FColName := LDS.FindField('column_name');
      if FColName <> nil then
        LList[LCount].Column := Trim(FColName.AsString);
      FDataType := LDS.FindField('data_type');
      if FDataType <> nil then
        LList[LCount].ColumnType := Trim(FDataType.AsString);
      FNullable := LDS.FindField('is_nullable');
      if FNullable <> nil then
        if SameText(Trim(FNullable.AsString), 'YES') then
          LList[LCount].IsNull := 'YES'
        else
          LList[LCount].IsNull := 'NO';
      FPkey := LDS.FindField('pkey');
      if FPkey <> nil then
        { AsString->StrToIntDef em vez de AsInteger: em FPC+UniDAC+SQLite o campo
          "pkey" (pk AS pkey do pragma_table_info) vem com um tipo que o AsInteger
          rejeita ("Invalid type conversion to Integer in field pkey"); a leitura
          por texto e' portavel em todos os engines/plataformas. }
        LList[LCount].IsPKey := StrToIntDef(Trim(FPkey.AsString), 0);
      FFkConstraint := LDS.FindField('fk_constraint_name');
      if FFkConstraint <> nil then
        LList[LCount].ConstraintName := Trim(FFkConstraint.AsString);
      FFkRefTable := LDS.FindField('fk_referenced_table');
      if FFkRefTable <> nil then
        LList[LCount].ReferencedTable := Trim(FFkRefTable.AsString);
      FFkRefCol := LDS.FindField('fk_referenced_column');
      if FFkRefCol <> nil then
        LList[LCount].ReferencedColumn := Trim(FFkRefCol.AsString);
      Inc(LCount);
      LDS.Next;
    end;
    Result := LList;
  finally
    LDS.Free;
  end;
  if (DatabaseType = dtPostgreSQL) and (Length(Result) = 0) and not LCallerProvidedSchema then
  begin
    LSQL := 'SELECT table_schema FROM information_schema.tables WHERE table_name = ' + QuotedStr(LTable) + ' LIMIT 1';
    LDS := ExecuteQuery(LSQL);
    try
      if not LDS.Eof and (LDS.Fields.Count > 0) then
      begin
        LResolveSchema := Trim(LDS.Fields[0].AsString);
        if LResolveSchema <> '' then
          Result := GetTableStructure(LTable, LResolveSchema);
      end;
    finally
      LDS.Free;
    end;
  end;
end;

{ BindParams — vincula AParams a um objeto query nativo (engine-specific).
  Convenção de nomes: :param0, :param1, ... para FireDAC/UniDAC/SQLdb;
  Zeos usa índice posicional (Params[I]) após NormalizeParams substituir :paramN por ?. }
procedure TConnection.BindParams(AQuery: TObject; const AParams: array of Variant);
var
  I: Integer;
{$IF DEFINED(USE_UNIDAC)}
  LFSInvariantSQLAnywhere968: TFormatSettings;
{$ENDIF}
begin
  if (AQuery = nil) or (Length(AParams) = 0) then
    Exit;
{$IF DEFINED(USE_UNIDAC)}
  { bug-968: "." fixo, NUNCA o locale do processo/thread - so' usado no ramo
    dtSQLAnywhere abaixo (varSingle/varDouble/varCurrency). Copia o
    FormatSettings corrente so' para herdar os restantes campos e forca o
    separador decimal - nao mexe no FormatSettings global. }
  LFSInvariantSQLAnywhere968 := {$IFDEF FPC}DefaultFormatSettings{$ELSE}FormatSettings{$ENDIF};
  LFSInvariantSQLAnywhere968.DecimalSeparator := '.';
  LFSInvariantSQLAnywhere968.ThousandSeparator := #0;

  for I := 0 to High(AParams) do
  begin
    { Tipar o param ANTES do Value: Variant sem DataType no UniDAC 10.3+SQL Server
      sobe como sql_variant e falha em colunas varchar/datetime (LogMigration). }
    with TUniQuery(AQuery).ParamByName('param' + IntToStr(I)) do
    begin
      case VarType(AParams[I]) and VarTypeMask of
        varSmallint, varInteger, varShortInt, varByte, varWord, varLongWord:
          DataType := ftInteger;
        varInt64:
          DataType := ftLargeint;
        varSingle, varDouble, varCurrency:
          { bug-968 (fix de raiz): dbcapi.dll (client library nativa do SQL
            Anywhere) falha a converter o Double nativo respeitando o locale
            do processo/thread - EUniError "Cannot convert '10,5' to double"
            em locale pt-BR (virgula decimal). setlocale(LC_NUMERIC,'C') via
            msvcrt E' SetThreadLocale (API Win32/NLS) foram AMBOS testados e
            REFUTADOS (spikes bug-968, 1a e 2a rodada de investigacao,
            30/08/2026) - o erro persiste identico com qualquer um dos dois.
            Bindar como STRING com "." fixo (nunca o locale) contorna a
            conversao nativa binaria problematica - o parser SQL do proprio
            motor SQL Anywhere e' sempre "." independente de locale.
            Validado empiricamente: spike isolado com INSERT + verificacao
            de persistencia por 2a conexao independente (cross-connection),
            valor 10.5 lido de volta correctamente em ambas as variantes
            (ftString e ftWideString). Gated so' a dtSQLAnywhere - outros
            engines via UniDAC (SQL Server, PostgreSQL, MySQL, ...) mantem o
            binding nativo Double inalterado. }
          if DatabaseType = dtSQLAnywhere then
            DataType := ftWideString
          else
            DataType := ftFloat;
        varBoolean:
          DataType := ftBoolean;
        varDate:
          DataType := ftDateTime;
        varString, varUString, varOleStr:
          DataType := ftWideString;
      end;
      if not VarIsEmpty(AParams[I]) and not VarIsNull(AParams[I]) then
      begin
        if (DatabaseType = dtSQLAnywhere) and
           ((VarType(AParams[I]) and VarTypeMask) in [varSingle, varDouble, varCurrency]) then
          Value := FormatFloat('0.0###############', Double(AParams[I]), LFSInvariantSQLAnywhere968)
        else
          Value := AParams[I];
      end
      else
        Clear;
    end;
  end;
{$ELSE}
  {$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)}
  for I := 0 to High(AParams) do
    TFDQuery(AQuery).ParamByName('param' + IntToStr(I)).Value := AParams[I];
  {$ELSE}
    {$IF DEFINED(USE_ZEOS)}
    { TZQuery gera TParams pelo ParamCheck de :nome — bind por nome, como os
      demais engines (Params[I] posicional falhava: '?' não cria parâmetros).
      bug-820 (fix de raiz): TIPAR o param ANTES do Value (mesmo padrao do ramo
      UniDAC acima). Um Variant SEM DataType (esp. varDate/varBoolean) deixa o
      Zeos inferir o tipo do parametro; no ramo dblib/SACAPI (SQL Anywhere via
      asa_capi, e tambem FreeTDS/sybase) isso corrompia o heap em win64 (AV em
      System.SysGetMem - raw Zeos com params TIPADOS nao reproduz; so o Variant
      cru do BindParams). Tipar explicitamente elimina a inferencia -> mesma
      robustez que o UniDAC (que ja tipava e por isso passava 13/13 no MESMO
      dbcapi.dll). Principio do owner: trabalhar o mais tipado possivel sempre. }
    for I := 0 to High(AParams) do
      { bug-1171: castar para o ANCESTRAL COMUM (TZAbstractRODataset) e nao para
        TZQuery - o ramo SQL Anywhere passa aqui um TZReadOnlyQuery, que NAO
        descende de TZQuery (ZDataset.pas: TZReadOnlyQuery = class(TZAbstractRODataSet)).
        ParamByName vive em TZAbstractRODataset, logo serve os dois sem duplicar
        esta tipagem de parametros. }
      with ZAbstractRODataset.TZAbstractRODataset(AQuery).ParamByName('param' + IntToStr(I)) do
      begin
        case VarType(AParams[I]) and VarTypeMask of
          varSmallint, varInteger, varShortInt, varByte, varWord, varLongWord:
            DataType := ftInteger;
          varInt64:
            DataType := ftLargeint;
          varSingle, varDouble, varCurrency:
            DataType := ftFloat;
          varBoolean:
            DataType := ftBoolean;
          varDate:
            DataType := ftDateTime;
          varString, varUString, varOleStr:
            DataType := ftWideString;
        end;
        if not VarIsEmpty(AParams[I]) and not VarIsNull(AParams[I]) then
          Value := AParams[I]
        else
          Clear;
      end;
    {$ELSE} {$IF DEFINED(USE_SQLDB)}
    // TParam do fcl-db nao tem AsVariant (so no Delphi via variants); Value e
    // a propriedade Variant portavel.
    for I := 0 to High(AParams) do
      TSQLQuery(AQuery).Params.ParamByName('param' + IntToStr(I)).Value := AParams[I];
    {$ENDIF} {$ENDIF}
  {$ENDIF}
{$ENDIF}
end;

{ NormalizeParams — converte :param0, :param1, ... para o formato do engine.
  TODOS os engines suportados (Zeos incluído) aceitam :paramN nativamente:
  o TZQuery gera TParams pelo ParamCheck de :nome — substituir por '?' deixava
  Params vazio (fix 1.0.20). Mantida como ponto de extensão para engines futuros. }
function TConnection.NormalizeParams(const ASQL: string): string;
begin
  Result := ASQL;
end;

{ ExecuteQuery (parametrizado) — abre um dataset com parâmetros vinculados.
  O caller é responsável por liberar o TDataSet retornado (padrão do projeto). }
function TConnection.ExecuteQuery(const ASQL: string;
  const AParams: array of Variant): TDataSet;
var
  LSQL: string;
  LQ: TObject;
begin
  Result := nil;
  if not Assigned(FConnection) or not IsConnected then
    raise EConnectionConnectionException.Create('Conexão não estabelecida.',
      ERR_CONNECTION_NOT_CONNECTED, 'ExecuteQuery');
  LSQL := NormalizeParams(ASQL);
{$IF DEFINED(USE_UNIDAC)}
  LQ := TUniQuery.Create(nil);
  try
    TUniQuery(LQ).Connection := TUniConnection(FConnection);
    TUniQuery(LQ).SQL.Text := LSQL;
    { Sem Prepare antes do bind: com Prepared=True o UniDAC 10.3 tipa Variant
      como sql_variant e o SQL Server rejeita (varchar/datetime) —
      "Implicit conversion from data type sql_variant to varchar is not allowed"
      (EnsureTable/LogMigration). Mesmo racional FireDAC/Zeos (1.0.22 / -335). }
    BindParams(LQ, AParams);
    TUniQuery(LQ).Open;
    { Etapa A1: devolve copia em memoria DESCONECTADA; a fisica liberta-se ja }
    Result := CreateDisconnectedCopy(TDataSet(LQ));
  finally
    TUniQuery(LQ).Free;
  end;
{$ENDIF}
{$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)}
  LQ := TFDQuery.Create(nil);
  try
    TFDQuery(LQ).Connection := TFDConnection(FConnection);
    TFDQuery(LQ).SQL.Text := LSQL;
    { sem Prepare explícito: no Prepare os DataTypes dos params ainda são
      desconhecidos (EFDException -335); o FireDAC prepara no Open, depois de
      BindParams atribuir os Values (mesmo racional do fix Zeos 1.0.22). }
    BindParams(LQ, AParams);
    TFDQuery(LQ).Open;
    Result := CreateDisconnectedCopy(TDataSet(LQ));
  finally
    TFDQuery(LQ).Free;
  end;
{$ENDIF}
{$IF DEFINED(USE_ZEOS)}
  { bug-1171 (01/09/2026) - SQL Anywhere via TDS/FreeTDS: usar TZReadOnlyQuery,
    o MESMO desvio que a sobrecarga SEM parametros ja faz (ver ExecuteQuery(ASQL)
    e ExecuteQueryZeosReadOnly). O TZQuery EDITAVEL resolve metadados "smart"
    pelas stored procedures de catalogo JDBC (sp_jdbc_*), que o SQL Anywhere nao
    serve por TDS -> toda a leitura falhava com
      EZSQLException "Convertion is not possible for column N from Unknown to X".
    O desvio existia SO na sobrecarga sem parametros: por isso um SELECT sem
    WHERE passava e QUALQUER SELECT parametrizado (IQueryBuilder.Where) falhava.
    Isolado com spike Zeos CRU (sem units do projecto): com TZQuery falham TODOS
    os SELECT de colunas (mesmo literais, sem parametros) e passam COUNT(*) e
    UPDATE/DELETE - ou seja, o defeito e da via de metadata do dataset editavel,
    nao do TDS, nao do libsybdb e nao dos parametros. }
  if FDatabaseType = dtSQLAnywhere then
  begin
    LQ := ZDataset.TZReadOnlyQuery.Create(nil);
    try
      ZDataset.TZReadOnlyQuery(LQ).Connection := ZConnection.TZConnection(FConnection);
      ZDataset.TZReadOnlyQuery(LQ).SQL.Text := LSQL;
      BindParams(LQ, AParams);
      ZDataset.TZReadOnlyQuery(LQ).Open;
      Result := CreateDisconnectedCopy(TDataSet(LQ));
    finally
      ZDataset.TZReadOnlyQuery(LQ).Free;
    end;
    Exit;
  end;
  LQ := ZDataset.TZQuery.Create(nil);
  try
    ZDataset.TZQuery(LQ).Connection := ZConnection.TZConnection(FConnection);
    ZDataset.TZQuery(LQ).SQL.Text := LSQL;
    { sem Prepare explícito: Prepare antes do bind por nome deixava Params
      vazios em algumas builds Zeos — BindParams + Open (fix 1.0.22) }
    BindParams(LQ, AParams);
    ZDataset.TZQuery(LQ).Open;
    Result := CreateDisconnectedCopy(TDataSet(LQ));
  finally
    ZDataset.TZQuery(LQ).Free;
  end;
{$ENDIF}
{$IF DEFINED(USE_SQLDB)}
  LQ := TSQLQuery.Create(nil);
  try
    TSQLQuery(LQ).Database := TSQLConnection(FConnection);
    TSQLQuery(LQ).Transaction := TSQLTransaction(FTransaction);
    // ver nota no ExecuteQuery simples: sem server index defs (SQLPrimaryKeys).
    TSQLQuery(LQ).UsePrimaryKeyAsKey := False;
    TSQLQuery(LQ).SQL.Text := LSQL;
    TSQLQuery(LQ).Prepare;
    BindParams(LQ, AParams);
    TSQLQuery(LQ).Open;
    Result := CreateDisconnectedCopy(TDataSet(LQ));
  finally
    TSQLQuery(LQ).Free;
  end;
{$ENDIF}
end;

{ ExecuteCommand (parametrizado) — executa DML com parâmetros; retorna RowsAffected.
  FIX 1.0.21: usa query LOCAL por chamada (não o FExecQuery partilhado) — como os
  nomes :param0..N se repetem entre SQLs diferentes, o dataset partilhado preservava
  o TIPO dos parâmetros do comando anterior (TParams rebuild mantém DataType por
  nome), causando EVariantTypeCastError/EConvertError em sequências de INSERTs. }
function TConnection.ExecuteCommand(const ASQL: string;
  const AParams: array of Variant): Integer;
var
  LSQL: string;
  LQ: TObject;
begin
  Result := 0;
  if not Assigned(FConnection) or not IsConnected then
    raise EConnectionConnectionException.Create('Conexão não estabelecida.',
      ERR_CONNECTION_NOT_CONNECTED, 'ExecuteCommand');
  LSQL := NormalizeParams(ASQL);
{$IFDEF USE_DATABASE}
  try  // F5-FU.3 - converte lock Firebird (NO WAIT) em EDatabaseObjectLockedException
{$ENDIF}
{$IF DEFINED(USE_UNIDAC)}
  { FB+UniDAC: fechar read-transaction pendente antes de executar (ver nota no
    overload sem parametros). }
  if (not FInTransaction) and TUniConnection(FConnection).InTransaction then
    TUniConnection(FConnection).Commit;
  LQ := TUniQuery.Create(nil);
  try
    TUniQuery(LQ).Connection := TUniConnection(FConnection);
    TUniQuery(LQ).SQL.Text := LSQL;
    { Sem Prepare antes do bind — ver nota no ExecuteQuery parametrizado
      (UniDAC 10.3 + SQL Server: sql_variant vs varchar). }
    BindParams(LQ, AParams);
    TUniQuery(LQ).ExecSQL;
    Result := TUniQuery(LQ).RowsAffected;
    { POST-commit fora de transacao explicita (ver nota detalhada no overload sem
      parametros): SQL Anywhere (o path PREPARED de sqlany_execute NAO autocommita -
      o DML parametrizado fica por-committar e perde-se no Disconnect, bug-884) OU
      transacao nativa ainda aberta (Firebird). Confirmado por dbisql. }
    if (not FInTransaction) and
       ((FDatabaseType = dtSQLAnywhere) or TUniConnection(FConnection).InTransaction) then
      TUniConnection(FConnection).Commit;
  finally
    TUniQuery(LQ).Free;
  end;
{$ENDIF}
{$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)}
  LQ := TFDQuery.Create(nil);
  try
    TFDQuery(LQ).Connection := TFDConnection(FConnection);
    TFDQuery(LQ).SQL.Text := LSQL;
    { sem Prepare explícito — ver nota no ExecuteQuery parametrizado. }
    BindParams(LQ, AParams);
    TFDQuery(LQ).ExecSQL;
    Result := TFDQuery(LQ).RowsAffected;
  finally
    TFDQuery(LQ).Free;
  end;
{$ENDIF}
{$IF DEFINED(USE_ZEOS)}
  LQ := ZDataset.TZQuery.Create(nil);
  try
    ZDataset.TZQuery(LQ).Connection := ZConnection.TZConnection(FConnection);
    ZDataset.TZQuery(LQ).SQL.Text := LSQL;
    BindParams(LQ, AParams);
    ZDataset.TZQuery(LQ).ExecSQL;
    Result := ZDataset.TZQuery(LQ).RowsAffected;
  finally
    ZDataset.TZQuery(LQ).Free;
  end;
{$ENDIF}
{$IF DEFINED(USE_SQLDB)}
  LQ := TSQLQuery.Create(nil);
  try
    TSQLQuery(LQ).DataBase := TSQLConnection(FConnection);
    TSQLQuery(LQ).SQL.Text := LSQL;
    TSQLQuery(LQ).Prepare;
    BindParams(LQ, AParams);
    try
      TSQLQuery(LQ).ExecSQL;
      Result := TSQLQuery(LQ).RowsAffected;
      { autocommit emulado — ver nota no ExecuteCommand simples. }
      if not FInTransaction then
        TSQLTransaction(FTransaction).CommitRetaining;
    except
      if not FInTransaction then
        TSQLTransaction(FTransaction).RollbackRetaining;
      raise;
    end;
  finally
    TSQLQuery(LQ).Free;
  end;
{$ENDIF}
  InvalidateDriverMetadata(LSQL); // bug-167 (no-op fora do Zeos)
{$IFDEF USE_DATABASE}
  except
    on E: Exception do
    begin
      if (not FLockWait) and (FDatabaseType = dtFireBird) and IsFirebirdLockError(E.Message) then
        raise EDatabaseObjectLockedException.Create(
          Format(DB_ERR_OBJECT_LOCKED_MSG, [Trim(Copy(ASQL, 1, 60)), E.Message]),
          ERR_DATABASE_OBJECT_LOCKED, ASQL);
      raise;
    end;
  end;
{$ENDIF}
end;

{ ExecuteScalar (parametrizado) — retorna o primeiro campo da primeira linha;
  reutiliza ExecuteQuery(parametrizado) e libera o dataset internamente. }
function TConnection.ExecuteScalar(const ASQL: string;
  const AParams: array of Variant): Variant;
var
  LDS: TDataSet;
begin
  Result := Null;
  LDS := ExecuteQuery(ASQL, AParams);
  if LDS = nil then
    Exit;
  try
    if not LDS.IsEmpty and (LDS.FieldCount > 0) then
      Result := LDS.Fields[0].Value;
  finally
    LDS.Free;
  end;
end;

class function TConnection.New: IConnection;
begin
  Result := TConnection.Create;
end;

{$HINTS ON}
initialization
{$IF DEFINED(FPC) AND DEFINED(USE_UNIDAC)}
  { UniDAC+FPC: sob um locale cujo separador decimal nao e '.' (ex.: pt-BR = ','),
    a UniDAC devolve valores TIMESTAMP/numericos do banco como STRING com '.', e o
    parse do RTL (AsDateTime/AsFloat -> StrToFloat sem FormatSettings explicito)
    usa o DecimalSeparator do locale (',') -> EConvertError (ex.: dia Juliano
    "2461247.97..."). Forcar '.' para o parsing de valores de banco - padrao para
    apps de BD em FPC; bancos usam SEMPRE '.'. Zeos/SQLdb+FPC nao precisam (mapeiam
    o tipo nativo, sem round-trip por string). Efeito colateral: a formatacao
    numerica global desta app passa a usar '.' sob UniDAC+FPC. }
  FormatSettings.DecimalSeparator := '.';
  DefaultFormatSettings.DecimalSeparator := '.';
{$IFEND}
finalization
{$IF DEFINED(USE_FIREDAC) AND NOT DEFINED(FPC)}
  FreeAndNil(FDFBDriverLink);
{$ENDIF}
{$IF DEFINED(USE_SQLDB)}
  FreeSqldbLoaders;
{$ENDIF}

end.
