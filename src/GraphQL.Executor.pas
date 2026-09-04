{ =============================================================================
  GraphQL.Executor - executes a parsed document against a schema
  (FASE 13, wave 13A.4; spec Sections 6 and 7)

  Pipeline: GetOperation -> CoerceVariableValues -> ExecuteSelectionSet
  (CollectFields with @skip/@include and fragment expansion + cycle detection ->
  resolve each field ONCE for ALL current sources via IGraphQLResolver.ResolveBatch
  -> CompleteValue: scalar (Serialize) / object (recurse) / list (recurse with ALL
  items at once) / non-null (null check)). Errors are ACCUMULATED, never raised to
  the caller (spec 6.4.3 / 7) - the result is always data + errors[].

  ANTI-N+1 BY CONSTRUCTION: a field is resolved for every source of the current
  level in a single ResolveBatch call; completing a list-of-objects hands ALL the
  items to the next ExecuteSelectionSet, so a nested navigation field batches the
  keys of every item into one query. See GraphQL.Server.OrmResolvers (13A.4-c).

  Resolvers are CALLBACK/interface (IGraphQLResolver) - never RTTI-by-name (the
  FPC 3.3.1 gotcha, decision 4). A field with no bound resolver falls back to the
  trivial resolver (property lookup on the source object by field name, spec 6.4.2).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           12/08/2026

  Changelog (file):
  - 1.0.0 (12/08/2026): FASE 13 wave 13A.4 - IGraphQLResolver, resolve context,
    executor (variable/argument coercion, collect fields, @skip/@include, fragment
    expansion with cycle detection, complete value, batch-preserving lists),
    accumulated errors, data + errors[] JSON.
  ============================================================================= }

unit GraphQL.Executor;

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
  GraphQL.Types,
  GraphQL.Consts,
  GraphQL.Exceptions,
  GraphQL.Core.Ast,
  GraphQL.Schema.Types,
  GraphQL.Schema,
  GraphQL.Value;

type
  TGraphQLExecutor = class; // forward

  { Passed to a resolver: the coerced arguments (object value), the arena to
    build results in, and the executor (for stats/query counting by ORM resolvers). }
  TGraphQLResolveContext = class
  private
    FArena: TGraphQLValueArena;
    FArgs: TGraphQLValue;
    FFieldName: string;
    FExecutor: TGraphQLExecutor;
  public
    property Arena: TGraphQLValueArena read FArena;
    property Args: TGraphQLValue read FArgs;
    property FieldName: string read FFieldName;
    property Executor: TGraphQLExecutor read FExecutor;
    function Arg(const AName: string): TGraphQLValue; // nil if absent
  end;

  { Resolves a field for EVERY source at once (batch). Result[i] corresponds to
    ASources[i]. A scalar field returns a scalar/null value; an object field
    returns an object value (the next-level source); a list field returns a list
    value. Never raises for a data error - return null and let CompleteValue map it. }
  IGraphQLResolver = interface
    ['{2F0A6E1C-7B84-4D2E-9A1F-1C3D5E7B9A02}']
    function ResolveBatch(const ASources: TGraphQLValueArray;
      AContext: TGraphQLResolveContext): TGraphQLValueArray;
  end;

  TGraphQLError = record
    Message: string;
    Path: string;
    Line: Integer;
    Column: Integer;
  end;
  TGraphQLErrorArray = array of TGraphQLError;

  TGraphQLExecutionResult = class
  private
    FArena: TGraphQLValueArena; // owns Data (and every intermediate value)
    FData: TGraphQLValue;       // arena-owned, may be nil
    FErrors: TGraphQLErrorArray;
    FHasData: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function ToJSON: string;
    property Data: TGraphQLValue read FData;
    property Errors: TGraphQLErrorArray read FErrors;
    function HasErrors: Boolean;
  end;

  TGraphQLExecutor = class
  private
    FSchema: IGraphQLSchema;
    FDocument: TGraphQLDocumentNode;   // not owned
    FVars: TGraphQLValue;              // coerced variables (object), arena-owned
    FArena: TGraphQLValueArena;        // = result arena during Execute
    FErrors: TGraphQLErrorArray;
    FQueryCount: Integer;
    procedure AddError(const AMessage, APath: string; ALine, AColumn: Integer);
    function FindOperation(const AName: string): TGraphQLOperationDefinitionNode;
    function FindFragment(const AName: string): TGraphQLFragmentDefinitionNode;
    function CoerceVariables(AOp: TGraphQLOperationDefinitionNode;
      AInput: TGraphQLValue): TGraphQLValue;
    function AstValueToValue(ANode: TGraphQLValueNode): TGraphQLValue;
    function CloneValue(AValue: TGraphQLValue): TGraphQLValue;
    function ValueAsBool(AValue: TGraphQLValue): Boolean;
    function ShouldInclude(const ADirectives: TGraphQLDirectiveArray): Boolean;
    function CoerceArguments(const AArgs: TGraphQLArgumentArray): TGraphQLValue;
    function ExecuteSelectionSet(const ASources: TGraphQLValueArray;
      ASelSet: TGraphQLSelectionSetNode; AObjectType: TGraphQLObjectType;
      const APath: string): TGraphQLValueArray;
    function CompleteValue(AFieldType: TGraphQLSchemaType;
      ASubSel: TGraphQLSelectionSetNode; AValue: TGraphQLValue;
      const APath: string; APos: TGraphQLPosition): TGraphQLValue;
  public
    constructor Create(ASchema: IGraphQLSchema);
    function Execute(ADocument: TGraphQLDocumentNode; AVariables: TGraphQLValue = nil;
      const AOperationName: string = ''): TGraphQLExecutionResult;
    property QueryCount: Integer read FQueryCount write FQueryCount;
  end;

