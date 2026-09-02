{ =============================================================================
  GraphQL.Client.Query - fluent GraphQL document builder (FASE 13, wave 13B.1)

  Builds an executable document by assembling the Core AST (GraphQL.Core.Ast) and
  rendering it with the canonical Core printer (GraphQLPrintDocument) - so the
  client emits exactly the same normalized form the server parses (SSOT reuse, no
  hand-rolled text). Variables are kept SEPARATE from the document (never
  interpolated - the GraphQL analogue of bound :params) as a TGraphQLValue object
  (reusing the 13A value tree instead of System.JSON/fpjson). Validate() re-parses
  the emitted document with the Core parser (positioned errors before any network).

  Fluent, stack-based nesting (BeginSelection/EndSelection) - no closures, for
  cross-compiler safety (Delphi 12 + FPC 3.3.1).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           12/08/2026

  Changelog (file):
  - 1.0.0 (12/08/2026): FASE 13 wave 13B.1 - IGraphQLQuery fluent builder over the
    Core AST + printer; variables as a TGraphQLValue; local Validate via the parser.
  ============================================================================= }

unit GraphQL.Client.Query;

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
  GraphQL.Core.Ast,
  GraphQL.Core.Printer,
  GraphQL.Core.Parser,
  GraphQL.Value;

type
  IGraphQLQuery = interface
    ['{7A2C9E10-3B45-4D68-9E1A-2F4B6C8D0E12}']
    { operation + selection }
    function Operation(AType: TGraphQLOperationType; const AName: string = ''): IGraphQLQuery;
    function Field(const AName: string): IGraphQLQuery;
    function Alias(const AAlias: string): IGraphQLQuery;
    function BeginSelection: IGraphQLQuery;   // enter the last field's sub-selection
    function EndSelection: IGraphQLQuery;     // leave it
    { arguments on the last field }
    function Arg(const AName: string; const AValue: Variant): IGraphQLQuery; // literal
    function ArgVar(const AName, AVarName: string): IGraphQLQuery;           // $var
    function Directive(const AName: string): IGraphQLQuery;                  // @name
    { variables: declaration ($name: Type) + the value to send }
    function Variable(const AName, AType: string): IGraphQLQuery;
    function SetVar(const AName: string; const AValue: Variant): IGraphQLQuery;
    { output }
    function ToGraphQL: string;                 // canonical document text
    function OperationName: string;
    function Variables: TGraphQLValue;          // value tree (owned by the query)
    function Validate: Boolean;                 // re-parse locally; sets LastError
    function LastError: string;
  end;

function NewGraphQLQuery: IGraphQLQuery;

{$ENDIF}

implementation

{$IF DEFINED(USE_GRAPHQL) AND DEFINED(USE_GRAPHQL_CLIENT)}

type
  TSelStack = array of TGraphQLSelectionSetNode;

  TGraphQLQuery = class(TInterfacedObject, IGraphQLQuery)
  private
    FDoc: TGraphQLDocumentNode;                 // owns the whole AST
    FOp: TGraphQLOperationDefinitionNode;
    FStack: TSelStack;
    FLastField: TGraphQLFieldNode;
    FArena: TGraphQLValueArena;                 // owns FVars
    FVars: TGraphQLValue;
    FLastError: string;
    procedure Push(ASel: TGraphQLSelectionSetNode);
    procedure Pop;
    function Top: TGraphQLSelectionSetNode;
    procedure EnsureOperation;
  public
    constructor Create;
    destructor Destroy; override;
    function Operation(AType: TGraphQLOperationType; const AName: string = ''): IGraphQLQuery;
    function Field(const AName: string): IGraphQLQuery;
    function Alias(const AAlias: string): IGraphQLQuery;
    function BeginSelection: IGraphQLQuery;
    function EndSelection: IGraphQLQuery;
    function Arg(const AName: string; const AValue: Variant): IGraphQLQuery;
    function ArgVar(const AName, AVarName: string): IGraphQLQuery;
    function Directive(const AName: string): IGraphQLQuery;
    function Variable(const AName, AType: string): IGraphQLQuery;
    function SetVar(const AName: string; const AValue: Variant): IGraphQLQuery;
    function ToGraphQL: string;
    function OperationName: string;
    function Variables: TGraphQLValue;
    function Validate: Boolean;
    function LastError: string;
  end;

