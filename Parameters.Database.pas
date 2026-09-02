{ =============================================================================
  Parameters.Database - fonte Database do modulo Parameters (TParametersDatabase)

  Implementa IParametersDatabase (Parameters.Interfaces) reusando Connections(F4)
  + Database(F5): CRUD via IQueryBuilder/ITable/EntityManager, DDL via
  ISynchronize/ISchemaDefinition (AddUnique multi-coluna) - ZERO SQL manual, ZERO
  IFDEF de engine. Conexao INDEPENDENTE (bootstrap file->SQLite) ou injetada
  (Connection(IConnection) tipada). A god-class v1.0.7 (~7.400 linhas, ~200
  diretivas condicionais de engine) NAO transita - esta unit e reescrita limpa
  por referencia.

  FASE 7, Onda 7.2 (Fonte Database) - COMPLETA. Tudo IMPLEMENTADO (reuso
  IQueryBuilder/ISynchronize, zero SQL manual, zero IFDEF de engine): CRUD
  (Select/Insert/Update/Save/Delete/Exists/Count), DDL (EnsureTable/TableExists/
  DropTable), bootstrap da conexao propria (cascata config.db/ini/json -> SQLite
  zero-config), escopo (contrato/produto/titulo), Connection tipada/ownership,
  ToJSON e ImportFrom/ExportTo. Validado: smoke_parameters_db 41/41 (4 alvos) +
  suite compat S1 52/52.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  2.0.0
  FileVersion:    1.3.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           16/07/2026

  Changelog (file):
  - 1.3.0 (21/07/2026): 3 achados da revisao F7 (owner). (A) THREAD-SAFETY: Save
    (upsert Exists+Insert/Update) e EnsureConnection (lazy-init da conexao +
    auto-create de tabela) passam a tomar o FLock (TCriticalSection recursivo) -
    antes so FromConfig sincronizava; os CRUD individuais nao precisam (1 statement,
    o banco serializa). (C) REORDER on-insert/on-update por POSICAO: novos
    ReorderShift (desliza a ordem no grupo) + CurrentOrderOf, integrados no Insert/
    Update sob DEFAULT_PARAMETER_AUTO_REORDER_ON_INSERT/UPDATE - ZERO SQL manual
    (usa o novo IQueryBuilder.SetValueDelta da F5: SET col = col +/- N dialect-aware,
    ambos os lados quotados). Validado smoke +4 casos em Zeos(dcc32/fpc32)/FireDAC/
    SQLdb + suite S1 52/52 (fpc32/64). (B AutoCreateFile = nas fontes INI/JSON.)
  - 1.2.0 (21/07/2026): ToJSON + ImportFrom/ExportTo IMPLEMENTADOS (eram os
    ultimos 3 stubs "NotImplemented" da fonte). Mesma semantica de
    TParametersSourceBase: ToJSON itera Select->TJSONObject; ImportFrom/ExportTo
    fazem upsert (Save) uniforme entre quaisquer IParametersSource. Helper privado
    NotImplemented removido (orfao). Comentarios de cabecalho/seccao atualizados -
    o texto "Onda 7.2.a esqueleto / CRUD stubs" estava desatualizado (o CRUD/DDL
    ficaram REAIS apos as sub-ondas 7.2.b..f). Validado smoke 41/41 + S1 52/52.
  - 1.1.0 (17/07/2026): Onda 10-D (cross-DB) - Insert/Update passam a gravar o
    campo 'ativo' como Boolean NATURAL (AParameter.Ativo), em vez de Ord(...):
    o QueryBuilder.Bind + IDialect.EncodeBoolean homogeneizam a representacao por
    banco (fecha o write de boolean no PostgreSQL). Simetrico ao READ FieldAsBool
    (bug-569).
  - 1.0.0 (16/07/2026): criacao - esqueleto da fonte Database (Onda 7.2.a):
    config fluente + escopo + Connection tipada/ownership + ciclo de vida;
    CRUD/DDL/bootstrap como stubs ate as sub-ondas 7.2.b..f.
  ============================================================================= }

unit Parameters.Database;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../../ORM.Defines.inc}

{$IFDEF USE_PARAMETERS}

uses
{$IF DEFINED(FPC)}
  SysUtils, Classes, SyncObjs, fpjson,
{$ELSE}
  System.SysUtils, System.Classes, System.SyncObjs, System.JSON,
{$ENDIF}
  Commons.Types,           // TParameter, TParameterList, TParameterSource, TDatabaseEngine, TDatabaseTypes, TFirebirdVersion
  Connections.Interfaces,  // IConnection (DI tipada da conexao)
  Exceptions.Parameters,   // EParameters* + codigos ERR_PARAMETER_*
  Parameters.Interfaces;   // IParametersDatabase / IParametersSource

