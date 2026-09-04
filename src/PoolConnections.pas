{ =============================================================================
  PoolConnections - O Broker Elastico (TPoolBroker + TConnectionWorkerThread)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  2.2.0
  FileVersion:    1.3.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           09/08/2026

  FERRAMENTA PRINCIPAL do ecossistema (Onda 4.3, arquitectura do owner 10/07):
  Message Broker Elastico com consciencia de hardware.

  - TConnectionWorkerThread: instancia e DETEM 1 TConnection fisico (criado
    DENTRO da propria thread); loop continuo a consumir TPoolRequest da sua
    fila, executando na conexao e devolvendo o resultado (Done.SetEvent) a
    thread que gerou a mensagem. Componentes DB nunca cruzam threads.
  - TPoolBroker (IPoolConnections + IPoolBroker): pool HETEROGENEO (catalogo de
    bancos com filas/workers separados); GetFromPool NUNCA devolve a fisica -
    instancia um TConnectionProxy vinculado a worker e devolve o Proxy
    (Transparencia Total); teto de hardware 80/20 via PoolConnections.Hardware;
    espera pacifica na fila com AcquireTimeout -> OnPoolExhausted + 450001;
    sticky sessions (transacoes pinadas a worker); leases com rastreio
    owner/operation; Shutdown guardiao (fecha TODAS as workers, zero orfas);
    Destroy chama Shutdown.

  Paridade D10 v2.3.0: 7 metodos IPoolConnections + GetByIndex/GetByName/
  GetPoolList + 9 eventos + free functions (FormatConnectionInfo/GetTableNames/
  TableNamesToCVS via IConnection directo - o v2 dependia de Database.Tables).
  Add/TryAdd ADOPTAM conexoes externas (worker adoptiva; dedup por chave
  Engine+Type+Host+User). Nota de semantica broker registada em
  PoolConnections.Interfaces.

  Housekeeper (Onda 4.3b - TPoolHousekeeperThread): monitor continuo que a cada
  HousekeeperIntervalMs faz warm-up (MinPoolSize por banco), scale-out (fila de
  aquisicao > ScaleOutQueueThreshold e margem nos tetos -> nova worker
  pre-aquecida), scale-in (worker ociosa > IdleTimeoutMs -> fecho gracioso,
  preservando MinPoolSize; adoptadas/adhoc nunca sao retiradas) e detecao de
  leaks (lease > LeakWarningTimeoutMs -> OnConnectionLeak, uma vez por lease).
  Test-on-borrow (ValidateOnBorrow): Ping ao REUSAR worker; falha = worker
  substituida. Drain de shutdown: a worker esvazia a fila antes de fechar
  (nenhum pedido enfileirado fica sem Done). Metricas: AvgAcquireMs,
  TotalScaleOuts/Ins, LeaksDetected.

  Changelog (file):
  - 1.3.0 (09/08/2026): F8 Onda 8.6 -- SetLogger(const ALogger: ILogger):
    IPoolConnections reintroduzido no broker (guardado por USE_LOGGERS).
    Piggyback em 4 hooks ja existentes -- nenhum ponto de chamada novo:
    OnBeforeAdd/OnAfterAdd (Debug), OnPoolExhausted/OnConnectionLeak
    (Warning). Default = TNullLogger (Loggers.NullLogger, zero overhead).
    Validado isolado antes desta aplicacao: src/testes/Loggers/
    spike_poolconnections_setlogger.dpr (4 alvos) + patch em
    .workspace/patches/f8-onda8.6-poolconnections-setlogger/ (aplicado com
    autorizacao expressa do owner, pasta bloqueada).
  - 1.2.1 (22/07/2026): GAP REAL corrigido (achado por auditoria adversarial F8 +
    apontado pelo owner) - o ramo FUseData de TConnectionWorkerThread.Execute
    (usado por TPoolBroker.AddDatabase(AName, TConnectionData) - o caminho que
    Loggers/qualquer consumidor via pool usa) nunca propagava ServerName (ENG do
    SQL Anywhere) nem DllDownloadUrl (override de URL, F7 Onda 7.0) do
    TConnectionData para o TConnection construido - ficavam silenciosamente
    perdidos para toda conexao pooled, apesar de resolvidos correctamente a
    montante (Parameters.Connections.LoadConfigure). Os outros 2 ramos (FJSON/
    FIniPath, via FromJSON/FromIniFile) ja propagavam correctamente por lerem o
    ficheiro de config directamente. Adicionado .ServerName(FData.ServerName) e
    .DllDownloadUrl(FData.DllDownloadUrl) ao encadeamento fluente.
  - 1.2.0 (12/07/2026): bug-164 - WaitReady de workers NOVAS (AcquireSlot/
    TryAdd/HkCreateWorker) passa a usar ConnectTimeoutMs (30 s default);
    AcquireTimeoutMs governa apenas a espera por worker livre.
  - 1.1.1 (11/07/2026): Onda 4.4 - fix bug-159: Remove tambem retira e liberta
    o TProxyBinding do proxy removido (binding orfao apontava para o slot ja
    libertado -> use-after-free no ProxyReleased/Release posterior).
  - 1.1.0 (11/07/2026): Onda 4.3b - housekeeper (warm-up/scale-out/scale-in/
    leaks), test-on-borrow, drain de shutdown no loop da worker, rqExecuteDirect
    (passthrough bug-157), AvgAcquireMs e contadores de escalonamento.
  - 1.0.0 (10/07/2026): versao inicial (Onda 4.3 Etapa B).
  ============================================================================= }
unit PoolConnections;

{$I ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$IFDEF USE_POOLCONNECTIONS}

uses
{$IFDEF FPC}
  Windows, // INFINITE
  ActiveX, // CoInitializeEx/CoUninitialize (OLE DB nas worker threads)
  SysUtils, Classes, SyncObjs, Variants, DB,
{$ELSE}
  Winapi.Windows, // GetTickCount64, Sleep, INFINITE
  Winapi.ActiveX, // CoInitializeEx/CoUninitialize (OLE DB nas worker threads)
  System.SysUtils, System.Classes, System.SyncObjs, System.Variants, Data.DB,
{$ENDIF}
  Commons.Types,
  Commons.Consts,
  Commons.PoolConnections.Types,
  Commons.PoolConnections.Consts,
  Exceptions.Base,
  Exceptions.PoolConnections,
  Connections.Interfaces,
  Connections.Proxy,
  PoolConnections.Interfaces,
  PoolConnections.Queue,
  PoolConnections.Hardware
{$IFDEF USE_LOGGERS}
  , Loggers.Interfaces  // F8 Onda 8.6 -- SetLogger
  , Loggers.NullLogger  // default zero-overhead do FLogger
{$ENDIF}
  ;

