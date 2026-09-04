{ =============================================================================
  Commons.Loggers.Consts - Constantes internas do módulo Loggers (v3)

  126 chaves de parâmetros em 16 grupos (Loggers, loggers, Loggers.Database,
  Loggers.TextFile, Loggers.Json, Loggers.Format, Loggers.EventLog,
  Loggers.CSV, Loggers.Http, Loggers.Email, Loggers.WebSocket,
  Loggers.Console, Loggers.Memory, Loggers.Redis, Loggers.ElasticSearch,
  Loggers.SysLog) + defaults de comportamento. Regra: dados puros, não
  lógica. Consumido pelo bootstrap idempotente (seed dos parâmetros na
  tabela `parameters` via IParameters).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.15.0
  FileVersion:    1.12.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           01/08/2026

  Changelog (file):
  - 1.12.0 (01/08/2026): FASE 8 (canal SysLog RFC5424) - novo grupo
    'Loggers.SysLog' (7 chaves: Enabled/Host/Port/Protocol/Facility/AppName/
    Hostname) + LOGGERS_TITULO_SYSLOG. Canal de rede mais simples do modulo -
    UM datagrama (UDP, default) ou pacote com framing LF (TCP) por Write,
    sobre o MESMO motor ICS TWSocket ja' usado pelo canal Redis. Sem chave de
    TimeoutSec propria (timeout fixo interno, 10s - UDP nao faz handshake de
    rede, TCP so' precisa do 3-way, nao ha troca subsequente que justifique
    tornar isto configuravel). LOGGERS_PARAM_DEFAULTS 119->126 linhas (16
    grupos). ModuleVersion do modulo 1.14.0->1.15.0.
  - 1.11.0 (31/07/2026): F8 Onda 8.16 (canal ElasticSearch) - novo grupo
    'Loggers.ElasticSearch' (11 chaves: Enabled/Host/Port/Scheme/Index/
    Username/Password/ApiKey/TlsVerifyCert/TlsCAFile/BatchSize) +
    LOGGERS_TITULO_ELASTICSEARCH. Canal HTTP(S) especializado (POST NDJSON
    para <Scheme>://<Host>:<Port>/<Index>/_bulk, Bulk Index API do
    Elasticsearch) - reusa a mesma maquina ICS (TSslHttpCli+TSslContext) ja'
    validada pelo canal Http, sem duplicar o cliente. ApiKey tem prioridade
    sobre Basic Username/Password quando ambos configurados. BatchSize
    (default 1) agrupa N entradas por POST _bulk - default 1 = comportamento
    "1 Write = 1 POST" identico ao canal Http. LOGGERS_PARAM_DEFAULTS
    108->119 linhas (15 grupos). ModuleVersion do modulo 1.13.0->1.14.0.
  - 1.10.0 (31/07/2026): F8 Onda 8.15 (canal Redis) - novo grupo
    'Loggers.Redis' (8 chaves: Enabled/Host/Port/Password/DbIndex/Mode/
    ChannelOrKey/TimeoutSec) + LOGGERS_TITULO_REDIS. Protocolo RESP2 sobre
    TCP cru (ICS TWSocket, sincrono por-tentativa) - PUBLISH (Mode=Publish,
    pub/sub fire-and-forget) ou LPUSH (Mode=List, persiste na lista). Sem
    chaves de TLS nesta 1a versao (so' TCP simples - ver plano F8 Redis §6.1
    para o desenho completo, incl. as 3 chaves TLS reservadas para uma onda
    futura). LOGGERS_PARAM_DEFAULTS 100->108 linhas (14 grupos). ModuleVersion
    do modulo 1.12.0->1.13.0.
  - 1.9.0 (31/07/2026): F8 Onda 8.4.7 (canal Memory) - novo grupo
    'Loggers.Memory' (2 chaves: Enabled/Capacity) + LOGGERS_TITULO_MEMORY.
    Canal universal (ring-buffer puramente em memoria), sem chaves de
    formatacao proprias (nao serializa - Snapshot devolve TLoggerEntry
    diretamente). Sem equivalente direto no LoggersORM v2.3.0/QuickLogger
    (novo canal baseline do v3). LOGGERS_PARAM_DEFAULTS 98->100 linhas (13
    grupos). ModuleVersion do modulo 1.11.0->1.12.0.
  - 1.8.0 (31/07/2026): F8 Onda 8.4.6 (canal Console) - novo grupo
    'Loggers.Console' (2 chaves: Enabled/UseColors) + LOGGERS_TITULO_CONSOLE.
    Canal universal (stdout via Writeln), sem chaves de formatacao proprias -
    reusa o MESMO template do grupo 'Loggers.Format' (mesmas chaves do canal
    TextFile). Sem equivalente direto no LoggersORM v2.3.0/QuickLogger (novo
    canal baseline do v3). LOGGERS_PARAM_DEFAULTS 96->98 linhas (12 grupos).
    ModuleVersion do modulo 1.10.0->1.11.0.
  - 1.7.0 (27/07/2026): F8 Onda 8.9 (hardening pos-auditoria) - + campo
    ModuleVersion no cabecalho (fix X1 da auditoria: a unit estava fora do
    mecanismo de sync de versao do modulo) + 5 chaves novas:
    LOGGERS_CHANNEL_RECOVERY_MS (grupo Loggers, cooldown de reativacao de
    canal auto-desativado - achado C2) + LOGGERS_HTTP_TLS_VERIFY_CERT/_CA_FILE
    (grupo Http) + LOGGERS_EML_TLS_VERIFY_CERT/_CA_FILE (grupo Email) para a
    validacao de certificado TLS dos canais outbound (achado N1, anti-MITM).
    LOGGERS_PARAM_DEFAULTS 91->96 linhas (11 grupos: core 11->12, Http 11->13,
    Email 18->20). Comentario "49 linhas (7 grupos)" corrigido para "96 linhas
    (11 grupos)" (fix X2, desatualizado desde a onda 8.4.1). ModuleVersion do
    modulo 1.9.0->1.10.0.
  - 1.6.0 (23/07/2026): F8 Onda 8.4.5 (canal WebSocket broadcast-only,
    Delphi-only via ICS) - novo grupo 'Loggers.WebSocket' (4 chaves: Enabled/
    Port/BindAddr/MaxClients) + LOGGERS_TITULO_WEBSOCKET. Absorção de
    lógica/semântica do LoggersORM v2.3.0 (Loggers.WebSocket.pas +
    Loggers.Engines.WebSocket.Indy.pas - o motor real, "órfão" no v2.3.0 sem
    Factory/Interfaces): servidor WS broadcast-only (nunca lê frames dos
    clientes, só envia), resolve a pendência P2. Motor de transporte
    substituído de Indy (TIdTCPServer) para ICS (TWSocketServer/
    TWSocketClient), único engine de rede do projeto (owner: "neste caso
    agora somente um engine, diferente do 2.3.0"); handshake RFC6455
    (SHA1+Base64) e construção de frame absorvidos fielmente do v2.3.0 (lógica
    já correta e simples, sem motivo para reescrever) - fonte de escuta muda
    de engine, não a lógica do protocolo. Enabled=False por default
    (deliberado - abrir uma porta de rede é um efeito colateral que não deve
    acontecer silenciosamente); BindAddr=127.0.0.1 por default (mais seguro
    que 0.0.0.0). LOGGERS_PARAM_DEFAULTS 87->91 linhas (11 grupos).
  - 1.5.0 (23/07/2026): F8 Onda 8.4.4 (canal Email genérico, Delphi-only via
    ICS) - novo grupo 'Loggers.Email' (18 chaves: Enabled/Host/Port/SslMode/
    Username/Password/AuthType/TimeoutSec/FromAddress/FromName/ToAddresses/
    CcAddresses/BccAddresses/SubjectPrefix/AggregationEnabled/
    AggregationMaxCount/AggregationMaxIntervalSec/AggregationMinLevel) +
    LOGGERS_TITULO_EMAIL. Absorção de lógica/semântica do LoggersORM v2.3.0
    (Loggers.EMails.*+Engines.Email.*) - a AGREGAÇÃO (N entradas -> 1 email)
    é o valor real deste canal (QuickLogger não tem equivalente, cada
    entrada vira 1 email lá); simplificada: 3 gatilhos combináveis
    (contagem/tempo/nível) em vez de um enum de estratégia mutuamente
    exclusivo do v2.3.0 - MaxCount=0/MaxIntervalSec=0/MinLevel='None'
    desativam cada gatilho independentemente, mais expressivo que o
    original. AuthType só None/Login (Plain/CramMD5/NTLM/OAuth2 do v2.3.0
    nunca foram implementados, dead code). SslMode None/Implicit/Explicit
    (mesmos 3 modos reais do v2.3.0, sem os campos UseSSL/UseTLS deprecated
    que os engines nem liam). Sem TemplateFormat HTML (v2.3.0 não escapava
    as mensagens no HTML - bug real; corpo plain-text sempre). Corrige bug
    real do v2.3.0: buffer agregado NÃO é descartado se o envio falhar
    (re-inserido para a próxima tentativa). LOGGERS_PARAM_DEFAULTS 69->87
    linhas (10 grupos).
  - 1.4.0 (23/07/2026): F8 Onda 8.4.3 (canal HTTP genérico, Delphi-only via
    ICS) - novo grupo 'Loggers.Http' (11 chaves: Enabled/Url/TimeoutSec/
    AuthType/AuthUsername/AuthPassword/AuthToken/AuthApiKeyHeader/
    AuthApiKeyValue/RetryMaxRetries/RetryIntervalMs) + LOGGERS_TITULO_HTTP.
    Absorção de lógica/semântica do LoggersORM v2.3.0 (Loggers.HTTPs.* +
    Loggers.Engines.HTTP.*) e do QuickLogger (Quick.Logger.Provider.Rest),
    simplificada: (a) BaseURL+Endpoint fundidos num único Url; (b) Method
    fixo POST (log sink nunca precisa de GET/PUT/PATCH); (c) ContentType
    fixo JSON via Commons.Loggers.Types.LoggerEntryToJSON (v2.3.0 suportava
    XML/FormData/Text SEM qualquer escaping - bug real, removido); (d)
    estratégia de retry fixa em backoff exponencial (v2.3.0 tinha 4
    estratégias configuráveis, delimitador de valor real); (e) condição de
    retry CORRIGIDA para qualquer falha (rede/timeout/status não-2xx) - o
    v2.3.0 só fazia retry para uma lista de status HTTP configurável que por
    default NÃO incluía falha de rede (status 0), o caso mais comum, bug
    real identificado na análise; (f) fallback para uma 2ª URL NÃO migrado -
    o fan-out+fail-over do NÚCLEO (TLoggerImpl, onda 8.1) já cobre esse
    papel ao nível do módulo (outros canais continuam a receber se o HTTP
    cair), um fallback privado por-canal seria mecanismo paralelo; (g)
    OAuth2/Digest do v2.3.0 (declarados no enum mas nunca implementados) não
    migrados - nada para "absorver", são dead code; (h) motor dual
    Indy/Synapse substituído pelo motor único ICS (THttpCli), eliminando as
    divergências reais de comportamento entre os 2 engines do v2.3.0 (Basic
    Auth quebrado no Synapse por falta de Base64; sucesso definido como
    "qualquer resposta completa" no Synapse vs "só 2xx" no Indy) - Basic
    Auth agora codificado em Base64 pelo PRÓPRIO canal (System.NetEncoding),
    não delegado ao engine, resolvendo a divergência na raiz.
  - 1.3.0 (23/07/2026): F8 Onda 8.4.2 (canal CSV) - novo grupo 'Loggers.CSV'
    (9 chaves: Enabled/FolderPath/FileNamePattern/FileSuffix/RotationBySizeMB/
    RotationByDate/MaxFilesToKeep/Delimiter/IncludeHeaders) + LOGGERS_TITULO_CSV.
    Simplificação deliberada vs LoggersORM v2.3.0 (Loggers.CSV.Types.TLogCSVConfig):
    (a) delimitador único configurável por string (não enum TLogCSVDelimiter +
    CustomDelimiter separado - 1 chave cobre virgula/ponto-e-virgula/tab/pipe/
    custom); (b) estratégia de escape fixa em RFC4180 double-quote (a única
    "recomendada" no próprio comentário do v2.3.0 - lcesBackslash/lcesNone
    removidas, sem consumidor real); (c) conjunto de colunas FIXO (Timestamp/
    Level/Category/Message/AppName/Host/ThreadId/ExceptionClass/
    ExceptionMessage/Tag, espelha TLoggerEntry) em vez dos 9 flags Include* do
    v2.3.0 configuráveis em runtime - motivo: no v2.3.0 mudar um IncludeXxx a
    meio da vida do ficheiro invalidava silenciosamente as linhas já escritas
    com outro nº de colunas (CSV corrompido sem erro), fixar o layout aplica a
    regra do owner "faça o merge se possível, senão prevalece a melhor
    lógica/semântica" a favor da correção. LOGGERS_PARAM_DEFAULTS 49->58 linhas
    (8 grupos).
  - 1.2.0 (23/07/2026): F8 Onda 8.4.1 (canal EventLog) - novo grupo
    'Loggers.EventLog' (4 chaves: Enabled/SourceName/LogName/AutoCreateSource)
    + LOGGERS_TITULO_EVENTLOG. Absorção de lógica/semântica do
    LoggersORM v2.3.0 (Loggers.EventLogs.*) simplificada para o padrão v3
    (config via IParameters, não a API fluente de 20+ setters do v2.3.0) -
    mapeamento de nível para tipo/EventID/categoria fica automático/derivado
    (Ord(Level)) em vez de 15 chaves configuráveis por nível. LOGGERS_PARAM_
    DEFAULTS 45->49 linhas (7 grupos).
  - 1.1.2 (22/07/2026): Finalização da onda 8.3, item 3 (owner: "resolva todos
    e documente nos planos") - REMOVIDO LOGGERS_DB_BATCH_INSERT_SIZE (chave
    'BatchInsertSize') + DEFAULT_LOGGERS_DB_BATCH_SIZE + a linha seeded
    correspondente: estava configurável mas nunca implementado (Write insere
    sempre 1 linha de cada vez) - implementar batching real exigiria redesenhar
    o contrato síncrono de Write() por-entrada (cada chamada tem de reportar
    sucesso/falha de UMA entrada para o fail-over de Loggers.pas decidir; um
    buffer teria de responder por N entradas ainda não persistidas), fora do
    escopo de finalizar a onda 8.3 - mais correto remover a config enganosa do
    que a deixar como decoração. LOGGERS_PARAM_DEFAULTS 46->45 linhas (grupo
    'Loggers.Database' 6->5). Comentário de LOGGERS_DB_CONNECTION_PROFILE
    corrigido (já não menciona GetFromPool - o canal usa IConnection própria
    desde bug-697). Achado da auditoria adversarial F8 8.1-8.3, plano de
    finalização (f8-loggers changelog 2.8.7) - bug-699.
  - 1.1.1 (22/07/2026): REMOVIDO residuo da tentativa DllNames revertida (F8
    Onda 8.3, seam 400017) que o revert em Commons.Types.pas/Commons.Consts.pas/
    Parameters.Connections.pas nao tinha limpo aqui: LOGGERS_PROFILE_DLL_PATH/
    _DLL_NAME + DEFAULT_LOGGERS_DB_DLL_PATH/_DLL_NAME + as 2 linhas seeded
    correspondentes em LOGGERS_PARAM_DEFAULTS (chaves 'dll_path'/'dll_name' sob
    titulo='loggers', nunca lidas por Parameters.Connections.LoadConfigure -
    esse le so ate database_dll/dllBasePath e agora dll_download_url).
    LOGGERS_PARAM_DEFAULTS 48->46 linhas (grupo 'loggers' 10->8). Achado por
    auditoria adversarial "arquivo a arquivo, onda a onda" pedida pelo owner
    (22/07); ver .wolf/buglog.json.
  - 1.1.0 (22/07/2026): + TLoggerParamDefault + LOGGERS_PARAM_DEFAULTS (48
    linhas, tabela estruturada titulo/chave/valor/descricao consumida pelo
    bootstrap idempotente em Loggers.pas) + 6 constantes LOGGERS_TITULO_*.
  - 1.0.0 (21/07/2026): criação — FASE 8 Onda 8.1. Constantes dos 6 grupos
    de parâmetros, defaults do núcleo e comportamento de fila assíncrona.
  ============================================================================= }

unit Commons.Loggers.Consts;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_LOGGERS}

