{ =============================================================================
  Attributers.Database.Types - Tipos do nucleo RTTI de mapeamento Classe<->ITable

  Absorvido de ProvidersORM v2.3.0 Attributers.Providers.Types.pas (FASE 6
  Onda 6.1) - renomeado Providers->Database: o nome do modulo real que estes
  atributos decoram (regra D5, "Attributers.<Modulo>"), ja antecipado por uma
  nota deixada em Commons.Types.pas na F1 ("... sao (re)criados centralizados
  em Attributers.Database.*"). uses Commons.Types removido (nao usado pelo
  record - limpeza permitida por D2, modernizar na absorcao).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.3.1 (Database - modulo que estes atributos mapeiam)
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.0.0 (03/08/2026): FASE 6 Onda 6.1 - absorvido de Attributers.Providers.Types.pas
    (SSOT v2.2.0), fiel ao original (TFieldMappingInfo/TFieldMappingInfoArray).
  ============================================================================= }

unit Attributers.Database.Types;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

type
  { Informacao de mapeamento propriedade <-> coluna obtida por RTTI ([Field], [PrimaryKey]). }
  TFieldMappingInfo = record
    PropertyName: string;
    ColumnName: string;
    ColumnType: string;
    IsPrimaryKey: Boolean;
  end;

{$IF DEFINED(FPC)}
  TFieldMappingInfoArray = array of TFieldMappingInfo;
{$ELSE}
  TFieldMappingInfoArray = System.TArray<TFieldMappingInfo>;
{$ENDIF}

implementation

end.
