{*
 * ZipFile.pas
 *
 * Class that encapsulates a ZipFile.
 *
 * Copyright (c) 2006-2007 by the MODELbuilder developers team
 * Originally written by Darius Blaszijk, <dhkblaszyk@zeelandnet.nl>
 * Creation date: 23-Sep-2007
 * Website: www.modelbuilder.org
 *
 * This file is part of the MODELbuilder component library (MCL) 
 * and licensed under the LGPL, see COPYING.LGPL included in 
 * this distribution, for details about the copyright.
 *
 *}
unit ZipFile;

{$IFDEF FPC}
{$mode objfpc}{$H+}
{$ENDIF}

interface

uses
  Classes, SysUtils,
  {$IFDEF FPC}{$IFDEF LCL}
  LResources,
  {$ENDIF}{$ENDIF}
  Math,
  {$IF (NOT DEFINED(FPC)) OR DEFINED(LCL)}
  Dialogs,
  {$IFEND}
  StrUtils,
  {$IFDEF FPC}
    {$if defined(VER2_0_0) or defined(VER2_0_1) or defined(VER2_0_2)}
    gzCrc,
    {$ELSE}
    crc,
    {$ENDIF}
    zstream,    // v4.1: raw-deflate writer (paszlib TCompressionStream)
  {$ELSE}
  // Delphi: use ZLib unit's crc32 function (compatible signature with FPC's crc unit)
  ZLib,
  {$ENDIF}
  ZipFile.Compression.Base, ZipFile.Compression.None, ZipFile.Compression.ZLib, ZipFile.Compression.Consts,
  ZipFile.UTF8, ZipFile.ZIP64, Commons.ZipFile.Types, ZipFile.Events, ZipFile.Encryption.AES,
  ZipFile.Streaming, ZipFile.Compression.LZMA,
  ZipFile.Interfaces, Exceptions.ZipFile, Commons.ZipFile.Consts;

// Resourcestrings relocated to Commons.ZipFile.Consts.pas (Wave 3a). They are
// re-exported by virtue of the `uses Commons.ZipFile.Consts;` above — resourcestring
// identifiers are visible to any unit that has them in its uses chain.

type
  // TZipSearchRec relocated to Commons.ZipFile.Types.pas. Aliased for backward
  // compat with `uses ZipFile` consumers.
  TZipSearchRec = Commons.ZipFile.Types.TZipSearchRec;
  
  TLocalFileHeaderStart = packed record
    signature:         longword;      {local file header signature     4 bytes  (0x04034b50)}
    extractversion:    word;          {version needed to extract       2 bytes}
    generalpurposebit: word;          {general purpose bit flag        2 bytes}
    compressmethod:    word;          {compression method              2 bytes}
    lastmodtime:       word;          {last mod file time              2 bytes}
    lastmoddate:       word;          {last mod file date              2 bytes}
    crc32:             longword;      {crc-32                          4 bytes}
    compressedsize:    longword;      {compressed size                 4 bytes}
    uncompressedsize:  longword;      {uncompressed size               4 bytes}
    filenamelength:    word;          {file name length                2 bytes}
    extrafieldlength:  word;          {extra field length              2 bytes}
  end;
  
  TLocalFileHeaderAdditional = packed record
    filename: string;
    extrafield: string;
  end;
  
  TLocalFileHeader = packed record
    start: TLocalFileHeaderStart;
    add: TLocalFileHeaderAdditional;
  end;

  TCDFileHeaderStart = packed record
    signature:              longword; {central file header signature   4 bytes  (0x02014b50)}
    versionmadeby:          word;     {version made by                 2 bytes}
    versiontoextract:       word;     {version needed to extract       2 bytes}
    generalpurposebit:      word;     {general purpose bit flag        2 bytes}
    compressionmethod:      word;     {compression method              2 bytes}
    lastmodfiletime:        word;     {last mod file time              2 bytes}
    lastmodfiledate:        word;     {last mod file date              2 bytes}
    crc32:                  longword; {crc-32                          4 bytes}
    compressedsize:         longword; {compressed size                 4 bytes}
    uncompressedsize:       longword; {uncompressed size               4 bytes}
    filenamelength:         word;     {file name length                2 bytes}
    extrafieldlength:       word;     {extra field length              2 bytes}
    filecommentlength:      word;     {file comment length             2 bytes}
    disknumberstart:        word;     {disk number start               2 bytes}
    internalfileattributes: word;     {internal file attributes        2 bytes}
    externalfileattributed: longword; {external file attributes        4 bytes}
    reloffsetlocalheader:   longword; {relative offset of local header 4 bytes}
  end;

  TCDFileHeaderAdditional = packed record
    filename:    string;              {file name (variable size)}
    extrafield:  string;              {extra field (variable size)}
    filecomment: string;              {file comment (variable size)}
  end;
  
  TCDFileHeader = packed record
    start: TCDFileHeaderStart;
    add: TCDFileHeaderAdditional;
  end;
  
  TEndOfCentralDirectoryRecordStart = packed record
    endofcentraldirsignature:  longword; {end of central dir signature    4 bytes  (0x06054b50)}
    numberofthisdisk:          word;     {number of this disk             2 bytes}
    numberofthisdiskwithcd:    word;     {number of the disk with the}
                                         {start of the central directory  2 bytes}
    numberofcdentries:         word;     {total number of entries in the}
                                         {central directory on this disk  2 bytes}
    totalnumberofcdentries:    word;     {total number of entries in}
                                         {the central directory           2 bytes}
    sizeofthecentraldirectory: longword; {size of the central directory   4 bytes}
    cdoffset:                  longword; {offset of start of central}
                                         {directory with respect to}
                                         {the starting disk number        4 bytes}
    ZIPfilecommentlength:      word;     {.ZIP file comment length        2 bytes}
  end;
  
  TEndOfCentralDirectoryRecordAdditional = packed record
    ZIPfilecomment: string;           {.ZIP file comment       (variable size)}
  end;

  TEndOfCentralDirectoryRecord = packed record
    start: TEndOfCentralDirectoryRecordStart;
    add: TEndOfCentralDirectoryRecordAdditional;
  end;
  
  TZipFileItem = record
    lfh: TLocalFileHeader;
    filedata: Pbyte;
  end;

  // Type aliases — definitive declarations live in ZipFile.Interfaces.pas
  // (so IZipFileBuilder there can reference them without circular dependency).
  // Backward-compatible re-export for `uses ZipFile` consumers.
  TFileChangedEvent = ZipFile.Interfaces.TFileChangedEvent;
  TCompressionMethod = ZipFile.Interfaces.TCompressionMethod;
  TReCompressionMethod = ZipFile.Interfaces.TReCompressionMethod;

const
  cmNone        = ZipFile.Interfaces.cmNone;
  cmMaximal     = ZipFile.Interfaces.cmMaximal;
  rmKeepOriginal = ZipFile.Interfaces.rmKeepOriginal;
  rmNone        = ZipFile.Interfaces.rmNone;
  rmMaximal     = ZipFile.Interfaces.rmMaximal;

type
  { TZipFile }

  TZipFile = class(TComponent)
  protected
    endofcdrecord: TEndOfCentralDirectoryRecord;
    endofcdrecordstartpos: longword;
    FActive: boolean;
    FCompression: TCompressionMethod;
    FFileName: string;
    fileheaderlist: array of TCDFileHeader;
    fileindex: longword;
    FOnFileChanged: TFileChangedEvent;
    FReCompression: TReCompressionMethod;
    fs: TFileStream;
    // v2.0: features modernas (additive, sem quebrar API existente)
    FUseUtf8: Boolean;     // Quando True, filenames non-ASCII gravam bit 11 GP flag + UTF-8 encoding
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
    FOnLog: TArchiveLogEvent;  // Disparado em operacoes longas (append/extract/delete)
    FPassword: string;     // Quando <>'', entries gravadas serao cifradas (se UseAES=True).
    FUseAES: Boolean;      // Liga AES-256 WinZip-AE-2 no write path (le sempre auto-detecta).
    FUseLZMA: Boolean;     // Quando True, AppendStream comprime com LZMA method=14 (Win32 only).
    FForceZip64: Boolean;  // Forca emissao de ZIP64 extras + EOCD ainda que sizes pequenos.
    // v3.12 design-time enrichment — backing fields
    FCompressionLevel: Integer; // 0..9 — para Deflate; reservado para futuras impls
    FAESKeySize: Word;         // 128/192/256 (AE-2 sempre 256 atualmente)
    FArchiveComment: string;   // ZIP archive comment (EOCDR field) — reservado para wire
    FVolumeSize: Int64;        // 0 = single .zip; >0 = split em .z01/.z02/.zip
    FStoreMSDosAttributes: Boolean;  // armazena DOS file attributes
    FStoreUnixAttributes: Boolean;   // armazena Unix permissions via extra field
    FStoreNTSecurity: Boolean;       // armazena NTFS security descriptor (extra)
    FArchiveSize: Int64;       // physical .zip size — read-only via GetFileSize alias
    // ZIP64 shadow tracking (Int64 reais quando os campos 32-bit on-disk
    // carregam sentinel 0xFFFFFFFF/0xFFFF). Sempre populado, mesmo em
    // archives pequenos, para simplificar o codigo.
    FZip64TotalEntries: Int64;
    FZip64CDSize: Int64;
    FZip64CDOffset: Int64;
    // Paralelo a fileheaderlist[]: tamanhos e offset reais 64-bit por entry.
    // Indexado igual a fileheaderlist[i]. Populado em AddCDFileHeader e
    // GetCDFileHeaders.
    FEntryUSize64: array of Int64;
    FEntryCSize64: array of Int64;
    FEntryOffset64: array of Int64;

    // Helper interno para emitir OnProgress; retorna True se caller pediu cancel.
    function DoProgress(ABytesDone, ABytesTotal: Int64): Boolean;
    // Copia ASrc para ADst em chunks de 64K disparando OnProgress; aborta se cancel.
    procedure DoProgressChunkedCopy(ASrc, ADst: TStream; ATotal: Int64);
    // Read-side ZIP64: detecta sentinel 0xFFFFFFFF/0xFFFF na EOCD standard
    // ou ZIP64 EOCD Locator imediatamente antes; parseia ZIP64 EOCD Record
    // e popula shadow Int64 fields. Nao raise — silencia para archives
    // ZIP64 sao agora suportados em leitura.
    procedure DetectAndParseZip64;
    // Per-entry ZIP64: parseia extra field 0x0001 quando sentinel detectado;
    // popula FEntryUSize64/CSize64/Offset64[AIndex] com Int64 reais.
    procedure ParseEntryZip64Shadow(AIndex: Integer);
    // Constroi extra field 0x0001 com USize+CSize (LFH) ou USize+CSize+Offset
    // (CDH). Tamanho: 4 bytes header + 16 ou 24 bytes payload.
    function BuildZip64ExtraField(AUSize, ACSize, AOffset: Int64; AIncludeOffset: Boolean): RawByteString;
    // Decide se a entry no indice atual demanda extra field 0x0001 baseado em
    // FForceZip64 + sizes/offset overflow 32-bit.
    function EntryNeedsZip64(AUSize, ACSize, AOffset: Int64): Boolean;
    // Emite ZIP64 EOCD Record (sig 0x06064B50) + ZIP64 EOCD Locator
    // (sig 0x07064B50) na posicao corrente do fs. Usado em AppendStream
    // imediatamente antes da EOCDR standard quando triggers se acionam.
    procedure EmitZip64EocdAndLocator;
    // Preenche um buffer de salt com 16 bytes random; usa RTLGenRandom em Win/x64,
    // fallback para Random pseudo-random em FPC.
    procedure RandomizeSalt(var ASalt: array of Byte);
    // Constroi os 11 bytes do extra field 0x9901 (WinZip AES-2) carregando o
    // real compression method.
    function BuildAESExtraField(ARealMethod: Word): RawByteString;
    // Localiza e parseia o extra field 0x9901; devolve True e RealMethod se
    // achou um header AES-2 valido.
    function ParseAESExtraField(const ARaw: RawByteString; out ARealMethod: Word): Boolean;

    function EndOfCDRecordPosition: longword;
    function FileNameIndex(AFileName: string): longint;
    function GetSearchResult(var SearchResult : TZipSearchRec): integer;
    function GetStreamCrc32(Stream: TStream): longword;
    function MakeLocalFileHeader(FileName: string; FSize: Int64; crc32: cardinal; FileDateTime: TDateTime): TLocalFileHeader;
    function ReadLocalFileHeader(AOffSet: Int64): TLocalFileHeader;
    function ShowCDFileHeaderReport(index: longword): TStrings;
    function ShowEndOfCDRecordReport: TStrings;
    function ShowLocalFileHeaderReport(index: longword): TStrings;
    procedure AddCDFileHeader(FSize: int64; AFileName: string; LocalOffset: longword; LFHSize: Int64; crc32: cardinal; FileDateTime: TDateTime);
    procedure DateTimeToDosDateTime(DateTime: TDateTime; var dosdate, dostime: word);
    procedure DosDateTimeToDateTime(dosdate, dostime: word; var DateTime: TDateTime);
    procedure GetCDFileHeaders;
    procedure GetEndOfCDRecord;
    function GetFileSize: Int64;
    procedure Reset;
    procedure SetActive(Value: boolean);
    procedure SetFileName(Value: string);
  public
    fileheadercount: longword;
    
    constructor Create(AOwner: TComponent);
    destructor Destroy; override;

    procedure Activate;

    //file functions
    function GetFileStream(AFileName: string; var BufLength: longword): TMemoryStream;
    // v2.0: streaming-friendly entry reader. Returns a TStream that reads
    // direct from the archive file handle without buffering the entry in
    // RAM. Caller MUST .Free the returned stream BEFORE freeing TZipFile
    // (the underlying file handle is shared). Supports STORED entries
    // (method 0) plain or AES-256-encrypted. For DEFLATE entries, falls
    // back to GetFileStream wrapped in a TMemoryStream-backed reader.
    function GetEntryStream(AFileName: string): TStream;
    function FileCount: longword;
    function FileExists(AFileName: string): boolean;
    function FindFirst(var SearchResult : TZipSearchRec): integer;
    function FindNext(var SearchResult : TZipSearchRec): integer;
    procedure AppendFileFromDisk(AFileName, ZIPFileName: string);
    procedure AppendStream(Stream: TStream; ZIPFileName: string; FileDateTime: TDateTime);
    procedure DeleteFile(AFileName: string);
    procedure UpdateFile(Stream: TStream; ZIPFileName: string);

    // v2.4: Fluent inline configurators — cada um seta a property correspondente
    // e devolve Self, permitindo chaining no estilo:
    //   Zip.WithUtf8.WithAES('senha').WithProgress(handler);
    // Sem builder externo, sem mudar lifecycle, 100% backward compat com
    // properties tradicionais (que continuam funcionando exatamente igual).
    function WithUtf8(AEnable: Boolean = True): TZipFile;
    function WithAES(const APassword: string): TZipFile;
    function WithLZMA(AEnable: Boolean = True): TZipFile;
    function WithForceZip64(AEnable: Boolean = True): TZipFile;
    function WithProgress(AEvent: TZipProgressEvent): TZipFile;
    function WithPassword(const APassword: string): TZipFile;
    function WithCompression(AMethod: TCompressionMethod): TZipFile;
    function WithReCompression(AMethod: TReCompressionMethod): TZipFile;
    function WithFileName(const APath: string): TZipFile;
    function OnArchiveChanged(AEvent: TFileChangedEvent): TZipFile;
    // Convenience activator (em vez de Active := True)
    function Open: TZipFile;

    //reporting
    function Report: TStrings;
  published
    property Active: boolean read FActive write SetActive;
    property Compression: TCompressionMethod read FCompression write FCompression;
    property ReCompression: TReCompressionMethod read FReCompression write FReCompression;
    property FileName: string read FFileName write SetFileName;
    property FileSize: Int64 read GetFileSize;
    property OnFileChanged: TFileChangedEvent read FOnFileChanged write FOnFileChanged;
    // v2.0 additive properties (non-breaking).
    // UseUtf8: quando True, filenames com chars non-ASCII gravam bit 11 GP flag
    // + filename UTF-8 encoded. Quando False (default), comportamento legado
    // (encoding ANSI/CP437). Leitura sempre auto-detecta via bit 11.
    property UseUtf8: Boolean read FUseUtf8 write FUseUtf8 default False;
    // OnProgress: disparado em operacoes longas (append/extract/delete) com
    // BytesDone/BytesTotal. Caller pode setar Cancel := True para abortar
    // (causa EZipFileCancelled).
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
    // Password: senha para AES-256. So tem efeito quando UseAES=True.
    property Password: string read FPassword write FPassword;
    // UseAES: quando True (e Password<>''), entries novas sao cifradas com AES-256
    // WinZip-AE-2 (extra field 0x9901, method=99, GP bit 0). Leitura sempre
    // auto-detecta encryption pelo bit 0 + presenca do extra field.
    property UseAES: Boolean read FUseAES write FUseAES default False;
    // UseLZMA: quando True, entries novas sao comprimidas com LZMA (PKWARE
    // method 14). Win32 only (Win64/FPC raise EZipLZMANotSupportedOnPlatform
    // via integracao com src/ZipFile.Compression.LZMA.pas). Leitura sempre
    // auto-detecta method=14.
    property UseLZMA: Boolean read FUseLZMA write FUseLZMA default False;
    // ForceZip64: quando True, AppendStream emite extras 0x0001 + ZIP64 EOCD
    // Record + Locator mesmo para archives pequenos. Util para testes e para
    // garantir compatibilidade ZIP64 antecipada quando o tamanho final ainda
    // nao e conhecido. Em condicoes normais, ZIP64 aciona automaticamente
    // quando >65535 entries OR archive >=4GB OR entry size >=4GB.
    property ForceZip64: Boolean read FForceZip64 write FForceZip64 default False;
    // v3.12 design-time additions ----------------------------------------
    // Deflate compression level 0..9 (0=store, 6=default, 9=best). Reservado.
    property CompressionLevel: Integer read FCompressionLevel write FCompressionLevel default 6;
    // AES key size (128/192/256). Hoje AE-2 sempre usa 256.
    property AESKeySize: Word read FAESKeySize write FAESKeySize default 256;
    // Comentario do archive (EOCDR comment field, max 65535 bytes).
    property ArchiveComment: string read FArchiveComment write FArchiveComment;
    // Split em multiplos .z01/.z02/.zip. 0 = single-file (default).
    property VolumeSize: Int64 read FVolumeSize write FVolumeSize default 0;
    // Armazena atributos DOS (READONLY/HIDDEN/SYSTEM/ARCHIVE) nos external attrs.
    property StoreMSDosAttributes: Boolean read FStoreMSDosAttributes write FStoreMSDosAttributes default True;
    // Armazena permissoes Unix via Info-ZIP Unix extra field (0x756e).
    property StoreUnixAttributes: Boolean read FStoreUnixAttributes write FStoreUnixAttributes default False;
    // Armazena NTFS security descriptor via extra field 0x4453.
    property StoreNTSecurity: Boolean read FStoreNTSecurity write FStoreNTSecurity default False;
  end;

  // Exception types relocated to Exceptions.ZipFile.pas (Wave 3a).
  // Aliased for backward compat with `uses ZipFile` consumers.
  EZipFileCancelled         = Exceptions.ZipFile.EZipFileCancelled;
  EZipFileZip64NotSupported = Exceptions.ZipFile.EZipFileZip64NotSupported;

