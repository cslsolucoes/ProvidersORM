unit Commons.DynamicLibrary;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

{ =============================================================================
  Commons.DynamicLibrary - SSOT da resolucao de paths de DLLs cliente por banco

  Servico central (nucleo, §3-C) consumido por Connection (F4) e Parameters (F6):
  resolve o caminho da DLL cliente por (tipo de banco, plataforma, versao Firebird)
  no padrao canonico <exe>/dll/[win32|win64]/[FireBird/N|FreeTDS|MySql|PostgreSQL|SQLite]/.
  PURE path resolution — NAO depende de engine (Zeos/FireDAC/etc.). Os configuradores
  de engine (ConfigureZeos/FireDAC VendorLib) e a leitura de 'database_dll' do config
  vivem nos modulos que consomem esta unit (Connection F4 / Parameters F6).

  Promovido de src/Commons/Parameters.DynamicLibrary.pas (v1.0.7) + extraido de
  Commons.Types (Onda 1.1); Firebird passa a MULTI-VERSAO (plano §2-D).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  FileVersion:    1.2.0
  Author:         Claiton de Souza Linhares
  Date:           04/07/2026

  Changelog (file):
  - 1.2.0 (16/07/2026): TConnectionDLL.Directory/.Path + GetVendorLibPath/
    GetVendorLibDirectory passam a resolver dtSQLAnywhere (F5 Onda 10) -
    <base>/dll/<plat>/SQLAnywhere/dbcapi.dll, single-folder (sem multi-versao
    como o Firebird). Cliente NATIVO (Zeos protocolo 'asa_capi'/FireDAC/UniDAC),
    NAO ODBC.
  - 1.1.0 (06/07/2026): GetVendorLibPath/GetVendorLibDirectory passam a resolver
    dtSQLite (<base>/dll/<plat>/SQLite/sqlite3.dll) — antes caiam no else '' (o record
    helper .Directory/.Path ja tratava SQLite, mas as free functions nao). F4 Onda 4.1.
  - 1.0.0 (04/07/2026): v3 (F1 Onda 1.3). Record helper TConnectionDLL + free functions
    de resolucao (Resolve/GetVendorLibPath[MySQLAlt]/GetVendorLibDirectory/GetFirebirdLib*)
    movidos de Commons.Types (que fica so com tipos). AppendPathEnv promovido da v1.0.7.
  ============================================================================= }

interface

{$I ../ORM.Defines.inc}
{$IFDEF FPC}
  {$I Commons.FPC.inc}
{$ENDIF}

uses
  {$IF DEFINED(FPC)}
  SysUtils{$IF DEFINED(WINDOWS)},
  Windows{$ENDIF},
  {$ELSE}
  System.SysUtils{$IF DEFINED(MSWINDOWS)},
  Winapi.Windows{$ENDIF},
  {$ENDIF}
  Commons.Types,
  Commons.Consts;

type
  { Record helper para TDatabaseTypes. Uso: dtPostgreSQL.Directory, FDatabaseType.Path. }
  TConnectionDLL = record helper for TDatabaseTypes
  public
    function BaseDirectory: string;
    function Directory: string;
    function Path: string;
  end;

  { Resolução de paths de DLLs por tipo de banco (win32/win64). Usado por Connection e outros módulos. }
  function ResolveDllBasePath(const ABasePath: string; const AExePath: string): string;
  function GetVendorLibPath(const ABasePath: string; const AExePath: string; ADatabaseType: TDatabaseTypes; AFirebirdVersion: TFirebirdVersion = fb50): string;
  function GetVendorLibPathMySQLAlt(const ABasePath: string; const AExePath: string): string;
  function GetVendorLibDirectory(const ABasePath: string; const AExePath: string; ADatabaseType: TDatabaseTypes; AFirebirdVersion: TFirebirdVersion = fb50): string;

  { Firebird e MULTI-VERSAO (dll\plat\FireBird\N\). Estas funcoes compoem o path
    com a subpasta da versao (FIREBIRD_VERSION_SUBDIR). Ver plano secao 2-D. }
  function GetFirebirdLibDirectory(AVersion: TFirebirdVersion; const ABasePath: string; const AExePath: string): string;
  function GetFirebirdLibPath(AVersion: TFirebirdVersion; const ABasePath: string; const AExePath: string): string;

  { Acrescenta ADirectory ao inicio do PATH do processo (Windows). No-op fora do Windows. }
  procedure AppendPathEnv(const ADirectory: string);

implementation

{ TConnectionDLL }

