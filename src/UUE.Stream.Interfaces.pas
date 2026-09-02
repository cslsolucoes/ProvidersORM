{ =============================================================================
  UUE.Stream.Interfaces - absorvido do ZipFileORM v4.0.0 (modulo ZipFile, F1-A Onda A.3)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           05/07/2026

  Changelog (file):
  - 1.0.0 (05/07/2026): v3 F1-A A.3 - copia integral do ZipFileORM v4.0.0 com
    namespaces reconciliados conforme o mapa da Onda A.1 do plano (dados do
    pacote consolidados no nucleo Commons e infra renomeada ao namespace do
    modulo). Paths de objetos nativos apontam a pasta Library do modulo.
    Header original preservado abaixo.
  ============================================================================= }
{ UUE.Stream.Interfaces.pas

  Companion interfaces de UUE.Stream.pas conforme
  backend-pascal-unit-naming_V1.6.0 §2 — declara o builder fluent
  IUueBuilder (anteriormente em UUE.Fluent.pas) na unit companion
  canônica.
}
unit UUE.Stream.Interfaces;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Classes;

type
  TUueDirection = (uudEncode, uudDecode);

  IUueBuilder = interface
    ['{A7E2D158-9F4B-4C5E-AB12-3E8F9D5C4B17}']
    function WithFileName(const AName: string): IUueBuilder;
    function WithMode(AMode: Cardinal): IUueBuilder;
    function ToString: string;
    function ToBytes: TBytes;
    procedure ToStream(ADest: TStream);
    procedure ToFile(const APath: string);
  end;

implementation

end.
