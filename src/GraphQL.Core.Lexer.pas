{ =============================================================================
  GraphQL.Core.Lexer - tokenizer for GraphQL source (FASE 13, wave 13A.1)

  Char-by-char lexer per spec Section 2.1. Skips ignored tokens (whitespace,
  line terminators, comments '#', commas), and emits significant tokens with
  1-based Line/Column positions: punctuators (incl. '...'), Name, Int, Float,
  String (normal + block, with escapes and block-string dedent). Raises
  EGraphQLParseException on invalid input. Cross-compiler (Delphi + FPC 3.3.1).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           11/08/2026

  Changelog (file):
  - 1.0.0 (11/08/2026): FASE 13 wave 13A.1 - lexer with ignored-token skipping,
    16 punctuators, Name/Int/Float, normal string (\" \\ \/ \b \f \n \r \t
    \uXXXX and variable-width unicode escapes) and block string with
    common-indent dedent (spec 2.1.7).
  ============================================================================= }

unit GraphQL.Core.Lexer;

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
  GraphQL.Exceptions;

type
  { A lexical token. For gtkString, IsBlock tells normal vs block string; Value
    holds the DECODED text. For Int/Float/Name, Value is the raw lexeme. }
  TGraphQLToken = record
    Kind: TGraphQLTokenKind;
    Value: string;
    Position: TGraphQLPosition;
    IsBlock: Boolean;
  end;

  TGraphQLLexer = class
  private
    FSource: string;
    FPos: Integer;      // 1-based index into FSource
    FLen: Integer;
    FLine: Integer;
    FColumn: Integer;
    function PeekAt(AOffset: Integer): Char;
    procedure Advance;
    procedure SkipIgnored;
    function MakeToken(AKind: TGraphQLTokenKind; const AValue: string;
      ALine, AColumn: Integer): TGraphQLToken;
    function ReadName(ALine, AColumn: Integer): TGraphQLToken;
    function ReadNumber(ALine, AColumn: Integer): TGraphQLToken;
    function ReadString(ALine, AColumn: Integer): TGraphQLToken;
    function ReadBlockString(ALine, AColumn: Integer): TGraphQLToken;
    procedure Fail(const AMsg: string; ALine, AColumn: Integer);
  public
    constructor Create(const ASource: string);
    function Next: TGraphQLToken;
    property Line: Integer read FLine;
    property Column: Integer read FColumn;
  end;

{ Applies the block-string common-indent dedent (spec 2.1.7 BlockStringValue). }
function GraphQLDedentBlock(const ARaw: string): string;

{$ENDIF USE_GRAPHQL}

implementation

{$IFDEF USE_GRAPHQL}

function IsNameStart(C: Char): Boolean;
begin
  Result := ((C >= 'a') and (C <= 'z')) or ((C >= 'A') and (C <= 'Z')) or (C = '_');
end;

function IsNameContinue(C: Char): Boolean;
begin
  Result := IsNameStart(C) or ((C >= '0') and (C <= '9'));
end;

function IsDigit(C: Char): Boolean;
begin
  Result := (C >= '0') and (C <= '9');
end;

function IsHexDigit(C: Char): Boolean;
begin
  Result := IsDigit(C) or ((C >= 'a') and (C <= 'f')) or ((C >= 'A') and (C <= 'F'));
end;

{ ---- block string dedent ---- }

