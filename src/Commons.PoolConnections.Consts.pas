{ =============================================================================
  Commons.PoolConnections.Consts - Constantes exclusivas do PoolConnections v3

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  2.0.0
  FileVersion:    1.2.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           10/07/2026

  Defaults do Broker Elastico (Onda 4.3). Regra de hardware do owner: o pool
  opera no maximo em CPU_THRESHOLD por cento dos nucleos; o restante
  (100 - CPU_THRESHOLD = 20 por cento) e reserva INTOCAVEL do Sistema Operativo.

  Changelog (file):
  - 1.2.0 (12/07/2026): bug-164 - DEFAULT_POOL_CONNECT_TIMEOUT_MS (30 s).
  - 1.1.0 (11/07/2026): Onda 4.3b (housekeeper) - DEFAULT_POOL_HOUSEKEEPER_INTERVAL_MS
    e DEFAULT_POOL_SCALEOUT_QUEUE_THRESHOLD.
  - 1.0.0 (10/07/2026): versao inicial (Onda 4.3 Etapa A2).
  ============================================================================= }
unit Commons.PoolConnections.Consts;

{$I ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$IFDEF USE_POOLCONNECTIONS}

const
  DEFAULT_POOL_MIN_SIZE              = 0;
  DEFAULT_POOL_MAX_SIZE_PER_DATABASE = 10;
  DEFAULT_POOL_ACQUIRE_TIMEOUT_MS    = 5000;
  DEFAULT_POOL_IDLE_TIMEOUT_MS       = 300000;
  DEFAULT_POOL_LEAK_WARNING_MS       = 60000;
  { Teto de CPU do pool em % (owner 10/07): 80% para o pool, 20% reservados
    obrigatoriamente para o SO. }
  DEFAULT_POOL_CPU_THRESHOLD         = 80;
  DEFAULT_POOL_WORKERS_PER_CORE      = 2;
  { Housekeeper (Onda 4.3b): cadencia do monitor e gatilho de scale-out
    (fila de aquisicao de um banco acima do threshold = gargalo). }
  DEFAULT_POOL_HOUSEKEEPER_INTERVAL_MS  = 1000;
  DEFAULT_POOL_SCALEOUT_QUEUE_THRESHOLD = 5;
  { Timeout de CRIACAO de worker (bind/connect da fisica) - separado do
    AcquireTimeout (espera por worker LIVRE): arranque frio de SQL Server/
    ODBC + download de DLLs pode exceder folgadamente os 5 s (bug-164). }
  DEFAULT_POOL_CONNECT_TIMEOUT_MS       = 30000;

  { Mensagens do modulo }
  POOL_ERR_ACQUIRE_TIMEOUT_MSG    = 'Pool esgotado: timeout a aguardar conexao livre (banco "%s", %d ms).';
  POOL_ERR_SHUTDOWN_MSG           = 'Pool em shutdown: pedido rejeitado.';
  POOL_ERR_CONFIG_INVALID_MSG     = 'Configuracao de pool invalida: %s';
  POOL_ERR_CONNECTION_INVALID_MSG = 'Conexao invalida no pool: %s';
  POOL_ERR_DB_NOT_REGISTERED_MSG  = 'Banco "%s" nao registado no pool (AddDatabase primeiro).';
  POOL_ERR_HARDWARE_CAP_MSG       = 'Teto global de hardware atingido (%d workers).';
  POOL_ERR_NOT_RECONFIGURABLE_MSG = 'Conexao de pool nao e reconfiguravel (%s) - configure o banco no broker.';

{$ENDIF}

implementation

end.
