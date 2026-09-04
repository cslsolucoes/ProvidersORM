(* =============================================================================
  Attributers.ActiveDirectory - Atributos RTTI, entidades AD e mapeador LDAP

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.8.0 (ActiveDirectory absorvido do SSOT v1.7.6)
  FileVersion:    1.2.1
  Author:         Claiton de Souza Linhares
  Date:           07/03/2026

  Changelog (file):
  - 1.0.0 (07/03/2026): Versão inicial.
  - 1.0.1 (07/03/2026): Constantes LDAP_ATTR_* e LDAP_OBJECTCLASS_*; atributo RTTI LdapAttribute.
  - 1.0.2 (07/03/2026): LDAP_ATTR_UNIQUEMEMBER; constantes de filtro LDAP_FILTER_*; uso no projeto todo.
  - 1.0.3 (07/03/2026): Classes RTTI (LdapAttribute, LdapObjectClass) condicionais a USE_ATTRIBUTES (ORM.Defines.inc).
  - 1.1.0 (2026-04-13): TAdUser, TAdGroup (entidades AD anotadas com [LdapAttribute]/[LdapObjectClass]);
                        TActiveDirectoryMapper<T> (mapeador RTTI genérico); FromSearchResult popula T a partir de
                        ILDAPSearchResult via reflexão de campos; ToModifyList serializa campos para lista
                        de modificação LDAP ("AttrName=Value"). FILETIME e generalizedTime suportados.
  - 1.2.0 (2026-04-14): LdapSidAttribute (novo atributo RTTI → chama AttributeSid);
                        TAdUser expandido (~50 campos + 10 helpers, renomeado LastChanged→WhenChanged);
                        TAdGroup expandido (11 campos + 4 helpers);
                        TAdComputer (novo, 17 campos + 5 helpers);
                        TAdOU (novo, 6 campos);
                        TAdAttrDef (record) e TAdAttrList (classe utilitária) para AD_ATTR_LIST.
  - 1.2.1 (06/07/2026): (1) adicionado o {$I ..\ORM.Defines.inc} que faltava (bug de
    absorção) — sem ele USE_ATTRIBUTES ficava OFF e TODO o mapeador RTTI (TAdUser/
    TActiveDirectoryMapper) estava DORMENTE (compilado-fora) nos 2 compiladores.
    (2) fix cross-compiler no mapeador: TValue.From<TArray<string>> / AsType<TArray<string>>
    (só-Delphi) -> TValue.Make + GetArrayLength/GetArrayElement (Delphi + FPC 3.3.1).
    Mapeador AD passa a estar ATIVO e cross-compiler. Exposto ao migrar as Views (F3 etapa 1).
  ============================================================================= *)

unit Attributers.ActiveDirectory;

{$I ORM.Defines.inc}

interface

uses
{$IFDEF USE_ATTRIBUTES}
  {$IFDEF FPC}
    Rtti, SysUtils, DateUtils, Classes, Generics.Collections,
  {$ELSE}
    System.Rtti, System.SysUtils, System.DateUtils, System.Classes,
    System.Generics.Collections,
  {$ENDIF}
  ActiveDirectory.Main.Interfaces,
{$ENDIF}
  Commons.ActiveDirectory.Consts;

{$IFDEF USE_ATTRIBUTES}

