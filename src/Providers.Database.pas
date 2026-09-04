{ =============================================================================
  Providers.Database - slice da fachada TProviders para o modulo Database

  Ponto de entrada unico do modulo para o ecossistema: o consumidor faz
  'uses Providers.Database;' e obtem as factories + os contratos sem ter de
  conhecer a arvore interna (Database / Databases / Databases.Interfaces /
  Database.Synchronize / Database.QueryBuilder / Database.Dialect /
  Database.CatalogReader / Database.EntityManager). Espelha o padrao dos
  demais modulos (ex.: Providers.Parameters -> TProvidersParameters).

  Este slice ANTECIPA a camada Main/: a FASE 10 (fachada unificada, Onda
  10.1-a) apenas liga TProviders.New<Peca> a TProvidersDatabase aqui definido
  - sem reescrever logica. Re-exporta por alias os contratos publicos do
  modulo (o consumidor nao precisa de 'uses Databases.Interfaces' nem de
  'uses Database.CatalogReader' so para nomear os tipos).

  Gated por USE_DATABASE. Zero logica propria: delega em TDatabase/TDatabases
  (Fatia B-e), TSynchronize (ex-SchemaSync, Onda 5.5/5.5-B), TQueryBuilder
  (nucleo, Onda 6-f), TDialect (Onda 5.4/7) e TCatalogReader (catalogo
  normalizado). TEntityManager (RTTI persistence) fica aninhado sob
  USE_ENTITY_MANAGER dentro deste USE_DATABASE, espelhando o aninhamento ja
  usado em Database.pas/ProvidersV3.dpr/.lpr.

  DESVIO DE PLANO (achado, ver ficheiro Providers.pas para o registo formal):
  o plano F10 (v2.3.0, Onda 10.1-a) previa 'NewMetadata'/'IMetadata' (ex-
  IMetadataProvider) como uma das factories desta slice. Por leitura directa
  de Databases.Interfaces.pas (22 contratos) e de Database.Version.pas
  (changelog 3.4.1, nota expressa "o dissolvido foi o IMetadata publico, nao
  o ICatalogReader") confirma-se que esse contrato NAO EXISTE no modulo -
  foi dissolvido na propagacao F5 (26/07/2026), nao renomeado. O ICatalogReader
  (Database.CatalogReader.pas) e o SSOT real de metadados/catalogo hoje - por
  isso esta slice expoe NewCatalogReader (nome real) em vez de fabricar um
  NewMetadata/IMetadata que nao tem classe/factory por tras.

  ADICAO NAO PEDIDA EXPLICITAMENTE PELO PLANO ROOT (completude da slice):
  o plano root (Providers.pas) so pede Synchronize/QueryBuilder/EntityManager/
  Dialect para o TProviders raiz desta onda. Esta SLICE, para nao ficar capada
  face ao padrao do molde Providers.Parameters (que re-exporta TODOS os
  contratos publicos relevantes do modulo, nao so os que o TProviders raiz
  liga nesta onda), tambem expoe NewDatabase/NewDatabases (TDatabase.New/
  TDatabases.New) e NewCatalogReader (TCatalogReader.New) - conveniencias
  aditivas, sem qualquer logica propria (delegacao 1:1).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.4.1
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.0.0 (03/08/2026): criacao (FASE 10, Onda 10.1-a - ambito parcial
    Connections/PoolConnections/Database/Parameters, decisao do owner) - slice
    de fachada Providers.Database (re-export de IDatabase/IDatabases/
    ISynchronize/IQueryBuilder/IDialect/ICatalogReader/IEntityManager +
    factory TProvidersDatabase que delega em TDatabase.New/TDatabases.New/
    TSynchronize.New/TQueryBuilder.New/TDialect.ForConnection|ForDatabaseType/
    TCatalogReader.New/TEntityManager.New). Desvio de plano documentado acima
    (NewMetadata/IMetadata nao existe - dissolvido na F5, nao renomeado). A
    ligacao TProviders.New<Peca> fecha na mesma onda (Main/Providers.pas).
  ============================================================================= }

unit Providers.Database;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_DATABASE}

uses
  Commons.Types,          // TDatabaseTypes, TFirebirdVersion (assinaturas de NewDialect)
  Connections.Interfaces, // IConnection (parametro das factories connection-bound)
  Databases.Interfaces,   // IDatabase/IDatabases/IDialect/ISynchronize/IQueryBuilder/IEntityManager (contratos re-exportados)
  Database.CatalogReader, // ICatalogReader + TCatalogReader (catalogo normalizado)
  Database,                // TDatabase (factory do modulo, Fatia B-e)
  Databases,                // TDatabases (factory do modulo, Fatia B-e)
  Database.Synchronize,   // TSynchronize (ex-SchemaSync, Onda 5.5/5.5-B)
  Database.QueryBuilder,  // TQueryBuilder (nucleo, Onda 6-f)
  Database.Dialect        // TDialect (base + factories ForConnection/ForDatabaseType, Onda 5.4/7)
{$IFDEF USE_ENTITY_MANAGER}
  , Database.EntityManager // TEntityManager (RTTI persistence, requer USE_ATTRIBUTES)
{$ENDIF}
  ;