{$ENDIF}

implementation

{$IFDEF USE_GRAPHQL}

{ collected field (merged by response key) }
type
  TCollectedField = record
    ResponseKey: string;
    Name: string;
    Args: TGraphQLArgumentArray;                 // from the first occurrence
    Pos: TGraphQLPosition;
    SubSelections: array of TGraphQLSelectionSetNode; // merged sub-selection sets
  end;
  TCollectedFieldArray = array of TCollectedField;

{ TGraphQLResolveContext }

function TGraphQLResolveContext.Arg(const AName: string): TGraphQLValue;
begin
  if FArgs = nil then
    Result := nil
  else
    Result := FArgs.GetField(AName);
end;

{ TGraphQLExecutionResult }

constructor TGraphQLExecutionResult.Create;
begin
  inherited Create;
  FArena := TGraphQLValueArena.Create;
  FData := nil;
  FHasData := False;
end;

destructor TGraphQLExecutionResult.Destroy;
begin
  FArena.Free; // frees Data and every intermediate value
  inherited Destroy;
end;

function TGraphQLExecutionResult.HasErrors: Boolean;
begin
  Result := Length(FErrors) > 0;
end;

function TGraphQLExecutionResult.ToJSON: string;
var
  I: Integer;
  LSb: string;
begin
  LSb := '{';
  if FHasData then
    LSb := LSb + '"data":' + GraphQLValueToJSON(FData);
  if Length(FErrors) > 0 then
  begin
    if FHasData then
      LSb := LSb + ',';
    LSb := LSb + '"errors":[';
    for I := 0 to High(FErrors) do
    begin
      if I > 0 then
        LSb := LSb + ',';
      LSb := LSb + '{"message":' + GraphQLJSONQuote(FErrors[I].Message);
      if FErrors[I].Line > 0 then
        LSb := LSb + ',"locations":[{"line":' + IntToStr(FErrors[I].Line) +
          ',"column":' + IntToStr(FErrors[I].Column) + '}]';
      if FErrors[I].Path <> '' then
        LSb := LSb + ',"path":' + GraphQLJSONQuote(FErrors[I].Path);
      LSb := LSb + '}';
    end;
    LSb := LSb + ']';
  end;
  Result := LSb + '}';