type

  // ---------------------------------------------------------------------------
  // Atributos RTTI para anotação de campos e classes
  // ---------------------------------------------------------------------------

  { Mapeia um campo público ao nome do atributo LDAP correspondente.
    Uso: [LdapAttribute('sAMAccountName')] Login: string; }
  LdapAttribute = class(TCustomAttribute)
  private
    FAttributeName: string;
  public
    constructor Create(const AAttributeName: string);
    property AttributeName: string read FAttributeName;
  end;

  { Mapeia a classe ao objectClass LDAP (ex.: 'user', 'group').
    Uso: [LdapObjectClass('user')] TAdUser = class ... }
  LdapObjectClass = class(TCustomAttribute)
  private
    FObjectClass: string;
  public
    constructor Create(const AObjectClass: string);
    property ObjectClass: string read FObjectClass;
  end;

  { Mapeia um campo string ao nome de um atributo SID binário.
    O mapper chama AttributeSid() em vez de Attribute(), convertendo
    automaticamente os bytes para o formato 'S-1-5-21-...'.
    Uso: [LdapSidAttribute('objectSid')] ObjectSid: string; }
  LdapSidAttribute = class(TCustomAttribute)
  private
    FAttributeName: string;
  public
    constructor Create(const AAttributeName: string);
    property AttributeName: string read FAttributeName;
  end;


  // ---------------------------------------------------------------------------
  // Entidades AD anotadas
  // ---------------------------------------------------------------------------

  { Usuário do Active Directory com todos os atributos relevantes. }
  [LdapObjectClass('user')]
  TAdUser = class
  public
    [LdapAttribute('objectGUID')]                 ObjectGUID:         TGUID;
    [LdapSidAttribute('objectSid')]               ObjectSid:          string;
    [LdapAttribute('distinguishedName')]          DN:                 string;
    [LdapAttribute('cn')]                         CN:                 string;
    [LdapAttribute('sn')]                         Surname:            string;
    [LdapAttribute('givenName')]                  FirstName:          string;
    [LdapAttribute('middleName')]                 MiddleName:         string;
    [LdapAttribute('initials')]                   Initials:           string;
    [LdapAttribute('displayName')]                DisplayName:        string;
    [LdapAttribute('mail')]                       Email:              string;
    [LdapAttribute('proxyAddresses')]             ProxyAddresses:     TArray<string>;
    [LdapAttribute('sAMAccountName')]             Login:              string;
    [LdapAttribute('userPrincipalName')]          UPN:                string;
    [LdapAttribute('title')]                      Title:              string;
    [LdapAttribute('department')]                 Department:         string;
    [LdapAttribute('company')]                    Company:            string;
    [LdapAttribute('physicalDeliveryOfficeName')] Office:             string;
    [LdapAttribute('telephoneNumber')]            Phone:              string;
    [LdapAttribute('mobile')]                     Mobile:             string;
    [LdapAttribute('facsimileTelephoneNumber')]   Fax:                string;
    [LdapAttribute('streetAddress')]              StreetAddress:      string;
    [LdapAttribute('l')]                          City:               string;
    [LdapAttribute('st')]                         State:              string;
    [LdapAttribute('postalCode')]                 PostalCode:         string;
    [LdapAttribute('c')]                          CountryCode:        string;
    [LdapAttribute('co')]                         Country:            string;
    [LdapAttribute('manager')]                    ManagerDN:          string;
    [LdapAttribute('wWWHomePage')]                WebPage:            string;
    [LdapAttribute('employeeID')]                 EmployeeID:         string;
    [LdapAttribute('employeeNumber')]             EmployeeNumber:     string;
    [LdapAttribute('userAccountControl')]         UAC:                Integer;
    [LdapAttribute('pwdLastSet')]                 PwdLastSet:         Int64;
    [LdapAttribute('accountExpires')]             AccountExpires:     Int64;
    [LdapAttribute('lockoutTime')]                LockoutTime:        Int64;
    [LdapAttribute('badPwdCount')]                BadPwdCount:        Integer;
    [LdapAttribute('logonCount')]                 LogonCount:         Integer;
    [LdapAttribute('adminCount')]                 AdminCount:         Integer;
    [LdapAttribute('primaryGroupID')]             PrimaryGroupID:     Integer;
    [LdapAttribute('scriptPath')]                 ScriptPath:         string;
    [LdapAttribute('lastLogon')]                  LastLogon:          Int64;
    [LdapAttribute('lastLogonTimestamp')]         LastLogonTimestamp: Int64;
    [LdapAttribute('memberOf')]                   Groups:             TArray<string>;
    [LdapAttribute('whenCreated')]                WhenCreated:        TDateTime;
    [LdapAttribute('whenChanged')]                WhenChanged:        TDateTime;

    { True se a conta estiver bloqueada (UAC_LOCKOUT). }
    function IsLocked: Boolean;
    { True se a conta estiver desabilitada (UAC_ACCOUNTDISABLE). }
    function IsDisabled: Boolean;
    { True se a senha estiver expirada (UAC_PASSWORD_EXPIRED). }
    function IsExpired: Boolean;
    { True se a senha nunca expira (UAC_DONT_EXPIRE_PASSWD). }
    function IsPasswordNeverExpires: Boolean;
    { True se a conta é membro de grupo protegido (AdminSDHolder). }
    function IsAdminProtected: Boolean;
    { Data da última troca de senha (FILETIME → TDateTime; 0 se nunca trocou). }
    function PwdLastSetDate: TDateTime;
    { Data de expiração da conta (FILETIME → TDateTime; 0 se nunca expira). }
    function AccountExpiresDate: TDateTime;
    { Último logon replicado (FILETIME → TDateTime; 0 se nunca logou). }
    function LastLogonDate: TDateTime;
    { True se o usuário nunca fez logon (LastLogon = 0 e LastLogonTimestamp = 0). }
    function NeverLoggedOn: Boolean;
    { True se a conta expirou (AccountExpires <> sentinel e AccountExpiresDate < Now). }
    function IsAccountExpired: Boolean;
  private
    class function FT(AVal: Int64): TDateTime; static;
  end;

  { Grupo do Active Directory. }
  [LdapObjectClass('group')]
  TAdGroup = class
  public
    [LdapAttribute('objectGUID')]        ObjectGUID:  TGUID;
    [LdapSidAttribute('objectSid')]      ObjectSid:   string;
    [LdapAttribute('cn')]                Name:        string;
    [LdapAttribute('distinguishedName')] DN:          string;
    [LdapAttribute('description')]       Description: string;
    [LdapAttribute('sAMAccountName')]    Login:       string;
    [LdapAttribute('groupType')]         GroupType:   Integer;
    [LdapAttribute('sAMAccountType')]    SamType:     Integer;
    [LdapAttribute('member')]            Members:     TArray<string>;
    [LdapAttribute('whenCreated')]       WhenCreated: TDateTime;
    [LdapAttribute('whenChanged')]       WhenChanged: TDateTime;

    { True se é um grupo de segurança (bit LDAP_GROUPTYPE_SECURITY). }
    function IsSecurityGroup: Boolean;
    { True se é um grupo global. }
    function IsGlobalGroup: Boolean;
    { True se é um grupo universal. }
    function IsUniversalGroup: Boolean;
    { True se é um grupo de domínio local. }
    function IsDomainLocalGroup: Boolean;
  end;

  { Computador do Active Directory. }
  [LdapObjectClass('computer')]
  TAdComputer = class
  public
    [LdapAttribute('objectGUID')]             ObjectGUID:   TGUID;
    [LdapSidAttribute('objectSid')]           ObjectSid:    string;
    [LdapAttribute('distinguishedName')]      DN:           string;
    [LdapAttribute('cn')]                     ComputerName: string;
    [LdapAttribute('dNSHostName')]            DnsHostName:  string;
    [LdapAttribute('operatingSystem')]        OS:           string;
    [LdapAttribute('operatingSystemVersion')] OSVersion:    string;
    [LdapAttribute('sAMAccountName')]         SamAccount:   string;
    [LdapAttribute('userAccountControl')]     UAC:          Integer;
    [LdapAttribute('lastLogon')]              LastLogon:    Int64;
    [LdapAttribute('pwdLastSet')]             PwdLastSet:   Int64;
    [LdapAttribute('logonCount')]             LogonCount:   Integer;
    [LdapAttribute('memberOf')]               Groups:       TArray<string>;
    [LdapAttribute('servicePrincipalName')]   SPNs:         TArray<string>;
    [LdapAttribute('whenCreated')]            WhenCreated:  TDateTime;
    [LdapAttribute('whenChanged')]            WhenChanged:  TDateTime;

    { True se o computador está desabilitado (UAC_ACCOUNTDISABLE). }
    function IsDisabled: Boolean;
    { True se é uma estação de trabalho membro do domínio (UAC_WORKSTATION_TRUST_ACCOUNT). }
    function IsWorkstation: Boolean;
    { True se é um controlador de domínio (UAC_SERVER_TRUST_ACCOUNT). }
    function IsDomainController: Boolean;
    { Data do último logon (FILETIME → TDateTime). }
    function LastLogonDate: TDateTime;
    { Data da última renovação de senha do computador (FILETIME → TDateTime). }
    function PwdLastSetDate: TDateTime;
  private
    class function FT(AVal: Int64): TDateTime; static;
  end;

  { Unidade Organizacional do Active Directory. }
  [LdapObjectClass('organizationalUnit')]
  TAdOU = class
  public
    [LdapAttribute('objectGUID')]        ObjectGUID:  TGUID;
    [LdapAttribute('ou')]                Name:        string;
    [LdapAttribute('distinguishedName')] DN:          string;
    [LdapAttribute('description')]       Description: string;
    [LdapAttribute('whenCreated')]       WhenCreated: TDateTime;
    [LdapAttribute('whenChanged')]       WhenChanged: TDateTime;
  end;


  // ---------------------------------------------------------------------------
  // Catálogo de atributos — TAdAttrDef e TAdAttrList
  // ---------------------------------------------------------------------------

  { Representa uma entrada do catálogo AD_ATTR_LIST. }
  TAdAttrDef = record
    (** Nome do atributo LDAP. Ex: 'givenName'. *)
    AttrName:    string;
    (** objectClass alvo: '*' = todos; 'user', 'group', 'computer', 'ou' = específico;
        'user|group' = múltiplas classes (separadas por '|'). *)
    ObjectClass: string;
    (** Descrição legível. Ex: 'Primeiro nome'. *)
    Description: string;
  end;

  (** Utilitários para parsear e filtrar AD_ATTR_LIST.
      AD_ATTR_LIST é a fonte canônica de metadados de atributos definida em
      ActiveDirectory.Consts.pas. Formato: 'attr:objectClass:desc,...'

      Uso típico:
        // Atributos para busca de usuário (inclui '*' + 'user')
        LAttrs := TAdAttrList.NamesForClass(AD_ATTR_LIST, 'user');

        // Descrição de um atributo
        ShowMessage(TAdAttrList.DescOf(AD_ATTR_LIST, 'employeeID')); *)
  TAdAttrList = class
  public
    (** Parseia AD_ATTR_LIST completo em array de TAdAttrDef. *)
    class function Parse(const AList: string): TArray<TAdAttrDef>; static;

    (** Retorna apenas os nomes de atributo para AClass.
        Inclui entradas '*' e entradas cujo ObjectClass contenha AClass. *)
    class function NamesForClass(const AList, AClass: string): TArray<string>; static;

    (** Retorna a descrição de um atributo pelo nome. '' se não encontrado. *)
    class function DescOf(const AList, AAttrName: string): string; static;
  end;


  // ---------------------------------------------------------------------------
  // Mapeador RTTI genérico
  // ---------------------------------------------------------------------------

  { Popula instâncias de T a partir de ILDAPSearchResult e serializa para
    lista de modificação LDAP.

    T deve ser uma classe com campos públicos anotados com [LdapAttribute]
    ou [LdapSidAttribute].

    Tipos de campo suportados: string, Integer, Int64, TDateTime (FILETIME ou
    generalizedTime), TGUID, TArray<string>.

    Uso:
      var LUser: TAdUser;
      LUser := TActiveDirectoryMapper<TAdUser>.FromSearchResult(LResult);
      try
        if LUser.IsLocked then ...
      finally
        LUser.Free;
      end; }
  TActiveDirectoryMapper<T: class, constructor> = class
  private
    { Converte Windows FILETIME (Int64, 100ns desde 1601-01-01) em TDateTime. }
    class function InternalFileTimeToDateTime(AFileTime: Int64): TDateTime; static;

    { Converte string generalizedTime do AD (YYYYMMDDHHmmss[.f]Z) em TDateTime. }
    class function InternalParseGeneralizedTime(const S: string): TDateTime; static;

    { Lê o atributo AAttrName de AResult e atribui ao campo AField de AInstance.
      AIsSid=True indica que o campo usa LdapSidAttribute → chama AttributeSid. }
    class procedure SetFieldValue(AInstance: TObject; AField: TRttiField;
      AResult: ILDAPSearchResult; const AAttrName: string;
      AIsSid: Boolean = False); static;
  public
    { Cria T e preenche seus campos anotados com dados de AResult.
      O chamador é responsável por liberar a instância retornada. }
    class function FromSearchResult(AResult: ILDAPSearchResult): T; static;

    { Serializa os campos anotados de AObj em um TStringList ("AttrName=Value").
      Atributos multivalorados geram múltiplas linhas com o mesmo nome.
      O chamador é responsável por liberar o TStringList retornado. }
    class function ToModifyList(AObj: T): TStringList; static;
  end;

