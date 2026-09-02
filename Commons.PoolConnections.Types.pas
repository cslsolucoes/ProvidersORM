{ =============================================================================
  Commons.PoolConnections.Types - Tipos e contratos-dado do PoolConnections v3

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  2.0.0
  FileVersion:    1.2.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           10/07/2026

  Broker Elastico (Onda 4.3): dados publicos mas exclusivos do dominio pool
  (regra D11 refinada) + CONTRATOS DE FRONTEIRA cross-modulo (IPoolBroker,
  IPooledConnection, TPoolRequest) que vivem no nucleo Commons para o
  TConnectionProxy (modulo Connections) NAO depender do modulo PoolConnections
  (DIP - ordem topologica preservada: pool depende de Connections, nunca o
  inverso).

  Pecas: TPoolConfig (parametros; o CALCULO de hardware vive em
  PoolConnections.Hardware) - TPoolRequest (a "mensagem" do broker) -
  IPoolBroker (roteamento minimo consumido pelo proxy) - IPooledConnection -
  TPoolLease/TPoolMetrics/TPoolHardwareInfo - TPool/TPools (paridade v2.3.0) -
  eventos.

  Changelog (file):
  - 1.2.0 (12/07/2026): bug-164 - TPoolConfig.ConnectTimeoutMs (criacao de
    worker; separado do AcquireTimeoutMs, que governa a espera por livre).
  - 1.1.0 (11/07/2026): Onda 4.3b - TPoolDirectProc + rqExecuteDirect +
    IPooledConnection.ExecuteDirect (passthrough de interfaces estendidas na
    worker, bug-157); TPoolLeakEvent; TPoolConfig.HousekeeperIntervalMs/
    ScaleOutQueueThreshold; TPoolMetrics.AvgAcquireMs/TotalScaleOuts/
    TotalScaleIns/LeaksDetected.
  - 1.0.0 (10/07/2026): versao inicial (Onda 4.3 Etapa A2).
  ============================================================================= }
unit Commons.PoolConnections.Types;

{$I ../ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$IFDEF USE_POOLCONNECTIONS}

uses
{$IFDEF FPC}
  SysUtils, Classes, SyncObjs, DB,
{$ELSE}
  System.SysUtils, System.Classes, System.SyncObjs, Data.DB,
{$ENDIF}
  Commons.Types,
  Connections.Interfaces;

