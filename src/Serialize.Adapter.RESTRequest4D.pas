{ =============================================================================
  Serialize.Adapter.RESTRequest4D - IRequestAdapter sobre TDataSetSerializeHelper

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           13/07/2026

  Absorvido de FontesReferencias/dataset-serialize-adapter-restrequest4delphi/
  src/DataSet.Serialize.Adapter.RESTRequest4D.pas (namespace DataSet.Serialize.
  Adapter.RESTRequest4D -> Serialize.Adapter.RESTRequest4D; uses DataSet.
  Serialize -> Serialize). Conteudo logico verbatim.

  Gate USE_RESTREQUEST4D (ORM.Defines.inc, OFF por defeito): a lib
  RESTRequest4Delphi esta vendorizada em Packages/RESTRequest4Delphi/src desde
  15/07 (opcional, nao exigida pelo ecossistema nucleo) - a unit INTEIRA (interface+implementation) fica gated
  para o core (ProvidersV3/ParametersV3) compilar sem essa dependencia
  presente. Activar apenas em bancadas que vendorizem RESTRequest4Delphi no
  search path e definam -DUSE_RESTREQUEST4D / -dUSE_RESTREQUEST4D.

  Changelog (file):
  - 1.0.0 (13/07/2026): versao inicial (FASE 5 Onda 9) - absorcao TOTAL do
    dataset-serialize-adapter-restrequest4delphi, header v3, unit inteira
    gated por USE_RESTREQUEST4D (novo define, Layer 2, OFF por defeito).
  ============================================================================= }
unit Serialize.Adapter.RESTRequest4D;

{$I ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}{$H+}
{$ENDIF}

interface

{$IFDEF USE_RESTREQUEST4D}

uses
  RESTRequest4D.Request.Adapter.Contract, Serialize{$IF DEFINED(FPC)}, DB{$ELSE}, Data.DB{$ENDIF};

type
  TDataSetSerializeAdapter = class(TInterfacedObject, IRequestAdapter)
  private
    FRootElement: string;
    FDataSet: TDataSet;
    procedure Execute(const AContent: string);
    {$IFNDEF FPC}
    procedure ActiveCachedUpdates(const ADataSet: TDataSet; const AActive: Boolean);
    {$ENDIF}
    constructor Create(const ADataSet: TDataSet; const ARootElement: string = ''); reintroduce;
  public
    class function New(const ADataSet: TDataSet; const ARootElement: string = ''): IRequestAdapter;
  end;

{$ENDIF}

implementation

{$IFDEF USE_RESTREQUEST4D}

{$IFNDEF FPC}
uses System.Generics.Collections, FireDAC.Comp.Client;

procedure TDataSetSerializeAdapter.ActiveCachedUpdates(const ADataSet: TDataSet; const AActive: Boolean);
var
  LDataSet: TDataSet;
  LDataSetDetails: TList<TDataSet>;
begin
  LDataSetDetails := TList<TDataSet>.Create;
  try
    if not AActive then
      FDataSet.Close;
    if ADataSet is TFDMemTable then
      TFDMemTable(ADataSet).CachedUpdates := AActive;
    if AActive and (not ADataSet.Active) and (ADataSet.FieldCount > 0) then
      ADataSet.Open;
    ADataSet.GetDetailDataSets(LDataSetDetails);
    for LDataSet in LDataSetDetails do
      ActiveCachedUpdates(LDataSet, AActive);
  finally
    LDataSetDetails.Free;
  end;
end;
{$ENDIF}

constructor TDataSetSerializeAdapter.Create(const ADataSet: TDataSet; const ARootElement: string = '');
begin
  FDataSet := ADataSet;
  FRootElement := ARootElement;
end;

procedure TDataSetSerializeAdapter.Execute(const AContent: string);
begin
  {$IFNDEF FPC}
  ActiveCachedUpdates(FDataSet, False);
  {$ENDIF}
  FDataSet.LoadFromJSON(AContent, FRootElement);
  {$IFNDEF FPC}
  ActiveCachedUpdates(FDataSet, True);
  {$ENDIF}
end;

class function TDataSetSerializeAdapter.New(const ADataSet: TDataSet; const ARootElement: string = ''): IRequestAdapter;
begin
  Result := TDataSetSerializeAdapter.Create(ADataSet, ARootElement);
end;

{$ENDIF}

end.
