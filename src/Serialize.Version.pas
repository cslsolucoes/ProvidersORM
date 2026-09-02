{ =============================================================================
  Serialize.Version - ModuleVersion do modulo Serialize

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.1.1
  FileVersion:    1.1.1
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           15/07/2026

  ModuleVersion do modulo Serialize (FASE 5 Onda 9 - absorcao TOTAL do
  dataset-serialize + adapter RESTRequest4Delphi, modelo ZipFile/AD): 1.0.0
  absorcao inicial (DataSet<->JSON: TDataSetSerializeHelper/TDataSetSerialize/
  TJSONSerialize + Config/Consts/Language/UpdatedStatus/Utils + adapter
  Serialize.Adapter.RESTRequest4D gated por USE_RESTREQUEST4D, OFF por
  defeito).

  Changelog (file):
  - 1.1.1 (15/07/2026): RESTRequest4Delphi VENDORIZADA (Packages/RESTRequest4Delphi/
    src, 17 units) + paths nos 4 cfg/opts -> os adapters (JSON e CSV) compilam com
    USE_RESTREQUEST4D ON nos 4 compiladores. Fix bug-137 no header do CSV adapter
    (a diretiva IFDEF FPC escrita com chavetas dentro do comentario fechava-o - so surgia com o define
    ON). Novo smoke_restadapters (CSV adapter JSON->CSV) OK=5 dcc32 (System.JSON) +
    fpc32 (fpjson) - ramo fpjson agora runtime-VERIFICADO. Gate default (OFF) intacto.
  - 1.1.0 (15/07/2026): absorcao do CSV adapter (csv-adapter-restrequest4delphi)
    -> Serialize.Adapter.CSV.RESTRequest4D[.Config/.Utils], gated USE_RESTREQUEST4D
    (OFF por defeito, mesma politica do adapter JSON); parsing JSON cross-compiler
    (fpjson no FPC / System.JSON no Delphi); Exception cru -> ESerializeException/
    ERR_SERIALIZE_GENERIC. O modulo Serialize passa a oferecer JSON E CSV sobre o
    mesmo contrato IRequestAdapter. Gate default 4 compiladores EXIT=0.
  - 1.0.0 (13/07/2026): versao inicial (FASE 5 Onda 9) - absorcao TOTAL do
    dataset-serialize (FontesReferencias/dataset-serialize) + adapter
    dataset-serialize-adapter-restrequest4delphi para src/Modulos/Serialize,
    namespace DataSet.Serialize.* -> Serialize.* (unit-level; identificadores
    de classe/tipo preservados verbatim - TDataSetSerializeHelper/TDataSetSerialize/
    TJSONSerialize/TDataSetSerializeConfig/TDataSetSerializeUtils/etc.); excecao
    EDataSetSerializeException (Exception cru) migrada para ESerializeException
    (Exceptions.Serialize, herda EExceptionBase, faixa 44).
  ============================================================================= }
unit Serialize.Version;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

const
  SERIALIZE_VERSION_MAJOR = 1;
  SERIALIZE_VERSION_MINOR = 1;
  SERIALIZE_VERSION_PATCH = 1;
  SERIALIZE_VERSION       = '1.1.1';
  SERIALIZE_VERSION_DATE  = '15/07/2026';

  { Forma legivel para logs / About box. }
  SERIALIZE_VERSION_FULL  = 'Serialize ' + SERIALIZE_VERSION +
                               ' (' + SERIALIZE_VERSION_DATE + ')';

implementation

end.
