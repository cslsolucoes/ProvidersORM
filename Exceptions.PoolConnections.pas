{ =============================================================================
  Exceptions.PoolConnections - Excecoes do modulo PoolConnections (faixa MM=45)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  2.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           10/07/2026

  Broker Elastico (Onda 4.3). Faixa ja alocada em Exceptions.Base:
  ERR_POOLCONNECTIONS_BASE = 450000 (450001..459999). ErrorCode vive na raiz
  EExceptionBase (de-dup transversal - regra 6 do plano principal).

  Changelog (file):
  - 1.0.0 (10/07/2026): versao inicial (Onda 4.3 Etapa A2).
  ============================================================================= }
unit Exceptions.PoolConnections;

{$I ../ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$IFDEF USE_POOLCONNECTIONS}

uses
{$IFDEF FPC}
  SysUtils,
{$ELSE}
  System.SysUtils,
{$ENDIF}
  Exceptions.Base;

const
  ERR_POOL_ACQUIRE_TIMEOUT       = ERR_POOLCONNECTIONS_BASE + 1; // 450001
  ERR_POOL_SHUTDOWN              = ERR_POOLCONNECTIONS_BASE + 2; // 450002
  ERR_POOL_CONFIG_INVALID        = ERR_POOLCONNECTIONS_BASE + 3; // 450003
  ERR_POOL_CONNECTION_INVALID    = ERR_POOLCONNECTIONS_BASE + 4; // 450004
  ERR_POOL_DATABASE_NOT_REGISTERED = ERR_POOLCONNECTIONS_BASE + 5; // 450005
  ERR_POOL_HARDWARE_CAP          = ERR_POOLCONNECTIONS_BASE + 6; // 450006

type
  { Raiz das excecoes do pool; herda ErrorCode de EExceptionBase. }
  EPoolConnectionsException = class(EExceptionBase);

  { Timeout de aquisicao (espera pacifica esgotou AcquireTimeoutMs). }
  EPoolAcquireTimeoutException = class(EPoolConnectionsException);

{$ENDIF}

implementation

end.
