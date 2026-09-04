{ =============================================================================
  Database.TypeDatabase - Tipo de banco (TTypeDatabase, ITypeDatabase)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.0.0
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           26/02/2026

  Changelog (file):
  - 1.1.0 (12/07/2026): absorcao v3 (FASE 5 Onda 5.1) - uses
    Providers.Connection.Interfaces -> Connections.Interfaces; header v3.
  - 1.0.2 (07/04/2026): Compatibilidade FPC: MODE DELPHI adicionado antes da seção interface.
  - 1.0.0 (22/02/2026): Versão inicial; SupportsSchema, GetIdentifierQuote.
  - 1.0.1 (26/02/2026): GetIdentifierQuoteClose (] para SQL Server/Access); GetIdentifierQuote dtAccess usa '['.

  TTypeDatabase implementa ITypeDatabase; delega suporte a schema e delimitadores a Commons.Types/Consts.
  GetIdentifierQuote / GetIdentifierQuoteClose para delimitadores por engine (", `, []).
  ============================================================================= }

unit Database.TypeDatabase;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}
interface

{$I ORM.Defines.inc}

uses
  Commons.Types,
  Commons.Consts,
  Databases.Interfaces;

type
  TTypeDatabase = class(TInterfacedObject, ITypeDatabase)
  private
    FDatabaseType: TDatabaseTypes;
  public
    class function New: ITypeDatabase;

    function DatabaseType(const AValue: TDatabaseTypes): ITypeDatabase; overload;
    function DatabaseType: TDatabaseTypes; overload;

    function SupportsSchema: Boolean;
    function GetIdentifierQuote: string;
    function GetIdentifierQuoteClose: string;
  end;

implementation

class function TTypeDatabase.New: ITypeDatabase;
begin
  Result := TTypeDatabase.Create;
end;

function TTypeDatabase.DatabaseType(const AValue: TDatabaseTypes): ITypeDatabase;
begin
  FDatabaseType := AValue;
  Result := Self;
end;

function TTypeDatabase.DatabaseType: TDatabaseTypes;
begin
  Result := FDatabaseType;
end;

function TTypeDatabase.SupportsSchema: Boolean;
begin
  Result := TDatabaseTypeHasSchema[FDatabaseType];
end;

function TTypeDatabase.GetIdentifierQuote: string;
begin
  case FDatabaseType of
    dtMySQL: Result := '`';
    dtSQLServer, dtAccess: Result := '[';
  else
    Result := '"';
  end;
end;

function TTypeDatabase.GetIdentifierQuoteClose: string;
begin
  case FDatabaseType of
    dtSQLServer, dtAccess: Result := ']';
  else
    Result := GetIdentifierQuote;
  end;
end;

end.