type
  { Tipo de pedido marshalado do proxy para a worker (a "mensagem" do broker).
    Cada chamada DB do TConnectionProxy vira UM TPoolRequest. }
  TPoolRequestKind = (
    rqConnect, rqDisconnect, rqIsConnected, rqPing,
    rqExecuteQuery, rqExecuteQueryParams,
    rqExecuteCommand, rqExecuteCommandParams,
    rqExecuteScalar, rqExecuteScalarParams,
    rqBeginTransaction, rqCommit, rqRollback, rqInTransaction,
    rqGetServerVersion, rqGetClientVersion,
    rqGetTableNames, rqGetDatabaseNames, rqGetSchemaNames,
    rqGetColumnNames, rqGetTableStructure,
    rqIsRequiredDllFound,
    rqExecuteDirect
  );

  { Callback executado NA Worker Thread com a conexao FISICA (Onda 4.3b -
    passthrough de interfaces estendidas, ex. LDAP). Procedure PLANA com
    contexto (sem anonymous methods - FPC). A referencia NAO pode ser guardada
    para fora do callback (a fisica pertence a worker). }
  TPoolDirectProc = procedure(const AConnection: IConnection; AContext: Pointer);

  { A mensagem: parametros de entrada + slots de resultado + sinal de conclusao.
    Classe (nao record) porque transporta um TEvent e arrays dinamicos, e a
    posse atravessa threads (criada pelo proxy, preenchida pela worker). }
  TPoolRequest = class
  public
    Kind          : TPoolRequestKind;
    SQL           : string;
    Params        : TArray<Variant>;
    StrArg1       : string;   // metadados: tabela / database
    StrArg2       : string;   // metadados: schema
    DirectProc    : TPoolDirectProc; // rqExecuteDirect (4.3b)
    DirectContext : Pointer;
    { slots de resultado (preenchidos pela worker) }
    ResultDataSet : TDataSet; // ja DESCONECTADO (Memory DataSet - Etapa A1)
    ResultInt     : Integer;
    ResultVariant : Variant;
    ResultStr     : string;
    ResultBool    : Boolean;
    ResultStrArr  : TStringArray;
    ResultFields  : TArray<TDatabaseFields>;
    { erro relancado no lado do solicitante (codigo+mensagem preservados) }
    HasError      : Boolean;
    ErrorClass    : string;
    ErrorMessage  : string;
    ErrorCode     : Integer;
    { conclusao }
    Done          : TEvent;
    constructor Create(const AKind: TPoolRequestKind);
    destructor Destroy; override;
  end;

  { Contrato MINIMO de roteamento consumido pelo TConnectionProxy (Connections).
    Implementado pelo TPoolBroker (modulo PoolConnections). O proxy nao conhece
    filas nem workers - entrega o pedido e espera; sticky sessions por ProxyId. }
  IPoolBroker = interface
    ['{5A7E9C10-2B4D-4E6F-8A90-1C2D3E4F5A60}']
    { Encaminha o pedido para a worker adequada (sticky-aware), BLOQUEIA ate a
      conclusao e devolve com os slots preenchidos (ou HasError). }
    procedure ExecuteRequest(const AProxyId: Integer; const ARequest: TPoolRequest);
    { Sticky session (transacoes): reserva worker exclusiva para o proxy. }
    procedure BeginSticky(const AProxyId: Integer);
    procedure EndSticky(const AProxyId: Integer);
    { Devolucao do lease (Release explicito ou Destroy do proxy). }
    procedure ProxyReleased(const AProxyId: Integer);
  end;

  { Conexao entregue pelo pool: IConnection PLENA + devolucao explicita.
    Contrato de fronteira (proxy implementa; broker devolve) -> Commons. }
  IPooledConnection = interface(IConnection)
    ['{C1D2E3F4-A5B6-4789-9ABC-DEF012345678}']
    { Devolve a worker ao pool (idempotente). O refcount-0 do proxy tambem
      devolve; Disconnect num pooled = Release (transparencia). }
    procedure Release;
    { Executa AProc NA Worker Thread com a conexao FISICA (bloqueia ate
      concluir; excecoes relancadas no caller). Unica porta para interfaces
      estendidas da fisica (ex. IConnectionsActiveDirectory) via pool. }
    procedure ExecuteDirect(const AProc: TPoolDirectProc; const AContext: Pointer);
  end;

  { Configuracao do pool - SO parametros (dado puro); o calculo de hardware
    (CoresForPool/GlobalWorkerCap) vive em PoolConnections.Hardware. }
  TPoolConfig = record
    MinPoolSize            : Integer;  // warm-up por banco (housekeeper)
    MaxPoolSizePerDatabase : Integer;
    AcquireTimeoutMs       : Integer;  // espera por worker LIVRE
    ConnectTimeoutMs       : Integer;  // CRIACAO de worker (connect da fisica; bug-164)
    IdleTimeoutMs          : Integer;  // scale-in (housekeeper)
    LeakWarningTimeoutMs   : Integer;  // detecao de leaks (housekeeper)
    ValidateOnBorrow       : Boolean;  // test-on-borrow (Ping ao reusar worker)
    PoolType               : TConnectionPoolType;
    CPUThreshold           : Integer;  // teto do pool em % (owner: 80; SO fica com 100-CPUThreshold)
    WorkersPerCoreFactor   : Integer;
    HousekeeperIntervalMs  : Integer;  // cadencia do monitor (4.3b)
    ScaleOutQueueThreshold : Integer;  // fila > X = gargalo -> scale-out (4.3b)
    class function GetDefault: TPoolConfig; static;
  end;

  { Snapshot da analise de hardware (para metricas/dashboard 4.4). }
  TPoolHardwareInfo = record
    ProcessorCount  : Integer;
    CoresForPool    : Integer;
    ReservedForOS   : Integer;
    GlobalWorkerCap : Integer;
  end;

  { Lease activo (rastreio owner/operation - requisito do ecossistema). }
  TPoolLease = record
    ConnId         : Integer;
    DatabaseName   : string;
    Owner          : string;
    Operation      : string;
    AcquiredAt     : TDateTime;
    ReleasedAt     : TDateTime;
    WorkerThreadId : NativeUInt;
  end;
  TPoolLeases = array of TPoolLease;

  { Metricas do broker. }
  TPoolMetrics = record
    TotalWorkers   : Integer;
    IdleWorkers    : Integer;
    ActiveWorkers  : Integer;
    TotalAcquired  : Integer;
    TotalTimeouts  : Integer;
    CoresForPool   : Integer;
    GlobalCap      : Integer;
    { housekeeper (4.3b) }
    AvgAcquireMs   : Integer;
    TotalScaleOuts : Integer;
    TotalScaleIns  : Integer;
    LeaksDetected  : Integer;
  end;

  { Entrada nomeada do pool (paridade v2.3.0 - GetPoolList/GetByName/GetByIndex). }
  TPool = record
    Id               : Integer;
    Name             : string;
    Connection       : IConnection;
    ConnectionInfo   : TConnectionData;
    ConnectionStatus : TConnectionStatus;
  end;
  TPools = array of TPool;

  { Eventos (paridade v2.3.0 + broker). }
  TPoolConnectionEvent  = procedure(Sender: TObject; const AConnection: IConnection) of object;
  TPoolExhaustedEvent   = procedure(Sender: TObject; const ADatabaseName: string; const AWaitedMs: Integer) of object;
  TPoolLeakEvent        = procedure(Sender: TObject; const ALease: TPoolLease) of object;
  TPoolConnectionFactory = function: IConnection of object;

