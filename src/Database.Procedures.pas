{ =============================================================================
  Database.Procedures - Colecao de STORED PROCEDURES do banco, Connection-bound
  (TProcedures, IProcedures)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.0.0
  FileVersion:    1.1.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           30/07/2026

  Onda R2 (f5-repair, re-layering por responsabilidade) - colecao NOVA de
  nivel IDatabase: PROCEDURES sao objectos de BANCO, nao de tabela (ao
  contrario de campos/indices/constraints, que vivem na ITable dona).
  ADITIVO PURO - paralela as operacoes HOMONIMAS ja existentes em ISchema
  (CreateProcedure/DropProcedure, Database.Schema.pas), que continuam
  intactas (a remocao fica para a Fase C do f5-repair). TProcedures e
  Connection-bound (Connection getter/setter fluente, sem parametro de
  conexao nos metodos Create/Drop - mesmo padrao Connection-bound de
  TSchemas/TDatabases); cacheia DatabaseTypes a partir da Connection
  injectada (mesmo truque de TDatabase.Connection) para que *SQL
  (CreateProcedureSQL/DropProcedureSQL) funcionem sem exigir conexao LIGADA
  (TDialect.ForDatabaseType), enquanto os metodos que EXECUTAM
  (CreateProcedure/DropProcedure) exigem Connection ligada e resolvem o
  dialecto por TDialect.ForConnection (version-aware).

  Delega a TDialect.ForConnection(FConnection).Routine (CreateSQL/DropSQL,
  AIsFunction=False) e a TCatalogReader.New(FConnection) (ProcedureNames/
  ProcedureExists) para as operacoes reais; degrada graciosamente
  (''/0/False/[]) quando USE_DATABASE esta OFF, sem Connection injectada, ou
  conexao desligada - mesmo padrao de robustez de Database.Schema.pas
  (TSchema.CreateProcedure/DropProcedure).

  GOTCHA de uses (Do-Not-Repeat, evita E2004/E2003): ProcedureNames devolve
  TStringArray - Commons.Types fica SO no uses da INTERFACE (nao no da
  implementation, que ja o herda por visibilidade de secao) - mesmo padrao
  de Database.Schemas.pas.

  Changelog (file):
  - 1.1.0 (30/07/2026): bugfix (achado onda S4/serializacao, teste real
    test_serialize.dpr contra PostgreSQL) - CreateRoutine (caminho zero-SQL/
    builder, o que ISchema.ApplyStructure usa) ganha o MESMO guard de
    idempotencia (ProcedureExists) que CreateProcedure(AName,ABody) ja tinha;
    sem isso, repetir ApplyStructure com a MESMA definicao lancava
    EUniError "funcao/procedure ja existe com os mesmos tipos de argumento"
    no PostgreSQL. Ver comentario completo no corpo de CreateRoutine.
  - 1.0.0 (25/07/2026): versao inicial (Onda R2, f5-repair) - colecao NOVA,
    Connection-bound, paralela a ISchema.CreateProcedure/DropProcedure (que
    permanecem intactos por agora).
  ============================================================================= }
unit Database.Procedures;

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
  TProcedures = class(TInterfacedObject, IProcedures)
  private
    FConnection: IConnection;
    FDatabaseTypes: TDatabaseTypes;
  public
    constructor Create;
    class function New: IProcedures;
    function Connection(const AConnection: IConnection): IProcedures; overload;
    function Connection: IConnection; overload;
    function ProcedureNames: TStringArray;
    function ProcedureExists(const AName: string): Boolean;
    function CreateProcedureSQL(const AName, ABody: string): string;
    function DropProcedureSQL(const AName: string; const AIfExists: Boolean = True): string;
    function CreateProcedure(const AName, ABody: string): Integer;
    function DropProcedure(const AName: string): Integer;
    { Onda F1 - lancador zero-SQL a partir do builder de rotinas. A clausula de
      resolucao de metodo mapeia IProcedures.Create -> CreateRoutine para EVITAR
      colisao com o constructor Create desta classe (Delphi + FPC mode delphi). }
    function IProcedures.Create = CreateRoutine;
    function CreateRoutine(const ADef: IRoutineDefinition): Integer;
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

constructor TProcedures.Create;
begin
  inherited Create;
  FDatabaseTypes := dtNone;
end;

class function TProcedures.New: IProcedures;
begin
  Result := TProcedures.Create;
end;

function TProcedures.Connection(const AConnection: IConnection): IProcedures;
begin
  FConnection := AConnection;
  if AConnection <> nil then
    FDatabaseTypes := AConnection.DatabaseType
  else
    FDatabaseTypes := dtNone;
  Result := Self;
