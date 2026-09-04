{ =============================================================================
  Loggers.Channel.FileBase - Base partilhada dos canais de ficheiro (.log/JSON)

  TLoggerChannelFileBase: mecânica comum aos 2 canais baseline que escrevem em
  ficheiro (texto puro .log e JSON NDJSON) - resolução do caminho corrente
  (tokens AppName/Date do padrão de nome), rotação por tamanho
  (RotationBySizeMB) e por data (RotationByDate, implícita ao incluir o token
  Date no padrão), append thread-safe, retenção de rodados (MaxFilesToKeep).
  Subclasses só fornecem a formatação da linha (FormatEntry, abstrato) e a
  leitura da própria config (LoadConfig, abstrato - cada canal lê o seu
  próprio grupo de parâmetros).

  Espelha o papel de `Parameters.SourceBase.pas`/`TParametersSourceBase` na F7
  (base partilhada de ficheiro), adaptado à semântica de Loggers (append-only,
  nunca reescreve o ficheiro inteiro).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.10.0
  FileVersion:    1.2.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           22/07/2026

  Changelog (file):
  - 1.2.0 (27/07/2026): F8 Onda 8.9 (hardening pos-auditoria) - F1/F2: SanitizeFileName engole tokens nao resolvidos e troca caracteres proibidos por underscore no NOME do ficheiro (um typo no padrao ja nao gera nome ilegal que desativava o canal em silencio). ModuleVersion do modulo 1.9.0->1.10.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.9.0 - F8 Onda 8.4.5 acrescenta o canal TLoggerChannelWebSocket (8o canal baseline, 3o real sobre ICS, resolve P2); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.9.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.8.0 - F8 Onda 8.4.4 acrescenta o canal TLoggerChannelEmail (7o canal baseline, 2o real sobre ICS); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.8.0.
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.7.0 - F8 Onda 8.4.3 acrescenta o canal TLoggerChannelHttp (6o canal baseline, 1o real sobre ICS); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.7.0.
  - 1.1.0 (23/07/2026): F8 Onda 8.4.2 (canal CSV) - novo `CurrentFilePath: string`
    strict protected (só expõe o `ResolveCurrentPath` privado já existente, sem
    duplicar a lógica de resolução de caminho/rotação). Motivo: `TLoggerChannelCSV`
    precisa de saber, ANTES de formatar a linha, se o ficheiro-alvo desta escrita
    ainda não existe (para decidir se prefixa a linha de cabeçalho CSV) - sem
    este hook, o canal teria de re-derivar o mesmo caminho de forma paralela
    (viola DRY/placement por peça) ou duplicar `FHeadersWritten`+lógica de
    reescrita como o LoggersORM v2.3.0 fazia (bug latente: colunas configuráveis
    em runtime invalidavam silenciosamente as linhas já escritas com outro
    layout). Aditivo, 100% retrocompatível - `TLoggerChannelTextFile`/`TLoggerChannelJson`
    não usam o novo hook, comportamento inalterado (confirmado pelo gate sem
    regressão).
  - (sync 23/07/2026) ModuleVersion sincronizado para 1.5.0 - F8 Onda 8.4.1 acrescenta o canal TLoggerChannelEventLog (Windows Event Log, 4o canal baseline); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.5.0.
  - (sync 22/07/2026) ModuleVersion sincronizado para 1.4.0 - Loggers.Channel.Database.pas removeu a dependencia de IPoolConnections/TPoolBroker (conexao propria, direta), decisao de arquitectura do owner ('o Loggers via consumir sem pool direto o Connections'); sem alteracao funcional neste ficheiro. Ver Loggers.Version.pas 1.4.0.
  - 1.0.0 (22/07/2026): criação — FASE 8 Onda 8.2.
  ============================================================================= }

unit Loggers.Channel.FileBase;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_LOGGERS}

