# Glosala 0.2.1

Esta versión añade los instaladores que faltaban en 0.2.0: DEB/RPM, MSI/EXE y DMG/PKG, conservando los paquetes portables. Incluye los adjuntos y las mejoras de edición y organización de 0.2.0.

## Novedades

- Instalación de escritorio con accesos de lanzamiento, dependencias incluidas o declaradas y comprobaciones de instalación en CI. Desinstalar la aplicación conserva la bóveda del usuario.
- Adjuntos de imágenes, audio, vídeo y documentos, con visor, reproductor, descarga del original y sincronización. Exportaciones ZIP con los archivos y enlaces relativos en Markdown y HTML.
- Modo sin distracciones mediante el botón de enfoque o Ctrl/Cmd+Mayús+F.
- Columnas ocultables, ancho ajustable y pestañas junto a los controles de ventana. Opciones organizadas por secciones.
- Ordenación persistente, duplicación, menús contextuales y selección múltiple de notas.
- Buscar y reemplazar, deshacer/rehacer y formato Markdown sobre varias líneas.
- Cinco idiomas actualizados y notas de ejemplo que se pueden añadir conservando las existentes.

Las bóvedas con adjuntos usan el formato 2: actualiza Glosala en todos los dispositivos antes de sincronizarlas. El límite es de 100 MB por archivo y 512 MB por bóveda. Los formatos reproducibles dependen de los códecs del dispositivo o del navegador. Quitar un adjunto de una nota conserva el original para Deshacer y las copias de conflicto.

Los paquetes se crean después del análisis y las pruebas del mismo commit. El archivo `SHA256SUMS.txt` permite comprobar su integridad.

## Firma e instalación

- **Linux x64:** usar `.deb` en Ubuntu 24.04 o posterior y Debian compatible, o `.rpm` en Fedora 44 o posterior. `sudo apt install ./glosala_0.2.1_amd64.deb` o `sudo dnf install ./glosala-0.2.1-1.x86_64.rpm` resuelven las dependencias GTK 3 y libmpv. La aplicación se instala en `/opt/glosala`, con el comando `glosala` y una entrada de menú. Se desinstala con `sudo apt remove glosala` o `sudo dnf remove glosala`. El portable `.tar.gz` requiere esas bibliotecas ya instaladas; hay que conservar juntos el ejecutable, `data/` y `lib/`.
- **Windows x64:** abrir el instalador `.exe` o `.msi`, que instala en Archivos de programa y añade un acceso al menú Inicio. Ambos incluyen la aplicación completa y las DLL de Visual C++; el EXE contiene el mismo MSI. Desinstalar desde Aplicaciones de Windows. También se ofrece un ZIP portable. Los instaladores no tienen firma de editor.
- **macOS:** abrir el `.dmg` y arrastrar Glosala a Aplicaciones, o ejecutar el `.pkg` para instalar en `/Applications`. Se conserva también el ZIP de la aplicación. La aplicación y el instalador no están notarizados ni firmados con un certificado de distribución de Apple.
- **Android:** APK de pruebas firmado con una clave de desarrollo. Para distribución estable o Play Store hay que configurar una clave de publicación y conservarla entre versiones.
- **iOS:** aplicación compilada sin firma. Requiere certificado, perfil de aprovisionamiento y empaquetado IPA desde Xcode para instalar o distribuir.
- **Web:** servir los archivos con un servidor estático. Los datos son locales al navegador y al origen; conviene mantener la misma dirección entre versiones.

No se crean certificados, claves de firma ni cuentas de tiendas automáticamente. El comprobador de actualizaciones muestra únicamente GitHub Releases publicadas; no muestra borradores y no instala ejecutables.

## Comprobación del empaquetado

El CI instala y desinstala DEB, RPM, MSI y EXE, comprueba el arranque en Ubuntu y Windows, monta el DMG e instala el PKG. Los archivos deben superar la comprobación de formatos y estar completos antes de crear la Release. `SHA256SUMS.txt` incluye los doce paquetes.

Las herramientas están en `herramientas/empaquetar.py`; Windows utiliza WiX 5.0.2, con identificadores estables para las actualizaciones. El runtime se copia del directorio de redistribuibles de Visual Studio siguiendo la [distribución local de Microsoft](https://learn.microsoft.com/en-us/cpp/windows/deployment-in-visual-cpp). Linux calcula las dependencias de las bibliotecas de cada binario con `dpkg-shlibdeps` y RPM.
