{ =============================================================================
  ActiveDirectory.Main.Interfaces - Interfaces públicas do núcleo LDAP

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.9.0 (F8 Onda 8.6 — SetLogger)
  FileVersion:    1.8.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           08/08/2026

  Interfaces exportadas:
    ILDAPSearchResult          — resultado tipado de uma entrada LDAP
    IActiveDirectoryConnection — fluent builder de configuração de conexão
    IActiveDirectoryService    — operações LDAP: leitura e escrita

  Changelog (file):
  - 1.8.0 (08/08/2026): F8 Onda 8.6 -- SetLogger(const ALogger: ILogger) em
    IActiveDirectoryService, appended ao fim do vtable (mesmo padrao do
    SetSearchLogCallback V1.6.0), guardado por define USE_LOGGERS (unit nao
    dependia de ORM.Defines.inc ate agora -- include acrescentado). Ver
    ActiveDirectory.Service.pas para a implementacao (piggyback em
    LogLDAPSearch, sem novo ponto de chamada).
  - 1.0.0 (07/03/2026): IActiveDirectoryConnection, IActiveDirectoryService.
  - 1.0.2 (08/03/2026): Métodos de escrita LDAP em IActiveDirectoryService
                        (SetAttributeValue, AddAttributeValue, DeleteAttributeValue,
                         SetAttributes, AddObject, DeleteObject, RenameObject,
                         AddMemberToGroup, RemoveMemberFromGroup, ChangePassword).
  - 1.1.0 (2026-04-13): ILDAPSearchResult; fluentes TlsMode/CAFile/PageSize/UseGlobalCatalog
                        em IActiveDirectoryConnection; GetUserDirectoryData, GetTransitiveGroups,
                        GetAncestorOUs, SearchUsersPage, SetPassword, ForcePasswordChange
                        em IActiveDirectoryService.
  - 1.2.0 (2026-04-14): AttributeSid em ILDAPSearchResult para decodificação de objectSid
                        binário → 'S-1-5-21-...' (string legível).
  - 1.4.0 (2026-04-20): Paridade com Version.Old — 10 métodos Find* / SearchBy* em
                        IActiveDirectoryService (FindObjectByAttribute, FindUserByAttribute,
                        FindComputerByAttribute, GetObjectDetailsByAttribute,
                        SearchObjectsByAttribute, FindObjectsByMultipleAttributes,
                        FindObjectBySAMAccountName, FindUserBySAMAccountName,
                        FindComputerBySAMAccountName, GetObjectDetailsBySAMAccountName).
                        Ver .cursor/plans/activedirectory-orm-parity_V1.0.plan.md.
  - 1.6.0 (2026-04-21): Paridade final com Version.Old/LogLDAPSearch --
                        TLDAPSearchLogProc (method-of-object) + SetSearchLogCallback
                        appended ao fim do vtable de IActiveDirectoryService.
                        GUID preservado (A1B2C3D4-...). Binario compativel com
                        v1.4.x e v1.5.x (Dual OpenSSL).
                        Plano master: ok-reescreva-para-fica-swift-narwhal.md.
  - 1.7.6 (2026-04-24): V1.7.6 Documentation refresh -- FileVersion bumpado
                        para alinhar com ProjectVersion. Zero alteracao nos
                        contratos (GUID, ordem de metodos, assinaturas).
                        Binario compativel com v1.4.x..v1.7.x.
  ============================================================================= }

unit ActiveDirectory.Main.Interfaces;

interface

{$I ../../ORM.Defines.inc}

uses
  Commons.ActiveDirectory.Types,
{$IFDEF FPC}
  Classes, fpjson, SysUtils
{$ELSE}
  System.Classes, System.JSON, System.SysUtils
{$ENDIF}
{$IFDEF USE_LOGGERS}
  , Loggers.Interfaces
{$ENDIF}
  ;

