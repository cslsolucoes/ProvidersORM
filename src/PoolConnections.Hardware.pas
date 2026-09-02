{ =============================================================================
  PoolConnections.Hardware - Analise de hardware do Broker (Consciencia de HW)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  2.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           10/07/2026

  A unit que analisa o hardware (pedido do owner 10/07): le
  TThread.ProcessorCount UMA vez (cache) e aplica a regra 80/20 — o pool opera
  no maximo em CPUThreshold por cento dos nucleos; os restantes sao RESERVA
  INTOCAVEL do Sistema Operativo (I/O, rede, estabilidade). O teto global de
  Worker Threads deriva deste limite. Se outro modulo vier a precisar de
  introspecao de hardware, promover a Commons (regra D11 retroactiva).

  Changelog (file):
  - 1.0.0 (10/07/2026): versao inicial (Onda 4.3 Etapa B).
  ============================================================================= }
unit PoolConnections.Hardware;

{$I ../../ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$IFDEF USE_POOLCONNECTIONS}

uses
{$IFDEF FPC}
  Classes, Math,
{$ELSE}
  System.Classes, System.Math,
{$ENDIF}
  Commons.PoolConnections.Types,
  Commons.PoolConnections.Consts;

type
  TPoolHardware = class
  strict private
    class var FProcessorCount: Integer; // cache (0 = por ler)
  public
    { Nucleos logicos da maquina (TThread.ProcessorCount, cacheado). }
    class function ProcessorCount: Integer;
    { Nucleos disponiveis para o pool: Max(1, Trunc(PC * threshold/100)). }
    class function CoresForPool(
      const ACPUThreshold: Integer = DEFAULT_POOL_CPU_THRESHOLD): Integer;
    { A reserva intocavel do SO (PC - CoresForPool). }
    class function ReservedForOS(
      const ACPUThreshold: Integer = DEFAULT_POOL_CPU_THRESHOLD): Integer;
    { Teto GLOBAL de Worker Threads simultaneas do broker. }
    class function GlobalWorkerCap(
      const ACPUThreshold: Integer = DEFAULT_POOL_CPU_THRESHOLD;
      const AWorkersPerCore: Integer = DEFAULT_POOL_WORKERS_PER_CORE): Integer;
    { Snapshot para metricas/dashboard (4.4). }
    class function GetInfo(const AConfig: TPoolConfig): TPoolHardwareInfo;
  end;

{$ENDIF}

implementation

{$IFDEF USE_POOLCONNECTIONS}

class function TPoolHardware.ProcessorCount: Integer;
begin
  if FProcessorCount <= 0 then
    FProcessorCount := TThread.ProcessorCount;
  Result := FProcessorCount;
end;

class function TPoolHardware.CoresForPool(const ACPUThreshold: Integer): Integer;
begin
  Result := Max(1, Trunc(ProcessorCount * ACPUThreshold / 100));
end;

class function TPoolHardware.ReservedForOS(const ACPUThreshold: Integer): Integer;
begin
  Result := ProcessorCount - CoresForPool(ACPUThreshold);
end;

class function TPoolHardware.GlobalWorkerCap(const ACPUThreshold: Integer;
  const AWorkersPerCore: Integer): Integer;
begin
  Result := CoresForPool(ACPUThreshold) * Max(1, AWorkersPerCore);
end;

class function TPoolHardware.GetInfo(const AConfig: TPoolConfig): TPoolHardwareInfo;
begin
  Result.ProcessorCount  := ProcessorCount;
  Result.CoresForPool    := CoresForPool(AConfig.CPUThreshold);
  Result.ReservedForOS   := ReservedForOS(AConfig.CPUThreshold);
  Result.GlobalWorkerCap := GlobalWorkerCap(AConfig.CPUThreshold, AConfig.WorkersPerCoreFactor);
end;

{$ENDIF}

end.
