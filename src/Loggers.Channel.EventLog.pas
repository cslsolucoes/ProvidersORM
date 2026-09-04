{ =============================================================================
  Loggers.Channel.EventLog - Canal Windows Event Log (F8 Onda 8.4.1)

  TLoggerChannelEventLog: implementa ILoggerChannel sobre a API standard do
  Windows (RegisterEventSource/ReportEvent/DeregisterEventSource, já
  declaradas em Winapi.Windows/Windows - SEM declaração externa manual, ao
  contrário do LoggersORM v2.3.0, cuja versão hand-rolled misturava entry
  points ANSI ('...A') com PChar Unicode). Handle mantido aberto entre
  escritas (reaberto só se ainda não existir), fechado no Destroy. Regista a
  fonte no registry (HKLM\SYSTEM\CurrentControlSet\Services\EventLog\<Log>\
  <Source>) se AutoCreateSource=True e a fonte ainda não existir - requer
  privilégios de administrador; falha degrada silenciosamente (mesma
  filosofia dos outros canais: nunca propaga, fail-over do núcleo decide).
  Fora do Windows (ou com USE_LOGGERS_EVENTLOG desligado), canal inerte.

  Absorção de lógica/semântica do LoggersORM v2.3.0 (Loggers.EventLogs.*),
  NÃO cópia de ficheiros - simplificada para o padrão de configuração v3 (via
  IParameters/Commons.Loggers.Consts, não a API fluente de 20+ setters do
  v2.3.0): mapeamento de nível->tipo de evento é direto e fixo; EventID é
  derivado (1000+Ord(Level)) em vez de 5 chaves configuráveis; categoria
  sempre 0 (sem CategoryCount configurável). Corrige o bug de ANSI/Unicode do
  v2.3.0 usando as funções standard (resolvem para os entry points corretos
  automaticamente, tanto em Delphi como em FPC - confirmado por spike real).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.10.0
  FileVersion:    1.2.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           23/07/2026

  Changelog (file):
  - (sync 27/07/2026) ModuleVersion sincronizado para 1.10.0 - F8 Onda 8.9 (hardening pos-auditoria); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.10.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.9.0 - F8 Onda 8.4.5 acrescenta o canal TLoggerChannelWebSocket (8o canal baseline, 3o real sobre ICS, resolve P2); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.9.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.8.0 - F8 Onda 8.4.4 acrescenta o canal TLoggerChannelEmail (7o canal baseline, 2o real sobre ICS); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.8.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.7.0 - F8 Onda 8.4.3 acrescenta o canal TLoggerChannelHttp (6o canal baseline, 1o real sobre ICS); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.7.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.6.0 - F8 Onda 8.4.2 acrescenta o canal TLoggerChannelCSV (5o canal baseline); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.6.0.
  - 1.2.0 (23/07/2026): 2º fix FPC do gate 4/4 - a unit Windows.pp do FPC
    3.3.1 nao declara EVENTLOG_SUCCESS/EVENTLOG_ERROR_TYPE/
    EVENTLOG_WARNING_TYPE/EVENTLOG_INFORMATION_TYPE (presentes em
    Winapi.Windows no Delphi, por isso dcc32/dcc64 ja compilavam OK).
    "Identifier not found EVENTLOG_SUCCESS" em fpc32/fpc64. Fix: constantes
    redeclaradas localmente so sob IFDEF FPC, valores estaveis da WinAPI
    (winbase.h) - nao e mecanismo de projeto, e API crua do SO.
  - 1.1.0 (23/07/2026): fix bug real FPC 3.3.1 (achado no gate 4/4 da Onda
    8.4.1) - a unit Windows.pp do FPC declara o seu proprio TCriticalSection
    (struct WinAPI, nao a classe de SyncObjs). Como Windows entra em scope na
    implementation (bloco MSWINDOWS) DEPOIS de SyncObjs (interface), o
    identificador curto "TCriticalSection" passa a resolver para o record da
    Windows.pp dentro da implementation - "TCriticalSection.Create" falhava
    com "Identifier idents no member Create" (fpc32/fpc64, dcc32/dcc64 imunes
    porque Winapi.Windows nao declara TCriticalSection). Confirmado por spike
    isolado (2 units, so difere a ordem SyncObjs/Windows no uses). Fix:
    qualificar "SyncObjs.TCriticalSection.Create" so no ramo condicional FPC
    (IFDEF FPC, sem chavetas aqui de propósito - ver bug-659/cerebrum).
  - 1.0.0 (23/07/2026): criação — FASE 8 Onda 8.4.1.
  ============================================================================= }

