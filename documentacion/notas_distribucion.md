# Glosala 0.2.0

Esta versión incorpora adjuntos, un espacio de trabajo ajustable y mejoras de edición y organización de notas.

## Novedades

- Adjuntos de imágenes, audio, vídeo y documentos, con visor, reproductor, descarga del original y sincronización. Exportaciones ZIP con los archivos y enlaces relativos en Markdown y HTML.
- Modo sin distracciones mediante el botón de enfoque o Ctrl/Cmd+Mayús+F.
- Columnas ocultables, ancho ajustable y pestañas junto a los controles de ventana. Opciones organizadas por secciones.
- Ordenación persistente, duplicación, menús contextuales y selección múltiple de notas.
- Buscar y reemplazar, deshacer/rehacer y formato Markdown sobre varias líneas.
- Cinco idiomas actualizados y notas de ejemplo que se pueden añadir conservando las existentes.

Las bóvedas con adjuntos usan el formato 2: actualiza Glosala en todos los dispositivos antes de sincronizarlas. El límite es de 100 MB por archivo y 512 MB por bóveda. Los formatos reproducibles dependen de los códecs del dispositivo o del navegador. Quitar un adjunto de una nota conserva el original para Deshacer y las copias de conflicto.

Los paquetes se crean después del análisis y las pruebas del mismo commit. El archivo `SHA256SUMS.txt` permite comprobar su integridad.

## Firma e instalación

- **Linux:** extraer el paquete completo y ejecutar `glosala`; requiere GTK 3 y libmpv del sistema. Mantener juntos `data/` y `lib/`. Para compilar se necesitan también las cabeceras de libmpv.
- **Windows:** extraer todo el ZIP; conservar las DLL y `data/`. No está firmado con un certificado de editor.
- **macOS:** aplicación sin notarizar. Antes de distribuirla a usuarios se necesita configurar la firma y notarización de Apple.
- **Android:** APK de pruebas firmado con una clave de desarrollo. Para distribución estable o Play Store hay que configurar una clave de publicación y conservarla entre versiones.
- **iOS:** aplicación compilada sin firma. Requiere certificado, perfil de aprovisionamiento y empaquetado IPA desde Xcode para instalar o distribuir.
- **Web:** servir los archivos con un servidor estático. Los datos son locales al navegador y al origen; conviene mantener la misma dirección entre versiones.

No se crean certificados, claves de firma ni cuentas de tiendas automáticamente. El comprobador de actualizaciones muestra únicamente GitHub Releases publicadas; no muestra borradores y no instala ejecutables.
