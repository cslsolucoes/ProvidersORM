{ =============================================================================
  Parameters - factory + convergencia do modulo Parameters

  TParameters: factory publica (New / NewDatabase / NewIniFile / NewJsonObject).
  TParametersImpl (OCULTA na implementation): convergencia multi-fonte (IParameters)
  - leitura em CASCATA pela ordem de Priority (default DB > INI > JSON; conjunto
  ativo default [Database, IniFiles]); ESCRITA so na fonte ATIVA; escopo
  (contrato/produto) propagado a todas as fontes; acesso direto a cada fonte.

  A matriz Import/Export uniforme ja vive na base comum (Parameters.SourceBase,
  Onda 7.3) - a convergencia so orquestra as fontes.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  2.1.0
  FileVersion:    1.1.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           11/08/2026

  Changelog (file):
  - 1.1.0 (11/08/2026): retrofit SetLogger (F8 Onda 8.6) - observabilidade
    estrutural via ILogger fluente (SetLogger). Campo FLogger + construtor init
    TNullLogger + piggybacking Insert/Update/Save/Delete/Select. Gated USE_LOGGERS.
  - 1.0.0 (17/07/2026): criacao (FASE 7, Onda 7.4) - factory TParameters +
    convergencia TParametersImpl (cascata de leitura / escrita na fonte ativa /
    escopo propagado / acesso direto). (A fachada TProviders.Parameters = F10.)
  ============================================================================= }

unit Parameters;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_PARAMETERS}

uses
{$IF DEFINED(FPC)}
  SysUtils, fpjson,
{$ELSE}
  System.SysUtils, System.JSON,
{$ENDIF}
  Commons.Types,
  Parameters.Interfaces
{$IFDEF USE_LOGGERS}
  ,Loggers.Interfaces
{$ENDIF}
;

type
  { Factory publica do modulo (ponto unico de criacao). }
  TParameters = class
  public
    class function New: IParameters; overload; static;
    class function New(const AConfig: TParameterConfig): IParameters; overload; static;
    class function NewDatabase: IParametersDatabase; static;
    class function NewIniFile: IParametersIniFile; static;
    class function NewJsonObject: IParametersJsonObject; static;
  end;

{$ENDIF USE_PARAMETERS}

implementation

{$IFDEF USE_PARAMETERS}

uses
  Commons.Consts,            // DEFAULT_PARAMETER_CONFIG
  Commons.Parameters.Consts, // DEFAULT_CONTRATO_ID / DEFAULT_PRODUTO_ID
  Parameters.Database,
  Parameters.IniFile,
  Parameters.JsonObject
{$IFDEF USE_LOGGERS}
  ,Loggers.NullLogger        // TNullLogger (default logger)
{$ENDIF}
;

function CopyParam(const ASrc: TParameter): TParameter;
begin
  Result := TParameter.Create;
  Result.ID          := ASrc.ID;
  Result.Name        := ASrc.Name;
  Result.Value       := ASrc.Value;
  Result.ValueType   := ASrc.ValueType;
  Result.Description  := ASrc.Description;
  Result.ContratoID  := ASrc.ContratoID;
  Result.ProdutoID   := ASrc.ProdutoID;
  Result.Ordem       := ASrc.Ordem;
  Result.Titulo      := ASrc.Titulo;
  Result.Ativo       := ASrc.Ativo;
  Result.CreatedAt   := ASrc.CreatedAt;
  Result.UpdatedAt   := ASrc.UpdatedAt;
end;

type
  { Convergencia multi-fonte (oculta - so via TParameters.New). }
  TParametersImpl = class(TInterfacedObject, IParameters)
  strict private
    FDatabase   : IParametersDatabase;
    FIniFile    : IParametersIniFile;
    FJsonObject : IParametersJsonObject;
    FActive     : TParameterSource;
    FEnabled    : TParameterConfig;
    FPriority   : TParameterSourceArray;
    FContratoID : Integer;
    FProdutoID  : Integer;
{$IFDEF USE_LOGGERS}
    FLogger     : ILogger;
{$ENDIF}
    function EnsureSource(const AKind: TParameterSource): IParametersSource;
    procedure PropagateScope;
  public
    constructor Create(const AConfig: TParameterConfig);

