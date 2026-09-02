{ =============================================================================
  Loggers.Channel.Memory - Canal Memory (ring-buffer in-memory, F8 Onda 8.4.7)

  TLoggerChannelMemory: implementa ILoggerChannel sobre um ring-buffer
  puramente em memoria (sem I/O de disco/rede/BD nas escritas - so' a
  LoadConfig toca o Parameters, como todos os outros canais). Mesmo molde
  estrutural do canal Console (TInterfacedObject, ILoggerChannel; FLock com o
  fix bug-659 para FPC - qualificar SyncObjs.TCriticalSection.Create so' no
  ramo FPC); canal UNIVERSAL sem restricao de plataforma - segue o padrao
  ELSE-com-defaults ja usado por Console/Json/CSV (LoadConfig nunca deixa o
  canal permanentemente morto so' por falta de fonte de configuracao viva).

  Guarda as ULTIMAS N entradas (N = config Capacity, default 1000) num array
  circular (FItems/FHead/FCount) - eviccao FIFO em O(1) quando cheio, sem o
  custo de Delete(0) de um TList<T> convencional. Nao reusa Loggers.Queue
  (TLoggerQueue): aquela e' uma fila de ENTREGA transitoria consumida pelo
  worker assincrono (Pop remove o item); este canal e' um buffer de LEITURA
  retido - proposito e ciclo de vida diferentes, nao e' o mesmo mecanismo.

  ILoggerChannel nao expoe leitura (contrato minimo Write/Name/Enabled/
  Health) - por isso este canal acrescenta 3 metodos CONCRETOS (Snapshot/
  Count/Clear), so' acessiveis por quem detem a referencia concreta
  TLoggerChannelMemory (consumidores/testes que querem inspecionar o
  historico recente sem tocar disco).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.12.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           31/07/2026

  Changelog (file):
  - 1.0.0 (31/07/2026): criação — FASE 8 Onda 8.4.7 (canal Memory, 10º canal
    baseline). Sem equivalente direto no LoggersORM v2.3.0/QuickLogger (novo
    canal do v3) - motivado por dar acesso in-process instantâneo às últimas
    N entradas (ex.: painel de diagnóstico embutido, health-check) sem
    depender de nenhum canal de I/O.
  ============================================================================= }

unit Loggers.Channel.Memory;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../ORM.Defines.inc}

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
  TLoggerChannelMemory = class(TInterfacedObject, ILoggerChannel)
  strict private
    FLock     : TCriticalSection;
    FEnabled  : Boolean;
    FReady    : Boolean;   // sempre True apos LoadConfig - canal universal, sem restricao de plataforma.
    FCapacity : Integer;
    FItems    : array of TLoggerEntry;  // buffer circular, tamanho fixo = FCapacity apos o Create.
    FHead     : Integer;   // indice da entrada mais ANTIGA dentro de FItems.
    FCount    : Integer;   // nº de entradas validas (0..FCapacity).
    procedure LoadConfig;
  public
    constructor Create;
    destructor Destroy; override;
    function Name: string;
    function Write(const AEntry: TLoggerEntry): Boolean;
    function Enabled: Boolean; overload;
    function Enabled(const AValue: Boolean): ILoggerChannel; overload;
    function IsHealthy: Boolean;

    { Leitura concreta - fora do contrato ILoggerChannel (que nao expoe
      leitura), disponivel a quem detem a referencia TLoggerChannelMemory. }
    function Snapshot: TArray<TLoggerEntry>;  // copia das entradas por ordem cronologica (mais antiga primeiro).
    function Count: Integer;
    procedure Clear;
  end;

{$ENDIF USE_LOGGERS}

implementation

{$IFDEF USE_LOGGERS}

{$IF DEFINED(USE_LOGGERS_MEMORY) AND DEFINED(USE_PARAMETERS)}
  {$DEFINE LOGGERS_MEM_CHANNEL_ACTIVE}
{$ENDIF}

uses
  Commons.Loggers.Consts,  { sempre em scope - os DEFAULT_LOGGERS_MEMORY_* nao dependem de USE_PARAMETERS. }
{$IFDEF LOGGERS_MEM_CHANNEL_ACTIVE}
  Commons.Types,              // TParameter
  Parameters.Interfaces,
  Parameters,
{$ENDIF}
  Loggers.Version;  { mantem a unit no uses mesmo sem LOGGERS_MEM_CHANNEL_ACTIVE, evita warning de uses vazio. }

