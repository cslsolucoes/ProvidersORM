{ =============================================================================
  Exceptions.Messages - Leitor RUNTIME do catálogo de mensagens de exceção

  Descrição:
  Implementa IExceptionsMessages: resolve `código MMXXXX` ou `constant_name`
  para a mensagem no idioma pedido, lendo a tabela `messages` (por defeito
  Data/exception.db, SQLite). Reusa o SSOT existente — NÃO redefine nada:
    · nomes das colunas ....... Exceptions.Base (MESSAGES_COL)
    · nome da tabela .......... Commons.Consts (DEFAULT_MESSAGES_TABLE)
    · caminho do exception.db . Commons.Consts (DefaultMessagesDatabasePath)
    · idiomas ................. Commons.Consts (DEFAULT_LANGUAGE, LANGUAGE_*)
    · DDL da tabela ........... GERADO por ITable+IDialect (modulo Database)
    · record de retorno ....... Commons.Types (TMessageRecord)

  Diferenças deliberadas face à referência v2.3.0 (Exceptions.Database.pas, 829 L):

  1. SQL PARAMETRIZADO. A v2.3.0 concatenava tudo em RAW, escapando plicas à mão
     (`StringReplace(V, '''', '''''', [rfReplaceAll])`) e embebendo inteiros com
     IntToStr. Aqui usa-se o overload parametrizado de IConnection
     (`ExecuteQuery(ASQL, [p0, p1])`), que já existe no módulo Connections — sem
     escaping manual, sem superfície de injeção e sem depender do dialecto.

  2. CACHE THREAD-SAFE (T2). A v2.3.0 ia à BD em TODA a chamada. Aqui há cache em
     memória; como TDictionary NÃO é thread-safe e o catálogo é lido do path de
     exceções (Pool + Logger assíncrono), todo o acesso é serializado por
     TCriticalSection.

  3. FALLBACK DE IDIOMA (T5). A v2.3.0 filtrava `AND language = <pedido>` e, se não
     houvesse linha, devolvia vazio — indistinguível de mensagem vazia. Aqui há
     TMessageFallback (mfNone/mfDefault/mfAnyLanguage) e o miss devolve uma
     SENTINELA visível (T4), nunca string vazia silenciosa.

  4. FORMAT SEGURO (T3). GetMessage(...AArgs) nunca deixa escapar EConvertError de
     um `%s` a mais/a menos no catálogo: em erro devolve a mensagem crua + marca.

  NÃO portado de propósito: FromConfig/FromConfigJson (INI/JSON). Ler configuração
  é do módulo Parameters (F7); duplicar aqui violaria a regra transversal #14.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.2.0
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           01/09/2026

  Changelog (file):
  - 1.0.0 (01/09/2026): F15 Onda 15.4 — criação. Porte do leitor de catálogo da
    v2.3.0 com SQL parametrizado, cache thread-safe, fallback de idioma e
    sentinela em miss. Cross-compiler Delphi 12 + FPC 3.3.1.
  ============================================================================= }
unit Exceptions.Messages;

