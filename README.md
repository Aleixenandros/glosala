# Glosala

Aplicación Flutter de notas Markdown e ideas conectadas, inspirada en el flujo de trabajo de Obsidian. Incluye tareas, traducciones XML editables, temas, sincronización y un primer plugin de exportación.

## Ejecutar

Requiere **Flutter 3.50.0 / Dart 3.14**. El CI utiliza la misma versión.

Para compilar en Linux, instala las bibliotecas de desarrollo GTK 3 y libmpv (`libmpv-dev` en Debian/Ubuntu, `mpv-devel` en Fedora). La reproducción utiliza libmpv del sistema.

```bash
flutter pub get
flutter run -d linux
# Alternativa: navegador
flutter run -d chrome
```

Para Android, conecta un dispositivo o inicia un emulador y ejecuta `flutter run`. Windows se compila en Windows; macOS e iOS requieren macOS y Xcode.

## Funcionalidades

- **Notas:** editor Markdown, lectura y vista dividida en pantallas amplias; guardado automático, búsqueda, carpetas lógicas, favoritas, etiquetas, pestañas y papelera reversible. Ordenación por modificación, creación o título, guardada entre sesiones; duplicación de notas individuales o selecciones con títulos únicos.
- **Edición:** búsqueda literal dentro de la nota, resaltado, navegación y reemplazo individual o completo. Deshacer/Rehacer con historial acotado de la nota abierta; formato de listas, tareas, citas y encabezados sobre todas las líneas seleccionadas.
- **Adjuntos:** imágenes con vista previa, reproductor de audio/vídeo y documentos que se abren o descargan desde el botón de clip. Copias locales, sincronización y exportación en ZIP con los originales; hasta 100 MB por archivo. [Uso y límites](documentacion/adjuntos.md).
- **Conexiones:** `[[Título]]`, `[[Título|alias]]`, enlaces entrantes y mapa interactivo. Al renombrar una nota se actualizan sus enlaces internos.
- **Tareas:** tareas y subtareas anidadas, edición, eliminación con confirmación y filtros. Completar una tarea completa sus subtareas; los padres reflejan el estado de sus hijas.
- **Idiomas:** español, inglés, francés, alemán y portugués. Selector en **Opciones → Idiomas** y editor XML con validación, importación y exportación. El contenido de las notas conserva su idioma original.
- **Apariencia:** claro, oscuro o sistema; temas Amatista, Bosque, Océano y Ámbar.
- **Sincronización:** al final de **Opciones**, mediante WebDAV o una carpeta de escritorio/NAS montada. Comparación manual de versiones y copias de conflicto, sin descartar silenciosamente contenido.
- **Espacio de trabajo:** columna de notas ocultable y redimensionable arrastrando su borde derecho; doble clic en el separador restablece el ancho. La columna de detalles se oculta desde su botón de cierre o desde la cabecera. Se recuerdan el ancho y la visibilidad de ambas columnas. Carpetas y etiquetas son plegables, con Papelera debajo. Opciones organiza apariencia, idiomas, bóveda, plugins, acerca de y sincronización en secciones independientes.
- **Ventana de escritorio:** pestañas, nueva nota y controles de minimizar, maximizar/restaurar y cerrar comparten una sola cabecera. Arrastra el nombre de la aplicación o los espacios libres de la cabecera para moverla; haz doble clic allí para maximizar. Los bordes permiten cambiar su tamaño. El cierre espera al guardado y se cancela si falla.
- **Sin distracciones:** botón de enfoque en la cabecera o **Ctrl/Cmd+Mayús+F**. Centra la nota y oculta navegación, columnas, pestañas y herramientas. **Esc** o **Salir** recuperan la disposición anterior; se conservan la selección, el historial y el guardado automático.
- **Menús contextuales:** botón derecho, pulsación larga o botón de opciones en cada nota y carpeta. Las carpetas se pueden renombrar o eliminar conservando sus notas en la raíz.
- **Selección múltiple:** Ctrl/Cmd + clic, Mayús + clic para rangos o casillas. Permite mover, marcar favoritas, enviar a la papelera, restaurar y exportar las notas seleccionadas. «Seleccionar todas» respeta la búsqueda y la carpeta visibles. Con el foco en el listado, Ctrl/Cmd+A selecciona todas y Escape limpia la selección; Mayús+F10 abre el menú contextual.
- **Plugins:** activación en **Opciones → Plugins**. Al habilitar Exportación de notas, el menú de cada nota o selección ofrece **Exportar a… → Markdown, HTML, PDF u ODS**. Varias notas en Markdown se reúnen en un ZIP.
- **Acerca de:** en **Opciones → Acerca de**, versión, repositorio, licencias y comprobación de actualizaciones en GitHub Releases.

## Editor y ejemplos

