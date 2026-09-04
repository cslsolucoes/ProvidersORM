{ =============================================================================
  Attributers.Parameters - Parser e Mapper de atributos RTTI (TAttributeParser,
  TAttributeMapper) para o mapeamento Classe <-> TParameter/TParameterList

  FASE 6 Onda 6.2. Fundido de 2 fontes (owner 03/08, via AskUserQuestion):
  logica do Parser/Mapper e' quase identica entre o standalone v1.0.7
  (`FontesReferencias\ParamentersORM\src\Attributes\Parameters.Attributes.pas`)
  e a SSOT v2.2.0/2.3.0 (`Attributers.Parameters.pas`) - a fusao real esta nos
  `uses`: em vez de reimplementar Consts/Exceptions locais (como o standalone
  fazia, auto-contido) ou depender de `Commons.Parameters.Types` (que a SSOT
  usava e que **NAO existe no v3** - eliminado por D11-a, "nada exclusivo"),
  este ficheiro reusa o que a F7 (Parameters v3) e a F1 (Commons) ja
  entregaram: `Commons.Types` (TParameter/TParameterList/TParameterValueType/
  TParameterSource), `Commons.Parameters.Consts` (DEFAULT_CONTRATO_ID/
  DEFAULT_PRODUTO_ID/DEFAULT_PARAMETER_ORDER), `Commons.Consts`
  (DEFAULT_PARAMETER_SOURCE) e `Exceptions.Parameters`
  (EParametersAttributeException + ERR_ATTRIBUTE_*_CODE + MSG_ATTRIBUTE_* -
  JA migrados de Parameters.Attributes.Exceptions.pas numa sessao anterior,
  confirmado por leitura antes de escrever este ficheiro - zero duplicacao).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  2.0.0 (Parameters - modulo que estes atributos mapeiam)
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.1.0 (03/08/2026): bug-1132 (achado real, isolado por spike) - substituido
    `ARttiProperty.GetValue(AInstance).AsVariant` por `TypInfo.GetPropValue
    (AInstance, ARttiProperty.Name)` em ParsePropertyToParameter e
    TAttributeMapper.GetPropertyValue: no FPC 3.3.1, TValue.AsVariant lanca
    EInvalidCast para tipos simples (string/Integer) mesmo com TValue valido
    (TValue.ToString funciona) - GetPropValue (RTTI classica de TypInfo) da'
    o valor certo nos DOIS compiladores (confirmado por spike isolado antes
    de tocar no ficheiro real). Sem isto, ParseClass(instancia)/GetParameterValue
    caiam silenciosamente no valor DEFAULT do atributo [ParameterValue] em vez
    do valor real da instancia, no FPC.
  - 1.0.0 (03/08/2026): FASE 6 Onda 6.2 - TAttributeParser/TAttributeMapper
    absorvidos (logica fiel ao standalone v1.0.7/SSOT v2.3.0), reescritos os
    uses para o nucleo v3 existente (zero Consts/Exceptions/Types novos).
  ============================================================================= }

unit Attributers.Parameters;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$HINTS OFF}
{$I ORM.Defines.inc}

uses
  Attributers.Parameters.Interfaces,
  Commons.Types,
{$IF DEFINED(FPC)}
  Rtti;
{$ELSE}
  System.RTTI;
{$ENDIF}

