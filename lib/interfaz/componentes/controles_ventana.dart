// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

import '../../idiomas/gestor_idiomas.dart';
import '../ventana_escritorio.dart';

class ZonaArrastreVentana extends StatelessWidget {
  const ZonaArrastreVentana({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ventana = VentanaEscritorio.instancia;
    if (!ventana.activa) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => ventana.arrastrar(),
      onDoubleTap: ventana.alternarMaximizada,
      child: child,
    );
  }
}

class ControlesVentana extends StatelessWidget {
  const ControlesVentana({super.key});

  @override
  Widget build(BuildContext context) {
    final ventana = VentanaEscritorio.instancia;
    return ListenableBuilder(
      listenable: ventana,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _boton(context, 'Minimizar', Icons.remove, ventana.minimizar),
          _boton(
            context,
            ventana.maximizada ? 'Restaurar ventana' : 'Maximizar',
            ventana.maximizada ? Icons.filter_none : Icons.crop_square,
            ventana.alternarMaximizada,
          ),
          _boton(context, 'Cerrar', Icons.close, ventana.cerrar, cerrar: true),
        ],
      ),
    );
  }

  Widget _boton(
    BuildContext context,
    String titulo,
    IconData icono,
    VoidCallback accion, {
    bool cerrar = false,
  }) => Tooltip(
    message: t(titulo),
    child: SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: accion,
        style: IconButton.styleFrom(
          shape: const RoundedRectangleBorder(),
          hoverColor: cerrar
              ? Theme.of(context).colorScheme.errorContainer
              : null,
        ),
        icon: Icon(icono, size: 16, semanticLabel: t(titulo)),
      ),
    ),
  );
}
