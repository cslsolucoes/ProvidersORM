{ =============================================================================
  Providers.Attributers - slice da fachada TProviders para o RTTI attribute
  mapping (modulo Attributers, F6)

  Ponto de entrada unico do RTTI attribute mapping para o ecossistema: o
  consumidor faz 'uses Providers.Attributers;' e obtem os parsers/mappers de
  Database/Parameters/Loggers sem ter de conhecer a arvore interna
  ('src/Attributers/Attributers.<Modulo>[.Interfaces]').

  COLISAO REAL DE NOMES (achado por leitura directa, nao assumido) - RESOLVIDA
  NESTA SLICE por alias com prefixo de dominio: Attributers.Database.Interfaces
  E Attributers.Parameters.Interfaces declaram, cada um no seu proprio ficheiro,
  uma interface 'IAttributeParser' e uma 'IAttributeMapper' - MESMO NOME
  LITERAL, GUIDs diferentes, semantica diferente (Database: Classe -> ITable;
  Parameters: Classe -> TParameterList). Sem alias, 'uses
  Attributers.Database.Interfaces, Attributers.Parameters.Interfaces;' no
  mesmo ficheiro da E2004 Identifier redeclared. Resolvido com o padrao ja
  usado no resto da fachada (Providers.Database re-exporta 'IDialect', nao
  'ISQLDialect' cru importado sem contexto) - aqui o contexto e o MODULO que
  o parser/mapper mapeia: 'IDatabaseAttributeParser'/'IDatabaseAttributeMapper'
  (para ITable) vs 'IParametersAttributeParser'/'IParametersAttributeMapper'
  (para TParameterList). O 3o modulo (Loggers, Onda 6.3) NAO colide - ja
  nasceu com nome proprio 'ILoggerAttributeParser' (decisao do owner na F6,
  "ILogger e' nucleo fan-out, nao ha IAttributeMapper com sentido aqui" - sem
  par Mapper) - re-exportado por uniformidade (o consumidor so' precisa de
  'uses Providers.Attributers;', nunca de 'uses Attributers.Loggers.Interfaces').
  Esta e' uma decisao de nomenclatura em simbolos NOVOS (a fachada nao existia
  antes desta onda) - nao e' rename de simbolo publico com consumidores
  existentes, por isso NAO dispara o workflow de mapeamento de consumidores/
  AskUserQuestion da skill governance-refactoring-compatibility-policy (secao
  "When NOT to use": "Adicao de novos simbolos sem remover ou renomear os
  existentes (greenfield puro) -> nenhuma skill necessaria"; skill consultada
  antes de decidir, conforme pedido).

  ASSIMETRIA REAL ENTRE OS 3 MODULOS (achado por leitura directa de
  Attributers.Database.pas / Attributers.Parameters.pas / Attributers.Loggers.pas):
  - Database: SO' singletons globais 'AttributeParser'/'AttributeMapper'
    (var, tipo IAttributeParser/IAttributeMapper), criados na 'initialization'
    da unit - as classes TAttributeParser/TAttributeMapper sao privadas
    (declaradas dentro do 'implementation', sem 'class function New' publico).
    NewDatabaseParser/NewDatabaseMapper devolvem o singleton (delegacao 1:1,
    nao fabricam instancia nova a cada chamada - documentado, nao escondido).
  - Parameters: TEM 'class function New' publico em AMBAS as classes
    (TAttributeParser.New: IAttributeParser / TAttributeMapper.New:
    IAttributeMapper) E TAMBEM os singletons globais equivalentes. Esta slice
    usa a factory 'New' (fabrica instancia nova por chamada - mais consistente
    com o padrao NewX de toda a fachada), nao o singleton.
  - Loggers: SO' 'class function New' publico em TLoggerAttributeParser (+
    singleton global equivalente); sem par Mapper (ver nota acima). Esta
    slice usa a factory 'New'.

  ActiveDirectory/Connections FORA de ambito nesta onda (achado, nao decisao
  arbitraria): 'Attributers.ActiveDirectory.pas' (LdapAttribute/
  LdapObjectClass/LdapSidAttribute + entidades TAdUser/TAdGroup/TAdComputer/
  TAdOU + TActiveDirectoryMapper<T> generico) e 'Attributers.Connections.pas'
  (ConnectionAttribute) NAO declaram nenhum par IAttributeParser/IAttributeMapper
  nem factory 'New' - sao classes de atributo RTTI (TCustomAttribute) puras,
  decoradas directamente pelas classes do consumidor (ex.: '[LdapAttribute(...)]
  Login: string;' ou '[Connection(...)] TMinhaClasse = class'), sem um
  parser/mapper por tras para "New" delegar. Nao ha contrato para esta slice
  agregar (o padrao de toda a fachada e' 'delega 1:1 numa factory existente',
  nao ha factory aqui) - o consumidor que quiser decorar uma classe com estes
  atributos continua a fazer 'uses Attributers.ActiveDirectory;' /
  'uses Attributers.Connections;' directamente, ja' cobertos por
  Providers.ActiveDirectory (Onda 10.1-a2, o parser fica dentro do proprio
  modulo AD) e Providers.Connections (Onda 10.1-a) respectivamente.

  Gated por USE_ATTRIBUTES. Cada bloco (Database/Parameters/Loggers) fica
  TAMBEM aninhado sob o USE_* do modulo que mapeia (USE_DATABASE/
  USE_PARAMETERS/USE_LOGGERS respectivamente) - mesmo padrao de
  ProvidersV3.dpr/.lpr, onde Attributers.Database/.Parameters/.Loggers so' sao
  ligados dentro do bloco USE_DATABASE/USE_PARAMETERS/USE_LOGGERS, aninhado em
  USE_ATTRIBUTES (nao o inverso). Zero logica propria.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.3.1 (Database) / 2.0.0 (Parameters) / 1.10.0 (Loggers) - RTTI mapeia os 3
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           11/08/2026

  Changelog (file):
  - 1.0.0 (11/08/2026): criacao (FASE 10, Onda 10.1-b - Attributers fechado na
    F6 03/08, ainda por commitar mas ja disponivel para leitura) - slice de
    fachada Providers.Attributers. Resolve a colisao real IAttributeParser/
    IAttributeMapper (Database vs Parameters) por alias com prefixo de
    dominio (IDatabaseAttributeParser/IDatabaseAttributeMapper vs
    IParametersAttributeParser/IParametersAttributeMapper); re-exporta
    ILoggerAttributeParser (sem colisao, sem par Mapper); TFieldMappingInfo/
    TFieldMappingInfoArray (retorno de GetFieldMappings, Database). Excluidos
    (achado, documentado acima): Attributers.ActiveDirectory/.Connections -
    atributos RTTI puros sem parser/mapper/factory por tras, ja cobertos
    pelas slices Providers.ActiveDirectory/Providers.Connections.
    governance-refactoring-compatibility-policy consultada antes de decidir
    os aliases - dispensada (simbolos novos, greenfield, sem consumidores a
    mapear).
  ============================================================================= }

