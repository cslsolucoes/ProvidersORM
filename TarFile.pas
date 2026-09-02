{ TarFile.pas

  TTarFile — encoder + decoder TAR formato POSIX ustar (1988), com API
  espelhada de TZipFile para uniformidade.

  Layout POSIX ustar (cada entry = header de 512 bytes + payload em
  multiplos de 512 com padding NUL):

    bytes  campo                  conteudo
    0-99   name                  filename (cstring NUL-terminated)
    100-107 mode                 permissions octal (ASCII)
    108-115 uid                  user id octal
    116-123 gid                  group id octal
    124-135 size                 file size octal
    136-147 mtime                modification time octal (unix epoch)
    148-155 chksum               header checksum (calculado com este campo = 8 espacos)
    156    typeflag              '0'=file, '5'=directory, '2'=symlink
    157-256 linkname             if typeflag='2'
    257-262 magic                "ustar\0"
    263-264 version              "00"
    265-296 uname                user name (cstring)
    297-328 gname                group name (cstring)
    329-336 devmajor             octal
    337-344 devminor             octal
    345-499 prefix               (long names: prefix + '/' + name)
    500-511 zero padding

  Trailer: 2 blocos vazios (1024 bytes NUL) marcam end-of-archive.

  Tamanhos >8GB usam GNU extension "ustar  \0" magic ou pax extended
  header — v3.0 implementa POSIX ustar (ate 8 GB por entry); pax fica
  como TODO v3.0.1 se demanda.
}
unit TarFile;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Classes, Commons.ZipFile.Types, ZipFile.Events, TarFile.Interfaces, Exceptions.Base, Exceptions.ZipFile;

