{ ==========================================================================
  PROVENANCE NOTE (ProvidersORM v3, FASE 10 Onda 10.2 - USE_PROVIDERS_V161):
  Absorbed VERBATIM from FontesReferencias/ProvidersORM.v1.6.1/Modulos/Providers.Module.CRUD.pas
  into this v3 tree as part of the USE_PROVIDERS_V161 compatibility subsystem
  (legacy ProvidersORM v1.6.1, mechanical port only - zero logic/behavior/
  symbol-name changes; see the unit's own original header below for the
  authorial history). Reachable via uses Providers.v161 - NOT part of the
  unified TProviders facade (Main/Providers.pas).

  MECHANICAL FIX: System.SysUtils, System.Classes, System.JSON, Data.DB
  (Delphi-scoped names) wrapped in an FPC conditional with the bare
  SysUtils/Classes/fpjson/DB names on the FPC branch and the System.*/
  Data.DB qualified names (System.JSON) on the Delphi branch - same
  project-wide pattern already used by the vendored
  Packages/Horse/dataset-serialize/src/DataSet.Serialize.pas for the exact
  same System.JSON to fpjson pairing. Safe here because TJSONArray is used
  only as an opaque field (Assigned/.Free in TCRUDResult.Clear) - no
  Delphi-only fluent members (AddPair/ParseJSONValue/...) are called in this
  file, so fpjson's TJSONArray is a behaviorally-equivalent substitute. No
  logic change. File re-saved as UTF-8 BOM.
  ========================================================================== }

{
  Providers.Module.CRUD - Módulo CRUD para Provider v1.6.0
  
  Responsabilidade:
    - Operações CRUD (Create, Read, Update, Delete)
    - Geração de SQL para operações CRUD
    - Validação de operações CRUD
    
  Compatibilidade: v1.5.0, v1.6.0
  Autor: Claiton de Souza Linhares
  Data: 27/01/2025
}
unit Providers.Module.CRUD;

interface

uses
{$IFDEF FPC}
  SysUtils, Classes, fpjson, DB,
{$ELSE}
  System.SysUtils, System.Classes, System.JSON, Data.DB,
{$ENDIF}
  Utilities.Types;

type
  TCRUDResult = record
    Success: Boolean;
    Message: String;
    Data: TJSONArray;
    procedure Clear;
  end;

  TProviderCRUDModule = class
  private
    class function BuildInsertSQL(AProvider: TDatabaseProvider; const ATable: String; 
      const AFields, AValues: TStringList): String;
    class function BuildUpdateSQL(AProvider: TDatabaseProvider; const ATable: String; 
      const AFields, AValues: TStringList; const AWhere: String): String;
    class function BuildDeleteSQL(AProvider: TDatabaseProvider; const ATable: String; 
      const AWhere: String; ASoftDelete: Boolean = True): String;
    class function BuildSelectSQL(AProvider: TDatabaseProvider; const ATable: String; 
      const AFields: String; const AWhere: String = ''; const AOrderBy: String = ''): String;
  public
    // Gerar SQL de INSERT
    class function GenerateInsertSQL(AProvider: TDatabaseProvider; const ATable: String; 
      AFields: TStringList; AValues: TStringList): String;
    
    // Gerar SQL de UPDATE
    class function GenerateUpdateSQL(AProvider: TDatabaseProvider; const ATable: String; 
      AFields: TStringList; AValues: TStringList; const APrimaryKey: String; 
      const APrimaryValue: String): String;
    
    // Gerar SQL de DELETE
    class function GenerateDeleteSQL(AProvider: TDatabaseProvider; const ATable: String; 
      const APrimaryKey: String; const APrimaryValue: String; 
      ASoftDelete: Boolean = True): String;
    
    // Gerar SQL de SELECT
    class function GenerateSelectSQL(AProvider: TDatabaseProvider; const ATable: String; 
      const AFields: String = '*'; const AWhere: String = ''; 
      const AOrderBy: String = ''): String;
    
    // Validar dados antes de INSERT
    class function ValidateInsertData(AFields: TStringList; AValues: TStringList): Boolean;
    
    // Validar dados antes de UPDATE
    class function ValidateUpdateData(AFields: TStringList; AValues: TStringList; 
      const APrimaryKey: String): Boolean;
  end;

implementation

uses
  Providers.Common.SQLBuilder, Providers.Common.TypeConverter;

{ TCRUDResult }

procedure TCRUDResult.Clear;
begin
  Success := False;
  Message := '';
  if Assigned(Data) then
    Data.Free;
  Data := nil;
