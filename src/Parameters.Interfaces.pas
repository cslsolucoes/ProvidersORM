{ =============================================================================
  Parameters.Interfaces - TODAS as interfaces do modulo Parameters

  Ficheiro central das interfaces do modulo (regra do owner "centralizar as
  interfaces"): IParametersSource (contrato comum CRUD das 3 fontes) +
  IParametersDatabase / IParametersIniFile / IParametersJsonObject (fontes
  concretas) + IParameters (convergencia multi-fonte com fallback em cascata).

  Redesenho v3 (FASE 7, Onda 7.1 - reescrita limpa por referencia):
  - Nomenclatura CRUD real: Select / Insert / Update / Save / Delete
    (substitui Getter / Setter / List / Update-alias / Get do standalone v1.0.7,
    que NAO transitam - vivem so na linha v1 congelada, superficie S1).
  - Conexao TIPADA: Connection(IConnection) - nunca TObject / TDataSet.
  - Escopo Contrato / Produto / Titulo = 3 filtros PARALELOS.
  - Erros por EXCECAO tipada EParameters* (Exceptions.Parameters); os overloads
    com "out ASuccess" cobrem o resultado ESPERADO (padrao GetLastError).
  - De-dup: reusa TDatabaseEngine / TDatabaseTypes / TFirebirdVersion / TConnectionData
    de Commons.Types (nao redeclara enums proprios de engine/tipo).
  - Import/Export UNIFORME: ImportFrom / ExportTo(IParametersSource).

  Depende so de Commons.Types + Connections.Interfaces (IConnection). Gated por
  USE_PARAMETERS. A factory oculta (TParameters) e a convergencia vivem em
  Parameters.pas (Onda 7.4); as fontes em Parameters.Database / .IniFile /
  .JsonObject (Ondas 7.2/7.3).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  2.1.0
  FileVersion:    2.1.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           11/08/2026

  Changelog (file):
  - 2.1.0 (11/08/2026): retrofit SetLogger (F8 Onda 8.6) - observabilidade
    estrutural da convergencia multi-fonte via ILogger fluente (SetLogger).
    Gated USE_LOGGERS; default TNullLogger.
  - 2.0.0 (16/07/2026): criacao - contratos v3 do modulo Parameters (FASE 7,
    Onda 7.1). Nomenclatura CRUD aprovada pelo owner; base comum
    IParametersSource; de-dup de enums; import/export uniforme. Superficie do
    standalone v1.0.7 (Getter/Setter/List/Update/Get) NAO transita.
  ============================================================================= }

unit Parameters.Interfaces;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_PARAMETERS}

uses
{$IF DEFINED(FPC)}
  SysUtils, Classes, fpjson,
{$ELSE}
  System.SysUtils, System.Classes, System.JSON,
{$ENDIF}
  Commons.Types,          // TParameter, TParameterList, TParameterValueType, TParameterSource,
                          // TParameterSourceArray, TDatabaseEngine, TDatabaseTypes, TFirebirdVersion, TConnectionData
  Connections.Interfaces  // IConnection (Connection tipado - DI da conexao)
{$IFDEF USE_LOGGERS}
  ,Loggers.Interfaces     // ILogger
{$ENDIF}
;