function TConnectionDLL.BaseDirectory: string;
Begin
  // IMPORTANTE: Sempre retorna caminho absoluto baseado no executável
  // Usa a constante DEFAULT_DLL_DIRECTORY_NAME de Database.Consts
  // Se for caminho absoluto, usa direto; caso contrário, expande para absoluto
  if (Length(DEFAULT_DATABASE_PATH_DLL) > 1) and (DEFAULT_DATABASE_PATH_DLL[2] = ':') then
    // Caminho absoluto (ex: E:\CSL\ORM\src\Database\dll)
    Result := DEFAULT_DATABASE_PATH_DLL
  else
  begin
    // Caminho relativo ao executável - SEMPRE expande para absoluto
    Result := ExtractFilePath(ParamStr(0));
    Result := IncludeTrailingPathDelimiter(Result) + DEFAULT_DLL_DIRECTORY;
    // Garante que seja absoluto usando ExpandFileName
    Result := ExpandFileName(Result);
  end;
  Result := IncludeTrailingPathDelimiter(Result);
end;

function TConnectionDLL.Directory: string;
begin
  case Self of
    dtPostgreSQL:
      Result := DEFAULT_DLL_PATH_POSTGRESQL;
    dtMySQL:
      Result := DEFAULT_DLL_PATH_MYSQL;
    dtSQLServer:
      // SQL Server: Zeos usa FreeTDS (libsybdb-5.dll), UniDAC/FireDAC usam DLL do sistema
      case DEFAULT_DATABASE_ENGINE of
        teZeos:
          Result := DEFAULT_DLL_PATH_SQLSERVER_FREETDS; // FreeTDS para Zeos
        else
          Result := DEFAULT_DLL_PATH_SQLSERVER; // UniDAC/FireDAC usam DLL do sistema
      end;
    dtFireBird:
      // Firebird multi-versao: base + subpasta da versao default (5.0).
      // Para outra versao usar GetFirebirdLibDirectory(AVersion, ...).
      Result := DEFAULT_DLL_PATH_FIREBIRD +
                FIREBIRD_VERSION_SUBDIR[DEFAULT_FIREBIRD_VERSION] + DirectorySeparator;
    dtSQLite:
      // SQLite: cria subdiretório SQLite para organizar as DLLs
      Result := DEFAULT_DLL_PATH_SQLITE;
    dtSQLAnywhere:
      // SQL Anywhere: cliente nativo dbcapi.dll (Zeos/FireDAC/UniDAC) - nao ODBC
      Result := DEFAULT_DLL_PATH_SQLANYWHERE;
  else
    Result := BaseDirectory;
  end;
end;

function TConnectionDLL.Path: string;
var
  LDLLName: string;
begin
  Result := '';
  case Self of
    dtPostgreSQL:
      LDLLName := DEFAULT_DLL_NAME_POSTGRESQL; // 'libpq.dll'
    dtMySQL:
      LDLLName := DEFAULT_DLL_NAME_MYSQL; // 'libmysql.dll'
    dtSQLServer:
      case DEFAULT_DATABASE_ENGINE of
        teUnidac:
          LDLLName := DEFAULT_DLL_NAME_SQLSERVER; // 'sqlncli11.dll'
        teZeos:
          LDLLName := DEFAULT_DLL_NAME_SQLSERVER_FREETDS; // 'libsybdb-5.dll' (FreeTDS)
        else
          LDLLName := 'msodbcsql17.dll'; // FireDAC usa ODBC Driver 17
      end;
    dtFireBird:
      LDLLName := DEFAULT_DLL_NAME_FIREBIRD; // 'fbclient.dll' (todas as versoes 2.5+)
    dtSQLite:
      LDLLName := DEFAULT_DLL_NAME_SQLITE; // 'sqlite3.dll'
    dtSQLAnywhere:
      LDLLName := DEFAULT_DLL_NAME_SQLANYWHERE; // 'dbcapi.dll' (nativo Zeos/FireDAC/UniDAC)
  else
    Exit; // Outros bancos não precisam de DLL específica
  end;

  if LDLLName <> '' then
    Result := Directory + LDLLName;
end;

{ Resolução de paths de DLLs (centralizado; antes em Providers.Connection.Types) }

function ResolveDllBasePath(const ABasePath: string; const AExePath: string): string;
var
  LBase: string;
begin
  LBase := Trim(ABasePath);
  if LBase = '' then
    Result := IncludeTrailingPathDelimiter(Trim(AExePath)) + 'dll' + PathDelim
  else
    Result := IncludeTrailingPathDelimiter(LBase);
end;

function GetVendorLibPath(const ABasePath: string; const AExePath: string; ADatabaseType: TDatabaseTypes; AFirebirdVersion: TFirebirdVersion = fb50): string;
var
  LBase: string;
