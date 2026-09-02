{ =============================================================================
  SevenZFile.Exceptions - absorvido do ZipFileORM v4.0.0 (modulo ZipFile, F1-A Onda A.3)

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
  SevenZFile.Exceptions - Exception hierarchy of the 7Z module

  Descrição:
  Companion exception unit of SevenZFile.pas, holding the ESevenZError
  root + ESevenZNotSupportedOnPlatform leaf. Split from SevenZFile.pas
  per v4.1 Wave 3a refactor.

  Características:
  - 2 exception classes (ESevenZError base, ESevenZNotSupportedOnPlatform leaf)
  - ESevenZNotSupportedOnPlatform raised on FPC (no rota planeada per spec)
  - Backward-compatible re-export via `type` aliases in SevenZFile.pas
  - Cross-platform: Delphi (D24..D37 Win32+Win64) + FPC/Lazarus

  Project:        ZipFileORM
  ProjectVersion: 4.0.0
  FileVersion:    1.0.0
  Author:         CSL Softwares
  Date:           28/05/2026

  Changelog (file):
  - 1.0.0 (28/05/2026): created — split from SevenZFile.pas (Wave 3a).
  ============================================================================= }
unit SevenZFile.Exceptions;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Exceptions.Base;

type
  ESevenZError = class(EExceptionBase);
  ESevenZNotSupportedOnPlatform = class(ESevenZError);

implementation

end.
