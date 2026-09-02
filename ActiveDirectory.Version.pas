{ =============================================================================
  ActiveDirectory.Version - Versão do MÓDULO ActiveDirectory (runtime)

  Descrição:
  Constantes de versão do módulo ActiveDirectory — nível ModuleVersion, entre o
  ProjectVersion global (Commons.Version = 3.0.0) e o FileVersion de cada ficheiro.
  Expostas para runtime (logs, About box, User-Agent). O módulo foi absorvido do
  standalone ActiveDirectoryORM v1.7.6 (SSOT E:\Dropbox\CSL\ActiveDirectoryORM);
  esta versão de módulo NÃO é redundante com Commons.Version (projeto = 3.0.0).
  Vive na pasta do módulo (Modulos/ActiveDirectory) para fácil identificação.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.9.0
  FileVersion:    1.2.0
  Author:         Claiton de Souza Linhares
  Date:           08/08/2026

  Changelog (file):
  - 1.2.0 (08/08/2026): módulo ActiveDirectory bumpado 1.8.0 -> 1.9.0 (F8 Onda
    8.6 — SetLogger em IActiveDirectoryService/TActiveDirectoryService/
    TServiceLDAP, guardado USE_LOGGERS; bug-1158 — unit Service.pas passa a
    incluir ORM.Defines.inc, ativando ssl_openssl3 pela 1ª vez).
  - 1.1.0 (06/07/2026): módulo ActiveDirectory bumpado 1.7.6 -> 1.8.0 (evolução v3:
    TLDAPConfig->TActiveDirectoryConfig + merge da factory; TLdap*->TActiveDirectory*
    nos results/mapper; mapeador RTTI ativado e cross-compiler; Views migradas).
  - 1.0.0 (06/07/2026): re-criado na absorção v3 (preserva a versão do módulo 1.7.6
    do standalone). Fica em Modulos/ActiveDirectory/ (decisão do owner: version =
    identidade do módulo). Consts ADORM_VERSION_* -> ACTIVEDIRECTORY_VERSION_*.
  ============================================================================= }
unit ActiveDirectory.Version;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

const
  ACTIVEDIRECTORY_VERSION_MAJOR = 1;
  ACTIVEDIRECTORY_VERSION_MINOR = 9;
  ACTIVEDIRECTORY_VERSION_PATCH = 0;
  ACTIVEDIRECTORY_VERSION       = '1.9.0';
  ACTIVEDIRECTORY_VERSION_DATE  = '08/08/2026';

  { Forma legível para logs / About box. }
  ACTIVEDIRECTORY_VERSION_FULL  = 'ActiveDirectory ' + ACTIVEDIRECTORY_VERSION +
                                  ' (' + ACTIVEDIRECTORY_VERSION_DATE + ')';

implementation

end.
