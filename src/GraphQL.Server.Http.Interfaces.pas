{ =============================================================================
  GraphQL.Server.Http.Interfaces - transport-agnostic HTTP boundary
  (FASE 13, wave 13A.6)

  Two minimal interfaces isolate the GraphQL engine from any HTTP framework
  (decision 1): the handler only ever sees IGraphQLHttpRequest/IGraphQLHttpResponse;
  a thin adapter maps a concrete server (Indy TIdHTTPServer, Horse, WebBroker, ...)
  to them. Cross-compiler; zero framework dependency here.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           12/08/2026

  Changelog (file):
  - 1.0.0 (12/08/2026): FASE 13 wave 13A.6 - IGraphQLHttpRequest / IGraphQLHttpResponse.
  ============================================================================= }

unit GraphQL.Server.Http.Interfaces;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../../ORM.Defines.inc}

{$IFDEF USE_GRAPHQL}

type
  { What the handler reads from an incoming request. }
  IGraphQLHttpRequest = interface
    ['{9C1E2A44-6B0D-4E71-8F2A-7D3C5E1B9A03}']
    function Method: string;                            // 'GET' / 'POST' / ...
    function ContentType: string;                       // e.g. 'application/json'
    function Body: string;                              // raw request body (POST)
    function QueryParam(const AName: string): string;   // URL query string (GET)
    function Header(const AName: string): string;       // request header value
  end;

  { What the handler writes to the outgoing response. }
  IGraphQLHttpResponse = interface
    ['{9C1E2A44-6B0D-4E71-8F2A-7D3C5E1B9A04}']
    procedure SetStatus(ACode: Integer);
    procedure SetHeader(const AName, AValue: string);
    procedure SetBody(const AContent: string);
  end;

{$ENDIF}

implementation

end.
