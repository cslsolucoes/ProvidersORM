{ =============================================================================
  Databases - Container de bancos (TDatabases, IDatabases)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.3.0
  FileVersion:    1.4.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           30/07/2026

  FASE 5 Onda 4-cont (revisao F5), Fatia B-e (ULTIMA fatia da Fatia B) - ver
  comentario completo em Databases.Interfaces.IDatabases.
  ToJSON/FromJSON/MergeFromJSON/StructureToJSON/StructureFromJSON delegam
  integralmente ao IDatabase de cada elemento de FList (que, por sua vez,
  ja delega a ISchemas por SchemaName - Fatia B-d). Sem covariancia
  (IDatabases nao herda IDatabase/ISchemas/ITables/IFields) - nenhuma
  clausula de resolucao de interface necessaria. Helper local de escaping
  RFC 8259 (DatabasesJSONQuoteString) - mesma tecnica dos escapers das
  fatias anteriores, duplicado localmente; NUNCA QuotedStr para JSON
  (bug-293).

  NOMENCLATURA (ordem do owner, 14/07): "Databases" e o plural do conceito
  RAIZ "Database" - fica SEM o prefixo "Database." (reservado a
  sub-conceitos como Database.Table/Database.Field/Database.Schema). Por
  isso a unit chama-se "Databases", NAO "Database.Databases".

  Changelog (file):
  - 1.4.0 (30/07/2026): Onda S3b (ADITIVO - materializacao do merge, ver
    Databases.Interfaces 3.3.0) - ApplyStructure(AConnection): IDatabases
    agrega o IDatabase.ApplyStructure de cada banco de FList; zero SQL novo,
    so orquestracao trivial (mesmo padrao de ToDDL, acima).
  - 1.3.0 (30/07/2026): Onda S4 (ADITIVO - eixo FULL, ver Databases.Interfaces
    3.2.0) - ToFullJSON (COMPOE StructureToJSON+ToJSON)/FromFullJSON/
    MergeFullFromJSON (decompoem via Database.Helpers.JSON.JSONExtractMember,
    estrutura antes de dado - ja usava Database.Helpers.JSON, sem uses novo)
    + Export(AWithData)/Import(AJSON, AWithData, AMerge) ergonomicos, SEM
    overload de AQuery:IQueryBuilder (reservada a ITable/ISchema/IDatabase).
    Sem covariancia (IDatabases nao herda IDatabase/ISchemas/ITables/
    IFields) - declaracao directa. Zero mudanca nos metodos pre-existentes.
  - 1.2.0 (29/07/2026): Onda S3 (ADITIVO - eixo SQL, ver Databases.Interfaces
    3.1.0) - ToDDL: string (agrega o IDatabase.ToDDL de cada banco de FList;
    zero SQL novo, so orquestracao trivial - mesmo padrao ja usado por
    ToJSON/StructureToJSON, que delegam integralmente a cada IDatabase).
  - 1.1.0 (29/07/2026): Onda S2-a (ADITIVO, simetria To/From/Merge) -
    IDatabases ganha StructureMergeFromJSON - PATCH aditivo: localiza (ou
    CRIA, nunca remove) o IDatabase pelo DatabaseName de cada elemento de
    "databases" e delega a IDatabase.StructureMergeFromJSON nesse banco. Ao
    contrario de StructureFromJSON (FList.Clear + reconstroi tudo), esta
    versao preserva os bancos existentes. Zero mudanca nos metodos
    pre-existentes.
  - 1.0.2 (27/07/2026): conformidade F5 (onda C5, M7) - DatabasesJSONQuoteString
    local removida; delega ao SSOT unico Database.Helpers.JSON.JSONQuoteString.
  - 1.0.1 (25/07/2026): R2.6 (f5-repair, Onda R2 - re-layering por
    responsabilidade) - ADITIVO: IDatabases ganha DatabaseNames: TStringArray
    - delega a TCatalogReader.New(FConnection).DatabaseNames (mesmo padrao de
    degradacao de LoadDatabasesFromConnection, acima - vazio se USE_DATABASE
    OFF/sem Connection/conexao nao ligada). Sem uses novo - Database.CatalogReader
    ja estava na seccao implementation (gated USE_DATABASE).
  - 1.0.0 (14/07/2026): versao inicial (Fatia B-e).
  ============================================================================= }
