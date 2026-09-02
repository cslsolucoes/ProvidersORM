{ =============================================================================
  Parameters.Version - ModuleVersion do modulo Parameters

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  2.0.0
  FileVersion:    2.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           16/07/2026

  ModuleVersion do modulo Parameters (FASE 7) = PROXIMA MAJOR na linhagem do
  ParametersORM standalone (decisao do owner 16/07). O standalone esta em 1.0.7
  (src/Commons/Parameters.Version.pas); o v3 e uma reescrita MAJOR incompativel
  (B-freeze, refactor total de nomenclatura CRUD Select/Insert/Update/Delete,
  define USE_PARAMETERS) -> bump de major -> 2.0.0. NAO usa o 3.0.0 do produto
  ProvidersORM nem a numeracao propria do modulo Database. As ondas da FASE 7
  incrementam a MINOR/PATCH a partir de 2.0.0.

  Changelog (file):
  - 2.0.0 (16/07/2026): versao inicial do modulo Parameters no v3 - proxima major
    da linhagem ParametersORM (1.0.7 -> 2.0.0). FASE 7, Onda 7.2.a.
  ============================================================================= }

unit Parameters.Version;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

const
  PARAMETERS_VERSION_MAJOR = 2;
  PARAMETERS_VERSION_MINOR = 0;
  PARAMETERS_VERSION_PATCH = 0;
  PARAMETERS_VERSION       = '2.0.0';
  PARAMETERS_VERSION_DATE  = '16/07/2026';

  { Forma legivel para logs / About box. }
  PARAMETERS_VERSION_FULL  = 'Parameters ' + PARAMETERS_VERSION +
                             ' (' + PARAMETERS_VERSION_DATE + ')';

implementation

end.