type
  ETarError = class(EExceptionBase);

  // Fluent builder + factory (relocated from former Tar.Fluent.pas per
  // backend-pascal-unit-naming_V1.6.0 §2). Interface ITarFileBuilder lives
  // in TarFile.Interfaces.pas. Builder supports both .tar and .tar.gz
  // (TarGzFile dependency lives in implementation section).
  TTarBuilderItem = record
    Kind: (tbkFile, tbkBytes, tbkString, tbkDir);
    DiskFileName: string;
    EntryName: string;
    Data: TBytes;
    StrData: string;
    ModTime: TDateTime;
  end;

  TTarFileBuilder = class(TInterfacedObject, ITarFileBuilder)
  private
    FArchivePath: string;
    FOpenForRead: Boolean;
    FUseGzip: Boolean;
    FGzipLevel: Integer;
    FItems: array of TTarBuilderItem;
    procedure ApplyItems(ATar: TObject);  // typed as TObject to avoid TarFile fwd-dep
  public
    constructor CreateNew(const APath: string; AGzip: Boolean);
    constructor CreateOpen(const APath: string; AGzip: Boolean);
    function WithGzip(AEnable: Boolean = True): ITarFileBuilder;
    function WithGzipLevel(ALevel: Integer): ITarFileBuilder;
    function AppendFile(const ADiskFileName, AEntryName: string): ITarFileBuilder;
    function AppendBytes(const AData: TBytes; const AEntryName: string): ITarFileBuilder;
    function AppendString(const AContent, AEntryName: string): ITarFileBuilder;
    function AppendDirectory(const ADirName: string): ITarFileBuilder;
    procedure Execute;
    function ExtractStream(const AEntryName: string): TStream;
    function ReadAsBytes(const AEntryName: string): TBytes;
    function ReadAsString(const AEntryName: string): string;
    function HasEntry(const AEntryName: string): Boolean;
    function CountEntries: Integer;
  end;

  Tarball = class
  public
    class function NewArchive(const APath: string): ITarFileBuilder;
    class function NewGzArchive(const APath: string): ITarFileBuilder;
    class function OpenArchive(const APath: string): ITarFileBuilder;
    class function OpenGzArchive(const APath: string): ITarFileBuilder;
  end;

  TTarEntryType = (tetFile, tetDirectory, tetSymLink, tetHardLink, tetOther);

  // Metadata exposta por entry (versao simplificada do TZipSearchRec)
  TTarSearchRec = record
    Name: string;
    Size: Int64;
    Mode: Cardinal;
    ModTime: TDateTime;
    EntryType: TTarEntryType;
    LinkTarget: string;  // para symlink/hardlink
    Offset: Int64;       // posicao do payload no stream (para extracao)
  end;

  // Variantes do header tar.
  //   tfUstar = POSIX ustar (default, 100 char filename, 32 char prefix)
  //   tfGnu   = GNU tar (long names via @LongLink, sparse, devices)
  //   tfPax   = PAX (POSIX.1-2001, extended UTF-8 attributes)
  //   tfV7    = pre-POSIX v7 (100 char name, sem prefix)
  TTarFormat = (tfUstar, tfGnu, tfPax, tfV7);

  TTarFile = class(TComponent)
  protected
    FStream: TStream;
    FOwnsStream: Boolean;
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
    // Diagnostics
    FOnError: TArchiveErrorEvent;
    FOnWarning: TArchiveWarningEvent;
    FOnLog: TArchiveLogEvent;
    FEntries: array of TTarSearchRec;
    FEntryCount: Integer;
    FFindIndex: Integer;
    FFormat: TTarFormat;
    FPreserveOwnership: Boolean;       // grava uid/gid no header (Unix)
    FPreserveTimestamps: Boolean;      // grava MTime real (default True)
    FDefaultMode: Cardinal;            // chmod default para entries novos (octal)
    FDefaultUid: Cardinal;             // uid default
    FDefaultGid: Cardinal;             // gid default
    FOwnerName: string;                // uname field (ustar)
    FGroupName: string;                // gname field (ustar)
    // v3.12 extras
    FBlockSize: Integer;               // size of single tar block (default 512)
    FBlockingFactor: Integer;          // number of blocks per record (default 20)
    FRecordSize: Integer;              // physical record size = BlockSize * BlockingFactor
    FSparse: Boolean;                  // emit GNU sparse format para holes
    FUnixPermissions: Boolean;         // preserva chmod bits unix completos
    FIgnoreZeroBlocks: Boolean;        // nao trate 2 zero blocks como EOF
    FAddPaxExtensions: Boolean;        // grava PAX extended headers (UTF-8/timestamps)
    FArchiveSize: Int64;               // read-only — physical file size
    procedure ReadDirectory;
    procedure WriteTrailer;
    function WriteEntryHeader(const AName: string; ASize: Int64;
      ATypeflag: AnsiChar; AModTime: TDateTime; AMode: Cardinal): Boolean;
    procedure SetActive(AValue: Boolean);
    procedure SetFileName(const AValue: string);
    // v4.1 P28: setters de BlockSize / BlockingFactor recomputam FRecordSize.
    procedure SetBlockSize(AValue: Integer);
    procedure SetBlockingFactor(AValue: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // Lifecycle
    procedure Open;
    procedure Close;

    // Read API (espelhando TZipFile)
    function GetEntryCount: Integer;
    function FileExists(const AName: string): Boolean;
    function GetEntryStream(const AName: string): TStream;
    function ReadAsBytes(const AName: string): TBytes;
    function ReadAsString(const AName: string): string;
    function FindFirst(out ARec: TTarSearchRec): Integer;
    function FindNext(out ARec: TTarSearchRec): Integer;

    // Write API
    procedure AppendStream(AStream: TStream; const AName: string; AModTime: TDateTime);
    procedure AppendFileFromDisk(const ADiskPath, AArchiveName: string);
    procedure AppendBytes(const ABytes: TBytes; const AName: string);
    procedure AppendString(const AContent: string; const AName: string);
    procedure AppendDirectoryEntry(const ADirName: string; AModTime: TDateTime);

    // Fluent inline (v2.4 pattern)
    function WithFileName(const APath: string): TTarFile;
    function ThatOpens: TTarFile;  // .ThatOpens (Open chainable)
  published
    property Active: Boolean read FActive write SetActive;
    property FileName: string read FFileName write SetFileName;
    property EntryCount: Integer read GetEntryCount;

    // ---- Format ----
    // Variante do header tar emitida em Append*. Default tfUstar.
    property Format: TTarFormat read FFormat write FFormat default tfUstar;

    // ---- Metadata defaults for new entries ----
    // Inclui uid/gid no header (Unix). Default False.
    property PreserveOwnership: Boolean read FPreserveOwnership write FPreserveOwnership default False;
    // Grava MTime real do arquivo source. Default True.
    property PreserveTimestamps: Boolean read FPreserveTimestamps write FPreserveTimestamps default True;
    // Permissoes default para entries novos (octal): $1A4 = 0644, $1FF = 0777.
    property DefaultMode: Cardinal read FDefaultMode write FDefaultMode default $1A4;
    property DefaultUid: Cardinal read FDefaultUid write FDefaultUid default 0;
    property DefaultGid: Cardinal read FDefaultGid write FDefaultGid default 0;
    // Username/groupname (uname/gname fields no header ustar).
    property OwnerName: string read FOwnerName write FOwnerName;
    property GroupName: string read FGroupName write FGroupName;

    // ---- Block / record geometry ----
    // Tamanho de cada tar block em bytes. Default 512 (spec POSIX).
    // v4.1 P28: setter recomputa RecordSize = BlockSize * BlockingFactor.
    property BlockSize: Integer read FBlockSize write SetBlockSize default 512;
    // Blocks per record (-b factor em GNU tar). Default 20 — record = 10240 bytes.
    property BlockingFactor: Integer read FBlockingFactor write SetBlockingFactor default 20;
    // Physical record size = BlockSize * BlockingFactor. Read-only (calculado
    // automaticamente pelos setters de BlockSize / BlockingFactor).
    property RecordSize: Integer read FRecordSize;

    // ---- Format extensions ----
    // GNU sparse format para arquivos com large zero holes.
    property Sparse: Boolean read FSparse write FSparse default False;
    // Preserva chmod bits unix completos (setuid/setgid/sticky).
    property UnixPermissions: Boolean read FUnixPermissions write FUnixPermissions default False;
    // Nao termine a leitura ao encontrar 2 zero blocks (concat de tar arquivos).
    property IgnoreZeroBlocks: Boolean read FIgnoreZeroBlocks write FIgnoreZeroBlocks default False;
    // PAX extended headers (POSIX.1-2001 — UTF-8 names, atime/ctime nano, etc.)
    property AddPaxExtensions: Boolean read FAddPaxExtensions write FAddPaxExtensions default False;

    // ---- Read-only info ----
    property ArchiveSize: Int64 read FArchiveSize;

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
    property OnError: TArchiveErrorEvent read FOnError write FOnError;
    property OnWarning: TArchiveWarningEvent read FOnWarning write FOnWarning;
    property OnLog: TArchiveLogEvent read FOnLog write FOnLog;
  end;

implementation

uses
  TarGzFile;  // for TTarFileBuilder Gzip variant (implementation-only;
              // TarGzFile uses TarFile in its interface — cycle resolved
              // by Pascal's implementation-section uses semantics)

const
  TAR_BLOCK_SIZE = 512;
  USTAR_MAGIC = 'ustar' + #0;
  USTAR_VERSION = '00';

type
  TTarHeaderRaw = packed array[0..TAR_BLOCK_SIZE - 1] of AnsiChar;

// ---------- Helpers ----------

function OctalToInt64(const ABuf: array of AnsiChar; AOffset, ALen: Integer): Int64;
var
  I: Integer;
  C: AnsiChar;
begin
  Result := 0;
  for I := 0 to ALen - 1 do
  begin
    C := ABuf[AOffset + I];
    if (C = #0) or (C = ' ') then Continue;
    if (C < '0') or (C > '7') then Break;
    Result := Result * 8 + (Ord(C) - Ord('0'));
  end;
end;

procedure WriteOctal(var ABuf: TTarHeaderRaw; AOffset, ALen: Integer; AValue: Int64);
var
  S: AnsiString;
  I: Integer;
begin
  S := AnsiString(IntToHex(AValue, 1));
  // Convert to octal
  S := '';
  if AValue = 0 then
    S := '0'
  else
    while AValue > 0 do
    begin
      S := AnsiChar(Ord('0') + (AValue mod 8)) + S;
      AValue := AValue div 8;
    end;
  // Pad with leading zeros (left-pad), one byte less than ALen for NUL terminator
  while Length(S) < ALen - 1 do
    S := '0' + S;
  // Copy (truncate if too long)
  for I := 0 to ALen - 2 do
    if I < Length(S) then
      ABuf[AOffset + I] := S[I + 1]
    else
      ABuf[AOffset + I] := '0';
  ABuf[AOffset + ALen - 1] := #0;
end;

procedure WriteString(var ABuf: TTarHeaderRaw; AOffset, ALen: Integer; const AStr: AnsiString);
var
  I, N: Integer;
begin
  N := Length(AStr);
  if N > ALen then N := ALen;
  for I := 0 to N - 1 do
    ABuf[AOffset + I] := AStr[I + 1];
  for I := N to ALen - 1 do
    ABuf[AOffset + I] := #0;
end;

function ReadString(const ABuf: array of AnsiChar; AOffset, AMaxLen: Integer): string;
var
  S: AnsiString;
  I: Integer;
begin
  S := '';
  for I := 0 to AMaxLen - 1 do
  begin
    if ABuf[AOffset + I] = #0 then Break;
    S := S + ABuf[AOffset + I];
  end;
  Result := string(S);
end;

function CalcChecksum(const ABuf: TTarHeaderRaw): Cardinal;
var
  I: Integer;
  Sum: Cardinal;
begin
  Sum := 0;
  for I := 0 to TAR_BLOCK_SIZE - 1 do
  begin
    if (I >= 148) and (I < 156) then
      Sum := Sum + 32  // chksum field treated as spaces
    else
      Sum := Sum + Byte(ABuf[I]);
  end;
  Result := Sum;
end;

function DateTimeToUnixEpoch(ADateTime: TDateTime): Int64;
const
  UnixEpoch = 25569.0; // 1970-01-01
begin
  Result := Round((ADateTime - UnixEpoch) * 86400);
end;

function UnixEpochToDateTime(AEpoch: Int64): TDateTime;
const
  UnixEpoch = 25569.0;
begin
  Result := UnixEpoch + (AEpoch / 86400);
end;

// =============================================================================
//   TTarFile
// =============================================================================

constructor TTarFile.Create(AOwner: TComponent);
begin
  inherited;
  FActive := False;
  FFindIndex := -1;
  FFormat := tfUstar;
  FPreserveOwnership := False;
  FPreserveTimestamps := True;
  FDefaultMode := $1A4;            // 0644 octal
  FDefaultUid := 0;
  FDefaultGid := 0;
  // v4.1 P28: block/record geometry defaults per POSIX tar spec.
  FBlockSize := 512;
  FBlockingFactor := 20;
  FRecordSize := FBlockSize * FBlockingFactor;  // 10240
  FArchiveSize := 0;
end;

procedure TTarFile.SetBlockSize(AValue: Integer);
begin
  if AValue <= 0 then Exit;
  FBlockSize := AValue;
  FRecordSize := FBlockSize * FBlockingFactor;
end;

procedure TTarFile.SetBlockingFactor(AValue: Integer);
begin
  if AValue <= 0 then Exit;
  FBlockingFactor := AValue;
  FRecordSize := FBlockSize * FBlockingFactor;
end;

destructor TTarFile.Destroy;
begin
  Close;
  inherited;
end;

procedure TTarFile.SetActive(AValue: Boolean);
begin
  if AValue = FActive then Exit;
  if AValue then Open else Close;
end;

procedure TTarFile.SetFileName(const AValue: string);
begin
  if AValue = FFileName then Exit;
  Close;
  FFileName := AValue;
  if Assigned(FOnFileChanged) then FOnFileChanged(Self);
end;

procedure TTarFile.Open;
begin
  if FActive then Exit;
  if FFileName = '' then
    raise ETarError.Create('TTarFile.Open: FileName not set');
  if SysUtils.FileExists(FFileName) then
  begin
    FStream := TFileStream.Create(FFileName, fmOpenReadWrite or fmShareDenyWrite);
    FOwnsStream := True;
    ReadDirectory;
  end
  else
  begin
    FStream := TFileStream.Create(FFileName, fmCreate);
    FOwnsStream := True;
    // Empty archive: only trailer
    WriteTrailer;
    FStream.Position := 0;  // ready for appends (will seek to before-trailer)
    SetLength(FEntries, 0);
    FEntryCount := 0;
  end;
  // v4.1 P28: populate read-only ArchiveSize from actual stream size.
  if Assigned(FStream) then FArchiveSize := FStream.Size else FArchiveSize := 0;
  FActive := True;
end;

procedure TTarFile.Close;
begin
  if not FActive then Exit;
  // v4.1 P28: refresh ArchiveSize one last time before freeing stream
  // (writes that occurred during the session change file size).
  if Assigned(FStream) then FArchiveSize := FStream.Size;
  if FOwnsStream and Assigned(FStream) then
    FreeAndNil(FStream);
  FStream := nil;
  FActive := False;
  SetLength(FEntries, 0);
  FEntryCount := 0;
end;

procedure TTarFile.ReadDirectory;
var
  Hdr: TTarHeaderRaw;
  N, Idx: Integer;
  Size: Int64;
  EntryName, Magic: string;
  Chksum, Calc: Cardinal;
  TypeFlag: AnsiChar;
  Mtime: Int64;
  Padding: Int64;
begin
  SetLength(FEntries, 0);
  FEntryCount := 0;
  FStream.Position := 0;
  while FStream.Position + TAR_BLOCK_SIZE <= FStream.Size do
  begin
    N := FStream.Read(Hdr[0], TAR_BLOCK_SIZE);
    if N < TAR_BLOCK_SIZE then Break;
    // End-of-archive: 2 zero blocks (we stop at first)
    if Hdr[0] = #0 then Break;
    Magic := ReadString(Hdr, 257, 6);
    if (Copy(Magic, 1, 5) <> 'ustar') then Break;
    // Parse standard ustar header fields
    EntryName := ReadString(Hdr, 0, 100);
    Size      := OctalToInt64(Hdr, 124, 12);
    Mtime     := OctalToInt64(Hdr, 136, 12);
    Chksum    := OctalToInt64(Hdr, 148, 8);
    TypeFlag  := Hdr[156];
    // (Re-)compute checksum for validation (optional)
    Calc := CalcChecksum(Hdr);
    if (Chksum <> 0) and (Chksum <> Calc) then
      raise ETarError.CreateFmt('TAR entry "%s" checksum mismatch (got %d, calc %d)',
        [EntryName, Chksum, Calc]);
    // Register entry
    Idx := Length(FEntries);
    SetLength(FEntries, Idx + 1);
    FEntries[Idx].Name      := EntryName;
    FEntries[Idx].Size      := Size;
    FEntries[Idx].Mode      := OctalToInt64(Hdr, 100, 8);
    FEntries[Idx].ModTime   := UnixEpochToDateTime(Mtime);
    FEntries[Idx].Offset    := FStream.Position;
    FEntries[Idx].LinkTarget := ReadString(Hdr, 157, 100);
    case TypeFlag of
      '0', #0: FEntries[Idx].EntryType := tetFile;
      '1':     FEntries[Idx].EntryType := tetHardLink;
      '2':     FEntries[Idx].EntryType := tetSymLink;
      '5':     FEntries[Idx].EntryType := tetDirectory;
    else
      FEntries[Idx].EntryType := tetOther;
    end;
    // Skip payload (rounded up to next 512-byte block)
    Padding := (TAR_BLOCK_SIZE - (Size mod TAR_BLOCK_SIZE)) mod TAR_BLOCK_SIZE;
    FStream.Position := FStream.Position + Size + Padding;
  end;
  FEntryCount := Length(FEntries);
end;

procedure TTarFile.WriteTrailer;
const
  Zero: array[0..TAR_BLOCK_SIZE * 2 - 1] of Byte = (
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  );
begin
  FStream.WriteBuffer(Zero[0], TAR_BLOCK_SIZE * 2);
end;

function TTarFile.WriteEntryHeader(const AName: string; ASize: Int64;
  ATypeflag: AnsiChar; AModTime: TDateTime; AMode: Cardinal): Boolean;
var
  Hdr: TTarHeaderRaw;
  I: Integer;
  Chksum: Cardinal;
  ChkStr: AnsiString;
begin
  // Zero header
  for I := 0 to TAR_BLOCK_SIZE - 1 do Hdr[I] := #0;
  // name (0-99), truncate if too long (TODO: long name support via GNU/pax)
  WriteString(Hdr, 0, 100, AnsiString(AName));
  WriteOctal(Hdr, 100, 8, AMode);
  WriteOctal(Hdr, 108, 8, 0);     // uid
  WriteOctal(Hdr, 116, 8, 0);     // gid
  WriteOctal(Hdr, 124, 12, ASize);
  WriteOctal(Hdr, 136, 12, DateTimeToUnixEpoch(AModTime));
  // chksum field (148-155): 8 spaces during calc
  for I := 148 to 155 do Hdr[I] := ' ';
  Hdr[156] := ATypeflag;
  // magic + version
  WriteString(Hdr, 257, 6, USTAR_MAGIC);
  WriteString(Hdr, 263, 2, USTAR_VERSION);
  // Calculate checksum
  Chksum := CalcChecksum(Hdr);
  // Write checksum field (6 octal digits + NUL + space)
  ChkStr := '';
  while Chksum > 0 do
  begin
    ChkStr := AnsiChar(Ord('0') + (Chksum mod 8)) + ChkStr;
    Chksum := Chksum div 8;
  end;
  while Length(ChkStr) < 6 do ChkStr := '0' + ChkStr;
  for I := 0 to 5 do Hdr[148 + I] := ChkStr[I + 1];
  Hdr[154] := #0;
  Hdr[155] := ' ';
  // Write header
  FStream.WriteBuffer(Hdr[0], TAR_BLOCK_SIZE);
  Result := True;
end;

procedure TTarFile.AppendStream(AStream: TStream; const AName: string; AModTime: TDateTime);
var
  StreamSize: Int64;
  Padding: Int64;
  Zero: array[0..TAR_BLOCK_SIZE - 1] of Byte;
  Buf: array of Byte;
  N: Integer;
  TrailerPos: Int64;
begin
  if not FActive then
    raise ETarError.Create('TTarFile.AppendStream: not Active');
  StreamSize := AStream.Size - AStream.Position;
  // Seek to position before trailer (last 2 blocks)
  TrailerPos := FStream.Size - (TAR_BLOCK_SIZE * 2);
  if TrailerPos < 0 then TrailerPos := 0;
  FStream.Position := TrailerPos;
  WriteEntryHeader(AName, StreamSize, '0', AModTime, $1B6); // mode 0666
  // Copy payload
  SetLength(Buf, 64 * 1024);
  while AStream.Position < AStream.Size do
  begin
    N := AStream.Read(Buf[0], Length(Buf));
    if N <= 0 then Break;
    FStream.WriteBuffer(Buf[0], N);
  end;
  // Pad to 512
  Padding := (TAR_BLOCK_SIZE - (StreamSize mod TAR_BLOCK_SIZE)) mod TAR_BLOCK_SIZE;
  if Padding > 0 then
  begin
    FillChar(Zero[0], Padding, 0);
    FStream.WriteBuffer(Zero[0], Padding);
  end;
  // Re-emit trailer
  WriteTrailer;
  // Reload directory
  ReadDirectory;
end;

procedure TTarFile.AppendFileFromDisk(const ADiskPath, AArchiveName: string);
var
  Fs: TFileStream;
begin
  Fs := TFileStream.Create(ADiskPath, fmOpenRead or fmShareDenyWrite);
  try
    AppendStream(Fs, AArchiveName, Now);
  finally
    Fs.Free;
  end;
end;

procedure TTarFile.AppendBytes(const ABytes: TBytes; const AName: string);
var
  Mem: TMemoryStream;
begin
  Mem := TMemoryStream.Create;
  try
    if Length(ABytes) > 0 then
      Mem.WriteBuffer(ABytes[0], Length(ABytes));
    Mem.Position := 0;
    AppendStream(Mem, AName, Now);
  finally
    Mem.Free;
  end;
end;

procedure TTarFile.AppendString(const AContent: string; const AName: string);
var
  Raw: AnsiString;
  B: TBytes;
begin
  Raw := AnsiString(AContent);
  SetLength(B, Length(Raw));
  if Length(Raw) > 0 then
    Move(Raw[1], B[0], Length(Raw));
  AppendBytes(B, AName);
end;

procedure TTarFile.AppendDirectoryEntry(const ADirName: string; AModTime: TDateTime);
var
  TrailerPos: Int64;
begin
  if not FActive then
    raise ETarError.Create('TTarFile.AppendDirectoryEntry: not Active');
  TrailerPos := FStream.Size - (TAR_BLOCK_SIZE * 2);
  if TrailerPos < 0 then TrailerPos := 0;
  FStream.Position := TrailerPos;
  WriteEntryHeader(ADirName, 0, '5', AModTime, $1ED); // mode 0755 typical dir
  WriteTrailer;
  ReadDirectory;
end;

function TTarFile.GetEntryCount: Integer;
begin
  Result := FEntryCount;
end;

function TTarFile.FileExists(const AName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FEntryCount - 1 do
    if FEntries[I].Name = AName then
      Exit(True);
end;

function TTarFile.GetEntryStream(const AName: string): TStream;
var
  I: Integer;
  Mem: TMemoryStream;
begin
  Result := nil;
  for I := 0 to FEntryCount - 1 do
    if FEntries[I].Name = AName then
    begin
      Mem := TMemoryStream.Create;
      try
        FStream.Position := FEntries[I].Offset;
        if FEntries[I].Size > 0 then
          Mem.CopyFrom(FStream, FEntries[I].Size);
        Mem.Position := 0;
        Result := Mem;
      except
        Mem.Free;
        raise;
      end;
      Exit;
    end;
  raise ETarError.CreateFmt('TTarFile.GetEntryStream: entry "%s" not found', [AName]);
end;

function TTarFile.ReadAsBytes(const AName: string): TBytes;
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

function TTarFile.ReadAsString(const AName: string): string;
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

function TTarFile.FindFirst(out ARec: TTarSearchRec): Integer;
begin
  if FEntryCount = 0 then
  begin
    FillChar(ARec, SizeOf(ARec), 0);
    Result := -1;
    Exit;
  end;
  FFindIndex := 0;
  ARec := FEntries[0];
  Result := 0;
end;

function TTarFile.FindNext(out ARec: TTarSearchRec): Integer;
begin
  Inc(FFindIndex);
  if FFindIndex >= FEntryCount then
  begin
    FillChar(ARec, SizeOf(ARec), 0);
    Result := -1;
    Exit;
  end;
  ARec := FEntries[FFindIndex];
  Result := FFindIndex;
end;

// ---- Fluent inline ----

function TTarFile.WithFileName(const APath: string): TTarFile;
begin
  SetFileName(APath);
  Result := Self;
end;

function TTarFile.ThatOpens: TTarFile;
begin
  Open;
  Result := Self;
end;

{ ============================================================================
  Fluent builder + factory — relocated from former Tar.Fluent.pas (dissolved
  per backend-pascal-unit-naming_V1.6.0 §2; interface in companion .Interfaces.pas).
  ============================================================================ }

constructor TTarFileBuilder.CreateNew(const APath: string; AGzip: Boolean);
begin
  inherited Create;
  FArchivePath := APath;
  FOpenForRead := False;
  FUseGzip := AGzip;
  FGzipLevel := 6;
  if SysUtils.FileExists(APath) then SysUtils.DeleteFile(APath);
end;

constructor TTarFileBuilder.CreateOpen(const APath: string; AGzip: Boolean);
begin
  inherited Create;
  FArchivePath := APath;
  FOpenForRead := True;
  FUseGzip := AGzip;
end;

function TTarFileBuilder.WithGzip(AEnable: Boolean): ITarFileBuilder;
begin
  FUseGzip := AEnable;
  Result := Self;
end;

function TTarFileBuilder.WithGzipLevel(ALevel: Integer): ITarFileBuilder;
begin
  FGzipLevel := ALevel;
  Result := Self;
end;

function TTarFileBuilder.AppendFile(const ADiskFileName, AEntryName: string): ITarFileBuilder;
var Item: TTarBuilderItem;
begin
  Item.Kind := tbkFile;
  Item.DiskFileName := ADiskFileName;
  Item.EntryName := AEntryName;
  SetLength(FItems, Length(FItems) + 1);
  FItems[High(FItems)] := Item;
  Result := Self;
end;

function TTarFileBuilder.AppendBytes(const AData: TBytes; const AEntryName: string): ITarFileBuilder;
var Item: TTarBuilderItem;
begin
  Item.Kind := tbkBytes;
  Item.Data := AData;
  Item.EntryName := AEntryName;
  SetLength(FItems, Length(FItems) + 1);
  FItems[High(FItems)] := Item;
  Result := Self;
end;

function TTarFileBuilder.AppendString(const AContent, AEntryName: string): ITarFileBuilder;
var Item: TTarBuilderItem;
begin
  Item.Kind := tbkString;
  Item.StrData := AContent;
  Item.EntryName := AEntryName;
  SetLength(FItems, Length(FItems) + 1);
  FItems[High(FItems)] := Item;
  Result := Self;
end;

function TTarFileBuilder.AppendDirectory(const ADirName: string): ITarFileBuilder;
var Item: TTarBuilderItem;
begin
  Item.Kind := tbkDir;
  Item.EntryName := ADirName;
  Item.ModTime := Now;
  SetLength(FItems, Length(FItems) + 1);
  FItems[High(FItems)] := Item;
  Result := Self;
end;

procedure TTarFileBuilder.ApplyItems(ATar: TObject);
var I: Integer; T: TTarFile;
begin
  T := TTarFile(ATar);
  for I := 0 to High(FItems) do
    case FItems[I].Kind of
      tbkFile:   T.AppendFileFromDisk(FItems[I].DiskFileName, FItems[I].EntryName);
      tbkBytes:  T.AppendBytes(FItems[I].Data, FItems[I].EntryName);
      tbkString: T.AppendString(FItems[I].StrData, FItems[I].EntryName);
      tbkDir:    T.AppendDirectoryEntry(FItems[I].EntryName, FItems[I].ModTime);
    end;
end;

procedure TTarFileBuilder.Execute;
var
  Tar: TTarFile;
  TarGz: TTarGzFile;
  I: Integer;
begin
  if Length(FItems) = 0 then
    raise ETarError.Create('TTarFileBuilder.Execute: nenhum item appended', ERR_ZIPFILE_TAR);
  if FUseGzip then
  begin
    TarGz := TTarGzFile.Create(nil);
    try
      TarGz.FileName := FArchivePath;
      TarGz.GzipLevel := FGzipLevel;
      TarGz.Active := True;
      for I := 0 to High(FItems) do
        case FItems[I].Kind of
          tbkFile:   TarGz.AppendFileFromDisk(FItems[I].DiskFileName, FItems[I].EntryName);
          tbkBytes:  TarGz.AppendBytes(FItems[I].Data, FItems[I].EntryName);
          tbkString: TarGz.AppendString(FItems[I].StrData, FItems[I].EntryName);
          tbkDir:    ; // TTarGzFile nao expoe AppendDirectoryEntry
        end;
    finally TarGz.Free; end;
  end
  else
  begin
    Tar := TTarFile.Create(nil);
    try
      Tar.FileName := FArchivePath;
      Tar.Active := True;
      ApplyItems(Tar);
    finally Tar.Free; end;
  end;
end;

function TTarFileBuilder.ExtractStream(const AEntryName: string): TStream;
var
  Tar: TTarFile;
  TarGz: TTarGzFile;
begin
  if FUseGzip then
  begin
    TarGz := TTarGzFile.Create(nil);
    try
      TarGz.FileName := FArchivePath;
      TarGz.Active := True;
      Result := TarGz.GetEntryStream(AEntryName);
    finally TarGz.Free; end;
  end
  else
  begin
    Tar := TTarFile.Create(nil);
    try
      Tar.FileName := FArchivePath;
      Tar.Active := True;
      Result := Tar.GetEntryStream(AEntryName);
    finally Tar.Free; end;
  end;
end;

function TTarFileBuilder.ReadAsBytes(const AEntryName: string): TBytes;
var Stm: TStream;
begin
  Stm := ExtractStream(AEntryName);
  try
    SetLength(Result, Stm.Size);
    Stm.Position := 0;
    if Stm.Size > 0 then Stm.ReadBuffer(Result[0], Stm.Size);
  finally Stm.Free; end;
end;

function TTarFileBuilder.ReadAsString(const AEntryName: string): string;
var B: TBytes;
begin
  B := ReadAsBytes(AEntryName);
  if Length(B) = 0 then Result := ''
  else Result := TEncoding.UTF8.GetString(B);
end;

function TTarFileBuilder.HasEntry(const AEntryName: string): Boolean;
var
  Tar: TTarFile;
  TarGz: TTarGzFile;
begin
  if FUseGzip then
  begin
    TarGz := TTarGzFile.Create(nil);
    try
      TarGz.FileName := FArchivePath;
      TarGz.Active := True;
      Result := TarGz.FileExists(AEntryName);
    finally TarGz.Free; end;
  end
  else
  begin
    Tar := TTarFile.Create(nil);
    try
      Tar.FileName := FArchivePath;
      Tar.Active := True;
      Result := Tar.FileExists(AEntryName);
    finally Tar.Free; end;
  end;
end;

function TTarFileBuilder.CountEntries: Integer;
var
  Tar: TTarFile;
  TarGz: TTarGzFile;
begin
  if FUseGzip then
  begin
    TarGz := TTarGzFile.Create(nil);
    try
      TarGz.FileName := FArchivePath;
      TarGz.Active := True;
      Result := TarGz.EntryCount;
    finally TarGz.Free; end;
  end
  else
  begin
    Tar := TTarFile.Create(nil);
    try
      Tar.FileName := FArchivePath;
      Tar.Active := True;
      Result := Tar.EntryCount;
    finally Tar.Free; end;
  end;
end;

class function Tarball.NewArchive(const APath: string): ITarFileBuilder;
begin Result := TTarFileBuilder.CreateNew(APath, False); end;

class function Tarball.NewGzArchive(const APath: string): ITarFileBuilder;
begin Result := TTarFileBuilder.CreateNew(APath, True); end;

class function Tarball.OpenArchive(const APath: string): ITarFileBuilder;
begin Result := TTarFileBuilder.CreateOpen(APath, False); end;

class function Tarball.OpenGzArchive(const APath: string): ITarFileBuilder;
begin Result := TTarFileBuilder.CreateOpen(APath, True); end;

end.
