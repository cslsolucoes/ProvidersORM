{ =============================================================================
  GraphQL.Schema - schema container, fluent builder and SDL printer
  (FASE 13, wave 13A.2)

  IGraphQLSchema owns every type (named + List/NonNull wrappers) in a flat
  registry and frees them all. TGraphQLSchemaBuilder accumulates type
  definitions (via GraphQL.Schema.Types) and, on Build, registers the built-in
  scalars, resolves each field/arg/input type-expression to a pointer (creating
  wrappers), resolves interface/union member references, validates, and hands
  ownership to the schema. PrintSDL renders the schema back to SDL text.
  Cross-compiler.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           11/08/2026

  Changelog (file):
  - 1.0.0 (11/08/2026): FASE 13 wave 13A.2 - IGraphQLSchema + TGraphQLSchema
    (owning registry), TGraphQLSchemaBuilder (Add object/interface/union/enum/
    input/scalar + roots), Build (built-in scalars, type-expr resolution with
    wrappers, reference resolution, validation) and PrintSDL.
  ============================================================================= }

unit GraphQL.Schema;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_GRAPHQL}

uses
{$IF DEFINED(FPC)}
  SysUtils,
{$ELSE}
  System.SysUtils,
{$ENDIF}
  GraphQL.Types,
  GraphQL.Consts,
  GraphQL.Exceptions,
  GraphQL.Core.Lexer,
  GraphQL.Schema.Types;

type
  IGraphQLSchema = interface
    ['{4B1D9C22-3E71-46A9-9C0B-9F5A2D1E7A10}']
    function QueryType: TGraphQLObjectType;
    function MutationType: TGraphQLObjectType;
    function SubscriptionType: TGraphQLObjectType;
    function FindType(const AName: string): TGraphQLSchemaType;
    function NamedTypes: TGraphQLSchemaTypeArray;
    function PrintSDL: string;
    { Registers the introspection meta-types (__Schema/__Type/__Field/...) and
      injects the __schema/__type meta-fields into the query type, resolving
      their type references. Idempotent. Resolvers are attached by the server
      layer (GraphQL.Server.Introspection). }
    procedure InstallIntrospectionTypes;
  end;

  TGraphQLSchema = class(TInterfacedObject, IGraphQLSchema)
  private
    FNamed: TGraphQLSchemaTypeArray;    // owned
    FWrappers: TGraphQLSchemaTypeArray; // owned
    FQueryName: string;
    FMutationName: string;
    FSubscriptionName: string;
    function ObjectByName(const AName: string): TGraphQLObjectType;
  public
    destructor Destroy; override;
    // building helpers (used by the builder / SDL loader before publish)
    procedure AddNamed(AType: TGraphQLSchemaType);
    function GetOrCreateList(AOfType: TGraphQLSchemaType): TGraphQLSchemaType;
    function GetOrCreateNonNull(AOfType: TGraphQLSchemaType): TGraphQLSchemaType;
    procedure SetRoots(const AQuery, AMutation, ASubscription: string);
    // IGraphQLSchema
    function QueryType: TGraphQLObjectType;
    function MutationType: TGraphQLObjectType;
    function SubscriptionType: TGraphQLObjectType;
    function FindType(const AName: string): TGraphQLSchemaType;
    function NamedTypes: TGraphQLSchemaTypeArray;
    function PrintSDL: string;
    procedure InstallIntrospectionTypes;
  end;

  TGraphQLSchemaBuilder = class
  private
    FNamed: TGraphQLSchemaTypeArray; // owned until Build
    FQueryName: string;
    FMutationName: string;
    FSubscriptionName: string;
    FBuilt: Boolean;
    procedure Register(AType: TGraphQLSchemaType);
  public
    constructor Create;
    destructor Destroy; override;
    function ObjectType(const AName: string): TGraphQLObjectType;
    function InterfaceType(const AName: string): TGraphQLInterfaceType;
    function UnionType(const AName: string): TGraphQLUnionType;
    function EnumType(const AName: string): TGraphQLEnumType;
    function InputObjectType(const AName: string): TGraphQLInputObjectType;
    function ScalarType(const AName: string): TGraphQLScalarType;
    procedure RegisterScalar(AScalar: TGraphQLScalarType); // custom scalar instance
    procedure Query(const AName: string);
    procedure Mutation(const AName: string);
    procedure Subscription(const AName: string);
    function Find(const AName: string): TGraphQLSchemaType;
    function Build: IGraphQLSchema;
  end;

