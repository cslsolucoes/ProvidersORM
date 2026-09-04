{ =============================================================================
  Database.QueryBuilder.Sychronize - Execucao assincrona do modulo Database (TORMTask<T>)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.0.0
  FileVersion:    1.2.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           01/08/2026

  Onda 6-f Estagio 2 (I11/A2) - implementacao concreta de IORMTask<T>
  (declarada em Databases.Interfaces, superficie consolidada do modulo),
  consumida por IQueryBuilder.ExecuteAsync (Database.QueryBuilder). Placement
  decidido pelo owner: no MODULO Database, unit PROPRIA (nao dentro de
  Databases.Interfaces, que so declara contratos - nem dentro de Database.
  QueryBuilder, para nao acoplar a mecanica assincrona generica a um unico
  consumidor).

  DESENHO (TThread CRU - a FPC 3.3.1 nao tem System.Threading/TTask):
  - TORMTaskWorker<T> (TThread) corre UMA VEZ a funcao de trabalho
    (TORMTaskFunc<T>, metodo "of object" - NAO "reference to function"),
    captura o RESULTADO (FResult) ou, se a funcao levantar uma excecao, a
    MENSAGEM (FErrorMsg, ClassName+': '+Message - NUNCA o objecto Exception
    original: nao existe forma segura de repassar um Exception entre
    threads/heaps em Object Pascal) e sinaliza um TEvent (SyncObjs)
    manual-reset ao terminar.
  - TORMTask<T> (TInterfacedObject, IORMTask<T>) arranca o TORMTaskWorker<T>
    no construtor (thread corre em segundo plano OFF the bat) e devolve-se a
    si proprio via o factory Run; Await bloqueia no TEvent e devolve/relanca;
    IsCompleted/IsFaulted/Error sao consulta PASSIVA (WaitFor(0), nunca
    bloqueiam nem lancam).
  - NOTA (bug-1088, FPC 3.2.2 erro de sintaxe "Identifier not found
    'reference'", fix 01/08/2026): TORMTaskFunc<T> ERA "reference to
    function: T" (closure) - o FPC 3.2.2 NAO suporta closures/anonymous
    methods de todo (recurso adicionado ao FPC so numa versao posterior, ja
    presente no 3.3.1; nem os modeswitches FUNCTIONREFERENCES/
    ANONYMOUSFUNCTIONS resolvem - o 2o nem existe como switch no 3.2.2).
    Isolado em repro minimo (3 units de poucas linhas, nao e sobre
    genericos). Substituido por metodo "of object" (Self.Execute, mesma
    assinatura function: TDataSet), universal para os 3 compiladores (nao
    so um fallback 3.2.2 - simplifica para 1 UNICO caminho de codigo,
    decisao do owner). Um metodo "of object" sozinho NAO retem a interface
    do dono viva (o campo Data e um ponteiro cru, sem refcount) - por isso
    TORMTaskWorker<T>/TORMTask<T>.Create/Run ganham o parametro explicito
    AKeepAlive: IInterface, retido pelo Worker (FKeepAlive) durante toda a
    vida da thread e libertado (:= nil) so apos sinalizar conclusao -
    recupera a MESMA protecao que a closure dava implicitamente (capturar
    LSelf: IQueryBuilder), agora EXPLICITA no parametro. Provado com
    execucao real (nao so compilacao) nos 6 alvos: objecto sobrevive a
    thread de fundo mesmo largando a referencia do caller imediatamente,
    resultado correto, destruido so no fim. Chamador unico no ecossistema
    (TQueryBuilder.ExecuteAsync, Database.QueryBuilder.pas) atualizado em
    conjunto - nenhum outro consumidor de TORMTaskFunc<T>/TORMTask<T>.Run
    existe (confirmado por grep).

  Changelog (file):
  - 1.2.0 (01/08/2026): bug-1088 (FPC 3.2.2 nao suporta "reference to
    function" - closures/anonymous methods, lacuna de linguagem real e
    permanente dessa versao, nao um ICE) - TORMTaskFunc<T> passa de
    "reference to function: T" para metodo "of object" (function: T of
    object), universal para os 3 compiladores (decisao do owner: 1 so
    caminho de codigo, nao gate por versao). TORMTaskWorker<T>.Create/
    TORMTask<T>.Create/Run ganham o parametro AKeepAlive: IInterface
    (retido pelo Worker durante a thread, libertado apos concluir) -
    recupera a protecao de refcount que a closure dava implicitamente,
    agora explicita. Provado com execucao real (nao so compilacao) nos 6
    alvos antes desta aplicacao (repro isolado em .workspace/fpc-ice-repro/
    unit-repro/). Unico consumidor (TQueryBuilder.ExecuteAsync) atualizado
    em conjunto (Database.QueryBuilder.pas).
  - 1.1.0 (27/07/2026): conformidade F5 (onda C5, B7) - TORMTaskWorker<T>
    ganha FErrorCode (captura EExceptionBase(E).ErrorCode no except, 0 senao);
    Await passa a EDatabaseAsyncException.Create(..., FWorker.FErrorCode) -
    OriginalErrorCode fica acessivel sem perder o ErrorCode 41xxxx original
    (ErrorCode da excecao relancada continua sempre ERR_DATABASE_ASYNC).
  - 1.0.1 (26/07/2026): conformidade F5 (onda C2, doc-only) - M8: nota no
    destrutor TORMTask.Destroy de que o WaitFor imediato ao largar a referencia
    sem Await degenera ExecuteAsync em execucao sincrona bloqueante. Sem mudanca
    de codigo.
  - 1.0.0 (15/07/2026): versao inicial (Onda 6-f Estagio 2, I11/A2) -
    TORMTaskFunc<T>/TORMTaskWorker<T>/TORMTask<T>.
  ============================================================================= }
unit Database.QueryBuilder.Sychronize;

{$I ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$IFDEF USE_DATABASE}

uses
{$IFDEF FPC}
  Classes, SysUtils, SyncObjs,
{$ELSE}
  System.Classes, System.SysUtils, System.SyncObjs,
{$ENDIF}
  Databases.Interfaces;

type
  { Funcao de trabalho corrida em segundo plano por TORMTask<T>.Run - metodo
    "of object" (bug-1088: NAO closure - ver comentario de topo desta unit).
    Nao retem nada vivo por si so; quem quer que o dono continue vivo
    durante a thread passa AKeepAlive a TORMTask<T>.Create/Run. }
  TORMTaskFunc<T> = function: T of object;

  { Thread de fundo CRUA (Classes.TThread) - corre TORMTaskFunc<T> UMA UNICA
    VEZ (nao reutilizavel; cada IORMTask<T> tem o seu proprio worker),
    capturando o resultado OU a mensagem de qualquer excecao levantada, e
    sinaliza ADoneEvent (propriedade do TORMTask<T> dono) ao terminar - QUER
    tenha tido sucesso QUER falhado (garante que Await nunca fica bloqueado
    para sempre). FreeOnTerminate=False - o TORMTask<T> dono controla o ciclo
    de vida (WaitFor + Free no proprio destrutor). }
  TORMTaskWorker<T> = class(TThread)
  private
    FFunc: TORMTaskFunc<T>;
    { bug-1088 - retem o dono (ex.: IQueryBuilder) vivo (refcount) durante
      toda a vida da thread; libertado (:= nil) so apos sinalizar conclusao
      em Execute. Substitui a protecao que a closure dava implicitamente. }
    FKeepAlive: IInterface;
    FResult: T;
    FFaulted: Boolean;
    FErrorMsg: string;
    { B7 (conformidade F5, onda C5) - ErrorCode ORIGINAL da excecao capturada
      (0 se a excecao nao era EExceptionBase/derivada) - preservado para
      Await poder relancar sem perder a causa (ver EDatabaseAsyncException.
      OriginalErrorCode). }
    FErrorCode: Integer;
    FDoneEvent: TEvent;
  protected
    procedure Execute; override;
  public
    constructor Create(const AFunc: TORMTaskFunc<T>; const AKeepAlive: IInterface; const ADoneEvent: TEvent);
  end;

  { Implementacao concreta de IORMTask<T> (Databases.Interfaces). }
  TORMTask<T> = class(TInterfacedObject, IORMTask<T>)
  private
    FDoneEvent: TEvent;
    FWorker: TORMTaskWorker<T>;
  public
    { bug-1088: AKeepAlive (tipicamente a interface do dono de AFunc, ex.:
      LSelf: IQueryBuilder) e retido pelo Worker durante a thread - ver
      TORMTaskWorker<T>.FKeepAlive. Passar nil se AFunc nao precisar de
      manter nada vivo (ex.: funcao livre/estatica). }
    constructor Create(const AFunc: TORMTaskFunc<T>; const AKeepAlive: IInterface);
    destructor Destroy; override;
    { Arranca AFunc numa thread de fundo e devolve IMEDIATAMENTE a tarefa
      (nao bloqueia) - ponto de entrada unico do modulo (mesmo padrao
      TQueryBuilder.New/TDatabase.New - factory class function). }
    class function Run(const AFunc: TORMTaskFunc<T>; const AKeepAlive: IInterface): IORMTask<T>;

    function Await: T;
    function IsCompleted: Boolean;
    function IsFaulted: Boolean;
    function Error: string;
  end;

{$ENDIF}

implementation

{$IFDEF USE_DATABASE}

uses
  Exceptions.Base,
  Exceptions.Database;

{ TORMTaskWorker<T> }

constructor TORMTaskWorker<T>.Create(const AFunc: TORMTaskFunc<T>; const AKeepAlive: IInterface; const ADoneEvent: TEvent);
begin
  inherited Create(True); // CreateSuspended - TORMTask<T>.Create chama .Start explicitamente
  FreeOnTerminate := False;
  FFunc := AFunc;
  FKeepAlive := AKeepAlive; // bug-1088 - retido ate Execute concluir
  FDoneEvent := ADoneEvent;
  FFaulted := False;
  FErrorMsg := '';
  FErrorCode := 0;
end;

procedure TORMTaskWorker<T>.Execute;
begin
  try
    FResult := FFunc();
  except
    on E: Exception do
    begin
      { a excecao ORIGINAL nao sobrevive ao fim deste bloco except (nem seria
        seguro repassa-la a outra thread) - preserva-se a mensagem E o
        ErrorCode (B7, conformidade F5 C5 - se a excecao for EExceptionBase/
        derivada; 0 senao), que Await embrulha numa NOVA EDatabaseAsyncException
        (ver TORMTask<T>.Await). }
      FFaulted := True;
      FErrorMsg := E.ClassName + ': ' + E.Message;
      if E is EExceptionBase then
        FErrorCode := EExceptionBase(E).ErrorCode
      else
        FErrorCode := 0;
    end;
  end;
  { sinaliza SEMPRE, sucesso ou falha - Await nunca fica bloqueado para sempre. }
  FDoneEvent.SetEvent;
  FKeepAlive := nil; // bug-1088 - liberta a referencia so apos concluir
end;

{ TORMTask<T> }

constructor TORMTask<T>.Create(const AFunc: TORMTaskFunc<T>; const AKeepAlive: IInterface);
begin
  inherited Create;
  FDoneEvent := TEvent.Create(nil, True, False, ''); // manual-reset, nao sinalizado
  FWorker := TORMTaskWorker<T>.Create(AFunc, AKeepAlive, FDoneEvent);
  FWorker.Start; // arranca AGORA - ExecuteAsync devolve sem bloquear
end;

destructor TORMTask<T>.Destroy;
begin
  { Se o caller nunca chamou Await (largou a referencia IORMTask<T> cedo
    demais), esperamos aqui a thread terminar antes de libertar FWorker -
    evita libertar o TThread enquanto ainda corre. Em uso normal (Await
    chamado antes de largar a referencia) a tarefa ja terminou e WaitFor
    devolve de imediato. GOTCHA (M8, conformidade F5 C2): por isso, DESCARTAR o
    resultado de ExecuteAsync sem o capturar degenera em execucao SINCRONA
    BLOQUEANTE - este WaitFor corre no Destroy imediato. Capturar sempre a
    IORMTask ate Await. }
  FWorker.WaitFor;
  FWorker.Free;
  FDoneEvent.Free;
  inherited Destroy;
end;

class function TORMTask<T>.Run(const AFunc: TORMTaskFunc<T>; const AKeepAlive: IInterface): IORMTask<T>;
begin
  Result := TORMTask<T>.Create(AFunc, AKeepAlive);
end;

function TORMTask<T>.Await: T;
begin
  FDoneEvent.WaitFor(INFINITE);
  if FWorker.FFaulted then
    { B7 (conformidade F5, onda C5) - OriginalErrorCode preserva o codigo 41xxxx
      da excecao original (0 se nao era EExceptionBase); o ErrorCode desta
      excecao continua SEMPRE ERR_DATABASE_ASYNC (sinaliza "veio do Await"). }
    raise EDatabaseAsyncException.Create(FWorker.FErrorMsg, ERR_DATABASE_ASYNC, FWorker.FErrorCode)
  else
    Result := FWorker.FResult;
end;

function TORMTask<T>.IsCompleted: Boolean;
begin
  Result := FDoneEvent.WaitFor(0) = wrSignaled;
end;

function TORMTask<T>.IsFaulted: Boolean;
begin
  Result := IsCompleted and FWorker.FFaulted;
end;

function TORMTask<T>.Error: string;
begin
  if IsCompleted then
    Result := FWorker.FErrorMsg
  else
    Result := '';
end;

{$ENDIF}

end.
