import '../../idiomas/gestor_idiomas.dart';
// Compatibilidad con el renderizador Markdown hasta su migración a material_ui.
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'menu_contextual.dart';

import '../../aplicacion/controlador_boveda.dart';
import '../../dominio/nota.dart';
import '../tema_aplicacion.dart';

class PanelBoveda extends StatefulWidget {
  const PanelBoveda({
    super.key,
    required this.controller,
    required this.alCrear,
    required this.alCrearCarpeta,
    required this.alImportar,
    required this.alSeleccionar,
    required this.alAbrirOpciones,
    required this.accionesNotas,
    required this.accionesCarpeta,
  });
  final ControladorBoveda controller;
  final VoidCallback alCrear;
  final VoidCallback alCrearCarpeta;
  final VoidCallback alImportar;
  final VoidCallback alAbrirOpciones;
  final ValueChanged<Nota> alSeleccionar;
  final List<Widget> Function(List<Nota>) accionesNotas;
  final List<Widget> Function(String) accionesCarpeta;

  @override
  State<PanelBoveda> createState() => _EstadoPanelBoveda();
}

class _EstadoPanelBoveda extends State<PanelBoveda> {
  final _buscador = TextEditingController();
  bool _modoSeleccion = false;

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final theme = Theme.of(context);
    final visibles = c.notasVisibles;
    final marcadas = c.notasMarcadas;
    final idsMarcadas = marcadas.map((nota) => nota.id).toSet();
    final seleccionando = _modoSeleccion || marcadas.isNotEmpty;
    if (_buscador.text != c.busqueda) {
      _buscador.value = TextEditingValue(
        text: c.busqueda,
        selection: TextSelection.collapsed(offset: c.busqueda.length),
      );
    }
    final panel = ColoredBox(
      color: TemaAplicacion.sidebar(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 23, 14, 20),
            child: Row(
              children: [
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.auto_stories_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('Glosala'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.5,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        t('Tu espacio para pensar'),
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF8D899A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: widget.alCrear,
              icon: Icon(Icons.add, size: 18),
              label: Text(t('Nueva nota')),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              key: Key('sidebar-search'),
              controller: _buscador,
              onChanged: c.cambiarBusqueda,
              style: TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: t('Buscar en tus notas…'),
                prefixIcon: Icon(Icons.search_rounded, size: 18),
                suffixIcon: c.busqueda.isEmpty
                    ? null
                    : IconButton(
                        tooltip: t('Limpiar búsqueda'),
                        icon: Icon(Icons.close, size: 16),
                        onPressed: () => c.cambiarBusqueda(''),
                      ),
              ),
            ),
          ),
          _navegacion(
            context,
            Icons.notes_rounded,
            t('Todas las notas'),
            c.filtro == FiltroNotas.todas && c.carpeta == null && c.tag == null,
            () => c.cambiarFiltro(FiltroNotas.todas),
            count: c.notasActivas.length,
          ),
          _navegacion(
            context,
            Icons.star_outline_rounded,
            t('Favoritas'),
            c.filtro == FiltroNotas.favoritas,
            () => c.cambiarFiltro(FiltroNotas.favoritas),
            count: c.notasActivas.where((n) => n.favorita).length,
          ),
          _navegacion(
            context,
            Icons.delete_outline_rounded,
            t('Papelera'),
            c.filtro == FiltroNotas.papelera,
            () => c.cambiarFiltro(FiltroNotas.papelera),
            count: c.notas.where((n) => n.eliminada).length,
          ),
          SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 190),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 22, right: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            t('CARPETAS'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.4,
                              color: Color(0xFF8D899A),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: t('Nueva carpeta'),
                          onPressed: widget.alCrearCarpeta,
                          icon: Icon(
                            Icons.create_new_folder_outlined,
                            size: 17,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  for (final carpeta in c.carpetas)
                    MenuContextual(
                      key: ValueKey('carpeta-$carpeta'),
                      descripcion: t('Acciones de {titulo}', {
                        'titulo': carpeta,
                      }),
                      acciones: widget.accionesCarpeta(carpeta),
                      construir: (boton) => _navegacion(
                        context,
                        Icons.folder_outlined,
                        carpeta,
                        c.carpeta == carpeta,
                        () => c.cambiarFiltro(
                          FiltroNotas.todas,
                          enCarpeta: carpeta,
                        ),
                        compacto: true,
                        adicional: boton,
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12),
          Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (seleccionando) ...[
                  IconButton(
                    tooltip: t('Seleccionar todas'),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.select_all, size: 18),
                    onPressed: c.marcarTodasVisibles,
                  ),
                  Expanded(
                    child: Text(
                      t('{cantidad} seleccionadas', {
                        'cantidad': marcadas.length,
                      }),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  if (marcadas.isNotEmpty)
                    MenuContextual(
                      descripcion: t('Acciones de la selección'),
                      acciones: widget.accionesNotas(marcadas),
                    ),
                ] else ...[
                  Expanded(
                    child: Text(
                      c.busqueda.isNotEmpty
                          ? t('RESULTADOS')
                          : c.tag != null
                          ? '#${c.tag}'
                          : t('NOTAS'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  Text(
                    '${visibles.length}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
                PopupMenuButton<OrdenNotas>(
                  tooltip: t('Ordenar notas'),
                  icon: const Icon(Icons.sort, size: 18),
                  initialValue: c.ordenNotas,
                  onSelected: c.cambiarOrdenNotas,
                  itemBuilder: (_) => [
                    for (final entrada in {
                      OrdenNotas.modificadas: 'Última modificación',
                      OrdenNotas.creadas: 'Creación más reciente',
                      OrdenNotas.tituloAscendente: 'Título: A–Z',
                      OrdenNotas.tituloDescendente: 'Título: Z–A',
                    }.entries)
                      CheckedPopupMenuItem(
                        value: entrada.key,
                        checked: c.ordenNotas == entrada.key,
                        child: Text(t(entrada.value)),
                      ),
                  ],
                ),
                IconButton(
                  tooltip: t(
                    seleccionando ? 'Cancelar selección' : 'Seleccionar notas',
                  ),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    seleccionando ? Icons.close : Icons.checklist,
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() => _modoSeleccion = !seleccionando);
                    if (seleccionando) c.limpiarSeleccion();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyA, control: true):
                    c.marcarTodasVisibles,
                const SingleActivator(LogicalKeyboardKey.keyA, meta: true):
                    c.marcarTodasVisibles,
                const SingleActivator(LogicalKeyboardKey.escape): () {
                  setState(() => _modoSeleccion = false);
                  c.limpiarSeleccion();
                },
              },
              child: visibles.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          t(
                            'No hay notas aquí.\nPrueba otra búsqueda o crea una nueva.',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8D899A),
                            height: 1.8,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      itemCount: visibles.length,
                      itemBuilder: (context, index) {
                        final nota = visibles[index];
                        final selected =
                            c.notaSeleccionada?.id == nota.id && !c.mapaVisible;
                        final marcada = idsMarcadas.contains(nota.id);
                        return MenuContextual(
                          key: ValueKey('nota-${nota.id}'),
                          descripcion: t('Acciones de {titulo}', {
                            'titulo': nota.titulo,
                          }),
                          acciones: widget.accionesNotas(
                            marcada ? marcadas : [nota],
                          ),
                          construir: (boton) => Padding(
                            padding: EdgeInsets.only(bottom: 5),
                            child: Material(
                              color: (selected || marcada)
                                  ? theme.colorScheme.primary.withValues(
                                      alpha: .12,
                                    )
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  final teclado = HardwareKeyboard.instance;
                                  if (_modoSeleccion ||
                                      teclado.isControlPressed ||
                                      teclado.isMetaPressed ||
                                      teclado.isShiftPressed) {
                                    c.marcarNota(
                                      nota.id,
                                      rango: teclado.isShiftPressed,
                                      acumular:
                                          !teclado.isShiftPressed ||
                                          teclado.isControlPressed ||
                                          teclado.isMetaPressed,
                                    );
                                  } else {
                                    c.limpiarSeleccion();
                                    widget.alSeleccionar(nota);
                                  }
                                },
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (seleccionando)
                                        SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: Checkbox(
                                            value: marcada,
                                            semanticLabel: t(
                                              'Seleccionar {titulo}',
                                              {'titulo': nota.titulo},
                                            ),
                                            onChanged: (_) =>
                                                c.marcarNota(nota.id),
                                          ),
                                        )
                                      else
                                        Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Icon(
                                            Icons.description_outlined,
                                            size: 16,
                                            color: selected
                                                ? theme.colorScheme.primary
                                                : null,
                                          ),
                                        ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              nota.titulo,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: selected
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                                color: selected
                                                    ? theme.colorScheme.primary
                                                    : null,
                                              ),
                                            ),
                                            SizedBox(height: 5),
                                            Text(
                                              nota.extracto.isEmpty
                                                  ? t('Una página en blanco')
                                                  : nota.extracto,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant
                                                    .withValues(alpha: .6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (nota.favorita)
                                        Padding(
                                          padding: EdgeInsets.only(left: 5),
                                          child: Icon(
                                            Icons.star_rounded,
                                            size: 12,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      boton,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          if (c.etiquetas.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                height: 29,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: c.etiquetas
                      .map(
                        (tag) => Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(
                              '#$tag',
                              style: TextStyle(fontSize: 10),
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            side: BorderSide.none,
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: c.tag == tag ? .22 : .07),
                            onPressed: () => c.cambiarFiltro(
                              FiltroNotas.todas,
                              conEtiqueta: tag,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          Divider(),
          Padding(
            padding: EdgeInsets.fromLTRB(18, 9, 10, 9),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 13,
                  color: theme.colorScheme.primary,
                ),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    t('Bóveda local'),
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                IconButton(
                  tooltip: t('Importar Markdown'),
                  onPressed: widget.alImportar,
                  icon: Icon(Icons.file_upload_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: t('Ajustes'),
                  onPressed: widget.alAbrirOpciones,
                  icon: Icon(Icons.tune_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    // Mantener accesible la búsqueda al reducirse el espacio por el teclado.
    return LayoutBuilder(
      builder: (context, limites) => SingleChildScrollView(
        child: SizedBox(
          height: limites.maxHeight < 720 ? 720 : limites.maxHeight,
          child: panel,
        ),
      ),
    );
  }

  Widget _navegacion(
    BuildContext context,
    IconData icon,
    String label,
    bool selected,
    VoidCallback onTap, {
    int? count,
    bool compacto = false,
    Widget? adicional,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: Material(
        color: selected ? primary.withValues(alpha: .09) : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: compacto ? 2 : 10,
            ),
            child: Row(
              children: [
                Icon(icon, size: 17, color: selected ? primary : null),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? primary : null,
                    ),
                  ),
                ),
                ?adicional,
                if (count != null)
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      color: selected ? primary : Color(0xFF8D899A),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
