{ =============================================================================
  Database.Rule - Builder FLUENTE de RULES, zero-SQL
  (TRuleDefinition, IRuleDefinition)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           29/07/2026

  Onda F4 (camada DDL fluente zero-SQL) - implementacao do builder de RULES
  IRuleDefinition (declarado UNGATED em Databases.Interfaces). O objecto RULE
  existe APENAS em PostgreSQL (query-rewrite) e SQL Server (constraint de valor,
  legado) - o dialecto compoe o CREATE RULE especifico a partir desta definicao
  (IRuleDialect.CreateSQL -> TDialect.RuleDefCreateSQL nos 2 motores; os outros
  5 devolvem '' = N/A).

  Estilo FLUENTE (setters devolvem a propria interface) + FACTORY
  (TRuleDefinition.New). Unit UNGATED (paralelo a Database.Trigger): so
  referencia Databases.Interfaces.

  Changelog (file):
  - 1.0.0 (29/07/2026): versao inicial (Onda F4) - TRuleDefinition.New, Name/
    OnTable/Event/BodyRaw/BodyText. Default: evento reInsert, corpo vazio (o
    dialecto aplica o default seguro por banco - PG 'INSTEAD NOTHING', SQL
    Server '@val >= 0').
  ============================================================================= }
unit Database.Rule;

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
  TRuleDefinition = class(TInterfacedObject, IRuleDefinition)
  private
    FName     : string;
    FTable    : string;
    FEvent    : TRuleEvent;
    FBodyText : string;
  public
    constructor Create;
    class function New: IRuleDefinition;

    function Name(const AValue: string): IRuleDefinition; overload;
    function Name: string; overload;
    function OnTable(const AValue: string): IRuleDefinition; overload;
    function OnTable: string; overload;
    function Event(const AValue: TRuleEvent): IRuleDefinition; overload;
    function Event: TRuleEvent; overload;
    function BodyRaw(const AValue: string): IRuleDefinition;
    function BodyText: string;
  end;

implementation

{ TRuleDefinition }

constructor TRuleDefinition.Create;
begin
  inherited Create;
  FName     := '';
  FTable    := '';
  FEvent    := reInsert;
  FBodyText := '';
end;

class function TRuleDefinition.New: IRuleDefinition;
begin
  Result := TRuleDefinition.Create;
end;

function TRuleDefinition.Name(const AValue: string): IRuleDefinition;
begin
  FName := Trim(AValue);
  Result := Self;
end;

function TRuleDefinition.Name: string;
begin
  Result := FName;
end;

function TRuleDefinition.OnTable(const AValue: string): IRuleDefinition;
begin
  FTable := Trim(AValue);
  Result := Self;
end;

function TRuleDefinition.OnTable: string;
begin
  Result := FTable;
end;

function TRuleDefinition.Event(const AValue: TRuleEvent): IRuleDefinition;
begin
  FEvent := AValue;
  Result := Self;
end;

function TRuleDefinition.Event: TRuleEvent;
begin
  Result := FEvent;
end;

function TRuleDefinition.BodyRaw(const AValue: string): IRuleDefinition;
begin
  FBodyText := AValue;
  Result := Self;
end;

function TRuleDefinition.BodyText: string;
begin
  Result := FBodyText;
end;

end.
