{ =============================================================================
  Exceptions.Printers - Exceções do módulo acessório Printers (relatórios)

  Descrição:
  Hierarquia de exceções do módulo umbrella Printers e dos seus motores de
  relatório (ReportBuilder, FastReport, QuickReport). Segue o mesmo padrão de
  Exceptions.Loggers (classe base com ErrorCode/Operation + categorias).

  Faixa de códigos canónicos (a registar em exception.db/exception.sql): 960XXX.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.1.0 (03/08/2026): + EFortesReportProvidersException (motor FortesReport CE,
    4.º motor absorvido na F9 Onda 9.0 — espelha a SSOT E:\Dropbox\CSL\ProvidersORM,
    que já a tinha desde a introdução do motor em 16/07/2026). Aditivo, autorizado
    pelo owner (ficheiro entregue pela F2 já concluída).
  - 1.0.0 (28/06/2026): Versão inicial — EPrintersException (base) + categorias
    (Configuration/Template/DataSource/Render/Export) + exceções por motor
    (EReportBuilder/EFastReport/EQuickReportProvidersException); faixa de códigos 960XXX.
  ============================================================================= }

unit Exceptions.Printers;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../ORM.Defines.inc}

uses
{$IF DEFINED(FPC)}
  SysUtils,
{$ELSE}
  System.SysUtils,
{$ENDIF}
  Exceptions.Base;

type
  { =============================================================================
    EPrintersException - Exceção base do módulo Printers
    ============================================================================= }
  EPrintersException = class(EExceptionBase)
  private
    FOperation: string;
  public
    constructor Create(const AMessage: string; const AErrorCode: Integer = 0;
      const AOperation: string = ''); reintroduce;
    property Operation: string read FOperation;   // ErrorCode vem de EExceptionBase (de-dup 05/07)
  end;

  { =============================================================================
    Categorias
    ============================================================================= }
  EPrintersConfigurationException = class(EPrintersException);
  EPrintersTemplateException      = class(EPrintersException);
  EPrintersDataSourceException    = class(EPrintersException);
  EPrintersRenderException        = class(EPrintersException);
  EPrintersExportException        = class(EPrintersException);

  { Exceção específica do motor ReportBuilder. }
  EReportBuilderProvidersException = class(EPrintersException);

  { Exceção específica do motor FastReport. }
  EFastReportProvidersException = class(EPrintersException);

  { Exceção específica do motor QuickReport. }
  EQuickReportProvidersException = class(EPrintersException);

  { Exceção específica do motor FortesReport CE (RLReport). }
  EFortesReportProvidersException = class(EPrintersException);

const
  { =============================================================================
    CÓDIGOS DE ERRO — Printers (faixa canónica 960XXX)
    ============================================================================= }
  // ----- Configuração (960001-960019) -----
  ERR_PRINTERS_CONNECTION_NOT_ASSIGNED = 960001;
  ERR_PRINTERS_ENGINE_NOT_ENABLED      = 960002;

  // ----- Template (960101-960119) -----
  ERR_PRINTERS_TEMPLATE_NOT_INFORMED   = 960101;
  ERR_PRINTERS_TEMPLATE_NOT_FOUND      = 960102;
  ERR_PRINTERS_TEMPLATE_LOAD_FAILED    = 960103;

  // ----- Fonte de dados (960201-960219) -----
  ERR_PRINTERS_DATASOURCE_EMPTY        = 960201;
  ERR_PRINTERS_QUERY_EXECUTE_FAILED    = 960202;

  // ----- Render (960301-960319) -----
  ERR_PRINTERS_RENDER_FAILED           = 960301;

  // ----- Export (960401-960419) -----
  ERR_PRINTERS_EXPORT_FAILED           = 960401;
  ERR_PRINTERS_EXPORT_FILE_NOT_INFORMED = 960402;

implementation

{ EPrintersException }

constructor EPrintersException.Create(const AMessage: string;
  const AErrorCode: Integer; const AOperation: string);
begin
  inherited Create(AMessage, AErrorCode);
  FOperation := AOperation;
end;

end.
