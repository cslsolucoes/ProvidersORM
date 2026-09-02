{ ZipFile.Compression.pas

  Enum global cross-format de métodos de compressão + helpers de mapeamento.
  Usado pela facade ZipFileORM.pas e pelos módulos format que precisam
  expor o método em runtime de forma uniforme.

  ZipFileORM v4.0.0 — single source of truth para método de compressão.
}
unit ZipFile.Compression;

{$IFDEF FPC}{$mode delphi}{$H+}{$ENDIF}

interface

uses
  SysUtils;

type
  // Métodos de compressão cobertos pela biblioteca (cross-format).
  // Cada formato consome um subset.
  TCompressionMethod = (
    cmStore,        // sem compressão (ZIP, 7Z, TAR)
    cmDeflate,      // ZIP, GZIP, TARGZ — RFC 1951
    cmDeflate64,    // ZIP (variante)
    cmBzip2,        // ZIP, 7Z, standalone .bz2
    cmLzma,         // ZIP (method 14), 7Z
    cmLzma2,        // 7Z padrão moderno
    cmPpmd,         // 7Z
    cmMszip,        // CAB (Microsoft variant of deflate)
    cmQuantum,      // CAB
    cmLzx,          // CAB
    cmLzh,          // LHA (-lh4..7)
    cmRar,          // RAR (methods 1-5)
    cmUnknown
  );

  TCompressionMethodSet = set of TCompressionMethod;

// Mapeia método para string legivel
function CompressionMethodToString(AMethod: TCompressionMethod): string;
function StringToCompressionMethod(const AName: string): TCompressionMethod;

implementation

function CompressionMethodToString(AMethod: TCompressionMethod): string;
begin
  case AMethod of
    cmStore:     Result := 'Store';
    cmDeflate:   Result := 'Deflate';
    cmDeflate64: Result := 'Deflate64';
    cmBzip2:     Result := 'BZip2';
    cmLzma:      Result := 'LZMA';
    cmLzma2:     Result := 'LZMA2';
    cmPpmd:      Result := 'PPMd';
    cmMszip:     Result := 'MSZIP';
    cmQuantum:   Result := 'Quantum';
    cmLzx:       Result := 'LZX';
    cmLzh:       Result := 'LZH';
    cmRar:       Result := 'RAR';
  else
    Result := 'Unknown';
  end;
end;

function StringToCompressionMethod(const AName: string): TCompressionMethod;
var
  N: string;
begin
  N := UpperCase(AName);
  if      N = 'STORE'      then Result := cmStore
  else if N = 'DEFLATE'    then Result := cmDeflate
  else if N = 'DEFLATE64'  then Result := cmDeflate64
  else if N = 'BZIP2'      then Result := cmBzip2
  else if N = 'LZMA'       then Result := cmLzma
  else if N = 'LZMA2'      then Result := cmLzma2
  else if N = 'PPMD'       then Result := cmPpmd
  else if N = 'MSZIP'      then Result := cmMszip
  else if N = 'QUANTUM'    then Result := cmQuantum
  else if N = 'LZX'        then Result := cmLzx
  else if N = 'LZH'        then Result := cmLzh
  else if N = 'RAR'        then Result := cmRar
  else                          Result := cmUnknown;
end;

end.
