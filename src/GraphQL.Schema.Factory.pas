{ =============================================================================
  GraphQL.Schema.Factory - build a GraphQL schema from an ORM catalog
  (FASE 13, wave 13A.3)

  TGraphQLSchemaFactory.FromMetadata(ICatalogReader) reads a database catalog
  (tables, columns, primary keys, foreign keys) via the ORM's ICatalogReader
  (module Database, consumed READ-ONLY) and emits an executable IGraphQLSchema:

    - one ObjectType per table (PascalCased table name);
    - column -> field, mapped RAW ColumnType -> TSQLColumnKind (via the promoted
      Database.SchemaColumnTypeToKind SSOT) -> GraphQL scalar; PRIMARY KEY -> ID!;
      NOT NULL -> NonNull;
    - foreign key -> navigation field to the referenced ObjectType (object for
      N:1/1:1, list for 1:N), skipping FKs whose target table is out of scope;
    - one InputObjectType per table (<Type>Input, non-PK/non-identity columns);
    - Query root with <type>(id: ID!) and <type>List(limit, offset);
    - Mutation root with insert<Type>/update<Type>/delete<Type>.

  STRUCTURE ONLY: field resolvers (binding to IQueryBuilder + the anti-N+1
  batch-loader) are wired in wave 13A.4 (Executor). Custom scalars (Long/Decimal/
  Date/Time/DateTime/Blob) are declared here as identity scalars; real coercion
  is a 13A.4 concern. Cross-compiler (Delphi 12 + FPC 3.3.1); no generics beyond
  the ORM's own TArray<> return types; no RTTI.

  Known limitations (documented backlog, non-blocking for 13A.3):
    - composite primary keys: each PK column becomes ID!, but the CRUD root args
      assume a single-column id (first PK); multi-key lookup is 13A.4+.
    - two FKs to the same target table collide on the navigation field name
      (only the first is emitted, via FindField dedup);
    - table/column names are only sanitized to a valid GraphQL name + PascalCase
      first letter (no pluralization / singularization / logical-name mapping).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           11/08/2026

  Changelog (file):
  - 1.0.0 (11/08/2026): FASE 13 wave 13A.3 - TGraphQLSchemaFactory.FromMetadata:
    catalog (ICatalogReader) -> IGraphQLSchema (types + CRUD roots + input types)
    using the promoted Database.SchemaColumnTypeToKind for RAW->kind mapping.
  ============================================================================= }

unit GraphQL.Schema.Factory;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IF DEFINED(USE_GRAPHQL) AND DEFINED(USE_DATABASE)}

uses
{$IF DEFINED(FPC)}
  SysUtils,
{$ELSE}
  System.SysUtils,
{$ENDIF}
  Commons.Types,            // TDatabaseFields, TStringArray
  Commons.Database.Types,   // TSQLColumnKind, TRelationInfo, TRelationCardinality
  Database.CatalogReader,   // ICatalogReader
  Database.Schema,          // SchemaColumnTypeToKind (promoted to interface, 13A.3)
  GraphQL.Consts,
  GraphQL.Schema.Types,
  GraphQL.Schema;

type
  { Generates an executable GraphQL schema (types + CRUD roots + input types)
    from an ORM catalog. Structure only - resolvers land in wave 13A.4. }
  TGraphQLSchemaFactory = class
  public
    class function FromMetadata(const AMeta: ICatalogReader;
      const ASchema: string = ''): IGraphQLSchema;
  end;

{ Naming convention exposed so the ORM resolver wiring (13A.4-c) reuses the exact
  same table->type and type->root-field mapping instead of duplicating it. }
function GraphQLTypeNameForTable(const ATableName: string): string;
function GraphQLRootFieldName(const ATypeName: string): string;
function GraphQLStripSchema(const AName: string): string;

{$ENDIF}

implementation

{$IF DEFINED(USE_GRAPHQL) AND DEFINED(USE_DATABASE)}

const
  { Generated custom scalars (not GraphQL built-ins) - identity coercion until
    the executor (13A.4) attaches real Serialize/ParseLiteral. }
  GQL_GEN_SCALAR_LONG     = 'Long';
  GQL_GEN_SCALAR_DECIMAL  = 'Decimal';
  GQL_GEN_SCALAR_DATE     = 'Date';
  GQL_GEN_SCALAR_TIME     = 'Time';
  GQL_GEN_SCALAR_DATETIME = 'DateTime';
  GQL_GEN_SCALAR_BLOB     = 'Blob';

