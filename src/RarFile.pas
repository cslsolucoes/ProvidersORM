{ =============================================================================
  RarFile - absorvido do ZipFileORM v4.0.0 (modulo ZipFile, F1-A Onda A.3)

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
{ RarFile.pas

  TRarFile — READ-only RAR decoder, pure-pascal.

  Suporta:
   - RAR5 format (marker "Rar!\x1A\x07\x01\x00", 8 bytes)
   - Variable-length integer (vint) decoder (LSB-first, 7-bit + continuation)
   - Block parsing: archive header, file headers, end-of-archive
   - Method 0 (store / no compression) — extract direto
   - UTF-8 filenames (RAR5 nativo)
   - Listing/metadata para qualquer method

  NAO suporta nesta versao (deferido para v3.5.1):
   - RAR4 legacy format (marker "Rar!\x1A\x07\x00", 7 bytes) — autodetect
     emite EUnsupportedFormat
   - Methods 1-5 (RAR LZSS, PPMd) — ReadAsBytes raise ERarMethodNotSupported
   - Encryption (header ou data)
   - Multi-volume archives
   - WRITE

  Cross-platform: Delphi (Win32/Win64) + FPC (Win32/Win64/Linux i386/x86_64).
  Sem dependencia C — apenas SysUtils + Classes.

  API espelhada de TZipFile/TLhaFile/TArjFile/TIsoFile.

  RAR5 spec ref: https://www.rarlab.com/technote.htm (RAR 5.0 archive format)
}
unit RarFile;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Classes, Commons.ZipFile.Types, ZipFile.Events, RarFile.Exceptions;

const
  // RAR5 marker: 8 bytes "Rar!\x1A\x07\x01\x00"
  RAR5_MARKER_LEN = 8;

  // Block header types
  RAR_BLOCK_MAIN       = 1;
  RAR_BLOCK_FILE       = 2;
  RAR_BLOCK_SERVICE    = 3;
  RAR_BLOCK_ENCRYPTION = 4;
  RAR_BLOCK_END        = 5;

  // Block flags
  RAR_BLOCK_FLAG_EXTRA = $01;
  RAR_BLOCK_FLAG_DATA  = $02;

  // File flags (FILE block)
  RAR_FILE_FLAG_DIRECTORY = $01;
  RAR_FILE_FLAG_HAS_MTIME = $02;
  RAR_FILE_FLAG_HAS_CRC32 = $04;
  RAR_FILE_FLAG_UNK_SIZE  = $08;

type
  // Exception types relocated to RarFile.Exceptions.pas (Wave 3b).
  ERarError = RarFile.Exceptions.ERarError;
  ERarMethodNotSupported = RarFile.Exceptions.ERarMethodNotSupported;
  ERarUnsupportedFormat = RarFile.Exceptions.ERarUnsupportedFormat;

  TRarEntry = record
    FileName: string;
    UnpackedSize: Int64;
    PackedSize: Int64;
    DataOffset: Int64;
    Method: Byte;
    Version: Byte;
    HostOS: Byte;
    FileCRC32: Cardinal;
    Mtime: Cardinal;
    Attributes: Cardinal;
    IsDirectory: Boolean;
  end;

  TRarFile = class(TComponent)
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
    // Solid block
    FOnSolidBlockStart: TArchiveSolidBlockEvent;
    FOnSolidBlockEnd: TArchiveSolidBlockEvent;
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
    FEntries: array of TRarEntry;
    FIsRar5: Boolean;
    // Read-only header info — populated by ParseRar4/ParseRar5.
    FMajorVersion: Byte;        // 4 ou 5
    FMinVersionToExtract: Byte; // RAR5: version_to_extract
    FArchiveFlags: Cardinal;    // archive header flags
    FHasComment: Boolean;       // archive contains a CMT subblock
    FHasEncryption: Boolean;    // archive is password-protected
    FHasRecoveryRecord: Boolean;// archive contains recovery info (RR)
    FIsSolid: Boolean;          // SOLID flag bit
    FIsMultiVolume: Boolean;    // VOLUME flag bit (.part01.rar set)
    FVolumeNumber: Cardinal;    // current volume index (RAR5)
    FArchiveSize: Int64;        // physical .rar file size
    // v3.12 extras
    FArchiverVersion: Byte;      // archiver version that produced
    FArchiveComment: string;     // archive-level comment block (CMT)
    FRecoveryPercent: Byte;      // RR coverage percent (0..100)
    FHasAuthenticityVerification: Boolean;  // AV block presente (RAR4 only)
    FHasLockFlag: Boolean;       // Lock flag (archive read-only flag)
    FIsFirstVolume: Boolean;     // True se este eh o primeiro volume do set
    FIsLastVolume: Boolean;      // True se este eh o ultimo volume do set
    FQuickOpenInfo: Boolean;     // QO header presente (RAR5 — quick directory access)
    FArchiveNameInternal: string; // archive name dentro do header (RAR4 .sfx)

    function ReadByte_: Byte;
    function ReadLEUInt32: Cardinal;
    function ReadVInt: UInt64;
    function ReadBytes(ACount: Integer): TBytes;
    function DetectFormat: Boolean;
    procedure ParseRar5;

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

    function WithFileName(const APath: string): TRarFile;
    function ThatOpens: TRarFile;
  published
    property Active: Boolean read FActive write SetActive;
    property FileName: string read FFileName write SetFileName;
    property EntryCount: Integer read GetEntryCount;

    // ---- Read-only archive info ----
    property IsRar5: Boolean read FIsRar5;
    // 4 = RAR4 format, 5 = RAR5 format.
    property MajorVersion: Byte read FMajorVersion;
    // Minimum RAR version required to extract (RAR5 field).
    property MinVersionToExtract: Byte read FMinVersionToExtract;
    // Archive flags bitmask (format-specific bits).
    property ArchiveFlags: Cardinal read FArchiveFlags;
    // True se o archive contem comment block (CMT subheader).
    property HasComment: Boolean read FHasComment;
    // True se o archive eh password-protected.
    property HasEncryption: Boolean read FHasEncryption;
    // True se contem recovery record (RR) para reparo.
    property HasRecoveryRecord: Boolean read FHasRecoveryRecord;
    // SOLID block: entries comprimidas como bloco contiguo (melhor ratio).
    property IsSolid: Boolean read FIsSolid;
    // VOLUME flag: archive faz parte de set .part01.rar / .part02.rar / etc.
    property IsMultiVolume: Boolean read FIsMultiVolume;
    // Volume number atual (0-based, RAR5).
    property VolumeNumber: Cardinal read FVolumeNumber;
    property ArchiveSize: Int64 read FArchiveSize;
    // Versao do archiver que produziu o arquivo.
    property ArchiverVersion: Byte read FArchiverVersion;
    // Texto do comment block (vazio se HasComment=False).
    property ArchiveComment: string read FArchiveComment;
    // Recovery Record coverage 0..100% (so valido se HasRecoveryRecord=True).
    property RecoveryPercent: Byte read FRecoveryPercent;
    // True se Authenticity Verification block presente (RAR4 only).
    property HasAuthenticityVerification: Boolean read FHasAuthenticityVerification;
    // True se Lock flag bit setado (archive read-only por design).
    property HasLockFlag: Boolean read FHasLockFlag;
    // True se este eh o primeiro volume do multi-volume set.
    property IsFirstVolume: Boolean read FIsFirstVolume;
    // True se este eh o ultimo volume do multi-volume set.
    property IsLastVolume: Boolean read FIsLastVolume;
    // True se QuickOpen header presente (RAR5 — speedup directory access).
    property QuickOpenInfo: Boolean read FQuickOpenInfo;
    // Nome interno do archive (RAR4 SFX armazena o nome original).
    property ArchiveNameInternal: string read FArchiveNameInternal;

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
    property OnSolidBlockStart: TArchiveSolidBlockEvent read FOnSolidBlockStart write FOnSolidBlockStart;
    property OnSolidBlockEnd: TArchiveSolidBlockEvent read FOnSolidBlockEnd write FOnSolidBlockEnd;
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

constructor TRarFile.Create(AOwner: TComponent);
begin
  inherited;
  FActive := False;
end;

destructor TRarFile.Destroy;
begin
  Close;
  inherited;
end;

procedure TRarFile.SetActive(AValue: Boolean);
begin
  if AValue = FActive then Exit;
  if AValue then Open else Close;
end;

procedure TRarFile.SetFileName(const AValue: string);
begin
  if AValue = FFileName then Exit;
  Close;
  FFileName := AValue;
  if Assigned(FOnFileChanged) then FOnFileChanged(Self);
end;

function TRarFile.ReadByte_: Byte;
begin
  FStream.ReadBuffer(Result, 1);
end;

function TRarFile.ReadLEUInt32: Cardinal;
var B: array[0..3] of Byte;
begin
  FStream.ReadBuffer(B[0], 4);
  Result := Cardinal(B[0]) or (Cardinal(B[1]) shl 8) or
            (Cardinal(B[2]) shl 16) or (Cardinal(B[3]) shl 24);
end;

// RAR5 vint (variable-length integer): little-endian, 7 bits + 1 bit continuation
// per byte. MSB=1 indica "tem mais byte". Max 10 bytes (UInt64).
function TRarFile.ReadVInt: UInt64;
var
  B: Byte;
  Shift: Integer;
begin
  Result := 0;
  Shift := 0;
  while Shift < 64 do
  begin
    B := ReadByte_;
    Result := Result or (UInt64(B and $7F) shl Shift);
    if (B and $80) = 0 then Exit;
    Inc(Shift, 7);
  end;
  raise ERarError.Create('TRarFile.ReadVInt: vint overflow (>10 bytes)');
end;

function TRarFile.ReadBytes(ACount: Integer): TBytes;
begin
  SetLength(Result, ACount);
  if ACount > 0 then FStream.ReadBuffer(Result[0], ACount);
end;

function TRarFile.DetectFormat: Boolean;
var
  Marker: TBytes;
begin
  Result := False;
  FIsRar5 := False;
  FStream.Position := 0;
  // fix v3: o guard original (< 7) permitia ReadBytes(8) alem do fim num
  // ficheiro de exactamente 7 bytes -> EReadError da RTL em vez de False
  if FStream.Size < 8 then Exit;

  Marker := ReadBytes(8);

  // RAR5: "Rar!\x1A\x07\x01\x00" (8 bytes)
  if (Marker[0] = $52) and (Marker[1] = $61) and (Marker[2] = $72) and (Marker[3] = $21) and
     (Marker[4] = $1A) and (Marker[5] = $07) and (Marker[6] = $01) and (Marker[7] = $00) then
  begin
    FIsRar5 := True;
    Result := True;
    Exit;
  end;

  // RAR4: "Rar!\x1A\x07\x00" (7 bytes) — deferido v3.5.1
  if (Marker[0] = $52) and (Marker[1] = $61) and (Marker[2] = $72) and (Marker[3] = $21) and
     (Marker[4] = $1A) and (Marker[5] = $07) and (Marker[6] = $00) then
  begin
    raise ERarUnsupportedFormat.Create(
      'TRarFile: RAR4 (legacy) format detectado, mas apenas RAR5 implementado em v3.5. ' +
      'Use rar.exe -ma5 (ou WinRAR 5+) para criar RAR5.');
  end;

  // Nada reconhecido
end;

procedure TRarFile.ParseRar5;
var
  BlockStart, HeaderEnd, BlockEnd: Int64;
  BlockCrc: Cardinal;
  HeaderSize, BlockType, BlockFlags: UInt64;
  ExtraSize, DataSize: UInt64;
  FileFlags, UnpSize, Attrs, CompInfo, HostOs, NameLen, MTime: UInt64;
  CrcField: Cardinal;
  NameBytes: TBytes;
  Entry: TRarEntry;
  AnsiName: AnsiString;
  IsDir: Boolean;
begin
  // Posicao apos marker (8 bytes RAR5)
  FStream.Position := RAR5_MARKER_LEN;

  while FStream.Position < FStream.Size do
  begin
    BlockStart := FStream.Position;

    BlockCrc := ReadLEUInt32;  // header CRC32 (apenas low 32 bits)
    HeaderSize := ReadVInt;    // header size (excluindo este vint e CRC field)
    HeaderEnd := FStream.Position + Int64(HeaderSize);
    BlockType := ReadVInt;
    BlockFlags := ReadVInt;

    ExtraSize := 0;
    DataSize := 0;
    if (BlockFlags and RAR_BLOCK_FLAG_EXTRA) <> 0 then
      ExtraSize := ReadVInt;
    if (BlockFlags and RAR_BLOCK_FLAG_DATA) <> 0 then
      DataSize := ReadVInt;

    case BlockType of
      RAR_BLOCK_END:
        Exit;

      RAR_BLOCK_MAIN:
        ; // archive header — ignored para listing

      RAR_BLOCK_FILE:
        begin
          FileFlags := ReadVInt;
          UnpSize := ReadVInt;
          Attrs := ReadVInt;
          MTime := 0;
          if (FileFlags and RAR_FILE_FLAG_HAS_MTIME) <> 0 then
          begin
            MTime := ReadLEUInt32;
          end;
          CrcField := 0;
          if (FileFlags and RAR_FILE_FLAG_HAS_CRC32) <> 0 then
            CrcField := ReadLEUInt32;
          CompInfo := ReadVInt;
          HostOs := ReadVInt;
          NameLen := ReadVInt;
          NameBytes := ReadBytes(Integer(NameLen));

          IsDir := (FileFlags and RAR_FILE_FLAG_DIRECTORY) <> 0;

          Entry.UnpackedSize := Int64(UnpSize);
          Entry.PackedSize := Int64(DataSize);
          Entry.Attributes := Cardinal(Attrs);
          Entry.Mtime := MTime;
          Entry.FileCRC32 := CrcField;
          // CompInfo: bits 0..5 = version, bit 6 = solid, bits 7..9 = method
          // (method 0 = store), bits 10..13 = dict size, bits 14+ = reserved
          Entry.Version := Byte(CompInfo and $3F);
          Entry.Method := Byte((CompInfo shr 7) and $7);
          Entry.HostOS := Byte(HostOs);
          Entry.IsDirectory := IsDir;

          if Length(NameBytes) > 0 then
          begin
            SetLength(AnsiName, Length(NameBytes));
            Move(NameBytes[0], AnsiName[1], Length(NameBytes));
            Entry.FileName := UTF8ToString(AnsiName);
          end
          else
            Entry.FileName := '';

          // Data offset = posicao apos header (e extra area), o que e HeaderEnd
          Entry.DataOffset := HeaderEnd;

          SetLength(FEntries, Length(FEntries) + 1);
          FEntries[High(FEntries)] := Entry;
        end;

      // RAR_BLOCK_SERVICE, RAR_BLOCK_ENCRYPTION: skip
    end;

    // Avanca para apos header + data
    BlockEnd := HeaderEnd + Int64(DataSize);
    if BlockEnd <= BlockStart then Break;  // sanity (corrupt)
    FStream.Position := BlockEnd;
  end;
end;

procedure TRarFile.Open;
begin
  if FActive then Exit;
  if FFileName = '' then
    raise ERarError.Create('TRarFile.Open: FileName not set');
  FStream := TFileStream.Create(FFileName, fmOpenRead or fmShareDenyWrite);
  try
    if not DetectFormat then
      raise ERarError.Create('TRarFile.Open: nao e RAR archive valido (marker nao encontrado)');
    SetLength(FEntries, 0);
    ParseRar5;
    FActive := True;
  except
    FStream.Free;
    FStream := nil;
    raise;
  end;
end;

procedure TRarFile.Close;
begin
  if Assigned(FStream) then
  begin
    FStream.Free;
    FStream := nil;
  end;
  SetLength(FEntries, 0);
  FIsRar5 := False;
  FActive := False;
end;

function TRarFile.GetEntryCount: Integer;
begin Result := Length(FEntries); end;

function TRarFile.IsDir(AIndex: Integer): Boolean;
begin
  Result := (AIndex >= 0) and (AIndex < Length(FEntries)) and FEntries[AIndex].IsDirectory;
end;

function TRarFile.GetFileSize(AIndex: Integer): Int64;
begin
  if (AIndex >= 0) and (AIndex < Length(FEntries)) then
    Result := FEntries[AIndex].UnpackedSize
  else Result := 0;
end;

function TRarFile.GetEntryName(AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex < Length(FEntries)) then
    Result := FEntries[AIndex].FileName
  else Result := '';
end;

function TRarFile.GetEntryMethod(AIndex: Integer): Byte;
begin
  if (AIndex >= 0) and (AIndex < Length(FEntries)) then
    Result := FEntries[AIndex].Method
  else Result := 255;
end;

function TRarFile.FindIndex(const AName: string): Integer;
var I: Integer;
begin
  for I := 0 to High(FEntries) do
    if SameText(FEntries[I].FileName, AName) then Exit(I);
  Result := -1;
end;

function TRarFile.FileExists(const AName: string): Boolean;
begin Result := FindIndex(AName) >= 0; end;

function TRarFile.ReadAsBytes(const AName: string): TBytes;
var Idx: Integer;
begin
  if not FActive then raise ERarError.Create('TRarFile.ReadAsBytes: nao aberto');
  Idx := FindIndex(AName);
  if Idx < 0 then
    raise ERarError.CreateFmt('TRarFile.ReadAsBytes: entry nao encontrada "%s"', [AName]);
  if FEntries[Idx].IsDirectory then
    raise ERarError.CreateFmt('TRarFile.ReadAsBytes: "%s" eh um diretorio', [AName]);

  // Method 0 = stored. Methods 1-5 = LZSS/PPMd — deferidos v3.5.1.
  if FEntries[Idx].Method <> 0 then
    raise ERarMethodNotSupported.CreateFmt(
      'TRarFile.ReadAsBytes: method %d nao suportado em v3.5 (apenas method 0 / Store; ' +
      'LZSS/PPMd deferidos v3.5.1 via static-link sdk/unrar)', [FEntries[Idx].Method]);

  SetLength(Result, FEntries[Idx].UnpackedSize);
  if FEntries[Idx].UnpackedSize > 0 then
  begin
    FStream.Position := FEntries[Idx].DataOffset;
    FStream.ReadBuffer(Result[0], FEntries[Idx].UnpackedSize);
  end;
end;

function TRarFile.ReadAsString(const AName: string): string;
var B: TBytes;
begin
  B := ReadAsBytes(AName);
  if Length(B) = 0 then Result := ''
  else Result := TEncoding.UTF8.GetString(B);
end;

function TRarFile.GetEntryStream(const AName: string): TStream;
var B: TBytes;
begin
  B := ReadAsBytes(AName);
  Result := TMemoryStream.Create;
  if Length(B) > 0 then Result.WriteBuffer(B[0], Length(B));
  Result.Position := 0;
end;

function TRarFile.WithFileName(const APath: string): TRarFile;
begin SetFileName(APath); Result := Self; end;

function TRarFile.ThatOpens: TRarFile;
begin Open; Result := Self; end;

end.
