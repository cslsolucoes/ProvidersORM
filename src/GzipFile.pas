{ =============================================================================
  GzipFile - absorvido do ZipFileORM v4.0.0 (modulo ZipFile, F1-A Onda A.3)

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
{ GzipFile.pas

  Single-file Gzip (RFC 1952) component. Para o caso comum de comprimir/
  descomprimir UM arquivo (.log.gz, .sql.gz, .txt.gz) sem packaging tar.

  Diferenças vs. TTarGzFile:
  - TTarGzFile = tar + gzip combo (multi-arquivo, virtual filesystem).
  - TGzipFile  = single-file gzip apenas (1 source → 1 .gz; 1 .gz → 1 target).

  API typical:
    GzipFile1.FileName := 'app.log.gz';
    GzipFile1.CompressFromFile('app.log');      // grava .gz
    GzipFile1.DecompressToFile('app.log.out');  // restaura

  Fluent:
    TGzipFile.Create(nil).WithLevel(9).CompressFile('big.sql', 'big.sql.gz');

  Cross-platform: Delphi (Win32/Win64) + FPC (Win32/Win64/Linux i386/x86_64).
}
unit GzipFile;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Classes, Commons.ZipFile.Types, ZipFile.Events, TarFile.GzipStream, Exceptions.Base;

type
  EGzipFileError = class(EExceptionBase);

  TGzipFile = class(TComponent)
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
    // Security
    FOnAskPassword: TArchivePasswordRequestEvent;
    FOnReplaceQuery: TArchiveReplaceQueryEvent;
    FOnVerify: TArchiveVerifyEvent;
    // Diagnostics
    FOnError: TArchiveErrorEvent;
    FOnWarning: TArchiveWarningEvent;
    FOnLog: TArchiveLogEvent;
    FLevel: Integer;
    FOriginalName: string;
    FComment: string;                  // gzip COMMENT header field (RFC 1952)
    FOriginalTimestamp: TDateTime;     // MTIME field — emitted on Compress*; populated by Open
    FOSCode: Byte;                     // OS field (3=Unix, 0=FAT, 11=NTFS, 255=unknown)
    // Read-only — populated after Open ou DecompressTo*.
    FCRC32: LongWord;
    FUncompressedSize: Int64;          // ISIZE field (modulo 2^32 per RFC — Int64 to allow >4GB approx)
    FCompressedSize: Int64;            // physical .gz file size
    // v3.12 extra RFC 1952 / deflate options
    FTextMode: Boolean;                // FTEXT bit (FLG[0]) — likely ASCII text
    FHeaderCRC: Boolean;               // FHCRC bit (FLG[1]) — adds 2-byte CRC16 do header
    FExtraField: TBytes;               // FEXTRA bytes (FLG[2])
    FStrategy: Byte;                   // Deflate strategy: 0=default, 1=filtered, 2=huffman-only,
                                       //   3=RLE, 4=fixed. Default 0.
    FXFL: Byte;                        // XFL byte: 2=max compression, 4=fastest. Auto-set por Level.
    procedure SetActive(AValue: Boolean);
    procedure SetFileName(const AValue: string);
    procedure SetLevel(AValue: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // Abrir/fechar — equivalente a checar se o .gz existe e é legível.
    procedure Open;
    procedure Close;

    // Comprimir.
    procedure CompressFromFile(const ASourcePath: string);
    procedure CompressFromStream(ASource: TStream);
    procedure CompressFromBytes(const ASource: TBytes);
    procedure CompressFromString(const ASource: string);

    // Descomprimir.
    procedure DecompressToFile(const ATargetPath: string);
    procedure DecompressToStream(ATarget: TStream);
    function  DecompressToBytes: TBytes;
    function  DecompressToString: string;

    // One-shot helpers (não exigem FileName / Active).
    class procedure CompressFile(const ASourcePath, ATargetGzPath: string; ALevel: Integer = 6);
    class procedure DecompressFile(const ASourceGzPath, ATargetPath: string);

    // Fluent inline.
    function WithFileName(const APath: string): TGzipFile;
    function WithLevel(ALevel: Integer): TGzipFile;
    function ThatOpens: TGzipFile;
  published
    property Active: Boolean read FActive write SetActive default False;
    property FileName: string read FFileName write SetFileName;

    // ---- Compression knobs ----
    // 1=fast, 9=best, 6=balance.
    property Level: Integer read FLevel write SetLevel default 6;

    // ---- Header metadata (RFC 1952) — emitted on Compress*; reservado para
    // populacao via Open. Implementacao do parser de header gzip fica para v3.2.
    // Original filename (FNAME field).
    property OriginalName: string read FOriginalName write FOriginalName;
    // COMMENT field.
    property Comment: string read FComment write FComment;
    // MTIME field (modification time da fonte). Vazio = grava timestamp atual no compress.
    property OriginalTimestamp: TDateTime read FOriginalTimestamp write FOriginalTimestamp;
    // OS field per RFC 1952: 0=FAT, 3=Unix, 11=NTFS, 255=unknown. Default 255.
    property OSCode: Byte read FOSCode write FOSCode default 255;

    // ---- Advanced gzip flags (RFC 1952) ----
    // FTEXT bit (FLG[0]) — hint que conteudo eh ASCII text.
    property TextMode: Boolean read FTextMode write FTextMode default False;
    // FHCRC bit (FLG[1]) — adiciona CRC16 do header gzip.
    property HeaderCRC: Boolean read FHeaderCRC write FHeaderCRC default False;
    // FEXTRA bytes (FLG[2]) — extension field para aplicacoes especificas.
    property ExtraField: TBytes read FExtraField write FExtraField;
    // Deflate strategy: 0=default, 1=filtered, 2=huffman-only, 3=RLE, 4=fixed.
    property Strategy: Byte read FStrategy write FStrategy default 0;
    // XFL byte: 2 = max compression, 4 = fastest. Auto-set por Level se 0.
    property XFL: Byte read FXFL write FXFL default 0;

    // ---- Read-only file info ----
    property CRC32: LongWord read FCRC32;
    property UncompressedSize: Int64 read FUncompressedSize;
    property CompressedSize: Int64 read FCompressedSize;

    // ---- Events ----
    property OnFileChanged: TNotifyEvent read FOnFileChanged write FOnFileChanged;
    property OnProgress: TZipProgressEvent read FOnProgress write FOnProgress;
    // Lifecycle events
    property OnBeforeOpen: TArchiveLifecycleQueryEvent read FOnBeforeOpen write FOnBeforeOpen;
    property OnAfterOpen: TArchiveLifecycleEvent read FOnAfterOpen write FOnAfterOpen;
    property OnBeforeClose: TArchiveLifecycleQueryEvent read FOnBeforeClose write FOnBeforeClose;
    property OnAfterClose: TArchiveLifecycleEvent read FOnAfterClose write FOnAfterClose;
    property OnAskPassword: TArchivePasswordRequestEvent read FOnAskPassword write FOnAskPassword;
    property OnReplaceQuery: TArchiveReplaceQueryEvent read FOnReplaceQuery write FOnReplaceQuery;
    property OnVerify: TArchiveVerifyEvent read FOnVerify write FOnVerify;
    property OnError: TArchiveErrorEvent read FOnError write FOnError;
    property OnWarning: TArchiveWarningEvent read FOnWarning write FOnWarning;
    property OnLog: TArchiveLogEvent read FOnLog write FOnLog;
  end;

implementation

const
  cReadBufSize = 64 * 1024;

constructor TGzipFile.Create(AOwner: TComponent);
begin
  inherited;
  FLevel := 6;
  FActive := False;
  FOSCode := 255;     // unknown
end;

destructor TGzipFile.Destroy;
begin
  Close;
  inherited;
end;

procedure TGzipFile.SetActive(AValue: Boolean);
begin
  if AValue = FActive then Exit;
  if AValue then Open else Close;
end;

procedure TGzipFile.SetFileName(const AValue: string);
begin
  if AValue = FFileName then Exit;
  Close;
  FFileName := AValue;
  if Assigned(FOnFileChanged) then FOnFileChanged(Self);
end;

procedure TGzipFile.SetLevel(AValue: Integer);
begin
  if (AValue < 1) or (AValue > 9) then
    raise EGzipFileError.CreateFmt('Gzip level must be 1..9 (got %d)', [AValue]);
  FLevel := AValue;
end;

procedure TGzipFile.Open;
begin
  if FFileName = '' then
    raise EGzipFileError.Create('FileName not set');
  if not SysUtils.FileExists(FFileName) then
    raise EGzipFileError.CreateFmt('Gzip file not found: %s', [FFileName]);
  FActive := True;
end;

procedure TGzipFile.Close;
begin
  FActive := False;
end;

// ---------------------------------------------------------------------------
//   Compress
// ---------------------------------------------------------------------------

procedure TGzipFile.CompressFromFile(const ASourcePath: string);
var
  LSrc: TFileStream;
begin
  LSrc := TFileStream.Create(ASourcePath, fmOpenRead or fmShareDenyWrite);
  try
    CompressFromStream(LSrc);
  finally
    LSrc.Free;
  end;
end;

procedure TGzipFile.CompressFromStream(ASource: TStream);
var
  LDst: TFileStream;
  LGz: TGzipWriteStream;
begin
  if FFileName = '' then
    raise EGzipFileError.Create('FileName not set');
  LDst := TFileStream.Create(FFileName, fmCreate);
  try
    LGz := TGzipWriteStream.Create(LDst, FLevel, False);
    try
      ASource.Position := 0;
      LGz.CopyFrom(ASource, 0);
    finally
      LGz.Free;
    end;
  finally
    LDst.Free;
  end;
  FActive := True;
end;

procedure TGzipFile.CompressFromBytes(const ASource: TBytes);
var
  LMs: TMemoryStream;
begin
  LMs := TMemoryStream.Create;
  try
    if Length(ASource) > 0 then
      LMs.WriteBuffer(ASource[0], Length(ASource));
    CompressFromStream(LMs);
  finally
    LMs.Free;
  end;
end;

procedure TGzipFile.CompressFromString(const ASource: string);
var
  LBytes: TBytes;
begin
  LBytes := TEncoding.UTF8.GetBytes(ASource);
  CompressFromBytes(LBytes);
end;

// ---------------------------------------------------------------------------
//   Decompress
// ---------------------------------------------------------------------------

procedure TGzipFile.DecompressToFile(const ATargetPath: string);
var
  LDst: TFileStream;
begin
  LDst := TFileStream.Create(ATargetPath, fmCreate);
  try
    DecompressToStream(LDst);
  finally
    LDst.Free;
  end;
end;

procedure TGzipFile.DecompressToStream(ATarget: TStream);
var
  LSrc: TFileStream;
  LGz: TGzipReadStream;
  LBuf: array[0..cReadBufSize - 1] of Byte;
  LRead: Integer;
begin
  if FFileName = '' then
    raise EGzipFileError.Create('FileName not set');
  if not SysUtils.FileExists(FFileName) then
    raise EGzipFileError.CreateFmt('Gzip file not found: %s', [FFileName]);
  LSrc := TFileStream.Create(FFileName, fmOpenRead or fmShareDenyWrite);
  try
    LGz := TGzipReadStream.Create(LSrc, False);
    try
      repeat
        LRead := LGz.Read(LBuf, cReadBufSize);
        if LRead > 0 then
          ATarget.WriteBuffer(LBuf, LRead);
      until LRead = 0;
    finally
      LGz.Free;
    end;
  finally
    LSrc.Free;
  end;
end;

function TGzipFile.DecompressToBytes: TBytes;
var
  LMs: TMemoryStream;
begin
  LMs := TMemoryStream.Create;
  try
    DecompressToStream(LMs);
    SetLength(Result, LMs.Size);
    if LMs.Size > 0 then
      Move(LMs.Memory^, Result[0], LMs.Size);
  finally
    LMs.Free;
  end;
end;

function TGzipFile.DecompressToString: string;
var
  LBytes: TBytes;
begin
  LBytes := DecompressToBytes;
  Result := TEncoding.UTF8.GetString(LBytes);
end;

// ---------------------------------------------------------------------------
//   One-shot class helpers
// ---------------------------------------------------------------------------

class procedure TGzipFile.CompressFile(const ASourcePath, ATargetGzPath: string; ALevel: Integer);
var
  LGz: TGzipFile;
begin
  LGz := TGzipFile.Create(nil);
  try
    LGz.FFileName := ATargetGzPath;
    LGz.FLevel := ALevel;
    LGz.CompressFromFile(ASourcePath);
  finally
    LGz.Free;
  end;
end;

class procedure TGzipFile.DecompressFile(const ASourceGzPath, ATargetPath: string);
var
  LGz: TGzipFile;
begin
  LGz := TGzipFile.Create(nil);
  try
    LGz.FFileName := ASourceGzPath;
    LGz.DecompressToFile(ATargetPath);
  finally
    LGz.Free;
  end;
end;

// ---------------------------------------------------------------------------
//   Fluent
// ---------------------------------------------------------------------------

function TGzipFile.WithFileName(const APath: string): TGzipFile;
begin
  FileName := APath;
  Result := Self;
end;

function TGzipFile.WithLevel(ALevel: Integer): TGzipFile;
begin
  Level := ALevel;
  Result := Self;
end;

function TGzipFile.ThatOpens: TGzipFile;
begin
  Open;
  Result := Self;
end;

end.
