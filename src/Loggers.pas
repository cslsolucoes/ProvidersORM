{ =============================================================================
  Loggers - Factory + convergência do módulo Loggers (v3)

  TLoggerImpl: fan-out (uma entrada vai a todos os canais registados) +
  fail-over de resiliência (canal que falha MaxFailsBeforeDisable vezes
  consecutivas desativa-se sozinho; uma exceção de canal NUNCA propaga para
  o chamador de Log/Info/Error/...). Dispatch síncrono ou assíncrono (via
  TLoggerQueue + worker thread próprio) conforme o parâmetro 'Async'.
  Bootstrap idempotente dos ~49 parâmetros de configuração via IParameters
  (F7) — só semeia as chaves que faltarem, nunca sobrescreve customização.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.15.0
  FileVersion:    1.14.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           01/08/2026

  Changelog (file):
  - 1.14.0 (01/08/2026): FASE 8 — TLoggerImpl.Create regista também
    TLoggerChannelSysLog (canal SysLog RFC5424 via ICS TWSocket, UDP
    fire-and-forget por default ou TCP com framing LF; 13º canal baseline,
    6º canal REAL sobre ICS — reusa o mesmo motor/padrão do canal Redis;
    degrada-se sozinho sob FPC/sem USE_LOGGERS_SYSLOG/sem Host configurado).
    ModuleVersion do módulo inteiro 1.14.0→1.15.0.
  - 1.13.0 (31/07/2026): FASE 8 Onda 8.16 — TLoggerImpl.Create regista também
    TLoggerChannelElasticSearch (canal Bulk Index API via ICS, POST NDJSON
    para <Scheme>://<Host>:<Port>/<Index>/_bulk; 12º canal baseline, 5º canal
    REAL sobre ICS - reusa a mesma máquina HTTP/TLS do canal Http, não
    duplica cliente; degrada-se sozinho sob FPC/sem
    USE_LOGGERS_ELASTICSEARCH/sem Host configurado). ModuleVersion do módulo
    inteiro 1.13.0→1.14.0.
  - 1.12.0 (31/07/2026): FASE 8 Onda 8.15 — TLoggerImpl.Create regista também
    TLoggerChannelRedis (canal Redis PUBLISH/LPUSH via ICS TWSocket, RESP2,
    Delphi-only, cliente sincrono por-tentativa; 11º canal baseline, 4º canal
    REAL sobre ICS - universal na ordem de registo, degrada-se sozinho sob
    FPC/sem USE_LOGGERS_REDIS/sem Host configurado). ModuleVersion do módulo
    inteiro 1.12.0→1.13.0.
  - 1.11.0 (31/07/2026): FASE 8 Onda 8.4.7 — TLoggerImpl.Create regista também
    TLoggerChannelMemory (canal ring-buffer in-memory, 10º canal baseline;
    universal - sem restrição de plataforma, mesma regra dos outros canais
    locais: sempre registado, degrada-se sozinho só se Enabled=False na
    config). ModuleVersion do módulo inteiro 1.11.0→1.12.0.
  - 1.10.0 (31/07/2026): FASE 8 Onda 8.4.6 — TLoggerImpl.Create regista também
    TLoggerChannelConsole (canal stdout via Writeln, 9º canal baseline;
    universal - sem restrição de plataforma, mesma regra dos outros canais
    locais: sempre registado, degrada-se sozinho só se Enabled=False na
    config). ModuleVersion do módulo inteiro 1.10.0→1.11.0.
  - 1.9.0 (27/07/2026): F8 Onda 8.9 (hardening pos-auditoria) - C1: dispatch (DispatchToChannels) deixa de segurar o FLock global durante o Write() dos canais (copy-under-lock + AtomicInc/Dec de FPending) -> um canal lento ja nao bloqueia toda a app; C2: canal auto-desativado recupera apos cooldown (FRecoveryMs/LOGGERS_CHANNEL_RECOVERY_MS); C3: excecao de canal ganha diagnostico (OutputDebugString, Delphi-Windows). ModuleVersion do modulo 1.9.0->1.10.0.
  - 1.8.0 (23/07/2026): FASE 8 Onda 8.4.5 — TLoggerImpl.Create regista também
    TLoggerChannelWebSocket (canal WebSocket broadcast-only via ICS,
    Delphi-only, resolve pendência P2; degrada-se sozinho sob FPC/sem
    USE_LOGGERS_WEBSOCKET/sem Enabled=True configurado). ModuleVersion do
    módulo inteiro 1.8.0→1.9.0.
  - 1.7.0 (23/07/2026): FASE 8 Onda 8.4.4 — TLoggerImpl.Create regista também
    TLoggerChannelEmail (canal Email/SMTP via ICS, Delphi-only, com agregação
    N-entradas->1-email; degrada-se sozinho sob FPC/sem USE_LOGGERS_EMAIL/sem
    Host+FromAddress+ToAddresses configurados). BootstrapParameters passou a
    delegar o mapeamento nome->TLogLevel para a nova função partilhada
    Commons.Loggers.Types.StrToLogLevel (comportamento byte-idêntico).
    ModuleVersion do módulo inteiro 1.7.0→1.8.0.
  - 1.6.0 (23/07/2026): FASE 8 Onda 8.4.3 — TLoggerImpl.Create regista também
    TLoggerChannelHttp (canal HTTP genérico via ICS, Delphi-only — 1º canal
    real sobre ICS; degrada-se sozinho sob FPC/sem USE_LOGGERS_HTTP/sem Url
    configurado). ModuleVersion do módulo inteiro 1.6.0→1.7.0.
  - 1.5.0 (23/07/2026): FASE 8 Onda 8.4.2 — TLoggerImpl.Create regista também
    TLoggerChannelCSV (canal CSV, reutiliza TLoggerChannelFileBase - mesma
    mecânica de rotação/retenção do TextFile/Json). ModuleVersion do módulo
    inteiro 1.5.0→1.6.0 (nova capacidade, não só bug fix).
  - 1.4.0 (23/07/2026): FASE 8 Onda 8.4.1 — TLoggerImpl.Create regista também
    TLoggerChannelEventLog (canal Windows Event Log, mesma regra dos outros
    baseline: sempre registado, degrada-se sozinho fora do Windows/sem
    USE_LOGGERS_EVENTLOG). ModuleVersion do módulo inteiro 1.4.0→1.5.0 (nova
    capacidade, não só bug fix).
  - (sync 22/07/2026) ModuleVersion sincronizado para 1.4.0 - Loggers.Channel.Database.pas removeu a dependencia de IPoolConnections/TPoolBroker (conexao propria, direta), decisao de arquitectura do owner ('o Loggers via consumir sem pool direto o Connections'); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.4.0.
  - 1.3.0 (22/07/2026): FASE 8 Onda 8.3 — TLoggerImpl.Create regista também
    TLoggerChannelDatabase (canal sobre pool, perfil 'loggers'); mesma regra
    dos canais de ficheiro (sempre registado, cada canal decide o próprio
    Enabled/Ready).
  - 1.2.0 (22/07/2026): FASE 8 Onda 8.2 — TLoggerImpl.Create regista sempre os
    2 canais baseline (TLoggerChannelTextFile/TLoggerChannelJson); cada canal
    lê o próprio Enabled da config (DispatchToChannels já ignora desativados).
  - 1.1.0 (22/07/2026): revisão pós-verificação independente da onda 8.1 —
    FChannels TList->TList<ILoggerChannel> (corrige use-after-free: TList
    pointer-based não fazia refcount de interface, objeto podia ser libertado
    antes do fan-out); fail-over REAL (try/except por canal + contagem de
    falhas consecutivas + desativação automática, nunca propaga exceção);
    dispatch assíncrono real via TLoggerWorkerThread consumindo TLoggerQueue
    quando Async=True; BootstrapParameters deixou de ser stub — semeia os 48
    parâmetros (Commons.Loggers.Consts.LOGGERS_PARAM_DEFAULTS) via
    IParameters.Exists/Insert (zero SQL manual, USE_PARAMETERS-gated) e lê a
    config do núcleo (MinLevel/Async/QueueMaxSize/FailoverEnabled/MaxFails)
    de volta; MinLevel passa a comparar por LOG_LEVEL_SEVERITY (não Ord);
    ExceptionClass/Message agora populados quando AException é passado;
    Flush espera FPending=0 (contador de entradas aceites mas ainda não
    despachadas) em vez de FQueue.Count=0 - corrige corrida onde o Pop do
    worker já tinha removido o item da fila mas o DispatchToChannels ainda
    não tinha terminado (Flush podia devolver antes da última entrada
    chegar aos canais).
  - 1.0.0 (21/07/2026): FASE 8 Onda 8.1 — TLogger (fan-out, fail-over).
  ============================================================================= }

