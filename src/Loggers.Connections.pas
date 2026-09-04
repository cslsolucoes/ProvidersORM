{ =============================================================================
  Loggers.Connections - adaptador de perfil de conexao do canal Database

  Espelha Parameters.Connections.pas (TParametersConnectionLoader): resolve o
  perfil de conexao identificado pelo titulo 'loggers' (grupo completo de
  chaves de conexao: database_type/host/port/username/password/database/
  schema/dll_path/dll_name/server_name) via IParameters, devolvendo-o como
  TConnectionData. NAO regista nada no seam 400017 (IConnection.FromConfig) -
  chama o loader diretamente, sem depender de estado global de registo.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.10.0
  FileVersion:    1.2.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           22/07/2026

  Changelog (file):
  - (sync 27/07/2026) ModuleVersion sincronizado para 1.10.0 - F8 Onda 8.9 (hardening pos-auditoria); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.10.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.9.0 - F8 Onda 8.4.5 acrescenta o canal TLoggerChannelWebSocket (8o canal baseline, 3o real sobre ICS, resolve P2); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.9.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.8.0 - F8 Onda 8.4.4 acrescenta o canal TLoggerChannelEmail (7o canal baseline, 2o real sobre ICS); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.8.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.7.0 - F8 Onda 8.4.3 acrescenta o canal TLoggerChannelHttp (6o canal baseline, 1o real sobre ICS); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.7.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.6.0 - F8 Onda 8.4.2 acrescenta o canal TLoggerChannelCSV (5o canal baseline); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.6.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.5.0 - F8 Onda 8.4.1 acrescenta o canal TLoggerChannelEventLog (Windows Event Log, 4o canal baseline); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.5.0.
  - 1.2.0 (22/07/2026): Finalização da onda 8.3, itens 1+2 (owner: "resolva
    todos e documente nos planos") - EnsureParametersSeeded ganha lock unit-level
    (GSeedLock: TCriticalSection, initialization/finalization) - corrige race
    condition real: check-then-act (Exists->Insert) sem sincronização podia
    colidir na constraint UNIQUE da tabela parameters quando duas threads
    chamavam TLoggers.New() quase ao mesmo tempo no arranque (TLoggers.New não
    é singleton, onda 8.1); a exceção não tratada propagava até ao construtor
    do canal Database. + flag GSeeded: Boolean (mesma secção crítica) - evita
    repetir os ~46 SELECT/Exists a cada TLoggers.New() (o núcleo e o canal
    Database chamavam ambos EnsureParametersSeeded); só a 1ª chamada do
    processo semeia de facto, as seguintes são no-op. Achados da auditoria
    adversarial F8 8.1-8.3 (ver f8-loggers changelog 2.93) e do plano de
    finalização (changelog 2.8.7) - bug-698.
  - (sync 22/07/2026) ModuleVersion sincronizado para 1.4.0 - Loggers.Database.pas removeu a dependencia de IPoolConnections/TPoolBroker (conexao propria, direta), decisao de arquitectura do owner ('o Loggers via consumir sem pool direto o Connections'); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.4.0.
  - 1.1.0 (22/07/2026): + EnsureParametersSeeded (bootstrap idempotente dos 48
    parâmetros, extraído de Loggers.pas.BootstrapParameters para partilha) -
    ResolveConnectionData chama-o primeiro, para o canal Database conseguir
    resolver o perfil 'loggers' mesmo quando instanciado ANTES do bootstrap
    do núcleo (bug encontrado no smoke da onda 8.3: EDatabaseDialectException
    "banco None" porque database_type ainda não tinha sido semeado).
  - 1.0.0 (22/07/2026): criação — FASE 8 Onda 8.3.
  ============================================================================= }

unit Loggers.Connections;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_LOGGERS}
{$IFDEF USE_PARAMETERS}

uses
  Commons.Types;  // TConnectionData

type
  TLoggersConnectionResolver = class
  public
    { Bootstrap idempotente dos ~46 parâmetros do módulo Loggers (mesma tabela
      LOGGERS_PARAM_DEFAULTS que Loggers.pas.BootstrapParameters semeia) - só
      insere as chaves que faltarem. Chamado internamente por
      ResolveConnectionData (um canal instanciado ANTES de TLoggerImpl.Create
      não pode assumir que o núcleo já semeou o perfil 'loggers'); também
      reaproveitado por Loggers.pas para não duplicar o loop de seed. }
    class procedure EnsureParametersSeeded; static;

    { Resolve o perfil 'loggers' (titulo na tabela parameters) em TConnectionData.
      Devolve False se nenhuma chave do perfil foi encontrada (perfil vazio). }
    class function ResolveConnectionData(out AData: TConnectionData): Boolean; static;
  end;

{$ENDIF USE_PARAMETERS}
{$ENDIF USE_LOGGERS}

implementation

{$IFDEF USE_LOGGERS}
{$IFDEF USE_PARAMETERS}

uses
{$IF DEFINED(FPC)}
  SysUtils, SyncObjs,
{$ELSE}
  System.SysUtils, System.SyncObjs,
{$ENDIF}
  Commons.Loggers.Consts,    // LOGGERS_TITULO_PROFILE ('loggers')
  Connections.Interfaces,    // IConnectionConfigureLoader
  Parameters.Interfaces,     // IParameters
  Parameters,                // TParameters.New
  Parameters.Connections;    // TParametersConnectionLoader (reaproveitado - mesmo mecanismo do seam 400017)

