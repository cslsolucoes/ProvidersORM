{ TarFile.Interfaces.pas

  Companion interfaces de TarFile.pas conforme
  backend-pascal-unit-naming_V1.6.0 §2 — declara o builder fluent
  ITarFileBuilder (anteriormente em Tar.Fluent.pas) na unit
  companion canônica.
}
unit TarFile.Interfaces;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Classes;

type
  ITarFileBuilder = interface
    ['{F8A3D912-4E6B-4C1A-9E51-2A8C7B3D911E}']
    function WithGzip(AEnable: Boolean = True): ITarFileBuilder;
    function WithGzipLevel(ALevel: Integer): ITarFileBuilder;
    function AppendFile(const ADiskFileName, AEntryName: string): ITarFileBuilder;
    function AppendBytes(const AData: TBytes; const AEntryName: string): ITarFileBuilder;
    function AppendString(const AContent, AEntryName: string): ITarFileBuilder;
    function AppendDirectory(const ADirName: string): ITarFileBuilder;
    procedure Execute;
    function ExtractStream(const AEntryName: string): TStream;
    function ReadAsBytes(const AEntryName: string): TBytes;
    function ReadAsString(const AEntryName: string): string;
    function HasEntry(const AEntryName: string): Boolean;
    function CountEntries: Integer;
  end;

implementation

end.