type
  { --- Re-export dos contratos do modulo (o consumidor nomeia-os via este slice) --- }
  IDatabase      = Databases.Interfaces.IDatabase;
  IDatabases     = Databases.Interfaces.IDatabases;
  IDialect       = Databases.Interfaces.IDialect;
  ISynchronize   = Databases.Interfaces.ISynchronize;
  IQueryBuilder  = Databases.Interfaces.IQueryBuilder;
  ICatalogReader = Database.CatalogReader.ICatalogReader;
{$IFDEF USE_ENTITY_MANAGER}
  IEntityManager = Databases.Interfaces.IEntityManager;
{$ENDIF}

  { Slice da fachada TProviders para o modulo Database. A F10 liga
    TProviders.New<Peca> a estes membros - sem duplicar logica. }
  TProvidersDatabase = class
  public
    { TDatabase (Fatia B-e). Adicao de completude da slice - ver nota no
      cabecalho do ficheiro. }
    class function NewDatabase: IDatabase; overload; static;
    class function NewDatabase(const AConnection: IConnection): IDatabase; overload; static;

    { TDatabases (Fatia B-e). Adicao de completude da slice. }
    class function NewDatabases: IDatabases; static;

    { TSynchronize - ex-SchemaSync (Onda 5.5/5.5-B). Nomenclatura FINAL
      pos-PROPAGACAO F5 (Synchronize/ISynchronize/NewSynchronize). }
    class function NewSynchronize(const AConnection: IConnection): ISynchronize; static;

    { TQueryBuilder - nucleo sob USE_DATABASE (independente de
      USE_QUERY_BUILDER, que gateia so a entrada de fachada Database.
      QueryBuilder(AConnection); ver Database.pas, comentario A1). }
    class function NewQueryBuilder: IQueryBuilder; static;

    { TDialect - 2 factories (Onda 5.4/7). Nomenclatura FINAL pos-PROPAGACAO
      F5 (IDialect/NewDialect, nao ISQLDialect). }
    class function NewDialect(const AConnection: IConnection): IDialect; overload; static;
    class function NewDialect(const ADatabaseType: TDatabaseTypes;
      const AFirebirdVersion: TFirebirdVersion = fb50): IDialect; overload; static;

    { TCatalogReader - ICatalogReader (catalogo normalizado). SUBSTITUI o
      NewMetadata/IMetadata previsto no plano root, que nao existe no modulo
      (dissolvido na propagacao F5) - ver nota no cabecalho do ficheiro.
      Adicao de completude da slice. }
    class function NewCatalogReader: ICatalogReader; overload; static;
    class function NewCatalogReader(const AConnection: IConnection): ICatalogReader; overload; static;

{$IFDEF USE_ENTITY_MANAGER}
    { TEntityManager - RTTI persistence (requer USE_ATTRIBUTES). }
    class function NewEntityManager: IEntityManager; static;
{$ENDIF}
  end;

{$ENDIF USE_DATABASE}

implementation

{$IFDEF USE_DATABASE}

{ TProvidersDatabase }

class function TProvidersDatabase.NewDatabase: IDatabase;
begin
  Result := Database.TDatabase.New;
end;

class function TProvidersDatabase.NewDatabase(const AConnection: IConnection): IDatabase;
begin
  Result := Database.TDatabase.New(AConnection);
end;

class function TProvidersDatabase.NewDatabases: IDatabases;
begin
  Result := Databases.TDatabases.New;
end;

class function TProvidersDatabase.NewSynchronize(const AConnection: IConnection): ISynchronize;
begin
  Result := Database.Synchronize.TSynchronize.New(AConnection);
end;

class function TProvidersDatabase.NewQueryBuilder: IQueryBuilder;
begin
  Result := Database.QueryBuilder.TQueryBuilder.New;
end;

class function TProvidersDatabase.NewDialect(const AConnection: IConnection): IDialect;
begin
  Result := Database.Dialect.TDialect.ForConnection(AConnection);
end;

class function TProvidersDatabase.NewDialect(const ADatabaseType: TDatabaseTypes;
  const AFirebirdVersion: TFirebirdVersion): IDialect;
begin
  Result := Database.Dialect.TDialect.ForDatabaseType(ADatabaseType, AFirebirdVersion);
end;

class function TProvidersDatabase.NewCatalogReader: ICatalogReader;
begin
  Result := Database.CatalogReader.TCatalogReader.New;
end;

class function TProvidersDatabase.NewCatalogReader(const AConnection: IConnection): ICatalogReader;
begin
  Result := Database.CatalogReader.TCatalogReader.New(AConnection);
end;

{$IFDEF USE_ENTITY_MANAGER}
class function TProvidersDatabase.NewEntityManager: IEntityManager;
begin
  Result := Database.EntityManager.TEntityManager.New;
end;
{$ENDIF}

{$ENDIF USE_DATABASE}

end.
