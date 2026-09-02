{ =============================================================================
  Printers.Version - Versão do MÓDULO Printers (runtime)

  Descrição:
  Constantes de versão do módulo Printers — nível ModuleVersion, entre o
  ProjectVersion global (Commons.Version = 3.0.0) e o FileVersion de cada
  ficheiro. O módulo v2.3.0 não tinha ModuleVersion próprio (introduzido só
  no refactor v3); arranca em 1.0.0 na Onda 9.0 (contrato IReportProvider).
  Vive na pasta do módulo (Modulos/Printers), mesmo padrão de
  Connections.Version/Database.Version/Exceptions.Version.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.0.0 (03/08/2026): criado na Onda 9.0 (contrato IReportProvider,
    Printers.Interfaces.pas) — primeiro artefacto v3 do módulo Printers.
  ============================================================================= }
unit Printers.Version;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

const
  PRINTERS_VERSION_MAJOR = 1;
  PRINTERS_VERSION_MINOR = 0;
  PRINTERS_VERSION_PATCH = 0;
  PRINTERS_VERSION       = '1.0.0';
  PRINTERS_VERSION_DATE  = '03/08/2026';

  { Forma legível para logs / About box. }
  PRINTERS_VERSION_FULL  = 'Printers ' + PRINTERS_VERSION +
                            ' (' + PRINTERS_VERSION_DATE + ')';

implementation

end.
