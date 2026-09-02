{ =============================================================================
  Serialize.Consts - Constantes de mensagem/propriedade do modulo Serialize

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           13/07/2026

  Absorvido de FontesReferencias/dataset-serialize/src/DataSet.Serialize.Consts.pas
  (namespace DataSet.Serialize.Consts -> Serialize.Consts). Conteudo verbatim
  (mensagens de erro + nomes de propriedade JSON da estrutura SaveStructure/
  LoadStructure) - mantem a coesao da lib no modulo (nao migrado para Commons).

  Changelog (file):
  - 1.0.0 (13/07/2026): versao inicial (FASE 5 Onda 9) - absorcao TOTAL do
    dataset-serialize, header v3.
  ============================================================================= }
unit Serialize.Consts;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}{$H+}
{$ENDIF}

interface

const
  FIELD_TYPE_NOT_FOUND = 'Cannot find type for field "%s"';
  DATASET_ACTIVATED = 'The DataSet can not be active.';
  PREDEFINED_FIELDS = 'The DataSet can not have predefined fields';
  DATASET_HAS_NO_DEFINED_FIELDS = 'DataSet has no defined fields';
  JSON_NOT_DIFINED = 'JSON not defined';
  SIZE_NOT_DEFINED_FOR_FIELD = 'Size not defined for field "%s".';
  TO_CONVERT_STRUCTURE_ONLY_JSON_ARRAY_ALLOWED = 'To convert a structure only JSONArray is allowed';
  INVALID_FIELD_COUNT = '[%s] Invalid field count';

  FIELD_PROPERTY_ALIGNMENT = 'alignment';
  FIELD_PROPERTY_FIELD_NAME = 'fieldName';
  FIELD_PROPERTY_DISPLAY_LABEL = 'displayLabel';
  FIELD_PROPERTY_DATA_TYPE = 'dataType';
  FIELD_PROPERTY_SIZE = 'size';
  FIELD_PROPERTY_KEY = 'key';
  FIELD_PROPERTY_ORIGIN = 'origin';
  FIELD_PROPERTY_REQUIRED = 'required';
  FIELD_PROPERTY_VISIBLE = 'visible';
  FIELD_PROPERTY_READ_ONLY = 'readOnly';
  FIELD_PROPERTY_AUTO_GENERATE_VALUE = 'autoGenerateValue';
  FIELD_PROPERTY_PRECISION = 'precision';

implementation

end.
