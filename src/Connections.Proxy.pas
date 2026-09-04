{ =============================================================================
  Connections.Proxy - Proxy transparente de IConnection sobre o Broker (Onda 4.3)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.23
  FileVersion:    1.1.1
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           22/07/2026

  Padrao Proxy / Caixa Preta (pilar 1 do broker - Prompt Connections tarefas
  2-4): TConnectionProxy implementa IConnection COMPLETO mas NUNCA toca na
  conexao fisica - cada metodo DB empacota os parametros num TPoolRequest,
  envia-o ao broker (abstracao IPoolBroker, declarada em
  Commons.PoolConnections.Types - este modulo NAO depende do modulo
  PoolConnections), suspende a execucao e aguarda o resultado da Worker
  Thread, devolvendo-o (ou relancando a excecao com codigo+mensagem
  preservados). O solicitante e completamente alheio a filas/limites/workers.

  Sticky Sessions (tarefa 4): BeginTransaction informa o broker para reservar
  uma worker em EXCLUSIVIDADE; todas as chamadas seguintes (incl. Commit e
  Rollback) sao roteadas para essa mesma worker ate a transacao terminar.

  Semanticas de pooled connection:
  - Connect        -> no-op (a worker do pool ja esta conectada); devolve Self.
  - Disconnect     -> Release (devolve a worker ao pool SEM fechar a fisica) -
                      transparencia total para o consumidor.
  - From*/setters  -> a config do banco pertence ao BROKER; From* lanca
                      EPoolConnectionsException (450003); setters fluentes
                      actualizam apenas a copia local (getters) e devolvem Self.

  Changelog (file):
  - 1.1.1 (22/07/2026): implementado DllDownloadUrl(AValue)/DllDownloadUrl
    (IConnection ganhou o método na auditoria F7, Onda 7.0) — delega em
    FData.DllDownloadUrl (mesmo padrão de DllBasePath); GetConnectionData ja
    exporta automaticamente (devolve FData inteiro).
  - 1.1.0 (11/07/2026): Onda 4.3b - IPooledConnection.ExecuteDirect (bug-157):
    callback plano executado NA worker com a conexao FISICA - unica porta para
    interfaces estendidas (ex. IConnectionsActiveDirectory) via pool.
  - 1.0.0 (10/07/2026): versao inicial (Onda 4.3 Etapa A2).
  ============================================================================= }
unit Connections.Proxy;

{$I ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$IFDEF USE_POOLCONNECTIONS}

uses
{$IFDEF FPC}
  SysUtils, Classes, Variants, DB,
{$ELSE}
  System.SysUtils, System.Classes, System.Variants, Data.DB,
{$ENDIF}
  Commons.Types,
  Commons.PoolConnections.Types,
  Commons.PoolConnections.Consts,
  Exceptions.PoolConnections,
  Connections.Interfaces;

