{ =============================================================================
  GraphQL.Core.Ast - Abstract Syntax Tree for an EXECUTABLE GraphQL document
  (FASE 13, wave 13A.1). Shared by Server (13-A) and Client (13-B).

  Class hierarchy for query/mutation/subscription + fragments (spec Section 2).
  Ownership is MANUAL: every node owns its child nodes and frees them in its
  destructor; freeing the root TGraphQLDocumentNode frees the whole tree. No
  generics (cross-compiler safe on FPC 3.3.1). Positions come from GraphQL.Types.
  Values keep Int/Float as raw strings to avoid precision loss.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           11/08/2026

  Changelog (file):
  - 1.0.0 (11/08/2026): FASE 13 wave 13A.1 - executable-document AST: Document,
    OperationDefinition, VariableDefinition, SelectionSet, Field, Argument,
    FragmentSpread, InlineFragment, FragmentDefinition, Directive, value nodes
    (Variable/Int/Float/String/Boolean/Null/Enum/List/Object/ObjectField) and
    type references (Named/List/NonNull). Manual ownership.
  ============================================================================= }

unit GraphQL.Core.Ast;

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
  GraphQL.Types;

type
  // Forward declarations
  TGraphQLAstNode = class;
  TGraphQLValueNode = class;
  TGraphQLTypeNode = class;
  TGraphQLNamedTypeNode = class;
  TGraphQLVariableNode = class;
  TGraphQLArgumentNode = class;
  TGraphQLDirectiveNode = class;
  TGraphQLObjectFieldNode = class;
  TGraphQLSelectionNode = class;
  TGraphQLSelectionSetNode = class;
  TGraphQLVariableDefinitionNode = class;
  TGraphQLDefinitionNode = class;

  TGraphQLValueArray             = array of TGraphQLValueNode;
  TGraphQLArgumentArray          = array of TGraphQLArgumentNode;
  TGraphQLDirectiveArray         = array of TGraphQLDirectiveNode;
  TGraphQLObjectFieldArray       = array of TGraphQLObjectFieldNode;
  TGraphQLSelectionArray         = array of TGraphQLSelectionNode;
  TGraphQLVariableDefinitionArray = array of TGraphQLVariableDefinitionNode;
  TGraphQLDefinitionArray        = array of TGraphQLDefinitionNode;

  { Root of every AST node. Carries the node kind and its 1-based position. }
  TGraphQLAstNode = class
  private
    FKind: TGraphQLAstNodeKind;
    FPosition: TGraphQLPosition;
  public
    constructor Create(AKind: TGraphQLAstNodeKind; const APosition: TGraphQLPosition);
    property Kind: TGraphQLAstNodeKind read FKind;
    property Position: TGraphQLPosition read FPosition;
  end;

  { ---- Value nodes (spec 2.9) ---- }

  TGraphQLValueNode = class(TGraphQLAstNode); // abstract base for values

  { $name - also a value (used inside arguments / default values). }
  TGraphQLVariableNode = class(TGraphQLValueNode)
  private
    FName: string;
  public
    constructor Create(const AName: string; const APosition: TGraphQLPosition);
    property Name: string read FName;
  end;

  TGraphQLIntValueNode = class(TGraphQLValueNode)
  private
    FValue: string; // raw digits (no precision loss)
  public
    constructor Create(const AValue: string; const APosition: TGraphQLPosition);
    property Value: string read FValue;
  end;

  TGraphQLFloatValueNode = class(TGraphQLValueNode)
  private
    FValue: string; // raw text
  public
    constructor Create(const AValue: string; const APosition: TGraphQLPosition);
    property Value: string read FValue;
  end;

  TGraphQLStringValueNode = class(TGraphQLValueNode)
  private
    FValue: string;    // decoded value
    FIsBlock: Boolean; // """ block string """
  public
    constructor Create(const AValue: string; AIsBlock: Boolean;
      const APosition: TGraphQLPosition);
    property Value: string read FValue;
    property IsBlock: Boolean read FIsBlock;
  end;

  TGraphQLBooleanValueNode = class(TGraphQLValueNode)
  private
    FValue: Boolean;
  public
    constructor Create(AValue: Boolean; const APosition: TGraphQLPosition);
    property Value: Boolean read FValue;
  end;

  TGraphQLNullValueNode = class(TGraphQLValueNode); // null keyword

  TGraphQLEnumValueNode = class(TGraphQLValueNode)
  private
    FValue: string;
  public
    constructor Create(const AValue: string; const APosition: TGraphQLPosition);
    property Value: string read FValue;
  end;

  TGraphQLListValueNode = class(TGraphQLValueNode)
  private
    FValues: TGraphQLValueArray; // owned
  public
    destructor Destroy; override;
    procedure Add(ANode: TGraphQLValueNode);
    property Values: TGraphQLValueArray read FValues;
  end;

  { name: value inside an ObjectValue. }
  TGraphQLObjectFieldNode = class(TGraphQLAstNode)
  private
    FName: string;
    FValue: TGraphQLValueNode; // owned
  public
    destructor Destroy; override;
    property Name: string read FName write FName;
    property Value: TGraphQLValueNode read FValue write FValue;
  end;

  TGraphQLObjectValueNode = class(TGraphQLValueNode)
  private
    FFields: TGraphQLObjectFieldArray; // owned
  public
    destructor Destroy; override;
    procedure Add(ANode: TGraphQLObjectFieldNode);
    property Fields: TGraphQLObjectFieldArray read FFields;
  end;

  { ---- Type references (spec 2.11) ---- }

  TGraphQLTypeNode = class(TGraphQLAstNode); // abstract

  TGraphQLNamedTypeNode = class(TGraphQLTypeNode)
  private
    FName: string;
  public
    constructor Create(const AName: string; const APosition: TGraphQLPosition);
    property Name: string read FName;
  end;

  TGraphQLListTypeNode = class(TGraphQLTypeNode)
  private
    FOfType: TGraphQLTypeNode; // owned
  public
    destructor Destroy; override;
    property OfType: TGraphQLTypeNode read FOfType write FOfType;
  end;

  TGraphQLNonNullTypeNode = class(TGraphQLTypeNode)
  private
    FOfType: TGraphQLTypeNode; // owned (Named or List)
  public
    destructor Destroy; override;
    property OfType: TGraphQLTypeNode read FOfType write FOfType;
  end;

  { ---- Arguments / directives ---- }

  TGraphQLArgumentNode = class(TGraphQLAstNode)
  private
    FName: string;
    FValue: TGraphQLValueNode; // owned
  public
    destructor Destroy; override;
    property Name: string read FName write FName;
    property Value: TGraphQLValueNode read FValue write FValue;
  end;

  TGraphQLDirectiveNode = class(TGraphQLAstNode)
  private
    FName: string;
    FArguments: TGraphQLArgumentArray; // owned
  public
    destructor Destroy; override;
    procedure AddArgument(ANode: TGraphQLArgumentNode);
    property Name: string read FName write FName;
    property Arguments: TGraphQLArgumentArray read FArguments;
  end;

  { ---- Selections ---- }

  TGraphQLSelectionNode = class(TGraphQLAstNode); // abstract

  TGraphQLFieldNode = class(TGraphQLSelectionNode)
  private
    FAlias: string;
    FName: string;
    FArguments: TGraphQLArgumentArray;   // owned
    FDirectives: TGraphQLDirectiveArray; // owned
    FSelectionSet: TGraphQLSelectionSetNode; // owned, may be nil
  public
    destructor Destroy; override;
    procedure AddArgument(ANode: TGraphQLArgumentNode);
    procedure AddDirective(ANode: TGraphQLDirectiveNode);
    property Alias: string read FAlias write FAlias;
    property Name: string read FName write FName;
    property Arguments: TGraphQLArgumentArray read FArguments;
    property Directives: TGraphQLDirectiveArray read FDirectives;
    property SelectionSet: TGraphQLSelectionSetNode read FSelectionSet write FSelectionSet;
  end;

  TGraphQLFragmentSpreadNode = class(TGraphQLSelectionNode)
  private
    FName: string;
    FDirectives: TGraphQLDirectiveArray; // owned
  public
    destructor Destroy; override;
    procedure AddDirective(ANode: TGraphQLDirectiveNode);
    property Name: string read FName write FName;
    property Directives: TGraphQLDirectiveArray read FDirectives;
  end;

  TGraphQLInlineFragmentNode = class(TGraphQLSelectionNode)
  private
    FTypeCondition: TGraphQLNamedTypeNode;   // owned, may be nil
    FDirectives: TGraphQLDirectiveArray;     // owned
    FSelectionSet: TGraphQLSelectionSetNode; // owned
  public
    destructor Destroy; override;
    procedure AddDirective(ANode: TGraphQLDirectiveNode);
    property TypeCondition: TGraphQLNamedTypeNode read FTypeCondition write FTypeCondition;
    property Directives: TGraphQLDirectiveArray read FDirectives;
    property SelectionSet: TGraphQLSelectionSetNode read FSelectionSet write FSelectionSet;
  end;

  TGraphQLSelectionSetNode = class(TGraphQLAstNode)
  private
    FSelections: TGraphQLSelectionArray; // owned
  public
    destructor Destroy; override;
    procedure Add(ANode: TGraphQLSelectionNode);
    property Selections: TGraphQLSelectionArray read FSelections;
  end;

  { ---- Definitions ---- }

  TGraphQLVariableDefinitionNode = class(TGraphQLAstNode)
  private
    FVariable: TGraphQLVariableNode;     // owned
    FVarType: TGraphQLTypeNode;          // owned
    FDefaultValue: TGraphQLValueNode;    // owned, may be nil
    FDirectives: TGraphQLDirectiveArray; // owned
  public
    destructor Destroy; override;
    procedure AddDirective(ANode: TGraphQLDirectiveNode);
    property Variable: TGraphQLVariableNode read FVariable write FVariable;
    property VarType: TGraphQLTypeNode read FVarType write FVarType;
    property DefaultValue: TGraphQLValueNode read FDefaultValue write FDefaultValue;
    property Directives: TGraphQLDirectiveArray read FDirectives;
  end;

  TGraphQLDefinitionNode = class(TGraphQLAstNode); // abstract

  TGraphQLOperationDefinitionNode = class(TGraphQLDefinitionNode)
  private
    FOperation: TGraphQLOperationType;
    FName: string;
    FVariableDefinitions: TGraphQLVariableDefinitionArray; // owned
    FDirectives: TGraphQLDirectiveArray;                   // owned
    FSelectionSet: TGraphQLSelectionSetNode;               // owned
  public
    destructor Destroy; override;
    procedure AddVariableDefinition(ANode: TGraphQLVariableDefinitionNode);
    procedure AddDirective(ANode: TGraphQLDirectiveNode);
    property Operation: TGraphQLOperationType read FOperation write FOperation;
    property Name: string read FName write FName;
    property VariableDefinitions: TGraphQLVariableDefinitionArray read FVariableDefinitions;
    property Directives: TGraphQLDirectiveArray read FDirectives;
    property SelectionSet: TGraphQLSelectionSetNode read FSelectionSet write FSelectionSet;
  end;

  TGraphQLFragmentDefinitionNode = class(TGraphQLDefinitionNode)
  private
    FName: string;
    FTypeCondition: TGraphQLNamedTypeNode;   // owned
    FDirectives: TGraphQLDirectiveArray;     // owned
    FSelectionSet: TGraphQLSelectionSetNode; // owned
  public
    destructor Destroy; override;
    procedure AddDirective(ANode: TGraphQLDirectiveNode);
    property Name: string read FName write FName;
    property TypeCondition: TGraphQLNamedTypeNode read FTypeCondition write FTypeCondition;
    property Directives: TGraphQLDirectiveArray read FDirectives;
    property SelectionSet: TGraphQLSelectionSetNode read FSelectionSet write FSelectionSet;
  end;

  { Root node - owns every definition (and thus the whole tree). }
  TGraphQLDocumentNode = class(TGraphQLAstNode)
  private
    FDefinitions: TGraphQLDefinitionArray; // owned
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    procedure Add(ANode: TGraphQLDefinitionNode);
    property Definitions: TGraphQLDefinitionArray read FDefinitions;
  end;