uses
{$IF DEFINED(FPC)}
  SysUtils, Classes, SyncObjs,
{$ELSE}
  System.SysUtils, System.Classes, System.SyncObjs,
{$ENDIF}
  Commons.Loggers.Types,
  Loggers.Interfaces;

type
  { Base ABSTRATA (via NotImplemented em FormatEntry/LoadConfig) dos canais de
    ficheiro. Não regista como ILoggerChannel sozinha — só as subclasses
    concretas (TLoggerChannelTextFile/TLoggerChannelJson). }
  TLoggerChannelFileBase = class(TInterfacedObject, ILoggerChannel)
  strict private
    FLock            : TCriticalSection;
    FName            : string;
    FEnabled         : Boolean;
    FAppName         : string;
    FFolderPath      : string;
    FFileNamePattern : string;
    FFileSuffix      : string;
    FRotationBySizeMB: Integer;
    FRotationByDate  : Boolean;
    FMaxFilesToKeep  : Integer;
    FSizeRotationIdx : Integer;  { índice de rotação por tamanho, dentro do mesmo dia. }
    FLastDateToken   : string;   { deteta troca de dia para reiniciar FSizeRotationIdx. }
    function ResolveBasePath(const ADateToken: string): string;
    function ResolveCurrentPath: string;
    procedure EnforceRetention;
  strict protected
    { Campos partilhados que o LoadConfig de cada subclasse deve preencher. }
    procedure SetSharedConfig(const AEnabled: Boolean; const AAppNameOverride,
      AFolderPath, AFileNamePattern, AFileSuffix: string;
      const ARotationBySizeMB: Integer; const ARotationByDate: Boolean;
      const AMaxFilesToKeep: Integer);
    { Subclasse: monta a linha (sem quebra de linha) para uma entrada. }
    function FormatEntry(const AEntry: TLoggerEntry): string; virtual; abstract;
    { Subclasse: lê o seu próprio grupo de parâmetros e chama SetSharedConfig. }
    procedure LoadConfig; virtual; abstract;
    { Caminho que a PRÓXIMA escrita vai usar (mesmo cálculo de ResolveCurrentPath,
      incl. rotação) - só leitura, sem efeito colateral. Chamado de dentro de
      FormatEntry (já sob FLock, via Write) por subclasses que precisam saber
      se o ficheiro-alvo ainda não existe (ex.: TLoggerChannelCSV decide se
      prefixa a linha de cabeçalho). }
    function CurrentFilePath: string;
  public
    constructor Create(const AName: string);
    destructor Destroy; override;
    function Name: string;
    function Write(const AEntry: TLoggerEntry): Boolean;
    function Enabled: Boolean; overload;
    function Enabled(const AValue: Boolean): ILoggerChannel; overload;
    function IsHealthy: Boolean;
  end;

{$ENDIF USE_LOGGERS}

implementation

{$IFDEF USE_LOGGERS}

function CompareFileTimeAsc(AList: TStringList; AIndex1, AIndex2: Integer): Integer;
begin
  Result := NativeInt(AList.Objects[AIndex1]) - NativeInt(AList.Objects[AIndex2]);
end;

{ Tamanho em bytes de um ficheiro existente, sem depender de System.IOUtils
  (disponibilidade cross-compiler incerta) - abre/fecha um TFileStream. }
function GetFileSizeSafe(const APath: string): Int64;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
  try
    Result := LStream.Size;
  finally
    LStream.Free;
  end;
end;