const
  { === Grupo 'Loggers' (núcleo) === }
  LOGGERS_ENABLED                = 'Enabled';
  LOGGERS_DEFAULT_LEVEL          = 'DefaultLevel';
  LOGGERS_ASYNC                  = 'Async';
  LOGGERS_QUEUE_MAX_SIZE         = 'QueueMaxSize';
  LOGGERS_FLUSH_INTERVAL_MS      = 'FlushIntervalMs';
  LOGGERS_FAILOVER_ENABLED       = 'FailoverEnabled';
  LOGGERS_MAX_FAILS_BEFORE_DISABLE = 'MaxFailsBeforeDisable';
  LOGGERS_CHANNEL_RECOVERY_MS    = 'ChannelRecoveryMs';
  LOGGERS_INCLUDE_HOST           = 'IncludeHost';
  LOGGERS_INCLUDE_THREAD_ID      = 'IncludeThreadId';
  LOGGERS_INCLUDE_USER_NAME      = 'IncludeUserName';
  LOGGERS_APP_NAME_OVERRIDE      = 'AppNameOverride';

  { === Grupo 'loggers' (perfil de conexão do canal Database) === }
  LOGGERS_PROFILE_DATABASE_TYPE  = 'database_type';
  LOGGERS_PROFILE_HOST           = 'host';
  LOGGERS_PROFILE_PORT           = 'port';
  LOGGERS_PROFILE_USERNAME       = 'username';
  LOGGERS_PROFILE_PASSWORD       = 'password';
  LOGGERS_PROFILE_DATABASE       = 'database';
  LOGGERS_PROFILE_SCHEMA         = 'schema';
  LOGGERS_PROFILE_SERVER_NAME    = 'server_name';  // SQL Anywhere ENG

  { === Grupo 'Loggers.Database' (comportamento do canal Database) === }
  LOGGERS_DB_ENABLED             = 'Enabled';
  LOGGERS_DB_CONNECTION_PROFILE  = 'ConnectionProfile';
  LOGGERS_DB_TABLE_NAME          = 'TableName';
  LOGGERS_DB_AUTO_CREATE_TABLE   = 'AutoCreateTable';
  LOGGERS_DB_RETENTION_DAYS      = 'RetentionDays';

  { === Grupo 'Loggers.TextFile' (canal .log) === }
  LOGGERS_TXT_ENABLED            = 'Enabled';
  LOGGERS_TXT_FOLDER_PATH        = 'FolderPath';
  LOGGERS_TXT_FILE_NAME_PATTERN  = 'FileNamePattern';
  LOGGERS_TXT_FILE_PREFIX        = 'FilePrefix';
  LOGGERS_TXT_FILE_SUFFIX        = 'FileSuffix';
  LOGGERS_TXT_ROTATION_BY_SIZE_MB = 'RotationBySizeMB';
  LOGGERS_TXT_ROTATION_BY_DATE   = 'RotationByDate';
  LOGGERS_TXT_MAX_FILES_TO_KEEP  = 'MaxFilesToKeep';
  LOGGERS_TXT_ENCODING           = 'Encoding';
  LOGGERS_TXT_COMPRESS           = 'Compress';

  { === Grupo 'Loggers.Json' (canal JSON NDJSON) === }
  LOGGERS_JSON_ENABLED           = 'Enabled';
  LOGGERS_JSON_FOLDER_PATH       = 'FolderPath';
  LOGGERS_JSON_FILE_NAME_PATTERN = 'FileNamePattern';
  LOGGERS_JSON_FILE_SUFFIX       = 'FileSuffix';
  LOGGERS_JSON_FORMAT            = 'Format';   // NDJSON ou Array
  LOGGERS_JSON_ROTATION_BY_SIZE_MB = 'RotationBySizeMB';
  LOGGERS_JSON_ROTATION_BY_DATE  = 'RotationByDate';
  LOGGERS_JSON_MAX_FILES_TO_KEEP = 'MaxFilesToKeep';

  { === Grupo 'Loggers.Format' (template de formatação) === }
  LOGGERS_FMT_TEMPLATE           = 'Template';
  LOGGERS_FMT_DATE_FORMAT        = 'DateFormat';
  LOGGERS_FMT_TIME_FORMAT        = 'TimeFormat';

  { === Grupo 'Loggers.EventLog' (canal Windows Event Log, F8 Onda 8.4.1) === }
  LOGGERS_EVT_ENABLED            = 'Enabled';
  LOGGERS_EVT_SOURCE_NAME        = 'SourceName';
  LOGGERS_EVT_LOG_NAME           = 'LogName';
  LOGGERS_EVT_AUTO_CREATE_SOURCE = 'AutoCreateSource';

  { === Grupo 'Loggers.CSV' (canal CSV, F8 Onda 8.4.2) === }
  LOGGERS_CSV_ENABLED            = 'Enabled';
  LOGGERS_CSV_FOLDER_PATH        = 'FolderPath';
  LOGGERS_CSV_FILE_NAME_PATTERN  = 'FileNamePattern';
  LOGGERS_CSV_FILE_SUFFIX        = 'FileSuffix';
  LOGGERS_CSV_ROTATION_BY_SIZE_MB = 'RotationBySizeMB';
  LOGGERS_CSV_ROTATION_BY_DATE   = 'RotationByDate';
  LOGGERS_CSV_MAX_FILES_TO_KEEP  = 'MaxFilesToKeep';
  LOGGERS_CSV_DELIMITER          = 'Delimiter';
  LOGGERS_CSV_INCLUDE_HEADERS    = 'IncludeHeaders';

  { === Grupo 'Loggers.Http' (canal HTTP genérico via ICS, F8 Onda 8.4.3) === }
  LOGGERS_HTTP_ENABLED             = 'Enabled';
  LOGGERS_HTTP_URL                 = 'Url';
  LOGGERS_HTTP_TIMEOUT_SEC         = 'TimeoutSec';
  LOGGERS_HTTP_AUTH_TYPE           = 'AuthType';           // None/Basic/Bearer/ApiKey
  LOGGERS_HTTP_AUTH_USERNAME       = 'AuthUsername';
  LOGGERS_HTTP_AUTH_PASSWORD       = 'AuthPassword';
  LOGGERS_HTTP_AUTH_TOKEN          = 'AuthToken';          // Bearer
  LOGGERS_HTTP_AUTH_APIKEY_HEADER  = 'AuthApiKeyHeader';
  LOGGERS_HTTP_AUTH_APIKEY_VALUE   = 'AuthApiKeyValue';
  LOGGERS_HTTP_RETRY_MAX_RETRIES   = 'RetryMaxRetries';
  LOGGERS_HTTP_RETRY_INTERVAL_MS   = 'RetryIntervalMs';
  LOGGERS_HTTP_TLS_VERIFY_CERT     = 'TlsVerifyCert';       // valida o certificado do servidor (anti-MITM)
  LOGGERS_HTTP_TLS_CA_FILE         = 'TlsCAFile';           // bundle CA custom em PEM (vazio = CAs raiz embutidos do ICS)

  { === Grupo 'Loggers.Email' (canal Email genérico via ICS, F8 Onda 8.4.4) === }
  LOGGERS_EML_ENABLED              = 'Enabled';
  LOGGERS_EML_HOST                 = 'Host';
  LOGGERS_EML_PORT                 = 'Port';
  LOGGERS_EML_SSL_MODE             = 'SslMode';             // None/Implicit/Explicit
  LOGGERS_EML_USERNAME             = 'Username';
  LOGGERS_EML_PASSWORD             = 'Password';
  LOGGERS_EML_AUTH_TYPE            = 'AuthType';             // None/Login
  LOGGERS_EML_TIMEOUT_SEC          = 'TimeoutSec';
  LOGGERS_EML_FROM_ADDRESS         = 'FromAddress';
  LOGGERS_EML_FROM_NAME            = 'FromName';
  LOGGERS_EML_TO_ADDRESSES         = 'ToAddresses';          // separados por ';'
  LOGGERS_EML_CC_ADDRESSES         = 'CcAddresses';          // separados por ';'
  LOGGERS_EML_BCC_ADDRESSES        = 'BccAddresses';         // separados por ';' (so' no envelope, nunca em header)
  LOGGERS_EML_SUBJECT_PREFIX       = 'SubjectPrefix';
  LOGGERS_EML_AGG_ENABLED          = 'AggregationEnabled';
  LOGGERS_EML_AGG_MAX_COUNT        = 'AggregationMaxCount';
  LOGGERS_EML_AGG_MAX_INTERVAL_SEC = 'AggregationMaxIntervalSec';
  LOGGERS_EML_AGG_MIN_LEVEL        = 'AggregationMinLevel';  // 'None' desativa o gatilho por nivel
  LOGGERS_EML_TLS_VERIFY_CERT      = 'TlsVerifyCert';        // valida o certificado do servidor SMTP (anti-MITM)
  LOGGERS_EML_TLS_CA_FILE          = 'TlsCAFile';            // bundle CA custom em PEM (vazio = CAs raiz embutidos do ICS)

  { === Grupo 'Loggers.WebSocket' (canal WebSocket broadcast-only via ICS, F8 Onda 8.4.5) === }
  LOGGERS_WS_ENABLED               = 'Enabled';
  LOGGERS_WS_PORT                  = 'Port';
  LOGGERS_WS_BIND_ADDR             = 'BindAddr';
  LOGGERS_WS_MAX_CLIENTS           = 'MaxClients';

  { === Grupo 'Loggers.Console' (canal stdout via Writeln, F8 Onda 8.4.6) === }
  LOGGERS_CONSOLE_ENABLED          = 'Enabled';
  LOGGERS_CONSOLE_USE_COLORS       = 'UseColors';

  { === Grupo 'Loggers.Memory' (canal ring-buffer in-memory, F8 Onda 8.4.7) === }
  LOGGERS_MEMORY_ENABLED           = 'Enabled';
  LOGGERS_MEMORY_CAPACITY          = 'Capacity';

  { === Grupo 'Loggers.Redis' (canal Redis PUBLISH/LPUSH via ICS, F8 Onda 8.15) === }
  LOGGERS_REDIS_ENABLED            = 'Enabled';
  LOGGERS_REDIS_HOST               = 'Host';
  LOGGERS_REDIS_PORT               = 'Port';
  LOGGERS_REDIS_PASSWORD           = 'Password';         // AUTH (requirepass do servidor); vazio = sem AUTH
  LOGGERS_REDIS_DB_INDEX           = 'DbIndex';           // SELECT <n>
  LOGGERS_REDIS_MODE               = 'Mode';              // Publish (PUBLISH) ou List (LPUSH)
  LOGGERS_REDIS_CHANNEL_OR_KEY     = 'ChannelOrKey';       // nome do canal (PUBLISH) ou da chave-lista (LPUSH)
  LOGGERS_REDIS_TIMEOUT_SEC        = 'TimeoutSec';

  { === Grupo 'Loggers.ElasticSearch' (canal Bulk Index API via ICS HTTP(S), F8 Onda 8.16) === }
  LOGGERS_ES_ENABLED               = 'Enabled';
  LOGGERS_ES_HOST                  = 'Host';
  LOGGERS_ES_PORT                  = 'Port';
  LOGGERS_ES_SCHEME                = 'Scheme';             // http ou https
  LOGGERS_ES_INDEX                 = 'Index';
  LOGGERS_ES_USERNAME              = 'Username';            // Basic auth (so' usado se ApiKey vazio)
  LOGGERS_ES_PASSWORD              = 'Password';            // Basic auth (so' usado se ApiKey vazio)
  LOGGERS_ES_API_KEY               = 'ApiKey';              // Authorization: ApiKey <valor> - prioridade sobre Basic
  LOGGERS_ES_TLS_VERIFY_CERT       = 'TlsVerifyCert';       // valida o certificado do servidor (anti-MITM, so' Scheme=https)
  LOGGERS_ES_TLS_CA_FILE           = 'TlsCAFile';           // bundle CA custom em PEM (vazio = CAs raiz embutidos do ICS)
  LOGGERS_ES_BATCH_SIZE            = 'BatchSize';           // nº de entradas por POST _bulk (1 = 1 Write = 1 POST)

  { === Grupo 'Loggers.SysLog' (canal SysLog RFC5424 via ICS, FASE 8) === }
  LOGGERS_SYSLOG_ENABLED           = 'Enabled';
  LOGGERS_SYSLOG_HOST              = 'Host';
  LOGGERS_SYSLOG_PORT              = 'Port';
  LOGGERS_SYSLOG_PROTOCOL          = 'Protocol';           // udp (default) ou tcp
  LOGGERS_SYSLOG_FACILITY          = 'Facility';           // 0..23 RFC5424 (16 = local0)
  LOGGERS_SYSLOG_APP_NAME          = 'AppName';            // vazio = ExtractFileName(ParamStr(0))
  LOGGERS_SYSLOG_HOSTNAME          = 'Hostname';           // vazio = COMPUTERNAME do SO / 'localhost'

  { === Valores iniciais (defaults) === }
  DEFAULT_LOGGERS_ENABLED        = 'True';
  DEFAULT_LOGGERS_DEFAULT_LEVEL  = 'Info';
  DEFAULT_LOGGERS_ASYNC          = 'True';
  DEFAULT_LOGGERS_QUEUE_MAX_SIZE = '10000';
  DEFAULT_LOGGERS_FLUSH_INTERVAL_MS = '500';
  DEFAULT_LOGGERS_FAILOVER_ENABLED = 'True';
  DEFAULT_LOGGERS_MAX_FAILS      = '5';
  DEFAULT_LOGGERS_CHANNEL_RECOVERY_MS = '30000';  // cooldown antes de reativar um canal auto-desativado (0 = nunca reativa)
  DEFAULT_LOGGERS_INCLUDE_HOST   = 'True';
  DEFAULT_LOGGERS_INCLUDE_THREAD = 'True';
  DEFAULT_LOGGERS_INCLUDE_USER   = 'False';
  DEFAULT_LOGGERS_APP_NAME       = '';

  DEFAULT_LOGGERS_PROFILE        = 'loggers';
  DEFAULT_LOGGERS_DB_ENABLED     = 'True';
  DEFAULT_LOGGERS_DB_TABLE       = 'logs';
  DEFAULT_LOGGERS_DB_AUTO_CREATE = 'True';
  DEFAULT_LOGGERS_DB_RETENTION   = '90';

  DEFAULT_LOGGERS_TXT_ENABLED    = 'True';
  DEFAULT_LOGGERS_TXT_FOLDER     = 'data\logs';
  DEFAULT_LOGGERS_TXT_PATTERN    = '{AppName}_{Date}.log';
  DEFAULT_LOGGERS_TXT_PREFIX     = '';
  DEFAULT_LOGGERS_TXT_SUFFIX     = '.log';
  DEFAULT_LOGGERS_TXT_ROTATION_SIZE = '10';
  DEFAULT_LOGGERS_TXT_ROTATION_DATE = 'True';
  DEFAULT_LOGGERS_TXT_MAX_FILES  = '30';
  DEFAULT_LOGGERS_TXT_ENCODING   = 'UTF8';
  DEFAULT_LOGGERS_TXT_COMPRESS   = 'False';

  DEFAULT_LOGGERS_JSON_ENABLED   = 'True';
  DEFAULT_LOGGERS_JSON_FOLDER    = 'data\logs';
  DEFAULT_LOGGERS_JSON_PATTERN   = '{AppName}_{Date}.json';
  DEFAULT_LOGGERS_JSON_SUFFIX    = '.json';
  DEFAULT_LOGGERS_JSON_FORMAT    = 'NDJSON';
  DEFAULT_LOGGERS_JSON_ROTATION_SIZE = '10';
  DEFAULT_LOGGERS_JSON_ROTATION_DATE = 'True';
  DEFAULT_LOGGERS_JSON_MAX_FILES = '30';

  DEFAULT_LOGGERS_FMT_TEMPLATE   = '[{Date} {Time}] [{Level}] {Message}';
  DEFAULT_LOGGERS_FMT_DATE       = 'yyyy-mm-dd';
  DEFAULT_LOGGERS_FMT_TIME       = 'hh:nn:ss.zzz';

  DEFAULT_LOGGERS_DB_TYPE        = 'SQLite';
  DEFAULT_LOGGERS_DB_HOST        = '';
  DEFAULT_LOGGERS_DB_PORT        = '0';
  DEFAULT_LOGGERS_DB_USERNAME    = '';
  DEFAULT_LOGGERS_DB_PASSWORD    = '';
  DEFAULT_LOGGERS_DB_DATABASE    = 'data\logs.db';
  DEFAULT_LOGGERS_DB_SCHEMA      = '';
  DEFAULT_LOGGERS_DB_SERVER_NAME = '';

  DEFAULT_LOGGERS_EVT_ENABLED     = 'True';
  DEFAULT_LOGGERS_EVT_SOURCE_NAME = '';           // vazio = AppNameOverride/ExtractFileName(ParamStr(0))
  DEFAULT_LOGGERS_EVT_LOG_NAME    = 'Application';
  DEFAULT_LOGGERS_EVT_AUTO_CREATE = 'True';

  DEFAULT_LOGGERS_CSV_ENABLED    = 'True';
  DEFAULT_LOGGERS_CSV_FOLDER     = 'data\logs';
  DEFAULT_LOGGERS_CSV_PATTERN    = '{AppName}_{Date}.csv';
  DEFAULT_LOGGERS_CSV_SUFFIX     = '.csv';
  DEFAULT_LOGGERS_CSV_ROTATION_SIZE = '10';
  DEFAULT_LOGGERS_CSV_ROTATION_DATE = 'True';
  DEFAULT_LOGGERS_CSV_MAX_FILES  = '30';
  DEFAULT_LOGGERS_CSV_DELIMITER  = ',';
  DEFAULT_LOGGERS_CSV_INCLUDE_HEADERS = 'True';

  DEFAULT_LOGGERS_HTTP_ENABLED            = 'True';
  DEFAULT_LOGGERS_HTTP_URL                = '';           // vazio = FReady=False, canal inerte ate configurado
  DEFAULT_LOGGERS_HTTP_TIMEOUT_SEC        = '30';          // segundos - ICS THttpCli.Timeout sincrono e' em segundos, nao ms (confirmado no vendor source)
  DEFAULT_LOGGERS_HTTP_AUTH_TYPE          = 'None';
  DEFAULT_LOGGERS_HTTP_AUTH_USERNAME      = '';
  DEFAULT_LOGGERS_HTTP_AUTH_PASSWORD      = '';
  DEFAULT_LOGGERS_HTTP_AUTH_TOKEN         = '';
  DEFAULT_LOGGERS_HTTP_AUTH_APIKEY_HEADER = 'X-API-Key';
  DEFAULT_LOGGERS_HTTP_AUTH_APIKEY_VALUE  = '';
  DEFAULT_LOGGERS_HTTP_RETRY_MAX_RETRIES  = '3';
  DEFAULT_LOGGERS_HTTP_RETRY_INTERVAL_MS  = '1000';
  DEFAULT_LOGGERS_HTTP_TLS_VERIFY_CERT    = 'True';   // seguro por default: valida cert; self-signed exige TlsCAFile ou opt-out explicito
  DEFAULT_LOGGERS_HTTP_TLS_CA_FILE        = '';       // vazio = usa o bundle de CAs raiz embutido do ICS

  DEFAULT_LOGGERS_EML_ENABLED       = 'True';
  DEFAULT_LOGGERS_EML_HOST          = '';           // vazio = FReady=False, canal inerte ate configurado
  DEFAULT_LOGGERS_EML_PORT          = '25';
  DEFAULT_LOGGERS_EML_SSL_MODE      = 'None';
  DEFAULT_LOGGERS_EML_USERNAME      = '';
  DEFAULT_LOGGERS_EML_PASSWORD      = '';
  DEFAULT_LOGGERS_EML_AUTH_TYPE     = 'None';
  DEFAULT_LOGGERS_EML_TIMEOUT_SEC   = '30';          // segundos - mesmo padrao do canal Http (TSyncSmtpCli.Timeout tambem e' em segundos no vendor source)
  DEFAULT_LOGGERS_EML_FROM_ADDRESS  = '';
  DEFAULT_LOGGERS_EML_FROM_NAME     = '';
  DEFAULT_LOGGERS_EML_TO_ADDRESSES  = '';           // vazio = FReady=False
  DEFAULT_LOGGERS_EML_CC_ADDRESSES  = '';
  DEFAULT_LOGGERS_EML_BCC_ADDRESSES = '';
  DEFAULT_LOGGERS_EML_SUBJECT_PREFIX = '[ProvidersORM]';
  DEFAULT_LOGGERS_EML_AGG_ENABLED   = 'False';       // default = envio imediato por entrada (mesmo default do v2.3.0)
  DEFAULT_LOGGERS_EML_AGG_MAX_COUNT = '100';
  DEFAULT_LOGGERS_EML_AGG_MAX_INTERVAL_SEC = '300';  // 5 min
  DEFAULT_LOGGERS_EML_AGG_MIN_LEVEL = 'Error';       // qualquer entrada >= Error no buffer forca o envio do lote inteiro
  DEFAULT_LOGGERS_EML_TLS_VERIFY_CERT = 'True';      // seguro por default: valida cert SMTP; self-signed exige TlsCAFile ou opt-out explicito
  DEFAULT_LOGGERS_EML_TLS_CA_FILE   = '';            // vazio = usa o bundle de CAs raiz embutido do ICS

  DEFAULT_LOGGERS_WS_ENABLED  = 'False';    // servidor so escuta se explicitamente ligado (efeito colateral de rede, nao arranca sozinho)
  DEFAULT_LOGGERS_WS_PORT     = '8090';
  DEFAULT_LOGGERS_WS_BIND_ADDR = '127.0.0.1';  // so localhost por default (mais seguro que 0.0.0.0)
  DEFAULT_LOGGERS_WS_MAX_CLIENTS = '50';

  DEFAULT_LOGGERS_CONSOLE_ENABLED    = 'True';
  DEFAULT_LOGGERS_CONSOLE_USE_COLORS = 'True';

  DEFAULT_LOGGERS_MEMORY_ENABLED  = 'True';
  DEFAULT_LOGGERS_MEMORY_CAPACITY = '1000';

  DEFAULT_LOGGERS_REDIS_ENABLED       = 'True';
  DEFAULT_LOGGERS_REDIS_HOST          = '';        // vazio = FReady=False, canal inerte ate configurado
  DEFAULT_LOGGERS_REDIS_PORT          = '6379';
  DEFAULT_LOGGERS_REDIS_PASSWORD      = '';        // vazio = sem AUTH
  DEFAULT_LOGGERS_REDIS_DB_INDEX      = '0';        // 0 = sem SELECT (DB default do servidor)
  DEFAULT_LOGGERS_REDIS_MODE          = 'Publish';
  DEFAULT_LOGGERS_REDIS_CHANNEL_OR_KEY = 'logs';
  DEFAULT_LOGGERS_REDIS_TIMEOUT_SEC   = '30';       // segundos - mesmo padrao dos canais Http/Email

  DEFAULT_LOGGERS_ES_ENABLED     = 'True';
  DEFAULT_LOGGERS_ES_HOST        = '';              // vazio = FReady=False, canal inerte ate configurado
  DEFAULT_LOGGERS_ES_PORT        = '9200';
  DEFAULT_LOGGERS_ES_SCHEME      = 'https';
  DEFAULT_LOGGERS_ES_INDEX       = 'logs';
  DEFAULT_LOGGERS_ES_USERNAME    = '';
  DEFAULT_LOGGERS_ES_PASSWORD    = '';
  DEFAULT_LOGGERS_ES_API_KEY     = '';
  DEFAULT_LOGGERS_ES_TLS_VERIFY_CERT = 'True';      // seguro por default: valida cert (Scheme=https); self-signed exige TlsCAFile ou opt-out explicito
  DEFAULT_LOGGERS_ES_TLS_CA_FILE = '';              // vazio = usa o bundle de CAs raiz embutido do ICS
  DEFAULT_LOGGERS_ES_BATCH_SIZE  = '1';             // 1 = envia a cada Write (mesmo comportamento do canal Http)

  DEFAULT_LOGGERS_SYSLOG_ENABLED  = 'True';
  DEFAULT_LOGGERS_SYSLOG_HOST     = '';              // vazio = FReady=False, canal inerte ate configurado
  DEFAULT_LOGGERS_SYSLOG_PORT     = '514';
  DEFAULT_LOGGERS_SYSLOG_PROTOCOL = 'udp';
  DEFAULT_LOGGERS_SYSLOG_FACILITY = '16';            // local0
  DEFAULT_LOGGERS_SYSLOG_APP_NAME = '';              // vazio = ExtractFileName(ParamStr(0))
  DEFAULT_LOGGERS_SYSLOG_HOSTNAME = '';              // vazio = COMPUTERNAME do SO / 'localhost'

  { === Nomes dos 16 grupos (campo `titulo` na tabela `parameters`) === }
  LOGGERS_TITULO_CORE      = 'Loggers';
  LOGGERS_TITULO_PROFILE   = 'loggers';
  LOGGERS_TITULO_DATABASE  = 'Loggers.Database';
  LOGGERS_TITULO_TEXTFILE  = 'Loggers.TextFile';
  LOGGERS_TITULO_JSON      = 'Loggers.Json';
  LOGGERS_TITULO_FORMAT    = 'Loggers.Format';
  LOGGERS_TITULO_EVENTLOG  = 'Loggers.EventLog';
  LOGGERS_TITULO_CSV       = 'Loggers.CSV';
  LOGGERS_TITULO_HTTP      = 'Loggers.Http';
  LOGGERS_TITULO_EMAIL     = 'Loggers.Email';
  LOGGERS_TITULO_WEBSOCKET = 'Loggers.WebSocket';
  LOGGERS_TITULO_CONSOLE   = 'Loggers.Console';
  LOGGERS_TITULO_MEMORY    = 'Loggers.Memory';
  LOGGERS_TITULO_REDIS     = 'Loggers.Redis';
  LOGGERS_TITULO_ELASTICSEARCH = 'Loggers.ElasticSearch';
  LOGGERS_TITULO_SYSLOG    = 'Loggers.SysLog';

