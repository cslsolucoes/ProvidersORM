{ =============================================================================
  GraphQL.Validator - static validation of a document against a schema
  (FASE 13, wave 13A.4-b; spec Section 5, main rules)

  A pre-flight pass that accumulates errors WITHOUT executing. Rules covered
  (documented scope - not the full Section 5):
    - 5.2.2.1 Lone anonymous operation (an unnamed op cannot coexist with others)
    - 5.3.1  Field selections must exist on the type (+ __typename allowed)
    - 5.3.3  Leaf/branch: scalar/enum cannot have a sub-selection; object/interface
             must have one
    - 5.4.1  Argument names must be defined by the field
    - 5.5.1.1 Fragment spread target must be defined
    - 5.5.2.2 Fragment spreads must not form cycles
    - 5.8.3  A used variable must be defined by the operation

  Not covered (backlog, documented): argument/variable type coercion checks,
  fragment type-condition applicability, defined-but-unused variables, directive
  location rules, input-object field validation.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           12/08/2026

  Changelog (file):
  - 1.0.0 (12/08/2026): FASE 13 wave 13A.4-b - static validator (field existence,
    leaf/branch, known arguments, fragment target + cycle, lone anonymous op,
    used-variable-defined), accumulated errors with positions.
  ============================================================================= }

unit GraphQL.Validator;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../../ORM.Defines.inc}

{$IFDEF USE_GRAPHQL}

uses
{$IF DEFINED(FPC)}
  SysUtils,
{$ELSE}
  System.SysUtils,
{$ENDIF}
  GraphQL.Types,
  GraphQL.Consts,
  GraphQL.Core.Ast,
  GraphQL.Schema.Types,
  GraphQL.Schema;

type
  TGraphQLValidationError = record
    Message: string;
    Line: Integer;
    Column: Integer;
  end;
  TGraphQLValidationErrorArray = array of TGraphQLValidationError;

  TGraphQLValidator = class
  private
    FSchema: IGraphQLSchema;
    FDocument: TGraphQLDocumentNode;
    FErrors: TGraphQLValidationErrorArray;
    FDefinedVars: array of string; // current operation's declared variables
    procedure AddErr(const AMessage: string; const APos: TGraphQLPosition);
    function FindFragment(const AName: string): TGraphQLFragmentDefinitionNode;
    function VarIsDefined(const AName: string): Boolean;
    procedure CheckValueVars(ANode: TGraphQLValueNode);
    procedure ValidateArguments(const AArgs: TGraphQLArgumentArray;
      AFieldDef: TGraphQLFieldDef);
    procedure ValidateSelectionSet(ASelSet: TGraphQLSelectionSetNode;
      AObjectType: TGraphQLObjectType; var AVisited: array of string;
      var AVisitedCount: Integer);
  public
    constructor Create(ASchema: IGraphQLSchema);
    function Validate(ADocument: TGraphQLDocumentNode): TGraphQLValidationErrorArray;
    function IsValid(ADocument: TGraphQLDocumentNode): Boolean;
  end;

{$ENDIF}

implementation

{$IFDEF USE_GRAPHQL}

constructor TGraphQLValidator.Create(ASchema: IGraphQLSchema);
begin
  inherited Create;
  FSchema := ASchema;
end;

procedure TGraphQLValidator.AddErr(const AMessage: string; const APos: TGraphQLPosition);
begin
  SetLength(FErrors, Length(FErrors) + 1);
  FErrors[High(FErrors)].Message := AMessage;
  FErrors[High(FErrors)].Line := APos.Line;
  FErrors[High(FErrors)].Column := APos.Column;
end;

function TGraphQLValidator.FindFragment(const AName: string): TGraphQLFragmentDefinitionNode;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to High(FDocument.Definitions) do
    if FDocument.Definitions[I] is TGraphQLFragmentDefinitionNode then
      if TGraphQLFragmentDefinitionNode(FDocument.Definitions[I]).Name = AName then
        Exit(TGraphQLFragmentDefinitionNode(FDocument.Definitions[I]));
end;

