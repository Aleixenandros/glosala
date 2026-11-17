// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

import '../../idiomas/gestor_idiomas.dart';

class BotonReproduccion extends StatelessWidget {
  const BotonReproduccion({
    super.key,
    required this.reproduciendo,
    this.alPulsar,
  });
  final bool reproduciendo;
  final VoidCallback? alPulsar;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      label: t(reproduciendo ? 'Pausar' : 'Reproducir'),
      child: Tooltip(
        message: t('Reproducir / Pausar'),
        excludeFromSemantics: true,
        child: IconButton(
          onPressed: alPulsar,
          icon: Icon(reproduciendo ? Icons.pause : Icons.play_arrow),
        ),
      ),
    ),
  );
}
