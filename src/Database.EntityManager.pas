{ =============================================================================
  Database.EntityManager - Entity Manager (TEntityManager, IEntityManager)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.0.0
  FileVersion:    1.10.0
  Author:         Claiton de Souza Linhares
  Date:           25/07/2026

  Changelog (file):
  - 1.10.0 (25/07/2026): F5-FU.1 (populacao de IsIdentity por dialecto, ADITIVO) -
    MapTable passa a propagar LStruct[i].IsIdentity (populado por TCatalogReader.
    TableStructure/ApplyColumnIdentity, via IDialect.IdentityColumnsSQL) para
    IField.IsIdentity, na mesma cadeia fluente de Position/ConstraintName/
    ReferencedTable/... abaixo do TField.New. Default 0 -> IsIdentity=False
    (dialecto sem suporte ou coluna sem identity - no-op inalterado).
  - 1.9.0 (15/07/2026): Onda 7 (camada de lancadores fluentes) - resolve o
    ciclo ITable.EntityManager <-> Database.EntityManager (esta unit ja usa
    Database.Table para TTable.New em CloneTableStructure/MapTable - Database.
    Table.pas NAO pode `uses Database.EntityManager` diretamente). Nova
    secao `initialization` atribui GTableEntityManagerFactory (Databases.
    Interfaces 2.11.0, gated USE_ENTITY_MANAGER) para TableEntityManager
    FactoryImpl (nova funcao privada, implementation) - Table(ATable)
    diretamente sobre a ITable recebida (SEM MapTable/discovery - reusa os
    campos/valores ja presentes) + Connection(ATable.Connection). TTable.
    EntityManager (Database.Table.pas) so chama a var, com guarda Assigned.
    Zero mudanca na API publica de IEntityManager/TEntityManager.
  - 1.8.0 (14/07/2026): Onda 6-b I7 - LogicalName em IField/ITable (nome
    logico) + ITable.PhysicalColumn (resolucao logico->fisico,
    case-insensitive, fallback ao nome dado); ListWhere delega. Aditivo
    (default '' -> inalterado).
  - 1.7.0 (14/07/2026): Sub-passo 4.4 (continuacao Onda 4, revisao F5) - soft
    delete no List/ListWhere/Find: novo campo FIncludeDeleted (default False)
    + getter/setter fluente IncludeDeleted (padrao ICatalogReader.
    IncludeSystemObjects) + helper privado ApplySoftDeleteFilter(AQB) -
    quando FIncludeDeleted=False (default) E FTable.FieldIsDeleted esta
    configurado E a coluna existe na tabela (FTable.FieldExist), acrescenta
    Where(FieldIsDeleted, '=', 0) [bindado, via IQueryBuilder] a query antes
    de Execute - so devolve os registos ativos. Sem FieldIsDeleted
    configurado (ou coluna inexistente) -> comportamento inalterado
    (aditivo). Chamado em Find/List/ListWhere logo apos montar o LQB base
    (ANTES de LQB.Execute). NOTA: a versao simples "=0" nao trata explicit
    NULL (coluna sem DEFAULT e nunca escrita) como ativo - nao ha precedente
    de WhereOr/grupo no QueryBuilder v3 (so AND top-level; WhereRaw exigiria
    quoting de identificador por dialecto, fora do boundary desta tarefa) -
    para colunas de soft delete NULLABLE sem DEFAULT 0 na DDL, considerar
    NOT NULL DEFAULT 0 no schema (mesma orientacao do smoke novo).
    CloneTableStructure passa tambem a propagar AuditFields/FieldDateCreated/
    FieldDateUpdated/FieldIsDeleted/FieldIsActive de ATable (a ITable mapeada)
    para a tabela clonada, junto de TableName/DatabaseTypes (ja propagados) -
    uma linha devolvida por Find/List/ListWhere fica apta a soft-delete/
    auditoria via Execute(dsDeleted/dsInsert/dsEdit) sem reconfiguracao manual.
  - 1.6.0 (14/07/2026): renomeacao mecanica IMetadataProvider -> ICatalogReader /
    TMetadataProvider -> TCatalogReader.
  - 1.5.0 (13/07/2026): Fatia A (continuacao Onda 4, revisao F5) - injecao
    aditiva de FConnection nas ITable materializadas: CloneTableStructure
    (usado por Find/List/ListWhere/Delete(AId)) e MapTable passam a chamar
    Result/FTable.Connection(FConnection), deixando a tabela pronta para
    ITable.Execute (overload sem parametro) sem depender do caller passar
    AConnection explicitamente. Nao muda a assinatura publica de
    IEntityManager nem a semantica de Save/Delete/Update.
  - 1.4.0 (13/07/2026): Ajuste de API (ordem do owner) - Save(ATable) passa a
    DELEGAR para ITable.Execute(FConnection); removida a inferencia
    Insert/Update/Delete por Status/PK e o reset de Status daqui - agora
    centralizados em TTable.Execute (Database.Table.pas). Assinatura publica
    de IEntityManager inalterada.
  - 1.3.0 (13/07/2026): Onda 4.3 - MapTable(ATableName, ASchema) - cria um
    IMetadataProvider sobre FConnection, le TableStructure e constroi FTable
    (ITable) automaticamente (campo a campo, via TField.New+IFields.AddField);
    uses Database.CatalogReader[.Interfaces].
  - 1.2.0 (13/07/2026): Onda 4.2 - Save(ATable) passa a decidir INSERT/UPDATE/
    DELETE pelo ATable.Status (dsInsert/dsEdit/dsDeleted, modelo v1.6.1);
    dsInactive preserva o comportamento legado (infere pela PK); reset do
    status p/ dsInactive apos gravar com sucesso; uses Commons.Database.Types.
  - 1.1.0 (13/07/2026): absorcao v3 (FASE 5 Onda 4.0) - ProjectVersion 3.0.0, ModuleVersion 1.8.0; uses Providers.Connection.Interfaces -> Connections.Interfaces; migracao interna p/ API v3 do QueryBuilder; excecoes na faixa 41.
  - 1.0.0 (26/02/2026): TEntityManager com Connection, Table; Find/List/ListWhere (clone ITable + fill from DataSet); Save/Delete/Update via ITable.Execute*; cache opcional para Find (Fase 5).
  ============================================================================= }