{$IFDEF USE_ATTRIBUTES}
type
  TAttributeParser = class(TInterfacedObject, IAttributeParser)
  private
    FRttiContext: TRttiContext;
    function GetRttiType(const AClassType: TClass): TRttiType;
    function GetParameterAttribute(const ARttiType: TRttiType): ParameterAttribute;
    function GetContratoIDAttribute(const ARttiType: TRttiType): ContratoIDAttribute;
    function GetProdutoIDAttribute(const ARttiType: TRttiType): ProdutoIDAttribute;
    function GetParameterSourceAttribute(const ARttiType: TRttiType): ParameterSourceAttribute;
    function HasAttribute<T: TCustomAttribute>(const ARttiProperty: TRttiProperty): Boolean;
    function GetAttribute<T: TCustomAttribute>(const ARttiProperty: TRttiProperty): T;
    function ConvertRttiTypeToValueType(const ARttiType: TRttiType): TParameterValueType;
    function GetParameterKey(const ARttiProperty: TRttiProperty): string;
    function GetParameterValue(const ARttiProperty: TRttiProperty): Variant;
    function GetParameterDescription(const ARttiProperty: TRttiProperty): string;
    function GetParameterValueType(const ARttiProperty: TRttiProperty): TParameterValueType;
    function GetParameterOrder(const ARttiProperty: TRttiProperty): Integer;
    function IsParameterRequired(const ARttiProperty: TRttiProperty): Boolean;
    function VariantToString(const AValue: Variant; const AValueType: TParameterValueType): string;
    function ParsePropertyToParameter(const ARttiProperty: TRttiProperty; const AInstance: TObject;
      const ATitulo: string; const AContratoID, AProdutoID: Integer): TParameter;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: IAttributeParser;
    function ParseClass(const AClassType: TClass): TParameterList; overload;
    function ParseClass(const AInstance: TObject): TParameterList; overload;
    function GetClassTitle(const AClassType: TClass): string; overload;
    function GetClassTitle(const AInstance: TObject): string; overload;
    function GetClassContratoID(const AClassType: TClass): Integer; overload;
    function GetClassContratoID(const AInstance: TObject): Integer; overload;
    function GetClassProdutoID(const AClassType: TClass): Integer; overload;
    function GetClassProdutoID(const AInstance: TObject): Integer; overload;
    function GetClassSource(const AClassType: TClass): TParameterSource; overload;
    function GetClassSource(const AInstance: TObject): TParameterSource; overload;
    function GetParameterProperties(const AClassType: TClass): TStringArray; overload;
    function GetParameterProperties(const AInstance: TObject): TStringArray; overload;
    function GetPropertyKey(const AInstance: TObject; const APropertyName: string): string;
    function GetPropertyDefaultValue(const AInstance: TObject; const APropertyName: string): Variant;
    function GetPropertyDescription(const AInstance: TObject; const APropertyName: string): string;
    function GetPropertyValueType(const AInstance: TObject; const APropertyName: string): TParameterValueType;
    function GetPropertyOrder(const AInstance: TObject; const APropertyName: string): Integer;
    function IsPropertyRequired(const AInstance: TObject; const APropertyName: string): Boolean;
    function ValidateClass(const AClassType: TClass): Boolean; overload;
    function ValidateClass(const AInstance: TObject): Boolean; overload;
  end;

  TAttributeMapper = class(TInterfacedObject, IAttributeMapper)
  private
    FRttiContext: TRttiContext;
    FParser: TAttributeParser;
    function GetRttiType(const AClassType: TClass): TRttiType;
    function GetRttiPropertyByKey(const ARttiType: TRttiType; const AParameterKey: string): TRttiProperty;
    function SetPropertyValue(const AInstance: TObject; const AProperty: TRttiProperty; const AValue: Variant): Boolean;
    function GetPropertyValue(const AInstance: TObject; const AProperty: TRttiProperty): Variant;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: IAttributeMapper;
    function MapClassToParameters(const AClassType: TClass): TParameterList; overload;
    function MapClassToParameters(const AInstance: TObject): TParameterList; overload;
    function MapParametersToClass(AParameters: TParameterList; AInstance: TObject): IAttributeMapper; overload;
    function SetParameterValue(AInstance: TObject; const AParameterKey: string; const AValue: Variant): IAttributeMapper; overload;
    function GetParameterValue(const AInstance: TObject; const AParameterKey: string): Variant; overload;
  end;

var
  { Instancia singleton do parser (criada na primeira leitura). }
  AttributeParser: IAttributeParser;
  { Instancia singleton do mapper (criada na primeira leitura). }
  AttributeMapper: IAttributeMapper;
{$ENDIF}

{$HINTS ON}

{$IFDEF USE_ATTRIBUTES}
implementation

{$HINTS OFF}
uses
{$IF DEFINED(FPC)}
  TypInfo, SysUtils, StrUtils, Variants,
{$ELSE}
  System.TypInfo, System.SysUtils, System.StrUtils, System.Variants,
{$ENDIF}
  Commons.Parameters.Consts,
  Commons.Consts,
  Exceptions.Parameters;

