{ =============================================================================
  ActiveDirectory.Helpers - Helpers para filtros LDAP, DN e listas de atributos

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.8.0 (ActiveDirectory absorvido do SSOT v1.7.6)
  FileVersion:    1.1.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           24/04/2026

  Changelog (file):
  - 1.0.0 (07/03/2026): TActiveDirectoryHelper; conversão do Exemplo para núcleo.
  - 1.0.1 (07/03/2026): Uses Attributers.ActiveDirectory para constantes LDAP_ATTR_* e LDAP_OBJECTCLASS_*.
  - 1.1.0 (21/04/2026): AddDefaultAttributesForDetailedSearch passa a incluir
                        whenCreated e whenChanged (paridade final com
                        Version.Old/ListContainerObjectsDetailed — gap #1 do
                        plano V1.6.0 master).
  ============================================================================= }

unit ActiveDirectory.Helpers;

interface

uses
{$IFDEF FPC}
  SysUtils, Classes, StrUtils,
{$ELSE}
  System.SysUtils, System.Classes, System.StrUtils,
{$ENDIF}
  Commons.ActiveDirectory.Types,
  Commons.ActiveDirectory.Consts,
  Attributers.ActiveDirectory;

type
  TActiveDirectoryHelper = class
  public
    class function BuildUserSearchFilter(const AUsername: string): string;
    class function GetCommonName(const ADN: string): string;
    class function FormatObjectInfo(const ADN: string; const AAttributes: TStringList): string;
    class function EscapeFilterValue(const AValue: string): string;
    class function BuildFilter(const AAttributeName, AAttributeValue: string): string;
    class function BuildFilterWithObjectClass(const AAttr, AVal, AObjectClass: string): string;
    class function BuildFilterMultiple(const AAttributes, AValues: array of string): string;
    class function BuildFilterMultipleObjectTypes(const AObjectTypes: array of string): string;
    class function GetAttributeValueFromList(const AAttributes: TStringList; const AAttributeName: string): string;
    class function GetObjectClassFromAttributes(const AAttributes: TStringList): string;
    class function GetAttributeFromDN(const ADN, AAttributeName: string): string;
    class procedure AddDefaultAttributesForSearch(const AList: TStringList);
    class procedure AddDefaultAttributesForDetailedSearch(const AList: TStringList);
    class procedure AddDefaultAttributesForGroup(const AList: TStringList);
    class procedure AddDefaultAttributesForUserSearch(const AList: TStringList);
    class procedure AddDefaultAttributesForOU(const AList: TStringList);
  end;

implementation

{ TActiveDirectoryHelper }

class function TActiveDirectoryHelper.BuildUserSearchFilter(const AUsername: string): string;
var
  LEsc: string;
begin
  LEsc := EscapeFilterValue(AUsername);
  Result := '(&(|(objectClass=' + LDAP_OBJECTCLASS_PERSON + ')(objectClass=' + LDAP_OBJECTCLASS_USER + '))' +
    '(|(cn=' + LEsc + ')(' + LDAP_ATTR_DISTINGUISHEDNAME + '=' + LEsc + ')(' + LDAP_ATTR_SAMACCOUNTNAME + '=' + LEsc + ')' +
    '(' + LDAP_ATTR_USERPRINCIPALNAME + '=' + LEsc + ')))';
end;

class function TActiveDirectoryHelper.GetCommonName(const ADN: string): string;
var
  StartPos, EndPos: Integer;
  LUpper: string;
begin
  Result := ADN;
  LUpper := UpperCase(ADN);
  StartPos := Pos('CN=', LUpper);
  if StartPos > 0 then
  begin
    StartPos := StartPos + 3;
    EndPos := PosEx(',', ADN, StartPos);
    if EndPos > 0 then
      Result := Copy(ADN, StartPos, EndPos - StartPos)
    else
      Result := Copy(ADN, StartPos, MaxInt);
  end;
end;

class function TActiveDirectoryHelper.FormatObjectInfo(const ADN: string; const AAttributes: TStringList): string;
var
  LCN, LObjClass: string;
begin
  LCN := GetCommonName(ADN);
  LObjClass := GetObjectClassFromAttributes(AAttributes);
  if LObjClass = '' then
    LObjClass := 'unknown';
  Result := Format('[%s] %s (%s)', [LObjClass, LCN, ADN]);
end;