type
  { ---------------------------------------------------------------------------
    TParametersDatabase - fonte Database (implementa IParametersDatabase)

    Fonte Database COMPLETA: config/escopo/connection/ownership + CRUD + DDL +
    bootstrap + ToJSON/Import/Export, todos reais (reuso Database/Connections).
    --------------------------------------------------------------------------- }
  TParametersDatabase = class(TInterfacedObject, IParametersSource, IParametersDatabase)
  strict private
    FLock            : TCriticalSection;
    FConnection      : IConnection;
    FOwnConnection   : Boolean;
    { config da tabela }
    FTableName       : string;
    FSchema          : string;
    FAutoCreateTable : Boolean;
    { escopo (3 filtros paralelos) }
    FContratoID      : Integer;
    FProdutoID       : Integer;
    FTitle           : string;
    { config de conexao propria (bootstrap file->SQLite) }
    FEngine          : TDatabaseEngine;
    FDatabaseType    : TDatabaseTypes;
    FHost            : string;
    FPort            : Integer;
    FUsername        : string;
    FPassword        : string;
    FDatabase        : string;
    FDllBasePath     : string;
    FFirebirdVersion : TFirebirdVersion;
    { Onda 7.6 (revisita 7.2) - guarda p/ auto-create da tabela disparar uma unica vez. }
    FTableEnsured    : Boolean;

    { Onda 7.2.b - bootstrap da conexao propria (cascata config.db/ini/json -> SQLite zero-config). }
    function NewOwnSQLite(const ADbPath: string): IConnection;
    function ResolveConfigBasePath(const APath: string): string;
    { Onda 7.6 (revisita 7.2) - conexao propria a partir dos setters fluentes (config explicita). }
    function BuildOwnConnection: IConnection;
    { Onda 7.6 (revisita 7.2) - DDL da tabela (assume conexao aberta); reusada por EnsureTable + auto-create. }
    procedure DoEnsureTable;
    { Onda 7.2.c - garante FConnection existente e conectada (bootstrap lazy). }
    procedure EnsureConnection;
{$IFDEF USE_DATABASE}
    { Onda 7.2.f - proxima ordem (MAX(ordem)+1) no grupo (contrato/produto/titulo). }
    function GetNextOrder(const ATitulo: string): Integer;
    { Onda 7.2.f (reorder por posicao) - ordem ATUAL de uma chave no grupo (0 se ausente). }
    function CurrentOrderOf(const AName, ATitulo: string): Integer;
    { Onda 7.2.f (reorder por posicao) - shift `ordem += ADelta` das linhas do grupo
      (contrato/produto/titulo) com ordem em [AFrom, ATo]; ATo<0 = sem limite superior.
      UMA statement UPDATE de EXPRESSAO (o QueryBuilder bindado nao faz col=col+/-1). }
    procedure ReorderShift(const ATitulo: string;
      AContrato, AProduto, AFrom, ATo, ADelta: Integer);
{$ENDIF}
  public
    constructor Create;
    destructor Destroy; override;

    { ---- IParametersSource: identificacao / escopo ---- }
    function Source: TParameterSource;
    function ContratoID(const AValue: Integer): IParametersSource; overload;
    function ContratoID: Integer; overload;
    function ProdutoID(const AValue: Integer): IParametersSource; overload;
    function ProdutoID: Integer; overload;
    function Title(const AValue: string): IParametersSource; overload;
    function Title: string; overload;

    { ---- IParametersSource: CRUD ---- }
    function Select(const AName: string): TParameter; overload;
    function Select(const AName: string; out AParameter: TParameter): IParametersSource; overload;
    function Select: TParameterList; overload;
    function Select(out AList: TParameterList): IParametersSource; overload;
    function Insert(const AParameter: TParameter): IParametersSource; overload;
    function Insert(const AParameter: TParameter; out ASuccess: Boolean): IParametersSource; overload;
    function Update(const AParameter: TParameter): IParametersSource; overload;
    function Update(const AParameter: TParameter; out ASuccess: Boolean): IParametersSource; overload;
    function Save(const AParameter: TParameter): IParametersSource; overload;
    function Save(const AParameter: TParameter; out ASuccess: Boolean): IParametersSource; overload;
    function Delete(const AName: string): IParametersSource; overload;
    function Delete(const AName: string; out ASuccess: Boolean): IParametersSource; overload;
    function Exists(const AName: string): Boolean; overload;
    function Exists(const AName: string; out AExists: Boolean): IParametersSource; overload;
    function Count: Integer; overload;
    function Count(out ACount: Integer): IParametersSource; overload;
    function Refresh: IParametersSource;
    function ToJSON: TJSONObject;
    function ImportFrom(const ASource: IParametersSource): IParametersSource; overload;
    function ImportFrom(const ASource: IParametersSource; out ASuccess: Boolean): IParametersSource; overload;
    function ExportTo(const ASource: IParametersSource): IParametersSource; overload;
    function ExportTo(const ASource: IParametersSource; out ASuccess: Boolean): IParametersSource; overload;

    { ---- IParametersDatabase: config da tabela ---- }
    function TableName(const AValue: string): IParametersDatabase; overload;
    function TableName: string; overload;
    function Schema(const AValue: string): IParametersDatabase; overload;
    function Schema: string; overload;
    function AutoCreateTable(const AValue: Boolean): IParametersDatabase; overload;
    function AutoCreateTable: Boolean; overload;

    { ---- IParametersDatabase: conexao DI tipada + ownership ---- }
    function Connection(const AConnection: IConnection): IParametersDatabase; overload;
    function Connection: IConnection; overload;

    { ---- IParametersDatabase: config de conexao propria ---- }
    function Engine(const AValue: TDatabaseEngine): IParametersDatabase; overload;
    function Engine: TDatabaseEngine; overload;
    function DatabaseType(const AValue: TDatabaseTypes): IParametersDatabase; overload;
    function DatabaseType: TDatabaseTypes; overload;
    function Host(const AValue: string): IParametersDatabase; overload;
    function Host: string; overload;
    function Port(const AValue: Integer): IParametersDatabase; overload;
    function Port: Integer; overload;
    function Username(const AValue: string): IParametersDatabase; overload;
    function Username: string; overload;
    function Password(const AValue: string): IParametersDatabase; overload;
    function Password: string; overload;
    function Database(const AValue: string): IParametersDatabase; overload;
    function Database: string; overload;
    function DllBasePath(const AValue: string): IParametersDatabase; overload;
    function DllBasePath: string; overload;
    function FirebirdVersion(const AValue: TFirebirdVersion): IParametersDatabase; overload;
    function FirebirdVersion: TFirebirdVersion; overload;

    { ---- IParametersDatabase: bootstrap + ciclo de vida + DDL ---- }
    function FromConfig: IParametersDatabase; overload;
    function FromConfig(const APath: string): IParametersDatabase; overload;
    function Connect: IParametersDatabase; overload;
    function Disconnect: IParametersDatabase;
    function IsConnected: Boolean;
    function EnsureTable: IParametersDatabase;
    function TableExists: Boolean;

{$IFDEF USE_DEPRECATED}
    { ---- Compat v1.0.7 (deprecated; delega ao CRUD/DDL v3) ---- }
    function Getter(const AName: string): TParameter; overload;
    function Getter(const AName: string; out AParameter: TParameter): IParametersSource; overload;
    function List: TParameterList; overload;
    function List(out AList: TParameterList): IParametersSource; overload;
    function Setter(const AParameter: TParameter): IParametersSource; overload;
    function Setter(const AParameter: TParameter; out ASuccess: Boolean): IParametersSource; overload;
    function CreateTable: IParametersDatabase;
    function Connect(out ASuccess: Boolean): IParametersDatabase; overload;
    function DropTable: IParametersDatabase; overload;
    function DropTable(out ASuccess: Boolean): IParametersDatabase; overload;
    function MigrateTable: IParametersDatabase; overload;
    function MigrateTable(out ASuccess: Boolean): IParametersDatabase; overload;
    function ListAvailableDatabases: TStringArray; overload;
    function ListAvailableDatabases(out AList: TStringArray): IParametersDatabase; overload;
    function ListAvailableTables: TStringArray; overload;
    function ListAvailableTables(out AList: TStringArray): IParametersDatabase; overload;
{$ENDIF}
  end;

{$ENDIF USE_PARAMETERS}

implementation

{$IFDEF USE_PARAMETERS}

