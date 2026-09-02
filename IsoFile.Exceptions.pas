{ =============================================================================
  IsoFile.Exceptions - absorvido do ZipFileORM v4.0.0 (modulo ZipFile, F1-A Onda A.3)

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
{ =============================================================================
  IsoFile.Exceptions - Exception class of the ISO module

  Descrição:
  Companion exception unit of IsoFile.pas. Split from IsoFile.pas per
  v4.1 Wave 3b uniformity refactor.

  Características:
  - EIsoError (single class — raised on ISO 9660 parse errors, invalid
    volume descriptors, unsupported extensions, etc.)
  - Backward-compatible re-export via `type` alias in IsoFile.pas
  - Cross-platform: Delphi (D24..D37 Win32+Win64) + FPC/Lazarus

  Project:        ZipFileORM
  ProjectVersion: 4.0.0
  FileVersion:    1.0.0
  Author:         CSL Softwares
  Date:           28/05/2026

  Changelog (file):
  - 1.0.0 (28/05/2026): created — split from IsoFile.pas (Wave 3b).
  ============================================================================= }
unit IsoFile.Exceptions;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Exceptions.Base;

type
  EIsoError = class(EExceptionBase);

implementation

end.
