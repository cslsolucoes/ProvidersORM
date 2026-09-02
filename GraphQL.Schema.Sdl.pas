{ =============================================================================
  GraphQL.Schema.Sdl - SDL (Schema Definition Language) parser
  (FASE 13, wave 13A.2)

  Parses SDL text (spec Section 3) into a TGraphQLSchemaBuilder, reusing the
  Core lexer. Supports: schema block, type (with implements), interface, union,
  enum, input, scalar; field arguments; type references ([X!]!). Descriptions
  and directives are skipped (best-effort - not emitted by PrintSDL, so the
  no-description/no-directive subset round-trips exactly). Default values on
  args/input fields are consumed but not yet round-tripped. Cross-compiler.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           11/08/2026

  Changelog (file):
  - 1.0.0 (11/08/2026): FASE 13 wave 13A.2 - SDL parser into the schema builder;
    GraphQLBuildFromSDL convenience (parse + build). Round-trips with PrintSDL
    on the description/directive/default-free subset.
  ============================================================================= }

unit GraphQL.Schema.Sdl;

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
  GraphQL.Schema.Types,
  GraphQL.Schema;

type
  TGraphQLSdlParser = class
  private
    FLexer: TGraphQLLexer;
    FCur: TGraphQLToken;
    FBuilder: TGraphQLSchemaBuilder; // not owned
    procedure Next;
    function CurIsName(const AName: string): Boolean;
    procedure Fail(const AMsg: string);
    procedure ExpectPunct(AKind: TGraphQLTokenKind; const AWhat: string);
    function ExpectName: string;
    function ReadTypeExpr: string;
    procedure SkipValue;
    procedure ParseFieldBody(AField: TGraphQLFieldDef);
    procedure ParseSchemaBlock;
    procedure ParseObjectDef;
    procedure ParseInterfaceDef;
    procedure ParseUnionDef;
    procedure ParseEnumDef;
    procedure ParseInputDef;
    procedure ParseScalarDef;
  public
    constructor Create(const ASdl: string);
    destructor Destroy; override;
    procedure ParseInto(ABuilder: TGraphQLSchemaBuilder);
  end;

{ Parses SDL and builds a validated schema in one call. }
function GraphQLBuildFromSDL(const ASdl: string): IGraphQLSchema;

{$ENDIF USE_GRAPHQL}

implementation

{$IFDEF USE_GRAPHQL}

constructor TGraphQLSdlParser.Create(const ASdl: string);
begin
  inherited Create;
  FLexer := TGraphQLLexer.Create(ASdl);
end;

destructor TGraphQLSdlParser.Destroy;
begin
  FLexer.Free;
  inherited Destroy;
end;

procedure TGraphQLSdlParser.Next;
begin
  FCur := FLexer.Next;
end;

function TGraphQLSdlParser.CurIsName(const AName: string): Boolean;
begin
  Result := (FCur.Kind = gtkName) and (FCur.Value = AName);
end;

procedure TGraphQLSdlParser.Fail(const AMsg: string);
begin
  raise EGraphQLParseException.Create('SDL: ' + AMsg, FCur.Position.Line,
    FCur.Position.Column, FCur.Value);
end;

procedure TGraphQLSdlParser.ExpectPunct(AKind: TGraphQLTokenKind; const AWhat: string);
begin
  if FCur.Kind <> AKind then
    Fail(Format('expected %s but found "%s"', [AWhat, FCur.Value]));
  Next;
end;

function TGraphQLSdlParser.ExpectName: string;
begin
  if FCur.Kind <> gtkName then
    Fail(Format('expected a Name but found "%s"', [FCur.Value]));
  Result := FCur.Value;
  Next;
end;

