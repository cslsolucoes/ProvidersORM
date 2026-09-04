{ =============================================================================
  Printers.ReportBuilder.Template - Carregamento de template .rtm em runtime

  Descrição:
  Carrega um template ReportBuilder (.rtm) num TppReport em runtime, sem alterar
  o layout (binding por nome preservado). Suporta ficheiro e stream.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.1.0 (03/08/2026): absorvido de ProvidersORM v2.3.0 para
    `src/Modulos/Printers/ReportBuilder/` (Onda 9.2). Zero alteração de
    código (`uses` já não tinha nenhuma referência v2.3.0-specific) — só
    cabeçalho v3. Nota preservada (não corrigida, fora do âmbito): o `except`
    de `LoadFromFile` não re-lança `EPrintersException` intacta antes do
    wrap genérico, ao contrário do homólogo FastReport — inconsistência
    menor, comportamento absorvido tal como está.
  Changelog (fonte v2.3.0):
  - 1.0.0 (28/06/2026): Versão inicial — TReportTemplate.LoadFromFile/LoadFromStream.
  ============================================================================= }

unit Printers.ReportBuilder.Template;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_REPORTBUILDER}

uses
{$IF DEFINED(FPC)}
  Classes, SysUtils,
{$ELSE}
  System.Classes, System.SysUtils,
{$ENDIF}
  ppReport, ppTmplat;

type
  { Carregador de template .rtm para um TppReport existente. }
  TReportTemplate = class
  public
    class procedure LoadFromFile(const AReport: TppReport; const AFileName: string);
    class procedure LoadFromStream(const AReport: TppReport; const AStream: TStream);
  end;

{$ENDIF}

implementation

{$IFDEF USE_REPORTBUILDER}

uses
  Exceptions.Printers;

{ TReportTemplate }

class procedure TReportTemplate.LoadFromFile(const AReport: TppReport;
  const AFileName: string);
begin
  if AReport = nil then
    raise EPrintersTemplateException.Create('TppReport não informado.',
      ERR_PRINTERS_TEMPLATE_NOT_INFORMED, 'TReportTemplate.LoadFromFile');

  if AFileName = '' then
    raise EPrintersTemplateException.Create('Caminho do template (.rtm) não informado.',
      ERR_PRINTERS_TEMPLATE_NOT_INFORMED, 'TReportTemplate.LoadFromFile');

  if not FileExists(AFileName) then
    raise EPrintersTemplateException.Create('Template .rtm não encontrado: ' + AFileName,
      ERR_PRINTERS_TEMPLATE_NOT_FOUND, 'TReportTemplate.LoadFromFile');

  try
    AReport.Template.FileName := AFileName;
    AReport.Template.LoadFromFile;
  except
    on E: Exception do
      raise EPrintersTemplateException.Create('Falha ao carregar template: ' + E.Message,
        ERR_PRINTERS_TEMPLATE_LOAD_FAILED, 'TReportTemplate.LoadFromFile');
  end;
end;

class procedure TReportTemplate.LoadFromStream(const AReport: TppReport;
  const AStream: TStream);
begin
  if AReport = nil then
    raise EPrintersTemplateException.Create('TppReport não informado.',
      ERR_PRINTERS_TEMPLATE_NOT_INFORMED, 'TReportTemplate.LoadFromStream');

  if AStream = nil then
    raise EPrintersTemplateException.Create('Stream do template não informado.',
      ERR_PRINTERS_TEMPLATE_NOT_INFORMED, 'TReportTemplate.LoadFromStream');

  try
    AReport.Template.LoadFromStream(AStream);
  except
    on E: Exception do
      raise EPrintersTemplateException.Create('Falha ao carregar template (stream): ' + E.Message,
        ERR_PRINTERS_TEMPLATE_LOAD_FAILED, 'TReportTemplate.LoadFromStream');
  end;
end;

{$ENDIF}

end.
