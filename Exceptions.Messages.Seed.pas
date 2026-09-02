{ =============================================================================
  Exceptions.Messages.Seed - Semeadura do catálogo de mensagens (tabela `messages`)

  Descrição:
  Popula a tabela `messages` com TODOS os códigos MMXXXX declarados em
  `src/Exceptions/*.pas`. GERADO a partir do SSOT Pascal — não é uma lista
  mantida à mão, logo não pode divergir das constantes.

  Regenerar:  python .workspace/scripts/gera_seed.py

  HONESTIDADE SOBRE O CONTEÚDO: só 126 dos 199 códigos têm mensagem REAL (as
  constantes `MSG_*` que existem em `Exceptions.Parameters.pas`, emparelhadas
  pelo sufixo). Os restantes 73 ficam com o próprio `constant_name` como texto,
  de propósito: inventar centenas de mensagens seria pior que a ausência delas —
  daria a ilusão de um catálogo completo. Ficam listados no relatório de lacunas
  para tradução posterior (as 546 linhas do ExceptionORM que o plano F15 previa
  colher NÃO estão disponíveis nesta máquina — `E:\CSL\ExceptionORM` não existe).

  Idioma: pt-BR (DEFAULT_LANGUAGE). en/es ficam para quando houver tradução real.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.2.0
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           01/09/2026

  Changelog (file):
  - 1.1.0 (01/09/2026): F15 — ZERO SQL. O DELETE+INSERT concatenados a mao
    dao lugar a ITable.ExecuteDelete/ExecuteInsert (modulo Database), que
    citam os identificadores pelo dialecto do engine. Sem isso `message`,
    palavra reservada no SQL Anywhere, partia o DML nesse banco. Ordem do
    owner (01/09): "o insert tambem tem que usar o modulo database/connection".
  - 1.0.0 (01/09/2026): F15 Onda 15.5 — geração inicial a partir do SSOT.
  ============================================================================= }
unit Exceptions.Messages.Seed;

