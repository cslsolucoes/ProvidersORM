{ =============================================================================
  Loggers.Channel.Email - Canal Email genérico (Delphi-only, via ICS)

  TLoggerChannelEmail: implementa ILoggerChannel enviando entradas de log por
  SMTP sobre o motor ICS (OverbyteIcsSmtpProt.TSslSmtpCli, síncrono via
  OpenSync/MailSync/QuitSync — mesma unit já validada por spike real na onda
  8.4.0). Reusa o padrão estabelecido pelo canal Http (onda 8.4.3): shell
  incondicional, gate `LOGGERS_EML_CHANNEL_ACTIVE` definido antes da
  interface, cliente ICS fresco por tentativa. Delphi-only enquanto ICS v9.8
  não compilar sob FPC 3.3.1 (bug-712).

  AGREGAÇÃO (o valor real deste canal vs um envio ingénuo por-entrada,
  absorvido do LoggersORM v2.3.0): quando `AggregationEnabled=True`, as
  entradas são acumuladas num buffer em memória em vez de gerar 1 email por
  entrada; o lote é enviado como UM email quando qualquer um dos 3 gatilhos
  dispara — contagem (`AggregationMaxCount`), tempo decorrido desde a 1ª
  entrada do lote (`AggregationMaxIntervalSec`) ou presença de uma entrada
  com nível >= `AggregationMinLevel` no lote (força envio imediato do lote
  inteiro, não só da entrada grave). Os 3 gatilhos são independentes -
  qualquer um pode ser desativado (`MaxCount=0`/`MaxIntervalSec=0`/
  `MinLevel='None'`), mais expressivo que o enum de estratégia mutuamente
  exclusivo do v2.3.0. Se o envio de um lote falhar, as entradas voltam para
  o buffer (não são descartadas - corrige um bug real do v2.3.0, que limpava
  o buffer incondicionalmente). `Destroy` tenta um último flush best-effort
  do que sobrar (nunca propaga).

  Absorção de lógica/semântica do LoggersORM v2.3.0 (Loggers.EMails.*+
  Engines.Email.*) e do QuickLogger (Quick.Logger.Provider.Email.pas), NÃO
  cópia de ficheiros — ver Commons.Loggers.Consts.pas 1.5.0 para o detalhe
  completo das simplificações deliberadas.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.10.0
  FileVersion:    1.1.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           23/07/2026

  Changelog (file):
  - 1.1.0 (27/07/2026): F8 Onda 8.9 (hardening pos-auditoria) - N1: passa a VALIDAR o certificado TLS (TSslContext + CertVerBundle + UseSharedCAStore/SslCAFile), anti-MITM, corrige tambem a ESslContextException que impedia SMTPS/STARTTLS; N2: clamp do timeout SMTP (TimeoutSec<=0 -> 30, evita bloqueio indefinido). ModuleVersion do modulo 1.9.0->1.10.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.9.0 - F8 Onda 8.4.5 acrescenta o canal TLoggerChannelWebSocket (8o canal baseline, 3o real sobre ICS, resolve P2); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.9.0.
  - 1.0.0 (23/07/2026): criação — FASE 8 Onda 8.4.4.
  ============================================================================= }

unit Loggers.Channel.Email;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IF DEFINED(USE_LOGGERS_EMAIL) AND DEFINED(USE_PARAMETERS) AND DEFINED(MSWINDOWS)}
  {$DEFINE LOGGERS_EML_CHANNEL_ACTIVE}
{$ENDIF}

{$IFDEF USE_LOGGERS}

uses
{$IF DEFINED(FPC)}
  SysUtils, Classes, SyncObjs, Generics.Collections,
{$ELSE}
  System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections,
{$ENDIF}
  Commons.Loggers.Types,
  Loggers.Interfaces;

