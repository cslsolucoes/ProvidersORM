{ =============================================================================
  Database.Synchronize - Motor de versionamento de esquema (ex-SchemaSync) - Onda 5.5

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.0.0
  FileVersion:    2.7.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           30/07/2026

  FASE 5 Onda 5.5 - NUCLEO (greenfield). Reusa o ICatalogReader (5.1) para o
  estado REAL e o IDialect (5.2) para gerar o DDL (ColumnTypeFor/quoting) por
  banco. O Migrator aplica CREATE TABLE + ADD COLUMN em TRANSACCAO, regista em
  schema_version (bindado) e e IDEMPOTENTE (a comparacao usa um metadata provider
  fresco a cada Sync; o kernel invalida o cache pos-DDL - bug-167). PK simples
  (embutida em SQLite via ckIdentity; senao clausula PRIMARY KEY). PK-composta/
  FK/indices/views/recreate-table SQLite -> onda 5.5-B.

  Changelog (file):
  - 2.7.0 (30/07/2026): bug-foreignkey-schema-version (test_foreignkey.dpr,
    UniDAC x fpc64 x sqlanywhere - crash 5/5, "EUniError: Item 'schema_version'
    already exists" nao tratado) - achado colateral do bug-983, nunca corrigido
    ate agora: EnsureVersionTable tornado IDEMPOTENTE e ROBUSTO - (1) a deteccao
    de existencia (TableExists) fica protegida por try/except proprio (se
    falhar por qualquer motivo, assume EXISTS=True - conservador, nao arrisca
    recriar); (2) o CREATE TABLE mantem-se protegido por um try/except externo
    que tolera qualquer falha pontual (a mais comum sendo "already exists" por
    falso-negativo de TableExists - mesma familia bug-983/988/1000). Nunca mais
    aborta o Sync do chamador por causa do bookkeeping de schema_version (best-
    effort, so' consumido por LogMigration). Validado: 5x test_foreignkey.dpr
    (fpc64/UniDAC x sqlanywhere) = 0 crash (era 5/5 crash determinístico).
  - 2.6.0 (30/07/2026): auditoria adversarial ao ApplyStructure (Database.
    Schema.pas) - 2 fixes ADITIVOS neste ficheiro: (a) fix #2 - ISchemaColumn
    ganha Scale (TSchemaColumn.FScale/constructor/getter) e ISchemaTable.
    AddColumn ganha AScale: Integer = 0 (default, nenhuma quebra de call-site);
    BuildCreateTable/BuildAddColumn (TSchemaComparer) passam a repassar
    LCols[I].Scale/ACol.Scale a ADialect.ColumnTypeFor - antes so' Size era
    repassado, o que materializava sempre DECIMAL(p,0) para colunas DECIMAL/
    NUMERIC com escala real (a escala vive em IField.Precision/Scale, nao em
    Size - ver Database.Field.ParseColumnTypeDimensions); (b) fix #6 -
    CommitResidualSQLAnywhere ganha o gate "FConn.InTransaction" (skip se
    True) - o COMMIT cru SQL Anywhere corria incondicionalmente e podia
    terminar uma transaccao EXPLICITA do consumidor na mesma ligacao; mesmo
    padrao ja usado no COMMIT pos-ExecuteQuery de Connections.pas (gated
    "not FInTransaction"). Zero mudanca de comportamento no fluxo normal
    (Sync sem transaccao externa: InTransaction=False neste ponto, ver
    TSynchronize.Sync). Ambos os achados da auditoria adversarial pedida
    pelo owner sobre ApplyStructure (ver Database.Schema.pas 1.10.0 para o
    fix #1(CRITICO)/#3, o isolamento por-passo do ApplyStructure em si).
  - 2.5.0 (30/07/2026): bug-986 (test_catalogreader.dpr, UniDAC x fpc32 x
    sqlanywhere - FAIL em "TableNames contem zzz_cat" apos TSynchronize.Sync
    criar a tabela, na MESMA ligacao) - MESMA raiz do bug-983 (transaccao
    IMPLICITA residual do INSERT de LogMigration, nunca fechada de forma
    fiavel via TConnection.Commit/ExecuteCommand parametrizado no SQL
    Anywhere/UniDAC), mas o fix anterior (COMMIT dentro de VerifyShape,
    onda C7) so beneficiava a PROPRIA verificacao interna do Sync - qualquer
    consumidor EXTERNO que reutilizasse a mesma ligacao a seguir (ex.:
    ICatalogReader.TableNames chamado directamente pelo caller) podia ainda
    encontrar a ligacao suja. FIX DE RAIZ: o COMMIT (SQL cru, SO
    dtSQLAnywhere) mudou-se de VerifyShape para Sync - novo metodo privado
    CommitResidualSQLAnywhere, chamado logo apos LogMigration,
    INCONDICIONALMENTE (mesmo com VerifyAfterSync(False), que antes deixava
    a ligacao suja). VerifyShape deixa de repetir o COMMIT (agora redundante
    - a ligacao ja chega limpa), mantendo so o retry de defesa em
    profundidade. Diagnostico A/B (git stash de Synchronize+Connections,
    fpc32/UniDAC x sqlanywhere real): o FAIL reportado NAO reproduziu em
    execucao isolada de test_catalogreader.exe (14 corridas pre-fix + 4
    pos-fix = 18/18 0 FAIL) - indicio de que a manifestacao original exigia
    o contexto da matriz/suite completa (muitas ligacoes sequenciais no
    mesmo servidor partilhado), nao reproduzida aqui isoladamente; o fix de
    raiz endurece um gap estrutural REAL e ja confirmado (bug-983),
    aplicado por prudencia e por ser a arquitectura correcta independente da
    reproducao. Validado: test_catalogreader 3x dcc32 + 3x fpc32 x
    sqlanywhere = 0 FAIL; test_serialize 3x dcc32 + 3x fpc32 x sqlanywhere =
    0 FAIL (sem regressao); postgresql/sqlite sem regressao; 4 alvos
    ProvidersV3 EXIT=0.
  - 2.4.0 (30/07/2026): fix do FAIL intermitente em test_serialize.dpr (UniDAC
    x fpc32 x sqlanywhere - EDatabaseSchemaVerificationException "verificacao
    pos-DDL falhou" com o DDL fisicamente aplicado). Hipotese inicial (latencia
    de catalogo do SQL Anywhere sob carga, mitigada so' com Sleep+retry) foi
    INVESTIGADA E REFUTADA empiricamente (spike dedicado, servidor real): ate
    12 tentativas de 1000ms (12s) na MESMA ligacao NUNCA resolveram, enquanto
    uma 2a ligacao aberta no MESMO PROCESSO via o estado correcto de imediato,
    sem qualquer espera - prova que nao e' uma questao de tempo, e' a ligacao
    FConn ficar presa. ROOT CAUSE real: LogMigration executa um INSERT em
    schema_version via ExecuteCommand DEPOIS do Commit do loop de DDL, sem
    fechar essa escrita - no SQL Anywhere (UniDAC) isto abre uma transaccao
    IMPLICITA nesta ligacao que fica por commitar (o proprio Commit() do
    TConnection e' no-op aqui - so actua com FInTransaction=True, e essa flag
    ja foi baixada pelo Commit do DDL), presando as leituras seguintes NESTA
    ligacao a uma vista que nao reflecte o DDL. Fix: VerifyShape ganhou a
    funcao auxiliar HardResidual (extraida, mesmo filtro sckCreateTable/
    sckAddColumn de sempre) e, SO para FConn.DatabaseType=dtSQLAnywhere,
    fecha essa transaccao residual com um "COMMIT" em SQL cru (bypassa o
    bookkeeping FInTransaction) ANTES da 1a leitura do catalogo; um retry
    curto (3x300ms) fica como rede de seguranca adicional (defesa em
    profundidade, nao a mitigacao principal). Gated ao motor: zero mudanca de
    comportamento nos restantes engines (deteccao de falha genuina intacta).
    Validado: dcc32/dcc64 UniDAC + fpc32/fpc64 Zeos EXIT=0 (gate 4/4); 3x
    dcc32/UniDAC e 3x fpc32/UniDAC contra sqlanywhere real = 0 FAIL
    deterministico; postgresql/sqlite sem regressao.
  - 2.3.0 (27/07/2026): conformidade F5 (onda C6, M4) - Sync fica
    ENGINE-AWARE: deixa de abrir BeginTransaction/Commit/Rollback quando
    FConn.DatabaseType=dtMySQL (MySQL/MariaDB fazem implicit commit por
    statement DDL - a transacao era uma falsa promessa de atomicidade,
    corrigindo em vez de so documentar). Os restantes engines mantem o
    comportamento transacional original; VerifyShape continua a rede de
    seguranca real nos 2 ramos.
  - 2.2.0 (27/07/2026): conformidade F5 (onda C5, B4) - TENTADO E REVERTIDO
    (doc-only no resultado final). Implementada uma 2a confirmacao de
    sckAddUnique/sckCreateIndex via ICatalogReader.UniqueExists/IndexExists
    antes de VerifyShape escalar a hard failure - REPRODUZIU o falso-positivo
    em `smoke_parameters_db` real (Zeos+SQLite: introspecao nao viu o UNIQUE
    "parameters_bak.ChaveUnica" imediatamente apos o DDL, na mesma ligacao).
    Revertido ao comportamento original (ignorar estes 2 kinds); comentario do
    metodo ampliado com a prova empirica de que a cautela original e correta.
    Nenhuma mudanca de comportamento no ficheiro final.
  - 2.1.1 (26/07/2026): conformidade F5 (onda C4) - B5 (doc-only): documentado no
    TSchemaInspector.Meta que o FMeta e cache reutilizado (OK no fluxo Sync -
    Compare/EnsureVersionTable ja usam readers frescos, bug-167) e que um
    consumidor EXTERNO deve invalidar via Meta.Refresh ou re-setar Connection
    apos DDL externo. ModuleVersion 3.0.0 (onda C1).
  - 2.1.0 (16/07/2026): Onda 5.5-B (indices/constraints, ADITIVO) - o SchemaSync
    passa a suportar constraints UNIQUE compostas e indices. ISchemaTable ganha
    AddUnique(cols,name)/AddIndex(cols,name,unique) + Uniques/Indexes; Compare
    emite sckAddUnique/sckCreateIndex (statement SEPARADO com nome
    DETERMINISTICO - NAO inline, para o SQLite nao gerar sqlite_autoindex e a
    idempotencia por nome funcionar uniformemente entre engines); BuildAddUnique/
    BuildCreateIndex delegam a IDialect.AddUniqueSQL/CreateIndexSQL; idempotencia
    via ICatalogReader.UniqueExists/IndexExists. TSchemaChange ganha campo Name.
    Resolve o item "indices" da nota de cabecalho (antes adiado). Pre-requisito
    da FASE 7 (Parameters - chave unica composta).
  - 2.0.0 (14/07/2026): Reorg 2 (owner) - unit renomeada Database.SchemaSync ->
    Database.Synchronize (pasta SchemaSync/ -> Synchronize/); factory renomeada
    TDatabase.SchemaSync -> TDatabase.Synchronize. Classes/interfaces do dominio
    (TSchema*/ISchema*) INALTERADAS (descrevem objectos de esquema, nao a
    operacao). ISchema* ja consolidadas em Databases.Interfaces (Reorg 1).
  - 1.1.0 (14/07/2026): renomeacao mecanica IMetadataProvider -> ICatalogReader /
    TMetadataProvider -> TCatalogReader.
  - 1.0.0 (12/07/2026): versao inicial (Onda 5.5 - nucleo).
  ============================================================================= }
unit Database.Synchronize;

{$I ../../../ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$IFDEF USE_DATABASE}

uses
{$IFDEF FPC}
  SysUtils, Classes, Variants, Generics.Collections,
{$ELSE}
  System.SysUtils, System.Classes, System.Variants, System.Generics.Collections,
{$ENDIF}
  Commons.Types,
  Commons.Database.Types,
  Connections.Interfaces,
  Databases.Interfaces,
  Database.CatalogReader; // F5-FU.2 - ICatalogReader (TSchemaInspector.FMeta, seccao interface)

type
  TSchemaColumn = class(TInterfacedObject, ISchemaColumn)
  private
    FName     : string;
    FKind     : TSQLColumnKind;
    FSize     : Integer;
    FScale    : Integer;   // fix #2 (auditoria) - escala DECIMAL/NUMERIC, ver ISchemaColumn.Scale
    FNullable : Boolean;
    FPK       : Boolean;
  public
    constructor Create(const AName: string; const AKind: TSQLColumnKind;
      const ASize: Integer; const ANullable, APK: Boolean; const AScale: Integer = 0);
    function ColumnName: string;
    function Kind: TSQLColumnKind;
    function Size: Integer;
    function Scale: Integer;
    function IsNullable: Boolean;
    function IsPrimaryKey: Boolean;
  end;

  TSchemaTable = class(TInterfacedObject, ISchemaTable)
  private
    FName    : string;
    FCols    : TList<ISchemaColumn>;
    FUniques : TSchemaUniques;   // Onda 5.5-B
    FIndexes : TSchemaIndexes;   // Onda 5.5-B
  public
    constructor Create(const AName: string);
    destructor Destroy; override;
    function TableName: string;
    function AddColumn(const AName: string; const AKind: TSQLColumnKind;
      const ASize: Integer = 0; const ANullable: Boolean = True;
      const APrimaryKey: Boolean = False; const AScale: Integer = 0): ISchemaTable;
    function Columns: TArray<ISchemaColumn>;
    function AddUnique(const AColumns: array of string; const AName: string = ''): ISchemaTable;
    function AddIndex(const AColumns: array of string; const AName: string = '';
      const AUnique: Boolean = False): ISchemaTable;
    function Uniques: TSchemaUniques;
    function Indexes: TSchemaIndexes;
  end;

  TSchemaDefinition = class(TInterfacedObject, ISchemaDefinition)
  private
    FTables : TList<ISchemaTable>;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: ISchemaDefinition;
    function Table(const AName: string): ISchemaTable;
    function Tables: TArray<ISchemaTable>;
  end;

  TSchemaInspector = class(TInterfacedObject, ISchemaInspector)
  private
    FConn : IConnection;
    FMeta : ICatalogReader;
    function Meta: ICatalogReader;
  public
    class function New(const AConn: IConnection): ISchemaInspector;
    function Connection(const AConn: IConnection): ISchemaInspector; overload;
    function Connection: IConnection; overload;
    function TableExists(const ATable: string): Boolean;
    function ColumnExists(const ATable, AColumn: string): Boolean;
    function Refresh: ISchemaInspector;
  end;

  TSchemaComparer = class(TInterfacedObject, ISchemaComparer)
  private
    function BuildCreateTable(const ADialect: IDialect;
      const ATable: ISchemaTable): string;
    function BuildAddColumn(const ADialect: IDialect;
      const ATable: string; const ACol: ISchemaColumn): string;
    { Onda 5.5-B - ALTER TABLE ADD CONSTRAINT UNIQUE (tabela existente) + CREATE
      [UNIQUE] INDEX; delegam a geracao de sintaxe ao IDialect. }
    function BuildAddUnique(const ADialect: IDialect; const ATable, AName: string;
      const AColumns: TSchemaColumnNames): string;
    function BuildCreateIndex(const ADialect: IDialect; const ATable, AName: string;
      const AColumns: TSchemaColumnNames; const AUnique: Boolean): string;
  public
    class function New: ISchemaComparer;
    function Compare(const ADef: ISchemaDefinition;
      const AConn: IConnection): TArray<TSchemaChange>;
  end;

  TSynchronize = class(TInterfacedObject, ISynchronize)
  private
    FConn   : IConnection;
    FVerify : Boolean;      // R2-B - verificacao pos-DDL (default ON, ligado no New)
    procedure EnsureVersionTable(const ADialect: IDialect);
    procedure LogMigration(const ADialect: IDialect; const AChanges: Integer);
    { F5 onda C8 (bug-986, mesma raiz do bug-983) - fecha, no SQL Anywhere, a
      transaccao IMPLICITA residual que o INSERT de LogMigration abre nesta
      ligacao (ExecuteCommand parametrizado - bug-884 - nao a fecha de forma
      fiavel aqui; ver comentario completo no corpo do metodo). Chamado UMA
      VEZ em Sync, logo apos LogMigration - LOCAL correcto (fix de RAIZ): o
      Sync() passa a devolver SEMPRE a ligacao committada/limpa neste engine,
      com ou sem VerifyAfterSync(False), em vez de depender de VerifyShape
      (que so beneficiava a propria verificacao interna). No-op nos restantes
      engines. }
    procedure CommitResidualSQLAnywhere;
    { F5 onda C7 (mitigacao race catalogo SQL Anywhere) - calcula os residuos
      "duros" (sckCreateTable/sckAddColumn) de um Compare FRESCO. Extraido de
      VerifyShape para ser reutilizado tanto na 1a verificacao como nas
      retries SA (mesma logica, sem duplicar o filtro de kinds). }
    function HardResidual(const ADef: ISchemaDefinition): TArray<TSchemaChange>;
    { R2-B - re-corre o Compare sobre ADef apos o Sync aplicar; se sobrar
      diferenca lanca EDatabaseSchemaVerificationException (o DDL nao produziu
      o alvo). Sem efeito se FVerify=False. }
    procedure VerifyShape(const ADef: ISchemaDefinition);
  public
    class function New(const AConn: IConnection): ISynchronize;
    function Connection(const AConn: IConnection): ISynchronize;
    function VerifyAfterSync(const AValue: Boolean): ISynchronize;
    function Plan(const ADef: ISchemaDefinition): TArray<TSchemaChange>;
    function Sync(const ADef: ISchemaDefinition): Integer;
  end;

{$ENDIF}

implementation

{$IFDEF USE_DATABASE}

uses
{$IFDEF FPC}
  Windows,        // Sleep - retry pos-DDL SQL Anywhere (onda C7, VerifyShape)
{$ELSE}
  Winapi.Windows, // Sleep - retry pos-DDL SQL Anywhere (onda C7, VerifyShape)
{$ENDIF}
  Commons.Database.Consts,
  Exceptions.Database,
  Database.Dialect;

{ TSchemaColumn }

constructor TSchemaColumn.Create(const AName: string; const AKind: TSQLColumnKind;
  const ASize: Integer; const ANullable, APK: Boolean; const AScale: Integer);
begin
  inherited Create;
  FName := AName;
  FKind := AKind;
  FSize := ASize;
  FScale := AScale;
  FNullable := ANullable;
  FPK := APK;
end;

function TSchemaColumn.ColumnName: string;
begin
  Result := FName;
end;

function TSchemaColumn.Kind: TSQLColumnKind;
begin
  Result := FKind;
end;

function TSchemaColumn.Size: Integer;
begin
  Result := FSize;
end;

function TSchemaColumn.Scale: Integer;
begin
  Result := FScale;
end;

function TSchemaColumn.IsNullable: Boolean;
begin
  Result := FNullable;
end;

function TSchemaColumn.IsPrimaryKey: Boolean;
begin
  Result := FPK;
end;

{ TSchemaTable }

constructor TSchemaTable.Create(const AName: string);
begin
  inherited Create;
  FName := Trim(AName);
  FCols := TList<ISchemaColumn>.Create;
end;

destructor TSchemaTable.Destroy;
begin
  FCols.Free;
  inherited Destroy;
end;

function TSchemaTable.TableName: string;
begin
  Result := FName;
end;

function TSchemaTable.AddColumn(const AName: string; const AKind: TSQLColumnKind;
  const ASize: Integer; const ANullable, APrimaryKey: Boolean; const AScale: Integer): ISchemaTable;
begin
  FCols.Add(TSchemaColumn.Create(Trim(AName), AKind, ASize, ANullable, APrimaryKey, AScale));
  Result := Self;
end;

function TSchemaTable.Columns: TArray<ISchemaColumn>;
begin
  Result := FCols.ToArray;
end;

function TSchemaTable.AddUnique(const AColumns: array of string;
  const AName: string): ISchemaTable;
var
  LU: TSchemaUnique;
  I: Integer;
begin
  LU.Name := Trim(AName);
  SetLength(LU.Columns, Length(AColumns));
  for I := 0 to High(AColumns) do
    LU.Columns[I] := Trim(AColumns[I]);
  SetLength(FUniques, Length(FUniques) + 1);
  FUniques[High(FUniques)] := LU;
  Result := Self;
end;

function TSchemaTable.AddIndex(const AColumns: array of string;
  const AName: string; const AUnique: Boolean): ISchemaTable;
var
  LX: TSchemaIndex;
  I: Integer;
begin
  LX.Name := Trim(AName);
  LX.Unique := AUnique;
  SetLength(LX.Columns, Length(AColumns));
  for I := 0 to High(AColumns) do
    LX.Columns[I] := Trim(AColumns[I]);
  SetLength(FIndexes, Length(FIndexes) + 1);
  FIndexes[High(FIndexes)] := LX;
  Result := Self;
end;

function TSchemaTable.Uniques: TSchemaUniques;
begin
  Result := FUniques;
end;

function TSchemaTable.Indexes: TSchemaIndexes;
begin
  Result := FIndexes;
end;

{ TSchemaDefinition }

constructor TSchemaDefinition.Create;
begin
  inherited Create;
  FTables := TList<ISchemaTable>.Create;
end;

destructor TSchemaDefinition.Destroy;
begin
  FTables.Free;
  inherited Destroy;
end;

class function TSchemaDefinition.New: ISchemaDefinition;
begin
  Result := TSchemaDefinition.Create;
end;

function TSchemaDefinition.Table(const AName: string): ISchemaTable;
var
  I: Integer;
  LName: string;
begin
  LName := Trim(AName);
  for I := 0 to FTables.Count - 1 do
    if SameText(FTables[I].TableName, LName) then
      Exit(FTables[I]);
  Result := TSchemaTable.Create(LName);
  FTables.Add(Result);
end;

function TSchemaDefinition.Tables: TArray<ISchemaTable>;
begin
  Result := FTables.ToArray;
end;

{ TSchemaInspector }

class function TSchemaInspector.New(const AConn: IConnection): ISchemaInspector;
var
  LObj: TSchemaInspector;
begin
  LObj := TSchemaInspector.Create;
  LObj.FConn := AConn;
  Result := LObj;
end;

function TSchemaInspector.Meta: ICatalogReader;
begin
  { B5 (conformidade F5 C4): FMeta e reutilizado (cache lazy por inspector) - OK
    para o fluxo Sync (Compare/EnsureVersionTable ja criam readers FRESCOS a cada
    chamada, cobrindo o bug-167 pos-DDL). Um consumidor EXTERNO que use este
    ISchemaInspector directamente e faca DDL FORA dele deve invalidar via
    Self.Meta.Refresh (ICatalogReader.Refresh) ou re-setar Connection (que poe
    FMeta:=nil) antes de reler, senao le estado desatualizado. }
  if FMeta = nil then
    FMeta := TCatalogReader.New(FConn);
  Result := FMeta;
end;

function TSchemaInspector.Connection(const AConn: IConnection): ISchemaInspector;
begin
  FConn := AConn;
  FMeta := nil;
  Result := Self;
end;

function TSchemaInspector.Connection: IConnection;
begin
  Result := FConn;
end;

function TSchemaInspector.TableExists(const ATable: string): Boolean;
begin
  Result := Meta.TableExists(ATable);
end;

function TSchemaInspector.ColumnExists(const ATable, AColumn: string): Boolean;
begin
  Result := Meta.ColumnExists(ATable, AColumn);
end;

function TSchemaInspector.Refresh: ISchemaInspector;
begin
  if FMeta <> nil then
    FMeta.Refresh;
  Result := Self;
end;

{ ---- Onda 5.5-B - helpers de UNIQUE/INDEX ---- }

{ nome DETERMINISTICO da constraint UNIQUE / indice quando o utilizador nao o
  fornece - a MESMA derivacao e usada na criacao e na verificacao de
  idempotencia, para casarem. Derivado das COLUNAS (nao da posicao ordinal),
  para ser ESTAVEL a reordenacao/insercao de outros AddUnique/AddIndex anonimos:
  se o nome dependesse do indice K, inserir um novo AddUnique no meio faria o
  mesmo nome passar a designar OUTRA constraint fisica e o Compare confundiria
  'existe constraint com este nome' com 'a constraint desejada ja existe'
  (constraint perdida em silencio + duplicada). APrefix = 'uk' ou 'ix'.
  NOTA: nomes anonimos multi-coluna podem exceder o limite de identificador de
  motores antigos (ex. Firebird fb25 = 31 chars); nesse caso, fornecer AName. }
function ResolveObjName(const ATable, AName, APrefix: string;
  const AColumns: TSchemaColumnNames): string;
var
  I: Integer;
begin
  if Trim(AName) <> '' then
    Exit(Trim(AName));
  Result := Trim(ATable) + '_' + APrefix;
  for I := 0 to High(AColumns) do
    if Trim(AColumns[I]) <> '' then
      Result := Result + '_' + Trim(AColumns[I]);
end;

{ TSchemaComparer }

class function TSchemaComparer.New: ISchemaComparer;
begin
  Result := TSchemaComparer.Create;
end;

function TSchemaComparer.BuildCreateTable(const ADialect: IDialect;
  const ATable: ISchemaTable): string;
var
  LCols: TArray<ISchemaColumn>;
  I: Integer;
  LColSql, LColsAll, LPkList, LType: string;
  LPkEmbedded: Boolean;
begin
  LCols := ATable.Columns;
  if Length(LCols) = 0 then
    raise EDatabaseSchemaException.Create(
      Format(DB_ERR_SCHEMA_NO_TABLE_MSG, [ATable.TableName]), ERR_DATABASE_SCHEMA);
  LColsAll := '';
  LPkList := '';
  LPkEmbedded := False;
  for I := 0 to High(LCols) do
  begin
    { fix #2 (auditoria) - passa a Scale (ISchemaColumn.Scale, ADITIVO) para o
      dialecto; sem isto uma DECIMAL/NUMERIC de origem perdia sempre a escala
      (ColumnTypeFor defaulta Scale=0, nao 4, quando AScale=0 e' passado
      explicitamente - so' defaulta quando < 0). }
    LType := ADialect.ColumnTypeFor(LCols[I].Kind, LCols[I].Size, LCols[I].Scale);
    LColSql := ADialect.QuoteIdentifier(LCols[I].ColumnName) + ' ' + LType;
    if not LCols[I].IsNullable then
      LColSql := LColSql + ' NOT NULL';
    if LColsAll <> '' then
      LColsAll := LColsAll + ', ';
    LColsAll := LColsAll + LColSql;
    if LCols[I].IsPrimaryKey then
    begin
      if LPkList <> '' then
        LPkList := LPkList + ', ';
      LPkList := LPkList + ADialect.QuoteIdentifier(LCols[I].ColumnName);
      if Pos('PRIMARY KEY', UpperCase(LType)) > 0 then
        LPkEmbedded := True;
    end;
  end;
  if (LPkList <> '') and (not LPkEmbedded) then
    LColsAll := LColsAll + ', PRIMARY KEY (' + LPkList + ')';
  { Onda 5.5-B: as constraints UNIQUE e os indices NAO vao inline aqui - sao
    emitidos como statements SEPARADOS pelo Compare (BuildAddUnique/
    BuildCreateIndex), SEMPRE com o nosso nome deterministico. Motivo: em SQLite
    um UNIQUE inline gera um "sqlite_autoindex_*" (ignora o nome da constraint),
    o que quebraria a idempotencia por nome; o statement separado (CREATE UNIQUE
    INDEX no SQLite/Access, ALTER ADD CONSTRAINT nos restantes) preserva o nome. }
  { Onda D (D.10): o WRAPPER 'CREATE TABLE t (...)' vem da faceta do dialecto
    (fonte UNICA de sintaxe) - antes era montado inline aqui. A clausula de
    colunas+PK continua a ser decidida por este comparador. }
  Result := ADialect.Table.CreateSQL(ATable.TableName, LColsAll, '');
end;

function TSchemaComparer.BuildAddColumn(const ADialect: IDialect;
  const ATable: string; const ACol: ISchemaColumn): string;
begin
  { Onda D (D.10): delega a sintaxe a faceta Field.AddSQL do dialecto (fonte
    UNICA). A base e 'ADD COLUMN', mas Firebird/SQL Server sobrepoem (ADD SEM
    'COLUMN') - antes o 'ADD COLUMN' estava hardcoded aqui e ERRAVA em Firebird. }
  { fix #2 (auditoria) - idem BuildCreateTable, ver comentario la'. }
  Result := ADialect.Field.AddSQL(ATable, ACol.ColumnName,
    ADialect.ColumnTypeFor(ACol.Kind, ACol.Size, ACol.Scale), not ACol.IsNullable);
end;

function TSchemaComparer.BuildAddUnique(const ADialect: IDialect;
  const ATable, AName: string; const AColumns: TSchemaColumnNames): string;
begin
  { delega a sintaxe ao dialecto: base ALTER TABLE ADD CONSTRAINT UNIQUE;
    SQLite/Access -> CREATE UNIQUE INDEX (o dialecto pode devolver '' se nao
    suportar - o Compare filtra SQL vazio). }
  Result := ADialect.AddUniqueSQL(ATable, AName, AColumns);
end;

function TSchemaComparer.BuildCreateIndex(const ADialect: IDialect;
  const ATable, AName: string; const AColumns: TSchemaColumnNames;
  const AUnique: Boolean): string;
begin
  Result := ADialect.CreateIndexSQL(ATable, AName, AColumns, AUnique);
end;

function TSchemaComparer.Compare(const ADef: ISchemaDefinition;
  const AConn: IConnection): TArray<TSchemaChange>;
var
  LDialect  : IDialect;
  LMeta     : ICatalogReader;
  LTables   : TArray<ISchemaTable>;
  LCols     : TArray<ISchemaColumn>;
  LUniques  : TSchemaUniques;
  LIndexes  : TSchemaIndexes;
  I, J, K, N: Integer;
  LChange   : TSchemaChange;
  LTbl, LName, LSQL: string;
  LNewTable : Boolean;
begin
  SetLength(Result, 0);
  N := 0;
  if AConn = nil then
    raise EDatabaseSchemaException.Create(
      Format(DB_ERR_SCHEMA_NO_CONN_MSG, ['Compare']), ERR_DATABASE_NO_CONNECTION);
  LDialect := TDialect.ForConnection(AConn);
  LMeta := TCatalogReader.New(AConn);
  LMeta.Refresh;
  LTables := ADef.Tables;
  for I := 0 to High(LTables) do
  begin
    LTbl := LTables[I].TableName;
    LNewTable := not LMeta.TableExists(LTbl);
    if LNewTable then
    begin
      LChange.Kind := sckCreateTable;
      LChange.Table := LTbl;
      LChange.Column := '';
      LChange.Name := '';
      LChange.SQL := BuildCreateTable(LDialect, LTables[I]);
      SetLength(Result, N + 1);
      Result[N] := LChange;
      Inc(N);
    end
    else
    begin
      { colunas em falta (tabela ja existe) }
      LCols := LTables[I].Columns;
      for J := 0 to High(LCols) do
        if not LMeta.ColumnExists(LTbl, LCols[J].ColumnName) then
        begin
          LChange.Kind := sckAddColumn;
          LChange.Table := LTbl;
          LChange.Column := LCols[J].ColumnName;
          LChange.Name := '';
          LChange.SQL := BuildAddColumn(LDialect, LTbl, LCols[J]);
          SetLength(Result, N + 1);
          Result[N] := LChange;
          Inc(N);
        end;
    end;
    { Onda 5.5-B - constraints UNIQUE (statement separado, nome deterministico).
      Tabela nova -> emitir sempre (IndexExists/UniqueExists nao consultado, a
      tabela ainda nao existe fisicamente); tabela existente -> so as que faltam
      (idempotencia via ICatalogReader.UniqueExists por nome; dialecto sem
      introspecao -> UniqueExists devolve True e nao re-emite). SQL vazio
      (dialecto sem suporte) e filtrado. }
    LUniques := LTables[I].Uniques;
    for K := 0 to High(LUniques) do
    begin
      LName := ResolveObjName(LTbl, LUniques[K].Name, 'uk', LUniques[K].Columns);
      if LNewTable or (not LMeta.UniqueExists(LTbl, LName)) then
      begin
        LSQL := BuildAddUnique(LDialect, LTbl, LName, LUniques[K].Columns);
        if Trim(LSQL) <> '' then
        begin
          LChange.Kind := sckAddUnique;
          LChange.Table := LTbl;
          LChange.Column := '';
          LChange.Name := LName;
          LChange.SQL := LSQL;
          SetLength(Result, N + 1);
          Result[N] := LChange;
          Inc(N);
        end;
      end;
    end;
    { indices (CREATE [UNIQUE] INDEX) - mesma logica de idempotencia por nome. }
    LIndexes := LTables[I].Indexes;
    for K := 0 to High(LIndexes) do
    begin
      LName := ResolveObjName(LTbl, LIndexes[K].Name, 'ix', LIndexes[K].Columns);
      if LNewTable or (not LMeta.IndexExists(LTbl, LName)) then
      begin
        LSQL := BuildCreateIndex(LDialect, LTbl, LName, LIndexes[K].Columns, LIndexes[K].Unique);
        if Trim(LSQL) <> '' then
        begin
          LChange.Kind := sckCreateIndex;
          LChange.Table := LTbl;
          LChange.Column := '';
          LChange.Name := LName;
          LChange.SQL := LSQL;
          SetLength(Result, N + 1);
          Result[N] := LChange;
          Inc(N);
        end;
      end;
    end;
  end;
end;

{ TSynchronize }

class function TSynchronize.New(const AConn: IConnection): ISynchronize;
var
  LObj: TSynchronize;
begin
  LObj := TSynchronize.Create;
  LObj.FConn := AConn;
  LObj.FVerify := True;   // R2-B - verificacao pos-DDL ligada por defeito
  Result := LObj;
end;

function TSynchronize.Connection(const AConn: IConnection): ISynchronize;
begin
  FConn := AConn;
  Result := Self;
end;

function TSynchronize.VerifyAfterSync(const AValue: Boolean): ISynchronize;
begin
  FVerify := AValue;
  Result := Self;
end;

{ bug-983 (achado colateral, nunca corrigido) / auditoria 30/07 (bug-foreignkey-
  schema-version) - EnsureVersionTable chamava FConn.ExecuteCommand(CREATE
  TABLE schema_version) SEM try/except algum: se TableExists desse um
  falso-negativo pontual (visibilidade de catalogo residual no SQL Anywhere/
  UniDAC - mesma familia documentada em bug-983/988/1000, mesmo apos os fixes
  de CommitResidualSQLAnywhere/ExecuteQuery ali aplicados) numa tabela que
  JA' EXISTE (criada por uma corrida anterior), o CREATE TABLE seguinte era
  rejeitado pelo servidor ("Item 'schema_version' already exists") e essa
  EUniError NAO TRATADA abortava o processo inteiro (test_foreignkey.dpr,
  5/5 determinístico - schema_version persistia de corridas anteriores no
  servidor partilhado 10.100.2.3). Confirmado tambem nesta sessao (spike
  isolado, dcc32/UniDAC x sqlanywhere, instrumentacao Writeln bisectada) que
  o proprio TableExists (via TCatalogReader->GetTableNamesFromDriver->
  ExecuteQuery) pode propagar uma EXCEPCAO (inclusive EAccessViolation do
  driver nativo, tambem catchable) num cenario de reconexao - ou seja, "nao
  sabemos se a tabela existe" e' um resultado real possivel, nao so' teorico.

  FIX (mínimo, aditivo): schema_version e' um artefacto de AUDITORIA/
  bookkeeping (consumido so' por LogMigration, log informativo de migracoes) -
  nunca deve abortar o Sync/DDL REAL do chamador. Tornado IDEMPOTENTE e
  ROBUSTO: (1) a deteccao de existencia (TableExists) e' ela propria protegida
  - se falhar (excecao de qualquer tipo), assume EXISTS=True (conservador:
  NAO tenta criar, evita de proposito o "already exists" quando a deteccao
  nao e' fiavel); (2) o CREATE TABLE mantem-se protegido por um try/except
  final que tolera QUALQUER falha pontual (a mais comum sendo "already
  exists" pelo motivo acima) - nunca propaga para Sync(). Zero mudanca de
  comportamento no caminho feliz (tabela nao existe, cria-se normalmente;
  tabela existe e e' vista corretamente, Exit cedo como antes). }
procedure TSynchronize.EnsureVersionTable(const ADialect: IDialect);
var
  LMeta: ICatalogReader;
  LSql: string;
  LExists: Boolean;
begin
  try
    LExists := False;
    try
      LMeta := TCatalogReader.New(FConn);
      LMeta.Refresh;
      LExists := LMeta.TableExists(SCHEMA_VERSION_TABLE);
    except
      { nao foi possivel confirmar a existencia (ex.: falha pontual do driver
        nativo numa reconexao) - assume presente para NAO arriscar um CREATE
        TABLE sobre algo que pode ja existir; o try/except externo cobre
        ainda assim qualquer "already exists" residual. }
      LExists := True;
    end;
    if LExists then
      Exit;
    LSql := 'CREATE TABLE ' + ADialect.QuoteIdentifier(SCHEMA_VERSION_TABLE) + ' (' +
      ADialect.QuoteIdentifier('applied_at') + ' ' + ADialect.ColumnTypeFor(ckVarChar, 30) + ', ' +
      ADialect.QuoteIdentifier('changes') + ' ' + ADialect.ColumnTypeFor(ckInteger) + ')';
    FConn.ExecuteCommand(LSql);
  except
    { tolerante por desenho (ver comentario acima) - "already exists" (falso-
      negativo do TableExists) ou qualquer outra falha pontual na criacao do
      bookkeeping de versao NUNCA pode abortar o Sync do chamador. }
  end;
end;

procedure TSynchronize.LogMigration(const ADialect: IDialect;
  const AChanges: Integer);
var
  LSql: string;
  LP: TArray<Variant>;
begin
  { bindado - nunca literal de data por locale (GAP GestorERP) }
  LSql := 'INSERT INTO ' + ADialect.QuoteIdentifier(SCHEMA_VERSION_TABLE) + ' (' +
    ADialect.QuoteIdentifier('applied_at') + ', ' + ADialect.QuoteIdentifier('changes') +
    ') VALUES (:param0, :param1)';
  SetLength(LP, 2);
  LP[0] := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
  LP[1] := AChanges;
  FConn.ExecuteCommand(LSql, LP);
end;

{ F5 onda C8 (bug-986, mesma raiz do bug-983) - FIX DE RAIZ: fecha, logo apos
  LogMigration, a transaccao IMPLICITA residual que o INSERT em schema_version
  abre nesta ligacao no SQL Anywhere (UniDAC).

  PORQUE E' PRECISO: LogMigration corre via FConn.ExecuteCommand(parametrizado),
  que ja tenta (bug-884) commitar via TUniConnection.Commit quando
  (not FInTransaction) and (FDatabaseType=dtSQLAnywhere). Essa chamada nativa
  e' o que resolve a PERSISTENCIA do INSERT (confirmado por dbisql em bug-884),
  mas nao garante de forma fiavel que a MESMA ligacao fica LIVRE de uma
  transaccao aberta para as PROXIMAS leituras: o proprio TConnection.Commit
  (Connections.pas, chamado pelo loop de DDL ANTES de LogMigration) so actua
  quando o bookkeeping FInTransaction esta True - e essa flag ja foi baixada
  pelo Commit do DDL antes de LogMigration correr. So um "COMMIT" em SQL CRU
  (via ExecuteCommand, contornando esse bookkeeping) fecha isto de forma
  DETERMINISTICA (bug-983, provado contra o servidor real - ate 12 tentativas
  de Sleep+retry na MESMA ligacao NUNCA resolviam sem este COMMIT).

  LOCAL CORRECTO (fix de RAIZ, nao patch por-consumidor): chamado AQUI, logo
  apos LogMigration em Sync - e nao dentro de VerifyShape (onda C7, versao
  anterior) - porque (a) corre INCONDICIONALMENTE, mesmo com
  VerifyAfterSync(False) (a versao anterior so commitava quando FVerify=True,
  deixando a ligacao suja num Sync com verificacao desligada); e (b) garante
  que Sync() DEVOLVE a ligacao sempre committada/limpa a QUALQUER consumidor
  externo que a reutilize a seguir (ex.: ICatalogReader.TableNames chamado
  directamente pelo caller, fora do proprio Sync - bug-986/test_catalogreader),
  nao so' a propria verificacao interna (VerifyShape la' dentro ja nao precisa
  de repetir este COMMIT - consolidado, evita 2 chamadas redundantes).

  Gated a dtSQLAnywhere: COMMIT sem transaccao pendente e' um no-op inocuo;
  o try/except so' evita que uma falha aqui (ligacao a rejeitar um COMMIT
  solto) mascare o que se segue. Zero mudanca de comportamento nos restantes
  engines (nunca executam este COMMIT extra).

  fix #6 (auditoria adversarial) - gate adicional FConn.InTransaction: o
  COMMIT cru corria INCONDICIONALMENTE (mesmo com uma transaccao EXPLICITA
  do consumidor ainda aberta nesta MESMA ligacao - ex.: chamador fez
  IConnection.BeginTransaction antes de invocar Sync/ApplyStructure) -
  terminaria essa transaccao do consumidor por baixo dos pes dele. Mesmo
  padrao ja usado no COMMIT pos-ExecuteQuery (Connections.pas, gated
  "(not FInTransaction) and (FDatabaseType = dtSQLAnywhere)"): so' commita
  quando NAO ha uma transaccao explicita bookkept nesta ligacao. Quando ha
  (FConn.InTransaction=True), o COMMIT residual e' pulado - a transaccao do
  consumidor decide o proprio commit/rollback; o fluxo normal do Sync (sem
  transaccao externa) continua identico (InTransaction=False neste ponto,
  ver TSynchronize.Sync - o Commit do loop DDL ja baixou o bookkeeping antes
  de LogMigration/CommitResidualSQLAnywhere correrem). }
procedure TSynchronize.CommitResidualSQLAnywhere;
begin
  if FConn.DatabaseType <> dtSQLAnywhere then
    Exit;
  if FConn.InTransaction then
    Exit;
  try
    FConn.ExecuteCommand('COMMIT');
  except
    { inocuo - nada para commitar, ou a ligacao rejeita um COMMIT solto; a
      verificacao/leituras seguintes continuam a decidir o resultado real. }
  end;
end;

{ R2-B - descreve o tipo do objecto em falta (para a mensagem de verificacao). }
function ChangeKindText(const AKind: TSchemaChangeKind): string;
begin
  case AKind of
    sckCreateTable: Result := 'tabela';
    sckAddColumn:   Result := 'coluna';
    sckAddUnique:   Result := 'unique';
    sckCreateIndex: Result := 'indice';
  else
    Result := 'objecto';
  end;
end;

function TSynchronize.HardResidual(const ADef: ISchemaDefinition): TArray<TSchemaChange>;
var
  LResidual: TArray<TSchemaChange>;
  I: Integer;
begin
  { re-corre o Compare com metadata FRESCO (Compare faz TCatalogReader.New +
    Refresh a cada chamada - ve o resultado do DDL, bug-167). O Compare so reporta
    o que FALTA do desejado, por isso um Sync bem-sucedido deixa-o VAZIO.
    IMPORTANTE: so consideramos residuos de TABELA/COLUNA (sckCreateTable/
    sckAddColumn) - existencia FIAVELMENTE introspetavel em todos os engines. Os
    residuos de UNIQUE/INDICE (sckAddUnique/sckCreateIndex) sao IGNORADOS: a sua
    idempotencia e CONSERVADORA (UniqueExists/IndexExists pode nao casar por
    nome/quoting um objecto ACABADO de criar em alguns engines), o que geraria
    FALSO-POSITIVO de verificacao num Sync que de facto criou tudo.

    B4 (conformidade F5, onda C5) - TENTATIVA E REVERSAO: o owner pediu para
    reabrir e estender a verificacao a estes 2 kinds com uma 2a confirmacao
    via ICatalogReader.UniqueExists/IndexExists (introspecao fresca e direta,
    sem cache) antes de escalar. IMPLEMENTADO e testado - REPRODUZIU o
    falso-positivo EM PRODUCAO REAL: smoke_parameters_db (Zeos+SQLite local)
    passou a falhar com EDatabaseSchemaVerificationException logo apos criar
    "parameters_bak" + UNIQUE "ChaveUnica" (a query de introspecao nao viu o
    objecto imediatamente a seguir ao DDL, na MESMA ligacao/transacao,
    mesmo sem cache do TCatalogReader). Prova empirica de que a cautela
    ORIGINAL desta funcao (ignorar estes 2 kinds) e CORRETA e nao um
    conservadorismo desnecessario - revertido para o comportamento original;
    "N/A"/limitacao documentada mantem-se (nao ha correcao segura conhecida
    sem arriscar falsos-positivos que quebrem Syncs bem-sucedidos). }
  LResidual := TSchemaComparer.New.Compare(ADef, FConn);
  SetLength(Result, 0);
  for I := 0 to High(LResidual) do
    if LResidual[I].Kind in [sckCreateTable, sckAddColumn] then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := LResidual[I];
    end;
end;

procedure TSynchronize.VerifyShape(const ADef: ISchemaDefinition);
const
  { F5 onda C7 - achado real (nao a hipotese inicial de "latencia de catalogo
    do SQL Anywhere sob carga"): investigacao empirica (spike dedicado, 3
    ligacoes distintas comparadas lado-a-lado contra o servidor real) provou
    que NAO e' uma questao de TEMPO. Sleep+retry na MESMA ligacao ate' 12x de
    1000ms (12 segundos) NUNCA resolveu; uma 2a ligacao aberta no MESMO
    PROCESSO, sem qualquer espera, via SEMPRE o estado correcto de imediato.
    Isto isola a causa a ligacao FConn em si, nao ao catalogo do servidor.

    ROOT CAUSE: LogMigration (chamado em Sync mesmo antes de VerifyShape)
    executa um INSERT em schema_version via FConn.ExecuteCommand FORA de
    qualquer BeginTransaction/Commit explicito, abrindo no SQL Anywhere
    (UniDAC) uma transaccao IMPLICITA nesta ligacao que fica por commitar.

    F5 onda C8 (bug-986) - o COMMIT que fechava essa transaccao residual
    ANTES da 1a leitura do catalogo MUDOU-SE para Sync (metodo
    CommitResidualSQLAnywhere, chamado logo apos LogMigration, ANTES desta
    funcao) - fix de RAIZ: corre incondicionalmente (mesmo com
    FVerify=False) e garante que
    QUALQUER consumidor externo que reutilize FConn a seguir ve o catalogo
    consistente, nao so' esta verificacao interna. Chamar o MESMO COMMIT aqui
    outra vez seria redundante (a ligacao ja chega limpa a VerifyShape) -
    consolidado num unico ponto. Mantido o retry curto
    (SA_VERIFY_RETRY_COUNT/DELAY_MS) como rede de seguranca adicional para
    hipoteses residuais (ex.: hiccup de rede pontual contra o servidor
    partilhado) - barato e inofensivo, mesmo agora que o COMMIT principal
    corre mais cedo. }
  SA_VERIFY_RETRY_COUNT    = 3;
  SA_VERIFY_RETRY_DELAY_MS = 300;
var
  LHard: TArray<TSchemaChange>;
  LAttempt: Integer;
  LObj: string;
begin
  if not FVerify then
    Exit;
  LHard := HardResidual(ADef);
  { Retry curto SO para dtSQLAnywhere, como defesa em profundidade adicional
    (ver comentario da const acima) - reentra a introspecao (HardResidual
    chama Compare, que cria um ICatalogReader NOVO + Refresh a cada
    tentativa) antes de escalar. Gated ao tipo de banco: os restantes
    engines NUNCA reentram aqui, mantendo o comportamento original
    (deteccao de falha genuina imediata). Se apos as tentativas ainda
    faltar algo, cai no mesmo "raise" de sempre - a rede de seguranca
    continua intacta. }
  if (Length(LHard) > 0) and (FConn.DatabaseType = dtSQLAnywhere) then
  begin
    LAttempt := 0;
    while (Length(LHard) > 0) and (LAttempt < SA_VERIFY_RETRY_COUNT) do
    begin
      Sleep(SA_VERIFY_RETRY_DELAY_MS);
      LHard := HardResidual(ADef);
      Inc(LAttempt);
    end;
  end;
  if Length(LHard) = 0 then
    Exit;
  if Trim(LHard[0].Column) <> '' then
    LObj := LHard[0].Table + '.' + LHard[0].Column
  else
    LObj := LHard[0].Table;
  raise EDatabaseSchemaVerificationException.Create(
    Format(DB_ERR_SCHEMA_VERIFY_MSG,
      [Length(LHard), ChangeKindText(LHard[0].Kind), LObj]),
    ERR_DATABASE_SCHEMA_VERIFICATION, LHard[0].SQL);
end;

function TSynchronize.Plan(const ADef: ISchemaDefinition): TArray<TSchemaChange>;
begin
  Result := TSchemaComparer.New.Compare(ADef, FConn);
end;

function TSynchronize.Sync(const ADef: ISchemaDefinition): Integer;
var
  LDialect : IDialect;
  LChanges : TArray<TSchemaChange>;
  I        : Integer;
  LTransactional: Boolean;
begin
  if FConn = nil then
    raise EDatabaseSchemaException.Create(
      Format(DB_ERR_SCHEMA_NO_CONN_MSG, ['Sync']), ERR_DATABASE_NO_CONNECTION);
  LDialect := TDialect.ForConnection(FConn);
  EnsureVersionTable(LDialect);
  LChanges := TSchemaComparer.New.Compare(ADef, FConn);
  Result := Length(LChanges);
  if Result = 0 then
    Exit;
  { M4 (conformidade F5, onda C6) - MySQL/MariaDB fazem IMPLICIT COMMIT a cada
    statement DDL (CREATE/ALTER/DROP TABLE, ADD INDEX, ...) - envolver o loop
    abaixo em BeginTransaction/Commit/Rollback era uma falsa promessa de
    atomicidade nesse engine (um erro a meio deixa as alteracoes anteriores
    JA COMMITADAS de qualquer forma; o Rollback so desfaria o que NAO
    precisava de DDL, tipicamente nada). ENGINE-AWARE: MySQL/MariaDB correm o
    DDL DIRETO, sem transacao; os restantes engines mantem o comportamento
    transacional original (BeginTransaction real, Rollback real em falha).
    VerifyShape (chamado no fim, em AMBOS os ramos) continua a ser a rede de
    seguranca REAL que deteta um Sync incompleto, com ou sem transacao. }
  LTransactional := FConn.DatabaseType <> dtMySQL;
  if LTransactional then
    FConn.BeginTransaction;
  try
    for I := 0 to High(LChanges) do
      FConn.ExecuteCommand(LChanges[I].SQL);
    if LTransactional then
      FConn.Commit;
  except
    { F5-FU.3 - o lock em NO WAIT ja vem tipado do funil ExecuteCommand; deixa
      passar catchable (senao o handler generico abaixo mascarava-o como
      EDatabaseSchemaException e o consumidor perdia o tipo). Rollback so
      quando ha transacao real (M4 - MySQL/MariaDB nunca abriu uma). }
    on E: EDatabaseObjectLockedException do
    begin
      if LTransactional then
        FConn.Rollback;
      raise;
    end;
    on E: Exception do
    begin
      if LTransactional then
        FConn.Rollback;
      raise EDatabaseSchemaException.Create(
        Format(DB_ERR_SCHEMA_APPLY_MSG, ['Sync', E.Message]), ERR_DATABASE_SCHEMA);
    end;
  end;
  LogMigration(LDialect, Result);
  CommitResidualSQLAnywhere;   // F5 onda C8 (bug-986) - ver comentario do metodo
  VerifyShape(ADef);   // R2-B - rede de seguranca: confirma que o DDL produziu o alvo
end;

{$ENDIF}

end.
