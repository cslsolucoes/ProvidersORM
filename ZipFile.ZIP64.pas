{ ZipFile.ZIP64.pas
  ZIP64 extension format support per PKWARE APPNOTE 4.5 / 4.6.
  Dual-target Delphi (D24..D37) and FPC/Lazarus.

  ZIP64 is required when ANY of these conditions hold:
    - Compressed or uncompressed size > 4 GB (0xFFFFFFFF)
    - Number of entries > 65535
    - Central directory size > 4 GB
    - Local header offset > 4 GB

  When required, the standard 32-bit fields in LocalFileHeader / CDFileHeader /
  EndOfCentralDirectoryRecord are set to 0xFFFFFFFF (or 0xFFFF for count fields)
  and the actual 64-bit values live in:

    1. ZIP64 Extended Information Extra Field (in LFH/CDH extra area)
       Header ID = 0x0001, contains uncompressed_size, compressed_size,
       relative_offset, disk_start_number (each present only if the
       corresponding 32-bit field is 0xFFFFFFFF/0xFFFF).

    2. ZIP64 End of Central Directory Record (signature 0x06064b50)
       New EOCD with 64-bit sizes / offsets / count.

    3. ZIP64 End of Central Directory Locator (signature 0x07064b50)
       Locator with 64-bit offset to ZIP64 EOCD.

  Reader logic: find standard EOCD (0x06054b50), then look backwards 20 bytes
  for ZIP64 EOCD Locator signature; if found, follow to ZIP64 EOCD.

  Writer logic: when writing final EOCD, if ANY ZIP64 trigger condition holds,
  write ZIP64 EOCD + Locator BEFORE standard EOCD; in the standard EOCD set the
  affected fields to 0xFFFFFFFF / 0xFFFF as sentinel.
}
unit ZipFile.ZIP64;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils;  // TBytes

const
  // ZIP64 markers used in 32-bit fields to indicate "see ZIP64 extra field"
  ZIP64_MAGIC_32 = $FFFFFFFF;
  ZIP64_MAGIC_16 = $FFFF;

  // Header ID for ZIP64 Extended Information Extra Field (LFH/CDH extra area)
  ZIP64_EXTRA_FIELD_ID = $0001;

  // Signatures
  ZIP64_END_OF_CD_RECORD_SIGNATURE  = $06064B50;
  ZIP64_END_OF_CD_LOCATOR_SIGNATURE = $07064B50;
  STANDARD_EOCD_SIGNATURE           = $06054B50;

type
  // ZIP64 End Of Central Directory Record (APPNOTE 4.3.14)
  TZip64EndOfCentralDirectoryRecord = packed record
    Signature: Cardinal;                  // 0x06064b50
    SizeOfRecord: UInt64;                 // size of remainder of this record
    VersionMadeBy: Word;
    VersionNeeded: Word;
    DiskNumber: Cardinal;
    DiskWithCDStart: Cardinal;
    EntriesOnThisDisk: UInt64;
    TotalEntries: UInt64;
    CDSize: UInt64;
    CDOffset: UInt64;
    // Variable: zip64 extensible data sector (size derived from SizeOfRecord)
  end;

  // ZIP64 End Of Central Directory Locator (APPNOTE 4.3.15) - fixed 20 bytes
  TZip64EndOfCentralDirectoryLocator = packed record
    Signature: Cardinal;                  // 0x07064b50
    DiskWithZip64EOCD: Cardinal;
    Zip64EOCDOffset: UInt64;
    TotalDisks: Cardinal;
  end;

  // ZIP64 Extended Information Extra Field DATA portion (APPNOTE 4.5.3).
  // The full extra field on disk is: [HeaderID=0x0001][DataSize][Data].
  // Only the data fields that correspond to 0xFFFFFFFF/0xFFFF standard fields
  // are present. Order is fixed: UncompressedSize, CompressedSize, RelativeOffset,
  // DiskStartNumber. Up to 28 bytes.
  TZip64ExtraFieldData = packed record
    HeaderID: Word;       // 0x0001
    DataSize: Word;       // size of the following data block
    // Followed by 0..28 bytes of variable data (parsed by helpers below).
  end;

// --- Detection helpers ---

// Returns True if any field in the entry requires ZIP64 encoding.
function NeedsZip64Entry(const UncompressedSize, CompressedSize, RelativeOffset: Int64): Boolean;

// Returns True if the archive itself needs ZIP64 EOCD (too many entries or
// central directory too large or too far from start of file).
function NeedsZip64Archive(const EntryCount, CDSize, CDOffset: Int64): Boolean;

