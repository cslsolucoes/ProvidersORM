{ =============================================================================
  Database.UnitOfWork - Unit of Work (TUnitOfWork, IUnitOfWork)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.0.0
  FileVersion:    1.5.0
  Author:         Claiton de Souza Linhares
  Date:           26/02/2026

  Changelog (file):
  - 1.5.0 (15/07/2026): Onda 7 (camada de lancadores fluentes) - removido o
    `uses Database.Table` do INTERFACE (morto: grep confirmou zero uso de
    `TTable.` neste ficheiro fora de comentario - o parametro `ATable: ITable`
    de RegisterNew/Dirty/Deleted ja vem de Databases.Interfaces, ja presente
    no uses). Cleanup necessario para ITable.UnitOfWork (Databases.Interfaces
    2.11.0) poder chamar `Database.UnitOfWork.TUnitOfWork.New` diretamente de
    Database.Table.pas sem ciclo de unit (Database.UnitOfWork.pas `uses
    Database.Table` + Database.Table.pas `uses Database.UnitOfWork` seria
    circular). Zero mudanca de comportamento (import nao usado).
  - 1.4.0 (14/07/2026): Passo 4 Fatia C (continuacao Onda 4, revisao F5) -
    alinhamento Commit <-> ITable.Status/Execute (aditivo, decisao (b) do
    plano). RegisterNew/RegisterDirty/RegisterDeleted passam a SETAR o Status
    (TRowStatus) correto na ITable registada (dsInsert/dsEdit/dsDeleted, alem
    de propagar FConnection ja feito na Fatia A) - a intencao declarada pela
    lista de destino (New/Dirty/Deleted) fica explicita no proprio registo,
    em vez de depender da inferencia por PK que o overload sem-Status do
    Execute usa (essa inferencia so distingue Insert/Update; nao existe
    inferencia de Delete, por isso o Status tem de ser setado explicitamente
    para o caminho dsDeleted funcionar). Commit deixa de compor SQL
    manualmente (InsertSQL/UpdateSQL/WhereByPrimaryKey/DeleteSQL/
    EnsureSafeDML) e passa a chamar LTable.Execute(FConnection) para cada
    item das 3 listas - UNICO caminho DML, o mesmo que TEntityManager.Save ja
    usa (Database.EntityManager.pas 1.2.0, Onda 4.2) - dentro da MESMA
    transacao (BeginTransaction/Commit/Rollback, inalterada). Execute ja
    despacha por Status, infere PK quando dsInactive, aplica a guarda
    EnsureSafeDML internamente (via ExecuteUpdate/ExecuteDelete) e reseta o
    Status para dsInactive apos gravar com sucesso - Commit fica mais fino e
    sem duplicacao de logica com o EntityManager. Zero mudanca na API publica
    (RegisterNew/Dirty/Deleted/PendingCount/HasPending/Commit/Rollback
    inalterados); zero mudanca de comportamento observavel em SQL gerado
    (mesmos InsertSQL/UpdateSQL/WhereByPrimaryKey/DeleteSQL/EnsureSafeDML,
    agora invocados de dentro do Execute em vez de directamente no Commit).
  - 1.3.0 (13/07/2026): Fatia A (continuacao Onda 4, revisao F5) - aditivo/leve:
    RegisterNew/RegisterDirty/RegisterDeleted passam a propagar FConnection
    (se ja setada) para a ITable registada via Connection(v), deixando-a apta
    a ITable.Execute mesmo fora do Commit. Zero mudanca na semantica do
    Commit (continua a gerar/executar SQL diretamente via FConnection, sem
    depender de ITable.Execute/Connection).
  - 1.2.0 (13/07/2026): Commit atualizado para a API fundida de Database.Table
    (ordem do owner) - GenerateInsertSQL -> LTable.InsertSQL (default
    Optimized=True); GenerateUpdateSQLOptimized -> LTable.UpdateSQL (default
    Optimized=True, continua dinamico so campos IsChanged); GenerateDeleteSQL ->
    LTable.DeleteSQL (default Optimized=True); GenerateWhereByPrimaryKey ->
    LTable.WhereByPrimaryKey. Zero mudanca de comportamento (so os nomes).
  - 1.1.0 (13/07/2026): absorcao v3 (FASE 5 Onda 3) - ProjectVersion 3.0.0, ModuleVersion 1.7.0; uses Providers.Connection.Interfaces -> Connections.Interfaces; + PendingCount/HasPending (modernizacao aditiva); Commit corrige duplicacao de WHERE em UPDATE/DELETE - GenerateUpdateSQL/GenerateDeleteSQL v3 ja incluem GenerateWhereByPrimaryKey internamente, a concatenacao extra do legado gerava SQL invalido (bug-232).
  - 1.0.0 (26/02/2026): TUnitOfWork com listas New/Dirty/Deleted (ITable); Connection fluente; Commit (transação + Insert/Update/Delete + clear); Rollback (Fase 3).
  ============================================================================= }

unit Database.UnitOfWork;


{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}
interface

{$I ../../../ORM.Defines.inc}

uses
{$IF DEFINED(FPC)}
  SysUtils, Classes, Generics.Collections,
{$ELSE}
  System.SysUtils, System.Classes, System.Generics.Collections,
{$ENDIF}
  Commons.Database.Types,
  Databases.Interfaces,
  Connections.Interfaces;

