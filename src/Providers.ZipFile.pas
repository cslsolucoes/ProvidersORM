{ =============================================================================
  Providers.ZipFile - slice da fachada TProviders para o modulo ZipFile
  (10 formatos de arquivo)

  Ponto de entrada unico do modulo para o ecossistema: o consumidor faz
  'uses Providers.ZipFile;' e obtem a factory fluente do formato ZIP + a
  fachada umbrella multi-formato sem ter de conhecer a arvore interna
  (ZipFile / ZipFile.Interfaces / ZipFile.Facade / Commons.ZipFile.Types).
  Espelha o padrao dos demais modulos (ex.: Providers.Parameters ->
  TProvidersParameters).

  Este slice ANTECIPA a camada Main/: a FASE 10 (fachada unificada, Onda
  10.1-a2 - decisao do owner 03/08, "ActiveDirectory/ZipFile nao estao
  congelados", ver plano F10 v2.5.0) apenas liga TProviders.NewZip a
  TProvidersZipFile aqui definido - sem reescrever logica.

  SEM gate USE_* proprio - confirmado por leitura directa + grep no modulo
  inteiro (src/Modulos/ZipFile/*.pas): ZERO ocorrencias da diretiva IFDEF
  USE_ZIPFILE em qualquer unit do modulo. USE_ZIPFILE (definido em
  ORM.Defines.inc) so controla, em cascata, os USE_ARCHIVE_<FMT> por formato
  (linhas 375-379 de ORM.Defines.inc: quando USE_ZIPFILE nao esta definido,
  UNDEF em todos os USE_ARCHIVE_<FMT>) - e esses sim gateiam blocos internos
  de ZipFile.Facade.pas (Create<Fmt>/Extract<Fmt>ToFolder) e a arvore
  condicional do .dpr/.lpr (ex.: bloco IFDEF USE_ARCHIVE_TAR em torno de
  TarFile). O nucleo do modulo (unit ZipFile, classe Zip; unit ZipFile.Facade,
  classe TArchive - deteccao + formato ZIP base + extracao) NAO tem gate
  proprio, exactamente como Connections (modulo CORE) - por isso
  ZipFile.Compression.*/ZipFile/ZipFile.Facade ja estao wired
  INCONDICIONALMENTE em ProvidersV3.dpr/.lpr (bloco de topo, antes de
  qualquer diretiva IFDEF). Este slice acompanha o mesmo regime: sempre
  presente, sem diretivas IFDEF/ENDIF a envolver o conteudo (ao contrario dos
  moldes Providers.Parameters/.PoolConnections/.Database, gated pelo
  respectivo USE_*) - por nao ter nenhum USE_* proprio a resolver, tambem
  nao inclui o include ORM.Defines.inc.

  DESVIO DELIBERADO da convencao "devolve interfaces, nunca classes
  concretas" (achado real, documentado - nao decidido arbitrariamente):

  1) IArchive/IArchiveEntry/IArchiveBuilder (declarados em
     ZipFile.Interfaces.pas) NAO sao re-exportados por esta slice. Confirmado
     por grep em TODO o modulo (src/Modulos/ZipFile/*.pas): zero classes
     implementam estas 3 interfaces (nenhum '..., IArchive)'/
     '..., IArchiveBuilder)' em lado nenhum) - sao contratos DECLARADOS mas
     NUNCA instanciaveis por nenhuma factory do modulo hoje. Re-exporta-los
     criaria uma expectativa de uso (o consumidor declara a variavel mas
     nenhum 'New'/'Build' real do modulo a preenche) que o modulo nao cumpre
     - contraria a regra "nao inventar contrato que o modulo nao tem".

  2) O contrato REAL, implementado e obtido por factory e IZipFileBuilder
     (classe TZipFileBuilder, ZipFile.pas), devolvido por Zip.NewArchive/
     Zip.OpenArchive (classe Zip, tambem ZipFile.pas) - o formato ZIP e a
     base do modulo, sempre presente (paralelo ao "Connections e core"). Esta
     slice expoe esse par como TProvidersZipFile.NewArchive/OpenArchive.

  3) ARMADILHA REAL ENCONTRADA por leitura atenta de ZipFile.Interfaces.pas:
     o ficheiro declara DOIS tipos "TCompressionMethod" DISTINTOS sob o mesmo
     identificador (reaproveitado, nao e erro de compilacao porque o 2o
     SOMBREIA o 1o a partir do ponto onde e declarado): (a) o 1o, usado por
     IArchiveBuilder.WithMethod (interface nao implementada - ver ponto 1),
     resolve para ZipFile.Compression.TCompressionMethod (importado no 'uses'
     do proprio ZipFile.Interfaces.pas); (b) o 2o, declarado localmente como
     '(cmNone, cmMaximal)' MAIS ABAIXO no mesmo ficheiro, sombreia o 1o dai
     em diante e e o que IZipFileBuilder.WithCompression REALMENTE usa. Esta
     slice re-exporta o 2o (o que corresponde ao unico contrato implementado,
     IZipFileBuilder) sob o nome simples TCompressionMethod - NAO o
     TCompressionMethod mais rico de ZipFile.Compression (esse so e
     alcancavel via propriedades de TZipFile directamente, 'uses
     ZipFile.Compression;' no consumidor, fora do ambito desta slice).

  4) TArchive (ZipFile.Facade, "Fachada publica unica do modulo ZipFile (10
     formatos)" - citacao literal do cabecalho de ZipFile.Facade.pas) e
     re-exportada por ALIAS DE TIPO (zero logica propria, tal como
     'TParameter = Commons.Types.TParameter;' no molde Providers.Parameters)
     - nao por wrapper 1:1 method-a-method: TArchive tem ~9 factories Create*
     (devolvem classes concretas TZipFile/TTarFile/TGzipFile/.../TRarFile,
     cada uma gated pelo seu USE_ARCHIVE_<FMT>) + ~9 extratores
     Extract*ToFolder + deteccao (DetectFormat/FormatToString). Envolver cada
     um num wrapper interface-only obrigaria a reimplementar/inventar
     contratos que o modulo nao tem (o modulo opta deliberadamente por
     devolver os proprios componentes TXxxFile, nao interfaces, para os 9
     formatos alem do ZIP base) - contraria "zero logica propria" (um
     wrapper teria de re-declarar 18+ assinaturas so para delegar). O
     consumidor usa 'Providers.ZipFile.TArchive.ExtractZipToFolder(...)' /
     '.CreateTar(...)' etc. directamente - identico a usar TArchive.

  Project:        ProvidersORM
  ProjectVersion: 3.0.0
  ModuleVersion:  4.0.0 (ZIPFILE_MODULE_SOURCE_VERSION, ZipFile.Facade.pas -
                   o modulo ZipFile nao tem unit <Modulo>.Version.pas propria
                   como Connections/Database/Parameters/PoolConnections/
                   ActiveDirectory; confirmado por leitura + Glob no modulo)
  FileVersion:    1.0.0
  Company:        CSL Tech Solutions
  Author:         Claiton de Souza Linhares
  Date:           03/08/2026

  Changelog (file):
  - 1.0.0 (03/08/2026): criacao (FASE 10, Onda 10.1-a2 - ActiveDirectory/
    ZipFile, decisao do owner) - slice de fachada Providers.ZipFile (re-export
    de IZipFileBuilder + TCompressionMethod/TReCompressionMethod/
    TFileChangedEvent/TZipProgressEvent + TArchiveFormat/EArchiveDetectError/
    TArchive [alias de ZipFile.Facade.TArchive, umbrella multi-formato] +
    factory TProvidersZipFile que delega em Zip.NewArchive/Zip.OpenArchive).
    3 desvios documentados no cabecalho: IArchive/IArchiveEntry/IArchiveBuilder
    nao re-exportados (sem implementacao no modulo); TCompressionMethod
    re-exportado e o de ZipFile.Interfaces (o que IZipFileBuilder usa de
    facto, nao o de ZipFile.Compression); TArchive re-exportada por alias de
    tipo (nao wrapper method-a-method). A ligacao TProviders.NewZip fecha na
    mesma onda (Main/Providers.pas).
  ============================================================================= }

unit Providers.ZipFile;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Commons.ZipFile.Types, // TZipProgressEvent (tipo re-exportado)
  ZipFile.Interfaces,    // IZipFileBuilder + TCompressionMethod/TReCompressionMethod/TFileChangedEvent (contratos/tipos re-exportados)
  ZipFile,                // Zip (factory do formato ZIP base, sempre presente)
  ZipFile.Facade;         // TArchive (fachada umbrella multi-formato, 10 formatos)

type
  { --- Re-export do contrato do modulo (o consumidor nomeia-o via este slice) ---
    IArchive/IArchiveEntry/IArchiveBuilder NAO re-exportados - ver ponto 1 do
    cabecalho (declarados em ZipFile.Interfaces.pas, sem nenhuma classe
    implementadora no modulo). }
  IZipFileBuilder = ZipFile.Interfaces.IZipFileBuilder;

  { --- Re-export dos tipos publicos usados pelos metodos fluentes de IZipFileBuilder ---
    TCompressionMethod: ver ponto 3 do cabecalho (armadilha de identificador
    reaproveitado dentro de ZipFile.Interfaces.pas - este e o que
    IZipFileBuilder.WithCompression realmente usa). }
  TCompressionMethod   = ZipFile.Interfaces.TCompressionMethod;
  TReCompressionMethod = ZipFile.Interfaces.TReCompressionMethod;
  TFileChangedEvent    = ZipFile.Interfaces.TFileChangedEvent;
  TZipProgressEvent    = Commons.ZipFile.Types.TZipProgressEvent;

  { --- Re-export do nucleo umbrella multi-formato (ZipFile.Facade) --- ver ponto 4 do cabecalho. }
  TArchiveFormat      = ZipFile.Facade.TArchiveFormat;
  EArchiveDetectError = ZipFile.Facade.EArchiveDetectError;
  TArchive            = ZipFile.Facade.TArchive;

  { Slice da fachada TProviders para o modulo ZipFile. A F10 liga
    TProviders.NewZip a estes membros - sem duplicar logica. Formato ZIP e
    core do modulo (sem gate USE_* proprio) - esta unit acompanha o mesmo
    regime (sempre presente). Para os outros 9 formatos (TAR/TARGZ/GZIP/
    SEVENZ/CAB/RAR/ARJ/LHA/ISO), usar Providers.ZipFile.TArchive directamente
    (deteccao, Create<Fmt>, Extract<Fmt>ToFolder - cada um com o seu
    USE_ARCHIVE_<FMT> interno). }
  TProvidersZipFile = class
  public
    { Factory fluente do formato ZIP base (delega em Zip.NewArchive - unit
      ZipFile.pas, Onda F1-A). Cria um novo arquivo .zip em APath. }
    class function NewArchive(const APath: string): IZipFileBuilder; static;

    { Factory fluente do formato ZIP base (delega em Zip.OpenArchive - unit
      ZipFile.pas, Onda F1-A). Abre um arquivo .zip existente em APath para
      leitura/actualizacao. }
    class function OpenArchive(const APath: string): IZipFileBuilder; static;
  end;

implementation

{ TProvidersZipFile }

class function TProvidersZipFile.NewArchive(const APath: string): IZipFileBuilder;
begin
  Result := ZipFile.Zip.NewArchive(APath);
end;

class function TProvidersZipFile.OpenArchive(const APath: string): IZipFileBuilder;
begin
  Result := ZipFile.Zip.OpenArchive(APath);
end;

end.