unit Loggers;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_LOGGERS}

uses
{$IF DEFINED(FPC)}
  SysUtils, Classes, Generics.Collections, SyncObjs,
{$ELSE}
  System.SysUtils, System.Classes, System.Generics.Collections, System.SyncObjs,
  Winapi.Windows,
{$ENDIF}
  Commons.Types,
  Commons.Loggers.Types,
  Loggers.Interfaces,
  Loggers.Queue;

type
  TLoggers = class
  public
    class function New: ILogger; static;
  end;

{$ENDIF USE_LOGGERS}

implementation

{$IFDEF USE_LOGGERS}

uses
  Loggers.Channel.TextFile,
  Loggers.Channel.Json,
  Loggers.Channel.Database,
  Loggers.Channel.EventLog,
  Loggers.Channel.CSV,
  Loggers.Channel.Console,
  Loggers.Channel.Memory,
  Loggers.Channel.Http,
  Loggers.Channel.Email,
  Loggers.Channel.WebSocket,
  Loggers.Channel.Redis,
  Loggers.Channel.ElasticSearch,
  Loggers.Channel.SysLog
{$IFDEF USE_PARAMETERS}
  , Commons.Loggers.Consts
  , Parameters.Interfaces
  , Parameters
  , Loggers.Connections
{$ENDIF}
{$IF DEFINED(USE_LOGGERS_NET) AND DEFINED(USE_PARAMETERS)}
  , OverbyteIcsTypes       // GSSL_DLL_DIR: dir das DLLs OpenSSL do ICS
  , Commons.DynamicLibrary // ResolveDllBasePath / AppendPathEnv (SSOT de path de DLL)
  , Commons.Consts         // DLL_PLATFORM_SUBDIR
{$IFEND}, Commons.Diagnostics;

