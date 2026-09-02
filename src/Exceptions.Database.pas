{ =============================================================================
  Exceptions.Database - Excecoes do modulo Database (faixa MM=41)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.8.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           27/07/2026

  FASE 5 (placement por peca: excecao -> Exceptions/Exceptions.<Modulo>).
  Faixa 41 (ERR_DATABASE_BASE=410000); offsets reservados pelo plano F5:
  Table DML +03..+06 · Metadata +10 · EntityManager +70 · QueryBuilder +80 ·
  IdentityMap +90 · UnitOfWork +91 · TypeDatabase +92 · Async +95 (Onda 6-f
  Estagio 2). Todas herdam EExceptionBase (ErrorCode na raiz - regra v3;
  nunca lancar Exception cru).

  Changelog (file):
  - 1.8.0 (27/07/2026): conformidade F5 (onda C5, B7) - EDatabaseAsyncException
    ganha OriginalErrorCode: Integer (default 0, overload aditivo com 3o
    parametro opcional - ZERO call site pre-existente muda) - preserva o
    ErrorCode 41xxxx da excecao original capturada na thread de fundo
    (TORMTask<T>.Await continua a relancar sempre com ERR_DATABASE_ASYNC,
    mas agora com a causa original acessivel sem parsear a mensagem).
  - 1.7.0 (15/07/2026): Onda 6-f Estagio 2 (I11/A2, ADITIVO) -
    ERR_DATABASE_ASYNC (410095) + EDatabaseAsyncException - excecao capturada
    numa THREAD DE FUNDO (Database.QueryBuilder.Sychronize.TORMTask<T>, consumida por
    IQueryBuilder.ExecuteAsync) e RELANCADA por IORMTask<T>.Await; a MENSAGEM
    embrulhada e ClassName+': '+Message da excecao ORIGINAL (nao e seguro
    repassar o proprio objecto Exception entre threads em Object Pascal).
  - 1.6.0 (15/07/2026): Onda 6-e Estagio 4 (F5 revisao, A3, ADITIVO) -
    EDatabaseException (e TODAS as subclasses da faixa 41, por heranca, sem
    reintroducao) ganha SQLContext: string (padrao '' - o mesmo padrao de
    EConnectionException.Operation em Exceptions.Base: um novo overload de
    Create com 3o parametro OPCIONAL, o 2-arg Create(AMessage, AErrorCode)
    pre-existente continua a resolver contra este overload com SQLContext=''
    por omissao - ZERO call site pre-existente precisa de mudar). Uso inicial:
    TTable.EnsureSafeDML (Database.Table.pas) passa a incluir o SQL bloqueado
    em EDatabaseUnsafeDMLException.SQLContext (mensagem/ErrorCode inalterados).
  - 1.5.0 (15/07/2026): + ERR_DATABASE_QB_UNKNOWN_OP (410081) (Onda 6-e
    Estagio 3, I19 - operadores semanticos) - IQueryBuilder.WhereOp recebe um
    nome semantico ('eq'/'neq'/'contains'/'startsWith'/'endsWith'/'gt'/'ge'/
    'lt'/'le') nao reconhecido; reusa EDatabaseQueryBuilderException (mesma
    classe da faixa +80).
  - 1.4.0 (15/07/2026): + ERR_DATABASE_METADATA_FILE (410011) (Onda 6-d, I6 -
    snapshot offline) - falha de E/S em IMetadata.SaveToFile/LoadFromFile
    (ficheiro nao encontrado, escrita falhou); reusa EDatabaseMetadataException.
  - 1.3.0 (14/07/2026): + ERR_DATABASE_VALIDATION (410004)/EDatabaseValidationException
    + ERR_DATABASE_READONLY (410005)/EDatabaseReadOnlyException + ERR_DATABASE_INVALID_STATUS
    (410006)/EDatabaseInvalidStatusException (Sub-passo 4.5, continuacao Onda 4, revisao F5) -
    validacao no save (obrigatorios em falta) + guardas read-only/soft-deleted (equiv.
    FDeletedBlock v1.6.1) + status invalido (dsEdit/dsDeleted sem PK) em TTable.Execute.
  - 1.2.0 (13/07/2026): + ERR_DATABASE_ENTITYMANAGER (410070) + EDatabaseEntityManagerException
    (Onda 4, revisao F5) - absorcao do EntityManager; a fonte legada reservava a faixa
    70XXX (pre-norma, nunca usada) - integrada na faixa 41 canonica do projeto.
  - 1.1.0 (13/07/2026): + ERR_DATABASE_UNSAFE_DML (410003) + EDatabaseUnsafeDMLException
    (Onda 3, revisao F5) - guarda contra UPDATE/DELETE sem WHERE antes de executar.
  - 1.0.0 (12/07/2026): versao inicial (FASE 5 Onda 5.1) - base + metadata.
  ============================================================================= }
