{ ==========================================================================
  PROVENANCE NOTE (ProvidersORM v3, FASE 10 Onda 10.2 - USE_PROVIDERS_V161):
  Absorbed VERBATIM from FontesReferencias/ProvidersORM.v1.6.1/Commons/Providers.Common.FieldHelper.pas
  into this v3 tree as part of the USE_PROVIDERS_V161 compatibility subsystem
  (legacy ProvidersORM v1.6.1, mechanical port only - zero logic/behavior/
  symbol-name changes; see the unit's own original header below for the
  authorial history). Reachable via uses Providers.v161 - NOT part of the
  unified TProviders facade (Main/Providers.pas).

  MECHANICAL FIX: uses System.SysUtils, System.Classes, Data.DB (Delphi-
  scoped names, unresolvable under FPC in this toolchain) wrapped in an FPC
  conditional with the bare SysUtils/Classes/DB names on the FPC branch and
  the System.*/Data.DB qualified names on the Delphi branch - same units,
  same symbols, no logic change (matches this project's own convention,
  e.g. Modulos/Connections/Connections.pas). File re-saved as UTF-8 BOM.
  ========================================================================== }

{
  Providers.Common.FieldHelper - Helpers de Campos para Provider v1.6.0
  
  Responsabilidade:
    - Manipulação de campos
    - Validação de campos
    - Formatação de valores de campos
    
  Compatibilidade: v1.5.0, v1.6.0
  Autor: Claiton de Souza Linhares
  Data: 27/01/2025
}
unit Providers.Common.FieldHelper;

interface

uses
{$IFDEF FPC}
  SysUtils, Classes, DB,
{$ELSE}
  System.SysUtils, System.Classes, Data.DB,
{$ENDIF}
  Utilities.Types;

type
  TProviderFieldHelper = class
  public
    // Verificar se campo é primary key
    class function IsPrimaryKey(ADataSet: TDataSet; const AFieldName: String): Boolean;
    
    // Obter valor formatado do campo
    class function GetFormattedValue(ADataSet: TDataSet; const AFieldName: String): String;
    
    // Verificar se campo foi alterado
    class function IsFieldChanged(ADataSet: TDataSet; const AFieldName: String): Boolean;
    
    // Obter tipo de dados do campo
    class function GetFieldDataType(ADataSet: TDataSet; const AFieldName: String): String;
    
    // Verificar se campo pode ser nulo
    class function IsFieldNullable(ADataSet: TDataSet; const AFieldName: String): Boolean;
    
    // Formatar ID com zeros à esquerda
    class function FormatID(const AID: String; ALength: Integer = 6): String;
    
    // Validar valor do campo baseado no tipo
    class function ValidateFieldValue(const AValue: String; const ADataType: String; 
      AProvider: TDatabaseProvider): Boolean;
  end;

implementation

uses
  Providers.Common.TypeConverter;

{ TProviderFieldHelper }

class function TProviderFieldHelper.IsPrimaryKey(ADataSet: TDataSet; const AFieldName: String): Boolean;
begin
  Result := False;
  if not Assigned(ADataSet) then
    Exit;
    
  if not Assigned(ADataSet.FindField('PKey')) then
    Exit;
    
  try
    ADataSet.Filter := Format('column_name = %s', [QuotedStr(AFieldName)]);
    ADataSet.Filtered := True;
    Result := (not ADataSet.IsEmpty) and (ADataSet.FieldByName('PKey').AsInteger = 1);
    ADataSet.Filtered := False;
  except
    Result := False;
  end;
end;

class function TProviderFieldHelper.GetFormattedValue(ADataSet: TDataSet; const AFieldName: String): String;
begin
  Result := '';
  if not Assigned(ADataSet) then
    Exit;
    
  if not Assigned(ADataSet.FindField(AFieldName)) then
    Exit;
    
  Result := ADataSet.FieldByName(AFieldName).AsString;
end;

class function TProviderFieldHelper.IsFieldChanged(ADataSet: TDataSet; const AFieldName: String): Boolean;
begin
  Result := False;
  if not Assigned(ADataSet) then
    Exit;
    
  if not Assigned(ADataSet.FindField('changed')) then
    Exit;
    
  try
    ADataSet.Filter := Format('column_name = %s', [QuotedStr(AFieldName)]);
    ADataSet.Filtered := True;
    Result := (not ADataSet.IsEmpty) and (ADataSet.FieldByName('changed').AsInteger = 1);
    ADataSet.Filtered := False;
  except
    Result := False;
  end;
end;

class function TProviderFieldHelper.GetFieldDataType(ADataSet: TDataSet; const AFieldName: String): String;
begin
  Result := '';
  if not Assigned(ADataSet) then
    Exit;
    
  if not Assigned(ADataSet.FindField('data_type')) then
    Exit;
    
  try
    ADataSet.Filter := Format('column_name = %s', [QuotedStr(AFieldName)]);
    ADataSet.Filtered := True;
    if not ADataSet.IsEmpty then
      Result := ADataSet.FieldByName('data_type').AsString;
    ADataSet.Filtered := False;
  except
    Result := '';
  end;
end;

class function TProviderFieldHelper.IsFieldNullable(ADataSet: TDataSet; const AFieldName: String): Boolean;
begin
  Result := True;
  if not Assigned(ADataSet) then
    Exit;
    
  if not Assigned(ADataSet.FindField('is_nullable')) then
    Exit;
    
  try
    ADataSet.Filter := Format('column_name = %s', [QuotedStr(AFieldName)]);
    ADataSet.Filtered := True;
    if not ADataSet.IsEmpty then
      Result := UpperCase(ADataSet.FieldByName('is_nullable').AsString) = 'YES';
    ADataSet.Filtered := False;
  except
    Result := True;
  end;
end;

class function TProviderFieldHelper.FormatID(const AID: String; ALength: Integer): String;
var
  IDInt: Integer;
begin
  try
    IDInt := StrToIntDef(AID, 0);
    Result := Format('%.*d', [ALength, IDInt]);
  except
    Result := AID;
  end;
end;

class function TProviderFieldHelper.ValidateFieldValue(const AValue: String; 
  const ADataType: String; AProvider: TDatabaseProvider): Boolean;
var
  TipoUpper: String;
begin
  Result := True;
  
  if AValue.IsEmpty then
    Exit;
    
  TipoUpper := UpperCase(ADataType);
  
  // Validar tipos numéricos
  if TProviderTypeConverter.IsNumericType(ADataType, AProvider) then
  begin
    try
      StrToFloat(AValue);
      Result := True;
    except
      Result := False;
    end;
  end
  // Validar tipos de data/hora
  else if TProviderTypeConverter.IsDateTimeType(ADataType, AProvider) then
  begin
    try
      StrToDateTime(AValue);
      Result := True;
    except
      try
        StrToDate(AValue);
        Result := True;
      except
        Result := False;
      end;
    end;
  end;
end;

end.

