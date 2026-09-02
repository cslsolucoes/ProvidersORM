{ =============================================================================
  PoolConnections.Version - ModuleVersion do modulo PoolConnections

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  2.2.0
  FileVersion:    1.2.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           09/08/2026

  ModuleVersion 2.0.0 (decisao do owner 10/07): redesenho completo como
  Message Broker Elastico (major sobre o 1.0.x do container manual v2.3.0).
  2.1.0 (Onda 4.3b): housekeeper (warm-up/scale-out/scale-in/leaks),
  test-on-borrow, drain de shutdown, ExecuteDirect (passthrough), metricas.
  2.2.0 (F8 Onda 8.6): SetLogger reintroduzido (observabilidade estrutural).

  Changelog (file):
  - 1.2.0 (09/08/2026): F8 Onda 8.6 -- SetLogger no broker (ver
    PoolConnections.pas changelog 1.3.0). Bump aditivo puro.
  - 1.1.0 (11/07/2026): ModuleVersion 2.1.0 (Onda 4.3b - housekeeper).
  - 1.0.0 (10/07/2026): versao inicial (Onda 4.3 Etapa B).
  ============================================================================= }
unit PoolConnections.Version;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

const
  POOLCONNECTIONS_VERSION_MAJOR = 2;
  POOLCONNECTIONS_VERSION_MINOR = 2;
  POOLCONNECTIONS_VERSION_PATCH = 0;
  POOLCONNECTIONS_VERSION       = '2.2.0';
  POOLCONNECTIONS_VERSION_DATE  = '09/08/2026';

  { Forma legivel para logs / About box. }
  POOLCONNECTIONS_VERSION_FULL  = 'PoolConnections ' + POOLCONNECTIONS_VERSION +
                                  ' (' + POOLCONNECTIONS_VERSION_DATE + ')';

implementation

end.