unit Databases;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}
interface

{$I ../../ORM.Defines.inc}

uses
{$IF DEFINED(FPC)}
  SysUtils, Classes, Generics.Collections,
{$ELSE}
  System.SysUtils, System.Classes, System.Generics.Collections,
{$ENDIF}
  Commons.Types,
  Databases.Interfaces,
  Connections.Interfaces;

type
  TDatabases = class(TInterfacedObject, IDatabases)
  private
    FList: TList<IDatabase>;
    FConnection: IConnection;
    function IndexOfDatabase(const AName: string): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: IDatabases;
    function Connection(const AConnection: IConnection): IDatabases; overload;
    function Connection: IConnection; overload;
    function Add(const ADatabase: IDatabase): IDatabases;
    function Database(const AName: string): IDatabase;
    function GetDatabasesList: TDatabaseArray;
    function DatabasesCount: Integer;
    function DatabaseExists(const AName: string): Boolean;
    function LoadDatabasesFromConnection: IDatabases;
    { R2.6 (f5-repair) - ver comentario completo em
      Databases.Interfaces.IDatabases.DatabaseNames. }
    function DatabaseNames: TStringArray;

    { Serialize PROPRIA da Databases (Fatia B-e) - ver comentario completo
      em Databases.Interfaces.IDatabases. Sem covariancia (IDatabases nao
      herda IDatabase/ISchemas/ITables/IFields) - declaracao directa, sem
      clausula de resolucao de interface. }
    function ToJSON: string;
    function FromJSON(const AJSON: string): IDatabases;
    function MergeFromJSON(const AJSON: string): IDatabases;
    function StructureToJSON: string;
    function StructureFromJSON(const AJSON: string): IDatabases;
    { Onda S2-a (ADITIVO) - ver comentario completo em
      Databases.Interfaces.IDatabases.StructureMergeFromJSON. }
    function StructureMergeFromJSON(const AJSON: string): IDatabases;
    { Onda S3 - eixo SQL - ver comentario completo em
      Databases.Interfaces.IDatabases.ToDDL. }
    function ToDDL: string;

    { Onda S3b (ADITIVO) - MATERIALIZACAO do merge - ver comentario completo
      em Databases.Interfaces.IDatabases.ApplyStructure. }
    function ApplyStructure(const AConnection: IConnection): IDatabases;

    { Onda S4 (ADITIVO) - eixo FULL - ver comentario completo em
      Databases.Interfaces.IDatabases. }
    function ToFullJSON: string;
    function FromFullJSON(const AJSON: string): IDatabases;
    function MergeFullFromJSON(const AJSON: string): IDatabases;
    function Export(const AWithData: Boolean): string;
    function Import(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): IDatabases;
  end;

implementation

uses
{$IF DEFINED(FPC)}
  fpjson, jsonparser,
{$ELSE}
  System.JSON,
{$ENDIF}
  Database,
  Database.Helpers.JSON
{$IFDEF USE_DATABASE}
  , Database.CatalogReader
{$ENDIF}
  ;

