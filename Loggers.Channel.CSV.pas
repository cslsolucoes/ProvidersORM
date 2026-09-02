{ =============================================================================
  Loggers.Channel.CSV - Canal CSV (Comma-Separated Values)

  TLoggerChannelCSV: implementa ILoggerChannel sobre TLoggerChannelFileBase
  (mesma mecânica partilhada de TextFile/Json - rotação por tamanho/data,
  retenção, append thread-safe). Lê a própria config do grupo 'Loggers.CSV'
  (+ 'Loggers' para AppNameOverride) via IParameters; formata cada entrada
  como uma linha CSV com escaping RFC4180 (aspas duplas), colunas fixas
  (Timestamp/Level/Category/Message/AppName/Host/ThreadId/ExceptionClass/
  ExceptionMessage/Tag) e cabeçalho opcional, escrito automaticamente no
  início de cada ficheiro novo (incl. rodados por tamanho/data, via
  TLoggerChannelFileBase.CurrentFilePath) - nunca invalida linhas já escritas.

  Absorção de lógica/semântica do LoggersORM v2.3.0 (Loggers.Channel.CSV.*), NÃO cópia
  de ficheiros: simplificado para o padrão de configuração v3 (via
  IParameters/Commons.Loggers.Consts, não a API fluente de 20+ setters do
  v2.3.0) - delimitador único por string (não enum+CustomDelimiter),
  estratégia de escape fixa (double-quote, a única recomendada no próprio
  v2.3.0), colunas fixas (não 9 flags Include* configuráveis em runtime, que
  no v2.3.0 podiam invalidar silenciosamente linhas já escritas com outro
  layout). Buffer assíncrono próprio do v2.3.0 (TThreadList<TLogEntry>) não
  migrado - a fila assíncrona do núcleo (TLoggerQueue/TLoggerWorkerThread,
  onda 8.1) já cobre esse papel para TODOS os canais, duplicá-lo por-canal
  seria mecanismo paralelo.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.10.0
  FileVersion:    1.1.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           23/07/2026

  Changelog (file):
  - 1.1.0 (27/07/2026): F8 Onda 8.9 (hardening pos-auditoria) - F4: comentario a fixar a ordem obrigatoria do escaping RFC4180 (duplicar aspas ANTES de envolver) para evitar refactor incorreto. ModuleVersion do modulo 1.9.0->1.10.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.9.0 - F8 Onda 8.4.5 acrescenta o canal TLoggerChannelWebSocket (8o canal baseline, 3o real sobre ICS, resolve P2); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.9.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.8.0 - F8 Onda 8.4.4 acrescenta o canal TLoggerChannelEmail (7o canal baseline, 2o real sobre ICS); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.8.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.7.0 - F8 Onda 8.4.3 acrescenta o canal TLoggerChannelHttp (6o canal baseline, 1o real sobre ICS); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.7.0.
  - 1.0.0 (23/07/2026): criação — FASE 8 Onda 8.4.2.
  ============================================================================= }

unit Loggers.Channel.CSV;

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
  Commons.Loggers.Types,
  Commons.Loggers.Consts,
  Loggers.Interfaces,
  Loggers.Channel.FileBase;

type
  TLoggerChannelCSV = class(TLoggerChannelFileBase)
  strict private
    FDelimiter     : string;
    FIncludeHeaders: Boolean;
    function EscapeCSV(const AValue: string): string;
    function HeaderLine: string;
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
  Commons.Types,
  Parameters.Interfaces,
  Parameters;
{$ENDIF}

constructor TLoggerChannelCSV.Create;
begin
  inherited Create('CSV');
  LoadConfig;
end;

