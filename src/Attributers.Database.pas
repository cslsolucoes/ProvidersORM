{ =============================================================================
  Attributers.Database - Parser e Mapper de atributos RTTI (TAttributeParser,
  TAttributeMapper)

  Absorvido de ProvidersORM v2.3.0 Attributers.Providers.pas (FASE 6 Onda 6.1)
  - renomeado Providers->Database (regra D5). uses actualizados para os nomes
  v3 do modulo Database (Reorg 1/2/3): Database.Table.Interfaces->Databases.Interfaces;
  Database.Fields.Interfaces/Database.Field.Interfaces eliminados (contrato
  unico, ja em Databases.Interfaces). TField.New/TFields.New/TTable.New com a
  mesma assinatura da fonte (confirmado por leitura directa dos 3 ficheiros).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.3.1 (Database - modulo que estes atributos mapeiam)
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.0.0 (03/08/2026): FASE 6 Onda 6.1 - absorvido de Attributers.Providers.pas
    (SSOT v2.2.0), fiel ao original (TAttributeParser.HasTableAttribute/
    GetTableName/GetSchema/GetFieldMappings; TAttributeMapper.FromClass;
    singletons AttributeParser/AttributeMapper criados na initialization).
  ============================================================================= }

unit Attributers.Database;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

uses
  Attributers.Database.Interfaces,
  Attributers.Database.Types,
  Attributers.Database.Consts;

{$IFDEF USE_ATTRIBUTES}
var
  { Instancia singleton do parser (criada na primeira leitura). }
  AttributeParser: IAttributeParser;
  { Instancia singleton do mapper (criada na primeira leitura). }
  AttributeMapper: IAttributeMapper;
{$ENDIF}

implementation

{$IFDEF USE_ATTRIBUTES}
uses
{$IF DEFINED(FPC)}
  SysUtils, TypInfo, Rtti, Generics.Collections,
{$ELSE}
  System.SysUtils, System.TypInfo, System.Rtti, System.Generics.Collections,
{$ENDIF}
  Commons.Types,
  Databases.Interfaces,
  Database.Table,
  Database.Fields,
  Database.Field;

type
  TAttributeParser = class(TInterfacedObject, IAttributeParser)
  private
    FCtx: TRttiContext;
    function GetRttiType(const AClass: TClass): TRttiType;
    function RttiTypeKindToColumnType(const AType: TRttiType): string;
  public
    constructor Create;
    destructor Destroy; override;
    function HasTableAttribute(const AClass: TClass): Boolean;
    function GetTableName(const AClass: TClass): string;
    function GetSchema(const AClass: TClass): string;
    function GetFieldMappings(const AClass: TClass): TFieldMappingInfoArray;
  end;

  TAttributeMapper = class(TInterfacedObject, IAttributeMapper)
  private
    FParser: IAttributeParser;
  public
    constructor Create(const AParser: IAttributeParser);
    function FromClass(const AClass: TClass; const ADatabaseType: TDatabaseTypes): ITable;
  end;

{ TAttributeParser }

constructor TAttributeParser.Create;
begin
  inherited Create;
  FCtx := TRttiContext.Create;
end;

destructor TAttributeParser.Destroy;
begin
  FCtx.Free;
  inherited;
end;

function TAttributeParser.GetRttiType(const AClass: TClass): TRttiType;
begin
  Result := FCtx.GetType(AClass);
end;

function TAttributeParser.RttiTypeKindToColumnType(const AType: TRttiType): string;
var
  LName: string;
begin
  if AType = nil then
  begin
    Result := 'varchar(' + IntToStr(DEFAULT_FIELD_SIZE) + ')';
    Exit;
  end;
  LName := LowerCase(AType.Name);
  case AType.TypeKind of
    tkInteger: Result := 'integer';
    tkInt64: Result := 'bigint';
    tkFloat: Result := 'double precision';
    tkEnumeration:
      if (LName = 'boolean') or (Pos('bool', LName) > 0) then
        Result := 'boolean'
      else
        Result := 'integer';
    tkSet: Result := 'integer';
    tkChar, tkWChar: Result := 'char(1)';
    tkString, tkLString, tkWString, tkUString:
      Result := 'varchar(' + IntToStr(DEFAULT_FIELD_SIZE) + ')';
  else
    Result := 'varchar(' + IntToStr(DEFAULT_FIELD_SIZE) + ')';
  end;
end;

function TAttributeParser.HasTableAttribute(const AClass: TClass): Boolean;
var
  LType: TRttiType;
  LAttr: TCustomAttribute;