function CreateParameterNotFoundException(const AClassName, AOperation: string): EParametersAttributeException;
begin
  Result := EParametersAttributeException.Create(
    Format(MSG_ATTRIBUTE_PARAMETER_NOT_FOUND, [AClassName]),
    ERR_ATTRIBUTE_PARAMETER_NOT_FOUND_CODE,
    AOperation
  );
end;

function CreateRTTINotAvailableException(const AClassName, AOperation: string): EParametersAttributeException;
var
  LMsg: string;
begin
  if AClassName = '' then
    LMsg := MSG_ATTRIBUTE_RTTI_NOT_AVAILABLE
  else
    LMsg := Format(MSG_ATTRIBUTE_RTTI_NOT_AVAILABLE, [AClassName]);
  Result := EParametersAttributeException.Create(LMsg, ERR_ATTRIBUTE_RTTI_NOT_AVAILABLE_CODE, AOperation);
end;

{ TAttributeParser }

constructor TAttributeParser.Create;
begin
  inherited Create;
  FRttiContext := TRttiContext.Create;
end;

destructor TAttributeParser.Destroy;
begin
  FRttiContext.Free;
  inherited Destroy;
end;

class function TAttributeParser.New: IAttributeParser;
begin
  Result := TAttributeParser.Create;
end;

function TAttributeParser.GetRttiType(const AClassType: TClass): TRttiType;
begin
  Result := FRttiContext.GetType(AClassType);
  if Result = nil then
    raise CreateRTTINotAvailableException(AClassType.ClassName, 'GetRttiType');
end;

function TAttributeParser.GetParameterAttribute(const ARttiType: TRttiType): ParameterAttribute;
var
  LAttr: TCustomAttribute;
begin
  Result := nil;
  for LAttr in ARttiType.GetAttributes do
    if LAttr is ParameterAttribute then
    begin
      Result := ParameterAttribute(LAttr);
      Exit;
    end;
end;

function TAttributeParser.GetContratoIDAttribute(const ARttiType: TRttiType): ContratoIDAttribute;
var
  LAttr: TCustomAttribute;
begin
  Result := nil;
  for LAttr in ARttiType.GetAttributes do
    if LAttr is ContratoIDAttribute then
    begin
      Result := ContratoIDAttribute(LAttr);
      Exit;
    end;
end;

function TAttributeParser.GetProdutoIDAttribute(const ARttiType: TRttiType): ProdutoIDAttribute;
var
  LAttr: TCustomAttribute;
begin
  Result := nil;
  for LAttr in ARttiType.GetAttributes do
    if LAttr is ProdutoIDAttribute then
    begin
      Result := ProdutoIDAttribute(LAttr);
      Exit;
    end;
end;

function TAttributeParser.GetParameterSourceAttribute(const ARttiType: TRttiType): ParameterSourceAttribute;
var
  LAttr: TCustomAttribute;
begin
  Result := nil;
  for LAttr in ARttiType.GetAttributes do
    if LAttr is ParameterSourceAttribute then
    begin
      Result := ParameterSourceAttribute(LAttr);
      Exit;
    end;
end;

function TAttributeParser.HasAttribute<T>(const ARttiProperty: TRttiProperty): Boolean;
var
  LAttr: TCustomAttribute;
begin
  Result := False;
  for LAttr in ARttiProperty.GetAttributes do
    if LAttr is T then
    begin
      Result := True;
      Exit;
    end;
end;

function TAttributeParser.GetAttribute<T>(const ARttiProperty: TRttiProperty): T;
var
  LAttr: TCustomAttribute;
begin
  Result := nil;
  for LAttr in ARttiProperty.GetAttributes do
    if LAttr is T then
    begin
      Result := T(LAttr);
      Exit;
    end;
end;

function TAttributeParser.ConvertRttiTypeToValueType(const ARttiType: TRttiType): TParameterValueType;
var
  LTypeName: string;
