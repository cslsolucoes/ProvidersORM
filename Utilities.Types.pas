{ ==========================================================================
  PROVENANCE NOTE (ProvidersORM v3, FASE 10 Onda 10.2 - USE_PROVIDERS_V161):
  Absorbed VERBATIM from FontesReferencias/ProvidersORM.v1.6.1/Utilities/Utilities.Types.pas
  into this v3 tree as part of the USE_PROVIDERS_V161 compatibility subsystem
  (legacy ProvidersORM v1.6.1, mechanical port only - zero logic/behavior/
  symbol-name changes; see the unit's own original header below for the
  authorial history). Reachable via uses Providers.v161 - NOT part of the
  unified TProviders facade (Main/Providers.pas).

  No structural fix needed - the uses clause was already correctly gated
  per compiler. File re-saved as UTF-8 BOM (source snapshot was
  Windows-1252 - re-encoded, not re-typed; same characters/codepoints).
  ========================================================================== }

unit Utilities.Types;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}
{$ifdef FPC}
    {$mode objfpc}{$H+}
{$endif}

interface

uses
{$ifdef FPC}
  Classes,
{$else}
  System.Classes, System.DateUtils,
{$endif}
 Utilities.Consts;

Type

  TProviderThreadMethod = procedure(Sender: TObject) of object;

  TDatabaseProvider     = (dpNone, dpFireBird, dpFireBird3, dpMySQL, dpMariaDB, dpPostgreSQL, dpSQLite, dpSQLServer);

  TProviderStatus       = (dsInactive, dsEdit, dsInsert, dsDeleted);

  TProvicerTypeVariable = (ptNone,ptNumericInteger,ptNumericFloat,ptCharacterString,
                           ptCharacterText,ptCharacterChar,ptDatetime,ptDatetimeTime,
                           ptDatetimeDate,ptBoolean,ptBooleanInteger);

  TVariableTypeNumeric = Record
    nInteger : String;
    nFloat   : String;
  End;

  TVariableTypeText    = Record
    nString : String;
    nText   : String;
    nChar   : String;
  End;

  TVariableTypeDateTime = Record
    nDate : String;
    nTime : String;
    nDateTime : String;
  End;

  TVariableTypeBool    = Record
    nBoolean : String;
    nInteger : String;
  End;

  TVariableType  = record
     vNumeric    : TVariableTypeNumeric;
     vCharacter  : TVariableTypeText;
     vDatetime   : TVariableTypeDateTime;
     vBoolean    : String;
  End;

  TFieldType       = Record
    ftColumn       : String;
    ftType         : String;
    ftNull         : String;
    ftValue        : String;
    ftValueDefault : String;
    ftChanged      : integer;
    PKey           : Integer;
  End;

  TFormatCaracter  = (caNone,caNumero,caNumeroPonto,caAaZMaiusculo,caAaZMinusculo,caHexMaiusculo,caHexMinusculo,
                      cacaVersaoProduto,caVerSaoArquivo,caVerSaoGestao,caVersaoNumero,ipFormatoPadrao,ipFormato15d,
                      maFormato2pontos,maFormato100pontos );

  TFileInformation = (vaCompany,vaDescription,vaFileVersion,vaInternalName,vaCopyright,
                      vaOriginalName,vaProduct,vaProductVersion,vaComments,vaAuthor);

  TDocumento  = class
    public
      Id                     : Integer;
      IdEmpresa              : Integer;
      IdSetor                : Integer;
      IdTipo                 : integer;
      NomeOriginal           : String;
      NomeOriginalCaminho    : String;
      NomeGravado            : String;
      NomeGravadoCaminho     : String;
      MesAno                 : TDatetime;
      Vencimento             : TDateTime;
      IdOrigem               : String;
      Observacao             : string;
      EMail                  : Boolean;
      WhatsApp               : Boolean;
    end;

  TCampo = Class
    Coluna  : String;
    Tipo    : String;
    Nulo    : String;
    Valor   : String;
    Padrao  : String;
    PKey    : integer;
    PKeyName: String;
    Alterado: integer;
  End;

    // Estados possíveis do chat
  TChatStateType = (csInicio, csSetor, csTipo, csMes, csFinalizado);
  // Setores disponíveis
  TSetorType = (stPessoal, stFiscal, stJuridico, stContabil);

  TTipoDocumento = record
    ID_Tipo           : Integer;
    Descricao         : string;
  end;

  // Configurações da Evolution API
  TEvolutionConfig = Record
    Servidor   : string;
    Porta      : String;
    Token      : string;
    Instance   : string;
    Webhook    : string;
    Usuario    : String;
    Senha      : String;
    Timeout    : Integer;
    AutoReply  : Integer;
    WelcomeMessage: string;
  end;

  // Configurações da Evolution API
  TFTPConfig = Record
    Servidor   : string;
    Porta      : integer;
    Usuario    : String;
    Senha      : String;
  end;

  // Configurações de Email
  TEMailConfig = Record
    Servidor   : string;
    Porta      : String;
    Usuario    : string;
    Senha      : string;
    Nome       : String;
    Email      : string;
    TimeOut    : Integer;
  end;

  // Configurações da IA
  TChatgptConfig = Record
    API_BASE_URL : string;
    API_USER     : string;
    API_PASS     : string;
  end;

  // Estrutura para mensagem recebida
  TMensagemRecebida = record
    Numero: string;
    Mensagem: string;
    Timestamp: TDateTime;
    Tipo: string; // 'text', 'file', 'image', etc.
  end;

  // Estrutura para mensagem a ser enviada
  TMensagemEnviar = record
    Numero: string;
    Mensagem: string;
    CaminhoArquivo: string;
    NomeArquivo: string;
    Tipo: string; // 'text', 'file', 'image'
  end;

  // Estado do chat para cada usuário
  TChatState = record
    Estado: TChatStateType;
    SetorEscolhido: Integer;
    //SetorEscolhido: TSetorType;
    //TipoEscolhido: TTipoDocumento;
    TipoEscolhido: Integer;
    MesEscolhido: string;
    EmpresaID: Integer;
    UltimaInteracao: TDateTime;
  end;

  // Resultado de operação
  TResultadoOperacao = record
    Sucesso: Boolean;
    Mensagem: string;
    Dados: string;
  end;

  TSetor = record
    ID_Setor          : Integer;
    Descricao         : string;
  end;

  TSetores = TArray<TSetor>;

  TTiposDocumento = TArray<TTipoDocumento>;

  FieldRecord       = record
                        Table         : String;
                        Session       : String;
                        Name          : String;
                        Value         : String;
                        DefaultValue  : String;
                        Typed         : String;
                        Encript       : Boolean;
                        Changed       : Boolean;
                      end;

  TFieldRecord      = Array of FieldRecord;    {Campos}
  TFieldRecords     = Array of TFieldRecord;         {Registros}
  TTableRegister    = Array of TFieldRecords;        {Tabelas}
  TDatabaseRegister = Array of TTableRegister; {Banco de Dados}
  TStringArray      = array of String;
  TStringArrayList  = Array of TStringList;
  TCharArray        = array of Char;
  TArrayStringList  = Array of TStringList;
  arrayChar         = array of Char;
  TAnsiString       = array of AnsiString;
  TAnsiStringArray  = array of AnsiString;

  TInfoAdaptador    = array of record
                        dwIndex	         : longint;
                        dwType           : longint;
                        dwMtu            : longint;
                        dwSpeed	         : extended;
                        dwPhysAddrLen    : longint;
                        bPhysAddr        : string;
                        dwAdminStatus    : longint;
                        dwOperStatus     : longint;
                        dwLastChange     : longint;
                        dwInOctets       : longint;
                        dwInUcastPkts    : longint;
                        dwInNUcastPkts   : longint;
                        dwInDiscards     : longint;
                        dwInErrors       : longint;
                        dwInUnknownProtos: longint;
                        dwOutOctets      : longint;
                        dwOutUcastPkts   : longint;
                        dwOutNUcastPkts  : longint;
                        dwOutDiscards    : longint;
                        dwOutErrors      : longint;
                        dwOutQLen        : longint;
                        dwDescrLen       : longint;
                        bDescr           : string;
                        sIpAddress       : string;
                        sIpMask          : string;
                      end;

  MIB_IFROW        = record
                     wszName          : array[0 .. (MAX_INTERFACE_NAME_LEN * 2 - 1)] of ansichar;
                     dwIndex          : longint;
                     dwType           : longint;
                     dwMtu            : longint;
                     dwSpeed          : longint;
                     dwPhysAddrLen    : longint;
                     bPhysAddr        : array[0 .. (MAXLEN_PHYSADDR - 1)] of byte;
                     dwAdminStatus    : longint;
                     dwOperStatus     : longint;
                     dwLastChange     : longint;
                     dwInOctets       : longint;
                     dwInUcastPkts    : longint;
                     dwInNUcastPkts   : longint;
                     dwInDiscards     : longint;
                     dwInErrors       : longint;
                     dwInUnknownProtos: longint;
                     dwOutOctets      : longint;
                     dwOutUcastPkts   : longint;
                     dwOutNUcastPkts  : longint;
                     dwOutDiscards    : longint;
                     dwOutErrors      : longint;
                     dwOutQLen        : longint;
                     dwDescrLen       : longint;
                     bDescr           : array[0 .. (MAXLEN_IFDESCR - 1)] of ansichar;
                     end;

  MIB_IPADDRROW    = record
                     dwAddr           : longint;
                     dwIndex          : longint;
                     dwMask           : longint;
                     dwBCastAddr      : longint;
                     dwReasmSize      : longint;
                     unused1          : word;
                     unused2          : word;
                     end;

  _SeTabela        = record
                     nRows: longint;
                     ifRow: array[1.._MAX_ROWS_] of MIB_IFROW;
                     end;

  _IpTabela        = record
                     dwNumEntries: longint;
                     table: array[1..ANY_SIZE] of MIB_IPADDRROW;
                     end;

implementation

{ TUploadDocumento }

end.
