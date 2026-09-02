{ =============================================================================
  Database.Field - Campo individual (TField, IField)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.2.0
  FileVersion:    1.8.0
  Author:         Claiton de Souza Linhares
  Date:           30/07/2026

  Changelog (file):
  - 1.8.0 (30/07/2026): Onda S4 (ADITIVO - eixo FULL) - ToFullJSON (COMPOE
    StructureToJSON+ToJSON, zero SQL/parse novo)/FromFullJSON/
    MergeFullFromJSON (decompoem via Database.Helpers.JSON.JSONExtractMember
    e delegam, estrutura antes de dado, aos 4 metodos JA EXISTENTES) +
    Export(AWithData)/Import(AJSON, AWithData, AMerge) ergonomicos (ver
    comentario completo em Databases.Interfaces.IField). Zero mudanca nos
    metodos pre-existentes.
  - 1.7.0 (29/07/2026): Onda S2-a (ADITIVO, simetria To/From/Merge) - FromJSON
    (delega a LoadFromJSON, nome canonico fluente), MergeFromJSON (patch do
    valor via SetColumnValue - dirty inteligente, ao contrario de
    LoadFromJSON/FromJSON que usam SetColumnValueWithoutChange) e
    StructureMergeFromJSON (patch de metadata - delega a StructureFromJSON,
    que ja usa Get/GetValue com default=valor CORRENTE, logo ja e patch
    aditivo a nivel de um campo isolado). Zero mudanca nos metodos
    pre-existentes (LoadFromJSON/StructureFromJSON/ToJSON/StructureToJSON
    intactos).
  - 1.6.0 (27/07/2026): conformidade F5 (onda C6, B2) - StructureToJSON/
    StructureFromJSON ganham Description/LogicalName (eixo ESTRUTURA) -
    fecha a assimetria com Clone (que ja os preservava); round-trip de
    snapshots antigos (sem estas chaves) continua a funcionar via default
    do proprio Get/GetValue.
  - 1.5.1 (27/07/2026): conformidade F5 (onda C5) - M7: JSONQuoteString local
    removida, delega ao SSOT unico Database.Helpers.JSON.JSONQuoteString
    (regra #14; zero call-sites mudam de nome). B1 (doc-only): comentario
    marcando SetAsChanged/SetAsUnchanged/IsFieldChanged/IsFieldPrimaryKey
    como aliases de compat mantidos por decisao do owner.
  - 1.5.0 (15/07/2026): Onda 6-d PARTE 2 (I24, ADITIVO) - FDescription + par
    fluente Description(AValue)/Description; Clone passa a copiar Description
    explicitamente (mesmo padrao de LogicalName/Size/Precision/Scale). Default
    '' (comportamento pre-existente inalterado).
  - 1.4.0 (14/07/2026): Onda 6-b I7 - LogicalName em IField/ITable (nome
    logico) + ITable.PhysicalColumn (resolucao logico->fisico,
    case-insensitive, fallback ao nome dado); ListWhere delega. Aditivo
    (default '' -> inalterado).
  - 1.3.0 (14/07/2026): renomeacao mecanica IMetadataProvider -> ICatalogReader.
  - 1.2.0 (13/07/2026): F5 Onda 4-cont, Fatia B-a. (1) Metadados de dimensao
    FSize/FPrecision/FScale + pares fluentes Size/Precision/Scale; o setter
    ColumnType(AValue) decompoe o conteudo entre parenteses (parser
    ParseColumnTypeDimensions): 1 numero -> Size; 2 numeros (virgula) ->
    Precision,Scale; sem parenteses -> 0,0,0. (2) Serialize em 2 EIXOS:
    StructureToJSON/StructureFromJSON (ESTRUTURA pura, novos, JSON valido
    via escaping proprio JSONQuoteString/JSONBoolLiteral) + ToJSON passa a
    emitir SO "value" (DADO puro; deixa de ser hibrido) + LoadFromJSON
    implementado de verdade (parser real cross-compiler fpjson+jsonparser/
    System.JSON, padrao de Connections.pas.LoadFromJSON) - hidrata via
    SetColumnValueWithoutChange (carga "limpa", nao marca dirty). Clone
    passa a copiar Size/Precision/Scale explicitamente (preserva overrides
    manuais que divirjam do parse derivado do texto de ColumnType).
  - 1.1.0 (12/07/2026): absorcao v3 (FASE 5 Onda 5.1) - uses
    Providers.Connection.Interfaces -> Connections.Interfaces; header v3.
  - 1.0.3 (07/04/2026): Compatibilidade FPC: MODE DELPHI adicionado antes da seção interface.
  - 1.0.0 (03/02/2026): Versão inicial.
  - 1.0.1 (22/02/2026): TField implementando IField; metadados, valor, IsChanged, Fluent, Clone, ToJSON, New.
  - 1.0.2 (27/02/2026): OnUpdateRule/OnDeleteRule (FOnUpdateRule, FOnDeleteRule); Clone copia regras de FK (assimilação DatabaseORM).
  ============================================================================= }

unit Database.Field;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}
interface