begin
  case ARttiType.TypeKind of
    tkInteger, tkInt64:
      Result := pvtInteger;
    tkFloat:
    begin
      LTypeName := ARttiType.Name;
      if (SameText(LTypeName, 'TDateTime')) or (SameText(LTypeName, 'TDate')) or (SameText(LTypeName, 'TTime')) then
        Result := pvtDateTime
      else
        Result := pvtFloat;
    end;
    tkEnumeration:
    begin
      LTypeName := ARttiType.Name;
      if SameText(LTypeName, 'Boolean') then
        Result := pvtBoolean
      else
        Result := pvtInteger;
    end;
    tkString, tkLString, tkWString, tkUString:
      Result := pvtString;
    tkChar, tkWChar:
      Result := pvtString;
  else
    Result := pvtString;
  end;
end;

function TAttributeParser.GetParameterKey(const ARttiProperty: TRttiProperty): string;
var
  LKeyAttr: ParameterKeyAttribute;
begin
  Result := '';
  LKeyAttr := GetAttribute<ParameterKeyAttribute>(ARttiProperty);
  if LKeyAttr <> nil then
    Result := LKeyAttr.Key;
end;

function TAttributeParser.GetParameterValue(const ARttiProperty: TRttiProperty): Variant;
var
  LValueAttr: ParameterValueAttribute;
begin
  Result := Null;
  LValueAttr := GetAttribute<ParameterValueAttribute>(ARttiProperty);
  if LValueAttr <> nil then
    Result := LValueAttr.Value;
end;

function TAttributeParser.GetParameterDescription(const ARttiProperty: TRttiProperty): string;
var
  LDescAttr: ParameterDescriptionAttribute;
begin
  Result := '';
  LDescAttr := GetAttribute<ParameterDescriptionAttribute>(ARttiProperty);
  if LDescAttr <> nil then
    Result := LDescAttr.Description;
end;

function TAttributeParser.GetParameterValueType(const ARttiProperty: TRttiProperty): TParameterValueType;
var
  LTypeAttr: ParameterTypeAttribute;
begin
  LTypeAttr := GetAttribute<ParameterTypeAttribute>(ARttiProperty);
  if LTypeAttr <> nil then
    Result := LTypeAttr.ValueType
  else
    Result := ConvertRttiTypeToValueType(ARttiProperty.PropertyType);
end;

function TAttributeParser.GetParameterOrder(const ARttiProperty: TRttiProperty): Integer;
var
  LOrderAttr: ParameterOrderAttribute;
begin
  Result := DEFAULT_PARAMETER_ORDER;
  LOrderAttr := GetAttribute<ParameterOrderAttribute>(ARttiProperty);
  if LOrderAttr <> nil then
    Result := LOrderAttr.Order;
end;

function TAttributeParser.IsParameterRequired(const ARttiProperty: TRttiProperty): Boolean;
begin
  Result := HasAttribute<ParameterRequiredAttribute>(ARttiProperty);
end;

function TAttributeParser.VariantToString(const AValue: Variant; const AValueType: TParameterValueType): string;
var
  LIntValue: Int64;
  LFloatValue: Double;
  LBoolValue: Boolean;
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
  begin
    Result := '';
    Exit;
  end;
  case AValueType of
    pvtString:
      Result := VarToStr(AValue);
    pvtInteger:
      begin
        try
          LIntValue := VarAsType(AValue, varInt64);
          Result := IntToStr(LIntValue);
        except
          Result := IntToStr(Integer(AValue));
        end;
      end;
    pvtFloat:
      begin
        try
          LFloatValue := VarAsType(AValue, varDouble);
          Result := FloatToStr(LFloatValue);
        except
          Result := FloatToStr(Double(AValue));
        end;
      end;
    pvtBoolean:
      begin
        try
          LBoolValue := VarAsType(AValue, varBoolean);
          Result := IfThen(LBoolValue, 'True', 'False');
        except
          Result := IfThen(Boolean(AValue), 'True', 'False');
        end;
      end;
    pvtDateTime:
      Result := DateTimeToStr(VarToDateTime(AValue));
    pvtJSON:
      Result := VarToStr(AValue);
  else
    Result := VarToStr(AValue);
  end;
end;

function TAttributeParser.ParsePropertyToParameter(const ARttiProperty: TRttiProperty; const AInstance: TObject;
  const ATitulo: string; const AContratoID, AProdutoID: Integer): TParameter;
var
  LKey: string;
  LValueVariant: Variant;
