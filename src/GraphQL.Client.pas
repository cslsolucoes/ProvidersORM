{ =============================================================================
  GraphQL.Client - HTTP transport for a GraphQL client (FASE 13, wave 13B.2)

  IGraphQLClient (fluent): Endpoint/Header/BearerToken/BasicAuth/Timeout +
  Execute(query|document,variables,operationName) -> IGraphQLResponse. POST
  application/json body (query + variables + operationName) via Indy TIdHTTP
  ("single API" rule). The response body is parsed with GraphQLParseJSON into a
  TGraphQLValue tree; IGraphQLResponse exposes Success/HasErrors/StatusCode/
  Errors/Data/DataAt(path)/RawJSON. Variables are the query's TGraphQLValue
  (serialized with GraphQLValueToJSON) - reuse of the 13A value tree, not
  System.JSON/fpjson. Cross-compiler.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           12/08/2026

  Changelog (file):
  - 1.0.0 (12/08/2026): FASE 13 wave 13B.2 - IGraphQLClient (Indy transport) +
    IGraphQLResponse (data + typed errors + DataAt navigation).
  ============================================================================= }

unit GraphQL.Client;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IF DEFINED(USE_GRAPHQL) AND DEFINED(USE_GRAPHQL_CLIENT)}

uses
{$IF DEFINED(FPC)}
  SysUtils,
  Classes,
  Variants,
{$ELSE}
  System.SysUtils,
  System.Classes,
  System.Variants,
{$ENDIF}
  IdHTTP,
  GraphQL.Value,
  GraphQL.Exceptions,
  GraphQL.Client.Query;

type
  TGraphQLResponseError = record
    Message: string;
    Line: Integer;
    Column: Integer;
    Path: string;
    Code: string; // extensions.code
  end;
  TGraphQLResponseErrorArray = array of TGraphQLResponseError;

  IGraphQLResponse = interface
    ['{3C5D7F20-9A14-4E62-8B7C-1D2E3F405162}']
    function Success: Boolean;                    // HTTP 200 and no errors
    function HasErrors: Boolean;
    function StatusCode: Integer;
    function Errors: TGraphQLResponseErrorArray;
    function Data: TGraphQLValue;                 // the "data" object (may be nil)
    function DataAt(const APath: string): TGraphQLValue; // e.g. 'user.name'
    function RawJSON: string;
  end;

  IGraphQLClient = interface
    ['{3C5D7F20-9A14-4E62-8B7C-1D2E3F405163}']
    function Endpoint(const AUrl: string): IGraphQLClient;
    function Header(const AName, AValue: string): IGraphQLClient;
    function BearerToken(const AToken: string): IGraphQLClient;
    function BasicAuth(const AUser, APass: string): IGraphQLClient;
    function Timeout(const AMs: Integer): IGraphQLClient;
    function Execute(AQuery: IGraphQLQuery): IGraphQLResponse; overload;
    function Execute(const ADocument: string; AVariables: TGraphQLValue = nil;
      const AOperationName: string = ''): IGraphQLResponse; overload;
  end;

function NewGraphQLClient: IGraphQLClient;

{$ENDIF}

implementation

{$IF DEFINED(USE_GRAPHQL) AND DEFINED(USE_GRAPHQL_CLIENT)}

type
  TGraphQLResponse = class(TInterfacedObject, IGraphQLResponse)
  private
    FArena: TGraphQLValueArena;
    FRaw: string;
    FStatus: Integer;
    FData: TGraphQLValue;
    FErrors: TGraphQLResponseErrorArray;
    procedure ParseErrors(ARoot: TGraphQLValue);
  public
    constructor Create(const ARaw: string; AStatus: Integer);
    destructor Destroy; override;
    function Success: Boolean;
    function HasErrors: Boolean;
    function StatusCode: Integer;
    function Errors: TGraphQLResponseErrorArray;
    function Data: TGraphQLValue;
    function DataAt(const APath: string): TGraphQLValue;
    function RawJSON: string;
  end;

  TGraphQLClient = class(TInterfacedObject, IGraphQLClient)
  private
    FEndpoint: string;
    FHeaders: TStringList;
    FBearer: string;
    FBasicUser: string;
    FBasicPass: string;
    FTimeout: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    function Endpoint(const AUrl: string): IGraphQLClient;
    function Header(const AName, AValue: string): IGraphQLClient;
    function BearerToken(const AToken: string): IGraphQLClient;
    function BasicAuth(const AUser, APass: string): IGraphQLClient;
    function Timeout(const AMs: Integer): IGraphQLClient;
    function Execute(AQuery: IGraphQLQuery): IGraphQLResponse; overload;
    function Execute(const ADocument: string; AVariables: TGraphQLValue = nil;
      const AOperationName: string = ''): IGraphQLResponse; overload;
  end;

