{ =============================================================================
  Serialize.UpdatedStatus - Helper TUpdateStatus.ToString ('object_state')

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           13/07/2026

  Absorvido de FontesReferencias/dataset-serialize/src/DataSet.Serialize.UpdatedStatus.pas
  (namespace DataSet.Serialize.UpdatedStatus -> Serialize.UpdatedStatus).
  Conteudo verbatim - traduz TUpdateStatus (usModified/usInserted/usDeleted/
  usUnmodified) para os literais usados na chave "object_state" do JSON
  (Serialize.Export/Import).

  Changelog (file):
  - 1.0.0 (13/07/2026): versao inicial (FASE 5 Onda 9) - absorcao TOTAL do
    dataset-serialize, header v3.
  ============================================================================= }
unit Serialize.UpdatedStatus;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}{$H+}
{$ENDIF}

interface

uses
{$IF DEFINED(FPC)}
  DB;
{$ELSE}
  Data.DB;
{$ENDIF}

type
  TUpdateStatusHelper = record helper for TUpdateStatus
    function ToString: string;
  end;

implementation

function TUpdateStatusHelper.ToString: string;
begin
  case Self of
    usModified:
      Result := 'MODIFIED';
    usInserted:
      Result := 'INSERTED';
    usDeleted:
      Result := 'DELETED';
  else
    Result := 'UNMODIFIED';
  end;
end;

end.
