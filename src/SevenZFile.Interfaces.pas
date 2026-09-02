{ =============================================================================
  SevenZFile.Interfaces - absorvido do ZipFileORM v4.0.0 (modulo ZipFile, F1-A Onda A.3)

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
{ SevenZFile.Interfaces.pas

  Companion interfaces de SevenZFile.pas conforme
  backend-pascal-unit-naming_V1.6.0 §2 — declara o builder fluent
  ISevenZFileBuilder (anteriormente em SevenZ.Fluent.pas) na unit
  companion canônica.
}
unit SevenZFile.Interfaces;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Classes;

type
  ISevenZFileBuilder = interface
    ['{C9E1A5B2-3D8F-4C2A-8E11-7B5D4F8A39C2}']
    function WithStore: ISevenZFileBuilder;
    function WithLZMA2(ALevel: Integer = 5): ISevenZFileBuilder;
    function AppendFile(const ADiskFileName, AEntryName: string): ISevenZFileBuilder;
    function AppendBytes(const AData: TBytes; const AEntryName: string): ISevenZFileBuilder;
    procedure Execute;
    function ExtractStream(const AEntryName: string): TStream;
    function ReadAsBytes(const AEntryName: string): TBytes;
    function ReadAsString(const AEntryName: string): string;
    function HasEntry(const AEntryName: string): Boolean;
    function CountEntries: Integer;
  end;

implementation

end.
