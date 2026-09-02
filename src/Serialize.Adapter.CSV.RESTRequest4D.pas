{ =============================================================================
  Serialize.Adapter.CSV.RESTRequest4D - IRequestAdapter que converte JSON
  (corpo de resposta RESTRequest4Delphi) para CSV

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           15/07/2026

  Absorvido de FontesReferencias/csv-adapter-restrequest4delphi/Src/
  CSV.Adapter.RESTRequest4D.pas (namespace CSV.Adapter.RESTRequest4D ->
  Serialize.Adapter.CSV.RESTRequest4D; uses internos CSV.Adapter.RESTRequest4D.
  Config/.Utils -> Serialize.Adapter.CSV.RESTRequest4D.Config/.Utils). O
  form de exemplo View.Main.pas da fonte NAO foi absorvido (fora do escopo
  do modulo). Nomes de tipo mantidos verbatim (TCSVAdapterRESTRequest4D,
  ICSVAdapterRESTRequest4DConfig, TCSVAdapterRESTRequest4DUtils) - so o
  namespace de unit muda, seguindo o padrao ja aplicado ao dataset-serialize-
  adapter-restrequest4delphi (Serialize.Adapter.RESTRequest4D).

  Gate USE_RESTREQUEST4D (ORM.Defines.inc, OFF por defeito): a lib
  RESTRequest4Delphi esta vendorizada em Packages/RESTRequest4Delphi/src desde
  15/07 (opcional, nao exigida pelo ecossistema nucleo) - a unit INTEIRA (interface+implementation) fica gated
  para o core (ProvidersV3/ParametersV3) compilar sem essa dependencia
  presente. Activar apenas em bancadas que vendorizem RESTRequest4Delphi no
  search path e definam -DUSE_RESTREQUEST4D / -dUSE_RESTREQUEST4D.

  Cross-compiler (parsing JSON): o original e Delphi-only (System.JSON,
  TJSONObject.ParseJSONValue/FindValue/for..in TJSONPair). Ramo FPC (compilacao condicional)
  portado para fpjson (GetJSON/TJSONData/TJSONObject.Names[i]+Items[i]/
  TJSONData.FindPath - equivalente por caminho ao FindValue do Delphi) +
  jsonparser (parser handler do GetJSON), seguindo o padrao ja usado em
  Connections.pas (LoadFromJSON). Ramo FPC runtime-VERIFICADO (15/07): a lib
  RESTRequest4Delphi foi vendorizada em Packages/RESTRequest4Delphi/src; compila
  com USE_RESTREQUEST4D ON nos 4 compiladores e o smoke_restadapters valida o
  parsing JSON->CSV em dcc32 (System.JSON) E fpc32 (fpjson) = OK=5 FAIL=0.

  Excecao: raise Exception.Create('Root element not found') (upstream, cru)
  substituido por raise ESerializeException.Create(..., ERR_SERIALIZE_GENERIC)
  (regra v3 - nunca lancar Exception cru; Exceptions.Serialize, faixa 44).

  Changelog (file):
  - 1.0.0 (15/07/2026): versao inicial - absorcao TOTAL do csv-adapter-
    restrequest4delphi, header v3, unit inteira gated por USE_RESTREQUEST4D,
    porte cross-compiler do parsing JSON (fpjson vs System.JSON), excecao
    ad-hoc trocada por ESerializeException/ERR_SERIALIZE_GENERIC.
  ============================================================================= }
unit Serialize.Adapter.CSV.RESTRequest4D;

{$I ../../../ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}{$H+}
{$ENDIF}

interface

{$IFDEF USE_RESTREQUEST4D}

uses
{$IF DEFINED(FPC)}
  SysUtils, fpjson, jsonparser, Generics.Collections, Classes,
{$ELSE}
  System.SysUtils, System.JSON, System.Generics.Collections, System.Classes,
{$ENDIF}
  Serialize.Adapter.CSV.RESTRequest4D.Config,
  RESTRequest4D.Request.Adapter.Contract,
  Serialize.Adapter.CSV.RESTRequest4D.Utils,
  Exceptions.Serialize;

