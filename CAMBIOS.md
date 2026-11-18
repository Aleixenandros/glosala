# Historial de cambios

## [0.2.1] — 2026-11-18

- Instaladores DEB y RPM para Linux, MSI y EXE para Windows, y DMG y PKG para macOS, además de los paquetes portables.
- Accesos de lanzamiento y dependencias declaradas en Linux; runtime de Visual C++ incluido en Windows.
- Windows portable en un único `_portable.exe`, sin instalación, con bóveda y preferencias en `datos/boveda` junto al ejecutable, independiente de la versión instalada.
- CI comprueba instalación y desinstalación, y exige todos los formatos antes de preparar una Release.

## [0.2.0] — 2026-11-17

- Adjuntos de imágenes, audio, vídeo, documentos y otros archivos desde el editor; visor, reproductor y descarga del original. Copias locales verificadas, sincronización conservando conflictos y exportaciones ZIP con archivos y enlaces portables.
- Modo sin distracciones con nota centrada, cabecera mínima, botón y atajo Ctrl/Cmd+Mayús+F; Esc restaura la disposición anterior conservando selección e historial de edición.
- Pestañas y nueva nota integradas en la cabecera de ventana, con desplazamiento a la pestaña activa.
- Bóveda redimensionable con arrastre, teclado o doble clic para restablecer; ancho y visibilidad de las columnas conservados entre sesiones. Botón de cierre dentro del panel de detalles.
- Columna de notas compacta y ocultable, carpetas y etiquetas plegables, sin accesos duplicados a ajustes.
- Opciones dividida en apariencia, idiomas, bóveda local, plugins y acerca de, con sincronización al final.
- Controles de ventana integrados en la cabecera de escritorio, arrastre, doble clic para maximizar y cierre que espera al guardado.
- Ordenación persistente del listado por modificación, creación o título; duplicación individual y por lotes.
- Buscar y reemplazar en la nota con resaltado, mayúsculas opcionales y navegación entre coincidencias.
- Deshacer/Rehacer acotado a la nota abierta; listas, tareas, citas y encabezados sobre selecciones de varias líneas.
- Notas de ejemplo con humor de Chiquito Ipsum y carga desde Opciones sin sobrescribir contenido existente.
- Menús contextuales de notas y carpetas mediante botón derecho, pulsación larga o botón de opciones.
- Selección múltiple con Ctrl/Cmd, Mayús y casillas; acciones por lote y exportación de la selección.
- Atajos de menú contextual y selección total limitados al listado, respetando los atajos del editor.
- Plugins dentro de Opciones; el exportador habilita el submenú «Exportar a…» en notas y selecciones.
- Renombrado y eliminación de carpetas conservando sus notas, incluida la papelera, y propagación de los cambios al sincronizar.
- Nuevos textos en los cinco idiomas y conservación de traducciones personales al actualizar los catálogos.

## [0.1.0] — 2026-11-15

- Base Flutter para Android, iOS, Linux, Windows, macOS y web.
- Editor Markdown con búsqueda, carpetas, etiquetas, favoritas, papelera y conexiones entre notas.
- Módulo de tareas y subtareas.
- Cinco idiomas XML editables y temas configurables.
- Sincronización manual WebDAV y carpeta/NAS con control de concurrencia.
- Plugin de exportación Markdown, ZIP, HTML, PDF y ODS.
- Opciones, acerca de y comprobación de actualizaciones.
- Pruebas y CI multiplataforma con artefactos y borradores de versión.
