{ =============================================================================
  GraphQL.Server.Introspection - introspection resolvers (FASE 13, wave 13A.5)

  Attaches the __schema and __type resolvers to a schema whose introspection
  meta-types were installed by IGraphQLSchema.InstallIntrospectionTypes. The
  resolvers build a value tree describing the schema from IGraphQLSchema.NamedTypes;
  the meta-type fields (name/kind/fields/ofType/...) are then resolved TRIVIALLY by
  the executor (the source object already carries every pair). __typename is
  handled directly by the executor. Spec Section 4.

  BuildTypeFull is used for entries of __schema.types and for __type(name) and
  root types (carries fields/enumValues/inputFields). BuildTypeRef is used for a
  field/argument type and for ofType chains (kind + name + ofType, no fields -
  terminates the recursion at named types, spec-correct).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           12/08/2026

  Changelog (file):
  - 1.0.0 (12/08/2026): FASE 13 wave 13A.5 - __schema / __type resolvers building
    the introspection value tree; InstallIntrospectionResolvers.
  ============================================================================= }

unit GraphQL.Server.Introspection;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_GRAPHQL}

uses
{$IF DEFINED(FPC)}
  SysUtils,
  Variants,
{$ELSE}
  System.SysUtils,
  System.Variants,
{$ENDIF}
  GraphQL.Value,
  GraphQL.Executor,
  GraphQL.Schema,
  GraphQL.Schema.Types;

type
  TGraphQLIntrospectSchemaResolver = class(TInterfacedObject, IGraphQLResolver)
  private
    FSchema: IGraphQLSchema;
  public
    constructor Create(const ASchema: IGraphQLSchema);
    function ResolveBatch(const ASources: TGraphQLValueArray;
      AContext: TGraphQLResolveContext): TGraphQLValueArray;
  end;

  TGraphQLIntrospectTypeResolver = class(TInterfacedObject, IGraphQLResolver)
  private
    FSchema: IGraphQLSchema;
  public
    constructor Create(const ASchema: IGraphQLSchema);
    function ResolveBatch(const ASources: TGraphQLValueArray;
      AContext: TGraphQLResolveContext): TGraphQLValueArray;
  end;

{ Installs the introspection meta-types (via the schema) and attaches the
  __schema / __type resolvers. }
procedure InstallIntrospectionResolvers(const ASchema: IGraphQLSchema);

{$ENDIF}

implementation

{$IFDEF USE_GRAPHQL}

function TypeKindStr(AType: TGraphQLSchemaType): string;
begin
  if AType is TGraphQLListSchemaType then Result := 'LIST'
  else if AType is TGraphQLNonNullSchemaType then Result := 'NON_NULL'
  else if AType is TGraphQLObjectType then Result := 'OBJECT'
  else if AType is TGraphQLInterfaceType then Result := 'INTERFACE'
  else if AType is TGraphQLUnionType then Result := 'UNION'
  else if AType is TGraphQLEnumType then Result := 'ENUM'
  else if AType is TGraphQLInputObjectType then Result := 'INPUT_OBJECT'
  else Result := 'SCALAR';
end;

{ Type reference: kind + name + ofType (no fields) - terminates at named types. }
function BuildTypeRef(AArena: TGraphQLValueArena; AType: TGraphQLSchemaType): TGraphQLValue;
begin
  Result := AArena.NewObject;
  if AType = nil then
  begin
    Result.SetField('kind', AArena.NewScalar('SCALAR'));
    Result.SetField('name', AArena.NewNull);
    Result.SetField('ofType', AArena.NewNull);
    Exit;
  end;
  if AType is TGraphQLListSchemaType then
  begin
    Result.SetField('kind', AArena.NewScalar('LIST'));
    Result.SetField('name', AArena.NewNull);
    Result.SetField('ofType', BuildTypeRef(AArena, TGraphQLListSchemaType(AType).OfType));
  end
  else if AType is TGraphQLNonNullSchemaType then
  begin
    Result.SetField('kind', AArena.NewScalar('NON_NULL'));
    Result.SetField('name', AArena.NewNull);
    Result.SetField('ofType', BuildTypeRef(AArena, TGraphQLNonNullSchemaType(AType).OfType));
  end
  else
  begin
    Result.SetField('kind', AArena.NewScalar(TypeKindStr(AType)));
    Result.SetField('name', AArena.NewScalar(AType.Name));
    Result.SetField('ofType', AArena.NewNull);
  end;