{ Keeps only characters valid in a GraphQL Name (/[_A-Za-z][_0-9A-Za-z]*/);
  everything else becomes '_'. Empty -> '_'; leading digit -> prefixed '_'. }
function SanitizeName(const AName: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(AName) do
  begin
    C := AName[I];
    if ((C >= 'A') and (C <= 'Z')) or ((C >= 'a') and (C <= 'z')) or
       ((C >= '0') and (C <= '9')) or (C = '_') then
      Result := Result + C
    else
      Result := Result + '_';
  end;
  if Result = '' then
    Result := '_';
  if (Result[1] >= '0') and (Result[1] <= '9') then
    Result := '_' + Result;
end;

function UpFirst(const S: string): string;
begin
  Result := S;
  if (Result <> '') and (Result[1] >= 'a') and (Result[1] <= 'z') then
    Result[1] := Chr(Ord(Result[1]) - 32);
end;

function LowFirst(const S: string): string;
begin
  Result := S;
  if (Result <> '') and (Result[1] >= 'A') and (Result[1] <= 'Z') then
    Result[1] := Chr(Ord(Result[1]) + 32);
end;

function TypeNameOf(const ATableName: string): string;
begin
  Result := UpFirst(SanitizeName(ATableName));
end;

function GraphQLTypeNameForTable(const ATableName: string): string;
begin
  Result := UpFirst(SanitizeName(ATableName));
end;

function GraphQLRootFieldName(const ATypeName: string): string;
begin
  Result := LowFirst(ATypeName);
end;

function IsBuiltinScalar(const AName: string): Boolean;
begin
  Result := (AName = GQL_SCALAR_INT) or (AName = GQL_SCALAR_FLOAT) or
            (AName = GQL_SCALAR_STRING) or (AName = GQL_SCALAR_BOOLEAN) or
            (AName = GQL_SCALAR_ID);
end;

function ScalarNameForKind(AKind: TSQLColumnKind): string;
begin
  case AKind of
    ckSmallInt, ckInteger:      Result := GQL_SCALAR_INT;
    ckBigInt:                   Result := GQL_GEN_SCALAR_LONG;
    ckIdentity:                 Result := GQL_SCALAR_ID;
    ckFloat:                    Result := GQL_SCALAR_FLOAT;
    ckDecimal:                  Result := GQL_GEN_SCALAR_DECIMAL;
    ckBoolean:                  Result := GQL_SCALAR_BOOLEAN;
    ckVarChar, ckChar, ckText:  Result := GQL_SCALAR_STRING;
    ckDate:                     Result := GQL_GEN_SCALAR_DATE;
    ckTime:                     Result := GQL_GEN_SCALAR_TIME;
    ckDateTime:                 Result := GQL_GEN_SCALAR_DATETIME;
    ckBlob:                     Result := GQL_GEN_SCALAR_BLOB;
  else
    Result := GQL_SCALAR_STRING;
  end;
end;

{ Registers AName as a custom scalar once, unless it is a built-in (Int/Float/
  String/Boolean/ID - the Build step registers those implicitly). }
procedure EnsureScalar(ABuilder: TGraphQLSchemaBuilder; const AName: string);
begin
  if (not IsBuiltinScalar(AName)) and (ABuilder.Find(AName) = nil) then
    ABuilder.ScalarType(AName);
end;

function ColInArray(const ACol: string; const AArr: TStringArray): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(AArr) do
    if SameText(AArr[I], ACol) then
      Exit(True);
end;

{ ICatalogReader.ResolveFK may return a schema-qualified target table name
  (e.g. 'public.customer', 'gql13a3.customer'), whereas TableNames returns bare
  names - reduce to the part after the last '.' so scope matching works. }
function StripSchemaQualifier(const AName: string): string;
var
  P: Integer;
begin
  Result := AName;
  P := Length(Result);
  while (P > 0) and (Result[P] <> '.') do
    Dec(P);
  if P > 0 then
    Result := Copy(Result, P + 1, Length(Result) - P);
end;

function GraphQLStripSchema(const AName: string): string;
begin
  Result := StripSchemaQualifier(AName);
end;

{ TGraphQLSchemaFactory }

class function TGraphQLSchemaFactory.FromMetadata(const AMeta: ICatalogReader;
  const ASchema: string): IGraphQLSchema;
var
  LBuilder: TGraphQLSchemaBuilder;
  LQuery, LMutation: TGraphQLObjectType;
  LTables: TStringArray;
  T: Integer;

  function TableInScope(const AName: string): Boolean;
  var
    K: Integer;
  begin
    Result := False;
    for K := 0 to High(LTables) do
      if SameText(LTables[K], AName) then
        Exit(True);
  end;

  procedure BuildTable(const ATableName: string);
  var
    LTypeName, LRootName: string;
    LObj: TGraphQLObjectType;
    LInput: TGraphQLInputObjectType;
    LCols: TArray<TDatabaseFields>;
    LRels: TArray<TRelationInfo>;
    LPKs: TStringArray;
    LList, LUpd: TGraphQLFieldDef;
    I: Integer;
    LFieldName, LBase, LTypeExpr, LScalar, LNavName, LToType, LBareTo: string;
    LIsPK, LIsIdentity, LNonNull: Boolean;
    LKind: TSQLColumnKind;
  begin
    LTypeName := TypeNameOf(ATableName);
    LRootName := LowFirst(LTypeName);
    LObj := LBuilder.ObjectType(LTypeName);
    LInput := LBuilder.InputObjectType(LTypeName + 'Input');

    { columns -> fields; PK detected via the dedicated PrimaryKeyColumns (more
      reliable cross-engine) with the per-column IsPKey flag as a fallback }
    LPKs := AMeta.PrimaryKeyColumns(ATableName, ASchema);
    LCols := AMeta.TableStructure(ATableName, ASchema);
    for I := 0 to High(LCols) do
    begin
      LFieldName := SanitizeName(LCols[I].Column);
      LIsPK := (LCols[I].IsPKey = 1) or ColInArray(LCols[I].Column, LPKs);
      LIsIdentity := (LCols[I].IsIdentity = 1);
      if LIsPK then
        LBase := GQL_SCALAR_ID
      else
      begin
        LKind := SchemaColumnTypeToKind(LCols[I].ColumnType, LIsIdentity);
        LScalar := ScalarNameForKind(LKind);
        EnsureScalar(LBuilder, LScalar);
        LBase := LScalar;
      end;
      LNonNull := LIsPK or (not SameText(LCols[I].IsNull, 'YES'));
      if LNonNull then
        LTypeExpr := LBase + '!'
      else
        LTypeExpr := LBase;
      LObj.AddField(LFieldName, LTypeExpr);
      { input type: skip PK and identity (server-assigned) }
      if not (LIsPK or LIsIdentity) then
        LInput.AddInputField(LFieldName, LTypeExpr);
    end;

    { foreign keys -> navigation fields (only to in-scope tables) }
    LRels := AMeta.ResolveFK(ATableName, ASchema);
    for I := 0 to High(LRels) do
    begin
      LBareTo := StripSchemaQualifier(LRels[I].ToTable);
      if not TableInScope(LBareTo) then
        Continue;
      LToType := TypeNameOf(LBareTo);
      LNavName := LowFirst(LToType);
      if LRels[I].Cardinality = rcOneToMany then
      begin
        if LObj.FindField(LNavName + 'List') = nil then
          LObj.AddField(LNavName + 'List', '[' + LToType + '!]');
      end
      else { rcManyToOne / rcOneToOne / rcUnknown: a FK column is N:1 by nature }
        if LObj.FindField(LNavName) = nil then
          LObj.AddField(LNavName, LToType);
    end;

    { CRUD roots }
    LQuery.AddField(LRootName, LTypeName).AddArg('id', 'ID!');
    LList := LQuery.AddField(LRootName + 'List', '[' + LTypeName + '!]');
    LList.AddArg('limit', GQL_SCALAR_INT);
    LList.AddArg('offset', GQL_SCALAR_INT);

    LMutation.AddField('insert' + LTypeName, LTypeName).AddArg('input', LTypeName + 'Input!');
    LUpd := LMutation.AddField('update' + LTypeName, LTypeName);
    LUpd.AddArg('id', 'ID!');
    LUpd.AddArg('input', LTypeName + 'Input!');
    LMutation.AddField('delete' + LTypeName, GQL_SCALAR_BOOLEAN).AddArg('id', 'ID!');
  end;

begin
  LBuilder := TGraphQLSchemaBuilder.Create;
  try
    LTables := AMeta.TableNames(ASchema);
    LQuery := LBuilder.ObjectType('Query');
    if Length(LTables) > 0 then
      LMutation := LBuilder.ObjectType('Mutation')
    else
      LMutation := nil;
    for T := 0 to High(LTables) do
      BuildTable(LTables[T]);
    LBuilder.Query('Query');
    if LMutation <> nil then
      LBuilder.Mutation('Mutation');
    Result := LBuilder.Build;
  finally
    LBuilder.Free;
  end;
end;

{$ENDIF}

end.
