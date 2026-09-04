{ =============================================================================
  Database.Fields - Container de campos (TFields, IFields)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.2.0
  FileVersion:    1.4.0
  Author:         Claiton de Souza Linhares
  Date:           30/07/2026

  Changelog (file):
  - 1.4.0 (30/07/2026): Onda S4 (ADITIVO - eixo FULL) - ToFullJSON (COMPOE
    StructureToJSON+ToJSON)/FromFullJSON/MergeFullFromJSON (decompoem via
    Database.Helpers.JSON.JSONExtractMember, estrutura antes de dado - novo
    uses implementation Database.Helpers.JSON) + Export(AWithData)/
    Import(AJSON, AWithData, AMerge) ergonomicos (ver comentario completo em
    Databases.Interfaces.IFields). Zero mudanca nos metodos pre-existentes.
  - 1.3.0 (29/07/2026): Onda S2-a (ADITIVO, simetria To/From/Merge) -
    MergeFromJSON (patch posicional dos valores - mesmo percurso de FromJSON,
    delega a IField.MergeFromJSON em vez de IField.LoadFromJSON) e
    StructureMergeFromJSON (patch aditivo POR NOME de coluna - existentes
    recebem IField.StructureMergeFromJSON, ausentes sao criados via
    TField.New.StructureFromJSON + AddField, nada e removido). Zero mudanca
    nos metodos pre-existentes (FromJSON/StructureFromJSON/ToJSON/
    StructureToJSON intactos).
  - 1.2.0 (13/07/2026): F5 Onda 4-cont, Fatia B-a. TFieldList ganha
    size/precision/scale: Integer (SyncFieldListFromField sincroniza a partir
    de IField.Size/Precision/Scale). Serialize em 2 EIXOS: StructureToJSON
    (novo, array de IField.StructureToJSON) + StructureFromJSON (novo, parser
    real cross-compiler fpjson+jsonparser/System.JSON - cria um IField por
    elemento do array via TField.New + StructureFromJSON, delegando o
    parse do OBJECTO individual ao proprio IField); ToJSON passa a emitir o
    array de IField.ToJSON (eixo DADO, so "value" por campo); FromJSON deixa
    de ser stub - hidrata POSICIONALMENTE os campos JA EXISTENTES no container
    (o eixo dado nao carrega nome de coluna, so o valor).
  - 1.1.0 (12/07/2026): absorcao v3 (FASE 5 Onda 5.1) - uses
    Providers.Connection.Interfaces -> Connections.Interfaces; header v3.
  - 1.0.4 (07/04/2026): Compatibilidade FPC: MODE DELPHI adicionado antes da seção interface.
  - 1.0.0 (03/02/2026): Versão inicial.
  - 1.0.1 (22/02/2026): TFields implementando IFields; lista de IField, AddField, HasChanges, GetPrimaryKey, ToJSON.
  - 1.0.2 (22/02/2026): FList como TFieldLists (array of TFieldList); SyncFieldListFromField; Remove com shift e índice.
  - 1.0.3 (27/02/2026): TFieldList: onUpdateRule, onDeleteRule; SyncFieldListFromField preenche a partir de IField (assimilação DatabaseORM).
  ============================================================================= }

unit Database.Fields;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}
interface

{$I ORM.Defines.inc}

uses
{$IF DEFINED(FPC)}
  SysUtils, Variants, fpjson, jsonparser,
{$ELSE}
  System.SysUtils, System.Variants, System.JSON,
{$ENDIF}
  Commons.Types,
  Databases.Interfaces;

