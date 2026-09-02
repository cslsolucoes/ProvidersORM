{ =============================================================================
  GraphQL.Schema.Types - executable type system (FASE 13, wave 13A.2)

  Runtime schema types per spec Section 3: scalar (custom by subclass overriding
  ParseLiteral/ParseValue/Serialize), object (with interfaces), interface, union,
  enum (with deprecation), input object, plus List/NonNull wrappers. Every type
  is OWNED by the schema (flat registry, GraphQL.Schema); everything here refers
  to other types by POINTER (resolved at Build) or by NAME string (unresolved
  forward reference). Value carrier is Variant (no TValue/generics - avoids the
  FPC 3.3.1 header issue, bug-808). Cross-compiler.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           11/08/2026

  Changelog (file):
  - 1.0.0 (11/08/2026): FASE 13 wave 13A.2 - schema type classes (scalar/object/
    interface/union/enum/input + list/nonnull wrappers), field/argument/enum-
    value definitions, field type held as a string type-expression resolved at
    Build. Scalar coercion (Variant) with identity base + overridable hooks.
  ============================================================================= }

unit GraphQL.Schema.Types;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../../ORM.Defines.inc}

{$IFDEF USE_GRAPHQL}

uses
{$IF DEFINED(FPC)}
  SysUtils,
  Variants,
{$ELSE}
  System.SysUtils,
  System.Variants,
{$ENDIF}
  GraphQL.Types,
  GraphQL.Core.Ast;

