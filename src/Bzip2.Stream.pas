{ =============================================================================
  Bzip2.Stream - absorvido do ZipFileORM v4.0.0 (modulo ZipFile, F1-A Onda A.3)

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
{ Bzip2.Stream.pas

  BZIP2 stream compression/decompression — binding ao bzip2 1.1.0-dev SDK
  (Snyder fork) compilado em 4 toolchains via tools/Build-Bzip2Objs.ps1:
   - Delphi Win32 OMF (bcc32c)
   - Delphi Win64 ELF (bcc64) — habilitado em v3.8
   - FPC Win32+Win64 COFF (mingw-w64) — habilitado em v3.8

  API minimalista:
   - Bz2CompressBytes  / Bz2DecompressBytes
   - Bz2CompressStream / Bz2DecompressStream (one-shot buffer-in-memory)

  Streaming real (TBz2CompressStream/TBz2DecompressStream classes) deferido
  para v3.8.1 — exige BZ2_bzCompress/BZ2_bzDecompress sequenciais com
  estado bz_stream persistente entre chamadas, similar ao zlib z_stream.
}
unit Bzip2.Stream;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Classes, Bzip2.Stream.Interfaces, Exceptions.Base;

type
  EBzip2Error = class(EExceptionBase);
  EBzip2NotSupportedOnPlatform = class(EBzip2Error);

const
  BZ_OK         = 0;
  BZ_RUN_OK     = 1;
  BZ_FLUSH_OK   = 2;
  BZ_FINISH_OK  = 3;
  BZ_STREAM_END = 4;
  BZ_SEQUENCE_ERROR = -1;
  BZ_PARAM_ERROR    = -2;
  BZ_MEM_ERROR      = -3;
  BZ_DATA_ERROR     = -4;
  BZ_OUTBUFF_FULL   = -8;

function Bz2CompressBytes(const Src: TBytes; BlockSize100k: Integer = 9): TBytes;
function Bz2DecompressBytes(const Src: TBytes): TBytes;

procedure Bz2CompressStream(Src, Dst: TStream; BlockSize100k: Integer = 9);
procedure Bz2DecompressStream(Src, Dst: TStream);

type
  // Concrete builder for IBzip2Builder. Interface lives in
  // Bzip2.Stream.Interfaces.pas per backend-pascal-unit-naming_V1.6.0 §2.
  TBzip2Builder = class(TInterfacedObject, IBzip2Builder)
  private
    FDirection: TBzip2Direction;
    FLevel: Integer;
    FSrcBytes: TBytes;
    function ProcessBytes: TBytes;
  public
    constructor Create(ADir: TBzip2Direction; const ASrc: TBytes);
    function WithLevel(ALevel: Integer): IBzip2Builder;
    function ToBytes: TBytes;
    function ToString: string; reintroduce;
    procedure ToStream(ADest: TStream);
    procedure ToFile(const APath: string);
  end;

  // Factory facade — entry point for fluent Bzip2 usage:
  //   var Comp := Bzip.Compress(plainBytes).WithLevel(9).ToBytes;
  Bzip = class
  public
    class function Compress(const ASrc: TBytes): IBzip2Builder; overload;
    class function Compress(ASrc: TStream): IBzip2Builder; overload;
    class function Compress(const AText: string): IBzip2Builder; overload;
    class function CompressFile(const APath: string): IBzip2Builder;
    class function Decompress(const ASrc: TBytes): IBzip2Builder; overload;
    class function Decompress(ASrc: TStream): IBzip2Builder; overload;
    class function DecompressFile(const APath: string): IBzip2Builder;
  end;

implementation

// v3.8: 4 toolchains habilitadas (Delphi Win32+Win64, FPC Win32+Win64)
{$IF DEFINED(WIN32) OR DEFINED(WIN64)}
  {$DEFINE BZIP2_AVAILABLE}
{$IFEND}

// Sufixo de prefixo de simbolo:
//  - Win32 OMF (bcc32c, MSVC ABI): __stdcall sem prefixo `_`. cdecl com `_`.
//  - Win64 (ABI x64 unificada): sem prefixo, sem distincao stdcall/cdecl.
//  - FPC Win32 (mingw COFF GNU ABI): cdecl sem prefixo `_`.
//  - FPC Win64 (mingw COFF): idem Win64.
//
// BZ2_bzBuffToBuff* sao __stdcall em Win32 (WINAPI macro), mas o symbol
// fica SEM prefixo nas duas plataformas que importamos:
//   bcc32c stdcall → `BZ2_bzBuffToBuffCompress` (sem `_`, sem `@N`)
//   bcc64 (sem stdcall distinto) → `BZ2_bzBuffToBuffCompress`
//   mingw stdcall Win32 → `_BZ2_bzBuffToBuffCompress@28` (com `_` e `@N`)
// Para FPC mingw, precisariamos definir `BZ_NO_STDCALL` ou recompilar
// sem `WINAPI`. Vamos forcar BZ_API = func cdecl puro via -DBZ_NO_WINAPI
// se necessario para FPC. Por ora, smoke FPC fica pendente.

{$IFDEF BZIP2_AVAILABLE}

// === CRT stubs ===
// Win32 OMF bcc32c: simbolos C cdecl tem prefixo `_` (`_malloc`).
// Win64 ELF bcc64 + FPC COFF mingw Win64: simbolos C sem prefixo (`malloc`).
{$IFDEF WIN32}
  {$DEFINE BZ_C_UNDERSCORE}
{$ENDIF}

{$IFDEF BZ_C_UNDERSCORE}
function _malloc(size: NativeUInt): Pointer; cdecl;
{$ELSE}
function malloc(size: NativeUInt): Pointer; cdecl;
{$ENDIF}
begin
  if size = 0 then Result := nil else GetMem(Result, size);
end;

{$IFDEF BZ_C_UNDERSCORE}
procedure _free(ptr: Pointer); cdecl;
{$ELSE}
procedure free(ptr: Pointer); cdecl;
{$ENDIF}
begin
  if ptr <> nil then FreeMem(ptr);
end;

{$IFDEF BZ_C_UNDERSCORE}
function _memset(dest: Pointer; c: Integer; count: NativeUInt): Pointer; cdecl;
{$ELSE}
function memset(dest: Pointer; c: Integer; count: NativeUInt): Pointer; cdecl;
{$ENDIF}
begin
  FillChar(dest^, count, Byte(c));
  Result := dest;
end;

{$IFDEF BZ_C_UNDERSCORE}
function _memcpy(dest, src: Pointer; count: NativeUInt): Pointer; cdecl;
{$ELSE}
function memcpy(dest, src: Pointer; count: NativeUInt): Pointer; cdecl;
{$ENDIF}
begin
  Move(src^, dest^, count);
  Result := dest;
end;

{$IFDEF BZ_C_UNDERSCORE}
function _memmove(dest, src: Pointer; count: NativeUInt): Pointer; cdecl;
{$ELSE}
function memmove(dest, src: Pointer; count: NativeUInt): Pointer; cdecl;
{$ENDIF}
begin
  Move(src^, dest^, count);
  Result := dest;
end;

// BZIP2 source chama setjmp/longjmp em alguns paths; stubs minimos
{$IFDEF BZ_C_UNDERSCORE}
function _setjmp(env: Pointer): Integer; cdecl;
{$ELSE}
function setjmp(env: Pointer): Integer; cdecl;
{$ENDIF}
begin
  Result := 0;
end;

{$IFDEF BZ_C_UNDERSCORE}
procedure _longjmp(env: Pointer; val: Integer); cdecl;
{$ELSE}
procedure longjmp(env: Pointer; val: Integer); cdecl;
{$ENDIF}
begin
  raise EBzip2Error.CreateFmt('bzip2 longjmp val=%d (corrupted stream?)', [val]);
end;

// Stack-probe stub. Win32 bcc32c emite __chkstk_noalloc; Win64 bcc64 emite
// __chkstk; FPC mingw COFF emite ___chkstk_ms ou similar. No-op (Pascal RTL
// ja garante stack).
{$IFDEF WIN32}
procedure __chkstk_noalloc; cdecl;
begin end;
{$ENDIF}
{$IFDEF WIN64}
procedure __chkstk; cdecl;
begin end;
{$ENDIF}

// bz_internal_error: callback que bzlib.c chama em AssertH macros. Definida
// na bzlib.h como `void bz_internal_error(int errcode)`. Default impl chama
// fprintf+exit. Substituimos por raise.
{$IFDEF BZ_C_UNDERSCORE}
procedure _bz_internal_error(errcode: Integer); cdecl;
{$ELSE}
procedure bz_internal_error(errcode: Integer); cdecl;
{$ENDIF}
begin
  raise EBzip2Error.CreateFmt('bz_internal_error: assertion failure code=%d', [errcode]);
end;

// bzlib.c usa fprintf(stderr, ...) so em BZ2_bz__AssertH__fail e em
// bzopen-style helpers (alto-nivel). API one-shot que usamos nao bate
// nesses paths — stubs no-op cobrem a linkagem.
//
// Win64 + FPC mingw: -DBZ_NO_STDIO desabilita esses paths no source, entao
// nao precisamos dos stubs stdio. So Win32 (que nao passamos -DBZ_NO_STDIO
// historicamente) precisa.
{$IFDEF WIN32}
var
  __streams: array[0..2] of Pointer = (nil, nil, nil);
  __stderr: Pointer = nil;
  __stdin: Pointer = nil;
  __stdout: Pointer = nil;
{$ENDIF}

// cdecl + varargs nao permitido em Pascal-implementado; fprintf/printf
// no path de fprintf so dispara em assertion failures que nao queremos
// suportar mesmo. Stubs sem varargs sao OK porque cdecl callee nao precisa
// limpar stack (caller cleanup) — extra args ficam stranded mas nao crash.
{$IFDEF WIN32}
function _fprintf(stream: Pointer; const fmt: PAnsiChar): Integer; cdecl;
begin
  Result := 0;
end;
function _printf(const fmt: PAnsiChar): Integer; cdecl;
begin
  Result := 0;
end;
function _fflush(stream: Pointer): Integer; cdecl;
begin
  Result := 0;
end;
function _fclose(stream: Pointer): Integer; cdecl;
begin
  Result := 0;
end;
function _fopen(const path, mode: PAnsiChar): Pointer; cdecl;
begin
  Result := nil;  // BZ2_bzopen high-level path nao usado em buffer-to-buffer API
end;
function _fread(ptr: Pointer; size, nmemb: NativeUInt; stream: Pointer): NativeUInt; cdecl;
begin
  Result := 0;
end;
function _fwrite(ptr: Pointer; size, nmemb: NativeUInt; stream: Pointer): NativeUInt; cdecl;
begin
  Result := nmemb;  // pretend write succeeded
end;
function _ferror(stream: Pointer): Integer; cdecl;
begin
  Result := 0;
end;
function _feof(stream: Pointer): Integer; cdecl;
begin
  Result := 1;
end;
function _fputc(c: Integer; stream: Pointer): Integer; cdecl;
begin
  Result := c;
end;
function _fgetc(stream: Pointer): Integer; cdecl;
begin
  Result := -1;  // EOF
end;
function _ungetc(c: Integer; stream: Pointer): Integer; cdecl;
begin
  Result := -1;
end;
function _fdopen(fd: Integer; const mode: PAnsiChar): Pointer; cdecl;
begin
  Result := nil;
end;
function _strlen(const s: PAnsiChar): NativeUInt; cdecl;
var p: PAnsiChar;
begin
  Result := 0;
  if s = nil then Exit;
  p := s;
  while p^ <> #0 do
  begin
    Inc(p);
    Inc(Result);
  end;
end;
function _setmode(fd, mode: Integer): Integer; cdecl;
begin
  Result := 0;
end;
var
  GErrnoStorage: Integer = 0;
function ___errno: PInteger; cdecl;
begin
  Result := @GErrnoStorage;
end;
procedure _exit(code: Integer); cdecl;
begin
  raise EBzip2Error.CreateFmt('bzip2 abort (exit %d)', [code]);
end;
{$ENDIF}  // WIN32 stdio stubs

// Linkagem do BZIP2 — TODOS os .c combinados num unico OBJ via BzipCombined.c
// (mutual deps bzlib.c <-> compress.c <-> blocksort.c <-> ... resolvem internamente)
{$IFDEF WIN32}
  {$L Library\delphi-win32\BzipCombined.obj}
{$ENDIF}
{$IFDEF WIN64}
  {$L Library\delphi-win64\BzipCombined.o}
{$ENDIF}

// BZ2_bzBuffToBuffCompress — one-shot in-memory compression
//   dest, destLen: output buffer + size (in: capacity, out: actual)
//   source, sourceLen: input
//   blockSize100k: 1..9 (9 = best compression, 900KB block)
//   verbosity: 0
//   workFactor: 0 (default 30)
//
// IMPORTANTE (v3.8 fix): bzlib.h define `BZ_API(func) WINAPI func`
// quando _WIN32. WINAPI = __stdcall. Pascal precisa declarar `stdcall`,
// NAO cdecl, senao o callee ja desempilhou args (stdcall) e o caller faz
// pop redundante causando AV ao retornar. bcc32c clang emite o symbol
// SEM prefixo `_` quando __stdcall (diferente do cdecl OMF que adiciona
// `_`). Em Win64, x64 ABI nao tem distinção stdcall/cdecl no ABI — bcc64
// emite sem prefixo direto.
function BZ2_bzBuffToBuffCompress(
  dest: Pointer; var destLen: Cardinal;
  source: Pointer; sourceLen: Cardinal;
  blockSize100k, verbosity, workFactor: Integer
): Integer; stdcall; external name 'BZ2_bzBuffToBuffCompress';

function BZ2_bzBuffToBuffDecompress(
  dest: Pointer; var destLen: Cardinal;
  source: Pointer; sourceLen: Cardinal;
  small, verbosity: Integer
): Integer; stdcall; external name 'BZ2_bzBuffToBuffDecompress';

{$ENDIF}

function Bz2CompressBytes(const Src: TBytes; BlockSize100k: Integer): TBytes;
{$IFDEF BZIP2_AVAILABLE}
var
  SrcLen, DstLen: Cardinal;
  Res: Integer;
begin
  SrcLen := Cardinal(Length(Src));
  // BZIP2 recomenda destLen >= 1.01*srcLen + 600 para garantir cabe sem expandir
  DstLen := SrcLen + (SrcLen div 100) + 600;
  SetLength(Result, DstLen);
  if SrcLen = 0 then Exit;
  Res := BZ2_bzBuffToBuffCompress(@Result[0], DstLen, @Src[0], SrcLen,
    BlockSize100k, 0, 0);
  if Res <> BZ_OK then
    raise EBzip2Error.CreateFmt('BZ2_bzBuffToBuffCompress: error %d', [Res]);
  SetLength(Result, DstLen);
end;
{$ELSE}
begin
  raise EBzip2NotSupportedOnPlatform.Create('BZIP2 requires Delphi Win32 + bcc32c-compiled .obj set.');
end;
{$ENDIF}

function Bz2DecompressBytes(const Src: TBytes): TBytes;
{$IFDEF BZIP2_AVAILABLE}
var
  SrcLen, DstCapacity, DstLen: Cardinal;
  Res: Integer;
begin
  SrcLen := Cardinal(Length(Src));
  if SrcLen = 0 then Exit;
  // Inicia com 8x estimativa; se BZ_OUTBUFF_FULL, dobra ate caber
  DstCapacity := SrcLen * 8;
  if DstCapacity < 65536 then DstCapacity := 65536;
  repeat
    SetLength(Result, DstCapacity);
    DstLen := DstCapacity;
    Res := BZ2_bzBuffToBuffDecompress(@Result[0], DstLen, @Src[0], SrcLen, 0, 0);
    if Res = BZ_OUTBUFF_FULL then
    begin
      DstCapacity := DstCapacity * 2;
      if DstCapacity > 1024 * 1024 * 1024 then  // limite 1 GB
        raise EBzip2Error.Create('Bz2DecompressBytes: output exceeds 1 GB limit');
      Continue;
    end;
    if Res <> BZ_OK then
      raise EBzip2Error.CreateFmt('BZ2_bzBuffToBuffDecompress: error %d', [Res]);
    Break;
  until False;
  SetLength(Result, DstLen);
end;
{$ELSE}
begin
  raise EBzip2NotSupportedOnPlatform.Create('BZIP2 requires Delphi Win32 + bcc32c-compiled .obj set.');
end;
{$ENDIF}

procedure Bz2CompressStream(Src, Dst: TStream; BlockSize100k: Integer);
var Buf, Comp: TBytes;
begin
  SetLength(Buf, Src.Size - Src.Position);
  if Length(Buf) > 0 then Src.ReadBuffer(Buf[0], Length(Buf));
  Comp := Bz2CompressBytes(Buf, BlockSize100k);
  if Length(Comp) > 0 then Dst.WriteBuffer(Comp[0], Length(Comp));
end;

procedure Bz2DecompressStream(Src, Dst: TStream);
var Buf, Dec: TBytes;
begin
  SetLength(Buf, Src.Size - Src.Position);
  if Length(Buf) > 0 then Src.ReadBuffer(Buf[0], Length(Buf));
  Dec := Bz2DecompressBytes(Buf);
  if Length(Dec) > 0 then Dst.WriteBuffer(Dec[0], Length(Dec));
end;

{ ============================================================================
  Fluent builder — relocated from former Bzip2.Fluent.pas (dissolved per
  backend-pascal-unit-naming_V1.6.0 §2; interface in companion .Interfaces.pas).
  ============================================================================ }

function BytesFromStream(AStream: TStream): TBytes;
begin
  AStream.Position := 0;
  SetLength(Result, AStream.Size);
  if AStream.Size > 0 then AStream.ReadBuffer(Result[0], AStream.Size);
end;

function BytesFromFile(const APath: string): TBytes;
var Fs: TFileStream;
begin
  Fs := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try Result := BytesFromStream(Fs); finally Fs.Free; end;
end;

constructor TBzip2Builder.Create(ADir: TBzip2Direction; const ASrc: TBytes);
begin
  inherited Create;
  FDirection := ADir;
  FLevel := 9;
  FSrcBytes := ASrc;
end;

function TBzip2Builder.WithLevel(ALevel: Integer): IBzip2Builder;
begin
  FLevel := ALevel;
  Result := Self;
end;

function TBzip2Builder.ProcessBytes: TBytes;
begin
  case FDirection of
    bzdCompress:   Result := Bz2CompressBytes(FSrcBytes, FLevel);
    bzdDecompress: Result := Bz2DecompressBytes(FSrcBytes);
  else SetLength(Result, 0);
  end;
end;

function TBzip2Builder.ToBytes: TBytes;
begin
  Result := ProcessBytes;
end;

function TBzip2Builder.ToString: string;
var B: TBytes;
begin
  B := ProcessBytes;
  if Length(B) = 0 then Result := ''
  else Result := TEncoding.UTF8.GetString(B);
end;

procedure TBzip2Builder.ToStream(ADest: TStream);
var B: TBytes;
begin
  B := ProcessBytes;
  if Length(B) > 0 then ADest.WriteBuffer(B[0], Length(B));
end;

procedure TBzip2Builder.ToFile(const APath: string);
var Fs: TFileStream;
begin
  Fs := TFileStream.Create(APath, fmCreate);
  try ToStream(Fs); finally Fs.Free; end;
end;

class function Bzip.Compress(const ASrc: TBytes): IBzip2Builder;
begin Result := TBzip2Builder.Create(bzdCompress, ASrc); end;

class function Bzip.Compress(ASrc: TStream): IBzip2Builder;
begin Result := TBzip2Builder.Create(bzdCompress, BytesFromStream(ASrc)); end;

class function Bzip.Compress(const AText: string): IBzip2Builder;
begin Result := TBzip2Builder.Create(bzdCompress, TEncoding.UTF8.GetBytes(AText)); end;

class function Bzip.CompressFile(const APath: string): IBzip2Builder;
begin Result := TBzip2Builder.Create(bzdCompress, BytesFromFile(APath)); end;

class function Bzip.Decompress(const ASrc: TBytes): IBzip2Builder;
begin Result := TBzip2Builder.Create(bzdDecompress, ASrc); end;

class function Bzip.Decompress(ASrc: TStream): IBzip2Builder;
begin Result := TBzip2Builder.Create(bzdDecompress, BytesFromStream(ASrc)); end;

class function Bzip.DecompressFile(const APath: string): IBzip2Builder;
begin Result := TBzip2Builder.Create(bzdDecompress, BytesFromFile(APath)); end;

end.
