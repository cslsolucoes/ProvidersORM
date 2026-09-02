{ =============================================================================
  LhaFile - absorvido do ZipFileORM v4.0.0 (modulo ZipFile, F1-A Onda A.3)

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
{ LhaFile.pas

  TLhaFile — READ-only LHA/LZH decoder, pure-pascal.

  Suporta:
   - Header level 0, 1, 2 parsing completo
   - Method `-lh0-` (Store / no compression) — extract direto
   - Listing/metadata para qualquer method (-lh1- a -lh7-, -lzs-, -lz4-, etc.)
   - Detecao de directory entries (-lhd-)

  NAO suporta nesta versao (deferido para v3.3.1):
   - Methods -lh1- a -lh7- (LZSS + static/dynamic Huffman) — ReadAsBytes
     raise ELhaError 'method not supported'
   - Methods -lzs-, -lz4-, -lz5-, -lh8-, -lh9- (legacy/raros)
   - WRITE — apenas READ
   - Multi-volume archives

  Cross-platform: Delphi (Win32/Win64) + FPC (Win32/Win64/Linux i386/x86_64).
  Sem dependencia C — apenas SysUtils + Classes.

  API espelhada de TZipFile/TSevenZFile/TIsoFile.

  Para Store (-lh0-) o decode e trivial (compressed == original). Para
  os methods Huffman, vendor SDK em sdk/lha/src/[slide,huf,dhuf,shuf,larc].c
  pode ser linkado em v3.3.1 via Combined.c wrapper similar ao bzip2.
}
unit LhaFile;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Classes, Commons.ZipFile.Types, ZipFile.Events, LhaFile.Exceptions;

type
  // Exception types relocated to LhaFile.Exceptions.pas (Wave 3b).
  ELhaError = LhaFile.Exceptions.ELhaError;
  ELhaMethodNotSupported = LhaFile.Exceptions.ELhaMethodNotSupported;

  TLhaEntry = record
    FileName: string;
    Method: string;        // "-lh0-", "-lh5-", etc.
    HeaderLevel: Byte;
    PackedSize: Cardinal;
    OriginalSize: Cardinal;
    Timestamp: Cardinal;
    DataOffset: Int64;     // byte offset onde o payload comeca
    FileCRC16: Word;
    IsDirectory: Boolean;
  end;

  TLhaFile = class(TComponent)
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
    FEntries: array of TLhaEntry;
    // Read-only info — populated by DoOpenAndIndex.
    FHeaderLevel: Byte;          // 0, 1, 2 ou 3 (LHA header format variant)
    FOSCode: Byte;               // OS marker per LHA spec ($4D=M=MSDOS, $4A=J=Java,
                                 //   $55=U=Unix, $57=W=Windows, $4D=Mac, etc.)
    FFirstMethod: string;        // ID do primeiro entry (lh0/lh5/lh6/lh7/lhd...)
    FArchiveSize: Int64;         // physical .lha file size
    // v3.12 extras
    FMinorVersion: Byte;         // minor version field per header
    FHeaderChecksum: Byte;       // checksum byte do primeiro header
    FTotalPackedSize: Int64;     // soma dos compressed_size de todos os entries
    FTotalOriginalSize: Int64;   // soma dos original_size de todos os entries
    FHasComment: Boolean;        // archive contains comment block
    FArchiveComment: string;     // archive-level comment (rara em LHA)
    FCompressionRatio: Double;   // TotalPacked / TotalOriginal (read-only metric)

    function ReadByteAt(AOffset: Int64): Byte;
    function ReadLEUInt16At(AOffset: Int64): Word;
    function ReadLEUInt32At(AOffset: Int64): Cardinal;
    procedure ReadBytesAt(AOffset: Int64; var ABuffer: TBytes; ACount: Integer);

    function ParseLevel0Or1Header(AOffset: Int64; out AEntry: TLhaEntry;
      out ANextOffset: Int64): Boolean;
    function ParseLevel2Header(AOffset: Int64; out AEntry: TLhaEntry;
      out ANextOffset: Int64): Boolean;
    function DecodeLh5(const AEntry: TLhaEntry): TBytes;

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
    function GetEntryMethod(AIndex: Integer): string;
    function FindIndex(const AName: string): Integer;
    function GetEntryStream(const AName: string): TStream;
    function ReadAsBytes(const AName: string): TBytes;
    function ReadAsString(const AName: string): string;

    function WithFileName(const APath: string): TLhaFile;
    function ThatOpens: TLhaFile;
  published
    property Active: Boolean read FActive write SetActive;
    property FileName: string read FFileName write SetFileName;
    property EntryCount: Integer read GetEntryCount;

    // ---- Read-only LHA header info ----
    // 0, 1, 2 ou 3 — variante do header LHA (Level-0 mais antigo, Level-2 default moderno).
    property HeaderLevel: Byte read FHeaderLevel;
    // OS marker per LHA spec: 'M'=$4D MSDOS, 'U'=$55 Unix, 'W'=$57 Windows,
    // 'J'=$4A Java/CP932, 'm'=$6D Mac, '2'=$32 OS/2 etc.
    property OSCode: Byte read FOSCode;
    // Compression method ID do primeiro entry: -lh0- (store), -lh5- (LZSS+huffman),
    // -lh6-/-lh7- (LZSS+larger window), -lhd- (directory), etc.
    property FirstMethod: string read FFirstMethod;
    property ArchiveSize: Int64 read FArchiveSize;
    // Minor version field from primary header.
    property MinorVersion: Byte read FMinorVersion;
    // Checksum byte of the first entry header (validation).
    property HeaderChecksum: Byte read FHeaderChecksum;
    // Aggregated sizes across all entries.
    property TotalPackedSize: Int64 read FTotalPackedSize;
    property TotalOriginalSize: Int64 read FTotalOriginalSize;
    // True if archive carries an archive-level comment subblock.
    property HasComment: Boolean read FHasComment;
    property ArchiveComment: string read FArchiveComment;
    // Overall compression ratio (TotalPacked / TotalOriginal). 0.0 if empty.
    property CompressionRatio: Double read FCompressionRatio;

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

constructor TLhaFile.Create(AOwner: TComponent);
begin
  inherited;
  FActive := False;
end;

destructor TLhaFile.Destroy;
begin
  Close;
  inherited;
end;

procedure TLhaFile.SetActive(AValue: Boolean);
begin
  if AValue = FActive then Exit;
  if AValue then Open else Close;
end;

procedure TLhaFile.SetFileName(const AValue: string);
begin
  if AValue = FFileName then Exit;
  Close;
  FFileName := AValue;
  if Assigned(FOnFileChanged) then FOnFileChanged(Self);
end;

function TLhaFile.ReadByteAt(AOffset: Int64): Byte;
begin
  FStream.Position := AOffset;
  FStream.ReadBuffer(Result, 1);
end;

function TLhaFile.ReadLEUInt16At(AOffset: Int64): Word;
var B: array[0..1] of Byte;
begin
  FStream.Position := AOffset;
  FStream.ReadBuffer(B[0], 2);
  Result := Word(B[0]) or (Word(B[1]) shl 8);
end;

function TLhaFile.ReadLEUInt32At(AOffset: Int64): Cardinal;
var B: array[0..3] of Byte;
begin
  FStream.Position := AOffset;
  FStream.ReadBuffer(B[0], 4);
  Result := Cardinal(B[0]) or (Cardinal(B[1]) shl 8) or
            (Cardinal(B[2]) shl 16) or (Cardinal(B[3]) shl 24);
end;

procedure TLhaFile.ReadBytesAt(AOffset: Int64; var ABuffer: TBytes; ACount: Integer);
begin
  if Length(ABuffer) < ACount then SetLength(ABuffer, ACount);
  if ACount <= 0 then Exit;
  FStream.Position := AOffset;
  FStream.ReadBuffer(ABuffer[0], ACount);
end;

// Level 0/1: header size byte + 21 bytes fixed + filename + CRC + extended.
// Layout (offsets relativos ao inicio do header, antes do header_size byte):
//   -1: (nada — header_size eh o primeiro byte do header)
//    0: header_size (1 byte) - tamanho do header excluindo este byte e checksum
//    1: header_sum (1 byte)
//    2: method[5]
//    7: packed_size (4 bytes LE)
//   11: original_size (4 bytes LE)
//   15: time/date (4 bytes MSDOS)
//   19: attribute (1 byte)
//   20: level (1 byte)
//   21: fname_len (1 byte)
//   22: filename (fname_len bytes)
//   22+fname_len: file_crc (2 bytes LE)
//   24+fname_len: extended area
//   23+header_size: comeco do payload
function TLhaFile.ParseLevel0Or1Header(AOffset: Int64;
  out AEntry: TLhaEntry; out ANextOffset: Int64): Boolean;
var
  HdrSize: Byte;
  HdrBuf: TBytes;
  Method: string;
  FnLen: Byte;
  Level: Byte;
  HeaderEnd: Int64;
  DataStart: Int64;
  Attr: Byte;
  AnsiName: AnsiString;
  ExtOffset: Int64;
  ExtSize: Word;
  ExtTotalBytes: Int64;
begin
  Result := False;
  HdrSize := ReadByteAt(AOffset);
  if HdrSize = 0 then Exit;  // end of archive

  // Read fixed part (22 bytes after AOffset)
  ReadBytesAt(AOffset + 2, HdrBuf, 20);
  Method := '';
  Method := Char(HdrBuf[0]) + Char(HdrBuf[1]) + Char(HdrBuf[2]) +
            Char(HdrBuf[3]) + Char(HdrBuf[4]);
  AEntry.Method := Method;
  AEntry.PackedSize := Cardinal(HdrBuf[5]) or (Cardinal(HdrBuf[6]) shl 8) or
                       (Cardinal(HdrBuf[7]) shl 16) or (Cardinal(HdrBuf[8]) shl 24);
  AEntry.OriginalSize := Cardinal(HdrBuf[9]) or (Cardinal(HdrBuf[10]) shl 8) or
                         (Cardinal(HdrBuf[11]) shl 16) or (Cardinal(HdrBuf[12]) shl 24);
  AEntry.Timestamp := Cardinal(HdrBuf[13]) or (Cardinal(HdrBuf[14]) shl 8) or
                      (Cardinal(HdrBuf[15]) shl 16) or (Cardinal(HdrBuf[16]) shl 24);
  Attr := HdrBuf[17];
  Level := HdrBuf[18];
  FnLen := HdrBuf[19];
  AEntry.HeaderLevel := Level;
  AEntry.IsDirectory := (Method = '-lhd-') or ((Attr and $10) <> 0);

  // Filename (FnLen bytes at offset AOffset + 22) — single-byte ASCII/CP
  // codepage. Read into AnsiString primeiro, depois converte para string
  // Unicode preservando bytes (assume ASCII/OEM).
  ReadBytesAt(AOffset + 22, HdrBuf, FnLen);
  if FnLen > 0 then
  begin
    SetLength(AnsiName, FnLen);
    Move(HdrBuf[0], AnsiName[1], FnLen);
    AEntry.FileName := string(AnsiName);
  end
  else
    AEntry.FileName := '';
  // Normalize backslash to forward slash for path consistency
  AEntry.FileName := StringReplace(AEntry.FileName, '\', '/', [rfReplaceAll]);

  // File CRC at offset 22 + FnLen
  AEntry.FileCRC16 := ReadLEUInt16At(AOffset + 22 + FnLen);

  // Data starts after the header. header_size = total header bytes EXCLUDING
  // the leading header_size byte and the checksum byte. So data starts at:
  //   AOffset + 2 + HdrSize  (level 0/1)
  // BUT level 1 has additional extended-header chain after CRC; HdrSize ja
  // engloba a parte fixa (22 bytes - 2) + filename + crc; o ext-header chain
  // segue depois apos um OS-id byte. Para simplificar, level 1 calculamos
  // o data offset incrementalmente seguindo a chain. Level 0 nao tem chain.
  HeaderEnd := AOffset + 2 + HdrSize;  // posicao logica do fim do header level0
  DataStart := HeaderEnd;

  if Level = 1 then
  begin
    // Apos o CRC (offset 22+FnLen+2 = 24+FnLen) vem 1 byte OS-id, depois
    // chain de ext-headers cada um: 2 bytes (LE size) + (size-2) bytes data.
    // Chain termina quando size == 0. Cada ext-header EXTRA conta para o
    // packed_size... essa eh a peculiaridade do level 1.
    ExtOffset := HeaderEnd;  // chain comeca apos o fixed part inclusive OS-id
    ExtTotalBytes := 0;
    while True do
    begin
      ExtSize := ReadLEUInt16At(ExtOffset);
      if ExtSize = 0 then
      begin
        Inc(ExtOffset, 2);
        Inc(ExtTotalBytes, 2);
        Break;
      end;
      Inc(ExtOffset, ExtSize);
      Inc(ExtTotalBytes, ExtSize);
      if ExtTotalBytes > 1024 * 1024 then
        raise ELhaError.Create('LHA level 1: ext-header chain corrupt or unreasonable');
    end;
    // Para level 1, packed_size do header inclui os ext-headers. Compensamos
    // subtraindo ExtTotalBytes do payload effective. Mas DataStart = end of chain.
    DataStart := ExtOffset;
    if AEntry.PackedSize >= ExtTotalBytes then
      AEntry.PackedSize := AEntry.PackedSize - Cardinal(ExtTotalBytes)
    else
      AEntry.PackedSize := 0;
  end;

  AEntry.DataOffset := DataStart;
  ANextOffset := DataStart + AEntry.PackedSize;
  Result := True;
end;

// Level 2: header_size eh 2 bytes LE, layout diferente.
//   0: header_size (2 bytes LE)
//   2: method[5]
//   7: packed_size (4 bytes LE)
//  11: original_size (4 bytes LE)
//  15: timestamp Unix (4 bytes LE)
//  19: reserved 0x20 (1 byte)
//  20: level (1 byte) = 2
//  21: file_crc (2 bytes LE)
//  23: OS-id (1 byte)
//  24: ext-headers chain (each: 2 bytes size LE + (size-2) bytes data)
//  end: header_size bytes total from offset 0.
//  payload starts at AOffset + header_size.
function TLhaFile.ParseLevel2Header(AOffset: Int64;
  out AEntry: TLhaEntry; out ANextOffset: Int64): Boolean;
var
  HdrSize: Word;
  HdrBuf: TBytes;
  Method: string;
  ExtOffset: Int64;
  ExtSize: Word;
  ExtId: Byte;
  Fn, DirName: string;
  FnAnsi, DirAnsi: AnsiString;
begin
  Result := False;
  HdrSize := ReadLEUInt16At(AOffset);
  if HdrSize = 0 then Exit;

  ReadBytesAt(AOffset + 2, HdrBuf, 22);
  Method := Char(HdrBuf[0]) + Char(HdrBuf[1]) + Char(HdrBuf[2]) +
            Char(HdrBuf[3]) + Char(HdrBuf[4]);
  AEntry.Method := Method;
  AEntry.PackedSize := Cardinal(HdrBuf[5]) or (Cardinal(HdrBuf[6]) shl 8) or
                       (Cardinal(HdrBuf[7]) shl 16) or (Cardinal(HdrBuf[8]) shl 24);
  AEntry.OriginalSize := Cardinal(HdrBuf[9]) or (Cardinal(HdrBuf[10]) shl 8) or
                         (Cardinal(HdrBuf[11]) shl 16) or (Cardinal(HdrBuf[12]) shl 24);
  AEntry.Timestamp := Cardinal(HdrBuf[13]) or (Cardinal(HdrBuf[14]) shl 8) or
                      (Cardinal(HdrBuf[15]) shl 16) or (Cardinal(HdrBuf[16]) shl 24);
  AEntry.HeaderLevel := HdrBuf[18];
  AEntry.FileCRC16 := Word(HdrBuf[19]) or (Word(HdrBuf[20]) shl 8);
  AEntry.IsDirectory := (Method = '-lhd-');

  // Ext-header chain starts at offset 24 (apos OS-id)
  // Filename eh codificado em um dos ext-headers (header id 0x01).
  ExtOffset := AOffset + 24;
  Fn := '';
  while ExtOffset < AOffset + HdrSize do
  begin
    ExtSize := ReadLEUInt16At(ExtOffset);
    if ExtSize < 3 then Break;  // tamanho minimo: 2 (size) + 1 (id)
    ExtId := ReadByteAt(ExtOffset + 2);
    if ExtId = $01 then  // filename header
    begin
      ReadBytesAt(ExtOffset + 3, HdrBuf, ExtSize - 3);
      SetLength(FnAnsi, ExtSize - 3);
      if ExtSize > 3 then
        Move(HdrBuf[0], FnAnsi[1], ExtSize - 3);
      Fn := string(FnAnsi);
    end
    else if ExtId = $02 then  // directory header — concatenar
    begin
      ReadBytesAt(ExtOffset + 3, HdrBuf, ExtSize - 3);
      SetLength(DirAnsi, ExtSize - 3);
      if ExtSize > 3 then
        Move(HdrBuf[0], DirAnsi[1], ExtSize - 3);
      DirName := string(DirAnsi);
      // Diretorios usam 0xFF como separator; convertemos para '/'
      DirName := StringReplace(DirName, Char($FF), '/', [rfReplaceAll]);
      if (Length(DirName) > 0) and (DirName[Length(DirName)] <> '/') then
        DirName := DirName + '/';
      Fn := DirName + Fn;
    end;
    Inc(ExtOffset, ExtSize);
    if ExtOffset > AOffset + HdrSize + 65536 then
      raise ELhaError.Create('LHA level 2: ext-header chain corrupt');
  end;
  AEntry.FileName := StringReplace(Fn, '\', '/', [rfReplaceAll]);

  AEntry.DataOffset := AOffset + HdrSize;
  ANextOffset := AEntry.DataOffset + AEntry.PackedSize;
  Result := True;
end;

procedure TLhaFile.DoOpenAndIndex;
var
  Offset: Int64;
  NextOffset: Int64;
  HeaderFirstByte: Byte;
  Level: Byte;
  LevelProbe: TBytes;
  Entry: TLhaEntry;
  Ok: Boolean;
begin
  SetLength(FEntries, 0);
  Offset := 0;
  while Offset < FStream.Size do
  begin
    HeaderFirstByte := ReadByteAt(Offset);
    if HeaderFirstByte = 0 then Break;  // end of archive marker

    // Detectar level: ler byte 20 do header (offset Offset+20).
    // Level 0/1: byte at offset 20 = level (0 ou 1).
    // Level 2: byte at offset 20 = level (2). Header size eh 2 bytes em vez de 1.
    if Offset + 21 >= FStream.Size then Break;
    ReadBytesAt(Offset, LevelProbe, 21);
    Level := LevelProbe[20];

    case Level of
      0, 1: Ok := ParseLevel0Or1Header(Offset, Entry, NextOffset);
      2:    Ok := ParseLevel2Header(Offset, Entry, NextOffset);
    else
      raise ELhaError.CreateFmt('LHA: header level %d nao suportado em offset %d', [Level, Offset]);
    end;

    if not Ok then Break;
    SetLength(FEntries, Length(FEntries) + 1);
    FEntries[High(FEntries)] := Entry;
    Offset := NextOffset;
  end;
end;

procedure TLhaFile.Open;
begin
  if FActive then Exit;
  if FFileName = '' then
    raise ELhaError.Create('TLhaFile.Open: FileName not set');
  FStream := TFileStream.Create(FFileName, fmOpenRead or fmShareDenyWrite);
  try
    DoOpenAndIndex;
    FActive := True;
  except
    FStream.Free;
    FStream := nil;
    raise;
  end;
end;

procedure TLhaFile.Close;
begin
  if Assigned(FStream) then
  begin
    FStream.Free;
    FStream := nil;
  end;
  SetLength(FEntries, 0);
  FActive := False;
end;

function TLhaFile.GetEntryCount: Integer;
begin
  Result := Length(FEntries);
end;

function TLhaFile.IsDir(AIndex: Integer): Boolean;
begin
  Result := (AIndex >= 0) and (AIndex < Length(FEntries)) and FEntries[AIndex].IsDirectory;
end;

function TLhaFile.GetFileSize(AIndex: Integer): Int64;
begin
  if (AIndex >= 0) and (AIndex < Length(FEntries)) then
    Result := FEntries[AIndex].OriginalSize
  else
    Result := 0;
end;

function TLhaFile.GetEntryName(AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex < Length(FEntries)) then
    Result := FEntries[AIndex].FileName
  else
    Result := '';
end;

function TLhaFile.GetEntryMethod(AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex < Length(FEntries)) then
    Result := FEntries[AIndex].Method
  else
    Result := '';
end;

function TLhaFile.FindIndex(const AName: string): Integer;
var I: Integer;
begin
  for I := 0 to High(FEntries) do
    if SameText(FEntries[I].FileName, AName) then
      Exit(I);
  Result := -1;
end;

function TLhaFile.FileExists(const AName: string): Boolean;
begin
  Result := FindIndex(AName) >= 0;
end;

function TLhaFile.ReadAsBytes(const AName: string): TBytes;
var
  Idx: Integer;
begin
  if not FActive then
    raise ELhaError.Create('TLhaFile.ReadAsBytes: nao aberto');
  Idx := FindIndex(AName);
  if Idx < 0 then
    raise ELhaError.CreateFmt('TLhaFile.ReadAsBytes: entry nao encontrada "%s"', [AName]);
  if FEntries[Idx].IsDirectory then
    raise ELhaError.CreateFmt('TLhaFile.ReadAsBytes: "%s" eh um diretorio', [AName]);

  // Decompressao: apenas Store (-lh0-) implementada em pure-pascal.
  // Methods Huffman-based (-lh1- a -lh7-, -lzs-) requerem decoder LZSS +
  // tabela Huffman — deferidos para v3.3.1 (provavelmente static-link
  // SDK sdk/lha/src/{huf,dhuf,shuf,larc,slide}.c via Combined.c).
  if FEntries[Idx].Method = '-lh0-' then
  begin
    // Store: copy raw bytes
    SetLength(Result, FEntries[Idx].OriginalSize);
    if FEntries[Idx].OriginalSize > 0 then
    begin
      FStream.Position := FEntries[Idx].DataOffset;
      FStream.ReadBuffer(Result[0], FEntries[Idx].OriginalSize);
    end;
  end
  else if (FEntries[Idx].Method = '-lh4-') or (FEntries[Idx].Method = '-lh5-') or
          (FEntries[Idx].Method = '-lh6-') or (FEntries[Idx].Method = '-lh7-') then
  begin
    // v3.3.2 LH5+ decoder (LZSS + static Huffman). Pascal port derivado
    // de sdk/lha/src/[huf,bitio,maketbl,slide].c
    Result := DecodeLh5(FEntries[Idx]);
  end
  else
    raise ELhaMethodNotSupported.CreateFmt(
      'TLhaFile.ReadAsBytes: method "%s" nao suportado (suportados: -lh0- Store, -lh4-/-lh5-/-lh6-/-lh7- LZSS+Huf)',
      [FEntries[Idx].Method]);
end;

function TLhaFile.ReadAsString(const AName: string): string;
var B: TBytes;
begin
  B := ReadAsBytes(AName);
  if Length(B) = 0 then
    Result := ''
  else
    Result := TEncoding.UTF8.GetString(B);
end;

function TLhaFile.GetEntryStream(const AName: string): TStream;
var B: TBytes;
begin
  B := ReadAsBytes(AName);
  Result := TMemoryStream.Create;
  if Length(B) > 0 then
    Result.WriteBuffer(B[0], Length(B));
  Result.Position := 0;
end;

// =============================================================================
//   v3.3.2 LH4/5/6/7 decoder — LZSS + static Huffman pure-pascal port
//   derivado de sdk/lha/src/[huf,bitio,maketbl,slide].c
// =============================================================================
//
// Constantes do LHA spec (lha_macro.h):
//   THRESHOLD=3, MAXMATCH=256
//   NC = 255 + 256 + 2 - 3 = 510  (number of c_table codes)
//   NP_LH5 = 14 (dicbit=13 + 1), NP_LH6 = 16, NP_LH7 = 17
//   NT = 19 (USHRT_BIT 16 + 3)
//
// LZ77 dictionary com window de 2^dicbit bytes (lh4=4KB, lh5=8KB,
// lh6=32KB, lh7=64KB).
//
// Algorithm: bloco-estruturado. Cada bloco tem:
//   1. blocksize (16 bits) = numero de codes neste bloco
//   2. pt_len[NT] tabela de comprimentos (codificada compactamente)
//   3. c_len[NC] tabela de comprimentos (codificada via pt_len Huffman)
//   4. pt_len[NP] tabela para position codes (re-encoded)
//   5. blocksize codes (literal byte 0..255 ou match-length 256..NC-1).
//      Se match: position code segue, depois extra-bits.

const
  LH_THRESHOLD = 3;
  LH_MAXMATCH  = 256;
  LH_NC        = 510;        // 255 + 256 + 2 - 3
  LH_NT        = 19;         // USHRT_BIT(16) + 3
  LH_NP_LH5    = 14;         // dicbit=13 + 1
  LH_NP_LH6    = 16;
  LH_NP_LH7    = 17;
  LH_CBIT      = 9;          // smallest such that (1 << CBIT) > NC
  LH_TBIT      = 5;

type
  TWordArray = array[0..65535] of Word;
  PWordArray = ^TWordArray;

  // Match SDK bitio.c exactly: bitbuf=unsigned short (16-bit MSB-aligned),
  // subbitbuf=byte holding bits being shifted in, bitcount=valid in subbitbuf.
  TLhaDecodeCtx = record
    Inp: PByte;             // input buffer cursor
    InpEnd: PByte;
    Bitbuf: Word;
    SubBitbuf: Byte;
    BitCount: Byte;

    Dicbit: Integer;
    Np: Integer;
    Pbit: Integer;
    Blocksize: Word;

    CTable: array[0..4095] of Word;
    CLen: array[0..LH_NC-1] of Byte;
    PtTable: array[0..255] of Word;
    PtLen: array[0..LH_NT-1] of Byte;
    Left: array[0..2*LH_NC-2] of Word;
    Right: array[0..2*LH_NC-2] of Word;
  end;

procedure LhaFillBuf(var Ctx: TLhaDecodeCtx; N: Integer);
var
  B: Byte;
begin
  while N > Ctx.BitCount do
  begin
    Dec(N, Ctx.BitCount);
    Ctx.Bitbuf := (Ctx.Bitbuf shl Ctx.BitCount) or (Ctx.SubBitbuf shr (8 - Ctx.BitCount));
    if Ctx.Inp < Ctx.InpEnd then
    begin
      B := Ctx.Inp^;
      Inc(Ctx.Inp);
    end
    else
      B := 0;
    Ctx.SubBitbuf := B;
    Ctx.BitCount := 8;
  end;
  Dec(Ctx.BitCount, N);
  Ctx.Bitbuf := (Ctx.Bitbuf shl N) or (Ctx.SubBitbuf shr (8 - N));
  Ctx.SubBitbuf := Ctx.SubBitbuf shl N;
end;

function LhaGetBits(var Ctx: TLhaDecodeCtx; N: Integer): Cardinal;
begin
  Result := Ctx.Bitbuf shr (16 - N);
  LhaFillBuf(Ctx, N);
end;

function LhaPeekBits(var Ctx: TLhaDecodeCtx; N: Integer): Cardinal; inline;
begin
  Result := Ctx.Bitbuf shr (16 - N);
end;

// Make Huffman decode table — port direto de sdk/lha/src/maketbl.c
function LhaMakeTable(var Ctx: TLhaDecodeCtx;
  NChar: Integer; const BitLen: array of Byte;
  TableBits: Integer; Table: PWord): Integer;
var
  Count: array[0..17] of Word;
  Weight: array[0..17] of Cardinal;
  Start: array[0..17] of Cardinal;
  Total: Cardinal;
  I, J, K, L, M, N: Integer;
  Avail: Integer;
  TableSize: Integer;
  Ptr: PWord;
  Idx: Cardinal;
begin
  Result := 0;
  for I := 1 to 16 do
  begin
    Count[I] := 0;
    Weight[I] := UInt32(1) shl (16 - I);
  end;
  for I := 0 to NChar - 1 do
  begin
    if BitLen[I] > 16 then Exit(1);
    Inc(Count[BitLen[I]]);
  end;
  Total := 0;
  for I := 1 to 16 do
  begin
    Start[I] := Total;
    Inc(Total, Cardinal(Count[I]) * Weight[I]);
  end;
  if ((Total and $FFFF) <> 0) or (NChar = 0) then Exit(1);

  M := 16 - TableBits;
  for I := 1 to TableBits do
  begin
    Start[I] := Start[I] shr M;
    Weight[I] := Weight[I] shr M;
  end;

  TableSize := 1 shl TableBits;
  if TableSize > 4096 then TableSize := 4096;
  // initialize unused entries to 0
  J := Integer(Start[TableBits + 1] shr M);
  for I := J to TableSize - 1 do PWordArray(Table)^[I] := 0;

  Avail := NChar;
  for K := 0 to NChar - 1 do
  begin
    L := BitLen[K];
    if L = 0 then Continue;
    if L <= TableBits then
    begin
      // code fits in table — direct fill
      I := Integer(Start[L]);
      M := I + Integer(Weight[L]);
      if M > TableSize then M := TableSize;
      while I < M do
      begin
        PWordArray(Table)^[I] := Word(K);
        Inc(I);
      end;
      Start[L] := Cardinal(I);
    end
    else
    begin
      // long code — traverse tree
      Idx := Start[L];
      Ptr := @PWordArray(Table)^[Idx shr (16 - TableBits)];
      Idx := Idx shl TableBits;
      N := L - TableBits;
      while N > 0 do
      begin
        Dec(N);
        if Ptr^ = 0 then
        begin
          Ctx.Right[Avail] := 0;
          Ctx.Left[Avail] := 0;
          Ptr^ := Word(Avail);
          Inc(Avail);
        end;
        if (Idx and $8000) <> 0 then
          Ptr := @Ctx.Right[Ptr^]
        else
          Ptr := @Ctx.Left[Ptr^];
        Idx := (Idx shl 1) and $FFFF;
      end;
      Ptr^ := Word(K);
      Start[L] := Start[L] + Weight[L];
    end;
  end;
end;

procedure LhaReadPtLen(var Ctx: TLhaDecodeCtx; Nn, Nbit, ISpecial: Integer);
var
  I, C, N: Integer;
  Mask: Cardinal;
begin
  N := LhaGetBits(Ctx, Nbit);
  if N = 0 then
  begin
    C := LhaGetBits(Ctx, Nbit);
    for I := 0 to Nn - 1 do Ctx.PtLen[I] := 0;
    for I := 0 to 255 do Ctx.PtTable[I] := Word(C);
    Exit;
  end;
  I := 0;
  while I < N do
  begin
    C := LhaPeekBits(Ctx, 3);
    if C <> 7 then
      LhaFillBuf(Ctx, 3)
    else
    begin
      Mask := $8000 shr 3;  // bit position 12 (after 3 consumed by peek)
      while (Ctx.Bitbuf and Mask) <> 0 do
      begin
        Mask := Mask shr 1;
        Inc(C);
      end;
      LhaFillBuf(Ctx, C - 3);
    end;
    Ctx.PtLen[I] := Byte(C);
    Inc(I);
    if I = ISpecial then
    begin
      C := LhaGetBits(Ctx, 2);
      while (C > 0) and (I < Nn) do
      begin
        Ctx.PtLen[I] := 0;
        Inc(I);
        Dec(C);
      end;
    end;
  end;
  while I < Nn do
  begin
    Ctx.PtLen[I] := 0;
    Inc(I);
  end;
  LhaMakeTable(Ctx, Nn, Ctx.PtLen, 8, @Ctx.PtTable[0]);
end;

procedure LhaReadCLen(var Ctx: TLhaDecodeCtx);
var
  I, C, N: Integer;
  Mask: Cardinal;
begin
  N := LhaGetBits(Ctx, LH_CBIT);
  if N = 0 then
  begin
    C := LhaGetBits(Ctx, LH_CBIT);
    for I := 0 to LH_NC - 1 do Ctx.CLen[I] := 0;
    for I := 0 to 4095 do Ctx.CTable[I] := Word(C);
    Exit;
  end;
  I := 0;
  while I < N do
  begin
    C := Ctx.PtTable[LhaPeekBits(Ctx, 8)];
    if C >= LH_NT then
    begin
      Mask := UInt32(1) shl (16 - 9);
      repeat
        if (Ctx.Bitbuf and Mask) <> 0 then C := Ctx.Right[C]
        else C := Ctx.Left[C];
        Mask := Mask shr 1;
      until C < LH_NT;
    end;
    LhaFillBuf(Ctx, Ctx.PtLen[C]);
    if C <= 2 then
    begin
      if C = 0 then C := 1
      else if C = 1 then C := Integer(LhaGetBits(Ctx, 4)) + 3
      else C := Integer(LhaGetBits(Ctx, LH_CBIT)) + 20;
      while (C > 0) and (I < LH_NC) do
      begin
        Ctx.CLen[I] := 0;
        Inc(I);
        Dec(C);
      end;
    end
    else
    begin
      Ctx.CLen[I] := Byte(C - 2);
      Inc(I);
    end;
  end;
  while I < LH_NC do
  begin
    Ctx.CLen[I] := 0;
    Inc(I);
  end;
  LhaMakeTable(Ctx, LH_NC, Ctx.CLen, 12, @Ctx.CTable[0]);
end;

function LhaDecodeC(var Ctx: TLhaDecodeCtx): Word;
var
  J: Word;
  Mask: Cardinal;
begin
  if Ctx.Blocksize = 0 then
  begin
    Ctx.Blocksize := Word(LhaGetBits(Ctx, 16));
    LhaReadPtLen(Ctx, LH_NT, LH_TBIT, 3);
    LhaReadCLen(Ctx);
    LhaReadPtLen(Ctx, Ctx.Np, Ctx.Pbit, -1);
  end;
  Dec(Ctx.Blocksize);
  J := Ctx.CTable[LhaPeekBits(Ctx, 12)];
  if J < LH_NC then
    LhaFillBuf(Ctx, Ctx.CLen[J])
  else
  begin
    LhaFillBuf(Ctx, 12);
    Mask := $8000;
    repeat
      if (Ctx.Bitbuf and Mask) <> 0 then J := Ctx.Right[J]
      else J := Ctx.Left[J];
      Mask := Mask shr 1;
    until J < LH_NC;
    LhaFillBuf(Ctx, Ctx.CLen[J] - 12);
  end;
  Result := J;
end;

function LhaDecodeP(var Ctx: TLhaDecodeCtx): Word;
var
  J: Word;
  Mask: Cardinal;
begin
  J := Ctx.PtTable[LhaPeekBits(Ctx, 8)];
  if J < Ctx.Np then
    LhaFillBuf(Ctx, Ctx.PtLen[J])
  else
  begin
    LhaFillBuf(Ctx, 8);
    Mask := $8000;
    repeat
      if (Ctx.Bitbuf and Mask) <> 0 then J := Ctx.Right[J]
      else J := Ctx.Left[J];
      Mask := Mask shr 1;
    until J < Ctx.Np;
    LhaFillBuf(Ctx, Ctx.PtLen[J] - 8);
  end;
  if J <> 0 then
    J := Word((1 shl (J - 1)) + Integer(LhaGetBits(Ctx, J - 1)));
  Result := J;
end;

function TLhaFile.DecodeLh5(const AEntry: TLhaEntry): TBytes;
var
  Ctx: TLhaDecodeCtx;
  InBuf: TBytes;
  DicBit, DictSize: Integer;
  Dict: TBytes;
  DictMask: Cardinal;
  WritePos: Cardinal;
  OutPos: Cardinal;
  Decoded: Cardinal;
  C: Word;
  P: Word;
  MatchOff: Cardinal;
  K: Integer;
begin
  // Read packed data into memory
  SetLength(InBuf, AEntry.PackedSize);
  FStream.Position := AEntry.DataOffset;
  if AEntry.PackedSize > 0 then
    FStream.ReadBuffer(InBuf[0], AEntry.PackedSize);

  // Dicbit per method
  if AEntry.Method = '-lh4-' then DicBit := 12
  else if AEntry.Method = '-lh5-' then DicBit := 13
  else if AEntry.Method = '-lh6-' then DicBit := 15
  else if AEntry.Method = '-lh7-' then DicBit := 16
  else raise ELhaError.CreateFmt('LH method desconhecido: %s', [AEntry.Method]);

  // Init context
  FillChar(Ctx, SizeOf(Ctx), 0);
  Ctx.Inp := PByte(InBuf);
  Ctx.InpEnd := Ctx.Inp + Length(InBuf);
  Ctx.Bitcount := 0;
  Ctx.Dicbit := DicBit;
  if DicBit <= 13 then begin Ctx.Pbit := 4; Ctx.Np := LH_NP_LH5; end
  else if DicBit = 15 then begin Ctx.Pbit := 5; Ctx.Np := LH_NP_LH6; end
  else                begin Ctx.Pbit := 5; Ctx.Np := LH_NP_LH7; end;
  Ctx.Blocksize := 0;
  // Prime the bit buffer (2 bytes initially per LHA convention)
  LhaFillBuf(Ctx, 16);

  // Setup dictionary
  DictSize := 1 shl DicBit;
  SetLength(Dict, DictSize);
  DictMask := Cardinal(DictSize - 1);
  WritePos := 0;
  SetLength(Result, AEntry.OriginalSize);
  OutPos := 0;
  Decoded := 0;

  while Decoded < AEntry.OriginalSize do
  begin
    C := LhaDecodeC(Ctx);
    if C < 256 then
    begin
      // Literal byte
      Result[OutPos] := Byte(C);
      Dict[WritePos] := Byte(C);
      WritePos := (WritePos + 1) and DictMask;
      Inc(OutPos);
      Inc(Decoded);
    end
    else
    begin
      // Match: length = C - (256 - LH_THRESHOLD)
      K := Integer(C) - 256 + LH_THRESHOLD;
      P := LhaDecodeP(Ctx);
      MatchOff := (WritePos - Cardinal(P) - 1) and DictMask;
      while (K > 0) and (Decoded < AEntry.OriginalSize) do
      begin
        Result[OutPos] := Dict[MatchOff];
        Dict[WritePos] := Dict[MatchOff];
        MatchOff := (MatchOff + 1) and DictMask;
        WritePos := (WritePos + 1) and DictMask;
        Inc(OutPos);
        Inc(Decoded);
        Dec(K);
      end;
    end;
  end;
end;

function TLhaFile.WithFileName(const APath: string): TLhaFile;
begin
  SetFileName(APath);
  Result := Self;
end;

function TLhaFile.ThatOpens: TLhaFile;
begin
  Open;
  Result := Self;
end;

end.
