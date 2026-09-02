{ ZipFile.Open.pas

  Auto-detect de formato por magic bytes — usuario chama
  ZipFile.Open('x.foo') sem precisar saber se e ZIP/TAR/Gzip/TarGz.

  Magic bytes detectados (ADR-002 do SPEC):
  - PK\x03\x04 / PK\x05\x06 / PK\x07\x08  -> ZIP
  - \x1F\x8B                              -> Gzip (.gz; pode ser .tar.gz por content)
  - ustar\x00 em offset 257               -> TAR
  - 7z\xBC\xAF\x27\x1C                    -> 7zip (v3.1)
  - Rar!\x1A\x07\x00 / Rar!\x1A\x07\x01\x00 -> RAR (v3.5)
  - PMOCC                                 -> CAB (v3.7)
  - BZh                                   -> BZIP2 (v3.8)
  - \x1F\x9D                              -> Z compress (v3.9)
  - \x60\xEA                              -> ARJ (v3 ProvidersORM F1-A A.3)
  - -l??- em offset 2                     -> LHA (v3 ProvidersORM F1-A A.3)
  - CD001 em offset 0x8001                -> ISO 9660 (v3 ProvidersORM F1-A A.3)

  Para .tar.gz: detectado como Gzip primeiro; usuario pode usar
  ZipFile.OpenTarGz() diretamente OU ZipFile.Open() devolve TGzipReadStream
  e usuario decide o que fazer.
}
unit ZipFile.Open;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Classes, Exceptions.Base;

type
  TArchiveFormat = (
    afUnknown,
    afZip,
    afGzip,
    afTar,
    afTarGz,    // detectado por dupla checagem
    afSevenZip,
    afRar,
    afCab,
    afBzip2,
    afZCompress,
    afArj,      // v3 ProvidersORM (F1-A A.3): 0x60 0xEA
    afIso,      // v3 ProvidersORM (F1-A A.3): CD001 em 0x8001
    afLha       // v3 ProvidersORM (F1-A A.3): -l??- em offset 2
  );

  EArchiveDetectError = class(EExceptionBase);

// Le os primeiros bytes do arquivo/stream e identifica o formato.
function DetectArchiveFormat(AStream: TStream): TArchiveFormat; overload;
function DetectArchiveFormat(const APath: string): TArchiveFormat; overload;

// String legivel
function ArchiveFormatToString(AFormat: TArchiveFormat): string;

implementation

function ArchiveFormatToString(AFormat: TArchiveFormat): string;
begin
  case AFormat of
    afZip:        Result := 'ZIP';
    afGzip:       Result := 'Gzip';
    afTar:        Result := 'TAR (POSIX ustar)';
    afTarGz:      Result := 'TAR + Gzip (.tar.gz)';
    afSevenZip:   Result := '7-Zip';
    afRar:        Result := 'RAR';
    afCab:        Result := 'CAB (Microsoft Cabinet)';
    afBzip2:      Result := 'BZIP2';
    afZCompress:  Result := 'Z (Unix compress)';
    afArj:        Result := 'ARJ';
    afIso:        Result := 'ISO 9660';
    afLha:        Result := 'LHA';
  else
    Result := 'Unknown';
  end;
end;

function DetectArchiveFormat(AStream: TStream): TArchiveFormat;
var
  Saved: Int64;
  Buf: array[0..511] of Byte;
  N: Integer;
begin
  Result := afUnknown;
  if AStream = nil then Exit;
  Saved := AStream.Position;
  try
    AStream.Position := 0;
    N := AStream.Read(Buf[0], SizeOf(Buf));
    if N < 4 then Exit;
    // ZIP: PK\x03\x04 / PK\x05\x06 / PK\x07\x08
    if (Buf[0] = $50) and (Buf[1] = $4B) and
       (((Buf[2] = $03) and (Buf[3] = $04)) or
        ((Buf[2] = $05) and (Buf[3] = $06)) or
        ((Buf[2] = $07) and (Buf[3] = $08))) then
      Exit(afZip);
    // 7zip: 7z\xBC\xAF\x27\x1C
    if (N >= 6) and (Buf[0] = $37) and (Buf[1] = $7A) and
       (Buf[2] = $BC) and (Buf[3] = $AF) and
       (Buf[4] = $27) and (Buf[5] = $1C) then
      Exit(afSevenZip);
    // RAR: Rar!\x1A\x07\x00 (RAR4) ou Rar!\x1A\x07\x01\x00 (RAR5)
    if (N >= 7) and (Buf[0] = $52) and (Buf[1] = $61) and
       (Buf[2] = $72) and (Buf[3] = $21) and
       (Buf[4] = $1A) and (Buf[5] = $07) and
       ((Buf[6] = $00) or (Buf[6] = $01)) then
      Exit(afRar);
    // CAB: MSCF
    if (Buf[0] = $4D) and (Buf[1] = $53) and
       (Buf[2] = $43) and (Buf[3] = $46) then
      Exit(afCab);
    // BZIP2: BZh
    if (Buf[0] = $42) and (Buf[1] = $5A) and (Buf[2] = $68) then
      Exit(afBzip2);
    // Z compress: \x1F\x9D
    if (Buf[0] = $1F) and (Buf[1] = $9D) then
      Exit(afZCompress);
    // ARJ: \x60\xEA (v3 ProvidersORM)
    if (Buf[0] = $60) and (Buf[1] = $EA) then
      Exit(afArj);
    // LHA: '-l??-' em offset 2 (ex: -lh0- .. -lh7-, -lhd-, -lz4-) (v3 ProvidersORM)
    if (N >= 7) and (Buf[2] = Ord('-')) and (Buf[3] = Ord('l')) and
       (Buf[6] = Ord('-')) then
      Exit(afLha);
    // Gzip: \x1F\x8B (pode ser .tar.gz, mas precisa descomprimir pra saber)
    if (Buf[0] = $1F) and (Buf[1] = $8B) then
      Exit(afGzip);
    // TAR: "ustar" em offset 257
    if (N >= 264) and
       (Buf[257] = Ord('u')) and (Buf[258] = Ord('s')) and
       (Buf[259] = Ord('t')) and (Buf[260] = Ord('a')) and
       (Buf[261] = Ord('r')) then
      Exit(afTar);
    // ISO 9660: 'CD001' no offset 0x8001 (PVD no sector 16) (v3 ProvidersORM)
    if AStream.Size >= $8006 then
    begin
      AStream.Position := $8001;
      N := AStream.Read(Buf[0], 5);
      if (N = 5) and
         (Buf[0] = Ord('C')) and (Buf[1] = Ord('D')) and
         (Buf[2] = Ord('0')) and (Buf[3] = Ord('0')) and
         (Buf[4] = Ord('1')) then
        Exit(afIso);
    end;
  finally
    AStream.Position := Saved;
  end;
end;

function DetectArchiveFormat(const APath: string): TArchiveFormat;
var
  Fs: TFileStream;
begin
  Result := afUnknown;
  if not SysUtils.FileExists(APath) then Exit;
  Fs := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Result := DetectArchiveFormat(Fs);
  finally
    Fs.Free;
  end;
end;

end.