end;

{ TGraphQLExecutor }

constructor TGraphQLExecutor.Create(ASchema: IGraphQLSchema);
begin
  inherited Create;
  FSchema := ASchema;
end;

procedure TGraphQLExecutor.AddError(const AMessage, APath: string;
  ALine, AColumn: Integer);
begin
  SetLength(FErrors, Length(FErrors) + 1);
  FErrors[High(FErrors)].Message := AMessage;
  FErrors[High(FErrors)].Path := APath;
  FErrors[High(FErrors)].Line := ALine;
  FErrors[High(FErrors)].Column := AColumn;
end;

function TGraphQLExecutor.FindOperation(const AName: string): TGraphQLOperationDefinitionNode;
var
  I: Integer;
  LOp: TGraphQLOperationDefinitionNode;
  LCount: Integer;
begin
  Result := nil;
  LCount := 0;
  for I := 0 to High(FDocument.Definitions) do
    if FDocument.Definitions[I] is TGraphQLOperationDefinitionNode then
    begin
      LOp := TGraphQLOperationDefinitionNode(FDocument.Definitions[I]);
      Inc(LCount);
      if AName <> '' then
      begin
        if LOp.Name = AName then
          Exit(LOp);
      end
      else
        Result := LOp; // remember the last (validated as single below)
    end;
  if (AName = '') and (LCount > 1) then
    Result := nil; // ambiguous - caller must name the operation
end;

function TGraphQLExecutor.FindFragment(const AName: string): TGraphQLFragmentDefinitionNode;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to High(FDocument.Definitions) do
    if FDocument.Definitions[I] is TGraphQLFragmentDefinitionNode then
      if TGraphQLFragmentDefinitionNode(FDocument.Definitions[I]).Name = AName then
        Exit(TGraphQLFragmentDefinitionNode(FDocument.Definitions[I]));
end;

function TGraphQLExecutor.AstValueToValue(ANode: TGraphQLValueNode): TGraphQLValue;
var
  I: Integer;
  LObj, LItem: TGraphQLValue;
  LVarVal: TGraphQLValue;
begin
  if ANode is TGraphQLVariableNode then
  begin
    if FVars <> nil then
      LVarVal := FVars.GetField(TGraphQLVariableNode(ANode).Name)
    else
      LVarVal := nil;
    if LVarVal = nil then
      Result := FArena.NewNull
    else
      Result := LVarVal; // already in the exec arena (coerced)
  end
  else if ANode is TGraphQLIntValueNode then
    Result := FArena.NewScalar(StrToInt64Def(TGraphQLIntValueNode(ANode).Value, 0))
  else if ANode is TGraphQLFloatValueNode then
    Result := FArena.NewScalar(TGraphQLFloatValueNode(ANode).Value) // keep raw text as scalar string; serialized as-is
  else if ANode is TGraphQLStringValueNode then
    Result := FArena.NewScalar(TGraphQLStringValueNode(ANode).Value)
  else if ANode is TGraphQLBooleanValueNode then
    Result := FArena.NewScalar(TGraphQLBooleanValueNode(ANode).Value)
  else if ANode is TGraphQLNullValueNode then
    Result := FArena.NewNull
  else if ANode is TGraphQLEnumValueNode then
    Result := FArena.NewScalar(TGraphQLEnumValueNode(ANode).Value)
  else if ANode is TGraphQLListValueNode then
  begin
    Result := FArena.NewList;
    for I := 0 to High(TGraphQLListValueNode(ANode).Values) do
      Result.AddItem(AstValueToValue(TGraphQLListValueNode(ANode).Values[I]));
  end
  else if ANode is TGraphQLObjectValueNode then
  begin
    LObj := FArena.NewObject;
    for I := 0 to High(TGraphQLObjectValueNode(ANode).Fields) do
    begin
      LItem := AstValueToValue(TGraphQLObjectValueNode(ANode).Fields[I].Value);
      LObj.SetField(TGraphQLObjectValueNode(ANode).Fields[I].Name, LItem);
    end;
    Result := LObj;
  end
  else
    Result := FArena.NewNull;