unit Exceptions.Database;

{$I ../ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$IFDEF USE_DATABASE}

uses
  Exceptions.Base;

const
  ERR_DATABASE_BASE           = 410000;
  ERR_DATABASE_NO_CONNECTION  = 410001; // provider/builder sem IConnection injectada
  ERR_DATABASE_INVALID_NAME   = 410002; // tabela/coluna/schema vazio ou invalido
  ERR_DATABASE_UNSAFE_DML     = 410003; // Table DML: UPDATE/DELETE sem WHERE bloqueado antes de executar
  { Sub-passo 4.5 (validacao no save + guardas read-only) }
  ERR_DATABASE_VALIDATION     = 410004; // Table DML: obrigatorio(s) em falta no INSERT/UPDATE (Execute/Save)
  ERR_DATABASE_READONLY       = 410005; // Table DML: guarda read-only/soft-deleted (equiv. FDeletedBlock v1.6.1)
  ERR_DATABASE_INVALID_STATUS = 410006; // Table DML: Status (dsEdit/dsDeleted) sem PK preenchida
  { Metadata (Onda 5.1) }
  ERR_DATABASE_METADATA       = 410010; // falha generica ao ler o catalogo
  ERR_DATABASE_METADATA_FILE  = 410011; // Onda 6-d (I6): falha de E/S do snapshot (SaveToFile/LoadFromFile)
  { Dialectos (Onda 5.2) }
  ERR_DATABASE_DIALECT        = 410020; // banco sem dialecto registado
  ERR_DATABASE_OPERATOR       = 410021; // operador nao registado no dialecto
  ERR_DATABASE_OPERATOR_ARITY = 410022; // nr de operandos errado
  ERR_DATABASE_PAGINATION     = 410023; // paginacao nao suportada
  { QueryBuilder (Onda 5.3) - offset +80 }
  ERR_DATABASE_QUERYBUILDER   = 410080; // estado invalido do builder (falta tabela/colunas/valores)
  ERR_DATABASE_QB_UNKNOWN_OP  = 410081; // Onda 6-e Estagio 3 (I19): WhereOp com nome semantico desconhecido
  { QueryTransformer (Onda 5.4) - offset +85 }
  ERR_DATABASE_TRANSFORMER    = 410085; // estado invalido do transformer (sem source)
  { SchemaSync (Onda 5.5) - offset +86 }
  ERR_DATABASE_SCHEMA         = 410086; // falha de definicao/migracao de esquema
  { EntityManager (Onda 4, revisao F5) - offset +70 }
  ERR_DATABASE_ENTITYMANAGER  = 410070; // falha generica do EntityManager (fonte legada reservava 70XXX pre-norma)
  { Async (Onda 6-f Estagio 2, I11/A2) - offset +95 }
  ERR_DATABASE_ASYNC          = 410095; // excecao capturada na thread de fundo, relancada por IORMTask<T>.Await
  { Ferramentas de controlo DDL (F5-FU.3 anti-hang + R2-B verificacao pos-DDL) }
  ERR_DATABASE_OBJECT_LOCKED       = 410030; // F5-FU.3: DDL abortado por lock (NO WAIT) em vez de pendurar - EDatabaseObjectLockedException
  ERR_DATABASE_SCHEMA_VERIFICATION = 410031; // R2-B: shape vivo != pretendido apos Sync (DDL nao produziu o resultado) - EDatabaseSchemaVerificationException