{$I ../../../ORM.Defines.inc}

uses
{$IF DEFINED(FPC)}
  SysUtils, Variants, Classes, DateUtils, fpjson, jsonparser,
{$ELSE}
  System.SysUtils, System.Variants, System.Classes, System.DateUtils, System.JSON,
{$ENDIF}
  Commons.Types,
  Databases.Interfaces,
  Database.Helpers.JSON;

type
  TField = class(TInterfacedObject, IField)
  private
    FTable: string;
    FColumn: string;
    FLogicalName: string;
    FDescription: string;
    FColumnType: string;
    FColumnTypeCode: Integer;
    FSize: Integer;
    FPrecision: Integer;
    FScale: Integer;
    FIsNull: Boolean;
    FIsPKey: Boolean;
    FIsIdentity: Boolean;
    FPosition: Integer;
    FConstraintName: string;
    FReferencedTable: string;
    FReferencedColumn: string;
    FOnUpdateRule: string;
    FOnDeleteRule: string;
    FValue: Variant;
    FDefaultValue: Variant;
    FOriginalValue: Variant;  // valor original carregado; referencia p/ detetar alteracao (modelo v1.6.1: changed = valor atual <> valor original)
    FIsChanged: Boolean;
  public
    class function New(const AColumn, AColumnType: string; AIsNull, AIsPKey: Boolean): IField; overload;
    class function New: IField; overload;

    { IField - Metadados }
    function Table(const AValue: string): IField; overload;
    function Table: string; overload;
    function Column(const AValue: string): IField; overload;
    function Column: string; overload;
    function LogicalName(const AValue: string): IField; overload;
    function LogicalName: string; overload;
    function Description(const AValue: string): IField; overload;
    function Description: string; overload;
    function ColumnType(const AValue: string): IField; overload;
    function ColumnType: string; overload;
    function ColumnTypeCode(const AValue: Integer): IField; overload;
    function ColumnTypeCode: Integer; overload;

    { IField - Metadados de dimensao }
    function Size(const AValue: Integer): IField; overload;
    function Size: Integer; overload;
    function Precision(const AValue: Integer): IField; overload;
    function Precision: Integer; overload;
    function Scale(const AValue: Integer): IField; overload;
    function Scale: Integer; overload;

    function IsNull(const AValue: Boolean): IField; overload;
    function IsNull: Boolean; overload;
    function IsPKey(const AValue: Boolean): IField; overload;
    function IsPKey: Boolean; overload;
    function IsIdentity(const AValue: Boolean): IField; overload;
    function IsIdentity: Boolean; overload;
    function Position(const AValue: Integer): IField; overload;
    function Position: Integer; overload;
    function ConstraintName(const AValue: string): IField; overload;
    function ConstraintName: string; overload;
    function ReferencedTable(const AValue: string): IField; overload;
    function ReferencedTable: string; overload;
    function ReferencedColumn(const AValue: string): IField; overload;
    function ReferencedColumn: string; overload;
    function OnUpdateRule(const AValue: string): IField; overload;
    function OnUpdateRule: string; overload;
    function OnDeleteRule(const AValue: string): IField; overload;
    function OnDeleteRule: string; overload;

    { IField - Valor e estado }
    function Value: Variant; overload;
    function Value(const AValue: Variant): IField; overload;
    function OriginalValue: Variant; overload;
    function OriginalValue(const AValue: Variant): IField; overload;
    function ToDefault: IField;
    function IsChanged: Boolean;
    function SetColumnValue(const AValue: Variant): IField;
    function SetColumnValueWithoutChange(const AValue: Variant): IField;
    function MarkChanged: IField;
    function MarkUnchanged: IField;
    { B1 (conformidade F5, onda C5) - aliases de MarkChanged/MarkUnchanged;
      mantidos por decisao do owner (compat/ergonomia, 0 call-sites de
      producao) - ver nota completa em Databases.Interfaces.IField. }
    function SetAsChanged: IField;
    function SetAsUnchanged: IField;

    { IField - Helpers }
    { B1 - aliases de IsChanged/IsPKey; mantidos por decisao do owner (mesma
      nota de SetAsChanged, acima). }
    function IsFieldChanged: Boolean;
    function IsFieldPrimaryKey: Boolean;
    function FieldAllowsNull: Boolean;

    { IField - Serialização em 2 eixos }
    function StructureToJSON: string;
    function StructureFromJSON(const AJSON: string): IField;
    function StructureMergeFromJSON(const AJSON: string): IField;
    function ToJSON: string;
    function LoadFromJSON(const AJSON: string): IField;
    function FromJSON(const AJSON: string): IField;
    function MergeFromJSON(const AJSON: string): IField;

    { Onda S4 (ADITIVO) - eixo FULL - ver comentario completo em
      Databases.Interfaces.IField. }
    function ToFullJSON: string;
    function FromFullJSON(const AJSON: string): IField;
    function MergeFullFromJSON(const AJSON: string): IField;
    function Export(const AWithData: Boolean): string;
    function Import(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): IField;

    { IField - Cópia }
    function Clone: IField;
  end;