unit Providers.Attributers;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../ORM.Defines.inc}

{$IFDEF USE_ATTRIBUTES}

uses
{$IF DEFINED(USE_DATABASE)}
  Attributers.Database.Types,       // TFieldMappingInfo/TFieldMappingInfoArray (retorno de GetFieldMappings)
  Attributers.Database.Interfaces,  // IAttributeParser/IAttributeMapper (Database - re-exportados com prefixo)
  Attributers.Database,             // singletons AttributeParser/AttributeMapper (Database - unica factory publica)
{$ENDIF}
{$IF DEFINED(USE_PARAMETERS)}
  Attributers.Parameters.Interfaces, // IAttributeParser/IAttributeMapper (Parameters - re-exportados com prefixo)
  Attributers.Parameters,            // TAttributeParser.New / TAttributeMapper.New (Parameters)
{$ENDIF}
{$IF DEFINED(USE_LOGGERS)}
  Attributers.Loggers.Interfaces,   // ILoggerAttributeParser (sem colisao - ja nasceu com nome proprio)
  Attributers.Loggers,              // TLoggerAttributeParser.New (Loggers)
{$ENDIF}
  Commons.Types // TStringArray (assinaturas de GetParameterProperties/GetLoggerProperties)
  ;

type
{$IF DEFINED(USE_DATABASE)}
  { --- Re-export com prefixo de dominio (colide com Parameters sem o prefixo) --- }
  IDatabaseAttributeParser = Attributers.Database.Interfaces.IAttributeParser;
  IDatabaseAttributeMapper = Attributers.Database.Interfaces.IAttributeMapper;
  TFieldMappingInfo        = Attributers.Database.Types.TFieldMappingInfo;
  TFieldMappingInfoArray   = Attributers.Database.Types.TFieldMappingInfoArray;
{$ENDIF}

