{ =============================================================================
  Database.Helpers.Export - Ponte QueryBuilder->JSON (eixo FULL, dado real)

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  3.2.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           30/07/2026

  Onda S4 (ADITIVO) - SSOT unico da logica partilhada por
  ITable/ISchema/IDatabase.Export(AWithData, AQuery: IQueryBuilder): executa
  AQuery (com fallback de Connection) e serializa as LINHAS resultantes
  (TDataSet) via TDataSetSerializeHelper.ToJSONArrayString (unit Serialize,
  Modulos/Database/Serialize - reutilizado, NUNCA SQL/parse novo), compondo o
  objecto FULL final ("structure"+"data").

  Placement (regra do projecto - logica/algoritmo -> Modulos/<Modulo>/*):
  isolado em unit PROPRIA (em vez de embutido em Database.Table/Schema/
  Database.pas, os 3 consumidores) por um motivo CONCRETO descoberto durante
  esta onda: Database.Table.pas (e por heranca/composicao Database.Schema.pas)
  usa Commons.Database.Types.TRowStatus, cujos literais (dsInactive/dsInsert/
  dsEdit/dsDeleted) COLIDEM por NOME com os literais de Data.DB.TDataSetState
  (dsInactive/dsBrowse/dsEdit/dsInsert/...) - adicionar Data.DB directamente
  ao uses dessas units tornou AMBIGUOS os `case FStatus of dsInsert:
  dsEdit: ...` ja existentes (confirmado por compilacao real: E2010
  Incompatible types TRowStatus vs TDataSetState em Database.Table.pas,
  onda S4). Isolando o unico ponto que precisa de Data.DB/Serialize NESTA
  unit propria (que NAO usa TRowStatus), os 3 consumidores voltam a so
  `uses Database.Helpers.Export` (gated USE_DATABASE) sem nunca importar
  Data.DB/DB directamente - zero colisao, zero duplicacao (regra #14 - a
  MESMA funcao serve ITable/ISchema/IDatabase).

  Gated USE_DATABASE so no PONTO DE USO (uses clause dos 3 consumidores,
  mesmo padrao ja usado por Database.QueryBuilder.pas/Database.Synchronize.pas
  - nao se auto-protegem com IFDEF, dependem do caller so as trazer sob
  USE_DATABASE); esta unit em si nao tem guarda propria (IQueryBuilder so
  existe sob esse define, logo esta unit so e compilada quando USE_DATABASE
  estiver ON, transitivamente, tal como as 2 units citadas).

  Changelog (file):
  - 1.0.0 (30/07/2026): versao inicial (Onda S4) - TryExportQueryData unico,
    extraido dos 3 corpos de Export(AWithData, AQuery) de TTable/TSchema/
    TDatabase para resolver a colisao TRowStatus x TDataSetState.
  ============================================================================= }
unit Database.Helpers.Export;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}
interface

{$I ORM.Defines.inc}

uses
  Databases.Interfaces,
  Connections.Interfaces;

{ Executa AQuery (injectando AFallbackConnection quando AQuery ainda nao tem
  Connection propria) e serializa as LINHAS resultantes em JSON, compondo o
  objecto FULL final (AStructureJSON + "data" das linhas). Devolve False (sem
  tocar AFullJSON) quando: AQuery=nil; nem AQuery nem AFallbackConnection tem
  uma IConnection viva (Assigned + IsConnected); ou AQuery.Execute devolve
  nil (ex.: qbCall sem SQL suportado pelo dialecto, ver TQueryBuilder.Execute).
  NUNCA lanca - o caller (TTable/TSchema/TDatabase.Export) cai graciosamente
  em ToFullJSON quando Result=False. }
function TryExportQueryData(const AQuery: IQueryBuilder; const AFallbackConnection: IConnection;
  const AStructureJSON: string; out AFullJSON: string): Boolean;

implementation

uses
{$IF DEFINED(FPC)}
  DB,
{$ELSE}
  Data.DB,
{$ENDIF}
  { Serialize (Modulos/Database/Serialize) - TDataSetSerializeHelper.
    ToJSONArrayString (class helper for TDataSet) - reutilizado, NUNCA SQL/
    parse novo. Sem define proprio (unit sempre presente, ver header de
    Serialize.pas). }
  Serialize;

function TryExportQueryData(const AQuery: IQueryBuilder; const AFallbackConnection: IConnection;
  const AStructureJSON: string; out AFullJSON: string): Boolean;
var
  LConn: IConnection;
  LDataSet: TDataSet;
begin
  Result := False;
  AFullJSON := '';
  if not Assigned(AQuery) then
    Exit;
  LConn := AQuery.Connection;
  if LConn = nil then
    LConn := AFallbackConnection;
  if (not Assigned(LConn)) or (not LConn.IsConnected) then
    Exit;
  if AQuery.Connection = nil then
    AQuery.Connection(LConn);
  LDataSet := AQuery.Execute;
  if not Assigned(LDataSet) then
    Exit;
  AFullJSON := '{"structure":' + AStructureJSON + ',"data":' + LDataSet.ToJSONArrayString + '}';
  Result := True;
end;

end.
