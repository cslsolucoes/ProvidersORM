{ =============================================================================
  ArjFile - absorvido do ZipFileORM v4.0.0 (modulo ZipFile, F1-A Onda A.3)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           05/07/2026

  Changelog (file):
  - 1.0.0 (05/07/2026): v3 F1-A A.3 - copia integral do ZipFileORM v4.0.0 com
    namespaces reconciliados conforme o mapa da Onda A.1 do plano (dados do
    pacote consolidados no nucleo Commons e infra renomeada ao namespace do
    modulo). Paths de objetos nativos apontam a pasta Library do modulo.
    Header original preservado abaixo.
  ============================================================================= }
{ ArjFile.pas

  TArjFile — READ-only ARJ decoder, pure-pascal.

  Suporta:
   - Magic 0xEA60 (LE 0x60 0xEA) detection
   - Main header (file_type=2) skip + per-file header parsing
   - Method 0 (stored / no compression) — extract direto
   - Listing/metadata para qualquer method
   - Extended header chain (skipped — opcional)

  NAO suporta nesta versao (deferido para v3.4.1):
   - Methods 1-9 (ARJ LZ77 variants) — ReadAsBytes raise EArjError
   - Encryption (file_type=1)
   - Multi-volume archives

  Cross-platform: Delphi (Win32/Win64) + FPC (Win32/Win64/Linux i386/x86_64).
  Sem dependencia C — apenas SysUtils + Classes.

  API espelhada de TZipFile/TLhaFile/TIsoFile.

  ARJ format layout (per header):
    +0  2 bytes  magic = 0xEA60 LE
    +2  2 bytes  basic_hdr_size LE (=0 => end of archive)
    +4  N bytes  basic header content (size = basic_hdr_size)
    +4+N 4 bytes header_crc32 LE
    +8+N 2 bytes ext_hdr_size LE (chain; first size=0 => end of chain)
       ... ext_hdr data if size>0, then another size, etc.
    after chain ends: compressed data (only if file header, not main header)

  Basic header (first 34 bytes for ARJ 2.x):
    +0  1B  first_hdr_size (=34 or 30 for older)
    +1  1B  archiver_version
    +2  1B  min_version_to_extract
    +3  1B  host_os
    +4  1B  arj_flags
    +5  1B  security_version
    +6  1B  file_type (0=normal, 2=main, etc.)
    +7  1B  reserved
    +8  4B  timestamp_dos LE
    +12 4B  compressed_size LE
    +16 4B  original_size LE
    +20 4B  file_crc32 LE
    +24 2B  filespec_position LE
    +26 2B  file_attr LE
    +28 2B  host_data LE
    +30 4B  extra (V format)
  After basic header: filename (null-terminated), then comment (null-terminated).
}
unit ArjFile;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Classes, Commons.ZipFile.Types, ZipFile.Events, ArjFile.Exceptions;

const
  ARJ_MAGIC = $EA60;

  ARJ_FILETYPE_NORMAL    = 0;
  ARJ_FILETYPE_ENCRYPTED = 1;
  ARJ_FILETYPE_MAIN      = 2;
  ARJ_FILETYPE_DIR       = 3;
  ARJ_FILETYPE_LABEL     = 4;

