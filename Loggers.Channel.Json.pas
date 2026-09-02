{ =============================================================================
  Loggers.Channel.Json - Canal baseline JSON (NDJSON, append-only)

  TLoggerChannelJson: implementa ILoggerChannel sobre TLoggerChannelFileBase.
  Lê a própria config do grupo 'Loggers.Json' (+ 'Loggers' para
  AppNameOverride) via IParameters; cada entrada vira UMA linha JSON válida
  (newline-delimited JSON). O formato "Array" do legado v2.3.0 (reescreve o
  ficheiro inteiro por entrada) foi identificado na onda 8.0 como anti-padrão
  e DELIBERADAMENTE não é suportado aqui — só NDJSON.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.10.0
  FileVersion:    1.1.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           23/07/2026

  Changelog (file):
  - (sync 27/07/2026) ModuleVersion sincronizado para 1.10.0 - F8 Onda 8.9 (hardening pos-auditoria); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.10.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.9.0 - F8 Onda 8.4.5 acrescenta o canal TLoggerChannelWebSocket (8o canal baseline, 3o real sobre ICS, resolve P2); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.9.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.8.0 - F8 Onda 8.4.4 acrescenta o canal TLoggerChannelEmail (7o canal baseline, 2o real sobre ICS); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.8.0.
  - 1.1.0 (23/07/2026): F8 Onda 8.4.3 - FormatEntry passou a delegar para a
    nova função partilhada Commons.Loggers.Types.LoggerEntryToJSON (extraída
    daqui, era local/duplicada) - o canal Http novo (onda 8.4.3) precisa da
    mesma serialização para o corpo do POST. Comportamento byte-idêntico
    (validado por regressão de smoke_loggers_channels).
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.6.0 - F8 Onda 8.4.2 acrescenta o canal TLoggerChannelCSV (5o canal baseline); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.6.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.5.0 - F8 Onda 8.4.1 acrescenta o canal TLoggerChannelEventLog (Windows Event Log, 4o canal baseline); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.5.0.
  - (sync 22/07/2026) ModuleVersion sincronizado para 1.4.0 - Loggers.Channel.Database.pas removeu a dependencia de IPoolConnections/TPoolBroker (conexao propria, direta), decisao de arquitectura do owner ('o Loggers via consumir sem pool direto o Connections'); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.4.0.
  - 1.0.0 (22/07/2026): criação — FASE 8 Onda 8.2.
  ============================================================================= }

unit Loggers.Channel.Json;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../ORM.Defines.inc}

{$IFDEF USE_LOGGERS}

uses
{$IF DEFINED(FPC)}
  SysUtils, Classes,
{$ELSE}
  System.SysUtils, System.Classes,
{$ENDIF}
  Commons.Types,
  Commons.Loggers.Types,
  Commons.Loggers.Consts,
  Loggers.Interfaces,
  Loggers.Channel.FileBase;

type
  TLoggerChannelJson = class(TLoggerChannelFileBase)
  strict protected
    function FormatEntry(const AEntry: TLoggerEntry): string; override;
    procedure LoadConfig; override;
  public
    constructor Create;
  end;

{$ENDIF USE_LOGGERS}

implementation

{$IFDEF USE_LOGGERS}

{$IFDEF USE_PARAMETERS}
uses
  Parameters.Interfaces,
  Parameters;
{$ENDIF}

constructor TLoggerChannelJson.Create;
begin
  inherited Create('Json');
  LoadConfig;
end;

{$IFDEF USE_PARAMETERS}
procedure TLoggerChannelJson.LoadConfig;
var
  LParams: IParameters;
  LSource: IParametersDatabase;

  function Read(const ATitulo, AChave, ADefault: string): string;
  var
    LVal: TParameter;
  begin
    LSource.Title(ATitulo);
    LVal := LSource.Select(AChave);
    try
      if (LVal <> nil) and (LVal.Value <> '') then
        Result := LVal.Value
      else
        Result := ADefault;
    finally
      LVal.Free;
    end;
  end;

begin
  LParams := TParameters.New;
  LSource := LParams.Database;
  LSource.AutoCreateTable(True);
  LSource.EnsureTable;  { idempotente - garante a tabela mesmo se este canal for criado antes do bootstrap do nucleo (Loggers.pas). }

  SetSharedConfig(
    SameText(Read(LOGGERS_TITULO_JSON, LOGGERS_JSON_ENABLED, DEFAULT_LOGGERS_JSON_ENABLED), 'True'),
    Read(LOGGERS_TITULO_CORE, LOGGERS_APP_NAME_OVERRIDE, DEFAULT_LOGGERS_APP_NAME),
    Read(LOGGERS_TITULO_JSON, LOGGERS_JSON_FOLDER_PATH, DEFAULT_LOGGERS_JSON_FOLDER),
    Read(LOGGERS_TITULO_JSON, LOGGERS_JSON_FILE_NAME_PATTERN, DEFAULT_LOGGERS_JSON_PATTERN),
    Read(LOGGERS_TITULO_JSON, LOGGERS_JSON_FILE_SUFFIX, DEFAULT_LOGGERS_JSON_SUFFIX),
    StrToIntDef(Read(LOGGERS_TITULO_JSON, LOGGERS_JSON_ROTATION_BY_SIZE_MB, DEFAULT_LOGGERS_JSON_ROTATION_SIZE), 10),
    SameText(Read(LOGGERS_TITULO_JSON, LOGGERS_JSON_ROTATION_BY_DATE, DEFAULT_LOGGERS_JSON_ROTATION_DATE), 'True'),
    StrToIntDef(Read(LOGGERS_TITULO_JSON, LOGGERS_JSON_MAX_FILES_TO_KEEP, DEFAULT_LOGGERS_JSON_MAX_FILES), 30));
end;
{$ELSE}
procedure TLoggerChannelJson.LoadConfig;
begin
  SetSharedConfig(
    SameText(DEFAULT_LOGGERS_JSON_ENABLED, 'True'), DEFAULT_LOGGERS_APP_NAME,
    DEFAULT_LOGGERS_JSON_FOLDER, DEFAULT_LOGGERS_JSON_PATTERN, DEFAULT_LOGGERS_JSON_SUFFIX,
    StrToIntDef(DEFAULT_LOGGERS_JSON_ROTATION_SIZE, 10),
    SameText(DEFAULT_LOGGERS_JSON_ROTATION_DATE, 'True'),
    StrToIntDef(DEFAULT_LOGGERS_JSON_MAX_FILES, 30));
end;
{$ENDIF}

function TLoggerChannelJson.FormatEntry(const AEntry: TLoggerEntry): string;
begin
  Result := LoggerEntryToJSON(AEntry);  { SSOT partilhada com o canal Http (onda 8.4.3) - ver Commons.Loggers.Types.pas 1.3.0. }
end;

{$ENDIF USE_LOGGERS}

end.
