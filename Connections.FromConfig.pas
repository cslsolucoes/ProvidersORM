{ =============================================================================
  Connections.FromConfig - Seam de DI para TConnection.FromConfig

  Decisão do owner (Onda 4.1): FromConfig deixa de montar um path INI default e
  chamar LoadFromIniFile diretamente (comportamento da fonte v2.3.0) - passa a
  depender de um loader externo registado em runtime, para o módulo Parameters
  (F7, ainda não existe em src/) poder oferecer a fonte configurada (prioridade
  Database/Inifiles/JsonObject, ver Commons.Consts.DEFAULT_PARAMETER_PRIORITY)
  sem que Connections tenha de importar Parameters (zero dependência, D10).

  IConnectionConfigureLoader é implementado externamente (Parameters, F7) e
  registado uma vez via TConnectionConfigureLoaderRegistry.Register - tipicamente
  na inicialização da fachada (Main/Providers.pas, wave da fachada). Sem loader
  registado, TConnection.FromConfig lança EConnectionConfigurationException
  (ver Connections.pas) em vez de falhar em silêncio.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  1.0.22
  FileVersion:    1.1.0
  Author:         Claiton de Souza Linhares
  Date:           06/07/2026

  Changelog (file):
  - 1.1.0 (06/07/2026): IConnectionConfigureLoader movido para Connections.Interfaces
    (centralização das interfaces do módulo, regra do owner). Fica só a classe de
    registo TConnectionConfigureLoaderRegistry; uses Connections.Interfaces.
  - 1.0.0 (06/07/2026): criação (Onda 4.1) - seam de DI para desacoplar
    Connections.FromConfig do módulo Parameters (F7, ainda não absorvido).
  ============================================================================= }
unit Connections.FromConfig;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ../../ORM.Defines.inc}

uses
  Commons.Types,          // TConnectionData
  Connections.Interfaces; // IConnectionConfigureLoader (centralizado)

type
  { Registo global do loader de configuração (singleton simples; o registo
    ocorre uma única vez, na inicialização da fachada/aplicação). }
  TConnectionConfigureLoaderRegistry = class
  public
    class procedure Register(const ALoader: IConnectionConfigureLoader);
    class procedure Unregister;
    class function HasLoader: Boolean;
    class function CurrentLoader: IConnectionConfigureLoader;
  end;

implementation

var
  GConfigureLoader: IConnectionConfigureLoader;

class procedure TConnectionConfigureLoaderRegistry.Register(const ALoader: IConnectionConfigureLoader);
begin
  GConfigureLoader := ALoader;
end;

class procedure TConnectionConfigureLoaderRegistry.Unregister;
begin
  GConfigureLoader := nil;
end;

class function TConnectionConfigureLoaderRegistry.HasLoader: Boolean;
begin
  Result := Assigned(GConfigureLoader);
end;

class function TConnectionConfigureLoaderRegistry.CurrentLoader: IConnectionConfigureLoader;
begin
  Result := GConfigureLoader;
end;

end.