type
  { Uma linha da tabela de defaults (titulo/chave/valor/descricao) consumida
    pelo bootstrap idempotente (Loggers.pas, onda 8.1). }
  TLoggerParamDefault = record
    Titulo      : string;
    Chave       : string;
    Valor       : string;
    Descricao   : string;
  end;

const
  { 126 linhas (16 grupos) - espelha as tabelas do plano F8 §"Configuração do
    módulo via Parameters/F7". Consumida em loop pelo bootstrap idempotente
    (IParameters.Exists/Insert - zero SQL manual); granularidade por chave
    individual, nunca sobrescreve valor já customizado pelo utilizador. }
  LOGGERS_PARAM_DEFAULTS: array[0..125] of TLoggerParamDefault = (
    // --- 'Loggers' (núcleo, 12) ---
    (Titulo: LOGGERS_TITULO_CORE; Chave: LOGGERS_ENABLED; Valor: DEFAULT_LOGGERS_ENABLED; Descricao: 'liga/desliga o modulo globalmente'),
    (Titulo: LOGGERS_TITULO_CORE; Chave: LOGGERS_DEFAULT_LEVEL; Valor: DEFAULT_LOGGERS_DEFAULT_LEVEL; Descricao: 'nivel minimo default (TLogLevel)'),
    (Titulo: LOGGERS_TITULO_CORE; Chave: LOGGERS_ASYNC; Valor: DEFAULT_LOGGERS_ASYNC; Descricao: 'fila assincrona ligada'),
    (Titulo: LOGGERS_TITULO_CORE; Chave: LOGGERS_QUEUE_MAX_SIZE; Valor: DEFAULT_LOGGERS_QUEUE_MAX_SIZE; Descricao: 'capacidade da fila antes da politica de descarte/bloqueio'),
    (Titulo: LOGGERS_TITULO_CORE; Chave: LOGGERS_FLUSH_INTERVAL_MS; Valor: DEFAULT_LOGGERS_FLUSH_INTERVAL_MS; Descricao: 'intervalo de descarga da fila'),
    (Titulo: LOGGERS_TITULO_CORE; Chave: LOGGERS_FAILOVER_ENABLED; Valor: DEFAULT_LOGGERS_FAILOVER_ENABLED; Descricao: 'fail-over em cascata quando um canal falha'),
    (Titulo: LOGGERS_TITULO_CORE; Chave: LOGGERS_MAX_FAILS_BEFORE_DISABLE; Valor: DEFAULT_LOGGERS_MAX_FAILS; Descricao: 'falhas consecutivas antes de desativar canal'),
    (Titulo: LOGGERS_TITULO_CORE; Chave: LOGGERS_CHANNEL_RECOVERY_MS; Valor: DEFAULT_LOGGERS_CHANNEL_RECOVERY_MS; Descricao: 'cooldown ms antes de reativar canal auto-desativado (0 = nunca reativa)'),
    (Titulo: LOGGERS_TITULO_CORE; Chave: LOGGERS_INCLUDE_HOST; Valor: DEFAULT_LOGGERS_INCLUDE_HOST; Descricao: 'hostname na entrada'),
    (Titulo: LOGGERS_TITULO_CORE; Chave: LOGGERS_INCLUDE_THREAD_ID; Valor: DEFAULT_LOGGERS_INCLUDE_THREAD; Descricao: 'id da thread'),
    (Titulo: LOGGERS_TITULO_CORE; Chave: LOGGERS_INCLUDE_USER_NAME; Valor: DEFAULT_LOGGERS_INCLUDE_USER; Descricao: 'utilizador do SO'),
    (Titulo: LOGGERS_TITULO_CORE; Chave: LOGGERS_APP_NAME_OVERRIDE; Valor: DEFAULT_LOGGERS_APP_NAME; Descricao: 'vazio = ExtractFileName(ParamStr(0))'),
    // --- 'Loggers.Database' (comportamento do canal, 5) ---
    (Titulo: LOGGERS_TITULO_DATABASE; Chave: LOGGERS_DB_ENABLED; Valor: DEFAULT_LOGGERS_DB_ENABLED; Descricao: 'canal baseline ativo'),
    (Titulo: LOGGERS_TITULO_DATABASE; Chave: LOGGERS_DB_CONNECTION_PROFILE; Valor: DEFAULT_LOGGERS_PROFILE; Descricao: 'nome do perfil de conexao (titulo do grupo loggers), informativo - o canal usa IConnection propria, nao pool'),
    (Titulo: LOGGERS_TITULO_DATABASE; Chave: LOGGERS_DB_TABLE_NAME; Valor: DEFAULT_LOGGERS_DB_TABLE; Descricao: 'tabela destino'),
    (Titulo: LOGGERS_TITULO_DATABASE; Chave: LOGGERS_DB_AUTO_CREATE_TABLE; Valor: DEFAULT_LOGGERS_DB_AUTO_CREATE; Descricao: 'cria se nao existir'),
    (Titulo: LOGGERS_TITULO_DATABASE; Chave: LOGGERS_DB_RETENTION_DAYS; Valor: DEFAULT_LOGGERS_DB_RETENTION; Descricao: 'retencao antes de purga (0 = sem purga; purga throttled a 1x/hora)'),
    // --- 'loggers' (perfil de conexao completo, 8) ---
    (Titulo: LOGGERS_TITULO_PROFILE; Chave: LOGGERS_PROFILE_DATABASE_TYPE; Valor: DEFAULT_LOGGERS_DB_TYPE; Descricao: 'tipo de banco (TDatabaseTypeClass.FromString)'),
    (Titulo: LOGGERS_TITULO_PROFILE; Chave: LOGGERS_PROFILE_HOST; Valor: DEFAULT_LOGGERS_DB_HOST; Descricao: 'host do servidor (vazio p/ SQLite/Access)'),
    (Titulo: LOGGERS_TITULO_PROFILE; Chave: LOGGERS_PROFILE_PORT; Valor: DEFAULT_LOGGERS_DB_PORT; Descricao: 'porta (0 = default do banco)'),
    (Titulo: LOGGERS_TITULO_PROFILE; Chave: LOGGERS_PROFILE_USERNAME; Valor: DEFAULT_LOGGERS_DB_USERNAME; Descricao: 'utilizador'),
    (Titulo: LOGGERS_TITULO_PROFILE; Chave: LOGGERS_PROFILE_PASSWORD; Valor: DEFAULT_LOGGERS_DB_PASSWORD; Descricao: 'password'),
    (Titulo: LOGGERS_TITULO_PROFILE; Chave: LOGGERS_PROFILE_DATABASE; Valor: DEFAULT_LOGGERS_DB_DATABASE; Descricao: 'base de dados (ficheiro SQLite zero-config ou nome do DB)'),
    (Titulo: LOGGERS_TITULO_PROFILE; Chave: LOGGERS_PROFILE_SCHEMA; Valor: DEFAULT_LOGGERS_DB_SCHEMA; Descricao: 'schema (quando aplicavel)'),
    (Titulo: LOGGERS_TITULO_PROFILE; Chave: LOGGERS_PROFILE_SERVER_NAME; Valor: DEFAULT_LOGGERS_DB_SERVER_NAME; Descricao: 'ServerName/ENG - SQL Anywhere'),
    // --- 'Loggers.TextFile' (canal .log, 10) ---
    (Titulo: LOGGERS_TITULO_TEXTFILE; Chave: LOGGERS_TXT_ENABLED; Valor: DEFAULT_LOGGERS_TXT_ENABLED; Descricao: 'canal baseline ativo'),
    (Titulo: LOGGERS_TITULO_TEXTFILE; Chave: LOGGERS_TXT_FOLDER_PATH; Valor: DEFAULT_LOGGERS_TXT_FOLDER; Descricao: 'pasta base'),
    (Titulo: LOGGERS_TITULO_TEXTFILE; Chave: LOGGERS_TXT_FILE_NAME_PATTERN; Valor: DEFAULT_LOGGERS_TXT_PATTERN; Descricao: 'nomenclatura com tokens'),
    (Titulo: LOGGERS_TITULO_TEXTFILE; Chave: LOGGERS_TXT_FILE_PREFIX; Valor: DEFAULT_LOGGERS_TXT_PREFIX; Descricao: 'prefixo opcional'),
    (Titulo: LOGGERS_TITULO_TEXTFILE; Chave: LOGGERS_TXT_FILE_SUFFIX; Valor: DEFAULT_LOGGERS_TXT_SUFFIX; Descricao: 'sufixo/extensao'),
    (Titulo: LOGGERS_TITULO_TEXTFILE; Chave: LOGGERS_TXT_ROTATION_BY_SIZE_MB; Valor: DEFAULT_LOGGERS_TXT_ROTATION_SIZE; Descricao: 'rotacao por tamanho'),
    (Titulo: LOGGERS_TITULO_TEXTFILE; Chave: LOGGERS_TXT_ROTATION_BY_DATE; Valor: DEFAULT_LOGGERS_TXT_ROTATION_DATE; Descricao: 'rotacao diaria'),
    (Titulo: LOGGERS_TITULO_TEXTFILE; Chave: LOGGERS_TXT_MAX_FILES_TO_KEEP; Valor: DEFAULT_LOGGERS_TXT_MAX_FILES; Descricao: 'retencao de rodados'),
    (Titulo: LOGGERS_TITULO_TEXTFILE; Chave: LOGGERS_TXT_ENCODING; Valor: DEFAULT_LOGGERS_TXT_ENCODING; Descricao: 'encoding'),
    (Titulo: LOGGERS_TITULO_TEXTFILE; Chave: LOGGERS_TXT_COMPRESS; Valor: DEFAULT_LOGGERS_TXT_COMPRESS; Descricao: 'comprime rodados'),
    // --- 'Loggers.Json' (canal JSON NDJSON, 8) ---
    (Titulo: LOGGERS_TITULO_JSON; Chave: LOGGERS_JSON_ENABLED; Valor: DEFAULT_LOGGERS_JSON_ENABLED; Descricao: 'canal baseline ativo'),
    (Titulo: LOGGERS_TITULO_JSON; Chave: LOGGERS_JSON_FOLDER_PATH; Valor: DEFAULT_LOGGERS_JSON_FOLDER; Descricao: 'mesma raiz do TextFile'),
    (Titulo: LOGGERS_TITULO_JSON; Chave: LOGGERS_JSON_FILE_NAME_PATTERN; Valor: DEFAULT_LOGGERS_JSON_PATTERN; Descricao: 'nomenclatura com tokens'),
    (Titulo: LOGGERS_TITULO_JSON; Chave: LOGGERS_JSON_FILE_SUFFIX; Valor: DEFAULT_LOGGERS_JSON_SUFFIX; Descricao: 'extensao'),
    (Titulo: LOGGERS_TITULO_JSON; Chave: LOGGERS_JSON_FORMAT; Valor: DEFAULT_LOGGERS_JSON_FORMAT; Descricao: 'newline-delimited (NDJSON) vs Array'),
    (Titulo: LOGGERS_TITULO_JSON; Chave: LOGGERS_JSON_ROTATION_BY_SIZE_MB; Valor: DEFAULT_LOGGERS_JSON_ROTATION_SIZE; Descricao: 'rotacao por tamanho'),
    (Titulo: LOGGERS_TITULO_JSON; Chave: LOGGERS_JSON_ROTATION_BY_DATE; Valor: DEFAULT_LOGGERS_JSON_ROTATION_DATE; Descricao: 'rotacao diaria'),
    (Titulo: LOGGERS_TITULO_JSON; Chave: LOGGERS_JSON_MAX_FILES_TO_KEEP; Valor: DEFAULT_LOGGERS_JSON_MAX_FILES; Descricao: 'retencao de rodados'),
    // --- 'Loggers.Format' (template de formatacao, 3) ---
    (Titulo: LOGGERS_TITULO_FORMAT; Chave: LOGGERS_FMT_TEMPLATE; Valor: DEFAULT_LOGGERS_FMT_TEMPLATE; Descricao: 'tokens: Date/Time/Level/Message/Category/AppName/Host/ThreadId/Tag'),
    (Titulo: LOGGERS_TITULO_FORMAT; Chave: LOGGERS_FMT_DATE_FORMAT; Valor: DEFAULT_LOGGERS_FMT_DATE; Descricao: 'formato de data'),
    (Titulo: LOGGERS_TITULO_FORMAT; Chave: LOGGERS_FMT_TIME_FORMAT; Valor: DEFAULT_LOGGERS_FMT_TIME; Descricao: 'formato de hora'),
    // --- 'Loggers.EventLog' (canal Windows Event Log, F8 Onda 8.4.1, 4) ---
    (Titulo: LOGGERS_TITULO_EVENTLOG; Chave: LOGGERS_EVT_ENABLED; Valor: DEFAULT_LOGGERS_EVT_ENABLED; Descricao: 'canal ativo (so Windows - inerte fora dele)'),
    (Titulo: LOGGERS_TITULO_EVENTLOG; Chave: LOGGERS_EVT_SOURCE_NAME; Valor: DEFAULT_LOGGERS_EVT_SOURCE_NAME; Descricao: 'nome da fonte no Event Viewer (vazio = AppNameOverride/nome do exe)'),
    (Titulo: LOGGERS_TITULO_EVENTLOG; Chave: LOGGERS_EVT_LOG_NAME; Valor: DEFAULT_LOGGERS_EVT_LOG_NAME; Descricao: 'log destino (Application/System/custom)'),
    (Titulo: LOGGERS_TITULO_EVENTLOG; Chave: LOGGERS_EVT_AUTO_CREATE_SOURCE; Valor: DEFAULT_LOGGERS_EVT_AUTO_CREATE; Descricao: 'regista a fonte no registry (HKLM) se nao existir - exige admin, falha degrada silenciosamente'),
    // --- 'Loggers.CSV' (canal CSV, F8 Onda 8.4.2, 9) ---
    (Titulo: LOGGERS_TITULO_CSV; Chave: LOGGERS_CSV_ENABLED; Valor: DEFAULT_LOGGERS_CSV_ENABLED; Descricao: 'canal baseline ativo'),
    (Titulo: LOGGERS_TITULO_CSV; Chave: LOGGERS_CSV_FOLDER_PATH; Valor: DEFAULT_LOGGERS_CSV_FOLDER; Descricao: 'pasta base (mesma raiz do TextFile/Json)'),
    (Titulo: LOGGERS_TITULO_CSV; Chave: LOGGERS_CSV_FILE_NAME_PATTERN; Valor: DEFAULT_LOGGERS_CSV_PATTERN; Descricao: 'nomenclatura com tokens'),
    (Titulo: LOGGERS_TITULO_CSV; Chave: LOGGERS_CSV_FILE_SUFFIX; Valor: DEFAULT_LOGGERS_CSV_SUFFIX; Descricao: 'sufixo/extensao'),
    (Titulo: LOGGERS_TITULO_CSV; Chave: LOGGERS_CSV_ROTATION_BY_SIZE_MB; Valor: DEFAULT_LOGGERS_CSV_ROTATION_SIZE; Descricao: 'rotacao por tamanho'),
    (Titulo: LOGGERS_TITULO_CSV; Chave: LOGGERS_CSV_ROTATION_BY_DATE; Valor: DEFAULT_LOGGERS_CSV_ROTATION_DATE; Descricao: 'rotacao diaria'),
    (Titulo: LOGGERS_TITULO_CSV; Chave: LOGGERS_CSV_MAX_FILES_TO_KEEP; Valor: DEFAULT_LOGGERS_CSV_MAX_FILES; Descricao: 'retencao de rodados'),
    (Titulo: LOGGERS_TITULO_CSV; Chave: LOGGERS_CSV_DELIMITER; Valor: DEFAULT_LOGGERS_CSV_DELIMITER; Descricao: 'separador de campo (virgula/ponto-e-virgula/tab/pipe/custom - 1+ caracteres)'),
    (Titulo: LOGGERS_TITULO_CSV; Chave: LOGGERS_CSV_INCLUDE_HEADERS; Valor: DEFAULT_LOGGERS_CSV_INCLUDE_HEADERS; Descricao: 'escreve linha de cabecalho no inicio de cada ficheiro (incl. rodados)'),
    // --- 'Loggers.Http' (canal HTTP generico via ICS, F8 Onda 8.4.3, Delphi-only, 13) ---
    (Titulo: LOGGERS_TITULO_HTTP; Chave: LOGGERS_HTTP_ENABLED; Valor: DEFAULT_LOGGERS_HTTP_ENABLED; Descricao: 'canal ativo (inerte se Url vazio, ou sob FPC - ICS Delphi-only nesta build)'),
    (Titulo: LOGGERS_TITULO_HTTP; Chave: LOGGERS_HTTP_URL; Valor: DEFAULT_LOGGERS_HTTP_URL; Descricao: 'endpoint POST completo (http:// ou https://); vazio = canal inerte'),
    (Titulo: LOGGERS_TITULO_HTTP; Chave: LOGGERS_HTTP_TIMEOUT_SEC; Valor: DEFAULT_LOGGERS_HTTP_TIMEOUT_SEC; Descricao: 'timeout em SEGUNDOS (ICS sincrono usa segundos, nao ms)'),
    (Titulo: LOGGERS_TITULO_HTTP; Chave: LOGGERS_HTTP_AUTH_TYPE; Valor: DEFAULT_LOGGERS_HTTP_AUTH_TYPE; Descricao: 'None/Basic/Bearer/ApiKey'),
    (Titulo: LOGGERS_TITULO_HTTP; Chave: LOGGERS_HTTP_AUTH_USERNAME; Valor: DEFAULT_LOGGERS_HTTP_AUTH_USERNAME; Descricao: 'AuthType=Basic'),
    (Titulo: LOGGERS_TITULO_HTTP; Chave: LOGGERS_HTTP_AUTH_PASSWORD; Valor: DEFAULT_LOGGERS_HTTP_AUTH_PASSWORD; Descricao: 'AuthType=Basic'),
    (Titulo: LOGGERS_TITULO_HTTP; Chave: LOGGERS_HTTP_AUTH_TOKEN; Valor: DEFAULT_LOGGERS_HTTP_AUTH_TOKEN; Descricao: 'AuthType=Bearer'),
    (Titulo: LOGGERS_TITULO_HTTP; Chave: LOGGERS_HTTP_AUTH_APIKEY_HEADER; Valor: DEFAULT_LOGGERS_HTTP_AUTH_APIKEY_HEADER; Descricao: 'AuthType=ApiKey - nome do header'),
    (Titulo: LOGGERS_TITULO_HTTP; Chave: LOGGERS_HTTP_AUTH_APIKEY_VALUE; Valor: DEFAULT_LOGGERS_HTTP_AUTH_APIKEY_VALUE; Descricao: 'AuthType=ApiKey - valor do header'),
    (Titulo: LOGGERS_TITULO_HTTP; Chave: LOGGERS_HTTP_RETRY_MAX_RETRIES; Valor: DEFAULT_LOGGERS_HTTP_RETRY_MAX_RETRIES; Descricao: 'retentativas apos a 1a tentativa (0 = sem retry)'),
    (Titulo: LOGGERS_TITULO_HTTP; Chave: LOGGERS_HTTP_RETRY_INTERVAL_MS; Valor: DEFAULT_LOGGERS_HTTP_RETRY_INTERVAL_MS; Descricao: 'intervalo base em ms, backoff exponencial (x1,x2,x4,...)'),
    (Titulo: LOGGERS_TITULO_HTTP; Chave: LOGGERS_HTTP_TLS_VERIFY_CERT; Valor: DEFAULT_LOGGERS_HTTP_TLS_VERIFY_CERT; Descricao: 'valida o certificado TLS do servidor (True = seguro/anti-MITM; False = aceita qualquer cert)'),
    (Titulo: LOGGERS_TITULO_HTTP; Chave: LOGGERS_HTTP_TLS_CA_FILE; Valor: DEFAULT_LOGGERS_HTTP_TLS_CA_FILE; Descricao: 'ficheiro de CAs custom em PEM (vazio = bundle de CAs raiz embutido do ICS)'),
    // --- 'Loggers.Email' (canal Email generico via ICS, F8 Onda 8.4.4, Delphi-only, 20) ---
    (Titulo: LOGGERS_TITULO_EMAIL; Chave: LOGGERS_EML_ENABLED; Valor: DEFAULT_LOGGERS_EML_ENABLED; Descricao: 'canal ativo (inerte se Host/FromAddress/ToAddresses vazios, ou sob FPC - ICS Delphi-only, bug-712)'),
    (Titulo: LOGGERS_TITULO_EMAIL; Chave: LOGGERS_EML_HOST; Valor: DEFAULT_LOGGERS_EML_HOST; Descricao: 'servidor SMTP; vazio = canal inerte'),
    (Titulo: LOGGERS_TITULO_EMAIL; Chave: LOGGERS_EML_PORT; Valor: DEFAULT_LOGGERS_EML_PORT; Descricao: 'porta SMTP (25 sem TLS, 587 STARTTLS, 465 SSL implicito)'),
    (Titulo: LOGGERS_TITULO_EMAIL; Chave: LOGGERS_EML_SSL_MODE; Valor: DEFAULT_LOGGERS_EML_SSL_MODE; Descricao: 'None/Implicit/Explicit (STARTTLS)'),
    (Titulo: LOGGERS_TITULO_EMAIL; Chave: LOGGERS_EML_USERNAME; Valor: DEFAULT_LOGGERS_EML_USERNAME; Descricao: 'AuthType=Login'),
    (Titulo: LOGGERS_TITULO_EMAIL; Chave: LOGGERS_EML_PASSWORD; Valor: DEFAULT_LOGGERS_EML_PASSWORD; Descricao: 'AuthType=Login'),
    (Titulo: LOGGERS_TITULO_EMAIL; Chave: LOGGERS_EML_AUTH_TYPE; Valor: DEFAULT_LOGGERS_EML_AUTH_TYPE; Descricao: 'None/Login (AUTH LOGIN)'),
    (Titulo: LOGGERS_TITULO_EMAIL; Chave: LOGGERS_EML_TIMEOUT_SEC; Valor: DEFAULT_LOGGERS_EML_TIMEOUT_SEC; Descricao: 'timeout em SEGUNDOS (ICS sincrono usa segundos, nao ms)'),
    (Titulo: LOGGERS_TITULO_EMAIL; Chave: LOGGERS_EML_FROM_ADDRESS; Valor: DEFAULT_LOGGERS_EML_FROM_ADDRESS; Descricao: 'endereco do remetente (MAIL FROM + header From)'),
    (Titulo: LOGGERS_TITULO_EMAIL; Chave: LOGGERS_EML_FROM_NAME; Valor: DEFAULT_LOGGERS_EML_FROM_NAME; Descricao: 'nome de exibicao do remetente (opcional)'),
    (Titulo: LOGGERS_TITULO_EMAIL; Chave: LOGGERS_EML_TO_ADDRESSES; Valor: DEFAULT_LOGGERS_EML_TO_ADDRESSES; Descricao: 'destinatarios separados por ; vazio = canal inerte'),
    (Titulo: LOGGERS_TITULO_EMAIL; Chave: LOGGERS_EML_CC_ADDRESSES; Valor: DEFAULT_LOGGERS_EML_CC_ADDRESSES; Descricao: 'copia visivel, separados por ;'),
    (Titulo: LOGGERS_TITULO_EMAIL; Chave: LOGGERS_EML_BCC_ADDRESSES; Valor: DEFAULT_LOGGERS_EML_BCC_ADDRESSES; Descricao: 'copia oculta (apenas no envelope, nunca em header), separados por ;'),
    (Titulo: LOGGERS_TITULO_EMAIL; Chave: LOGGERS_EML_SUBJECT_PREFIX; Valor: DEFAULT_LOGGERS_EML_SUBJECT_PREFIX; Descricao: 'prefixo do assunto'),
    (Titulo: LOGGERS_TITULO_EMAIL; Chave: LOGGERS_EML_AGG_ENABLED; Valor: DEFAULT_LOGGERS_EML_AGG_ENABLED; Descricao: 'agrega N entradas num so email (False = 1 email por entrada)'),
    (Titulo: LOGGERS_TITULO_EMAIL; Chave: LOGGERS_EML_AGG_MAX_COUNT; Valor: DEFAULT_LOGGERS_EML_AGG_MAX_COUNT; Descricao: 'gatilho por contagem (0 = desativado)'),
    (Titulo: LOGGERS_TITULO_EMAIL; Chave: LOGGERS_EML_AGG_MAX_INTERVAL_SEC; Valor: DEFAULT_LOGGERS_EML_AGG_MAX_INTERVAL_SEC; Descricao: 'gatilho por tempo em segundos (0 = desativado; so avaliado no proximo Write)'),
    (Titulo: LOGGERS_TITULO_EMAIL; Chave: LOGGERS_EML_AGG_MIN_LEVEL; Valor: DEFAULT_LOGGERS_EML_AGG_MIN_LEVEL; Descricao: 'gatilho por nivel - qualquer entrada no lote >= este nivel forca envio imediato do lote inteiro (None = desativado)'),
    (Titulo: LOGGERS_TITULO_EMAIL; Chave: LOGGERS_EML_TLS_VERIFY_CERT; Valor: DEFAULT_LOGGERS_EML_TLS_VERIFY_CERT; Descricao: 'valida o certificado TLS do servidor SMTP (True = seguro/anti-MITM; False = aceita qualquer cert)'),
    (Titulo: LOGGERS_TITULO_EMAIL; Chave: LOGGERS_EML_TLS_CA_FILE; Valor: DEFAULT_LOGGERS_EML_TLS_CA_FILE; Descricao: 'ficheiro de CAs custom em PEM (vazio = bundle de CAs raiz embutido do ICS)'),
    // --- 'Loggers.WebSocket' (canal WebSocket broadcast-only via ICS, F8 Onda 8.4.5, Delphi-only, 4) ---
    (Titulo: LOGGERS_TITULO_WEBSOCKET; Chave: LOGGERS_WS_ENABLED; Valor: DEFAULT_LOGGERS_WS_ENABLED; Descricao: 'servidor WS ativo (nao arranca sozinho - efeito colateral de rede; ou sob FPC - ICS Delphi-only, bug-712)'),
    (Titulo: LOGGERS_TITULO_WEBSOCKET; Chave: LOGGERS_WS_PORT; Valor: DEFAULT_LOGGERS_WS_PORT; Descricao: 'porta TCP onde o servidor WS escuta'),
    (Titulo: LOGGERS_TITULO_WEBSOCKET; Chave: LOGGERS_WS_BIND_ADDR; Valor: DEFAULT_LOGGERS_WS_BIND_ADDR; Descricao: 'interface de bind (127.0.0.1=so local; 0.0.0.0=todas)'),
    (Titulo: LOGGERS_TITULO_WEBSOCKET; Chave: LOGGERS_WS_MAX_CLIENTS; Valor: DEFAULT_LOGGERS_WS_MAX_CLIENTS; Descricao: 'limite de clientes simultaneos (0 = sem limite)'),
    // --- 'Loggers.Console' (canal stdout via Writeln, F8 Onda 8.4.6, 2) ---
    (Titulo: LOGGERS_TITULO_CONSOLE; Chave: LOGGERS_CONSOLE_ENABLED; Valor: DEFAULT_LOGGERS_CONSOLE_ENABLED; Descricao: 'canal baseline ativo'),
    (Titulo: LOGGERS_TITULO_CONSOLE; Chave: LOGGERS_CONSOLE_USE_COLORS; Valor: DEFAULT_LOGGERS_CONSOLE_USE_COLORS; Descricao: 'aplica cor por nivel na consola (Windows SetConsoleTextAttribute); reusa o template do grupo Loggers.Format'),
    // --- 'Loggers.Memory' (canal ring-buffer in-memory, F8 Onda 8.4.7, 2) ---
    (Titulo: LOGGERS_TITULO_MEMORY; Chave: LOGGERS_MEMORY_ENABLED; Valor: DEFAULT_LOGGERS_MEMORY_ENABLED; Descricao: 'canal baseline ativo'),
    (Titulo: LOGGERS_TITULO_MEMORY; Chave: LOGGERS_MEMORY_CAPACITY; Valor: DEFAULT_LOGGERS_MEMORY_CAPACITY; Descricao: 'numero maximo de entradas retidas (FIFO - descarta a mais antiga quando cheio)'),
    // --- 'Loggers.Redis' (canal Redis PUBLISH/LPUSH via ICS, F8 Onda 8.15, Delphi-only, 8) ---
    (Titulo: LOGGERS_TITULO_REDIS; Chave: LOGGERS_REDIS_ENABLED; Valor: DEFAULT_LOGGERS_REDIS_ENABLED; Descricao: 'canal ativo (inerte se Host vazio, ou sob FPC - ICS Delphi-only nesta build)'),
    (Titulo: LOGGERS_TITULO_REDIS; Chave: LOGGERS_REDIS_HOST; Valor: DEFAULT_LOGGERS_REDIS_HOST; Descricao: 'host do Redis/Memurai; vazio = canal inerte'),
    (Titulo: LOGGERS_TITULO_REDIS; Chave: LOGGERS_REDIS_PORT; Valor: DEFAULT_LOGGERS_REDIS_PORT; Descricao: 'porta TCP'),
    (Titulo: LOGGERS_TITULO_REDIS; Chave: LOGGERS_REDIS_PASSWORD; Valor: DEFAULT_LOGGERS_REDIS_PASSWORD; Descricao: 'AUTH (requirepass do servidor); vazio = sem AUTH'),
    (Titulo: LOGGERS_TITULO_REDIS; Chave: LOGGERS_REDIS_DB_INDEX; Valor: DEFAULT_LOGGERS_REDIS_DB_INDEX; Descricao: 'SELECT <n> (0 = sem SELECT, usa o DB default do servidor)'),
    (Titulo: LOGGERS_TITULO_REDIS; Chave: LOGGERS_REDIS_MODE; Valor: DEFAULT_LOGGERS_REDIS_MODE; Descricao: 'Publish (PUBLISH, pub/sub fire-and-forget) ou List (LPUSH, persiste na lista)'),
    (Titulo: LOGGERS_TITULO_REDIS; Chave: LOGGERS_REDIS_CHANNEL_OR_KEY; Valor: DEFAULT_LOGGERS_REDIS_CHANNEL_OR_KEY; Descricao: 'nome do canal (PUBLISH) ou da chave-lista (LPUSH)'),
    (Titulo: LOGGERS_TITULO_REDIS; Chave: LOGGERS_REDIS_TIMEOUT_SEC; Valor: DEFAULT_LOGGERS_REDIS_TIMEOUT_SEC; Descricao: 'timeout em SEGUNDOS por operacao (connect/auth/select/publish-lpush)'),
    // --- 'Loggers.ElasticSearch' (canal Bulk Index API via ICS HTTP(S), F8 Onda 8.16, Delphi-only, 11) ---
    (Titulo: LOGGERS_TITULO_ELASTICSEARCH; Chave: LOGGERS_ES_ENABLED; Valor: DEFAULT_LOGGERS_ES_ENABLED; Descricao: 'canal ativo (inerte se Host vazio, ou sob FPC - ICS Delphi-only nesta build)'),
    (Titulo: LOGGERS_TITULO_ELASTICSEARCH; Chave: LOGGERS_ES_HOST; Valor: DEFAULT_LOGGERS_ES_HOST; Descricao: 'host do cluster Elasticsearch; vazio = canal inerte'),
    (Titulo: LOGGERS_TITULO_ELASTICSEARCH; Chave: LOGGERS_ES_PORT; Valor: DEFAULT_LOGGERS_ES_PORT; Descricao: 'porta HTTP(S)'),
    (Titulo: LOGGERS_TITULO_ELASTICSEARCH; Chave: LOGGERS_ES_SCHEME; Valor: DEFAULT_LOGGERS_ES_SCHEME; Descricao: 'http ou https'),
    (Titulo: LOGGERS_TITULO_ELASTICSEARCH; Chave: LOGGERS_ES_INDEX; Valor: DEFAULT_LOGGERS_ES_INDEX; Descricao: 'indice destino (endpoint /<Index>/_bulk)'),
    (Titulo: LOGGERS_TITULO_ELASTICSEARCH; Chave: LOGGERS_ES_USERNAME; Valor: DEFAULT_LOGGERS_ES_USERNAME; Descricao: 'Basic auth - so usado se ApiKey vazio'),
    (Titulo: LOGGERS_TITULO_ELASTICSEARCH; Chave: LOGGERS_ES_PASSWORD; Valor: DEFAULT_LOGGERS_ES_PASSWORD; Descricao: 'Basic auth - so usado se ApiKey vazio'),
    (Titulo: LOGGERS_TITULO_ELASTICSEARCH; Chave: LOGGERS_ES_API_KEY; Valor: DEFAULT_LOGGERS_ES_API_KEY; Descricao: 'Authorization: ApiKey <valor> - tem prioridade sobre Basic Username/Password quando ambos configurados'),
    (Titulo: LOGGERS_TITULO_ELASTICSEARCH; Chave: LOGGERS_ES_TLS_VERIFY_CERT; Valor: DEFAULT_LOGGERS_ES_TLS_VERIFY_CERT; Descricao: 'valida o certificado TLS do servidor (True = seguro/anti-MITM; False = aceita qualquer cert; so relevante com Scheme=https)'),
    (Titulo: LOGGERS_TITULO_ELASTICSEARCH; Chave: LOGGERS_ES_TLS_CA_FILE; Valor: DEFAULT_LOGGERS_ES_TLS_CA_FILE; Descricao: 'ficheiro de CAs custom em PEM (vazio = bundle de CAs raiz embutido do ICS)'),
    (Titulo: LOGGERS_TITULO_ELASTICSEARCH; Chave: LOGGERS_ES_BATCH_SIZE; Valor: DEFAULT_LOGGERS_ES_BATCH_SIZE; Descricao: 'numero de entradas agrupadas por POST _bulk (1 = 1 Write = 1 POST, mesmo comportamento do canal Http)'),
    // --- 'Loggers.SysLog' (canal SysLog RFC5424 via ICS, FASE 8, Delphi-only, 7) ---
    (Titulo: LOGGERS_TITULO_SYSLOG; Chave: LOGGERS_SYSLOG_ENABLED; Valor: DEFAULT_LOGGERS_SYSLOG_ENABLED; Descricao: 'canal ativo (inerte se Host vazio, ou sob FPC - ICS Delphi-only nesta build)'),
    (Titulo: LOGGERS_TITULO_SYSLOG; Chave: LOGGERS_SYSLOG_HOST; Valor: DEFAULT_LOGGERS_SYSLOG_HOST; Descricao: 'host do recetor SysLog (rsyslog/syslog-ng/Graylog/...); vazio = canal inerte'),
    (Titulo: LOGGERS_TITULO_SYSLOG; Chave: LOGGERS_SYSLOG_PORT; Valor: DEFAULT_LOGGERS_SYSLOG_PORT; Descricao: 'porta UDP/TCP (514 e a porta standard RFC5424/RFC3164)'),
    (Titulo: LOGGERS_TITULO_SYSLOG; Chave: LOGGERS_SYSLOG_PROTOCOL; Valor: DEFAULT_LOGGERS_SYSLOG_PROTOCOL; Descricao: 'udp (fire-and-forget, default) ou tcp (framing LF nao-transparente, RFC6587)'),
    (Titulo: LOGGERS_TITULO_SYSLOG; Chave: LOGGERS_SYSLOG_FACILITY; Valor: DEFAULT_LOGGERS_SYSLOG_FACILITY; Descricao: 'facility RFC5424 (0..23; 16 = local0); fora do intervalo cai no default'),
    (Titulo: LOGGERS_TITULO_SYSLOG; Chave: LOGGERS_SYSLOG_APP_NAME; Valor: DEFAULT_LOGGERS_SYSLOG_APP_NAME; Descricao: 'APP-NAME do cabecalho RFC5424; vazio = ExtractFileName(ParamStr(0))'),
    (Titulo: LOGGERS_TITULO_SYSLOG; Chave: LOGGERS_SYSLOG_HOSTNAME; Valor: DEFAULT_LOGGERS_SYSLOG_HOSTNAME; Descricao: 'HOSTNAME do cabecalho RFC5424; vazio = COMPUTERNAME do SO ou localhost')
  );

{$ENDIF USE_LOGGERS}

implementation

end.
