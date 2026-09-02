{ =============================================================================
  Bzip2.Stream.Interfaces - absorvido do ZipFileORM v4.0.0 (modulo ZipFile, F1-A Onda A.3)

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
{ Bzip2.Stream.Interfaces.pas

  Companion interfaces de Bzip2.Stream.pas conforme
  backend-pascal-unit-naming_V1.6.0 §2 — declara o builder fluent
  IBzip2Builder (anteriormente em Bzip2.Fluent.pas) na unit
  companion canônica.
}
unit Bzip2.Stream.Interfaces;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Classes;

type
  TBzip2Direction = (bzdCompress, bzdDecompress);

  IBzip2Builder = interface
    ['{D2A8F417-6B91-4C5E-9DA3-8F1E6C5B4321}']
    function WithLevel(ALevel: Integer): IBzip2Builder;
    function ToBytes: TBytes;
    function ToString: string;
    procedure ToStream(ADest: TStream);
    procedure ToFile(const APath: string);
  end;

implementation

end.
