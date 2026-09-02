{ =============================================================================
  ActiveDirectory.JsonResult - ILDAPSearchResult sobre TJSONObject

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.8.0 (ActiveDirectory absorvido do SSOT v1.7.6)
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           24/04/2026

  Fornece TActiveDirectoryJsonResult — implementação de ILDAPSearchResult que lê dados
  de um TJSONObject (resposta REST / MS Graph / qualquer fonte JSON).

  Estrutura JSON esperada — campos por tipo:
    dn / distinguishedName : string direto
    sAMAccountName / mail  : string direto
    memberOf               : TJSONArray de strings
    objectGUID             : base64 de 16 bytes
    objectSid              : base64 binario ou string "S-1-5-21-..."
    pwdLastSet             : Int64 como string decimal

  Campos multivalorados: TJSONArray de strings.
  Campos binários: base64 via TNetEncoding.Base64.
  Campos FILETIME: string numérica Int64.

  Changelog (file):
  - 1.0.0 (14/04/2026): Versão inicial — TActiveDirectoryJsonResult implementa ILDAPSearchResult
                        lendo de TJSONObject; AttributeSid decodifica base64 em bytes
                        e retorna no formato S-1-5-21-...; AttributeGuid decodifica
                        base64 em TGUID.
  ============================================================================= }

unit ActiveDirectory.JsonResult;

interface

uses
  ActiveDirectory.Main.Interfaces,
{$IFDEF FPC}
  SysUtils, Classes, fpjson, base64;
{$ELSE}
  System.SysUtils, System.Classes, System.JSON, System.NetEncoding;
{$ENDIF}

{$IFDEF FPC}
type
  // cross-compiler: base JSON value type (Delphi = System.JSON.TJSONValue; FPC = fpjson.TJSONData)
  TJSONValue = fpjson.TJSONData;
{$ENDIF}

type

  // ===========================================================================
  // TActiveDirectoryJsonResult
  // ===========================================================================

  (** Implementação de ILDAPSearchResult sobre um TJSONObject.
      Não assume posse do objeto JSON — o chamador é responsável pelo ciclo de vida.

      Uso:
        LJson   := TJSONObject(LResponseArray.Items[0]);
        LResult := TActiveDirectoryJsonResult.Create(LJson);
        LUser   := TActiveDirectoryMapper<TAdUser>.FromSearchResult(LResult); *)
  TActiveDirectoryJsonResult = class(TInterfacedObject, ILDAPSearchResult)
  private
    FJson: TJSONObject;
    function RawValue(const AName: string): string;
    function DecodeBase64Bytes(const ABase64: string): TBytes;
    function DecodeSidBytes(const ABytes: TBytes): string;
  public
    (** Recebe referência ao JSON — não assume posse. *)
    constructor Create(AJson: TJSONObject);

    function DN: string;
    function Attribute(const AName: string): string;
    function AttributeList(const AName: string): TArray<string>;
    function AttributeGuid(const AName: string): TGuid;
    function AttributeFileTime(const AName: string): Int64;
    function AttributeSid(const AName: string): string;
  end;


implementation

{ TActiveDirectoryJsonResult — helpers privados }

function TActiveDirectoryJsonResult.RawValue(const AName: string): string;
{$IFDEF FPC}
var
  LData: TJSONData;
begin
  Result := '';
  LData  := FJson.Find(AName);
  if (LData = nil) or (LData.JSONType = jtNull) then Exit;
  if LData.JSONType = jtArray then
  begin
    // array: retorna o primeiro elemento
    if TJSONArray(LData).Count > 0 then
      Result := TJSONArray(LData).Items[0].AsString;
  end
  else
    Result := LData.AsString;
end;
{$ELSE}
var
  LVal: TJSONValue;
begin
  Result := '';
  LVal   := FJson.GetValue(AName);
  if LVal = nil then Exit;
  if LVal is TJSONArray then
  begin
    if TJSONArray(LVal).Count > 0 then
      Result := TJSONArray(LVal).Items[0].Value;
  end
  else
    Result := LVal.Value;
