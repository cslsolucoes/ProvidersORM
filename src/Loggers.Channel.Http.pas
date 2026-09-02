{ =============================================================================
  Loggers.Channel.Http - Canal HTTP genérico (Delphi-only, via ICS)

  TLoggerChannelHttp: implementa ILoggerChannel fazendo POST JSON de cada
  entrada para um endpoint HTTP/HTTPS configurável, sobre o motor ICS
  (OverbyteIcsHttpProt.TSslHttpCli, síncrono via .Post — a mesma unit já
  validada por spike real na onda 8.4.0). Primeiro canal REAL sobre ICS,
  estabelece o padrão base partilhado pelos canais Email (8.4.4) e WebSocket
  (8.4.5). Delphi-only enquanto ICS v9.8 não compilar sob FPC 3.3.1
  (bug-712) — sob FPC o canal fica um shell inerte (mesmo padrão dos outros
  canais gated: nunca deixa de existir, só se degrada sozinho).

  Corpo da requisição = Commons.Loggers.Types.LoggerEntryToJSON (SSOT
  partilhada com o canal Json). Autenticação: None/Basic (Base64 calculado
  aqui, não delegado ao engine)/Bearer/ApiKey via header custom. Retry com
  backoff exponencial (intervalo base × 1, ×2, ×4, ...) para QUALQUER falha
  (rede/timeout/status não-2xx) — corrige um bug real do LoggersORM v2.3.0,
  cuja lista de status "retryável" não incluía por default o caso mais
  comum (falha de rede = status 0). Sem fallback para uma 2ª URL: o
  fan-out+fail-over do NÚCLEO (onda 8.1) já cobre esse papel ao nível do
  módulo — um fallback privado por-canal seria mecanismo paralelo.

  Absorção de lógica/semântica do LoggersORM v2.3.0 (Loggers.HTTPs.pas +
  Loggers.Engines.HTTP.*) e do QuickLogger (Quick.Logger.Provider.Rest.pas),
  NÃO cópia de ficheiros — ver Commons.Loggers.Consts.pas 1.4.0 para o
  detalhe completo das simplificações deliberadas.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.10.0
  FileVersion:    1.1.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           23/07/2026

  Changelog (file):
  - 1.1.0 (27/07/2026): F8 Onda 8.9 (hardening pos-auditoria) - N1: passa a VALIDAR o certificado TLS (TSslContext + SslCertVerMethod=CertVerBundle + UseSharedCAStore/SslCAFile), anti-MITM, corrige tambem a ESslContextException que impedia https; N6: cap de RetryMaxRetries (evita overflow do backoff). ModuleVersion do modulo 1.9.0->1.10.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.9.0 - F8 Onda 8.4.5 acrescenta o canal TLoggerChannelWebSocket (8o canal baseline, 3o real sobre ICS, resolve P2); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.9.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.8.0 - F8 Onda 8.4.4 acrescenta o canal TLoggerChannelEmail (7o canal baseline, 2o real sobre ICS); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.8.0.
  - 1.0.0 (23/07/2026): criação — FASE 8 Onda 8.4.3.
  ============================================================================= }

unit Loggers.Channel.Http;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../ORM.Defines.inc}

{$IF DEFINED(USE_LOGGERS_HTTP) AND DEFINED(USE_PARAMETERS) AND DEFINED(MSWINDOWS)}
  {$DEFINE LOGGERS_HTTP_CHANNEL_ACTIVE}
{$ENDIF}

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
  TLoggerChannelHttp = class(TInterfacedObject, ILoggerChannel)
  strict private
    FLock            : TCriticalSection;
    FEnabled         : Boolean;
    FReady           : Boolean;  { False se Url vazio OU ICS indisponivel (FPC) OU USE_LOGGERS_HTTP/USE_PARAMETERS em falta. }
    FUrl             : string;
    FTimeoutSec      : Integer;
    FAuthType        : string;
    FAuthUsername    : string;
    FAuthPassword    : string;
    FAuthToken       : string;
    FAuthApiKeyHeader: string;
    FAuthApiKeyValue : string;
    FRetryMaxRetries : Integer;
    FRetryIntervalMs : Integer;
    FTlsVerifyCert   : Boolean;  { N1 (auditoria F8): valida o certificado TLS do servidor HTTPS (anti-MITM). }
    FTlsCAFile       : string;   { N1: bundle CA custom em PEM (vazio = CAs raiz embutidos do ICS). }
    procedure LoadConfig;
{$IFDEF LOGGERS_HTTP_CHANNEL_ACTIVE}
    function AttemptPost(const AJsonBody: string): Boolean;
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
{$IFDEF LOGGERS_HTTP_CHANNEL_ACTIVE}
  {$IFDEF FPC}
  base64,                       // EncodeStringBase64 (Basic auth) - FPC RTL (cross-compiler port)
  {$ELSE}
  System.NetEncoding,           // TNetEncoding.Base64 (Basic auth) - Delphi RTL
  {$ENDIF}
  OverbyteIcsTypes,             // TCertVerMethod (CertVerBundle/CertVerNone) - N1
  OverbyteIcsSslBase,           // TSslContext (N1 - verificacao de certificado TLS)
  OverbyteIcsHttpProt,          // TSslHttpCli - motor unico ICS (spike validado na onda 8.4.0)
  Commons.Types,                 // TParameter
  Commons.Loggers.Consts,
  Parameters.Interfaces,
  Parameters,
{$ENDIF}
  Loggers.Version;  { mantem a unit no uses mesmo sem LOGGERS_HTTP_CHANNEL_ACTIVE, evita warning de uses vazio. }

