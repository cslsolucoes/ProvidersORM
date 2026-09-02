{ =============================================================================
  Parameters.IniFile - fonte INI do modulo Parameters (TParametersIniFile)

  Modulo INTERNO (nao reusa F4/F5): assenta na base comum TParametersSourceBase
  (Template Method + lock). So implementa os hooks LoadAll/SaveAll (parsing linha-
  a-linha, mesma logica/semantica do produto v2.3.0/v1) e a config propria
  (FilePath/Section/AutoCreateFile).

  Modelo: seccao INI = Titulo; [#]chave=valor[ ; descricao] por parametro; '#' =
  INATIVO; tudo apos o 1o ';' = descricao; ordem = posicao fisica; marca [Contrato]
  com Contrato_ID/Produto_ID (escopo global do ficheiro). Comentarios e linhas
  vazias sao PRESERVADOS (SaveAll rele o ficheiro e so toca linhas de parametro).

  I/O resiliente: LoadAll/SaveAll fazem retry com backoff em EStreamError para
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
  - 1.2.0 (21/07/2026): paridade v2.3.0 (#5) - LoadAll com AutoCreateFile=False +
    ficheiro ausente lanca EParametersConfigurationException tambem na LEITURA
    (nao so na escrita).
  - 1.1.0 (21/07/2026): reescrita LoadAll/SaveAll linha-a-linha (sai o TIniFile):
    descricao/ativo(#)/ordem por-linha + preservacao de comentarios (refinamento
    v2.3.0/v1); I/O resiliente com retry+backoff em EStreamError (sharing violation
    externa, ex. Dropbox). (bug-625)
  - 1.0.0 (17/07/2026): criacao (FASE 7, Onda 7.3) - fonte INI sobre a base
    comum; LoadAll/SaveAll via TIniFile; FilePath/Section/AutoCreateFile.
  ============================================================================= }

unit Parameters.IniFile;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../../ORM.Defines.inc}

{$IFDEF USE_PARAMETERS}

uses
{$IF DEFINED(FPC)}
  SysUtils, Classes, IniFiles,
{$ELSE}
  System.SysUtils, System.Classes, System.IniFiles,
{$ENDIF}
  Commons.Types,
  Exceptions.Parameters,
  Parameters.Interfaces,
  Parameters.SourceBase;

type
  TParametersIniFile = class(TParametersSourceBase, IParametersIniFile)
  strict protected
    function GetSourceKind: TParameterSource; override;
    function DefaultFileName: string; override;
    function LoadAll: TParameterList; override;
    procedure SaveAll(const AList: TParameterList); override;
  public
    { IParametersIniFile }
    function FilePath(const AValue: string): IParametersIniFile; overload;
    function FilePath: string; overload;
    function Section(const AValue: string): IParametersIniFile; overload;
    function Section: string; overload;
    function AutoCreateFile(const AValue: Boolean): IParametersIniFile; overload;
    function AutoCreateFile: Boolean; overload;
    function FileExists: Boolean;
{$IFDEF USE_DEPRECATED}
    function EndInifiles: IInterface;
{$ENDIF}
  end;

{$ENDIF USE_PARAMETERS}

implementation

{$IFDEF USE_PARAMETERS}

uses
  Commons.Consts;   // DEFAULT_CONFIG_INI_FILENAME

const
  SCOPE_SECTION = 'Contrato';

{ Wrappers de unit: a nivel de unit nao ha colisao com o metodo homonimo
  TParametersIniFile.FileExists, entao FileExists/DeleteFile resolvem para o RTL
  sem qualificacao (evita `System.SysUtils.` [so Delphi] vs `SysUtils.` [so FPC]). }
function FileExistsU(const APath: string): Boolean;
begin
  Result := FileExists(APath);
end;

procedure DeleteFileU(const APath: string);
begin
  DeleteFile(APath);
end;

const
  FILE_IO_RETRIES = 20;   { tentativas; backoff progressivo por tentativa. }
  FILE_IO_BACKOFF = 8;    { ms base: espera = FILE_IO_BACKOFF*(tentativa+1). }

{ I/O resiliente a bloqueio EXTERNO transitorio do ficheiro (Dropbox/OneDrive/AV/
  editor com o handle aberto): retry com backoff em EStreamError (a sharing
  violation no open aparece como EFOpenError/EFCreateError, ambas EStreamError).
  O CRUD ja e serializado pelo FLock; isto cobre so o bloqueio de fora do processo. }
procedure IniLoadResilient(const ALines: TStringList; const APath: string);
var LAttempt: Integer;
begin
  for LAttempt := 0 to FILE_IO_RETRIES do
    try
      ALines.LoadFromFile(APath);
      Exit;
    except
      on EStreamError do
        if LAttempt >= FILE_IO_RETRIES then raise
        else TThread.Sleep(FILE_IO_BACKOFF * (LAttempt + 1));
    end;
end;

procedure IniSaveResilient(const ALines: TStringList; const APath: string);
var LAttempt: Integer;
begin
  for LAttempt := 0 to FILE_IO_RETRIES do
    try
      ALines.SaveToFile(APath);
      Exit;
    except
      on EStreamError do
        if LAttempt >= FILE_IO_RETRIES then raise
        else TThread.Sleep(FILE_IO_BACKOFF * (LAttempt + 1));
    end;
end;

{ --- parsing/format do formato INI (mesma logica/semantica do produto v2.3.0 e do
  standalone v1 - reescrita limpa, nao copia). Contrato:
    * parametro   = [#]chave=valor[ ; descricao] dentro de uma seccao [Titulo];
    * '#' inicial = INATIVO; ausencia = ativo;
    * tudo apos o 1o ';' da linha = DESCRICAO (sem escape - valor com ';' trunca);
    * o 1o '=' separa chave/valor (o resto do valor pode conter '=');
    * ORDEM        = posicao fisica (N-esima linha "chave=valor" da seccao);
    * seccao [Contrato] reservada (Contrato_ID/Produto_ID), fora da enumeracao;
    * linhas vazias e comentario-puro (';...' sem '=') sao PRESERVADAS verbatim
      (o SaveAll rele o ficheiro e so toca as linhas de parametro). --- }

function IniIsSection(const ALine: string): Boolean;
var L: string;
begin
  L := Trim(ALine);
  Result := (Length(L) >= 2) and (L[1] = '[') and (L[Length(L)] = ']');
end;

function IniSectionName(const ALine: string): string;
var L: string;
begin
  L := Trim(ALine);
  Result := Trim(Copy(L, 2, Length(L) - 2));
end;

{ linha de parametro: nao-vazia, nao seccao, nao comentario-puro, e tem '='. }
function IniIsParam(const ALine: string): Boolean;
var L: string;
begin
  L := Trim(ALine);
  if (L = '') or (L[1] = ';') or IniIsSection(L) then
    Exit(False);
  Result := Pos('=', L) > 0;
end;

function IniStripHash(const ALine: string; out AInactive: Boolean): string;
begin
  Result := Trim(ALine);
  AInactive := (Result <> '') and (Result[1] = '#');
  if AInactive then
    Result := Trim(Copy(Result, 2, MaxInt));
end;

function IniKeyOf(const ALine: string): string;
var L: string; P: Integer; LInact: Boolean;
begin
  L := IniStripHash(ALine, LInact);
  P := Pos(';', L);  if P > 0 then L := Trim(Copy(L, 1, P - 1));
  P := Pos('=', L);
  if P > 0 then Result := Trim(Copy(L, 1, P - 1)) else Result := Trim(L);
end;

function IniValueOf(const ALine: string): string;
var L: string; P: Integer; LInact: Boolean;
begin
  L := IniStripHash(ALine, LInact);
  P := Pos(';', L);  if P > 0 then L := Trim(Copy(L, 1, P - 1));
  P := Pos('=', L);
  if P > 0 then Result := Trim(Copy(L, P + 1, MaxInt)) else Result := '';
end;

function IniDescOf(const ALine: string): string;
var P: Integer;
begin
  P := Pos(';', ALine);
  if P > 0 then Result := Trim(Copy(ALine, P + 1, MaxInt)) else Result := '';
end;

function IniFormatParam(const AParam: TParameter): string;
begin
  if AParam.Ativo then Result := AParam.Name else Result := '#' + AParam.Name;
  Result := Result + '=' + AParam.Value;
  if Trim(AParam.Description) <> '' then
    Result := Result + ' ; ' + AParam.Description;
end;

{ indice da linha [ASection]; -1 se ausente. }
function IniFindSection(const ALines: TStringList; const ASection: string): Integer;
var I: Integer;
begin
  Result := -1;
  for I := 0 to ALines.Count - 1 do
    if IniIsSection(ALines[I]) and SameText(IniSectionName(ALines[I]), ASection) then
      Exit(I);
end;

{ indice da linha do parametro AKey na seccao que comeca em ASectionIdx; -1 se ausente. }
function IniFindKey(const ALines: TStringList; const ASectionIdx: Integer; const AKey: string): Integer;
var I: Integer;
begin
  Result := -1;
  if ASectionIdx < 0 then Exit;
  for I := ASectionIdx + 1 to ALines.Count - 1 do
  begin
    if IniIsSection(ALines[I]) then Exit;      { proxima seccao. }
    if IniIsParam(ALines[I]) and SameText(IniKeyOf(ALines[I]), AKey) then
      Exit(I);
  end;
end;

{ 1a linha APOS a ultima linha da seccao (proxima '[' ou Count). }
function IniSectionEnd(const ALines: TStringList; const ASectionIdx: Integer): Integer;
var I: Integer;
begin
  Result := ALines.Count;
  for I := ASectionIdx + 1 to ALines.Count - 1 do
    if IniIsSection(ALines[I]) then Exit(I);
end;

{ upsert de uma chave simples numa seccao (usado p/ [Contrato]). }
procedure IniSetSectionKey(const ALines: TStringList; const ASection, AKey, AValue: string);
var LSecIdx, LKeyIdx, LEnd: Integer;
begin
  LSecIdx := IniFindSection(ALines, ASection);
  if LSecIdx < 0 then
  begin
    if ALines.Count > 0 then ALines.Insert(0, '');
    ALines.Insert(0, '[' + ASection + ']');
    LSecIdx := 0;
  end;
  LKeyIdx := IniFindKey(ALines, LSecIdx, AKey);
  if LKeyIdx >= 0 then
    ALines[LKeyIdx] := AKey + '=' + AValue
  else
  begin
    LEnd := IniSectionEnd(ALines, LSecIdx);
    ALines.Insert(LEnd, AKey + '=' + AValue);
  end;
end;

{ True se a linha de parametro em AIdx (secao = ultima '[' antes; chave) consta da
  lista; a seccao [Contrato] devolve sempre True (nunca e removida). }
function IniParamInList(const ALines: TStringList; const AIdx: Integer; const AList: TParameterList): Boolean;
var J, K: Integer; LSec, LKey: string;
begin
  LSec := '';
  for J := AIdx downto 0 do
    if IniIsSection(ALines[J]) then begin LSec := IniSectionName(ALines[J]); Break; end;
  if SameText(LSec, SCOPE_SECTION) then Exit(True);
  LKey := IniKeyOf(ALines[AIdx]);
  Result := False;
  for K := 0 to AList.Count - 1 do
    if SameText(AList[K].Titulo, LSec) and SameText(AList[K].Name, LKey) then
      Exit(True);
end;

{ --- hooks --- }

function TParametersIniFile.GetSourceKind: TParameterSource;
begin
  Result := psInifiles;
end;

function TParametersIniFile.DefaultFileName: string;
begin
  Result := DEFAULT_CONFIG_INI_FILENAME;   // 'config.ini'
end;

function TParametersIniFile.LoadAll: TParameterList;
var
  LLines: TStringList;
  LPath, LSec: string;
  I, LOrder, LContrato, LProduto: Integer;
  LParam: TParameter;
  LInact: Boolean;
begin
  Result := TParameterList.Create;
  LPath := ResolveFilePath;
  if not FileExistsU(LPath) then
  begin
    { paridade v2.3.0: AutoCreateFile=False + ficheiro ausente -> erro na LEITURA
      tambem (nao so na escrita). Default True -> lista vazia (comportamento normal). }
    if not FAutoCreateFile then
      raise EParametersConfigurationException.Create(
        'Parameters.IniFile: ficheiro "' + LPath +
        '" nao existe e AutoCreateFile=False - nada a ler.', 0, 'LoadAll');
    Exit;
  end;
  LLines := TStringList.Create;
  try
    IniLoadResilient(LLines, LPath);
    { 1a passagem: escopo (seccao [Contrato]). }
    LContrato := FContratoID; LProduto := FProdutoID; LSec := '';
    for I := 0 to LLines.Count - 1 do
    begin
      if IniIsSection(LLines[I]) then begin LSec := IniSectionName(LLines[I]); Continue; end;
      if SameText(LSec, SCOPE_SECTION) and IniIsParam(LLines[I]) then
      begin
        if SameText(IniKeyOf(LLines[I]), 'Contrato_ID') then
          LContrato := StrToIntDef(IniValueOf(LLines[I]), LContrato)
        else if SameText(IniKeyOf(LLines[I]), 'Produto_ID') then
          LProduto := StrToIntDef(IniValueOf(LLines[I]), LProduto);
      end;
    end;
    { 2a passagem: parametros (chave/valor/ativo/descricao/ordem por-linha). }
    LSec := ''; LOrder := 0;
    for I := 0 to LLines.Count - 1 do
    begin
      if IniIsSection(LLines[I]) then begin LSec := IniSectionName(LLines[I]); LOrder := 0; Continue; end;
      if SameText(LSec, SCOPE_SECTION) then Continue;   { escopo, nao e titulo. }
      if not IniIsParam(LLines[I]) then Continue;       { vazia ou comentario-puro (preservados). }
      IniStripHash(LLines[I], LInact);
      Inc(LOrder);
      LParam := TParameter.Create;
      LParam.Titulo      := LSec;
      LParam.Name        := IniKeyOf(LLines[I]);
      LParam.Value       := IniValueOf(LLines[I]);
      LParam.Description := IniDescOf(LLines[I]);   { descricao = comentario ; da linha. }
      LParam.Ativo       := not LInact;             { '#' = inativo. }
      LParam.Ordem       := LOrder;                 { posicao fisica na seccao. }
      LParam.ContratoID  := LContrato;
      LParam.ProdutoID   := LProduto;
      Result.Add(LParam);
    end;
  finally
    LLines.Free;
  end;
end;

procedure TParametersIniFile.SaveAll(const AList: TParameterList);
var
  LLines: TStringList;
  LPath, LTitulo: string;
  I, LSecIdx, LKeyIdx: Integer;
begin
  LPath := ResolveFilePath;
  { AutoCreateFile (default True): False + ficheiro inexistente -> NAO cria (erro
    explicito). O utilizador que desliga o auto-create espera que o ficheiro ja
    exista; criar silenciosamente mascararia um path errado. }
  if (not FAutoCreateFile) and (not FileExistsU(LPath)) then
    raise EParametersConfigurationException.Create(
      'Parameters.IniFile: ficheiro "' + LPath +
      '" nao existe e AutoCreateFile=False - nada gravado.', 0, 'SaveAll');
  LLines := TStringList.Create;
  try
    { rele o ficheiro existente -> preserva comentarios, linhas vazias e estrutura
      (so as linhas de PARAMETRO sao tocadas: update-in-place / insert / remove). }
    if FileExistsU(LPath) then
      IniLoadResilient(LLines, LPath);
    { 1. escopo [Contrato]. }
    IniSetSectionKey(LLines, SCOPE_SECTION, 'Contrato_ID', IntToStr(FContratoID));
    IniSetSectionKey(LLines, SCOPE_SECTION, 'Produto_ID', IntToStr(FProdutoID));
    { 2. remove as linhas de parametro que ja nao constam da lista (comentarios/
      vazias/seccoes e a [Contrato] ficam intactos). }
    I := 0;
    while I < LLines.Count do
    begin
      if IniIsParam(LLines[I]) and (not IniParamInList(LLines, I, AList)) then
        LLines.Delete(I)
      else
        Inc(I);
    end;
    { 3. upsert de cada parametro: update-in-place (preserva posicao e comentarios)
      ou insert no fim da sua seccao (criando-a se preciso). ativo/descricao vao na
      linha via IniFormatParam. }
    for I := 0 to AList.Count - 1 do
    begin
      if FTitle <> '' then LTitulo := FTitle else LTitulo := AList[I].Titulo;
      if Trim(LTitulo) = '' then LTitulo := 'Default';
      LSecIdx := IniFindSection(LLines, LTitulo);
      if LSecIdx < 0 then
      begin
        if (LLines.Count > 0) and (Trim(LLines[LLines.Count - 1]) <> '') then
          LLines.Add('');
        LLines.Add('[' + LTitulo + ']');
        LSecIdx := LLines.Count - 1;
      end;
      LKeyIdx := IniFindKey(LLines, LSecIdx, AList[I].Name);
      if LKeyIdx >= 0 then
        LLines[LKeyIdx] := IniFormatParam(AList[I])                  { update-in-place. }
      else
        LLines.Insert(IniSectionEnd(LLines, LSecIdx), IniFormatParam(AList[I]));  { insert no fim da seccao. }
    end;
    ForceDirectories(ExtractFilePath(LPath));
    IniSaveResilient(LLines, LPath);
  finally
    LLines.Free;
  end;
end;

{ --- IParametersIniFile --- }

function TParametersIniFile.FilePath(const AValue: string): IParametersIniFile;
begin
  FFilePath := AValue;
  Result := Self;
end;

function TParametersIniFile.FilePath: string;
begin
  Result := ResolveFilePath;
end;

function TParametersIniFile.Section(const AValue: string): IParametersIniFile;
begin
  { no INI a seccao E o titulo -> alias de escopo. }
  FTitle := AValue;
  Result := Self;
end;

function TParametersIniFile.Section: string;
begin
  Result := FTitle;
end;

function TParametersIniFile.AutoCreateFile(const AValue: Boolean): IParametersIniFile;
begin
  FAutoCreateFile := AValue;
  Result := Self;
end;

function TParametersIniFile.AutoCreateFile: Boolean;
begin
  Result := FAutoCreateFile;
end;

function TParametersIniFile.FileExists: Boolean;
begin
  Result := FileExistsU(ResolveFilePath);
end;

{$IFDEF USE_DEPRECATED}
function TParametersIniFile.EndInifiles: IInterface;
begin
  Result := Self;   { navegacao fluente v2.3.0: devolve a propria fonte (sem "pai"). }
end;
{$ENDIF}

{$ENDIF USE_PARAMETERS}

end.
