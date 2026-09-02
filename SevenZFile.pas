{ =============================================================================
  SevenZFile - absorvido do ZipFileORM v4.0.0 (modulo ZipFile, F1-A Onda A.3)

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
{ SevenZFile.pas

  TSevenZFile — READ-only 7zip (.7z) decoder for Delphi (Win32+Win64).

  Implementação: linka estaticamente os .obj/.o do LZMA SDK 24.07 (já
  presentes em Lib/lzma_obj_win32 + Lib/lzma_obj_win64) + wrapper
  minimalista C (sdk/lzma2601/C/SevenZWrapper.c) que encapsula:
   - CSzArEx (archive directory)
   - CFileInStream + CLookToRead2 (I/O machinery)
   - ISzAlloc instances + solid-block extract cache

  API espelhada de TZipFile para uniformidade:
   - Active, FileName, Open, Close
   - EntryCount, FileExists, IsDir, GetFileSize
   - GetEntryStream, ReadAsBytes, ReadAsString
   - FindFirst/Next (opcional)

  Não suporta WRITE (v3.2 se demanda — encoder LZMA2 + container 7z é
  complexo). Não suporta archives 7z criptografados com senha por
  enquanto (TODO v3.1.1 via SzCtx_SetPassword extender wrapper).

  Plataformas suportadas (v3.1.1+):
   - Delphi Win32: ✅ via OBJs OMF (bcc32c BCC102/D29)
   - Delphi Win64: ✅ via OBJs ELF (bcc64 D37) + Aes/Sha256 combinados
     (fix mutual deps + stub HW; vide §15.4 do SPEC v3.x)
   - FPC: raise ESevenZNotSupportedOnPlatform (sem rota planeada).
}
unit SevenZFile;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Classes, Commons.ZipFile.Types, ZipFile.Events,
  SevenZFile.Interfaces, SevenZFile.Exceptions, SevenZFile.Types, Exceptions.ZipFile;

type
  // Exception + codec types relocated to companion units (Wave 3a split):
  //   - ESevenZError, ESevenZNotSupportedOnPlatform: SevenZFile.Exceptions
  //   - TSevenZMethod, TSevenZFilter, TSevenZCrypto, TLzmaMatchFinder,
  //     TLzmaAlgorithm: SevenZFile.Types
  // Re-exported as aliases for backward compat with `uses SevenZFile`.
  ESevenZError = SevenZFile.Exceptions.ESevenZError;
  ESevenZNotSupportedOnPlatform = SevenZFile.Exceptions.ESevenZNotSupportedOnPlatform;

  // Fluent builder + factory (relocated from former SevenZ.Fluent.pas per
  // backend-pascal-unit-naming_V1.6.0 §2). Interface ISevenZFileBuilder lives
  // in SevenZFile.Interfaces.pas. TSevenZBuilderMethod is builder-internal
  // (distinct from TSevenZMethod which encodes the on-wire codec ID).
  TSevenZBuilderMethod = (szbStore, szbLzma2);

  TSevenZBuilderItem = record
    Kind: (sbkFile, sbkBytes);
    EntryName: string;
    DiskFileName: string;
    Data: TBytes;
  end;

  TSevenZFileBuilder = class(TInterfacedObject, ISevenZFileBuilder)
  private
    FArchivePath: string;
    FOpenForRead: Boolean;
    FMethod: TSevenZBuilderMethod;
    FLevel: Integer;
    FItems: array of TSevenZBuilderItem;
  public
    constructor CreateNew(const APath: string);
    constructor CreateOpen(const APath: string);
    function WithStore: ISevenZFileBuilder;
    function WithLZMA2(ALevel: Integer = 5): ISevenZFileBuilder;
    function AppendFile(const ADiskFileName, AEntryName: string): ISevenZFileBuilder;
    function AppendBytes(const AData: TBytes; const AEntryName: string): ISevenZFileBuilder;
    procedure Execute;
    function ExtractStream(const AEntryName: string): TStream;
    function ReadAsBytes(const AEntryName: string): TBytes;
    function ReadAsString(const AEntryName: string): string;
    function HasEntry(const AEntryName: string): Boolean;
    function CountEntries: Integer;
  end;

  SevenZip = class
  public
    class function NewArchive(const APath: string): ISevenZFileBuilder;
    class function OpenArchive(const APath: string): ISevenZFileBuilder;
  end;

  // Codec / filter / crypto / LZMA tuning enums relocated to
  // SevenZFile.Types.pas (Wave 3a). Aliased here so `uses SevenZFile`
  // consumers continue to see TSevenZMethod, TSevenZFilter, etc.
  TSevenZMethod    = SevenZFile.Types.TSevenZMethod;
  TSevenZFilter    = SevenZFile.Types.TSevenZFilter;
  TSevenZCrypto    = SevenZFile.Types.TSevenZCrypto;
  TLzmaMatchFinder = SevenZFile.Types.TLzmaMatchFinder;
  TLzmaAlgorithm   = SevenZFile.Types.TLzmaAlgorithm;

const
  // Enum-value aliases (Delphi+FPC support const alias of enum members).
  szmCopy      = SevenZFile.Types.szmCopy;
  szmLzma2     = SevenZFile.Types.szmLzma2;
  szmLzma      = SevenZFile.Types.szmLzma;
  szmPpmd      = SevenZFile.Types.szmPpmd;
  szmDeflate   = SevenZFile.Types.szmDeflate;
  szmDeflate64 = SevenZFile.Types.szmDeflate64;
  szmBzip2     = SevenZFile.Types.szmBzip2;
  szmZstd      = SevenZFile.Types.szmZstd;
  szmBrotli    = SevenZFile.Types.szmBrotli;
  szmLz4       = SevenZFile.Types.szmLz4;
  szmLz5       = SevenZFile.Types.szmLz5;
  szmLizard    = SevenZFile.Types.szmLizard;
  szfNone   = SevenZFile.Types.szfNone;
  szfDelta  = SevenZFile.Types.szfDelta;
  szfBCJ    = SevenZFile.Types.szfBCJ;
  szfBCJ2   = SevenZFile.Types.szfBCJ2;
  szfPPC    = SevenZFile.Types.szfPPC;
  szfIA64   = SevenZFile.Types.szfIA64;
  szfARM    = SevenZFile.Types.szfARM;
  szfARMT   = SevenZFile.Types.szfARMT;
  szfSPARC  = SevenZFile.Types.szfSPARC;
  szfARM64  = SevenZFile.Types.szfARM64;
  szfRISCV  = SevenZFile.Types.szfRISCV;
  szcNone      = SevenZFile.Types.szcNone;
  szcAES256    = SevenZFile.Types.szcAES256;
  szcZipCrypto = SevenZFile.Types.szcZipCrypto;
  mfBT2 = SevenZFile.Types.mfBT2;
  mfBT3 = SevenZFile.Types.mfBT3;
  mfBT4 = SevenZFile.Types.mfBT4;
  mfHC4 = SevenZFile.Types.mfHC4;
  laFast   = SevenZFile.Types.laFast;
  laNormal = SevenZFile.Types.laNormal;

type
  TSevenZFile = class(TComponent)
  protected
    FCtx: Pointer;        // opaque SzCtx* do wrapper C
    FFileName: string;
    FActive: Boolean;
    // ---- Eventos (cobertura full lifecycle 7z) ----
    FOnFileChanged: TNotifyEvent;
    FOnProgress: TZipProgressEvent;
    // Lifecycle
    FOnBeforeOpen: TArchiveLifecycleQueryEvent;
    FOnAfterOpen: TArchiveLifecycleEvent;
    FOnBeforeClose: TArchiveLifecycleQueryEvent;
    FOnAfterClose: TArchiveLifecycleEvent;
    // Entries (read scan)
    FOnEntryFound: TArchiveEntryFoundEvent;
    // Extract
    FOnBeforeExtract: TArchiveBeforeExtractEvent;
    FOnAfterExtract: TArchiveAfterExtractEvent;
    FOnExtractProgress: TArchiveEntryProgressEvent;
    // Add (write)
    FOnBeforeAdd: TArchiveBeforeAddEvent;
    FOnAfterAdd: TArchiveAfterAddEvent;
    FOnAddProgress: TArchiveEntryProgressEvent;
    // Solid block / folder (7z-specifico)
    FOnSolidBlockStart: TArchiveSolidBlockEvent;
    FOnSolidBlockEnd: TArchiveSolidBlockEvent;
    FOnFolderProgress: TArchiveFolderProgressEvent;
    FOnCompressionMethod: TArchiveCompressionMethodEvent;
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
    // ---- Compressao basica ----
    FCompressionMethod: TSevenZMethod;
    FCompressionLevel: Integer;        // 0..9 (passado para Lzma2Enc.c)
    FMultiThreaded: Boolean;           // LZMA2 multi-thread (default True)
    FThreadCount: Integer;             // 0 = auto; >0 = num threads
    FDictionarySize: Int64;            // LZMA dict em bytes (default 64MB)
    // ---- Parametros LZMA/LZMA2 avancados (CLI -m{...}) ----
    FAlgorithm: TLzmaAlgorithm;        // -ma (laNormal default)
    FFastBytes: Integer;               // -mfb (5..273, default 32 — fb)
    FMatchFinder: TLzmaMatchFinder;    // -mmf (mfBT4 default)
    FMatchCycles: Integer;             // -mmc (1..N, default 32)
    FLiteralContextBits: Integer;      // -mlc (0..8, default 3)
    FLiteralPosBits: Integer;          // -mlp (0..4, default 0)
    FPosBits: Integer;                 // -mpb (0..4, default 2)
    FNumHashBytes: Integer;            // -mhb (2..4 — for BT match finders)
    FBlockSize: Int64;                 // LZMA2 parallel block size (0 = auto)
    FWriteEndMark: Boolean;            // emit LZMA end-of-stream marker
    // ---- Codec chain extras (filters + crypto) ----
    FPreFilter: TSevenZFilter;         // filtro aplicado antes do compressor
    FDeltaDistance: Integer;           // distancia para Delta filter (1..256, default 1)
    FCryptoMethod: TSevenZCrypto;      // metodo de encryption (default szcAES256)
    // ---- Encryption ----
    FPassword: string;                 // AES-256 — reservado para v3.13
    FEncryptHeaders: Boolean;          // criptografa nomes alem do conteudo
    // ---- Archive flags (CLI -m{he,hc,qs,tm,tc,ta,tr,sfx,myx}) ----
    FSolidArchive: Boolean;            // -ms (solid mode)
    FSolidBlockSize: Int64;            // -ms=Nf or Nb: solid block byte limit
    FHeaderCompression: Boolean;       // -mhc (compress headers, default True)
    FSortByType: Boolean;              // -mqs (sort files by extension)
    FStoreLastModified: Boolean;       // -mtm
    FStoreCreationTime: Boolean;       // -mtc
    FStoreLastAccess: Boolean;         // -mta
    FStoreNTSecurity: Boolean;         // -mtr (NTFS ACL)
    FAnalysisLevel: Integer;           // -myx (0..9 file analysis depth)
    FSelfExtracting: Boolean;          // -sfx (cria .exe SFX)
    FSfxModule: string;                // path para SFX stub (.exe template)
    // ---- Split / multi-volume ----
    FVolumeSize: Int64;                // 0 = single-file; >0 = split em chunks
    // ---- Read-only header info (preenchidos por Open) ----
    FArchiveSize: Int64;
    FArchiveComment: string;
    FIsMultiVolume: Boolean;
    FFormatVersionMajor: Byte;         // 7z format version (0 currently)
    FFormatVersionMinor: Byte;         // (3 currently)
    FHasHeaderEncryption: Boolean;     // detected from archive
    FIsSolidDetected: Boolean;         // archive uses solid blocks
    procedure SetActive(AValue: Boolean);
    procedure SetFileName(const AValue: string);
    procedure SetCompressionLevel(AValue: Integer);
    procedure SetLiteralContextBits(AValue: Integer);
    procedure SetLiteralPosBits(AValue: Integer);
    procedure SetPosBits(AValue: Integer);
    procedure SetFastBytes(AValue: Integer);
    procedure SetAnalysisLevel(AValue: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Open;
    procedure Close;

    // Read API (Delphi Win32/Win64 only — requires SDK static link)
    function GetEntryCount: Integer;
    function FileExists(const AName: string): Boolean;
    function IsDir(AIndex: Integer): Boolean;
    function GetFileSize(AIndex: Integer): Int64;
    function GetEntryName(AIndex: Integer): string;
    function FindIndex(const AName: string): Integer;
    function GetEntryStream(const AName: string): TStream;
    function ReadAsBytes(const AName: string): TBytes;
    function ReadAsString(const AName: string): string;

    // Write API (cross-platform pure-pascal — Store / method "Copy" only).
    // Methods LZMA2 / PPMd / etc. deferidos para v3.1.2 via Lzma2Enc.c link.
    // CreateFromFiles: 1 folder por arquivo (cleaner, no SubStreamsInfo).
    //   AFileList: pares [src_path, name_in_archive] alternados.
    //   Ex.: CreateFromFiles(['c:\a.txt', 'a.txt', 'c:\b.txt', 'b.txt']);
    procedure CreateFromFiles(const AFileList: array of string);
    // CreateFromBytes: in-memory entries com bytes ja em buffer.
    //   ANames + AData devem ter mesmo Length.
    procedure CreateFromBytes(const ANames: array of string;
      const AData: array of TBytes);

    // v3.1.3 LZMA2 compressed WRITE (via static-link Lzma2Enc.c).
    // ALevel: 0..9 (default 5). Cada arquivo em sua propria folder
    // (1 packed stream LZMA2 por file — sem solid blocks).
    procedure CreateFromBytesLzma2(const ANames: array of string;
      const AData: array of TBytes; ALevel: Integer = 5);
    procedure CreateFromFilesLzma2(const AFileList: array of string;
      ALevel: Integer = 5);

    // Fluent
    function WithFileName(const APath: string): TSevenZFile;
    function ThatOpens: TSevenZFile;
  published
    property Active: Boolean read FActive write SetActive;
    property FileName: string read FFileName write SetFileName;
    property EntryCount: Integer read GetEntryCount;

    // ============================================================
    //   Compressao basica (mapeia 7-zip CLI -mx / -mm / -md / -mmt)
    // ============================================================
    // Algoritmo de compressao por entry. Default szmLzma2.
    property CompressionMethod: TSevenZMethod read FCompressionMethod write FCompressionMethod default szmLzma2;
    // 0=store, 1=fast, 5=normal, 9=ultra. Default 5.
    property CompressionLevel: Integer read FCompressionLevel write SetCompressionLevel default 5;
    // Multi-thread encoding (-mmt em CLI). Default True.
    property MultiThreaded: Boolean read FMultiThreaded write FMultiThreaded default True;
    // Numero explicito de threads (0 = auto baseado em ThreadCount logical).
    property ThreadCount: Integer read FThreadCount write FThreadCount default 0;
    // Dicionario LZMA em bytes (-md). Default 64MB. Max LZMA2 = 2GB.
    property DictionarySize: Int64 read FDictionarySize write FDictionarySize default 67108864;

    // ============================================================
    //   Parametros LZMA/LZMA2 avancados (CLI -m{a,fb,mf,mc,lc,lp,pb,hb})
    // ============================================================
    // Algoritmo: laFast (0) ou laNormal (1, default — melhor ratio).
    property Algorithm: TLzmaAlgorithm read FAlgorithm write FAlgorithm default laNormal;
    // Fast bytes (-mfb): 5..273. Default 32. Maior = melhor ratio + mais lento.
    property FastBytes: Integer read FFastBytes write SetFastBytes default 32;
    // Match finder algorithm (-mmf). Default mfBT4 (best ratio).
    property MatchFinder: TLzmaMatchFinder read FMatchFinder write FMatchFinder default mfBT4;
    // Match cycles (-mmc): 1..N. Default 32.
    property MatchCycles: Integer read FMatchCycles write FMatchCycles default 32;
    // Literal context bits (-mlc): 0..8. Default 3.
    property LiteralContextBits: Integer read FLiteralContextBits write SetLiteralContextBits default 3;
    // Literal pos bits (-mlp): 0..4. Default 0.
    property LiteralPosBits: Integer read FLiteralPosBits write SetLiteralPosBits default 0;
    // Pos bits (-mpb): 0..4. Default 2.
    property PosBits: Integer read FPosBits write SetPosBits default 2;
    // Hash bytes para BT match finders (-mhb): 2, 3 ou 4. Default 4.
    property NumHashBytes: Integer read FNumHashBytes write FNumHashBytes default 4;
    // LZMA2 parallel block size em bytes (0 = auto).
    property BlockSize: Int64 read FBlockSize write FBlockSize default 0;
    // Emit LZMA end-of-stream marker (default True).
    property WriteEndMark: Boolean read FWriteEndMark write FWriteEndMark default True;

    // ============================================================
    //   Filters / preprocessors (codec chain $03 $03 *)
    // ============================================================
    // Filter aplicado antes do compressor. Melhora ratio em binarios
    // de arquitetura especifica (BCJ x86, ARM, etc.) ou dados estruturados (Delta).
    // szfNone = sem filtro (default).
    property PreFilter: TSevenZFilter read FPreFilter write FPreFilter default szfNone;
    // Distancia (em bytes) para Delta filter — bom para audio 16-bit (=2),
    // 24-bit (=3), images RGB (=3), pixels RGBA (=4). 1..256, default 1.
    property DeltaDistance: Integer read FDeltaDistance write FDeltaDistance default 1;

    // ============================================================
    //   Encryption (reservado v3.13 — declarado para API surface)
    // ============================================================
    // AES-256 password. Vazio = sem criptografia.
    property Password: string read FPassword write FPassword;
    // Encryption method: szcAES256 (default 7z), szcZipCrypto (weak legacy).
    property CryptoMethod: TSevenZCrypto read FCryptoMethod write FCryptoMethod default szcAES256;
    // -mhe: criptografa structure (file names, sizes, times) alem do conteudo.
    property EncryptHeaders: Boolean read FEncryptHeaders write FEncryptHeaders default False;

    // ============================================================
    //   Archive flags (CLI -m{s,hc,qs,tm,tc,ta,tr,myx} + -sfx)
    // ============================================================
    // -ms: True = 1 packed stream cobrindo varios files (melhor compressao,
    // pior random access). False = 1 folder por file. Default False.
    property SolidArchive: Boolean read FSolidArchive write FSolidArchive default False;
    // -ms=Nb/Nk/Nm/Ng: solid block byte limit. 0 = ilimitado.
    property SolidBlockSize: Int64 read FSolidBlockSize write FSolidBlockSize default 0;
    // -mhc: comprime tabelas de header alem do conteudo. Default True.
    property HeaderCompression: Boolean read FHeaderCompression write FHeaderCompression default True;
    // -mqs: agrupa files por extensao (melhora compressao em solid mode).
    property SortByType: Boolean read FSortByType write FSortByType default False;
    // -mtm: armazena MTime. Default True.
    property StoreLastModified: Boolean read FStoreLastModified write FStoreLastModified default True;
    // -mtc: armazena CTime. Default False.
    property StoreCreationTime: Boolean read FStoreCreationTime write FStoreCreationTime default False;
    // -mta: armazena ATime. Default False.
    property StoreLastAccess: Boolean read FStoreLastAccess write FStoreLastAccess default False;
    // -mtr: armazena NTFS ACL/security descriptors.
    property StoreNTSecurity: Boolean read FStoreNTSecurity write FStoreNTSecurity default False;
    // -myx: analysis level (0..9). Maior = mais lento mas melhor pipeline.
    property AnalysisLevel: Integer read FAnalysisLevel write SetAnalysisLevel default 0;
    // -sfx: cria self-extracting .exe (usa FSfxModule como stub).
    property SelfExtracting: Boolean read FSelfExtracting write FSelfExtracting default False;
    // Path para o SFX stub .exe (default = 7zSD.sfx do 7-zip).
    property SfxModule: string read FSfxModule write FSfxModule;

    // ============================================================
    //   Split / multi-volume (reservado v3.14)
    // ============================================================
    // Tamanho em bytes de cada volume. 0 = single-file (default).
    // >0 = grava .7z.001 / .7z.002 / etc. cada um com ate VolumeSize bytes.
    property VolumeSize: Int64 read FVolumeSize write FVolumeSize default 0;

    // ============================================================
    //   Read-only archive info (preenchido por Open)
    // ============================================================
    property ArchiveSize: Int64 read FArchiveSize;
    property ArchiveComment: string read FArchiveComment;
    // True se o .7z aberto eh parte de um volume set (.7z.001 etc.).
    property IsMultiVolume: Boolean read FIsMultiVolume;
    // 7z format version (byte major.minor). Atualmente 0.3.
    property FormatVersionMajor: Byte read FFormatVersionMajor;
    property FormatVersionMinor: Byte read FFormatVersionMinor;
    // True se o archive aberto eh encrypted-header.
    property HasHeaderEncryption: Boolean read FHasHeaderEncryption;
    // True se o archive aberto usa solid blocks.
    property IsSolidDetected: Boolean read FIsSolidDetected;

    // ============================================================
    //   Events — full lifecycle (write/read/extract/multi-volume)
    // ============================================================
    // Basicos
    property OnFileChanged: TNotifyEvent read FOnFileChanged write FOnFileChanged;
    property OnProgress: TZipProgressEvent read FOnProgress write FOnProgress;

    // Lifecycle (Cancel := True nos Before* aborta a operacao)
    property OnBeforeOpen: TArchiveLifecycleQueryEvent read FOnBeforeOpen write FOnBeforeOpen;
    property OnAfterOpen: TArchiveLifecycleEvent read FOnAfterOpen write FOnAfterOpen;
    property OnBeforeClose: TArchiveLifecycleQueryEvent read FOnBeforeClose write FOnBeforeClose;
    property OnAfterClose: TArchiveLifecycleEvent read FOnAfterClose write FOnAfterClose;

    // Scan / index (disparado para cada entry achado em Open)
    property OnEntryFound: TArchiveEntryFoundEvent read FOnEntryFound write FOnEntryFound;

    // Extract per entry
    property OnBeforeExtract: TArchiveBeforeExtractEvent read FOnBeforeExtract write FOnBeforeExtract;
    property OnAfterExtract: TArchiveAfterExtractEvent read FOnAfterExtract write FOnAfterExtract;
    // Per-entry progress (diferente de OnProgress que e overall)
    property OnExtractProgress: TArchiveEntryProgressEvent read FOnExtractProgress write FOnExtractProgress;

    // Add (write) per entry
    property OnBeforeAdd: TArchiveBeforeAddEvent read FOnBeforeAdd write FOnBeforeAdd;
    property OnAfterAdd: TArchiveAfterAddEvent read FOnAfterAdd write FOnAfterAdd;
    property OnAddProgress: TArchiveEntryProgressEvent read FOnAddProgress write FOnAddProgress;

    // 7z-specifico: solid block / folder events
    // Folder = packed stream LZMA2 cobrindo 1+ entries. Solid block = idem.
    property OnSolidBlockStart: TArchiveSolidBlockEvent read FOnSolidBlockStart write FOnSolidBlockStart;
    property OnSolidBlockEnd: TArchiveSolidBlockEvent read FOnSolidBlockEnd write FOnSolidBlockEnd;
    property OnFolderProgress: TArchiveFolderProgressEvent read FOnFolderProgress write FOnFolderProgress;
    // Disparado quando o codec chain de um entry e selecionado/detectado.
    property OnCompressionMethod: TArchiveCompressionMethodEvent read FOnCompressionMethod write FOnCompressionMethod;

    // Security
    property OnAskPassword: TArchivePasswordRequestEvent read FOnAskPassword write FOnAskPassword;
    property OnReplaceQuery: TArchiveReplaceQueryEvent read FOnReplaceQuery write FOnReplaceQuery;
    property OnVerify: TArchiveVerifyEvent read FOnVerify write FOnVerify;

    // Multi-volume
    property OnRequestVolume: TArchiveRequestVolumeEvent read FOnRequestVolume write FOnRequestVolume;
    property OnVolumeChanged: TArchiveVolumeChangedEvent read FOnVolumeChanged write FOnVolumeChanged;

    // Diagnostics
    property OnError: TArchiveErrorEvent read FOnError write FOnError;
    property OnWarning: TArchiveWarningEvent read FOnWarning write FOnWarning;
    property OnLog: TArchiveLogEvent read FOnLog write FOnLog;
  end;

implementation

// v3.1.1: Win64 HABILITADO — mesmo conjunto de .o ELF produzidos por bcc64
// que ZipFile.Compression.LZMA já linka com sucesso em Win64. Subset
// estendido inclui Aes/AesOpt/Sha256/Sha256Opt/7zCrc/7zCrcOpt (decoders
// auxiliares 7z) — testar individualmente caso linker rejeite algum.
{$IF DEFINED(WIN32) AND NOT DEFINED(FPC)}
  {$DEFINE SEVENZ_AVAILABLE}
{$IFEND}
{$IF DEFINED(WIN64) AND NOT DEFINED(FPC)}
  {$DEFINE SEVENZ_AVAILABLE}
{$IFEND}

{$IFDEF SEVENZ_AVAILABLE}

// ---- CRT stubs locais ao unit ----
// Pascal {$L} resolve externals OBJ por unit (não cross-unit). Por isso
// duplicamos os mesmos stubs cdecl que ZipFile.Compression.LZMA.pas já
// define localmente (malloc/free/realloc/memset/memcpy/memmove). Symbol
// names cdecl Pascal não conflictam entre units.

{$IFDEF WIN32}
  {$DEFINE SZ_C_UNDERSCORE}
{$ENDIF}

{$IFDEF SZ_C_UNDERSCORE}
function _malloc(size: NativeUInt): Pointer; cdecl;
{$ELSE}
function malloc(size: NativeUInt): Pointer; cdecl;
{$ENDIF}
begin
  if size = 0 then Result := nil else GetMem(Result, size);
end;

{$IFDEF SZ_C_UNDERSCORE}
procedure _free(ptr: Pointer); cdecl;
{$ELSE}
procedure free(ptr: Pointer); cdecl;
{$ENDIF}
begin
  if ptr <> nil then FreeMem(ptr);
end;

{$IFDEF SZ_C_UNDERSCORE}
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

{$IFDEF SZ_C_UNDERSCORE}
function _memset(dest: Pointer; c: Integer; count: NativeUInt): Pointer; cdecl;
{$ELSE}
function memset(dest: Pointer; c: Integer; count: NativeUInt): Pointer; cdecl;
{$ENDIF}
begin
  FillChar(dest^, count, Byte(c));
  Result := dest;
end;

{$IFDEF SZ_C_UNDERSCORE}
function _memcpy(dest, src: Pointer; count: NativeUInt): Pointer; cdecl;
{$ELSE}
function memcpy(dest, src: Pointer; count: NativeUInt): Pointer; cdecl;
{$ENDIF}
begin
  Move(src^, dest^, count);
  Result := dest;
end;

{$IFDEF SZ_C_UNDERSCORE}
function _memmove(dest, src: Pointer; count: NativeUInt): Pointer; cdecl;
{$ELSE}
function memmove(dest, src: Pointer; count: NativeUInt): Pointer; cdecl;
{$ENDIF}
begin
  Move(src^, dest^, count);
  Result := dest;
end;

// === Externs (cdecl) — wrapper C ===
// Win32 OMF: bcc32c prefixa com `_`. Win64 ELF: bcc64 NAO prefixa.

{$IFDEF SZ_C_UNDERSCORE}
function SzCtx_Open(const path: PAnsiChar): Pointer; cdecl; external name '_SzCtx_Open';
procedure SzCtx_Close(ctx: Pointer); cdecl; external name '_SzCtx_Close';
function SzCtx_FileCount(ctx: Pointer): Cardinal; cdecl; external name '_SzCtx_FileCount';
function SzCtx_IsDir(ctx: Pointer; idx: Cardinal): Integer; cdecl; external name '_SzCtx_IsDir';
function SzCtx_FileSize(ctx: Pointer; idx: Cardinal): UInt64; cdecl; external name '_SzCtx_FileSize';
function SzCtx_GetNameUtf8(ctx: Pointer; idx: Cardinal; outBuf: PAnsiChar; bufSize: Cardinal): Cardinal; cdecl; external name '_SzCtx_GetNameUtf8';
function SzCtx_Extract(ctx: Pointer; idx: Cardinal; outBuf: PByte; bufSize: UInt64): Integer; cdecl; external name '_SzCtx_Extract';
{$ELSE}
function SzCtx_Open(const path: PAnsiChar): Pointer; cdecl; external name 'SzCtx_Open';
procedure SzCtx_Close(ctx: Pointer); cdecl; external name 'SzCtx_Close';
function SzCtx_FileCount(ctx: Pointer): Cardinal; cdecl; external name 'SzCtx_FileCount';
function SzCtx_IsDir(ctx: Pointer; idx: Cardinal): Integer; cdecl; external name 'SzCtx_IsDir';
function SzCtx_FileSize(ctx: Pointer; idx: Cardinal): UInt64; cdecl; external name 'SzCtx_FileSize';
function SzCtx_GetNameUtf8(ctx: Pointer; idx: Cardinal; outBuf: PAnsiChar; bufSize: Cardinal): Cardinal; cdecl; external name 'SzCtx_GetNameUtf8';
function SzCtx_Extract(ctx: Pointer; idx: Cardinal; outBuf: PByte; bufSize: UInt64): Integer; cdecl; external name 'SzCtx_Extract';
{$ENDIF}

// v3.1.3: LZMA2 encoder externs (Lzma2Enc.c). Mesma logica de underscore
// que SzCtx_*.
type
  // CLzmaEncProps layout — DEVE bater com LzmaEnc.h CLzmaEncProps record.
  // Spec: level int; dictSize UInt32; lc/lp/pb int; algo int; fb int;
  //   btMode int; numHashBytes int; numHashOutBits unsigned; mc UInt32;
  //   writeEndMark unsigned; affinity UInt64; numThreads int (MT).
  // Layout C exato (LzmaEnc.h, SDK 24.07):
  //   int level; UInt32 dictSize; int lc,lp,pb,algo,fb,btMode,numHashBytes;
  //   unsigned numHashOutBits; UInt32 mc; unsigned writeEndMark; int numThreads;
  //   Int32 affinityGroup; UInt64 reduceSize; UInt64 affinity;
  //   UInt64 affinityInGroup;
  // Total: 80 bytes (campos 4-byte aligned, UInt64s 8-byte aligned).
  TCLzmaEncProps = record
    level: Integer;
    dictSize: Cardinal;
    lc, lp, pb, algo, fb, btMode, numHashBytes: Integer;
    numHashOutBits: Cardinal;
    mc: Cardinal;
    writeEndMark: Cardinal;
    numThreads: Integer;
    affinityGroup: Integer;
    reduceSize: UInt64;
    affinity: UInt64;
    affinityInGroup: UInt64;
  end;

  TCLzma2EncProps = record
    lzmaProps: TCLzmaEncProps;
    blockSize: UInt64;
    numBlockThreads_Reduced: Integer;
    numBlockThreads_Max: Integer;
    numTotalThreads: Integer;
    numThreadGroups: Cardinal;
  end;

{$IFDEF SZ_C_UNDERSCORE}
procedure Lzma2EncProps_Init(p: Pointer); cdecl; external name '_Lzma2EncProps_Init';
function Lzma2Enc_Create(alloc, allocBig: Pointer): Pointer; cdecl; external name '_Lzma2Enc_Create';
procedure Lzma2Enc_Destroy(p: Pointer); cdecl; external name '_Lzma2Enc_Destroy';
function Lzma2Enc_SetProps(p: Pointer; props: Pointer): Integer; cdecl; external name '_Lzma2Enc_SetProps';
procedure Lzma2Enc_SetDataSize(p: Pointer; dataSize: UInt64); cdecl; external name '_Lzma2Enc_SetDataSize';
function Lzma2Enc_WriteProperties(p: Pointer): Byte; cdecl; external name '_Lzma2Enc_WriteProperties';
function Lzma2Enc_Encode2(p, outStream: Pointer; outBuf: PByte;
  outBufSize: PNativeUInt; inStream: Pointer; inData: PByte; inDataSize: NativeUInt;
  progress: Pointer): Integer; cdecl; external name '_Lzma2Enc_Encode2';
{$ELSE}
procedure Lzma2EncProps_Init(p: Pointer); cdecl; external name 'Lzma2EncProps_Init';
function Lzma2Enc_Create(alloc, allocBig: Pointer): Pointer; cdecl; external name 'Lzma2Enc_Create';
procedure Lzma2Enc_Destroy(p: Pointer); cdecl; external name 'Lzma2Enc_Destroy';
function Lzma2Enc_SetProps(p: Pointer; props: Pointer): Integer; cdecl; external name 'Lzma2Enc_SetProps';
procedure Lzma2Enc_SetDataSize(p: Pointer; dataSize: UInt64); cdecl; external name 'Lzma2Enc_SetDataSize';
function Lzma2Enc_WriteProperties(p: Pointer): Byte; cdecl; external name 'Lzma2Enc_WriteProperties';
function Lzma2Enc_Encode2(p, outStream: Pointer; outBuf: PByte;
  outBufSize: PNativeUInt; inStream: Pointer; inData: PByte; inDataSize: NativeUInt;
  progress: Pointer): Integer; cdecl; external name 'Lzma2Enc_Encode2';
{$ENDIF}

// ISzAlloc estrutura — necessario passar para Lzma2Enc_Create.
// Reusamos a logica de PascalSzAlloc do ZipFile.Compression.LZMA mas
// duplicada aqui (Pascal {$L} eh per-unit).
type
  PSzAllocLocal = ^TSzAllocLocal;
  TSzAllocLocal = record
    fnAlloc: function(p: Pointer; size: NativeUInt): Pointer; cdecl;
    fnFree:  procedure(p, address: Pointer); cdecl;
  end;

function SzAllocLocal_Alloc(p: Pointer; size: NativeUInt): Pointer; cdecl;
begin
  if size = 0 then Result := nil else GetMem(Result, size);
end;

procedure SzAllocLocal_Free(p, address: Pointer); cdecl;
begin
  if address <> nil then FreeMem(address);
end;

var
  GLzmaAllocator: TSzAllocLocal = (fnAlloc: SzAllocLocal_Alloc; fnFree: SzAllocLocal_Free);

// Forçar linkagem dos .obj/.o do 7z subset (já residentes ao lado dos LZMA).
// Ordem importa — providers primeiro, consumers depois; LzmaDec/LzFind/Alloc
// linkados aqui (mesma estratégia self-contained de ZipFile.Compression.LZMA).
{$IFDEF WIN32}
  // Ordem CONSUMERS primeiro, PROVIDERS depois (Delphi OBJ linker resolve
  // refs forward — mesmo padrão de ZipFile.Compression.LZMA.pas).
  {$L Library\delphi-win32\SevenZWrapper.obj}
  {$L Library\delphi-win32\7zFile.obj}
  {$L Library\delphi-win32\SevenZCombined.obj}  // 7zArcIn.c + 7zDec.c (mutual deps)
  {$L Library\delphi-win32\Lzma2Dec.obj}
  // v3.1.3: LZMA encoder + LZMA2 encoder (para 7z WRITE compressed)
  {$L Library\delphi-win32\Lzma2Enc.obj}
  {$L Library\delphi-win32\LzmaEnc.obj}
  {$L Library\delphi-win32\7zCrc.obj}
  {$L Library\delphi-win32\7zStream.obj}
  {$L Library\delphi-win32\7zBuf2.obj}
  {$L Library\delphi-win32\7zBuf.obj}
  {$L Library\delphi-win32\7zAlloc.obj}
  {$L Library\delphi-win32\LzmaDec.obj}
  {$L Library\delphi-win32\LzFind.obj}
  {$L Library\delphi-win32\7zCrcOpt.obj}
  {$L Library\delphi-win32\Bcj2.obj}
  {$L Library\delphi-win32\BraIA64.obj}
  {$L Library\delphi-win32\Bra86.obj}
  {$L Library\delphi-win32\Bra.obj}
  {$L Library\delphi-win32\Delta.obj}
  {$L Library\delphi-win32\AesOpt.obj}
  {$L Library\delphi-win32\Aes.obj}
  {$L Library\delphi-win32\Sha256Opt.obj}
  {$L Library\delphi-win32\Sha256.obj}
  {$L Library\delphi-win32\Alloc.obj}
{$ENDIF}
{$IFDEF WIN64}
  // v3.1.1 — Win64 ELF linker bcc64/Delphi e single-pass; refs mutuas entre
  // OBJs separados nao resolvem. Aes.c <-> AesOpt.c e Sha256.c <-> Sha256Opt.c
  // tem refs mutuas, entao consolidadas em AesCombined.c + Sha256Combined.c.
  // Win32 OMF (ilink32 do BCC102) e multi-pass; mantém OBJs separados la.
  {$L Library\delphi-win64\SevenZWrapper.o}
  {$L Library\delphi-win64\7zFile.o}
  {$L Library\delphi-win64\SevenZCombined.o}
  {$L Library\delphi-win64\Lzma2Dec.o}
  // v3.1.3: LZMA encoder + LZMA2 encoder
  {$L Library\delphi-win64\Lzma2Enc.o}
  {$L Library\delphi-win64\LzmaEnc.o}
  {$L Library\delphi-win64\7zCrc.o}
  {$L Library\delphi-win64\7zStream.o}
  {$L Library\delphi-win64\7zBuf2.o}
  {$L Library\delphi-win64\7zBuf.o}
  {$L Library\delphi-win64\7zAlloc.o}
  {$L Library\delphi-win64\LzmaDec.o}
  {$L Library\delphi-win64\LzFind.o}
  {$L Library\delphi-win64\7zCrcOpt.o}
  {$L Library\delphi-win64\Bcj2.o}
  {$L Library\delphi-win64\BraIA64.o}
  {$L Library\delphi-win64\Bra86.o}
  {$L Library\delphi-win64\Bra.o}
  {$L Library\delphi-win64\Delta.o}
  {$L Library\delphi-win64\AesCombined.o}    // Aes + AesOpt (mutual deps)
  {$L Library\delphi-win64\Sha256Combined.o} // Sha256 + Sha256Opt (mutual deps)
  {$L Library\delphi-win64\Alloc.o}
  {$L Library\delphi-win64\CpuArch.o}
{$ENDIF}

// --- Win32 APIs que Alloc.c + 7zFile.c + CpuArch.c usam ---
function VirtualAlloc(lpAddress: Pointer; dwSize: NativeUInt; flAllocationType, flProtect: Cardinal): Pointer; stdcall;
  external 'kernel32.dll' name 'VirtualAlloc';
function VirtualFree(lpAddress: Pointer; dwSize: NativeUInt; dwFreeType: Cardinal): LongBool; stdcall;
  external 'kernel32.dll' name 'VirtualFree';
function GetModuleHandleW(lpModuleName: PWideChar): NativeUInt; stdcall;
  external 'kernel32.dll' name 'GetModuleHandleW';
function GetProcAddress(hModule: NativeUInt; lpProcName: PAnsiChar): Pointer; stdcall;
  external 'kernel32.dll' name 'GetProcAddress';
// v3.1.1: Alloc.c usa GetLargePageMinimum; CpuArch.c usa IsProcessorFeaturePresent.
// No Win32 OMF, ilink32 do BCC102 ja resolve essas via msvcrt fallback. Em
// Win64 ELF, precisa importar explicitamente do kernel32.dll.
function GetLargePageMinimum: NativeUInt; stdcall;
  external 'kernel32.dll' name 'GetLargePageMinimum';
function IsProcessorFeaturePresent(ProcessorFeature: Cardinal): LongBool; stdcall;
  external 'kernel32.dll' name 'IsProcessorFeaturePresent';
// 7zFile.c usa CreateFileA/W, CloseHandle, GetFileSize, GetLastError,
// ReadFile, SetFilePointer, WriteFile. bcc32c clang32 emite nomes
// stdcall sem prefixo `_` nem sufixo `@N`.
function CreateFileA(lpFileName: PAnsiChar; dwDesiredAccess, dwShareMode: Cardinal;
  lpSecurityAttributes: Pointer; dwCreationDisposition, dwFlagsAndAttributes: Cardinal;
  hTemplateFile: NativeUInt): NativeUInt; stdcall; external 'kernel32.dll' name 'CreateFileA';
function CreateFileW(lpFileName: PWideChar; dwDesiredAccess, dwShareMode: Cardinal;
  lpSecurityAttributes: Pointer; dwCreationDisposition, dwFlagsAndAttributes: Cardinal;
  hTemplateFile: NativeUInt): NativeUInt; stdcall; external 'kernel32.dll' name 'CreateFileW';
function CloseHandle(hObject: NativeUInt): LongBool; stdcall;
  external 'kernel32.dll' name 'CloseHandle';
function GetFileSize(hFile: NativeUInt; lpFileSizeHigh: Pointer): Cardinal; stdcall;
  external 'kernel32.dll' name 'GetFileSize';
function GetLastError: Cardinal; stdcall;
  external 'kernel32.dll' name 'GetLastError';
function ReadFile(hFile: NativeUInt; lpBuffer: Pointer; nNumberOfBytesToRead: Cardinal;
  lpNumberOfBytesRead, lpOverlapped: Pointer): LongBool; stdcall;
  external 'kernel32.dll' name 'ReadFile';
function SetFilePointer(hFile: NativeUInt; lDistanceToMove: Integer;
  lpDistanceToMoveHigh: Pointer; dwMoveMethod: Cardinal): Cardinal; stdcall;
  external 'kernel32.dll' name 'SetFilePointer';
function WriteFile(hFile: NativeUInt; lpBuffer: Pointer; nNumberOfBytesToWrite: Cardinal;
  lpNumberOfBytesWritten, lpOverlapped: Pointer): LongBool; stdcall;
  external 'kernel32.dll' name 'WriteFile';

{$ENDIF}

// =============================================================================
//   TSevenZFile
// =============================================================================

constructor TSevenZFile.Create(AOwner: TComponent);
begin
  inherited;
  FCtx := nil;
  FActive := False;
  // Compression defaults
  FCompressionMethod := szmLzma2;
  FCompressionLevel := 5;
  FMultiThreaded := True;
  FThreadCount := 0;
  FDictionarySize := 67108864;     // 64 MB
  // LZMA advanced defaults
  FAlgorithm := laNormal;
  FFastBytes := 32;
  FMatchFinder := mfBT4;
  FMatchCycles := 32;
  FLiteralContextBits := 3;
  FLiteralPosBits := 0;
  FPosBits := 2;
  FNumHashBytes := 4;
  FBlockSize := 0;
  FWriteEndMark := True;
  // Archive flags
  FSolidArchive := False;
  FSolidBlockSize := 0;
  FHeaderCompression := True;
  FSortByType := False;
  FStoreLastModified := True;
  FStoreCreationTime := False;
  FStoreLastAccess := False;
  FStoreNTSecurity := False;
  FAnalysisLevel := 0;
  FSelfExtracting := False;
  // Filters / Crypto chain
  FPreFilter := szfNone;
  FDeltaDistance := 1;
  FCryptoMethod := szcAES256;
  // Encryption
  FEncryptHeaders := False;
  // Split
  FVolumeSize := 0;
end;

procedure TSevenZFile.SetCompressionLevel(AValue: Integer);
begin
  if (AValue < 0) or (AValue > 9) then
    raise ESevenZError.CreateFmt('CompressionLevel must be 0..9 (got %d)', [AValue]);
  FCompressionLevel := AValue;
end;

procedure TSevenZFile.SetLiteralContextBits(AValue: Integer);
begin
  if (AValue < 0) or (AValue > 8) then
    raise ESevenZError.CreateFmt('LiteralContextBits must be 0..8 (got %d)', [AValue]);
  FLiteralContextBits := AValue;
end;

procedure TSevenZFile.SetLiteralPosBits(AValue: Integer);
begin
  if (AValue < 0) or (AValue > 4) then
    raise ESevenZError.CreateFmt('LiteralPosBits must be 0..4 (got %d)', [AValue]);
  FLiteralPosBits := AValue;
end;

procedure TSevenZFile.SetPosBits(AValue: Integer);
begin
  if (AValue < 0) or (AValue > 4) then
    raise ESevenZError.CreateFmt('PosBits must be 0..4 (got %d)', [AValue]);
  FPosBits := AValue;
end;

procedure TSevenZFile.SetFastBytes(AValue: Integer);
begin
  if (AValue < 5) or (AValue > 273) then
    raise ESevenZError.CreateFmt('FastBytes must be 5..273 (got %d)', [AValue]);
  FFastBytes := AValue;
end;

procedure TSevenZFile.SetAnalysisLevel(AValue: Integer);
begin
  if (AValue < 0) or (AValue > 9) then
    raise ESevenZError.CreateFmt('AnalysisLevel must be 0..9 (got %d)', [AValue]);
  FAnalysisLevel := AValue;
end;

destructor TSevenZFile.Destroy;
begin
  Close;
  inherited;
end;

procedure TSevenZFile.SetActive(AValue: Boolean);
begin
  if AValue = FActive then Exit;
  if AValue then Open else Close;
end;

procedure TSevenZFile.SetFileName(const AValue: string);
begin
  if AValue = FFileName then Exit;
  Close;
  FFileName := AValue;
  if Assigned(FOnFileChanged) then FOnFileChanged(Self);
end;

procedure TSevenZFile.Open;
{$IFDEF SEVENZ_AVAILABLE}
var
  Raw: AnsiString;
{$ENDIF}
begin
  if FActive then Exit;
  if FFileName = '' then
    raise ESevenZError.Create('TSevenZFile.Open: FileName not set');
  {$IFDEF SEVENZ_AVAILABLE}
  Raw := AnsiString(FFileName);
  FCtx := SzCtx_Open(PAnsiChar(Raw));
  if FCtx = nil then
    raise ESevenZError.CreateFmt('TSevenZFile.Open: failed to parse 7z archive "%s"',
      [FFileName]);
  FActive := True;
  {$ELSE}
  raise ESevenZNotSupportedOnPlatform.Create(
    'TSevenZFile requires Delphi Win32/Win64 with the BCC102-compiled 7z .obj set.');
  {$ENDIF}
end;

procedure TSevenZFile.Close;
begin
  if not FActive then Exit;
  {$IFDEF SEVENZ_AVAILABLE}
  if FCtx <> nil then
  begin
    SzCtx_Close(FCtx);
    FCtx := nil;
  end;
  {$ENDIF}
  FActive := False;
end;

function TSevenZFile.GetEntryCount: Integer;
begin
  {$IFDEF SEVENZ_AVAILABLE}
  if FActive and (FCtx <> nil) then
    Result := Integer(SzCtx_FileCount(FCtx))
  else
    Result := 0;
  {$ELSE}
  Result := 0;
  {$ENDIF}
end;

function TSevenZFile.IsDir(AIndex: Integer): Boolean;
begin
  {$IFDEF SEVENZ_AVAILABLE}
  Result := FActive and (FCtx <> nil) and
            (SzCtx_IsDir(FCtx, Cardinal(AIndex)) <> 0);
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function TSevenZFile.GetFileSize(AIndex: Integer): Int64;
begin
  {$IFDEF SEVENZ_AVAILABLE}
  if FActive and (FCtx <> nil) then
    Result := Int64(SzCtx_FileSize(FCtx, Cardinal(AIndex)))
  else
    Result := 0;
  {$ELSE}
  Result := 0;
  {$ENDIF}
end;

function TSevenZFile.GetEntryName(AIndex: Integer): string;
{$IFDEF SEVENZ_AVAILABLE}
var
  Size: Cardinal;
  Buf: AnsiString;
{$ENDIF}
begin
  Result := '';
  {$IFDEF SEVENZ_AVAILABLE}
  if not FActive or (FCtx = nil) then Exit;
  Size := SzCtx_GetNameUtf8(FCtx, Cardinal(AIndex), nil, 0);
  if Size = 0 then Exit;
  SetLength(Buf, Size);
  if SzCtx_GetNameUtf8(FCtx, Cardinal(AIndex), PAnsiChar(Buf), Size) > 0 then
  begin
    // Strip trailing NUL
    while (Length(Buf) > 0) and (Buf[Length(Buf)] = #0) do
      SetLength(Buf, Length(Buf) - 1);
    Result := string(Buf);
  end;
  {$ENDIF}
end;

function TSevenZFile.FindIndex(const AName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to EntryCount - 1 do
    if GetEntryName(I) = AName then
      Exit(I);
end;

function TSevenZFile.FileExists(const AName: string): Boolean;
begin
  Result := FindIndex(AName) >= 0;
end;

function TSevenZFile.GetEntryStream(const AName: string): TStream;
{$IFDEF SEVENZ_AVAILABLE}
var
  Idx: Integer;
  Sz: Int64;
  Buf: TBytes;
  Res: Integer;
  Mem: TMemoryStream;
{$ENDIF}
begin
  Result := nil;
  {$IFDEF SEVENZ_AVAILABLE}
  Idx := FindIndex(AName);
  if Idx < 0 then
    raise ESevenZError.CreateFmt('TSevenZFile.GetEntryStream: entry "%s" not found', [AName]);
  if SzCtx_IsDir(FCtx, Cardinal(Idx)) <> 0 then
    raise ESevenZError.CreateFmt('TSevenZFile.GetEntryStream: "%s" is a directory', [AName]);
  Sz := GetFileSize(Idx);
  SetLength(Buf, Sz);
  if Sz > 0 then
  begin
    Res := SzCtx_Extract(FCtx, Cardinal(Idx), PByte(Buf), UInt64(Sz));
    if Res <> 0 then
      raise ESevenZError.CreateFmt('TSevenZFile.GetEntryStream: SDK error %d extracting "%s"',
        [Res, AName]);
  end;
  Mem := TMemoryStream.Create;
  try
    if Sz > 0 then
      Mem.WriteBuffer(Buf[0], Sz);
    Mem.Position := 0;
    Result := Mem;
  except
    Mem.Free;
    raise;
  end;
  {$ENDIF}
end;

function TSevenZFile.ReadAsBytes(const AName: string): TBytes;
var
  Stm: TStream;
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

function TSevenZFile.ReadAsString(const AName: string): string;
var
  B: TBytes;
  S: AnsiString;
begin
  B := ReadAsBytes(AName);
  SetLength(S, Length(B));
  if Length(B) > 0 then
    Move(B[0], S[1], Length(B));
  Result := string(S);
end;

// =============================================================================
//   WRITE API (cross-platform pure-pascal, Store/Copy only)
// =============================================================================
//
// 7z container layout (per sdk/lzma2601/DOC/7zFormat.txt 18.06):
//   Offset 0..31: SignatureHeader (32 bytes fixos)
//     0..5  = magic "7z\xBC\xAF\x27\x1C"
//     6..7  = version 0.4
//     8..11 = StartHeaderCRC (CRC32 of bytes 12..31)
//     12..19 = NextHeaderOffset (UInt64 LE, relative ao final do signature)
//     20..27 = NextHeaderSize (UInt64 LE)
//     28..31 = NextHeaderCRC (CRC32 of header bytes)
//   Offset 32..32+packed_total-1: PackedStreams (raw bytes para Copy)
//   Offset 32+packed_total..: Header (inline, NID 0x01)
//
// Estrategia "1 folder per file": evita SubStreamsInfo (mais complexo). Cada
// arquivo vira sua propria pack stream + folder com 1 coder Copy.

const
  SZ_NID_END                = $00;
  SZ_NID_HEADER             = $01;
  SZ_NID_ARCHIVE_PROPERTIES = $02;
  SZ_NID_ADDITIONAL_STREAMS = $03;
  SZ_NID_MAIN_STREAMS_INFO  = $04;
  SZ_NID_FILES_INFO         = $05;
  SZ_NID_PACK_INFO          = $06;
  SZ_NID_UNPACK_INFO        = $07;
  SZ_NID_SUBSTREAMS_INFO    = $08;
  SZ_NID_SIZE               = $09;
  SZ_NID_CRC                = $0A;
  SZ_NID_FOLDER             = $0B;
  SZ_NID_CODERS_UNPACK_SIZE = $0C;
  SZ_NID_NUM_UNPACK_STREAM  = $0D;
  SZ_NID_EMPTY_STREAM       = $0E;
  SZ_NID_EMPTY_FILE         = $0F;
  SZ_NID_NAME               = $11;

// Write 7z REAL_UINT64 (variable-length encoding per spec).
// First byte format encodes how many extra bytes follow:
//   0xxxxxxx                 (1 byte)
//   10xxxxxx + y[1]          (2 bytes, value = (xxxxxx << 8) | y)
//   110xxxxx + y[2]          (3 bytes)
//   ...
//   11111110 + y[7]          (8 bytes, value = y)
//   11111111 + y[8]          (9 bytes, value = y)
procedure SzWriteRealUInt64(AStream: TStream; AValue: UInt64);
var
  I: Integer;
  Mask, FirstByte: Byte;
  Bytes: array[0..8] of Byte;
  NumBytes: Integer;
begin
  // Find how many bytes needed
  NumBytes := 0;
  Mask := $80;
  FirstByte := 0;
  for I := 0 to 7 do
  begin
    if AValue < (UInt64(1) shl (7 * (I + 1))) then
    begin
      NumBytes := I;
      FirstByte := Byte(AValue shr (8 * I));
      Mask := not ((Byte(1) shl (7 - I)) - 1);  // construct mask for top bits
      // Simplified: for NumBytes=I, mask is (0xFF << (8-I)) & 0xFF but invert top bit
      // Use the spec table approach instead:
      Break;
    end;
  end;

  // Spec table approach (simpler):
  // value < 2^7 (0..127)     -> 1 byte:  0xxxxxxx (mask 0x00)
  // value < 2^14             -> 2 bytes: first 10xxxxxx (mask 0x80)
  // value < 2^21             -> 3 bytes: first 110xxxxx (mask 0xC0)
  // value < 2^28             -> 4 bytes: first 1110xxxx (mask 0xE0)
  // value < 2^35             -> 5 bytes: first 11110xxx (mask 0xF0)
  // value < 2^42             -> 6 bytes: first 111110xx (mask 0xF8)
  // value < 2^49             -> 7 bytes: first 1111110x (mask 0xFC)
  // value < 2^56             -> 8 bytes: first 11111110 (mask 0xFE)
  // else                     -> 9 bytes: first 11111111 (mask 0xFF)
  if AValue < (UInt64(1) shl 7) then
  begin
    Bytes[0] := Byte(AValue);
    AStream.WriteBuffer(Bytes[0], 1);
  end
  else if AValue < (UInt64(1) shl 14) then
  begin
    Bytes[0] := $80 or Byte(AValue shr 8);
    Bytes[1] := Byte(AValue and $FF);
    AStream.WriteBuffer(Bytes[0], 2);
  end
  else if AValue < (UInt64(1) shl 21) then
  begin
    Bytes[0] := $C0 or Byte(AValue shr 16);
    Bytes[1] := Byte((AValue shr 0) and $FF);
    Bytes[2] := Byte((AValue shr 8) and $FF);
    AStream.WriteBuffer(Bytes[0], 3);
  end
  else if AValue < (UInt64(1) shl 28) then
  begin
    Bytes[0] := $E0 or Byte(AValue shr 24);
    Bytes[1] := Byte((AValue shr 0) and $FF);
    Bytes[2] := Byte((AValue shr 8) and $FF);
    Bytes[3] := Byte((AValue shr 16) and $FF);
    AStream.WriteBuffer(Bytes[0], 4);
  end
  else if AValue < (UInt64(1) shl 35) then
  begin
    Bytes[0] := $F0 or Byte(AValue shr 32);
    Bytes[1] := Byte((AValue shr 0) and $FF);
    Bytes[2] := Byte((AValue shr 8) and $FF);
    Bytes[3] := Byte((AValue shr 16) and $FF);
    Bytes[4] := Byte((AValue shr 24) and $FF);
    AStream.WriteBuffer(Bytes[0], 5);
  end
  else
  begin
    // Fallback: use 9-byte form for anything larger
    Bytes[0] := $FF;
    Bytes[1] := Byte((AValue shr 0)  and $FF);
    Bytes[2] := Byte((AValue shr 8)  and $FF);
    Bytes[3] := Byte((AValue shr 16) and $FF);
    Bytes[4] := Byte((AValue shr 24) and $FF);
    Bytes[5] := Byte((AValue shr 32) and $FF);
    Bytes[6] := Byte((AValue shr 40) and $FF);
    Bytes[7] := Byte((AValue shr 48) and $FF);
    Bytes[8] := Byte((AValue shr 56) and $FF);
    AStream.WriteBuffer(Bytes[0], 9);
  end;
end;

// CRC-32 IEEE 802.3 (zlib polynomial)
function SzCrc32(const ABytes: TBytes; AStart, ALen: NativeInt): Cardinal;
const
  POLY = $EDB88320;
var
  Tbl: array[0..255] of Cardinal;
  I, J: Integer;
  C: Cardinal;
begin
  for I := 0 to 255 do
  begin
    C := I;
    for J := 0 to 7 do
      if (C and 1) <> 0 then C := (C shr 1) xor POLY else C := C shr 1;
    Tbl[I] := C;
  end;
  Result := $FFFFFFFF;
  for I := AStart to AStart + ALen - 1 do
    Result := Tbl[(Result xor ABytes[I]) and $FF] xor (Result shr 8);
  Result := Result xor $FFFFFFFF;
end;

// Build the inline Header bytes for a 7z archive with N files in N folders.
//   ANames[i]        = filename
//   APackSizes[i]    = size of compressed data on disk (folder i pack stream)
//   AUnpackSizes[i]  = original uncompressed size of file i
//   ACoderId         = 1+ bytes codec id (e.g. [0x00] for Copy, [0x21] for LZMA2)
//   ACoderProps      = optional codec properties (per-folder; same for all
//                      here; empty for Copy, 1 byte dict-encoded for LZMA2)
function BuildSevenZHeader(const ANames: array of string;
  const APackSizes: array of UInt64;
  const AUnpackSizes: array of UInt64;
  const ACoderId: TBytes;
  const ACoderProps: TBytes): TBytes;
var
  Hdr: TMemoryStream;
  I, J: Integer;
  N: Integer;
  NameProp: TMemoryStream;
  WName: WideString;
  WLen: Integer;
  HdrBytes: TBytes;
  Zero: Byte;
begin
  N := Length(ANames);
  Hdr := TMemoryStream.Create;
  try
    // kHeader
    Zero := SZ_NID_HEADER; Hdr.WriteBuffer(Zero, 1);
    // kMainStreamsInfo
    Zero := SZ_NID_MAIN_STREAMS_INFO; Hdr.WriteBuffer(Zero, 1);

    // ---- kPackInfo ----
    Zero := SZ_NID_PACK_INFO; Hdr.WriteBuffer(Zero, 1);
    SzWriteRealUInt64(Hdr, 0);                  // PackPos = 0
    SzWriteRealUInt64(Hdr, UInt64(N));          // NumPackStreams
    Zero := SZ_NID_SIZE; Hdr.WriteBuffer(Zero, 1);
    for I := 0 to N - 1 do
      SzWriteRealUInt64(Hdr, APackSizes[I]);
    Zero := SZ_NID_END; Hdr.WriteBuffer(Zero, 1);  // end PackInfo

    // ---- kUnPackInfo ----
    Zero := SZ_NID_UNPACK_INFO; Hdr.WriteBuffer(Zero, 1);
    Zero := SZ_NID_FOLDER; Hdr.WriteBuffer(Zero, 1);
    SzWriteRealUInt64(Hdr, UInt64(N));          // NumFolders
    Zero := 0; Hdr.WriteBuffer(Zero, 1);        // External = 0 (folders inline)
    // For each folder: 1 coder, no bind pairs, no packed indices.
    // Coder flags byte: low 4 bits = CodecIdSize, bit 5 = hasAttrs.
    for I := 0 to N - 1 do
    begin
      SzWriteRealUInt64(Hdr, 1);                // NumCoders = 1
      Zero := Byte(Length(ACoderId) and $0F);
      if Length(ACoderProps) > 0 then
        Zero := Zero or $20;                    // has attributes
      Hdr.WriteBuffer(Zero, 1);
      // CodecId bytes
      if Length(ACoderId) > 0 then
        Hdr.WriteBuffer(ACoderId[0], Length(ACoderId));
      // Properties (size as RealUInt64 + props bytes)
      if Length(ACoderProps) > 0 then
      begin
        SzWriteRealUInt64(Hdr, UInt64(Length(ACoderProps)));
        Hdr.WriteBuffer(ACoderProps[0], Length(ACoderProps));
      end;
      // No NumBindPairs (not complex), no PackedIndices
    end;
    Zero := SZ_NID_CODERS_UNPACK_SIZE; Hdr.WriteBuffer(Zero, 1);
    for I := 0 to N - 1 do
      SzWriteRealUInt64(Hdr, AUnpackSizes[I]);
    Zero := SZ_NID_END; Hdr.WriteBuffer(Zero, 1);  // end UnPackInfo

    // ---- No SubStreamsInfo (defaults to 1 unpack stream per folder) ----

    Zero := SZ_NID_END; Hdr.WriteBuffer(Zero, 1);  // end MainStreamsInfo

    // ---- kFilesInfo ----
    Zero := SZ_NID_FILES_INFO; Hdr.WriteBuffer(Zero, 1);
    SzWriteRealUInt64(Hdr, UInt64(N));          // NumFiles

    // Property kName (0x11): UTF-16 LE names, null-terminated each
    NameProp := TMemoryStream.Create;
    try
      Zero := 0; NameProp.WriteBuffer(Zero, 1); // External = 0 (inline)
      for I := 0 to N - 1 do
      begin
        WName := WideString(ANames[I]);
        WLen := Length(WName);
        for J := 1 to WLen do
        begin
          NameProp.WriteBuffer(WName[J], 2);  // 2 bytes UTF-16 LE per char
        end;
        // Null terminator (2 bytes)
        Zero := 0; NameProp.WriteBuffer(Zero, 1); NameProp.WriteBuffer(Zero, 1);
      end;
      // Write Name property: kName + size + content
      Zero := SZ_NID_NAME; Hdr.WriteBuffer(Zero, 1);
      SzWriteRealUInt64(Hdr, UInt64(NameProp.Size));
      NameProp.Position := 0;
      Hdr.CopyFrom(NameProp, NameProp.Size);
    finally NameProp.Free; end;

    Zero := SZ_NID_END; Hdr.WriteBuffer(Zero, 1);  // end FilesInfo

    Zero := SZ_NID_END; Hdr.WriteBuffer(Zero, 1);  // end Header

    SetLength(HdrBytes, Hdr.Size);
    Hdr.Position := 0;
    Hdr.ReadBuffer(HdrBytes[0], Hdr.Size);
    Result := HdrBytes;
  finally Hdr.Free; end;
end;

procedure TSevenZFile.CreateFromBytes(const ANames: array of string;
  const AData: array of TBytes);
var
  N, I: Integer;
  PackSizes: array of UInt64;
  HdrBytes: TBytes;
  HdrCrc, StartHdrCrc: Cardinal;
  StartHdr: TBytes;
  TotalPackBytes: UInt64;
  Outf: TFileStream;
  Magic: array[0..7] of Byte;
begin
  if FFileName = '' then
    raise ESevenZError.Create('CreateFromBytes: FileName not set');
  if Length(ANames) <> Length(AData) then
    raise ESevenZError.Create('CreateFromBytes: ANames and AData length mismatch');
  N := Length(ANames);
  if N = 0 then
    raise ESevenZError.Create('CreateFromBytes: empty');

  SetLength(PackSizes, N);
  TotalPackBytes := 0;
  for I := 0 to N - 1 do
  begin
    PackSizes[I] := UInt64(Length(AData[I]));
    Inc(TotalPackBytes, PackSizes[I]);
  end;

  // Copy coder: ID = [0x00], no properties.
  HdrBytes := BuildSevenZHeader(ANames, PackSizes, PackSizes,
    TBytes.Create($00), nil);
  HdrCrc := SzCrc32(HdrBytes, 0, Length(HdrBytes));

  // Build start header (bytes 12..31 of file):
  //   12..19 = NextHeaderOffset = TotalPackBytes (header sits right after pack data)
  //   20..27 = NextHeaderSize
  //   28..31 = NextHeaderCRC
  SetLength(StartHdr, 20);
  PUInt64(@StartHdr[0])^ := TotalPackBytes;
  PUInt64(@StartHdr[8])^ := UInt64(Length(HdrBytes));
  PCardinal(@StartHdr[16])^ := HdrCrc;
  StartHdrCrc := SzCrc32(StartHdr, 0, 20);

  // Write file
  Outf := TFileStream.Create(FFileName, fmCreate);
  try
    // Signature magic + version + StartHeaderCRC + StartHeader
    Magic[0] := $37; Magic[1] := $7A;
    Magic[2] := $BC; Magic[3] := $AF;
    Magic[4] := $27; Magic[5] := $1C;
    Magic[6] := $00; Magic[7] := $04;          // version 0.4
    Outf.WriteBuffer(Magic[0], 8);
    Outf.WriteBuffer(StartHdrCrc, 4);
    Outf.WriteBuffer(StartHdr[0], 20);
    // PackedStreams: raw data for each entry
    for I := 0 to N - 1 do
      if Length(AData[I]) > 0 then
        Outf.WriteBuffer(AData[I][0], Length(AData[I]));
    // Header (inline, kHeader)
    Outf.WriteBuffer(HdrBytes[0], Length(HdrBytes));
  finally Outf.Free; end;
end;

// v3.1.3 LZMA2 compressed WRITE.
// Comprime cada arquivo individualmente (1 folder = 1 packed LZMA2 stream per file).
// Codec ID 7z LZMA2 = 0x21 (single byte).
// Properties = 1 byte (dict size encoded per LZMA2 spec).
procedure TSevenZFile.CreateFromBytesLzma2(const ANames: array of string;
  const AData: array of TBytes; ALevel: Integer);
{$IFDEF SEVENZ_AVAILABLE}
var
  N, I: Integer;
  PackSizes, UnpackSizes: array of UInt64;
  CompData: array of TBytes;
  HdrBytes, CoderId, CoderProps: TBytes;
  HdrCrc, StartHdrCrc: Cardinal;
  StartHdr: TBytes;
  TotalPackBytes: UInt64;
  Outf: TFileStream;
  Magic: array[0..7] of Byte;
  Enc: Pointer;
  Props2: TCLzma2EncProps;
  OutBufSize: NativeUInt;
  Res: Integer;
  PropByte: Byte;
  CommonProp: Byte;
begin
  if FFileName = '' then
    raise ESevenZError.Create('CreateFromBytesLzma2: FileName not set');
  if Length(ANames) <> Length(AData) then
    raise ESevenZError.Create('CreateFromBytesLzma2: ANames and AData length mismatch');
  N := Length(ANames);
  if N = 0 then
    raise ESevenZError.Create('CreateFromBytesLzma2: empty');

  SetLength(PackSizes, N);
  SetLength(UnpackSizes, N);
  SetLength(CompData, N);
  TotalPackBytes := 0;
  CommonProp := 0;

  // Comprimir cada arquivo individualmente
  for I := 0 to N - 1 do
  begin
    UnpackSizes[I] := UInt64(Length(AData[I]));
    Enc := Lzma2Enc_Create(@GLzmaAllocator, @GLzmaAllocator);
    if Enc = nil then
      raise ESevenZError.Create('Lzma2Enc_Create failed');
    try
      Lzma2EncProps_Init(@Props2);
      Props2.lzmaProps.level := ALevel;
      Res := Lzma2Enc_SetProps(Enc, @Props2);
      if Res <> 0 then
        raise ESevenZError.CreateFmt('Lzma2Enc_SetProps erro %d', [Res]);
      Lzma2Enc_SetDataSize(Enc, UnpackSizes[I]);

      PropByte := Lzma2Enc_WriteProperties(Enc);
      if I = 0 then CommonProp := PropByte
      else if PropByte <> CommonProp then
        raise ESevenZError.Create('LZMA2 properties divergem entre folders (level deve ser igual)');

      // Allocate output buffer 110% size + 256 padding
      OutBufSize := NativeUInt(Length(AData[I]) + (Length(AData[I]) div 10) + 256);
      SetLength(CompData[I], OutBufSize);
      if Length(AData[I]) = 0 then
      begin
        // Empty file: LZMA2 still emits 1-byte end-of-stream marker
        CompData[I][0] := $00;
        OutBufSize := 1;
      end
      else
      begin
        Res := Lzma2Enc_Encode2(Enc, nil, @CompData[I][0], @OutBufSize,
          nil, @AData[I][0], NativeUInt(Length(AData[I])), nil);
        if Res <> 0 then
          raise ESevenZError.CreateFmt('Lzma2Enc_Encode2 erro %d em "%s"',
            [Res, ANames[I]]);
      end;
      SetLength(CompData[I], OutBufSize);
      PackSizes[I] := UInt64(OutBufSize);
      Inc(TotalPackBytes, PackSizes[I]);
    finally Lzma2Enc_Destroy(Enc); end;
  end;

  // Codec ID LZMA2 = single byte 0x21
  CoderId := TBytes.Create($21);
  // Properties (1 byte dict-encoded). Per LZMA2 spec, last 5 bits encode dict size.
  CoderProps := TBytes.Create(CommonProp);

  HdrBytes := BuildSevenZHeader(ANames, PackSizes, UnpackSizes,
    CoderId, CoderProps);
  HdrCrc := SzCrc32(HdrBytes, 0, Length(HdrBytes));

  SetLength(StartHdr, 20);
  PUInt64(@StartHdr[0])^ := TotalPackBytes;
  PUInt64(@StartHdr[8])^ := UInt64(Length(HdrBytes));
  PCardinal(@StartHdr[16])^ := HdrCrc;
  StartHdrCrc := SzCrc32(StartHdr, 0, 20);

  Outf := TFileStream.Create(FFileName, fmCreate);
  try
    Magic[0] := $37; Magic[1] := $7A;
    Magic[2] := $BC; Magic[3] := $AF;
    Magic[4] := $27; Magic[5] := $1C;
    Magic[6] := $00; Magic[7] := $04;
    Outf.WriteBuffer(Magic[0], 8);
    Outf.WriteBuffer(StartHdrCrc, 4);
    Outf.WriteBuffer(StartHdr[0], 20);
    for I := 0 to N - 1 do
      if Length(CompData[I]) > 0 then
        Outf.WriteBuffer(CompData[I][0], Length(CompData[I]));
    Outf.WriteBuffer(HdrBytes[0], Length(HdrBytes));
  finally Outf.Free; end;
end;
{$ELSE}
begin
  raise ESevenZError.Create('LZMA2 encode not available on this platform (requires SEVENZ_AVAILABLE)');
end;
{$ENDIF}

procedure TSevenZFile.CreateFromFilesLzma2(const AFileList: array of string;
  ALevel: Integer);
{$IFDEF SEVENZ_AVAILABLE}
var
  N, I: Integer;
  Names: array of string;
  Data: array of TBytes;
  Fs: TFileStream;
begin
  if (Length(AFileList) mod 2) <> 0 then
    raise ESevenZError.Create('CreateFromFilesLzma2: pares [src, name] requeridos');
  N := Length(AFileList) div 2;
  SetLength(Names, N);
  SetLength(Data, N);
  for I := 0 to N - 1 do
  begin
    Names[I] := AFileList[I * 2 + 1];
    Fs := TFileStream.Create(AFileList[I * 2], fmOpenRead or fmShareDenyWrite);
    try
      SetLength(Data[I], Fs.Size);
      if Fs.Size > 0 then Fs.ReadBuffer(Data[I][0], Fs.Size);
    finally Fs.Free; end;
  end;
  CreateFromBytesLzma2(Names, Data, ALevel);
end;
{$ELSE}
begin
  raise ESevenZError.Create('LZMA2 encode not available on this platform (requires SEVENZ_AVAILABLE)');
end;
{$ENDIF}

procedure TSevenZFile.CreateFromFiles(const AFileList: array of string);
var
  N, I: Integer;
  Names: array of string;
  Data: array of TBytes;
  Fs: TFileStream;
begin
  if (Length(AFileList) mod 2) <> 0 then
    raise ESevenZError.Create('CreateFromFiles: AFileList must have pairs [src, name]');
  N := Length(AFileList) div 2;
  SetLength(Names, N);
  SetLength(Data, N);
  for I := 0 to N - 1 do
  begin
    Names[I] := AFileList[I * 2 + 1];
    Fs := TFileStream.Create(AFileList[I * 2], fmOpenRead or fmShareDenyWrite);
    try
      SetLength(Data[I], Fs.Size);
      if Fs.Size > 0 then Fs.ReadBuffer(Data[I][0], Fs.Size);
    finally Fs.Free; end;
  end;
  CreateFromBytes(Names, Data);
end;

// ---- Fluent ----

function TSevenZFile.WithFileName(const APath: string): TSevenZFile;
begin
  SetFileName(APath);
  Result := Self;
end;

function TSevenZFile.ThatOpens: TSevenZFile;
begin
  Open;
  Result := Self;
end;

{ ============================================================================
  Fluent builder + factory — relocated from former SevenZ.Fluent.pas (dissolved
  per backend-pascal-unit-naming_V1.6.0 §2; interface in companion .Interfaces.pas).
  Class declarations are in the interface section (see top of unit).
  ============================================================================ }

constructor TSevenZFileBuilder.CreateNew(const APath: string);
begin
  inherited Create;
  FArchivePath := APath;
  FOpenForRead := False;
  FMethod := szbStore;
  FLevel := 5;
  if SysUtils.FileExists(APath) then SysUtils.DeleteFile(APath);
end;

constructor TSevenZFileBuilder.CreateOpen(const APath: string);
begin
  inherited Create;
  FArchivePath := APath;
  FOpenForRead := True;
end;

function TSevenZFileBuilder.WithStore: ISevenZFileBuilder;
begin
  FMethod := szbStore;
  Result := Self;
end;

function TSevenZFileBuilder.WithLZMA2(ALevel: Integer): ISevenZFileBuilder;
begin
  FMethod := szbLzma2;
  FLevel := ALevel;
  Result := Self;
end;

function TSevenZFileBuilder.AppendFile(const ADiskFileName, AEntryName: string): ISevenZFileBuilder;
var Item: TSevenZBuilderItem;
begin
  Item.Kind := sbkFile;
  Item.DiskFileName := ADiskFileName;
  Item.EntryName := AEntryName;
  SetLength(FItems, Length(FItems) + 1);
  FItems[High(FItems)] := Item;
  Result := Self;
end;

function TSevenZFileBuilder.AppendBytes(const AData: TBytes;
  const AEntryName: string): ISevenZFileBuilder;
var Item: TSevenZBuilderItem;
begin
  Item.Kind := sbkBytes;
  Item.EntryName := AEntryName;
  Item.Data := AData;
  SetLength(FItems, Length(FItems) + 1);
  FItems[High(FItems)] := Item;
  Result := Self;
end;

procedure TSevenZFileBuilder.Execute;
var
  Sz: TSevenZFile;
  Names: array of string;
  Datas: array of TBytes;
  I: Integer;
  Fs: TFileStream;
begin
  if Length(FItems) = 0 then
    raise ESevenZError.Create('TSevenZFileBuilder.Execute: nenhum item appended', ERR_ZIPFILE_SEVENZ);

  SetLength(Names, Length(FItems));
  SetLength(Datas, Length(FItems));
  for I := 0 to High(FItems) do
  begin
    Names[I] := FItems[I].EntryName;
    if FItems[I].Kind = sbkFile then
    begin
      Fs := TFileStream.Create(FItems[I].DiskFileName, fmOpenRead or fmShareDenyWrite);
      try
        SetLength(Datas[I], Fs.Size);
        if Fs.Size > 0 then Fs.ReadBuffer(Datas[I][0], Fs.Size);
      finally Fs.Free; end;
    end
    else
      Datas[I] := FItems[I].Data;
  end;

  Sz := TSevenZFile.Create(nil);
  try
    Sz.FileName := FArchivePath;
    case FMethod of
      szbStore: Sz.CreateFromBytes(Names, Datas);
      szbLzma2: Sz.CreateFromBytesLzma2(Names, Datas, FLevel);
    end;
  finally Sz.Free; end;
end;

function TSevenZFileBuilder.ExtractStream(const AEntryName: string): TStream;
var Sz: TSevenZFile;
begin
  Sz := TSevenZFile.Create(nil);
  try
    Sz.FileName := FArchivePath;
    Sz.Active := True;
    Result := Sz.GetEntryStream(AEntryName);
  finally Sz.Free; end;
end;

function TSevenZFileBuilder.ReadAsBytes(const AEntryName: string): TBytes;
var Sz: TSevenZFile;
begin
  Sz := TSevenZFile.Create(nil);
  try
    Sz.FileName := FArchivePath;
    Sz.Active := True;
    Result := Sz.ReadAsBytes(AEntryName);
  finally Sz.Free; end;
end;

function TSevenZFileBuilder.ReadAsString(const AEntryName: string): string;
var Sz: TSevenZFile;
begin
  Sz := TSevenZFile.Create(nil);
  try
    Sz.FileName := FArchivePath;
    Sz.Active := True;
    Result := Sz.ReadAsString(AEntryName);
  finally Sz.Free; end;
end;

function TSevenZFileBuilder.HasEntry(const AEntryName: string): Boolean;
var Sz: TSevenZFile;
begin
  Sz := TSevenZFile.Create(nil);
  try
    Sz.FileName := FArchivePath;
    Sz.Active := True;
    Result := Sz.FileExists(AEntryName);
  finally Sz.Free; end;
end;

function TSevenZFileBuilder.CountEntries: Integer;
var Sz: TSevenZFile;
begin
  Sz := TSevenZFile.Create(nil);
  try
    Sz.FileName := FArchivePath;
    Sz.Active := True;
    Result := Sz.EntryCount;
  finally Sz.Free; end;
end;

class function SevenZip.NewArchive(const APath: string): ISevenZFileBuilder;
begin
  Result := TSevenZFileBuilder.CreateNew(APath);
end;

class function SevenZip.OpenArchive(const APath: string): ISevenZFileBuilder;
begin
  Result := TSevenZFileBuilder.CreateOpen(APath);
end;

end.
