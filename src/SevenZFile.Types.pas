{ =============================================================================
  SevenZFile.Types - absorvido do ZipFileORM v4.0.0 (modulo ZipFile, F1-A Onda A.3)

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
  SevenZFile.Types - Codec / filter / crypto / LZMA tuning enums of 7Z

  Descrição:
  Companion types unit of SevenZFile.pas. These 6 enums encode the full
  7z codec ID space (compression methods, filters, encryption, LZMA-internal
  tuning) and are referenced by consumers configuring TSevenZFile.Compression /
  Filter / Crypto / LzmaMatchFinder / LzmaAlgorithm. Splitting them here keeps
  SevenZFile.pas focused on class implementation.

  Características:
  - TSevenZMethod (12 compressors com codec IDs binarios per 7z spec)
  - TSevenZFilter (11 BCJ/Delta preprocessors)
  - TSevenZCrypto (3 encryption modes: None/AES256/ZipCrypto)
  - TLzmaMatchFinder (4 match finder strategies: BT2/BT3/BT4/HC4)
  - TLzmaAlgorithm (2 modes: laFast/laNormal)
  - Backward-compatible re-export via type + const aliases em SevenZFile.pas
  - Cross-platform: Delphi (D24..D37 Win32+Win64) + FPC/Lazarus

  Project:        ZipFileORM
  ProjectVersion: 4.0.0
  FileVersion:    1.0.0
  Author:         CSL Softwares
  Date:           28/05/2026

  Changelog (file):
  - 1.0.0 (28/05/2026): created — split from SevenZFile.pas (Wave 3a).
  ============================================================================= }
unit SevenZFile.Types;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

type
  // Metodo de compressao primario por entry no .7z. CodecIDs binarios per
  // 7z format spec (lzma SDK / 7zFormat.txt):
  //
  // Compressores:
  //   szmCopy        = $00            — sem compressao (Store)
  //   szmLzma2       = $21            — LZMA2 (default, melhor general-purpose)
  //   szmLzma        = $03 $01 $01    — LZMA classico (pre-LZMA2)
  //   szmPpmd        = $03 $04 $01    — PPMd (compressao de texto excelente)
  //   szmDeflate     = $04 $01 $08    — Deflate (zlib — compat .zip)
  //   szmDeflate64   = $04 $01 $09    — Deflate64 (PKWARE extension)
  //   szmBzip2       = $04 $02 $02    — bzip2 (Burrows-Wheeler)
  //   szmZstd        = $04 $F7 $11 $01 — Zstandard (extensao 7-zip 22+)
  //   szmBrotli      = $04 $F7 $11 $02 — Brotli (extensao 7-zip 22+)
  //   szmLz4         = $04 $F7 $11 $04 — LZ4 (extensao 7-zip 22+)
  //   szmLz5         = $04 $F7 $11 $05 — LZ5
  //   szmLizard      = $04 $F7 $11 $06 — Lizard
  TSevenZMethod = (
    szmCopy,         // $00
    szmLzma2,        // $21 — default
    szmLzma,         // $03 $01 $01
    szmPpmd,         // $03 $04 $01
    szmDeflate,      // $04 $01 $08
    szmDeflate64,    // $04 $01 $09
    szmBzip2,        // $04 $02 $02
    szmZstd,         // $04 $F7 $11 $01
    szmBrotli,       // $04 $F7 $11 $02
    szmLz4,          // $04 $F7 $11 $04
    szmLz5,          // $04 $F7 $11 $05
    szmLizard        // $04 $F7 $11 $06
  );

  // Filters/preprocessors aplicados ANTES da compressao (codec chain).
  // Detectados por arquitetura do binario para melhorar ratio.
  // CodecIDs $03 $03 *:
  //   szfNone     = sem filtro (default)
  //   szfDelta    = $03 $03 $08 $01 — Delta encoding (audio/imagens)
  //   szfBCJ      = $03 $03 $01 $03 — Branch Call/Jump x86 32-bit
  //   szfBCJ2     = $03 $03 $01 $1B — BCJ2 (BCJ com 4 streams output)
  //   szfPPC      = $03 $03 $02 $05 — PowerPC big-endian
  //   szfIA64     = $03 $03 $04 $01 — Intel Itanium IA-64
  //   szfARM      = $03 $03 $05 $01 — ARM little-endian
  //   szfARMT     = $03 $03 $07 $01 — ARM Thumb
  //   szfSPARC    = $03 $03 $08 $05 — SPARC
  //   szfARM64    = $03 $03 $0A $01 — ARM64 / AArch64
  //   szfRISCV    = $03 $03 $0B $01 — RISC-V
  TSevenZFilter = (
    szfNone, szfDelta, szfBCJ, szfBCJ2, szfPPC, szfIA64,
    szfARM, szfARMT, szfSPARC, szfARM64, szfRISCV
  );

  // Crypto methods (codec chain $06 $F1 *):
  //   szcNone     = sem encryption
  //   szcAES256   = $06 $F1 $07 $01 — AES-256 + SHA-256 (7z default)
  //   szcZipCrypto= $06 $F1 $07 $02 — ZipCrypto (PKWARE legacy, weak)
  TSevenZCrypto = (szcNone, szcAES256, szcZipCrypto);

  // LZMA match finder algorithm (parametro `mf` em 7-zip CLI).
  //   mfBT2  = binary tree, 2-byte hash
  //   mfBT3  = binary tree, 3-byte hash
  //   mfBT4  = binary tree, 4-byte hash (default — best ratio)
  //   mfHC4  = hash chain, 4-byte hash (faster, lower ratio)
  TLzmaMatchFinder = (mfBT2, mfBT3, mfBT4, mfHC4);

  // LZMA encoding algorithm: fast (0) ou normal (1, default — better ratio).
  TLzmaAlgorithm = (laFast, laNormal);

implementation

end.