type
  { Worker: a DONA da conexao fisica. A conexao e criada DENTRO do Execute
    (afinidade de thread) - por factory, JSON, INI, dados fluentes ou ADOPTADA
    (paridade Add). }
  TConnectionWorkerThread = class(TThread)
  strict private
    FId           : Integer;
    FQueue        : TPoolQueue;
    FReady        : TEvent;
    FConnectError : string;
    FConnData     : TConnectionData; // snapshot pos-connect (p/ proxies)
    { modos de criacao (um unico e usado) }
    FAdopted      : IConnection;
    FFactory      : TPoolConnectionFactory;
    FJSON         : string;
    FIniPath      : string;
    FIniSection   : string;
    FData         : TConnectionData;
    FUseData      : Boolean;
    FConnection   : IConnection;     // SO a worker toca aqui
    procedure Process(const AReq: TPoolRequest);
  protected
    procedure Execute; override;
  public
    constructor Create(const AId: Integer);
    destructor Destroy; override;
    { configuracao do modo de criacao (antes de Start) }
    procedure SetupAdopted(const AConnection: IConnection);
    procedure SetupFactory(const AFactory: TPoolConnectionFactory);
    procedure SetupJSON(const AJSON: string);
    procedure SetupIni(const APath, ASection: string);
    procedure SetupData(const AData: TConnectionData);
    { espera a conexao inicial; '' = ok, senao mensagem de erro }
    function WaitReady(const ATimeoutMs: Integer): string;
    { entrega o pedido e BLOQUEIA ate a conclusao (chamado na thread do caller) }
    procedure ExecuteRequest(const AReq: TPoolRequest);
    { fecha a fila (o loop termina e desconecta) }
    procedure CloseQueue;
    function QueueCount: Integer;
    property Id: Integer read FId;
    property ConnData: TConnectionData read FConnData;
  end;

  { Tick do housekeeper: executa uma ronda e devolve os ms ate a proxima. }
  TPoolHousekeeperTick = function: Integer of object;

  { Housekeeper / Load Balancer dinamico (Onda 4.3b): thread de monitorizacao
    continua do broker. Nao conhece os internos - chama o tick (metodo do
    broker) na cadencia que ele devolver; Stop acorda e termina de imediato. }
  TPoolHousekeeperThread = class(TThread)
  strict private
    FTick : TPoolHousekeeperTick;
    FStop : TEvent;
  protected
    procedure Execute; override;
  public
    constructor Create(const ATick: TPoolHousekeeperTick);
    destructor Destroy; override;
    procedure Stop;
  end;

  { O Broker central. }
  TPoolBroker = class(TInterfacedObject, IPoolConnections, IPoolBroker)
  strict private
    type
      TDatabaseEntry = class
      public
        Name       : string;
        Data       : TConnectionData;
        HasData    : Boolean;
        JSON       : string;
        IniPath    : string;
        IniSection : string;
        Waiting    : Integer; // aquisicoes em espera (QueueDepth)
      end;
      TWorkerSlot = class
      public
        Worker      : TConnectionWorkerThread;
        Busy        : Boolean;
        EntryName   : string;  // '' = adhoc (Add/TryAdd)
        DisplayName : string;
        DedupKey    : string;  // adhoc: Engine+Type+Host+User
        LastUsedAt  : TDateTime; // scale-in (4.3b): ociosa desde
      end;
      TProxyBinding = class
      public
        ProxyId      : Integer;
        Slot         : TWorkerSlot;
        ProxyPtr     : Pointer;    // referencia FRACA (identidade p/ Remove)
        Sticky       : Boolean;
        Lease        : TPoolLease;
        LeakNotified : Boolean;    // OnConnectionLeak disparado (uma vez)
      end;
      { plano de criacao do housekeeper: snapshot POR VALOR da entry (a entry
        pode morrer num Shutdown concorrente enquanto a worker conecta) }
      THkCreatePlan = record
        Name       : string;
        JSON       : string;
        IniPath    : string;
        IniSection : string;
        Data       : TConnectionData;
        UseFactory : Boolean;
      end;
    var
      FLock        : TCriticalSection;
      FEntries     : TList; // of TDatabaseEntry
      FSlots       : TList; // of TWorkerSlot
      FBindings    : TList; // of TProxyBinding
      FConfig      : TPoolConfig;
      FFactory     : TPoolConnectionFactory;
      FNextId      : Integer;
      FNextProxyId : Integer;
      FShutdown    : Boolean;
      FTotalAcquired : Integer;
      FTotalTimeouts : Integer;
      { housekeeper (4.3b) }
      FHousekeeper    : TPoolHousekeeperThread;
      FAcquireCount   : Int64;
      FAcquireMsTotal : Int64;
      FTotalScaleOuts : Integer;
      FTotalScaleIns  : Integer;
      FLeaksDetected  : Integer;
      { eventos (paridade v2 + broker) }
      FOnBeforeAdd, FOnAfterAdd, FOnBeforeRemove, FOnAfterRemove,
      FOnAfterGetFromPool, FOnBeforeReturnToPool, FOnAfterReturnToPool: TPoolConnectionEvent;
      FOnBeforeGetFromPool, FOnClear: TNotifyEvent;
      FOnPoolExhausted: TPoolExhaustedEvent;
      FOnConnectionLeak: TPoolLeakEvent;
{$IFDEF USE_LOGGERS}
      FLogger: ILogger; // F8 Onda 8.6 - default TNullLogger (zero overhead)
{$ENDIF}
    function FindEntry(const AName: string): TDatabaseEntry;
    function EntrySlotCount(const AName: string): Integer;
    function ConnectionKey(const AData: TConnectionData): string;
    function CreateWorkerSlot(const AEntry: TDatabaseEntry): TWorkerSlot;
    function AcquireSlot(const ADatabaseName, AOwner, AOperation: string): IConnection;
    procedure ShutdownSlot(const ASlot: TWorkerSlot);
    procedure CheckNotShutdown;
    { housekeeper (4.3b) }
    function HousekeepingTick: Integer;
    procedure HkCreateWorker(const APlan: THkCreatePlan);
  public
    constructor Create;
    destructor Destroy; override;
    class function New: IPoolConnections;

    { IPoolBroker (consumido pelo TConnectionProxy) }
    procedure ExecuteRequest(const AProxyId: Integer; const ARequest: TPoolRequest);
    procedure BeginSticky(const AProxyId: Integer);
    procedure EndSticky(const AProxyId: Integer);
    procedure ProxyReleased(const AProxyId: Integer);

    { IPoolConnections - paridade v2 }
    function GetFromPool: IConnection; overload;
    function ReturnToPool(const AConnection: IConnection): IPoolConnections;
    function Add(const AConnection: IConnection): IPoolConnections;
    function TryAdd(const AConnection: IConnection): Boolean;
    function Remove(const AConnection: IConnection): IPoolConnections;
    function Count: Integer;
    function Clear: IPoolConnections;
    function GetByIndex(const AIndex: Integer): IConnection;
    function GetByName(const AName: string): IConnection;
    function GetPoolList: TPools;

    { IPoolConnections - catalogo heterogeneo }
    function AddDatabase(const AName: string; const AConfig: TConnectionData): IPoolConnections;
    function FromJSON(const AName, AJSON: string): IPoolConnections;
    function FromIniFile(const AName, AFilePath, ASection: string): IPoolConnections;
    function Factory(const AValue: TPoolConnectionFactory): IPoolConnections;

    { IPoolConnections - aquisicao }
    function GetFromPool(const ADatabaseName: string): IConnection; overload;
    function GetFromPool(const ADatabaseName, AOwner, AOperation: string): IConnection; overload;

    { IPoolConnections - config e observabilidade }
    function Config(const AValue: TPoolConfig): IPoolConnections; overload;
    function Config: TPoolConfig; overload;
    function Metrics: TPoolMetrics;
    function HardwareInfo: TPoolHardwareInfo;
    function ActiveLeases: TPoolLeases;
    function QueueDepth(const ADatabaseName: string): Integer;
    procedure Shutdown;

    { IPoolConnections - eventos }
    function OnBeforeAdd(const AValue: TPoolConnectionEvent): IPoolConnections;
    function OnAfterAdd(const AValue: TPoolConnectionEvent): IPoolConnections;
    function OnBeforeRemove(const AValue: TPoolConnectionEvent): IPoolConnections;
    function OnAfterRemove(const AValue: TPoolConnectionEvent): IPoolConnections;
    function OnBeforeGetFromPool(const AValue: TNotifyEvent): IPoolConnections;
    function OnAfterGetFromPool(const AValue: TPoolConnectionEvent): IPoolConnections;
    function OnBeforeReturnToPool(const AValue: TPoolConnectionEvent): IPoolConnections;
    function OnAfterReturnToPool(const AValue: TPoolConnectionEvent): IPoolConnections;
    function OnClear(const AValue: TNotifyEvent): IPoolConnections;
    function OnPoolExhausted(const AValue: TPoolExhaustedEvent): IPoolConnections;
    function OnConnectionLeak(const AValue: TPoolLeakEvent): IPoolConnections;

{$IFDEF USE_LOGGERS}
    { F8 Onda 8.6 - ver IPoolConnections.SetLogger para semantica. }
    function SetLogger(const ALogger: ILogger): IPoolConnections;
{$ENDIF}
  end;

{ Free functions - paridade v2.3.0 (reimplementadas via IConnection directo;
  o v2 delegava a Database.Tables, modulo F5 inexistente em src). }
