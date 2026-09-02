{ =============================================================================
  Loggers.Channel.Redis - Canal Redis (PUBLISH/LPUSH, Delphi-only, via ICS)

  TLoggerChannelRedis: implementa ILoggerChannel enviando cada entrada de log
  para um servidor Redis-compativel (ex.: Memurai) via protocolo RESP (RESP2)
  sobre TCP cru, usando o motor unico ICS (OverbyteIcsWSocket.TWSocket).
  TWSocket e' um componente de baixo nivel, ASSINCRONO por mensagens do
  Windows (mesmo achado ja documentado nos canais Http/Email/WebSocket desta
  fase) - ao contrario do THttpCli/TSslSmtpCli usados por esses 2 primeiros
  canais (que ja' embutem um metodo sincrono pronto, Post/OpenSync), o
  TWSocket NAO tem um "PublishSync" - e' preciso bombear mensagens a mao.
  Aqui NAO se justifica um TWSocketServer/thread dedicado (como o canal
  WebSocket, que hospeda um SERVIDOR persistente): o canal Redis e' cliente
  pedido-resposta pontual, como o Http/Email - por isso reusa o MESMO padrao
  "cliente ICS fresco por tentativa", com o loop de bombeamento
  (TWSocket.ProcessMessage + Sleep curto quando nao ha mensagem, cada
  operacao com o seu proprio deadline) JA' validado neste projecto por
  test_websocket.dpr (TWSTestClientICS.Pump/WaitConnected, Vaga 3 F8) - o
  mesmo padrao e' aplicado aqui do lado do canal de PRODUCAO, nao apenas de
  um teste.

  Protocolo: RESP (RESP2) - AUTH (se Password<>'') + SELECT (se DbIndex<>0) +
  PUBLISH <ChannelOrKey> <json> (Mode=Publish, fire-and-forget) ou LPUSH
  <ChannelOrKey> <json> (Mode=List, persiste na lista) - tudo na MESMA ligacao
  TCP, sequencial. Payload = Commons.Loggers.Types.LoggerEntryToJSON (mesma
  SSOT do canal Http/Json - nao duplica serializacao). Sem TLS nesta 1a
  versao (so' TCP simples - AUTH em texto claro, adequado a uma rede de
  confianca/VPN; ver plano F8 Redis §4 sobre seguranca do servidor Memurai).

  Desenho: .workspace/plans/providersorm-v3-f8-loggers-redis-memurai-setup_v1.0.md
  §6 (owner, 31/07/2026).

  Absorção: SEM equivalente direto no LoggersORM v2.3.0 nem no QuickLogger
  (nenhum dos dois tem provider Redis) - canal novo do v3, desenhado de raiz
  seguindo o padrao SSOT ja estabelecido pelos canais de rede ICS existentes
  (Http/Email/WebSocket).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.13.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           31/07/2026

  Changelog (file):
  - 1.0.0 (31/07/2026): criacao - FASE 8 Onda 8.15 (canal Redis, 11o canal
    baseline, 4o canal REAL sobre ICS). RESP2 sobre TWSocket (TCP cru) em modo
    sincrono por-tentativa (TWSocket.ProcessMessage bombeado em ciclo com
    deadline por operacao - mesmo padrao ja validado por test_websocket.dpr/
    TWSTestClientICS). Modes Publish (PUBLISH) e List (LPUSH). TLS fora do
    escopo desta 1a versao.
  ============================================================================= }

unit Loggers.Channel.Redis;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../ORM.Defines.inc}

{$IF DEFINED(USE_LOGGERS_REDIS) AND DEFINED(USE_PARAMETERS) AND DEFINED(MSWINDOWS)}
  {$DEFINE LOGGERS_REDIS_CHANNEL_ACTIVE}
{$ENDIF}

{$IFDEF USE_LOGGERS}

uses
{$IF DEFINED(FPC)}
  SysUtils, Classes, SyncObjs,
{$ELSE}
  System.SysUtils, System.Classes, System.SyncObjs,
{$ENDIF}
  Commons.Loggers.Types,
  Loggers.Interfaces;

type
  TLoggerChannelRedis = class(TInterfacedObject, ILoggerChannel)
  strict private
    FLock        : TCriticalSection;
    FEnabled     : Boolean;
    FReady       : Boolean;  { False se Host vazio OU ICS indisponivel (FPC) OU USE_LOGGERS_REDIS/USE_PARAMETERS em falta. }
    FHost        : string;
    FPort        : Integer;
    FPassword    : string;
    FDbIndex     : Integer;
    FMode        : string;   { 'Publish' (PUBLISH) ou 'List' (LPUSH) - ver LoadConfig. }
    FChannelOrKey: string;
    FTimeoutSec  : Integer;
    procedure LoadConfig;
{$IFDEF LOGGERS_REDIS_CHANNEL_ACTIVE}
    function AttemptSend(const AJsonBody: string): Boolean;
{$ENDIF}
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