{$ENDIF USE_ATTRIBUTES}

implementation

{$IFDEF USE_ATTRIBUTES}

{ LdapAttribute }

constructor LdapAttribute.Create(const AAttributeName: string);
begin
  inherited Create;
  FAttributeName := AAttributeName;
end;

{ LdapObjectClass }

constructor LdapObjectClass.Create(const AObjectClass: string);
begin
  inherited Create;
  FObjectClass := AObjectClass;
end;

{ LdapSidAttribute }

constructor LdapSidAttribute.Create(const AAttributeName: string);
begin
  inherited Create;
  FAttributeName := AAttributeName;
end;


{ TAdUser — helpers }

class function TAdUser.FT(AVal: Int64): TDateTime;
const
  TICKS_PER_DAY: Int64 = 864000000000;
begin
  if (AVal <= 0) or (AVal = Int64($7FFFFFFFFFFFFFFF)) then
    Result := 0
  else
    Result := (AVal - LDAP_FILETIME_EPOCH_DAYS * TICKS_PER_DAY) / TICKS_PER_DAY;
end;

function TAdUser.IsLocked: Boolean;
begin
  Result := (UAC and UAC_LOCKOUT) <> 0;
end;

function TAdUser.IsDisabled: Boolean;
begin
  Result := (UAC and UAC_ACCOUNTDISABLE) <> 0;
