{ =============================================================================
  Commons.Dependencies - Guard de compile-time das dependencias externas

  SSOT unico que ABORTA o build (via MESSAGE FATAL no Delphi / ERROR no
  FPC) quando uma biblioteca de terceiros usada pelo ProvidersORM esta numa
  versao INFERIOR a minima exigida por esta major (v3.0.0). Cada guard e
  activado apenas pelo respectivo define de engine/modulo, de modo que so a
  dependencia realmente compilada e verificada.

  Mecanica por lib (levantada dos headers reais em 23/07/2026):
  - Delphi     : CompilerVersion (simbolo magico)            -> >= 36 (RAD 12 Athens)
  - FPC        : FPC_FULLVERSION (macro inteira)             -> >= 30202 (3.2.2)
  - Zeos       : const ZEOS_MAJOR/MINOR/SUB_VERSION (ZClasses) -> >= 8.0.0
  - UniDAC     : simbolo-sentinela TSQLAnywhereUniProvider (fork CSL) -> 10.3.0B
  - FireDAC    : sem const propria -> proxy CompilerProxy (RAD, so Delphi) -> 12
  - Indy       : const gsIdVersionMajor/Minor/Release (IdGlobal) -> >= 10.6.3
  - Synapse    : define SYNAPSE_V42_1_OR_HIGHER (Synapse.Version.inc) -> 42.1.0
  - SQLdb      : segue a versao do FPC (coberto pelo guard FPC)
  - ICS        : ainda nao consumido (rede F8 onda 8.4) -> placeholder inactivo

  Placement: Commons (dado transversal). Compilada cedo pelo .dpr/.lpr para
  falhar o build antes de qualquer outra unit tocar a lib desactualizada.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  FileVersion:    1.2.0
  Author:         Claiton de Souza Linhares
  Date:           01/08/2026

  Changelog (file):
  - 1.2.0 (01/08/2026): comentario da mecanica por lib (linha ~12) corrigido -
    ainda dizia "FPC_FULLVERSION >= 30301 (3.3.1)", desatualizado desde a
    1.1.0 (o guard FPC_FULLVERSION < 30202 e o MIN_FPC_FULLVERSION=30202
    ja estavam corretos; so o comentario documental ficou para tras). Owner
    (01/08): "corrigir o FPC_FULLVERSION em todo o projeto para 30202 como
    minima versao" - esclarecido que isto cobre APENAS o piso MINIMO
    suportado do compilador (este guard); os checks de FUNCIONALIDADE
    especifica (Commons.FPC.inc: FPC_USE_GENERICS_COLLECTIONS/
    FPC_RTTI_GETATTRIBUTES; ORM.Defines.inc:255, degradacao automatica de
    USE_ATTRIBUTES/USE_ENTITY_MANAGER) permanecem em >= 30301 DE PROPOSITO -
    confirmado por teste isolado (RttiTest.lpr) que TRttiType.GetAttributes
    genuinamente NAO existe no FPC 3.2.2. Owner confirmou: "RTTI/Generics so
    sera habilitado quando a versao for 30301 - isso ja fica registado como
    limitacoes do projeto". NAO alterar esses 2 ficheiros para 30202.
  - 1.1.0 (01/08/2026): piso minimo do FPC baixado de 3.3.1 (30301) para 3.2.2
    (30202) - owner: "corrija para ser 3.2.2+, aplique e teste". Motivado pela
    correcao do bug-1074 (Databases.Interfaces.pas, FPC 3.2.2 Internal error
    2012101001 ao especializar IIdentityMap<TObject> forward antes da decl
    completa - ver .workspace/patches/providersorm-database-identitymap-bug1074-fpc322-ice/). Guard
    dos outros compiladores/libs inalterado (Delphi >= RAD 12 Athens/CV 36;
    Zeos/UniDAC/FireDAC/Indy/Synapse mantem os pisos anteriores).
  - 1.0.1 (23/07/2026): guard Synapse elevado ao piso exacto 42.1.0 via include
    de Synapse.Version.inc (define SYNAPSE_V42_1_OR_HIGHER), apos corrigir o
    cabecalho do proprio .inc do fork (delimitador de bloco chaveado migrado
    para parenteses-asterisco) que o tornava nao-includivel. Removido o
    sentinela TLDAPAttributeValue e o uses ldapsend.
  - 1.0.0 (23/07/2026): versao inicial - guard de versao minima das
    dependencias externas (Delphi/FPC, Zeos, UniDAC fork, FireDAC, Indy,
    Synapse fork, SQLdb; ICS preparado/inactivo).
  ============================================================================= }

