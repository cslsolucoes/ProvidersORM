{ =============================================================================
  GraphQL.Server.Http.Handler - the GraphQL-over-HTTP request pipeline
  (FASE 13, wave 13A.6; GraphQL-over-HTTP conventions)

  Reads a GraphQL request from an IGraphQLHttpRequest, runs parse -> (validate) ->
  execute against the schema, and writes the JSON response to IGraphQLHttpResponse.
  Framework-agnostic (an adapter supplies the two interfaces).

  Routing:
    - POST application/json      -> body is data + variables + operationName (JSON)
    - POST application/graphql   -> body IS the query document
    - GET                        -> ?query=...&variables=...&operationName=...
    - anything else              -> 405 + Allow: GET, POST
  Response is always application/json; charset=UTF-8. Parse/validation problems
  come back as an errors array (200 for execution errors; 400 for a missing query;
  405 for a bad method).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           12/08/2026

  Changelog (file):
  - 1.0.0 (12/08/2026): FASE 13 wave 13A.6 - TGraphQLHttpHandler (method routing,
    JSON/graphql/GET request forms, validate+execute, errors as JSON).
  ============================================================================= }

unit GraphQL.Server.Http.Handler;

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
  GraphQL.Core.Ast,
  GraphQL.Core.Parser,
  GraphQL.Exceptions,
  GraphQL.Schema,
  GraphQL.Value,
  GraphQL.Executor,
  GraphQL.Validator,
  GraphQL.Server.Http.Interfaces;

type
  TGraphQLHttpHandler = class
  private
    FSchema: IGraphQLSchema;
    FValidate: Boolean;
  public
    constructor Create(const ASchema: IGraphQLSchema; AValidate: Boolean = True);
    { Full HTTP round-trip: reads the request, writes status/headers/body. }
    procedure Handle(const ARequest: IGraphQLHttpRequest;
      const AResponse: IGraphQLHttpResponse);
    { Parse -> (validate) -> execute a single query; returns the JSON response. }
    function ExecuteQuery(const AQuery: string; AVariables: TGraphQLValue;
      const AOperationName: string): string;
    property Validate: Boolean read FValidate write FValidate;
  end;

{$ENDIF}

implementation

{$IFDEF USE_GRAPHQL}

const
  CT_JSON = 'application/json; charset=UTF-8';

constructor TGraphQLHttpHandler.Create(const ASchema: IGraphQLSchema; AValidate: Boolean);
begin
  inherited Create;
  FSchema := ASchema;
  FValidate := AValidate;
end;

function ValidationErrorsToJSON(const AErrors: TGraphQLValidationErrorArray): string;
var
  I: Integer;
begin
  Result := '{"errors":[';
  for I := 0 to High(AErrors) do
  begin
    if I > 0 then
      Result := Result + ',';
    Result := Result + '{"message":' + GraphQLJSONQuote(AErrors[I].Message);
    if AErrors[I].Line > 0 then
      Result := Result + ',"locations":[{"line":' + IntToStr(AErrors[I].Line) +
        ',"column":' + IntToStr(AErrors[I].Column) + '}]';
    Result := Result + '}';
  end;
  Result := Result + ']}';
end;

function TGraphQLHttpHandler.ExecuteQuery(const AQuery: string;
  AVariables: TGraphQLValue; const AOperationName: string): string;
var
  LParser: TGraphQLParser;
  LDoc: TGraphQLDocumentNode;
  LExec: TGraphQLExecutor;
  LRes: TGraphQLExecutionResult;
  LVal: TGraphQLValidator;
  LErrs: TGraphQLValidationErrorArray;
begin
  LDoc := nil;
  try
    LParser := TGraphQLParser.Create(AQuery);
    try
      LDoc := LParser.Parse;
    finally
      LParser.Free;
    end;
  except
    on E: Exception do
      Exit('{"errors":[{"message":' + GraphQLJSONQuote(E.Message) + '}]}');
  end;

  try
    if FValidate then
    begin
      LVal := TGraphQLValidator.Create(FSchema);
      try
        LErrs := LVal.Validate(LDoc);
      finally
        LVal.Free;
      end;
      if Length(LErrs) > 0 then
        Exit(ValidationErrorsToJSON(LErrs));
    end;

    LExec := TGraphQLExecutor.Create(FSchema);
    LRes := LExec.Execute(LDoc, AVariables, AOperationName);
    try
      Result := LRes.ToJSON;
    finally
      LRes.Free;
      LExec.Free;
    end;
  finally
    LDoc.Free;
  end;
end;

procedure TGraphQLHttpHandler.Handle(const ARequest: IGraphQLHttpRequest;
  const AResponse: IGraphQLHttpResponse);
var
  LMethod, LCt, LQuery, LOpName, LVarStr, LJson: string;
  LArena: TGraphQLValueArena;
  LVars, LBody, LV: TGraphQLValue;
begin
  LMethod := UpperCase(Trim(ARequest.Method));
  LArena := TGraphQLValueArena.Create;
  try
    LQuery := '';
    LOpName := '';
    LVars := nil;

    if LMethod = 'POST' then
    begin
      LCt := LowerCase(ARequest.ContentType);
      if Pos('application/graphql', LCt) > 0 then
        LQuery := ARequest.Body
      else
      begin
        LBody := GraphQLParseJSON(ARequest.Body, LArena);
        if (LBody <> nil) and (LBody.Kind = gvkObject) then
        begin
          LV := LBody.GetField('query');
          if (LV <> nil) and (LV.Kind = gvkScalar) then
            LQuery := VarToStr(LV.Scalar);
          LV := LBody.GetField('operationName');
          if (LV <> nil) and (LV.Kind = gvkScalar) then
            LOpName := VarToStr(LV.Scalar);
          LVars := LBody.GetField('variables'); // object or nil/null
        end;
      end;
    end
    else if LMethod = 'GET' then
    begin
      LQuery := ARequest.QueryParam('query');
      LOpName := ARequest.QueryParam('operationName');
      LVarStr := ARequest.QueryParam('variables');
      if LVarStr <> '' then
        LVars := GraphQLParseJSON(LVarStr, LArena);
    end
    else
    begin
      AResponse.SetStatus(405);
      AResponse.SetHeader('Allow', 'GET, POST');
      AResponse.SetHeader('Content-Type', CT_JSON);
      AResponse.SetBody('{"errors":[{"message":"Method not allowed"}]}');
      Exit;
    end;

    if Trim(LQuery) = '' then
    begin
      AResponse.SetStatus(400);
      AResponse.SetHeader('Content-Type', CT_JSON);
      AResponse.SetBody('{"errors":[{"message":"Missing query"}]}');
      Exit;
    end;

    LJson := ExecuteQuery(LQuery, LVars, LOpName);
    AResponse.SetStatus(200);
    AResponse.SetHeader('Content-Type', CT_JSON);
    AResponse.SetBody(LJson);
  finally
    LArena.Free;
  end;
end;

{$ENDIF}

end.