unit Loggers.Channel.EventLog;

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
  Loggers.Interfaces;

type
  TLoggerChannelEventLog = class(TInterfacedObject, ILoggerChannel)
  strict private
    FLock            : TCriticalSection;
    FEnabled         : Boolean;
    FReady           : Boolean;  { False fora do Windows OU USE_LOGGERS_EVENTLOG desligado OU perfil vazio. }
    FSourceName      : string;
    FLogName         : string;
    FAutoCreateSource: Boolean;
{$IFDEF MSWINDOWS}
    FHandle          : THandle;  { 0 = fechado; mantido aberto entre escritas. }
{$ENDIF}
    procedure LoadConfig;
{$IFDEF MSWINDOWS}
    function EnsureSourceRegistered: Boolean;
    function OpenSource: Boolean;
    procedure CloseSource;
    function EventTypeFor(ALevel: TLogLevel): Word;
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

{$IF DEFINED(USE_LOGGERS_EVENTLOG) AND DEFINED(USE_PARAMETERS)}
  {$DEFINE LOGGERS_EVT_CHANNEL_ACTIVE}
{$ENDIF}

uses
{$IFDEF LOGGERS_EVT_CHANNEL_ACTIVE}
  Commons.Types,              // TParameter
  Commons.Loggers.Consts,
  Parameters.Interfaces,
  Parameters,
{$ENDIF}
{$IFDEF MSWINDOWS}
  {$IF DEFINED(FPC)}
  Windows,
  Registry,
  {$ELSE}
  Winapi.Windows,
  System.Win.Registry,
  {$ENDIF}
{$ENDIF}
  Loggers.Version;  { mantem a unit no uses mesmo sem LOGGERS_EVT_CHANNEL_ACTIVE, evita warning de uses vazio. }

constructor TLoggerChannelEventLog.Create;
begin
  inherited Create;
{$IFDEF FPC}
  FLock := SyncObjs.TCriticalSection.Create;  { Windows.pp tambem declara TCriticalSection (struct WinAPI) - sem qualificar, o nome curto resolve para o record, nao para a classe SyncObjs, porque a unit Windows entra em scope na implementation (bug real FPC 3.3.1, achado F8 8.4.1). }
{$ELSE}
  FLock := TCriticalSection.Create;
{$ENDIF}
  FEnabled := False;
  FReady := False;
{$IFDEF MSWINDOWS}
  FHandle := 0;
{$ENDIF}
  LoadConfig;
end;

destructor TLoggerChannelEventLog.Destroy;
begin
{$IFDEF MSWINDOWS}
  CloseSource;
{$ENDIF}
  FLock.Free;
  inherited;
end;

function TLoggerChannelEventLog.Name: string;
begin
  Result := 'EventLog';
end;

function TLoggerChannelEventLog.Enabled: Boolean;
begin
  FLock.Acquire;
  try
    Result := FEnabled and FReady;
  finally
    FLock.Release;
  end;
end;

function TLoggerChannelEventLog.Enabled(const AValue: Boolean): ILoggerChannel;
begin
  FLock.Acquire;
  try
    FEnabled := AValue;
  finally
    FLock.Release;
  end;
  Result := Self;
end;

function TLoggerChannelEventLog.IsHealthy: Boolean;
begin
  Result := Enabled;
end;

{$IFDEF LOGGERS_EVT_CHANNEL_ACTIVE}

procedure TLoggerChannelEventLog.LoadConfig;
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
  LSource.Title(LOGGERS_TITULO_EVENTLOG);

  FEnabled := SameText(Read(LOGGERS_EVT_ENABLED, DEFAULT_LOGGERS_EVT_ENABLED), 'True');
  FSourceName := Read(LOGGERS_EVT_SOURCE_NAME, DEFAULT_LOGGERS_EVT_SOURCE_NAME);
  if FSourceName = '' then
  begin
    LSource.Title(LOGGERS_TITULO_CORE);
    FSourceName := Read(LOGGERS_APP_NAME_OVERRIDE, '');
    if FSourceName = '' then
      FSourceName := ChangeFileExt(ExtractFileName(ParamStr(0)), '');
  end;
  LSource.Title(LOGGERS_TITULO_EVENTLOG);
  FLogName := Read(LOGGERS_EVT_LOG_NAME, DEFAULT_LOGGERS_EVT_LOG_NAME);
  FAutoCreateSource := SameText(Read(LOGGERS_EVT_AUTO_CREATE_SOURCE, DEFAULT_LOGGERS_EVT_AUTO_CREATE), 'True');

