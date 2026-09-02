{ =============================================================================
  GraphQL.Core.Parser - recursive-descent parser (FASE 13, wave 13A.1)

  Parses an EXECUTABLE GraphQL document (query/mutation/subscription + fragments,
  incl. the brace-shorthand) into the AST of GraphQL.Core.Ast. Lookahead of 1
  token over GraphQL.Core.Lexer. Permissive on const-ness (variables accepted in
  any value position) - const validation is a Section 5 concern (wave 13A.4).
  Positioned errors via EGraphQLParseException. Cross-compiler.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           11/08/2026

  Changelog (file):
  - 1.0.0 (11/08/2026): FASE 13 wave 13A.1 - full executable-document grammar:
    operations (long + shorthand), variable definitions, selection sets, fields
    (alias/args/directives/sub-selection), fragment spreads, inline fragments
    (optional type condition), fragment definitions, arguments, directives,
    values (variable/int/float/string/bool/null/enum/list/object) and type
    references (named/list/nonnull). Frees the whole tree on parse error.
  ============================================================================= }

unit GraphQL.Core.Parser;

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
  GraphQL.Exceptions,
  GraphQL.Core.Lexer,
  GraphQL.Core.Ast;

type
  TGraphQLParser = class
  private
    FLexer: TGraphQLLexer;
    FCurrent: TGraphQLToken;
    procedure NextToken;
    function CurrentIsName(const AName: string): Boolean;
    procedure Fail(const AMsg: string);
    procedure Expect(AKind: TGraphQLTokenKind);
    function ExpectName: string;
    // grammar
    function ParseDocument: TGraphQLDocumentNode;
    function ParseDefinition: TGraphQLDefinitionNode;
    function ParseOperationDefinition: TGraphQLDefinitionNode;
    function ParseFragmentDefinition: TGraphQLFragmentDefinitionNode;
    procedure ParseVariableDefinitions(AOp: TGraphQLOperationDefinitionNode);
    function ParseVariableDefinition: TGraphQLVariableDefinitionNode;
    function ParseSelectionSet: TGraphQLSelectionSetNode;
    function ParseSelection: TGraphQLSelectionNode;
    function ParseField: TGraphQLFieldNode;
    function ParseArguments: TGraphQLArgumentArray;
    function ParseArgument: TGraphQLArgumentNode;
    function ParseDirectives: TGraphQLDirectiveArray;
    function ParseDirective: TGraphQLDirectiveNode;
    function ParseValue: TGraphQLValueNode;
    function ParseType: TGraphQLTypeNode;
    function ParseNamedType: TGraphQLNamedTypeNode;
  public
    constructor Create(const ASource: string);
    destructor Destroy; override;
    { Parses the whole source into a document. Caller OWNS (and frees) it. }
    function Parse: TGraphQLDocumentNode;
  end;

{$ENDIF USE_GRAPHQL}

implementation

{$IFDEF USE_GRAPHQL}

constructor TGraphQLParser.Create(const ASource: string);
begin
  inherited Create;
  FLexer := TGraphQLLexer.Create(ASource);
end;

destructor TGraphQLParser.Destroy;
begin
  FLexer.Free;
  inherited Destroy;
end;

procedure TGraphQLParser.NextToken;
begin
  FCurrent := FLexer.Next;
end;

function TGraphQLParser.CurrentIsName(const AName: string): Boolean;
begin
  Result := (FCurrent.Kind = gtkName) and (FCurrent.Value = AName);
end;

procedure TGraphQLParser.Fail(const AMsg: string);
begin
  raise EGraphQLParseException.Create(AMsg, FCurrent.Position.Line,
    FCurrent.Position.Column, FCurrent.Value);
end;

procedure TGraphQLParser.Expect(AKind: TGraphQLTokenKind);
begin
  if FCurrent.Kind <> AKind then
    Fail(Format('Syntax error: unexpected token "%s"',
      [FCurrent.Value]));
  NextToken;
end;

function TGraphQLParser.ExpectName: string;
begin
  if FCurrent.Kind <> gtkName then
    Fail(Format('Syntax error: expected a Name but found "%s"', [FCurrent.Value]));
  Result := FCurrent.Value;
  NextToken;
end;

function TGraphQLParser.Parse: TGraphQLDocumentNode;
begin
  NextToken; // prime lookahead
  Result := ParseDocument;
end;

function TGraphQLParser.ParseDocument: TGraphQLDocumentNode;
begin
  Result := TGraphQLDocumentNode.Create;
  try
    if FCurrent.Kind = gtkEOF then
      Fail('Syntax error: empty document');
    while FCurrent.Kind <> gtkEOF do
      Result.Add(ParseDefinition);
  except
    Result.Free;
    raise;
  end;