type
  TConnectionProxy = class(TInterfacedObject, IConnection, IPooledConnection)
  strict private
    FBroker          : IPoolBroker;
    FProxyId         : Integer;
    FData            : TConnectionData; // copia local (getters); config real e do broker
    FFirebirdVersion : TFirebirdVersion;
    FServerName      : string; // ENG do SQL Anywhere (F5 Onda 10)
    FSQLAnywhereDriver : string; // vertente SA sob UniDAC (dual-driver): native | odbc
    FAutoDownloadDlls: Boolean;
    FReleased        : Boolean;
    FInTransaction   : Boolean;
    procedure CheckAlive(const AOp: string);
    { Executa o pedido no broker e relanca erro se houver; o caller consome os
      slots e liberta o request. }
    procedure Exec(const AReq: TPoolRequest);
    procedure CopyParams(const AParams: array of Variant; out ADest: TArray<Variant>);
    function NotReconfigurable(const AOp: string): EPoolConnectionsException;
  public
    constructor Create(const ABroker: IPoolBroker; const AProxyId: Integer;
      const AData: TConnectionData);
    destructor Destroy; override;

    { IPooledConnection }
    procedure Release;
    procedure ExecuteDirect(const AProc: TPoolDirectProc; const AContext: Pointer);

    { IConnection - configuracao fluente (copia local) }
    function Engine(const AValue: TDatabaseEngine): IConnection; overload;
    function Engine: TDatabaseEngine; overload;
    function DatabaseType(const AValue: TDatabaseTypes): IConnection; overload;
    function DatabaseType(const AValue: string): IConnection; overload;
    function DatabaseType: TDatabaseTypes; overload;
    function Host(const AValue: string): IConnection; overload;
    function Host: string; overload;
    function Port(const AValue: Integer): IConnection; overload;
    function Port: Integer; overload;
    function Username(const AValue: string): IConnection; overload;
    function Username: string; overload;
    function Password(const AValue: string): IConnection; overload;
    function Password: string; overload;
    function Database(const AValue: string): IConnection; overload;
    function Database: string; overload;
    function Schema(const AValue: string): IConnection; overload;
    function Schema: string; overload;
    function ConfigFilePath(const AValue: string): IConnection; overload;
    function ConfigFilePath: string; overload;
    function DllBasePath(const AValue: string): IConnection; overload;
    function DllBasePath: string; overload;
    function AutoDownloadDlls(const AValue: Boolean): IConnection; overload;
    function AutoDownloadDlls: Boolean; overload;
    function DllDownloadUrl(const AValue: string): IConnection; overload;
    function DllDownloadUrl: string; overload;
    function FirebirdVersion(const AValue: TFirebirdVersion): IConnection; overload;
    function FirebirdVersion(const AValue: string): IConnection; overload;
    function FirebirdVersion: TFirebirdVersion; overload;
    function ServerName(const AValue: string): IConnection; overload;
    function ServerName: string; overload;
    function SQLAnywhereDriver(const AValue: string): IConnection; overload;
    function SQLAnywhereDriver: string; overload;
    function IsRequiredDllFound: Boolean;

    { IConnection - carregamento de configuracao: nao aplicavel a pooled }
    function FromIniFile(const AFilePath, ASection: string): IConnection;
    function FromConfig: IConnection;
    function FromJSON(const AJSON: string): IConnection;
{$IFDEF USE_ATTRIBUTES}
    function FromClass(const AClass: TClass): IConnection;
{$ENDIF}

    { IConnection - conexao }
    function Connect: IConnection;
    function Disconnect: IConnection;
    function IsConnected: Boolean;
    function Ping: Boolean;

    { IConnection - execucao }
    function ExecuteQuery(const ASQL: string): TDataSet; overload;
    function ExecuteCommand(const ASQL: string): Integer; overload;
    function ExecuteScalar(const ASQL: string): Variant; overload;
    function ExecuteQuery(const ASQL: string;
      const AParams: array of Variant): TDataSet; overload;
    function ExecuteCommand(const ASQL: string;
      const AParams: array of Variant): Integer; overload;
    function ExecuteScalar(const ASQL: string;
      const AParams: array of Variant): Variant; overload;

    { IConnection - transacoes (sticky sessions) }
    function BeginTransaction: IConnection;
    function Commit: IConnection;
    function Rollback: IConnection;
    function InTransaction: Boolean;
    function LockWait(const AValue: Boolean): IConnection; overload; // F5-FU.3
    function LockWait: Boolean; overload;

    { IConnection - versoes }
    function GetServerVersion: string;
    function GetClientVersion: string;

    { IConnection - dados }
    function GetConnectionData: TConnectionData;

    { IConnection - metadados }
    function GetTableNames(const ASchema: string = ''): TStringArray;
    function GetDatabaseNames: TStringArray;
    function GetSchemaNames(const ADatabase: string = ''): TStringArray;
    function GetColumnNames(const ATableName: string; const ASchema: string = ''): TStringArray;
    function GetTableStructure(const ATableName: string; const ASchema: string = ''): TArray<TDatabaseFields>;
  end;

{$ENDIF}

implementation

uses
  Commons.Diagnostics;

{$IFDEF USE_POOLCONNECTIONS}

{ TConnectionProxy }

constructor TConnectionProxy.Create(const ABroker: IPoolBroker;
  const AProxyId: Integer; const AData: TConnectionData);
begin
  inherited Create;
  FBroker := ABroker;
  FProxyId := AProxyId;
  FData := AData;
  FFirebirdVersion := fb50;
  FAutoDownloadDlls := False;
  FReleased := False;
  FInTransaction := False;
