{ =============================================================================
  Exceptions.Messages.Interfaces - Contrato do leitor de catálogo de mensagens

  Descrição:
  Contrato do leitor RUNTIME do catálogo de mensagens de exceção (tabela
  `messages`, por defeito em Data/exception.db). Resolve `código MMXXXX` ou
  `constant_name` para a mensagem no idioma pedido, com fallback.

  Porquê o nome `Exceptions.Messages` e não `Exceptions.Database`: no v3 o nome
  `Exceptions.Database` já está tomado pelas EXCEÇÕES do módulo Database
  (faixa 41 + sub-faixas 70/80/90/91/92). Renomear evita a colisão — decisão do
  owner (pendência #5 do plano F15, 01/09/2026).

  Retaguarda INTERNA: consumido pelos módulos do ecossistema para resolver
  mensagens por código. NÃO há slice `TProviders.Exceptions` na fachada
  (decisão do owner, pendência #6).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.2.0
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           01/09/2026

  Changelog (file):
  - 1.0.0 (01/09/2026): F15 Onda 15.4 — criação. Porte do contrato
    `IExceptionsDatabase` da v2.3.0 (`Modulos/Exceptions/Exceptions.Database.Interfaces.pas`)
    com três diferenças deliberadas face à referência:
    (a) `FromConfig`/`FromConfigJson` NÃO são portados — leitura de INI/JSON de
        configuração é responsabilidade do módulo Parameters (F7); portá-los aqui
        duplicaria SSOT (regra transversal #14, anti-duplicação);
    (b) acrescentado `Fallback` (controlo do fallback de idioma), que a v2.3.0 não
        tinha — lá, um código sem linha no idioma pedido devolvia vazio em silêncio;
    (c) acrescentados `ClearCache` e `CacheCount` — a v2.3.0 ia à BD em TODA a
        chamada, sem cache (hot path de exceções).
  ============================================================================= }
unit Exceptions.Messages.Interfaces;

{$I ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Commons.Types,
  Connections.Interfaces;

type
  { Reexporta o record do SSOT: quem usa este contrato não precisa de conhecer
    Commons.Types directamente (mesmo padrão da v2.3.0). }
  TMessageRecord = Commons.Types.TMessageRecord;

  { Política de fallback quando não há linha para o idioma pedido.
    A v2.3.0 não tinha nenhuma — devolvia vazio, o que torna um código em falta
    indistinguível de uma mensagem vazia. }
  TMessageFallback = (
    mfNone,       // sem fallback: miss é miss
    mfDefault,    // tenta DEFAULT_LANGUAGE ('pt-BR')
    mfAnyLanguage // tenta DEFAULT_LANGUAGE e, falhando, qualquer idioma existente
  );

  IExceptionsMessages = interface
    ['{7E1C4A93-2B5D-4F08-9C6E-3A17D5B0E842}']

    { --- configuração fluente --- }
    function Language(const AValue: string): IExceptionsMessages; overload;
    function Language: string; overload;
    function Module(const AValue: string): IExceptionsMessages; overload;
    function Module: string; overload;
    function SourceProject(const AValue: string): IExceptionsMessages; overload;
    function SourceProject: string; overload;
    function Fallback(const AValue: TMessageFallback): IExceptionsMessages; overload;
    function Fallback: TMessageFallback; overload;

    { --- origem dos dados --- }
    function FromDefault: IExceptionsMessages;
    function FromFile(const APath: string): IExceptionsMessages;
    function FromConnection(const AConnection: IConnection): IExceptionsMessages;

    { --- consulta por código MMXXXX --- }
    function GetMessage(ACode: Integer): string; overload;
    function GetMessage(ACode: Integer; const AArgs: array of const): string; overload;
    function GetMessageRecord(ACode: Integer): TMessageRecord; overload;
    function Exists(ACode: Integer): Boolean; overload;

    { --- consulta por constant_name --- }
    function GetMessage(const AConstantName: string): string; overload;
    function GetMessage(const AConstantName: string; const AArgs: array of const): string; overload;
    function GetMessageRecord(const AConstantName: string): TMessageRecord; overload;
    function Exists(const AConstantName: string): Boolean; overload;

    function ListAll: TArray<TMessageRecord>;

    { --- cache (net-new face à v2.3.0) --- }
    function ClearCache: IExceptionsMessages;
    function CacheCount: Integer;

    { --- ligação --- }
    function Connect: IExceptionsMessages; overload;
    function Connect(out ASuccess: Boolean): IExceptionsMessages; overload;
    function Disconnect: IExceptionsMessages;
    function IsConnected: Boolean;
  end;

implementation

end.
