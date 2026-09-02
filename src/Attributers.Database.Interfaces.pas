{ =============================================================================
  Attributers.Database.Interfaces - Contratos + atributos RTTI do mapeamento
  Classe <-> ITable ([Table]/[Field]/[PrimaryKey])

  Absorvido de ProvidersORM v2.3.0 Attributers.Providers.Interfaces.pas (FASE 6
  Onda 6.1) - renomeado Providers->Database (regra D5). ConnectionAttribute da
  fonte NAO veio para aqui: ja existe em Attributers.Connections.pas (Onda 4.1,
  extraido antes por esta mesma razao) - de-dup simbolo-a-simbolo vs nucleo,
  nao duplicar. TableAttribute/FieldAttribute/PrimaryKeyAttribute relocados
  aqui a partir de Commons/Commons.Types.pas (SSOT v2.3.0), onde violavam a
  regra D5 ("atributos RTTI NUNCA em Commons") - a F1 ja tinha deixado uma nota
  em Commons.Types.pas a antecipar este destino.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.3.1 (Database - modulo que estes atributos mapeiam)
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.1.0 (03/08/2026): bug-1128 (achado real, isolado por spike) - doc do
    FieldAttribute passa a exigir explicitamente `published` (nao `public`)
    na propriedade decorada: no FPC 3.3.1, TRttiType.GetProperties so devolve
    propriedades published por omissao. Sem codigo novo (contrato do modulo,
    ja implicito no TAttributeParser existente).
  - 1.0.0 (03/08/2026): FASE 6 Onda 6.1 - IAttributeParser/IAttributeMapper/
    IAttributeRegistry absorvidas fieis ao original (uses Database.Table.Interfaces
    -> Databases.Interfaces, Reorg 1); TableAttribute/FieldAttribute/PrimaryKeyAttribute
    relocadas de Commons.Types.pas (D5).
  ============================================================================= }

unit Attributers.Database.Interfaces;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../ORM.Defines.inc}

uses
{$IF DEFINED(FPC)}
  SysUtils,
{$ELSE}
  System.SysUtils,
{$ENDIF}
  Commons.Types,
  Attributers.Database.Types,
  Databases.Interfaces;

{$IFDEF USE_ATTRIBUTES}
type
  { Atributo para mapear classe a tabela - Uso: [Table('messages')] }
  TableAttribute = class(TCustomAttribute)
  private
    FTableName: string;
    FSchema: string;
  public
    constructor Create(const ATableName: string; const ASchema: string = '');
    property TableName: string read FTableName;
    property Schema: string read FSchema;
  end;

  { Atributo para mapear propriedade a coluna - Uso: [Field('code')].
    CONTRATO CROSS-COMPILER (bug-1128): a propriedade decorada DEVE ser
    `published`, nunca `public` - no FPC 3.3.1, TRttiType.GetProperties so
    devolve propriedades published por omissao (RTTI estendida FPC != Delphi,
    que expoe public+published por omissao); TAttributeParser.GetFieldMappings
    devolve array vazio em silencio se a regra nao for seguida (nao lanca). }
  FieldAttribute = class(TCustomAttribute)
  private
    FColumnName: string;
  public
    constructor Create(const AColumnName: string);
    property ColumnName: string read FColumnName;
  end;

  { Atributo para marcar propriedade como chave primaria - Uso: [PrimaryKey] na mesma propriedade que [Field('id')] }
  PrimaryKeyAttribute = class(TCustomAttribute)
  public
    constructor Create;
  end;

  { Parser de atributos RTTI: [Table], [Field], [PrimaryKey] em uma classe. }
  IAttributeParser = interface
    ['{A8B9C0D1-7890-1234-5678-901234EF5678}']
    function HasTableAttribute(const AClass: TClass): Boolean;
    function GetTableName(const AClass: TClass): string;
    function GetSchema(const AClass: TClass): string;
    function GetFieldMappings(const AClass: TClass): TFieldMappingInfoArray;
  end;

  { Mapeador Classe -> ITable a partir dos atributos. }
  IAttributeMapper = interface
    ['{B9C0D1E2-8901-2345-6789-012345F06789}']
    function FromClass(const AClass: TClass; const ADatabaseType: TDatabaseTypes): ITable;
  end;

  { Registo central de classes decoradas com [Table] para cache de ITable por classe/tipo de banco. }
  IAttributeRegistry = interface
    ['{C0D1E2F3-9012-3456-7890-123456F17890}']
    function GetTable(const AClass: TClass; const ADatabaseType: TDatabaseTypes): ITable;
    procedure Unregister(const AClass: TClass);
    procedure Clear;
  end;
{$ENDIF}

implementation

{$IFDEF USE_ATTRIBUTES}

constructor TableAttribute.Create(const ATableName: string; const ASchema: string);
begin
  inherited Create;
  FTableName := ATableName;
  FSchema := ASchema;
end;

constructor FieldAttribute.Create(const AColumnName: string);
begin
  inherited Create;
  FColumnName := AColumnName;
end;

constructor PrimaryKeyAttribute.Create;
begin
  inherited Create;
end;

{$ENDIF}

end.
