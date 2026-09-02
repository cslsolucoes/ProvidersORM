{ =============================================================================
  Database.Trigger - Builder FLUENTE de TRIGGERS, zero-SQL
  (TTriggerDefinition, ITriggerDefinition)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           29/07/2026

  Onda F3 (camada DDL fluente zero-SQL) - implementacao do builder de triggers
  ITriggerDefinition (declarado UNGATED em Databases.Interfaces). Descreve um
  trigger (nome, tabela, momento, eventos, granularidade, corpo) SEM uma unica
  linha de SQL cru; o DIALECTO compoe o CREATE TRIGGER especifico de cada banco
  a partir desta definicao (ver ITriggerDialect.CreateSQL(ADef) +
  TDialect.TriggerDefCreateSQL nos 6 motores com triggers - PostgreSQL/MySQL/
  SQLServer/Firebird/SQLite/SQLAnywhere; Access = N/A).

  Estilo FLUENTE (setters devolvem a propria interface) + FACTORY
  (TTriggerDefinition.New), como o resto do modulo Database. Unit UNGATED de
  proposito (nao depende de USE_DATABASE): so referencia Databases.Interfaces -
  os tipos e o builder estao sempre disponiveis para o lancador ITriggers.

  Changelog (file):
  - 1.0.0 (29/07/2026): versao inicial (Onda F3) - TTriggerDefinition.New,
    Name/OnTable/Timing/Event/Events/ForEachRow/BodyEmpty/BodyRaw/BodyMode/
    BodyText. Event acumula no conjunto; Events(set) substitui. Default:
    kind row-level (ForEachRow=True), timing ttAfter, eventos [teInsert],
    corpo tbmEmpty.
  ============================================================================= }
unit Database.Trigger;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}
interface

{$I ../../../ORM.Defines.inc}

uses
{$IF DEFINED(FPC)}
  SysUtils,
{$ELSE}
  System.SysUtils,
{$ENDIF}
  Databases.Interfaces;

type
  TTriggerDefinition = class(TInterfacedObject, ITriggerDefinition)
  private
    FName       : string;
    FTable      : string;
    FTiming     : TTriggerTiming;
    FEvents     : TTriggerEvents;
    FForEachRow : Boolean;
    FBodyMode   : TTriggerBodyMode;
    FBodyText   : string;
  public
    constructor Create;
    class function New: ITriggerDefinition;

    function Name(const AValue: string): ITriggerDefinition; overload;
    function Name: string; overload;
    function OnTable(const AValue: string): ITriggerDefinition; overload;
    function OnTable: string; overload;
    function Timing(const AValue: TTriggerTiming): ITriggerDefinition; overload;
    function Timing: TTriggerTiming; overload;
    function Event(const AValue: TTriggerEvent): ITriggerDefinition; overload;
    function Events(const AValue: TTriggerEvents): ITriggerDefinition; overload;
    function Events: TTriggerEvents; overload;
    function ForEachRow(const AValue: Boolean): ITriggerDefinition; overload;
    function ForEachRow: Boolean; overload;
    function BodyEmpty: ITriggerDefinition;
    function BodyRaw(const AValue: string): ITriggerDefinition;
    function BodyMode: TTriggerBodyMode;
    function BodyText: string;
  end;

implementation

{ TTriggerDefinition }

constructor TTriggerDefinition.Create;
begin
  inherited Create;
  FName       := '';
  FTable      := '';
  FTiming     := ttAfter;      // AFTER e o momento comum a TODOS os motores
  FEvents     := [teInsert];   // ao menos um evento por defeito
  FForEachRow := True;         // row-level por defeito (MySQL/SQLite exigem)
  FBodyMode   := tbmEmpty;
  FBodyText   := '';
end;

class function TTriggerDefinition.New: ITriggerDefinition;
begin
  Result := TTriggerDefinition.Create;
end;

function TTriggerDefinition.Name(const AValue: string): ITriggerDefinition;
begin
  FName := Trim(AValue);
  Result := Self;
end;

function TTriggerDefinition.Name: string;
begin
  Result := FName;
end;

function TTriggerDefinition.OnTable(const AValue: string): ITriggerDefinition;
begin
  FTable := Trim(AValue);
  Result := Self;
end;

function TTriggerDefinition.OnTable: string;
begin
  Result := FTable;
end;

function TTriggerDefinition.Timing(const AValue: TTriggerTiming): ITriggerDefinition;
begin
  FTiming := AValue;
  Result := Self;
end;

function TTriggerDefinition.Timing: TTriggerTiming;
begin
  Result := FTiming;
end;

function TTriggerDefinition.Event(const AValue: TTriggerEvent): ITriggerDefinition;
begin
  FEvents := FEvents + [AValue];
  Result := Self;
end;

function TTriggerDefinition.Events(const AValue: TTriggerEvents): ITriggerDefinition;
begin
  FEvents := AValue;
  Result := Self;
end;

function TTriggerDefinition.Events: TTriggerEvents;
begin
  Result := FEvents;
end;

function TTriggerDefinition.ForEachRow(const AValue: Boolean): ITriggerDefinition;
begin
  FForEachRow := AValue;
  Result := Self;
end;

function TTriggerDefinition.ForEachRow: Boolean;
begin
  Result := FForEachRow;
end;

function TTriggerDefinition.BodyEmpty: ITriggerDefinition;
begin
  FBodyMode := tbmEmpty;
  FBodyText := '';
  Result := Self;
end;

function TTriggerDefinition.BodyRaw(const AValue: string): ITriggerDefinition;
begin
  FBodyMode := tbmRaw;
  FBodyText := AValue;
  Result := Self;
end;

function TTriggerDefinition.BodyMode: TTriggerBodyMode;
begin
  Result := FBodyMode;
end;

function TTriggerDefinition.BodyText: string;
begin
  Result := FBodyText;
end;

end.