uses
  Connections,      // TConnection.New (factory da conexao propria - F4)
  Commons.Consts,   // DEFAULT_DATABASE_PATH / DEFAULT_SQLITE_NAME / DEFAULT_SECTION_PARAMETER_NAME / DEFAULT_CONFIG_*
  Commons.Parameters.Consts   // DEFAULT_PARAMETER_AUTO_RENUMBER_ZERO_ORDER (reorder)
{$IFDEF USE_DATABASE}
  , Commons.Database.Types   // TSQLColumnKind (ck*)
  , Databases.Interfaces     // ISchemaDefinition / ISynchronize / ISchemaInspector / IQueryBuilder (contratos F5)
  , Database.Synchronize     // TSchemaDefinition.New / TSynchronize.New (F5 - DDL idempotente)
  , Database.Tables          // TTables.New (F5-FU.2 - ITables.TableExists; COLECCAO lista/descobre)
  , Database.Schema          // TSchema.New (F5 - DropTable idempotente, compat v2.3.0)
  , Database.QueryBuilder    // TQueryBuilder.New (F5 - CRUD bindado + SetValueDelta p/ reorder)
  {$IFDEF FPC}
  , DB                       // TDataSet (leitura do resultado)
  {$ELSE}
  , Data.DB
  {$ENDIF}
{$ENDIF}
  ;

{ helpers JSON cross-compiler locais (ToJSON hierarquico - paridade v2.3.0; sempre
  presentes, ToJSON e de IParametersSource independente de USE_DATABASE). }
{$IF DEFINED(FPC)}
procedure PJAddStr(const AObj: TJSONObject; const AKey, AValue: string); begin AObj.Add(AKey, AValue); end;
procedure PJAddInt(const AObj: TJSONObject; const AKey: string; const AValue: Integer); begin AObj.Add(AKey, AValue); end;
procedure PJAddBool(const AObj: TJSONObject; const AKey: string; const AValue: Boolean); begin AObj.Add(AKey, AValue); end;
procedure PJAddObj(const AObj: TJSONObject; const AKey: string; const AValue: TJSONObject); begin AObj.Add(AKey, AValue); end;
function PJGetObj(const AObj: TJSONObject; const AKey: string): TJSONObject;
var LD: TJSONData;
begin LD := AObj.Find(AKey); if (LD <> nil) and (LD.JSONType = jtObject) then Result := TJSONObject(LD) else Result := nil; end;
{$ELSE}
procedure PJAddStr(const AObj: TJSONObject; const AKey, AValue: string); begin AObj.AddPair(AKey, AValue); end;
procedure PJAddInt(const AObj: TJSONObject; const AKey: string; const AValue: Integer); begin AObj.AddPair(AKey, TJSONNumber.Create(AValue)); end;
procedure PJAddBool(const AObj: TJSONObject; const AKey: string; const AValue: Boolean); begin AObj.AddPair(AKey, TJSONBool.Create(AValue)); end;
procedure PJAddObj(const AObj: TJSONObject; const AKey: string; const AValue: TJSONObject); begin AObj.AddPair(AKey, AValue); end;
function PJGetObj(const AObj: TJSONObject; const AKey: string): TJSONObject;
var LV: TJSONValue;
begin LV := AObj.GetValue(AKey); if LV is TJSONObject then Result := TJSONObject(LV) else Result := nil; end;
{$ENDIF}

{$IFDEF USE_DATABASE}
{ Funcoes de unit (Onda 7.2.d) - visiveis so na implementation (nao expoem
  IQueryBuilder/TDataSet no contrato da classe). }

{ Le um campo booleano de forma cross-engine: o mesmo ckBoolean vira INTEGER no
  SQLite/MySQL mas BIT->campo ftBoolean no SQL Anywhere/PostgreSQL/SQL Server -
  ler AsInteger num campo Boolean lanca "Cannot access field as Integer". }
function FieldAsBool(const AField: TField): Boolean;
begin
  if AField.IsNull then
    Result := False
  else if AField.DataType = ftBoolean then
    Result := AField.AsBoolean
  else
    Result := AField.AsInteger <> 0;
end;

{ Leitura defensiva de TIMESTAMP (data_cadastro/data_alteracao = metadata de
  AUDITORIA). UniDAC+FPC pode mapear o TIMESTAMP como string numerica (dia
  Juliano) e AField.AsDateTime faz StrToFloat sob o DecimalSeparator do locale
  (',' em pt-BR) -> EConvertError, rebentando a leitura INTEIRA do perfil/config.
  Como e' apenas auditoria (nao critico para a config funcionar), degrada para 0
  em vez de propagar a excecao. Delphi (locale '.') e demais engines nao entram
  no except. }
function FieldAsDateTimeSafe(const AField: TField): TDateTime;
begin
  Result := 0;
  if AField = nil then
    Exit;
  try
    if not AField.IsNull then
      Result := AField.AsDateTime;
  except
    Result := 0;
  end;
end;

function RowToParameter(const ADataSet: TDataSet): TParameter;
begin
  Result := TParameter.Create;
  Result.ID          := ADataSet.FieldByName('config_id').AsInteger;
  Result.ContratoID  := ADataSet.FieldByName('contrato_id').AsInteger;
  Result.ProdutoID   := ADataSet.FieldByName('produto_id').AsInteger;
  Result.Ordem       := ADataSet.FieldByName('ordem').AsInteger;
  Result.Titulo      := ADataSet.FieldByName('titulo').AsString;
  Result.Name        := ADataSet.FieldByName('chave').AsString;
  Result.Value       := ADataSet.FieldByName('valor').AsString;
  Result.Description  := ADataSet.FieldByName('descricao').AsString;
  Result.Ativo       := FieldAsBool(ADataSet.FieldByName('ativo'));
  Result.CreatedAt   := FieldAsDateTimeSafe(ADataSet.FieldByName('data_cadastro'));
  Result.UpdatedAt   := FieldAsDateTimeSafe(ADataSet.FieldByName('data_alteracao'));
  Result.ValueType   := pvtString;   { a tabela nao guarda o tipo -> default (7.2.e refina). }
end;

{ SELECT bindado com escopo (contrato/produto sempre; titulo se setado; chave para Select-um). }
function BuildScopedQuery(const AConn: IConnection; const ATable, ASchema: string;
  const AContrato, AProduto: Integer; const ATitulo, AChave: string): IQueryBuilder;
begin
  Result := TQueryBuilder.New.Connection(AConn)
    .Select('*').From(ATable, ASchema)
    .Where('contrato_id', '=', AContrato)
    .Where('produto_id', '=', AProduto);
  if ATitulo <> '' then
    Result.Where('titulo', '=', ATitulo);
  if AChave <> '' then
    Result.Where('chave', '=', AChave)
  else
    Result.OrderBy('ordem');
end;
{$ENDIF}

{ TParametersDatabase }

constructor TParametersDatabase.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FConnection := nil;
  FOwnConnection := False;
  { defaults (Q16: tabela default 'parameters'; DEFAULT_CONTRATO_ID/PRODUTO_ID = 1) }
  FTableName := 'parameters';
  FSchema := '';
  FAutoCreateTable := False;
  FContratoID := 1;
  FProdutoID := 1;
  FTitle := '';
  FEngine := teNone;
  FDatabaseType := dtNone;
  FHost := '';
  FPort := 0;
  FUsername := '';
  FPassword := '';
  FDatabase := '';
  FDllBasePath := '';
  FFirebirdVersion := fb50;
  FTableEnsured := False;