{$ENDIF USE_GRAPHQL}

implementation

{$IFDEF USE_GRAPHQL}

{ TGraphQLAstNode }

constructor TGraphQLAstNode.Create(AKind: TGraphQLAstNodeKind;
  const APosition: TGraphQLPosition);
begin
  inherited Create;
  FKind := AKind;
  FPosition := APosition;
end;

{ Value nodes }

constructor TGraphQLVariableNode.Create(const AName: string;
  const APosition: TGraphQLPosition);
begin
  inherited Create(ankVariable, APosition);
  FName := AName;
end;

constructor TGraphQLIntValueNode.Create(const AValue: string;
  const APosition: TGraphQLPosition);
begin
  inherited Create(ankIntValue, APosition);
  FValue := AValue;
end;

constructor TGraphQLFloatValueNode.Create(const AValue: string;
  const APosition: TGraphQLPosition);
begin
  inherited Create(ankFloatValue, APosition);
  FValue := AValue;
end;

constructor TGraphQLStringValueNode.Create(const AValue: string;
  AIsBlock: Boolean; const APosition: TGraphQLPosition);
begin
  inherited Create(ankStringValue, APosition);
  FValue := AValue;
  FIsBlock := AIsBlock;
end;

constructor TGraphQLBooleanValueNode.Create(AValue: Boolean;
  const APosition: TGraphQLPosition);
