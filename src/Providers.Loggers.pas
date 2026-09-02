{ =============================================================================
  Providers.Loggers - slice da fachada TProviders para o modulo Loggers

  Ponto de entrada unico do modulo para o ecossistema: o consumidor faz
  'uses Providers.Loggers;' e obtem a factory + os contratos + os tipos sem
  ter de conhecer a arvore interna (Loggers / Loggers.Interfaces / os 13
  Loggers.Channel.*). Espelha o padrao dos demais modulos (ex.:
  Providers.Parameters -> TProvidersParameters, Providers.Database ->
  TProvidersDatabase).

  Gated por USE_LOGGERS. Zero logica propria: delega em TLoggers (Loggers.pas,
  Onda 8.1) - factory UNICA do modulo (confirmado por leitura directa de
  Loggers.pas: 'TLoggers = class public class function New: ILogger; static;
  end;' - nenhum outro membro publico). TLoggers.New auto-regista os canais
  baseline internamente (fan-out/fail-over/fila assincrona) - os 13
  Loggers.Channel.* (CSV/Console/Database/ElasticSearch/Email/EventLog/
  FileBase/Http/Json/Memory/Redis/SysLog/TextFile/WebSocket) sao detalhe de
  implementacao do modulo, NAO expostos individualmente por esta fachada
  (hipotese do pedido original, CONFIRMADA por leitura de Loggers.Interfaces.pas
  e Loggers.pas antes de escrever este ficheiro) - o consumidor so conhece
  ILogger/ILoggerChannel (o 2o so' para quem implementa um canal custom via
  RegisterChannel).

  Re-exporta por alias os contratos/tipos publicos do nucleo (o consumidor
  nao precisa de 'uses Loggers.Interfaces' nem de 'uses Commons.Loggers.Types'
  so para nomear os tipos): ILogger, ILoggerChannel, TLogLevel, TLoggerEntry
  + as 3 assinaturas de hook (TLoggerBeforeWriteEvent/TLoggerAfterWriteEvent/
  TLoggerLevelCheckEvent), usadas pelo consumidor para implementar
  OnBeforeWrite/OnAfterWrite/OnLevelCheck.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.10.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           11/08/2026

  Changelog (file):
  - 1.0.0 (11/08/2026): criacao (FASE 10, Onda 10.1-b retomada parcialmente -
    F8/Loggers descongelada e concluida em 11/08, deixa de bloquear) - slice
    de fachada Providers.Loggers (re-export de ILogger/ILoggerChannel/
    TLogLevel/TLoggerEntry/hooks + factory TProvidersLoggers.New que delega
    em Loggers.TLoggers.New). Os 13 canais NAO sao expostos individualmente -
    ja encapsulados internamente por TLoggers.New (confirmado por leitura,
    nao assumido).
  ============================================================================= }

unit Providers.Loggers;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../ORM.Defines.inc}

{$IFDEF USE_LOGGERS}

uses
  Commons.Loggers.Types, // TLogLevel, TLoggerEntry (tipos re-exportados)
  Loggers.Interfaces,    // ILogger/ILoggerChannel + assinaturas dos 3 hooks (contratos re-exportados)
  Loggers;               // TLoggers (factory do modulo, Onda 8.1)

type
  { --- Re-export dos contratos do modulo (o consumidor nomeia-os via este slice) --- }
  ILogger        = Loggers.Interfaces.ILogger;
  ILoggerChannel = Loggers.Interfaces.ILoggerChannel;

  { --- Re-export das assinaturas de hook (OnBeforeWrite/OnAfterWrite/OnLevelCheck) --- }
  TLoggerBeforeWriteEvent = Loggers.Interfaces.TLoggerBeforeWriteEvent;
  TLoggerAfterWriteEvent  = Loggers.Interfaces.TLoggerAfterWriteEvent;
  TLoggerLevelCheckEvent  = Loggers.Interfaces.TLoggerLevelCheckEvent;

  { --- Re-export dos tipos publicos (Commons.Loggers.Types e a fonte unica; aqui so re-exposto) --- }
  TLogLevel    = Commons.Loggers.Types.TLogLevel;
  TLoggerEntry = Commons.Loggers.Types.TLoggerEntry;

  { Slice da fachada TProviders para o modulo Loggers. A F10 liga
    TProviders.NewLogger a este membro - sem duplicar logica. }
  TProvidersLoggers = class
  public
    { Factory UNICA do modulo (delega em TLoggers.New - Onda 8.1). Devolve um
      ILogger com os canais baseline ja auto-registados internamente (fan-out/
      fail-over/fila assincrona) - ver nota no cabecalho do ficheiro. }
    class function New: ILogger; static;
  end;

{$ENDIF USE_LOGGERS}

implementation

{$IFDEF USE_LOGGERS}

{ TProvidersLoggers }

class function TProvidersLoggers.New: ILogger;
begin
  Result := Loggers.TLoggers.New;
end;

{$ENDIF USE_LOGGERS}

end.
