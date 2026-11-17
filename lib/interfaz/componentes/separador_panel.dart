// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../idiomas/gestor_idiomas.dart';

class SeparadorPanel extends StatefulWidget {
  const SeparadorPanel({
    super.key,
    required this.ancho,
    required this.minimo,
    required this.maximo,
    required this.alCambiar,
    required this.alTerminar,
  });

  final double ancho;
  final double minimo;
  final double maximo;
  final ValueChanged<double> alCambiar;
  final VoidCallback alTerminar;

  @override
  State<SeparadorPanel> createState() => _EstadoSeparadorPanel();
}

class _EstadoSeparadorPanel extends State<SeparadorPanel> {
  final _foco = FocusNode();
  bool _resaltado = false;
  bool _enfocado = false;
  double _arrastre = 0;

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  void _ajustar(double valor, {bool terminar = false}) {
    widget.alCambiar(valor.clamp(widget.minimo, widget.maximo));
    if (terminar) widget.alTerminar();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    slider: true,
    label: t('Ajustar ancho de la bóveda'),
    value: '${widget.ancho.round()} px',
    increasedValue:
        '${(widget.ancho + 16).clamp(widget.minimo, widget.maximo).round()} px',
    decreasedValue:
        '${(widget.ancho - 16).clamp(widget.minimo, widget.maximo).round()} px',
    onIncrease: () => _ajustar(widget.ancho + 16, terminar: true),
    onDecrease: () => _ajustar(widget.ancho - 16, terminar: true),
    child: Focus(
      focusNode: _foco,
      onFocusChange: (valor) => setState(() => _enfocado = valor),
      onKeyEvent: (_, evento) {
        if (evento is! KeyDownEvent && evento is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final tecla = evento.logicalKey;
        if (tecla != LogicalKeyboardKey.arrowLeft &&
            tecla != LogicalKeyboardKey.arrowRight) {
          return KeyEventResult.ignored;
        }
        _ajustar(
          widget.ancho + (tecla == LogicalKeyboardKey.arrowRight ? 16 : -16),
          terminar: true,
        );
        return KeyEventResult.handled;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        onEnter: (_) => setState(() => _resaltado = true),
        onExit: (_) => setState(() => _resaltado = false),
        child: Tooltip(
          message: t(
            'Arrastra para ajustar el ancho. Doble clic para restablecer.',
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _foco.requestFocus,
            onDoubleTap: () => _ajustar(256, terminar: true),
            onHorizontalDragStart: (_) {
              _foco.requestFocus();
              _arrastre = widget.ancho;
            },
            onHorizontalDragUpdate: (evento) {
              _arrastre = (_arrastre + evento.delta.dx).clamp(
                widget.minimo,
                widget.maximo,
              );
              _ajustar(_arrastre);
            },
            onHorizontalDragEnd: (_) => widget.alTerminar(),
            onHorizontalDragCancel: widget.alTerminar,
            child: SizedBox(
              width: 6,
              child: Center(
                child: Container(
                  width: _resaltado || _enfocado ? 3 : 1,
                  color: _resaltado || _enfocado
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).dividerColor,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
