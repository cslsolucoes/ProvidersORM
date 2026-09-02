{*
 * ZipFile.Compression.ZLib.Bridge.pas
 *
 * Bridge entre TStream e zlib (compressão/descompressão buffer e stream).
 * Era dzlib.pas — renomeado para namespace Commons.* na refatoração v4.0.0.
 *
 * Original (c) 1997 Borland International / 1998 Jacques Nomssi Nzali /
 *          2006 Graeme Geldenhuys
 * Refactor v4.0.0 (c) 2026 CSL Softwares
 * Licença: LGPL-3.0
 *
 * Nota: este ficheiro é compilado APENAS sob FPC. Em Delphi usa-se
 * System.ZLib direto.
 *}
unit ZipFile.Compression.ZLib.Bridge;

{$MODE OBJFPC}{$H+}

{ At least FPC 2.0.2 is required }
{$if defined(ver1) or (defined(ver2_0) and (fpc_patch<2))}
  {$fatal ZipFileORM requires at least FPC 2.0.2}
{$ELSEIF (defined(ver2_0) and (fpc_patch=2))}
  {$DEFINE FPC202}
{$ELSE}
  {$DEFINE FPC202OrAbove}
{$ENDIF}

interface

uses
  zbase, Sysutils, Classes, Exceptions.Base;

type
  TZStreamRec = z_stream;

const
  FBufSize = 8192;

type
  TCustomZlibStream = class(TStream)
  private
    FStrm: TStream;
    FStrmPos: Integer;
    FOnProgress: TNotifyEvent;
    FZRec: TZStreamRec;
    FBuffer: array [0..FBufSize-1] of Char;
  protected
    procedure Progress(Sender: TObject); dynamic;
    property OnProgress: TNotifyEvent read FOnProgress write FOnProgress;
    constructor Create(Strm: TStream);
  end;

  TCompressionLevel = (clNone, clFastest, clDefault, clMax);

  TCompressionStream = class(TCustomZlibStream)
  private
    function GetCompressionRate: Single;
  public
    constructor Create(CompressionLevel: TCompressionLevel; Dest: TStream);
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(Offset: Longint; Origin: Word): Longint; override;
    property CompressionRate: Single read GetCompressionRate;
    property OnProgress;
  end;

  TDecompressionStream = class(TCustomZlibStream)
  public
    constructor Create(Source: TStream);
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(Offset: Longint; Origin: Word): Longint; override;
    property OnProgress;
  end;

procedure CompressBuf(const InBuf: Pointer; InBytes: Integer;
                      out OutBuf: Pointer; out OutBytes: Integer);

procedure DecompressBuf(const InBuf: Pointer; InBytes: Integer;
                        OutEstimate: Integer; out OutBuf: Pointer; out OutBytes: Integer);

type
  EZlibError = class(EExceptionBase);
  ECompressionError = class(EZlibError);
  EDecompressionError = class(EZlibError);

implementation

uses
  {$ifdef fpc202}
  zutil,
  {$endif}
  zDeflate, zInflate;

function zlibAllocMem(AppData: Pointer; Items, Size: Cardinal): Pointer;
begin
  GetMem(Result, Items*Size);
end;

procedure zlibFreeMem(AppData, Block: Pointer);
begin
  FreeMem(Block);
end;

function zlibCheck(code: Integer): Integer;
begin
  Result := code;
  if code < 0 then
    raise EZlibError.Create('error');
end;

function CCheck(code: Integer): Integer;
begin
  Result := code;
  if code < 0 then
    raise ECompressionError.Create('error');
end;

function DCheck(code: Integer): Integer;
begin
  Result := code;
  if code < 0 then
    raise EDecompressionError.Create('error');
end;

procedure CompressBuf(const InBuf: Pointer; InBytes: Integer;
                      out OutBuf: Pointer; out OutBytes: Integer);
var
  strm: TZStreamRec;
  P: Pointer;