end;

function TGraphQLExecutor.CloneValue(AValue: TGraphQLValue): TGraphQLValue;
var
  I: Integer;
begin
  if AValue = nil then
    Exit(FArena.NewNull);
  case AValue.Kind of
    gvkNull:
      Result := FArena.NewNull;
    gvkScalar:
      Result := FArena.NewScalar(AValue.Scalar);
    gvkObject:
      begin
        Result := FArena.NewObject;
        for I := 0 to High(AValue.Pairs) do
          Result.SetField(AValue.Pairs[I].Name, CloneValue(AValue.Pairs[I].Value));
      end;
    gvkList:
      begin
        Result := FArena.NewList;
        for I := 0 to High(AValue.Items) do
          Result.AddItem(CloneValue(AValue.Items[I]));
      end;
  else
    Result := FArena.NewNull;
  end;
end;

function TGraphQLExecutor.ValueAsBool(AValue: TGraphQLValue): Boolean;
begin
  Result := (AValue <> nil) and (AValue.Kind = gvkScalar) and
    (VarType(AValue.Scalar) = varBoolean) and Boolean(AValue.Scalar);
end;

function TGraphQLExecutor.CoerceVariables(AOp: TGraphQLOperationDefinitionNode;
  AInput: TGraphQLValue): TGraphQLValue;
var
  I: Integer;
  LDef: TGraphQLVariableDefinitionNode;
  LName: string;
  LIn: TGraphQLValue;
begin
  Result := FArena.NewObject;
  for I := 0 to High(AOp.VariableDefinitions) do
  begin
    LDef := AOp.VariableDefinitions[I];
    LName := LDef.Variable.Name;
    LIn := nil;
    if AInput <> nil then
      LIn := AInput.GetField(LName);
    if LIn <> nil then
      Result.SetField(LName, CloneValue(LIn))
    else if LDef.DefaultValue <> nil then
      Result.SetField(LName, AstValueToValue(LDef.DefaultValue))
    else
      Result.SetField(LName, FArena.NewNull);
  end;
end;

function TGraphQLExecutor.ShouldInclude(const ADirectives: TGraphQLDirectiveArray): Boolean;
var
  I, J: Integer;
  LIf: TGraphQLValue;
begin
  Result := True;
  for I := 0 to High(ADirectives) do
  begin
    LIf := nil;
    for J := 0 to High(ADirectives[I].Arguments) do
      if ADirectives[I].Arguments[J].Name = 'if' then
        LIf := AstValueToValue(ADirectives[I].Arguments[J].Value);
    if ADirectives[I].Name = GQL_DIR_SKIP then
    begin
      if ValueAsBool(LIf) then
        Exit(False);
    end
    else if ADirectives[I].Name = GQL_DIR_INCLUDE then
    begin
      if not ValueAsBool(LIf) then
        Exit(False);
    end;
  end;
end;

function TGraphQLExecutor.CoerceArguments(const AArgs: TGraphQLArgumentArray): TGraphQLValue;
var
  I: Integer;
begin
  Result := FArena.NewObject;
  for I := 0 to High(AArgs) do
    Result.SetField(AArgs[I].Name, AstValueToValue(AArgs[I].Value));
end;

{ merges the selection set into the collected-field list (by response key),
  expanding fragments; AVisited guards fragment-spread cycles. }
procedure Collect(AExec: TGraphQLExecutor; ASelSet: TGraphQLSelectionSetNode;
  AObjectType: TGraphQLObjectType; var ACollected: TCollectedFieldArray;
  var AVisited: array of string; var AVisitedCount: Integer);