begin
  Result := '';
  // <base>/dll/<plat>/ ; plataforma e nomes vem de Commons.Consts (SSOT, zero literais)
  LBase := ResolveDllBasePath(ABasePath, AExePath) + DLL_PLATFORM_SUBDIR + PathDelim;
  case ADatabaseType of
    dtPostgreSQL:
      Result := LBase + DLL_SUBDIR_POSTGRESQL + PathDelim + DEFAULT_DLL_NAME_POSTGRESQL;
    dtMySQL:
      // MariaDB e a preferida; GetVendorLibPathMySQLAlt forca libmysql
      Result := LBase + DLL_SUBDIR_MYSQL + PathDelim + DEFAULT_DLL_NAME_MYSQL_MARIADB;
    dtSQLServer:
      // FreeTDS (Zeos); UniDAC/FireDAC usam a DLL do sistema (ver record helper Path)
      Result := LBase + DLL_SUBDIR_SQLSERVER_FREETDS + PathDelim + DEFAULT_DLL_NAME_SQLSERVER_FREETDS;
    dtSQLite:
      // SQLite: <base>/dll/<plat>/SQLite/sqlite3.dll (Zeos usa LibLocation; consts SSOT)
      Result := LBase + DLL_SUBDIR_SQLITE + PathDelim + DEFAULT_DLL_NAME_SQLITE;
    dtFireBird:
      Result := GetFirebirdLibPath(AFirebirdVersion, ABasePath, AExePath);
    dtSQLAnywhere:
      // SQL Anywhere: <base>/dll/<plat>/SQLAnywhere/dbcapi.dll (nativo; Zeos LibLocation)
      Result := LBase + DLL_SUBDIR_SQLANYWHERE + PathDelim + DEFAULT_DLL_NAME_SQLANYWHERE;
  else
    Result := '';
  end;
end;

function GetVendorLibPathMySQLAlt(const ABasePath: string; const AExePath: string): string;
begin
  Result := ResolveDllBasePath(ABasePath, AExePath) + DLL_PLATFORM_SUBDIR + PathDelim +
            DLL_SUBDIR_MYSQL + PathDelim + DEFAULT_DLL_NAME_MYSQL;
end;

function GetVendorLibDirectory(const ABasePath: string; const AExePath: string; ADatabaseType: TDatabaseTypes; AFirebirdVersion: TFirebirdVersion = fb50): string;
var
  LBase: string;
begin
  Result := '';
  LBase := ResolveDllBasePath(ABasePath, AExePath) + DLL_PLATFORM_SUBDIR + PathDelim;
  case ADatabaseType of
    dtPostgreSQL:
      Result := LBase + DLL_SUBDIR_POSTGRESQL;
    dtMySQL:
      Result := LBase + DLL_SUBDIR_MYSQL;
    dtSQLServer:
      Result := LBase + DLL_SUBDIR_SQLSERVER_FREETDS;
    dtSQLite:
      Result := LBase + DLL_SUBDIR_SQLITE;
    dtFireBird:
      Result := GetFirebirdLibDirectory(AFirebirdVersion, ABasePath, AExePath);
    dtSQLAnywhere:
      Result := LBase + DLL_SUBDIR_SQLANYWHERE;
  else
    Result := '';
  end;
end;

{ Firebird multi-versao: dll\plat\FireBird\N\ (N = FIREBIRD_VERSION_SUBDIR) }

function GetFirebirdLibDirectory(AVersion: TFirebirdVersion; const ABasePath: string; const AExePath: string): string;
begin
  Result := ResolveDllBasePath(ABasePath, AExePath) + DLL_PLATFORM_SUBDIR + PathDelim +
            DLL_SUBDIR_FIREBIRD + PathDelim + FIREBIRD_VERSION_SUBDIR[AVersion];
end;

function GetFirebirdLibPath(AVersion: TFirebirdVersion; const ABasePath: string; const AExePath: string): string;
begin
  Result := IncludeTrailingPathDelimiter(
    GetFirebirdLibDirectory(AVersion, ABasePath, AExePath)) + DEFAULT_DLL_NAME_FIREBIRD;
end;


{ AppendPathEnv (promovido de Parameters.DynamicLibrary v1.0.7) }

{$IF DEFINED(MSWINDOWS) OR DEFINED(WINDOWS)}
{$IF DEFINED(FPC)}
function GetEnvironmentVariableValue(const AName: string): string;
var
  LBuffer: array[0..32767] of Char;
  LSize: DWORD;
begin
  Result := '';
  LSize := Windows.GetEnvironmentVariable(PChar(AName), LBuffer, SizeOf(LBuffer));
  if LSize > 0 then
    Result := string(LBuffer);
end;
{$ENDIF}

procedure AppendPathEnv(const ADirectory: string);
var
  LCurrent: string;
begin
  if Trim(ADirectory) = '' then
    Exit;
  {$IF DEFINED(FPC)}
  LCurrent := GetEnvironmentVariableValue('PATH');
  {$ELSE}
  LCurrent := GetEnvironmentVariable('PATH');
  {$ENDIF}
  SetEnvironmentVariable('PATH', PChar(ADirectory + ';' + LCurrent));
end;
{$ELSE}
procedure AppendPathEnv(const ADirectory: string);
begin
  // Non-Windows: PATH append nao se aplica ao carregamento via LibraryLocation/VendorLib. No-op.
end;
{$ENDIF}

end.