{$ENDIF USE_GRAPHQL}

implementation

{$IFDEF USE_GRAPHQL}

const
  BUILTIN_SCALARS: array[0..4] of string =
    (GQL_SCALAR_INT, GQL_SCALAR_FLOAT, GQL_SCALAR_STRING, GQL_SCALAR_BOOLEAN, GQL_SCALAR_ID);

{ ---- TGraphQLSchema ---- }

destructor TGraphQLSchema.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FWrappers) do
    FWrappers[I].Free;
  for I := 0 to High(FNamed) do
    FNamed[I].Free;
  inherited Destroy;
end;

procedure TGraphQLSchema.AddNamed(AType: TGraphQLSchemaType);
begin
  SetLength(FNamed, Length(FNamed) + 1);
  FNamed[High(FNamed)] := AType;
end;

function TGraphQLSchema.FindType(const AName: string): TGraphQLSchemaType;
var
  I: Integer;
begin
  for I := 0 to High(FNamed) do
    if FNamed[I].Name = AName then
      Exit(FNamed[I]);
  Result := nil;
end;

function TGraphQLSchema.GetOrCreateList(AOfType: TGraphQLSchemaType): TGraphQLSchemaType;
var
  I: Integer;
  LList: TGraphQLListSchemaType;
begin
  for I := 0 to High(FWrappers) do
    if (FWrappers[I] is TGraphQLListSchemaType) and
       (TGraphQLListSchemaType(FWrappers[I]).OfType = AOfType) then
      Exit(FWrappers[I]);
  LList := TGraphQLListSchemaType.Create;
  LList.OfType := AOfType;
  SetLength(FWrappers, Length(FWrappers) + 1);
  FWrappers[High(FWrappers)] := LList;
  Result := LList;
end;

function TGraphQLSchema.GetOrCreateNonNull(AOfType: TGraphQLSchemaType): TGraphQLSchemaType;
var
  I: Integer;
  LNN: TGraphQLNonNullSchemaType;
begin
  for I := 0 to High(FWrappers) do
    if (FWrappers[I] is TGraphQLNonNullSchemaType) and
       (TGraphQLNonNullSchemaType(FWrappers[I]).OfType = AOfType) then
      Exit(FWrappers[I]);
  LNN := TGraphQLNonNullSchemaType.Create;
  LNN.OfType := AOfType;
  SetLength(FWrappers, Length(FWrappers) + 1);
  FWrappers[High(FWrappers)] := LNN;
  Result := LNN;
end;

procedure TGraphQLSchema.SetRoots(const AQuery, AMutation, ASubscription: string);
begin
  FQueryName := AQuery;
  FMutationName := AMutation;
  FSubscriptionName := ASubscription;
end;

function TGraphQLSchema.ObjectByName(const AName: string): TGraphQLObjectType;
var
  LType: TGraphQLSchemaType;
begin
  Result := nil;
  if AName = '' then
    Exit;
  LType := FindType(AName);
  if LType is TGraphQLObjectType then
    Result := TGraphQLObjectType(LType);
end;

function TGraphQLSchema.QueryType: TGraphQLObjectType;
begin
  Result := ObjectByName(FQueryName);
end;

function TGraphQLSchema.MutationType: TGraphQLObjectType;
begin
  Result := ObjectByName(FMutationName);
end;

function TGraphQLSchema.SubscriptionType: TGraphQLObjectType;
begin
  Result := ObjectByName(FSubscriptionName);
end;

function TGraphQLSchema.NamedTypes: TGraphQLSchemaTypeArray;
begin
  Result := FNamed;
