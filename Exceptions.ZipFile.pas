{ =============================================================================
  Exceptions.ZipFile - Excecoes do modulo ZipFile/Archive (faixa 99)

  Todas as excecoes de arquivamento herdam de EExceptionBase (raiz do ecossistema;
  prerrogativa perene: nenhuma excecao de dominio herda de Exception cru). Faixa de
  codigos MMXXXX = 99 (ERR_ZIPFILE_BASE = 990000, definido em Exceptions.Base).

  Nomes compactos preservados (EArchive, EArchiveNotFound, ...) por decisao do
  owner (F15, sem rename/alias) - so re-parent + codigo. As raizes de FORMATO que
  hoje vivem em Modulos/ZipFile/ (EArjError, ERarError, ...) sao re-parented in
  place na Onda 15.2-b/c (patch); os codigos faixa 99 reservados para elas ficam
  aqui como SSOT.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           01/09/2026

  Changelog (file):
  - 1.1.0 (01/09/2026): F15 Onda 15.2-a - re-parent EArchive / EZipFileCancelled /
    EZipFileZip64NotSupported de Exception cru -> EExceptionBase (via
    uses Exceptions.Base). Adicionada a tabela de codigos faixa 99 (ERR_ARCHIVE_* +
    reservas de formato ERR_ZIPFILE_*). Nomes mantidos; sub-classes de EArchive
    inalteradas (conformam-se por heranca). O wiring dos codigos nos raise sites
    e a conformacao das raizes do modulo = Ondas 15.2-b/c (patch).
  - 1.0.0 (pre-F15): hub de excecoes ZipFile herdando de Exception cru (sem header).
  ============================================================================= }
unit Exceptions.ZipFile;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
  {$H+}
{$ENDIF}

interface

uses
{$IF DEFINED(FPC)}
  SysUtils,
{$ELSE}
  System.SysUtils,
{$ENDIF}
  Exceptions.Base;

const
  { --- Codigos faixa 99 (ZipFile/Archive); ERR_ZIPFILE_BASE=990000 em Exceptions.Base --- }
  ERR_ARCHIVE_GENERIC                = ERR_ZIPFILE_BASE + 1;    // 990001
  ERR_ARCHIVE_NOT_FOUND              = ERR_ZIPFILE_BASE + 2;    // 990002
  ERR_ARCHIVE_INVALID_FORMAT         = ERR_ZIPFILE_BASE + 3;    // 990003
  ERR_ARCHIVE_CORRUPT                = ERR_ZIPFILE_BASE + 4;    // 990004
  ERR_ARCHIVE_ALREADY_OPEN           = ERR_ZIPFILE_BASE + 5;    // 990005
  ERR_ARCHIVE_NOT_OPEN               = ERR_ZIPFILE_BASE + 6;    // 990006
  ERR_ARCHIVE_ENCRYPTION             = ERR_ZIPFILE_BASE + 7;    // 990007
  ERR_ARCHIVE_PASSWORD_REQUIRED      = ERR_ZIPFILE_BASE + 8;    // 990008
  ERR_ARCHIVE_PASSWORD_INCORRECT     = ERR_ZIPFILE_BASE + 9;    // 990009
  ERR_ARCHIVE_WRITE_NOT_SUPPORTED    = ERR_ZIPFILE_BASE + 10;   // 990010
  ERR_ARCHIVE_PLATFORM_NOT_SUPPORTED = ERR_ZIPFILE_BASE + 11;   // 990011
  ERR_ARCHIVE_ENTRY_NOT_FOUND        = ERR_ZIPFILE_BASE + 12;   // 990012
  ERR_ARCHIVE_DETECT                 = ERR_ZIPFILE_BASE + 13;   // 990013 (EArchiveDetectError, 15.2-c)
  ERR_ARCHIVE_WRITE_FAILED           = ERR_ZIPFILE_BASE + 14;   // 990014 (raises genericos, 15.2-c)
  ERR_ZIPFILE_CANCELLED              = ERR_ZIPFILE_BASE + 20;   // 990020
  ERR_ZIPFILE_ZIP64_NOT_SUPPORTED    = ERR_ZIPFILE_BASE + 21;   // 990021

  { Reservas de codigo para as raizes de FORMATO do modulo (conformadas na 15.2-c) }
  ERR_ZIPFILE_ARJ                    = ERR_ZIPFILE_BASE + 40;   // 990040
  ERR_ZIPFILE_RAR                    = ERR_ZIPFILE_BASE + 41;   // 990041
  ERR_ZIPFILE_CAB                    = ERR_ZIPFILE_BASE + 42;   // 990042
  ERR_ZIPFILE_LHA                    = ERR_ZIPFILE_BASE + 43;   // 990043
  ERR_ZIPFILE_ISO                    = ERR_ZIPFILE_BASE + 44;   // 990044
  ERR_ZIPFILE_SEVENZ                 = ERR_ZIPFILE_BASE + 45;   // 990045
  ERR_ZIPFILE_BZIP2                  = ERR_ZIPFILE_BASE + 46;   // 990046
  ERR_ZIPFILE_GZIP                   = ERR_ZIPFILE_BASE + 47;   // 990047
  ERR_ZIPFILE_TAR                    = ERR_ZIPFILE_BASE + 48;   // 990048
  ERR_ZIPFILE_TARGZ                  = ERR_ZIPFILE_BASE + 49;   // 990049
  ERR_ZIPFILE_UUE                    = ERR_ZIPFILE_BASE + 50;   // 990050
  ERR_ZIPFILE_ZCOMPRESS              = ERR_ZIPFILE_BASE + 51;   // 990051
  ERR_ZIPFILE_LZMA                   = ERR_ZIPFILE_BASE + 52;   // 990052
  ERR_ZIPFILE_AES                    = ERR_ZIPFILE_BASE + 53;   // 990053
  ERR_ZIPFILE_ZLIB                   = ERR_ZIPFILE_BASE + 54;   // 990054
  ERR_ZIPFILE_GZIPSTREAM             = ERR_ZIPFILE_BASE + 55;   // 990055

type
  // Exception base - todos os erros do ZipFileORM herdam daqui (agora via EExceptionBase)
  EArchive = class(EExceptionBase);

  // Erros de acesso a archive
  EArchiveNotFound          = class(EArchive);
  EArchiveInvalidFormat     = class(EArchive);
  EArchiveCorrupt           = class(EArchive);
  EArchiveAlreadyOpen       = class(EArchive);
  EArchiveNotOpen           = class(EArchive);

  // Erros de criptografia
  EArchiveEncryption        = class(EArchive);
  EArchivePasswordRequired  = class(EArchiveEncryption);
  EArchivePasswordIncorrect = class(EArchiveEncryption);

  // Erros de operacao
  EArchiveWriteNotSupported   = class(EArchive);
  EArchivePlatformNotSupported = class(EArchive);
  EArchiveEntryNotFound        = class(EArchive);

  // Excecoes ZipFile especificas (siblings de EArchive, tambem sob EExceptionBase)
  EZipFileCancelled = class(EExceptionBase);
  EZipFileZip64NotSupported = class(EExceptionBase);

implementation

end.