type
  TLoggerChannelEmail = class(TInterfacedObject, ILoggerChannel)
  strict private
    FLock            : TCriticalSection;
    FEnabled         : Boolean;
    FReady           : Boolean;  { False se Host/FromAddress/ToAddresses vazios OU ICS indisponivel (FPC) OU config em falta. }
    FHost            : string;
    FPort            : Integer;
    FSslMode         : string;
    FUsername        : string;
    FPassword        : string;
    FAuthType        : string;
    FTimeoutSec      : Integer;
    FFromAddress     : string;
    FFromName        : string;
    FToAddresses     : string;
    FCcAddresses     : string;
    FBccAddresses    : string;
    FSubjectPrefix   : string;
    FAggEnabled      : Boolean;
    FAggMaxCount     : Integer;
    FAggMaxIntervalSec: Integer;
    FAggMinLevel     : string;
    FTlsVerifyCert   : Boolean;  { N1 (auditoria F8): valida o certificado TLS do servidor SMTP (anti-MITM). }
    FTlsCAFile       : string;   { N1: bundle CA custom em PEM (vazio = CAs raiz embutidos do ICS). }
{$IFDEF LOGGERS_EML_CHANNEL_ACTIVE}
    FBuffer          : TList<TLoggerEntry>;
    FBufferStartTime : TDateTime;
{$ENDIF}
    procedure LoadConfig;
{$IFDEF LOGGERS_EML_CHANNEL_ACTIVE}
    function ShouldFlushLocked: Boolean;
    function SendBatch(const AEntries: TArray<TLoggerEntry>): Boolean;
    function BuildSubject(const AEntries: TArray<TLoggerEntry>): string;
    procedure AppendBodyLines(const AEntries: TArray<TLoggerEntry>; ALines: TStrings);
    procedure SplitAddresses(const ARaw: string; ADest: TStrings);
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

uses
{$IFDEF LOGGERS_EML_CHANNEL_ACTIVE}
  {$IF DEFINED(FPC)}
  DateUtils,
  {$ELSE}
  System.DateUtils,
  {$ENDIF}
  OverbyteIcsTypes,           // TSmtpSslType/TSmtpAuthType + TCertVerMethod (CertVerBundle/CertVerNone, N1)
  OverbyteIcsSslBase,         // TSslContext (N1 - verificacao de certificado TLS)
  OverbyteIcsSmtpProt,        // TSslSmtpCli - motor unico ICS (spike validado na onda 8.4.0)
  Commons.Types,              // TParameter
  Commons.Loggers.Consts,
  Parameters.Interfaces,
  Parameters,
{$ENDIF}
  Loggers.Version;  { mantem a unit no uses mesmo sem LOGGERS_EML_CHANNEL_ACTIVE, evita warning de uses vazio. }

constructor TLoggerChannelEmail.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FEnabled := False;
  FReady := False;
{$IFDEF LOGGERS_EML_CHANNEL_ACTIVE}
  FBuffer := TList<TLoggerEntry>.Create;
{$ENDIF}
  LoadConfig;
end;

destructor TLoggerChannelEmail.Destroy;
{$IFDEF LOGGERS_EML_CHANNEL_ACTIVE}
var
  LPending: TArray<TLoggerEntry>;
{$ENDIF}
begin
{$IFDEF LOGGERS_EML_CHANNEL_ACTIVE}
  try
    FLock.Acquire;
    try
      LPending := FBuffer.ToArray;
      FBuffer.Clear;
    finally
      FLock.Release;
    end;
    if Length(LPending) > 0 then
      SendBatch(LPending);  { flush best-effort no shutdown - resultado ignorado, nunca propaga. }
  except
    { nunca propaga a partir do destructor. }
  end;
  FBuffer.Free;
{$ENDIF}
  FLock.Free;
  inherited;
end;

function TLoggerChannelEmail.Name: string;
begin
  Result := 'Email';
end;

function TLoggerChannelEmail.Enabled: Boolean;
begin
  FLock.Acquire;
  try
    Result := FEnabled and FReady;
  finally
    FLock.Release;
  end;
end;

function TLoggerChannelEmail.Enabled(const AValue: Boolean): ILoggerChannel;
begin
  FLock.Acquire;
  try
    FEnabled := AValue;
  finally
    FLock.Release;
  end;
  Result := Self;
end;

function TLoggerChannelEmail.IsHealthy: Boolean;
begin
  Result := Enabled;
end;

{$IFDEF LOGGERS_EML_CHANNEL_ACTIVE}

