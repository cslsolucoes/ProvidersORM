{ =============================================================================
  Attributers.Database.Registry - Registo central de classes [Table] com cache
  de ITable por classe/tipo de banco

  Absorvido de ProvidersORM v2.3.0 Attributers.Providers.Registry.pas (FASE 6
  Onda 6.1) - renomeado Providers->Database (regra D5); uses actualizados para
  os nomes v3 (Database.Table.Interfaces->Databases.Interfaces, Reorg 1).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.3.1 (Database - modulo que estes atributos mapeiam)
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.0.0 (03/08/2026): FASE 6 Onda 6.1 - absorvido de Attributers.Providers.Registry.pas
    (SSOT v2.2.0), fiel ao original (TAttributeRegistry: GetTable/Unregister/Clear;
    cache por (TClass, TDatabaseTypes)).
  ============================================================================= }

unit Attributers.Database.Registry;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../ORM.Defines.inc}

{$IFDEF USE_ATTRIBUTES}
uses
  Attributers.Database.Interfaces,
  Commons.Types,
  Databases.Interfaces;

var
  { Instancia singleton do registo (cache de ITable por classe/tipo de banco). }
  AttributeRegistry: IAttributeRegistry;

function GetAttributeRegistry: IAttributeRegistry;
{$ENDIF}

implementation

{$IFDEF USE_ATTRIBUTES}
uses
{$IF DEFINED(FPC)}
  SysUtils, Generics.Collections,
{$ELSE}
  System.SysUtils, System.Generics.Collections,
{$ENDIF}
  Attributers.Database;

type
  TAttributeRegistry = class(TInterfacedObject, IAttributeRegistry)
  strict private
    FCache: TDictionary<string, ITable>;
    function CacheKey(const AClass: TClass; const ADatabaseType: TDatabaseTypes): string;
  public
    constructor Create;
    destructor Destroy; override;
    function GetTable(const AClass: TClass; const ADatabaseType: TDatabaseTypes): ITable;
    procedure Unregister(const AClass: TClass);
    procedure Clear;
  end;

function TAttributeRegistry.CacheKey(const AClass: TClass; const ADatabaseType: TDatabaseTypes): string;
begin
  Result := Format('%p|%d', [Pointer(AClass), Ord(ADatabaseType)]);
end;

constructor TAttributeRegistry.Create;
begin
  inherited Create;
  FCache := TDictionary<string, ITable>.Create;
end;

destructor TAttributeRegistry.Destroy;
begin
  FCache.Free;
  inherited;
end;

function TAttributeRegistry.GetTable(const AClass: TClass; const ADatabaseType: TDatabaseTypes): ITable;
var
  LKey: string;
begin
  Result := nil;
  if AClass = nil then
    Exit;
  LKey := CacheKey(AClass, ADatabaseType);
  if FCache.TryGetValue(LKey, Result) then
    Exit;
  if AttributeMapper = nil then
    Exit;
  Result := AttributeMapper.FromClass(AClass, ADatabaseType);
  if Result <> nil then
    FCache.Add(LKey, Result);
end;

procedure TAttributeRegistry.Unregister(const AClass: TClass);
var
  LKeysToRemove: TList<string>;
  LKey: string;
  LPrefix: string;
begin
  if AClass = nil then
    Exit;
  LPrefix := Format('%p|', [Pointer(AClass)]);
  LKeysToRemove := TList<string>.Create;
  try
    for LKey in FCache.Keys do
      if (Length(LKey) >= Length(LPrefix)) and (Copy(LKey, 1, Length(LPrefix)) = LPrefix) then
        LKeysToRemove.Add(LKey);
    for LKey in LKeysToRemove do
      FCache.Remove(LKey);
  finally
    LKeysToRemove.Free;
  end;
end;

procedure TAttributeRegistry.Clear;
begin
  FCache.Clear;
end;

function GetAttributeRegistry: IAttributeRegistry;
begin
  if AttributeRegistry = nil then
    AttributeRegistry := TAttributeRegistry.Create;
  Result := AttributeRegistry;
end;

initialization
  AttributeRegistry := nil;
{$ENDIF}

end.
