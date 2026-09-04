{ =============================================================================
  Loggers.Interfaces - Contratos do módulo Loggers (v3)

  ILoggerChannel (contrato mínimo de um canal: Write, Name, Enabled, Health)
  + ILogger (contrato fluente núcleo: Log/Info/Warning/Error/... + 3 hooks
  canceláveis OnBeforeWrite/OnAfterWrite/OnLevelCheck + RegisterChannel +
  Min Level + Flush).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.10.0
  FileVersion:    1.1.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           22/07/2026

  Changelog (file):
  - (sync 27/07/2026) ModuleVersion sincronizado para 1.10.0 - F8 Onda 8.9 (hardening pos-auditoria); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.10.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.9.0 - F8 Onda 8.4.5 acrescenta o canal TLoggerChannelWebSocket (8o canal baseline, 3o real sobre ICS, resolve P2); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.9.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.8.0 - F8 Onda 8.4.4 acrescenta o canal TLoggerChannelEmail (7o canal baseline, 2o real sobre ICS); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.8.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.7.0 - F8 Onda 8.4.3 acrescenta o canal TLoggerChannelHttp (6o canal baseline, 1o real sobre ICS); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.7.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.6.0 - F8 Onda 8.4.2 acrescenta o canal TLoggerChannelCSV (5o canal baseline); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.6.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.5.0 - F8 Onda 8.4.1 acrescenta o canal TLoggerChannelEventLog (Windows Event Log, 4o canal baseline); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.5.0.
  - (sync 22/07/2026) ModuleVersion sincronizado para 1.4.0 - Loggers.Database.pas removeu a dependencia de IPoolConnections/TPoolBroker (conexao propria, direta), decisao de arquitectura do owner ('o Loggers via consumir sem pool direto o Connections'); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.4.0.
  - 1.1.0 (22/07/2026): GUID de ILoggerChannel corrigido — colidia com
    IConnection (Connections.Interfaces.pas), 2 interfaces distintas com o
    mesmo GUID literal no mesmo programa (bug-653, copiado por acidente do
    material de referência legado durante a onda 8.0/8.1).
  - 1.0.0 (21/07/2026): FASE 8 Onda 8.1 — ILoggerChannel (W/Name/Enabled/Health),
    ILogger (fluent Log*/RegisterChannel/hooks/MinLevel/Flush).
  ============================================================================= }

unit Loggers.Interfaces;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_LOGGERS}

uses
{$IF DEFINED(FPC)}
  SysUtils, Classes,
{$ELSE}
  System.SysUtils, System.Classes,
{$ENDIF}
  Commons.Types,
  Commons.Loggers.Types;

type
  { Forward declarations. }
  ILogger = interface;
  ILoggerChannel = interface;

  { Assinatura do hook OnBeforeWrite (cancelável). }
  TLoggerBeforeWriteEvent = procedure(const AEntry: TLoggerEntry; var ACancel: Boolean) of object;

  { Assinatura do hook OnAfterWrite. }
  TLoggerAfterWriteEvent = procedure(const AEntry: TLoggerEntry) of object;

  { Assinatura do hook OnLevelCheck (permite override dinâmico de "deve logar?"). }
  TLoggerLevelCheckEvent = function(ALevel: TLogLevel): Boolean of object;

  { ==========================================================================
    ILoggerChannel - Contrato mínimo de um canal de log
    ========================================================================== }
  ILoggerChannel = interface
    ['{5F2E9A10-3C7B-4D8E-9A61-7B2F0C4E8D31}']

    { Nome único do canal (ex. "Database", "TextFile", "JsonNDJSON"). }
    function Name: string;

    { Escreve a entrada. Retorna True se bem-sucedido, False em erro gracioso. }
    function Write(const AEntry: TLoggerEntry): Boolean;

    { Estado do canal (True = ativo). }
    function Enabled: Boolean; overload;
    function Enabled(const AValue: Boolean): ILoggerChannel; overload;

    { Health-check: True se o canal está acessível. }
    function IsHealthy: Boolean;
  end;

  { ==========================================================================
    ILogger - Interface fluente do núcleo (fan-out + fail-over + hooks)
    ========================================================================== }
  ILogger = interface
    ['{B2C3D4E5-F6A7-B890-1CDE-F1234567890A}']

    { Registra um canal para receber todas as entradas (fan-out). }
    function RegisterChannel(const AChannel: ILoggerChannel): ILogger;

    { Nível mínimo (entradas com nível < MinLevel são descartadas). }
    function MinLevel: TLogLevel; overload;
    function MinLevel(const AValue: TLogLevel): ILogger; overload;

    { Métodos de log fluentes + overloads com parâmetros/exceção. }
    procedure Info(const AMessage: string); overload;
    procedure Info(const AMessage: string; const AData: array of const); overload;
    procedure Info(const AMessage: string; AException: TObject); overload;

    procedure Success(const AMessage: string); overload;
    procedure Success(const AMessage: string; const AData: array of const); overload;
    procedure Success(const AMessage: string; AException: TObject); overload;

    procedure Warning(const AMessage: string); overload;
    procedure Warning(const AMessage: string; const AData: array of const); overload;
    procedure Warning(const AMessage: string; AException: TObject); overload;

    procedure Error(const AMessage: string); overload;
    procedure Error(const AMessage: string; const AData: array of const); overload;
    procedure Error(const AMessage: string; AException: TObject); overload;

    procedure Critical(const AMessage: string); overload;
    procedure Critical(const AMessage: string; const AData: array of const); overload;
    procedure Critical(const AMessage: string; AException: TObject); overload;

    procedure Exception(const AMessage: string; E: TObject); overload;
    procedure Exception(const AMessage: string; const AData: array of const; E: TObject); overload;

    procedure Debug(const AMessage: string); overload;
    procedure Debug(const AMessage: string; const AData: array of const); overload;
    procedure Debug(const AMessage: string; AException: TObject); overload;

    procedure Trace(const AMessage: string); overload;
    procedure Trace(const AMessage: string; const AData: array of const); overload;
    procedure Trace(const AMessage: string; AException: TObject); overload;

    procedure Done(const AMessage: string); overload;
    procedure Done(const AMessage: string; const AData: array of const); overload;
    procedure Done(const AMessage: string; AException: TObject); overload;

    { Método genérico. }
    procedure Log(ALevel: TLogLevel; const AMessage: string); overload;
    procedure Log(ALevel: TLogLevel; const AMessage: string; const AData: array of const); overload;
    procedure Log(ALevel: TLogLevel; const AMessage: string; AException: TObject); overload;

    { Descarga a fila assíncrona (se houver). }
    procedure Flush;

    { ==========================================================================
      Hooks (3 apenas com valor comprovado)
      ========================================================================== }

    { Antes de escrever — pode cancelar (ACancel := True). }
    function OnBeforeWrite: TLoggerBeforeWriteEvent; overload;
    function OnBeforeWrite(const AValue: TLoggerBeforeWriteEvent): ILogger; overload;

    { Depois de escrever (sucesso ou erro do canal desconsiderado). }
    function OnAfterWrite: TLoggerAfterWriteEvent; overload;
    function OnAfterWrite(const AValue: TLoggerAfterWriteEvent): ILogger; overload;

    { Override dinâmico: "devo logar este nível?" (falha-segura: assume True). }
    function OnLevelCheck: TLoggerLevelCheckEvent; overload;
    function OnLevelCheck(const AValue: TLoggerLevelCheckEvent): ILogger; overload;
  end;

{$ENDIF USE_LOGGERS}

implementation

end.