end;

destructor TConnectionProxy.Destroy;
begin
{$IFDEF POOL_DEBUG_TRACE}
  Writeln('    [trace] proxy ', FProxyId, ' Destroy');
{$ENDIF}
  Release; // refcount-0 devolve a worker ao pool (idempotente)
  inherited;
end;

procedure TConnectionProxy.Release;
begin
  if FReleased then
    Exit;
  FReleased := True;
  if FInTransaction then
  begin
    { transacao aberta abandonada: rollback melhor-esforco + fim do sticky }
    try
      Exec(TPoolRequest.Create(rqRollback));
    except
      { 15.3/T10: engolir aqui e deliberado (cleanup best-effort),
        mas nao pode ser MUDO - sem rasto o defeito fica invisivel. }
      on E: Exception do
        TraceSwallowed('TConnectionProxy.Release', 'cleanup best-effort', E);
    end;
    try FBroker.EndSticky(FProxyId); except end;
    FInTransaction := False;
  end;
  try FBroker.ProxyReleased(FProxyId); except end;
end;

procedure TConnectionProxy.ExecuteDirect(const AProc: TPoolDirectProc;
  const AContext: Pointer);
var
  LReq: TPoolRequest;
begin
  CheckAlive('ExecuteDirect');
  LReq := TPoolRequest.Create(rqExecuteDirect);
  LReq.DirectProc := AProc;
  LReq.DirectContext := AContext;
  Exec(LReq);
  LReq.Free;
end;

procedure TConnectionProxy.CheckAlive(const AOp: string);
begin
  if FReleased then
    raise EPoolConnectionsException.Create(
      Format(POOL_ERR_CONNECTION_INVALID_MSG, ['proxy ja devolvido ao pool - ' + AOp]),
      ERR_POOL_CONNECTION_INVALID);
end;

procedure TConnectionProxy.Exec(const AReq: TPoolRequest);
var
  LClass, LMsg: string;
  LCode: Integer;
begin
  try
    FBroker.ExecuteRequest(FProxyId, AReq);
  except
    AReq.Free;
    raise;
  end;
  if AReq.HasError then
  begin
    LClass := AReq.ErrorClass;
    LMsg := AReq.ErrorMessage;
    LCode := AReq.ErrorCode;
    AReq.Free;
    { relanca com codigo+mensagem preservados; classe de origem no texto }
    raise EPoolConnectionsException.Create('[' + LClass + '] ' + LMsg, LCode);
  end;
end;

procedure TConnectionProxy.CopyParams(const AParams: array of Variant;
  out ADest: TArray<Variant>);
var
  I: Integer;
begin
  SetLength(ADest, Length(AParams));
  for I := 0 to High(AParams) do
    ADest[I] := AParams[I];
end;

function TConnectionProxy.NotReconfigurable(const AOp: string): EPoolConnectionsException;
begin
  Result := EPoolConnectionsException.Create(
    Format(POOL_ERR_NOT_RECONFIGURABLE_MSG, [AOp]), ERR_POOL_CONFIG_INVALID);
end;

{ configuracao fluente - copia local }

function TConnectionProxy.Engine(const AValue: TDatabaseEngine): IConnection;
begin
  FData.Engine := AValue;
  Result := Self;
end;

function TConnectionProxy.Engine: TDatabaseEngine;
begin
  Result := FData.Engine;
end;

function TConnectionProxy.DatabaseType(const AValue: TDatabaseTypes): IConnection;
begin
  FData.DatabaseType := AValue;
  Result := Self;
end;

function TConnectionProxy.DatabaseType(const AValue: string): IConnection;
begin
  Result := Self; // copia local por enum; string ignorada (config e do broker)
end;

function TConnectionProxy.DatabaseType: TDatabaseTypes;
begin
  Result := FData.DatabaseType;
end;

function TConnectionProxy.Host(const AValue: string): IConnection;
begin
  FData.Host := AValue;
  Result := Self;
end;

function TConnectionProxy.Host: string;
begin
  Result := FData.Host;
end;

function TConnectionProxy.Port(const AValue: Integer): IConnection;
begin
  FData.Port := AValue;
  Result := Self;
end;