unit Commons.Dependencies;

{$IF DEFINED(FPC)}
  {$MODE DELPHI} // Ensures DEFINED()/Declared() work as in Delphi
{$ENDIF}

interface

{$I ORM.Defines.inc}

uses
  {$IFDEF USE_ZEOS} ZClasses, {$ENDIF}                    // ZEOS_*_VERSION consts
  {$IFDEF USE_UNIDAC} SQLAnywhereUniProvider, {$ENDIF}    // TSQLAnywhereUniProvider (fork CSL)
  {$IFDEF USE_DLL_AUTODOWNLOAD} IdGlobal, {$ENDIF}        // gsIdVersion* consts
  SysUtils;

// =============================================================================
// 1) Compiladores (base do produto v3.0.0)
// =============================================================================
{$IFDEF FPC}
  {$IF FPC_FULLVERSION < 30202}
    {$ERROR 'ProvidersORM v3.0.0: FPC 3.2.2+ exigido (FPC_FULLVERSION >= 30202).'}
  {$ENDIF}
{$ELSE}
  {$IF CompilerVersion < 36.0}
    {$MESSAGE FATAL 'ProvidersORM v3.0.0: RAD Studio 12 Athens+ exigido (CompilerVersion >= 36).'}
  {$ENDIF}
{$ENDIF}

// =============================================================================
// 2) Zeos (USE_ZEOS) - const numerica em ZClasses.pas
// =============================================================================
{$IFDEF USE_ZEOS}
  {$IF (ZEOS_MAJOR_VERSION * 10000 + ZEOS_MINOR_VERSION * 100 + ZEOS_SUB_VERSION) < 80000}
    {$IFDEF FPC}
      {$ERROR 'ProvidersORM v3.0.0: Zeos 8.0.0+ exigido. Actualize Packages/zeosdbo.'}
    {$ELSE}
      {$MESSAGE FATAL 'ProvidersORM v3.0.0: Zeos 8.0.0+ exigido. Actualize Packages/zeosdbo.'}
    {$ENDIF}
  {$ENDIF}
{$ENDIF}

// =============================================================================
// 3) UniDAC (USE_UNIDAC) - fork CSL: sem const numerica, usa simbolo-sentinela.
//    TSQLAnywhereUniProvider so existe a partir do fork 10.3.0B (dbcapi nativo).
// =============================================================================
{$IFDEF USE_UNIDAC}
  {$IF NOT DECLARED(TSQLAnywhereUniProvider)}
    {$IFDEF FPC}
      {$ERROR 'ProvidersORM v3.0.0: UniDAC fork CSL 10.3.0B+ exigido (TSQLAnywhereUniProvider ausente - Packages/UniDAC desactualizado ou UniDAC vanilla).'}
    {$ELSE}
      {$MESSAGE FATAL 'ProvidersORM v3.0.0: UniDAC fork CSL 10.3.0B+ exigido (TSQLAnywhereUniProvider ausente - Packages/UniDAC desactualizado ou UniDAC vanilla).'}
    {$ENDIF}
  {$ENDIF}
{$ENDIF}

// =============================================================================
// 4) FireDAC (USE_FIREDAC) - sem const propria; acompanha o RAD Studio. So Delphi.
// =============================================================================
{$IFDEF USE_FIREDAC}
  {$IFDEF FPC}
    {$ERROR 'ProvidersORM v3.0.0: FireDAC nao existe em FPC - use USE_ZEOS/USE_UNIDAC/USE_SQLDB.'}
  {$ELSE}
    {$IF CompilerVersion < 36.0}
      {$MESSAGE FATAL 'ProvidersORM v3.0.0: FireDAC exige RAD Studio 12 Athens+ (CompilerVersion >= 36).'}
    {$ENDIF}
  {$ENDIF}
{$ENDIF}