begin
  Result := nil;
  LKey := GetParameterKey(ARttiProperty);
  if LKey = '' then
    Exit;
  Result := TParameter.Create;
  try
    Result.Titulo := ATitulo;
    Result.Name := LKey;
    Result.ContratoID := AContratoID;
    Result.ProdutoID := AProdutoID;
    Result.Ordem := GetParameterOrder(ARttiProperty);
    Result.Description := GetParameterDescription(ARttiProperty);
    Result.ValueType := GetParameterValueType(ARttiProperty);
    Result.Ativo := True;
    Result.CreatedAt := Now;
    Result.UpdatedAt := Now;
    if AInstance <> nil then
    begin
      try
        LValueVariant := GetPropValue(AInstance, ARttiProperty.Name);
        Result.Value := VariantToString(LValueVariant, Result.ValueType);
      except
        LValueVariant := GetParameterValue(ARttiProperty);
        if not VarIsNull(LValueVariant) then
          Result.Value := VariantToString(LValueVariant, Result.ValueType);
      end;
    end
    else
    begin
      LValueVariant := GetParameterValue(ARttiProperty);
      if not VarIsNull(LValueVariant) then
        Result.Value := VariantToString(LValueVariant, Result.ValueType);
    end;
  except
    Result.Free;
    Result := nil;
    raise;
  end;
end;

function TAttributeParser.ParseClass(const AClassType: TClass): TParameterList;
var
  LRttiType: TRttiType;
  LParamAttr: ParameterAttribute;
  LContratoIDAttr: ContratoIDAttribute;
  LProdutoIDAttr: ProdutoIDAttribute;
  LProperty: TRttiProperty;
  LParam: TParameter;
  LTitulo: string;
  LContratoID, LProdutoID: Integer;
begin
  LRttiType := GetRttiType(AClassType);
  LParamAttr := GetParameterAttribute(LRttiType);
  if LParamAttr = nil then
    raise CreateParameterNotFoundException(AClassType.ClassName, 'ParseClass');
  LTitulo := LParamAttr.Title;
  LContratoIDAttr := GetContratoIDAttribute(LRttiType);
  if LContratoIDAttr <> nil then
    LContratoID := LContratoIDAttr.ContratoID
  else
    LContratoID := DEFAULT_CONTRATO_ID;
  LProdutoIDAttr := GetProdutoIDAttribute(LRttiType);
  if LProdutoIDAttr <> nil then
    LProdutoID := LProdutoIDAttr.ProdutoID
  else
    LProdutoID := DEFAULT_PRODUTO_ID;
  Result := TParameterList.Create;
  for LProperty in LRttiType.GetProperties do
  begin
    LParam := ParsePropertyToParameter(LProperty, nil, LTitulo, LContratoID, LProdutoID);
    if LParam <> nil then
      Result.Add(LParam);
  end;
end;

function TAttributeParser.ParseClass(const AInstance: TObject): TParameterList;
var
  LClassType: TClass;
  LRttiType: TRttiType;
  LProperty: TRttiProperty;
  LParam: TParameter;
  LParamAttr: ParameterAttribute;
  LContratoIDAttr: ContratoIDAttribute;
  LProdutoIDAttr: ProdutoIDAttribute;
  LTitulo: string;
  LContratoID, LProdutoID: Integer;
  I: Integer;
begin
  if AInstance = nil then
    raise CreateRTTINotAvailableException('', 'ParseClass');
  LClassType := AInstance.ClassType;
  Result := ParseClass(LClassType);
  LRttiType := GetRttiType(LClassType);
  LParamAttr := GetParameterAttribute(LRttiType);
  if LParamAttr = nil then
    raise CreateParameterNotFoundException(LClassType.ClassName, 'ParseClass');
  LTitulo := LParamAttr.Title;
  LContratoIDAttr := GetContratoIDAttribute(LRttiType);
  if LContratoIDAttr <> nil then
    LContratoID := LContratoIDAttr.ContratoID
  else
    LContratoID := DEFAULT_CONTRATO_ID;
  LProdutoIDAttr := GetProdutoIDAttribute(LRttiType);
  if LProdutoIDAttr <> nil then
    LProdutoID := LProdutoIDAttr.ProdutoID
  else
    LProdutoID := DEFAULT_PRODUTO_ID;
  for LProperty in LRttiType.GetProperties do
  begin
    LParam := ParsePropertyToParameter(LProperty, AInstance, LTitulo, LContratoID, LProdutoID);
    if LParam <> nil then
    begin
      for I := 0 to Result.Count - 1 do
        if SameText(Result[I].Name, LParam.Name) then
        begin
          Result[I].Value := LParam.Value;
          LParam.Free;
          Break;
        end;
    end;
  end;
