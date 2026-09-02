{ ==========================================================================
  PROVENANCE NOTE (ProvidersORM v3, FASE 10 Onda 10.2 - USE_PROVIDERS_V161):
  Absorbed VERBATIM from FontesReferencias/ProvidersORM.v1.6.1/Utilities/Utilities.Strings.pas
  into this v3 tree as part of the USE_PROVIDERS_V161 compatibility subsystem
  (legacy ProvidersORM v1.6.1, mechanical port only - zero logic/behavior/
  symbol-name changes; see the unit's own original header below for the
  authorial history). Reachable via uses Providers.v161 - NOT part of the
  unified TProviders facade (Main/Providers.pas).

  MECHANICAL FIX: the FPC branch of the uses clause imported Graphics,
  Dialogs, Forms (Lazarus LCL units) unconditionally, same issue and same
  fix as Utilities.Consts.pas - dropped from the FPC branch (this project's
  FPC target has no LCL search path). The single live call that needed
  Dialogs under FPC+Windows (ShowMessage inside Log's except handler) has
  its guard corrected from MSWINDOWS-only to MSWINDOWS-and-not-FPC so FPC
  always takes the existing Writeln fallback branch (same pattern used in
  Main/Providers.v161.pas). Zero symbol/logic change for Delphi. File
  re-saved as UTF-8 BOM (source snapshot was Windows-1252 - re-encoded, not
  re-typed; same characters/codepoints, including the utf8/acentos lookup
  arrays in Utilities.Consts.pas, which round-trip byte-identically through
  a correct cp1252 to UTF-8 conversion).
  ========================================================================== }

{
API Strings - Manipulação de Strings
Versão : 1.0.2
Autor: Claiton de Souza Linhares
Criação : 01/07/2019
Atualização: 02/07/2023 - atualização realizada de campos senteças (Sessao, Padrão, Encriptação)
Atualização: 05/07/2023 - atualização realizada função caracter se caNumero retorna 0 caso string vazia
Atualização: 24/03/2024 - compatibilização com Delphi 11
Atualização: 30/07/2025 - compatibilização com Delphi 12
}
unit Utilities.Strings;


{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}
{$ifdef FPC}
    {$mode objfpc}{$H+}
{$endif}

interface

uses
{$ifdef FPC}
   Classes, SysUtils;
{$else}
 {$IF defined(MSWINDOWS)}
  Vcl.Graphics,  Vcl.Dialogs, Vcl.Forms,
 {$ENDIF}
  System.Classes, System.SysUtils, System.StrUtils,
{$endif}
  Utilities.Consts,Utilities.Types;

Type

  TTipoVariavel = record
    Numerico   : String;
    Caracter   : String;
    Hora       : String;
    Data       : String;
    DataHora   : String;
    Booleano   : String;
    function tipo(AValor : String) : integer;
  End;

  TUtilitiesWhatsapp = class
  public

    // Formatação de números de telefone
    class function FormatarNumero(const Numero: string): string;
    class function LimparNumero(const Numero: string): string;
    class function NormalizarNumeroParaBusca(const NumeroLimpo: string): TArray<string>;

    // Conversão de meses
    class function ConverterMesParaNumero(const Mes: string): string;
    class function ConverterNumeroParaMes(const Numero: string): string;

    // Validações
    class function ValidarNumero(const Numero: string): Boolean;
    class function ValidarMes(const Mes: string): Boolean;
    //class function TipoDocumentoParaString(const Tipo: TTipoDocumento): string;

    // Utilitários de texto
    class function NormalizarTexto(const Texto: string): string;
    class function ExtrairComando(const Mensagem: string): string;

    // Novas funções
    class function FormatarNumeroEnvio(const Numero: string): string;
  end;

  Function  FCrypta   (VFString:String)                             : String;
  Function  FDesCrypta(VFString:String)                             : String;
  Function  Log(valor: String; const arquivo: String) : Boolean;

  Procedure ArrayReserveFast(var a: TStringArray; const len: longint; const reserveLength: longint);
{$ifdef FPC}
  Procedure strSplit(out splitted: TStringArray; s, sep: string; includeEmpty: boolean);
  Function  strSplit(const s, sep: string; includeEmpty: boolean) : TStringArray;
  Function  ArrayToString( ArrayValor : TStringArray ; const Delimiter : char = ',') : String;
{$Else}
  Function StringArrayToArrayChar(const StrArray: tStringArray): ArrayChar;
  Procedure PstrSplit(out splitted: TStringArray; s, sep: string; includeEmpty: boolean);
  Function  FstrSplit(const s, sep: string; includeEmpty: boolean) : TStringArray;
  Function  FArrayToString( ArrayValor : TStringArray ; const Delimiter : char = ',') : String;
{$endif}

  Function  ArrayToString(A: arrayChar): String;
  Function  ArrayAddFast(var a: TStringArray; var len: longint; const e: string): longint;
  Function  Strlsequal(p1,p2:pchar;l1,l2: longint):boolean;
  Function  StrlsIndexOf(str, searched: pchar; l1, l2: longint): longint;
  Function  Strindexof(const str, searched: string; from: longint): longint;
  Function  StrCopyFrom(const s: string; start: longint): string; inline;overload;

  Function  ArrayField(valor: string; delimitador: char; campo: integer): String; overload;
  Function  ArrayField(valor: string; campo: integer): String; overload;
  Function  ArrayFieldCount(valor: string; const delimitador: char = #0): Integer;
  Function  StringToArray( strValor : String ; Const Delimiter : Char = ',' ; Const IncluirVazio : Boolean = False) : TStringArray;
  Function  StrAlignLeft(valor: string; tam: integer; const alinha: char = 'E'): String;
  Function  StrAlignRigth(valor: string; tam: integer; const alinha: char = 'D'): String;
  Function  StrAlignCenter(valor: string; tam: integer; const alinha: char = 'C'): String;

//  Function  AcentosToUTF8(Valor: String) : String;
  Function  IPAddress (valor:string; const tipo:char = 'B') : String;
  Function  MACAddress(valor:string; const tipo:char = 'A') : String;
  Function  caracter  (valor:string; const tipo:char = 'E') : String;
  Function  espacos   (valor:string; tam :integer ; const alinha:char = 'E')    : String;
  Function EmailValido(const Email: string): Boolean;

Var
  _Delimiter  : Char;

implementation


function EmailValido(const Email: string): Boolean;
var
  AtPos, DotPos: Integer;
begin
  Result := False;
  AtPos := Pos('@', Email);
  if AtPos > 1 then
  begin
    DotPos := Pos('.', Copy(Email, AtPos + 1, MaxInt));
    if DotPos > 0 then
      DotPos := DotPos + AtPos;
    Result := DotPos > AtPos + 1;
  end;
end;

procedure ArrayReserveFast(var a: TStringArray; const len: longint;
  const reserveLength: longint);
begin
  if reserveLength <= len then exit;
  if reserveLength <= length(a) then exit;
  if reserveLength <= 4  then SetLength(a, 4)
  else if reserveLength <= 16 then SetLength(a, 16)
  else if (len <= 1024) and (reserveLength <= 2*len) then SetLength(a, 2*len)
  else if (length(a) <= 1024) and (reserveLength <= 2*length(a)) then SetLength(a, 2*length(a))
  else if (reserveLength <= len+1024) then SetLength(a, len+1024)
  else if (reserveLength <= length(a)+1024) then SetLength(a, length(a)+1024)
  else SetLength(a, reserveLength);
end;

{$ifdef FPC}
  Procedure strSplit(out splitted: TStringArray; s, sep: string; includeEmpty: boolean);
{$Else}
Function StringArrayToArrayChar(const StrArray: tStringArray): ArrayChar;
var
  i, j, len: Integer;
begin
  len := 0;
  // Calcula o comprimento total do array de caracteres
  for i := Low(StrArray) to High(StrArray) do
    len := len + Length(StrArray[i]);

  // Aloca memória para o array de caracteres
  SetLength(Result, len);

  // Copia os caracteres para o array de caracteres
  len := 0;
  for i := Low(StrArray) to High(StrArray) do
  begin
    for j := 1 to Length(StrArray[i]) do
    begin
      Result[len] := StrArray[i][j];
      Inc(len);
    end;
  end;
end;

Procedure PstrSplit(out splitted: TStringArray; s, sep: string; includeEmpty: boolean);
{$endif}
var p:longint;
    m: longint;
    reslen: longint;
begin
  SetLength(splitted,0);
  reslen := 0;
  if s='' then begin
    if includeEmpty then begin
      SetLength(splitted, 1);
      splitted[0] := '';
    end;
    exit;
  end;
  p:=pos(sep,s);
  m:=1;
  while p>0 do begin
    if p=m then begin
      if includeEmpty then
        arrayAddFast(splitted, reslen, '');
    end else
      arrayAddFast(splitted, reslen, copy(s,m,p-m));
    m:=p+length(sep);
    p:=strindexof(s, sep, m);
  end;
  if (m<>length(s)+1) or includeEmpty then
    arrayAddFast(splitted, reslen, strcopyfrom(s,m));
  SetLength(splitted, reslen);
end;

{$ifdef FPC}
function strSplit(const s, sep: string; includeEmpty: boolean): TStringArray;
{$Else}
Function  FstrSplit(const s, sep: string; includeEmpty: boolean) : TStringArray;
{$endif}
Var p, m, reslen: Longint;
    splitted: TStringArray;
Begin
  SetLength(splitted, 0);
  reslen := 0;
  If s = '' Then
  Begin
    If includeEmpty Then
    Begin
      SetLength(splitted, 1);
      splitted[0] := '';
    End;
    exit;
  End;
  p := pos(sep, s);
  m := 1;
  While p > 0 Do
  Begin
    If p = m Then
    Begin
      If includeEmpty Then
        arrayAddFast(splitted, reslen, '');
    End
    Else
      arrayAddFast(splitted, reslen, copy(s, m, p - m));
    m := p + length(sep);
    p := strindexof(s, sep, m);
  End;
  If (m <> length(s) + 1) Or includeEmpty Then
    arrayAddFast(splitted, reslen, strcopyfrom(s, m));
  SetLength(splitted, reslen);
  Result := splitted;
end;

function ArrayToString(A: arrayChar): String;
 var i: integer;
begin
  Result := '';
  for i := 0 to High(A) do
    Result := Result + A[i];
end;

function ArrayAddFast(var a: TStringArray; var len: longint; const e: string
  ): longint;
begin
  if len >= length(a) then
  arrayReserveFast(a, len, len+1);
  result:=len;
  len := len +1;
  a[result] := Trim(e);
end;

function Strlsequal(p1, p2: pchar; l1, l2: longint): boolean;
 var i:integer;
begin
  result:=l1=l2;
  if not result then exit;
  for i:=0 to l1-1 do
    if p1[i]<>p2[i] then
      exit(false);      end;

function StrlsIndexOf(str, searched: pchar; l1, l2: longint): longint;
 var last: pchar;
begin
  if l2<=0 then exit(0);
  if l1<l2 then exit(-1);
  last:=str+(l1-l2);
  result:=0;
  while str <= last do begin
    if str^ = searched^ then
      if strlsequal(str, searched, l2, l2) then
        exit();
    inc(str);
    result := result + 1;
  end;
  result := -1;
end;

function Strindexof(const str, searched: string; from: longint): longint;
begin
  if from > length(str) then exit(0);
  result := strlsIndexOf(pchar(pointer(str))+from-1, pchar(pointer(searched)), length(str) - from + 1, length(searched));
  if result < 0 then exit(0);
  result := result + from;
end;

function StrCopyFrom(const s: string; start: longint): string;
begin
  result:=copy(s,start,length(s)-start+1);
end;

function ArrayField(valor: string; delimitador: char; campo: integer): String;
var
s,t:string;
i,c:integer;
sair:boolean;
begin
  s := '';
  t := '';
  i :=  0;
  c :=  1;
  sair := false;
  repeat
    inc(i);
    if (c = campo) and (i = length(valor))
    then begin
         if valor[i] <> delimitador then s := s + valor[i];
         t      := s;
         Result := t;
         sair   := true;
         end;

    if (valor = '')
    then sair := true
    else begin
         if (valor[i] = delimitador) and (t = '') and not sair
         then begin
              if c = campo
              then begin
                   t      := s;
                   Result := t;
                   end
              else begin
                   s      := '';
                   inc(c);
                   end
              end
         else if not sair then s := s + valor[i];
         end;
    if (i = length(valor)) and (t = '') then Result := '';

  until (i = length(valor)) or ((c = campo) and (t <> '')) or (sair = true);
end;

function  ArrayField(valor: string; campo: integer): String; overload;
Begin
  ArrayField(valor,',',campo);
End;

function ArrayFieldCount(valor: string; const delimitador: char): Integer;
var
i,c:integer;

D : String;
begin
  _Delimiter := ',';

  If delimitador = #0 then
     D := _Delimiter
  Else
     D := delimitador;

  c :=  1;
  for i := 1 to length(valor)
  do begin
     if valor[i] = D
     then begin
          inc(c);
          end;
     end;
  Result := c;
end;

function StringToArray(strValor: String; const Delimiter: Char;
  const IncluirVazio: Boolean): TStringArray;
Var p, m, reslen: Longint;
    srtArray: TStringArray;
Begin
    _Delimiter := Delimiter;

  //Zerando variáveis
  SetLength(srtArray, 0);
  reslen := 0;
  //checando string se é vazio
  If strValor = EmptyStr Then
  Begin
    If IncluirVazio Then
    Begin
      SetLength(srtArray, 1);
      srtArray[0] := EmptyStr;
    End;
    exit;
  End;

  p := pos(Delimiter, strValor);
  m := 1;

  While p > 0 Do
  Begin

    If p = m Then
    Begin
      If IncluirVazio Then
        arrayAddFast(srtArray, reslen, '');
    End
    Else
      arrayAddFast(srtArray, reslen, copy(strValor, m, p - m));

    m := p + length(Delimiter);
    p := strindexof(strValor, Delimiter, m);

  End;

  If (m <> length(strValor) + 1) Or IncluirVazio Then
    arrayAddFast(srtArray, reslen, strcopyfrom(strValor, m));

  SetLength(srtArray, reslen);
  Result := srtArray;
end;

{$ifdef FPC}
  Function  ArrayToString( ArrayValor : TStringArray ; const Delimiter : char = ',') : String;
{$Else}
  Function  FArrayToString( ArrayValor : TStringArray ; const Delimiter : char = ',') : String;
{$endif}
Var
    s : String;
    i : Integer;
begin
  _Delimiter := Delimiter;
  s := '';
  for i := 0 to High(ArrayValor) do
    s := s + ArrayValor[i] + Delimiter;
  Result := copy(s,1,Length(s) - 1);
end;

function StrAlignLeft(valor: string; tam: integer; const alinha: char): String;
var
i,j,t:integer;
s,m:string;
begin
//   alinha := upcase(alinha);
   s   := '';
   m   := '';

   valor := copy(valor,1,tam);
   tam := tam - length(valor);


   case upCase(alinha) of

     'D':begin
         for i := 1 to tam do
             s := s + ' ';
         Result := s + valor;
         end;

     'E':begin
         for i := 1 to tam do
             s := s + ' ';
         Result := valor + s;
         end;

     'C':begin
         t := tam div 2;
         j := tam mod 2;
         for i := 1 to (t + j) do
             s := s + ' ';
         for i := 1 to t do
             m := m + ' ';
         Result := s + valor + m;
         end;

     'L':begin
         for i:= 1 to length(valor) do
             if valor[i] in ['a'..'z','A'..'Z','=',',',':','|','!'] then  s := s + valor[i];
         Result := s;
         end;
   end;
end;

function StrAlignRigth(valor: string; tam: integer; const alinha: char): String;
begin
  Result := StrAlignLeft(valor,tam,alinha);
end;

function StrAlignCenter(valor: string; tam: integer; const alinha: char
  ): String;
begin
  Result := StrAlignLeft(valor,tam,alinha);
end;
{
function AcentosToUTF8(Valor: String): String;
Var
  i, j, k: integer;
  Str : String;
begin
  Str:=Valor;
  for j := 1 to 46 do begin
    Str := StringReplace(Str,acentos[j] , utf8[j],[rfReplaceAll, rfIgnoreCase]);
  end;
  Result := Str;
end;
}
function IPAddress(valor: string; const tipo: char): String;

  function f (v:string):string;
  var
    s:string;
    t:integer;
  begin
  s := trim(v);
  if Length(s) < 3
  then for t := 1 to (3 - Length(s))
       do s :=  '0' + s;
  Result := s;
  end;
var
 t: integer;
 a: Array [1..4] of String;
 v: String;
begin
    valor := caracter(trim(valor),'I');

    if (valor = '')
    then Result := '';

    if  (not (ArrayFieldCount(valor,'.') > 3))
    then begin Result := ''; exit; end;

    for t := 1 to 4
    do if ArrayField(valor,'.',t) = ''
       then a[t] := '0'
       else a[t] := ArrayField(valor,'.',t) ;

    case upcase(tipo) of
        // com 12 caracteres (000.000.000.000)
        'A': v      := f(a[1]) + '.' +
                       f(a[2]) + '.' +
                       f(a[3]) + '.' +
                       f(a[4]) ;

        // minimo (0.0.0.0)
        'B': v      := IntToStr(StrToInt(f(a[1]))) + '.' +
                       IntToStr(StrToInt(f(a[2]))) + '.' +
                       IntToStr(StrToInt(f(a[3]))) + '.' +
                       IntToStr(StrToInt(f(a[4]))) ;

        // com 12 caracteres ()
        'C': v      := f(a[1]) + '.' +
                       f(a[2]) + '.' +
                       f(a[3]) + '.' +
                       f(a[4]) ;
    end;

    if  ((v = '000.000.000.000')
    or   (v = '0.0.0.0'))
    and ((upcase(tipo) = 'C')
    or   (upcase(tipo) = 'B'))
    then Result := ''
    else Result := v ;
end;

function MACAddress(valor: string; const tipo: char): String;
var
  t: integer;
  j: integer;
  s,r: string;
begin
  j := 0;
  case upcase(tipo) of
    // 00:00:00:00:00:00
    'A':begin
        s := trim(caracter(valor,'E'));
        if  (not Length(s) > 0)
        or  (s = '')
        then begin
             Result := '';
             exit;
             end;
        if Length(s) < 12
        then for t := 1 to (12 - Length(s))
             do  s :=  '0' + s;
        for t := 1 to Length(s)
        do begin
           inc(j);
           r := r + s[t];
           if  (j = 2)
           and (Length(s) > t)
           then begin
                j := 0;
                r := r + ':';
                end;
           end;
        Result := r;
        end;
     //001122334455
    'B':Result := trim(caracter(valor,'H'));
  end;
end;

function caracter(valor: string; const tipo: char): String;
var
 i:integer;
 j:integer;
 s:string;
begin
   s := '';
   case upcase(tipo) of
                             //12345
        '1': //1.00.00 Versão  10000
             s := Copy(valor,1,1) + '.' + Copy(valor,2,2) + '.' + Copy(valor,4,2);
                             //1234
        '2': //1.0.0.0 Versão  1000
             s := Copy(valor,1,1) + '.' + Copy(valor,2,1) + '.' + Copy(valor,3,1) + '.' + Copy(valor,4,4);
                                //12345678
        '3': //10.00.0000 Versão  10000000
             s := Copy(valor,1,2) + '.' + Copy(valor,3,2) + '.' + Copy(valor,5,4);

        '4':Begin
               for i := 1 to length(valor) do
                  if valor[i] in ['0'..'9','.']
                     then s := s + valor[i];
               if Length(s) = 0 Then s := '0';
            end;

        'D':for i := 1 to length(valor) do
                if valor[i] in ['A'..'Z']
                   then s := s + chr(ord(valor[i]) + 32)
                   else s := s + valor[i];

        'U':for i := 1 to length(valor) do
                if valor[i] in ['a'..'z']
                   then s := s + chr(ord(valor[i]) - 32)
                   else s := s + valor[i];

        'E':for i := 1 to length(valor) do
                if valor[i] in ['A'..'Z','a'..'z','0'..'9']
                   then s := s + valor[i];

        'H':for i := 1 to length(valor) do
                if valor[i] in ['A'..'F','a'..'f','0'..'9']
                   then s := s + valor[i];

        'N':for i := 1 to length(valor) do
                if valor[i] in ['0'..'9']
                   then s := s + valor[i];

        'I':for i := 1 to length(valor) do
                if valor[i] in ['0'..'9','.']
                   then s := s + valor[i];

            else s := s +  valor[i];
   end;
   Result := s;
end;

function espacos(valor: string; tam: integer; const alinha: char): String;
var
i,j,t:integer;
s,m:string;
begin
//   alinha := upcase(alinha);
   s   := '';
   m   := '';

   valor := copy(valor,1,tam);
   tam := tam - length(valor);


   case upCase(alinha) of

     'D':begin
         for i := 1 to tam do
             s := s + ' ';
         Result := s + valor;
         end;

     'E':begin
         for i := 1 to tam do
             s := s + ' ';
         Result := valor + s;
         end;

     'C':begin
         t := tam div 2;
         j := tam mod 2;
         for i := 1 to (t + j) do
             s := s + ' ';
         for i := 1 to t do
             m := m + ' ';
         Result := s + valor + m;
         end;

     'L':begin
         for i:= 1 to length(valor) do
             if valor[i] in ['a'..'z','A'..'Z','=',',',':','|','!'] then  s := s + valor[i];
         Result := s;
         end;
   end;
end;

function FCrypta(VFString: String): String;

   Function StrZero(VFString: String; VFTamanho: Integer): String;
   Var
   VFRetorno       : String;
   I,
   VFZerosAColocar : Integer;
   Begin
   VFZerosAColocar := VFTamanho - Length(TrimLeft(TrimRight(VFString)));
   VFRetorno       := '';

   For I := 1 To VFZerosAColocar Do
       VFRetorno := VFRetorno + '0';

   Result := VFRetorno + TrimLeft(TrimRight(VFString));
   End;


   function FAsc(VFString : String) : Integer;
   var
   VFS: String;
   begin
   VFS    := VFString;
   Result := Ord(VFS[1]);
   end;


   function PDireita(VFString : String; VFQuantidade : Integer) : String;
   begin
        Result := Copy(VFString,Length(VFString)-VFQuantidade+1,VFQuantidade);
   end;

Var
   Y,
   VTamanho,
   k        : Word;
   VAsc     : Real;
   VCrypta  : String;
   VNumAsc,
   VAjuda,
   VFLetra  : String;
   VImpar   : Boolean;
Begin
   VTamanho := Length(trim(VFString));
   VCrypta  := '';
   VNumAsc  := '';
   VFString := Trim(VFString);
   For y := 1 To VTamanho Do
       Begin
       VFLetra  := Copy(VFString,y,1);
       VNumAsc  := StrZero(FloatToStr(FAsc(VFLetra)),3);
       VAjuda   := '';
       For k := 3 Downto 1 Do
           VAjuda := VAjuda + copy(VNumAsc,k,1);

       VImpar := False;

       If (y mod 2) = 0 Then
          VAsc   := StrToFloat(VAjuda)
       Else
          Begin
          VAsc   := StrToFloat(Vajuda)+3;
          VImpar := True;
       End;

       If VAsc > 255 Then
          If Vimpar Then
             VCrypta := VCrypta + Chr(252)+Chr(145)+Chr(254)+Chr(StrToInt(Copy(StrZero(FloatToStr(VAsc),3),1,2)))+Chr(StrToInt(PDireita(StrZero(FloatToStr(VAsc),3),2)))
          Else
             VCrypta := VCrypta + Chr(252)+Chr(145)+Chr(247)+Chr(StrToInt(Copy(StrZero(FloatToStr(VAsc),3),1,2)))+Chr(StrToInt(PDireita(StrZero(FloatToStr(VAsc),3),2)))
       Else
          If Vimpar Then
             VCrypta := VCrypta + Chr(254)+ Chr(StrToInt(FloatToStr(VAsc)))
          Else
             VCrypta := VCrypta + Chr(247)+ Chr(StrToInt(FloatToStr(VAsc)));
   End;
   Result := VCrypta;
end;

function FDesCrypta(VFString: String): String;

         Function StrZero(VFString: String; VFTamanho: Integer): String;
         Var
         VFRetorno       : String;
         I,
         VFZerosAColocar : Integer;
         Begin
         VFZerosAColocar := VFTamanho - Length(TrimLeft(TrimRight(VFString)));
         VFRetorno       := '';

         For I := 1 To VFZerosAColocar Do
             VFRetorno := VFRetorno + '0';

         Result := VFRetorno + TrimLeft(TrimRight(VFString));
         End;


         function FAsc(VFString : String) : Integer;
         var
         VFS: String;
         begin
         VFS    := VFString;
         Result := Ord(VFS[1]);
         end;


         function PDireita(VFString : String; VFQuantidade : Integer) : String;
         begin
              Result := Copy(VFString,Length(VFString)-VFQuantidade+1,VFQuantidade);
         end;

Var
   y,
   k         : Word;
   VCrypta,
   VProc,
   VFLetra,
   VAjuda,
   VNumASc   : String;
   VAsc      : Real;
   VPrimNum,
   VContProc,
   VPegouPar,
   VPar,
   VParLetra : Boolean;
Begin
   VCrypta    := '';
   VProc      := '';
   VNumASc    := '';
   VPrimNum   := False;
   VContProc  := False;
   VPegouPar := False;
   VParLetra  := False;
   For y := 1 To Length(VFString) Do
       Begin
       VFLetra  := Copy(VFString,y,1);
       If (FAsc(VFLetra) = 252) And (VProc = '') Then
          Begin
          VProc := Vproc + VFletra;
          Continue;
       End;
       If (FAsc(VFLetra) = 145) And (VFLetra <> '') Then
          Begin
          VProc := VProc + VFletra;
          Continue;
       End;
       If VProc = Chr(252)+Chr(145) Then
          Begin
          VPrimNum  := True;
          VProc     := '';
          If VFLetra = Chr(247) Then
             VPar := True
          Else
             VPar := False;

          VPegoupar := True;
          Continue;
       End;
       If VPrimNum Then
          Begin
          VPrimNum := False;
          VNumAsc  := Trim(FloatToStr(FAsc(VFLetra)));
          Continue;
       End;
       If VPegoupar Then
          Begin
          VPegouPar := False;
          VNumAsc   := VNumAsc + PDireita(Trim(FloatToStr(FAsc(VFLetra))),1);
          VAsc      := StrToFloat(VNumASc);
          If Not Vpar Then
             VAsc  := VAsc - 3;

          VAjuda := '';
          For k := 3 Downto 1 Do
              VAjuda := VAjuda + Copy(FloatToStr(VAsc),k,1);

          VAsc := StrToFloat(VAjuda);
       End
       Else
          Begin
          If Not VParLetra Then
             Begin
             If VFletra = Chr(247) Then
                VPar := True
             Else
                Vpar := False;

             VParLetra := True;
             Continue;
          End
          Else
            VParletra := False;

          VAjuda := FloatToStr(FAsc(VFLetra));

          If VPar Then
             VAsc := StrToFloat(VAjuda)
          Else
             VAsc := StrToFloat(VAjuda) - 3;

          VNumAsc  := StrZero(FloatToStr(VAsc),3);
          VAjuda   := '';
          For k := 3 Downto 1 Do
              VAjuda := VAjuda + Copy(VNumAsc,k,1);

          VAsc := StrToFloat(VAjuda);
       End;
       VCrypta := VCrypta + Chr(StrToInt(FloatToStr(VAsc)));
   End;
   Result := VCrypta;
end;

function Log(valor: String; const arquivo: String): Boolean;
Var
   arq: TextFile;
   NomeArq : String;
   linha : String;
   l : String;
begin
//  Exit;
  If arquivo = EmptyStr Then Begin
    NomeArq := ChangeFileExt(ParamStr(0), '.txt');
  end
  Else Begin
    NomeArq := arquivo;
  end;
  l := LineEnding + 'Inicio (' + DateToStr(Date) + '  ' + TimeToStr(Time) +') --------------------------------' + LineEnding + LineEnding;
  try
    AssignFile(arq,NomeArq);
      If  FileExists(arquivo)
      and FileExists('debug.txt') Then
        Append(arq)
      Else
        Rewrite(arq);
    linha := LineEnding + LineEnding + 'Final --------------------------------' + LineEnding + LineEnding;;
    Writeln(arq, l + valor + linha);
    CloseFile(arq);
  except
    {$IF DEFINED(MSWINDOWS) AND NOT DEFINED(FPC)}
    ShowMessage('Erro: Arquivo ' + arquivo + ' está em uso no momento');
    {$ELSE}
    Writeln('Erro: Arquivo ' + arquivo + ' está em uso no momento');
    {$ENDIF}
   end;
end;

{ TUtilitiesWhatsapp }

class function TUtilitiesWhatsapp.NormalizarNumeroParaBusca(const NumeroLimpo: string): TArray<string>;
var
  ddd, resto, quatroPrimeiros, quatroUltimos: string;
begin
  // Garante que o número limpo tem pelo menos 10 dígitos
  if Length(NumeroLimpo) < 10 then
    Exit(TArray<string>.Create(NumeroLimpo));

  // Extrai DDD e resto do número
  if NumeroLimpo.StartsWith('55') and (Length(NumeroLimpo) >= 12) then
  begin
    ddd := Copy(NumeroLimpo, 3, 2); // Ex.: 61
    resto := Copy(NumeroLimpo, 5, Length(NumeroLimpo) - 4); // Ex.: 99989402
  end
  else
  begin
    ddd := Copy(NumeroLimpo, 1, 2); // Ex.: 61
    resto := Copy(NumeroLimpo, 3, Length(NumeroLimpo) - 2); // Ex.: 99989402
  end;

  // Divide o resto em 4 primeiros e 4 últimos dígitos para (61)9998-9402
  if Length(resto) >= 8 then
  begin
    quatroPrimeiros := Copy(resto, 1, 4); // Ex.: 9998
    quatroUltimos := Copy(resto, 5, 4); // Ex.: 9402
  end
  else
  begin
    quatroPrimeiros := resto; // Usa o resto completo se for menor
    quatroUltimos := '';
  end;

  // Gera formatos comuns, incluindo (61)9998-9402
  if quatroUltimos <> '' then
    Result := TArray<string>.Create(
      NumeroLimpo,                          // 556199989402
      '+' + NumeroLimpo,                   // +556199989402
      ddd + resto,                         // 6199989402
      '(' + ddd + ')' + resto,             // (61)99989402
      '(' + ddd + ')' + quatroPrimeiros + '-' + quatroUltimos, // (61)9998-9402
      '+55' + ddd + resto,                 // +556199989402
      ddd + '-' + resto                    // 61-99989402
    )
  else
    Result := TArray<string>.Create(
      NumeroLimpo,
      '+' + NumeroLimpo,
      ddd + resto,
      '(' + ddd + ')' + resto,
      '+55' + ddd + resto,
      ddd + '-' + resto
    );
end;

class function TUtilitiesWhatsapp.FormatarNumero(const Numero: string): string;
var
  numeroLimpo: string;
begin
  numeroLimpo := LimparNumero(Numero);

  // Adicionar código do país se não tiver
  if not numeroLimpo.StartsWith('55') then
    numeroLimpo := '55' + numeroLimpo;

  Result := numeroLimpo + '@c.us';
end;

class function TUtilitiesWhatsapp.LimparNumero(const Numero: string): string;
var
  i: Integer;
  c: Char;
begin
  Result := '';
  for i := 1 to Length(Numero) do
  begin
    c := Numero[i];
    if CharInSet(c, ['0'..'9']) then
      Result := Result + c;
  end;
end;

class function TUtilitiesWhatsapp.ConverterMesParaNumero(const Mes: string): string;
var
  mesUpper, mesPart, anoPart: string;
  mesInt, anoInt: Integer;
  partes: TArray<string>;
begin
  Result := '';
  mesUpper := UpperCase(Trim(Mes));

  // Exige formato "Mês/Ano" (ex.: "JANEIRO/2025" ou "01/2025")
  if Pos('/', mesUpper) = 0 then
    Exit; // Retorna vazio se não tiver ano

  partes := mesUpper.Split(['/']);
  if Length(partes) <> 2 then
    Exit; // Retorna vazio se não tiver exatamente mês e ano

  mesPart := partes[0];
  anoPart := partes[1];

  // Valida o ano (entre 2000 e ano atual + 1)
  if not (TryStrToInt(anoPart, anoInt) and (anoInt >= 2000) and (anoInt <= StrToInt(FormatDateTime('yyyy', Now)) + 1)) then
    Exit;

  // Converte o mês
  if TryStrToInt(mesPart, mesInt) and (mesInt >= 1) and (mesInt <= 12) then
    Result := Format('%.2d', [mesInt]) + '/' + anoPart
  else if (mesPart = 'JANEIRO') or (mesPart = 'JAN') then Result := '01/' + anoPart
  else if (mesPart = 'FEVEREIRO') or (mesPart = 'FEV') then Result := '02/' + anoPart
  else if (mesPart = 'MARÇO') or (mesPart = 'MAR') then Result := '03/' + anoPart
  else if (mesPart = 'ABRIL') or (mesPart = 'ABR') then Result := '04/' + anoPart
  else if (mesPart = 'MAIO') or (mesPart = 'MAI') then Result := '05/' + anoPart
  else if (mesPart = 'JUNHO') or (mesPart = 'JUN') then Result := '06/' + anoPart
  else if (mesPart = 'JULHO') or (mesPart = 'JUL') then Result := '07/' + anoPart
  else if (mesPart = 'AGOSTO') or (mesPart = 'AGO') then Result := '08/' + anoPart
  else if (mesPart = 'SETEMBRO') or (mesPart = 'SET') then Result := '09/' + anoPart
  else if (mesPart = 'OUTUBRO') or (mesPart = 'OUT') then Result := '10/' + anoPart
  else if (mesPart = 'NOVEMBRO') or (mesPart = 'NOV') then Result := '11/' + anoPart
  else if (mesPart = 'DEZEMBRO') or (mesPart = 'DEZ') then Result := '12/' + anoPart;
end;

class function TUtilitiesWhatsapp.ConverterNumeroParaMes(const Numero: string): string;
begin
  if Numero = '01' then
    Result := 'Janeiro'
  else if Numero = '02' then
    Result := 'Fevereiro'
  else if Numero = '03' then
    Result := 'Março'
  else if Numero = '04' then
    Result := 'Abril'
  else if Numero = '05' then
    Result := 'Maio'
  else if Numero = '06' then
    Result := 'Junho'
  else if Numero = '07' then
    Result := 'Julho'
  else if Numero = '08' then
    Result := 'Agosto'
  else if Numero = '09' then
    Result := 'Setembro'
  else if Numero = '10' then
    Result := 'Outubro'
  else if Numero = '11' then
    Result := 'Novembro'
  else if Numero = '12' then
    Result := 'Dezembro'
  else
    Result := '';
end;

class function TUtilitiesWhatsapp.ValidarNumero(const Numero: string): Boolean;
var
  numeroLimpo: string;
begin
  numeroLimpo := LimparNumero(Numero);
  Result := (Length(numeroLimpo) >= 10) and (Length(numeroLimpo) <= 13);
end;

class function TUtilitiesWhatsapp.ValidarMes(const Mes: string): Boolean;
begin
  Result := ConverterMesParaNumero(Mes) <> '';
end;

//class function TUtilitiesWhatsapp.TipoDocumentoParaString(const Tipo: TTipoDocumento): string;
//begin
//  case Tipo of
//    tdCarteiraTrabalho: Result := 'Carteira de Trabalho';
//    tdContratoTrabalho: Result := 'Contrato de Trabalho';
//    tdHolerite: Result := 'Holerite';
//    tdDeclaracaoFerias: Result := 'Declaração de Férias';
//    else Result := 'Holerite';
//  end;
//end;

class function TUtilitiesWhatsapp.NormalizarTexto(const Texto: string): string;
begin
  Result := UpperCase(Trim(Texto));
end;

class function TUtilitiesWhatsapp.ExtrairComando(const Mensagem: string): string;
begin
  Result := NormalizarTexto(Mensagem);
end;

class function TUtilitiesWhatsapp.FormatarNumeroEnvio(const Numero: string): string;
var
  numeroLimpo: string;
begin
  numeroLimpo := LimparNumero(Numero);

  // Adicionar DDI se não tiver
  if not numeroLimpo.StartsWith('55') then
    numeroLimpo := '55' + numeroLimpo;

  // Se o número após o DDI+DDD tiver 8 dígitos, adiciona o 9
  // Exemplo: 556199758948 (correto), 556199758948 (já tem 9), 556199758948 (precisa adicionar 9)
  if (Length(numeroLimpo) = 12) then // 2 (DDI) + 2 (DDD) + 8 (número)
    System.Insert('9', numeroLimpo, 5);

  Result := numeroLimpo;
end;

{ TTipoVariavel }

function TTipoVariavel.tipo(AValor: String): integer;
begin

  If (AnsiIndexStr(AValor,FstrSplit(Numerico,',',false)) > -1) Then begin
    Result := 0;
    exit;
  End
  Else If (AnsiIndexStr(AValor,FstrSplit(Caracter,',',false)) > -1) Then begin
         Result := 1;
         Exit;
        End
        Else If (AnsiIndexStr(AValor,FstrSplit(Hora,',',false)) > -1) Then begin
               Result := 2;
               Exit;
             End
             Else If (AnsiIndexStr(AValor,FstrSplit(Data,',',false)) > -1) Then begin
                    Result := 3;
                    Exit;
                  End
                  Else If (AnsiIndexStr(AValor,FstrSplit(DataHora,',',false)) > -1) Then begin
                         Result := 4;
                         Exit;
                       End
                       Else If (AnsiIndexStr(AValor,FstrSplit(Booleano,',',false)) > -1) Then begin
                              Result := 5;
                              Exit;
                            End
end;

end.