{$ENDIF}

implementation

{$IFDEF USE_POOLCONNECTIONS}

uses
  Commons.PoolConnections.Consts;

{ TPoolRequest }

constructor TPoolRequest.Create(const AKind: TPoolRequestKind);
begin
  inherited Create;
  Kind := AKind;
  Done := TEvent.Create(nil, True, False, ''); // manual-reset
  HasError := False;
  ResultDataSet := nil;
end;

destructor TPoolRequest.Destroy;
begin
  Done.Free;
  { ResultDataSet pertence ao CALLER depois de consumido; se o pedido morrer
    com o dataset ainda aqui (erro antes da entrega), liberta-o. }
  ResultDataSet.Free;
  inherited;
end;

{ TPoolConfig }

class function TPoolConfig.GetDefault: TPoolConfig;
begin
  Result.MinPoolSize            := DEFAULT_POOL_MIN_SIZE;
  Result.MaxPoolSizePerDatabase := DEFAULT_POOL_MAX_SIZE_PER_DATABASE;
  Result.AcquireTimeoutMs       := DEFAULT_POOL_ACQUIRE_TIMEOUT_MS;
  Result.ConnectTimeoutMs       := DEFAULT_POOL_CONNECT_TIMEOUT_MS;
  Result.IdleTimeoutMs          := DEFAULT_POOL_IDLE_TIMEOUT_MS;
  Result.LeakWarningTimeoutMs   := DEFAULT_POOL_LEAK_WARNING_MS;
  Result.ValidateOnBorrow       := False;
  Result.PoolType               := cptDynamic;
  Result.CPUThreshold           := DEFAULT_POOL_CPU_THRESHOLD;
  Result.WorkersPerCoreFactor   := DEFAULT_POOL_WORKERS_PER_CORE;
  Result.HousekeeperIntervalMs  := DEFAULT_POOL_HOUSEKEEPER_INTERVAL_MS;
  Result.ScaleOutQueueThreshold := DEFAULT_POOL_SCALEOUT_QUEUE_THRESHOLD;
end;

{$ENDIF}

end.
