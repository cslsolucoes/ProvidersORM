{ =============================================================================
  Providers.Interfaces - Re-export unificado das interfaces publicas do
  ProvidersORM v3 (ambito desta onda: Connections/PoolConnections/Database/
  Parameters)

  Finalidade: unit unica de TIPOS para consumo externo, sem as factories (para
  factories use a unit Providers). Agrega, por type-alias explicito (uses nao
  e transitivo em Pascal - cada slice ja re-exporta os seus proprios
  contratos, ver Providers.Connections/.PoolConnections/.Database/
  .Parameters), os contratos dos 4 modulos ACTIVOS na Onda 10.1-a (decisao do
  owner, 03/08 - ambito parcial). Sem esta unit, um consumidor teria de fazer
  'uses Providers.Connections, Providers.PoolConnections, Providers.Database,
  Providers.Parameters;' so para nomear tipos - aqui fica UMA unica clausula.

  Uso tipico (tipos apenas - para factories use 'uses Providers;'):
    uses Providers.Interfaces;
    var LConn: IConnection; LDb: IDatabase; LParams: IParameters;

  Mapa de ativacao (define -> bloco re-exportado):
    (sempre)             IConnection (Connections e core, sem gate)
    USE_POOLCONNECTIONS  IPoolConnections
    USE_DATABASE         IDatabase, IDatabases, IDialect, ISynchronize,
                         IQueryBuilder, ICatalogReader
    USE_DATABASE + USE_ENTITY_MANAGER
                         IEntityManager
    USE_PARAMETERS       IParameters, IParametersSource/Database/IniFile/
                         JsonObject, TParameter(List), TParameterSource,
                         TParameterConfig, TParameterSourceArray

  AMBITO PARCIAL (Onda 10.1-a, decisao do owner 03/08): os 6 modulos
  CONGELADOS (Loggers/Printers/Attributers/GraphQL/ActiveDirectory/ZipFile)
  ficam FORA desta unit - nao ha placeholder/gate vazio para eles; entram
  quando a Onda 10.1-b descongelar (mesmo tratamento dado aos slices
  Providers.<Modulo> correspondentes).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.0.0 (03/08/2026): criacao (FASE 10, Onda 10.1-a - ambito parcial
    Connections/PoolConnections/Database/Parameters, decisao do owner) -
    re-export agregado dos 4 slices activos desta onda. Estilo inspirado no
    Providers.Interfaces v2.3.0 (SSOT em E:\Dropbox\CSL\ProvidersORM), mas
    reduzido ao ambito parcial e com a nomenclatura FINAL pos-PROPAGACAO F5
    (nao ha ISQLDialect/IMetadataProvider aqui - ver desvio documentado em
    Providers.Database.pas).
  ============================================================================= }

unit Providers.Interfaces;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../ORM.Defines.inc}

uses
  Providers.Connections // IConnection - core, sem gate USE_* (sempre presente)
{$IFDEF USE_POOLCONNECTIONS}
  , Providers.PoolConnections // IPoolConnections
{$ENDIF}
{$IFDEF USE_DATABASE}
  , Providers.Database // IDatabase/IDatabases/IDialect/ISynchronize/IQueryBuilder/ICatalogReader(/IEntityManager)
{$ENDIF}
{$IFDEF USE_PARAMETERS}
  , Providers.Parameters // IParameters* + TParameter*
{$ENDIF}
  ;

type
  { --- Connections (core, sem gate) --- }
  IConnection = Providers.Connections.IConnection;

{$IFDEF USE_POOLCONNECTIONS}
  { --- PoolConnections (Broker Elastico) --- }
  IPoolConnections = Providers.PoolConnections.IPoolConnections;
{$ENDIF}

{$IFDEF USE_DATABASE}
  { --- Database --- }
  IDatabase      = Providers.Database.IDatabase;
  IDatabases     = Providers.Database.IDatabases;
  IDialect       = Providers.Database.IDialect;
  ISynchronize   = Providers.Database.ISynchronize;
  IQueryBuilder  = Providers.Database.IQueryBuilder;
  ICatalogReader = Providers.Database.ICatalogReader;
  {$IFDEF USE_ENTITY_MANAGER}
  IEntityManager = Providers.Database.IEntityManager;
  {$ENDIF}
{$ENDIF}

{$IFDEF USE_PARAMETERS}
  { --- Parameters --- }
  IParameters           = Providers.Parameters.IParameters;
  IParametersSource     = Providers.Parameters.IParametersSource;
  IParametersDatabase   = Providers.Parameters.IParametersDatabase;
  IParametersIniFile    = Providers.Parameters.IParametersIniFile;
  IParametersJsonObject = Providers.Parameters.IParametersJsonObject;
  TParameter            = Providers.Parameters.TParameter;
  TParameterList        = Providers.Parameters.TParameterList;
  TParameterSource      = Providers.Parameters.TParameterSource;
  TParameterConfig      = Providers.Parameters.TParameterConfig;
  TParameterSourceArray = Providers.Parameters.TParameterSourceArray;
{$ENDIF}

implementation

end.
