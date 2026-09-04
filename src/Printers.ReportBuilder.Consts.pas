{ =============================================================================
  Printers.ReportBuilder.Consts - Constantes do adapter ReportBuilder

  Descrição:
  Identificadores de "device" nativos do `TppReport.DeviceType` (ReportBuilder)
  — Screen/Printer/PDF. Movidos para aqui (Onda 9.1) porque são específicos do
  motor ReportBuilder, não dado neutro do módulo Printers (correção de
  placement — antes viviam em `Commons.Printers.Consts`, F1, por herança
  directa da fonte v2.2.0 que os tratava como "constantes do umbrella").

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.0.0 (03/08/2026): criado na Onda 9.1 (placement) — relocado de
    `Commons.Printers.Consts` (F1, removido de lá nesta mesma onda, decisão do
    owner: "mover RB_DEVICE_* para o adapter RB, toca o F1") + de
    `Modulos/Printers/Commons/Printers.Consts.pas` (cópia crua v2.2.0,
    eliminada — conteúdo idêntico). Zero alteração de valores.
  Changelog (fonte v2.3.0, unit `Printers.Consts`):
  - 1.0.0 (28/06/2026): Versão inicial — device names do ReportBuilder.
  ============================================================================= }

unit Printers.ReportBuilder.Consts;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_REPORTBUILDER}

const
  { DeviceType do TppReport (ReportBuilder) — valores nativos do motor. }
  RB_DEVICE_SCREEN  = 'Screen';
  RB_DEVICE_PRINTER = 'Printer';
  RB_DEVICE_PDF     = 'PDF';

{$ENDIF}

implementation

end.
