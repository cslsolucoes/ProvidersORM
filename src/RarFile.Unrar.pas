{ =============================================================================
  RarFile.Unrar - Extracao de arquivos RAR via unrar.dll (UnRARDLL API)

  Binding dinamico (LoadLibrary + GetProcAddress) da unrar.dll oficial. Extrai
  RAR4 e RAR5 de QUALQUER metodo (store/LZSS/PPMd) -- ao contrario do decoder
  puro-pascal TRarFile, limitado a RAR5 method 0. Windows-only (a unrar.dll e o
  cliente nativo). A DLL da arquitectura do processo vive em dll/win32|win64/.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           05/07/2026

  Changelog (file):
  - 1.0.0 (05/07/2026): v3 (F1-A Onda A.3, formato RAR). Binding unrar.dll novo
    (o ZipFileORM nao o trazia): RAROpenArchiveEx/RARReadHeaderEx/RARProcessFileW/
    RARCloseArchive/RARSetCallback. TUnrar.ExtractToFolder extrai preservando a
    estrutura de subpastas. Carregamento dinamico por caminho (dll/win32|win64/).
  ============================================================================= }
unit RarFile.Unrar;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
  {$H+}
{$ENDIF}

interface

{$I ORM.Defines.inc}

uses
  {$IF DEFINED(FPC)}
  SysUtils,
  Classes;
  {$ELSE}
  System.SysUtils,
  System.Classes;
  {$ENDIF}

type
  { Extracao de arquivos RAR via unrar.dll. Metodos de classe (sem estado). }
  TUnrar = class
  public
    { Extrai todo o conteudo de ARarPath para ADestDir preservando subpastas.
      AUnrarDllPath: caminho para a unrar.dll da arquitectura do processo; vazio
      procura 'unrar.dll' no PATH/pasta-do-exe. Devolve True em sucesso. }
    class function ExtractToFolder(const ARarPath, ADestDir: string;
      const AUnrarDllPath: string = ''): Boolean; static;

    { True se a unrar.dll do caminho dado carrega. }
    class function Available(const AUnrarDllPath: string = ''): Boolean; static;
  end;

implementation

{$IFDEF MSWINDOWS}
uses
  {$IF DEFINED(FPC)}Windows{$ELSE}Winapi.Windows{$ENDIF};

const
  RAR_OM_EXTRACT   = 1;   // OpenMode: abrir para extraccao
  RAR_EXTRACT      = 2;   // Operation de RARProcessFile: extrair para disco
  ERAR_SUCCESS     = 0;
  ERAR_END_ARCHIVE = 10;  // fim normal do arquivo

type
  { Campos usados: ArcNameW, OpenMode, OpenResult. Layout identico ao
    RAROpenArchiveDataEx oficial do unrar.h 5.5+ (OpFlags + CmtBufW +
    Reserved de 25 Cardinais) — correcto em Win32 e Win64. }
  TRAROpenArchiveDataEx = record
    ArcName: PAnsiChar;
    ArcNameW: PWideChar;
    OpenMode: Cardinal;
    OpenResult: Cardinal;
    CmtBuf: PAnsiChar;
    CmtBufSize: Cardinal;
    CmtSize: Cardinal;
    CmtState: Cardinal;
    Flags: Cardinal;
    Callback: Pointer;
    UserData: NativeInt;
    OpFlags: Cardinal;
    CmtBufW: PWideChar;
    Reserved: array[0..24] of Cardinal;
  end;
  PRAROpenArchiveDataEx = ^TRAROpenArchiveDataEx;

  { Layout completo do RARHeaderDataEx (a dll escreve ate Reserved). }
  TRARHeaderDataEx = record
    ArcName: array[0..1023] of AnsiChar;
    ArcNameW: array[0..1023] of WideChar;
    FileName: array[0..1023] of AnsiChar;
    FileNameW: array[0..1023] of WideChar;
    Flags: Cardinal;
    PackSize: Cardinal;
    PackSizeHigh: Cardinal;
    UnpSize: Cardinal;
    UnpSizeHigh: Cardinal;
    HostOS: Cardinal;
    FileCRC: Cardinal;
    FileTime: Cardinal;
    UnpVer: Cardinal;
    Method: Cardinal;
    FileAttr: Cardinal;
    CmtBuf: PAnsiChar;
    CmtBufSize: Cardinal;
    CmtSize: Cardinal;
    CmtState: Cardinal;
    DictSize: Cardinal;
    HashType: Cardinal;
    Hash: array[0..31] of AnsiChar;
    RedirType: Cardinal;
    RedirName: PWideChar;
    RedirNameSize: Cardinal;
    DirTarget: Cardinal;
    MtimeLow: Cardinal;
    MtimeHigh: Cardinal;
    CtimeLow: Cardinal;
    CtimeHigh: Cardinal;
    AtimeLow: Cardinal;
    AtimeHigh: Cardinal;
    Reserved: array[0..987] of Cardinal;
  end;
  PRARHeaderDataEx = ^TRARHeaderDataEx;

  TRAROpenArchiveEx = function(Data: PRAROpenArchiveDataEx): THandle; stdcall;
  TRARCloseArchive  = function(hArc: THandle): Integer; stdcall;
  TRARReadHeaderEx  = function(hArc: THandle; Data: PRARHeaderDataEx): Integer; stdcall;
  TRARProcessFileW  = function(hArc: THandle; Op: Integer; DestPath, DestName: PWideChar): Integer; stdcall;
  TRARSetCallback   = procedure(hArc: THandle; Callback: Pointer; UserData: NativeInt); stdcall;

