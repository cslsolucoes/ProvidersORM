{ =============================================================================
  Printers.ReportBuilder.AutoBind - Introspeção e limpeza de .rtm legado

  Descrição:
  Lê um template .rtm legado do Hábil/ReportBuilder e:
   - extrai cada par (pipeline, SQL) dos blocos TdaSQL (descodificando as strings
     DFM, incl. escapes #NNN e continuações '+');
   - produz um template "limpo" (sem o DataView ADO/daDataModule, sem módulos RAP
     TraCodeModule, sem TppParameterList, sem rodapé Hábil pós-DFM, sem refs de
     pipeline dangling e sem handlers de evento BeforePrint/OnPreviewFormCreate).

  O resultado alimenta o TReportProvider.AutoBind: o layout (bandas/labels) é
  preservado e religado por nome ao pipeline do ProvidersORM.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.1.0 (03/08/2026): absorvido de ProvidersORM v2.3.0 para
    `src/Modulos/Printers/ReportBuilder/` (Onda 9.2). Zero alteração de
    lógica — resolvido D.7 (uses Delphi-only sem ramo FPC): `uses` ganhou
    um ramo condicional dedicado a FPC usando `Commons.RegEx` (novo, F9 Onda 9.2 — shim
    `TRegEx`/`TRegExOptions` sobre `RegExpr`/`TRegExpr` do FPC) em vez de
    `System.RegularExpressions`; os call-sites (`TRegEx.IsMatch`) ficam
    IDÊNTICOS nos dois ramos, nada tocado no corpo do parser.
  Changelog (fonte v2.3.0):
  - 1.0.0 (28/06/2026): Versão inicial — DFM decode + extração + limpeza.
  ============================================================================= }

unit Printers.ReportBuilder.AutoBind;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../../ORM.Defines.inc}

{$IFDEF USE_REPORTBUILDER}

uses
{$IF DEFINED(FPC)}
  SysUtils, Classes;
{$ELSE}
  System.SysUtils, System.Classes;
{$ENDIF}

type
  TReportDataSpec = record
    Pipeline: string;
    Sql: string;
  end;
  TReportDataSpecs = array of TReportDataSpec;

  TReportAutoBind = class
  public
    { Lê AFileName, devolve o template limpo (ACleanedDfm) e os pares pipeline/SQL. }
    class procedure Parse(const AFileName: string; out ACleanedDfm: string;
      out ASpecs: TReportDataSpecs);
  end;

{$ENDIF}

implementation

{$IFDEF USE_REPORTBUILDER}

uses
{$IF DEFINED(FPC)}
  StrUtils, Commons.RegEx;
{$ELSE}
  System.StrUtils, System.RegularExpressions;
{$ENDIF}