unit Database.EntityManager;


{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}
interface

{$I ORM.Defines.inc}

uses
{$IF DEFINED(FPC)}
  SysUtils, Variants, DB, Generics.Collections,
{$ELSE}
  System.SysUtils, System.Variants, Data.DB, System.Generics.Collections,
{$ENDIF}
  Commons.Types,
  Commons.Database.Types,
  Database.Field,
  Database.Fields,
  Database.Table,
  Database.QueryBuilder,
  Database.CatalogReader,
  Databases.Interfaces,
  Connections.Interfaces;

type
  TEntityManager = class(TInterfacedObject, IEntityManager)
  private
    FConnection: IConnection;
    FTable: ITable;
    FCache: TDictionary<string, ITable>;
    FIncludeDeleted: Boolean;
    function CloneTableStructure(const ATable: ITable): ITable;
    procedure FillTableFromDataSet(const ATable: ITable; const ADataSet: TDataSet);
    function GetPrimaryKeyColumn: string;
    { Sub-passo 4.4: acrescenta o filtro de soft delete (FieldIsDeleted=0) ao
      IQueryBuilder passado quando aplicavel (ver comentario do changelog). }
    procedure ApplySoftDeleteFilter(const AQB: IQueryBuilder);
  public
    constructor Create;
    destructor Destroy; override;
    class function New: IEntityManager;

    function Connection(const AConnection: IConnection): IEntityManager; overload;
    function Connection: IConnection; overload;

    function Table(const ATable: ITable): IEntityManager; overload;
    function Table: ITable; overload;

    function MapTable(const ATableName: string; const ASchema: string = ''): IEntityManager;

    function IncludeDeleted(const AValue: Boolean): IEntityManager; overload;
    function IncludeDeleted: Boolean; overload;

    function Find(const AId: Variant): ITable;
    function List: TArray<ITable>;
    function ListWhere(const AColumn, AOp: string; const AValue: Variant): TArray<ITable>;

    function Save(const ATable: ITable): Integer;
    function Delete(const ATable: ITable): Integer; overload;
    function Delete(const AId: Variant): Integer; overload;
    function Update(const ATable: ITable): Integer;
  end;