end;

function TAdUser.IsExpired: Boolean;
begin
  Result := (UAC and UAC_PASSWORD_EXPIRED) <> 0;
end;

function TAdUser.IsPasswordNeverExpires: Boolean;
begin
  Result := (UAC and UAC_DONT_EXPIRE_PASSWD) <> 0;
end;

function TAdUser.IsAdminProtected: Boolean;
begin
  Result := AdminCount > 0;
end;

function TAdUser.PwdLastSetDate: TDateTime;
begin
  Result := FT(PwdLastSet);
end;

function TAdUser.AccountExpiresDate: TDateTime;
begin
  Result := FT(AccountExpires);
end;

function TAdUser.LastLogonDate: TDateTime;
begin
  Result := FT(LastLogonTimestamp);
end;

function TAdUser.NeverLoggedOn: Boolean;
begin
  Result := (LastLogon = 0) and (LastLogonTimestamp = 0);
end;

function TAdUser.IsAccountExpired: Boolean;
var
  LExp: TDateTime;
begin
  if (AccountExpires = LDAP_ACCOUNTEXPIRES_NEVER_0) or
     (AccountExpires = LDAP_ACCOUNTEXPIRES_NEVER_MAX) then
  begin
    Result := False;
    Exit;
  end;
  LExp   := FT(AccountExpires);
  Result := (LExp > 0) and (LExp < Now);
