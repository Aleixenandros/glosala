import 'nota.dart';
import 'tarea.dart';
import 'adjunto.dart';

class Boveda {
  const Boveda({
    required this.notas,
    this.carpetas = const [],
    this.idSeleccionada,
    this.modoOscuro = true,
    this.tareas = const [],
    this.preferencias = const {},
    this.adjuntos = const [],
  });

  final List<Nota> notas;
  final List<String> carpetas;
  final String? idSeleccionada;
  final bool modoOscuro;
  final List<Tarea> tareas;
  final Map<String, dynamic> preferencias;
  final List<Adjunto> adjuntos;

  Map<String, Object?> aJson({
    bool incluirNotas = true,
    bool incluirDatosAdjuntos = true,
  }) => {
    'version': adjuntos.isEmpty ? 1 : 2,
    if (incluirNotas) 'notes': notas.map((nota) => nota.aJson()).toList(),
    'folders': carpetas,
    'selectedId': idSeleccionada,
    'darkMode': modoOscuro,
    'tareas': tareas.map((tarea) => tarea.aJson()).toList(),
    'preferencias': preferencias,
    if (adjuntos.isNotEmpty)
      'attachments': adjuntos
          .map((a) => a.aJson(incluirDatos: incluirDatosAdjuntos))
          .toList(),
  };

  factory Boveda.desdeJson(
    Map<String, dynamic> json, {
    List<Adjunto>? adjuntosCargados,
  }) {
    if (json['version'] != 1 && json['version'] != 2) {
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
    final adjuntos = <Adjunto>[];
    var tamano = 0;
    for (final dato in adjuntosCargados ?? json['attachments'] as List? ?? []) {
      final adjunto = dato is Adjunto
          ? dato
          : Adjunto.desdeJson(Map<String, dynamic>.from(dato as Map));
      tamano += adjunto.bytes.length;
      if (tamano > Adjunto.maximoBovedaBytes) {
        throw const FormatException(
          'La bóveda supera el límite de 512 MB de adjuntos.',
        );
      }
      adjuntos.add(adjunto);
    }
    if (adjuntos.map((a) => a.id).toSet().length != adjuntos.length) {
      throw const FormatException('La bóveda contiene adjuntos repetidos.');
    }
    return Boveda(
      notas: notas,
      adjuntos: adjuntos,
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
