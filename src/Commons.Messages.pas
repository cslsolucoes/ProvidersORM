unit Commons.Messages;
{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

{ =============================================================================
  Providers.Commons.Messages - Abstração de exibição de mensagens (GUI / TUI)

  Descrição:
  Permite que código compartilhado (ex.: Commons.pas) exiba mensagens sem
  depender de Dialogs/Forms. Em projeto GUI o aplicativo atribui OnCommonsMessage
  a um procedimento que chama ShowMessage; em projeto TUI atribui a WriteLn(StdErr, ...).

  Uso em código compartilhado:
    Providers.Commons.Messages.CommonsMessage('Engine: ' + EngineName);

  No startup do projeto GUI (ex.: .lpr):
    Providers.Commons.Messages.OnCommonsMessage := @MyShowMessage;  // MyShowMessage chama ShowMessage

  No startup do projeto TUI:
    Providers.Commons.Messages.OnCommonsMessage := @MyConsoleMessage;  // WriteLn(StdErr, AMsg)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  FileVersion:    1.0.0
  Author:         Claiton de Souza Linhares
  Date:           15/02/2026

  Changelog (file):
  - 1.0.0 (04/07/2026): migrado para o v3 (plano F1 Onda 1.1) - header 3.0.0;
    referencia da fonte v2.3.0 preservada abaixo.
  Changelog (fonte v2.3.0):
  - 1.0.0 (15/02/2026): Criação para Fase 8 (GUI/TUI); callback sem dependência de Dialogs.
  ============================================================================= }

interface

type
  { Procedimento de exibição de mensagem (GUI: ShowMessage; TUI: WriteLn(StdErr, ...)) }
  TCommonsMessageProc = procedure(const AMsg: string);

var
  { Callback atribuído pelo aplicativo no startup. Se nil, CommonsMessage não exibe nada. }
  OnCommonsMessage: TCommonsMessageProc = nil;
  { Alias para compatibilidade: código que usava Parameters.Messages.OnParametersMessage. }
  OnParametersMessage: TCommonsMessageProc = nil;

{ Exibe mensagem através do callback, se atribuído. }
procedure CommonsMessage(const AMsg: string);

{ Alias para compatibilidade com código que usava Parameters.Messages.ParametersMessage. }
procedure ParametersMessage(const AMsg: string);

implementation

procedure CommonsMessage(const AMsg: string);
begin
  if Assigned(OnCommonsMessage) then
    OnCommonsMessage(AMsg);
end;

procedure ParametersMessage(const AMsg: string);
begin
  if Assigned(OnParametersMessage) then
    OnParametersMessage(AMsg)
  else
    CommonsMessage(AMsg);
end;

end.
