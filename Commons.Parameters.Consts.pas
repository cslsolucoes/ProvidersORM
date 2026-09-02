unit Commons.Parameters.Consts;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

{ =============================================================================
  Commons.Parameters.Consts - Constantes INTERNAS do modulo Parameters (D11)

  Regra de ouro: Commons.<Servico> = publico/transversal; Commons.<Modulo>.<Servico>
  = exclusivo interno. Aqui fica SO o que nao aparece na API publica nem e usado
  por outro modulo: limites de validacao, flags de comportamento e defaults de dados.

  Publico -> Commons.Consts (DEFAULT_PARAMETERS_TABLE, ParameterValueTypeNames,
  DEFAULT_PARAMETER_SOURCE/VALUE_TYPE/CONFIG*/PRIORITY, mensagens PARAMETER_*).
  Tipos   -> Commons.Types (TParameter/Source/SourceArray/Config/ValueType/List).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           04/07/2026

  Changelog (file):
  - 1.1.0 (04/07/2026): D11 criterio API-publica. Movido para Commons.Consts o bloco
    publico (tabela config, ParameterValueTypeNames, SOURCE/VALUE_TYPE/CONFIG*/PRIORITY,
    mensagens PARAMETER_*); tipos para Commons.Types. Removido uses
  Commons.Parameters.Types.
    DEFAULT_PARAMETERS_TABLE_NAME eliminado (redundante com Commons.Consts.DEFAULT_PARAMETERS_TABLE).
  - 1.0.0 (04/07/2026): migrado para o v3 (plano F1 Onda 1.2).
  ============================================================================= }

interface

{$I ../ORM.Defines.inc}

const

  { Auto-criar o ficheiro de config quando ausente (fontes INI/JSON) - interno. }
  DEFAULT_PARAMETERS_AUTO_CREATE_FILE = True;

  { Limites de campo (validacao interna). }
  MAX_PARAMETER_NAME_LENGTH        = 255;
  MAX_PARAMETER_VALUE_LENGTH       = 65535;
  MAX_PARAMETER_DESCRIPTION_LENGTH = 1000;

  { Comportamento de ordenacao/importacao (interno). }
  DEFAULT_PARAMETER_AUTO_REORDER_ON_INSERT        = True;
  DEFAULT_PARAMETER_AUTO_RENUMBER_ZERO_ORDER      = True;
  DEFAULT_PARAMETER_AUTO_REORDER_ON_UPDATE        = True;
  DEFAULT_PARAMETER_IMPORT_OVERWRITE_EXISTING     = False;
  DEFAULT_PARAMETER_IMPORT_ALLOW_SILENT_OVERWRITE = True;

  { ORDER BY interno das consultas de parametros. }
  DEFAULT_PARAMETER_ORDER_BY = 'contrato_id, produto_id, titulo, ordem';

  { Defaults de contrato/produto/ordem de um parametro (dados). }
  DEFAULT_CONTRATO_ID     = 1;
  DEFAULT_PRODUTO_ID      = 1;
  DEFAULT_PARAMETER_ORDER = 0;

implementation

end.