function FormatConnectionInfo(const AConn: IConnection): string;
function GetTableNames(const AConn: IConnection): TStringArray;
function TableNamesToCVS(const ANames: TStringArray): string;

{$ENDIF}

implementation

{$IFDEF USE_POOLCONNECTIONS}

uses
  Connections, Commons.Diagnostics; // TConnection.New (default factory das workers)

{ ===================== free functions (paridade v2) ===================== }

function FormatConnectionInfo(const AConn: IConnection): string;
var
  LData: TConnectionData;
begin
  if AConn = nil then
    Exit('(nil)');
  LData := AConn.GetConnectionData;
  Result := Format('%s %s@%s:%d/%s (user=%s)',
    [DEFAULT_DATABASE_ENGINE_NAME,
     TDatabaseTypeClass.ConfigString(LData.DatabaseType),
     LData.Host, LData.Port, LData.Database, LData.Username]);
end;

function GetTableNames(const AConn: IConnection): TStringArray;
begin
  SetLength(Result, 0);
  if (AConn <> nil) and AConn.IsConnected then
    Result := AConn.GetTableNames('');
end;

function TableNamesToCVS(const ANames: TStringArray): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(ANames) do
  begin
    if I > 0 then
      Result := Result + ',';
    Result := Result + ANames[I];
  end;
end;

{ ===================== TPoolHousekeeperThread ===================== }

constructor TPoolHousekeeperThread.Create(const ATick: TPoolHousekeeperTick);
begin
  inherited Create(True); // suspensa; Start explicito (FPC arranca no Create)
  FreeOnTerminate := False;
  FTick := ATick;
  FStop := TEvent.Create(nil, True, False, '');
end;

destructor TPoolHousekeeperThread.Destroy;
begin
  Stop;
  if not Suspended then
    WaitFor;
  FStop.Free;
  inherited;
end;

procedure TPoolHousekeeperThread.Stop;
begin
  Terminate;
  FStop.SetEvent;
end;

procedure TPoolHousekeeperThread.Execute;
var
  LNextMs: Integer;
begin
  while not Terminated do
  begin
    LNextMs := FTick();
    if LNextMs < 50 then
      LNextMs := 50;
    if Terminated then
      Break;
    if FStop.WaitFor(LNextMs) = wrSignaled then
      Break;
  end;
end;

{ ===================== TConnectionWorkerThread ===================== }

constructor TConnectionWorkerThread.Create(const AId: Integer);
begin
  inherited Create(True); // suspensa; Start apos Setup*
  FreeOnTerminate := False;
  FId := AId;
  FQueue := TPoolQueue.Create;
  FReady := TEvent.Create(nil, True, False, '');
  FUseData := False;
end;

destructor TConnectionWorkerThread.Destroy;
begin
  CloseQueue;
  if not Suspended then
    WaitFor;
  FQueue.Free;
  FReady.Free;
  inherited;
end;

procedure TConnectionWorkerThread.SetupAdopted(const AConnection: IConnection);
begin
  FAdopted := AConnection;
end;

procedure TConnectionWorkerThread.SetupFactory(const AFactory: TPoolConnectionFactory);
begin
  FFactory := AFactory;
end;

procedure TConnectionWorkerThread.SetupJSON(const AJSON: string);
begin
  FJSON := AJSON;
end;

procedure TConnectionWorkerThread.SetupIni(const APath, ASection: string);
begin
  FIniPath := APath;
  FIniSection := ASection;
end;

procedure TConnectionWorkerThread.SetupData(const AData: TConnectionData);
begin
  FData := AData;
  FUseData := True;
end;

function TConnectionWorkerThread.WaitReady(const ATimeoutMs: Integer): string;
begin
  if FReady.WaitFor(ATimeoutMs) <> wrSignaled then
    Exit('timeout a criar/conectar a worker');
  Result := FConnectError;
end;

procedure TConnectionWorkerThread.ExecuteRequest(const AReq: TPoolRequest);
begin
  if not FQueue.Push(AReq) then
  begin
    AReq.HasError := True;
    AReq.ErrorClass := 'EPoolConnectionsException';
    AReq.ErrorMessage := POOL_ERR_SHUTDOWN_MSG;
    AReq.ErrorCode := ERR_POOL_SHUTDOWN;
    AReq.Done.SetEvent;
    Exit;
  end;
  AReq.Done.WaitFor(INFINITE);
end;

procedure TConnectionWorkerThread.CloseQueue;
begin
  FQueue.Close;
end;

function TConnectionWorkerThread.QueueCount: Integer;
begin
  Result := FQueue.Count;
end;

procedure TConnectionWorkerThread.Execute;
var
  LReq: TPoolRequest;
  LComInit: Boolean;
begin
  { COM/OLE DB: os providers OLE DB (ex.: UniDAC x SQL Server) exigem CoInitialize
    NA thread que cria/usa a conexao. A worker DETEM a fisica e corre TODO o DML
    aqui, logo inicializa COM (MTA) a entrada e liberta a saida. Sem isto:
    "CoInitialize has not been called" (falha real UniDAC x SQL Server no pool). }
  LComInit := Succeeded(CoInitializeEx(nil, COINIT_MULTITHREADED));
  try
  { 1. criar/adoptar a conexao DENTRO da worker (afinidade de thread) }
  try
    if FAdopted <> nil then
    begin
      FConnection := FAdopted;
      if not FConnection.IsConnected then
        FConnection.Connect;
    end
    else if Assigned(FFactory) then
    begin
      FConnection := FFactory();
      if (FConnection <> nil) and (not FConnection.IsConnected) then
        FConnection.Connect;
    end
    else if FJSON <> '' then
      FConnection := TConnection.New.AutoDownloadDlls(True).FromJSON(FJSON).Connect
    else if FIniPath <> '' then
      FConnection := TConnection.New.AutoDownloadDlls(True).FromIniFile(FIniPath, FIniSection).Connect
    else if FUseData then
      FConnection := TConnection.New
        .Engine(FData.Engine)
        .DatabaseType(FData.DatabaseType)
        .Host(FData.Host).Port(FData.Port)
        .Username(FData.Username).Password(FData.Password)
        .Database(FData.Database).Schema(FData.Schema)
        .ServerName(FData.ServerName)
        .DllBasePath(FData.DllBasePath)
        .DllDownloadUrl(FData.DllDownloadUrl)
        .AutoDownloadDlls(True)
        .Connect
    else
      FConnectError := 'worker sem modo de criacao configurado';
    if (FConnectError = '') and ((FConnection = nil) or (not FConnection.IsConnected)) then
      FConnectError := 'conexao nao estabelecida';
    if FConnection <> nil then
      FConnData := FConnection.GetConnectionData;
  except
    on E: Exception do
      FConnectError := E.ClassName + ': ' + E.Message;
  end;
  FReady.SetEvent;
  if FConnectError <> '' then
    Exit;

  { 2. loop de consumo da fila (a unica thread que toca em FConnection).
    DRAIN de shutdown (4.3b): o fecho e governado pela FILA, nao pelo
    Terminated - depois do Close a worker ainda esvazia os pedidos pendentes
    (Pop so devolve False com a fila fechada E vazia), garantindo que nenhum
    solicitante fica pendurado num Done que nunca sinaliza. }
  try
    while FQueue.Pop(LReq, -1) do
    begin
      Process(LReq);
      LReq.Done.SetEvent; // devolve o resultado a thread solicitante
    end;
  finally
    { 3. fecho seguro da fisica (guardiao - zero conexoes orfas) }
    try
      if (FConnection <> nil) and FConnection.IsConnected then
        FConnection.Disconnect;
    except
      { 15.3/T10: engolir aqui e deliberado (guardiao: fecho da fisica no fim da thread),
        mas nao pode ser MUDO - sem rasto o defeito fica invisivel. }
      on E: Exception do
        TraceSwallowed('TConnectionWorkerThread.Execute', 'guardiao: fecho da fisica no fim da thread', E);
    end;
    FConnection := nil;
    FAdopted := nil;
  end;
  finally
    if LComInit then
      CoUninitialize;
  end;
