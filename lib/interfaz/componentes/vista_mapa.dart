import '../../idiomas/gestor_idiomas.dart';
// Compatibilidad con el renderizador Markdown hasta su migración a material_ui.
// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../aplicacion/controlador_boveda.dart';

class VistaMapa extends StatelessWidget {
  const VistaMapa({super.key, required this.controller});
  final ControladorBoveda controller;

  @override
  Widget build(BuildContext context) {
    final notas = controller.notasActivas;
    final color = Theme.of(context).colorScheme;
    final side = math.max(700.0, math.sqrt(notas.length) * 240);
    final center = Offset(side / 2, side / 2);
    final posiciones = <String, Offset>{};
    for (var i = 0; i < notas.length; i++) {
      final angle = i * math.pi * (3 - math.sqrt(5));
      final radius = i == 0 ? 0.0 : 130.0 * math.sqrt(i);
      posiciones[notas[i].id] =
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    }
    final aristas = <(Offset, Offset)>[];
    for (final nota in notas) {
      for (final link in nota.enlaces) {
        final destino = controller.notaPorTitulo(link);
        if (destino != null && destino.id != nota.id) {
          aristas.add((posiciones[nota.id]!, posiciones[destino.id]!));
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('Tus ideas, conectadas.'),
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.7,
                ),
              ),
              SizedBox(height: 8),
              Text(
                t(
                  '{notas} notas · {enlaces} enlaces. Toca una nota para abrirla.',
                  {'notas': notas.length, 'enlaces': aristas.length},
                ),
                style: TextStyle(fontSize: 12, color: color.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Expanded(
          child: notas.isEmpty
              ? Center(child: Text(t('Crea una nota para empezar tu mapa.')))
              : LayoutBuilder(
                  builder: (context, constraints) => InteractiveViewer(
                    constrained: false,
                    minScale: .25,
                    maxScale: 2.5,
                    boundaryMargin: EdgeInsets.all(250),
                    transformationController: null,
                    child: SizedBox(
                      width: side,
                      height: side,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _PintorMapa(
                                aristas,
                                color.primary.withValues(alpha: .22),
                              ),
                            ),
                          ),
                          for (final nota in notas)
                            Positioned(
                              left: posiciones[nota.id]!.dx - 72,
                              top: posiciones[nota.id]!.dy - 27,
                              width: 144,
                              height: 70,
                              child: InkWell(
                                onTap: () =>
                                    controller.seleccionarNota(nota.id),
                                borderRadius: BorderRadius.circular(16),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 17,
                                      height: 17,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: color.primary,
                                        boxShadow: [
                                          BoxShadow(
                                            color: color.primary.withValues(
                                              alpha: .2,
                                            ),
                                            blurRadius: 16,
                                            spreadRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 9),
                                    Text(
                                      nota.titulo,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _PintorMapa extends CustomPainter {
  _PintorMapa(this.aristas, this.color);
  final List<(Offset, Offset)> aristas;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.3;
    for (final (from, to) in aristas) {
      canvas.drawLine(from - Offset(0, 18.5), to - Offset(0, 18.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PintorMapa oldDelegate) =>
      oldDelegate.aristas != aristas || oldDelegate.color != color;
}