implementation

type
{$IF DEFINED(FPC)}
  TDBField = DB.TField;
{$ELSE}
  TDBField = Data.DB.TField;
{$ENDIF}

function TEntityManager.GetPrimaryKeyColumn: string;
var
  LPk: IField;
begin
  Result := '';
  if FTable = nil then
    Exit;
  LPk := FTable.GetPrimaryKey;
  if LPk <> nil then
    Result := LPk.Column;
end;

function TEntityManager.CloneTableStructure(const ATable: ITable): ITable;
var
  LFields: IFields;
  LArr: TFieldArray;
  i: Integer;
begin
  Result := nil;
  if ATable = nil then
    Exit;
  LFields := TFields.New;
  LArr := ATable.GetFieldsList;
  for i := 0 to High(LArr) do
    LFields.AddField(LArr[i].Clone);
  Result := TTable.New(LFields, ATable.TableName);
  Result.DatabaseTypes(ATable.DatabaseTypes);
  { Fatia A (continuacao Onda 4) - a tabela clonada (Find/List/ListWhere/
    Delete(AId), todos passam por aqui) sai pronta a executar via a propria
    IConnection do EntityManager, sem depender de o caller passar AConnection
    a ITable.Execute. }
  Result.Connection(FConnection);
  { Sub-passo 4.4 (continuacao Onda 4) - propaga a configuracao de auditoria/
    soft delete de ATable (a ITable "mapeada" pelo EntityManager) para a
    tabela clonada, tal como TableName/DatabaseTypes ja eram propagados -
    garante que uma linha devolvida por Find/List/ListWhere continua apta a
    soft-delete/auditoria (Execute(dsDeleted)/dsInsert/dsEdit) sem o caller
    ter de reconfigurar os nomes de coluna manualmente. Sem configuracao em
    ATable (strings vazias, AuditFields=False) -> zero mudanca (aditivo). }
  Result.AuditFields(ATable.AuditFields)
    .FieldDateCreated(ATable.FieldDateCreated)
    .FieldDateUpdated(ATable.FieldDateUpdated)
    .FieldIsDeleted(ATable.FieldIsDeleted)
    .FieldIsActive(ATable.FieldIsActive);
end;

procedure TEntityManager.FillTableFromDataSet(const ATable: ITable; const ADataSet: TDataSet);
var
  LArr: TFieldArray;
  i: Integer;
  LDataField: TDBField;
  LColName: string;
begin
  if (ATable = nil) or (ADataSet = nil) or ADataSet.IsEmpty then
    Exit;
  LArr := ATable.GetFieldsList;
  for i := 0 to High(LArr) do
  begin
    LColName := LArr[i].Column;
    LDataField := ADataSet.FindField(LColName);
    if LDataField = nil then
      LDataField := ADataSet.FindField(LowerCase(LColName));
    if LDataField <> nil then
      LArr[i].SetColumnValueWithoutChange(LDataField.Value);
  end;
end;

constructor TEntityManager.Create;
begin
  inherited Create;
  FCache := TDictionary<string, ITable>.Create;
end;

destructor TEntityManager.Destroy;
begin
  FCache.Free;
  inherited;
end;

class function TEntityManager.New: IEntityManager;
begin
  Result := TEntityManager.Create;
end;

function TEntityManager.Connection(const AConnection: IConnection): IEntityManager;
begin
  FConnection := AConnection;
  Result := Self;
end;

function TEntityManager.Connection: IConnection;
begin
  Result := FConnection;
end;

function TEntityManager.Table(const ATable: ITable): IEntityManager;
begin
  FTable := ATable;
  Result := Self;
end;

function TEntityManager.Table: ITable;
begin
  Result := FTable;
