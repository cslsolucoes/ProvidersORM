{ =============================================================================
  Attributers.Database.Consts - Constantes do nucleo RTTI de mapeamento Classe<->ITable

  Absorvido de ProvidersORM v2.3.0 Attributers.Providers.Consts.pas (FASE 6
  Onda 6.1) - renomeado Providers->Database (regra D5; ver nota do mesmo
  racional em Attributers.Database.Types.pas).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.3.1 (Database - modulo que estes atributos mapeiam)
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.0.0 (03/08/2026): FASE 6 Onda 6.1 - absorvido de Attributers.Providers.Consts.pas
    (SSOT v2.2.0), fiel ao original (DEFAULT_FIELD_SIZE, DEFAULT_SCHEMA).
  ============================================================================= }

unit Attributers.Database.Consts;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

const
  { Tamanho padrao para colunas string quando nao inferido por RTTI. }
  DEFAULT_FIELD_SIZE = 255;

  { Schema padrao quando [Table('nome')] nao informa schema. }
  DEFAULT_SCHEMA = '';

implementation

end.
