{ ZipFile.Compression.LZMA.pas

  LZMA (method 14 PKWARE) compression for ZIP entries — Win32 only.

  Statically links the LZMA SDK 24.07 C sources compiled to OMF objects
  via Embarcadero bcc32c.exe (BCC102 freeware):

      Lib/lzma_obj_win32/LzmaDec.obj
      Lib/lzma_obj_win32/LzmaEnc.obj
      Lib/lzma_obj_win32/LzFind.obj
      Lib/lzma_obj_win32/Alloc.obj

  Compiled with:
      bcc32c -c -O2 -D_7ZIP_ST -o<dest>.obj <src>.c

  Win64 NOT supported in this revision — BCC102 freeware ships only the
  Win32 OMF toolchain (no bcc64x). On Win64 builds, the public functions
  raise EZipLZMANotSupportedOnPlatform.

  Public API is a one-call memory-to-memory pair:

      LzmaCompressBuffer(...)
      LzmaDecompressBuffer(...)

  Higher-level integration with TZipFile (method=14 wire) lives in
  ZipFile.pas.
}
unit ZipFile.Compression.LZMA;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Exceptions.Base;

type
  EZipLZMAError = class(EExceptionBase);
  EZipLZMANotSupportedOnPlatform = class(EZipLZMAError);

const
  LZMA_PROPS_SIZE = 5;

  // SRes return codes from 7zTypes.h
  SZ_OK              = 0;
  SZ_ERROR_DATA      = 1;
  SZ_ERROR_MEM       = 2;
  SZ_ERROR_CRC       = 3;
  SZ_ERROR_UNSUPPORTED = 4;
  SZ_ERROR_PARAM     = 5;
  SZ_ERROR_INPUT_EOF = 6;
  SZ_ERROR_OUTPUT_EOF= 7;
  SZ_ERROR_READ      = 8;
  SZ_ERROR_WRITE     = 9;
  SZ_ERROR_PROGRESS  = 10;
  SZ_ERROR_FAIL      = 11;
  SZ_ERROR_THREAD    = 12;

  // ELzmaFinishMode
  LZMA_FINISH_ANY    = 0;
  LZMA_FINISH_END    = 1;

// Compress APlain into a heap-allocated TBytes; out APropsEncoded is the
// 5-byte LZMA properties header (caller emits it as ZIP method-14 prefix).
// Raises EZipLZMAError on SDK error; EZipLZMANotSupportedOnPlatform on Win64.
procedure LzmaCompressBuffer(
  const APlain: TBytes; APlainLen: NativeInt;
  out ACompressed: TBytes;
  out APropsEncoded: TBytes;
  ALevel: Integer = 5
);

// Decompress AComp into APlain (APlainExpectedLen MUST match the original
// uncompressed length — ZIP stores it in LFH/CDH uncompressedsize, so caller
// knows it). APropsEncoded is the 5-byte header.
procedure LzmaDecompressBuffer(
  const AComp: TBytes; ACompLen: NativeInt;
  const APropsEncoded: TBytes;
  out APlain: TBytes; APlainExpectedLen: NativeInt
);

implementation

// v3.6: LZMA agora disponivel em FPC Win32+Win64 via mingw COFF .o
{$IF DEFINED(WIN32) OR DEFINED(WIN64)}
  {$DEFINE LZMA_AVAILABLE}
{$IFEND}

{$IFDEF LZMA_AVAILABLE}

// =============================================================================
//   Object file linkage (Win32 OMF, from bcc32c)
// =============================================================================
//
// Paths are relative to packages/ where the .dpr/.dpk lives (so Library\... walks
// up out of packages/ into the project root).
//
// =============================================================================
//   ISzAlloc record (mirror of the SDK's struct ISzAlloc in 7zTypes.h).
//   Must come BEFORE the C runtime + MatchFinder stubs because they take it
//   as a parameter type.
// =============================================================================