end;

{ ---- SDL printing ---- }

function IsBuiltinScalarName(const AName: string): Boolean;
var
  I: Integer;
begin
  for I := Low(BUILTIN_SCALARS) to High(BUILTIN_SCALARS) do
    if BUILTIN_SCALARS[I] = AName then
      Exit(True);
  Result := False;
end;

function PrintArgsSDL(const AArgs: TGraphQLInputValueDefArray): string;
var
  I: Integer;
begin
  if Length(AArgs) = 0 then
    Exit('');
  Result := '(';
  for I := 0 to High(AArgs) do
  begin
    if I > 0 then
      Result := Result + ', ';
    Result := Result + AArgs[I].Name + ': ' + AArgs[I].TypeExpr;
  end;
  Result := Result + ')';
end;

function PrintFieldsSDL(const AFields: TGraphQLFieldDefArray): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AFields) do
  begin
    if Copy(AFields[I].Name, 1, 2) = '__' then
      Continue; // introspection meta-fields (__schema/__type) are implicit
    Result := Result + '  ' + AFields[I].Name + PrintArgsSDL(AFields[I].Args) +
      ': ' + AFields[I].TypeExpr + #10;
  end;
end;

function PrintTypeSDL(AType: TGraphQLSchemaType): string;
var
  I: Integer;
  LObj: TGraphQLObjectType;
  LIntf: TGraphQLInterfaceType;
  LUnion: TGraphQLUnionType;
  LEnum: TGraphQLEnumType;
  LInput: TGraphQLInputObjectType;
begin
  if AType is TGraphQLObjectType then
  begin
    LObj := TGraphQLObjectType(AType);
    Result := 'type ' + LObj.Name;
    if Length(LObj.InterfaceNames) > 0 then
    begin
      Result := Result + ' implements ';
      for I := 0 to High(LObj.InterfaceNames) do
      begin
        if I > 0 then
          Result := Result + ' & ';
        Result := Result + LObj.InterfaceNames[I];
      end;
    end;
    Result := Result + ' {' + #10 + PrintFieldsSDL(LObj.Fields) + '}';
  end
  else if AType is TGraphQLInterfaceType then
  begin
    LIntf := TGraphQLInterfaceType(AType);
    Result := 'interface ' + LIntf.Name + ' {' + #10 + PrintFieldsSDL(LIntf.Fields) + '}';
  end
  else if AType is TGraphQLUnionType then
  begin
    LUnion := TGraphQLUnionType(AType);
    Result := 'union ' + LUnion.Name + ' = ';
    for I := 0 to High(LUnion.MemberNames) do
    begin
      if I > 0 then
        Result := Result + ' | ';
      Result := Result + LUnion.MemberNames[I];
    end;
  end
  else if AType is TGraphQLEnumType then
  begin
    LEnum := TGraphQLEnumType(AType);
    Result := 'enum ' + LEnum.Name + ' {' + #10;
    for I := 0 to High(LEnum.Values) do
      Result := Result + '  ' + LEnum.Values[I].Name + #10;
    Result := Result + '}';
  end
  else if AType is TGraphQLInputObjectType then
  begin
    LInput := TGraphQLInputObjectType(AType);
    Result := 'input ' + LInput.Name + ' {' + #10;
    for I := 0 to High(LInput.InputFields) do
      Result := Result + '  ' + LInput.InputFields[I].Name + ': ' +
        LInput.InputFields[I].TypeExpr + #10;
    Result := Result + '}';
  end
  else if AType is TGraphQLScalarType then
    Result := 'scalar ' + AType.Name
  else
    Result := '';
end;

function TGraphQLSchema.PrintSDL: string;
var
  I: Integer;
  LFirst: Boolean;
  LNeedsSchemaBlock: Boolean;
