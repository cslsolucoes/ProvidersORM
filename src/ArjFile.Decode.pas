{ =============================================================================
  ArjFile.Decode - Binding do decoder ARJ nativo (decode.c do SDK ARJ 3.10)

  Liga o objeto ArjDecode (Library/<plat>/, compilado do sdk/arj/decode.c com
  SFX_LEVEL=2) e fornece em Pascal todo o ambiente que o decoder espera:
  entrada byte-a-byte (arj_fgetc sobre TStream), saida por blocos
  (extraction_stub para TStream), estado partilhado (bitbuf/dec_text/tabelas
  Huffman) e tratamento de erro (error_proc lanca EArjError). Cobre os
  methods 1-3 (LZSS + Huffman dinamico); method 4 (decode_f) ficou fora do
  objeto no nivel SFX usado e continua nao suportado.

  O estado do decoder C e global (single-instance) - o acesso e serializado
  por seccao critica. CRC32 (IEEE, mesmo polinomio do ZIP) e calculado sobre
  a saida para validacao contra o original_crc32 do header.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           05/07/2026

  Changelog (file):
  - 1.0.0 (05/07/2026): v3 F1-A (formato ARJ, decisao do owner: objetos C do
    plano upstream). Objetos compilados com redirects fgetc->arj_fgetc e
    free->arj_free; msg headers e largeint supridos por stubs no compat do
    SDK. Nomes C: Win32 com underscore (Delphi verbatim; FPC decora cdecl),
    Win64 sem prefixo - mesmo esquema da unit LZMA.
  ============================================================================= }
unit ArjFile.Decode;