begin
  inherited Create(ankBooleanValue, APosition);
  FValue := AValue;
end;

constructor TGraphQLEnumValueNode.Create(const AValue: string;
  const APosition: TGraphQLPosition);
begin
  inherited Create(ankEnumValue, APosition);
  FValue := AValue;
end;

destructor TGraphQLListValueNode.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FValues) do
    FValues[I].Free;
  inherited Destroy;
end;

procedure TGraphQLListValueNode.Add(ANode: TGraphQLValueNode);
begin
  SetLength(FValues, Length(FValues) + 1);
  FValues[High(FValues)] := ANode;
end;

destructor TGraphQLObjectFieldNode.Destroy;
begin
  FValue.Free;
  inherited Destroy;
end;

destructor TGraphQLObjectValueNode.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FFields) do
    FFields[I].Free;
  inherited Destroy;
end;

procedure TGraphQLObjectValueNode.Add(ANode: TGraphQLObjectFieldNode);
begin
  SetLength(FFields, Length(FFields) + 1);
  FFields[High(FFields)] := ANode;
end;

{ Type references }

constructor TGraphQLNamedTypeNode.Create(const AName: string;
  const APosition: TGraphQLPosition);
begin
  inherited Create(ankNamedType, APosition);
  FName := AName;
end;

