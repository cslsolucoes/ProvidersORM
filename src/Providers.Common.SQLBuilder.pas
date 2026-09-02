{ ==========================================================================
  PROVENANCE NOTE (ProvidersORM v3, FASE 10 Onda 10.2 - USE_PROVIDERS_V161):
  Absorbed VERBATIM from FontesReferencias/ProvidersORM.v1.6.1/Commons/Providers.Common.SQLBuilder.pas
  into this v3 tree as part of the USE_PROVIDERS_V161 compatibility subsystem
  (legacy ProvidersORM v1.6.1, mechanical port only - zero logic/behavior/
  symbol-name changes; see the unit's own original header below for the
  authorial history). Reachable via uses Providers.v161 - NOT part of the
  unified TProviders facade (Main/Providers.pas).

  MECHANICAL FIX: System.SysUtils/System.Classes (interface uses) and
  System.StrUtils (implementation uses) - Delphi-scoped names, unresolvable
  under FPC in this toolchain - wrapped in an FPC conditional with the bare
  RTL names on the FPC branch and the System.* qualified names on the
  Delphi branch. Same units, same symbols, no logic change. File re-saved
  as UTF-8 BOM.
  ========================================================================== }

{
  Providers.Common.SQLBuilder - SQL Builder Commons para Provider v1.6.0
  
  Responsabilidade:
    - Construção de SQL específico para cada provider
    - Templates SQL reutilizáveis
    - Conversão de tipos de dados entre providers
    
  Compatibilidade: v1.5.0, v1.6.0
  Autor: Claiton de Souza Linhares
  Data: 27/01/2025
}
unit Providers.Common.SQLBuilder;

interface

uses
{$IFDEF FPC}
  SysUtils, Classes,
{$ELSE}
  System.SysUtils, System.Classes,
{$ENDIF}
  Utilities.Types;

type
  TProviderSQLBuilder = class
  private
    class function GetSQLFieldsPostgreSQL(const ASchema, ATable: String): String;
    class function GetSQLFieldsMySQL(const ASchema, ATable: String): String;
    class function GetSQLFieldsSQLServer(const ASchema, ATable: String): String;
    class function GetSQLFieldsFireBird(const ATable: String): String;
    class function GetSQLFieldsSQLite(const ATable: String): String;
    
    class function GetSQLPrimaryKeyPostgreSQL(const ASchema, ATable: String): String;
    class function GetSQLPrimaryKeyMySQL(const ASchema, ATable: String): String;
    class function GetSQLPrimaryKeySQLServer(const ASchema, ATable: String): String;
    class function GetSQLPrimaryKeyFireBird(const ATable: String): String;
    class function GetSQLPrimaryKeySQLite(const ATable: String): String;
    
    class function GetSQLTablesPostgreSQL(const ASchema, ADatabase: String): String;
    class function GetSQLTablesMySQL(const ASchema, ADatabase: String): String;
    class function GetSQLTablesSQLServer(const ASchema, ADatabase: String): String;
    class function GetSQLTablesFireBird: String;
    class function GetSQLTablesSQLite: String;
  public
    // SQL para obter campos da tabela
    class function GetSQLFields(AProvider: TDatabaseProvider; const ASchema, ATable: String): String;
    
    // SQL para obter primary keys
    class function GetSQLPrimaryKey(AProvider: TDatabaseProvider; const ASchema, ATable: String): String;
    
    // SQL para listar tabelas
    class function GetSQLTables(AProvider: TDatabaseProvider; const ASchema, ADatabase: String): String;
    
    // SQL para últimos 12 meses
    class function GetSQLLast12Months(AProvider: TDatabaseProvider): String;
    
    // Formatação de valores por tipo de provider
    class function FormatValue(AProvider: TDatabaseProvider; const AValue: String; ADataType: String): String;
    
    // Escape de strings para SQL
    class function EscapeString(AProvider: TDatabaseProvider; const AValue: String): String;
  end;

implementation

uses
{$IFDEF FPC}
  StrUtils;
{$ELSE}
  System.StrUtils;
{$ENDIF}

{ TProviderSQLBuilder }