// Build the variable-size ZIP64 extra field payload (without the HeaderID/DataSize
// prefix). UncompressedSize is included if the standard CDH `uncompressed_size`
// field is set to 0xFFFFFFFF; same logic for the others. Caller decides which
// fields to include via the Include* parameters.
function BuildZip64ExtraFieldPayload(
  const UncompressedSize, CompressedSize, RelativeOffset: Int64;
  const DiskStart: Cardinal;
  const IncludeUncompressed, IncludeCompressed, IncludeOffset, IncludeDiskStart: Boolean
): TBytes;

// Parse a ZIP64 extra field DATA block (i.e. the bytes AFTER the HeaderID/DataSize
// prefix). The four Include* booleans must match what the corresponding standard
// fields contain (0xFFFFFFFF / 0xFFFF) so we know which Int64s are present.
procedure ParseZip64ExtraFieldPayload(
  const Data: TBytes;
  const IncludeUncompressed, IncludeCompressed, IncludeOffset, IncludeDiskStart: Boolean;
  out UncompressedSize, CompressedSize, RelativeOffset: Int64;
  out DiskStart: Cardinal
);

implementation

function NeedsZip64Entry(const UncompressedSize, CompressedSize, RelativeOffset: Int64): Boolean;
begin
  Result := (UncompressedSize >= Int64(ZIP64_MAGIC_32))
         or (CompressedSize   >= Int64(ZIP64_MAGIC_32))
         or (RelativeOffset   >= Int64(ZIP64_MAGIC_32));
end;

function NeedsZip64Archive(const EntryCount, CDSize, CDOffset: Int64): Boolean;
begin
  Result := (EntryCount >= Int64(ZIP64_MAGIC_16))
         or (CDSize     >= Int64(ZIP64_MAGIC_32))
         or (CDOffset   >= Int64(ZIP64_MAGIC_32));
end;

function BuildZip64ExtraFieldPayload(
  const UncompressedSize, CompressedSize, RelativeOffset: Int64;
  const DiskStart: Cardinal;
  const IncludeUncompressed, IncludeCompressed, IncludeOffset, IncludeDiskStart: Boolean
): TBytes;
var
  Size: Integer;
  P: Integer;
  V64: UInt64;
  V32: Cardinal;
begin
  Size := 0;
  if IncludeUncompressed then Inc(Size, 8);
  if IncludeCompressed   then Inc(Size, 8);
  if IncludeOffset       then Inc(Size, 8);
  if IncludeDiskStart    then Inc(Size, 4);
  SetLength(Result, Size);
  P := 0;
  if IncludeUncompressed then begin
    V64 := UInt64(UncompressedSize);
    Move(V64, Result[P], 8); Inc(P, 8);
  end;
  if IncludeCompressed then begin
    V64 := UInt64(CompressedSize);
    Move(V64, Result[P], 8); Inc(P, 8);
  end;
  if IncludeOffset then begin
    V64 := UInt64(RelativeOffset);
    Move(V64, Result[P], 8); Inc(P, 8);
  end;
  if IncludeDiskStart then begin
    V32 := DiskStart;
    Move(V32, Result[P], 4); Inc(P, 4);
  end;
end;

procedure ParseZip64ExtraFieldPayload(
  const Data: TBytes;
  const IncludeUncompressed, IncludeCompressed, IncludeOffset, IncludeDiskStart: Boolean;
  out UncompressedSize, CompressedSize, RelativeOffset: Int64;
  out DiskStart: Cardinal
);
var
  P: Integer;
  V64: UInt64;
  V32: Cardinal;
begin
  UncompressedSize := 0;
  CompressedSize   := 0;
  RelativeOffset   := 0;
  DiskStart        := 0;
  P := 0;
  if IncludeUncompressed and (P + 8 <= Length(Data)) then begin
    Move(Data[P], V64, 8); UncompressedSize := Int64(V64); Inc(P, 8);
  end;
  if IncludeCompressed and (P + 8 <= Length(Data)) then begin
    Move(Data[P], V64, 8); CompressedSize := Int64(V64); Inc(P, 8);
  end;
  if IncludeOffset and (P + 8 <= Length(Data)) then begin
    Move(Data[P], V64, 8); RelativeOffset := Int64(V64); Inc(P, 8);
  end;
  if IncludeDiskStart and (P + 4 <= Length(Data)) then begin
    Move(Data[P], V32, 4); DiskStart := V32; Inc(P, 4);
  end;
end;

end.
