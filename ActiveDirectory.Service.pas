{ =============================================================================
  ActiveDirectory.Service - Implementação do serviço LDAP via Synapse

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.9.0 (F8 Onda 8.6 — SetLogger)
  FileVersion:    1.9.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           08/08/2026

  Changelog (file, summary):
  - 1.9.0 (08/08/2026): F8 Onda 8.6 -- SetLogger(const ALogger: ILogger) em
    TActiveDirectoryService (+ delegate em TServiceLDAP), guardado por
    define USE_LOGGERS. Piggyback no hook LogLDAPSearch ja existente
    (emite Debug/Warning sempre, antes do FLogCallback/Exit -- nao adiciona
    ponto de chamada novo). Default FLogger = TNullLogger (zero overhead).
    bug-1158: esta unit nunca incluia ORM.Defines.inc -- corrigido (ver
    comentario no uses clause); ativa ssl_openssl3 pela 1a vez (era sempre
    dead code, caia no ssl_openssl legado); VerifyCert:=False inalterado em
    tmStartTLS/tmLDAPSNoCertCheck (owner: manter inseguro por agora -- CA
    interna nao validavel em alguns ambientes).
  - 1.5.3 (07/03/2026): Versao anterior consolidada.
  - 1.7.6 (24/04/2026): Bump de header para alinhar FileVersion com ProjectVersion
                        (1.7.6 -- Documentation refresh). Zero alteracao de logica
                        nesta revisao. Historico fino das V1.6.x/V1.7.x esta em
                        src/Commons/ActiveDirectory.Version.pas (SSOT do release).
  - 1.8.1 (08/07/2026): [fix governado, estrategia C — correcao no lugar] Dois
                        bug-fixes de comportamento em metodos publicos:
                        * bug-097: GetGroupMembers passa a adicionar 1 DN por
                          membro (antes GetAttributeValue achatava o multivalor
                          'member'/'uniqueMember' numa unica string). Corrige em
                          cascata GetGroupMembersDetailed e IsUserMemberOfGroup
                          (que agora devolve True para membros reais).
                        * bug-099: GetObjectDetailsByAttribute/BySAMAccountName
                          deixam de emitir a entrada vazia final (o separador ''
                          passa a ser inserido ENTRE blocos).
                        BREAKING (comportamento, nao assinatura): o output de
                        GetGroupMembers muda de 1 entrada-blob para N entradas.
                        Consumidores no workspace = apenas ferramentas de teste
                        (display-only); nenhum dependia do comportamento antigo.

  Compilado apenas quando USE_LDAP está definido (ORM.Defines.inc).

  Responsabilidades:
    - TActiveDirectoryService: implementação completa de IActiveDirectoryService
      com operações de leitura (Connect, Authenticate, List*, Search*,
      GetObjectAttributes, GetGroupMembers, etc.) e operações de escrita LDAP
      (SetAttributeValue, AddObject, DeleteObject, RenameObject,
      AddMemberToGroup, RemoveMemberFromGroup, ChangePassword).
    - TServiceLDAP: wrapper de compatibilidade retroativa para código legado
      que usa a API do Exemplo anterior.

  Dependências externas (Synapse):
    - ldapsend.pas: TLDAPSend, TLDAPAttribute, TLDAPAttributeList, TLDAPModifyOp
    - ssl_openssl: plugin OpenSSL necessário para LDAPS (porta 636)
    - synautil: utilitários de string do Synapse

  Encoding:
    - Todos os valores enviados ao Synapse passam por Utf8EncodeToAnsi
      (string Unicode → AnsiString UTF-8 bytes).
    - Todos os valores recebidos passam por Utf8DecodeFromAnsi / FixUtf8Mojibake
      (UTF-8 estrito; bytes inválidos caem em fallback Latin-1 por byte para não
      levantar EEncodingError; atributos ;binary em hex em GetAttributeValue).

  Changelog (file):
  - 1.0.0 (07/03/2026): TActiveDirectoryService; conversão do Exemplo para núcleo.
  - 1.0.1 (07/03/2026): LDAPS (porta 636): FullSSL; AutoTLS apenas para StartTLS na 389.
  - 1.0.2 (07/03/2026): ssl_openssl para carregar libeay32/ssleay32 e permitir porta 636.
  - 1.0.3 (08/03/2026): VerifyCert := False para aceitar certificado AD interno.
  - 1.0.4 (07/03/2026): Decodificação UTF-8 de ObjectName e atributos (acentos).
  - 1.0.5 (07/03/2026): Encoding UTF-8 de DNs e filtros enviados ao Synapse.
  - 1.0.6 (08/03/2026): Operações de escrita LDAP (BindAsAdmin + 10 métodos write).
  - 1.1.0 (2026-04-13): Fase A — TTlsMode: construtor aplica case FConfig.TlsMode em vez
                        de if UseSSL hardcoded; helper IsSSLPort; cópia de TlsMode/CAFile/PageSize.
  - 1.2.0 (2026-04-13): Fase B — TLDAPSearchResultAdapter (ILDAPSearchResult com cópia de dados);
                        GetUserDirectoryData, GetTransitiveGroups, GetAncestorOUs,
                        SearchUsersPage (via TLDAPSend.SearchAllPages), SetPassword,
                        ForcePasswordChange (delegam a TLDAPSend 001.007.002).
  - 1.3.0 (2026-04-14): AttributeSid em TLDAPSearchResultAdapter — decodificação de
                        objectSid binário (RawValues) → 'S-1-5-21-...' (string legível).
  - 1.4.0 (2026-04-20): Paridade com Version.Old —
                        * 10 métodos Find*/SearchBy* em TActiveDirectoryService:
                          FindObjectByAttribute, FindUserByAttribute,
                          FindComputerByAttribute, GetObjectDetailsByAttribute,
                          SearchObjectsByAttribute, FindObjectsByMultipleAttributes,
                          FindObjectBySAMAccountName, FindUserBySAMAccountName,
                          FindComputerBySAMAccountName, GetObjectDetailsBySAMAccountName.
                        * Wrapper TServiceLDAP ampliado: delega agora toda a
                          superfície pública do legado (Connect/Auth/List*/Groups/
                          Search*/Validate/Attributes/Find*) — drop-in legacy.
                        * Helpers privados: BuildAttributeFilter, BuildMultiClassFilter,
                          BuildMultiAttributeFilter.
                        Ver .cursor/plans/_completed/activedirectory-orm-parity_V1.0.plan.md.
  - 1.5.0 (2026-04-21): Dual OpenSSL — uses condicional ssl_openssl / ssl_openssl3 /
                        ssl_openssl4 via USE_OPENSSL3/USE_OPENSSL4 em ORM.Defines.inc.
                        Bloco initialization opt-in chama TOpenSSLPaths.Apply(N) quando
                        USE_OPENSSL3 ou USE_OPENSSL4. Comportamento V1.4.0 preservado
                        quando sem define (ssl_openssl legacy + sem SetDllDirectory).
                        Ver .cursor/plans/activedirectoryorm-openssl-dual_V1.0.plan.md.
  - 1.5.1 (2026-04-21): Utf8DecodeFromAnsi / FixUtf8Mojibake / DecodeStr — decodificação
                        UTF-8 tolerante (fallback Latin-1 por byte). GetObjectAttributes:
                        atributos Synapse IsBinary (;binary) exibidos em hex. Evita
                        EEncodingError no loop de GetObjectAttributes (AD + wildcard *).
  - 1.5.2 (2026-04-22): TLDAPSearchResultAdapter.Create: RawValues[j] passa a usar
                        LAttr.GetRawValueAt(j) em vez de LAttr[j] (indexador Get).
                        Com Synapse V41.3 o Get() ja converte os bytes conforme FValueType
                        (vtGUID devolve string GUID; vtSID devolve S-1-5-...) tornando o
                        campo RawValues inutil para AttributeGuid e AttributeSid.
                        GetRawValueAt preserva os bytes brutos do socket (inclui
                        DecodeBase64 se IsBinary). Efeito: objectGUID e objectSid passam
                        a ser mapeados correctamente pelo TActiveDirectoryMapper<TAdUser>.
  - 1.5.3 (2026-04-22): ExecuteLDAPSearch: FLDAPSend.Search envolvido em try/except
                        para capturar excepcoes de socket Synapse (evita AV no caller).
                        SearchAllOUs: FLDAPSend.Bind envolvido em try/except; bloco
                        try/except externo envolve todo o corpo para capturar qualquer
                        excepcao Synapse e registar em LErrorMsg -- evita AV em
                        btnFindMultiClick quando LList ficava nil por excepcao propagada.
                        Reconnect automatico transparente: quando Bind falha (socket
                        expirado), faz Logout+Connect+Bind uma vez antes de desistir.
                        Elimina necessidade de desconectar/reconectar manualmente na
                        aba Avancado apos conexao estabelecida na aba Conexao.
  ============================================================================= }
{$DEFINE USE_LDAP}
{$IFDEF USE_LDAP}
unit ActiveDirectory.Service;

interface

{$I ../../ORM.Defines.inc}

uses
  ActiveDirectory.Main.Interfaces,
  Commons.ActiveDirectory.Types,
  Commons.ActiveDirectory.Consts,
  Attributers.ActiveDirectory,
  Exceptions.ActiveDirectory,
  ActiveDirectory.Helpers,
{$IFDEF FPC}
  Classes, SysUtils, DateUtils, fpjson,
{$ELSE}
  System.Classes, System.SysUtils, System.DateUtils, System.JSON,
{$ENDIF}
{$IFDEF USE_LOGGERS}
  Loggers.Interfaces,
  Loggers.NullLogger,
{$ENDIF}
  { OpenSSL version selector (ver ORM.Defines.inc):
    - USE_OPENSSL4 : ssl_openssl4 (fork CSL, OpenSSL 4.0 dll/v4)
    - USE_OPENSSL3 : ssl_openssl3 (Synapse oficial, OpenSSL 3.x dll/v3)
    - nenhum       : ssl_openssl (legacy 1.0/1.1, comportamento V1.4.0)
    bug-1158 (08/08/2026): esta unit NUNCA incluiu ORM.Defines.inc antes -
    USE_OPENSSL3/4 eram sempre indefinidos aqui e o ramo caia sempre no
    ssl_openssl legado, apesar do default do projeto ser USE_OPENSSL3 ON.
    O include acrescentado acima corrige isso (agora ativa ssl_openssl3 de
    facto). Cert check inalterado: ApplyTlsMode ja fixa VerifyCert:=False em
    tmStartTLS/tmLDAPSNoCertCheck (Synapse TCustomSSL.VerifyCert, comum a
    qualquer plugin) - "inseguro" por default nesses 2 modos, como antes;
    tmLDAPSWithCA continua a validar CA real para quem configurar assim. }
  {$IFDEF USE_OPENSSL4}
  ssl_openssl4,
  ssl_openssl_paths,
  {$ELSE}
    {$IFDEF USE_OPENSSL3}
    ssl_openssl3,
    ssl_openssl_paths,
    {$ELSE}
    ssl_openssl,   { V1.4.0 compat: sem ssl_openssl_paths, sem SetDllDirectory }
    {$ENDIF}
  {$ENDIF}
  ldapsend, synautil;

