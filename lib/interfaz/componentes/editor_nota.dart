import '../../idiomas/gestor_idiomas.dart';
// Compatibilidad con el renderizador Markdown hasta su migración a material_ui.
// ignore_for_file: deprecated_member_use

import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../edicion/controlador_texto_nota.dart';
import '../edicion/operaciones_markdown.dart';
import '../edicion/historial_edicion.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../aplicacion/controlador_boveda.dart';
import '../../dominio/nota.dart';
import 'menu_contextual.dart';
import 'dialogo_adjuntos.dart';
import 'visor_adjunto.dart';

class EditorNota extends StatefulWidget {
  const EditorNota({
    super.key,
    this.sinDistracciones = false,
    required this.nota,
    required this.controller,
    required this.alRenombrar,
    required this.acciones,
  });
  final bool sinDistracciones;
  final Nota nota;
  final ControladorBoveda controller;
  final VoidCallback alRenombrar;
  final List<Widget> acciones;

  @override
  State<EditorNota> createState() => EstadoEditorNota();
}

class EstadoEditorNota extends State<EditorNota> {
  late ControladorTextoNota _texto;
  late HistorialEdicion _historial;
  bool _restaurandoHistorial = false;
  final _campoEdicion = GlobalKey();
  final _consulta = TextEditingController();
  final _reemplazo = TextEditingController();
  final _focoBusqueda = FocusNode();
  bool _buscarVisible = false;
  bool _mostrarReemplazo = false;
  bool _distinguirMayusculas = false;
  int _coincidencia = 0;
  late String _ultimoContenido;
  final _foco = FocusNode();
  final _desplazamientoEditor = ScrollController();

  @override
  void initState() {
    super.initState();
    _prepararTexto();
  }

  void _prepararTexto() {
    _ultimoContenido = widget.nota.contenido;
    _texto = ControladorTextoNota(text: _ultimoContenido);
    _texto.buscar(
      _buscarVisible ? _consulta.text : '',
      distinguirMayusculas: _distinguirMayusculas,
    );
    _texto.selection = const TextSelection.collapsed(offset: 0);
    _historial = HistorialEdicion(_texto.value);
    _texto.addListener(_alEditarTexto);
  }

  void _alEditarTexto() {
    if (!_restaurandoHistorial) _historial.registrar(_texto.value);
    if (_texto.text == _ultimoContenido) return;
    _ultimoContenido = _texto.text;
    if (!widget.nota.eliminada) {
      widget.controller.actualizarContenido(widget.nota.id, _texto.text);
    }
    if (_buscarVisible && mounted) setState(() => _coincidencia = 0);
  }

