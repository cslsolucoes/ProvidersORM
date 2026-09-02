{ =============================================================================
  GraphQL.Client.Introspection - remote schema introspection (FASE 13, wave 13B.3)

  FetchSchema(client) runs the standard __schema introspection query through an
  IGraphQLClient and returns an IGraphQLRemoteSchema: a navigable model of the
  remote type system (type names/kinds, field names, a field's named type). Built
  by re-parsing the response RawJSON with GraphQLParseJSON into a self-owned arena
  (independent of the response). RemoteSchemaFromJSON builds the same model from a
  fixed introspection JSON (golden tests, no network).

  ValidateQuery(query) is a CLIENT-SIDE pre-flight: it parses the query's document
  with the Core parser and checks every field exists on the corresponding remote
  type (recursing through a field's type), returning positioned-free error strings
  BEFORE any round-trip. Cross-compiler.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           12/08/2026

  Changelog (file):
  - 1.0.0 (12/08/2026): FASE 13 wave 13B.3 - IGraphQLRemoteSchema + FetchSchema +
    RemoteSchemaFromJSON + client-side ValidateQuery.
  ============================================================================= }

unit GraphQL.Client.Introspection;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../../ORM.Defines.inc}

{$IF DEFINED(USE_GRAPHQL) AND DEFINED(USE_GRAPHQL_CLIENT)}

uses
{$IF DEFINED(FPC)}
  SysUtils,
  Variants,
{$ELSE}
  System.SysUtils,
  System.Variants,
{$ENDIF}
  GraphQL.Types,
  GraphQL.Value,
  GraphQL.Core.Ast,
  GraphQL.Core.Parser,
  GraphQL.Client.Query,
  GraphQL.Client;

const
  { Standard introspection query (subset sufficient for the navigable model). }
  GRAPHQL_INTROSPECTION_QUERY =
    'query IntrospectionQuery {' + #10 +
    '  __schema {' + #10 +
    '    queryType { name }' + #10 +
    '    mutationType { name }' + #10 +
    '    types {' + #10 +
    '      name' + #10 +
    '      kind' + #10 +
    '      fields {' + #10 +
    '        name' + #10 +
    '        type { kind name ofType { kind name ofType { kind name } } }' + #10 +
    '      }' + #10 +
    '    }' + #10 +
    '  }' + #10 +
    '}';

type
  IGraphQLRemoteSchema = interface
    ['{5E7A9C30-2B41-4D75-8F62-3A4B5C6D7E80}']
    function QueryTypeName: string;
    function MutationTypeName: string;
    function TypeNames: TArray<string>;
    function HasType(const AName: string): Boolean;
    function TypeKind(const AName: string): string;
    function FieldNames(const ATypeName: string): TArray<string>;
    function HasField(const ATypeName, AFieldName: string): Boolean;
    function FieldTypeName(const ATypeName, AFieldName: string): string;
    { client-side pre-flight: returns the field errors (empty = valid) }
    function ValidateQuery(AQuery: IGraphQLQuery): TArray<string>;
    function RawSchema: TGraphQLValue; // the __schema value (arena-owned)
  end;

{ Builds a remote schema model from a full introspection response JSON
  (data.__schema or a bare __schema object). }
function RemoteSchemaFromJSON(const AJSON: string): IGraphQLRemoteSchema;
{ Runs the introspection query through the client and builds the model. }
function FetchSchema(AClient: IGraphQLClient): IGraphQLRemoteSchema;

{$ENDIF}

implementation

{$IF DEFINED(USE_GRAPHQL) AND DEFINED(USE_GRAPHQL_CLIENT)}

type
  TGraphQLRemoteSchema = class(TInterfacedObject, IGraphQLRemoteSchema)
  private
    FArena: TGraphQLValueArena;
    FSchema: TGraphQLValue; // the __schema object
    function FindType(const AName: string): TGraphQLValue;
    function FindField(const ATypeName, AFieldName: string): TGraphQLValue;
    procedure ValidateSelectionSet(ASel: TGraphQLSelectionSetNode;
      const ATypeName: string; var AErrors: TArray<string>);
  public
    constructor Create(const AJSON: string);
    destructor Destroy; override;
    function QueryTypeName: string;
    function MutationTypeName: string;
    function TypeNames: TArray<string>;
    function HasType(const AName: string): Boolean;
    function TypeKind(const AName: string): string;
    function FieldNames(const ATypeName: string): TArray<string>;
    function HasField(const ATypeName, AFieldName: string): Boolean;
    function FieldTypeName(const ATypeName, AFieldName: string): string;
    function ValidateQuery(AQuery: IGraphQLQuery): TArray<string>;
    function RawSchema: TGraphQLValue;
  end;

function ScalarStr(AValue: TGraphQLValue): string;
begin
  if (AValue <> nil) and (AValue.Kind = gvkScalar) then
    Result := VarToStr(AValue.Scalar)
  else
    Result := '';
end;

{ unwraps a type-ref (kind/name/ofType) down to its named type }
function UnwrapTypeName(ATypeRef: TGraphQLValue): string;
var
  LName: TGraphQLValue;
begin
  Result := '';
  while ATypeRef <> nil do
  begin
    LName := ATypeRef.GetField('name');
    if (LName <> nil) and (LName.Kind = gvkScalar) then
      Exit(VarToStr(LName.Scalar));
    ATypeRef := ATypeRef.GetField('ofType');
  end;
end;

{ TGraphQLRemoteSchema }

constructor TGraphQLRemoteSchema.Create(const AJSON: string);
var
  LRoot, LData: TGraphQLValue;
begin
  inherited Create;
  FArena := TGraphQLValueArena.Create;
  FSchema := nil;
  LRoot := GraphQLParseJSON(AJSON, FArena);
  if (LRoot <> nil) and (LRoot.Kind = gvkObject) then
  begin
    LData := LRoot.GetField('data');
    if (LData <> nil) and (LData.Kind = gvkObject) then
      FSchema := LData.GetField('__schema')
    else
      FSchema := LRoot.GetField('__schema');
  end;
end;

destructor TGraphQLRemoteSchema.Destroy;
begin
  FArena.Free;
  inherited Destroy;
end;

function TGraphQLRemoteSchema.FindType(const AName: string): TGraphQLValue;
var
  LTypes: TGraphQLValue;
  I: Integer;
begin
  Result := nil;
  if FSchema = nil then
    Exit;
  LTypes := FSchema.GetField('types');
  if (LTypes = nil) or (LTypes.Kind <> gvkList) then
    Exit;
  for I := 0 to High(LTypes.Items) do
    if SameText(ScalarStr(LTypes.Items[I].GetField('name')), AName) then
      Exit(LTypes.Items[I]);
end;

function TGraphQLRemoteSchema.FindField(const ATypeName, AFieldName: string): TGraphQLValue;
var
  LType, LFields: TGraphQLValue;
  I: Integer;
begin
  Result := nil;
  LType := FindType(ATypeName);
  if LType = nil then
    Exit;
  LFields := LType.GetField('fields');
  if (LFields = nil) or (LFields.Kind <> gvkList) then
    Exit;
  for I := 0 to High(LFields.Items) do
    if SameText(ScalarStr(LFields.Items[I].GetField('name')), AFieldName) then
      Exit(LFields.Items[I]);
end;

function TGraphQLRemoteSchema.QueryTypeName: string;
begin
  if FSchema <> nil then
    Result := ScalarStr(FSchema.GetField('queryType').GetField('name'))
  else
    Result := '';
end;

function TGraphQLRemoteSchema.MutationTypeName: string;
var
  LMut: TGraphQLValue;
begin
  Result := '';
  if FSchema = nil then
    Exit;
  LMut := FSchema.GetField('mutationType');
  if (LMut <> nil) and (LMut.Kind = gvkObject) then
    Result := ScalarStr(LMut.GetField('name'));
end;

function TGraphQLRemoteSchema.TypeNames: TArray<string>;
var
  LTypes: TGraphQLValue;
  I: Integer;
begin
  SetLength(Result, 0);
  if FSchema = nil then
    Exit;
  LTypes := FSchema.GetField('types');
  if (LTypes = nil) or (LTypes.Kind <> gvkList) then
    Exit;
  SetLength(Result, Length(LTypes.Items));
  for I := 0 to High(LTypes.Items) do
    Result[I] := ScalarStr(LTypes.Items[I].GetField('name'));
end;

function TGraphQLRemoteSchema.HasType(const AName: string): Boolean;
begin
  Result := FindType(AName) <> nil;
end;

function TGraphQLRemoteSchema.TypeKind(const AName: string): string;
var
  LType: TGraphQLValue;
begin
  LType := FindType(AName);
  if LType <> nil then
    Result := ScalarStr(LType.GetField('kind'))
  else
    Result := '';
end;

function TGraphQLRemoteSchema.FieldNames(const ATypeName: string): TArray<string>;
var
  LType, LFields: TGraphQLValue;
  I: Integer;
begin
  SetLength(Result, 0);
  LType := FindType(ATypeName);
  if LType = nil then
    Exit;
  LFields := LType.GetField('fields');
  if (LFields = nil) or (LFields.Kind <> gvkList) then
    Exit;
  SetLength(Result, Length(LFields.Items));
  for I := 0 to High(LFields.Items) do
    Result[I] := ScalarStr(LFields.Items[I].GetField('name'));
end;

function TGraphQLRemoteSchema.HasField(const ATypeName, AFieldName: string): Boolean;
begin
  Result := FindField(ATypeName, AFieldName) <> nil;
end;

function TGraphQLRemoteSchema.FieldTypeName(const ATypeName, AFieldName: string): string;
var
  LField: TGraphQLValue;
begin
  Result := '';
  LField := FindField(ATypeName, AFieldName);
  if LField <> nil then
    Result := UnwrapTypeName(LField.GetField('type'));
end;

procedure TGraphQLRemoteSchema.ValidateSelectionSet(ASel: TGraphQLSelectionSetNode;
  const ATypeName: string; var AErrors: TArray<string>);
var
  I: Integer;
  LField: TGraphQLFieldNode;
  LSubType: string;
begin
  if (ASel = nil) or (ATypeName = '') then
    Exit;
  for I := 0 to High(ASel.Selections) do
  begin
    if not (ASel.Selections[I] is TGraphQLFieldNode) then
      Continue; // fragments not validated in this wave (backlog)
    LField := TGraphQLFieldNode(ASel.Selections[I]);
    if LField.Name = '__typename' then
      Continue;
    if not HasField(ATypeName, LField.Name) then
    begin
      SetLength(AErrors, Length(AErrors) + 1);
      AErrors[High(AErrors)] := Format('Field "%s" does not exist on remote type "%s"',
        [LField.Name, ATypeName]);
    end
    else if LField.SelectionSet <> nil then
    begin
      LSubType := FieldTypeName(ATypeName, LField.Name);
      ValidateSelectionSet(LField.SelectionSet, LSubType, AErrors);
    end;
  end;
end;

function TGraphQLRemoteSchema.ValidateQuery(AQuery: IGraphQLQuery): TArray<string>;
var
  LParser: TGraphQLParser;
  LDoc: TGraphQLDocumentNode;
  LOp: TGraphQLOperationDefinitionNode;
  LRootType: string;
  I: Integer;
begin
  SetLength(Result, 0);
  LParser := TGraphQLParser.Create(AQuery.ToGraphQL);
  try
    try
      LDoc := LParser.Parse;
    except
      on E: Exception do
      begin
        SetLength(Result, 1);
        Result[0] := 'Parse error: ' + E.Message;
        Exit;
      end;
    end;
    try
      for I := 0 to High(LDoc.Definitions) do
        if LDoc.Definitions[I] is TGraphQLOperationDefinitionNode then
        begin
          LOp := TGraphQLOperationDefinitionNode(LDoc.Definitions[I]);
          if LOp.Operation = otMutation then
            LRootType := MutationTypeName
          else
            LRootType := QueryTypeName;
          ValidateSelectionSet(LOp.SelectionSet, LRootType, Result);
        end;
    finally
      LDoc.Free;
    end;
  finally
    LParser.Free;
  end;
end;

function TGraphQLRemoteSchema.RawSchema: TGraphQLValue;
begin
  Result := FSchema;
end;

function RemoteSchemaFromJSON(const AJSON: string): IGraphQLRemoteSchema;
begin
  Result := TGraphQLRemoteSchema.Create(AJSON);
end;

function FetchSchema(AClient: IGraphQLClient): IGraphQLRemoteSchema;
var
  LResp: IGraphQLResponse;
begin
  LResp := AClient.Execute(GRAPHQL_INTROSPECTION_QUERY, nil, 'IntrospectionQuery');
  Result := TGraphQLRemoteSchema.Create(LResp.RawJSON);
end;

{$ENDIF}

end.