type

  // ===========================================================================
  // TLDAPSearchResultAdapter — adaptador ILDAPSearchResult sobre TLDAPResult
  // ===========================================================================

  { Par nome→valores de um atributo LDAP copiado para o adapter.
    Values    = valores decodificados UTF-8 para string (uso geral).
    RawValues = bytes brutos do Synapse antes de qualquer decodificação
                (necessário para atributos binários como objectGUID). }
  TLDAPAttrEntry = record
    Name:      string;
    Values:    TArray<string>;
    RawValues: TArray<AnsiString>;
  end;

  (** Implementação concreta de ILDAPSearchResult.
      Copia os dados do TLDAPResult no constructor — completamente independente
      do ciclo de vida do TLDAPResultList original.
      Criada internamente por TActiveDirectoryService; não instanciar diretamente. *)
  TLDAPSearchResultAdapter = class(TInterfacedObject, ILDAPSearchResult)
  private
    FDN:    string;
    FAttrs: array of TLDAPAttrEntry;
    function FindAttrIdx(const AName: string): Integer;
    class function DecodeStr(const A: AnsiString): string; static;
  public
    constructor Create(AResult: TLDAPResult);
    function DN: string;
    function Attribute(const AName: string): string;
    function AttributeList(const AName: string): TArray<string>;
    function AttributeGuid(const AName: string): TGuid;
    function AttributeFileTime(const AName: string): Int64;
    function AttributeSid(const AName: string): string;
  end;


  // ===========================================================================
  // TActiveDirectoryService
  // ===========================================================================

  (** Implementação concreta de IActiveDirectoryService usando Synapse (TLDAPSend).
      Fornece operações de leitura LDAP (conexão, autenticação, listagem, pesquisa)
      e operações de escrita LDAP (modificar atributos, criar/excluir objetos,
      gerenciar membros de grupos, alterar senha via unicodePwd).

      Ciclo de vida recomendado:
        LSvc := TActiveDirectoryService.Create(LCfg);
        try
          if LSvc.Connect then
          begin
            LSvc.Authenticate('usuario', 'senha');
            LSvc.SetAttributeValue(DN, 'telephoneNumber', '9999-0000');
          end;
        finally
          LSvc.Free;  // ou LSvc := nil se via interface
        end;

      Observações de encoding:
        - Toda string enviada ao Synapse passa por Utf8EncodeToAnsi.
        - Todo resultado recebido passa por Utf8DecodeFromAnsi / FixUtf8Mojibake
          (UTF-8 tolerante; fallback Latin-1; binários ;binary em hex).
      Compilação: requer {$DEFINE USE_LDAP} em ORM.Defines.inc. *)
  TActiveDirectoryService = class(TInterfacedObject, IActiveDirectoryService)
  private
    // ── Campos internos ──────────────────────────────────────────────────────
    FConfig: TActiveDirectoryConfig;              // cópia completa da configuração recebida no Create
    FLDAPSend: TLDAPSend;              // objeto Synapse que gerencia o socket LDAP
    FConnected: Boolean;               // True após Login bem-sucedido
    FLastError: string;                // acumulador de erros para GetLastError
    FLogCallback: TLDAPSearchLogProc;  // V1.6.0 -- callback opt-in de telemetria
{$IFDEF USE_LOGGERS}
    FLogger: ILogger;                  // F8 Onda 8.6 -- default TNullLogger (zero overhead)
{$ENDIF}

    // ── Helpers privados ─────────────────────────────────────────────────────

    { Acrescenta ResultString e ResultCode do Synapse a FLastError.
      Chamado após qualquer operação que retorne False. }
    procedure AppendLDAPResultToLastError;

    { Recria o TLDAPSend do zero (Logout + Free + Create + ApplyTlsMode).
      Unica forma fiavel de recuperar um socket TCP morto no Synapse. }
    procedure ResetLDAPSend;

    { Garante ligacao valida com Bind antes de qualquer operacao Search.
      Se o socket estiver morto, chama ResetLDAPSend + Connect + Bind.
      Retorna True se a ligacao esta pronta para uso. }
    function ReconnectIfNeeded: Boolean;

    { V1.6.0 -- Emite log estruturado de uma operação de busca.
      Se FLogCallback estiver registado, chama-o com os parâmetros.
      Caso contrário, em builds DEBUG, acumula em FLastError no formato
      estilo Version.Old:1593-1630 (sem emojis -- mais grep-friendly).
      Nome + sequência de tipos idênticos ao Version.Old:105-107. }
    procedure LogLDAPSearch(const AOperation, ABaseDN, AFilter: string;
                            const AStartTime: TDateTime;
                            AResultCount: Integer;
                            ASuccess: Boolean;
                            const AErrorMessage: string = '');

    { Extrai o valor de um TLDAPAttribute como string Unicode.
      Atributos multivalorados são unidos por ", ". }
    function GetAttributeValue(const AAttribute: TLDAPAttribute): string;

    { Converte AnsiString UTF-8 (bytes Synapse) para string Unicode Delphi/FPC. }
    function Utf8DecodeFromAnsi(const A: AnsiString): string;

    { Converte string Unicode Delphi/FPC para AnsiString UTF-8 (bytes Synapse). }
    function Utf8EncodeToAnsi(const S: string): AnsiString;

    { Corrige "mojibake" UTF-8 — string com bytes UTF-8 interpretados como Latin-1.
      Usado quando o dado já foi decodificado incorretamente pelo Synapse. }
    function FixUtf8Mojibake(const S: string): string;

    { Localiza o DN de AUsername nas SearchOUs configuradas via Bind administrativo.
      Percorre FConfig.SearchOUs, chama SearchUserInOU em cada uma.
      Retorna '' se o usuário não for encontrado. }
    function FindUserDN(const AUsername: string): string;

    { Executa busca em uma única OU pelo filtro BuildUserSearchFilter(AUsername).
      Retorna o ObjectName (DN) do primeiro resultado ou '' se vazio. }
    function SearchUserInOU(const AUsername, ABaseDN: string): string;

    { Executa pesquisa LDAP SubTree em ABaseDN com AFilter e AAttributes.
      Retorna TStringList com os DNs encontrados. O chamador deve liberar. }
    function ExecuteLDAPSearch(const ABaseDN, AFilter: string; const AAttributes: TStringList): TStringList;

    { Faz Bind como conta administrativa (FConfig.BaseAuth / FConfig.Password).
      Usado por todos os métodos de escrita antes de chamar Modify/Add/Delete.
      Retorna True se o Bind foi aceito; False e acumula erro em FLastError. }
    function BindAsAdmin: Boolean;

    { Retorna True se APort é uma porta SSL/LDAPS padrão (636 ou 3269 GC). }
    class function IsSSLPort(APort: Integer): Boolean;

    { Configura FLDAPSend conforme FConfig.TlsMode.
      Chamado no constructor e em reconexões. }
    procedure ApplyTlsMode;

    { Constrói filtro '(&(objectClass=X)(attr=value))' ou '(attr=value)' se ObjectType=''. }
    class function BuildAttributeFilter(const AAttrName, AAttrValue, AObjectType: string): string; static;

    { Constrói filtro '(&(|(objectClass=a)(objectClass=b)...)(attr=value))'.
      Se AObjectTypes vazio, equivale a BuildAttributeFilter com ObjectType=''. }
    class function BuildMultiClassFilter(const AAttrName, AAttrValue: string;
      const AObjectTypes: array of string): string; static;

    { Constrói filtro AND de múltiplos pares + objectClass opcional:
      (&(attr1=val1)(attr2=val2)...(objectClass=X)) ou sem o último termo se ObjectType=''. }
    class function BuildMultiAttributeFilter(const ANames, AValues: array of string;
      const AObjectType: string): string; static;

    { Loop padrão em FConfig.SearchOUs aplicando AFilter; deduplica DNs por case-insensitive. }
    function SearchAllOUs(const AFilter: string): TStringList;

  public
    // ── Construção / destruição ───────────────────────────────────────────────

    (** Cria o serviço copiando AConfig internamente e configurando o TLDAPSend.
        LDAPS (porta 636): ativa FullSSL + desativa verificação de certificado.
        STARTTLS (porta 389 + UseSSL=True): ativa AutoTLS.
        @param AConfig  Configuração de conexão obtida via TActiveDirectory.New...GetConfig. *)
    constructor Create(const AConfig: TActiveDirectoryConfig);

    (** Libera o TLDAPSend e o TStringList interno de SearchOUs. *)
    destructor Destroy; override;

    (** Factory method — retorna a instância como IActiveDirectoryService
        (referência contada, liberação automática).
        @param AConfig  Configuração de conexão.
        @returns Interface gerenciada pelo compilador. *)
    class function New(const AConfig: TActiveDirectoryConfig): IActiveDirectoryService;

    // ── Conexão ───────────────────────────────────────────────────────────────

    (** Abre o socket TCP com o servidor (TLDAPSend.Login).
        Não autentica — use Authenticate ou BindAsAdmin após Connect.
        @returns True se o socket foi estabelecido com sucesso. *)
    function Connect: Boolean;

    (** Fecha o socket (TLDAPSend.Logout) e marca FConnected := False.
        @returns True se desconectado sem exceções. *)
    function Disconnect: Boolean;

    (** Conecta e faz Bind com Username/Password para verificar acesso.
        @returns True se Connect + Bind foram aceitos pelo servidor. *)
    function TestConnection: Boolean;

    // ── Autenticação ──────────────────────────────────────────────────────────

    (** Localiza o DN do usuário nas SearchOUs e autentica via Bind direto.
        @param AUsername  sAMAccountName, CN ou UPN do usuário.
        @param APassword  Senha do usuário. *)
    function Authenticate(const AUsername, APassword: string): Boolean;

    (** Autentica diretamente com o DN completo (mais rápido que Authenticate).
        @param AUserDN   DN completo do usuário.
        @param APassword Senha do usuário. *)
    function AuthenticateUser(const AUserDN, APassword: string): Boolean;

    // ── Status e diagnóstico ──────────────────────────────────────────────────

    (** Retorna "Servidor: host:porta | SSL: X | Conectado: Y". *)
    function GetServerInfo: string;

    (** Retorna "Conectado" ou "Desconectado" com LastError acrescentado se houver. *)
    function GetConnectionStatus: string;

    (** True se a conexão TCP estiver ativa (FConnected = True). *)
    function GetConnected: Boolean;

    (** Última mensagem de erro acumulada; '' se nenhuma operação falhou. *)
    function GetLastError: string;

    (** Acrescenta uma OU à lista de pesquisa em tempo de execução (sem duplicatas).
        @param OU  DN da OU. Ex: 'OU=Usuarios,DC=empresa,DC=local'. *)
    procedure AddSearchOU(const OU: string);

    // ── Listagem de objetos ────────────────────────────────────────────────────

    (** Lista DNs de objetos filhos diretos de ContainerDN (escopo OneLevel).
        @param ContainerDN  DN do contêiner pai. *)
    function ListContainerObjects(const ContainerDN: string): TStringList;

    (** Lista objetos filhos com formato "[objectClass] CommonName" por linha.
        @param ContainerDN  DN do contêiner pai. *)
    function ListContainerObjectsDetailed(const ContainerDN: string): TStringList;

    // ── Atributos de objeto ────────────────────────────────────────────────────

    (** Retorna todos os atributos do objeto como lista "nome=valor".
        Primeira linha: "DN=<dn>".
        @param ObjectDN  DN do objeto. *)
    function GetObjectAttributes(const ObjectDN: string): TStringList;

    (** Versão formatada de GetObjectAttributes para exibição direta em Memo.
        @param ObjectDN  DN do objeto. *)
    function GetObjectAttributesFormatted(const ObjectDN: string): string;

    (** Retorna o objectClass do objeto ('user', 'group', etc.).
        @param ObjectDN  DN do objeto. *)
    function GetObjectClass(const ObjectDN: string): string;

    // ── Grupos ────────────────────────────────────────────────────────────────

    (** Lista DNs de todos os grupos nas SearchOUs configuradas. *)
    function ListGroups: TStringList;

    (** Lista DNs de grupos dentro de uma OU específica (SubTree).
        @param OUDN  DN da OU. *)
    function ListGroupsInOU(const OUDN: string): TStringList;

    (** Lista grupos com formato "[GRUPO] CN (DN)" por linha. *)
    function ListGroupsDetailed: TStringList;

    (** Retorna DNs dos membros do atributo 'member' (ou uniqueMember) do grupo.
        @param GroupDN  DN do grupo. *)
    function GetGroupMembers(const GroupDN: string): TStringList;

    (** Versão detalhada de GetGroupMembers: "[MEMBRO] CN (DN)" por linha.
        @param GroupDN  DN do grupo. *)
    function GetGroupMembersDetailed(const GroupDN: string): TStringList;

    (** Verifica se UserDN está na lista de membros do grupo (case-insensitive).
        @param UserDN   DN do usuário.
        @param GroupDN  DN do grupo. *)
    function IsUserMemberOfGroup(const UserDN, GroupDN: string): Boolean;

    // ── Pesquisa ──────────────────────────────────────────────────────────────

    (** Pesquisa genérica SubTree com filtro e atributos customizados.
        @param BaseDN     DN raiz da pesquisa.
        @param Filter     Filtro LDAP RFC 4515.
        @param Attributes Lista de atributos; nil usa atributos padrão. *)
    function SearchObjects(const BaseDN, Filter: string; const Attributes: TStringList): TStringList;

    (** Pesquisa com filtro customizado nas SearchOUs (ou em BaseDN específico).
        Requer Connect previamente chamado.
        @param CustomFilter  Filtro LDAP completo.
        @param BaseDN        Se '', pesquisa em todas as SearchOUs. *)
    function SearchWithCustomFilter(const CustomFilter: string; const BaseDN: string): TStringList;

    // ── Busca por atributo (paridade legado V1.4.0) ───────────────────────────

    (** Busca em todas as SearchOUs por (attr=value), opcionalmente filtrada por objectClass.
        @param AttributeName   Ex: 'mail', 'cn', 'department'.
        @param AttributeValue  Valor a procurar.
        @param ObjectType      objectClass; '' = qualquer classe. *)
    function FindObjectByAttribute(const AttributeName, AttributeValue: string;
      const ObjectType: string = ''): TStringList;

    (** Atalho: FindObjectByAttribute(AttrName, AttrValue, 'user'). *)
    function FindUserByAttribute(const AttributeName, AttributeValue: string): TStringList;

    (** Atalho: FindObjectByAttribute(AttrName, AttrValue, 'computer'). *)
    function FindComputerByAttribute(const AttributeName, AttributeValue: string): TStringList;

    (** Detalhes formatados (1 bloco por objecto encontrado). *)
    function GetObjectDetailsByAttribute(const AttributeName, AttributeValue: string): TStringList;

    (** Busca filtrando por OR de múltiplos objectClass (ex: user|computer|group). *)
    function SearchObjectsByAttribute(const AttributeName, AttributeValue: string;
      const ObjectTypes: array of string): TStringList;

    (** Busca por AND de múltiplos pares atributo=valor.
        Contrato idêntico ao Version.Old:176-178 (nome + sequência de tipos).
        @raises EADValidationException se Length(AAttributes) <> Length(AValues). *)
    function FindObjectsByMultipleAttributes(const AAttributes, AValues: array of string;
      const AObjectType: string = ''): TStringList;

    (** Atalho: FindObjectByAttribute('sAMAccountName', SAMAccountName, ObjectType). *)
    function FindObjectBySAMAccountName(const SAMAccountName: string;
      const ObjectType: string = ''): TStringList;

    (** Atalho: FindObjectBySAMAccountName(SAMAccountName, 'user'). *)
    function FindUserBySAMAccountName(const SAMAccountName: string): TStringList;

    (** Atalho: FindObjectBySAMAccountName(SAMAccountName, 'computer'). *)
    function FindComputerBySAMAccountName(const SAMAccountName: string): TStringList;

    (** Detalhes formatados por sAMAccountName. *)
    function GetObjectDetailsBySAMAccountName(const SAMAccountName: string): TStringList;

    // ── Utilitários ───────────────────────────────────────────────────────────

    (** Valida se DN é não vazio e contém '='.
        @param DN  String a validar. *)
    function ValidateDN(const DN: string): Boolean;

    (** Extrai o valor do componente CN= do DN.
        @param DN  DN completo; retorna o DN original se CN= não encontrado. *)
    function GetCommonName(const DN: string): string;

    // ── Exportação JSON ───────────────────────────────────────────────────────

    (** Serializa Host, Port, BaseDN, Connected, LastError em TJSONObject.
        O chamador deve liberar o objeto retornado. *)
    function ToJSON: TJSONObject;

    (** Serializa a lista de SearchOUs em TJSONArray de strings.
        O chamador deve liberar o array retornado. *)
    function ToJSONArray: TJSONArray;

    // ── Escrita LDAP (requerem BaseAuth com permissão de escrita no AD) ────────

    (** MO_Replace: substitui o valor de AAttrName por AAttrValue.
        AAttrValue='' esvazia o atributo.
        @raises EADValidationException — DN ou AttrName inválidos.
        @raises EADWriteException      — Connect ou Bind falhou. *)
    function SetAttributeValue(const ADN, AAttrName, AAttrValue: string): Boolean;

    (** MO_Add: acrescenta AAttrValue a atributo multivalorado.
        @raises EADValidationException — DN ou AttrName inválidos.
        @raises EADWriteException      — Connect ou Bind falhou. *)
    function AddAttributeValue(const ADN, AAttrName, AAttrValue: string): Boolean;

    (** MO_Delete: remove valor específico (AAttrValue<>'') ou o atributo inteiro (AAttrValue='').
        @raises EADValidationException — DN ou AttrName inválidos.
        @raises EADWriteException      — Connect ou Bind falhou. *)
    function DeleteAttributeValue(const ADN, AAttrName: string; const AAttrValue: string = ''): Boolean;

    (** Substitui múltiplos atributos de uma vez; AAttributes = lista "nome=valor".
        Retorna False se qualquer Modify falhar (erros acumulados em GetLastError).
        @raises EADValidationException — DN inválido ou lista vazia.
        @raises EADWriteException      — Connect ou Bind falhou. *)
    function SetAttributes(const ADN: string; const AAttributes: TStringList): Boolean;

    (** Cria novo objeto LDAP. AAttributes deve incluir 'objectClass=<classe>'.
        @raises EADValidationException — DN inválido ou lista vazia.
        @raises EADWriteException      — Connect, Bind ou Add falhou. *)
    function AddObject(const ADN: string; const AAttributes: TStringList): Boolean;

    (** Remove definitivamente o objeto pelo DN.
        @raises EADValidationException — DN inválido.
        @raises EADWriteException      — Connect, Bind ou Delete falhou. *)
    function DeleteObject(const ADN: string): Boolean;

    (** Renomeia ou move objeto (ModifyDN).
        ANewParentDN='' mantém o pai atual.
        @raises EADValidationException — ADN ou ANewRDN inválidos.
        @raises EADWriteException      — Connect, Bind ou ModifyDN falhou. *)
    function RenameObject(const ADN, ANewRDN, ANewParentDN: string; ADeleteOldRDN: Boolean = True): Boolean;

    (** Adiciona AUserDN ao atributo 'member' do grupo (MO_Add).
        @raises EADValidationException — qualquer DN inválido.
        @raises EADWriteException      — Connect ou Bind falhou. *)
    function AddMemberToGroup(const AUserDN, AGroupDN: string): Boolean;

    (** Remove AUserDN do atributo 'member' do grupo (MO_Delete).
        @raises EADValidationException — qualquer DN inválido.
        @raises EADWriteException      — Connect ou Bind falhou. *)
    function RemoveMemberFromGroup(const AUserDN, AGroupDN: string): Boolean;

    (** Altera unicodePwd via MO_Replace. REQUER LDAPS (TlsMode tmLDAPSNoCertCheck ou tmLDAPSWithCA).
        Codifica '"senha"' como UTF-16LE (bytes brutos) conforme protocolo do AD.
        @raises EADWriteException      — TlsMode plain, Connect ou Bind falhou.
        @raises EADValidationException — DN ou senha vazia. *)
    function ChangePassword(const AUserDN, ANewPassword: string): Boolean;

    // ── Operações AD avançadas (delegam a TLDAPSend 001.007.002) ─────────────

    (** Busca atributos de um objeto pelo DN (escopo BaseObject).
        Retorna nil se o objeto não for encontrado.
        @param AUserDN     DN completo do objeto.
        @param AAttributes Atributos a solicitar ao servidor. *)
    function GetUserDirectoryData(const AUserDN: string;
      const AAttributes: TArray<string>): ILDAPSearchResult;

    (** Grupos transitivos do usuário via LDAP_MATCHING_RULE_IN_CHAIN.
        Inclui membros aninhados recursivamente.
        @param AUserDN  DN completo do usuário.
        @returns Array de DNs de grupo; vazio se nenhum. *)
    function GetTransitiveGroups(const AUserDN: string): TArray<string>;

    (** Extrai OUs ancestrais do DN por parsing de string (sem LDAP).
        Ex: 'CN=João,OU=TI,OU=Brasil,DC=empresa,DC=local'
        → ['OU=TI,OU=Brasil,DC=empresa,DC=local', 'OU=Brasil,DC=empresa,DC=local']
        @param AUserDN  DN de qualquer objeto LDAP. *)
    function GetAncestorOUs(const AUserDN: string): TArray<string>;

    (** Pesquisa paginada acumulando todas as páginas (usa TLDAPSend.SearchAllPages).
        @param AFilter     Filtro LDAP. Ex: '(objectClass=user)'.
        @param AAttributes Atributos desejados.
        @param APageSize   Entradas por página (padrão: FConfig.PageSize). *)
    function SearchUsersPage(const AFilter: string;
      const AAttributes: TArray<string>;
      APageSize: Integer = 1000): TArray<ILDAPSearchResult>;

    (** Reset administrativo de senha (MO_Replace em unicodePwd via TLDAPSend.SetPassword).
        REQUISITO: TlsMode = tmLDAPSNoCertCheck ou tmLDAPSWithCA.
        @param AUserDN      DN do usuário alvo.
        @param ANewPassword Nova senha em texto claro. *)
    function SetPassword(const AUserDN, ANewPassword: string): Boolean;

    (** Força troca de senha no próximo logon via TLDAPSend.ForcePasswordChange (pwdLastSet=0).
        @param AUserDN  DN do usuário alvo. *)
    function ForcePasswordChange(const AUserDN: string): Boolean;

    // ── Telemetria / Observabilidade (V1.6.0) ─────────────────────────────────

    (** V1.6.0 -- Regista um callback para receber telemetria de buscas LDAP.
        Ver IActiveDirectoryService.SetSearchLogCallback para semântica.
        @param ACallback  Handler method-of-object (TLDAPSearchLogProc); nil remove. *)
    procedure SetSearchLogCallback(ACallback: TLDAPSearchLogProc);