type
  TGraphQLSchemaType = class;
  TGraphQLFieldDef = class;
  TGraphQLInputValueDef = class;
  TGraphQLEnumValueDef = class;

  TGraphQLSchemaTypeArray   = array of TGraphQLSchemaType;
  TGraphQLFieldDefArray     = array of TGraphQLFieldDef;
  TGraphQLInputValueDefArray = array of TGraphQLInputValueDef;
  TGraphQLEnumValueDefArray = array of TGraphQLEnumValueDef;
  TGraphQLStringArray       = array of string;

  { Base of every schema type. Named types are owned by the schema registry;
    List/NonNull wrappers too. }
  TGraphQLSchemaType = class
  protected
    FName: string;
    FDescription: string;
  public
    function Kind: TGraphQLTypeKind; virtual; abstract;
    { Printable type reference, e.g. "User", "[User!]!". }
    function TypeRef: string; virtual;
    { Unwraps List/NonNull down to the underlying named type (nil if none). }
    function NamedType: TGraphQLSchemaType; virtual;
    property Name: string read FName write FName;
    property Description: string read FDescription write FDescription;
  end;

  { ---- wrappers ---- }

  TGraphQLListSchemaType = class(TGraphQLSchemaType)
  private
    FOfType: TGraphQLSchemaType; // pointer (owned by schema)
  public
    function Kind: TGraphQLTypeKind; override;
    function TypeRef: string; override;
    function NamedType: TGraphQLSchemaType; override;
    property OfType: TGraphQLSchemaType read FOfType write FOfType;
  end;

  TGraphQLNonNullSchemaType = class(TGraphQLSchemaType)
  private
    FOfType: TGraphQLSchemaType; // pointer (owned by schema)
  public
    function Kind: TGraphQLTypeKind; override;
    function TypeRef: string; override;
    function NamedType: TGraphQLSchemaType; override;
    property OfType: TGraphQLSchemaType read FOfType write FOfType;
  end;

  { ---- scalar (custom by subclass) ---- }

  TGraphQLScalarType = class(TGraphQLSchemaType)
  public
    function Kind: TGraphQLTypeKind; override;
    { AST literal -> internal value. Base: extracts the raw scalar. }
    function ParseLiteral(ANode: TGraphQLValueNode): Variant; virtual;
    { external input variable -> internal value. Base: identity. }
    function ParseValue(const AInput: Variant): Variant; virtual;
    { internal value -> output value (for the response). Base: identity. }
    function Serialize(const AValue: Variant): Variant; virtual;
  end;

  { ---- enum ---- }

  TGraphQLEnumValueDef = class
  private
    FName: string;
    FDescription: string;
    FDeprecationReason: string;
  public
    property Name: string read FName write FName;
    property Description: string read FDescription write FDescription;
    property DeprecationReason: string read FDeprecationReason write FDeprecationReason;
  end;

  TGraphQLEnumType = class(TGraphQLSchemaType)
  private
    FValues: TGraphQLEnumValueDefArray; // owned
  public
    destructor Destroy; override;
    function Kind: TGraphQLTypeKind; override;
    function AddValue(const AName: string): TGraphQLEnumValueDef;
    function HasValue(const AName: string): Boolean;
    property Values: TGraphQLEnumValueDefArray read FValues;
  end;

  { ---- input object / arguments ---- }

  TGraphQLInputValueDef = class
  private
    FName: string;
    FDescription: string;
    FTypeExpr: string;               // e.g. "ID!" - resolved at Build
    FValueType: TGraphQLSchemaType;  // resolved pointer (not owned)
    FDefaultValue: TGraphQLValueNode; // owned, may be nil
  public
    destructor Destroy; override;
    property Name: string read FName write FName;
    property Description: string read FDescription write FDescription;
    property TypeExpr: string read FTypeExpr write FTypeExpr;
    property ValueType: TGraphQLSchemaType read FValueType write FValueType;
    property DefaultValue: TGraphQLValueNode read FDefaultValue write FDefaultValue;
  end;

  TGraphQLInputObjectType = class(TGraphQLSchemaType)
  private
    FInputFields: TGraphQLInputValueDefArray; // owned
  public
    destructor Destroy; override;
    function Kind: TGraphQLTypeKind; override;
    function AddInputField(const AName, ATypeExpr: string): TGraphQLInputValueDef;
    property InputFields: TGraphQLInputValueDefArray read FInputFields;
  end;

  { ---- field / object / interface / union ---- }

  TGraphQLFieldDef = class
  private
    FName: string;
    FDescription: string;
    FDeprecationReason: string;
    FTypeExpr: string;               // e.g. "[User!]!" - resolved at Build
    FFieldType: TGraphQLSchemaType;  // resolved pointer (not owned)
    FArgs: TGraphQLInputValueDefArray; // owned
    FResolver: IInterface;           // opaque resolver ref (server layer)
  public
    destructor Destroy; override;
    function AddArg(const AName, ATypeExpr: string): TGraphQLInputValueDef;
    function FindArg(const AName: string): TGraphQLInputValueDef;
    property Name: string read FName write FName;
    property Description: string read FDescription write FDescription;
    property DeprecationReason: string read FDeprecationReason write FDeprecationReason;
    property TypeExpr: string read FTypeExpr write FTypeExpr;
    property FieldType: TGraphQLSchemaType read FFieldType write FFieldType;
    property Args: TGraphQLInputValueDefArray read FArgs;
    property Resolver: IInterface read FResolver write FResolver;
  end;

  TGraphQLObjectType = class(TGraphQLSchemaType)
  private
    FFields: TGraphQLFieldDefArray;    // owned
    FInterfaceNames: TGraphQLStringArray;
    FInterfaces: TGraphQLSchemaTypeArray; // resolved pointers (not owned)
  public
    destructor Destroy; override;
    function Kind: TGraphQLTypeKind; override;
    function AddField(const AName, ATypeExpr: string): TGraphQLFieldDef;
    function FindField(const AName: string): TGraphQLFieldDef;
    procedure AddInterfaceName(const AName: string);
    property Fields: TGraphQLFieldDefArray read FFields;
    property InterfaceNames: TGraphQLStringArray read FInterfaceNames;
    property Interfaces: TGraphQLSchemaTypeArray read FInterfaces write FInterfaces;
  end;

  TGraphQLInterfaceType = class(TGraphQLSchemaType)
  private
    FFields: TGraphQLFieldDefArray; // owned
  public
    destructor Destroy; override;
    function Kind: TGraphQLTypeKind; override;
    function AddField(const AName, ATypeExpr: string): TGraphQLFieldDef;
    function FindField(const AName: string): TGraphQLFieldDef;
    property Fields: TGraphQLFieldDefArray read FFields;
  end;

  TGraphQLUnionType = class(TGraphQLSchemaType)
  private
    FMemberNames: TGraphQLStringArray;
    FMembers: TGraphQLSchemaTypeArray; // resolved pointers (not owned)
  public
    function Kind: TGraphQLTypeKind; override;
    procedure AddMemberName(const AName: string);
    property MemberNames: TGraphQLStringArray read FMemberNames;
    property Members: TGraphQLSchemaTypeArray read FMembers write FMembers;
  end;