type
  // Fluent builder + factory (relocated from former ZipFile.Fluent.pas per
  // backend-pascal-unit-naming_V1.6.0 §2). Interface IZipFileBuilder lives
  // in ZipFile.Interfaces.pas (along with TCompressionMethod/TReCompressionMethod/
  // TFileChangedEvent types it uses).

  // Append intent recorded by the fluent chain; flushed lazily in .Execute.
  TZipBuilderItem = record
    Kind: (zbkStream, zbkFile, zbkDelete, zbkUpdate);
    ZipName: string;
    DiskFileName: string;
    Stream: TStream;
    OwnStream: Boolean;
  end;

  TZipFileBuilder = class(TInterfacedObject, IZipFileBuilder)
  private
    FArchivePath: string;
    FOpenForUpdate: Boolean;
    FUseUtf8: Boolean;
    FUseAES: Boolean;
    FPassword: string;
    FUseLZMA: Boolean;
    FForceZip64: Boolean;
    FCompression: TCompressionMethod;
    FReCompression: TReCompressionMethod;
    FCompressionSet: Boolean;
    FReCompressionSet: Boolean;
    FOnProgress: TZipProgressEvent;
    FOnArchiveChanged: TFileChangedEvent;
    FItems: array of TZipBuilderItem;
    procedure ApplySettings(AZip: TZipFile);
  public
    constructor CreateNew(const APath: string);
    constructor CreateOpen(const APath: string);
    function WithUtf8(AEnable: Boolean = True): IZipFileBuilder;
    function WithAES(const APassword: string): IZipFileBuilder;
    function WithPassword(const APassword: string): IZipFileBuilder;
    function WithLZMA(AEnable: Boolean = True): IZipFileBuilder;
    function WithForceZip64(AEnable: Boolean = True): IZipFileBuilder;
    function WithCompression(AMethod: TCompressionMethod): IZipFileBuilder;
    function WithReCompression(AMethod: TReCompressionMethod): IZipFileBuilder;
    function OnProgress(AEvent: TZipProgressEvent): IZipFileBuilder;
    function OnArchiveChanged(AEvent: TFileChangedEvent): IZipFileBuilder;
    function AppendStream(AStream: TStream; const AZipName: string;
                         AOwnStream: Boolean = False): IZipFileBuilder;
    function AppendFile(const ADiskFileName, AZipName: string): IZipFileBuilder;
    function DeleteEntry(const AZipName: string): IZipFileBuilder;
    function UpdateEntry(AStream: TStream; const AZipName: string;
                         AOwnStream: Boolean = False): IZipFileBuilder;
    procedure Execute;
    function ExtractStream(const AZipName: string): TStream;
    function HasEntry(const AZipName: string): Boolean;
    function CountEntries: Cardinal;
  end;

  Zip = class
  public
    class function NewArchive(const APath: string): IZipFileBuilder;
    class function OpenArchive(const APath: string): IZipFileBuilder;
  end;

procedure Register;

implementation

{$IF DEFINED(FPC) AND DEFINED(ZIPFILE_LCL_PALETTE)}
uses
  TarFile,
  TarGzFile,
  GzipFile,
  WCabFile,
  SevenZFile,
  ArjFile,
  IsoFile,
  LhaFile,
  RarFile;
{$ENDIF}

// Register — chamado pelo Lazarus em FPC (via HasRegisterProc no .lpk).
// Em Delphi a registration acontece em packages/zipfileReg.pas (que tambem
// configura property categories no Object Inspector). Aqui em FPC mantemos
// apenas RegisterComponents — Lazarus nao suporta property categories.
procedure Register;
begin
{$IF DEFINED(FPC) AND DEFINED(ZIPFILE_LCL_PALETTE)}
  RegisterComponents('ZipFileORM',
    [TZipFile,
     TTarFile,
     TTarGzFile,
     TGzipFile,
     TWCabFile,
     TSevenZFile,
     TArjFile,
     TIsoFile,
     TLhaFile,
     TRarFile]);
{$ENDIF}
end;

function TZipFile.DoProgress(ABytesDone, ABytesTotal: Int64): Boolean;
var
  LCancel: Boolean;
begin
  Result := False;
  if not Assigned(FOnProgress) then
    Exit;
  LCancel := False;
  FOnProgress(Self, ABytesDone, ABytesTotal, LCancel);
  Result := LCancel;
end;

procedure TZipFile.RandomizeSalt(var ASalt: array of Byte);
var
  I: Integer;
begin
  // Salt cryptographic-quality random:
  //   - FPC: usa Random com seed via Randomize() (best-effort sem libsodium).
  //   - Delphi: idem; consumidor que precisa NIST-level deve injectar salt.
  // Note: WinZip AE only requires that the same salt never repeat for the same
  // password. Random suffices for low-volume scenarios; high-volume users should
  // override via a property hook (TODO future).
  for I := Low(ASalt) to High(ASalt) do
    ASalt[I] := Byte(Random(256));
end;

function TZipFile.ParseAESExtraField(const ARaw: RawByteString; out ARealMethod: Word): Boolean;
var
  Bytes: TBytes;
  P, Total: Integer;
  HdrID, DataSize: Word;
begin
  Result := False;
  ARealMethod := 0;
  Total := Length(ARaw);
  if Total < 11 then
    Exit;
  SetLength(Bytes, Total);
  Move(Pointer(ARaw)^, Bytes[0], Total);
  P := 0;
  // Scan all extra fields ([HdrID(2)][Size(2)][Data(Size)]) — pick 0x9901
  while P + 4 <= Total do
  begin
    HdrID    := Bytes[P] or (Bytes[P+1] shl 8);
    DataSize := Bytes[P+2] or (Bytes[P+3] shl 8);
    if (HdrID = ZipFile.Encryption.AES.WINZIP_AES_EXTRA_FIELD_ID) and
       (DataSize = 7) and (P + 4 + DataSize <= Total) then
    begin
      // Bytes layout after HdrID/Size: ver(2)+vendor(2)+strength(1)+method(2)
      ARealMethod := Bytes[P+4+5] or (Bytes[P+4+6] shl 8);
      Exit(True);
    end;
    Inc(P, 4 + DataSize);
  end;
end;

function TZipFile.BuildAESExtraField(ARealMethod: Word): RawByteString;
var
  Buf: array[0..10] of Byte;
begin
  // [0..1]  Header ID 0x9901 (LE)
  Buf[0] := $01; Buf[1] := $99;
  // [2..3]  Data Size = 7 (LE)
  Buf[2] := $07; Buf[3] := $00;
  // [4..5]  Version = 2 (AE-2, LE)
  Buf[4] := $02; Buf[5] := $00;
  // [6..7]  Vendor ID = "AE"
  Buf[6] := Ord('A'); Buf[7] := Ord('E');
  // [8]     Strength = 0x03 (AES-256)
  Buf[8] := $03;
  // [9..10] Real Compression Method (LE)
  Buf[9]  := Byte(ARealMethod);
  Buf[10] := Byte(ARealMethod shr 8);
  SetLength(Result, 11);
  Move(Buf[0], Pointer(Result)^, 11);
end;

function TZipFile.EntryNeedsZip64(AUSize, ACSize, AOffset: Int64): Boolean;
begin
  Result := FForceZip64
        or (AUSize  >= Int64(ZipFile.ZIP64.ZIP64_MAGIC_32))
        or (ACSize  >= Int64(ZipFile.ZIP64.ZIP64_MAGIC_32))
        or (AOffset >= Int64(ZipFile.ZIP64.ZIP64_MAGIC_32));
end;

procedure TZipFile.EmitZip64EocdAndLocator;
var
  Rec: ZipFile.ZIP64.TZip64EndOfCentralDirectoryRecord;
  Loc: ZipFile.ZIP64.TZip64EndOfCentralDirectoryLocator;
  Zip64EOCDOffset: Int64;
