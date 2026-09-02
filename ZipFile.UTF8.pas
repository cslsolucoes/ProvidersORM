{ ZipFile.UTF8.pas

  Helper unit for filename encoding/decoding in ZIP archives per
  PKWARE APPNOTE 4.4.4 (Language encoding flag, bit 11 of GP flag).

  When bit 11 of General Purpose Bit Flag is set, the file_name and
  comment fields MUST be encoded in UTF-8. When cleared, they are
  encoded in the original IBM CP437 (DOS Latin) character set.

  Dual-target Delphi (D24..D37) and FPC/Lazarus.
}
unit ZipFile.UTF8;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils;

const
  // Bit 11 of General Purpose Bit Flag (LFH/CDFileHeader)
  GP_FLAG_UTF8 = $0800;

// Returns True if the string contains characters outside ASCII range (>127)
// and therefore needs UTF-8 encoding to be losslessly represented.
function NeedsUtf8Encoding(const S: string): Boolean;

// Encode a filename for storage in ZIP.
// If UseUtf8 is True, returns UTF-8 bytes (and caller must set GP flag bit 11).
// If False, returns CP437 / system default ANSI bytes (legacy behavior).
function EncodeFilename(const S: string; UseUtf8: Boolean): RawByteString;

// Decode a filename read from ZIP.
// If GP flag bit 11 was set, decode as UTF-8.
// Otherwise decode as CP437 (which is the legacy PKZIP default).
function DecodeFilename(const Raw: RawByteString; GPFlagBit11: Boolean): string;

// Convenience: check the GP flag for the UTF-8 bit.
function IsUtf8Flagged(const GPFlag: Word): Boolean; inline;

// Round-tripping arbitrary bytes through a `string` field in Delphi/Unicode is
// lossy when the default ANSI codepage doesn't map all 256 byte values.
// These helpers preserve byte values exactly by treating each byte as a
// 16-bit code point in the WideChar range 0..255 (no codepage conversion).
function BytesToStr(const B: RawByteString): string;
function StrToBytes(const S: string): RawByteString;

implementation

function NeedsUtf8Encoding(const S: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to Length(S) do
    if Ord(S[I]) > 127 then
      Exit(True);
end;

function EncodeFilename(const S: string; UseUtf8: Boolean): RawByteString;
{$IFDEF FPC}
var
  U: UTF8String;
{$ENDIF}
begin
  if UseUtf8 then
  begin
    {$IFDEF FPC}
    U := UTF8Encode(S);
    Result := RawByteString(U);
    {$ELSE}
    // Delphi: System.SysUtils.UTF8Encode returns RawByteString in modern versions
    Result := UTF8Encode(S);
    {$ENDIF}
  end
  else
  begin
    // CP437/ANSI legacy. RawByteString assignment from unicode does default conversion.
    Result := RawByteString(AnsiString(S));
  end;
end;

function DecodeFilename(const Raw: RawByteString; GPFlagBit11: Boolean): string;
begin
  if GPFlagBit11 then
  begin
    {$IFDEF FPC}
    Result := UTF8Decode(string(Raw));
    {$ELSE}
    Result := UTF8ToString(Raw);
    {$ENDIF}
  end
  else
  begin
    // Decode as ANSI (system default). For strict CP437, callers should use
    // an explicit CP437->Unicode mapping (not implemented here).
    Result := string(AnsiString(Raw));
  end;
end;

function IsUtf8Flagged(const GPFlag: Word): Boolean;
begin
  Result := (GPFlag and GP_FLAG_UTF8) <> 0;
end;

function BytesToStr(const B: RawByteString): string;
{$IFDEF FPC}
begin
  Result := string(B);  // FPC: string=AnsiString, raw bytes preserved.
end;
{$ELSE}
var
  I, N: Integer;
begin
  N := Length(B);
  SetLength(Result, N);
  for I := 1 to N do
    Result[I] := WideChar(Byte(B[I]));
end;
{$ENDIF}

function StrToBytes(const S: string): RawByteString;
{$IFDEF FPC}
begin
  Result := RawByteString(S);
end;
{$ELSE}
var
  I, N: Integer;
begin
  N := Length(S);
  SetLength(Result, N);
  for I := 1 to N do
    Result[I] := AnsiChar(Byte(Ord(S[I]) and $FF));
end;
{$ENDIF}

end.