{$IFDEF USE_LOGGERS}
    function SetLogger(const ALogger: ILogger): IParameters;
{$ENDIF}

    function Source(const AValue: TParameterSource): IParameters; overload;
    function Source: TParameterSource; overload;
    function AddSource(const AValue: TParameterSource): IParameters;
    function RemoveSource(const AValue: TParameterSource): IParameters;
    function HasSource(const AValue: TParameterSource): Boolean;
    function Priority(const ASources: TParameterSourceArray): IParameters;

    function ContratoID(const AValue: Integer): IParameters; overload;
    function ContratoID: Integer; overload;
    function ProdutoID(const AValue: Integer): IParameters; overload;
    function ProdutoID: Integer; overload;

    function Select(const AName: string): TParameter; overload;
    function Select(const AName: string; const ASource: TParameterSource): TParameter; overload;
    function Select: TParameterList; overload;
    function Insert(const AParameter: TParameter): IParameters; overload;
    function Insert(const AParameter: TParameter; out ASuccess: Boolean): IParameters; overload;
    function Update(const AParameter: TParameter): IParameters; overload;
    function Update(const AParameter: TParameter; out ASuccess: Boolean): IParameters; overload;
    function Save(const AParameter: TParameter): IParameters; overload;
    function Save(const AParameter: TParameter; out ASuccess: Boolean): IParameters; overload;
    function Delete(const AName: string): IParameters; overload;
    function Delete(const AName: string; out ASuccess: Boolean): IParameters; overload;
    function Exists(const AName: string): Boolean;
    function Count: Integer;
    function Refresh: IParameters;
    function ToJSON: TJSONObject;

    function Database: IParametersDatabase;
    function IniFile: IParametersIniFile;
    function JsonObject: IParametersJsonObject;

{$IFDEF USE_DEPRECATED}
    function Getter(const AName: string): TParameter; overload;
    function List: TParameterList; overload;
    function Setter(const AParameter: TParameter): IParameters; overload;
{$ENDIF}

    function EndParameters: IInterface;
  end;

{ TParametersImpl }

constructor TParametersImpl.Create(const AConfig: TParameterConfig);
begin
  inherited Create;
  FEnabled := AConfig;
  FContratoID := DEFAULT_CONTRATO_ID;
  FProdutoID := DEFAULT_PRODUTO_ID;
{$IFDEF USE_LOGGERS}
  FLogger := TNullLogger.New;
{$ENDIF}
  { ordem de leitura default: DB > INI > JSON. }
  SetLength(FPriority, 3);
  FPriority[0] := psDatabase;
  FPriority[1] := psInifiles;
  FPriority[2] := psJsonObject;
  { fonte ativa (escrita) = 1a das ativas na ordem de prioridade. }
  if psDatabase in FEnabled then FActive := psDatabase
  else if psInifiles in FEnabled then FActive := psInifiles
  else if psJsonObject in FEnabled then FActive := psJsonObject
  else FActive := psDatabase;
end;

{$IFDEF USE_LOGGERS}
function TParametersImpl.SetLogger(const ALogger: ILogger): IParameters;
begin
  if Assigned(ALogger) then
    FLogger := ALogger
  else
    FLogger := TNullLogger.New;
  Result := Self;
end;
{$ENDIF}

function TParametersImpl.EnsureSource(const AKind: TParameterSource): IParametersSource;
begin
  case AKind of
    psDatabase:
      begin
        if FDatabase = nil then FDatabase := TParametersDatabase.Create;
        Result := FDatabase;
      end;
    psInifiles:
      begin
        if FIniFile = nil then FIniFile := TParametersIniFile.Create;
        Result := FIniFile;
      end;
    psJsonObject:
      begin
        if FJsonObject = nil then FJsonObject := TParametersJsonObject.Create;
        Result := FJsonObject;
      end;
  else
    Result := nil;
  end;
  if Result <> nil then
  begin
    Result.ContratoID(FContratoID);
    Result.ProdutoID(FProdutoID);
  end;
end;

procedure TParametersImpl.PropagateScope;
begin
  if FDatabase <> nil then FDatabase.ContratoID(FContratoID).ProdutoID(FProdutoID);
  if FIniFile <> nil then FIniFile.ContratoID(FContratoID).ProdutoID(FProdutoID);
  if FJsonObject <> nil then FJsonObject.ContratoID(FContratoID).ProdutoID(FProdutoID);
end;

function TParametersImpl.Source(const AValue: TParameterSource): IParameters;
begin
  FActive := AValue;
  Include(FEnabled, AValue);
  Result := Self;
