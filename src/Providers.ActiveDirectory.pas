{ =============================================================================
  Providers.ActiveDirectory - slice da fachada TProviders para o modulo
  ActiveDirectory (LDAP / Active Directory)

  Ponto de entrada unico do modulo para o ecossistema: o consumidor faz
  'uses Providers.ActiveDirectory;' e obtem as factories + os contratos sem
  ter de conhecer a arvore interna (ActiveDirectory.Main.Interfaces /
  ActiveDirectory.Main / ActiveDirectory.Service / Commons.ActiveDirectory.
  Types). Espelha o padrao dos demais modulos (ex.: Providers.Parameters ->
  TProvidersParameters).

  Este slice ANTECIPA a camada Main/: a FASE 10 (fachada unificada, Onda
  10.1-a2 - decisao do owner 03/08, "ActiveDirectory/ZipFile nao estao
  congelados", ver plano F10 v2.5.0) apenas liga TProviders.NewActiveDirectory
  a TProvidersActiveDirectory aqui definido - sem reescrever logica. Re-exporta
  por alias os contratos/tipos publicos (o consumidor nao precisa de 'uses
  ActiveDirectory.Main.Interfaces' nem de 'uses Commons.ActiveDirectory.Types').

  Gated por USE_ACTIVEDIRECTORY - confirmado por leitura directa de
  ORM.Defines.inc (linhas 189, 361-362): e o define PUBLICO do modulo (o
  usado pelo bloco 'uses' de ProvidersV3.dpr/.lpr para envolver toda a arvore
  ActiveDirectory.*); internamente algumas units do modulo (ex.:
  ActiveDirectory.LdapResult.pas) usam USE_LDAP, que e uma PONTE automatica
  a partir de USE_ACTIVEDIRECTORY (ORM.Defines.inc, diretiva IF: quando
  USE_ACTIVEDIRECTORY esta definido e USE_LDAP nao esta, define USE_LDAP) -
  ActiveDirectory.Main.Interfaces.pas e ActiveDirectory.Main.pas (o nucleo
  publico usado por este slice) NAO tem nenhuma diretiva IFDEF USE_LDAP nem
  IFDEF USE_ACTIVEDIRECTORY interna (confirmado por leitura + grep - zero
  ocorrencias nesses 2 ficheiros); o gate real e aplicado a arvore inteira
  pelo 'uses' condicional do .dpr/.lpr. Este slice replica esse mesmo gate
  publico (USE_ACTIVEDIRECTORY) para se manter auto-consistente mesmo se
  referenciado fora do bloco condicional do .dpr/.lpr.

  Zero logica propria: delega em TActiveDirectory (builder fluente de
  configuracao, ActiveDirectory.Main, Onda F3) e TActiveDirectoryService
  (servico LDAP completo leitura+escrita, ActiveDirectory.Service, Onda F3).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.8.0 (ActiveDirectory absorvido do SSOT v1.7.6 - confirmado
                   no cabecalho de ActiveDirectory.Main.Interfaces.pas/
                   ActiveDirectory.Main.pas)
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.0.0 (03/08/2026): criacao (FASE 10, Onda 10.1-a2 - ActiveDirectory/
    ZipFile, decisao do owner) - slice de fachada Providers.ActiveDirectory
    (re-export de IActiveDirectoryConnection/IActiveDirectoryService/
    ILDAPSearchResult/TLDAPSearchLogProc + TActiveDirectoryConfig/TTlsMode de
    Commons.ActiveDirectory.Types + factory TProvidersActiveDirectory que
    delega em TActiveDirectory.New e TActiveDirectoryService.New). A ligacao
    TProviders.NewActiveDirectory fecha na mesma onda (Main/Providers.pas).
  ============================================================================= }

unit Providers.ActiveDirectory;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_ACTIVEDIRECTORY}

uses
  Commons.ActiveDirectory.Types,   // TActiveDirectoryConfig, TTlsMode (tipos re-exportados)
  ActiveDirectory.Main.Interfaces, // IActiveDirectoryConnection/IActiveDirectoryService/ILDAPSearchResult/TLDAPSearchLogProc (contratos re-exportados)
  ActiveDirectory.Main,            // TActiveDirectory (factory do builder de configuracao, Onda F3)
  ActiveDirectory.Service;         // TActiveDirectoryService (factory do servico LDAP, Onda F3)

type
  { --- Re-export dos contratos do modulo (o consumidor nomeia-os via este slice) --- }
  IActiveDirectoryConnection = ActiveDirectory.Main.Interfaces.IActiveDirectoryConnection;
  IActiveDirectoryService    = ActiveDirectory.Main.Interfaces.IActiveDirectoryService;
  ILDAPSearchResult          = ActiveDirectory.Main.Interfaces.ILDAPSearchResult;

  { --- Re-export dos tipos publicos (Commons.ActiveDirectory.Types e ActiveDirectory.Main.Interfaces) --- }
  TActiveDirectoryConfig = Commons.ActiveDirectory.Types.TActiveDirectoryConfig;
  TTlsMode                = Commons.ActiveDirectory.Types.TTlsMode;
  TLDAPSearchLogProc      = ActiveDirectory.Main.Interfaces.TLDAPSearchLogProc;

  { Slice da fachada TProviders para o modulo ActiveDirectory. A F10 liga
    TProviders.NewActiveDirectory a estes membros - sem duplicar logica. }
  TProvidersActiveDirectory = class
  public
    { Builder fluente de configuracao (IActiveDirectoryConnection) - delega em
      TActiveDirectory.New (ActiveDirectory.Main, Onda F3). Uso tipico:
        TProviders.NewActiveDirectory.Host('dc.empresa.local').Port(389)...GetConfig
      devolve o TActiveDirectoryConfig a passar a NewService. }
    class function New: IActiveDirectoryConnection; static;

    { Servico LDAP completo (IActiveDirectoryService, leitura+escrita) - delega
      em TActiveDirectoryService.New (ActiveDirectory.Service, Onda F3).
      @param AConfig  TActiveDirectoryConfig produzido por New(...).GetConfig
                       ou por TActiveDirectoryConfig.GetDefaultConfig. }
    class function NewService(const AConfig: TActiveDirectoryConfig): IActiveDirectoryService; static;
  end;

{$ENDIF USE_ACTIVEDIRECTORY}

implementation

{$IFDEF USE_ACTIVEDIRECTORY}

{ TProvidersActiveDirectory }

class function TProvidersActiveDirectory.New: IActiveDirectoryConnection;
begin
  Result := ActiveDirectory.Main.TActiveDirectory.New;
end;

class function TProvidersActiveDirectory.NewService(
  const AConfig: TActiveDirectoryConfig): IActiveDirectoryService;
begin
  Result := ActiveDirectory.Service.TActiveDirectoryService.New(AConfig);
end;

{$ENDIF USE_ACTIVEDIRECTORY}

end.
