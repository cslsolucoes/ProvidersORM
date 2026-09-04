{ =============================================================================
  Exceptions.Parameters - Exceções do módulo Parameters (core em Modulos/Exceptions)

  Conteúdo migrado de Commons.Parameters.Exceptions. EParametersException
  herda de EExceptionBase (Exceptions.Base). Faixa 50XXX.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           02/03/2026

  Changelog (file):
  - 1.0.0 (02/03/2026): Migração de Commons.Parameters.Exceptions para Modulos/Exceptions.
  ============================================================================= }

unit Exceptions.Parameters;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

Uses
{$IF DEFINED(FPC)}
  SysUtils,
{$ELSE}
  System.SysUtils,
{$ENDIF}
  Exceptions.Base,
  Commons.Types;

type
  EParametersException = class(EExceptionBase)
  private
    FOperation: string;
  public
    constructor Create(const AMessage: string; const AErrorCode: Integer = 0; const AOperation: string = ''); reintroduce;
    property Operation: string read FOperation;   // ErrorCode vem de EExceptionBase (de-dup 05/07)
  end;

  EParametersConnectionException = class(EParametersException);
  EParametersSQLException = class(EParametersException);
  EParametersValidationException = class(EParametersException);
  EParametersNotFoundException = class(EParametersException);
  EParametersConfigurationException = class(EParametersException);
  EParametersFileException = class(EParametersException);
  EParametersInifilesException = class(EParametersException);
  EParametersJsonObjectException = class(EParametersException);

  { Exceção para erros de Attributes (RTTI/mapeamento). Migrado de Parameters.Attributes.Exceptions. }
  EParametersAttributeException = class(EParametersConfigurationException)
  public
    constructor Create(const AMessage: string; const AErrorCode: Integer = 0; const AOperation: string = ''); reintroduce;
  end;