end;

function TGraphQLParser.ParseDefinition: TGraphQLDefinitionNode;
begin
  Result := nil; // all non-assigning paths call Fail (which raises)
  if FCurrent.Kind = gtkBraceL then
    Result := ParseOperationDefinition // shorthand query
  else if FCurrent.Kind = gtkName then
  begin
    if CurrentIsName(GQL_KW_FRAGMENT) then
      Result := ParseFragmentDefinition
    else if CurrentIsName(GQL_KW_QUERY) or CurrentIsName(GQL_KW_MUTATION)
         or CurrentIsName(GQL_KW_SUBSCRIPTION) then
      Result := ParseOperationDefinition
    else
      Fail(Format('Syntax error: unexpected "%s" at top level', [FCurrent.Value]));
  end
  else
    Fail(Format('Syntax error: unexpected token "%s" at top level', [FCurrent.Value]));
end;

function TGraphQLParser.ParseOperationDefinition: TGraphQLDefinitionNode;
var
  LOp: TGraphQLOperationDefinitionNode;
  I: Integer;
  LDirs: TGraphQLDirectiveArray;
begin
  LOp := TGraphQLOperationDefinitionNode.Create(ankOperationDefinition, FCurrent.Position);
  Result := LOp;
  if FCurrent.Kind = gtkBraceL then
  begin
    LOp.Operation := otQuery; // anonymous shorthand
    LOp.SelectionSet := ParseSelectionSet;
    Exit;
  end;
  // operation type keyword
  if CurrentIsName(GQL_KW_QUERY) then
    LOp.Operation := otQuery
  else if CurrentIsName(GQL_KW_MUTATION) then
    LOp.Operation := otMutation
  else if CurrentIsName(GQL_KW_SUBSCRIPTION) then
    LOp.Operation := otSubscription
  else
    Fail('Syntax error: expected an operation type');
  NextToken;
  // optional name
  if FCurrent.Kind = gtkName then
  begin
    LOp.Name := FCurrent.Value;
    NextToken;
  end;
  // optional variable definitions
  if FCurrent.Kind = gtkParenL then
    ParseVariableDefinitions(LOp);
  // optional directives
  if FCurrent.Kind = gtkAt then
  begin
    LDirs := ParseDirectives;
    for I := 0 to High(LDirs) do
      LOp.AddDirective(LDirs[I]);
  end;
  // selection set
  LOp.SelectionSet := ParseSelectionSet;
end;

function TGraphQLParser.ParseFragmentDefinition: TGraphQLFragmentDefinitionNode;
var
  I: Integer;
  LDirs: TGraphQLDirectiveArray;
begin
  Result := TGraphQLFragmentDefinitionNode.Create(ankFragmentDefinition, FCurrent.Position);
  NextToken; // consume 'fragment'
  Result.Name := ExpectName;
  if Result.Name = GQL_KW_ON then
    Fail('Syntax error: fragment name cannot be "on"');
  if not CurrentIsName(GQL_KW_ON) then
    Fail('Syntax error: expected "on" in fragment definition');
  NextToken; // consume 'on'
  Result.TypeCondition := ParseNamedType;
  if FCurrent.Kind = gtkAt then
  begin
    LDirs := ParseDirectives;
    for I := 0 to High(LDirs) do
      Result.AddDirective(LDirs[I]);
  end;
  Result.SelectionSet := ParseSelectionSet;
end;

procedure TGraphQLParser.ParseVariableDefinitions(AOp: TGraphQLOperationDefinitionNode);
begin
  Expect(gtkParenL);
  if FCurrent.Kind = gtkParenR then
    Fail('Syntax error: empty variable definition list');
  while FCurrent.Kind <> gtkParenR do
  begin
    if FCurrent.Kind = gtkEOF then
      Fail('Syntax error: unterminated variable definitions');
    AOp.AddVariableDefinition(ParseVariableDefinition);
  end;
  Expect(gtkParenR);
end;

function TGraphQLParser.ParseVariableDefinition: TGraphQLVariableDefinitionNode;
var
  I: Integer;
  LDirs: TGraphQLDirectiveArray;
  LVarPos: TGraphQLPosition;
begin
  Result := TGraphQLVariableDefinitionNode.Create(ankVariableDefinition, FCurrent.Position);
  LVarPos := FCurrent.Position;
  Expect(gtkDollar);
  Result.Variable := TGraphQLVariableNode.Create(ExpectName, LVarPos);
  Expect(gtkColon);
  Result.VarType := ParseType;
  if FCurrent.Kind = gtkEquals then
  begin
    NextToken;
    Result.DefaultValue := ParseValue;
  end;
  if FCurrent.Kind = gtkAt then
  begin
    LDirs := ParseDirectives;
    for I := 0 to High(LDirs) do
      Result.AddDirective(LDirs[I]);
  end;