type
  TSzAllocFunc = function(p: Pointer; size: NativeUInt): Pointer; cdecl;
  TSzFreeFunc  = procedure(p: Pointer; address: Pointer); cdecl;

  PSzAlloc = ^TSzAlloc;
  TSzAlloc = record
    fnAlloc: TSzAllocFunc;
    fnFree:  TSzFreeFunc;
  end;

function PascalSzAlloc(p: Pointer; size: NativeUInt): Pointer; cdecl;
begin
  if size = 0 then
    Result := nil
  else
    GetMem(Result, size);
end;

procedure PascalSzFree(p: Pointer; address: Pointer); cdecl;
begin
  if address <> nil then
    FreeMem(address);
end;

var
  GAllocator: TSzAlloc = (fnAlloc: PascalSzAlloc; fnFree: PascalSzFree);

// =============================================================================
//   C runtime stubs that the LZMA SDK's compiled objects expect to find.
//   Win32 OMF: bcc32c emits `_memset` (leading underscore).
//   Win64 ELF: bcc64 emits `memset` (no prefix).
//   We provide both name spellings via conditional compilation.
// =============================================================================

// CRT stubs: Delphi nao tem CRT C-callable, entao implementamos manualmente
// em Pascal redirecionando para RTL primitives. Em FPC, msvcrt.dll fornece
// os simbolos reais — Pascal stubs seriam duplicacao e linker rejeitaria.
//
// STUB_NAME_USES_UNDERSCORE: Delphi externals devem ser literal (`_memset`
// para Win32 OMF, `memset` para Win64 ELF).
{$IFNDEF FPC}
{$IFDEF WIN32}
  {$DEFINE STUB_NAME_USES_UNDERSCORE}
{$ENDIF}

{$IFDEF STUB_NAME_USES_UNDERSCORE}
function _memset(dest: Pointer; c: Integer; count: NativeUInt): Pointer; cdecl;
{$ELSE}
function memset(dest: Pointer; c: Integer; count: NativeUInt): Pointer; cdecl;
{$ENDIF}
begin
  FillChar(dest^, count, Byte(c));
  Result := dest;
end;

{$IFDEF STUB_NAME_USES_UNDERSCORE}
function _memmove(dest, src: Pointer; count: NativeUInt): Pointer; cdecl;
{$ELSE}
function memmove(dest, src: Pointer; count: NativeUInt): Pointer; cdecl;
{$ENDIF}
begin
  Move(src^, dest^, count);
  Result := dest;
end;

{$IFDEF STUB_NAME_USES_UNDERSCORE}
function _memcpy(dest, src: Pointer; count: NativeUInt): Pointer; cdecl;
{$ELSE}
function memcpy(dest, src: Pointer; count: NativeUInt): Pointer; cdecl;
{$ENDIF}
begin
  Move(src^, dest^, count);
  Result := dest;
end;

{$IFDEF STUB_NAME_USES_UNDERSCORE}
function _malloc(size: NativeUInt): Pointer; cdecl;
{$ELSE}
function malloc(size: NativeUInt): Pointer; cdecl;
{$ENDIF}
begin
  if size = 0 then Result := nil else GetMem(Result, size);
end;

{$IFDEF STUB_NAME_USES_UNDERSCORE}
procedure _free(ptr: Pointer); cdecl;
{$ELSE}
procedure free(ptr: Pointer); cdecl;
{$ENDIF}
begin
  if ptr <> nil then FreeMem(ptr);
end;

{$IFDEF STUB_NAME_USES_UNDERSCORE}
function _realloc(ptr: Pointer; size: NativeUInt): Pointer; cdecl;
{$ELSE}
function realloc(ptr: Pointer; size: NativeUInt): Pointer; cdecl;
{$ENDIF}
begin
  if ptr = nil then
  begin
    if size = 0 then Result := nil else GetMem(Result, size);
  end
  else if size = 0 then
  begin
    FreeMem(ptr);
    Result := nil;
  end
  else
  begin
    ReallocMem(ptr, size);
    Result := ptr;
  end;
end;
{$ENDIF}  // NOT FPC — FPC usa msvcrt.dll diretamente

