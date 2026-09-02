{ TarGzFile.pas

  Combo TAR + Gzip — wraps TTarFile (POSIX ustar) com layer Gzip transparent
  permitindo arquivos .tar.gz / .tgz comuns em ecossistema Unix/Docker/CI.

  Implementação:
  - Read: descomprime gzip para memória, abre TTarFile no buffer descomprimido
  - Write: escreve TAR em memória, comprime para o arquivo .tar.gz final

  Para arquivos grandes (>100MB), considere TTarFile direto + TGzipReadStream
  manual em vez deste wrapper (que carrega tudo em RAM).
}
unit TarGzFile;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Classes, Commons.ZipFile.Types, ZipFile.Events, TarFile, TarFile.GzipStream, Exceptions.Base;

type
  ETarGzError = class(EExceptionBase);

  TTarGzFile = class(TComponent)
  protected
    FInner: TTarFile;
    FTempBuffer: TMemoryStream;
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
    FGzipLevel: Integer;
    // Tar-level config (espelha TTarFile)
    FFormat: TTarFormat;
    FPreserveOwnership: Boolean;
    FPreserveTimestamps: Boolean;
    FDefaultMode: Cardinal;
    FOwnerName: string;
    FGroupName: string;
    FBlockSize: Integer;
    FBlockingFactor: Integer;
    FSparse: Boolean;
    FUnixPermissions: Boolean;
    FAddPaxExtensions: Boolean;
    // Gzip-level metadata (RFC 1952)
    FGzipComment: string;
    FGzipOriginalName: string;
    FGzipTextMode: Boolean;
    FGzipHeaderCRC: Boolean;
    FGzipStrategy: Byte;
    FGzipOSCode: Byte;
    FGzipExtraField: TBytes;
    // Read-only
    FArchiveSize: Int64;
    procedure SetActive(AValue: Boolean);
    procedure SetFileName(const AValue: string);
    procedure SetGzipLevel(AValue: Integer);
    procedure LoadFromGz(const APath: string);
    procedure SaveToGz(const APath: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Open;
    procedure Close;
    procedure Save;
    function GetEntryCount: Integer;
    function FileExists(const AName: string): Boolean;
    function GetEntryStream(const AName: string): TStream;
    function ReadAsString(const AName: string): string;
    function ReadAsBytes(const AName: string): TBytes;
    procedure AppendStream(AStream: TStream; const AName: string; AModTime: TDateTime);
    procedure AppendFileFromDisk(const ADiskPath, AArchiveName: string);
    procedure AppendBytes(const ABytes: TBytes; const AName: string);
    procedure AppendString(const AContent: string; const AName: string);
    // Fluent inline
    function WithFileName(const APath: string): TTarGzFile;
    function WithGzipLevel(ALevel: Integer): TTarGzFile;
    function ThatOpens: TTarGzFile;
  published
    property Active: Boolean read FActive write SetActive;
    property FileName: string read FFileName write SetFileName;
    property EntryCount: Integer read GetEntryCount;

    // ---- Gzip layer ----
    // 1=fast, 9=best, 6=balance. Default 6.
    property GzipLevel: Integer read FGzipLevel write SetGzipLevel default 6;
    // RFC 1952 metadata para o wrapper gzip externo.
    property GzipComment: string read FGzipComment write FGzipComment;
    property GzipOriginalName: string read FGzipOriginalName write FGzipOriginalName;

    // ---- Tar layer (espelha TTarFile) ----
    property Format: TTarFormat read FFormat write FFormat default tfUstar;
    property PreserveOwnership: Boolean read FPreserveOwnership write FPreserveOwnership default False;
    property PreserveTimestamps: Boolean read FPreserveTimestamps write FPreserveTimestamps default True;
    property DefaultMode: Cardinal read FDefaultMode write FDefaultMode default $1A4;
    property OwnerName: string read FOwnerName write FOwnerName;
    property GroupName: string read FGroupName write FGroupName;
    property BlockSize: Integer read FBlockSize write FBlockSize default 512;
    property BlockingFactor: Integer read FBlockingFactor write FBlockingFactor default 20;
    property Sparse: Boolean read FSparse write FSparse default False;
    property UnixPermissions: Boolean read FUnixPermissions write FUnixPermissions default False;
    property AddPaxExtensions: Boolean read FAddPaxExtensions write FAddPaxExtensions default False;

    // ---- Gzip layer extras ----
    property GzipTextMode: Boolean read FGzipTextMode write FGzipTextMode default False;
    property GzipHeaderCRC: Boolean read FGzipHeaderCRC write FGzipHeaderCRC default False;
    property GzipStrategy: Byte read FGzipStrategy write FGzipStrategy default 0;
    property GzipOSCode: Byte read FGzipOSCode write FGzipOSCode default 255;
    property GzipExtraField: TBytes read FGzipExtraField write FGzipExtraField;

    // ---- Read-only ----
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

constructor TTarGzFile.Create(AOwner: TComponent);
begin
  inherited;
  FGzipLevel := 6;
  FActive := False;
  FFormat := tfUstar;
  FPreserveOwnership := False;
  FPreserveTimestamps := True;
  FDefaultMode := $1A4;
end;

procedure TTarGzFile.SetGzipLevel(AValue: Integer);
begin
  if (AValue < 1) or (AValue > 9) then
    raise ETarGzError.CreateFmt('GzipLevel must be 1..9 (got %d)', [AValue]);
  FGzipLevel := AValue;
end;

destructor TTarGzFile.Destroy;
begin
  Close;
  inherited;
end;

procedure TTarGzFile.SetActive(AValue: Boolean);
begin
  if AValue = FActive then Exit;
  if AValue then Open else Close;
end;

procedure TTarGzFile.SetFileName(const AValue: string);
begin
  if AValue = FFileName then Exit;
  Close;
  FFileName := AValue;
  if Assigned(FOnFileChanged) then FOnFileChanged(Self);
end;

procedure TTarGzFile.LoadFromGz(const APath: string);
var
  Fs: TFileStream;
  Gz: TGzipReadStream;
  Buf: array of Byte;
  N: Integer;
begin
  Fs := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Gz := TGzipReadStream.Create(Fs, False);
    try
      SetLength(Buf, 64 * 1024);
      repeat
        N := Gz.Read(Buf[0], Length(Buf));
        if N > 0 then
          FTempBuffer.WriteBuffer(Buf[0], N);
      until N <= 0;
    finally
      Gz.Free;
    end;
  finally
    Fs.Free;
  end;
  FTempBuffer.Position := 0;
end;

procedure TTarGzFile.SaveToGz(const APath: string);
var
  Fs: TFileStream;
  Gz: TGzipWriteStream;
  Buf: array of Byte;
  N: Integer;
begin
  FTempBuffer.Position := 0;
  Fs := TFileStream.Create(APath, fmCreate);
  try
    Gz := TGzipWriteStream.Create(Fs, FGzipLevel, False);
    try
      SetLength(Buf, 64 * 1024);
      while FTempBuffer.Position < FTempBuffer.Size do
      begin
        N := FTempBuffer.Read(Buf[0], Length(Buf));
        if N <= 0 then Break;
        Gz.WriteBuffer(Buf[0], N);
      end;
    finally
      Gz.Free; // flush + close
    end;
  finally
    Fs.Free;
  end;
end;

procedure TTarGzFile.Open;
var
  TempName: string;
begin
  if FActive then Exit;
  if FFileName = '' then
    raise ETarGzError.Create('TTarGzFile.Open: FileName not set');
  FTempBuffer := TMemoryStream.Create;
  if SysUtils.FileExists(FFileName) then
    LoadFromGz(FFileName);
  // Materialize temp buffer to a real TFileStream (TTarFile precisa de
  // arquivo no disco; em RAM via TMemoryStream nao funciona com TFileStream API).
  TempName := FFileName + '.tar.tmp';
  with TFileStream.Create(TempName, fmCreate) do
    try
      if FTempBuffer.Size > 0 then
      begin
        FTempBuffer.Position := 0;
        CopyFrom(FTempBuffer, FTempBuffer.Size);
      end;
    finally
      Free;
    end;
  FInner := TTarFile.Create(nil);
  FInner.FileName := TempName;
  FInner.Open;
  FActive := True;
end;

procedure TTarGzFile.Save;
var
  TempName: string;
  Fs: TFileStream;
begin
  if not FActive then Exit;
  TempName := FInner.FileName;
  // Re-le buffer do TAR temp
  FInner.Close;
  Fs := TFileStream.Create(TempName, fmOpenRead);
  try
    FTempBuffer.Clear;
    FTempBuffer.CopyFrom(Fs, Fs.Size);
  finally
    Fs.Free;
  end;
  SaveToGz(FFileName);
  // Reabre Inner para append continuar
  FInner.Open;
end;

procedure TTarGzFile.Close;
var
  TempName: string;
begin
  if not FActive then Exit;
  Save;
  TempName := FInner.FileName;
  FreeAndNil(FInner);
  FreeAndNil(FTempBuffer);
  if SysUtils.FileExists(TempName) then
    SysUtils.DeleteFile(TempName);
  FActive := False;
end;

function TTarGzFile.GetEntryCount: Integer;
begin
  if FActive then Result := FInner.EntryCount else Result := 0;
end;

function TTarGzFile.FileExists(const AName: string): Boolean;
begin
  Result := FActive and FInner.FileExists(AName);
end;

function TTarGzFile.GetEntryStream(const AName: string): TStream;
begin
  if not FActive then
    raise ETarGzError.Create('TTarGzFile.GetEntryStream: not Active');
  Result := FInner.GetEntryStream(AName);
end;

function TTarGzFile.ReadAsString(const AName: string): string;
begin
  Result := FInner.ReadAsString(AName);
end;

function TTarGzFile.ReadAsBytes(const AName: string): TBytes;
begin
  Result := FInner.ReadAsBytes(AName);
end;

procedure TTarGzFile.AppendStream(AStream: TStream; const AName: string; AModTime: TDateTime);
begin
  FInner.AppendStream(AStream, AName, AModTime);
end;

procedure TTarGzFile.AppendFileFromDisk(const ADiskPath, AArchiveName: string);
begin
  FInner.AppendFileFromDisk(ADiskPath, AArchiveName);
end;

procedure TTarGzFile.AppendBytes(const ABytes: TBytes; const AName: string);
begin
  FInner.AppendBytes(ABytes, AName);
end;

procedure TTarGzFile.AppendString(const AContent: string; const AName: string);
begin
  FInner.AppendString(AContent, AName);
end;

function TTarGzFile.WithFileName(const APath: string): TTarGzFile;
begin
  SetFileName(APath);
  Result := Self;
end;

function TTarGzFile.WithGzipLevel(ALevel: Integer): TTarGzFile;
begin
  FGzipLevel := ALevel;
  Result := Self;
end;

function TTarGzFile.ThatOpens: TTarGzFile;
begin
  Open;
  Result := Self;
end;

end.
