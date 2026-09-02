{ =============================================================================
  PoolConnections.Queue - Fila Multithread do Broker (TPoolQueue)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  2.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           10/07/2026

  Fila FIFO thread-safe de TPoolRequest (a "mensagem" do broker):
  TCriticalSection + TEvent manual-reset ("ha itens OU fechada"). Push por
  produtores (proxies via broker); Pop bloqueante com deadline pelas Worker
  Threads. Close acorda TODOS os consumidores para shutdown gracioso.

  Changelog (file):
  - 1.0.0 (10/07/2026): versao inicial (Onda 4.3 Etapa B).
  ============================================================================= }
unit PoolConnections.Queue;

{$I ../../ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$IFDEF USE_POOLCONNECTIONS}

uses
{$IFDEF FPC}
  SysUtils, Classes, SyncObjs,
{$ELSE}
  Winapi.Windows, // GetTickCount64
  System.SysUtils, System.Classes, System.SyncObjs,
{$ENDIF}
  Commons.PoolConnections.Types;

type
  TPoolQueue = class
  strict private
    FLock   : TCriticalSection;
    FItems  : TList;   // of TPoolRequest (FIFO: 0 = mais antigo)
    FSignal : TEvent;  // manual-reset: "ha itens OU fila fechada"
    FClosed : Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    { Enfileira (False se a fila ja fechou - caller mantem a posse do request). }
    function Push(const AReq: TPoolRequest): Boolean;
    { Retira o mais antigo; bloqueia ate ATimeoutMs (INFINITE = -1).
      False = timeout OU fila fechada e vazia. }
    function Pop(out AReq: TPoolRequest; const ATimeoutMs: Integer): Boolean;
    function Count: Integer;
    { Fecha a fila e acorda todos os consumidores (shutdown gracioso). }
    procedure Close;
    function IsClosed: Boolean;
  end;

{$ENDIF}

implementation

{$IFDEF USE_POOLCONNECTIONS}

constructor TPoolQueue.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FItems := TList.Create;
  FSignal := TEvent.Create(nil, True, False, ''); // manual-reset
  FClosed := False;
end;

destructor TPoolQueue.Destroy;
begin
  Close;
  FItems.Free;
  FSignal.Free;
  FLock.Free;
  inherited;
end;

function TPoolQueue.Push(const AReq: TPoolRequest): Boolean;
begin
  FLock.Acquire;
  try
    if FClosed then
      Exit(False);
    FItems.Add(AReq);
    FSignal.SetEvent;
    Result := True;
  finally
    FLock.Release;
  end;
end;

function TPoolQueue.Pop(out AReq: TPoolRequest; const ATimeoutMs: Integer): Boolean;
var
  LDeadline: UInt64;
  LRemaining: Integer;
begin
  AReq := nil;
  Result := False;
  if ATimeoutMs < 0 then
    LDeadline := High(UInt64)
  else
    LDeadline := GetTickCount64 + UInt64(ATimeoutMs);
  repeat
    FLock.Acquire;
    try
      if FItems.Count > 0 then
      begin
        AReq := TPoolRequest(FItems[0]);
        FItems.Delete(0);
        { esvaziou e continua aberta -> proximos Pop esperam }
        if (FItems.Count = 0) and (not FClosed) then
          FSignal.ResetEvent;
        Exit(True);
      end;
      if FClosed then
        Exit(False); // fechada e vazia (sinal fica set p/ acordar os restantes)
      FSignal.ResetEvent;
    finally
      FLock.Release;
    end;
    if LDeadline = High(UInt64) then
      FSignal.WaitFor(250) // fatias: permite Terminated-check no consumidor
    else
    begin
      LRemaining := Integer(Int64(LDeadline) - Int64(GetTickCount64));
      if LRemaining <= 0 then
        Exit(False);
      if LRemaining > 250 then
        LRemaining := 250;
      FSignal.WaitFor(LRemaining);
    end;
  until False;
end;

function TPoolQueue.Count: Integer;
begin
  FLock.Acquire;
  try
    Result := FItems.Count;
  finally
    FLock.Release;
  end;
end;

procedure TPoolQueue.Close;
begin
  FLock.Acquire;
  try
    FClosed := True;
    FSignal.SetEvent; // acorda TODOS (manual-reset fica set)
  finally
    FLock.Release;
  end;
end;

function TPoolQueue.IsClosed: Boolean;
begin
  FLock.Acquire;
  try
    Result := FClosed;
  finally
    FLock.Release;
  end;
end;

{$ENDIF}

end.