implementation

{ Helpers de parsing/serializacao JSON (free functions, uso interno da unit) }

{ Decompoe o conteudo entre parenteses de um texto de tipo de coluna:
  1 numero -> ASize (ex.: VARCHAR(50) -> 50; NUMERIC(18) -> 18);
  2 numeros separados por virgula -> APrecision,AScale (ex.: DECIMAL(10,2));
  sem parenteses (ou vazio) -> 0,0,0. }
procedure ParseColumnTypeDimensions(const AColumnType: string; out ASize, APrecision, AScale: Integer);
var
  LOpenPos, LClosePos, LCommaPos: Integer;
  LInner, LPart1, LPart2: string;
begin
  ASize := 0;
  APrecision := 0;
  AScale := 0;
  LOpenPos := Pos('(', AColumnType);
  LClosePos := Pos(')', AColumnType);
  if (LOpenPos = 0) or (LClosePos = 0) or (LClosePos < LOpenPos) then
    Exit;
  LInner := Trim(Copy(AColumnType, LOpenPos + 1, LClosePos - LOpenPos - 1));
  if LInner = '' then
    Exit;
  LCommaPos := Pos(',', LInner);
  if LCommaPos > 0 then
  begin
    LPart1 := Trim(Copy(LInner, 1, LCommaPos - 1));
    LPart2 := Trim(Copy(LInner, LCommaPos + 1, Length(LInner) - LCommaPos));
    APrecision := StrToIntDef(LPart1, 0);
    AScale := StrToIntDef(LPart2, 0);
  end
  else
    ASize := StrToIntDef(LInner, 0);
end;