end;

destructor TParametersDatabase.Destroy;
begin
  { ownership: so liberta a conexao se foi criada por este modulo (bootstrap). }
  if FOwnConnection then
    FConnection := nil;
  FLock.Free;
  inherited Destroy;
end;

{ ---- identificacao / escopo ---- }

function TParametersDatabase.Source: TParameterSource;
begin
  Result := psDatabase;
end;

function TParametersDatabase.ContratoID(const AValue: Integer): IParametersSource;
begin
  FContratoID := AValue;
  Result := Self;
end;

function TParametersDatabase.ContratoID: Integer;
begin
  Result := FContratoID;
end;

function TParametersDatabase.ProdutoID(const AValue: Integer): IParametersSource;
begin
  FProdutoID := AValue;
  Result := Self;
end;

function TParametersDatabase.ProdutoID: Integer;
begin
  Result := FProdutoID;
end;

function TParametersDatabase.Title(const AValue: string): IParametersSource;
begin
  FTitle := AValue;
  Result := Self;
end;

function TParametersDatabase.Title: string;
begin
  Result := FTitle;
end;

{ ---- CRUD (Select/Insert/Update/Save/Delete/Exists/Count) ---- }

function TParametersDatabase.Select(const AName: string): TParameter;
{$IFDEF USE_DATABASE}
var
  LDs: TDataSet;
{$ENDIF}
begin
{$IFDEF USE_DATABASE}
  EnsureConnection;
  LDs := BuildScopedQuery(FConnection, FTableName, FSchema,
    FContratoID, FProdutoID, FTitle, AName).Execute;
  try
    if LDs.EOF then
      Result := nil                 { nao encontrado -> nil. }
    else
      Result := RowToParameter(LDs);
  finally
    LDs.Free;                       { o Execute devolve um dataset desconectado (caller liberta). }
  end;
{$ELSE}
  raise EParametersConfigurationException.Create(
    'Parameters.Database.Select requer o modulo Database (USE_DATABASE).', 0, 'Select');
{$ENDIF}
end;

function TParametersDatabase.Select(const AName: string; out AParameter: TParameter): IParametersSource;
begin
  AParameter := Select(AName);
  Result := Self;
end;

function TParametersDatabase.Select: TParameterList;
{$IFDEF USE_DATABASE}
var
  LDs: TDataSet;
{$ENDIF}
begin
{$IFDEF USE_DATABASE}
  EnsureConnection;
  Result := TParameterList.Create;
  LDs := BuildScopedQuery(FConnection, FTableName, FSchema,
    FContratoID, FProdutoID, FTitle, '').Execute;
  try
    while not LDs.EOF do
    begin
      Result.Add(RowToParameter(LDs));
      LDs.Next;
    end;
  finally
    LDs.Free;
  end;
{$ELSE}
  raise EParametersConfigurationException.Create(
    'Parameters.Database.Select requer o modulo Database (USE_DATABASE).', 0, 'Select');
{$ENDIF}
end;

function TParametersDatabase.Select(out AList: TParameterList): IParametersSource;
begin
  AList := Select;
  Result := Self;
end;

function TParametersDatabase.Insert(const AParameter: TParameter): IParametersSource;
{$IFDEF USE_DATABASE}
var
  LNow: TDateTime;
  LTitulo: string;
  LOrdem: Integer;
  LContrato, LProduto: Integer;
{$ENDIF}
begin
{$IFDEF USE_DATABASE}
  EnsureConnection;
  LNow := Now;
  if FTitle <> '' then LTitulo := FTitle else LTitulo := AParameter.Titulo;
  { escopo do registo: o proprio TParameter carrega a sua identidade (contrato/
    produto); quando nao a especifica (<=0), herda o escopo da fonte (7.6). }
  LContrato := FContratoID;
  if AParameter.ContratoID > 0 then LContrato := AParameter.ContratoID;
  LProduto := FProdutoID;
  if AParameter.ProdutoID > 0 then LProduto := AParameter.ProdutoID;
  { reorder (7.2.f): ordem<=0 -> append (MAX+1, renumber-zero); ordem>0 explicita
    com auto-reorder-on-insert -> abre espaco em LOrdem (shift +1 das linhas cujo
    ordem >= LOrdem no grupo), para o novo entrar na posicao pedida sem colidir. }
  LOrdem := AParameter.Ordem;
  if (LOrdem <= 0) and DEFAULT_PARAMETER_AUTO_RENUMBER_ZERO_ORDER then
    LOrdem := GetNextOrder(LTitulo)
  else if (LOrdem > 0) and DEFAULT_PARAMETER_AUTO_REORDER_ON_INSERT then
    ReorderShift(LTitulo, LContrato, LProduto, LOrdem, -1, 1);
  TQueryBuilder.New.Connection(FConnection)
    .InsertInto(FTableName, FSchema)
    .Value('contrato_id',    LContrato)
    .Value('produto_id',     LProduto)
    .Value('ordem',          LOrdem)
    .Value('titulo',         LTitulo)
    .Value('chave',          AParameter.Name)
    .Value('valor',          AParameter.Value)
    .Value('descricao',      AParameter.Description)
    .Value('ativo',          AParameter.Ativo)
    .Value('data_cadastro',  LNow)
    .Value('data_alteracao', LNow)
    .ExecuteMutation;
  Result := Self;
{$ELSE}
  raise EParametersConfigurationException.Create(
    'Parameters.Database.Insert requer o modulo Database (USE_DATABASE).', 0, 'Insert');
{$ENDIF}
end;

function TParametersDatabase.Insert(const AParameter: TParameter; out ASuccess: Boolean): IParametersSource;
begin
  ASuccess := False;
  try
    Insert(AParameter);
    ASuccess := True;
  except
    ASuccess := False;
  end;
  Result := Self;
end;

