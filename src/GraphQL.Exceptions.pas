{ =============================================================================
  GraphQL.Exceptions - exception hierarchy of the GraphQL module (FASE 13, 13A.0)

  EGraphQL* hierarchy, all inheriting EExceptionBase (Exceptions.Base) so the
  ErrorCode (range MM=97) lives at the root, like every other module. Placement:
  in-module (owner 11/08 - the concluded Exceptions/ folder stays READ-ONLY; we
  only CONSUME EExceptionBase, never edit it). The canonical range table in
  Exceptions.Base is NOT touched here - MM=97 (GraphQL) is reserved and will be
  registered there at merge/F10 with explicit owner authorization.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           11/08/2026

  Changelog (file):
  - 1.0.0 (11/08/2026): FASE 13 wave 13A.0 - EGraphQLException base + parse/
    validation/execution/schema subclasses (range 97XXXX). EGraphQLParseException
    carries Line/Column/Token (same pattern as EConnectionException.Operation).
  ============================================================================= }

unit GraphQL.Exceptions;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../ORM.Defines.inc}

{$IFDEF USE_GRAPHQL}

uses
{$IF DEFINED(FPC)}
  SysUtils,
{$ELSE}
  System.SysUtils,
{$ENDIF}
  Exceptions.Base;

const
  { GraphQL error range (MM=97). ERR_GRAPHQL_BASE defined HERE (not re-exported
    from Exceptions.Base, which is READ-ONLY and does not yet list this range). }
  ERR_GRAPHQL_BASE          = 970000;
  ERR_GRAPHQL_PARSE         = ERR_GRAPHQL_BASE + 1;  // 970001
  ERR_GRAPHQL_VALIDATION    = ERR_GRAPHQL_BASE + 2;  // 970002
  ERR_GRAPHQL_EXECUTION     = ERR_GRAPHQL_BASE + 3;  // 970003
  ERR_GRAPHQL_SCHEMA        = ERR_GRAPHQL_BASE + 4;  // 970004
  ERR_GRAPHQL_COERCION      = ERR_GRAPHQL_BASE + 5;  // 970005
  ERR_GRAPHQL_INTROSPECTION = ERR_GRAPHQL_BASE + 6;  // 970006
  ERR_GRAPHQL_TRANSPORT     = ERR_GRAPHQL_BASE + 7;  // 970007
  ERR_GRAPHQL_CLIENT        = ERR_GRAPHQL_BASE + 8;  // 970008

type
  { Root of the GraphQL module exceptions. Inherits ErrorCode from
    EExceptionBase (Exceptions.Base - concluded module, READ-ONLY: consumed
    only). Range MM=97. }
  EGraphQLException = class(EExceptionBase);

  { Lexer/parser error carrying the source position and offending token. }
  EGraphQLParseException = class(EGraphQLException)
  private
    FLine: Integer;
    FColumn: Integer;
    FToken: string;
  public
    constructor Create(const AMessage: string); overload;
    constructor Create(const AMessage: string; const ALine, AColumn: Integer;
      const AToken: string = ''); overload;
    property Line: Integer read FLine;
    property Column: Integer read FColumn;
    property Token: string read FToken;
  end;

  { Document/schema validation error (spec Section 5). }
  EGraphQLValidationException = class(EGraphQLException);

  { Field resolution / execution error (spec Section 6). }
  EGraphQLExecutionException = class(EGraphQLException);

  { Schema build/definition error (spec Section 3). }
  EGraphQLSchemaException = class(EGraphQLException);

  { Client transport error (network/HTTP failure) - carries the HTTP status code
    (0 = no HTTP response, e.g. connection failure). Wave 13B.2. }
  EGraphQLClientException = class(EGraphQLException)
  private
    FStatusCode: Integer;
  public
    constructor Create(const AMessage: string; const AStatusCode: Integer = 0);
    property StatusCode: Integer read FStatusCode;
  end;

{$ENDIF USE_GRAPHQL}

implementation

{$IFDEF USE_GRAPHQL}

{ EGraphQLParseException }

constructor EGraphQLParseException.Create(const AMessage: string);
begin
  inherited Create(AMessage, ERR_GRAPHQL_PARSE);
end;

constructor EGraphQLParseException.Create(const AMessage: string;
  const ALine, AColumn: Integer; const AToken: string);
begin
  inherited Create(AMessage, ERR_GRAPHQL_PARSE);
  FLine := ALine;
  FColumn := AColumn;
  FToken := AToken;
end;

{ EGraphQLClientException }

constructor EGraphQLClientException.Create(const AMessage: string;
  const AStatusCode: Integer);
begin
  inherited Create(AMessage, ERR_GRAPHQL_CLIENT);
  FStatusCode := AStatusCode;
end;

{$ENDIF USE_GRAPHQL}

end.
