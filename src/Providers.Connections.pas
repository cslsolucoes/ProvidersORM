{ =============================================================================
  Providers.Connections - slice da fachada TProviders para o modulo Connections

  Ponto de entrada unico do modulo para o ecossistema: o consumidor faz
  'uses Providers.Connections;' e obtem a factory + o contrato sem ter de
  conhecer a arvore interna (Connections / Connections.Interfaces). Espelha o
  padrao dos demais modulos (ex.: Providers.Parameters -> TProvidersParameters).

  Este slice ANTECIPA a camada Main/: a FASE 10 (fachada unificada, Onda
  10.1-a) apenas liga TProviders.NewConnection a TProvidersConnections aqui
  definido - sem reescrever logica. Re-exporta por alias o contrato publico
  (o consumidor nao precisa de 'uses Connections.Interfaces').

  SEM gate USE_* proprio - Connections e modulo CORE (regra do ORM.Defines.inc,
  "Core areas... have NO gate: always present"; ver bloco "FASE 4 Onda 4.1 -
  Connections (core, sem gate)" em ProvidersV3.dpr/.lpr). Este slice acompanha
  o mesmo regime: sempre presente, sem diretivas IFDEF/ENDIF a envolver o
  conteudo (ao contrario do molde Providers.Parameters, gated USE_PARAMETERS).
  Por nao ter nenhum USE_* a resolver dentro desta unit, tambem nao inclui
  o include ORM.Defines.inc (nada aqui depende de nenhuma diretiva).

  Zero logica propria: delega em TConnection (factory, Onda 4.1).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.22
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.0.0 (03/08/2026): criacao (FASE 10, Onda 10.1-a - ambito parcial
    Connections/PoolConnections/Database/Parameters, decisao do owner) - slice
    de fachada Providers.Connections (re-export de IConnection + factory
    TProvidersConnections que delega em TConnection.New). A ligacao
    TProviders.NewConnection fecha na mesma onda (Main/Providers.pas).
  ============================================================================= }

unit Providers.Connections;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Connections.Interfaces, // IConnection (contrato re-exportado)
  Connections;            // TConnection (factory do modulo, Onda 4.1)

type
  { --- Re-export do contrato do modulo (o consumidor nomeia-o via este slice) --- }
  IConnection = Connections.Interfaces.IConnection;

  { Slice da fachada TProviders para o modulo Connections. A F10 liga
    TProviders.NewConnection a este membro - sem duplicar logica. Connections
    e core (sem gate USE_*) - esta unit acompanha o mesmo regime (sempre
    presente). }
  TProvidersConnections = class
  public
    { Factory (delega em TConnection.New - Onda 4.1). }
    class function New: IConnection; static;
  end;

implementation

{ TProvidersConnections }

class function TProvidersConnections.New: IConnection;
begin
  Result := Connections.TConnection.New;
end;

end.