function GraphQLDedentBlock(const ARaw: string): string;
var
  Lines: array of string;
  LStart, I, J: Integer;
  LCommon, LIndent: Integer;
  LChar: Char;
  LFirst, LLast: Integer;
  LBuilt: string;

  procedure PushLine(const S: string);
  begin
    SetLength(Lines, Length(Lines) + 1);
    Lines[High(Lines)] := S;
  end;

  function LeadingWhitespace(const S: string): Integer;
  var K: Integer;
  begin
    Result := 0;
    for K := 1 to Length(S) do
      if (S[K] = ' ') or (S[K] = #9) then
        Inc(Result)
      else
        Break;
  end;

  function IsBlank(const S: string): Boolean;
  begin
    Result := LeadingWhitespace(S) = Length(S);
  end;

begin
  // 1) split ARaw into lines on LF/CRLF/CR
  SetLength(Lines, 0);
  LStart := 1;
  I := 1;
  while I <= Length(ARaw) do
  begin
    LChar := ARaw[I];
    if (LChar = #10) or (LChar = #13) then
    begin
      PushLine(Copy(ARaw, LStart, I - LStart));
      if (LChar = #13) and (I < Length(ARaw)) and (ARaw[I + 1] = #10) then
        Inc(I);
      LStart := I + 1;
    end;
    Inc(I);
  end;
  PushLine(Copy(ARaw, LStart, Length(ARaw) - LStart + 1));

  // 2) common indent of lines after the first (non-blank only)
  LCommon := MaxInt;
  for I := 1 to High(Lines) do
    if not IsBlank(Lines[I]) then
    begin
      LIndent := LeadingWhitespace(Lines[I]);
      if LIndent < LCommon then
        LCommon := LIndent;
    end;
  if LCommon = MaxInt then
    LCommon := 0;

  // 3) remove common indent from lines after the first
  for I := 1 to High(Lines) do
    if Length(Lines[I]) >= LCommon then
      Lines[I] := Copy(Lines[I], LCommon + 1, Length(Lines[I]) - LCommon);

  // 4) drop leading/trailing all-whitespace lines
  LFirst := 0;
  while (LFirst <= High(Lines)) and IsBlank(Lines[LFirst]) do
    Inc(LFirst);
  LLast := High(Lines);
  while (LLast >= LFirst) and IsBlank(Lines[LLast]) do
    Dec(LLast);

  // 5) join with LF
  LBuilt := '';
  for J := LFirst to LLast do
  begin
    if J > LFirst then
      LBuilt := LBuilt + #10;
    LBuilt := LBuilt + Lines[J];
  end;
  Result := LBuilt;
end;

{ ---- TGraphQLLexer ---- }

constructor TGraphQLLexer.Create(const ASource: string);
begin
  inherited Create;
  FSource := ASource;
  FLen := Length(FSource);
  FPos := 1;
  FLine := 1;
  FColumn := 1;
end;

procedure TGraphQLLexer.Fail(const AMsg: string; ALine, AColumn: Integer);
begin
  raise EGraphQLParseException.Create(AMsg, ALine, AColumn, '');
end;

function TGraphQLLexer.PeekAt(AOffset: Integer): Char;
var
  P: Integer;
begin
  P := FPos + AOffset;
  if (P >= 1) and (P <= FLen) then
    Result := FSource[P]
  else
    Result := #0;
end;

procedure TGraphQLLexer.Advance;
begin
  if FPos <= FLen then
  begin
    if FSource[FPos] = #10 then
    begin
      Inc(FLine);
      FColumn := 1;
    end
    else
      Inc(FColumn);
    Inc(FPos);
  end;
end;

procedure TGraphQLLexer.SkipIgnored;
begin
  while FPos <= FLen do
  begin
    case FSource[FPos] of
      #9, #32, #13, #10, ',':
        Advance;
      '#':
        while (FPos <= FLen) and (FSource[FPos] <> #10) and (FSource[FPos] <> #13) do
          Advance;
    else
      Break;
    end;
  end;
end;

function TGraphQLLexer.MakeToken(AKind: TGraphQLTokenKind; const AValue: string;
  ALine, AColumn: Integer): TGraphQLToken;
begin
  Result.Kind := AKind;
  Result.Value := AValue;
  Result.Position.Line := ALine;
  Result.Position.Column := AColumn;
  Result.IsBlock := False;
end;

function TGraphQLLexer.ReadName(ALine, AColumn: Integer): TGraphQLToken;
var
  LStart: Integer;
begin
  LStart := FPos;
  while (FPos <= FLen) and IsNameContinue(FSource[FPos]) do
    Advance;
  Result := MakeToken(gtkName, Copy(FSource, LStart, FPos - LStart), ALine, AColumn);
end;

function TGraphQLLexer.ReadNumber(ALine, AColumn: Integer): TGraphQLToken;
var
  LStart: Integer;
  LIsFloat: Boolean;
begin
  LStart := FPos;
  LIsFloat := False;
  if (FPos <= FLen) and (FSource[FPos] = '-') then
    Advance;
  // integer part
  if (FPos <= FLen) and (FSource[FPos] = '0') then
    Advance
  else
  begin
    if not ((FPos <= FLen) and IsDigit(FSource[FPos])) then
      Fail(Format(GQL_MSG_UNEXPECTED_CHAR, ['(number)', ALine, AColumn]), ALine, AColumn);
    while (FPos <= FLen) and IsDigit(FSource[FPos]) do
      Advance;
  end;
  // fractional part
  if (FPos <= FLen) and (FSource[FPos] = '.') then
  begin
    LIsFloat := True;
    Advance;
    if not ((FPos <= FLen) and IsDigit(FSource[FPos])) then
      Fail('Invalid float: expected digit after "."', FLine, FColumn);
    while (FPos <= FLen) and IsDigit(FSource[FPos]) do
      Advance;
  end;
  // exponent part
  if (FPos <= FLen) and ((FSource[FPos] = 'e') or (FSource[FPos] = 'E')) then
  begin
    LIsFloat := True;
    Advance;
    if (FPos <= FLen) and ((FSource[FPos] = '+') or (FSource[FPos] = '-')) then
      Advance;
    if not ((FPos <= FLen) and IsDigit(FSource[FPos])) then
      Fail('Invalid float: expected digit in exponent', FLine, FColumn);
    while (FPos <= FLen) and IsDigit(FSource[FPos]) do
      Advance;
  end;
  if LIsFloat then
    Result := MakeToken(gtkFloat, Copy(FSource, LStart, FPos - LStart), ALine, AColumn)
  else
    Result := MakeToken(gtkInt, Copy(FSource, LStart, FPos - LStart), ALine, AColumn);
end;

function TGraphQLLexer.ReadString(ALine, AColumn: Integer): TGraphQLToken;
var
  LValue: string;
  LHex: string;
  LCode: Integer;
begin
  Advance; // opening "
  LValue := '';
  while True do
  begin
    if FPos > FLen then
      Fail(Format(GQL_MSG_UNTERMINATED_STR, [ALine, AColumn]), ALine, AColumn);
    case FSource[FPos] of
      '"':
        begin
          Advance;
          Break;
        end;
      #10, #13:
        Fail(Format(GQL_MSG_UNTERMINATED_STR, [ALine, AColumn]), ALine, AColumn);
      '\':
        begin
          Advance;
          if FPos > FLen then
            Fail(Format(GQL_MSG_UNTERMINATED_STR, [ALine, AColumn]), ALine, AColumn);
          case FSource[FPos] of
            '"': LValue := LValue + '"';
            '\': LValue := LValue + '\';
            '/': LValue := LValue + '/';
            'b': LValue := LValue + #8;
            'f': LValue := LValue + #12;
            'n': LValue := LValue + #10;
            'r': LValue := LValue + #13;
            't': LValue := LValue + #9;
            'u':
              begin
                Advance; // consume 'u'
                if (FPos <= FLen) and (FSource[FPos] = '{') then
                begin
                  Advance;
                  LHex := '';
                  while (FPos <= FLen) and IsHexDigit(FSource[FPos]) do
                  begin
                    LHex := LHex + FSource[FPos];
                    Advance;
                  end;
                  if (FPos > FLen) or (FSource[FPos] <> '}') then
                    Fail('Invalid \u{...} escape', FLine, FColumn);
                  // '}' consumed below by the trailing Advance
                end
                else
                begin
                  LHex := '';
                  while (Length(LHex) < 4) and (FPos <= FLen) and IsHexDigit(FSource[FPos]) do
                  begin
                    LHex := LHex + FSource[FPos];
                    Advance;
                  end;
                  if Length(LHex) <> 4 then
                    Fail('Invalid \uXXXX escape', FLine, FColumn);
                  // last hex digit consumed; step back one so trailing Advance lands right
                  Dec(FPos);
                  Dec(FColumn);
                end;
                LCode := StrToInt('$' + LHex);
                if LCode <= $FFFF then
                  LValue := LValue + Char(LCode)
                else
                  LValue := LValue + Char($FFFF); // astral: best-effort placeholder
              end;
          else
            Fail('Invalid escape sequence "\' + FSource[FPos] + '"', FLine, FColumn);
          end;
          Advance;
        end;
    else
      begin
        LValue := LValue + FSource[FPos];
        Advance;
      end;
    end;
  end;
  Result := MakeToken(gtkString, LValue, ALine, AColumn);
  Result.IsBlock := False;
end;

function TGraphQLLexer.ReadBlockString(ALine, AColumn: Integer): TGraphQLToken;
var
  LRaw: string;
begin
  // consume opening """
  Advance; Advance; Advance;
  LRaw := '';
  while True do
  begin
    if FPos > FLen then
      Fail(Format(GQL_MSG_UNTERMINATED_STR, [ALine, AColumn]), ALine, AColumn);
    // closing """
    if (FSource[FPos] = '"') and (PeekAt(1) = '"') and (PeekAt(2) = '"') then
    begin
      Advance; Advance; Advance;
      Break;
    end;
    // escaped \"""
    if (FSource[FPos] = '\') and (PeekAt(1) = '"') and (PeekAt(2) = '"')
       and (PeekAt(3) = '"') then
    begin
      LRaw := LRaw + '"""';
      Advance; Advance; Advance; Advance;
      Continue;
    end;
    LRaw := LRaw + FSource[FPos];
    Advance;
  end;
  Result := MakeToken(gtkString, GraphQLDedentBlock(LRaw), ALine, AColumn);
  Result.IsBlock := True;
end;

function TGraphQLLexer.Next: TGraphQLToken;
var
  LLine, LCol: Integer;
  C: Char;
begin
  SkipIgnored;
  LLine := FLine;
  LCol := FColumn;
  if FPos > FLen then
  begin
    Result := MakeToken(gtkEOF, '', LLine, LCol);
    Exit;
  end;
  C := FSource[FPos];
  case C of
    '!': begin Advance; Result := MakeToken(gtkBang, '!', LLine, LCol); end;
    '$': begin Advance; Result := MakeToken(gtkDollar, '$', LLine, LCol); end;
    '&': begin Advance; Result := MakeToken(gtkAmp, '&', LLine, LCol); end;
    '(': begin Advance; Result := MakeToken(gtkParenL, '(', LLine, LCol); end;
    ')': begin Advance; Result := MakeToken(gtkParenR, ')', LLine, LCol); end;
    ':': begin Advance; Result := MakeToken(gtkColon, ':', LLine, LCol); end;
    '=': begin Advance; Result := MakeToken(gtkEquals, '=', LLine, LCol); end;
    '@': begin Advance; Result := MakeToken(gtkAt, '@', LLine, LCol); end;
    '[': begin Advance; Result := MakeToken(gtkBracketL, '[', LLine, LCol); end;
    ']': begin Advance; Result := MakeToken(gtkBracketR, ']', LLine, LCol); end;
    '{': begin Advance; Result := MakeToken(gtkBraceL, '{', LLine, LCol); end;
    '}': begin Advance; Result := MakeToken(gtkBraceR, '}', LLine, LCol); end;
    '|': begin Advance; Result := MakeToken(gtkPipe, '|', LLine, LCol); end;
    '.':
      begin
        if (PeekAt(1) = '.') and (PeekAt(2) = '.') then
        begin
          Advance; Advance; Advance;
          Result := MakeToken(gtkSpread, '...', LLine, LCol);
        end
        else
          Fail(Format(GQL_MSG_UNEXPECTED_CHAR, ['.', LLine, LCol]), LLine, LCol);
      end;
    '"':
      begin
        if (PeekAt(1) = '"') and (PeekAt(2) = '"') then
          Result := ReadBlockString(LLine, LCol)
        else
          Result := ReadString(LLine, LCol);
      end;
    '-', '0'..'9':
      Result := ReadNumber(LLine, LCol);
    'a'..'z', 'A'..'Z', '_':
      Result := ReadName(LLine, LCol);
  else
    Fail(Format(GQL_MSG_UNEXPECTED_CHAR, [C, LLine, LCol]), LLine, LCol);
  end;
end;

{$ENDIF USE_GRAPHQL}

end.