function TGraphQLSdlParser.ReadTypeExpr: string;
begin
  if FCur.Kind = gtkBracketL then
  begin
    Next;
    Result := '[' + ReadTypeExpr + ']';
    ExpectPunct(gtkBracketR, '"]"');
  end
  else if FCur.Kind = gtkName then
  begin
    Result := FCur.Value;
    Next;
  end
  else
  begin
    Fail(Format('expected a type but found "%s"', [FCur.Value]));
    Result := '';
  end;
  if FCur.Kind = gtkBang then
  begin
    Result := Result + '!';
    Next;
  end;
end;

procedure TGraphQLSdlParser.SkipValue;
begin
  case FCur.Kind of
    gtkBracketL:
      begin
        Next;
        while FCur.Kind <> gtkBracketR do
        begin
          if FCur.Kind = gtkEOF then
            Fail('unterminated list default value');
          SkipValue;
        end;
        Next;
      end;
    gtkBraceL:
      begin
        Next;
        while FCur.Kind <> gtkBraceR do
        begin
          if FCur.Kind = gtkEOF then
            Fail('unterminated object default value');
          ExpectName;
          ExpectPunct(gtkColon, '":"');
          SkipValue;
        end;
        Next;
      end;
    gtkDollar:
      begin
        Next;
        ExpectName;
      end;
    gtkInt, gtkFloat, gtkString, gtkName:
      Next;
  else
    Fail(Format('expected a value but found "%s"', [FCur.Value]));
  end;
end;

procedure TGraphQLSdlParser.ParseFieldBody(AField: TGraphQLFieldDef);
var
  LArgName, LArgType: string;
begin
  if FCur.Kind = gtkParenL then
  begin
    Next;
    while FCur.Kind <> gtkParenR do
    begin
      if FCur.Kind = gtkEOF then
        Fail('unterminated argument list');
      LArgName := ExpectName;
      ExpectPunct(gtkColon, '":"');
      LArgType := ReadTypeExpr;
      AField.AddArg(LArgName, LArgType);
      if FCur.Kind = gtkEquals then
      begin
        Next;
        SkipValue; // default value (not round-tripped yet)
      end;
      // directives on args are not supported yet
    end;
    Next; // ')'
  end;
  ExpectPunct(gtkColon, '":"');
  AField.TypeExpr := ReadTypeExpr;
end;

procedure TGraphQLSdlParser.ParseSchemaBlock;
var
  LOp, LTypeName: string;
begin
  Next; // 'schema'
  ExpectPunct(gtkBraceL, '"{"');
  while FCur.Kind <> gtkBraceR do
  begin
    if FCur.Kind = gtkEOF then
      Fail('unterminated schema block');
    LOp := ExpectName;
    ExpectPunct(gtkColon, '":"');
    LTypeName := ExpectName;
    if LOp = GQL_KW_QUERY then
      FBuilder.Query(LTypeName)
    else if LOp = GQL_KW_MUTATION then
      FBuilder.Mutation(LTypeName)
    else if LOp = GQL_KW_SUBSCRIPTION then
      FBuilder.Subscription(LTypeName)
    else
      Fail(Format('unknown root operation "%s"', [LOp]));
  end;
  Next; // '}'
end;

procedure TGraphQLSdlParser.ParseObjectDef;
var
  LObj: TGraphQLObjectType;
  LName: string;
  LField: TGraphQLFieldDef;
begin
  Next; // 'type'
  LName := ExpectName;
  LObj := FBuilder.ObjectType(LName);
  if CurIsName('implements') then
  begin
    Next;
    if FCur.Kind = gtkAmp then
      Next; // optional leading &
    LObj.AddInterfaceName(ExpectName);
    while FCur.Kind = gtkAmp do
    begin
      Next;
      LObj.AddInterfaceName(ExpectName);
    end;
  end;
  ExpectPunct(gtkBraceL, '"{"');
  while FCur.Kind <> gtkBraceR do
  begin
    if FCur.Kind = gtkEOF then
      Fail('unterminated type body');
    LField := LObj.AddField(ExpectName, '');
    ParseFieldBody(LField);
  end;
  Next; // '}'
end;

procedure TGraphQLSdlParser.ParseInterfaceDef;
var
  LIntf: TGraphQLInterfaceType;
  LField: TGraphQLFieldDef;
