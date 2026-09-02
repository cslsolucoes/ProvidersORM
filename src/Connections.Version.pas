{ =============================================================================
  Connections.Version - Versão do MÓDULO Connections (runtime)

  Descrição:
  Constantes de versão do módulo Connections — nível ModuleVersion, entre o
  ProjectVersion global (Commons.Version = 3.0.0) e o FileVersion de cada
  ficheiro. O módulo foi absorvido de ProvidersORM v2.3.0 (Onda 4.1); esta
  versão de módulo NÃO é redundante com Commons.Version (projeto = 3.0.0).
  Vive na pasta do módulo (Modulos/Connections) para fácil identificação,
  mesmo padrão de ActiveDirectory.Version/Exceptions.Version.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.1.0
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           09/08/2026

  Changelog (file):
  - 1.1.0 (09/08/2026): F8 Onda 8.6 -- SetLogger reintroduzido em
    TConnection (ver Connections.pas changelog 1.9.0). Bump aditivo puro
    (contrato IConnection inalterado - SetLogger e' so' da classe).
  - 1.0.0 (06/07/2026): criado na absorção v3 (Onda 4.1); preserva a versão do
    módulo 1.0.22 (último FileVersion de Providers.Connection.pas em v2.3.0).
  ============================================================================= }
unit Connections.Version;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

const
  CONNECTIONS_VERSION_MAJOR = 1;
  CONNECTIONS_VERSION_MINOR = 1;
  CONNECTIONS_VERSION_PATCH = 0;
  CONNECTIONS_VERSION       = '1.1.0';
  CONNECTIONS_VERSION_DATE  = '09/08/2026';

  { Forma legível para logs / About box. }
  CONNECTIONS_VERSION_FULL  = 'Connections ' + CONNECTIONS_VERSION +
                              ' (' + CONNECTIONS_VERSION_DATE + ')';

implementation

end.