function TConnectionProxy.Port: Integer;
begin
  Result := FData.Port;
end;

function TConnectionProxy.Username(const AValue: string): IConnection;
begin
  FData.Username := AValue;
  Result := Self;
end;

function TConnectionProxy.Username: string;
begin
  Result := FData.Username;
end;

function TConnectionProxy.Password(const AValue: string): IConnection;
begin
  FData.Password := AValue;
  Result := Self;
end;

function TConnectionProxy.Password: string;
begin
  Result := FData.Password;
end;

function TConnectionProxy.Database(const AValue: string): IConnection;
begin
  FData.Database := AValue;
  Result := Self;
end;

function TConnectionProxy.Database: string;
begin
  Result := FData.Database;
end;

function TConnectionProxy.Schema(const AValue: string): IConnection;
begin
  FData.Schema := AValue;
  Result := Self;
end;

function TConnectionProxy.Schema: string;
begin
  Result := FData.Schema;
end;

function TConnectionProxy.ConfigFilePath(const AValue: string): IConnection;
begin
  FData.ConfigFilePath := AValue;
  Result := Self;
end;

function TConnectionProxy.ConfigFilePath: string;
begin
  Result := FData.ConfigFilePath;
end;

function TConnectionProxy.DllBasePath(const AValue: string): IConnection;
begin
  FData.DllBasePath := AValue;
  Result := Self;
end;

function TConnectionProxy.DllBasePath: string;
begin
  Result := FData.DllBasePath;
end;

function TConnectionProxy.AutoDownloadDlls(const AValue: Boolean): IConnection;
begin
  FAutoDownloadDlls := AValue;
  Result := Self;
end;

function TConnectionProxy.AutoDownloadDlls: Boolean;
begin
  Result := FAutoDownloadDlls;
end;

function TConnectionProxy.DllDownloadUrl(const AValue: string): IConnection;
begin
  FData.DllDownloadUrl := AValue;
  Result := Self;
end;

function TConnectionProxy.DllDownloadUrl: string;
begin
  Result := FData.DllDownloadUrl;
end;

function TConnectionProxy.FirebirdVersion(const AValue: TFirebirdVersion): IConnection;
begin
  FFirebirdVersion := AValue;
  Result := Self;
end;

function TConnectionProxy.FirebirdVersion(const AValue: string): IConnection;
begin
  Result := Self; // config real e do broker
end;

function TConnectionProxy.FirebirdVersion: TFirebirdVersion;
begin
  Result := FFirebirdVersion;
end;

function TConnectionProxy.ServerName(const AValue: string): IConnection;
begin
  FServerName := AValue;
  Result := Self; // config real e do broker
end;

function TConnectionProxy.ServerName: string;
begin
  Result := FServerName;
end;

function TConnectionProxy.SQLAnywhereDriver(const AValue: string): IConnection;
begin
  FSQLAnywhereDriver := AValue;
  Result := Self; // config real e do broker
end;

function TConnectionProxy.SQLAnywhereDriver: string;
begin
  Result := FSQLAnywhereDriver;
end;

function TConnectionProxy.IsRequiredDllFound: Boolean;
var
  LReq: TPoolRequest;
begin
  CheckAlive('IsRequiredDllFound');
  LReq := TPoolRequest.Create(rqIsRequiredDllFound);
  Exec(LReq);
  Result := LReq.ResultBool;
  LReq.Free;
end;

{ carregamento de configuracao - nao aplicavel a pooled }

function TConnectionProxy.FromIniFile(const AFilePath, ASection: string): IConnection;
begin
  raise NotReconfigurable('FromIniFile');
end;

function TConnectionProxy.FromConfig: IConnection;
begin
  raise NotReconfigurable('FromConfig');
end;

function TConnectionProxy.FromJSON(const AJSON: string): IConnection;
begin
  raise NotReconfigurable('FromJSON');
end;

{$IFDEF USE_ATTRIBUTES}
function TConnectionProxy.FromClass(const AClass: TClass): IConnection;
begin
  raise NotReconfigurable('FromClass');
end;
{$ENDIF}

{ conexao }

function TConnectionProxy.Connect: IConnection;
begin
  CheckAlive('Connect');
  { no-op: a worker do pool ja esta conectada (transparencia) }
  Result := Self;