end;

function TParametersImpl.Source: TParameterSource;
begin
  Result := FActive;
end;

function TParametersImpl.AddSource(const AValue: TParameterSource): IParameters;
begin
  Include(FEnabled, AValue);
  Result := Self;
end;

function TParametersImpl.RemoveSource(const AValue: TParameterSource): IParameters;
begin
  Exclude(FEnabled, AValue);
  { paridade v2.3.0: se a fonte removida era a ATIVA, reatribui a ativa para a
    proxima habilitada por prioridade (evita escrever numa fonte "removida"). }
  if FActive = AValue then
  begin
    if psDatabase in FEnabled then FActive := psDatabase
    else if psInifiles in FEnabled then FActive := psInifiles
    else if psJsonObject in FEnabled then FActive := psJsonObject
    else FActive := psDatabase;   { nenhuma habilitada: mantem default (as escritas re-habilitam). }
  end;
  Result := Self;
end;

function TParametersImpl.HasSource(const AValue: TParameterSource): Boolean;
begin
  Result := AValue in FEnabled;
end;

function TParametersImpl.Priority(const ASources: TParameterSourceArray): IParameters;
begin
  FPriority := ASources;
  Result := Self;
end;

function TParametersImpl.ContratoID(const AValue: Integer): IParameters;
begin
  FContratoID := AValue;
  PropagateScope;
  Result := Self;
end;

function TParametersImpl.ContratoID: Integer;
begin
  Result := FContratoID;
end;

function TParametersImpl.ProdutoID(const AValue: Integer): IParameters;
begin
  FProdutoID := AValue;
  PropagateScope;
  Result := Self;
end;

function TParametersImpl.ProdutoID: Integer;
begin
  Result := FProdutoID;
end;

function TParametersImpl.Select(const AName: string): TParameter;
var
  I: Integer;
  LSrc: IParametersSource;
begin
  { cascata: 1o nao-nil pela ordem de Priority (so fontes ativas). }
{$IFDEF USE_LOGGERS}
  FLogger.Trace(Format('Parameters.Select: chave=%s', [AName]));
{$ENDIF}
  Result := nil;
  for I := 0 to Length(FPriority) - 1 do
    if FPriority[I] in FEnabled then
    begin
      LSrc := EnsureSource(FPriority[I]);
      if LSrc <> nil then
      begin
        Result := LSrc.Select(AName);
        if Result <> nil then
        begin
{$IFDEF USE_LOGGERS}
          FLogger.Trace(Format('Parameters.Select: encontrado (chave=%s)', [AName]));
{$ENDIF}
          Break;
        end;
      end;
    end;
{$IFDEF USE_LOGGERS}
  if Result = nil then
    FLogger.Warning(Format('Parameters.Select: nao encontrado (chave=%s)', [AName]));
{$ENDIF}
end;

function TParametersImpl.Select(const AName: string; const ASource: TParameterSource): TParameter;
var
  LSrc: IParametersSource;
begin
  { forca a fonte indicada, sem fallback. }
  LSrc := EnsureSource(ASource);
  if LSrc <> nil then
    Result := LSrc.Select(AName)
  else
    Result := nil;
end;

function TParametersImpl.Select: TParameterList;
var
  I, J, K: Integer;
  LSrc: IParametersSource;
  LTmp: TParameterList;
  LDup: Boolean;
begin
  { merge com dedup por Name - 1a ocorrencia (fonte de maior prioridade) ganha. }
  Result := TParameterList.Create;
  for I := 0 to Length(FPriority) - 1 do
    if FPriority[I] in FEnabled then
    begin
      LSrc := EnsureSource(FPriority[I]);
      if LSrc = nil then Continue;
      LTmp := LSrc.Select;
      try
        for J := 0 to LTmp.Count - 1 do
        begin
          LDup := False;
          for K := 0 to Result.Count - 1 do
            if SameText(Result[K].Name, LTmp[J].Name) then
            begin
              LDup := True;
              Break;
            end;
          if not LDup then
            Result.Add(CopyParam(LTmp[J]));
        end;
      finally
        LTmp.Free;
      end;
    end;
end;