uses
{$IFDEF LOGGERS_REDIS_CHANNEL_ACTIVE}
  {$IF DEFINED(FPC)}
  Windows,
  {$ELSE}
  Winapi.Windows,
  {$ENDIF}
  OverbyteIcsWSocket,          // TWSocket - motor unico ICS (cliente RESP sincrono por-tentativa)
  Commons.Types,                // TParameter
  Commons.Loggers.Consts,
  Parameters.Interfaces,
  Parameters,
{$ENDIF}
  Loggers.Version;  { mantem a unit no uses mesmo sem LOGGERS_REDIS_CHANNEL_ACTIVE, evita warning de uses vazio. }

constructor TLoggerChannelRedis.Create;
begin
  inherited Create;
{$IFDEF FPC}
  FLock := SyncObjs.TCriticalSection.Create;  { Windows.pp do FPC declara TCriticalSection (record WinAPI) que sombreia a classe SyncObjs quando Windows entra em scope na implementation - bug-659, mesmo fix do canal EventLog. }
{$ELSE}
  FLock := TCriticalSection.Create;
{$ENDIF}
  FEnabled := False;
  FReady := False;
  LoadConfig;
end;

destructor TLoggerChannelRedis.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TLoggerChannelRedis.Name: string;
begin
  Result := 'Redis';
end;

function TLoggerChannelRedis.Enabled: Boolean;
begin
  FLock.Acquire;
  try
    Result := FEnabled and FReady;
  finally
    FLock.Release;
  end;
end;

function TLoggerChannelRedis.Enabled(const AValue: Boolean): ILoggerChannel;
begin
  FLock.Acquire;
  try
    FEnabled := AValue;
  finally
    FLock.Release;
  end;
  Result := Self;
end;

function TLoggerChannelRedis.IsHealthy: Boolean;
begin
  Result := Enabled;
end;

{$IFDEF LOGGERS_REDIS_CHANNEL_ACTIVE}

procedure TLoggerChannelRedis.LoadConfig;
var
  LParams: IParameters;
  LSource: IParametersDatabase;

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
  LSource.EnsureTable;  { idempotente - garante a tabela mesmo se este canal for criado antes do bootstrap do nucleo. }
  LSource.Title(LOGGERS_TITULO_REDIS);

  FEnabled := SameText(Read(LOGGERS_REDIS_ENABLED, DEFAULT_LOGGERS_REDIS_ENABLED), 'True');
  FHost := Read(LOGGERS_REDIS_HOST, DEFAULT_LOGGERS_REDIS_HOST);
  FPort := StrToIntDef(Read(LOGGERS_REDIS_PORT, DEFAULT_LOGGERS_REDIS_PORT), 6379);
  FPassword := Read(LOGGERS_REDIS_PASSWORD, DEFAULT_LOGGERS_REDIS_PASSWORD);
  FDbIndex := StrToIntDef(Read(LOGGERS_REDIS_DB_INDEX, DEFAULT_LOGGERS_REDIS_DB_INDEX), 0);
  FMode := Read(LOGGERS_REDIS_MODE, DEFAULT_LOGGERS_REDIS_MODE);
  FChannelOrKey := Read(LOGGERS_REDIS_CHANNEL_OR_KEY, DEFAULT_LOGGERS_REDIS_CHANNEL_OR_KEY);
  FTimeoutSec := StrToIntDef(Read(LOGGERS_REDIS_TIMEOUT_SEC, DEFAULT_LOGGERS_REDIS_TIMEOUT_SEC), 30);
  if FTimeoutSec <= 0 then
    FTimeoutSec := 30;

  FReady := (FHost <> '');  { canal inerte ate ter um host configurado, independente de Enabled. }
end;

{ Constroi um comando RESP (RESP2) tipo array-de-bulk-strings - forma padrao
  usada por QUALQUER comando de um cliente Redis (AUTH/SELECT/PUBLISH/LPUSH):
  "*N\r\n$len1\r\narg1\r\n...$lenN\r\nargN\r\n". O prefixo $<len> tem de ser o
  tamanho em BYTES UTF-8 do argumento (nao Length() da string Pascal, que e'
  UTF-16) - decisivo para entradas de log com acentuacao (pt-BR/pt-PT). A
  concatenacao de segmentos UTF-8 e' equivalente a' codificacao UTF-8 do todo
  (mesma tecnica ja usada pelo canal WebSocket em BuildWebSocketTextFrame),
  por isso codifica-se o comando inteiro de uma vez no fim. }
