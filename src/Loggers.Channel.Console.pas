{ =============================================================================
  Loggers.Channel.Console - Canal Console (stdout, F8 Onda 8.4.6)

  TLoggerChannelConsole: implementa ILoggerChannel sobre a saida standard do
  processo (Writeln). Mesmo molde estrutural do canal EventLog (TInterfacedObject,
  ILoggerChannel; FLock com o fix bug-659 para FPC - qualificar
  SyncObjs.TCriticalSection.Create so' no ramo FPC, porque a unit Windows
  tambem declara um TCriticalSection proprio e entra em scope na
  implementation deste ficheiro). Ao contrario do EventLog (so' Windows,
  inerte fora dele), o Console e' um canal UNIVERSAL: mesmo sem
  USE_LOGGERS_CONSOLE/USE_PARAMETERS ativos, permanece pronto a escrever com
  defaults fixos - segue o padrao ELSE-com-defaults ja usado pelos canais
  Json/CSV (LoadConfig nunca deixa o canal permanentemente morto so' por
  falta de fonte de configuracao viva).

  Formatacao da linha: reusa o MESMO template do grupo 'Loggers.Format' via a
  nova funcao partilhada Commons.Loggers.Types.FormatLoggerEntryTemplate
  (extraida nesta onda de Loggers.Channel.TextFile.FormatEntry - SSOT unica
  para os 2 canais, nao duplica a logica de substituicao de tokens). Cor por
  nivel (Windows GetStdHandle/SetConsoleTextAttribute/
  GetConsoleScreenBufferInfo) e' opcional via UseColors - mapeamento fixo,
  nao configuravel: Info=cinza claro/normal, Success/Done=verde,
  Warning=amarelo, Error/Critical/Exception=vermelho, Debug/Trace=cinza
  escuro. A LINHA de texto sai sempre por Writeln normal (nunca escrita
  direta num handle de consola) - preserva a capturabilidade via
  redirecionamento standard de Output usado pelos testes (AssignFile/
  Rewrite), porque os codigos de cor (SetConsoleTextAttribute) atuam sobre o
  handle nativo do SO, um canal totalmente separado do TextFile Pascal
  redirecionado.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.11.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           31/07/2026

  Changelog (file):
  - 1.0.0 (31/07/2026): criação — FASE 8 Onda 8.4.6 (canal Console, 9º canal
    baseline). Sem equivalente direto no LoggersORM v2.3.0/QuickLogger (novo
    canal do v3) - motivado por ser o canal mais simples/util para
    desenvolvimento local (ver console/stdout durante um debug sem abrir
    ficheiro nenhum).
  ============================================================================= }

unit Loggers.Channel.Console;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../ORM.Defines.inc}

{$IFDEF USE_LOGGERS}

uses
{$IF DEFINED(FPC)}
  SysUtils, Classes, SyncObjs,
{$ELSE}
  System.SysUtils, System.Classes, System.SyncObjs,
{$ENDIF}
  Commons.Loggers.Types,
  Loggers.Interfaces;

type
  TLoggerChannelConsole = class(TInterfacedObject, ILoggerChannel)
  strict private
    FLock      : TCriticalSection;
    FEnabled   : Boolean;
    FReady     : Boolean;  { sempre True apos LoadConfig - canal universal, sem restricao de plataforma. }
    FUseColors : Boolean;
    FTemplate  : string;
    FDateFormat: string;
    FTimeFormat: string;
    procedure LoadConfig;
{$IFDEF MSWINDOWS}
    function ColorFor(ALevel: TLogLevel): Word;
{$ENDIF}
  public
    constructor Create;
    destructor Destroy; override;
    function Name: string;
    function Write(const AEntry: TLoggerEntry): Boolean;
    function Enabled: Boolean; overload;
    function Enabled(const AValue: Boolean): ILoggerChannel; overload;
    function IsHealthy: Boolean;
  end;

{$ENDIF USE_LOGGERS}

implementation

{$IFDEF USE_LOGGERS}

{$IF DEFINED(USE_LOGGERS_CONSOLE) AND DEFINED(USE_PARAMETERS)}
  {$DEFINE LOGGERS_CON_CHANNEL_ACTIVE}
{$ENDIF}

uses
  Commons.Loggers.Consts,  { sempre em scope - os DEFAULT_LOGGERS_CONSOLE_*/DEFAULT_LOGGERS_FMT_* nao dependem de USE_PARAMETERS. }
{$IFDEF LOGGERS_CON_CHANNEL_ACTIVE}
  Commons.Types,              // TParameter
  Parameters.Interfaces,
  Parameters,
{$ENDIF}
{$IFDEF MSWINDOWS}
  {$IF DEFINED(FPC)}
  Windows,
  {$ELSE}
  Winapi.Windows,
  {$ENDIF}
{$ENDIF}
  Loggers.Version;  { mantem a unit no uses mesmo sem LOGGERS_CON_CHANNEL_ACTIVE, evita warning de uses vazio. }

constructor TLoggerChannelConsole.Create;
begin
  inherited Create;
{$IFDEF FPC}
  FLock := SyncObjs.TCriticalSection.Create;  { Windows.pp tambem declara TCriticalSection (struct WinAPI) - qualificar evita a resolucao errada (bug real FPC 3.3.1, mesmo fix do canal EventLog). }
{$ELSE}
  FLock := TCriticalSection.Create;
{$ENDIF}
  FEnabled := False;
  FReady := False;
  FUseColors := True;
  LoadConfig;
end;

destructor TLoggerChannelConsole.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TLoggerChannelConsole.Name: string;
begin
  Result := 'Console';
end;

