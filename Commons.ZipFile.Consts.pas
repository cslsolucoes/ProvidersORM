unit Commons.ZipFile.Consts;

{$IFDEF FPC}{$mode delphi}{$H+}{$ENDIF}

interface

resourcestring
  // ── Mensagens cross-format (genéricas) ──
  rsArchiveFilenameDoesNotExistInS = 'Archive entry %s does not exist in %s';
  rsArchiveFileSDoesNotExist       = 'Archive %s does not exist';
  rsArchiveSIsCorruptOrUnsupported = 'Archive %s is corrupt or has unsupported format';
  rsArchiveSIsEmpty                = 'Archive %s is empty';
  rsArchiveSIsAlreadyOpen          = 'Archive %s is already open';
  rsArchiveSIsNotOpen              = 'Archive %s is not open';
  rsArchivePasswordRequired        = 'Archive %s is encrypted — password required';
  rsArchivePasswordIncorrect       = 'Incorrect password for archive %s';
  rsArchiveWriteNotSupported       = 'Write operations not supported for this archive format';

  // ── Códigos de plataforma / engine ──
  rsPlatformNotSupported           = 'This operation is not supported on the current platform';
  rsEngineNotInitialized           = 'Compression engine is not initialized';

resourcestring
  rsFilenameSDoesNotExistInS = 'Filename %s does not exist in %s';
  rsZipFileSDoesNotExist = 'ZipFile %s does not exist';

implementation

end.
