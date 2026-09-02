{*
 * ZipFile.Compression.Consts.pas
 *
 * Constantes string para o factory de compressão (era tiConstants.pas do MCL).
 * Renomeado para namespace Commons.* na refatoração v4.0.0.
 *
 * Original (c) 2006-2007 MODELbuilder developers team — Graeme Geldenhuys
 * Refactor v4.0.0 (c) 2026 CSL Softwares
 * Licença: LGPL-3.0
 *}
unit ZipFile.Compression.Consts;

{$I ZipFile.Compression.Defines.inc}

interface

const
  // Compression constants — chaves para registro no TCompressFactory
  cgsCompressNone = 'No compression';
  cgsCompressZLib = 'ZLib compression';

implementation

end.
