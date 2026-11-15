import 'package:markdown/markdown.dart' as md;

class Nota {
  const Nota({
    required this.id,
    required this.titulo,
    required this.contenido,
    required this.creadaEl,
    required this.modificadaEl,
    this.carpeta = '',
    this.favorita = false,
    this.eliminada = false,
  });

  final String id;
  final String titulo;
  final String contenido;
  final DateTime creadaEl;
  final DateTime modificadaEl;
  final String carpeta;
  final bool favorita;
  final bool eliminada;

  int get numeroPalabras => RegExp(r'\S+').allMatches(contenido).length;

  List<String> get etiquetas =>
      RegExp(r'(?:^|\s)#([\p{L}\p{N}_/-]+)', unicode: true)
          .allMatches(_sinCodigo(contenido))
          .map((match) => match[1]!)
          .toSet()
          .toList()
        ..sort();

  List<String> get enlaces => SintaxisEnlaceInterno.destinos(contenido);

  List<({String text, int level, int offset})> get encabezados {
    final fuente = _sinCodigo(contenido);
    return RegExp(r'^(#{1,6}) +(.+)$', multiLine: true)
        .allMatches(fuente)
        .map(
          (match) => (
            text: match[2]!.replaceFirst(RegExp(r' +#+\s*$'), ''),
            level: match[1]!.length,
            offset: match.start,
          ),
        )
        .toList();
  }

  String get extracto => contenido
      .replaceAll(RegExp(r'[#*_>`\[\]]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Nota copiar({
    String? titulo,
    String? contenido,
    String? carpeta,
    bool? favorita,
    bool? eliminada,
    DateTime? modificadaEl,
  }) => Nota(
    id: id,
    titulo: titulo ?? this.titulo,
    contenido: contenido ?? this.contenido,
    creadaEl: creadaEl,
    modificadaEl: modificadaEl ?? this.modificadaEl,
    carpeta: carpeta ?? this.carpeta,
    favorita: favorita ?? this.favorita,
    eliminada: eliminada ?? this.eliminada,
  );

  Map<String, Object?> aJson({bool incluirContenido = true}) => {
    'id': id,
    'title': titulo,
    if (incluirContenido) 'content': contenido,
    'folder': carpeta,
    'createdAt': creadaEl.toIso8601String(),
    'updatedAt': modificadaEl.toIso8601String(),
    'isFavorite': favorita,
    'isDeleted': eliminada,
  };

  factory Nota.desdeJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      throw const FormatException('Identificador de nota no válido.');
    }
    return Nota(
      id: id,
      titulo: json['title'] as String,
      contenido: json['content'] as String? ?? '',
      carpeta: json['folder'] as String? ?? '',
      creadaEl: DateTime.parse(json['createdAt'] as String),
      modificadaEl: DateTime.parse(json['updatedAt'] as String),
      favorita: json['isFavorite'] as bool? ?? false,
      eliminada: json['isDeleted'] as bool? ?? false,
    );
  }
}

/// Sustituye el código por espacios y conserva posiciones para navegar por el índice.
String _sinCodigo(String value) {
  String blank(Match match) => match[0]!.replaceAll(RegExp(r'[^\n]'), ' ');
  return value
      .replaceAllMapped(
        RegExp(
          r'^ {0,3}(`{3,}|~{3,})[^\n]*\n[\s\S]*?^ {0,3}\1[^\n]*(?:\n|$)',
          multiLine: true,
        ),
        blank,
      )
      .replaceAllMapped(RegExp(r'(`+)[^`\n]*?\1'), blank);
}

class SintaxisEnlaceInterno extends md.InlineSyntax {
  SintaxisEnlaceInterno() : super(r'\[\[([^\]\n]+)\]\]');

  static String renombrarDestino(
    String fuente,
    String oldTitle,
    String newTitle,
  ) {
    final searchable = _sinCodigo(fuente);
    return fuente.replaceAllMapped(RegExp(r'\[\[([^\]\n]+)\]\]'), (match) {
      if (searchable.substring(match.start, match.end).trim().isEmpty) {
        return match[0]!;
      }
      final parts = match[1]!.split('|');
      if (parts.first.trim().toLowerCase() != oldTitle.toLowerCase()) {
        return match[0]!;
      }
      return '[[$newTitle${parts.length > 1 ? '|${parts.sublist(1).join('|')}' : ''}]]';
    });
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final parts = match[1]!.split('|');
    final destino = parts.first.trim();
    final label = parts.length > 1
        ? parts.sublist(1).join('|').trim()
        : destino;
    final element = md.Element.text('a', label);
    element.attributes['href'] = 'glosala:${Uri.encodeComponent(destino)}';
    parser.addNode(element);
    return true;
  }

  static List<String> destinos(String fuente) =>
      RegExp(r'\[\[([^\]\n]+)\]\]')
          .allMatches(_sinCodigo(fuente))
          .map((match) => match[1]!.split('|').first.trim())
          .where((destino) => destino.isNotEmpty)
          .toSet()
          .toList();
}
