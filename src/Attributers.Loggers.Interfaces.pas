{ =============================================================================
  Attributers.Loggers.Interfaces - Atributos RTTI + contrato do mapeamento
  Classe -> ILogger ([Logger]/[LoggerLevel]/[LoggerCategory]) ao nivel de
  CLASSE, com introspeccao (nao aplicacao) ao nivel de PROPRIEDADE

  FASE 6 Onda 6.3. Absorvido da SSOT v2.2.0 (E:\Dropbox\CSL\ProvidersORM\
  src\Attributers\Attributers.Loggers.Interfaces.pas) com ESCOPO REDUZIDO
  (decisao do owner via AskUserQuestion, 03/08): o ILogger do v3 (F8,
  Loggers.Interfaces.pas) e' um NUCLEO FAN-OUT sobre canais (RegisterChannel/
  MinLevel/Log*/Flush) - cada canal (ILoggerChannel: Database/TextFile/Json/
  Http/...) configura-se via IParameters, NAO via setters fluentes no
  ILogger. O ILogger da SSOT v2.2.0 era MONOLITICO (.FilePath/.FileMaxSize/
  .Format/.Destinations/.DatabaseConnection/.MemTable) - esses metodos NAO
  EXISTEM no v3, por isso a logica de APLICACAO por propriedade
  (ApplyPropertyToLogger/ApplyLoggerConfigToProperty/MapLoggerToClass/
  SetConfigValue/GetConfigValue da SSOT) NAO FOI PORTADA (nao tem alvo
  valido - portar dava codigo enganoso, "parece funcional, e' no-op").
  Absorvido: nivel de CLASSE ([Logger]/[LoggerLevel]/[LoggerCategory] ->
  ParseClass devolve um ILogger real via TLoggers.New com MinLevel definido)
  + nivel de PROPRIEDADE como INTROSPECCAO pura (GetLoggerProperties/
  GetPropertyKey/GetPropertyDefaultValue/GetPropertyDescription/
  IsPropertyRequired - mesma forma do IAttributeParser da Onda 6.2, sem
  IAttributeMapper porque nao ha "escrever de volta" com sentido aqui).
  LoggerFormatAttribute/LoggerDestinationsAttribute da SSOT DROPADOS (sem
  alvo). LoggerValueAttribute usa `string` (nao `Variant`) desde a origem -
  aplica preventivamente a licao do bug-1131 (Onda 6.2: Variant em
  TCustomAttribute corrompe/crasha ao decorar propriedade).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.10.0 (Loggers - modulo que estes atributos mapeiam)
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.0.0 (03/08/2026): FASE 6 Onda 6.3 - absorvido com escopo reduzido
    (so' nivel de classe + introspeccao de propriedade).
  ============================================================================= }

unit Attributers.Loggers.Interfaces;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

uses
  Commons.Types,
  Commons.Loggers.Types,
  Loggers.Interfaces;

{$IFDEF USE_LOGGERS}
{$IFDEF USE_ATTRIBUTES}
type
  { =============================================================================
    Atributos de classe
    ============================================================================= }

  { Define o nome do logger. Obrigatorio - Uso: [Logger('AppLogger')] }
  LoggerAttribute = class(TCustomAttribute)
  private
    FName: string;
  public
    constructor Create(const AName: string);
    property Name: string read FName;
  end;

  { Nivel minimo de log. Opcional (default llInfo) - Uso: [LoggerLevel(llWarning)] }
  LoggerLevelAttribute = class(TCustomAttribute)
  private
    FLevel: TLogLevel;
  public
    constructor Create(const ALevel: TLogLevel);
    property Level: TLogLevel read FLevel;
  end;

  { Categoria do logger. Opcional (default = Name) - Uso: [LoggerCategory('ERP')] }
  LoggerCategoryAttribute = class(TCustomAttribute)
  private
    FCategory: string;
  public
    constructor Create(const ACategory: string);
    property Category: string read FCategory;
  end;

  { =============================================================================
    Atributos de propriedade (INTROSPECCAO - sem aplicacao a um setter fluente,
    ver nota do cabecalho)
    ============================================================================= }

  { Mapeia propriedade a uma chave de configuracao (informativa). Uso: [LoggerKey('FilePath')] }
  LoggerKeyAttribute = class(TCustomAttribute)
  private
    FKey: string;
  public
    constructor Create(const AKey: string);
    property Key: string read FKey;
  end;

  { Valor padrao (textual) da chave. Uso: [LoggerValue('app.log')] }
  LoggerValueAttribute = class(TCustomAttribute)
  private
    FValue: string;
  public
    constructor Create(const AValue: string);
    property Value: string read FValue;
  end;

  { Descricao/comentario da chave. Uso: [LoggerDescription('Caminho do ficheiro de log')] }
  LoggerDescriptionAttribute = class(TCustomAttribute)
  private
    FDescription: string;
  public
    constructor Create(const ADescription: string);
    property Description: string read FDescription;
  end;

  { Marca a chave como obrigatoria. Uso: [LoggerRequired] }
  LoggerRequiredAttribute = class(TCustomAttribute)
  public
    constructor Create;
  end;

  { =============================================================================
    ILoggerAttributeParser - parsing (classe) + introspeccao (propriedade)
    ============================================================================= }
  ILoggerAttributeParser = interface
    ['{B1C2D3E4-F5A6-7890-ABCD-EF12345678AA}']
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
{$ENDIF}
{$ENDIF}

implementation

{$IFDEF USE_LOGGERS}
{$IFDEF USE_ATTRIBUTES}

constructor LoggerAttribute.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

constructor LoggerLevelAttribute.Create(const ALevel: TLogLevel);
begin
  inherited Create;
  FLevel := ALevel;
end;

constructor LoggerCategoryAttribute.Create(const ACategory: string);
begin
  inherited Create;
  FCategory := ACategory;
end;

constructor LoggerKeyAttribute.Create(const AKey: string);
begin
  inherited Create;
  FKey := AKey;
end;

constructor LoggerValueAttribute.Create(const AValue: string);
begin
  inherited Create;
  FValue := AValue;
end;

constructor LoggerDescriptionAttribute.Create(const ADescription: string);
begin
  inherited Create;
  FDescription := ADescription;
end;

constructor LoggerRequiredAttribute.Create;
begin
  inherited Create;
end;

{$ENDIF}
{$ENDIF}

end.
