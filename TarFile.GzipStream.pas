{ TarFile.GzipStream.pas

  Streams Gzip (RFC 1952) sobre TStream. Wraps:
  - Delphi: System.ZLib (TZCompressionStream/TZDecompressionStream com
    parametro WindowBits = 31 que ativa gzip header em vez de zlib raw)
  - FPC: zstream unit (paszlib) nao envolve o wrapper gzip do RFC 1952; a
    unit faz o header e o trailer a mao e usa raw deflate/inflate
    (skipheader=True) para o payload. Cross-compiler completo (fix bug-046, v3).

  API:
  - TGzipReadStream(InnerStream): le bytes gzipped do inner e devolve
    inflated em sequencia (Read/Seek-from-current)
  - TGzipWriteStream(OutStream, Level): escreve plain bytes; gzipped sai
    no OutStream. Flush+close em Destroy

  Dual-target Delphi (D24..D37) e FPC/Lazarus.

  Nota: Seek backwards nao e suportado em modo streaming gzip (inflate
  e stateful). Para acesso randomico, use TMemoryStream intermediario.
}
unit TarFile.GzipStream;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Classes
  {$IFNDEF FPC}, System.ZLib{$ELSE}, ZStream{$ENDIF}, Exceptions.Base;

type
  EGzipStreamError = class(EExceptionBase);

  // Read-only wrap: inner = arquivo .gz no disco; cliente le bytes inflated.
  TGzipReadStream = class(TStream)
  private
    FInner: TStream;
    FOwnsInner: Boolean;
    {$IFNDEF FPC}
    FZStream: TZDecompressionStream;
    {$ELSE}
    FZStream: TDecompressionStream;
    {$ENDIF}
    FPosition: Int64;
  protected
    function GetSize: Int64; override;
    procedure SetSize(const NewSize: Int64); override;
  public
    constructor Create(AInner: TStream; AOwnsInner: Boolean = False);
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

  // Write-only wrap: cliente escreve plain bytes; gzipped sai no Inner.
  TGzipWriteStream = class(TStream)
  private
    FInner: TStream;
    FOwnsInner: Boolean;
    {$IFNDEF FPC}
    FZStream: TZCompressionStream;
    {$ELSE}
    FZStream: TCompressionStream;
    FCrc32: Cardinal;   // CRC32 (IEEE, invertido) dos dados crus, para o trailer
    FRawSize: Int64;    // total de bytes crus escritos, para o ISIZE
    {$ENDIF}
    FPosition: Int64;
  protected
    function GetSize: Int64; override;
    procedure SetSize(const NewSize: Int64); override;
  public
    // ALevel: 1..9 (1=fast, 9=best). Default 6 = balance.
    constructor Create(AInner: TStream; ALevel: Integer = 6; AOwnsInner: Boolean = False);
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

// Helpers de conveniencia:
procedure GzipCompressBuffer(const ASrc: TBytes; out ADst: TBytes; ALevel: Integer = 6);
procedure GzipDecompressBuffer(const ASrc: TBytes; out ADst: TBytes);

implementation

{$IFDEF FPC}
// =============================================================================
//   Suporte gzip manual para FPC. O paszlib so produz/le zlib ou raw deflate;
//   fazemos o header (RFC 1952) e o trailer (CRC32 + ISIZE) a mao e usamos
//   raw deflate/inflate (skipheader=True) para o payload. (fix bug-046)
// =============================================================================
const
  GZIP_ID1        = $1F;
  GZIP_ID2        = $8B;
  GZIP_CM_DEFLATE = $08;
  GZIP_FHCRC      = $02;
  GZIP_FEXTRA     = $04;
  GZIP_FNAME      = $08;
  GZIP_FCOMMENT   = $10;

var
  GzCrcTable: array[0..255] of Cardinal;

procedure InitGzCrcTable;
var
  I, J: Integer;
  C: Cardinal;
begin
  for I := 0 to 255 do
  begin
    C := Cardinal(I);
    for J := 0 to 7 do
      if (C and 1) <> 0 then
        C := $EDB88320 xor (C shr 1)
      else
        C := C shr 1;
    GzCrcTable[I] := C;
  end;
end;

function GzCrc32Update(ACrc: Cardinal; const ABuf; ALen: Integer): Cardinal;
var
  P: PByte;
  I: Integer;
begin
  Result := ACrc;
  P := @ABuf;
  for I := 0 to ALen - 1 do
  begin
    Result := GzCrcTable[(Result xor P^) and $FF] xor (Result shr 8);
    Inc(P);
  end;
end;

{ Le e salta o header gzip de AStream, deixando-o no inicio do deflate. }
procedure GzipReadAndSkipHeader(AStream: TStream);
var
  Hdr: array[0..9] of Byte;
  Flg, B: Byte;
  XLen: Word;
