{ =============================================================================
  Commons.Printers.Types - Tipos de dados do modulo Printers (relatorios)

  Tipos neutros (sem dependencia de motor pp*/frx*/QR*) da API publica do modulo
  Printers. Colocados no nucleo Commons por serem DADOS (regra §3-C: dados de um
  modulo ficam em Commons.<Modulo>.* quando sao exclusivos do dominio; so o que
  e cross-modulo sobe ao Commons.Types generico). TReportOutput e exclusivo do
  dominio de relatorios -> Commons.Printers.Types.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           05/07/2026

  Changelog (file):
  - 1.0.0 (05/07/2026): v3 F1 Onda 1.4 - extraido de Modulos/Printers/Commons/
    Printers.Types (ref v2.2.0) para o nucleo, renomeado Commons.Printers.Types
    conforme §3-C. Conteudo preservado (TReportOutput).
  ============================================================================= }
unit Commons.Printers.Types;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

type
  { Destino de saida de um relatorio (terminal generico da API Printers). }
  TReportOutput = (roPreview, roPrinter, roPDF, roFile);

implementation

end.
