{ =============================================================================
  Loggers.Channel.SysLog - Canal SysLog RFC5424 (Delphi-only, via ICS)

  TLoggerChannelSysLog: implementa ILoggerChannel enviando cada entrada de log
  como UMA mensagem RFC5424 ("The Syslog Protocol") a um recetor SysLog
  (rsyslog/syslog-ng/Graylog/qualquer coletor compativel), sobre o motor UNICO
  ICS (OverbyteIcsWSocket.TWSocket) - o MESMO componente ja usado pelo canal
  Redis (onda 8.15), reaproveitando o padrao "cliente fresco por-tentativa" +
  bombeamento manual de mensagens (TWSocket.ProcessMessage + Sleep curto,
  deadline por operacao) ja validado neste projecto (test_websocket.dpr,
  producao no canal Redis). E' o canal de rede MAIS simples do modulo: UDP
  (default, fire-and-forget - um unico datagrama por Write, sem handshake de
  rede real; o Connect de um socket UDP so associa o par remoto localmente,
  confirmado no source do ICS - TCustomWSocket.Connect dispara
  TriggerSessionConnectedSpecial(0) de imediato quando FType=SOCK_DGRAM) ou
  TCP (framing nao-transparente por LF, RFC6587 - mais simples que
  octet-counting, sem esperar resposta do recetor em nenhum dos 2 casos - o
  protocolo SysLog nao tem confirmacao de entrega a nivel de aplicacao).

  Mensagem RFC5424: PRIVAL = Facility*8 + Severity (Severity mapeado do
  TLogLevel deste projecto - 9 niveis - para os 8 niveis RFC5424:
  llCritical/llException->2 Critical, llError->3 Error, llWarning->4 Warning,
  llInfo/llSuccess/llDone->6 Informational, llDebug/llTrace->7 Debug; nunca
  emite 0/1/5, sem consumidor real para Emergency/Alert/Notice neste modulo).
  TIMESTAMP em RFC3339 com o OFFSET local real (nao 'Z' falso) - mesma
  filosofia de honestidade de fuso ja aplicada em
  Commons.Loggers.Types.LoggerEntryToJSON (hora local, sem UTC fingido);
  offset calculado via Windows.GetTimeZoneInformation (Bias em minutos,
  disponivel identico em FPC e Delphi). HOSTNAME/APP-NAME/PROCID/MSGID
  sanitizados para PRINTUSASCII sem espacos (substitui caracter invalido por
  '_', "-" se ficar vazio) - a MENSAGEM em si (MSG) nao e sanitizada, viaja
  UTF-8 integral. STRUCTURED-DATA sempre "-" (nenhum SD-ELEMENT nesta
  versao). MSGID usa a Category da entrada (sanitizada) quando presente,
  senao "-"; a MSG acrescenta "[Category]" (texto integral, nao sanitizado)
  para nao perder informacao que a sanitizacao do MSGID possa cortar.

  Absorcao: SEM equivalente direto no LoggersORM v2.3.0 nem no QuickLogger
  (nenhum dos dois tem provider SysLog) - canal novo do v3, desenhado de raiz
  seguindo o padrao SSOT ja estabelecido pelos canais de rede ICS existentes
  (Http/Email/WebSocket/Redis/ElasticSearch).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.15.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           01/08/2026

  Changelog (file):
  - 1.0.0 (01/08/2026): criacao - FASE 8 (canal SysLog RFC5424, 13o canal
    baseline, 6o canal REAL sobre ICS). PRIVAL=Facility*8+Severity, TIMESTAMP
    RFC3339 com offset local real, HOSTNAME/APP-NAME/PROCID/MSGID
    sanitizados, STRUCTURED-DATA="-". Transporte UDP (default,
    fire-and-forget) ou TCP (framing LF nao-transparente), mesmo padrao
    TWSocket + Pump manual ja usado pelo canal Redis - sem esperar resposta
    do recetor em nenhum dos 2 protocolos.
  ============================================================================= }

unit Loggers.Channel.SysLog;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../ORM.Defines.inc}