// MatchFinderMt_* stubs come from LzmaStubsST.obj (compiled from
// sdk/lzma2601/C/LzmaStubsST.c) — separating C stubs gives us the leading-
// underscore exports that bcc32c emits natively, which is what the LzmaEnc.obj
// references expect. Pascal cdecl exports do NOT prefix `_`, so doing the
// stubs in Pascal here doesn't resolve to the right symbol names.

// =============================================================================
//   Win32 APIs the SDK calls (Alloc.c uses VirtualAlloc/VirtualFree for big
//   buffers; GetModuleHandle+GetProcAddress probe for SetThreadAffinityMask).
// =============================================================================

function VirtualAlloc(lpAddress: Pointer; dwSize: NativeUInt; flAllocationType, flProtect: Cardinal): Pointer; stdcall;
  external 'kernel32.dll' name 'VirtualAlloc';
function VirtualFree(lpAddress: Pointer; dwSize: NativeUInt; dwFreeType: Cardinal): LongBool; stdcall;
  external 'kernel32.dll' name 'VirtualFree';
function GetModuleHandleW(lpModuleName: PWideChar): NativeUInt; stdcall;
  external 'kernel32.dll' name 'GetModuleHandleW';
function GetProcAddress(hModule: NativeUInt; lpProcName: PAnsiChar): Pointer; stdcall;
  external 'kernel32.dll' name 'GetProcAddress';
{$IFDEF WIN64}
// Extra kernel32 APIs the Win64 LZMA build uses (Alloc.c large-page path +
// CpuArch.c IsProcessorFeaturePresent for SSE/AVX detection).
function GetLargePageMinimum: NativeUInt; stdcall;
  external 'kernel32.dll' name 'GetLargePageMinimum';
function IsProcessorFeaturePresent(ProcessorFeature: Cardinal): LongBool; stdcall;
  external 'kernel32.dll' name 'IsProcessorFeaturePresent';
{$ENDIF}

// =============================================================================
//   Linkage of the four LZMA SDK objects (OMF, compiled by bcc32c).
//   Order matters — Alloc must be last so its symbols are still pending when
//   the LZMA objects reference them.
// =============================================================================

// v3.6: Delphi vs FPC tem diretorios distintos. Delphi usa bcc32c/bcc64
// (OMF/ELF Embarcadero); FPC usa mingw-w64 (COFF). FPC linker rejeita
// formato Embarcadero e vice-versa — precisam paths separados.
{$IFDEF FPC}
  // System DLLs (mingw COFF expects explicit linking — VirtualAlloc etc.
  // do kernel32, Alloc.c usa large pages no Win64 + CpuArch IsProcessor*).
  // msvcrt fornece memcpy/memset/memmove/malloc/free reais (FPC RTL nao
  // expoe esses simbolos como C-callable; nossos stubs Pascal nao linkam).
  {$LINKLIB kernel32}
  {$LINKLIB msvcrt}
  {$IFDEF WIN32}
    {$L Library\fpc-win32\LzmaDec.o}
    {$L Library\fpc-win32\LzmaEnc.o}
    {$L Library\fpc-win32\LzFind.o}
    {$L Library\fpc-win32\Alloc.o}
    {$L Library\fpc-win32\CpuArch.o}
    {$L Library\fpc-win32\LzmaStubsST.o}
  {$ENDIF}
  {$IFDEF WIN64}
    {$L Library\fpc-win64\LzmaDec.o}
    {$L Library\fpc-win64\LzmaEnc.o}
    {$L Library\fpc-win64\LzFind.o}
    {$L Library\fpc-win64\Alloc.o}
    {$L Library\fpc-win64\CpuArch.o}
    {$L Library\fpc-win64\LzmaStubsST.o}
  {$ENDIF}
{$ELSE} // Delphi
  {$IFDEF WIN32}
    {$L Library\delphi-win32\LzmaDec.obj}
    {$L Library\delphi-win32\LzmaEnc.obj}
    {$L Library\delphi-win32\LzFind.obj}
    {$L Library\delphi-win32\Alloc.obj}
    {$L Library\delphi-win32\LzmaStubsST.obj}
  {$ENDIF}
  {$IFDEF WIN64}
    {$L Library\delphi-win64\LzmaDec.o}
    {$L Library\delphi-win64\LzmaEnc.o}
    {$L Library\delphi-win64\LzFind.o}
    {$L Library\delphi-win64\Alloc.o}
    {$L Library\delphi-win64\CpuArch.o}        // Win64 LzFind uses SSE4.1/AVX2 fast paths
    {$L Library\delphi-win64\LzmaStubsST.o}
  {$ENDIF}
{$ENDIF}