function TGraphQLValidator.VarIsDefined(const AName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(FDefinedVars) do
    if FDefinedVars[I] = AName then
      Exit(True);
end;

procedure TGraphQLValidator.CheckValueVars(ANode: TGraphQLValueNode);
var
  I: Integer;
begin
  if ANode = nil then
    Exit;
  if ANode is TGraphQLVariableNode then
  begin
    if not VarIsDefined(TGraphQLVariableNode(ANode).Name) then
      AddErr(Format('Variable "$%s" is not defined', [TGraphQLVariableNode(ANode).Name]),
        ANode.Position);
  end
  else if ANode is TGraphQLListValueNode then
    for I := 0 to High(TGraphQLListValueNode(ANode).Values) do
      CheckValueVars(TGraphQLListValueNode(ANode).Values[I])
  else if ANode is TGraphQLObjectValueNode then
    for I := 0 to High(TGraphQLObjectValueNode(ANode).Fields) do
      CheckValueVars(TGraphQLObjectValueNode(ANode).Fields[I].Value);
end;

procedure TGraphQLValidator.ValidateArguments(const AArgs: TGraphQLArgumentArray;
  AFieldDef: TGraphQLFieldDef);
var
  I: Integer;
begin
  for I := 0 to High(AArgs) do
  begin
    if (AFieldDef <> nil) and (AFieldDef.FindArg(AArgs[I].Name) = nil) then
      AddErr(Format('Unknown argument "%s" on field "%s"',
        [AArgs[I].Name, AFieldDef.Name]), AArgs[I].Position);
    CheckValueVars(AArgs[I].Value);
  end;
end;

procedure TGraphQLValidator.ValidateSelectionSet(ASelSet: TGraphQLSelectionSetNode;
  AObjectType: TGraphQLObjectType; var AVisited: array of string;
  var AVisitedCount: Integer);
var
  I, V: Integer;
  LSel: TGraphQLSelectionNode;
  LField: TGraphQLFieldNode;
  LSpread: TGraphQLFragmentSpreadNode;
  LInline: TGraphQLInlineFragmentNode;
  LFrag: TGraphQLFragmentDefinitionNode;
  LFieldDef: TGraphQLFieldDef;
  LNamed: TGraphQLSchemaType;
  LCycle: Boolean;
begin
  if (ASelSet = nil) or (AObjectType = nil) then
    Exit;
  for I := 0 to High(ASelSet.Selections) do
  begin
    LSel := ASelSet.Selections[I];
    if LSel is TGraphQLFieldNode then
    begin
      LField := TGraphQLFieldNode(LSel);
      if LField.Name = GQL_INTROSPECT_TYPENAME then
        Continue; // __typename is always valid, scalar String
      LFieldDef := AObjectType.FindField(LField.Name);
      if LFieldDef = nil then
      begin
        AddErr(Format('Cannot query field "%s" on type "%s"',
          [LField.Name, AObjectType.Name]), LField.Position);
        Continue;
      end;
      ValidateArguments(LField.Arguments, LFieldDef);
      LNamed := nil;
      if LFieldDef.FieldType <> nil then
        LNamed := LFieldDef.FieldType.NamedType;
      if (LNamed is TGraphQLObjectType) then
      begin
        if LField.SelectionSet = nil then
          AddErr(Format('Field "%s" of object type "%s" must have a selection set',
            [LField.Name, LNamed.Name]), LField.Position)
        else
          ValidateSelectionSet(LField.SelectionSet, TGraphQLObjectType(LNamed),
            AVisited, AVisitedCount);
      end
      else
      begin
        // leaf (scalar/enum/interface-without-object handling): must NOT have a sub-selection
        if LField.SelectionSet <> nil then
          AddErr(Format('Field "%s" must not have a selection set (leaf type)',
            [LField.Name]), LField.Position);
      end;
    end
    else if LSel is TGraphQLInlineFragmentNode then
    begin
      LInline := TGraphQLInlineFragmentNode(LSel);
      ValidateSelectionSet(LInline.SelectionSet, AObjectType, AVisited, AVisitedCount);
    end
    else if LSel is TGraphQLFragmentSpreadNode then
    begin
      LSpread := TGraphQLFragmentSpreadNode(LSel);
      LFrag := FindFragment(LSpread.Name);
      if LFrag = nil then
      begin
        AddErr(Format('Unknown fragment "%s"', [LSpread.Name]), LSpread.Position);
        Continue;
      end;
      LCycle := False;
      for V := 0 to AVisitedCount - 1 do
        if AVisited[V] = LSpread.Name then
          LCycle := True;
      if LCycle then
      begin
        AddErr(Format('Fragment spread "%s" forms a cycle', [LSpread.Name]),
          LSpread.Position);
        Continue;
      end;
      AVisited[AVisitedCount] := LSpread.Name;
      Inc(AVisitedCount);
      ValidateSelectionSet(LFrag.SelectionSet, AObjectType, AVisited, AVisitedCount);
      Dec(AVisitedCount);
    end;
  end;
end;

function TGraphQLValidator.Validate(ADocument: TGraphQLDocumentNode): TGraphQLValidationErrorArray;
var
  I, J, LOpCount, LAnonCount: Integer;
  LDef: TGraphQLDefinitionNode;
  LOp: TGraphQLOperationDefinitionNode;
  LRootType: TGraphQLObjectType;
  LVisited: array of string;
  LVisitedCount: Integer;
begin
  FDocument := ADocument;
  SetLength(FErrors, 0);

  { 5.2.2.1 lone anonymous operation }
  LOpCount := 0;
  LAnonCount := 0;
  for I := 0 to High(ADocument.Definitions) do
    if ADocument.Definitions[I] is TGraphQLOperationDefinitionNode then
    begin
      Inc(LOpCount);
      if TGraphQLOperationDefinitionNode(ADocument.Definitions[I]).Name = '' then
        Inc(LAnonCount);
    end;
  if (LAnonCount > 0) and (LOpCount > 1) then
    AddErr('This anonymous operation must be the only defined operation',
      ADocument.Position);

  { validate each operation }
  for I := 0 to High(ADocument.Definitions) do
  begin
    LDef := ADocument.Definitions[I];
    if not (LDef is TGraphQLOperationDefinitionNode) then
      Continue;
    LOp := TGraphQLOperationDefinitionNode(LDef);
    // collect declared variables
    SetLength(FDefinedVars, Length(LOp.VariableDefinitions));
    for J := 0 to High(LOp.VariableDefinitions) do
      FDefinedVars[J] := LOp.VariableDefinitions[J].Variable.Name;
    // root type for the operation
    if LOp.Operation = otMutation then
      LRootType := FSchema.MutationType
    else if LOp.Operation = otSubscription then
      LRootType := FSchema.SubscriptionType
    else
      LRootType := FSchema.QueryType;
    if LRootType = nil then
    begin
      AddErr('Schema has no root type for this operation', LOp.Position);
      Continue;
    end;
    SetLength(LVisited, 256);
    LVisitedCount := 0;
    ValidateSelectionSet(LOp.SelectionSet, LRootType, LVisited, LVisitedCount);
  end;

  Result := FErrors;
end;

function TGraphQLValidator.IsValid(ADocument: TGraphQLDocumentNode): Boolean;
begin
  Result := Length(Validate(ADocument)) = 0;
end;

{$ENDIF}

end.
