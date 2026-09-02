{ =============================================================================
  Loggers.Version - ModuleVersion do módulo Loggers

  Versão do módulo Loggers v3 (FASE 8). 1.0.0 estabeleceu a linha de base (API
  fluente, contratos); 1.1.0 foi a primeira versão REALMENTE validada pelo
  gate (1.0.0 tinha fail-over/bootstrap/dispatch assíncrono não funcionais,
  ver bug-653..658); 1.2.0 acrescenta os 2 canais baseline (.log + JSON);
  1.3.0 acrescenta o 3º canal baseline (Database, sobre pool); 1.4.0 remove a
  dependência do pool do canal Database (conexão própria, direta); 1.5.0
  acrescenta o 4º canal (EventLog, Windows Event Log — F8 Onda 8.4.1); 1.6.0
  acrescenta o 5º canal (CSV, reutiliza TLoggerChannelFileBase — F8 Onda 8.4.2);
  1.7.0 acrescenta o 6º canal (Http, 1º canal real sobre ICS, Delphi-only — F8
  Onda 8.4.3); 1.8.0 acrescenta o 7º canal (Email, com agregação N-entradas->
  1-email — F8 Onda 8.4.4); 1.9.0 acrescenta o 8º canal (WebSocket
  broadcast-only, resolve pendência P2 — F8 Onda 8.4.5); 1.10.0 é o hardening
  pós-auditoria (correção dos achados da auditoria estática — F8 Onda 8.9);
  1.11.0 acrescenta o 9º canal (Console, stdout via Writeln, canal universal
  — F8 Onda 8.4.6); 1.12.0 acrescenta o 10º canal (Memory, ring-buffer
  in-memory, canal universal — F8 Onda 8.4.7); 1.13.0 acrescenta o 11º canal
  (Redis, PUBLISH/LPUSH via RESP2 sobre ICS TWSocket, 4º canal REAL sobre
  ICS — F8 Onda 8.15); 1.14.0 acrescenta o 12º canal (ElasticSearch, Bulk
  Index API via ICS HTTP(S), 5º canal REAL sobre ICS — F8 Onda 8.16); 1.15.0
  acrescenta o 13º canal (SysLog, RFC5424 via ICS TWSocket — UDP default/TCP
  com framing LF —, 6º canal REAL sobre ICS — FASE 8); 1.16.0 acrescenta
  TNullLogger (SSOT do logger no-op — F8 Onda 8.6, retrofit SetLogger
  transversal a AD/Connections/PoolConnections).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.16.0
  FileVersion:    1.16.0
  Author:         Claiton de Souza Linhares
  Date:           08/08/2026

  Changelog (file):
  - 1.16.0 (08/08/2026): FASE 8 Onda 8.6 — novo Loggers.NullLogger.pas
    (TNullLogger, implementação no-op de ILogger, singleton via
    TNullLogger.New). Default de SetLogger nos módulos retrofit (AD/
    Connections/PoolConnections) quando nenhum ILogger real é injetado —
    permite ao código consumidor chamar FLogger.Info/Warning/... sempre
    directamente, sem guarda `if Assigned`. Não adiciona nem remove nenhum
    hook do núcleo (RegisterChannel/OnBeforeWrite/OnAfterWrite/OnLevelCheck
    continuam sem efeito prático nesta implementação — só o TLoggerImpl real
    faz fan-out). Sem impacto nos canais/dispatch existentes (aditivo puro).
  - 1.15.0 (01/08/2026): FASE 8 — canal TLoggerChannelSysLog, 13º canal
    baseline, 6º canal REAL sobre ICS (OverbyteIcsWSocket.TWSocket, mesmo
    padrão/motor do canal Redis — cliente fresco por-tentativa + bombeamento
    manual de mensagens). Mensagem RFC5424: PRIVAL=Facility*8+Severity
    (Severity mapeado dos 9 TLogLevel deste projecto para os 8 níveis
    RFC5424), TIMESTAMP RFC3339 com o OFFSET LOCAL REAL (Windows.
    GetTimeZoneInformation — não 'Z' falso, mesma honestidade de fuso já
    aplicada por LoggerEntryToJSON), HOSTNAME/APP-NAME/PROCID/MSGID
    sanitizados (PRINTUSASCII sem espaço), STRUCTURED-DATA sempre '-'.
    Transporte UDP (default, fire-and-forget — Connect de um socket
    SOCK_DGRAM no ICS não faz handshake de rede, confirmado no source) ou
    TCP (framing não-transparente por LF, RFC6587); nunca espera resposta do
    recetor em nenhum dos 2 protocolos. Delphi-only — inerte sob FPC/sem
    USE_LOGGERS_SYSLOG/sem Host configurado. Sem equivalente no LoggersORM
    v2.3.0/QuickLogger (nenhum dos 2 tem provider SysLog) — canal novo do v3.
  - 1.14.0 (31/07/2026): FASE 8 Onda 8.16 — canal TLoggerChannelElasticSearch,
    12º canal baseline, 5º canal REAL sobre ICS (OverbyteIcsHttpProt.
    TSslHttpCli, síncrono via .Post — MESMO motor do canal Http, não
    duplicado). POST NDJSON (linha de ação "index" vazia + doc via
    Commons.Loggers.Types.LoggerEntryToJSON, SSOT partilhada) para
    <Scheme>://<Host>:<Port>/<Index>/_bulk (Bulk Index API). BatchSize
    (default 1) agrupa N entradas por POST; buffer preservado em caso de
    falha (retry implícito na próxima escrita/flush, mesma filosofia do
    canal Email). ApiKey tem prioridade sobre Basic Username/Password.
    Delphi-only — inerte sob FPC/sem USE_LOGGERS_ELASTICSEARCH/sem Host
    configurado. Sem equivalente no LoggersORM v2.3.0/QuickLogger (nenhum
    dos 2 tem provider Elasticsearch) — canal novo do v3.
  - 1.13.0 (31/07/2026): FASE 8 Onda 8.15 — canal TLoggerChannelRedis, 11º
    canal baseline, 4º canal REAL sobre ICS (OverbyteIcsWSocket.TWSocket,
    cliente RESP2 sincrono por-tentativa — bombeamento de mensagens manual
    via ProcessMessage/Sleep, mesmo padrao ja' validado por test_websocket.dpr/
    TWSTestClientICS, ja' que TWSocket, ao contrario do THttpCli/TSslSmtpCli
    dos canais Http/Email, nao tem um metodo sincrono pronto). Delphi-only —
    inerte sob FPC/sem USE_LOGGERS_REDIS/sem Host configurado. AUTH (se
    Password<>'') + SELECT (se DbIndex<>0) + PUBLISH ou LPUSH (Mode), tudo na
    MESMA ligacao TCP sequencial. Payload via Commons.Loggers.Types.
    LoggerEntryToJSON (SSOT partilhada com Http/Json). Sem equivalente no
    LoggersORM v2.3.0/QuickLogger (nenhum dos 2 tem provider Redis) — canal
    novo do v3. TLS fora do escopo desta 1a versao.
  - 1.12.0 (31/07/2026): FASE 8 Onda 8.4.7 — canal TLoggerChannelMemory, 10º
    canal baseline (ring-buffer retido puramente em memória — sem I/O de
    disco/rede nas escritas). Sem equivalente direto no LoggersORM v2.3.0/
    QuickLogger (novo canal do v3). Universal (sem restrição de plataforma,
    mesmo padrão ELSE-com-defaults do Console/Json/CSV). Guarda as últimas N
    entradas (config Capacity, default 1000) num array circular (O(1) por
    escrita/eviccão); 3 métodos concretos de leitura fora do contrato
    ILoggerChannel (Snapshot/Count/Clear), só acessíveis por quem detém a
    referência concreta TLoggerChannelMemory. Auto-registado em
    TLoggerImpl.Create, mesma regra dos outros 5 canais locais.
  - 1.11.0 (31/07/2026): FASE 8 Onda 8.4.6 — canal TLoggerChannelConsole, 9º
    canal baseline (stdout via Writeln). Sem equivalente direto no LoggersORM
    v2.3.0/QuickLogger (novo canal do v3). Universal (sem restrição de
    plataforma como o EventLog) — mesmo sem USE_LOGGERS_CONSOLE/
    USE_PARAMETERS, continua pronto a escrever com defaults fixos (padrão
    ELSE-com-defaults do Json/CSV). Reusa o template do grupo 'Loggers.Format'
    via a nova função partilhada Commons.Loggers.Types.FormatLoggerEntryTemplate
    (extraída de Loggers.Channel.TextFile.FormatEntry — SSOT única para os 2
    canais). Cor por nível opcional (UseColors, Windows
    SetConsoleTextAttribute) — mapeamento fixo: Info=cinza claro/normal,
    Success/Done=verde, Warning=amarelo, Error/Critical/Exception=vermelho,
    Debug/Trace=cinza escuro. Auto-registado em TLoggerImpl.Create, mesma
    regra dos outros 4 canais locais.
  - (rename 27/07/2026) Familia de canais renomeada sob o infixo `.Channel.` (owner):
    Loggers.<Canal>.pas -> Loggers.Channel.<Canal>.pas (8 canais - CSV/Database/Email/
    EventLog/Http/Json/TextFile/WebSocket) + Loggers.FileChannelBase -> Loggers.Channel.FileBase.
    Estrategia C (skill governance-refactoring): nomes de UNIT internos (NAO a API publica
    TProviders), zero consumidores externos, v3 B-freeze. 69 refs de `uses`/`unit` atualizadas
    (ProvidersV3.dpr/.lpr, Loggers.pas, os 3 canais de ficheiro, 8 smokes) por script Python com
    regex que PROTEGE as strings de config 'Loggers.<Grupo>' (titulos de grupo de parametros,
    inalterados - verificado 0 corrupcoes). ModuleVersion inalterado (renomeacao e' organizacao,
    nao funcionalidade). Gate: 4 alvos EXIT=0 + 7 smokes verdes dcc32/dcc64 + fpc32 channels/csv/core.
  - 1.10.0 (27/07/2026): FASE 8 Onda 8.9 (hardening pos-auditoria) - correcao dos
    achados da auditoria estatica do modulo (report
    providersorm-v3-f8-loggers-auditoria_v1.0.md; 2 criticos + 6 relevantes +
    higiene). NUCLEO: C1 - o dispatch deixa de segurar o FLock global durante o
    Write() dos canais (copy-under-lock + AtomicInc/Dec de FPending) -> um canal
    lento ja nao bloqueia toda a app; C2 - canal auto-desativado recupera apos
    cooldown (LOGGERS_CHANNEL_RECOVERY_MS); C3 - excecao de canal ganha
    diagnostico (OutputDebugString, Delphi-Windows). REDE: N1 - Http/Email
    passam a VALIDAR o certificado TLS (TSslContext + CertVerBundle +
    UseSharedCAStore/CAFile; corrige tambem ESslContextException que impedia
    HTTPS/SMTPS), anti-MITM; N2 - clamp do timeout SMTP; N3/N4/N5 - WebSocket
    reporta falha real do servidor, handshake com try/except, fila com teto.
    FICHEIRO: F1/F2 - sanitizacao do nome; D1 - canal Database serializa o Write.
    Limpeza C7/X1/X2/X3 + comentarios F4/F5. 5 chaves de config novas. Gate: 4
    alvos EXIT=0 (ProvidersV3+ParametersV3) + 7 smokes Loggers verdes em dcc32.
  - 1.9.0 (23/07/2026): FASE 8 Onda 8.4.5 — canal TLoggerChannelWebSocket, 8º
    canal baseline, 3º canal REAL sobre ICS (OverbyteIcsWSocketS.
    TWSocketServer/TWSocketClient). Delphi-only (bug-712) — inerte sob
    FPC/sem Enabled=True configurado (default False, deliberado - abrir uma
    porta de rede é um efeito colateral que não deve acontecer
    silenciosamente). Resolve a pendência P2 ("WebSocket é requisito real?").
    Diferente dos outros 2 canais ICS (pedido-resposta): mantém um SERVIDOR
    persistente que arranca no Create e faz broadcast de cada entrada
    (JSON, via LoggerEntryToJSON) a todos os clientes WS ligados — nunca lê
    nada dos clientes (broadcast-only). Absorção de lógica/semântica do
    LoggersORM v2.3.0 (Loggers.WebSocket.pas +
    Loggers.Engines.WebSocket.Indy.pas — o "órfão" sem Factory/Interfaces,
    mas com a ÚNICA lógica real do módulo): handshake RFC6455 (SHA1+Base64)
    e construção do frame de texto absorvidos fielmente (lógica já simples
    e correta); só o motor de transporte muda de Indy (TIdTCPServer) para
    ICS (TWSocketServer), único engine de rede do v3.
  - 1.8.0 (23/07/2026): FASE 8 Onda 8.4.4 — canal TLoggerChannelEmail, 7º
    canal baseline, 2º canal REAL sobre ICS (OverbyteIcsSmtpProt.TSslSmtpCli,
    síncrono via OpenSync/MailSync/QuitSync). Delphi-only (bug-712) — inerte
    sob FPC/sem Host+FromAddress+ToAddresses configurados. AGREGAÇÃO
    (N-entradas->1-email, absorvida do LoggersORM v2.3.0
    Loggers.EMails.pas): 3 gatilhos independentes (contagem/tempo/nível),
    cada um desativável individualmente — mais expressivo que o enum de
    estratégia mutuamente exclusivo do original. Corrige bug real do v2.3.0
    (buffer agregado descartado incondicionalmente se o envio falhasse — no
    v3 as entradas voltam para o buffer). AuthType só None/Login
    (Plain/CramMD5/NTLM/OAuth2 do v2.3.0 nunca implementados, dead code).
    Corpo sempre plain-text (v2.3.0 tinha modo HTML sem escaping das
    mensagens — bug real, não migrado). Nova
    Commons.Loggers.Types.StrToLogLevel (SSOT extraída de
    Loggers.pas.BootstrapParameters) usada pelo gatilho de agregação por
    nível.
  - 1.7.0 (23/07/2026): FASE 8 Onda 8.4.3 — canal TLoggerChannelHttp, 6º canal
    baseline, 1º canal REAL sobre ICS (OverbyteIcsHttpProt.TSslHttpCli,
    síncrono via .Post). Delphi-only enquanto ICS v9.8 não compilar sob FPC
    3.3.1 (bug-712) — inerte sob FPC/sem Url configurado. Absorção de
    lógica/semântica do LoggersORM v2.3.0 (Loggers.HTTPs.*+Engines.HTTP.*) +
    QuickLogger (Quick.Logger.Provider.Rest), simplificada: Url único (sem
    BaseURL+Endpoint), Method fixo POST, ContentType fixo JSON (via nova
    Commons.Loggers.Types.LoggerEntryToJSON, SSOT partilhada com o canal
    Json), retry com backoff exponencial para QUALQUER falha (corrige bug
    real do v2.3.0 — retry não cobria falha de rede por default), sem
    fallback privado por-canal (o fan-out+fail-over do núcleo já cobre esse
    papel), motor único ICS substitui o dual Indy/Synapse do v2.3.0
    (eliminando divergências reais de comportamento entre os 2 engines —
    Basic Auth quebrado no Synapse, sucesso definido diferente em cada um).
  - 1.6.0 (23/07/2026): FASE 8 Onda 8.4.2 — canal TLoggerChannelCSV, 5º canal
    baseline, reutiliza TLoggerChannelFileBase (mesma mecânica de rotação por
    tamanho/data + retenção do TextFile/Json — sem reimplementar I/O de
    ficheiro). Absorção de lógica/semântica do LoggersORM v2.3.0
    (Loggers.CSV.*), simplificada para o padrão v3: delimitador único por
    string (não enum+CustomDelimiter), escape RFC4180 fixo (double-quote — a
    única "recomendada" no próprio v2.3.0), colunas fixas espelhando
    TLoggerEntry (não 9 flags Include* configuráveis em runtime — no v2.3.0
    isso podia invalidar silenciosamente linhas já escritas com outro layout
    de colunas). Cabeçalho opcional, escrito automaticamente no início de
    CADA ficheiro novo (incl. rodados), via novo hook `CurrentFilePath` em
    `TLoggerChannelFileBase` (aditivo, TextFile/Json inalterados). Auto-
    registado em TLoggerImpl.Create, mesma regra dos outros 4 baseline.
  - 1.5.0 (23/07/2026): FASE 8 Onda 8.4.1 — canal TLoggerChannelEventLog
    (Windows Event Log via RegisterEventSource/ReportEvent/DeregisterEventSource
    STANDARD, sem declaração externa manual — corrige o bug ANSI/Unicode do
    LoggersORM v2.3.0, que misturava entry points '...A' com PChar Unicode).
    Absorção de lógica/semântica do v2.3.0 (Loggers.EventLogs.*), simplificada
    para o padrão de configuração v3 (4 chaves via IParameters, não a API
    fluente de 20+ setters do v2.3.0). Registo automático da fonte no registry
    (HKLM) se AutoCreateSource=True; falha degrada silenciosamente (mesma
    filosofia dos outros canais). Auto-registado em TLoggerImpl.Create, mesma
    regra dos outros 3 baseline.
  - 1.4.0 (22/07/2026): Auditoria adversarial F8 8.1→8.3 (owner: "revise o F8
    arquivo a arquivo onda a onda") + 3 gaps reais corrigidos (bug-688/692/693)
    + decisão de arquitectura do owner ("o Loggers via consumir sem pool direto
    o Connections"): TLoggerChannelDatabase deixa de usar IPoolConnections/
    TPoolBroker — passa a construir e possuir a sua própria IConnection direta
    (mesmo padrão de Parameters.Database.pas), eliminando de raiz a race
    condition do antigo var global GPool (achado crítico da auditoria, check-
    then-set sem lock). LOGGERS_DB_AUTO_CREATE_TABLE honrado (antes ignorado).
    PoolConnections.pas corrigido em paralelo (bug-692, ServerName/
    DllDownloadUrl não propagados no caminho pooled — afeta outros consumidores
    do pool, não só Loggers). Gate: 4 alvos EXIT=0 + smoke_loggers_core 18/18 +
    smoke_loggers_channels 23/23 + smoke_loggers_db 12/12 + smoke_poolconnections
    32/32 + smoke_pool_stress 13/13 + smoke_parameters_db 93/93, zero regressão.
  - 1.3.0 (22/07/2026): FASE 8 Onda 8.3 — canal baseline TLoggerChannelDatabase
    (sobre IPoolConnections, perfil 'loggers', tabela logs via
    ISchemaDefinition/TSynchronize); bootstrap idempotente extraído para
    Loggers.Connections.TLoggersConnectionResolver.EnsureParametersSeeded
    (partilhado com o núcleo, resolve o bug do canal Database instanciado
    antes do bootstrap do núcleo não encontrar o perfil de conexão semeado).
  - 1.2.0 (22/07/2026): FASE 8 Onda 8.2 — canais baseline TLoggerChannelTextFile
    (.log com template) e TLoggerChannelJson (NDJSON), sobre base partilhada
    TLoggerChannelFileBase (rotação por tamanho/data, retenção); auto-
    registados em TLoggerImpl.Create.
  - 1.1.0 (22/07/2026): fan-out+fail-over reais, bootstrap idempotente real via
    IParameters, dispatch assíncrono real via TLoggerWorkerThread, GUID de
    ILoggerChannel corrigido (colidia com IConnection) — ver bug-653..658.
  - 1.0.0 (21/07/2026): versão inicial do módulo Loggers v3 (FASE 8 Onda 8.1).
  ============================================================================= }

unit Loggers.Version;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

const
  LOGGERS_VERSION_MAJOR = 1;
  LOGGERS_VERSION_MINOR = 16;
  LOGGERS_VERSION_PATCH = 0;
  LOGGERS_VERSION       = '1.16.0';
  LOGGERS_VERSION_DATE  = '08/08/2026';

  { Forma legível para logs / About box. }
  LOGGERS_VERSION_FULL  = 'Loggers ' + LOGGERS_VERSION +
                          ' (' + LOGGERS_VERSION_DATE + ')';

implementation

end.
