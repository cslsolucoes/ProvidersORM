{ =============================================================================
  Attributers.Loggers - Parser de atributos RTTI (TLoggerAttributeParser) para
  o mapeamento Classe -> ILogger (nivel de classe) + introspeccao (nivel de
  propriedade)

  FASE 6 Onda 6.3. Ver Attributers.Loggers.Interfaces.pas para a nota completa
  sobre o escopo reduzido (decisao do owner, 03/08): o ILogger do v3 e' um
  nucleo fan-out sobre canais configurados via IParameters, nao um logger
  monolitico com setters fluentes por-campo (FilePath/FileMaxSize/Format/
  Destinations/...) como na SSOT v2.2.0 - por isso NAO ha TLoggerAttributeMapper
  aqui (nada com sentido para "aplicar" de volta a um ILogger real).
  ParseClass usa TLoggers.New (Loggers.pas) - fabrica que ja auto-regista os
  canais baseline; este ficheiro so' define o MinLevel a partir do atributo
  [LoggerLevel].

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.10.0 (Loggers - modulo que estes atributos mapeiam)
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.0.0 (03/08/2026): FASE 6 Onda 6.3 - TLoggerAttributeParser (ParseClass/
    GetLoggerName/GetLoggerLevel/GetLoggerCategory/GetLoggerProperties/
    GetPropertyKey/GetPropertyDefaultValue/GetPropertyDescription/
    IsPropertyRequired/ValidateClass).
  ============================================================================= }

unit Attributers.Loggers;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../ORM.Defines.inc}

uses
  Attributers.Loggers.Interfaces,
  Commons.Types,
  Commons.Loggers.Types,
  Loggers.Interfaces,
  Exceptions.Loggers,
{$IF DEFINED(FPC)}
  Rtti;
{$ELSE}
  System.RTTI;
{$ENDIF}

{$IFDEF USE_LOGGERS}
{$IFDEF USE_ATTRIBUTES}
type
  TLoggerAttributeParser = class(TInterfacedObject, ILoggerAttributeParser)
  private
    FRttiContext: TRttiContext;
    function GetRttiType(const AClassType: TClass): TRttiType;
    function GetLoggerAttribute(const ARttiType: TRttiType): LoggerAttribute;
    function GetLoggerLevelAttribute(const ARttiType: TRttiType): LoggerLevelAttribute;
    function GetLoggerCategoryAttribute(const ARttiType: TRttiType): LoggerCategoryAttribute;
    function GetAttribute<T: TCustomAttribute>(const ARttiProperty: TRttiProperty): T;
    function HasAttribute<T: TCustomAttribute>(const ARttiProperty: TRttiProperty): Boolean;
    function CreateLoggerNotFoundException(const AClassName: string): ELoggersAttributeException;
    function CreateRTTINotAvailableException(const AClassName: string): ELoggersAttributeException;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: ILoggerAttributeParser;
    function ParseClass(const AClassType: TClass): ILogger; overload;
    function ParseClass(const AInstance: TObject): ILogger; overload;
    function GetLoggerName(const AClassType: TClass): string; overload;
    function GetLoggerName(const AInstance: TObject): string; overload;
    function GetLoggerLevel(const AClassType: TClass): TLogLevel; overload;
    function GetLoggerLevel(const AInstance: TObject): TLogLevel; overload;
    function GetLoggerCategory(const AClassType: TClass): string; overload;
    function GetLoggerCategory(const AInstance: TObject): string; overload;
    function GetLoggerProperties(const AClassType: TClass): Commons.Types.TStringArray; overload;
    function GetLoggerProperties(const AInstance: TObject): Commons.Types.TStringArray; overload;
    function GetPropertyKey(const AInstance: TObject; const APropertyName: string): string;
    function GetPropertyDefaultValue(const AInstance: TObject; const APropertyName: string): string;
    function GetPropertyDescription(const AInstance: TObject; const APropertyName: string): string;
    function IsPropertyRequired(const AInstance: TObject; const APropertyName: string): Boolean;
    function ValidateClass(const AClassType: TClass): Boolean; overload;
    function ValidateClass(const AInstance: TObject): Boolean; overload;
  end;