end;

{ TProviderCRUDModule }

class function TProviderCRUDModule.BuildInsertSQL(AProvider: TDatabaseProvider; 
  const ATable: String; const AFields, AValues: TStringList): String;
var
  i: Integer;
  FieldsStr, ValuesStr: String;
begin
  FieldsStr := '';
  ValuesStr := '';
  
  for i := 0 to AFields.Count - 1 do
  begin
    if i > 0 then
    begin
      FieldsStr := FieldsStr + ', ';
      ValuesStr := ValuesStr + ', ';
    end;
    
    FieldsStr := FieldsStr + AFields[i];
    ValuesStr := ValuesStr + AValues[i];
  end;
  
  Result := Format('INSERT INTO %s (%s) VALUES (%s)', [ATable, FieldsStr, ValuesStr]);
end;

class function TProviderCRUDModule.BuildUpdateSQL(AProvider: TDatabaseProvider; 
  const ATable: String; const AFields, AValues: TStringList; const AWhere: String): String;
var
  i: Integer;
  SetClause: String;
begin
  SetClause := '';
  
  for i := 0 to AFields.Count - 1 do
  begin
    if i > 0 then
      SetClause := SetClause + ', ';
    SetClause := SetClause + Format('%s = %s', [AFields[i], AValues[i]]);
  end;
  
  Result := Format('UPDATE %s SET %s WHERE %s', [ATable, SetClause, AWhere]);
end;

class function TProviderCRUDModule.BuildDeleteSQL(AProvider: TDatabaseProvider; 
  const ATable: String; const AWhere: String; ASoftDelete: Boolean): String;
begin
  if ASoftDelete then
    Result := Format('UPDATE %s SET DELETED = 1 WHERE %s', [ATable, AWhere])
  else
    Result := Format('DELETE FROM %s WHERE %s', [ATable, AWhere]);
end;

class function TProviderCRUDModule.BuildSelectSQL(AProvider: TDatabaseProvider; 
  const ATable: String; const AFields: String; const AWhere: String; 
  const AOrderBy: String): String;
begin
  Result := Format('SELECT %s FROM %s', [AFields, ATable]);
  
  if not AWhere.IsEmpty then
    Result := Result + ' WHERE ' + AWhere;
    
  if not AOrderBy.IsEmpty then
    Result := Result + ' ORDER BY ' + AOrderBy;
end;

class function TProviderCRUDModule.GenerateInsertSQL(AProvider: TDatabaseProvider; 
  const ATable: String; AFields: TStringList; AValues: TStringList): String;
begin
  Result := BuildInsertSQL(AProvider, ATable, AFields, AValues);
end;

class function TProviderCRUDModule.GenerateUpdateSQL(AProvider: TDatabaseProvider; 
  const ATable: String; AFields: TStringList; AValues: TStringList; 
  const APrimaryKey: String; const APrimaryValue: String): String;
var
  WhereClause: String;
begin
  WhereClause := Format('%s = %s', [APrimaryKey, APrimaryValue]);
  Result := BuildUpdateSQL(AProvider, ATable, AFields, AValues, WhereClause);
end;

class function TProviderCRUDModule.GenerateDeleteSQL(AProvider: TDatabaseProvider; 
  const ATable: String; const APrimaryKey: String; const APrimaryValue: String; 
  ASoftDelete: Boolean): String;
var
  WhereClause: String;
begin
  WhereClause := Format('%s = %s', [APrimaryKey, APrimaryValue]);
  Result := BuildDeleteSQL(AProvider, ATable, WhereClause, ASoftDelete);
end;

class function TProviderCRUDModule.GenerateSelectSQL(AProvider: TDatabaseProvider; 
  const ATable: String; const AFields: String; const AWhere: String; 
  const AOrderBy: String): String;
begin
  Result := BuildSelectSQL(AProvider, ATable, AFields, AWhere, AOrderBy);
end;

class function TProviderCRUDModule.ValidateInsertData(AFields: TStringList; 
  AValues: TStringList): Boolean;
begin
  Result := (Assigned(AFields)) and (Assigned(AValues)) and 
             (AFields.Count = AValues.Count) and (AFields.Count > 0);
end;

class function TProviderCRUDModule.ValidateUpdateData(AFields: TStringList; 
  AValues: TStringList; const APrimaryKey: String): Boolean;
begin
  Result := ValidateInsertData(AFields, AValues) and (not APrimaryKey.IsEmpty);
end;

end.