{$ENDIF USE_GRAPHQL}

implementation

{$IFDEF USE_GRAPHQL}

{ TGraphQLSchemaType }

function TGraphQLSchemaType.TypeRef: string;
begin
  Result := FName;
end;

function TGraphQLSchemaType.NamedType: TGraphQLSchemaType;
begin
  Result := Self;
end;

{ TGraphQLListSchemaType }

function TGraphQLListSchemaType.Kind: TGraphQLTypeKind;
begin
  Result := tkList;
end;

function TGraphQLListSchemaType.TypeRef: string;
begin
  if Assigned(FOfType) then
    Result := '[' + FOfType.TypeRef + ']'
  else
    Result := '[?]';
end;

function TGraphQLListSchemaType.NamedType: TGraphQLSchemaType;
begin
  if Assigned(FOfType) then
    Result := FOfType.NamedType
  else
    Result := nil;
end;

{ TGraphQLNonNullSchemaType }

function TGraphQLNonNullSchemaType.Kind: TGraphQLTypeKind;
begin
  Result := tkNonNull;
end;

function TGraphQLNonNullSchemaType.TypeRef: string;
begin
  if Assigned(FOfType) then
    Result := FOfType.TypeRef + '!'
  else
    Result := '?!';
end;

function TGraphQLNonNullSchemaType.NamedType: TGraphQLSchemaType;
begin
  if Assigned(FOfType) then
    Result := FOfType.NamedType
  else
    Result := nil;
end;

{ TGraphQLScalarType }

function TGraphQLScalarType.Kind: TGraphQLTypeKind;
begin
  Result := tkScalar;
end;

function TGraphQLScalarType.ParseLiteral(ANode: TGraphQLValueNode): Variant;
begin
  if ANode is TGraphQLIntValueNode then
    Result := StrToInt64(TGraphQLIntValueNode(ANode).Value)
  else if ANode is TGraphQLFloatValueNode then
    Result := StrToFloat(TGraphQLFloatValueNode(ANode).Value)
  else if ANode is TGraphQLStringValueNode then
    Result := TGraphQLStringValueNode(ANode).Value
  else if ANode is TGraphQLBooleanValueNode then
    Result := TGraphQLBooleanValueNode(ANode).Value
  else if ANode is TGraphQLEnumValueNode then
    Result := TGraphQLEnumValueNode(ANode).Value
  else
    Result := Null;
end;

function TGraphQLScalarType.ParseValue(const AInput: Variant): Variant;
begin
  Result := AInput;
end;

function TGraphQLScalarType.Serialize(const AValue: Variant): Variant;
begin
  Result := AValue;
end;

{ TGraphQLEnumType }

destructor TGraphQLEnumType.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FValues) do
    FValues[I].Free;
  inherited Destroy;
end;

function TGraphQLEnumType.Kind: TGraphQLTypeKind;
begin
  Result := tkEnum;
end;

function TGraphQLEnumType.AddValue(const AName: string): TGraphQLEnumValueDef;
begin
  Result := TGraphQLEnumValueDef.Create;
  Result.Name := AName;
  SetLength(FValues, Length(FValues) + 1);
  FValues[High(FValues)] := Result;
end;

