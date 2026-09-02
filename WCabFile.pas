{ =============================================================================
  WCabFile - absorvido do ZipFileORM v4.0.0 (modulo ZipFile, F1-A Onda A.3)

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
{ WCabFile.pas

  TWCabFile — Microsoft Cabinet (.cab) READ via FDI (File Decompression
  Interface). WRITE deferido para v3.7.1 (via FCI).

  Implementacao: linka estaticamente fdi.obj do sdk/cabnet/ (Wine cabinet
  source compilado via D29 bcc32c + D29 Win SDK headers). Sem dependencia
  cabinet.dll — pronto para Linux x86_64 quando FPC cross build for setup.

  Win32-only por enquanto (Win64 deferido — bcc64 ELF issues similares ao
  v3.1 7zip; ver lições aprendidas no SPEC §15).

  API espelha TZipFile / TSevenZFile:
    - Active, FileName, Open, Close
    - EntryCount, FileExists, GetEntryName, GetFileSize
    - GetEntryStream, ReadAsBytes, ReadAsString
    - Fluent: WithFileName, ThatOpens
}
unit WCabFile;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Classes, Commons.ZipFile.Types, ZipFile.Events,
  CabFile.Interfaces, CabFile.Exceptions, CabFile.Types, Exceptions.ZipFile;

type
  // Exception types relocated to CabFile.Exceptions.pas (Wave 3a split).
  // TCabEntry relocated to CabFile.Types.pas. Re-exported as aliases for
  // backward compat with `uses WCabFile` consumers.
  ECabError = CabFile.Exceptions.ECabError;
  ECabNotSupportedOnPlatform = CabFile.Exceptions.ECabNotSupportedOnPlatform;
  TCabEntry = CabFile.Types.TCabEntry;

  // TCabCompressionType is now declared in CabFile.Interfaces.pas (alongside
  // ICabFileBuilder which needs it). Aliased here for backward compatibility
  // with consumers that `uses WCabFile` only.
  TCabCompressionType = CabFile.Interfaces.TCabCompressionType;

const
  cctNone  = CabFile.Interfaces.cctNone;
  cctMSZIP = CabFile.Interfaces.cctMSZIP;

type
  // Concrete builder for ICabFileBuilder. Interface lives in
  // CabFile.Interfaces.pas per backend-pascal-unit-naming_V1.6.0 §2.
  // Relocated from former Cab.Fluent.pas.
  TCabBuilderItem = record
    DiskFileName: string;
    EntryName: string;
  end;

  TCabFileBuilder = class(TInterfacedObject, ICabFileBuilder)
  private
    FArchivePath: string;
    FOpenForRead: Boolean;
    FCompression: TCabCompressionType;
    FItems: array of TCabBuilderItem;
  public
    constructor CreateNew(const APath: string);
    constructor CreateOpen(const APath: string);
    function WithCompression(AKind: TCabCompressionType): ICabFileBuilder;
    function AppendFile(const ADiskFileName, AEntryName: string): ICabFileBuilder;
    procedure Execute;
    function ExtractStream(const AEntryName: string): TStream;
    function ReadAsBytes(const AEntryName: string): TBytes;
    function ReadAsString(const AEntryName: string): string;
    function HasEntry(const AEntryName: string): Boolean;
    function CountEntries: Integer;
  end;

  // Factory facade for fluent CAB usage:
  //   Cabinet.NewArchive('out.cab').WithCompression(cctMSZIP).AppendFile(...).Execute;
  Cabinet = class
  public
    class function NewArchive(const APath: string): ICabFileBuilder;
    class function OpenArchive(const APath: string): ICabFileBuilder;
  end;

  TWCabFile = class(TComponent)
  protected
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
    // Add (write)
    FOnBeforeAdd: TArchiveBeforeAddEvent;
    FOnAfterAdd: TArchiveAfterAddEvent;
    FOnAddProgress: TArchiveEntryProgressEvent;
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
    FEntries: array of TCabEntry;
    FCompression: TCabCompressionType;
    FCompressionLevel: Integer;        // 1..9 (MSZIP/LZX) — reservado v3.8
    FExtractTarget: string;
    FExtractStream: TMemoryStream;
    FSetID: Word;                      // cabinet set ID (multi-cabinet sets)
    FCabinetIndex: Word;                // index within set (0 = first)
    FVolumeSize: Int64;                 // 0 = single .cab; >0 = split em multiple .cab
    FReserveSize: Integer;              // per-data-block reserve bytes (advanced) — reservado
    // Cabinet set chain (CFHEADER szCabinetPrev/szCabinetNext + szDiskPrev/szDiskNext)
    FPreviousCabinet: string;
    FNextCabinet: string;
    FPreviousDiskName: string;
    FNextDiskName: string;
    // Reserved area splits (cbCFHeader / cbCFFolder / cbCFData)
    FHeaderReserveSize: Word;          // bytes reservados no CFHEADER
    FFolderReserveSize: Byte;          // bytes reservados em cada CFFOLDER
    FDataReserveSize: Byte;            // bytes reservados em cada CFDATA
    // Read-only — populated by Open.
    FArchiveSize: Int64;
    FIsMultiCabinet: Boolean;
    FVersionMajor: Byte;               // cabinet format major (1)
    FVersionMinor: Byte;               // cabinet format minor (3)
    FHasReserveArea: Boolean;          // cfhdrRESERVE_PRESENT bit set
    FHasPrevCabinet: Boolean;          // cfhdrPREV_CABINET bit set
    FHasNextCabinet: Boolean;          // cfhdrNEXT_CABINET bit set
    FTotalEntries: Integer;            // sum across all cabinets in set
    procedure SetActive(AValue: Boolean);
    procedure SetFileName(const AValue: string);
    procedure SetCompressionLevel(AValue: Integer);
    procedure DoListEntries;
    procedure DoExtract(const AName: string; ADst: TStream);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Open;
    procedure Close;

    function GetEntryCount: Integer;
    function FileExists(const AName: string): Boolean;
    function GetFileSize(AIndex: Integer): Int64;
    function GetEntryName(AIndex: Integer): string;
    function FindIndex(const AName: string): Integer;
    function GetEntryStream(const AName: string): TStream;
    function ReadAsBytes(const AName: string): TBytes;
    function ReadAsString(const AName: string): string;

    // v3.7.1 WRITE: cria cabinet novo a partir de pares
    // ['source-on-disk', 'name-in-cabinet', ...]
    procedure CreateFromFiles(const ASourcesAndNames: array of string);

    function WithFileName(const APath: string): TWCabFile;
    function ThatOpens: TWCabFile;
  published
    property Active: Boolean read FActive write SetActive;
    property FileName: string read FFileName write SetFileName;
    property EntryCount: Integer read GetEntryCount;

    // ---- Compression ----
    property Compression: TCabCompressionType read FCompression write FCompression default cctNone;
    // 1..9 — usado quando Compression for MSZIP/LZX. Default 6.
    property CompressionLevel: Integer read FCompressionLevel write SetCompressionLevel default 6;

    // ---- Cabinet set / multi-volume ----
    // SetID identifica um grupo de .cab relacionados. Default 0.
    property SetID: Word read FSetID write FSetID default 0;
    // Index do .cab atual dentro do set. Default 0 (primeiro).
    property CabinetIndex: Word read FCabinetIndex write FCabinetIndex default 0;
    // Tamanho em bytes de cada .cab quando split. 0 = single-cabinet (default).
    property VolumeSize: Int64 read FVolumeSize write FVolumeSize default 0;
    // Bytes reservados em cada CFDATA block (advanced — reservado v3.8.x).
    property ReserveSize: Integer read FReserveSize write FReserveSize default 0;

    // ---- Extraction ----
    // Path destino default usado quando ExtractAll/Extract sem argumento. Vazio = cwd.
    property ExtractTarget: string read FExtractTarget write FExtractTarget;

    // ---- Multi-cabinet chain (CFHEADER szCabinetPrev/Next + szDiskPrev/Next) ----
    // Para multi-cab sets (HasPrevCabinet/HasNextCabinet), nome do cab anterior/proximo.
    property PreviousCabinet: string read FPreviousCabinet write FPreviousCabinet;
    property NextCabinet: string read FNextCabinet write FNextCabinet;
    property PreviousDiskName: string read FPreviousDiskName write FPreviousDiskName;
    property NextDiskName: string read FNextDiskName write FNextDiskName;

    // ---- Reserved areas (cbCFHeader/cbCFFolder/cbCFData) ----
    // Bytes adicionais reservados no CFHEADER para uso da aplicacao (max 60K).
    property HeaderReserveSize: Word read FHeaderReserveSize write FHeaderReserveSize default 0;
    // Bytes reservados em cada CFFOLDER (max 255).
    property FolderReserveSize: Byte read FFolderReserveSize write FFolderReserveSize default 0;
    // Bytes reservados em cada CFDATA block (max 255).
    property DataReserveSize: Byte read FDataReserveSize write FDataReserveSize default 0;

    // ---- Read-only info ----
    property ArchiveSize: Int64 read FArchiveSize;
    property IsMultiCabinet: Boolean read FIsMultiCabinet;
    // Cabinet format version (Microsoft spec: currently 1.3).
    property VersionMajor: Byte read FVersionMajor;
    property VersionMinor: Byte read FVersionMinor;
    // True se header carrega cbCFHeader/Folder/Data > 0.
    property HasReserveArea: Boolean read FHasReserveArea;
    // cfhdrPREV_CABINET / cfhdrNEXT_CABINET bits.
    property HasPrevCabinet: Boolean read FHasPrevCabinet;
    property HasNextCabinet: Boolean read FHasNextCabinet;
    // Total entries somando todos os cabs no set (somente populado se IsMultiCabinet).
    property TotalEntries: Integer read FTotalEntries;

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
    property OnBeforeAdd: TArchiveBeforeAddEvent read FOnBeforeAdd write FOnBeforeAdd;
    property OnAfterAdd: TArchiveAfterAddEvent read FOnAfterAdd write FOnAfterAdd;
    property OnAddProgress: TArchiveEntryProgressEvent read FOnAddProgress write FOnAddProgress;
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

// FPC Windows habilitado via mingw-w64 gcc 16.1.0 vendored em
// ZipFile/deps/gcc-mingw-w64/. Gera COFF sem COMDAT pervasivo (issue MSVC
// cl.exe que FPC linker nao suporta). OBJs COFF FPC em
// Lib/cabnet_obj_fpc_win{32,64}/.
{$IF DEFINED(WIN32) OR DEFINED(WIN64)}
  {$DEFINE CAB_AVAILABLE}
{$IFEND}
{$IFDEF WIN32}
  {$DEFINE CAB_C_UNDERSCORE}
{$ENDIF}

{$IFDEF CAB_AVAILABLE}

// ============================================================================
//   CRT stubs (mesmo padrao do v3.1 SevenZ)
// ============================================================================

{$IFDEF CAB_C_UNDERSCORE}
function _malloc(size: NativeUInt): Pointer; cdecl;
{$ELSE}
function malloc(size: NativeUInt): Pointer; cdecl;
{$ENDIF}
begin
  if size = 0 then Result := nil else GetMem(Result, size);
end;
{$IFDEF CAB_C_UNDERSCORE}
procedure _free(ptr: Pointer); cdecl;
{$ELSE}
procedure free(ptr: Pointer); cdecl;
{$ENDIF}
begin
  if ptr <> nil then FreeMem(ptr);
end;
{$IFDEF CAB_C_UNDERSCORE}
function _memset(dest: Pointer; c: Integer; count: NativeUInt): Pointer; cdecl;
{$ELSE}
function memset(dest: Pointer; c: Integer; count: NativeUInt): Pointer; cdecl;
{$ENDIF}
begin
  FillChar(dest^, count, Byte(c));
  Result := dest;
end;
{$IFDEF CAB_C_UNDERSCORE}
function _memcpy(dest, src: Pointer; count: NativeUInt): Pointer; cdecl;
{$ELSE}
function memcpy(dest, src: Pointer; count: NativeUInt): Pointer; cdecl;
{$ENDIF}
begin
  Move(src^, dest^, count);
  Result := dest;
end;
{$IFDEF CAB_C_UNDERSCORE}
function _memmove(dest, src: Pointer; count: NativeUInt): Pointer; cdecl;
{$ELSE}
function memmove(dest, src: Pointer; count: NativeUInt): Pointer; cdecl;
{$ENDIF}
begin
  Move(src^, dest^, count);
  Result := dest;
end;
{$IFDEF CAB_C_UNDERSCORE}
function _strlen(const s: PAnsiChar): NativeUInt; cdecl;
{$ELSE}
function strlen(const s: PAnsiChar): NativeUInt; cdecl;
{$ENDIF}
var p: PAnsiChar;
begin
  Result := 0;
  if s = nil then Exit;
  p := s;
  while p^ <> #0 do begin Inc(p); Inc(Result); end;
end;
{$IFDEF CAB_C_UNDERSCORE}
function _strcpy(dest: PAnsiChar; const src: PAnsiChar): PAnsiChar; cdecl;
{$ELSE}
function strcpy(dest: PAnsiChar; const src: PAnsiChar): PAnsiChar; cdecl;
{$ENDIF}
var d: PAnsiChar; s: PAnsiChar;
begin
  d := dest; s := src;
  while s^ <> #0 do begin d^ := s^; Inc(d); Inc(s); end;
  d^ := #0;
  Result := dest;
end;
{$IFDEF CAB_C_UNDERSCORE}
function _strcat(dest: PAnsiChar; const src: PAnsiChar): PAnsiChar; cdecl;
{$ELSE}
function strcat(dest: PAnsiChar; const src: PAnsiChar): PAnsiChar; cdecl;
{$ENDIF}
var d: PAnsiChar; s: PAnsiChar;
begin
  d := dest;
  while d^ <> #0 do Inc(d);
  s := src;
  while s^ <> #0 do begin d^ := s^; Inc(d); Inc(s); end;
  d^ := #0;
  Result := dest;
end;

// ============================================================================
//   FDI types (Microsoft) — minimal subset needed for READ
// ============================================================================

const
  FDIERROR_NONE                  = 0;
  FDIERROR_CABINET_NOT_FOUND     = 1;
  FDIERROR_NOT_A_CABINET         = 2;
  FDIERROR_UNKNOWN_CABINET_VERSION = 3;
  FDIERROR_CORRUPT_CABINET       = 4;
  FDIERROR_ALLOC_FAIL            = 5;
  FDIERROR_BAD_COMPR_TYPE        = 6;
  FDIERROR_MDI_FAIL              = 7;
  FDIERROR_TARGET_FILE           = 8;
  FDIERROR_RESERVE_MISMATCH      = 9;
  FDIERROR_WRONG_CABINET         = 10;
  FDIERROR_USER_ABORT            = 11;

  cpuUNKNOWN = -1;
  cpu80286   = 0;
  cpu80386   = 1;

  // FDINOTIFICATIONTYPE
  fdintCABINET_INFO    = 0;
  fdintPARTIAL_FILE    = 1;
  fdintCOPY_FILE       = 2;
  fdintCLOSE_FILE_INFO = 3;
  fdintNEXT_CABINET    = 4;
  fdintENUMERATE       = 5;

  // open modes for FDI's PFNOPEN callback (sys/stat.h Win mingw values)
  _O_RDONLY  = $0000;
  _O_WRONLY  = $0001;
  _O_RDWR    = $0002;
  _O_BINARY  = $8000;

  // seek
  SEEK_SET = 0;
  SEEK_CUR = 1;
  SEEK_END = 2;

type
  THfdi = Pointer;

  PERF = ^TERF;
  TERF = record
    erfOper: Integer;
    erfType: Integer;
    fError: Integer;
  end;

  // FDINOTIFICATION struct (passed to PFNFDINOTIFY)
  PFDINOTIFICATION = ^TFDINOTIFICATION;
  TFDINOTIFICATION = record
    cb: LongInt;            // file size
    psz1: PAnsiChar;        // file name
    psz2: PAnsiChar;
    psz3: PAnsiChar;
    pv: Pointer;            // user context
    hf: Integer;            // handle
    date: Word;
    time: Word;
    attribs: Word;
    setID: Word;
    iCabinet: Word;
    iFolder: Word;
    fdie: Integer;
  end;

  PFDICABINETINFO = ^TFDICABINETINFO;
  TFDICABINETINFO = record
    cbCabinet: LongInt;
    cFolders: Word;
    cFiles: Word;
    setID: Word;
    iCabinet: Word;
    fReserve: Integer;
    hasprev: Integer;
    hasnext: Integer;
  end;

  // Callbacks (cdecl)
  PFNALLOC = function(cb: Cardinal): Pointer; cdecl;
  PFNFREE  = procedure(pv: Pointer); cdecl;
  PFNOPEN  = function(const path: PAnsiChar; oflag, pmode: Integer): Integer; cdecl;
  PFNREAD  = function(hf: Integer; pv: Pointer; cb: Cardinal): Cardinal; cdecl;
  PFNWRITE = function(hf: Integer; pv: Pointer; cb: Cardinal): Cardinal; cdecl;
  PFNCLOSE = function(hf: Integer): Integer; cdecl;
  PFNSEEK  = function(hf: Integer; dist: LongInt; seektype: Integer): LongInt; cdecl;
  PFNFDINOTIFY = function(fdint: Integer; pfdin: PFDINOTIFICATION): Integer; cdecl;
  PFNFDIDECRYPT = Pointer;

// Link OBJs — providers last.
// Delphi: .obj OMF Win32 (bcc32c) ou .o ELF Win64 (bcc64) +
//   cabinet_main.obj (Win32 helpers + clean FDIDestroy wrapper).
// FPC: .o COFF mingw-w64 gcc (cabnet_obj_fpc_win{32,64}/) — pula
//   cabinet_main pois Wine fdi.o ja exporta FDIDestroy clean direto.
// v3.7.2 WRITE: adiciona zlib real linkado (8 .obj/.o) — MSZIP funcional.
// cabstubs ainda contem __assert/_assert + zlib stubs como fallback;
// linker resolve preferindo zlib real (definicoes vencem stubs).
{$IFDEF FPC}
  // FPC: linkar libs Win32 + CRT mingw que fdi.o/fci.o/zlib*.o referenciam
  {$LINKLIB kernel32}
  {$LINKLIB msvcrt}
  {$LINKLIB gcc}  // libgcc.a — fornece __moddi3 / __udivdi3 (64-bit math helpers gcc)
{$ENDIF}

{$IFDEF FPC}
  // Ordem CONSUMERS first, PROVIDERS last (single-pass Delphi linker)
  {$IFDEF WIN32}
    {$L Library\fpc-win32\fdi.o}
    {$L Library\fpc-win32\fci.o}
    {$L Library\fpc-win32\deflate.o}
    {$L Library\fpc-win32\inflate.o}
    {$L Library\fpc-win32\inftrees.o}
    {$L Library\fpc-win32\inffast.o}
    {$L Library\fpc-win32\trees.o}
    {$L Library\fpc-win32\adler32.o}
    {$L Library\fpc-win32\crc32.o}
    {$L Library\fpc-win32\zutil.o}
    {$L Library\fpc-win32\cabstubs.o}
  {$ENDIF}
  {$IFDEF WIN64}
    {$L Library\fpc-win64\fdi.o}
    {$L Library\fpc-win64\fci.o}
    {$L Library\fpc-win64\deflate.o}
    {$L Library\fpc-win64\inflate.o}
    {$L Library\fpc-win64\inftrees.o}
    {$L Library\fpc-win64\inffast.o}
    {$L Library\fpc-win64\trees.o}
    {$L Library\fpc-win64\adler32.o}
    {$L Library\fpc-win64\crc32.o}
    {$L Library\fpc-win64\zutil.o}
    {$L Library\fpc-win64\cabstubs.o}
  {$ENDIF}
{$ELSE}
  // v3.7.3: Delphi Win32 MSZIP HABILITADO — adler32 recompilado com
  // -DNO_DIVIDE (CHOP loop em vez de %= BASE) elimina referencia a
  // __aullrem que linker Delphi single-pass nao resolvia. zlib agora
  // linka completo em todas 4 toolchains.
  {$IFDEF WIN32}
    {$L Library\delphi-win32\cabinet_main.obj}
    {$L Library\delphi-win32\fdi.obj}
    {$L Library\delphi-win32\fci.obj}
    {$L Library\delphi-win32\deflate.obj}
    {$L Library\delphi-win32\inflate.obj}
    {$L Library\delphi-win32\inftrees.obj}
    {$L Library\delphi-win32\inffast.obj}
    {$L Library\delphi-win32\trees.obj}
    {$L Library\delphi-win32\adler32.obj}
    {$L Library\delphi-win32\crc32.obj}
    {$L Library\delphi-win32\zutil.obj}
    {$L Library\delphi-win32\cabstubs.obj}
  {$ENDIF}
  {$IFDEF WIN64}
    {$L Library\delphi-win64\cabinet_main.o}
    {$L Library\delphi-win64\fdi.o}
    {$L Library\delphi-win64\fci.o}
    {$L Library\delphi-win64\deflate.o}
    {$L Library\delphi-win64\inflate.o}
    {$L Library\delphi-win64\inftrees.o}
    {$L Library\delphi-win64\inffast.o}
    {$L Library\delphi-win64\trees.o}
    {$L Library\delphi-win64\adler32.o}
    {$L Library\delphi-win64\crc32.o}
    {$L Library\delphi-win64\zutil.o}
    {$L Library\delphi-win64\cabstubs.o}
  {$ENDIF}
{$ENDIF}

// Symbol naming differences:
//   Delphi Win32 OMF (bcc32c) -> '_FDICreate' (literal underscore esperado)
//   Delphi Win64 ELF (bcc64)  -> 'FDICreate' (sem prefix)
//   FPC Win32 COFF (mingw)    -> 'FDICreate' (FPC adiciona _ automaticamente
//                                 para match '_FDICreate' no .o)
//   FPC Win64 COFF (mingw)    -> 'FDICreate' (sem prefix)
{$IF DEFINED(CAB_C_UNDERSCORE) AND NOT DEFINED(FPC)}
function FDICreate(palloc: PFNALLOC; pfree: PFNFREE;
  pfopen: PFNOPEN; pfread: PFNREAD; pfwrite: PFNWRITE;
  pfclose: PFNCLOSE; pfseek: PFNSEEK;
  cpuType: Integer; perf: PERF): THfdi; cdecl;
  external name '_FDICreate';

function FDICopy(hfdi: THfdi; const pszCabinet, pszCabPath: PAnsiChar;
  flags: Integer; pfnfdin: PFNFDINOTIFY; pfnfdid: PFNFDIDECRYPT;
  pv: Pointer): Integer; cdecl;
  external name '_FDICopy';
{$ELSE}
function FDICreate(palloc: PFNALLOC; pfree: PFNFREE;
  pfopen: PFNOPEN; pfread: PFNREAD; pfwrite: PFNWRITE;
  pfclose: PFNCLOSE; pfseek: PFNSEEK;
  cpuType: Integer; perf: PERF): THfdi; cdecl;
  external name 'FDICreate';

function FDICopy(hfdi: THfdi; const pszCabinet, pszCabPath: PAnsiChar;
  flags: Integer; pfnfdin: PFNFDINOTIFY; pfnfdid: PFNFDIDECRYPT;
  pv: Pointer): Integer; cdecl;
  external name 'FDICopy';
{$IFEND}

// FDI Destroy: Delphi usa wrapper de cabinet_main; FPC usa direto de Wine fdi.o
{$IF DEFINED(CAB_C_UNDERSCORE) AND NOT DEFINED(FPC)}
function FDIDestroy(hfdi: THfdi): Integer; cdecl;
  external name '_FDIDestroy';
{$ELSE}
function FDIDestroy(hfdi: THfdi): Integer; cdecl;
  external name 'FDIDestroy';
{$IFEND}

// cabinet_main.obj (Delphi only) refere DllGetVersion — stub no-op
{$IFNDEF FPC}
  {$IFDEF CAB_C_UNDERSCORE}
function _DllGetVersion(pdvi: Pointer): LongInt; cdecl;
begin
  Result := 1;
end;
  {$ELSE}
function DllGetVersion(pdvi: Pointer): LongInt; cdecl;
begin
  Result := 1;
end;
  {$ENDIF}
{$ENDIF}

// Win32 APIs que cabinet_main.c usa
function CreateFileA(lpFileName: PAnsiChar; dwDesiredAccess, dwShareMode: Cardinal;
  lpSecurityAttributes: Pointer; dwCreationDisposition, dwFlagsAndAttributes: Cardinal;
  hTemplateFile: NativeUInt): NativeUInt; stdcall;
  external 'kernel32.dll' name 'CreateFileA';
function CloseHandle(hObject: NativeUInt): LongBool; stdcall;
  external 'kernel32.dll' name 'CloseHandle';
function ReadFile(hFile: NativeUInt; lpBuffer: Pointer; nNumberOfBytesToRead: Cardinal;
  lpNumberOfBytesRead, lpOverlapped: Pointer): LongBool; stdcall;
  external 'kernel32.dll' name 'ReadFile';
function WriteFile(hFile: NativeUInt; lpBuffer: Pointer; nNumberOfBytesToWrite: Cardinal;
  lpNumberOfBytesWritten, lpOverlapped: Pointer): LongBool; stdcall;
  external 'kernel32.dll' name 'WriteFile';
function SetFilePointer(hFile: NativeUInt; lDistanceToMove: Integer;
  lpDistanceToMoveHigh: Pointer; dwMoveMethod: Cardinal): Cardinal; stdcall;
  external 'kernel32.dll' name 'SetFilePointer';
function GetLastError: Cardinal; stdcall;
  external 'kernel32.dll' name 'GetLastError';
function GetFileAttributesA(lpFileName: PAnsiChar): Cardinal; stdcall;
  external 'kernel32.dll' name 'GetFileAttributesA';
function GetProcessHeap: NativeUInt; stdcall;
  external 'kernel32.dll' name 'GetProcessHeap';
function HeapAlloc(hHeap: NativeUInt; dwFlags: Cardinal; dwBytes: NativeUInt): Pointer; stdcall;
  external 'kernel32.dll' name 'HeapAlloc';
function HeapFree(hHeap: NativeUInt; dwFlags: Cardinal; lpMem: Pointer): LongBool; stdcall;
  external 'kernel32.dll' name 'HeapFree';
function lstrlenA(lpString: PAnsiChar): Integer; stdcall;
  external 'kernel32.dll' name 'lstrlenA';
function DosDateTimeToFileTime(wFatDate, wFatTime: Word; lpFileTime: Pointer): LongBool; stdcall;
  external 'kernel32.dll' name 'DosDateTimeToFileTime';
function lstrcpyA(lpString1, lpString2: PAnsiChar): PAnsiChar; stdcall;
  external 'kernel32.dll' name 'lstrcpyA';
function lstrcatA(lpString1, lpString2: PAnsiChar): PAnsiChar; stdcall;
  external 'kernel32.dll' name 'lstrcatA';
function lstrcpynA(lpString1, lpString2: PAnsiChar; iMaxLength: Integer): PAnsiChar; stdcall;
  external 'kernel32.dll' name 'lstrcpynA';
function lstrcmpiA(lpString1, lpString2: PAnsiChar): Integer; stdcall;
  external 'kernel32.dll' name 'lstrcmpiA';
function LocalFileTimeToFileTime(const lpLocalFileTime, lpFileTime: Pointer): LongBool; stdcall;
  external 'kernel32.dll' name 'LocalFileTimeToFileTime';
function SetFileTime(hFile: NativeUInt; const lpCreationTime, lpLastAccessTime, lpLastWriteTime: Pointer): LongBool; stdcall;
  external 'kernel32.dll' name 'SetFileTime';
function CreateDirectoryA(lpPathName: PAnsiChar; lpSecurityAttributes: Pointer): LongBool; stdcall;
  external 'kernel32.dll' name 'CreateDirectoryA';
function SetFileAttributesA(lpFileName: PAnsiChar; dwFileAttributes: Cardinal): LongBool; stdcall;
  external 'kernel32.dll' name 'SetFileAttributesA';
function DeleteFileA(lpFileName: PAnsiChar): LongBool; stdcall;
  external 'kernel32.dll' name 'DeleteFileA';
function PathFileExistsA(pszPath: PAnsiChar): LongBool; stdcall;
  external 'shlwapi.dll' name 'PathFileExistsA';

{$IFDEF CAB_C_UNDERSCORE}
function _strrchr(const s: PAnsiChar; c: Integer): PAnsiChar; cdecl;
{$ELSE}
function strrchr(const s: PAnsiChar; c: Integer): PAnsiChar; cdecl;
{$ENDIF}
var p, last: PAnsiChar;
begin
  p := s; last := nil;
  while p^ <> #0 do
  begin
    if p^ = AnsiChar(Byte(c)) then last := p;
    Inc(p);
  end;
  if c = 0 then Result := p else Result := last;
end;

// ============================================================================
//   Pascal-side state for FDI callbacks
// ============================================================================

type
  TCallbackContext = record
    WCabFile: TWCabFile;
    Mode: (cmList, cmExtract);
    ExtractName: AnsiString;
    ExtractStream: TStream;
  end;
  PCallbackContext = ^TCallbackContext;

var
  GCabCtx: TCallbackContext;  // single-threaded for now; thread-local in v3.7.1

// File-handle table (Pascal-managed; FDI handles são ints opacos)
const
  MAX_FDI_HANDLES = 16;
var
  GFdiHandles: array[0..MAX_FDI_HANDLES - 1] of TFileStream;

function AllocSlot: Integer;
var I: Integer;
begin
  for I := 0 to MAX_FDI_HANDLES - 1 do
    if GFdiHandles[I] = nil then Exit(I + 1);  // handles 1-based
  Result := -1;
end;

// ============================================================================
//   FDI callbacks
// ============================================================================

function CbAlloc(cb: Cardinal): Pointer; cdecl;
begin
  if cb = 0 then Result := nil else GetMem(Result, cb);
end;

procedure CbFree(pv: Pointer); cdecl;
begin
  if pv <> nil then FreeMem(pv);
end;

function CbOpen(const path: PAnsiChar; oflag, pmode: Integer): Integer; cdecl;
var
  Slot: Integer;
  S: string;
  Mode: Word;
begin
  Slot := AllocSlot;
  if Slot < 0 then Exit(-1);
  S := string(AnsiString(path));
  if (oflag and _O_RDWR) <> 0 then Mode := fmOpenReadWrite or fmShareDenyWrite
  else if (oflag and _O_WRONLY) <> 0 then Mode := fmCreate
  else Mode := fmOpenRead or fmShareDenyWrite;
  try
    if Mode = fmCreate then
      GFdiHandles[Slot - 1] := TFileStream.Create(S, fmCreate)
    else
      GFdiHandles[Slot - 1] := TFileStream.Create(S, Mode);
    Result := Slot;
  except
    Result := -1;
  end;
end;

function CbRead(hf: Integer; pv: Pointer; cb: Cardinal): Cardinal; cdecl;
begin
  Result := 0;
  if (hf < 1) or (hf > MAX_FDI_HANDLES) then Exit;
  if GFdiHandles[hf - 1] = nil then Exit;
  try
    Result := Cardinal(GFdiHandles[hf - 1].Read(pv^, cb));
  except
    Result := 0;
  end;
end;

function CbWrite(hf: Integer; pv: Pointer; cb: Cardinal): Cardinal; cdecl;
begin
  // No modo cmExtract, escrita vai para FCallbackContext.ExtractStream
  if (GCabCtx.Mode = cmExtract) and (GCabCtx.ExtractStream <> nil) and (hf = -7777) then
  begin
    try
      GCabCtx.ExtractStream.WriteBuffer(pv^, cb);
      Exit(cb);
    except
      Exit(0);
    end;
  end;
  Result := 0;
  if (hf < 1) or (hf > MAX_FDI_HANDLES) then Exit;
  if GFdiHandles[hf - 1] = nil then Exit;
  try
    Result := Cardinal(GFdiHandles[hf - 1].Write(pv^, cb));
  except
    Result := 0;
  end;
end;

function CbClose(hf: Integer): Integer; cdecl;
begin
  Result := 0;
  if hf = -7777 then Exit;  // virtual extract handle
  if (hf < 1) or (hf > MAX_FDI_HANDLES) then Exit;
  if GFdiHandles[hf - 1] <> nil then
  begin
    GFdiHandles[hf - 1].Free;
    GFdiHandles[hf - 1] := nil;
  end;
end;

function CbSeek(hf: Integer; dist: LongInt; seektype: Integer): LongInt; cdecl;
var Origin: TSeekOrigin;
begin
  Result := -1;
  if hf = -7777 then
  begin
    if (GCabCtx.ExtractStream <> nil) then
    begin
      case seektype of
        SEEK_SET: Origin := soBeginning;
        SEEK_CUR: Origin := soCurrent;
        SEEK_END: Origin := soEnd;
      else Origin := soBeginning;
      end;
      Result := LongInt(GCabCtx.ExtractStream.Seek(Int64(dist), Origin));
    end;
    Exit;
  end;
  if (hf < 1) or (hf > MAX_FDI_HANDLES) then Exit;
  if GFdiHandles[hf - 1] = nil then Exit;
  case seektype of
    SEEK_SET: Origin := soBeginning;
    SEEK_CUR: Origin := soCurrent;
    SEEK_END: Origin := soEnd;
  else Origin := soBeginning;
  end;
  try
    Result := LongInt(GFdiHandles[hf - 1].Seek(Int64(dist), Origin));
  except
    Result := -1;
  end;
end;

// FDI notification callback — chamado para cada arquivo no cabinet
function CbNotify(fdint: Integer; pfdin: PFDINOTIFICATION): Integer; cdecl;
var
  Name: AnsiString;
  Entry: TCabEntry;
begin
  Result := 0;
  case fdint of
    fdintCABINET_INFO: Result := 0;
    fdintCOPY_FILE:
    begin
      Name := AnsiString(pfdin^.psz1);
      if GCabCtx.Mode = cmList then
      begin
        Entry.Name := string(Name);
        Entry.Size := pfdin^.cb;
        Entry.Date := Now;
        SetLength(GCabCtx.WCabFile.FEntries, Length(GCabCtx.WCabFile.FEntries) + 1);
        GCabCtx.WCabFile.FEntries[High(GCabCtx.WCabFile.FEntries)] := Entry;
        Result := 0;  // skip — não extrair em modo list
      end
      else if GCabCtx.Mode = cmExtract then
      begin
        if SameText(string(Name), string(GCabCtx.ExtractName)) then
          Result := -7777  // virtual handle — sinaliza para extrair
        else
          Result := 0;     // skip outros
      end;
    end;
    fdintCLOSE_FILE_INFO: Result := 1;  // ack close
  else
    Result := 0;
  end;
end;

// ============================================================================
//   FCI types (Microsoft) — WRITE side
// ============================================================================

const
  CB_MAX_DISK          = $7FFFFFFF;
  CB_MAX_CABINET_NAME  = 256;
  CB_MAX_CAB_PATH      = 256;
  CB_MAX_DISK_NAME     = 256;
  tcompTYPE_NONE       = $0000;
  tcompTYPE_MSZIP      = $0001;

type
  THfci = Pointer;

  PCCAB = ^TCCAB;
  TCCAB = packed record
    cb: Cardinal;
    cbFolderThresh: Cardinal;
    cbReserveCFHeader: Cardinal;
    cbReserveCFFolder: Cardinal;
    cbReserveCFData: Cardinal;
    iCab: Integer;
    iDisk: Integer;
    fFailOnIncompressible: Integer;
    setID: Word;
    szDisk: array[0..CB_MAX_DISK_NAME - 1] of AnsiChar;
    szCab: array[0..CB_MAX_CABINET_NAME - 1] of AnsiChar;
    szCabPath: array[0..CB_MAX_CAB_PATH - 1] of AnsiChar;
  end;

  PFNFCIALLOC = function(cb: Cardinal): Pointer; cdecl;
  PFNFCIFREE  = procedure(pv: Pointer); cdecl;
  PFNFCIOPEN  = function(const path: PAnsiChar; oflag, pmode: Integer; var err: Integer; pv: Pointer): Integer; cdecl;
  PFNFCIREAD  = function(hf: Integer; buf: Pointer; cb: Cardinal; var err: Integer; pv: Pointer): Cardinal; cdecl;
  PFNFCIWRITE = function(hf: Integer; buf: Pointer; cb: Cardinal; var err: Integer; pv: Pointer): Cardinal; cdecl;
  PFNFCICLOSE = function(hf: Integer; var err: Integer; pv: Pointer): Integer; cdecl;
  PFNFCISEEK  = function(hf: Integer; dist: LongInt; seektype: Integer; var err: Integer; pv: Pointer): LongInt; cdecl;
  PFNFCIDELETE = function(const path: PAnsiChar; var err: Integer; pv: Pointer): Integer; cdecl;
  PFNFCIGETTEMPFILE = function(pszTempName: PAnsiChar; cbTempName: Integer; pv: Pointer): LongBool; cdecl;
  PFNFCIGETOPENINFO = function(pszName: PAnsiChar; var pdate, ptime, pattribs: Word; var err: Integer; pv: Pointer): NativeInt; cdecl;
  PFNFCIGETNEXTCABINET = function(pccab: PCCAB; cbPrevCab: Cardinal; pv: Pointer): LongBool; cdecl;
  PFNFCIFILEPLACED = function(pccab: PCCAB; pszFile: PAnsiChar; cbFile: LongInt; fContinuation: LongBool; pv: Pointer): Integer; cdecl;
  PFNFCISTATUS = function(typeStatus: Cardinal; cb1, cb2: Cardinal; pv: Pointer): LongInt; cdecl;

{$IF DEFINED(CAB_C_UNDERSCORE) AND NOT DEFINED(FPC)}
function FCICreate(perf: PERF; pfnfcifp: PFNFCIFILEPLACED;
  pfna: PFNFCIALLOC; pfnf: PFNFCIFREE;
  pfnopen: PFNFCIOPEN; pfnread: PFNFCIREAD; pfnwrite: PFNFCIWRITE;
  pfnclose: PFNFCICLOSE; pfnseek: PFNFCISEEK; pfndelete: PFNFCIDELETE;
  pfnfcigtf: PFNFCIGETTEMPFILE; pccab: PCCAB; pv: Pointer): THfci; cdecl;
  external name '_FCICreate';
function FCIAddFile(hfci: THfci; pszSourceFile, pszFileName: PAnsiChar;
  fExecute: LongBool; pfnfcignc: PFNFCIGETNEXTCABINET;
  pfnfcis: PFNFCISTATUS; pfnfcigoi: PFNFCIGETOPENINFO;
  typeCompress: Word): LongBool; cdecl;
  external name '_FCIAddFile';
function FCIFlushCabinet(hfci: THfci; fGetNextCab: LongBool;
  pfnfcignc: PFNFCIGETNEXTCABINET; pfnfcis: PFNFCISTATUS): LongBool; cdecl;
  external name '_FCIFlushCabinet';
function FCIDestroy(hfci: THfci): LongBool; cdecl;
  external name '_FCIDestroy';
{$ELSE}
function FCICreate(perf: PERF; pfnfcifp: PFNFCIFILEPLACED;
  pfna: PFNFCIALLOC; pfnf: PFNFCIFREE;
  pfnopen: PFNFCIOPEN; pfnread: PFNFCIREAD; pfnwrite: PFNFCIWRITE;
  pfnclose: PFNFCICLOSE; pfnseek: PFNFCISEEK; pfndelete: PFNFCIDELETE;
  pfnfcigtf: PFNFCIGETTEMPFILE; pccab: PCCAB; pv: Pointer): THfci; cdecl;
  external name 'FCICreate';
function FCIAddFile(hfci: THfci; pszSourceFile, pszFileName: PAnsiChar;
  fExecute: LongBool; pfnfcignc: PFNFCIGETNEXTCABINET;
  pfnfcis: PFNFCISTATUS; pfnfcigoi: PFNFCIGETOPENINFO;
  typeCompress: Word): LongBool; cdecl;
  external name 'FCIAddFile';
function FCIFlushCabinet(hfci: THfci; fGetNextCab: LongBool;
  pfnfcignc: PFNFCIGETNEXTCABINET; pfnfcis: PFNFCISTATUS): LongBool; cdecl;
  external name 'FCIFlushCabinet';
function FCIDestroy(hfci: THfci): LongBool; cdecl;
  external name 'FCIDestroy';
{$IFEND}

// Win32 APIs adicionais para FCI temp file callback
function GetTempFileNameA(lpPathName, lpPrefixString: PAnsiChar;
  uUnique: Cardinal; lpTempFileName: PAnsiChar): Cardinal; stdcall;
  external 'kernel32.dll' name 'GetTempFileNameA';
function GetTempPathA(nBufferLength: Cardinal; lpBuffer: PAnsiChar): Cardinal; stdcall;
  external 'kernel32.dll' name 'GetTempPathA';

// ============================================================================
//   FCI callbacks (WRITE side, Pascal-implementadas)
// ============================================================================

function FCb_Alloc(cb: Cardinal): Pointer; cdecl;
begin
  if cb = 0 then Result := nil else GetMem(Result, cb);
end;
procedure FCb_Free(pv: Pointer); cdecl;
begin
  if pv <> nil then FreeMem(pv);
end;
function FCb_Open(const path: PAnsiChar; oflag, pmode: Integer;
  var err: Integer; pv: Pointer): Integer; cdecl;
var Slot: Integer; S: string; WriteAccess: Boolean;
begin
  err := 0;
  Slot := AllocSlot;
  if Slot < 0 then begin err := 24; Exit(-1); end;
  S := string(AnsiString(path));
  WriteAccess := ((oflag and _O_RDWR) <> 0) or ((oflag and _O_WRONLY) <> 0);
  try
    if WriteAccess or not SysUtils.FileExists(S) then
      GFdiHandles[Slot - 1] := TFileStream.Create(S, fmCreate)
    else
      GFdiHandles[Slot - 1] := TFileStream.Create(S, fmOpenReadWrite or fmShareDenyWrite);
    Result := Slot;
  except err := 5; Result := -1; end;
end;
function FCb_Read(hf: Integer; buf: Pointer; cb: Cardinal; var err: Integer; pv: Pointer): Cardinal; cdecl;
begin
  err := 0; Result := 0;
  if (hf < 1) or (hf > MAX_FDI_HANDLES) or (GFdiHandles[hf - 1] = nil) then Exit;
  try Result := Cardinal(GFdiHandles[hf - 1].Read(buf^, cb));
  except err := 5; end;
end;
function FCb_Write(hf: Integer; buf: Pointer; cb: Cardinal; var err: Integer; pv: Pointer): Cardinal; cdecl;
begin
  err := 0; Result := 0;
  if (hf < 1) or (hf > MAX_FDI_HANDLES) or (GFdiHandles[hf - 1] = nil) then Exit;
  try Result := Cardinal(GFdiHandles[hf - 1].Write(buf^, cb));
  except err := 5; end;
end;
function FCb_Close(hf: Integer; var err: Integer; pv: Pointer): Integer; cdecl;
begin
  err := 0; Result := 0;
  if (hf < 1) or (hf > MAX_FDI_HANDLES) then Exit;
  if GFdiHandles[hf - 1] <> nil then begin GFdiHandles[hf - 1].Free; GFdiHandles[hf - 1] := nil; end;
end;
function FCb_Seek(hf: Integer; dist: LongInt; seektype: Integer; var err: Integer; pv: Pointer): LongInt; cdecl;
var Origin: TSeekOrigin;
begin
  err := 0; Result := -1;
  if (hf < 1) or (hf > MAX_FDI_HANDLES) or (GFdiHandles[hf - 1] = nil) then Exit;
  case seektype of
    SEEK_SET: Origin := soBeginning;
    SEEK_CUR: Origin := soCurrent;
    SEEK_END: Origin := soEnd;
  else Origin := soBeginning;
  end;
  try Result := LongInt(GFdiHandles[hf - 1].Seek(Int64(dist), Origin));
  except err := 5; end;
end;
function FCb_Delete(const path: PAnsiChar; var err: Integer; pv: Pointer): Integer; cdecl;
begin
  err := 0;
  if SysUtils.DeleteFile(string(AnsiString(path))) then Result := 0 else begin err := 5; Result := -1; end;
end;
function FCb_GetTempFile(pszTempName: PAnsiChar; cbTempName: Integer; pv: Pointer): LongBool; cdecl;
var
  PathBuf: array[0..511] of AnsiChar;
  TmpBuf:  array[0..511] of AnsiChar;
  N, I: Cardinal;
begin
  Result := False;
  N := GetTempPathA(SizeOf(PathBuf), @PathBuf[0]);
  if N = 0 then Exit;
  if GetTempFileNameA(@PathBuf[0], 'CAB', 0, @TmpBuf[0]) = 0 then Exit;
  // GetTempFileNameA cria o arquivo; FCI espera nome livre — apaga
  SysUtils.DeleteFile(string(AnsiString(@TmpBuf[0])));
  I := 0;
  while (I < Cardinal(cbTempName) - 1) and (TmpBuf[I] <> #0) do
  begin
    pszTempName[I] := TmpBuf[I];
    Inc(I);
  end;
  pszTempName[I] := #0;
  Result := True;
end;
function FCb_FilePlaced(pccab: PCCAB; pszFile: PAnsiChar; cbFile: LongInt;
  fContinuation: LongBool; pv: Pointer): Integer; cdecl;
begin Result := 0; end;
function FCb_GetNextCabinet(pccab: PCCAB; cbPrevCab: Cardinal; pv: Pointer): LongBool; cdecl;
begin Result := False; end;
function FCb_Status(typeStatus: Cardinal; cb1, cb2: Cardinal; pv: Pointer): LongInt; cdecl;
begin Result := 0; end;
function FCb_GetOpenInfo(pszName: PAnsiChar; var pdate, ptime, pattribs: Word;
  var err: Integer; pv: Pointer): NativeInt; cdecl;
var S: string; Slot: Integer;
begin
  err := 0; Result := -1;
  S := string(AnsiString(pszName));
  if not SysUtils.FileExists(S) then begin err := 2; Exit; end;
  // DOS date 2026-01-01 00:00:00 (evita SysUtils.DateTimeToDosDateTime
  // signature differences Delphi vs FPC)
  pdate := (Word(2026 - 1980) shl 9) or (1 shl 5) or 1;
  ptime := 0;
  pattribs := $20;  // archive bit
  Slot := AllocSlot;
  if Slot < 0 then begin err := 24; Exit; end;
  try
    GFdiHandles[Slot - 1] := TFileStream.Create(S, fmOpenRead or fmShareDenyWrite);
    Result := Slot;
  except err := 5; Result := -1; end;
end;

{$ENDIF}  // CAB_AVAILABLE

// ============================================================================
//   TWCabFile
// ============================================================================

constructor TWCabFile.Create(AOwner: TComponent);
begin
  inherited;
  FActive := False;
  FCompression := cctNone;  // v3.7.1: MSZIP stub-only; cctNone funcional
  FCompressionLevel := 6;
  FSetID := 0;
  FCabinetIndex := 0;
  FVolumeSize := 0;
  FReserveSize := 0;
end;

procedure TWCabFile.SetCompressionLevel(AValue: Integer);
begin
  if (AValue < 1) or (AValue > 9) then
    raise ECabError.CreateFmt('CompressionLevel must be 1..9 (got %d)', [AValue]);
  FCompressionLevel := AValue;
end;

destructor TWCabFile.Destroy;
begin
  Close;
  inherited;
end;

procedure TWCabFile.SetActive(AValue: Boolean);
begin
  if AValue = FActive then Exit;
  if AValue then Open else Close;
end;

procedure TWCabFile.SetFileName(const AValue: string);
begin
  if AValue = FFileName then Exit;
  Close;
  FFileName := AValue;
  if Assigned(FOnFileChanged) then FOnFileChanged(Self);
end;

procedure TWCabFile.DoListEntries;
{$IFDEF CAB_AVAILABLE}
var
  Hfdi: THfdi;
  Erf: TERF;
  Path, Name: AnsiString;
{$ENDIF}
begin
  {$IFDEF CAB_AVAILABLE}
  SetLength(FEntries, 0);
  FillChar(Erf, SizeOf(Erf), 0);
  Hfdi := FDICreate(CbAlloc, CbFree, CbOpen, CbRead, CbWrite, CbClose, CbSeek,
    cpu80386, @Erf);
  if Hfdi = nil then
    raise ECabError.CreateFmt('FDICreate falhou (oper=%d type=%d)', [Erf.erfOper, Erf.erfType]);
  try
    GCabCtx.WCabFile := Self;
    GCabCtx.Mode := cmList;
    GCabCtx.ExtractStream := nil;

    // FDICopy precisa pszCabinet relativo a pszCabPath
    Name := AnsiString(ExtractFileName(FFileName));
    Path := AnsiString(ExtractFilePath(ExpandFileName(FFileName)));
    if Path = '' then Path := AnsiString(IncludeTrailingPathDelimiter(GetCurrentDir));
    if FDICopy(Hfdi, PAnsiChar(Name), PAnsiChar(Path), 0, @CbNotify, nil, nil) = 0 then
    begin
      // FDICopy retorna FALSE em erro
      if Erf.fError <> 0 then
        raise ECabError.CreateFmt('FDICopy falhou (erfOper=%d)', [Erf.erfOper]);
    end;
  finally
    FDIDestroy(Hfdi);
    GCabCtx.WCabFile := nil;
  end;
  {$ENDIF}
end;

procedure TWCabFile.DoExtract(const AName: string; ADst: TStream);
{$IFDEF CAB_AVAILABLE}
var
  Hfdi: THfdi;
  Erf: TERF;
  Path, Name: AnsiString;
{$ENDIF}
begin
  {$IFDEF CAB_AVAILABLE}
  FillChar(Erf, SizeOf(Erf), 0);
  Hfdi := FDICreate(CbAlloc, CbFree, CbOpen, CbRead, CbWrite, CbClose, CbSeek,
    cpu80386, @Erf);
  if Hfdi = nil then
    raise ECabError.CreateFmt('FDICreate falhou (oper=%d)', [Erf.erfOper]);
  try
    GCabCtx.WCabFile := Self;
    GCabCtx.Mode := cmExtract;
    GCabCtx.ExtractName := AnsiString(AName);
    GCabCtx.ExtractStream := ADst;

    Name := AnsiString(ExtractFileName(FFileName));
    Path := AnsiString(ExtractFilePath(ExpandFileName(FFileName)));
    if Path = '' then Path := AnsiString(IncludeTrailingPathDelimiter(GetCurrentDir));
    FDICopy(Hfdi, PAnsiChar(Name), PAnsiChar(Path), 0, @CbNotify, nil, nil);
  finally
    FDIDestroy(Hfdi);
    GCabCtx.ExtractStream := nil;
    GCabCtx.ExtractName := '';
  end;
  {$ENDIF}
end;

procedure TWCabFile.Open;
begin
  if FActive then Exit;
  if FFileName = '' then
    raise ECabError.Create('TWCabFile.Open: FileName not set');
  if not SysUtils.FileExists(FFileName) then
    raise ECabError.CreateFmt('TWCabFile.Open: file "%s" not found', [FFileName]);
  {$IFDEF CAB_AVAILABLE}
  DoListEntries;
  FActive := True;
  {$ELSE}
  raise ECabNotSupportedOnPlatform.Create('TWCabFile requer Delphi Win32.');
  {$ENDIF}
end;

procedure TWCabFile.Close;
begin
  if not FActive then Exit;
  SetLength(FEntries, 0);
  FActive := False;
end;

function TWCabFile.GetEntryCount: Integer;
begin
  Result := Length(FEntries);
end;

function TWCabFile.FindIndex(const AName: string): Integer;
var I: Integer;
begin
  Result := -1;
  for I := 0 to High(FEntries) do
    if SameText(FEntries[I].Name, AName) then Exit(I);
end;

function TWCabFile.FileExists(const AName: string): Boolean;
begin
  Result := FindIndex(AName) >= 0;
end;

function TWCabFile.GetFileSize(AIndex: Integer): Int64;
begin
  if (AIndex >= 0) and (AIndex <= High(FEntries)) then
    Result := FEntries[AIndex].Size
  else
    Result := 0;
end;

function TWCabFile.GetEntryName(AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex <= High(FEntries)) then
    Result := FEntries[AIndex].Name
  else
    Result := '';
end;

function TWCabFile.GetEntryStream(const AName: string): TStream;
var Mem: TMemoryStream;
begin
  if not FActive then
    raise ECabError.Create('TWCabFile.GetEntryStream: not active');
  if FindIndex(AName) < 0 then
    raise ECabError.CreateFmt('TWCabFile.GetEntryStream: entry "%s" not found', [AName]);
  Mem := TMemoryStream.Create;
  try
    DoExtract(AName, Mem);
    Mem.Position := 0;
    Result := Mem;
  except
    Mem.Free;
    raise;
  end;
end;

function TWCabFile.ReadAsBytes(const AName: string): TBytes;
var Stm: TStream;
begin
  Stm := GetEntryStream(AName);
  try
    SetLength(Result, Stm.Size);
    if Stm.Size > 0 then
    begin
      Stm.Position := 0;
      Stm.ReadBuffer(Result[0], Stm.Size);
    end;
  finally
    Stm.Free;
  end;
end;

function TWCabFile.ReadAsString(const AName: string): string;
var B: TBytes; S: AnsiString;
begin
  B := ReadAsBytes(AName);
  SetLength(S, Length(B));
  if Length(B) > 0 then Move(B[0], S[1], Length(B));
  Result := string(S);
end;

procedure TWCabFile.CreateFromFiles(const ASourcesAndNames: array of string);
{$IFDEF CAB_AVAILABLE}
var
  Hfci: THfci;
  Erf: TERF;
  Ccab: TCCAB;
  PathOut, NameOut, Src, NameIn: AnsiString;
  TypeCompress: Word;
  I: Integer;
{$ENDIF}
begin
  {$IFDEF CAB_AVAILABLE}
  if (Length(ASourcesAndNames) mod 2) <> 0 then
    raise ECabError.Create('CreateFromFiles: array deve ter pares source|name (length par)');
  if FFileName = '' then
    raise ECabError.Create('CreateFromFiles: FileName not set');

  FillChar(Erf, SizeOf(Erf), 0);
  FillChar(Ccab, SizeOf(Ccab), 0);
  Ccab.cb := CB_MAX_DISK;
  Ccab.cbFolderThresh := 900 * 1024;
  Ccab.iCab := 1;
  Ccab.iDisk := 0;
  Ccab.setID := 0;
  PathOut := AnsiString(ExtractFilePath(ExpandFileName(FFileName)));
  if PathOut = '' then PathOut := AnsiString(IncludeTrailingPathDelimiter(GetCurrentDir));
  NameOut := AnsiString(ExtractFileName(FFileName));
  Move(PAnsiChar(PathOut)^, Ccab.szCabPath[0], Length(PathOut));
  Move(PAnsiChar(NameOut)^, Ccab.szCab[0],     Length(NameOut));

  if FCompression = cctMSZIP then TypeCompress := tcompTYPE_MSZIP
  else TypeCompress := tcompTYPE_NONE;

  Hfci := FCICreate(@Erf, @FCb_FilePlaced, @FCb_Alloc, @FCb_Free,
    @FCb_Open, @FCb_Read, @FCb_Write, @FCb_Close, @FCb_Seek, @FCb_Delete,
    @FCb_GetTempFile, @Ccab, nil);
  if Hfci = nil then
    raise ECabError.CreateFmt('FCICreate falhou (oper=%d type=%d)', [Erf.erfOper, Erf.erfType]);
  try
    I := 0;
    while I < Length(ASourcesAndNames) do
    begin
      Src := AnsiString(ASourcesAndNames[I]);
      NameIn := AnsiString(ASourcesAndNames[I + 1]);
      if not FCIAddFile(Hfci, PAnsiChar(Src), PAnsiChar(NameIn), False,
        @FCb_GetNextCabinet, @FCb_Status, @FCb_GetOpenInfo, TypeCompress) then
        raise ECabError.CreateFmt('FCIAddFile("%s") falhou (erf %d)',
          [ASourcesAndNames[I], Erf.erfOper]);
      Inc(I, 2);
    end;
    if not FCIFlushCabinet(Hfci, False, @FCb_GetNextCabinet, @FCb_Status) then
      raise ECabError.CreateFmt('FCIFlushCabinet falhou (erf %d)', [Erf.erfOper]);
  finally
    FCIDestroy(Hfci);
  end;
  {$ELSE}
  raise ECabNotSupportedOnPlatform.Create('TWCabFile.CreateFromFiles: platform unsupported');
  {$ENDIF}
end;

function TWCabFile.WithFileName(const APath: string): TWCabFile;
begin
  SetFileName(APath);
  Result := Self;
end;

function TWCabFile.ThatOpens: TWCabFile;
begin
  Open;
  Result := Self;
end;

{ ============================================================================
  Fluent builder + factory — relocated from former Cab.Fluent.pas (dissolved
  per backend-pascal-unit-naming_V1.6.0 §2; interface in companion .Interfaces.pas).
  ============================================================================ }

constructor TCabFileBuilder.CreateNew(const APath: string);
begin
  inherited Create;
  FArchivePath := APath;
  FOpenForRead := False;
  FCompression := cctNone;
  if SysUtils.FileExists(APath) then SysUtils.DeleteFile(APath);
end;

constructor TCabFileBuilder.CreateOpen(const APath: string);
begin
  inherited Create;
  FArchivePath := APath;
  FOpenForRead := True;
end;

function TCabFileBuilder.WithCompression(AKind: TCabCompressionType): ICabFileBuilder;
begin
  FCompression := AKind;
  Result := Self;
end;

function TCabFileBuilder.AppendFile(const ADiskFileName, AEntryName: string): ICabFileBuilder;
var Item: TCabBuilderItem;
begin
  Item.DiskFileName := ADiskFileName;
  Item.EntryName := AEntryName;
  SetLength(FItems, Length(FItems) + 1);
  FItems[High(FItems)] := Item;
  Result := Self;
end;

procedure TCabFileBuilder.Execute;
var
  Cab: TWCabFile;
  List: array of string;
  I: Integer;
begin
  if Length(FItems) = 0 then
    raise ECabError.Create('TCabFileBuilder.Execute: nenhum file appended', ERR_ZIPFILE_CAB);
  Cab := TWCabFile.Create(nil);
  try
    Cab.FileName := FArchivePath;
    Cab.Compression := FCompression;
    SetLength(List, Length(FItems) * 2);
    for I := 0 to High(FItems) do
    begin
      List[I * 2]     := FItems[I].DiskFileName;
      List[I * 2 + 1] := FItems[I].EntryName;
    end;
    Cab.CreateFromFiles(List);
  finally Cab.Free; end;
end;

function TCabFileBuilder.ExtractStream(const AEntryName: string): TStream;
var Cab: TWCabFile;
begin
  Cab := TWCabFile.Create(nil);
  try
    Cab.FileName := FArchivePath;
    Cab.Active := True;
    Result := Cab.GetEntryStream(AEntryName);
  finally Cab.Free; end;
end;

function TCabFileBuilder.ReadAsBytes(const AEntryName: string): TBytes;
var Cab: TWCabFile;
begin
  Cab := TWCabFile.Create(nil);
  try
    Cab.FileName := FArchivePath;
    Cab.Active := True;
    Result := Cab.ReadAsBytes(AEntryName);
  finally Cab.Free; end;
end;

function TCabFileBuilder.ReadAsString(const AEntryName: string): string;
var Cab: TWCabFile;
begin
  Cab := TWCabFile.Create(nil);
  try
    Cab.FileName := FArchivePath;
    Cab.Active := True;
    Result := Cab.ReadAsString(AEntryName);
  finally Cab.Free; end;
end;

function TCabFileBuilder.HasEntry(const AEntryName: string): Boolean;
var Cab: TWCabFile;
begin
  Cab := TWCabFile.Create(nil);
  try
    Cab.FileName := FArchivePath;
    Cab.Active := True;
    Result := Cab.FileExists(AEntryName);
  finally Cab.Free; end;
end;

function TCabFileBuilder.CountEntries: Integer;
var Cab: TWCabFile;
begin
  Cab := TWCabFile.Create(nil);
  try
    Cab.FileName := FArchivePath;
    Cab.Active := True;
    Result := Cab.EntryCount;
  finally Cab.Free; end;
end;

class function Cabinet.NewArchive(const APath: string): ICabFileBuilder;
begin
  Result := TCabFileBuilder.CreateNew(APath);
end;

class function Cabinet.OpenArchive(const APath: string): ICabFileBuilder;
begin
  Result := TCabFileBuilder.CreateOpen(APath);
end;

end.
