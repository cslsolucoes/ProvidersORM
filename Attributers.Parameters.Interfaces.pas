{ =============================================================================
  Attributers.Parameters.Interfaces - Atributos RTTI + contratos do mapeamento
  Classe <-> TParameter/TParameterList ([Parameter]/[ParameterKey]/...)

  FASE 6 Onda 6.2. Fundido de 2 fontes (regra do plano F6, owner 03/08):
  - FontesReferencias\ParamentersORM\src\Attributes\Parameters.Attributes.Types.pas
    e Parameters.Attributes.Interfaces.pas (standalone v1.0.7, Parser/Mapper maduros)
    - fonte dos 10 atributos RTTI
    (auto-contidos, sem depender de Commons.*).
  - SSOT `E:\Dropbox\CSL\ProvidersORM\src\Attributers\Attributers.Parameters.Interfaces.pas`
    (v2.2.0/2.3.0) — fonte das interfaces IAttributeParser/IAttributeMapper.
  De-dup vs nucleo v3 (F7): TParameter/TParameterList/TParameterValueType/
  TParameterSource/TStringArray JA EXISTEM em Commons.Types (NAO redefinidos
  aqui); DEFAULT_CONTRATO_ID/DEFAULT_PRODUTO_ID/DEFAULT_PARAMETER_ORDER ja em
  Commons.Parameters.Consts; EParametersAttributeException + ERR_ATTRIBUTE_*_CODE
  + MSG_ATTRIBUTE_* JA EXISTEM em Exceptions.Parameters.pas/Commons.Consts.pas
  (migrados numa sessao anterior, confirmados por leitura antes de escrever este
  ficheiro). Aliases em portugues do standalone (Parametro/ChaveParametro/...)
  DROPADOS (B-freeze - v3 limpo, sem sugar de compat).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  2.0.0 (Parameters - modulo que estes atributos mapeiam)
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.0.0 (03/08/2026): FASE 6 Onda 6.2 - fusao standalone (atributos) + SSOT
    (interfaces), reusando Commons.Types/Commons.Parameters.Consts/Exceptions.Parameters
    do v3 (F7) em vez de redefinir.
  ============================================================================= }

unit Attributers.Parameters.Interfaces;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../ORM.Defines.inc}

uses
  Commons.Types;