begin
  Result := '';
  LFirst := True;
  // optional schema block (only when roots deviate from the defaults)
  LNeedsSchemaBlock := (FQueryName <> '') and
    ((FQueryName <> 'Query') or (FMutationName <> '') or (FSubscriptionName <> ''));
  if LNeedsSchemaBlock then
  begin
    Result := 'schema {' + #10;
    if FQueryName <> '' then
      Result := Result + '  query: ' + FQueryName + #10;
    if FMutationName <> '' then
      Result := Result + '  mutation: ' + FMutationName + #10;
    if FSubscriptionName <> '' then
      Result := Result + '  subscription: ' + FSubscriptionName + #10;
    Result := Result + '}';
    LFirst := False;
  end;
  for I := 0 to High(FNamed) do
  begin
    if (FNamed[I] is TGraphQLScalarType) and IsBuiltinScalarName(FNamed[I].Name) then
      Continue; // built-in scalars are implicit
    if Copy(FNamed[I].Name, 1, 2) = '__' then
      Continue; // introspection meta-types are implicit
    if not LFirst then
      Result := Result + #10 + #10;
    Result := Result + PrintTypeSDL(FNamed[I]);
    LFirst := False;
  end;
end;

{ ---- TGraphQLSchemaBuilder ---- }

constructor TGraphQLSchemaBuilder.Create;
begin
  inherited Create;
  FBuilt := False;
end;

destructor TGraphQLSchemaBuilder.Destroy;
var
  I: Integer;
begin
  if not FBuilt then
    for I := 0 to High(FNamed) do
      FNamed[I].Free;
  inherited Destroy;
end;

procedure TGraphQLSchemaBuilder.Register(AType: TGraphQLSchemaType);
begin
  SetLength(FNamed, Length(FNamed) + 1);
  FNamed[High(FNamed)] := AType;
end;

function TGraphQLSchemaBuilder.Find(const AName: string): TGraphQLSchemaType;
var
  I: Integer;
begin
  for I := 0 to High(FNamed) do
    if FNamed[I].Name = AName then
      Exit(FNamed[I]);
  Result := nil;
end;

function TGraphQLSchemaBuilder.ObjectType(const AName: string): TGraphQLObjectType;
begin
  Result := TGraphQLObjectType.Create;
  Result.Name := AName;
  Register(Result);
end;

function TGraphQLSchemaBuilder.InterfaceType(const AName: string): TGraphQLInterfaceType;
begin
  Result := TGraphQLInterfaceType.Create;
  Result.Name := AName;
  Register(Result);
end;

function TGraphQLSchemaBuilder.UnionType(const AName: string): TGraphQLUnionType;
begin
  Result := TGraphQLUnionType.Create;
  Result.Name := AName;
  Register(Result);
end;

function TGraphQLSchemaBuilder.EnumType(const AName: string): TGraphQLEnumType;
begin
  Result := TGraphQLEnumType.Create;
  Result.Name := AName;
  Register(Result);
end;

function TGraphQLSchemaBuilder.InputObjectType(const AName: string): TGraphQLInputObjectType;
begin
  Result := TGraphQLInputObjectType.Create;
  Result.Name := AName;
  Register(Result);
end;

function TGraphQLSchemaBuilder.ScalarType(const AName: string): TGraphQLScalarType;
begin
  Result := TGraphQLScalarType.Create;
  Result.Name := AName;
  Register(Result);
end;

procedure TGraphQLSchemaBuilder.RegisterScalar(AScalar: TGraphQLScalarType);
begin
  Register(AScalar);
end;

procedure TGraphQLSchemaBuilder.Query(const AName: string);
begin
  FQueryName := AName;
end;

procedure TGraphQLSchemaBuilder.Mutation(const AName: string);
begin
  FMutationName := AName;
end;

procedure TGraphQLSchemaBuilder.Subscription(const AName: string);
begin
  FSubscriptionName := AName;
end;

{ Resolves a type-expression ("[User!]!") against the schema registry, creating
  list/nonnull wrappers owned by the schema. Raises on an unknown named type. }
