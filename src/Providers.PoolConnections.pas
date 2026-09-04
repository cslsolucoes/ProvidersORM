{ =============================================================================
  Providers.PoolConnections - slice da fachada TProviders para o modulo
  PoolConnections (Broker Elastico)

  Ponto de entrada unico do modulo para o ecossistema: o consumidor faz
  'uses Providers.PoolConnections;' e obtem a factory + o contrato sem ter de
  conhecer a arvore interna (PoolConnections / PoolConnections.Interfaces /
  Commons.PoolConnections.Types). Espelha o padrao dos demais modulos (ex.:
  Providers.Parameters -> TProvidersParameters).

  Este slice ANTECIPA a camada Main/: a FASE 10 (fachada unificada, Onda
  10.1-a) apenas liga TProviders.NewPoolConnections a TProvidersPoolConnections
  aqui definido - sem reescrever logica. Re-exporta por alias o contrato
  publico (o consumidor nao precisa de 'uses PoolConnections.Interfaces').

  Gated por USE_POOLCONNECTIONS. Zero logica propria: delega em TPoolBroker
  (factory, Onda 4.3 Etapa B).

  Nota de fronteira (IPoolBroker NAO re-exportado): TPoolBroker implementa
  tanto IPoolConnections (API publica, aquisicao/devolucao/eventos) quanto
  IPoolBroker (Commons.PoolConnections.Types) - este ultimo e o contrato
  MINIMO de roteamento (ExecuteRequest/BeginSticky/EndSticky/ProxyReleased)
  consumido internamente pelo TConnectionProxy (modulo Connections, DIP) e
  devolvido apenas via o proxy fisico - nao e uma capacidade que o consumidor
  do ecossistema invoque diretamente (New devolve so IPoolConnections, como
  o proprio TPoolBroker.New confirma). Por isso este slice re-exporta so
  IPoolConnections; IPoolBroker fica onde esta (Commons.PoolConnections.Types),
  peca de fronteira cross-modulo, nao de fachada.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  2.1.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.0.0 (03/08/2026): criacao (FASE 10, Onda 10.1-a - ambito parcial
    Connections/PoolConnections/Database/Parameters, decisao do owner) - slice
    de fachada Providers.PoolConnections (re-export de IPoolConnections +
    factory TProvidersPoolConnections que delega em TPoolBroker.New). A
    ligacao TProviders.NewPoolConnections fecha na mesma onda
    (Main/Providers.pas).
  ============================================================================= }

unit Providers.PoolConnections;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_POOLCONNECTIONS}

uses
  PoolConnections.Interfaces, // IPoolConnections (contrato re-exportado)
  PoolConnections;            // TPoolBroker (factory do modulo, Onda 4.3 Etapa B)

type
  { --- Re-export do contrato do modulo (o consumidor nomeia-o via este slice) --- }
  IPoolConnections = PoolConnections.Interfaces.IPoolConnections;

  { Slice da fachada TProviders para o modulo PoolConnections. A F10 liga
    TProviders.NewPoolConnections a este membro - sem duplicar logica. }
  TProvidersPoolConnections = class
  public
    { Factory (delega em TPoolBroker.New - Onda 4.3 Etapa B). }
    class function New: IPoolConnections; static;
  end;

{$ENDIF USE_POOLCONNECTIONS}

implementation

{$IFDEF USE_POOLCONNECTIONS}

{ TProvidersPoolConnections }

class function TProvidersPoolConnections.New: IPoolConnections;
begin
  Result := PoolConnections.TPoolBroker.New;
end;

{$ENDIF USE_POOLCONNECTIONS}

end.