{ Descodifica uma linha DFM (tokens '...' e #NNN/#$HHHH); AContinues = termina com '+' }
function DecodeDfmLine(const ALine: string; out AContinues: Boolean): string;
var
  s: string;
  i, n, code: Integer;
const
  HEX = '0123456789ABCDEF';
begin
  Result := '';
  s := TrimRight(ALine);
  AContinues := EndsStr('+', s);
  n := Length(s);
  i := 1;
  while i <= n do
  begin
    case s[i] of
      '''':
        begin
          Inc(i);
          while i <= n do
          begin
            if s[i] = '''' then
            begin
              if (i < n) and (s[i + 1] = '''') then begin Result := Result + ''''; Inc(i, 2); end
              else begin Inc(i); Break; end;
            end
            else begin Result := Result + s[i]; Inc(i); end;
          end;
        end;
      '#':
        begin
          Inc(i);
          if (i <= n) and (s[i] = '$') then
          begin
            Inc(i); code := 0;
            while (i <= n) and (Pos(UpCase(s[i]), HEX) > 0) do
            begin code := code * 16 + (Pos(UpCase(s[i]), HEX) - 1); Inc(i); end;
          end
          else
          begin
            code := 0;
            while (i <= n) and (s[i] >= '0') and (s[i] <= '9') do
            begin code := code * 10 + (Ord(s[i]) - Ord('0')); Inc(i); end;
          end;
          if code > 0 then Result := Result + Char(code);
        end;
    else
      Inc(i); // espaços, '+', etc.
    end;
  end;
end;

{ Junta as linhas de um SQLText.Strings = ( ... ) num SQL único }
function DecodeStringList(ALines: TStringList): string;
var
  i: Integer;
  val: string;
  cont, prevCont: Boolean;
begin
  Result := '';
  prevCont := False;
  for i := 0 to ALines.Count - 1 do
  begin
    val := DecodeDfmLine(ALines[i], cont);
    if i = 0 then
      Result := val
    else if prevCont then
      Result := Result + val            // continuação: sem separador
    else
      Result := Result + ' ' + val;     // novo elemento: separador
    prevCont := cont;
  end;
end;

class procedure TReportAutoBind.Parse(const AFileName: string; out ACleanedDfm: string;
  out ASpecs: TReportDataSpecs);
var
  LSrc, LOut: TStringList;
  i: Integer;
  line, trimmed: string;
  skipIndent: Integer;         // -1 = não está a saltar bloco
  curPipe: string;
  inSql: Boolean;
  sqlLines: TStringList;
  doneTop: Boolean;
  skipPropCont: Boolean;       // a saltar valor multilinha de uma propriedade

  function IndentOf(const AL: string): Integer;
  var k: Integer;
  begin
    k := 0;
    while (k < Length(AL)) and (AL[k + 1] = ' ') do Inc(k);
    Result := k;
  end;

  procedure AddSpec(const APipe, ASql: string);
  begin
    if (Trim(APipe) = '') or (Trim(ASql) = '') then Exit;
    SetLength(ASpecs, Length(ASpecs) + 1);
    ASpecs[High(ASpecs)].Pipeline := APipe;
    ASpecs[High(ASpecs)].Sql := ASql;
  end;

begin
  ACleanedDfm := '';
  SetLength(ASpecs, 0);
  LSrc := TStringList.Create;
  LOut := TStringList.Create;
  sqlLines := TStringList.Create;
  try
    LSrc.LoadFromFile(AFileName);
    skipIndent := -1;
    curPipe := '';
    inSql := False;
    doneTop := False;
    skipPropCont := False;

    for i := 0 to LSrc.Count - 1 do
    begin
      line := LSrc[i];
      trimmed := Trim(line);

      // ---- extração de SQL/pipeline (sobre o texto original) ----
      if inSql then
      begin
        // O ')' que fecha SQLText.Strings = (...) pode vir:
        //  - sozinho numa linha:  )            -> trimmed = ')'
        //  - colado à última string: '...TRUE )')  -> linha termina em ')'
        if trimmed = ')' then
        begin
          AddSpec(curPipe, DecodeStringList(sqlLines));
          sqlLines.Clear; inSql := False; curPipe := '';
        end
        else if EndsStr(')', TrimRight(line)) then
        begin
          sqlLines.Add(line);   // DecodeDfmLine ignora o ')' final (fora de aspas)
          AddSpec(curPipe, DecodeStringList(sqlLines));
          sqlLines.Clear; inSql := False; curPipe := '';
        end
        else
          sqlLines.Add(line);
      end
      else
      begin
        if StartsStr('DataPipelineName = ', trimmed) then
          curPipe := AnsiDequotedStr(Trim(Copy(trimmed, Length('DataPipelineName = ') + 1, MaxInt)), '''');
        if TRegEx.IsMatch(trimmed, '^SQLText\.Strings\s*=\s*\(') then
        begin
          inSql := True; sqlLines.Clear;
          // caso a 1ª string venha na mesma linha do "("
        end;
      end;

      // ---- construção do template limpo ----
      if doneTop then Continue;                         // descarta rodapé Hábil
      if skipPropCont then                              // a saltar valor multilinha
      begin
        if not EndsStr('+', TrimRight(line)) then skipPropCont := False;
        Continue;
      end;
      if skipIndent >= 0 then
      begin
        if (IndentOf(line) = skipIndent) and (trimmed = 'end') then skipIndent := -1;
        Continue;
      end;
      // inicia salto de blocos a remover (qualquer indentação)
      if TRegEx.IsMatch(trimmed, '^object \w+: (TdaDataModule|TraCodeModule|TppParameterList)\b') then
      begin
        skipIndent := IndentOf(line);
        Continue;
      end;
      // refs de pipeline dangling + handlers do app
      if StartsStr('DataPipeline = daADOQueryDataView', trimmed) then Continue;
      if StartsStr('BeforePrint = ', trimmed) or StartsStr('OnPreviewFormCreate = ', trimmed) then Continue;
      // propriedades problemáticas em headless (reload de template / diálogos / forms)
      if StartsStr('Template.FileName', trimmed)
        or StartsStr('ShowAutoSearchDialog', trimmed)
        or StartsStr('ArchiveFileName', trimmed)
        or StartsStr('DefaultFileDeviceType', trimmed)
        or StartsStr('ThumbnailSettings.', trimmed)
        or StartsStr('PreviewFormSettings.', trimmed) then
      begin
        if EndsStr('=', TrimRight(line)) or EndsStr('+', TrimRight(line)) then
          skipPropCont := True;                          // valor continua nas linhas seguintes
        Continue;
      end;

      LOut.Add(line);
      if line = 'end' then doneTop := True;             // fecha o objeto Relatorio (col 0)
    end;

    ACleanedDfm := LOut.Text;
  finally
    sqlLines.Free;
    LOut.Free;
    LSrc.Free;
  end;
end;

{$ENDIF}

end.