{$IFDEF USE_LOGGERS}
    (** F8 Onda 8.6 -- Ver IActiveDirectoryService.SetLogger para semântica. *)
    procedure SetLogger(const ALogger: ILogger);
{$ENDIF}
  end;


  // ===========================================================================
  // TServiceLDAP — wrapper de compatibilidade retroativa
  // ===========================================================================

  (** Wrapper que expõe a mesma API pública que o TServiceLDAP do Exemplo legado,
      delegando todas as chamadas para uma instância interna de IActiveDirectoryService.
      Permite que código antigo (ufrmLDAP_Teste, etc.) funcione sem alterações
      enquanto usa internamente o núcleo v1.0. *)
  TServiceLDAP = class
  private
    FConfig: TActiveDirectoryConfig;           // configuração passada no Create
    FService: IActiveDirectoryService; // instância interna gerenciada
    function GetConnected: Boolean;
    function GetLastError: string;
  public
    (** Cria o wrapper e instancia internamente TActiveDirectoryService.
        @param Config  Configuração LDAP já preenchida. *)
    constructor Create(const Config: TActiveDirectoryConfig);
    destructor Destroy; override;

    (** True se a conexão interna está ativa. *)
    property Connected: Boolean read GetConnected;

    (** Última mensagem de erro da operação mais recente. *)
    property LastError: string read GetLastError;

    (** Acesso à configuração; permite leitura ou substituição em tempo de execução. *)
    property Config: TActiveDirectoryConfig read FConfig write FConfig;

    function Connect: Boolean;
    function Disconnect: Boolean;
    function TestConnection: Boolean;
    function Authenticate(const AUsername, APassword: string): Boolean;
    function AuthenticateUser(const AUserDN, APassword: string): Boolean;
    function GetServerInfo: string;
    function GetConnectionStatus: string;
    procedure AddSearchOU(const OU: string);

    // ── Delegação total — paridade com Version.Old (V1.4.0) ─────────────────

    // Utilitários
    function ValidateDN(const DN: string): Boolean;
    function GetCommonName(const DN: string): string;
    function GetObjectClass(const ObjectDN: string): string;

    // Listagem / atributos
    function ListContainerObjects(const ContainerDN: string): TStringList;
    function ListContainerObjectsDetailed(const ContainerDN: string): TStringList;
    function GetObjectAttributes(const ObjectDN: string): TStringList;
    function GetObjectAttributesFormatted(const ObjectDN: string): string;

    // Grupos
    function ListGroups: TStringList;
    function ListGroupsInOU(const OUDN: string): TStringList;
    function ListGroupsDetailed: TStringList;
    function GetGroupMembers(const GroupDN: string): TStringList;
    function GetGroupMembersDetailed(const GroupDN: string): TStringList;
    function IsUserMemberOfGroup(const UserDN, GroupDN: string): Boolean;

    // Pesquisa
    function SearchObjects(const BaseDN, Filter: string;
      const Attributes: TStringList = nil): TStringList;
    function SearchWithCustomFilter(const CustomFilter: string;
      const BaseDN: string = ''): TStringList;

    // Find por atributo
    function FindObjectByAttribute(const AttributeName, AttributeValue: string;
      const ObjectType: string = ''): TStringList;
    function FindUserByAttribute(const AttributeName, AttributeValue: string): TStringList;
    function FindComputerByAttribute(const AttributeName, AttributeValue: string): TStringList;
    function GetObjectDetailsByAttribute(const AttributeName, AttributeValue: string): TStringList;
    function SearchObjectsByAttribute(const AttributeName, AttributeValue: string;
      const ObjectTypes: array of string): TStringList;
    function FindObjectsByMultipleAttributes(const AAttributes, AValues: array of string;
      const AObjectType: string = ''): TStringList;

    // Find por sAMAccountName
    function FindObjectBySAMAccountName(const SAMAccountName: string;
      const ObjectType: string = ''): TStringList;
    function FindUserBySAMAccountName(const SAMAccountName: string): TStringList;
    function FindComputerBySAMAccountName(const SAMAccountName: string): TStringList;
    function GetObjectDetailsBySAMAccountName(const SAMAccountName: string): TStringList;

    // ── Paridade final V1.6.0 com Version.Old (público no wrapper) ──────────

    (** V1.6.0 -- Regista callback de telemetria. Delega a FService. *)
    procedure SetSearchLogCallback(ACallback: TLDAPSearchLogProc);

{$IFDEF USE_LOGGERS}
    (** F8 Onda 8.6 -- Injeta ILogger para observabilidade estrutural. Delega a FService. *)
    procedure SetLogger(const ALogger: ILogger);
{$ENDIF}

    (** V1.6.0 -- Emite log estruturado manualmente.
        Assinatura idêntica ao Version.Old:105-107 (nome + sequência de tipos).
        Delega ao FService interno. *)
    procedure LogLDAPSearch(const AOperation, ABaseDN, AFilter: string;
                            const AStartTime: TDateTime;
                            AResultCount: Integer;
                            ASuccess: Boolean;
                            const AErrorMessage: string = '');

    (** V1.6.0 -- ExecuteLDAPSearch público com assinatura legada
        (3 strings: AOperation, ABaseDN, AFilter). Delega ao núcleo adaptando
        para a assinatura privada do SSOT (que recebe AAttributes = nil).
        Assinatura idêntica ao Version.Old:108. *)
    function ExecuteLDAPSearch(const AOperation, ABaseDN, AFilter: string): TStringList;
  end;

implementation

uses
  Commons.Diagnostics;

{ --- Codificação LDAP recebida (UTF-8 estrito falha em bytes binários / inválidos) -- }

function ADBytesToLatin1String(const B: TBytes): string;
var
  I: Integer;
begin
  SetLength(Result, Length(B));
  for I := 0 to High(B) do
    Result[Succ(I)] := Char(B[I]);
end;

function ADLdapBytesToDisplayString(const LBytes: TBytes): string;
begin
  if Length(LBytes) = 0 then
    Exit('');
  try
    Result := TEncoding.UTF8.GetString(LBytes);
  except
    Result := ADBytesToLatin1String(LBytes);
  end;
end;

function ADLdapAnsiToDisplayString(const A: AnsiString): string;
var
  LBytes: TBytes;
begin
  if A = '' then
    Exit('');
  SetLength(LBytes, Length(A));
  if Length(LBytes) > 0 then
    Move(A[1], LBytes[0], Length(LBytes));
  Result := ADLdapBytesToDisplayString(LBytes);
end;