type
  TUnitOfWork = class(TInterfacedObject, IUnitOfWork)
  private
    FConnection: IConnection;
    FNewList: TList<ITable>;
    FDirtyList: TList<ITable>;
    FDeletedList: TList<ITable>;
    procedure ClearLists;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: IUnitOfWork;

    function Connection(const AConnection: IConnection): IUnitOfWork; overload;
    function Connection: IConnection; overload;

    function RegisterNew(const ATable: ITable): IUnitOfWork;
    function RegisterDirty(const ATable: ITable): IUnitOfWork;
    function RegisterDeleted(const ATable: ITable): IUnitOfWork;

    function PendingCount: Integer;
    function HasPending: Boolean;

    procedure Commit;
    procedure Rollback;
  end;

implementation

constructor TUnitOfWork.Create;
begin
  inherited Create;
  FNewList := TList<ITable>.Create;
  FDirtyList := TList<ITable>.Create;
  FDeletedList := TList<ITable>.Create;
end;

destructor TUnitOfWork.Destroy;
begin
  ClearLists;
  FNewList.Free;
  FDirtyList.Free;
  FDeletedList.Free;
  inherited;
end;

class function TUnitOfWork.New: IUnitOfWork;
begin
  Result := TUnitOfWork.Create;
end;

procedure TUnitOfWork.ClearLists;
begin
  FNewList.Clear;
  FDirtyList.Clear;
  FDeletedList.Clear;
end;

function TUnitOfWork.Connection(const AConnection: IConnection): IUnitOfWork;
begin
  FConnection := AConnection;
  Result := Self;
end;

function TUnitOfWork.Connection: IConnection;
begin
  Result := FConnection;
end;

function TUnitOfWork.RegisterNew(const ATable: ITable): IUnitOfWork;
begin
  if (ATable <> nil) and (FNewList.IndexOf(ATable) < 0) then
  begin
    FNewList.Add(ATable);
    { Fatia C (continuacao Onda 4) - seta o Status (TRowStatus) conforme a
      lista de destino, para que Commit possa despachar via ITable.Execute
      (dsInsert -> ExecuteInsert). A intencao declarada pelo Register* fica
      explicita no proprio registo. }
    ATable.Status(dsInsert);
    { Fatia A (continuacao Onda 4) - aditivo/leve: propaga a conexao do UoW
      para a tabela registada, para que ITable.Execute (fora do Commit) tambem
      funcione sem parametro. }
    if FConnection <> nil then
      ATable.Connection(FConnection);
  end;
  Result := Self;
end;

function TUnitOfWork.RegisterDirty(const ATable: ITable): IUnitOfWork;
begin
  if (ATable <> nil) and (FDirtyList.IndexOf(ATable) < 0) then
  begin
    FDirtyList.Add(ATable);
    { Fatia C - dsEdit -> ExecuteUpdate (dinamico, so campos IsChanged) no
      despacho de Execute. }
    ATable.Status(dsEdit);
    if FConnection <> nil then
      ATable.Connection(FConnection);
  end;
  Result := Self;
end;

function TUnitOfWork.RegisterDeleted(const ATable: ITable): IUnitOfWork;
begin
  if (ATable <> nil) and (FDeletedList.IndexOf(ATable) < 0) then
  begin
    FDeletedList.Add(ATable);
    { Fatia C - dsDeleted -> ExecuteDelete. Sem este Status explicito, o
      despacho de Execute (ramo dsInactive) so infere Insert/Update pela PK -
      NAO ha inferencia de Delete - por isso setar o Status aqui e
      obrigatorio para o caminho de remocao funcionar via Execute. }
    ATable.Status(dsDeleted);
    if FConnection <> nil then
      ATable.Connection(FConnection);
  end;
  Result := Self;
end;

function TUnitOfWork.PendingCount: Integer;
begin
  Result := FNewList.Count + FDirtyList.Count + FDeletedList.Count;
end;

function TUnitOfWork.HasPending: Boolean;
begin
  Result := PendingCount > 0;
end;

procedure TUnitOfWork.Commit;
var
  i: Integer;
begin
  { Fatia C (continuacao Onda 4, revisao F5) - despacho UNICO via
    ITable.Execute(FConnection), o mesmo caminho ja usado por
    TEntityManager.Save (Database.EntityManager.pas 1.2.0). Execute despacha
    por Status (dsInsert/dsEdit/dsDeleted - setado pelo Register* respectivo,
    Fatia C) chamando ExecuteInsert/ExecuteUpdate/ExecuteDelete internamente;
    estes ja compoem o WHERE por PK (design composable) e aplicam a guarda
    TTable.EnsureSafeDML antes de qualquer UPDATE/DELETE - nada disso precisa
    de ser repetido aqui. Execute tambem reseta o Status para dsInactive apos
    gravar com sucesso. Tudo dentro da MESMA transacao (inalterada). }
  if FConnection = nil then
    Exit;
  try
    FConnection.BeginTransaction;
    try
      for i := 0 to FNewList.Count - 1 do
        FNewList[i].Execute(FConnection);
      for i := 0 to FDirtyList.Count - 1 do
        FDirtyList[i].Execute(FConnection);
      for i := 0 to FDeletedList.Count - 1 do
        FDeletedList[i].Execute(FConnection);
      FConnection.Commit;
      ClearLists;
    except
      FConnection.Rollback;
      raise;
    end;
  finally
    { transação já commitada ou rollback }
  end;
end;

procedure TUnitOfWork.Rollback;
begin
  ClearLists;
  if (FConnection <> nil) and FConnection.InTransaction then
    FConnection.Rollback;
end;

end.
