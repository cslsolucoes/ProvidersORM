{ =============================================================================
  ZipFile.Facade - Fachada publica unica do modulo ZipFile (10 formatos)

  Absorve o umbrella ZipFileORM.pas v4.0.0: o consumidor escreve
  uses ZipFile.Facade e ganha TArchive com (1) deteccao de formato por magic
  number, (2) factories Create por formato, (3) extratores de alto nivel
  Extract-ToFolder preservando a estrutura de subpastas. Cada formato e gated
  pelo seu USE_ARCHIVE_ do ORM.Defines.inc (todos ON por defeito).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           05/07/2026

  Changelog (file):
  - 1.1.0 (05/07/2026): v3 F1-A A.3 - merge do umbrella ZipFileORM.pas
    (DetectFormat, FormatToString, factories Create por formato, re-exports
    TArchiveFormat e TCompressionMethod) + novos extratores: Rar (binding
    unrar.dll - suporta metodos comprimidos, ao contrario do decoder puro
    pascal), Tar (indice FindFirst devolve indice e nao zero), TarGz (gunzip
    em streaming para tar temporario), Gzip (payload unico), SevenZ, Cab, Arj,
    Iso e Lha (enumeracao por indice). Guarda anti path-traversal: entries com
    caminho pai sao ignoradas em todos os extratores.
  - 1.0.0 (05/07/2026): v3 (F1-A Onda A.4). Facade minima sobre TZipFile usando
    FindFirst-FindNext + GetEntryStream. Sem alterar a lib absorvida.
  ============================================================================= }
unit ZipFile.Facade;

{$IFDEF FPC}{$mode delphi}{$H+}{$ENDIF}

interface

{$I ORM.Defines.inc}

uses
  Classes,
  SysUtils,
  Commons.ZipFile.Types,
  ZipFile.Open,
  ZipFile.Compression,
  ZipFile
  {$IFDEF USE_ARCHIVE_TAR}, TarFile{$ENDIF}
  {$IFDEF USE_ARCHIVE_TARGZ}, TarGzFile{$ENDIF}
  {$IFDEF USE_ARCHIVE_GZIP}, GzipFile{$ENDIF}
  {$IFDEF USE_ARCHIVE_CAB}, WCabFile{$ENDIF}
  {$IFDEF USE_ARCHIVE_SEVENZ}, SevenZFile{$ENDIF}
  {$IFDEF USE_ARCHIVE_ARJ}, ArjFile{$ENDIF}
  {$IFDEF USE_ARCHIVE_ISO}, IsoFile{$ENDIF}
  {$IFDEF USE_ARCHIVE_LHA}, LhaFile{$ENDIF}
  {$IFDEF USE_ARCHIVE_RAR}, RarFile{$ENDIF}
  ;

type
  { Re-exports (umbrella): deteccao e compressao cross-format }
  TArchiveFormat        = ZipFile.Open.TArchiveFormat;
  EArchiveDetectError   = ZipFile.Open.EArchiveDetectError;
  TCompressionMethod    = ZipFile.Compression.TCompressionMethod;
  TCompressionMethodSet = ZipFile.Compression.TCompressionMethodSet;

const
  { Versao do ZipFileORM absorvido (proveniencia da Onda A.3) }
  ZIPFILE_MODULE_SOURCE_VERSION = '4.0.0';

