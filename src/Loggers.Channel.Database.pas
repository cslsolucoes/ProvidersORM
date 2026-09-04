{ =============================================================================
  Loggers.Channel.Database - Canal baseline sobre IConnection DIRETA (nunca pool)

  TLoggerChannelDatabase: implementa ILoggerChannel sobre uma IConnection
  PROPRIA do canal (construida uma vez em LoadConfig, mantida aberta durante
  o ciclo de vida da instancia, fechada no Destroy) - mesmo padrao de
  ownership de Parameters.Database.pas (BuildOwnConnection/FConnection), NAO
  IPoolConnections/TPoolBroker. Insere na tabela 'logs' via IQueryBuilder
  (parametrizado, zero SQL manual). Tabela criada/sincronizada via
  ISchemaDefinition+TSynchronize (mecanismo F5, ja validado nos 7 dialetos
  incl. SQL Anywhere - substitui a ideia original do plano de SQL cru por
  engine em Commons.Loggers.SQL.pas, que reproduziria um padrao ja morto no
  proprio Parameters.Database.pas). Retencao (RetentionDays) aplicada apos
  cada insert bem sucedido, por simetria com os canais de ficheiro (onda 8.2).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.10.0
  FileVersion:    1.4.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           22/07/2026

  Changelog (file):
  - 1.4.0 (27/07/2026): F8 Onda 8.9 (hardening pos-auditoria) - D1: Write serializa por FLock (FConnection nao e thread-safe; necessario porque o dispatch do nucleo C1 deixou de segurar um lock global); X3: parentese de comentario fechado. ModuleVersion do modulo 1.9.0->1.10.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.9.0 - F8 Onda 8.4.5 acrescenta o canal TLoggerChannelWebSocket (8o canal baseline, 3o real sobre ICS, resolve P2); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.9.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.8.0 - F8 Onda 8.4.4 acrescenta o canal TLoggerChannelEmail (7o canal baseline, 2o real sobre ICS); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.8.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.7.0 - F8 Onda 8.4.3 acrescenta o canal TLoggerChannelHttp (6o canal baseline, 1o real sobre ICS); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.7.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.6.0 - F8 Onda 8.4.2 acrescenta o canal TLoggerChannelCSV (5o canal baseline); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.6.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.5.0 - F8 Onda 8.4.1 acrescenta o canal TLoggerChannelEventLog (Windows Event Log, 4o canal baseline); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.5.0.
  - 1.3.0 (22/07/2026): Finalização da onda 8.3, item 3a (owner: "resolva todos
    e documente nos planos") - PurgeOldEntries deixa de correr incondicionalmente
    a seguir a TODO Write() bem sucedido (dobrava o trafego de BD por linha de
    log sob volume alto) - novo campo FLastPurgeAt (TDateTime, 0=nunca purgou),
    throttle de 1 hora entre purgas (retencao e' medida em dias, granularidade
    horaria e' mais que suficiente). Preserva o contrato ja testado no smoke
    (1o Write apos a construcao do canal sempre purga, porque FLastPurgeAt
    comeca a 0) - nenhuma alteracao ao smoke_loggers_db.dpr necessaria. Achado
    da auditoria adversarial F8 8.1-8.3, plano de finalização (f8-loggers
    changelog 2.8.7) - bug-699.
  - 1.2.0 (22/07/2026): REMOVIDA dependencia de IPoolConnections/TPoolBroker
    (owner: "o Loggers via consumir sem pool direto o Connections") -
    TLoggerChannelDatabase passa a construir e possuir a sua propria IConnection
    (FConnection), igual ao padrao de ownership ja usado por Parameters.Database.
    pas (BuildOwnConnection: TConnection.New encadeado a partir de
    TConnectionData, .Connect uma vez, mantida aberta ate ao Destroy). Elimina
    de raiz a race condition documentada na auditoria F8 8.1-8.3 sobre o antigo
    var global GPool (check-then-set sem lock, unit-level, partilhado entre
    TODAS as instancias do canal) - sem estado partilhado, nao ha mais nada
    para disputar entre instancias concorrentes de TLoggerChannelDatabase.
    EnsureSchema/PurgeOldEntries/Write deixam de fazer GetFromPool/ReturnToPool
    por chamada - usam directamente FConnection (ja aberta). Precedente: o
    proprio Parameters.Database.pas nunca usou o pool (SQLite/ficheiro proprio
    zero-config) - Loggers.Channel.Database.pas alinha-se ao mesmo padrao do modulo
    irmao em vez de ser o unico canal a depender do broker elastico (que foi
    desenhado para consumo concorrente vindo de MUITOS pontos da app, nao para
    um unico worker thread sequencial de dispatch de logs - onda 8.1). Units
    PoolConnections.Interfaces/PoolConnections removidas do uses; Connections.
    Interfaces/Connections adicionadas. Nenhuma alteracao a Loggers.Connections.
    pas (TLoggersConnectionResolver.ResolveConnectionData ja devolvia um
    TConnectionData puro, reusado tal-e-qual para construir a IConnection
    directa). ModuleVersion 1.3.0->1.4.0 (mudanca de arquitectura, nao so bug
    fix).
  - 1.1.0 (22/07/2026): GAP corrigido (achado por auditoria adversarial F8,
    onda 8.3 - owner pediu paridade com Parameters.Database.pas): LOGGERS_DB_
    AUTO_CREATE_TABLE estava seeded em Commons.Loggers.Consts mas NUNCA lido -
    EnsureSchema (TSynchronize.Sync, introspeccao de metadados) corria sempre
    incondicionalmente na construcao de todo TLoggerChannelDatabase. Novo campo
    FAutoCreateTable lido em LoadConfig; EnsureSchema so corre se True (default
    'True', comportamento previo preservado por omissao) - paridade com o
    padrao FAutoCreateTable/FTableEnsured de Parameters.Database.pas (AutoCreateTable
    honrado, so que aqui a decisao e' tomada uma vez na construcao do canal, nao
    lazy por operacao, porque LoadConfig ja so corre uma vez no Create).
  - 1.0.0 (22/07/2026): criação — FASE 8 Onda 8.3.
  ============================================================================= }

unit Loggers.Channel.Database;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_LOGGERS}

uses
{$IF DEFINED(FPC)}
  SysUtils, Classes, SyncObjs,
{$ELSE}
  System.SysUtils, System.Classes, System.SyncObjs,
{$ENDIF}
  Commons.Loggers.Types,
  Connections.Interfaces,  // IConnection (propria do canal, sem pool)
  Loggers.Interfaces;

type
  TLoggerChannelDatabase = class(TInterfacedObject, ILoggerChannel)
  strict private
    FLock             : TCriticalSection;
    FEnabled          : Boolean;
    FReady            : Boolean;  { False se USE_PARAMETERS/USE_DATABASE em falta OU perfil vazio - canal inerte, Write sempre False. }
    FConnectionProfile: string;   { informativo (nome do perfil 'loggers' resolvido); NAO e' chave de pool - o canal nao usa pool. }
    FTableName        : string;
    FRetentionDays    : Integer;
    FAutoCreateTable  : Boolean;
    FConnection       : IConnection;  { propria do canal (nao pool); construida em LoadConfig, viva ate ao Destroy. }
    FLastPurgeAt      : TDateTime;    { 0 = nunca purgou; throttle de PurgeOldEntries (ver corpo do metodo). }
    procedure LoadConfig;
    procedure EnsureSchema;
    procedure PurgeOldEntries;
  public
    constructor Create;
    destructor Destroy; override;
    function Name: string;
    function Write(const AEntry: TLoggerEntry): Boolean;
    function Enabled: Boolean; overload;
    function Enabled(const AValue: Boolean): ILoggerChannel; overload;
    function IsHealthy: Boolean;
  end;

{$ENDIF USE_LOGGERS}

implementation

{$IFDEF USE_LOGGERS}

{$IF DEFINED(USE_PARAMETERS) AND DEFINED(USE_DATABASE)}
  {$DEFINE LOGGERS_DB_CHANNEL_ACTIVE}
{$ENDIF}

uses
{$IFDEF LOGGERS_DB_CHANNEL_ACTIVE}
  Commons.Types,              // TConnectionData
  Commons.Database.Types,     // TSQLColumnKind (ck*)
  Commons.Loggers.Consts,
  Connections,                // TConnection.New (conexao propria, direta - nao pool)
  Databases.Interfaces,       // ISchemaDefinition/ISchemaTable
  Database.Synchronize,       // TSchemaDefinition, TSynchronize
  Database.QueryBuilder,      // TQueryBuilder
  Parameters.Interfaces,      // IParameters/IParametersDatabase
  Parameters,                 // TParameters.New
  Loggers.Connections,        // TLoggersConnectionResolver
{$ENDIF}
  Loggers.Version;            // (mantem a unit no uses mesmo sem LOGGERS_DB_CHANNEL_ACTIVE, evita warning de uses vazio)

constructor TLoggerChannelDatabase.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FEnabled := False;
  FReady := False;
  FTableName := 'logs';
  FLastPurgeAt := 0;
  LoadConfig;
end;

destructor TLoggerChannelDatabase.Destroy;
begin
{$IFDEF LOGGERS_DB_CHANNEL_ACTIVE}
  if (FConnection <> nil) and FConnection.IsConnected then
    FConnection.Disconnect;
  FConnection := nil;
{$ENDIF}
  FLock.Free;
  inherited;
end;

function TLoggerChannelDatabase.Name: string;
begin
  Result := 'Database';
end;

function TLoggerChannelDatabase.Enabled: Boolean;
begin
  FLock.Acquire;
  try
    Result := FEnabled and FReady;
  finally
    FLock.Release;
  end;
end;

function TLoggerChannelDatabase.Enabled(const AValue: Boolean): ILoggerChannel;
begin
  FLock.Acquire;
  try
    FEnabled := AValue;
  finally
    FLock.Release;
  end;
  Result := Self;
end;

function TLoggerChannelDatabase.IsHealthy: Boolean;
begin
  Result := Enabled;
end;

{$IFDEF LOGGERS_DB_CHANNEL_ACTIVE}

procedure TLoggerChannelDatabase.LoadConfig;
var
  LParams: IParameters;
  LSource: IParametersDatabase;
  LData: TConnectionData;

  function Read(const AChave, ADefault: string): string;
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
  LParams := TParameters.New;
  LSource := LParams.Database;
  LSource.AutoCreateTable(True);
  LSource.EnsureTable;
  LSource.Title(LOGGERS_TITULO_DATABASE);

  FEnabled := SameText(Read(LOGGERS_DB_ENABLED, DEFAULT_LOGGERS_DB_ENABLED), 'True');
  FConnectionProfile := Read(LOGGERS_DB_CONNECTION_PROFILE, DEFAULT_LOGGERS_PROFILE);
  FTableName := Read(LOGGERS_DB_TABLE_NAME, DEFAULT_LOGGERS_DB_TABLE);
  FRetentionDays := StrToIntDef(Read(LOGGERS_DB_RETENTION_DAYS, DEFAULT_LOGGERS_DB_RETENTION), 90);
  FAutoCreateTable := SameText(Read(LOGGERS_DB_AUTO_CREATE_TABLE, DEFAULT_LOGGERS_DB_AUTO_CREATE), 'True');

  if not FEnabled then
    Exit;

  if not TLoggersConnectionResolver.ResolveConnectionData(LData) then
  begin
    FEnabled := False;
    Exit;
  end;
  FConnection := TConnection.New
    .Engine(LData.Engine)
    .DatabaseType(LData.DatabaseType)
    .Host(LData.Host).Port(LData.Port)
    .Username(LData.Username).Password(LData.Password)
    .Database(LData.Database).Schema(LData.Schema)
    .ServerName(LData.ServerName)
    .DllBasePath(LData.DllBasePath)
    .DllDownloadUrl(LData.DllDownloadUrl)
    .AutoDownloadDlls(True)
    .Connect;

  FReady := True;
  { AutoCreateTable=False (paridade Parameters.Database.pas): a tabela e' gerida
    fora (DBA/migracao externa) - nao correr TSynchronize.Sync (introspeccao +
    possivel ALTER) a cada construcao do canal; so grava, assume que ja existe. }
  if FAutoCreateTable then
    EnsureSchema;
end;

procedure TLoggerChannelDatabase.EnsureSchema;
var
  LDef: ISchemaDefinition;
begin
  LDef := TSchemaDefinition.New;
  LDef.Table(FTableName)
    .AddColumn('log_id',              ckIdentity, 0,   False, True)
    .AddColumn('created_at',          ckDateTime, 0,   False)
    .AddColumn('level',               ckVarChar,  20,  False)
    .AddColumn('message',             ckText,     0,   True)
    .AddColumn('category',            ckVarChar,  255, True)
    .AddColumn('app_name',            ckVarChar,  255, True)
    .AddColumn('host',                ckVarChar,  255, True)
    .AddColumn('thread_id',           ckInteger,  0,   True)
    .AddColumn('user_name',           ckVarChar,  255, True)
    .AddColumn('exception_class',     ckVarChar,  255, True)
    .AddColumn('exception_message',   ckText,     0,   True)
    .AddColumn('stack_trace',         ckText,     0,   True)
    .AddColumn('tag',                 ckVarChar,  255, True)
    .AddIndex(['created_at'], 'idx_' + FTableName + '_created_at');
  TSynchronize.New(FConnection).Sync(LDef);
end;

procedure TLoggerChannelDatabase.PurgeOldEntries;
const
  { Throttle: um DELETE por CADA Write() (o comportamento original) dobra o
    trafego de BD sob volume alto de log. Retencao e' medida em DIAS - verificar
    de hora a hora e' mais que suficiente granularidade. Sempre corre no 1o
    Write apos a construcao do canal (FLastPurgeAt=0), preservando o contrato
    ja validado pelo smoke (1 Write dispara a purga, sem esperar N escritas). }
  PURGE_THROTTLE_HOURS = 1;
var
  LCutoff: TDateTime;
begin
  if FRetentionDays <= 0 then
    Exit;
  if (FLastPurgeAt <> 0) and (Now - FLastPurgeAt < (PURGE_THROTTLE_HOURS / 24)) then
    Exit;
  LCutoff := Now - FRetentionDays;
  TQueryBuilder.New.Connection(FConnection)
    .DeleteFrom(FTableName)
    .Where('created_at', '<', LCutoff)
    .ExecuteMutation;
  FLastPurgeAt := Now;
end;

function TLoggerChannelDatabase.Write(const AEntry: TLoggerEntry): Boolean;
begin
  Result := False;
  if not (FReady and FEnabled) then
    Exit;
  { D1 (auditoria F8): FConnection (TZQuery/TFDQuery/TUniQuery/...) NAO e'
    thread-safe; serializa Write+Purge desta instancia. Necessario porque o
    dispatch do nucleo (C1) deixou de segurar um lock global durante o Write -
    no modo sincrono, duas threads da app podem entrar aqui em simultaneo. }
  FLock.Acquire;
  try
    try
      TQueryBuilder.New.Connection(FConnection)
        .InsertInto(FTableName)
        .Value('created_at',        AEntry.Timestamp)
        .Value('level',             LogLevelToStr(AEntry.Level))
        .Value('message',           AEntry.Message)
        .Value('category',          AEntry.Category)
        .Value('app_name',          AEntry.AppName)
        .Value('host',              AEntry.Host)
        .Value('thread_id',         AEntry.ThreadId)
        .Value('user_name',         AEntry.UserName)
        .Value('exception_class',   AEntry.ExceptionClass)
        .Value('exception_message', AEntry.ExceptionMessage)
        .Value('stack_trace',       AEntry.StackTrace)
        .Value('tag',               AEntry.Tag)
        .ExecuteMutation;
      PurgeOldEntries;
      Result := True;
    except
      Result := False;  { canal nunca propaga - fail-over do TLoggerImpl decide o resto. }
    end;
  finally
    FLock.Release;
  end;
end;

{$ELSE}

procedure TLoggerChannelDatabase.LoadConfig;
begin
  { USE_PARAMETERS/USE_DATABASE em falta - canal permanece inerte. }
  FEnabled := False;
  FReady := False;
end;

procedure TLoggerChannelDatabase.EnsureSchema;
begin
end;

procedure TLoggerChannelDatabase.PurgeOldEntries;
begin
end;

function TLoggerChannelDatabase.Write(const AEntry: TLoggerEntry): Boolean;
begin
  Result := False;
end;

{$ENDIF LOGGERS_DB_CHANNEL_ACTIVE}

{$ENDIF USE_LOGGERS}

end.