begin
  FillChar(strm, sizeof(strm), 0);
  {$ifdef fpc202}
  strm.zalloc := @zlibAllocMem;
  strm.zfree := @zlibFreeMem;
  {$endif}
  OutBytes := ((InBytes + (InBytes div 10) + 12) + 255) and not 255;
  GetMem(OutBuf, OutBytes);
  try
    strm.next_in   := InBuf;
    strm.avail_in  := InBytes;
    strm.next_out  := OutBuf;
    strm.avail_out := OutBytes;
    CCheck(deflateInit_(@strm, Z_BEST_COMPRESSION, zlib_version, sizeof(strm)));
    try
      while deflate(strm, Z_FINISH) <> Z_STREAM_END do
      begin
        P := OutBuf;
        Inc(OutBytes, 256);
        ReallocMem(OutBuf, OutBytes);
        strm.next_out := {$ifdef fpc202}PBytef{$else}PByte{$endif}(PtrUInt(OutBuf) + (PtrUInt(strm.next_out) - PtrUInt(P)));
        strm.avail_out := 256;
      end;
    finally
      CCheck(deflateEnd(strm));
    end;
    ReallocMem(OutBuf, strm.total_out);
    OutBytes := strm.total_out;
  except
    zlibFreeMem(NIL, OutBuf);
    raise
  end;
end;

procedure DecompressBuf(const InBuf: Pointer; InBytes: Integer;
                        OutEstimate: Integer; out OutBuf: Pointer; out OutBytes: Integer);
var
  strm: TZStreamRec;
  P: Pointer;
  BufInc: Integer;
begin
  FillChar(strm, sizeof(strm), 0);
  {$ifdef fpc202}
  strm.zalloc := @zlibAllocMem;
  strm.zfree := @zlibFreeMem;
  {$endif}
  BufInc := (InBytes + 255) and not 255;
  if OutEstimate = 0 then
    OutBytes := BufInc
  else
    OutBytes := OutEstimate;
  GetMem(OutBuf, OutBytes);
  try
    strm.next_in   := InBuf;
    strm.avail_in  := InBytes;
    strm.next_out  := OutBuf;
    strm.avail_out := OutBytes;
    DCheck(inflateInit_(@strm, zlib_version, sizeof(strm)));
    try
      while inflate(strm, Z_FINISH) <> Z_STREAM_END do
      begin
        P := OutBuf;
        Inc(OutBytes, BufInc);
        ReallocMem(OutBuf, OutBytes);
        strm.next_out := {$ifdef fpc202}pBytef{$else}PByte{$endif}(PtrUInt(OutBuf) + (PtrUInt(strm.next_out) - PtrUInt(P)));
        strm.avail_out := BufInc;
      end;
    finally
      DCheck(inflateEnd(strm));
    end;
    ReallocMem(OutBuf, strm.total_out);
    OutBytes := strm.total_out;
  except
    zlibFreeMem(NIL, OutBuf);
    raise
  end;
end;

constructor TCustomZLibStream.Create(Strm: TStream);
begin
  inherited Create;
  FStrm        := Strm;
  FStrmPos     := Strm.Position;
  {$ifdef fpc202}
  FZRec.zalloc := @zlibAllocMem;
  FZRec.zfree  := @zlibFreeMem;
  {$endif}
end;

procedure TCustomZLibStream.Progress(Sender: TObject);
begin
  if Assigned(FOnProgress) then FOnProgress(Sender);
end;

constructor TCompressionStream.Create(CompressionLevel: TCompressionLevel;
  Dest: TStream);
const
  Levels: array [TCompressionLevel] of ShortInt =
    (Z_NO_COMPRESSION, Z_BEST_SPEED, Z_DEFAULT_COMPRESSION, Z_BEST_COMPRESSION);
begin
  inherited Create(Dest);
  FZRec.next_out := @FBuffer;
  FZRec.avail_out := sizeof(FBuffer);
  CCheck(deflateInit_(@FZRec, Levels[CompressionLevel], zlib_version, sizeof(FZRec)));
end;

