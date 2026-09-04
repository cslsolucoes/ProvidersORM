{ =============================================================================
  Commons.Diagnostics - Rasto de diagnóstico para blocos `except` silenciosos

  Descrição:
  SSOT do "swallow com rasto" (técnica T10 do plano F15). Há sítios no
  ecossistema onde engolir a exceção é a decisão CORRECTA — cleanup best-effort
  em destrutores, guardiões de thread, rollback de transação abandonada — porque
  propagar ali derrubaria a aplicação por causa de um erro secundário. O que NÃO
  é aceitável é engolir **sem deixar rasto**: em produção o defeito fica
  invisível (foi assim que o bug-1108 escapou).

  Porquê OutputDebugString e não o ILogger:
  vários destes sítios vivem DENTRO do próprio dispatch do Loggers
  (`Loggers.pas` :218 e :548) — chamar o logger ali seria reentrância no
  caminho que está justamente a falhar. OutputDebugString é out-of-band, não
  aloca dependências, não reentra e não pode falhar de forma relevante.

  Este idioma já existia inline em `Loggers.pas` (bloco rotulado "C3, auditoria
  F8", :509-517); esta unit promove-o a SSOT em vez de o duplicar pela 4.ª vez
  (regra transversal #14).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.0.0
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           01/09/2026

  Changelog (file):
  - 1.0.0 (01/09/2026): F15 Onda 15.3 — criação. Autorizada pelo owner em 01/09
    ("3 - sim") para dar rasto aos 17 blocos `except` totalmente silenciosos de
    Connections (13), Loggers (2), ActiveDirectory (1) e PoolConnections (1).
  ============================================================================= }
unit Commons.Diagnostics;

{$I ORM.Defines.inc}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
{$IF DEFINED(FPC)}
  SysUtils;
{$ELSE}
  System.SysUtils;
{$ENDIF}

{ Regista que uma exceção foi deliberadamente engolida.
  AOrigem  = unit/rotina onde aconteceu (ex.: 'TConnection.DestroyNativeConnection')
  AMotivo  = porque é best-effort (ex.: 'cleanup de destrutor')
  AE       = a exceção apanhada; pode ser nil quando não há handle para ela. }
procedure TraceSwallowed(const AOrigem, AMotivo: string; AE: Exception); overload;
procedure TraceSwallowed(const AOrigem, AMotivo: string); overload;

implementation

uses
{$IF DEFINED(FPC)}
  Windows;
{$ELSE}
  Winapi.Windows;
{$ENDIF}

const
  TRACE_PREFIX = '[ProvidersORM] swallow: ';

procedure Emitir(const ATexto: string);
begin
  { Nunca pode falhar nem propagar: isto corre em caminhos de erro/teardown. }
  try
{$IFDEF FPC}
    OutputDebugString(PChar(AnsiString(ATexto)));
{$ELSE}
    OutputDebugString(PChar(ATexto));
{$ENDIF}
  except
    { deliberado e final: se nem o rasto se consegue emitir, não há mais nada a
      fazer aqui — e rebentar seria trocar um erro secundário por um pior. }
  end;
end;

procedure TraceSwallowed(const AOrigem, AMotivo: string; AE: Exception);
begin
  if AE <> nil then
    Emitir(Format('%s%s (%s) -> %s: %s',
      [TRACE_PREFIX, AOrigem, AMotivo, AE.ClassName, AE.Message]))
  else
    Emitir(Format('%s%s (%s)', [TRACE_PREFIX, AOrigem, AMotivo]));
end;

procedure TraceSwallowed(const AOrigem, AMotivo: string);
begin
  TraceSwallowed(AOrigem, AMotivo, nil);
end;

end.