type
  { ---------------------------------------------------------------------------
    Forward declarations (interfaces do modulo, num unico bloco 'type' continuo)
    --------------------------------------------------------------------------- }
  IParametersSource     = interface;
  IParametersDatabase   = interface;
  IParametersIniFile    = interface;
  IParametersJsonObject = interface;
  IParameters           = interface;

  { ===========================================================================
    IParametersSource - contrato COMUM das 3 fontes (Database / INI / JSON)

    CRUD tipado, escopo, utilitarios e import/export uniforme. As fontes
    concretas herdam este contrato e adicionam a sua configuracao especifica.
    Os setters de escopo devolvem IParametersSource (fluent-base); para encadear
    configuracao especifica, usar a interface concreta.
    =========================================================================== }
  IParametersSource = interface
    ['{7B3F1A20-9C4D-4E6F-A180-1122334455F0}']

    { Identificacao da fonte }
    function Source: TParameterSource;

    { Escopo - 3 filtros PARALELOS (contrato / produto / titulo) }
    function ContratoID(const AValue: Integer): IParametersSource; overload;
    function ContratoID: Integer; overload;
    function ProdutoID(const AValue: Integer): IParametersSource; overload;
    function ProdutoID: Integer; overload;
    function Title(const AValue: string): IParametersSource; overload;
    function Title: string; overload;

    { CRUD - leitura (Select-um / Select-muitos) }
    function Select(const AName: string): TParameter; overload;
    function Select(const AName: string; out AParameter: TParameter): IParametersSource; overload;
    function Select: TParameterList; overload;
    function Select(out AList: TParameterList): IParametersSource; overload;

    { CRUD - escrita (erro -> EParameters*; overload 'out ASuccess' p/ resultado esperado) }
    function Insert(const AParameter: TParameter): IParametersSource; overload;
    function Insert(const AParameter: TParameter; out ASuccess: Boolean): IParametersSource; overload;
    function Update(const AParameter: TParameter): IParametersSource; overload;
    function Update(const AParameter: TParameter; out ASuccess: Boolean): IParametersSource; overload;
    function Save(const AParameter: TParameter): IParametersSource; overload;                        // upsert (INSERT-ou-UPDATE)
    function Save(const AParameter: TParameter; out ASuccess: Boolean): IParametersSource; overload;
    function Delete(const AName: string): IParametersSource; overload;
    function Delete(const AName: string; out ASuccess: Boolean): IParametersSource; overload;

    { Predicados / utilitarios }
    function Exists(const AName: string): Boolean; overload;
    function Exists(const AName: string; out AExists: Boolean): IParametersSource; overload;
    function Count: Integer; overload;
    function Count(out ACount: Integer): IParametersSource; overload;
    function Refresh: IParametersSource;
    function ToJSON: TJSONObject;

    { Import / Export UNIFORME entre fontes (matriz N x N) }
    function ImportFrom(const ASource: IParametersSource): IParametersSource; overload;
    function ImportFrom(const ASource: IParametersSource; out ASuccess: Boolean): IParametersSource; overload;
    function ExportTo(const ASource: IParametersSource): IParametersSource; overload;
    function ExportTo(const ASource: IParametersSource; out ASuccess: Boolean): IParametersSource; overload;

{$IFDEF USE_DEPRECATED}
    { --- Compat v1.0.7 (deprecated; gated USE_DEPRECATED; delega ao CRUD v3) --- }
    function Getter(const AName: string): TParameter; overload; deprecated 'Use Select. Removido na proxima major.';
    function Getter(const AName: string; out AParameter: TParameter): IParametersSource; overload; deprecated 'Use Select.';
    function List: TParameterList; overload; deprecated 'Use Select (Select-muitos).';
    function List(out AList: TParameterList): IParametersSource; overload; deprecated 'Use Select.';
    function Setter(const AParameter: TParameter): IParametersSource; overload; deprecated 'Use Save (upsert).';
    function Setter(const AParameter: TParameter; out ASuccess: Boolean): IParametersSource; overload; deprecated 'Use Save.';
{$ENDIF}
  end;

  { ===========================================================================
    IParametersDatabase - fonte Database (sobre Connections F4 + Database F5)

    Persistencia via IConnection DIRETA (nunca o pool) + EntityManager /
    QueryBuilder / Table / ISynchronize do v3 - zero SQL manual, zero IFDEF de
    engine. Suporta conexao propria (bootstrap file->SQLite) ou IConnection
    injetada. Serve tambem os perfis de conexao ao ecossistema (via o adaptador
    do seam, Parameters.Connections, Onda 7.5).
    =========================================================================== }
  IParametersDatabase = interface(IParametersSource)
    ['{7B3F1A21-9C4D-4E6F-A180-1122334455F1}']

    { Tabela (default 'parameters' - Q16; pode haver >1 tabela - Q17) }
    function TableName(const AValue: string): IParametersDatabase; overload;
    function TableName: string; overload;
    function Schema(const AValue: string): IParametersDatabase; overload;
    function Schema: string; overload;
    function AutoCreateTable(const AValue: Boolean): IParametersDatabase; overload;
    function AutoCreateTable: Boolean; overload;

    { Conexao - DI TIPADA (v3: IConnection, nunca TObject/TDataSet) }
    function Connection(const AConnection: IConnection): IParametersDatabase; overload;
    function Connection: IConnection; overload;

    { Config de conexao propria (conexao INDEPENDENTE - bootstrap) }
    function Engine(const AValue: TDatabaseEngine): IParametersDatabase; overload;
    function Engine: TDatabaseEngine; overload;
    function DatabaseType(const AValue: TDatabaseTypes): IParametersDatabase; overload;
    function DatabaseType: TDatabaseTypes; overload;
    function Host(const AValue: string): IParametersDatabase; overload;
    function Host: string; overload;
    function Port(const AValue: Integer): IParametersDatabase; overload;
    function Port: Integer; overload;
    function Username(const AValue: string): IParametersDatabase; overload;
    function Username: string; overload;
    function Password(const AValue: string): IParametersDatabase; overload;
    function Password: string; overload;
    function Database(const AValue: string): IParametersDatabase; overload;
    function Database: string; overload;
    function DllBasePath(const AValue: string): IParametersDatabase; overload;
    function DllBasePath: string; overload;
    function FirebirdVersion(const AValue: TFirebirdVersion): IParametersDatabase; overload;
    function FirebirdVersion: TFirebirdVersion; overload;

    { Bootstrap: file (config.db->ini->json em <EXE>\data) senao SQLite zero-config (Q10) }
    function FromConfig: IParametersDatabase; overload;
    function FromConfig(const APath: string): IParametersDatabase; overload;

    { Ciclo de vida da conexao }
    function Connect: IParametersDatabase; overload;
    function Disconnect: IParametersDatabase;
    function IsConnected: Boolean;

    { DDL da tabela - via ISynchronize / IMetadata do F5 (a tabela vira ISchemaDefinition) }
    function EnsureTable: IParametersDatabase;   // ex-CreateTable + MigrateTable (idempotente)
    function TableExists: Boolean;