destructor TGraphQLListTypeNode.Destroy;
begin
  FOfType.Free;
  inherited Destroy;
end;

destructor TGraphQLNonNullTypeNode.Destroy;
begin
  FOfType.Free;
  inherited Destroy;
end;

{ Arguments / directives }

destructor TGraphQLArgumentNode.Destroy;
begin
  FValue.Free;
  inherited Destroy;
end;

destructor TGraphQLDirectiveNode.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FArguments) do
    FArguments[I].Free;
  inherited Destroy;
end;

procedure TGraphQLDirectiveNode.AddArgument(ANode: TGraphQLArgumentNode);
begin
  SetLength(FArguments, Length(FArguments) + 1);
  FArguments[High(FArguments)] := ANode;
end;

{ Selections }

destructor TGraphQLFieldNode.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FArguments) do
    FArguments[I].Free;
  for I := 0 to High(FDirectives) do
    FDirectives[I].Free;
  FSelectionSet.Free;
  inherited Destroy;
end;

procedure TGraphQLFieldNode.AddArgument(ANode: TGraphQLArgumentNode);
begin
  SetLength(FArguments, Length(FArguments) + 1);
  FArguments[High(FArguments)] := ANode;
end;

procedure TGraphQLFieldNode.AddDirective(ANode: TGraphQLDirectiveNode);
begin
  SetLength(FDirectives, Length(FDirectives) + 1);
  FDirectives[High(FDirectives)] := ANode;