{ Onda C5 (M7, conformidade F5): JSONQuoteString local removida; delega ao
  SSOT unico Database.Helpers.JSON.JSONQuoteString (regra #14). Zero
  call-sites mudam de nome (era ja "JSONQuoteString" aqui, agora o import). }

function JSONBoolLiteral(const AValue: Boolean): string;
begin
  if AValue then
    Result := 'true'
  else
    Result := 'false';
end;

{ Converte um Variant (o "value" do eixo DADO) para o literal JSON equivalente.
  Datas -> ISO-8601 LOCAL (UTC opt-in=False); Null/Unassigned -> "null";
  numericos -> literal numerico (separador decimal '.' forcado); resto -> string
  escapada. }
function VariantToJSONLiteral(const AValue: Variant): string;
var
  LFS: TFormatSettings;
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
    Exit('null');
  {$IF DEFINED(FPC)}
  LFS := DefaultFormatSettings;
  {$ELSE}
  LFS := FormatSettings;
  {$ENDIF}
  LFS.DecimalSeparator := '.';
  case VarType(AValue) and varTypeMask of
    varBoolean:
      Result := JSONBoolLiteral(Boolean(AValue));
    varDate:
      Result := JSONQuoteString(DateToISO8601(VarToDateTime(AValue), False));
    varByte, varSmallInt, varInteger, varShortInt, varWord, varLongWord,
    varInt64{$IFNDEF FPC}, varUInt64{$ENDIF}:
      Result := IntToStr(Int64(AValue));
    varSingle, varDouble, varCurrency:
      Result := FloatToStr(Double(AValue), LFS);
  else
    Result := JSONQuoteString(VarToStr(AValue));
  end;
end;

{ Converte o node "value" (ja localizado no objecto JSON) de volta a Variant.
  Numero com fracao 0 -> Int64 (preserva o round-trip de inteiros); numero com
  fracao -> Double; boolean/string/null tratados directamente. Implementacao
  duplicada por compilador (padrao de Connections.pas.LoadFromJSON - APIs
  fpjson/System.JSON nao sao unificaveis por macro sem perder legibilidade). }
{$IF DEFINED(FPC)}
function JSONNodeToVariant(ANode: TJSONData): Variant;
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
function JSONNodeToVariant(ANode: TJSONValue): Variant;
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

{ TField }

class function TField.New(const AColumn, AColumnType: string; AIsNull, AIsPKey: Boolean): IField;
begin
  Result := TField.Create;
  Result.Column(AColumn).ColumnType(AColumnType).IsNull(AIsNull).IsPKey(AIsPKey);
end;

class function TField.New: IField;
begin
  Result := TField.Create;
end;

function TField.Table(const AValue: string): IField;
begin
  FTable := AValue;
  Result := Self;
end;

function TField.Table: string;
begin
  Result := FTable;
end;

function TField.Column(const AValue: string): IField;
begin
  FColumn := AValue;
  Result := Self;
end;

function TField.Column: string;
begin
  Result := FColumn;
end;

function TField.LogicalName(const AValue: string): IField;
begin
  FLogicalName := AValue;
  Result := Self;
end;

function TField.LogicalName: string;
begin
  Result := FLogicalName;
end;

function TField.Description(const AValue: string): IField;
begin
  FDescription := AValue;
  Result := Self;
end;

function TField.Description: string;
begin
  Result := FDescription;
end;

function TField.ColumnType(const AValue: string): IField;
begin
  FColumnType := AValue;
  { parser de dimensao (Fatia B-a): decompoe o conteudo entre parenteses em
    Size (1 numero) ou Precision/Scale (2 numeros); ColumnType mantem-se com
    a string COMPLETA (ex.: 'DECIMAL(10,2)'). }
  ParseColumnTypeDimensions(AValue, FSize, FPrecision, FScale);
  Result := Self;
end;

function TField.ColumnType: string;
begin
  Result := FColumnType;
end;

function TField.ColumnTypeCode(const AValue: Integer): IField;
begin
  FColumnTypeCode := AValue;
  Result := Self;
end;

function TField.ColumnTypeCode: Integer;
begin
  Result := FColumnTypeCode;
end;

function TField.Size(const AValue: Integer): IField;
begin
  FSize := AValue;
  Result := Self;
end;

function TField.Size: Integer;
begin
  Result := FSize;
end;

function TField.Precision(const AValue: Integer): IField;
begin
  FPrecision := AValue;
  Result := Self;
end;

function TField.Precision: Integer;
begin
  Result := FPrecision;
end;

function TField.Scale(const AValue: Integer): IField;
begin
  FScale := AValue;
  Result := Self;
end;

function TField.Scale: Integer;
begin
  Result := FScale;
end;

function TField.IsNull(const AValue: Boolean): IField;
begin
  FIsNull := AValue;
  Result := Self;
end;

function TField.IsNull: Boolean;
begin
  Result := FIsNull;
end;

function TField.IsPKey(const AValue: Boolean): IField;
begin
  FIsPKey := AValue;
  Result := Self;
end;

function TField.IsPKey: Boolean;
begin
  Result := FIsPKey;
end;

function TField.IsIdentity(const AValue: Boolean): IField;
begin
  FIsIdentity := AValue;
  Result := Self;
end;

function TField.IsIdentity: Boolean;
begin
  Result := FIsIdentity;
end;

function TField.Position(const AValue: Integer): IField;
begin
  FPosition := AValue;
  Result := Self;
end;

function TField.Position: Integer;
begin
  Result := FPosition;
end;

function TField.ConstraintName(const AValue: string): IField;
begin
  FConstraintName := AValue;
  Result := Self;
end;

function TField.ConstraintName: string;
begin
  Result := FConstraintName;
end;

function TField.ReferencedTable(const AValue: string): IField;
begin
  FReferencedTable := AValue;
  Result := Self;
end;

function TField.ReferencedTable: string;
begin
  Result := FReferencedTable;
end;

function TField.ReferencedColumn(const AValue: string): IField;
begin
  FReferencedColumn := AValue;
  Result := Self;
end;

function TField.ReferencedColumn: string;
begin
  Result := FReferencedColumn;
end;

function TField.OnUpdateRule(const AValue: string): IField;
begin
  FOnUpdateRule := AValue;
  Result := Self;
end;

function TField.OnUpdateRule: string;
begin
  Result := FOnUpdateRule;
end;

function TField.OnDeleteRule(const AValue: string): IField;
begin
  FOnDeleteRule := AValue;
  Result := Self;
end;

function TField.OnDeleteRule: string;
begin
  Result := FOnDeleteRule;
end;

function TField.Value: Variant;
begin
  Result := FValue;
end;

function TField.Value(const AValue: Variant): IField;
begin
  FValue := AValue;
  FIsChanged := VarToStr(AValue) <> VarToStr(FOriginalValue);
  Result := Self;
end;

function TField.OriginalValue: Variant;
begin
  Result := FOriginalValue;
end;

function TField.OriginalValue(const AValue: Variant): IField;
begin
  FOriginalValue := AValue;
  FIsChanged := VarToStr(FValue) <> VarToStr(FOriginalValue);
  Result := Self;
end;

function TField.ToDefault: IField;
begin
  FValue := FDefaultValue;
  FOriginalValue := FDefaultValue;
  FIsChanged := False;
  Result := Self;
end;

function TField.IsChanged: Boolean;
begin
  Result := FIsChanged;
end;

function TField.SetColumnValue(const AValue: Variant): IField;
begin
  FValue := AValue;
  { dirty inteligente (modelo v1.6.1): so marca changed se difere do valor original;
    voltar ao valor original zera automaticamente o IsChanged. }
  FIsChanged := VarToStr(AValue) <> VarToStr(FOriginalValue);
  Result := Self;
end;

function TField.SetColumnValueWithoutChange(const AValue: Variant): IField;
begin
  { carregar "limpo" (hidratacao do banco): define o valor E o valor original; nao dirty. }
  FValue := AValue;
  FOriginalValue := AValue;
  FIsChanged := False;
  Result := Self;
end;

function TField.MarkChanged: IField;
begin
  FIsChanged := True;
  Result := Self;
end;

function TField.MarkUnchanged: IField;
begin
  FOriginalValue := FValue;
  FIsChanged := False;
  Result := Self;
end;

function TField.SetAsChanged: IField;
begin
  FIsChanged := True;
  Result := Self;
end;

function TField.SetAsUnchanged: IField;
begin
  FOriginalValue := FValue;
  FIsChanged := False;
  Result := Self;
end;

function TField.IsFieldChanged: Boolean;
begin
  Result := FIsChanged;
end;

function TField.IsFieldPrimaryKey: Boolean;
begin
  Result := FIsPKey;
end;

function TField.FieldAllowsNull: Boolean;
begin
  Result := FIsNull;
end;

function TField.StructureToJSON: string;
begin
  { EIXO ESTRUTURA - metadados de esquema, SEM valor. }
  Result := '{' +
    '"column":' + JSONQuoteString(FColumn) + ',' +
    '"columnType":' + JSONQuoteString(FColumnType) + ',' +
    '"size":' + IntToStr(FSize) + ',' +
    '"precision":' + IntToStr(FPrecision) + ',' +
    '"scale":' + IntToStr(FScale) + ',' +
    '"isNull":' + JSONBoolLiteral(FIsNull) + ',' +
    '"isPKey":' + JSONBoolLiteral(FIsPKey) + ',' +
    '"isIdentity":' + JSONBoolLiteral(FIsIdentity) + ',' +
    '"position":' + IntToStr(FPosition) + ',' +
    '"columnTypeCode":' + IntToStr(FColumnTypeCode) + ',' +
    '"constraintName":' + JSONQuoteString(FConstraintName) + ',' +
    '"referencedTable":' + JSONQuoteString(FReferencedTable) + ',' +
    '"referencedColumn":' + JSONQuoteString(FReferencedColumn) + ',' +
    '"onUpdateRule":' + JSONQuoteString(FOnUpdateRule) + ',' +
    '"onDeleteRule":' + JSONQuoteString(FOnDeleteRule) + ',' +
    { B2 (conformidade F5, onda C6) - Description/LogicalName entram no eixo
      ESTRUTURA (fecha a assimetria com Clone, que ja os preservava). Default
      '' - round-trip StructureToJSON->StructureFromJSON de campos antigos
      (sem estes 2 valores) continua a produzir ''/'' via LObj.Get/GetValue
      com o default FDescription/FLogicalName correntes. }
    '"description":' + JSONQuoteString(FDescription) + ',' +
    '"logicalName":' + JSONQuoteString(FLogicalName) +
  '}';
end;

function TField.StructureFromJSON(const AJSON: string): IField;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
begin
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
    Column(LObj.Get('column', FColumn));
    ColumnType(LObj.Get('columnType', FColumnType)); // ja aplica o parser de Size/Precision/Scale
    Size(LObj.Get('size', FSize));
    Precision(LObj.Get('precision', FPrecision));
    Scale(LObj.Get('scale', FScale));
    IsNull(LObj.Get('isNull', FIsNull));
    IsPKey(LObj.Get('isPKey', FIsPKey));
    IsIdentity(LObj.Get('isIdentity', FIsIdentity));
    Position(LObj.Get('position', FPosition));
    ColumnTypeCode(LObj.Get('columnTypeCode', FColumnTypeCode));
    ConstraintName(LObj.Get('constraintName', FConstraintName));
    ReferencedTable(LObj.Get('referencedTable', FReferencedTable));
    ReferencedColumn(LObj.Get('referencedColumn', FReferencedColumn));
    OnUpdateRule(LObj.Get('onUpdateRule', FOnUpdateRule));
    OnDeleteRule(LObj.Get('onDeleteRule', FOnDeleteRule));
    Description(LObj.Get('description', FDescription));
    LogicalName(LObj.Get('logicalName', FLogicalName));
  finally
    LObj.Free;
  end;
end;
{$ELSE}
var
  LVal: TJSONValue;
  LObj: TJSONObject;
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
    Column(LObj.GetValue<string>('column', FColumn));
    ColumnType(LObj.GetValue<string>('columnType', FColumnType)); // ja aplica o parser de Size/Precision/Scale
    Size(LObj.GetValue<Integer>('size', FSize));
    Precision(LObj.GetValue<Integer>('precision', FPrecision));
    Scale(LObj.GetValue<Integer>('scale', FScale));
    IsNull(LObj.GetValue<Boolean>('isNull', FIsNull));
    IsPKey(LObj.GetValue<Boolean>('isPKey', FIsPKey));
    IsIdentity(LObj.GetValue<Boolean>('isIdentity', FIsIdentity));
    Position(LObj.GetValue<Integer>('position', FPosition));
    ColumnTypeCode(LObj.GetValue<Integer>('columnTypeCode', FColumnTypeCode));
    ConstraintName(LObj.GetValue<string>('constraintName', FConstraintName));
    ReferencedTable(LObj.GetValue<string>('referencedTable', FReferencedTable));
    ReferencedColumn(LObj.GetValue<string>('referencedColumn', FReferencedColumn));
    OnUpdateRule(LObj.GetValue<string>('onUpdateRule', FOnUpdateRule));
    OnDeleteRule(LObj.GetValue<string>('onDeleteRule', FOnDeleteRule));
    Description(LObj.GetValue<string>('description', FDescription));
    LogicalName(LObj.GetValue<string>('logicalName', FLogicalName));
  finally
    LObj.Free;
  end;
end;
{$ENDIF}

function TField.ToJSON: string;
begin
  { EIXO DADO - so o valor corrente do campo (deixou de ser hibrido). }
  Result := '{"value":' + VariantToJSONLiteral(FValue) + '}';
end;

function TField.LoadFromJSON(const AJSON: string): IField;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
begin
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
    { hidratacao "limpa" (carga de dado, nao edicao do utilizador): define o
      valor E o valor original, nao marca dirty (mesma semantica usada por
      EntityManager.MapTable ao hidratar a partir do ICatalogReader). }
    SetColumnValueWithoutChange(JSONNodeToVariant(LObj.Find('value')));
  finally
    LObj.Free;
  end;
end;
{$ELSE}
var
  LVal: TJSONValue;
  LObj: TJSONObject;
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
    SetColumnValueWithoutChange(JSONNodeToVariant(LObj.GetValue('value')));
  finally
    LObj.Free;
  end;
end;
{$ENDIF}

function TField.StructureMergeFromJSON(const AJSON: string): IField;
begin
  { Onda S2-a (ADITIVO, simetria To/From/Merge) - PATCH de metadata:
    StructureFromJSON ja le cada chave via Get/GetValue com DEFAULT = valor
    CORRENTE do respetivo campo (ex.: Column(LObj.Get('column', FColumn)) -
    se "column" estiver ausente no JSON, o default e o proprio FColumn, ou
    seja, mantem-se inalterado) - a nivel de UM campo isolado (sem
    sub-colecao) isto JA E o comportamento de patch aditivo (nunca reseta
    uma chave ausente para vazio/0/False); reutiliza-se directamente, sem
    duplicar o parse. }
  Result := StructureFromJSON(AJSON);
end;

function TField.FromJSON(const AJSON: string): IField;
begin
  { Onda S2-a (ADITIVO, simetria To/From/Merge) - "replace" no eixo DADO;
    mesmo mecanismo de LoadFromJSON (SetColumnValueWithoutChange -
    hidratacao limpa, IsChanged fica false), delegado por reuso directo
    (sem logica nova) para expor o nome canonico do trio To/From/Merge ja
    usado nos restantes niveis (Fields/Table/Tables/Schema/Schemas/
    Database/Databases). }
  Result := LoadFromJSON(AJSON);
end;

function TField.MergeFromJSON(const AJSON: string): IField;
{$IF DEFINED(FPC)}
var
  LData: TJSONData;
  LObj: TJSONObject;
begin
  { Onda S2-a (ADITIVO) - "patch" no eixo DADO: mesmo parse de LoadFromJSON/
    FromJSON, mas hidrata via SetColumnValue (dirty inteligente - so fica
    IsChanged=True quando o valor realmente difere de OriginalValue) em vez
    de SetColumnValueWithoutChange (hidratacao limpa). Um campo tem um so
    valor -> a semantica de "patch" fica no TRACKING de dirty, nao na
    selectividade de chaves (essa fica em StructureMergeFromJSON, aplicada
    aos METADADOS, acima). }
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
    SetColumnValue(JSONNodeToVariant(LObj.Find('value')));
  finally
    LObj.Free;
  end;
end;
{$ELSE}
var
  LVal: TJSONValue;
  LObj: TJSONObject;
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
    SetColumnValue(JSONNodeToVariant(LObj.GetValue('value')));
  finally
    LObj.Free;
  end;
end;
{$ENDIF}

function TField.ToFullJSON: string;
begin
  { Onda S4 (ADITIVO) - COMPOE os 2 eixos JA EXISTENTES (StructureToJSON/
    ToJSON), sem reimplementar nenhum dos 2 - ambos ja emitem JSON valido
    (objecto), so concatenados sob as chaves "structure"/"data". }
  Result := '{"structure":' + StructureToJSON + ',"data":' + ToJSON + '}';
end;

function TField.FromFullJSON(const AJSON: string): IField;
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

function TField.MergeFullFromJSON(const AJSON: string): IField;
var
  LStructure, LData: string;
begin
  { Onda S4 (ADITIVO) - mesma decomposicao de FromFullJSON, mas delega aos
    "patch" StructureMergeFromJSON/MergeFromJSON. }
  Result := Self;
  LStructure := JSONExtractMember(AJSON, 'structure');
  if LStructure <> '' then
    StructureMergeFromJSON(LStructure);
  LData := JSONExtractMember(AJSON, 'data');
  if LData <> '' then
    MergeFromJSON(LData);
end;

function TField.Export(const AWithData: Boolean): string;
begin
  { Onda S4 (ADITIVO) - atalho ergonomico: False -> so ESTRUTURA; True ->
    FULL (estrutura+dado). }
  if AWithData then
    Result := ToFullJSON
  else
    Result := StructureToJSON;
end;

function TField.Import(const AJSON: string; const AWithData: Boolean; const AMerge: Boolean): IField;
begin
  { Onda S4 (ADITIVO) - despacha pelas 2 flags para o metodo To/From/Merge
    ja existente correspondente (ver tabela completa em
    Databases.Interfaces.IField.Export/Import). }
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

function TField.Clone: IField;
begin
  Result := TField.New(Column, ColumnType, IsNull, IsPKey);
  Result.Table(Table).LogicalName(LogicalName).Description(Description).Position(Position).ConstraintName(ConstraintName);
  Result.IsIdentity(IsIdentity);
  Result.ReferencedTable(ReferencedTable).ReferencedColumn(ReferencedColumn);
  Result.OnUpdateRule(OnUpdateRule).OnDeleteRule(OnDeleteRule);
  { override explicito p/ preservar Size/Precision/Scale mesmo quando divergem
    do parse derivado do texto de ColumnType (setter fluente chamado depois). }
  Result.Size(Size).Precision(Precision).Scale(Scale);
  Result.SetColumnValueWithoutChange(Value);
  if not IsChanged then
    Result.MarkUnchanged;
end;

end.