end;

function TConnectionProxy.Disconnect: IConnection;
begin
  { transparencia: "fechar" um pooled = devolver a worker ao pool }
  Release;
  Result := Self;
end;

function TConnectionProxy.IsConnected: Boolean;
var
  LReq: TPoolRequest;
begin
  if FReleased then
    Exit(False);
  LReq := TPoolRequest.Create(rqIsConnected);
  Exec(LReq);
  Result := LReq.ResultBool;
  LReq.Free;
end;

function TConnectionProxy.Ping: Boolean;
var
  LReq: TPoolRequest;
begin
  CheckAlive('Ping');
  LReq := TPoolRequest.Create(rqPing);
  Exec(LReq);
  Result := LReq.ResultBool;
  LReq.Free;
end;

{ execucao }

function TConnectionProxy.ExecuteQuery(const ASQL: string): TDataSet;
var
  LReq: TPoolRequest;
begin
  CheckAlive('ExecuteQuery');
  LReq := TPoolRequest.Create(rqExecuteQuery);
  LReq.SQL := ASQL;
  Exec(LReq);
  Result := LReq.ResultDataSet;   // Memory DataSet desconectado (Etapa A1)
  LReq.ResultDataSet := nil;      // posse transferida para o caller
  LReq.Free;
end;

function TConnectionProxy.ExecuteQuery(const ASQL: string;
  const AParams: array of Variant): TDataSet;
var
  LReq: TPoolRequest;
begin
  CheckAlive('ExecuteQuery');
  LReq := TPoolRequest.Create(rqExecuteQueryParams);
  LReq.SQL := ASQL;
  CopyParams(AParams, LReq.Params);
  Exec(LReq);
  Result := LReq.ResultDataSet;
  LReq.ResultDataSet := nil;
  LReq.Free;
end;

function TConnectionProxy.ExecuteCommand(const ASQL: string): Integer;
var
  LReq: TPoolRequest;
begin
  CheckAlive('ExecuteCommand');
  LReq := TPoolRequest.Create(rqExecuteCommand);
  LReq.SQL := ASQL;
  Exec(LReq);
  Result := LReq.ResultInt;
  LReq.Free;
end;

function TConnectionProxy.ExecuteCommand(const ASQL: string;
  const AParams: array of Variant): Integer;
var
  LReq: TPoolRequest;
begin
  CheckAlive('ExecuteCommand');
  LReq := TPoolRequest.Create(rqExecuteCommandParams);
  LReq.SQL := ASQL;
  CopyParams(AParams, LReq.Params);
  Exec(LReq);
  Result := LReq.ResultInt;
  LReq.Free;
end;

function TConnectionProxy.ExecuteScalar(const ASQL: string): Variant;
var
  LReq: TPoolRequest;
begin
  CheckAlive('ExecuteScalar');
  LReq := TPoolRequest.Create(rqExecuteScalar);
  LReq.SQL := ASQL;
  Exec(LReq);
  Result := LReq.ResultVariant;
  LReq.Free;
end;

function TConnectionProxy.ExecuteScalar(const ASQL: string;
  const AParams: array of Variant): Variant;
var
  LReq: TPoolRequest;
begin
  CheckAlive('ExecuteScalar');
  LReq := TPoolRequest.Create(rqExecuteScalarParams);
  LReq.SQL := ASQL;
  CopyParams(AParams, LReq.Params);
  Exec(LReq);
  Result := LReq.ResultVariant;
  LReq.Free;
end;

{ transacoes - sticky sessions (pilar 7) }

function TConnectionProxy.BeginTransaction: IConnection;
var
  LReq: TPoolRequest;
begin
  CheckAlive('BeginTransaction');
  FBroker.BeginSticky(FProxyId);
  try
    LReq := TPoolRequest.Create(rqBeginTransaction);
    Exec(LReq);
    LReq.Free;
    FInTransaction := True;
  except
    try FBroker.EndSticky(FProxyId); except end;
    raise;
  end;
  Result := Self;
end;

function TConnectionProxy.Commit: IConnection;
var
  LReq: TPoolRequest;