Consulta [los atajos y herramientas del editor](documentacion/editor.md). Las notas de bienvenida combinan ejemplos de Markdown con un toque de [Chiquito Ipsum](https://www.chiquitoipsum.com/). Desde **Opciones → Bóveda local → Añadir notas de ejemplo** puedes incorporarlas a una bóveda existente. Se crean copias con identificadores y títulos nuevos, conservando las notas que ya tenías y conectando los ejemplos entre sí.

## Persistencia

En Android, iOS y escritorio, cada nota es un `.md` con cabecera YAML dentro del directorio de soporte de la aplicación. La ruta se muestra en **Opciones → Bóveda local → Ubicación de la bóveda**. Las carpetas de la interfaz son metadatos y los nombres de archivo son identificadores estables. Copia la bóveda completa, con la aplicación cerrada, para conservar notas, tareas y preferencias.

En web se utiliza **IndexedDB**. Los datos pertenecen al navegador y al origen de la aplicación; borrar los datos del sitio también elimina la bóveda. Usa exportación o sincronización para conservar otra copia. No hay cuentas ni servicio central de almacenamiento.

Las traducciones originales están en `recursos/idiomas/*.xml`. Las modificaciones hechas desde Opciones se guardan como preferencias locales y se pueden exportar como XML. No se modifica el catálogo instalado dentro del ejecutable. Al actualizar la aplicación se añaden las nuevas claves conservando las traducciones personales.

## Sincronización

Consulta [la configuración de sincronización](documentacion/sincronizacion.md). Se comparten notas, papelera, carpetas y adjuntos; tareas, preferencias, idiomas y credenciales permanecen en cada dispositivo.

## Exportación y plugins

Consulta [el contrato y los formatos de exportación](documentacion/plugins.md). Los plugins de esta primera versión están integrados en el ejecutable; todavía no existe un instalador de plugins externos.

## Comprobar el proyecto

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
python3 herramientas/verificar_proyecto.py
flutter test --coverage
```

Las pruebas cubren enlaces Markdown, guardado, fallos de escritura, papelera, tareas, catálogos XML, exportaciones, sincronización con un servidor HTTP real y la interfaz móvil/escritorio.

## Compilaciones y CI

Los workflows se inspiran en la separación entre validación y compilación de [Rustty](https://github.com/Aleixenandros/Rustty/tree/main/.github/workflows). Cada push a `main`, PR o ejecución manual valida primero el código y después compila seis plataformas:

| Plataforma | Artefacto |
| --- | --- |
| Linux x64 | Instaladores `.deb` y `.rpm`, y portable `.tar.gz` |
| Windows x64 | Instaladores `.msi` y `.exe`, y ejecutable `_portable.exe` |
| macOS | Imagen `.dmg`, instalador `.pkg` y aplicación `.zip`, sin notarización |
| Android | APK de pruebas, firmado con clave de desarrollo |
| iOS | ZIP de la aplicación sin firmar; no instalable directamente |
| Web | ZIP de los archivos estáticos y motor local |

Las etiquetas `v*` repiten las verificaciones y crean un **borrador** de GitHub Release con artefactos y SHA-256. La etiqueta debe coincidir con `pubspec.yaml` y `CAMBIOS.md`. No se publican versiones automáticamente ni se suben aplicaciones a tiendas. Consulta [distribución](documentacion/notas_distribucion.md).

Desde 0.2.1, el CI exige los doce paquetes y prueba los instaladores: DEB en Ubuntu, RPM en Fedora, MSI/EXE en Windows y DMG/PKG en macOS. Las pruebas de desinstalación conservan los datos de las notas. El `.exe` es un asistente que incluye el mismo MSI; ambos instalan la aplicación completa y el runtime de Visual C++.

Abre `glosala-0.2.1-windows-x64_portable.exe` directamente desde una carpeta con permiso de escritura. Es un único ejecutable con la aplicación y sus DLL incluidas; no necesita instalación ni permisos de administrador. Las notas, adjuntos y preferencias se guardan en `datos/boveda`, junto al EXE descargado. Cierra Glosala y copia el EXE junto con `datos/` para trasladarla; para actualizar, sustituye únicamente el EXE. La bóveda portable es independiente de la versión instalada. Los binarios se extraen temporalmente al abrir y se eliminan al cerrar.

## Organización

```text
lib/
  dominio/           # Notas, tareas, bóveda y enlaces Markdown
  aplicacion/        # Operaciones y estado observable
  datos/             # Repositorios nativo y web
  adjuntos/          # Recursos temporales y apertura por plataforma
  interfaz/          # Navegación, componentes y módulos
  idiomas/           # Lectura y validación de XML
  sincronizacion/    # Transporte, control de concurrencia y mezcla
  plugins/           # Contrato y exportador
  actualizaciones/   # Consulta de GitHub Releases
recursos/idiomas/     # Cinco catálogos XML
herramientas/        # Validación y empaquetado del CI
```

Nuestros archivos y conceptos están en castellano. Los nombres exigidos por Flutter, Dart, GitHub Actions y las plataformas conservan su forma estándar. La carpeta local `memoria/` está expresamente excluida de Git.

## Alcance de esta primera versión

No incluye compatibilidad completa con una bóveda de Obsidian: aún no hay selección de bóvedas arbitrarias, observación de cambios externos en caliente, sincronización automática, edición colaborativa, enlaces a bloques ni transclusiones. Los adjuntos se añaden desde el selector de archivos; todavía no se pueden pegar o arrastrar al editor ni eliminar definitivamente de la bóveda. Markdown admite imágenes locales y por URL en lectura; el PDF no descarga ni incrusta imágenes. Las actualizaciones se consultan y descargan manualmente.
