{ =============================================================================
  ZCompress.LzwStream.Interfaces - absorvido do ZipFileORM v4.0.0 (modulo ZipFile, F1-A Onda A.3)

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
{ ZCompress.LzwStream.Interfaces.pas

  Companion interfaces de ZCompress.LzwStream.pas conforme
  backend-pascal-unit-naming_V1.6.0 §2 — declara o builder fluent
  IZCompressBuilder (anteriormente em ZCompress.Fluent.pas) na unit
  companion canônica.
}
unit ZCompress.LzwStream.Interfaces;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Classes;

type
  TZCompressDirection = (zcdCompress, zcdDecompress);

  IZCompressBuilder = interface
    ['{E3B947C2-8D14-4F62-9A53-71BC4D8E6A12}']
    function WithMaxBits(ABits: Integer): IZCompressBuilder;
    function ToBytes: TBytes;
    function ToString: string;
    procedure ToStream(ADest: TStream);
    procedure ToFile(const APath: string);
  end;

implementation

end.