type
  ICSVAdapterRESTRequest4DConfig = Serialize.Adapter.CSV.RESTRequest4D.Config.ICSVAdapterRESTRequest4DConfig;
  TCSVAdapterRESTRequest4DConfig = Serialize.Adapter.CSV.RESTRequest4D.Config.TCSVAdapterRESTRequest4DConfig;

  TCSVAdapterRESTRequest4D = class(TInterfacedObject, IRequestAdapter)
  private
    FConfig: ICSVAdapterRESTRequest4DConfig;
    FFileName: string;
    FRootElement: string;
    FCSV: TStrings;
    FStringListResult: TStrings;
    FCaptionsCreated: Boolean;
    procedure CreateInternal(const AConfig: ICSVAdapterRESTRequest4DConfig = nil);
    procedure Execute(const AContent: string);
    procedure Process(const AValue: string); overload;
    procedure Process(const AJSONObject: TJSONObject); overload;
    procedure Process(const AJSONArray: TJSONArray); overload;
    procedure GetItems(const AJSONObject: TJSONObject);
    procedure GetColumns(const AJSONObject: TJSONObject);
    procedure ProcessResult;
  public
    class function New(const AFileName: string; const ARootElement: string = ''): IRequestAdapter; overload;
    class function New(const AFileName: string; const AConfig: ICSVAdapterRESTRequest4DConfig): IRequestAdapter; overload;
    class function New(const AFileName: string; const ARootElement: string;
      const AConfig: ICSVAdapterRESTRequest4DConfig): IRequestAdapter; overload;

    class function New(const AStList: TStrings; const ARootElement: string = ''): IRequestAdapter; overload;
    class function New(const AStList: TStrings; const AConfig: ICSVAdapterRESTRequest4DConfig): IRequestAdapter; overload;
    class function New(const AStList: TStrings; const ARootElement: string;
      const AConfig: ICSVAdapterRESTRequest4DConfig): IRequestAdapter; overload;

    constructor Create(const AFileName: string; const ARootElement: string = '';
      const AConfig: ICSVAdapterRESTRequest4DConfig = nil); overload;
    constructor Create(const AStList: TStrings; const ARootElement: string = '';
      const AConfig: ICSVAdapterRESTRequest4DConfig = nil); overload;

    destructor Destroy; override;
  end;

{$ENDIF}

implementation

{$IFDEF USE_RESTREQUEST4D}

procedure TCSVAdapterRESTRequest4D.CreateInternal(const AConfig: ICSVAdapterRESTRequest4DConfig = nil);
begin
  FConfig := AConfig;
  if FConfig = nil then
    FConfig := TCSVAdapterRESTRequest4DConfig.New;

  FCaptionsCreated := False;
  FCSV := TStringList.Create;
  FFileName := '';
  FRootElement := '';
end;

class function TCSVAdapterRESTRequest4D.New(const AFileName: string; const ARootElement: string = ''): IRequestAdapter;
begin
  Result := Self.Create(AFileName, ARootElement);
end;

class function TCSVAdapterRESTRequest4D.New(const AFileName: string; const AConfig: ICSVAdapterRESTRequest4DConfig): IRequestAdapter;
begin
  Result := Self.Create(AFileName, '', AConfig);
end;

class function TCSVAdapterRESTRequest4D.New(const AFileName: string; const ARootElement: string;
  const AConfig: ICSVAdapterRESTRequest4DConfig): IRequestAdapter;
begin
  Result := Self.Create(AFileName, ARootElement, AConfig);
end;

class function TCSVAdapterRESTRequest4D.New(const AStList: TStrings; const ARootElement: string = ''): IRequestAdapter;
begin
  Result := Self.Create(AStList, ARootElement);
end;

class function TCSVAdapterRESTRequest4D.New(const AStList: TStrings; const AConfig: ICSVAdapterRESTRequest4DConfig): IRequestAdapter;
begin
  Result := Self.Create(AStList, '', AConfig);
end;

class function TCSVAdapterRESTRequest4D.New(const AStList: TStrings; const ARootElement: string;
  const AConfig: ICSVAdapterRESTRequest4DConfig): IRequestAdapter;
begin
  Result := Self.Create(AStList, ARootElement, AConfig);
end;

constructor TCSVAdapterRESTRequest4D.Create(const AFileName: string; const ARootElement: string = '';
  const AConfig: ICSVAdapterRESTRequest4DConfig = nil);
begin
  Self.CreateInternal(AConfig);
  FFileName := AFileName;
  FRootElement := ARootElement;
end;

constructor TCSVAdapterRESTRequest4D.Create(const AStList: TStrings; const ARootElement: string = '';
  const AConfig: ICSVAdapterRESTRequest4DConfig = nil);
begin
  Self.CreateInternal(AConfig);
  FStringListResult := AStList;
  FRootElement := ARootElement;
end;

destructor TCSVAdapterRESTRequest4D.Destroy;
begin
  FCSV.Free;
  inherited;
end;

procedure TCSVAdapterRESTRequest4D.Execute(const AContent: string);
begin
  Self.Process(AContent.Trim);
end;

procedure TCSVAdapterRESTRequest4D.Process(const AValue: string);
{$IFDEF FPC}
var
  LData: TJSONData;