{ F1/F2 (auditoria F8): o NOME do ficheiro e' derivado de um padrao configuravel
  com tokens [AppName]/[Date] (em colchetes DE PROPOSITO - chavetas literais
  fechariam este comentario, bug-661). Um token desconhecido por typo fica
  literal, ou um caracter proibido vindo do AppName produziria um nome ilegal no
  Windows -> CreateFile falha -> o canal desativa-se em silencio (perde logs).
  Engole qualquer token entre chavetas nao resolvido e troca os caracteres
  proibidos por '_'. Aplica-se SO' ao nome, nunca ao FolderPath. }
function SanitizeFileName(const AName: string): string;
var
  I, LDepth: Integer;
  C: Char;
begin
  Result := '';
  LDepth := 0;
  for I := 1 to Length(AName) do
  begin
    C := AName[I];
    if C = '{' then
      Inc(LDepth)
    else if C = '}' then
    begin
      if LDepth > 0 then
        Dec(LDepth);
    end
    else if LDepth = 0 then
    begin
      if (Ord(C) < 32) or CharInSet(C, ['\', '/', ':', '*', '?', '"', '<', '>', '|']) then
        Result := Result + '_'
      else
        Result := Result + C;
    end;
  end;
  if Result = '' then
    Result := 'log';
end;

constructor TLoggerChannelFileBase.Create(const AName: string);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FName := AName;
  FEnabled := True;
  FSizeRotationIdx := 0;
  FLastDateToken := '';
end;

destructor TLoggerChannelFileBase.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TLoggerChannelFileBase.SetSharedConfig(const AEnabled: Boolean;
  const AAppNameOverride, AFolderPath, AFileNamePattern, AFileSuffix: string;
  const ARotationBySizeMB: Integer; const ARotationByDate: Boolean;
  const AMaxFilesToKeep: Integer);
begin
  FEnabled := AEnabled;
  if AAppNameOverride <> '' then
    FAppName := AAppNameOverride
  else
    FAppName := ExtractFileName(ParamStr(0));
  FFolderPath := AFolderPath;
  FFileNamePattern := AFileNamePattern;
  FFileSuffix := AFileSuffix;
  FRotationBySizeMB := ARotationBySizeMB;
  FRotationByDate := ARotationByDate;
  FMaxFilesToKeep := AMaxFilesToKeep;
end;

function TLoggerChannelFileBase.ResolveBasePath(const ADateToken: string): string;
var
  LFileName: string;
begin
  LFileName := FFileNamePattern;
  LFileName := StringReplace(LFileName, '{AppName}', FAppName, [rfReplaceAll, rfIgnoreCase]);
  LFileName := StringReplace(LFileName, '{Date}', ADateToken, [rfReplaceAll, rfIgnoreCase]);
  LFileName := SanitizeFileName(LFileName);  { F1/F2: tokens nao resolvidos e caracteres invalidos nao geram nome ilegal. }
  Result := IncludeTrailingPathDelimiter(FFolderPath) + LFileName;
end;

function TLoggerChannelFileBase.ResolveCurrentPath: string;
var
  LDateToken, LBasePath, LCandidate: string;
  LExt: string;
begin
  if FRotationByDate then
    LDateToken := FormatDateTime('yyyy-mm-dd', Now)
  else
    LDateToken := '';  { pattern default tem sempre o token Date; se RotationByDate=False o token fica vazio. }

  if LDateToken <> FLastDateToken then
  begin
    FLastDateToken := LDateToken;
    FSizeRotationIdx := 0;  { novo dia -> reinicia a contagem de rotação por tamanho. }
  end;

  LBasePath := ResolveBasePath(LDateToken);

  { Rotação por tamanho: se o ficheiro corrente já atingiu o limite, avança
    para o próximo índice (<base>.<N><suffix>) até encontrar um que ainda
    caiba (ou que não exista ainda). }
  if FRotationBySizeMB > 0 then
  begin
    LExt := ExtractFileExt(LBasePath);
    LBasePath := Copy(LBasePath, 1, Length(LBasePath) - Length(LExt));
    repeat
      if FSizeRotationIdx = 0 then
        LCandidate := LBasePath + LExt
      else
        LCandidate := LBasePath + '.' + IntToStr(FSizeRotationIdx) + LExt;
      if (not FileExists(LCandidate)) then
        Break;
      if (GetFileSizeSafe(LCandidate) < Int64(FRotationBySizeMB) * 1024 * 1024) then
        Break;
      Inc(FSizeRotationIdx);
    until False;
    Result := LCandidate;
  end
  else
    Result := LBasePath;
end;

procedure TLoggerChannelFileBase.EnforceRetention;
var
  LGlobPrefix, LGlobPattern: string;
  LSearch: TSearchRec;
  LFiles: TStringList;
  I: Integer;
begin
  if FMaxFilesToKeep <= 0 then
    Exit;
  LGlobPrefix := StringReplace(FFileNamePattern, '{AppName}', FAppName, [rfReplaceAll, rfIgnoreCase]);
  { '*' no lugar do token Date já cobre os rodados por tamanho (base.N.suffix)
    também - FindFirst trata '*' como "qualquer sequência" incl. pontos
    embutidos, desde que o nome termine exatamente no sufixo fixo do padrão. }
  LGlobPattern := StringReplace(LGlobPrefix, '{Date}', '*', [rfReplaceAll, rfIgnoreCase]);

  LFiles := TStringList.Create;
  try
    if FindFirst(IncludeTrailingPathDelimiter(FFolderPath) + LGlobPattern, faAnyFile, LSearch) = 0 then
    try
      repeat
        if (LSearch.Attr and faDirectory) = 0 then
          LFiles.AddObject(IncludeTrailingPathDelimiter(FFolderPath) + LSearch.Name,
            TObject(NativeInt(LSearch.Time)));
      until FindNext(LSearch) <> 0;
    finally
      FindClose(LSearch);
    end;

    if LFiles.Count <= FMaxFilesToKeep then
      Exit;

    { ordena por Time (FindData) ascendente -> os primeiros são os mais antigos. }
    LFiles.CustomSort(CompareFileTimeAsc);

    for I := 0 to LFiles.Count - FMaxFilesToKeep - 1 do
      DeleteFile(LFiles[I]);
  finally
    LFiles.Free;
  end;
end;

function TLoggerChannelFileBase.CurrentFilePath: string;
begin
  Result := ResolveCurrentPath;
end;

function TLoggerChannelFileBase.Write(const AEntry: TLoggerEntry): Boolean;
var
  LPath, LLine: string;
  LStream: TFileStream;
  LBytes: TBytes;
begin
  Result := False;
  FLock.Acquire;
  try
    try
      if not FEnabled then
        Exit;
      ForceDirectories(FFolderPath);
      LPath := ResolveCurrentPath;
      LLine := FormatEntry(AEntry) + sLineBreak;
      LBytes := TEncoding.UTF8.GetBytes(LLine);
      if FileExists(LPath) then
        LStream := TFileStream.Create(LPath, fmOpenReadWrite or fmShareDenyWrite)
      else
        LStream := TFileStream.Create(LPath, fmCreate or fmShareDenyWrite);
      try
        LStream.Seek(0, soEnd);
        LStream.WriteBuffer(LBytes[0], Length(LBytes));
      finally
        LStream.Free;
      end;
      EnforceRetention;
      Result := True;
    except
      Result := False;  { canal de ficheiro nunca propaga - fail-over do TLoggerImpl decide o resto. }
    end;
  finally
    FLock.Release;
  end;
end;

function TLoggerChannelFileBase.Name: string;
begin
  Result := FName;
end;

function TLoggerChannelFileBase.Enabled: Boolean;
begin
  FLock.Acquire;
  try
    Result := FEnabled;
  finally
    FLock.Release;
  end;
end;

function TLoggerChannelFileBase.Enabled(const AValue: Boolean): ILoggerChannel;
begin
  FLock.Acquire;
  try
    FEnabled := AValue;
  finally
    FLock.Release;
  end;
  Result := Self;
end;

function TLoggerChannelFileBase.IsHealthy: Boolean;
begin
  Result := Enabled and (DirectoryExists(FFolderPath) or ForceDirectories(FFolderPath));
end;

{$ENDIF USE_LOGGERS}

end.
