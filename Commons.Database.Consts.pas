{ =============================================================================
  Commons.Database.Consts - Constantes exclusivas do modulo Database (dado)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.1.0
  FileVersion:    1.1.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           15/07/2026

  FASE 5 Onda 5.2: nomes canonicos dos operadores do registry E3 (chaves do
  dicionario dos dialectos - o RENDER por banco vive em cada TDialect*) e
  mensagens do modulo.

  Changelog (file):
  - 1.1.0 (15/07/2026): Onda 6-e Estagio 3 (I19, ADITIVO) -
    DB_ERR_QB_UNKNOWN_OP_MSG (mensagem de IQueryBuilder.WhereOp para nome
    semantico desconhecido).
  - 1.0.0 (12/07/2026): versao inicial (Onda 5.2).
  ============================================================================= }
unit Commons.Database.Consts;

{$I ../ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$IFDEF USE_DATABASE}

const
  { Chaves canonicas do registry de operadores (modelo E3). }
  SQLOP_EQ        = '=';
  SQLOP_NEQ       = '<>';
  SQLOP_GT        = '>';
  SQLOP_GTE       = '>=';
  SQLOP_LT        = '<';
  SQLOP_LTE       = '<=';
  SQLOP_LIKE      = 'LIKE';
  SQLOP_NOT_LIKE  = 'NOT LIKE';
  SQLOP_ILIKE     = 'ILIKE';       // capability scILike (PostgreSQL)
  SQLOP_IN        = 'IN';
  SQLOP_NOT_IN    = 'NOT IN';
  SQLOP_BETWEEN   = 'BETWEEN';     // ternario (Relate/Relate2)
  SQLOP_IS_NULL   = 'IS NULL';     // unario postfix
  SQLOP_NOT_NULL  = 'IS NOT NULL'; // unario postfix
  SQLOP_CAST      = 'CAST';        // CAST(x AS t)
  SQLOP_CONCAT    = 'CONCAT';      // || / CONCAT(,) / + conforme dialecto
  SQLOP_UPPER     = 'UPPER';
  SQLOP_LOWER     = 'LOWER';
  SQLOP_TRIM      = 'TRIM';
  SQLOP_COALESCE  = 'COALESCE';

  { Mensagens do modulo (Onda 5.2). }
  DB_ERR_DIALECT_UNSUPPORTED_MSG = 'Dialecto nao suportado para o banco "%s".';
  DB_ERR_OPERATOR_UNKNOWN_MSG    = 'Operador "%s" nao registado no dialecto %s.';
  DB_ERR_OPERATOR_ARITY_MSG      = 'Operador "%s" espera %d operando(s); recebeu %d.';
  DB_ERR_PAGINATION_MSG          = 'Paginacao nao suportada pelo dialecto %s.';

  { Mensagens do QueryBuilder (Onda 5.3). }
  DB_ERR_QB_NO_TABLE_MSG   = 'QueryBuilder: %s exige uma tabela (From/InsertInto/Update/DeleteFrom).';
  DB_ERR_QB_NO_COLUMNS_MSG = 'QueryBuilder: %s sem colunas/valores definidos.';
  DB_ERR_QB_NO_CONN_MSG    = 'QueryBuilder: %s exige IConnection (para dialecto/execucao).';
  DB_ERR_QB_BAD_STATE_MSG  = 'QueryBuilder: operacao "%s" invalida no modo %s.';
  DB_ERR_QB_UNKNOWN_OP_MSG = 'QueryBuilder: WhereOp - operador semantico "%s" desconhecido.';

  { Mensagens do QueryTransformer (Onda 5.4). }
  DB_ERR_QT_NO_SOURCE_MSG  = 'QueryTransformer: %s exige uma query base (Source).';
  DB_ERR_QT_NO_CONN_MSG    = 'QueryTransformer: %s exige IConnection na query base.';

  { Alias por defeito da derived table do QueryTransformer. }
  QT_SUBQUERY_ALIAS = 'q';

  { SchemaSync (Onda 5.5). }
  SCHEMA_VERSION_TABLE     = 'schema_version'; // tabela de auditoria das migracoes
  DB_ERR_SCHEMA_NO_CONN_MSG = 'SchemaSync: %s exige IConnection.';
  DB_ERR_SCHEMA_NO_TABLE_MSG = 'SchemaSync: definicao de tabela "%s" sem colunas.';
  DB_ERR_SCHEMA_APPLY_MSG  = 'SchemaSync: falha ao aplicar "%s": %s';
  { R2-B - verificacao pos-DDL (Sync): shape vivo != pretendido }
  DB_ERR_SCHEMA_VERIFY_MSG = 'SchemaSync: verificacao pos-DDL falhou - %d objecto(s) ainda em falta apos aplicar (1o: %s "%s"). O DDL executou mas o catalogo nao reflecte o esquema pretendido.';
  { F5-FU.3 - DDL abortado por lock (Firebird NO WAIT) }
  DB_ERR_OBJECT_LOCKED_MSG = 'DDL abortado: objecto "%s" bloqueado por outra transaccao (NO WAIT). Causa: %s';

  { T5 - templates de ToHumanText (linguagem natural pt-PT; sem ML). }
  QT_HT_AND      = ' e ';
  QT_HT_EQUAL    = '%s igual a %s';
  QT_HT_NOTEQUAL = '%s diferente de %s';
  QT_HT_GT       = '%s maior que %s';
  QT_HT_GE       = '%s maior ou igual a %s';
  QT_HT_LT       = '%s menor que %s';
  QT_HT_LE       = '%s menor ou igual a %s';
  QT_HT_BETWEEN  = '%s entre %s e %s';
  QT_HT_CONTAINS = '%s contém "%s"';
  QT_HT_STARTS   = '%s começa por "%s"';
  QT_HT_ENDS     = '%s termina em "%s"';
  QT_HT_IN       = '%s em (%s)';
  QT_HT_NULL     = '%s vazio';
  QT_HT_NOTNULL  = '%s preenchido';
  QT_HT_EMPTY    = '(sem filtros)';

{$ENDIF}

implementation

end.
