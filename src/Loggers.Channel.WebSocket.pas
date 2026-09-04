{ =============================================================================
  Loggers.Channel.WebSocket - Canal WebSocket broadcast-only (Delphi-only, via ICS)

  TLoggerChannelWebSocket: implementa ILoggerChannel mantendo um servidor
  WebSocket (RFC6455) que faz broadcast de cada entrada (JSON) a todos os
  clientes ligados — ex.: um dashboard de logs em tempo real que abre
  `new WebSocket('ws://host:porta')` no browser. Resolve a pendência P2
  ("WebSocket é requisito real?" — owner: "mesma resposta anterior").

  Diferente dos canais Http/Email (pedido-resposta, cliente fresco por
  tentativa), este canal é um SERVIDOR persistente. O ICS (`TWSocketServer`)
  é fundamentalmente ASSÍNCRONO por mensagens do Windows (janela oculta +
  GetMessage/DispatchMessage) — sem um message loop a correr continuamente,
  o servidor nunca aceita ligações nem processa dados (achado real desta
  onda: uma 1ª versão sem thread próprio ficava pendurado indefinidamente no
  handshake do 1º cliente de teste). Por isso o servidor corre inteiramente
  dentro de `TLoggerWSServerThread` (cria o `TWSocketServer` no `Execute`,
  chama `Listen` e depois `MessageLoop` — bloqueia ali, a processar mensagens,
  até `PostQuitMessage`). `Write` nunca toca os sockets diretamente (thread
  errada) — só enfileira o frame (`EnqueueBroadcast`, protegido por lock) e
  acorda o loop via `PostMessage`; o envio real aos clientes corre dentro do
  `WndProc` do servidor, já na thread certa. `Destroy` pede a paragem do
  loop e espera a thread terminar.

  Absorção de lógica/semântica do LoggersORM v2.3.0
  (Loggers.Channel.WebSocket.pas + Loggers.Engines.WebSocket.Indy.pas — o "órfão" sem
  Factory/Interfaces, mas com a ÚNICA lógica real do módulo), NÃO cópia de
  ficheiros: o handshake RFC6455 (SHA1+Base64) e a construção do frame de
  texto são absorvidos fielmente (lógica já simples e correta, sem motivo
  para reescrever) — só o motor de transporte muda, de Indy
  (`TIdTCPServer`) para ICS (`TWSocketServer`/`TWSocketClient`), único
  engine de rede do projeto v3.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.10.0
  FileVersion:    1.5.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           24/07/2026

  Changelog (file):
  - 1.5.0 (30/08/2026): bug-760 RESOLVIDO na raiz (investigacao funda de 30/08).
    A race residual (~1 em 10) NAO era, como se documentou em 24/07, uma race
    dentro do dispatch de accept/FD_ACCEPT do TWSocketServer (vendor) - era
    aplicacional, nesta unit: TriggerDataAvailable devolvia sempre FALSE
    (`inherited` = Assigned(FOnDataAvailable), e o canal nunca atribui
    OnDataAvailable). Com False, o TCustomWSocket.ASyncReceive executa o ramo
    "Nothing wants to receive, we will receive and throw away" e faz DoRecv()
    para um TrashCan, ENGOLINDO em silencio os bytes do pedido HTTP Upgrade que
    cheguem entre o ultimo ReceiveStrA do handler e esse DoRecv - o handshake
    fica incompleto para sempre. Fix: devolver True enquanto o handshake corre
    (mantendo False depois dele, de proposito - ver comentario no codigo).
  - 1.4.0 (27/07/2026): F8 Onda 8.9 (hardening pos-auditoria) - N3: Broadcast/AttemptBroadcast/Write passam a Boolean e reportam falha real do servidor morto (fail-over do nucleo deixa de o dar por saudavel para sempre); N4: TryCompleteHandshake protegido por try/except (um cliente a desligar a meio ja nao termina o servidor); N5: fila de broadcast FPending com teto anti-crescimento. ModuleVersion do modulo 1.9.0->1.10.0.
  - 1.3.0 (24/07/2026): 3º fix real descoberto no gate (o mais subtil, achado
    só por reprodução em loop — falhava ~1 em 4 execuções, nunca de forma
    determinística num único run): `TLoggerWSClient.TriggerDataAvailable`
    fazia exatamente 1 `ReceiveStrA` por chamada. A notificação assíncrona do
    WinSock por mensagem (`WM_ASYNC_SELECT`, base do `TWSocketServer`) é por
    TRANSIÇÃO (edge-triggered) — só dispara quando o socket passa de vazio a
    não-vazio. Quando o pedido HTTP Upgrade de um cliente chegava fatiado em
    mais do que 1 segmento TCP (comum sob concorrência — 2º cliente a ligar
    enquanto o servidor já processava outra coisa), o handler lia só o 1º
    pedaço e nunca recebia uma nova notificação para o resto — o pedido
    ficava parado a meio para sempre, sem exceção, sem log (o 1º cliente do
    processo raramente sofria, por chegar quase sempre num único segmento).
    Fix: ciclo de drenagem (`repeat ReceiveStrA until vazio`) dentro do
    handler — o padrão-livro para notificações edge-triggered, garante que o
    socket fica sempre esvaziado antes do handler devolver. Reduziu a falha
    de ~1 em 4 para ~1 em 10 execuções — melhoria grande mas NÃO eliminou por
    completo: sobra uma race mais funda, dentro do próprio dispatch de
    accept/`FD_ACCEPT` do `TWSocketServer` (ICS), fora do alcance do código
    do canal (não é um bug aplicacional — não há fix possível sem editar o
    vendor). **Mitigação aplicada no smoke** (não no canal): reconexão com
    retry (`ConnectAndHandshakeWithRetry`, até 3 tentativas com socket
    totalmente novo por tentativa) — a mesma resiliência que um cliente
    WebSocket real de produção já aplica (reconnect-on-failure, ex.: um
    browser). Validado 70/70 execuções consecutivas com o retry; decisão do
    owner (24/07/2026, ver plano) — aceitar o risco residual documentado em
    vez de perseguir mais fundo os internals do vendor.
  - 1.2.0 (24/07/2026): 2º fix real descoberto no gate — a janela oculta do
    ICS é PARTILHADA entre componentes (pool `TIcsWndHandler`); cada
    componente só recebe mensagens dentro do seu próprio intervalo privado
    `[FMsgLow, FMsgLow+N)`, atribuído via `AllocateMsgHandler`. Um `WM_USER+1`
    fixo colidia com o intervalo que o PRÓPRIO `TWSocketServer` reserva para
    os seus eventos internos de socket (handshake/frames a desaparecer,
    ligações a fechar-se sozinhas — `EIdConnClosedGracefully` no cliente de
    teste); trocar para `RegisterWindowMessage` evitava a colisão mas caía
    FORA do intervalo do componente, logo o dispatcher do pool nunca chamava
    `WndProc` (frame nenhum chegava). Fix definitivo: `TLoggerWSServerComp`
    reserva o seu próprio slot através do mecanismo documentado do ICS —
    `MsgHandlersCount`/`AllocateMsgHandlers` (`FBroadcastMsg :=
    FWndHandler.AllocateMsgHandler(Self)`), o mesmo padrão usado
    internamente por `TCustomWSocket` para os seus 6 handlers assíncronos.
    Também corrigido nesta ronda: `TCustomWSocketServer.Banner` (default
    `'Welcome to OverByte ICS TcpSrv'`) enviado antes da resposta HTTP
    Upgrade — desalinhava o parse `ReadLn` de qualquer cliente WS real;
    `FServer.Banner := ''` no arranque do servidor.
  - 1.1.0 (23/07/2026): fix real descoberto no gate — `TWSocketServer` (ICS)
    é assíncrono por mensagens do Windows; sem um message loop a correr
    continuamente, o servidor nunca processa a ligação/handshake de um
    cliente real (smoke ficou pendurado indefinidamente no handshake do 1º
    cliente). Reescrito para hospedar o servidor em `TLoggerWSServerThread`
    dedicado (`Execute` cria o `TWSocketServer` + `Listen` + bloqueia em
    `MessageLoop`); `Write` deixou de tocar os sockets diretamente (thread
    errada) — agora só enfileira o frame via `EnqueueBroadcast` (lock +
    `PostMessage` para acordar o loop), o envio real corre dentro do
    `WndProc` do servidor (`TLoggerWSServerComp`), já na thread certa.
  - 1.0.0 (23/07/2026): criação — FASE 8 Onda 8.4.5.
  ============================================================================= }