end;

function TProcedures.Connection: IConnection;
begin
  Result := FConnection;
end;

function TProcedures.ProcedureNames: Commons.Types.TStringArray;
begin
  SetLength(Result, 0);
{$IFDEF USE_DATABASE}
  if (FConnection = nil) or not FConnection.IsConnected then
    Exit;
  Result := TCatalogReader.New(FConnection).ProcedureNames('');
{$ENDIF}
end;

function TProcedures.ProcedureExists(const AName: string): Boolean;
begin
  Result := False;
{$IFDEF USE_DATABASE}
  if (FConnection = nil) or not FConnection.IsConnected then
    Exit;
  Result := TCatalogReader.New(FConnection).ProcedureExists(Trim(AName), '');
{$ENDIF}
end;

function TProcedures.CreateProcedureSQL(const AName, ABody: string): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (Trim(AName) = '') or (Trim(ABody) = '') or (FDatabaseTypes = dtNone) then
    Exit;
  Result := TDialect.ForDatabaseType(FDatabaseTypes).Routine.CreateSQL(Trim(AName), ABody, False);
{$ENDIF}
end;

function TProcedures.DropProcedureSQL(const AName: string; const AIfExists: Boolean): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (Trim(AName) = '') or (FDatabaseTypes = dtNone) then
    Exit;
  Result := TDialect.ForDatabaseType(FDatabaseTypes).Routine.DropSQL(Trim(AName), False, AIfExists);
{$ENDIF}
end;

function TProcedures.CreateProcedure(const AName, ABody: string): Integer;
{$IFDEF USE_DATABASE}
var
  LSQL: string;
{$ENDIF}
begin
  Result := 0;
{$IFDEF USE_DATABASE}
  if (FConnection = nil) or not FConnection.IsConnected then
    Exit;
  if (Trim(AName) = '') or (Trim(ABody) = '') then
    Exit;
  { idempotente: so cria se ainda nao existir (introspecao; sem SQL de
    procedures o dialecto degrada para "nao existe" e tenta criar) - mesmo
    padrao de TSchema.CreateProcedure. }
  if TCatalogReader.New(FConnection).ProcedureExists(Trim(AName), '') then
    Exit;
  LSQL := TDialect.ForConnection(FConnection).Routine.CreateSQL(Trim(AName), ABody, False);
  if Trim(LSQL) <> '' then
    Result := FConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

function TProcedures.DropProcedure(const AName: string): Integer;
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
    TSchema.DropProcedure. }
  if (Trim(LDialect.ProceduresSQL('')) <> '') and
     (not TCatalogReader.New(FConnection).ProcedureExists(Trim(AName), '')) then
    Exit;
  LSQL := LDialect.Routine.DropSQL(Trim(AName), False, True);
  if Trim(LSQL) <> '' then
    Result := FConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

function TProcedures.CreateRoutine(const ADef: IRoutineDefinition): Integer;
{$IFDEF USE_DATABASE}
var
  LSQL: string;
{$ENDIF}
begin
  { Onda F1 - zero-SQL: o dialecto (version-aware, ForConnection) compoe o
    CREATE PROCEDURE a partir do builder; degrada para no-op/0 quando o motor
    nao suporta procedures (SQLite/Access -> RoutineDefCreateSQL='') ou sem
    conexao ligada. }
  Result := 0;
{$IFDEF USE_DATABASE}
  if (FConnection = nil) or not FConnection.IsConnected then
    Exit;
  if ADef = nil then
    Exit;
  { bug real (achado onda S4/serializacao, teste real contra PostgreSQL):
    faltava aqui o MESMO guard de idempotencia que CreateProcedure(AName,
    ABody), acima, ja tem - ApplyStructure (Database.Schema.pas) chama esta
    rotina repetindo a MESMA definicao para provar idempotencia do merge, e
    sem o guard o PostgreSQL lanca "funcao/procedure ja existe com os mesmos
    tipos de argumento" na 2a chamada (CREATE PROCEDURE, ao contrario de
    CREATE VIEW/TRIGGER/RULE, nao e' CREATE OR REPLACE nesta versao do
    dialecto). So cria se ainda nao existir - mesmo padrao ja usado por
    CreateProcedure/DropProcedure/DropFunction (introspecao via
    ICatalogReader.ProcedureExists). }
  if (Trim(ADef.Name) <> '') and TCatalogReader.New(FConnection).ProcedureExists(Trim(ADef.Name), '') then
    Exit;
  LSQL := TDialect.ForConnection(FConnection).Routine.CreateSQL(ADef);
  if Trim(LSQL) <> '' then
    Result := FConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

end.
