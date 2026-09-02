{ =============================================================================
  Database.Tables - Container de tabelas (TTables, ITables)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.2.0
  FileVersion:    1.6.0
  Author:         Claiton de Souza Linhares
  Date:           30/07/2026

  Changelog (file):
  - 1.6.0 (30/07/2026): Onda S4 (ADITIVO - eixo FULL, ver Databases.Interfaces
    3.2.0) - ToFullJSON (COMPOE StructureToJSON+ToJSON)/FromFullJSON/
    MergeFullFromJSON (decompoem via Database.Helpers.JSON.JSONExtractMember,
    estrutura antes de dado - novo uses implementation Database.Helpers.JSON)
    + Export(AWithData)/Import(AJSON, AWithData, AMerge) ergonomicos, SEM
    overload de AQuery:IQueryBuilder (reservada a ITable/ISchema/IDatabase).
    Zero mudanca nos metodos pre-existentes.
  - 1.5.0 (29/07/2026): Onda S3 (ADITIVO - eixo SQL, ver Databases.Interfaces
    3.1.0) - ToSQL: string (DML - INSERT de todos os registos de FList,
    orquestrando ITable.ToSQL de cada elemento; zero SQL novo). NOTA:
    ISchema/TSchema SOBREPOE este metodo (Database.Schema.pas 1.7.0) - ao
    contrario de DropTableSQL/RenameTableSQL/DropTable/RenameTable (herdados
    TAL-QUAL, FList e' o contentor certo para essas), o FList aqui e' um
    contentor ESTRUTURAL PARALELO a FGroups (o modelo por-tabela usado por
    ToJSON/StructureToJSON do Schema) - herdar sem override devolveria '' para
    qualquer schema construido pelo eixo JSON (achado durante a implementacao
    do ToDDL/ToSQL do Schema). Zero mudanca nos metodos pre-existentes.
  - 1.4.0 (29/07/2026): Onda S2-a (ADITIVO, simetria To/From/Merge) - ITables
    ganha StructureMergeFromJSON - PATCH aditivo POR NOME de tabela
    (TableName): existentes recebem ITable.StructureMergeFromJSON, ausentes
    sao criados via TTable.New.StructureFromJSON, nada e removido (ao
    contrario de StructureFromJSON, que substitui FList por completo). Zero
    mudanca nos metodos pre-existentes.
  - 1.3.0 (26/07/2026): conformidade F5 (onda C4) - M2: as portas de descoberta
    (GetTableNames/GetDatabaseNames/GetSchemaNames/GetColumnNames/GetTableStructure)
    DELEGAM ao motor unico TCatalogReader (SSOT, filtro de sistema + enriquecimento)
    em vez do FConnection.Get* cru; fallback FConnection sob USE_DATABASE OFF. M3:
    LoadFromConnection liga cada ITable carregada ao motor (Connection +
    DatabaseTypes) para se detalhar ON DEMAND (nao eager - evita N structure-
    queries que penalizariam o TableExists do unico consumidor externo,
    Parameters.Database). Gate: dcc32+fpc32 ProvidersV3 EXIT=0 + smoke_parameters_db
    93/0 + database 67/0 + launchers 36/0 + metadata 19/0 + loggers_db 12/0, zero
    regressao. ModuleVersion 3.0.0 (onda C1).
  - 1.2.1 (25/07/2026): R2.2 (f5-repair, Onda R2 - re-layering por
    responsabilidade) - ADITIVO, extend existing: ITables ganha
    DropTableSQL/RenameTableSQL/DropTable/RenameTable POR NOME - mesma
    semantica ja existente em TSchema (Database.Schema.pas, nivel schema),
    replicada aqui trocando SchemaName (proprio de TSchema) pelo getter
    Schema ja existente em TTables. Novo uses (implementation, gated
    USE_DATABASE): Database.Dialect (classe TDialect) + Database.CatalogReader
    (classe TCatalogReader) - nenhuma das 2 usa Database.Tables, sem ciclo.
  - 1.2.0 (13/07/2026): Fatia B-c (continuacao Onda 4, revisao F5) -
    serializacao PROPRIA da Tables em 2 eixos (ver comentario completo em
    Database.Tables.Interfaces.ITables). StructureToJSON/StructureFromJSON
    (novos) + MergeFromJSON (novo) somam-se ao ToJSON/FromJSON ja existentes
    (FromJSON deixa de ser stub). FromJSON/MergeFromJSON partilham a logica
    de reconciliacao por PK privada ImportJSON(AJSON, AMerge) - arvore de
    import por object_state (INSERTED/UNMODIFIED/MODIFIED/DELETED). Registos
    novos (INSERTED, ou MODIFIED/nao encontrado) sao adicionados via
    AddRowFromJSON, que clona a ESTRUTURA do 1o registo existente em FList
    (round-trip StructureToJSON->StructureFromJSON) quando disponivel, antes
    de hidratar os dados - sem estrutura previa, so o object_state->Status e
    aplicado (limitacao documentada: o eixo dado nunca cria campos novos,
    mesma regra ja valida em IFields/ITable). Helpers locais de parsing JSON
    (TablesFindNode/TablesJSONNodeToVariant) duplicados por compilador
    (fpjson/System.JSON), mesma tecnica ja usada em Database.Field.pas/
    Database.Table.pas (nao exportados por aquelas units).
  - 1.1.0 (12/07/2026): absorcao v3 (FASE 5 Onda 5.1) - uses
    Providers.Connection.Interfaces -> Connections.Interfaces; header v3.
  - 1.0.0 (03/02/2026): Versão inicial.
  - 1.0.1 (22/02/2026): TTables com Connection, LoadFromConnection (GetTableNames), Table, GetTablesList, TablesCount, TableExists.
  - 1.0.2 (22/02/2026): FList como TTableLists (array of TTableList); SyncTableListFromTable.
  - 1.0.3 (26/02/2026): LoadFromConnection(const ASchema) para filtrar tabelas por schema.
  - 1.0.4 (26/02/2026): GetTableNames, GetDatabaseNames, GetSchemaNames, GetColumnNames, GetTableStructure movidos de IConnection para ITables; delegacao a FConnection; LoadFromConnection usa GetTableNames.
  - 1.0.5 (27/02/2026): SetOnLoadTablesProgress, SetOnLoadFieldsProgress; disparo de OnLoadTablesProgress em LoadFromConnection (assimilação DatabaseORM).
  - 1.0.6 (12/03/2026): LoadFromConnection dispara OnLoadFieldsProgress por tabela/coluna (GetColumnNames por tabela).
  ============================================================================= }

unit Database.Tables;


{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}
interface

{$I ../../../ORM.Defines.inc}

uses
{$IF DEFINED(FPC)}
  SysUtils, Variants, fpjson,
{$ELSE}
  System.SysUtils, System.Variants, System.JSON,
{$ENDIF}
  Commons.Types,
  Databases.Interfaces,
  Connections.Interfaces;

type
  TTableList = record
    index: Integer;
    table: ITable;
    tablename: string;
    alias: string;
    auditFields: Boolean;
    fieldDateCreated: string;
    fieldDateUpdated: string;
    fieldIsDeleted: string;
    fieldIsActive: string;
  end;

  TTableLists = array of TTableList;

  // Container de tabelas (TTables, ITables)
  TTables = class(TInterfacedObject, ITables)
  private
    FList: TTableLists;
    FConnection: IConnection;
    FDatabaseTypes: TDatabaseTypes;
    FDatabase: string;
    FSchema: string;
    FOnLoadTablesProgress: TOnLoadTablesProgress;
    FOnLoadFieldsProgress: TOnLoadFieldsProgress;
    function IndexOfTable(const AName: string): Integer;
    { Fatia B-c (Onda 4-cont) - reconciliacao por PK partilhada por
      FromJSON(AMerge=False, "replace")/MergeFromJSON(AMerge=True, "patch"). }
    function ImportJSON(const AJSON: string; const AMerge: Boolean): ITables;
    { Localiza em FList o indice do registo cujo campo PK tem, no proprio
      FList[i].table, o mesmo valor que AItem traz para essa mesma coluna PK;
      -1 se nenhum registo tiver PK ou nenhum coincidir. }
    function FindMatchIndex(const AItem: TJSONObject): Integer;
    { Adiciona um novo registo a FList hidratado a partir de AItemJSON
      (eixo dado, objeto ITable.ToJSON); clona a ESTRUTURA de FList[0] (round-
      trip StructureToJSON->StructureFromJSON) quando ja existe pelo menos 1
      registo, para que os campos existam antes da hidratacao por nome. }
    function AddRowFromJSON(const AItemJSON: string; const AMerge: Boolean): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: ITables;

    function Connection(const AConnection: IConnection): ITables; overload;
    function Connection: IConnection; overload;
    function DatabaseTypes(const AValue: TDatabaseTypes): ITables; overload;
    function DatabaseTypes: TDatabaseTypes; overload;
    function Database(const AValue: string): ITables; overload;
    function Database: string; overload;
    function Schema(const AValue: string): ITables; overload;
    function Schema: string; overload;

    function SetOnLoadTablesProgress(const AValue: TOnLoadTablesProgress): ITables;
    function SetOnLoadFieldsProgress(const AValue: TOnLoadFieldsProgress): ITables;
    function LoadFromConnection(const ASchema: string = ''): ITables;
    function LoadTables: ITables;
    function Table(const AName: string): ITable;
    function GetTablesList: TTableArray;
    function TablesCount: Integer;
    function TableExists(const AName: string): Boolean;
    function GetTableNames(const ASchema: string = ''): TStringArray;
    function GetDatabaseNames: TStringArray;
    function GetSchemaNames(const ADatabase: string = ''): TStringArray;
    function GetColumnNames(const ATableName: string; const ASchema: string = ''): TStringArray;
    function GetTableStructure(const ATableName: string; const ASchema: string = ''): TArray<TDatabaseFields>;
    { R2.2 (f5-repair) - manipulacao IMPERATIVA de TABELA (por nome), POR
      NOME - ver comentario completo em Databases.Interfaces.ITables. }
    function DropTableSQL(const ATableName: string): string;
    function RenameTableSQL(const AOldName, ANewName: string): string;
    function DropTable(const AConnection: IConnection; const ATableName: string): Integer;
    function RenameTable(const AConnection: IConnection; const AOldName, ANewName: string): Integer;
    function HasChanges: Boolean;
    function ClearAllChanges: ITables;

    { Serialize PROPRIA da Tables (Fatia B-c) - ver comentario completo em
      Database.Tables.Interfaces.ITables. }
    function ToJSON: string;
    function FromJSON(const AJSON: string): ITables;
    function MergeFromJSON(const AJSON: string): ITables;
    function StructureToJSON: string;
    function StructureFromJSON(const AJSON: string): ITables;
    { Onda S2-a (ADITIVO) - ver comentario completo em
      Databases.Interfaces.ITables.StructureMergeFromJSON. }
    function StructureMergeFromJSON(const AJSON: string): ITables;
    { Onda S3 - eixo SQL (DML) - ver comentario completo em
      Databases.Interfaces.ITables.ToSQL. }
    function ToSQL: string;

    { Onda S4 (ADITIVO) - eixo FULL - ver comentario completo em
      Databases.Interfaces.ITables. }
    function ToFullJSON: string;
    function FromFullJSON(const AJSON: string): ITables;
    function MergeFullFromJSON(const AJSON: string): ITables;
    function Export(const AWithData: Boolean): string;
    function Import(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): ITables;
  end;

implementation

uses
{$IF DEFINED(FPC)}
  jsonparser,
{$ENDIF}
  Database.Table,
  Database.Helpers.JSON
{$IFDEF USE_DATABASE}
  , Database.Dialect
  , Database.CatalogReader    // motor de catalogo centralizado (SSOT) - TableExists/introspeccao
{$ENDIF}
  ;

{ Helpers de parsing JSON (Fatia B-c, Onda 4-cont) - duplicados localmente
  (mesma tecnica ja usada em Database.Field.pas/Database.Table.pas, nao
  exportados por aquelas units). }

{ Procura AKey (case-insensitive) num objeto JSON ja parseado; nil se ausente. }
{$IF DEFINED(FPC)}
function TablesFindNode(const AObj: TJSONObject; const AKey: string): TJSONData;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Pred(AObj.Count) do
    if CompareText(AObj.Names[I], AKey) = 0 then
    begin
      Result := AObj.Items[I];
      Exit;
    end;
end;
{$ELSE}
function TablesFindNode(const AObj: TJSONObject; const AKey: string): TJSONValue;
var
  LPair: TJSONPair;
begin
  Result := nil;
  for LPair in AObj do
    if CompareText(LPair.JsonString.Value, AKey) = 0 then
    begin
      Result := LPair.JsonValue;
      Exit;
    end;
end;
{$ENDIF}

{ Converte o node JSON (ja localizado) para Variant - usado so para comparar o
  valor da coluna PK do JSON de entrada com o valor corrente do registo em
  FList (VarToStr dos 2 lados). Implementacao duplicada por compilador (mesmo
  padrao de Database.Table.pas.TableJSONNodeToVariant). }
{$IF DEFINED(FPC)}
function TablesJSONNodeToVariant(ANode: TJSONData): Variant;
var
  LFloat: Double;
begin
  if (not Assigned(ANode)) or (ANode.JSONType = jtNull) then
    Result := Null
  else
    case ANode.JSONType of
      jtBoolean:
        Result := ANode.AsBoolean;
      jtNumber:
        begin
          LFloat := ANode.AsFloat;
          if Frac(LFloat) = 0 then
            Result := ANode.AsInt64
          else
            Result := LFloat;
        end;
    else
      Result := ANode.AsString;
    end;
end;
{$ELSE}
function TablesJSONNodeToVariant(ANode: TJSONValue): Variant;
var
  LFloat: Double;
  LBool: Boolean;
begin
  if (not Assigned(ANode)) or (ANode is TJSONNull) then
    Result := Null
  else if ANode is TJSONNumber then
  begin
    LFloat := TJSONNumber(ANode).AsDouble;
    if Frac(LFloat) = 0 then
      Result := TJSONNumber(ANode).AsInt64
    else
      Result := LFloat;
  end
  else if ANode.TryGetValue<Boolean>(LBool) then
    Result := LBool
  else if ANode is TJSONString then
    Result := TJSONString(ANode).Value
  else
    Result := ANode.Value;
end;
{$ENDIF}

procedure SyncTableListFromTable(var AItem: TTableList; const ATable: ITable; AIndex: Integer);
begin
  AItem.index := AIndex;
  AItem.table := ATable;
  AItem.tablename := ATable.TableName;
  AItem.alias := ATable.Alias;
  AItem.auditFields := ATable.AuditFields;
  AItem.fieldDateCreated := ATable.FieldDateCreated;
  AItem.fieldDateUpdated := ATable.FieldDateUpdated;
  AItem.fieldIsDeleted := ATable.FieldIsDeleted;
  AItem.fieldIsActive := ATable.FieldIsActive;
end;

function TTables.IndexOfTable(const AName: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(FList) do
    if CompareText(FList[i].tablename, AName) = 0 then
    begin
      Result := i;
      Exit;
    end;
end;

constructor TTables.Create;
begin
  inherited Create;
  SetLength(FList, 0);
  FDatabaseTypes := dtNone;
end;

destructor TTables.Destroy;
begin
  SetLength(FList, 0);
  inherited;
end;

class function TTables.New: ITables;
begin
  Result := TTables.Create;
end;

function TTables.Connection(const AConnection: IConnection): ITables;
begin
  FConnection := AConnection;
  Result := Self;
end;

function TTables.Connection: IConnection;
begin
  Result := FConnection;
end;

function TTables.DatabaseTypes(const AValue: TDatabaseTypes): ITables;
begin
  FDatabaseTypes := AValue;
  Result := Self;
end;

function TTables.DatabaseTypes: TDatabaseTypes;
begin
  Result := FDatabaseTypes;
end;

function TTables.Database(const AValue: string): ITables;
begin
  FDatabase := AValue;
  Result := Self;
end;

function TTables.Database: string;
begin
  Result := FDatabase;
end;

function TTables.Schema(const AValue: string): ITables;
begin
  FSchema := AValue;
  Result := Self;
end;

function TTables.Schema: string;
begin
  Result := FSchema;
end;

function TTables.SetOnLoadTablesProgress(const AValue: TOnLoadTablesProgress): ITables;
begin
  FOnLoadTablesProgress := AValue;
  Result := Self;
end;

function TTables.SetOnLoadFieldsProgress(const AValue: TOnLoadFieldsProgress): ITables;
begin
  FOnLoadFieldsProgress := AValue;
  Result := Self;
end;

{ M2 (conformidade F5 C4): as "portas publicas" de descoberta deste container
  ITables passam a DELEGAR ao motor de catalogo UNICO TCatalogReader (SSOT -
  hierarquia "muitas portas publicas, um so motor", regra transversal 14) em vez
  do FConnection.Get* cru: ganham o filtro de objectos de sistema (IsSystemObject,
  default IncludeSystemObjects=False) + o enriquecimento (Description/IsIdentity
  no TableStructure), tal como ja faziam ITable/Views/Procedures. Sob USE_DATABASE
  OFF caem no FConnection cru (fallback, sem TCatalogReader disponivel). }
function TTables.GetTableNames(const ASchema: string): TStringArray;
begin
  SetLength(Result, 0);
  if not Assigned(FConnection) then Exit;
{$IFDEF USE_DATABASE}
  Result := TCatalogReader.New(FConnection).TableNames(ASchema);
{$ELSE}
  Result := FConnection.GetTableNames(ASchema);
{$ENDIF}
end;

function TTables.GetDatabaseNames: TStringArray;
begin
  SetLength(Result, 0);
  if not Assigned(FConnection) then Exit;
{$IFDEF USE_DATABASE}
  Result := TCatalogReader.New(FConnection).DatabaseNames;
{$ELSE}
  Result := FConnection.GetDatabaseNames;
{$ENDIF}
end;

function TTables.GetSchemaNames(const ADatabase: string): TStringArray;
begin
  SetLength(Result, 0);
  if not Assigned(FConnection) then Exit;
{$IFDEF USE_DATABASE}
  Result := TCatalogReader.New(FConnection).SchemaNames(ADatabase);
{$ELSE}
  Result := FConnection.GetSchemaNames(ADatabase);
{$ENDIF}
end;

function TTables.GetColumnNames(const ATableName: string; const ASchema: string): TStringArray;
begin
  SetLength(Result, 0);
  if not Assigned(FConnection) then Exit;
{$IFDEF USE_DATABASE}
  Result := TCatalogReader.New(FConnection).ColumnNames(ATableName, ASchema);
{$ELSE}
  Result := FConnection.GetColumnNames(ATableName, ASchema);
{$ENDIF}
end;

function TTables.GetTableStructure(const ATableName: string; const ASchema: string): TArray<TDatabaseFields>;
begin
  SetLength(Result, 0);
  if not Assigned(FConnection) then Exit;
{$IFDEF USE_DATABASE}
  Result := TCatalogReader.New(FConnection).TableStructure(ATableName, ASchema);
{$ELSE}
  Result := FConnection.GetTableStructure(ATableName, ASchema);
{$ENDIF}
end;

{ ===== R2.2 (f5-repair) - manipulacao IMPERATIVA de TABELA (por nome) neste
  container - mesma logica de TSchema.DropTableSQL/RenameTableSQL/DropTable/
  RenameTable (Database.Schema.pas), trocando SchemaName (proprio de TSchema)
  pelo getter Schema ja existente em TTables. <Op>TableSQL monta via a
  faceta IDialect.Table (dialecto por DatabaseTypes); <Op>Table(conn) executa
  e e IDEMPOTENTE (consulta ICatalogReader.TableExists). Gated USE_DATABASE. }

function TTables.DropTableSQL(const ATableName: string): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (Trim(ATableName) = '') or (DatabaseTypes = dtNone) then Exit;
  Result := TDialect.ForDatabaseType(DatabaseTypes).Table.DropSQL(Trim(ATableName), Schema, True);
{$ENDIF}
end;

function TTables.RenameTableSQL(const AOldName, ANewName: string): string;
begin
  Result := '';
{$IFDEF USE_DATABASE}
  if (Trim(AOldName) = '') or (Trim(ANewName) = '') or (DatabaseTypes = dtNone) then Exit;
  Result := TDialect.ForDatabaseType(DatabaseTypes).Table.RenameSQL(Trim(AOldName), Trim(ANewName));
{$ENDIF}
end;

function TTables.DropTable(const AConnection: IConnection; const ATableName: string): Integer;
{$IFDEF USE_DATABASE}
var
  LSQL: string;
{$ENDIF}
begin
  Result := 0;
{$IFDEF USE_DATABASE}
  if (AConnection = nil) or not AConnection.IsConnected then Exit;
  if Trim(ATableName) = '' then Exit;
  { idempotente: so remove se a tabela existir (introspecao live) }
  if not TCatalogReader.New(AConnection).TableExists(Trim(ATableName), Schema) then Exit;
  LSQL := TDialect.ForConnection(AConnection).Table.DropSQL(Trim(ATableName), Schema, True);
  if Trim(LSQL) <> '' then Result := AConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

function TTables.RenameTable(const AConnection: IConnection; const AOldName, ANewName: string): Integer;
{$IFDEF USE_DATABASE}
var
  LMeta: ICatalogReader;
  LSQL: string;
{$ENDIF}
begin
  Result := 0;
{$IFDEF USE_DATABASE}
  if (AConnection = nil) or not AConnection.IsConnected then Exit;
  if (Trim(AOldName) = '') or (Trim(ANewName) = '') then Exit;
  { so renomeia se a origem existir E o destino ainda NAO }
  LMeta := TCatalogReader.New(AConnection);
  if not LMeta.TableExists(Trim(AOldName), Schema) then Exit;
  if LMeta.TableExists(Trim(ANewName), Schema) then Exit;
  LSQL := TDialect.ForConnection(AConnection).Table.RenameSQL(Trim(AOldName), Trim(ANewName));
  if Trim(LSQL) <> '' then Result := AConnection.ExecuteCommand(LSQL);
{$ENDIF}
end;

function TTables.LoadFromConnection(const ASchema: string): ITables;
var
  LNames: TStringArray;
  LCols: TStringArray;
  i, j, L: Integer;
  LTable: ITable;
begin
  SetLength(FList, 0);
  if Assigned(FConnection) then
  begin
    LNames := GetTableNames(ASchema);
    for i := 0 to Length(LNames) - 1 do
    begin
      if Assigned(FOnLoadTablesProgress) then
        FOnLoadTablesProgress(i + 1, Length(LNames), LNames[i]);
      LCols := GetColumnNames(LNames[i], ASchema);
      for j := 0 to Length(LCols) - 1 do
      begin
        if Assigned(FOnLoadFieldsProgress) then
          FOnLoadFieldsProgress(LNames[i], j + 1, Length(LCols), LCols[j]);
      end;
      LTable := TTable.New;
      LTable.TableName(LNames[i]);
      { M3 (conformidade F5 C4): liga a ITable carregada ao motor (Connection +
        DatabaseTypes) para que ela possa DETALHAR-SE on demand (TableStructure/
        ColumnExists/introspeccao, que ja delegam ao TCatalogReader/SSOT) em vez
        de sair "cega" com 0 campos E sem forma de os obter. Mantem o carregamento
        LEVE (a coleccao LISTA; a ITable singular detalha-se por PEDIDO - hierarquia
        coleccao/singular), sem N structure-queries eager que penalizariam o
        TableExists do F7 (unico consumidor externo: Parameters.Database.pas). }
      LTable.Connection(FConnection);
      LTable.DatabaseTypes(FConnection.DatabaseType);
      L := Length(FList);
      SetLength(FList, L + 1);
      SyncTableListFromTable(FList[L], LTable, L);
    end;
  end;
  Result := Self;
end;

function TTables.LoadTables: ITables;
begin
  Result := LoadFromConnection;
end;

function TTables.Table(const AName: string): ITable;
var
  i: Integer;
begin
  Result := nil;
  i := IndexOfTable(AName);
  if i >= 0 then
    Result := FList[i].table;
end;

function TTables.GetTablesList: TTableArray;
var
  i: Integer;
begin
  SetLength(Result, Length(FList));
  for i := 0 to High(FList) do
    Result[i] := FList[i].table;
end;

function TTables.TablesCount: Integer;
begin
  Result := Length(FList);
end;

function TTables.TableExists(const AName: string): Boolean;
begin
  Result := IndexOfTable(AName) >= 0;
end;

function TTables.HasChanges: Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(FList) do
    if FList[i].table.HasChanges then
    begin
      Result := True;
      Exit;
    end;
end;

function TTables.ClearAllChanges: ITables;
var
  i: Integer;
begin
  for i := 0 to High(FList) do
    FList[i].table.ClearAllChanges;
  Result := Self;
end;

function TTables.ToSQL: string;
var
  i: Integer;
  LStmt: string;
begin
  { Onda S3 - orquestra ITable.ToSQL de cada elemento (zero SQL novo); ver
    comentario completo em Databases.Interfaces.ITables.ToSQL. }
  Result := '';
  for i := 0 to High(FList) do
  begin
    LStmt := Trim(FList[i].table.ToSQL);
    if LStmt = '' then
      Continue;
    if Result <> '' then
      Result := Result + sLineBreak;
    Result := Result + LStmt + ';';
  end;
end;

function TTables.ToJSON: string;
var
  i: Integer;
begin
  Result := '[';
  for i := 0 to High(FList) do
  begin
    if i > 0 then Result := Result + ',';
    Result := Result + FList[i].table.ToJSON;
  end;
  Result := Result + ']';
end;

{ Adiciona um novo registo a FList hidratado a partir de AItemJSON (eixo
  dado). Clona a ESTRUTURA de FList[0] (round-trip StructureToJSON->
  StructureFromJSON) quando ja existe pelo menos 1 registo - assim os campos
  existem antes da hidratacao por nome (FromJSON/MergeFromJSON de ITable
  nunca criam campos novos). Compilador-agnostico (sem parsing JSON direto). }
function TTables.AddRowFromJSON(const AItemJSON: string; const AMerge: Boolean): Integer;
var
  LNewTable: ITable;
begin
  LNewTable := TTable.New;
  if Length(FList) > 0 then
    LNewTable.StructureFromJSON(FList[0].table.StructureToJSON);
  if AMerge then
    LNewTable.MergeFromJSON(AItemJSON)
  else
    LNewTable.FromJSON(AItemJSON);
  Result := Length(FList);
  SetLength(FList, Result + 1);
  SyncTableListFromTable(FList[Result], LNewTable, Result);
end;

function TTables.FindMatchIndex(const AItem: TJSONObject): Integer;
{$IF DEFINED(FPC)}
var
  I: Integer;
  LPk: IField;
  LNode: TJSONData;
begin
  Result := -1;
  for I := 0 to High(FList) do
  begin
    LPk := FList[I].table.GetPrimaryKey;
    if LPk = nil then
      Continue;
    LNode := TablesFindNode(AItem, LPk.Column);
    if not Assigned(LNode) then
      Continue;
    if VarToStr(TablesJSONNodeToVariant(LNode)) = VarToStr(LPk.Value) then
    begin
      Result := I;
      Exit;
    end;
  end;
end;
{$ELSE}
var
  I: Integer;
  LPk: IField;
  LNode: TJSONValue;
begin
  Result := -1;
  for I := 0 to High(FList) do
  begin
    LPk := FList[I].table.GetPrimaryKey;
    if LPk = nil then
      Continue;
    LNode := TablesFindNode(AItem, LPk.Column);
    if not Assigned(LNode) then
      Continue;
    if VarToStr(TablesJSONNodeToVariant(LNode)) = VarToStr(LPk.Value) then
    begin
      Result := I;
      Exit;
    end;
  end;
end;
{$ENDIF}

function TTables.ImportJSON(const AJSON: string; const AMerge: Boolean): ITables;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LArr: TJSONArray;
  LItem: TJSONObject;
  I, LIdx: Integer;
  LState: string;
  LStateNode: TJSONData;
begin
  { Arvore de import por object_state (Fatia B-c): INSERTED->adiciona novo;
    UNMODIFIED->nao edita (sem ramo - cai no "else" implicito, sem accao);
    MODIFIED->localiza por PK e edita (se nao achar, adiciona); DELETED->
    localiza e marca (Status=dsDeleted, via ITable.FromJSON/MergeFromJSON que
    ja aplica object_state->Status). AMerge=False usa ITable.FromJSON
    (replace); AMerge=True usa ITable.MergeFromJSON (patch). }
  Result := Self;
  if Trim(AJSON) = '' then
    Exit;
  LData := GetJSON(AJSON);
  if (not Assigned(LData)) or (not (LData is TJSONArray)) then
  begin
    if Assigned(LData) then
      LData.Free;
    Exit;
  end;
  LArr := TJSONArray(LData);
  try
    for I := 0 to Pred(LArr.Count) do
    begin
      if not (LArr.Items[I] is TJSONObject) then
        Continue;
      LItem := TJSONObject(LArr.Items[I]);
      LState := 'UNMODIFIED';
      LStateNode := TablesFindNode(LItem, 'object_state');
      if Assigned(LStateNode) then
        LState := LStateNode.AsString;
      LIdx := FindMatchIndex(LItem);
      if CompareText(LState, 'INSERTED') = 0 then
        AddRowFromJSON(LItem.AsJSON, AMerge)
      else if CompareText(LState, 'MODIFIED') = 0 then
      begin
        if LIdx >= 0 then
        begin
          if AMerge then
            FList[LIdx].table.MergeFromJSON(LItem.AsJSON)
          else
            FList[LIdx].table.FromJSON(LItem.AsJSON);
        end
        else
          AddRowFromJSON(LItem.AsJSON, AMerge);
      end
      else if CompareText(LState, 'DELETED') = 0 then
      begin
        if LIdx >= 0 then
        begin
          if AMerge then
            FList[LIdx].table.MergeFromJSON(LItem.AsJSON)
          else
            FList[LIdx].table.FromJSON(LItem.AsJSON);
        end;
      end;
    end;
  finally
    LArr.Free;
  end;
end;
{$ELSE}
var
  LVal: TJSONValue;
  LArr: TJSONArray;
  LItem: TJSONObject;
  I, LIdx: Integer;
  LState: string;
  LStateNode: TJSONValue;
begin
  Result := Self;
  if Trim(AJSON) = '' then
    Exit;
  LVal := TJSONObject.ParseJSONValue(AJSON);
  if (not Assigned(LVal)) or (not (LVal is TJSONArray)) then
  begin
    if Assigned(LVal) then
      LVal.Free;
    Exit;
  end;
  LArr := TJSONArray(LVal);
  try
    for I := 0 to Pred(LArr.Count) do
    begin
      if not (LArr.Items[I] is TJSONObject) then
        Continue;
      LItem := TJSONObject(LArr.Items[I]);
      LState := 'UNMODIFIED';
      LStateNode := TablesFindNode(LItem, 'object_state');
      if Assigned(LStateNode) then
        LState := LStateNode.Value;
      LIdx := FindMatchIndex(LItem);
      if CompareText(LState, 'INSERTED') = 0 then
        AddRowFromJSON(LItem.ToJSON, AMerge)
      else if CompareText(LState, 'MODIFIED') = 0 then
      begin
        if LIdx >= 0 then
        begin
          if AMerge then
            FList[LIdx].table.MergeFromJSON(LItem.ToJSON)
          else
            FList[LIdx].table.FromJSON(LItem.ToJSON);
        end
        else
          AddRowFromJSON(LItem.ToJSON, AMerge);
      end
      else if CompareText(LState, 'DELETED') = 0 then
      begin
        if LIdx >= 0 then
        begin
          if AMerge then
            FList[LIdx].table.MergeFromJSON(LItem.ToJSON)
          else
            FList[LIdx].table.FromJSON(LItem.ToJSON);
        end;
      end;
    end;
  finally
    LArr.Free;
  end;
end;
{$ENDIF}

function TTables.FromJSON(const AJSON: string): ITables;
begin
  Result := ImportJSON(AJSON, False);
end;

function TTables.MergeFromJSON(const AJSON: string): ITables;
begin
  Result := ImportJSON(AJSON, True);
end;

function TTables.StructureToJSON: string;
var
  I: Integer;
begin
  { EIXO ESTRUTURA PROPRIO da Tables (Fatia B-c) - array com um
    ITable.StructureToJSON por elemento. }
  Result := '[';
  for I := 0 to High(FList) do
  begin
    if I > 0 then
      Result := Result + ',';
    Result := Result + FList[I].table.StructureToJSON;
  end;
  Result := Result + ']';
end;

function TTables.StructureFromJSON(const AJSON: string): ITables;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LArr: TJSONArray;
  I: Integer;
  LTable: ITable;
begin
  { EIXO ESTRUTURA PROPRIO da Tables (Fatia B-c) - reconstroi FList por
    completo (substitui) - um ITable por elemento, via
    ITable.StructureFromJSON. }
  Result := Self;
  if Trim(AJSON) = '' then
    Exit;
  LData := GetJSON(AJSON);
  if (not Assigned(LData)) or (not (LData is TJSONArray)) then
  begin
    if Assigned(LData) then
      LData.Free;
    Exit;
  end;
  LArr := TJSONArray(LData);
  try
    SetLength(FList, 0);
    for I := 0 to Pred(LArr.Count) do
    begin
      LTable := TTable.New;
      LTable.StructureFromJSON(LArr.Items[I].AsJSON);
      SetLength(FList, Length(FList) + 1);
      SyncTableListFromTable(FList[High(FList)], LTable, High(FList));
    end;
  finally
    LArr.Free;
  end;
end;
{$ELSE}
var
  LVal: TJSONValue;
  LArr: TJSONArray;
  I: Integer;
  LTable: ITable;
begin
  Result := Self;
  if Trim(AJSON) = '' then
    Exit;
  LVal := TJSONObject.ParseJSONValue(AJSON);
  if (not Assigned(LVal)) or (not (LVal is TJSONArray)) then
  begin
    if Assigned(LVal) then
      LVal.Free;
    Exit;
  end;
  LArr := TJSONArray(LVal);
  try
    SetLength(FList, 0);
    for I := 0 to Pred(LArr.Count) do
    begin
      LTable := TTable.New;
      LTable.StructureFromJSON(LArr.Items[I].ToJSON);
      SetLength(FList, Length(FList) + 1);
      SyncTableListFromTable(FList[High(FList)], LTable, High(FList));
    end;
  finally
    LArr.Free;
  end;
end;
{$ENDIF}

function TTables.StructureMergeFromJSON(const AJSON: string): ITables;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LArr: TJSONArray;
  I, LIdx: Integer;
  LItemObj: TJSONObject;
  LTableName: string;
  LTable: ITable;
begin
  { Onda S2-a (ADITIVO) - PATCH aditivo POR NOME de tabela (TableName), ao
    contrario de StructureFromJSON (que substitui FList por completo): para
    cada elemento do array, se ja existe uma ITable com esse "table" (via
    IndexOfTable, case-insensitive), aplica ITable.StructureMergeFromJSON
    nela (patch dos campos dessa tabela); se nao existe, cria via
    TTable.New + StructureFromJSON (semeia directamente) e adiciona ao
    FList. NUNCA remove uma tabela existente que nao apareca no JSON de
    entrada. }
  Result := Self;
  if Trim(AJSON) = '' then
    Exit;
  LData := GetJSON(AJSON);
  if (not Assigned(LData)) or (not (LData is TJSONArray)) then
  begin
    if Assigned(LData) then
      LData.Free;
    Exit;
  end;
  LArr := TJSONArray(LData);
  try
    for I := 0 to Pred(LArr.Count) do
    begin
      if not (LArr.Items[I] is TJSONObject) then
        Continue;
      LItemObj := TJSONObject(LArr.Items[I]);
      LTableName := LItemObj.Get('table', '');
      LIdx := IndexOfTable(LTableName);
      if LIdx >= 0 then
        FList[LIdx].table.StructureMergeFromJSON(LItemObj.AsJSON)
      else
      begin
        LTable := TTable.New;
        LTable.StructureFromJSON(LItemObj.AsJSON);
        SetLength(FList, Length(FList) + 1);
        SyncTableListFromTable(FList[High(FList)], LTable, High(FList));
      end;
    end;
  finally
    LArr.Free;
  end;
end;
{$ELSE}
var
  LVal: TJSONValue;
  LArr: TJSONArray;
  I, LIdx: Integer;
  LItemObj: TJSONObject;
  LTableName: string;
  LTable: ITable;
begin
  Result := Self;
  if Trim(AJSON) = '' then
    Exit;
  LVal := TJSONObject.ParseJSONValue(AJSON);
  if (not Assigned(LVal)) or (not (LVal is TJSONArray)) then
  begin
    if Assigned(LVal) then
      LVal.Free;
    Exit;
  end;
  LArr := TJSONArray(LVal);
  try
    for I := 0 to Pred(LArr.Count) do
    begin
      if not (LArr.Items[I] is TJSONObject) then
        Continue;
      LItemObj := TJSONObject(LArr.Items[I]);
      LTableName := LItemObj.GetValue<string>('table', '');
      LIdx := IndexOfTable(LTableName);
      if LIdx >= 0 then
        FList[LIdx].table.StructureMergeFromJSON(LItemObj.ToJSON)
      else
      begin
        LTable := TTable.New;
        LTable.StructureFromJSON(LItemObj.ToJSON);
        SetLength(FList, Length(FList) + 1);
        SyncTableListFromTable(FList[High(FList)], LTable, High(FList));
      end;
    end;
  finally
    LArr.Free;
  end;
end;
{$ENDIF}

function TTables.ToFullJSON: string;
begin
  { Onda S4 (ADITIVO) - COMPOE os 2 eixos JA EXISTENTES (StructureToJSON/
    ToJSON), sem reimplementar nenhum dos 2. }
  Result := '{"structure":' + StructureToJSON + ',"data":' + ToJSON + '}';
end;

function TTables.FromFullJSON(const AJSON: string): ITables;
var
  LStructure, LData: string;
begin
  { Onda S4 (ADITIVO) - decompoe via JSONExtractMember (SSOT, Database.
    Helpers.JSON) e delega, NESTA ORDEM (estrutura antes de dado - o eixo
    dado deste container reconcilia por PK sobre o FList JA CONSTRUIDO pelo
    eixo estrutura), a StructureFromJSON/FromJSON ja existentes. Tolerante:
    chave ausente nao aplica esse eixo. }
  Result := Self;
  LStructure := JSONExtractMember(AJSON, 'structure');
  if LStructure <> '' then
    StructureFromJSON(LStructure);
  LData := JSONExtractMember(AJSON, 'data');
  if LData <> '' then
    FromJSON(LData);
end;

function TTables.MergeFullFromJSON(const AJSON: string): ITables;
var
  LStructure, LData: string;
begin
  { Onda S4 (ADITIVO) - mesma decomposicao/ordem de FromFullJSON, delegando
    aos "patch" StructureMergeFromJSON/MergeFromJSON. }
  Result := Self;
  LStructure := JSONExtractMember(AJSON, 'structure');
  if LStructure <> '' then
    StructureMergeFromJSON(LStructure);
  LData := JSONExtractMember(AJSON, 'data');
  if LData <> '' then
    MergeFromJSON(LData);
end;

function TTables.Export(const AWithData: Boolean): string;
begin
  { Onda S4 (ADITIVO) - atalho ergonomico: False -> so ESTRUTURA; True ->
    FULL (estrutura+dado). }
  if AWithData then
    Result := ToFullJSON
  else
    Result := StructureToJSON;
end;

function TTables.Import(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): ITables;
begin
  { Onda S4 (ADITIVO) - despacha pelas 2 flags para o metodo To/From/Merge
    ja existente correspondente. }
  Result := Self;
  if AWithData then
  begin
    if AMerge then
      MergeFullFromJSON(AJSON)
    else
      FromFullJSON(AJSON);
  end
  else
  begin
    if AMerge then
      StructureMergeFromJSON(AJSON)
    else
      StructureFromJSON(AJSON);
  end;
end;

end.