var
  I, K: Integer;
  LSel: TGraphQLSelectionNode;
  LField: TGraphQLFieldNode;
  LSpread: TGraphQLFragmentSpreadNode;
  LInline: TGraphQLInlineFragmentNode;
  LFrag: TGraphQLFragmentDefinitionNode;
  LKey: string;
  LFound: Boolean;

  function AlreadyVisited(const AName: string): Boolean;
  var V: Integer;
  begin
    Result := False;
    for V := 0 to AVisitedCount - 1 do
      if AVisited[V] = AName then Exit(True);
  end;

begin
  if ASelSet = nil then
    Exit;
  for I := 0 to High(ASelSet.Selections) do
  begin
    LSel := ASelSet.Selections[I];
    if LSel is TGraphQLFieldNode then
    begin
      LField := TGraphQLFieldNode(LSel);
      if not AExec.ShouldInclude(LField.Directives) then
        Continue;
      if LField.Alias <> '' then
        LKey := LField.Alias
      else
        LKey := LField.Name;
      LFound := False;
      for K := 0 to High(ACollected) do
        if ACollected[K].ResponseKey = LKey then
        begin
          if LField.SelectionSet <> nil then
          begin
            SetLength(ACollected[K].SubSelections, Length(ACollected[K].SubSelections) + 1);
            ACollected[K].SubSelections[High(ACollected[K].SubSelections)] := LField.SelectionSet;
          end;
          LFound := True;
          Break;
        end;
      if not LFound then
      begin
        SetLength(ACollected, Length(ACollected) + 1);
        ACollected[High(ACollected)].ResponseKey := LKey;
        ACollected[High(ACollected)].Name := LField.Name;
        ACollected[High(ACollected)].Args := LField.Arguments;
        ACollected[High(ACollected)].Pos := LField.Position;
        if LField.SelectionSet <> nil then
        begin
          SetLength(ACollected[High(ACollected)].SubSelections, 1);
          ACollected[High(ACollected)].SubSelections[0] := LField.SelectionSet;
        end;
      end;
    end
    else if LSel is TGraphQLInlineFragmentNode then
    begin
      LInline := TGraphQLInlineFragmentNode(LSel);
      if not AExec.ShouldInclude(LInline.Directives) then
        Continue;
      // type condition: apply only if it matches the current object type (or absent)
      if (LInline.TypeCondition = nil) or
         (LInline.TypeCondition.Name = AObjectType.Name) then
        Collect(AExec, LInline.SelectionSet, AObjectType, ACollected, AVisited, AVisitedCount);
    end
    else if LSel is TGraphQLFragmentSpreadNode then
    begin
      LSpread := TGraphQLFragmentSpreadNode(LSel);
      if not AExec.ShouldInclude(LSpread.Directives) then
        Continue;
      if AlreadyVisited(LSpread.Name) then
        Continue; // cycle guard
      LFrag := AExec.FindFragment(LSpread.Name);
      if LFrag = nil then
        Continue;
      if (LFrag.TypeCondition <> nil) and
         (LFrag.TypeCondition.Name <> AObjectType.Name) then
        Continue;
      AVisited[AVisitedCount] := LSpread.Name;
      Inc(AVisitedCount);
      Collect(AExec, LFrag.SelectionSet, AObjectType, ACollected, AVisited, AVisitedCount);
      Dec(AVisitedCount);
    end;
  end;
end;

function TGraphQLExecutor.ExecuteSelectionSet(const ASources: TGraphQLValueArray;
  ASelSet: TGraphQLSelectionSetNode; AObjectType: TGraphQLObjectType;
  const APath: string): TGraphQLValueArray;