end;

procedure TConnectionWorkerThread.Process(const AReq: TPoolRequest);
begin
  try
    case AReq.Kind of
      rqConnect:
        FConnection.Connect;
      rqDisconnect:
        FConnection.Disconnect;
      rqIsConnected:
        AReq.ResultBool := FConnection.IsConnected;
      rqPing:
        AReq.ResultBool := FConnection.Ping;
      rqExecuteQuery:
        AReq.ResultDataSet := FConnection.ExecuteQuery(AReq.SQL);
      rqExecuteQueryParams:
        AReq.ResultDataSet := FConnection.ExecuteQuery(AReq.SQL, AReq.Params);
      rqExecuteCommand:
        AReq.ResultInt := FConnection.ExecuteCommand(AReq.SQL);
      rqExecuteCommandParams:
        AReq.ResultInt := FConnection.ExecuteCommand(AReq.SQL, AReq.Params);
      rqExecuteScalar:
        AReq.ResultVariant := FConnection.ExecuteScalar(AReq.SQL);
      rqExecuteScalarParams:
        AReq.ResultVariant := FConnection.ExecuteScalar(AReq.SQL, AReq.Params);
      rqBeginTransaction:
        FConnection.BeginTransaction;
      rqCommit:
        FConnection.Commit;
      rqRollback:
        FConnection.Rollback;
      rqInTransaction:
        AReq.ResultBool := FConnection.InTransaction;
      rqGetServerVersion:
        AReq.ResultStr := FConnection.GetServerVersion;
      rqGetClientVersion:
        AReq.ResultStr := FConnection.GetClientVersion;
      rqGetTableNames:
        AReq.ResultStrArr := FConnection.GetTableNames(AReq.StrArg2);
      rqGetDatabaseNames:
        AReq.ResultStrArr := FConnection.GetDatabaseNames;
      rqGetSchemaNames:
        AReq.ResultStrArr := FConnection.GetSchemaNames(AReq.StrArg1);
      rqGetColumnNames:
        AReq.ResultStrArr := FConnection.GetColumnNames(AReq.StrArg1, AReq.StrArg2);
      rqGetTableStructure:
        AReq.ResultFields := FConnection.GetTableStructure(AReq.StrArg1, AReq.StrArg2);
      rqIsRequiredDllFound:
        AReq.ResultBool := FConnection.IsRequiredDllFound;
      rqExecuteDirect:
        { passthrough (bug-157): callback do caller executa AQUI, na worker,
          com a conexao FISICA - interfaces estendidas acessiveis com
          afinidade de thread correcta }
        if Assigned(AReq.DirectProc) then
          AReq.DirectProc(FConnection, AReq.DirectContext);
    end;
  except
    on E: Exception do
    begin
      AReq.HasError := True;
      AReq.ErrorClass := E.ClassName;
      AReq.ErrorMessage := E.Message;
      if E is EExceptionBase then
        AReq.ErrorCode := EExceptionBase(E).ErrorCode
      else
        AReq.ErrorCode := 0;
    end;
  end;
end;

{ ===================== TPoolBroker ===================== }

constructor TPoolBroker.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FEntries := TList.Create;
  FSlots := TList.Create;
  FBindings := TList.Create;
  FConfig := TPoolConfig.GetDefault;
  FNextId := 1;
  FNextProxyId := 1;
  FShutdown := False;
{$IFDEF USE_LOGGERS}
  FLogger := TNullLogger.New;
{$ENDIF}
  { housekeeper por ULTIMO (o tick le o estado do broker ja construido) }
  FHousekeeper := TPoolHousekeeperThread.Create(HousekeepingTick);
  FHousekeeper.Start;
end;

destructor TPoolBroker.Destroy;
begin
  Shutdown; // guardiao: fecha TODAS as workers ao morrer (zero orfas)
  FBindings.Free;
  FSlots.Free;
  FEntries.Free;
  FLock.Free;
  inherited;
end;

class function TPoolBroker.New: IPoolConnections;
begin
  Result := TPoolBroker.Create;
end;

procedure TPoolBroker.CheckNotShutdown;
begin
  if FShutdown then
    raise EPoolConnectionsException.Create(POOL_ERR_SHUTDOWN_MSG, ERR_POOL_SHUTDOWN);
end;

function TPoolBroker.FindEntry(const AName: string): TDatabaseEntry;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FEntries.Count - 1 do
    if SameText(TDatabaseEntry(FEntries[I]).Name, AName) then
      Exit(TDatabaseEntry(FEntries[I]));
end;

