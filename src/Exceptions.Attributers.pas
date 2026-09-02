{ =============================================================================
  Exceptions.Attributers - Excecoes do modulo Attributers (faixa MM=60)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  FASE 6 Onda 6.1. Faixa ja alocada em Exceptions.Base:
  ERR_ATTRIBUTERS_BASE = 600000 (600001..609999). ErrorCode vive na raiz
  EExceptionBase (de-dup transversal - regra 6 do plano principal). Absorvido
  de ProvidersORM v2.3.0 Attributers.Providers.Exceptions.pas - placement
  corrigido (exceção => pasta Exceptions/, nunca dentro de Attributers/) e
  numeracao modernizada para o esquema MMXXXX do v3 (a fonte usava 60001/60002
  de 5 digitos, incompativel com a faixa 600000 ja reservada).

  Changelog (file):
  - 1.0.0 (03/08/2026): versao inicial (FASE 6 Onda 6.1) - EAttributersException
    + ERR_ATTRIBUTERS_NO_TABLE_ATTRIBUTE/ERR_ATTRIBUTERS_RTTI_NOT_AVAILABLE.
  ============================================================================= }
unit Exceptions.Attributers;

{$I ../ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$IFDEF USE_ATTRIBUTES}

uses
{$IFDEF FPC}
  SysUtils,
{$ELSE}
  System.SysUtils,
{$ENDIF}
  Exceptions.Base;

const
  ERR_ATTRIBUTERS_NO_TABLE_ATTRIBUTE = ERR_ATTRIBUTERS_BASE + 1; // 600001
  ERR_ATTRIBUTERS_RTTI_NOT_AVAILABLE = ERR_ATTRIBUTERS_BASE + 2; // 600002

type
  { Raiz das excecoes do modulo Attributers; herda ErrorCode de EExceptionBase. }
  EAttributersException = class(EExceptionBase);

{$ENDIF}

implementation

end.
