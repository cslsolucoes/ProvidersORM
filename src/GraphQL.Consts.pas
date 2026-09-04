{ =============================================================================
  GraphQL.Consts - shared CONSTANTS of the GraphQL module (FASE 13, wave 13A.0)

  Built-in scalar names, directive names, introspection meta-field names,
  operation keywords and error-message templates. Placement: in-module (owner
  11/08 - Commons/ READ-ONLY), the equivalent of Commons.GraphQL.Consts. Gated
  by USE_GRAPHQL.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           11/08/2026

  Changelog (file):
  - 1.0.0 (11/08/2026): FASE 13 wave 13A.0 - built-in scalars (Int/Float/String/
    Boolean/ID), built-in directives (include/skip/deprecated), introspection
    names (__schema/__type/__typename), operation keywords and parser/lexer
    error-message templates. Names per the local spec Sections 2/3/4.
  ============================================================================= }

unit GraphQL.Consts;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_GRAPHQL}

const
  { Built-in scalar type names (spec Section 3.5). }
  GQL_SCALAR_INT     = 'Int';
  GQL_SCALAR_FLOAT   = 'Float';
  GQL_SCALAR_STRING  = 'String';
  GQL_SCALAR_BOOLEAN = 'Boolean';
  GQL_SCALAR_ID      = 'ID';

  { Built-in directive names (spec Section 3.13). }
  GQL_DIR_INCLUDE    = 'include';
  GQL_DIR_SKIP       = 'skip';
  GQL_DIR_DEPRECATED = 'deprecated';

  { Introspection meta-field names (spec Section 4). }
  GQL_INTROSPECT_SCHEMA   = '__schema';
  GQL_INTROSPECT_TYPE     = '__type';
  GQL_INTROSPECT_TYPENAME = '__typename';

  { Operation / language keywords (spec Section 2). }
  GQL_KW_QUERY        = 'query';
  GQL_KW_MUTATION     = 'mutation';
  GQL_KW_SUBSCRIPTION = 'subscription';
  GQL_KW_FRAGMENT     = 'fragment';
  GQL_KW_ON           = 'on';
  GQL_KW_TRUE         = 'true';
  GQL_KW_FALSE        = 'false';
  GQL_KW_NULL         = 'null';

  { Error-message templates (used by the lexer/parser via GraphQL.Exceptions). }
  GQL_MSG_UNEXPECTED_TOKEN = 'Unexpected token "%s" at line %d, column %d';
  GQL_MSG_UNEXPECTED_CHAR  = 'Unexpected character "%s" at line %d, column %d';
  GQL_MSG_UNTERMINATED_STR = 'Unterminated string at line %d, column %d';

{$ENDIF USE_GRAPHQL}

implementation

end.
