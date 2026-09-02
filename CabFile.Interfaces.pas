{ =============================================================================
  CabFile.Interfaces - absorvido do ZipFileORM v4.0.0 (modulo ZipFile, F1-A Onda A.3)

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
{ CabFile.Interfaces.pas

  Companion interfaces de CabFile.pas conforme
  backend-pascal-unit-naming_V1.6.0 §2 — declara o builder fluent
  ICabFileBuilder (anteriormente em Cab.Fluent.pas) e os tipos que
  o contrato utiliza (TCabCompressionType).

  CabFile.pas re-exporta os tipos via alias para preservar
  retro-compatibilidade dos consumidores que fazem `uses WCabFile`.
}
unit CabFile.Interfaces;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Classes;

type
  TCabCompressionType = (cctNone, cctMSZIP);  // MSZIP nao funcional ate v3.7.2

  ICabFileBuilder = interface
    ['{4B7A3E84-2C95-4A11-BA42-E6F1A3D29111}']
    function WithCompression(AKind: TCabCompressionType): ICabFileBuilder;
    function AppendFile(const ADiskFileName, AEntryName: string): ICabFileBuilder;
    procedure Execute;
    function ExtractStream(const AEntryName: string): TStream;
    function ReadAsBytes(const AEntryName: string): TBytes;
    function ReadAsString(const AEntryName: string): string;
    function HasEntry(const AEntryName: string): Boolean;
    function CountEntries: Integer;
  end;

implementation

end.