begin
  if AStream.Read(Hdr[0], 10) <> 10 then
    raise EGzipStreamError.Create('gzip: header truncado');
  if (Hdr[0] <> GZIP_ID1) or (Hdr[1] <> GZIP_ID2) then
    raise EGzipStreamError.Create('gzip: assinatura invalida (nao e um .gz)');
  if Hdr[2] <> GZIP_CM_DEFLATE then
    raise EGzipStreamError.Create('gzip: metodo de compressao nao suportado (so deflate)');
  Flg := Hdr[3];
  if (Flg and GZIP_FEXTRA) <> 0 then
  begin
    if AStream.Read(XLen, 2) <> 2 then
      raise EGzipStreamError.Create('gzip: campo FEXTRA truncado');
    AStream.Seek(Int64(XLen), soCurrent);
  end;
  if (Flg and GZIP_FNAME) <> 0 then
    repeat B := 0; if AStream.Read(B, 1) <> 1 then Break; until B = 0;
  if (Flg and GZIP_FCOMMENT) <> 0 then
    repeat B := 0; if AStream.Read(B, 1) <> 1 then Break; until B = 0;
  if (Flg and GZIP_FHCRC) <> 0 then
    AStream.Seek(2, soCurrent);
end;

{ Escreve um header gzip minimo (sem FNAME/FEXTRA/MTIME) em AStream. }
procedure GzipWriteHeader(AStream: TStream);
var
  Hdr: array[0..9] of Byte;
begin
  FillChar(Hdr, SizeOf(Hdr), 0);
  Hdr[0] := GZIP_ID1;
  Hdr[1] := GZIP_ID2;
  Hdr[2] := GZIP_CM_DEFLATE;
  // FLG=0, MTIME=0, XFL=0
  Hdr[9] := $FF;   // OS = desconhecido
  AStream.WriteBuffer(Hdr[0], 10);
end;
{$ENDIF}

// =============================================================================
//   TGzipReadStream
// =============================================================================

constructor TGzipReadStream.Create(AInner: TStream; AOwnsInner: Boolean);
begin
  inherited Create;
  if AInner = nil then
    raise EGzipStreamError.Create('TGzipReadStream: inner stream is nil');
  FInner := AInner;
  FOwnsInner := AOwnsInner;
  {$IFNDEF FPC}
  // System.ZLib em Delphi: WindowBits = 15+16 = 31 ativa modo gzip (em vez
  // de zlib raw). 15 = max window size; +16 = "use gzip wrapper".
  FZStream := TZDecompressionStream.Create(FInner, 31);
  {$ELSE}
  // FPC: o paszlib nao le o wrapper gzip -> saltar o header a mao e fazer
  // raw inflate (skipheader=True) sobre o deflate que se segue. (fix bug-046)
  GzipReadAndSkipHeader(FInner);
  FZStream := TDecompressionStream.Create(FInner, True);
  {$ENDIF}
  FPosition := 0;
end;

destructor TGzipReadStream.Destroy;
begin
  FreeAndNil(FZStream);
  if FOwnsInner then
    FreeAndNil(FInner);
  inherited;
end;

function TGzipReadStream.GetSize: Int64;
begin
  // Tamanho descomprimido nao e conhecido sem ler tudo. Retorna -1.
  Result := -1;
end;

procedure TGzipReadStream.SetSize(const NewSize: Int64);
begin
  raise EGzipStreamError.Create('TGzipReadStream is read-only');
end;

function TGzipReadStream.Read(var Buffer; Count: Longint): Longint;
begin
  Result := FZStream.Read(Buffer, Count);
  Inc(FPosition, Result);
end;

function TGzipReadStream.Write(const Buffer; Count: Longint): Longint;
begin
  raise EGzipStreamError.Create('TGzipReadStream is read-only');
end;

function TGzipReadStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  // Inflate e stateful; suporta apenas avanco linear (read-ahead).
  if (Origin = soCurrent) and (Offset = 0) then
    Result := FPosition
  else if (Origin = soBeginning) and (Offset = FPosition) then
    Result := FPosition
  else
    raise EGzipStreamError.Create('TGzipReadStream seek only supports current position query');
end;

// =============================================================================
//   TGzipWriteStream
// =============================================================================

constructor TGzipWriteStream.Create(AInner: TStream; ALevel: Integer; AOwnsInner: Boolean);
{$IFNDEF FPC}
var
  LLevel: TZCompressionLevel;
{$ENDIF}
begin
  inherited Create;
  if AInner = nil then
    raise EGzipStreamError.Create('TGzipWriteStream: inner stream is nil');
  FInner := AInner;
  FOwnsInner := AOwnsInner;
  {$IFNDEF FPC}
  // Mapeia 1..9 -> TZCompressionLevel
  case ALevel of
    1: LLevel := zcFastest;
    2..5: LLevel := zcDefault;
    6..8: LLevel := zcDefault;
    9: LLevel := zcMax;
  else
    LLevel := zcDefault;
  end;
  // WindowBits 31 = gzip wrapper output
  FZStream := TZCompressionStream.Create(FInner, LLevel, 31);
  {$ELSE}
  // FPC: header gzip a mao + raw deflate (skipheader=True). O trailer
  // (CRC32+ISIZE) sai no Destroy. (fix bug-046)
  GzipWriteHeader(FInner);
  FCrc32 := $FFFFFFFF;
  FRawSize := 0;
  case ALevel of
    1: FZStream := TCompressionStream.Create(clfastest, FInner, True);
    9: FZStream := TCompressionStream.Create(clmax, FInner, True);
  else
    FZStream := TCompressionStream.Create(cldefault, FInner, True);
  end;
  {$ENDIF}
  FPosition := 0;