function TPoolBroker.EntrySlotCount(const AName: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FSlots.Count - 1 do
    if SameText(TWorkerSlot(FSlots[I]).EntryName, AName) then
      Inc(Result);
end;

function TPoolBroker.ConnectionKey(const AData: TConnectionData): string;
begin
  Result := LowerCase(Format('%d|%d|%s|%s',
    [Ord(AData.Engine), Ord(AData.DatabaseType),
     Trim(AData.Host), Trim(AData.Username)]));
end;

function TPoolBroker.CreateWorkerSlot(const AEntry: TDatabaseEntry): TWorkerSlot;
var
  LW: TConnectionWorkerThread;
begin
  LW := TConnectionWorkerThread.Create(FNextId);
  Inc(FNextId);
  if Assigned(FFactory) then
    LW.SetupFactory(FFactory)
  else if AEntry.JSON <> '' then
    LW.SetupJSON(AEntry.JSON)
  else if AEntry.IniPath <> '' then
    LW.SetupIni(AEntry.IniPath, AEntry.IniSection)
  else
    LW.SetupData(AEntry.Data);
  Result := TWorkerSlot.Create;
  Result.Worker := LW;
  Result.Busy := False;
  Result.EntryName := AEntry.Name;
  Result.DisplayName := AEntry.Name + '-' + IntToStr(LW.Id);
  Result.DedupKey := '';
  Result.LastUsedAt := Now;
  FSlots.Add(Result);
  LW.Start;
end;

procedure TPoolBroker.ShutdownSlot(const ASlot: TWorkerSlot);
begin
  ASlot.Worker.CloseQueue;
  ASlot.Worker.Terminate;
  ASlot.Worker.Free; // Destroy faz WaitFor (fecho ordenado)
  ASlot.Free;
end;

{ aquisicao: worker livre -> cria dentro dos tetos -> espera pacifica }

function TPoolBroker.AcquireSlot(const ADatabaseName, AOwner, AOperation: string): IConnection;
var
  LEntry: TDatabaseEntry;
  LSlot, LNew: TWorkerSlot;
  LBinding: TProxyBinding;
  LName, LErr: string;
  LDeadline, LStart: UInt64;
  LWaited, LConnectMs: Integer;
  LProxy: TConnectionProxy;
  LPingReq: TPoolRequest;
  LValidate, LPingOk: Boolean;
  I: Integer;
begin
  Result := nil;
  LName := ADatabaseName;
  if Assigned(FOnBeforeGetFromPool) then
    FOnBeforeGetFromPool(Self);
  LStart := GetTickCount64;
  LDeadline := LStart + UInt64(FConfig.AcquireTimeoutMs);
  LValidate := FConfig.ValidateOnBorrow;
  LConnectMs := FConfig.ConnectTimeoutMs;

  { resolve o banco (fora do loop) }
  FLock.Acquire;
  try
    CheckNotShutdown;
    if LName = '' then
    begin
      if FEntries.Count >= 1 then
        LName := TDatabaseEntry(FEntries[0]).Name  // default = 1o banco registado
      else if FSlots.Count = 0 then
        raise EPoolConnectionsException.Create(
          Format(POOL_ERR_DB_NOT_REGISTERED_MSG, ['(default)']), ERR_POOL_DATABASE_NOT_REGISTERED);
      { senao: so adhoc slots (EntryName='') - LName fica '' e casa com eles }
    end
    else if FindEntry(LName) = nil then
      raise EPoolConnectionsException.Create(
        Format(POOL_ERR_DB_NOT_REGISTERED_MSG, [LName]), ERR_POOL_DATABASE_NOT_REGISTERED);
    LEntry := FindEntry(LName);
    if LEntry <> nil then
      Inc(LEntry.Waiting);
  finally
    FLock.Release;
  end;

  try
    repeat
      LNew := nil;
      FLock.Acquire;
      try
        CheckNotShutdown;
        { 1) worker livre do banco (FIFO) }
        LSlot := nil;
        for I := 0 to FSlots.Count - 1 do
          if (not TWorkerSlot(FSlots[I]).Busy) and
             SameText(TWorkerSlot(FSlots[I]).EntryName, LName) then
          begin
            LSlot := TWorkerSlot(FSlots[I]);
            Break;
          end;
        { 2) criar nova worker dentro dos tetos (por-banco E global/hardware) }
        if (LSlot = nil) and (LEntry <> nil) and
           (EntrySlotCount(LName) < FConfig.MaxPoolSizePerDatabase) and
           (FSlots.Count < TPoolHardware.GlobalWorkerCap(FConfig.CPUThreshold, FConfig.WorkersPerCoreFactor)) then
        begin
          LNew := CreateWorkerSlot(LEntry);
          LNew.Busy := True; // reservada para este caller
          LSlot := LNew;
        end
        else if LSlot <> nil then
          LSlot.Busy := True;
      finally
        FLock.Release;
      end;

      if (LSlot <> nil) and (LNew <> nil) then
      begin
        { espera a conexao inicial da worker nova (fora do lock) com o timeout
          de CRIACAO (bug-164): arranque frio (SQL Server/ODBC/DLLs) excede o
          AcquireTimeout - esse governa so a espera por worker LIVRE }
        LErr := LNew.Worker.WaitReady(LConnectMs);
        if LErr <> '' then
        begin
          FLock.Acquire;
          try
            FSlots.Remove(LNew);
          finally
            FLock.Release;
          end;
          ShutdownSlot(LNew);
          raise EPoolConnectionsException.Create(
            Format(POOL_ERR_CONNECTION_INVALID_MSG, [LErr]), ERR_POOL_CONNECTION_INVALID);
        end;
      end;

      { test-on-borrow (4.3b): ao REUSAR worker existente, valida com Ping;
        falha = worker morta e substituida (volta ao loop) }
      if (LSlot <> nil) and (LNew = nil) and LValidate then
      begin
        LPingReq := TPoolRequest.Create(rqPing);
        try
          LSlot.Worker.ExecuteRequest(LPingReq);
          LPingOk := (not LPingReq.HasError) and LPingReq.ResultBool;
        finally
          LPingReq.Free;
        end;
        if not LPingOk then
        begin
          FLock.Acquire;
          try
            FSlots.Remove(LSlot);
          finally
            FLock.Release;
          end;
          ShutdownSlot(LSlot);
          LSlot := nil;
        end;
      end;

      if LSlot <> nil then
      begin
        { bind + proxy (Transparencia Total: NUNCA a fisica) }
        FLock.Acquire;
        try
          LBinding := TProxyBinding.Create;
          LBinding.ProxyId := FNextProxyId;
          Inc(FNextProxyId);
          LBinding.Slot := LSlot;
          LBinding.Sticky := False;
          LBinding.Lease.ConnId := LSlot.Worker.Id;
          LBinding.Lease.DatabaseName := LName;
          LBinding.Lease.Owner := AOwner;
          LBinding.Lease.Operation := AOperation;
          LBinding.Lease.AcquiredAt := Now;
          LBinding.Lease.ReleasedAt := 0;
          LBinding.Lease.WorkerThreadId := NativeUInt(LSlot.Worker.ThreadID);
          FBindings.Add(LBinding);
          Inc(FTotalAcquired);
          Inc(FAcquireCount);
          FAcquireMsTotal := FAcquireMsTotal + Int64(GetTickCount64 - LStart);
          LProxy := TConnectionProxy.Create(Self, LBinding.ProxyId, LSlot.Worker.ConnData);
          LBinding.ProxyPtr := Pointer(LProxy);
        finally
          FLock.Release;
        end;
        Result := LProxy;
        if Assigned(FOnAfterGetFromPool) then
          FOnAfterGetFromPool(Self, Result);
        Exit;
      end;

      { 3) espera pacifica na fila (fatias de 50 ms ate ao deadline) }
      if GetTickCount64 >= LDeadline then
      begin
        FLock.Acquire;
        try
          Inc(FTotalTimeouts);
        finally
          FLock.Release;
        end;
        LWaited := FConfig.AcquireTimeoutMs;
        if Assigned(FOnPoolExhausted) then
          FOnPoolExhausted(Self, LName, LWaited);
{$IFDEF USE_LOGGERS}
        FLogger.Warning(Format('PoolExhausted: %s esgotado apos %dms de espera', [LName, LWaited]));
{$ENDIF}
        raise EPoolAcquireTimeoutException.Create(
          Format(POOL_ERR_ACQUIRE_TIMEOUT_MSG, [LName, LWaited]), ERR_POOL_ACQUIRE_TIMEOUT);
      end;
      Sleep(50);
    until False;
  finally
    if LEntry <> nil then
    begin
      FLock.Acquire;
      try
        Dec(LEntry.Waiting);
      finally
        FLock.Release;
      end;
    end;
  end;
end;

{ ---- IPoolBroker (proxy -> broker) ---- }

procedure TPoolBroker.ExecuteRequest(const AProxyId: Integer; const ARequest: TPoolRequest);
var
  I: Integer;
  LSlot: TWorkerSlot;
begin
  LSlot := nil;
  FLock.Acquire;
  try
    for I := 0 to FBindings.Count - 1 do
      if TProxyBinding(FBindings[I]).ProxyId = AProxyId then
      begin
        LSlot := TProxyBinding(FBindings[I]).Slot;
        Break;
      end;
  finally
    FLock.Release;
  end;
  if LSlot = nil then
  begin
    ARequest.HasError := True;
    ARequest.ErrorClass := 'EPoolConnectionsException';
    ARequest.ErrorMessage := POOL_ERR_SHUTDOWN_MSG;
    ARequest.ErrorCode := ERR_POOL_SHUTDOWN;
    ARequest.Done.SetEvent;
    Exit;
  end;
  { fora do lock: a worker executa e sinaliza Done (o caller ja espera nele) }
  LSlot.Worker.ExecuteRequest(ARequest);
end;

procedure TPoolBroker.BeginSticky(const AProxyId: Integer);
var
  I: Integer;
begin
  FLock.Acquire;
  try
    for I := 0 to FBindings.Count - 1 do
      if TProxyBinding(FBindings[I]).ProxyId = AProxyId then
      begin
        TProxyBinding(FBindings[I]).Sticky := True; // worker ja e exclusiva do lease
        Break;
      end;
  finally
    FLock.Release;
  end;
end;

procedure TPoolBroker.EndSticky(const AProxyId: Integer);
var
  I: Integer;
begin
  FLock.Acquire;
  try
    for I := 0 to FBindings.Count - 1 do
      if TProxyBinding(FBindings[I]).ProxyId = AProxyId then
      begin
        TProxyBinding(FBindings[I]).Sticky := False;
        Break;
      end;
  finally
    FLock.Release;
  end;
end;

procedure TPoolBroker.ProxyReleased(const AProxyId: Integer);
var
  I: Integer;
  LBinding: TProxyBinding;
begin
  LBinding := nil;
  FLock.Acquire;
  try
    for I := 0 to FBindings.Count - 1 do
      if TProxyBinding(FBindings[I]).ProxyId = AProxyId then
      begin
        LBinding := TProxyBinding(FBindings[I]);
        FBindings.Delete(I);
        Break;
      end;
    if LBinding <> nil then
    begin
      LBinding.Slot.Busy := False; // worker volta a fila de livres
      LBinding.Slot.LastUsedAt := Now; // relogio do scale-in (4.3b)
    end;
  finally
    FLock.Release;
  end;
  if LBinding <> nil then
  begin
    if Assigned(FOnAfterReturnToPool) then
      FOnAfterReturnToPool(Self, nil); // fisica nunca sai do pool (broker)
    LBinding.Free;
  end;