end;


{ TAdGroup — helpers }

function TAdGroup.IsSecurityGroup: Boolean;
begin
  Result := (GroupType and LDAP_GROUPTYPE_SECURITY) <> 0;
end;

function TAdGroup.IsGlobalGroup: Boolean;
begin
  Result := (GroupType and LDAP_GROUPTYPE_GLOBAL) <> 0;
end;

function TAdGroup.IsUniversalGroup: Boolean;
begin
  Result := (GroupType and LDAP_GROUPTYPE_UNIVERSAL) <> 0;
end;

function TAdGroup.IsDomainLocalGroup: Boolean;
begin
  Result := (GroupType and LDAP_GROUPTYPE_DOMAIN_LOCAL) <> 0;
end;


{ TAdComputer — helpers }

class function TAdComputer.FT(AVal: Int64): TDateTime;
begin
  Result := TAdUser.FT(AVal);   // de-dup: conversao FILETIME->TDateTime canonica em TAdUser.FT
end;

function TAdComputer.IsDisabled: Boolean;
begin
  Result := (UAC and UAC_ACCOUNTDISABLE) <> 0;
end;

function TAdComputer.IsWorkstation: Boolean;
begin
  Result := (UAC and UAC_WORKSTATION_TRUST_ACCOUNT) <> 0;
