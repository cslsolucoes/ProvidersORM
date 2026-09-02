{ =============================================================================
  ActiveDirectory.LdapResult - ILDAPSearchResult sobre Synapse binário

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.8.0 (ActiveDirectory absorvido do SSOT v1.7.6)
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           24/04/2026

  Fornece TActiveDirectoryResult — implementação de ILDAPSearchResult que lê dados
  diretamente de um TLDAPResult do Synapse (bytes binários).

  Casos de uso:
    - Wrappear uma entrada TLDAPResult fora do TActiveDirectoryService para
      uso com TActiveDirectoryMapper<T> sem passar pelo adapter interno do Service.
    - Testes unitários com entradas Synapse mockadas.

  Nota: Para uso integrado ao TActiveDirectoryService, o adapter interno
  TLDAPSearchResultAdapter (ActiveDirectory.Service.pas) já é suficiente.
  TActiveDirectoryResult é útil quando se acessa o TLDAPSend diretamente.

  Changelog (file):
  - 1.0.0 (14/04/2026): Versão inicial — TActiveDirectoryResult implementa ILDAPSearchResult
                        lendo de TLDAPResult (Synapse); AttributeSid decodifica
                        objectSid binário → 'S-1-5-21-...'.
  ============================================================================= }

{$I ../../ORM.Defines.inc}
{$IFDEF USE_LDAP}
unit ActiveDirectory.LdapResult;

interface

uses
  ActiveDirectory.Main.Interfaces,
{$IFDEF FPC}
  SysUtils, Classes,
  ldapsend;   // Synapse fork CSL - mesmo backend LDAP em FPC e Delphi (v1.7.6 SSOT tinha lNet, incompativel)
{$ELSE}
  System.SysUtils, System.Classes,
  ldapsend;   // Synapse Delphi: TLDAPResult, TLDAPAttribute
{$ENDIF}

type

  // ===========================================================================
  // TActiveDirectoryResult
  // ===========================================================================

  (** Par nome→valores copiado do TLDAPResult para isolamento de ciclo de vida. *)
  TActiveDirectoryAttrEntry = record
    Name:      string;
    Values:    TArray<string>;
    RawValues: TArray<AnsiString>;
  end;

  (** Implementação de ILDAPSearchResult sobre uma entrada TLDAPResult do Synapse.
      Copia todos os atributos no constructor para ser independente do ciclo de
      vida do TLDAPResultList original.

      Uso:
        LEntry := FLDAPSend.SearchResult.Items[0];
        LResult := TActiveDirectoryResult.Create(LEntry);
        LUser   := TActiveDirectoryMapper<TAdUser>.FromSearchResult(LResult); *)
  TActiveDirectoryResult = class(TInterfacedObject, ILDAPSearchResult)
  private
    FDN:    string;
    FAttrs: array of TActiveDirectoryAttrEntry;
    function FindAttrIdx(const AName: string): Integer;
    class function DecodeStr(const A: AnsiString): string; static;
  public
    (** Copia todos os dados do TLDAPResult. AResult não é referenciado após o constructor. *)
    constructor Create(AResult: ldapsend.TLDAPResult);   // qualificado: colide (case-insensitive) com a classe TActiveDirectoryResult

    function DN: string;
    function Attribute(const AName: string): string;
    function AttributeList(const AName: string): TArray<string>;
    function AttributeGuid(const AName: string): TGuid;
    function AttributeFileTime(const AName: string): Int64;
    function AttributeSid(const AName: string): string;
  end;


implementation

{ TActiveDirectoryResult — helpers privados }

class function TActiveDirectoryResult.DecodeStr(const A: AnsiString): string;
begin
{$IFDEF FPC}
  Result := UTF8ToString(A);
{$ELSE}
  {$IF CompilerVersion >= 20}
    Result := TEncoding.UTF8.GetString(TEncoding.ANSI.GetBytes(string(A)));
  {$ELSE}
    Result := UTF8ToString(A);
  {$IFEND}
{$ENDIF}
end;