end;

{ ---- IPoolConnections: paridade v2 ---- }

function TPoolBroker.GetFromPool: IConnection;
begin
  Result := AcquireSlot('', '', '');
end;

function TPoolBroker.GetFromPool(const ADatabaseName: string): IConnection;
begin
  Result := AcquireSlot(ADatabaseName, '', '');
end;

function TPoolBroker.GetFromPool(const ADatabaseName, AOwner, AOperation: string): IConnection;
begin
  Result := AcquireSlot(ADatabaseName, AOwner, AOperation);
end;

function TPoolBroker.ReturnToPool(const AConnection: IConnection): IPoolConnections;
var
  LPooled: IPooledConnection;
begin
  Result := Self;
  if AConnection = nil then
    Exit;
  if Assigned(FOnBeforeReturnToPool) then
    FOnBeforeReturnToPool(Self, AConnection);
  if Supports(AConnection, IPooledConnection, LPooled) then
    LPooled.Release
  else
    TryAdd(AConnection); // conexao crua (paridade v2): reinsere no pool
end;

function TPoolBroker.Add(const AConnection: IConnection): IPoolConnections;
begin
  TryAdd(AConnection);
  Result := Self;
end;

function TPoolBroker.TryAdd(const AConnection: IConnection): Boolean;
var
  LKey: string;
  LSlot: TWorkerSlot;
  LW: TConnectionWorkerThread;
  LErr: string;
  I: Integer;
begin
  Result := False;
  if AConnection = nil then
    Exit;
  if Assigned(FOnBeforeAdd) then
    FOnBeforeAdd(Self, AConnection);
{$IFDEF USE_LOGGERS}
  FLogger.Debug('TryAdd: iniciando (conexao adoptada)');
{$ENDIF}
  LKey := ConnectionKey(AConnection.GetConnectionData);
  FLock.Acquire;
  try
    CheckNotShutdown;
    for I := 0 to FSlots.Count - 1 do
      if TWorkerSlot(FSlots[I]).DedupKey = LKey then
        Exit(False); // dedup por Engine+Type+Host+User (paridade v2)
    LW := TConnectionWorkerThread.Create(FNextId);
    Inc(FNextId);
    LW.SetupAdopted(AConnection);
    LSlot := TWorkerSlot.Create;
    LSlot.Worker := LW;
    LSlot.Busy := False;
    LSlot.EntryName := '';
    LSlot.DisplayName := 'Conexao ' + IntToStr(LW.Id); // paridade v2
    LSlot.DedupKey := LKey;
    FSlots.Add(LSlot);
    LW.Start;
  finally
    FLock.Release;
  end;
  LErr := LSlot.Worker.WaitReady(FConfig.ConnectTimeoutMs);
  if LErr <> '' then
  begin
    FLock.Acquire;
    try
      FSlots.Remove(LSlot);
    finally
      FLock.Release;
    end;
    ShutdownSlot(LSlot);
    Exit(False);
  end;
  Result := True;
  if Assigned(FOnAfterAdd) then
    FOnAfterAdd(Self, AConnection);
{$IFDEF USE_LOGGERS}
  FLogger.Debug('TryAdd: OK (conexao adoptada)');
{$ENDIF}
end;

function TPoolBroker.Remove(const AConnection: IConnection): IPoolConnections;
var
  I: Integer;
  LSlot: TWorkerSlot;
  LBinding, LVictim: TProxyBinding;
begin
  Result := Self;
  if AConnection = nil then
    Exit;
  if Assigned(FOnBeforeRemove) then
    FOnBeforeRemove(Self, AConnection);
  LSlot := nil;
  LVictim := nil;
  FLock.Acquire;
  try
    { proxy activo? remove a worker vinculada E o binding (bug-159: binding
      orfao apontava para slot libertado -> use-after-free no ProxyReleased;
      sem binding, o Release posterior do proxy e um no-op inofensivo) }
    for I := 0 to FBindings.Count - 1 do
    begin
      LBinding := TProxyBinding(FBindings[I]);
      if LBinding.ProxyPtr = Pointer(AConnection) then
      begin
        LSlot := LBinding.Slot;
        LVictim := LBinding;
        FBindings.Delete(I);
        Break;
      end;
    end;
    if LSlot <> nil then
      FSlots.Remove(LSlot);
  finally
    FLock.Release;
  end;
  if LVictim <> nil then
    LVictim.Free;
  if LSlot <> nil then
    ShutdownSlot(LSlot);
  if Assigned(FOnAfterRemove) then
    FOnAfterRemove(Self, AConnection);
end;

function TPoolBroker.Count: Integer;
begin
  FLock.Acquire;
  try
    Result := FSlots.Count;
  finally
    FLock.Release;
  end;
end;

function TPoolBroker.Clear: IPoolConnections;
var
  LList: TList;
  I: Integer;
begin
  Result := Self;
  LList := TList.Create;
  try
    FLock.Acquire;
    try
      for I := 0 to FSlots.Count - 1 do
        LList.Add(FSlots[I]);
      FSlots.Clear;
      for I := 0 to FBindings.Count - 1 do
        TProxyBinding(FBindings[I]).Free;
      FBindings.Clear;
    finally
      FLock.Release;
    end;
    for I := 0 to LList.Count - 1 do
      ShutdownSlot(TWorkerSlot(LList[I]));
  finally
    LList.Free;
  end;
  if Assigned(FOnClear) then
    FOnClear(Self);
end;

function TPoolBroker.GetByIndex(const AIndex: Integer): IConnection;
var
  LSlot: TWorkerSlot;
  LBinding: TProxyBinding;
  LProxy: TConnectionProxy;
begin
  Result := nil;
  FLock.Acquire;
  try
    if (AIndex < 0) or (AIndex >= FSlots.Count) then
      Exit;
    LSlot := TWorkerSlot(FSlots[AIndex]);
    if LSlot.Busy then
      Exit; // ocupada: no broker a fisica nunca sai - devolve nil
    LSlot.Busy := True;
    LBinding := TProxyBinding.Create;
    LBinding.ProxyId := FNextProxyId;
    Inc(FNextProxyId);
    LBinding.Slot := LSlot;
    LBinding.Sticky := False;
    LBinding.Lease.ConnId := LSlot.Worker.Id;
    LBinding.Lease.DatabaseName := LSlot.EntryName;
    LBinding.Lease.Owner := 'GetByIndex';
    LBinding.Lease.Operation := IntToStr(AIndex);
    LBinding.Lease.AcquiredAt := Now;
    LBinding.Lease.WorkerThreadId := NativeUInt(LSlot.Worker.ThreadID);
    FBindings.Add(LBinding);
    Inc(FTotalAcquired);
    LProxy := TConnectionProxy.Create(Self, LBinding.ProxyId, LSlot.Worker.ConnData);
    LBinding.ProxyPtr := Pointer(LProxy);
    Result := LProxy;
  finally
    FLock.Release;
  end;
end;

function TPoolBroker.GetByName(const AName: string): IConnection;
var
  I: Integer;
  LIdx: Integer;
begin
  Result := nil;
  LIdx := -1;
  FLock.Acquire;
  try
    for I := 0 to FSlots.Count - 1 do
      if SameText(TWorkerSlot(FSlots[I]).DisplayName, AName) or
         ((not TWorkerSlot(FSlots[I]).Busy) and SameText(TWorkerSlot(FSlots[I]).EntryName, AName)) then
      begin
        LIdx := I;
        Break;
      end;
  finally
    FLock.Release;
  end;
  if LIdx >= 0 then
    Result := GetByIndex(LIdx);
end;

function TPoolBroker.GetPoolList: TPools;
var
  I: Integer;
  LSlot: TWorkerSlot;
begin
  FLock.Acquire;
  try
    SetLength(Result, FSlots.Count);
    for I := 0 to FSlots.Count - 1 do
    begin
      LSlot := TWorkerSlot(FSlots[I]);
      Result[I].Id := LSlot.Worker.Id;
      Result[I].Name := LSlot.DisplayName;
      Result[I].Connection := nil; // snapshot informativo: a fisica nunca sai
      Result[I].ConnectionInfo := LSlot.Worker.ConnData;
      if LSlot.Busy then
        Result[I].ConnectionStatus := csConnected
      else
        Result[I].ConnectionStatus := csDisconnected; // livre (idle)
    end;
  finally
    FLock.Release;
  end;