function ResolveTypeExpr(ASchema: TGraphQLSchema; const AExpr: string): TGraphQLSchemaType;
var
  LLexer: TGraphQLLexer;
  LTok: TGraphQLToken;

  function ParseRef: TGraphQLSchemaType;
  var
    LNamed: TGraphQLSchemaType;
  begin
    if LTok.Kind = gtkBracketL then
    begin
      LTok := LLexer.Next; // consume '['
      Result := ASchema.GetOrCreateList(ParseRef);
      if LTok.Kind <> gtkBracketR then
        raise EGraphQLSchemaException.Create(
          Format('Invalid type expression "%s": expected "]"', [AExpr]),
          ERR_GRAPHQL_SCHEMA);
      LTok := LLexer.Next; // consume ']'
    end
    else if LTok.Kind = gtkName then
    begin
      LNamed := ASchema.FindType(LTok.Value);
      if LNamed = nil then
        raise EGraphQLSchemaException.Create(
          Format('Unknown type "%s" in type expression "%s"', [LTok.Value, AExpr]),
          ERR_GRAPHQL_SCHEMA);
      Result := LNamed;
      LTok := LLexer.Next; // consume Name
    end
    else
      raise EGraphQLSchemaException.Create(
        Format('Invalid type expression "%s"', [AExpr]), ERR_GRAPHQL_SCHEMA);
    if LTok.Kind = gtkBang then
    begin
      Result := ASchema.GetOrCreateNonNull(Result);
      LTok := LLexer.Next; // consume '!'
    end;
  end;

begin
  LLexer := TGraphQLLexer.Create(AExpr);
  try
    LTok := LLexer.Next;
    Result := ParseRef;
    if LTok.Kind <> gtkEOF then
      raise EGraphQLSchemaException.Create(
        Format('Invalid trailing tokens in type expression "%s"', [AExpr]),
        ERR_GRAPHQL_SCHEMA);
  finally
    LLexer.Free;
  end;
end;

procedure TGraphQLSchema.InstallIntrospectionTypes;
var
  LKind: TGraphQLEnumType;
  LType, LField, LInputVal, LEnumVal, LDirective, LSchemaT, LQuery, LObj: TGraphQLObjectType;
  LNew: TGraphQLSchemaTypeArray;
  I, J: Integer;

  procedure Track(AType: TGraphQLSchemaType);
  begin
    AddNamed(AType);
    SetLength(LNew, Length(LNew) + 1);
    LNew[High(LNew)] := AType;
  end;