  @override
  void didUpdateWidget(covariant EditorNota oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nota.id != widget.nota.id) {
      final anterior = _texto;
      final historialAnterior = _historial;
      anterior.removeListener(_alEditarTexto);
      _prepararTexto();
      _coincidencia = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        anterior.dispose();
        historialAnterior.dispose();
        if (mounted && _desplazamientoEditor.hasClients) {
          _desplazamientoEditor.jumpTo(0);
        }
      });
    } else if (_texto.text != widget.nota.contenido) {
      // Los cambios externos reinician la base del historial de esta nota.
      _historial.separarGrupo();
      _ultimoContenido = widget.nota.contenido;
      final offset = _texto.selection.baseOffset.clamp(
        0,
        _ultimoContenido.length,
      );
      _restaurandoHistorial = true;
      _texto.value = TextEditingValue(
        text: _ultimoContenido,
        selection: TextSelection.collapsed(offset: offset),
      );
      _restaurandoHistorial = false;
      final historialAnterior = _historial;
      _historial = HistorialEdicion(_texto.value);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => historialAnterior.dispose(),
      );
      _coincidencia = 0;
    }
  }

  @override
  void dispose() {
    _texto.removeListener(_alEditarTexto);
    _texto.dispose();
    _historial.dispose();
    _consulta.dispose();
    _reemplazo.dispose();
    _focoBusqueda.dispose();
    _foco.dispose();
    _desplazamientoEditor.dispose();
    super.dispose();
  }

  void enfocarContenido() {
    if (_buscarVisible) {
      _focoBusqueda.requestFocus();
    } else if (widget.controller.modoEditor != ModoEditor.leer &&
        !widget.nota.eliminada) {
      _foco.requestFocus();
    }
  }

  Future<void> abrirAdjuntos() async {
    final id = widget.nota.id;
    await showDialog<void>(
      context: context,
      builder: (_) => DialogoAdjuntos(
        controlador: widget.controller,
        notaId: id,
        alInsertar: (adjuntos) {
          if (!mounted || widget.nota.id != id || widget.nota.eliminada) return;
          widget.controller.registrarAdjuntos(adjuntos);
          final seleccion = _texto.selection;
          final inicio = seleccion.isValid
              ? seleccion.start
              : _texto.text.length;
          final fin = seleccion.isValid ? seleccion.end : inicio;
          final enlaces =
              '\n\n${adjuntos.map((a) => a.markdown).join('\n\n')}\n\n';
          _aplicar(
            TextEditingValue(
              text: _texto.text.replaceRange(inicio, fin, enlaces),
              selection: TextSelection.collapsed(
                offset: inicio + enlaces.length,
              ),
            ),
            enfocar: false,
          );
        },
        alQuitar: (adjunto) {
          if (!mounted || widget.nota.id != id || widget.nota.eliminada) return;
          final patron = RegExp(
            r'!?\[(?:\\.|[^\]\\])*\]\(' + RegExp.escape(adjunto.enlace) + r'\)',
          );
          final texto = _texto.text
              .replaceAll(patron, '')
              .replaceAll(adjunto.enlace, adjunto.nombre);
          _aplicar(
            TextEditingValue(
              text: texto,
              selection: TextSelection.collapsed(
                offset: _texto.selection.baseOffset.clamp(0, texto.length),
              ),
            ),
            enfocar: false,
          );
        },
      ),
    );
  }

  void format(String apertura, String cierre, String relleno) {
    _aplicar(
      OperacionesMarkdown.rodear(_texto.value, apertura, cierre, t(relleno)),
    );
  }

  void _formatearLineas(FormatoLinea formato, String relleno) {
    _aplicar(
      OperacionesMarkdown.formatearLineas(_texto.value, formato, t(relleno)),
    );
  }

  void _aplicar(TextEditingValue valor, {bool enfocar = true}) {
    if (widget.nota.eliminada) return;
    if (widget.controller.modoEditor == ModoEditor.leer) {
      widget.controller.cambiarModoEditor(ModoEditor.editar);
    }
    _historial.separarGrupo();
    _texto.value = valor;
    _historial.separarGrupo();
    if (enfocar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _foco.requestFocus();
      });
    }
  }

  void _restaurarEdicion({bool rehacer = false}) {
    if (widget.nota.eliminada) return;
    final valor = rehacer ? _historial.rehacer() : _historial.deshacer();
    if (valor == null) return;
    _restaurandoHistorial = true;
    _texto.value = valor;
    _restaurandoHistorial = false;
  }

  void abrirBusqueda({bool reemplazar = false}) {
    if (!_buscarVisible &&
        _texto.selection.isValid &&
        !_texto.selection.isCollapsed) {
      final seleccion = _texto.selection.textInside(_texto.text);
      if (!seleccion.contains('\n') && seleccion.length <= 200) {
        _consulta.text = seleccion;
      }
    }
    _texto.buscar(_consulta.text, distinguirMayusculas: _distinguirMayusculas);
    if (!widget.nota.eliminada) {
      widget.controller.cambiarModoEditor(ModoEditor.editar);
    }
    setState(() {
      _buscarVisible = true;
      _mostrarReemplazo =
          !widget.nota.eliminada && (reemplazar || _mostrarReemplazo);
      _coincidencia = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focoBusqueda.requestFocus();
        _seleccionarCoincidencia(0);
      }
    });
  }

  void _cerrarBusqueda() {
    _texto.buscar('', distinguirMayusculas: _distinguirMayusculas);
    setState(() {
      _buscarVisible = false;
      _mostrarReemplazo = false;
    });
    _foco.requestFocus();
  }

  void _actualizarBusqueda() {
    _texto.buscar(_consulta.text, distinguirMayusculas: _distinguirMayusculas);
    setState(() => _coincidencia = 0);
    _seleccionarCoincidencia(0);
  }

  void siguienteCoincidencia({bool anterior = false}) {
    if (!_buscarVisible) {
      abrirBusqueda();
      return;
    }
    _seleccionarCoincidencia(_coincidencia + (anterior ? -1 : 1));
  }

  void _seleccionarCoincidencia(int indice) {
    final coincidencias = _texto.coincidencias;
    if (coincidencias.isEmpty) return;
    setState(() => _coincidencia = indice % coincidencias.length);
    final rango = coincidencias[_coincidencia];
    _texto.selection = TextSelection(
      baseOffset: rango.start,
      extentOffset: rango.end,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // EditableText expone el desplazamiento exacto al cursor, también con líneas largas.
      void visitar(Element elemento) {
        if (elemento is StatefulElement &&
            elemento.state is EditableTextState) {
          (elemento.state as EditableTextState).bringIntoView(
            TextPosition(offset: rango.start.clamp(0, _texto.text.length)),
          );
        } else {
          elemento.visitChildElements(visitar);
        }
      }

      _campoEdicion.currentContext?.visitChildElements(visitar);
    });
  }

  void _reemplazarCoincidencias({bool todas = false}) {
    if (widget.nota.eliminada || _texto.coincidencias.isEmpty) return;
    final coincidencias = _texto.coincidencias;
    final actual =
        coincidencias[_coincidencia.clamp(0, coincidencias.length - 1)];
    var contenido = _texto.text;
    if (todas) {
      // Recorrer desde el final conserva las posiciones y trata el reemplazo literalmente.
      for (final rango in coincidencias.reversed) {
        contenido = contenido.replaceRange(
          rango.start,
          rango.end,
          _reemplazo.text,
        );
      }
    } else {
      contenido = contenido.replaceRange(
        actual.start,
        actual.end,
        _reemplazo.text,
      );
    }
    final fin =
        (todas ? coincidencias.first.start : actual.start) +
        _reemplazo.text.length;
    _aplicar(
      TextEditingValue(
        text: contenido,
        selection: TextSelection.collapsed(offset: fin),
      ),
      enfocar: false,
    );
    final siguientes = _texto.coincidencias;
    final indice = siguientes.indexWhere((rango) => rango.start >= fin);
    _seleccionarCoincidencia(indice < 0 ? 0 : indice);
  }

  Widget _barraBusqueda() {
    final coincidencias = _texto.coincidencias;
    final hayCoincidencias = coincidencias.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('buscar-en-nota'),
                  controller: _consulta,
                  focusNode: _focoBusqueda,
                  decoration: InputDecoration(
                    hintText: t('Buscar en esta nota'),
                  ),
                  onChanged: (_) => _actualizarBusqueda(),
                  onSubmitted: (_) => siguienteCoincidencia(),
                ),
              ),
              IconButton(
                tooltip: t('Distinguir mayúsculas'),
                isSelected: _distinguirMayusculas,
                icon: const Icon(Icons.text_fields, size: 18),
                onPressed: () {
                  _distinguirMayusculas = !_distinguirMayusculas;
                  _actualizarBusqueda();
                },
              ),
              IconButton(
                tooltip: t('Cerrar búsqueda'),
                icon: const Icon(Icons.close, size: 18),
                onPressed: _cerrarBusqueda,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  t('{actual} de {total}', {
                    'actual': hayCoincidencias
                        ? _coincidencia.clamp(0, coincidencias.length - 1) + 1
                        : 0,
                    'total': coincidencias.length,
                  }),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              IconButton(
                tooltip: t('Coincidencia anterior'),
                icon: const Icon(Icons.keyboard_arrow_up),
                onPressed: hayCoincidencias
                    ? () => siguienteCoincidencia(anterior: true)
                    : null,
              ),
              IconButton(
                tooltip: t('Coincidencia siguiente'),
                icon: const Icon(Icons.keyboard_arrow_down),
                onPressed: hayCoincidencias ? siguienteCoincidencia : null,
              ),
              if (!widget.nota.eliminada)
                TextButton(
                  onPressed: () =>
                      setState(() => _mostrarReemplazo = !_mostrarReemplazo),
                  child: Text(t('Reemplazar')),
                ),
            ],
          ),
          if (_mostrarReemplazo && !widget.nota.eliminada)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('reemplazar-en-nota'),
                    controller: _reemplazo,
                    decoration: InputDecoration(hintText: t('Reemplazar por')),
                    onSubmitted: (_) => _reemplazarCoincidencias(),
                  ),
                ),
                IconButton(
                  tooltip: t('Reemplazar coincidencia'),
                  icon: const Icon(Icons.find_replace, size: 18),
                  onPressed: hayCoincidencias ? _reemplazarCoincidencias : null,
                ),
                IconButton(
                  tooltip: t('Reemplazar todas'),
                  icon: const Icon(Icons.done_all, size: 18),
                  onPressed: hayCoincidencias
                      ? () => _reemplazarCoincidencias(todas: true)
                      : null,
                ),
              ],
            ),
        ],
      ),
    );
  }

  void irAEncabezado(int offset) {
    widget.controller.cambiarModoEditor(ModoEditor.editar);
    _texto.selection = TextSelection.collapsed(
      offset: offset.clamp(0, _texto.text.length),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _foco.requestFocus();
      if (_desplazamientoEditor.hasClients) {
        final fraction =
            offset / (_texto.text.isEmpty ? 1 : _texto.text.length);
        _desplazamientoEditor.animateTo(
          _desplazamientoEditor.position.maxScrollExtent * fraction,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final nota = widget.nota;
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: widget.sinDistracciones ? 860 : double.infinity,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compacto = constraints.maxWidth < 580;
            final mode = nota.eliminada
                ? (_buscarVisible ? ModoEditor.editar : ModoEditor.leer)
                : c.modoEditor == ModoEditor.dividir &&
                      (widget.sinDistracciones || constraints.maxWidth < 700)
                ? ModoEditor.editar
                : c.modoEditor;
            final contenido = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.sinDistracciones)
                  Padding(
                    key: const Key('herramientas-nota'),
                    padding: EdgeInsets.symmetric(
                      horizontal: compacto ? 14 : 26,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.folder_open_outlined,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  nota.carpeta.isEmpty
                                      ? t('Mi bóveda')
                                      : nota.carpeta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!nota.eliminada) ...[
                          _botonModo(
                            context,
                            Icons.edit_outlined,
                            'Editar',
                            ModoEditor.editar,
                            mode,
                            compacto,
                          ),
                          if (constraints.maxWidth >= 700)
                            _botonModo(
                              context,
                              Icons.vertical_split_outlined,
                              'Dividir',
                              ModoEditor.dividir,
                              mode,
                              compacto,
                            ),
                          _botonModo(
                            context,
                            Icons.chrome_reader_mode_outlined,
                            'Leer',
                            ModoEditor.leer,
                            mode,
                            compacto,
                          ),
                        ],
                        IconButton(
                          tooltip: t('Buscar en esta nota (Ctrl/Cmd+F)'),
                          icon: const Icon(Icons.search, size: 18),
                          onPressed: abrirBusqueda,
                        ),
                        IconButton(
                          tooltip: t('Adjuntos'),
                          onPressed: abrirAdjuntos,
                          icon: Badge(
                            isLabelVisible: nota.idsAdjuntos.isNotEmpty,
                            label: Text('${nota.idsAdjuntos.length}'),
                            child: const Icon(Icons.attach_file, size: 18),
                          ),
                        ),
                        SizedBox(width: 5),
                        MenuContextual(
                          descripcion: t('Opciones de la nota'),
                          acciones: widget.acciones,
                        ),
                      ],
                    ),
                  ),
                if (!widget.sinDistracciones) Divider(),
                if (nota.eliminada)
                  MaterialBanner(
                    content: Text(t('Esta nota está en la papelera.')),
                    actions: [
                      TextButton(
                        onPressed: () => c.restaurarNota(nota.id),
                        child: Text(t('Restaurar')),
                      ),
                    ],
                  ),
                if (_buscarVisible) _barraBusqueda(),
                if (!widget.sinDistracciones &&
                    mode != ModoEditor.leer &&
                    !nota.eliminada)
                  SizedBox(
                    height: 43,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          ValueListenableBuilder<UndoHistoryValue>(
                            valueListenable: _historial,
                            builder: (context, valor, _) => Row(
                              children: [
                                IconButton(
                                  tooltip: t('Deshacer'),
                                  icon: const Icon(Icons.undo, size: 18),
                                  onPressed: valor.canUndo
                                      ? _restaurarEdicion
                                      : null,
                                ),
                                IconButton(
                                  tooltip: t('Rehacer'),
                                  icon: const Icon(Icons.redo, size: 18),
                                  onPressed: valor.canRedo
                                      ? () => _restaurarEdicion(rehacer: true)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          _botonFormato(
                            Icons.format_bold,
                            'Negrita (Ctrl/Cmd+B)',
                            '**',
                            '**',
                            'texto',
                          ),
                          _botonFormato(
                            Icons.format_italic,
                            'Cursiva (Ctrl/Cmd+I)',
                            '*',
                            '*',
                            'texto',
                          ),
                          _botonLineas(
                            Icons.title,
                            'Encabezado',
                            FormatoLinea.encabezado,
                            'Encabezado',
                          ),
                          SizedBox(
                            height: 18,
                            child: VerticalDivider(width: 20),
                          ),
                          _botonLineas(
                            Icons.format_list_bulleted,
                            'Lista',
                            FormatoLinea.lista,
                            'Elemento',
                          ),
                          _botonLineas(
                            Icons.format_list_numbered,
                            'Lista numerada',
                            FormatoLinea.listaNumerada,
                            'Elemento',
                          ),
                          _botonLineas(
                            Icons.check_box_outlined,
                            'Tarea',
                            FormatoLinea.tarea,
                            'Tarea',
                          ),
                          _botonLineas(
                            Icons.format_quote,
                            'Cita',
                            FormatoLinea.cita,
                            'Una idea para recordar',
                          ),
                          _botonFormato(
                            Icons.code,
                            'Código',
                            '`',
                            '`',
                            'código',
                          ),
                          _botonFormato(
                            Icons.link,
                            'Enlazar una nota',
                            '[[',
                            ']]',
                            'Título de la nota',
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: mode == ModoEditor.dividir
                      ? Row(
                          children: [
                            Expanded(child: _panelEdicion(context)),
                            VerticalDivider(width: 1),
                            Expanded(child: _vistaPrevia(context, compacto)),
                          ],
                        )
                      : mode == ModoEditor.leer
                      ? _vistaPrevia(context, compacto)
                      : _panelEdicion(context),
                ),
                if (!widget.sinDistracciones) Divider(),
                if (!widget.sinDistracciones)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    child: Row(
                      children: [
                        Text(
                          t('Markdown'),
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Spacer(),
                        Text(
                          t('{cantidad} palabras', {
                            'cantidad': nota.numeroPalabras,
                          }),
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (!compacto) ...[
                          SizedBox(width: 18),
                          Text(
                            t('{cantidad} caracteres', {
                              'cantidad': nota.contenido.characters.length,
                            }),
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
            final minimo = _buscarVisible
                ? 520.0
                : widget.sinDistracciones
                ? 180.0
                : 320.0;
            return CallbackShortcuts(
              bindings: {
                if (_buscarVisible)
                  const SingleActivator(LogicalKeyboardKey.escape):
                      _cerrarBusqueda,
              },
              child: constraints.maxHeight >= minimo
                  ? contenido
                  : SingleChildScrollView(
                      child: SizedBox(height: minimo, child: contenido),
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _botonModo(
    BuildContext context,
    IconData icon,
    String label,
    ModoEditor value,
    ModoEditor selected,
    bool compacto,
  ) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: EdgeInsets.only(left: 3),
      child: Tooltip(
        message: t(label),
        child: Material(
          color: value == selected
              ? color.withValues(alpha: .13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => widget.controller.cambiarModoEditor(value),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: value == selected ? color : null),
                  if (!compacto) ...[
                    SizedBox(width: 6),
                    Text(
                      t(label),
                      style: TextStyle(
                        fontSize: 11,
                        color: value == selected ? color : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _botonFormato(
    IconData icon,
    String tooltip,
    String before,
    String after,
    String placeholder,
  ) => IconButton(
    tooltip: t(tooltip),
    icon: Icon(icon, size: 18),
    onPressed: () => format(before, after, placeholder),
    visualDensity: VisualDensity.compact,
  );

  Widget _botonLineas(
    IconData icono,
    String etiqueta,
    FormatoLinea formato,
    String relleno,
  ) => IconButton(
    tooltip: t(etiqueta),
    icon: Icon(icono, size: 18),
    onPressed: () => _formatearLineas(formato, relleno),
    visualDensity: VisualDensity.compact,
  );

  Widget _titulo(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: InkWell(
          onTap: widget.nota.eliminada ? null : widget.alRenombrar,
          child: Text(
            widget.nota.titulo,
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w700,
              letterSpacing: -.8,
              height: 1.3,
            ),
          ),
        ),
      ),
      if (!widget.sinDistracciones && !widget.nota.eliminada)
        IconButton(
          tooltip: t(
            widget.nota.favorita ? 'Quitar de favoritas' : 'Añadir a favoritas',
          ),
          onPressed: () => widget.controller.alternarFavorita(widget.nota.id),
          icon: Icon(
            widget.nota.favorita
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            color: widget.nota.favorita
                ? Theme.of(context).colorScheme.primary
                : null,
            size: 21,
          ),
        ),
    ],
  );

  Widget _panelEdicion(BuildContext context) => Padding(
    key: _campoEdicion,
    padding: EdgeInsets.fromLTRB(26, 24, 26, 10),
    child: Column(
      children: [
        _titulo(context),
        SizedBox(height: 22),
        Expanded(
          child: KeyedSubtree(
            key: ValueKey('edicion-${widget.nota.id}'),
            child: CallbackShortcuts(
              // En web algunos atajos se delegan al navegador. El historial de
              // la nota debe recibirlos también después de un reemplazo.
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
                    _restaurarEdicion,
                const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
                    _restaurarEdicion,
                const SingleActivator(
                  LogicalKeyboardKey.keyZ,
                  control: true,
                  shift: true,
                ): () =>
                    _restaurarEdicion(rehacer: true),
                const SingleActivator(
                  LogicalKeyboardKey.keyZ,
                  meta: true,
                  shift: true,
                ): () =>
                    _restaurarEdicion(rehacer: true),
                const SingleActivator(
                  LogicalKeyboardKey.keyY,
                  control: true,
                ): () =>
                    _restaurarEdicion(rehacer: true),
              },
              child: Actions(
                actions: {
                  UndoTextIntent: CallbackAction<UndoTextIntent>(
                    onInvoke: (_) {
                      _restaurarEdicion();
                      return null;
                    },
                  ),
                  RedoTextIntent: CallbackAction<RedoTextIntent>(
                    onInvoke: (_) {
                      _restaurarEdicion(rehacer: true);
                      return null;
                    },
                  ),
                },
                child: TextField(
                  key: Key('markdown-editor'),
                  readOnly: widget.nota.eliminada,
                  controller: _texto,
                  focusNode: _foco,
                  scrollController: _desplazamientoEditor,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  autocorrect: false,
                  enableSuggestions: false,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 13,
                    height: 1.85,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: t(
                      'Empieza a escribir…\n\nUsa # para títulos y [[ para conectar ideas.',
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _vistaPrevia(BuildContext context, bool compacto) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    return SingleChildScrollView(
      key: PageStorageKey('preview-${widget.nota.id}'),
      padding: EdgeInsets.fromLTRB(
        compacto ? 24 : 48,
        32,
        compacto ? 24 : 48,
        60,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 730),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _titulo(context),
              if (!widget.sinDistracciones) SizedBox(height: 10),
              if (!widget.sinDistracciones)
                Text(
                  '${_fecha(widget.nota.modificadaEl)}  ·  ${t('{cantidad} palabras', {'cantidad': widget.nota.numeroPalabras})}',
                  style: TextStyle(
                    fontSize: 10,
                    color: color.onSurfaceVariant.withValues(alpha: .7),
                  ),
                ),
              SizedBox(height: 30),
              if (widget.nota.contenido.trim().isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 50),
                  child: Text(
                    t(
                      'Todo empieza con una idea.\nPulsa Editar para escribir la tuya.',
                    ),
                    style: TextStyle(
                      color: color.onSurfaceVariant,
                      height: 1.8,
                    ),
                  ),
                ),
              MarkdownBody(
                data: widget.nota.contenido,
                selectable: true,
                extensionSet: md.ExtensionSet.gitHubFlavored,
                inlineSyntaxes: [SintaxisEnlaceInterno()],
                imageBuilder: (uri, titulo, alternativa) {
                  if (uri.scheme == 'adjunto') {
                    final adjunto = widget.controller.adjuntoPorId(uri.path);
                    if (adjunto == null) {
                      return Text(t('Adjunto no disponible.'));
                    }
                    return InkWell(
                      onTap: () => mostrarAdjunto(context, adjunto),
                      child: Image.memory(
                        adjunto.bytes,
                        fit: BoxFit.contain,
                        semanticLabel: alternativa ?? adjunto.nombre,
                        errorBuilder: (_, _, _) => TextButton.icon(
                          onPressed: () => mostrarAdjunto(context, adjunto),
                          icon: const Icon(Icons.image_outlined),
                          label: Text(adjunto.nombre),
                        ),
                      ),
                    );
                  }
                  if (uri.scheme == 'https' || uri.scheme == 'http') {
                    return Image.network(
                      uri.toString(),
                      semanticLabel: alternativa,
                      errorBuilder: (_, _, _) => Text(
                        alternativa ??
                            t('No hay vista previa para este archivo.'),
                      ),
                    );
                  }
                  return Text(
                    alternativa ?? t('No hay vista previa para este archivo.'),
                  );
                },
                onTapLink: (label, href, title) => _abrirEnlace(href),
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: TextStyle(
                    fontSize: 14,
                    height: 1.85,
                    color: color.onSurface.withValues(alpha: .85),
                  ),
                  h1: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.7,
                    height: 1.5,
                  ),
                  h2: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.3,
                    height: 1.7,
                  ),
                  h3: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.7,
                  ),
                  h2Padding: EdgeInsets.only(top: 18, bottom: 8),
                  h3Padding: EdgeInsets.only(top: 12, bottom: 5),
                  blockSpacing: 16,
                  listBullet: TextStyle(fontSize: 14, color: color.primary),
                  a: TextStyle(
                    color: color.primary,
                    decoration: TextDecoration.none,
                  ),
                  code: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12,
                    color: color.primary,
                    backgroundColor: color.primary.withValues(alpha: .07),
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: color.primary.withValues(alpha: .055),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  codeblockPadding: EdgeInsets.all(18),
                  blockquote: TextStyle(
                    color: color.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                    fontSize: 14,
                    height: 1.8,
                  ),
                  blockquoteDecoration: BoxDecoration(
                    color: color.primary.withValues(alpha: .055),
                    border: Border(
                      left: BorderSide(color: color.primary, width: 3),
                    ),
                  ),
                  blockquotePadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  horizontalRuleDecoration: BoxDecoration(
                    border: Border(top: BorderSide(color: theme.dividerColor)),
                  ),
                  tableBorder: TableBorder.all(color: theme.dividerColor),
                  tableCellsPadding: EdgeInsets.all(10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirEnlace(String? href) async {
    if (href == null) return;
    if (href.startsWith('adjunto:')) {
      final adjunto = widget.controller.adjuntoPorId(href.substring(8));
      if (adjunto == null) {
        _mensaje('Adjunto no disponible.');
      } else {
        await mostrarAdjunto(context, adjunto);
      }
      return;
    }
    if (href.startsWith('glosala:')) {
      widget.controller.abrirEnlaceInterno(
        Uri.decodeComponent(href.substring(8)),
      );
      return;
    }
    final uri = Uri.tryParse(href);
    if (uri == null || !{'https', 'http', 'mailto'}.contains(uri.scheme)) {
      _mensaje(
        'Este enlace no se puede abrir. Usa [[Título]] para enlazar una nota.',
      );
      return;
    }
    try {
      if (!await launchUrl(uri)) _mensaje('No se ha podido abrir el enlace.');
    } catch (_) {
      _mensaje('No se ha podido abrir el enlace.');
    }
  }

  void _mensaje(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  String _fecha(DateTime fecha) =>
      MaterialLocalizations.of(context).formatMediumDate(fecha.toLocal());
}
