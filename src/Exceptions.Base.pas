{ =============================================================================
  Exceptions.Base - Excecao raiz do ecossistema + tabela canonica de codigos

  EExceptionBase e a RAIZ de TODA excecao de dominio do ProvidersORM (prerrogativa
  perene 5: nenhuma excecao de dominio herda de Exception cru). Cada modulo define
  a sua E<Modulo>Exception herdando daqui e usa a sua faixa de codigos MMXXXX.

  --- TABELA CANONICA DE CODIGOS (v3, esquema MMXXXX de 6 digitos) ---
  MM = 2 digitos de modulo ; XXXX = 4 digitos de codigo dentro do modulo.
  A coluna `code` da tabela messages e INTEGER (cabe ate 999999).

    MM  Modulo/Servico            Base       Faixa
    30  SQL (transversal)         300000     300001..309999
    40  Connection                400000     400001..409999
    41  Database (core)           410000     410001..419999
    44  Serialize              440000     440001..449999
    45  PoolConnections           450000     450001..459999
    50  Parameters                500000     500001..509999
    60  Attributers               600000     600001..609999
    70  Database.EntityManager    700000     700001..709999
    80  Database.QueryBuilder     800000     800001..809999
    90  Database.IdentityMap      900000     900001..909999
    91  Database.UnitOfWork       910000     910001..919999
    92  Database.TypeDatabase     920000     920001..929999
    93  Loggers                   930000     930001..939999
    95  ActiveDirectory           950000     950001..959999
    96  Printers                  960000     960001..969999
    97  GraphQL                   970000     970001..979999
    99  ZipFile/Archive           990000     990001..999999

  Nota de regularizacao (v3): a referencia v2.x misturava 5 e 6 digitos
  (Connection 40001-40019; Database submodulos 60000-92000; Parameters/Loggers/
  Printers ja em 6 digitos). O v3 fixa 6 digitos MMXXXX para todos, preservando
  as atribuicoes de modulo reconheciveis. Connection: 4000N -> 40000N.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  FileVersion:    1.2.0
  Author:         Claiton de Souza Linhares
  Date:           01/09/2026

  Changelog (file):
  - 1.2.0 (01/09/2026): F15 Onda 15.1 - reservada a faixa 97 (GraphQL,
    970001..979999) na tabela canonica. ERR_GRAPHQL_BASE=970000 permanece em
    Modulos/GraphQL/GraphQL.Exceptions.pas (modulo F13 congelado; NAO duplicado
    aqui para evitar shadowing de simbolo). EDatabaseException mantido por offset
    (decisao do owner: sem classes dedicadas 90/91/92). Sem alteracao de codigo
    executavel - so a tabela-comentario de faixas e o cabecalho.
  - 1.1.0 (13/07/2026): FASE 5 Onda 9 - registada a faixa 44 (Serialize,
    ERR_SERIALIZE_BASE=440000) na tabela canonica + const list, para a
    absorcao TOTAL do dataset-serialize (ver Exceptions.Serialize).
  - 1.0.0 (05/07/2026): v3 FASE 2 Onda 2.1 - migrado de ProvidersORM v2.2.0
    (Modulos/Exceptions/Exceptions.Base). Codigos Connection regularizados ao
    esquema MMXXXX (40000X); tabela canonica de faixas fixada; ERR_<MOD>_BASE
    de 6 digitos. Hierarquia: todo modulo herda de EExceptionBase.
  ============================================================================= }
unit Exceptions.Base;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../ORM.Defines.inc}

uses
{$IF DEFINED(FPC)}
  SysUtils;
{$ELSE}
  System.SysUtils;
{$ENDIF}

type
  { Raiz de todas as excecoes de dominio do ecossistema. Guarda o ErrorCode
    (faixa MMXXXX) - PROMOVIDO para a base (05/07) para eliminar a repeticao do
    padrao FErrorCode em cada modulo: AD, Connection, etc. reusam este. }
  EExceptionBase = class(Exception)
  private
    FErrorCode: Integer;
  public
    constructor Create(const AMessage: string); overload;
    constructor Create(const AMessage: string; const AErrorCode: Integer); overload;
    property ErrorCode: Integer read FErrorCode;
  end;

  { Excecoes de conexao (faixa 40 - Connection). ErrorCode vem da base. }
  EConnectionException = class(EExceptionBase)
  private
    FOperation: string;
  public
    constructor Create(const AMessage: string); overload;
    constructor Create(const AMessage: string; const AErrorCode: Integer;
      const AOperation: string = ''); overload;
    property Operation: string read FOperation;
  end;

  EConnectionConnectionException = class(EConnectionException);
  EConnectionSQLException = class(EConnectionException);
  EConnectionValidationException = class(EConnectionException);
  EConnectionConfigurationException = class(EConnectionException);
  EConnectionNotFoundException = class(EConnectionException);

  { Mapa de nomes de coluna da tabela messages (usado pela Exceptions.Database
    para montar SQL sem literais espalhados). }
  TMessageColumns = record
    Code: string;
    ConstantName: string;
    Message: string;
    Module: string;
    SourceProject: string;
    Language: string;
    Name: string;
  end;

