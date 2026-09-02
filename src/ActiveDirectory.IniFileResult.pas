{ =============================================================================
  ActiveDirectory.IniFileResult - ILDAPSearchResult sobre TCustomIniFile

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.8.0 (ActiveDirectory absorvido do SSOT v1.7.6)
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           06/07/2026

  Fornece TActiveDirectoryIniFileResult — implementação de ILDAPSearchResult que lê
  dados de uma SECÇÃO de um TCustomIniFile (TIniFile / TMemIniFile). Uma entrada
  LDAP = uma secção; atributos = key=value. Modelado em ActiveDirectory.JsonResult
  (mesma interface, mesma decodificação de SID/GUID).

  Estrutura INI esperada (secção = uma entrada):
    [<seccao>]
    dn=CN=...                       (ou distinguishedName=)
    sAMAccountName=...
    mail=...
    memberOf=CN=G1,...|CN=G2,...    (multivalorado, separado por '|')
    objectGUID=<base64 de 16 bytes>
    objectSid=<base64 binario  ou  S-1-5-21-...>
    pwdLastSet=<Int64 decimal>

  Campos multivalorados usam o separador '|' (pipe) porque valores LDAP (DNs)
  contêm vírgulas. Campos binários: base64. Campos FILETIME: string Int64.

  Changelog (file):
  - 1.0.0 (06/07/2026): versão inicial — TActiveDirectoryIniFileResult implementa
    ILDAPSearchResult lendo de uma secção de TCustomIniFile; multivalorados por '|';
    objectSid/objectGUID decodificados de base64 (mesma lógica do JsonResult).
  ============================================================================= }

unit ActiveDirectory.IniFileResult;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../ORM.Defines.inc}

uses
  ActiveDirectory.Main.Interfaces,
{$IFDEF FPC}
  SysUtils, Classes, IniFiles, base64;
{$ELSE}
  System.SysUtils, System.Classes, System.IniFiles, System.NetEncoding;
{$ENDIF}

const
  { Separador de valores multivalorados numa key INI (pipe; DNs têm vírgulas). }
  INI_RESULT_LIST_SEP = '|';

type

  // ===========================================================================
  // TActiveDirectoryIniFileResult
  // ===========================================================================

  (** Implementação de ILDAPSearchResult sobre uma secção de um TCustomIniFile.
      Não assume posse do ini — o chamador é responsável pelo ciclo de vida.

      Uso:
        LIni    := TMemIniFile.Create('entry.ini');
        LResult := TActiveDirectoryIniFileResult.Create(LIni, 'user1');
        LUser   := TActiveDirectoryMapper<TAdUser>.FromSearchResult(LResult); *)
  TActiveDirectoryIniFileResult = class(TInterfacedObject, ILDAPSearchResult)
  private
    FIni: TCustomIniFile;
    FSection: string;
    function RawValue(const AName: string): string;
    function DecodeBase64Bytes(const ABase64: string): TBytes;
    function DecodeSidBytes(const ABytes: TBytes): string;
  public
    (** Recebe referência ao ini e a secção da entrada — não assume posse. *)
    constructor Create(AIni: TCustomIniFile; const ASection: string);

    function DN: string;
    function Attribute(const AName: string): string;
    function AttributeList(const AName: string): TArray<string>;
    function AttributeGuid(const AName: string): TGuid;
    function AttributeFileTime(const AName: string): Int64;
    function AttributeSid(const AName: string): string;
  end;

implementation

{ TActiveDirectoryIniFileResult — helpers privados }

function TActiveDirectoryIniFileResult.RawValue(const AName: string): string;
begin
  if FIni = nil then
    Result := ''
  else
    Result := FIni.ReadString(FSection, AName, '');
end;

function TActiveDirectoryIniFileResult.DecodeBase64Bytes(const ABase64: string): TBytes;
begin
{$IFDEF FPC}
  Result := BytesOf(DecodeStringBase64(ABase64, True));
{$ELSE}
  Result := TNetEncoding.Base64.DecodeStringToBytes(ABase64);
{$ENDIF}
end;

