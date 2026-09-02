{ =============================================================================
  Exceptions.ActiveDirectory - Hierarquia de exceções do ActiveDirectory ORM

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.8.0 (ActiveDirectory absorvido do SSOT v1.7.6)
  FileVersion:    1.0.4
  Company:        CSL Tech Solutions
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           07/03/2026

  Hierarquia:
    Exception
      EADException                — base: armazena ErrorCode
        EADConnectionException    — 40001  falha de transporte/socket
        EADAuthenticationException— 40002  bind rejeitado
        EADValidationException    — 40003  parâmetro inválido
        EADNotFoundException      — 40004  objeto não encontrado
        EADConfigurationException — 40005  configuração inválida
        EADWriteException         — 40006  falha em escrita LDAP

  Changelog (file):
  - 1.0.0 (07/03/2026): Versão inicial — EADException e 5 subclasses.
  - 1.0.4 (08/03/2026): EADWriteException (40006) para Modify/Add/Delete/ModifyDN.
  ============================================================================= }

unit Exceptions.ActiveDirectory;

interface

uses
{$IFDEF FPC}
  SysUtils,
{$ELSE}
  System.SysUtils,
{$ENDIF}
  Exceptions.Base,              // EExceptionBase (raiz canonica; ErrorCode vem daqui)
  Commons.ActiveDirectory.Consts;

type

  // ---------------------------------------------------------------------------
  // EADException — classe base (herda de EExceptionBase, prerrogativa 5)
  // ---------------------------------------------------------------------------

  (** Classe base de todas as exceções do módulo LDAP/Active Directory.
      Herda de EExceptionBase (raiz do ecossistema): o ErrorCode (faixa MM=95)
      vem da base, sem FErrorCode proprio (de-dup). A mensagem final segue o
      padrão "ClassName: <mensagem> [Código: NNN]" para os logs. *)
  EADException = class(EExceptionBase)
  public
    (** Cria a exceção com uma mensagem descritiva e um código de erro.
        @param AMessage  Descrição legível do problema.
        @param AErrorCode Código numérico da faixa 95XXXX (padrão: ERR_LDAP_BASE). *)
    constructor Create(const AMessage: string; AErrorCode: Integer = ERR_LDAP_BASE); reintroduce;
    // ErrorCode herdado de EExceptionBase (de-dup: sem campo/property proprios).
  end;


  // ---------------------------------------------------------------------------
  // Subclasses — uma por categoria de falha
  // ---------------------------------------------------------------------------

  (** Falha no transporte LDAP: host inacessível, timeout de socket,
      perda de conexão, erro no Login/Logout do Synapse.
      Código padrão: ERR_LDAP_CONNECTION (40001). *)
  EADConnectionException = class(EADException)
  public
    (** @param AMessage  Descrição da falha de conexão.
        @param AErrorCode Código de erro; padrão ERR_LDAP_CONNECTION. *)
    constructor Create(const AMessage: string; AErrorCode: Integer = ERR_LDAP_CONNECTION);
  end;

  (** Bind rejeitado pelo servidor LDAP: credenciais inválidas,
      conta bloqueada, conta expirada ou sem permissão de Bind.
      Código padrão: ERR_LDAP_AUTHENTICATION (40002). *)
  EADAuthenticationException = class(EADException)
  public
    (** @param AMessage  Descrição da falha de autenticação.
        @param AErrorCode Código de erro; padrão ERR_LDAP_AUTHENTICATION. *)
    constructor Create(const AMessage: string; AErrorCode: Integer = ERR_LDAP_AUTHENTICATION);
  end;

  (** Parâmetro inválido fornecido pelo chamador: DN mal formado,
      nome de atributo vazio, filtro LDAP incorreto, lista nula.
      Código padrão: ERR_LDAP_VALIDATION (40003). *)
  EADValidationException = class(EADException)
  public
    (** @param AMessage  Descrição do parâmetro inválido.
        @param AErrorCode Código de erro; padrão ERR_LDAP_VALIDATION. *)
    constructor Create(const AMessage: string; AErrorCode: Integer = ERR_LDAP_VALIDATION);
  end;

  (** Objeto não encontrado no diretório: usuário, grupo ou OU
      com o DN/nome informado não existe na base LDAP pesquisada.
      Código padrão: ERR_LDAP_NOT_FOUND (40004). *)
  EADNotFoundException = class(EADException)
  public
    (** @param AMessage  Identificação do objeto não encontrado.
        @param AErrorCode Código de erro; padrão ERR_LDAP_NOT_FOUND. *)
    constructor Create(const AMessage: string; AErrorCode: Integer = ERR_LDAP_NOT_FOUND);
  end;

  (** Configuração inválida detectada antes de tentar a conexão:
      Host vazio, Port fora da faixa 1–65535, Version diferente de 2 ou 3,
      BaseDN ausente.
      Código padrão: ERR_LDAP_CONFIGURATION (40005). *)
  EADConfigurationException = class(EADException)
  public
    (** @param AMessage  Descrição do campo de configuração inválido.
        @param AErrorCode Código de erro; padrão ERR_LDAP_CONFIGURATION. *)
    constructor Create(const AMessage: string; AErrorCode: Integer = ERR_LDAP_CONFIGURATION);
  end;

  (** Falha em operação de escrita LDAP: Modify (MO_Replace/MO_Add/MO_Delete),
      Add (criar objeto), Delete (remover objeto) ou ModifyDN (renomear/mover).
      Levantada também quando ChangePassword é chamado sem UseSSL=True.
      Código padrão: ERR_LDAP_WRITE (40006). *)
  EADWriteException = class(EADException)
  public
    (** @param AMessage  Descrição da falha de escrita.
        @param AErrorCode Código de erro; padrão ERR_LDAP_WRITE. *)
    constructor Create(const AMessage: string; AErrorCode: Integer = ERR_LDAP_WRITE);
  end;


implementation

{ EADException }

constructor EADException.Create(const AMessage: string; AErrorCode: Integer);
var
  LMsg: string;
begin
  // Formato padronizado: "ClassName: mensagem [Código: NNN]"
  LMsg := ClassName + ': ' + AMessage + ' [Código: ' + IntToStr(AErrorCode) + ']';
  inherited Create(LMsg, AErrorCode);  // EExceptionBase guarda o ErrorCode (de-dup)
end;

{ EADConnectionException }

constructor EADConnectionException.Create(const AMessage: string; AErrorCode: Integer);
begin
  inherited Create(AMessage, AErrorCode);
end;

{ EADAuthenticationException }

constructor EADAuthenticationException.Create(const AMessage: string; AErrorCode: Integer);
begin
  inherited Create(AMessage, AErrorCode);
end;

{ EADValidationException }

constructor EADValidationException.Create(const AMessage: string; AErrorCode: Integer);
begin
  inherited Create(AMessage, AErrorCode);
end;

{ EADNotFoundException }

constructor EADNotFoundException.Create(const AMessage: string; AErrorCode: Integer);
begin
  inherited Create(AMessage, AErrorCode);
end;

{ EADConfigurationException }

constructor EADConfigurationException.Create(const AMessage: string; AErrorCode: Integer);
begin
  inherited Create(AMessage, AErrorCode);
end;

{ EADWriteException }

constructor EADWriteException.Create(const AMessage: string; AErrorCode: Integer);
begin
  inherited Create(AMessage, AErrorCode);
end;

end.
