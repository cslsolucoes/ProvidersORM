{ ==========================================================================
  PROVENANCE NOTE (ProvidersORM v3, FASE 10 Onda 10.2 - USE_PROVIDERS_V161):
  Absorbed VERBATIM from FontesReferencias/ProvidersORM.v1.6.1/Commons/Providers.Common.TypeConverter.pas
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
  Providers.Common.TypeConverter - Conversores de Tipo para Provider v1.6.0
  
  Responsabilidade:
    - Conversão de tipos de dados entre diferentes providers
    - Mapeamento de tipos de dados
    - Formatação de valores por tipo
    
  Compatibilidade: v1.5.0, v1.6.0
  Autor: Claiton de Souza Linhares
  Data: 27/01/2025
}
unit Providers.Common.TypeConverter;

interface

uses
{$IFDEF FPC}
  SysUtils, Classes,
{$ELSE}
  System.SysUtils, System.Classes,
{$ENDIF}
  Utilities.Types, Utilities.Strings;

type
  TProviderTypeConverter = class
  private
    class function GetTipoVariavelFireBird: TTipoVariavel;
    class function GetTipoVariavelFireBird3: TTipoVariavel;
    class function GetTipoVariavelPostgreSQL: TTipoVariavel;
    class function GetTipoVariavelMySQL: TTipoVariavel;
    class function GetTipoVariavelMariaDB: TTipoVariavel;
    class function GetTipoVariavelSQLServer: TTipoVariavel;
    class function GetTipoVariavelSQLite: TTipoVariavel;
  public
    // Obter configuração de tipos de variáveis por provider
    class function GetTipoVariavel(AProvider: TDatabaseProvider): TTipoVariavel;
    
    // Converter tipo de dados para código numérico
    class function DataTypeToCode(const ADataType: String): Integer;
    
    // Verificar se tipo é numérico
    class function IsNumericType(const ADataType: String; AProvider: TDatabaseProvider): Boolean;
    
    // Verificar se tipo é caractere
    class function IsCharacterType(const ADataType: String; AProvider: TDatabaseProvider): Boolean;
    
    // Verificar se tipo é data/hora
    class function IsDateTimeType(const ADataType: String; AProvider: TDatabaseProvider): Boolean;
    
    // Verificar se tipo é booleano
    class function IsBooleanType(const ADataType: String; AProvider: TDatabaseProvider): Boolean;
    
    // Formatar valor para SQL baseado no tipo
    class function FormatValueForSQL(AProvider: TDatabaseProvider; const AValue: String; 
      const ADataType: String): String;
  end;

implementation

uses
{$IFDEF FPC}
  StrUtils;
{$ELSE}
  System.StrUtils;
{$ENDIF}

{ TProviderTypeConverter }

class function TProviderTypeConverter.GetTipoVariavel(AProvider: TDatabaseProvider): TTipoVariavel;
begin
  case AProvider of
    dpFireBird: Result := GetTipoVariavelFireBird;
    dpFireBird3: Result := GetTipoVariavelFireBird3;
    dpPostgreSQL: Result := GetTipoVariavelPostgreSQL;
    dpMySQL: Result := GetTipoVariavelMySQL;
    dpMariaDB: Result := GetTipoVariavelMariaDB;
    dpSQLServer: Result := GetTipoVariavelSQLServer;
    dpSQLite: Result := GetTipoVariavelSQLite;
  else
    Result := GetTipoVariavelPostgreSQL;
  end;
end;

class function TProviderTypeConverter.GetTipoVariavelFireBird: TTipoVariavel;
begin
  Result.Numerico := 'smallint,integer,bigint,decimal,numeric,float,double precision';
  Result.Caracter := 'char,varchar';
  Result.Hora := 'time';
  Result.Data := 'date';
  Result.DataHora := 'timestamp';
  Result.Booleano := ''; // Não possui tipo boolean nativo
end;

class function TProviderTypeConverter.GetTipoVariavelFireBird3: TTipoVariavel;
begin
  Result.Numerico := 'smallint,integer,bigint,decimal,numeric,float,double precision';
  Result.Caracter := 'char,varchar';
  Result.Hora := 'time';
  Result.Data := 'date';
  Result.DataHora := 'timestamp';
  Result.Booleano := 'boolean';
end;

class function TProviderTypeConverter.GetTipoVariavelPostgreSQL: TTipoVariavel;
begin
  Result.Numerico := 'smallint,integer,bigint,decimal,numeric,real,double precision,serial,bigserial,smallserial,money';
  Result.Caracter := 'char,varchar,text,name,citext,character varying';
  Result.Hora := 'time,timetz';
  Result.Data := 'date';
  Result.DataHora := 'timestamp,timestamptz,timestamp with time zone';
  Result.Booleano := 'boolean';
end;

class function TProviderTypeConverter.GetTipoVariavelMySQL: TTipoVariavel;
begin
  Result.Numerico := 'bit,tinyint,smallint,mediumint,int,bigint,decimal,numeric,float,double,real,serial';
  Result.Caracter := 'char,varchar,text,tinytext,mediumtext,longtext,binary,varbinary,enum,set';
  Result.Hora := 'time';
  Result.Data := 'date,year';
  Result.DataHora := 'datetime,timestamp';
  Result.Booleano := 'boolean';