class function TActiveDirectoryHelper.EscapeFilterValue(const AValue: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(AValue) do
  begin
    C := AValue[I];
    case C of
      '\', '*', '(', ')', #0: Result := Result + '\' + Char(Ord(C) and $FF);
      else Result := Result + C;
    end;
  end;
end;

class function TActiveDirectoryHelper.BuildFilter(const AAttributeName, AAttributeValue: string): string;
begin
  Result := '(' + AAttributeName + '=' + EscapeFilterValue(AAttributeValue) + ')';
end;

class function TActiveDirectoryHelper.BuildFilterWithObjectClass(const AAttr, AVal, AObjectClass: string): string;
begin
  Result := '(&(objectClass=' + EscapeFilterValue(AObjectClass) + ')' + BuildFilter(AAttr, AVal) + ')';
end;

class function TActiveDirectoryHelper.BuildFilterMultiple(const AAttributes, AValues: array of string): string;
var
  I: Integer;
begin
  if Length(AAttributes) <> Length(AValues) then
    Exit('');
  Result := '(&';
  for I := Low(AAttributes) to High(AAttributes) do
    Result := Result + BuildFilter(AAttributes[I], AValues[I]);
  Result := Result + ')';
end;

class function TActiveDirectoryHelper.BuildFilterMultipleObjectTypes(const AObjectTypes: array of string): string;
var
  I: Integer;
begin
  if Length(AObjectTypes) = 0 then
    Exit('');
  Result := '(|';
  for I := Low(AObjectTypes) to High(AObjectTypes) do
    Result := Result + '(objectClass=' + EscapeFilterValue(AObjectTypes[I]) + ')';
  Result := Result + ')';
end;

class function TActiveDirectoryHelper.GetAttributeValueFromList(const AAttributes: TStringList; const AAttributeName: string): string;
var
  I, P: Integer;
  LLine, LName: string;
begin
  Result := '';
  if AAttributes = nil then
    Exit;
  for I := 0 to AAttributes.Count - 1 do
  begin
    LLine := AAttributes[I];
    P := Pos('=', LLine);
    if P > 0 then
    begin
      LName := Trim(Copy(LLine, 1, P - 1));
      if SameText(LName, AAttributeName) then
      begin
        Result := Trim(Copy(LLine, P + 1, MaxInt));
        Exit;
      end;
    end;
  end;
end;

class function TActiveDirectoryHelper.GetObjectClassFromAttributes(const AAttributes: TStringList): string;
begin
  Result := GetAttributeValueFromList(AAttributes, LDAP_ATTR_OBJECTCLASS);
end;

class function TActiveDirectoryHelper.GetAttributeFromDN(const ADN, AAttributeName: string): string;
var
  LAttrUpper, LPart: string;
  S, P, Q: Integer;
begin
  Result := '';
  LAttrUpper := UpperCase(AAttributeName) + '=';
  S := 1;
  while S <= Length(ADN) do
  begin
    if (S = 1) or (ADN[S - 1] = ',') then
    begin
      if SameText(Copy(ADN, S, Length(LAttrUpper)), LAttrUpper) then
      begin
        P := S + Length(LAttrUpper);
        Q := P;
        while Q <= Length(ADN) do
        begin
          if ADN[Q] = ',' then
            Break;
          if ADN[Q] = '\' then
            Inc(Q);
          Inc(Q);
        end;
        Result := Copy(ADN, P, Q - P);
        Exit;
      end;
    end;
    Inc(S);
  end;
end;

class procedure TActiveDirectoryHelper.AddDefaultAttributesForSearch(const AList: TStringList);
begin
  if AList = nil then Exit;
  AList.Add(LDAP_ATTR_DISTINGUISHEDNAME);
  AList.Add(LDAP_ATTR_OBJECTCLASS);
  AList.Add(LDAP_ATTR_CN);
end;

class procedure TActiveDirectoryHelper.AddDefaultAttributesForDetailedSearch(const AList: TStringList);
begin
  if AList = nil then Exit;
  AddDefaultAttributesForSearch(AList);
  AList.Add(LDAP_ATTR_NAME);
  AList.Add(LDAP_ATTR_SAMACCOUNTNAME);
  AList.Add(LDAP_ATTR_USERPRINCIPALNAME);
  AList.Add(LDAP_ATTR_DESCRIPTION);
  AList.Add(LDAP_ATTR_WHENCREATED);
  AList.Add(LDAP_ATTR_WHENCHANGED);
end;

class procedure TActiveDirectoryHelper.AddDefaultAttributesForGroup(const AList: TStringList);
begin
  if AList = nil then Exit;
  AList.Add(LDAP_ATTR_CN);
  AList.Add(LDAP_ATTR_DISTINGUISHEDNAME);
  AList.Add(LDAP_ATTR_MEMBER);
  AList.Add(LDAP_ATTR_OBJECTCLASS);
end;

class procedure TActiveDirectoryHelper.AddDefaultAttributesForUserSearch(const AList: TStringList);
begin
  if AList = nil then Exit;
  AList.Add(LDAP_ATTR_CN);
  AList.Add(LDAP_ATTR_SAMACCOUNTNAME);
  AList.Add(LDAP_ATTR_USERPRINCIPALNAME);
  AList.Add(LDAP_ATTR_DISTINGUISHEDNAME);
  AList.Add(LDAP_ATTR_OBJECTCLASS);
end;

class procedure TActiveDirectoryHelper.AddDefaultAttributesForOU(const AList: TStringList);
begin
  if AList = nil then Exit;
  AList.Add(LDAP_ATTR_CN);
  AList.Add(LDAP_ATTR_DISTINGUISHEDNAME);
  AList.Add(LDAP_ATTR_OBJECTCLASS);
  AList.Add(LDAP_ATTR_DESCRIPTION);
end;

end.