end;

function TAttributeParser.GetClassTitle(const AClassType: TClass): string;
var
  LRttiType: TRttiType;
  LParamAttr: ParameterAttribute;
begin
  LRttiType := GetRttiType(AClassType);
  LParamAttr := GetParameterAttribute(LRttiType);
  if LParamAttr = nil then
    raise CreateParameterNotFoundException(AClassType.ClassName, 'GetClassTitle');
  Result := LParamAttr.Title;
end;

function TAttributeParser.GetClassTitle(const AInstance: TObject): string;
begin
  if AInstance = nil then
    raise CreateRTTINotAvailableException('', 'GetClassTitle');
  Result := GetClassTitle(AInstance.ClassType);
end;

function TAttributeParser.GetClassContratoID(const AClassType: TClass): Integer;
var
  LRttiType: TRttiType;
  LContratoIDAttr: ContratoIDAttribute;
begin
  Result := DEFAULT_CONTRATO_ID;
  LRttiType := GetRttiType(AClassType);
  LContratoIDAttr := GetContratoIDAttribute(LRttiType);
  if LContratoIDAttr <> nil then
    Result := LContratoIDAttr.ContratoID;
end;

function TAttributeParser.GetClassContratoID(const AInstance: TObject): Integer;
begin
  if AInstance = nil then
    raise CreateRTTINotAvailableException('', 'GetClassContratoID');
  Result := GetClassContratoID(AInstance.ClassType);
end;

function TAttributeParser.GetClassProdutoID(const AClassType: TClass): Integer;
var
  LRttiType: TRttiType;
  LProdutoIDAttr: ProdutoIDAttribute;
begin
  Result := DEFAULT_PRODUTO_ID;
  LRttiType := GetRttiType(AClassType);
  LProdutoIDAttr := GetProdutoIDAttribute(LRttiType);
  if LProdutoIDAttr <> nil then
    Result := LProdutoIDAttr.ProdutoID;
end;

function TAttributeParser.GetClassProdutoID(const AInstance: TObject): Integer;
begin
  if AInstance = nil then
    raise CreateRTTINotAvailableException('', 'GetClassProdutoID');
  Result := GetClassProdutoID(AInstance.ClassType);
end;

function TAttributeParser.GetClassSource(const AClassType: TClass): TParameterSource;
var
  LRttiType: TRttiType;
  LSourceAttr: ParameterSourceAttribute;
begin
  Result := DEFAULT_PARAMETER_SOURCE;
  LRttiType := GetRttiType(AClassType);
  LSourceAttr := GetParameterSourceAttribute(LRttiType);
  if LSourceAttr <> nil then
    Result := LSourceAttr.Source;
end;

function TAttributeParser.GetClassSource(const AInstance: TObject): TParameterSource;
begin
  if AInstance = nil then
    raise CreateRTTINotAvailableException('', 'GetClassSource');
  Result := GetClassSource(AInstance.ClassType);
end;

function TAttributeParser.GetParameterProperties(const AClassType: TClass): Commons.Types.TStringArray;
var
  LRttiType: TRttiType;
  LProperty: TRttiProperty;
  LKey: string;
  LCount: Integer;
begin
  SetLength(Result, 0);
  LRttiType := GetRttiType(AClassType);
  LCount := 0;
  for LProperty in LRttiType.GetProperties do
  begin
    LKey := GetParameterKey(LProperty);
    if LKey <> '' then
    begin
      SetLength(Result, LCount + 1);
      Result[LCount] := LProperty.Name;
      Inc(LCount);
    end;
  end;
end;

function TAttributeParser.GetParameterProperties(const AInstance: TObject): Commons.Types.TStringArray;
begin
  if AInstance = nil then
    raise CreateRTTINotAvailableException('', 'GetParameterProperties');
  Result := GetParameterProperties(AInstance.ClassType);
end;

