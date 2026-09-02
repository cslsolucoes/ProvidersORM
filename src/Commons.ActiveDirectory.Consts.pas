{ =============================================================================
  Commons.ActiveDirectory.Consts - Constantes do projeto ActiveDirectory ORM

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.8.0 (ActiveDirectory absorvido do SSOT v1.7.6)
  FileVersion:    1.0.8
  Author:         Claiton de Souza Linhares
  Date:           07/03/2026

  Changelog (file):
  - 1.0.0 (07/03/2026): Versão inicial.
  - 1.0.1 (07/03/2026): Constantes ERR_LDAP_* (faixa 40XXX) para exceções.
  - 1.0.2 (07/03/2026): Constantes LDAP_OBJECTCLASS_* e LDAP_ATTR_* para helpers.
  - 1.0.3 (07/03/2026): LDAP_PORT_DEFAULT (389) e LDAPS_PORT_DEFAULT (636) para uso com SSL.
  - 1.0.4 (07/03/2026): LDAP_ATTR_* e LDAP_OBJECTCLASS_* movidos para Attributers.ActiveDirectory;
                        manter apenas códigos de erro, portas e timeout.
  - 1.0.5 (08/03/2026): ERR_LDAP_WRITE (40006) para operações de escrita LDAP.
  - 1.0.6 (2026-04-13): LDAP_GC_PORT_DEFAULT (3268) e LDAPS_GC_PORT_DEFAULT (3269) para Global Catalog.
  - 1.0.7 (2026-04-13): UAC_* (userAccountControl flags) e LDAP_FILETIME_EPOCH_DAYS para TAdUser e TActiveDirectoryMapper.
  - 1.0.8 (2026-04-14): LDAP_ATTR_* completos (identidade, contato, RH, conta, logon, auditoria,
                        grupo, computador, OU, POSIX); objectClass adicionais; UAC_* extras;
                        LDAP_GROUPTYPE_*; LDAP_ACCOUNTEXPIRES_NEVER_*; LDAP_SAMTYPE_*;
                        AD_ATTR_LIST (catálogo mestre 'attr:objectClass:desc,...').
  ============================================================================= }

unit Commons.ActiveDirectory.Consts;

interface

uses
  Exceptions.Base;   // ERR_ACTIVEDIRECTORY_BASE (faixa canonica MM=95, esquema MMXXXX)