function TParametersImpl.Insert(const AParameter: TParameter): IParameters;
begin
{$IFDEF USE_LOGGERS}
  FLogger.Debug(Format('Parameters.Insert: chave=%s', [AParameter.Name]));
{$ENDIF}
  EnsureSource(FActive).Insert(AParameter);   { escrita SO na fonte ativa. }
{$IFDEF USE_LOGGERS}
  FLogger.Success(Format('Parameters.Insert: OK (chave=%s)', [AParameter.Name]));
{$ENDIF}
  Result := Self;
end;

function TParametersImpl.Insert(const AParameter: TParameter; out ASuccess: Boolean): IParameters;
begin
  ASuccess := False;
  try EnsureSource(FActive).Insert(AParameter); ASuccess := True; except ASuccess := False; end;
  Result := Self;
end;

function TParametersImpl.Update(const AParameter: TParameter): IParameters;
begin
{$IFDEF USE_LOGGERS}
  FLogger.Debug(Format('Parameters.Update: chave=%s', [AParameter.Name]));
{$ENDIF}
  EnsureSource(FActive).Update(AParameter);
{$IFDEF USE_LOGGERS}
  FLogger.Success(Format('Parameters.Update: OK (chave=%s)', [AParameter.Name]));
{$ENDIF}
  Result := Self;
end;

function TParametersImpl.Update(const AParameter: TParameter; out ASuccess: Boolean): IParameters;
begin
  ASuccess := False;
  try EnsureSource(FActive).Update(AParameter); ASuccess := True; except ASuccess := False; end;
  Result := Self;
end;

function TParametersImpl.Save(const AParameter: TParameter): IParameters;
begin
{$IFDEF USE_LOGGERS}
  FLogger.Debug(Format('Parameters.Save: chave=%s (upsert)', [AParameter.Name]));
{$ENDIF}
  EnsureSource(FActive).Save(AParameter);
{$IFDEF USE_LOGGERS}
  FLogger.Success(Format('Parameters.Save: OK (chave=%s)', [AParameter.Name]));
{$ENDIF}
  Result := Self;
end;

function TParametersImpl.Save(const AParameter: TParameter; out ASuccess: Boolean): IParameters;
begin
  ASuccess := False;
  try EnsureSource(FActive).Save(AParameter); ASuccess := True; except ASuccess := False; end;
  Result := Self;
end;

function TParametersImpl.Delete(const AName: string): IParameters;
begin
{$IFDEF USE_LOGGERS}
  FLogger.Debug(Format('Parameters.Delete: chave=%s', [AName]));
{$ENDIF}
  EnsureSource(FActive).Delete(AName);
{$IFDEF USE_LOGGERS}
  FLogger.Success(Format('Parameters.Delete: OK (chave=%s)', [AName]));
{$ENDIF}
  Result := Self;
end;

function TParametersImpl.Delete(const AName: string; out ASuccess: Boolean): IParameters;
begin
  ASuccess := False;
  try EnsureSource(FActive).Delete(AName); ASuccess := True; except ASuccess := False; end;
  Result := Self;
end;

function TParametersImpl.Exists(const AName: string): Boolean;
var
  I: Integer;
  LSrc: IParametersSource;
begin
  Result := False;
  for I := 0 to Length(FPriority) - 1 do
    if FPriority[I] in FEnabled then
    begin
      LSrc := EnsureSource(FPriority[I]);
      if (LSrc <> nil) and LSrc.Exists(AName) then
      begin
        Result := True;
        Break;
      end;
    end;
end;

function TParametersImpl.Count: Integer;
var
  LList: TParameterList;
begin
  { total distinto na cascata. }
  LList := Select;
  try
    Result := LList.Count;
  finally
    LList.Free;
  end;
end;

function TParametersImpl.Refresh: IParameters;
begin
  if FDatabase <> nil then FDatabase.Refresh;
  if FIniFile <> nil then FIniFile.Refresh;
  if FJsonObject <> nil then FJsonObject.Refresh;
  Result := Self;
end;