begin
  Zip64EOCDOffset := fs.Position;

  // ZIP64 EOCD Record (56 bytes total: sig(4) + sizeofrecord(8) + 44 bytes rest)
  Rec.Signature        := ZipFile.ZIP64.ZIP64_END_OF_CD_RECORD_SIGNATURE;
  Rec.SizeOfRecord     := 44;     // size of the remainder following this Int64
  Rec.VersionMadeBy    := $002D;  // 4.5
  Rec.VersionNeeded    := $002D;
  Rec.DiskNumber       := 0;
  Rec.DiskWithCDStart  := 0;
  Rec.EntriesOnThisDisk := UInt64(FZip64TotalEntries);
  Rec.TotalEntries     := UInt64(FZip64TotalEntries);
  Rec.CDSize           := UInt64(FZip64CDSize);
  Rec.CDOffset         := UInt64(FZip64CDOffset);
  fs.WriteBuffer(Rec, SizeOf(Rec));

  // ZIP64 EOCD Locator (fixed 20 bytes)
  Loc.Signature          := ZipFile.ZIP64.ZIP64_END_OF_CD_LOCATOR_SIGNATURE;
  Loc.DiskWithZip64EOCD  := 0;
  Loc.Zip64EOCDOffset    := UInt64(Zip64EOCDOffset);
  Loc.TotalDisks         := 1;
  fs.WriteBuffer(Loc, SizeOf(Loc));
end;

function TZipFile.BuildZip64ExtraField(AUSize, ACSize, AOffset: Int64; AIncludeOffset: Boolean): RawByteString;
var
  DataSize: Word;
  Buf: array of Byte;
  V64: UInt64;
  P: Integer;
begin
  // Layout: [HdrID=0x0001 LE 2][DataSize LE 2][USize 8][CSize 8][Offset 8?]
  if AIncludeOffset then
    DataSize := 24
  else
    DataSize := 16;
  SetLength(Buf, 4 + DataSize);
  Buf[0] := $01; Buf[1] := $00;
  Buf[2] := Byte(DataSize); Buf[3] := Byte(DataSize shr 8);
  V64 := UInt64(AUSize);
  Move(V64, Buf[4], 8);
  V64 := UInt64(ACSize);
  Move(V64, Buf[12], 8);
  if AIncludeOffset then
  begin
    V64 := UInt64(AOffset);
    Move(V64, Buf[20], 8);
  end;
  P := 4 + DataSize;
  SetLength(Result, P);
  Move(Buf[0], Pointer(Result)^, P);
end;

procedure TZipFile.DetectAndParseZip64;
var
  Loc: ZipFile.ZIP64.TZip64EndOfCentralDirectoryLocator;
  Rec: ZipFile.ZIP64.TZip64EndOfCentralDirectoryRecord;
  SavedPos: Int64;
  HasZip64: Boolean;
begin
  // Defaults: shadow Int64 mirror the standard 32-bit fields.
  FZip64TotalEntries := endofcdrecord.start.totalnumberofcdentries;
  FZip64CDSize := endofcdrecord.start.sizeofthecentraldirectory;
  FZip64CDOffset := endofcdrecord.start.cdoffset;

  HasZip64 := False;
  // Trigger 1: standard EOCD fields carry ZIP64 sentinel.
  if (endofcdrecord.start.cdoffset = ZipFile.ZIP64.ZIP64_MAGIC_32) or
     (endofcdrecord.start.sizeofthecentraldirectory = ZipFile.ZIP64.ZIP64_MAGIC_32) or
     (endofcdrecord.start.numberofcdentries = ZipFile.ZIP64.ZIP64_MAGIC_16) or
     (endofcdrecord.start.totalnumberofcdentries = ZipFile.ZIP64.ZIP64_MAGIC_16) then
    HasZip64 := True;

  // Trigger 2: ZIP64 EOCD Locator presente nos 20 bytes anteriores a EOCD std.
  if (not HasZip64) and (endofcdrecordstartpos >= 20) then
  begin
    SavedPos := fs.Position;
    try
      fs.Seek(endofcdrecordstartpos - 20, soFromBeginning);
      fs.ReadBuffer(Loc, SizeOf(Loc));
      if Loc.Signature = ZipFile.ZIP64.ZIP64_END_OF_CD_LOCATOR_SIGNATURE then
        HasZip64 := True;
    finally
      fs.Position := SavedPos;
    end;
  end;

  if not HasZip64 then
    Exit;

  // Re-le o Locator se ainda nao temos. Esta de pe que o Locator ESTA no
  // offset (endofcdrecordstartpos - 20) quando HasZip64 do trigger 1 esta
  // setado mas o sigantura nao foi confirmada ainda; nesse caso confirmamos.
  fs.Seek(endofcdrecordstartpos - 20, soFromBeginning);
  fs.ReadBuffer(Loc, SizeOf(Loc));
  if Loc.Signature <> ZipFile.ZIP64.ZIP64_END_OF_CD_LOCATOR_SIGNATURE then
    raise EArchiveCorrupt.Create(Format(
      'Archive "%s" has ZIP64 sentinel mas Locator nao encontrado em offset %d.',
      [FFileName, endofcdrecordstartpos - 20]), ERR_ARCHIVE_CORRUPT);

  // Le o ZIP64 EOCD Record propriamente.
  fs.Seek(Loc.Zip64EOCDOffset, soFromBeginning);
  fs.ReadBuffer(Rec, SizeOf(Rec));
  if Rec.Signature <> ZipFile.ZIP64.ZIP64_END_OF_CD_RECORD_SIGNATURE then
    raise EArchiveCorrupt.Create(Format(
      'Archive "%s" ZIP64 EOCD Record sig invalida em offset %d.',
      [FFileName, Loc.Zip64EOCDOffset]), ERR_ARCHIVE_CORRUPT);

  FZip64TotalEntries := Int64(Rec.TotalEntries);
  FZip64CDSize := Int64(Rec.CDSize);
  FZip64CDOffset := Int64(Rec.CDOffset);
end;

procedure TZipFile.ParseEntryZip64Shadow(AIndex: Integer);
var
  Raw: RawByteString;
  Bytes: TBytes;
  P, Total: Integer;
  HdrID, DataSize: Word;
  NeedUSize, NeedCSize, NeedOffset: Boolean;
  V64: UInt64;
  V32: Cardinal;
  EntryStart: Integer;
begin
  // Defaults: shadow mirrors the 32-bit fields.
  FEntryUSize64[AIndex] := fileheaderlist[AIndex].start.uncompressedsize;
  FEntryCSize64[AIndex] := fileheaderlist[AIndex].start.compressedsize;
  FEntryOffset64[AIndex] := fileheaderlist[AIndex].start.reloffsetlocalheader;

  NeedUSize  := fileheaderlist[AIndex].start.uncompressedsize = ZipFile.ZIP64.ZIP64_MAGIC_32;
  NeedCSize  := fileheaderlist[AIndex].start.compressedsize = ZipFile.ZIP64.ZIP64_MAGIC_32;
  NeedOffset := fileheaderlist[AIndex].start.reloffsetlocalheader = ZipFile.ZIP64.ZIP64_MAGIC_32;
  if not (NeedUSize or NeedCSize or NeedOffset) then
    Exit;

  // Procura extra field 0x0001 e parseia os Int64s na ordem fixa:
  // UncompressedSize, CompressedSize, RelativeOffset, DiskStartNumber.
  Raw := ZipFile.UTF8.StrToBytes(fileheaderlist[AIndex].add.extrafield);
  Total := Length(Raw);
  if Total < 4 then Exit;
  SetLength(Bytes, Total);
  Move(Pointer(Raw)^, Bytes[0], Total);
  P := 0;
  while P + 4 <= Total do
  begin
    HdrID    := Bytes[P] or (Bytes[P+1] shl 8);
    DataSize := Bytes[P+2] or (Bytes[P+3] shl 8);
    if HdrID = ZipFile.ZIP64.ZIP64_EXTRA_FIELD_ID then
    begin
      EntryStart := P + 4;
      if NeedUSize and (EntryStart + 8 <= Total) then
      begin
        Move(Bytes[EntryStart], V64, 8);
        FEntryUSize64[AIndex] := Int64(V64);
        Inc(EntryStart, 8);
      end;
      if NeedCSize and (EntryStart + 8 <= Total) then
      begin
        Move(Bytes[EntryStart], V64, 8);
        FEntryCSize64[AIndex] := Int64(V64);
        Inc(EntryStart, 8);
      end;
      if NeedOffset and (EntryStart + 8 <= Total) then
      begin
        Move(Bytes[EntryStart], V64, 8);
        FEntryOffset64[AIndex] := Int64(V64);
        Inc(EntryStart, 8);
      end;
      // DiskStartNumber ignorado (ZipFile single-disk).
      Exit;
    end;
    Inc(P, 4 + DataSize);
  end;
end;

procedure TZipFile.DoProgressChunkedCopy(ASrc, ADst: TStream; ATotal: Int64);
const
  CHUNK = 64 * 1024;
var
  Buf: array of Byte;
  Done: Int64;
  N: Integer;
  Want: Int64;
begin
  SetLength(Buf, CHUNK);
  Done := 0;
  while Done < ATotal do
  begin
    Want := ATotal - Done;
    if Want > CHUNK then
      Want := CHUNK;
    N := ASrc.Read(Buf[0], Want);
    if N <= 0 then
      Break;
    ADst.WriteBuffer(Buf[0], N);
    Inc(Done, N);
    if DoProgress(Done, ATotal) then
      raise EZipFileCancelled.Create('ZIP operation cancelled by OnProgress handler');
  end;
end;

constructor TZipFile.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  endofcdrecord.start.endofcentraldirsignature := $06054b50;

  // v3.12 design-time defaults
  FCompressionLevel := 6;
  FAESKeySize := 256;
  FVolumeSize := 0;
  FStoreMSDosAttributes := True;

  Reset;
end;

destructor TZipFile.Destroy;
begin
  inherited Destroy;

  Reset;
end;

procedure TZipFile.Reset;
begin
  FActive := False;
  endofcdrecordstartpos := 0;
  fileheadercount:= 0;
  fileindex := 0;
  SetLength(fileheaderlist, fileheadercount);
  SetLength(FEntryUSize64, 0);
  SetLength(FEntryCSize64, 0);
  SetLength(FEntryOffset64, 0);
  FZip64TotalEntries := 0;
  FZip64CDSize := 0;
  FZip64CDOffset := 0;

  if Assigned(fs) then
    FreeAndNil(fs);
end;

procedure TZipFile.SetFileName(Value: string);
begin
  if Value <> FFileName then
  begin
    Reset;
    FFileName := Value;
  end;
end;

procedure TZipFile.Activate;
begin
  Active := True;
end;

// ============================================================================
//   v2.4: Fluent inline configurators
//   Cada método seta property correspondente e devolve Self → chaining.
//   Comportamento 100% equivalente a `Self.X := value;` exceto que pode ser
//   encadeado em uma única expressão.
// ============================================================================

function TZipFile.WithUtf8(AEnable: Boolean): TZipFile;
begin
  FUseUtf8 := AEnable;
  Result := Self;
end;

function TZipFile.WithAES(const APassword: string): TZipFile;
begin
  FUseAES := True;
  FPassword := APassword;
  Result := Self;
end;

function TZipFile.WithLZMA(AEnable: Boolean): TZipFile;
begin
  FUseLZMA := AEnable;
  Result := Self;
end;

function TZipFile.WithForceZip64(AEnable: Boolean): TZipFile;
begin
  FForceZip64 := AEnable;
  Result := Self;
end;

function TZipFile.WithProgress(AEvent: TZipProgressEvent): TZipFile;
begin
  FOnProgress := AEvent;
  Result := Self;
end;

function TZipFile.WithPassword(const APassword: string): TZipFile;
begin
  FPassword := APassword;
  Result := Self;
end;

function TZipFile.WithCompression(AMethod: TCompressionMethod): TZipFile;
begin
  FCompression := AMethod;
  Result := Self;
end;

function TZipFile.WithReCompression(AMethod: TReCompressionMethod): TZipFile;
begin
  FReCompression := AMethod;
  Result := Self;
end;

function TZipFile.WithFileName(const APath: string): TZipFile;
begin
  SetFileName(APath);
  Result := Self;
end;

function TZipFile.OnArchiveChanged(AEvent: TFileChangedEvent): TZipFile;
begin
  FOnFileChanged := AEvent;
  Result := Self;
end;

function TZipFile.Open: TZipFile;
begin
  Active := True;
  Result := Self;
end;

procedure TZipFile.SetActive(Value: boolean);
var
  i: Int64;
begin
  if Value <> FActive then
  begin
    FActive := Value;

    if Value = True then
    begin
      if not SysUtils.FileExists(FileName) then
      begin
        fs := TFileStream.Create(FileName, fmCreate);

        //write EOCDH
        fs.WriteBuffer(endofcdrecord.start, SizeOf(endofcdrecord.start));
        fs.WriteBuffer(endofcdrecord.add.ZIPfilecomment[1], Length(endofcdrecord.add.ZIPfilecomment));

        fs.Free;
      end;

      //open the filestream to the ZipFile
      fs := TFileStream.Create(FileName, fmOpenReadWrite);

      //get position of end of CD header
      endofcdrecordstartpos := EndOfCDRecordPosition;

      //get end of CD record from disk
      GetEndOfCDRecord;

      // v2.0: parse ZIP64 EOCD Locator + Record (if any) into shadow Int64
      // fields, so we can iterate >65535 entries and seek to CDs beyond 4 GB.
      DetectAndParseZip64;

      //read all file headers from ZipFile (use Int64 shadow for count + offset).
      // FPC i386 nao aceita Int64 em variavel de loop — usar while.
      fs.Seek(FZip64CDOffset, soFromBeginning);
      i := 1;
      while i <= FZip64TotalEntries do
      begin
        GetCDFileHeaders;
        Inc(i);
      end;

      if Assigned(FOnFileChanged) then FOnFileChanged(Self);
    end
    else
      Reset;
  end;
end;

