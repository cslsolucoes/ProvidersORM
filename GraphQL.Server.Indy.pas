{ =============================================================================
  GraphQL.Server.Indy - Indy TIdHTTPServer adapter (FASE 13, wave 13A.6)

  A thin adapter mapping Indy's TIdHTTPRequestInfo/TIdHTTPResponseInfo to the
  transport-agnostic IGraphQLHttpRequest/IGraphQLHttpResponse, plus a small
  TGraphQLIndyServer that hosts a schema over HTTP via TGraphQLHttpHandler.
  Cross-compiler (Indy is the "single API" rule of the cerebrum).

  NOTE (concurrency): TIdHTTPServer dispatches on worker threads. The handler and
  schema are read-only/stateless per request (a fresh executor per request), but
  ORM resolvers hold one IConnection - for concurrent load use a pooled connection
  (PoolConnections) or a connection-per-request resolver. Documented backlog.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           12/08/2026

  Changelog (file):
  - 1.0.0 (12/08/2026): FASE 13 wave 13A.6 - request/response adapters +
    TGraphQLIndyServer (Start/Stop, GET+POST+other -> handler).
  ============================================================================= }

unit GraphQL.Server.Indy;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../../ORM.Defines.inc}

{$IFDEF USE_GRAPHQL}

uses
{$IF DEFINED(FPC)}
  SysUtils,
  Classes,
{$ELSE}
  System.SysUtils,
  System.Classes,
{$ENDIF}
  IdContext,
  IdCustomHTTPServer,
  IdHTTPServer,
  GraphQL.Schema,
  GraphQL.Server.Http.Interfaces,
  GraphQL.Server.Http.Handler;

type
  TGraphQLIndyRequest = class(TInterfacedObject, IGraphQLHttpRequest)
  private
    FReq: TIdHTTPRequestInfo;
    FBody: string;
  public
    constructor Create(AReq: TIdHTTPRequestInfo);
    function Method: string;
    function ContentType: string;
    function Body: string;
    function QueryParam(const AName: string): string;
    function Header(const AName: string): string;
  end;

  TGraphQLIndyResponse = class(TInterfacedObject, IGraphQLHttpResponse)
  private
    FResp: TIdHTTPResponseInfo;
  public
    constructor Create(AResp: TIdHTTPResponseInfo);
    procedure SetStatus(ACode: Integer);
    procedure SetHeader(const AName, AValue: string);
    procedure SetBody(const AContent: string);
  end;

  TGraphQLIndyServer = class
  private
    FServer: TIdHTTPServer;
    FHandler: TGraphQLHttpHandler;
    procedure DoCommand(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo);
  public
    constructor Create(const ASchema: IGraphQLSchema; APort: Integer;
      AValidate: Boolean = True);
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    function Active: Boolean;
  end;

{$ENDIF}

implementation

{$IFDEF USE_GRAPHQL}

{ TGraphQLIndyRequest }

constructor TGraphQLIndyRequest.Create(AReq: TIdHTTPRequestInfo);
var
  LSs: TStringStream;
begin
  inherited Create;
  FReq := AReq;
  FBody := '';
  if Assigned(AReq.PostStream) then
  begin
    LSs := TStringStream.Create('');
    try
      AReq.PostStream.Position := 0;
      LSs.CopyFrom(AReq.PostStream, 0);
      FBody := LSs.DataString;
    finally
      LSs.Free;
    end;
  end;
end;

function TGraphQLIndyRequest.Method: string;
begin
  Result := FReq.Command;
end;

function TGraphQLIndyRequest.ContentType: string;
begin
  Result := FReq.ContentType;
end;

function TGraphQLIndyRequest.Body: string;
begin
  Result := FBody;
end;

function TGraphQLIndyRequest.QueryParam(const AName: string): string;
begin
  Result := FReq.Params.Values[AName];
end;

function TGraphQLIndyRequest.Header(const AName: string): string;
begin
  Result := FReq.RawHeaders.Values[AName];
end;

{ TGraphQLIndyResponse }

constructor TGraphQLIndyResponse.Create(AResp: TIdHTTPResponseInfo);
begin
  inherited Create;
  FResp := AResp;
end;

procedure TGraphQLIndyResponse.SetStatus(ACode: Integer);
begin
  FResp.ResponseNo := ACode;
end;

procedure TGraphQLIndyResponse.SetHeader(const AName, AValue: string);
begin
  if SameText(AName, 'Content-Type') then
    FResp.ContentType := AValue
  else
    FResp.CustomHeaders.Values[AName] := AValue;
end;

procedure TGraphQLIndyResponse.SetBody(const AContent: string);
begin
  FResp.ContentText := AContent;
end;

{ TGraphQLIndyServer }

constructor TGraphQLIndyServer.Create(const ASchema: IGraphQLSchema;
  APort: Integer; AValidate: Boolean);
begin
  inherited Create;
  FHandler := TGraphQLHttpHandler.Create(ASchema, AValidate);
  FServer := TIdHTTPServer.Create(nil);
  FServer.DefaultPort := APort;
  FServer.OnCommandGet := DoCommand;
  FServer.OnCommandOther := DoCommand;
end;

destructor TGraphQLIndyServer.Destroy;
begin
  Stop;
  FServer.Free;
  FHandler.Free;
  inherited Destroy;
end;

procedure TGraphQLIndyServer.DoCommand(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  LReq: IGraphQLHttpRequest;
  LResp: IGraphQLHttpResponse;
begin
  LReq := TGraphQLIndyRequest.Create(ARequestInfo);
  LResp := TGraphQLIndyResponse.Create(AResponseInfo);
  FHandler.Handle(LReq, LResp);
end;

procedure TGraphQLIndyServer.Start;
begin
  if not FServer.Active then
    FServer.Active := True;
end;

procedure TGraphQLIndyServer.Stop;
begin
  if FServer.Active then
    FServer.Active := False;
end;

function TGraphQLIndyServer.Active: Boolean;
begin
  Result := FServer.Active;
end;

{$ENDIF}

end.
