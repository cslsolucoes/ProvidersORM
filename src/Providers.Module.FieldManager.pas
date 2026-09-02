{ ==========================================================================
  PROVENANCE NOTE (ProvidersORM v3, FASE 10 Onda 10.2 - USE_PROVIDERS_V161):
  Absorbed VERBATIM from FontesReferencias/ProvidersORM.v1.6.1/Modulos/Providers.Module.FieldManager.pas
  into this v3 tree as part of the USE_PROVIDERS_V161 compatibility subsystem
  (legacy ProvidersORM v1.6.1, mechanical port only - zero logic/behavior/
  symbol-name changes; see the unit's own original header below for the
  authorial history). Reachable via uses Providers.v161 - NOT part of the
  unified TProviders facade (Main/Providers.pas).

  MECHANICAL FIX: uses System.SysUtils, System.Classes, Data.DB (Delphi-
  scoped names, unresolvable under FPC in this toolchain) wrapped in an FPC
  conditional with the bare SysUtils/Classes/DB names on the FPC branch and
  the System.*/Data.DB qualified names on the Delphi branch - same units,
  same symbols, no logic change. File re-saved as UTF-8 BOM.
  ========================================================================== }

{
  Providers.Module.FieldManager - Módulo de Gerenciamento de Campos para Provider v1.6.0
  
  Responsabilidade:
    - Gerenciamento de campos de tabela
    - Validação de campos
    - Manipulação de valores de campos
    
  Compatibilidade: v1.5.0, v1.6.0
  Autor: Claiton de Souza Linhares
  Data: 27/01/2025
}
unit Providers.Module.FieldManager;

interface

uses
{$IFDEF FPC}
  SysUtils, Classes, DB,
{$ELSE}
  System.SysUtils, System.Classes, Data.DB,
{$ENDIF}
  Utilities.Types;

type
  TFieldInfo = record
    ColumnName: String;
    DataType: String;
    IsNullable: Boolean;
    IsPrimaryKey: Boolean;
    DefaultValue: String;
    Position: Integer;
    procedure Clear;
  end;

  TProviderFieldManager = class
  private
    class function ParseFieldInfo(ADataSet: TDataSet): TFieldInfo;
  public
    // Obter informações de um campo
    class function GetFieldInfo(ADataSet: TDataSet; const AFieldName: String): TFieldInfo;
    
    // Listar todos os campos de uma tabela
    class function GetFieldsList(ADataSet: TDataSet): TStringList;
    
    // Obter campos que são primary keys
    class function GetPrimaryKeyFields(ADataSet: TDataSet): TStringList;
    
    // Obter campos excluídos (DELETED, DATA_CADASTRO, etc)
    class function GetExcludedFields: TStringList;
    
    // Verificar se campo deve ser excluído
    class function ShouldExcludeField(const AFieldName: String): Boolean;
    
    // Filtrar campos por tipo
    class function FilterFieldsByType(ADataSet: TDataSet; const ADataType: String): TStringList;
    
    // Validar campo obrigatório
    class function ValidateRequiredField(const AValue: String; AIsNullable: Boolean): Boolean;
  end;

implementation

uses
  Providers.Common.FieldHelper;

{ TFieldInfo }

procedure TFieldInfo.Clear;
begin
  ColumnName := '';
  DataType := '';
  IsNullable := True;
  IsPrimaryKey := False;
  DefaultValue := '';
  Position := 0;
end;

{ TProviderFieldManager }