type
  { Alias p/ SysUtils.Exception, declarado FORA do escopo de TLoggerImpl.
    TLoggerImpl tem um metodo publico proprio chamado "Exception" (contrato
    ILogger.Exception) que faz sombra ao tipo global dentro dos metodos da
    classe - usar TSysException em vez de Exception dentro de TLoggerImpl. }
  TSysException = Exception;

  TLoggerDispatchProc = procedure(const AEntry: TLoggerEntry) of object;

  { Worker thread do dispatch assíncrono: consome TLoggerQueue e chama o
    callback de dispatch (fan-out+fail-over) fora da thread do chamador. }
  TLoggerWorkerThread = class(TThread)
  strict private
    FQueue    : TLoggerQueue;
    FDispatch : TLoggerDispatchProc;
  protected
    procedure Execute; override;
  public
    constructor Create(const AQueue: TLoggerQueue; const ADispatch: TLoggerDispatchProc);
  end;

constructor TLoggerWorkerThread.Create(const AQueue: TLoggerQueue; const ADispatch: TLoggerDispatchProc);
begin
  inherited Create(True);  { suspensa - Start explicito pelo dono, apos o Create devolver (padrao já usado em Database.QueryBuilder.Sychronize/PoolConnections deste projeto). }
  FreeOnTerminate := False;
  FQueue := AQueue;
  FDispatch := ADispatch;
end;

procedure TLoggerWorkerThread.Execute;
var
  LEntry: TLoggerEntry;
begin
  while not Terminated do
  begin
    if FQueue.Pop(LEntry, 250) then
    begin
      if Assigned(FDispatch) then
        try
          FDispatch(LEntry);
        except
          { um canal com defeito nunca derruba o worker. }
        end;
    end
    else if FQueue.IsClosed then
      Break;
  end;
  { drena o que sobrar após o Close (shutdown gracioso, sem bloquear). }
  while FQueue.Pop(LEntry, 0) do
    if Assigned(FDispatch) then
      try
        FDispatch(LEntry);
      except
        { 15.3/T10: engolir aqui e deliberado (canal com defeito nao derruba o dispatch),
          mas nao pode ser MUDO - sem rasto o defeito fica invisivel. }
        on E: TSysException do  { alias local da unit (l.171) }
          TraceSwallowed('TLoggerWorkerThread.Execute', 'canal com defeito nao derruba o dispatch', E);
      end;
end;