end;
{$ENDIF}

function TActiveDirectoryJsonResult.DecodeBase64Bytes(const ABase64: string): TBytes;
begin
{$IFDEF FPC}
  Result := BytesOf(DecodeStringBase64(ABase64, True));  // FPC: AnsiString(raw bytes) -> TBytes
{$ELSE}
  Result := TNetEncoding.Base64.DecodeStringToBytes(ABase64);
{$ENDIF}
end;

function TActiveDirectoryJsonResult.DecodeSidBytes(const ABytes: TBytes): string;
var
  LRev, LCnt: Byte;
  LAuth: Int64;
  I:    Integer;
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

{ TActiveDirectoryJsonResult — constructor }

constructor TActiveDirectoryJsonResult.Create(AJson: TJSONObject);
begin
  inherited Create;
  FJson := AJson;
end;

{ TActiveDirectoryJsonResult — públicos }

function TActiveDirectoryJsonResult.DN: string;
begin
  Result := RawValue('dn');
  if Result = '' then
    Result := RawValue('distinguishedName');
end;

function TActiveDirectoryJsonResult.Attribute(const AName: string): string;
begin
  Result := RawValue(AName);
end;

function TActiveDirectoryJsonResult.AttributeList(const AName: string): TArray<string>;
{$IFDEF FPC}
var
  LData: TJSONData;
  LArr:  TJSONArray;
  I:     Integer;
begin
  SetLength(Result, 0);
  LData := FJson.Find(AName);
  if LData = nil then Exit;
  if LData.JSONType = jtArray then
  begin
    LArr := TJSONArray(LData);
    SetLength(Result, LArr.Count);
    for I := 0 to LArr.Count - 1 do
      Result[I] := LArr.Items[I].AsString;
  end
  else if LData.JSONType <> jtNull then
  begin
    // valor escalar → array de 1 elemento
    SetLength(Result, 1);
    Result[0] := LData.AsString;
  end;
end;
{$ELSE}
var
  LVal: TJSONValue;
  LArr: TJSONArray;
  I:    Integer;
begin
  SetLength(Result, 0);
  LVal := FJson.GetValue(AName);
  if LVal = nil then Exit;
  if LVal is TJSONArray then
  begin
    LArr := TJSONArray(LVal);
    SetLength(Result, LArr.Count);
    for I := 0 to LArr.Count - 1 do
      Result[I] := LArr.Items[I].Value;
  end
  else
  begin
    // valor escalar → array de 1 elemento
    SetLength(Result, 1);
    Result[0] := LVal.Value;
  end;
end;
{$ENDIF}

function TActiveDirectoryJsonResult.AttributeGuid(const AName: string): TGuid;
var
  LB64:  string;
  LBytes: TBytes;
begin
  FillChar(Result, SizeOf(Result), 0);
  LB64 := RawValue(AName);
  if LB64 = '' then Exit;
  LBytes := DecodeBase64Bytes(LB64);
  if Length(LBytes) = SizeOf(TGuid) then
    Move(LBytes[0], Result, SizeOf(TGuid));
end;

function TActiveDirectoryJsonResult.AttributeFileTime(const AName: string): Int64;
begin
  Result := StrToInt64Def(RawValue(AName), 0);
end;

function TActiveDirectoryJsonResult.AttributeSid(const AName: string): string;
var
  LRaw:   string;
  LBytes: TBytes;
begin
  Result := '';
  LRaw := RawValue(AName);
  if LRaw = '' then Exit;
  // Tenta decodificar como base64 (formato binário/JSON do AD)
  try
    LBytes := DecodeBase64Bytes(LRaw);
    if Length(LBytes) >= 8 then
    begin
      Result := DecodeSidBytes(LBytes);
      Exit;
    end;
  except
    // não é base64 — trata como string direta
  end;
  // Se começa com 'S-', assume já decodificado
  if Copy(LRaw, 1, 2) = 'S-' then
    Result := LRaw;
end;

end.