// MODE OBJFPC (nao DELPHI): a diretiva 'public name' em VARIAVEIS - necessaria
// para dar aos globals partilhados o nome C que o objeto importa - so e
// reconhecida pelo parser do FPC em modo objfpc. A unit e procedural pura.
{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

interface

uses
  SysUtils,
  Classes;

{ True quando o decoder nativo esta disponivel neste alvo (Win32/Win64). }
function ArjDecodeAvailable: Boolean;

{ Descomprime uma entry ARJ (methods 1-3) lendo ACompSize bytes de ASrc
  (posicionado no DataOffset da entry) e escrevendo AOrigSize bytes em ADst.
  ACrc32 devolve o CRC32 (IEEE) da saida para validacao contra o header.
  Lanca EArjError (via ArjFile.Exceptions) em dados corrompidos. }
function ArjDecodeToStream(ASrc: TStream; ACompSize, AOrigSize: Cardinal;
  ADst: TStream; out ACrc32: Cardinal): Boolean;

implementation

uses
  SyncObjs,
  ArjFile.Exceptions;

{$IF DEFINED(WIN32) OR DEFINED(WIN64)}
  {$DEFINE ARJ_DECODE_AVAILABLE}
{$IFEND}

{$IFDEF ARJ_DECODE_AVAILABLE}

// =============================================================================
//   Linkagem dos objetos (mesmo esquema por toolchain da ZipFile.Compression.LZMA)
// =============================================================================
{$IFDEF FPC}
  {$LINKLIB msvcrt}   // memset + __imp__longjmp (import lib mingw via -Fl)
  {$IFDEF WIN32}
    {$L Library\fpc-win32\ArjDecode.o}
  {$ELSE}
    {$L Library\fpc-win64\ArjDecode.o}
  {$ENDIF}
{$ELSE}
  {$IFDEF WIN32}
    {$L Library\delphi-win32\ArjDecode.obj}
  {$ELSE}
    {$L Library\delphi-win64\ArjDecode.o}
  {$ENDIF}
{$ENDIF}

// C name mangling: Win32 OMF/COFF usa prefixo '_'; Win64 usa nome bare.
//  - Delphi external/identificador: verbatim (Win32 precisa do '_' explicito).
//  - FPC cdecl external: decora sozinho no Win32 -> usar nome bare;
//    FPC public name: verbatim -> dar o nome final com '_' no Win32.
{$IF DEFINED(WIN32) AND NOT DEFINED(FPC)}
  {$DEFINE C_PREFIX_UNDERSCORE}
{$IFEND}

const
  ARJ_DICSIZ = 26624;              // dicionario LZSS (DICSIZ do arj.h)
  ARJ_NC     = 510;                // 255 + MAXMATCH(256) + 2 - THRESHOLD(3)
  ARJ_NPT    = 32;                 // NPT real = 19 (NT); folga segura

// =============================================================================
//   Estado partilhado com o objeto (o C importa; o Pascal define)
// =============================================================================
// Aliases g* (absolute) dao acesso neutro independente do prefixo de simbolo.

{$IFDEF C_PREFIX_UNDERSCORE}
var
  _aistream: Pointer;
  _compsize: Cardinal;
  _origsize: Cardinal;
  _file_packing: Integer;
  _file_garbled: Integer;
  _packblock_ptr: Pointer;
  _packmem_remain: Cardinal;
  _bitbuf: Word;
  _bitcount: Integer;
  _byte_buf: Byte;
  _dec_text: array[0..ARJ_DICSIZ - 1] of Byte;
  _c_len: array[0..ARJ_NC - 1] of Byte;
  _pt_len: array[0..ARJ_NPT - 1] of Byte;
  _left: array[0..2 * ARJ_NC - 2] of Word;
  _right: array[0..2 * ARJ_NC - 2] of Word;
var
  gcompsize: Cardinal absolute _compsize;
  gorigsize: Cardinal absolute _origsize;
  gfile_packing: Integer absolute _file_packing;
  gfile_garbled: Integer absolute _file_garbled;
  gaistream: Pointer absolute _aistream;
  gpackblock_ptr: Pointer absolute _packblock_ptr;
  gpackmem_remain: Cardinal absolute _packmem_remain;
  gbitbuf: Word absolute _bitbuf;
  gbitcount: Integer absolute _bitcount;
  gbyte_buf: Byte absolute _byte_buf;
{$ELSE}
var
  aistream: Pointer; {$IFDEF FPC}public name {$IFDEF WIN32}'_aistream'{$ELSE}'aistream'{$ENDIF};{$ENDIF}
  compsize: Cardinal; {$IFDEF FPC}public name {$IFDEF WIN32}'_compsize'{$ELSE}'compsize'{$ENDIF};{$ENDIF}
  origsize: Cardinal; {$IFDEF FPC}public name {$IFDEF WIN32}'_origsize'{$ELSE}'origsize'{$ENDIF};{$ENDIF}
  file_packing: Integer; {$IFDEF FPC}public name {$IFDEF WIN32}'_file_packing'{$ELSE}'file_packing'{$ENDIF};{$ENDIF}
  file_garbled: Integer; {$IFDEF FPC}public name {$IFDEF WIN32}'_file_garbled'{$ELSE}'file_garbled'{$ENDIF};{$ENDIF}
  packblock_ptr: Pointer; {$IFDEF FPC}public name {$IFDEF WIN32}'_packblock_ptr'{$ELSE}'packblock_ptr'{$ENDIF};{$ENDIF}
  packmem_remain: Cardinal; {$IFDEF FPC}public name {$IFDEF WIN32}'_packmem_remain'{$ELSE}'packmem_remain'{$ENDIF};{$ENDIF}
  bitbuf: Word; {$IFDEF FPC}public name {$IFDEF WIN32}'_bitbuf'{$ELSE}'bitbuf'{$ENDIF};{$ENDIF}
  bitcount: Integer; {$IFDEF FPC}public name {$IFDEF WIN32}'_bitcount'{$ELSE}'bitcount'{$ENDIF};{$ENDIF}
  byte_buf: Byte; {$IFDEF FPC}public name {$IFDEF WIN32}'_byte_buf'{$ELSE}'byte_buf'{$ENDIF};{$ENDIF}
  dec_text: array[0..ARJ_DICSIZ - 1] of Byte; {$IFDEF FPC}public name {$IFDEF WIN32}'_dec_text'{$ELSE}'dec_text'{$ENDIF};{$ENDIF}
  c_len: array[0..ARJ_NC - 1] of Byte; {$IFDEF FPC}public name {$IFDEF WIN32}'_c_len'{$ELSE}'c_len'{$ENDIF};{$ENDIF}
  pt_len: array[0..ARJ_NPT - 1] of Byte; {$IFDEF FPC}public name {$IFDEF WIN32}'_pt_len'{$ELSE}'pt_len'{$ENDIF};{$ENDIF}
  left: array[0..2 * ARJ_NC - 2] of Word; {$IFDEF FPC}public name {$IFDEF WIN32}'_left'{$ELSE}'left'{$ENDIF};{$ENDIF}
  right: array[0..2 * ARJ_NC - 2] of Word; {$IFDEF FPC}public name {$IFDEF WIN32}'_right'{$ELSE}'right'{$ENDIF};{$ENDIF}
var
  gcompsize: Cardinal absolute compsize;
  gorigsize: Cardinal absolute origsize;
  gfile_packing: Integer absolute file_packing;
  gfile_garbled: Integer absolute file_garbled;
  gaistream: Pointer absolute aistream;
  gpackblock_ptr: Pointer absolute packblock_ptr;
  gpackmem_remain: Cardinal absolute packmem_remain;
  gbitbuf: Word absolute bitbuf;
  gbitcount: Integer absolute bitcount;
  gbyte_buf: Byte absolute byte_buf;
{$ENDIF}

// =============================================================================
//   Contexto Pascal do decode em curso (protegido por GLock)
// =============================================================================
var
  GLock: TCriticalSection;
  GSrc: TStream;                    // entrada (posicionada no DataOffset)
  GDst: TStream;                    // saida descomprimida
  GCrc: Cardinal;                   // CRC32 em curso (IEEE, invertido)
  GCrcTable: array[0..255] of Cardinal;
  // buffer de entrada: o decoder consome byte-a-byte (fgetc); ler os dados
  // comprimidos de uma vez evita milhoes de TStream.Read de 1 byte
  GBuf: TBytes;
  GBufPos: NativeInt;

procedure InitCrcTable;
var
  I, J: Integer;
  C: Cardinal;
begin
  for I := 0 to 255 do
  begin
    C := Cardinal(I);
    for J := 0 to 7 do
      if (C and 1) <> 0 then
        C := $EDB88320 xor (C shr 1)
      else
        C := C shr 1;
    GCrcTable[I] := C;
  end;
end;

// =============================================================================
//   Importados do objeto
// =============================================================================
{$IFDEF FPC}
procedure decode(action: Integer); cdecl; external name 'decode';
procedure fillbuf(n: Integer); cdecl; external name 'fillbuf';
{$ELSE}
  {$IFDEF C_PREFIX_UNDERSCORE}
procedure decode(action: Integer); cdecl; external name '_decode';
procedure fillbuf(n: Integer); cdecl; external name '_fillbuf';
  {$ELSE}
procedure decode(action: Integer); cdecl; external name 'decode';
procedure fillbuf(n: Integer); cdecl; external name 'fillbuf';
  {$ENDIF}
{$ENDIF}

// =============================================================================
//   Exportados para o objeto (callbacks e ambiente)
// =============================================================================

// entrada byte-a-byte: fgetc redirecionado no build (-Dfgetc=arj_fgetc)
{$IFDEF C_PREFIX_UNDERSCORE}
function _arj_fgetc(AStream: Pointer): Integer; cdecl;
{$ELSE}
function arj_fgetc(AStream: Pointer): Integer; cdecl;
  {$IFDEF FPC}public name {$IFDEF WIN32}'_arj_fgetc'{$ELSE}'arj_fgetc'{$ENDIF};{$ENDIF}
{$ENDIF}
begin
  if GBufPos < Length(GBuf) then
  begin
    Result := GBuf[GBufPos];
    Inc(GBufPos);
  end
  else
    Result := -1;
end;

// free redirecionado (-Dfree=arj_free); nivel SFX=2 nao aloca, stub por seguranca
{$IFDEF C_PREFIX_UNDERSCORE}
procedure _arj_free(P: Pointer); cdecl;
{$ELSE}
procedure arj_free(P: Pointer); cdecl;
  {$IFDEF FPC}public name {$IFDEF WIN32}'_arj_free'{$ELSE}'arj_free'{$ENDIF};{$ENDIF}
{$ENDIF}
begin
  if P <> nil then
    FreeMem(P);
end;

// saida por blocos; retorno <> 0 aborta o decode
{$IFDEF C_PREFIX_UNDERSCORE}
function _extraction_stub(ABlock: PAnsiChar; ALen, AAction: Integer): Integer; cdecl;
{$ELSE}
function extraction_stub(ABlock: PAnsiChar; ALen, AAction: Integer): Integer; cdecl;
  {$IFDEF FPC}public name {$IFDEF WIN32}'_extraction_stub'{$ELSE}'extraction_stub'{$ENDIF};{$ENDIF}
{$ENDIF}
var
  I: Integer;
  P: PByte;
begin
  Result := 0;
  if ALen <= 0 then
    Exit;
  P := PByte(ABlock);
  for I := 0 to ALen - 1 do
    GCrc := GCrcTable[(GCrc xor P[I]) and $FF] xor (GCrc shr 8);
  if GDst <> nil then
    GDst.WriteBuffer(ABlock^, ALen);
end;

// inicializacao do estado de bits (semantica de arj_file.c decode_start_stub)
{$IFDEF C_PREFIX_UNDERSCORE}
procedure _decode_start_stub; cdecl;
{$ELSE}
procedure decode_start_stub; cdecl;
  {$IFDEF FPC}public name {$IFDEF WIN32}'_decode_start_stub'{$ELSE}'decode_start_stub'{$ENDIF};{$ENDIF}
{$ENDIF}
begin
  gbitbuf := 0;
  gbyte_buf := 0;
  gbitcount := 0;
  fillbuf(16);   // CHAR_BIT * 2
end;

// erro fatal do decoder -> excecao de dominio (nunca retorna)
{$IFDEF C_PREFIX_UNDERSCORE}
function _error_proc(AMsg: PAnsiChar): Integer; cdecl;
{$ELSE}
function error_proc(AMsg: PAnsiChar): Integer; cdecl;
  {$IFDEF FPC}public name {$IFDEF WIN32}'_error_proc'{$ELSE}'error_proc'{$ENDIF};{$ENDIF}
{$ENDIF}
begin
  Result := 0;
  raise EArjError.Create(string(AnsiString(AMsg)));
end;

// progresso: nao usado (facade tem o seu proprio TZipProgressEvent)
{$IFDEF C_PREFIX_UNDERSCORE}
procedure _display_indicator(ABytes: LongInt); cdecl;
{$ELSE}
procedure display_indicator(ABytes: LongInt); cdecl;
  {$IFDEF FPC}public name {$IFDEF WIN32}'_display_indicator'{$ELSE}'display_indicator'{$ENDIF};{$ENDIF}
{$ENDIF}
begin
end;

// decriptacao garble: nunca chamada (file_garbled = 0)
{$IFDEF C_PREFIX_UNDERSCORE}
procedure _garble_decode(AData: PAnsiChar; ALen: Integer); cdecl;
{$ELSE}
procedure garble_decode(AData: PAnsiChar; ALen: Integer); cdecl;
  {$IFDEF FPC}public name {$IFDEF WIN32}'_garble_decode'{$ELSE}'garble_decode'{$ENDIF};{$ENDIF}
{$ENDIF}
begin
end;

// delay de erro do SFX: irrelevante aqui
{$IFDEF C_PREFIX_UNDERSCORE}
procedure _arj_delay(ASeconds: Cardinal); cdecl;
{$ELSE}
procedure arj_delay(ASeconds: Cardinal); cdecl;
  {$IFDEF FPC}public name {$IFDEF WIN32}'_arj_delay'{$ELSE}'arj_delay'{$ENDIF};{$ENDIF}
{$ENDIF}
begin
end;

{$IFNDEF FPC}
// CRT para os objetos Delphi (no FPC vem do msvcrt via LINKLIB).
{$IFDEF C_PREFIX_UNDERSCORE}
function _memset(ADest: Pointer; AValue: Integer; ACount: NativeUInt): Pointer; cdecl;
{$ELSE}
function memset(ADest: Pointer; AValue: Integer; ACount: NativeUInt): Pointer; cdecl;
{$ENDIF}
begin
  FillChar(ADest^, ACount, Byte(AValue));
  Result := ADest;
end;

// longjmp: no nivel SFX=2 o setjmp e compilado fora e o error_proc lanca
// excecao antes de qualquer longjmp - simbolo so para satisfazer o link.
{$IFDEF C_PREFIX_UNDERSCORE}
procedure _longjmp(AEnv: Pointer; AVal: Integer); cdecl;
{$ELSE}
procedure longjmp(AEnv: Pointer; AVal: Integer); cdecl;
{$ENDIF}
begin
  raise EArjError.Create('ARJ decoder: longjmp inesperado (dados corrompidos)');
end;
{$ENDIF}

{$ENDIF} // ARJ_DECODE_AVAILABLE

// =============================================================================
//   API publica
// =============================================================================

function ArjDecodeAvailable: Boolean;
begin
  {$IFDEF ARJ_DECODE_AVAILABLE}
  Result := True;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function ArjDecodeToStream(ASrc: TStream; ACompSize, AOrigSize: Cardinal;
  ADst: TStream; out ACrc32: Cardinal): Boolean;
{$IFDEF ARJ_DECODE_AVAILABLE}
begin
  Result := False;
  ACrc32 := 0;
  if (ASrc = nil) or (ADst = nil) then
    Exit;

  GLock.Acquire;
  try
    GSrc := ASrc;
    GDst := ADst;
    GCrc := $FFFFFFFF;
    // carregar o bloco comprimido inteiro (PackedSize conhecido do header)
    SetLength(GBuf, ACompSize);
    if ACompSize > 0 then
      ASrc.ReadBuffer(GBuf[0], ACompSize);
    GBufPos := 0;
    gaistream := nil;          // nao usado: arj_fgetc le de GSrc
    gcompsize := ACompSize;
    gorigsize := AOrigSize;
    gfile_packing := 1;        // caminho fgetc (stream), nao RAM-block
    gfile_garbled := 0;        // sem encriptacao
    gpackblock_ptr := nil;
    gpackmem_remain := 0;

    decode(0);

    ACrc32 := GCrc xor $FFFFFFFF;
    Result := True;
  finally
    GSrc := nil;
    GDst := nil;
    GBuf := nil;
    GLock.Release;
  end;
end;
{$ELSE}
begin
  Result := False;
  ACrc32 := 0;
end;
{$ENDIF}

initialization
  {$IFDEF ARJ_DECODE_AVAILABLE}
  GLock := TCriticalSection.Create;
  InitCrcTable;
  {$ENDIF}

finalization
  {$IFDEF ARJ_DECODE_AVAILABLE}
  GLock.Free;
  {$ENDIF}

end.