constructor TLoggerChannelHttp.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FEnabled := False;
  FReady := False;
  LoadConfig;
end;

destructor TLoggerChannelHttp.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TLoggerChannelHttp.Name: string;
begin
  Result := 'Http';
end;

function TLoggerChannelHttp.Enabled: Boolean;
begin
  FLock.Acquire;
  try
    Result := FEnabled and FReady;
  finally
    FLock.Release;
  end;
end;

function TLoggerChannelHttp.Enabled(const AValue: Boolean): ILoggerChannel;
begin
  FLock.Acquire;
  try
    FEnabled := AValue;
  finally
    FLock.Release;
  end;
  Result := Self;
end;

function TLoggerChannelHttp.IsHealthy: Boolean;
begin
  Result := Enabled;
end;

{$IFDEF LOGGERS_HTTP_CHANNEL_ACTIVE}

procedure TLoggerChannelHttp.LoadConfig;
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
  LSource.Title(LOGGERS_TITULO_HTTP);

  FEnabled := SameText(Read(LOGGERS_HTTP_ENABLED, DEFAULT_LOGGERS_HTTP_ENABLED), 'True');
  FUrl := Read(LOGGERS_HTTP_URL, DEFAULT_LOGGERS_HTTP_URL);
  FTimeoutSec := StrToIntDef(Read(LOGGERS_HTTP_TIMEOUT_SEC, DEFAULT_LOGGERS_HTTP_TIMEOUT_SEC), 30);
  FAuthType := Read(LOGGERS_HTTP_AUTH_TYPE, DEFAULT_LOGGERS_HTTP_AUTH_TYPE);
  FAuthUsername := Read(LOGGERS_HTTP_AUTH_USERNAME, DEFAULT_LOGGERS_HTTP_AUTH_USERNAME);
  FAuthPassword := Read(LOGGERS_HTTP_AUTH_PASSWORD, DEFAULT_LOGGERS_HTTP_AUTH_PASSWORD);
  FAuthToken := Read(LOGGERS_HTTP_AUTH_TOKEN, DEFAULT_LOGGERS_HTTP_AUTH_TOKEN);
  FAuthApiKeyHeader := Read(LOGGERS_HTTP_AUTH_APIKEY_HEADER, DEFAULT_LOGGERS_HTTP_AUTH_APIKEY_HEADER);
  FAuthApiKeyValue := Read(LOGGERS_HTTP_AUTH_APIKEY_VALUE, DEFAULT_LOGGERS_HTTP_AUTH_APIKEY_VALUE);
  FRetryMaxRetries := StrToIntDef(Read(LOGGERS_HTTP_RETRY_MAX_RETRIES, DEFAULT_LOGGERS_HTTP_RETRY_MAX_RETRIES), 3);
  if FRetryMaxRetries < 0 then
    FRetryMaxRetries := 0;
  if FRetryMaxRetries > 10 then
    FRetryMaxRetries := 10;  { N6 (auditoria F8): cap - o backoff (1 shl LAttempt) explodiria (overflow/Sleep de dias) com valores altos. }
  FRetryIntervalMs := StrToIntDef(Read(LOGGERS_HTTP_RETRY_INTERVAL_MS, DEFAULT_LOGGERS_HTTP_RETRY_INTERVAL_MS), 1000);
  FTlsVerifyCert := SameText(Read(LOGGERS_HTTP_TLS_VERIFY_CERT, DEFAULT_LOGGERS_HTTP_TLS_VERIFY_CERT), 'True');
  FTlsCAFile := Read(LOGGERS_HTTP_TLS_CA_FILE, DEFAULT_LOGGERS_HTTP_TLS_CA_FILE);

  FReady := (FUrl <> '');  { canal inerte ate ter um endpoint configurado, independente de Enabled. }