{ helpers JSON cross-compiler locais (ToJSON hierarquico - paridade v2.3.0). }
{$IF DEFINED(FPC)}
procedure CJAddStr(const AObj: TJSONObject; const AKey, AValue: string); begin AObj.Add(AKey, AValue); end;
procedure CJAddInt(const AObj: TJSONObject; const AKey: string; const AValue: Integer); begin AObj.Add(AKey, AValue); end;
procedure CJAddBool(const AObj: TJSONObject; const AKey: string; const AValue: Boolean); begin AObj.Add(AKey, AValue); end;
procedure CJAddObj(const AObj: TJSONObject; const AKey: string; const AValue: TJSONObject); begin AObj.Add(AKey, AValue); end;
function CJGetObj(const AObj: TJSONObject; const AKey: string): TJSONObject;
var LD: TJSONData;
begin LD := AObj.Find(AKey); if (LD <> nil) and (LD.JSONType = jtObject) then Result := TJSONObject(LD) else Result := nil; end;
{$ELSE}
procedure CJAddStr(const AObj: TJSONObject; const AKey, AValue: string); begin AObj.AddPair(AKey, AValue); end;
procedure CJAddInt(const AObj: TJSONObject; const AKey: string; const AValue: Integer); begin AObj.AddPair(AKey, TJSONNumber.Create(AValue)); end;
procedure CJAddBool(const AObj: TJSONObject; const AKey: string; const AValue: Boolean); begin AObj.AddPair(AKey, TJSONBool.Create(AValue)); end;
procedure CJAddObj(const AObj: TJSONObject; const AKey: string; const AValue: TJSONObject); begin AObj.AddPair(AKey, AValue); end;
function CJGetObj(const AObj: TJSONObject; const AKey: string): TJSONObject;
var LV: TJSONValue;
begin LV := AObj.GetValue(AKey); if LV is TJSONObject then Result := TJSONObject(LV) else Result := nil; end;
{$ENDIF}

function TParametersImpl.ToJSON: TJSONObject;
var
  LList: TParameterList;
  I: Integer;
  LCont, LTit, LKey: TJSONObject;
begin
  { formato HIERARQUICO (paridade v2.3.0): raiz -> "Contrato" + um objeto por Titulo
    -> um objeto por chave com valor/descricao/ativo/ordem. Funde as fontes ativas
    (Select ja aplica a cascata + escopo). }
  Result := TJSONObject.Create;
  LCont := TJSONObject.Create;
  CJAddInt(LCont, 'Contrato_ID', FContratoID);
  CJAddInt(LCont, 'Produto_ID', FProdutoID);
  CJAddObj(Result, 'Contrato', LCont);
  LList := Select;
  try
    for I := 0 to LList.Count - 1 do
    begin
      LTit := CJGetObj(Result, LList[I].Titulo);
      if LTit = nil then
      begin
        LTit := TJSONObject.Create;
        CJAddObj(Result, LList[I].Titulo, LTit);
      end;
      LKey := TJSONObject.Create;
      CJAddStr(LKey, 'valor', LList[I].Value);
      CJAddStr(LKey, 'descricao', LList[I].Description);
      CJAddBool(LKey, 'ativo', LList[I].Ativo);
      CJAddInt(LKey, 'ordem', LList[I].Ordem);
      CJAddObj(LTit, LList[I].Name, LKey);
    end;
  finally
    LList.Free;
  end;
end;

function TParametersImpl.Database: IParametersDatabase;
begin
  EnsureSource(psDatabase);
  Result := FDatabase;
end;

function TParametersImpl.IniFile: IParametersIniFile;
begin
  EnsureSource(psInifiles);
  Result := FIniFile;
end;

function TParametersImpl.JsonObject: IParametersJsonObject;
begin
  EnsureSource(psJsonObject);
  Result := FJsonObject;
end;

{$IFDEF USE_DEPRECATED}
function TParametersImpl.Getter(const AName: string): TParameter;
begin
  Result := Select(AName);
end;

function TParametersImpl.List: TParameterList;
begin
  Result := Select;
end;

function TParametersImpl.Setter(const AParameter: TParameter): IParameters;
begin
  Result := Save(AParameter);
end;
{$ENDIF}

function TParametersImpl.EndParameters: IInterface;
begin
  Result := Self;
end;

{ TParameters (factory) }

class function TParameters.New: IParameters;
begin
  Result := TParametersImpl.Create(DEFAULT_PARAMETER_CONFIG);
end;

class function TParameters.New(const AConfig: TParameterConfig): IParameters;
begin
  Result := TParametersImpl.Create(AConfig);
end;

class function TParameters.NewDatabase: IParametersDatabase;
begin
  Result := TParametersDatabase.Create;
end;

class function TParameters.NewIniFile: IParametersIniFile;
begin
  Result := TParametersIniFile.Create;
end;

class function TParameters.NewJsonObject: IParametersJsonObject;
begin
  Result := TParametersJsonObject.Create;
end;

{$ENDIF USE_PARAMETERS}

end.