end;

{ ---- catalogo heterogeneo ---- }

function TPoolBroker.AddDatabase(const AName: string; const AConfig: TConnectionData): IPoolConnections;
var
  LEntry: TDatabaseEntry;
begin
  Result := Self;
  FLock.Acquire;
  try
    CheckNotShutdown;
    LEntry := FindEntry(AName);
    if LEntry = nil then
    begin
      LEntry := TDatabaseEntry.Create;
      LEntry.Name := AName;
      FEntries.Add(LEntry);
    end;
    LEntry.Data := AConfig;
    LEntry.HasData := True;
    LEntry.JSON := '';
    LEntry.IniPath := '';
  finally
    FLock.Release;
  end;
end;

function TPoolBroker.FromJSON(const AName, AJSON: string): IPoolConnections;
var
  LEntry: TDatabaseEntry;
begin
  Result := Self;
  FLock.Acquire;
  try
    CheckNotShutdown;
    LEntry := FindEntry(AName);
    if LEntry = nil then
    begin
      LEntry := TDatabaseEntry.Create;
      LEntry.Name := AName;
      FEntries.Add(LEntry);
    end;
    LEntry.JSON := AJSON;
    LEntry.IniPath := '';
    LEntry.HasData := False;
  finally
    FLock.Release;
  end;
end;

function TPoolBroker.FromIniFile(const AName, AFilePath, ASection: string): IPoolConnections;
var
  LEntry: TDatabaseEntry;
begin
  Result := Self;
  FLock.Acquire;
  try
    CheckNotShutdown;
    LEntry := FindEntry(AName);
    if LEntry = nil then
    begin
      LEntry := TDatabaseEntry.Create;
      LEntry.Name := AName;
      FEntries.Add(LEntry);
    end;
    LEntry.IniPath := AFilePath;
    LEntry.IniSection := ASection;
    LEntry.JSON := '';
    LEntry.HasData := False;
  finally
    FLock.Release;
  end;
end;

function TPoolBroker.Factory(const AValue: TPoolConnectionFactory): IPoolConnections;
begin
  FFactory := AValue;
  Result := Self;
end;

{ ---- config e observabilidade ---- }

function TPoolBroker.Config(const AValue: TPoolConfig): IPoolConnections;
begin
  FLock.Acquire;
  try
    FConfig := AValue;
  finally
    FLock.Release;
  end;
  Result := Self;
end;

function TPoolBroker.Config: TPoolConfig;
begin
  FLock.Acquire;
  try
    Result := FConfig;
  finally
    FLock.Release;
  end;
end;

function TPoolBroker.Metrics: TPoolMetrics;
var
  I: Integer;
begin
  FLock.Acquire;
  try
    Result.TotalWorkers := FSlots.Count;
    Result.IdleWorkers := 0;
    for I := 0 to FSlots.Count - 1 do
      if not TWorkerSlot(FSlots[I]).Busy then
        Inc(Result.IdleWorkers);
    Result.ActiveWorkers := Result.TotalWorkers - Result.IdleWorkers;
    Result.TotalAcquired := FTotalAcquired;
    Result.TotalTimeouts := FTotalTimeouts;
    Result.CoresForPool := TPoolHardware.CoresForPool(FConfig.CPUThreshold);
    Result.GlobalCap := TPoolHardware.GlobalWorkerCap(FConfig.CPUThreshold, FConfig.WorkersPerCoreFactor);
    Result.AvgAcquireMs := 0;
    if FAcquireCount > 0 then
      Result.AvgAcquireMs := Integer(FAcquireMsTotal div FAcquireCount);
    Result.TotalScaleOuts := FTotalScaleOuts;
    Result.TotalScaleIns := FTotalScaleIns;
    Result.LeaksDetected := FLeaksDetected;
  finally
    FLock.Release;
  end;
end;

function TPoolBroker.HardwareInfo: TPoolHardwareInfo;
begin
  Result := TPoolHardware.GetInfo(Config);
end;

function TPoolBroker.ActiveLeases: TPoolLeases;
var
  I: Integer;
begin
  FLock.Acquire;
  try
    SetLength(Result, FBindings.Count);
    for I := 0 to FBindings.Count - 1 do
      Result[I] := TProxyBinding(FBindings[I]).Lease;
  finally
    FLock.Release;
  end;
end;

function TPoolBroker.QueueDepth(const ADatabaseName: string): Integer;
var
  LEntry: TDatabaseEntry;
begin
  FLock.Acquire;
  try
    LEntry := FindEntry(ADatabaseName);
    if LEntry <> nil then
      Result := LEntry.Waiting
    else
      Result := 0;
  finally
    FLock.Release;
  end;
end;

procedure TPoolBroker.Shutdown;
var
  LSlots: TList;
  LHk: TPoolHousekeeperThread;
  I: Integer;
begin
  LHk := nil;
  LSlots := TList.Create;
  try
    FLock.Acquire;
    try
      if FShutdown then
        Exit;
      FShutdown := True; // waiters de acquire veem e recebem 450002
      LHk := FHousekeeper;
      FHousekeeper := nil;
      for I := 0 to FSlots.Count - 1 do
        LSlots.Add(FSlots[I]);
      FSlots.Clear;
      for I := 0 to FBindings.Count - 1 do
        TProxyBinding(FBindings[I]).Free;
      FBindings.Clear;
      for I := 0 to FEntries.Count - 1 do
        TDatabaseEntry(FEntries[I]).Free;
      FEntries.Clear;
    finally
      FLock.Release;
    end;
    { housekeeper primeiro (fora do lock): o tick corrente ve FShutdown e
      aborta; workers em criacao pelo housekeeper sao fechadas por ele }
    if LHk <> nil then
      LHk.Free; // Destroy = Stop + WaitFor
    { fora do lock: percorre TODAS as workers -> fecho seguro + WaitFor }
    for I := 0 to LSlots.Count - 1 do
      ShutdownSlot(TWorkerSlot(LSlots[I]));
  finally
    LSlots.Free;
  end;
end;

{ ---- housekeeper (Onda 4.3b) ---- }

{ Uma ronda de manutencao: warm-up + scale-out + scale-in + leaks. Estrategia
  de lock: fase 1 recolhe TUDO sob o lock (planos por VALOR, slots retirados
  de FSlots, leases marcadas); fase 2 age FORA do lock (conectar/fechar
  workers, disparar eventos). Devolve os ms ate ao proximo tick. }
function TPoolBroker.HousekeepingTick: Integer;
var
  LPlans: array of THkCreatePlan;
  LRetire: TList;
  LLeaks: TPoolLeases;
  LEntry: TDatabaseEntry;
  LSlot: TWorkerSlot;
  LBinding: TProxyBinding;
  LBudget, LSlotCount, LWanted, I: Integer;
