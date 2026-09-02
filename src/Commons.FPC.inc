{ Define usado por Parameters.Types e Attributers para escolher Generics.Collections (FPC 3.3.1+)
  ou fgl. Incluído apenas quando FPC está definido (evita E2026 no Delphi). }
{$IF FPC_FULLVERSION >= 30301}
  {$DEFINE FPC_USE_GENERICS_COLLECTIONS}
{$ENDIF}
{ FPC 3.3.1+ expõe GetAttributes em TRttiType/TRttiProperty; usar Rtti.TCustomAttribute. }
{$IF FPC_FULLVERSION >= 30301}
  {$DEFINE FPC_RTTI_GETATTRIBUTES}
{$ENDIF}
