{ =============================================================================
  RarFile.Exceptions - absorvido do ZipFileORM v4.0.0 (modulo ZipFile, F1-A Onda A.3)

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
  RarFile.Exceptions - Exception hierarchy of the RAR module

  Descrição:
  Companion exception unit of RarFile.pas. Split from RarFile.pas per
  v4.1 Wave 3b uniformity refactor.

  Características:
  - ERarError (base) raised on generic RAR parse errors
  - ERarMethodNotSupported raised on compressed entries (current reader
    is metadata-only — full RAR decoder is v5.0 scope)
  - ERarUnsupportedFormat raised when archive is neither RAR4 nor RAR5
    or uses encryption headers not yet handled
  - Backward-compatible re-export via `type` aliases in RarFile.pas
  - Cross-platform: Delphi (D24..D37 Win32+Win64) + FPC/Lazarus

  Project:        ZipFileORM
  ProjectVersion: 4.0.0
  FileVersion:    1.0.0
  Author:         CSL Softwares
  Date:           28/05/2026

  Changelog (file):
  - 1.0.0 (28/05/2026): created — split from RarFile.pas (Wave 3b).
  ============================================================================= }
unit RarFile.Exceptions;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Exceptions.Base;

type
  ERarError = class(EExceptionBase);
  ERarMethodNotSupported = class(ERarError);
  ERarUnsupportedFormat = class(ERarError);

implementation

end.