function TParametersDatabase.Update(const AParameter: TParameter): IParametersSource;
{$IFDEF USE_DATABASE}
var
  LQB: IQueryBuilder;
  LTitulo: string;
  LOldOrder: Integer;
{$ENDIF}
begin
{$IFDEF USE_DATABASE}
  EnsureConnection;
  if FTitle <> '' then LTitulo := FTitle else LTitulo := AParameter.Titulo;
  { reorder-on-update (7.2.f): se a chave e movida para uma nova ordem>0, desliza as
    linhas intermedias para manter a sequencia densa (sem buracos/duplicados finais).
    new>old -> as (old,new] descem 1; new<old -> as [new,old) sobem 1. A ordem nao tem
    constraint UNIQUE, logo a colisao transitoria antes do UPDATE do proprio e inocua. }
  if DEFAULT_PARAMETER_AUTO_REORDER_ON_UPDATE and (AParameter.Ordem > 0) then
  begin
    LOldOrder := CurrentOrderOf(AParameter.Name, LTitulo);
    if (LOldOrder > 0) and (LOldOrder <> AParameter.Ordem) then
    begin
      if AParameter.Ordem > LOldOrder then
        ReorderShift(LTitulo, FContratoID, FProdutoID, LOldOrder + 1, AParameter.Ordem, -1)
      else
        ReorderShift(LTitulo, FContratoID, FProdutoID, AParameter.Ordem, LOldOrder - 1, 1);
    end;
  end;
  LQB := TQueryBuilder.New.Connection(FConnection)
    .Update(FTableName, FSchema)
    .SetValue('valor',          AParameter.Value)
    .SetValue('descricao',      AParameter.Description)
    .SetValue('ordem',          AParameter.Ordem)
    .SetValue('ativo',          AParameter.Ativo)
    .SetValue('data_alteracao', Now)
    .Where('contrato_id', '=', FContratoID)
    .Where('produto_id',  '=', FProdutoID)
    .Where('chave',       '=', AParameter.Name);
  if LTitulo <> '' then
    LQB.Where('titulo', '=', LTitulo);
  LQB.ExecuteMutation;
  Result := Self;
{$ELSE}
  raise EParametersConfigurationException.Create(
    'Parameters.Database.Update requer o modulo Database (USE_DATABASE).', 0, 'Update');
{$ENDIF}
end;

function TParametersDatabase.Update(const AParameter: TParameter; out ASuccess: Boolean): IParametersSource;
begin
  ASuccess := False;
  try
    Update(AParameter);
    ASuccess := True;
  except
    ASuccess := False;
  end;
  Result := Self;
end;

function TParametersDatabase.Save(const AParameter: TParameter): IParametersSource;
begin
{$IFDEF USE_DATABASE}
  { upsert: verificacao aplicacional da ChaveUnica (ex-Setter do v1). O FLock
    torna Exists+Insert/Update ATOMICO - sem ele, dois Save concorrentes da mesma
    chave fariam ambos Insert (duplicado / violacao de ChaveUnica). O TCriticalSection
    e recursivo, logo as chamadas aninhadas (Exists/Insert/Update/EnsureConnection,
    que tambem tomam o lock) reentram sem deadlock. }
  FLock.Acquire;
  try
    if Exists(AParameter.Name) then
      Update(AParameter)
    else
      Insert(AParameter);
  finally
    FLock.Release;
  end;
  Result := Self;
{$ELSE}
  raise EParametersConfigurationException.Create(
    'Parameters.Database.Save requer o modulo Database (USE_DATABASE).', 0, 'Save');
{$ENDIF}
end;

function TParametersDatabase.Save(const AParameter: TParameter; out ASuccess: Boolean): IParametersSource;
begin
  ASuccess := False;
  try
    Save(AParameter);
    ASuccess := True;
  except
    ASuccess := False;
  end;
  Result := Self;
end;

function TParametersDatabase.Delete(const AName: string): IParametersSource;
{$IFDEF USE_DATABASE}
var
  LQB: IQueryBuilder;
{$ENDIF}
begin
{$IFDEF USE_DATABASE}
  EnsureConnection;
  LQB := TQueryBuilder.New.Connection(FConnection)
    .DeleteFrom(FTableName, FSchema)
    .Where('contrato_id', '=', FContratoID)
    .Where('produto_id',  '=', FProdutoID)
    .Where('chave',       '=', AName);
  if FTitle <> '' then
    LQB.Where('titulo', '=', FTitle);
  LQB.ExecuteMutation;
  Result := Self;
{$ELSE}
  raise EParametersConfigurationException.Create(
    'Parameters.Database.Delete requer o modulo Database (USE_DATABASE).', 0, 'Delete');
{$ENDIF}
end;

function TParametersDatabase.Delete(const AName: string; out ASuccess: Boolean): IParametersSource;
begin
  ASuccess := False;
  try
    Delete(AName);
    ASuccess := True;
  except
    ASuccess := False;
  end;
  Result := Self;
end;

function TParametersDatabase.Exists(const AName: string): Boolean;
{$IFDEF USE_DATABASE}
var
  LDs: TDataSet;
{$ENDIF}
begin
{$IFDEF USE_DATABASE}
  EnsureConnection;
  LDs := BuildScopedQuery(FConnection, FTableName, FSchema,
    FContratoID, FProdutoID, FTitle, AName).Execute;
  try
    Result := not LDs.EOF;
  finally
    LDs.Free;
  end;
{$ELSE}
  raise EParametersConfigurationException.Create(
    'Parameters.Database.Exists requer o modulo Database (USE_DATABASE).', 0, 'Exists');
{$ENDIF}
end;

function TParametersDatabase.Exists(const AName: string; out AExists: Boolean): IParametersSource;
begin
  AExists := Exists(AName);
  Result := Self;
end;

function TParametersDatabase.Count: Integer;
{$IFDEF USE_DATABASE}
var
  LDs: TDataSet;
  LQB: IQueryBuilder;
{$ENDIF}
begin
{$IFDEF USE_DATABASE}
  EnsureConnection;
  { COUNT(*) agregado no servidor - O(1) de transferencia (nao materializa as linhas). }
  LQB := TQueryBuilder.New.Connection(FConnection)
    .Count('*', 'CNT').From(FTableName, FSchema)
    .Where('contrato_id', '=', FContratoID)
    .Where('produto_id',  '=', FProdutoID);
  if FTitle <> '' then
    LQB.Where('titulo', '=', FTitle);
  LDs := LQB.Execute;
  try
    if LDs.EOF then Result := 0 else Result := LDs.Fields[0].AsInteger;
  finally
    LDs.Free;
  end;
{$ELSE}
  raise EParametersConfigurationException.Create(
    'Parameters.Database.Count requer o modulo Database (USE_DATABASE).', 0, 'Count');
{$ENDIF}
end;

function TParametersDatabase.Count(out ACount: Integer): IParametersSource;
begin
  ACount := Count;
  Result := Self;
end;

function TParametersDatabase.Refresh: IParametersSource;
begin
  { Onda 7.2.a: sem cache -> no-op fluente. }
  Result := Self;
end;

function TParametersDatabase.ToJSON: TJSONObject;
var
  LList: TParameterList;
  I: Integer;
  LCont, LTit, LKey: TJSONObject;