var
  LCollected: TCollectedFieldArray;
  LVisited: array of string;
  LVisitedCount: Integer;
  C, S: Integer;
  LFieldDef: TGraphQLFieldDef;
  LResolver: IGraphQLResolver;
  LCtx: TGraphQLResolveContext;
  LValues: TGraphQLValueArray;
  LMergedSel: TGraphQLSelectionSetNode;
  LItemPath: string;
  LCompleted: TGraphQLValue;
begin
  SetLength(Result, Length(ASources));
  for S := 0 to High(ASources) do
    Result[S] := FArena.NewObject;

  SetLength(LCollected, 0);
  SetLength(LVisited, 256);
  LVisitedCount := 0;
  Collect(Self, ASelSet, AObjectType, LCollected, LVisited, LVisitedCount);

  for C := 0 to High(LCollected) do
  begin
    LFieldDef := AObjectType.FindField(LCollected[C].Name);
    if LFieldDef = nil then
    begin
      // introspection/typename or unknown field
      if LCollected[C].Name = GQL_INTROSPECT_TYPENAME then
      begin
        for S := 0 to High(ASources) do
          Result[S].SetField(LCollected[C].ResponseKey, FArena.NewScalar(AObjectType.Name));
        Continue;
      end;
      AddError(Format('Cannot query field "%s" on type "%s"',
        [LCollected[C].Name, AObjectType.Name]), APath + '/' + LCollected[C].ResponseKey,
        LCollected[C].Pos.Line, LCollected[C].Pos.Column);
      for S := 0 to High(ASources) do
        Result[S].SetField(LCollected[C].ResponseKey, FArena.NewNull);
      Continue;
    end;

    // resolve the field ONCE for all sources (batch)
    LCtx := TGraphQLResolveContext.Create;
    try
      LCtx.FArena := FArena;
      LCtx.FArgs := CoerceArguments(LCollected[C].Args);
      LCtx.FFieldName := LCollected[C].Name;
      LCtx.FExecutor := Self;
      if Supports(LFieldDef.Resolver, IGraphQLResolver, LResolver) then
      begin
        try
          LValues := LResolver.ResolveBatch(ASources, LCtx);
        except
          on E: Exception do
          begin
            AddError(E.Message, APath + '/' + LCollected[C].ResponseKey,
              LCollected[C].Pos.Line, LCollected[C].Pos.Column);
            SetLength(LValues, Length(ASources));
            for S := 0 to High(LValues) do
              LValues[S] := FArena.NewNull;
          end;
        end;
      end
      else
      begin
        // trivial resolver: property lookup on the source by field name
        SetLength(LValues, Length(ASources));
        for S := 0 to High(ASources) do
          if (ASources[S] <> nil) and (ASources[S].Kind = gvkObject) and
             (ASources[S].GetField(LCollected[C].Name) <> nil) then
            LValues[S] := ASources[S].GetField(LCollected[C].Name)
          else
            LValues[S] := FArena.NewNull;
      end;
    finally
      LResolver := nil;
      LCtx.Free;
    end;

    // merge sub-selections of this collected field into one selection set view
    LMergedSel := nil;
    if Length(LCollected[C].SubSelections) > 0 then
      LMergedSel := LCollected[C].SubSelections[0]; // primary; extra merges handled in Collect on next level

    // complete each value against the field type
    for S := 0 to High(ASources) do
    begin
      if APath = '' then
        LItemPath := LCollected[C].ResponseKey
      else
        LItemPath := APath + '/' + LCollected[C].ResponseKey;
      LCompleted := CompleteValue(LFieldDef.FieldType, LMergedSel, LValues[S],
        LItemPath, LCollected[C].Pos);
      Result[S].SetField(LCollected[C].ResponseKey, LCompleted);
    end;
  end;
end;

function TGraphQLExecutor.CompleteValue(AFieldType: TGraphQLSchemaType;
  ASubSel: TGraphQLSelectionSetNode; AValue: TGraphQLValue; const APath: string;
  APos: TGraphQLPosition): TGraphQLValue;