const
  ERR_CONNECTION_NOT_ASSIGNED = 500001;
  ERR_CONNECTION_FAILED = 500002;
  ERR_CONNECTION_ALREADY_EXISTS = 500003;
  ERR_CONNECTION_NOT_CONNECTED = 500004;
  ERR_DISCONNECTION_FAILED = 500005;
  ERR_CONNECTION_TIMEOUT = 500006;
  ERR_CONNECTION_INVALID_CREDENTIALS = 500007;
  ERR_CONNECTION_DATABASE_NOT_FOUND = 500008;
  ERR_CONNECTION_DRIVE_NOT_READY = 500009;
  ERR_SQL_EXECUTION_FAILED = 501001;
  ERR_SQL_QUERY_FAILED = 501002;
  ERR_SQL_INVALID = 501003;
  ERR_SQL_INJECTION_DETECTED = 501004;
  ERR_SQL_TABLE_NOT_EXISTS = 501005;
  ERR_SQL_TABLE_CREATE_FAILED = 501006;
  ERR_SQL_TABLE_DROP_FAILED = 501007;
  ERR_SQL_TABLE_STRUCTURE_INVALID = 501008;
  ERR_SQL_COLUMN_NOT_FOUND = 501009;
  ERR_SQL_COLUMN_TYPE_MISMATCH = 501010;
  ERR_SQL_PRIMARY_KEY_MISSING = 501011;
  ERR_SQL_GENERATOR_EXISTS = 501012;
  ERR_SQL_TRIGGER_EXISTS = 501013;
  ERR_SQL_GENERATOR_NOT_FOUND = 501014;
  ERR_SQL_TRIGGER_NOT_FOUND = 501015;
  ERR_PARAMETER_NAME_EMPTY = 500201;
  ERR_PARAMETER_NAME_INVALID = 500202;
  ERR_PARAMETER_VALUE_INVALID = 500203;
  ERR_PARAMETER_REQUIRED = 500204;
  ERR_TABLE_NAME_EMPTY = 500205;
  ERR_SCHEMA_NAME_EMPTY = 500206;
  ERR_CONTRATO_ID_INVALID = 500207;
  ERR_PRODUTO_ID_INVALID = 500208;
  ERR_ORDEM_INVALID = 500209;
  ERR_TITULO_EMPTY = 500210;
  ERR_CHAVE_EMPTY = 500211;
  ERR_CHAVE_INVALID = 500212;
  ERR_PARAMETER_NOT_FOUND = 500301;
  ERR_PARAMETER_ALREADY_EXISTS = 500302;
  ERR_INSERT_FAILED = 500303;
  ERR_UPDATE_FAILED = 500304;
  ERR_DELETE_FAILED = 500305;
  ERR_LIST_FAILED = 500306;
  ERR_GET_FAILED = 500307;
  ERR_COUNT_FAILED = 500308;
  ERR_EXISTS_FAILED = 500309;
  ERR_REFRESH_FAILED = 500310;
  ERR_ENGINE_NOT_DEFINED = 500401;
  ERR_DATABASE_TYPE_NOT_DEFINED = 500402;
  ERR_HOST_NOT_DEFINED = 500403;
  ERR_DATABASE_NOT_DEFINED = 500404;
  ERR_INVALID_CONFIGURATION = 500405;
  ERR_PORT_INVALID = 500406;
  ERR_USERNAME_NOT_DEFINED = 500407;
  ERR_SCHEMA_NOT_DEFINED = 500408;
  ERR_FILE_NOT_FOUND = 500501;
  ERR_FILE_CANNOT_READ = 500502;
  ERR_FILE_CANNOT_WRITE = 500503;
  ERR_FILE_CANNOT_CREATE = 500504;
  ERR_FILE_ACCESS_DENIED = 500505;
  ERR_FILE_LOCKED = 500506;
  ERR_FILE_INVALID_FORMAT = 500507;
  ERR_FILE_ENCODING_INVALID = 500508;
  ERR_FILE_PATH_EMPTY = 500509;
  ERR_FILE_PATH_INVALID = 500510;
  ERR_DIRECTORY_NOT_EXISTS = 500511;
  ERR_DIRECTORY_CANNOT_CREATE = 500512;
  ERR_INI_FILE_NOT_FOUND = 500601;
  ERR_INI_FILE_CANNOT_READ = 500602;
  ERR_INI_FILE_CANNOT_WRITE = 500603;
  ERR_INI_SECTION_EMPTY = 500604;
  ERR_INI_SECTION_NOT_FOUND = 500605;
  ERR_INI_KEY_NOT_FOUND = 500606;
  ERR_INI_KEY_ALREADY_EXISTS = 500607;
  ERR_INI_INVALID_FORMAT = 500608;
  ERR_JSON_FILE_NOT_FOUND = 500701;
  ERR_JSON_FILE_CANNOT_READ = 500702;
  ERR_JSON_FILE_CANNOT_WRITE = 500703;
  ERR_JSON_INVALID_FORMAT = 500704;
  ERR_JSON_INVALID_ENCODING = 500705;
  ERR_JSON_OBJECT_NOT_FOUND = 500706;
  ERR_JSON_KEY_NOT_FOUND = 500707;
  ERR_JSON_KEY_ALREADY_EXISTS = 500708;
  ERR_JSON_OBJECT_NAME_EMPTY = 500709;
  ERR_JSON_PARSE_ERROR = 500710;
  ERR_JSON_EMPTY = 500711;
  ERR_IMPORT_FAILED = 500801;
  ERR_EXPORT_FAILED = 500802;
  ERR_IMPORT_SOURCE_NOT_FOUND = 500803;
  ERR_IMPORT_TARGET_NOT_FOUND = 500804;
  ERR_EXPORT_SOURCE_NOT_FOUND = 500805;
  ERR_EXPORT_TARGET_NOT_FOUND = 500806;
  ERR_IMPORT_INVALID_DATA = 500807;
  ERR_EXPORT_INVALID_DATA = 500808;
  ERR_IMPORT_OVERWRITE_DENIED = 500809;

  MSG_CONNECTION_NOT_ASSIGNED = 'Conexao nao foi inicializada. Use TParameters.New() para criar uma instancia.';
  MSG_CONNECTION_FAILED = 'Falha ao conectar ao banco de dados. Verifique as configuracoes de conexao (Host, Port, Username, Password, Database).';
  MSG_CONNECTION_NOT_CONNECTED = 'Nao ha conexao ativa com o banco de dados. Use Connect() para estabelecer conexao.';
  MSG_DISCONNECTION_FAILED = 'Falha ao desconectar do banco de dados.';
  MSG_CONNECTION_TIMEOUT = 'Timeout ao conectar ao banco de dados. Verifique se o servidor esta acessivel.';
  MSG_CONNECTION_INVALID_CREDENTIALS = 'Credenciais invalidas. Verifique Username e Password.';
  MSG_CONNECTION_DATABASE_NOT_FOUND = 'Banco de dados "%s" nao encontrado. Verifique o nome do banco ou liste os bancos disponiveis.';
  MSG_CONNECTION_DRIVE_NOT_READY = 'Drive nao esta acessivel ou nao existe. Verifique o caminho do arquivo.';
  MSG_SQL_EXECUTION_FAILED = 'Falha ao executar comando SQL: %s';
  MSG_SQL_QUERY_FAILED = 'Falha ao executar consulta SQL: %s';
  MSG_SQL_INVALID = 'SQL invalido: %s';
  MSG_SQL_TABLE_NOT_EXISTS = 'Tabela "%s" nao existe. Use CreateTable() para criar a tabela.';
  MSG_SQL_TABLE_CREATE_FAILED = 'Falha ao criar tabela "%s": %s';
  MSG_SQL_TABLE_DROP_FAILED = 'Falha ao remover tabela "%s": %s';
  MSG_SQL_TABLE_STRUCTURE_INVALID = 'Estrutura da tabela "%s" incompativel. %s';
  MSG_SQL_COLUMN_NOT_FOUND = 'Coluna "%s" nao encontrada na tabela "%s".';
  MSG_SQL_COLUMN_TYPE_MISMATCH = 'Coluna "%s" deve ser do tipo %s, mas encontrado: %s';
  MSG_SQL_PRIMARY_KEY_MISSING = 'Coluna "%s" deve ser PRIMARY KEY.';
  MSG_SQL_GENERATOR_EXISTS = 'Generator "%s" ja existe no banco de dados.';
  MSG_SQL_TRIGGER_EXISTS = 'Trigger "%s" ja existe no banco de dados.';
  MSG_PARAMETER_NAME_EMPTY = 'O nome do parametro nao pode estar vazio.';
  MSG_PARAMETER_NAME_INVALID = 'Nome de parametro invalido: "%s". Use apenas letras, numeros e underscores.';
  MSG_PARAMETER_VALUE_INVALID = 'Valor do parametro invalido para o tipo %s: "%s"';
  MSG_PARAMETER_REQUIRED = 'O parametro "%s" e obrigatorio.';
  MSG_TABLE_NAME_EMPTY = 'O nome da tabela nao pode estar vazio. Use TableName() para definir.';
  MSG_SCHEMA_NAME_EMPTY = 'O nome do schema nao pode estar vazio. Use Schema() para definir.';
  MSG_CONTRATO_ID_INVALID = 'Contrato ID deve ser um numero valido (>= 0).';
  MSG_PRODUTO_ID_INVALID = 'Produto ID deve ser um numero valido (>= 0).';
  MSG_ORDEM_INVALID = 'Ordem deve ser um numero valido (>= 0).';
  MSG_TITULO_EMPTY = 'O titulo nao pode estar vazio.';
  MSG_CHAVE_EMPTY = 'A chave nao pode estar vazia.';
  MSG_CHAVE_INVALID = 'Chave invalida: "%s". Use apenas letras, numeros e underscores.';
  MSG_PARAMETER_NOT_FOUND = 'Parametro "%s" nao encontrado na tabela %s.';
  MSG_PARAMETER_ALREADY_EXISTS = 'Parametro "%s" ja existe na tabela %s.';
  MSG_INSERT_FAILED = 'Falha ao inserir parametro "%s": %s';
  MSG_UPDATE_FAILED = 'Falha ao atualizar parametro "%s": %s';
  MSG_DELETE_FAILED = 'Falha ao deletar parametro "%s": %s';
  MSG_LIST_FAILED = 'Falha ao listar parametros: %s';
  MSG_GET_FAILED = 'Falha ao obter parametro "%s": %s';
  MSG_COUNT_FAILED = 'Falha ao contar parametros: %s';
  MSG_EXISTS_FAILED = 'Falha ao verificar existencia do parametro "%s": %s';
  MSG_REFRESH_FAILED = 'Falha ao renovar dados: %s';
  MSG_ENGINE_NOT_DEFINED = 'Engine de banco de dados nao definido. Use Engine() para configurar.';
  MSG_DATABASE_TYPE_NOT_DEFINED = 'Tipo de banco de dados nao definido. Use DatabaseType() para configurar.';
  MSG_HOST_NOT_DEFINED = 'Host do servidor nao definido. Use Host() para configurar.';
  MSG_DATABASE_NOT_DEFINED = 'Nome do banco de dados nao definido. Use Database() para configurar.';
  MSG_INVALID_CONFIGURATION = 'Configuracao invalida: %s';
  MSG_PORT_INVALID = 'Porta deve ser um numero valido entre 1 e 65535.';
  MSG_USERNAME_NOT_DEFINED = 'Username nao definido. Use Username() para configurar.';
  MSG_SCHEMA_NOT_DEFINED = 'Schema nao definido. Use Schema() para configurar (obrigatorio para %s).';
  MSG_FILE_NOT_FOUND = 'Arquivo nao encontrado: %s';
  MSG_FILE_CANNOT_READ = 'Nao foi possivel ler o arquivo: %s';
  MSG_FILE_CANNOT_WRITE = 'Nao foi possivel escrever no arquivo: %s';
  MSG_FILE_CANNOT_CREATE = 'Nao foi possivel criar o arquivo: %s';
  MSG_FILE_ACCESS_DENIED = 'Acesso negado ao arquivo: %s';
  MSG_FILE_LOCKED = 'Arquivo esta sendo usado por outro processo: %s';
  MSG_FILE_INVALID_FORMAT = 'Formato de arquivo invalido: %s';
  MSG_FILE_ENCODING_INVALID = 'Encoding do arquivo invalido ou nao suportado: %s';
  MSG_FILE_PATH_EMPTY = 'Caminho do arquivo nao pode estar vazio.';
  MSG_FILE_PATH_INVALID = 'Caminho do arquivo invalido: %s';
  MSG_DIRECTORY_NOT_EXISTS = 'Diretorio nao existe: %s';
  MSG_DIRECTORY_CANNOT_CREATE = 'Nao foi possivel criar o diretorio: %s';
  MSG_INI_FILE_NOT_FOUND = 'Arquivo INI nao encontrado: %s';
  MSG_INI_FILE_CANNOT_READ = 'Nao foi possivel ler o arquivo INI: %s';
  MSG_INI_FILE_CANNOT_WRITE = 'Nao foi possivel escrever no arquivo INI: %s';
  MSG_INI_SECTION_EMPTY = 'Secao do INI nao pode estar vazia. Use Section() para definir.';
  MSG_INI_SECTION_NOT_FOUND = 'Secao "%s" nao encontrada no arquivo INI.';
  MSG_INI_KEY_NOT_FOUND = 'Chave "%s" nao encontrada na secao "%s".';
  MSG_INI_KEY_ALREADY_EXISTS = 'Chave "%s" ja existe na secao "%s".';
  MSG_INI_INVALID_FORMAT = 'Formato do arquivo INI invalido: %s';
  MSG_JSON_FILE_NOT_FOUND = 'Arquivo JSON nao encontrado: %s';
  MSG_JSON_FILE_CANNOT_READ = 'Nao foi possivel ler o arquivo JSON: %s';
  MSG_JSON_FILE_CANNOT_WRITE = 'Nao foi possivel escrever no arquivo JSON: %s';
  MSG_JSON_INVALID_FORMAT = 'Formato JSON invalido: %s';
  MSG_JSON_INVALID_ENCODING = 'Encoding do arquivo JSON invalido. Suportado: UTF-8 (com/sem BOM) ou ANSI.';
  MSG_JSON_OBJECT_NOT_FOUND = 'Objeto JSON "%s" nao encontrado.';
  MSG_JSON_KEY_NOT_FOUND = 'Chave "%s" nao encontrada no objeto "%s".';
  MSG_JSON_KEY_ALREADY_EXISTS = 'Chave "%s" ja existe no objeto "%s".';
  MSG_JSON_OBJECT_NAME_EMPTY = 'Nome do objeto JSON nao pode estar vazio. Use ObjectName() para definir.';
  MSG_JSON_PARSE_ERROR = 'Erro ao parsear arquivo JSON: %s';
  MSG_JSON_EMPTY = 'Arquivo JSON esta vazio ou nao contem dados validos.';
  MSG_IMPORT_FAILED = 'Falha ao importar dados: %s';
  MSG_EXPORT_FAILED = 'Falha ao exportar dados: %s';
  MSG_IMPORT_SOURCE_NOT_FOUND = 'Fonte de importacao nao encontrada ou nao configurada.';
  MSG_IMPORT_TARGET_NOT_FOUND = 'Destino de importacao nao encontrado ou nao configurado.';
  MSG_EXPORT_SOURCE_NOT_FOUND = 'Fonte de exportacao nao encontrada ou nao configurada.';
  MSG_EXPORT_TARGET_NOT_FOUND = 'Destino de exportacao nao encontrado ou nao configurado.';
  MSG_IMPORT_INVALID_DATA = 'Dados invalidos para importacao: %s';
  MSG_EXPORT_INVALID_DATA = 'Dados invalidos para exportacao: %s';
  MSG_IMPORT_OVERWRITE_DENIED = 'Importacao cancelada pelo usuario (sobrescrita negada).';

  { =============================================================================
    CODIGOS DE ERRO - Attributes (600101-600110, canonica exception.sql)
    Migrado de Parameters.Attributes.Exceptions.
    ============================================================================= }
  ERR_ATTRIBUTE_PARAMETER_NOT_FOUND_CODE         = 509001;
  ERR_ATTRIBUTE_PARAMETER_KEY_NOT_FOUND_CODE     = 509002;
  ERR_ATTRIBUTE_INVALID_CLASS_CODE               = 509003;
  ERR_ATTRIBUTE_RTTI_NOT_AVAILABLE_CODE          = 509004;
  ERR_ATTRIBUTE_INVALID_PROPERTY_CODE            = 509005;
  ERR_ATTRIBUTE_REQUIRED_PARAMETER_NOT_FOUND_CODE = 509006;
  ERR_ATTRIBUTE_PARSING_FAILED_CODE              = 509007;
  ERR_ATTRIBUTE_MAPPING_FAILED_CODE              = 509008;
  ERR_ATTRIBUTE_VALIDATION_FAILED_CODE           = 509009;
  ERR_ATTRIBUTE_VALUE_CONVERSION_FAILED_CODE     = 509010;

  MSG_ATTRIBUTE_PARAMETER_NOT_FOUND         = 'Classe %s não possui atributo [Parameter]';
  MSG_ATTRIBUTE_PARAMETER_KEY_NOT_FOUND     = 'Propriedade %s não possui atributo [ParameterKey]';
  MSG_ATTRIBUTE_RTTI_NOT_AVAILABLE          = 'RTTI não disponível para classe %s (adicione {$M+} ou {$TYPEINFO ON})';
  MSG_ATTRIBUTE_REQUIRED_PARAMETER_NOT_FOUND = 'Parâmetro obrigatório "%s" não encontrado';

