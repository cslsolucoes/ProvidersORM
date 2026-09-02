{ =============================================================================
  Commons.Database.Types - Tipos exclusivos do modulo Database (dado puro)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.0
  FileVersion:    1.11.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           29/07/2026

  FASE 5 Onda 5.1 (placement por peca: dado -> Commons.Database.*). Tipos do
  catalogo de metadados consumidos pelo IMetadata e, nas ondas
  seguintes, pelos dialectos (5.2) e SchemaSync (5.5).

  Nota: a separacao real de views/procedures por engine chega com o
  IDialect (Onda 5.2); na 5.1 o filtro implementado e o de objectos de
  SISTEMA (normalizacao apurada na Onda 4.2d - ex.: Zeos+Firebird lista
  RDB$/MON$ em GetTableNames).

  Changelog (file):
  - 1.11.0 (29/07/2026): Onda S2-b2 (versionamento de banco - triggers/rules/
    procedures/functions/views ao nivel do SCHEMA, Database.Schema.pas) -
    novo record TSchemaView/TSchemaViews (dado puro Name/SelectSQL/OrReplace),
    mesmo padrao de TSchemaUnique/TSchemaIndex (nome+dado composto); VIEW e o
    unico dos 5 objectos sem builder fluente proprio (TRIGGER/RULE/PROCEDURE/
    FUNCTION reutilizam ITriggerDefinition/IRuleDefinition/IRoutineDefinition,
    ja existentes em Databases.Interfaces).
  - 1.10.0 (16/07/2026): F5 Onda 10 (SQL Anywhere 17) - TSQLPaginationStyle
    ganha psTopStartAt ("TOP n START AT m", confirmado contra servidor real;
    LIMIT/OFFSET NAO suportado, SQLCODE=-131).
  - 1.9.0 (16/07/2026): Onda 5.5-B (indices/constraints, ADITIVO) - TSQLCapability
    ganha scUnique (no FIM do enum, ordinais preservados); TSchemaChangeKind ganha
    sckAddUnique/sckCreateIndex (no FIM); TSchemaChange ganha campo Name; novos
    records TSchemaUnique/TSchemaUniques + TSchemaIndex/TSchemaIndexes + tipo
    TSchemaColumnNames (dado puro do UNIQUE/INDEX composto do SchemaSync).
  - 1.8.0 (15/07/2026): Onda 6-e Estagio 1 (F5 revisao, I3 estatisticas de
    execucao, ADITIVO) - TQueryStatistics (RowsAffected/ElapsedMs/LastSQL),
    dado puro consumido por IQueryBuilder.Statistics (Database.QueryBuilder) -
    devolve as estatisticas do ultimo Execute/ExecuteMutation. Default (record
    zerado: 0, 0, '') = sem execucao ainda (comportamento pre-existente
    inalterado).
  - 1.7.0 (15/07/2026): Onda 6-d (F5 revisao, I9 filtro de catalogo, ADITIVO) -
    TMetadataFilter (SchemaName/NamePrefix/IncludeSystemObjects), dado puro
    consumido por IMetadata.Filter (Database.Metadata) - restringe TableNames/
    TableStructure/ForeignKeys/ResolveFK/TableExists/ColumnExists por schema
    (fallback quando o parametro ASchema nao e fornecido) e por prefixo de
    nome (client-side). Default (record zerado) = sem restricao.
  - 1.6.0 (15/07/2026): Onda 6-c (F5 revisao, I5 AutoJoin por FK + I20 relacoes,
    ADITIVO) - TRelationCardinality (rcUnknown/rcOneToOne/rcManyToOne/
    rcOneToMany) + TRelationInfo (FromTable/FromColumn/ToTable/ToColumn/
    Cardinality), dado puro consumido por IMetadata.ResolveFK (descoberta de
    FK) e IQueryBuilder.JoinByFK/AutoJoin (Database.QueryBuilder).
  - 1.5.0 (14/07/2026): Onda 6-a (F5 revisao, modernizacao AQB/EMS - I23,
    ADITIVO) - TSQLCapability ganha 8 flags SUPERSET no fim do enum (posicoes
    ordinais das existentes preservadas): scRecursiveCTE/scWindowFunctions/
    scMerge/scUpsert/scSequences/scArrays/scJSON/scFullText. Cada
    TDialect<Banco> so acrescenta ao FCapabilities os que suporta (set of -
    ausencia = OFF sem custo de codigo).
  - 1.4.0 (14/07/2026): Sub-passo 4.5 (continuacao Onda 4, revisao F5) -
    TFieldValidationError/TFieldValidationErrors (dado puro) - detalhe
    (field,message) devolvido por ITable.ValidateFields (Database.Table),
    validacao no save (INSERT/UPDATE) antes de gerar SQL.
  - 1.3.0 (14/07/2026): renomeacao mecanica (Provider suffix removido): T/IMetadata.
  - 1.2.0 (13/07/2026): Onda 4.2 - TRowStatus (dsInactive/dsInsert/dsEdit/
    dsDeleted) - estado de operacao por registo (modelo v1.6.1).
  - 1.1.0 (12/07/2026): Onda 5.2 - TSQLCapability/Capabilities,
    TSQLPaginationStyle, TSQLColumnKind (substitui TVariableType estatico) e
    TSQLOperatorDef (operadores decompostos, modelo E3).
  - 1.0.0 (12/07/2026): versao inicial (FASE 5 Onda 5.1).
  ============================================================================= }