type
  // Exception types relocated to ArjFile.Exceptions.pas (Wave 3b).
  // Aliased for backward compat with `uses ArjFile` consumers.
  EArjError = ArjFile.Exceptions.EArjError;
  EArjMethodNotSupported = ArjFile.Exceptions.EArjMethodNotSupported;

  TArjEntry = record
    FileName: string;
    Comment: string;
    Method: Byte;
    FileType: Byte;
    PackedSize: Cardinal;
    OriginalSize: Cardinal;
    Timestamp: Cardinal;
    FileCRC32: Cardinal;
    DataOffset: Int64;
    IsDirectory: Boolean;
  end;

  TArjFile = class(TComponent)
  private
    FFileName: string;
    FActive: Boolean;
    FOnFileChanged: TNotifyEvent;
    FOnProgress: TZipProgressEvent;
    // Lifecycle
    FOnBeforeOpen: TArchiveLifecycleQueryEvent;
    FOnAfterOpen: TArchiveLifecycleEvent;
    FOnBeforeClose: TArchiveLifecycleQueryEvent;
    FOnAfterClose: TArchiveLifecycleEvent;
    // Entries
    FOnEntryFound: TArchiveEntryFoundEvent;
    FOnBeforeExtract: TArchiveBeforeExtractEvent;
    FOnAfterExtract: TArchiveAfterExtractEvent;
    FOnExtractProgress: TArchiveEntryProgressEvent;
    // Security
    FOnAskPassword: TArchivePasswordRequestEvent;
    FOnReplaceQuery: TArchiveReplaceQueryEvent;
    FOnVerify: TArchiveVerifyEvent;
    // Multi-volume
    FOnRequestVolume: TArchiveRequestVolumeEvent;
    FOnVolumeChanged: TArchiveVolumeChangedEvent;
    // Diagnostics
    FOnError: TArchiveErrorEvent;
    FOnWarning: TArchiveWarningEvent;
    FOnLog: TArchiveLogEvent;
    FStream: TFileStream;
    FEntries: array of TArjEntry;
    FArchiveName: string;
    FArchiveComment: string;
    // Read-only header fields — populated by ParseHeader / DoOpenAndIndex.
    FHostOS: Byte;             // ARJ host OS code: 0=MSDOS, 1=PRIMOS, 2=Unix, 3=Amiga,
                               //   4=Mac, 5=OS/2, 6=Apple ][, 7=Atari, 8=NeXT, 9=VMS,
                               //   10=Win95, 11=WinNT
    FArchiverVersion: Byte;    // version that produced the archive
    FMinVersionToExtract: Byte;
    FFlags: Byte;              // ARJ archive flags (GARBLED_FLAG, OLD_SECURED_FLAG, ...)
    FIsMultiVolume: Boolean;   // true if this is part of a multi-volume set
    FArchiveSize: Int64;       // physical size of .arj file
    // v3.12 extras
    FFileType: Byte;           // 0=binary, 1=7bit text, 2=8bit text, 3=path, 4=label, 5=ghost
    FFileAccessMode: Cardinal; // permissoes file_access_mode no header
    FSecurityVersion: Byte;    // security envelope version (0=none)
    FHostData: Word;           // host-specific data field
    FExtensionPos: Cardinal;   // extension data offset
    FCreationDate: TDateTime;  // archive creation date_time
    FModificationDate: TDateTime; // archive modification date_time
    FArjFlags2: Byte;          // ARJ2 flags byte (older ARJ format)

    function ReadByteAt(AOffset: Int64): Byte;
    function ReadLEUInt16At(AOffset: Int64): Word;
    function ReadLEUInt32At(AOffset: Int64): Cardinal;
    procedure ReadBytesAt(AOffset: Int64; var ABuffer: TBytes; ACount: Integer);
    function ReadCStrAt(var AOffset: Int64; AMaxLen: Integer): string;
    function FindNextMagic(AStart: Int64): Int64;
    function ParseHeader(AOffset: Int64; out AEntry: TArjEntry;
      out ADataOffset, ANextHeaderOffset: Int64; out AFileType: Byte): Boolean;
    procedure DoOpenAndIndex;

    procedure SetActive(AValue: Boolean);
    procedure SetFileName(const AValue: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Open;
    procedure Close;

    function GetEntryCount: Integer;
    function FileExists(const AName: string): Boolean;
    function IsDir(AIndex: Integer): Boolean;
    function GetFileSize(AIndex: Integer): Int64;
    function GetEntryName(AIndex: Integer): string;
    function GetEntryMethod(AIndex: Integer): Byte;
    function FindIndex(const AName: string): Integer;
    function GetEntryStream(const AName: string): TStream;
    function ReadAsBytes(const AName: string): TBytes;
    function ReadAsString(const AName: string): string;

    function WithFileName(const APath: string): TArjFile;
    function ThatOpens: TArjFile;
  published
    property Active: Boolean read FActive write SetActive;
    property FileName: string read FFileName write SetFileName;
    property EntryCount: Integer read GetEntryCount;

    // ---- Read-only header info ----
    property ArchiveName: string read FArchiveName;
    property ArchiveComment: string read FArchiveComment;
    // Host OS code per ARJ spec: 0=MSDOS, 1=PRIMOS, 2=Unix, 3=Amiga, 4=Mac,
    // 5=OS/2, 6=Apple][, 7=Atari, 8=NeXT, 9=VMS, 10=Win95, 11=WinNT.
    property HostOS: Byte read FHostOS;
    // ARJ version that produced the archive.
    property ArchiverVersion: Byte read FArchiverVersion;
    // Minimum ARJ version required to extract.
    property MinVersionToExtract: Byte read FMinVersionToExtract;
    // Bit flags: $01=GARBLED (encrypted), $04=VOLUME, $08=EXTFILE, ...
    property Flags: Byte read FFlags;
    // True se este .arj eh parte de um volume set (.arj/.a01/.a02/...).
    property IsMultiVolume: Boolean read FIsMultiVolume;
    // Physical size of the .arj file on disk.
    property ArchiveSize: Int64 read FArchiveSize;
    // ARJ file_type: 0=binary, 1=7bit text, 2=8bit text, 3=path, 4=label, 5=ghost.
    property FileType: Byte read FFileType;
    // ARJ file access mode bits.
    property FileAccessMode: Cardinal read FFileAccessMode;
    // ARJ security envelope version (0=none).
    property SecurityVersion: Byte read FSecurityVersion;
    // ARJ host_data field (depends on HostOS).
    property HostData: Word read FHostData;
    // Position of extension data in the archive.
    property ExtensionPos: Cardinal read FExtensionPos;
    // Archive creation date/time (from archive main header).
    property CreationDate: TDateTime read FCreationDate;
    // Archive modification date/time.
    property ModificationDate: TDateTime read FModificationDate;
    // ARJ2 flags byte (older ARJ format compat).
    property ArjFlags2: Byte read FArjFlags2;

    // ---- Events ----
    property OnFileChanged: TNotifyEvent read FOnFileChanged write FOnFileChanged;
    property OnProgress: TZipProgressEvent read FOnProgress write FOnProgress;
    // Lifecycle events
    property OnBeforeOpen: TArchiveLifecycleQueryEvent read FOnBeforeOpen write FOnBeforeOpen;
    property OnAfterOpen: TArchiveLifecycleEvent read FOnAfterOpen write FOnAfterOpen;
    property OnBeforeClose: TArchiveLifecycleQueryEvent read FOnBeforeClose write FOnBeforeClose;
    property OnAfterClose: TArchiveLifecycleEvent read FOnAfterClose write FOnAfterClose;
    property OnEntryFound: TArchiveEntryFoundEvent read FOnEntryFound write FOnEntryFound;
    property OnBeforeExtract: TArchiveBeforeExtractEvent read FOnBeforeExtract write FOnBeforeExtract;
    property OnAfterExtract: TArchiveAfterExtractEvent read FOnAfterExtract write FOnAfterExtract;
    property OnExtractProgress: TArchiveEntryProgressEvent read FOnExtractProgress write FOnExtractProgress;
    property OnAskPassword: TArchivePasswordRequestEvent read FOnAskPassword write FOnAskPassword;
    property OnReplaceQuery: TArchiveReplaceQueryEvent read FOnReplaceQuery write FOnReplaceQuery;
    property OnVerify: TArchiveVerifyEvent read FOnVerify write FOnVerify;
    property OnRequestVolume: TArchiveRequestVolumeEvent read FOnRequestVolume write FOnRequestVolume;
    property OnVolumeChanged: TArchiveVolumeChangedEvent read FOnVolumeChanged write FOnVolumeChanged;
    property OnError: TArchiveErrorEvent read FOnError write FOnError;
    property OnWarning: TArchiveWarningEvent read FOnWarning write FOnWarning;
    property OnLog: TArchiveLogEvent read FOnLog write FOnLog;
  end;

implementation

uses
  ArjFile.Decode;   // decoder nativo methods 1-3 (v3, F1-A)

constructor TArjFile.Create(AOwner: TComponent);
begin
  inherited;
  FActive := False;
end;

destructor TArjFile.Destroy;
begin
  Close;
  inherited;
end;

procedure TArjFile.SetActive(AValue: Boolean);
begin
  if AValue = FActive then Exit;
  if AValue then Open else Close;
end;

procedure TArjFile.SetFileName(const AValue: string);
begin
  if AValue = FFileName then Exit;
  Close;
  FFileName := AValue;
  if Assigned(FOnFileChanged) then FOnFileChanged(Self);
end;

function TArjFile.ReadByteAt(AOffset: Int64): Byte;
begin
  FStream.Position := AOffset;
  FStream.ReadBuffer(Result, 1);
end;

function TArjFile.ReadLEUInt16At(AOffset: Int64): Word;
var B: array[0..1] of Byte;
begin
  FStream.Position := AOffset;
  FStream.ReadBuffer(B[0], 2);
  Result := Word(B[0]) or (Word(B[1]) shl 8);
end;

function TArjFile.ReadLEUInt32At(AOffset: Int64): Cardinal;
var B: array[0..3] of Byte;
begin
  FStream.Position := AOffset;
  FStream.ReadBuffer(B[0], 4);
  Result := Cardinal(B[0]) or (Cardinal(B[1]) shl 8) or
            (Cardinal(B[2]) shl 16) or (Cardinal(B[3]) shl 24);
end;

procedure TArjFile.ReadBytesAt(AOffset: Int64; var ABuffer: TBytes; ACount: Integer);
begin
  if Length(ABuffer) < ACount then SetLength(ABuffer, ACount);
  if ACount <= 0 then Exit;
  FStream.Position := AOffset;
  FStream.ReadBuffer(ABuffer[0], ACount);
end;

function TArjFile.ReadCStrAt(var AOffset: Int64; AMaxLen: Integer): string;
var
  B: Byte;
  AnsiBuf: AnsiString;
  Count: Integer;
begin
  AnsiBuf := '';
  Count := 0;
  while Count < AMaxLen do
  begin
    if AOffset >= FStream.Size then Break;
    B := ReadByteAt(AOffset);
    Inc(AOffset);
    if B = 0 then Break;
    AnsiBuf := AnsiBuf + AnsiChar(B);
    Inc(Count);
  end;
  Result := string(AnsiBuf);
end;

function TArjFile.FindNextMagic(AStart: Int64): Int64;
var
  Buf: TBytes;
  ChunkSize, I: Integer;
  ReadStart: Int64;
begin
  // Search forward for 0x60 0xEA byte sequence (ARJ magic LE)
  Result := -1;
  ReadStart := AStart;
  ChunkSize := 65536;
  while ReadStart < FStream.Size do
  begin
    if FStream.Size - ReadStart < ChunkSize then
      ChunkSize := Integer(FStream.Size - ReadStart);
    // fix v3: com resto < 2 bytes o magic de 2 bytes ja nao cabe e o avanco
    // 'ChunkSize - 1' seria 0 -> loop infinito quando o magic nao existe
    if ChunkSize < 2 then
      Break;
    SetLength(Buf, ChunkSize);
    ReadBytesAt(ReadStart, Buf, ChunkSize);
    for I := 0 to ChunkSize - 2 do
      if (Buf[I] = $60) and (Buf[I + 1] = $EA) then
      begin
        Result := ReadStart + I;
        Exit;
      end;
    Inc(ReadStart, ChunkSize - 1);  // overlap 1 byte for cross-chunk match
  end;
end;

function TArjFile.ParseHeader(AOffset: Int64; out AEntry: TArjEntry;
  out ADataOffset, ANextHeaderOffset: Int64; out AFileType: Byte): Boolean;
var
  Magic: Word;
  BasicHdrSize: Word;
  FirstHdrSize: Byte;
  Buf: TBytes;
  ReadOffset: Int64;
  ExtSize: Word;
begin
  Result := False;
  if AOffset + 4 > FStream.Size then Exit;

  Magic := ReadLEUInt16At(AOffset);
  if Magic <> ARJ_MAGIC then Exit;
  BasicHdrSize := ReadLEUInt16At(AOffset + 2);
  if BasicHdrSize = 0 then Exit;  // end of archive
  if BasicHdrSize > 2600 then Exit;  // unreasonable

  // Read basic header (BasicHdrSize bytes starting at AOffset+4)
  ReadBytesAt(AOffset + 4, Buf, BasicHdrSize);

  FirstHdrSize := Buf[0];
  if FirstHdrSize < 30 then Exit;
  AFileType := Buf[6];

  AEntry.FileType := AFileType;
  // fix v3: layout ARJ (technote oficial): 0=first_hdr_size 1=ver 2=min_ver
  // 3=host_os 4=flags 5=METHOD 6=file_type 7=reserved. O original lia Buf[7]
  // (reserved) e reportava lixo (ex.: method 212 = 1o byte do timestamp do
  // main header). Method real esta em Buf[5].
  AEntry.Method := Buf[5];
  AEntry.Timestamp := Cardinal(Buf[8]) or (Cardinal(Buf[9]) shl 8) or
                      (Cardinal(Buf[10]) shl 16) or (Cardinal(Buf[11]) shl 24);
  AEntry.PackedSize := Cardinal(Buf[12]) or (Cardinal(Buf[13]) shl 8) or
                       (Cardinal(Buf[14]) shl 16) or (Cardinal(Buf[15]) shl 24);
  AEntry.OriginalSize := Cardinal(Buf[16]) or (Cardinal(Buf[17]) shl 8) or
                         (Cardinal(Buf[18]) shl 16) or (Cardinal(Buf[19]) shl 24);
  AEntry.FileCRC32 := Cardinal(Buf[20]) or (Cardinal(Buf[21]) shl 8) or
                      (Cardinal(Buf[22]) shl 16) or (Cardinal(Buf[23]) shl 24);
  AEntry.IsDirectory := (AFileType = ARJ_FILETYPE_DIR);

  // Filename starts at AOffset + 4 + FirstHdrSize
  ReadOffset := AOffset + 4 + FirstHdrSize;
  // ReadCStrAt avanca ReadOffset (var) para depois do NUL - o comment segue-se
  AEntry.FileName := ReadCStrAt(ReadOffset, 1024);
  AEntry.Comment := ReadCStrAt(ReadOffset, 4096);

  // After basic header: header_crc32 (4 bytes) + ext_hdr chain
  ReadOffset := AOffset + 4 + BasicHdrSize + 4;  // skip header CRC

  // Ext header chain — each: 2 bytes size; if size=0 done; else size bytes + 4 bytes ext CRC
  while ReadOffset + 2 <= FStream.Size do
  begin
    ExtSize := ReadLEUInt16At(ReadOffset);
    if ExtSize = 0 then
    begin
      Inc(ReadOffset, 2);
      Break;
    end;
    Inc(ReadOffset, 2 + ExtSize + 4);  // size field + data + ext CRC
  end;

  // Data starts here (for normal file headers)
  ADataOffset := ReadOffset;
  AEntry.DataOffset := ADataOffset;
  if AFileType = ARJ_FILETYPE_NORMAL then
    ANextHeaderOffset := ADataOffset + AEntry.PackedSize
  else
    ANextHeaderOffset := ADataOffset;  // main header: no data
  Result := True;
end;

procedure TArjFile.DoOpenAndIndex;
var
  Offset, NextOffset, DataOffset: Int64;
  Entry: TArjEntry;
  FileType: Byte;
begin
  SetLength(FEntries, 0);
  // ARJ files podem ter SFX prefix; busca o magic 0xEA60 a partir do inicio
  Offset := FindNextMagic(0);
  if Offset < 0 then
    raise EArjError.Create('TArjFile.Open: ARJ magic 0xEA60 nao encontrado');

  while Offset < FStream.Size do
  begin
    if not ParseHeader(Offset, Entry, DataOffset, NextOffset, FileType) then Break;
    case FileType of
      ARJ_FILETYPE_MAIN:
        begin
          FArchiveName := Entry.FileName;
          FArchiveComment := Entry.Comment;
        end;
      ARJ_FILETYPE_NORMAL, ARJ_FILETYPE_DIR, ARJ_FILETYPE_LABEL:
        begin
          SetLength(FEntries, Length(FEntries) + 1);
          FEntries[High(FEntries)] := Entry;
        end;
    end;
    if NextOffset <= Offset then Break;  // sanity
    Offset := NextOffset;
  end;
end;

procedure TArjFile.Open;
begin
  if FActive then Exit;
  if FFileName = '' then
    raise EArjError.Create('TArjFile.Open: FileName not set');
  FStream := TFileStream.Create(FFileName, fmOpenRead or fmShareDenyWrite);
  try
    DoOpenAndIndex;
    FActive := True;
  except
    FStream.Free;
    FStream := nil;
    raise;
  end;
end;

procedure TArjFile.Close;
begin
  if Assigned(FStream) then
  begin
    FStream.Free;
    FStream := nil;
  end;
  SetLength(FEntries, 0);
  FArchiveName := '';
  FArchiveComment := '';
  FActive := False;
end;

function TArjFile.GetEntryCount: Integer;
begin Result := Length(FEntries); end;

function TArjFile.IsDir(AIndex: Integer): Boolean;
begin
  Result := (AIndex >= 0) and (AIndex < Length(FEntries)) and FEntries[AIndex].IsDirectory;
end;

function TArjFile.GetFileSize(AIndex: Integer): Int64;
begin
  if (AIndex >= 0) and (AIndex < Length(FEntries)) then
    Result := FEntries[AIndex].OriginalSize
  else Result := 0;
end;

function TArjFile.GetEntryName(AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex < Length(FEntries)) then
    Result := FEntries[AIndex].FileName
  else Result := '';
end;

function TArjFile.GetEntryMethod(AIndex: Integer): Byte;
begin
  if (AIndex >= 0) and (AIndex < Length(FEntries)) then
    Result := FEntries[AIndex].Method
  else Result := 255;
end;

function TArjFile.FindIndex(const AName: string): Integer;
var I: Integer;
begin
  for I := 0 to High(FEntries) do
    if SameText(FEntries[I].FileName, AName) then Exit(I);
  Result := -1;
end;

function TArjFile.FileExists(const AName: string): Boolean;
begin Result := FindIndex(AName) >= 0; end;

function TArjFile.ReadAsBytes(const AName: string): TBytes;
var
  Idx: Integer;
  LOut: TMemoryStream;
  LCrc: Cardinal;
begin
  if not FActive then raise EArjError.Create('TArjFile.ReadAsBytes: nao aberto');
  Idx := FindIndex(AName);
  if Idx < 0 then
    raise EArjError.CreateFmt('TArjFile.ReadAsBytes: entry nao encontrada "%s"', [AName]);
  if FEntries[Idx].IsDirectory then
    raise EArjError.CreateFmt('TArjFile.ReadAsBytes: "%s" eh um diretorio', [AName]);

  case FEntries[Idx].Method of
    0: // Store: copia direta
      begin
        SetLength(Result, FEntries[Idx].OriginalSize);
        if FEntries[Idx].OriginalSize > 0 then
        begin
          FStream.Position := FEntries[Idx].DataOffset;
          FStream.ReadBuffer(Result[0], FEntries[Idx].OriginalSize);
        end;
      end;
    1..3: // LZSS + Huffman dinamico via decoder nativo (ArjFile.Decode, v3)
      begin
        if not ArjDecodeAvailable then
          raise EArjMethodNotSupported.CreateFmt(
            'TArjFile.ReadAsBytes: method %d requer o decoder nativo ' +
            '(indisponivel neste alvo)', [FEntries[Idx].Method]);
        LOut := TMemoryStream.Create;
        try
          LOut.Size := FEntries[Idx].OriginalSize;   // pre-aloca
          LOut.Position := 0;
          FStream.Position := FEntries[Idx].DataOffset;
          ArjDecodeToStream(FStream, FEntries[Idx].PackedSize,
            FEntries[Idx].OriginalSize, LOut, LCrc);
          if LOut.Size <> Int64(FEntries[Idx].OriginalSize) then
            raise EArjError.CreateFmt(
              'TArjFile.ReadAsBytes: "%s" descomprimiu %d bytes (esperado %d)',
              [AName, LOut.Size, FEntries[Idx].OriginalSize]);
          if (FEntries[Idx].FileCRC32 <> 0) and (LCrc <> FEntries[Idx].FileCRC32) then
            raise EArjError.CreateFmt(
              'TArjFile.ReadAsBytes: CRC32 invalido em "%s" (obtido %.8x, esperado %.8x)',
              [AName, LCrc, FEntries[Idx].FileCRC32]);
          SetLength(Result, LOut.Size);
          if LOut.Size > 0 then
            Move(LOut.Memory^, Result[0], LOut.Size);
        finally
          LOut.Free;
        end;
      end;
  else
    // Method 4 (decode_f) fora do objeto no nivel SFX usado; 5-9 nao existem.
    raise EArjMethodNotSupported.CreateFmt(
      'TArjFile.ReadAsBytes: method %d nao suportado (0 Store e 1-3 ' +
      'LZSS+Huffman via decoder nativo; method 4 fast-LZ77 nao incluido)',
      [FEntries[Idx].Method]);
  end;
end;

function TArjFile.ReadAsString(const AName: string): string;
var B: TBytes;
begin
  B := ReadAsBytes(AName);
  if Length(B) = 0 then Result := ''
  else Result := TEncoding.UTF8.GetString(B);
end;

function TArjFile.GetEntryStream(const AName: string): TStream;
var B: TBytes;
begin
  B := ReadAsBytes(AName);
  Result := TMemoryStream.Create;
  if Length(B) > 0 then Result.WriteBuffer(B[0], Length(B));
  Result.Position := 0;
end;

function TArjFile.WithFileName(const APath: string): TArjFile;
begin SetFileName(APath); Result := Self; end;

function TArjFile.ThatOpens: TArjFile;
begin Open; Result := Self; end;

end.