var
  { Instancia singleton do parser (criada na primeira leitura). }
  LoggerAttributeParser: ILoggerAttributeParser;
{$ENDIF}
{$ENDIF}

implementation

{$IFDEF USE_LOGGERS}
{$IFDEF USE_ATTRIBUTES}
uses
{$IF DEFINED(FPC)}
  SysUtils, TypInfo,
{$ELSE}
  System.SysUtils, System.TypInfo,
{$ENDIF}
  Loggers;

constructor TLoggerAttributeParser.Create;
begin
  inherited Create;
  FRttiContext := TRttiContext.Create;
end;

destructor TLoggerAttributeParser.Destroy;
begin
  FRttiContext.Free;
  inherited Destroy;
end;

class function TLoggerAttributeParser.New: ILoggerAttributeParser;
begin
  Result := TLoggerAttributeParser.Create;
end;

function TLoggerAttributeParser.GetRttiType(const AClassType: TClass): TRttiType;
begin
  Result := FRttiContext.GetType(AClassType);
  if Result = nil then
    raise CreateRTTINotAvailableException(AClassType.ClassName);
end;

function TLoggerAttributeParser.GetLoggerAttribute(const ARttiType: TRttiType): LoggerAttribute;
var
  LAttr: TCustomAttribute;
begin
  Result := nil;
  for LAttr in ARttiType.GetAttributes do
    if LAttr is LoggerAttribute then
    begin
      Result := LoggerAttribute(LAttr);
      Exit;
    end;
end;

function TLoggerAttributeParser.GetLoggerLevelAttribute(const ARttiType: TRttiType): LoggerLevelAttribute;
var
  LAttr: TCustomAttribute;
begin
  Result := nil;
  for LAttr in ARttiType.GetAttributes do
    if LAttr is LoggerLevelAttribute then
    begin
      Result := LoggerLevelAttribute(LAttr);
      Exit;
    end;
end;

function TLoggerAttributeParser.GetLoggerCategoryAttribute(const ARttiType: TRttiType): LoggerCategoryAttribute;
var
  LAttr: TCustomAttribute;
begin
  Result := nil;
  for LAttr in ARttiType.GetAttributes do
    if LAttr is LoggerCategoryAttribute then
    begin
      Result := LoggerCategoryAttribute(LAttr);
      Exit;
    end;
end;

function TLoggerAttributeParser.HasAttribute<T>(const ARttiProperty: TRttiProperty): Boolean;
var
  LAttr: TCustomAttribute;
begin
  Result := False;
  for LAttr in ARttiProperty.GetAttributes do
    if LAttr is T then
    begin
      Result := True;
      Exit;
    end;
end;

function TLoggerAttributeParser.GetAttribute<T>(const ARttiProperty: TRttiProperty): T;
var
  LAttr: TCustomAttribute;
begin
  Result := nil;
  for LAttr in ARttiProperty.GetAttributes do
    if LAttr is T then
    begin
      Result := T(LAttr);
      Exit;
    end;
end;

function TLoggerAttributeParser.CreateLoggerNotFoundException(const AClassName: string): ELoggersAttributeException;
begin
  Result := ELoggersAttributeException.Create(
    Format('Classe %s nao possui atributo [Logger]', [AClassName]),
    ERR_LOGGERS_ATTRIBUTE_NOT_FOUND
  );
end;

function TLoggerAttributeParser.CreateRTTINotAvailableException(const AClassName: string): ELoggersAttributeException;
var
  LMsg: string;
begin
  if AClassName = '' then
    LMsg := 'RTTI nao disponivel'
  else
    LMsg := Format('RTTI nao disponivel para classe %s', [AClassName]);
  Result := ELoggersAttributeException.Create(LMsg, ERR_LOGGERS_ATTRIBUTE_RTTI_NOT_AVAILABLE);
