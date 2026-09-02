(* =============================================================================
  ORM.Version.inc - Single source of version for the unified ProvidersORM

  Consumed by: Commons.Version.pas (const section include), resource script
  generation (.rc) and CHANGELOG tooling. Eliminates the v1/v2 triplication
  (.rc x Version.pas x changelog headers).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           04/07/2026

  Changelog (file):
  - 1.0.0 (04/07/2026): v3 initial - version as consts, plan wave 0.1.
    Const names without project prefix (PRODUCT_NAME already identifies the
    project - owner review). 4-field versioning Major.Minor.Patch.Build
    (matches Windows FILEVERSION/.rc - owner review).
  ============================================================================= *)

  VERSION_MAJOR   = 3;
  VERSION_MINOR   = 0;
  VERSION_PATCH   = 0;
  VERSION_BUILD   = 0;
  VERSION_SEMVER  = '3.0.0';       // Major.Minor.Patch (sem build)
  VERSION         = '3.0.0.0';     // Major.Minor.Patch.Build (resource/exe)
  VERSION_DATE    = '2026-07-04';
  PRODUCT_NAME    = 'ProvidersORM';
  PRODUCT_COMPANY = 'CSL Tech Solutions';
  PRODUCT_COPYRIGHT = 'Copyright (C) 2025-2026 CSL Tech Solutions';

(* ========================== END ORM.Version.inc v3 ========================= *)