{$IFDEF MSWINDOWS}
  FReady := True;
{$ELSE}
  FReady := False;  { fora do Windows: canal permanece inerte (Write sempre False). }
{$ENDIF}
end;

{$ELSE}

procedure TLoggerChannelEventLog.LoadConfig;
begin
  { USE_LOGGERS_EVENTLOG/USE_PARAMETERS em falta - canal permanece inerte. }
  FEnabled := False;
  FReady := False;
end;

{$ENDIF LOGGERS_EVT_CHANNEL_ACTIVE}

{$IFDEF MSWINDOWS}

{$IFDEF FPC}
const
  { A unit Windows.pp do FPC 3.3.1 nao declara estas constantes (presentes em
    Winapi.Windows no Delphi) - valores estaveis da WinAPI (winbase.h), sem
    variacao entre versoes do Windows. }
  EVENTLOG_SUCCESS          = $0000;
  EVENTLOG_ERROR_TYPE       = $0001;
  EVENTLOG_WARNING_TYPE     = $0002;
  EVENTLOG_INFORMATION_TYPE = $0004;
{$ENDIF}

function TLoggerChannelEventLog.EventTypeFor(ALevel: TLogLevel): Word;
begin
  case ALevel of
    llSuccess, llDone:               Result := EVENTLOG_SUCCESS;
    llWarning:                       Result := EVENTLOG_WARNING_TYPE;
    llError, llCritical, llException: Result := EVENTLOG_ERROR_TYPE;
  else
    Result := EVENTLOG_INFORMATION_TYPE;  { llInfo, llDebug, llTrace. }
  end;
end;

function TLoggerChannelEventLog.EnsureSourceRegistered: Boolean;
var
  LReg: TRegistry;
  LKey: string;
begin
  Result := False;
  LReg := TRegistry.Create(KEY_WRITE);
  try
    LReg.RootKey := HKEY_LOCAL_MACHINE;
    LKey := 'SYSTEM\CurrentControlSet\Services\EventLog\' + FLogName + '\' + FSourceName;
    try
      if LReg.OpenKey(LKey, True) then
      begin
        LReg.WriteInteger('TypesSupported', EVENTLOG_SUCCESS or EVENTLOG_ERROR_TYPE or
          EVENTLOG_WARNING_TYPE or EVENTLOG_INFORMATION_TYPE);
        Result := True;
      end;
    except
      Result := False;  { sem privilegios de administrador - degrada silenciosamente (mesma filosofia do v2.3.0). }
    end;
  finally
    LReg.Free;
  end;
end;

function TLoggerChannelEventLog.OpenSource: Boolean;
begin
  if FHandle <> 0 then
    Exit(True);
  FHandle := RegisterEventSource(nil, PChar(FSourceName));
  if (FHandle = 0) and FAutoCreateSource then
  begin
    if EnsureSourceRegistered then
      FHandle := RegisterEventSource(nil, PChar(FSourceName));
  end;
  Result := FHandle <> 0;
end;

procedure TLoggerChannelEventLog.CloseSource;
begin
  if FHandle <> 0 then
  begin
    try
      DeregisterEventSource(FHandle);
    except
      { ignora erros ao fechar. }
    end;
    FHandle := 0;
  end;
end;

{$ENDIF MSWINDOWS}

function TLoggerChannelEventLog.Write(const AEntry: TLoggerEntry): Boolean;
{$IFDEF MSWINDOWS}
var
  LMessage: string;
  LStrings: array[0..0] of PChar;
{$ENDIF}
begin
  Result := False;
  if not (FReady and FEnabled) then
    Exit;
{$IFDEF MSWINDOWS}
  FLock.Acquire;
  try
    if not OpenSource then
      Exit(False);
    try
      if AEntry.Category <> '' then
        LMessage := '[' + AEntry.Category + '] ' + AEntry.Message
      else
        LMessage := AEntry.Message;
      if AEntry.ExceptionClass <> '' then
        LMessage := LMessage + ' [' + AEntry.ExceptionClass + ': ' + AEntry.ExceptionMessage + ']';
      LStrings[0] := PChar(LMessage);
      Result := ReportEvent(FHandle, EventTypeFor(AEntry.Level), 0,
        1000 + Ord(AEntry.Level), nil, 1, 0, @LStrings[0], nil);
    except
      Result := False;  { canal nunca propaga - fail-over do TLoggerImpl decide o resto. }
    end;
  finally
    FLock.Release;
  end;
{$ENDIF}
end;

{$ENDIF USE_LOGGERS}

end.