begin
  Next; // 'interface'
  LIntf := FBuilder.InterfaceType(ExpectName);
  ExpectPunct(gtkBraceL, '"{"');
  while FCur.Kind <> gtkBraceR do
  begin
    if FCur.Kind = gtkEOF then
      Fail('unterminated interface body');
    LField := LIntf.AddField(ExpectName, '');
    ParseFieldBody(LField);
  end;
  Next; // '}'
end;

procedure TGraphQLSdlParser.ParseUnionDef;
var
  LUnion: TGraphQLUnionType;
begin
  Next; // 'union'
  LUnion := FBuilder.UnionType(ExpectName);
  ExpectPunct(gtkEquals, '"="');
  if FCur.Kind = gtkPipe then
    Next; // optional leading |
  LUnion.AddMemberName(ExpectName);
  while FCur.Kind = gtkPipe do
  begin
    Next;
    LUnion.AddMemberName(ExpectName);
  end;
end;

procedure TGraphQLSdlParser.ParseEnumDef;
var
  LEnum: TGraphQLEnumType;
begin
  Next; // 'enum'
  LEnum := FBuilder.EnumType(ExpectName);
  ExpectPunct(gtkBraceL, '"{"');
  while FCur.Kind <> gtkBraceR do
  begin
    if FCur.Kind = gtkEOF then
      Fail('unterminated enum body');
    LEnum.AddValue(ExpectName);
  end;
  Next; // '}'
end;

procedure TGraphQLSdlParser.ParseInputDef;
var
  LInput: TGraphQLInputObjectType;
  LName, LType: string;
begin
  Next; // 'input'
  LInput := FBuilder.InputObjectType(ExpectName);
  ExpectPunct(gtkBraceL, '"{"');
  while FCur.Kind <> gtkBraceR do
  begin
    if FCur.Kind = gtkEOF then
      Fail('unterminated input body');
    LName := ExpectName;
    ExpectPunct(gtkColon, '":"');
    LType := ReadTypeExpr;
    LInput.AddInputField(LName, LType);
    if FCur.Kind = gtkEquals then
    begin
      Next;
      SkipValue;
    end;
  end;
  Next; // '}'
end;

procedure TGraphQLSdlParser.ParseScalarDef;
begin
  Next; // 'scalar'
  FBuilder.ScalarType(ExpectName);
end;

procedure TGraphQLSdlParser.ParseInto(ABuilder: TGraphQLSchemaBuilder);
begin
  FBuilder := ABuilder;
  Next; // prime
  while FCur.Kind <> gtkEOF do
  begin
    if FCur.Kind = gtkString then
    begin
      Next; // description - ignored
      Continue;
    end;
    if FCur.Kind <> gtkName then
      Fail(Format('unexpected token "%s" at top level', [FCur.Value]));
    if CurIsName('schema') then
      ParseSchemaBlock
    else if CurIsName('type') then
      ParseObjectDef
    else if CurIsName('interface') then
      ParseInterfaceDef
    else if CurIsName('union') then
      ParseUnionDef
    else if CurIsName('enum') then
      ParseEnumDef
    else if CurIsName('input') then
      ParseInputDef
    else if CurIsName('scalar') then
      ParseScalarDef
    else
      Fail(Format('unknown definition keyword "%s"', [FCur.Value]));
  end;
end;

function GraphQLBuildFromSDL(const ASdl: string): IGraphQLSchema;
var
  LBuilder: TGraphQLSchemaBuilder;
  LParser: TGraphQLSdlParser;
begin
  LBuilder := TGraphQLSchemaBuilder.Create;
  try
    LParser := TGraphQLSdlParser.Create(ASdl);
    try
      LParser.ParseInto(LBuilder);
    finally
      LParser.Free;
    end;
    Result := LBuilder.Build;
  finally
    LBuilder.Free;
  end;
end;

{$ENDIF USE_GRAPHQL}

end.
