{ =============================================================================
  IsoFile - absorvido do ZipFileORM v4.0.0 (modulo ZipFile, F1-A Onda A.3)

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
{ IsoFile.pas

  TIsoFile — READ-only ISO 9660 + Joliet decoder, pure-pascal.

  Suporta:
   - ISO 9660 (ECMA-119) Primary Volume Descriptor + diretorios
   - Joliet extension (Supplementary VD com UCS-2/UTF-16 BE filenames)
   - Sectores 2048 bytes (modo 1, padrao para CD-ROM data)
   - Recursive directory traversal -> flat entry list

  NAO suporta:
   - Rock Ridge POSIX extensions (deferido)
   - El Torito boot
   - Multi-extent files (>4GB single file)
   - UDF (Universal Disk Format — usado em DVD/Blu-ray)

  Cross-platform: Delphi (Win32/Win64) + FPC (Win32/Win64/Linux i386/x86_64).
  Sem dependencia C — apenas SysUtils + Classes.

  API espelhada de TZipFile/TSevenZFile/etc.:
   - Active, FileName, Open, Close
   - EntryCount, FileExists, IsDir, GetFileSize, GetEntryName
   - FindIndex, GetEntryStream, ReadAsBytes, ReadAsString
   - JolietActive: True se VD secundario com Joliet foi usado
}
unit IsoFile;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Classes, Commons.ZipFile.Types, ZipFile.Events, IsoFile.Exceptions;

const
  ISO_SECTOR_SIZE   = 2048;
  ISO_PVD_LBA       = 16;       // sector 16 = primeira VD
  VD_BOOT           = $00;
  VD_PRIMARY        = $01;
  VD_SUPPLEMENTARY  = $02;
  VD_PARTITION      = $03;
  VD_TERMINATOR     = $FF;

  // File flags (byte at offset 25 in directory record)
  DREC_HIDDEN       = $01;
  DREC_DIRECTORY    = $02;
  DREC_ASSOCIATED   = $04;
  DREC_RECORD_FMT   = $08;
  DREC_PROTECTION   = $10;
  DREC_MULTI_EXTENT = $80;

type
  // Exception type relocated to IsoFile.Exceptions.pas (Wave 3b).
  EIsoError = IsoFile.Exceptions.EIsoError;

  TIsoEntry = record
    FullPath: string;       // ex.: 'DIR1/SUB/FILE.TXT'
    Extent: Cardinal;       // LBA do primeiro setor
    Size: Cardinal;         // bytes (sem alinhamento de setor)
    IsDirectory: Boolean;
  end;

  TIsoFile = class(TComponent)
  private
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
    // Security
    FOnAskPassword: TArchivePasswordRequestEvent;
    FOnReplaceQuery: TArchiveReplaceQueryEvent;
    FOnVerify: TArchiveVerifyEvent;
    // Diagnostics
    FOnError: TArchiveErrorEvent;
    FOnWarning: TArchiveWarningEvent;
    FOnLog: TArchiveLogEvent;
    FStream: TFileStream;
    FOwnsStream: Boolean;
    FEntries: array of TIsoEntry;
    FJolietActive: Boolean;
    FVolumeID: string;
    // Read-only PVD (Primary Volume Descriptor) fields — populated by FindBestVolumeDescriptor.
    FSystemID: string;
    FPublisherID: string;
    FPreparerID: string;
    FApplicationID: string;
    FCopyrightFile: string;
    FAbstractFile: string;
    FBibliographicFile: string;
    FCreationDate: TDateTime;
    FModificationDate: TDateTime;
    FVolumeSize: Int64;          // bytes = volume_space_size * logical_block_size
    FBlockSize: Word;            // logical block size (normalmente 2048)
    FVolumeSetSize: Word;        // 1 = single volume
    FArchiveSize: Int64;         // physical .iso file size
    // v3.12 extras
    FVolumeFlags: Byte;          // SVD flags (FRAR bit etc.)
    FVolumeSequenceNumber: Word; // sequencia para multi-volume set
    FVolumeSetIdentifier: string; // identifier do volume set (multi-disc)
    FFileStructureVersion: Byte; // sempre 1 em ISO 9660
    FPathTableSize: Cardinal;    // bytes do path table
    FExpirationDate: TDateTime;  // data depois da qual o conteudo expira
    FEffectiveDate: TDateTime;   // data em que o conteudo se torna valido
    FApplicationUse: TBytes;     // 512 bytes free para uso da app
    FHasRockRidge: Boolean;      // Rock Ridge extension detectada
    FHasElTorito: Boolean;       // El Torito boot record detectado
    FHasUDFBridge: Boolean;      // UDF bridge (ISO + UDF combined)
    FBootCatalogLBA: Cardinal;   // LBA do boot catalog (El Torito)

    procedure ReadSector(ALba: Cardinal; var ABuffer: TBytes);
    function FindBestVolumeDescriptor(out APvd: TBytes; out AIsJoliet: Boolean): Boolean;
    procedure ParseDirectoryRecursive(AExtent, ASize: Cardinal;
      const APathPrefix: string; AIsJoliet: Boolean);
    procedure DoOpenAndIndex;

    procedure SetActive(AValue: Boolean);
    procedure SetFileName(const AValue: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Open;
    procedure Close;

    function GetEntryCount: Integer;
    function FileExists(const AName: string): Boolean;
    function IsDir(AIndex: Integer): Boolean;
    function GetFileSize(AIndex: Integer): Int64;
    function GetEntryName(AIndex: Integer): string;
    function FindIndex(const AName: string): Integer;
    function GetEntryStream(const AName: string): TStream;
    function ReadAsBytes(const AName: string): TBytes;
    function ReadAsString(const AName: string): string;

    function WithFileName(const APath: string): TIsoFile;
    function ThatOpens: TIsoFile;
  published
    property Active: Boolean read FActive write SetActive;
    property FileName: string read FFileName write SetFileName;
    property EntryCount: Integer read GetEntryCount;

    // ---- Primary Volume Descriptor (ISO 9660 + Joliet) ----
    property JolietActive: Boolean read FJolietActive;
    property VolumeID: string read FVolumeID;
    property SystemID: string read FSystemID;
    property PublisherID: string read FPublisherID;
    property PreparerID: string read FPreparerID;
    property ApplicationID: string read FApplicationID;
    property CopyrightFile: string read FCopyrightFile;
    property AbstractFile: string read FAbstractFile;
    property BibliographicFile: string read FBibliographicFile;
    property CreationDate: TDateTime read FCreationDate;
    property ModificationDate: TDateTime read FModificationDate;
    property VolumeSize: Int64 read FVolumeSize;
    // Logical block size (normalmente 2048).
    property BlockSize: Word read FBlockSize;
    // 1 = single ISO; >1 = volume set (raro).
    property VolumeSetSize: Word read FVolumeSetSize;
    property ArchiveSize: Int64 read FArchiveSize;
    // Volume flags (SVD byte 7 — FRAR bit indicates UTF-16 LE encoding etc.)
    property VolumeFlags: Byte read FVolumeFlags;
    // Sequence number deste volume dentro do set (1-based).
    property VolumeSequenceNumber: Word read FVolumeSequenceNumber;
    // Volume set identifier (texto livre, 128 bytes max).
    property VolumeSetIdentifier: string read FVolumeSetIdentifier;
    // File structure version (sempre 1 em ISO 9660:1988).
    property FileStructureVersion: Byte read FFileStructureVersion;
    // Path table size em bytes.
    property PathTableSize: Cardinal read FPathTableSize;
    // Datas adicionais do PVD.
    property ExpirationDate: TDateTime read FExpirationDate;
    property EffectiveDate: TDateTime read FEffectiveDate;
    // ApplicationUse (PVD bytes 884..1395) — 512 bytes livres para apps.
    property ApplicationUse: TBytes read FApplicationUse;
    // True se Rock Ridge System Use Entries detectadas (POSIX file metadata).
    property HasRockRidge: Boolean read FHasRockRidge;
    // True se El Torito Boot Record presente (bootable CD/DVD).
    property HasElTorito: Boolean read FHasElTorito;
    // True se o image contem UDF bridge (DVD video / Blu-ray combinado).
    property HasUDFBridge: Boolean read FHasUDFBridge;
    // LBA do boot catalog (so valido se HasElTorito).
    property BootCatalogLBA: Cardinal read FBootCatalogLBA;

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
    property OnAskPassword: TArchivePasswordRequestEvent read FOnAskPassword write FOnAskPassword;
    property OnReplaceQuery: TArchiveReplaceQueryEvent read FOnReplaceQuery write FOnReplaceQuery;
    property OnVerify: TArchiveVerifyEvent read FOnVerify write FOnVerify;
    property OnError: TArchiveErrorEvent read FOnError write FOnError;
    property OnWarning: TArchiveWarningEvent read FOnWarning write FOnWarning;
    property OnLog: TArchiveLogEvent read FOnLog write FOnLog;
  end;

implementation

// === Little-endian readers (ISO usa both-endian para portabilidade;
// PCs leem o LE; LE = first half de cada both-endian field) ===

function ReadLEUInt32(const Buf: TBytes; AOffset: Integer): Cardinal; inline;
begin
  Result := Cardinal(Buf[AOffset]) or
            (Cardinal(Buf[AOffset + 1]) shl 8) or
            (Cardinal(Buf[AOffset + 2]) shl 16) or
            (Cardinal(Buf[AOffset + 3]) shl 24);
end;

function ReadLEUInt16(const Buf: TBytes; AOffset: Integer): Word; inline;
begin
  Result := Word(Buf[AOffset]) or (Word(Buf[AOffset + 1]) shl 8);
end;

// === Joliet UCS-2 BE decoder (filename Joliet usa UCS-2 big-endian) ===

function DecodeUcs2Be(const Buf: TBytes; AOffset, ALength: Integer): string;
var
  I: Integer;
  CodeUnit: Word;
  Chars: TArray<Char>;
begin
  // ALength em bytes; cada char UCS-2 = 2 bytes BE
  SetLength(Chars, ALength div 2);
  for I := 0 to (ALength div 2) - 1 do
  begin
    CodeUnit := (Word(Buf[AOffset + I * 2]) shl 8) or Word(Buf[AOffset + I * 2 + 1]);
    Chars[I] := Char(CodeUnit);
  end;
  SetString(Result, PChar(@Chars[0]), Length(Chars));
end;

function DecodeIso8859(const Buf: TBytes; AOffset, ALength: Integer): string;
var
  I: Integer;
  Chars: TArray<Char>;
begin
  SetLength(Chars, ALength);
  for I := 0 to ALength - 1 do
    Chars[I] := Char(Buf[AOffset + I]);
  SetString(Result, PChar(@Chars[0]), Length(Chars));
end;

constructor TIsoFile.Create(AOwner: TComponent);
begin
  inherited;
  FActive := False;
  FOwnsStream := False;
end;

destructor TIsoFile.Destroy;
begin
  Close;
  inherited;
end;

procedure TIsoFile.SetActive(AValue: Boolean);
begin
  if AValue = FActive then Exit;
  if AValue then Open else Close;
end;

procedure TIsoFile.SetFileName(const AValue: string);
begin
  if AValue = FFileName then Exit;
  Close;
  FFileName := AValue;
  if Assigned(FOnFileChanged) then FOnFileChanged(Self);
end;

procedure TIsoFile.ReadSector(ALba: Cardinal; var ABuffer: TBytes);
begin
  if Length(ABuffer) < ISO_SECTOR_SIZE then
    SetLength(ABuffer, ISO_SECTOR_SIZE);
  FStream.Position := Int64(ALba) * ISO_SECTOR_SIZE;
  FStream.ReadBuffer(ABuffer[0], ISO_SECTOR_SIZE);
end;

function TIsoFile.FindBestVolumeDescriptor(out APvd: TBytes;
  out AIsJoliet: Boolean): Boolean;
var
  Lba: Cardinal;
  Buf, BestPvd, BestSvd: TBytes;
  Sig: string;
  VdType: Byte;
  IsJolietSvd: Boolean;
begin
  Result := False;
  AIsJoliet := False;
  SetLength(BestPvd, 0);
  SetLength(BestSvd, 0);
  SetLength(Buf, ISO_SECTOR_SIZE);
  Lba := ISO_PVD_LBA;
  while Lba < ISO_PVD_LBA + 64 do  // limite sano: 64 VDs
  begin
    ReadSector(Lba, Buf);
    VdType := Buf[0];
    Sig := DecodeIso8859(Buf, 1, 5);
    if Sig <> 'CD001' then Break;  // nao e ISO 9660 valido
    if VdType = VD_TERMINATOR then Break;
    if VdType = VD_PRIMARY then
    begin
      BestPvd := Copy(Buf, 0, ISO_SECTOR_SIZE);
    end
    else if VdType = VD_SUPPLEMENTARY then
    begin
      // Joliet detection: escape sequence at offset 88 (8 bytes)
      // Joliet usa "%/@" (0x25 0x2F 0x40) ou "%/C" (0x25 0x2F 0x43)
      // ou "%/E" (0x25 0x2F 0x45) — level 1/2/3
      IsJolietSvd := (Buf[88] = $25) and (Buf[89] = $2F) and
                     ((Buf[90] = $40) or (Buf[90] = $43) or (Buf[90] = $45));
      if IsJolietSvd then
        BestSvd := Copy(Buf, 0, ISO_SECTOR_SIZE);
    end;
    Inc(Lba);
  end;
  if Length(BestSvd) = ISO_SECTOR_SIZE then
  begin
    APvd := BestSvd;
    AIsJoliet := True;
    Result := True;
  end
  else if Length(BestPvd) = ISO_SECTOR_SIZE then
  begin
    APvd := BestPvd;
    Result := True;
  end;
end;

procedure TIsoFile.ParseDirectoryRecursive(AExtent, ASize: Cardinal;
  const APathPrefix: string; AIsJoliet: Boolean);
var
  TotalRead: Cardinal;
  Buf: TBytes;
  Offset: Integer;
  RecLen: Byte;
  ChildExtent, ChildSize: Cardinal;
  Flags: Byte;
  FnLen: Byte;
  Fn: string;
  IsDirChild: Boolean;
  Entry: TIsoEntry;
  CurrentLba: Cardinal;
  SectorsToRead: Cardinal;
begin
  // ler todo o diretorio em chunks de 1 setor (ASize pode ser multiplo de 2048)
  SectorsToRead := (ASize + ISO_SECTOR_SIZE - 1) div ISO_SECTOR_SIZE;
  SetLength(Buf, SectorsToRead * ISO_SECTOR_SIZE);
  CurrentLba := AExtent;
  TotalRead := 0;
  while TotalRead < SectorsToRead * ISO_SECTOR_SIZE do
  begin
    FStream.Position := Int64(CurrentLba) * ISO_SECTOR_SIZE;
    FStream.ReadBuffer(Buf[TotalRead], ISO_SECTOR_SIZE);
    Inc(CurrentLba);
    Inc(TotalRead, ISO_SECTOR_SIZE);
  end;

  Offset := 0;
  while Offset < Integer(ASize) do
  begin
    RecLen := Buf[Offset];
    if RecLen = 0 then
    begin
      // padding ate o final do setor
      Offset := ((Offset div ISO_SECTOR_SIZE) + 1) * ISO_SECTOR_SIZE;
      Continue;
    end;
    if Offset + RecLen > Integer(ASize) then Break;

    ChildExtent := ReadLEUInt32(Buf, Offset + 2);
    ChildSize := ReadLEUInt32(Buf, Offset + 10);
    Flags := Buf[Offset + 25];
    FnLen := Buf[Offset + 32];
    IsDirChild := (Flags and DREC_DIRECTORY) <> 0;

    // skip "." e ".." (FnLen=1, byte=0 ou 1)
    if (FnLen = 1) and ((Buf[Offset + 33] = 0) or (Buf[Offset + 33] = 1)) then
    begin
      Inc(Offset, RecLen);
      Continue;
    end;

    if AIsJoliet then
      Fn := DecodeUcs2Be(Buf, Offset + 33, FnLen)
    else
      Fn := DecodeIso8859(Buf, Offset + 33, FnLen);
    // ISO 9660 strip ";N" version suffix — convencao mantida em Joliet tambem
    if Pos(';', Fn) > 0 then
      Fn := Copy(Fn, 1, Pos(';', Fn) - 1);

    if IsDirChild then
    begin
      // subdir — recursar
      Entry.FullPath := APathPrefix + Fn + '/';
      Entry.Extent := ChildExtent;
      Entry.Size := ChildSize;
      Entry.IsDirectory := True;
      SetLength(FEntries, Length(FEntries) + 1);
      FEntries[High(FEntries)] := Entry;
      ParseDirectoryRecursive(ChildExtent, ChildSize, Entry.FullPath, AIsJoliet);
    end
    else
    begin
      Entry.FullPath := APathPrefix + Fn;
      Entry.Extent := ChildExtent;
      Entry.Size := ChildSize;
      Entry.IsDirectory := False;
      SetLength(FEntries, Length(FEntries) + 1);
      FEntries[High(FEntries)] := Entry;
    end;
    Inc(Offset, RecLen);
  end;
end;

procedure TIsoFile.DoOpenAndIndex;
var
  Vd: TBytes;
  RootExtent, RootSize: Cardinal;
begin
  if not FindBestVolumeDescriptor(Vd, FJolietActive) then
    raise EIsoError.Create('TIsoFile.Open: nao e ISO 9660 valido (assinatura CD001 nao encontrada em sector 16+)');

  // Volume ID em offset 40 (32 bytes ASCII no PVD, UCS-2 BE no Joliet SVD)
  if FJolietActive then
    FVolumeID := TrimRight(DecodeUcs2Be(Vd, 40, 32))
  else
    FVolumeID := TrimRight(DecodeIso8859(Vd, 40, 32));

  // Root directory record em offset 156, 34 bytes
  RootExtent := ReadLEUInt32(Vd, 156 + 2);
  RootSize := ReadLEUInt32(Vd, 156 + 10);
  SetLength(FEntries, 0);
  ParseDirectoryRecursive(RootExtent, RootSize, '', FJolietActive);
end;

procedure TIsoFile.Open;
begin
  if FActive then Exit;
  if FFileName = '' then
    raise EIsoError.Create('TIsoFile.Open: FileName not set');
  FStream := TFileStream.Create(FFileName, fmOpenRead or fmShareDenyWrite);
  FOwnsStream := True;
  try
    DoOpenAndIndex;
    FActive := True;
  except
    FStream.Free;
    FStream := nil;
    FOwnsStream := False;
    raise;
  end;
end;

procedure TIsoFile.Close;
begin
  if FOwnsStream and Assigned(FStream) then
  begin
    FStream.Free;
    FStream := nil;
    FOwnsStream := False;
  end;
  SetLength(FEntries, 0);
  FActive := False;
end;

function TIsoFile.GetEntryCount: Integer;
begin
  Result := Length(FEntries);
end;

function TIsoFile.IsDir(AIndex: Integer): Boolean;
begin
  Result := (AIndex >= 0) and (AIndex < Length(FEntries)) and FEntries[AIndex].IsDirectory;
end;

function TIsoFile.GetFileSize(AIndex: Integer): Int64;
begin
  if (AIndex >= 0) and (AIndex < Length(FEntries)) then
    Result := FEntries[AIndex].Size
  else
    Result := 0;
end;

function TIsoFile.GetEntryName(AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex < Length(FEntries)) then
    Result := FEntries[AIndex].FullPath
  else
    Result := '';
end;

function TIsoFile.FindIndex(const AName: string): Integer;
var I: Integer;
begin
  for I := 0 to High(FEntries) do
    if SameText(FEntries[I].FullPath, AName) then
      Exit(I);
  // Tentar tambem sem '/' trailing
  for I := 0 to High(FEntries) do
    if SameText(FEntries[I].FullPath, AName + '/') then
      Exit(I);
  Result := -1;
end;

function TIsoFile.FileExists(const AName: string): Boolean;
begin
  Result := FindIndex(AName) >= 0;
end;

function TIsoFile.ReadAsBytes(const AName: string): TBytes;
var
  Idx: Integer;
begin
  if not FActive then
    raise EIsoError.Create('TIsoFile.ReadAsBytes: nao aberto');
  Idx := FindIndex(AName);
  if Idx < 0 then
    raise EIsoError.CreateFmt('TIsoFile.ReadAsBytes: entry nao encontrada "%s"', [AName]);
  if FEntries[Idx].IsDirectory then
    raise EIsoError.CreateFmt('TIsoFile.ReadAsBytes: "%s" e um diretorio', [AName]);

  SetLength(Result, FEntries[Idx].Size);
  if FEntries[Idx].Size > 0 then
  begin
    FStream.Position := Int64(FEntries[Idx].Extent) * ISO_SECTOR_SIZE;
    FStream.ReadBuffer(Result[0], FEntries[Idx].Size);
  end;
end;

function TIsoFile.ReadAsString(const AName: string): string;
var B: TBytes;
begin
  B := ReadAsBytes(AName);
  if Length(B) = 0 then
    Result := ''
  else
    Result := TEncoding.UTF8.GetString(B);
end;

function TIsoFile.GetEntryStream(const AName: string): TStream;
var B: TBytes;
begin
  B := ReadAsBytes(AName);
  Result := TMemoryStream.Create;
  if Length(B) > 0 then
    Result.WriteBuffer(B[0], Length(B));
  Result.Position := 0;
end;

function TIsoFile.WithFileName(const APath: string): TIsoFile;
begin
  SetFileName(APath);
  Result := Self;
end;

function TIsoFile.ThatOpens: TIsoFile;
begin
  Open;
  Result := Self;
end;

end.
