{ =============================================================================
  Loggers.Channel.ElasticSearch - Canal Elasticsearch (Bulk Index API, via ICS)

  TLoggerChannelElasticSearch: implementa ILoggerChannel fazendo POST do
  corpo NDJSON (Bulk Index API do Elasticsearch) para
  <Scheme>://<Host>:<Port>/<Index>/_bulk, sobre o MESMO motor ICS síncrono
  já validado pelo canal Http (OverbyteIcsHttpProt.TSslHttpCli.Post) - não
  duplica o cliente HTTP/TLS, apenas especializa o corpo/endpoint/auth para o
  formato exigido pela Bulk API. Delphi-only enquanto ICS não estiver
  garantidamente FPC-ready fora desta build (mesmo gate MSWINDOWS dos canais
  Http/Redis, pós bug-872 - ICS já compila sob FPC 3.3.1 nesta bancada).

  Corpo do POST = 1 par de linhas NDJSON por entrada acumulada no buffer:
  a linha de ação (objeto JSON "index" vazio - deixa o Elasticsearch atribuir
  o _id) + Commons.Loggers.Types.LoggerEntryToJSON(entry) (SSOT partilhada com os
  canais Json/Http/Redis) - cada linha termina em LF, incluindo a última
  (exigência do formato NDJSON da Bulk API). BatchSize (default 1) controla
  quantas entradas vão por POST: BatchSize=1 reproduz o comportamento
  "1 Write = 1 POST" do canal Http; BatchSize>1 acumula em memória até
  atingir o limiar, só então envia. Se o POST falhar, o buffer NÃO é
  descartado (re-enviado na próxima escrita/flush) - mesma filosofia do
  canal Email (nunca perde entradas por falha transiente de rede).

  Autenticação: ApiKey (header `Authorization: ApiKey <valor>`) tem
  PRIORIDADE sobre Basic (Username/Password, Base64 calculado aqui, mesmo
  padrão do canal Http) quando ambos configurados. TLS (Scheme=https):
  TlsVerifyCert/TlsCAFile, mesmo mecanismo anti-MITM (TSslContext +
  SslCertVerMethod=CertVerBundle/UseSharedCAStore) do canal Http (N1,
  auditoria F8).

  Absorção: SEM equivalente direto no LoggersORM v2.3.0 nem no QuickLogger
  (nenhum dos dois tem provider Elasticsearch) - canal novo do v3, desenhado
  de raiz reaproveitando a máquina HTTP/TLS já madura do canal Http (não
  duplica cliente/engine, só o formato do payload e o endpoint).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.14.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           31/07/2026

  Changelog (file):
  - 1.0.0 (31/07/2026): criação - FASE 8 Onda 8.16 (canal ElasticSearch, 12º
    canal baseline, 5º canal REAL sobre ICS). POST NDJSON para
    <Scheme>://<Host>:<Port>/<Index>/_bulk (Bulk Index API), reusa
    TSslHttpCli/TSslContext (mesmo padrão do canal Http, não duplica o
    cliente). BatchSize agrupa N entradas por POST; buffer preservado em
    caso de falha (retry implícito na próxima escrita).
  ============================================================================= }

unit Loggers.Channel.ElasticSearch;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../ORM.Defines.inc}

