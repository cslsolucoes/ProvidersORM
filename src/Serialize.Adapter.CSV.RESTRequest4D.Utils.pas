{ =============================================================================
  Serialize.Adapter.CSV.RESTRequest4D.Utils - Helpers de string (separador
  CSV) do adapter CSV IRequestAdapter

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           15/07/2026

  Absorvido de FontesReferencias/csv-adapter-restrequest4delphi/Src/
  CSV.Adapter.RESTRequest4D.Utils.pas (namespace CSV.Adapter.RESTRequest4D.
  Utils -> Serialize.Adapter.CSV.RESTRequest4D.Utils; uses interno CSV.
  Adapter.RESTRequest4D.Config -> Serialize.Adapter.CSV.RESTRequest4D.Config).
  Conteudo logico verbatim - nomes de tipo mantidos (TCSVAdapterRESTRequest4DUtils).

  Gate USE_RESTREQUEST4D (ORM.Defines.inc, OFF por defeito): a lib
  RESTRequest4Delphi nao esta vendorizada em Packages/ (nem exigida pelo
  ecossistema nucleo) - a unit INTEIRA (interface+implementation) fica gated
  para o core (ProvidersV3/ParametersV3) compilar sem essa dependencia
  presente. Activar apenas em bancadas que vendorizem RESTRequest4Delphi no
  search path e definam -DUSE_RESTREQUEST4D / -dUSE_RESTREQUEST4D.

  Changelog (file):
  - 1.0.0 (15/07/2026): versao inicial - absorcao do csv-adapter-
    restrequest4delphi (Utils), header v3, unit inteira gated por
    USE_RESTREQUEST4D.
  ============================================================================= }
unit Serialize.Adapter.CSV.RESTRequest4D.Utils;

{$I ../../../ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}{$H+}
{$ENDIF}

interface

{$IFDEF USE_RESTREQUEST4D}

uses
{$IF DEFINED(FPC)}
  SysUtils;
{$ELSE}
  System.SysUtils;
{$ENDIF}

type
  TCSVAdapterRESTRequest4DUtils = class
  private
  public
    class function RemoveLastSeparator(const AValue: string; const ASeparator: string): string;
    ///<summary>Remove if the string has characters used as separator</summary>
    class function PrepareStr(const AValue: string; const ASeparator: string): string;
  end;

{$ENDIF}

implementation

{$IFDEF USE_RESTREQUEST4D}

uses
  Serialize.Adapter.CSV.RESTRequest4D.Config;

class function TCSVAdapterRESTRequest4DUtils.RemoveLastSeparator(const AValue: string; const ASeparator: string): string;
begin
  Result := AValue.Trim;

  if Result.EndsWith(ASeparator) then
    Result := copy(AValue, 1, Pred(AValue.Length));
end;

class function TCSVAdapterRESTRequest4DUtils.PrepareStr(const AValue: string; const ASeparator: string): string;
begin
  Result := AValue.Replace(ASeparator, '', [rfReplaceAll, rfIgnoreCase]);
end;

{$ENDIF}

end.
