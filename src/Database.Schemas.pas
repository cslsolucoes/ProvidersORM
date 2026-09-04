{ =============================================================================
  Database.Schemas - Container de schemas (TSchemas, ISchemas)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.3.0
  FileVersion:    1.6.0
  Author:         Claiton de Souza Linhares
  Date:           30/07/2026

  Changelog (file):
  - 1.6.0 (30/07/2026): Onda S3b (ADITIVO - materializacao do merge, ver
    Databases.Interfaces 3.3.0) - ApplyStructure(AConnection): ISchemas
    agrega o ISchema.ApplyStructure de cada schema de FList; zero SQL novo,
    so orquestracao trivial (mesmo padrao de ToDDL, acima).
  - 1.5.0 (30/07/2026): Onda S4 (ADITIVO - eixo FULL, ver Databases.Interfaces
    3.2.0) - ToFullJSON (COMPOE StructureToJSON+ToJSON)/FromFullJSON/
    MergeFullFromJSON (decompoem via Database.Helpers.JSON.JSONExtractMember,
    estrutura antes de dado - ja usava Database.Helpers.JSON, sem uses novo)
    + Export(AWithData)/Import(AJSON, AWithData, AMerge) ergonomicos, SEM
    overload de AQuery:IQueryBuilder (reservada a ITable/ISchema/IDatabase).
    Sem covariancia (ISchemas nao herda ITables/IFields) - declaracao
    directa. Zero mudanca nos metodos pre-existentes.
  - 1.4.0 (29/07/2026): Onda S3 (ADITIVO - eixo SQL, ver Databases.Interfaces
    3.1.0) - ToDDL: string (agrega o ISchema.ToDDL de cada schema de FList;
    zero SQL novo, so orquestracao trivial - mesmo padrao ja usado por
    ToJSON/StructureToJSON, que delegam integralmente a cada ISchema).
  - 1.3.0 (29/07/2026): Onda S2-a (ADITIVO, simetria To/From/Merge) -
    ISchemas ganha StructureMergeFromJSON - PATCH aditivo: localiza (ou CRIA,
    nunca remove) o ISchema pelo SchemaName de cada elemento de "schemas" e
    delega a ISchema.StructureMergeFromJSON nesse schema. Ao contrario de
    StructureFromJSON (FList.Clear + reconstroi tudo), esta versao preserva
    os schemas existentes. Zero mudanca nos metodos pre-existentes.
  - 1.2.2 (27/07/2026): conformidade F5 (onda C5, M7) - SchemasJSONQuoteString
    local removida; delega ao SSOT unico Database.Helpers.JSON.JSONQuoteString
    (regra #14).
  - 1.2.1 (25/07/2026): R2.6 (f5-repair, Onda R2 - re-layering por
    responsabilidade) - ADITIVO: ISchemas ganha SchemaNames: TStringArray -
    delega a TCatalogReader.New(FConnection).SchemaNames('') (mesmo padrao de
    degradacao de LoadSchemasFromConnection, acima - vazio se USE_DATABASE
    OFF/sem Connection/conexao nao ligada). Novo uses (implementation, gated
    USE_DATABASE): Database.CatalogReader (classe TCatalogReader) - nao usa
    Database.Schemas, sem ciclo.
  - 1.2.0 (13/07/2026): Fatia B-d (continuacao Onda 4-cont, revisao F5) -
    serializacao PROPRIA da Schemas, formato CHAVE-NOMEADA por SchemaName
    (ver comentario completo em Database.Schemas.Interfaces.ISchemas).
    ToJSON/FromJSON/MergeFromJSON/StructureToJSON/StructureFromJSON
    delegam integralmente ao ISchema de cada elemento de FList (que, por sua
    vez, ja delega ao grupo ITables por TableName - Fatia B-d ao nivel do
    Schema). Sem covariancia (ISchemas nao herda ITables/IFields) - nenhuma
    clausula de resolucao de interface necessaria. Helper local de escaping
    RFC 8259 (SchemasJSONQuoteString) - mesma tecnica dos escapers das
    fatias anteriores, duplicado localmente; NUNCA QuotedStr para JSON
    (bug-293).
  - 1.1.0 (12/07/2026): absorcao v3 (FASE 5 Onda 5.1) - uses
    Providers.Connection.Interfaces -> Connections.Interfaces; header v3.
  - 1.0.3 (07/04/2026): Compatibilidade FPC: MODE DELPHI adicionado antes da seção interface.
  - 1.0.0 (22/02/2026): Versão inicial (LoadSchemasFromConnection stub).
  - 1.0.1 (26/02/2026): LoadSchemasFromConnection implementado via ITables.GetSchemaNames.
  - 1.0.2 (26/02/2026): Metadados (GetTableNames, GetSchemaNames, etc.) movidos para ITables; Schemas usa TTables.New.Connection(FConnection).GetSchemaNames.
  ============================================================================= }

unit Database.Schemas;


{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}
interface

{$I ORM.Defines.inc}

uses
{$IF DEFINED(FPC)}
  SysUtils, Classes, Generics.Collections,
{$ELSE}
  System.SysUtils, System.Classes, System.Generics.Collections,
{$ENDIF}
  Database.Tables,
  Databases.Interfaces,
  Connections.Interfaces,
  Commons.Types;

type
  TSchemas = class(TInterfacedObject, ISchemas)
  private
    FList: TList<ISchema>;
    FConnection: IConnection;
    function IndexOfSchema(const AName: string): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: ISchemas;
    function Connection(const AConnection: IConnection): ISchemas; overload;
    function Connection: IConnection; overload;
    function Add(const ASchema: ISchema): ISchemas;
    function Schema(const AName: string): ISchema;
    function GetSchemasList: TSchemaArray;
    function SchemasCount: Integer;
    function SchemaExists(const AName: string): Boolean;
    function LoadSchemasFromConnection: ISchemas;
    { R2.6 (f5-repair) - ver comentario completo em
      Databases.Interfaces.ISchemas.SchemaNames. }
    function SchemaNames: TStringArray;

    { Serialize PROPRIA da Schemas (Fatia B-d) - ver comentario completo
      em Database.Schemas.Interfaces.ISchemas. Sem covariancia (ISchemas nao
      herda ITables/IFields) - declaracao directa, sem clausula de resolucao
      de interface. }
    function ToJSON: string;
    function FromJSON(const AJSON: string): ISchemas;
    function MergeFromJSON(const AJSON: string): ISchemas;
    function StructureToJSON: string;
    function StructureFromJSON(const AJSON: string): ISchemas;
    { Onda S2-a (ADITIVO) - ver comentario completo em
      Databases.Interfaces.ISchemas.StructureMergeFromJSON. }
    function StructureMergeFromJSON(const AJSON: string): ISchemas;
    { Onda S3 - eixo SQL - ver comentario completo em
      Databases.Interfaces.ISchemas.ToDDL. }
    function ToDDL: string;

    { Onda S3b (ADITIVO) - MATERIALIZACAO do merge - ver comentario completo
      em Databases.Interfaces.ISchemas.ApplyStructure. }
    function ApplyStructure(const AConnection: IConnection): ISchemas;

    { Onda S4 (ADITIVO) - eixo FULL - ver comentario completo em
      Databases.Interfaces.ISchemas. }
    function ToFullJSON: string;
    function FromFullJSON(const AJSON: string): ISchemas;
    function MergeFullFromJSON(const AJSON: string): ISchemas;
    function Export(const AWithData: Boolean): string;
    function Import(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): ISchemas;
  end;

implementation

uses
{$IF DEFINED(FPC)}
  fpjson, jsonparser,
{$ELSE}
  System.JSON,
{$ENDIF}
  Database.Schema,
  Database.Helpers.JSON
{$IFDEF USE_DATABASE}
  , Database.CatalogReader
{$ENDIF}
  ;

{ Escaper RFC 8259 - Onda C5 (M7, conformidade F5): delega ao SSOT unico
  Database.Helpers.JSON.JSONQuoteString (antes copia local
  SchemasJSONQuoteString - regra #14). Usado so para as CHAVES do objeto
  chave-nomeada (SchemaName) - os VALORES sao sempre delegados a
  ISchema.ToJSON/StructureToJSON de cada schema, que ja escapam por conta
  propria. }

function TSchemas.IndexOfSchema(const AName: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to FList.Count - 1 do
    if CompareText(FList.Items[i].SchemaName, AName) = 0 then
    begin
      Result := i;
      Exit;
    end;
end;

constructor TSchemas.Create;
begin
  inherited Create;
  FList := TList<ISchema>.Create;
end;

destructor TSchemas.Destroy;
begin
  FList.Free;
  inherited;
end;

class function TSchemas.New: ISchemas;
begin
  Result := TSchemas.Create;
end;

function TSchemas.Connection(const AConnection: IConnection): ISchemas;
begin
  FConnection := AConnection;
  Result := Self;
end;

function TSchemas.Connection: IConnection;
begin
  Result := FConnection;
end;

function TSchemas.Add(const ASchema: ISchema): ISchemas;
begin
  if ASchema <> nil then
    FList.Add(ASchema);
  Result := Self;
end;

function TSchemas.Schema(const AName: string): ISchema;
var
  i: Integer;
begin
  Result := nil;
  i := IndexOfSchema(AName);
  if i >= 0 then
    Result := FList.Items[i];
end;

function TSchemas.GetSchemasList: TSchemaArray;
var
  i: Integer;
begin
  SetLength(Result, FList.Count);
  for i := 0 to FList.Count - 1 do
    Result[i] := FList.Items[i];
end;

function TSchemas.SchemasCount: Integer;
begin
  Result := FList.Count;
end;

function TSchemas.SchemaExists(const AName: string): Boolean;
begin
  Result := IndexOfSchema(AName) >= 0;
end;

function TSchemas.LoadSchemasFromConnection: ISchemas;
var
  LNames: TStringArray;
  i: Integer;
  LSchema: ISchema;
  LDb: string;
begin
  FList.Clear;
  if Assigned(FConnection) and FConnection.IsConnected then
  begin
    LDb := FConnection.Database;
    LNames := TTables.New.Connection(FConnection).GetSchemaNames(LDb);
    for i := 0 to High(LNames) do
    begin
      LSchema := TSchema.New.SchemaName(LNames[i]).Database(LDb);
      FList.Add(LSchema);
    end;
  end;
  Result := Self;
end;

{ R2.6 (f5-repair) - lista os nomes de schema via ICatalogReader.SchemaNames
  (Connection-bound); vazio se USE_DATABASE estiver OFF, sem Connection
  injectada, ou conexao nao ligada (mesmo padrao de degradacao de
  LoadSchemasFromConnection, acima). }
function TSchemas.SchemaNames: TStringArray;
begin
  SetLength(Result, 0);
{$IFDEF USE_DATABASE}
  if (FConnection = nil) or not FConnection.IsConnected then Exit;
  Result := TCatalogReader.New(FConnection).SchemaNames('');
{$ENDIF}
end;

function TSchemas.ToDDL: string;
var
  i: Integer;
  LStmt: string;
begin
  { Onda S3 - agrega o ISchema.ToDDL de cada schema (zero SQL novo, so
    orquestracao); ver comentario completo em Databases.Interfaces.ISchemas.
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

function TSchemas.ApplyStructure(const AConnection: IConnection): ISchemas;
var
  i: Integer;
begin
  { Onda S3b - agrega o ISchema.ApplyStructure de cada schema (zero SQL
    novo, so orquestracao); ver comentario completo em Databases.Interfaces.
    ISchemas.ApplyStructure. }
  Result := Self;
  for i := 0 to FList.Count - 1 do
    FList.Items[i].ApplyStructure(AConnection);
end;

function TSchemas.ToJSON: string;
var
  I: Integer;
  LBody: string;
begin
  { EIXO DADO PROPRIO da Schemas (Fatia B-d) - chave-nomeada por SchemaName;
    o valor de cada chave e o ISchema.ToJSON desse schema (que, por sua vez,
    ja e chave-nomeada por TableName). }
  LBody := '';
  for I := 0 to FList.Count - 1 do
  begin
    if LBody <> '' then
      LBody := LBody + ',';
    LBody := LBody + JSONQuoteString(FList[I].SchemaName) + ':' + FList[I].ToJSON;
  end;
  Result := '{' + LBody + '}';
end;

function TSchemas.FromJSON(const AJSON: string): ISchemas;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
  I: Integer;
  LSchema: ISchema;
begin
  { EIXO DADO PROPRIO da Schemas, "replace" (Fatia B-d) - para cada chave do
    objeto de entrada (SchemaName), localiza (ou cria) o schema e delega a
    ISchema.FromJSON. }
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
      LSchema := Schema(LObj.Names[I]);
      if LSchema = nil then
      begin
        LSchema := TSchema.New.SchemaName(LObj.Names[I]);
        Add(LSchema);
      end;
      LSchema.FromJSON(LObj.Items[I].AsJSON);
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
  LSchema: ISchema;
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
      LSchema := Schema(LPair.JsonString.Value);
      if LSchema = nil then
      begin
        LSchema := TSchema.New.SchemaName(LPair.JsonString.Value);
        Add(LSchema);
      end;
      LSchema.FromJSON(LPair.JsonValue.ToJSON);
    end;
  finally
    LObj.Free;
  end;
end;
{$ENDIF}

function TSchemas.MergeFromJSON(const AJSON: string): ISchemas;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
  I: Integer;
  LSchema: ISchema;
begin
  { EIXO DADO PROPRIO da Schemas, "patch" (Fatia B-d) - mesma arvore de
    FromJSON, mas delega a ISchema.MergeFromJSON nos schemas localizados/
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
      LSchema := Schema(LObj.Names[I]);
      if LSchema = nil then
      begin
        LSchema := TSchema.New.SchemaName(LObj.Names[I]);
        Add(LSchema);
      end;
      LSchema.MergeFromJSON(LObj.Items[I].AsJSON);
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
  LSchema: ISchema;
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
      LSchema := Schema(LPair.JsonString.Value);
      if LSchema = nil then
      begin
        LSchema := TSchema.New.SchemaName(LPair.JsonString.Value);
        Add(LSchema);
      end;
      LSchema.MergeFromJSON(LPair.JsonValue.ToJSON);
    end;
  finally
    LObj.Free;
  end;
end;
{$ENDIF}

function TSchemas.StructureToJSON: string;
var
  I: Integer;
  LBody: string;
begin
  { EIXO ESTRUTURA PROPRIO da Schemas (Fatia B-d) - chave schemas (array de
    ISchema.StructureToJSON). }
  LBody := '';
  for I := 0 to FList.Count - 1 do
  begin
    if LBody <> '' then
      LBody := LBody + ',';
    LBody := LBody + FList[I].StructureToJSON;
  end;
  Result := '{"schemas":[' + LBody + ']}';
end;

function TSchemas.StructureFromJSON(const AJSON: string): ISchemas;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
  LSchemasNode: TJSONData;
  LSchemasArr: TJSONArray;
  I: Integer;
  LSchema: ISchema;
begin
  { EIXO ESTRUTURA PROPRIO da Schemas (Fatia B-d) - reconstroi FList por
    completo (substitui) - 1 ISchema por elemento de schemas, via
    ISchema.StructureFromJSON. }
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
    LSchemasNode := LObj.Find('schemas');
    if Assigned(LSchemasNode) and (LSchemasNode is TJSONArray) then
    begin
      LSchemasArr := TJSONArray(LSchemasNode);
      for I := 0 to LSchemasArr.Count - 1 do
      begin
        LSchema := TSchema.New;
        LSchema.StructureFromJSON(LSchemasArr.Items[I].AsJSON);
        FList.Add(LSchema);
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
  LSchemasVal: TJSONValue;
  LSchemasArr: TJSONArray;
  I: Integer;
  LSchema: ISchema;
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
    LSchemasVal := LObj.GetValue('schemas');
    if Assigned(LSchemasVal) and (LSchemasVal is TJSONArray) then
    begin
      LSchemasArr := TJSONArray(LSchemasVal);
      for I := 0 to LSchemasArr.Count - 1 do
      begin
        LSchema := TSchema.New;
        LSchema.StructureFromJSON(LSchemasArr.Items[I].ToJSON);
        FList.Add(LSchema);
      end;
    end;
  finally
    LObj.Free;
  end;
end;
{$ENDIF}

function TSchemas.StructureMergeFromJSON(const AJSON: string): ISchemas;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
  LSchemasNode: TJSONData;
  LSchemasArr: TJSONArray;
  I: Integer;
  LItemObj: TJSONObject;
  LName: string;
  LSchema: ISchema;
begin
  { Onda S2-a (ADITIVO) - PATCH aditivo: ao contrario de StructureFromJSON
    (que faz FList.Clear e reconstroi tudo), localiza (ou CRIA, via Schema/
    Add - nunca remove) o ISchema pelo "schema" de cada elemento de
    "schemas" e delega a ISchema.StructureMergeFromJSON nesse schema. }
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
    LSchemasNode := LObj.Find('schemas');
    if Assigned(LSchemasNode) and (LSchemasNode is TJSONArray) then
    begin
      LSchemasArr := TJSONArray(LSchemasNode);
      for I := 0 to LSchemasArr.Count - 1 do
      begin
        if not (LSchemasArr.Items[I] is TJSONObject) then
          Continue;
        LItemObj := TJSONObject(LSchemasArr.Items[I]);
        LName := LItemObj.Get('schema', '');
        LSchema := Schema(LName);
        if LSchema = nil then
        begin
          LSchema := TSchema.New.SchemaName(LName);
          Add(LSchema);
        end;
        LSchema.StructureMergeFromJSON(LItemObj.AsJSON);
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
  LSchemasVal: TJSONValue;
  LSchemasArr: TJSONArray;
  I: Integer;
  LItemObj: TJSONObject;
  LName: string;
  LSchema: ISchema;
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
    LSchemasVal := LObj.GetValue('schemas');
    if Assigned(LSchemasVal) and (LSchemasVal is TJSONArray) then
    begin
      LSchemasArr := TJSONArray(LSchemasVal);
      for I := 0 to LSchemasArr.Count - 1 do
      begin
        if not (LSchemasArr.Items[I] is TJSONObject) then
          Continue;
        LItemObj := TJSONObject(LSchemasArr.Items[I]);
        LName := LItemObj.GetValue<string>('schema', '');
        LSchema := Schema(LName);
        if LSchema = nil then
        begin
          LSchema := TSchema.New.SchemaName(LName);
          Add(LSchema);
        end;
        LSchema.StructureMergeFromJSON(LItemObj.ToJSON);
      end;
    end;
  finally
    LObj.Free;
  end;
end;
{$ENDIF}

function TSchemas.ToFullJSON: string;
begin
  { Onda S4 (ADITIVO) - COMPOE os 2 eixos JA EXISTENTES (StructureToJSON/
    ToJSON), sem reimplementar nenhum dos 2. }
  Result := '{"structure":' + StructureToJSON + ',"data":' + ToJSON + '}';
end;

function TSchemas.FromFullJSON(const AJSON: string): ISchemas;
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

function TSchemas.MergeFullFromJSON(const AJSON: string): ISchemas;
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

function TSchemas.Export(const AWithData: Boolean): string;
begin
  { Onda S4 (ADITIVO) - atalho ergonomico: False -> so ESTRUTURA; True ->
    FULL (estrutura+dado). }
  if AWithData then
    Result := ToFullJSON
  else
    Result := StructureToJSON;
end;

function TSchemas.Import(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): ISchemas;
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
