# Distribución de Glosala

Primera base multiplataforma con notas Markdown, tareas y subtareas, cinco idiomas XML editables, temas, sincronización WebDAV/NAS y exportación a Markdown, HTML, PDF y ODS.

Los paquetes se crean después del análisis y las pruebas del mismo commit. El archivo `SHA256SUMS.txt` contiene la integridad de los artefactos. El workflow deja un borrador para revisar antes de publicar.

## Firma e instalación

- **Linux:** extraer el paquete completo y ejecutar `glosala`; requiere las bibliotecas GTK 3 del sistema. Mantener juntos `data/` y `lib/`.
- **Windows:** extraer todo el ZIP; conservar las DLL y `data/`. No está firmado con un certificado de editor.
- **macOS:** aplicación sin notarizar. Antes de distribuirla a usuarios se necesita configurar la firma y notarización de Apple.
- **Android:** APK de pruebas firmado con una clave de desarrollo. Para distribución estable o Play Store hay que configurar una clave de publicación y conservarla entre versiones.
- **iOS:** aplicación compilada sin firma. Requiere certificado, perfil de aprovisionamiento y empaquetado IPA desde Xcode para instalar o distribuir.
- **Web:** servir los archivos con un servidor estático. Los datos son locales al navegador y al origen; conviene mantener la misma dirección entre versiones.

No se crean certificados, claves de firma ni cuentas de tiendas automáticamente. El comprobador de actualizaciones muestra únicamente GitHub Releases publicadas; no muestra borradores y no instala ejecutables.
