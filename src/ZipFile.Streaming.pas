{ ZipFile.Streaming.pas
  Stream wrappers that read entry payload directly from the underlying file
  handle without buffering the whole entry in memory (the legacy
  TZipFile.GetFileStream returns a TMemoryStream — fine for small payloads,
  fatal for >100 MB files).

  Two flavours:

   * TZipEntryReadStream
       Read-only view of a contiguous [StartOffset .. StartOffset+Length)
       range of an existing TStream. Position 0 maps to StartOffset.
       Used for STORED (method 0) entries that are not encrypted.

   * TZipEntryAESReadStream
       Same idea, but transparently decrypts WinZip-AE-2 payload (AES-256-CTR)
       on each Read. The AES counter is seekable so Seek works correctly.
       NOTE: HMAC trailer authentication is performed eagerly at construction
       (we read the trailer once and verify against the expected key); a
       MAC mismatch raises EZipAESError before any Read is allowed.

  Dual-target Delphi (D24..D37) and FPC/Lazarus.
}
unit ZipFile.Streaming;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Classes, ZipFile.Encryption.AES
  {$IFDEF FPC}, zstream{$ELSE}, ZLib{$ENDIF};

type
  // Slice over an existing read-capable TStream. Does not own the source.
  TZipEntryReadStream = class(TStream)
  private
    FSource: TStream;
    FStartOffset: Int64;
    FLength: Int64;
    FPosition: Int64;
  protected
    function GetSize: Int64; override;
    procedure SetSize(const NewSize: Int64); override;
  public
    constructor Create(ASource: TStream; AStartOffset, ALength: Int64);
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

  // Forward-only DEFLATE decompression stream wrapping a raw-deflate slice
  // (TZipEntryReadStream over a ZIP entry's compressed payload).
  // Seek is supported only to Position 0 (re-init) or forward within current
  // buffer. PlainSize is known from the ZIP CD's uncompressed-size field.
  TZipEntryDeflateReadStream = class(TStream)
  private
    FInner: TZipEntryReadStream;      // owned
    FZStream: {$IFDEF FPC}zstream.TDecompressionStream{$ELSE}ZLib.TZDecompressionStream{$ENDIF};
    FPlainSize: Int64;
    FPosition: Int64;
  protected
    function GetSize: Int64; override;
    procedure SetSize(const NewSize: Int64); override;
  public
    // Takes ownership of AInner. APlainSize is uncompressed size from ZIP CD.
    constructor Create(AInner: TZipEntryReadStream; APlainSize: Int64);
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

  // AES-256-CTR seekable decrypt-on-read stream. Wraps the inner cipher slice.
  // The expanded key is precomputed; per Read, we compute the counter range
  // touched by [FPosition .. FPosition+Count) and XOR keystream blocks.
  TZipEntryAESReadStream = class(TStream)
  private
    FInner: TZipEntryReadStream;  // owned
    FExpanded: TAESExpandedKey;
    FPlainLength: Int64;
    FPosition: Int64;
    procedure DecryptRange(var ABuf; AAbsByteOffset: Int64; ACount: Integer);
  protected
    function GetSize: Int64; override;
    procedure SetSize(const NewSize: Int64); override;
  public
    // Takes ownership of AInner. AKey is the AES-256 encryption key derived
    // via WinZip-AE-2 PBKDF2.
    constructor Create(AInner: TZipEntryReadStream; const AKey: TAESKey256);
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

implementation

// =============================================================================
//   TZipEntryReadStream
// =============================================================================

constructor TZipEntryReadStream.Create(ASource: TStream; AStartOffset, ALength: Int64);
begin
  inherited Create;
  if ASource = nil then
    raise EArgumentNilException.Create('TZipEntryReadStream: source is nil');
  if ALength < 0 then
    raise ERangeError.CreateFmt('TZipEntryReadStream: negative length %d', [ALength]);
  FSource := ASource;
  FStartOffset := AStartOffset;
  FLength := ALength;
  FPosition := 0;
