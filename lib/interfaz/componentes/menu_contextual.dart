// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Abre las acciones con botón derecho, pulsación larga o un botón accesible.
class MenuContextual extends StatefulWidget {
  const MenuContextual({
    super.key,
    required this.acciones,
    required this.descripcion,
    this.construir,
  });

  final List<Widget> acciones;
  final String descripcion;
  final Widget Function(Widget boton)? construir;

  @override
  State<MenuContextual> createState() => _EstadoMenuContextual();
}

class _EstadoMenuContextual extends State<MenuContextual> {
  final _foco = FocusNode();

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MenuAnchor(
    consumeOutsideTap: true,
    childFocusNode: _foco,
    useRootOverlay: true,
    menuChildren: widget.acciones,
    builder: (context, controlador, _) {
      final boton = IconButton(
        tooltip: widget.descripcion,
        focusNode: _foco,
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.more_horiz, size: 18),
        onPressed: () =>
            controlador.isOpen ? controlador.close() : controlador.open(),
      );
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.contextMenu): () =>
              controlador.open(),
          const SingleActivator(LogicalKeyboardKey.f10, shift: true): () =>
              controlador.open(),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onSecondaryTapDown: (detalles) =>
              controlador.open(position: detalles.localPosition),
          onLongPressStart: (detalles) =>
              controlador.open(position: detalles.localPosition),
          child: widget.construir?.call(boton) ?? boton,
        ),
      );
    },
  );
}