{$IFDEF USE_ATTRIBUTES}
type
  { =============================================================================
    Atributos de classe
    ============================================================================= }

  { Define titulo/seccao do parametro. Obrigatorio - Uso: [Parameter('ERP')] }
  ParameterAttribute = class(TCustomAttribute)
  private
    FTitle: string;
  public
    constructor Create(const ATitle: string);
    property Title: string read FTitle;
  end;

  { Define ContratoID. Opcional - Uso: [ContratoID(1)] }
  ContratoIDAttribute = class(TCustomAttribute)
  private
    FContratoID: Integer;
  public
    constructor Create(const AContratoID: Integer);
    property ContratoID: Integer read FContratoID;
  end;

  { Define ProdutoID. Opcional - Uso: [ProdutoID(1)] }
  ProdutoIDAttribute = class(TCustomAttribute)
  private
    FProdutoID: Integer;
  public
    constructor Create(const AProdutoID: Integer);
    property ProdutoID: Integer read FProdutoID;
  end;

  { Define fonte de dados preferencial da classe. Opcional - Uso: [ParameterSource(psDatabase)] }
  ParameterSourceAttribute = class(TCustomAttribute)
  private
    FSource: TParameterSource;
  public
    constructor Create(const ASource: TParameterSource);
    property Source: TParameterSource read FSource;
  end;

  { =============================================================================
    Atributos de propriedade
    ============================================================================= }

  { Mapeia propriedade a chave do parametro. Obrigatorio p/ mapear - Uso: [ParameterKey('database_host')] }
  ParameterKeyAttribute = class(TCustomAttribute)
  private
    FKey: string;
  public
    constructor Create(const AKey: string);
    property Key: string read FKey;
  end;

  { Valor padrao do parametro. Opcional - Uso: [ParameterValue('localhost')].
    CONTRATO CROSS-COMPILER (bug-1131): construtor recebe `string`, NUNCA
    `Variant` - confirmado por spike isolado que um TCustomAttribute com
    parametro `Variant` fica com o valor corrompido (lixo de memoria) ou
    provoca EAccessViolation em oleaut32.dll quando lido de volta por
    TRttiProperty.GetAttributes (Delphi 12 Studio 37; nao testado se FPC
    tem o mesmo defeito - decisao e' evitar Variant em atributos custom,
    ponto, independente de compilador). Valores tipados (Integer/Boolean/
    Float) usam a representacao textual - ex. [ParameterValue('5432')],
    [ParameterValue('False')] - convertidos para o tipo real no ponto de
    uso (TParameter.Value ja e' string em toda a v3, este desenho e' MAIS
    consistente que o Variant original do standalone/SSOT, nao menos). }
  ParameterValueAttribute = class(TCustomAttribute)
  private
    FValue: string;
  public
    constructor Create(const AValue: string);
    property Value: string read FValue;
  end;

  { Descricao/comentario do parametro. Opcional - Uso: [ParameterDescription('Host do banco')] }
  ParameterDescriptionAttribute = class(TCustomAttribute)
  private
    FDescription: string;
  public
    constructor Create(const ADescription: string);
    property Description: string read FDescription;
  end;

  { Tipo do valor. Opcional, inferido do tipo da propriedade se omisso - Uso: [ParameterType(pvtInteger)] }
  ParameterTypeAttribute = class(TCustomAttribute)
  private
    FValueType: TParameterValueType;
  public
    constructor Create(const AValueType: TParameterValueType);
    property ValueType: TParameterValueType read FValueType;
  end;

  { Ordem de exibicao. Opcional - Uso: [ParameterOrder(1)] }
  ParameterOrderAttribute = class(TCustomAttribute)
  private
    FOrder: Integer;
  public
    constructor Create(const AOrder: Integer);
    property Order: Integer read FOrder;
  end;

  { Marca propriedade como obrigatoria. Opcional - Uso: [ParameterRequired] }
  ParameterRequiredAttribute = class(TCustomAttribute)
  public
    constructor Create;
  end;

  { =============================================================================
    IAttributeParser - parsing de atributos via RTTI
    ============================================================================= }
  IAttributeParser = interface
    ['{B1C2D3E4-F5A6-7890-ABCD-EF1234567890}']
    function ParseClass(const AClassType: TClass): TParameterList; overload;
    function ParseClass(const AInstance: TObject): TParameterList; overload;
    function GetClassTitle(const AClassType: TClass): string; overload;
    function GetClassTitle(const AInstance: TObject): string; overload;
    function GetClassContratoID(const AClassType: TClass): Integer; overload;
    function GetClassContratoID(const AInstance: TObject): Integer; overload;
    function GetClassProdutoID(const AClassType: TClass): Integer; overload;
    function GetClassProdutoID(const AInstance: TObject): Integer; overload;
    function GetClassSource(const AClassType: TClass): TParameterSource; overload;
    function GetClassSource(const AInstance: TObject): TParameterSource; overload;
    function GetParameterProperties(const AClassType: TClass): TStringArray; overload;
    function GetParameterProperties(const AInstance: TObject): TStringArray; overload;
    function GetPropertyKey(const AInstance: TObject; const APropertyName: string): string;
    function GetPropertyDefaultValue(const AInstance: TObject; const APropertyName: string): Variant;
    function GetPropertyDescription(const AInstance: TObject; const APropertyName: string): string;
    function GetPropertyValueType(const AInstance: TObject; const APropertyName: string): TParameterValueType;
    function GetPropertyOrder(const AInstance: TObject; const APropertyName: string): Integer;
    function IsPropertyRequired(const AInstance: TObject; const APropertyName: string): Boolean;
    function ValidateClass(const AClassType: TClass): Boolean; overload;
    function ValidateClass(const AInstance: TObject): Boolean; overload;
  end;

  { =============================================================================
    IAttributeMapper - mapeamento bidirecional Classe <-> TParameter
    ============================================================================= }
  IAttributeMapper = interface
    ['{C2D3E4F5-A6B7-8901-CDEF-123456789012}']
    function MapClassToParameters(const AClassType: TClass): TParameterList; overload;
    function MapClassToParameters(const AInstance: TObject): TParameterList; overload;
    function MapParametersToClass(AParameters: TParameterList; AInstance: TObject): IAttributeMapper; overload;
    function SetParameterValue(AInstance: TObject; const AParameterKey: string; const AValue: Variant): IAttributeMapper; overload;
    function GetParameterValue(const AInstance: TObject; const AParameterKey: string): Variant; overload;
  end;
{$ENDIF}

implementation

{$IFDEF USE_ATTRIBUTES}

constructor ParameterAttribute.Create(const ATitle: string);
begin
  inherited Create;
  FTitle := ATitle;
end;

constructor ContratoIDAttribute.Create(const AContratoID: Integer);
begin
  inherited Create;
  FContratoID := AContratoID;
end;

constructor ProdutoIDAttribute.Create(const AProdutoID: Integer);
begin
  inherited Create;
  FProdutoID := AProdutoID;
end;

constructor ParameterSourceAttribute.Create(const ASource: TParameterSource);
begin
  inherited Create;
  FSource := ASource;
end;

constructor ParameterKeyAttribute.Create(const AKey: string);
begin
  inherited Create;
  FKey := AKey;
end;

constructor ParameterValueAttribute.Create(const AValue: string);
begin
  inherited Create;
  FValue := AValue;
end;

constructor ParameterDescriptionAttribute.Create(const ADescription: string);
begin
  inherited Create;
  FDescription := ADescription;
end;

constructor ParameterTypeAttribute.Create(const AValueType: TParameterValueType);
begin
  inherited Create;
  FValueType := AValueType;
end;

constructor ParameterOrderAttribute.Create(const AOrder: Integer);
begin
  inherited Create;
  FOrder := AOrder;
end;

constructor ParameterRequiredAttribute.Create;
begin
  inherited Create;
end;

{$ENDIF}

end.