function TGraphQLEnumType.HasValue(const AName: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(FValues) do
    if FValues[I].Name = AName then
      Exit(True);
  Result := False;
end;

{ TGraphQLInputValueDef }

destructor TGraphQLInputValueDef.Destroy;
begin
  FDefaultValue.Free;
  inherited Destroy;
end;

{ TGraphQLInputObjectType }

destructor TGraphQLInputObjectType.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FInputFields) do
    FInputFields[I].Free;
  inherited Destroy;
end;

function TGraphQLInputObjectType.Kind: TGraphQLTypeKind;
begin
  Result := tkInputObject;
end;

function TGraphQLInputObjectType.AddInputField(const AName, ATypeExpr: string): TGraphQLInputValueDef;
begin
  Result := TGraphQLInputValueDef.Create;
  Result.Name := AName;
  Result.TypeExpr := ATypeExpr;
  SetLength(FInputFields, Length(FInputFields) + 1);
  FInputFields[High(FInputFields)] := Result;
end;

{ TGraphQLFieldDef }

destructor TGraphQLFieldDef.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FArgs) do
    FArgs[I].Free;
  inherited Destroy;
end;

function TGraphQLFieldDef.AddArg(const AName, ATypeExpr: string): TGraphQLInputValueDef;
begin
  Result := TGraphQLInputValueDef.Create;
  Result.Name := AName;
  Result.TypeExpr := ATypeExpr;
  SetLength(FArgs, Length(FArgs) + 1);
  FArgs[High(FArgs)] := Result;
end;

function TGraphQLFieldDef.FindArg(const AName: string): TGraphQLInputValueDef;
var
  I: Integer;
begin
  for I := 0 to High(FArgs) do
    if FArgs[I].Name = AName then
      Exit(FArgs[I]);
  Result := nil;
end;

{ TGraphQLObjectType }

destructor TGraphQLObjectType.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FFields) do
    FFields[I].Free;
  inherited Destroy;
end;

function TGraphQLObjectType.Kind: TGraphQLTypeKind;
begin
  Result := tkObject;
end;

function TGraphQLObjectType.AddField(const AName, ATypeExpr: string): TGraphQLFieldDef;
begin
  Result := TGraphQLFieldDef.Create;
  Result.Name := AName;
  Result.TypeExpr := ATypeExpr;
  SetLength(FFields, Length(FFields) + 1);
  FFields[High(FFields)] := Result;
end;

function TGraphQLObjectType.FindField(const AName: string): TGraphQLFieldDef;
var
  I: Integer;
begin
  for I := 0 to High(FFields) do
    if FFields[I].Name = AName then
      Exit(FFields[I]);
  Result := nil;
end;

procedure TGraphQLObjectType.AddInterfaceName(const AName: string);
begin
  SetLength(FInterfaceNames, Length(FInterfaceNames) + 1);
  FInterfaceNames[High(FInterfaceNames)] := AName;
end;

{ TGraphQLInterfaceType }

destructor TGraphQLInterfaceType.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FFields) do
    FFields[I].Free;
  inherited Destroy;
end;

function TGraphQLInterfaceType.Kind: TGraphQLTypeKind;
begin
  Result := tkInterface;
end;

function TGraphQLInterfaceType.AddField(const AName, ATypeExpr: string): TGraphQLFieldDef;
begin
  Result := TGraphQLFieldDef.Create;
  Result.Name := AName;
  Result.TypeExpr := ATypeExpr;
  SetLength(FFields, Length(FFields) + 1);
  FFields[High(FFields)] := Result;
end;

function TGraphQLInterfaceType.FindField(const AName: string): TGraphQLFieldDef;
var
  I: Integer;
begin
  for I := 0 to High(FFields) do
    if FFields[I].Name = AName then
      Exit(FFields[I]);
  Result := nil;
end;

{ TGraphQLUnionType }

function TGraphQLUnionType.Kind: TGraphQLTypeKind;
begin
  Result := tkUnion;
end;

procedure TGraphQLUnionType.AddMemberName(const AName: string);
begin
  SetLength(FMemberNames, Length(FMemberNames) + 1);
  FMemberNames[High(FMemberNames)] := AName;
end;

{$ENDIF USE_GRAPHQL}

end.