begin
  { formato HIERARQUICO (paridade v2.3.0, igual ao TParametersSourceBase.ToJSON):
    raiz -> "Contrato" (Contrato_ID/Produto_ID) + um objeto por Titulo -> um objeto
    por chave com valor/descricao/ativo/ordem. }
  Result := TJSONObject.Create;
  LCont := TJSONObject.Create;
  PJAddInt(LCont, 'Contrato_ID', FContratoID);
  PJAddInt(LCont, 'Produto_ID', FProdutoID);
  PJAddObj(Result, 'Contrato', LCont);
  LList := Select;   { ja filtrado por escopo + copias. }
  try
    for I := 0 to LList.Count - 1 do
    begin
      LTit := PJGetObj(Result, LList[I].Titulo);
      if LTit = nil then
      begin
        LTit := TJSONObject.Create;
        PJAddObj(Result, LList[I].Titulo, LTit);
      end;
      LKey := TJSONObject.Create;
      PJAddStr(LKey, 'valor', LList[I].Value);
      PJAddStr(LKey, 'descricao', LList[I].Description);
      PJAddBool(LKey, 'ativo', LList[I].Ativo);
      PJAddInt(LKey, 'ordem', LList[I].Ordem);
      PJAddObj(LTit, LList[I].Name, LKey);
    end;
  finally
    LList.Free;
  end;
end;

function TParametersDatabase.ImportFrom(const ASource: IParametersSource): IParametersSource;
var
  LList: TParameterList;
  I: Integer;
begin
  { le da origem (uniforme, qualquer IParametersSource) e faz upsert (Save) em
    self - mesma semantica de TParametersSourceBase.ImportFrom. }
  LList := ASource.Select;
  try
    for I := 0 to LList.Count - 1 do
      Save(LList[I]);
  finally
    LList.Free;
  end;
  Result := Self;
end;

function TParametersDatabase.ImportFrom(const ASource: IParametersSource; out ASuccess: Boolean): IParametersSource;
begin
  ASuccess := False;
  try ImportFrom(ASource); ASuccess := True; except ASuccess := False; end;
  Result := Self;
end;

function TParametersDatabase.ExportTo(const ASource: IParametersSource): IParametersSource;
var
  LList: TParameterList;
  I: Integer;
begin
  { le de self (ja filtrado por escopo) e faz upsert (Save) na fonte destino. }
  LList := Select;
  try
    for I := 0 to LList.Count - 1 do
      ASource.Save(LList[I]);
  finally
    LList.Free;
  end;
  Result := Self;
end;

function TParametersDatabase.ExportTo(const ASource: IParametersSource; out ASuccess: Boolean): IParametersSource;
begin
  ASuccess := False;
  try ExportTo(ASource); ASuccess := True; except ASuccess := False; end;
  Result := Self;
end;

{ ---- config da tabela ---- }

function TParametersDatabase.TableName(const AValue: string): IParametersDatabase;
begin
  FTableName := AValue;
  Result := Self;
end;

function TParametersDatabase.TableName: string;
begin
  Result := FTableName;
end;

function TParametersDatabase.Schema(const AValue: string): IParametersDatabase;
begin
  FSchema := AValue;
  Result := Self;
end;

function TParametersDatabase.Schema: string;
begin
  Result := FSchema;
end;

function TParametersDatabase.AutoCreateTable(const AValue: Boolean): IParametersDatabase;
begin
  FAutoCreateTable := AValue;
  Result := Self;
end;

function TParametersDatabase.AutoCreateTable: Boolean;
begin
  Result := FAutoCreateTable;
end;

{ ---- conexao DI tipada + ownership ---- }

function TParametersDatabase.Connection(const AConnection: IConnection): IParametersDatabase;
begin
  { conexao INJETADA -> o modulo NAO e dono (nao liberta no Destroy). }
  FConnection := AConnection;
  FOwnConnection := False;
  Result := Self;
end;

function TParametersDatabase.Connection: IConnection;
begin
  Result := FConnection;
end;

{ ---- config de conexao propria ---- }

function TParametersDatabase.Engine(const AValue: TDatabaseEngine): IParametersDatabase;
begin
  FEngine := AValue;
  Result := Self;
end;

function TParametersDatabase.Engine: TDatabaseEngine;
begin
  Result := FEngine;
end;

function TParametersDatabase.DatabaseType(const AValue: TDatabaseTypes): IParametersDatabase;
begin
  FDatabaseType := AValue;
  Result := Self;
end;

function TParametersDatabase.DatabaseType: TDatabaseTypes;
begin
  Result := FDatabaseType;
end;

function TParametersDatabase.Host(const AValue: string): IParametersDatabase;
begin
  FHost := AValue;
  Result := Self;
end;

function TParametersDatabase.Host: string;
begin
  Result := FHost;
end;

function TParametersDatabase.Port(const AValue: Integer): IParametersDatabase;
begin
  FPort := AValue;
  Result := Self;
end;

function TParametersDatabase.Port: Integer;
begin
  Result := FPort;
end;

function TParametersDatabase.Username(const AValue: string): IParametersDatabase;
begin
  FUsername := AValue;
  Result := Self;
end;

function TParametersDatabase.Username: string;
begin
  Result := FUsername;
end;

function TParametersDatabase.Password(const AValue: string): IParametersDatabase;
begin
  FPassword := AValue;
  Result := Self;
end;

function TParametersDatabase.Password: string;
begin
  Result := FPassword;
end;

function TParametersDatabase.Database(const AValue: string): IParametersDatabase;
begin
  FDatabase := AValue;
  Result := Self;
end;

function TParametersDatabase.Database: string;
begin
  Result := FDatabase;
end;

function TParametersDatabase.DllBasePath(const AValue: string): IParametersDatabase;
begin
  FDllBasePath := AValue;
  Result := Self;
end;

function TParametersDatabase.DllBasePath: string;
begin
  Result := FDllBasePath;
end;

function TParametersDatabase.FirebirdVersion(const AValue: TFirebirdVersion): IParametersDatabase;
begin
  FFirebirdVersion := AValue;
  Result := Self;
end;

function TParametersDatabase.FirebirdVersion: TFirebirdVersion;
begin
  Result := FFirebirdVersion;
end;

{ ---- bootstrap + ciclo de vida + DDL ---- }

function TParametersDatabase.NewOwnSQLite(const ADbPath: string): IConnection;
begin
  { Conexao INDEPENDENTE dedicada ao store de parametros (SQLite zero-config ou
    config.db como store direto). Engine/DllBasePath opcionais herdam o setado. }
  Result := TConnection.New
    .DatabaseType(dtSQLite)
    .Database(ADbPath);
  if FEngine <> teNone then
    Result.Engine(FEngine);
  if FDllBasePath <> '' then
    Result.DllBasePath(FDllBasePath);
end;

function TParametersDatabase.ResolveConfigBasePath(const APath: string): string;
begin
  { APath vazio -> <EXE>\data\config ; pasta -> <pasta>\config ; ficheiro -> base sem extensao. }
  if APath = '' then
    Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
              DEFAULT_DATABASE_PATH + 'config'
  else if DirectoryExists(APath) then
    Result := IncludeTrailingPathDelimiter(APath) + 'config'
  else
    Result := ChangeFileExt(APath, '');
end;

function TParametersDatabase.FromConfig: IParametersDatabase;
begin
  Result := FromConfig('');