end;

class function TProviderTypeConverter.GetTipoVariavelMariaDB: TTipoVariavel;
begin
  Result.Numerico := 'bit,tinyint,smallint,mediumint,int,bigint,decimal,numeric,float,double,real,serial';
  Result.Caracter := 'char,varchar,text,tinytext,mediumtext,longtext,binary,varbinary,enum,set';
  Result.Hora := 'time';
  Result.Data := 'date,year';
  Result.DataHora := 'datetime,timestamp';
  Result.Booleano := 'boolean';
end;

class function TProviderTypeConverter.GetTipoVariavelSQLServer: TTipoVariavel;
begin
  Result.Numerico := 'bit,tinyint,smallint,int,bigint,decimal,numeric,money,smallmoney,float,real';
  Result.Caracter := 'char,varchar,text,nchar,nvarchar,ntext,binary,varbinary,image,xml';
  Result.Hora := 'time';
  Result.Data := 'date';
  Result.DataHora := 'datetime,datetime2,smalldatetime,datetimeoffset';
  Result.Booleano := 'bool,boolean,bit';
end;

class function TProviderTypeConverter.GetTipoVariavelSQLite: TTipoVariavel;
begin
  Result.Numerico := 'integer,real,numeric';
  Result.Caracter := 'text';
  Result.Hora := 'text,real,integer';
  Result.Data := 'text,real,integer';
  Result.DataHora := 'text,real,integer';
  Result.Booleano := 'integer';
end;

class function TProviderTypeConverter.DataTypeToCode(const ADataType: String): Integer;
const
  FFieldsType = 'SMALLINT,INTEGER,INT,TINYINT,BIGINT,FLOAT,DOUBLE PRECISION,MONEY,SMALLMONEY,DATE,TIME,TIMESTAMP,DATETIME,CHAR,VARCHAR,BLOB,TEXT,SMALLDATETIME';
var
  Index: Integer;
begin
  Index := AnsiIndexStr(UpperCase(ADataType), FstrSplit(FFieldsType, ',', False));
  Result := Index;
end;

class function TProviderTypeConverter.IsNumericType(const ADataType: String; AProvider: TDatabaseProvider): Boolean;
var
  TipoVar: TTipoVariavel;
  TipoUpper: String;
begin
  TipoVar := GetTipoVariavel(AProvider);
  TipoUpper := UpperCase(ADataType);
  Result := Pos(TipoUpper, UpperCase(TipoVar.Numerico)) > 0;
end;

class function TProviderTypeConverter.IsCharacterType(const ADataType: String; AProvider: TDatabaseProvider): Boolean;
var
  TipoVar: TTipoVariavel;
  TipoUpper: String;
begin
  TipoVar := GetTipoVariavel(AProvider);
  TipoUpper := UpperCase(ADataType);
  Result := Pos(TipoUpper, UpperCase(TipoVar.Caracter)) > 0;
end;

class function TProviderTypeConverter.IsDateTimeType(const ADataType: String; AProvider: TDatabaseProvider): Boolean;
var
  TipoVar: TTipoVariavel;
  TipoUpper: String;
begin
  TipoVar := GetTipoVariavel(AProvider);
  TipoUpper := UpperCase(ADataType);
  Result := (Pos(TipoUpper, UpperCase(TipoVar.Data)) > 0) or
            (Pos(TipoUpper, UpperCase(TipoVar.DataHora)) > 0) or
            (Pos(TipoUpper, UpperCase(TipoVar.Hora)) > 0);
end;

class function TProviderTypeConverter.IsBooleanType(const ADataType: String; AProvider: TDatabaseProvider): Boolean;
var
  TipoVar: TTipoVariavel;
  TipoUpper: String;
begin
  TipoVar := GetTipoVariavel(AProvider);
  TipoUpper := UpperCase(ADataType);
  Result := (TipoVar.Booleano <> '') and (Pos(TipoUpper, UpperCase(TipoVar.Booleano)) > 0);
end;

class function TProviderTypeConverter.FormatValueForSQL(AProvider: TDatabaseProvider; 
  const AValue: String; const ADataType: String): String;
var
  TipoVar: TTipoVariavel;
  TipoIndex: Integer;
begin
  if AValue.IsEmpty then
  begin
    Result := 'NULL';
    Exit;
  end;
  
  TipoVar := GetTipoVariavel(AProvider);
  try
    TipoIndex := TipoVar.tipo(LowerCase(ADataType));
  except
    TipoIndex := -1;
  end;
  
  case TipoIndex of
    0: // Numérico
      Result := AValue;
    1: // Caractere
      Result := QuotedStr(AValue);
    2: // Hora
      Result := QuotedStr(AValue);
    3: // Data
      Result := QuotedStr(AValue);
    4: // DataHora
      Result := QuotedStr(AValue);
    5: // Booleano
      if IsBooleanType(ADataType, AProvider) then
        Result := AValue
      else
        Result := QuotedStr(AValue);
  else
    Result := QuotedStr(AValue);
  end;
end;

end.

