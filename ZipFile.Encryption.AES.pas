{ ZipFile.Encryption.AES.pas

  WinZip AE-2 AES-256 encryption for ZIP entries.

  Implements the primitives needed by APPNOTE 6.3.4 + WinZip AES spec:
    - SHA-1                  (FIPS 180-4)
    - HMAC-SHA-1             (RFC 2104)
    - PBKDF2-HMAC-SHA-1      (RFC 8018 / PKCS#5)  --- 1000 iterations
    - AES-256 block cipher   (FIPS 197) - pure pascal, table-free
    - AES-256-CTR stream     (counter LE little-endian, starting at 1)
    - WinZip-AE-2 framing    (salt | pwd_verify | data | hmac10)

  Dual-target Delphi (D24..D37) and FPC/Lazarus.

  Implementation notes:
   * AES key schedule and round function are written without using lookup
     tables of T-boxes to keep the code compact and analytically clear.
     Performance is sufficient for ZIP workloads.
   * A future revision can hot-swap the round function for an x64 AES-NI
     asm path (AESENC / AESENCLAST / AESKEYGENASSIST) via CPUID detection;
     the public Encrypt API stays stable.
}
unit ZipFile.Encryption.AES;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Exceptions.Base;

const
  AES_BLOCK_SIZE   = 16;
  AES256_KEY_BYTES = 32;
  AES256_SALT_SIZE = 16;  // WinZip-AE-2: 16 bytes salt for AES-256
  WINZIP_AE_PWD_VERIFY_BYTES = 2;
  WINZIP_AE_HMAC_TRAILER     = 10; // truncated SHA-1 first 10 bytes
  WINZIP_AE_ITERATIONS       = 1000;

  // Extra field header id for WinZip AES (LFH/CDH)
  WINZIP_AES_EXTRA_FIELD_ID  = $9901;
  // Compression method placeholder when AES-encrypted (real method is in extra)
  WINZIP_AES_METHOD          = 99;
  // GP flag bit 0 — encryption indicator
  GP_FLAG_ENCRYPTED          = $0001;

type
  EZipAESError = class(EExceptionBase);
  TAESKey256 = array[0..AES256_KEY_BYTES - 1] of Byte;
  TAESBlock  = array[0..AES_BLOCK_SIZE - 1] of Byte;
  TSHA1Digest = array[0..19] of Byte;

// --- SHA-1 ---
function Sha1Bytes(const Data: array of Byte; Len: Integer): TSHA1Digest;

// --- HMAC-SHA-1 ---
function HmacSha1(const Key: array of Byte; KeyLen: Integer;
                  const Msg: array of Byte; MsgLen: Integer): TSHA1Digest;

// --- PBKDF2-HMAC-SHA-1 ---
// Out: pre-allocated SetLength(Result, OutLen) by caller; we fill in place.
procedure Pbkdf2HmacSha1(const Password: RawByteString;
                         const Salt: array of Byte; SaltLen: Integer;
                         Iterations, OutLen: Integer;
                         var OutBytes: array of Byte);

// --- AES-256 block cipher ---
type
  TAESExpandedKey = record
    RoundKey: array[0..14, 0..15] of Byte; // 15 round keys for AES-256
  end;

procedure AES256ExpandKey(const AKey: TAESKey256; out AExpanded: TAESExpandedKey);
procedure AES256EncryptBlock(const AExpanded: TAESExpandedKey;
                             const AIn: TAESBlock; out AOut: TAESBlock);

// --- AES-256-CTR (in-place) ---
// Counter is little-endian, starting at 1, packed into bytes 0..3 of the IV.
// Bytes 4..15 of the IV are zero. Each 16-byte block increments the counter.
procedure AES256CtrXor(const AExpanded: TAESExpandedKey;
                       var AData: array of Byte; ADataLen: Integer;
                       AStartCounter: Cardinal);

// --- WinZip-AE-2 framing (high-level helpers) ---
// Derives encryption key, authentication key, and pwd-verification bytes from
// (password, salt) per AE-2 spec for AES-256.
procedure DeriveAEKeys(const Password: RawByteString;
                       const Salt: array of Byte;
                       out EncKey: TAESKey256;
                       out AuthKey: TAESKey256;
                       out PwdVerify: array of Byte);

// Compute HMAC-SHA-1 of ciphertext and return the first 10 bytes (truncated).
function HmacAuthTag(const AuthKey: TAESKey256;
                     const Cipher: array of Byte; Len: Integer): TBytes;

implementation

// =============================================================================
//   SHA-1 (FIPS 180-4)
// =============================================================================

type
  TSha1Ctx = record
    H: array[0..4] of Cardinal;
    Block: array[0..63] of Byte;
    BlockLen: Integer;
    TotalLen: UInt64;
  end;

procedure Sha1Init(out C: TSha1Ctx);
begin
  C.H[0] := $67452301;
  C.H[1] := $EFCDAB89;
  C.H[2] := $98BADCFE;
  C.H[3] := $10325476;
  C.H[4] := $C3D2E1F0;
  C.BlockLen := 0;
  C.TotalLen := 0;
end;

function RotL32(X: Cardinal; N: Byte): Cardinal; inline;
begin
  Result := (X shl N) or (X shr (32 - N));
end;

procedure Sha1Compress(var C: TSha1Ctx);
var
  W: array[0..79] of Cardinal;
  A, B, D, E, F, K, T, G: Cardinal;
  I: Integer;
begin
  for I := 0 to 15 do
    W[I] := (Cardinal(C.Block[I*4]) shl 24) or
            (Cardinal(C.Block[I*4+1]) shl 16) or
            (Cardinal(C.Block[I*4+2]) shl 8) or
            Cardinal(C.Block[I*4+3]);
  for I := 16 to 79 do
    W[I] := RotL32(W[I-3] xor W[I-8] xor W[I-14] xor W[I-16], 1);
  A := C.H[0]; B := C.H[1]; G := C.H[2]; D := C.H[3]; E := C.H[4];
  for I := 0 to 79 do
  begin
    case I of
       0..19: begin F := (B and G) or ((not B) and D); K := $5A827999; end;
      20..39: begin F := B xor G xor D;               K := $6ED9EBA1; end;
      40..59: begin F := (B and G) or (B and D) or (G and D); K := $8F1BBCDC; end;
      else    begin F := B xor G xor D;               K := $CA62C1D6; end;
    end;
    T := RotL32(A, 5) + F + E + K + W[I];
    E := D; D := G; G := RotL32(B, 30); B := A; A := T;
  end;
  C.H[0] := C.H[0] + A;
  C.H[1] := C.H[1] + B;
  C.H[2] := C.H[2] + G;
  C.H[3] := C.H[3] + D;
  C.H[4] := C.H[4] + E;
end;

procedure Sha1Update(var C: TSha1Ctx; const Data: array of Byte; Len: Integer);
var
  I: Integer;
begin
  for I := 0 to Len - 1 do
  begin
    C.Block[C.BlockLen] := Data[I];
    Inc(C.BlockLen);
    if C.BlockLen = 64 then
    begin
      Sha1Compress(C);
      C.BlockLen := 0;
    end;
  end;
  Inc(C.TotalLen, UInt64(Len));
end;

procedure Sha1Final(var C: TSha1Ctx; out Digest: TSHA1Digest);
var
  BitLen: UInt64;
  I: Integer;
begin
  BitLen := C.TotalLen * 8;
  C.Block[C.BlockLen] := $80;
  Inc(C.BlockLen);
  if C.BlockLen > 56 then
  begin
    while C.BlockLen < 64 do
    begin
      C.Block[C.BlockLen] := 0;
      Inc(C.BlockLen);
    end;
    Sha1Compress(C);
    C.BlockLen := 0;
  end;
  while C.BlockLen < 56 do
  begin
    C.Block[C.BlockLen] := 0;
    Inc(C.BlockLen);
  end;
  for I := 7 downto 0 do
  begin
    C.Block[C.BlockLen] := Byte(BitLen shr (I * 8));
    Inc(C.BlockLen);
  end;
  Sha1Compress(C);
  for I := 0 to 4 do
  begin
    Digest[I*4]   := Byte(C.H[I] shr 24);
    Digest[I*4+1] := Byte(C.H[I] shr 16);
    Digest[I*4+2] := Byte(C.H[I] shr 8);
    Digest[I*4+3] := Byte(C.H[I]);
  end;
end;

function Sha1Bytes(const Data: array of Byte; Len: Integer): TSHA1Digest;
var
  C: TSha1Ctx;
begin
  Sha1Init(C);
  Sha1Update(C, Data, Len);
  Sha1Final(C, Result);
end;

// =============================================================================
//   HMAC-SHA-1 (RFC 2104)
// =============================================================================

function HmacSha1(const Key: array of Byte; KeyLen: Integer;
                  const Msg: array of Byte; MsgLen: Integer): TSHA1Digest;
const
  IPAD = $36;
  OPAD = $5C;
  BLK = 64;
var
  KBuf: array[0..63] of Byte;
  K2: TSHA1Digest;
  IKey, OKey: array[0..63] of Byte;
  Inner: TSHA1Digest;
  CtxI, CtxO: TSha1Ctx;
  I: Integer;
begin
  FillChar(KBuf, BLK, 0);
  if KeyLen > BLK then
  begin
    K2 := Sha1Bytes(Key, KeyLen);
    Move(K2[0], KBuf[0], 20);
  end
  else if KeyLen > 0 then
    Move(Key[0], KBuf[0], KeyLen);

  for I := 0 to BLK - 1 do
  begin
    IKey[I] := KBuf[I] xor IPAD;
    OKey[I] := KBuf[I] xor OPAD;
  end;

  Sha1Init(CtxI);
  Sha1Update(CtxI, IKey, BLK);
  Sha1Update(CtxI, Msg, MsgLen);
  Sha1Final(CtxI, Inner);

  Sha1Init(CtxO);
  Sha1Update(CtxO, OKey, BLK);
  Sha1Update(CtxO, Inner, 20);
  Sha1Final(CtxO, Result);
end;

// =============================================================================
//   PBKDF2-HMAC-SHA-1 (RFC 8018)
// =============================================================================

procedure Pbkdf2HmacSha1(const Password: RawByteString;
                         const Salt: array of Byte; SaltLen: Integer;
                         Iterations, OutLen: Integer;
                         var OutBytes: array of Byte);
var
  PwdBytes: TBytes;
  Block: TBytes;
  U, T: TSHA1Digest;
  I, J, K, BlockIdx, Copy: Integer;
  Blocks: Integer;
begin
  SetLength(PwdBytes, Length(Password));
  if Length(Password) > 0 then
    Move(Pointer(Password)^, PwdBytes[0], Length(Password));

  Blocks := (OutLen + 19) div 20;
  SetLength(Block, SaltLen + 4);
  if SaltLen > 0 then
    Move(Salt[0], Block[0], SaltLen);

  for BlockIdx := 1 to Blocks do
  begin
    Block[SaltLen]     := Byte(BlockIdx shr 24);
    Block[SaltLen + 1] := Byte(BlockIdx shr 16);
    Block[SaltLen + 2] := Byte(BlockIdx shr 8);
    Block[SaltLen + 3] := Byte(BlockIdx);
    U := HmacSha1(PwdBytes, Length(PwdBytes), Block, SaltLen + 4);
    T := U;
    for I := 2 to Iterations do
    begin
      U := HmacSha1(PwdBytes, Length(PwdBytes), U, 20);
      for J := 0 to 19 do
        T[J] := T[J] xor U[J];
    end;
    if BlockIdx = Blocks then
      Copy := OutLen - (Blocks - 1) * 20
    else
      Copy := 20;
    for K := 0 to Copy - 1 do
      OutBytes[(BlockIdx - 1) * 20 + K] := T[K];
  end;
end;

// =============================================================================
//   AES-256 (FIPS 197) — pure-pascal, no T-tables
// =============================================================================

const
  SBOX: array[0..255] of Byte = (
    $63,$7C,$77,$7B,$F2,$6B,$6F,$C5,$30,$01,$67,$2B,$FE,$D7,$AB,$76,
    $CA,$82,$C9,$7D,$FA,$59,$47,$F0,$AD,$D4,$A2,$AF,$9C,$A4,$72,$C0,
    $B7,$FD,$93,$26,$36,$3F,$F7,$CC,$34,$A5,$E5,$F1,$71,$D8,$31,$15,
    $04,$C7,$23,$C3,$18,$96,$05,$9A,$07,$12,$80,$E2,$EB,$27,$B2,$75,
    $09,$83,$2C,$1A,$1B,$6E,$5A,$A0,$52,$3B,$D6,$B3,$29,$E3,$2F,$84,
    $53,$D1,$00,$ED,$20,$FC,$B1,$5B,$6A,$CB,$BE,$39,$4A,$4C,$58,$CF,
    $D0,$EF,$AA,$FB,$43,$4D,$33,$85,$45,$F9,$02,$7F,$50,$3C,$9F,$A8,
    $51,$A3,$40,$8F,$92,$9D,$38,$F5,$BC,$B6,$DA,$21,$10,$FF,$F3,$D2,
    $CD,$0C,$13,$EC,$5F,$97,$44,$17,$C4,$A7,$7E,$3D,$64,$5D,$19,$73,
    $60,$81,$4F,$DC,$22,$2A,$90,$88,$46,$EE,$B8,$14,$DE,$5E,$0B,$DB,
    $E0,$32,$3A,$0A,$49,$06,$24,$5C,$C2,$D3,$AC,$62,$91,$95,$E4,$79,
    $E7,$C8,$37,$6D,$8D,$D5,$4E,$A9,$6C,$56,$F4,$EA,$65,$7A,$AE,$08,
    $BA,$78,$25,$2E,$1C,$A6,$B4,$C6,$E8,$DD,$74,$1F,$4B,$BD,$8B,$8A,
    $70,$3E,$B5,$66,$48,$03,$F6,$0E,$61,$35,$57,$B9,$86,$C1,$1D,$9E,
    $E1,$F8,$98,$11,$69,$D9,$8E,$94,$9B,$1E,$87,$E9,$CE,$55,$28,$DF,
    $8C,$A1,$89,$0D,$BF,$E6,$42,$68,$41,$99,$2D,$0F,$B0,$54,$BB,$16
  );

  RCON: array[1..10] of Byte = ($01,$02,$04,$08,$10,$20,$40,$80,$1B,$36);

function XTime(B: Byte): Byte; inline;
begin
  if (B and $80) <> 0 then
    Result := Byte((B shl 1) xor $1B)
  else
    Result := Byte(B shl 1);
end;

procedure AES256ExpandKey(const AKey: TAESKey256; out AExpanded: TAESExpandedKey);
var
  Round, I: Integer;
  Temp: array[0..3] of Byte;
  // 60 words = 240 bytes; we lay them out across RoundKey[0..14][0..15]
  Words: array[0..59, 0..3] of Byte;
  Tmp: Byte;
begin
  // First 8 words come straight from the key
  for I := 0 to 7 do
  begin
    Words[I, 0] := AKey[I*4];
    Words[I, 1] := AKey[I*4+1];
    Words[I, 2] := AKey[I*4+2];
    Words[I, 3] := AKey[I*4+3];
  end;

  for I := 8 to 59 do
  begin
    Temp[0] := Words[I-1, 0];
    Temp[1] := Words[I-1, 1];
    Temp[2] := Words[I-1, 2];
    Temp[3] := Words[I-1, 3];
    if (I mod 8) = 0 then
    begin
      // RotWord
      Tmp     := Temp[0];
      Temp[0] := Temp[1];
      Temp[1] := Temp[2];
      Temp[2] := Temp[3];
      Temp[3] := Tmp;
      // SubWord
      Temp[0] := SBOX[Temp[0]];
      Temp[1] := SBOX[Temp[1]];
      Temp[2] := SBOX[Temp[2]];
      Temp[3] := SBOX[Temp[3]];
      // Rcon
      Temp[0] := Temp[0] xor RCON[I div 8];
    end
    else if (I mod 8) = 4 then
    begin
      // Extra SubWord for AES-256
      Temp[0] := SBOX[Temp[0]];
      Temp[1] := SBOX[Temp[1]];
      Temp[2] := SBOX[Temp[2]];
      Temp[3] := SBOX[Temp[3]];
    end;
    Words[I, 0] := Words[I-8, 0] xor Temp[0];
    Words[I, 1] := Words[I-8, 1] xor Temp[1];
    Words[I, 2] := Words[I-8, 2] xor Temp[2];
    Words[I, 3] := Words[I-8, 3] xor Temp[3];
  end;

  // Layout into RoundKey[round][col*4+row]
  for Round := 0 to 14 do
    for I := 0 to 3 do
    begin
      AExpanded.RoundKey[Round, I*4]     := Words[Round*4 + I, 0];
      AExpanded.RoundKey[Round, I*4 + 1] := Words[Round*4 + I, 1];
      AExpanded.RoundKey[Round, I*4 + 2] := Words[Round*4 + I, 2];
      AExpanded.RoundKey[Round, I*4 + 3] := Words[Round*4 + I, 3];
    end;
end;

// CPUID-based AES-NI capability test (cached). Only meaningful on x64 Delphi
// builds — FPC and Win32 always use the pure-pascal path.
{$IF NOT DEFINED(FPC) AND DEFINED(CPUX64)}
{$DEFINE ZIPFILE_AESNI_CANDIDATE}
{$IFEND}

{$IFDEF ZIPFILE_AESNI_CANDIDATE}
var
  GAESNICached: Integer = -1;  // -1 = not probed, 0 = not available, 1 = available

// Dedicated asm-only function (Win64 ABI does not allow inline asm in
// regular Pascal bodies — only fully-asm procedures).
// Returns CPUID(1).ECX as a Cardinal so the AESNI flag (bit 25) can be tested.
function CpuId1Ecx: Cardinal;
asm
  .NOFRAME
  push    rbx
  mov     eax, 1
  cpuid
  mov     eax, ecx
  pop     rbx
end;

function HasAESNI: Boolean;
begin
  if GAESNICached < 0 then
  begin
    if (CpuId1Ecx and (Cardinal(1) shl 25)) <> 0 then
      GAESNICached := 1
    else
      GAESNICached := 0;
  end;
  Result := GAESNICached = 1;
end;

procedure AES256EncryptBlock_NI(const AExpanded: TAESExpandedKey;
                                const AIn: TAESBlock; out AOut: TAESBlock);
// x64 calling convention (Win64 ABI):
//   RCX = const AExpanded   (pointer to TAESExpandedKey, layout = 15*16 bytes)
//   RDX = const AIn         (pointer to 16-byte block)
//   R8  = out AOut          (pointer to 16-byte block)
// Uses XMM0 = state, XMM1..XMM15 not preserved here (caller-saved in Win64).
asm
  .NOFRAME
  movdqu  xmm0,  [rdx]                // load plaintext block
  movdqu  xmm1,  [rcx + 0*16]         // RoundKey 0
  pxor    xmm0,  xmm1                 // AddRoundKey(0)
  movdqu  xmm1,  [rcx + 1*16];  aesenc      xmm0, xmm1
  movdqu  xmm1,  [rcx + 2*16];  aesenc      xmm0, xmm1
  movdqu  xmm1,  [rcx + 3*16];  aesenc      xmm0, xmm1
  movdqu  xmm1,  [rcx + 4*16];  aesenc      xmm0, xmm1
  movdqu  xmm1,  [rcx + 5*16];  aesenc      xmm0, xmm1
  movdqu  xmm1,  [rcx + 6*16];  aesenc      xmm0, xmm1
  movdqu  xmm1,  [rcx + 7*16];  aesenc      xmm0, xmm1
  movdqu  xmm1,  [rcx + 8*16];  aesenc      xmm0, xmm1
  movdqu  xmm1,  [rcx + 9*16];  aesenc      xmm0, xmm1
  movdqu  xmm1,  [rcx + 10*16]; aesenc      xmm0, xmm1
  movdqu  xmm1,  [rcx + 11*16]; aesenc      xmm0, xmm1
  movdqu  xmm1,  [rcx + 12*16]; aesenc      xmm0, xmm1
  movdqu  xmm1,  [rcx + 13*16]; aesenc      xmm0, xmm1
  movdqu  xmm1,  [rcx + 14*16]; aesenclast  xmm0, xmm1
  movdqu  [r8],  xmm0                 // store ciphertext
end;
{$ENDIF}

procedure AES256EncryptBlock(const AExpanded: TAESExpandedKey;
                             const AIn: TAESBlock; out AOut: TAESBlock);
var
  State: TAESBlock;
  Round, I: Integer;
  S0, S1, S2, S3: Byte;
  T0, T1, T2, T3: Byte;
begin
  {$IFDEF ZIPFILE_AESNI_CANDIDATE}
  if HasAESNI then
  begin
    AES256EncryptBlock_NI(AExpanded, AIn, AOut);
    Exit;
  end;
  {$ENDIF}
  // AddRoundKey (round 0)
  for I := 0 to 15 do
    State[I] := AIn[I] xor AExpanded.RoundKey[0, I];

  // 13 main rounds + final round
  for Round := 1 to 14 do
  begin
    // SubBytes
    for I := 0 to 15 do
      State[I] := SBOX[State[I]];
    // ShiftRows — operate on columns (col-major layout: State[col*4+row])
    // row 0: no shift
    // row 1: shift left 1
    T0 := State[1];
    State[1]  := State[5];
    State[5]  := State[9];
    State[9]  := State[13];
    State[13] := T0;
    // row 2: shift left 2
    T0 := State[2];  T1 := State[6];
    State[2]  := State[10]; State[6]  := State[14];
    State[10] := T0;        State[14] := T1;
    // row 3: shift left 3
    T0 := State[15];
    State[15] := State[11];
    State[11] := State[7];
    State[7]  := State[3];
    State[3]  := T0;

    if Round <> 14 then
    begin
      // MixColumns
      for I := 0 to 3 do
      begin
        S0 := State[I*4];
        S1 := State[I*4 + 1];
        S2 := State[I*4 + 2];
        S3 := State[I*4 + 3];
        T0 := XTime(S0) xor (XTime(S1) xor S1) xor S2 xor S3;
        T1 := S0 xor XTime(S1) xor (XTime(S2) xor S2) xor S3;
        T2 := S0 xor S1 xor XTime(S2) xor (XTime(S3) xor S3);
        T3 := (XTime(S0) xor S0) xor S1 xor S2 xor XTime(S3);
        State[I*4]     := T0;
        State[I*4 + 1] := T1;
        State[I*4 + 2] := T2;
        State[I*4 + 3] := T3;
      end;
    end;

    // AddRoundKey
    for I := 0 to 15 do
      State[I] := State[I] xor AExpanded.RoundKey[Round, I];
  end;

  Move(State[0], AOut[0], 16);
end;

// =============================================================================
//   AES-256-CTR (in-place XOR)
// =============================================================================

procedure AES256CtrXor(const AExpanded: TAESExpandedKey;
                       var AData: array of Byte; ADataLen: Integer;
                       AStartCounter: Cardinal);
var
  IV, KS: TAESBlock;
  Counter: Cardinal;
  Pos, I, ChunkLen: Integer;
begin
  Pos := 0;
  Counter := AStartCounter;
  while Pos < ADataLen do
  begin
    FillChar(IV, SizeOf(IV), 0);
    IV[0] := Byte(Counter);
    IV[1] := Byte(Counter shr 8);
    IV[2] := Byte(Counter shr 16);
    IV[3] := Byte(Counter shr 24);
    AES256EncryptBlock(AExpanded, IV, KS);
    if ADataLen - Pos >= 16 then
      ChunkLen := 16
    else
      ChunkLen := ADataLen - Pos;
    for I := 0 to ChunkLen - 1 do
      AData[Pos + I] := AData[Pos + I] xor KS[I];
    Inc(Pos, ChunkLen);
    Inc(Counter);
  end;
end;

// =============================================================================
//   WinZip AE-2 framing helpers
// =============================================================================

procedure DeriveAEKeys(const Password: RawByteString;
                       const Salt: array of Byte;
                       out EncKey: TAESKey256;
                       out AuthKey: TAESKey256;
                       out PwdVerify: array of Byte);
const
  TOTAL = AES256_KEY_BYTES + AES256_KEY_BYTES + WINZIP_AE_PWD_VERIFY_BYTES; // 66
var
  OutBuf: array[0..TOTAL - 1] of Byte;
  I: Integer;
begin
  Pbkdf2HmacSha1(Password, Salt, Length(Salt), WINZIP_AE_ITERATIONS, TOTAL, OutBuf);
  for I := 0 to AES256_KEY_BYTES - 1 do
    EncKey[I] := OutBuf[I];
  for I := 0 to AES256_KEY_BYTES - 1 do
    AuthKey[I] := OutBuf[AES256_KEY_BYTES + I];
  for I := 0 to WINZIP_AE_PWD_VERIFY_BYTES - 1 do
    PwdVerify[I] := OutBuf[2 * AES256_KEY_BYTES + I];
end;

function HmacAuthTag(const AuthKey: TAESKey256;
                     const Cipher: array of Byte; Len: Integer): TBytes;
var
  D: TSHA1Digest;
  I: Integer;
begin
  D := HmacSha1(AuthKey, AES256_KEY_BYTES, Cipher, Len);
  SetLength(Result, WINZIP_AE_HMAC_TRAILER);
  for I := 0 to WINZIP_AE_HMAC_TRAILER - 1 do
    Result[I] := D[I];
end;

end.