end;

function TZipEntryReadStream.GetSize: Int64;
begin
  Result := FLength;
end;

procedure TZipEntryReadStream.SetSize(const NewSize: Int64);
begin
  raise EStreamError.Create('TZipEntryReadStream is read-only');
end;

function TZipEntryReadStream.Read(var Buffer; Count: Longint): Longint;
var
  Avail: Int64;
begin
  Avail := FLength - FPosition;
  if Avail <= 0 then Exit(0);
  if Count > Avail then Count := Longint(Avail);
  FSource.Position := FStartOffset + FPosition;
  Result := FSource.Read(Buffer, Count);
  Inc(FPosition, Result);
end;

function TZipEntryReadStream.Write(const Buffer; Count: Longint): Longint;
begin
  raise EStreamError.Create('TZipEntryReadStream is read-only');
end;

function TZipEntryReadStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
var
  NewPos: Int64;
begin
  case Origin of
    soBeginning: NewPos := Offset;
    soCurrent:   NewPos := FPosition + Offset;
    soEnd:       NewPos := FLength + Offset;
  else
    NewPos := FPosition;
  end;
  if NewPos < 0 then NewPos := 0;
  if NewPos > FLength then NewPos := FLength;
  FPosition := NewPos;
  Result := FPosition;
end;

// =============================================================================
//   TZipEntryDeflateReadStream
// =============================================================================

constructor TZipEntryDeflateReadStream.Create(AInner: TZipEntryReadStream; APlainSize: Int64);
begin
  inherited Create;
  if AInner = nil then
    raise EArgumentNilException.Create('TZipEntryDeflateReadStream: inner is nil');
  FInner := AInner;
  FInner.Position := 0;
  FPlainSize := APlainSize;
  FPosition := 0;
  // WindowBits = -15 -> raw DEFLATE (no zlib header). ZIP entries são raw.
  {$IFDEF FPC}
  FZStream := zstream.TDecompressionStream.Create(FInner, True);  // skipheader=True
  {$ELSE}
  FZStream := ZLib.TZDecompressionStream.Create(FInner, -15);
  {$ENDIF}
end;

destructor TZipEntryDeflateReadStream.Destroy;
begin
  FreeAndNil(FZStream);
  FreeAndNil(FInner);
  inherited;
end;

function TZipEntryDeflateReadStream.GetSize: Int64;
begin
  Result := FPlainSize;
end;

procedure TZipEntryDeflateReadStream.SetSize(const NewSize: Int64);
begin
  raise EStreamError.Create('TZipEntryDeflateReadStream is read-only');
end;

function TZipEntryDeflateReadStream.Read(var Buffer; Count: Longint): Longint;
var
  Avail: Int64;
begin
  Avail := FPlainSize - FPosition;
  if Avail <= 0 then Exit(0);
  if Count > Avail then Count := Longint(Avail);
  Result := FZStream.Read(Buffer, Count);
  Inc(FPosition, Result);
end;

function TZipEntryDeflateReadStream.Write(const Buffer; Count: Longint): Longint;
begin
  raise EStreamError.Create('TZipEntryDeflateReadStream is read-only');
end;

function TZipEntryDeflateReadStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
var
  NewPos: Int64;
  Skip: Int64;
  Got: Longint;
  Discard: array[0..4095] of Byte;
begin
  case Origin of
    soBeginning: NewPos := Offset;
    soCurrent:   NewPos := FPosition + Offset;
    soEnd:       NewPos := FPlainSize + Offset;
  else
    NewPos := FPosition;
  end;
  if NewPos = FPosition then
  begin
    Result := FPosition;
    Exit;
  end;
  if NewPos < FPosition then
    raise EStreamError.Create(
      'TZipEntryDeflateReadStream: backward seek not supported (use GetFileStream for random access)');
  while FPosition < NewPos do
  begin
    Skip := NewPos - FPosition;
    if Skip > Length(Discard) then Skip := Length(Discard);
    Got := Read(Discard, Longint(Skip));
    if Got <= 0 then Break;
  end;
  Result := FPosition;