unit Commons.Database.Types;

{$I ../ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$IFDEF USE_DATABASE}

type
  { Tipo de objecto do catalogo (consumo pleno na Onda 5.2 - dialectos). }
  TMetadataObjectKind  = (mokTable, mokView, mokProcedure, mokSystem);
  TMetadataObjectKinds = set of TMetadataObjectKind;

  { ===== Onda 5.2 - dialectos SQL (dado puro) ===== }

  { Capability flags (modelo AQB): o QueryBuilder/SchemaSync consultam antes
    de emitir SQL - o dialecto e o UNICO sitio com SQL especifico de banco. }
  TSQLCapability = (
    scSchemas,          // qualificacao schema.tabela
    scCTE,              // WITH ... AS
    scDerivedTables,    // FROM (SELECT ...)
    scUnion, scUnionAll,
    scReturning,        // INSERT ... RETURNING (1 linha)
    scReturningMulti,   // RETURNING multi-linha (FB 5.0+)
    scBoolean,          // tipo BOOLEAN nativo
    scIdentity,         // GENERATED ... AS IDENTITY
    scDecFloat,         // DECFLOAT/INT128 (FB 4.0+)
    scILike,            // ILIKE (PostgreSQL)
    scConcatPipes,      // operador || (ANSI)
    scOffsetFetch,      // OFFSET n ROWS FETCH NEXT m
    scLimitOffset,      // LIMIT m OFFSET n
    scRowsClause,       // ROWS m TO n (Firebird)
    scTop,              // SELECT TOP n (SQLServer/Access)
    { ===== Onda 6-a (F5 revisao, modernizacao AQB/EMS - I23) - aditivos =====
      Superconjunto de capacidades; cada TDialect<Banco> so acrescenta ao
      FCapabilities os flags que suporta - ausencia = OFF (set of, sem custo). }
    scRecursiveCTE,     // WITH RECURSIVE
    scWindowFunctions,  // OVER (PARTITION BY ... ORDER BY ...) - ranking/analytic
    scMerge,            // MERGE ... WHEN MATCHED/NOT MATCHED (statement dedicado)
    scUpsert,           // upsert de 1 statement (ON CONFLICT / ON DUPLICATE KEY / UPDATE OR INSERT)
    scSequences,        // objecto SEQUENCE/GENERATOR autonomo (fora da coluna)
    scArrays,           // tipo ARRAY nativo de coluna
    scJSON,             // tipo/funcoes JSON nativos (JSONB, JSON_VALUE, json1, ...)
    scFullText,         // indexacao/pesquisa full-text nativa
    { ===== Onda 5.5-B (indices/constraints) - aditivo (posicao ordinal no FIM) ===== }
    scUnique,           // constraint/indice UNIQUE declaravel (single ou multi-coluna)
    { ===== Onda D (manipulacao DDL por nivel) - aditivos (ordinal no FIM) =====
      Consumidos pelos novos metodos DDL do IDialect (Add/Drop/Alter/Rename de
      column/table/PK/FK/index/view/procedure/function) para gatear/escolher
      fallback (ex.: SQLite sem scAlterColumn -> table-rebuild). }
    scDropIfExists,     // DROP ... IF EXISTS nativo (senao introspeccao/EXECUTE BLOCK)
    scAlterColumn,      // ALTER/MODIFY COLUMN (mudar tipo/null) - SQLite NAO -> rebuild
    scDropColumn,       // ALTER TABLE DROP COLUMN (SQLite so 3.35+)
    scRenameColumn,     // RENAME COLUMN (SQLite 3.25+; SQLServer sp_rename)
    scRenameTable,      // RENAME TABLE (Firebird NAO tem)
    scForeignKeys,      // FOREIGN KEY declaravel/enforced (SQLite via PRAGMA)
    scViews,            // CREATE/DROP/ALTER VIEW
    scStoredProcedures, // CREATE/DROP PROCEDURE (SQLite/Access NAO)
    scUserFunctions,    // CREATE/DROP FUNCTION user-defined (SQLite/Access NAO)
    scCheck             // CHECK constraint
  );
  TSQLCapabilities = set of TSQLCapability;

  { Estilo de paginacao preferido do dialecto. }
  { psTopStartAt (F5 Onda 10, SQL Anywhere 17) - "SELECT TOP n START AT m ...";
    distinto de psTop (SQLServer, TOP puro SEM offset - a base ApplyPagination
    lanca excepcao se AOffset>0). Confirmado empiricamente contra servidor
    real: LIMIT/OFFSET NAO e suportado (SQLCODE=-131, syntax error). }
  TSQLPaginationStyle = (psNone, psLimitOffset, psRowsTo, psOffsetFetch, psTop, psTopStartAt);

  { Tipo de coluna ABSTRACTO (mapeado por dialecto/versao em ColumnTypeFor -
    substitui o TVariableType estatico de Commons.Types, so 2.5.9). }
  TSQLColumnKind = (
    ckInteger, ckBigInt, ckSmallInt, ckDecimal, ckFloat,
    ckBoolean, ckVarChar, ckChar, ckText,
    ckDate, ckTime, ckDateTime, ckBlob, ckIdentity
  );

  { Operador DECOMPOSTO (modelo E3 do benchmark EMS): Prefix + operandos
    intercalados por Relate + Postfix expressa BETWEEN x AND y, CAST(x AS t),
    x || y, ILIKE, ... no MESMO modelo. Arity = nr de operandos (1..3). }
  TSQLOperatorDef = record
    Name    : string;
    Prefix  : string;
    Relate  : string;
    Relate2 : string;  // 2o separador (operadores ternarios: BETWEEN)
    Postfix : string;
    Arity   : Integer;
  end;

  { ===== Onda 5.5 - SchemaSync (dado puro) ===== }

  { Onda 5.5-B - lista ordenada de nomes de coluna (constraint UNIQUE / indice).
    Tipo simples (array of string) para NAO introduzir dependencia de Generics
    neste ficheiro de dado puro (cross-compiler Delphi 12 + FPC 3.3.1 mode delphi). }
  TSchemaColumnNames = array of string;

  { Tipo de mudanca de esquema detectada/aplicada. Nucleo (5.5): tabela + coluna.
    Onda 5.5-B (aditivo, no FIM do enum): +constraint UNIQUE, +indice. }
  TSchemaChangeKind = (sckCreateTable, sckAddColumn, sckAddUnique, sckCreateIndex);

  { Uma diferenca entre o esquema DESEJADO (ISchemaDefinition) e o REAL do banco;
    SQL = DDL gerado pelo IDialect para a aplicar. Name = nome do objecto
    (constraint UNIQUE / indice) nos tipos sckAddUnique/sckCreateIndex; '' nos
    tipos de tabela/coluna (campo Name = aditivo 5.5-B). }
  TSchemaChange = record
    Kind   : TSchemaChangeKind;
    Table  : string;
    Column : string;   // sckAddColumn
    Name   : string;   // sckAddUnique/sckCreateIndex (nome da constraint/indice)
    SQL    : string;   // DDL pronto a executar
  end;

  { Onda 5.5-B - constraint UNIQUE composta DESEJADA sobre uma tabela (dado puro).
    Name = nome da constraint (derivado deterministicamente se vazio); Columns =
    colunas na ordem em que compoem a chave. }
  TSchemaUnique = record
    Name    : string;
    Columns : TSchemaColumnNames;
  end;
  TSchemaUniques = array of TSchemaUnique;

  { Onda 5.5-B - indice DESEJADO (unico ou nao) sobre uma tabela (dado puro). }
  TSchemaIndex = record
    Name    : string;
    Columns : TSchemaColumnNames;
    Unique  : Boolean;
  end;
  TSchemaIndexes = array of TSchemaIndex;

  { Onda S2-b2 (versionamento de banco - triggers/rules/procedures/functions/
    views ao nivel do SCHEMA, ver Database.Schema.pas) - definicao PURA de uma
    VIEW (nome + SELECT + flag de substituicao). TRIGGER/RULE/PROCEDURE/
    FUNCTION ja tinham builder fluente proprio (ITriggerDefinition/
    IRuleDefinition/IRoutineDefinition, Databases.Interfaces, reutilizados
    tal-qual); uma VIEW nao tem builder dedicado (e so nome, SELECT e flag de
    substituicao - IViews.CreateView ja recebe estes 3 valores directamente) -
    dado puro reusando o MESMO padrao nome+dado composto de TSchemaUnique/
    TSchemaIndex (acima) em vez de introduzir um mecanismo novo. }
  TSchemaView = record
    Name      : string;
    SelectSQL : string;
    OrReplace : Boolean;
  end;
  TSchemaViews = array of TSchemaView;

  { ===== Onda 4.2 - status por registo (dado puro) ===== }

  { Estado de operacao de um registo - modelo v1.6.1. }
  TRowStatus = (dsInactive, dsInsert, dsEdit, dsDeleted);

  { ===== Sub-passo 4.5 - validacao no save (dado puro) ===== }

  { Um erro de validacao de campo obrigatorio (ITable.ValidateFields):
    Field = nome da coluna; Message = descricao legivel do problema. }
  TFieldValidationError = record
    Field   : string;
    Message : string;
  end;
  TFieldValidationErrors = array of TFieldValidationError;

  { ===== Onda 6-c - relacoes/FK (dado puro) ===== }

  { Cardinalidade da relacao (perspectiva FromTable -> ToTable). Uma FK
    aponta tipicamente da tabela filha (N) para a tabela pai (1) - rcManyToOne. }
  TRelationCardinality = (rcUnknown, rcOneToOne, rcManyToOne, rcOneToMany);

  { Uma relacao entre 2 tabelas (descoberta via IMetadata.ResolveFK ou
    construida manualmente); consumida pelo IQueryBuilder.JoinByFK/AutoJoin
    para gerar o INNER JOIN correspondente. }
  TRelationInfo = record
    FromTable   : string;
    FromColumn  : string;
    ToTable     : string;
    ToColumn    : string;
    Cardinality : TRelationCardinality;
  end;

  { ===== Onda 6-d - filtro de catalogo (I9, dado puro) ===== }

  { Filtro de catalogo aplicado por IMetadata.Filter (Database.Metadata):
    SchemaName restringe/serve de fallback quando ASchema nao e fornecido
    explicitamente nas chamadas de TableNames/ColumnNames/TableStructure (e,
    por delegacao, ForeignKeys/ResolveFK/TableExists/ColumnExists);
    NamePrefix restringe a listagem de TableNames por prefixo de nome
    (case-insensitive, client-side); IncludeSystemObjects espelha
    IMetadata.IncludeSystemObjects (fonte da verdade unica quando aplicado
    via Filter). Default (record zerado: '', '', False) = sem restricao
    (comportamento pre-existente inalterado). }
  TMetadataFilter = record
    SchemaName           : string;
    NamePrefix           : string;
    IncludeSystemObjects : Boolean;
  end;

  { ===== Onda 6-e Estagio 1 - estatisticas de execucao (I3, dado puro) ===== }

  { Estatisticas do ULTIMO Execute/ExecuteMutation de um IQueryBuilder
    (Database.QueryBuilder.TQueryBuilder.Statistics): RowsAffected = linhas
    afectadas (ExecuteMutation) ou -1 (Execute/SELECT - dataset vivo, nao
    aplicavel); ElapsedMs = duracao da chamada (GetTickCount64); LastSQL = SQL
    efectivamente executado (com placeholders :paramN). Default (record
    zerado: 0, 0, '') = sem execucao ainda (comportamento pre-existente
    inalterado). }
  TQueryStatistics = record
    RowsAffected : Integer;
    ElapsedMs    : Int64;
    LastSQL      : string;
  end;

{$ENDIF}

implementation

end.