type
  { Fachada unica do modulo: deteccao + factories + extratores de alto nivel }
  TArchive = class
  public
    { ---- Deteccao de formato (magic number; delega em ZipFile.Open) ---- }
    class function DetectFormat(const AFileName: string): TArchiveFormat; overload;
    class function DetectFormat(AStream: TStream): TArchiveFormat; overload;
    class function FormatToString(AFormat: TArchiveFormat): string;

    { ---- Factories (umbrella): componente pre-configurado; Owner pode ser nil ---- }
    class function CreateZip(AOwner: TComponent; const AFileName: string): TZipFile;
    {$IFDEF USE_ARCHIVE_TAR}
    class function CreateTar(AOwner: TComponent; const AFileName: string): TTarFile;
    {$ENDIF}
    {$IFDEF USE_ARCHIVE_TARGZ}
    class function CreateTarGz(AOwner: TComponent; const AFileName: string): TTarGzFile;
    {$ENDIF}
    {$IFDEF USE_ARCHIVE_GZIP}
    class function CreateGzip(AOwner: TComponent; const AFileName: string): TGzipFile;
    {$ENDIF}
    {$IFDEF USE_ARCHIVE_CAB}
    class function CreateCab(AOwner: TComponent; const AFileName: string): TWCabFile;
    {$ENDIF}
    {$IFDEF USE_ARCHIVE_SEVENZ}
    class function CreateSevenZ(AOwner: TComponent; const AFileName: string): TSevenZFile;
    {$ENDIF}
    {$IFDEF USE_ARCHIVE_ARJ}
    class function CreateArj(AOwner: TComponent; const AFileName: string): TArjFile;
    {$ENDIF}
    {$IFDEF USE_ARCHIVE_ISO}
    class function CreateIso(AOwner: TComponent; const AFileName: string): TIsoFile;
    {$ENDIF}
    {$IFDEF USE_ARCHIVE_LHA}
    class function CreateLha(AOwner: TComponent; const AFileName: string): TLhaFile;
    {$ENDIF}
    {$IFDEF USE_ARCHIVE_RAR}
    class function CreateRar(AOwner: TComponent; const AFileName: string): TRarFile;
    {$ENDIF}

    { ---- Extratores de alto nivel (preservam subpastas; True = sucesso) ---- }

    { ZIP (formato base, sempre presente). AOnProgress: entradas feitas-total. }
    class function ExtractZipToFolder(const AZipPath, ADestDir: string;
      AOnProgress: TZipProgressEvent = nil): Boolean;

    {$IFDEF USE_ARCHIVE_RAR}
    { RAR4-RAR5 qualquer metodo, via unrar.dll (dll do processo em dll-plat).
      AUnrarDllPath vazio procura 'unrar.dll' no PATH e pasta do exe. }
    class function ExtractRarToFolder(const ARarPath, ADestDir: string;
      const AUnrarDllPath: string = ''): Boolean;
    {$ENDIF}

    {$IFDEF USE_ARCHIVE_TAR}
    { TAR POSIX ustar. }
    class function ExtractTarToFolder(const ATarPath, ADestDir: string): Boolean;
    {$ENDIF}

    {$IFDEF USE_ARCHIVE_TARGZ}
    { TAR.GZ - gunzip em streaming para .tar temporario + ExtractTarToFolder
      (nao carrega o conteudo todo em RAM). Requer USE_ARCHIVE_TAR. }
    class function ExtractTarGzToFolder(const ATarGzPath, ADestDir: string): Boolean;
    {$ENDIF}

    {$IFDEF USE_ARCHIVE_GZIP}
    { GZIP de payload unico: descomprime para ATargetPath. }
    class function ExtractGzipToFile(const AGzPath, ATargetPath: string): Boolean;
    {$ENDIF}

    {$IFDEF USE_ARCHIVE_SEVENZ}
    class function Extract7zToFolder(const A7zPath, ADestDir: string): Boolean;
    {$ENDIF}
    {$IFDEF USE_ARCHIVE_CAB}
    class function ExtractCabToFolder(const ACabPath, ADestDir: string): Boolean;
    {$ENDIF}
    {$IFDEF USE_ARCHIVE_ARJ}
    class function ExtractArjToFolder(const AArjPath, ADestDir: string): Boolean;
    {$ENDIF}
    {$IFDEF USE_ARCHIVE_ISO}
    class function ExtractIsoToFolder(const AIsoPath, ADestDir: string): Boolean;
    {$ENDIF}
    {$IFDEF USE_ARCHIVE_LHA}
    class function ExtractLhaToFolder(const ALhaPath, ADestDir: string): Boolean;
    {$ENDIF}
  end;

implementation