end;

function BuildInputValue(AArena: TGraphQLValueArena;
  AInput: TGraphQLInputValueDef): TGraphQLValue;
begin
  Result := AArena.NewObject;
  Result.SetField('name', AArena.NewScalar(AInput.Name));
  Result.SetField('description', AArena.NewNull);
  Result.SetField('type', BuildTypeRef(AArena, AInput.ValueType));
  Result.SetField('defaultValue', AArena.NewNull);
end;

function BuildField(AArena: TGraphQLValueArena; AField: TGraphQLFieldDef): TGraphQLValue;
var
  LArgs: TGraphQLValue;
  I: Integer;
begin
  Result := AArena.NewObject;
  Result.SetField('name', AArena.NewScalar(AField.Name));
  Result.SetField('description', AArena.NewNull);
  LArgs := AArena.NewList;
  for I := 0 to High(AField.Args) do
    LArgs.AddItem(BuildInputValue(AArena, AField.Args[I]));
  Result.SetField('args', LArgs);
  Result.SetField('type', BuildTypeRef(AArena, AField.FieldType));
  Result.SetField('isDeprecated', AArena.NewScalar(False));
  Result.SetField('deprecationReason', AArena.NewNull);
end;

{ Full type: kind/name/fields/enumValues/inputFields/interfaces (for types[]
  and __type(name) and root types). }
function BuildTypeFull(AArena: TGraphQLValueArena; AType: TGraphQLSchemaType): TGraphQLValue;
var
  LList: TGraphQLValue;
  I: Integer;
  LObj: TGraphQLObjectType;
  LEnum: TGraphQLEnumType;
  LInput: TGraphQLInputObjectType;
  LEv: TGraphQLValue;
begin
  Result := AArena.NewObject;
  Result.SetField('kind', AArena.NewScalar(TypeKindStr(AType)));
  Result.SetField('name', AArena.NewScalar(AType.Name));
  Result.SetField('description', AArena.NewNull);
  Result.SetField('ofType', AArena.NewNull);

  { fields (object / interface) }
  if AType is TGraphQLObjectType then
  begin
    LObj := TGraphQLObjectType(AType);
    LList := AArena.NewList;
    for I := 0 to High(LObj.Fields) do
      LList.AddItem(BuildField(AArena, LObj.Fields[I]));
    Result.SetField('fields', LList);
    Result.SetField('interfaces', AArena.NewList);
  end
  else if AType is TGraphQLInterfaceType then
  begin
    LList := AArena.NewList;
    for I := 0 to High(TGraphQLInterfaceType(AType).Fields) do
      LList.AddItem(BuildField(AArena, TGraphQLInterfaceType(AType).Fields[I]));
    Result.SetField('fields', LList);
    Result.SetField('interfaces', AArena.NewNull);
  end
  else
  begin
    Result.SetField('fields', AArena.NewNull);
    Result.SetField('interfaces', AArena.NewNull);
  end;

  { enum values }
  if AType is TGraphQLEnumType then
  begin
    LEnum := TGraphQLEnumType(AType);
    LList := AArena.NewList;
    for I := 0 to High(LEnum.Values) do
    begin
      LEv := AArena.NewObject;
      LEv.SetField('name', AArena.NewScalar(LEnum.Values[I].Name));
      LEv.SetField('description', AArena.NewNull);
      LEv.SetField('isDeprecated', AArena.NewScalar(False));
      LEv.SetField('deprecationReason', AArena.NewNull);
      LList.AddItem(LEv);
    end;
    Result.SetField('enumValues', LList);
  end
  else
    Result.SetField('enumValues', AArena.NewNull);

  { input fields }
  if AType is TGraphQLInputObjectType then
  begin
    LInput := TGraphQLInputObjectType(AType);
    LList := AArena.NewList;
    for I := 0 to High(LInput.InputFields) do
      LList.AddItem(BuildInputValue(AArena, LInput.InputFields[I]));
    Result.SetField('inputFields', LList);
  end
  else
    Result.SetField('inputFields', AArena.NewNull);

  Result.SetField('possibleTypes', AArena.NewNull);
