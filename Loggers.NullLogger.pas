{ =============================================================================
  Loggers.NullLogger - Implementacao no-op de ILogger (SSOT, F8 Onda 8.6)

  TNullLogger: satisfaz ILogger sem custo (todos os metodos vazios, hooks
  devolvem nil). Default de SetLogger nos modulos retrofit (AD/Connections/
  PoolConnections) quando nenhum logger real e' injetado - evita "if
  Assigned(FLogger)" espalhado pelo codigo consumidor (chama sempre
  FLogger.Info/Warning/... directamente, sem guarda condicional).

  Singleton simples (TNullLogger.New devolve sempre a MESMA instancia,
  RefCount>=1 desde o inicio via referencia global - nao ha estado
  interno, seguro partilhar entre threads/consumidores).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.16.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           08/08/2026

  Changelog (file):
  - 1.0.0 (08/08/2026): criacao - F8 Onda 8.6 (retrofit transversal SetLogger em
    AD/Connections/PoolConnections). SSOT do "logger nulo" - achado de pesquisa
    de sessao anterior (24/07), so' agora implementado.
  ============================================================================= }

unit Loggers.NullLogger;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../ORM.Defines.inc}

{$IFDEF USE_LOGGERS}

uses
  Commons.Loggers.Types,
  Loggers.Interfaces;

type
  { Implementacao no-op de ILogger - todos os metodos vazios, hooks devolvem
    nil. Ver TNullLogger.New (unica forma de construcao - singleton). }
  TNullLogger = class(TInterfacedObject, ILogger)
  public
    class function New: ILogger;

    function RegisterChannel(const AChannel: ILoggerChannel): ILogger;

    function MinLevel: TLogLevel; overload;
    function MinLevel(const AValue: TLogLevel): ILogger; overload;

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

    procedure Log(ALevel: TLogLevel; const AMessage: string); overload;
    procedure Log(ALevel: TLogLevel; const AMessage: string; const AData: array of const); overload;
    procedure Log(ALevel: TLogLevel; const AMessage: string; AException: TObject); overload;

    procedure Flush;

    function OnBeforeWrite: TLoggerBeforeWriteEvent; overload;
    function OnBeforeWrite(const AValue: TLoggerBeforeWriteEvent): ILogger; overload;
    function OnAfterWrite: TLoggerAfterWriteEvent; overload;
    function OnAfterWrite(const AValue: TLoggerAfterWriteEvent): ILogger; overload;
    function OnLevelCheck: TLoggerLevelCheckEvent; overload;
    function OnLevelCheck(const AValue: TLoggerLevelCheckEvent): ILogger; overload;
  end;

{$ENDIF USE_LOGGERS}

implementation

{$IFDEF USE_LOGGERS}

var
  GInstance: ILogger;

class function TNullLogger.New: ILogger;
begin
  if GInstance = nil then
    GInstance := TNullLogger.Create;
  Result := GInstance;
end;

function TNullLogger.RegisterChannel(const AChannel: ILoggerChannel): ILogger;
begin
  Result := Self;
end;

function TNullLogger.MinLevel: TLogLevel;
begin
  Result := llTrace;
end;

function TNullLogger.MinLevel(const AValue: TLogLevel): ILogger;
begin
  Result := Self;
end;

procedure TNullLogger.Info(const AMessage: string);
begin
end;

procedure TNullLogger.Info(const AMessage: string; const AData: array of const);
begin
end;

procedure TNullLogger.Info(const AMessage: string; AException: TObject);
begin
end;

procedure TNullLogger.Success(const AMessage: string);
begin
end;

procedure TNullLogger.Success(const AMessage: string; const AData: array of const);
begin
end;

procedure TNullLogger.Success(const AMessage: string; AException: TObject);
begin
end;

procedure TNullLogger.Warning(const AMessage: string);
begin
end;

procedure TNullLogger.Warning(const AMessage: string; const AData: array of const);
begin
end;

procedure TNullLogger.Warning(const AMessage: string; AException: TObject);
begin
end;

procedure TNullLogger.Error(const AMessage: string);
begin
end;

procedure TNullLogger.Error(const AMessage: string; const AData: array of const);
begin
end;

procedure TNullLogger.Error(const AMessage: string; AException: TObject);
begin
end;

procedure TNullLogger.Critical(const AMessage: string);
begin
end;

procedure TNullLogger.Critical(const AMessage: string; const AData: array of const);
begin
end;

procedure TNullLogger.Critical(const AMessage: string; AException: TObject);
begin
end;

procedure TNullLogger.Exception(const AMessage: string; E: TObject);
begin
end;

procedure TNullLogger.Exception(const AMessage: string; const AData: array of const; E: TObject);
begin
end;

procedure TNullLogger.Debug(const AMessage: string);
begin
end;

procedure TNullLogger.Debug(const AMessage: string; const AData: array of const);
begin
end;

procedure TNullLogger.Debug(const AMessage: string; AException: TObject);
begin
end;

procedure TNullLogger.Trace(const AMessage: string);
begin
end;

procedure TNullLogger.Trace(const AMessage: string; const AData: array of const);
begin
end;

procedure TNullLogger.Trace(const AMessage: string; AException: TObject);
begin
end;

procedure TNullLogger.Done(const AMessage: string);
begin
end;

procedure TNullLogger.Done(const AMessage: string; const AData: array of const);
begin
end;

procedure TNullLogger.Done(const AMessage: string; AException: TObject);
begin
end;

procedure TNullLogger.Log(ALevel: TLogLevel; const AMessage: string);
begin
end;

procedure TNullLogger.Log(ALevel: TLogLevel; const AMessage: string; const AData: array of const);
begin
end;

procedure TNullLogger.Log(ALevel: TLogLevel; const AMessage: string; AException: TObject);
begin
end;

procedure TNullLogger.Flush;
begin
end;

function TNullLogger.OnBeforeWrite: TLoggerBeforeWriteEvent;
begin
  Result := nil;
end;

function TNullLogger.OnBeforeWrite(const AValue: TLoggerBeforeWriteEvent): ILogger;
begin
  Result := Self;
end;

function TNullLogger.OnAfterWrite: TLoggerAfterWriteEvent;
begin
  Result := nil;
end;

function TNullLogger.OnAfterWrite(const AValue: TLoggerAfterWriteEvent): ILogger;
begin
  Result := Self;
end;

function TNullLogger.OnLevelCheck: TLoggerLevelCheckEvent;
begin
  Result := nil;
end;

function TNullLogger.OnLevelCheck(const AValue: TLoggerLevelCheckEvent): ILogger;
begin
  Result := Self;
end;

{$ENDIF USE_LOGGERS}

end.