function BuildRespCommand(const AArgs: array of string): TBytes;
var
  I: Integer;
  LCmd: string;
begin
  LCmd := '*' + IntToStr(Length(AArgs)) + #13#10;
  for I := 0 to High(AArgs) do
    LCmd := LCmd + '$' + IntToStr(Length(TEncoding.UTF8.GetBytes(AArgs[I]))) + #13#10 + AArgs[I] + #13#10;
  Result := TEncoding.UTF8.GetBytes(LCmd);
end;

type
  { Cliente RESP sincrono sobre TWSocket (ICS) - 1 instancia fresca por
    tentativa de Write (mesmo padrao "cliente fresco por tentativa" dos
    canais Http/Email, sem ligacao persistente entre entradas). TWSocket e'
    assincrono por mensagens do Windows - os 3 handlers (SessionConnected/
    DataAvailable/SessionClosed) so' marcam flags/acumulam bytes; quem avanca
    o protocolo e' esta classe, bombeando mensagens (Pump) em ciclo com
    deadline, ate' cada flag ficar True ou o TimeoutSec configurado esgotar -
    o MESMO padrao ja' validado neste projecto por test_websocket.dpr
    (TWSTestClientICS, Vaga 3 F8), aqui replicado do lado do canal de
    PRODUCAO. OnDataAvailable drena em CICLO (repeat ReceiveStrA until vazio)
    - mesmo cuidado obrigatorio documentado nos gotchas ICS do canal WebSocket
    (notificacao WM_ASYNC_SELECT e' edge-triggered, 1 unico ReceiveStrA por
    evento arrisca perder o resto de uma resposta fatiada por mais de 1
    segmento TCP). }
  TRedisRespClient = class
  strict private
    FSocket   : TWSocket;
    FTimeoutSec: Integer;
    FConnDone : Boolean;
    FConnOk   : Boolean;
    FClosed   : Boolean;
    FRecvBuf  : AnsiString;
    procedure DoSessionConnected(Sender: TObject; ErrCode: Word);
    procedure DoDataAvailable(Sender: TObject; ErrCode: Word);
    procedure DoSessionClosed(Sender: TObject; ErrCode: Word);
    procedure Pump;
  public
    constructor Create(ATimeoutSec: Integer);
    destructor Destroy; override;
    function Connect(const AHost: string; APort: Integer): Boolean;
    { Envia UM comando RESP e le' a linha de resposta simples (+OK/-ERR/:N).
      Aceita qualquer resposta que NAO comece por '-' (erro RESP) como
      sucesso - cobre tanto +OK (AUTH/SELECT) como :N (PUBLISH devolve o nº
      de subscritores, LPUSH devolve o novo tamanho da lista - nenhum dos 2
      valores exatos interessa ao contrato Write:Boolean deste canal). }
    function SendAndCheck(const AArgs: array of string): Boolean;
  end;

constructor TRedisRespClient.Create(ATimeoutSec: Integer);
begin
  inherited Create;
  FTimeoutSec := ATimeoutSec;
  if FTimeoutSec <= 0 then
    FTimeoutSec := 30;
  FConnDone := False;
  FConnOk := False;
  FClosed := False;
  FRecvBuf := '';
  FSocket := TWSocket.Create(nil);
  FSocket.OnSessionConnected := DoSessionConnected;
  FSocket.OnDataAvailable := DoDataAvailable;
  FSocket.OnSessionClosed := DoSessionClosed;
end;

destructor TRedisRespClient.Destroy;
begin
  try
    FSocket.Close;
  except
    { nunca propaga a partir do destructor. }
  end;
  FSocket.Free;
  inherited;
end;

procedure TRedisRespClient.DoSessionConnected(Sender: TObject; ErrCode: Word);
begin
  FConnDone := True;
  FConnOk := (ErrCode = 0);
end;

procedure TRedisRespClient.DoDataAvailable(Sender: TObject; ErrCode: Word);
var
  LChunk: AnsiString;
begin
  if ErrCode <> 0 then
    Exit;
  repeat
    LChunk := FSocket.ReceiveStrA;
    if LChunk = '' then
      Break;
    FRecvBuf := FRecvBuf + LChunk;
  until False;
end;

procedure TRedisRespClient.DoSessionClosed(Sender: TObject; ErrCode: Word);
begin
  FClosed := True;
