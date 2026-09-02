{ =============================================================================
  Serialize.Language - Idiomas suportados por ValidateJSON

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           13/07/2026

  Absorvido de FontesReferencias/dataset-serialize/src/DataSet.Serialize.Language.pas
  (namespace DataSet.Serialize.Language -> Serialize.Language). Conteudo
  verbatim.

  Changelog (file):
  - 1.0.0 (13/07/2026): versao inicial (FASE 5 Onda 9) - absorcao TOTAL do
    dataset-serialize, header v3.
  ============================================================================= }
unit Serialize.Language;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}{$H+}
{$ENDIF}

interface

type
  /// <summary>
  ///   Languages handled by helper Validate (JSON).
  /// </summary>
  TLanguageType = (ptBR, enUS);

implementation

end.
