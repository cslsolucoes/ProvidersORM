{ =============================================================================
  GraphQL.Value - runtime value tree for the executor (FASE 13, wave 13A.4)

  A TGraphQLValue is the carrier that flows through the executor: it is BOTH the
  "source" a resolver receives (e.g. an ORM row is an object of column->scalar
  pairs) AND the intermediate result a resolver returns (scalar / object / list /
  null). The final response is serialized to a JSON string (ToJSON) - own tree
  instead of System.JSON/fpjson to stay cross-compiler and give deterministic
  output for golden tests. Scalars are carried as Variant (no TValue - bug-808).

  OWNERSHIP: values do NOT free their children. A TGraphQLValueArena owns every
  node it creates and frees them all at once (FreeAll) - an arena avoids manual
  ownership bugs across resolver boundaries (the whole request is one arena).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           12/08/2026

  Changelog (file):
  - 1.0.0 (12/08/2026): FASE 13 wave 13A.4 - TGraphQLValue (null/scalar/object/
    list) + arena allocator + JSON serialization (RFC 8259 escaping).
  ============================================================================= }

unit GraphQL.Value;

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
  GraphQL.Types;

type
  TGraphQLValueKind = (gvkNull, gvkScalar, gvkObject, gvkList);

  TGraphQLValue = class;
  TGraphQLValueArray = array of TGraphQLValue;

  TGraphQLValuePair = record
    Name: string;
    Value: TGraphQLValue; // pointer (owned by the arena)
  end;
  TGraphQLValuePairArray = array of TGraphQLValuePair;

  { A node in the runtime value tree. Children are pointers owned by the arena,
    NOT freed here. }
  TGraphQLValue = class
  private
    FKind: TGraphQLValueKind;
    FScalar: Variant;
    FPairs: TGraphQLValuePairArray; // gvkObject
    FItems: TGraphQLValueArray;     // gvkList
  public
    property Kind: TGraphQLValueKind read FKind write FKind;
    property Scalar: Variant read FScalar write FScalar;
    property Pairs: TGraphQLValuePairArray read FPairs;
    property Items: TGraphQLValueArray read FItems;
    { object helpers }
    procedure SetField(const AName: string; AValue: TGraphQLValue);
    function GetField(const AName: string): TGraphQLValue; // nil if absent
    function HasField(const AName: string): Boolean;
    { list helpers }
    procedure AddItem(AValue: TGraphQLValue);
    function Count: Integer; // list length (0 otherwise)
    { convenience }
    function IsNull: Boolean;
  end;

  { Owns every TGraphQLValue created through it; frees them all on FreeAll/Destroy. }
  TGraphQLValueArena = class
  private
    FNodes: TGraphQLValueArray;
    function Track(AValue: TGraphQLValue): TGraphQLValue;
  public
    destructor Destroy; override;
    function NewNull: TGraphQLValue;
    function NewScalar(const AValue: Variant): TGraphQLValue;
    function NewObject: TGraphQLValue;
    function NewList: TGraphQLValue;
    procedure FreeAll;
  end;

{ Serializes a value tree to a JSON string (RFC 8259). ANull-safe. }
function GraphQLValueToJSON(AValue: TGraphQLValue): string;
{ Escapes a string as a JSON string literal (with surrounding quotes). Never
  QuotedStr (that is Pascal quoting, not JSON - bug-293). }
function GraphQLJSONQuote(const AText: string): string;
{ Renders a Variant scalar as its JSON token (number/string/bool/null). }
function GraphQLScalarToJSON(const AValue: Variant): string;
{ Parses a JSON document into a value tree (lenient: malformed -> Null). Used to
  read a GraphQL-over-HTTP request body (query, variables, operationName). }
function GraphQLParseJSON(const AText: string; AArena: TGraphQLValueArena): TGraphQLValue;

{$ENDIF}

implementation

{$IFDEF USE_GRAPHQL}

var
  GJSONFmt: TFormatSettings; // neutral: '.' decimal separator (JSON numbers)

{ TGraphQLValue }

procedure TGraphQLValue.SetField(const AName: string; AValue: TGraphQLValue);
var
  I: Integer;
begin
  for I := 0 to High(FPairs) do
    if FPairs[I].Name = AName then
    begin
      FPairs[I].Value := AValue;
      Exit;
    end;
  SetLength(FPairs, Length(FPairs) + 1);
  FPairs[High(FPairs)].Name := AName;
  FPairs[High(FPairs)].Value := AValue;
end;

function TGraphQLValue.GetField(const AName: string): TGraphQLValue;
var
  I: Integer;
begin
  for I := 0 to High(FPairs) do
    if FPairs[I].Name = AName then
      Exit(FPairs[I].Value);
  Result := nil;
end;