{$IF DEFINED(USE_LOGGERS_SYSLOG) AND DEFINED(USE_PARAMETERS) AND DEFINED(MSWINDOWS)}
  {$DEFINE LOGGERS_SYSLOG_CHANNEL_ACTIVE}
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
  TLoggerChannelSysLog = class(TInterfacedObject, ILoggerChannel)
  strict private
    FLock     : TCriticalSection;
    FEnabled  : Boolean;
    FReady    : Boolean;  { False se Host vazio OU ICS indisponivel (FPC) OU USE_LOGGERS_SYSLOG/USE_PARAMETERS em falta. }
    FHost     : string;
    FPort     : Integer;
    FProtocol : string;   { 'udp' (default) ou 'tcp'. }
    FFacility : Integer;  { 0..23 (RFC5424); default 16 = local0. }
    FAppName  : string;
    FHostname : string;
    procedure LoadConfig;
{$IFDEF LOGGERS_SYSLOG_CHANNEL_ACTIVE}
    function BuildMessage(const AEntry: TLoggerEntry): TBytes;
    function AttemptSend(const ABytes: TBytes): Boolean;
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
{$IFDEF LOGGERS_SYSLOG_CHANNEL_ACTIVE}
  {$IF DEFINED(FPC)}
  Windows,
  {$ELSE}
  Winapi.Windows,
  {$ENDIF}
  OverbyteIcsWSocket,          // TWSocket - motor unico ICS (mesmo padrao do canal Redis)
  Commons.Types,                // TParameter
  Commons.Loggers.Consts,
  Parameters.Interfaces,
  Parameters,
{$ENDIF}
  Loggers.Version;  { mantem a unit no uses mesmo sem LOGGERS_SYSLOG_CHANNEL_ACTIVE, evita warning de uses vazio. }

constructor TLoggerChannelSysLog.Create;
begin
  inherited Create;
{$IFDEF FPC}
  FLock := SyncObjs.TCriticalSection.Create;  { Windows.pp do FPC declara TCriticalSection (record WinAPI) que sombreia a classe SyncObjs quando Windows entra em scope na implementation - bug-659, mesmo fix dos canais EventLog/Console/Memory/Redis/ElasticSearch. }
{$ELSE}
  FLock := TCriticalSection.Create;
{$ENDIF}
  FEnabled := False;
  FReady := False;
  LoadConfig;
end;

destructor TLoggerChannelSysLog.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TLoggerChannelSysLog.Name: string;
begin
  Result := 'SysLog';
end;

function TLoggerChannelSysLog.Enabled: Boolean;
begin
  FLock.Acquire;
  try
    Result := FEnabled and FReady;
  finally
    FLock.Release;
  end;
end;

function TLoggerChannelSysLog.Enabled(const AValue: Boolean): ILoggerChannel;
begin
  FLock.Acquire;
  try
    FEnabled := AValue;
  finally
    FLock.Release;
  end;
  Result := Self;
end;

function TLoggerChannelSysLog.IsHealthy: Boolean;
begin
  Result := Enabled;
end;

{$IFDEF LOGGERS_SYSLOG_CHANNEL_ACTIVE}

const
  { Timeout fixo por-tentativa (connect+send) - o canal SysLog nao expoe
    chave de configuracao propria para isto (ao contrario de Redis/Http/
    Email): UDP e' fire-and-forget quase instantaneo (Connect de um socket
    SOCK_DGRAM nao faz handshake de rede) e TCP so' precisa do 3-way
    handshake, sem trocas subsequentes - 10s cobre com folga qualquer dos 2
    casos sem justificar mais uma chave de config. }
  SYSLOG_DEFAULT_TIMEOUT_SEC = 10;

