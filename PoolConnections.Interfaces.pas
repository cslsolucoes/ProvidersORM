{ =============================================================================
  PoolConnections.Interfaces - Contrato do Broker Elastico (IPoolConnections)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  2.2.0
  FileVersion:    1.2.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           09/08/2026

  Todas as interfaces do modulo num ficheiro (regra do owner 06/07). Os
  contratos de FRONTEIRA cross-modulo (IPoolBroker, IPooledConnection,
  TPoolRequest) vivem em Commons.PoolConnections.Types (DIP - o proxy do
  modulo Connections nao pode depender deste modulo).

  Paridade D10 com o v2.3.0: os 7 metodos originais de IPoolConnections
  (GetFromPool/ReturnToPool/Add/TryAdd/Remove/Count/Clear) + extras da classe
  promovidos a interface (GetByIndex/GetByName/GetPoolList) + os 9 eventos como
  setters fluentes. Aditivos do broker: catalogo heterogeneo por banco,
  GetFromPool com rastreio, Config/Metrics/HardwareInfo/ActiveLeases/QueueDepth,
  Shutdown, OnPoolExhausted.

  Nota de semantica (broker vs container v2): GetByIndex/GetByName ADQUIREM um
  lease sobre a worker alvo se ela estiver livre (devolvem o proxy) e nil se
  ocupada; GetPoolList e um snapshot INFORMATIVO (Connection=nil - a fisica
  nunca sai do pool). Divergencia registada na matriz D10 (capacidade mantida,
  semantica broker).

  Changelog (file):
  - 1.2.0 (09/08/2026): F8 Onda 8.6 -- setter fluente SetLogger(const ALogger:
    ILogger): IPoolConnections, guardado por USE_LOGGERS. Ver
    PoolConnections.pas para a implementacao (piggyback nos hooks
    OnBeforeAdd/OnAfterAdd/OnPoolExhausted/OnConnectionLeak ja existentes).
  - 1.1.0 (11/07/2026): Onda 4.3b - setter OnConnectionLeak (housekeeper).
  - 1.0.0 (10/07/2026): versao inicial (Onda 4.3 Etapa B).
  ============================================================================= }
unit PoolConnections.Interfaces;

{$I ../../ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$IFDEF USE_POOLCONNECTIONS}

uses
{$IFDEF FPC}
  Classes,
{$ELSE}
  System.Classes,
{$ENDIF}
  Commons.Types,
  Commons.PoolConnections.Types,
  Connections.Interfaces
{$IFDEF USE_LOGGERS}
  , Loggers.Interfaces // F8 Onda 8.6 -- SetLogger
{$ENDIF}
  ;

type
  IPoolConnections = interface
    ['{7E4A1B2C-9D3E-4F50-A6B7-C8D9E0F1A2B3}']

    { ---- Paridade v2.3.0 (D10) ---- }
    function GetFromPool: IConnection; overload;
    function ReturnToPool(const AConnection: IConnection): IPoolConnections;
    function Add(const AConnection: IConnection): IPoolConnections;
    function TryAdd(const AConnection: IConnection): Boolean;
    function Remove(const AConnection: IConnection): IPoolConnections;
    function Count: Integer;
    function Clear: IPoolConnections;
    function GetByIndex(const AIndex: Integer): IConnection;
    function GetByName(const AName: string): IConnection;
    function GetPoolList: TPools;

    { ---- Catalogo heterogeneo (multi-tenant) ---- }
    function AddDatabase(const AName: string; const AConfig: TConnectionData): IPoolConnections;
    function FromJSON(const AName, AJSON: string): IPoolConnections;
    function FromIniFile(const AName, AFilePath, ASection: string): IPoolConnections;
    function Factory(const AValue: TPoolConnectionFactory): IPoolConnections;

    { ---- Aquisicao (transparente: devolve o Proxy, NUNCA a fisica) ---- }
    function GetFromPool(const ADatabaseName: string): IConnection; overload;
    function GetFromPool(const ADatabaseName, AOwner, AOperation: string): IConnection; overload;

    { ---- Configuracao e observabilidade ---- }
    function Config(const AValue: TPoolConfig): IPoolConnections; overload;
    function Config: TPoolConfig; overload;
    function Metrics: TPoolMetrics;
    function HardwareInfo: TPoolHardwareInfo;
    function ActiveLeases: TPoolLeases;
    function QueueDepth(const ADatabaseName: string): Integer;

    { ---- Ciclo de vida (guardiao) ---- }
    procedure Shutdown;

    { ---- Eventos (9 da paridade v2 + broker), setters fluentes ---- }
    function OnBeforeAdd(const AValue: TPoolConnectionEvent): IPoolConnections;
    function OnAfterAdd(const AValue: TPoolConnectionEvent): IPoolConnections;
    function OnBeforeRemove(const AValue: TPoolConnectionEvent): IPoolConnections;
    function OnAfterRemove(const AValue: TPoolConnectionEvent): IPoolConnections;
    function OnBeforeGetFromPool(const AValue: TNotifyEvent): IPoolConnections;
    function OnAfterGetFromPool(const AValue: TPoolConnectionEvent): IPoolConnections;
    function OnBeforeReturnToPool(const AValue: TPoolConnectionEvent): IPoolConnections;
    function OnAfterReturnToPool(const AValue: TPoolConnectionEvent): IPoolConnections;
    function OnClear(const AValue: TNotifyEvent): IPoolConnections;
    function OnPoolExhausted(const AValue: TPoolExhaustedEvent): IPoolConnections;
    function OnConnectionLeak(const AValue: TPoolLeakEvent): IPoolConnections;

{$IFDEF USE_LOGGERS}
    { F8 Onda 8.6 - injeta ILogger para observabilidade estrutural do broker.
      Piggyback nos hooks ja existentes acima (OnBeforeAdd/OnAfterAdd Debug;
      OnPoolExhausted/OnConnectionLeak Warning) - nenhum ponto de chamada
      novo. Default = TNullLogger (zero overhead). }
    function SetLogger(const ALogger: ILogger): IPoolConnections;
{$ENDIF}
  end;

{$ENDIF}

implementation

end.