begin
  CheckAlive('Commit');
  LReq := TPoolRequest.Create(rqCommit);
  Exec(LReq);
  LReq.Free;
  FInTransaction := False;
  FBroker.EndSticky(FProxyId);
  Result := Self;
end;

function TConnectionProxy.Rollback: IConnection;
var
  LReq: TPoolRequest;
begin
  CheckAlive('Rollback');
  LReq := TPoolRequest.Create(rqRollback);
  Exec(LReq);
  LReq.Free;
  FInTransaction := False;
  FBroker.EndSticky(FProxyId);
  Result := Self;
end;

function TConnectionProxy.InTransaction: Boolean;
var
  LReq: TPoolRequest;
begin
  if FReleased then
    Exit(False);
  LReq := TPoolRequest.Create(rqInTransaction);
  Exec(LReq);
  Result := LReq.ResultBool;
  LReq.Free;
end;

function TConnectionProxy.LockWait(const AValue: Boolean): IConnection;
begin
  { F5-FU.3 - NO WAIT e config de conexao DIRECTA (aplicada em
    ConfigureNativeConnection, antes de Connect); a pool serve DML e nao expoe o
    objecto nativo por request. Para DDL com NO WAIT usar uma IConnection directa
    (TConnection.New...LockWait(False)). No-op aqui, documentado. }
  Result := Self;
end;

function TConnectionProxy.LockWait: Boolean;
begin
  Result := True;  // WAIT (default) — a config real vive na conexao directa
end;

{ versoes }

function TConnectionProxy.GetServerVersion: string;
var
  LReq: TPoolRequest;
begin
  CheckAlive('GetServerVersion');
  LReq := TPoolRequest.Create(rqGetServerVersion);
  Exec(LReq);
  Result := LReq.ResultStr;
  LReq.Free;
end;

function TConnectionProxy.GetClientVersion: string;
var
  LReq: TPoolRequest;
begin
  CheckAlive('GetClientVersion');
  LReq := TPoolRequest.Create(rqGetClientVersion);
  Exec(LReq);
  Result := LReq.ResultStr;
  LReq.Free;
end;

{ dados }

function TConnectionProxy.GetConnectionData: TConnectionData;
begin
  Result := FData;
end;

{ metadados }

function TConnectionProxy.GetTableNames(const ASchema: string): TStringArray;
var
  LReq: TPoolRequest;
begin
  CheckAlive('GetTableNames');
  LReq := TPoolRequest.Create(rqGetTableNames);
  LReq.StrArg2 := ASchema;
  Exec(LReq);
  Result := LReq.ResultStrArr;
  LReq.Free;
end;

function TConnectionProxy.GetDatabaseNames: TStringArray;
var
  LReq: TPoolRequest;
begin
  CheckAlive('GetDatabaseNames');
  LReq := TPoolRequest.Create(rqGetDatabaseNames);
  Exec(LReq);
  Result := LReq.ResultStrArr;
  LReq.Free;
end;

function TConnectionProxy.GetSchemaNames(const ADatabase: string): TStringArray;
var
  LReq: TPoolRequest;
begin
  CheckAlive('GetSchemaNames');
  LReq := TPoolRequest.Create(rqGetSchemaNames);
  LReq.StrArg1 := ADatabase;
  Exec(LReq);
  Result := LReq.ResultStrArr;
  LReq.Free;
end;

function TConnectionProxy.GetColumnNames(const ATableName: string;
  const ASchema: string): TStringArray;
var
  LReq: TPoolRequest;
begin
  CheckAlive('GetColumnNames');
  LReq := TPoolRequest.Create(rqGetColumnNames);
  LReq.StrArg1 := ATableName;
  LReq.StrArg2 := ASchema;
  Exec(LReq);
  Result := LReq.ResultStrArr;
  LReq.Free;
end;

function TConnectionProxy.GetTableStructure(const ATableName: string;
  const ASchema: string): TArray<TDatabaseFields>;
var
  LReq: TPoolRequest;
begin
  CheckAlive('GetTableStructure');
  LReq := TPoolRequest.Create(rqGetTableStructure);
  LReq.StrArg1 := ATableName;
  LReq.StrArg2 := ASchema;
  Exec(LReq);
  Result := LReq.ResultFields;
  LReq.Free;
end;

{$ENDIF}

end.
