{*
 * ZipFile.Compression.ZLib.pas
 *
 * ZLib compression class — adaptador do System.ZLib (Delphi) e dzlib (FPC).
 * Era tiCompressZLib.pas do MCL — renomeado para namespace Commons.* na v4.0.0.
 *
 * Original (c) 2006-2007 MODELbuilder developers team — Graeme Geldenhuys
 * Refactor v4.0.0 (c) 2026 CSL Softwares
 * Licença: LGPL-3.0
 *}
unit ZipFile.Compression.ZLib;

{$I ZipFile.Compression.Defines.inc}

interface

uses
  ZipFile.Compression.Base,
  Classes, Exceptions.ZipFile;

type
  // TtiCompress descendant usando a biblioteca ZLib (Delphi System.ZLib ou FPC dzlib bridge)
  TtiCompressZLib = class(TtiCompressAbs)
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
  {$IFDEF FPC}
  ZipFile.Compression.ZLib.Bridge
  {$ELSE}
  ZLib
  {$ENDIF}
  ,SysUtils
  ,ZipFile.Compression.Consts
  ;

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// * TtiCompressZLib
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

function TtiCompressZLib.CompressBuffer(const AFrom: Pointer;
  const AFromSize: Integer; out ATo: Pointer; out AToSize: Integer): Extended;
begin
  {$IFDEF FPC}
  ZipFile.Compression.ZLib.Bridge.CompressBuf(AFrom, AFromSize, ATo, AToSize);
  {$ELSE}
  // Delphi System.ZLib usa ZCompress (CompressBuf nao existe)
  ZLib.ZCompress(AFrom, AFromSize, ATo, AToSize);
  {$ENDIF}
  if AFromSize <> 0 then
    result := AToSize / AFromSize * 100
  else
    result := 0;
end;

function TtiCompressZLib.CompressFile(const AFrom : string; const ATo: string): Extended;
var
  lStreamFrom : TFileStream;
  lStreamTo  : TFileStream;
begin
  lStreamFrom := TFileStream.Create(AFrom, fmOpenRead or fmShareExclusive);
  try
    lStreamTo  := TFileStream.Create(ATo, fmCreate or fmShareExclusive);
    try
      result := CompressStream(lStreamFrom, lStreamTo);
    finally
      lStreamTo.Free;
    end;
  finally
    lStreamFrom.Free;
  end;
end;

function TtiCompressZLib.CompressStream(AFrom, ATo: TStream): Extended;
var
  liFromSize : integer;
  liToSize  : integer;
  lBufFrom  : Pointer;
  lBufTo    : Pointer;
begin
  Assert(AFrom <> nil, 'From stream unassigned');
  Assert(ATo <> nil, 'To stream unassigned');

  try
    AFrom.Position := 0;

    if AFrom.Size = 0 then
    begin
      ATo.Size := 0;
      result := 0;
      Exit;
    end;

    liFromSize := AFrom.Size;
    GetMem(lBufFrom, liFromSize);
    try
      AFrom.ReadBuffer(lBufFrom^, liFromSize);
      try
        result := CompressBuffer(lBufFrom, liFromSize, lBufTo, liToSize);
        ATo.Size := 0;
        ATo.WriteBuffer(lBufTo^, liToSize);
      finally
        FreeMem(lBufTo);
      end;
    finally
      FreeMem(lBufFrom);
    end;

    AFrom.Position := 0;
    ATo.Position := 0;

  except
    on e:exception do
      raise EArchive.Create('Error in TtiCompressZLib.CompressStream. Message: ' +
                              e.message, ERR_ZIPFILE_ZLIB);
  end;
end;

function TtiCompressZLib.CompressString(const AFrom: string;
  var ATo: string): Extended;
var
  lStreamFrom : TStringStream;
  lStreamTo  : TStringStream;
begin
  lStreamFrom := TStringStream.Create(AFrom);
  try
    lStreamTo  := TStringStream.Create('');
    try
      result := CompressStream(lStreamFrom, lStreamTo);
      ATo  := lStreamTo.DataString;
    finally
      lStreamTo.Free;
    end;
  finally
    lStreamFrom.Free;
  end;
end;

procedure TtiCompressZLib.DecompressBuffer(const AFrom: Pointer;
  const AFromSize: Integer; out ATo: Pointer; out AToSize: Integer);
begin
  {$IFDEF FPC}
  ZipFile.Compression.ZLib.Bridge.DecompressBuf(AFrom, AFromSize, AFromSize*2, ATo, AToSize);
  {$ELSE}
  // Delphi System.ZLib: ZDecompress(In, InSize, Out, OutSize, OutEstimate)
  ZLib.ZDecompress(AFrom, AFromSize, ATo, AToSize, AFromSize * 2);
  {$ENDIF}
end;

procedure TtiCompressZLib.DecompressFile(const AFrom, ATo: string);
var
  lStreamFrom : TFileStream;
  lStreamTo  : TFileStream;
begin
  lStreamFrom := TFileStream.Create(AFrom, fmOpenRead or fmShareExclusive);
  try
    lStreamTo  := TFileStream.Create(ATo, fmCreate or fmShareExclusive);
    try
      DecompressStream(lStreamFrom, lStreamTo);
    finally
      lStreamTo.Free;
    end;
  finally
    lStreamFrom.Free;
  end;
end;

procedure TtiCompressZLib.DecompressStream(AFrom, ATo: TStream);
var
  liToSize : integer;
  liFromSize : integer;
  lBufFrom : Pointer;
  lBufTo  : Pointer;
begin
  try
    if AFrom.Size = 0 then
    begin
      ATo.Size := 0;
      Exit;
    end;

    AFrom.Position := 0;
    ATo.Size := 0;
    liFromSize := AFrom.Size;
    GetMem(lBufFrom, liFromSize);
    try
      try
        AFrom.ReadBuffer(lBufFrom^, liFromSize);
        DecompressBuffer(lBufFrom, liFromSize, lBufTo, liToSize);
        ATo.Size := 0;
        ATo.WriteBuffer(lBufTo^, liToSize);
      finally
        FreeMem(lBufTo);
      end;
    finally
      FreeMem(lBufFrom);
    end;
    AFrom.Position := 0;
    ATo.Position := 0;
  except
    on e:exception do
      raise EArchive.Create('Error in TtiCompressZLib.DeCompressStream. Message: ' +
                              e.message, ERR_ZIPFILE_ZLIB);
  end;
end;

procedure TtiCompressZLib.DecompressString(const AFrom: string;
  var ATo: string);
var
  lStreamFrom : TStringStream;
  lStreamTo  : TStringStream;
begin
  lStreamFrom := TStringStream.Create(AFrom);
  try
    lStreamTo  := TStringStream.Create('');
    try
      DecompressStream(lStreamFrom, lStreamTo);
      ATo  := lStreamTo.DataString;
    finally
      lStreamTo.Free;
    end;
  finally
    lStreamFrom.Free;
  end;
end;

initialization
  gCompressFactory.RegisterClass(cgsCompressZLib, TtiCompressZLib);
  gtiCompressClass := TtiCompressZLib;

end.
