{ =============================================================================
  Database.Helpers.JSON - Escaper RFC 8259 unico do modulo Database

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.0.0
  FileVersion:    1.1.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           30/07/2026

  Onda C5 (M7, conformidade F5, regra #14 anti-duplicacao) - SSOT unico do
  escaper de string JSON (RFC 8259) usado por TODA a serializacao ToJSON/
  StructureToJSON do modulo Database. Antes desta onda existiam 8 copias
  byte-a-byte do MESMO algoritmo, uma por unit (Database.pas.
  DatabaseJSONQuoteString, Databases.pas.DatabasesJSONQuoteString,
  Database.CatalogReader.pas.MetadataJSONQuoteString, Database.Table.pas.
  TableJSONQuoteString, Database.Schemas.pas.SchemasJSONQuoteString,
  Database.QueryBuilder.pas.QBJSONQuoteString, Database.Schema.pas.
  SchemaJSONQuoteString, Database.Field.pas.JSONQuoteString) - todas privadas
  (so na implementation, nunca exportadas na interface, confirmado por grep
  antes de consolidar - zero consumidor externo perdido). Correcao de escaping
  (ex.: surrogate pairs) exigia 8 edicoes sincronizadas antes desta onda;
  agora exige so 1.

  NUNCA QuotedStr para JSON (aspas simples Pascal, nao e sintaxe JSON -
  bug-293, motivo original da introducao do escaper em cada unit).

  Placement (regra do projecto - lógica/algoritmo -> Modulos/<Modulo>/*):
  logica pura de escaping, usada so DENTRO do modulo Database (nenhum outro
  modulo tem esta necessidade - confirmado por grep no projecto inteiro
  antes de criar esta peca) - fica em Modulos/Database/, nao em Commons
  (Commons e' para dado/consts, nao para algoritmo).

  Sem gate USE_DATABASE: pura funcao de string, sem dependencia de
  IConnection/Databases.Interfaces/etc. - consumida tanto por units gated
  como (potencialmente) ungated do modulo.

  Changelog (file):
  - 1.1.0 (30/07/2026): Onda S4 (ADITIVO, eixo FULL - Metadata+Data num so
    JSON) - novo helper JSONExtractMember(AJSON, AKey): string, SSOT unico
    para decompor o eixo FULL nos 8 niveis (Field/Fields/Table/Tables/Schema/
    Schemas/Database/Databases): localiza AKey (case-sensitive, mesmo
    criterio das chaves ja emitidas por este modulo, ex.: "structure"/"data")
    num objecto JSON de topo e devolve o TEXTO JSON bruto desse membro
    (objecto OU array, reserializado via AsJSON no FPC / ToJSON no Delphi -
    MESMA tecnica ja usada por Databases.pas/Database.Schema.pas/Database.
    Tables.pas para reencaminhar um TJSONData/TJSONValue ja parseado a um
    FromJSON/StructureFromJSON de nivel inferior, regra #14 - nao duplica o
    parser). Tolerante por definicao: devolve '' se AJSON estiver vazio/
    invalido, nao for um objecto de topo, ou AKey nao existir - o caller
    (FromFullJSON/MergeFullFromJSON de cada nivel) decide o que fazer com ''
    (nao aplica esse eixo, mantendo o comportamento actual do objecto). Novo
    uses (implementation): fpjson+jsonparser (FPC) / System.JSON (Delphi) -
    a interface publica desta unit continua so-string (sem gate USE_DATABASE,
    inalterado).
  - 1.0.0 (27/07/2026): versao inicial (Onda C5, M7) - JSONQuoteString unico,
    substitui as 8 copias locais.
  ============================================================================= }
unit Database.Helpers.JSON;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}
interface

function JSONQuoteString(const AValue: string): string;
{ Onda S4 - ver comentario completo no header do ficheiro (changelog 1.1.0). }
function JSONExtractMember(const AJSON, AKey: string): string;

implementation

uses
{$IF DEFINED(FPC)}
  SysUtils, fpjson, jsonparser
{$ELSE}
  System.SysUtils, System.JSON
{$ENDIF}
  ;

{ Escapa e cerca uma string com aspas duplas, produzindo um literal JSON valido
  (RFC 8259) - substitui o uso indevido de QuotedStr (aspas simples Pascal, nao
  e sintaxe JSON) no ToJSON hibrido anterior (bug-293). }
function JSONQuoteString(const AValue: string): string;
var
  I: Integer;
  LChar: Char;
begin
  Result := '"';
  for I := 1 to Length(AValue) do
  begin
    LChar := AValue[I];
    case LChar of
      '"': Result := Result + '\"';
      '\': Result := Result + '\\';
      #8:  Result := Result + '\b';
      #9:  Result := Result + '\t';
      #10: Result := Result + '\n';
      #12: Result := Result + '\f';
      #13: Result := Result + '\r';
    else
      if LChar < #32 then
        Result := Result + '\u' + IntToHex(Ord(LChar), 4)
      else
        Result := Result + LChar;
    end;
  end;
  Result := Result + '"';
end;

{ Onda S4 - ver comentario completo no header do ficheiro (changelog 1.1.0).
  Implementacao duplicada por compilador (fpjson vs System.JSON), MESMO
  padrao ja usado por todo o resto do modulo (ex.: TablesFindNode em
  Database.Tables.pas) - so o parser/AST difere; a semantica e identica nos
  2 ramos. }
{$IF DEFINED(FPC)}
function JSONExtractMember(const AJSON, AKey: string): string;
var
  LData: TJSONData;
  LObj: TJSONObject;
  LMember: TJSONData;
begin
  Result := '';
  if Trim(AJSON) = '' then
    Exit;
  LData := GetJSON(AJSON);
  if (not Assigned(LData)) or (not (LData is TJSONObject)) then
  begin
    if Assigned(LData) then
      LData.Free;
    Exit;
  end;
  LObj := TJSONObject(LData);
  try
    LMember := LObj.Find(AKey);
    if Assigned(LMember) then
      Result := LMember.AsJSON;
  finally
    LObj.Free;
  end;
end;
{$ELSE}
function JSONExtractMember(const AJSON, AKey: string): string;
var
  LVal: TJSONValue;
  LObj: TJSONObject;
  LMember: TJSONValue;
begin
  Result := '';
  if Trim(AJSON) = '' then
    Exit;
  LVal := TJSONObject.ParseJSONValue(AJSON);
  if (not Assigned(LVal)) or (not (LVal is TJSONObject)) then
  begin
    if Assigned(LVal) then
      LVal.Free;
    Exit;
  end;
  LObj := TJSONObject(LVal);
  try
    LMember := LObj.GetValue(AKey);
    if Assigned(LMember) then
      Result := LMember.ToJSON;
  finally
    LObj.Free;
  end;
end;
{$ENDIF}

end.