function TAttributeParser.GetPropertyKey(const AInstance: TObject; const APropertyName: string): string;
var
  LRttiType: TRttiType;
  LProperty: TRttiProperty;
begin
  Result := '';
  if AInstance = nil then
    Exit;
  LRttiType := GetRttiType(AInstance.ClassType);
  LProperty := LRttiType.GetProperty(APropertyName);
  if LProperty <> nil then
    Result := GetParameterKey(LProperty);
end;

function TAttributeParser.GetPropertyDefaultValue(const AInstance: TObject; const APropertyName: string): Variant;
var
  LRttiType: TRttiType;
  LProperty: TRttiProperty;
begin
  Result := Null;
  if AInstance = nil then
    Exit;
  LRttiType := GetRttiType(AInstance.ClassType);
  LProperty := LRttiType.GetProperty(APropertyName);
  if LProperty <> nil then
    Result := GetParameterValue(LProperty);
end;

function TAttributeParser.GetPropertyDescription(const AInstance: TObject; const APropertyName: string): string;
var
  LRttiType: TRttiType;
  LProperty: TRttiProperty;
begin
  Result := '';
  if AInstance = nil then
    Exit;
  LRttiType := GetRttiType(AInstance.ClassType);
  LProperty := LRttiType.GetProperty(APropertyName);
  if LProperty <> nil then
    Result := GetParameterDescription(LProperty);
end;

function TAttributeParser.GetPropertyValueType(const AInstance: TObject; const APropertyName: string): TParameterValueType;
var
  LRttiType: TRttiType;
  LProperty: TRttiProperty;
begin
  Result := pvtString;
  if AInstance = nil then
    Exit;
  LRttiType := GetRttiType(AInstance.ClassType);
  LProperty := LRttiType.GetProperty(APropertyName);
  if LProperty <> nil then
    Result := GetParameterValueType(LProperty);
end;

function TAttributeParser.GetPropertyOrder(const AInstance: TObject; const APropertyName: string): Integer;
var
  LRttiType: TRttiType;
  LProperty: TRttiProperty;
begin
  Result := DEFAULT_PARAMETER_ORDER;
  if AInstance = nil then
    Exit;
  LRttiType := GetRttiType(AInstance.ClassType);
  LProperty := LRttiType.GetProperty(APropertyName);
  if LProperty <> nil then
    Result := GetParameterOrder(LProperty);
end;

function TAttributeParser.IsPropertyRequired(const AInstance: TObject; const APropertyName: string): Boolean;
var
  LRttiType: TRttiType;
  LProperty: TRttiProperty;
begin
  Result := False;
  if AInstance = nil then
    Exit;
  LRttiType := GetRttiType(AInstance.ClassType);
  LProperty := LRttiType.GetProperty(APropertyName);
  if LProperty <> nil then
    Result := IsParameterRequired(LProperty);
end;

function TAttributeParser.ValidateClass(const AClassType: TClass): Boolean;
var
  LRttiType: TRttiType;
  LParamAttr: ParameterAttribute;
begin
  Result := False;
  try
    LRttiType := GetRttiType(AClassType);
    LParamAttr := GetParameterAttribute(LRttiType);
    Result := (LParamAttr <> nil);
  except
    Result := False;
  end;
end;

function TAttributeParser.ValidateClass(const AInstance: TObject): Boolean;
begin
  if AInstance = nil then
    raise CreateRTTINotAvailableException('', 'ValidateClass');
  Result := ValidateClass(AInstance.ClassType);
end;

{ TAttributeMapper }

constructor TAttributeMapper.Create;
begin
  inherited Create;
  FRttiContext := TRttiContext.Create;
  FParser := TAttributeParser.Create;
end;

destructor TAttributeMapper.Destroy;
begin
  FRttiContext.Free;
  FParser.Free;
  inherited Destroy;
end;

class function TAttributeMapper.New: IAttributeMapper;
begin
  Result := TAttributeMapper.Create;
end;

function TAttributeMapper.GetRttiType(const AClassType: TClass): TRttiType;
begin
  Result := FRttiContext.GetType(AClassType);
  if Result = nil then
    raise CreateRTTINotAvailableException(AClassType.ClassName, 'GetRttiType');
end;

