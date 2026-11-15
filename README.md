# Glosala

Aplicación Flutter de notas Markdown e ideas conectadas, inspirada en el flujo de trabajo de Obsidian. Incluye tareas, traducciones XML editables, temas, sincronización y un primer plugin de exportación.

## Ejecutar

Requiere **Flutter 3.50.0 / Dart 3.14**. El CI utiliza la misma versión.

```bash
flutter pub get
flutter run -d linux
# Alternativa: navegador
flutter run -d chrome
```

Para Android, conecta un dispositivo o inicia un emulador y ejecuta `flutter run`. Windows se compila en Windows; macOS e iOS requieren macOS y Xcode.

## Funcionalidades

- **Notas:** editor Markdown, lectura y vista dividida en pantallas amplias; guardado automático, búsqueda, carpetas lógicas, favoritas, etiquetas, pestañas y papelera reversible.
- **Conexiones:** `[[Título]]`, `[[Título|alias]]`, enlaces entrantes y mapa interactivo. Al renombrar una nota se actualizan sus enlaces internos.
- **Tareas:** tareas y subtareas anidadas, edición, eliminación con confirmación y filtros. Completar una tarea completa sus subtareas; los padres reflejan el estado de sus hijas.
- **Idiomas:** español, inglés, francés, alemán y portugués. Selector en Opciones y editor XML con validación, importación y exportación. El contenido de las notas conserva su idioma original.
- **Apariencia:** claro, oscuro o sistema; temas Amatista, Bosque, Océano y Ámbar.
- **Sincronización:** manual, mediante WebDAV o una carpeta de escritorio/NAS montada. Comparación de versiones y copias de conflicto, sin descartar silenciosamente contenido.
- **Plugins:** zona de activación y configuración. El primer plugin exporta una o todas las notas a Markdown, ZIP, HTML, PDF y ODS.
- **Acerca de:** versión, repositorio, licencias y comprobación de actualizaciones en GitHub Releases.

## Persistencia

En Android, iOS y escritorio, cada nota es un `.md` con cabecera YAML dentro del directorio de soporte de la aplicación. La ruta se muestra en **Opciones → Ubicación de la bóveda**. Las carpetas de la interfaz son metadatos y los nombres de archivo son identificadores estables. Copia la bóveda completa, con la aplicación cerrada, para conservar notas, tareas y preferencias.

En web se utiliza **IndexedDB**. Los datos pertenecen al navegador y al origen de la aplicación; borrar los datos del sitio también elimina la bóveda. Usa exportación o sincronización para conservar otra copia. No hay cuentas ni servicio central de almacenamiento.

Las traducciones originales están en `recursos/idiomas/*.xml`. Las modificaciones hechas desde Opciones se guardan como preferencias locales y se pueden exportar como XML. No se modifica el catálogo instalado dentro del ejecutable.

## Sincronización

Consulta [la configuración de sincronización](documentacion/sincronizacion.md). Se comparten notas, papelera y carpetas; tareas, preferencias, idiomas y credenciales permanecen en cada dispositivo.

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
| Linux x64 | Archivo tar.gz con el ejecutable y sus bibliotecas |
| Windows x64 | ZIP con la aplicación completa |
| macOS | ZIP de la aplicación, sin notarización |
| Android | APK de pruebas, firmado con clave de desarrollo |
| iOS | ZIP de la aplicación sin firmar; no instalable directamente |
| Web | ZIP de los archivos estáticos y motor local |

Las etiquetas `v*` repiten las verificaciones y crean un **borrador** de GitHub Release con artefactos y SHA-256. La etiqueta debe coincidir con `pubspec.yaml` y `CAMBIOS.md`. No se publican versiones automáticamente ni se suben aplicaciones a tiendas. Consulta [distribución](documentacion/notas_distribucion.md).

## Organización

```text
lib/
  dominio/           # Notas, tareas, bóveda y enlaces Markdown
  aplicacion/        # Operaciones y estado observable
  datos/             # Repositorios nativo y web
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

No incluye compatibilidad completa con una bóveda de Obsidian: aún no hay selección de bóvedas arbitrarias, observación de cambios externos en caliente, sincronización automática, edición colaborativa, enlaces a bloques, transclusiones ni gestor de adjuntos. Markdown admite imágenes por URL en lectura; el PDF no descarga ni incrusta imágenes. Las actualizaciones se consultan y descargan manualmente.