end;

function TAdComputer.IsDomainController: Boolean;
begin
  Result := (UAC and UAC_SERVER_TRUST_ACCOUNT) <> 0;
end;

function TAdComputer.LastLogonDate: TDateTime;
begin
  Result := FT(LastLogon);
end;

function TAdComputer.PwdLastSetDate: TDateTime;
begin
  Result := FT(PwdLastSet);
end;


{ TAdAttrList }

class function TAdAttrList.Parse(const AList: string): TArray<TAdAttrDef>;
var
  LEntries: TArray<string>;
  LParts:   TArray<string>;
  LDef:     TAdAttrDef;
  LEntry:   string;
  LResult:  TList<TAdAttrDef>;
begin
  LResult := TList<TAdAttrDef>.Create;
  try
    LEntries := AList.Split([',']);
    for LEntry in LEntries do
    begin
      LParts := LEntry.Split([':']);
      if Length(LParts) >= 3 then
      begin
        LDef.AttrName    := LParts[0];
        LDef.ObjectClass := LParts[1];
        LDef.Description := LParts[2];
        LResult.Add(LDef);
      end
      else if Length(LParts) = 2 then
      begin
        LDef.AttrName    := LParts[0];
        LDef.ObjectClass := '*';
        LDef.Description := LParts[1];
        LResult.Add(LDef);
      end;
    end;
    Result := LResult.ToArray;
  finally
    LResult.Free;
  end;
end;

class function TAdAttrList.NamesForClass(const AList, AClass: string): TArray<string>;
var
  LEntries: TArray<string>;
  LParts:   TArray<string>;
  LResult:  TList<string>;
  LEntry:   string;
begin
  LResult := TList<string>.Create;
  try
    LEntries := AList.Split([',']);
    for LEntry in LEntries do
    begin
      LParts := LEntry.Split([':']);
      if Length(LParts) >= 2 then
        if (LParts[1] = '*') or LParts[1].Contains(AClass) then
          LResult.Add(LParts[0]);
    end;
    Result := LResult.ToArray;
  finally
    LResult.Free;
  end;
end;

class function TAdAttrList.DescOf(const AList, AAttrName: string): string;
var
  LEntries: TArray<string>;
  LParts:   TArray<string>;
  LEntry:   string;
