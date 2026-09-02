unit Commons.StrUtils;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{ =============================================================================
  Providers.Commons.StrUtils - Compatibilidade IfThen para FPC (Commons)

  Unit exclusiva para FPC: replica a API de System.StrUtils.IfThen (Delphi)
  do FPC usando SysUtils/Classes.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  FileVersion:    1.0.0 
  Author:         Claiton de Souza Linhares
  Date:           03/02/2026
  Changelog (file): 
  1.0.0 (03/02/2026): Versão inicial.
  ============================================================================= }

interface
{$IF DEFINED(FPC)}
uses
  SysUtils,
  Classes;

{ IfThen - compatível com System.StrUtils.IfThen (Delphi); uso em FPC quando
  uso em FPC quando Commons.StrUtils estiver no uses
  . }
function IfThen(AValue: Boolean; const ATrue: string; const AFalse: string = ''): string; overload;
function IfThen(AValue: Boolean; ATrue: Integer; AFalse: Integer = 0): Integer; overload;
function IfThen(AValue: Boolean; ATrue: Int64; AFalse: Int64 = 0): Int64; overload;
function IfThen(AValue: Boolean; ATrue: Boolean; AFalse: Boolean = False): Boolean; overload;
{$ENDIF}
implementation
{ SysUtils já em interface; FileExists, ExtractFilePath, etc. estão em SysUtils no FPC }

{ IfThen - espelha System.StrUtils.IfThen (Delphi) }

{$IF DEFINED(FPC)}

function IfThen(AValue: Boolean; const ATrue: string; const AFalse: string): string;
begin
  if AValue then
    Result := ATrue
  else
    Result := AFalse;
end;

function IfThen(AValue: Boolean; ATrue: Integer; AFalse: Integer): Integer;
begin
  if AValue then
    Result := ATrue
  else
    Result := AFalse;
end;

function IfThen(AValue: Boolean; ATrue: Int64; AFalse: Int64): Int64;
begin
  if AValue then
    Result := ATrue
  else
    Result := AFalse;
end;

function IfThen(AValue: Boolean; ATrue: Boolean; AFalse: Boolean): Boolean;
begin
  if AValue then
    Result := ATrue
  else
    Result := AFalse;
end;
{$ENDIF}

end.
