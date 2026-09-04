{ =============================================================================
  Commons.Version - SSOT de versionamento (runtime) do ProvidersORM v3

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           04/07/2026

  Fonte unica dos NUMEROS de versao: ORM.Version.inc (raiz do modulo). Esta
  unit inclui esse ficheiro e expoe as constantes/record TVersion em runtime.
  Para bump de versao, alterar APENAS ORM.Version.inc.

  Uso basico:
    uses
  Commons.Version;
    ShowMessage(PROVIDERORM_VERSION);        // '3.0.0'
    ShowMessage(PROVIDERORM_VERSION_FULL);   // '3.0.0.0'
    if TVersion.Current >= TVersion.FromString('2.3.0') then ...

  Changelog (file):
  - 1.0.0 (04/07/2026): v3 - deriva de ORM.Version.inc (SSOT unica). Espelha a
    API publica da fonte v2.3.0 (PROVIDERORM_VERSION*, TVersion) para paridade.
  Changelog (fonte v2.3.0):
  - 1.0.0 (13/04/2026): SSOT de versionamento centralizado.
  - 1.1.0 (28/06/2026): bump 2.1.6 -> 2.2.0 (Printers).
  - 1.2.0 (02/07/2026): bump 2.2.0 -> 2.3.0 (fachada unificada Providers).
  ============================================================================= }

unit Commons.Version;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

const
{$I ORM.Version.inc}

  { Espelhos da API publica v2.3.0 (derivados do include - SSOT) }
  PROVIDERORM_VERSION      = VERSION_SEMVER;   // 'M.N.P'
  PROVIDERORM_VERSION_FULL = VERSION;          // 'M.N.P.B'
  PROVIDERORM_PRERELEASE   = '';               // '' = release
  PROVIDERORM_NAME         = PRODUCT_NAME;
  PROVIDERORM_COMPANY      = PRODUCT_COMPANY;
  PROVIDERORM_COPYRIGHT    = PRODUCT_COPYRIGHT;

type
  { TVersion - record imutavel de comparacao de versao }
  TVersion = record
  public
    Major : Integer;
    Minor : Integer;
    Patch : Integer;
    Build : Integer;

    class function Current: TVersion; static;
    class function Create(AMajor, AMinor, APatch: Integer;
                          ABuild: Integer = 0): TVersion; static;
    class function FromString(const AVersion: string): TVersion; static;

    function AsString: string;      // 'M.N.P'
    function AsStringFull: string;  // 'M.N.P.B'

    class operator Equal(const A, B: TVersion): Boolean;
    class operator NotEqual(const A, B: TVersion): Boolean;
    class operator GreaterThan(const A, B: TVersion): Boolean;
    class operator GreaterThanOrEqual(const A, B: TVersion): Boolean;
    class operator LessThan(const A, B: TVersion): Boolean;
    class operator LessThanOrEqual(const A, B: TVersion): Boolean;
  end;

implementation

uses
  {$IF DEFINED(FPC)}
  SysUtils;
{$ELSE}
  System.SysUtils;
{$ENDIF}

function IntToVersionStr(AMajor, AMinor, APatch: Integer): string;
begin
  Result := IntToStr(AMajor) + '.' + IntToStr(AMinor) + '.' + IntToStr(APatch);
end;

function IntToVersionStrFull(AMajor, AMinor, APatch, ABuild: Integer): string;
begin
  Result := IntToStr(AMajor) + '.' + IntToStr(AMinor) + '.' +
            IntToStr(APatch)  + '.' + IntToStr(ABuild);
end;

{ Versao integer-packed para comparacao }
function VersionToInt64(const V: TVersion): Int64;
begin
  Result := Int64(V.Major) * 1000000000
          + Int64(V.Minor) * 1000000
          + Int64(V.Patch) * 1000
          + Int64(V.Build);
end;

class function TVersion.Current: TVersion;
begin
  Result.Major := VERSION_MAJOR;
  Result.Minor := VERSION_MINOR;
  Result.Patch := VERSION_PATCH;
  Result.Build := VERSION_BUILD;
end;

class function TVersion.Create(AMajor, AMinor, APatch: Integer;
                                ABuild: Integer): TVersion;
begin
  Result.Major := AMajor;
  Result.Minor := AMinor;
  Result.Patch := APatch;
  Result.Build := ABuild;
end;

class function TVersion.FromString(const AVersion: string): TVersion;
var
  LRest : string;

  function NextToken(var S: string): string;
  var P: Integer;
  begin
    P := Pos('.', S);
    if P > 0 then
    begin
      Result := Copy(S, 1, P - 1);
      S      := Copy(S, P + 1, MaxInt);
    end
    else
    begin
      Result := S;
      S      := '';
    end;
  end;

begin
  Result := TVersion.Create(0, 0, 0, 0);
  LRest  := Trim(AVersion);
  if LRest = '' then Exit;
  Result.Major := StrToIntDef(Trim(NextToken(LRest)), 0);
  if LRest <> '' then Result.Minor := StrToIntDef(Trim(NextToken(LRest)), 0);
  if LRest <> '' then Result.Patch := StrToIntDef(Trim(NextToken(LRest)), 0);
  if LRest <> '' then Result.Build := StrToIntDef(Trim(LRest),            0);
end;

function TVersion.AsString: string;
begin
  Result := IntToVersionStr(Major, Minor, Patch);
end;

function TVersion.AsStringFull: string;
begin
  Result := IntToVersionStrFull(Major, Minor, Patch, Build);
end;

class operator TVersion.Equal(const A, B: TVersion): Boolean;
begin
  Result := VersionToInt64(A) = VersionToInt64(B);
end;

class operator TVersion.NotEqual(const A, B: TVersion): Boolean;
begin
  Result := VersionToInt64(A) <> VersionToInt64(B);
end;

class operator TVersion.GreaterThan(const A, B: TVersion): Boolean;
begin
  Result := VersionToInt64(A) > VersionToInt64(B);
end;

class operator TVersion.GreaterThanOrEqual(const A, B: TVersion): Boolean;
begin
  Result := VersionToInt64(A) >= VersionToInt64(B);
end;

class operator TVersion.LessThan(const A, B: TVersion): Boolean;
begin
  Result := VersionToInt64(A) < VersionToInt64(B);
end;

class operator TVersion.LessThanOrEqual(const A, B: TVersion): Boolean;
begin
  Result := VersionToInt64(A) <= VersionToInt64(B);
end;

end.
