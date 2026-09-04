{ =============================================================================
  Serialize.Adapter.CSV.RESTRequest4D.Config - Configuracao (separador) do
  adapter CSV IRequestAdapter

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           15/07/2026

  Absorvido de FontesReferencias/csv-adapter-restrequest4delphi/Src/
  CSV.Adapter.RESTRequest4D.Config.pas (namespace CSV.Adapter.RESTRequest4D.
  Config -> Serialize.Adapter.CSV.RESTRequest4D.Config). Conteudo logico
  verbatim - nomes de tipo mantidos (ICSVAdapterRESTRequest4DConfig,
  TCSVAdapterRESTRequest4DConfig), so o namespace de unit muda (padrao ja
  aplicado ao dataset-serialize-adapter-restrequest4delphi).

  Gate USE_RESTREQUEST4D (ORM.Defines.inc, OFF por defeito): a lib
  RESTRequest4Delphi nao esta vendorizada em Packages/ (nem exigida pelo
  ecossistema nucleo) - a unit INTEIRA (interface+implementation) fica gated
  para o core (ProvidersV3/ParametersV3) compilar sem essa dependencia
  presente. Activar apenas em bancadas que vendorizem RESTRequest4Delphi no
  search path e definam -DUSE_RESTREQUEST4D / -dUSE_RESTREQUEST4D.

  Changelog (file):
  - 1.0.0 (15/07/2026): versao inicial - absorcao do csv-adapter-
    restrequest4delphi (Config), header v3, unit inteira gated por
    USE_RESTREQUEST4D.
  ============================================================================= }
unit Serialize.Adapter.CSV.RESTRequest4D.Config;

{$I ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}{$H+}
{$ENDIF}

interface

{$IFDEF USE_RESTREQUEST4D}

uses
{$IF DEFINED(FPC)}
  SysUtils,
{$ELSE}
  System.SysUtils,
{$ENDIF}
  RESTRequest4D.Request.Adapter.Contract;

type
  ICSVAdapterRESTRequest4DConfig = interface
    ['{B5BF0D7A-8CEF-44AB-8721-9BDFF54921BC}']
    function Separator: string; overload;
    function Separator(const Value: string): ICSVAdapterRESTRequest4DConfig; overload;
  end;

  TCSVAdapterRESTRequest4DConfig = class(TInterfacedObject, ICSVAdapterRESTRequest4DConfig)
  private
    FSeparator: string;
  protected
    function Separator: string; overload;
    function Separator(const Value: string): ICSVAdapterRESTRequest4DConfig; overload;
  public
    class function New: ICSVAdapterRESTRequest4DConfig;
    constructor Create;
  end;

{$ENDIF}

implementation

{$IFDEF USE_RESTREQUEST4D}

const
  SEMICOLON = ';';

class function TCSVAdapterRESTRequest4DConfig.New: ICSVAdapterRESTRequest4DConfig;
begin
  Result := Self.Create;
end;

constructor TCSVAdapterRESTRequest4DConfig.Create;
begin
  FSeparator := SEMICOLON;
end;

function TCSVAdapterRESTRequest4DConfig.Separator: string;
begin
  Result := FSeparator;
end;

function TCSVAdapterRESTRequest4DConfig.Separator(const Value: string): ICSVAdapterRESTRequest4DConfig;
begin
  Result := Self;
  FSeparator := Value;

  if FSeparator.Trim.IsEmpty then
    FSeparator := SEMICOLON;
end;

{$ENDIF}

end.
