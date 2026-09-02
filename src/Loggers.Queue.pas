{ =============================================================================
  Loggers.Queue - Fila thread-safe assíncrona do módulo Loggers

  TLoggerQueue: FIFO thread-safe usando TList<TLoggerEntry> (genérico).
  TCriticalSection + TEvent (manual-reset). Capacidade configurável,
  política de bloqueio quando cheia.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.10.0
  FileVersion:    1.1.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           21/07/2026

  Changelog (file):
  - 1.1.0 (27/07/2026): F8 Onda 8.9 (hardening pos-auditoria) - C7: removido o metodo PopMultiple (dead code, nenhum consumidor no projeto). ModuleVersion do modulo 1.9.0->1.10.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.9.0 - F8 Onda 8.4.5 acrescenta o canal TLoggerChannelWebSocket (8o canal baseline, 3o real sobre ICS, resolve P2); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.9.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.8.0 - F8 Onda 8.4.4 acrescenta o canal TLoggerChannelEmail (7o canal baseline, 2o real sobre ICS); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.8.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.7.0 - F8 Onda 8.4.3 acrescenta o canal TLoggerChannelHttp (6o canal baseline, 1o real sobre ICS); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.7.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.6.0 - F8 Onda 8.4.2 acrescenta o canal TLoggerChannelCSV (5o canal baseline); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.6.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.5.0 - F8 Onda 8.4.1 acrescenta o canal TLoggerChannelEventLog (Windows Event Log, 4o canal baseline); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.5.0.
  - (sync 22/07/2026) ModuleVersion sincronizado para 1.4.0 - Loggers.Database.pas removeu a dependencia de IPoolConnections/TPoolBroker (conexao propria, direta), decisao de arquitectura do owner ('o Loggers via consumir sem pool direto o Connections'); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.4.0.
  - 1.0.0 (21/07/2026): FASE 8 Onda 8.1 — TLoggerQueue (FIFO, manual-reset,
    capacidade + callback flush periódico).
  ============================================================================= }

unit Loggers.Queue;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../ORM.Defines.inc}

{$IFDEF USE_LOGGERS}

uses
{$IFDEF FPC}
  SysUtils, Classes, Generics.Collections, SyncObjs,
{$ELSE}
  System.SysUtils, System.Classes, System.Generics.Collections, System.SyncObjs,
  Winapi.Windows,
{$ENDIF}
  Commons.Loggers.Types;

type
  { Fila FIFO thread-safe de TLoggerEntry. Capacidade máxima, política de
    bloqueio quando cheia. }
  TLoggerQueue = class
  strict private
    FLock      : TCriticalSection;
    FItems     : TList<TLoggerEntry>;
    FSignal    : TEvent;  // manual-reset: "há itens OU fila fechada"
    FClosed    : Boolean;
    FMaxSize   : Integer;
  public
    constructor Create(const AMaxSize: Integer = 10000);
    destructor Destroy; override;

    { Enfileira (False se cheia + política bloqueio/descarte). }
    function Push(const AEntry: TLoggerEntry): Boolean;

    { Retira o mais antigo. Bloqueia até ATimeoutMs (INFINITE = -1).
      False = timeout OU fila fechada e vazia. }
    function Pop(out AEntry: TLoggerEntry; const ATimeoutMs: Integer): Boolean;

    function Count: Integer;

    { Fecha a fila (shutdown gracioso). Acordam todos os consumidores. }
    procedure Close;

    function IsClosed: Boolean;
  end;

{$ENDIF USE_LOGGERS}

implementation

{$IFDEF USE_LOGGERS}

constructor TLoggerQueue.Create(const AMaxSize: Integer);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FItems := TList<TLoggerEntry>.Create;
  FSignal := TEvent.Create(nil, True, False, '');  // manual-reset
  FClosed := False;
  FMaxSize := AMaxSize;
  if FMaxSize <= 0 then FMaxSize := 10000;
end;

destructor TLoggerQueue.Destroy;
begin
  Close;
  FItems.Free;
  FSignal.Free;
  FLock.Free;
  inherited;
end;

function TLoggerQueue.Push(const AEntry: TLoggerEntry): Boolean;
begin
  FLock.Acquire;
  try
    if FClosed then
      Exit(False);
    { Política simples: se cheia, bloqueia o push (fail-safe para não perder). }
    while FItems.Count >= FMaxSize do
    begin
      FLock.Release;
      Sleep(10);  { Yield curto, espera que um Pop esvazie. }
      FLock.Acquire;
      if FClosed then
        Exit(False);
    end;
    FItems.Add(AEntry);
    FSignal.SetEvent;
    Result := True;
  finally
    FLock.Release;
  end;
end;

function TLoggerQueue.Pop(out AEntry: TLoggerEntry; const ATimeoutMs: Integer): Boolean;
var
  LDeadline: UInt32;
  LRemaining: Integer;
begin
  AEntry := Default(TLoggerEntry);
  Result := False;
  if ATimeoutMs < 0 then
    LDeadline := High(UInt32)
  else
    LDeadline := GetTickCount + UInt32(ATimeoutMs);

  repeat
    FLock.Acquire;
    try
      if FItems.Count > 0 then
      begin
        AEntry := FItems[0];
        FItems.Delete(0);
        { Se esvaziou e não está fechada, reseta o sinal. }
        if (FItems.Count = 0) and (not FClosed) then
          FSignal.ResetEvent;
        Exit(True);
      end;
      if FClosed then
        Exit(False);  { Fechada e vazia. }
      FSignal.ResetEvent;
    finally
      FLock.Release;
    end;

    { Espera pacífica com fatias. }
    if LDeadline = High(UInt32) then
      FSignal.WaitFor(250)
    else
    begin
      LRemaining := Integer(Int32(LDeadline) - Int32(GetTickCount));
      if LRemaining <= 0 then
        Exit(False);
      if LRemaining > 250 then
        LRemaining := 250;
      FSignal.WaitFor(LRemaining);
    end;
  until False;
end;

function TLoggerQueue.Count: Integer;
begin
  FLock.Acquire;
  try
    Result := FItems.Count;
  finally
    FLock.Release;
  end;
end;

procedure TLoggerQueue.Close;
begin
  FLock.Acquire;
  try
    FClosed := True;
    FSignal.SetEvent;  { Acorda TODOS (manual-reset fica set). }
  finally
    FLock.Release;
  end;
end;

function TLoggerQueue.IsClosed: Boolean;
begin
  FLock.Acquire;
  try
    Result := FClosed;
  finally
    FLock.Release;
  end;
end;

{$ENDIF USE_LOGGERS}

end.