{$IFDEF USE_DEPRECATED}
    { --- Compat v1.0.7 / v2.3.0 (deprecated; delega ao v3) --- }
    function CreateTable: IParametersDatabase; deprecated 'Use EnsureTable (idempotente: cria se nao existe + migra).';
    function Connect(out ASuccess: Boolean): IParametersDatabase; overload; deprecated 'Use Connect (lanca EParameters* em erro).';
    { re-exposto p/ paridade v2.3.0 (validacao + Opcao B do owner): capacidades que
      existiam na fachada v2.3.0 e continuam disponiveis via Connections/Database. }
    function DropTable: IParametersDatabase; overload; deprecated 'Removido do v3 limpo; re-exposto (delega ISchema.DropTable, idempotente).';
    function DropTable(out ASuccess: Boolean): IParametersDatabase; overload; deprecated 'Idem DropTable.';
    function MigrateTable: IParametersDatabase; overload; deprecated 'Use EnsureTable (idempotente ja cobre migracao).';
    function MigrateTable(out ASuccess: Boolean): IParametersDatabase; overload; deprecated 'Use EnsureTable.';
    function ListAvailableDatabases: TStringArray; overload; deprecated 'Use Connection.GetDatabaseNames.';
    function ListAvailableDatabases(out AList: TStringArray): IParametersDatabase; overload; deprecated 'Use Connection.GetDatabaseNames.';
    function ListAvailableTables: TStringArray; overload; deprecated 'Use Connection.GetTableNames.';
    function ListAvailableTables(out AList: TStringArray): IParametersDatabase; overload; deprecated 'Use Connection.GetTableNames.';
{$ENDIF}
  end;

  { ===========================================================================
    IParametersIniFile - fonte INI (modulo interno, base comum TParametersSourceBase)
    Uma seccao por Titulo; preserva comentarios do ficheiro.
    =========================================================================== }
  IParametersIniFile = interface(IParametersSource)
    ['{7B3F1A22-9C4D-4E6F-A180-1122334455F2}']
    function FilePath(const AValue: string): IParametersIniFile; overload;   // default <EXE>\data\config.ini (Q16)
    function FilePath: string; overload;
    function Section(const AValue: string): IParametersIniFile; overload;
    function Section: string; overload;
    function AutoCreateFile(const AValue: Boolean): IParametersIniFile; overload;
    function AutoCreateFile: Boolean; overload;
    function FileExists: Boolean;
{$IFDEF USE_DEPRECATED}
    function EndInifiles: IInterface; deprecated 'Navegacao fluente v2.3.0; devolve Self (sem "pai" no modo standalone).';
{$ENDIF}
  end;

  { ===========================================================================
    IParametersJsonObject - fonte JSON (modulo interno, base comum)
    Um objeto por Titulo; encoding UTF-8 (BOM-aware na leitura, sem BOM na escrita).
    =========================================================================== }
  IParametersJsonObject = interface(IParametersSource)
    ['{7B3F1A23-9C4D-4E6F-A180-1122334455F3}']
    function FilePath(const AValue: string): IParametersJsonObject; overload;   // default <EXE>\data\config.json (Q16)
    function FilePath: string; overload;
    function ObjectName(const AValue: string): IParametersJsonObject; overload;
    function ObjectName: string; overload;
    function JsonObject(const AValue: TJSONObject): IParametersJsonObject; overload;
    function JsonObject: TJSONObject; overload;
    function AutoCreateFile(const AValue: Boolean): IParametersJsonObject; overload;
    function AutoCreateFile: Boolean; overload;
    function FileExists: Boolean;
    function ToJSONString: string;
    function SaveToFile(const AFilePath: string = ''): IParametersJsonObject; overload;
    function LoadFromFile(const AFilePath: string = ''): IParametersJsonObject; overload;
    function LoadFromString(const AJsonString: string): IParametersJsonObject;
{$IFDEF USE_DEPRECATED}
    function EndJsonObject: IInterface; deprecated 'Navegacao fluente v2.3.0; devolve Self.';
    function SaveToFile(const AFilePath: string; out ASuccess: Boolean): IParametersJsonObject; overload; deprecated 'Use SaveToFile (lanca em erro).';
    function LoadFromFile(const AFilePath: string; out ASuccess: Boolean): IParametersJsonObject; overload; deprecated 'Use LoadFromFile.';
{$ENDIF}
  end;

  { ===========================================================================
    IParameters - convergencia multi-fonte (fachada de leitura em cascata)

    Le em cascata configuravel (Priority; default DB > INI, JSON opt-in);
    escreve SO na fonte ativa (Source). Da acesso direto a cada fonte concreta.
    =========================================================================== }
  IParameters = interface
    ['{7B3F1A24-9C4D-4E6F-A180-1122334455F4}']