type

  // ===========================================================================
  // TLDAPSearchLogProc — callback de telemetria de buscas LDAP (V1.6.0)
  // ===========================================================================

  (** Callback de telemetria disparado pelo serviço após cada operação de busca
      (ExecuteLDAPSearch, SearchAllOUs, FindUserDN, SearchUserInOU,
      SearchWithCustomFilter). Usado para logging estruturado, APM, métricas e
      auditoria — paridade funcional com Version.Old/LogLDAPSearch.

      Tipo method-of-object (compat Delphi 12.x + FPC 3.3.1+). Consumidores
      declaram o handler com qualquer nome de parâmetro — Pascal vincula por
      posição + tipo, não por nome.

      @param AOperation    Nome lógico da operação. Ex: 'ExecuteLDAPSearch',
                           'FindUserDN', 'SearchAllOUs (consolidado)'.
      @param ABaseDN       DN base da busca (vazio quando não aplicável).
      @param AFilter       Filtro LDAP RFC 4515.
      @param AElapsedMs    Duração da operação em milissegundos (Int64).
      @param AResultCount  Número de entradas retornadas.
      @param ASuccess      True se o servidor aceitou a busca (ainda que zero
                           resultados).
      @param AErrorMessage Mensagem de erro em caso de ASuccess=False; ''
                           caso contrário. *)
  TLDAPSearchLogProc = procedure(const AOperation, ABaseDN, AFilter: string;
    AElapsedMs: Int64; AResultCount: Integer;
    ASuccess: Boolean; const AErrorMessage: string) of object;


  // ===========================================================================
  // ILDAPSearchResult
  // ===========================================================================

  (** Resultado tipado de uma entrada LDAP.
      Envolve TLDAPResult do Synapse expondo a API em string Unicode,
      sem expor AnsiString ao chamador.

      Uso:
        LResult := FSvc.GetUserDirectoryData(LUserDN, ['mail','sAMAccountName']);
        if LResult <> nil then
          ShowMessage(LResult.Attribute('mail'));
  *)
  ILDAPSearchResult = interface
    ['{C3D4E5F6-A7B8-4C9D-8E0F-1A2B3C4D5E6F}']

    (** DN completo da entrada (distinguishedName / ObjectName do Synapse).
        Decodificado de UTF-8 para string Unicode. *)
    function DN: string;

    (** Primeiro valor do atributo AName; '' se o atributo estiver ausente.
        Decodificado de UTF-8 para string Unicode.
        @param AName  Nome do atributo LDAP. Ex: 'mail', 'sAMAccountName'. *)
    function Attribute(const AName: string): string;

    (** Todos os valores de um atributo multivalorado.
        Ex: 'memberOf' retorna os DNs de todos os grupos do objeto.
        @param AName  Nome do atributo. *)
    function AttributeList(const AName: string): TArray<string>;

    (** Valor do atributo AName como TGUID.
        Usado para objectGUID (16 bytes brutos little-endian do AD).
        Retorna TGuid vazio se o atributo estiver ausente ou tiver tamanho errado.
        @param AName  Ex: 'objectGUID'. *)
    function AttributeGuid(const AName: string): TGuid;

    (** Valor do atributo AName como Int64 (Windows FILETIME).
        Usado para pwdLastSet, lastLogon, whenChanged (100 ns desde 1601-01-01).
        Converter para TDateTime com TLDAPSend.FileTimeToDateTime.
        @param AName  Ex: 'pwdLastSet', 'lastLogon'. *)
    function AttributeFileTime(const AName: string): Int64;

    (** Decodifica um atributo SID binário (objectSid) e retorna no formato
        'S-1-5-21-...' (string legível).
        Estrutura do SID:
          Byte 0:     Revision
          Byte 1:     SubAuthorityCount (N)
          Bytes 2..7: IdentifierAuthority (6 bytes big-endian)
          Bytes 8+:   N × SubAuthority (4 bytes little-endian cada)
        Retorna '' se o atributo não existir ou os bytes forem inválidos (< 8 bytes).
        @param AName  Ex: 'objectSid'. *)
    function AttributeSid(const AName: string): string;
  end;




  // ===========================================================================
  // IActiveDirectoryConnection
  // ===========================================================================

  (** Interface fluente para configuração de conexão LDAP.
      Todos os setters retornam Self, permitindo encadeamento:
        TActiveDirectory.New
          .Host('dc.empresa.local')
          .Port(389)
          .BaseDN('DC=empresa,DC=local')
          .BaseAuth('CN=ldap,CN=Users,DC=empresa,DC=local')
          .Password('secret')
          .AddSearchOU('OU=Usuarios,DC=empresa,DC=local')
          .GetConfig;
  *)
  IActiveDirectoryConnection = interface
    ['{B5E7D2A1-8C4F-4E9B-A1D3-2F6E8C0B5A7D}']

    // ── Setters fluentes ──────────────────────────────────────────────────────

    (** Define o endereço IP ou hostname do servidor LDAP/AD.
        @param AValue  Ex: '10.0.74.3' ou 'dc.empresa.local'. *)
    function Host(const AValue: string): IActiveDirectoryConnection;

    (** Define a porta de conexão.
        UseSSL(True) ajusta automaticamente 389 → 636.
        @param AValue  Padrão: 389 (LDAP) ou 636 (LDAPS). *)
    function Port(AValue: Integer): IActiveDirectoryConnection;

    (** Define o DN base para todas as pesquisas.
        @param AValue  Ex: 'DC=empresa,DC=local'. *)
    function BaseDN(const AValue: string): IActiveDirectoryConnection;

    (** Define o DN da conta administrativa usada nos Bind de leitura e escrita.
        @param AValue  Ex: 'CN=ldapusers,CN=Users,DC=empresa,DC=local'. *)
    function BaseAuth(const AValue: string): IActiveDirectoryConnection;

    (** Define o sAMAccountName para uso no TestConnection.
        @param AValue  Ex: 'ldapusers'. *)
    function Username(const AValue: string): IActiveDirectoryConnection;

    (** Define a senha da conta administrativa (BaseAuth / Username).
        @param AValue  Senha em texto claro; trafega cifrada apenas com LDAPS. *)
    function Password(const AValue: string): IActiveDirectoryConnection;

    (** Ativa ou desativa SSL/TLS (retrocompatibilidade).
        True  → tmLDAPSNoCertCheck inferido; porta ajustada para 636.
        False → tmNone; porta 389 sem TLS.
        Preferir TlsMode() para controle granular.
        @param AValue  True para LDAPS, False para LDAP simples. *)
    function UseSSL(AValue: Boolean): IActiveDirectoryConnection;

    (** Define o modo TLS da conexão.
        Substitui UseSSL() para controle mais granular.
        tmNone            — porta 389, sem criptografia.
        tmStartTLS        — porta 389, STARTTLS upgrade.
        tmLDAPSNoCertCheck — porta 636, SSL sem validar CA (AD interno).
        tmLDAPSWithCA     — porta 636, SSL com validação de CA (produção).
        @param AMode  Valor do enum TTlsMode. *)
    function TlsMode(AMode: TTlsMode): IActiveDirectoryConnection;

    (** Caminho do arquivo CA PEM para validação de certificado do servidor.
        Usado somente quando TlsMode = tmLDAPSWithCA.
        @param APath  Caminho absoluto. Ex: 'C:\certs\empresa-ca.pem'. *)
    function CAFile(const APath: string): IActiveDirectoryConnection;

    (** Tamanho da página para SearchUsersPage (paginação LDAP RFC 2696).
        @param ASize  Número de entradas por página. Padrão: 1000. *)
    function PageSize(ASize: Integer): IActiveDirectoryConnection;

    (** Usa Global Catalog (porta 3268 / 3269 com LDAPS) para consultas forest-wide.
        Ajusta a porta automaticamente conforme TlsMode configurado.
        True  → 3268 (sem TLS / StartTLS) ou 3269 (LDAPS).
        False → 389 ou 636 (padrão).
        @param AValue  True para ativar GC. *)
    function UseGlobalCatalog(AValue: Boolean): IActiveDirectoryConnection;

    (** Define o timeout de socket em milissegundos.
        @param AValue  Ex: 30000 (30 s). Padrão recomendado: 5000–30000. *)
    function TimeOut(AValue: Integer): IActiveDirectoryConnection;

    (** Define a versão do protocolo LDAP.
        @param AValue  2 ou 3. Active Directory requer versão 3. *)
    function Version(AValue: Integer): IActiveDirectoryConnection;

    // ── AddSearchOU (4 sobrecargas) ───────────────────────────────────────────

    (** Acrescenta uma OU à lista de bases de pesquisa de usuários.
        @param AOU  DN da OU. Ex: 'OU=Usuarios,DC=empresa,DC=local'. *)
    function AddSearchOU(const AOU: string): IActiveDirectoryConnection; overload;

    (** Acrescenta múltiplas OUs a partir de um TStringList (um DN por linha).
        @param AOU  Lista de DNs de OUs. *)
    function AddSearchOU(const AOU: TStringList): IActiveDirectoryConnection; overload;

    (** Acrescenta múltiplas OUs a partir de um TJSONArray de strings.
        @param AOU  Array JSON com DNs. Ex: ["OU=TI,...","OU=RH,..."] *)
    function AddSearchOU(const AOU: TJSONArray): IActiveDirectoryConnection; overload;

    (** Acrescenta OUs a partir de um TJSONObject.
        Aceita chave "SearchOUs", "searchOUs" ou "Data" contendo um array.
        @param AOU  Objeto JSON com lista de OUs. *)
    function AddSearchOU(const AOU: TJSONObject): IActiveDirectoryConnection; overload;

    // ── Leitura / escrita de configuração ─────────────────────────────────────

    (** Retorna um TActiveDirectoryConfig (record) com a configuração atual.
        Usado para passar a configuração para TActiveDirectoryService.Create. *)
    function GetConfig: TActiveDirectoryConfig;

    (** Carrega configuração completa a partir de um TJSONObject.
        Chaves suportadas (case-sensitive): Host, Port, BaseDN, BaseAuth,
        Username, Password, UseSSL, TimeOut, Version, SearchOUs (array).
        @param AConfig  Objeto JSON com as chaves acima. *)
    function SetConfig(const AConfig: TJSONObject): IActiveDirectoryConnection; overload;

    (** Carrega apenas a lista de SearchOUs a partir de um TJSONArray de strings.
        Não altera Host, Port nem outras configurações de conexão.
        @param AConfig  Array JSON com DNs de OUs. *)
    function SetConfig(const AConfig: TJSONArray): IActiveDirectoryConnection; overload;

    (** Carrega configuração a partir de um TStringList no formato "Chave=Valor".
        @param AConfig  Lista com pares "Host=...", "Port=...", etc. *)
    function SetConfig(const AConfig: TStringList): IActiveDirectoryConnection; overload;

    (** Copia todos os campos de um TActiveDirectoryConfig para a configuração interna.
        @param AConfig  Record TActiveDirectoryConfig já preenchido. *)
    function SetConfig(const AConfig: TActiveDirectoryConfig): IActiveDirectoryConnection; overload;
  end;


  // ===========================================================================
  // IActiveDirectoryService
  // ===========================================================================

  (** Interface principal de operações LDAP.
      Obtida via TActiveDirectoryService.New(LCfg) ou TActiveDirectoryService.Create(LCfg).
      Agrupa operações de leitura (conexão, autenticação, pesquisa, listagem)
      e operações de escrita (modificar atributos, criar/excluir objetos,
      gerenciar membros de grupos, alterar senha). *)
  IActiveDirectoryService = interface
    ['{A1B2C3D4-E5F6-4A7B-8C9D-0E1F2A3B4C5D}']

    // ── Conexão ───────────────────────────────────────────────────────────────

    (** Abre a conexão TCP com o servidor LDAP (TLDAPSend.Login).
        Não realiza Bind — apenas estabelece o socket.
        @returns True se conectado com sucesso; False caso contrário.
                 Em falha, detalhes ficam em GetLastError. *)
    function Connect: Boolean;

    (** Encerra a conexão TCP (TLDAPSend.Logout).
        @returns True se desconectado com sucesso. *)
    function Disconnect: Boolean;

    (** Conecta e faz Bind com Username/Password para validar as credenciais.
        Útil para verificar se o serviço está acessível antes de usar.
        @returns True se conexão e Bind foram bem-sucedidos. *)
    function TestConnection: Boolean;

    // ── Autenticação ──────────────────────────────────────────────────────────

    (** Localiza o DN do usuário nas SearchOUs configuradas e autentica via Bind.
        Pesquisa por CN, distinguishedName, sAMAccountName e userPrincipalName.
        @param AUsername  Login do usuário (sAMAccountName ou nome completo).
        @param APassword  Senha do usuário.
        @returns True se o usuário foi encontrado e o Bind teve sucesso. *)
    function Authenticate(const AUsername, APassword: string): Boolean;

    (** Autentica diretamente com o DN completo do usuário (Bind direto).
        Mais rápido que Authenticate quando o DN já é conhecido.
        @param AUserDN    DN completo. Ex: 'CN=Joao,OU=TI,DC=empresa,DC=local'.
        @param APassword  Senha do usuário.
        @returns True se o Bind com AUserDN/APassword foi aceito pelo servidor. *)
    function AuthenticateUser(const AUserDN, APassword: string): Boolean;

    // ── Status ────────────────────────────────────────────────────────────────

    (** Retorna uma string formatada com Host, Port, SSL e estado de conexão.
        Ex: "Servidor: dc.local:389 | SSL: False | Conectado: True" *)
    function GetServerInfo: string;

    (** Retorna o estado atual da conexão como texto legível,
        acrescentando o LastError se houver.
        Ex: "Conectado" ou "Desconectado - Erro ao conectar..." *)
    function GetConnectionStatus: string;

    (** True se a conexão TCP estiver estabelecida. *)
    function GetConnected: Boolean;

    (** Última mensagem de erro gerada por qualquer operação.
        Acrescenta o ResultString e ResultCode do Synapse quando disponíveis. *)
    function GetLastError: string;

    (** Acrescenta uma OU à lista de SearchOUs em tempo de execução.
        Não adiciona duplicatas.
        @param OU  DN da OU a ser acrescentada. *)
    procedure AddSearchOU(const OU: string);

    // ── Listagem de objetos ────────────────────────────────────────────────────

    (** Lista os DNs de todos os objetos imediatamente filhos de ContainerDN
        (escopo OneLevel).
        @param ContainerDN  DN do contêiner. Ex: 'OU=TI,DC=empresa,DC=local'.
        @returns TStringList com os DNs encontrados. O chamador deve liberar. *)
    function ListContainerObjects(const ContainerDN: string): TStringList;

    (** Lista objetos filhos de ContainerDN com informações de classe.
        Cada linha retornada tem o formato: "[objectClass] CommonName"
        @param ContainerDN  DN do contêiner.
        @returns TStringList formatada. O chamador deve liberar. *)
    function ListContainerObjectsDetailed(const ContainerDN: string): TStringList;

    // ── Atributos de objeto ────────────────────────────────────────────────────

    (** Retorna todos os atributos de um objeto como lista "nome=valor".
        A primeira linha é sempre "DN=<dn>".
        @param ObjectDN  DN do objeto a consultar.
        @returns TStringList com pares "atributo=valor". O chamador deve liberar. *)
    function GetObjectAttributes(const ObjectDN: string): TStringList;

    (** Versão formatada de GetObjectAttributes para exibição direta.
        Inclui cabeçalho "=== ATRIBUTOS DO OBJETO ===" e o DN.
        @param ObjectDN  DN do objeto.
        @returns String multilinha pronta para exibição em Memo/Label. *)
    function GetObjectAttributesFormatted(const ObjectDN: string): string;

    (** Retorna o valor do atributo objectClass do objeto.
        @param ObjectDN  DN do objeto.
        @returns String com o objectClass (Ex: 'user', 'group'). 'unknown' se não encontrado. *)
    function GetObjectClass(const ObjectDN: string): string;

    // ── Grupos ────────────────────────────────────────────────────────────────

    (** Lista os DNs de todos os grupos encontrados nas SearchOUs configuradas.
        @returns TStringList com DNs de grupos. O chamador deve liberar. *)
    function ListGroups: TStringList;

    (** Lista os DNs de grupos dentro de uma OU específica (escopo SubTree).
        Filtra por group, groupOfNames e groupOfUniqueNames.
        @param OUDN  DN da OU a pesquisar.
        @returns TStringList com DNs de grupos. O chamador deve liberar. *)
    function ListGroupsInOU(const OUDN: string): TStringList;

    (** Versão detalhada de ListGroups: retorna "[GRUPO] CN (DN)" por linha.
        @returns TStringList formatada. O chamador deve liberar. *)
    function ListGroupsDetailed: TStringList;

    (** Retorna os DNs dos membros do atributo 'member' (ou uniqueMember) do grupo.
        @param GroupDN  DN do grupo.
        @returns TStringList com DNs dos membros. O chamador deve liberar. *)
    function GetGroupMembers(const GroupDN: string): TStringList;

    (** Versão detalhada de GetGroupMembers: "[MEMBRO] CN (DN)" por linha.
        Inclui cabeçalho "=== MEMBROS DO GRUPO ===".
        @param GroupDN  DN do grupo.
        @returns TStringList formatada. O chamador deve liberar. *)
    function GetGroupMembersDetailed(const GroupDN: string): TStringList;

    (** Verifica se UserDN consta no atributo 'member' do grupo (comparação case-insensitive).
        @param UserDN   DN do usuário a verificar.
        @param GroupDN  DN do grupo alvo.
        @returns True se UserDN está na lista de membros. *)
    function IsUserMemberOfGroup(const UserDN, GroupDN: string): Boolean;

    // ── Pesquisa ──────────────────────────────────────────────────────────────

    (** Executa uma pesquisa LDAP genérica com filtro e atributos customizados.
        Usa escopo SubTree a partir de BaseDN.
        @param BaseDN     DN raiz da pesquisa.
        @param Filter     Filtro LDAP (RFC 4515). Ex: '(sAMAccountName=joao)'.
        @param Attributes Lista de atributos desejados; nil retorna atributos padrão.
        @returns TStringList com DNs encontrados. O chamador deve liberar. *)
    function SearchObjects(const BaseDN, Filter: string; const Attributes: TStringList = nil): TStringList;

    (** Pesquisa com filtro customizado nas SearchOUs configuradas (ou em BaseDN se informado).
        Requer que a conexão já esteja estabelecida (Connect chamado antes).
        @param CustomFilter  Filtro LDAP completo. Ex: '(&(objectClass=user)(department=TI))'.
        @param BaseDN        Se vazio, pesquisa em todas as SearchOUs. *)
    function SearchWithCustomFilter(const CustomFilter: string; const BaseDN: string): TStringList;

    // ── Busca por atributo (paridade legado V1.4.0) ───────────────────────────

    (** Pesquisa genérica por atributo=valor em todas as SearchOUs configuradas.
        Se ObjectType for informado, restringe a um objectClass específico.
        @param AttributeName  Nome do atributo. Ex: 'mail', 'cn', 'department'.
        @param AttributeValue Valor desejado. Ex: 'joao@empresa.local'.
        @param ObjectType     objectClass opcional. Ex: 'user', 'computer', 'group'.
        @returns TStringList com DNs encontrados; o chamador deve liberar. *)
    function FindObjectByAttribute(const AttributeName, AttributeValue: string;
      const ObjectType: string = ''): TStringList;

    (** Atalho para FindObjectByAttribute(AttrName, AttrValue, 'user'). *)
    function FindUserByAttribute(const AttributeName, AttributeValue: string): TStringList;

    (** Atalho para FindObjectByAttribute(AttrName, AttrValue, 'computer'). *)
    function FindComputerByAttribute(const AttributeName, AttributeValue: string): TStringList;

    (** Busca por atributo e retorna os atributos de cada resultado em formato
        "DN=<dn>" + pares "nome=valor" (igual a GetObjectAttributesFormatted).
        @param AttributeName  Nome do atributo.
        @param AttributeValue Valor a procurar.
        @returns TStringList multi-bloco (um bloco por objecto). *)
    function GetObjectDetailsByAttribute(const AttributeName, AttributeValue: string): TStringList;

    (** Busca por atributo filtrando por múltiplos objectClass alternativos (OR).
        Filtro gerado: (&(|(objectClass=T1)(objectClass=T2)...)(attr=value))
        @param AttributeName  Nome do atributo.
        @param AttributeValue Valor a procurar.
        @param ObjectTypes    Array de objectClass (ex: ['user','computer']).
                              Array vazio equivale a FindObjectByAttribute(..., '').
        @returns TStringList com DNs. *)
    function SearchObjectsByAttribute(const AttributeName, AttributeValue: string;
      const ObjectTypes: array of string): TStringList;

    (** Busca por AND de múltiplos pares atributo=valor, opcionalmente filtrada
        por objectClass. Filtro gerado: (&(attr1=val1)(attr2=val2)...(objectClass=X)).
        Contrato idêntico ao Version.Old:176-178 (nome + sequência de tipos).
        @param AAttributes  Array com nomes dos atributos.
        @param AValues      Array com valores (mesmo tamanho que AAttributes).
        @param AObjectType  objectClass opcional.
        @returns TStringList com DNs.
        @raises EADValidationException se Length(AAttributes) <> Length(AValues). *)
    function FindObjectsByMultipleAttributes(const AAttributes, AValues: array of string;
      const AObjectType: string = ''): TStringList;

    (** Busca por sAMAccountName — atalho para FindObjectByAttribute('sAMAccountName', ...).
        @param SAMAccountName Nome de logon (sem domínio).
        @param ObjectType     objectClass opcional.
        @returns TStringList com DNs. *)
    function FindObjectBySAMAccountName(const SAMAccountName: string;
      const ObjectType: string = ''): TStringList;

    (** Atalho para FindObjectBySAMAccountName(SAMAccountName, 'user'). *)
    function FindUserBySAMAccountName(const SAMAccountName: string): TStringList;

    (** Atalho para FindObjectBySAMAccountName(SAMAccountName, 'computer'). *)
    function FindComputerBySAMAccountName(const SAMAccountName: string): TStringList;

    (** Detalhes formatados por sAMAccountName — atalho para
        GetObjectDetailsByAttribute('sAMAccountName', ...). *)
    function GetObjectDetailsBySAMAccountName(const SAMAccountName: string): TStringList;

    // ── Utilitários ───────────────────────────────────────────────────────────

    (** Valida se DN é minimamente correto (não vazio e contém '=').
        @param DN  String a validar.
        @returns True se o DN é não vazio e tem ao menos um '='. *)
    function ValidateDN(const DN: string): Boolean;

    (** Extrai o componente CN= do DN.
        @param DN  DN completo.
        @returns Valor do CN. Retorna o DN original se CN= não for encontrado. *)
    function GetCommonName(const DN: string): string;

    // ── Exportação JSON ───────────────────────────────────────────────────────

    (** Exporta Host, Port, BaseDN, Connected e LastError como TJSONObject.
        @returns TJSONObject alocado; o chamador deve liberar. *)
    function ToJSON: TJSONObject;

    (** Exporta a lista de SearchOUs como TJSONArray de strings.
        @returns TJSONArray alocado; o chamador deve liberar. *)
    function ToJSONArray: TJSONArray;


    // =========================================================================
    // Operações de escrita LDAP
    // Requerem: credenciais com permissão de escrita no AD (BaseAuth/Password).
    // Padrão interno: Connect → BindAsAdmin → operação → AppendLDAPResultToLastError.
    // =========================================================================

    // ── Modificação de atributos ──────────────────────────────────────────────

    (** Substitui o valor de um atributo por AAttrValue (MO_Replace).
        Se AAttrValue = '' o atributo é esvaziado (valor removido).
        @param ADN        DN do objeto alvo.
        @param AAttrName  Nome do atributo. Ex: 'telephoneNumber'.
        @param AAttrValue Novo valor. Ex: '(11) 99999-1234'.
        @returns True se a operação foi aceita pelo servidor.
        @raises EADValidationException se DN ou AttrName inválidos.
        @raises EADWriteException      se Connect ou Bind falharem. *)
    function SetAttributeValue(const ADN, AAttrName, AAttrValue: string): Boolean;

    (** Acrescenta AAttrValue a um atributo multivalorado (MO_Add).
        Uso típico: adicionar endereço proxy, número de telefone alternativo.
        @param ADN        DN do objeto alvo.
        @param AAttrName  Nome do atributo multivalorado. Ex: 'proxyAddresses'.
        @param AAttrValue Valor a acrescentar. Ex: 'smtp:joao@empresa.local'.
        @returns True se aceito pelo servidor.
        @raises EADValidationException se DN ou AttrName inválidos.
        @raises EADWriteException      se Connect ou Bind falharem. *)
    function AddAttributeValue(const ADN, AAttrName, AAttrValue: string): Boolean;

    (** Remove um valor específico de atributo (AAttrValue preenchido)
        ou remove o atributo inteiro do objeto (AAttrValue = '') via MO_Delete.
        @param ADN        DN do objeto alvo.
        @param AAttrName  Nome do atributo. Ex: 'description'.
        @param AAttrValue Valor específico a remover; '' remove o atributo todo.
        @returns True se aceito pelo servidor.
        @raises EADValidationException se DN ou AttrName inválidos.
        @raises EADWriteException      se Connect ou Bind falharem. *)
    function DeleteAttributeValue(const ADN, AAttrName: string; const AAttrValue: string = ''): Boolean;

    (** Substitui múltiplos atributos em uma única chamada (um Modify por par).
        AAttributes deve conter linhas no formato "nome=valor".
        Linhas sem '=' são ignoradas silenciosamente.
        @param ADN         DN do objeto alvo.
        @param AAttributes Lista de pares "atributo=valor".
        @returns True se todos os Modify foram aceitos; False se qualquer um falhou
                 (GetLastError acumula os erros intermediários).
        @raises EADValidationException se DN inválido ou lista vazia.
        @raises EADWriteException      se Connect ou Bind falharem. *)
    function SetAttributes(const ADN: string; const AAttributes: TStringList): Boolean;

    // ── Ciclo de vida de objetos ──────────────────────────────────────────────

    (** Cria um novo objeto LDAP com o DN e atributos fornecidos (operação Add).
        AAttributes deve incluir obrigatoriamente 'objectClass=<classe>'.
        @param ADN         DN do novo objeto. Ex: 'CN=Novo,OU=TI,DC=empresa,DC=local'.
        @param AAttributes Lista "nome=valor" incluindo objectClass.
        @returns True se o objeto foi criado com sucesso.
        @raises EADValidationException se DN inválido ou lista vazia.
        @raises EADWriteException      se Connect, Bind ou Add falharem. *)
    function AddObject(const ADN: string; const AAttributes: TStringList): Boolean;

    (** Remove definitivamente um objeto LDAP pelo DN (operação Delete).
        Objetos com filhos precisam ser esvaziados antes.
        @param ADN  DN do objeto a remover.
        @returns True se removido com sucesso.
        @raises EADValidationException se DN inválido.
        @raises EADWriteException      se Connect, Bind ou Delete falharem. *)
    function DeleteObject(const ADN: string): Boolean;

    (** Renomeia e/ou move um objeto LDAP (operação ModifyDN).
        @param ADN           DN atual do objeto.
        @param ANewRDN       Novo componente RDN. Ex: 'CN=Novo Nome'.
        @param ANewParentDN  DN do novo contêiner pai. '' mantém o pai atual.
        @param ADeleteOldRDN True remove o RDN antigo (comportamento padrão do AD).
        @returns True se a operação foi aceita.
        @raises EADValidationException se ADN vazio ou ANewRDN vazio.
        @raises EADWriteException      se Connect, Bind ou ModifyDN falharem. *)
    function RenameObject(const ADN, ANewRDN, ANewParentDN: string; ADeleteOldRDN: Boolean = True): Boolean;

    // ── Membros de grupo ──────────────────────────────────────────────────────

    (** Acrescenta AUserDN ao atributo 'member' do grupo AGroupDN (MO_Add).
        @param AUserDN   DN do usuário (ou objeto) a adicionar.
        @param AGroupDN  DN do grupo alvo.
        @returns True se aceito pelo servidor.
        @raises EADValidationException se qualquer DN for inválido.
        @raises EADWriteException      se Connect ou Bind falharem. *)
    function AddMemberToGroup(const AUserDN, AGroupDN: string): Boolean;

    (** Remove AUserDN do atributo 'member' do grupo AGroupDN (MO_Delete).
        @param AUserDN   DN do usuário (ou objeto) a remover.
        @param AGroupDN  DN do grupo alvo.
        @returns True se aceito pelo servidor.
        @raises EADValidationException se qualquer DN for inválido.
        @raises EADWriteException      se Connect ou Bind falharem. *)
    function RemoveMemberFromGroup(const AUserDN, AGroupDN: string): Boolean;

    // ── Senha ─────────────────────────────────────────────────────────────────

    (** Altera a senha de um usuário no Active Directory via atributo unicodePwd.
        REQUISITO: a conexão deve usar LDAPS (TlsMode = tmLDAPSNoCertCheck ou tmLDAPSWithCA).
        O Active Directory rejeita alteração de senha em canal não cifrado.
        Codificação interna: '"senha"' convertida para UTF-16LE (bytes brutos)
        conforme exigido pelo protocolo do AD. Equivalente a um reset administrativo
        (MO_Replace em unicodePwd). Para troca autenticada (usuário conhece a senha
        antiga), usar ChangePasswordUser (futuro).
        @param AUserDN      DN do usuário alvo.
        @param ANewPassword Nova senha em texto claro (sem aspas).
        @returns True se a senha foi alterada com sucesso.
        @raises EADWriteException      se TlsMode plain, Connect ou Bind falharem.
        @raises EADValidationException se DN vazio ou senha vazia. *)
    function ChangePassword(const AUserDN, ANewPassword: string): Boolean;


    // =========================================================================
    // Operações AD avançadas (requerem TLDAPSend 001.007.002)
    // =========================================================================

    // ── Dados de usuário ──────────────────────────────────────────────────────

    (** Busca atributos de um objeto pelo DN completo (escopo BaseObject).
        Retorna nil se o objeto não for encontrado.
        Atributos recomendados: sAMAccountName, mail, userPrincipalName,
        memberOf, objectGUID, whenChanged, userAccountControl, distinguishedName.
        @param AUserDN     DN completo do objeto LDAP.
        @param AAttributes Array de nomes de atributos a solicitar ao servidor.
        @returns ILDAPSearchResult com os atributos; nil se não encontrado. *)
    function GetUserDirectoryData(const AUserDN: string;
      const AAttributes: TArray<string>): ILDAPSearchResult;

    (** Retorna DNs de todos os grupos dos quais AUserDN é membro,
        incluindo membros aninhados (transitivo via LDAP_MATCHING_RULE_IN_CHAIN).
        @param AUserDN  DN completo do usuário.
        @returns Array de DNs de grupo; array vazio se nenhum. *)
    function GetTransitiveGroups(const AUserDN: string): TArray<string>;

    (** Extrai as OUs ancestrais do DN via parse de string — sem chamada LDAP.
        Retorna as OUs do mais próximo ao mais distante.
        Ex: 'CN=João,OU=TI,OU=Brasil,DC=empresa,DC=local'
        → ['OU=TI,OU=Brasil,DC=empresa,DC=local', 'OU=Brasil,DC=empresa,DC=local']
        @param AUserDN  DN de qualquer objeto LDAP.
        @returns Array de strings com o DN de cada OU ancestral. *)
    function GetAncestorOUs(const AUserDN: string): TArray<string>;

    (** Pesquisa paginada acumulando todas as páginas (usa TLDAPSend.SearchAllPages).
        Útil para exportar >1000 objetos sem limite de paginação.
        @param AFilter     Filtro LDAP. Ex: '(objectClass=user)'.
        @param AAttributes Atributos desejados por entrada.
        @param APageSize   Entradas por página (padrão: 1000).
        @returns Array de ILDAPSearchResult com todos os resultados acumulados. *)
    function SearchUsersPage(const AFilter: string;
      const AAttributes: TArray<string>;
      APageSize: Integer = 1000): TArray<ILDAPSearchResult>;

    // ── Senha avançada ────────────────────────────────────────────────────────

    (** Reset administrativo de senha (MO_Replace em unicodePwd).
        Equivalente a "Redefinir senha" no ADUC; não exige senha anterior.
        REQUISITO: TlsMode = tmLDAPSNoCertCheck ou tmLDAPSWithCA (porta 636).
        @param AUserDN      DN do usuário alvo.
        @param ANewPassword Nova senha em texto claro.
        @returns True se aceito pelo AD. *)
    function SetPassword(const AUserDN, ANewPassword: string): Boolean;

    (** Força troca de senha no próximo logon (pwdLastSet := 0).
        O usuário será obrigado a definir nova senha ao entrar.
        @param AUserDN  DN do usuário alvo.
        @returns True se aceito pelo AD. *)
    function ForcePasswordChange(const AUserDN: string): Boolean;


    // ── Telemetria / Observabilidade (V1.6.0) ─────────────────────────────────

    (** Regista um callback para receber telemetria de todas as operações
        de busca LDAP. Chamado após ExecuteLDAPSearch, SearchAllOUs, FindUserDN,
        SearchUserInOU e SearchWithCustomFilter. Passar `nil` remove o callback.

        Em builds DEBUG, quando nenhum callback está registado, o log estruturado
        é acumulado automaticamente em GetLastError (estilo Version.Old:1593-1630).

        Método appended ao fim do vtable -- binário compatível com v1.4.x e
        v1.5.x (Dual OpenSSL). GUID da interface preservado.

        @param ACallback  Handler method-of-object; tipo TLDAPSearchLogProc. *)
    procedure SetSearchLogCallback(ACallback: TLDAPSearchLogProc);

{$IFDEF USE_LOGGERS}
    (** Injeta um ILogger para observabilidade estrutural das operações de
        busca LDAP (F8 Onda 8.6 — retrofit transversal). Complementa
        SetSearchLogCallback (telemetria de baixo nível, method-of-object):
        SetLogger emite via o mesmo hook existente (LogLDAPSearch), nível
        Debug em sucesso / Warning em falha — nenhum ponto de chamada novo.
        Default = TNullLogger (zero overhead); ALogger = nil reverte ao
        default. Método appended ao fim do vtable -- binário compatível com
        v1.4.x..v1.8.x. GUID da interface preservado. Inerte sob
        USE_LOGGERS off (método nem existe nesse build).
        @param ALogger  Instância ILogger; nil reverte a TNullLogger. *)
    procedure SetLogger(const ALogger: ILogger);
{$ENDIF}
  end;


implementation

end.