type
  { Onda 6-e Estagio 4 (A3) - SQLContext: string opcional (default '') com o
    SQL/contexto que originou a excecao (ex.: EnsureSafeDML passa o SQL
    bloqueado). Mesma tecnica de EConnectionException.Operation
    (Exceptions.Base): 1 unico overload de Create com o novo parametro
    OPCIONAL cobre tambem as chamadas de 2 argumentos pre-existentes
    (AErrorCode, string) - nenhum call site precisa de mudar. Todas as
    subclasses da faixa 41 herdam SQLContext automaticamente (sem
    reintroducao de Create - mesmo padrao de ErrorCode na base EExceptionBase). }
  EDatabaseException = class(EExceptionBase)
  private
    FSQLContext: string;
  public
    constructor Create(const AMessage: string); overload;
    constructor Create(const AMessage: string; const AErrorCode: Integer;
      const ASQLContext: string = ''); overload;
    property SQLContext: string read FSQLContext;
  end;
  EDatabaseUnsafeDMLException = class(EDatabaseException);
  EDatabaseValidationException = class(EDatabaseException);
  EDatabaseReadOnlyException = class(EDatabaseException);
  EDatabaseInvalidStatusException = class(EDatabaseException);
  EDatabaseMetadataException = class(EDatabaseException);
  EDatabaseDialectException = class(EDatabaseException);
  EDatabaseQueryBuilderException = class(EDatabaseException);
  EDatabaseTransformerException = class(EDatabaseException);
  EDatabaseSchemaException = class(EDatabaseException);
  EDatabaseEntityManagerException = class(EDatabaseException);
  { Onda C5 (B7, conformidade F5) - AOriginalErrorCode (default 0) preserva o
    ErrorCode da excecao ORIGINAL capturada na thread de fundo (mesmo padrao
    de EDatabaseException.SQLContext, acima: 1 overload novo com 3o parametro
    OPCIONAL cobre tambem o Create(AMessage, AErrorCode) de 2 argumentos
    pre-existente - ZERO call site precisa mudar). O ErrorCode desta excecao
    continua SEMPRE ERR_DATABASE_ASYNC (410095, sinaliza "veio do Await");
    OriginalErrorCode e o codigo 41xxxx da excecao que a thread de fundo
    levantou (0 se nao era EExceptionBase/EExceptionBase-derivada). }
  EDatabaseAsyncException = class(EDatabaseException)
  private
    FOriginalErrorCode: Integer;
  public
    constructor Create(const AMessage: string); overload;
    constructor Create(const AMessage: string; const AErrorCode: Integer;
      const AOriginalErrorCode: Integer = 0); overload;
    property OriginalErrorCode: Integer read FOriginalErrorCode;
  end;
  { F5-FU.3 - DDL Firebird em NO WAIT: lock detetado -> falha rapida catchable
    (em vez de pendurar); mensagem inclui o objecto alvo, SQLContext = DDL. }
  EDatabaseObjectLockedException = class(EDatabaseException);
  { R2-B - verificacao pos-DDL: o shape VIVO (catalogo) diverge do pretendido
    (ISchemaDefinition) apos Sync - o DDL "executou" mas nao produziu o alvo. }
  EDatabaseSchemaVerificationException = class(EDatabaseException);

{$ENDIF}

implementation

{$IFDEF USE_DATABASE}

constructor EDatabaseException.Create(const AMessage: string);
begin
  inherited Create(AMessage);
  FSQLContext := '';
end;

constructor EDatabaseException.Create(const AMessage: string; const AErrorCode: Integer;
  const ASQLContext: string);
begin
  inherited Create(AMessage, AErrorCode);
  FSQLContext := ASQLContext;
end;

constructor EDatabaseAsyncException.Create(const AMessage: string);
begin
  inherited Create(AMessage);
  FOriginalErrorCode := 0;
end;

constructor EDatabaseAsyncException.Create(const AMessage: string; const AErrorCode: Integer;
  const AOriginalErrorCode: Integer);
begin
  inherited Create(AMessage, AErrorCode);
  FOriginalErrorCode := AOriginalErrorCode;
end;

{$ENDIF}

end.