var
  { Serializa EnsureParametersSeeded entre chamadas concorrentes (TLoggers.New nao
    e singleton - onda 8.1 - logo duas instancias podem chamar isto quase ao mesmo
    tempo no arranque, antes de qualquer parametro existir). Sem este lock, o
    check-then-act (Exists->Insert) pode colidir na constraint UNIQUE da tabela
    parameters e propagar excepcao ate ao construtor do canal Database. }
  GSeedLock: TCriticalSection;
  { Evita repetir os ~46 SELECT/Exists de verificacao a cada TLoggers.New() - o
    nucleo (Loggers.pas.BootstrapParameters) e o canal Database (via
    ResolveConnectionData) chamam ambos EnsureParametersSeeded; apos a 1a
    semeadura bem sucedida do processo, as chamadas seguintes sao no-op. }
  GSeeded: Boolean;

class procedure TLoggersConnectionResolver.EnsureParametersSeeded;
var
  I: Integer;
  LParams: IParameters;
  LSource: IParametersDatabase;
  LParam: TParameter;
  LTitulo: string;
begin
  GSeedLock.Acquire;
  try
    LParams := TParameters.New;
    LTitulo := '';
    LSource := LParams.Database;
    LSource.AutoCreateTable(True);
    { bug-1162 (RESOLVIDO 25/08): GSeeded sozinho e' um cache de PROCESSO que
      confia cegamente em "ja semeei uma vez, nunca mais preciso verificar" -
      correto em producao (ninguem apaga config.db a meio do processo), mas
      falso quando um teste (Tests.Loggers.Memory/Json/Csv/TextFile.pas, todos
      seguindo o padrao de smoke_loggers_channels.dpr) faz DeleteFile(config.db)
      NO MEIO do mesmo processo para garantir determinismo entre corridas - o
      ficheiro (e a tabela 'parameters' + todas as chaves seedeadas, incl.
      'database_type' do perfil 'loggers') desaparece, mas GSeeded continua
      True, entao o loop de seed abaixo nunca torna a correr - ResolveConnectionData
      le um perfil 'loggers' vazio, DatabaseType fica dtNone, e qualquer operacao
      de dialecto (TSynchronize.Sync) lanca EDatabaseDialectException("Dialecto
      nao suportado para o banco None"). Fix: um canario barato (TableExists,
      1 query) confirma que o store REALMENTE sobrevive antes de confiar no
      cache - se a tabela sumiu, reseed integral, independente de GSeeded. }
    if GSeeded and LSource.TableExists then
      Exit;
    LSource.EnsureTable;  { cria a tabela 'parameters' se não existir (idempotente). }
    for I := Low(LOGGERS_PARAM_DEFAULTS) to High(LOGGERS_PARAM_DEFAULTS) do
    begin
      if LOGGERS_PARAM_DEFAULTS[I].Titulo <> LTitulo then
      begin
        LTitulo := LOGGERS_PARAM_DEFAULTS[I].Titulo;
        LSource := LParams.Database;
        LSource.Title(LTitulo);
      end;
      if not LSource.Exists(LOGGERS_PARAM_DEFAULTS[I].Chave) then
      begin
        LParam := TParameter.Create;
        try
          LParam.Titulo := LOGGERS_PARAM_DEFAULTS[I].Titulo;
          LParam.Name := LOGGERS_PARAM_DEFAULTS[I].Chave;
          LParam.Value := LOGGERS_PARAM_DEFAULTS[I].Valor;
          LParam.Description := LOGGERS_PARAM_DEFAULTS[I].Descricao;
          LParam.Ativo := True;
          { P0/A7 (auditoria F8): GSeedLock so serializa intra-processo; numa race
            cross-process outra instancia pode semear a mesma chave entre o Exists
            (acima) e este Insert -> viola a constraint UNIQUE. Nao e erro se a
            chave ficou la (resultado desejado); so re-propaga falha real. }
          try
            LSource.Insert(LParam);
          except
            on Exception do
              if not LSource.Exists(LOGGERS_PARAM_DEFAULTS[I].Chave) then
                raise;
          end;
        finally
          LParam.Free;
        end;
      end;
    end;
    GSeeded := True;
  finally
    GSeedLock.Release;
  end;
end;

class function TLoggersConnectionResolver.ResolveConnectionData(out AData: TConnectionData): Boolean;
var
  LParams: IParameters;
  LLoader: IConnectionConfigureLoader;
begin
  EnsureParametersSeeded;  { garante que o perfil 'loggers' existe mesmo se este canal for resolvido antes do bootstrap do núcleo. }
  LParams := TParameters.New;
  LLoader := TParametersConnectionLoader.New(LParams);
  Result := LLoader.LoadConfigure(LOGGERS_TITULO_PROFILE, AData);
end;

{$ENDIF USE_PARAMETERS}
{$ENDIF USE_LOGGERS}

{$IFDEF USE_LOGGERS}
{$IFDEF USE_PARAMETERS}
initialization
  GSeedLock := TCriticalSection.Create;
  GSeeded := False;

finalization
  GSeedLock.Free;
{$ENDIF USE_PARAMETERS}
{$ENDIF USE_LOGGERS}

end.