function TGraphQLValue.HasField(const AName: string): Boolean;
begin
  Result := GetField(AName) <> nil;
end;

procedure TGraphQLValue.AddItem(AValue: TGraphQLValue);
begin
  SetLength(FItems, Length(FItems) + 1);
  FItems[High(FItems)] := AValue;
end;

function TGraphQLValue.Count: Integer;
begin
  Result := Length(FItems);
end;

function TGraphQLValue.IsNull: Boolean;
begin
  Result := (FKind = gvkNull) or ((FKind = gvkScalar) and VarIsNull(FScalar));
end;

{ TGraphQLValueArena }

destructor TGraphQLValueArena.Destroy;
begin
  FreeAll;
  inherited Destroy;
end;

function TGraphQLValueArena.Track(AValue: TGraphQLValue): TGraphQLValue;
begin
  SetLength(FNodes, Length(FNodes) + 1);
  FNodes[High(FNodes)] := AValue;
  Result := AValue;
end;

function TGraphQLValueArena.NewNull: TGraphQLValue;
begin
  Result := Track(TGraphQLValue.Create);
  Result.Kind := gvkNull;
end;

function TGraphQLValueArena.NewScalar(const AValue: Variant): TGraphQLValue;
begin
  Result := Track(TGraphQLValue.Create);
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
    Result.Kind := gvkNull
  else
  begin
    Result.Kind := gvkScalar;
    Result.Scalar := AValue;
  end;
end;

function TGraphQLValueArena.NewObject: TGraphQLValue;
begin
  Result := Track(TGraphQLValue.Create);
  Result.Kind := gvkObject;
end;

function TGraphQLValueArena.NewList: TGraphQLValue;
begin
  Result := Track(TGraphQLValue.Create);
  Result.Kind := gvkList;
end;

procedure TGraphQLValueArena.FreeAll;
var
  I: Integer;
begin
  for I := 0 to High(FNodes) do
    FNodes[I].Free;
  SetLength(FNodes, 0);
end;

{ JSON serialization }

function GraphQLJSONQuote(const AText: string): string;
var
  I: Integer;
  C: Char;
  LSb: string;
begin
  LSb := '"';
  for I := 1 to Length(AText) do
  begin
    C := AText[I];
    case C of
      '"':  LSb := LSb + '\"';
      '\':  LSb := LSb + '\\';
      #8:   LSb := LSb + '\b';
      #9:   LSb := LSb + '\t';
      #10:  LSb := LSb + '\n';
      #12:  LSb := LSb + '\f';
      #13:  LSb := LSb + '\r';
    else
      if C < #32 then
        LSb := LSb + '\u' + LowerCase(IntToHex(Ord(C), 4))
      else
        LSb := LSb + C;
    end;
  end;
  Result := LSb + '"';
end;

function GraphQLScalarToJSON(const AValue: Variant): string;
var
  LType: Integer;
  LF: Extended;
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
    Exit('null');
  LType := VarType(AValue) and VarTypeMask;
  case LType of
    varBoolean:
      if Boolean(AValue) then
        Result := 'true'
      else
        Result := 'false';
    varShortInt, varByte, varSmallint, varWord, varInteger, varLongWord,
    varInt64{$IFDEF FPC}, varQWord{$ENDIF}:
      Result := VarToStr(AValue);
    varSingle, varDouble, varCurrency:
      begin
        LF := AValue;
        Result := FloatToStr(LF, GJSONFmt);
      end;
  else
    Result := GraphQLJSONQuote(VarToStr(AValue));
  end;
end;

function GraphQLValueToJSON(AValue: TGraphQLValue): string;
var
  I: Integer;
  LSb: string;
begin
  if (AValue = nil) or AValue.IsNull then
    Exit('null');
  case AValue.Kind of
    gvkScalar:
      Result := GraphQLScalarToJSON(AValue.Scalar);
    gvkObject:
      begin
        LSb := '{';
        for I := 0 to High(AValue.Pairs) do
        begin
          if I > 0 then
            LSb := LSb + ',';
          LSb := LSb + GraphQLJSONQuote(AValue.Pairs[I].Name) + ':' +
            GraphQLValueToJSON(AValue.Pairs[I].Value);
        end;
        Result := LSb + '}';
      end;
    gvkList:
      begin
        LSb := '[';
        for I := 0 to High(AValue.Items) do
        begin
          if I > 0 then
            LSb := LSb + ',';
          LSb := LSb + GraphQLValueToJSON(AValue.Items[I]);
        end;
        Result := LSb + ']';
      end;
  else
    Result := 'null';
  end;
end;

{ ---- JSON parsing (lenient) ---- }

