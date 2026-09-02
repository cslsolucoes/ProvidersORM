{ =============================================================================
  Commons.ActiveDirectory.Types - Tipos e estruturas (TActiveDirectoryConfig, TLDAPEntry)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.8.0 (ActiveDirectory absorvido do SSOT v1.7.6)
  FileVersion:    1.8.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           24/04/2026

  Changelog (file):
  - 1.8.0 (06/07/2026): record TLDAPConfig renomeado TActiveDirectoryConfig (owner);
    absorve GetDefaultConfig (class function static) — merge da factory homónima que
    foi removida de ActiveDirectory.Main.
  - 1.0.0 (07/03/2026): TActiveDirectoryConfig (record), TLDAPEntry (classe); conversão do Exemplo para núcleo.
  - 1.1.0 (2026-04-13): TTlsMode enum; campos TlsMode, CAFile, PageSize em TActiveDirectoryConfig.
  ============================================================================= }

unit Commons.ActiveDirectory.Types;

interface

uses
{$IFDEF FPC}
  Classes;
{$ELSE}
  System.Classes;
{$ENDIF}

type
  { Modo TLS da conexão LDAP.
    tmNone            — porta 389, plain text (sem criptografia).
    tmStartTLS        — porta 389 com STARTTLS upgrade.
    tmLDAPSNoCertCheck — porta 636 SSL sem validar CA (AD interno / dev).
    tmLDAPSWithCA     — porta 636 SSL com validação de CA (produção). }
  TTlsMode = (
    tmNone,
    tmStartTLS,
    tmLDAPSNoCertCheck,
    tmLDAPSWithCA
  );

  { Parâmetros de conexão LDAP; SearchOUs é gerenciado pelo dono do record. }
  TActiveDirectoryConfig = record
    Host: string;
    Port: Integer;
    BaseDN: string;
    BaseAuth: string;
    Username: string;
    Password: string;
    UseSSL: Boolean;     // retrocompatibilidade — preferir TlsMode
    TimeOut: Integer;
    Version: Integer;
    SearchOUs: TStringList;
    TlsMode:  TTlsMode;  // modo TLS granular; substitui UseSSL
    CAFile:   string;    // caminho CA PEM (usado somente com tmLDAPSWithCA)
    PageSize: Integer;   // tamanho de página para SearchUsersPage (padrão 1000)
    { Config default (merge da antiga factory TActiveDirectoryConfig de AD.Main). }
    class function GetDefaultConfig: TActiveDirectoryConfig; static;
  end;

  { Entrada LDAP simplificada; quem cria é responsável por liberar a instância e Attributes. }
  TLDAPEntry = class
  public
    DN: string;
    Attributes: TStringList;
    IsContainer: Boolean;
    constructor Create(const ADN: string);
    destructor Destroy; override;
  end;

implementation

{ TLDAPEntry }

constructor TLDAPEntry.Create(const ADN: string);
begin
  inherited Create;
  DN := ADN;
  Attributes := TStringList.Create;
  IsContainer := False;
end;

destructor TLDAPEntry.Destroy;
begin
  if Attributes <> nil then
    Attributes.Free;
  inherited;
end;

{ TActiveDirectoryConfig }

class function TActiveDirectoryConfig.GetDefaultConfig: TActiveDirectoryConfig;
begin
  Result.Host := '10.0.74.3';
  Result.Port := 389;
  Result.BaseDN := 'DC=CAC,DC=Local';
  Result.BaseAuth := 'CN=ldapusers,CN=Users,' + Result.BaseDN;
  Result.Username := 'CN=ldapusers,CN=Users,' + Result.BaseDN;
  Result.Password := '1q2w3e4r5T!@#$%';
  Result.UseSSL := False;
  Result.TimeOut := 60000;
  Result.Version := 3;
  Result.SearchOUs := TStringList.Create;
  Result.SearchOUs.Add('CN=Users,' + Result.BaseDN);
  Result.SearchOUs.Add('OU=Empresa,' + Result.BaseDN);
end;

end.
