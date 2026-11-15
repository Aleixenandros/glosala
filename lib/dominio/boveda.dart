import 'nota.dart';
import 'tarea.dart';

class Boveda {
  const Boveda({
    required this.notas,
    this.carpetas = const [],
    this.idSeleccionada,
    this.modoOscuro = true,
    this.tareas = const [],
    this.preferencias = const {},
  });

  final List<Nota> notas;
  final List<String> carpetas;
  final String? idSeleccionada;
  final bool modoOscuro;
  final List<Tarea> tareas;
  final Map<String, dynamic> preferencias;

  Map<String, Object?> aJson({bool incluirNotas = true}) => {
    'version': 1,
    if (incluirNotas) 'notes': notas.map((nota) => nota.aJson()).toList(),
    'folders': carpetas,
    'selectedId': idSeleccionada,
    'darkMode': modoOscuro,
    'tareas': tareas.map((tarea) => tarea.aJson()).toList(),
    'preferencias': preferencias,
  };

  factory Boveda.desdeJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Versión de bóveda no compatible.');
    }
    final notas = (json['notes'] as List? ?? [])
        .map((value) => Nota.desdeJson(Map<String, dynamic>.from(value as Map)))
        .toList();
    if (notas.map((nota) => nota.id).toSet().length != notas.length) {
      throw const FormatException(
        'La bóveda contiene identificadores repetidos.',
      );
    }
    return Boveda(
      notas: notas,
      carpetas: (json['folders'] as List? ?? []).cast<String>(),
      idSeleccionada: json['selectedId'] as String?,
      modoOscuro: json['darkMode'] as bool? ?? true,
      tareas: (json['tareas'] as List? ?? [])
          .map(
            (dato) => Tarea.desdeJson(Map<String, dynamic>.from(dato as Map)),
          )
          .toList(),
      preferencias: Map<String, dynamic>.from(
        json['preferencias'] as Map? ?? {},
      ),
    );
  }
}