function CreateConnectionException(const AMessage: string; const AErrorCode: Integer = 0; const AOperation: string = ''): EParametersConnectionException;
function CreateSQLException(const AMessage: string; const AErrorCode: Integer = 0; const AOperation: string = ''): EParametersSQLException;
function CreateValidationException(const AMessage: string; const AErrorCode: Integer = 0; const AOperation: string = ''): EParametersValidationException;
function CreateNotFoundException(const AMessage: string; const AErrorCode: Integer = 0; const AOperation: string = ''): EParametersNotFoundException;
function CreateConfigurationException(const AMessage: string; const AErrorCode: Integer = 0; const AOperation: string = ''): EParametersConfigurationException;
function CreateFileException(const AMessage: string; const AErrorCode: Integer = 0; const AOperation: string = ''): EParametersFileException;
function CreateInifilesException(const AMessage: string; const AErrorCode: Integer = 0; const AOperation: string = ''): EParametersInifilesException;
function CreateJsonObjectException(const AMessage: string; const AErrorCode: Integer = 0; const AOperation: string = ''): EParametersJsonObjectException;
function TableNotFoundMessage(const AInnerMessage: string; const ADatabasePath: string): string;
function ConvertToParametersException(const AException: Exception; const AOperation: string = ''): EParametersException;
function IsParametersException(const AException: Exception): Boolean;
function GetExceptionErrorCode(const AException: Exception): Integer;
function GetExceptionOperation(const AException: Exception): string;

