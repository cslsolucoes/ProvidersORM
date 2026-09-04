{ =============================================================================
  GraphQL.Types - shared DATA types of the GraphQL module (FASE 13, wave 13A.0)

  Enums and position record shared by the Core (lexer/parser/AST) and the
  Server/Client. Placement: per owner decision (11/08) the GraphQL module is
  self-contained - this is the in-module equivalent of Commons.GraphQL.Types
  (Commons/ stays READ-ONLY). Pure data only: no logic, no dependency beyond the
  RTL. Gated by USE_GRAPHQL.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           11/08/2026

  Changelog (file):
  - 1.0.0 (11/08/2026): FASE 13 wave 13A.0 - token kinds (lexer), AST node kinds,
    operation type (query/mutation/subscription), type-system kinds
    (scalar/object/.../nonnull) and a 1-based Line/Column position record.
    Aligned with the local spec (FontesReferencias/graphql/graphql-spec,
    Section 2 + Section 4) and the graphql-js blueprint. No logic.
  ============================================================================= }

unit GraphQL.Types;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_GRAPHQL}

type
  { Lexical token kinds (spec Section 2.1.6 + punctuators 2.1.9; graphql-js
    TokenKind). gtkEOF marks end of input; gtkComment is an ignored token kept
    for tooling. }
  TGraphQLTokenKind = (
    gtkEOF,
    gtkBang,        // !
    gtkDollar,      // $
    gtkAmp,         // &
    gtkParenL,      // (
    gtkParenR,      // )
    gtkSpread,      // ...
    gtkColon,       // :
    gtkEquals,      // =
    gtkAt,          // @
    gtkBracketL,    // [
    gtkBracketR,    // ]
    gtkBraceL,      // {
    gtkPipe,        // |
    gtkBraceR,      // }
    gtkName,        // Name
    gtkInt,         // IntValue
    gtkFloat,       // FloatValue
    gtkString,      // StringValue
    gtkBlockString, // """ block string """
    gtkComment      // # comment (ignored token)
  );

  { AST node kinds for an EXECUTABLE document (query/mutation/subscription).
    SDL / type-system nodes are added in wave 13A.2. }
  TGraphQLAstNodeKind = (
    ankDocument,
    ankOperationDefinition,
    ankVariableDefinition,
    ankSelectionSet,
    ankField,
    ankArgument,
    ankFragmentSpread,
    ankInlineFragment,
    ankFragmentDefinition,
    ankVariable,
    ankIntValue,
    ankFloatValue,
    ankStringValue,
    ankBooleanValue,
    ankNullValue,
    ankEnumValue,
    ankListValue,
    ankObjectValue,
    ankObjectField,
    ankDirective,
    ankNamedType,
    ankListType,
    ankNonNullType
  );

  { Operation type (spec Section 2.3). }
  TGraphQLOperationType = (otQuery, otMutation, otSubscription);

  { Type-system kind (spec Section 4 __TypeKind). tkList/tkNonNull are wrappers. }
  TGraphQLTypeKind = (
    tkScalar,
    tkObject,
    tkInterface,
    tkUnion,
    tkEnum,
    tkInputObject,
    tkList,
    tkNonNull
  );

  { 1-based source position, attached to every token and AST node so the
    executor can emit errors[].locations[].line/column (spec Section 7). }
  TGraphQLPosition = record
    Line: Integer;
    Column: Integer;
  end;

{$ENDIF USE_GRAPHQL}

implementation

end.