function ScalarStr(AValue: TGraphQLValue): string;
begin
  if (AValue <> nil) and (AValue.Kind = gvkScalar) then
    Result := VarToStr(AValue.Scalar)
  else
    Result := '';
end;

function ScalarInt(AValue: TGraphQLValue): Integer;
begin
  if (AValue <> nil) and (AValue.Kind = gvkScalar) then
    Result := StrToIntDef(VarToStr(AValue.Scalar), 0)
  else
    Result := 0;
end;

{ TGraphQLResponse }

constructor TGraphQLResponse.Create(const ARaw: string; AStatus: Integer);
var
  LRoot: TGraphQLValue;
begin
  inherited Create;
  FArena := TGraphQLValueArena.Create;
  FRaw := ARaw;
  FStatus := AStatus;
  LRoot := GraphQLParseJSON(ARaw, FArena);
  if (LRoot <> nil) and (LRoot.Kind = gvkObject) then
  begin
    FData := LRoot.GetField('data');
    ParseErrors(LRoot);
  end
  else
    FData := nil;
end;

destructor TGraphQLResponse.Destroy;
begin
  FArena.Free;
  inherited Destroy;
end;

procedure TGraphQLResponse.ParseErrors(ARoot: TGraphQLValue);
var
  LErrs, LItem, LLoc, LPath, LExt: TGraphQLValue;
  I, J: Integer;
begin
  LErrs := ARoot.GetField('errors');
  if (LErrs = nil) or (LErrs.Kind <> gvkList) then
    Exit;
  SetLength(FErrors, Length(LErrs.Items));
  for I := 0 to High(LErrs.Items) do
  begin
    LItem := LErrs.Items[I];
    FErrors[I].Message := '';
    FErrors[I].Line := 0;
    FErrors[I].Column := 0;
    FErrors[I].Path := '';
    FErrors[I].Code := '';
    if (LItem = nil) or (LItem.Kind <> gvkObject) then
      Continue;
    FErrors[I].Message := ScalarStr(LItem.GetField('message'));
    LLoc := LItem.GetField('locations');
    if (LLoc <> nil) and (LLoc.Kind = gvkList) and (Length(LLoc.Items) > 0) then
    begin
      FErrors[I].Line := ScalarInt(LLoc.Items[0].GetField('line'));
      FErrors[I].Column := ScalarInt(LLoc.Items[0].GetField('column'));
    end;
    LPath := LItem.GetField('path');
    if LPath <> nil then
    begin
      if LPath.Kind = gvkScalar then
        FErrors[I].Path := VarToStr(LPath.Scalar)
      else if LPath.Kind = gvkList then
        for J := 0 to High(LPath.Items) do
        begin
          if J > 0 then
            FErrors[I].Path := FErrors[I].Path + '/';
          FErrors[I].Path := FErrors[I].Path + ScalarStr(LPath.Items[J]);
        end;
    end;
    LExt := LItem.GetField('extensions');
    if (LExt <> nil) and (LExt.Kind = gvkObject) then
      FErrors[I].Code := ScalarStr(LExt.GetField('code'));
  end;
end;

function TGraphQLResponse.Success: Boolean;
begin
  Result := (FStatus = 200) and (Length(FErrors) = 0);
end;

function TGraphQLResponse.HasErrors: Boolean;
begin
  Result := Length(FErrors) > 0;
end;

function TGraphQLResponse.StatusCode: Integer;
begin
  Result := FStatus;
end;

function TGraphQLResponse.Errors: TGraphQLResponseErrorArray;
begin
  Result := FErrors;
end;

function TGraphQLResponse.Data: TGraphQLValue;
begin
  Result := FData;
end;

function TGraphQLResponse.DataAt(const APath: string): TGraphQLValue;
var
  LCur: TGraphQLValue;
  LRest, LSeg: string;
  LDot: Integer;