begin
  if FindType('__Schema') <> nil then
    Exit; // idempotent

  LKind := TGraphQLEnumType.Create;
  LKind.Name := '__TypeKind';
  LKind.AddValue('SCALAR'); LKind.AddValue('OBJECT'); LKind.AddValue('INTERFACE');
  LKind.AddValue('UNION'); LKind.AddValue('ENUM'); LKind.AddValue('INPUT_OBJECT');
  LKind.AddValue('LIST'); LKind.AddValue('NON_NULL');
  Track(LKind);

  LType := TGraphQLObjectType.Create;
  LType.Name := '__Type';
  LType.AddField('kind', '__TypeKind!');
  LType.AddField('name', 'String');
  LType.AddField('description', 'String');
  LType.AddField('fields', '[__Field!]');
  LType.AddField('interfaces', '[__Type!]');
  LType.AddField('possibleTypes', '[__Type!]');
  LType.AddField('enumValues', '[__EnumValue!]');
  LType.AddField('inputFields', '[__InputValue!]');
  LType.AddField('ofType', '__Type');
  Track(LType);

  LField := TGraphQLObjectType.Create;
  LField.Name := '__Field';
  LField.AddField('name', 'String!');
  LField.AddField('description', 'String');
  LField.AddField('args', '[__InputValue!]!');
  LField.AddField('type', '__Type!');
  LField.AddField('isDeprecated', 'Boolean!');
  LField.AddField('deprecationReason', 'String');
  Track(LField);

  LInputVal := TGraphQLObjectType.Create;
  LInputVal.Name := '__InputValue';
  LInputVal.AddField('name', 'String!');
  LInputVal.AddField('description', 'String');
  LInputVal.AddField('type', '__Type!');
  LInputVal.AddField('defaultValue', 'String');
  Track(LInputVal);

  LEnumVal := TGraphQLObjectType.Create;
  LEnumVal.Name := '__EnumValue';
  LEnumVal.AddField('name', 'String!');
  LEnumVal.AddField('description', 'String');
  LEnumVal.AddField('isDeprecated', 'Boolean!');
  LEnumVal.AddField('deprecationReason', 'String');
  Track(LEnumVal);

  LDirective := TGraphQLObjectType.Create;
  LDirective.Name := '__Directive';
  LDirective.AddField('name', 'String!');
  LDirective.AddField('description', 'String');
  LDirective.AddField('locations', '[String!]!');
  LDirective.AddField('args', '[__InputValue!]!');
  Track(LDirective);

  LSchemaT := TGraphQLObjectType.Create;
  LSchemaT.Name := '__Schema';
  LSchemaT.AddField('types', '[__Type!]!');
  LSchemaT.AddField('queryType', '__Type!');
  LSchemaT.AddField('mutationType', '__Type');
  LSchemaT.AddField('subscriptionType', '__Type');
  LSchemaT.AddField('directives', '[__Directive!]!');
  Track(LSchemaT);

  { inject the meta-fields into the query type }
  LQuery := QueryType;
  if LQuery <> nil then
  begin
    LQuery.AddField('__schema', '__Schema!');
    LQuery.AddField('__type', '__Type').AddArg('name', 'String!');
  end;

  { resolve type references of every new meta-type field }
  for I := 0 to High(LNew) do
    if LNew[I] is TGraphQLObjectType then
    begin
      LObj := TGraphQLObjectType(LNew[I]);
      for J := 0 to High(LObj.Fields) do
        LObj.Fields[J].FieldType := ResolveTypeExpr(Self, LObj.Fields[J].TypeExpr);
    end;

  { resolve the injected query fields + their args }
  if LQuery <> nil then
    for J := 0 to High(LQuery.Fields) do
      if (LQuery.Fields[J].Name = '__schema') or (LQuery.Fields[J].Name = '__type') then
      begin
        LQuery.Fields[J].FieldType := ResolveTypeExpr(Self, LQuery.Fields[J].TypeExpr);
        for I := 0 to High(LQuery.Fields[J].Args) do
          LQuery.Fields[J].Args[I].ValueType :=
            ResolveTypeExpr(Self, LQuery.Fields[J].Args[I].TypeExpr);
      end;
end;

function TGraphQLSchemaBuilder.Build: IGraphQLSchema;
var
  LSchema: TGraphQLSchema;
  I, J, K: Integer;
  LType: TGraphQLSchemaType;
  LObj: TGraphQLObjectType;
  LIntf: TGraphQLInterfaceType;
  LUnion: TGraphQLUnionType;
  LInput: TGraphQLInputObjectType;
  LScalar: TGraphQLScalarType;
  LRef: TGraphQLSchemaType;
  LMembers: TGraphQLSchemaTypeArray;
  LIfaces: TGraphQLSchemaTypeArray;

  procedure ResolveFields(const AFields: TGraphQLFieldDefArray);
  var
    F, A: Integer;
  begin
    for F := 0 to High(AFields) do
    begin
      AFields[F].FieldType := ResolveTypeExpr(LSchema, AFields[F].TypeExpr);
      for A := 0 to High(AFields[F].Args) do
        AFields[F].Args[A].ValueType := ResolveTypeExpr(LSchema, AFields[F].Args[A].TypeExpr);
    end;
  end;