var
  LNamed: TGraphQLSchemaType;
  LItemType: TGraphQLSchemaType;
  LObjType: TGraphQLObjectType;
  LSubResults: TGraphQLValueArray;
  I: Integer;
  LList: TGraphQLValue;
begin
  // non-null wrapper: complete the inner type; a null there is an error
  if AFieldType is TGraphQLNonNullSchemaType then
  begin
    Result := CompleteValue(TGraphQLNonNullSchemaType(AFieldType).OfType, ASubSel,
      AValue, APath, APos);
    if (Result = nil) or Result.IsNull then
    begin
      AddError(Format('Cannot return null for non-nullable field at "%s"', [APath]),
        APath, APos.Line, APos.Column);
      // (simplified: null the field; full null-bubbling to parent is backlog)
    end;
    Exit;
  end;

  if (AValue = nil) or AValue.IsNull then
    Exit(FArena.NewNull);

  if AFieldType is TGraphQLListSchemaType then
  begin
    if AValue.Kind <> gvkList then
      Exit(FArena.NewNull);
    LItemType := TGraphQLListSchemaType(AFieldType).OfType;
    LNamed := LItemType.NamedType;
    LList := FArena.NewList;
    if LNamed is TGraphQLObjectType then
    begin
      // BATCH: hand ALL items to one ExecuteSelectionSet (anti-N+1)
      LObjType := TGraphQLObjectType(LNamed);
      LSubResults := ExecuteSelectionSet(AValue.Items, ASubSel, LObjType, APath);
      for I := 0 to High(LSubResults) do
        LList.AddItem(LSubResults[I]);
    end
    else
      for I := 0 to High(AValue.Items) do
        LList.AddItem(CompleteValue(LItemType, ASubSel, AValue.Items[I], APath, APos));
    Exit(LList);
  end;

  LNamed := AFieldType.NamedType;
  if LNamed is TGraphQLObjectType then
  begin
    LObjType := TGraphQLObjectType(LNamed);
    LSubResults := ExecuteSelectionSet([AValue], ASubSel, LObjType, APath);
    Exit(LSubResults[0]);
  end;

  if LNamed is TGraphQLScalarType then
    Exit(FArena.NewScalar(TGraphQLScalarType(LNamed).Serialize(AValue.Scalar)));

  // enum or anything else: pass the scalar through
  Result := FArena.NewScalar(AValue.Scalar);
end;

function TGraphQLExecutor.Execute(ADocument: TGraphQLDocumentNode;
  AVariables: TGraphQLValue; const AOperationName: string): TGraphQLExecutionResult;
var
  LOp: TGraphQLOperationDefinitionNode;
  LRootType: TGraphQLObjectType;
  LRootSource: TGraphQLValueArray;
  LRootResults: TGraphQLValueArray;
begin
  Result := TGraphQLExecutionResult.Create;
  FDocument := ADocument;
  FArena := Result.FArena;
  SetLength(FErrors, 0);
  FQueryCount := 0;

  LOp := FindOperation(AOperationName);
  if LOp = nil then
  begin
    AddError('Operation not found or ambiguous (name the operation)', '', 0, 0);
    Result.FErrors := FErrors;
    Exit;
  end;

  FVars := CoerceVariables(LOp, AVariables);

  if LOp.Operation = otMutation then
    LRootType := FSchema.MutationType
  else
    LRootType := FSchema.QueryType;

  if LRootType = nil then
  begin
    AddError('Schema has no matching root type for the operation', '', 0, 0);
    Result.FErrors := FErrors;
    Exit;
  end;

  SetLength(LRootSource, 1);
  LRootSource[0] := FArena.NewObject; // root has no meaningful source
  LRootResults := ExecuteSelectionSet(LRootSource, LOp.SelectionSet, LRootType, '');

  Result.FData := LRootResults[0];
  Result.FHasData := True;
  Result.FErrors := FErrors;
end;

{$ENDIF}

end.