begin
  Result   := '';
  LEntries := AList.Split([',']);
  for LEntry in LEntries do
  begin
    LParts := LEntry.Split([':']);
    if (Length(LParts) >= 3) and SameText(LParts[0], AAttrName) then
    begin
      Result := LParts[2];
      Exit;
    end;
  end;
end;


{ TActiveDirectoryMapper<T> — helpers privados }

class function TActiveDirectoryMapper<T>.InternalFileTimeToDateTime(AFileTime: Int64): TDateTime;
begin
  Result := TAdUser.FT(AFileTime);   // de-dup: conversao FILETIME->TDateTime canonica em TAdUser.FT
end;

class function TActiveDirectoryMapper<T>.InternalParseGeneralizedTime(const S: string): TDateTime;
var
  Y, M, D, H, Mi, Se: Integer;
begin
  Result := 0;
  if Length(S) < 14 then Exit;
  try
    Y  := StrToIntDef(Copy(S,  1, 4), 0);
    M  := StrToIntDef(Copy(S,  5, 2), 1);
    D  := StrToIntDef(Copy(S,  7, 2), 1);
    H  := StrToIntDef(Copy(S,  9, 2), 0);
    Mi := StrToIntDef(Copy(S, 11, 2), 0);
    Se := StrToIntDef(Copy(S, 13, 2), 0);
    Result := EncodeDateTime(Y, M, D, H, Mi, Se, 0);
  except
    Result := 0;
  end;
end;

class procedure TActiveDirectoryMapper<T>.SetFieldValue(AInstance: TObject; AField: TRttiField;
  AResult: ILDAPSearchResult; const AAttrName: string; AIsSid: Boolean);
var
  LTypeKind: TTypeKind;
  LVal:      TValue;
  Arr:       TArray<string>;
  FT:        Int64;
  GT:        TDateTime;
  DArrType:  TRttiDynamicArrayType;
begin
  LTypeKind := AField.FieldType.TypeKind;

  // LdapSidAttribute → campo string via AttributeSid
  if AIsSid and (LTypeKind = tkUString) then
  begin
    LVal := TValue.From<string>(AResult.AttributeSid(AAttrName));
    AField.SetValue(AInstance, LVal);
    Exit;
  end;

  case LTypeKind of

    tkUString:
    begin
      LVal := TValue.From<string>(AResult.Attribute(AAttrName));
      AField.SetValue(AInstance, LVal);
    end;

    tkInteger:
    begin
      LVal := TValue.From<Integer>(StrToIntDef(AResult.Attribute(AAttrName), 0));
      AField.SetValue(AInstance, LVal);
    end;

    tkInt64:
    begin
      LVal := TValue.From<Int64>(StrToInt64Def(AResult.Attribute(AAttrName), 0));
      AField.SetValue(AInstance, LVal);
    end;

    tkFloat:
    begin
      // TDateTime é alias de Double (tkFloat); confirmar pelo TypeInfo
      if AField.FieldType.Handle = TypeInfo(TDateTime) then
      begin
        FT := AResult.AttributeFileTime(AAttrName);
        if (FT > 0) and (FT <> Int64($7FFFFFFFFFFFFFFF)) then
          GT := InternalFileTimeToDateTime(FT)
        else
          GT := InternalParseGeneralizedTime(AResult.Attribute(AAttrName));
        LVal := TValue.From<TDateTime>(GT);
        AField.SetValue(AInstance, LVal);
      end;
    end;

    tkRecord:
    begin
      // TGUID — 16 bytes brutos via AttributeGuid
      if AField.FieldType.Handle = TypeInfo(TGUID) then
      begin
        LVal := TValue.From<TGUID>(AResult.AttributeGuid(AAttrName));
        AField.SetValue(AInstance, LVal);
      end;
    end;

    tkDynArray:
    begin
      // TArray<string> — atributo multivalorado
      DArrType := AField.FieldType as TRttiDynamicArrayType;
      if (DArrType.ElementType <> nil) and
         (DArrType.ElementType.TypeKind in [tkUString, tkLString, tkWString]) then
      begin
        Arr  := AResult.AttributeList(AAttrName);
        // cross-compiler: FPC nao aceita TValue.From<TArray<string>> (generic aninhado);
        // TValue.Make + o typeinfo do proprio campo funciona em Delphi e FPC.
        TValue.Make(@Arr, AField.FieldType.Handle, LVal);
        AField.SetValue(AInstance, LVal);
      end;
    end;

  end;