// =============================================================================
// 5) Indy (USE_DLL_AUTODOWNLOAD) - const numerica gsIdVersion* em IdGlobal.
//    10.6.3 = 10*10000 + 6*100 + 3 = 100603.
// =============================================================================
{$IFDEF USE_DLL_AUTODOWNLOAD}
  {$IF DECLARED(gsIdVersionMajor)}
    {$IF (gsIdVersionMajor * 10000 + gsIdVersionMinor * 100 + gsIdVersionRelease) < 100603}
      {$IFDEF FPC}
        {$ERROR 'ProvidersORM v3.0.0: Indy 10.6.3+ exigido. Actualize Packages/indylaz (FPC) ou Indy (Delphi).'}
      {$ELSE}
        {$MESSAGE FATAL 'ProvidersORM v3.0.0: Indy 10.6.3+ exigido. Actualize Packages/indylaz (FPC) ou Indy (Delphi).'}
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}
{$ENDIF}

// =============================================================================
// 6) Synapse (USE_ACTIVEDIRECTORY) - fork CSL: define cumulativo pre-computado
//    em Synapse.Version.inc (SYNAPSE_V42_1_OR_HIGHER). O .inc do fork foi
//    corrigido (cabecalho { } -> parenteses-asterisco) para ser includivel.
// =============================================================================
{$IFDEF USE_ACTIVEDIRECTORY}
  {$I Synapse.Version.inc}
  {$IFNDEF SYNAPSE_V42_1_OR_HIGHER}
    {$IFDEF FPC}
      {$ERROR 'ProvidersORM v3.0.0: Synapse (fork CSL) 42.1.0+ exigido. Ver Packages/Synapse/VERSION.md.'}
    {$ELSE}
      {$MESSAGE FATAL 'ProvidersORM v3.0.0: Synapse (fork CSL) 42.1.0+ exigido. Ver Packages/Synapse/VERSION.md.'}
    {$ENDIF}
  {$ENDIF}
{$ENDIF}

// =============================================================================
// 7) ICS (rede) - PLACEHOLDER inactivo. ICS ainda nao e consumido por nenhuma
//    unit (canais de rede dos Loggers = F8 onda 8.4, pendente). Quando a onda
//    8.4 adicionar 'uses OverbyteIcsWSocket' sob USE_LOGGERS_NET, activar aqui
//    um guard sobre a const de versao do ICS (OverbyteIcsWSocket: WSocketVersion
//    ou o define de OverbyteIcsDefs.inc). Minimo alvo do plano: ICS v9.8.
// =============================================================================
// {$IFDEF USE_LOGGERS_NET}
//   ... guard ICS >= 9.8 (activar na onda 8.4) ...
// {$ENDIF}

const
  { ---------------------------------------------------------------------------
    Manifesto de versoes minimas exigidas (SSOT documental legivel).
    Mantenha sincronizado com os guards acima ao subir um piso.
    --------------------------------------------------------------------------- }
  MIN_DELPHI_COMPILERVERSION = 29.0;                  // RAD Studio 12 Athens
  MIN_FPC_FULLVERSION        = 30202;                 // FPC 3.2.2
  MIN_ZEOS_VERSION           = '8.0.0';
  MIN_UNIDAC_VERSION         = '10.3.0B (fork CSL)';
  MIN_FIREDAC_RAD_VERSION    = '13.1 Florence (Delphi)';
  MIN_INDY_VERSION           = '10.6.3';
  MIN_SYNAPSE_VERSION        = '42.1.0 (fork CSL)';
  MIN_SQLDB_VERSION          = '3.2.2 (segue o FPC)';
  MIN_ICS_VERSION            = '9.8 (placeholder - onda 8.4)';

implementation

end.
