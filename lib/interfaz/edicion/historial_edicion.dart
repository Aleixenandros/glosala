import 'package:flutter/widgets.dart';

/// Historial acotado de la nota abierta. Conserva el estado inicial incluso si
/// se escribe inmediatamente, y agrupa pulsaciones cercanas en una sola acción.
class HistorialEdicion extends ValueNotifier<UndoHistoryValue> {
  HistorialEdicion(TextEditingValue inicial)
    : _actual = inicial,
      super(UndoHistoryValue.empty);

  TextEditingValue _actual;
  final _anteriores = <TextEditingValue>[];
  final _posteriores = <TextEditingValue>[];
  DateTime? _ultimaEdicion;

  void separarGrupo() => _ultimaEdicion = null;

  void registrar(TextEditingValue valor) {
    final limpio = valor.copyWith(composing: TextRange.empty);
    if (_actual.text == valor.text) {
      if (_actual.selection != valor.selection) separarGrupo();
      _actual = limpio;
      return;
    }
    final ahora = DateTime.now();
    if (_ultimaEdicion == null ||
        ahora.difference(_ultimaEdicion!).inMilliseconds > 500) {
      _anteriores.add(_actual);
      if (_anteriores.length > 100) _anteriores.removeAt(0);
    }
    _ultimaEdicion = ahora;
    _actual = limpio;
    _posteriores.clear();
    _notificar();
  }

  TextEditingValue? deshacer() {
    if (_anteriores.isEmpty) return null;
    _posteriores.add(_actual);
    _actual = _anteriores.removeLast();
    separarGrupo();
    _notificar();
    return _actual;
  }

  TextEditingValue? rehacer() {
    if (_posteriores.isEmpty) return null;
    _anteriores.add(_actual);
    _actual = _posteriores.removeLast();
    separarGrupo();
    _notificar();
    return _actual;
  }

  void _notificar() => value = UndoHistoryValue(
    canUndo: _anteriores.isNotEmpty,
    canRedo: _posteriores.isNotEmpty,
  );
}