{$I ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Commons.Types,
  Connections.Interfaces,
  Exceptions.Messages.Interfaces;

type
  TExceptionsMessages = class(TInterfacedObject, IExceptionsMessages)
  strict private
    FConnection    : IConnection;
    FOwnsConnection: Boolean;
    FDatabasePath  : string;
    FLanguage      : string;
    FModule        : string;
    FSourceProject : string;
    FFallback      : TMessageFallback;

    procedure EnsureInternalConnection;
    procedure EnsureConnect;
    procedure EnsureMessagesTable;
    function  ResolvedPath: string;
    function  ResolvedLanguage: string;

    { Núcleo único de leitura: AByCode decide a coluna do filtro.
      Evita os 6 blocos quase-iguais que a v2.3.0 tinha. }
    function  Fetch(const AByCode: Boolean; ACode: Integer;
      const AConstantName: string; out ARecord: TMessageRecord): Boolean;
    function  FetchWithFallback(const AByCode: Boolean; ACode: Integer;
      const AConstantName: string; out ARecord: TMessageRecord): Boolean;
    function  CacheKey(const AByCode: Boolean; ACode: Integer;
      const AConstantName: string): string;
    function  SafeFormat(const AMask: string; const AArgs: array of const): string;
  public
    constructor Create;
    destructor  Destroy; override;
    class function New: IExceptionsMessages;

    function Language(const AValue: string): IExceptionsMessages; overload;
    function Language: string; overload;
    function Module(const AValue: string): IExceptionsMessages; overload;
    function Module: string; overload;
    function SourceProject(const AValue: string): IExceptionsMessages; overload;
    function SourceProject: string; overload;
    function Fallback(const AValue: TMessageFallback): IExceptionsMessages; overload;
    function Fallback: TMessageFallback; overload;

    function FromDefault: IExceptionsMessages;
    function FromFile(const APath: string): IExceptionsMessages;
    function FromConnection(const AConnection: IConnection): IExceptionsMessages;

    function GetMessage(ACode: Integer): string; overload;
    function GetMessage(ACode: Integer; const AArgs: array of const): string; overload;
    function GetMessageRecord(ACode: Integer): TMessageRecord; overload;
    function Exists(ACode: Integer): Boolean; overload;

    function GetMessage(const AConstantName: string): string; overload;
    function GetMessage(const AConstantName: string; const AArgs: array of const): string; overload;
    function GetMessageRecord(const AConstantName: string): TMessageRecord; overload;
    function Exists(const AConstantName: string): Boolean; overload;

    function ListAll: TArray<TMessageRecord>;

    function ClearCache: IExceptionsMessages;
    function CacheCount: Integer;

    function Connect: IExceptionsMessages; overload;
    function Connect(out ASuccess: Boolean): IExceptionsMessages; overload;
    function Disconnect: IExceptionsMessages;
    function IsConnected: Boolean;
  end;

{ Sentinela devolvida quando o código não existe no catálogo (T4).
  NUNCA devolver '' num miss: vazio confunde-se com mensagem legitimamente vazia
  e esconde catálogos incompletos em produção. }
function MessageNotFoundSentinel(ACode: Integer; const AConstantName: string): string;

implementation

uses
{$IF DEFINED(FPC)}
  { ORDEM IMPORTA: `Windows` declara TCriticalSection como RECORD (a estrutura
    CRITICAL_SECTION da API Win32) e ensombra a CLASSE homónima de SyncObjs —
    o sintoma é "Identifier idents no member Create" no FLock. SyncObjs tem de
    vir DEPOIS de Windows para ganhar a resolução. Custou-me 3 iterações no gate
    FPC da Onda 15.4 por eu ter assumido que o erro era nos genéricos, em vez de
    ler a linha que o compilador apontava. }
  SysUtils, Classes, Variants, DB, Windows, Generics.Collections, SyncObjs,
{$ELSE}
  System.SysUtils, System.Classes, System.Variants, Data.DB, Winapi.Windows,
  System.Generics.Collections, System.SyncObjs,
{$ENDIF}
  Commons.Consts,
  Commons.Database.Types,
  Exceptions.Base,
  Connections,
  { CRIACAO POR FLUENCIA (ordem do owner, 01/09): o ITable gera o DDL a partir
    da definicao de campos, com citacao de identificadores e tipo de coluna
    resolvidos pelo dialecto do engine. Zero SQL de DDL escrito a mao. }
  Databases.Interfaces,
  Database.Dialect,
  Database.Field,
  Database.Fields,
  Database.Table,
  Database.QueryBuilder;

type
  { Aliases obrigatórios para o FPC: em modo DELPHI o FPC 3.3.1 não aceita
    especializar um genérico inline no ponto de uso
    (`TDictionary<string, TMessageRecord>.Create` -> "Identifier idents no member
    Create"). Com alias de tipo compila nos dois compiladores. Apanhado no gate
    FPC da Onda 15.4.
    NOTA: não escrever a directiva de modo entre chavetas neste comentário — em
    Pascal `{` + `$` É directiva, mesmo dentro do que parece um comentário, e
    parte a compilação (custou-me uma iteração no gate FPC). }
  { `Database.Field` declara um TField PROPRIO (o campo do ORM) que ensombra
    o TField do Data.DB, porque vem depois no uses. Este alias mantem o do
    dataset acessivel para o FieldToText. }
{$IF DEFINED(FPC)}
  TDatasetField = DB.TField;
{$ELSE}
  TDatasetField = Data.DB.TField;
{$ENDIF}

  TMessageDict = TDictionary<string, Commons.Types.TMessageRecord>;
  TMessageList = TList<Commons.Types.TMessageRecord>;

  { Cache partilhada por processo: o catálogo é imutável em runtime (add-only, T12),
    logo vale a pena partilhar entre instâncias em vez de reler por cada uma. }
  TMessagesCache = class
  strict private
    FLock : TCriticalSection;
    FItems: TMessageDict;
  public
    constructor Create;
    destructor  Destroy; override;
    function  TryGet(const AKey: string; out ARecord: TMessageRecord): Boolean;
    procedure Put(const AKey: string; const ARecord: TMessageRecord);
    procedure Clear;
    function  Count: Integer;
  end;

var
  GCache: TMessagesCache = nil;

{ ---------------------------------------------------------------- TMessagesCache }

constructor TMessagesCache.Create;
begin
  inherited Create;
  FLock  := TCriticalSection.Create;
  FItems := TMessageDict.Create;
end;

destructor TMessagesCache.Destroy;
begin
  FItems.Free;
  FLock.Free;
  inherited Destroy;
end;

function TMessagesCache.TryGet(const AKey: string; out ARecord: TMessageRecord): Boolean;
begin
  FLock.Acquire;
  try
    Result := FItems.TryGetValue(AKey, ARecord);
  finally
    FLock.Release;
  end;
end;

procedure TMessagesCache.Put(const AKey: string; const ARecord: TMessageRecord);
begin
  FLock.Acquire;
  try
    FItems.AddOrSetValue(AKey, ARecord);
  finally
    FLock.Release;
  end;
end;

procedure TMessagesCache.Clear;
begin
  FLock.Acquire;
  try
    FItems.Clear;
  finally
    FLock.Release;
  end;
end;

function TMessagesCache.Count: Integer;
begin
  FLock.Acquire;
  try
    Result := FItems.Count;
  finally
    FLock.Release;
  end;
end;

{ --------------------------------------------------------------------- helpers }

function MessageNotFoundSentinel(ACode: Integer; const AConstantName: string): string;
begin
  if AConstantName <> '' then
    Result := Format('[messages: sem entrada para "%s"]', [AConstantName])
  else
    Result := Format('[messages: sem entrada para o codigo %d]', [ACode]);
end;

{ ----------------------------------------------------------- TExceptionsMessages }

constructor TExceptionsMessages.Create;
begin
  inherited Create;
  FLanguage       := DEFAULT_LANGUAGE;
  FFallback       := mfDefault;
  FOwnsConnection := False;
end;

destructor TExceptionsMessages.Destroy;
begin
  { Só desliga a ligação que ESTA instância criou. Uma ligação injectada por
    FromConnection pertence a quem a passou (ownership explícito — a v2.3.0 não
    distinguia os dois casos). }
  if FOwnsConnection and (FConnection <> nil) then
    try
      if FConnection.IsConnected then
        FConnection.Disconnect;
    except
      { teardown best-effort: fechar o catálogo nunca pode derrubar quem o usa. }
    end;
  FConnection := nil;
  inherited Destroy;
end;

class function TExceptionsMessages.New: IExceptionsMessages;
begin
  Result := TExceptionsMessages.Create;
end;

function TExceptionsMessages.Language(const AValue: string): IExceptionsMessages;
begin
  FLanguage := AValue;
  Result := Self;
end;

function TExceptionsMessages.Language: string;
begin
  Result := FLanguage;
end;

function TExceptionsMessages.Module(const AValue: string): IExceptionsMessages;
begin
  FModule := AValue;
  Result := Self;
end;

function TExceptionsMessages.Module: string;
begin
  Result := FModule;
end;

function TExceptionsMessages.SourceProject(const AValue: string): IExceptionsMessages;
begin
  FSourceProject := AValue;
  Result := Self;
end;

function TExceptionsMessages.SourceProject: string;
begin
  Result := FSourceProject;
end;

function TExceptionsMessages.Fallback(const AValue: TMessageFallback): IExceptionsMessages;
begin
  FFallback := AValue;
  Result := Self;
end;

function TExceptionsMessages.Fallback: TMessageFallback;
begin
  Result := FFallback;
end;

function TExceptionsMessages.FromDefault: IExceptionsMessages;
begin
  FDatabasePath   := '';
  FConnection     := nil;
  FOwnsConnection := False;
  Result := Self;
end;

function TExceptionsMessages.FromFile(const APath: string): IExceptionsMessages;
begin
  FDatabasePath   := APath;
  FConnection     := nil;
  FOwnsConnection := False;
  Result := Self;
end;

function TExceptionsMessages.FromConnection(const AConnection: IConnection): IExceptionsMessages;
begin
  FConnection     := AConnection;
  FOwnsConnection := False;  { não é nossa: não a desligamos no Destroy. }
  Result := Self;
end;

function TExceptionsMessages.ResolvedPath: string;
begin
  Result := FDatabasePath;
  if Result = '' then
    Result := DefaultMessagesDatabasePath;
end;

function TExceptionsMessages.ResolvedLanguage: string;
begin
  Result := FLanguage;
  if Result = '' then
    Result := DEFAULT_LANGUAGE;
end;

procedure TExceptionsMessages.EnsureInternalConnection;
begin
  if FConnection <> nil then
    Exit;
  { Banco secundário: SEMPRE SQLite (exception.db). Independente do banco
    principal da aplicação — mesma decisão da v2.3.0. }
  FConnection := TConnection.New
    .DatabaseType(dtSQLite)
    .Database(ResolvedPath);
  FOwnsConnection := True;
end;

procedure TExceptionsMessages.EnsureConnect;
begin
  EnsureInternalConnection;
  if (FConnection <> nil) and (not FConnection.IsConnected) then
  begin
    FConnection.Connect;
    { Primeira ligação ao NOSSO exception.db: garante a tabela. Sem isto, um
      ficheiro novo/vazio faz a 1ª leitura rebentar com "no such table:
      messages" — apanhado em runtime no spike da Onda 15.4. }
    EnsureMessagesTable;
  end;
end;

{ Bases `exception.db` ANTIGAS tem a coluna `message` como `blob COLLATE BINARY`
  (DDL hardcoded da v2.3.0, removido em 01/09). Lida com `.AsString` crua, uma
  mensagem UTF-8 volta como mojibake ('nao' -> 'nA£o') porque cada byte vira
  um char. Descodificar explicitamente como UTF-8 mantem o round-trip correcto
  nessas bases sem exigir migracao de esquema. Tabelas NOVAS ja nascem com o
  tipo de TEXTO do dialecto, logo caem no ramo AsString.
  Apanhado pelo smoke_exceptions_messages na Onda 15.4. }
function FieldToText(AField: TDatasetField): string;
var
  LBytes: TBytes;
begin
  Result := '';
  if (AField = nil) or AField.IsNull then
    Exit;
  { SÓ os tipos genuinamente BINÁRIOS passam por AsBytes. `ftMemo`/`ftWideMemo`
    são campos de TEXTO: `AsBytes` neles faz conversão para ANSI e rebenta com
    `EEncodingError: No mapping for the Unicode character` assim que a mensagem
    tem acentos — que é o caso de todo o catálogo pt-BR. Apanhado pelo
    smoke_exceptions_messages_db_matrix contra PostgreSQL/SQL Server/MariaDB
    reais (a escrita passava; era a LEITURA que rebentava). }
  if AField.DataType in [ftBlob, ftBytes, ftVarBytes] then
  begin
    LBytes := AField.AsBytes;
    if Length(LBytes) = 0 then
      Exit;
    Result := TEncoding.UTF8.GetString(LBytes);
  end
  else
    Result := AField.AsString;   { texto (incl. memo): AsString já devolve Unicode }
end;

{ Diagnóstico de último recurso: este leitor corre DENTRO do tratamento de
  exceções, logo não pode usar o ILogger (reentrância) nem propagar. Reusa o
  idioma já estabelecido no módulo Loggers ("C3", auditoria F8): OutputDebugString. }
procedure TraceSwallowed(const AWhere: string; E: Exception);
begin
{$IFNDEF FPC}
  OutputDebugString(PChar(Format('[ProvidersORM.Exceptions.Messages] %s falhou: %s: %s',
    [AWhere, E.ClassName, E.Message])));
{$ELSE}
  OutputDebugString(PChar(AnsiString(Format('[ProvidersORM.Exceptions.Messages] %s falhou: %s: %s',
    [AWhere, E.ClassName, E.Message]))));
{$ENDIF}
end;

procedure TExceptionsMessages.EnsureMessagesTable;
var
  LFields: IFields;
  LDialect: IDialect;
  LTable: ITable;
begin
  if FConnection = nil then
    Exit;

  { CRIAÇÃO POR FLUÊNCIA, sem uma linha de DDL escrita à mão (ordem do owner,
    01/09). O `ITable` gera o CREATE TABLE a partir da definição de campos e
    resolve DOIS problemas que o SQL hardcoded não resolvia:

      1. CITAÇÃO DE IDENTIFICADORES por dialecto (`QuoteIdent`). `MESSAGE` é
         PALAVRA RESERVADA no SQL Anywhere — o DDL não-citado dava
         "Syntax error near 'message'" e a tabela nunca era criada.
      2. TIPO DA COLUNA por engine, via `IDialect.ColumnTypeFor(ckText)`:
         TEXT (SQLite/PostgreSQL) · LONGTEXT (MySQL/Access) ·
         NVARCHAR(MAX) (SQL Server) · BLOB SUB_TYPE TEXT (Firebird) ·
         LONG VARCHAR (SQL Anywhere).

    Antes disto o dispatcher hardcoded nem sequer tinha ramo para SQL Anywhere:
    caía no `else` e devolvia DDL de SQLite. Ambos apanhados pelo
    smoke_exceptions_messages_db_matrix contra os servidores reais. }
  LDialect := TDialect.ForDatabaseType(FConnection.DatabaseType);

  LFields := TFields.New
    .AddField(Database.Field.TField.New.Column(MESSAGES_COL.Code)
      .ColumnType(LDialect.ColumnTypeFor(ckInteger)).IsPKey(True))
    .AddField(Database.Field.TField.New.Column(MESSAGES_COL.ConstantName)
      .ColumnType(LDialect.ColumnTypeFor(ckVarChar, 255)))
    .AddField(Database.Field.TField.New.Column(MESSAGES_COL.Message)
      .ColumnType(LDialect.ColumnTypeFor(ckText)))
    .AddField(Database.Field.TField.New.Column(MESSAGES_COL.Module)
      .ColumnType(LDialect.ColumnTypeFor(ckVarChar, 255)))
    .AddField(Database.Field.TField.New.Column(MESSAGES_COL.SourceProject)
      .ColumnType(LDialect.ColumnTypeFor(ckVarChar, 255)))
    .AddField(Database.Field.TField.New.Column(MESSAGES_COL.Language)
      .ColumnType(LDialect.ColumnTypeFor(ckVarChar, 50)).IsPKey(True))
    .AddField(Database.Field.TField.New.Column(MESSAGES_COL.Name)
      .ColumnType(LDialect.ColumnTypeFor(ckVarChar, 255)));

  { Best-effort: se a tabela já existe, o engine recusa e não há nada a fazer —
    mas deixa rasto (T10), nunca swallow mudo. }
  try
    LTable := TTable.New(LFields, DEFAULT_MESSAGES_TABLE);
    { DatabaseTypes devolve IFields (nao ITable), logo NAO encadeia com
      CreateTable - e' obrigatorio, sem ele o QuoteIdent nao cita e o SQL
      Anywhere rebenta em 'message' (palavra reservada). }
    LTable.DatabaseTypes(FConnection.DatabaseType);
    LTable.CreateTable(FConnection);
  except
    on E: Exception do
      TraceSwallowed('EnsureMessagesTable (tabela provavelmente ja existe)', E);
  end;
end;

function TExceptionsMessages.CacheKey(const AByCode: Boolean; ACode: Integer;
  const AConstantName: string): string;
begin
  if AByCode then
    Result := ResolvedLanguage + '|#' + IntToStr(ACode)
  else
    Result := ResolvedLanguage + '|$' + UpperCase(AConstantName);
end;

function TExceptionsMessages.Fetch(const AByCode: Boolean; ACode: Integer;
  const AConstantName: string; out ARecord: TMessageRecord): Boolean;
var
  LSQL: string;
  LDS : TDataSet;
begin
  Result := False;
  ARecord := Default(TMessageRecord);
  { Catálogo indisponível (ficheiro em falta, tabela por criar, BD bloqueada)
    NUNCA pode propagar: quem chama está a meio de tratar OUTRA exceção e trocar
    o erro original por um EDatabase seria pior que o problema. Degrada para
    miss -> sentinela, mas deixa rasto (T10: nada de swallow mudo). }
  try
    EnsureConnect;
  except
    on E: Exception do
    begin
      TraceSwallowed('EnsureConnect', E);
      Exit;
    end;
  end;
  if (FConnection = nil) or (not FConnection.IsConnected) then
    Exit;

  { LEITURA PELO MÓDULO DATABASE (ordem do owner, 01/09: "o exception é usuário
    do modulo Database/Connections"). Zero SQL escrito à mão: o IQueryBuilder
    gera o SELECT, parametriza os valores e — decisivo — CITA os identificadores
    pelo dialecto do engine.

    Sem essa citação o módulo não funcionava em dois engines:
      · SQL Anywhere — `message` é PALAVRA RESERVADA: "Syntax error near 'message'"
      · Firebird ..... identificador citado em minúsculas não casa com o
                       não-citado (que sofre fold para MAIÚSCULAS)
    Ambos apanhados pelo smoke_exceptions_messages_db_matrix contra os servidores
    reais — nenhum aparecia no SQLite local. }
  LDS := nil;
  try
    if AByCode then
      LDS := TQueryBuilder.New
        .Connection(FConnection)
        .Select
        .From(DEFAULT_MESSAGES_TABLE)
        .Where(MESSAGES_COL.Code, ACode)
        .Where(MESSAGES_COL.Language, ResolvedLanguage)
        .Execute
    else
      LDS := TQueryBuilder.New
        .Connection(FConnection)
        .Select
        .From(DEFAULT_MESSAGES_TABLE)
        .Where(MESSAGES_COL.ConstantName, AConstantName)
        .Where(MESSAGES_COL.Language, ResolvedLanguage)
        .Execute;
  except
    on E: Exception do
    begin
      TraceSwallowed('Fetch', E);
      Exit;
    end;
  end;

  if LDS = nil then
    Exit;
  try
    if LDS.Eof then
      Exit;
    ARecord.Code          := LDS.FieldByName(MESSAGES_COL.Code).AsInteger;
    ARecord.ConstantName  := LDS.FieldByName(MESSAGES_COL.ConstantName).AsString;
    ARecord.Message       := FieldToText(LDS.FieldByName(MESSAGES_COL.Message));
    ARecord.Module        := LDS.FieldByName(MESSAGES_COL.Module).AsString;
    ARecord.SourceProject := LDS.FieldByName(MESSAGES_COL.SourceProject).AsString;
    ARecord.Language      := LDS.FieldByName(MESSAGES_COL.Language).AsString;
    ARecord.Name          := LDS.FieldByName(MESSAGES_COL.Name).AsString;
    Result := True;
  finally
    LDS.Free;
  end;
end;

function TExceptionsMessages.FetchWithFallback(const AByCode: Boolean; ACode: Integer;
  const AConstantName: string; out ARecord: TMessageRecord): Boolean;
var
  LKey, LOriginal: string;
begin
  LKey := CacheKey(AByCode, ACode, AConstantName);
  if (GCache <> nil) and GCache.TryGet(LKey, ARecord) then
  begin
    Result := True;
    Exit;
  end;

  Result := Fetch(AByCode, ACode, AConstantName, ARecord);

  { Fallback de idioma — inexistente na v2.3.0. }
  if (not Result) and (FFallback <> mfNone) then
  begin
    LOriginal := FLanguage;
    try
      if not SameText(ResolvedLanguage, DEFAULT_LANGUAGE) then
      begin
        FLanguage := DEFAULT_LANGUAGE;
        Result := Fetch(AByCode, ACode, AConstantName, ARecord);
      end;
      if (not Result) and (FFallback = mfAnyLanguage) then
      begin
        FLanguage := '';  { ResolvedLanguage cai no default; ver nota abaixo }
        Result := Fetch(AByCode, ACode, AConstantName, ARecord);
      end;
    finally
      FLanguage := LOriginal;
    end;
  end;

  if Result and (GCache <> nil) then
    GCache.Put(LKey, ARecord);
end;

function TExceptionsMessages.SafeFormat(const AMask: string;
  const AArgs: array of const): string;
begin
  { T3: um catálogo com placeholders a mais/a menos não pode rebentar no meio do
    tratamento de uma exceção — seria trocar um erro por outro, pior. }
  try
    Result := Format(AMask, AArgs);
  except
    Result := AMask + ' [messages: argumentos incompativeis com a mascara]';
  end;
end;

function TExceptionsMessages.GetMessage(ACode: Integer): string;
var
  LRec: TMessageRecord;
begin
  if FetchWithFallback(True, ACode, '', LRec) then
    Result := LRec.Message
  else
    Result := MessageNotFoundSentinel(ACode, '');
end;

function TExceptionsMessages.GetMessage(ACode: Integer; const AArgs: array of const): string;
begin
  Result := SafeFormat(GetMessage(ACode), AArgs);
end;

function TExceptionsMessages.GetMessage(const AConstantName: string): string;
var
  LRec: TMessageRecord;
begin
  if FetchWithFallback(False, 0, AConstantName, LRec) then
    Result := LRec.Message
  else
    Result := MessageNotFoundSentinel(0, AConstantName);
end;

function TExceptionsMessages.GetMessage(const AConstantName: string;
  const AArgs: array of const): string;
begin
  Result := SafeFormat(GetMessage(AConstantName), AArgs);
end;

function TExceptionsMessages.GetMessageRecord(ACode: Integer): TMessageRecord;
begin
  if not FetchWithFallback(True, ACode, '', Result) then
    Result := Default(TMessageRecord);
end;

function TExceptionsMessages.GetMessageRecord(const AConstantName: string): TMessageRecord;
begin
  if not FetchWithFallback(False, 0, AConstantName, Result) then
    Result := Default(TMessageRecord);
end;

function TExceptionsMessages.Exists(ACode: Integer): Boolean;
var
  LRec: TMessageRecord;
begin
  Result := FetchWithFallback(True, ACode, '', LRec);
end;

function TExceptionsMessages.Exists(const AConstantName: string): Boolean;
var
  LRec: TMessageRecord;
begin
  Result := FetchWithFallback(False, 0, AConstantName, LRec);
end;

function TExceptionsMessages.ListAll: TArray<TMessageRecord>;
var
  LDS  : TDataSet;
  LList: TMessageList;
  LRec : TMessageRecord;
begin
  Result := nil;
  EnsureConnect;
  if (FConnection = nil) or (not FConnection.IsConnected) then
    Exit;

  { ListAll também pelo módulo Database - sem SQL à mão. }
  LDS := TQueryBuilder.New
    .Connection(FConnection)
    .Select
    .From(DEFAULT_MESSAGES_TABLE)
    .OrderBy(MESSAGES_COL.Code + ', ' + MESSAGES_COL.Language)
    .Execute;
  if LDS = nil then
    Exit;
  LList := TMessageList.Create;
  try
    while not LDS.Eof do
    begin
      LRec.Code          := LDS.FieldByName(MESSAGES_COL.Code).AsInteger;
      LRec.ConstantName  := LDS.FieldByName(MESSAGES_COL.ConstantName).AsString;
      LRec.Message       := FieldToText(LDS.FieldByName(MESSAGES_COL.Message));
      LRec.Module        := LDS.FieldByName(MESSAGES_COL.Module).AsString;
      LRec.SourceProject := LDS.FieldByName(MESSAGES_COL.SourceProject).AsString;
      LRec.Language      := LDS.FieldByName(MESSAGES_COL.Language).AsString;
      LRec.Name          := LDS.FieldByName(MESSAGES_COL.Name).AsString;
      LList.Add(LRec);
      LDS.Next;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
    LDS.Free;
  end;
end;

function TExceptionsMessages.ClearCache: IExceptionsMessages;
begin
  if GCache <> nil then
    GCache.Clear;
  Result := Self;
end;

function TExceptionsMessages.CacheCount: Integer;
begin
  if GCache <> nil then
    Result := GCache.Count
  else
    Result := 0;
end;

function TExceptionsMessages.Connect: IExceptionsMessages;
begin
  EnsureConnect;
  EnsureMessagesTable;
  Result := Self;
end;

function TExceptionsMessages.Connect(out ASuccess: Boolean): IExceptionsMessages;
begin
  ASuccess := False;
  try
    EnsureConnect;
    EnsureMessagesTable;
    ASuccess := (FConnection <> nil) and FConnection.IsConnected;
  except
    { A resolução de mensagens é retaguarda: não pode derrubar o chamador só
      porque o catálogo não abriu. Quem quiser saber, lê ASuccess. }
    ASuccess := False;
  end;
  Result := Self;
end;

function TExceptionsMessages.Disconnect: IExceptionsMessages;
begin
  if (FConnection <> nil) and FConnection.IsConnected then
    FConnection.Disconnect;
  Result := Self;
end;

function TExceptionsMessages.IsConnected: Boolean;
begin
  Result := (FConnection <> nil) and FConnection.IsConnected;
end;

initialization
  GCache := TMessagesCache.Create;

finalization
  GCache.Free;
  GCache := nil;

end.
