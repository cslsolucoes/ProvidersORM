{ =============================================================================
  Providers.Commons.Types - Tipos e estruturas do projeto Providers ORM

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  FileVersion:    1.3.3
  Author:         Claiton de Souza Linhares
  Date:           25/07/2026

  Changelog (file):
  - 1.3.3 (25/07/2026): F5-FU.1 (populacao de IsIdentity por dialecto, ADITIVO) -
    TDatabaseFields ganha campo IsIdentity: Integer (0/1, mesmo estilo de IsPKey),
    populado por TMetadata.ApplyColumnIdentity (Database.Metadata.pas) via
    IDialect.IdentityColumnsSQL. Default 0 (nao quebra nenhum consumidor
    existente - novo campo no fim do bloco IsPKey/Position).
  - 1.3.2 (22/07/2026): TConnectionData ganha campo DllDownloadUrl: string. NAO e
    reintroducao do DllNames revertido em 1.3.1 (aquele era um array paralelo de
    resolucao de path/nome por banco, duplicando Commons.DynamicLibrary.pas).
    Este campo preenche a decisao pendente da Onda 7.0 do F7 ("URL CDN do
    DllBootstrap - LE do Parameters"): so guarda uma STRING (URL de download,
    opcional, override de Commons.Consts.DEFAULT_DLL_DOWNLOAD_URL), sem tocar em
    nenhuma logica de resolucao de path/vendor/plataforma - zero sobreposicao
    com Commons.DynamicLibrary. Populado por Parameters.Connections.pas (le a
    chave dll_download_url do perfil); vazio = sem override (consumidor decide
    o fallback quando o mecanismo de auto-download runtime for construido).
  - 1.3.1 (22/07/2026): REVERTIDO o campo DllNames: TStringArray de TConnectionData
    (introduzido em 1.3.0, F8 Onda 8.3, seam 400017) - decisao do owner apos
    pesquisa confirmar que a resolucao de DLL por vendor/plataforma/versao ja
    esta coberta por Commons.DynamicLibrary.pas, sem consumidor real para um
    override por conexao; plumbing especulativo removido (ver .wolf/cerebrum.md
    Do-Not-Repeat 22/07, plano principal §4 regra #14).
  - 1.3.0 (22/07/2026): TConnectionData ganha campo DllNames: TStringArray (F8
    Onda 8.3, extensao aditiva do seam 400017) - nomes das DLLs cliente quando
    o banco exige mais de uma, ordem = ordem de carga; aditivo, nenhum campo
    existente alterado.
  - 1.2.2 (16/07/2026): CORRECAO de posicao no enum (owner) - dtSQLAnywhere
    reposicionado para ANTES de dtODBC/dtLDAP (nao depois). Convencao: dtODBC/
    dtLDAP ficam SEMPRE por ultimo no enum (nao sao dialectos SQL "reais");
    qualquer banco novo entra ANTES deles. Ordem final: dtNone, dtFireBird,
    dtMySQL, dtPostgreSQL, dtSQLite, dtSQLServer, dtAccess, dtSQLAnywhere,
    dtODBC, dtLDAP. Arrays posicionais de Commons.Consts.pas realinhados.
  - 1.2.1 (16/07/2026): TDatabaseTypeClass.VariableType (DEPRECATED) ganha ramo
    dtSQLAnywhere (tinyint/bit/etc.) - faltava, caia no `else` generico ANSI;
    corrigido por consistencia com os demais ramos (o metodo moderno e
    IDialect.ColumnTypeFor, Database.Dialect.SQLAnywhere.pas).
  - 1.2.0 (16/07/2026): TDatabaseTypes expandido com dtSQLAnywhere (F5 Onda 10 —
    SQL Anywhere 17; conectividade nativa dbcapi.dll via Zeos/FireDAC/UniDAC, ODBC
    so fallback SQLdb; ver .workspace/reports/providersorm-v3-f5-entendimento-
    database-sqlanywhere-odbc_v1.0.md).
  - 1.0.0 (04/07/2026): migrado para o v3 (plano F1 Onda 1.1) - header 3.0.0;
    referencia da fonte v2.3.0 preservada abaixo.
  Changelog (fonte v2.3.0):
  - 1.0.0 (03/02/2026): Versão inicial.
  - 1.0.1 (01/02/2026): TDatabaseEngine, TDatabaseTypes, TConnectionData (Fase 1 Connection).
  - 1.0.2 (22/02/2026): Remoção de constantes redundantes; TDatabaseTypeClass. 1.0.3 (23/02/2026): TDatabaseTypeClass com FromString, ConfigString, DisplayName, VariableType. Remoção das funções globais (uso direto da classe).
  - 1.0.4 (22/02/2026): TConnectionDLL record helper para TDatabaseTypes (Self em Directory/Path).
  - 1.0.5 (22/02/2026): ResolveDllBasePath, GetVendorLibPath, GetVendorLibPathMySQLAlt, GetVendorLibDirectory (centralizados; antes em Providers.Connection.Types).
  - 1.0.6 (22/02/2026): TMessageRecord, TableAttribute, FieldAttribute (USE_ATTRIBUTES) migrados de Exceptions.Commons.Types.
  - 1.0.7 (28/02/2026): TDatabaseFields: ReferencedTable e ReferencedColumn para suporte a FK em GetTableStructure.
  - 1.0.8 (27/02/2026): TDatabaseFields: OnUpdateRule e OnDeleteRule para regras de FK no DDL (assimilação DatabaseORM).
  - 1.0.9 (23/04/2026): TDatabaseTypes expandido com dtODBC e dtLDAP (absorção Loggers; Onda 2 do plano loggers-parameters-master-absorption-v1.0).
  - 1.1.0 (15/07/2026): Onda 6-d PARTE 2 (I24, ADITIVO) - TDatabaseFields ganha Description: string (texto de COMMENT/MS_Description/RDB$DESCRIPTION da coluna, preenchido por IMetadata.TableStructure via IDialect.ColumnDescriptionSQL quando o dialecto suporta). Default '' (comportamento pre-existente inalterado).
  ============================================================================= }

unit Commons.Types;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
  {$MODESWITCH TYPEHELPERS}
  {$MODESWITCH ADVANCEDRECORDS}
{$ENDIF}

interface

{$I ../ORM.Defines.inc}
{$IFDEF FPC}
  {$I Commons.FPC.inc}
{$ENDIF}

uses
  {$IF DEFINED(FPC)}
  {$IFDEF FPC_USE_GENERICS_COLLECTIONS}
    SysUtils,
  Classes,
  Generics.Collections;
  {$ELSE}
    SysUtils, Classes, fgl;
  {$ENDIF}
{$ELSE}
  System.SysUtils, System.Classes, System.Generics.Collections;
{$ENDIF}

type

  // COMPATIBILIDADE FPC/DELPHI - Array Types
  {$IF DEFINED(FPC)}
    // Free Pascal: TArray não está disponível, usar array dinâmico nativo
    TStringArray = array of string;
    TByteArray = array of Byte;
  {$ELSE}
    // Delphi: Usar TArray do System
    TStringArray = System.TArray<string>;
    TByteArray = System.TArray<Byte>;
  {$ENDIF}

  //Engine de banco de dados (um por compilação via ORM.Defines.inc).
  TDatabaseEngine = (
    teNone,
    teUnidac,
    teFireDAC,
    teZeos,
    teSQLdb
  );

  //Tipo de banco de dados suportado.
  TDatabaseTypes = (
    dtNone,
    dtFireBird,
    dtMySQL,
    dtPostgreSQL,
    dtSQLite,
    dtSQLServer,
    dtAccess,
    dtSQLAnywhere,
    dtODBC,
    dtLDAP
  );

// Estado do banco de dados
  TDatabaseStatus = (
    dsNone,
    dsInactive,
    dsEdit,
    dsInsert,
    dsDeleted
  );

// Estado da conexão.
  TConnectionStatus = (
    csNone,
    csDisconnected,
    csConnecting,
    csConnected,
    csError
  );

  { Modo de configuração da conexão (Connection - Single Connection ou Connections - Multiple Connections) }
  TConnectionMode = (
    ccmManual,        // Configuração manual (não recomendado)
    ccmParameters     // Configuração via Parameters (recomendado)
  );

  { Tipo de pool de conexões }
  TConnectionPoolType = (
    cptNone,          // Sem pool
    cptFixed,         // Pool fixo (tamanho definido)
    cptDynamic        // Pool dinâmico (cresce conforme necessário)
  );

  // Categoria de variaveis
  TDatabaseVariableType = (
    ptNone,
    ptNumericInteger,
    ptNumericFloat,
    ptCharacterString,
    ptCharacterText,
    ptCharacterChar,
    ptDatetime,
    ptDatetimeTime,
    ptDatetimeDate,
    ptBoolean,
    ptBooleanInteger
  );

  //======================================================================================================
  //  Eventos/callbacks transversais
  //======================================================================================================

  { Progresso generico (transversal). Absorvido de Commons.Progress (ZipFileORM, F1-A):
    2 consumidores no nucleo -> Commons.DllBootstrap (progresso de download) e o modulo
    ZipFile (extracao, via alias TZipProgressEvent). BytesDone/BytesTotal em bytes;
    definir Cancel := True interrompe a operacao. }
  TProgressEvent = procedure(Sender: TObject; BytesDone, BytesTotal: Int64;
    var Cancel: Boolean) of object;

  //======================================================================================================
  //  Records
  //======================================================================================================


  //Dados de conexão para IConnection/TConnection.
  TConnectionData = record
    Engine         : TDatabaseEngine;
    DatabaseType   : TDatabaseTypes;
    Host           : string;
    Port           : Integer;
    Username       : string;
    Password       : string;
    Database       : string;
    Schema         : string;
    ServerName     : string;   // ENG do SQL Anywhere - nome logico do servidor, distinto do Host (F5 Onda 10)
    ConfigFilePath : string;
    DllBasePath    : string;
    DllDownloadUrl : string;   // override opcional do URL de download (Commons.DllBootstrap); '' = usa DEFAULT_DLL_DOWNLOAD_URL
  end;

  { Registro de mensagem da tabela messages (módulo Exceptions). }
  TMessageRecord = record
    Code: Integer;
    ConstantName: string;
    Message: string;
    Module: string;
    SourceProject: string;
    Language: string;
    Name: string;
  end;

  // Dados do campos detalhados
  TDatabaseFields = Record
    Table           : string;
    Column          : string;
    ColumnType      : string;
    ColumnTypeCode  : Integer;
    IsNull          : string;
    Value           : string;
    ToDefault       : string;
    IsChanged       : Integer;
    IsPKey          : Integer;
    // F5-FU.1 - flag de coluna autoincremento (IDENTITY/SERIAL/AUTO_INCREMENT/
    // GENERATED AS IDENTITY, conforme o dialecto), populada pela introspecao do
    // catalogo (IDialect.IdentityColumnsSQL) via TMetadata.ApplyColumnIdentity.
    // Default 0 (dialecto sem suporte ou coluna sem identity - no-op gracioso).
    IsIdentity      : Integer;
    Position        : Integer;
    ConstraintName  : string;
    ReferencedTable : string;
    ReferencedColumn : string;
    OnUpdateRule    : string;
    OnDeleteRule    : string;
    // Onda 6-d PARTE 2 (I24) - descricao da coluna (COMMENT/MS_Description/
    // RDB$DESCRIPTION/COLUMN_COMMENT, conforme o banco). Default '' (sem
    // suporte no dialecto ou coluna sem comentario - no-op gracioso).
    Description     : string;
  End;

{$IFDEF USE_DEPRECATED}
  //Tipos de variáveis conforme tipo de banco de dados (TDatabaseTypes).
  //DEPRECATED (Onda 5.2): so cobre Firebird 2.5.9 - usar IDialect.ColumnTypeFor
  //(Database.Dialect.*, version-aware). Gated por USE_DEPRECATED (build v3 limpo com
  //-DNO_DEPRECATED exclui este tipo); remocao formal na v4.0. Sem consumidor externo.
  TVariableType = Class
    Numeric    : string;
    Character  : string;
    Time       : string;
    Date       : string;
    DateTime   : string;
    Boolean    : string;
  end;
{$ENDIF}

  { =============================================================================
    PARAMETROS - unidade de configuracao (migrado de Commons.Parameters.Types).
    TODOS sao API publica (assinaturas de IParameters / TProviders.Parameter) ->
    nucleo (D11 / criterio API-publica). Usados tambem por Loggers e Exceptions.
    ============================================================================= }

  TParameterValueType = (pvtString, pvtInteger, pvtFloat, pvtBoolean, pvtDateTime, pvtJSON);

  TParameterSource = (psNone, psDatabase, psInifiles, psJsonObject);

  {$IF DEFINED(FPC)}
    TParameterSourceArray = array of TParameterSource;
  {$ELSE}
    TParameterSourceArray = System.TArray<TParameterSource>;
  {$ENDIF}

  TParameterConfig = set of TParameterSource;

  { Unidade de configuracao (parametro). }
  TParameter = class
  private
    FID: Integer;
    FName: string;
    FValue: string;
    FValueType: TParameterValueType;
    FDescription: string;
    FContratoID: Integer;
    FProdutoID: Integer;
    FOrdem: Integer;
    FTitulo: string;
    FAtivo: Boolean;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    constructor Create;
    destructor Destroy; override;
    property ID: Integer read FID write FID;
    property Name: string read FName write FName;
    property Value: string read FValue write FValue;
    property ValueType: TParameterValueType read FValueType write FValueType;
    property Description: string read FDescription write FDescription;
    property ContratoID: Integer read FContratoID write FContratoID;
    property ProdutoID: Integer read FProdutoID write FProdutoID;
    property Ordem: Integer read FOrdem write FOrdem;
    property Titulo: string read FTitulo write FTitulo;
    property Ativo: Boolean read FAtivo write FAtivo;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  {$IF DEFINED(FPC) AND NOT DEFINED(FPC_USE_GENERICS_COLLECTIONS)}
  TParameterList = class(TFPGList<TParameter>)
  {$ELSE}
  TParameterList = class(TList<TParameter>)
  {$ENDIF}
  public
    destructor Destroy; override;
    procedure ClearAll;
  end;

  TParameterImportOverwriteCallback = function(const AExistingParameter, ANewParameter: TParameter): Boolean of object;
  TParameterImportOverwriteCallbackSimple = function(const AExistingParameter, ANewParameter: TParameter): Boolean;

  { Versoes suportadas do Firebird (plano secao 2-D). Usado por VariableType (mapeamento
    de tipos version-aware) e pela resolucao de DLL (GetFirebirdLibPath). As capability
    flags completas do dialecto ficam no IDialect (Onda 5.2), que reutiliza isto. }
  TFirebirdVersion = (fb25, fb30, fb40, fb50);

  { Conversão e utilitários para TDatabaseTypes. Usa TDatabaseTypeInverse e TDatabaseTypeConfig em Consts.
    VariableType e VERSION-AWARE para Firebird (2.5/3.0/4.0/5.0, plano 2-D): a sobrecarga
    sem versao usa DEFAULT_FIREBIRD_VERSION. A consolidacao final dos dialectos fica no
    IDialect (Onda 5.2), que reutiliza este mapeamento. }
  TDatabaseTypeClass = class
  public
    class function FromString(const AValue: string): TDatabaseTypes;
    class function ConfigString(ADatabaseType: TDatabaseTypes): string;
    class function DisplayName(ADatabaseType: TDatabaseTypes): string;
{$IFDEF USE_DEPRECATED}
    // DEPRECATED (Onda 5.2): substituido por IDialect.ColumnTypeFor. Ver TVariableType.
    class function VariableType(ADatabaseType: TDatabaseTypes): TVariableType; overload;
    class function VariableType(ADatabaseType: TDatabaseTypes;
      AFirebirdVersion: TFirebirdVersion): TVariableType; overload;
{$ENDIF}
  end;

  { Os atributos [Table]/[Field]/[PrimaryKey] deste modulo vivem centralizados em
    Attributers.Database.Interfaces (FASE 6 Onda 6.1, D5) - Commons.Types fica so
    com tipos de DADOS transversais. }

implementation

uses
  {$IF DEFINED(FPC)}
  StrUtils,
  {$ELSE}
  System.StrUtils,
  {$ENDIF}
  Commons.Consts;

{ TParameter }

constructor TParameter.Create;
begin
  inherited;
  FID := 0; FName := ''; FValue := ''; FValueType := pvtString;
  FDescription := ''; FContratoID := 0; FProdutoID := 0; FOrdem := 0;
  FTitulo := ''; FAtivo := True; FCreatedAt := Now; FUpdatedAt := Now;
end;

destructor TParameter.Destroy;
begin
  inherited;
end;

{ TParameterList }

destructor TParameterList.Destroy;
begin
  ClearAll;
  inherited;
end;

procedure TParameterList.ClearAll;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    Items[I].Free;
  Clear;
end;

{ TDatabaseTypeClass }

class function TDatabaseTypeClass.FromString(const AValue: string): TDatabaseTypes;
var
  I: TDatabaseTypes;
begin
  Result := dtNone;
  if Trim(AValue) = '' then Exit;
  for I := Low(TDatabaseTypeInverse) to High(TDatabaseTypeInverse) do
  begin
    if SameText(AValue, TDatabaseTypeInverse[I].Name) then
    begin
      Result := TDatabaseTypeInverse[I].DatabaseType;
      Exit;
    end;
  end;
  if SameText(AValue, 'FireBird') then Result := dtFireBird;
end;

class function TDatabaseTypeClass.ConfigString(ADatabaseType: TDatabaseTypes): string;
begin
  if (ADatabaseType >= Low(TDatabaseTypes)) and (ADatabaseType <= High(TDatabaseTypes)) then
    Result := TDatabaseTypeConfig[DEFAULT_DATABASE_ENGINE, ADatabaseType]
  else
    Result := TDatabaseTypeConfig[DEFAULT_DATABASE_ENGINE, dtPostgreSQL];
end;

class function TDatabaseTypeClass.DisplayName(ADatabaseType: TDatabaseTypes): string;
begin
  if (ADatabaseType >= Low(TDatabaseTypes)) and (ADatabaseType <= High(TDatabaseTypes)) then
    Result := TDatabaseTypeNames[ADatabaseType]
  else
    Result := 'None';
end;

{$IFDEF USE_DEPRECATED}
class function TDatabaseTypeClass.VariableType(ADatabaseType: TDatabaseTypes): TVariableType;
begin
  { Sobrecarga sem versao: usa a versao default do Firebird (DEFAULT_FIREBIRD_VERSION). }
  Result := VariableType(ADatabaseType, DEFAULT_FIREBIRD_VERSION);
end;

class function TDatabaseTypeClass.VariableType(ADatabaseType: TDatabaseTypes;
  AFirebirdVersion: TFirebirdVersion): TVariableType;
begin
  Result := TVariableType.Create;
  case ADatabaseType of
    // FIREBIRD - version-aware (2.5 / 3.0 / 4.0 / 5.0)
    dtFireBird:
    begin
      // Base (2.5.x): sem BOOLEAN nativo.
      Result.Numeric    := 'smallint,integer,bigint,decimal,numeric,float,double precision';
      Result.Character  := 'char,varchar';
      Result.Time       := 'time';
      Result.Date       := 'date';
      Result.DateTime   := 'timestamp';
      Result.Boolean    := '';
      // 3.0+: BOOLEAN nativo.
      if AFirebirdVersion >= fb30 then
        Result.Boolean  := 'boolean';
      // 4.0+: DECFLOAT / INT128 e tipos WITH TIME ZONE (5.0 mantem os mesmos tipos).
      if AFirebirdVersion >= fb40 then
      begin
        Result.Numeric  := Result.Numeric + ',decfloat,int128';
        Result.Time     := Result.Time + ',time with time zone';
        Result.DateTime := Result.DateTime + ',timestamp with time zone';
      end;
    end;

    // POSTGRESQL
    dtPostgreSQL: begin
      Result.Numeric      := 'smallint,integer,bigint,decimal,numeric,real,double precision,serial,bigserial,smallserial,money';
      Result.Character    := 'char,varchar,text,name,citext,character varying';
      Result.Time         := 'time,timetz';
      Result.Date         := 'date';
      Result.DateTime     := 'timestamp,timestamptz,timestamp with time zone';
      Result.Boolean      := 'boolean';
    end;

    // MARIADB / MYSQL
    dtMySQL: begin // MariaDB e MySQL usam os mesmos tipos
      Result.Numeric      := 'bit,tinyint,smallint,mediumint,int,bigint,decimal,numeric,float,double,real,serial';
      Result.Character    := 'char,varchar,text,tinytext,mediumtext,longtext,binary,varbinary,enum,set';
      Result.Time         := 'time';
      Result.Date         := 'date,year';
      Result.DateTime     := 'datetime,timestamp';
      Result.Boolean      := 'boolean';
    end;

    // SQL SERVER
    dtSQLServer: begin
      Result.Numeric      := 'bit,tinyint,smallint,int,bigint,decimal,numeric,money,smallmoney,float,real';
      Result.Character    := 'char,varchar,text,nchar,nvarchar,ntext,binary,varbinary,image,xml';
      Result.Time         := 'time';
      Result.Date         := 'date';
      Result.DateTime     := 'datetime,datetime2,smalldatetime,datetimeoffset';
      Result.Boolean      := 'bool,boolean,bit';
    end;

    // SQLITE
    dtSQLite: begin
      Result.Numeric      := 'integer,real,numeric';
      Result.Character    := 'text';
      Result.Time         := 'text,real,integer';
      Result.Date         := 'text,real,integer';
      Result.DateTime     := 'text,real,integer';
      Result.Boolean      := 'integer';
    end;

    // ACCESS
    dtAccess: begin
      Result.Numeric      := 'byte,integer,longinteger,single,double,currency,decimal';
      Result.Character    := 'text,memo';
      Result.Time         := 'date/time';
      Result.Date         := 'date/time';
      Result.DateTime     := 'date/time';
      Result.Boolean      := 'yesno';
    end;

    // SQL ANYWHERE (F5 Onda 10) - metodo DEPRECATED (usar IDialect.ColumnTypeFor,
    // Database.Dialect.SQLAnywhere.pas); mantido por consistencia com os demais
    // ramos - sem BOOLEAN nativo (usa BIT).
    dtSQLAnywhere: begin
      Result.Numeric      := 'tinyint,smallint,integer,bigint,decimal,numeric,float,double,real,money,smallmoney,unsigned int,unsigned bigint,unsigned smallint,unsigned tinyint';
      Result.Character    := 'char,varchar,nchar,nvarchar,long varchar,long nvarchar,text,xml';
      Result.Time         := 'time';
      Result.Date         := 'date';
      Result.DateTime     := 'timestamp,datetime,smalldatetime';
      Result.Boolean      := 'bit';
    end;

    else begin
      Result.Numeric      := 'smallint,integer,bigint,decimal,numeric,float,double precision';
      Result.Character    := 'char,varchar';
      Result.Time         := 'time';
      Result.Date         := 'date';
      Result.DateTime     := 'timestamp';
      Result.Boolean      := 'boolean';
    end;
  end;
end;
{$ENDIF}

end.
