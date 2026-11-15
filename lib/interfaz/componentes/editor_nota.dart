import '../../idiomas/gestor_idiomas.dart';
// Compatibilidad con el renderizador Markdown hasta su migración a material_ui.
// ignore_for_file: deprecated_member_use

import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../aplicacion/controlador_boveda.dart';
import '../../dominio/nota.dart';

class EditorNota extends StatefulWidget {
  const EditorNota({
    super.key,
    required this.nota,
    required this.controller,
    required this.alRenombrar,
    required this.alExportar,
    required this.alMover,
    required this.alEnviarPapelera,
  });
  final Nota nota;
  final ControladorBoveda controller;
  final VoidCallback alRenombrar;
  final VoidCallback alExportar;
  final VoidCallback alMover;
  final VoidCallback alEnviarPapelera;

  @override
  State<EditorNota> createState() => EstadoEditorNota();
}

class EstadoEditorNota extends State<EditorNota> {
  late final TextEditingController _texto;
  final _foco = FocusNode();
  final _desplazamientoEditor = ScrollController();

  @override
  void initState() {
    super.initState();
    _texto = TextEditingController(text: widget.nota.contenido);
  }

  @override
  void didUpdateWidget(covariant EditorNota oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_texto.text != widget.nota.contenido) {
      final offset = oldWidget.nota.id == widget.nota.id
          ? _texto.selection.baseOffset.clamp(0, widget.nota.contenido.length)
          : 0;
      _texto.value = TextEditingValue(
        text: widget.nota.contenido,
        selection: TextSelection.collapsed(offset: offset),
      );
      if (oldWidget.nota.id != widget.nota.id &&
          _desplazamientoEditor.hasClients) {
        _desplazamientoEditor.jumpTo(0);
      }
    }
  }

  @override
  void dispose() {
    _texto.dispose();
    _foco.dispose();
    _desplazamientoEditor.dispose();
    super.dispose();
  }

  void format(String before, String after, String placeholder) {
    if (widget.nota.eliminada) return;
    if (widget.controller.modoEditor == ModoEditor.leer) {
      widget.controller.cambiarModoEditor(ModoEditor.editar);
    }
    final selection = _texto.selection;
    final start = selection.isValid ? selection.start : _texto.text.length;
    final end = selection.isValid ? selection.end : start;
    final selected = start == end
        ? placeholder
        : _texto.text.substring(start, end);
    final replacement = '$before$selected$after';
    _texto.value = TextEditingValue(
      text: _texto.text.replaceRange(start, end, replacement),
      selection: TextSelection(
        baseOffset: start + before.length,
        extentOffset: start + before.length + selected.length,
      ),
    );
    widget.controller.actualizarContenido(widget.nota.id, _texto.text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _foco.requestFocus();
    });
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compacto = constraints.maxWidth < 580;
        final mode = nota.eliminada
            ? ModoEditor.leer
            : c.modoEditor == ModoEditor.dividir && constraints.maxWidth < 700
            ? ModoEditor.editar
            : c.modoEditor;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
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
                  SizedBox(width: 5),
                  PopupMenuButton<String>(
                    tooltip: t('Opciones de la nota'),
                    icon: Icon(Icons.more_horiz, size: 20),
                    onSelected: (value) {
                      switch (value) {
                        case 'rename':
                          widget.alRenombrar();
                        case 'move':
                          widget.alMover();
                        case 'export':
                          widget.alExportar();
                        case 'trash':
                          widget.alEnviarPapelera();
                      }
                    },
                    itemBuilder: (_) => [
                      if (!nota.eliminada)
                        PopupMenuItem(
                          value: 'rename',
                          child: Text(t('Renombrar')),
                        ),
                      if (!nota.eliminada)
                        PopupMenuItem(
                          value: 'move',
                          child: Text(t('Mover a carpeta')),
                        ),
                      PopupMenuItem(
                        value: 'export',
                        child: Text(t('Exportar notas')),
                      ),
                      if (!nota.eliminada)
                        PopupMenuItem(
                          value: 'trash',
                          child: Text(t('Mover a la papelera')),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(),
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
            if (mode != ModoEditor.leer)
              SizedBox(
                height: 43,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
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
                      _botonFormato(
                        Icons.title,
                        'Encabezado',
                        '\n## ',
                        '',
                        'Encabezado',
                      ),
                      SizedBox(height: 18, child: VerticalDivider(width: 20)),
                      _botonFormato(
                        Icons.format_list_bulleted,
                        'Lista',
                        '\n- ',
                        '',
                        'Elemento',
                      ),
                      _botonFormato(
                        Icons.check_box_outlined,
                        'Tarea',
                        '\n- [ ] ',
                        '',
                        'Tarea',
                      ),
                      _botonFormato(
                        Icons.format_quote,
                        'Cita',
                        '\n> ',
                        '',
                        'Una idea para recordar',
                      ),
                      _botonFormato(Icons.code, 'Código', '`', '`', 'código'),
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
            Divider(),
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
                    t('{cantidad} palabras', {'cantidad': nota.numeroPalabras}),
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
      },
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
      if (!widget.nota.eliminada)
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
    padding: EdgeInsets.fromLTRB(26, 24, 26, 10),
    child: Column(
      children: [
        _titulo(context),
        SizedBox(height: 22),
        Expanded(
          child: TextField(
            key: Key('markdown-editor'),
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
            onChanged: (value) =>
                widget.controller.actualizarContenido(widget.nota.id, value),
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
              SizedBox(height: 10),
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

  String _fecha(DateTime date) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final local = date.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}