procedure TLoggerChannelEmail.LoadConfig;
var
  LParams: IParameters;
  LSource: IParametersDatabase;

  function Read(const AChave, ADefault: string): string;
  var
    LVal: TParameter;
  begin
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
  LSource.Title(LOGGERS_TITULO_EMAIL);

  FEnabled := SameText(Read(LOGGERS_EML_ENABLED, DEFAULT_LOGGERS_EML_ENABLED), 'True');
  FHost := Read(LOGGERS_EML_HOST, DEFAULT_LOGGERS_EML_HOST);
  FPort := StrToIntDef(Read(LOGGERS_EML_PORT, DEFAULT_LOGGERS_EML_PORT), 25);
  FSslMode := Read(LOGGERS_EML_SSL_MODE, DEFAULT_LOGGERS_EML_SSL_MODE);
  FUsername := Read(LOGGERS_EML_USERNAME, DEFAULT_LOGGERS_EML_USERNAME);
  FPassword := Read(LOGGERS_EML_PASSWORD, DEFAULT_LOGGERS_EML_PASSWORD);
  FAuthType := Read(LOGGERS_EML_AUTH_TYPE, DEFAULT_LOGGERS_EML_AUTH_TYPE);
  FTimeoutSec := StrToIntDef(Read(LOGGERS_EML_TIMEOUT_SEC, DEFAULT_LOGGERS_EML_TIMEOUT_SEC), 30);
  FFromAddress := Read(LOGGERS_EML_FROM_ADDRESS, DEFAULT_LOGGERS_EML_FROM_ADDRESS);
  FFromName := Read(LOGGERS_EML_FROM_NAME, DEFAULT_LOGGERS_EML_FROM_NAME);
  FToAddresses := Read(LOGGERS_EML_TO_ADDRESSES, DEFAULT_LOGGERS_EML_TO_ADDRESSES);
  FCcAddresses := Read(LOGGERS_EML_CC_ADDRESSES, DEFAULT_LOGGERS_EML_CC_ADDRESSES);
  FBccAddresses := Read(LOGGERS_EML_BCC_ADDRESSES, DEFAULT_LOGGERS_EML_BCC_ADDRESSES);
  FSubjectPrefix := Read(LOGGERS_EML_SUBJECT_PREFIX, DEFAULT_LOGGERS_EML_SUBJECT_PREFIX);
  FAggEnabled := SameText(Read(LOGGERS_EML_AGG_ENABLED, DEFAULT_LOGGERS_EML_AGG_ENABLED), 'True');
  FAggMaxCount := StrToIntDef(Read(LOGGERS_EML_AGG_MAX_COUNT, DEFAULT_LOGGERS_EML_AGG_MAX_COUNT), 100);
  FAggMaxIntervalSec := StrToIntDef(Read(LOGGERS_EML_AGG_MAX_INTERVAL_SEC, DEFAULT_LOGGERS_EML_AGG_MAX_INTERVAL_SEC), 300);
  FAggMinLevel := Read(LOGGERS_EML_AGG_MIN_LEVEL, DEFAULT_LOGGERS_EML_AGG_MIN_LEVEL);
  FTlsVerifyCert := SameText(Read(LOGGERS_EML_TLS_VERIFY_CERT, DEFAULT_LOGGERS_EML_TLS_VERIFY_CERT), 'True');
  FTlsCAFile := Read(LOGGERS_EML_TLS_CA_FILE, DEFAULT_LOGGERS_EML_TLS_CA_FILE);

  if FTimeoutSec <= 0 then
    FTimeoutSec := 30;  { N2 (auditoria F8): TimeoutSec<=0 desativa o timeout do ICS (OverbyteIcsSmtpProt) -> bloqueio indefinido do worker. }

  FReady := (FHost <> '') and (FFromAddress <> '') and (FToAddresses <> '');
end;

{ Chamado com FLock JÁ adquirido (ver Write) - só examina/limpa o buffer, sem
  I/O. Verifica os 3 gatilhos independentes contra o buffer (que já inclui a
  entrada que acabou de chegar). }
function TLoggerChannelEmail.ShouldFlushLocked: Boolean;
var
  I: Integer;
  LMinSeverity: Integer;
begin
  Result := False;
  if (FAggMaxCount > 0) and (FBuffer.Count >= FAggMaxCount) then
    Exit(True);
  if (FAggMaxIntervalSec > 0) and (SecondsBetween(Now, FBufferStartTime) >= FAggMaxIntervalSec) then
    Exit(True);
  if not SameText(FAggMinLevel, 'None') then
  begin
    LMinSeverity := LOG_LEVEL_SEVERITY[StrToLogLevel(FAggMinLevel, llCritical)];
    for I := 0 to FBuffer.Count - 1 do
      if LOG_LEVEL_SEVERITY[FBuffer[I].Level] >= LMinSeverity then
        Exit(True);
  end;
