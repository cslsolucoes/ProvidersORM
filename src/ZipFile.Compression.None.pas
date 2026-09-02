{*
 * ZipFile.Compression.None.pas
 *
 * Compressão "no-op" (null object pattern) — copia stream sem comprimir.
 * Era tiCompressNone.pas do MCL — renomeado para namespace Commons.* na v4.0.0.
 *
 * Original (c) 2006-2007 MODELbuilder developers team — Graeme Geldenhuys
 * Refactor v4.0.0 (c) 2026 CSL Softwares
 * Licença: LGPL-3.0
 *}
unit ZipFile.Compression.None;

{$I ZipFile.Compression.Defines.inc}

interface

uses
  ZipFile.Compression.Base,
  Classes, Exceptions.ZipFile;

type
  // Null object pattern — implements TtiCompress with no compression
  TtiCompressNone = class(TtiCompressAbs)
  private
    procedure CopyFile(const AFrom, ATo : string);
  public
    function  CompressStream(  AFrom : TStream; ATo : TStream): Extended; override;
    procedure DecompressStream(AFrom : TStream; ATo : TStream); override;
    function  CompressBuffer(  const AFrom: Pointer ; const AFromSize : Integer;
                                out   ATo:   Pointer ; out   AToSize  : Integer): Extended; override;
    procedure DecompressBuffer(const AFrom: Pointer ; const AFromSize : Integer;
                                out   ATo:   Pointer ; out   AToSize  : Integer); override;
    function  CompressString(  const AFrom : string; var ATo : string)  : Extended; override;
    procedure DecompressString(const AFrom : string; var ATo : string)  ; override;
    function  CompressFile(    const AFrom : string; const ATo : string): Extended; override;
    procedure DecompressFile(  const AFrom : string; const ATo : string); override;
  end;

implementation

uses
  SysUtils,
  ZipFile.Compression.Consts
  {$IFDEF FPC}
    {$IFDEF LCL}
    ,FileUtil
    {$ENDIF}
  {$ELSE}
  ,Windows  // Delphi: usa CopyFile() do WinAPI
  {$ENDIF}
  ;

{$IFDEF FPC}
{$IFNDEF LCL}
// Headless FPC (sem Lazarus LCL): stream-based CopyFile.
function CopyFileStream(const AFrom, ATo: string): Boolean;
var Src, Dst: TFileStream;
begin
  Result := False;
  if not FileExists(AFrom) then Exit;
  try
    Src := TFileStream.Create(AFrom, fmOpenRead or fmShareDenyWrite);
    try
      Dst := TFileStream.Create(ATo, fmCreate);
      try
        Dst.CopyFrom(Src, Src.Size);
      finally Dst.Free; end;
    finally Src.Free; end;
    Result := True;
  except
    Result := False;
  end;
end;
{$ENDIF}
{$ENDIF}

{ TtiCompressNone }

function TtiCompressNone.CompressBuffer(const AFrom: Pointer;
  const AFromSize: Integer; out ATo: Pointer; out AToSize: Integer): Extended;
begin
  Assert(AFrom = AFrom);
  Assert(AFromSize = AFromSize);
  Assert(ATo = ATo);
  Assert(AToSize = AToSize);
  Assert(false, 'Not implemented yet.');
  result := 0;
end;

function TtiCompressNone.CompressFile(const AFrom, ATo: string): Extended;
begin
  CopyFile(AFrom, ATo);
  result := 1;
end;

function TtiCompressNone.CompressStream(AFrom, ATo: TStream): Extended;
begin
  AFrom.Seek(0, soFromBeginning);
  ATo.CopyFrom(AFrom, AFrom.Size);
  AFrom.Seek(0, soFromBeginning);
  ATo.Seek(0, soFromBeginning);
  result := 100;
end;

function TtiCompressNone.CompressString(const AFrom: string;
  var ATo: string): Extended;
begin
  ATo := AFrom;
  result := 100;
end;

procedure TtiCompressNone.CopyFile(const AFrom, ATo: string);
begin
  if FileExists(ATo) then
    SysUtils.DeleteFile(ATo);

  {$IFDEF FPC}
    {$IFDEF LCL}
    // FileUtil.CopyFile devolve True em SUCESSO (fix v3: faltava o 'not';
    // o ramo original lancava excecao em toda a copia bem-sucedida)
    if not FileUtil.CopyFile(AFrom, ATo) then begin
      raise EArchive.Create('Unable to copy <' + AFrom + '> to <' + ATo + '>', ERR_ARCHIVE_WRITE_FAILED);
    end;
    {$ELSE}
    if not CopyFileStream(AFrom, ATo) then
      raise EArchive.Create('Unable to copy <' + AFrom + '> to <' + ATo + '>', ERR_ARCHIVE_WRITE_FAILED);
    {$ENDIF}
  {$ELSE}
  // Delphi: WinAPI CopyFile retorna BOOL (True = sucesso)
  if not Windows.CopyFile(PChar(AFrom), PChar(ATo), False) then
    raise EArchive.Create('Unable to copy <' + AFrom + '> to <' + ATo + '>', ERR_ARCHIVE_WRITE_FAILED);
  {$ENDIF}
end;

procedure TtiCompressNone.DecompressBuffer(const AFrom: Pointer;
  const AFromSize: Integer; out ATo: Pointer; out AToSize: Integer);
begin
  Assert(AFrom = AFrom);
  Assert(AFromSize = AFromSize);
  Assert(ATo = ATo);
  Assert(AToSize = AToSize);
  Assert(false, 'Not implemented yet.');
end;

procedure TtiCompressNone.DecompressFile(const AFrom, ATo: string);
begin
  CopyFile(AFrom, ATo);
end;

procedure TtiCompressNone.DecompressStream(AFrom, ATo: TStream);
begin
  AFrom.Seek(0, soFromBeginning);
  ATo.CopyFrom(AFrom, AFrom.Size);
  AFrom.Seek(0, soFromBeginning);
  ATo.Seek(0, soFromBeginning);
end;

procedure TtiCompressNone.DecompressString(const AFrom: string; var ATo: string);
begin
  ATo := AFrom;
end;

initialization
  gCompressFactory.RegisterClass(cgsCompressNone, TtiCompressNone);
  gtiCompressClass := TtiCompressNone;

end.
