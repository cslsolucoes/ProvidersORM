{ =============================================================================
  Database.IdentityMap - Identity Map (TIdentityMap<T>, IIdentityMap<T>)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.0.0
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           26/02/2026

  Changelog (file):
  - 1.1.0 (13/07/2026): absorcao v3 (FASE 5 Onda 2) - ProjectVersion 3.0.0, ModuleVersion 1.6.0, header v3; + TryGet (modernizacao aditiva).
  - 1.0.0 (26/02/2026): TIdentityMap<T> com FMap (TDictionary<string,T>), FOwnerList (TObjectList<T> OwnsObjects=False); Add, Get, Contains, Remove, RemoveEntity, Update, Clear, Count, GetAll; factory New (Fase 3).
  ============================================================================= }

unit Database.IdentityMap;


{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}
interface

{$I ORM.Defines.inc}

uses
{$IF DEFINED(FPC)}
  SysUtils, Variants, Generics.Collections,
{$ELSE}
  System.SysUtils, System.Variants, System.Generics.Collections,
{$ENDIF}
  Commons.Types,
  Databases.Interfaces;

type
  TIdentityMap<T: class> = class(TInterfacedObject, IIdentityMap<T>)
  private
    FMap: TDictionary<string, T>;
    FOwnerList: TObjectList<T>;
    function IdToKey(const AId: Variant): string;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: IIdentityMap<T>;

    procedure Add(const AId: Variant; const AEntity: T);
    function Get(const AId: Variant): T;
    function TryGet(const AId: Variant; out AEntity: T): Boolean;
    function Contains(const AId: Variant): Boolean;
    procedure Remove(const AId: Variant);
    procedure RemoveEntity(const AEntity: T);
    procedure Update(const AId: Variant; const AEntity: T);
    procedure Clear;
    function Count: Integer;
    function GetAll: TArray<T>;
  end;

implementation

function TIdentityMap<T>.IdToKey(const AId: Variant): string;
begin
  Result := VarToStr(AId);
end;

constructor TIdentityMap<T>.Create;
begin
  inherited Create;
  FMap := TDictionary<string, T>.Create;
  FOwnerList := TObjectList<T>.Create(False);
end;

destructor TIdentityMap<T>.Destroy;
begin
  Clear;
  FOwnerList.Free;
  FMap.Free;
  inherited;
end;

class function TIdentityMap<T>.New: IIdentityMap<T>;
begin
  Result := TIdentityMap<T>.Create;
end;

procedure TIdentityMap<T>.Add(const AId: Variant; const AEntity: T);
var
  LKey: string;
begin
  if AEntity = nil then
    Exit;
  LKey := IdToKey(AId);
  if FMap.ContainsKey(LKey) then
    Update(AId, AEntity)
  else
  begin
    FMap.Add(LKey, AEntity);
    FOwnerList.Add(AEntity);
  end;
end;

function TIdentityMap<T>.Get(const AId: Variant): T;
var
  LKey: string;
begin
  Result := nil;
  LKey := IdToKey(AId);
  if FMap.TryGetValue(LKey, Result) then
    Exit;
end;

function TIdentityMap<T>.TryGet(const AId: Variant; out AEntity: T): Boolean;
begin
  Result := FMap.TryGetValue(IdToKey(AId), AEntity);
end;

function TIdentityMap<T>.Contains(const AId: Variant): Boolean;
begin
  Result := FMap.ContainsKey(IdToKey(AId));
end;

procedure TIdentityMap<T>.Remove(const AId: Variant);
var
  LKey: string;
  LEntity: T;
begin
  LKey := IdToKey(AId);
  if FMap.TryGetValue(LKey, LEntity) then
  begin
    FMap.Remove(LKey);
    FOwnerList.Remove(LEntity);
  end;
end;

procedure TIdentityMap<T>.RemoveEntity(const AEntity: T);
var
  LPair: TPair<string, T>;
begin
  if AEntity = nil then
    Exit;
  for LPair in FMap do
    if LPair.Value = AEntity then
    begin
      FMap.Remove(LPair.Key);
      FOwnerList.Remove(AEntity);
      Exit;
    end;
end;

procedure TIdentityMap<T>.Update(const AId: Variant; const AEntity: T);
var
  LKey: string;
  LOld: T;
  i: Integer;
begin
  if AEntity = nil then
    Exit;
  LKey := IdToKey(AId);
  if FMap.TryGetValue(LKey, LOld) then
  begin
    FMap[LKey] := AEntity;
    i := FOwnerList.IndexOf(LOld);
    if i >= 0 then
      FOwnerList[i] := AEntity;
  end
  else
    Add(AId, AEntity);
end;

procedure TIdentityMap<T>.Clear;
begin
  FMap.Clear;
  FOwnerList.Clear;
end;

function TIdentityMap<T>.Count: Integer;
begin
  Result := FMap.Count;
end;

function TIdentityMap<T>.GetAll: TArray<T>;
var
  i: Integer;
begin
  SetLength(Result, FOwnerList.Count);
  for i := 0 to FOwnerList.Count - 1 do
    Result[i] := FOwnerList[i];
end;

end.