begin
  LSchema := TGraphQLSchema.Create;
  Result := LSchema; // interface refcount owns LSchema from here
  // transfer named types
  for I := 0 to High(FNamed) do
    LSchema.AddNamed(FNamed[I]);
  FBuilt := True; // ownership handed to the schema
  SetLength(FNamed, 0);
  // built-in scalars (only if missing)
  for I := Low(BUILTIN_SCALARS) to High(BUILTIN_SCALARS) do
    if LSchema.FindType(BUILTIN_SCALARS[I]) = nil then
    begin
      LScalar := TGraphQLScalarType.Create;
      LScalar.Name := BUILTIN_SCALARS[I];
      LSchema.AddNamed(LScalar);
    end;
  // default root type names (spec 3.3.1): a type named Query/Mutation/
  // Subscription is the implicit root when no schema block set it.
  if (FQueryName = '') and (LSchema.FindType('Query') is TGraphQLObjectType) then
    FQueryName := 'Query';
  if (FMutationName = '') and (LSchema.FindType('Mutation') is TGraphQLObjectType) then
    FMutationName := 'Mutation';
  if (FSubscriptionName = '') and (LSchema.FindType('Subscription') is TGraphQLObjectType) then
    FSubscriptionName := 'Subscription';
  LSchema.SetRoots(FQueryName, FMutationName, FSubscriptionName);
  // resolve type references
  for I := 0 to High(LSchema.NamedTypes) do
  begin
    LType := LSchema.NamedTypes[I];
    if LType is TGraphQLObjectType then
    begin
      LObj := TGraphQLObjectType(LType);
      ResolveFields(LObj.Fields);
      SetLength(LIfaces, 0);
      for J := 0 to High(LObj.InterfaceNames) do
      begin
        LRef := LSchema.FindType(LObj.InterfaceNames[J]);
        if not (LRef is TGraphQLInterfaceType) then
          raise EGraphQLSchemaException.Create(
            Format('Type "%s" implements unknown interface "%s"',
              [LObj.Name, LObj.InterfaceNames[J]]), ERR_GRAPHQL_SCHEMA);
        SetLength(LIfaces, Length(LIfaces) + 1);
        LIfaces[High(LIfaces)] := LRef;
      end;
      LObj.Interfaces := LIfaces;
    end
    else if LType is TGraphQLInterfaceType then
    begin
      LIntf := TGraphQLInterfaceType(LType);
      ResolveFields(LIntf.Fields);
    end
    else if LType is TGraphQLInputObjectType then
    begin
      LInput := TGraphQLInputObjectType(LType);
      for K := 0 to High(LInput.InputFields) do
        LInput.InputFields[K].ValueType :=
          ResolveTypeExpr(LSchema, LInput.InputFields[K].TypeExpr);
    end
    else if LType is TGraphQLUnionType then
    begin
      LUnion := TGraphQLUnionType(LType);
      SetLength(LMembers, 0);
      for J := 0 to High(LUnion.MemberNames) do
      begin
        LRef := LSchema.FindType(LUnion.MemberNames[J]);
        if not (LRef is TGraphQLObjectType) then
          raise EGraphQLSchemaException.Create(
            Format('Union "%s" has unknown/invalid member "%s"',
              [LUnion.Name, LUnion.MemberNames[J]]), ERR_GRAPHQL_SCHEMA);
        SetLength(LMembers, Length(LMembers) + 1);
        LMembers[High(LMembers)] := LRef;
      end;
      LUnion.Members := LMembers;
    end;
  end;
  // validation: query root must exist and be an object
  if FQueryName = '' then
    raise EGraphQLSchemaException.Create('Schema has no query root type',
      ERR_GRAPHQL_SCHEMA);
  if LSchema.QueryType = nil then
    raise EGraphQLSchemaException.Create(
      Format('Query root "%s" is not a defined object type', [FQueryName]),
      ERR_GRAPHQL_SCHEMA);
  if (FMutationName <> '') and (LSchema.MutationType = nil) then
    raise EGraphQLSchemaException.Create(
      Format('Mutation root "%s" is not a defined object type', [FMutationName]),
      ERR_GRAPHQL_SCHEMA);
  if (FSubscriptionName <> '') and (LSchema.SubscriptionType = nil) then
    raise EGraphQLSchemaException.Create(
      Format('Subscription root "%s" is not a defined object type', [FSubscriptionName]),
      ERR_GRAPHQL_SCHEMA);
end;

{$ENDIF USE_GRAPHQL}

end.