procedure TZipFile.GetCDFileHeaders;
{$IFNDEF FPC}
var
  RawName, RawExtra, RawComment: RawByteString;
{$ENDIF}
begin
  Inc(fileheadercount);
  SetLength(fileheaderlist, fileheadercount);
  SetLength(FEntryUSize64, fileheadercount);
  SetLength(FEntryCSize64, fileheadercount);
  SetLength(FEntryOffset64, fileheadercount);

  with fileheaderlist[Pred(fileheadercount)] do
  begin
    //read fixed record
    fs.ReadBuffer(start, SizeOf(start));

    //do not change the order of the remaining statements unless you know what you are doing
    {$IFDEF FPC}
    SetLength(add.filename, start.filenamelength);
    fs.ReadBuffer(add.filename[1], start.filenamelength);
    SetLength(add.extrafield, start.extrafieldlength);
    fs.ReadBuffer(add.extrafield[1], start.extrafieldlength);
    SetLength(add.filecomment, start.filecommentlength);
    fs.ReadBuffer(add.filecomment[1], start.filecommentlength);
    {$ELSE}
    // Delphi: read raw bytes into RawByteString, then decode filename per bit 11.
    SetLength(RawName, start.filenamelength);
    if start.filenamelength > 0 then
      fs.ReadBuffer(RawName[1], start.filenamelength);
    add.filename := ZipFile.UTF8.DecodeFilename(RawName, ZipFile.UTF8.IsUtf8Flagged(start.generalpurposebit));
    SetLength(RawExtra, start.extrafieldlength);
    if start.extrafieldlength > 0 then
      fs.ReadBuffer(RawExtra[1], start.extrafieldlength);
    add.extrafield := ZipFile.UTF8.BytesToStr(RawExtra);
    SetLength(RawComment, start.filecommentlength);
    if start.filecommentlength > 0 then
      fs.ReadBuffer(RawComment[1], start.filecommentlength);
    add.filecomment := ZipFile.UTF8.BytesToStr(RawComment);
    {$ENDIF}
  end;
  // v2.0 ZIP64: parseia extra field 0x0001 per-entry e popula shadow Int64.
  ParseEntryZip64Shadow(fileheadercount - 1);
end;

procedure TZipFile.GetEndOfCDRecord;
begin
  fs.Seek(endofcdrecordstartpos, soFromBeginning);

  //read fixed part
  fs.ReadBuffer(endofcdrecord.start, SizeOf(endofcdrecord.start));

  //read variable part
  SetLength(endofcdrecord.add.ZIPfilecomment, endofcdrecord.start.ZIPfilecommentlength);
  if endofcdrecord.start.ZIPfilecommentlength > 0 then
    fs.ReadBuffer(endofcdrecord.add.ZIPfilecomment[1], endofcdrecord.start.ZIPfilecommentlength);

  // v4.1 P20: populate read-only ArchiveComment + ArchiveSize properties.
  FArchiveComment := endofcdrecord.add.ZIPfilecomment;
  FArchiveSize := fs.Size;
end;

function TZipFile.GetFileSize: Int64;
begin
  if Assigned(fs) then
    Result := fs.Size
  else
    Result := -1;
end;

function TZipFile.EndOfCDRecordPosition: longword;
var
  len: LongWord;
  i: integer;
  {$IFDEF FPC}
  buf: string;
  {$ELSE}
  buf: RawByteString;  // 1 byte per element, safe for binary scan
  {$ENDIF}