{ Escaper RFC 8259 - Onda C5 (M7, conformidade F5): delega ao SSOT unico
  Database.Helpers.JSON.JSONQuoteString (antes era uma copia local
  DatabasesJSONQuoteString - regra #14). Usado so para as CHAVES do objeto
  chave-nomeada (DatabaseName) - os VALORES sao sempre delegados a
  IDatabase.ToJSON/StructureToJSON de cada banco, que ja escapam por conta
  propria. }

function TDatabases.IndexOfDatabase(const AName: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to FList.Count - 1 do
    if CompareText(FList.Items[i].DatabaseName, AName) = 0 then
    begin
      Result := i;
      Exit;
    end;
end;

constructor TDatabases.Create;
begin
  inherited Create;
  FList := TList<IDatabase>.Create;
end;

destructor TDatabases.Destroy;
begin
  FList.Free;
  inherited;
end;

class function TDatabases.New: IDatabases;
begin
  Result := TDatabases.Create;
end;

function TDatabases.Connection(const AConnection: IConnection): IDatabases;
begin
  FConnection := AConnection;
  Result := Self;
end;

function TDatabases.Connection: IConnection;
begin
  Result := FConnection;
end;

function TDatabases.Add(const ADatabase: IDatabase): IDatabases;
begin
  if ADatabase <> nil then
    FList.Add(ADatabase);
  Result := Self;
end;

function TDatabases.Database(const AName: string): IDatabase;
var
  i: Integer;
begin
  Result := nil;
  i := IndexOfDatabase(AName);
  if i >= 0 then
    Result := FList.Items[i];
end;

function TDatabases.GetDatabasesList: TDatabaseArray;
var
  i: Integer;
begin
  SetLength(Result, FList.Count);
  for i := 0 to FList.Count - 1 do
    Result[i] := FList.Items[i];
end;

function TDatabases.DatabasesCount: Integer;
begin
  Result := FList.Count;
end;

function TDatabases.DatabaseExists(const AName: string): Boolean;
begin
  Result := IndexOfDatabase(AName) >= 0;
end;

function TDatabases.LoadDatabasesFromConnection: IDatabases;
{$IFDEF USE_DATABASE}
var
  LMeta: ICatalogReader;
  LNames: TStringArray;
  I: Integer;
  LDb: IDatabase;
{$ENDIF}
begin
  Result := Self;
  FList.Clear;
{$IFDEF USE_DATABASE}
  if (FConnection = nil) or not FConnection.IsConnected then
    Exit;
  LMeta := TCatalogReader.New(FConnection);
  LNames := LMeta.DatabaseNames;
  for I := 0 to High(LNames) do
  begin
    LDb := TDatabase.New(FConnection).DatabaseName(LNames[I]);
    LDb.LoadSchemasFromConnection;
    FList.Add(LDb);
  end;
{$ENDIF}
end;

{ R2.6 (f5-repair) - lista os nomes de banco via ICatalogReader.DatabaseNames
  (Connection-bound); vazio se USE_DATABASE estiver OFF, sem Connection
  injectada, ou conexao nao ligada (mesmo padrao de degradacao de
  LoadDatabasesFromConnection, acima). }
function TDatabases.DatabaseNames: TStringArray;
begin
  SetLength(Result, 0);
{$IFDEF USE_DATABASE}
  if (FConnection = nil) or not FConnection.IsConnected then Exit;
  Result := TCatalogReader.New(FConnection).DatabaseNames;
{$ENDIF}
end;

function TDatabases.ToDDL: string;
var
  i: Integer;
  LStmt: string;
begin
  { Onda S3 - agrega o IDatabase.ToDDL de cada banco (zero SQL novo, so
    orquestracao); ver comentario completo em Databases.Interfaces.IDatabases.
    ToDDL. }
  Result := '';
  for i := 0 to FList.Count - 1 do
  begin
    LStmt := Trim(FList.Items[i].ToDDL);
    if LStmt = '' then
      Continue;
    if Result <> '' then
      Result := Result + sLineBreak;
    Result := Result + LStmt;
  end;
end;

function TDatabases.ApplyStructure(const AConnection: IConnection): IDatabases;
var
  i: Integer;
begin
  { Onda S3b - agrega o IDatabase.ApplyStructure de cada banco (zero SQL
    novo, so orquestracao); ver comentario completo em Databases.Interfaces.
    IDatabases.ApplyStructure. }
  Result := Self;
  for i := 0 to FList.Count - 1 do
    FList.Items[i].ApplyStructure(AConnection);
end;

function TDatabases.ToJSON: string;
var
  I: Integer;
  LBody: string;
begin
  { EIXO DADO PROPRIO da Databases (Fatia B-e) - chave-nomeada por
    DatabaseName; o valor de cada chave e o IDatabase.ToJSON desse banco
    (que, por sua vez, ja e chave-nomeada por SchemaName). }
  LBody := '';
  for I := 0 to FList.Count - 1 do
  begin
    if LBody <> '' then
      LBody := LBody + ',';
    LBody := LBody + JSONQuoteString(FList[I].DatabaseName) + ':' + FList[I].ToJSON;
  end;
  Result := '{' + LBody + '}';
end;

function TDatabases.FromJSON(const AJSON: string): IDatabases;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
  I: Integer;
  LDb: IDatabase;
begin
  { EIXO DADO PROPRIO da Databases, "replace" (Fatia B-e) - para cada chave
    do objeto de entrada (DatabaseName), localiza (ou cria) o banco e
    delega a IDatabase.FromJSON. }
  Result := Self;
  if Trim(AJSON) = '' then
    Exit;
  LData := GetJSON(AJSON);
  if (not Assigned(LData)) or (not (LData is TJSONObject)) then
  begin
    if Assigned(LData) then
      LData.Free;
    Exit;
  end;
  LObj := TJSONObject(LData);
  try
    for I := 0 to Pred(LObj.Count) do
    begin
      if not (LObj.Items[I] is TJSONObject) then
        Continue;
      LDb := Database(LObj.Names[I]);
      if LDb = nil then
      begin
        LDb := TDatabase.New.DatabaseName(LObj.Names[I]);
        Add(LDb);
      end;
      LDb.FromJSON(LObj.Items[I].AsJSON);
    end;
  finally
    LObj.Free;
  end;
end;
{$ELSE}
var
  LVal: TJSONValue;
  LObj: TJSONObject;
  LPair: TJSONPair;
  LDb: IDatabase;
begin
  Result := Self;
  if Trim(AJSON) = '' then
    Exit;
  LVal := TJSONObject.ParseJSONValue(AJSON);
  if (not Assigned(LVal)) or (not (LVal is TJSONObject)) then
  begin
    if Assigned(LVal) then
      LVal.Free;
    Exit;
  end;
  LObj := TJSONObject(LVal);
  try
    for LPair in LObj do
    begin
      if not (LPair.JsonValue is TJSONObject) then
        Continue;
      LDb := Database(LPair.JsonString.Value);
      if LDb = nil then
      begin
        LDb := TDatabase.New.DatabaseName(LPair.JsonString.Value);
        Add(LDb);
      end;
      LDb.FromJSON(LPair.JsonValue.ToJSON);
    end;
  finally
    LObj.Free;
  end;
end;
{$ENDIF}

function TDatabases.MergeFromJSON(const AJSON: string): IDatabases;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
  I: Integer;
  LDb: IDatabase;
begin
  { EIXO DADO PROPRIO da Databases, "patch" (Fatia B-e) - mesma arvore de
    FromJSON, mas delega a IDatabase.MergeFromJSON nos bancos localizados/
    criados. }
  Result := Self;
  if Trim(AJSON) = '' then
    Exit;
  LData := GetJSON(AJSON);
  if (not Assigned(LData)) or (not (LData is TJSONObject)) then
  begin
    if Assigned(LData) then
      LData.Free;
    Exit;
  end;
  LObj := TJSONObject(LData);
  try
    for I := 0 to Pred(LObj.Count) do
    begin
      if not (LObj.Items[I] is TJSONObject) then
        Continue;
      LDb := Database(LObj.Names[I]);
      if LDb = nil then
      begin
        LDb := TDatabase.New.DatabaseName(LObj.Names[I]);
        Add(LDb);
      end;
      LDb.MergeFromJSON(LObj.Items[I].AsJSON);
    end;
  finally
    LObj.Free;
  end;
end;
{$ELSE}
var
  LVal: TJSONValue;
  LObj: TJSONObject;
  LPair: TJSONPair;
  LDb: IDatabase;
begin
  Result := Self;
  if Trim(AJSON) = '' then
    Exit;
  LVal := TJSONObject.ParseJSONValue(AJSON);
  if (not Assigned(LVal)) or (not (LVal is TJSONObject)) then
  begin
    if Assigned(LVal) then
      LVal.Free;
    Exit;
  end;
  LObj := TJSONObject(LVal);
  try
    for LPair in LObj do
    begin
      if not (LPair.JsonValue is TJSONObject) then
        Continue;
      LDb := Database(LPair.JsonString.Value);
      if LDb = nil then
      begin
        LDb := TDatabase.New.DatabaseName(LPair.JsonString.Value);
        Add(LDb);
      end;
      LDb.MergeFromJSON(LPair.JsonValue.ToJSON);
    end;
  finally
    LObj.Free;
  end;
end;
{$ENDIF}

function TDatabases.StructureToJSON: string;
var
  I: Integer;
  LBody: string;
begin
  { EIXO ESTRUTURA PROPRIO da Databases (Fatia B-e) - chave databases (array
    de IDatabase.StructureToJSON). }
  LBody := '';
  for I := 0 to FList.Count - 1 do
  begin
    if LBody <> '' then
      LBody := LBody + ',';
    LBody := LBody + FList[I].StructureToJSON;
  end;
  Result := '{"databases":[' + LBody + ']}';
end;

function TDatabases.StructureFromJSON(const AJSON: string): IDatabases;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
  LDatabasesNode: TJSONData;
  LDatabasesArr: TJSONArray;
  I: Integer;
  LDb: IDatabase;
begin
  { EIXO ESTRUTURA PROPRIO da Databases (Fatia B-e) - reconstroi FList por
    completo (substitui) - 1 IDatabase por elemento de databases, via
    IDatabase.StructureFromJSON. }
  Result := Self;
  if Trim(AJSON) = '' then
    Exit;
  LData := GetJSON(AJSON);
  if (not Assigned(LData)) or (not (LData is TJSONObject)) then
  begin
    if Assigned(LData) then
      LData.Free;
    Exit;
  end;
  LObj := TJSONObject(LData);
  try
    FList.Clear;
    LDatabasesNode := LObj.Find('databases');
    if Assigned(LDatabasesNode) and (LDatabasesNode is TJSONArray) then
    begin
      LDatabasesArr := TJSONArray(LDatabasesNode);
      for I := 0 to LDatabasesArr.Count - 1 do
      begin
        LDb := TDatabase.New;
        LDb.StructureFromJSON(LDatabasesArr.Items[I].AsJSON);
        FList.Add(LDb);
      end;
    end;
  finally
    LObj.Free;
  end;
end;
{$ELSE}
var
  LVal: TJSONValue;
  LObj: TJSONObject;
  LDatabasesVal: TJSONValue;
  LDatabasesArr: TJSONArray;
  I: Integer;
  LDb: IDatabase;
begin
  Result := Self;
  if Trim(AJSON) = '' then
    Exit;
  LVal := TJSONObject.ParseJSONValue(AJSON);
  if (not Assigned(LVal)) or (not (LVal is TJSONObject)) then
  begin
    if Assigned(LVal) then
      LVal.Free;
    Exit;
  end;
  LObj := TJSONObject(LVal);
  try
    FList.Clear;
    LDatabasesVal := LObj.GetValue('databases');
    if Assigned(LDatabasesVal) and (LDatabasesVal is TJSONArray) then
    begin
      LDatabasesArr := TJSONArray(LDatabasesVal);
      for I := 0 to LDatabasesArr.Count - 1 do
      begin
        LDb := TDatabase.New;
        LDb.StructureFromJSON(LDatabasesArr.Items[I].ToJSON);
        FList.Add(LDb);
      end;
    end;
  finally
    LObj.Free;
  end;
end;
{$ENDIF}

function TDatabases.StructureMergeFromJSON(const AJSON: string): IDatabases;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
  LDatabasesNode: TJSONData;
  LDatabasesArr: TJSONArray;
  I: Integer;
  LItemObj: TJSONObject;
  LName: string;
  LDb: IDatabase;
begin
  { Onda S2-a (ADITIVO) - PATCH aditivo: ao contrario de StructureFromJSON
    (que faz FList.Clear e reconstroi tudo), localiza (ou CRIA, via
    Database/Add - nunca remove) o IDatabase pelo "database" de cada
    elemento de "databases" e delega a IDatabase.StructureMergeFromJSON
    nesse banco. }
  Result := Self;
  if Trim(AJSON) = '' then
    Exit;
  LData := GetJSON(AJSON);
  if (not Assigned(LData)) or (not (LData is TJSONObject)) then
  begin
    if Assigned(LData) then
      LData.Free;
    Exit;
  end;
  LObj := TJSONObject(LData);
  try
    LDatabasesNode := LObj.Find('databases');
    if Assigned(LDatabasesNode) and (LDatabasesNode is TJSONArray) then
    begin
      LDatabasesArr := TJSONArray(LDatabasesNode);
      for I := 0 to LDatabasesArr.Count - 1 do
      begin
        if not (LDatabasesArr.Items[I] is TJSONObject) then
          Continue;
        LItemObj := TJSONObject(LDatabasesArr.Items[I]);
        LName := LItemObj.Get('database', '');
        LDb := Database(LName);
        if LDb = nil then
        begin
          LDb := TDatabase.New.DatabaseName(LName);
          Add(LDb);
        end;
        LDb.StructureMergeFromJSON(LItemObj.AsJSON);
      end;
    end;
  finally
    LObj.Free;
  end;
end;
{$ELSE}
var
  LVal: TJSONValue;
  LObj: TJSONObject;
  LDatabasesVal: TJSONValue;
  LDatabasesArr: TJSONArray;
  I: Integer;
  LItemObj: TJSONObject;
  LName: string;
  LDb: IDatabase;
begin
  Result := Self;
  if Trim(AJSON) = '' then
    Exit;
  LVal := TJSONObject.ParseJSONValue(AJSON);
  if (not Assigned(LVal)) or (not (LVal is TJSONObject)) then
  begin
    if Assigned(LVal) then
      LVal.Free;
    Exit;
  end;
  LObj := TJSONObject(LVal);
  try
    LDatabasesVal := LObj.GetValue('databases');
    if Assigned(LDatabasesVal) and (LDatabasesVal is TJSONArray) then
    begin
      LDatabasesArr := TJSONArray(LDatabasesVal);
      for I := 0 to LDatabasesArr.Count - 1 do
      begin
        if not (LDatabasesArr.Items[I] is TJSONObject) then
          Continue;
        LItemObj := TJSONObject(LDatabasesArr.Items[I]);
        LName := LItemObj.GetValue<string>('database', '');
        LDb := Database(LName);
        if LDb = nil then
        begin
          LDb := TDatabase.New.DatabaseName(LName);
          Add(LDb);
        end;
        LDb.StructureMergeFromJSON(LItemObj.ToJSON);
      end;
    end;
  finally
    LObj.Free;
  end;
end;
{$ENDIF}

function TDatabases.ToFullJSON: string;
begin
  { Onda S4 (ADITIVO) - COMPOE os 2 eixos JA EXISTENTES (StructureToJSON/
    ToJSON), sem reimplementar nenhum dos 2. }
  Result := '{"structure":' + StructureToJSON + ',"data":' + ToJSON + '}';
end;

function TDatabases.FromFullJSON(const AJSON: string): IDatabases;
var
  LStructure, LData: string;
begin
  { Onda S4 (ADITIVO) - decompoe via JSONExtractMember (SSOT, Database.
    Helpers.JSON) e delega, NESTA ORDEM (estrutura antes de dado), a
    StructureFromJSON/FromJSON ja existentes. Tolerante: chave ausente nao
    aplica esse eixo. }
  Result := Self;
  LStructure := JSONExtractMember(AJSON, 'structure');
  if LStructure <> '' then
    StructureFromJSON(LStructure);
  LData := JSONExtractMember(AJSON, 'data');
  if LData <> '' then
    FromJSON(LData);
end;

function TDatabases.MergeFullFromJSON(const AJSON: string): IDatabases;
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

function TDatabases.Export(const AWithData: Boolean): string;
begin
  { Onda S4 (ADITIVO) - atalho ergonomico: False -> so ESTRUTURA; True ->
    FULL (estrutura+dado). }
  if AWithData then
    Result := ToFullJSON
  else
    Result := StructureToJSON;
end;

function TDatabases.Import(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): IDatabases;
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