end;

function TLoggerAttributeParser.ParseClass(const AClassType: TClass): ILogger;
var
  LRttiType: TRttiType;
  LLoggerAttr: LoggerAttribute;
  LLevelAttr: LoggerLevelAttribute;
begin
  LRttiType := GetRttiType(AClassType);
  LLoggerAttr := GetLoggerAttribute(LRttiType);
  if LLoggerAttr = nil then
    raise CreateLoggerNotFoundException(AClassType.ClassName);
  Result := TLoggers.New;
  LLevelAttr := GetLoggerLevelAttribute(LRttiType);
  if LLevelAttr <> nil then
    Result.MinLevel(LLevelAttr.Level);
end;

function TLoggerAttributeParser.ParseClass(const AInstance: TObject): ILogger;
begin
  if AInstance = nil then
    raise CreateRTTINotAvailableException('');
  Result := ParseClass(AInstance.ClassType);
end;

function TLoggerAttributeParser.GetLoggerName(const AClassType: TClass): string;
var
  LRttiType: TRttiType;
  LLoggerAttr: LoggerAttribute;
begin
  LRttiType := GetRttiType(AClassType);
  LLoggerAttr := GetLoggerAttribute(LRttiType);
  if LLoggerAttr = nil then
    raise CreateLoggerNotFoundException(AClassType.ClassName);
  Result := LLoggerAttr.Name;
end;

function TLoggerAttributeParser.GetLoggerName(const AInstance: TObject): string;
begin
  if AInstance = nil then
    raise CreateRTTINotAvailableException('');
  Result := GetLoggerName(AInstance.ClassType);
end;

function TLoggerAttributeParser.GetLoggerLevel(const AClassType: TClass): TLogLevel;
var
  LRttiType: TRttiType;
  LLevelAttr: LoggerLevelAttribute;
begin
  Result := llInfo;
  LRttiType := GetRttiType(AClassType);
  LLevelAttr := GetLoggerLevelAttribute(LRttiType);
  if LLevelAttr <> nil then
    Result := LLevelAttr.Level;
end;

function TLoggerAttributeParser.GetLoggerLevel(const AInstance: TObject): TLogLevel;
begin
  if AInstance = nil then
    raise CreateRTTINotAvailableException('');
  Result := GetLoggerLevel(AInstance.ClassType);
end;

function TLoggerAttributeParser.GetLoggerCategory(const AClassType: TClass): string;
var
  LRttiType: TRttiType;
  LCategoryAttr: LoggerCategoryAttribute;
  LLoggerAttr: LoggerAttribute;
begin
  LRttiType := GetRttiType(AClassType);
  LCategoryAttr := GetLoggerCategoryAttribute(LRttiType);
  if LCategoryAttr <> nil then
    Result := LCategoryAttr.Category
  else
  begin
    LLoggerAttr := GetLoggerAttribute(LRttiType);
    if LLoggerAttr <> nil then
      Result := LLoggerAttr.Name
    else
      Result := '';
  end;
end;

function TLoggerAttributeParser.GetLoggerCategory(const AInstance: TObject): string;
begin
  if AInstance = nil then
    raise CreateRTTINotAvailableException('');
  Result := GetLoggerCategory(AInstance.ClassType);
end;

function TLoggerAttributeParser.GetLoggerProperties(const AClassType: TClass): Commons.Types.TStringArray;
var
  LRttiType: TRttiType;
  LProperty: TRttiProperty;
  LKeyAttr: LoggerKeyAttribute;
  LCount: Integer;
begin
  SetLength(Result, 0);
  LRttiType := GetRttiType(AClassType);
  LCount := 0;
  for LProperty in LRttiType.GetProperties do
  begin
    LKeyAttr := GetAttribute<LoggerKeyAttribute>(LProperty);
    if (LKeyAttr <> nil) and (LKeyAttr.Key <> '') then
    begin
      SetLength(Result, LCount + 1);
      Result[LCount] := LProperty.Name;
      Inc(LCount);
    end;
  end;
