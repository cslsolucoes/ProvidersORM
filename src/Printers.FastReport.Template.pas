{ =============================================================================
  Printers.FastReport.Template - Carregamento de template .fr3 em runtime

  Descrição:
  Carrega um template FastReport (.fr3) num TfrxReport em runtime, sem alterar o
  layout (binding por nome preservado). Suporta ficheiro e stream.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.1.0 (03/08/2026): absorvido de ProvidersORM v2.3.0 para
    `src/Modulos/Printers/FastReport/` (Onda 9.2). Zero alteração de código
    (`uses` já não tinha nenhuma referência v2.3.0-specific — só `frxClass` +
    `Exceptions.Printers`, ambos já correctos) — só cabeçalho v3.
  Changelog (fonte v2.3.0):
  - 1.0.0 (28/06/2026): Versão inicial — TFastReportTemplate.LoadFromFile/LoadFromStream.
  ============================================================================= }

unit Printers.FastReport.Template;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../../ORM.Defines.inc}

{$IFDEF USE_FASTREPORT}

uses
{$IF DEFINED(FPC)}
  Classes, SysUtils,
{$ELSE}
  System.Classes, System.SysUtils,
{$ENDIF}
  frxClass;

type
  { Carregador de template .fr3 para um TfrxReport existente. }
  TFastReportTemplate = class
  public
    class procedure LoadFromFile(const AReport: TfrxReport; const AFileName: string);
    class procedure LoadFromStream(const AReport: TfrxReport; const AStream: TStream);
  end;

{$ENDIF}

implementation

{$IFDEF USE_FASTREPORT}

uses
  Exceptions.Printers;

{ TFastReportTemplate }

class procedure TFastReportTemplate.LoadFromFile(const AReport: TfrxReport;
  const AFileName: string);
begin
  if AReport = nil then
    raise EPrintersTemplateException.Create('TfrxReport não informado.',
      ERR_PRINTERS_TEMPLATE_NOT_INFORMED, 'TFastReportTemplate.LoadFromFile');

  if AFileName = '' then
    raise EPrintersTemplateException.Create('Caminho do template (.fr3) não informado.',
      ERR_PRINTERS_TEMPLATE_NOT_INFORMED, 'TFastReportTemplate.LoadFromFile');

  if not FileExists(AFileName) then
    raise EPrintersTemplateException.Create('Template .fr3 não encontrado: ' + AFileName,
      ERR_PRINTERS_TEMPLATE_NOT_FOUND, 'TFastReportTemplate.LoadFromFile');

  try
    if not AReport.LoadFromFile(AFileName, True) then
      raise EPrintersTemplateException.Create('FastReport recusou o template: ' + AFileName,
        ERR_PRINTERS_TEMPLATE_LOAD_FAILED, 'TFastReportTemplate.LoadFromFile');
  except
    on E: EPrintersException do
      raise;
    on E: Exception do
      raise EPrintersTemplateException.Create('Falha ao carregar template: ' + E.Message,
        ERR_PRINTERS_TEMPLATE_LOAD_FAILED, 'TFastReportTemplate.LoadFromFile');
  end;
end;

class procedure TFastReportTemplate.LoadFromStream(const AReport: TfrxReport;
  const AStream: TStream);
begin
  if AReport = nil then
    raise EPrintersTemplateException.Create('TfrxReport não informado.',
      ERR_PRINTERS_TEMPLATE_NOT_INFORMED, 'TFastReportTemplate.LoadFromStream');

  if AStream = nil then
    raise EPrintersTemplateException.Create('Stream do template não informado.',
      ERR_PRINTERS_TEMPLATE_NOT_INFORMED, 'TFastReportTemplate.LoadFromStream');

  try
    AReport.LoadFromStream(AStream);   // procedure (sem retorno) no FastReport
  except
    on E: EPrintersException do
      raise;
    on E: Exception do
      raise EPrintersTemplateException.Create('Falha ao carregar template (stream): ' + E.Message,
        ERR_PRINTERS_TEMPLATE_LOAD_FAILED, 'TFastReportTemplate.LoadFromStream');
  end;
end;

{$ENDIF}

end.