{$IFDEF USE_LOGGERS}
    { Observabilidade estrutural - F8 Onda 8.6 }
    function SetLogger(const ALogger: ILogger): IParameters;
{$ENDIF}

    { Gerenciamento de fontes / precedencia }
    function Source(const AValue: TParameterSource): IParameters; overload;   // fonte ATIVA (escrita)
    function Source: TParameterSource; overload;
    function AddSource(const AValue: TParameterSource): IParameters;
    function RemoveSource(const AValue: TParameterSource): IParameters;
    function HasSource(const AValue: TParameterSource): Boolean;
    function Priority(const ASources: TParameterSourceArray): IParameters;    // ordem de leitura DB>INI>JSON

    { Escopo unificado (propaga a todas as fontes ativas) }
    function ContratoID(const AValue: Integer): IParameters; overload;
    function ContratoID: Integer; overload;
    function ProdutoID(const AValue: Integer): IParameters; overload;
    function ProdutoID: Integer; overload;

    { CRUD unificado - leitura em cascata; escrita na fonte ATIVA }
    function Select(const AName: string): TParameter; overload;
    function Select(const AName: string; const ASource: TParameterSource): TParameter; overload;   // forca fonte, sem fallback
    function Select: TParameterList; overload;
    function Insert(const AParameter: TParameter): IParameters; overload;
    function Insert(const AParameter: TParameter; out ASuccess: Boolean): IParameters; overload;
    function Update(const AParameter: TParameter): IParameters; overload;
    function Update(const AParameter: TParameter; out ASuccess: Boolean): IParameters; overload;
    function Save(const AParameter: TParameter): IParameters; overload;
    function Save(const AParameter: TParameter; out ASuccess: Boolean): IParameters; overload;
    function Delete(const AName: string): IParameters; overload;
    function Delete(const AName: string; out ASuccess: Boolean): IParameters; overload;
    function Exists(const AName: string): Boolean;
    function Count: Integer;
    function Refresh: IParameters;
    function ToJSON: TJSONObject;

    { Acesso direto as fontes concretas }
    function Database: IParametersDatabase;
    function IniFile: IParametersIniFile;
    function JsonObject: IParametersJsonObject;

{$IFDEF USE_DEPRECATED}
    { --- Compat v1.0.7 (deprecated; delega ao CRUD v3 unificado) --- }
    function Getter(const AName: string): TParameter; overload; deprecated 'Use Select.';
    function List: TParameterList; overload; deprecated 'Use Select.';
    function Setter(const AParameter: TParameter): IParameters; overload; deprecated 'Use Save.';
{$ENDIF}

    { Navegacao fluent (volta ao contexto pai) }
    function EndParameters: IInterface;
  end;

{$IFDEF USE_DEPRECATED}
  { Alias de compat v1.0.7 - nome antigo da interface INI (era 'Inifiles'). }
  IParametersInifiles = IParametersIniFile deprecated 'Use IParametersIniFile.';
{$ENDIF}

{$ENDIF USE_PARAMETERS}

implementation

end.