class function TProviderSQLBuilder.GetSQLFields(AProvider: TDatabaseProvider; const ASchema, ATable: String): String;
begin
  case AProvider of
    dpPostgreSQL: Result := GetSQLFieldsPostgreSQL(ASchema, ATable);
    dpMySQL, dpMariaDB: Result := GetSQLFieldsMySQL(ASchema, ATable);
    dpSQLServer: Result := GetSQLFieldsSQLServer(ASchema, ATable);
    dpFireBird, dpFireBird3: Result := GetSQLFieldsFireBird(ATable);
    dpSQLite: Result := GetSQLFieldsSQLite(ATable);
  else
    Result := GetSQLFieldsPostgreSQL(ASchema, ATable);
  end;
end;

class function TProviderSQLBuilder.GetSQLFieldsPostgreSQL(const ASchema, ATable: String): String;
begin
  Result :=
    'WITH CKey AS (' + sLineBreak +
    '  SELECT' + sLineBreak +
    '    kcu.TABLE_CATALOG AS "database",' + sLineBreak +
    '    kcu.TABLE_SCHEMA AS "schema",' + sLineBreak +
    '    kcu.TABLE_NAME AS "table",' + sLineBreak +
    '    tco.CONSTRAINT_NAME,' + sLineBreak +
    '    kcu.ORDINAL_POSITION AS "position",' + sLineBreak +
    '    kcu.COLUMN_NAME' + sLineBreak +
    '  FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tco' + sLineBreak +
    '  JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu ON kcu.CONSTRAINT_NAME = tco.CONSTRAINT_NAME' + sLineBreak +
    '    AND kcu.TABLE_SCHEMA = tco.TABLE_SCHEMA' + sLineBreak +
    '  WHERE tco.CONSTRAINT_TYPE = ''PRIMARY KEY''' + sLineBreak +
    '    AND kcu.TABLE_SCHEMA = ''' + ASchema + '''' + sLineBreak +
    '    AND kcu.TABLE_NAME = ''' + ATable + '''' + sLineBreak +
    ')' + sLineBreak +
    'SELECT' + sLineBreak +
    '  CAST('''' AS VARCHAR(200)) AS "value",' + sLineBreak +
    '  CAST('''' AS VARCHAR(200)) AS "valuedefault",' + sLineBreak +
    '  CAST(0 AS INTEGER) AS "changed",' + sLineBreak +
    '  Col.TABLE_CATALOG AS table_catalog,' + sLineBreak +
    '  Col.TABLE_SCHEMA AS table_schema,' + sLineBreak +
    '  Col.TABLE_NAME AS table_name,' + sLineBreak +
    '  Col.ORDINAL_POSITION AS position,' + sLineBreak +
    '  Col.COLUMN_NAME AS "column_name",' + sLineBreak +
    '  upper(Col.DATA_TYPE) AS data_type,' + sLineBreak +
    '  Col.CHARACTER_MAXIMUM_LENGTH AS character_maximum_length,' + sLineBreak +
    '  Col.IS_NULLABLE AS is_nullable,' + sLineBreak +
    '  Col.COLUMN_DEFAULT AS column_default,' + sLineBreak +
    '  (SELECT 1 FROM CKey WHERE CKey.COLUMN_NAME = Col.COLUMN_NAME) AS PKey,' + sLineBreak +
    '  (SELECT CKey.CONSTRAINT_NAME FROM CKey WHERE CKey.COLUMN_NAME = Col.COLUMN_NAME) AS constraint_name' + sLineBreak +
    'FROM INFORMATION_SCHEMA.COLUMNS Col' + sLineBreak +
    'WHERE Col.TABLE_SCHEMA = ''' + ASchema + '''' + sLineBreak +
    '  AND Col.TABLE_NAME = ''' + ATable + '''' + sLineBreak +
    'ORDER BY Col.ORDINAL_POSITION';
end;

class function TProviderSQLBuilder.GetSQLFieldsMySQL(const ASchema, ATable: String): String;
begin
  Result :=
    'SELECT' + sLineBreak +
    '  CAST('''' AS VARCHAR(200)) as "value",' + sLineBreak +
    '  CAST('''' AS VARCHAR(200)) as "valuedefault",' + sLineBreak +
    '  CAST(0 AS INTEGER) as "changed",' + sLineBreak +
    '  TABLE_CATALOG as table_catalog,' + sLineBreak +
    '  TABLE_SCHEMA as table_schema,' + sLineBreak +
    '  TABLE_NAME as table_name,' + sLineBreak +
    '  ORDINAL_POSITION as position,' + sLineBreak +
    '  COLUMN_NAME as column_name,' + sLineBreak +
    '  DATA_TYPE as data_type,' + sLineBreak +
    '  CHARACTER_MAXIMUM_LENGTH as character_maximum_length,' + sLineBreak +
    '  IS_NULLABLE as is_nullable,' + sLineBreak +
    '  COLUMN_DEFAULT as column_default,' + sLineBreak +
    '  CASE WHEN COLUMN_KEY = ''PRI'' THEN 1 ELSE 0 END as PKey' + sLineBreak +
    'FROM INFORMATION_SCHEMA.COLUMNS' + sLineBreak +
    'WHERE TABLE_SCHEMA = ''' + ASchema + '''' + sLineBreak +
    '  AND TABLE_NAME = ''' + ATable + '''' + sLineBreak +
    'ORDER BY ORDINAL_POSITION';
end;

class function TProviderSQLBuilder.GetSQLFieldsSQLServer(const ASchema, ATable: String): String;
begin
  Result :=
    'With CKey as ( Select' + sLineBreak +
    '  kcu.TABLE_CATALOG as "database",' + sLineBreak +
    '  kcu.TABLE_SCHEMA as "schema",' + sLineBreak +
    '  kcu.TABLE_NAME as "table",' + sLineBreak +
    '  tco.CONSTRAINT_NAME,' + sLineBreak +
    '  kcu.ORDINAL_POSITION as "position",' + sLineBreak +
    '  kcu.COLUMN_NAME' + sLineBreak +
    'FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tco' + sLineBreak +
    'JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu' + sLineBreak +
    '  ON kcu.CONSTRAINT_NAME = tco.CONSTRAINT_NAME' + sLineBreak +
    '  AND kcu.TABLE_SCHEMA = tco.TABLE_SCHEMA' + sLineBreak +
    'WHERE tco.CONSTRAINT_TYPE = ''PRIMARY KEY''' + sLineBreak +
    '  AND kcu.TABLE_SCHEMA = ''' + ASchema + '''' + sLineBreak +
    '  AND kcu.TABLE_NAME = ''' + ATable + '''' + sLineBreak +
    ')' + sLineBreak +
    'SELECT' + sLineBreak +
    '  CAST('''' AS VARCHAR(200)) as "value",' + sLineBreak +
    '  CAST('''' AS VARCHAR(200)) as "valuedefault",' + sLineBreak +
    '  CAST(0 AS INTEGER) as "changed",' + sLineBreak +
    '  TABLE_CATALOG as table_catalog,' + sLineBreak +
    '  TABLE_SCHEMA as table_schema,' + sLineBreak +
    '  TABLE_NAME as table_name,' + sLineBreak +
    '  ORDINAL_POSITION as position,' + sLineBreak +
    '  COLUMN_NAME as "column_name",' + sLineBreak +
    '  upper(DATA_TYPE) as data_type,' + sLineBreak +
    '  CHARACTER_MAXIMUM_LENGTH as character_maximum_length,' + sLineBreak +
    '  IS_NULLABLE as is_nullable,' + sLineBreak +
    '  COLUMN_DEFAULT as column_default,' + sLineBreak +
    '  (Select 1 From Ckey Where COLUMN_NAME=Col.COLUMN_NAME) as PKey,' + sLineBreak +
    '  (Select CONSTRAINT_NAME From Ckey Where COLUMN_NAME=Col.COLUMN_NAME) as constraint_name' + sLineBreak +
    'FROM INFORMATION_SCHEMA.COLUMNS Col' + sLineBreak +
    'WHERE TABLE_SCHEMA = ''' + ASchema + '''' + sLineBreak +
    '  AND TABLE_NAME = ''' + ATable + '''' + sLineBreak +
    'ORDER BY ORDINAL_POSITION';
end;

class function TProviderSQLBuilder.GetSQLFieldsFireBird(const ATable: String): String;
begin
  Result :=
    'SELECT' + sLineBreak +
    '  CAST('''' AS VARCHAR(200)) as "value",' + sLineBreak +
    '  CAST('''' AS VARCHAR(200)) as "valuedefault",' + sLineBreak +
    '  CAST(0 AS INTEGER) as "changed",' + sLineBreak +
    '  CAST('''' AS VARCHAR(200)) as "table_catalog",' + sLineBreak +
    '  CAST('''' AS VARCHAR(200)) as "table_schema",' + sLineBreak +
    '  rf.RDB$RELATION_NAME as "table_name",' + sLineBreak +
    '  rf.RDB$FIELD_POSITION + 1 as "position",' + sLineBreak +
    '  rf.RDB$FIELD_NAME as "column_name",' + sLineBreak +
    '  upper(CASE f.RDB$FIELD_TYPE' + sLineBreak +
    '    WHEN 7 THEN ''SMALLINT''' + sLineBreak +
    '    WHEN 8 THEN ''INTEGER''' + sLineBreak +
    '    WHEN 10 THEN ''FLOAT''' + sLineBreak +
    '    WHEN 12 THEN ''DATE''' + sLineBreak +
    '    WHEN 13 THEN ''TIME''' + sLineBreak +
    '    WHEN 14 THEN ''CHAR''' + sLineBreak +
    '    WHEN 16 THEN ''BIGINT''' + sLineBreak +
    '    WHEN 27 THEN ''DOUBLE PRECISION''' + sLineBreak +
    '    WHEN 35 THEN ''TIMESTAMP''' + sLineBreak +
    '    WHEN 37 THEN ''VARCHAR''' + sLineBreak +
    '    WHEN 261 THEN ''BLOB''' + sLineBreak +
    '    ELSE ''UNKNOWN''' + sLineBreak +
    '  END) as "data_type",' + sLineBreak +
    '  f.RDB$FIELD_LENGTH as "character_maximum_length",' + sLineBreak +
    '  CASE WHEN rf.RDB$NULL_FLAG = 1 THEN ''NO'' ELSE ''YES'' END as "is_nullable",' + sLineBreak +
    '  rf.RDB$DEFAULT_SOURCE as "column_default",' + sLineBreak +
    '  (SELECT 1' + sLineBreak +
    '    FROM RDB$RELATION_CONSTRAINTS rc1' + sLineBreak +
    '    JOIN RDB$INDEX_SEGMENTS ise ON rc1.RDB$INDEX_NAME = ise.RDB$INDEX_NAME' + sLineBreak +
    '    WHERE rc1.RDB$CONSTRAINT_TYPE = ''PRIMARY KEY''' + sLineBreak +
    '      AND rc1.RDB$RELATION_NAME = ''' + ATable + '''' + sLineBreak +
    '      AND ise.RDB$FIELD_NAME=rf.RDB$FIELD_NAME) as pkey' + sLineBreak +
    'FROM RDB$RELATION_FIELDS rf' + sLineBreak +
    'JOIN RDB$FIELDS f ON rf.RDB$FIELD_SOURCE = f.RDB$FIELD_NAME' + sLineBreak +
    'WHERE rf.RDB$RELATION_NAME = ''' + ATable + '''' + sLineBreak +
    'ORDER BY rf.RDB$FIELD_POSITION';
end;

class function TProviderSQLBuilder.GetSQLFieldsSQLite(const ATable: String): String;
begin
  Result :=
    'SELECT' + sLineBreak +
    '  '''' as table_catalog,' + sLineBreak +
    '  '''' as table_schema,' + sLineBreak +
    '  ''' + ATable + ''' as table_name,' + sLineBreak +
    '  cid + 1 as position,' + sLineBreak +
    '  name as column_name,' + sLineBreak +
    '  type as data_type,' + sLineBreak +
    '  0 as character_maximum_length,' + sLineBreak +
    '  CASE WHEN "notnull" = 0 THEN ''YES'' ELSE ''NO'' END as is_nullable,' + sLineBreak +
    '  dflt_value as column_default,' + sLineBreak +
    '  pk as PKey' + sLineBreak +
    'FROM pragma_table_info(''' + ATable + ''')' + sLineBreak +
    'ORDER BY cid';
end;

class function TProviderSQLBuilder.GetSQLPrimaryKey(AProvider: TDatabaseProvider; const ASchema, ATable: String): String;
begin
  case AProvider of
    dpPostgreSQL: Result := GetSQLPrimaryKeyPostgreSQL(ASchema, ATable);
    dpMySQL, dpMariaDB: Result := GetSQLPrimaryKeyMySQL(ASchema, ATable);
    dpSQLServer: Result := GetSQLPrimaryKeySQLServer(ASchema, ATable);
    dpFireBird, dpFireBird3: Result := GetSQLPrimaryKeyFireBird(ATable);
    dpSQLite: Result := GetSQLPrimaryKeySQLite(ATable);
  else
    Result := GetSQLPrimaryKeyPostgreSQL(ASchema, ATable);
  end;
end;

class function TProviderSQLBuilder.GetSQLPrimaryKeyPostgreSQL(const ASchema, ATable: String): String;
begin
  Result :=
    'WITH CKey AS (' + sLineBreak +
    '  SELECT' + sLineBreak +
    '    kcu.TABLE_CATALOG AS "database",' + sLineBreak +
    '    kcu.TABLE_SCHEMA AS "schema",' + sLineBreak +
    '    kcu.TABLE_NAME AS "table",' + sLineBreak +
    '    tco.CONSTRAINT_NAME,' + sLineBreak +
    '    kcu.ORDINAL_POSITION AS "position",' + sLineBreak +
    '    kcu.COLUMN_NAME' + sLineBreak +
    '  FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tco' + sLineBreak +
    '  JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu ON kcu.CONSTRAINT_NAME = tco.CONSTRAINT_NAME' + sLineBreak +
    '    AND kcu.TABLE_SCHEMA = tco.TABLE_SCHEMA' + sLineBreak +
    '  WHERE tco.CONSTRAINT_TYPE = ''PRIMARY KEY''' + sLineBreak +
    '    AND kcu.TABLE_SCHEMA = ''' + ASchema + '''' + sLineBreak +
    '    AND kcu.TABLE_NAME = ''' + ATable + '''' + sLineBreak +
    ')' + sLineBreak +
    'SELECT' + sLineBreak +
    '  CAST('''' AS VARCHAR(200)) AS "value",' + sLineBreak +
    '  CAST('''' AS VARCHAR(200)) AS "valuedefault",' + sLineBreak +
    '  CAST(0 AS INTEGER) AS "changed",' + sLineBreak +
    '  Col.TABLE_CATALOG AS table_catalog,' + sLineBreak +
    '  Col.TABLE_SCHEMA AS table_schema,' + sLineBreak +
    '  Col.TABLE_NAME AS table_name,' + sLineBreak +
    '  Col.ORDINAL_POSITION AS position,' + sLineBreak +
    '  Col.COLUMN_NAME AS "column_name",' + sLineBreak +
    '  upper(Col.DATA_TYPE) AS data_type,' + sLineBreak +
    '  Col.CHARACTER_MAXIMUM_LENGTH AS character_maximum_length,' + sLineBreak +
    '  Col.IS_NULLABLE AS is_nullable,' + sLineBreak +
    '  Col.COLUMN_DEFAULT AS column_default,' + sLineBreak +
    '  (SELECT 1 FROM CKey WHERE CKey.COLUMN_NAME = Col.COLUMN_NAME) AS PKey,' + sLineBreak +
    '  (SELECT CKey.CONSTRAINT_NAME FROM CKey WHERE CKey.COLUMN_NAME = Col.COLUMN_NAME) AS constraint_name' + sLineBreak +
    'FROM INFORMATION_SCHEMA.COLUMNS Col' + sLineBreak +
    'WHERE Col.TABLE_SCHEMA = ''' + ASchema + '''' + sLineBreak +
    '  AND Col.TABLE_NAME = ''' + ATable + '''' + sLineBreak +
    '  AND (SELECT 1 FROM CKey WHERE COLUMN_NAME=Col.COLUMN_NAME) is not null' + sLineBreak +
    'ORDER BY Col.ORDINAL_POSITION';
end;

class function TProviderSQLBuilder.GetSQLPrimaryKeyMySQL(const ASchema, ATable: String): String;
begin
  Result :=
    'SELECT' + sLineBreak +
    '  TABLE_SCHEMA as schema,' + sLineBreak +
    '  TABLE_NAME as table,' + sLineBreak +
    '  ORDINAL_POSITION as position,' + sLineBreak +
    '  COLUMN_NAME as "column_name",' + sLineBreak +
    '  DATA_TYPE, COLUMN_TYPE, COLUMN_KEY, EXTRA' + sLineBreak +
    'FROM INFORMATION_SCHEMA.COLUMNS' + sLineBreak +
    'WHERE COLUMN_KEY = ''PRI''' + sLineBreak +
    '  AND TABLE_SCHEMA = ''' + ASchema + '''' + sLineBreak +
    '  AND TABLE_NAME = ''' + ATable + '''' + sLineBreak +
    'ORDER BY TABLE_NAME, ORDINAL_POSITION';
end;

class function TProviderSQLBuilder.GetSQLPrimaryKeySQLServer(const ASchema, ATable: String): String;
begin
  Result :=
    'SELECT' + sLineBreak +
    '  kcu.TABLE_CATALOG as "database",' + sLineBreak +
    '  kcu.TABLE_SCHEMA as "schema",' + sLineBreak +
    '  kcu.TABLE_NAME as "table",' + sLineBreak +
    '  tco.CONSTRAINT_NAME as "constraint",' + sLineBreak +
    '  kcu.ORDINAL_POSITION as "position",' + sLineBreak +
    '  kcu.COLUMN_NAME as "column_name"' + sLineBreak +
    'FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tco' + sLineBreak +
    'JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu' + sLineBreak +
    '  ON kcu.CONSTRAINT_NAME = tco.CONSTRAINT_NAME' + sLineBreak +
    '  AND kcu.TABLE_SCHEMA = tco.TABLE_SCHEMA' + sLineBreak +
    'WHERE tco.CONSTRAINT_TYPE = ''PRIMARY KEY''' + sLineBreak +
    '  AND kcu.TABLE_SCHEMA = ''' + ASchema + '''' + sLineBreak +
    '  AND kcu.TABLE_NAME = ''' + ATable + '''' + sLineBreak +
    'ORDER BY kcu.ORDINAL_POSITION';
end;

class function TProviderSQLBuilder.GetSQLPrimaryKeyFireBird(const ATable: String): String;
begin
  Result :=
    'SELECT' + sLineBreak +
    '  CAST('''' AS VARCHAR(200)) as "value",' + sLineBreak +
    '  CAST('''' AS VARCHAR(200)) as "valuedefault",' + sLineBreak +
    '  CAST(0 AS INTEGER) as "changed",' + sLineBreak +
    '  CAST('''' AS VARCHAR(200)) as "table_catalog",' + sLineBreak +
    '  CAST('''' AS VARCHAR(200)) as "table_schema",' + sLineBreak +
    '  rf.RDB$RELATION_NAME as "table_name",' + sLineBreak +
    '  rf.RDB$FIELD_POSITION + 1 as "position",' + sLineBreak +
    '  rf.RDB$FIELD_NAME as "column_name",' + sLineBreak +
    '  upper(CASE f.RDB$FIELD_TYPE' + sLineBreak +
    '    WHEN 7 THEN ''SMALLINT''' + sLineBreak +
    '    WHEN 8 THEN ''INTEGER''' + sLineBreak +
    '    WHEN 10 THEN ''FLOAT''' + sLineBreak +
    '    WHEN 12 THEN ''DATE''' + sLineBreak +
    '    WHEN 13 THEN ''TIME''' + sLineBreak +
    '    WHEN 14 THEN ''CHAR''' + sLineBreak +
    '    WHEN 16 THEN ''BIGINT''' + sLineBreak +
    '    WHEN 27 THEN ''DOUBLE PRECISION''' + sLineBreak +
    '    WHEN 35 THEN ''TIMESTAMP''' + sLineBreak +
    '    WHEN 37 THEN ''VARCHAR''' + sLineBreak +
    '    WHEN 261 THEN ''BLOB''' + sLineBreak +
    '    ELSE ''UNKNOWN''' + sLineBreak +
    '  END) as "data_type",' + sLineBreak +
    '  f.RDB$FIELD_LENGTH as "character_maximum_length",' + sLineBreak +
    '  CASE WHEN rf.RDB$NULL_FLAG = 1 THEN ''NO'' ELSE ''YES'' END as "is_nullable",' + sLineBreak +
    '  rf.RDB$DEFAULT_SOURCE as "column_default",' + sLineBreak +
    '  (SELECT 1' + sLineBreak +
    '    FROM RDB$RELATION_CONSTRAINTS rc1' + sLineBreak +
    '    JOIN RDB$INDEX_SEGMENTS ise ON rc1.RDB$INDEX_NAME = ise.RDB$INDEX_NAME' + sLineBreak +
    '    WHERE rc1.RDB$CONSTRAINT_TYPE = ''PRIMARY KEY''' + sLineBreak +
    '      AND rc1.RDB$RELATION_NAME = ''' + ATable + '''' + sLineBreak +
    '      AND ise.RDB$FIELD_NAME=rf.RDB$FIELD_NAME) as pkey,' + sLineBreak +
    '  (SELECT rc1.RDB$CONSTRAINT_NAME' + sLineBreak +
    '    FROM RDB$RELATION_CONSTRAINTS rc1' + sLineBreak +
    '    JOIN RDB$INDEX_SEGMENTS ise ON rc1.RDB$INDEX_NAME = ise.RDB$INDEX_NAME' + sLineBreak +
    '    WHERE rc1.RDB$CONSTRAINT_TYPE = ''PRIMARY KEY''' + sLineBreak +
    '      AND rc1.RDB$RELATION_NAME = ''' + ATable + '''' + sLineBreak +
    '      AND ise.RDB$FIELD_NAME=rf.RDB$FIELD_NAME) as constraint_name' + sLineBreak +
    'FROM RDB$RELATION_FIELDS rf' + sLineBreak +
    'JOIN RDB$FIELDS f ON rf.RDB$FIELD_SOURCE = f.RDB$FIELD_NAME' + sLineBreak +
    'WHERE rf.RDB$RELATION_NAME = ''' + ATable + '''' + sLineBreak +
    '  AND (SELECT 1' + sLineBreak +
    '    FROM RDB$RELATION_CONSTRAINTS rc1' + sLineBreak +
    '    JOIN RDB$INDEX_SEGMENTS ise ON rc1.RDB$INDEX_NAME = ise.RDB$INDEX_NAME' + sLineBreak +
    '    WHERE rc1.RDB$CONSTRAINT_TYPE = ''PRIMARY KEY''' + sLineBreak +
    '      AND rc1.RDB$RELATION_NAME = ''' + ATable + '''' + sLineBreak +
    '      AND ise.RDB$FIELD_NAME=rf.RDB$FIELD_NAME) is not null' + sLineBreak +
    'ORDER BY rf.RDB$FIELD_POSITION';
end;

class function TProviderSQLBuilder.GetSQLPrimaryKeySQLite(const ATable: String): String;
begin
  Result :=
    'SELECT' + sLineBreak +
    '  '''' as database,' + sLineBreak +
    '  '''' as schema,' + sLineBreak +
    '  name as table,' + sLineBreak +
    '  '''' as constraint,' + sLineBreak +
    '  cid + 1 as position,' + sLineBreak +
    '  name as "column_name"' + sLineBreak +
    'FROM pragma_table_info(''' + ATable + ''')' + sLineBreak +
    'WHERE pk > 0' + sLineBreak +
    'ORDER BY pk';
end;

class function TProviderSQLBuilder.GetSQLTables(AProvider: TDatabaseProvider; const ASchema, ADatabase: String): String;
begin
  case AProvider of
    dpPostgreSQL: Result := GetSQLTablesPostgreSQL(ASchema, ADatabase);
    dpMySQL, dpMariaDB: Result := GetSQLTablesMySQL(ASchema, ADatabase);
    dpSQLServer: Result := GetSQLTablesSQLServer(ASchema, ADatabase);
    dpFireBird, dpFireBird3: Result := GetSQLTablesFireBird;
    dpSQLite: Result := GetSQLTablesSQLite;
  else
    Result := GetSQLTablesPostgreSQL(ASchema, ADatabase);
  end;
end;

class function TProviderSQLBuilder.GetSQLTablesPostgreSQL(const ASchema, ADatabase: String): String;
begin
  Result :=
    'SELECT' + sLineBreak +
    '  table_catalog,' + sLineBreak +
    '  table_schema,' + sLineBreak +
    '  table_name,' + sLineBreak +
    '  table_type' + sLineBreak +
    'FROM information_schema.tables' + sLineBreak +
    'WHERE table_type = ''BASE TABLE''' + sLineBreak +
    '  AND table_catalog = ''' + ADatabase + '''' + sLineBreak +
    '  AND table_schema = ''' + ASchema + '''' + sLineBreak +
    'ORDER BY table_name';
end;

class function TProviderSQLBuilder.GetSQLTablesMySQL(const ASchema, ADatabase: String): String;
begin
  Result :=
    'SELECT' + sLineBreak +
    '  TABLE_CATALOG as table_catalog,' + sLineBreak +
    '  TABLE_SCHEMA as table_schema,' + sLineBreak +
    '  TABLE_NAME as table_name,' + sLineBreak +
    '  TABLE_TYPE as table_type' + sLineBreak +
    'FROM INFORMATION_SCHEMA.TABLES' + sLineBreak +
    'WHERE TABLE_TYPE = ''BASE TABLE''' + sLineBreak +
    '  AND TABLE_SCHEMA = ''' + ADatabase + '''' + sLineBreak +
    'ORDER BY TABLE_NAME';
end;

class function TProviderSQLBuilder.GetSQLTablesSQLServer(const ASchema, ADatabase: String): String;
begin
  Result :=
    'SELECT' + sLineBreak +
    '  TABLE_CATALOG as table_catalog,' + sLineBreak +
    '  TABLE_SCHEMA as table_schema,' + sLineBreak +
    '  TABLE_NAME as table_name,' + sLineBreak +
    '  TABLE_TYPE as table_type' + sLineBreak +
    'FROM INFORMATION_SCHEMA.TABLES' + sLineBreak +
    'WHERE TABLE_TYPE = ''BASE TABLE''' + sLineBreak +
    '  AND TABLE_CATALOG = ''' + ADatabase + '''' + sLineBreak +
    '  AND TABLE_SCHEMA = ''' + ASchema + '''' + sLineBreak +
    'ORDER BY TABLE_NAME';
end;

class function TProviderSQLBuilder.GetSQLTablesFireBird: String;
begin
  Result :=
    'SELECT' + sLineBreak +
    '  '''' as table_catalog,' + sLineBreak +
    '  '''' as table_schema,' + sLineBreak +
    '  RDB$RELATION_NAME as table_name,' + sLineBreak +
    '  ''BASE TABLE'' as table_type' + sLineBreak +
    'FROM RDB$RELATIONS' + sLineBreak +
    'WHERE RDB$SYSTEM_FLAG = 0' + sLineBreak +
    '  AND RDB$RELATION_TYPE = 0' + sLineBreak +
    'ORDER BY RDB$RELATION_NAME';
end;

class function TProviderSQLBuilder.GetSQLTablesSQLite: String;
begin
  Result :=
    'SELECT' + sLineBreak +
    '  '''' as table_catalog,' + sLineBreak +
    '  '''' as table_schema,' + sLineBreak +
    '  name as table_name,' + sLineBreak +
    '  ''BASE TABLE'' as table_type' + sLineBreak +
    'FROM sqlite_master' + sLineBreak +
    'WHERE type = ''table''' + sLineBreak +
    '  AND name NOT LIKE ''sqlite_%''' + sLineBreak +
    'ORDER BY name';
end;

class function TProviderSQLBuilder.GetSQLLast12Months(AProvider: TDatabaseProvider): String;
begin
  // Implementação simplificada - pode ser expandida
  case AProvider of
    dpPostgreSQL:
      Result := 'SELECT NOW() as data_atual';
    dpSQLServer:
      Result := 'SELECT GETDATE() as data_atual';
    dpMySQL, dpMariaDB:
      Result := 'SELECT CURDATE() as data_atual';
    dpSQLite:
      Result := 'SELECT DATE(''now'') as data_atual';
  else
    Result := 'SELECT CURRENT_DATE as data_atual';
  end;
end;

class function TProviderSQLBuilder.FormatValue(AProvider: TDatabaseProvider; const AValue: String; ADataType: String): String;
begin
  // Implementação básica - pode ser expandida
  Result := AValue;
end;

class function TProviderSQLBuilder.EscapeString(AProvider: TDatabaseProvider; const AValue: String): String;
begin
  // Escape básico - substituir ' por ''
  Result := StringReplace(AValue, '''', '''''', [rfReplaceAll]);
end;

end.