function GraphQLParseJSON(const AText: string; AArena: TGraphQLValueArena): TGraphQLValue;
var
  LPos, LLen: Integer;

  procedure SkipWs;
  begin
    while (LPos <= LLen) and (AText[LPos] <= ' ') do
      Inc(LPos);
  end;

  function ParseValue: TGraphQLValue; forward;

  function ParseString: string;
  var
    C: Char;
    LCode: Integer;
  begin
    Result := '';
    Inc(LPos); // opening quote
    while (LPos <= LLen) and (AText[LPos] <> '"') do
    begin
      C := AText[LPos];
      if C = '\' then
      begin
        Inc(LPos);
        if LPos > LLen then
          Break;
        case AText[LPos] of
          '"': Result := Result + '"';
          '\': Result := Result + '\';
          '/': Result := Result + '/';
          'b': Result := Result + #8;
          'f': Result := Result + #12;
          'n': Result := Result + #10;
          'r': Result := Result + #13;
          't': Result := Result + #9;
          'u':
            begin
              if LPos + 4 <= LLen then
              begin
                LCode := StrToIntDef('$' + Copy(AText, LPos + 1, 4), 32);
                Result := Result + Char(LCode);
                Inc(LPos, 4);
              end;
            end;
        else
          Result := Result + AText[LPos];
        end;
        Inc(LPos);
      end
      else
      begin
        Result := Result + C;
        Inc(LPos);
      end;
    end;
    if (LPos <= LLen) and (AText[LPos] = '"') then
      Inc(LPos); // closing quote
  end;

  function ParseNumber: TGraphQLValue;
  var
    LStart: Integer;
    LNum: string;
    LIsFloat: Boolean;
    LI: Int64;
  begin
    LStart := LPos;
    LIsFloat := False;
    while (LPos <= LLen) and (Pos(AText[LPos], '0123456789+-.eE') > 0) do
    begin
      if (AText[LPos] = '.') or (AText[LPos] = 'e') or (AText[LPos] = 'E') then
        LIsFloat := True;
      Inc(LPos);
    end;
    LNum := Copy(AText, LStart, LPos - LStart);
    if LIsFloat then
      Result := AArena.NewScalar(StrToFloatDef(LNum, 0, GJSONFmt))
    else
    begin
      LI := StrToInt64Def(LNum, 0);
      Result := AArena.NewScalar(LI);
    end;
  end;

  function ParseArray: TGraphQLValue;
  begin
    Result := AArena.NewList;
    Inc(LPos); // '['
    SkipWs;
    if (LPos <= LLen) and (AText[LPos] = ']') then
    begin
      Inc(LPos);
      Exit;
    end;
    while LPos <= LLen do
    begin
      SkipWs;
      Result.AddItem(ParseValue);
      SkipWs;
      if (LPos <= LLen) and (AText[LPos] = ',') then
        Inc(LPos)
      else
        Break;
    end;
    SkipWs;
    if (LPos <= LLen) and (AText[LPos] = ']') then
      Inc(LPos);
  end;

  function ParseObject: TGraphQLValue;
  var
    LKey: string;
  begin
    Result := AArena.NewObject;
    Inc(LPos); // '{'
    SkipWs;
    if (LPos <= LLen) and (AText[LPos] = '}') then
    begin
      Inc(LPos);
      Exit;
    end;
    while LPos <= LLen do
    begin
      SkipWs;
      if (LPos <= LLen) and (AText[LPos] = '"') then
        LKey := ParseString
      else
        Break;
      SkipWs;
      if (LPos <= LLen) and (AText[LPos] = ':') then
        Inc(LPos);
      SkipWs;
      Result.SetField(LKey, ParseValue);
      SkipWs;
      if (LPos <= LLen) and (AText[LPos] = ',') then
        Inc(LPos)
      else
        Break;
    end;
    SkipWs;
    if (LPos <= LLen) and (AText[LPos] = '}') then
      Inc(LPos);
  end;

  function ParseValue: TGraphQLValue;
  begin
    SkipWs;
    if LPos > LLen then
      Exit(AArena.NewNull);
    case AText[LPos] of
      '{': Result := ParseObject;
      '[': Result := ParseArray;
      '"': Result := AArena.NewScalar(ParseString);
      't':
        begin
          Result := AArena.NewScalar(True);
          Inc(LPos, 4); // true
        end;
      'f':
        begin
          Result := AArena.NewScalar(False);
          Inc(LPos, 5); // false
        end;
      'n':
        begin
          Result := AArena.NewNull;
          Inc(LPos, 4); // null
        end;
    else
      Result := ParseNumber;
    end;
  end;

begin
  LPos := 1;
  LLen := Length(AText);
  Result := ParseValue;
end;

initialization
  GJSONFmt := FormatSettings;
  GJSONFmt.DecimalSeparator := '.';
  GJSONFmt.ThousandSeparator := #0;

{$ENDIF}

end.
