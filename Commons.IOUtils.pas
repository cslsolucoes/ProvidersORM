
unit Commons.IOUtils;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{ =============================================================================
  Providers.Commons.IOUtils - Compatibilidade TFile/TPath para FPC (Commons)

  Unit exclusiva para FPC: replica a API de System.IOUtils (TFile e TPath)
  do Delphi usando SysUtils/Classes.

  Uso nas demais units: em FPC use Providers.Commons.IOUtils, em Delphi System.IOUtils
  (uses
  condicional); em seguida TFile.Exists(), TPath.GetDirectoryName(), etc.

  Estrutura igual à do Delphi: classes com métodos de classe (class function),
  sem herança entre TFile e TPath (espelhando System.IOUtils).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026
  Changelog (file):
  - 1.1.0 (03/08/2026): + TPath.GetTempPath (espelha System.IOUtils.TPath.GetTempPath —
    caminho da pasta temporária COM separador final), via SysUtils.GetTempDir do FPC.
    Necessário pelo adapter ReportBuilder (F9 Onda 9.2, AutoBind — grava o .rtm limpo
    em ficheiro temporário) que antes só tinha ramo Delphi (`System.IOUtils`), sem
    equivalente FPC. Aditivo, F1 concluída, autorizado (mesmo padrão de extensão já
    usado noutras peças concluídas nesta fase F9).
  - 1.0.0 (03/02/2026): Versão inicial.
  ============================================================================= }

interface
{$IF DEFINED(FPC)}
uses
  SysUtils,
  Classes;

type
  { Espelha System.IOUtils.TFile - apenas métodos de classe }
  TFile = class
  public
    class function Exists(const APath: string): Boolean;
    class function ReadAllText(const APath: string): string;
    class procedure WriteAllText(const APath, AContents: string);
  end;

  { Espelha System.IOUtils.TPath - apenas métodos de classe }
  TPath = class
  public
    class function GetDirectoryName(const APath: string): string;
    class function GetFileName(const APath: string): string;
    class function GetFileNameWithoutExtension(const APath: string): string;
    class function GetExtension(const APath: string): string;
    class function Combine(const APath1, APath2: string): string;
    class function GetFullPath(const APath: string): string;
    class function GetTempPath: string;
  end;
{$ENDIF}
implementation
{$IF DEFINED(FPC)}
{ TFile }

class function TFile.Exists(const APath: string): Boolean;
begin
  Result := FileExists(APath);
end;

class function TFile.ReadAllText(const APath: string): string;
var
  LList: TStringList;
begin
  LList := TStringList.Create;
  try
    LList.LoadFromFile(APath);
    Result := LList.Text;
  finally
    LList.Free;
  end;
end;

class procedure TFile.WriteAllText(const APath, AContents: string);
var
  LList: TStringList;
  LDir: string;
begin
  LDir := ExtractFilePath(APath);
  if (LDir <> '') and not DirectoryExists(LDir) then
    ForceDirectories(LDir);
  LList := TStringList.Create;
  try
    LList.Text := AContents;
    LList.SaveToFile(APath);
  finally
    LList.Free;
  end;
end;

{ TPath }

class function TPath.GetDirectoryName(const APath: string): string;
begin
  Result := ExtractFilePath(APath);
  if (Result <> '') and (Result[Length(Result)] = DirectorySeparator) then
    SetLength(Result, Length(Result) - 1);
end;

class function TPath.GetFileName(const APath: string): string;
begin
  Result := ExtractFileName(APath);
end;

class function TPath.GetFileNameWithoutExtension(const APath: string): string;
begin
  Result := ChangeFileExt(ExtractFileName(APath), '');
end;

class function TPath.GetExtension(const APath: string): string;
begin
  Result := ExtractFileExt(APath);
end;

class function TPath.Combine(const APath1, APath2: string): string;
var
  LIsAbsolute: Boolean;
begin
  if APath2 = '' then
    Result := APath1
  else
  begin
    LIsAbsolute := (Length(APath2) >= 1) and ((APath2[1] = DirectorySeparator) or
      ((Length(APath2) >= 2) and (APath2[2] = ':')));
    if (APath1 = '') or LIsAbsolute then
      Result := APath2
    else
      Result := IncludeTrailingPathDelimiter(APath1) + APath2;
  end;
end;

class function TPath.GetFullPath(const APath: string): string;
begin
  Result := ExpandFileName(APath);
end;

class function TPath.GetTempPath: string;
begin
  Result := IncludeTrailingPathDelimiter(SysUtils.GetTempDir);
end;
{$ENDIF}
end.