constructor TActiveDirectoryResult.Create(AResult: ldapsend.TLDAPResult);
var
  i, j:   Integer;
  LAttr:  ldapsend.TLDAPAttribute;
  LEntry: TActiveDirectoryAttrEntry;
begin
  inherited Create;
  FDN := DecodeStr(AnsiString(AResult.ObjectName));
  SetLength(FAttrs, AResult.Attributes.Count);
  for i := 0 to AResult.Attributes.Count - 1 do
  begin
    LAttr := AResult.Attributes[i];
    LEntry.Name := DecodeStr(AnsiString(LAttr.AttributeName));
    SetLength(LEntry.Values,    LAttr.Count);
    SetLength(LEntry.RawValues, LAttr.Count);
    for j := 0 to LAttr.Count - 1 do
    begin
      LEntry.RawValues[j] := LAttr.RawValueAt[j];   // v1.7.6 SSOT usava GetRaw(j) inexistente no Synapse 001.007.005
      LEntry.Values[j]    := DecodeStr(LEntry.RawValues[j]);
    end;
    FAttrs[i] := LEntry;
  end;
end;


function TActiveDirectoryResult.FindAttrIdx(const AName: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(FAttrs) do
    if SameText(FAttrs[i].Name, AName) then
    begin
      Result := i;
      Exit;
    end;
end;

{ TActiveDirectoryResult — públicos }

function TActiveDirectoryResult.DN: string;
begin
  Result := FDN;
end;

function TActiveDirectoryResult.Attribute(const AName: string): string;
var
  idx: Integer;
begin
  Result := '';
  idx := FindAttrIdx(AName);
  if (idx >= 0) and (Length(FAttrs[idx].Values) > 0) then
    Result := FAttrs[idx].Values[0];
end;

function TActiveDirectoryResult.AttributeList(const AName: string): TArray<string>;
var
  idx: Integer;
begin
  SetLength(Result, 0);
  idx := FindAttrIdx(AName);
  if idx >= 0 then
    Result := FAttrs[idx].Values;
end;

function TActiveDirectoryResult.AttributeGuid(const AName: string): TGuid;
var
  LRaw: AnsiString;
  idx:  Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  idx := FindAttrIdx(AName);
  if (idx < 0) or (Length(FAttrs[idx].RawValues) = 0) then Exit;
  LRaw := FAttrs[idx].RawValues[0];
  if Length(LRaw) = SizeOf(TGuid) then
    Move(LRaw[1], Result, SizeOf(TGuid));
end;

function TActiveDirectoryResult.AttributeFileTime(const AName: string): Int64;
begin
  Result := StrToInt64Def(Attribute(AName), 0);
end;

function TActiveDirectoryResult.AttributeSid(const AName: string): string;
var
  LRaw:  AnsiString;
  idx:   Integer;
  LB:    TBytes;
  LRev, LCnt: Byte;
  LAuth: Int64;
  I:     Integer;
  LSub:  LongWord;
begin
  Result := '';
  idx := FindAttrIdx(AName);
  if (idx < 0) or (Length(FAttrs[idx].RawValues) = 0) then Exit;
  LRaw := FAttrs[idx].RawValues[0];
  if Length(LRaw) < 8 then Exit;
  SetLength(LB, Length(LRaw));
  Move(LRaw[1], LB[0], Length(LRaw));
  LRev  := LB[0];
  LCnt  := LB[1];
  LAuth := 0;
  for I := 2 to 7 do
    LAuth := (LAuth shl 8) or LB[I];
  Result := Format('S-%d-%d', [LRev, LAuth]);
  if Length(LB) < 8 + LCnt * 4 then Exit;
  for I := 0 to LCnt - 1 do
  begin
    LSub := LB[8 + I * 4]
          or (LB[9  + I * 4] shl 8)
          or (LB[10 + I * 4] shl 16)
          or (LB[11 + I * 4] shl 24);
    Result := Result + '-' + IntToStr(LSub);
  end;
end;

{$ENDIF USE_LDAP}

end.