end;

function TLoggerChannelHttp.AttemptPost(const AJsonBody: string): Boolean;
var
  LHttp: TSslHttpCli;
  LCtx: TSslContext;
  LBody: TStringStream;
begin
  Result := False;
  LHttp := TSslHttpCli.Create(nil);
  try
    { N1 (auditoria F8): sem um TSslContext atribuido, StartSslHandshake do ICS
      lanca ESslContextException (https:// nem ligava); com ele + verify, o
      certificado do servidor passa a ser validado -> RequestDoneError/StatusCode
      ja rejeitam se o cert for invalido (anti-MITM), sem alterar a logica. }
    LCtx := TSslContext.Create(LHttp);  { owned pelo LHttp - liberta com ele. }
    LCtx.SslVerifyPeer := True;
    if FTlsVerifyCert then
    begin
      if FTlsCAFile <> '' then
        LCtx.SslCAFile := FTlsCAFile
      else
        LCtx.UseSharedCAStore := True;  { bundle de CAs raiz embutido no exe (ICS RootCaCertsBundle.RES). }
      LHttp.SslCertVerMethod := CertVerBundle;  { gate que REJEITA cert invalido. }
    end
    else
      LHttp.SslCertVerMethod := CertVerNone;
    LHttp.SslContext := LCtx;

    LBody := TStringStream.Create(AJsonBody, TEncoding.UTF8);
    try
      LHttp.URL := FUrl;
      LHttp.Timeout := FTimeoutSec;  { ICS sincrono: segundos, nao ms - confirmado no vendor source (OverbyteIcsHttpProt.pas). }
      LHttp.SendStream := LBody;
      LHttp.ContentTypePost := 'application/json; charset=utf-8';
      LHttp.Agent := 'ProvidersORM-Loggers/3.0.0';

      if SameText(FAuthType, 'Basic') then
        LHttp.ExtraHeaders.Add('Authorization: Basic ' +
        {$IFDEF FPC}
          string(EncodeStringBase64(Utf8Encode(FAuthUsername + ':' + FAuthPassword))))  // FPC: base64 unit
        {$ELSE}
          TNetEncoding.Base64.EncodeBytesToString(TEncoding.UTF8.GetBytes(FAuthUsername + ':' + FAuthPassword)))
        {$ENDIF}
      else if SameText(FAuthType, 'Bearer') then
        LHttp.ExtraHeaders.Add('Authorization: Bearer ' + FAuthToken)
      else if SameText(FAuthType, 'ApiKey') and (FAuthApiKeyHeader <> '') then
        LHttp.ExtraHeaders.Add(FAuthApiKeyHeader + ': ' + FAuthApiKeyValue);

      try
        LHttp.Post;
        Result := (LHttp.RequestDoneError = 0) and (LHttp.StatusCode >= 200) and (LHttp.StatusCode < 300);
      except
        Result := False;  { erro de rede/DNS/exceção do engine - conta como falha, elegível a retry. }
      end;
    finally
      LBody.Free;
    end;
  finally
    LHttp.Free;
  end;
end;

{$ELSE}

procedure TLoggerChannelHttp.LoadConfig;
begin
  { USE_LOGGERS_HTTP/USE_PARAMETERS em falta, OU fora do Windows/FPC (ICS
    Delphi-only nesta build, bug-712) - canal permanece inerte. }
  FEnabled := False;
  FReady := False;
end;

{$ENDIF LOGGERS_HTTP_CHANNEL_ACTIVE}

function TLoggerChannelHttp.Write(const AEntry: TLoggerEntry): Boolean;
{$IFDEF LOGGERS_HTTP_CHANNEL_ACTIVE}
var
  LJsonBody: string;
  LAttempt: Integer;
  LOk: Boolean;
{$ENDIF}
begin
  Result := False;
  if not (FReady and FEnabled) then
    Exit;
{$IFDEF LOGGERS_HTTP_CHANNEL_ACTIVE}
  LJsonBody := LoggerEntryToJSON(AEntry);
  LAttempt := 0;
  repeat
    LOk := AttemptPost(LJsonBody);
    if LOk then
      Break;
    if LAttempt < FRetryMaxRetries then
      Sleep(FRetryIntervalMs * (1 shl LAttempt));  { backoff exponencial: x1, x2, x4, ... }
    Inc(LAttempt);
  until LAttempt > FRetryMaxRetries;
  Result := LOk;
{$ENDIF}
end;

{$ENDIF USE_LOGGERS}

end.