procedure TLoggerChannelSysLog.LoadConfig;
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
  LSource.Title(LOGGERS_TITULO_SYSLOG);

  FEnabled := SameText(Read(LOGGERS_SYSLOG_ENABLED, DEFAULT_LOGGERS_SYSLOG_ENABLED), 'True');
  FHost := Read(LOGGERS_SYSLOG_HOST, DEFAULT_LOGGERS_SYSLOG_HOST);
  FPort := StrToIntDef(Read(LOGGERS_SYSLOG_PORT, DEFAULT_LOGGERS_SYSLOG_PORT), 514);
  FProtocol := LowerCase(Read(LOGGERS_SYSLOG_PROTOCOL, DEFAULT_LOGGERS_SYSLOG_PROTOCOL));
  if (FProtocol <> 'udp') and (FProtocol <> 'tcp') then
    FProtocol := DEFAULT_LOGGERS_SYSLOG_PROTOCOL;  { config invalida - fail-safe: cai no default (udp). }
  FFacility := StrToIntDef(Read(LOGGERS_SYSLOG_FACILITY, DEFAULT_LOGGERS_SYSLOG_FACILITY), 16);
  if (FFacility < 0) or (FFacility > 23) then
    FFacility := 16;  { fora do intervalo RFC5424 (0..23) - fail-safe: local0. }
  FAppName := Read(LOGGERS_SYSLOG_APP_NAME, DEFAULT_LOGGERS_SYSLOG_APP_NAME);
  if FAppName = '' then
    FAppName := ExtractFileName(ParamStr(0));
  FHostname := Read(LOGGERS_SYSLOG_HOSTNAME, DEFAULT_LOGGERS_SYSLOG_HOSTNAME);
  if FHostname = '' then
  begin
    { GetEnvironmentVariable (1 arg, devolve string) - QUALIFICADO: o
      Windows.pp do FPC / Winapi.Windows do Delphi declaram a sua propria
      GetEnvironmentVariable (3 args, wrapper WinAPI) que sombreia a de
      SysUtils quando Windows entra em scope na implementation (mesma
      familia do bug-659/TCriticalSection). Qualificacao pelo NOME REAL da
      unit por compilador (nao "SysUtils" nu sob Delphi - so' resolve via
      -NS/Unit Scope Names, que nem sempre esta' activo, ex.: ficheiros fora
      da pasta do dcc32.cfg, como testes\Loggers\). }
{$IFDEF FPC}
    FHostname := SysUtils.GetEnvironmentVariable('COMPUTERNAME');
{$ELSE}
    FHostname := System.SysUtils.GetEnvironmentVariable('COMPUTERNAME');
{$ENDIF}
    if FHostname = '' then
      FHostname := 'localhost';
  end;

  FReady := (FHost <> '');  { canal inerte ate ter um host configurado, independente de Enabled. }
end;

{ Mapeia o TLogLevel (9 valores, este projecto) para a Severity RFC5424 (0
  Emergency .. 7 Debug) - nunca emite 0/1/5 (Emergency/Alert/Notice), sem
  consumidor real desses 3 niveis neste modulo. }
function SysLogSeverity(ALevel: TLogLevel): Integer;
begin
  case ALevel of
    llCritical, llException:   Result := 2;  // Critical
    llError:                   Result := 3;  // Error
    llWarning:                 Result := 4;  // Warning
    llDebug, llTrace:          Result := 7;  // Debug
    llInfo, llSuccess, llDone: Result := 6;  // Informational
  else
    Result := 6;  // fail-safe - nunca deveria cair aqui (os 9 valores estao cobertos acima).
  end;
end;

{ Sanitiza um campo de cabecalho RFC5424 (HOSTNAME/APP-NAME/PROCID/MSGID) -
  PRINTUSASCII sem espaco, sem '=', ']' nem aspas (delimitadores de
  STRUCTURED-DATA, evita ambiguidade mesmo este canal nunca os emitindo).
  Caracter invalido vira '_'; string vazia apos sanitizar vira '-'
  (NILVALUE). AMaxLen<=0 desliga o corte de tamanho. }
function SysLogSanitizeField(const AValue: string; AMaxLen: Integer): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(AValue) do
  begin
    C := AValue[I];
    if (Ord(C) > 32) and (Ord(C) < 127) and (C <> '=') and (C <> ']') and (C <> '"') then
      Result := Result + C
    else
      Result := Result + '_';
  end;
  if Result = '' then
    Result := '-';
  if (AMaxLen > 0) and (Length(Result) > AMaxLen) then
    Result := Copy(Result, 1, AMaxLen);
end;

