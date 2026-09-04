{ =============================================================================
  Commons.DllBootstrap - Download on-demand do pacote de DLLs cliente de banco

  Descarrega o pacote 'dll.zip' (arvore dll/win32|win64/banco/...) e extrai-o
  para a pasta do executavel, preservando a estrutura de subpastas. Fecha o
  ciclo da Onda 0 (DLLs cliente fora do git). HTTP via Indy TIdHTTP -- API unica
  Delphi + FPC (procedimento de ouro: sem IFDEF de engine HTTP). Unzip pelo
  modulo ZipFile (ZipFile.Facade.TArchive.ExtractZipToFolder, F1-A Onda A.4).

  Ativo apenas sob USE_DLL_AUTODOWNLOAD (opt-in). Sem o define, todos os metodos
  sao no-op que devolvem False -- e a unit compila sem exigir Indy nem OpenSSL.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           05/07/2026

  Changelog (file):
  - 1.0.0 (05/07/2026): v3 (F1-A Onda A.5). Download Indy TIdHTTP + HTTPS
    (IdSSLOpenSSL) com ponte de progresso para TProgressEvent do nucleo; unzip
    delegado ao modulo ZipFile. Stub no-op quando USE_DLL_AUTODOWNLOAD off.
  ============================================================================= }
unit Commons.DllBootstrap;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
  {$H+}
{$ENDIF}

interface

{$I ORM.Defines.inc}

uses
  {$IF DEFINED(FPC)}
  SysUtils,
  Classes,
  {$ELSE}
  System.SysUtils,
  System.Classes,
  {$ENDIF}
  Commons.Types;

type
  { Fachada de bootstrap de DLLs cliente de banco. Metodos de classe (sem estado). }
  TDllBootstrap = class
  public
    { True quando compilado com USE_DLL_AUTODOWNLOAD. }
    class function Enabled: Boolean; static;

    { URL padrao do pacote (Commons.Consts.DEFAULT_DLL_DOWNLOAD_URL). }
    class function DefaultUrl: string; static;

    { Descarrega AUrl para um ficheiro temporario e extrai para ADestDir,
      preservando a estrutura de subpastas. AOnProgress (opcional) reporta o
      progresso do DOWNLOAD (BytesDone/BytesTotal); Cancel := True aborta.
      Devolve True em sucesso. No-op (False) sem USE_DLL_AUTODOWNLOAD. }
    class function DownloadAndExtract(const AUrl, ADestDir: string;
      AOnProgress: TProgressEvent = nil): Boolean; static;

    { Conveniencia: DownloadAndExtract(DefaultUrl, pasta-do-executavel). O pacote
      traz entries com prefixo 'dll/', logo o resultado e exe/dll/plat/banco/. }
    class function EnsureDlls(AOnProgress: TProgressEvent = nil): Boolean; static;
  end;

implementation

uses
  Commons.Consts
  {$IFDEF USE_DLL_AUTODOWNLOAD}
  , IdHTTP
  , IdComponent
  , IdSSLOpenSSL
  , ZipFile.Facade
  {$ENDIF};

{$IFDEF USE_DLL_AUTODOWNLOAD}
type
  { Ponte entre o evento OnWork do Indy e o TProgressEvent generico do nucleo. }
  TIdWorkBridge = class
  public
    Callback: TProgressEvent;
    Total: Int64;
    Cancel: Boolean;
    procedure DoWorkBegin(ASender: TObject; AWorkMode: TWorkMode; AWorkCountMax: Int64);
    procedure DoWork(ASender: TObject; AWorkMode: TWorkMode; AWorkCount: Int64);
  end;

procedure TIdWorkBridge.DoWorkBegin(ASender: TObject; AWorkMode: TWorkMode;
  AWorkCountMax: Int64);
begin
  Total := AWorkCountMax; // Content-Length quando o servidor o envia (0 caso contrario)
end;

procedure TIdWorkBridge.DoWork(ASender: TObject; AWorkMode: TWorkMode;
  AWorkCount: Int64);
begin
  if Assigned(Callback) then
  begin
    Callback(ASender, AWorkCount, Total, Cancel);
    if Cancel and (ASender is TIdHTTP) then
      TIdHTTP(ASender).Disconnect; // aborta o Get em progresso
  end;
end;
{$ENDIF}

class function TDllBootstrap.Enabled: Boolean;
begin
  {$IFDEF USE_DLL_AUTODOWNLOAD}
  Result := True;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

class function TDllBootstrap.DefaultUrl: string;
begin
  Result := DEFAULT_DLL_DOWNLOAD_URL;
end;

class function TDllBootstrap.DownloadAndExtract(const AUrl, ADestDir: string;
  AOnProgress: TProgressEvent): Boolean;
{$IFDEF USE_DLL_AUTODOWNLOAD}
var
  LHttp: TIdHTTP;
  LSSL: TIdSSLIOHandlerSocketOpenSSL;
  LBridge: TIdWorkBridge;
  LTmp: string;
  LFile: TFileStream;
begin
  Result := False;
  if Trim(AUrl) = '' then
    Exit;

  { Ficheiro temporario para o pacote descarregado. }
  LTmp := GetEnvironmentVariable('TEMP');
  if LTmp = '' then
    LTmp := ExtractFilePath(ParamStr(0));
  LTmp := IncludeTrailingPathDelimiter(LTmp) + 'providersorm_dllpack.zip';

  LBridge := TIdWorkBridge.Create;
  LHttp := TIdHTTP.Create(nil);
  LSSL := TIdSSLIOHandlerSocketOpenSSL.Create(LHttp);
  try
    LBridge.Callback := AOnProgress;
    LSSL.SSLOptions.SSLVersions := [sslvTLSv1_2];
    LHttp.IOHandler := LSSL;
    LHttp.HandleRedirects := True;
    LHttp.OnWorkBegin := LBridge.DoWorkBegin;
    LHttp.OnWork := LBridge.DoWork;

    LFile := TFileStream.Create(LTmp, fmCreate);
    try
      try
        LHttp.Get(AUrl, LFile);
      except
        if LBridge.Cancel then
          Exit  // cancelado pelo utilizador via progresso
        else
          raise;
      end;
    finally
      LFile.Free;
    end;

    { Unzip via modulo ZipFile (A.4) -- mesma logica em Delphi e FPC. }
    Result := TArchive.ExtractZipToFolder(LTmp, ADestDir);
  finally
    LHttp.Free;     // liberta tambem o LSSL (owner = LHttp)
    LBridge.Free;
    if FileExists(LTmp) then
      DeleteFile(LTmp);
  end;
end;
{$ELSE}
begin
  { USE_DLL_AUTODOWNLOAD desativado: no-op. }
  Result := False;
end;
{$ENDIF}

class function TDllBootstrap.EnsureDlls(AOnProgress: TProgressEvent): Boolean;
{$IFDEF USE_DLL_AUTODOWNLOAD}
begin
  Result := DownloadAndExtract(DefaultUrl, ExtractFilePath(ParamStr(0)), AOnProgress);
end;
{$ELSE}
begin
  Result := False;
end;
{$ENDIF}

end.