const
  MESSAGES_COL: TMessageColumns = (
    Code: 'code';
    ConstantName: 'constant_name';
    Message: 'message';
    Module: 'module';
    SourceProject: 'source_project';
    Language: 'language';
    Name: 'name'
  );

  { --- Bases canonicas por modulo (esquema MMXXXX, ver tabela no cabecalho) --- }
  ERR_SQL_BASE            = 300000;
  ERR_CONNECTION_BASE     = 400000;
  ERR_DATABASE_BASE       = 410000;
  ERR_SERIALIZE_BASE   = 440000;
  ERR_POOLCONNECTIONS_BASE = 450000;
  ERR_PARAMETERS_BASE     = 500000;
  ERR_ATTRIBUTERS_BASE    = 600000;
  ERR_ENTITYMANAGER_BASE  = 700000;
  ERR_QUERYBUILDER_BASE   = 800000;
  ERR_IDENTITYMAP_BASE    = 900000;
  ERR_UNITOFWORK_BASE     = 910000;
  ERR_TYPEDATABASE_BASE   = 920000;
  ERR_LOGGERS_BASE        = 930000;
  ERR_ACTIVEDIRECTORY_BASE = 950000;
  ERR_PRINTERS_BASE       = 960000;
  ERR_ZIPFILE_BASE        = 990000;

  { --- Codigos de conexao (faixa 40, regularizados de 4000N para 40000N) --- }
  ERR_CONNECTION_NOT_ASSIGNED        = ERR_CONNECTION_BASE + 1;   // 400001
  ERR_CONNECTION_FAILED              = ERR_CONNECTION_BASE + 2;
  ERR_CONNECTION_ALREADY_CONNECTED   = ERR_CONNECTION_BASE + 3;
  ERR_CONNECTION_NOT_CONNECTED       = ERR_CONNECTION_BASE + 4;
  ERR_DISCONNECT_FAILED              = ERR_CONNECTION_BASE + 5;
  ERR_CONNECTION_TIMEOUT             = ERR_CONNECTION_BASE + 6;
  ERR_CONNECTION_INVALID_CREDENTIALS = ERR_CONNECTION_BASE + 7;
  ERR_CONNECTION_DATABASE_NOT_FOUND  = ERR_CONNECTION_BASE + 8;
  ERR_SQL_EXECUTION_FAILED           = ERR_CONNECTION_BASE + 9;
  ERR_SQL_QUERY_FAILED               = ERR_CONNECTION_BASE + 10;
  ERR_SQL_COMMAND_FAILED             = ERR_CONNECTION_BASE + 11;
  ERR_TRANSACTION_NOT_STARTED        = ERR_CONNECTION_BASE + 12;
  ERR_TRANSACTION_ALREADY_STARTED    = ERR_CONNECTION_BASE + 13;
  ERR_ENGINE_NOT_SUPPORTED           = ERR_CONNECTION_BASE + 14;
  ERR_DATABASE_TYPE_NOT_SUPPORTED    = ERR_CONNECTION_BASE + 15;
  ERR_CONFIG_FILE_NOT_FOUND          = ERR_CONNECTION_BASE + 16;
  ERR_CONFIG_INVALID                 = ERR_CONNECTION_BASE + 17;
  ERR_SQL_TABLE_NOT_EXISTS           = ERR_CONNECTION_BASE + 18;
  ERR_SQL_TABLE_CREATE_FAILED        = ERR_CONNECTION_BASE + 19;

var
  ExceptionsColumns: TMessageColumns;

implementation

constructor EExceptionBase.Create(const AMessage: string);
begin
  inherited Create(AMessage);
  FErrorCode := 0;
end;

constructor EExceptionBase.Create(const AMessage: string; const AErrorCode: Integer);
begin
  inherited Create(AMessage);
  FErrorCode := AErrorCode;
end;

constructor EConnectionException.Create(const AMessage: string);
begin
  inherited Create(AMessage);
  FOperation := '';
end;

constructor EConnectionException.Create(const AMessage: string;
  const AErrorCode: Integer; const AOperation: string);
begin
  inherited Create(AMessage, AErrorCode);
  FOperation := AOperation;
end;

initialization
  ExceptionsColumns := MESSAGES_COL;

end.