end;


{ TActiveDirectoryMapper<T> — públicos }

class function TActiveDirectoryMapper<T>.FromSearchResult(AResult: ILDAPSearchResult): T;
var
  LCtx:   TRttiContext;
  LType:  TRttiType;
  LField: TRttiField;
  LAttr:  TCustomAttribute;
begin
  Result := T.Create;
  try
    LType := LCtx.GetType(TypeInfo(T));
    for LField in LType.GetDeclaredFields do
      for LAttr in LField.GetAttributes do
      begin
        if LAttr is LdapAttribute then
        begin
          SetFieldValue(TObject(Result), LField, AResult,
                        LdapAttribute(LAttr).AttributeName, False);
          Break;
        end
        else if LAttr is LdapSidAttribute then
        begin
          SetFieldValue(TObject(Result), LField, AResult,
                        LdapSidAttribute(LAttr).AttributeName, True);
          Break;
        end;
      end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

class function TActiveDirectoryMapper<T>.ToModifyList(AObj: T): TStringList;
var
  LCtx:      TRttiContext;
  LType:     TRttiType;
  LField:    TRttiField;
  LAttr:     TCustomAttribute;
  LAttrName: string;
  LVal:      TValue;
  Arr:       TArray<string>;
  S:         string;
  DArrType:  TRttiDynamicArrayType;
  LIdx:      Integer;
begin
  Result := TStringList.Create;
  LType  := LCtx.GetType(TypeInfo(T));
  for LField in LType.GetDeclaredFields do
    for LAttr in LField.GetAttributes do
    begin
      if LAttr is LdapAttribute then
        LAttrName := LdapAttribute(LAttr).AttributeName
      else if LAttr is LdapSidAttribute then
        LAttrName := LdapSidAttribute(LAttr).AttributeName
      else
        Continue;

      LVal := LField.GetValue(TObject(AObj));

      case LField.FieldType.TypeKind of

        tkUString:
          Result.Add(LAttrName + '=' + LVal.AsString);

        tkInteger:
          Result.Add(LAttrName + '=' + IntToStr(LVal.AsInteger));

        tkInt64:
          Result.Add(LAttrName + '=' + IntToStr(LVal.AsInt64));

        tkFloat:
          if LField.FieldType.Handle = TypeInfo(TDateTime) then
            Result.Add(LAttrName + '=' +
              FormatDateTime('yyyymmddhhnnss', LVal.AsType<TDateTime>) + '.0Z');

        tkRecord:
          if LField.FieldType.Handle = TypeInfo(TGUID) then
            Result.Add(LAttrName + '=' + GUIDToString(LVal.AsType<TGUID>));

        tkDynArray:
        begin
          DArrType := LField.FieldType as TRttiDynamicArrayType;
          if (DArrType.ElementType <> nil) and
             (DArrType.ElementType.TypeKind in [tkUString, tkLString, tkWString]) then
          begin
            // cross-compiler: FPC nao aceita LVal.AsType<TArray<string>>; extrai via GetArrayElement.
            SetLength(Arr, LVal.GetArrayLength);
            for LIdx := 0 to High(Arr) do
              Arr[LIdx] := LVal.GetArrayElement(LIdx).AsString;
            for S in Arr do
              Result.Add(LAttrName + '=' + S);
          end;
        end;

      end;

      Break; // próximo campo
    end;
end;

{$ENDIF USE_ATTRIBUTES}

end.