begin
  Result := False;
  if AClass = nil then
    Exit;
  LType := GetRttiType(AClass);
  if LType = nil then
    Exit;
  for LAttr in LType.GetAttributes do
    if LAttr is TableAttribute then
    begin
      Result := True;
      Exit;
    end;
end;

function TAttributeParser.GetTableName(const AClass: TClass): string;
var
  LType: TRttiType;
  LAttr: TCustomAttribute;
begin
  Result := '';
  if AClass = nil then
    Exit;
  LType := GetRttiType(AClass);
  if LType = nil then
    Exit;
  for LAttr in LType.GetAttributes do
    if LAttr is TableAttribute then
    begin
      Result := TableAttribute(LAttr).TableName;
      Exit;
    end;
end;

function TAttributeParser.GetSchema(const AClass: TClass): string;
var
  LType: TRttiType;
  LAttr: TCustomAttribute;
begin
  Result := DEFAULT_SCHEMA;
  if AClass = nil then
    Exit;
  LType := GetRttiType(AClass);
  if LType = nil then
    Exit;
  for LAttr in LType.GetAttributes do
    if LAttr is TableAttribute then
    begin
      Result := TableAttribute(LAttr).Schema;
      Exit;
    end;
end;

function TAttributeParser.GetFieldMappings(const AClass: TClass): TFieldMappingInfoArray;
var
  LType: TRttiType;
  LProp: TRttiProperty;
  LAttr: TCustomAttribute;
  LFieldAttr: FieldAttribute;
  LHasPk: Boolean;
  LList: TList<TFieldMappingInfo>;
  LInfo: TFieldMappingInfo;
  i: Integer;
begin
  SetLength(Result, 0);
  if AClass = nil then
    Exit;
  LType := GetRttiType(AClass);
  if LType = nil then
    Exit;
  LList := TList<TFieldMappingInfo>.Create;
  try
    for LProp in LType.GetProperties do
    begin
      LFieldAttr := nil;
      LHasPk := False;
      for LAttr in LProp.GetAttributes do
      begin
        if LAttr is FieldAttribute then
          LFieldAttr := FieldAttribute(LAttr)
        else if LAttr is PrimaryKeyAttribute then
          LHasPk := True;
      end;
      if LFieldAttr <> nil then
      begin
        LInfo.PropertyName := LProp.Name;
        LInfo.ColumnName := LFieldAttr.ColumnName;
        LInfo.ColumnType := RttiTypeKindToColumnType(LProp.PropertyType);
        LInfo.IsPrimaryKey := LHasPk;
        LList.Add(LInfo);
      end;
    end;
    SetLength(Result, LList.Count);
    for i := 0 to LList.Count - 1 do
      Result[i] := LList[i];
  finally
    LList.Free;
  end;
end;

{ TAttributeMapper }

constructor TAttributeMapper.Create(const AParser: IAttributeParser);
begin
  inherited Create;
  FParser := AParser;
end;

function TAttributeMapper.FromClass(const AClass: TClass; const ADatabaseType: TDatabaseTypes): ITable;
var
  LTableName, LSchema: string;
  LMappings: TFieldMappingInfoArray;
  LFields: IFields;
  i: Integer;
  LField: IField;
begin
  Result := nil;
  if (AClass = nil) or (FParser = nil) then
    Exit;
  if not FParser.HasTableAttribute(AClass) then
    Exit;
  LTableName := FParser.GetTableName(AClass);
  if LTableName = '' then
    Exit;
  LSchema := FParser.GetSchema(AClass);
  LMappings := FParser.GetFieldMappings(AClass);
  LFields := TFields.New;
  LFields.DatabaseTypes(ADatabaseType);
  for i := 0 to High(LMappings) do
  begin
    LField := TField.New(
      LMappings[i].ColumnName,
      LMappings[i].ColumnType,
      True,
      LMappings[i].IsPrimaryKey
    );
    LFields.AddField(LField);
  end;
  Result := TTable.New(LFields, LTableName);
  Result.DatabaseTypes(ADatabaseType);
end;

{ Inicializacao }

procedure CreateAttributeParserAndMapper;
begin
  if AttributeParser = nil then
    AttributeParser := TAttributeParser.Create;
  if AttributeMapper = nil then
    AttributeMapper := TAttributeMapper.Create(AttributeParser);
end;

initialization
  CreateAttributeParserAndMapper;
{$ENDIF}

end.
