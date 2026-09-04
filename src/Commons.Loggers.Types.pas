{ =============================================================================
  Commons.Loggers.Types - Tipos de dados do módulo Loggers (v3)

  TLogLevel (9 níveis: llInfo, llSuccess, llWarning, llError, llCritical,
  llException, llDebug, llTrace, llDone) + TLoggerEntry (record com 14 campos
  para uma entrada de log: Id, Timestamp, Level, Message, Category, AppName,
  Host, ThreadId, UserName, ExceptionClass, ExceptionMessage, StackTrace, Tag).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.11.0
  FileVersion:    1.6.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           31/07/2026

  Changelog (file):
  - 1.6.0 (31/07/2026): F8 Onda 8.4.6 (canal Console) - + FormatLoggerEntryTemplate,
    extraida de Loggers.Channel.TextFile.FormatEntry (era logica local/duplicada) -
    SSOT partilhada para o novo canal Console (stdout), que reusa exatamente o
    mesmo template do grupo 'Loggers.Format' - mesmo padrao ja aplicado a
    LoggerEntryToJSON (extraida de Loggers.Channel.Json na onda 8.4.3). Comportamento
    byte-identico (validado por regressao de smoke_loggers_channels). ModuleVersion
    do modulo 1.10.0->1.11.0.
  - 1.5.0 (27/07/2026): F8 Onda 8.9 (hardening pos-auditoria) - + campo
    ModuleVersion no cabecalho (fix X1 da auditoria: a unit estava fora do
    mecanismo de sync de versao do modulo, tal como Commons.Loggers.Consts) +
    comentario em LoggerEntryToJSON a documentar que o timestamp e' HORA LOCAL
    sem fuso (fix F5, por design). ModuleVersion do modulo 1.9.0->1.10.0.
  - 1.4.0 (23/07/2026): + StrToLogLevel (F8 Onda 8.4.4) - mapeamento nome de
    nível (string, ex. 'Error') -> TLogLevel, extraído de
    Loggers.pas.BootstrapParameters (onda 8.1, cadeia if/elseif local) para
    SSOT partilhada: o novo canal Email (onda 8.4.4) precisa exatamente do
    mesmo mapeamento para o gatilho de agregação por nível
    (AggregationMinLevel). Loggers.pas passou a delegar para esta função
    (comportamento byte-idêntico, validado por regressão de
    smoke_loggers_core).
  - 1.3.0 (23/07/2026): + LoggerEntryToJSON (F8 Onda 8.4.3) - formatação de
    UMA TLoggerEntry como objeto JSON, extraída de Loggers.Json.pas (onda 8.2,
    função local/duplicada) para SSOT partilhada: o novo canal HTTP (onda
    8.4.3) precisa exatamente da mesma serialização para o corpo do POST, e
    canais SaaS futuros (Sentry/Slack/GrayLog/Logstash/ElasticSearch, backlog
    8.4.6-8.4.15) também vão consumir JSON-por-entrada - centralizar aqui
    evita duplicar a função de escaping + o mapeamento de campos em cada
    canal novo (placement por peça - dado/lógica de formatação partilhada
    pertence a Commons, não a um canal específico). Loggers.Json.pas.FormatEntry
    passou a delegar para esta função (comportamento byte-idêntico, validado
    pela regressão de smoke_loggers_channels).
  - 1.2.0 (22/07/2026): + LogLevelToStr (nome textual do nível, onda 8.2 —
    consumido pelo template do canal .log e pelo campo "level" do canal JSON).
  - 1.1.0 (22/07/2026): + LOG_LEVEL_SEVERITY (rank de gravidade independente
    da ordem de declaração do enum) — corrige filtragem por MinLevel, que
    seria incorreta comparando Ord(TLogLevel) diretamente (Debug/Trace têm
    ordinal alto mas gravidade baixa).
  - 1.0.0 (21/07/2026): criação — FASE 8 Onda 8.1. TLogLevel (9 valores),
    TLoggerEntry (record com 14 campos para persistência/serialização).
  ============================================================================= }

unit Commons.Loggers.Types;

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
  Commons.Types;