unit Loggers.Channel.WebSocket;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IF DEFINED(USE_LOGGERS_WEBSOCKET) AND DEFINED(USE_PARAMETERS) AND DEFINED(MSWINDOWS)}
  {$DEFINE LOGGERS_WS_CHANNEL_ACTIVE}
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
  TLoggerChannelWebSocket = class(TInterfacedObject, ILoggerChannel)
  strict private
    FLock      : TCriticalSection;
    FEnabled   : Boolean;
    FReady     : Boolean;  { False se Port invalida OU ICS indisponivel (FPC) OU USE_LOGGERS_WEBSOCKET/USE_PARAMETERS em falta OU o Listen falhar (porta ocupada). }
    FPort      : Integer;
    FBindAddr  : string;
    FMaxClients: Integer;
{$IFDEF LOGGERS_WS_CHANNEL_ACTIVE}
    FServerThread: TThread;  { na verdade TLoggerWSServerThread - tipo concreto so' existe na implementation, ver AttemptBroadcast. }
{$ENDIF}
    procedure LoadConfig;
{$IFDEF LOGGERS_WS_CHANNEL_ACTIVE}
    function AttemptBroadcast(const AFrame: TBytes): Boolean;
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
{$IFDEF LOGGERS_WS_CHANNEL_ACTIVE}
  {$IF DEFINED(FPC)}
  Windows,
  base64,                       // EncodeStringBase64 (handshake RFC6455) - FPC RTL
  OverbyteIcsSha1,              // SHA1ofStr (handshake RFC6455) - cross-compiler (ICS)
  Generics.Collections,
  {$ELSE}
  Winapi.Windows,
  Winapi.Messages,
  System.Hash,                 // THashSHA1 (handshake RFC6455) - Delphi RTL
  System.NetEncoding,          // TNetEncoding.Base64 (handshake RFC6455) - Delphi RTL
  System.Generics.Collections,
  {$ENDIF}
  OverbyteIcsWSocketS,          // TWSocketServer/TWSocketClient - motor unico ICS (spike validado na onda 8.4.0)
  Commons.Types,                // TParameter
  Commons.Loggers.Consts,
  Parameters.Interfaces,
  Parameters,
{$ENDIF}
  Loggers.Version;  { mantem a unit no uses mesmo sem LOGGERS_WS_CHANNEL_ACTIVE, evita warning de uses vazio. }

{$IFDEF LOGGERS_WS_CHANNEL_ACTIVE}

const
  WS_MAGIC_GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';  { RFC6455 §1.3 - constante fixa do protocolo. }

{ Constroi um frame de TEXTO WebSocket (RFC6455 §5.2) para um payload UTF-8;
  servidor->cliente NUNCA mascara (masking so e obrigatorio no sentido
  inverso). Absorvido fielmente do LoggersORM v2.3.0
  (Loggers.Engines.WebSocket.Indy.SendWebSocketTextFrame) - so' payloads ate
  65535 bytes (limite do v2.3.0 tambem; uma entrada de log nunca chega la). }
function BuildWebSocketTextFrame(const AText: string): TBytes;
var
  LPayload: TBytes;
  LLen: Integer;
begin
  LPayload := TEncoding.UTF8.GetBytes(AText);
  LLen := Length(LPayload);
  if LLen < 126 then
  begin
    SetLength(Result, 2 + LLen);
    Result[0] := $81;  { FIN=1, opcode=1 (texto). }
    Result[1] := LLen; { bit MASK=0 (frame de servidor, sem mascara). }
    if LLen > 0 then
      Move(LPayload[0], Result[2], LLen);
  end
  else if LLen < 65536 then
  begin
    SetLength(Result, 4 + LLen);
    Result[0] := $81;
    Result[1] := 126;
    Result[2] := (LLen shr 8) and $FF;
    Result[3] := LLen and $FF;
    if LLen > 0 then
      Move(LPayload[0], Result[4], LLen);
  end
  else
    SetLength(Result, 0);  { payload demasiado grande - nunca deveria acontecer para 1 entrada de log; o chamador trata Length=0 como "nada a enviar". }
end;

type
  { Handler por-cliente: acumula bytes ate encontrar o fim dos headers HTTP
    (CRLFCRLF), extrai Sec-WebSocket-Key, responde 101 Switching Protocols.
    Depois do handshake, ignora tudo o que o cliente enviar (canal so-
    broadcast, nunca le frames do lado do cliente - mesma filosofia do
    v2.3.0). Todo o processamento corre na thread do servidor (ver
    TLoggerWSServerThread), nunca na thread do chamador de Write. }
  TLoggerWSClient = class(TWSocketClient)
  strict private
    FHandshakeDone: Boolean;
    FRequestBuffer: string;
    procedure TryCompleteHandshake;
  public
    function TriggerDataAvailable(Error: Word): Boolean; override;
    property HandshakeDone: Boolean read FHandshakeDone;
  end;

  { Servidor com fila thread-safe de frames pendentes: EnqueueBroadcast pode
    ser chamado de QUALQUER thread (ex.: a thread do chamador de Write, ou o
    worker assincrono do nucleo); o envio real (Client.Send) so acontece
    dentro de WndProc, ja na thread do servidor (unica forma segura de tocar
    os sockets ICS). }
  TLoggerWSServerComp = class(TWSocketServer)
  strict private
    FQueueLock: {$IFDEF FPC}SyncObjs.{$ENDIF}TCriticalSection;  { qualificado: Windows.pp/FPC sombreia SyncObjs.TCriticalSection (bug-718). }
    FPending: TList<TBytes>;
    FBroadcastMsg: UINT;
  strict protected
    { A janela oculta do ICS e' PARTILHADA por varios componentes (pool
      TIcsWndHandler) - cada um so' recebe as mensagens dentro do seu proprio
      intervalo privado [FMsgLow, FMsgLow+N), atribuido via AllocateMsgHandler.
      Um WM_USER+N ou RegisterWindowMessage postado directamente NUNCA chega a
      WndProc (o dispatcher do handler descarta tudo fora do intervalo do
      componente) - e' preciso reservar um slot proprio por este mecanismo. }
    function MsgHandlersCount: Integer; override;
    procedure AllocateMsgHandlers; override;
    procedure WndProc(var MsgRec: TMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure EnqueueBroadcast(const AFrame: TBytes);
  end;

  { Hospeda o TWSocketServer inteiramente dentro da propria thread: cria o
    componente no Execute (a janela oculta do ICS fica associada a ESTA
    thread), chama Listen, e bloqueia em MessageLoop (GetMessage/
    DispatchMessage) ate PostQuitMessage - e essa mensagem que faz o
    servidor aceitar ligacoes e processar dados; sem isto o TWSocketServer
    fica "surdo" num processo console sem message loop proprio (achado real
    desta onda). }
  TLoggerWSServerThread = class(TThread)
  strict private
    FBindAddr    : string;
    FPort        : Integer;
    FMaxClients  : Integer;
    FServer      : TLoggerWSServerComp;
    FReadyEvent  : {$IFDEF FPC}SyncObjs.{$ENDIF}TEvent;  { qualificado: Windows.pp/FPC sombreia SyncObjs.TEvent (bug-718). }
    FStartOk     : Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(const ABindAddr: string; APort, AMaxClients: Integer);
    destructor Destroy; override;
    function WaitStarted(ATimeoutMs: Cardinal): Boolean;
    function Broadcast(const AFrame: TBytes): Boolean;
    procedure RequestStop;
  end;

procedure TLoggerWSClient.TryCompleteHandshake;
var
  LKey, LAccept, LResponse: string;
  LLines: TArray<string>;
  I: Integer;
{$IFNDEF FPC}
  LHash: TBytes;
{$ENDIF}
begin
  LKey := '';
  LLines := FRequestBuffer.Split([#13#10]);
  for I := 0 to High(LLines) do
    if LLines[I].TrimLeft.StartsWith('Sec-WebSocket-Key:', True) then
    begin
      LKey := LLines[I].Substring(LLines[I].IndexOf(':') + 1).Trim;
      Break;
    end;
  FRequestBuffer := '';
  if LKey = '' then
  begin
    Close;  { pedido HTTP sem Sec-WebSocket-Key - nao e um handshake WS valido. }
    Exit;
  end;
  try
    {$IFDEF FPC}
    { FPC: SHA1 via ICS (SHA1ofStr - AnsiString 20 chars) + base64 unit; o input
      (key+GUID) e' ASCII puro, logo os bytes batem com o caminho Delphi -> mesmo
      Accept (validado contra o exemplo canonico RFC6455 no smoke). }
    LAccept := string(EncodeStringBase64(SHA1ofStr(AnsiString(LKey + WS_MAGIC_GUID))));
    {$ELSE}
    LHash := THashSHA1.GetHashBytes(LKey + WS_MAGIC_GUID);
    LAccept := TNetEncoding.Base64.EncodeBytesToString(LHash);
    {$ENDIF}
    LResponse :=
      'HTTP/1.1 101 Switching Protocols'#13#10 +
      'Upgrade: websocket'#13#10 +
      'Connection: Upgrade'#13#10 +
      'Sec-WebSocket-Accept: ' + LAccept + #13#10#13#10;
    SendStr(LResponse);
    FHandshakeDone := True;
  except
    { N4 (auditoria F8): cliente desligou a meio do handshake / socket resetado.
      SendStr pode lançar; a excecao NUNCA pode subir para o MessageLoop do
      servidor (terminaria FServer e TODOS os clientes ligados - ver N3). Fecha
      so' este cliente. }
    try Close; except end;
  end;
end;

function TLoggerWSClient.TriggerDataAvailable(Error: Word): Boolean;
var
  LChunk: AnsiString;
begin
  { bug-760: o VALOR DE RETORNO desta funcao diz ao ICS se este handler consumiu
    os dados. `inherited` devolve Assigned(FOnDataAvailable) = FALSE (este canal
    nunca atribui OnDataAvailable) e, com False, TCustomWSocket.ASyncReceive
    (OverbyteIcsWSocket.pas) executa o ramo
      "Nothing wants to receive, we will receive and throw away"
    -> DoRecv(TrashCan, 1024, 0) - que ENGOLE quaisquer bytes chegados entre o
    ultimo ReceiveStrA deste handler e esse DoRecv. Ver `Result := True` no fim. }
  Result := inherited TriggerDataAvailable(Error);
  if FHandshakeDone then
    Exit;  { False DE PROPOSITO depois do handshake: o canal e' so-broadcast e
             QUER que o ICS leia-e-descarte o input do cliente (e' esse ramo do
             ASyncReceive que faz o descarte). NAO devolver True aqui: sem
             ninguem a drenar, FIONREAD nunca baixa e o ASyncReceive entra em
             busy-loop infinito - medido no spike do bug-760: 2.902.897 chamadas
             a este handler em 300 ms e o MessageLoop do servidor congelado
             (deixa de aceitar QUALQUER cliente novo). }
  { Drenar em CICLO ate' nao haver mais nada logo disponivel: a notificacao
    assincrona do WinSock (WM_ASYNC_SELECT) e' por TRANSICAO (edge-triggered) -
    so' dispara quando o buffer passa de vazio a nao-vazio. Se o pedido HTTP
    chegar em mais do que 1 segmento TCP e so' se ler 1 vez por chamada, bytes
    que cheguem enquanto este handler ainda corre podem nunca gerar uma nova
    notificacao - o pedido fica parado a meio para sempre (handshake nunca
    completa, cliente bloqueado a espera de "101"). Achado real do gate (onda
    8.4.5): intermitente (~1 em 4), so' visivel com 2+ clientes/reconexoes -
    o 1o cliente do processo raramente falha (pedido isolado, 1 unico read
    chega a bastar). }
  repeat
    LChunk := ReceiveStrA;
    if LChunk = '' then
      Break;
    FRequestBuffer := FRequestBuffer + string(LChunk);
  until (Pos(#13#10#13#10, FRequestBuffer) > 0) or (Length(FRequestBuffer) > 8192);
  if (Pos(#13#10#13#10, FRequestBuffer) > 0) or (Length(FRequestBuffer) > 8192) then
    TryCompleteHandshake;  { limite de 8KB evita um pedido HTTP mal-formado crescer o buffer indefinidamente. }
  { bug-760 FIX: enquanto o handshake nao esta' concluido, ESTE handler e' o
    unico consumidor legitimo do socket - dizer True impede o ASyncReceive de
    correr o DoRecv(TrashCan) e engolir o resto do pedido HTTP Upgrade. Nao ha
    risco de busy-loop: o ciclo acima ja drenou ate WSAEWOULDBLOCK, logo o
    FIONREAD que o ASyncReceive testa a seguir da' 0 e o loop termina. Medido
    (spike, 30/08): 106 handshakes perdidos / 2400 sem este Result, 0 / 2600
    com ele; e 97/200 -> 0/200 com o servidor deliberadamente ocupado 3 ms. }
  Result := True;
end;

constructor TLoggerWSServerComp.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FQueueLock := {$IFDEF FPC}SyncObjs.{$ENDIF}TCriticalSection.Create;
  FPending := TList<TBytes>.Create;
end;

destructor TLoggerWSServerComp.Destroy;
begin
  FPending.Free;
  FQueueLock.Free;
  inherited;
end;

function TLoggerWSServerComp.MsgHandlersCount: Integer;
begin
  Result := 1 + inherited MsgHandlersCount;
end;

procedure TLoggerWSServerComp.AllocateMsgHandlers;
begin
  inherited AllocateMsgHandlers;
  FBroadcastMsg := FWndHandler.AllocateMsgHandler(Self);
end;

procedure TLoggerWSServerComp.EnqueueBroadcast(const AFrame: TBytes);
const
  MAX_PENDING = 10000;  { N5 (auditoria F8): teto anti-crescimento ilimitado sob rajada. }
begin
  FQueueLock.Acquire;
  try
    { N5: se o dreno (WndProc) nao acompanhar a rajada, descarta os mais ANTIGOS
      (log em tempo real - entradas velhas valem menos) em vez de crescer sem
      limite ate esgotar a memoria. }
    while FPending.Count >= MAX_PENDING do
      FPending.Delete(0);
    FPending.Add(AFrame);
  finally
    FQueueLock.Release;
  end;
  { N5: se PostMessage falhar (fila de mensagens da thread cheia), o frame fica
    em FPending e sai no proximo PostMessage bem-sucedido - nunca crasha. }
  PostMessage(Handle, FBroadcastMsg, 0, 0);
end;

procedure TLoggerWSServerComp.WndProc(var MsgRec: TMessage);
var
  LFrames: TArray<TBytes>;
  I, J: Integer;
  LClient: TWSocketClient;
begin
  if MsgRec.Msg = FBroadcastMsg then
  begin
    FQueueLock.Acquire;
    try
      LFrames := FPending.ToArray;
      FPending.Clear;
    finally
      FQueueLock.Release;
    end;
    for I := 0 to High(LFrames) do
      for J := 0 to ClientCount - 1 do
      begin
        LClient := Client[J];
        if (LClient is TLoggerWSClient) and TLoggerWSClient(LClient).HandshakeDone then
          try
            LClient.Send(Pointer(LFrames[I]), Length(LFrames[I]));
          except
            { um cliente com defeito nunca impede o broadcast aos restantes. }
          end;
      end;
    MsgRec.Result := 0;
  end
  else
    inherited WndProc(MsgRec);
end;

constructor TLoggerWSServerThread.Create(const ABindAddr: string; APort, AMaxClients: Integer);
begin
  FBindAddr := ABindAddr;
  FPort := APort;
  FMaxClients := AMaxClients;
  FReadyEvent := {$IFDEF FPC}SyncObjs.{$ENDIF}TEvent.Create(nil, True, False, '');
  FreeOnTerminate := False;
  inherited Create(False);  { arranca logo - Create devolve so' depois de FBindAddr/FPort/FMaxClients estarem prontos, lidos por Execute na nova thread. }
end;

destructor TLoggerWSServerThread.Destroy;
begin
  FReadyEvent.Free;
  inherited;
end;

procedure TLoggerWSServerThread.Execute;
begin
  FServer := TLoggerWSServerComp.Create(nil);
  try
    FServer.ClientClass := TLoggerWSClient;
    FServer.Addr := FBindAddr;
    FServer.Port := IntToStr(FPort);
    FServer.MaxClients := FMaxClients;
    FServer.Banner := '';  { TCustomWSocketServer manda 'Welcome to OverByte ICS TcpSrv' por default (OverbyteIcsWSocketS.DefaultBanner) - texto solto antes do handshake RFC6455 quebraria qualquer cliente WS real. }
    try
      FServer.Listen;
      FStartOk := True;
    except
      FStartOk := False;
    end;
    FReadyEvent.SetEvent;
    if FStartOk then
      FServer.MessageLoop;  { bloqueia aqui - processa handshakes/dados/EnqueueBroadcast ate RequestStop chamar PostQuitMessage. }
  finally
    FreeAndNil(FServer);
  end;
end;

function TLoggerWSServerThread.WaitStarted(ATimeoutMs: Cardinal): Boolean;
begin
  FReadyEvent.WaitFor(ATimeoutMs);
  Result := FStartOk;
end;

function TLoggerWSServerThread.Broadcast(const AFrame: TBytes): Boolean;
begin
  { N3 (auditoria F8): devolve se o servidor esta' VIVO e aceitou o frame - se
    morreu (Listen falhou / FServer=nil), False, para o fail-over do nucleo
    poder desativar o canal em vez de o dar por saudavel para sempre. 0 clientes
    ligados NAO e' falha (fire-and-forget - o frame e' enfileirado na mesma). }
  Result := FStartOk and (FServer <> nil);
  if Result then
    FServer.EnqueueBroadcast(AFrame);
end;

procedure TLoggerWSServerThread.RequestStop;
begin
  if FStartOk and (FServer <> nil) then
    FServer.PostQuitMessage;
end;

{$ENDIF LOGGERS_WS_CHANNEL_ACTIVE}

constructor TLoggerChannelWebSocket.Create;
begin
  inherited Create;
  FLock := {$IFDEF FPC}SyncObjs.{$ENDIF}TCriticalSection.Create;
  FEnabled := False;
  FReady := False;
  LoadConfig;
{$IFDEF LOGGERS_WS_CHANNEL_ACTIVE}
  if FReady then
  begin
    FServerThread := TLoggerWSServerThread.Create(FBindAddr, FPort, FMaxClients);
    if not TLoggerWSServerThread(FServerThread).WaitStarted(5000) then
    begin
      FReady := False;  { falhou a arrancar (porta ocupada, timeout, etc.) - canal fica inerte. }
      FServerThread.WaitFor;
      FreeAndNil(FServerThread);
    end;
  end;
{$ENDIF}
end;

destructor TLoggerChannelWebSocket.Destroy;
begin
{$IFDEF LOGGERS_WS_CHANNEL_ACTIVE}
  if FServerThread <> nil then
  begin
    try
      TLoggerWSServerThread(FServerThread).RequestStop;
      FServerThread.WaitFor;
    except
      { nunca propaga a partir do destructor. }
    end;
    FServerThread.Free;
  end;
{$ENDIF}
  FLock.Free;
  inherited;
end;

function TLoggerChannelWebSocket.Name: string;
begin
  Result := 'WebSocket';
end;

function TLoggerChannelWebSocket.Enabled: Boolean;
begin
  FLock.Acquire;
  try
    Result := FEnabled and FReady;
  finally
    FLock.Release;
  end;
end;

function TLoggerChannelWebSocket.Enabled(const AValue: Boolean): ILoggerChannel;
begin
  FLock.Acquire;
  try
    FEnabled := AValue;
  finally
    FLock.Release;
  end;
  Result := Self;
end;

function TLoggerChannelWebSocket.IsHealthy: Boolean;
begin
  Result := Enabled;
end;

{$IFDEF LOGGERS_WS_CHANNEL_ACTIVE}

procedure TLoggerChannelWebSocket.LoadConfig;
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
  LSource.Title(LOGGERS_TITULO_WEBSOCKET);

  FEnabled := SameText(Read(LOGGERS_WS_ENABLED, DEFAULT_LOGGERS_WS_ENABLED), 'True');
  FPort := StrToIntDef(Read(LOGGERS_WS_PORT, DEFAULT_LOGGERS_WS_PORT), 8090);
  FBindAddr := Read(LOGGERS_WS_BIND_ADDR, DEFAULT_LOGGERS_WS_BIND_ADDR);
  FMaxClients := StrToIntDef(Read(LOGGERS_WS_MAX_CLIENTS, DEFAULT_LOGGERS_WS_MAX_CLIENTS), 50);

  FReady := (FPort > 0) and (FPort <= 65535);
end;

function TLoggerChannelWebSocket.AttemptBroadcast(const AFrame: TBytes): Boolean;
begin
  Result := TLoggerWSServerThread(FServerThread).Broadcast(AFrame);
end;

{$ELSE}

procedure TLoggerChannelWebSocket.LoadConfig;
begin
  { USE_LOGGERS_WEBSOCKET/USE_PARAMETERS em falta, OU fora do Windows/FPC
    (ICS Delphi-only nesta build, bug-712) - canal permanece inerte. }
  FEnabled := False;
  FReady := False;
end;

{$ENDIF LOGGERS_WS_CHANNEL_ACTIVE}

function TLoggerChannelWebSocket.Write(const AEntry: TLoggerEntry): Boolean;
{$IFDEF LOGGERS_WS_CHANNEL_ACTIVE}
var
  LFrame: TBytes;
{$ENDIF}
begin
  Result := False;
  if not (FReady and FEnabled) then
    Exit;
{$IFDEF LOGGERS_WS_CHANNEL_ACTIVE}
  if FServerThread = nil then
    Exit;
  try
    LFrame := BuildWebSocketTextFrame(LoggerEntryToJSON(AEntry));
    if Length(LFrame) = 0 then
      Exit(True);  { payload demasiado grande para 1 frame - nao e falha do canal. }
    Result := AttemptBroadcast(LFrame);  { N3: True so' se o servidor esta' vivo (0 clientes ainda conta como sucesso, fire-and-forget). }
  except
    Result := False;
  end;
{$ENDIF}
end;

{$ENDIF USE_LOGGERS}

end.
