import 'dart:ui' show AppExitResponse;
// Compatibilidad con el renderizador Markdown hasta su migración a material_ui.
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../aplicacion/controlador_boveda.dart';
import 'tema_aplicacion.dart';
import 'componentes/vista_mapa.dart';
import 'componentes/editor_nota.dart';
import 'componentes/inspector_nota.dart';
import 'componentes/panel_boveda.dart';
import '../idiomas/gestor_idiomas.dart';
import 'modulos/panel_tareas.dart';
import 'modulos/panel_sincronizacion.dart';
import 'modulos/panel_opciones.dart';
import 'modulos/panel_plugins.dart';
import 'modulos/panel_acerca.dart';

class PantallaEspacio extends StatefulWidget {
  const PantallaEspacio({super.key, required this.controller});
  final ControladorBoveda controller;

  @override
  State<PantallaEspacio> createState() => _EstadoPantallaEspacio();
}

class _EstadoPantallaEspacio extends State<PantallaEspacio>
    with WidgetsBindingObserver {
  final _estructura = GlobalKey<ScaffoldState>();
  final _editor = GlobalKey<EstadoEditorNota>();
  bool _inspector = true;
  bool _operacionArchivo = false;
  String _modulo = 'notas';
  ControladorBoveda get c => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(c.guardarPendientes());
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await c.guardarPendientes();
    return c.estadoGuardado == EstadoGuardado.error
        ? AppExitResponse.cancel
        : AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) {
    if (!c.cargada) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_off_outlined, size: 36),
                SizedBox(height: 18),
                Text(t('No se ha podido leer tu bóveda.')),
                SizedBox(height: 12),
                SelectableText(
                  c.errorLectura ?? 'Abriendo notas…',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 18),
                FilledButton(
                  onPressed: c.inicializar,
                  child: Text(t('Reintentar')),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.keyN, control: true): _crearNota,
        SingleActivator(LogicalKeyboardKey.keyN, meta: true): _crearNota,
        SingleActivator(LogicalKeyboardKey.keyP, control: true):
            _aperturaRapida,
        SingleActivator(LogicalKeyboardKey.keyP, meta: true): _aperturaRapida,
        SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            unawaited(c.guardarPendientes()),
        SingleActivator(LogicalKeyboardKey.keyS, meta: true): () =>
            unawaited(c.guardarPendientes()),
        SingleActivator(LogicalKeyboardKey.keyB, control: true): () =>
            _editor.currentState?.format('**', '**', 'texto'),
        SingleActivator(LogicalKeyboardKey.keyB, meta: true): () =>
            _editor.currentState?.format('**', '**', 'texto'),
        SingleActivator(LogicalKeyboardKey.keyI, control: true): () =>
            _editor.currentState?.format('*', '*', 'texto'),
        SingleActivator(LogicalKeyboardKey.keyI, meta: true): () =>
            _editor.currentState?.format('*', '*', 'texto'),
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final amplio = constraints.maxWidth >= 900;
            final mostrarInspector =
                _modulo == 'notas' &&
                _inspector &&
                constraints.maxWidth >= 1280 &&
                c.notaSeleccionada != null &&
                !c.mapaVisible;
            final sidebar = PanelBoveda(
              controller: c,
              alCrear: _crearNota,
              alCrearCarpeta: _crearCarpeta,
              alImportar: _importarMarkdown,
              alAbrirOpciones: () => _cambiarModulo('opciones'),
              alSeleccionar: (nota) {
                setState(() => _modulo = 'notas');
                c.seleccionarNota(nota.id);
                _estructura.currentState?.closeDrawer();
              },
            );
            return Scaffold(
              key: _estructura,
              drawer: amplio
                  ? null
                  : Drawer(width: 300, child: SafeArea(child: sidebar)),
              body: SafeArea(
                child: Column(
                  children: [
                    if (_operacionArchivo)
                      LinearProgressIndicator(minHeight: 2),
                    if (c.estadoGuardado == EstadoGuardado.error)
                      MaterialBanner(
                        content: Text(
                          '${t('No se han guardado los últimos cambios.')} ${c.errorGuardado ?? ''}',
                          maxLines: 3,
                        ),
                        leading: Icon(Icons.cloud_off_rounded),
                        actions: [
                          TextButton(
                            onPressed: () => c.guardarPendientes(),
                            child: Text(t('Reintentar')),
                          ),
                        ],
                      ),
                    Expanded(
                      child: Row(
                        children: [
                          if (amplio) ...[
                            _barraLateral(context),
                            if (_modulo == 'notas')
                              SizedBox(width: 272, child: sidebar),
                            VerticalDivider(width: 1),
                          ],
                          Expanded(
                            child: Column(
                              children: [
                                _barraSuperior(context, amplio),
                                Divider(),
                                if (_modulo == 'notas' &&
                                    !c.mapaVisible &&
                                    c.notasAbiertas.isNotEmpty)
                                  _pestanas(context),
                                Expanded(
                                  child: _modulo != 'notas'
                                      ? _panelModulo()
                                      : c.mapaVisible
                                      ? VistaMapa(controller: c)
                                      : c.notaSeleccionada == null
                                      ? _estadoVacio(context)
                                      : EditorNota(
                                          key: _editor,
                                          nota: c.notaSeleccionada!,
                                          controller: c,
                                          alRenombrar: _renombrarNota,
                                          alExportar: () =>
                                              _cambiarModulo('plugins'),
                                          alMover: _moverNota,
                                          alEnviarPapelera: _enviarPapelera,
                                        ),
                                ),
                              ],
                            ),
                          ),
                          if (mostrarInspector) ...[
                            VerticalDivider(width: 1),
                            SizedBox(
                              width: 242,
                              child: InspectorNota(
                                controller: c,
                                nota: c.notaSeleccionada!,
                                alEncabezado: (offset) =>
                                    _editor.currentState?.irAEncabezado(offset),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!amplio) _navegacionMovil(context),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _barraLateral(BuildContext context) => Container(
    width: 58,
    color: TemaAplicacion.rail(context),
    padding: EdgeInsets.symmetric(vertical: 19),
    child: Column(
      children: [
        Icon(
          Icons.blur_on_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 29,
        ),
        SizedBox(height: 29),
        _botonLateral(
          Icons.description_outlined,
          t('Notas'),
          _modulo == 'notas' && !c.mapaVisible,
          () {
            _cambiarModulo('notas');
            c.mostrarMapa(false);
          },
        ),
        SizedBox(height: 12),
        _botonLateral(
          Icons.search_rounded,
          t('Abrir nota (Ctrl/Cmd+P)'),
          false,
          _aperturaRapida,
        ),
        SizedBox(height: 12),
        _botonLateral(
          Icons.hub_outlined,
          t('Mapa de ideas'),
          _modulo == 'notas' && c.mapaVisible,
          () {
            _cambiarModulo('notas');
            c.mostrarMapa(true);
          },
        ),
        SizedBox(height: 12),
        _botonLateral(
          Icons.checklist_rounded,
          t('Tareas'),
          _modulo == 'tareas',
          () => _cambiarModulo('tareas'),
        ),
        SizedBox(height: 12),
        _botonLateral(
          Icons.sync_rounded,
          t('Sincronización'),
          _modulo == 'sincronizacion',
          () => _cambiarModulo('sincronizacion'),
        ),
        SizedBox(height: 12),
        _botonLateral(
          Icons.extension_outlined,
          t('Plugins'),
          _modulo == 'plugins',
          () => _cambiarModulo('plugins'),
        ),
        Spacer(),
        _botonLateral(
          c.modoOscuro ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          'Cambiar tema',
          false,
          c.alternarTema,
        ),
        SizedBox(height: 12),
        _botonLateral(
          Icons.help_outline_rounded,
          t('Ayuda y atajos'),
          false,
          _ayuda,
        ),
        SizedBox(height: 12),
        _botonLateral(
          Icons.settings_outlined,
          t('Opciones'),
          _modulo == 'opciones',
          () => _cambiarModulo('opciones'),
        ),
        SizedBox(height: 12),
        _botonLateral(
          Icons.info_outline_rounded,
          t('Acerca de'),
          _modulo == 'acerca',
          () => _cambiarModulo('acerca'),
        ),
      ],
    ),
  );

  Widget _botonLateral(
    IconData icon,
    String tooltip,
    bool selected,
    VoidCallback onPressed,
  ) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: selected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: .15)
          : null,
      borderRadius: BorderRadius.circular(10),
    ),
    child: IconButton(
      tooltip: t(tooltip),
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 20,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      padding: EdgeInsets.zero,
    ),
  );

  Widget _barraSuperior(BuildContext context, bool amplio) => SizedBox(
    height: 51,
    child: Padding(
      padding: EdgeInsets.only(left: amplio ? 24 : 6, right: 10),
      child: Row(
        children: [
          if (!amplio)
            IconButton(
              tooltip: t('Abrir bóveda'),
              icon: Icon(Icons.menu_rounded),
              onPressed: () => _estructura.currentState?.openDrawer(),
            ),
          Expanded(
            child: Text(
              t(
                _modulo == 'notas'
                    ? c.mapaVisible
                          ? 'MAPA DE IDEAS'
                          : 'MI ESPACIO'
                    : _nombresModulos[_modulo]!,
              ),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.8,
              ),
            ),
          ),
          Icon(
            c.estadoGuardado == EstadoGuardado.guardando
                ? Icons.more_horiz
                : c.estadoGuardado == EstadoGuardado.error
                ? Icons.error_outline
                : Icons.check_circle_outline,
            size: 13,
            color: c.estadoGuardado == EstadoGuardado.error
                ? Theme.of(context).colorScheme.error
                : Color(0xFF85AB99),
          ),
          SizedBox(width: 6),
          Text(
            t(switch (c.estadoGuardado) {
              EstadoGuardado.guardado => 'Guardado',
              EstadoGuardado.guardando => 'Guardando…',
              EstadoGuardado.error => 'Sin guardar',
            }),
            style: TextStyle(fontSize: 10, color: Color(0xFF8D899A)),
          ),
          SizedBox(width: 12),
          if (amplio)
            IconButton(
              tooltip: t(_inspector ? 'Ocultar detalles' : 'Mostrar detalles'),
              onPressed: () {
                if (MediaQuery.sizeOf(context).width < 1280) {
                  _mostrarDetalles();
                } else {
                  setState(() => _inspector = !_inspector);
                }
              },
              icon: Icon(Icons.view_sidebar_outlined, size: 18),
            ),
        ],
      ),
    ),
  );

  Widget _pestanas(BuildContext context) => Container(
    height: 44,
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final nota in c.notasAbiertas)
          Container(
            constraints: BoxConstraints(maxWidth: 240),
            decoration: BoxDecoration(
              color: c.notaSeleccionada?.id == nota.id
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: .04)
                  : null,
              border: Border(
                right: BorderSide(color: Theme.of(context).dividerColor),
                bottom: BorderSide(
                  color: c.notaSeleccionada?.id == nota.id
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: InkWell(
              onTap: () => c.seleccionarNota(nota.id),
              child: Padding(
                padding: EdgeInsets.only(left: 17, right: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.description_outlined, size: 13),
                    SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        nota.titulo,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      tooltip: t('Cerrar {titulo}', {'titulo': nota.titulo}),
                      onPressed: () => c.cerrarPestana(nota.id),
                      icon: Icon(Icons.close, size: 13),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
          ),
        IconButton(
          tooltip: t('Nueva nota'),
          onPressed: _crearNota,
          icon: Icon(Icons.add, size: 17),
        ),
      ],
    ),
  );

  Widget _navegacionMovil(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Divider(),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            tooltip: t('Nueva nota'),
            onPressed: _crearNota,
            icon: Icon(Icons.note_add_outlined),
          ),
          IconButton(
            tooltip: t('Buscar nota'),
            onPressed: _aperturaRapida,
            icon: Icon(Icons.search),
          ),
          IconButton(
            tooltip: t('Mapa de ideas'),
            onPressed: () {
              _cambiarModulo('notas');
              c.mostrarMapa(!c.mapaVisible);
            },
            icon: Icon(Icons.hub_outlined),
          ),
          IconButton(
            tooltip: t('Detalles de la nota'),
            onPressed: _mostrarDetalles,
            icon: Icon(Icons.subject),
          ),
          IconButton(
            tooltip: t('Cambiar tema'),
            onPressed: c.alternarTema,
            icon: Icon(
              c.modoOscuro
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: t('Módulos'),
            icon: Icon(Icons.apps),
            onSelected: _cambiarModulo,
            itemBuilder: (_) => _nombresModulos.entries
                .map(
                  (entrada) => PopupMenuItem(
                    value: entrada.key,
                    child: Text(t(entrada.value)),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    ],
  );

  Widget _estadoVacio(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 52,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(height: 25),
          Text(
            t('Espacio para tu próxima idea.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w600,
              letterSpacing: -.8,
            ),
          ),
          SizedBox(height: 14),
          Text(
            t('Abre una nota o empieza una nueva historia.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF8D899A), fontSize: 13),
          ),
          SizedBox(height: 25),
          FilledButton.icon(
            onPressed: _crearNota,
            icon: Icon(Icons.add, size: 18),
            label: Text(t('Crear una nota')),
          ),
          SizedBox(height: 18),
          Text(
            t('Ctrl / Cmd + P para abrir una nota'),
            style: TextStyle(fontSize: 10, color: Color(0xFF8D899A)),
          ),
        ],
      ),
    ),
  );

  void _crearNota() {
    _cambiarModulo('notas');
    _estructura.currentState?.closeDrawer();
    c.crearNota();
  }

  static const _nombresModulos = {
    'notas': 'Notas',
    'tareas': 'Tareas',
    'sincronizacion': 'Sincronización',
    'plugins': 'Plugins',
    'opciones': 'Opciones',
    'acerca': 'Acerca de',
  };

  void _cambiarModulo(String modulo) {
    _estructura.currentState?.closeDrawer();
    setState(() => _modulo = modulo);
  }

  Widget _panelModulo() => switch (_modulo) {
    'tareas' => PanelTareas(controlador: c),
    'sincronizacion' => PanelSincronizacion(controlador: c),
    'plugins' => PanelPlugins(controlador: c),
    'opciones' => PanelOpciones(controlador: c),
    'acerca' => PanelAcerca(),
    _ => _estadoVacio(context),
  };

  Future<void> _crearCarpeta() => _dialogoNombre(
    'Nueva carpeta',
    '',
    'Nombre de la carpeta',
    c.anadirCarpeta,
  );

  Future<void> _renombrarNota() async {
    final nota = c.notaSeleccionada;
    if (nota == null) return;
    await _dialogoNombre(
      'Renombrar nota',
      nota.titulo,
      'Título de la nota',
      (value) => c.renombrarNota(nota.id, value),
    );
  }

  Future<void> _dialogoNombre(
    String title,
    String initial,
    String label,
    String? Function(String) save,
  ) async {
    final text = TextEditingController(text: initial);
    text.selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (context, update) {
            void submit() {
              final message = save(text.text);
              if (message == null) {
                Navigator.pop(dialogContext);
              } else {
                update(() => error = message);
              }
            }

            return AlertDialog(
              title: Text(t(title)),
              content: SizedBox(
                width: 350,
                child: TextField(
                  controller: text,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: t(label),
                    errorText: error,
                  ),
                  onSubmitted: (_) => submit(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(t('Cancelar')),
                ),
                FilledButton(onPressed: submit, child: Text(t('Guardar'))),
              ],
            );
          },
        );
      },
    );
    // La transición de la ruta puede seguir utilizando el controlador.
    await Future<void>.delayed(Duration(milliseconds: 300));
    text.dispose();
  }

  Future<void> _moverNota() async {
    final nota = c.notaSeleccionada;
    if (nota == null) return;
    final destino = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(t('Mover a carpeta')),
        children: [
          for (final carpeta in ['', ...c.carpetas])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, carpeta),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  carpeta.isEmpty ? t('Mi bóveda (sin carpeta)') : carpeta,
                ),
              ),
            ),
        ],
      ),
    );
    if (destino != null) c.moverNota(nota.id, destino);
  }

  void _enviarPapelera() {
    final nota = c.notaSeleccionada;
    if (nota == null) return;
    c.enviarPapelera(nota.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t('«{titulo}» está en la papelera.', {'titulo': nota.titulo}),
        ),
        action: SnackBarAction(
          label: t('Deshacer'),
          onPressed: () => c.restaurarNota(nota.id),
        ),
      ),
    );
  }

  Future<void> _importarMarkdown() async {
    if (_operacionArchivo) return;
    setState(() => _operacionArchivo = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'markdown', 'txt'],
        dialogTitle: 'Importar notas Markdown',
      );
      // Leer todos los archivos antes de modificar la bóveda evita importaciones parciales.
      final importadas = <({String titulo, String contenido})>[];
      for (final file in files) {
        final contenido = utf8
            .decode(await file.readAsBytes())
            .replaceFirst(RegExp('^\uFEFF'), '');
        importadas.add((
          titulo: p.basenameWithoutExtension(file.name),
          contenido: contenido,
        ));
      }
      for (final nota in importadas) {
        c.crearNota(titulo: nota.titulo, contenido: nota.contenido);
      }
      if (importadas.isNotEmpty) {
        _mensaje(
          t('{cantidad} notas importadas.', {'cantidad': importadas.length}),
        );
      }
    } catch (error) {
      _mensaje('${t('No se han podido importar las notas.')} $error');
    } finally {
      if (mounted) setState(() => _operacionArchivo = false);
    }
  }

  Future<void> _aperturaRapida() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var busqueda = '';
        return StatefulBuilder(
          builder: (context, update) {
            final coincidencias = c.notasActivas
                .where(
                  (nota) => '${nota.titulo}\n${nota.contenido}'
                      .toLowerCase()
                      .contains(busqueda.toLowerCase()),
                )
                .toList();
            return AlertDialog(
              contentPadding: EdgeInsets.all(16),
              content: SizedBox(
                width: 500,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: t('¿Qué idea estás buscando?'),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => update(() => busqueda = value),
                      onSubmitted: (_) {
                        if (coincidencias.isNotEmpty) {
                          _cambiarModulo('notas');
                          c.seleccionarNota(coincidencias.first.id);
                          Navigator.pop(dialogContext);
                        }
                      },
                    ),
                    SizedBox(height: 12),
                    Expanded(
                      child: coincidencias.isEmpty
                          ? Center(
                              child: Text(t('No se han encontrado notas.')),
                            )
                          : ListView.builder(
                              itemCount: coincidencias.length,
                              itemBuilder: (context, index) {
                                final nota = coincidencias[index];
                                return ListTile(
                                  leading: Icon(
                                    Icons.description_outlined,
                                    size: 18,
                                  ),
                                  title: Text(
                                    nota.titulo,
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    nota.carpeta.isEmpty
                                        ? t('Mi bóveda')
                                        : nota.carpeta,
                                    style: TextStyle(fontSize: 10),
                                  ),
                                  onTap: () {
                                    _cambiarModulo('notas');
                                    c.seleccionarNota(nota.id);
                                    Navigator.pop(dialogContext);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(t('Cerrar')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarDetalles() {
    final nota = c.notaSeleccionada;
    if (nota == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: InspectorNota(
          controller: c,
          nota: nota,
          alEncabezado: (offset) {
            Navigator.pop(context);
            _editor.currentState?.irAEncabezado(offset);
          },
        ),
      ),
    );
  }

  void _ayuda() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(t('Un poco de ayuda')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Text(
            t('ayuda_contenido'),
            style: TextStyle(fontSize: 13, height: 1.9),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('Entendido')),
        ),
      ],
    ),
  );

  void _mensaje(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }
}