end;

procedure TLoggerChannelEmail.SplitAddresses(const ARaw: string; ADest: TStrings);
var
  LParts: TArray<string>;
  I: Integer;
  LAddr: string;
begin
  LParts := ARaw.Split([';']);
  for I := 0 to High(LParts) do
  begin
    LAddr := Trim(LParts[I]);
    if LAddr <> '' then
      ADest.Add(LAddr);
  end;
end;

function TLoggerChannelEmail.BuildSubject(const AEntries: TArray<TLoggerEntry>): string;
var
  I: Integer;
  LWorstLevel: TLogLevel;
  LWorstSeverity, LSeverity: Integer;
begin
  LWorstLevel := AEntries[0].Level;
  LWorstSeverity := LOG_LEVEL_SEVERITY[LWorstLevel];
  for I := 1 to High(AEntries) do
  begin
    LSeverity := LOG_LEVEL_SEVERITY[AEntries[I].Level];
    if LSeverity > LWorstSeverity then
    begin
      LWorstSeverity := LSeverity;
      LWorstLevel := AEntries[I].Level;
    end;
  end;
  if Length(AEntries) = 1 then
    Result := Format('%s %s: %s', [FSubjectPrefix, LogLevelToStr(LWorstLevel), Copy(AEntries[0].Message, 1, 80)])
  else
    Result := Format('%s %d log(s) - pior nivel: %s', [FSubjectPrefix, Length(AEntries), LogLevelToStr(LWorstLevel)]);
end;

procedure TLoggerChannelEmail.AppendBodyLines(const AEntries: TArray<TLoggerEntry>; ALines: TStrings);
var
  I: Integer;
begin
  for I := 0 to High(AEntries) do
  begin
    ALines.Add(Format('[%s] [%s] %s: %s',
      [FormatDateTime('yyyy-mm-dd hh:nn:ss', AEntries[I].Timestamp), LogLevelToStr(AEntries[I].Level),
       AEntries[I].Category, AEntries[I].Message]));
    if AEntries[I].ExceptionClass <> '' then
      ALines.Add(Format('  Exception: %s: %s', [AEntries[I].ExceptionClass, AEntries[I].ExceptionMessage]));
  end;
end;

function TLoggerChannelEmail.SendBatch(const AEntries: TArray<TLoggerEntry>): Boolean;
var
  LSmtp: TSslSmtpCli;
  LCtx: TSslContext;
  LTo, LCc, LBcc: TStringList;
  LFullFrom: string;
