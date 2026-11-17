# Plugins y exportación

`PluginGlosala` define identificador, nombre y descripción. `PluginExportacion` es la primera implementación incluida. Se activa o desactiva desde **Opciones → Plugins**, y su estado se guarda en las preferencias de la bóveda. Por ahora se compila con la aplicación; no hay descarga ni ejecución dinámica de plugins externos.

## Usar el exportador

1. Activa **Exportación de notas** en **Opciones → Plugins**.
2. Vuelve a Notas y pulsa el botón derecho sobre una nota. En móvil puedes mantenerla pulsada o usar su botón de opciones.
3. Abre **Exportar a…** y elige Markdown, HTML, PDF u ODS.

El menú actúa sobre la nota pulsada, aunque otra esté abierta en el editor. El botón de opciones del editor ofrece las mismas acciones para la nota abierta. Al desactivar el plugin desaparece la exportación de ambos menús.

Para exportar varias notas, selecciónalas con **Ctrl/Cmd + clic**, con **Mayús + clic** para un rango, o activa **Seleccionar notas** y usa las casillas. Abre el menú de una nota marcada o **Acciones de la selección**. La selección también permite mover a carpeta, añadir o quitar favoritas, enviar a la papelera y restaurar. Enviar varias notas a la papelera permite deshacer todo el lote. «Seleccionar todas» incluye solo las notas visibles; cambiar de búsqueda o filtro limpia la selección. Con el foco en el listado, Ctrl/Cmd+A selecciona las notas visibles y Escape limpia la selección. Mayús+F10 o la tecla de menú contextual abren las acciones del elemento enfocado. Estos atajos no sustituyen la selección de texto dentro del editor. Un clic normal tras usar Ctrl/Cmd abre la nota y termina la selección; el modo de casillas activado expresamente se mantiene hasta cancelarlo.

No se configura un formato único en Opciones: se elige en cada exportación. PDF, HTML y ODS reúnen las notas seleccionadas en un documento; Markdown utiliza un ZIP cuando hay varias.

## Formatos

- **Markdown:** contenido original en UTF-8. Una selección múltiple genera un ZIP con identificadores en los nombres para evitar colisiones.
- **HTML:** documento independiente con estilos, títulos, listas, tablas, código y enlaces seguros. Se escapan los fragmentos HTML del contenido y se aplica una política de contenido sin scripts.
- **PDF:** documento A4 paginado, fuentes incluidas, encabezados, listas, código y tablas. La primera versión simplifica algunos estilos en línea y no incrusta imágenes.
- **ODS:** libro OpenDocument con una hoja `Notas`. Cada nota ocupa una fila con título, carpeta, contenido Markdown, etiquetas y fecha de modificación. Las celdas son texto, no fórmulas.

El selector nativo permite elegir el destino. En web inicia la descarga. Los archivos exportados son copias: exportar no mueve ni elimina las notas.

Si las notas contienen adjuntos, cualquiera de los formatos se entrega en un ZIP con el documento y los archivos originales referenciados. Markdown y HTML usan rutas relativas; el HTML muestra las imágenes locales. Extrae el ZIP completo para conservar esos enlaces. Consulta [los detalles y límites de los adjuntos](adjuntos.md).

## Añadir otro plugin

1. Implementar `PluginGlosala` en un archivo de `lib/plugins/`.
2. Añadir su configuración y activación a la sección de plugins dentro de Opciones. Registrar sus acciones donde se utilicen (por ejemplo, en los menús de notas y selección), respetando su estado habilitado.
3. Guardar sus preferencias a través de `ControladorBoveda.configurar`.
4. Incluir textos en los cinco catálogos XML y probar su comportamiento y los formatos que produzca.