{ TIMESTAMP RFC3339 com o OFFSET LOCAL REAL (nao 'Z' falso) - mesma
  honestidade de fuso ja aplicada por Commons.Loggers.Types.LoggerEntryToJSON
  (AEntry.Timestamp e' hora local, vinda de Now). Bias de
  GetTimeZoneInformation e' em MINUTOS que se SOMAM ao horario local para
  obter UTC (ex.: UTC-3 -> Bias=180) - o offset RFC3339 e' o INVERSO. }
function SysLogRfc3339Timestamp(const ATimestamp: TDateTime): string;
var
  LTzi: TTimeZoneInformation;
  LBiasMinutes, LAbsBias, LHours, LMins: Integer;
  LSign: Char;
begin
  case GetTimeZoneInformation(LTzi) of
    TIME_ZONE_ID_STANDARD: LBiasMinutes := LTzi.Bias + LTzi.StandardBias;
    TIME_ZONE_ID_DAYLIGHT: LBiasMinutes := LTzi.Bias + LTzi.DaylightBias;
  else
    LBiasMinutes := LTzi.Bias;  { TIME_ZONE_ID_UNKNOWN/erro - assume so' o Bias base. }
  end;
  LAbsBias := Abs(LBiasMinutes);
  LHours := LAbsBias div 60;
  LMins := LAbsBias mod 60;
  if LBiasMinutes <= 0 then
    LSign := '+'  // Bias<=0 -> local esta' A FRENTE de UTC (ou e' UTC).
  else
    LSign := '-'; // Bias>0 -> local esta' ATRAS de UTC.
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz', ATimestamp) +
    Format('%s%.2d:%.2d', [LSign, LHours, LMins]);
end;

function TLoggerChannelSysLog.BuildMessage(const AEntry: TLoggerEntry): TBytes;
var
  LPri: Integer;
  LHostname, LAppName, LProcId, LMsgId, LMsg, LLine: string;
begin
  LPri := FFacility * 8 + SysLogSeverity(AEntry.Level);
  LHostname := SysLogSanitizeField(FHostname, 255);
  LAppName := SysLogSanitizeField(FAppName, 48);
  LProcId := IntToStr(Integer(GetCurrentProcessId));
  if AEntry.Category <> '' then
    LMsgId := SysLogSanitizeField(AEntry.Category, 32)
  else
    LMsgId := '-';
  LMsg := AEntry.Message;
  if AEntry.Category <> '' then
    LMsg := LMsg + ' [' + AEntry.Category + ']';  { texto integral, nao sanitizado - so' o MSGID acima e' sanitizado/cortado. }

  LLine := '<' + IntToStr(LPri) + '>1 ' +
    SysLogRfc3339Timestamp(AEntry.Timestamp) + ' ' +
    LHostname + ' ' +
    LAppName + ' ' +
    LProcId + ' ' +
    LMsgId + ' - ' +   { '-' = STRUCTURED-DATA (NILVALUE, nenhum SD-ELEMENT nesta versao). }
    LMsg;

  if SameText(FProtocol, 'tcp') then
    LLine := LLine + #10;  { framing NAO-transparente por LF (RFC6587) - mais simples que octet-counting. }

  Result := TEncoding.UTF8.GetBytes(LLine);
end;

type
  { Cliente de transporte fire-and-forget sobre TWSocket (ICS) - 1 instancia
    fresca por tentativa de Write (mesmo padrao "cliente fresco por
    tentativa" dos canais Http/Email/Redis). Cobre UDP e TCP com o MESMO
    codigo: para UDP, Connect() de um socket SOCK_DGRAM nao faz handshake de
    rede - dispara TriggerSessionConnectedSpecial(0) de imediato (confirmado
    no source do ICS, OverbyteIcsWSocket.pas) - por isso o mesmo ciclo de
    Pump com deadline serve aos 2 protocolos sem ramificacao. NUNCA espera
    resposta do recetor (SysLog nao tem confirmacao de entrega a nivel de
    aplicacao, nem em UDP nem em TCP) - so' confirma que o Send foi aceite
    pela pilha local. }
  TSysLogTransportClient = class
  strict private
    FSocket    : TWSocket;
    FTimeoutSec: Integer;
    FConnDone  : Boolean;
    FConnOk    : Boolean;
    FClosed    : Boolean;
    procedure DoSessionConnected(Sender: TObject; ErrCode: Word);
    procedure DoSessionClosed(Sender: TObject; ErrCode: Word);
    procedure Pump;
  public
    constructor Create(ATimeoutSec: Integer);
    destructor Destroy; override;
    function SendDatagram(const AProto, AHost: string; APort: Integer; const ABytes: TBytes): Boolean;
  end;

constructor TSysLogTransportClient.Create(ATimeoutSec: Integer);
begin
  inherited Create;
  FTimeoutSec := ATimeoutSec;
  if FTimeoutSec <= 0 then
    FTimeoutSec := SYSLOG_DEFAULT_TIMEOUT_SEC;
  FConnDone := False;
  FConnOk := False;
  FClosed := False;
  FSocket := TWSocket.Create(nil);
  FSocket.OnSessionConnected := DoSessionConnected;
  FSocket.OnSessionClosed := DoSessionClosed;
end;

destructor TSysLogTransportClient.Destroy;
begin
  try
    FSocket.Close;
  except
    { nunca propaga a partir do destructor. }
  end;
  FSocket.Free;
  inherited;
end;

procedure TSysLogTransportClient.DoSessionConnected(Sender: TObject; ErrCode: Word);
begin
  FConnDone := True;
  FConnOk := (ErrCode = 0);
end;

procedure TSysLogTransportClient.DoSessionClosed(Sender: TObject; ErrCode: Word);
begin
  FClosed := True;
end;

{ 1 "passo" nao-bloqueante do pump (TWSocket e' assincrono por mensagens do
  Windows - sem isto Connect/Send nunca progridem); o chamador decide o
  deadline por operacao. Sleep curto quando nao ha mensagem pendente evita
  busy-spin - mesmo padrao de test_websocket.dpr/canal Redis. }
procedure TSysLogTransportClient.Pump;
begin
  if not FSocket.ProcessMessage then
    Sleep(5);
end;

function TSysLogTransportClient.SendDatagram(const AProto, AHost: string; APort: Integer; const ABytes: TBytes): Boolean;
var
  LDeadline: Cardinal;
begin
  Result := False;
  if Length(ABytes) = 0 then
    Exit;
  FSocket.Proto := AProto;  // 'udp' ou 'tcp'
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
  if not (FConnDone and FConnOk and (not FClosed)) then
    Exit(False);

  try
    if FSocket.Send(Pointer(ABytes), Length(ABytes)) < 0 then
      Exit(False);
  except
    Exit(False);
  end;

  { Drena o buffer de saida do socket antes de fechar (o Destroy do chamador
    fecha logo a seguir) - sem isto um Close prematuro podia truncar os
    ultimos bytes ainda por entregar a pilha TCP/UDP do SO (mais relevante em
    TCP; UDP tipicamente esvazia de imediato por ser uma so mensagem curta).
    TWSocket.AllSent (bAllSent) so fica True depois do proprio winsock aceitar
    TODOS os bytes deste Send - deadline curto e independente do FTimeoutSec
    de connect, isto e' so' drenagem local, nao espera de rede/confirmacao do
    recetor. }
  LDeadline := GetTickCount + 2000;
  while (not FSocket.AllSent) and (not FClosed) and (GetTickCount < LDeadline) do
    Pump;

  Result := True;
end;

function TLoggerChannelSysLog.AttemptSend(const ABytes: TBytes): Boolean;
var
  LClient: TSysLogTransportClient;
begin
  Result := False;
  LClient := TSysLogTransportClient.Create(SYSLOG_DEFAULT_TIMEOUT_SEC);
  try
    try
      Result := LClient.SendDatagram(FProtocol, FHost, FPort, ABytes);
    except
      Result := False;  { erro de rede/protocolo - nunca propaga, elegivel ao fail-over do nucleo. }
    end;
  finally
    LClient.Free;
  end;
end;

{$ELSE}

procedure TLoggerChannelSysLog.LoadConfig;
begin
  { USE_LOGGERS_SYSLOG/USE_PARAMETERS em falta, OU fora do Windows/FPC (ICS
    Delphi-only nesta build, bug-712) - canal permanece inerte. }
  FEnabled := False;
  FReady := False;
end;

{$ENDIF LOGGERS_SYSLOG_CHANNEL_ACTIVE}

function TLoggerChannelSysLog.Write(const AEntry: TLoggerEntry): Boolean;
{$IFDEF LOGGERS_SYSLOG_CHANNEL_ACTIVE}
var
  LBytes: TBytes;
{$ENDIF}
begin
  Result := False;
  if not (FReady and FEnabled) then
    Exit;
{$IFDEF LOGGERS_SYSLOG_CHANNEL_ACTIVE}
  try
    LBytes := BuildMessage(AEntry);
    Result := AttemptSend(LBytes);
  except
    Result := False;
  end;
{$ENDIF}
end;

{$ENDIF USE_LOGGERS}

end.
