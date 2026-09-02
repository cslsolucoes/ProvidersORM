{ =============================================================================
  Parameters.SourceBase - base comum das fontes de FICHEIRO (INI / JSON)

  TParametersSourceBase (abstrata) implementa IParametersSource com CRUD/escopo/
  import-export/ToJSON/lock GENERICOS, delegando so a PERSISTENCIA fisica a dois
  hooks (Template Method): LoadAll (le TODO o store -> TParameterList) e
  SaveAll (escreve a lista completa). Elimina as ~800 linhas triplicadas do v1
  (INI e JSON partilhavam escopo/CRUD/import-export com storage distinto).

  Modelo unificado v3 (resolve as divergencias do v1):
  - unidade de armazenamento = TITULO (seccao INI / objeto JSON);
  - contrato/produto = escopo do ficheiro (a fonte carimba nos parametros);
  - ordem = renumber-zero na coleccao (ordem<=0 -> proxima do grupo por titulo).
  A fonte Database (Parameters.Database) NAO usa esta base - assenta em F4/F5.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  2.0.0
  FileVersion:    1.1.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           21/07/2026

  Changelog (file):
  - 1.1.0 (21/07/2026): paridade v2.3.0 (validacao + Opcao B do owner) - (#1) core
    DoInsert: Insert(out ASuccess)=False em chave DUPLICADA (era True/skip silencioso);
    (#4) ToJSON HIERARQUICO (Contrato + Titulo -> valor/descricao/ativo/ordem, nao mais
    dicionario plano); (#6) MakeRoomForOrder: renumera irmaos quando ordem explicita
    colide (Insert/Save/Update); (#7 no Parameters.pas) RemoveSource reatribui a ativa.
  - 1.0.0 (17/07/2026): criacao (FASE 7, Onda 7.3) - base comum Template Method
    (LoadAll/SaveAll) com CRUD/escopo/import-export/ToJSON genericos e lock.
  ============================================================================= }

unit Parameters.SourceBase;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../ORM.Defines.inc}

{$IFDEF USE_PARAMETERS}

uses
{$IF DEFINED(FPC)}
  SysUtils, Classes, SyncObjs, fpjson,
{$ELSE}
  System.SysUtils, System.Classes, System.SyncObjs, System.JSON,
{$ENDIF}
  Commons.Types,
  Commons.Consts,                 // DEFAULT_DATABASE_PATH
  Commons.Parameters.Consts,      // DEFAULT_PARAMETER_AUTO_RENUMBER_ZERO_ORDER / DEFAULT_CONTRATO_ID / DEFAULT_PRODUTO_ID
  Exceptions.Parameters,
  Parameters.Interfaces;

type
  { ---------------------------------------------------------------------------
    TParametersSourceBase - base abstrata das fontes de ficheiro.

    As subclasses concretas (INI/JSON) implementam apenas os 4 hooks
    protegidos; todo o CRUD/escopo/import-export vive aqui.
    --------------------------------------------------------------------------- }
  TParametersSourceBase = class(TInterfacedObject, IParametersSource)
  strict protected
    FLock            : TCriticalSection;
    FContratoID      : Integer;
    FProdutoID       : Integer;
    FTitle           : string;
    FFilePath        : string;
    FAutoCreateFile  : Boolean;

    { --- Template Method hooks (implementados pelas fontes concretas) --- }
    function GetSourceKind: TParameterSource; virtual; abstract;
    function DefaultFileName: string; virtual; abstract;            // 'config.ini' / 'config.json'
    function LoadAll: TParameterList; virtual; abstract;            // le TODO o store -> lista OWNER
    procedure SaveAll(const AList: TParameterList); virtual; abstract; // escreve a lista completa

    { --- helpers comuns --- }
    function ResolveFilePath: string;                              // <EXE>\data\<DefaultFileName> se vazio
    function MatchesScope(const AParam: TParameter; const AName: string): Boolean;
    function CopyParameter(const ASrc: TParameter): TParameter;
    procedure StampScope(const AParam: TParameter);               // carimba contrato/produto/titulo
    function NextOrder(const AList: TParameterList; const ATitulo: string): Integer;
    function IndexOfKey(const AList: TParameterList; const ATitulo, AName: string): Integer;
    { core do Insert: True=inserido, False=chave ja existe (skip). RAISE em erro
      real (I/O, AutoCreateFile). Paridade v2.3.0: duplicado NAO lanca, so nao insere. }
    function DoInsert(const AParameter: TParameter): Boolean;
    { paridade v2.3.0 (AdjustOrdersFor*): se AOrder explicito colide com outra chave
      do mesmo titulo, desloca +1 os irmaos com ordem >= AOrder (abre espaco). }
    procedure MakeRoomForOrder(const AList: TParameterList; const ATitulo, AName: string; const AOrder: Integer);
  public
    constructor Create;
    destructor Destroy; override;

    { IParametersSource }
    function Source: TParameterSource;
    function ContratoID(const AValue: Integer): IParametersSource; overload;
    function ContratoID: Integer; overload;
    function ProdutoID(const AValue: Integer): IParametersSource; overload;
    function ProdutoID: Integer; overload;
    function Title(const AValue: string): IParametersSource; overload;
    function Title: string; overload;

    function Select(const AName: string): TParameter; overload;
    function Select(const AName: string; out AParameter: TParameter): IParametersSource; overload;
    function Select: TParameterList; overload;
    function Select(out AList: TParameterList): IParametersSource; overload;
    function Insert(const AParameter: TParameter): IParametersSource; overload;
    function Insert(const AParameter: TParameter; out ASuccess: Boolean): IParametersSource; overload;
    function Update(const AParameter: TParameter): IParametersSource; overload;
    function Update(const AParameter: TParameter; out ASuccess: Boolean): IParametersSource; overload;
    function Save(const AParameter: TParameter): IParametersSource; overload;
    function Save(const AParameter: TParameter; out ASuccess: Boolean): IParametersSource; overload;
    function Delete(const AName: string): IParametersSource; overload;
    function Delete(const AName: string; out ASuccess: Boolean): IParametersSource; overload;
    function Exists(const AName: string): Boolean; overload;
    function Exists(const AName: string; out AExists: Boolean): IParametersSource; overload;
    function Count: Integer; overload;
    function Count(out ACount: Integer): IParametersSource; overload;
    function Refresh: IParametersSource;
    function ToJSON: TJSONObject;
    function ImportFrom(const ASource: IParametersSource): IParametersSource; overload;
    function ImportFrom(const ASource: IParametersSource; out ASuccess: Boolean): IParametersSource; overload;
    function ExportTo(const ASource: IParametersSource): IParametersSource; overload;
    function ExportTo(const ASource: IParametersSource; out ASuccess: Boolean): IParametersSource; overload;
{$IFDEF USE_DEPRECATED}
    { --- Compat v1.0.7 (deprecated; delega ao CRUD v3) --- }
    function Getter(const AName: string): TParameter; overload;
    function Getter(const AName: string; out AParameter: TParameter): IParametersSource; overload;
    function List: TParameterList; overload;
    function List(out AList: TParameterList): IParametersSource; overload;
    function Setter(const AParameter: TParameter): IParametersSource; overload;
    function Setter(const AParameter: TParameter; out ASuccess: Boolean): IParametersSource; overload;
{$ENDIF}
  end;

{$ENDIF USE_PARAMETERS}

implementation

{$IFDEF USE_PARAMETERS}

{ helpers JSON cross-compiler locais (ToJSON hierarquico - paridade v2.3.0). }
{$IF DEFINED(FPC)}
procedure JAddStrL(const AObj: TJSONObject; const AKey, AValue: string); begin AObj.Add(AKey, AValue); end;
procedure JAddIntL(const AObj: TJSONObject; const AKey: string; const AValue: Integer); begin AObj.Add(AKey, AValue); end;
procedure JAddBoolL(const AObj: TJSONObject; const AKey: string; const AValue: Boolean); begin AObj.Add(AKey, AValue); end;
procedure JAddObjL(const AObj: TJSONObject; const AKey: string; const AValue: TJSONObject); begin AObj.Add(AKey, AValue); end;
function JGetObjL(const AObj: TJSONObject; const AKey: string): TJSONObject;
var LD: TJSONData;
begin LD := AObj.Find(AKey); if (LD <> nil) and (LD.JSONType = jtObject) then Result := TJSONObject(LD) else Result := nil; end;
{$ELSE}
procedure JAddStrL(const AObj: TJSONObject; const AKey, AValue: string); begin AObj.AddPair(AKey, AValue); end;
procedure JAddIntL(const AObj: TJSONObject; const AKey: string; const AValue: Integer); begin AObj.AddPair(AKey, TJSONNumber.Create(AValue)); end;
procedure JAddBoolL(const AObj: TJSONObject; const AKey: string; const AValue: Boolean); begin AObj.AddPair(AKey, TJSONBool.Create(AValue)); end;
procedure JAddObjL(const AObj: TJSONObject; const AKey: string; const AValue: TJSONObject); begin AObj.AddPair(AKey, AValue); end;
function JGetObjL(const AObj: TJSONObject; const AKey: string): TJSONObject;
var LV: TJSONValue;
begin LV := AObj.GetValue(AKey); if LV is TJSONObject then Result := TJSONObject(LV) else Result := nil; end;
{$ENDIF}

{ TParametersSourceBase }

constructor TParametersSourceBase.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FContratoID := DEFAULT_CONTRATO_ID;
  FProdutoID := DEFAULT_PRODUTO_ID;
  FTitle := '';
  FFilePath := '';
  FAutoCreateFile := True;
end;

destructor TParametersSourceBase.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

{ --- helpers --- }

function TParametersSourceBase.ResolveFilePath: string;
begin
  if FFilePath <> '' then
    Result := FFilePath
  else
    Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
              DEFAULT_DATABASE_PATH + DefaultFileName;
end;

function TParametersSourceBase.MatchesScope(const AParam: TParameter; const AName: string): Boolean;
begin
  { escopo do ficheiro = titulo (contrato/produto sao globais ao ficheiro). }
  Result := ((FTitle = '') or SameText(AParam.Titulo, FTitle)) and
            ((AName = '') or SameText(AParam.Name, AName));
end;

function TParametersSourceBase.CopyParameter(const ASrc: TParameter): TParameter;
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

procedure TParametersSourceBase.StampScope(const AParam: TParameter);
begin
  AParam.ContratoID := FContratoID;
  AParam.ProdutoID := FProdutoID;
  if FTitle <> '' then
    AParam.Titulo := FTitle
  else if Trim(AParam.Titulo) = '' then
    AParam.Titulo := 'Default';
end;

function TParametersSourceBase.NextOrder(const AList: TParameterList; const ATitulo: string): Integer;
var
  I, LMax: Integer;
begin
  LMax := 0;
  for I := 0 to AList.Count - 1 do
    if SameText(AList[I].Titulo, ATitulo) and (AList[I].Ordem > LMax) then
      LMax := AList[I].Ordem;
  Result := LMax + 1;
end;

function TParametersSourceBase.IndexOfKey(const AList: TParameterList; const ATitulo, AName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to AList.Count - 1 do
    if SameText(AList[I].Titulo, ATitulo) and SameText(AList[I].Name, AName) then
      Exit(I);
end;

procedure TParametersSourceBase.MakeRoomForOrder(const AList: TParameterList; const ATitulo, AName: string; const AOrder: Integer);
var
  I: Integer;
  LCollision: Boolean;
begin
  if AOrder <= 0 then
    Exit;
  { ha colisao? outra chave (nome diferente) no mesmo titulo com a MESMA ordem. }
  LCollision := False;
  for I := 0 to AList.Count - 1 do
    if SameText(AList[I].Titulo, ATitulo) and (not SameText(AList[I].Name, AName)) and (AList[I].Ordem = AOrder) then
    begin
      LCollision := True;
      Break;
    end;
  if not LCollision then
    Exit;
  { desloca +1 os irmaos com ordem >= AOrder (excepto a propria chave). }
  for I := 0 to AList.Count - 1 do
    if SameText(AList[I].Titulo, ATitulo) and (not SameText(AList[I].Name, AName)) and (AList[I].Ordem >= AOrder) then
      AList[I].Ordem := AList[I].Ordem + 1;
end;

{ --- identificacao / escopo --- }

function TParametersSourceBase.Source: TParameterSource;
begin
  Result := GetSourceKind;
end;

function TParametersSourceBase.ContratoID(const AValue: Integer): IParametersSource;
begin
  FContratoID := AValue;
  Result := Self;
end;

function TParametersSourceBase.ContratoID: Integer;
begin
  Result := FContratoID;
end;

function TParametersSourceBase.ProdutoID(const AValue: Integer): IParametersSource;
begin
  FProdutoID := AValue;
  Result := Self;
end;

function TParametersSourceBase.ProdutoID: Integer;
begin
  Result := FProdutoID;
end;

function TParametersSourceBase.Title(const AValue: string): IParametersSource;
begin
  FTitle := AValue;
  Result := Self;
end;

function TParametersSourceBase.Title: string;
begin
  Result := FTitle;
end;

{ --- CRUD (generico via LoadAll/SaveAll) --- }

function TParametersSourceBase.Select(const AName: string): TParameter;
var
  LList: TParameterList;
  I: Integer;
begin
  FLock.Acquire;
  try
    Result := nil;
    LList := LoadAll;
    try
      for I := 0 to LList.Count - 1 do
        if MatchesScope(LList[I], AName) then
        begin
          Result := CopyParameter(LList[I]);
          Break;
        end;
    finally
      LList.Free;
    end;
  finally
    FLock.Release;
  end;
end;

function TParametersSourceBase.Select(const AName: string; out AParameter: TParameter): IParametersSource;
begin
  AParameter := Select(AName);
  Result := Self;
end;

function TParametersSourceBase.Select: TParameterList;
var
  LAll: TParameterList;
  I: Integer;
begin
  FLock.Acquire;
  try
    Result := TParameterList.Create;
    LAll := LoadAll;
    try
      for I := 0 to LAll.Count - 1 do
        if MatchesScope(LAll[I], '') then
          Result.Add(CopyParameter(LAll[I]));
    finally
      LAll.Free;
    end;
  finally
    FLock.Release;
  end;
end;

function TParametersSourceBase.Select(out AList: TParameterList): IParametersSource;
begin
  AList := Select;
  Result := Self;
end;

function TParametersSourceBase.DoInsert(const AParameter: TParameter): Boolean;
var
  LList: TParameterList;
  LNew: TParameter;
begin
  Result := False;
  FLock.Acquire;
  try
    LList := LoadAll;
    try
      LNew := CopyParameter(AParameter);
      StampScope(LNew);
      if IndexOfKey(LList, LNew.Titulo, LNew.Name) >= 0 then
      begin
        LNew.Free;   { chave ja existe: nao insere, sem excecao (paridade v2.3.0). }
        Exit;
      end;
      { renumber-zero (ordem<=0) OU abre espaco se ordem explicita colide. }
      if (LNew.Ordem <= 0) and DEFAULT_PARAMETER_AUTO_RENUMBER_ZERO_ORDER then
        LNew.Ordem := NextOrder(LList, LNew.Titulo)
      else
        MakeRoomForOrder(LList, LNew.Titulo, LNew.Name, LNew.Ordem);
      LList.Add(LNew);
      SaveAll(LList);
      Result := True;
    finally
      LList.Free;
    end;
  finally
    FLock.Release;
  end;
end;

function TParametersSourceBase.Insert(const AParameter: TParameter): IParametersSource;
begin
  DoInsert(AParameter);   { void: propaga excecao em erro real; duplicado = skip silencioso. }
  Result := Self;
end;

function TParametersSourceBase.Insert(const AParameter: TParameter; out ASuccess: Boolean): IParametersSource;
begin
  ASuccess := False;
  { ASuccess=False em DUPLICADO (DoInsert devolve False) OU em erro real (except). }
  try ASuccess := DoInsert(AParameter); except ASuccess := False; end;
  Result := Self;
end;

function TParametersSourceBase.Update(const AParameter: TParameter): IParametersSource;
var
  LList: TParameterList;
  LTitulo: string;
  LIdx: Integer;
begin
  FLock.Acquire;
  try
    if FTitle <> '' then LTitulo := FTitle else LTitulo := AParameter.Titulo;
    LList := LoadAll;
    try
      LIdx := IndexOfKey(LList, LTitulo, AParameter.Name);
      if LIdx >= 0 then
      begin
        LList[LIdx].Value := AParameter.Value;
        LList[LIdx].Description := AParameter.Description;
        LList[LIdx].Ativo := AParameter.Ativo;
        if AParameter.Ordem > 0 then
        begin
          MakeRoomForOrder(LList, LTitulo, AParameter.Name, AParameter.Ordem);
          LList[LIdx].Ordem := AParameter.Ordem;
        end;
        SaveAll(LList);
      end;
    finally
      LList.Free;
    end;
  finally
    FLock.Release;
  end;
  Result := Self;
end;

function TParametersSourceBase.Update(const AParameter: TParameter; out ASuccess: Boolean): IParametersSource;
begin
  ASuccess := False;
  try Update(AParameter); ASuccess := True; except ASuccess := False; end;
  Result := Self;
end;

function TParametersSourceBase.Save(const AParameter: TParameter): IParametersSource;
var
  LList: TParameterList;
  LNew: TParameter;
  LTitulo: string;
  LIdx: Integer;
begin
  FLock.Acquire;
  try
    if FTitle <> '' then LTitulo := FTitle
    else if Trim(AParameter.Titulo) <> '' then LTitulo := AParameter.Titulo
    else LTitulo := 'Default';
    LList := LoadAll;
    try
      LIdx := IndexOfKey(LList, LTitulo, AParameter.Name);
      if LIdx >= 0 then
      begin
        LList[LIdx].Value := AParameter.Value;
        LList[LIdx].Description := AParameter.Description;
        LList[LIdx].Ativo := AParameter.Ativo;
        if AParameter.Ordem > 0 then
        begin
          MakeRoomForOrder(LList, LTitulo, AParameter.Name, AParameter.Ordem);
          LList[LIdx].Ordem := AParameter.Ordem;
        end;
      end
      else
      begin
        LNew := CopyParameter(AParameter);
        StampScope(LNew);
        if (LNew.Ordem <= 0) and DEFAULT_PARAMETER_AUTO_RENUMBER_ZERO_ORDER then
          LNew.Ordem := NextOrder(LList, LNew.Titulo)
        else
          MakeRoomForOrder(LList, LNew.Titulo, LNew.Name, LNew.Ordem);
        LList.Add(LNew);
      end;
      SaveAll(LList);
    finally
      LList.Free;
    end;
  finally
    FLock.Release;
  end;
  Result := Self;
end;

function TParametersSourceBase.Save(const AParameter: TParameter; out ASuccess: Boolean): IParametersSource;
begin
  ASuccess := False;
  try Save(AParameter); ASuccess := True; except ASuccess := False; end;
  Result := Self;
end;

function TParametersSourceBase.Delete(const AName: string): IParametersSource;
var
  LList: TParameterList;
  I: Integer;
  LRemoved: Boolean;
begin
  FLock.Acquire;
  try
    LList := LoadAll;
    try
      LRemoved := False;
      for I := LList.Count - 1 downto 0 do
        if MatchesScope(LList[I], AName) then
        begin
          LList[I].Free;
          LList.Delete(I);
          LRemoved := True;
        end;
      if LRemoved then
        SaveAll(LList);
    finally
      LList.Free;
    end;
  finally
    FLock.Release;
  end;
  Result := Self;
end;

function TParametersSourceBase.Delete(const AName: string; out ASuccess: Boolean): IParametersSource;
begin
  ASuccess := False;
  try Delete(AName); ASuccess := True; except ASuccess := False; end;
  Result := Self;
end;

function TParametersSourceBase.Exists(const AName: string): Boolean;
var
  LList: TParameterList;
  I: Integer;
begin
  FLock.Acquire;
  try
    Result := False;
    LList := LoadAll;
    try
      for I := 0 to LList.Count - 1 do
        if MatchesScope(LList[I], AName) then
        begin
          Result := True;
          Break;
        end;
    finally
      LList.Free;
    end;
  finally
    FLock.Release;
  end;
end;

function TParametersSourceBase.Exists(const AName: string; out AExists: Boolean): IParametersSource;
begin
  AExists := Exists(AName);
  Result := Self;
end;

function TParametersSourceBase.Count: Integer;
var
  LList: TParameterList;
  I: Integer;
begin
  FLock.Acquire;
  try
    Result := 0;
    LList := LoadAll;
    try
      for I := 0 to LList.Count - 1 do
        if MatchesScope(LList[I], '') then
          Inc(Result);
    finally
      LList.Free;
    end;
  finally
    FLock.Release;
  end;
end;

function TParametersSourceBase.Count(out ACount: Integer): IParametersSource;
begin
  ACount := Count;
  Result := Self;
end;

function TParametersSourceBase.Refresh: IParametersSource;
begin
  { load-all le sempre fresco do ficheiro -> no-op. }
  Result := Self;
end;

function TParametersSourceBase.ToJSON: TJSONObject;
var
  LList: TParameterList;
  I: Integer;
  LCont, LTit, LKey: TJSONObject;
begin
  { formato HIERARQUICO (paridade v2.3.0): raiz -> objeto "Contrato" (Contrato_ID/
    Produto_ID) + um objeto por Titulo -> um objeto por chave com valor/descricao/
    ativo/ordem (registo completo, nao mais o dicionario plano chave:valor). }
  Result := TJSONObject.Create;
  LCont := TJSONObject.Create;
  JAddIntL(LCont, 'Contrato_ID', FContratoID);
  JAddIntL(LCont, 'Produto_ID', FProdutoID);
  JAddObjL(Result, 'Contrato', LCont);
  LList := Select;   { ja filtrado por escopo + copias. }
  try
    for I := 0 to LList.Count - 1 do
    begin
      LTit := JGetObjL(Result, LList[I].Titulo);
      if LTit = nil then
      begin
        LTit := TJSONObject.Create;
        JAddObjL(Result, LList[I].Titulo, LTit);
      end;
      LKey := TJSONObject.Create;
      JAddStrL(LKey, 'valor', LList[I].Value);
      JAddStrL(LKey, 'descricao', LList[I].Description);
      JAddBoolL(LKey, 'ativo', LList[I].Ativo);
      JAddIntL(LKey, 'ordem', LList[I].Ordem);
      JAddObjL(LTit, LList[I].Name, LKey);
    end;
  finally
    LList.Free;
  end;
end;

function TParametersSourceBase.ImportFrom(const ASource: IParametersSource): IParametersSource;
var
  LList: TParameterList;
  I: Integer;
begin
  { le da origem (uniforme) e faz upsert em self - uma vez so p/ todas as fontes. }
  LList := ASource.Select;
  try
    for I := 0 to LList.Count - 1 do
      Save(LList[I]);
  finally
    LList.Free;
  end;
  Result := Self;
end;

function TParametersSourceBase.ImportFrom(const ASource: IParametersSource; out ASuccess: Boolean): IParametersSource;
begin
  ASuccess := False;
  try ImportFrom(ASource); ASuccess := True; except ASuccess := False; end;
  Result := Self;
end;

function TParametersSourceBase.ExportTo(const ASource: IParametersSource): IParametersSource;
var
  LList: TParameterList;
  I: Integer;
begin
  LList := Select;
  try
    for I := 0 to LList.Count - 1 do
      ASource.Save(LList[I]);
  finally
    LList.Free;
  end;
  Result := Self;
end;

function TParametersSourceBase.ExportTo(const ASource: IParametersSource; out ASuccess: Boolean): IParametersSource;
begin
  ASuccess := False;
  try ExportTo(ASource); ASuccess := True; except ASuccess := False; end;
  Result := Self;
end;

{$IFDEF USE_DEPRECATED}

{ --- Compat v1.0.7 (deprecated) - delega ao CRUD v3 --- }

function TParametersSourceBase.Getter(const AName: string): TParameter;
begin
  Result := Select(AName);
end;

function TParametersSourceBase.Getter(const AName: string; out AParameter: TParameter): IParametersSource;
begin
  Result := Select(AName, AParameter);
end;

function TParametersSourceBase.List: TParameterList;
begin
  Result := Select;
end;

function TParametersSourceBase.List(out AList: TParameterList): IParametersSource;
begin
  Result := Select(AList);
end;

function TParametersSourceBase.Setter(const AParameter: TParameter): IParametersSource;
begin
  Result := Save(AParameter);
end;

function TParametersSourceBase.Setter(const AParameter: TParameter; out ASuccess: Boolean): IParametersSource;
begin
  Result := Save(AParameter, ASuccess);
end;

{$ENDIF}

{$ENDIF USE_PARAMETERS}

end.