// =============================================================================
//   Externs from the .obj files (cdecl, C name mangling)
// =============================================================================

// C name mangling differs between Win32 (leading `_`) and Win64 (no prefix).
// Pascal `external name 'X'` literal:
//  - Delphi: nao decora — usa nome verbatim. Win32 OMF emite `_LzmaEncode`,
//    entao precisamos declarar `name '_LzmaEncode'`.
//  - FPC cdecl: decora automaticamente em Win32 (adiciona `_`) — declarar
//    `name '_LzmaEncode'` resulta em `__LzmaEncode` (double). Usar nome bare.
//  - Em Win64 ambos (Delphi+FPC) usam nome bare.
{$IF DEFINED(WIN32) AND NOT DEFINED(FPC)}
  {$DEFINE C_PREFIX_UNDERSCORE}
{$IFEND}

{$IFDEF C_PREFIX_UNDERSCORE}
function LzmaEncode(
  dest: PByte; var destLen: NativeUInt;
  const src: PByte; srcLen: NativeUInt;
  const props: Pointer; propsEncoded: PByte; var propsSize: NativeUInt;
  writeEndMark: Integer;
  progress: Pointer;
  alloc: PSzAlloc;
  allocBig: PSzAlloc): Integer; cdecl; external name '_LzmaEncode';

function LzmaDecode(
  dest: PByte; var destLen: NativeUInt;
  const src: PByte; var srcLen: NativeUInt;
  const propData: PByte; propSize: Cardinal;
  finishMode: Integer;
  var status: Integer;
  alloc: PSzAlloc): Integer; cdecl; external name '_LzmaDecode';

procedure LzmaEncProps_Init(p: Pointer); cdecl; external name '_LzmaEncProps_Init';
{$ELSE}
function LzmaEncode(
  dest: PByte; var destLen: NativeUInt;
  const src: PByte; srcLen: NativeUInt;
  const props: Pointer; propsEncoded: PByte; var propsSize: NativeUInt;
  writeEndMark: Integer;
  progress: Pointer;
  alloc: PSzAlloc;
  allocBig: PSzAlloc): Integer; cdecl; external name 'LzmaEncode';

function LzmaDecode(
  dest: PByte; var destLen: NativeUInt;
  const src: PByte; var srcLen: NativeUInt;
  const propData: PByte; propSize: Cardinal;
  finishMode: Integer;
  var status: Integer;
  alloc: PSzAlloc): Integer; cdecl; external name 'LzmaDecode';

procedure LzmaEncProps_Init(p: Pointer); cdecl; external name 'LzmaEncProps_Init';
{$ENDIF}

// CLzmaEncProps layout (must match LzmaEnc.h CLzmaEncProps record exactly).
// Pack(4) — the C struct has no special pragma so default 4-byte alignment.
type
  TCLzmaEncProps = packed record
    level: Integer;          // 0..9, default 5
    dictSize: Cardinal;
    lc: Integer;
    lp: Integer;
    pb: Integer;
    algo: Integer;
    fb: Integer;
    btMode: Integer;
    numHashBytes: Integer;
    numHashOutBits: Cardinal;
    mc: Cardinal;
    writeEndMark: Cardinal;
    numThreads: Integer;
    affinityGroup: Integer;
    reduceSize: UInt64;
    affinity: UInt64;
    affinityInGroup: UInt64;
  end;