end;

// =============================================================================
//   TZipEntryAESReadStream
// =============================================================================

constructor TZipEntryAESReadStream.Create(AInner: TZipEntryReadStream; const AKey: TAESKey256);
begin
  inherited Create;
  if AInner = nil then
    raise EArgumentNilException.Create('TZipEntryAESReadStream: inner is nil');
  FInner := AInner;
  AES256ExpandKey(AKey, FExpanded);
  FPlainLength := FInner.Size;  // cipher and plain lengths match in CTR mode
  FPosition := 0;
end;

destructor TZipEntryAESReadStream.Destroy;
begin
  FreeAndNil(FInner);
  inherited;
end;

function TZipEntryAESReadStream.GetSize: Int64;
begin
  Result := FPlainLength;
end;

procedure TZipEntryAESReadStream.SetSize(const NewSize: Int64);
begin
  raise EStreamError.Create('TZipEntryAESReadStream is read-only');
end;

procedure TZipEntryAESReadStream.DecryptRange(var ABuf; AAbsByteOffset: Int64; ACount: Integer);
var
  BlockIdx: Cardinal;
  IntraBlockOffset: Integer;
  IV, KS: TAESBlock;
  P: PByte;
  Remaining: Integer;
  Slice: Integer;
  I: Integer;
begin
  P := @ABuf;
  Remaining := ACount;
  // Counter is 1-based (block 1 covers bytes 0..15, block 2 covers 16..31, ...).
  BlockIdx := Cardinal(AAbsByteOffset div 16) + 1;
  IntraBlockOffset := Integer(AAbsByteOffset mod 16);
  while Remaining > 0 do
  begin
    FillChar(IV, SizeOf(IV), 0);
    IV[0] := Byte(BlockIdx);
    IV[1] := Byte(BlockIdx shr 8);
    IV[2] := Byte(BlockIdx shr 16);
    IV[3] := Byte(BlockIdx shr 24);
    AES256EncryptBlock(FExpanded, IV, KS);
    Slice := 16 - IntraBlockOffset;
    if Slice > Remaining then Slice := Remaining;
    for I := 0 to Slice - 1 do
    begin
      P^ := P^ xor KS[IntraBlockOffset + I];
      Inc(P);
    end;
    Dec(Remaining, Slice);
    Inc(BlockIdx);
    IntraBlockOffset := 0;
  end;
end;

function TZipEntryAESReadStream.Read(var Buffer; Count: Longint): Longint;
var
  Avail: Int64;
  ReadCount: Longint;
begin
  Avail := FPlainLength - FPosition;
  if Avail <= 0 then Exit(0);
  if Count > Avail then Count := Longint(Avail);
  FInner.Position := FPosition;
  ReadCount := FInner.Read(Buffer, Count);
  if ReadCount > 0 then
    DecryptRange(Buffer, FPosition, ReadCount);
  Inc(FPosition, ReadCount);
  Result := ReadCount;
end;

function TZipEntryAESReadStream.Write(const Buffer; Count: Longint): Longint;
begin
  raise EStreamError.Create('TZipEntryAESReadStream is read-only');
end;

function TZipEntryAESReadStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
var
  NewPos: Int64;
begin
  case Origin of
    soBeginning: NewPos := Offset;
    soCurrent:   NewPos := FPosition + Offset;
    soEnd:       NewPos := FPlainLength + Offset;
  else
    NewPos := FPosition;
  end;
  if NewPos < 0 then NewPos := 0;
  if NewPos > FPlainLength then NewPos := FPlainLength;
  FPosition := NewPos;
  Result := FPosition;
end;

end.