implementation

constructor EParametersException.Create(const AMessage: string; const AErrorCode: Integer; const AOperation: string);
begin
  inherited Create(AMessage, AErrorCode);
  FOperation := AOperation;
end;

function CreateConnectionException(const AMessage: string; const AErrorCode: Integer; const AOperation: string): EParametersConnectionException;
begin
  Result := EParametersConnectionException.Create(AMessage, AErrorCode, AOperation);
end;

function CreateSQLException(const AMessage: string; const AErrorCode: Integer; const AOperation: string): EParametersSQLException;
begin
  Result := EParametersSQLException.Create(AMessage, AErrorCode, AOperation);
end;

function CreateValidationException(const AMessage: string; const AErrorCode: Integer; const AOperation: string): EParametersValidationException;
begin
  Result := EParametersValidationException.Create(AMessage, AErrorCode, AOperation);
end;

function CreateNotFoundException(const AMessage: string; const AErrorCode: Integer; const AOperation: string): EParametersNotFoundException;
begin
  Result := EParametersNotFoundException.Create(AMessage, AErrorCode, AOperation);
end;

function CreateConfigurationException(const AMessage: string; const AErrorCode: Integer; const AOperation: string): EParametersConfigurationException;
begin
  Result := EParametersConfigurationException.Create(AMessage, AErrorCode, AOperation);