function TActiveDirectoryIniFileResult.DecodeSidBytes(const ABytes: TBytes): string;
var
  LRev, LCnt: Byte;
  LAuth: Int64;
  I: Integer;
  LSub: LongWord;
begin
  Result := '';
  if Length(ABytes) < 8 then Exit;
  LRev  := ABytes[0];
  LCnt  := ABytes[1];
  LAuth := 0;
  for I := 2 to 7 do
    LAuth := (LAuth shl 8) or ABytes[I];
  Result := Format('S-%d-%d', [LRev, LAuth]);
  if Length(ABytes) < 8 + LCnt * 4 then Exit;
  for I := 0 to LCnt - 1 do
  begin
    LSub := ABytes[8 + I * 4]
          or (ABytes[9  + I * 4] shl 8)
          or (ABytes[10 + I * 4] shl 16)
          or (ABytes[11 + I * 4] shl 24);
    Result := Result + '-' + IntToStr(LSub);
  end;
end;

{ TActiveDirectoryIniFileResult — constructor }

constructor TActiveDirectoryIniFileResult.Create(AIni: TCustomIniFile; const ASection: string);
begin
  inherited Create;
  FIni := AIni;
  FSection := ASection;
end;

{ TActiveDirectoryIniFileResult — públicos }

function TActiveDirectoryIniFileResult.DN: string;
begin
  Result := RawValue('dn');
  if Result = '' then
    Result := RawValue('distinguishedName');
end;

function TActiveDirectoryIniFileResult.Attribute(const AName: string): string;
begin
  Result := RawValue(AName);
end;

function TActiveDirectoryIniFileResult.AttributeList(const AName: string): TArray<string>;
var
  LRaw, LItem: string;
  I, LCount: Integer;
  LTmp: TArray<string>;
begin
  SetLength(Result, 0);
  LRaw := RawValue(AName);
  if LRaw = '' then Exit;
  { split manual por '|' (cross-compiler; nao usa DelimitedText por causa de aspas/DNs). }
  SetLength(LTmp, Length(LRaw) + 1);
  LCount := 0;
  LItem := '';
  for I := 1 to Length(LRaw) do
  begin
    if LRaw[I] = INI_RESULT_LIST_SEP then
    begin
      LTmp[LCount] := LItem;
      Inc(LCount);
      LItem := '';
    end
    else
      LItem := LItem + LRaw[I];
  end;
  LTmp[LCount] := LItem;   // ultimo elemento
  Inc(LCount);
  SetLength(Result, LCount);
  for I := 0 to LCount - 1 do
    Result[I] := LTmp[I];
end;

function TActiveDirectoryIniFileResult.AttributeGuid(const AName: string): TGuid;
var
  LB64:   string;
  LBytes: TBytes;
begin
  FillChar(Result, SizeOf(Result), 0);
  LB64 := RawValue(AName);
  if LB64 = '' then Exit;
  LBytes := DecodeBase64Bytes(LB64);
  if Length(LBytes) = SizeOf(TGuid) then
    Move(LBytes[0], Result, SizeOf(TGuid));
end;

function TActiveDirectoryIniFileResult.AttributeFileTime(const AName: string): Int64;
begin
  Result := StrToInt64Def(RawValue(AName), 0);
end;

function TActiveDirectoryIniFileResult.AttributeSid(const AName: string): string;
var
  LRaw:   string;
  LBytes: TBytes;
begin
  Result := '';
  LRaw := RawValue(AName);
  if LRaw = '' then Exit;
  { Tenta base64 (formato binario do AD); senao trata como string 'S-...'. }
  try
    LBytes := DecodeBase64Bytes(LRaw);
    if Length(LBytes) >= 8 then
    begin
      Result := DecodeSidBytes(LBytes);
      Exit;
    end;
  except
    // nao e base64 — string direta
  end;
  if Copy(LRaw, 1, 2) = 'S-' then
    Result := LRaw;
end;

end.