const

  // ---------------------------------------------------------------------------
  // Códigos de erro — faixa MM=95 (ActiveDirectory), rebaseados de
  // ERR_ACTIVEDIRECTORY_BASE (Exceptions.Base) para eliminar os literais 40xxx
  // que colidiam com Connection (MM=40). Zero redundancia: base vem do nucleo.
  // ---------------------------------------------------------------------------

  (** Código base do módulo LDAP; raramente usado diretamente. *)
  ERR_LDAP_BASE            = ERR_ACTIVEDIRECTORY_BASE;         // 950000

  (** Falha de transporte: host inacessível, timeout de socket, Login/Logout. *)
  ERR_LDAP_CONNECTION      = ERR_ACTIVEDIRECTORY_BASE + 1;     // 950001

  (** Bind rejeitado: credenciais inválidas, conta bloqueada ou expirada. *)
  ERR_LDAP_AUTHENTICATION  = ERR_ACTIVEDIRECTORY_BASE + 2;     // 950002

  (** Parâmetro inválido: DN mal formado, atributo vazio, filtro incorreto. *)
  ERR_LDAP_VALIDATION      = ERR_ACTIVEDIRECTORY_BASE + 3;     // 950003

  (** Objeto não encontrado no diretório: usuário, grupo, OU inexistente. *)
  ERR_LDAP_NOT_FOUND       = ERR_ACTIVEDIRECTORY_BASE + 4;     // 950004

  (** Configuração inválida: Host vazio, Port fora de faixa, Version inválida. *)
  ERR_LDAP_CONFIGURATION   = ERR_ACTIVEDIRECTORY_BASE + 5;     // 950005

  (** Falha em operação de escrita LDAP: Modify, Add, Delete ou ModifyDN. *)
  ERR_LDAP_WRITE           = ERR_ACTIVEDIRECTORY_BASE + 6;     // 950006


  // ---------------------------------------------------------------------------
  // Portas padrão LDAP
  // ---------------------------------------------------------------------------

  (** Porta padrão LDAP sem criptografia (RFC 4511). *)
  LDAP_PORT_DEFAULT  = 389;

  (** Porta padrão LDAPS — LDAP sobre TLS/SSL direto (RFC 4513). *)
  LDAPS_PORT_DEFAULT = 636;

  (** Porta padrão LDAP Global Catalog — acesso a todo o forest (AD). *)
  LDAP_GC_PORT_DEFAULT  = 3268;

  (** Porta padrão LDAPS Global Catalog — acesso cifrado a todo o forest (AD). *)
  LDAPS_GC_PORT_DEFAULT = 3269;


  // ---------------------------------------------------------------------------
  // Timeouts
  // ---------------------------------------------------------------------------

  (** Timeout máximo (ms) para tentativa de Bind na autenticação de usuário. *)
  LDAP_AUTH_TIMEOUT_MS = 2000;


  // ---------------------------------------------------------------------------
  // objectClass LDAP/AD comuns
  // ---------------------------------------------------------------------------

  (** Conta de usuário padrão no Active Directory. *)
  LDAP_OBJECTCLASS_USER                = 'user';

  (** Conta de computador no Active Directory. *)
  LDAP_OBJECTCLASS_COMPUTER            = 'computer';

  (** Grupo de segurança ou distribuição do Active Directory. *)
  LDAP_OBJECTCLASS_GROUP               = 'group';

  (** Grupo LDAP genérico (RFC 2256); usado em OpenLDAP e outros diretórios. *)
  LDAP_OBJECTCLASS_GROUPOFNAMES        = 'groupOfNames';

  (** Variante de grupo LDAP com uniqueMember (RFC 2256). *)
  LDAP_OBJECTCLASS_GROUPOFUNIQUENAMES  = 'groupOfUniqueNames';

  (** Entrada de pessoa genérica (RFC 4519). *)
  LDAP_OBJECTCLASS_PERSON              = 'person';

  (** Unidade organizacional — contêiner hierárquico no diretório. *)
  LDAP_OBJECTCLASS_ORGANIZATIONALUNIT  = 'organizationalUnit';

  (** Contêiner genérico do AD (CN=Computers, CN=Users etc.). *)
  LDAP_OBJECTCLASS_CONTAINER           = 'container';

  (** Classe raiz de toda hierarquia LDAP. *)
  LDAP_OBJECTCLASS_TOP                 = 'top';

  (** Domínio DNS — raiz da partição de domínio AD. *)
  LDAP_OBJECTCLASS_DOMAINDNS           = 'domainDNS';


  // ---------------------------------------------------------------------------
  // Atributos LDAP/AD — identificação do objeto
  // ---------------------------------------------------------------------------

  (** GUID único imutável do objeto (16 bytes binários). *)
  LDAP_ATTR_OBJECTGUID              = 'objectGUID';

  (** SID de segurança do objeto (binário). *)
  LDAP_ATTR_OBJECTSID               = 'objectSid';

  (** Categoria do objeto (referência ao schema). *)
  LDAP_ATTR_OBJECTCATEGORY          = 'objectCategory';

  (** Classe do objeto LDAP (pode ser multivalorado). *)
  LDAP_ATTR_OBJECTCLASS             = 'objectClass';

  (** Tipo de conta SAM — veja LDAP_SAMTYPE_*. *)
  LDAP_ATTR_SAMACCOUNTTYPE          = 'sAMAccountType';


  // ---------------------------------------------------------------------------
  // Atributos LDAP/AD — nomenclatura e acesso
  // ---------------------------------------------------------------------------

  (** DN completo do objeto (Distinguished Name). *)
  LDAP_ATTR_DISTINGUISHEDNAME       = 'distinguishedName';

  (** Common Name — nome de exibição do objeto. *)
  LDAP_ATTR_CN                      = 'cn';

  (** Login do usuário no domínio Windows (SAM Account Name). *)
  LDAP_ATTR_SAMACCOUNTNAME          = 'sAMAccountName';

  (** Login completo no formato usuario@dominio.local (UPN). *)
  LDAP_ATTR_USERPRINCIPALNAME       = 'userPrincipalName';

  (** Nome RDN do objeto (geralmente igual ao CN). *)
  LDAP_ATTR_NAME                    = 'name';

  (** Campo de descrição livre do objeto. *)
  LDAP_ATTR_DESCRIPTION             = 'description';

  (** Nome da unidade organizacional (componente RDN). *)
  LDAP_ATTR_OU                      = 'ou';


  // ---------------------------------------------------------------------------
  // Atributos LDAP/AD — identidade pessoal
  // ---------------------------------------------------------------------------

  (** Sobrenome (surname / last name). *)
  LDAP_ATTR_SN                      = 'sn';

  (** Primeiro nome (given name / first name). *)
  LDAP_ATTR_GIVENNAME               = 'givenName';

  (** Nome do meio. *)
  LDAP_ATTR_MIDDLENAME              = 'middleName';

  (** Iniciais do nome. *)
  LDAP_ATTR_INITIALS                = 'initials';

  (** Nome de exibição composto. *)
  LDAP_ATTR_DISPLAYNAME             = 'displayName';

  (** Endereço de e-mail principal. *)
  LDAP_ATTR_MAIL                    = 'mail';

  (** Endereços de e-mail alternativos (multivalorado).
      Formato: smtp:email@dominio.com (lowercase = secundário, SMTP: = primário). *)
  LDAP_ATTR_PROXYADDRESSES          = 'proxyAddresses';


  // ---------------------------------------------------------------------------
  // Atributos LDAP/AD — perfil e contato
  // ---------------------------------------------------------------------------

  (** Cargo / título do usuário (ex.: 'Analista de Sistemas'). *)
  LDAP_ATTR_TITLE                   = 'title';

  (** Departamento do usuário (ex.: 'TI'). *)
  LDAP_ATTR_DEPARTMENT              = 'department';

  (** Empresa / organização do usuário. *)
  LDAP_ATTR_COMPANY                 = 'company';

  (** Nome do escritório / localização física. *)
  LDAP_ATTR_OFFICENAME              = 'physicalDeliveryOfficeName';

  (** Número de telefone principal do escritório. *)
  LDAP_ATTR_TELEPHONENUMBER         = 'telephoneNumber';

  (** Número de celular / telefone móvel. *)
  LDAP_ATTR_MOBILE                  = 'mobile';

  (** Número de fax. *)
  LDAP_ATTR_FAX                     = 'facsimileTelephoneNumber';

  (** Endereço: logradouro. *)
  LDAP_ATTR_STREETADDRESS           = 'streetAddress';

  (** Endereço: localidade / cidade. *)
  LDAP_ATTR_L                       = 'l';

  (** Endereço: estado / província. *)
  LDAP_ATTR_ST                      = 'st';

  (** Endereço: CEP / código postal. *)
  LDAP_ATTR_POSTALCODE              = 'postalCode';

  (** Endereço: caixa postal. *)
  LDAP_ATTR_POSTOFFICEBOX           = 'postOfficeBox';

  (** País — código ISO 2 chars (ex.: 'BR'). *)
  LDAP_ATTR_C                       = 'c';

  (** País — nome completo (ex.: 'Brasil'). *)
  LDAP_ATTR_CO                      = 'co';

  (** DN do gerente direto. *)
  LDAP_ATTR_MANAGER                 = 'manager';

  (** Página web / URL do usuário. *)
  LDAP_ATTR_WWWHOMEPAGE             = 'wWWHomePage';


  // ---------------------------------------------------------------------------
  // Atributos LDAP/AD — RH / sincronização com ERP
  // ---------------------------------------------------------------------------

  (** Matrícula / número do funcionário — chave de sincronização com o RH.
      Confirmar que o AD do cliente preenche este campo antes de usar como PK. *)
  LDAP_ATTR_EMPLOYEEID              = 'employeeID';

  (** Número alternativo de funcionário (RFC 2256). *)
  LDAP_ATTR_EMPLOYEENUMBER          = 'employeeNumber';


  // ---------------------------------------------------------------------------
  // Atributos LDAP/AD — controle de conta
  // ---------------------------------------------------------------------------

  { Flags de estado da conta (bitmask UAC_xxx). }
  LDAP_ATTR_USERACCOUNTCONTROL      = 'userAccountControl';

  (** Última troca de senha (Windows FILETIME como string Int64). *)
  LDAP_ATTR_PWDLASTSET              = 'pwdLastSet';

  (** Expiração da conta (FILETIME; 0 ou $7FFFFFFFFFFFFFFF = nunca). *)
  LDAP_ATTR_ACCOUNTEXPIRES          = 'accountExpires';

  (** Data/hora em que a conta foi bloqueada (FILETIME; 0 = não bloqueada). *)
  LDAP_ATTR_LOCKOUTTIME             = 'lockoutTime';

  (** Tentativas de senha incorreta desde o último logon bem-sucedido. *)
  LDAP_ATTR_BADPWDCOUNT             = 'badPwdCount';

  (** Última tentativa de senha incorreta (FILETIME). *)
  LDAP_ATTR_BADPASSWORDTIME         = 'badPasswordTime';

  (** Número de logons bem-sucedidos da conta. *)
  LDAP_ATTR_LOGONCOUNT              = 'logonCount';

  (** 1 se a conta é membro de grupo protegido (AdminSDHolder). *)
  LDAP_ATTR_ADMINCOUNT              = 'adminCount';

  (** RID do grupo primário (512 = Domain Admins, 513 = Domain Users). *)
  LDAP_ATTR_PRIMARYGROUPID          = 'primaryGroupID';


  // ---------------------------------------------------------------------------
  // Atributos LDAP/AD — logon e política
  // ---------------------------------------------------------------------------

  (** Último logon — apenas no DC autenticador, não replicado. *)
  LDAP_ATTR_LASTLOGON               = 'lastLogon';

  (** Último logon replicado (precisão ~14 dias) — preferir este para auditoria. *)
  LDAP_ATTR_LASTLOGONTIMESTAMP      = 'lastLogonTimestamp';

  (** Último logoff (raramente atualizado em redes modernas). *)
  LDAP_ATTR_LASTLOGOFF              = 'lastLogoff';

  (** Caminho do script de logon relativo ao NETLOGON share. *)
  LDAP_ATTR_SCRIPTPATH              = 'scriptPath';


  // ---------------------------------------------------------------------------
  // Atributos LDAP/AD — auditoria (timestamps de diretório)
  // ---------------------------------------------------------------------------

  (** Data/hora de criação do objeto (generalizedTime). *)
  LDAP_ATTR_WHENCREATED             = 'whenCreated';

  (** Data/hora da última modificação do objeto (generalizedTime). *)
  LDAP_ATTR_WHENCHANGED             = 'whenChanged';


  // ---------------------------------------------------------------------------
  // Atributos LDAP/AD — membros e grupos
  // ---------------------------------------------------------------------------

  (** Lista de membros de um grupo (AD e groupOfNames). *)
  LDAP_ATTR_MEMBER                  = 'member';

  (** Grupos dos quais o objeto é membro. *)
  LDAP_ATTR_MEMBEROF                = 'memberOf';

  (** Lista de membros únicos (groupOfUniqueNames). *)
  LDAP_ATTR_UNIQUEMEMBER            = 'uniqueMember';

  { Tipo e escopo do grupo (bitmask LDAP_GROUPTYPE_xxx). }
  LDAP_ATTR_GROUPTYPE               = 'groupType';


  // ---------------------------------------------------------------------------
  // Atributos LDAP/AD — computador
  // ---------------------------------------------------------------------------

  (** FQDN do host (ex.: 002-1235.cslsolucoes.com.br). *)
  LDAP_ATTR_DNSHOSTNAME             = 'dNSHostName';

  (** Nome do sistema operacional (ex.: 'Windows 11 IoT Enterprise LTSC'). *)
  LDAP_ATTR_OPERATINGSYSTEM         = 'operatingSystem';

  (** Versão do sistema operacional (ex.: '10.0 (26100)'). *)
  LDAP_ATTR_OPERATINGSYSTEMVERSION  = 'operatingSystemVersion';

  (** SPNs do Kerberos — multivalorado (ex.: 'HOST/WN-DC03'). *)
  LDAP_ATTR_SERVICEPRINCIPALNAME    = 'servicePrincipalName';


  // ---------------------------------------------------------------------------
  // Atributos POSIX/Unix (presentes no LDIF e claiton.xml)
  // ---------------------------------------------------------------------------

  (** UID numérico Unix/POSIX. *)
  LDAP_ATTR_UIDNUMBER               = 'uidNumber';

  (** GID primário Unix/POSIX. *)
  LDAP_ATTR_GIDNUMBER               = 'gidNumber';

  (** Diretório home Unix (ex.: '/home/claiton'). *)
  LDAP_ATTR_UNIXHOMEDIRECTORY       = 'unixHomeDirectory';

  (** Shell padrão Unix (ex.: '/bin/bash'). *)
  LDAP_ATTR_LOGINSHELL              = 'loginShell';


  // ---------------------------------------------------------------------------
  // Fragmentos de filtro LDAP prontos para reutilização
  // ---------------------------------------------------------------------------

  { Filtro que retorna qualquer objeto do diretório: (objectClass=*) }
  LDAP_FILTER_OBJECTCLASS_ANY       = '(objectClass=*)';

  (** Filtro que retorna grupos AD, groupOfNames e groupOfUniqueNames. *)
  LDAP_FILTER_OBJECTCLASS_GROUP     =
    '(|(objectClass=group)(objectClass=groupOfNames)(objectClass=groupOfUniqueNames))';

  (** Filtro que retorna objetos de usuário. *)
  LDAP_FILTER_OBJECTCLASS_USER      = '(objectClass=user)';

  (** Filtro que retorna objetos de computador. *)
  LDAP_FILTER_OBJECTCLASS_COMPUTER  = '(objectClass=computer)';

  (** Filtro que retorna unidades organizacionais. *)
  LDAP_FILTER_OBJECTCLASS_OU        = '(objectClass=organizationalUnit)';


  // ---------------------------------------------------------------------------
  // userAccountControl (UAC) — flags de estado da conta AD
  // ---------------------------------------------------------------------------

  (** Conta desabilitada manualmente no ADUC. *)
  UAC_ACCOUNTDISABLE                = $00000002;

  (** Home directory é obrigatório para a conta. *)
  UAC_HOMEDIR_REQUIRED              = $00000008;

  (** Conta bloqueada por excesso de tentativas com senha incorreta. *)
  UAC_LOCKOUT                       = $00000010;

  (** Senha não exigida para a conta. *)
  UAC_PASSWD_NOTREQD                = $00000020;

  (** Usuário não pode alterar a própria senha. *)
  UAC_PASSWD_CANT_CHANGE            = $00000040;

  (** Senha armazenada com criptografia reversível. *)
  UAC_ENCRYPTED_TEXT_PWD            = $00000080;

  (** Conta temporária duplicada (interoperabilidade). *)
  UAC_TEMP_DUPLICATE_ACCOUNT        = $00000100;

  (** Conta de usuário normal (flag base esperado em contas de usuário). *)
  UAC_NORMAL_ACCOUNT                = $00000200;

  (** Conta de trust entre domínios. *)
  UAC_INTERDOMAIN_TRUST_ACCOUNT     = $00000800;

  (** Conta de computador membro do domínio. *)
  UAC_WORKSTATION_TRUST_ACCOUNT     = $00001000;

  (** Conta reservada para domínio controlador. *)
  UAC_SERVER_TRUST_ACCOUNT          = $00002000;

  (** A senha nunca expira. *)
  UAC_DONT_EXPIRE_PASSWD            = $00010000;

  (** Logon requer cartão inteligente. *)
  UAC_SMARTCARD_REQUIRED            = $00040000;

  (** Conta confiável para delegação Kerberos não restrita. *)
  UAC_TRUSTED_FOR_DELEG             = $00080000;

  (** Kerberos não exige pré-autenticação. *)
  UAC_DONT_REQ_PREAUTH              = $00400000;

  (** Senha expirada — usuário deve trocar no próximo logon. *)
  UAC_PASSWORD_EXPIRED              = $00800000;


  // ---------------------------------------------------------------------------
  // groupType bitmask (LDAP_GROUPTYPE_*)
  // ---------------------------------------------------------------------------

  (** Grupo interno do AD (sistema). *)
  LDAP_GROUPTYPE_SYSTEM             = $00000001;

  (** Grupo global — membros do mesmo domínio. *)
  LDAP_GROUPTYPE_GLOBAL             = $00000002;

  (** Grupo local de domínio — membros de qualquer domínio. *)
  LDAP_GROUPTYPE_DOMAIN_LOCAL       = $00000004;

  (** Grupo universal — replicado no Global Catalog. *)
  LDAP_GROUPTYPE_UNIVERSAL          = $00000008;

  (** Bit de segurança; sem ele = grupo de distribuição.
      Ex.: global security = LDAP_GROUPTYPE_GLOBAL or LDAP_GROUPTYPE_SECURITY = -2147483646 *)
  LDAP_GROUPTYPE_SECURITY           = Integer($80000000);


  // ---------------------------------------------------------------------------
  // accountExpires sentinels
  // ---------------------------------------------------------------------------

  (** Conta nunca expira — variante 1 (valor zero). *)
  LDAP_ACCOUNTEXPIRES_NEVER_0       = Int64(0);

  (** Conta nunca expira — variante 2 (valor máximo Int64). *)
  LDAP_ACCOUNTEXPIRES_NEVER_MAX     = Int64($7FFFFFFFFFFFFFFF);


  // ---------------------------------------------------------------------------
  // sAMAccountType (LDAP_SAMTYPE_*)
  // ---------------------------------------------------------------------------

  (** Objeto de grupo. *)
  LDAP_SAMTYPE_GROUP_OBJECT         = 268435456;  // $10000000

  (** Conta de usuário normal. *)
  LDAP_SAMTYPE_USER_OBJECT          = 805306368;  // $30000000

  (** Conta de computador membro do domínio. *)
  LDAP_SAMTYPE_MACHINE_ACCOUNT      = 805306369;  // $30000001


  // ---------------------------------------------------------------------------
  // Conversão FILETIME ↔ TDateTime
  // ---------------------------------------------------------------------------

  (** Dias entre o epoch FILETIME (1601-01-01) e o epoch TDateTime (1899-12-30).
      Usado em: (FileTime - LDAP_FILETIME_EPOCH_DAYS * 864000000000) / 864000000000 = TDateTime. *)
  LDAP_FILETIME_EPOCH_DAYS          = 109205;


  // ---------------------------------------------------------------------------
  // Catálogo mestre de atributos LDAP/AD (AD_ATTR_LIST)
  //
  // Formato de cada entrada: 'atributo:objectClass:Descrição'
  // Entradas separadas por vírgula.
  //
  // objectClass:
  //   *                      = comum a todas as entidades
  //   user                   = apenas TAdUser
  //   group                  = apenas TAdGroup
  //   computer               = apenas TAdComputer
  //   ou                     = apenas TAdOU
  //   user|group|computer    = múltiplas classes (separador | dentro do campo)
  //
  // Para adicionar: incluir nova entrada no final ou na seção correspondente.
  // Extensível: novos campos podem ser adicionados ao final do formato
  // sem quebrar o parsing existente (ex.: 'attr:class:desc:tipo:obrigatorio').
  //
  // Uso com TAdAttrList (Attributers.pas):
  //   TAdAttrList.NamesForClass(AD_ATTR_LIST, 'user')  → TArray<string>
  //   TAdAttrList.DescOf(AD_ATTR_LIST, 'employeeID')   → 'Matrícula (sync RH/ERP)'
  // ---------------------------------------------------------------------------

  AD_ATTR_LIST =
    // --- Comuns a todas as entidades ---
    'objectGUID:*:GUID único imutável do objeto,' +
    'objectSid:*:SID de segurança (S-1-5-21-...),' +
    'distinguishedName:*:DN completo do objeto,' +
    'cn:*:Common Name,' +
    'description:*:Descrição livre,' +
    'whenCreated:*:Data de criação,' +
    'whenChanged:*:Última modificação,' +
    // --- Comuns a user / group / computer ---
    'sAMAccountName:user|group|computer:Login SAM,' +
    'sAMAccountType:user|group|computer:Tipo de conta SAM,' +
    'memberOf:user|computer:Grupos dos quais é membro,' +
    'userAccountControl:user|computer:Flags de estado da conta (UAC),' +
    // --- Usuário ---
    'sn:user:Sobrenome,' +
    'givenName:user:Primeiro nome,' +
    'middleName:user:Nome do meio,' +
    'initials:user:Iniciais,' +
    'displayName:user:Nome de exibição,' +
    'mail:user:E-mail principal,' +
    'proxyAddresses:user:E-mails alternativos (multivalorado),' +
    'userPrincipalName:user:Login UPN (usuario@dominio),' +
    'title:user:Cargo,' +
    'department:user:Departamento,' +
    'company:user:Empresa,' +
    'physicalDeliveryOfficeName:user:Nome do escritório,' +
    'telephoneNumber:user:Telefone,' +
    'mobile:user:Celular,' +
    'facsimileTelephoneNumber:user:Fax,' +
    'streetAddress:user:Logradouro,' +
    'l:user:Cidade,' +
    'st:user:Estado,' +
    'postalCode:user:CEP,' +
    'c:user:País (código ISO 2 chars),' +
    'co:user:País (nome completo),' +
    'manager:user:DN do gerente direto,' +
    'wWWHomePage:user:Página web,' +
    'employeeID:user:Matrícula (sync RH/ERP),' +
    'employeeNumber:user:Número alternativo de funcionário,' +
    'pwdLastSet:user:Última troca de senha (FILETIME),' +
    'accountExpires:user:Expiração da conta (FILETIME),' +
    'lockoutTime:user:Data do bloqueio (FILETIME),' +
    'badPwdCount:user:Tentativas incorretas de senha,' +
    'logonCount:user:Total de logons bem-sucedidos,' +
    'adminCount:user:Membro de grupo protegido (AdminSDHolder),' +
    'primaryGroupID:user:RID do grupo primário,' +
    'scriptPath:user:Caminho do script de logon,' +
    'lastLogon:user:Último logon - apenas no DC autenticador,' +
    'lastLogonTimestamp:user:Último logon replicado (~14 dias),' +
    // --- Grupo ---
    'groupType:group:Tipo e escopo do grupo (bitmask),' +
    'member:group:Membros do grupo (multivalorado),' +
    // --- Computador ---
    'dNSHostName:computer:FQDN do host,' +
    'operatingSystem:computer:Sistema operacional,' +
    'operatingSystemVersion:computer:Versão do SO,' +
    'lastLogon:computer:Último logon do computador (FILETIME),' +
    'pwdLastSet:computer:Última renovação de senha do computador,' +
    'logonCount:computer:Total de logons do computador,' +
    'servicePrincipalName:computer:SPNs Kerberos (multivalorado),' +
    // --- Unidade Organizacional ---
    'ou:ou:Nome da OU (componente RDN)';


implementation

end.
