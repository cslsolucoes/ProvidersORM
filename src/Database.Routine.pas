{ =============================================================================
  Database.Routine - Builder FLUENTE de ROTINAS (procedure/function), zero-SQL
  (TRoutineDefinition, IRoutineDefinition)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           29/07/2026

  Onda F1 (camada DDL fluente zero-SQL) - implementacao do builder de rotinas
  IRoutineDefinition (declarado UNGATED em Databases.Interfaces). Descreve uma
  procedure/function (nome, tipo, parametros, tipo de retorno, corpo) SEM uma
  unica linha de SQL cru; o DIALECTO compoe o CREATE especifico de cada banco
  a partir desta definicao (ver IRoutineDialect.CreateSQL(ADef) +
  TDialect.RoutineDefCreateSQL nos 5 motores com rotinas -
  PostgreSQL/MySQL/SQLServer/Firebird/SQLAnywhere; SQLite/Access = N/A).

  Estilo FLUENTE (setters devolvem a propria interface) + FACTORY
  (TRoutineDefinition.New), como o resto do modulo Database. Unit UNGATED de
  proposito (nao depende de USE_DATABASE): so referencia Commons.Database.Types
  e Databases.Interfaces - os tipos e o builder estao sempre disponiveis para
  os lancadores IProcedures/IFunctions (tambem ungated).

  Changelog (file):
  - 1.0.0 (29/07/2026): versao inicial (Onda F1) - TRoutineDefinition.New,
    Name/Kind/Param/Params/Returns/ReturnKind/ReturnSize/BodyEmpty/BodyReturn/
    BodyRaw/BodyMode/BodyText. BodyReturn(Variant) renderiza o literal (numerico
    sem aspas, booleano 0/1, string com aspas) para BodyText.
  ============================================================================= }
unit Database.Routine;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}
interface

{$I ORM.Defines.inc}

uses
{$IF DEFINED(FPC)}
  SysUtils,
  Variants,
{$ELSE}
  System.SysUtils,
  System.Variants,
{$ENDIF}
  Commons.Database.Types,
  Databases.Interfaces;

type
  TRoutineDefinition = class(TInterfacedObject, IRoutineDefinition)
  private
    FName       : string;
    FKind       : TRoutineKind;
    FParams     : TRoutineParamArray;
    FReturnKind : TSQLColumnKind;
    FReturnSize : Integer;
    FBodyMode   : TRoutineBodyMode;
    FBodyText   : string;
  public
    constructor Create;
    class function New: IRoutineDefinition;

    function Name(const AValue: string): IRoutineDefinition; overload;
    function Name: string; overload;
    function Kind(const AValue: TRoutineKind): IRoutineDefinition; overload;
    function Kind: TRoutineKind; overload;
    function Param(const AName: string; const AKind: TSQLColumnKind;
      const ASize: Integer = 0; const ADirection: TParamDirection = pdIn): IRoutineDefinition;
    function Params: TRoutineParamArray;
    function Returns(const AKind: TSQLColumnKind; const ASize: Integer = 0): IRoutineDefinition;
    function ReturnKind: TSQLColumnKind;
    function ReturnSize: Integer;
    function BodyEmpty: IRoutineDefinition;
    function BodyReturn(const AValue: Variant): IRoutineDefinition;
    function BodyRaw(const AValue: string): IRoutineDefinition;
    function BodyMode: TRoutineBodyMode;
    function BodyText: string;
  end;

implementation

{ helper: renderiza um Variant como literal SQL para o corpo RETURN (numerico
  sem aspas; booleano -> 1/0; NULL/Empty -> NULL; caso contrario string com
  aspas simples escapadas). So BodyReturn o usa. }
function VariantToRoutineLiteral(const AValue: Variant): string;
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
    Result := 'NULL'
  else if VarIsType(AValue, varBoolean) then
  begin
    if Boolean(AValue) then
      Result := '1'
    else
      Result := '0';
  end
  else if VarIsOrdinal(AValue) then
    Result := VarToStr(AValue)
  else if VarIsFloat(AValue) then
    Result := StringReplace(FloatToStr(Double(AValue)), ',', '.', [rfReplaceAll])
  else
    Result := '''' + StringReplace(VarToStr(AValue), '''', '''''', [rfReplaceAll]) + '''';
end;

{ TRoutineDefinition }

constructor TRoutineDefinition.Create;
begin
  inherited Create;
  FName := '';
  FKind := rkProcedure;
  SetLength(FParams, 0);
  FReturnKind := ckInteger;
  FReturnSize := 0;
  FBodyMode := rbmEmpty;
  FBodyText := '';
end;

class function TRoutineDefinition.New: IRoutineDefinition;
begin
  Result := TRoutineDefinition.Create;
end;

function TRoutineDefinition.Name(const AValue: string): IRoutineDefinition;
begin
  FName := Trim(AValue);
  Result := Self;
end;

function TRoutineDefinition.Name: string;
begin
  Result := FName;
end;

function TRoutineDefinition.Kind(const AValue: TRoutineKind): IRoutineDefinition;
begin
  FKind := AValue;
  Result := Self;
end;

function TRoutineDefinition.Kind: TRoutineKind;
begin
  Result := FKind;
end;

function TRoutineDefinition.Param(const AName: string; const AKind: TSQLColumnKind;
  const ASize: Integer; const ADirection: TParamDirection): IRoutineDefinition;
var
  LIdx: Integer;
begin
  LIdx := Length(FParams);
  SetLength(FParams, LIdx + 1);
  FParams[LIdx].Name := Trim(AName);
  FParams[LIdx].Kind := AKind;
  FParams[LIdx].Size := ASize;
  FParams[LIdx].Direction := ADirection;
  Result := Self;
end;

function TRoutineDefinition.Params: TRoutineParamArray;
begin
  Result := FParams;
end;

function TRoutineDefinition.Returns(const AKind: TSQLColumnKind; const ASize: Integer): IRoutineDefinition;
begin
  FReturnKind := AKind;
  FReturnSize := ASize;
  Result := Self;
end;

function TRoutineDefinition.ReturnKind: TSQLColumnKind;
begin
  Result := FReturnKind;
end;

function TRoutineDefinition.ReturnSize: Integer;
begin
  Result := FReturnSize;
end;

function TRoutineDefinition.BodyEmpty: IRoutineDefinition;
begin
  FBodyMode := rbmEmpty;
  FBodyText := '';
  Result := Self;
end;

function TRoutineDefinition.BodyReturn(const AValue: Variant): IRoutineDefinition;
begin
  FBodyMode := rbmReturn;
  FBodyText := VariantToRoutineLiteral(AValue);
  Result := Self;
end;

function TRoutineDefinition.BodyRaw(const AValue: string): IRoutineDefinition;
begin
  FBodyMode := rbmRaw;
  FBodyText := AValue;
  Result := Self;
end;

function TRoutineDefinition.BodyMode: TRoutineBodyMode;
begin
  Result := FBodyMode;
end;

function TRoutineDefinition.BodyText: string;
begin
  Result := FBodyText;
end;

end.