function TAttributeMapper.GetRttiPropertyByKey(const ARttiType: TRttiType; const AParameterKey: string): TRttiProperty;
var
  LProperty: TRttiProperty;
  LKeyAttr: ParameterKeyAttribute;
begin
  Result := nil;
  for LProperty in ARttiType.GetProperties do
  begin
    LKeyAttr := FParser.GetAttribute<ParameterKeyAttribute>(LProperty);
    if (LKeyAttr <> nil) and (SameText(LKeyAttr.Key, AParameterKey)) then
    begin
      Result := LProperty;
      Exit;
    end;
  end;
end;

function TAttributeMapper.SetPropertyValue(const AInstance: TObject; const AProperty: TRttiProperty; const AValue: Variant): Boolean;
begin
  Result := False;
  try
    AProperty.SetValue(AInstance, TValue.FromVariant(AValue));
    Result := True;
  except
    Result := False;
  end;
end;

function TAttributeMapper.GetPropertyValue(const AInstance: TObject; const AProperty: TRttiProperty): Variant;
begin
  try
    Result := GetPropValue(AInstance, AProperty.Name);
  except
    Result := Null;
  end;
end;

function TAttributeMapper.MapClassToParameters(const AClassType: TClass): TParameterList;
begin
  Result := FParser.ParseClass(AClassType);
end;

function TAttributeMapper.MapClassToParameters(const AInstance: TObject): TParameterList;
begin
  Result := FParser.ParseClass(AInstance);
end;

function TAttributeMapper.MapParametersToClass(AParameters: TParameterList; AInstance: TObject): IAttributeMapper;
var
  LRttiType: TRttiType;
  LParam: TParameter;
  LProperty: TRttiProperty;
  LValue: Variant;
  I: Integer;
begin
  Result := Self;
  if (AParameters = nil) or (AInstance = nil) then
    Exit;
  LRttiType := GetRttiType(AInstance.ClassType);
  for I := 0 to AParameters.Count - 1 do
  begin
    LParam := AParameters[I];
    if LParam = nil then
      Continue;
    LProperty := GetRttiPropertyByKey(LRttiType, LParam.Name);
    if LProperty = nil then
      Continue;
    case LParam.ValueType of
      pvtString:
        LValue := LParam.Value;
      pvtInteger:
        LValue := StrToIntDef(LParam.Value, 0);
      pvtFloat:
        LValue := StrToFloatDef(LParam.Value, 0.0);
      pvtBoolean:
        LValue := SameText(LParam.Value, 'True') or SameText(LParam.Value, '1');
      pvtDateTime:
        LValue := StrToDateTimeDef(LParam.Value, Now);
      pvtJSON:
        LValue := LParam.Value;
    else
      LValue := LParam.Value;
    end;
    SetPropertyValue(AInstance, LProperty, LValue);
  end;
end;

function TAttributeMapper.SetParameterValue(AInstance: TObject; const AParameterKey: string; const AValue: Variant): IAttributeMapper;
var
  LRttiType: TRttiType;
  LProperty: TRttiProperty;
begin
  Result := Self;
  if AInstance = nil then
    Exit;
  LRttiType := GetRttiType(AInstance.ClassType);
  LProperty := GetRttiPropertyByKey(LRttiType, AParameterKey);
  if LProperty <> nil then
    SetPropertyValue(AInstance, LProperty, AValue);
end;

function TAttributeMapper.GetParameterValue(const AInstance: TObject; const AParameterKey: string): Variant;
var
  LRttiType: TRttiType;
  LProperty: TRttiProperty;
begin
  Result := Null;
  if AInstance = nil then
    Exit;
  LRttiType := GetRttiType(AInstance.ClassType);
  LProperty := GetRttiPropertyByKey(LRttiType, AParameterKey);
  if LProperty <> nil then
    Result := GetPropertyValue(AInstance, LProperty);
end;

{ Inicializacao }

procedure CreateAttributeParserAndMapper;
begin
  if AttributeParser = nil then
    AttributeParser := TAttributeParser.Create;
  if AttributeMapper = nil then
    AttributeMapper := TAttributeMapper.Create;
end;

{$HINTS ON}

initialization
  CreateAttributeParserAndMapper;
{$ENDIF}

end.