end;

{ TGraphQLIntrospectSchemaResolver }

constructor TGraphQLIntrospectSchemaResolver.Create(const ASchema: IGraphQLSchema);
begin
  inherited Create;
  FSchema := ASchema;
end;

function TGraphQLIntrospectSchemaResolver.ResolveBatch(const ASources: TGraphQLValueArray;
  AContext: TGraphQLResolveContext): TGraphQLValueArray;
var
  LSch, LTypes: TGraphQLValue;
  LNamed: TGraphQLSchemaTypeArray;
  I: Integer;
begin
  SetLength(Result, Length(ASources));
  LSch := AContext.Arena.NewObject;
  LTypes := AContext.Arena.NewList;
  LNamed := FSchema.NamedTypes;
  for I := 0 to High(LNamed) do
    LTypes.AddItem(BuildTypeFull(AContext.Arena, LNamed[I]));
  LSch.SetField('types', LTypes);
  if FSchema.QueryType <> nil then
    LSch.SetField('queryType', BuildTypeFull(AContext.Arena, FSchema.QueryType))
  else
    LSch.SetField('queryType', AContext.Arena.NewNull);
  if FSchema.MutationType <> nil then
    LSch.SetField('mutationType', BuildTypeFull(AContext.Arena, FSchema.MutationType))
  else
    LSch.SetField('mutationType', AContext.Arena.NewNull);
  if FSchema.SubscriptionType <> nil then
    LSch.SetField('subscriptionType', BuildTypeFull(AContext.Arena, FSchema.SubscriptionType))
  else
    LSch.SetField('subscriptionType', AContext.Arena.NewNull);
  LSch.SetField('directives', AContext.Arena.NewList);
  if Length(Result) > 0 then
    Result[0] := LSch;
end;

{ TGraphQLIntrospectTypeResolver }

constructor TGraphQLIntrospectTypeResolver.Create(const ASchema: IGraphQLSchema);
begin
  inherited Create;
  FSchema := ASchema;
end;

function TGraphQLIntrospectTypeResolver.ResolveBatch(const ASources: TGraphQLValueArray;
  AContext: TGraphQLResolveContext): TGraphQLValueArray;
var
  LName: TGraphQLValue;
  LType: TGraphQLSchemaType;
begin
  SetLength(Result, Length(ASources));
  if Length(Result) = 0 then
    Exit;
  Result[0] := AContext.Arena.NewNull;
  LName := AContext.Arg('name');
  if (LName <> nil) and (LName.Kind = gvkScalar) then
  begin
    LType := FSchema.FindType(VarToStr(LName.Scalar));
    if LType <> nil then
      Result[0] := BuildTypeFull(AContext.Arena, LType);
  end;
end;

{ InstallIntrospectionResolvers }

procedure InstallIntrospectionResolvers(const ASchema: IGraphQLSchema);
var
  LQuery: TGraphQLObjectType;
  LField: TGraphQLFieldDef;
begin
  ASchema.InstallIntrospectionTypes;
  LQuery := ASchema.QueryType;
  if LQuery = nil then
    Exit;
  LField := LQuery.FindField('__schema');
  if LField <> nil then
    LField.Resolver := TGraphQLIntrospectSchemaResolver.Create(ASchema) as IGraphQLResolver;
  LField := LQuery.FindField('__type');
  if LField <> nil then
    LField.Resolver := TGraphQLIntrospectTypeResolver.Create(ASchema) as IGraphQLResolver;
end;

{$ENDIF}

end.