{$IFDEF USE_PARAMETERS}
procedure TLoggerChannelCSV.LoadConfig;
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
  LSource.EnsureTable;  { idempotente - garante a tabela mesmo se este canal for criado antes do bootstrap do nucleo. }

  SetSharedConfig(
    SameText(Read(LOGGERS_TITULO_CSV, LOGGERS_CSV_ENABLED, DEFAULT_LOGGERS_CSV_ENABLED), 'True'),
    Read(LOGGERS_TITULO_CORE, LOGGERS_APP_NAME_OVERRIDE, DEFAULT_LOGGERS_APP_NAME),
    Read(LOGGERS_TITULO_CSV, LOGGERS_CSV_FOLDER_PATH, DEFAULT_LOGGERS_CSV_FOLDER),
    Read(LOGGERS_TITULO_CSV, LOGGERS_CSV_FILE_NAME_PATTERN, DEFAULT_LOGGERS_CSV_PATTERN),
    Read(LOGGERS_TITULO_CSV, LOGGERS_CSV_FILE_SUFFIX, DEFAULT_LOGGERS_CSV_SUFFIX),
    StrToIntDef(Read(LOGGERS_TITULO_CSV, LOGGERS_CSV_ROTATION_BY_SIZE_MB, DEFAULT_LOGGERS_CSV_ROTATION_SIZE), 10),
    SameText(Read(LOGGERS_TITULO_CSV, LOGGERS_CSV_ROTATION_BY_DATE, DEFAULT_LOGGERS_CSV_ROTATION_DATE), 'True'),
    StrToIntDef(Read(LOGGERS_TITULO_CSV, LOGGERS_CSV_MAX_FILES_TO_KEEP, DEFAULT_LOGGERS_CSV_MAX_FILES), 30));

  FDelimiter := Read(LOGGERS_TITULO_CSV, LOGGERS_CSV_DELIMITER, DEFAULT_LOGGERS_CSV_DELIMITER);
  if FDelimiter = '' then
    FDelimiter := DEFAULT_LOGGERS_CSV_DELIMITER;
  FIncludeHeaders := SameText(Read(LOGGERS_TITULO_CSV, LOGGERS_CSV_INCLUDE_HEADERS, DEFAULT_LOGGERS_CSV_INCLUDE_HEADERS), 'True');
end;
{$ELSE}
procedure TLoggerChannelCSV.LoadConfig;
begin
  SetSharedConfig(
    SameText(DEFAULT_LOGGERS_CSV_ENABLED, 'True'), DEFAULT_LOGGERS_APP_NAME,
    DEFAULT_LOGGERS_CSV_FOLDER, DEFAULT_LOGGERS_CSV_PATTERN, DEFAULT_LOGGERS_CSV_SUFFIX,
    StrToIntDef(DEFAULT_LOGGERS_CSV_ROTATION_SIZE, 10),
    SameText(DEFAULT_LOGGERS_CSV_ROTATION_DATE, 'True'),
    StrToIntDef(DEFAULT_LOGGERS_CSV_MAX_FILES, 30));
  FDelimiter := DEFAULT_LOGGERS_CSV_DELIMITER;
  FIncludeHeaders := SameText(DEFAULT_LOGGERS_CSV_INCLUDE_HEADERS, 'True');
end;
{$ENDIF}

function TLoggerChannelCSV.EscapeCSV(const AValue: string): string;
begin
  { F4 (auditoria F8): a ORDEM e' obrigatoria (RFC4180) - PRIMEIRO duplicar as
    aspas internas (" -> ""), SO' DEPOIS envolver o campo em aspas se contiver
    delimitador/aspas/CR/LF. Inverter produziria CSV invalido - nao refatorar. }
  Result := StringReplace(AValue, '"', '""', [rfReplaceAll]);
  if (Pos(FDelimiter, Result) > 0) or (Pos(#13, Result) > 0) or (Pos(#10, Result) > 0) or (Pos('"', Result) > 0) then
    Result := '"' + Result + '"';
end;

function TLoggerChannelCSV.HeaderLine: string;
begin
  Result := 'Timestamp' + FDelimiter + 'Level' + FDelimiter + 'Category' + FDelimiter +
    'Message' + FDelimiter + 'AppName' + FDelimiter + 'Host' + FDelimiter + 'ThreadId' + FDelimiter +
    'ExceptionClass' + FDelimiter + 'ExceptionMessage' + FDelimiter + 'Tag';
end;

function TLoggerChannelCSV.FormatEntry(const AEntry: TLoggerEntry): string;
var
  LLine: string;
begin
  LLine :=
    EscapeCSV(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', AEntry.Timestamp)) + FDelimiter +
    EscapeCSV(LogLevelToStr(AEntry.Level)) + FDelimiter +
    EscapeCSV(AEntry.Category) + FDelimiter +
    EscapeCSV(AEntry.Message) + FDelimiter +
    EscapeCSV(AEntry.AppName) + FDelimiter +
    EscapeCSV(AEntry.Host) + FDelimiter +
    EscapeCSV(IntToStr(AEntry.ThreadId)) + FDelimiter +
    EscapeCSV(AEntry.ExceptionClass) + FDelimiter +
    EscapeCSV(AEntry.ExceptionMessage) + FDelimiter +
    EscapeCSV(AEntry.Tag);

  if FIncludeHeaders and not FileExists(CurrentFilePath) then
    Result := HeaderLine + sLineBreak + LLine
  else
    Result := LLine;
end;

{$ENDIF USE_LOGGERS}

end.