end;

{ 1 "passo" nao-bloqueante do pump (TWSocket e' assincrono por mensagens do
  Windows - sem isto Connect/Send/dados nunca progridem); o chamador decide o
  deadline por operacao. Sleep curto quando nao ha mensagem pendente evita
  busy-spin - mesmo padrao de test_websocket.dpr/TWSTestClientICS.Pump. }
procedure TRedisRespClient.Pump;
begin
  if not FSocket.ProcessMessage then
    Sleep(5);
end;

function TRedisRespClient.Connect(const AHost: string; APort: Integer): Boolean;
var
  LDeadline: Cardinal;
begin
  FSocket.Addr := AHost;
  FSocket.Port := IntToStr(APort);
  try
    FSocket.Connect;
  except
    Exit(False);  { host/porta invalidos ou erro sincrono imediato. }
  end;
  LDeadline := GetTickCount + Cardinal(FTimeoutSec) * 1000;
  while (not FConnDone) and (not FClosed) and (GetTickCount < LDeadline) do
    Pump;
  Result := FConnDone and FConnOk and (not FClosed);
end;

function TRedisRespClient.SendAndCheck(const AArgs: array of string): Boolean;
var
  LBytes: TBytes;
  LDeadline: Cardinal;
  LPos: Integer;
  LLine: AnsiString;
begin
  Result := False;
  if FClosed then
    Exit;
  LBytes := BuildRespCommand(AArgs);
  if Length(LBytes) = 0 then
    Exit;
  try
    if FSocket.Send(Pointer(LBytes), Length(LBytes)) < 0 then
      Exit(False);
  except
    Exit(False);
  end;

  LDeadline := GetTickCount + Cardinal(FTimeoutSec) * 1000;
  while (Pos(AnsiString(#13#10), FRecvBuf) = 0) and (not FClosed) and (GetTickCount < LDeadline) do
    Pump;

  LPos := Pos(AnsiString(#13#10), FRecvBuf);
  if LPos = 0 then
    Exit(False);  { timeout/desconexao antes de qualquer resposta. }

  LLine := Copy(FRecvBuf, 1, LPos - 1);
  Delete(FRecvBuf, 1, LPos + 1);  { consome so' esta linha - sobra fica para a proxima (defensivo, nao ha pipelining aqui). }
  Result := (LLine <> '') and (Copy(LLine, 1, 1) <> '-');  { '-' = erro RESP (-ERR/-WRONGPASS/-NOAUTH/...). }
end;

function TLoggerChannelRedis.AttemptSend(const AJsonBody: string): Boolean;
var
  LClient: TRedisRespClient;
begin
  Result := False;
  LClient := TRedisRespClient.Create(FTimeoutSec);
  try
    try
      if not LClient.Connect(FHost, FPort) then
        Exit(False);
      if (FPassword <> '') and not LClient.SendAndCheck(['AUTH', FPassword]) then
        Exit(False);
      if (FDbIndex <> 0) and not LClient.SendAndCheck(['SELECT', IntToStr(FDbIndex)]) then
        Exit(False);
      if SameText(FMode, 'List') then
        Result := LClient.SendAndCheck(['LPUSH', FChannelOrKey, AJsonBody])
      else
        Result := LClient.SendAndCheck(['PUBLISH', FChannelOrKey, AJsonBody]);
    except
      Result := False;  { erro de rede/protocolo - nunca propaga, elegivel ao fail-over do nucleo. }
    end;
  finally
    LClient.Free;
  end;
end;

{$ELSE}

procedure TLoggerChannelRedis.LoadConfig;
begin
  { USE_LOGGERS_REDIS/USE_PARAMETERS em falta, OU fora do Windows/FPC (ICS
    Delphi-only nesta build, bug-712) - canal permanece inerte. }
  FEnabled := False;
  FReady := False;
end;

{$ENDIF LOGGERS_REDIS_CHANNEL_ACTIVE}

function TLoggerChannelRedis.Write(const AEntry: TLoggerEntry): Boolean;
{$IFDEF LOGGERS_REDIS_CHANNEL_ACTIVE}
var
  LJsonBody: string;
{$ENDIF}
begin
  Result := False;
  if not (FReady and FEnabled) then
    Exit;
{$IFDEF LOGGERS_REDIS_CHANNEL_ACTIVE}
  try
    LJsonBody := LoggerEntryToJSON(AEntry);
    Result := AttemptSend(LJsonBody);
  except
    Result := False;
  end;
{$ENDIF}
end;

{$ENDIF USE_LOGGERS}

end.