function TLoggerChannelConsole.Enabled: Boolean;
begin
  FLock.Acquire;
  try
    Result := FEnabled and FReady;
  finally
    FLock.Release;
  end;
end;

function TLoggerChannelConsole.Enabled(const AValue: Boolean): ILoggerChannel;
begin
  FLock.Acquire;
  try
    FEnabled := AValue;
  finally
    FLock.Release;
  end;
  Result := Self;
end;

function TLoggerChannelConsole.IsHealthy: Boolean;
begin
  Result := Enabled;
end;

{$IFDEF LOGGERS_CON_CHANNEL_ACTIVE}

procedure TLoggerChannelConsole.LoadConfig;
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

  FEnabled := SameText(Read(LOGGERS_TITULO_CONSOLE, LOGGERS_CONSOLE_ENABLED, DEFAULT_LOGGERS_CONSOLE_ENABLED), 'True');
  FUseColors := SameText(Read(LOGGERS_TITULO_CONSOLE, LOGGERS_CONSOLE_USE_COLORS, DEFAULT_LOGGERS_CONSOLE_USE_COLORS), 'True');

  { Formatacao partilhada com o canal TextFile - mesmo grupo/chaves, sem
    duplicar Enabled/UseColors proprios do Console dentro de 'Loggers.Format'. }
  FTemplate := Read(LOGGERS_TITULO_FORMAT, LOGGERS_FMT_TEMPLATE, DEFAULT_LOGGERS_FMT_TEMPLATE);
  FDateFormat := Read(LOGGERS_TITULO_FORMAT, LOGGERS_FMT_DATE_FORMAT, DEFAULT_LOGGERS_FMT_DATE);
  FTimeFormat := Read(LOGGERS_TITULO_FORMAT, LOGGERS_FMT_TIME_FORMAT, DEFAULT_LOGGERS_FMT_TIME);

  FReady := True;
end;

{$ELSE}

procedure TLoggerChannelConsole.LoadConfig;
begin
  { USE_LOGGERS_CONSOLE/USE_PARAMETERS em falta - sem fonte de config viva,
    mas o canal continua PRONTO a escrever com defaults fixos (mesmo padrao
    ELSE-com-defaults do Json/CSV) - ao contrario do EventLog, o Console nao
    tem restricao de plataforma que o obrigue a ficar permanentemente inerte. }
  FEnabled := SameText(DEFAULT_LOGGERS_CONSOLE_ENABLED, 'True');
  FUseColors := SameText(DEFAULT_LOGGERS_CONSOLE_USE_COLORS, 'True');
  FTemplate := DEFAULT_LOGGERS_FMT_TEMPLATE;
  FDateFormat := DEFAULT_LOGGERS_FMT_DATE;
  FTimeFormat := DEFAULT_LOGGERS_FMT_TIME;
  FReady := True;
end;

{$ENDIF LOGGERS_CON_CHANNEL_ACTIVE}

{$IFDEF MSWINDOWS}
function TLoggerChannelConsole.ColorFor(ALevel: TLogLevel): Word;
const
  { Atributos de cor standard da consola do Windows (wAttributes) - valores
    literais para nao depender de FOREGROUND_RED/GREEN/BLUE/INTENSITY
    estarem declarados em ambos os compiladores (mesma familia de risco do
    bug real que obrigou o canal EventLog a redeclarar EVENTLOG_* sob FPC). }
  CCON_WHITE    = $0007;  // cinza claro/normal
  CCON_GREEN    = $000A;  // verde brilhante
  CCON_YELLOW   = $000E;  // amarelo brilhante
  CCON_RED      = $000C;  // vermelho brilhante
  CCON_DARKGRAY = $0008;  // cinza escuro
begin
  case ALevel of
    llSuccess, llDone:                 Result := CCON_GREEN;
    llWarning:                         Result := CCON_YELLOW;
    llError, llCritical, llException:  Result := CCON_RED;
    llDebug, llTrace:                  Result := CCON_DARKGRAY;
  else
    Result := CCON_WHITE;  { llInfo. }
  end;
end;
{$ENDIF}

function TLoggerChannelConsole.Write(const AEntry: TLoggerEntry): Boolean;
var
  LLine: string;
{$IFDEF MSWINDOWS}
  LHandle: THandle;
  LInfo: TConsoleScreenBufferInfo;
  LOldAttrs: Word;
{$ENDIF}
begin
  Result := False;
  if not (FReady and FEnabled) then
    Exit;
  FLock.Acquire;
  try
    try
      LLine := FormatLoggerEntryTemplate(AEntry, FTemplate, FDateFormat, FTimeFormat);
{$IFDEF MSWINDOWS}
      if FUseColors then
      begin
        LHandle := GetStdHandle(STD_OUTPUT_HANDLE);
        if GetConsoleScreenBufferInfo(LHandle, LInfo) then
          LOldAttrs := LInfo.wAttributes
        else
          LOldAttrs := $0007;  { sem consola real anexada (ex.: redirecionado) - fallback cinza claro/normal. }
        SetConsoleTextAttribute(LHandle, ColorFor(AEntry.Level));
        Writeln(LLine);  { Writeln normal - NUNCA escrita direta no handle, senao o redirecionamento de Output dos testes nao captura. }
        SetConsoleTextAttribute(LHandle, LOldAttrs);
      end
      else
        Writeln(LLine);
{$ELSE}
      Writeln(LLine);
{$ENDIF}
      Result := True;
    except
      Result := False;  { canal nunca propaga - fail-over do nucleo decide. }
    end;
  finally
    FLock.Release;
  end;
end;

{$ENDIF USE_LOGGERS}

end.
