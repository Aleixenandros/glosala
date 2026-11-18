; Lanzador autocontenido: no instala ni registra la aplicación en Windows.
Unicode true
Name "Glosala portable"
OutFile "${Salida}"
Icon "${Icono}"
RequestExecutionLevel user
SilentInstall silent
AutoCloseWindow true
CRCCheck force
SetCompressor /SOLID lzma
VIProductVersion "${Version}.0"
VIAddVersionKey "ProductName" "Glosala portable"
VIAddVersionKey "FileDescription" "Glosala portable"
VIAddVersionKey "FileVersion" "${Version}"
VIAddVersionKey "LegalCopyright" "Aleixenandros"

Section
  InitPluginsDir
  SetOutPath "$PLUGINSDIR\aplicacion"
  File /r "${Aplicacion}\*"
  ; El hijo usa el directorio del EXE descargado para los datos persistentes.
  System::Call 'kernel32::SetEnvironmentVariableW(w "GLOSALA_PORTABLE_DIR", w "$EXEDIR") i.r0'
  StrCmp $0 0 fallo
  ClearErrors
  ExecWait '"$PLUGINSDIR\aplicacion\glosala.exe"' $0
  IfErrors fallo
  SetErrorLevel $0
  Goto fin
fallo:
  MessageBox MB_OK|MB_ICONSTOP "No se ha podido abrir Glosala portable."
  SetErrorLevel 1
fin:
  ; NSIS elimina PLUGINSDIR al salir, después de que termine la aplicación.
  SetOutPath "$TEMP"
SectionEnd