constructor TLoggerChannelMemory.Create;
begin
  inherited Create;
{$IFDEF FPC}
  FLock := SyncObjs.TCriticalSection.Create;  { Windows.pp tambem declara TCriticalSection (struct WinAPI) - qualificar evita a resolucao errada (bug real FPC 3.3.1, mesmo fix dos canais EventLog/Console). }
{$ELSE}
  FLock := TCriticalSection.Create;
{$ENDIF}
  FEnabled := False;
  FReady := False;
  FCapacity := 1000;
  FHead := 0;
  FCount := 0;
  LoadConfig;  { pode ajustar FCapacity antes do array ser dimensionado abaixo. }
  SetLength(FItems, FCapacity);
end;

destructor TLoggerChannelMemory.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TLoggerChannelMemory.Name: string;
begin
  Result := 'Memory';
end;

function TLoggerChannelMemory.Enabled: Boolean;
begin
  FLock.Acquire;
  try
    Result := FEnabled and FReady;
  finally
    FLock.Release;
  end;
end;

function TLoggerChannelMemory.Enabled(const AValue: Boolean): ILoggerChannel;
begin
  FLock.Acquire;
  try
    FEnabled := AValue;
  finally
    FLock.Release;
  end;
  Result := Self;
end;

function TLoggerChannelMemory.IsHealthy: Boolean;
begin
  Result := Enabled;
end;

{$IFDEF LOGGERS_MEM_CHANNEL_ACTIVE}

procedure TLoggerChannelMemory.LoadConfig;
var
  LParams: IParameters;
  LSource: IParametersDatabase;

  function Read(const ATitulo, AChave, ADefault: string): string;
  var
    LVal: TParameter;
  begin
    LSource.Title(ATitulo);
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

  FEnabled := SameText(Read(LOGGERS_TITULO_MEMORY, LOGGERS_MEMORY_ENABLED, DEFAULT_LOGGERS_MEMORY_ENABLED), 'True');
  FCapacity := StrToIntDef(Read(LOGGERS_TITULO_MEMORY, LOGGERS_MEMORY_CAPACITY, DEFAULT_LOGGERS_MEMORY_CAPACITY), 1000);
  if FCapacity <= 0 then
    FCapacity := 1000;  { config invalida/zero - fail-safe para o default, nunca um buffer de tamanho zero (div/mod por zero). }

  FReady := True;
end;

{$ELSE}

procedure TLoggerChannelMemory.LoadConfig;
begin
  { USE_LOGGERS_MEMORY/USE_PARAMETERS em falta - sem fonte de config viva, mas
    o canal continua PRONTO a acumular com defaults fixos (mesmo padrao
    ELSE-com-defaults do Console/Json/CSV) - universal, sem restricao de
    plataforma que o obrigue a ficar permanentemente inerte. }
  FEnabled := SameText(DEFAULT_LOGGERS_MEMORY_ENABLED, 'True');
  FCapacity := StrToIntDef(DEFAULT_LOGGERS_MEMORY_CAPACITY, 1000);
  if FCapacity <= 0 then
    FCapacity := 1000;
  FReady := True;
end;

{$ENDIF LOGGERS_MEM_CHANNEL_ACTIVE}

function TLoggerChannelMemory.Write(const AEntry: TLoggerEntry): Boolean;
begin
  Result := False;
  if not (FReady and FEnabled) then
    Exit;
  FLock.Acquire;
  try
    try
      if FCount < FCapacity then
      begin
        FItems[(FHead + FCount) mod FCapacity] := AEntry;
        Inc(FCount);
      end
      else
      begin
        { buffer cheio - descarta a mais antiga (FHead) e avanca o inicio. }
        FItems[FHead] := AEntry;
        FHead := (FHead + 1) mod FCapacity;
      end;
      Result := True;
    except
      Result := False;  { canal nunca propaga - fail-over do nucleo decide. }
    end;
  finally
    FLock.Release;
  end;
end;

function TLoggerChannelMemory.Snapshot: TArray<TLoggerEntry>;
var
  I: Integer;
begin
  FLock.Acquire;
  try
    SetLength(Result, FCount);
    for I := 0 to FCount - 1 do
      Result[I] := FItems[(FHead + I) mod FCapacity];
  finally
    FLock.Release;
  end;
end;

function TLoggerChannelMemory.Count: Integer;
begin
  FLock.Acquire;
  try
    Result := FCount;
  finally
    FLock.Release;
  end;
end;

procedure TLoggerChannelMemory.Clear;
begin
  FLock.Acquire;
  try
    FHead := 0;
    FCount := 0;
  finally
    FLock.Release;
  end;
end;

{$ENDIF USE_LOGGERS}

end.