{$IF DEFINED(USE_LOGGERS_ELASTICSEARCH) AND DEFINED(USE_PARAMETERS) AND DEFINED(MSWINDOWS)}
  {$DEFINE LOGGERS_ES_CHANNEL_ACTIVE}
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
  TLoggerChannelElasticSearch = class(TInterfacedObject, ILoggerChannel)
  strict private
    FLock          : TCriticalSection;
    FEnabled       : Boolean;
    FReady         : Boolean;  { False se Host vazio OU ICS indisponivel (FPC) OU USE_LOGGERS_ELASTICSEARCH/USE_PARAMETERS em falta. }
    FHost          : string;
    FPort          : Integer;
    FScheme        : string;   { 'http' ou 'https'. }
    FIndex         : string;
    FUsername      : string;
    FPassword      : string;
    FApiKey        : string;
    FTlsVerifyCert : Boolean;
    FTlsCAFile     : string;
    FBatchSize     : Integer;
    FBuffer        : array of TLoggerEntry;  { entradas acumuladas, ainda nao enviadas - so cresce/esvazia sob FLock. }
    procedure LoadConfig;
{$IFDEF LOGGERS_ES_CHANNEL_ACTIVE}
    procedure AppendToBufferLocked(const AEntry: TLoggerEntry);
    function BuildBulkBody: string;
    function AttemptBulkPost(const ABody: string): Boolean;
    function FlushBufferLocked: Boolean;  { chamado sempre com FLock ja adquirido. }
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
{$IFDEF LOGGERS_ES_CHANNEL_ACTIVE}
  {$IFDEF FPC}
  base64,                       // EncodeStringBase64 (Basic auth) - FPC RTL (cross-compiler port)
  {$ELSE}
  System.NetEncoding,           // TNetEncoding.Base64 (Basic auth) - Delphi RTL
  {$ENDIF}
  OverbyteIcsTypes,             // TCertVerMethod (CertVerBundle/CertVerNone)
  OverbyteIcsSslBase,           // TSslContext (verificacao de certificado TLS)
  OverbyteIcsHttpProt,          // TSslHttpCli - mesmo motor ICS unico do canal Http (nao duplicado)
  Commons.Types,                 // TParameter
  Commons.Loggers.Consts,
  Parameters.Interfaces,
  Parameters,
{$ENDIF}
  Loggers.Version;  { mantem a unit no uses mesmo sem LOGGERS_ES_CHANNEL_ACTIVE, evita warning de uses vazio. }

constructor TLoggerChannelElasticSearch.Create;
begin
  inherited Create;
{$IFDEF FPC}
  FLock := SyncObjs.TCriticalSection.Create;  { Windows.pp do FPC declara TCriticalSection (record WinAPI) que sombreia a classe SyncObjs quando Windows entra em scope na implementation - bug-659, mesmo fix dos canais EventLog/Console/Memory/Redis. }
{$ELSE}
  FLock := TCriticalSection.Create;
{$ENDIF}
  FEnabled := False;
  FReady := False;
  LoadConfig;
end;

destructor TLoggerChannelElasticSearch.Destroy;
begin
{$IFDEF LOGGERS_ES_CHANNEL_ACTIVE}
  { Flush best-effort do buffer pendente - nunca propaga (o destructor nao
    pode lancar), falha aqui so significa que essas entradas se perdem (nao
    ha para onde as re-inserir depois do canal deixar de existir). }
  FLock.Acquire;
  try
    try
      if Length(FBuffer) > 0 then
        FlushBufferLocked;
    except
      { nunca propaga a partir do destructor. }
    end;
  finally
    FLock.Release;
  end;
{$ENDIF}
  FLock.Free;
  inherited;
end;

function TLoggerChannelElasticSearch.Name: string;
begin
  Result := 'ElasticSearch';
end;

function TLoggerChannelElasticSearch.Enabled: Boolean;
begin
  FLock.Acquire;
  try
    Result := FEnabled and FReady;
  finally
    FLock.Release;
  end;
end;

function TLoggerChannelElasticSearch.Enabled(const AValue: Boolean): ILoggerChannel;
begin
  FLock.Acquire;
  try
    FEnabled := AValue;
  finally
    FLock.Release;
  end;
  Result := Self;
end;

function TLoggerChannelElasticSearch.IsHealthy: Boolean;
begin
  Result := Enabled;
end;

{$IFDEF LOGGERS_ES_CHANNEL_ACTIVE}