type
  TFieldList = record
    index: Integer;
    field: IField;
    columnname: string;
    columnType: string;
    size: Integer;
    precision: Integer;
    scale: Integer;
    isNull: Boolean;
    isPKey: Boolean;
    position: Integer;
    constraintName: string;
    referencedTable: string;
    referencedColumn: string;
    onUpdateRule: string;
    onDeleteRule: string;
    value: Variant;
    defaultValue: Variant;
    isChanged: Boolean;
  end;

  TFieldLists = array of TFieldList;

  TFields = class(TInterfacedObject, IFields)
  private
    FList: TFieldLists;
    FDatabaseTypes: TDatabaseTypes;
    function IndexOfField(const AFieldName: string): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: IFields;

    function AddField(const AField: IField): IFields; overload;
    function AddField(const AColumn, AColumnType: string; AIsNull: Boolean): IFields; overload;
    function Add(const AField: IField): IFields;
    function Remove(const AFieldName: string): IFields;
    function Clear: IFields;

    function Fields(const AFieldName: string): IField;
    function GetFields(const AFieldName: string): IField;
    function GetFieldsByIndex(AIndex: Integer): IField;
    function GetFieldsList: TFieldArray;
    function FieldsCount: Integer;
    function FieldExist(const AFieldName: string): Boolean;

    function DatabaseTypes(const AValue: TDatabaseTypes): IFields; overload;
    function DatabaseTypes: TDatabaseTypes; overload;

    function HasChanges: Boolean;
    function ClearAllChanges: IFields;
    function GetAllChangedFieldNames: TStringArray;
    function GetPrimaryKey: IField;

    function StructureToJSON: string;
    function StructureFromJSON(const AJSON: string): IFields;
    function StructureMergeFromJSON(const AJSON: string): IFields;
    function ToJSON: string;
    function FromJSON(const AJSON: string): IFields;
    function MergeFromJSON(const AJSON: string): IFields;

    { Onda S4 (ADITIVO) - eixo FULL - ver comentario completo em
      Databases.Interfaces.IFields. }
    function ToFullJSON: string;
    function FromFullJSON(const AJSON: string): IFields;
    function MergeFullFromJSON(const AJSON: string): IFields;
    function Export(const AWithData: Boolean): string;
    function Import(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): IFields;
  end;

implementation

uses
  Database.Field,
  Database.Helpers.JSON;

{ Sincroniza um item TFieldList a partir de IField. defaultValue não existe em IField, permanece não atribuído. }
procedure SyncFieldListFromField(var AItem: TFieldList; const AField: IField; AIndex: Integer);
begin
  AItem.index := AIndex;
  AItem.field := AField;
  AItem.columnname := AField.Column;
  AItem.columnType := AField.ColumnType;
  AItem.size := AField.Size;
  AItem.precision := AField.Precision;
  AItem.scale := AField.Scale;
  AItem.isNull := AField.IsNull;
  AItem.isPKey := AField.IsPKey;
  AItem.position := AField.Position;
  AItem.constraintName := AField.ConstraintName;
  AItem.referencedTable := AField.ReferencedTable;
  AItem.referencedColumn := AField.ReferencedColumn;
  AItem.onUpdateRule := AField.OnUpdateRule;
  AItem.onDeleteRule := AField.OnDeleteRule;
  AItem.value := AField.Value;
  AItem.isChanged := AField.IsChanged;
end;