begin
  LCur := FData;
  LRest := APath;
  while (LRest <> '') and (LCur <> nil) do
  begin
    LDot := Pos('.', LRest);
    if LDot > 0 then
    begin
      LSeg := Copy(LRest, 1, LDot - 1);
      LRest := Copy(LRest, LDot + 1, Length(LRest) - LDot);
    end
    else
    begin
      LSeg := LRest;
      LRest := '';
    end;
    if LCur.Kind = gvkObject then
      LCur := LCur.GetField(LSeg)
    else
      LCur := nil;
  end;
  Result := LCur;
end;

function TGraphQLResponse.RawJSON: string;
begin
  Result := FRaw;
end;

{ TGraphQLClient }

constructor TGraphQLClient.Create;
begin
  inherited Create;
  FHeaders := TStringList.Create;
  FTimeout := 0;
end;

destructor TGraphQLClient.Destroy;
begin
  FHeaders.Free;
  inherited Destroy;
end;

function TGraphQLClient.Endpoint(const AUrl: string): IGraphQLClient;
begin
  FEndpoint := AUrl;
  Result := Self;
end;

function TGraphQLClient.Header(const AName, AValue: string): IGraphQLClient;
begin
  FHeaders.Values[AName] := AValue;
  Result := Self;
end;

function TGraphQLClient.BearerToken(const AToken: string): IGraphQLClient;
begin
  FBearer := AToken;
  Result := Self;
end;

function TGraphQLClient.BasicAuth(const AUser, APass: string): IGraphQLClient;
begin
  FBasicUser := AUser;
  FBasicPass := APass;
  Result := Self;
end;

function TGraphQLClient.Timeout(const AMs: Integer): IGraphQLClient;
begin
  FTimeout := AMs;
  Result := Self;
end;

function BuildBody(const ADoc: string; AVariables: TGraphQLValue;
  const AOperationName: string): string;
begin
  Result := '{"query":' + GraphQLJSONQuote(ADoc);
  if (AVariables <> nil) and (AVariables.Kind = gvkObject) and
     (Length(AVariables.Pairs) > 0) then
    Result := Result + ',"variables":' + GraphQLValueToJSON(AVariables);
  if AOperationName <> '' then
    Result := Result + ',"operationName":' + GraphQLJSONQuote(AOperationName);
  Result := Result + '}';
end;

function TGraphQLClient.Execute(const ADocument: string; AVariables: TGraphQLValue;
  const AOperationName: string): IGraphQLResponse;
var
  LHttp: TIdHTTP;
  LBody, LResp: string;
  LSs: TStringStream;
  LCode, I: Integer;
begin
  LBody := BuildBody(ADocument, AVariables, AOperationName);
  LHttp := TIdHTTP.Create(nil);
  try
    LHttp.HTTPOptions := LHttp.HTTPOptions + [hoNoProtocolErrorException];
    LHttp.Request.ContentType := 'application/json';
    if FTimeout > 0 then
    begin
      LHttp.ConnectTimeout := FTimeout;
      LHttp.ReadTimeout := FTimeout;
    end;
    if FBearer <> '' then
      LHttp.Request.CustomHeaders.Values['Authorization'] := 'Bearer ' + FBearer;
    if FBasicUser <> '' then
    begin
      LHttp.Request.BasicAuthentication := True;
      LHttp.Request.Username := FBasicUser;
      LHttp.Request.Password := FBasicPass;
    end;
    for I := 0 to FHeaders.Count - 1 do
      LHttp.Request.CustomHeaders.Values[FHeaders.Names[I]] :=
        FHeaders.ValueFromIndex[I];
    LSs := TStringStream.Create(LBody);
    try
      try
        LResp := LHttp.Post(FEndpoint, LSs);
      except
        on E: Exception do
          raise EGraphQLClientException.Create('GraphQL transport failed: ' +
            E.Message, LHttp.ResponseCode);
      end;
      LCode := LHttp.ResponseCode;
    finally
      LSs.Free;
    end;
    Result := TGraphQLResponse.Create(LResp, LCode);
  finally
    LHttp.Free;
  end;
end;

function TGraphQLClient.Execute(AQuery: IGraphQLQuery): IGraphQLResponse;
begin
  Result := Execute(AQuery.ToGraphQL, AQuery.Variables, AQuery.OperationName);
end;

function NewGraphQLClient: IGraphQLClient;
begin
  Result := TGraphQLClient.Create;
end;

{$ENDIF}

end.
