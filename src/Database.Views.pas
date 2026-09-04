{ =============================================================================
  Database.Views - Colecao de VIEWS do banco, Connection-bound (TViews, IViews)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           25/07/2026

  Onda R2 (f5-repair, re-layering por responsabilidade) - colecao NOVA de
  nivel IDatabase: VIEWS sao objectos de BANCO, nao de tabela (ao contrario
  de campos/indices/constraints, que vivem na ITable dona). ADITIVO PURO -
  paralela as operacoes HOMONIMAS ja existentes em ISchema (CreateView/
  DropView, Database.Schema.pas), que continuam intactas (a remocao fica
  para a Fase C do f5-repair). TViews e Connection-bound (Connection getter/
  setter fluente, sem parametro de conexao nos metodos Create/Drop - mesmo
  padrao Connection-bound de TSchemas/TDatabases); cacheia DatabaseTypes a
  partir da Connection injectada (mesmo truque de TDatabase.Connection) para
  que *SQL (CreateViewSQL/DropViewSQL) funcionem sem exigir conexao LIGADA
  (TDialect.ForDatabaseType), enquanto os metodos que EXECUTAM (CreateView/
  DropView) exigem Connection ligada e resolvem o dialecto por
  TDialect.ForConnection (version-aware).

  Delega a TDialect.ForConnection(FConnection).View (CreateSQL/DropSQL) e a
  TCatalogReader.New(FConnection) (ViewNames/ViewExists) para as operacoes reais;
  degrada graciosamente (''/0/False/[]) quando USE_DATABASE esta OFF, sem
  Connection injectada, ou conexao desligada - mesmo padrao de robustez de
  Database.Schema.pas (TSchema.CreateView/DropView).

  GOTCHA de uses (Do-Not-Repeat, evita E2004/E2003): ViewNames devolve
  TStringArray - Commons.Types fica SO no uses da INTERFACE (nao no da
  implementation, que ja o herda por visibilidade de secao) - mesmo padrao
  de Database.Schemas.pas.

  Changelog (file):
  - 1.0.0 (25/07/2026): versao inicial (Onda R2, f5-repair) - colecao NOVA,
    Connection-bound, paralela a ISchema.CreateView/DropView (que
    permanecem intactos por agora).
  ============================================================================= }
unit Database.Views;

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
  TViews = class(TInterfacedObject, IViews)
  private
    FConnection: IConnection;
    FDatabaseTypes: TDatabaseTypes;
  public
    constructor Create;
    class function New: IViews;
    function Connection(const AConnection: IConnection): IViews; overload;
    function Connection: IConnection; overload;
    function ViewNames: TStringArray;
    function ViewExists(const AViewName: string): Boolean;
    function CreateViewSQL(const AViewName, ASelectSQL: string; const AOrReplace: Boolean = True): string;
    function DropViewSQL(const AViewName: string; const AIfExists: Boolean = True): string;
    function CreateView(const AViewName, ASelectSQL: string; const AOrReplace: Boolean = True): Integer; {$IFDEF USE_DATABASE}overload;{$ENDIF}
    {$IFDEF USE_DATABASE}
    function CreateView(const AViewName: string; const ASelect: IQueryBuilder; const AOrReplace: Boolean = True): Integer; overload;
    {$ENDIF}
    function DropView(const AViewName: string): Integer;
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

constructor TViews.Create;
begin
  inherited Create;
  FDatabaseTypes := dtNone;
end;

class function TViews.New: IViews;
begin
  Result := TViews.Create;
end;

function TViews.Connection(const AConnection: IConnection): IViews;
begin
  FConnection := AConnection;
  if AConnection <> nil then
    FDatabaseTypes := AConnection.DatabaseType
  else
    FDatabaseTypes := dtNone;
  Result := Self;
end;

function TViews.Connection: IConnection;
begin
  Result := FConnection;
end;

function TViews.ViewNames: Commons.Types.TStringArray;
begin
  SetLength(Result, 0);
{$IFDEF USE_DATABASE}
  if (FConnection = nil) or not FConnection.IsConnected then
    Exit;
  Result := TCatalogReader.New(FConnection).ViewNames('');
{$ENDIF}
end;

function TViews.ViewExists(const AViewName: string): Boolean;
begin
  Result := False;
{$IFDEF USE_DATABASE}
  if (FConnection = nil) or not FConnection.IsConnected then
    Exit;
  Result := TCatalogReader.New(FConnection).ViewExists(Trim(AViewName), '');
{$ENDIF}
end;

function TViews.CreateViewSQL(const AViewName, ASelectSQL: string; const AOrReplace: Boolean): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (Trim(AViewName) = '') or (Trim(ASelectSQL) = '') or (FDatabaseTypes = dtNone) then
    Exit;
  Result := TDialect.ForDatabaseType(FDatabaseTypes).View.CreateSQL(Trim(AViewName), ASelectSQL, AOrReplace);
{$ENDIF}
end;

function TViews.DropViewSQL(const AViewName: string; const AIfExists: Boolean): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (Trim(AViewName) = '') or (FDatabaseTypes = dtNone) then
    Exit;
  Result := TDialect.ForDatabaseType(FDatabaseTypes).View.DropSQL(Trim(AViewName), AIfExists);
{$ENDIF}
end;

function TViews.CreateView(const AViewName, ASelectSQL: string; const AOrReplace: Boolean): Integer;
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
  if (Trim(AViewName) = '') or (Trim(ASelectSQL) = '') then
    Exit;
  LDialect := TDialect.ForConnection(FConnection);
  { idempotente: sem OR REPLACE so cria se a view ainda nao existir (quando ha
    introspecao; ViewsSQL vazio degrada para "nao existe" e tenta criar). Com
    AOrReplace a propria sintaxe do banco re-emite (mesmo padrao de
    TSchema.CreateView). }
  if (not AOrReplace) and (Trim(LDialect.ViewsSQL('')) <> '') and
     TCatalogReader.New(FConnection).ViewExists(Trim(AViewName), '') then
    Exit;
  LSQL := LDialect.View.CreateSQL(Trim(AViewName), ASelectSQL, AOrReplace);
  if Trim(LSQL) <> '' then
    Result := FConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

{$IFDEF USE_DATABASE}
{ overload zero-SQL: extrai o SELECT do IQueryBuilder (ToSQL) e delega ao overload
  de string. O chamador nao escreve SQL. }
function TViews.CreateView(const AViewName: string; const ASelect: IQueryBuilder; const AOrReplace: Boolean): Integer;
begin
  Result := 0;
  if ASelect = nil then
    Exit;
  Result := CreateView(AViewName, ASelect.ToSQL, AOrReplace);
end;
{$ENDIF}

function TViews.DropView(const AViewName: string): Integer;
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
  if Trim(AViewName) = '' then
    Exit;
  LDialect := TDialect.ForConnection(FConnection);
  { idempotente: com introspecao so remove se existir; sem introspecao confia
    no IF EXISTS da sintaxe do banco (DropSQL AIfExists=True) - mesmo padrao
    de TSchema.DropView. }
  if (Trim(LDialect.ViewsSQL('')) <> '') and
     (not TCatalogReader.New(FConnection).ViewExists(Trim(AViewName), '')) then
    Exit;
  LSQL := LDialect.View.DropSQL(Trim(AViewName), True);
  if Trim(LSQL) <> '' then
    Result := FConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

end.