begin
  Result := False;
  if Length(AEntries) = 0 then
    Exit(True);
  try
    LSmtp := TSslSmtpCli.Create(nil);
    try
      { N1 (auditoria F8): sem um TSslContext atribuido, StartSslHandshake do ICS
        lanca ESslContextException (SMTPS/STARTTLS nem ligava); com ele + verify,
        o certificado do servidor passa a ser validado -> OpenSync devolve False
        se o cert for invalido (rejeita MITM), sem alterar a logica de sucesso. }
      LCtx := TSslContext.Create(LSmtp);  { owned pelo LSmtp - liberta com ele. }
      LCtx.SslVerifyPeer := True;
      if FTlsVerifyCert then
      begin
        if FTlsCAFile <> '' then
          LCtx.SslCAFile := FTlsCAFile
        else
          LCtx.UseSharedCAStore := True;  { bundle de CAs raiz embutido no exe (ICS RootCaCertsBundle.RES). }
        LSmtp.SslCertVerMethod := CertVerBundle;  { gate que REJEITA cert invalido. }
      end
      else
        LSmtp.SslCertVerMethod := CertVerNone;
      LSmtp.SslContext := LCtx;

      LSmtp.Host := FHost;
      LSmtp.Port := IntToStr(FPort);
      LSmtp.Timeout := FTimeoutSec;  { ICS sincrono: segundos, nao ms - mesmo achado do canal Http. }

      if SameText(FSslMode, 'Implicit') then
        LSmtp.SslType := smtpTlsImplicit
      else if SameText(FSslMode, 'Explicit') then
        LSmtp.SslType := smtpTlsExplicit
      else
        LSmtp.SslType := smtpTlsNone;

      if SameText(FAuthType, 'Login') and (FUsername <> '') then
      begin
        LSmtp.AuthType := smtpAuthLogin;
        LSmtp.Username := FUsername;
        LSmtp.Password := FPassword;
      end
      else
        LSmtp.AuthType := smtpAuthNone;

      if FFromName <> '' then
        LFullFrom := FFromName + ' <' + FFromAddress + '>'
      else
        LFullFrom := FFromAddress;
      LSmtp.FromName := LFullFrom;  { ICS extrai o endereco cru para MAIL FROM via ParseEmail. }

      LTo := TStringList.Create;
      LCc := TStringList.Create;
      LBcc := TStringList.Create;
      try
        SplitAddresses(FToAddresses, LTo);
        SplitAddresses(FCcAddresses, LCc);
        SplitAddresses(FBccAddresses, LBcc);

        LSmtp.RcptName.Clear;
        LSmtp.RcptName.AddStrings(LTo);
        LSmtp.RcptName.AddStrings(LCc);
        LSmtp.RcptName.AddStrings(LBcc);  { envelope - Bcc so aqui, nunca em header. }

        LSmtp.MailMessage.Clear;
        LSmtp.MailMessage.Add('From: ' + LFullFrom);
        LSmtp.MailMessage.Add('To: ' + LTo.CommaText.Replace('"', ''));
        if LCc.Count > 0 then
          LSmtp.MailMessage.Add('Cc: ' + LCc.CommaText.Replace('"', ''));
        LSmtp.MailMessage.Add('Subject: ' + BuildSubject(AEntries));
        LSmtp.MailMessage.Add('Content-Type: text/plain; charset=utf-8');
        LSmtp.MailMessage.Add('MIME-Version: 1.0');
        LSmtp.MailMessage.Add('');
        AppendBodyLines(AEntries, LSmtp.MailMessage);

        Result := LSmtp.OpenSync and LSmtp.MailSync;
        LSmtp.QuitSync;
      finally
        LTo.Free;
        LCc.Free;
        LBcc.Free;
      end;
    finally
      LSmtp.Free;
    end;
  except
    Result := False;  { erro de rede/SMTP/exceção do engine - nunca propaga. }
  end;
end;

{$ELSE}

procedure TLoggerChannelEmail.LoadConfig;
begin
  { USE_LOGGERS_EMAIL/USE_PARAMETERS em falta, OU fora do Windows/FPC (ICS
    Delphi-only nesta build, bug-712) - canal permanece inerte. }
  FEnabled := False;
  FReady := False;
end;

{$ENDIF LOGGERS_EML_CHANNEL_ACTIVE}

function TLoggerChannelEmail.Write(const AEntry: TLoggerEntry): Boolean;
{$IFDEF LOGGERS_EML_CHANNEL_ACTIVE}
var
  LEntries: TArray<TLoggerEntry>;
  LDoFlush: Boolean;
  LEntry: TLoggerEntry;
{$ENDIF}
begin
  Result := False;
  if not (FReady and FEnabled) then
    Exit;
{$IFDEF LOGGERS_EML_CHANNEL_ACTIVE}
  if not FAggEnabled then
  begin
    Result := SendBatch([AEntry]);
    Exit;
  end;

  LDoFlush := False;
  FLock.Acquire;
  try
    if FBuffer.Count = 0 then
      FBufferStartTime := Now;
    FBuffer.Add(AEntry);
    LDoFlush := ShouldFlushLocked;
    if LDoFlush then
    begin
      LEntries := FBuffer.ToArray;
      FBuffer.Clear;
    end;
  finally
    FLock.Release;
  end;

  if not LDoFlush then
    Exit(True);  { entrada aceite no lote, ainda nao devida para envio - nao e falha. }

  Result := SendBatch(LEntries);
  if not Result then
  begin
    { envio do lote falhou - devolve as entradas ao buffer, nao descarta
      (corrige o bug real do v2.3.0: FAggregatedLogs.Clear incondicional). }
    FLock.Acquire;
    try
      for LEntry in LEntries do
        FBuffer.Add(LEntry);
      if FBuffer.Count = Length(LEntries) then
        FBufferStartTime := Now;  { reinicia a janela de tempo só se o buffer estava vazio antes de devolver. }
    finally
      FLock.Release;
    end;
  end;
{$ENDIF}
end;

{$ENDIF USE_LOGGERS}

end.