end;

function TGraphQLParser.ParseSelectionSet: TGraphQLSelectionSetNode;
begin
  Result := TGraphQLSelectionSetNode.Create(ankSelectionSet, FCurrent.Position);
  try
    Expect(gtkBraceL);
    if FCurrent.Kind = gtkBraceR then
      Fail('Syntax error: empty selection set');
    while FCurrent.Kind <> gtkBraceR do
    begin
      if FCurrent.Kind = gtkEOF then
        Fail('Syntax error: unterminated selection set');
      Result.Add(ParseSelection);
    end;
    Expect(gtkBraceR);
  except
    Result.Free;
    raise;
  end;
end;

function TGraphQLParser.ParseSelection: TGraphQLSelectionNode;
var
  LSpread: TGraphQLFragmentSpreadNode;
  LInline: TGraphQLInlineFragmentNode;
  LPos: TGraphQLPosition;
  I: Integer;
  LDirs: TGraphQLDirectiveArray;
begin
  if FCurrent.Kind <> gtkSpread then
  begin
    Result := ParseField;
    Exit;
  end;
  LPos := FCurrent.Position;
  NextToken; // consume '...'
  if CurrentIsName(GQL_KW_ON) or (FCurrent.Kind = gtkAt) or (FCurrent.Kind = gtkBraceL) then
  begin
    // inline fragment
    LInline := TGraphQLInlineFragmentNode.Create(ankInlineFragment, LPos);
    Result := LInline;
    if CurrentIsName(GQL_KW_ON) then
    begin
      NextToken; // consume 'on'
      LInline.TypeCondition := ParseNamedType;
    end;
    if FCurrent.Kind = gtkAt then
    begin
      LDirs := ParseDirectives;
      for I := 0 to High(LDirs) do
        LInline.AddDirective(LDirs[I]);
    end;
    LInline.SelectionSet := ParseSelectionSet;
  end
  else if FCurrent.Kind = gtkName then
  begin
    // fragment spread (name is not 'on')
    LSpread := TGraphQLFragmentSpreadNode.Create(ankFragmentSpread, LPos);
    Result := LSpread;
    LSpread.Name := FCurrent.Value;
    NextToken;
    if FCurrent.Kind = gtkAt then
    begin
      LDirs := ParseDirectives;
      for I := 0 to High(LDirs) do
        LSpread.AddDirective(LDirs[I]);
    end;
  end
  else
  begin
    Fail(Format('Syntax error: unexpected token "%s" after "..."', [FCurrent.Value]));
    Result := nil; // unreachable
  end;
end;

function TGraphQLParser.ParseField: TGraphQLFieldNode;
var
  LNameOrAlias: string;
  I: Integer;
  LArgs: TGraphQLArgumentArray;
  LDirs: TGraphQLDirectiveArray;
begin
  Result := TGraphQLFieldNode.Create(ankField, FCurrent.Position);
  try
    LNameOrAlias := ExpectName;
    if FCurrent.Kind = gtkColon then
    begin
      NextToken;
      Result.Alias := LNameOrAlias;
      Result.Name := ExpectName;
    end
    else
      Result.Name := LNameOrAlias;
    if FCurrent.Kind = gtkParenL then
    begin
      LArgs := ParseArguments;
      for I := 0 to High(LArgs) do
        Result.AddArgument(LArgs[I]);
    end;
    if FCurrent.Kind = gtkAt then
    begin
      LDirs := ParseDirectives;
      for I := 0 to High(LDirs) do
        Result.AddDirective(LDirs[I]);
    end;
    if FCurrent.Kind = gtkBraceL then
      Result.SelectionSet := ParseSelectionSet;
  except
    Result.Free;
    raise;
  end;
end;

function TGraphQLParser.ParseArguments: TGraphQLArgumentArray;
begin
  SetLength(Result, 0);
  Expect(gtkParenL);
  if FCurrent.Kind = gtkParenR then
    Fail('Syntax error: empty argument list');
  while FCurrent.Kind <> gtkParenR do
  begin
    if FCurrent.Kind = gtkEOF then
      Fail('Syntax error: unterminated arguments');
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := ParseArgument;
  end;
  Expect(gtkParenR);
end;

function TGraphQLParser.ParseArgument: TGraphQLArgumentNode;
begin
  Result := TGraphQLArgumentNode.Create(ankArgument, FCurrent.Position);
  try
    Result.Name := ExpectName;
    Expect(gtkColon);
    Result.Value := ParseValue;
  except
    Result.Free;
    raise;
  end;
end;