function ADLdapBinaryStringToHex(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    Result := Result + IntToHex(Ord(S[I]) and $FF, 2);
end;

{ TActiveDirectoryService }

constructor TActiveDirectoryService.Create(const AConfig: TActiveDirectoryConfig);
begin
  inherited Create;
  FConfig.Host     := AConfig.Host;
  FConfig.Port     := AConfig.Port;
  FConfig.BaseDN   := AConfig.BaseDN;
  FConfig.BaseAuth := AConfig.BaseAuth;
  FConfig.Username := AConfig.Username;
  FConfig.Password := AConfig.Password;
  FConfig.UseSSL   := AConfig.UseSSL;
  FConfig.TimeOut  := AConfig.TimeOut;
  FConfig.Version  := AConfig.Version;
  FConfig.TlsMode  := AConfig.TlsMode;
  FConfig.CAFile   := AConfig.CAFile;
  FConfig.PageSize := AConfig.PageSize;
  if FConfig.PageSize < 1 then
    FConfig.PageSize := 1000;
  FConfig.SearchOUs := TStringList.Create;
  if AConfig.SearchOUs <> nil then
    FConfig.SearchOUs.Assign(AConfig.SearchOUs);
  FLDAPSend := TLDAPSend.Create;
  FConnected := False;
  FLastError := '';
  FLDAPSend.TargetHost := FConfig.Host;
  FLDAPSend.TargetPort := IntToStr(FConfig.Port);
  FLDAPSend.Timeout    := FConfig.TimeOut;
  FLDAPSend.Version    := FConfig.Version;
  { Retrocompatibilidade: se TlsMode não foi definido explicitamente mas UseSSL=True,
    inferir tmLDAPSNoCertCheck quando a porta é SSL. }
  if (FConfig.TlsMode = tmNone) and FConfig.UseSSL and
     IsSSLPort(FConfig.Port) then
    FConfig.TlsMode := tmLDAPSNoCertCheck;
  ApplyTlsMode;
{$IFDEF USE_LOGGERS}
  FLogger := TNullLogger.New;
{$ENDIF}
end;

// ───────────────────────────────────────────────────────────────────────────────
// V1.6.0 -- Telemetria de buscas LDAP (paridade com Version.Old/LogLDAPSearch)
// ───────────────────────────────────────────────────────────────────────────────

procedure TActiveDirectoryService.SetSearchLogCallback(ACallback: TLDAPSearchLogProc);
begin
  FLogCallback := ACallback;
end;

{$IFDEF USE_LOGGERS}
procedure TActiveDirectoryService.SetLogger(const ALogger: ILogger);
begin
  if Assigned(ALogger) then
    FLogger := ALogger
  else
    FLogger := TNullLogger.New;
end;
{$ENDIF}

procedure TActiveDirectoryService.LogLDAPSearch(const AOperation, ABaseDN, AFilter: string;
                                                const AStartTime: TDateTime;
                                                AResultCount: Integer;
                                                ASuccess: Boolean;
                                                const AErrorMessage: string);
var
  LElapsedMs: Int64;
{$IFDEF DEBUG}
  LMsg: string;
{$ENDIF}
begin
  LElapsedMs := MilliSecondsBetween(Now, AStartTime);

{$IFDEF USE_LOGGERS}
  // F8 Onda 8.6 -- emitido sempre (independente de FLogCallback/DEBUG abaixo);
  // TNullLogger (default) torna isto zero-overhead quando SetLogger nunca foi chamado.
  if ASuccess then
    FLogger.Debug(Format('[LDAP] %s baseDN=%s filter=%s elapsed=%dms results=%d',
      [AOperation, ABaseDN, AFilter, LElapsedMs, AResultCount]))
  else
    FLogger.Warning(Format('[LDAP] %s FALHOU baseDN=%s filter=%s elapsed=%dms erro=%s',
      [AOperation, ABaseDN, AFilter, LElapsedMs, AErrorMessage]));
{$ENDIF}

  // Caminho 1 -- callback registado: despacha e retorna (não toca FLastError)
  if Assigned(FLogCallback) then
  begin
    FLogCallback(AOperation, ABaseDN, AFilter, LElapsedMs, AResultCount,
                 ASuccess, AErrorMessage);
    Exit;
  end;

  // Caminho 2 -- sem callback e DEBUG: acumula em FLastError formato legado
  // (sem emojis -- mais grep-friendly; equivalente semântico a Version.Old:1593-1630).
  {$IFDEF DEBUG}
  LMsg := Format('[LDAP SEARCH] %s', [AOperation]) + sLineBreak +
          Format('  Filtro: %s', [AFilter]) + sLineBreak +
          Format('  Base DN: %s', [ABaseDN]) + sLineBreak +
          Format('  Tempo: %d ms', [LElapsedMs]) + sLineBreak +
          Format('  Resultados: %d objetos', [AResultCount]);
  if ASuccess then
    LMsg := LMsg + sLineBreak + '  Status: Sucesso'
  else
    LMsg := LMsg + sLineBreak + '  Status: Falha' + sLineBreak +
            Format('  Erro: %s', [AErrorMessage]);
  LMsg := LMsg + sLineBreak +
          Format('  Servidor: %s:%d', [FConfig.Host, FConfig.Port]);
  if FLastError <> '' then
    FLastError := FLastError + sLineBreak + LMsg
  else
    FLastError := LMsg;
  {$ENDIF}
end;

procedure TActiveDirectoryService.AppendLDAPResultToLastError;
var
  LMsg: string;
begin
  LMsg := Trim(Utf8DecodeFromAnsi(FLDAPSend.ResultString));
  if (LMsg <> '') or (FLDAPSend.ResultCode <> 0) then
  begin
    if LMsg <> '' then
      FLastError := FLastError + ' | LDAP: ' + LMsg;
    if FLDAPSend.ResultCode <> 0 then
      FLastError := FLastError + ' (c'#243'digo ' + IntToStr(FLDAPSend.ResultCode) + ')';
  end;
end;

procedure TActiveDirectoryService.ResetLDAPSend;
begin
  // Recria o TLDAPSend do zero -- unica forma segura de recuperar um socket morto.
  // Logout silencioso primeiro para fechar o fd se ainda estiver aberto.
  try FLDAPSend.Logout; except end;
  FreeAndNil(FLDAPSend);
  FLDAPSend := TLDAPSend.Create;
  FLDAPSend.TargetHost := FConfig.Host;
  FLDAPSend.TargetPort := IntToStr(FConfig.Port);
  FLDAPSend.Timeout    := FConfig.TimeOut;
  FLDAPSend.Version    := FConfig.Version;
  ApplyTlsMode;
  FConnected := False;
end;

function TActiveDirectoryService.ReconnectIfNeeded: Boolean;
var
  LWasConnected: Boolean;
begin
  LWasConnected := FConnected;
  // Passo 1: tentar Bind no socket existente
  if FConnected then
  begin
    FLDAPSend.UserName := FConfig.Username;
    FLDAPSend.Password := FConfig.Password;
    try
      if FLDAPSend.Bind then
      begin
        Result := True;
        Exit;
      end;
    except
      { 15.3/T10: engolir aqui e deliberado (bind falhou; recuperado por ResetLDAPSend),
        mas nao pode ser MUDO - sem rasto o defeito fica invisivel. }
      on E: Exception do
        TraceSwallowed('TActiveDirectoryService.ReconnectIfNeeded', 'bind falhou; recuperado por ResetLDAPSend', E);
    end;
    // Bind falhou ou lancou excepcao -- socket TCP morto; recriar TLDAPSend
    ResetLDAPSend;  // FConnected := False internamente
  end;
  // Passo 2: reconectar TCP (Login)
  if not Connect then  // Connect repoe FConnected := True se tiver sucesso
  begin
    // Falhou -- repor FConnected ao valor anterior para nao alterar UI
    FConnected := LWasConnected;
    Result := False;
    Exit;
  end;
  // Passo 3: Bind LDAP apos reconexao TCP
  FLDAPSend.UserName := FConfig.Username;
  FLDAPSend.Password := FConfig.Password;
  try
    Result := FLDAPSend.Bind;
    if not Result then
    begin
      FLastError := 'ReconnectIfNeeded: Bind falhou apos reconexao TCP';
      // TCP ligado mas Bind LDAP falhou -- manter FConnected=True (TCP ok)
    end;
  except
    on E: Exception do
    begin
      FLastError := 'ReconnectIfNeeded: ' + E.Message;
      Result := False;
      // Socket pode estar morto de novo -- recriar mas manter FConnected=True
      // para nao forcar o utilizador a reconectar manualmente na UI
      ResetLDAPSend;
      FConnected := LWasConnected;
    end;
  end;
end;

destructor TActiveDirectoryService.Destroy;
begin
  Disconnect;
  if FConfig.SearchOUs <> nil then
    FConfig.SearchOUs.Free;
  if FLDAPSend <> nil then
    FLDAPSend.Free;
  inherited;
end;

class function TActiveDirectoryService.IsSSLPort(APort: Integer): Boolean;
begin
  Result := (APort = LDAPS_PORT_DEFAULT) or (APort = LDAPS_GC_PORT_DEFAULT);
end;

procedure TActiveDirectoryService.ApplyTlsMode;
begin
  case FConfig.TlsMode of
    tmNone:
    begin
      FLDAPSend.FullSSL := False;
      FLDAPSend.AutoTLS := False;
    end;
    tmStartTLS:
    begin
      FLDAPSend.FullSSL := False;
      FLDAPSend.AutoTLS := True;
      if FLDAPSend.Sock.SSL <> nil then
        FLDAPSend.Sock.SSL.VerifyCert := False;
    end;
    tmLDAPSNoCertCheck:
    begin
      FLDAPSend.FullSSL := True;
      FLDAPSend.AutoTLS := False;
      if FLDAPSend.Sock.SSL <> nil then
        FLDAPSend.Sock.SSL.VerifyCert := False;
    end;
    tmLDAPSWithCA:
    begin
      FLDAPSend.FullSSL := True;
      FLDAPSend.AutoTLS := False;
      if FLDAPSend.Sock.SSL <> nil then
      begin
        FLDAPSend.Sock.SSL.VerifyCert := True;
        FLDAPSend.Sock.SSL.CertCAFile := FConfig.CAFile;
      end;
    end;
  else
    { tmNone — fallback: sem TLS }
    FLDAPSend.FullSSL := False;
    FLDAPSend.AutoTLS := False;
  end;
end;

class function TActiveDirectoryService.New(const AConfig: TActiveDirectoryConfig): IActiveDirectoryService;
begin
  Result := TActiveDirectoryService.Create(AConfig);
end;

function TActiveDirectoryService.Utf8DecodeFromAnsi(const A: AnsiString): string;
begin
  Result := ADLdapAnsiToDisplayString(A);
end;

function TActiveDirectoryService.Utf8EncodeToAnsi(const S: string): AnsiString;
var
  LBytes: TBytes;
begin
  if S = '' then
    Exit('');
  LBytes := TEncoding.UTF8.GetBytes(S);
  SetLength(Result, Length(LBytes));
  if Length(LBytes) > 0 then
    Move(LBytes[0], Result[1], Length(LBytes));
end;

function TActiveDirectoryService.FixUtf8Mojibake(const S: string): string;
var
  LBytes: TBytes;
  I: Integer;
begin
  if S = '' then
    Exit('');
  SetLength(LBytes, Length(S));
  for I := 0 to Length(S) - 1 do
    LBytes[I] := Byte(Ord(S[I + 1]) and $FF);
  Result := ADLdapBytesToDisplayString(LBytes);
end;

function TActiveDirectoryService.GetAttributeValue(const AAttribute: TLDAPAttribute): string;
var
  I: Integer;
begin
  Result := '';
  if AAttribute = nil then
    Exit;
  if AAttribute.IsBinary then
  begin
    if AAttribute.Count = 1 then
      Exit(ADLdapBinaryStringToHex(AAttribute[0]));
    for I := 0 to AAttribute.Count - 1 do
    begin
      if I > 0 then
        Result := Result + ', ';
      Result := Result + ADLdapBinaryStringToHex(AAttribute[I]);
    end;
    Exit;
  end;
  if AAttribute.Count = 1 then
    Result := FixUtf8Mojibake(AAttribute[0])
  else if AAttribute.Count > 1 then
  begin
    for I := 0 to AAttribute.Count - 1 do
    begin
      if I > 0 then
        Result := Result + ', ';
      Result := Result + FixUtf8Mojibake(AAttribute[I]);
    end;
  end;
end;

function TActiveDirectoryService.SearchUserInOU(const AUsername, ABaseDN: string): string;
var
  LFilter: string;
  LAttrList: TStringList;
  LStart: TDateTime;
  LSuccess: Boolean;
  LErrorMsg: string;
  LResCount: Integer;
begin
  Result := '';
  LAttrList := TStringList.Create;
  LStart := Now;
  LSuccess := False;
  LErrorMsg := '';
  LResCount := 0;
  LFilter := '';
  try
    LFilter := TActiveDirectoryHelper.BuildUserSearchFilter(AUsername);
    LAttrList.Add(LDAP_ATTR_DISTINGUISHEDNAME);
    LAttrList.Add('dn');
    LAttrList.Add('*');
    if FLDAPSend.Search(Utf8EncodeToAnsi(ABaseDN), False, Utf8EncodeToAnsi(LFilter), LAttrList) then
    begin
      LResCount := FLDAPSend.SearchResult.Count;
      if LResCount > 0 then
        Result := Utf8DecodeFromAnsi(FLDAPSend.SearchResult.Items[0].ObjectName);
      LSuccess := True;
    end
    else
      LErrorMsg := Format('Falha Synapse (ResultCode=%d)', [FLDAPSend.ResultCode]);
  finally
    LAttrList.Free;
    LogLDAPSearch('SearchUserInOU', ABaseDN, LFilter, LStart, LResCount, LSuccess, LErrorMsg);
  end;
end;

function TActiveDirectoryService.FindUserDN(const AUsername: string): string;
var
  I: Integer;
  LFound: string;
  LPrevTimeout: Integer;
  LStart: TDateTime;
  LSuccess: Boolean;
  LErrorMsg: string;
begin
  Result := '';
  LPrevTimeout := FLDAPSend.Timeout;
  LStart := Now;
  LSuccess := False;
  LErrorMsg := '';
  if LPrevTimeout > LDAP_AUTH_TIMEOUT_MS then
    FLDAPSend.Timeout := LDAP_AUTH_TIMEOUT_MS;
  try
    if not Connect then
    begin
      LErrorMsg := 'Falha em Connect';
      Exit;
    end;
    FLDAPSend.UserName := FConfig.BaseAuth;
    FLDAPSend.Password := FConfig.Password;
    if not FLDAPSend.Bind then
    begin
      FLastError := 'Falha no bind administrativo para buscar usu'#225'rio';
      AppendLDAPResultToLastError;
      LErrorMsg := Format('Falha no Bind (ResultCode=%d)', [FLDAPSend.ResultCode]);
      Exit;
    end;
    if FConfig.SearchOUs = nil then
    begin
      LErrorMsg := 'SearchOUs nao configuradas';
      Exit;
    end;
    for I := 0 to FConfig.SearchOUs.Count - 1 do
    begin
      LFound := SearchUserInOU(AUsername, FConfig.SearchOUs[I]);
      if LFound <> '' then
      begin
        Result := LFound;
        Exit;
      end;
    end;
    LSuccess := True; // não achou em nenhuma OU, mas operação foi até o fim sem erro
  finally
    FLDAPSend.Timeout := LPrevTimeout;
    LogLDAPSearch('FindUserDN', '', AUsername, LStart, Ord(Result <> ''), LSuccess, LErrorMsg);
  end;
end;

function TActiveDirectoryService.ExecuteLDAPSearch(const ABaseDN, AFilter: string; const AAttributes: TStringList): TStringList;
var
  I: Integer;
  LStart: TDateTime;
  LSuccess: Boolean;
  LErrorMsg: string;
  LAttrs: TStringList;
  LOwnsAttrs: Boolean;
begin
  Result := TStringList.Create;
  LStart := Now;
  LSuccess := False;
  LErrorMsg := '';
  // Synapse faz Attributes.Count sem nil-check -- nunca passar nil
  if AAttributes <> nil then
  begin
    LAttrs := AAttributes;
    LOwnsAttrs := False;
  end
  else
  begin
    LAttrs := TStringList.Create;
    LOwnsAttrs := True;
  end;
  try
    if AFilter = '' then
    begin
      LErrorMsg := 'Filtro LDAP vazio';
      Exit;
    end;
    if not ReconnectIfNeeded then
    begin
      LErrorMsg := 'Falha ao (re)conectar ao servidor LDAP';
      Exit;
    end;
    try
      if FLDAPSend.Search(Utf8EncodeToAnsi(ABaseDN), True, Utf8EncodeToAnsi(AFilter), LAttrs) then
      begin
        for I := 0 to FLDAPSend.SearchResult.Count - 1 do
          Result.Add(Utf8DecodeFromAnsi(FLDAPSend.SearchResult.Items[I].ObjectName));
        LSuccess := True;
      end
      else
        LErrorMsg := Format('Falha Synapse (ResultCode=%d)', [FLDAPSend.ResultCode]);
    except
      on E: Exception do
      begin
        LErrorMsg := 'Excecao no Search: ' + E.Message;
        FConnected := False;
      end;
    end;
  finally
    if LOwnsAttrs then
      LAttrs.Free;
    LogLDAPSearch('ExecuteLDAPSearch', ABaseDN, AFilter, LStart, Result.Count, LSuccess, LErrorMsg);
  end;
end;

function TActiveDirectoryService.Connect: Boolean;
begin
  Result := False;
  FLastError := '';
  try
    if FLDAPSend.Login then
    begin
      FConnected := True;
      Result := True;
    end
    else
    begin
      FLastError := 'Erro ao conectar com o servidor LDAP';
      AppendLDAPResultToLastError;
    end;
  except
    on E: Exception do
    begin
      FLastError := 'Exce'#231#227'o ao conectar: ' + E.Message;
      raise EADConnectionException.Create(FLastError, ERR_LDAP_CONNECTION);
    end;
  end;
end;

function TActiveDirectoryService.Disconnect: Boolean;
begin
  Result := False;
  try
    if FConnected then
    begin
      FLDAPSend.Logout;
      FConnected := False;
    end;
    Result := True;
  except
    on E: Exception do
      FLastError := 'Erro ao desconectar: ' + E.Message;
  end;
end;

function TActiveDirectoryService.TestConnection: Boolean;
begin
  Result := False;
  if not Connect then
    Exit;
  try
    FLDAPSend.UserName := FConfig.Username;
    FLDAPSend.Password := FConfig.Password;
    if FLDAPSend.Bind then
    begin
      Result := True;
      FLastError := 'Conexão e autenticação bem-sucedidas';
    end
    else
    begin
      FLastError := 'Falha na autentica'#231#227'o inicial';
      AppendLDAPResultToLastError;
    end;
  except
    on E: Exception do
      FLastError := 'Erro no teste de conex'#227'o: ' + E.Message;
  end;
end;

function TActiveDirectoryService.Authenticate(const AUsername, APassword: string): Boolean;
var
  LUserDN: string;
begin
  Result := False;
  FLastError := '';
  try
    LUserDN := FindUserDN(AUsername);
    if LUserDN = '' then
    begin
      FLastError := 'Usuário não encontrado: ' + AUsername;
      Exit;
    end;
    Result := AuthenticateUser(LUserDN, APassword);
  except
    on E: Exception do
      FLastError := 'Erro na autenticação: ' + E.Message;
  end;
end;

function TActiveDirectoryService.AuthenticateUser(const AUserDN, APassword: string): Boolean;
var
  LPrevTimeout: Integer;
begin
  Result := False;
  FLastError := '';
  LPrevTimeout := FLDAPSend.Timeout;
  try
    if LPrevTimeout > LDAP_AUTH_TIMEOUT_MS then
      FLDAPSend.Timeout := LDAP_AUTH_TIMEOUT_MS;
    if not Connect then
      Exit;
    FLDAPSend.UserName := AUserDN;
    FLDAPSend.Password := APassword;
    if FLDAPSend.Bind then
    begin
      Result := True;
      FLastError := 'Autenticação bem-sucedida para ' + AUserDN;
    end
    else
    begin
      FLastError := 'Falha na autentica'#231#227'o para ' + AUserDN;
      AppendLDAPResultToLastError;
    end;
  except
    on E: Exception do
      FLastError := 'Erro na autentica'#231#227'o: ' + E.Message;
  end;
  FLDAPSend.Timeout := LPrevTimeout;
end;

function TActiveDirectoryService.GetServerInfo: string;
begin
  Result := Format('Servidor: %s:%d | SSL: %s | Conectado: %s', [
    FConfig.Host, FConfig.Port,
    BoolToStr(FConfig.UseSSL, True),
    BoolToStr(FConnected, True)
  ]);
end;

function TActiveDirectoryService.GetConnectionStatus: string;
begin
  if FConnected then
    Result := 'Conectado'
  else
    Result := 'Desconectado';
  if FLastError <> '' then
    Result := Result + ' - ' + FLastError;
end;

function TActiveDirectoryService.GetConnected: Boolean;
begin
  Result := FConnected;
end;

function TActiveDirectoryService.GetLastError: string;
begin
  Result := FLastError;
end;

procedure TActiveDirectoryService.AddSearchOU(const OU: string);
begin
  if FConfig.SearchOUs = nil then
    FConfig.SearchOUs := TStringList.Create;
  if (OU <> '') and (FConfig.SearchOUs.IndexOf(OU) < 0) then
    FConfig.SearchOUs.Add(OU);
end;

function TActiveDirectoryService.ListContainerObjects(const ContainerDN: string): TStringList;
var
  LFilter: string;
  LAttrList: TStringList;
  I: Integer;
begin
  Result := TStringList.Create;
  LAttrList := TStringList.Create;
  try
    if not Connect then
      Exit;
    FLDAPSend.UserName := FConfig.Username;
    FLDAPSend.Password := FConfig.Password;
    if not FLDAPSend.Bind then
      Exit;
    LFilter := LDAP_FILTER_OBJECTCLASS_ANY;
    TActiveDirectoryHelper.AddDefaultAttributesForSearch(LAttrList);
    if FLDAPSend.Search(Utf8EncodeToAnsi(ContainerDN), False, Utf8EncodeToAnsi(LFilter), LAttrList) then
      for I := 0 to FLDAPSend.SearchResult.Count - 1 do
        Result.Add(Utf8DecodeFromAnsi(FLDAPSend.SearchResult.Items[I].ObjectName));
  finally
    LAttrList.Free;
  end;
end;

function TActiveDirectoryService.ListContainerObjectsDetailed(const ContainerDN: string): TStringList;
var
  LFilter: string;
  LAttrList: TStringList;
  I, J: Integer;
  LObjClass, LCN, LInfo: string;
begin
  Result := TStringList.Create;
  LAttrList := TStringList.Create;
  try
    if not Connect then
      Exit;
    FLDAPSend.UserName := FConfig.Username;
    FLDAPSend.Password := FConfig.Password;
    if not FLDAPSend.Bind then
      Exit;
    LFilter := LDAP_FILTER_OBJECTCLASS_ANY;
    TActiveDirectoryHelper.AddDefaultAttributesForDetailedSearch(LAttrList);
    if FLDAPSend.Search(Utf8EncodeToAnsi(ContainerDN), False, Utf8EncodeToAnsi(LFilter), LAttrList) then
    begin
      for I := 0 to FLDAPSend.SearchResult.Count - 1 do
      begin
        with FLDAPSend.SearchResult.Items[I] do
        begin
          LCN := TActiveDirectoryHelper.GetCommonName(Utf8DecodeFromAnsi(ObjectName));
          LObjClass := 'unknown';
          for J := 0 to Attributes.Count - 1 do
            if SameText(Utf8DecodeFromAnsi(Attributes.Items[J].AttributeName), LDAP_ATTR_OBJECTCLASS) then
            begin
              LObjClass := GetAttributeValue(Attributes.Items[J]);
              Break;
            end;
          LInfo := Format('[%s] %s', [LObjClass, LCN]);
          Result.Add(LInfo);
        end;
      end;
    end;
  finally
    LAttrList.Free;
  end;
end;

function TActiveDirectoryService.GetObjectAttributes(const ObjectDN: string): TStringList;
var
  LAttrList: TStringList;
  J: Integer;
begin
  Result := TStringList.Create;
  LAttrList := TStringList.Create;
  try
    if not Connect then
      Exit;
    FLDAPSend.UserName := FConfig.Username;
    FLDAPSend.Password := FConfig.Password;
    if not FLDAPSend.Bind then
      Exit;
    LAttrList.Add('*');
    if FLDAPSend.Search(Utf8EncodeToAnsi(ObjectDN), False, Utf8EncodeToAnsi(LDAP_FILTER_OBJECTCLASS_ANY), LAttrList) and (FLDAPSend.SearchResult.Count > 0) then
      with FLDAPSend.SearchResult.Items[0] do
      begin
        Result.Add('DN=' + Utf8DecodeFromAnsi(ObjectName));
        for J := 0 to Attributes.Count - 1 do
          Result.Add(Utf8DecodeFromAnsi(Attributes.Items[J].AttributeName) + '=' + GetAttributeValue(Attributes.Items[J]));
      end;
  finally
    LAttrList.Free;
  end;
end;

function TActiveDirectoryService.GetObjectAttributesFormatted(const ObjectDN: string): string;
var
  LAttrs: TStringList;
  I: Integer;
begin
  Result := '';
  LAttrs := GetObjectAttributes(ObjectDN);
  try
    if LAttrs.Count > 0 then
    begin
      Result := '=== ATRIBUTOS DO OBJETO ===' + sLineBreak + 'Objeto: ' + ObjectDN + sLineBreak + sLineBreak;
      for I := 0 to LAttrs.Count - 1 do
        Result := Result + LAttrs[I] + sLineBreak;
    end
    else
      Result := 'Nenhum atributo encontrado para: ' + ObjectDN + sLineBreak + 'Erro: ' + FLastError;
  finally
    LAttrs.Free;
  end;
end;

function TActiveDirectoryService.GetObjectClass(const ObjectDN: string): string;
var
  LAttrs: TStringList;
begin
  Result := 'unknown';
  LAttrs := GetObjectAttributes(ObjectDN);
  try
    Result := TActiveDirectoryHelper.GetObjectClassFromAttributes(LAttrs);
    if Result = '' then
      Result := 'unknown';
  finally
    LAttrs.Free;
  end;
end;

function TActiveDirectoryService.ListGroups: TStringList;
var
  I: Integer;
  LGroups: TStringList;
begin
  Result := TStringList.Create;
  if FConfig.SearchOUs = nil then
    Exit;
  try
    for I := 0 to FConfig.SearchOUs.Count - 1 do
    begin
      LGroups := ListGroupsInOU(FConfig.SearchOUs[I]);
      try
        Result.AddStrings(LGroups);
      finally
        LGroups.Free;
      end;
    end;
  except
    on E: Exception do
      FLastError := 'Erro ao listar grupos: ' + E.Message;
  end;
end;

function TActiveDirectoryService.ListGroupsInOU(const OUDN: string): TStringList;
var
  LFilter: string;
  LAttrList: TStringList;
  I: Integer;
begin
  Result := TStringList.Create;
  LAttrList := TStringList.Create;
  try
    if not Connect then
      Exit;
    FLDAPSend.UserName := FConfig.Username;
    FLDAPSend.Password := FConfig.Password;
    if not FLDAPSend.Bind then
      Exit;
    LFilter := LDAP_FILTER_OBJECTCLASS_GROUP;
    TActiveDirectoryHelper.AddDefaultAttributesForGroup(LAttrList);
    if FLDAPSend.Search(Utf8EncodeToAnsi(OUDN), True, Utf8EncodeToAnsi(LFilter), LAttrList) then
      for I := 0 to FLDAPSend.SearchResult.Count - 1 do
        Result.Add(Utf8DecodeFromAnsi(FLDAPSend.SearchResult.Items[I].ObjectName));
  finally
    LAttrList.Free;
  end;
end;

function TActiveDirectoryService.ListGroupsDetailed: TStringList;
var
  LGroups: TStringList;
  I: Integer;
  LCN, LInfo: string;
begin
  Result := TStringList.Create;
  LGroups := ListGroups;
  try
    for I := 0 to LGroups.Count - 1 do
    begin
      LCN := TActiveDirectoryHelper.GetCommonName(LGroups[I]);
      LInfo := Format('[GRUPO] %s (%s)', [LCN, LGroups[I]]);
      Result.Add(LInfo);
    end;
  finally
    LGroups.Free;
  end;
end;

function TActiveDirectoryService.GetGroupMembers(const GroupDN: string): TStringList;
var
  LAttrList: TStringList;
  J, K: Integer;
  LMemberDN: string;
  LAttr: TLDAPAttribute;
begin
  Result := TStringList.Create;
  LAttrList := TStringList.Create;
  try
    if not Connect then
      Exit;
    FLDAPSend.UserName := FConfig.Username;
    FLDAPSend.Password := FConfig.Password;
    if not FLDAPSend.Bind then
      Exit;
    LAttrList.Add(LDAP_ATTR_MEMBER);
    LAttrList.Add(LDAP_ATTR_MEMBEROF);
    LAttrList.Add(LDAP_ATTR_UNIQUEMEMBER);
    if FLDAPSend.Search(Utf8EncodeToAnsi(GroupDN), False, Utf8EncodeToAnsi(LDAP_FILTER_OBJECTCLASS_ANY), LAttrList) and (FLDAPSend.SearchResult.Count > 0) then
      with FLDAPSend.SearchResult.Items[0] do
        for J := 0 to Attributes.Count - 1 do
          if SameText(Utf8DecodeFromAnsi(Attributes.Items[J].AttributeName), LDAP_ATTR_MEMBER) or SameText(Utf8DecodeFromAnsi(Attributes.Items[J].AttributeName), LDAP_ATTR_UNIQUEMEMBER) then
          begin
            { bug-097 (fix C, 08/07): adicionar 1 DN por membro em vez do
              multivalor 'member' achatado por GetAttributeValue (que juntava
              tudo numa string). Corrige GetGroupMembersDetailed e IsUserMemberOfGroup. }
            LAttr := Attributes.Items[J];
            for K := 0 to LAttr.Count - 1 do
            begin
              LMemberDN := FixUtf8Mojibake(LAttr[K]);
              if LMemberDN <> '' then
                Result.Add(LMemberDN);
            end;
          end;
  finally
    LAttrList.Free;
  end;
end;

function TActiveDirectoryService.GetGroupMembersDetailed(const GroupDN: string): TStringList;
var
  LMembers: TStringList;
  I: Integer;
  LCN, LInfo: string;
begin
  Result := TStringList.Create;
  LMembers := GetGroupMembers(GroupDN);
  try
    Result.Add('=== MEMBROS DO GRUPO ===' + sLineBreak + 'Grupo: ' + GroupDN + sLineBreak);
    for I := 0 to LMembers.Count - 1 do
    begin
      LCN := TActiveDirectoryHelper.GetCommonName(LMembers[I]);
      LInfo := Format('[MEMBRO] %s (%s)', [LCN, LMembers[I]]);
      Result.Add(LInfo);
    end;
    if LMembers.Count = 0 then
      Result.Add('Nenhum membro encontrado ou erro: ' + FLastError);
  finally
    LMembers.Free;
  end;
end;

function TActiveDirectoryService.IsUserMemberOfGroup(const UserDN, GroupDN: string): Boolean;
var
  LMembers: TStringList;
  I: Integer;
begin
  Result := False;
  LMembers := GetGroupMembers(GroupDN);
  try
    for I := 0 to LMembers.Count - 1 do
      if SameText(LMembers[I], UserDN) then
      begin
        Result := True;
        Break;
      end;
  finally
    LMembers.Free;
  end;
end;

function TActiveDirectoryService.SearchObjects(const BaseDN, Filter: string; const Attributes: TStringList): TStringList;
var
  LDefault: TStringList;
  I: Integer;
begin
  Result := TStringList.Create;
  LDefault := nil;
  try
    if not Connect then
      Exit;
    FLDAPSend.UserName := FConfig.Username;
    FLDAPSend.Password := FConfig.Password;
    if not FLDAPSend.Bind then
      Exit;
    if Attributes = nil then
    begin
      LDefault := TStringList.Create;
      TActiveDirectoryHelper.AddDefaultAttributesForSearch(LDefault);
    end;
    if (Attributes <> nil) and FLDAPSend.Search(Utf8EncodeToAnsi(BaseDN), True, Utf8EncodeToAnsi(Filter), Attributes) then
      for I := 0 to FLDAPSend.SearchResult.Count - 1 do
        Result.Add(Utf8DecodeFromAnsi(FLDAPSend.SearchResult.Items[I].ObjectName))
    else if (LDefault <> nil) and FLDAPSend.Search(Utf8EncodeToAnsi(BaseDN), True, Utf8EncodeToAnsi(Filter), LDefault) then
      for I := 0 to FLDAPSend.SearchResult.Count - 1 do
        Result.Add(Utf8DecodeFromAnsi(FLDAPSend.SearchResult.Items[I].ObjectName));
  finally
    if LDefault <> nil then
      LDefault.Free;
  end;
end;

function TActiveDirectoryService.SearchWithCustomFilter(const CustomFilter: string; const BaseDN: string): TStringList;
var
  LBase: string;
  I: Integer;
  LPart: TStringList;
  LStart: TDateTime;
  LSuccess: Boolean;
  LErrorMsg: string;
begin
  Result := TStringList.Create;
  LStart := Now;
  LSuccess := False;
  LErrorMsg := '';
  try
    if not FConnected then
    begin
      LErrorMsg := 'Nao conectado ao servidor LDAP';
      Exit;
    end;
    if CustomFilter = '' then
    begin
      LErrorMsg := 'Filtro customizado vazio';
      Exit;
    end;
    if BaseDN <> '' then
    begin
      LPart := ExecuteLDAPSearch(BaseDN, CustomFilter, nil);
      try
        Result.AddStrings(LPart);
      finally
        LPart.Free;
      end
    end
    else if FConfig.SearchOUs <> nil then
      for I := 0 to FConfig.SearchOUs.Count - 1 do
      begin
        LBase := FConfig.SearchOUs[I];
        LPart := ExecuteLDAPSearch(LBase, CustomFilter, nil);
        try
          Result.AddStrings(LPart);
        finally
          LPart.Free;
        end;
      end;
    LSuccess := True;
  finally
    LogLDAPSearch('SearchWithCustomFilter', BaseDN, CustomFilter, LStart, Result.Count, LSuccess, LErrorMsg);
  end;
end;

// ─────────────────────────────────────────────────────────────────────────────
// Helpers privados — paridade com Version.Old (V1.4.0)
// ─────────────────────────────────────────────────────────────────────────────

class function TActiveDirectoryService.BuildAttributeFilter(
  const AAttrName, AAttrValue, AObjectType: string): string;
begin
  if AObjectType <> '' then
    Result := '(&(objectClass=' + AObjectType + ')(' + AAttrName + '=' + AAttrValue + '))'
  else
    Result := '(' + AAttrName + '=' + AAttrValue + ')';
end;

class function TActiveDirectoryService.BuildMultiClassFilter(
  const AAttrName, AAttrValue: string;
  const AObjectTypes: array of string): string;
var
  LOr: string;
  I: Integer;
begin
  if Length(AObjectTypes) = 0 then
  begin
    Result := BuildAttributeFilter(AAttrName, AAttrValue, '');
    Exit;
  end;
  LOr := '';
  for I := 0 to High(AObjectTypes) do
    LOr := LOr + '(objectClass=' + AObjectTypes[I] + ')';
  if Length(AObjectTypes) = 1 then
    Result := '(&' + LOr + '(' + AAttrName + '=' + AAttrValue + '))'
  else
    Result := '(&(|' + LOr + ')(' + AAttrName + '=' + AAttrValue + '))';
end;

class function TActiveDirectoryService.BuildMultiAttributeFilter(
  const ANames, AValues: array of string;
  const AObjectType: string): string;
var
  LInner: string;
  I: Integer;
begin
  LInner := '';
  for I := 0 to High(ANames) do
    LInner := LInner + '(' + ANames[I] + '=' + AValues[I] + ')';
  if AObjectType <> '' then
    LInner := LInner + '(objectClass=' + AObjectType + ')';
  Result := '(&' + LInner + ')';
end;

function TActiveDirectoryService.SearchAllOUs(const AFilter: string): TStringList;
var
  I, J: Integer;
  LPart: TStringList;
  LDN: string;
  LDup: Boolean;
  LStart: TDateTime;
  LSuccess: Boolean;
  LErrorMsg: string;
begin
  Result := TStringList.Create;
  LStart := Now;
  LSuccess := False;
  LErrorMsg := '';
  try
    if AFilter = '' then
    begin
      LErrorMsg := 'Filtro LDAP vazio';
      Exit;
    end;
    if FConfig.SearchOUs = nil then
    begin
      LErrorMsg := 'SearchOUs nao configuradas';
      Exit;
    end;
    // ReconnectIfNeeded e' chamado por cada ExecuteLDAPSearch -- sem Bind manual aqui
    try
      for I := 0 to FConfig.SearchOUs.Count - 1 do
      begin
        LPart := ExecuteLDAPSearch(FConfig.SearchOUs[I], AFilter, nil);
        try
          for J := 0 to LPart.Count - 1 do
          begin
            LDN := LPart[J];
            LDup := False;
            if Result.Count > 0 then
              LDup := Result.IndexOf(LDN) >= 0;
            if (not LDup) then
              Result.Add(LDN);
          end;
        finally
          LPart.Free;
        end;
      end;
      LSuccess := True;
    except
      on E: Exception do
      begin
        LErrorMsg := 'Excecao em SearchAllOUs: ' + E.Message;
        FConnected := False;
      end;
    end;
  finally
    LogLDAPSearch('SearchAllOUs', '', AFilter, LStart, Result.Count, LSuccess, LErrorMsg);
  end;
end;

// ─────────────────────────────────────────────────────────────────────────────
// Find* / SearchBy* — paridade com Version.Old (V1.4.0)
// ─────────────────────────────────────────────────────────────────────────────

function TActiveDirectoryService.FindObjectByAttribute(
  const AttributeName, AttributeValue: string;
  const ObjectType: string): TStringList;
begin
  Result := SearchAllOUs(BuildAttributeFilter(AttributeName, AttributeValue, ObjectType));
end;

function TActiveDirectoryService.FindUserByAttribute(
  const AttributeName, AttributeValue: string): TStringList;
begin
  Result := FindObjectByAttribute(AttributeName, AttributeValue, 'user');
end;

function TActiveDirectoryService.FindComputerByAttribute(
  const AttributeName, AttributeValue: string): TStringList;
begin
  Result := FindObjectByAttribute(AttributeName, AttributeValue, 'computer');
end;

function TActiveDirectoryService.GetObjectDetailsByAttribute(
  const AttributeName, AttributeValue: string): TStringList;
var
  LDNs: TStringList;
  I: Integer;
  LDetails: string;
begin
  Result := TStringList.Create;
  LDNs := FindObjectByAttribute(AttributeName, AttributeValue, '');
  try
    for I := 0 to LDNs.Count - 1 do
    begin
      LDetails := GetObjectAttributesFormatted(LDNs[I]);
      if LDetails <> '' then
      begin
        { bug-099 (fix C, 08/07): separador ENTRE blocos, sem entrada vazia no fim. }
        if Result.Count > 0 then
          Result.Add('');
        Result.Add(LDetails);
      end;
    end;
  finally
    LDNs.Free;
  end;
end;

function TActiveDirectoryService.SearchObjectsByAttribute(
  const AttributeName, AttributeValue: string;
  const ObjectTypes: array of string): TStringList;
begin
  Result := SearchAllOUs(BuildMultiClassFilter(AttributeName, AttributeValue, ObjectTypes));
end;

function TActiveDirectoryService.FindObjectsByMultipleAttributes(
  const AAttributes, AValues: array of string;
  const AObjectType: string): TStringList;
var
  LTemp: TStringList;
begin
  Result := TStringList.Create;
  if Length(AAttributes) <> Length(AValues) then
    raise EADValidationException.Create(
      'FindObjectsByMultipleAttributes: arrays AAttributes/AValues com tamanhos diferentes',
      ERR_LDAP_VALIDATION);
  if Length(AAttributes) = 0 then
    Exit;
  LTemp := nil;
  try
    LTemp := SearchAllOUs(BuildMultiAttributeFilter(AAttributes, AValues, AObjectType));
    Result.Free;
    Result := LTemp;
    LTemp := nil;
  except
    on E: Exception do
      FLastError := 'FindObjectsByMultipleAttributes: ' + E.Message;
  end;
  LTemp.Free;
end;

function TActiveDirectoryService.FindObjectBySAMAccountName(
  const SAMAccountName: string;
  const ObjectType: string): TStringList;
begin
  Result := FindObjectByAttribute('sAMAccountName', SAMAccountName, ObjectType);
end;

function TActiveDirectoryService.FindUserBySAMAccountName(
  const SAMAccountName: string): TStringList;
begin
  Result := FindObjectBySAMAccountName(SAMAccountName, 'user');
end;

function TActiveDirectoryService.FindComputerBySAMAccountName(
  const SAMAccountName: string): TStringList;
begin
  Result := FindObjectBySAMAccountName(SAMAccountName, 'computer');
end;

function TActiveDirectoryService.GetObjectDetailsBySAMAccountName(
  const SAMAccountName: string): TStringList;
begin
  Result := GetObjectDetailsByAttribute('sAMAccountName', SAMAccountName);
end;

function TActiveDirectoryService.ValidateDN(const DN: string): Boolean;
begin
  Result := (DN <> '') and (Pos('=', DN) > 0);
end;

function TActiveDirectoryService.GetCommonName(const DN: string): string;
begin
  Result := TActiveDirectoryHelper.GetCommonName(DN);
end;

function TActiveDirectoryService.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
{$IFDEF FPC}
    Result.Add('Host', FConfig.Host);
    Result.Add('Port', FConfig.Port);
    Result.Add('BaseDN', FConfig.BaseDN);
    Result.Add('Connected', FConnected);
    Result.Add('LastError', FLastError);
{$ELSE}
    Result.AddPair('Host', FConfig.Host);
    Result.AddPair('Port', TJSONNumber.Create(FConfig.Port));
    Result.AddPair('BaseDN', FConfig.BaseDN);
    Result.AddPair('Connected', TJSONBool.Create(FConnected));
    Result.AddPair('LastError', FLastError);
{$ENDIF}
  except
    Result.Free;
    raise;
  end;
end;

function TActiveDirectoryService.ToJSONArray: TJSONArray;
var
  I: Integer;
begin
  Result := TJSONArray.Create;
  try
    if FConfig.SearchOUs <> nil then
      for I := 0 to FConfig.SearchOUs.Count - 1 do
      begin
{$IFDEF FPC}
        Result.Add(FConfig.SearchOUs[I]);
{$ELSE}
        Result.AddElement(TJSONString.Create(FConfig.SearchOUs[I]));
{$ENDIF}
      end;
  except
    Result.Free;
    raise;
  end;
end;

{ Helpers privados para operações de escrita }

function TActiveDirectoryService.BindAsAdmin: Boolean;
begin
  FLDAPSend.UserName := Utf8EncodeToAnsi(FConfig.BaseAuth);
  FLDAPSend.Password := Utf8EncodeToAnsi(FConfig.Password);
  Result := FLDAPSend.Bind;
  if not Result then
    AppendLDAPResultToLastError;
end;

{ SetAttributeValue — substitui valor de atributo (MO_Replace) }

function TActiveDirectoryService.SetAttributeValue(
  const ADN, AAttrName, AAttrValue: string): Boolean;
var
  LAttr: TLDAPAttribute;
begin
  Result := False;
  FLastError := '';
  if not ValidateDN(ADN) then
    raise EADValidationException.Create('DN inv'#225'lido: ' + ADN, ERR_LDAP_VALIDATION);
  if AAttrName = '' then
    raise EADValidationException.Create('AttrName n'#227'o pode ser vazio', ERR_LDAP_VALIDATION);
  if not Connect then
    raise EADWriteException.Create('Falha ao conectar: ' + FLastError);
  if not BindAsAdmin then
    raise EADWriteException.Create('Bind falhou ao modificar atributo: ' + FLastError);
  LAttr := TLDAPAttribute.Create;
  try
    LAttr.AttributeName := Utf8EncodeToAnsi(AAttrName);
    if AAttrValue <> '' then
      LAttr.Add(Utf8EncodeToAnsi(AAttrValue));
    Result := FLDAPSend.Modify(Utf8EncodeToAnsi(ADN), MO_Replace, LAttr);
    if not Result then
      AppendLDAPResultToLastError;
  finally
    LAttr.Free;
  end;
end;

{ AddAttributeValue — acrescenta valor a atributo multivalorado (MO_Add) }

function TActiveDirectoryService.AddAttributeValue(
  const ADN, AAttrName, AAttrValue: string): Boolean;
var
  LAttr: TLDAPAttribute;
begin
  Result := False;
  FLastError := '';
  if not ValidateDN(ADN) then
    raise EADValidationException.Create('DN inv'#225'lido: ' + ADN, ERR_LDAP_VALIDATION);
  if AAttrName = '' then
    raise EADValidationException.Create('AttrName n'#227'o pode ser vazio', ERR_LDAP_VALIDATION);
  if not Connect then
    raise EADWriteException.Create('Falha ao conectar: ' + FLastError);
  if not BindAsAdmin then
    raise EADWriteException.Create('Bind falhou ao adicionar valor de atributo: ' + FLastError);
  LAttr := TLDAPAttribute.Create;
  try
    LAttr.AttributeName := Utf8EncodeToAnsi(AAttrName);
    LAttr.Add(Utf8EncodeToAnsi(AAttrValue));
    Result := FLDAPSend.Modify(Utf8EncodeToAnsi(ADN), MO_Add, LAttr);
    if not Result then
      AppendLDAPResultToLastError;
  finally
    LAttr.Free;
  end;
end;

{ DeleteAttributeValue — remove valor específico ou o atributo inteiro (MO_Delete) }

function TActiveDirectoryService.DeleteAttributeValue(
  const ADN, AAttrName: string; const AAttrValue: string): Boolean;
var
  LAttr: TLDAPAttribute;
begin
  Result := False;
  FLastError := '';
  if not ValidateDN(ADN) then
    raise EADValidationException.Create('DN inv'#225'lido: ' + ADN, ERR_LDAP_VALIDATION);
  if AAttrName = '' then
    raise EADValidationException.Create('AttrName n'#227'o pode ser vazio', ERR_LDAP_VALIDATION);
  if not Connect then
    raise EADWriteException.Create('Falha ao conectar: ' + FLastError);
  if not BindAsAdmin then
    raise EADWriteException.Create('Bind falhou ao remover valor de atributo: ' + FLastError);
  LAttr := TLDAPAttribute.Create;
  try
    LAttr.AttributeName := Utf8EncodeToAnsi(AAttrName);
    if AAttrValue <> '' then
      LAttr.Add(Utf8EncodeToAnsi(AAttrValue));
    Result := FLDAPSend.Modify(Utf8EncodeToAnsi(ADN), MO_Delete, LAttr);
    if not Result then
      AppendLDAPResultToLastError;
  finally
    LAttr.Free;
  end;
end;

{ SetAttributes — substitui múltiplos atributos de uma só vez (lista "nome=valor") }

function TActiveDirectoryService.SetAttributes(
  const ADN: string; const AAttributes: TStringList): Boolean;
var
  LAttr: TLDAPAttribute;
  I, P: Integer;
  LName, LValue: string;
begin
  Result := False;
  FLastError := '';
  if not ValidateDN(ADN) then
    raise EADValidationException.Create('DN inv'#225'lido: ' + ADN, ERR_LDAP_VALIDATION);
  if (AAttributes = nil) or (AAttributes.Count = 0) then
    raise EADValidationException.Create('Lista de atributos n'#227'o pode ser vazia', ERR_LDAP_VALIDATION);
  if not Connect then
    raise EADWriteException.Create('Falha ao conectar: ' + FLastError);
  if not BindAsAdmin then
    raise EADWriteException.Create('Bind falhou ao definir atributos: ' + FLastError);
  Result := True;
  for I := 0 to AAttributes.Count - 1 do
  begin
    P := Pos('=', AAttributes[I]);
    if P = 0 then
      Continue;
    LName := Copy(AAttributes[I], 1, P - 1);
    LValue := Copy(AAttributes[I], P + 1, MaxInt);
    LAttr := TLDAPAttribute.Create;
    try
      LAttr.AttributeName := Utf8EncodeToAnsi(LName);
      if LValue <> '' then
        LAttr.Add(Utf8EncodeToAnsi(LValue));
      if not FLDAPSend.Modify(Utf8EncodeToAnsi(ADN), MO_Replace, LAttr) then
      begin
        AppendLDAPResultToLastError;
        Result := False;
      end;
    finally
      LAttr.Free;
    end;
  end;
end;

{ AddObject — cria novo objeto LDAP (lista "nome=valor" com objectClass obrigatório) }

function TActiveDirectoryService.AddObject(
  const ADN: string; const AAttributes: TStringList): Boolean;
var
  LList: TLDAPAttributeList;
  LAttr: TLDAPAttribute;
  I, P: Integer;
  LName, LValue: string;
begin
  Result := False;
  FLastError := '';
  if not ValidateDN(ADN) then
    raise EADValidationException.Create('DN inv'#225'lido: ' + ADN, ERR_LDAP_VALIDATION);
  if (AAttributes = nil) or (AAttributes.Count = 0) then
    raise EADValidationException.Create('Lista de atributos n'#227'o pode ser vazia', ERR_LDAP_VALIDATION);
  if not Connect then
    raise EADWriteException.Create('Falha ao conectar: ' + FLastError);
  if not BindAsAdmin then
    raise EADWriteException.Create('Bind falhou ao criar objeto: ' + FLastError);
  LList := TLDAPAttributeList.Create;
  try
    for I := 0 to AAttributes.Count - 1 do
    begin
      P := Pos('=', AAttributes[I]);
      if P = 0 then
        Continue;
      LName := Copy(AAttributes[I], 1, P - 1);
      LValue := Copy(AAttributes[I], P + 1, MaxInt);
      LAttr := LList.Add;
      LAttr.AttributeName := Utf8EncodeToAnsi(LName);
      if LValue <> '' then
        LAttr.Add(Utf8EncodeToAnsi(LValue));
    end;
    Result := FLDAPSend.Add(Utf8EncodeToAnsi(ADN), LList);
    if not Result then
      AppendLDAPResultToLastError;
  finally
    LList.Free;
  end;
end;

{ DeleteObject — remove objeto LDAP pelo DN }

function TActiveDirectoryService.DeleteObject(const ADN: string): Boolean;
begin
  Result := False;
  FLastError := '';
  if not ValidateDN(ADN) then
    raise EADValidationException.Create('DN inv'#225'lido: ' + ADN, ERR_LDAP_VALIDATION);
  if not Connect then
    raise EADWriteException.Create('Falha ao conectar: ' + FLastError);
  if not BindAsAdmin then
    raise EADWriteException.Create('Bind falhou ao remover objeto: ' + FLastError);
  Result := FLDAPSend.Delete(Utf8EncodeToAnsi(ADN));
  if not Result then
    AppendLDAPResultToLastError;
end;

{ RenameObject — renomeia ou move objeto (ModifyDN) }

function TActiveDirectoryService.RenameObject(
  const ADN, ANewRDN, ANewParentDN: string; ADeleteOldRDN: Boolean): Boolean;
begin
  Result := False;
  FLastError := '';
  if not ValidateDN(ADN) then
    raise EADValidationException.Create('DN inv'#225'lido: ' + ADN, ERR_LDAP_VALIDATION);
  if ANewRDN = '' then
    raise EADValidationException.Create('NewRDN n'#227'o pode ser vazio', ERR_LDAP_VALIDATION);
  if not Connect then
    raise EADWriteException.Create('Falha ao conectar: ' + FLastError);
  if not BindAsAdmin then
    raise EADWriteException.Create('Bind falhou ao renomear objeto: ' + FLastError);
  Result := FLDAPSend.ModifyDN(
    Utf8EncodeToAnsi(ADN),
    Utf8EncodeToAnsi(ANewRDN),
    Utf8EncodeToAnsi(ANewParentDN),
    ADeleteOldRDN
  );
  if not Result then
    AppendLDAPResultToLastError;
end;

{ AddMemberToGroup — acrescenta usuário ao atributo 'member' do grupo (MO_Add) }

function TActiveDirectoryService.AddMemberToGroup(
  const AUserDN, AGroupDN: string): Boolean;
var
  LAttr: TLDAPAttribute;
begin
  Result := False;
  FLastError := '';
  if not ValidateDN(AUserDN) then
    raise EADValidationException.Create('UserDN inv'#225'lido: ' + AUserDN, ERR_LDAP_VALIDATION);
  if not ValidateDN(AGroupDN) then
    raise EADValidationException.Create('GroupDN inv'#225'lido: ' + AGroupDN, ERR_LDAP_VALIDATION);
  if not Connect then
    raise EADWriteException.Create('Falha ao conectar: ' + FLastError);
  if not BindAsAdmin then
    raise EADWriteException.Create('Bind falhou ao adicionar membro ao grupo: ' + FLastError);
  LAttr := TLDAPAttribute.Create;
  try
    LAttr.AttributeName := Utf8EncodeToAnsi(LDAP_ATTR_MEMBER);
    LAttr.Add(Utf8EncodeToAnsi(AUserDN));
    Result := FLDAPSend.Modify(Utf8EncodeToAnsi(AGroupDN), MO_Add, LAttr);
    if not Result then
      AppendLDAPResultToLastError;
  finally
    LAttr.Free;
  end;
end;

{ RemoveMemberFromGroup — remove usuário do atributo 'member' do grupo (MO_Delete) }

function TActiveDirectoryService.RemoveMemberFromGroup(
  const AUserDN, AGroupDN: string): Boolean;
var
  LAttr: TLDAPAttribute;
begin
  Result := False;
  FLastError := '';
  if not ValidateDN(AUserDN) then
    raise EADValidationException.Create('UserDN inv'#225'lido: ' + AUserDN, ERR_LDAP_VALIDATION);
  if not ValidateDN(AGroupDN) then
    raise EADValidationException.Create('GroupDN inv'#225'lido: ' + AGroupDN, ERR_LDAP_VALIDATION);
  if not Connect then
    raise EADWriteException.Create('Falha ao conectar: ' + FLastError);
  if not BindAsAdmin then
    raise EADWriteException.Create('Bind falhou ao remover membro do grupo: ' + FLastError);
  LAttr := TLDAPAttribute.Create;
  try
    LAttr.AttributeName := Utf8EncodeToAnsi(LDAP_ATTR_MEMBER);
    LAttr.Add(Utf8EncodeToAnsi(AUserDN));
    Result := FLDAPSend.Modify(Utf8EncodeToAnsi(AGroupDN), MO_Delete, LAttr);
    if not Result then
      AppendLDAPResultToLastError;
  finally
    LAttr.Free;
  end;
end;

{ ChangePassword — altera unicodePwd no AD (exige LDAPS porta 636) }

function TActiveDirectoryService.ChangePassword(
  const AUserDN, ANewPassword: string): Boolean;
var
  LAttr: TLDAPAttribute;
  LQuoted: string;
  LEncoded: AnsiString;
  LBytes: TBytes;
  I: Integer;
begin
  Result := False;
  FLastError := '';
  if not (FConfig.TlsMode in [tmLDAPSNoCertCheck, tmLDAPSWithCA]) then
    raise EADWriteException.Create(
      'ChangePassword requer LDAPS (TlsMode tmLDAPSNoCertCheck ou tmLDAPSWithCA)');
  if not ValidateDN(AUserDN) then
    raise EADValidationException.Create('DN inv'#225'lido: ' + AUserDN, ERR_LDAP_VALIDATION);
  if ANewPassword = '' then
    raise EADValidationException.Create('Senha n'#227'o pode ser vazia', ERR_LDAP_VALIDATION);
  if not Connect then
    raise EADWriteException.Create('Falha ao conectar: ' + FLastError);
  if not BindAsAdmin then
    raise EADWriteException.Create('Bind falhou ao alterar senha: ' + FLastError);
  { AD exige '"senha"' codificado em UTF-16LE como bytes brutos }
  LQuoted := '"' + ANewPassword + '"';
  LBytes := TEncoding.Unicode.GetBytes(LQuoted);  // UTF-16LE no Delphi/FPC Windows
  SetLength(LEncoded, Length(LBytes));
  for I := 0 to Length(LBytes) - 1 do
    LEncoded[I + 1] := AnsiChar(LBytes[I]);
  LAttr := TLDAPAttribute.Create;
  try
    LAttr.AttributeName := 'unicodePwd';
    LAttr.Add(LEncoded);
    Result := FLDAPSend.Modify(Utf8EncodeToAnsi(AUserDN), MO_Replace, LAttr);
    if not Result then
      AppendLDAPResultToLastError;
  finally
    LAttr.Free;
  end;
end;

{ TLDAPSearchResultAdapter }

class function TLDAPSearchResultAdapter.DecodeStr(const A: AnsiString): string;
begin
  Result := ADLdapAnsiToDisplayString(A);
end;

constructor TLDAPSearchResultAdapter.Create(AResult: TLDAPResult);
var
  i, j:   Integer;
  LAttr:  TLDAPAttribute;
begin
  inherited Create;
  if AResult = nil then
  begin
    FDN := '';
    SetLength(FAttrs, 0);
    Exit;
  end;
  { Copiar DN }
  FDN := DecodeStr(AResult.ObjectName);
  { Copiar todos os atributos e seus valores }
  SetLength(FAttrs, AResult.Attributes.Count);
  for i := 0 to AResult.Attributes.Count - 1 do
  begin
    LAttr := AResult.Attributes[i];
    FAttrs[i].Name := string(LAttr.AttributeName);
    SetLength(FAttrs[i].Values,    LAttr.Count);
    SetLength(FAttrs[i].RawValues, LAttr.Count);
    for j := 0 to LAttr.Count - 1 do
    begin
      FAttrs[i].RawValues[j] := LAttr.RawValueAt[j]; // bytes brutos (para GUID/SID) — V41.3: Get() ja converte; RawValueAt preserva os bytes originais
      FAttrs[i].Values[j]    := DecodeStr(LAttr[j]);    // UTF-8 → string (para texto)
    end;
  end;
end;

function TLDAPSearchResultAdapter.FindAttrIdx(const AName: string): Integer;
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

function TLDAPSearchResultAdapter.DN: string;
begin
  Result := FDN;
end;

function TLDAPSearchResultAdapter.Attribute(const AName: string): string;
var
  idx: Integer;
begin
  Result := '';
  idx := FindAttrIdx(AName);
  if (idx >= 0) and (Length(FAttrs[idx].Values) > 0) then
    Result := FAttrs[idx].Values[0];
end;

function TLDAPSearchResultAdapter.AttributeList(
  const AName: string): TArray<string>;
var
  idx: Integer;
begin
  Result := [];
  idx := FindAttrIdx(AName);
  if idx >= 0 then
    Result := FAttrs[idx].Values;
end;

function TLDAPSearchResultAdapter.AttributeGuid(const AName: string): TGuid;
var
  LRaw: AnsiString;
  idx:  Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  idx := FindAttrIdx(AName);
  if (idx < 0) or (Length(FAttrs[idx].RawValues) = 0) then Exit;
  { objectGUID = 16 bytes brutos little-endian enviados pelo AD como OCTET STRING }
  LRaw := FAttrs[idx].RawValues[0];
  if Length(LRaw) = SizeOf(TGuid) then
    Move(LRaw[1], Result, SizeOf(TGuid));
end;

function TLDAPSearchResultAdapter.AttributeFileTime(
  const AName: string): Int64;
begin
  Result := StrToInt64Def(Attribute(AName), 0);
end;

function TLDAPSearchResultAdapter.AttributeSid(const AName: string): string;
var
  LRaw: AnsiString;
  idx:  Integer;
  LB:   TBytes;
  LRev, LCnt: Byte;
  LAuth: Int64;
  I:    Integer;
  LSub: LongWord;
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

{ TActiveDirectoryService — métodos Fase B }

function TActiveDirectoryService.GetUserDirectoryData(const AUserDN: string;
  const AAttributes: TArray<string>): ILDAPSearchResult;
var
  LAttrs: TStringList;
  i:      Integer;
begin
  Result := nil;
  FLastError := '';
  if AUserDN = '' then Exit;
  if not Connect then Exit;
  if not BindAsAdmin then Exit;

  LAttrs := TStringList.Create;
  try
    for i := 0 to High(AAttributes) do
      LAttrs.Add(AAttributes[i]);

    if FLDAPSend.Search(
         Utf8EncodeToAnsi(AUserDN),
         False,            { scope: base object }
         '(objectClass=*)',
         LAttrs) and (FLDAPSend.SearchResult.Count > 0) then
      Result := TLDAPSearchResultAdapter.Create(
        FLDAPSend.SearchResult.Items[0])
    else
      AppendLDAPResultToLastError;
  finally
    LAttrs.Free;
  end;
end;

function TActiveDirectoryService.GetTransitiveGroups(
  const AUserDN: string): TArray<string>;
var
  LAttrs:  TStringList;
  LFilter: AnsiString;
  i:       Integer;
  LEntry:  TLDAPResult;
  LEscapedDN: string;
begin
  Result := [];
  FLastError := '';
  if AUserDN = '' then Exit;
  if not Connect then Exit;
  if not BindAsAdmin then Exit;

  LAttrs := TStringList.Create;
  try
    LAttrs.Add('distinguishedName');
    { LDAP_MATCHING_RULE_IN_CHAIN = 1.2.840.113556.1.4.1941: grupos nested (transitivo) }
    LEscapedDN := AUserDN
      .Replace('\', '\5c').Replace('*', '\2a')
      .Replace('(', '\28').Replace(')', '\29')
      .Replace(#0, '\00');
    LFilter := AnsiString(
      '(&(objectClass=group)(member:1.2.840.113556.1.4.1941:=' +
      LEscapedDN + '))');

    if FLDAPSend.Search(
         Utf8EncodeToAnsi(FConfig.BaseDN),
         True,             { scope: whole subtree }
         LFilter,
         LAttrs) then
    begin
      SetLength(Result, FLDAPSend.SearchResult.Count);
      for i := 0 to FLDAPSend.SearchResult.Count - 1 do
      begin
        LEntry   := FLDAPSend.SearchResult.Items[i];
        Result[i] := Utf8DecodeFromAnsi(LEntry.ObjectName);
      end;
    end
    else
      AppendLDAPResultToLastError;
  finally
    LAttrs.Free;
  end;
end;

function TActiveDirectoryService.GetAncestorOUs(
  const AUserDN: string): TArray<string>;
var
  LParts:   TStringList;
  LResult:  TStringList;
  i:        Integer;
  LCurrent: string;
begin
  Result := [];
  if AUserDN = '' then Exit;

  LParts  := TStringList.Create;
  LResult := TStringList.Create;
  try
    LParts.Delimiter       := ',';
    LParts.StrictDelimiter := True;
    LParts.DelimitedText   := AUserDN;

    { Percorre a partir do componente 1 (pula o RDN do próprio objeto) }
    LCurrent := '';
    for i := 1 to LParts.Count - 1 do
    begin
      if LCurrent <> '' then
        LCurrent := LCurrent + ',';
      LCurrent := LCurrent + LParts[i];
      if LParts[i].StartsWith('OU=', True) then
        LResult.Add(LCurrent);
    end;

    SetLength(Result, LResult.Count);
    for i := 0 to LResult.Count - 1 do
      Result[i] := LResult[i];
  finally
    LParts.Free;
    LResult.Free;
  end;
end;

function TActiveDirectoryService.SearchUsersPage(const AFilter: string;
  const AAttributes: TArray<string>;
  APageSize: Integer): TArray<ILDAPSearchResult>;
var
  LAttrs:  TStringList;
  LFilter: AnsiString;
  i:       Integer;
begin
  Result := [];
  FLastError := '';
  if not Connect then Exit;
  if not BindAsAdmin then Exit;

  LAttrs := TStringList.Create;
  try
    for i := 0 to High(AAttributes) do
      LAttrs.Add(AAttributes[i]);

    LFilter := Utf8EncodeToAnsi(AFilter);

    { SearchAllPages nao disponivel nesta versao do Synapse — usa Search simples }
    if FLDAPSend.Search(
         Utf8EncodeToAnsi(FConfig.BaseDN),
         True,           { scope: whole subtree }
         LFilter,
         LAttrs) then
    begin
      SetLength(Result, FLDAPSend.SearchResult.Count);
      for i := 0 to FLDAPSend.SearchResult.Count - 1 do
        Result[i] := TLDAPSearchResultAdapter.Create(
          FLDAPSend.SearchResult.Items[i]);
    end
    else
      AppendLDAPResultToLastError;
  finally
    LAttrs.Free;
  end;
end;

function TActiveDirectoryService.SetPassword(const AUserDN,
  ANewPassword: string): Boolean;
begin
  Result     := False;
  FLastError := '';
  if not (FConfig.TlsMode in [tmLDAPSNoCertCheck, tmLDAPSWithCA]) then
    raise EADWriteException.Create(
      'SetPassword requer LDAPS (TlsMode tmLDAPSNoCertCheck ou tmLDAPSWithCA)',
      ERR_LDAP_WRITE);
  if not ValidateDN(AUserDN) then
    raise EADValidationException.Create(
      'DN inválido: ' + AUserDN, ERR_LDAP_VALIDATION);
  if ANewPassword = '' then
    raise EADValidationException.Create(
      'Senha não pode ser vazia', ERR_LDAP_VALIDATION);
  if not Connect then
    raise EADWriteException.Create(
      'Falha ao conectar: ' + FLastError, ERR_LDAP_WRITE);
  if not BindAsAdmin then
    raise EADWriteException.Create(
      'Bind falhou ao redefinir senha: ' + FLastError, ERR_LDAP_WRITE);

  { SetPassword nao disponivel nesta versao do Synapse }
  FLastError := 'SetPassword: nao suportado nesta versao do Synapse';
  Result := False;
end;

function TActiveDirectoryService.ForcePasswordChange(
  const AUserDN: string): Boolean;
begin
  Result     := False;
  FLastError := '';
  if not ValidateDN(AUserDN) then
    raise EADValidationException.Create(
      'DN inválido: ' + AUserDN, ERR_LDAP_VALIDATION);
  if not Connect then
    raise EADWriteException.Create(
      'Falha ao conectar: ' + FLastError, ERR_LDAP_WRITE);
  if not BindAsAdmin then
    raise EADWriteException.Create(
      'Bind falhou ao forçar troca de senha: ' + FLastError, ERR_LDAP_WRITE);

  { ForcePasswordChange nao disponivel nesta versao do Synapse }
  FLastError := 'ForcePasswordChange: nao suportado nesta versao do Synapse';
  Result := False;
end;

{ TServiceLDAP - compatibilidade com Exemplo para ufrmLDAP_Teste }

constructor TServiceLDAP.Create(const Config: TActiveDirectoryConfig);
begin
  inherited Create;
  FConfig := Config;
  FService := TActiveDirectoryService.New(FConfig);
end;

destructor TServiceLDAP.Destroy;
begin
  FService := nil;
  inherited;
end;

function TServiceLDAP.GetConnected: Boolean;
begin
  Result := (FService <> nil) and FService.GetConnected;
end;

function TServiceLDAP.GetLastError: string;
begin
  if FService <> nil then
    Result := FService.GetLastError
  else
    Result := '';
end;

function TServiceLDAP.Connect: Boolean;
begin
  Result := (FService <> nil) and FService.Connect;
end;

function TServiceLDAP.Disconnect: Boolean;
begin
  Result := (FService <> nil) and FService.Disconnect;
end;

function TServiceLDAP.TestConnection: Boolean;
begin
  Result := (FService <> nil) and FService.TestConnection;
end;

function TServiceLDAP.Authenticate(const AUsername, APassword: string): Boolean;
begin
  Result := (FService <> nil) and FService.Authenticate(AUsername, APassword);
end;

function TServiceLDAP.AuthenticateUser(const AUserDN, APassword: string): Boolean;
begin
  Result := (FService <> nil) and FService.AuthenticateUser(AUserDN, APassword);
end;

function TServiceLDAP.GetServerInfo: string;
begin
  if FService <> nil then
    Result := FService.GetServerInfo
  else
    Result := '';
end;

function TServiceLDAP.GetConnectionStatus: string;
begin
  if FService <> nil then
    Result := FService.GetConnectionStatus
  else
    Result := 'Não conectado';
end;

procedure TServiceLDAP.AddSearchOU(const OU: string);
begin
  if FService <> nil then
    FService.AddSearchOU(OU);
end;

// ─────────────────────────────────────────────────────────────────────────────
// Delegação total — paridade com Version.Old (V1.4.0)
// ─────────────────────────────────────────────────────────────────────────────

function TServiceLDAP.ValidateDN(const DN: string): Boolean;
begin
  Result := (FService <> nil) and FService.ValidateDN(DN);
end;

function TServiceLDAP.GetCommonName(const DN: string): string;
begin
  if FService <> nil then
    Result := FService.GetCommonName(DN)
  else
    Result := DN;
end;

function TServiceLDAP.GetObjectClass(const ObjectDN: string): string;
begin
  if FService <> nil then
    Result := FService.GetObjectClass(ObjectDN)
  else
    Result := 'unknown';
end;

function TServiceLDAP.ListContainerObjects(const ContainerDN: string): TStringList;
begin
  if FService <> nil then
    Result := FService.ListContainerObjects(ContainerDN)
  else
    Result := TStringList.Create;
end;

function TServiceLDAP.ListContainerObjectsDetailed(const ContainerDN: string): TStringList;
begin
  if FService <> nil then
    Result := FService.ListContainerObjectsDetailed(ContainerDN)
  else
    Result := TStringList.Create;
end;

function TServiceLDAP.GetObjectAttributes(const ObjectDN: string): TStringList;
begin
  if FService <> nil then
    Result := FService.GetObjectAttributes(ObjectDN)
  else
    Result := TStringList.Create;
end;

function TServiceLDAP.GetObjectAttributesFormatted(const ObjectDN: string): string;
begin
  if FService <> nil then
    Result := FService.GetObjectAttributesFormatted(ObjectDN)
  else
    Result := '';
end;

function TServiceLDAP.ListGroups: TStringList;
begin
  if FService <> nil then
    Result := FService.ListGroups
  else
    Result := TStringList.Create;
end;

function TServiceLDAP.ListGroupsInOU(const OUDN: string): TStringList;
begin
  if FService <> nil then
    Result := FService.ListGroupsInOU(OUDN)
  else
    Result := TStringList.Create;
end;

function TServiceLDAP.ListGroupsDetailed: TStringList;
begin
  if FService <> nil then
    Result := FService.ListGroupsDetailed
  else
    Result := TStringList.Create;
end;

function TServiceLDAP.GetGroupMembers(const GroupDN: string): TStringList;
begin
  if FService <> nil then
    Result := FService.GetGroupMembers(GroupDN)
  else
    Result := TStringList.Create;
end;

function TServiceLDAP.GetGroupMembersDetailed(const GroupDN: string): TStringList;
begin
  if FService <> nil then
    Result := FService.GetGroupMembersDetailed(GroupDN)
  else
    Result := TStringList.Create;
end;

function TServiceLDAP.IsUserMemberOfGroup(const UserDN, GroupDN: string): Boolean;
begin
  Result := (FService <> nil) and FService.IsUserMemberOfGroup(UserDN, GroupDN);
end;

function TServiceLDAP.SearchObjects(const BaseDN, Filter: string;
  const Attributes: TStringList): TStringList;
begin
  if FService <> nil then
    Result := FService.SearchObjects(BaseDN, Filter, Attributes)
  else
    Result := TStringList.Create;
end;

function TServiceLDAP.SearchWithCustomFilter(const CustomFilter: string;
  const BaseDN: string): TStringList;
begin
  if FService <> nil then
    Result := FService.SearchWithCustomFilter(CustomFilter, BaseDN)
  else
    Result := TStringList.Create;
end;

function TServiceLDAP.FindObjectByAttribute(const AttributeName, AttributeValue: string;
  const ObjectType: string): TStringList;
begin
  if FService <> nil then
    Result := FService.FindObjectByAttribute(AttributeName, AttributeValue, ObjectType)
  else
    Result := TStringList.Create;
end;

function TServiceLDAP.FindUserByAttribute(const AttributeName, AttributeValue: string): TStringList;
begin
  if FService <> nil then
    Result := FService.FindUserByAttribute(AttributeName, AttributeValue)
  else
    Result := TStringList.Create;
end;

function TServiceLDAP.FindComputerByAttribute(const AttributeName, AttributeValue: string): TStringList;
begin
  if FService <> nil then
    Result := FService.FindComputerByAttribute(AttributeName, AttributeValue)
  else
    Result := TStringList.Create;
end;

function TServiceLDAP.GetObjectDetailsByAttribute(
  const AttributeName, AttributeValue: string): TStringList;
begin
  if FService <> nil then
    Result := FService.GetObjectDetailsByAttribute(AttributeName, AttributeValue)
  else
    Result := TStringList.Create;
end;

function TServiceLDAP.SearchObjectsByAttribute(
  const AttributeName, AttributeValue: string;
  const ObjectTypes: array of string): TStringList;
begin
  if FService <> nil then
    Result := FService.SearchObjectsByAttribute(AttributeName, AttributeValue, ObjectTypes)
  else
    Result := TStringList.Create;
end;

function TServiceLDAP.FindObjectsByMultipleAttributes(
  const AAttributes, AValues: array of string;
  const AObjectType: string): TStringList;
begin
  if FService <> nil then
    Result := FService.FindObjectsByMultipleAttributes(AAttributes, AValues, AObjectType)
  else
    Result := TStringList.Create;
end;

function TServiceLDAP.FindObjectBySAMAccountName(const SAMAccountName: string;
  const ObjectType: string): TStringList;
begin
  if FService <> nil then
    Result := FService.FindObjectBySAMAccountName(SAMAccountName, ObjectType)
  else
    Result := TStringList.Create;
end;

function TServiceLDAP.FindUserBySAMAccountName(const SAMAccountName: string): TStringList;
begin
  if FService <> nil then
    Result := FService.FindUserBySAMAccountName(SAMAccountName)
  else
    Result := TStringList.Create;
end;

function TServiceLDAP.FindComputerBySAMAccountName(const SAMAccountName: string): TStringList;
begin
  if FService <> nil then
    Result := FService.FindComputerBySAMAccountName(SAMAccountName)
  else
    Result := TStringList.Create;
end;

function TServiceLDAP.GetObjectDetailsBySAMAccountName(const SAMAccountName: string): TStringList;
begin
  if FService <> nil then
    Result := FService.GetObjectDetailsBySAMAccountName(SAMAccountName)
  else
    Result := TStringList.Create;
end;

// ───────────────────────────────────────────────────────────────────────────────
// V1.6.0 -- Paridade final com Version.Old (público no wrapper)
// ───────────────────────────────────────────────────────────────────────────────

procedure TServiceLDAP.SetSearchLogCallback(ACallback: TLDAPSearchLogProc);
begin
  if FService <> nil then
    FService.SetSearchLogCallback(ACallback);
end;

{$IFDEF USE_LOGGERS}
procedure TServiceLDAP.SetLogger(const ALogger: ILogger);
begin
  if FService <> nil then
    FService.SetLogger(ALogger);
end;
{$ENDIF}

procedure TServiceLDAP.LogLDAPSearch(const AOperation, ABaseDN, AFilter: string;
                                    const AStartTime: TDateTime;
                                    AResultCount: Integer;
                                    ASuccess: Boolean;
                                    const AErrorMessage: string);
var
  LSvc: TActiveDirectoryService;
begin
  // Acesso direto ao TActiveDirectoryService para reutilizar o LogLDAPSearch
  // privado que já implementa o fallback DEBUG. A interface IActiveDirectoryService
  // não expõe LogLDAPSearch (privado por design do SSOT), então usamos cast da
  // implementação concreta via GetInterface.
  if FService = nil then
    Exit;
  if FService is TActiveDirectoryService then
    LSvc := TActiveDirectoryService(FService as TObject)
  else
    LSvc := nil;
  if LSvc <> nil then
    LSvc.LogLDAPSearch(AOperation, ABaseDN, AFilter, AStartTime,
                       AResultCount, ASuccess, AErrorMessage);
end;

function TServiceLDAP.ExecuteLDAPSearch(const AOperation, ABaseDN, AFilter: string): TStringList;
var
  LStart: TDateTime;
  LSuccess: Boolean;
  LErrorMsg: string;
begin
  // Adaptador para a assinatura legada (Version.Old:108). O privado do SSOT
  // recebe (ABaseDN, AFilter, AAttributes: TStringList) e retorna a lista.
  // Como o privado já faz LogLDAPSearch com operation 'ExecuteLDAPSearch', este
  // wrapper público faz um segundo log com o AOperation fornecido para manter
  // semântica legada (operation customizável).
  Result := TStringList.Create;
  LStart := Now;
  LSuccess := False;
  LErrorMsg := '';
  try
    if FService = nil then
    begin
      LErrorMsg := 'Servico nao inicializado';
      Exit;
    end;
    // Usa SearchObjects público que tem assinatura equivalente (BaseDN, Filter, Attrs=nil).
    Result.Free;
    Result := FService.SearchObjects(ABaseDN, AFilter, nil);
    LSuccess := True;
  finally
    // Log adicional com o AOperation nomeado pelo consumidor (paridade Version.Old).
    LogLDAPSearch(AOperation, ABaseDN, AFilter, LStart, Result.Count, LSuccess, LErrorMsg);
  end;
end;

{$ENDIF USE_LDAP}

{ ── Runtime OpenSSL DLL path resolution (V1.5.0+) ─────────────────────────────
  Só invocado quando USE_OPENSSL3 ou USE_OPENSSL4 está activo. Para compat
  V1.4.0 (sem define), este bloco não existe — comportamento Windows default
  (procura DLLs na pasta do .exe + PATH + System32) é preservado. }
{$IF DEFINED(USE_OPENSSL3) OR DEFINED(USE_OPENSSL4)}
initialization
  TOpenSSLPaths.Apply(
    {$IFDEF USE_OPENSSL4}4{$ELSE}3{$ENDIF}
  );
{$IFEND}

end.
