{ =============================================================================
  GraphQL.Core.Printer - AST -> canonical text (FASE 13, wave 13A.1)

  Renders an executable-document AST back to a normalized GraphQL string, so
  that parse -> print is stable and print -> parse -> print is idempotent
  (golden round-trip tests). 2-space indentation. Strings are always emitted as
  normal quoted strings with escapes (block-ness is normalized away but the
  VALUE round-trips). Cross-compiler.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           11/08/2026

  Changelog (file):
  - 1.0.0 (11/08/2026): FASE 13 wave 13A.1 - canonical printer for operations
    (long + shorthand), variable definitions, selection sets, fields, fragment
    spreads/inline fragments, fragment definitions, arguments, directives,
    values and type references.
  ============================================================================= }

unit GraphQL.Core.Printer;

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
  GraphQL.Core.Ast;

{ Renders a whole document to canonical text (definitions separated by a blank
  line, no trailing newline). }
function GraphQLPrintDocument(ADoc: TGraphQLDocumentNode): string;

{$ENDIF USE_GRAPHQL}

implementation

{$IFDEF USE_GRAPHQL}

function Indent(ALevel: Integer): string;
begin
  Result := StringOfChar(' ', ALevel * 2);
end;

function EncodeString(const S: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '"';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    case C of
      '"': Result := Result + '\"';
      '\': Result := Result + '\\';
      #8:  Result := Result + '\b';
      #12: Result := Result + '\f';
      #10: Result := Result + '\n';
      #13: Result := Result + '\r';
      #9:  Result := Result + '\t';
    else
      if C < ' ' then
        Result := Result + '\u' + IntToHex(Ord(C), 4)
      else
        Result := Result + C;
    end;
  end;
  Result := Result + '"';
end;

function PrintValue(AValue: TGraphQLValueNode): string; forward;

function PrintType(AType: TGraphQLTypeNode): string;
begin
  if AType is TGraphQLNamedTypeNode then
    Result := TGraphQLNamedTypeNode(AType).Name
  else if AType is TGraphQLListTypeNode then
    Result := '[' + PrintType(TGraphQLListTypeNode(AType).OfType) + ']'
  else if AType is TGraphQLNonNullTypeNode then
    Result := PrintType(TGraphQLNonNullTypeNode(AType).OfType) + '!'
  else
    Result := '';
end;

function PrintValue(AValue: TGraphQLValueNode): string;
var
  I: Integer;
  LList: TGraphQLListValueNode;
  LObj: TGraphQLObjectValueNode;
begin
  if AValue is TGraphQLVariableNode then
    Result := '$' + TGraphQLVariableNode(AValue).Name
  else if AValue is TGraphQLIntValueNode then
    Result := TGraphQLIntValueNode(AValue).Value
  else if AValue is TGraphQLFloatValueNode then
    Result := TGraphQLFloatValueNode(AValue).Value
  else if AValue is TGraphQLStringValueNode then
    Result := EncodeString(TGraphQLStringValueNode(AValue).Value)
  else if AValue is TGraphQLBooleanValueNode then
  begin
    if TGraphQLBooleanValueNode(AValue).Value then
      Result := GQL_KW_TRUE
    else
      Result := GQL_KW_FALSE;
  end
  else if AValue is TGraphQLNullValueNode then
    Result := GQL_KW_NULL
  else if AValue is TGraphQLEnumValueNode then
    Result := TGraphQLEnumValueNode(AValue).Value
  else if AValue is TGraphQLListValueNode then
  begin
    LList := TGraphQLListValueNode(AValue);
    Result := '[';
    for I := 0 to High(LList.Values) do
    begin
      if I > 0 then
        Result := Result + ', ';
      Result := Result + PrintValue(LList.Values[I]);
    end;
    Result := Result + ']';
  end
  else if AValue is TGraphQLObjectValueNode then
  begin
    LObj := TGraphQLObjectValueNode(AValue);
    Result := '{';
    for I := 0 to High(LObj.Fields) do
    begin
      if I > 0 then
        Result := Result + ', ';
      Result := Result + LObj.Fields[I].Name + ': ' + PrintValue(LObj.Fields[I].Value);
    end;
    Result := Result + '}';
  end
  else
    Result := '';
end;

function PrintArguments(const AArgs: TGraphQLArgumentArray): string;
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
    Result := Result + AArgs[I].Name + ': ' + PrintValue(AArgs[I].Value);
  end;
  Result := Result + ')';
end;

function PrintDirectives(const ADirs: TGraphQLDirectiveArray): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(ADirs) do
    Result := Result + ' @' + ADirs[I].Name + PrintArguments(ADirs[I].Arguments);
end;

function PrintSelectionSet(ASet: TGraphQLSelectionSetNode; ALevel: Integer): string; forward;

function PrintSelection(ASel: TGraphQLSelectionNode; ALevel: Integer): string;
var
  LField: TGraphQLFieldNode;
  LSpread: TGraphQLFragmentSpreadNode;
  LInline: TGraphQLInlineFragmentNode;
begin
  if ASel is TGraphQLFieldNode then
  begin
    LField := TGraphQLFieldNode(ASel);
    Result := '';
    if LField.Alias <> '' then
      Result := LField.Alias + ': ';
    Result := Result + LField.Name;
    Result := Result + PrintArguments(LField.Arguments);
    Result := Result + PrintDirectives(LField.Directives);
    if Assigned(LField.SelectionSet) then
      Result := Result + ' ' + PrintSelectionSet(LField.SelectionSet, ALevel);
  end
  else if ASel is TGraphQLFragmentSpreadNode then
  begin
    LSpread := TGraphQLFragmentSpreadNode(ASel);
    Result := '...' + LSpread.Name + PrintDirectives(LSpread.Directives);
  end
  else if ASel is TGraphQLInlineFragmentNode then
  begin
    LInline := TGraphQLInlineFragmentNode(ASel);
    Result := '...';
    if Assigned(LInline.TypeCondition) then
      Result := Result + ' on ' + LInline.TypeCondition.Name;
    Result := Result + PrintDirectives(LInline.Directives);
    Result := Result + ' ' + PrintSelectionSet(LInline.SelectionSet, ALevel);
  end
  else
    Result := '';
end;

function PrintSelectionSet(ASet: TGraphQLSelectionSetNode; ALevel: Integer): string;
var
  I: Integer;
begin
  Result := '{' + #10;
  for I := 0 to High(ASet.Selections) do
    Result := Result + Indent(ALevel + 1) +
      PrintSelection(ASet.Selections[I], ALevel + 1) + #10;
  Result := Result + Indent(ALevel) + '}';
end;

function PrintVariableDefinition(AVar: TGraphQLVariableDefinitionNode): string;
begin
  Result := '$' + AVar.Variable.Name + ': ' + PrintType(AVar.VarType);
  if Assigned(AVar.DefaultValue) then
    Result := Result + ' = ' + PrintValue(AVar.DefaultValue);
  Result := Result + PrintDirectives(AVar.Directives);
end;

function OperationTypeName(AOp: TGraphQLOperationType): string;
begin
  case AOp of
    otMutation: Result := GQL_KW_MUTATION;
    otSubscription: Result := GQL_KW_SUBSCRIPTION;
  else
    Result := GQL_KW_QUERY;
  end;
end;

function PrintDefinition(ADef: TGraphQLDefinitionNode): string;
var
  LOp: TGraphQLOperationDefinitionNode;
  LFrag: TGraphQLFragmentDefinitionNode;
  I: Integer;
  LIsShorthand: Boolean;
begin
  if ADef is TGraphQLOperationDefinitionNode then
  begin
    LOp := TGraphQLOperationDefinitionNode(ADef);
    LIsShorthand := (LOp.Operation = otQuery) and (LOp.Name = '') and
      (Length(LOp.VariableDefinitions) = 0) and (Length(LOp.Directives) = 0);
    if LIsShorthand then
    begin
      Result := PrintSelectionSet(LOp.SelectionSet, 0);
      Exit;
    end;
    Result := OperationTypeName(LOp.Operation);
    if LOp.Name <> '' then
      Result := Result + ' ' + LOp.Name;
    if Length(LOp.VariableDefinitions) > 0 then
    begin
      Result := Result + '(';
      for I := 0 to High(LOp.VariableDefinitions) do
      begin
        if I > 0 then
          Result := Result + ', ';
        Result := Result + PrintVariableDefinition(LOp.VariableDefinitions[I]);
      end;
      Result := Result + ')';
    end;
    Result := Result + PrintDirectives(LOp.Directives);
    Result := Result + ' ' + PrintSelectionSet(LOp.SelectionSet, 0);
  end
  else if ADef is TGraphQLFragmentDefinitionNode then
  begin
    LFrag := TGraphQLFragmentDefinitionNode(ADef);
    Result := 'fragment ' + LFrag.Name + ' on ' + LFrag.TypeCondition.Name +
      PrintDirectives(LFrag.Directives) + ' ' +
      PrintSelectionSet(LFrag.SelectionSet, 0);
  end
  else
    Result := '';
end;

function GraphQLPrintDocument(ADoc: TGraphQLDocumentNode): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(ADoc.Definitions) do
  begin
    if I > 0 then
      Result := Result + #10 + #10;
    Result := Result + PrintDefinition(ADoc.Definitions[I]);
  end;
end;

{$ENDIF USE_GRAPHQL}

end.