function P0: TGraphQLPosition;
begin
  Result.Line := 0;
  Result.Column := 0;
end;

{ builds a type-reference AST node from a string like "ID!", "[User!]!" }
function BuildTypeNode(const AExpr: string): TGraphQLTypeNode;
var
  LTrim: string;
  LInner: string;
  LNonNull: Boolean;
  LList: TGraphQLListTypeNode;
  LNN: TGraphQLNonNullTypeNode;
begin
  LTrim := Trim(AExpr);
  LNonNull := (LTrim <> '') and (LTrim[Length(LTrim)] = '!');
  if LNonNull then
    LTrim := Copy(LTrim, 1, Length(LTrim) - 1);
  if (LTrim <> '') and (LTrim[1] = '[') and (LTrim[Length(LTrim)] = ']') then
  begin
    LInner := Copy(LTrim, 2, Length(LTrim) - 2);
    LList := TGraphQLListTypeNode.Create(ankListType, P0);
    LList.OfType := BuildTypeNode(LInner);
    Result := LList;
  end
  else
    Result := TGraphQLNamedTypeNode.Create(LTrim, P0);
  if LNonNull then
  begin
    LNN := TGraphQLNonNullTypeNode.Create(ankNonNullType, P0);
    LNN.OfType := Result;
    Result := LNN;
  end;
end;

{ Variant -> value AST node (literal argument) }
function VariantToValueNode(const AValue: Variant): TGraphQLValueNode;
var
  LVt: Integer;
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
    Exit(TGraphQLNullValueNode.Create(ankNullValue, P0));
  LVt := VarType(AValue) and VarTypeMask;
  case LVt of
    varBoolean:
      Result := TGraphQLBooleanValueNode.Create(Boolean(AValue), P0);
    varShortInt, varByte, varSmallint, varWord, varInteger, varLongWord,
    varInt64{$IFDEF FPC}, varQWord{$ENDIF}:
      Result := TGraphQLIntValueNode.Create(VarToStr(AValue), P0);
    varSingle, varDouble, varCurrency:
      Result := TGraphQLFloatValueNode.Create(VarToStr(AValue), P0);
  else
    Result := TGraphQLStringValueNode.Create(VarToStr(AValue), False, P0);
  end;
end;

{ TGraphQLQuery }

constructor TGraphQLQuery.Create;
begin
  inherited Create;
  FDoc := TGraphQLDocumentNode.Create;
  FArena := TGraphQLValueArena.Create;
  FVars := FArena.NewObject;
  FOp := nil;
  FLastField := nil;
end;

destructor TGraphQLQuery.Destroy;
begin
  FDoc.Free;     // frees the whole AST
  FArena.Free;   // frees FVars
  inherited Destroy;
end;

procedure TGraphQLQuery.Push(ASel: TGraphQLSelectionSetNode);
begin
  SetLength(FStack, Length(FStack) + 1);
  FStack[High(FStack)] := ASel;
end;

procedure TGraphQLQuery.Pop;
begin
  if Length(FStack) > 0 then
    SetLength(FStack, Length(FStack) - 1);
end;

function TGraphQLQuery.Top: TGraphQLSelectionSetNode;
begin
  if Length(FStack) > 0 then
    Result := FStack[High(FStack)]
  else
    Result := nil;
end;

procedure TGraphQLQuery.EnsureOperation;
begin
  if FOp = nil then
    Operation(otQuery, '');
end;

function TGraphQLQuery.Operation(AType: TGraphQLOperationType; const AName: string): IGraphQLQuery;
begin
  FOp := TGraphQLOperationDefinitionNode.Create(ankOperationDefinition, P0);
  FOp.Operation := AType;
  FOp.Name := AName;
  FOp.SelectionSet := TGraphQLSelectionSetNode.Create(ankSelectionSet, P0);
  FDoc.Add(FOp);
  SetLength(FStack, 0);
  Push(FOp.SelectionSet);
  Result := Self;
