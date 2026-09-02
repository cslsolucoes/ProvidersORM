{ =============================================================================
  Exceptions.Serialize - Excecoes do modulo Serialize (faixa MM=44)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           13/07/2026

  FASE 5 Onda 9 (placement por peca: excecao -> Exceptions/Exceptions.<Modulo>).
  Faixa 44 (ERR_SERIALIZE_BASE=440000). Substitui EDataSetSerializeException
  (Exception cru, upstream dataset-serialize) por ESerializeException,
  herdando EExceptionBase (ErrorCode na raiz - regra v3; nunca lancar Exception
  cru). O modulo Serialize nao tem gate USE_* proprio (sempre presente, como
  Commons/Exceptions/Connections) - por isso este ficheiro nao envolve o
  conteudo em directiva condicional; so o adapter opcional
  (Serialize.Adapter.RESTRequest4D) e gated por USE_RESTREQUEST4D.

  Changelog (file):
  - 1.0.0 (13/07/2026): versao inicial (FASE 5 Onda 9) - absorcao do
    dataset-serialize; mapeamento 1:1 das constantes de mensagem de
    Serialize.Consts para codigos de erro proprios (FIELD_TYPE_NOT_FOUND,
    DATASET_ACTIVATED, PREDEFINED_FIELDS, DATASET_HAS_NO_DEFINED_FIELDS,
    JSON_NOT_DIFINED, SIZE_NOT_DEFINED_FOR_FIELD,
    TO_CONVERT_STRUCTURE_ONLY_JSON_ARRAY_ALLOWED, INVALID_FIELD_COUNT) +
    ERR_SERIALIZE_GENERIC para as 2 mensagens ad-hoc do LoadFieldStructure
    (ramo Delphi no-FPC).
  ============================================================================= }
unit Exceptions.Serialize;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Exceptions.Base;

const
  ERR_SERIALIZE_BASE                       = 440000;
  ERR_SERIALIZE_GENERIC                    = 440001; // mensagens ad-hoc (nao mapeadas a uma constante propria)
  ERR_SERIALIZE_FIELD_TYPE_NOT_FOUND       = 440002; // TField.DataType sem mapeamento JSON (export/import)
  ERR_SERIALIZE_DATASET_ACTIVATED          = 440003; // LoadStructure exige DataSet inactivo
  ERR_SERIALIZE_PREDEFINED_FIELDS          = 440004; // LoadStructure exige DataSet sem campos predefinidos
  ERR_SERIALIZE_NO_DEFINED_FIELDS          = 440005; // Validate exige DataSet com campos definidos
  ERR_SERIALIZE_JSON_NOT_DEFINED           = 440006; // TJSONSerialize sem JSONObject/JSONArray atribuido
  ERR_SERIALIZE_SIZE_NOT_DEFINED           = 440007; // campo string/wide sem Size definido (NewDataSetField)
  ERR_SERIALIZE_STRUCTURE_JSON_ARRAY_ONLY  = 440008; // LoadStructure so aceita JSONArray
  ERR_SERIALIZE_INVALID_FIELD_COUNT        = 440009; // JSONValueToDataSet exige DataSet com exactamente 1 campo

type
  ESerializeException = class(EExceptionBase);

implementation

end.