procedure LzmaCompressBuffer(
  const APlain: TBytes; APlainLen: NativeInt;
  out ACompressed: TBytes;
  out APropsEncoded: TBytes;
  ALevel: Integer
);
var
  Props: TCLzmaEncProps;
  CompCapacity, CompLen, PropsLen: NativeUInt;
  R: Integer;
begin
  LzmaEncProps_Init(@Props);
  Props.level := ALevel;
  Props.writeEndMark := 0;  // PKWARE method 14 does NOT use EOPM by default
  Props.numThreads := 1;    // _7ZIP_ST build: force single-thread; otherwise
                            // LzmaEnc would call MatchFinderMt_* (stubs return
                            // SZ_ERROR_UNSUPPORTED on purpose).

  // Worst-case compressed size per SDK guideline: src + (src/3) + 128
  CompCapacity := NativeUInt(APlainLen) + (NativeUInt(APlainLen) div 3) + 128;
  SetLength(ACompressed, CompCapacity);
  SetLength(APropsEncoded, LZMA_PROPS_SIZE);

  CompLen := CompCapacity;
  PropsLen := LZMA_PROPS_SIZE;

  if APlainLen = 0 then
  begin
    SetLength(ACompressed, 0);
    Exit;
  end;

  R := LzmaEncode(
    PByte(ACompressed), CompLen,
    PByte(APlain), NativeUInt(APlainLen),
    @Props,
    PByte(APropsEncoded), PropsLen,
    0,            // writeEndMark
    nil,          // progress
    @GAllocator,
    @GAllocator
  );
  if R <> SZ_OK then
    raise EZipLZMAError.CreateFmt('LzmaEncode failed (SRes=%d).', [R]);
  SetLength(ACompressed, CompLen);
end;

procedure LzmaDecompressBuffer(
  const AComp: TBytes; ACompLen: NativeInt;
  const APropsEncoded: TBytes;
  out APlain: TBytes; APlainExpectedLen: NativeInt
);
var
  DestLen, SrcLen: NativeUInt;
  Status: Integer;
  R: Integer;
begin
  if Length(APropsEncoded) <> LZMA_PROPS_SIZE then
    raise EZipLZMAError.CreateFmt('LZMA props header must be %d bytes (got %d).',
      [LZMA_PROPS_SIZE, Length(APropsEncoded)]);

  SetLength(APlain, APlainExpectedLen);
  if (APlainExpectedLen = 0) or (ACompLen = 0) then
    Exit;

  DestLen := NativeUInt(APlainExpectedLen);
  SrcLen := NativeUInt(ACompLen);

  R := LzmaDecode(
    PByte(APlain), DestLen,
    PByte(AComp), SrcLen,
    PByte(APropsEncoded), LZMA_PROPS_SIZE,
    LZMA_FINISH_END,
    Status,
    @GAllocator
  );
  if R <> SZ_OK then
    raise EZipLZMAError.CreateFmt('LzmaDecode failed (SRes=%d, status=%d).', [R, Status]);
  SetLength(APlain, DestLen);
end;

{$ELSE}

// Win64 / FPC fallback — raises clearly so caller knows LZMA isn't available.

procedure LzmaCompressBuffer(
  const APlain: TBytes; APlainLen: NativeInt;
  out ACompressed: TBytes;
  out APropsEncoded: TBytes;
  ALevel: Integer
);
begin
  raise EZipLZMANotSupportedOnPlatform.Create(
    'LZMA (method 14) requires Delphi Win32 with the BCC102-compiled .obj ' +
    'set. Win64/FPC paths are not yet wired — use Deflate (method 8) or ' +
    'Store (method 0) on those targets.');
end;

procedure LzmaDecompressBuffer(
  const AComp: TBytes; ACompLen: NativeInt;
  const APropsEncoded: TBytes;
  out APlain: TBytes; APlainExpectedLen: NativeInt
);
begin
  raise EZipLZMANotSupportedOnPlatform.Create(
    'LZMA (method 14) requires Delphi Win32 with the BCC102-compiled .obj ' +
    'set. Win64/FPC paths are not yet wired.');
end;

{$ENDIF}

end.