type
  TLoggerImpl = class(TInterfacedObject, ILogger)
  strict private
    FLock           : TCriticalSection;
    FChannels       : TList<ILoggerChannel>;
    FMinLevel       : TLogLevel;
    FAsync          : Boolean;
    FFailoverEnabled: Boolean;
    FMaxFails       : Integer;
    FFlushIntervalMs: Integer;
    FQueue          : TLoggerQueue;
    FWorker         : TLoggerWorkerThread;
    FOnBeforeWrite  : TLoggerBeforeWriteEvent;
    FOnAfterWrite   : TLoggerAfterWriteEvent;
    FOnLevelCheck   : TLoggerLevelCheckEvent;
    FChannelFails   : TDictionary<string, Integer>;
    FChannelDisabledAt: TDictionary<string, UInt32>;  { tick (GetTickCount) de quando cada canal foi auto-desativado - base do cooldown de reativacao (C2, auditoria F8). }
    FRecoveryMs     : Integer;  { cooldown ms antes de reativar um canal auto-desativado (0 = nunca reativa). }
    FPending        : Integer;  { entradas aceites mas ainda nao despachadas a todos os canais - Flush espera chegar a 0 (contador atomico, C1). }
    procedure DoLog(ALevel: TLogLevel; const AMessage: string; AException: TObject);
    procedure DispatchToChannels(const AEntry: TLoggerEntry);
    procedure BootstrapParameters;
{$IF DEFINED(USE_LOGGERS_NET) AND DEFINED(USE_PARAMETERS)}
    { Aponta o OpenSSL do ICS ao dll\ do projeto (SSOT), reusando o DllBasePath
      do perfil 'loggers'. Aditivo/gated - so' afeta os canais de rede TLS. }
    procedure ConfigureIcsOpenSslDir;
{$IFEND}
  public
    constructor Create;
    destructor Destroy; override;
    function RegisterChannel(const AChannel: ILoggerChannel): ILogger;
    function MinLevel: TLogLevel; overload;
    function MinLevel(const AValue: TLogLevel): ILogger; overload;
    procedure Info(const AMessage: string); overload;
    procedure Info(const AMessage: string; const AData: array of const); overload;
    procedure Info(const AMessage: string; AException: TObject); overload;
    procedure Success(const AMessage: string); overload;
    procedure Success(const AMessage: string; const AData: array of const); overload;
    procedure Success(const AMessage: string; AException: TObject); overload;
    procedure Warning(const AMessage: string); overload;
    procedure Warning(const AMessage: string; const AData: array of const); overload;
    procedure Warning(const AMessage: string; AException: TObject); overload;
    procedure Error(const AMessage: string); overload;
    procedure Error(const AMessage: string; const AData: array of const); overload;
    procedure Error(const AMessage: string; AException: TObject); overload;
    procedure Critical(const AMessage: string); overload;
    procedure Critical(const AMessage: string; const AData: array of const); overload;
    procedure Critical(const AMessage: string; AException: TObject); overload;
    procedure Exception(const AMessage: string; E: TObject); overload;
    procedure Exception(const AMessage: string; const AData: array of const; E: TObject); overload;
    procedure Debug(const AMessage: string); overload;
    procedure Debug(const AMessage: string; const AData: array of const); overload;
    procedure Debug(const AMessage: string; AException: TObject); overload;
    procedure Trace(const AMessage: string); overload;
    procedure Trace(const AMessage: string; const AData: array of const); overload;
    procedure Trace(const AMessage: string; AException: TObject); overload;
    procedure Done(const AMessage: string); overload;
    procedure Done(const AMessage: string; const AData: array of const); overload;
    procedure Done(const AMessage: string; AException: TObject); overload;
    procedure Log(ALevel: TLogLevel; const AMessage: string); overload;
    procedure Log(ALevel: TLogLevel; const AMessage: string; const AData: array of const); overload;
    procedure Log(ALevel: TLogLevel; const AMessage: string; AException: TObject); overload;
    procedure Flush;
    function OnBeforeWrite: TLoggerBeforeWriteEvent; overload;
    function OnBeforeWrite(const AValue: TLoggerBeforeWriteEvent): ILogger; overload;
    function OnAfterWrite: TLoggerAfterWriteEvent; overload;
    function OnAfterWrite(const AValue: TLoggerAfterWriteEvent): ILogger; overload;
    function OnLevelCheck: TLoggerLevelCheckEvent; overload;
    function OnLevelCheck(const AValue: TLoggerLevelCheckEvent): ILogger; overload;
  end;

constructor TLoggerImpl.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FChannels := TList<ILoggerChannel>.Create;
  FChannelFails := TDictionary<string, Integer>.Create;
  FChannelDisabledAt := TDictionary<string, UInt32>.Create;
  FMinLevel := llInfo;
  FAsync := True;
  FFailoverEnabled := True;
  FMaxFails := 5;
  FFlushIntervalMs := 500;
  FRecoveryMs := 30000;
  FQueue := TLoggerQueue.Create(10000);
  FWorker := nil;
  BootstrapParameters;  { pode substituir FQueue por uma com capacidade configurada. }

  { Canais baseline (onda 8.2) + EventLog (onda 8.4.1) + CSV (onda 8.4.2) +
    Http (onda 8.4.3) + Email (onda 8.4.4) + WebSocket (onda 8.4.5) — sempre
    registados; cada um lê o seu próprio Enabled da config e o
    DispatchToChannels já ignora canais desativados, por isso não há
    necessidade de condicionar o registo aqui (cada canal degrada-se
    sozinho quando o seu próprio USE_LOGGERS_* / plataforma / config não
    está disponível — Http/Email/WebSocket ficam inertes sob FPC, sem os
    respetivos USE_LOGGERS_*, ou sem config mínima). }
  { P0 (auditoria F8, C1): cada canal e registado sob try/except - se o
    LoadConfig/Connect do canal lançar (BD/rede/ficheiro indisponivel), o canal
    fica ausente em vez de derrubar TLoggers.New (o except de DispatchToChannels
    so protege Write, nunca a construcao do canal). }
  try RegisterChannel(TLoggerChannelTextFile.Create);  except on TSysException do ; end;
  try RegisterChannel(TLoggerChannelJson.Create);      except on TSysException do ; end;
  try RegisterChannel(TLoggerChannelDatabase.Create);  except on TSysException do ; end;
  try RegisterChannel(TLoggerChannelEventLog.Create);  except on TSysException do ; end;
  try RegisterChannel(TLoggerChannelCSV.Create);       except on TSysException do ; end;
  try RegisterChannel(TLoggerChannelConsole.Create);   except on TSysException do ; end;
  try RegisterChannel(TLoggerChannelMemory.Create);    except on TSysException do ; end;
{$IF DEFINED(USE_LOGGERS_NET) AND DEFINED(USE_PARAMETERS)}
  ConfigureIcsOpenSslDir;  { aponta o OpenSSL do ICS ao dll\ do projeto ANTES dos canais TLS }
{$IFEND}
  try RegisterChannel(TLoggerChannelHttp.Create);      except on TSysException do ; end;
  try RegisterChannel(TLoggerChannelEmail.Create);     except on TSysException do ; end;
  try RegisterChannel(TLoggerChannelWebSocket.Create); except on TSysException do ; end;
  try RegisterChannel(TLoggerChannelRedis.Create);     except on TSysException do ; end;
  try RegisterChannel(TLoggerChannelElasticSearch.Create); except on TSysException do ; end;
  try RegisterChannel(TLoggerChannelSysLog.Create);    except on TSysException do ; end;

  if FAsync then
  begin
    FWorker := TLoggerWorkerThread.Create(FQueue, DispatchToChannels);
    FWorker.Start;
  end;
end;

destructor TLoggerImpl.Destroy;
begin
  if FWorker <> nil then
  begin
    FQueue.Close;
    FWorker.WaitFor;
    FWorker.Free;
  end;
  FQueue.Free;
  FChannelFails.Free;
  FChannelDisabledAt.Free;
  FChannels.Free;
  FLock.Free;
  inherited;
end;

{$IFDEF USE_PARAMETERS}
procedure TLoggerImpl.BootstrapParameters;
var
  LParams: IParameters;
  LSource: IParametersDatabase;
  LLevelName: string;
  LQueueSize: Integer;

  function ReadCore(const AChave, ADefault: string): string;
  var
    LVal: TParameter;
  begin
    LVal := LSource.Select(AChave);
    try
      if (LVal <> nil) and (LVal.Value <> '') then
        Result := LVal.Value
      else
        Result := ADefault;
    finally
      LVal.Free;
    end;
  end;

begin
  { P0 (auditoria F8, C1+A7): o seed e a leitura de config tocam a BD; se a BD
    estiver indisponivel/corrompida, ou houver race de seed cross-process, NADA
    disto pode derrubar TLoggers.New - degrada para os defaults ja postos no
    construtor. LQueueSize e resolvido ANTES do FQueue.Free, logo o estado fica
    sempre consistente mesmo que a leitura lance a meio. }
  try
    { Seed idempotente (partilhado com Loggers.Connections.TLoggersConnectionResolver
      - só insere as chaves que faltarem, granularidade por chave individual,
      nunca sobrescreve valor já customizado). }
    TLoggersConnectionResolver.EnsureParametersSeeded;

    LParams := TParameters.New;
    { Lê a config do núcleo (titulo 'Loggers') após o seed. }
    LSource := LParams.Database;
    LSource.Title(LOGGERS_TITULO_CORE);
    LLevelName := ReadCore(LOGGERS_DEFAULT_LEVEL, DEFAULT_LOGGERS_DEFAULT_LEVEL);
    FMinLevel := StrToLogLevel(LLevelName, llInfo);  { SSOT partilhada com o canal Email (onda 8.4.4) - ver Commons.Loggers.Types.pas 1.4.0. }
    FAsync := SameText(ReadCore(LOGGERS_ASYNC, DEFAULT_LOGGERS_ASYNC), 'True');
    FFailoverEnabled := SameText(ReadCore(LOGGERS_FAILOVER_ENABLED, DEFAULT_LOGGERS_FAILOVER_ENABLED), 'True');
    FMaxFails := StrToIntDef(ReadCore(LOGGERS_MAX_FAILS_BEFORE_DISABLE, DEFAULT_LOGGERS_MAX_FAILS), 5);
    FFlushIntervalMs := StrToIntDef(ReadCore(LOGGERS_FLUSH_INTERVAL_MS, DEFAULT_LOGGERS_FLUSH_INTERVAL_MS), 500);
    FRecoveryMs := StrToIntDef(ReadCore(LOGGERS_CHANNEL_RECOVERY_MS, DEFAULT_LOGGERS_CHANNEL_RECOVERY_MS), 30000);
    LQueueSize := StrToIntDef(ReadCore(LOGGERS_QUEUE_MAX_SIZE, DEFAULT_LOGGERS_QUEUE_MAX_SIZE), 10000);
    FQueue.Free;
    FQueue := TLoggerQueue.Create(LQueueSize);
  except
    on TSysException do  { BD indisponivel / race de seed: mantem os defaults do construtor - logging degrada, app arranca. }
      ;
  end;
end;
{$ELSE}
procedure TLoggerImpl.BootstrapParameters;
begin
  { USE_PARAMETERS OFF: sem fonte de config, fica nos defaults do construtor. }
end;
{$ENDIF}

{$IF DEFINED(USE_LOGGERS_NET) AND DEFINED(USE_PARAMETERS)}
procedure TLoggerImpl.ConfigureIcsOpenSslDir;
var
  LData: TConnectionData;
  LDir: string;
begin
  { Aponta o loader de OpenSSL do ICS (GSSL_DLL_DIR) ao dll\<plat>\ do projeto,
    reusando o DllBasePath do perfil 'loggers' (o mesmo que o canal Database
    resolve) + o SSOT Commons.DynamicLibrary. Evita o cache buggy do ICS em
    C:\ProgramData\ICS-OpenSSL\<ver>. CLAUSULA DE COMPATIBILIDADE: so' redireciona
    se o OpenSSL estiver mesmo no dll\<plat>\ do projeto - senao PRESERVA o
    comportamento anterior (o default do ICS / um override externo ja' definido).
    Mudanca ADITIVA (metodo novo gated) - nao renomeia nem remove nada. }
  try
    if not TLoggersConnectionResolver.ResolveConnectionData(LData) then
      LData.DllBasePath := '';
    LDir := ResolveDllBasePath(LData.DllBasePath, ExtractFilePath(ParamStr(0)))
            + DLL_PLATFORM_SUBDIR + PathDelim;
    if FileExists(LDir + 'libcrypto-4.dll') then  { compat: so' redireciona se o OpenSSL 4.0 estiver no dll\ do projeto }
    begin
      GSSL_DLL_DIR := LDir;
      AppendPathEnv(LDir);
    end;
  except
    on TSysException do ;  { OpenSSL/config indisponivel: canais TLS degradam-se sozinhos. }
  end;
end;
{$IFEND}

procedure TLoggerImpl.DispatchToChannels(const AEntry: TLoggerEntry);
var
  I: Integer;
  LChannels: TArray<ILoggerChannel>;
  LChannel: ILoggerChannel;
  LOk: Boolean;
  LFails: Integer;
  LNow, LDisabledAt: UInt32;
begin
  { C1 (auditoria F8): snapshot dos canais sob lock BREVE; o Write() de cada
    canal (que pode fazer I/O de rede/BD potencialmente lento) corre FORA da
    seccao critica - senao o FLock ficaria preso durante o I/O e qualquer thread
    em DoLog (que so precisa do contador) bloquearia, anulando o modo assincrono.
    Padrao copy-under-lock identico ao PoolConnections.HousekeepingTick. }
  FLock.Acquire;
  try
    LChannels := FChannels.ToArray;
  finally
    FLock.Release;
  end;

  LNow := GetTickCount;
  for I := 0 to High(LChannels) do
  begin
    LChannel := LChannels[I];
    if LChannel = nil then
      Continue;

    if not LChannel.Enabled then
    begin
      { C2 (auditoria F8): canal auto-desativado tenta recuperar apos o cooldown
        FRecoveryMs - senao ficaria morto para sempre apos um blip transitorio. }
      if (not FFailoverEnabled) or (FRecoveryMs <= 0) then
        Continue;
      FLock.Acquire;
      try
        if not FChannelDisabledAt.TryGetValue(LChannel.Name, LDisabledAt) then
          LDisabledAt := 0;
      finally
        FLock.Release;
      end;
      if (LDisabledAt = 0) or ((LNow - LDisabledAt) < UInt32(FRecoveryMs)) then
        Continue;
      LChannel.Enabled(True);  { nova chance; se falhar outra vez, re-desativa abaixo. }
      FLock.Acquire;
      try
        FChannelFails.AddOrSetValue(LChannel.Name, 0);
        FChannelDisabledAt.Remove(LChannel.Name);
      finally
        FLock.Release;
      end;
    end;

    LOk := False;
    try
      LOk := LChannel.Write(AEntry);  { FORA do FLock (C1); cada canal e' thread-safe internamente. }
    except
      on E: TSysException do
      begin
        LOk := False;  { exceção do canal NUNCA propaga - log não pode derrubar a app. }
        {$IFNDEF FPC}{$IFDEF MSWINDOWS}
        { C3 (auditoria F8): superficie de diagnostico minima - sem isto o canal
          falha em silencio ate ao auto-disable, sem pista da causa em producao. }
        OutputDebugString(PChar(Format('[ProvidersORM.Loggers] canal "%s" falhou: %s: %s',
          [LChannel.Name, E.ClassName, E.Message])));
        {$ENDIF}{$ENDIF}
      end;
    end;

    FLock.Acquire;
    try
      if LOk then
      begin
        FChannelFails.AddOrSetValue(LChannel.Name, 0);
        FChannelDisabledAt.Remove(LChannel.Name);
      end
      else if FFailoverEnabled then
      begin
        LFails := 0;
        FChannelFails.TryGetValue(LChannel.Name, LFails);
        Inc(LFails);
        FChannelFails.AddOrSetValue(LChannel.Name, LFails);
        if LFails >= FMaxFails then
        begin
          LChannel.Enabled(False);  { desativa-se sozinho após N falhas consecutivas. }
          FChannelDisabledAt.AddOrSetValue(LChannel.Name, GetTickCount);  { marca p/ recuperacao (C2). }
        end;
      end;
    finally
      FLock.Release;
    end;
  end;

  if Assigned(FOnAfterWrite) then
    try
      FOnAfterWrite(AEntry);
    except
      { 15.3/T10: engolir aqui e deliberado (canal com defeito nao derruba o dispatch),
        mas nao pode ser MUDO - sem rasto o defeito fica invisivel. }
      on E: TSysException do  { alias local da unit (l.171) }
        TraceSwallowed('TLoggerImpl.DispatchToChannels', 'canal com defeito nao derruba o dispatch', E);
    end;
  {$IFDEF FPC}{$IF FPC_FULLVERSION < 30300}InterLockedDecrement{$ELSE}AtomicDecrement{$ENDIF}{$ELSE}AtomicDecrement{$ENDIF}(FPending);  { C1: contador atomico, sem partilhar o FLock com o dispatch. }
end;

procedure TLoggerImpl.DoLog(ALevel: TLogLevel; const AMessage: string; AException: TObject);
var
  LEntry: TLoggerEntry;
  LCancel: Boolean;
begin
  if LOG_LEVEL_SEVERITY[ALevel] < LOG_LEVEL_SEVERITY[FMinLevel] then
    Exit;
  if Assigned(FOnLevelCheck) then
    if not FOnLevelCheck(ALevel) then
      Exit;
  LEntry := Default(TLoggerEntry);
  LEntry.Timestamp := Now;
  LEntry.Level := ALevel;
  LEntry.Message := AMessage;
  LEntry.Category := 'Application';
  if Assigned(AException) and (AException is TSysException) then
  begin
    LEntry.ExceptionClass := AException.ClassName;
    LEntry.ExceptionMessage := TSysException(AException).Message;
  end;
  LCancel := False;
  if Assigned(FOnBeforeWrite) then
    FOnBeforeWrite(LEntry, LCancel);
  if LCancel then
    Exit;
  {$IFDEF FPC}{$IF FPC_FULLVERSION < 30300}InterLockedIncrement{$ELSE}AtomicIncrement{$ENDIF}{$ELSE}AtomicIncrement{$ENDIF}(FPending);  { C1: contador atomico, desacoplado do FLock do dispatch. }
  if FAsync and (FQueue <> nil) then
    FQueue.Push(LEntry)
  else
    DispatchToChannels(LEntry);
end;

function TLoggerImpl.RegisterChannel(const AChannel: ILoggerChannel): ILogger;
begin
  if AChannel <> nil then
  begin
    FLock.Acquire;
    try
      FChannels.Add(AChannel);
    finally
      FLock.Release;
    end;
  end;
  Result := Self;
end;

function TLoggerImpl.MinLevel: TLogLevel;
begin
  Result := FMinLevel;
end;

function TLoggerImpl.MinLevel(const AValue: TLogLevel): ILogger;
begin
  FMinLevel := AValue;
  Result := Self;
end;

procedure TLoggerImpl.Info(const AMessage: string);
begin
  DoLog(llInfo, AMessage, nil);
end;

procedure TLoggerImpl.Info(const AMessage: string; const AData: array of const);
begin
  DoLog(llInfo, Format(AMessage, AData), nil);
end;

procedure TLoggerImpl.Info(const AMessage: string; AException: TObject);
begin
  DoLog(llInfo, AMessage, AException);
end;

procedure TLoggerImpl.Success(const AMessage: string);
begin
  DoLog(llSuccess, AMessage, nil);
end;

procedure TLoggerImpl.Success(const AMessage: string; const AData: array of const);
begin
  DoLog(llSuccess, Format(AMessage, AData), nil);
end;

procedure TLoggerImpl.Success(const AMessage: string; AException: TObject);
begin
  DoLog(llSuccess, AMessage, AException);
end;

procedure TLoggerImpl.Warning(const AMessage: string);
begin
  DoLog(llWarning, AMessage, nil);
end;

procedure TLoggerImpl.Warning(const AMessage: string; const AData: array of const);
begin
  DoLog(llWarning, Format(AMessage, AData), nil);
end;

procedure TLoggerImpl.Warning(const AMessage: string; AException: TObject);
begin
  DoLog(llWarning, AMessage, AException);
end;

procedure TLoggerImpl.Error(const AMessage: string);
begin
  DoLog(llError, AMessage, nil);
end;

procedure TLoggerImpl.Error(const AMessage: string; const AData: array of const);
begin
  DoLog(llError, Format(AMessage, AData), nil);
end;

procedure TLoggerImpl.Error(const AMessage: string; AException: TObject);
begin
  DoLog(llError, AMessage, AException);
end;

procedure TLoggerImpl.Critical(const AMessage: string);
begin
  DoLog(llCritical, AMessage, nil);
end;

procedure TLoggerImpl.Critical(const AMessage: string; const AData: array of const);
begin
  DoLog(llCritical, Format(AMessage, AData), nil);
end;

procedure TLoggerImpl.Critical(const AMessage: string; AException: TObject);
begin
  DoLog(llCritical, AMessage, AException);
end;

procedure TLoggerImpl.Exception(const AMessage: string; E: TObject);
begin
  DoLog(llException, AMessage, E);
end;

procedure TLoggerImpl.Exception(const AMessage: string; const AData: array of const; E: TObject);
begin
  DoLog(llException, Format(AMessage, AData), E);
end;

procedure TLoggerImpl.Debug(const AMessage: string);
begin
  DoLog(llDebug, AMessage, nil);
end;

procedure TLoggerImpl.Debug(const AMessage: string; const AData: array of const);
begin
  DoLog(llDebug, Format(AMessage, AData), nil);
end;

procedure TLoggerImpl.Debug(const AMessage: string; AException: TObject);
begin
  DoLog(llDebug, AMessage, AException);
end;

procedure TLoggerImpl.Trace(const AMessage: string);
begin
  DoLog(llTrace, AMessage, nil);
end;

procedure TLoggerImpl.Trace(const AMessage: string; const AData: array of const);
begin
  DoLog(llTrace, Format(AMessage, AData), nil);
end;

procedure TLoggerImpl.Trace(const AMessage: string; AException: TObject);
begin
  DoLog(llTrace, AMessage, AException);
end;

procedure TLoggerImpl.Done(const AMessage: string);
begin
  DoLog(llDone, AMessage, nil);
end;

procedure TLoggerImpl.Done(const AMessage: string; const AData: array of const);
begin
  DoLog(llDone, Format(AMessage, AData), nil);
end;

procedure TLoggerImpl.Done(const AMessage: string; AException: TObject);
begin
  DoLog(llDone, AMessage, AException);
end;

procedure TLoggerImpl.Log(ALevel: TLogLevel; const AMessage: string);
begin
  DoLog(ALevel, AMessage, nil);
end;

procedure TLoggerImpl.Log(ALevel: TLogLevel; const AMessage: string; const AData: array of const);
begin
  DoLog(ALevel, Format(AMessage, AData), nil);
end;

procedure TLoggerImpl.Log(ALevel: TLogLevel; const AMessage: string; AException: TObject);
begin
  DoLog(ALevel, AMessage, AException);
end;

procedure TLoggerImpl.Flush;
var
  LDeadlineMs: Cardinal;
begin
  if not FAsync then
    Exit;  { caminho síncrono já escreveu tudo antes de devolver o controlo. }
  LDeadlineMs := GetTickCount + 5000;  { limite de segurança: 5s. }
  { FPending e' mantido por AtomicIncrement/Decrement (C1); leitura direta de
    Integer alinhado e' atomica, e o Sleep abaixo obriga a re-leitura do campo. }
  while (FPending > 0) and (GetTickCount < LDeadlineMs) do
    Sleep(2);
end;

function TLoggerImpl.OnBeforeWrite: TLoggerBeforeWriteEvent;
begin
  Result := FOnBeforeWrite;
end;

function TLoggerImpl.OnBeforeWrite(const AValue: TLoggerBeforeWriteEvent): ILogger;
begin
  FOnBeforeWrite := AValue;
  Result := Self;
end;

function TLoggerImpl.OnAfterWrite: TLoggerAfterWriteEvent;
begin
  Result := FOnAfterWrite;
end;

function TLoggerImpl.OnAfterWrite(const AValue: TLoggerAfterWriteEvent): ILogger;
begin
  FOnAfterWrite := AValue;
  Result := Self;
end;

function TLoggerImpl.OnLevelCheck: TLoggerLevelCheckEvent;
begin
  Result := FOnLevelCheck;
end;

function TLoggerImpl.OnLevelCheck(const AValue: TLoggerLevelCheckEvent): ILogger;
begin
  FOnLevelCheck := AValue;
  Result := Self;
end;

class function TLoggers.New: ILogger;
begin
  Result := TLoggerImpl.Create;
end;

{$ENDIF USE_LOGGERS}

end.
