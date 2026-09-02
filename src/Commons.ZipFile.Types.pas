unit Commons.ZipFile.Types;

{$IFDEF FPC}{$mode delphi}{$H+}{$ENDIF}

interface

uses
  Classes,
  SysUtils;

type
  { Progresso de operacoes longas do modulo ZipFile (compressao/extracao) e do
    Commons.DllBootstrap (download). Absorvido de Commons.Progress do ZipFileORM. }
  TZipProgressEvent = procedure(Sender: TObject; BytesDone, BytesTotal: Int64; var Cancel: Boolean) of object;

  // Capacidades de cada formato (read-only vs read+write)
  // NOTA: TArchiveFormat (enum dos 10 formatos) vive em ZipFile.Open.pas — fonte canonica.
  TArchiveCapability = (acRead, acWrite, acEncrypt, acSplitVolume, acSolidArchive);
  TArchiveCapabilities = set of TArchiveCapability;

  // Registro de uma entrada (file/directory) dentro do archive
  TArchiveSearchRec = record
    Name           : string;
    DateTime       : TDateTime;
    UncompressedSize : Int64;
    CompressedSize : Int64;
    IsDirectory    : Boolean;
    IsEncrypted    : Boolean;
    Comment        : string;
  end;

  // Informação de progresso para callbacks
  TArchiveProgressInfo = record
    CurrentEntry      : string;
    EntryIndex        : Integer;
    TotalEntries      : Integer;
    BytesProcessed    : Int64;
    TotalBytes        : Int64;
    PercentComplete   : Double;
  end;

type
  TZipSearchRec = record
    DateTime : TDateTime;
    USize : Int64;
    CSize: Int64;
    Name : TFileName;
  end;

implementation

end.