type
  { Nível de log (9 valores). Ordenação ascendente = severidade decrescente
    (Debug/Trace = mais informativo; Critical/Exception = mais grave). }
  TLogLevel = (
    llInfo,        // 0: informação standard
    llSuccess,     // 1: operação bem-sucedida
    llWarning,     // 2: aviso (algo inesperado mas recuperável)
    llError,       // 3: erro (falha, operação abortada)
    llCritical,    // 4: falha crítica (risco ao sistema)
    llException,   // 5: exceção capturada
    llDebug,       // 6: debug (desenvolvedores)
    llTrace,       // 7: trace (máximo detalhe)
    llDone         // 8: conclusão/marco (ex.: startup OK)
  );

  { Entrada de log (record imutável). Representa uma linha que será persistida
    em qualquer canal (Database, ficheiro .log, JSON, etc.). }
  TLoggerEntry = record
    Id                  : Int64;      // PK auto-incrementado no canal DB
    Timestamp           : TDateTime;  // data/hora da entrada
    Level               : TLogLevel;  // nível de severidade
    Message             : string;     // texto principal da mensagem
    Category            : string;     // rótulo temático (ex. "Database", "Auth")
    AppName             : string;     // nome da app (ex. "MyApp.exe")
    Host                : string;     // hostname da máquina
    ThreadId            : UInt32;     // ID da thread que gerou a entrada
    UserName            : string;     // utilizador do SO
    ExceptionClass      : string;     // tipo de exceção (ex. "EAccessViolation")
    ExceptionMessage    : string;     // mensagem da exceção
    StackTrace          : string;     // pilha de chamadas (se aplicável)
    Tag                 : string;     // metadado customizável (ex. "perf", "audit")
  end;

const
  { Rank de severidade por nível, INDEPENDENTE da ordem de declaração do enum
    (que segue a ordem de listagem do plano F8, não a ordem de gravidade —
    Debug/Trace vêm DEPOIS de Critical/Exception no enum mas são MENOS graves).
    Usado para filtragem por MinLevel: descarta entradas com
    LOG_LEVEL_SEVERITY[ALevel] < LOG_LEVEL_SEVERITY[AMinLevel]. Não usar Ord()
    diretamente para comparar gravidade. }
  LOG_LEVEL_SEVERITY: array[TLogLevel] of Integer = (
    2,  // llInfo
    2,  // llSuccess
    3,  // llWarning
    4,  // llError
    6,  // llCritical
    5,  // llException
    1,  // llDebug
    0,  // llTrace
    2   // llDone
  );

{ Nome textual do nível (usado por canais de output — template .log, campo
  "level" do JSON, futura coluna do canal Database). Mesmos nomes usados em
  Commons.Loggers.Consts (DEFAULT_LOGGERS_DEFAULT_LEVEL etc.). }
function LogLevelToStr(ALevel: TLogLevel): string;

{ Formata UMA entrada como objeto JSON de uma linha (sem quebra de linha) -
  mesmo shape usado pelo canal Json (NDJSON) e pelo corpo do POST do canal
  Http. Não usa TJSONObject para evitar alocação por entrada. }
function LoggerEntryToJSON(const AEntry: TLoggerEntry): string;

{ Mapeia o nome textual de um nível (case-insensitive, mesmos nomes de
  LogLevelToStr) para TLogLevel; nome vazio/não reconhecido devolve ADefault
  (fail-safe). Usado pelo núcleo (DefaultLevel) e pelo canal Email
  (AggregationMinLevel). }
function StrToLogLevel(const AName: string; ADefault: TLogLevel): TLogLevel;

{ Formata UMA entrada segundo um template com tokens (partilhado entre os
  canais TextFile e Console - grupo 'Loggers.Format'): Date/Time/Level/
  Message/Category/AppName/Host/ThreadId/Tag. Anexa ExceptionClass/Message
  no fim quando presentes. Extraída de Loggers.Channel.TextFile.FormatEntry
  (onda 8.2) para SSOT partilhada — o canal Console (onda 8.4.6) precisa
  exatamente da mesma formatação. }
function FormatLoggerEntryTemplate(const AEntry: TLoggerEntry;
  const ATemplate, ADateFormat, ATimeFormat: string): string;

{$ENDIF USE_LOGGERS}

implementation

{$IFDEF USE_LOGGERS}

function LogLevelToStr(ALevel: TLogLevel): string;
const
  CNames: array[TLogLevel] of string = (
    'Info', 'Success', 'Warning', 'Error', 'Critical', 'Exception', 'Debug', 'Trace', 'Done'
  );
begin
  Result := CNames[ALevel];
end;

