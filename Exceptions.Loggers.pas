{ =============================================================================
  Exceptions.Loggers - Exceções do módulo Loggers (faixa MM=93)

  Hierarquia ELoggers* herdando de EExceptionBase (Exceptions.Base). Faixa 93XXXX
  conforme tabela canônica (Exceptions.Base.pas). ErrorCode na raiz (de-dup 05/07).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.10.0
  FileVersion:    1.2.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           22/07/2026

  Changelog (file):
  - 1.2.0 (03/08/2026): FASE 6 Onda 6.3 - ELoggersAttributeException (herda
    ELoggersConfigurationException) + ERR_LOGGERS_ATTRIBUTE_NOT_FOUND/
    ERR_LOGGERS_ATTRIBUTE_RTTI_NOT_AVAILABLE (930006/930007), para o
    mapeamento por atributos RTTI [Logger]/[LoggerLevel]/[LoggerCategory]
    (Attributers.Loggers.*).
  - (sync 27/07/2026) ModuleVersion sincronizado para 1.10.0 - F8 Onda 8.9 (hardening pos-auditoria); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.10.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.9.0 - F8 Onda 8.4.5 acrescenta o canal TLoggerChannelWebSocket (8o canal baseline, 3o real sobre ICS, resolve P2); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.9.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.8.0 - F8 Onda 8.4.4 acrescenta o canal TLoggerChannelEmail (7o canal baseline, 2o real sobre ICS); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.8.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.7.0 - F8 Onda 8.4.3 acrescenta o canal TLoggerChannelHttp (6o canal baseline, 1o real sobre ICS); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.7.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.6.0 - F8 Onda 8.4.2 acrescenta o canal TLoggerChannelCSV (5o canal baseline); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.6.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.5.0 - F8 Onda 8.4.1 acrescenta o canal TLoggerChannelEventLog (Windows Event Log, 4o canal baseline); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.5.0.
  - (sync 22/07/2026) ModuleVersion sincronizado para 1.4.0 - Loggers.Database.pas removeu a dependencia de IPoolConnections/TPoolBroker (conexao propria, direta), decisao de arquitectura do owner ('o Loggers via consumir sem pool direto o Connections'); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.4.0.
  - 1.1.0 (22/07/2026): removida a redeclaração self-referencial
    ERR_LOGGERS_BASE = ERR_LOGGERS_BASE (redundante — já vem de
    Exceptions.Base via uses; mesmo padrão de Exceptions.Parameters.pas, que
    não redeclara a constante base do seu módulo).
  - 1.0.0 (21/07/2026): FASE 8 Onda 8.1 — hierarquia ELoggers* (faixa 93XXXX),
    exceções base para canal indisponível, falha de escrita, config inválida.
  ============================================================================= }

unit Exceptions.Loggers;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../ORM.Defines.inc}

{$IFDEF USE_LOGGERS}

uses
{$IF DEFINED(FPC)}
  SysUtils,
{$ELSE}
  System.SysUtils,
{$ENDIF}
  Exceptions.Base;

type
  { Raiz das exceções do módulo Loggers. Herda ErrorCode de EExceptionBase. }
  ELoggersException = class(EExceptionBase);

  { Canal indisponível (desativado ou falha de acesso). }
  ELoggersChannelUnavailableException = class(ELoggersException);

  { Falha ao escrever a entrada no canal. }
  ELoggersWriteException = class(ELoggersException);

  { Configuração inválida (perfil não encontrado, parâmetro ausente, etc.). }
  ELoggersConfigurationException = class(ELoggersException);

  { Erro de mapeamento por atributos RTTI ([Logger]/[LoggerLevel]/...) - FASE 6 Onda 6.3. }
  ELoggersAttributeException = class(ELoggersConfigurationException);

const
  { Códigos de erro da faixa 93XXXX (Loggers). ERR_LOGGERS_BASE = 930000 vem
    de Exceptions.Base (import via uses) - não redeclarado aqui (evita
    self-referência; outros módulos, ex. Exceptions.Parameters, seguem o
    mesmo padrão de não re-exportar a constante base do módulo). }
  ERR_LOGGERS_CHANNEL_UNAVAILABLE     = ERR_LOGGERS_BASE + 1;  // 930001
  ERR_LOGGERS_WRITE_FAILED            = ERR_LOGGERS_BASE + 2;  // 930002
  ERR_LOGGERS_CONFIG_INVALID          = ERR_LOGGERS_BASE + 3;  // 930003
  ERR_LOGGERS_QUEUE_FULL              = ERR_LOGGERS_BASE + 4;  // 930004
  ERR_LOGGERS_CHANNEL_INIT_FAILED     = ERR_LOGGERS_BASE + 5;  // 930005
  ERR_LOGGERS_ATTRIBUTE_NOT_FOUND     = ERR_LOGGERS_BASE + 6;  // 930006 (FASE 6 Onda 6.3)
  ERR_LOGGERS_ATTRIBUTE_RTTI_NOT_AVAILABLE = ERR_LOGGERS_BASE + 7;  // 930007

{$ENDIF USE_LOGGERS}

implementation

end.
