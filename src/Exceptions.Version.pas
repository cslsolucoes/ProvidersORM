{ =============================================================================
  Exceptions.Version - Versão do MÓDULO Exceptions (runtime)

  Descrição:
  Constantes de versão do módulo Exceptions — nível ModuleVersion, entre o
  ProjectVersion global (Commons.Version = 3.0.0) e o FileVersion de cada ficheiro.
  Módulo v3-nativo (migrado de ProvidersORM v2.2.0 na FASE 2); expõe a versão do
  subsistema Exceptions (Exceptions.Base + catálogo MMXXXX + DDL messages) em runtime.
  Vive na pasta do módulo (src.new/Exceptions/, na raiz — cross-cutting como Commons/).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.2.0
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           01/09/2026

  Changelog (file):
  - 1.1.0 (01/09/2026): F15 Onda 15.1 — ModuleVersion 1.1.0 → 1.2.0. Reflecte a
    reserva da faixa 97 (GraphQL) na tabela canónica de Exceptions.Base (v1.2.0);
    sem alteração de código executável do módulo.
  - 1.0.0 (06/07/2026): versão do módulo Exceptions v3. ModuleVersion 1.1.0 reflecte
    a promoção do ErrorCode à raiz EExceptionBase (06/07) sobre a base migrada em F2.
  ============================================================================= }
unit Exceptions.Version;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

const
  EXCEPTIONS_VERSION_MAJOR = 1;
  EXCEPTIONS_VERSION_MINOR = 2;
  EXCEPTIONS_VERSION_PATCH = 0;
  EXCEPTIONS_VERSION       = '1.2.0';
  EXCEPTIONS_VERSION_DATE  = '01/09/2026';

  { Forma legível para logs / About box. }
  EXCEPTIONS_VERSION_FULL  = 'Exceptions ' + EXCEPTIONS_VERSION +
                             ' (' + EXCEPTIONS_VERSION_DATE + ')';

implementation

end.