end;

function TGraphQLQuery.Field(const AName: string): IGraphQLQuery;
var
  LField: TGraphQLFieldNode;
begin
  EnsureOperation;
  LField := TGraphQLFieldNode.Create(ankField, P0);
  LField.Name := AName;
  Top.Add(LField);
  FLastField := LField;
  Result := Self;
end;

function TGraphQLQuery.Alias(const AAlias: string): IGraphQLQuery;
begin
  if FLastField <> nil then
    FLastField.Alias := AAlias;
  Result := Self;
end;

function TGraphQLQuery.BeginSelection: IGraphQLQuery;
begin
  if FLastField <> nil then
  begin
    if FLastField.SelectionSet = nil then
      FLastField.SelectionSet := TGraphQLSelectionSetNode.Create(ankSelectionSet, P0);
    Push(FLastField.SelectionSet);
  end;
  Result := Self;
end;

function TGraphQLQuery.EndSelection: IGraphQLQuery;
begin
  Pop;
  FLastField := nil;
  Result := Self;
end;

function TGraphQLQuery.Arg(const AName: string; const AValue: Variant): IGraphQLQuery;
var
  LArg: TGraphQLArgumentNode;
begin
  if FLastField <> nil then
  begin
    LArg := TGraphQLArgumentNode.Create(ankArgument, P0);
    LArg.Name := AName;
    LArg.Value := VariantToValueNode(AValue);
    FLastField.AddArgument(LArg);
  end;
  Result := Self;
end;

function TGraphQLQuery.ArgVar(const AName, AVarName: string): IGraphQLQuery;
var
  LArg: TGraphQLArgumentNode;
begin
  if FLastField <> nil then
  begin
    LArg := TGraphQLArgumentNode.Create(ankArgument, P0);
    LArg.Name := AName;
    LArg.Value := TGraphQLVariableNode.Create(AVarName, P0);
    FLastField.AddArgument(LArg);
  end;
  Result := Self;
end;

function TGraphQLQuery.Directive(const AName: string): IGraphQLQuery;
var
  LDir: TGraphQLDirectiveNode;
begin
  if FLastField <> nil then
  begin
    LDir := TGraphQLDirectiveNode.Create(ankDirective, P0);
    LDir.Name := AName;
    FLastField.AddDirective(LDir);
  end;
  Result := Self;
end;

function TGraphQLQuery.Variable(const AName, AType: string): IGraphQLQuery;
var
  LDef: TGraphQLVariableDefinitionNode;
begin
  EnsureOperation;
  LDef := TGraphQLVariableDefinitionNode.Create(ankVariableDefinition, P0);
  LDef.Variable := TGraphQLVariableNode.Create(AName, P0);
  LDef.VarType := BuildTypeNode(AType);
  FOp.AddVariableDefinition(LDef);
  Result := Self;
end;

function TGraphQLQuery.SetVar(const AName: string; const AValue: Variant): IGraphQLQuery;
begin
  FVars.SetField(AName, FArena.NewScalar(AValue));
  Result := Self;
end;

function TGraphQLQuery.ToGraphQL: string;
begin
  Result := GraphQLPrintDocument(FDoc);
end;

function TGraphQLQuery.OperationName: string;
begin
  if FOp <> nil then
    Result := FOp.Name
  else
    Result := '';
end;

function TGraphQLQuery.Variables: TGraphQLValue;
begin
  Result := FVars;
end;

function TGraphQLQuery.Validate: Boolean;
var
  LParser: TGraphQLParser;
  LDoc: TGraphQLDocumentNode;
begin
  FLastError := '';
  Result := True;
  LParser := TGraphQLParser.Create(ToGraphQL);
  try
    try
      LDoc := LParser.Parse;
      LDoc.Free;
    except
      on E: Exception do
      begin
        FLastError := E.Message;
        Result := False;
      end;
    end;
  finally
    LParser.Free;
  end;
end;

function TGraphQLQuery.LastError: string;
begin
  Result := FLastError;
end;

function NewGraphQLQuery: IGraphQLQuery;
begin
  Result := TGraphQLQuery.Create;
end;

{$ENDIF}

end.