class function TProviderFieldManager.ParseFieldInfo(ADataSet: TDataSet): TFieldInfo;
begin
  Result.Clear;
  
  if not Assigned(ADataSet) or ADataSet.IsEmpty then
    Exit;
    
  if Assigned(ADataSet.FindField('column_name')) then
    Result.ColumnName := ADataSet.FieldByName('column_name').AsString;
    
  if Assigned(ADataSet.FindField('data_type')) then
    Result.DataType := ADataSet.FieldByName('data_type').AsString;
    
  if Assigned(ADataSet.FindField('is_nullable')) then
    Result.IsNullable := UpperCase(ADataSet.FieldByName('is_nullable').AsString) = 'YES';
    
  if Assigned(ADataSet.FindField('PKey')) then
    Result.IsPrimaryKey := ADataSet.FieldByName('PKey').AsInteger = 1;
    
  if Assigned(ADataSet.FindField('column_default')) then
    Result.DefaultValue := ADataSet.FieldByName('column_default').AsString;
    
  if Assigned(ADataSet.FindField('position')) then
    Result.Position := ADataSet.FieldByName('position').AsInteger;
end;

class function TProviderFieldManager.GetFieldInfo(ADataSet: TDataSet; const AFieldName: String): TFieldInfo;
begin
  Result.Clear;
  
  if not Assigned(ADataSet) then
    Exit;
    
  try
    ADataSet.Filter := Format('column_name = %s', [QuotedStr(AFieldName)]);
    ADataSet.Filtered := True;
    
    if not ADataSet.IsEmpty then
      Result := ParseFieldInfo(ADataSet);
      
    ADataSet.Filtered := False;
  except
    Result.Clear;
  end;
end;

class function TProviderFieldManager.GetFieldsList(ADataSet: TDataSet): TStringList;
begin
  Result := TStringList.Create;
  
  if not Assigned(ADataSet) then
    Exit;
    
  try
    ADataSet.First;
    while not ADataSet.Eof do
    begin
      if Assigned(ADataSet.FindField('column_name')) then
        Result.Add(ADataSet.FieldByName('column_name').AsString);
      ADataSet.Next;
    end;
  except
    // Ignorar erros
  end;
end;

class function TProviderFieldManager.GetPrimaryKeyFields(ADataSet: TDataSet): TStringList;
begin
  Result := TStringList.Create;
  
  if not Assigned(ADataSet) then
    Exit;
    
  try
    ADataSet.Filter := 'PKey = 1';
    ADataSet.Filtered := True;
    ADataSet.First;
    
    while not ADataSet.Eof do
    begin
      if Assigned(ADataSet.FindField('column_name')) then
        Result.Add(ADataSet.FieldByName('column_name').AsString);
      ADataSet.Next;
    end;
    
    ADataSet.Filtered := False;
  except
    // Ignorar erros
  end;
end;

class function TProviderFieldManager.GetExcludedFields: TStringList;
begin
  Result := TStringList.Create;
  Result.Add('DELETED');
  Result.Add('DATA_CADASTRO');
  Result.Add('DATA_ALTERACAO');
end;

class function TProviderFieldManager.ShouldExcludeField(const AFieldName: String): Boolean;
var
  ExcludedFields: TStringList;
begin
  Result := False;
  ExcludedFields := GetExcludedFields;
  try
    Result := ExcludedFields.IndexOf(AFieldName) >= 0;
  finally
    ExcludedFields.Free;
  end;
end;

class function TProviderFieldManager.FilterFieldsByType(ADataSet: TDataSet; 
  const ADataType: String): TStringList;
begin
  Result := TStringList.Create;
  
  if not Assigned(ADataSet) then
    Exit;
    
  try
    ADataSet.Filter := Format('data_type = %s', [QuotedStr(ADataType)]);
    ADataSet.Filtered := True;
    ADataSet.First;
    
    while not ADataSet.Eof do
    begin
      if Assigned(ADataSet.FindField('column_name')) then
        Result.Add(ADataSet.FieldByName('column_name').AsString);
      ADataSet.Next;
    end;
    
    ADataSet.Filtered := False;
  except
    // Ignorar erros
  end;
end;

class function TProviderFieldManager.ValidateRequiredField(const AValue: String; 
  AIsNullable: Boolean): Boolean;
begin
  if AIsNullable then
    Result := True
  else
    Result := not AValue.IsEmpty;
end;

end.