begin
  if AValue.Trim.StartsWith('{') then
  begin
    LData := GetJSON(AValue);
    if Assigned(LData) then
    begin
      if LData is TJSONObject then
        Self.Process(TJSONObject(LData))
      else
        LData.Free;
    end;
  end
  else if Trim(AValue).StartsWith('[') then
  begin
    LData := GetJSON(AValue);
    if Assigned(LData) then
    begin
      if LData is TJSONArray then
        Self.Process(TJSONArray(LData))
      else
        LData.Free;
    end;
  end;

  Self.ProcessResult;
end;
{$ELSE}
begin
  if AValue.Trim.StartsWith('{') then
    Self.Process(TJSONObject.ParseJSONValue(TEncoding.UTF8.GetBytes(AValue), 0) as TJSONObject)
  else if Trim(AValue).StartsWith('[') then
    Self.Process(TJSONObject.ParseJSONValue(TEncoding.UTF8.GetBytes(AValue), 0) as TJSONArray);

  Self.ProcessResult;
end;
{$ENDIF}

procedure TCSVAdapterRESTRequest4D.Process(const AJSONArray: TJSONArray);
var
  i: Integer;
begin
  if not Assigned(AJSONArray) then
    Exit;

  for i := 0 to Pred(AJSONArray.Count) do
  begin
    if AJSONArray.Items[i] is TJSONObject then
    begin
      if not FCaptionsCreated then
        Self.GetColumns(AJSONArray.Items[i] as TJSONObject);

      Self.GetItems(AJSONArray.Items[i] as TJSONObject);
    end;
  end;
end;

procedure TCSVAdapterRESTRequest4D.GetColumns(const AJSONObject: TJSONObject);
var
  LLine: string;
  {$IFDEF FPC}
  i: Integer;
  {$ELSE}
  LJSONPair: TJSONPair;
  {$ENDIF}
begin
  LLine := '';
  {$IFDEF FPC}
  for i := 0 to Pred(AJSONObject.Count) do
    LLine := LLine + TCSVAdapterRESTRequest4DUtils.PrepareStr(AJSONObject.Names[i], FConfig.Separator) + FConfig.Separator;
  {$ELSE}
  for LJSONPair in AJSONObject do
    LLine := LLine + TCSVAdapterRESTRequest4DUtils.PrepareStr(LJSONPair.JsonString.Value, FConfig.Separator) + FConfig.Separator;
  {$ENDIF}

  FCSV.Add(TCSVAdapterRESTRequest4DUtils.RemoveLastSeparator(LLine, FConfig.Separator));
  FCaptionsCreated := True;
end;

procedure TCSVAdapterRESTRequest4D.GetItems(const AJSONObject: TJSONObject);
var
  LLine: string;
  {$IFDEF FPC}
  i: Integer;
  {$ELSE}
  LJSONPair: TJSONPair;
  {$ENDIF}
begin
  LLine := '';
  {$IFDEF FPC}
  for i := 0 to Pred(AJSONObject.Count) do
    LLine := LLine + TCSVAdapterRESTRequest4DUtils.PrepareStr(AJSONObject.Items[i].AsString, FConfig.Separator) + FConfig.Separator;
  {$ELSE}
  for LJSONPair in AJSONObject do
    LLine := LLine + TCSVAdapterRESTRequest4DUtils.PrepareStr(LJSONPair.JsonValue.Value, FConfig.Separator) + FConfig.Separator;
  {$ENDIF}

  FCSV.Add(TCSVAdapterRESTRequest4DUtils.RemoveLastSeparator(LLine, FConfig.Separator));
end;

procedure TCSVAdapterRESTRequest4D.Process(const AJSONObject: TJSONObject);
var
  {$IFDEF FPC}
  LJSONValue: TJSONData;
  {$ELSE}
  LJSONValue: TJSONValue;
  {$ENDIF}
begin
  try
    if FRootElement.Trim.IsEmpty then
      LJSONValue := AJSONObject
    else
      {$IFDEF FPC}
      LJSONValue := AJSONObject.FindPath(FRootElement);
      {$ELSE}
      LJSONValue := AJSONObject.FindValue(FRootElement);
      {$ENDIF}

    if not Assigned(LJSONValue) then
      raise ESerializeException.Create('Root element not found', ERR_SERIALIZE_GENERIC);

    if LJSONValue.InheritsFrom(TJSONArray) then
      Self.Process(LJSONValue as TJSONArray)
    else
    begin
      Self.GetColumns(LJSONValue as TJSONObject);
      Self.GetItems(LJSONValue as TJSONObject);
    end;
  finally
    AJSONObject.Free;
  end;
end;

procedure TCSVAdapterRESTRequest4D.ProcessResult;
begin
  if not FFileName.Trim.IsEmpty then
    FCSV.SaveToFile(FFileName)
  else if Assigned(FStringListResult) then
    FStringListResult.Text := FCSV.Text;
end;

{$ENDIF}

end.
