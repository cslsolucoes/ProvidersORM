{ =============================================================================
  Database.Triggers - Colecao de TRIGGERS do banco, Connection-bound
  (TTriggers, ITriggers)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           29/07/2026

  Onda F3 (camada DDL fluente zero-SQL) - colecao NOVA de nivel IDatabase:
  TRIGGERS sao objectos de BANCO (mesmo padrao de TViews/TProcedures/
  TFunctions). Connection-bound (Connection getter/setter fluente); cacheia
  DatabaseTypes a partir da Connection injectada para que *SQL
  (CreateTriggerSQL/DropTriggerSQL) funcionem sem exigir conexao LIGADA
  (TDialect.ForDatabaseType), enquanto os metodos que EXECUTAM
  (CreateTrigger/DropTrigger) exigem Connection ligada e resolvem o dialecto
  por TDialect.ForConnection (version-aware).

  Delega a TDialect.ForConnection(FConnection).Trigger (CreateSQL/DropSQL) e a
  TCatalogReader.New(FConnection) (TriggerNames/TriggerExists) para as
  operacoes reais; degrada graciosamente (''/0/False/[]) quando USE_DATABASE
  esta OFF, sem Connection injectada, conexao desligada, ou motor sem triggers
  (Access -> SQL '').

  GOTCHA (PostgreSQL): CreateSQL/DropSQL do dialecto podem devolver MULTIPLOS
  statements separados pelo caractere NUL (#0) - PostgreSQL emite a FUNCTION
  trigger + o TRIGGER (e no drop, o TRIGGER + a FUNCTION). ExecMulti divide por
  #0 e executa cada parte por ExecuteCommand (o #0 nunca ocorre em SQL legitimo,
  logo e um separador seguro; mantem TODO o SQL por-banco dentro do dialecto,
  fora do lancador). Devolve as linhas afectadas do ULTIMO statement.

  GOTCHA de uses (Do-Not-Repeat, evita E2004/E2003): TriggerNames devolve
  TStringArray - Commons.Types fica SO no uses da INTERFACE (nao no da
  implementation, que ja o herda por visibilidade de seccao) - mesmo padrao de
  Database.Procedures.pas.

  Changelog (file):
  - 1.0.0 (29/07/2026): versao inicial (Onda F3) - colecao NOVA, Connection-
    bound, consome ITriggerDefinition (builder) + faceta ITriggerDialect.
  ============================================================================= }
unit Database.Triggers;

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
  TTriggers = class(TInterfacedObject, ITriggers)
  private
    FConnection: IConnection;
    FDatabaseTypes: TDatabaseTypes;
    { executa ASQL, dividindo por #0 (PostgreSQL FUNCTION+TRIGGER); devolve as
      linhas afectadas do ultimo statement nao vazio. }
    function ExecMulti(const ASQL: string): Integer;
  public
    constructor Create;
    class function New: ITriggers;
    function Connection(const AConnection: IConnection): ITriggers; overload;
    function Connection: IConnection; overload;
    function TriggerNames: TStringArray;
    function TriggerExists(const AName: string): Boolean;
    function CreateTriggerSQL(const ADef: ITriggerDefinition): string;
    function DropTriggerSQL(const AName, ATable: string; const AIfExists: Boolean = True): string;
    function CreateTrigger(const ADef: ITriggerDefinition): Integer;
    function DropTrigger(const AName, ATable: string): Integer;
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

constructor TTriggers.Create;
begin
  inherited Create;
  FDatabaseTypes := dtNone;
end;

class function TTriggers.New: ITriggers;
begin
  Result := TTriggers.Create;
end;

function TTriggers.Connection(const AConnection: IConnection): ITriggers;
begin
  FConnection := AConnection;
  if AConnection <> nil then
    FDatabaseTypes := AConnection.DatabaseType
  else
    FDatabaseTypes := dtNone;
  Result := Self;
end;

function TTriggers.Connection: IConnection;
begin
  Result := FConnection;