begin
  //check if the position was already determined before
  if endofcdrecordstartpos <> 0 then
  begin
    Result := endofcdrecordstartpos;
    exit;
  end;

  //calculate the size of the buffer for the endofcdheader record
  //65557bytes is the maximum size of the datastructure
  fs.Seek(0,soFromEnd);
  len := Min(65557, fs.Position);

  //reset the filestream to start looking from the end
  fs.Seek(-len,soFromEnd);

  //read data segment
  SetLength(buf, len);
  if len > 0 then
    fs.ReadBuffer(buf[1], len);

  //search for the start of the end-of-CD-record signature (PK\x05\x06).
  //Upper bound is `len - 21` so the full 22-byte EOCDR fits within buf.
  //Lower bound is 1 to support the minimal 22-byte EOCDR-only archive.
  for i:= len - 21 downto 1 do
    if(buf[i]='P') and (buf[i+1]='K') and (buf[i+2]=#5) and (buf[i+3]=#6) then
      break;

  // i is 1-based within buf. buf[1] corresponds to file offset (fs.Size - len).
  // Convert to absolute file offset so Seek hits the real EOCDR even when the
  // archive is larger than 65557 bytes (buf is only the trailing window).
  Result := longword(Int64(fs.Size) - Int64(len)) + Pred(i);
end;

function GetBit(const Value: Cardinal; const Bit: Byte): Boolean;
begin
  Result := (Value and (1 shl Bit)) <> 0;
end;

function TZipFile.ReadLocalFileHeader(AOffSet: Int64): TLocalFileHeader;
{$IFNDEF FPC}
var
  RawName, RawExtra: RawByteString;
{$ENDIF}
begin
  fs.Seek(AOffset, soFromBeginning);

  //read local header start
  fs.ReadBuffer(Result.start, SizeOf(Result.start));

  {$IFDEF FPC}
  //read filename
  SetLength(Result.add.filename, Result.start.filenamelength);
  fs.ReadBuffer(Result.add.filename[1], Result.start.filenamelength);

  //read extra field
  SetLength(Result.add.extrafield, Result.start.ExtraFieldLength);
  fs.ReadBuffer(Result.add.extrafield[1], Result.start.extrafieldlength);
  {$ELSE}
  // Delphi: read raw bytes, decode filename per bit 11 of GP flag.
  SetLength(RawName, Result.start.filenamelength);
  if Result.start.filenamelength > 0 then
    fs.ReadBuffer(RawName[1], Result.start.filenamelength);
  Result.add.filename := ZipFile.UTF8.DecodeFilename(RawName, ZipFile.UTF8.IsUtf8Flagged(Result.start.generalpurposebit));
  SetLength(RawExtra, Result.start.ExtraFieldLength);
  if Result.start.ExtraFieldLength > 0 then
    fs.ReadBuffer(RawExtra[1], Result.start.extrafieldlength);
  Result.add.extrafield := ZipFile.UTF8.BytesToStr(RawExtra);
  {$ENDIF}
end;

function TZipFile.GetFileStream(AFileName: string; var BufLength: longword): TMemoryStream;
var
  index: longword;
  lfh: TLocalFileHeader;
  filedataoffset: Int64;
  lCompressed : TMemoryStream ;
  lCompress : TtiCompressAbs ;
  // v2.1 LZMA read-side
  LZmaProps, LZmaPayload, LZmaPlain: TBytes;
  LPropsSize: Word;
  LExpectedUSize: Int64;
  // v2.0 AES read-side
  LRealMethod: Word;
  LSalt: array[0..ZipFile.Encryption.AES.AES256_SALT_SIZE - 1] of Byte;
  LPwdVerifyRead, LPwdVerifyExpected: array[0..ZipFile.Encryption.AES.WINZIP_AE_PWD_VERIFY_BYTES - 1] of Byte;
  LEncKey, LAuthKey: ZipFile.Encryption.AES.TAESKey256;
  LExpanded: ZipFile.Encryption.AES.TAESExpandedKey;
  LHmacRead, LHmacExpected: TBytes;
  LCipherBytes: TBytes;
  LCipherLen: Integer;
  LDecrypted: TMemoryStream;
  I: Integer;
  LIsAES: Boolean;
begin
  index := FileNameIndex(AFileName);

  if (index < 0) or (index > Pred(fileheadercount)) then
    raise EArchiveEntryNotFound.Create(Format(rsFilenameSDoesNotExistInS, [AFileName, FileName]), ERR_ARCHIVE_ENTRY_NOT_FOUND);

  // v2.0 ZIP64: prefer shadow Int64 values when available (sentinel detected).
  lfh := ReadLocalFileHeader(FEntryOffset64[index]);
  BufLength := longword(FEntryCSize64[index]);   // legacy 32-bit API; >4GB truncates

  filedataoffset := FEntryOffset64[index] + 30 +
                    lfh.start.filenamelength + lfh.start.extrafieldlength;

  fs.Seek(filedataoffset, soFromBeginning);

  // ===== v2.0: AES-2 detection / decrypt =====
  LIsAES := (FileHeaderList[index].start.compressionmethod = ZipFile.Encryption.AES.WINZIP_AES_METHOD)
        and ((FileHeaderList[index].start.generalpurposebit and ZipFile.Encryption.AES.GP_FLAG_ENCRYPTED) <> 0);
  if LIsAES then
  begin
    if FPassword = '' then
      raise ZipFile.Encryption.AES.EZipAESError.CreateFmt('Entry "%s" is AES-encrypted but Password property is empty.', [AFileName]);
    if not ParseAESExtraField(ZipFile.UTF8.StrToBytes(FileHeaderList[index].add.extrafield), LRealMethod) then
      raise ZipFile.Encryption.AES.EZipAESError.CreateFmt('Entry "%s" missing or invalid 0x9901 AES extra field.', [AFileName]);
    // Read salt + pwd_verify + cipher + hmac directly from fs.
    fs.ReadBuffer(LSalt[0], Length(LSalt));
    fs.ReadBuffer(LPwdVerifyRead[0], Length(LPwdVerifyRead));
    LCipherLen := BufLength - Length(LSalt) - Length(LPwdVerifyRead) - ZipFile.Encryption.AES.WINZIP_AE_HMAC_TRAILER;
    if LCipherLen < 0 then
      raise ZipFile.Encryption.AES.EZipAESError.CreateFmt('Entry "%s" is too short to contain AES envelope.', [AFileName]);
    SetLength(LCipherBytes, LCipherLen);
    if LCipherLen > 0 then
      fs.ReadBuffer(LCipherBytes[0], LCipherLen);
    SetLength(LHmacRead, ZipFile.Encryption.AES.WINZIP_AE_HMAC_TRAILER);
    fs.ReadBuffer(LHmacRead[0], ZipFile.Encryption.AES.WINZIP_AE_HMAC_TRAILER);
    // Derive keys and check pwd_verify
    ZipFile.Encryption.AES.DeriveAEKeys(RawByteString(FPassword), LSalt, LEncKey, LAuthKey, LPwdVerifyExpected);
    if not CompareMem(@LPwdVerifyRead[0], @LPwdVerifyExpected[0], Length(LPwdVerifyRead)) then
      raise ZipFile.Encryption.AES.EZipAESError.Create('Bad password (AES password verification failed).');
    // Verify HMAC trailer
    LHmacExpected := ZipFile.Encryption.AES.HmacAuthTag(LAuthKey, LCipherBytes, LCipherLen);
    for I := 0 to ZipFile.Encryption.AES.WINZIP_AE_HMAC_TRAILER - 1 do
      if LHmacRead[I] <> LHmacExpected[I] then
        raise ZipFile.Encryption.AES.EZipAESError.Create('AES HMAC authentication failed (ciphertext tampered).');
    // Decrypt in place via CTR (counter starts at 1)
    ZipFile.Encryption.AES.AES256ExpandKey(LEncKey, LExpanded);
    ZipFile.Encryption.AES.AES256CtrXor(LExpanded, LCipherBytes, LCipherLen, 1);
    LDecrypted := TMemoryStream.Create;
    if LCipherLen > 0 then
      LDecrypted.WriteBuffer(LCipherBytes[0], LCipherLen);
    LDecrypted.Position := 0;
    lCompressed := LDecrypted;
    BufLength := LCipherLen;
  end
  else
  // ===== end AES =====
  begin
    lCompressed := TMemoryStream.Create;
    lCompressed.CopyFrom(fs, BufLength);
    lCompressed.Position := 0;
    LRealMethod := FileHeaderList[index].start.compressionmethod;
  end;

  Result := TMemoryStream.Create;
  try
    // v2.1: LZMA (method 14) decode handled inline (not via tiCompress).
    if LRealMethod = 14 then
    begin
      // PKWARE LZMA prefix: 2 bytes ver (major/minor, skip) + 2 bytes props size
      // (LE, == 5 by spec) + 5 bytes props + payload.
      lCompressed.Position := 0;
      lCompressed.Seek(2, soBeginning);  // skip ver bytes
      lCompressed.ReadBuffer(LPropsSize, SizeOf(LPropsSize));
      if LPropsSize <> ZipFile.Compression.LZMA.LZMA_PROPS_SIZE then
        raise EZipLZMAError.CreateFmt('LZMA prefix props_size=%d (expected 5).', [LPropsSize]);
      SetLength(LZmaProps, LPropsSize);
      lCompressed.ReadBuffer(LZmaProps[0], LPropsSize);
      SetLength(LZmaPayload, lCompressed.Size - lCompressed.Position);
      if Length(LZmaPayload) > 0 then
        lCompressed.ReadBuffer(LZmaPayload[0], Length(LZmaPayload));
      LExpectedUSize := FEntryUSize64[index];
      ZipFile.Compression.LZMA.LzmaDecompressBuffer(LZmaPayload, Length(LZmaPayload),
        LZmaProps, LZmaPlain, LExpectedUSize);
      if Length(LZmaPlain) > 0 then
        Result.WriteBuffer(LZmaPlain[0], Length(LZmaPlain));
      Result.Position := 0;
    end
    else
    begin
      // v4.1: fix — case ramo `else` and method-8 both fell into cgsCompressNone,
      // which silently returned raw DEFLATE bytes instead of decompressed
      // plaintext. Now method 8 routes to cgsCompressZLib correctly.
      case LRealMethod of
        0: lCompress := gCompressFactory.CreateInstance(cgsCompressNone);
        8: lCompress := gCompressFactory.CreateInstance(cgsCompressZLib);
      else
        // Unknown methods fall back to None (legacy behavior preserved;
        // streaming GetEntryStream path handles LZMA/AES separately).
        lCompress := gCompressFactory.CreateInstance(cgsCompressNone);
      end;
      try
        lCompress.DecompressStream(lCompressed, Result);
      finally
        lCompress.Free ;
      end ;
    end;
  finally
    lCompressed.Free ;
  end ;
end;

function TZipFile.GetEntryStream(AFileName: string): TStream;
var
  index: longword;
  lfh: TLocalFileHeader;
  filedataoffset: Int64;
  LIsAES: Boolean;
  LRealMethod: Word;
  LSalt: array[0..ZipFile.Encryption.AES.AES256_SALT_SIZE - 1] of Byte;
  LPwdVerifyRead, LPwdVerifyExpected: array[0..ZipFile.Encryption.AES.WINZIP_AE_PWD_VERIFY_BYTES - 1] of Byte;
  LEncKey, LAuthKey: ZipFile.Encryption.AES.TAESKey256;
  LCipherLen: Int64;
  LCipherOffset: Int64;
  LHmacRead, LHmacExpected: TBytes;
  LCipherBytes: TBytes;
  LInner: ZipFile.Streaming.TZipEntryReadStream;
  LBufLen: longword;
  LMem: TMemoryStream;
  I: Integer;
begin
  index := FileNameIndex(AFileName);
  if (index < 0) or (index > Pred(fileheadercount)) then
    raise EArchiveEntryNotFound.Create(Format(rsFilenameSDoesNotExistInS, [AFileName, FileName]), ERR_ARCHIVE_ENTRY_NOT_FOUND);

  // v2.0 ZIP64: prefer shadow Int64 values when available (sentinel detected).
  lfh := ReadLocalFileHeader(FEntryOffset64[index]);
  filedataoffset := FEntryOffset64[index] + 30 +
                    lfh.start.filenamelength + lfh.start.extrafieldlength;

  LIsAES := (FileHeaderList[index].start.compressionmethod = ZipFile.Encryption.AES.WINZIP_AES_METHOD)
        and ((FileHeaderList[index].start.generalpurposebit and ZipFile.Encryption.AES.GP_FLAG_ENCRYPTED) <> 0);

  if LIsAES then
  begin
    // AES-2 envelope: salt(16) | pwd_verify(2) | cipher | hmac(10)
    if FPassword = '' then
      raise ZipFile.Encryption.AES.EZipAESError.CreateFmt(
        'Entry "%s" is AES-encrypted but Password property is empty.', [AFileName]);
    if not ParseAESExtraField(ZipFile.UTF8.StrToBytes(FileHeaderList[index].add.extrafield), LRealMethod) then
      raise ZipFile.Encryption.AES.EZipAESError.CreateFmt(
        'Entry "%s" missing or invalid 0x9901 AES extra field.', [AFileName]);
    if (LRealMethod <> 0) then
      // Method != Store — fallback to GetFileStream (decompress goes via TMemoryStream).
    begin
      LBufLen := 0;
      Result := GetFileStream(AFileName, LBufLen);
      Exit;
    end;
    fs.Position := filedataoffset;
    fs.ReadBuffer(LSalt[0], Length(LSalt));
    fs.ReadBuffer(LPwdVerifyRead[0], Length(LPwdVerifyRead));
    LCipherOffset := fs.Position;
    LCipherLen := FEntryCSize64[index] - Length(LSalt)
                  - Length(LPwdVerifyRead) - ZipFile.Encryption.AES.WINZIP_AE_HMAC_TRAILER;
    if LCipherLen < 0 then
      raise ZipFile.Encryption.AES.EZipAESError.CreateFmt(
        'Entry "%s" is too short to contain AES envelope.', [AFileName]);
    // Derive + verify pwd
    ZipFile.Encryption.AES.DeriveAEKeys(RawByteString(FPassword), LSalt, LEncKey, LAuthKey, LPwdVerifyExpected);
    if not CompareMem(@LPwdVerifyRead[0], @LPwdVerifyExpected[0], Length(LPwdVerifyRead)) then
      raise ZipFile.Encryption.AES.EZipAESError.Create('Bad password (AES password verification failed).');
    // Eagerly read ciphertext + HMAC trailer to verify authenticity BEFORE
    // exposing a stream (streamed HMAC verification requires reading all
    // bytes anyway; doing it upfront keeps the semantics simple).
    SetLength(LCipherBytes, LCipherLen);
    if LCipherLen > 0 then
      fs.ReadBuffer(LCipherBytes[0], LCipherLen);
    SetLength(LHmacRead, ZipFile.Encryption.AES.WINZIP_AE_HMAC_TRAILER);
    fs.ReadBuffer(LHmacRead[0], ZipFile.Encryption.AES.WINZIP_AE_HMAC_TRAILER);
    LHmacExpected := ZipFile.Encryption.AES.HmacAuthTag(LAuthKey, LCipherBytes, LCipherLen);
    for I := 0 to ZipFile.Encryption.AES.WINZIP_AE_HMAC_TRAILER - 1 do
      if LHmacRead[I] <> LHmacExpected[I] then
        raise ZipFile.Encryption.AES.EZipAESError.Create('AES HMAC authentication failed (ciphertext tampered).');
    // Build the inner slice over fs and the seekable AES-CTR wrapper.
    LInner := ZipFile.Streaming.TZipEntryReadStream.Create(fs, LCipherOffset, LCipherLen);
    Result := ZipFile.Streaming.TZipEntryAESReadStream.Create(LInner, LEncKey);
  end
  else
  begin
    // Non-encrypted path
    case FileHeaderList[index].start.compressionmethod of
      0:
        // STORED: hand back a thin slice over fs (no copy)
        Result := ZipFile.Streaming.TZipEntryReadStream.Create(fs, filedataoffset,
                    FEntryCSize64[index]);
      8:
        // DEFLATE: v3.2 streaming — decompress on demand, sem alocar memoria
        // para o entry inteiro. Forward-only seek.
        Result := ZipFile.Streaming.TZipEntryDeflateReadStream.Create(
                    ZipFile.Streaming.TZipEntryReadStream.Create(fs, filedataoffset,
                      FEntryCSize64[index]),
                    FEntryUSize64[index]);
    else
      // Outros metodos (LZMA, etc) — fallback legacy GetFileStream (in-memory)
      LBufLen := 0;
      LMem := GetFileStream(AFileName, LBufLen);
      LMem.Position := 0;
      Result := LMem;
    end;
  end;
end;

function TZipFile.FileNameIndex(AFileName: string): longint;
var
  i: longint;
begin
  Result := -1;

  for i:= 0 to Pred(fileheadercount) do
    if FileHeaderList[i].add.filename = AFileName then
    begin
      Result := i;
      Break;
    end;
end;

function TZipFile.FileCount: longword;
begin
  Result := fileheadercount;
end;

function TZipFile.FileExists(AFileName: string): boolean;
begin
  Result := FileNameIndex(AFileName) <> -1;
end;

function TZipFile.GetSearchResult(var SearchResult: TZipSearchRec): integer;
var
  FileDateTime: TDateTime;
begin
  Result := 0;
  if fileindex >= fileheadercount then
  begin
    Result := 1;
    exit;
  end;

  with SearchResult do
  begin
    DosDateTimeToDateTime(FileHeaderList[fileindex].start.lastmodfiledate,
                          FileHeaderList[fileindex].start.lastmodfiletime,
                          FileDateTime);
    DateTime := FileDateTime;
    // v2.0 ZIP64: usa shadow Int64 — TZipSearchRec.USize/CSize sao Int64
    USize := FEntryUSize64[fileindex];
    CSize := FEntryCSize64[fileindex];
    Name := FileHeaderList[fileindex].add.filename
  end;
end;

function TZipFile.FindFirst(var SearchResult: TZipSearchRec): integer;
begin
  fileindex := 0;

  Result := GetSearchResult(SearchResult);
end;

function TZipFile.FindNext(var SearchResult: TZipSearchRec): integer;
begin
  Inc(fileindex);

  Result := GetSearchResult(SearchResult);
end;

procedure TZipFile.DateTimeToDosDateTime(DateTime: TDateTime; var dosdate, dostime: word);
var
  y, m, d, h, n, s, ms: word;
begin
  DecodeDate(DateTime, y, m, d);
  DecodeTime(DateTime, h, n, s, ms);

  y := y - 1980;

  dosdate := d + (32 * m) + (512 * y);
  dostime := (s div 2) + (32 * n) + (2048 * h);
end;

procedure TZipFile.DosDateTimeToDateTime(dosdate, dostime: word; var DateTime: TDateTime);
var
  y, m, d, h, n, s: word;
begin
  y := dosdate div 512 + 1980;
  dosdate := dosdate mod 512;
  m := dosdate div 32;
  dosdate := dosdate mod 32;
  d := dosdate;

  h := dostime div 2048;
  dostime := dostime mod 2048;
  n := dostime div 32;
  dostime := dostime mod 32;
  s := dostime * 2;

  DateTime := EncodeDate(y, m, d) + EncodeTime(h, n, s, 0);
end;

procedure TZipFile.AddCDFileHeader(FSize: int64; AFileName: string; LocalOffset: longword; LFHSize: Int64; crc32: cardinal; FileDateTime: TDateTime);
var
  EncodedName: RawByteString;
  UseUtf8ForThisEntry: Boolean;
  NeedsZ64: Boolean;
  Z64Extra: RawByteString;
  ExtraLen: Integer;
  StoredUSize, StoredCSize, StoredOffset: longword;
begin
  // v2.0: UTF-8 filename support. Must match what was emitted in LFH so reader
  // sees consistent bit 11 + encoded name in both LFH and central directory.
  UseUtf8ForThisEntry := FUseUtf8 and ZipFile.UTF8.NeedsUtf8Encoding(AFileName);
  EncodedName := ZipFile.UTF8.EncodeFilename(AFileName, UseUtf8ForThisEntry);

  Inc(fileheadercount);
  SetLength(fileheaderlist, fileheadercount);
  SetLength(FEntryUSize64,  fileheadercount);
  SetLength(FEntryCSize64,  fileheadercount);
  SetLength(FEntryOffset64, fileheadercount);
  // Always populate shadow Int64 — used by GetFileStream/GetEntryStream even
  // when ZIP64 isn't needed (the sentinel parser falls through to the 32-bit
  // values in that case).
  FEntryUSize64[Pred(fileheadercount)]  := FSize;
  FEntryCSize64[Pred(fileheadercount)]  := FSize;       // overwritten post-compress
  FEntryOffset64[Pred(fileheadercount)] := LocalOffset; // 32-bit param; ZIP64 callers pass already-32-bit-safe value

  NeedsZ64 := EntryNeedsZip64(FSize, FSize, LocalOffset);
  Z64Extra := '';
  ExtraLen := 0;
  if NeedsZ64 then
  begin
    Z64Extra := BuildZip64ExtraField(FSize, FSize, LocalOffset, True);  // CDH includes offset
    ExtraLen := Length(Z64Extra);
    StoredUSize  := ZipFile.ZIP64.ZIP64_MAGIC_32;
    StoredCSize  := ZipFile.ZIP64.ZIP64_MAGIC_32;
    StoredOffset := ZipFile.ZIP64.ZIP64_MAGIC_32;
  end
  else
  begin
    StoredUSize  := longword(FSize);
    StoredCSize  := longword(FSize);
    StoredOffset := LocalOffset;
  end;

  with fileheaderlist[Pred(fileheadercount)] do
  begin
    start.signature := $02014b50;
    start.versionmadeby := $0B14;
    if NeedsZ64 then
      start.versiontoextract := $002D                // 4.5 (ZIP64)
    else
      start.versiontoextract := $000A;
    start.generalpurposebit := $0000;
    if UseUtf8ForThisEntry then
      start.generalpurposebit := start.generalpurposebit or ZipFile.UTF8.GP_FLAG_UTF8;
    start.compressionmethod := $0000;
    DateTimeToDosDateTime(FileDateTime , start.lastmodfiledate, start.lastmodfiletime);
    start.crc32 := crc32;
    start.compressedsize := StoredCSize;
    start.uncompressedsize := StoredUSize;
    start.filenamelength := Length(EncodedName);
    start.extrafieldlength := ExtraLen;
    start.filecommentlength := 0;
    start.disknumberstart := 0;
    start.internalfileattributes := 1;
    start.externalfileattributed := 32;
    start.reloffsetlocalheader := StoredOffset;

    add.filename := string(EncodedName);
    if NeedsZ64 then
      add.extrafield := ZipFile.UTF8.BytesToStr(Z64Extra)
    else
      add.extrafield := '';
    add.filecomment := '';
  end;

  //update EOCDH (16-bit fields wrap at $FFFF; ZIP64 EOCD will carry real values)
  Inc(endofcdrecord.start.numberofcdentries);
  Inc(endofcdrecord.start.totalnumberofcdentries);
  // Shadow Int64 archive accounting (always accurate, even when 16-bit wraps)
  Inc(FZip64TotalEntries);
  Inc(endofcdrecord.start.sizeofthecentraldirectory, SizeOf(fileheaderlist[Pred(fileheadercount)].start) + Length(EncodedName) + ExtraLen);
  Inc(FZip64CDSize, SizeOf(fileheaderlist[Pred(fileheadercount)].start) + Length(EncodedName) + ExtraLen);
  // LFH ZIP64 extra field: 4 hdr + 16 data (USize+CSize, no offset) = 20 bytes
  // when this entry triggers ZIP64. Must be counted in cdoffset accounting.
  if NeedsZ64 then
  begin
    Inc(endofcdrecord.start.cdoffset, LFHSize + Length(EncodedName) + 20 + FSize);
    Inc(FZip64CDOffset, LFHSize + Length(EncodedName) + 20 + FSize);
  end
  else
  begin
    Inc(endofcdrecord.start.cdoffset, LFHSize + Length(EncodedName) + FSize);
    Inc(FZip64CDOffset, LFHSize + Length(EncodedName) + FSize);
  end;
end;

function TZipFile.MakeLocalFileHeader(FileName: string; FSize: Int64; crc32: cardinal; FileDateTime: TDateTime): TLocalFileHeader;
var
  EncodedName: RawByteString;
  UseUtf8ForThisEntry: Boolean;
  NeedsZ64: Boolean;
  Z64Extra: RawByteString;
  StoredUSize, StoredCSize: longword;
begin
  // v2.0: UTF-8 filename support (PKWARE APPNOTE 4.4.4 / bit 11 GP flag).
  UseUtf8ForThisEntry := FUseUtf8 and ZipFile.UTF8.NeedsUtf8Encoding(FileName);
  EncodedName := ZipFile.UTF8.EncodeFilename(FileName, UseUtf8ForThisEntry);

  // ZIP64 trigger at LFH time uses the offset that AppendStream will pass in
  // via reloffsetlocalheader (we don't know it here, so trigger on size + force).
  NeedsZ64 := EntryNeedsZip64(FSize, FSize, 0);
  if NeedsZ64 then
  begin
    // LFH ZIP64 extra carries USize + CSize only (offset goes only in CDH).
    Z64Extra := BuildZip64ExtraField(FSize, FSize, 0, False);
    StoredUSize := ZipFile.ZIP64.ZIP64_MAGIC_32;
    StoredCSize := ZipFile.ZIP64.ZIP64_MAGIC_32;
  end
  else
  begin
    Z64Extra := '';
    StoredUSize := longword(FSize);
    StoredCSize := longword(FSize);
  end;

  with Result do
  begin
    start.signature := $04034b50;
    if NeedsZ64 then
      start.extractversion := $002D       // 4.5 (ZIP64)
    else
      start.extractversion := $000A;
    start.generalpurposebit := $0000;
    if UseUtf8ForThisEntry then
      start.generalpurposebit := start.generalpurposebit or ZipFile.UTF8.GP_FLAG_UTF8;
    start.compressmethod := $0000;
    DateTimeToDosDateTime(FileDateTime , start.lastmoddate, start.lastmodtime);
    start.crc32 := crc32;
    start.compressedsize := StoredCSize;
    start.uncompressedsize := StoredUSize;
    start.filenamelength := Length(EncodedName);
    start.extrafieldlength := Length(Z64Extra);

    add.filename := string(EncodedName);
    if NeedsZ64 then
      add.extrafield := ZipFile.UTF8.BytesToStr(Z64Extra)
    else
      add.extrafield := '';
  end;
end;

// v4.1: raw-DEFLATE writers — bypass cgsCompressZLib (zlib-wrapped) and emit
// raw deflate bitstream consumable by TZipEntryDeflateReadStream (WindowBits=-15).
// Used by TZipFile.AppendStream when Compression = cmMaximal.
{$IFDEF FPC}
procedure DeflateRawCompressFPC(Source, Dest: TStream);
var
  Z: zstream.TCompressionStream;
  Buf: array[0..65535] of Byte;
  N: Integer;
begin
  Source.Position := 0;
  // paszlib: 3rd arg ASkipHeader=True -> raw deflate (no zlib header/trailer).
  Z := zstream.TCompressionStream.Create(zstream.clmax, Dest, True);
  try
    while True do
    begin
      N := Source.Read(Buf, SizeOf(Buf));
      if N <= 0 then Break;
      Z.WriteBuffer(Buf, N);
    end;
  finally
    Z.Free;  // flushes pending deflate bits to Dest before freeing
  end;
  Dest.Position := 0;  // reset for downstream CopyFrom
end;
{$ELSE}
procedure DeflateRawCompressDelphi(Source, Dest: TStream);
var
  Z: ZLib.TZCompressionStream;
  Buf: array[0..65535] of Byte;
  N: Integer;
begin
  Source.Position := 0;
  // Delphi System.ZLib: 3rd arg windowBits=-15 -> raw deflate (no zlib wrapper).
  Z := ZLib.TZCompressionStream.Create(Dest, ZLib.zcMax, -15);
  try
    while True do
    begin
      N := Source.Read(Buf, SizeOf(Buf));
      if N <= 0 then Break;
      Z.WriteBuffer(Buf, N);
    end;
  finally
    Z.Free;  // flushes pending deflate bits to Dest before freeing
  end;
  Dest.Position := 0;  // reset for downstream CopyFrom
end;
{$ENDIF}

procedure TZipFile.AppendStream(Stream: TStream; ZIPFileName: string; FileDateTime: TDateTime);
var
  localoffset: longword;
  count: longint;
  i: longword;
  lfh: TLocalFileHeader;
  crc32: cardinal;
{$IFNDEF FPC}
  RawName, RawExtra, RawComment: RawByteString;
{$ENDIF}
  lCompressed : TMemoryStream ;
  lCompress : TtiCompressAbs ;
  // v2.1: LZMA (PKWARE method 14)
  LDoLZMA: Boolean;
  LPlain: TBytes;
  LZmaPayload, LZmaProps: TBytes;
  LZmaTotalSize: Int64;
  LByteMaj, LByteMin: Byte;
  LWordPropSize: Word;
  // v2.0: AES-256 WinZip-AE-2 support
  LDoAES: Boolean;
  LSalt: array[0..ZipFile.Encryption.AES.AES256_SALT_SIZE - 1] of Byte;
  LEncKey, LAuthKey: ZipFile.Encryption.AES.TAESKey256;
  LPwdVerify: array[0..ZipFile.Encryption.AES.WINZIP_AE_PWD_VERIFY_BYTES - 1] of Byte;
  LExpanded: ZipFile.Encryption.AES.TAESExpandedKey;
  LCipherData: TBytes;
  LHmacTag: TBytes;
  LAESExtra: RawByteString;
  LRealMethod: Word;
  LOriginalUSize: Int64;
  LFinalCompressedSize: Int64;
begin
  LDoLZMA := FUseLZMA;
  LDoAES := FUseAES and (FPassword <> '');
  if LDoLZMA and LDoAES then
    raise EZipLZMAError.Create('UseLZMA + UseAES combined not supported in v2.1.');
  crc32 := GetStreamCrc32(Stream);
  lfh := MakeLocalFileHeader(ZIPFileName, Stream.Size, crc32, FileDateTime);
  localoffset := endofcdrecord.start.cdoffset;
  AddCDFileHeader(Stream.Size, ZIPFileName, localoffset, SizeOf(lfh.start), crc32, FileDateTime);

  //compress data — pick path based on FCompression property.
  // v4.1: TZipFile.AppendStream now honors Compression := cmMaximal
  // (was hardcoded to cgsCompressNone, ignoring user setting — bug
  // detected by smoke_streaming_deflate.dpr).
  // For DEFLATE (cmMaximal) we use TZCompressionStream with WindowBits=-15
  // which produces RAW DEFLATE (no zlib header/trailer) — exactly what
  // ZIP entries require per PKWARE APPNOTE §4.4.5 and what the matching
  // TZipEntryDeflateReadStream reader (WindowBits=-15) expects.
  lCompressed := TMemoryStream.Create;
  try
    if FCompression = cmMaximal then
    begin
      Stream.Position := 0;
      {$IFDEF FPC}
      // FPC paszlib: TCompressionStream(Level, Dest, SkipHeader=True) -> raw deflate
      DeflateRawCompressFPC(Stream, lCompressed);
      {$ELSE}
      // Delphi System.ZLib: WindowBits=-15 selects raw deflate
      DeflateRawCompressDelphi(Stream, lCompressed);
      {$ENDIF}
    end
    else
    begin
      lCompress := gCompressFactory.CreateInstance(cgsCompressNone);
      try
        lCompress.CompressStream(Stream, lCompressed);
      finally
        lCompress.Free;
      end;
    end;
  finally
  end;

  //update lfh — record actual method (8=DEFLATE if cmMaximal, 0=Store otherwise).
  // Method/version mutations must also be applied to the matching CD entry
  // (fileheaderlist) to keep LFH and CDH consistent on disk. EOCDR
  // cdoffset accounting must absorb the delta between Stream.Size (assumed
  // by AddCDFileHeader) and lCompressed.Size (actual bytes on disk).
  lfh.start.compressedsize := lCompressed.Size;
  if FCompression = cmMaximal then
  begin
    lfh.start.compressmethod := 8;       // DEFLATE
    lfh.start.extractversion := $0014;   // PKWARE 2.0 (DEFLATE requires >=2.0)
    with fileheaderlist[Pred(fileheadercount)] do
    begin
      start.compressionmethod := 8;
      if start.versiontoextract < $0014 then start.versiontoextract := $0014;
      start.compressedsize := lCompressed.Size;
    end;
    FEntryCSize64[Pred(fileheadercount)] := lCompressed.Size;
    // Fix EOCDR cdoffset: AddCDFileHeader incremented assuming uncompressed
    // size. Apply the delta now (negative when DEFLATE shrinks the entry).
    Inc(endofcdrecord.start.cdoffset, lCompressed.Size - Stream.Size);
    Inc(FZip64CDOffset, lCompressed.Size - Stream.Size);
  end;

  // ===== v2.1: LZMA wrap (PKWARE method 14, APPNOTE 5.8.8) =====
  if LDoLZMA then
  begin
    SetLength(LPlain, lCompressed.Size);
    if lCompressed.Size > 0 then
      Move(PByte(lCompressed.Memory)^, LPlain[0], lCompressed.Size);
    // Compress (raises EZipLZMANotSupportedOnPlatform on Win64/FPC)
    ZipFile.Compression.LZMA.LzmaCompressBuffer(LPlain, Length(LPlain), LZmaPayload, LZmaProps, 5);
    // PKWARE LZMA header: 2 bytes SDK version (major/minor) + 2 bytes props
    // size (LE, always 5) + 5 bytes encoded props + LZMA bitstream.
    lCompressed.Clear;
    // FPC/Delphi cross-compat: TStream.WriteBuffer existe em ambos;
    // WriteData e exclusivo Delphi modern.
    LByteMaj := 20;                                                   // major version (LZMA SDK 2.x)
    LByteMin := 7;                                                    // minor version
    LWordPropSize := ZipFile.Compression.LZMA.LZMA_PROPS_SIZE;
    lCompressed.WriteBuffer(LByteMaj, 1);
    lCompressed.WriteBuffer(LByteMin, 1);
    lCompressed.WriteBuffer(LWordPropSize, 2);
    lCompressed.WriteBuffer(LZmaProps[0], ZipFile.Compression.LZMA.LZMA_PROPS_SIZE);
    if Length(LZmaPayload) > 0 then
      lCompressed.WriteBuffer(LZmaPayload[0], Length(LZmaPayload));
    LZmaTotalSize := lCompressed.Size;
    lCompressed.Position := 0;
    // Mutate LFH: method 14, extractversion 6.3 (= 63 decimal)
    lfh.start.compressmethod := 14;
    lfh.start.extractversion := 63;
    lfh.start.compressedsize := LZmaTotalSize;
    // Mutate matching CDH entry
    with fileheaderlist[Pred(fileheadercount)] do
    begin
      start.compressionmethod := 14;
      start.versiontoextract := 63;
      start.compressedsize := LZmaTotalSize;
    end;
    // Fix EOCDH accounting: original cdoffset add was Stream.Size; real is LZmaTotalSize.
    Inc(endofcdrecord.start.cdoffset, LZmaTotalSize - Stream.Size);
    Inc(FZip64CDOffset, LZmaTotalSize - Stream.Size);
    // Update shadow Int64 size; ZIP64 extra field on disk still holds the
    // original size estimate (acceptable since reader rebuilds via cdoffset).
    FEntryCSize64[Pred(fileheadercount)] := LZmaTotalSize;
  end;

  // ===== v2.0: AES-256 WinZip-AE-2 encryption wrap =====
  if LDoAES then
  begin
    LRealMethod := lfh.start.compressmethod;   // remember actual method (0 = Store)
    LOriginalUSize := Stream.Size;
    // 1. Generate random salt
    RandomizeSalt(LSalt);
    // 2. Derive keys via PBKDF2(password, salt, 1000)
    ZipFile.Encryption.AES.DeriveAEKeys(RawByteString(FPassword), LSalt, LEncKey, LAuthKey, LPwdVerify);
    // 3. Encrypt compressed data with AES-256-CTR (counter starts at 1)
    SetLength(LCipherData, lCompressed.Size);
    if lCompressed.Size > 0 then
      Move(PByte(lCompressed.Memory)^, LCipherData[0], lCompressed.Size);
    ZipFile.Encryption.AES.AES256ExpandKey(LEncKey, LExpanded);
    ZipFile.Encryption.AES.AES256CtrXor(LExpanded, LCipherData, Length(LCipherData), 1);
    // 4. Build HMAC-SHA1 truncated to 10 bytes over ciphertext
    LHmacTag := ZipFile.Encryption.AES.HmacAuthTag(LAuthKey, LCipherData, Length(LCipherData));
    // 5. Replace lCompressed payload with: salt | pwd_verify | ciphertext | hmac
    lCompressed.Clear;
    lCompressed.WriteBuffer(LSalt[0], ZipFile.Encryption.AES.AES256_SALT_SIZE);
    lCompressed.WriteBuffer(LPwdVerify[0], ZipFile.Encryption.AES.WINZIP_AE_PWD_VERIFY_BYTES);
    if Length(LCipherData) > 0 then
      lCompressed.WriteBuffer(LCipherData[0], Length(LCipherData));
    lCompressed.WriteBuffer(LHmacTag[0], ZipFile.Encryption.AES.WINZIP_AE_HMAC_TRAILER);
    LFinalCompressedSize := lCompressed.Size;
    lCompressed.Position := 0;  // CopyFrom reads from current position
    // 6. Build 11-byte extra field 0x9901
    LAESExtra := BuildAESExtraField(LRealMethod);
    // 7. Mutate LFH: method=99, gpbit |= 0x0001, crc=0 (AE-2), add extra
    lfh.start.compressmethod := ZipFile.Encryption.AES.WINZIP_AES_METHOD;
    lfh.start.generalpurposebit := lfh.start.generalpurposebit or ZipFile.Encryption.AES.GP_FLAG_ENCRYPTED;
    lfh.start.crc32 := 0;
    lfh.start.compressedsize := LFinalCompressedSize;
    lfh.start.uncompressedsize := LOriginalUSize;
    lfh.start.extrafieldlength := Length(LAESExtra);
    lfh.add.extrafield := ZipFile.UTF8.BytesToStr(LAESExtra);
    // 8. Mutate matching CDH entry the same way
    with fileheaderlist[Pred(fileheadercount)] do
    begin
      start.compressionmethod := ZipFile.Encryption.AES.WINZIP_AES_METHOD;
      start.generalpurposebit := start.generalpurposebit or ZipFile.Encryption.AES.GP_FLAG_ENCRYPTED;
      start.crc32 := 0;
      start.compressedsize := LFinalCompressedSize;
      start.uncompressedsize := LOriginalUSize;
      start.extrafieldlength := Length(LAESExtra);
      add.extrafield := ZipFile.UTF8.BytesToStr(LAESExtra);
    end;
    // 9. Fix the EOCDH accounting: AddCDFileHeader assumed Store with no extra,
    //    so we add the extra-field bytes (LFH + CDH) and the cipher-vs-plain delta.
    Inc(endofcdrecord.start.sizeofthecentraldirectory, Length(LAESExtra));         // CDH extra
    Inc(FZip64CDSize, Length(LAESExtra));
    Inc(endofcdrecord.start.cdoffset, Length(LAESExtra));                          // LFH extra
    Inc(FZip64CDOffset, Length(LAESExtra));
    Inc(endofcdrecord.start.cdoffset, LFinalCompressedSize - LOriginalUSize);      // payload delta
    Inc(FZip64CDOffset, LFinalCompressedSize - LOriginalUSize);
    FEntryCSize64[Pred(fileheadercount)] := LFinalCompressedSize;
  end;
  // ===== end AES wrap =====

  //write local file header
  fs.Seek(localoffset, soFromBeginning);
  fs.WriteBuffer(lfh.start, SizeOf(lfh.start));

  //write local file header additional parameters
  {$IFDEF FPC}
  fs.WriteBuffer(lfh.add.filename[1], Length(lfh.add.filename));
  fs.WriteBuffer(lfh.add.extrafield[1], Length(lfh.add.extrafield));
  {$ELSE}
  // Delphi: emit raw bytes; re-encode filename per bit 11 of GP flag.
  RawName := ZipFile.UTF8.EncodeFilename(lfh.add.filename, ZipFile.UTF8.IsUtf8Flagged(lfh.start.generalpurposebit));
  if Length(RawName) > 0 then
    fs.WriteBuffer(RawName[1], Length(RawName));
  RawExtra := ZipFile.UTF8.StrToBytes(lfh.add.extrafield);
  if Length(RawExtra) > 0 then
    fs.WriteBuffer(RawExtra[1], Length(RawExtra));
  {$ENDIF}

  //write local file data (chunked to enable OnProgress callback)
  if Assigned(FOnProgress) then
  begin
    lCompressed.Position := 0;
    DoProgressChunkedCopy(lCompressed, fs, lCompressed.Size);
  end
  else
    fs.CopyFrom(lCompressed, lCompressed.Size);

  lCompressed.Free;

  //write CD
  for i := 0 to Pred(fileheadercount) do
  begin
    count := SizeOf(fileheaderlist[i].start);
    fs.WriteBuffer(fileheaderlist[i].start, count);
    {$IFDEF FPC}
    fs.WriteBuffer(fileheaderlist[i].add.filename[1], Length(fileheaderlist[i].add.filename));
    fs.WriteBuffer(fileheaderlist[i].add.extrafield[1], Length(fileheaderlist[i].add.extrafield));
    fs.WriteBuffer(fileheaderlist[i].add.filecomment[1], Length(fileheaderlist[i].add.filecomment));
    {$ELSE}
    RawName := ZipFile.UTF8.EncodeFilename(fileheaderlist[i].add.filename, ZipFile.UTF8.IsUtf8Flagged(fileheaderlist[i].start.generalpurposebit));
    if Length(RawName) > 0 then
      fs.WriteBuffer(RawName[1], Length(RawName));
    RawExtra := ZipFile.UTF8.StrToBytes(fileheaderlist[i].add.extrafield);
    if Length(RawExtra) > 0 then
      fs.WriteBuffer(RawExtra[1], Length(RawExtra));
    RawComment := ZipFile.UTF8.StrToBytes(fileheaderlist[i].add.filecomment);
    if Length(RawComment) > 0 then
      fs.WriteBuffer(RawComment[1], Length(RawComment));
    {$ENDIF}
  end;

  // v2.3: ZIP64 archive-level emission — if any trigger fired, write the
  // ZIP64 EOCD Record + ZIP64 EOCD Locator right BEFORE the standard EOCD,
  // and clamp the standard EOCD fields to sentinel values where they
  // overflow 16/32-bit limits.
  if FForceZip64
     or (FZip64TotalEntries > Int64(ZipFile.ZIP64.ZIP64_MAGIC_16))
     or (FZip64CDSize >= Int64(ZipFile.ZIP64.ZIP64_MAGIC_32))
     or (FZip64CDOffset >= Int64(ZipFile.ZIP64.ZIP64_MAGIC_32)) then
  begin
    EmitZip64EocdAndLocator;
    // Clamp the standard EOCDR fields so ZIP64-aware readers know to
    // consult the ZIP64 record. Older readers still see consistent
    // (sentinel) values without crashing.
    if FZip64TotalEntries > Int64(ZipFile.ZIP64.ZIP64_MAGIC_16) then
    begin
      endofcdrecord.start.numberofcdentries := ZipFile.ZIP64.ZIP64_MAGIC_16;
      endofcdrecord.start.totalnumberofcdentries := ZipFile.ZIP64.ZIP64_MAGIC_16;
    end;
    if FZip64CDSize >= Int64(ZipFile.ZIP64.ZIP64_MAGIC_32) then
      endofcdrecord.start.sizeofthecentraldirectory := ZipFile.ZIP64.ZIP64_MAGIC_32;
    if FZip64CDOffset >= Int64(ZipFile.ZIP64.ZIP64_MAGIC_32) then
      endofcdrecord.start.cdoffset := ZipFile.ZIP64.ZIP64_MAGIC_32;
  end;

  // v4.1 P54: emit ArchiveComment property into EOCDR ZIPfilecomment field
  // (PKWARE APPNOTE §4.3.16 — max 65535 bytes). Was declared but never
  // wired into the write path.
  if FArchiveComment <> '' then
  begin
    if Length(FArchiveComment) > 65535 then
      endofcdrecord.add.ZIPfilecomment := Copy(FArchiveComment, 1, 65535)
    else
      endofcdrecord.add.ZIPfilecomment := FArchiveComment;
    endofcdrecord.start.ZIPfilecommentlength := Word(Length(endofcdrecord.add.ZIPfilecomment));
  end;

  //write EOCDH
  count := SizeOf(endofcdrecord.start);
  fs.WriteBuffer(endofcdrecord.start, count);
  if Length(endofcdrecord.add.ZIPfilecomment) > 0 then
    fs.WriteBuffer(endofcdrecord.add.ZIPfilecomment[1], Length(endofcdrecord.add.ZIPfilecomment));

  if Assigned(FOnFileChanged) then FOnFileChanged(Self);
end;

procedure TZipFile.AppendFileFromDisk(AFileName, ZIPFileName: string);
var
  newfile: TFileStream;
  FileDateTime: TDateTime;
begin
  if not SysUtils.FileExists(AFileName) then
    raise EArchiveNotFound.Create(Format(rsZipFileSDoesNotExist, [AFileName]), ERR_ARCHIVE_NOT_FOUND);

  newfile := TFileStream.Create(AFileName,fmOpenRead);
  FileDateTime := FileDateToDateTime(FileAge(AFileName));

  AppendStream(newfile, ZIPFileName, FileDateTime);
  
  newfile.Free;
end;

function TZipFile.GetStreamCrc32(Stream: TStream): longword;
var
  pos: Int64;
  buf: Pbyte;
  buflen: longword;
begin
  pos := Stream.Position;
  Stream.Position := 0;

  GetMem(buf, 1024);

  Result := crc32(0,nil,0);
  repeat
    buflen := Stream.Read(buf^, 1024);
    Result := crc32(Result, buf, buflen);
  until buflen <> SizeOf(buf);

  FreeMem(buf);
  
  Stream.Position := pos;
end;

procedure TZipFile.DeleteFile(AFileName: string);
var
  index: longword;
  i: longword;
  startbuf: longword;
  endbuf: longword;
  frompos: longword;
  topos: longword;
  buflen: longword;
  buf: Pbyte;
  cditemsize: longword;
{$IFNDEF FPC}
  RawName, RawExtra, RawComment: RawByteString;
{$ENDIF}
begin
  index := FileNameIndex(AFileName);

  if (index < 0) or (index > Pred(fileheadercount)) then
    raise EArchiveEntryNotFound.Create(Format(rsFilenameSDoesNotExistInS, [AFileName, FileName]), ERR_ARCHIVE_ENTRY_NOT_FOUND);

  startbuf := fileheaderlist[index].start.reloffsetlocalheader;
  if index = Pred(fileheadercount) then
    endbuf := endofcdrecord.start.cdoffset
  else
    endbuf := fileheaderlist[Succ(index)].start.reloffsetlocalheader;
    
  //move local file headers on disk
  if index <> Pred(fileheadercount) then
  begin
    GetMem(buf, 1024);
    frompos := endbuf;
    topos := startbuf;
    repeat
      fs.Seek(frompos, soFromBeginning);
      buflen := fs.Read(buf^, Min(fs.Size - frompos, 1024));

      fs.Seek(topos, soFromBeginning);
      fs.Write(buf^, buflen);
      
      Inc(frompos, buflen);
      Inc(topos, buflen);
    until buflen < 1024;
    FreeMem(buf);
  end;

  //calculate new offsets for all CD
  if index <> Pred(fileheadercount) then
    for i:= Succ(index) to Pred(fileheadercount) do
      Dec(fileheaderlist[i].start.reloffsetlocalheader, endbuf - startbuf);

  //get size of deleted CD item
  cditemsize := SizeOf(fileheaderlist[index].start) +
                fileheaderlist[index].start.filenamelength +
                fileheaderlist[index].start.extrafieldlength +
                fileheaderlist[index].start.filecommentlength;

  //delete CD
  for i:= Succ(index) to Pred(fileheadercount) do
    fileheaderlist[Pred(i)] := fileheaderlist[i];
  Dec(fileheadercount);
  SetLength(fileheaderlist, fileheadercount);

  //calculate new values for EOCDH
  Dec(endofcdrecord.start.cdoffset, endbuf - startbuf);
  Dec(endofcdrecord.start.numberofcdentries);
  Dec(endofcdrecord.start.totalnumberofcdentries);
  Dec(endofcdrecord.start.sizeofthecentraldirectory, cditemsize);

  //write CD to disk
  fs.Seek(endofcdrecord.start.cdoffset, soFromBeginning);
  if fileheadercount <> 0 then
    for i:= 0 to Pred(fileheadercount) do
    begin
      fs.WriteBuffer(fileheaderlist[i].start, SizeOf(fileheaderlist[i].start));
      {$IFDEF FPC}
      fs.WriteBuffer(fileheaderlist[i].add.filename[1], fileheaderlist[i].start.filenamelength);
      fs.WriteBuffer(fileheaderlist[i].add.extrafield[1], fileheaderlist[i].start.extrafieldlength);
      fs.WriteBuffer(fileheaderlist[i].add.filecomment[1], fileheaderlist[i].start.filecommentlength);
      {$ELSE}
      RawName := ZipFile.UTF8.EncodeFilename(fileheaderlist[i].add.filename, ZipFile.UTF8.IsUtf8Flagged(fileheaderlist[i].start.generalpurposebit));
      if Length(RawName) > 0 then
        fs.WriteBuffer(RawName[1], Length(RawName));
      RawExtra := ZipFile.UTF8.StrToBytes(fileheaderlist[i].add.extrafield);
      if Length(RawExtra) > 0 then
        fs.WriteBuffer(RawExtra[1], Length(RawExtra));
      RawComment := ZipFile.UTF8.StrToBytes(fileheaderlist[i].add.filecomment);
      if Length(RawComment) > 0 then
        fs.WriteBuffer(RawComment[1], Length(RawComment));
      {$ENDIF}
    end;

  //write EOCDH
  fs.WriteBuffer(endofcdrecord.start, SizeOf(endofcdrecord.start));

  //overwrite the ZipFile comment
  fs.WriteBuffer(endofcdrecord.add.ZIPfilecomment[1], endofcdrecord.start.ZIPfilecommentlength);

  //truncate file
  fs.Size := fs.Size - cditemsize - endbuf + startbuf;

  if Assigned(FOnFileChanged) then FOnFileChanged(Self);
end;

procedure TZipFile.UpdateFile(Stream: TStream; ZIPFileName: string);
begin
  if FileExists(ZIPFileName) then
    DeleteFile(ZIPFileName);
  AppendStream(Stream, ZIPFileName, Now);
end;

function TZipFile.Report: TStrings;
var
  i: integer;
begin
  Result := TStringList.Create;

  Result.Add(Format('Archive: %s',[FileName]));
  Result.Add('');
  Result.Add('');
  Result.Add('Local file headers  (note: current implementation only finds LFH''s through CDFH)');
  Result.Add('------------------');
  Result.Add('');
  Result.Add(Format('Number of entries: %d',[fileheadercount]));
  Result.Add('');

  for i := 0 to Pred(fileheadercount) do
    Result.AddStrings(ShowLocalFileHeaderReport(i));

  Result.Add('');
  Result.Add('File headers');
  Result.Add('------------');
  Result.Add('');
  Result.Add(Format('Number of entries: %d',[fileheadercount]));
  Result.Add('');

  for i := 0 to Pred(fileheadercount) do
    Result.AddStrings(ShowCDFileHeaderReport(i));

  Result.Add('');
  Result.Add('');
  Result.Add('End of central directory record:');
  Result.Add('--------------------------------');
  Result.Add('');
  Result.AddStrings(ShowEndOfCDRecordReport);
end;

function TZipFile.ShowLocalFileHeaderReport(index: longword): TStrings;
var
  lfh: TLocalFileHeader;
  s: string;
  o: string;
begin
  Result := TStringList.Create;

  lfh := ReadLocalFileHeader(FileHeaderList[index].start.reloffsetlocalheader);

  s := IntToStr(Succ(index));
  o := DupeString(' ', Length(s));
  with Result do
  begin
    Add(Format('%s. signature        : $%.8x', [s, lfh.start.signature]));
    Add(Format('%s  extractversion   : %d', [o, lfh.start.extractversion]));
    Add(Format('%s  bitflag          : $%.4x', [o, lfh.start.generalpurposebit]));
    Add(Format('%s  compressmethod   : %d', [o, lfh.start.compressmethod]));
    Add(Format('%s  lastmodtime      : %d', [o, lfh.start.lastmodtime]));
    Add(Format('%s  lastmoddate      : %d', [o, lfh.start.lastmoddate]));
    Add(Format('%s  crc32            : $%.8x', [o, lfh.start.crc32]));
    Add(Format('%s  compressedsize   : %d', [o, lfh.start.compressedsize]));
    Add(Format('%s  uncompressedsize : %d', [o, lfh.start.uncompressedsize]));
    Add(Format('%s  filenamelength   : %d', [o, lfh.start.filenamelength]));
    Add(Format('%s  extrafieldlength : %d', [o, lfh.start.extrafieldlength]));
    Add(Format('%s  filename         : %s', [o, lfh.add.filename]));
    Add(Format('%s  extra field      : %s', [o, lfh.add.extrafield]));
  end;
end;

function TZipFile.ShowEndOfCDRecordReport: TStrings;
begin
  Result := TStringList.Create;

  with Result do
  begin
    Add(Format('endofcentraldirsignature  : $%.8x', [endofcdrecord.start.endofcentraldirsignature]));
    Add(Format('numberofthisdisk          : %d', [endofcdrecord.start.numberofthisdisk]));
    Add(Format('numberofthisdiskwithcd    : %d', [endofcdrecord.start.numberofthisdiskwithcd]));
    Add(Format('numberofcdentries         : %d', [endofcdrecord.start.numberofcdentries]));
    Add(Format('totalnumberofcdentries    : %d', [endofcdrecord.start.totalnumberofcdentries]));
    Add(Format('sizeofthecentraldirectory : %d', [endofcdrecord.start.sizeofthecentraldirectory]));
    Add(Format('cdoffset                  : %d', [endofcdrecord.start.cdoffset]));
    Add(Format('ZIPfilecommentlength      : %d', [endofcdrecord.start.ZIPfilecommentlength]));
    Add(Format('ZIPfilecomment            : %s', [endofcdrecord.add.ZIPfilecomment]))
  end;
end;

function TZipFile.ShowCDFileHeaderReport(index: longword): TStrings;
var
  s: string;
  o: string;
begin
  Result := TStringList.Create;

  if (index < 0) or (index >= fileheadercount) then
    Raise EArchiveEntryNotFound.Create('fileheader index out of bounds!', ERR_ARCHIVE_ENTRY_NOT_FOUND);

  s := IntToStr(Succ(index));
  o := DupeString(' ', Length(s));
  with FileHeaderList[index] do
  begin
    Result.Add(Format('%s. signature              : $%.8x', [s, start.signature]));
    Result.Add(Format('%s  versionmadeby          : $%.4x', [o, start.versionmadeby]));
    Result.Add(Format('%s  versiontoextract       : $%.4x', [o, start.versiontoextract]));
    Result.Add(Format('%s  generalpurposebit      : $%.4x', [o, start.generalpurposebit]));
    Result.Add(Format('%s  compressionmethod      : $%.4x', [o, start.compressionmethod]));
    Result.Add(Format('%s  lastmodfiletime        : $%.4x', [o, start.lastmodfiletime]));
    Result.Add(Format('%s  lastmodfiledate        : $%.4x', [o, start.lastmodfiledate]));
    Result.Add(Format('%s  crc32                  : $%.8x', [o, start.crc32]));
    Result.Add(Format('%s  compressedsize         : %d', [o, start.compressedsize]));
    Result.Add(Format('%s  uncompressedsize       : %d', [o, start.uncompressedsize]));
    Result.Add(Format('%s  filenamelength         : %d', [o, start.filenamelength]));
    Result.Add(Format('%s  extrafieldlength       : %d', [o, start.extrafieldlength]));
    Result.Add(Format('%s  filecommentlength      : %d', [o, start.filecommentlength]));
    Result.Add(Format('%s  disknumberstart        : %d', [o, start.disknumberstart]));
    Result.Add(Format('%s  internalfileattributes : %d', [o, start.internalfileattributes]));
    Result.Add(Format('%s  externalfileattributed : %d', [o, start.externalfileattributed]));
    Result.Add(Format('%s  reloffsetlocalheader   : %d', [o, start.reloffsetlocalheader]));
    Result.Add(Format('%s  filename               : %s', [o, add.filename]));
    Result.Add(Format('%s  extrafield             : %s', [o, add.extrafield]));
    Result.Add(Format('%s  filecomment            : %s', [o, add.filecomment]));
  end;
end;

{ ============================================================================
  Fluent builder + factory — relocated from former ZipFile.Fluent.pas (dissolved
  per backend-pascal-unit-naming_V1.6.0 §2; interface in companion .Interfaces.pas).
  ============================================================================ }

constructor TZipFileBuilder.CreateNew(const APath: string);
begin
  inherited Create;
  FArchivePath := APath;
  FOpenForUpdate := False;
  if SysUtils.FileExists(APath) then
    SysUtils.DeleteFile(APath);
end;

constructor TZipFileBuilder.CreateOpen(const APath: string);
begin
  inherited Create;
  FArchivePath := APath;
  FOpenForUpdate := True;
end;

function TZipFileBuilder.WithUtf8(AEnable: Boolean): IZipFileBuilder;
begin
  FUseUtf8 := AEnable;
  Result := Self;
end;

function TZipFileBuilder.WithAES(const APassword: string): IZipFileBuilder;
begin
  FUseAES := True;
  FPassword := APassword;
  Result := Self;
end;

function TZipFileBuilder.WithPassword(const APassword: string): IZipFileBuilder;
begin
  FPassword := APassword;
  Result := Self;
end;

function TZipFileBuilder.WithLZMA(AEnable: Boolean): IZipFileBuilder;
begin
  FUseLZMA := AEnable;
  Result := Self;
end;

function TZipFileBuilder.WithForceZip64(AEnable: Boolean): IZipFileBuilder;
begin
  FForceZip64 := AEnable;
  Result := Self;
end;

function TZipFileBuilder.WithCompression(AMethod: TCompressionMethod): IZipFileBuilder;
begin
  FCompression := AMethod;
  FCompressionSet := True;
  Result := Self;
end;

function TZipFileBuilder.WithReCompression(AMethod: TReCompressionMethod): IZipFileBuilder;
begin
  FReCompression := AMethod;
  FReCompressionSet := True;
  Result := Self;
end;

function TZipFileBuilder.OnProgress(AEvent: TZipProgressEvent): IZipFileBuilder;
begin
  FOnProgress := AEvent;
  Result := Self;
end;

function TZipFileBuilder.OnArchiveChanged(AEvent: TFileChangedEvent): IZipFileBuilder;
begin
  FOnArchiveChanged := AEvent;
  Result := Self;
end;

function TZipFileBuilder.AppendStream(AStream: TStream; const AZipName: string;
                                      AOwnStream: Boolean): IZipFileBuilder;
var
  Idx: Integer;
begin
  Idx := Length(FItems);
  SetLength(FItems, Idx + 1);
  FItems[Idx].Kind := zbkStream;
  FItems[Idx].ZipName := AZipName;
  FItems[Idx].Stream := AStream;
  FItems[Idx].OwnStream := AOwnStream;
  Result := Self;
end;

function TZipFileBuilder.AppendFile(const ADiskFileName, AZipName: string): IZipFileBuilder;
var
  Idx: Integer;
begin
  Idx := Length(FItems);
  SetLength(FItems, Idx + 1);
  FItems[Idx].Kind := zbkFile;
  FItems[Idx].ZipName := AZipName;
  FItems[Idx].DiskFileName := ADiskFileName;
  Result := Self;
end;

function TZipFileBuilder.DeleteEntry(const AZipName: string): IZipFileBuilder;
var
  Idx: Integer;
begin
  Idx := Length(FItems);
  SetLength(FItems, Idx + 1);
  FItems[Idx].Kind := zbkDelete;
  FItems[Idx].ZipName := AZipName;
  Result := Self;
end;

function TZipFileBuilder.UpdateEntry(AStream: TStream; const AZipName: string;
                                     AOwnStream: Boolean): IZipFileBuilder;
var
  Idx: Integer;
begin
  Idx := Length(FItems);
  SetLength(FItems, Idx + 1);
  FItems[Idx].Kind := zbkUpdate;
  FItems[Idx].ZipName := AZipName;
  FItems[Idx].Stream := AStream;
  FItems[Idx].OwnStream := AOwnStream;
  Result := Self;
end;

procedure TZipFileBuilder.ApplySettings(AZip: TZipFile);
begin
  AZip.UseUtf8     := FUseUtf8;
  AZip.UseAES      := FUseAES;
  AZip.Password    := FPassword;
  AZip.UseLZMA     := FUseLZMA;
  AZip.ForceZip64  := FForceZip64;
  if FCompressionSet   then AZip.Compression   := FCompression;
  if FReCompressionSet then AZip.ReCompression := FReCompression;
  if Assigned(FOnProgress)       then AZip.OnProgress    := FOnProgress;
  if Assigned(FOnArchiveChanged) then AZip.OnFileChanged := FOnArchiveChanged;
end;

procedure TZipFileBuilder.Execute;
var
  ZipObj: TZipFile;
  I: Integer;
begin
  ZipObj := TZipFile.Create(nil);
  try
    ZipObj.FileName := FArchivePath;
    ApplySettings(ZipObj);
    ZipObj.Active := True;
    for I := 0 to High(FItems) do
    begin
      case FItems[I].Kind of
        zbkStream:
          try
            ZipObj.AppendStream(FItems[I].Stream, FItems[I].ZipName, Now);
          finally
            if FItems[I].OwnStream then
              FreeAndNil(FItems[I].Stream);
          end;
        zbkFile:
          ZipObj.AppendFileFromDisk(FItems[I].DiskFileName, FItems[I].ZipName);
        zbkDelete:
          ZipObj.DeleteFile(FItems[I].ZipName);
        zbkUpdate:
          try
            ZipObj.UpdateFile(FItems[I].Stream, FItems[I].ZipName);
          finally
            if FItems[I].OwnStream then
              FreeAndNil(FItems[I].Stream);
          end;
      end;
    end;
  finally
    ZipObj.Free;
  end;
  SetLength(FItems, 0);
end;

function TZipFileBuilder.ExtractStream(const AZipName: string): TStream;
var
  ZipObj: TZipFile;
  EntryStm: TStream;
  Mem: TMemoryStream;
begin
  ZipObj := TZipFile.Create(nil);
  try
    ZipObj.FileName := FArchivePath;
    ApplySettings(ZipObj);
    ZipObj.Active := True;
    EntryStm := ZipObj.GetEntryStream(AZipName);
    try
      Mem := TMemoryStream.Create;
      try
        Mem.CopyFrom(EntryStm, EntryStm.Size);
        Mem.Position := 0;
        Result := Mem;
      except
        Mem.Free;
        raise;
      end;
    finally
      EntryStm.Free;
    end;
  finally
    ZipObj.Free;
  end;
end;

function TZipFileBuilder.HasEntry(const AZipName: string): Boolean;
var
  ZipObj: TZipFile;
begin
  ZipObj := TZipFile.Create(nil);
  try
    ZipObj.FileName := FArchivePath;
    ApplySettings(ZipObj);
    ZipObj.Active := True;
    Result := ZipObj.FileExists(AZipName);
  finally
    ZipObj.Free;
  end;
end;

function TZipFileBuilder.CountEntries: Cardinal;
var
  ZipObj: TZipFile;
begin
  ZipObj := TZipFile.Create(nil);
  try
    ZipObj.FileName := FArchivePath;
    ApplySettings(ZipObj);
    ZipObj.Active := True;
    Result := ZipObj.FileCount;
  finally
    ZipObj.Free;
  end;
end;

class function Zip.NewArchive(const APath: string): IZipFileBuilder;
begin
  Result := TZipFileBuilder.CreateNew(APath);
end;

class function Zip.OpenArchive(const APath: string): IZipFileBuilder;
begin
  Result := TZipFileBuilder.CreateOpen(APath);
end;

initialization
  { Registo design-time do componente (icone da palette). O ficheiro
    tZipFile.lrs NAO existe nem no SSOT ZipFileORM - residuo herdado que
    quebrava QUALQUER build LCL, porque o lazbuild define LCL. Guard proprio
    ZIPFILE_LCL_COMPONENT_RES: reactivar apenas se o .lrs for criado. }
  {$IFDEF FPC}{$IFDEF ZIPFILE_LCL_COMPONENT_RES}
  {$I tZipFile.lrs}
  {$ENDIF}{$ENDIF}

end.