function TGraphQLParser.ParseDirectives: TGraphQLDirectiveArray;
begin
  SetLength(Result, 0);
  while FCurrent.Kind = gtkAt do
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := ParseDirective;
  end;
end;

function TGraphQLParser.ParseDirective: TGraphQLDirectiveNode;
var
  I: Integer;
  LArgs: TGraphQLArgumentArray;
begin
  Result := TGraphQLDirectiveNode.Create(ankDirective, FCurrent.Position);
  try
    Expect(gtkAt);
    Result.Name := ExpectName;
    if FCurrent.Kind = gtkParenL then
    begin
      LArgs := ParseArguments;
      for I := 0 to High(LArgs) do
        Result.AddArgument(LArgs[I]);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TGraphQLParser.ParseValue: TGraphQLValueNode;
var
  LList: TGraphQLListValueNode;
  LObj: TGraphQLObjectValueNode;
  LField: TGraphQLObjectFieldNode;
  LPos: TGraphQLPosition;
begin
  LPos := FCurrent.Position;
  case FCurrent.Kind of
    gtkDollar:
      begin
        NextToken;
        Result := TGraphQLVariableNode.Create(ExpectName, LPos);
      end;
    gtkInt:
      begin
        Result := TGraphQLIntValueNode.Create(FCurrent.Value, LPos);
        NextToken;
      end;
    gtkFloat:
      begin
        Result := TGraphQLFloatValueNode.Create(FCurrent.Value, LPos);
        NextToken;
      end;
    gtkString:
      begin
        Result := TGraphQLStringValueNode.Create(FCurrent.Value, FCurrent.IsBlock, LPos);
        NextToken;
      end;
    gtkName:
      begin
        if FCurrent.Value = GQL_KW_TRUE then
          Result := TGraphQLBooleanValueNode.Create(True, LPos)
        else if FCurrent.Value = GQL_KW_FALSE then
          Result := TGraphQLBooleanValueNode.Create(False, LPos)
        else if FCurrent.Value = GQL_KW_NULL then
          Result := TGraphQLNullValueNode.Create(ankNullValue, LPos)
        else
          Result := TGraphQLEnumValueNode.Create(FCurrent.Value, LPos);
        NextToken;
      end;
    gtkBracketL:
      begin
        LList := TGraphQLListValueNode.Create(ankListValue, LPos);
        Result := LList;
        try
          NextToken; // consume '['
          while FCurrent.Kind <> gtkBracketR do
          begin
            if FCurrent.Kind = gtkEOF then
              Fail('Syntax error: unterminated list value');
            LList.Add(ParseValue);
          end;
          NextToken; // consume ']'
        except
          Result.Free;
          raise;
        end;
      end;
    gtkBraceL:
      begin
        LObj := TGraphQLObjectValueNode.Create(ankObjectValue, LPos);
        Result := LObj;
        try
          NextToken; // consume '{'
          while FCurrent.Kind <> gtkBraceR do
          begin
            if FCurrent.Kind = gtkEOF then
              Fail('Syntax error: unterminated object value');
            LField := TGraphQLObjectFieldNode.Create(ankObjectField, FCurrent.Position);
            LObj.Add(LField);
            LField.Name := ExpectName;
            Expect(gtkColon);
            LField.Value := ParseValue;
          end;
          NextToken; // consume '}'
        except
          Result.Free;
          raise;
        end;
      end;
  else
    begin
      Fail(Format('Syntax error: unexpected token "%s" where a value was expected',
        [FCurrent.Value]));
      Result := nil; // unreachable
    end;
  end;
end;

function TGraphQLParser.ParseType: TGraphQLTypeNode;
var
  LInner: TGraphQLTypeNode;
  LList: TGraphQLListTypeNode;
  LNonNull: TGraphQLNonNullTypeNode;
  LPos: TGraphQLPosition;
begin
  LPos := FCurrent.Position;
  if FCurrent.Kind = gtkBracketL then
  begin
    NextToken; // consume '['
    LInner := ParseType;
    LList := TGraphQLListTypeNode.Create(ankListType, LPos);
    LList.OfType := LInner;
    Result := LList;
    Expect(gtkBracketR);
  end
  else
    Result := ParseNamedType;
  if FCurrent.Kind = gtkBang then
  begin
    LPos := FCurrent.Position;
    NextToken;
    LNonNull := TGraphQLNonNullTypeNode.Create(ankNonNullType, LPos);
    LNonNull.OfType := Result;
    Result := LNonNull;
  end;
end;

function TGraphQLParser.ParseNamedType: TGraphQLNamedTypeNode;
var
  LPos: TGraphQLPosition;
begin
  LPos := FCurrent.Position;
  Result := TGraphQLNamedTypeNode.Create(ExpectName, LPos);
end;

{$ENDIF USE_GRAPHQL}

end.