{$I ..\ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Commons.Types,
  Connections.Interfaces;

type
  TSeedEntry = record
    Code        : Integer;
    ConstantName: string;
    Message     : string;
    Module      : string;
  end;

const
  SEED_LANGUAGE = 'pt-BR';
  SEED_COUNT    = 199;

{ Semeia o catálogo. Idempotente: apaga a chave (code, language) antes de
  inserir, respeitando a PK composta. Devolve quantas linhas escreveu. }
function SeedMessages(const AConnection: IConnection;
  const ALanguage: string = SEED_LANGUAGE): Integer;

function SeedEntries: TArray<TSeedEntry>;

implementation

uses
{$IF DEFINED(FPC)}
  SysUtils, Windows,
{$ELSE}
  System.SysUtils, Winapi.Windows,
{$ENDIF}
  Commons.Consts,
  Exceptions.Base,
  { INSERT/DELETE PELO MODULO DATABASE (ordem do owner, 01/09: "o insert
    tambem tem que usar o modulo database/connection"; "o exception e
    usuario do modulo Database/Connections"). Zero SQL escrito a mao. }
  Databases.Interfaces,
  Database.QueryBuilder;

type
  TSeedArray = array[0..SEED_COUNT - 1] of TSeedEntry;

const
  SEED_DATA: TSeedArray = (
    (Code: 400003; ConstantName: 'ERR_CONNECTION_ALREADY_CONNECTED'; Message: 'ERR_CONNECTION_ALREADY_CONNECTED'; Module: 'Core'),
    (Code: 400005; ConstantName: 'ERR_DISCONNECT_FAILED'; Message: 'ERR_DISCONNECT_FAILED'; Module: 'Core'),
    (Code: 400011; ConstantName: 'ERR_SQL_COMMAND_FAILED'; Message: 'ERR_SQL_COMMAND_FAILED'; Module: 'Core'),
    (Code: 400012; ConstantName: 'ERR_TRANSACTION_NOT_STARTED'; Message: 'ERR_TRANSACTION_NOT_STARTED'; Module: 'Core'),
    (Code: 400013; ConstantName: 'ERR_TRANSACTION_ALREADY_STARTED'; Message: 'ERR_TRANSACTION_ALREADY_STARTED'; Module: 'Core'),
    (Code: 400014; ConstantName: 'ERR_ENGINE_NOT_SUPPORTED'; Message: 'ERR_ENGINE_NOT_SUPPORTED'; Module: 'Core'),
    (Code: 400015; ConstantName: 'ERR_DATABASE_TYPE_NOT_SUPPORTED'; Message: 'ERR_DATABASE_TYPE_NOT_SUPPORTED'; Module: 'Core'),
    (Code: 400016; ConstantName: 'ERR_CONFIG_FILE_NOT_FOUND'; Message: 'ERR_CONFIG_FILE_NOT_FOUND'; Module: 'Core'),
    (Code: 400017; ConstantName: 'ERR_CONFIG_INVALID'; Message: 'ERR_CONFIG_INVALID'; Module: 'Core'),
    (Code: 410001; ConstantName: 'ERR_DATABASE_NO_CONNECTION'; Message: 'provider/builder sem IConnection injectada'; Module: 'Database'),
    (Code: 410002; ConstantName: 'ERR_DATABASE_INVALID_NAME'; Message: 'tabela/coluna/schema vazio ou invalido'; Module: 'Database'),
    (Code: 410003; ConstantName: 'ERR_DATABASE_UNSAFE_DML'; Message: 'Table DML: UPDATE/DELETE sem WHERE bloqueado antes de executar'; Module: 'Database'),
    (Code: 410004; ConstantName: 'ERR_DATABASE_VALIDATION'; Message: 'Table DML: obrigatorio(s) em falta no INSERT/UPDATE (Execute/Save)'; Module: 'Database'),
    (Code: 410005; ConstantName: 'ERR_DATABASE_READONLY'; Message: 'Table DML: guarda read-only/soft-deleted (equiv. FDeletedBlock v1.6.1)'; Module: 'Database'),
    (Code: 410006; ConstantName: 'ERR_DATABASE_INVALID_STATUS'; Message: 'Table DML: Status (dsEdit/dsDeleted) sem PK preenchida'; Module: 'Database'),
    (Code: 410010; ConstantName: 'ERR_DATABASE_METADATA'; Message: 'falha generica ao ler o catalogo'; Module: 'Database'),
    (Code: 410011; ConstantName: 'ERR_DATABASE_METADATA_FILE'; Message: 'Onda 6-d (I6): falha de E/S do snapshot (SaveToFile/LoadFromFile)'; Module: 'Database'),
    (Code: 410020; ConstantName: 'ERR_DATABASE_DIALECT'; Message: 'banco sem dialecto registado'; Module: 'Database'),
    (Code: 410021; ConstantName: 'ERR_DATABASE_OPERATOR'; Message: 'operador nao registado no dialecto'; Module: 'Database'),
    (Code: 410022; ConstantName: 'ERR_DATABASE_OPERATOR_ARITY'; Message: 'nr de operandos errado'; Module: 'Database'),
    (Code: 410023; ConstantName: 'ERR_DATABASE_PAGINATION'; Message: 'paginacao nao suportada'; Module: 'Database'),
    (Code: 410030; ConstantName: 'ERR_DATABASE_OBJECT_LOCKED'; Message: 'F5-FU.3: DDL abortado por lock (NO WAIT) em vez de pendurar - EDatabaseObjectLockedException'; Module: 'Database'),
    (Code: 410031; ConstantName: 'ERR_DATABASE_SCHEMA_VERIFICATION'; Message: 'R2-B: shape vivo != pretendido apos Sync (DDL nao produziu o resultado) - EDatabaseSchemaVerificationException'; Module: 'Database'),
    (Code: 410070; ConstantName: 'ERR_DATABASE_ENTITYMANAGER'; Message: 'falha generica do EntityManager (fonte legada reservava 70XXX pre-norma)'; Module: 'Database'),
    (Code: 410080; ConstantName: 'ERR_DATABASE_QUERYBUILDER'; Message: 'estado invalido do builder (falta tabela/colunas/valores)'; Module: 'Database'),
    (Code: 410081; ConstantName: 'ERR_DATABASE_QB_UNKNOWN_OP'; Message: 'Onda 6-e Estagio 3 (I19): WhereOp com nome semantico desconhecido'; Module: 'Database'),
    (Code: 410085; ConstantName: 'ERR_DATABASE_TRANSFORMER'; Message: 'estado invalido do transformer (sem source)'; Module: 'Database'),
    (Code: 410086; ConstantName: 'ERR_DATABASE_SCHEMA'; Message: 'falha de definicao/migracao de esquema'; Module: 'Database'),
    (Code: 410095; ConstantName: 'ERR_DATABASE_ASYNC'; Message: 'excecao capturada na thread de fundo, relancada por IORMTask<T>.Await'; Module: 'Database'),
    (Code: 440001; ConstantName: 'ERR_SERIALIZE_GENERIC'; Message: 'mensagens ad-hoc (nao mapeadas a uma constante propria)'; Module: 'Serialize'),
    (Code: 440002; ConstantName: 'ERR_SERIALIZE_FIELD_TYPE_NOT_FOUND'; Message: 'TField.DataType sem mapeamento JSON (export/import)'; Module: 'Serialize'),
    (Code: 440003; ConstantName: 'ERR_SERIALIZE_DATASET_ACTIVATED'; Message: 'LoadStructure exige DataSet inactivo'; Module: 'Serialize'),
    (Code: 440004; ConstantName: 'ERR_SERIALIZE_PREDEFINED_FIELDS'; Message: 'LoadStructure exige DataSet sem campos predefinidos'; Module: 'Serialize'),
    (Code: 440005; ConstantName: 'ERR_SERIALIZE_NO_DEFINED_FIELDS'; Message: 'Validate exige DataSet com campos definidos'; Module: 'Serialize'),
    (Code: 440006; ConstantName: 'ERR_SERIALIZE_JSON_NOT_DEFINED'; Message: 'TJSONSerialize sem JSONObject/JSONArray atribuido'; Module: 'Serialize'),
    (Code: 440007; ConstantName: 'ERR_SERIALIZE_SIZE_NOT_DEFINED'; Message: 'campo string/wide sem Size definido (NewDataSetField)'; Module: 'Serialize'),
    (Code: 440008; ConstantName: 'ERR_SERIALIZE_STRUCTURE_JSON_ARRAY_ONLY'; Message: 'LoadStructure so aceita JSONArray'; Module: 'Serialize'),
    (Code: 440009; ConstantName: 'ERR_SERIALIZE_INVALID_FIELD_COUNT'; Message: 'JSONValueToDataSet exige DataSet com exactamente 1 campo'; Module: 'Serialize'),
    (Code: 450001; ConstantName: 'ERR_POOL_ACQUIRE_TIMEOUT'; Message: 'ERR_POOL_ACQUIRE_TIMEOUT'; Module: 'PoolConnections'),
    (Code: 450002; ConstantName: 'ERR_POOL_SHUTDOWN'; Message: 'ERR_POOL_SHUTDOWN'; Module: 'PoolConnections'),
    (Code: 450003; ConstantName: 'ERR_POOL_CONFIG_INVALID'; Message: 'ERR_POOL_CONFIG_INVALID'; Module: 'PoolConnections'),
    (Code: 450004; ConstantName: 'ERR_POOL_CONNECTION_INVALID'; Message: 'ERR_POOL_CONNECTION_INVALID'; Module: 'PoolConnections'),
    (Code: 450005; ConstantName: 'ERR_POOL_DATABASE_NOT_REGISTERED'; Message: 'ERR_POOL_DATABASE_NOT_REGISTERED'; Module: 'PoolConnections'),
    (Code: 450006; ConstantName: 'ERR_POOL_HARDWARE_CAP'; Message: 'ERR_POOL_HARDWARE_CAP'; Module: 'PoolConnections'),
    (Code: 500001; ConstantName: 'ERR_CONNECTION_NOT_ASSIGNED'; Message: 'Conexao nao foi inicializada. Use TParameters.New() para criar uma instancia.'; Module: 'Core'),
    (Code: 500002; ConstantName: 'ERR_CONNECTION_FAILED'; Message: 'Falha ao conectar ao banco de dados. Verifique as configuracoes de conexao (Host, Port, Username, Password, Database).'; Module: 'Core'),
    (Code: 500003; ConstantName: 'ERR_CONNECTION_ALREADY_EXISTS'; Message: 'ERR_CONNECTION_ALREADY_EXISTS'; Module: 'Parameters'),
    (Code: 500004; ConstantName: 'ERR_CONNECTION_NOT_CONNECTED'; Message: 'Nao ha conexao ativa com o banco de dados. Use Connect() para estabelecer conexao.'; Module: 'Core'),
    (Code: 500005; ConstantName: 'ERR_DISCONNECTION_FAILED'; Message: 'Falha ao desconectar do banco de dados.'; Module: 'Parameters'),
    (Code: 500006; ConstantName: 'ERR_CONNECTION_TIMEOUT'; Message: 'Timeout ao conectar ao banco de dados. Verifique se o servidor esta acessivel.'; Module: 'Core'),
    (Code: 500007; ConstantName: 'ERR_CONNECTION_INVALID_CREDENTIALS'; Message: 'Credenciais invalidas. Verifique Username e Password.'; Module: 'Core'),
    (Code: 500008; ConstantName: 'ERR_CONNECTION_DATABASE_NOT_FOUND'; Message: 'Banco de dados "%s" nao encontrado. Verifique o nome do banco ou liste os bancos disponiveis.'; Module: 'Core'),
    (Code: 500009; ConstantName: 'ERR_CONNECTION_DRIVE_NOT_READY'; Message: 'Drive nao esta acessivel ou nao existe. Verifique o caminho do arquivo.'; Module: 'Parameters'),
    (Code: 500201; ConstantName: 'ERR_PARAMETER_NAME_EMPTY'; Message: 'O nome do parametro nao pode estar vazio.'; Module: 'Parameters'),
    (Code: 500202; ConstantName: 'ERR_PARAMETER_NAME_INVALID'; Message: 'Nome de parametro invalido: "%s". Use apenas letras, numeros e underscores.'; Module: 'Parameters'),
    (Code: 500203; ConstantName: 'ERR_PARAMETER_VALUE_INVALID'; Message: 'Valor do parametro invalido para o tipo %s: "%s"'; Module: 'Parameters'),
    (Code: 500204; ConstantName: 'ERR_PARAMETER_REQUIRED'; Message: 'O parametro "%s" e obrigatorio.'; Module: 'Parameters'),
    (Code: 500205; ConstantName: 'ERR_TABLE_NAME_EMPTY'; Message: 'O nome da tabela nao pode estar vazio. Use TableName() para definir.'; Module: 'Parameters'),
    (Code: 500206; ConstantName: 'ERR_SCHEMA_NAME_EMPTY'; Message: 'O nome do schema nao pode estar vazio. Use Schema() para definir.'; Module: 'Parameters'),
    (Code: 500207; ConstantName: 'ERR_CONTRATO_ID_INVALID'; Message: 'Contrato ID deve ser um numero valido (>= 0).'; Module: 'Parameters'),
    (Code: 500208; ConstantName: 'ERR_PRODUTO_ID_INVALID'; Message: 'Produto ID deve ser um numero valido (>= 0).'; Module: 'Parameters'),
    (Code: 500209; ConstantName: 'ERR_ORDEM_INVALID'; Message: 'Ordem deve ser um numero valido (>= 0).'; Module: 'Parameters'),
    (Code: 500210; ConstantName: 'ERR_TITULO_EMPTY'; Message: 'O titulo nao pode estar vazio.'; Module: 'Parameters'),
    (Code: 500211; ConstantName: 'ERR_CHAVE_EMPTY'; Message: 'A chave nao pode estar vazia.'; Module: 'Parameters'),
    (Code: 500212; ConstantName: 'ERR_CHAVE_INVALID'; Message: 'Chave invalida: "%s". Use apenas letras, numeros e underscores.'; Module: 'Parameters'),
    (Code: 500301; ConstantName: 'ERR_PARAMETER_NOT_FOUND'; Message: 'Parametro "%s" nao encontrado na tabela %s.'; Module: 'Parameters'),
    (Code: 500302; ConstantName: 'ERR_PARAMETER_ALREADY_EXISTS'; Message: 'Parametro "%s" ja existe na tabela %s.'; Module: 'Parameters'),
    (Code: 500303; ConstantName: 'ERR_INSERT_FAILED'; Message: 'Falha ao inserir parametro "%s": %s'; Module: 'Parameters'),
    (Code: 500304; ConstantName: 'ERR_UPDATE_FAILED'; Message: 'Falha ao atualizar parametro "%s": %s'; Module: 'Parameters'),
    (Code: 500305; ConstantName: 'ERR_DELETE_FAILED'; Message: 'Falha ao deletar parametro "%s": %s'; Module: 'Parameters'),
    (Code: 500306; ConstantName: 'ERR_LIST_FAILED'; Message: 'Falha ao listar parametros: %s'; Module: 'Parameters'),
    (Code: 500307; ConstantName: 'ERR_GET_FAILED'; Message: 'Falha ao obter parametro "%s": %s'; Module: 'Parameters'),
    (Code: 500308; ConstantName: 'ERR_COUNT_FAILED'; Message: 'Falha ao contar parametros: %s'; Module: 'Parameters'),
    (Code: 500309; ConstantName: 'ERR_EXISTS_FAILED'; Message: 'Falha ao verificar existencia do parametro "%s": %s'; Module: 'Parameters'),
    (Code: 500310; ConstantName: 'ERR_REFRESH_FAILED'; Message: 'Falha ao renovar dados: %s'; Module: 'Parameters'),
    (Code: 500401; ConstantName: 'ERR_ENGINE_NOT_DEFINED'; Message: 'Engine de banco de dados nao definido. Use Engine() para configurar.'; Module: 'Parameters'),
    (Code: 500402; ConstantName: 'ERR_DATABASE_TYPE_NOT_DEFINED'; Message: 'Tipo de banco de dados nao definido. Use DatabaseType() para configurar.'; Module: 'Parameters'),
    (Code: 500403; ConstantName: 'ERR_HOST_NOT_DEFINED'; Message: 'Host do servidor nao definido. Use Host() para configurar.'; Module: 'Parameters'),
    (Code: 500404; ConstantName: 'ERR_DATABASE_NOT_DEFINED'; Message: 'Nome do banco de dados nao definido. Use Database() para configurar.'; Module: 'Parameters'),
    (Code: 500405; ConstantName: 'ERR_INVALID_CONFIGURATION'; Message: 'Configuracao invalida: %s'; Module: 'Parameters'),
    (Code: 500406; ConstantName: 'ERR_PORT_INVALID'; Message: 'Porta deve ser um numero valido entre 1 e 65535.'; Module: 'Parameters'),
    (Code: 500407; ConstantName: 'ERR_USERNAME_NOT_DEFINED'; Message: 'Username nao definido. Use Username() para configurar.'; Module: 'Parameters'),
    (Code: 500408; ConstantName: 'ERR_SCHEMA_NOT_DEFINED'; Message: 'Schema nao definido. Use Schema() para configurar (obrigatorio para %s).'; Module: 'Parameters'),
    (Code: 500501; ConstantName: 'ERR_FILE_NOT_FOUND'; Message: 'Arquivo nao encontrado: %s'; Module: 'Parameters'),
    (Code: 500502; ConstantName: 'ERR_FILE_CANNOT_READ'; Message: 'Nao foi possivel ler o arquivo: %s'; Module: 'Parameters'),
    (Code: 500503; ConstantName: 'ERR_FILE_CANNOT_WRITE'; Message: 'Nao foi possivel escrever no arquivo: %s'; Module: 'Parameters'),
    (Code: 500504; ConstantName: 'ERR_FILE_CANNOT_CREATE'; Message: 'Nao foi possivel criar o arquivo: %s'; Module: 'Parameters'),
    (Code: 500505; ConstantName: 'ERR_FILE_ACCESS_DENIED'; Message: 'Acesso negado ao arquivo: %s'; Module: 'Parameters'),
    (Code: 500506; ConstantName: 'ERR_FILE_LOCKED'; Message: 'Arquivo esta sendo usado por outro processo: %s'; Module: 'Parameters'),
    (Code: 500507; ConstantName: 'ERR_FILE_INVALID_FORMAT'; Message: 'Formato de arquivo invalido: %s'; Module: 'Parameters'),
    (Code: 500508; ConstantName: 'ERR_FILE_ENCODING_INVALID'; Message: 'Encoding do arquivo invalido ou nao suportado: %s'; Module: 'Parameters'),
    (Code: 500509; ConstantName: 'ERR_FILE_PATH_EMPTY'; Message: 'Caminho do arquivo nao pode estar vazio.'; Module: 'Parameters'),
    (Code: 500510; ConstantName: 'ERR_FILE_PATH_INVALID'; Message: 'Caminho do arquivo invalido: %s'; Module: 'Parameters'),
    (Code: 500511; ConstantName: 'ERR_DIRECTORY_NOT_EXISTS'; Message: 'Diretorio nao existe: %s'; Module: 'Parameters'),
    (Code: 500512; ConstantName: 'ERR_DIRECTORY_CANNOT_CREATE'; Message: 'Nao foi possivel criar o diretorio: %s'; Module: 'Parameters'),
    (Code: 500601; ConstantName: 'ERR_INI_FILE_NOT_FOUND'; Message: 'Arquivo INI nao encontrado: %s'; Module: 'Parameters'),
    (Code: 500602; ConstantName: 'ERR_INI_FILE_CANNOT_READ'; Message: 'Nao foi possivel ler o arquivo INI: %s'; Module: 'Parameters'),
    (Code: 500603; ConstantName: 'ERR_INI_FILE_CANNOT_WRITE'; Message: 'Nao foi possivel escrever no arquivo INI: %s'; Module: 'Parameters'),
    (Code: 500604; ConstantName: 'ERR_INI_SECTION_EMPTY'; Message: 'Secao do INI nao pode estar vazia. Use Section() para definir.'; Module: 'Parameters'),
    (Code: 500605; ConstantName: 'ERR_INI_SECTION_NOT_FOUND'; Message: 'Secao "%s" nao encontrada no arquivo INI.'; Module: 'Parameters'),
    (Code: 500606; ConstantName: 'ERR_INI_KEY_NOT_FOUND'; Message: 'Chave "%s" nao encontrada na secao "%s".'; Module: 'Parameters'),
    (Code: 500607; ConstantName: 'ERR_INI_KEY_ALREADY_EXISTS'; Message: 'Chave "%s" ja existe na secao "%s".'; Module: 'Parameters'),
    (Code: 500608; ConstantName: 'ERR_INI_INVALID_FORMAT'; Message: 'Formato do arquivo INI invalido: %s'; Module: 'Parameters'),
    (Code: 500701; ConstantName: 'ERR_JSON_FILE_NOT_FOUND'; Message: 'Arquivo JSON nao encontrado: %s'; Module: 'Parameters'),
    (Code: 500702; ConstantName: 'ERR_JSON_FILE_CANNOT_READ'; Message: 'Nao foi possivel ler o arquivo JSON: %s'; Module: 'Parameters'),
    (Code: 500703; ConstantName: 'ERR_JSON_FILE_CANNOT_WRITE'; Message: 'Nao foi possivel escrever no arquivo JSON: %s'; Module: 'Parameters'),
    (Code: 500704; ConstantName: 'ERR_JSON_INVALID_FORMAT'; Message: 'Formato JSON invalido: %s'; Module: 'Parameters'),
    (Code: 500705; ConstantName: 'ERR_JSON_INVALID_ENCODING'; Message: 'Encoding do arquivo JSON invalido. Suportado: UTF-8 (com/sem BOM) ou ANSI.'; Module: 'Parameters'),
    (Code: 500706; ConstantName: 'ERR_JSON_OBJECT_NOT_FOUND'; Message: 'Objeto JSON "%s" nao encontrado.'; Module: 'Parameters'),
    (Code: 500707; ConstantName: 'ERR_JSON_KEY_NOT_FOUND'; Message: 'Chave "%s" nao encontrada no objeto "%s".'; Module: 'Parameters'),
    (Code: 500708; ConstantName: 'ERR_JSON_KEY_ALREADY_EXISTS'; Message: 'Chave "%s" ja existe no objeto "%s".'; Module: 'Parameters'),
    (Code: 500709; ConstantName: 'ERR_JSON_OBJECT_NAME_EMPTY'; Message: 'Nome do objeto JSON nao pode estar vazio. Use ObjectName() para definir.'; Module: 'Parameters'),
    (Code: 500710; ConstantName: 'ERR_JSON_PARSE_ERROR'; Message: 'Erro ao parsear arquivo JSON: %s'; Module: 'Parameters'),
    (Code: 500711; ConstantName: 'ERR_JSON_EMPTY'; Message: 'Arquivo JSON esta vazio ou nao contem dados validos.'; Module: 'Parameters'),
    (Code: 500801; ConstantName: 'ERR_IMPORT_FAILED'; Message: 'Falha ao importar dados: %s'; Module: 'Parameters'),
    (Code: 500802; ConstantName: 'ERR_EXPORT_FAILED'; Message: 'Falha ao exportar dados: %s'; Module: 'Parameters'),
    (Code: 500803; ConstantName: 'ERR_IMPORT_SOURCE_NOT_FOUND'; Message: 'Fonte de importacao nao encontrada ou nao configurada.'; Module: 'Parameters'),
    (Code: 500804; ConstantName: 'ERR_IMPORT_TARGET_NOT_FOUND'; Message: 'Destino de importacao nao encontrado ou nao configurado.'; Module: 'Parameters'),
    (Code: 500805; ConstantName: 'ERR_EXPORT_SOURCE_NOT_FOUND'; Message: 'Fonte de exportacao nao encontrada ou nao configurada.'; Module: 'Parameters'),
    (Code: 500806; ConstantName: 'ERR_EXPORT_TARGET_NOT_FOUND'; Message: 'Destino de exportacao nao encontrado ou nao configurado.'; Module: 'Parameters'),
    (Code: 500807; ConstantName: 'ERR_IMPORT_INVALID_DATA'; Message: 'Dados invalidos para importacao: %s'; Module: 'Parameters'),
    (Code: 500808; ConstantName: 'ERR_EXPORT_INVALID_DATA'; Message: 'Dados invalidos para exportacao: %s'; Module: 'Parameters'),
    (Code: 500809; ConstantName: 'ERR_IMPORT_OVERWRITE_DENIED'; Message: 'Importacao cancelada pelo usuario (sobrescrita negada).'; Module: 'Parameters'),
    (Code: 501001; ConstantName: 'ERR_SQL_EXECUTION_FAILED'; Message: 'Falha ao executar comando SQL: %s'; Module: 'Core'),
    (Code: 501002; ConstantName: 'ERR_SQL_QUERY_FAILED'; Message: 'Falha ao executar consulta SQL: %s'; Module: 'Core'),
    (Code: 501003; ConstantName: 'ERR_SQL_INVALID'; Message: 'SQL invalido: %s'; Module: 'Parameters'),
    (Code: 501004; ConstantName: 'ERR_SQL_INJECTION_DETECTED'; Message: 'ERR_SQL_INJECTION_DETECTED'; Module: 'Parameters'),
    (Code: 501005; ConstantName: 'ERR_SQL_TABLE_NOT_EXISTS'; Message: 'Tabela "%s" nao existe. Use CreateTable() para criar a tabela.'; Module: 'Core'),
    (Code: 501006; ConstantName: 'ERR_SQL_TABLE_CREATE_FAILED'; Message: 'Falha ao criar tabela "%s": %s'; Module: 'Core'),
    (Code: 501007; ConstantName: 'ERR_SQL_TABLE_DROP_FAILED'; Message: 'Falha ao remover tabela "%s": %s'; Module: 'Parameters'),
    (Code: 501008; ConstantName: 'ERR_SQL_TABLE_STRUCTURE_INVALID'; Message: 'Estrutura da tabela "%s" incompativel. %s'; Module: 'Parameters'),
    (Code: 501009; ConstantName: 'ERR_SQL_COLUMN_NOT_FOUND'; Message: 'Coluna "%s" nao encontrada na tabela "%s".'; Module: 'Parameters'),
    (Code: 501010; ConstantName: 'ERR_SQL_COLUMN_TYPE_MISMATCH'; Message: 'Coluna "%s" deve ser do tipo %s, mas encontrado: %s'; Module: 'Parameters'),
    (Code: 501011; ConstantName: 'ERR_SQL_PRIMARY_KEY_MISSING'; Message: 'Coluna "%s" deve ser PRIMARY KEY.'; Module: 'Parameters'),
    (Code: 501012; ConstantName: 'ERR_SQL_GENERATOR_EXISTS'; Message: 'Generator "%s" ja existe no banco de dados.'; Module: 'Parameters'),
    (Code: 501013; ConstantName: 'ERR_SQL_TRIGGER_EXISTS'; Message: 'Trigger "%s" ja existe no banco de dados.'; Module: 'Parameters'),
    (Code: 501014; ConstantName: 'ERR_SQL_GENERATOR_NOT_FOUND'; Message: 'ERR_SQL_GENERATOR_NOT_FOUND'; Module: 'Parameters'),
    (Code: 501015; ConstantName: 'ERR_SQL_TRIGGER_NOT_FOUND'; Message: 'ERR_SQL_TRIGGER_NOT_FOUND'; Module: 'Parameters'),
    (Code: 509001; ConstantName: 'ERR_ATTRIBUTE_PARAMETER_NOT_FOUND_CODE'; Message: 'ERR_ATTRIBUTE_PARAMETER_NOT_FOUND_CODE'; Module: 'Parameters'),
    (Code: 509002; ConstantName: 'ERR_ATTRIBUTE_PARAMETER_KEY_NOT_FOUND_CODE'; Message: 'ERR_ATTRIBUTE_PARAMETER_KEY_NOT_FOUND_CODE'; Module: 'Parameters'),
    (Code: 509003; ConstantName: 'ERR_ATTRIBUTE_INVALID_CLASS_CODE'; Message: 'ERR_ATTRIBUTE_INVALID_CLASS_CODE'; Module: 'Parameters'),
    (Code: 509004; ConstantName: 'ERR_ATTRIBUTE_RTTI_NOT_AVAILABLE_CODE'; Message: 'ERR_ATTRIBUTE_RTTI_NOT_AVAILABLE_CODE'; Module: 'Parameters'),
    (Code: 509005; ConstantName: 'ERR_ATTRIBUTE_INVALID_PROPERTY_CODE'; Message: 'ERR_ATTRIBUTE_INVALID_PROPERTY_CODE'; Module: 'Parameters'),
    (Code: 509006; ConstantName: 'ERR_ATTRIBUTE_REQUIRED_PARAMETER_NOT_FOUND_CODE'; Message: 'ERR_ATTRIBUTE_REQUIRED_PARAMETER_NOT_FOUND_CODE'; Module: 'Parameters'),
    (Code: 509007; ConstantName: 'ERR_ATTRIBUTE_PARSING_FAILED_CODE'; Message: 'ERR_ATTRIBUTE_PARSING_FAILED_CODE'; Module: 'Parameters'),
    (Code: 509008; ConstantName: 'ERR_ATTRIBUTE_MAPPING_FAILED_CODE'; Message: 'ERR_ATTRIBUTE_MAPPING_FAILED_CODE'; Module: 'Parameters'),
    (Code: 509009; ConstantName: 'ERR_ATTRIBUTE_VALIDATION_FAILED_CODE'; Message: 'ERR_ATTRIBUTE_VALIDATION_FAILED_CODE'; Module: 'Parameters'),
    (Code: 509010; ConstantName: 'ERR_ATTRIBUTE_VALUE_CONVERSION_FAILED_CODE'; Message: 'ERR_ATTRIBUTE_VALUE_CONVERSION_FAILED_CODE'; Module: 'Parameters'),
    (Code: 600001; ConstantName: 'ERR_ATTRIBUTERS_NO_TABLE_ATTRIBUTE'; Message: 'ERR_ATTRIBUTERS_NO_TABLE_ATTRIBUTE'; Module: 'Attributers'),
    (Code: 600002; ConstantName: 'ERR_ATTRIBUTERS_RTTI_NOT_AVAILABLE'; Message: 'ERR_ATTRIBUTERS_RTTI_NOT_AVAILABLE'; Module: 'Attributers'),
    (Code: 930001; ConstantName: 'ERR_LOGGERS_CHANNEL_UNAVAILABLE'; Message: 'ERR_LOGGERS_CHANNEL_UNAVAILABLE'; Module: 'Loggers'),
    (Code: 930002; ConstantName: 'ERR_LOGGERS_WRITE_FAILED'; Message: 'ERR_LOGGERS_WRITE_FAILED'; Module: 'Loggers'),
    (Code: 930003; ConstantName: 'ERR_LOGGERS_CONFIG_INVALID'; Message: 'ERR_LOGGERS_CONFIG_INVALID'; Module: 'Loggers'),
    (Code: 930004; ConstantName: 'ERR_LOGGERS_QUEUE_FULL'; Message: 'ERR_LOGGERS_QUEUE_FULL'; Module: 'Loggers'),
    (Code: 930005; ConstantName: 'ERR_LOGGERS_CHANNEL_INIT_FAILED'; Message: 'ERR_LOGGERS_CHANNEL_INIT_FAILED'; Module: 'Loggers'),
    (Code: 930006; ConstantName: 'ERR_LOGGERS_ATTRIBUTE_NOT_FOUND'; Message: '930006 (FASE 6 Onda 6.3)'; Module: 'Loggers'),
    (Code: 930007; ConstantName: 'ERR_LOGGERS_ATTRIBUTE_RTTI_NOT_AVAILABLE'; Message: 'ERR_LOGGERS_ATTRIBUTE_RTTI_NOT_AVAILABLE'; Module: 'Loggers'),
    (Code: 960001; ConstantName: 'ERR_PRINTERS_CONNECTION_NOT_ASSIGNED'; Message: 'ERR_PRINTERS_CONNECTION_NOT_ASSIGNED'; Module: 'Printers'),
    (Code: 960002; ConstantName: 'ERR_PRINTERS_ENGINE_NOT_ENABLED'; Message: '----- Template (960101-960119) -----'; Module: 'Printers'),
    (Code: 960101; ConstantName: 'ERR_PRINTERS_TEMPLATE_NOT_INFORMED'; Message: 'ERR_PRINTERS_TEMPLATE_NOT_INFORMED'; Module: 'Printers'),
    (Code: 960102; ConstantName: 'ERR_PRINTERS_TEMPLATE_NOT_FOUND'; Message: 'ERR_PRINTERS_TEMPLATE_NOT_FOUND'; Module: 'Printers'),
    (Code: 960103; ConstantName: 'ERR_PRINTERS_TEMPLATE_LOAD_FAILED'; Message: '----- Fonte de dados (960201-960219) -----'; Module: 'Printers'),
    (Code: 960201; ConstantName: 'ERR_PRINTERS_DATASOURCE_EMPTY'; Message: 'ERR_PRINTERS_DATASOURCE_EMPTY'; Module: 'Printers'),
    (Code: 960202; ConstantName: 'ERR_PRINTERS_QUERY_EXECUTE_FAILED'; Message: '----- Render (960301-960319) -----'; Module: 'Printers'),
    (Code: 960301; ConstantName: 'ERR_PRINTERS_RENDER_FAILED'; Message: '----- Export (960401-960419) -----'; Module: 'Printers'),
    (Code: 960401; ConstantName: 'ERR_PRINTERS_EXPORT_FAILED'; Message: 'ERR_PRINTERS_EXPORT_FAILED'; Module: 'Printers'),
    (Code: 960402; ConstantName: 'ERR_PRINTERS_EXPORT_FILE_NOT_INFORMED'; Message: 'ERR_PRINTERS_EXPORT_FILE_NOT_INFORMED'; Module: 'Printers'),
    (Code: 990001; ConstantName: 'ERR_ARCHIVE_GENERIC'; Message: 'ERR_ARCHIVE_GENERIC'; Module: 'ZipFile'),
    (Code: 990002; ConstantName: 'ERR_ARCHIVE_NOT_FOUND'; Message: 'ERR_ARCHIVE_NOT_FOUND'; Module: 'ZipFile'),
    (Code: 990003; ConstantName: 'ERR_ARCHIVE_INVALID_FORMAT'; Message: 'ERR_ARCHIVE_INVALID_FORMAT'; Module: 'ZipFile'),
    (Code: 990004; ConstantName: 'ERR_ARCHIVE_CORRUPT'; Message: 'ERR_ARCHIVE_CORRUPT'; Module: 'ZipFile'),
    (Code: 990005; ConstantName: 'ERR_ARCHIVE_ALREADY_OPEN'; Message: 'ERR_ARCHIVE_ALREADY_OPEN'; Module: 'ZipFile'),
    (Code: 990006; ConstantName: 'ERR_ARCHIVE_NOT_OPEN'; Message: 'ERR_ARCHIVE_NOT_OPEN'; Module: 'ZipFile'),
    (Code: 990007; ConstantName: 'ERR_ARCHIVE_ENCRYPTION'; Message: 'ERR_ARCHIVE_ENCRYPTION'; Module: 'ZipFile'),
    (Code: 990008; ConstantName: 'ERR_ARCHIVE_PASSWORD_REQUIRED'; Message: 'ERR_ARCHIVE_PASSWORD_REQUIRED'; Module: 'ZipFile'),
    (Code: 990009; ConstantName: 'ERR_ARCHIVE_PASSWORD_INCORRECT'; Message: 'ERR_ARCHIVE_PASSWORD_INCORRECT'; Module: 'ZipFile'),
    (Code: 990010; ConstantName: 'ERR_ARCHIVE_WRITE_NOT_SUPPORTED'; Message: 'ERR_ARCHIVE_WRITE_NOT_SUPPORTED'; Module: 'ZipFile'),
    (Code: 990011; ConstantName: 'ERR_ARCHIVE_PLATFORM_NOT_SUPPORTED'; Message: 'ERR_ARCHIVE_PLATFORM_NOT_SUPPORTED'; Module: 'ZipFile'),
    (Code: 990012; ConstantName: 'ERR_ARCHIVE_ENTRY_NOT_FOUND'; Message: 'ERR_ARCHIVE_ENTRY_NOT_FOUND'; Module: 'ZipFile'),
    (Code: 990013; ConstantName: 'ERR_ARCHIVE_DETECT'; Message: '990013 (EArchiveDetectError, 15.2-c)'; Module: 'ZipFile'),
    (Code: 990014; ConstantName: 'ERR_ARCHIVE_WRITE_FAILED'; Message: '990014 (raises genericos, 15.2-c)'; Module: 'ZipFile'),
    (Code: 990020; ConstantName: 'ERR_ZIPFILE_CANCELLED'; Message: 'ERR_ZIPFILE_CANCELLED'; Module: 'ZipFile'),
    (Code: 990021; ConstantName: 'ERR_ZIPFILE_ZIP64_NOT_SUPPORTED'; Message: 'ERR_ZIPFILE_ZIP64_NOT_SUPPORTED'; Module: 'ZipFile'),
    (Code: 990040; ConstantName: 'ERR_ZIPFILE_ARJ'; Message: 'ERR_ZIPFILE_ARJ'; Module: 'ZipFile'),
    (Code: 990041; ConstantName: 'ERR_ZIPFILE_RAR'; Message: 'ERR_ZIPFILE_RAR'; Module: 'ZipFile'),
    (Code: 990042; ConstantName: 'ERR_ZIPFILE_CAB'; Message: 'ERR_ZIPFILE_CAB'; Module: 'ZipFile'),
    (Code: 990043; ConstantName: 'ERR_ZIPFILE_LHA'; Message: 'ERR_ZIPFILE_LHA'; Module: 'ZipFile'),
    (Code: 990044; ConstantName: 'ERR_ZIPFILE_ISO'; Message: 'ERR_ZIPFILE_ISO'; Module: 'ZipFile'),
    (Code: 990045; ConstantName: 'ERR_ZIPFILE_SEVENZ'; Message: 'ERR_ZIPFILE_SEVENZ'; Module: 'ZipFile'),
    (Code: 990046; ConstantName: 'ERR_ZIPFILE_BZIP2'; Message: 'ERR_ZIPFILE_BZIP2'; Module: 'ZipFile'),
    (Code: 990047; ConstantName: 'ERR_ZIPFILE_GZIP'; Message: 'ERR_ZIPFILE_GZIP'; Module: 'ZipFile'),
    (Code: 990048; ConstantName: 'ERR_ZIPFILE_TAR'; Message: 'ERR_ZIPFILE_TAR'; Module: 'ZipFile'),
    (Code: 990049; ConstantName: 'ERR_ZIPFILE_TARGZ'; Message: 'ERR_ZIPFILE_TARGZ'; Module: 'ZipFile'),
    (Code: 990050; ConstantName: 'ERR_ZIPFILE_UUE'; Message: 'ERR_ZIPFILE_UUE'; Module: 'ZipFile'),
    (Code: 990051; ConstantName: 'ERR_ZIPFILE_ZCOMPRESS'; Message: 'ERR_ZIPFILE_ZCOMPRESS'; Module: 'ZipFile'),
    (Code: 990052; ConstantName: 'ERR_ZIPFILE_LZMA'; Message: 'ERR_ZIPFILE_LZMA'; Module: 'ZipFile'),
    (Code: 990053; ConstantName: 'ERR_ZIPFILE_AES'; Message: 'ERR_ZIPFILE_AES'; Module: 'ZipFile'),
    (Code: 990054; ConstantName: 'ERR_ZIPFILE_ZLIB'; Message: 'ERR_ZIPFILE_ZLIB'; Module: 'ZipFile'),
    (Code: 990055; ConstantName: 'ERR_ZIPFILE_GZIPSTREAM'; Message: 'ERR_ZIPFILE_GZIPSTREAM'; Module: 'ZipFile')

  );

{ T10: o DELETE previo falha legitimamente numa tabela recem-criada, mas um
  swallow MUDO esconderia um erro real de permissoes/schema. Mesmo idioma
  de diagnostico do resto do modulo (OutputDebugString, sem ILogger, para
  nao reentrar no caminho de excecoes). }
procedure TraceSeed(ACode: Integer; E: Exception);
begin
{$IFNDEF FPC}
  OutputDebugString(PChar(Format('[ProvidersORM.Exceptions.Messages.Seed] delete previo do codigo %d: %s: %s',
    [ACode, E.ClassName, E.Message])));
{$ELSE}
  OutputDebugString(PChar(AnsiString(Format('[ProvidersORM.Exceptions.Messages.Seed] delete previo do codigo %d: %s: %s',
    [ACode, E.ClassName, E.Message]))));
{$ENDIF}
end;

function SeedEntries: TArray<TSeedEntry>;
var
  I: Integer;
begin
  SetLength(Result, SEED_COUNT);
  for I := 0 to SEED_COUNT - 1 do
    Result[I] := SEED_DATA[I];
end;

function SeedMessages(const AConnection: IConnection;
  const ALanguage: string): Integer;
var
  I: Integer;
  LLang: string;
begin
  Result := 0;
  if (AConnection = nil) or (not AConnection.IsConnected) then
    Exit;
  LLang := ALanguage;
  if LLang = '' then
    LLang := DEFAULT_LANGUAGE;

  for I := 0 to SEED_COUNT - 1 do
  begin
    { DML PELO IQUERYBUILDER - o mesmo padrao do modulo Parameters, que o owner
      apontou (01/09) como a referencia da casa: QueryBuilder para TODO o DML,
      ITable so para DDL. Nao usar ITable.ExecuteDelete/ExecuteInsert aqui e
      DELIBERADO: TTable.WhereByPrimaryKey usa GetPrimaryKey (SINGULAR), logo com
      a PK composta (code, language) o delete filtraria so por `code` e apagaria
      TODOS os idiomas desse codigo - o seed de `en` levava o `pt-BR` a frente
      (apanhado pelo smoke local em 01/09). }
    try
      TQueryBuilder.New
        .Connection(AConnection)
        .DeleteFrom(DEFAULT_MESSAGES_TABLE)
        .Where(MESSAGES_COL.Code, SEED_DATA[I].Code)
        .Where(MESSAGES_COL.Language, LLang)
        .ExecuteMutation;
    except
      on E: Exception do
        TraceSeed(SEED_DATA[I].Code, E);
    end;

    TQueryBuilder.New
      .Connection(AConnection)
      .InsertInto(DEFAULT_MESSAGES_TABLE)
      .Value(MESSAGES_COL.Code,          SEED_DATA[I].Code)
      .Value(MESSAGES_COL.ConstantName,  SEED_DATA[I].ConstantName)
      .Value(MESSAGES_COL.Message,       SEED_DATA[I].Message)
      .Value(MESSAGES_COL.Module,        SEED_DATA[I].Module)
      .Value(MESSAGES_COL.SourceProject, 'ProvidersORM')
      .Value(MESSAGES_COL.Language,      LLang)
      .Value(MESSAGES_COL.Name,          SEED_DATA[I].ConstantName)
      .ExecuteMutation;
    Inc(Result);
  end;
end;

end.
