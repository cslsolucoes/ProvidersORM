{ =============================================================================
  ActiveDirectory.DataSetResult - ILDAPSearchResult sobre TDataSet

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.8.0 (ActiveDirectory absorvido do SSOT v1.7.6)
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           24/04/2026

  Fornece TActiveDirectoryDataSetResult — implementação de ILDAPSearchResult que lê dados
  do registro ativo de qualquer TDataSet (TFDQuery, TFDMemTable, etc.).

  Convenção de armazenamento:
    - Cada coluna do dataset tem o mesmo nome do atributo LDAP (case-insensitive
      via FieldByName).
    - Campos multivalorados (memberOf, proxyAddresses, servicePrincipalName, etc.)
      são armazenados em um único campo string com valores separados por ';'.
    - objectGUID pode ser armazenado como string formatada (B3C9F5A5-...) ou bytes binários.
    - objectSid pode ser armazenado já no formato 'S-1-5-21-...' (preferido) ou
      como base64 se originado de importação binária.

  Fluxo típico:
    Cache LDAP → TFDQuery/TFDMemTable → TActiveDirectoryDataSetResult → TActiveDirectoryMapper<TAdUser>

  Changelog (file):
  - 1.0.0 (14/04/2026): Versão inicial — TActiveDirectoryDataSetResult implementa ILDAPSearchResult
                        lendo de TDataSet; AttributeList split por ';'; AttributeSid
                        retorna direto se formato 'S-*' ou decodifica base64.
  ============================================================================= }

unit ActiveDirectory.DataSetResult;

interface

uses
  ActiveDirectory.Main.Interfaces,
{$IFDEF FPC}
  SysUtils, Classes, DB, base64;
{$ELSE}
  System.SysUtils, System.Classes, Data.DB, System.NetEncoding;
{$ENDIF}

const
  (** Separador de valores em campos multivalorados armazenados como string única.
      Padrão: ';'. Trocar apenas se o domínio usar ';' nos próprios valores. *)
  MULTIVALUE_SEPARATOR = ';';

type

  // ===========================================================================
  // TActiveDirectoryDataSetResult
  // ===========================================================================

  (** Implementação de ILDAPSearchResult sobre o registro ativo de um TDataSet.
      Não assume posse do dataset — o chamador é responsável pelo ciclo de vida.
      O dataset deve estar posicionado na linha desejada antes da chamada a
      TActiveDirectoryMapper<T>.FromSearchResult.

      Uso:
        while not LQuery.Eof do
        begin
          LResult := TActiveDirectoryDataSetResult.Create(LQuery);
          LUser   := TActiveDirectoryMapper<TAdUser>.FromSearchResult(LResult);
          // ... processar LUser ...
          LQuery.Next;
        end; *)
  TActiveDirectoryDataSetResult = class(TInterfacedObject, ILDAPSearchResult)
  private
    FDataSet: TDataSet;
    function SafeField(const AName: string): string;
    function DecodeBase64Bytes(const ABase64: string): TBytes;
    function DecodeSidBytes(const ABytes: TBytes): string;
  public
    (** Recebe referência ao dataset — não assume posse. *)
    constructor Create(ADataSet: TDataSet);

    function DN: string;
    function Attribute(const AName: string): string;
    function AttributeList(const AName: string): TArray<string>;
    function AttributeGuid(const AName: string): TGuid;
    function AttributeFileTime(const AName: string): Int64;
    function AttributeSid(const AName: string): string;
  end;


implementation

{ TActiveDirectoryDataSetResult — helpers privados }

function TActiveDirectoryDataSetResult.SafeField(const AName: string): string;
var
  LField: TField;
begin
  Result := '';
  LField := FDataSet.FindField(AName);
  if LField <> nil then
    Result := LField.AsString;
end;

function TActiveDirectoryDataSetResult.DecodeBase64Bytes(const ABase64: string): TBytes;
begin
{$IFDEF FPC}
  Result := BytesOf(DecodeStringBase64(ABase64, True));  // FPC: AnsiString(raw bytes) -> TBytes
{$ELSE}
  Result := TNetEncoding.Base64.DecodeStringToBytes(ABase64);
{$ENDIF}
end;

function TActiveDirectoryDataSetResult.DecodeSidBytes(const ABytes: TBytes): string;
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

{ TActiveDirectoryDataSetResult — constructor }

constructor TActiveDirectoryDataSetResult.Create(ADataSet: TDataSet);
begin
  inherited Create;
  FDataSet := ADataSet;
end;

{ TActiveDirectoryDataSetResult — públicos }

function TActiveDirectoryDataSetResult.DN: string;
begin
  Result := SafeField('distinguishedName');
  if Result = '' then
    Result := SafeField('dn');
end;

function TActiveDirectoryDataSetResult.Attribute(const AName: string): string;
begin
  Result := SafeField(AName);
end;

function TActiveDirectoryDataSetResult.AttributeList(const AName: string): TArray<string>;
var
  LRaw:   string;
  LParts: TArray<string>;
begin
  SetLength(Result, 0);
  LRaw := SafeField(AName);
  if LRaw = '' then Exit;
  // Split por MULTIVALUE_SEPARATOR (';' por padrão)
  LParts := LRaw.Split([MULTIVALUE_SEPARATOR]);
  Result := LParts;
end;

function TActiveDirectoryDataSetResult.AttributeGuid(const AName: string): TGuid;
var
  LRaw:   string;
  LField: TField;
  LBytes: TBytes;
begin
  FillChar(Result, SizeOf(Result), 0);
  LField := FDataSet.FindField(AName);
  if LField = nil then Exit;
  if LField.DataType = ftBlob then
  begin
    // Campo binário (ftBlob/ftBytes): lê bytes diretamente
    LBytes := LField.AsBytes;
    if Length(LBytes) = SizeOf(TGuid) then
      Move(LBytes[0], Result, SizeOf(TGuid));
  end
  else
  begin
    // Campo string: tenta como GUID formatado '{...}' ou base64
    LRaw := LField.AsString;
    if LRaw = '' then Exit;
    try
      Result := StringToGUID(LRaw);
    except
      try
        LBytes := DecodeBase64Bytes(LRaw);
        if Length(LBytes) = SizeOf(TGuid) then
          Move(LBytes[0], Result, SizeOf(TGuid));
      except
        // falha silenciosa; retorna GUID vazio
      end;
    end;
  end;
end;

function TActiveDirectoryDataSetResult.AttributeFileTime(const AName: string): Int64;
begin
  Result := StrToInt64Def(SafeField(AName), 0);
end;

function TActiveDirectoryDataSetResult.AttributeSid(const AName: string): string;
var
  LRaw:   string;
  LBytes: TBytes;
begin
  Result := '';
  LRaw := SafeField(AName);
  if LRaw = '' then Exit;
  // Se já está no formato S-1-5-21-... retorna diretamente
  if Copy(LRaw, 1, 2) = 'S-' then
  begin
    Result := LRaw;
    Exit;
  end;
  // Caso contrário, tenta decodificar como base64
  try
    LBytes := DecodeBase64Bytes(LRaw);
    if Length(LBytes) >= 8 then
      Result := DecodeSidBytes(LBytes);
  except
    // Sem decodificação válida — retorna ''
  end;
end;

end.