function TFields.IndexOfField(const AFieldName: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(FList) do
    if CompareText(FList[i].columnname, AFieldName) = 0 then
    begin
      Result := i;
      Exit;
    end;
end;

constructor TFields.Create;
begin
  inherited Create;
  SetLength(FList, 0);
  FDatabaseTypes := dtNone;
end;

destructor TFields.Destroy;
begin
  SetLength(FList, 0);
  inherited;
end;

class function TFields.New: IFields;
begin
  Result := TFields.Create;
end;

function TFields.AddField(const AField: IField): IFields;
var
  L: Integer;
begin
  if Assigned(AField) then
  begin
    L := Length(FList);
    SetLength(FList, L + 1);
    SyncFieldListFromField(FList[L], AField, L);
  end;
  Result := Self;
end;

function TFields.AddField(const AColumn, AColumnType: string; AIsNull: Boolean): IFields;
var
  LField: IField;
begin
  LField := TField.New(AColumn, AColumnType, AIsNull, False);
  Result := AddField(LField);
end;

function TFields.Add(const AField: IField): IFields;
begin
  Result := AddField(AField);
end;

function TFields.Remove(const AFieldName: string): IFields;
var
  i, j: Integer;
begin
  i := IndexOfField(AFieldName);
  if i >= 0 then
  begin
    for j := i to High(FList) - 1 do
    begin
      FList[j] := FList[j + 1];
      FList[j].index := j;
    end;
    SetLength(FList, Length(FList) - 1);
  end;
  Result := Self;
end;

function TFields.Clear: IFields;
begin
  SetLength(FList, 0);
  Result := Self;
end;

function TFields.Fields(const AFieldName: string): IField;
begin
  Result := GetFields(AFieldName);
end;

function TFields.GetFields(const AFieldName: string): IField;
var
  i: Integer;
begin
  Result := nil;
  i := IndexOfField(AFieldName);
  if i >= 0 then
    Result := FList[i].field;
end;

function TFields.GetFieldsByIndex(AIndex: Integer): IField;
begin
  Result := nil;
  if (AIndex >= 0) and (AIndex <= High(FList)) then
    Result := FList[AIndex].field;
end;

function TFields.GetFieldsList: TFieldArray;
var
  i: Integer;
begin
  SetLength(Result, Length(FList));
  for i := 0 to High(FList) do
    Result[i] := FList[i].field;
end;

function TFields.FieldsCount: Integer;
begin
  Result := Length(FList);
end;

function TFields.FieldExist(const AFieldName: string): Boolean;
begin
  Result := IndexOfField(AFieldName) >= 0;
end;

function TFields.DatabaseTypes(const AValue: TDatabaseTypes): IFields;
begin
  FDatabaseTypes := AValue;
  Result := Self;
end;

function TFields.DatabaseTypes: TDatabaseTypes;
begin
  Result := FDatabaseTypes;
end;

function TFields.HasChanges: Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(FList) do
    if FList[i].field.IsChanged then
    begin
      Result := True;
      Exit;
    end;
end;

function TFields.ClearAllChanges: IFields;
var
  i: Integer;
begin
  for i := 0 to High(FList) do
    FList[i].field.MarkUnchanged;
  Result := Self;
end;

function TFields.GetAllChangedFieldNames: TStringArray;
var
  i, c: Integer;
begin
  c := 0;
  for i := 0 to High(FList) do
    if FList[i].field.IsChanged then
      Inc(c);
  SetLength(Result, c);
  c := 0;
  for i := 0 to High(FList) do
    if FList[i].field.IsChanged then
    begin
      Result[c] := FList[i].field.Column;
      Inc(c);
    end;
end;

function TFields.GetPrimaryKey: IField;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to High(FList) do
    if FList[i].field.IsPKey then
    begin
      Result := FList[i].field;
      Exit;
    end;
end;

function TFields.StructureToJSON: string;
var
  i: Integer;
begin
  { EIXO ESTRUTURA - array de IField.StructureToJSON (metadados de esquema). }
  Result := '[';
  for i := 0 to High(FList) do
  begin
    if i > 0 then Result := Result + ',';
    Result := Result + FList[i].field.StructureToJSON;
  end;
  Result := Result + ']';
end;

function TFields.StructureFromJSON(const AJSON: string): IFields;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LArr: TJSONArray;
  i: Integer;
  LField: IField;
begin
  Result := Self;
  Clear;
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
    for i := 0 to LArr.Count - 1 do
    begin
      LField := TField.New;
      LField.StructureFromJSON(LArr.Items[i].AsJSON);
      AddField(LField);
    end;
  finally
    LArr.Free;
  end;
end;
{$ELSE}
var
  LVal: TJSONValue;
  LArr: TJSONArray;
  i: Integer;
  LField: IField;
begin
  Result := Self;
  Clear;
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
    for i := 0 to LArr.Count - 1 do
    begin
      LField := TField.New;
      LField.StructureFromJSON(LArr.Items[i].ToJSON);
      AddField(LField);
    end;
  finally
    LArr.Free;
  end;
end;
{$ENDIF}

function TFields.ToJSON: string;
var
  i: Integer;
begin
  { EIXO DADO - array de IField.ToJSON (so "value" por campo, na mesma ordem). }
  Result := '[';
  for i := 0 to High(FList) do
  begin
    if i > 0 then Result := Result + ',';
    Result := Result + FList[i].field.ToJSON;
  end;
  Result := Result + ']';
end;

function TFields.FromJSON(const AJSON: string): IFields;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LArr: TJSONArray;
  i: Integer;
begin
  { hidrata POSICIONALMENTE os campos JA EXISTENTES no container - o eixo dado
    (IField.ToJSON) so carrega "value", sem nome de coluna; a estrutura
    (StructureFromJSON/AddField) tem de estar montada ANTES de chamar isto. }
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
    for i := 0 to LArr.Count - 1 do
      if i <= High(FList) then
        FList[i].field.LoadFromJSON(LArr.Items[i].AsJSON);
  finally
    LArr.Free;
  end;
end;
{$ELSE}
var
  LVal: TJSONValue;
  LArr: TJSONArray;
  i: Integer;
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
    for i := 0 to LArr.Count - 1 do
      if i <= High(FList) then
        FList[i].field.LoadFromJSON(LArr.Items[i].ToJSON);
  finally
    LArr.Free;
  end;
end;
{$ENDIF}

function TFields.MergeFromJSON(const AJSON: string): IFields;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LArr: TJSONArray;
  i: Integer;
begin
  { Onda S2-a (ADITIVO) - "patch" posicional: mesmo percurso de FromJSON
    (hidrata os campos JA EXISTENTES no container, por posicao - o eixo dado
    de IField so carrega "value", sem nome de coluna), mas delega a
    IField.MergeFromJSON (dirty inteligente) em vez de IField.LoadFromJSON
    (hidratacao limpa). Tolerante a arrays de tamanho diferente (so hidrata
    i <= High(FList), mesma guarda de FromJSON). }
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
    for i := 0 to LArr.Count - 1 do
      if i <= High(FList) then
        FList[i].field.MergeFromJSON(LArr.Items[i].AsJSON);
  finally
    LArr.Free;
  end;
end;
{$ELSE}
var
  LVal: TJSONValue;
  LArr: TJSONArray;
  i: Integer;
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
    for i := 0 to LArr.Count - 1 do
      if i <= High(FList) then
        FList[i].field.MergeFromJSON(LArr.Items[i].ToJSON);
  finally
    LArr.Free;
  end;
end;
{$ENDIF}

function TFields.StructureMergeFromJSON(const AJSON: string): IFields;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LArr: TJSONArray;
  i: Integer;
  LColumnName: string;
  LField: IField;
begin
  { Onda S2-a (ADITIVO) - PATCH aditivo POR NOME de coluna (ao contrario de
    StructureFromJSON, que faz Clear e reconstroi tudo por posicao): para
    cada elemento do array, se ja existe um IField com esse "column" (via
    GetFields, case-insensitive - mesma busca de FieldExist/IndexOfField),
    aplica IField.StructureMergeFromJSON nele (patch dos metadados desse
    campo); se nao existe, cria via TField.New + StructureFromJSON (semeia
    directamente, sem estado previo a preservar) e adiciona ao container.
    NUNCA remove um campo existente que nao apareca no JSON de entrada. }
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
    for i := 0 to LArr.Count - 1 do
    begin
      if not (LArr.Items[i] is TJSONObject) then
        Continue;
      LColumnName := TJSONObject(LArr.Items[i]).Get('column', '');
      LField := GetFields(LColumnName);
      if LField <> nil then
        LField.StructureMergeFromJSON(LArr.Items[i].AsJSON)
      else
      begin
        LField := TField.New;
        LField.StructureFromJSON(LArr.Items[i].AsJSON);
        AddField(LField);
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
  i: Integer;
  LColumnName: string;
  LField: IField;
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
    for i := 0 to LArr.Count - 1 do
    begin
      if not (LArr.Items[i] is TJSONObject) then
        Continue;
      LColumnName := TJSONObject(LArr.Items[i]).GetValue<string>('column', '');
      LField := GetFields(LColumnName);
      if LField <> nil then
        LField.StructureMergeFromJSON(LArr.Items[i].ToJSON)
      else
      begin
        LField := TField.New;
        LField.StructureFromJSON(LArr.Items[i].ToJSON);
        AddField(LField);
      end;
    end;
  finally
    LArr.Free;
  end;
end;
{$ENDIF}

function TFields.ToFullJSON: string;
begin
  { Onda S4 (ADITIVO) - COMPOE os 2 eixos JA EXISTENTES (StructureToJSON/
    ToJSON), sem reimplementar nenhum dos 2. }
  Result := '{"structure":' + StructureToJSON + ',"data":' + ToJSON + '}';
end;

function TFields.FromFullJSON(const AJSON: string): IFields;
var
  LStructure, LData: string;
begin
  { Onda S4 (ADITIVO) - decompoe via JSONExtractMember (SSOT, Database.
    Helpers.JSON) e delega, NESTA ORDEM (estrutura antes de dado - FromJSON
    e' POSICIONAL sobre os campos JA EXISTENTES no container; sem
    StructureFromJSON antes, os campos nem existiriam), a StructureFromJSON/
    FromJSON ja existentes. Tolerante: chave ausente nao aplica esse eixo. }
  Result := Self;
  LStructure := JSONExtractMember(AJSON, 'structure');
  if LStructure <> '' then
    StructureFromJSON(LStructure);
  LData := JSONExtractMember(AJSON, 'data');
  if LData <> '' then
    FromJSON(LData);
end;

function TFields.MergeFullFromJSON(const AJSON: string): IFields;
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

function TFields.Export(const AWithData: Boolean): string;
begin
  { Onda S4 (ADITIVO) - atalho ergonomico: False -> so ESTRUTURA; True ->
    FULL (estrutura+dado). }
  if AWithData then
    Result := ToFullJSON
  else
    Result := StructureToJSON;
end;

function TFields.Import(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): IFields;
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
