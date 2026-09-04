{ =============================================================================
  Attributers.Connections - Atributo RTTI [Connection] para configuração via classe

  Extraído de ProvidersORM v2.3.0 Attributers.Providers.Interfaces.pas (Onda
  4.1) - só a classe ConnectionAttribute veio; IAttributeParser/IAttributeMapper/
  IAttributeRegistry (mesmo ficheiro na origem) dependem de Database.Table.Interfaces,
  módulo que só chega na wave Database (posterior a Connections na ordem
  canónica) - não fazem parte deste ficheiro para não puxar essa dependência
  antes da hora. Mesmo padrão de Attributers.ActiveDirectory.pas (RTTI por
  módulo, um ficheiro Attributers.<Modulo> por módulo).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.22
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           06/07/2026

  Changelog (file):
  - 1.0.0 (06/07/2026): criação (Onda 4.1) - ConnectionAttribute extraído de
    Attributers.Providers.Interfaces.pas (v2.3.0), fiel ao original (mesmos
    campos/construtor/propriedades).
  ============================================================================= }
unit Attributers.Connections;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

uses
{$IF DEFINED(FPC)}
  SysUtils;
{$ELSE}
  System.SysUtils;
{$ENDIF}

{$IFDEF USE_ATTRIBUTES}
type
  { Atributo para configurar conexão a partir de uma classe.
    Uso: [Connection] ou [Connection('config.ini', 'database')] para INI;
    ou [Connection('', '', 'E:\dll', 'PostgreSQL', '127.0.0.1', 5432, 'user', 'pass', 'db', 'public')] }
  ConnectionAttribute = class(TCustomAttribute)
  private
    FIniFile: string;
    FSection: string;
    FDllBasePath: string;
    FDatabaseType: string;
    FHost: string;
    FPort: Integer;
    FUsername: string;
    FPassword: string;
    FDatabase: string;
    FSchema: string;
  public
    constructor Create(const AIniFile: string = ''; const ASection: string = '';
      const ADllBasePath: string = ''; const ADatabaseType: string = '';
      const AHost: string = ''; APort: Integer = -1;
      const AUsername: string = ''; const APassword: string = '';
      const ADatabase: string = ''; const ASchema: string = ''); overload;
    property IniFile: string read FIniFile;
    property Section: string read FSection;
    property DllBasePath: string read FDllBasePath;
    property DatabaseType: string read FDatabaseType;
    property Host: string read FHost;
    property Port: Integer read FPort;
    property Username: string read FUsername;
    property Password: string read FPassword;
    property Database: string read FDatabase;
    property Schema: string read FSchema;
  end;
{$ENDIF}

implementation

{$IFDEF USE_ATTRIBUTES}
constructor ConnectionAttribute.Create(const AIniFile, ASection, ADllBasePath,
  ADatabaseType, AHost: string; APort: Integer;
  const AUsername, APassword, ADatabase, ASchema: string);
begin
  inherited Create;
  FIniFile := AIniFile;
  FSection := ASection;
  FDllBasePath := ADllBasePath;
  FDatabaseType := ADatabaseType;
  FHost := AHost;
  FPort := APort;
  FUsername := AUsername;
  FPassword := APassword;
  FDatabase := ADatabase;
  FSchema := ASchema;
end;
{$ENDIF}

end.