{ Callback minimo: continua em todos os eventos. Single-volume, sem cripto. }
function UnrarCallback(msg: Cardinal; UserData, P1, P2: NativeInt): Integer; stdcall;
begin
  Result := 0;
end;

class function TUnrar.ExtractToFolder(const ARarPath, ADestDir: string;
  const AUnrarDllPath: string): Boolean;
var
  LLib: HMODULE;
  LOpen: TRAROpenArchiveEx;
  LClose: TRARCloseArchive;
  LRead: TRARReadHeaderEx;
  LProcess: TRARProcessFileW;
  LSetCb: TRARSetCallback;
  LOpenData: TRAROpenArchiveDataEx;
  LHeader: TRARHeaderDataEx;
  LArc: THandle;
  LRC: Integer;
  LDll, LDest: string;
  LArcW, LDestW: WideString;
begin
  Result := False;
  if not FileExists(ARarPath) then
    Exit;

  LDll := AUnrarDllPath;
  if LDll = '' then
    LDll := 'unrar.dll';
  LLib := LoadLibrary(PChar(LDll));
  if LLib = 0 then
    Exit;
  try
    LOpen    := TRAROpenArchiveEx(GetProcAddress(LLib, 'RAROpenArchiveEx'));
    LClose   := TRARCloseArchive(GetProcAddress(LLib, 'RARCloseArchive'));
    LRead    := TRARReadHeaderEx(GetProcAddress(LLib, 'RARReadHeaderEx'));
    LProcess := TRARProcessFileW(GetProcAddress(LLib, 'RARProcessFileW'));
    LSetCb   := TRARSetCallback(GetProcAddress(LLib, 'RARSetCallback'));
    if not (Assigned(LOpen) and Assigned(LClose) and Assigned(LRead) and Assigned(LProcess)) then
      Exit;

    LDest := ExcludeTrailingPathDelimiter(ADestDir);
    ForceDirectories(LDest);
    LArcW  := WideString(ARarPath);   // string do FPC e AnsiString; WideString garante UTF-16
    LDestW := WideString(LDest);

    FillChar(LOpenData, SizeOf(LOpenData), 0);
    LOpenData.ArcNameW := PWideChar(LArcW);
    LOpenData.OpenMode := RAR_OM_EXTRACT;

    LArc := LOpen(@LOpenData);
    if (LArc = 0) or (LOpenData.OpenResult <> 0) then
      Exit;
    try
      if Assigned(LSetCb) then
        LSetCb(LArc, @UnrarCallback, 0);
      repeat
        FillChar(LHeader, SizeOf(LHeader), 0);
        LRC := LRead(LArc, @LHeader);
        if LRC = ERAR_END_ARCHIVE then
        begin
          Result := True;
          Break;
        end;
        if LRC <> ERAR_SUCCESS then
          Break;  // erro de leitura -> Result permanece False
        LRC := LProcess(LArc, RAR_EXTRACT, PWideChar(LDestW), nil);
        if LRC <> ERAR_SUCCESS then
          Break;  // erro de extraccao -> Result permanece False
      until False;
    finally
      LClose(LArc);
    end;
  finally
    FreeLibrary(LLib);
  end;
end;

class function TUnrar.Available(const AUnrarDllPath: string): Boolean;
var
  LLib: HMODULE;
  LDll: string;
begin
  LDll := AUnrarDllPath;
  if LDll = '' then
    LDll := 'unrar.dll';
  LLib := LoadLibrary(PChar(LDll));
  Result := LLib <> 0;
  if Result then
    FreeLibrary(LLib);
end;

{$ELSE}

class function TUnrar.ExtractToFolder(const ARarPath, ADestDir: string;
  const AUnrarDllPath: string): Boolean;
begin
  Result := False;  // unrar.dll: Windows-only
end;

class function TUnrar.Available(const AUnrarDllPath: string): Boolean;
begin
  Result := False;
end;

{$ENDIF}

end.
