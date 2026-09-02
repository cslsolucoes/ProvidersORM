
unit Commons.RegEx;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{ =============================================================================
  Commons.RegEx - Compatibilidade TRegEx para FPC (Commons)

  Unit exclusiva para FPC: replica o subconjunto de System.RegularExpressions.TRegEx
  (Delphi) realmente consumido no projecto — IsMatch e Replace (com/sem
  roIgnoreCase, com substituição $1/$2/...) — usando a unit `RegExpr` (TRegExpr,
  RTL do FPC, PCRE-like) como motor. Mesmo padrão de Commons.IOUtils (uses
  condicional: em FPC `Commons.RegEx`, em Delphi `System.RegularExpressions`;
  os call-sites `TRegEx.IsMatch(...)`/`TRegEx.Replace(...)`/`[roIgnoreCase]`
  ficam IDÊNTICOS nos dois ramos).

  Verificado (03/08/2026, F9 Onda 9.2): os padrões reais consumidos por
  `Printers.ReportBuilder.AutoBind`/`Printers.ReportBuilder.Sql.Dialect`
  (âncoras ^/$, \w, \d, \s, \b, alternação, grupos de captura, roIgnoreCase,
  substituição $1..$3) foram testados num repro isolado fora de src/ contra
  TRegExpr e produziram o MESMO resultado do TRegEx do Delphi.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.0.0 (03/08/2026): criado na F9 Onda 9.2 — desbloqueia D.7 (uses
    Delphi-only sem ramo FPC) em `Printers.ReportBuilder.AutoBind.pas` e
    `Printers.ReportBuilder.Sql.Dialect.pas`, os únicos 2 consumidores de
    TRegEx no projecto (grep confirmado antes de criar — regra transversal
    #14, sem SSOT equivalente já existente).
  ============================================================================= }

interface

{$IFDEF FPC}
uses
  RegExpr;

type
  TRegExOptions = set of (roIgnoreCase);

  { Subconjunto de System.RegularExpressions.TRegEx realmente usado no projecto. }
  TRegEx = record
  public
    class function IsMatch(const AInput, APattern: string): Boolean; static;
    class function Replace(const AInput, APattern, AReplacement: string): string; overload; static;
    class function Replace(const AInput, APattern, AReplacement: string;
      AOptions: TRegExOptions): string; overload; static;
  end;
{$ENDIF}

implementation

{$IFDEF FPC}

class function TRegEx.IsMatch(const AInput, APattern: string): Boolean;
var
  LRE: TRegExpr;
begin
  LRE := TRegExpr.Create(APattern);
  try
    Result := LRE.Exec(AInput);
  finally
    LRE.Free;
  end;
end;

class function TRegEx.Replace(const AInput, APattern, AReplacement: string): string;
begin
  Result := TRegEx.Replace(AInput, APattern, AReplacement, []);
end;

class function TRegEx.Replace(const AInput, APattern, AReplacement: string;
  AOptions: TRegExOptions): string;
var
  LRE: TRegExpr;
begin
  LRE := TRegExpr.Create(APattern);
  try
    LRE.ModifierI := roIgnoreCase in AOptions;
    Result := LRE.Replace(AInput, AReplacement, True);
  finally
    LRE.Free;
  end;
end;

{$ENDIF}

end.
