// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

import '../../dominio/nota.dart';
import '../../idiomas/gestor_idiomas.dart';
import 'controles_ventana.dart';

class PestanasNotas extends StatefulWidget {
  const PestanasNotas({
    super.key,
    required this.notas,
    required this.seleccionada,
    required this.alSeleccionar,
    required this.alCerrar,
  });
  final List<Nota> notas;
  final String? seleccionada;
  final ValueChanged<String> alSeleccionar;
  final ValueChanged<String> alCerrar;

  @override
  State<PestanasNotas> createState() => _EstadoPestanasNotas();
}

class _EstadoPestanasNotas extends State<PestanasNotas> {
  final _scroll = ScrollController();
  double _anchoPestana = 190;
  double? _anchoDisponible;

  @override
  void initState() {
    super.initState();
    _mostrarSeleccionada();
  }

  @override
  void didUpdateWidget(PestanasNotas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seleccionada != widget.seleccionada ||
        oldWidget.notas.length != widget.notas.length) {
      _mostrarSeleccionada();
    }
  }

  void _mostrarSeleccionada() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final indice = widget.notas.indexWhere(
        (n) => n.id == widget.seleccionada,
      );
      if (indice < 0) return;
      final inicio = indice * _anchoPestana;
      final anchoVisible = _scroll.position.viewportDimension;
      final fin = inicio + _anchoPestana;
      final destino = inicio < _scroll.offset
          ? inicio
          : fin > _scroll.offset + anchoVisible
          ? fin - anchoVisible
          : _scroll.offset;
      _scroll.jumpTo(destino.clamp(0, _scroll.position.maxScrollExtent));
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      if (_anchoDisponible != limites.maxWidth) {
        _anchoDisponible = limites.maxWidth;
        // En móvil, evitar que asome solo el cierre de la pestaña anterior.
        _anchoPestana = limites.maxWidth < 380
            ? limites.maxWidth.clamp(80.0, 380.0)
            : 190;
        _mostrarSeleccionada();
      }
      final tema = Theme.of(context);
      final lista = ListView.builder(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        itemExtent: _anchoPestana,
        itemCount: widget.notas.length,
        itemBuilder: (context, indice) {
          final nota = widget.notas[indice];
          final seleccionada = widget.seleccionada == nota.id;
          return Semantics(
            selected: seleccionada,
            child: Container(
              key: ValueKey('pestana-${nota.id}'),
              decoration: BoxDecoration(
                color: seleccionada
                    ? tema.colorScheme.primary.withValues(alpha: .08)
                    : null,
                border: Border(
                  right: BorderSide(color: tema.dividerColor),
                  bottom: BorderSide(
                    color: seleccionada
                        ? tema.colorScheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: InkWell(
                onTap: () => widget.alSeleccionar(nota.id),
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined, size: 13),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Tooltip(
                          message: nota.titulo,
                          child: Text(
                            nota.titulo,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: t('Cerrar {titulo}', {'titulo': nota.titulo}),
                        onPressed: () => widget.alCerrar(nota.id),
                        icon: const Icon(Icons.close, size: 13),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
      final anchoLista = (widget.notas.length * _anchoPestana).clamp(
        0.0,
        limites.maxWidth,
      );
      return Row(
        children: [
          SizedBox(width: anchoLista, child: lista),
          if (anchoLista < limites.maxWidth)
            const Expanded(
              child: ZonaArrastreVentana(
                child: SizedBox(key: Key('espacio-libre-pestanas'), height: 44),
              ),
            ),
        ],
      );
    },
  );
}