end;

procedure TEntityManager.ApplySoftDeleteFilter(const AQB: IQueryBuilder);
begin
  { Sub-passo 4.4 - ver comentario do changelog (topo do ficheiro) para o
    detalhe completo da decisao. }
  if (AQB = nil) or FIncludeDeleted or (FTable = nil) then
    Exit;
  if (Trim(FTable.FieldIsDeleted) = '') or not FTable.FieldExist(FTable.FieldIsDeleted) then
    Exit;
  AQB.Where(FTable.FieldIsDeleted, '=', 0);
end;

function TEntityManager.IncludeDeleted(const AValue: Boolean): IEntityManager;
begin
  FIncludeDeleted := AValue;
  Result := Self;
end;

function TEntityManager.IncludeDeleted: Boolean;
begin
  Result := FIncludeDeleted;
end;

function TEntityManager.MapTable(const ATableName: string; const ASchema: string): IEntityManager;
var
  LProvider: ICatalogReader;
  LStruct: TArray<TDatabaseFields>;
  LFields: IFields;
  LField: IField;
  i: Integer;
begin
  Result := Self;
  if FConnection = nil then
    Exit;
  { descobre a estrutura real da tabela via ICatalogReader (Onda 5.1) }
  LProvider := TCatalogReader.New(FConnection);
  LStruct := LProvider.TableStructure(ATableName, ASchema);
  LFields := TFields.New;
  for i := 0 to High(LStruct) do
  begin
    LField := TField.New(LStruct[i].Column, LStruct[i].ColumnType,
      SameText(LStruct[i].IsNull, 'YES'), LStruct[i].IsPKey <> 0);
    LField.Position(LStruct[i].Position)
      .ConstraintName(LStruct[i].ConstraintName)
      .ReferencedTable(LStruct[i].ReferencedTable)
      .ReferencedColumn(LStruct[i].ReferencedColumn)
      .OnUpdateRule(LStruct[i].OnUpdateRule)
      .OnDeleteRule(LStruct[i].OnDeleteRule)
      .IsIdentity(LStruct[i].IsIdentity <> 0); // F5-FU.1
    LFields.AddField(LField);
  end;
  FTable := TTable.New(LFields, ATableName);
  FTable.DatabaseTypes(FConnection.DatabaseType);
  { Fatia A (continuacao Onda 4) - a tabela auto-mapeada sai pronta a executar
    via a propria IConnection do EntityManager. }
  FTable.Connection(FConnection);
end;

function TEntityManager.Find(const AId: Variant): ITable;
var
  LDS: TDataSet;
  LQB: IQueryBuilder;
  LKey: string;
  LPkCol: string;
begin
  Result := nil;
  if (FConnection = nil) or (FTable = nil) then
    Exit;
  LPkCol := GetPrimaryKeyColumn;
  if LPkCol = '' then
    Exit;
  LKey := VarToStr(AId);
  if FCache.TryGetValue(LKey, Result) then
    Exit;
  LQB := TQueryBuilder.New
    .Connection(FConnection)
    .Select('*')
    .From(FTable.TableName, FConnection.Schema)
    .Where(LPkCol, '=', AId)
    .Limit(1);
  ApplySoftDeleteFilter(LQB);
  LDS := LQB.Execute;
  try
    if (LDS <> nil) and not LDS.IsEmpty then
    begin
      Result := CloneTableStructure(FTable);
      FillTableFromDataSet(Result, LDS);
      FCache.AddOrSetValue(LKey, Result);
    end;
  finally
    if LDS <> nil then
      LDS.Free;
  end;
end;

function TEntityManager.List: TArray<ITable>;
var
  LDS: TDataSet;
  LQB: IQueryBuilder;
  LList: TList<ITable>;
  LTable: ITable;
