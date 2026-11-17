# Archivos adjuntos

Abre el botón **Adjuntos** (clip) del editor y pulsa **Añadir archivos**. Puedes seleccionar varios archivos: se copian a la bóveda y se insertan en la posición del cursor. Las imágenes aparecen dentro de la nota; los demás archivos, como enlaces. No se modifica el original ni se depende de su ubicación después de importarlo.

Pulsa una imagen, un enlace de archivo o una fila de la lista de adjuntos para abrirlo:

- **Imágenes:** vista previa con zoom. Si el formato no se puede visualizar, puedes guardar el archivo original.
- **Audio y vídeo:** reproductor con pausa, desplazamiento y silencio. No se inicia automáticamente y se detiene al cerrar el visor. Los formatos y códecs disponibles dependen del dispositivo; en web dependen del navegador.
- **Documentos:** PDF, documentos de Office/OpenDocument y otros formatos habituales se abren con la aplicación asociada del sistema. En web se puede abrir el PDF en otra pestaña; los demás documentos se guardan para abrirlos localmente.
- **Otros archivos:** se conservan y se pueden descargar mediante **Guardar una copia**.

Los cambios realizados por otra aplicación afectan a una copia temporal. Para incorporar una versión editada, vuelve a adjuntarla en Glosala.

## Edición y conservación

Los enlaces tienen la forma `[nombre](adjunto:identificador)`; las imágenes utilizan `![nombre](adjunto:identificador)`. La identidad incluye el nombre y el contenido. Dos archivos diferentes con el mismo nombre se conservan por separado; adjuntar otra vez el mismo contenido con el mismo nombre reutiliza su copia.

**Quitar de la nota** elimina sus referencias en el texto. Puede deshacerse con **Ctrl/Cmd+Z**. La copia binaria se conserva en la bóveda para que Deshacer, las notas duplicadas y los conflictos sigan funcionando; quitar un enlace no libera espacio en disco ni borra el archivo de otros dispositivos. Las notas en la papelera también conservan sus adjuntos.

El límite es de **100 MB por archivo** y **512 MB de adjuntos por bóveda**, incluidos los archivos conservados sin referencias. Los archivos se leen por bloques y un lote que exceda los límites se rechaza antes de insertar enlaces. Si falla el guardado, permanece el aviso de cambios pendientes y se puede reintentar.

## Almacenamiento y sincronización

En escritorio y móvil, los binarios se guardan en `attachments/`, junto a `notes/` y `workspace.json`. En web se utiliza un almacén separado de IndexedDB; actualizar desde la versión anterior conserva las notas existentes. Los archivos no se vuelven a escribir con cada cambio del texto. Se comprueban tamaño e integridad al leer una bóveda.

La sincronización WebDAV/carpeta incluye los adjuntos y reúne las copias necesarias para las notas en conflicto, también cuando se adjunta un archivo durante el envío. No sincroniza rutas de origen ni credenciales. El documento remoto contiene los binarios codificados en base64, por lo que su tamaño y el tiempo de sincronización aumentan al añadir vídeos grandes.

Las bóvedas con adjuntos utilizan el formato 2. Los clientes anteriores rechazan ese formato; actualiza Glosala en todos los dispositivos antes de sincronizarlos. Las bóvedas antiguas sin adjuntos siguen siendo compatibles.

## Exportación

Si una nota contiene adjuntos, la exportación crea un **ZIP** con el documento Markdown, HTML, PDF u ODS y una carpeta `adjuntos/` con los archivos originales. Markdown y HTML utilizan enlaces relativos; extrae el ZIP completo para mantenerlos. El HTML incluye las imágenes locales. Los archivos de audio, vídeo y documentos se entregan por separado, sin incrustarlos en el PDF u ODS generado.

Solo se incluyen los archivos referenciados por las notas seleccionadas. La importación de notas Markdown sigue siendo de texto: un ZIP exportado no se importa automáticamente como bóveda. Para trasladar las notas con sus adjuntos entre instalaciones de Glosala, utiliza la sincronización.

## Reproducción en Linux

El reproductor utiliza [MediaKit](https://pub.dev/packages/media_kit). Linux necesita `libmpv` instalado; para compilar también se requieren sus cabeceras (`libmpv-dev` en Debian/Ubuntu o `mpv-devel` en Fedora). La biblioteca es un requisito para ejecutar el paquete Linux. Si un códec no está disponible, puedes guardar el adjunto para abrirlo con otra aplicación.
