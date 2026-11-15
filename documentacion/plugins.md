# Plugins y exportación

`PluginGlosala` define identificador, nombre y descripción. `PluginExportacion` es la primera implementación incluida. Se activa o desactiva desde la zona **Plugins**, y su estado se guarda en las preferencias de la bóveda. Por ahora se compila con la aplicación; no hay descarga ni ejecución dinámica de plugins externos.

## Formatos

- **Markdown:** contenido original en UTF-8. Una selección múltiple genera un ZIP con identificadores en los nombres para evitar colisiones.
- **HTML:** documento independiente con estilos, títulos, listas, tablas, código y enlaces seguros. Se escapan los fragmentos HTML del contenido y se aplica una política de contenido sin scripts.
- **PDF:** documento A4 paginado, fuentes incluidas, encabezados, listas, código y tablas. La primera versión simplifica algunos estilos en línea y no incrusta imágenes.
- **ODS:** libro OpenDocument con una hoja `Notas`. Cada nota ocupa una fila con título, carpeta, contenido Markdown, etiquetas y fecha de modificación. Las celdas son texto, no fórmulas.

El selector nativo permite elegir el destino. En web inicia la descarga. Los archivos exportados son copias: exportar no mueve ni elimina las notas.

## Añadir otro plugin

1. Implementar `PluginGlosala` en un archivo de `lib/plugins/`.
2. Añadir su configuración y activación a la zona de plugins.
3. Guardar sus preferencias a través de `ControladorBoveda.configurar`.
4. Incluir textos en los cinco catálogos XML y probar su comportamiento y los formatos que produzca.