{ Escapa uma string para caber num literal JSON (aspas, barra invertida,
  controlo). }
function JSONEscapeString(const S: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    case C of
      '"': Result := Result + '\"';
      '\': Result := Result + '\\';
      #8:  Result := Result + '\b';
      #9:  Result := Result + '\t';
      #10: Result := Result + '\n';
      #12: Result := Result + '\f';
      #13: Result := Result + '\r';
    else
      if Ord(C) < 32 then
        Result := Result + Format('\u%.4x', [Ord(C)])
      else
        Result := Result + C;
    end;
  end;
end;

function LoggerEntryToJSON(const AEntry: TLoggerEntry): string;
begin
  { F5 (auditoria F8): o timestamp e' HORA LOCAL do processo (AEntry.Timestamp vem
    de Now), serializado SEM sufixo de fuso - por design (os logs sao lidos no
    mesmo fuso do servidor que os gera). NAO anexar 'Z' (seria falsamente UTC). }
  Result :=
    '{"id":' + IntToStr(AEntry.Id) +
    ',"timestamp":"' + FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz', AEntry.Timestamp) + '"' +
    ',"level":"' + LogLevelToStr(AEntry.Level) + '"' +
    ',"message":"' + JSONEscapeString(AEntry.Message) + '"' +
    ',"category":"' + JSONEscapeString(AEntry.Category) + '"' +
    ',"appName":"' + JSONEscapeString(AEntry.AppName) + '"' +
    ',"host":"' + JSONEscapeString(AEntry.Host) + '"' +
    ',"threadId":' + IntToStr(AEntry.ThreadId) +
    ',"userName":"' + JSONEscapeString(AEntry.UserName) + '"' +
    ',"tag":"' + JSONEscapeString(AEntry.Tag) + '"';
  if AEntry.ExceptionClass <> '' then
    Result := Result +
      ',"exceptionClass":"' + JSONEscapeString(AEntry.ExceptionClass) + '"' +
      ',"exceptionMessage":"' + JSONEscapeString(AEntry.ExceptionMessage) + '"';
  if AEntry.StackTrace <> '' then
    Result := Result + ',"stackTrace":"' + JSONEscapeString(AEntry.StackTrace) + '"';
  Result := Result + '}';
end;

function StrToLogLevel(const AName: string; ADefault: TLogLevel): TLogLevel;
begin
  if SameText(AName, 'Success') then Result := llSuccess
  else if SameText(AName, 'Warning') then Result := llWarning
  else if SameText(AName, 'Error') then Result := llError
  else if SameText(AName, 'Critical') then Result := llCritical
  else if SameText(AName, 'Exception') then Result := llException
  else if SameText(AName, 'Debug') then Result := llDebug
  else if SameText(AName, 'Trace') then Result := llTrace
  else if SameText(AName, 'Done') then Result := llDone
  else if SameText(AName, 'Info') then Result := llInfo
  else Result := ADefault;
end;

function FormatLoggerEntryTemplate(const AEntry: TLoggerEntry;
  const ATemplate, ADateFormat, ATimeFormat: string): string;
begin
  Result := ATemplate;
  Result := StringReplace(Result, '{Date}', FormatDateTime(ADateFormat, AEntry.Timestamp), [rfReplaceAll]);
  Result := StringReplace(Result, '{Time}', FormatDateTime(ATimeFormat, AEntry.Timestamp), [rfReplaceAll]);
  Result := StringReplace(Result, '{Level}', LogLevelToStr(AEntry.Level), [rfReplaceAll]);
  Result := StringReplace(Result, '{Message}', AEntry.Message, [rfReplaceAll]);
  Result := StringReplace(Result, '{Category}', AEntry.Category, [rfReplaceAll]);
  Result := StringReplace(Result, '{AppName}', AEntry.AppName, [rfReplaceAll]);
  Result := StringReplace(Result, '{Host}', AEntry.Host, [rfReplaceAll]);
  Result := StringReplace(Result, '{ThreadId}', IntToStr(AEntry.ThreadId), [rfReplaceAll]);
  Result := StringReplace(Result, '{Tag}', AEntry.Tag, [rfReplaceAll]);
  if AEntry.ExceptionClass <> '' then
    Result := Result + ' [' + AEntry.ExceptionClass + ': ' + AEntry.ExceptionMessage + ']';
end;

{$ENDIF USE_LOGGERS}

end.