end;

function CreateFileException(const AMessage: string; const AErrorCode: Integer; const AOperation: string): EParametersFileException;
begin
  Result := EParametersFileException.Create(AMessage, AErrorCode, AOperation);
end;

function CreateInifilesException(const AMessage: string; const AErrorCode: Integer; const AOperation: string): EParametersInifilesException;
begin
  Result := EParametersInifilesException.Create(AMessage, AErrorCode, AOperation);
end;

function CreateJsonObjectException(const AMessage: string; const AErrorCode: Integer; const AOperation: string): EParametersJsonObjectException;
begin
  Result := EParametersJsonObjectException.Create(AMessage, AErrorCode, AOperation);
end;

function TableNotFoundMessage(const AInnerMessage: string; const ADatabasePath: string): string;
var
  LExt: string;
begin
  if (Pos('nao existe', AInnerMessage) > 0) or (Pos('CreateTable', AInnerMessage) > 0) then
  begin
    Result := AInnerMessage;
    if Trim(ADatabasePath) <> '' then
    begin
      Result := Result + ' Arquivo do banco: ' + ADatabasePath + '. ';
      LExt := LowerCase(ExtractFileExt(ADatabasePath));
      if (LExt = '.mdb') or (LExt = '.accdb') then
        Result := Result + 'Para Access use CreateTable() ou crie a tabela pelo MS Access / ODBC.'
      else
        Result := Result + 'Para criar a tabela use CreateTable() ou execute: sqlite3.exe "' + ADatabasePath + '" < seu_script.sql. ' +
          'Para verificar: sqlite3.exe "' + ADatabasePath + '" ".tables"';
    end;
  end
  else
    Result := AInnerMessage;