end;

destructor TGraphQLFragmentSpreadNode.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FDirectives) do
    FDirectives[I].Free;
  inherited Destroy;
end;

procedure TGraphQLFragmentSpreadNode.AddDirective(ANode: TGraphQLDirectiveNode);
begin
  SetLength(FDirectives, Length(FDirectives) + 1);
  FDirectives[High(FDirectives)] := ANode;
end;

destructor TGraphQLInlineFragmentNode.Destroy;
var
  I: Integer;
begin
  FTypeCondition.Free;
  for I := 0 to High(FDirectives) do
    FDirectives[I].Free;
  FSelectionSet.Free;
  inherited Destroy;
end;

procedure TGraphQLInlineFragmentNode.AddDirective(ANode: TGraphQLDirectiveNode);
begin
  SetLength(FDirectives, Length(FDirectives) + 1);
  FDirectives[High(FDirectives)] := ANode;
end;

destructor TGraphQLSelectionSetNode.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FSelections) do
    FSelections[I].Free;
  inherited Destroy;
end;

procedure TGraphQLSelectionSetNode.Add(ANode: TGraphQLSelectionNode);
begin
  SetLength(FSelections, Length(FSelections) + 1);
  FSelections[High(FSelections)] := ANode;
end;

{ Definitions }

destructor TGraphQLVariableDefinitionNode.Destroy;
var
  I: Integer;
begin
  FVariable.Free;
  FVarType.Free;
  FDefaultValue.Free;
  for I := 0 to High(FDirectives) do
    FDirectives[I].Free;
  inherited Destroy;
end;

procedure TGraphQLVariableDefinitionNode.AddDirective(ANode: TGraphQLDirectiveNode);
begin
  SetLength(FDirectives, Length(FDirectives) + 1);
  FDirectives[High(FDirectives)] := ANode;
end;

destructor TGraphQLOperationDefinitionNode.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FVariableDefinitions) do
    FVariableDefinitions[I].Free;
  for I := 0 to High(FDirectives) do
    FDirectives[I].Free;
  FSelectionSet.Free;
  inherited Destroy;
end;

procedure TGraphQLOperationDefinitionNode.AddVariableDefinition(
  ANode: TGraphQLVariableDefinitionNode);
begin
  SetLength(FVariableDefinitions, Length(FVariableDefinitions) + 1);
  FVariableDefinitions[High(FVariableDefinitions)] := ANode;
end;

procedure TGraphQLOperationDefinitionNode.AddDirective(ANode: TGraphQLDirectiveNode);
begin
  SetLength(FDirectives, Length(FDirectives) + 1);
  FDirectives[High(FDirectives)] := ANode;
end;

destructor TGraphQLFragmentDefinitionNode.Destroy;
var
  I: Integer;
begin
  FTypeCondition.Free;
  for I := 0 to High(FDirectives) do
    FDirectives[I].Free;
  FSelectionSet.Free;
  inherited Destroy;
end;

procedure TGraphQLFragmentDefinitionNode.AddDirective(ANode: TGraphQLDirectiveNode);
begin
  SetLength(FDirectives, Length(FDirectives) + 1);
  FDirectives[High(FDirectives)] := ANode;
end;

{ TGraphQLDocumentNode }

constructor TGraphQLDocumentNode.Create;
var
  LPos: TGraphQLPosition;
begin
  LPos.Line := 1;
  LPos.Column := 1;
  inherited Create(ankDocument, LPos);
end;

destructor TGraphQLDocumentNode.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FDefinitions) do
    FDefinitions[I].Free;
  inherited Destroy;
end;

procedure TGraphQLDocumentNode.Add(ANode: TGraphQLDefinitionNode);
begin
  SetLength(FDefinitions, Length(FDefinitions) + 1);
  FDefinitions[High(FDefinitions)] := ANode;
end;

{$ENDIF USE_GRAPHQL}

end.