destructor TCompressionStream.Destroy;
begin
  FZRec.next_in  := nil;
  FZRec.avail_in := 0;
  try
    if FStrm.Position <> FStrmPos then FStrm.Position := FStrmPos;
    while (CCheck(deflate(FZRec, Z_FINISH)) <> Z_STREAM_END)
      and (FZRec.avail_out = 0) do
    begin
      FStrm.WriteBuffer(FBuffer, sizeof(FBuffer));
      FZRec.next_out := @FBuffer;
      FZRec.avail_out := sizeof(FBuffer);
    end;
    if FZRec.avail_out < sizeof(FBuffer) then
      FStrm.WriteBuffer(FBuffer, sizeof(FBuffer) - FZRec.avail_out);
  finally
    deflateEnd(FZRec);
  end;
  inherited Destroy;
end;

function TCompressionStream.Read(var Buffer; Count: Longint): Longint;
begin
  raise ECompressionError.Create('Invalid stream operation');
end;

function TCompressionStream.Write(const Buffer; Count: Longint): Longint;
begin
  FZRec.next_in  := @Buffer;
  FZRec.avail_in := Count;
  if FStrm.Position <> FStrmPos then FStrm.Position := FStrmPos;
  while (FZRec.avail_in > 0) do
  begin
    CCheck(deflate(FZRec, 0));
    if FZRec.avail_out = 0 then
    begin
      FStrm.WriteBuffer(FBuffer, sizeof(FBuffer));
      FZRec.next_out := @FBuffer;
      FZRec.avail_out := sizeof(FBuffer);
      FStrmPos       := FStrm.Position;
      Progress(Self);
    end;
  end;
  Result := Count;
end;

function TCompressionStream.Seek(Offset: Longint; Origin: Word): Longint;
begin
  if (Offset = 0) and (Origin = soFromCurrent) then
    Result := FZRec.total_in
  else
    raise ECompressionError.Create('Invalid stream operation');
end;

function TCompressionStream.GetCompressionRate: Single;
begin
  if FZRec.total_in = 0 then
    Result := 0
  else
    Result := (1.0 - (FZRec.total_out / FZRec.total_in)) * 100.0;
end;

constructor TDecompressionStream.Create(Source: TStream);
begin
  inherited Create(Source);
  FZRec.next_in  := @FBuffer;
  FZRec.avail_in := 0;
  DCheck(inflateInit_(@FZRec, zlib_version, sizeof(FZRec)));
end;

destructor TDecompressionStream.Destroy;
begin
  inflateEnd(FZRec);
  inherited Destroy;
end;

function TDecompressionStream.Read(var Buffer; Count: Longint): Longint;
begin
  FZRec.next_out := @Buffer;
  FZRec.avail_out := Count;
  if FStrm.Position <> FStrmPos then FStrm.Position := FStrmPos;
  while (FZRec.avail_out > 0) do
  begin
    if FZRec.avail_in = 0 then
    begin
      FZRec.avail_in := FStrm.Read(FBuffer, sizeof(FBuffer));
      if FZRec.avail_in = 0 then
        begin
          Result := Count - FZRec.avail_out;
          Exit;
        end;
      FZRec.next_in := @FBuffer;
      FStrmPos := FStrm.Position;
      Progress(Self);
    end;
    CCheck(inflate(FZRec, 0));
  end;
  Result := Count;
end;

function TDecompressionStream.Write(const Buffer; Count: Longint): Longint;
begin
  raise EDecompressionError.Create('Invalid stream operation');
end;

function TDecompressionStream.Seek(Offset: Longint; Origin: Word): Longint;
var
  I: Integer;
  Buf: array [0..4095] of Char;
begin
  if (Offset = 0) and (Origin = soFromBeginning) then
  begin
    DCheck(inflateReset(FZRec));
    FZRec.next_in  := @FBuffer;
    FZRec.avail_in := 0;
    FStrm.Position := 0;
    FStrmPos := 0;
  end
  else if ((Offset >= 0) and (Origin = soFromCurrent)) or
          (((Offset - FZRec.total_out) > 0) and (Origin = soFromBeginning)) then
  begin
    if Origin = soFromBeginning then Dec(Offset, FZRec.total_out);
    if Offset > 0 then
    begin
      for I := 1 to Offset div sizeof(Buf) do
        ReadBuffer(Buf, sizeof(Buf));
      ReadBuffer(Buf, Offset mod sizeof(Buf));
    end;
  end
  else
    raise EDecompressionError.Create('Invalid stream operation');
  Result := FZRec.total_out;
end;

end.