end;

function ConvertToParametersException(const AException: Exception; const AOperation: string): EParametersException;
var
  LMessage: string;
  LErrorCode: Integer;
  LOperation: string;
begin
  LMessage := AException.Message;
  LOperation := AOperation;
  if AException is EParametersException then
  begin
    Result := EParametersException(AException);
    if (LOperation <> '') and (Result.Operation = '') then
    begin
      if AException is EParametersConnectionException then
        Result := CreateConnectionException(LMessage, Result.ErrorCode, LOperation)
      else if AException is EParametersSQLException then
        Result := CreateSQLException(LMessage, Result.ErrorCode, LOperation)
      else if AException is EParametersValidationException then
        Result := CreateValidationException(LMessage, Result.ErrorCode, LOperation)
      else if AException is EParametersNotFoundException then
        Result := CreateNotFoundException(LMessage, Result.ErrorCode, LOperation)
      else if AException is EParametersConfigurationException then
        Result := CreateConfigurationException(LMessage, Result.ErrorCode, LOperation)
      else if AException is EParametersFileException then
        Result := CreateFileException(LMessage, Result.ErrorCode, LOperation)
      else if AException is EParametersInifilesException then
        Result := CreateInifilesException(LMessage, Result.ErrorCode, LOperation)
      else if AException is EParametersJsonObjectException then
        Result := CreateJsonObjectException(LMessage, Result.ErrorCode, LOperation)
      else
        Result := EParametersException.Create(LMessage, Result.ErrorCode, LOperation);
    end
    else
      Result := EParametersException(AException);
    Exit;
  end;
  LMessage := UpperCase(LMessage);
  if (Pos('CONNECTION', LMessage) > 0) or (Pos('CONNECT', LMessage) > 0) or (Pos('DISCONNECT', LMessage) > 0) or
     (Pos('TIMEOUT', LMessage) > 0) or (Pos('CREDENTIALS', LMessage) > 0) or
     ((Pos('DATABASE', LMessage) > 0) and (Pos('NOT FOUND', LMessage) > 0)) then
  begin
    if Pos('NOT CONNECTED', LMessage) > 0 then LErrorCode := ERR_CONNECTION_NOT_CONNECTED
    else if Pos('TIMEOUT', LMessage) > 0 then LErrorCode := ERR_CONNECTION_TIMEOUT
    else if Pos('CREDENTIALS', LMessage) > 0 then LErrorCode := ERR_CONNECTION_INVALID_CREDENTIALS
    else LErrorCode := ERR_CONNECTION_FAILED;
    Result := CreateConnectionException(AException.Message, LErrorCode, LOperation);
  end
  else if (Pos('SQL', LMessage) > 0) or (Pos('TABLE', LMessage) > 0) or (Pos('COLUMN', LMessage) > 0) or
          (Pos('QUERY', LMessage) > 0) or (Pos('EXECUTE', LMessage) > 0) then
  begin
    if Pos('TABLE NOT EXISTS', LMessage) > 0 then LErrorCode := ERR_SQL_TABLE_NOT_EXISTS
    else if Pos('TABLE STRUCTURE', LMessage) > 0 then LErrorCode := ERR_SQL_TABLE_STRUCTURE_INVALID
    else if Pos('COLUMN NOT FOUND', LMessage) > 0 then LErrorCode := ERR_SQL_COLUMN_NOT_FOUND
    else LErrorCode := ERR_SQL_EXECUTION_FAILED;
    Result := CreateSQLException(AException.Message, LErrorCode, LOperation);
  end
  else if (Pos('FILE', LMessage) > 0) or (Pos('CANNOT READ', LMessage) > 0) or (Pos('CANNOT WRITE', LMessage) > 0) or
          (Pos('ACCESS DENIED', LMessage) > 0) or (Pos('LOCKED', LMessage) > 0) then
  begin
    if Pos('NOT FOUND', LMessage) > 0 then LErrorCode := ERR_FILE_NOT_FOUND
    else if Pos('CANNOT READ', LMessage) > 0 then LErrorCode := ERR_FILE_CANNOT_READ
    else if Pos('CANNOT WRITE', LMessage) > 0 then LErrorCode := ERR_FILE_CANNOT_WRITE
    else if Pos('ACCESS DENIED', LMessage) > 0 then LErrorCode := ERR_FILE_ACCESS_DENIED
    else LErrorCode := ERR_FILE_CANNOT_CREATE;
    Result := CreateFileException(AException.Message, LErrorCode, LOperation);
  end
  else if (Pos('JSON', LMessage) > 0) or ((Pos('PARSE', LMessage) > 0) and (Pos('JSON', LMessage) > 0)) then
  begin
    if Pos('INVALID FORMAT', LMessage) > 0 then LErrorCode := ERR_JSON_INVALID_FORMAT
    else if Pos('ENCODING', LMessage) > 0 then LErrorCode := ERR_JSON_INVALID_ENCODING
    else if Pos('PARSE', LMessage) > 0 then LErrorCode := ERR_JSON_PARSE_ERROR
    else LErrorCode := ERR_JSON_INVALID_FORMAT;
    Result := CreateJsonObjectException(AException.Message, LErrorCode, LOperation);
  end
  else if (Pos('EMPTY', LMessage) > 0) or (Pos('INVALID', LMessage) > 0) or (Pos('REQUIRED', LMessage) > 0) then
  begin
    if Pos('NAME EMPTY', LMessage) > 0 then LErrorCode := ERR_PARAMETER_NAME_EMPTY
    else if Pos('TABLE NAME EMPTY', LMessage) > 0 then LErrorCode := ERR_TABLE_NAME_EMPTY
    else LErrorCode := ERR_PARAMETER_REQUIRED;
    Result := CreateValidationException(AException.Message, LErrorCode, LOperation);
  end
  else
    Result := EParametersException.Create(AException.Message, 0, LOperation);
