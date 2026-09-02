{ ==========================================================================
  PROVENANCE NOTE (ProvidersORM v3, FASE 10 Onda 10.2 - USE_PROVIDERS_V161):
  Absorbed VERBATIM from FontesReferencias/ProvidersORM.v1.6.1/Commons/Providers.Common.Connection.pas
  into this v3 tree as part of the USE_PROVIDERS_V161 compatibility subsystem
  (legacy ProvidersORM v1.6.1, mechanical port only - zero logic/behavior/
  symbol-name changes; see the unit's own original header below for the
  authorial history). Reachable via uses Providers.v161 - NOT part of the
  unified TProviders facade (Main/Providers.pas).

  MECHANICAL FIX: uses System.SysUtils, System.Classes (Delphi-scoped names,
  unresolvable under FPC in this toolchain) wrapped in an FPC conditional
  with the bare SysUtils/Classes names on the FPC branch and the System.*
  qualified names on the Delphi branch - same unit, same symbols, no logic
  change (matches this project's own established convention, e.g.
  Commons/Commons.Types.pas). File re-saved as UTF-8 BOM.
  ========================================================================== }

{
  Providers.Common.Connection - Helpers de Conexão para Provider v1.6.0
  
  Responsabilidade:
    - Gerenciamento de conexões
    - Configuração de providers
    - Validação de parâmetros de conexão
    
  Compatibilidade: v1.5.0, v1.6.0
  Autor: Claiton de Souza Linhares
  Data: 27/01/2025
}
unit Providers.Common.Connection;

interface

uses
{$IFDEF FPC}
  SysUtils, Classes,
{$ELSE}
  System.SysUtils, System.Classes,
{$ENDIF}
  Utilities.Types;

type
  TProviderConnectionHelper = class
  public
    // Obter nome do provider master
    class function GetProviderMasterName(AProvider: TDatabaseProvider): String;
    
    // Validar parâmetros de conexão
    class function ValidateConnectionParams(AProvider: TDatabaseProvider; 
      const AHost: String; APort: Integer; const ADatabase: String): Boolean;
    
    // Obter porta padrão por provider
    class function GetDefaultPort(AProvider: TDatabaseProvider): Integer;
    
    // Obter string de conexão formatada
    class function GetConnectionString(AProvider: TDatabaseProvider; 
      const AHost: String; APort: Integer; const ADatabase, AUsername: String): String;
    
    // Verificar se provider requer schema
    class function RequiresSchema(AProvider: TDatabaseProvider): Boolean;
    
    // Verificar se provider requer servidor
    class function RequiresServer(AProvider: TDatabaseProvider): Boolean;
  end;

implementation

{ TProviderConnectionHelper }

class function TProviderConnectionHelper.GetProviderMasterName(AProvider: TDatabaseProvider): String;
begin
  case AProvider of
    dpFireBird, dpFireBird3: Result := 'InterBase';
    dpMariaDB: Result := 'MySQL';
    dpPostgreSQL: Result := 'PostgreSQL';
    dpSQLite: Result := 'SQLite';
    dpSQLServer: Result := 'SQL Server';
    dpNone: raise Exception.Create('TProviders Erro, falta selecionar o Tipo de Banco de dados');
  else
    Result := 'PostgreSQL';
  end;
end;

class function TProviderConnectionHelper.ValidateConnectionParams(AProvider: TDatabaseProvider; 
  const AHost: String; APort: Integer; const ADatabase: String): Boolean;
begin
  Result := False;
  
  // SQLite não requer servidor
  if AProvider = dpSQLite then
  begin
    Result := not ADatabase.IsEmpty;
    Exit;
  end;
  
  // Outros providers requerem servidor e porta
  if AHost.IsEmpty then
    Exit;
    
  if APort <= 0 then
    Exit;
    
  if ADatabase.IsEmpty then
    Exit;
    
  Result := True;
end;

class function TProviderConnectionHelper.GetDefaultPort(AProvider: TDatabaseProvider): Integer;
begin
  case AProvider of
    dpPostgreSQL: Result := 5432;
    dpMySQL, dpMariaDB: Result := 3306;
    dpSQLServer: Result := 1433;
    dpFireBird, dpFireBird3: Result := 3050;
    dpSQLite: Result := 0; // Não usa porta
  else
    Result := 5432;
  end;
end;

class function TProviderConnectionHelper.GetConnectionString(AProvider: TDatabaseProvider; 
  const AHost: String; APort: Integer; const ADatabase, AUsername: String): String;
begin
  if AProvider = dpSQLite then
  begin
    Result := Format('Database=%s', [ADatabase]);
  end
  else
  begin
    Result := Format(
      'Host=%s' + sLineBreak +
      'Port=%d' + sLineBreak +
      'Database=%s' + sLineBreak +
      'User=%s',
      [AHost, APort, ADatabase, AUsername]);
  end;
end;

class function TProviderConnectionHelper.RequiresSchema(AProvider: TDatabaseProvider): Boolean;
begin
  Result := AProvider in [dpPostgreSQL, dpSQLServer];
end;

class function TProviderConnectionHelper.RequiresServer(AProvider: TDatabaseProvider): Boolean;
begin
  Result := AProvider <> dpSQLite;
end;

end.

