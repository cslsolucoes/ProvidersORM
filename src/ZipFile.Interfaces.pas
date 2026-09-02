unit ZipFile.Interfaces;

{$IFDEF FPC}{$mode delphi}{$H+}{$ENDIF}

interface

uses
  SysUtils,
  Classes,
  Commons.ZipFile.Types,
  ZipFile.Compression;

type
  // Entrada (file ou directory) dentro de um archive — visão read-only
  IArchiveEntry = interface
    ['{B5E7A1F0-9C3D-4E5A-8B7F-1234567890AB}']
    function GetName: string;
    function GetSize: Int64;
    function GetCompressedSize: Int64;
    function GetDateTime: TDateTime;
    function GetIsDirectory: Boolean;
    function GetIsEncrypted: Boolean;
    function GetMethod: TCompressionMethod;
    function GetComment: string;

    property Name: string read GetName;
    property Size: Int64 read GetSize;
    property CompressedSize: Int64 read GetCompressedSize;
    property DateTime: TDateTime read GetDateTime;
    property IsDirectory: Boolean read GetIsDirectory;
    property IsEncrypted: Boolean read GetIsEncrypted;
    property Method: TCompressionMethod read GetMethod;
    property Comment: string read GetComment;
  end;

  // Archive aberto — contrato read-only comum a todos os formatos
  IArchive = interface
    ['{C4D5E6F7-8901-2345-6789-ABCDEF012345}']
    function GetFileName: string;
    function GetEntryCount: Integer;
    function GetEntry(AIndex: Integer): IArchiveEntry;
    function FindEntry(const AName: string): IArchiveEntry;
    function EntryExists(const AName: string): Boolean;
    function ReadEntryAsBytes(const AName: string): TBytes;
    function ReadEntryAsString(const AName: string): string;
    procedure ExtractEntry(const AName: string; ATarget: TStream); overload;
    procedure ExtractEntry(const AName: string; const ATargetPath: string); overload;
    procedure Close;

    property FileName: string read GetFileName;
    property EntryCount: Integer read GetEntryCount;
    property Entries[Index: Integer]: IArchiveEntry read GetEntry; default;
  end;

  // Builder fluent base — cada formato write-capable estende esta interface
  IArchiveBuilder = interface
    ['{D5E6F708-9012-3456-789A-BCDEF0123456}']
    function WithFileName(const AFileName: string): IArchiveBuilder;
    function WithPassword(const APassword: string): IArchiveBuilder;
    function WithMethod(AMethod: TCompressionMethod): IArchiveBuilder;
    function Build: IArchive;
  end;

type
  TCompressionMethod = (cmNone, cmMaximal);
  TReCompressionMethod = (rmKeepOriginal, rmNone, rmMaximal);

  TFileChangedEvent = procedure(Sender: TObject) of object;

  IZipFileBuilder = interface
    ['{B95B5C56-D5C8-4F8A-9C30-1F8E32D69A21}']
    // === Toggles / properties (todos chainable) ===
    function WithUtf8(AEnable: Boolean = True): IZipFileBuilder;
    function WithAES(const APassword: string): IZipFileBuilder;
    function WithPassword(const APassword: string): IZipFileBuilder;
    function WithLZMA(AEnable: Boolean = True): IZipFileBuilder;
    function WithForceZip64(AEnable: Boolean = True): IZipFileBuilder;
    function WithCompression(AMethod: TCompressionMethod): IZipFileBuilder;
    function WithReCompression(AMethod: TReCompressionMethod): IZipFileBuilder;
    function OnProgress(AEvent: TZipProgressEvent): IZipFileBuilder;
    function OnArchiveChanged(AEvent: TFileChangedEvent): IZipFileBuilder;
    // === Write intents (queued; emitted em .Execute) ===
    function AppendStream(AStream: TStream; const AZipName: string;
                         AOwnStream: Boolean = False): IZipFileBuilder;
    function AppendFile(const ADiskFileName, AZipName: string): IZipFileBuilder;
    function DeleteEntry(const AZipName: string): IZipFileBuilder;
    function UpdateEntry(AStream: TStream; const AZipName: string;
                         AOwnStream: Boolean = False): IZipFileBuilder;
    // === Terminais: write ===
    procedure Execute;
    // === Terminais: read (open-only) ===
    function ExtractStream(const AZipName: string): TStream;
    function HasEntry(const AZipName: string): Boolean;
    function CountEntries: Cardinal;
  end;

implementation

end.
