{ =============================================================================
  Printers.ReportBuilder.Sql.Dialect - Tradutor de SQL Access/Jet -> dialeto alvo

  Descrição:
  Converte o SQL embutido (dialeto Microsoft Access/Jet) dos .rtm legados para o
  dialeto do engine activo do ProvidersORM. Cobre os construtos medidos no acervo:
  guard de AutoSearch ('c'<>'c') AND, strings "..." -> '...', concat & ,
  iif/CInt/CDbl, datas #...#, booleanos <> TRUE/FALSE.

  SQL Server é o alvo validado; os demais dialetos são best-effort (rever casos
  de Format()/datas/subqueries — ver §R1 do GAP). NÃO traduz se ATarget = dtAccess.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.1.0 (03/08/2026): absorvido de ProvidersORM v2.3.0 para
    `src/Modulos/Printers/ReportBuilder/` (Onda 9.2). Zero alteração de
    lógica — resolvido D.7: `uses` ganhou um ramo condicional dedicado a FPC usando
    `Commons.RegEx` (novo, F9 Onda 9.2) em vez de `System.RegularExpressions`;
    call-sites (`TRegEx.Replace`, `[roIgnoreCase]`) idênticos nos 2 ramos —
    as 12 chamadas `TRegEx.Replace` deste ficheiro (incl. `$1`/`$2`/`$3` e
    `roIgnoreCase`) foram verificadas num repro isolado fora de src/ contra
    `TRegExpr`, mesmo resultado do `TRegEx` do Delphi (ver header de
    `Commons.RegEx.pas`). D.6 (overlap com `IDialect` do Database) já tinha
    sido resolvido na Onda 9.1 (sem alteração — fica local ao adapter RB).
  Changelog (fonte v2.3.0):
  - 1.0.0 (28/06/2026): Versão inicial — regras base (SQL Server primário).
  ============================================================================= }

unit Printers.ReportBuilder.Sql.Dialect;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../../ORM.Defines.inc}

{$IFDEF USE_REPORTBUILDER}

uses
  Commons.Types;  // TDatabaseTypes

type
  TDialect = class
  public
    { Traduz SQL Access/Jet para o dialeto alvo. Idempotente para SQL já compatível. }
    class function FromAccess(const ASQL: string; const ATarget: TDatabaseTypes): string;
  end;

{$ENDIF}

implementation

{$IFDEF USE_REPORTBUILDER}

uses
{$IF DEFINED(FPC)}
  SysUtils, Commons.RegEx, StrUtils;
{$ELSE}
  System.SysUtils, System.RegularExpressions, System.StrUtils;
{$ENDIF}

class function TDialect.FromAccess(const ASQL: string; const ATarget: TDatabaseTypes): string;
var
  s: string;
begin
  s := ASQL;
  if ATarget = dtAccess then
    Exit(s);

  // 1. Remover o guard de AutoSearch:  ( 'c' <> 'c' ) AND
  s := TRegEx.Replace(s, '\(\s*''c''\s*<>\s*''c''\s*\)\s*AND', ' ', [roIgnoreCase]);

  // 2. Strings Access "texto" -> 'texto'  (em SQL padrão " é identificador)
  s := TRegEx.Replace(s, '"([^"]*)"', '''$1''');

  // 3. Datas  #2014-01-01 00.00.00#  ->  '2014-01-01 00:00:00'
  //    (datas usam '-'; só a hora usa '.', logo é seguro converter . -> : antes de trocar # por ')
  s := TRegEx.Replace(s, '(\d{2})\.(\d{2})\.(\d{2})', '$1:$2:$3');
  s := TRegEx.Replace(s, '#([^#]+)#', '''$1''');

  // 4. Conversões de tipo Access
  s := TRegEx.Replace(s, '\bCInt\s*\(([^()]*)\)',  'CAST($1 AS INT)',   [roIgnoreCase]);
  s := TRegEx.Replace(s, '\bCDbl\s*\(([^()]*)\)',  'CAST($1 AS FLOAT)', [roIgnoreCase]);
  s := TRegEx.Replace(s, '\bCStr\s*\(([^()]*)\)',  'CAST($1 AS VARCHAR(255))', [roIgnoreCase]);

  // 5. Concat & e booleanos, por dialeto
  case ATarget of
    dtSQLServer:
      begin
        s := StringReplace(s, '&', '+', [rfReplaceAll]);          // concat
        s := TRegEx.Replace(s, '<>\s*TRUE',  '<> 1', [roIgnoreCase]);
        s := TRegEx.Replace(s, '=\s*TRUE',   '= 1',  [roIgnoreCase]);
        s := TRegEx.Replace(s, '<>\s*FALSE', '<> 0', [roIgnoreCase]);
        s := TRegEx.Replace(s, '=\s*FALSE',  '= 0',  [roIgnoreCase]);
        // iif() é nativo no SQL Server (>=2012) — mantém.
      end;
    dtMySQL:
      begin
        // MariaDB/MySQL: precisa PIPES_AS_CONCAT para '||'; usa-se IF em vez de iif.
        s := StringReplace(s, '&', '||', [rfReplaceAll]);
        s := TRegEx.Replace(s, '\biif\s*\(', 'IF(', [roIgnoreCase]);
        s := TRegEx.Replace(s, '<>\s*TRUE',  '<> 1', [roIgnoreCase]);
        s := TRegEx.Replace(s, '<>\s*FALSE', '<> 0', [roIgnoreCase]);
      end;
    dtPostgreSQL, dtFireBird, dtSQLite:
      begin
        s := StringReplace(s, '&', '||', [rfReplaceAll]);
        if ATarget = dtPostgreSQL then
        begin
          s := TRegEx.Replace(s, '<>\s*TRUE',  '<> TRUE',  [roIgnoreCase]);
          // iif -> CASE em PG é caso-a-caso; deixar marcado (best-effort: mantém iif e revê)
        end
        else
        begin
          s := TRegEx.Replace(s, '<>\s*TRUE',  '<> 1', [roIgnoreCase]);
          s := TRegEx.Replace(s, '<>\s*FALSE', '<> 0', [roIgnoreCase]);
        end;
      end;
  end;

  Result := s;
end;

{$ENDIF}

end.
