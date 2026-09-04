{ =============================================================================
  Database.Functions - Colecao de FUNCTIONS do banco, Connection-bound
  (TFunctions, IFunctions)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.0.0
  FileVersion:    1.2.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           30/07/2026

  Onda R2 (f5-repair, re-layering por responsabilidade) - colecao NOVA de
  nivel IDatabase: FUNCTIONS (scalar/stored) sao objectos de BANCO, nao de
  tabela. ADITIVO PURO - nao ha equivalente pre-existente em ISchema (que so
  tinha View/Procedure) - esta e a 1a colecao de FUNCTIONS do modulo.
  TFunctions e Connection-bound (Connection getter/setter fluente, sem
  parametro de conexao nos metodos Create/Drop - mesmo padrao Connection-
  bound de TViews/TProcedures, acima); cacheia DatabaseTypes a partir da
  Connection injectada para que *SQL (CreateFunctionSQL/DropFunctionSQL)
  funcionem sem exigir conexao LIGADA (TDialect.ForDatabaseType), enquanto os
  metodos que EXECUTAM (CreateFunction/DropFunction) exigem Connection ligada
  e resolvem o dialecto por TDialect.ForConnection (version-aware).

  Delega a TDialect.ForConnection(FConnection).Routine (CreateSQL/DropSQL,
  AIsFunction=True - mesma faceta IRoutineDialect ja usada por TProcedures,
  so com o flag invertido) para CreateFunction/DropFunction/CreateFunctionSQL/
  DropFunctionSQL - estes 4 metodos ja funcionam plenamente (nao dependem de
  introspeccao de functions, so de DatabaseTypes/Connection).

  FunctionNames/FunctionExists DELEGAM agora a TCatalogReader.New(FConnection)
  (Database.CatalogReader), que passou a expor introspeccao de FUNCTIONS
  (FunctionNames/FunctionExists sobre IDialect.FunctionsSQL - Onda C6, #4,
  plano f5-conformidade), no mesmo padrao ja usado por
  TViews.ViewNames/TProcedures.ProcedureNames. CreateFunction/DropFunction
  passam a ser IDEMPOTENTES via essa introspeccao (mesmo padrao de
  TProcedures.CreateProcedure/DropProcedure). Dialectos sem SQL de functions
  (SQLite/Access/SQL Anywhere) degradam para []/False (nunca lancam).

  GOTCHA de uses (Do-Not-Repeat, evita E2004/E2003): FunctionNames devolve
  TStringArray - Commons.Types fica SO no uses da INTERFACE (nao no da
  implementation, que ja o herda por visibilidade de secao) - mesmo padrao
  de Database.Schemas.pas.

  Changelog (file):
  - 1.2.0 (30/07/2026): bugfix (achado onda S4/serializacao, teste real
    test_serialize.dpr contra PostgreSQL) - CreateRoutine (caminho zero-SQL/
    builder, o que ISchema.ApplyStructure usa) ganha o MESMO guard de
    idempotencia (FunctionExists) que CreateFunction(AName,ABody) ja tinha;
    mesmo bug/fix do irmao TProcedures.CreateRoutine (Database.Procedures.pas
    1.1.0), ver comentario completo no corpo de CreateRoutine.
  - 1.1.0 (27/07/2026): Onda C6 (#4, plano f5-conformidade) - FunctionNames/
    FunctionExists deixam de ser STUB e passam a delegar a
    TCatalogReader.New(FConnection).FunctionNames/FunctionExists (novo
    IDialect.FunctionsSQL nos 7 dialectos); CreateFunction/DropFunction
    passam a ser idempotentes via a mesma introspeccao (paridade com
    TProcedures).
  - 1.0.0 (25/07/2026): versao inicial (Onda R2, f5-repair) - colecao NOVA,
    Connection-bound; FunctionNames/FunctionExists em STUB (sem catalogo de
    functions em ICatalogReader ainda).
  ============================================================================= }
unit Database.Functions;

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
  TFunctions = class(TInterfacedObject, IFunctions)
  private
    FConnection: IConnection;
    FDatabaseTypes: TDatabaseTypes;
  public
    constructor Create;
    class function New: IFunctions;
    function Connection(const AConnection: IConnection): IFunctions; overload;
    function Connection: IConnection; overload;
    function FunctionNames: TStringArray;
    function FunctionExists(const AName: string): Boolean;
    function CreateFunctionSQL(const AName, ABody: string): string;
    function DropFunctionSQL(const AName: string; const AIfExists: Boolean = True): string;
    function CreateFunction(const AName, ABody: string): Integer;
    function DropFunction(const AName: string): Integer;
    { Onda F1 - lancador zero-SQL a partir do builder de rotinas. A clausula de
      resolucao de metodo mapeia IFunctions.Create -> CreateRoutine para EVITAR
      colisao com o constructor Create desta classe (Delphi + FPC mode delphi). }
    function IFunctions.Create = CreateRoutine;
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

constructor TFunctions.Create;
begin
  inherited Create;
  FDatabaseTypes := dtNone;
end;

class function TFunctions.New: IFunctions;
begin
  Result := TFunctions.Create;
end;

function TFunctions.Connection(const AConnection: IConnection): IFunctions;
begin
  FConnection := AConnection;
  if AConnection <> nil then
    FDatabaseTypes := AConnection.DatabaseType
  else
    FDatabaseTypes := dtNone;
  Result := Self;
end;

function TFunctions.Connection: IConnection;
begin
  Result := FConnection;
end;

function TFunctions.FunctionNames: Commons.Types.TStringArray;
begin
  { Onda C6 (#4) - delega ao motor unico TCatalogReader (SSOT do catalogo,
    regra #14), mesmo padrao de TViews.ViewNames/TProcedures.ProcedureNames. }
  SetLength(Result, 0);
{$IFDEF USE_DATABASE}
  if (FConnection = nil) or not FConnection.IsConnected then
    Exit;
  Result := TCatalogReader.New(FConnection).FunctionNames('');
{$ENDIF}
end;

function TFunctions.FunctionExists(const AName: string): Boolean;
begin
  { Onda C6 (#4) - delega ao motor unico TCatalogReader, mesmo padrao de
    TProcedures.ProcedureExists. }
  Result := False;
{$IFDEF USE_DATABASE}
  if (FConnection = nil) or not FConnection.IsConnected then
    Exit;
  Result := TCatalogReader.New(FConnection).FunctionExists(Trim(AName), '');
{$ENDIF}
end;

function TFunctions.CreateFunctionSQL(const AName, ABody: string): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (Trim(AName) = '') or (Trim(ABody) = '') or (FDatabaseTypes = dtNone) then
    Exit;
  Result := TDialect.ForDatabaseType(FDatabaseTypes).Routine.CreateSQL(Trim(AName), ABody, True);
{$ENDIF}
end;

function TFunctions.DropFunctionSQL(const AName: string; const AIfExists: Boolean): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (Trim(AName) = '') or (FDatabaseTypes = dtNone) then
    Exit;
  Result := TDialect.ForDatabaseType(FDatabaseTypes).Routine.DropSQL(Trim(AName), True, AIfExists);
{$ENDIF}
end;

function TFunctions.CreateFunction(const AName, ABody: string): Integer;
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
  { Onda C6 (#4) - idempotente: so cria se ainda nao existir (introspecao
    agora real via TCatalogReader.FunctionNames); sem SQL de functions o
    dialecto degrada para "nao existe" e tenta criar - mesmo padrao de
    TProcedures.CreateProcedure. }
  if TCatalogReader.New(FConnection).FunctionExists(Trim(AName), '') then
    Exit;
  LSQL := TDialect.ForConnection(FConnection).Routine.CreateSQL(Trim(AName), ABody, True);
  if Trim(LSQL) <> '' then
    Result := FConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

function TFunctions.DropFunction(const AName: string): Integer;
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
  { Onda C6 (#4) - idempotente: com introspecao so remove se existir; senao
    confia no IF EXISTS da sintaxe do banco (DropSQL AIfExists=True) - mesmo
    padrao de TProcedures.DropProcedure. }
  if (Trim(LDialect.FunctionsSQL('')) <> '') and
     (not TCatalogReader.New(FConnection).FunctionExists(Trim(AName), '')) then
    Exit;
  LSQL := LDialect.Routine.DropSQL(Trim(AName), True, True);
  if Trim(LSQL) <> '' then
    Result := FConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

function TFunctions.CreateRoutine(const ADef: IRoutineDefinition): Integer;
{$IFDEF USE_DATABASE}
var
  LSQL: string;
{$ENDIF}
begin
  { Onda F1 - zero-SQL: o dialecto (version-aware, ForConnection) compoe o
    CREATE FUNCTION a partir do builder; degrada para no-op/0 quando o motor
    nao suporta functions (SQLite/Access -> RoutineDefCreateSQL='') ou sem
    conexao ligada. }
  Result := 0;
{$IFDEF USE_DATABASE}
  if (FConnection = nil) or not FConnection.IsConnected then
    Exit;
  if ADef = nil then
    Exit;
  { bug real (achado onda S4/serializacao, teste real contra PostgreSQL) -
    mesmo guard de idempotencia que ja falta no irmao TProcedures.
    CreateRoutine (ver comentario completo la): ApplyStructure repete a
    MESMA definicao para provar idempotencia do merge, e sem o guard o
    PostgreSQL lanca "funcao ja existe com os mesmos tipos de argumento" na
    2a chamada. So cria se ainda nao existir - mesmo padrao ja usado por
    CreateFunction/DropFunction/DropProcedure (introspecao via
    ICatalogReader.FunctionExists), so que agora tambem no caminho
    zero-SQL/builder. }
  if (Trim(ADef.Name) <> '') and TCatalogReader.New(FConnection).FunctionExists(Trim(ADef.Name), '') then
    Exit;
  LSQL := TDialect.ForConnection(FConnection).Routine.CreateSQL(ADef);
  if Trim(LSQL) <> '' then
    Result := FConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

end.