begin
  SetLength(Result, 0);
  if (FConnection = nil) or (FTable = nil) then
    Exit;
  LQB := TQueryBuilder.New
    .Connection(FConnection)
    .Select('*')
    .From(FTable.TableName, FConnection.Schema);
  ApplySoftDeleteFilter(LQB);
  LDS := LQB.Execute;
  try
    if LDS = nil then
      Exit;
    LList := TList<ITable>.Create;
    try
      while not LDS.Eof do
      begin
        LTable := CloneTableStructure(FTable);
        FillTableFromDataSet(LTable, LDS);
        LList.Add(LTable);
        LDS.Next;
      end;
      Result := LList.ToArray;
    finally
      LList.Free;
    end;
  finally
    if LDS <> nil then
      LDS.Free;
  end;
end;

function TEntityManager.ListWhere(const AColumn, AOp: string; const AValue: Variant): TArray<ITable>;
var
  LDS: TDataSet;
  LQB: IQueryBuilder;
  LList: TList<ITable>;
  LTable: ITable;
begin
  SetLength(Result, 0);
  if (FConnection = nil) or (FTable = nil) then
    Exit;
  LQB := TQueryBuilder.New
    .Connection(FConnection)
    .Select('*')
    .From(FTable.TableName, FConnection.Schema)
    .Where(FTable.PhysicalColumn(AColumn), AOp, AValue);
  ApplySoftDeleteFilter(LQB);
  LDS := LQB.Execute;
  try
    if LDS = nil then
      Exit;
    LList := TList<ITable>.Create;
    try
      while not LDS.Eof do
      begin
        LTable := CloneTableStructure(FTable);
        FillTableFromDataSet(LTable, LDS);
        LList.Add(LTable);
        LDS.Next;
      end;
      Result := LList.ToArray;
    finally
      LList.Free;
    end;
  finally
    if LDS <> nil then
      LDS.Free;
  end;
end;

function TEntityManager.Save(const ATable: ITable): Integer;
begin
  { Onda 5.x - Ajuste de API (ordem do owner): delega para ITable.Execute, que
    agora concentra a decisao Insert/Update/Delete por Status (TRowStatus) e o
    reset do Status apos gravar - deixou de estar duplicado aqui. }
  Result := 0;
  if (FConnection = nil) or (ATable = nil) then
    Exit;
  Result := ATable.Execute(FConnection);
end;

function TEntityManager.Delete(const ATable: ITable): Integer;
begin
  Result := 0;
  if (FConnection = nil) or (ATable = nil) then
    Exit;
  Result := ATable.ExecuteDelete(FConnection);
end;

function TEntityManager.Delete(const AId: Variant): Integer;
var
  LTable: ITable;
  LPkCol: string;
begin
  Result := 0;
  if (FConnection = nil) or (FTable = nil) then
    Exit;
  LPkCol := GetPrimaryKeyColumn;
  if LPkCol = '' then
    Exit;
  LTable := CloneTableStructure(FTable);
  LTable.Fields(LPkCol).SetColumnValue(AId);
  Result := LTable.ExecuteDelete(FConnection);
end;

function TEntityManager.Update(const ATable: ITable): Integer;
begin
  Result := 0;
  if (FConnection = nil) or (ATable = nil) then
    Exit;
  Result := ATable.ExecuteUpdate(FConnection);
end;

{$IFDEF USE_ENTITY_MANAGER}
{ Onda 7 (camada de lancadores fluentes) - implementacao concreta registada
  em GTableEntityManagerFactory (Databases.Interfaces); chamada por
  TTable.EntityManager (Database.Table.pas). Table(ATable) diretamente sobre
  a ITable recebida - SEM MapTable/discovery via ICatalogReader, reusa os
  campos/valores ja presentes nessa instancia - + Connection(ATable.
  Connection) (fallback fluente ja configurado na propria ITable, Fatia A). }
function TableEntityManagerFactoryImpl(const ATable: ITable): IEntityManager;
begin
  Result := nil;
  if ATable = nil then
    Exit;
  Result := TEntityManager.New.Connection(ATable.Connection).Table(ATable);
end;
{$ENDIF}

initialization
{$IFDEF USE_ENTITY_MANAGER}
  GTableEntityManagerFactory := TableEntityManagerFactoryImpl;
{$ENDIF}

end.