end;

function TLoggerAttributeParser.GetLoggerProperties(const AInstance: TObject): Commons.Types.TStringArray;
begin
  if AInstance = nil then
    raise CreateRTTINotAvailableException('');
  Result := GetLoggerProperties(AInstance.ClassType);
end;

function TLoggerAttributeParser.GetPropertyKey(const AInstance: TObject; const APropertyName: string): string;
var
  LRttiType: TRttiType;
  LProperty: TRttiProperty;
  LKeyAttr: LoggerKeyAttribute;
begin
  Result := '';
  if AInstance = nil then
    Exit;
  LRttiType := GetRttiType(AInstance.ClassType);
  LProperty := LRttiType.GetProperty(APropertyName);
  if LProperty = nil then
    Exit;
  LKeyAttr := GetAttribute<LoggerKeyAttribute>(LProperty);
  if LKeyAttr <> nil then
    Result := LKeyAttr.Key;
end;

function TLoggerAttributeParser.GetPropertyDefaultValue(const AInstance: TObject; const APropertyName: string): string;
var
  LRttiType: TRttiType;
  LProperty: TRttiProperty;
  LValueAttr: LoggerValueAttribute;
begin
  Result := '';
  if AInstance = nil then
    Exit;
  LRttiType := GetRttiType(AInstance.ClassType);
  LProperty := LRttiType.GetProperty(APropertyName);
  if LProperty = nil then
    Exit;
  LValueAttr := GetAttribute<LoggerValueAttribute>(LProperty);
  if LValueAttr <> nil then
    Result := LValueAttr.Value;
end;

function TLoggerAttributeParser.GetPropertyDescription(const AInstance: TObject; const APropertyName: string): string;
var
  LRttiType: TRttiType;
  LProperty: TRttiProperty;
  LDescAttr: LoggerDescriptionAttribute;
begin
  Result := '';
  if AInstance = nil then
    Exit;
  LRttiType := GetRttiType(AInstance.ClassType);
  LProperty := LRttiType.GetProperty(APropertyName);
  if LProperty = nil then
    Exit;
  LDescAttr := GetAttribute<LoggerDescriptionAttribute>(LProperty);
  if LDescAttr <> nil then
    Result := LDescAttr.Description;
end;

function TLoggerAttributeParser.IsPropertyRequired(const AInstance: TObject; const APropertyName: string): Boolean;
var
  LRttiType: TRttiType;
  LProperty: TRttiProperty;
begin
  Result := False;
  if AInstance = nil then
    Exit;
  LRttiType := GetRttiType(AInstance.ClassType);
  LProperty := LRttiType.GetProperty(APropertyName);
  if LProperty = nil then
    Exit;
  Result := HasAttribute<LoggerRequiredAttribute>(LProperty);
end;

function TLoggerAttributeParser.ValidateClass(const AClassType: TClass): Boolean;
var
  LRttiType: TRttiType;
  LLoggerAttr: LoggerAttribute;
begin
  Result := False;
  try
    LRttiType := GetRttiType(AClassType);
    LLoggerAttr := GetLoggerAttribute(LRttiType);
    Result := (LLoggerAttr <> nil);
  except
    Result := False;
  end;
end;

function TLoggerAttributeParser.ValidateClass(const AInstance: TObject): Boolean;
begin
  if AInstance = nil then
    raise CreateRTTINotAvailableException('');
  Result := ValidateClass(AInstance.ClassType);
end;

{ Inicializacao }

procedure CreateLoggerAttributeParser;
begin
  if LoggerAttributeParser = nil then
    LoggerAttributeParser := TLoggerAttributeParser.Create;
end;

initialization
  CreateLoggerAttributeParser;
{$ENDIF}
{$ENDIF}

end.