procedure TLoggerChannelElasticSearch.LoadConfig;
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
  LSource.Title(LOGGERS_TITULO_ELASTICSEARCH);

  FEnabled := SameText(Read(LOGGERS_ES_ENABLED, DEFAULT_LOGGERS_ES_ENABLED), 'True');
  FHost := Read(LOGGERS_ES_HOST, DEFAULT_LOGGERS_ES_HOST);
  FPort := StrToIntDef(Read(LOGGERS_ES_PORT, DEFAULT_LOGGERS_ES_PORT), 9200);
  FScheme := Read(LOGGERS_ES_SCHEME, DEFAULT_LOGGERS_ES_SCHEME);
  if (FScheme <> 'http') and (FScheme <> 'https') then
    FScheme := DEFAULT_LOGGERS_ES_SCHEME;
  FIndex := Read(LOGGERS_ES_INDEX, DEFAULT_LOGGERS_ES_INDEX);
  FUsername := Read(LOGGERS_ES_USERNAME, DEFAULT_LOGGERS_ES_USERNAME);
  FPassword := Read(LOGGERS_ES_PASSWORD, DEFAULT_LOGGERS_ES_PASSWORD);
  FApiKey := Read(LOGGERS_ES_API_KEY, DEFAULT_LOGGERS_ES_API_KEY);
  FTlsVerifyCert := SameText(Read(LOGGERS_ES_TLS_VERIFY_CERT, DEFAULT_LOGGERS_ES_TLS_VERIFY_CERT), 'True');
  FTlsCAFile := Read(LOGGERS_ES_TLS_CA_FILE, DEFAULT_LOGGERS_ES_TLS_CA_FILE);
  FBatchSize := StrToIntDef(Read(LOGGERS_ES_BATCH_SIZE, DEFAULT_LOGGERS_ES_BATCH_SIZE), 1);
  if FBatchSize <= 0 then
    FBatchSize := 1;  { config invalida/zero - fail-safe: nunca um limiar que NUNCA e atingido (buffer cresceria para sempre). }

  FReady := (FHost <> '');  { canal inerte ate ter um host configurado, independente de Enabled. }
end;

procedure TLoggerChannelElasticSearch.AppendToBufferLocked(const AEntry: TLoggerEntry);
begin
  SetLength(FBuffer, Length(FBuffer) + 1);
  FBuffer[High(FBuffer)] := AEntry;
end;

{ NDJSON: 2 linhas por entrada (acao + doc), cada uma terminada em LF - incl.
  a ultima (exigencia do parser bulk do Elasticsearch, que le linha a linha).
  A linha de acao (objeto JSON "index" vazio, sem opcoes) deixa o
  Elasticsearch atribuir o _id automaticamente (mais simples que gerir IDs
  proprios; o campo "id" do proprio TLoggerEntry, se necessario, ja vai
  dentro do documento via LoggerEntryToJSON). }
function TLoggerChannelElasticSearch.BuildBulkBody: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(FBuffer) do
    Result := Result + '{"index":{}}' + #10 + LoggerEntryToJSON(FBuffer[I]) + #10;
end;

function TLoggerChannelElasticSearch.AttemptBulkPost(const ABody: string): Boolean;
var
  LHttp: TSslHttpCli;
  LCtx: TSslContext;
  LSendBody, LRcvBody: TStringStream;
  LUrl, LRespText: string;