uses
  {$IFDEF USE_ARCHIVE_RAR}RarFile.Unrar,{$ENDIF}
  {$IFDEF USE_ARCHIVE_TARGZ}TarFile.GzipStream,{$ENDIF}
  Commons.ZipFile.Consts;

{ Normaliza separadores da entry ('/' e '-barra invertida-') para PathDelim. }
function NormalizeEntryPath(const AName: string): string;
begin
  Result := StringReplace(AName, '/', PathDelim, [rfReplaceAll]);
  Result := StringReplace(Result, '\', PathDelim, [rfReplaceAll]);
end;

{ Guarda anti path-traversal: True quando a entry e segura para extrair. }
function IsSafeEntry(const AName: string): Boolean;
begin
  Result := (AName <> '') and (Pos('..', AName) = 0);
end;

{ Escreve um stream de entry em ATarget, criando as pastas do caminho. }
procedure WriteEntryStream(ASrc: TStream; const ATarget: string);
var
  LDst: TFileStream;
begin
  ForceDirectories(ExtractFilePath(ATarget));
  ASrc.Position := 0;
  LDst := TFileStream.Create(ATarget, fmCreate);
  try
    LDst.CopyFrom(ASrc, 0);
  finally
    LDst.Free;
  end;
end;

{ ---- Deteccao ---- }

class function TArchive.DetectFormat(const AFileName: string): TArchiveFormat;
begin
  Result := ZipFile.Open.DetectArchiveFormat(AFileName);
end;

class function TArchive.DetectFormat(AStream: TStream): TArchiveFormat;
begin
  Result := ZipFile.Open.DetectArchiveFormat(AStream);
end;

class function TArchive.FormatToString(AFormat: TArchiveFormat): string;
begin
  Result := ZipFile.Open.ArchiveFormatToString(AFormat);
end;

{ ---- Factories ---- }

class function TArchive.CreateZip(AOwner: TComponent; const AFileName: string): TZipFile;
begin
  Result := TZipFile.Create(AOwner);
  Result.FileName := AFileName;
end;

{$IFDEF USE_ARCHIVE_TAR}
class function TArchive.CreateTar(AOwner: TComponent; const AFileName: string): TTarFile;
begin
  Result := TTarFile.Create(AOwner);
  Result.FileName := AFileName;
end;
{$ENDIF}

{$IFDEF USE_ARCHIVE_TARGZ}
class function TArchive.CreateTarGz(AOwner: TComponent; const AFileName: string): TTarGzFile;
begin
  Result := TTarGzFile.Create(AOwner);
  Result.FileName := AFileName;
end;
{$ENDIF}

{$IFDEF USE_ARCHIVE_GZIP}
class function TArchive.CreateGzip(AOwner: TComponent; const AFileName: string): TGzipFile;
begin
  Result := TGzipFile.Create(AOwner);
  Result.FileName := AFileName;
end;
{$ENDIF}

{$IFDEF USE_ARCHIVE_CAB}
class function TArchive.CreateCab(AOwner: TComponent; const AFileName: string): TWCabFile;
begin
  Result := TWCabFile.Create(AOwner);
  Result.FileName := AFileName;
end;
{$ENDIF}

{$IFDEF USE_ARCHIVE_SEVENZ}
class function TArchive.CreateSevenZ(AOwner: TComponent; const AFileName: string): TSevenZFile;
begin
  Result := TSevenZFile.Create(AOwner);
  Result.FileName := AFileName;
end;
{$ENDIF}

{$IFDEF USE_ARCHIVE_ARJ}
class function TArchive.CreateArj(AOwner: TComponent; const AFileName: string): TArjFile;
begin
  Result := TArjFile.Create(AOwner);
  Result.FileName := AFileName;
end;
{$ENDIF}

{$IFDEF USE_ARCHIVE_ISO}
class function TArchive.CreateIso(AOwner: TComponent; const AFileName: string): TIsoFile;
begin
  Result := TIsoFile.Create(AOwner);
  Result.FileName := AFileName;
end;
{$ENDIF}

{$IFDEF USE_ARCHIVE_LHA}
class function TArchive.CreateLha(AOwner: TComponent; const AFileName: string): TLhaFile;
begin
  Result := TLhaFile.Create(AOwner);
  Result.FileName := AFileName;
end;
{$ENDIF}

{$IFDEF USE_ARCHIVE_RAR}
class function TArchive.CreateRar(AOwner: TComponent; const AFileName: string): TRarFile;
begin
  Result := TRarFile.Create(AOwner);
  Result.FileName := AFileName;
end;
{$ENDIF}

{ ---- Extratores ---- }

class function TArchive.ExtractZipToFolder(const AZipPath, ADestDir: string;
  AOnProgress: TZipProgressEvent): Boolean;
var
  LZip: TZipFile;
  LSR: TZipSearchRec;
  LFind, LTotal, LIdx: Integer;
  LName, LTarget: string;
  LSrc: TStream;
  LCancel: Boolean;
begin
  Result := False;
  if (Trim(AZipPath) = '') or not FileExists(AZipPath) then
    Exit;

  LZip := TZipFile.Create(nil);
  try
    LZip.FileName := AZipPath;
    LZip.Open;
    LTotal := Integer(LZip.FileCount);
    LIdx := 0;

    LFind := LZip.FindFirst(LSR);      // ZIP: 0 = ok ; 1 = fim
    while LFind = 0 do
    begin
      LName := LSR.Name;
      // entradas de directorio terminam em '/'; ignorar (ForceDirectories cria as pastas)
      if IsSafeEntry(LName) and (LName[Length(LName)] <> '/') then
      begin
        LTarget := IncludeTrailingPathDelimiter(ADestDir) + NormalizeEntryPath(LName);
        LSrc := LZip.GetEntryStream(LName);
        try
          WriteEntryStream(LSrc, LTarget);
        finally
          LSrc.Free;
        end;
      end;

      Inc(LIdx);
      if Assigned(AOnProgress) then
      begin
        LCancel := False;
        AOnProgress(LZip, LIdx, LTotal, LCancel);
        if LCancel then
          Exit;
      end;

      LFind := LZip.FindNext(LSR);
    end;
    Result := True;
  finally
    LZip.Free;
  end;
end;

{$IFDEF USE_ARCHIVE_RAR}
class function TArchive.ExtractRarToFolder(const ARarPath, ADestDir: string;
  const AUnrarDllPath: string): Boolean;
begin
  Result := TUnrar.ExtractToFolder(ARarPath, ADestDir, AUnrarDllPath);
end;
{$ENDIF}

{$IFDEF USE_ARCHIVE_TAR}
class function TArchive.ExtractTarToFolder(const ATarPath, ADestDir: string): Boolean;
var
  LTar: TTarFile;
  LSR: TTarSearchRec;
  LFind: Integer;
  LName, LTarget: string;
  LSrc: TStream;
begin
  Result := False;
  if (Trim(ATarPath) = '') or not FileExists(ATarPath) then
    Exit;

  LTar := TTarFile.Create(nil);
  try
    LTar.FileName := ATarPath;
    LTar.Open;
    // NB: semantica TAR difere do ZIP -- FindNext devolve o INDICE (maior ou
    // igual a 1), nao 0. -1 = fim; qualquer valor nao negativo e entry valida.
    LFind := LTar.FindFirst(LSR);
    while LFind >= 0 do
    begin
      LName := LSR.Name;
      if IsSafeEntry(LName) and (LSR.EntryType <> tetDirectory) and
         (LName[Length(LName)] <> '/') then
      begin
        LTarget := IncludeTrailingPathDelimiter(ADestDir) + NormalizeEntryPath(LName);
        LSrc := LTar.GetEntryStream(LName);
        try
          WriteEntryStream(LSrc, LTarget);
        finally
          LSrc.Free;
        end;
      end;
      LFind := LTar.FindNext(LSR);
    end;
    Result := True;
  finally
    LTar.Free;
  end;
end;
{$ENDIF}

{$IFDEF USE_ARCHIVE_TARGZ}
class function TArchive.ExtractTarGzToFolder(const ATarGzPath, ADestDir: string): Boolean;
{$IFDEF USE_ARCHIVE_TAR}
var
  LGzFile: TFileStream;
  LGz: TGzipReadStream;
  LTar: TFileStream;
  LTmpTar: string;
  LBuf: array[0..65535] of Byte;
  LRead: Integer;
begin
  Result := False;
  if (Trim(ATarGzPath) = '') or not FileExists(ATarGzPath) then
    Exit;

  { gunzip em streaming para um .tar temporario (64 KB por bloco). }
  LTmpTar := GetEnvironmentVariable('TEMP');
  if LTmpTar = '' then
    LTmpTar := ExtractFilePath(ParamStr(0));
  LTmpTar := IncludeTrailingPathDelimiter(LTmpTar) + 'providersorm_targz.tar';

  LGzFile := TFileStream.Create(ATarGzPath, fmOpenRead or fmShareDenyWrite);
  try
    LGz := TGzipReadStream.Create(LGzFile);
    try
      LTar := TFileStream.Create(LTmpTar, fmCreate);
      try
        repeat
          LRead := LGz.Read(LBuf, SizeOf(LBuf));
          if LRead > 0 then
            LTar.WriteBuffer(LBuf, LRead);
        until LRead <= 0;
      finally
        LTar.Free;
      end;
    finally
      LGz.Free;
    end;
  finally
    LGzFile.Free;
  end;

  try
    Result := ExtractTarToFolder(LTmpTar, ADestDir);
  finally
    if FileExists(LTmpTar) then
      DeleteFile(LTmpTar);
  end;
end;
{$ELSE}
begin
  Result := False;  // requer USE_ARCHIVE_TAR
end;
{$ENDIF}
{$ENDIF}

{$IFDEF USE_ARCHIVE_GZIP}
class function TArchive.ExtractGzipToFile(const AGzPath, ATargetPath: string): Boolean;
begin
  Result := False;
  if (Trim(AGzPath) = '') or not FileExists(AGzPath) then
    Exit;
  ForceDirectories(ExtractFilePath(ATargetPath));
  TGzipFile.DecompressFile(AGzPath, ATargetPath);
  Result := FileExists(ATargetPath);
end;
{$ENDIF}

{$IFDEF USE_ARCHIVE_SEVENZ}
class function TArchive.Extract7zToFolder(const A7zPath, ADestDir: string): Boolean;
var
  LArc: TSevenZFile;
  I: Integer;
  LName, LTarget: string;
  LSrc: TStream;
begin
  Result := False;
  if (Trim(A7zPath) = '') or not FileExists(A7zPath) then
    Exit;
  LArc := TSevenZFile.Create(nil);
  try
    LArc.FileName := A7zPath;
    LArc.Open;
    for I := 0 to LArc.GetEntryCount - 1 do
    begin
      LName := LArc.GetEntryName(I);
      if (not IsSafeEntry(LName)) or LArc.IsDir(I) then
        Continue;
      LTarget := IncludeTrailingPathDelimiter(ADestDir) + NormalizeEntryPath(LName);
      LSrc := LArc.GetEntryStream(LName);
      try
        WriteEntryStream(LSrc, LTarget);
      finally
        LSrc.Free;
      end;
    end;
    Result := True;
  finally
    LArc.Free;
  end;
end;
{$ENDIF}

{$IFDEF USE_ARCHIVE_CAB}
class function TArchive.ExtractCabToFolder(const ACabPath, ADestDir: string): Boolean;
var
  LArc: TWCabFile;
  I: Integer;
  LName, LTarget: string;
  LSrc: TStream;
begin
  Result := False;
  if (Trim(ACabPath) = '') or not FileExists(ACabPath) then
    Exit;
  LArc := TWCabFile.Create(nil);
  try
    LArc.FileName := ACabPath;
    LArc.Open;
    // CAB nao tem entries de directorio (TWCabFile nao expoe IsDir);
    // pastas ficam implicitas nos caminhos das entries.
    for I := 0 to LArc.GetEntryCount - 1 do
    begin
      LName := LArc.GetEntryName(I);
      if (not IsSafeEntry(LName)) or
         (LName[Length(LName)] = '/') or (LName[Length(LName)] = '\') then
        Continue;
      LTarget := IncludeTrailingPathDelimiter(ADestDir) + NormalizeEntryPath(LName);
      LSrc := LArc.GetEntryStream(LName);
      try
        WriteEntryStream(LSrc, LTarget);
      finally
        LSrc.Free;
      end;
    end;
    Result := True;
  finally
    LArc.Free;
  end;
end;
{$ENDIF}

{$IFDEF USE_ARCHIVE_ARJ}
class function TArchive.ExtractArjToFolder(const AArjPath, ADestDir: string): Boolean;
var
  LArc: TArjFile;
  I: Integer;
  LName, LTarget: string;
  LSrc: TStream;
begin
  Result := False;
  if (Trim(AArjPath) = '') or not FileExists(AArjPath) then
    Exit;
  LArc := TArjFile.Create(nil);
  try
    LArc.FileName := AArjPath;
    LArc.Open;
    for I := 0 to LArc.GetEntryCount - 1 do
    begin
      LName := LArc.GetEntryName(I);
      if (not IsSafeEntry(LName)) or LArc.IsDir(I) then
        Continue;
      LTarget := IncludeTrailingPathDelimiter(ADestDir) + NormalizeEntryPath(LName);
      LSrc := LArc.GetEntryStream(LName);
      try
        WriteEntryStream(LSrc, LTarget);
      finally
        LSrc.Free;
      end;
    end;
    Result := True;
  finally
    LArc.Free;
  end;
end;
{$ENDIF}

{$IFDEF USE_ARCHIVE_ISO}
class function TArchive.ExtractIsoToFolder(const AIsoPath, ADestDir: string): Boolean;
var
  LArc: TIsoFile;
  I: Integer;
  LName, LTarget: string;
  LSrc: TStream;
begin
  Result := False;
  if (Trim(AIsoPath) = '') or not FileExists(AIsoPath) then
    Exit;
  LArc := TIsoFile.Create(nil);
  try
    LArc.FileName := AIsoPath;
    LArc.Open;
    for I := 0 to LArc.GetEntryCount - 1 do
    begin
      LName := LArc.GetEntryName(I);
      if (not IsSafeEntry(LName)) or LArc.IsDir(I) then
        Continue;
      LTarget := IncludeTrailingPathDelimiter(ADestDir) + NormalizeEntryPath(LName);
      LSrc := LArc.GetEntryStream(LName);
      try
        WriteEntryStream(LSrc, LTarget);
      finally
        LSrc.Free;
      end;
    end;
    Result := True;
  finally
    LArc.Free;
  end;
end;
{$ENDIF}

{$IFDEF USE_ARCHIVE_LHA}
class function TArchive.ExtractLhaToFolder(const ALhaPath, ADestDir: string): Boolean;
var
  LArc: TLhaFile;
  I: Integer;
  LName, LTarget: string;
  LSrc: TStream;
begin
  Result := False;
  if (Trim(ALhaPath) = '') or not FileExists(ALhaPath) then
    Exit;
  LArc := TLhaFile.Create(nil);
  try
    LArc.FileName := ALhaPath;
    LArc.Open;
    for I := 0 to LArc.GetEntryCount - 1 do
    begin
      LName := LArc.GetEntryName(I);
      if (not IsSafeEntry(LName)) or LArc.IsDir(I) then
        Continue;
      LTarget := IncludeTrailingPathDelimiter(ADestDir) + NormalizeEntryPath(LName);
      LSrc := LArc.GetEntryStream(LName);
      try
        WriteEntryStream(LSrc, LTarget);
      finally
        LSrc.Free;
      end;
    end;
    Result := True;
  finally
    LArc.Free;
  end;
end;
{$ENDIF}

end.
