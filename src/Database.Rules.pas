{ =============================================================================
  Database.Rules - Colecao de RULES do banco, Connection-bound
  (TRules, IRules)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           29/07/2026

  Onda F4 (camada DDL fluente zero-SQL) - colecao NOVA de nivel IDatabase:
  RULES (mesmo padrao Connection-bound de TTriggers/TViews). O objecto RULE
  existe so em PostgreSQL/SQL Server; nos outros 5 motores o dialecto devolve
  SQL '' -> CreateRule/DropRule tornam-se no-op (0) e RuleNames vem [].

  Delega a TDialect.ForConnection(FConnection).Rule (CreateSQL/DropSQL) e a
  TCatalogReader.New(FConnection) (RuleNames/RuleExists); degrada graciosamente
  (''/0/False/[]) quando USE_DATABASE esta OFF, sem Connection, conexao
  desligada, ou motor sem RULE.

  Changelog (file):
  - 1.0.0 (29/07/2026): versao inicial (Onda F4) - colecao NOVA, Connection-
    bound, consome IRuleDefinition (builder) + faceta IRuleDialect.
  ============================================================================= }
unit Database.Rules;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}
interface

{$I ORM.Defines.inc}

uses
  Databases.Interfaces,
  Connections.Interfaces,
  Commons.Types;

type
  TRules = class(TInterfacedObject, IRules)
  private
    FConnection: IConnection;
    FDatabaseTypes: TDatabaseTypes;
  public
    constructor Create;
    class function New: IRules;
    function Connection(const AConnection: IConnection): IRules; overload;
    function Connection: IConnection; overload;
    function RuleNames: TStringArray;
    function RuleExists(const AName: string): Boolean;
    function CreateRuleSQL(const ADef: IRuleDefinition): string;
    function DropRuleSQL(const AName, ATable: string; const AIfExists: Boolean = True): string;
    function CreateRule(const ADef: IRuleDefinition): Integer;
    function DropRule(const AName, ATable: string): Integer;
  end;

implementation

uses
{$IF DEFINED(FPC)}
  SysUtils
{$ELSE}
  System.SysUtils
{$ENDIF}
{$IFDEF USE_DATABASE}
  , Database.Dialect
  , Database.CatalogReader
{$ENDIF}
  ;

constructor TRules.Create;
begin
  inherited Create;
  FDatabaseTypes := dtNone;
end;

class function TRules.New: IRules;
begin
  Result := TRules.Create;
end;

function TRules.Connection(const AConnection: IConnection): IRules;
begin
  FConnection := AConnection;
  if AConnection <> nil then
    FDatabaseTypes := AConnection.DatabaseType
  else
    FDatabaseTypes := dtNone;
  Result := Self;
end;

function TRules.Connection: IConnection;
begin
  Result := FConnection;
end;

function TRules.RuleNames: Commons.Types.TStringArray;
begin
  SetLength(Result, 0);
{$IFDEF USE_DATABASE}
  if (FConnection = nil) or not FConnection.IsConnected then
    Exit;
  Result := TCatalogReader.New(FConnection).RuleNames('');
{$ENDIF}
end;

function TRules.RuleExists(const AName: string): Boolean;
begin
  Result := False;
{$IFDEF USE_DATABASE}
  if (FConnection = nil) or not FConnection.IsConnected then
    Exit;
  Result := TCatalogReader.New(FConnection).RuleExists(Trim(AName), '');
{$ENDIF}
end;

function TRules.CreateRuleSQL(const ADef: IRuleDefinition): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (ADef = nil) or (FDatabaseTypes = dtNone) then
    Exit;
  Result := TDialect.ForDatabaseType(FDatabaseTypes).Rule.CreateSQL(ADef);
{$ENDIF}
end;

function TRules.DropRuleSQL(const AName, ATable: string; const AIfExists: Boolean): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (Trim(AName) = '') or (FDatabaseTypes = dtNone) then
    Exit;
  Result := TDialect.ForDatabaseType(FDatabaseTypes).Rule.DropSQL(Trim(AName), Trim(ATable), AIfExists);
{$ENDIF}
end;

function TRules.CreateRule(const ADef: IRuleDefinition): Integer;
{$IFDEF USE_DATABASE}
var
  LSQL: string;
{$ENDIF}
begin
  { Onda F4 - zero-SQL: o dialecto compoe o CREATE RULE (PG/SQL Server); no-op/0
    onde nao suportado. Idempotente: so cria se ainda nao existir. }
  Result := 0;
{$IFDEF USE_DATABASE}
  if (FConnection = nil) or not FConnection.IsConnected then
    Exit;
  if (ADef = nil) or (Trim(ADef.Name) = '') then
    Exit;
  if TCatalogReader.New(FConnection).RuleExists(Trim(ADef.Name), '') then
    Exit;
  LSQL := TDialect.ForConnection(FConnection).Rule.CreateSQL(ADef);
  if Trim(LSQL) <> '' then
    Result := FConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

function TRules.DropRule(const AName, ATable: string): Integer;
{$IFDEF USE_DATABASE}
var
  LDialect: IDialect;
  LSQL: string;
{$ENDIF}
begin
  Result := 0;
{$IFDEF USE_DATABASE}
  if (FConnection = nil) or not FConnection.IsConnected then
    Exit;
  if Trim(AName) = '' then
    Exit;
  LDialect := TDialect.ForConnection(FConnection);
  { idempotente: com introspecao so remove se existir; senao confia no IF
    EXISTS da sintaxe do banco. }
  if (Trim(LDialect.RulesSQL('')) <> '') and
     (not TCatalogReader.New(FConnection).RuleExists(Trim(AName), '')) then
    Exit;
  LSQL := LDialect.Rule.DropSQL(Trim(AName), Trim(ATable), True);
  if Trim(LSQL) <> '' then
    Result := FConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

end.
