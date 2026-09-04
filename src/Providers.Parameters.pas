{ =============================================================================
  Providers.Parameters - slice da fachada TProviders para o modulo Parameters

  Ponto de entrada unico do modulo para o ecossistema: o consumidor faz
  'uses Providers.Parameters;' e obtem a factory + os contratos + os tipos sem
  ter de conhecer a arvore interna (Parameters / Parameters.Interfaces /
  Parameters.Connections / Commons.Types). Espelha o padrao dos demais modulos
  (ex.: ActiveDirectory.Main -> TActiveDirectory).

  Este slice ANTECIPA a camada Main/: a FASE 10 (fachada unificada) apenas liga
  TProviders.Parameters a TProvidersParameters aqui definido - sem reescrever
  logica. Re-exporta por alias os contratos/tipos publicos (o consumidor nao
  precisa de 'uses Parameters.Interfaces').

  Gated por USE_PARAMETERS. Zero logica propria: delega em TParameters (factory,
  Onda 7.4) e TParametersConnectionLoader (adaptador de perfis / seam, Onda 7.5).

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  2.0.0
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           17/07/2026

  Changelog (file):
  - 1.0.0 (17/07/2026): criacao (FASE 7, Onda 7.6) - slice de fachada
    Providers.Parameters (re-export dos contratos + factory TProvidersParameters
    que delega em TParameters e no adaptador de perfis). A ligacao
    TProviders.Parameters fecha na F10.
  ============================================================================= }

unit Providers.Parameters;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

{$I ORM.Defines.inc}

{$IFDEF USE_PARAMETERS}

uses
  Commons.Types,          // TParameter, TParameterList, TParameterSource, TParameterConfig, TParameterSourceArray
  Connections.Interfaces, // IConnectionConfigureLoader (retorno do registo do adaptador de perfis)
  Parameters.Interfaces,  // IParameters* (contratos re-exportados)
  Parameters,             // TParameters (factory do modulo, Onda 7.4)
  Parameters.Connections; // TParametersConnectionLoader (adaptador de perfis, Onda 7.5)

type
  { --- Re-export dos contratos do modulo (o consumidor nomeia-os via este slice) --- }
  IParameters           = Parameters.Interfaces.IParameters;
  IParametersSource     = Parameters.Interfaces.IParametersSource;
  IParametersDatabase   = Parameters.Interfaces.IParametersDatabase;
  IParametersIniFile    = Parameters.Interfaces.IParametersIniFile;
  IParametersJsonObject = Parameters.Interfaces.IParametersJsonObject;

  { --- Re-export dos tipos publicos (Commons.Types e a fonte unica; aqui so re-exposto) --- }
  TParameter            = Commons.Types.TParameter;
  TParameterList        = Commons.Types.TParameterList;
  TParameterSource      = Commons.Types.TParameterSource;
  TParameterConfig      = Commons.Types.TParameterConfig;
  TParameterSourceArray = Commons.Types.TParameterSourceArray;

  { Slice da fachada TProviders para o modulo Parameters. A F10 liga
    TProviders.Parameters (class function) a estes membros - sem duplicar logica. }
  TProvidersParameters = class
  public
    { Factory (delega em TParameters - Onda 7.4). }
    class function New: IParameters; overload; static;
    class function New(const AConfig: TParameterConfig): IParameters; overload; static;
    class function NewDatabase: IParametersDatabase; static;
    class function NewIniFile: IParametersIniFile; static;
    class function NewJsonObject: IParametersJsonObject; static;

    { Adaptador de perfis -> preenche o seam de configuracao do modulo Connections
      (IConnection.FromConfig; delega em TParametersConnectionLoader - Onda 7.5). }
    class function RegisterConnectionLoader(const AParameters: IParameters): IConnectionConfigureLoader; static;
    class procedure UnregisterConnectionLoader; static;
  end;

{$ENDIF USE_PARAMETERS}

implementation

{$IFDEF USE_PARAMETERS}

{ TProvidersParameters }

class function TProvidersParameters.New: IParameters;
begin
  Result := Parameters.TParameters.New;
end;

class function TProvidersParameters.New(const AConfig: TParameterConfig): IParameters;
begin
  Result := Parameters.TParameters.New(AConfig);
end;

class function TProvidersParameters.NewDatabase: IParametersDatabase;
begin
  Result := Parameters.TParameters.NewDatabase;
end;

class function TProvidersParameters.NewIniFile: IParametersIniFile;
begin
  Result := Parameters.TParameters.NewIniFile;
end;

class function TProvidersParameters.NewJsonObject: IParametersJsonObject;
begin
  Result := Parameters.TParameters.NewJsonObject;
end;

class function TProvidersParameters.RegisterConnectionLoader(
  const AParameters: IParameters): IConnectionConfigureLoader;
begin
  Result := TParametersConnectionLoader.Register(AParameters);
end;

class procedure TProvidersParameters.UnregisterConnectionLoader;
begin
  TParametersConnectionLoader.Unregister;
end;

{$ENDIF USE_PARAMETERS}

end.
