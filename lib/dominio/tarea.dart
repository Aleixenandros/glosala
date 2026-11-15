class Tarea {
  const Tarea({
    required this.id,
    required this.titulo,
    this.completada = false,
    this.subtareas = const [],
  });
  final String id;
  final String titulo;
  final bool completada;
  final List<Tarea> subtareas;

  Tarea copiar({String? titulo, bool? completada, List<Tarea>? subtareas}) =>
      Tarea(
        id: id,
        titulo: titulo ?? this.titulo,
        completada: completada ?? this.completada,
        subtareas: subtareas ?? this.subtareas,
      );

  Map<String, dynamic> aJson() => {
    'id': id,
    'titulo': titulo,
    'completada': completada,
    'subtareas': subtareas.map((tarea) => tarea.aJson()).toList(),
  };

  factory Tarea.desdeJson(Map<String, dynamic> datos) => Tarea(
    id: datos['id'] as String,
    titulo: datos['titulo'] as String,
    completada: datos['completada'] as bool? ?? false,
    subtareas: (datos['subtareas'] as List? ?? [])
        .map((dato) => Tarea.desdeJson(Map<String, dynamic>.from(dato as Map)))
        .toList(),
  );
}
