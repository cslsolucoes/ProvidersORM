{ =============================================================================
  GraphQL.Version - ModuleVersion of the GraphQL module (FASE 13)

  Version of the v3 GraphQL module (server 13-A + client 13-B, shared Core).
  1.0.0 is the foundation baseline (wave 13A.0): defines, data types, consts and
  the exception hierarchy. Lexer/parser/AST (13A.1) and beyond bump from here.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           11/08/2026

  Changelog (file):
  - 1.0.0 (11/08/2026): FASE 13 wave 13A.0 - foundation of the GraphQL module
    (greenfield, self-contained under src/Modulos/GraphQL/ per owner decision
    11/08: the concluded modules Commons/Exceptions stay READ-ONLY, so the
    cross-cutting data/exception units live INSIDE the module as GraphQL.Types/
    GraphQL.Consts/GraphQL.Exceptions instead of Commons.GraphQL.*/
    Exceptions.GraphQL). ModuleVersion 1.0.0.
  ============================================================================= }

unit GraphQL.Version;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

const
  GRAPHQL_VERSION_MAJOR = 1;
  GRAPHQL_VERSION_MINOR = 0;
  GRAPHQL_VERSION_PATCH = 0;
  GRAPHQL_VERSION       = '1.0.0';
  GRAPHQL_VERSION_DATE  = '11/08/2026';

  { Human-readable form for logs / About box. }
  GRAPHQL_VERSION_FULL  = 'GraphQL ' + GRAPHQL_VERSION +
                          ' (' + GRAPHQL_VERSION_DATE + ')';

implementation

end.