{$IF DEFINED(USE_PARAMETERS)}
  { --- Re-export com prefixo de dominio (colide com Database sem o prefixo) --- }
  IParametersAttributeParser = Attributers.Parameters.Interfaces.IAttributeParser;
  IParametersAttributeMapper = Attributers.Parameters.Interfaces.IAttributeMapper;
{$ENDIF}

{$IF DEFINED(USE_LOGGERS)}
  { --- Re-export (sem colisao - nome ja proprio na origem) --- }
  ILoggerAttributeParser = Attributers.Loggers.Interfaces.ILoggerAttributeParser;
{$ENDIF}

  { Slice da fachada TProviders para o RTTI attribute mapping (modulo
    Attributers, F6). Cada bloco fica aninhado sob o USE_* do modulo que
    mapeia - ver nota no cabecalho do ficheiro. }
  TProvidersAttributers = class
  public
{$IF DEFINED(USE_DATABASE)}
    { Database (Classe -> ITable, [Table]/[Field]/[PrimaryKey]). O modulo SO'
      expoe os singletons globais AttributeParser/AttributeMapper (sem
      'class function New' publico - ver nota no cabecalho) - estas factories
      devolvem o singleton, delegacao 1:1, nao fabricam instancia nova. }
    class function NewDatabaseParser: IDatabaseAttributeParser; static;
    class function NewDatabaseMapper: IDatabaseAttributeMapper; static;
{$ENDIF}

{$IF DEFINED(USE_PARAMETERS)}
    { Parameters (Classe -> TParameterList, [Parameter]/[ParameterKey]/...).
      Delega em TAttributeParser.New/TAttributeMapper.New (Attributers.
      Parameters.pas - fabrica instancia nova por chamada). }
    class function NewParametersParser: IParametersAttributeParser; static;
    class function NewParametersMapper: IParametersAttributeMapper; static;
{$ENDIF}

{$IF DEFINED(USE_LOGGERS)}
    { Loggers (Classe -> ILogger, [Logger]/[LoggerLevel]/[LoggerCategory] -
      so' nivel de classe + introspeccao de propriedade; sem Mapper, ver nota
      no cabecalho). Delega em TLoggerAttributeParser.New (Attributers.
      Loggers.pas). }
    class function NewLoggerParser: ILoggerAttributeParser; static;
{$ENDIF}
  end;

{$ENDIF USE_ATTRIBUTES}

implementation

{$IFDEF USE_ATTRIBUTES}

{ TProvidersAttributers }

{$IF DEFINED(USE_DATABASE)}
class function TProvidersAttributers.NewDatabaseParser: IDatabaseAttributeParser;
begin
  Result := Attributers.Database.AttributeParser;
end;

class function TProvidersAttributers.NewDatabaseMapper: IDatabaseAttributeMapper;
begin
  Result := Attributers.Database.AttributeMapper;
end;
{$ENDIF}

{$IF DEFINED(USE_PARAMETERS)}
class function TProvidersAttributers.NewParametersParser: IParametersAttributeParser;
begin
  Result := Attributers.Parameters.TAttributeParser.New;
end;

class function TProvidersAttributers.NewParametersMapper: IParametersAttributeMapper;
begin
  Result := Attributers.Parameters.TAttributeMapper.New;
end;
{$ENDIF}

{$IF DEFINED(USE_LOGGERS)}
class function TProvidersAttributers.NewLoggerParser: ILoggerAttributeParser;
begin
  Result := Attributers.Loggers.TLoggerAttributeParser.New;
end;
{$ENDIF}

{$ENDIF USE_ATTRIBUTES}

end.