begin
  Result := DEFAULT_POOL_HOUSEKEEPER_INTERVAL_MS;
  SetLength(LPlans, 0);
  SetLength(LLeaks, 0);
  LRetire := TList.Create;
  try
    FLock.Acquire;
    try
      Result := FConfig.HousekeeperIntervalMs;
      if FShutdown then
        Exit;
      { orcamento global de criacao (teto de hardware 80/20) }
      LBudget := TPoolHardware.GlobalWorkerCap(FConfig.CPUThreshold,
        FConfig.WorkersPerCoreFactor) - FSlots.Count;
      { warm-up (MinPoolSize) + scale-out (fila > threshold) por banco }
      for I := 0 to FEntries.Count - 1 do
      begin
        LEntry := TDatabaseEntry(FEntries[I]);
        LSlotCount := EntrySlotCount(LEntry.Name);
        LWanted := 0;
        if LSlotCount < FConfig.MinPoolSize then
          LWanted := FConfig.MinPoolSize - LSlotCount;
        if (LEntry.Waiting > FConfig.ScaleOutQueueThreshold) and
           (LSlotCount + LWanted < FConfig.MaxPoolSizePerDatabase) then
          Inc(LWanted); // gargalo: +1 worker por tick (rampa suave)
        if LSlotCount + LWanted > FConfig.MaxPoolSizePerDatabase then
          LWanted := FConfig.MaxPoolSizePerDatabase - LSlotCount;
        while (LWanted > 0) and (LBudget > 0) do
        begin
          SetLength(LPlans, Length(LPlans) + 1);
          LPlans[High(LPlans)].Name       := LEntry.Name;
          LPlans[High(LPlans)].JSON       := LEntry.JSON;
          LPlans[High(LPlans)].IniPath    := LEntry.IniPath;
          LPlans[High(LPlans)].IniSection := LEntry.IniSection;
          LPlans[High(LPlans)].Data       := LEntry.Data;
          LPlans[High(LPlans)].UseFactory := Assigned(FFactory);
          Dec(LWanted);
          Dec(LBudget);
        end;
      end;
      { scale-in: livres ha mais de IdleTimeoutMs; preserva MinPoolSize por
        banco; adhoc/adoptadas (EntryName='') NUNCA sao retiradas (paridade
        v2: Add/TryAdd transfere a posse mas nao autoriza descarte) }
      for I := FSlots.Count - 1 downto 0 do
      begin
        LSlot := TWorkerSlot(FSlots[I]);
        if LSlot.Busy or (LSlot.EntryName = '') then
          Continue;
        if ((Now - LSlot.LastUsedAt) * MSecsPerDay) <= FConfig.IdleTimeoutMs then
          Continue;
        if EntrySlotCount(LSlot.EntryName) <= FConfig.MinPoolSize then
          Continue;
        FSlots.Delete(I);
        LRetire.Add(LSlot);
        Inc(FTotalScaleIns);
      end;
      { leaks: lease vivo ha mais de LeakWarningTimeoutMs (uma notificacao) }
      for I := 0 to FBindings.Count - 1 do
      begin
        LBinding := TProxyBinding(FBindings[I]);
        if LBinding.LeakNotified then
          Continue;
        if ((Now - LBinding.Lease.AcquiredAt) * MSecsPerDay) > FConfig.LeakWarningTimeoutMs then
        begin
          LBinding.LeakNotified := True;
          Inc(FLeaksDetected);
          SetLength(LLeaks, Length(LLeaks) + 1);
          LLeaks[High(LLeaks)] := LBinding.Lease;
        end;
      end;
    finally
      FLock.Release;
    end;
    { fase 2 - fora do lock }
    for I := 0 to LRetire.Count - 1 do
      ShutdownSlot(TWorkerSlot(LRetire[I]));
    for I := 0 to High(LPlans) do
      HkCreateWorker(LPlans[I]);
    if Assigned(FOnConnectionLeak) then
      for I := 0 to High(LLeaks) do
        FOnConnectionLeak(Self, LLeaks[I]);
{$IFDEF USE_LOGGERS}
    for I := 0 to High(LLeaks) do
      FLogger.Warning(Format('ConnectionLeak: %s owner=%s operation=%s (worker %d)',
        [LLeaks[I].DatabaseName, LLeaks[I].Owner, LLeaks[I].Operation, Int64(LLeaks[I].WorkerThreadId)]));
{$ENDIF}
  finally
    LRetire.Free;
  end;
end;

{ Cria uma worker PRE-AQUECIDA para o plano (fora do lock: conectar demora).
  So entra em FSlots depois de READY - invariante "slot livre = pronto"
  preservada. Se as condicoes mudarem entretanto (shutdown/tetos), a worker
  e fechada aqui mesmo - nunca fica orfa. }
procedure TPoolBroker.HkCreateWorker(const APlan: THkCreatePlan);
var
  LW: TConnectionWorkerThread;
  LSlot: TWorkerSlot;
  LId: Integer;
  LErr: string;
begin
  FLock.Acquire;
  try
    if FShutdown then
      Exit;
    LId := FNextId;
    Inc(FNextId);
  finally
    FLock.Release;
  end;
  LW := TConnectionWorkerThread.Create(LId);
  if APlan.UseFactory then
    LW.SetupFactory(FFactory)
  else if APlan.JSON <> '' then
    LW.SetupJSON(APlan.JSON)
  else if APlan.IniPath <> '' then
    LW.SetupIni(APlan.IniPath, APlan.IniSection)
  else
    LW.SetupData(APlan.Data);
  LW.Start;
  LErr := LW.WaitReady(Config.ConnectTimeoutMs);
  if LErr = '' then
  begin
    FLock.Acquire;
    try
      if (not FShutdown) and
         (EntrySlotCount(APlan.Name) < FConfig.MaxPoolSizePerDatabase) and
         (FSlots.Count < TPoolHardware.GlobalWorkerCap(FConfig.CPUThreshold, FConfig.WorkersPerCoreFactor)) then
      begin
        LSlot := TWorkerSlot.Create;
        LSlot.Worker := LW;
        LSlot.Busy := False;
        LSlot.EntryName := APlan.Name;
        LSlot.DisplayName := APlan.Name + '-' + IntToStr(LW.Id);
        LSlot.DedupKey := '';
        LSlot.LastUsedAt := Now;
        FSlots.Add(LSlot);
        Inc(FTotalScaleOuts);
        LW := nil; // posse transferida para o slot
      end;
    finally
      FLock.Release;
    end;
  end;
  if LW <> nil then
  begin
    { conexao falhou OU condicoes mudaram: fecho ordenado }
    LW.CloseQueue;
    LW.Terminate;
    LW.Free;
  end;
end;

{ ---- eventos (setters fluentes) ---- }

function TPoolBroker.OnBeforeAdd(const AValue: TPoolConnectionEvent): IPoolConnections;
begin
  FOnBeforeAdd := AValue;
  Result := Self;
end;

function TPoolBroker.OnAfterAdd(const AValue: TPoolConnectionEvent): IPoolConnections;
begin
  FOnAfterAdd := AValue;
  Result := Self;
end;

function TPoolBroker.OnBeforeRemove(const AValue: TPoolConnectionEvent): IPoolConnections;
begin
  FOnBeforeRemove := AValue;
  Result := Self;
end;

function TPoolBroker.OnAfterRemove(const AValue: TPoolConnectionEvent): IPoolConnections;
begin
  FOnAfterRemove := AValue;
  Result := Self;
end;

function TPoolBroker.OnBeforeGetFromPool(const AValue: TNotifyEvent): IPoolConnections;
begin
  FOnBeforeGetFromPool := AValue;
  Result := Self;
end;

function TPoolBroker.OnAfterGetFromPool(const AValue: TPoolConnectionEvent): IPoolConnections;
begin
  FOnAfterGetFromPool := AValue;
  Result := Self;
end;

function TPoolBroker.OnBeforeReturnToPool(const AValue: TPoolConnectionEvent): IPoolConnections;
begin
  FOnBeforeReturnToPool := AValue;
  Result := Self;
end;

function TPoolBroker.OnAfterReturnToPool(const AValue: TPoolConnectionEvent): IPoolConnections;
begin
  FOnAfterReturnToPool := AValue;
  Result := Self;
end;

function TPoolBroker.OnClear(const AValue: TNotifyEvent): IPoolConnections;
begin
  FOnClear := AValue;
  Result := Self;
end;

function TPoolBroker.OnPoolExhausted(const AValue: TPoolExhaustedEvent): IPoolConnections;
begin
  FOnPoolExhausted := AValue;
  Result := Self;
end;

function TPoolBroker.OnConnectionLeak(const AValue: TPoolLeakEvent): IPoolConnections;
begin
  FOnConnectionLeak := AValue;
  Result := Self;
end;

{$IFDEF USE_LOGGERS}
function TPoolBroker.SetLogger(const ALogger: ILogger): IPoolConnections;
begin
  if Assigned(ALogger) then
    FLogger := ALogger
  else
    FLogger := TNullLogger.New;
  Result := Self;
end;
{$ENDIF}

{$ENDIF}

end.