begin
  Result := False;
  LUrl := FScheme + '://' + FHost + ':' + IntToStr(FPort) + '/' + FIndex + '/_bulk';
  LHttp := TSslHttpCli.Create(nil);
  try
    if SameText(FScheme, 'https') then
    begin
      { Mesmo mecanismo anti-MITM do canal Http (N1, auditoria F8): sem
        TSslContext atribuido, StartSslHandshake do ICS lanca
        ESslContextException (https:// nem ligava). }
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
    end;

    LSendBody := TStringStream.Create(ABody, TEncoding.UTF8);
    LRcvBody := TStringStream.Create('', TEncoding.UTF8);
    try
      LHttp.URL := LUrl;
      LHttp.Timeout := 30;  { segundos - ICS THttpCli.Timeout sincrono e' em segundos, nao ms (mesmo achado do canal Http); nao configuravel nesta 1a versao do canal ElasticSearch. }
      LHttp.SendStream := LSendBody;
      LHttp.RcvdStream := LRcvBody;  { captura o corpo da resposta - o canal Http nao precisa disto (so' olha StatusCode), mas o Bulk API pode devolver 200 com "errors":true (falha PARCIAL por documento) - so a inspecao do corpo apanha esse caso. }
      LHttp.ContentTypePost := 'application/x-ndjson';
      LHttp.Agent := 'ProvidersORM-Loggers/3.0.0';

      if FApiKey <> '' then
        LHttp.ExtraHeaders.Add('Authorization: ApiKey ' + FApiKey)  { prioridade sobre Basic, mesmo com Username/Password tambem configurados. }
      else if FUsername <> '' then
        LHttp.ExtraHeaders.Add('Authorization: Basic ' +
        {$IFDEF FPC}
          string(EncodeStringBase64(Utf8Encode(FUsername + ':' + FPassword))));
        {$ELSE}
          TNetEncoding.Base64.EncodeBytesToString(TEncoding.UTF8.GetBytes(FUsername + ':' + FPassword)));
        {$ENDIF}

      try
        LHttp.Post;
        Result := (LHttp.RequestDoneError = 0) and (LHttp.StatusCode >= 200) and (LHttp.StatusCode < 300);
        if Result then
        begin
          LRespText := LRcvBody.DataString;
          if Pos('"errors":true', LRespText) > 0 then
            Result := False;  { bulk aceite pelo transporte (2xx) mas 1+ documento rejeitado pelo Elasticsearch. }
        end;
      except
        Result := False;  { erro de rede/DNS/exceção do engine - conta como falha. }
      end;
    finally
      LSendBody.Free;
      LRcvBody.Free;
    end;
  finally
    LHttp.Free;
  end;
end;

{ Chamado sempre com FLock ja adquirido pelo chamador (Write/Destroy). So
  esvazia o buffer se o POST tiver sucesso - em caso de falha as entradas
  ficam retidas para a proxima tentativa (mesma filosofia do canal Email:
  nunca descarta um lote so por causa de uma falha transiente de rede). }
function TLoggerChannelElasticSearch.FlushBufferLocked: Boolean;
var
  LBody: string;
begin
  if Length(FBuffer) = 0 then
    Exit(True);
  LBody := BuildBulkBody;
  Result := AttemptBulkPost(LBody);
  if Result then
    SetLength(FBuffer, 0);
end;

{$ELSE}

procedure TLoggerChannelElasticSearch.LoadConfig;
begin
  { USE_LOGGERS_ELASTICSEARCH/USE_PARAMETERS em falta, OU fora do
    Windows/FPC - canal permanece inerte. }
  FEnabled := False;
  FReady := False;
end;

{$ENDIF LOGGERS_ES_CHANNEL_ACTIVE}

function TLoggerChannelElasticSearch.Write(const AEntry: TLoggerEntry): Boolean;
begin
  Result := False;
  if not (FReady and FEnabled) then
    Exit;
{$IFDEF LOGGERS_ES_CHANNEL_ACTIVE}
  FLock.Acquire;
  try
    try
      AppendToBufferLocked(AEntry);
      if Length(FBuffer) >= FBatchSize then
        Result := FlushBufferLocked
      else
        Result := True;  { acumulada com sucesso, ainda nao enviada (BatchSize>1). }
    except
      Result := False;  { nunca propaga - fail-over do nucleo decide. }
    end;
  finally
    FLock.Release;
  end;
{$ENDIF}
end;

{$ENDIF USE_LOGGERS}

end.