end;

destructor TGzipWriteStream.Destroy;
{$IFDEF FPC}
var
  LTrailer: array[0..7] of Byte;
  LCrc, LSize: Cardinal;
{$ENDIF}
begin
  // FZStream.Destroy flush + close — DEVE rodar antes de FInner.Free.
  FreeAndNil(FZStream);
  {$IFDEF FPC}
  // trailer gzip (RFC 1952): CRC32 (LE) + ISIZE (LE, mod 2^32) dos dados crus
  if FInner <> nil then
  begin
    LCrc := FCrc32 xor $FFFFFFFF;
    LSize := Cardinal(FRawSize and $FFFFFFFF);
    LTrailer[0] := Byte(LCrc);         LTrailer[1] := Byte(LCrc shr 8);
    LTrailer[2] := Byte(LCrc shr 16);  LTrailer[3] := Byte(LCrc shr 24);
    LTrailer[4] := Byte(LSize);        LTrailer[5] := Byte(LSize shr 8);
    LTrailer[6] := Byte(LSize shr 16); LTrailer[7] := Byte(LSize shr 24);
    FInner.WriteBuffer(LTrailer[0], 8);
  end;
  {$ENDIF}
  if FOwnsInner then
    FreeAndNil(FInner);
  inherited;
end;

function TGzipWriteStream.GetSize: Int64;
begin
  Result := FPosition;
end;

procedure TGzipWriteStream.SetSize(const NewSize: Int64);
begin
  raise EGzipStreamError.Create('TGzipWriteStream is write-only');
end;

function TGzipWriteStream.Read(var Buffer; Count: Longint): Longint;
begin
  raise EGzipStreamError.Create('TGzipWriteStream is write-only');
end;

function TGzipWriteStream.Write(const Buffer; Count: Longint): Longint;
begin
  Result := FZStream.Write(Buffer, Count);
  {$IFDEF FPC}
  // acumula CRC32 + tamanho dos dados crus para o trailer gzip
  if Result > 0 then
  begin
    FCrc32 := GzCrc32Update(FCrc32, Buffer, Result);
    Inc(FRawSize, Result);
  end;
  {$ENDIF}
  Inc(FPosition, Result);
end;

function TGzipWriteStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  if (Origin = soCurrent) and (Offset = 0) then
    Result := FPosition
  else
    raise EGzipStreamError.Create('TGzipWriteStream seek only supports current position query');
end;

// =============================================================================
//   Helpers
// =============================================================================

procedure GzipCompressBuffer(const ASrc: TBytes; out ADst: TBytes; ALevel: Integer);
var
  OutMem: TMemoryStream;
  W: TGzipWriteStream;
begin
  OutMem := TMemoryStream.Create;
  try
    W := TGzipWriteStream.Create(OutMem, ALevel, False);
    try
      if Length(ASrc) > 0 then
        W.WriteBuffer(ASrc[0], Length(ASrc));
    finally
      W.Free; // flush+close
    end;
    SetLength(ADst, OutMem.Size);
    if OutMem.Size > 0 then
      Move(PByte(OutMem.Memory)^, ADst[0], OutMem.Size);
  finally
    OutMem.Free;
  end;
end;

procedure GzipDecompressBuffer(const ASrc: TBytes; out ADst: TBytes);
const
  CHUNK = 64 * 1024;
var
  InMem: TMemoryStream;
  R: TGzipReadStream;
  OutMem: TMemoryStream;
  Buf: array of Byte;
  N: Integer;
begin
  InMem := TMemoryStream.Create;
  try
    if Length(ASrc) > 0 then
      InMem.WriteBuffer(ASrc[0], Length(ASrc));
    InMem.Position := 0;
    R := TGzipReadStream.Create(InMem, False);
    try
      OutMem := TMemoryStream.Create;
      try
        SetLength(Buf, CHUNK);
        repeat
          N := R.Read(Buf[0], CHUNK);
          if N > 0 then
            OutMem.WriteBuffer(Buf[0], N);
        until N <= 0;
        SetLength(ADst, OutMem.Size);
        if OutMem.Size > 0 then
          Move(PByte(OutMem.Memory)^, ADst[0], OutMem.Size);
      finally
        OutMem.Free;
      end;
    finally
      R.Free;
    end;
  finally
    InMem.Free;
  end;
end;

{$IFDEF FPC}
initialization
  InitGzCrcTable;
{$ENDIF}

end.
