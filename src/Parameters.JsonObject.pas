{ =============================================================================
  Parameters.JsonObject - fonte JSON do modulo Parameters (TParametersJsonObject)

  Modulo INTERNO (nao reusa F4/F5): assenta na base comum TParametersSourceBase
  (Template Method + lock). So implementa os hooks LoadAll/SaveAll (JSON cross-
  compiler: System.JSON no Delphi, fpjson/jsonparser no FPC) e a config propria.

  Modelo: objeto raiz -> objeto por Titulo -> objeto por chave com as propriedades
  valor/descricao/ativo/ordem (registo completo, ao contrario do INI). A marca de
  escopo e o objeto "Contrato" (Contrato_ID/Produto_ID), global ao ficheiro.
  Encoding: escrita UTF-8 SEM BOM; leitura salta o BOM UTF-8 se presente.

  I/O resiliente: leitura/escrita fazem retry com backoff em EStreamError para
  tolerar bloqueios EXTERNOS transitorios do ficheiro (Dropbox/OneDrive/AV/editor
  a segurar o handle) - o CRUD ja e serializado pelo FLock da instancia.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  2.0.0
  FileVersion:    1.2.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           21/07/2026

  Changelog (file):
  - 1.2.0 (21/07/2026): paridade v2.3.0 (validacao + Opcao B) - (#2) leitura deteta
    encoding UTF-8/UTF-16 LE-BE (com/sem BOM), ANSI cai em UTF-8; (#3) modo EM-MEMORIA
    (FInMemory/FBuffer): LoadFromString/JsonObject(obj) operam sem tocar o disco,
    LoadFromFile volta ao modo ficheiro, SaveToFile(path) persiste; (#5) LoadAll com
    AutoCreateFile=False + ficheiro ausente lanca tambem na LEITURA.
  - 1.1.0 (21/07/2026): I/O resiliente com retry+backoff em EStreamError no open
    do TFileStream (sharing violation externa, ex. Dropbox); guarda AutoCreateFile
    no SaveAll; LBytes inicializado (silencia hint FPC). (bug-625)
  - 1.0.0 (17/07/2026): criacao (FASE 7, Onda 7.3) - fonte JSON sobre a base
    comum; LoadAll/SaveAll com JSON cross-compiler; FilePath/ObjectName/
    AutoCreateFile + ToJSONString/SaveToFile/LoadFromFile/LoadFromString.
  ============================================================================= }

unit Parameters.JsonObject;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_PARAMETERS}

uses
{$IF DEFINED(FPC)}
  SysUtils, Classes, fpjson, jsonparser,
{$ELSE}
  System.SysUtils, System.Classes, System.JSON,
{$ENDIF}
  Commons.Types,
  Exceptions.Parameters,
  Parameters.Interfaces,
  Parameters.SourceBase;

type
  TParametersJsonObject = class(TParametersSourceBase, IParametersJsonObject)
  strict private
    { modo em-memoria (paridade v2.3.0): LoadFromString/JsonObject(obj) operam sobre
      FBuffer (texto JSON) sem tocar o disco; LoadFromFile volta ao modo ficheiro.
      SaveToFile(path) persiste explicitamente. }
    FInMemory: Boolean;
    FBuffer: string;
  strict protected
    function GetSourceKind: TParameterSource; override;
    function DefaultFileName: string; override;
    function LoadAll: TParameterList; override;
    procedure SaveAll(const AList: TParameterList); override;
  public
    { IParametersJsonObject }
    function FilePath(const AValue: string): IParametersJsonObject; overload;
    function FilePath: string; overload;
    function ObjectName(const AValue: string): IParametersJsonObject; overload;
    function ObjectName: string; overload;
    function JsonObject(const AValue: TJSONObject): IParametersJsonObject; overload;
    function JsonObject: TJSONObject; overload;
    function AutoCreateFile(const AValue: Boolean): IParametersJsonObject; overload;
    function AutoCreateFile: Boolean; overload;
    function FileExists: Boolean;
    function ToJSONString: string;
    function SaveToFile(const AFilePath: string = ''): IParametersJsonObject; overload;
    function LoadFromFile(const AFilePath: string = ''): IParametersJsonObject; overload;
    function LoadFromString(const AJsonString: string): IParametersJsonObject;
{$IFDEF USE_DEPRECATED}
    function EndJsonObject: IInterface;
    function SaveToFile(const AFilePath: string; out ASuccess: Boolean): IParametersJsonObject; overload;
    function LoadFromFile(const AFilePath: string; out ASuccess: Boolean): IParametersJsonObject; overload;
{$ENDIF}
  end;

{$ENDIF USE_PARAMETERS}

implementation

{$IFDEF USE_PARAMETERS}

uses
  Commons.Consts;   // DEFAULT_CONFIG_JSON_FILENAME

const
  SCOPE_OBJECT = 'Contrato';

{ --- wrappers de unit: ficheiro (sem colisao com o metodo FileExists da classe;
  UTF-8 sem BOM na escrita, salta BOM na leitura) --- }

function FileExistsU(const APath: string): Boolean;
begin
  Result := FileExists(APath);
end;

const
  FILE_IO_RETRIES = 20;   { tentativas; backoff progressivo por tentativa. }
  FILE_IO_BACKOFF = 8;    { ms base: espera = FILE_IO_BACKOFF*(tentativa+1). }

{ Abre o TFileStream com retry em EStreamError - tolera bloqueio EXTERNO
  transitorio do ficheiro (Dropbox/OneDrive/AV/editor a segurar o handle). A
  sharing violation no open aparece como EFOpenError/EFCreateError (EStreamError). }
function CreateFileStreamResilient(const APath: string; const AMode: Word): TFileStream;
var LAttempt: Integer;
begin
  Result := nil;
  for LAttempt := 0 to FILE_IO_RETRIES do
    try
      Result := TFileStream.Create(APath, AMode);
      Exit;
    except
      on EStreamError do
        if LAttempt >= FILE_IO_RETRIES then raise
        else TThread.Sleep(FILE_IO_BACKOFF * (LAttempt + 1));
    end;
end;

procedure WriteAllTextU(const APath, AText: string);
var
  LBytes: TBytes;
  LStream: TFileStream;
begin
  LBytes := TEncoding.UTF8.GetBytes(AText);
  LStream := CreateFileStreamResilient(APath, fmCreate);
  try
    if Length(LBytes) > 0 then
      LStream.WriteBuffer(LBytes[0], Length(LBytes));
  finally
    LStream.Free;
  end;
end;

{ heuristica: ASCII/JSON em UTF-16 LE SEM BOM -> a maioria dos bytes IMPARES e 0. }
function LooksLikeUtf16LE(const ABytes: TBytes): Boolean;
var I, LZeroOdd, LTotal: Integer;
begin
  LTotal := Length(ABytes);
  if LTotal < 4 then Exit(False);
  LZeroOdd := 0;
  I := 1;
  while I < LTotal do begin if ABytes[I] = 0 then Inc(LZeroOdd); Inc(I, 2); end;
  Result := (LZeroOdd * 2) > (LTotal div 2);
end;

{ Decodifica os bytes lidos respeitando o encoding (paridade v2.3.0): UTF-8 (com/sem
  BOM), UTF-16 LE/BE (com/sem BOM). ANSI/ASCII cai no ramo UTF-8 (compativel p/ ASCII). }
function DecodeBytesToString(const ABytes: TBytes): string;
var LLen: Integer;
begin
  LLen := Length(ABytes);
  if LLen = 0 then Exit('');
  if (LLen >= 3) and (ABytes[0] = $EF) and (ABytes[1] = $BB) and (ABytes[2] = $BF) then
    Result := TEncoding.UTF8.GetString(Copy(ABytes, 3, MaxInt))                { UTF-8 BOM }
  else if (LLen >= 2) and (ABytes[0] = $FF) and (ABytes[1] = $FE) then
    Result := TEncoding.Unicode.GetString(Copy(ABytes, 2, MaxInt))            { UTF-16 LE BOM }
  else if (LLen >= 2) and (ABytes[0] = $FE) and (ABytes[1] = $FF) then
    Result := TEncoding.BigEndianUnicode.GetString(Copy(ABytes, 2, MaxInt))   { UTF-16 BE BOM }
  else if LooksLikeUtf16LE(ABytes) then
    Result := TEncoding.Unicode.GetString(ABytes)                             { UTF-16 LE sem BOM }
  else
    Result := TEncoding.UTF8.GetString(ABytes);                               { UTF-8 / ASCII / ANSI }
end;

function ReadAllTextU(const APath: string): string;
var
  LBytes: TBytes;
  LStream: TFileStream;
begin
  LBytes := nil;
  LStream := CreateFileStreamResilient(APath, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(LBytes, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(LBytes[0], LStream.Size);
  finally
    LStream.Free;
  end;
  Result := DecodeBytesToString(LBytes);
end;

{ --- wrappers de unit: JSON cross-compiler --- }

{$IF DEFINED(FPC)}
function JParseObj(const AText: string): TJSONObject;
var LD: TJSONData;
begin
  Result := nil;
  try LD := GetJSON(AText); except LD := nil; end;
  if LD <> nil then
  begin
    if LD.JSONType = jtObject then Result := TJSONObject(LD)
    else LD.Free;
  end;
end;
procedure JAddStr(const AObj: TJSONObject; const AKey, AValue: string); begin AObj.Add(AKey, AValue); end;
procedure JAddInt(const AObj: TJSONObject; const AKey: string; const AValue: Integer); begin AObj.Add(AKey, AValue); end;
procedure JAddBool(const AObj: TJSONObject; const AKey: string; const AValue: Boolean); begin AObj.Add(AKey, AValue); end;
procedure JAddObj(const AObj: TJSONObject; const AKey: string; const AValue: TJSONObject); begin AObj.Add(AKey, AValue); end;
function JGetStr(const AObj: TJSONObject; const AKey, ADef: string): string; begin Result := AObj.Get(AKey, ADef); end;
function JGetInt(const AObj: TJSONObject; const AKey: string; const ADef: Integer): Integer; begin Result := AObj.Get(AKey, ADef); end;
function JGetBool(const AObj: TJSONObject; const AKey: string; const ADef: Boolean): Boolean; begin Result := AObj.Get(AKey, ADef); end;
function JGetObj(const AObj: TJSONObject; const AKey: string): TJSONObject;
var LD: TJSONData;
begin LD := AObj.Find(AKey); if (LD <> nil) and (LD.JSONType = jtObject) then Result := TJSONObject(LD) else Result := nil; end;
function JCount(const AObj: TJSONObject): Integer; begin Result := AObj.Count; end;
function JKeyAt(const AObj: TJSONObject; const AIndex: Integer): string; begin Result := AObj.Names[AIndex]; end;
function JObjAt(const AObj: TJSONObject; const AIndex: Integer): TJSONObject;
begin if AObj.Items[AIndex].JSONType = jtObject then Result := TJSONObject(AObj.Items[AIndex]) else Result := nil; end;
function JSerialize(const AObj: TJSONObject): string; begin Result := AObj.FormatJSON; end;
{$ELSE}
function JParseObj(const AText: string): TJSONObject;
var LV: TJSONValue;
begin
  Result := nil;
  LV := TJSONObject.ParseJSONValue(AText);
  if LV is TJSONObject then Result := TJSONObject(LV)
  else if LV <> nil then LV.Free;
end;
procedure JAddStr(const AObj: TJSONObject; const AKey, AValue: string); begin AObj.AddPair(AKey, AValue); end;
procedure JAddInt(const AObj: TJSONObject; const AKey: string; const AValue: Integer); begin AObj.AddPair(AKey, TJSONNumber.Create(AValue)); end;
procedure JAddBool(const AObj: TJSONObject; const AKey: string; const AValue: Boolean); begin AObj.AddPair(AKey, TJSONBool.Create(AValue)); end;
procedure JAddObj(const AObj: TJSONObject; const AKey: string; const AValue: TJSONObject); begin AObj.AddPair(AKey, AValue); end;
function JGetStr(const AObj: TJSONObject; const AKey, ADef: string): string;
var LV: TJSONValue;
begin LV := AObj.GetValue(AKey); if LV <> nil then Result := LV.Value else Result := ADef; end;
function JGetInt(const AObj: TJSONObject; const AKey: string; const ADef: Integer): Integer;
var LV: TJSONValue;
begin LV := AObj.GetValue(AKey); if LV is TJSONNumber then Result := TJSONNumber(LV).AsInt else Result := ADef; end;
function JGetBool(const AObj: TJSONObject; const AKey: string; const ADef: Boolean): Boolean;
var LV: TJSONValue;
begin LV := AObj.GetValue(AKey); if LV is TJSONBool then Result := TJSONBool(LV).AsBoolean else Result := ADef; end;
function JGetObj(const AObj: TJSONObject; const AKey: string): TJSONObject;
var LV: TJSONValue;
begin LV := AObj.GetValue(AKey); if LV is TJSONObject then Result := TJSONObject(LV) else Result := nil; end;
function JCount(const AObj: TJSONObject): Integer; begin Result := AObj.Count; end;
function JKeyAt(const AObj: TJSONObject; const AIndex: Integer): string; begin Result := AObj.Pairs[AIndex].JsonString.Value; end;
function JObjAt(const AObj: TJSONObject; const AIndex: Integer): TJSONObject;
begin if AObj.Pairs[AIndex].JsonValue is TJSONObject then Result := TJSONObject(AObj.Pairs[AIndex].JsonValue) else Result := nil; end;
function JSerialize(const AObj: TJSONObject): string; begin Result := AObj.ToJSON; end;
{$ENDIF}

{ --- hooks --- }

function TParametersJsonObject.GetSourceKind: TParameterSource;
begin
  Result := psJsonObject;
end;

function TParametersJsonObject.DefaultFileName: string;
begin
  Result := DEFAULT_CONFIG_JSON_FILENAME;   // 'config.json'
end;

function TParametersJsonObject.LoadAll: TParameterList;
var
  LRoot, LTituloObj, LKeyObj, LContObj: TJSONObject;
  LTitulo, LKey: string;
  LContrato, LProduto, T, K: Integer;
  LParam: TParameter;
begin
  Result := TParameterList.Create;
  if FInMemory then
  begin
    { modo em-memoria: parse do buffer, sem tocar o disco (paridade v2.3.0). }
    if Trim(FBuffer) = '' then
      Exit;
    LRoot := JParseObj(FBuffer);
  end
  else
  begin
    if not FileExistsU(ResolveFilePath) then
    begin
      { paridade v2.3.0: AutoCreateFile=False + ficheiro ausente -> erro na LEITURA. }
      if not FAutoCreateFile then
        raise EParametersConfigurationException.Create(
          'Parameters.JsonObject: ficheiro "' + ResolveFilePath +
          '" nao existe e AutoCreateFile=False - nada a ler.', 0, 'LoadAll');
      Exit;
    end;
    LRoot := JParseObj(ReadAllTextU(ResolveFilePath));
  end;
  if LRoot = nil then
    Exit;
  try
    LContrato := FContratoID;
    LProduto := FProdutoID;
    LContObj := JGetObj(LRoot, SCOPE_OBJECT);
    if LContObj <> nil then
    begin
      LContrato := JGetInt(LContObj, 'Contrato_ID', FContratoID);
      LProduto := JGetInt(LContObj, 'Produto_ID', FProdutoID);
    end;
    for T := 0 to JCount(LRoot) - 1 do
    begin
      LTitulo := JKeyAt(LRoot, T);
      if SameText(LTitulo, SCOPE_OBJECT) then
        Continue;
      LTituloObj := JObjAt(LRoot, T);
      if LTituloObj = nil then
        Continue;
      for K := 0 to JCount(LTituloObj) - 1 do
      begin
        LKey := JKeyAt(LTituloObj, K);
        LKeyObj := JObjAt(LTituloObj, K);
        LParam := TParameter.Create;
        LParam.Titulo := LTitulo;
        LParam.Name := LKey;
        if LKeyObj <> nil then
        begin
          LParam.Value       := JGetStr(LKeyObj, 'valor', '');
          LParam.Description  := JGetStr(LKeyObj, 'descricao', '');
          LParam.Ativo       := JGetBool(LKeyObj, 'ativo', True);
          LParam.Ordem       := JGetInt(LKeyObj, 'ordem', K + 1);
        end
        else
        begin
          LParam.Value := JGetStr(LTituloObj, LKey, '');
          LParam.Ativo := True;
          LParam.Ordem := K + 1;
        end;
        LParam.ContratoID := LContrato;
        LParam.ProdutoID := LProduto;
        Result.Add(LParam);
      end;
    end;
  finally
    LRoot.Free;
  end;
end;

procedure TParametersJsonObject.SaveAll(const AList: TParameterList);
var
  LRoot, LContObj, LTituloObj, LKeyObj: TJSONObject;
  I: Integer;
  LText: string;
begin
  LRoot := TJSONObject.Create;
  try
    LContObj := TJSONObject.Create;
    JAddInt(LContObj, 'Contrato_ID', FContratoID);
    JAddInt(LContObj, 'Produto_ID', FProdutoID);
    JAddObj(LRoot, SCOPE_OBJECT, LContObj);

    for I := 0 to AList.Count - 1 do
    begin
      LTituloObj := JGetObj(LRoot, AList[I].Titulo);
      if LTituloObj = nil then
      begin
        LTituloObj := TJSONObject.Create;
        JAddObj(LRoot, AList[I].Titulo, LTituloObj);
      end;
      LKeyObj := TJSONObject.Create;
      JAddStr(LKeyObj, 'valor', AList[I].Value);
      JAddStr(LKeyObj, 'descricao', AList[I].Description);
      JAddBool(LKeyObj, 'ativo', AList[I].Ativo);
      JAddInt(LKeyObj, 'ordem', AList[I].Ordem);
      JAddObj(LTituloObj, AList[I].Name, LKeyObj);
    end;

    LText := JSerialize(LRoot);
  finally
    LRoot.Free;
  end;
  if FInMemory then
  begin
    FBuffer := LText;   { modo em-memoria: atualiza o buffer, sem tocar o disco. }
    Exit;
  end;
  { AutoCreateFile (default True): False + ficheiro inexistente -> NAO cria (erro
    explicito), mesma semantica do TParametersIniFile. }
  if (not FAutoCreateFile) and (not FileExistsU(ResolveFilePath)) then
    raise EParametersConfigurationException.Create(
      'Parameters.JsonObject: ficheiro "' + ResolveFilePath +
      '" nao existe e AutoCreateFile=False - nada gravado.', 0, 'SaveAll');
  ForceDirectories(ExtractFilePath(ResolveFilePath));
  WriteAllTextU(ResolveFilePath, LText);
end;

{ --- IParametersJsonObject --- }

function TParametersJsonObject.FilePath(const AValue: string): IParametersJsonObject;
begin
  FFilePath := AValue;
  Result := Self;
end;

function TParametersJsonObject.FilePath: string;
begin
  Result := ResolveFilePath;
end;

function TParametersJsonObject.ObjectName(const AValue: string): IParametersJsonObject;
begin
  { o objeto JSON e o titulo -> alias de escopo. }
  FTitle := AValue;
  Result := Self;
end;

function TParametersJsonObject.ObjectName: string;
begin
  Result := FTitle;
end;

function TParametersJsonObject.JsonObject(const AValue: TJSONObject): IParametersJsonObject;
begin
  if AValue <> nil then
    LoadFromString(JSerialize(AValue));
  Result := Self;
end;

function TParametersJsonObject.JsonObject: TJSONObject;
begin
  Result := JParseObj(ToJSONString);
  if Result = nil then
    Result := TJSONObject.Create;
end;

function TParametersJsonObject.AutoCreateFile(const AValue: Boolean): IParametersJsonObject;
begin
  FAutoCreateFile := AValue;
  Result := Self;
end;

function TParametersJsonObject.AutoCreateFile: Boolean;
begin
  Result := FAutoCreateFile;
end;

function TParametersJsonObject.FileExists: Boolean;
begin
  Result := FileExistsU(ResolveFilePath);
end;

function TParametersJsonObject.ToJSONString: string;
begin
  if FInMemory then
  begin
    if Trim(FBuffer) <> '' then Result := FBuffer else Result := '{}';
  end
  else if FileExistsU(ResolveFilePath) then
    Result := ReadAllTextU(ResolveFilePath)
  else
    Result := '{}';
end;

function TParametersJsonObject.SaveToFile(const AFilePath: string): IParametersJsonObject;
var
  LList: TParameterList;
begin
  Result := Self;
  { modo ficheiro + sem path: ja persistido a cada operacao -> no-op.
    modo em-memoria OU path explicito: persiste no disco (e passa a modo ficheiro). }
  if (AFilePath = '') and (not FInMemory) then
    Exit;
  LList := Select;
  try
    FInMemory := False;
    if AFilePath <> '' then
      FFilePath := AFilePath;
    SaveAll(LList);
  finally
    LList.Free;
  end;
end;

function TParametersJsonObject.LoadFromFile(const AFilePath: string): IParametersJsonObject;
begin
  if AFilePath <> '' then
    FFilePath := AFilePath;
  FInMemory := False;   { volta ao modo FICHEIRO (a leitura passa a ser do disco). }
  FBuffer := '';
  Result := Self;
end;

function TParametersJsonObject.LoadFromString(const AJsonString: string): IParametersJsonObject;
begin
  { paridade v2.3.0: parse EM MEMORIA, sem tocar o disco. SaveToFile(path) persiste. }
  FInMemory := True;
  FBuffer := AJsonString;
  Result := Self;
end;

{$IFDEF USE_DEPRECATED}
function TParametersJsonObject.EndJsonObject: IInterface;
begin
  Result := Self;   { navegacao fluente v2.3.0: devolve a propria fonte. }
end;

function TParametersJsonObject.SaveToFile(const AFilePath: string; out ASuccess: Boolean): IParametersJsonObject;
begin
  ASuccess := False;
  try SaveToFile(AFilePath); ASuccess := True; except ASuccess := False; end;
  Result := Self;
end;

function TParametersJsonObject.LoadFromFile(const AFilePath: string; out ASuccess: Boolean): IParametersJsonObject;
begin
  ASuccess := False;
  try LoadFromFile(AFilePath); ASuccess := True; except ASuccess := False; end;
  Result := Self;
end;
{$ENDIF}

{$ENDIF USE_PARAMETERS}

end.
