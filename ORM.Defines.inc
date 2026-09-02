(* =============================================================================
  ORM.Defines.inc - Compilation directives for the unified ProvidersORM project

  Organization (plan section 3-B):
    Layer 1 - Database engine (activate EXACTLY ONE)
    Layer 2 - Ecosystem modules (inclusion gates; ON by default)
    Layer 3 - Infrastructure engines (network / UI)
    Layer 4 - Linear validation (platform, engine uniqueness, dependencies)

  Rules:
    - Core areas (Commons, Exceptions, Connections) have NO gate: always present.
    - A disabled module makes its facade return a typed stub exception.
    - Informational $MESSAGE HINT output only under USE_VERBOSE_DEFINES.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  FileVersion:    1.12.0
  Author:         Claiton de Souza Linhares
  Date:           12/08/2026

  Changelog (file):
  - 1.12.0 (12/08/2026): FASE 10 Onda 10.2 Tarefa B - USE_PROVIDERS_V200
    (Layer 3, ON by default) added for the new compatibility bridge
    src/Main/Providers.v200.pas (translates the v2.0/v2.3 TProviders public
    API - NewConnection/DefaultConnection/Parameter/Logger/ReportBuilder/
    FastReport/QuickReport/FortesReport - into pure delegation calls onto the
    REAL v3 facade Providers.pas + slices, zero own logic besides the
    DefaultConnection cache mechanic). Placed in Layer 3 (infrastructure/
    compat), NOT Layer 2 - unlike USE_PROVIDERS_V161 (added concurrently in
    this same onda, Tarefa A) it is NOT part of the 4.3a EXCLUSIVE-mode UNDEF
    cascade: Providers.v200's Parameter/Logger/Printers members are already
    individually nested under their own Layer 2 gates (USE_PARAMETERS/
    USE_LOGGERS/USE_PRINTERS), which 4.3a DOES undef when USE_PROVIDERS_V161
    is on - so the bridge degrades gracefully to NewConnection/
    DefaultConnection only (core, no gate) in that scenario, no fatal
    conflict, no need for an explicit UNDEF entry.
  - 1.11.0 (12/08/2026): FASE 10 Onda 10.2 - USE_PROVIDERS_V161 (Layer 2, OFF
    by default) added for the legacy ProvidersORM v1.6.1 compatibility
    subsystem, absorbed verbatim into src/Main/Providers.v161.pas +
    src/Modulos/Providers.v161/{Commons,Modulos,Utilities} (mechanical port
    only - zero logic/behavior/symbol-name changes; owner directive, 04/07).
    New section 4.3a implements the EXCLUSIVE mode documented in the unit's
    own header: when ON, every other Layer 2 ecosystem module gate is
    auto-UNDEF'd (runs before 4.3 so the existing dependency cascades see an
    already-clean state, no duplicate WARN messages). The legacy unit is
    self-contained (own UniDAC TDataModule + own Utilities.*/Providers.
    Common.*/Providers.Module.* units) and is reached directly via
    `uses Providers.v161;` - it does NOT participate in the unified
    TProviders facade (Main/Providers.pas untouched).
  - 1.10.0 (01/08/2026): FASE 8 - USE_LOGGERS_SYSLOG turned ON (was commented
    out as a QuickLogger-only placeholder since Onda 8.4). Loggers.Channel.
    SysLog.pas (RFC5424, ICS TWSocket - UDP default/TCP) is the 13th baseline
    channel, 6th REAL channel over ICS. Layer 4.3 cascade (USE_LOGGERS_NET
    off -> USE_LOGGERS_SYSLOG off) already existed since the ES/Redis onda -
    no new dependency wiring needed here.
  - 1.9.0 (31/07/2026): F8 Onda 8.4.7 - USE_LOGGERS_MEMORY (Layer 2, ON by
    default) gates the new Memory channel (Loggers.Channel.Memory.pas) - a
    ring-buffer retained in-memory, universal baseline channel (no platform
    restriction), no shared template dependency (no formatting - Snapshot
    returns TLoggerEntry directly). Layer 4.3 dependency check added
    (USE_LOGGERS_MEMORY requires USE_LOGGERS), same pattern as
    USE_LOGGERS_CONSOLE.
  - 1.8.0 (31/07/2026): F8 Onda 8.4.6 - USE_LOGGERS_CONSOLE (Layer 2, ON by
    default) gates the new Console/stdout channel (Loggers.Channel.Console.pas)
    - universal baseline channel (no platform restriction, unlike EventLog),
    reuses the Loggers.Format template shared with TextFile. Layer 4.3
    dependency check added (USE_LOGGERS_CONSOLE requires USE_LOGGERS), same
    pattern as USE_LOGGERS_EVENTLOG/USE_LOGGERS_CSV.
  - 1.7.0 (23/07/2026): F8 Onda 8.4.0 - spike real confirmou que o ICS v9.8
    vendorizado (Packages/ICS/Source) NAO compila sob FPC 3.3.1 -
    OverbyteIcsWinsock.pas tem incompatibilidades reais de assinatura PChar/
    PWideChar entre declaracoes externas do Winsock e as suas proprias
    implementacoes wrapper (GetAddrInfo/GetNameInfo/FreeAddrInfo + variantes
    Ics_ prefixadas), independente de um 2o bug separado (fallback "compilador
    desconhecido -> assume Delphi mais recente" que tambem definia
    RTL_NAMESPACES/Winapi.Windows sob FPC). CONTRADIZ a premissa "sem spike de
    risco FPC" do report de decisao (nunca validada contra este build
    especifico). Decisao do owner (23/07): avancar so em Delphi por agora -
    USE_LOGGERS_NET auto-desativado sob FPC (com aviso claro), fica pendencia
    aberta ate correcao (patch local ou update do ICS a montante). dcc32/dcc64
    confirmados OK (spike_ics.dpr, 5 units ICS incl. Http/Smtp/WebSocketCli).
  - 1.6.0 (23/07/2026): F8 Onda 8.4 - cobertura completa dos submodulos v2.3.0 +
    QuickLogger (owner: "necessito de todos os submodulos do v2.3.0 + o
    submodulos do QuickLogger... criando como subonda cada submodulo"; regra de
    merge: "em caso de conflito faca o merge se possivel, senao prevalece o que
    tive melhor logica/semantica"; absorcao de LOGICA/SEMANTICA, nao copia de
    ficheiros). Novos gates: USE_LOGGERS_CSV (local, v2.3.0 Loggers.CSV) +
    USE_LOGGERS_SYSLOG/_REDIS/_ELASTICSEARCH/_INFLUXDB/_GRAYLOG/_LOGSTASH/
    _SENTRY/_SLACK/_TELEGRAM/_TWILIO (providers QuickLogger sem equivalente
    v2.3.0, OFF por omissao - "so por valor confirmado"). XML fica SEM gate -
    nem v2.3.0 (reescreve o ficheiro inteiro por log, anti-padrao) nem
    QuickLogger (sem provider) tem logica que valha a pena herdar; aplicando a
    regra do owner quando nenhum lado e' melhor, mantem-se a decisao de matar
    XML da onda 8.0. Ver plano f8-loggers §"Onda 8.4" para a tabela de merge
    completa (canal a canal, v2.3.0 vs QuickLogger vs decisao final).
  - 1.5.0 (23/07/2026): F8 Onda 8.4 (canais de rede). (a) USE_ICS deixa de ser
    um {$DEFINE} proprio (owner: "como so tem um engine nao necessita desta
    diretiva de compilacao") - ICS e' o UNICO motor de rede de USE_LOGGERS_NET
    (nao ha alternativa entre a qual escolher, ao contrario de USE_ZEOS/
    USE_FIREDAC/USE_UNIDAC/USE_SQLDB), logo nao precisa de toggle proprio -
    mesmo padrao ja aplicado ao nucleo Serialize ("Core areas... have NO gate").
    Comentario desatualizado sobre "spike FPC pendente" corrigido - ja
    confirmado (report f8-loggers-decisao-engine, secao 3) que ICS V9.8
    suporta FPC 3.2.0+/Lazarus, sem spike de risco. (b) Diretivas por submodulo
    (owner: "necessito de diretivas por submodulo... assim como foi feito no
    zipfile") - USE_LOGGERS_NET vira gate mestre + 3 sub-gates por canal
    (USE_LOGGERS_HTTP/_EMAIL/_WEBSOCKET), mesmo padrao USE_ZIPFILE/
    USE_ARCHIVE_<FMT> (cascata "modulo off -> sub-gates off"). USE_LOGGERS_
    EVENTLOG criado como gate irmao independente (API local do Windows, sem
    ICS/rede, nao faz parte da cascata USE_LOGGERS_NET).
  - 1.4.0 (13/07/2026): FASE 5 Onda 9 - USE_RESTREQUEST4D (Layer 2, OFF by
    default; commented out like the Printers engines) gates the optional
    Serialize.Adapter.RESTRequest4D unit (IRequestAdapter over the absorbed
    dataset-serialize). The Serialize core module itself carries NO gate
    (always present, like Commons/Exceptions/Connections).
  - 1.3.0 (12/07/2026): USE_DEPRECATED policy gate (Layer 3, ON by default via
    {$IFNDEF NO_DEPRECATED}). Owner directive 7: deprecated API and v3 coexist in
    the SAME class/interface, gated by USE_DEPRECATED, 100% functional (warning
    only). This EVOLVES the earlier "v3 carries NO compat baggage" stance for the
    QueryBuilder old method names and the TVariableType type (project-wide, F0-F13).
    Build a clean v3 with -DNO_DEPRECATED / -dNO_DEPRECATED. Gate validates BOTH
    states x 4 compilers. See rule providersorm-v3-deprecated-policy_V1.0.0.
  - 1.2.0 (05/07/2026): removed the legacy alias USE_PARAMENTERS -> USE_PARAMETERS
    (B-freeze rule 7: v3 carries NO compat baggage; the v1/v2 typo dies with them).
    v3 code uses USE_PARAMETERS only.
  - 1.1.0 (04/07/2026): USE_ZIPFILE master gate for the ZipFile/Archive module
    (D12, plan F1-A) + per-format sub-gates USE_ARCHIVE_<FMT> (ZIP/TAR/TARGZ/GZIP/
    SEVENZ/CAB/RAR/ARJ/LHA/ISO, all ON). USE_DLL_AUTODOWNLOAD (opt-in) added to
    Layer 3. Layer 4.3: module off -> all format sub-gates off; USE_DLL_AUTODOWNLOAD
    requires USE_ZIPFILE + USE_ARCHIVE_ZIP.
  - 1.0.0 (04/07/2026): v3 refactor (plan 3-B). Linear validation replaces the
    legacy nested ENGINE_COUNT_* blocks (~470 lines). USE_PARAMETERS fixes the
    historical typo USE_PARAMENTERS (legacy alias accepted). USE_ICS collapses
    the 12 legacy network defines (email/http/websocket engines). UniDAC is now
    valid on FPC (historical prohibition removed). Dead defines dropped.
  ============================================================================= *)

{ ============================================================================
  LAYER 1 - DATABASE ENGINE (activate EXACTLY ONE; none defined -> Zeos)
  ============================================================================ }

// ZeosLib - open source, Delphi + FPC (default; vendored in Packages/zeosdbo)
//{$DEFINE USE_ZEOS}

// FireDAC - Embarcadero, Delphi XE7+ ONLY (not available on FPC)
//{$DEFINE USE_FIREDAC}

// UniDAC - Devart, Delphi + FPC/Lazarus (commercial; requires installation)
//{$DEFINE USE_UNIDAC}

// SQLdb - native FCL, FPC/Lazarus ONLY
//{$DEFINE USE_SQLDB}

(*
// No engine defined -> Zeos assumes (vendored default, both compilers)
{$IF NOT DEFINED(USE_ZEOS) AND NOT DEFINED(USE_FIREDAC) AND NOT DEFINED(USE_UNIDAC) AND NOT DEFINED(USE_SQLDB)}
  {$DEFINE USE_UNIDAC} // FPC: ZeosLib is not available on FPC
{$ENDIF}
*)

{ ============================================================================
  LAYER 2 - ECOSYSTEM MODULES (comment out to exclude; stub facade applies)
  ============================================================================ }

{$DEFINE USE_POOLCONNECTIONS}   // Connection pool - main tool of the ecosystem
{$DEFINE USE_DATABASE}          // Database module (metadata, DDL, SchemaSync)
{$DEFINE USE_QUERY_BUILDER}     // Fluent SELECT builder (requires USE_DATABASE)
{$DEFINE USE_QUERY_TRANSFORMER} // Dynamic query transformation (requires USE_QUERY_BUILDER)
{$DEFINE USE_ENTITY_MANAGER}    // RTTI persistence (requires USE_ATTRIBUTES)
{$DEFINE USE_PARAMETERS}        // Configuration parameters (Database/INI/JSON)

// GraphQL module (FASE 13 - greenfield, self-contained src\Modulos\GraphQL\).
// USE_GRAPHQL is the master gate; the two sub-gates select server and/or client
// (cascade in section 4.3: each sub-gate requires the master). ON by default on
// this bancada so the module compiles and is smoke-tested wave by wave.
{$DEFINE USE_GRAPHQL}           // GraphQL master gate (Core: lexer/parser/AST, schema, executor)
{$DEFINE USE_GRAPHQL_SERVER}    //   expose the ORM as a GraphQL server (resolvers, HTTP transport)
{$DEFINE USE_GRAPHQL_CLIENT}    //   consume remote GraphQL APIs (query builder + Indy transport)

{$DEFINE USE_LOGGERS}           // Logging system (async queue + channels)

// Loggers LOCAL channels beyond the baseline (F8 Onda 8.4 - absorved by logic/
// semantics from LoggersORM v2.3.0 + QuickLogger, NOT file copy - see plan
// f8-loggers §"Onda 8.4"). No network/ICS dependency.
{$DEFINE USE_LOGGERS_EVENTLOG}  // Windows Event Log (advapi32; v2.3.0 EventLogs logic, richer than QuickLogger's EventLog provider)
{$DEFINE USE_LOGGERS_CSV}       // CSV channel (v2.3.0 Loggers.CSV logic; QuickLogger has no dedicated provider, custom-format only)
{$DEFINE USE_LOGGERS_CONSOLE}   // Console/stdout channel (universal, reuses the Loggers.Format template shared with TextFile - no v2.3.0/QuickLogger equivalent worth absorbing, new baseline channel)
{$DEFINE USE_LOGGERS_MEMORY}    // Memory channel (ring-buffer in-memory, universal - no v2.3.0/QuickLogger equivalent, new baseline channel, F8 Onda 8.4.7)
// XML: NO gate - v2.3.0's Loggers.XML rewrites the whole file per log entry
// (anti-pattern) and QuickLogger has no provider at all; neither side has
// logic worth merging (owner rule: "prevalece o que tiver melhor logica" -
// when NEITHER does, the onda 8.0 kill decision stands). See plan table.

// Loggers NETWORK channels (F8 Onda 8.4). USE_LOGGERS_NET gates the whole
// category; the USE_LOGGERS_<CHANNEL> below are per-channel sub-gates (no
// "_NET_" infix, owner) - only meaningful when USE_LOGGERS_NET is on - same
// pattern as USE_ZIPFILE/USE_ARCHIVE_<FMT> below. All channels share ICS v9.8
// as transport, which has NO toggle of its own (sole engine, not one of
// several - see Layer 3). Comment out USE_LOGGERS_NET to exclude the entire
// category. Logic absorved from v2.3.0 (Https/Emails/WebSocket/Engines.*)
// merged with QuickLogger provider equivalents where both exist (owner rule:
// merge if possible, else best logic/semantics wins) - see plan f8-loggers
// §"Onda 8.4" for the merge table.
{$DEFINE USE_LOGGERS_NET}       //   Loggers network channels module master gate
{$DEFINE USE_LOGGERS_HTTP}      //   channel: HTTP generico (v2.3.0 Https auth/retry + Engines.HTTP, ICS OverbyteIcsHttpProt) - QuickLogger Rest equivalent
{$DEFINE USE_LOGGERS_EMAIL}     //   channel: Email/SMTP (v2.3.0 Emails aggregation + Engines.Email, ICS OverbyteIcsSmtpProt) - QuickLogger Email equivalent
{$DEFINE USE_LOGGERS_WEBSOCKET} //   channel: WebSocket (v2.3.0 WebSocket BroadcastLog, ICS OverbyteIcsWebSocketCli) - QuickLogger has no WS provider
// QuickLogger-only SaaS/observability providers (no v2.3.0 equivalent) - OFF
// by default, "so por valor confirmado" (plan P1/onda 8.0); each still gets
// its own named gate + sub-onda slot so nothing is silently dropped.
{$DEFINE USE_LOGGERS_SYSLOG}        //   channel: SysLog (RFC5424 - FASE 8)
{$DEFINE USE_LOGGERS_REDIS}         //   channel: Redis (RESP2 PUBLISH/LPUSH via ICS TWSocket - F8 Onda 8.15)
{$DEFINE USE_LOGGERS_ELASTICSEARCH}//   channel: Elasticsearch (bulk index API - F8 Onda 8.16)
//{$DEFINE USE_LOGGERS_INFLUXDB}     //   channel: InfluxDB (line protocol)
//{$DEFINE USE_LOGGERS_GRAYLOG}      //   channel: GrayLog (GELF)
//{$DEFINE USE_LOGGERS_LOGSTASH}     //   channel: Logstash (JSON over TCP/HTTP)
//{$DEFINE USE_LOGGERS_SENTRY}       //   channel: Sentry (error tracking API)
//{$DEFINE USE_LOGGERS_SLACK}        //   channel: Slack (incoming webhook)
//{$DEFINE USE_LOGGERS_TELEGRAM}     //   channel: Telegram (bot API)
//{$DEFINE USE_LOGGERS_TWILIO}       //   channel: Twilio (SMS API)
{$DEFINE USE_PRINTERS}          // Report printing contract (IReportProvider - Printers.Interfaces.pas)
//{$DEFINE USE_FASTREPORT}      // Printers engine: FastReport (commercial)
//{$DEFINE USE_QUICKREPORT}     // Printers engine: QuickReport (commercial)
//{$DEFINE USE_REPORTBUILDER}   // Printers engine: ReportBuilder (commercial)
//{$DEFINE USE_FORTESREPORT}    // Printers engine: FortesReport CE / RLReport (free)
{$DEFINE USE_ACTIVEDIRECTORY}   // LDAP / Active Directory
{$DEFINE USE_ATTRIBUTES}        // RTTI attribute mapping (Delphi XE7+ / FPC 3.3.1+)

// Serialize core (DataSet<->JSON, absorbed dataset-serialize) has NO gate -
// always present, like Commons/Exceptions/Connections. Only the optional
// RESTRequest4Delphi adapter below is gated (3rd-party client lib, not vendored).
//{$DEFINE USE_RESTREQUEST4D}   // Serialize.Adapter.RESTRequest4D (IRequestAdapter); OFF by default - RESTRequest4Delphi not vendored in Packages/

// ZipFile/Archive module (absorbed ZipFileORM: compression, AES, 10 formats).
// USE_ZIPFILE gates the whole module; the USE_ARCHIVE_<FMT> below are per-format
// sub-gates (only meaningful when USE_ZIPFILE is on). Comment out USE_ZIPFILE to
// exclude the entire module (all archive formats and Commons.DllBootstrap).
{$DEFINE USE_ZIPFILE}           //   ZipFile/Archive module master gate
{$DEFINE USE_ARCHIVE_ZIP}       //   format: ZIP  (base of Commons.DllBootstrap)
{$DEFINE USE_ARCHIVE_TAR}       //   format: TAR
{$DEFINE USE_ARCHIVE_TARGZ}     //   format: TAR.GZ
{$DEFINE USE_ARCHIVE_GZIP}      //   format: GZIP
{$DEFINE USE_ARCHIVE_SEVENZ}    //   format: 7-Zip (native objects in Library/)
{$DEFINE USE_ARCHIVE_CAB}       //   format: CAB
{$DEFINE USE_ARCHIVE_RAR}       //   format: RAR via unrar.dll (dll/<plat>/unrar.dll, solta)
{$DEFINE USE_ARCHIVE_ARJ}       //   format: ARJ
{$DEFINE USE_ARCHIVE_LHA}       //   format: LHA
{$DEFINE USE_ARCHIVE_ISO}       //   format: ISO

// Legacy compatibility subsystem (D14/FASE 10 Onda 10.2): Providers.v161.pas
// (+ Modulos/Providers.v161/{Commons,Modulos,Utilities}) is ProvidersORM
// v1.6.1 absorbed VERBATIM (mechanical port only - zero logic/behavior/
// symbol-name changes). It is self-contained (own UniDAC-based TDataModule,
// own Utilities.*/Providers.Common.*/Providers.Module.* units) and is
// SUPERSEDED by the unified TProviders facade - kept only for compatibility,
// accessed directly via `uses Providers.v161;` (src/Main/Providers.v161.pas),
// never through TProviders. OFF by default. EXCLUSIVE mode: when ON, every
// other ecosystem module gate above (Layer 2) is auto-disabled below
// (section 4.3a) - the legacy unit does not participate in / does not need
// the v3 module stack (Connections/Database/Parameters/Loggers/...).
//{$DEFINE USE_PROVIDERS_V161}

{ ============================================================================
  LAYER 3 - INFRASTRUCTURE
  ============================================================================ }

// ICS v9.8 has NO gate of its own (like Serialize core) - it is the SOLE network
// engine for USE_LOGGERS_NET (email/http/websocket), not one of several
// interchangeable options, so there is nothing to toggle between. The module
// gate is USE_LOGGERS_NET (Layer 2) - when it is on, ICS units compile
// unconditionally underneath it.
//{$DEFINE USE_DEVEXPRESS}      // DevExpress controls (view/ forms only, never core)
{$DEFINE USE_DLL_AUTODOWNLOAD} // On-demand DB DLL download (Indy TIdHTTP) + unzip via ZipFile module; opt-in, needs USE_ZIPFILE + USE_ARCHIVE_ZIP
//{$DEFINE USE_VERBOSE_DEFINES} // Emit informational $MESSAGE HINT summaries

// Compatibility / deprecated policy (rule providersorm-v3-deprecated-policy).
// ON by default: deprecated API (old method names, superseded types) compiles
// 100% functional (warning-only), coexisting with v3 in the SAME class/interface.
// Compile with -DNO_DEPRECATED (dcc) / -dNO_DEPRECATED (fpc) for a clean v3 build.
// Scope: whole project (F0-F13). Gate validates BOTH states x 4 compilers.
{$IFNDEF NO_DEPRECATED}
  {$DEFINE USE_DEPRECATED}
{$ENDIF}

// Providers.v200 compatibility bridge (FASE 10, Onda 10.2 Tarefa B) - src/Main/
// Providers.v200.pas translates the v2.0/v2.3 TProviders public API (NewConnection/
// DefaultConnection/Parameter/Logger/ReportBuilder/FastReport/QuickReport/
// FortesReport) into pure delegation calls onto the REAL v3 facade (Providers.pas
// + the Providers.Parameters/Providers.Loggers/Providers.Printers slices) - zero
// own logic besides the DefaultConnection cache mechanic (bridge behaviour, not
// Connections module logic). Dedicated gate (mirrors the per-bridge-gate naming
// pattern of USE_PROVIDERS_V161 above, added concurrently in this same onda by
// Tarefa A) so the consumer can drop the whole compat unit from the build when the
// legacy v2.0/v2.3 surface is not needed. ON by default on this bancada (thin unit,
// no dependencies of its own beyond the v3 facade slices it wraps). Standalone/
// exclusive use: 'uses Providers.v200;' alone, never together with 'uses Providers;'
// in the same consumer (TProviders here is an intentionally homonymous bridge
// class, not the v3 root facade) - same usage philosophy as USE_PROVIDERS_V161,
// but placed in Layer 3 (not Layer 2) and deliberately left OUT of the 4.3a
// EXCLUSIVE-mode UNDEF cascade below: unlike Providers.v161 (fully self-contained,
// does not touch the v3 module stack at all), Providers.v200 DELEGATES onto the
// v3 stack, so when USE_PROVIDERS_V161 disables Parameters/Loggers/Printers
// (Layer 2) the bridge's corresponding members are already excluded by their own
// nested {$IFDEF} - it just degrades to NewConnection/DefaultConnection, no
// conflict to guard against.
{$DEFINE USE_PROVIDERS_V200}

// OpenSSL plugin for the ActiveDirectory module (Synapse LDAPS, port 636).
// Selects which Synapse ssl_openssl* unit ActiveDirectory.Service links.
// Mutually exclusive; only meaningful under USE_ACTIVEDIRECTORY. Default = 3.x.
//   USE_OPENSSL3 -> ssl_openssl3 + ssl_openssl_paths (OpenSSL 3.x, dll/<plat>/.../v3)
//   USE_OPENSSL4 -> ssl_openssl4 + ssl_openssl_paths (CSL fork, OpenSSL 4.x, dll v4)
//   neither      -> ssl_openssl legacy 1.0/1.1 (no ssl_openssl_paths / SetDllDirectory)
{$DEFINE USE_OPENSSL3}
//{$DEFINE USE_OPENSSL4}

{ ============================================================================
  LAYER 4 - LINEAR VALIDATION
  ============================================================================ }

// 4.1 - Platform x engine constraints
{$IF DEFINED(FPC)}
  {$IF DEFINED(USE_FIREDAC)}
    {$ERROR 'ORM.Defines v3: FireDAC is Delphi-only. On FPC use USE_ZEOS (default), USE_UNIDAC or USE_SQLDB.'}
  {$ENDIF}
  // RTTI GetAttributes (TCustomAttribute em Rtti) so existe no FPC 3.3.1+.
  // Abaixo disso, USE_ATTRIBUTES/USE_ENTITY_MANAGER degradam automaticamente.
  {$IF FPC_FULLVERSION < 30301}
    {$IF DEFINED(USE_ATTRIBUTES)}
      {$UNDEF USE_ATTRIBUTES}
      {$MESSAGE WARN 'ORM.Defines v3: FPC < 3.3.1 - USE_ATTRIBUTES desativado (RTTI GetAttributes indisponivel).'}
    {$ENDIF}
    {$IF DEFINED(USE_ENTITY_MANAGER)}
      {$UNDEF USE_ENTITY_MANAGER}
    {$ENDIF}
  {$ENDIF}
{$ELSE}
  {$IF DEFINED(USE_SQLDB)}
    {$MESSAGE FATAL 'ORM.Defines v3: SQLdb is FPC-only. On Delphi use USE_ZEOS, USE_FIREDAC or USE_UNIDAC.'}
  {$ENDIF}
{$ENDIF}

// 4.2-zero - AT LEAST one database engine must be selected.
//
// Sem esta guarda, "nenhum engine" nao dava erro nenhum: o compilador saltava
// os 4 ramos condicionais que contem o CORPO de TConnection.GetTableNamesFromDriver
// (Connections.pas 2824-3080, um ramo por engine), a procedure ficava SEM CORPO,
// o parser continuava em modo declaracao e descarrilava, produzindo 60+ erros
// CRIPTICOS a comecar em "E2023 Function needs result type" (:3098) e a terminar
// em "E2065 Unsatisfied forward" - nenhum deles a apontar para a causa real.
// Custou uma sessao inteira de diagnostico em 01/09/2026. Falhar aqui, alto e
// claro, e' infinitamente melhor. (F15, decisao do owner 01/09.)
//
// NOTA: os defines USE_* deste ficheiro estao comentados DE PROPOSITO desde
// 96a1b396 ("matriz 4-engines FECHADA") - o engine vem da linha de comando
// (-DUSE_ZEOS no Delphi, -dUSE_ZEOS no FPC). Esta guarda NAO muda isso; so
// transforma o esquecimento num erro legivel.
{$IF NOT DEFINED(USE_ZEOS) AND NOT DEFINED(USE_FIREDAC) AND NOT DEFINED(USE_UNIDAC) AND NOT DEFINED(USE_SQLDB)}
  {$IF DEFINED(FPC)}{$ERROR 'ORM.Defines v3: NO database engine selected. Pass exactly one on the command line (-dUSE_ZEOS | -dUSE_UNIDAC | -dUSE_SQLDB) or uncomment one USE_* define above.'}{$ELSE}{$MESSAGE FATAL 'ORM.Defines v3: NO database engine selected. Pass exactly one on the command line (-DUSE_ZEOS | -DUSE_FIREDAC | -DUSE_UNIDAC) or uncomment one USE_* define above.'}{$ENDIF}
{$ENDIF}

// 4.2 - Exactly one database engine (pairwise check, single fatal message)
{$IF DEFINED(USE_ZEOS) AND DEFINED(USE_FIREDAC)}
  {$IF DEFINED(FPC)}{$ERROR 'ORM.Defines v3: multiple engines selected (ZEOS+FIREDAC). Keep exactly one.'}{$ELSE}{$MESSAGE FATAL 'ORM.Defines v3: multiple engines selected (ZEOS+FIREDAC). Keep exactly one.'}{$ENDIF}
{$ENDIF}
{$IF DEFINED(USE_ZEOS) AND DEFINED(USE_UNIDAC)}
  {$IF DEFINED(FPC)}{$ERROR 'ORM.Defines v3: multiple engines selected (ZEOS+UNIDAC). Keep exactly one.'}{$ELSE}{$MESSAGE FATAL 'ORM.Defines v3: multiple engines selected (ZEOS+UNIDAC). Keep exactly one.'}{$ENDIF}
{$ENDIF}
{$IF DEFINED(USE_ZEOS) AND DEFINED(USE_SQLDB)}
  {$IF DEFINED(FPC)}{$ERROR 'ORM.Defines v3: multiple engines selected (ZEOS+SQLDB). Keep exactly one.'}{$ELSE}{$MESSAGE FATAL 'ORM.Defines v3: multiple engines selected (ZEOS+SQLDB). Keep exactly one.'}{$ENDIF}
{$ENDIF}
{$IF DEFINED(USE_FIREDAC) AND DEFINED(USE_UNIDAC)}
  {$IF DEFINED(FPC)}{$ERROR 'ORM.Defines v3: multiple engines selected (FIREDAC+UNIDAC). Keep exactly one.'}{$ELSE}{$MESSAGE FATAL 'ORM.Defines v3: multiple engines selected (FIREDAC+UNIDAC). Keep exactly one.'}{$ENDIF}
{$ENDIF}
{$IF DEFINED(USE_UNIDAC) AND DEFINED(USE_SQLDB)}
  {$IF DEFINED(FPC)}{$ERROR 'ORM.Defines v3: multiple engines selected (UNIDAC+SQLDB). Keep exactly one.'}{$ELSE}{$MESSAGE FATAL 'ORM.Defines v3: multiple engines selected (UNIDAC+SQLDB). Keep exactly one.'}{$ENDIF}
{$ENDIF}

// 4.3a - USE_PROVIDERS_V161 EXCLUSIVE mode: disable every other ecosystem
// module gate (Layer 2) - the legacy unit (D14/FASE 10 Onda 10.2) is
// self-contained and does not use the v3 module stack. Runs first so the
// dependency cascades in 4.3 below see a clean, already-disabled state (no
// duplicate WARN messages). Core areas (Commons/Exceptions/Connections/
// Serialize) have no gate and stay present regardless, as always.
{$IF DEFINED(USE_PROVIDERS_V161)}
  {$UNDEF USE_POOLCONNECTIONS}      {$UNDEF USE_DATABASE}
  {$UNDEF USE_QUERY_BUILDER}        {$UNDEF USE_QUERY_TRANSFORMER}
  {$UNDEF USE_ENTITY_MANAGER}       {$UNDEF USE_PARAMETERS}
  {$UNDEF USE_GRAPHQL}              {$UNDEF USE_GRAPHQL_SERVER}
  {$UNDEF USE_GRAPHQL_CLIENT}       {$UNDEF USE_LOGGERS}
  {$UNDEF USE_LOGGERS_EVENTLOG}     {$UNDEF USE_LOGGERS_CSV}
  {$UNDEF USE_LOGGERS_CONSOLE}      {$UNDEF USE_LOGGERS_MEMORY}
  {$UNDEF USE_LOGGERS_NET}          {$UNDEF USE_LOGGERS_HTTP}
  {$UNDEF USE_LOGGERS_EMAIL}        {$UNDEF USE_LOGGERS_WEBSOCKET}
  {$UNDEF USE_LOGGERS_SYSLOG}       {$UNDEF USE_LOGGERS_REDIS}
  {$UNDEF USE_LOGGERS_ELASTICSEARCH}{$UNDEF USE_LOGGERS_INFLUXDB}
  {$UNDEF USE_LOGGERS_GRAYLOG}      {$UNDEF USE_LOGGERS_LOGSTASH}
  {$UNDEF USE_LOGGERS_SENTRY}       {$UNDEF USE_LOGGERS_SLACK}
  {$UNDEF USE_LOGGERS_TELEGRAM}     {$UNDEF USE_LOGGERS_TWILIO}
  {$UNDEF USE_PRINTERS}             {$UNDEF USE_FASTREPORT}
  {$UNDEF USE_QUICKREPORT}          {$UNDEF USE_REPORTBUILDER}
  {$UNDEF USE_FORTESREPORT}         {$UNDEF USE_ACTIVEDIRECTORY}
  {$UNDEF USE_ATTRIBUTES}           {$UNDEF USE_ZIPFILE}
  {$MESSAGE WARN 'ORM.Defines v3: USE_PROVIDERS_V161 is EXCLUSIVE - all other ecosystem module gates (Layer 2) disabled (legacy compat mode).'}
{$ENDIF}

// 4.3 - Module dependencies (auto-disable with warning; never fatal)
{$IF DEFINED(USE_QUERY_BUILDER) AND NOT DEFINED(USE_DATABASE)}
  {$UNDEF USE_QUERY_BUILDER}
  {$MESSAGE WARN 'ORM.Defines v3: USE_QUERY_BUILDER requires USE_DATABASE - disabled.'}
{$ENDIF}
{$IF DEFINED(USE_QUERY_TRANSFORMER) AND NOT DEFINED(USE_QUERY_BUILDER)}
  {$UNDEF USE_QUERY_TRANSFORMER}
  {$MESSAGE WARN 'ORM.Defines v3: USE_QUERY_TRANSFORMER requires USE_QUERY_BUILDER - disabled.'}
{$ENDIF}
{$IF DEFINED(USE_ENTITY_MANAGER) AND NOT DEFINED(USE_ATTRIBUTES)}
  {$UNDEF USE_ENTITY_MANAGER}
  {$MESSAGE WARN 'ORM.Defines v3: USE_ENTITY_MANAGER requires USE_ATTRIBUTES - disabled.'}
{$ENDIF}
{$IF DEFINED(USE_LOGGERS_NET) AND NOT DEFINED(USE_LOGGERS)}
  {$UNDEF USE_LOGGERS_NET}
  {$MESSAGE WARN 'ORM.Defines v3: USE_LOGGERS_NET requires USE_LOGGERS - disabled.'}
{$ENDIF}
// F8 Onda 8.4.0 (23/07/2026): the vendored ICS did NOT compile under FPC 3.3.1
// -> USE_LOGGERS_NET auto-disabled under FPC (Delphi-only). bug-712/726.
//
// UPDATE (27/07/2026, owner): the ICS in Packages/ICS was CUSTOMIZED for FPC (fork;
// Source/Helpers/OverbyteIcsFpc{IOUtils,StrUtils}.pas - the missing FPC shim units).
// After adding Source/Helpers to fpc32.opts/fpc64.opts, the ICS ENGINE (OverbyteIcs
// WSocket/HttpProt/SmtpProt/SslBase) compiles AND links clean under FPC 3.3.1 win32
// AND win64 - proven by tests/test_ics_fpc.dpr (EXIT=0 both). So the ORIGINAL blocker
// (bug-712: the engine did not compile) is GONE.
//
// UPDATE (27/07/2026, Onda 8.4.6-fpc): (1) the ICS engine compiles under FPC (see above);
// (2) the network CHANNEL UNITS were ported to cross-compiler and now compile clean under
// FPC - Loggers.Channel.Http/WebSocket gate System.Hash/System.NetEncoding (Delphi) vs
// OverbyteIcsSha1 + the base64 unit (FPC) for the RFC6455 handshake/Basic auth, and gate
// System.Generics.Collections + qualify SyncObjs (bug-718); Email was already FPC-ready.
//
// bug-872 RESOLVED (31/07): the two-zlibs clash (ICS zlib vs ZipFile CAB zlib) was fixed by
// prefixing the PROJECT ZipFile's OWN zlib objects (src/Modulos/ZipFile/Library/fpc-*) with
// `zfz_` via objcopy --redefine-syms (64 symbols/arch), so they no longer collide with the
// ICS's own zlib (canonical C:\...\Packages\ICS-Fork\Source\zobj1321, kept verbatim). Only the
// PROJECT ZipFile was touched (the ZipFileORM package stays intact). USE_LOGGERS_NET now
// compiles+links under FPC (Delphi was never affected). Former Delphi-only gate removed.
// Loggers network module off -> all per-channel sub-gates off (keeps state
// clean, same pattern as ZipFile/USE_ARCHIVE_<FMT> below).
{$IF NOT DEFINED(USE_LOGGERS_NET)}
  {$UNDEF USE_LOGGERS_HTTP}         {$UNDEF USE_LOGGERS_EMAIL}
  {$UNDEF USE_LOGGERS_WEBSOCKET}    {$UNDEF USE_LOGGERS_SYSLOG}
  {$UNDEF USE_LOGGERS_REDIS}        {$UNDEF USE_LOGGERS_ELASTICSEARCH}
  {$UNDEF USE_LOGGERS_INFLUXDB}     {$UNDEF USE_LOGGERS_GRAYLOG}
  {$UNDEF USE_LOGGERS_LOGSTASH}     {$UNDEF USE_LOGGERS_SENTRY}
  {$UNDEF USE_LOGGERS_SLACK}        {$UNDEF USE_LOGGERS_TELEGRAM}
  {$UNDEF USE_LOGGERS_TWILIO}
{$ENDIF}
{$IF DEFINED(USE_LOGGERS_EVENTLOG) AND NOT DEFINED(USE_LOGGERS)}
  {$UNDEF USE_LOGGERS_EVENTLOG}
  {$MESSAGE WARN 'ORM.Defines v3: USE_LOGGERS_EVENTLOG requires USE_LOGGERS - disabled.'}
{$ENDIF}
{$IF DEFINED(USE_LOGGERS_CSV) AND NOT DEFINED(USE_LOGGERS)}
  {$UNDEF USE_LOGGERS_CSV}
  {$MESSAGE WARN 'ORM.Defines v3: USE_LOGGERS_CSV requires USE_LOGGERS - disabled.'}
{$ENDIF}
{$IF DEFINED(USE_LOGGERS_CONSOLE) AND NOT DEFINED(USE_LOGGERS)}
  {$UNDEF USE_LOGGERS_CONSOLE}
  {$MESSAGE WARN 'ORM.Defines v3: USE_LOGGERS_CONSOLE requires USE_LOGGERS - disabled.'}
{$ENDIF}
{$IF DEFINED(USE_LOGGERS_MEMORY) AND NOT DEFINED(USE_LOGGERS)}
  {$UNDEF USE_LOGGERS_MEMORY}
  {$MESSAGE WARN 'ORM.Defines v3: USE_LOGGERS_MEMORY requires USE_LOGGERS - disabled.'}
{$ENDIF}
// GraphQL (FASE 13): server/client sub-gates require the master USE_GRAPHQL.
{$IF DEFINED(USE_GRAPHQL_SERVER) AND NOT DEFINED(USE_GRAPHQL)}
  {$UNDEF USE_GRAPHQL_SERVER}
  {$MESSAGE WARN 'ORM.Defines v3: USE_GRAPHQL_SERVER requires USE_GRAPHQL - disabled.'}
{$ENDIF}
{$IF DEFINED(USE_GRAPHQL_CLIENT) AND NOT DEFINED(USE_GRAPHQL)}
  {$UNDEF USE_GRAPHQL_CLIENT}
  {$MESSAGE WARN 'ORM.Defines v3: USE_GRAPHQL_CLIENT requires USE_GRAPHQL - disabled.'}
{$ENDIF}
// ICS V9.8/Lazarus supports FPC 3.2.0+ (HTTP/SMTP/SSL-TLS via OpenSSL) - the
// "ICS is Delphi-only" premise from the original F8 plan was wrong/outdated
// (corrected in providersorm-v3-f8-loggers-decisao-engine_v1.0.md §3); no FPC
// spike/auto-disable needed here.

// AD module internal gate: the AD units carry {$IFDEF USE_LDAP} (ADORM standalone
// origin); bridge it from the public module gate USE_ACTIVEDIRECTORY. Temporary -
// the units are renamed to check USE_ACTIVEDIRECTORY directly in wave 3.3.
{$IF DEFINED(USE_ACTIVEDIRECTORY) AND NOT DEFINED(USE_LDAP)}
  {$DEFINE USE_LDAP}
{$ENDIF}

// AD OpenSSL plugin: mutually exclusive; assume 3.x when AD is on and none chosen
{$IF DEFINED(USE_OPENSSL3) AND DEFINED(USE_OPENSSL4)}
  {$IF DEFINED(FPC)}{$ERROR 'ORM.Defines v3: USE_OPENSSL3 and USE_OPENSSL4 are mutually exclusive. Keep exactly one.'}{$ELSE}{$MESSAGE FATAL 'ORM.Defines v3: USE_OPENSSL3 and USE_OPENSSL4 are mutually exclusive. Keep exactly one.'}{$ENDIF}
{$ENDIF}
{$IF DEFINED(USE_ACTIVEDIRECTORY) AND NOT DEFINED(USE_OPENSSL3) AND NOT DEFINED(USE_OPENSSL4)}
  {$DEFINE USE_OPENSSL3}
  {$MESSAGE WARN 'ORM.Defines v3: USE_ACTIVEDIRECTORY without OpenSSL choice - assuming USE_OPENSSL3 (OpenSSL 3.x).'}
{$ENDIF}

// ZipFile module off -> all archive format sub-gates off (keeps state clean)
{$IF NOT DEFINED(USE_ZIPFILE)}
  {$UNDEF USE_ARCHIVE_ZIP}  {$UNDEF USE_ARCHIVE_TAR}   {$UNDEF USE_ARCHIVE_TARGZ}
  {$UNDEF USE_ARCHIVE_GZIP} {$UNDEF USE_ARCHIVE_SEVENZ}{$UNDEF USE_ARCHIVE_CAB}
  {$UNDEF USE_ARCHIVE_RAR}  {$UNDEF USE_ARCHIVE_ARJ}   {$UNDEF USE_ARCHIVE_LHA}
  {$UNDEF USE_ARCHIVE_ISO}
{$ENDIF}
// Commons.DllBootstrap needs the ZipFile module (ZIP format) for the unzip step
{$IF DEFINED(USE_DLL_AUTODOWNLOAD) AND (NOT DEFINED(USE_ZIPFILE) OR NOT DEFINED(USE_ARCHIVE_ZIP))}
  {$UNDEF USE_DLL_AUTODOWNLOAD}
  {$MESSAGE WARN 'ORM.Defines v3: USE_DLL_AUTODOWNLOAD requires USE_ZIPFILE + USE_ARCHIVE_ZIP - disabled.'}
{$ENDIF}

// 4.4 - Verbose summary (opt-in)
{$IF DEFINED(USE_VERBOSE_DEFINES)}
  {$IF DEFINED(USE_ZEOS)}
    {$MESSAGE HINT 'ProvidersORM v3: database engine = ZeosLib.'}
  {$ELSEIF DEFINED(USE_FIREDAC)}
    {$MESSAGE HINT 'ProvidersORM v3: database engine = FireDAC.'}
  {$ELSEIF DEFINED(USE_UNIDAC)}
    {$MESSAGE HINT 'ProvidersORM v3: database engine = UniDAC.'}
  {$ELSEIF DEFINED(USE_SQLDB)}
    {$MESSAGE HINT 'ProvidersORM v3: database engine = SQLdb.'}
  {$ENDIF}
{$ENDIF}

(* ========================== END ORM.Defines.inc v3 ========================= *)