end;

function TTriggers.ExecMulti(const ASQL: string): Integer;
{$IFDEF USE_DATABASE}
var
  LParts: TArray<string>;
  I: Integer;
  LStmt: string;
{$ENDIF}
begin
  Result := 0;
{$IFDEF USE_DATABASE}
  if (FConnection = nil) or not FConnection.IsConnected then
    Exit;
  if Trim(ASQL) = '' then
    Exit;
  LParts := ASQL.Split([#0]);
  for I := 0 to High(LParts) do
  begin
    LStmt := Trim(LParts[I]);
    if LStmt <> '' then
      Result := FConnection.ExecuteCommand(LStmt);
  end;
{$ENDIF}
end;

function TTriggers.TriggerNames: Commons.Types.TStringArray;
begin
  SetLength(Result, 0);
{$IFDEF USE_DATABASE}
  if (FConnection = nil) or not FConnection.IsConnected then
    Exit;
  Result := TCatalogReader.New(FConnection).TriggerNames('');
{$ENDIF}
end;

function TTriggers.TriggerExists(const AName: string): Boolean;
begin
  Result := False;
{$IFDEF USE_DATABASE}
  if (FConnection = nil) or not FConnection.IsConnected then
    Exit;
  Result := TCatalogReader.New(FConnection).TriggerExists(Trim(AName), '');
{$ENDIF}
end;

function TTriggers.CreateTriggerSQL(const ADef: ITriggerDefinition): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (ADef = nil) or (FDatabaseTypes = dtNone) then
    Exit;
  Result := TDialect.ForDatabaseType(FDatabaseTypes).Trigger.CreateSQL(ADef);
{$ENDIF}
end;

function TTriggers.DropTriggerSQL(const AName, ATable: string; const AIfExists: Boolean): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (Trim(AName) = '') or (FDatabaseTypes = dtNone) then
    Exit;
  Result := TDialect.ForDatabaseType(FDatabaseTypes).Trigger.DropSQL(Trim(AName), Trim(ATable), AIfExists);
{$ENDIF}
end;

function TTriggers.CreateTrigger(const ADef: ITriggerDefinition): Integer;
{$IFDEF USE_DATABASE}
var
  LSQL: string;
{$ENDIF}
begin
  { Onda F3 - zero-SQL: o dialecto (version-aware, ForConnection) compoe o
    CREATE TRIGGER (e, no PostgreSQL, a FUNCTION trigger) a partir do builder;
    degrada para no-op/0 quando o motor nao suporta triggers (Access ->
    TriggerDefCreateSQL='') ou sem conexao ligada. Idempotente: so cria se o
    trigger ainda nao existir (introspecao; sem SQL de triggers o dialecto
    degrada para "nao existe" e tenta criar). }
  Result := 0;
{$IFDEF USE_DATABASE}
  if (FConnection = nil) or not FConnection.IsConnected then
    Exit;
  if (ADef = nil) or (Trim(ADef.Name) = '') then
    Exit;
  if TCatalogReader.New(FConnection).TriggerExists(Trim(ADef.Name), '') then
    Exit;
  LSQL := TDialect.ForConnection(FConnection).Trigger.CreateSQL(ADef);
  if Trim(LSQL) <> '' then
    Result := ExecMulti(LSQL);
{$ENDIF}
end;

function TTriggers.DropTrigger(const AName, ATable: string): Integer;
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
    EXISTS da sintaxe do banco (DropSQL AIfExists=True) - mesmo padrao de
    TProcedures.DropProcedure. }
  if (Trim(LDialect.TriggersSQL('')) <> '') and
     (not TCatalogReader.New(FConnection).TriggerExists(Trim(AName), '')) then
    Exit;
  LSQL := LDialect.Trigger.DropSQL(Trim(AName), Trim(ATable), True);
  if Trim(LSQL) <> '' then
    Result := ExecMulti(LSQL);
{$ENDIF}
end;

end.