end;

function TParametersDatabase.FromConfig(const APath: string): IParametersDatabase;
var
  LBase, LDb, LIni, LJson, LZero: string;
  LJsonText: TStringList;
begin
  FLock.Acquire;
  try
    LBase := ResolveConfigBasePath(APath);
    LDb   := LBase + '.db';
    LIni  := LBase + '.ini';
    LJson := LBase + '.json';

    if FileExists(LDb) then
      { config.db existe -> e o proprio store SQLite. }
      FConnection := NewOwnSQLite(LDb)
    else
    begin
      FConnection := nil;
      if FileExists(LIni) then
      begin
        { config.ini -> reusa o leitor de config de conexao do modulo Connections (F4). }
        FConnection := TConnection.New.FromIniFile(LIni, DEFAULT_SECTION_PARAMETER_NAME);
        if FConnection.DatabaseType = dtNone then
          { config.ini orfao/incompleto (sem chave database_type - ex.: artefacto de
            sessao antiga numa pasta data/ partilhada) - trata como AUSENTE em vez de
            propagar dtNone ate' o dialect resolver (bug-1163). }
          FConnection := nil;
      end;
      if (not Assigned(FConnection)) and FileExists(LJson) then
      begin
        LJsonText := TStringList.Create;
        try
          LJsonText.LoadFromFile(LJson);
          FConnection := TConnection.New.FromJSON(LJsonText.Text);
          if FConnection.DatabaseType = dtNone then
            { mesmo cuidado do config.ini acima - config.json orfao/incompleto. }
            FConnection := nil;
        finally
          LJsonText.Free;
        end;
      end;
      if not Assigned(FConnection) then
      begin
        { nada informado (ou ficheiros orfaos sem database_type) -> SQLite
          zero-config em <EXE>\data\config.db (Q10/Q16). }
        LZero := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + DEFAULT_SQLITE_NAME;
        FConnection := NewOwnSQLite(LZero);
      end;
    end;

    FOwnConnection := True;   { a conexao e propria do modulo (liberta no Destroy). }
    Result := Self;
  finally
    FLock.Release;
  end;
end;

function TParametersDatabase.BuildOwnConnection: IConnection;
begin
  { Onda 7.6 (revisita 7.2): conexao INDEPENDENTE a partir da config fluente
    explicita (DatabaseType/Database/Host/Port/User/Pass/Schema/DllBasePath). Antes
    da 7.6 estes setters eram inertes (so FromConfig por ficheiro ou Connection()
    injetada construiam a conexao) - agora Connect/EnsureConnection honram-nos. }
  Result := TConnection.New
    .DatabaseType(FDatabaseType)
    .Database(FDatabase);
  if FHost <> '' then Result.Host(FHost);
  if FPort <> 0 then Result.Port(FPort);
  if FUsername <> '' then Result.Username(FUsername);
  if FPassword <> '' then Result.Password(FPassword);
  if FSchema <> '' then Result.Schema(FSchema);
  if FEngine <> teNone then Result.Engine(FEngine);
  if FDllBasePath <> '' then Result.DllBasePath(FDllBasePath);
  if FDatabaseType = dtFireBird then Result.FirebirdVersion(FFirebirdVersion);
end;

function TParametersDatabase.Connect: IParametersDatabase;
begin
  { A conexao e construida sob demanda: config fluente explicita (BuildOwnConnection),
    ou FromConfig (ficheiro/zero-config), ou a injetada por Connection(). }
  EnsureConnection;
  Result := Self;
end;

function TParametersDatabase.Disconnect: IParametersDatabase;
begin
  if (FConnection <> nil) and FConnection.IsConnected then
    FConnection.Disconnect;
  Result := Self;
end;

function TParametersDatabase.IsConnected: Boolean;
begin
  Result := (FConnection <> nil) and FConnection.IsConnected;
end;

procedure TParametersDatabase.EnsureConnection;
begin
  { Sob FLock: o lazy-init da conexao (FConnection/FOwnConnection) e o disparo
    unico do auto-create (FTableEnsured) sao read-then-write - dois threads a
    entrar ao mesmo tempo criariam 2 conexoes / correriam o Sync 2x. Recursivo:
    FromConfig (chamado abaixo) tambem toma o lock -> reentra. }
  FLock.Acquire;
  try
    if FConnection = nil then
    begin
      if FDatabaseType <> dtNone then
      begin
        { config fluente explicita informada -> conexao propria a partir dos setters. }
        FConnection := BuildOwnConnection;
        FOwnConnection := True;
      end
      else
        FromConfig;          { bootstrap lazy: zero-config SQLite se nada configurado. }
    end;
    if not FConnection.IsConnected then
      FConnection.Connect;
  {$IFDEF USE_DATABASE}
    { Onda 7.6 (revisita 7.2): AutoCreateTable(True) dispara a criacao da tabela
      (uma unica vez) no primeiro acesso, sem exigir EnsureTable explicito. }
    if FAutoCreateTable and not FTableEnsured then
    begin
      FTableEnsured := True;
      DoEnsureTable;
    end;
  {$ENDIF}
  finally
    FLock.Release;
  end;
end;

{$IFDEF USE_DATABASE}
function TParametersDatabase.GetNextOrder(const ATitulo: string): Integer;
var
  LDs: TDataSet;
begin
  { grupo = contrato/produto/titulo do registo a inserir (query ordenada por ordem ASC;
    a ultima linha tem o MAX). Grupo vazio -> 1. }
  Result := 1;
  LDs := BuildScopedQuery(FConnection, FTableName, FSchema,
    FContratoID, FProdutoID, ATitulo, '').Execute;
  try
    if LDs.RecordCount > 0 then
    begin
      LDs.Last;
      Result := LDs.FieldByName('ordem').AsInteger + 1;
    end;
  finally
    LDs.Free;
  end;
end;

function TParametersDatabase.CurrentOrderOf(const AName, ATitulo: string): Integer;
var
  LDs: TDataSet;
begin
  { ordem atual da chave especifica no grupo (0 se nao existir). }
  Result := 0;
  LDs := BuildScopedQuery(FConnection, FTableName, FSchema,
    FContratoID, FProdutoID, ATitulo, AName).Execute;
  try
    if not LDs.EOF then
      Result := LDs.FieldByName('ordem').AsInteger;
  finally
    LDs.Free;
  end;
end;

procedure TParametersDatabase.ReorderShift(const ATitulo: string;
  AContrato, AProduto, AFrom, ATo, ADelta: Integer);
var
  LQB: IQueryBuilder;
begin
  if (FConnection = nil) or (ADelta = 0) then
    Exit;
  { ZERO SQL manual: SetValueDelta (auto-incremento dialect-aware do QueryBuilder,
    F5) gera SET ordem = ordem +/- N; escopo e intervalo pelo Where bindado. }
  LQB := TQueryBuilder.New.Connection(FConnection)
    .Update(FTableName, FSchema)
    .SetValueDelta('ordem', ADelta)
    .Where('contrato_id', '=', AContrato)
    .Where('produto_id',  '=', AProduto)
    .Where('titulo',      '=', ATitulo)
    .Where('ordem',       '>=', AFrom);
  if ATo >= 0 then
    LQB.Where('ordem', '<=', ATo);
  LQB.ExecuteMutation;
end;
{$ENDIF}

procedure TParametersDatabase.DoEnsureTable;
{$IFDEF USE_DATABASE}
var
  LDef: ISchemaDefinition;
{$ENDIF}
begin
{$IFDEF USE_DATABASE}
  { A tabela de parametros vira uma ISchemaDefinition; o motor F5 (ISynchronize)
    trata criacao/actualizacao idempotente + indice unico composto (ChaveUnica).
    Assume FConnection ja aberta (garantido pelo caller: EnsureConnection). }
  LDef := TSchemaDefinition.New;
  LDef.Table(FTableName)
    .AddColumn('config_id',      ckIdentity, 0,   False, True)   { PK auto-incremento }
    .AddColumn('contrato_id',    ckInteger,  0,   False)
    .AddColumn('produto_id',     ckInteger,  0,   False)
    .AddColumn('ordem',          ckInteger,  0,   False)
    .AddColumn('titulo',         ckVarChar,  255, False)
    .AddColumn('chave',          ckVarChar,  255, False)
    .AddColumn('valor',          ckText,     0,   True)
    .AddColumn('descricao',      ckText,     0,   True)
    .AddColumn('ativo',          ckBoolean,  0,   False)
    .AddColumn('data_cadastro',  ckDateTime, 0,   False)
    .AddColumn('data_alteracao', ckDateTime, 0,   False)
    .AddUnique(['contrato_id', 'produto_id', 'titulo', 'chave'], 'ChaveUnica');
  TSynchronize.New(FConnection).Sync(LDef);
{$ELSE}
  raise EParametersConfigurationException.Create(
    'Parameters.Database.EnsureTable requer o modulo Database (USE_DATABASE).',
    0, 'EnsureTable');
{$ENDIF}
end;

function TParametersDatabase.EnsureTable: IParametersDatabase;
begin
{$IFDEF USE_DATABASE}
  EnsureConnection;      { garante a conexao (pode ja ter auto-criado a tabela). }
  FTableEnsured := True;
  DoEnsureTable;         { idempotente (Sync); alinha o estado apos criacao explicita. }
  Result := Self;
{$ELSE}
  raise EParametersConfigurationException.Create(
    'Parameters.Database.EnsureTable requer o modulo Database (USE_DATABASE).',
    0, 'EnsureTable');
{$ENDIF}
end;

function TParametersDatabase.TableExists: Boolean;
begin
{$IFDEF USE_DATABASE}
  EnsureConnection;
  { F5-FU.2 - IMetadata dissolvido; introspeccao de EXISTENCIA de tabela pertence
    a COLECCAO ITables (lista/descobre membros), nao a um inspector separado
    (plano f5-repair R2.8 / principio de layering §6-A). Config e SQLite/
    schemaless (FSchema='' por defeito). }
  Result := TTables.New.Connection(FConnection).LoadFromConnection(FSchema).TableExists(FTableName);
{$ELSE}
  raise EParametersConfigurationException.Create(
    'Parameters.Database.TableExists requer o modulo Database (USE_DATABASE).',
    0, 'TableExists');
{$ENDIF}
end;

{$IFDEF USE_DEPRECATED}

{ ---- Compat v1.0.7 (deprecated) - cada wrapper delega ao equivalente v3 ---- }

function TParametersDatabase.Getter(const AName: string): TParameter;
begin
  Result := Select(AName);
end;

function TParametersDatabase.Getter(const AName: string; out AParameter: TParameter): IParametersSource;
begin
  Result := Select(AName, AParameter);
end;

function TParametersDatabase.List: TParameterList;
begin
  Result := Select;
end;

function TParametersDatabase.List(out AList: TParameterList): IParametersSource;
begin
  Result := Select(AList);
end;

function TParametersDatabase.Setter(const AParameter: TParameter): IParametersSource;
begin
  Result := Save(AParameter);
end;

function TParametersDatabase.Setter(const AParameter: TParameter; out ASuccess: Boolean): IParametersSource;
begin
  Result := Save(AParameter, ASuccess);
end;

function TParametersDatabase.CreateTable: IParametersDatabase;
begin
  Result := EnsureTable;
end;

function TParametersDatabase.Connect(out ASuccess: Boolean): IParametersDatabase;
begin
  ASuccess := False;
  try
    Connect();             // overload v3 sem args (lanca EParameters* em erro)
    ASuccess := True;
  except
    ASuccess := False;
  end;
  Result := Self;
end;

{ ---- Compat v2.3.0 (deprecated) - capacidades re-expostas via Connections/Database ---- }

function TParametersDatabase.DropTable: IParametersDatabase;
begin
{$IFDEF USE_DATABASE}
  EnsureConnection;
  TSchema.New.DropTable(FConnection, FTableName);   { idempotente (consulta TableExists). }
  FTableEnsured := False;
{$ELSE}
  raise EParametersConfigurationException.Create(
    'Parameters.Database.DropTable requer o modulo Database (USE_DATABASE).', 0, 'DropTable');
{$ENDIF}
  Result := Self;
end;

function TParametersDatabase.DropTable(out ASuccess: Boolean): IParametersDatabase;
begin
  ASuccess := False;
  try DropTable(); ASuccess := True; except ASuccess := False; end;
  Result := Self;
end;

function TParametersDatabase.MigrateTable: IParametersDatabase;
begin
  Result := EnsureTable;   { EnsureTable e idempotente: cria-se-nao-existe + migra. }
end;

function TParametersDatabase.MigrateTable(out ASuccess: Boolean): IParametersDatabase;
begin
  ASuccess := False;
  try EnsureTable; ASuccess := True; except ASuccess := False; end;
  Result := Self;
end;

function TParametersDatabase.ListAvailableDatabases: TStringArray;
begin
  EnsureConnection;
  Result := FConnection.GetDatabaseNames;
end;

function TParametersDatabase.ListAvailableDatabases(out AList: TStringArray): IParametersDatabase;
begin
  AList := ListAvailableDatabases;
  Result := Self;
end;

function TParametersDatabase.ListAvailableTables: TStringArray;
begin
  EnsureConnection;
  Result := FConnection.GetTableNames(FSchema);
end;

function TParametersDatabase.ListAvailableTables(out AList: TStringArray): IParametersDatabase;
begin
  AList := ListAvailableTables;
  Result := Self;
end;

{$ENDIF}

{$ENDIF USE_PARAMETERS}

end.
