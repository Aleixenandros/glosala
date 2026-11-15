// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

/// Búsqueda literal y resaltado sin modificar el Markdown ni su composición IME.
class ControladorTextoNota extends TextEditingController {
  ControladorTextoNota({super.text});
  String _consulta = '';
  bool _distinguirMayusculas = false;
  String? _textoAnalizado;
  List<TextRange> _coincidencias = [];

  void buscar(String consulta, {required bool distinguirMayusculas}) {
    _consulta = consulta;
    _distinguirMayusculas = distinguirMayusculas;
    _textoAnalizado = null;
    notifyListeners();
  }

  List<TextRange> get coincidencias {
    if (_textoAnalizado != text) {
      _textoAnalizado = text;
      _coincidencias = _consulta.isEmpty
          ? []
          : RegExp(
                  RegExp.escape(_consulta),
                  caseSensitive: _distinguirMayusculas,
                  unicode: true,
                )
                .allMatches(text)
                .map((m) => TextRange(start: m.start, end: m.end))
                .toList();
    }
    return List.unmodifiable(_coincidencias);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if ((withComposing &&
            value.composing.isValid &&
            !value.composing.isCollapsed) ||
        coincidencias.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final resaltado = TextStyle(
      backgroundColor: Theme.of(context).colorScheme.primary
          .withValues(alpha: .25),
    );
    final fragmentos = <TextSpan>[];
    var inicio = 0;
    for (final coincidencia in coincidencias) {
      fragmentos.add(
        TextSpan(text: text.substring(inicio, coincidencia.start)),
      );
      fragmentos.add(
        TextSpan(
          text: text.substring(coincidencia.start, coincidencia.end),
          style: resaltado,
        ),
      );
      inicio = coincidencia.end;
    }
    fragmentos.add(TextSpan(text: text.substring(inicio)));
    return TextSpan(style: style, children: fragmentos);
  }
}