end;

function IsParametersException(const AException: Exception): Boolean;
begin
  Result := AException is EParametersException;
end;

function GetExceptionErrorCode(const AException: Exception): Integer;
begin
  if AException is EParametersException then
    Result := EParametersException(AException).ErrorCode
  else
    Result := 0;
end;

function GetExceptionOperation(const AException: Exception): string;
begin
  if AException is EParametersException then
    Result := EParametersException(AException).Operation
  else
    Result := '';
end;

{ EParametersAttributeException }

constructor EParametersAttributeException.Create(const AMessage: string; const AErrorCode: Integer; const AOperation: string);
var
  LErrorCode: Integer;
begin
  if AErrorCode = 0 then
  begin
    if Pos('não possui atributo [Parameter]', AMessage) > 0 then
      LErrorCode := ERR_ATTRIBUTE_PARAMETER_NOT_FOUND_CODE
    else if Pos('não possui atributo [ParameterKey]', AMessage) > 0 then
      LErrorCode := ERR_ATTRIBUTE_PARAMETER_KEY_NOT_FOUND_CODE
    else if Pos('RTTI não disponível', AMessage) > 0 then
      LErrorCode := ERR_ATTRIBUTE_RTTI_NOT_AVAILABLE_CODE
    else if Pos('Parâmetro obrigatório', AMessage) > 0 then
      LErrorCode := ERR_ATTRIBUTE_REQUIRED_PARAMETER_NOT_FOUND_CODE
    else
      LErrorCode := ERR_ATTRIBUTE_PARSING_FAILED_CODE;
  end
  else
    LErrorCode := AErrorCode;
  inherited Create(AMessage, LErrorCode, AOperation);
end;

end.
