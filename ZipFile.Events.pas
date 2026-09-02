{ ZipFile.Events.pas

  Tipos de evento compartilhados entre todos os componentes archive (TZipFile,
  TSevenZFile, TWCabFile, TTarFile, TTarGzFile, TGzipFile, TArjFile, TIsoFile,
  TLhaFile, TRarFile).

  Naming convention das procs de evento:
    TArchive<Action>Event = procedure(Sender; <args>) of object;
    TArchive<Action>QueryEvent = procedure(Sender; <args>; var <decision>) of object;

  Categorias:
    Lifecycle  — OnBeforeOpen, OnAfterOpen, OnBeforeClose, OnAfterClose
    Entry      — OnEntryFound, OnBeforeExtract, OnAfterExtract, OnBeforeAdd, OnAfterAdd
    Progress   — TZipProgressEvent (overall, ja em Commons.ZipFile.Types.pas)
                 TArchiveEntryProgressEvent (per-entry)
                 TArchiveFolderProgressEvent (per-folder em 7z)
    Security   — OnAskPassword, OnReplaceQuery, OnVerify
    Multi-vol  — OnRequestVolume, OnVolumeChanged
    Diagnostics— OnError, OnLog, OnWarning
    Codec (7z) — OnSolidBlockStart, OnSolidBlockEnd, OnCompressionMethodSelect

  Cross-platform: Delphi (D24..D37) + FPC/Lazarus.
}
unit ZipFile.Events;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Classes;

type
  // -------------------- Estado / lifecycle --------------------

  // Pre-action gate: handler pode cancelar setando ACancel := True.
  TArchiveLifecycleQueryEvent = procedure(Sender: TObject; var Cancel: Boolean) of object;

  // Post-action notification.
  TArchiveLifecycleEvent = TNotifyEvent;

  // -------------------- Entries --------------------

  // Disparado para cada entry encontrado durante scan/open da CD/index.
  // Skip := True faz o componente ignorar o entry para subsequentes operacoes.
  TArchiveEntryFoundEvent = procedure(
    Sender: TObject;
    const EntryName: string;
    EntryIndex: Integer;
    Size: Int64;
    var Skip: Boolean) of object;

  // Pre-extract per entry: handler pode redirecionar para outro target ou pular.
  TArchiveBeforeExtractEvent = procedure(
    Sender: TObject;
    const EntryName: string;
    EntryIndex: Integer;
    var TargetPath: string;
    var Skip: Boolean) of object;

  // Post-extract per entry: dispara apos cada entry ser gravado em disco.
  TArchiveAfterExtractEvent = procedure(
    Sender: TObject;
    const EntryName: string;
    EntryIndex: Integer;
    const ExtractedPath: string;
    BytesExtracted: Int64) of object;

  // Pre-add per entry (write side): handler pode renomear EntryName ou pular.
  TArchiveBeforeAddEvent = procedure(
    Sender: TObject;
    const SourcePath: string;
    var EntryName: string;
    var Skip: Boolean) of object;

  // Post-add per entry.
  TArchiveAfterAddEvent = procedure(
    Sender: TObject;
    const EntryName: string;
    EntryIndex: Integer;
    BytesWritten: Int64;
    CompressedSize: Int64) of object;

  // -------------------- Progress --------------------

  // Progress per entry (vs overall TZipProgressEvent). Cancel via var.
  TArchiveEntryProgressEvent = procedure(
    Sender: TObject;
    const EntryName: string;
    BytesDone, BytesTotal: Int64;
    var Cancel: Boolean) of object;

  // Progress per folder/packed stream em 7z (1 folder pode conter varios entries).
  TArchiveFolderProgressEvent = procedure(
    Sender: TObject;
    FolderIndex: Integer;
    BytesDone, BytesTotal: Int64;
    var Cancel: Boolean) of object;

  // -------------------- Password / Encryption --------------------

  // Solicita password ao caller. Vazio + Cancel=False = tentar sem password.
  // Cancel=True aborta a operacao.
  TArchivePasswordRequestEvent = procedure(
    Sender: TObject;
    const EntryName: string;
    Attempt: Integer;
    var Password: string;
    var Cancel: Boolean) of object;

  // -------------------- Conflict / replace --------------------

  // Acao a tomar quando extracao colide com arquivo existente.
  TArchiveReplaceAction = (
    raSkip,             // pula este entry
    raReplace,          // sobrescreve apenas este
    raReplaceAll,       // sobrescreve daqui pra frente (cache na opcao)
    raSkipAll,          // pula daqui pra frente
    raRenameNew,        // grava com sufixo numerico (target_1.txt etc.)
    raCancel            // aborta toda a extracao
  );

  TArchiveReplaceQueryEvent = procedure(
    Sender: TObject;
    const ExistingPath: string;
    const EntryName: string;
    ExistingSize, NewSize: Int64;
    var Action: TArchiveReplaceAction) of object;

  // -------------------- Verify / integrity --------------------

  // Disparado apos calcular CRC durante extract — handler pode aceitar/rejeitar.
  TArchiveVerifyEvent = procedure(
    Sender: TObject;
    const EntryName: string;
    ComputedCRC: Cardinal;
    ExpectedCRC: Cardinal;
    var IsValid: Boolean) of object;

  // -------------------- Multi-volume --------------------

  // Read side: archive aponta para proximo volume que nao existe no path padrao.
  // Handler pode retornar NewPath com a localizacao real (ex.: usuario inseriu disco).
  TArchiveRequestVolumeEvent = procedure(
    Sender: TObject;
    VolumeNumber: Integer;
    const ExpectedPath: string;
    var NewPath: string;
    var Cancel: Boolean) of object;

  // Write side: arquivo atingiu VolumeSize, novo volume sendo criado.
  TArchiveVolumeChangedEvent = procedure(
    Sender: TObject;
    OldVolumeNumber: Integer;
    NewVolumeNumber: Integer;
    const NewVolumePath: string) of object;

  // -------------------- Diagnostics --------------------

  // Erro recuperavel. Handled := True suprime a exception.
  TArchiveErrorEvent = procedure(
    Sender: TObject;
    const Context: string;
    E: Exception;
    var Handled: Boolean) of object;

  // Warning nao-fatal (corrupcao detectada, header inconsistente, etc.).
  TArchiveWarningEvent = procedure(
    Sender: TObject;
    const Context: string;
    const Message: string) of object;

  // Verbose log message. Level: 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR.
  TArchiveLogEvent = procedure(
    Sender: TObject;
    Level: Byte;
    const Message: string) of object;

  // -------------------- Codec selection (7z especifico) --------------------

  // Disparado ao iniciar leitura/escrita de cada folder/packed stream solid em 7z.
  TArchiveSolidBlockEvent = procedure(
    Sender: TObject;
    FolderIndex: Integer;
    EntryCount: Integer;
    UnpackedSize: Int64;
    PackedSize: Int64) of object;

  // Disparado quando o codec chain de um entry eh resolvido (read side) ou
  // selecionado (write side). Handler pode logar/decidir baseado no tipo.
  TArchiveCompressionMethodEvent = procedure(
    Sender: TObject;
    const EntryName: string;
    MethodID: Cardinal;       // primeiro byte do codec ID
    const MethodName: string  // nome textual ('LZMA2', 'BCJ', 'Copy', etc.)
    ) of object;

implementation

end.
