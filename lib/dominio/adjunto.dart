import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mime/mime.dart';

/// Copia inmutable del archivo. La identidad incluye el nombre y los bytes,
/// de modo que dos dispositivos nunca sobrescriben un adjunto diferente.
class Adjunto {
  Adjunto._(this.id, this.nombre, this.bytes, this.tipoMime);

  static const maximoBytes = 100 * 1024 * 1024;
  static const maximoBovedaBytes = 512 * 1024 * 1024;
  final String id;
  final String nombre;
  final Uint8List bytes;
  final String tipoMime;

  factory Adjunto.crear(String nombre, Uint8List contenido) {
    if (contenido.length > maximoBytes) {
      throw const FormatException('El archivo supera el límite de 100 MB.');
    }
    var seguro = nombre
        .split(RegExp(r'[/\\]'))
        .last
        .replaceAll(RegExp(r'[<>:"|?*\x00-\x1F\x7F]'), '_')
        .replaceAll(RegExp(r'[. ]+$'), '')
        .trim();
    if (RegExp(
      r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
      caseSensitive: false,
    ).hasMatch(seguro)) {
      seguro = 'archivo-$seguro';
    }
    if (seguro.isEmpty || utf8.encode(seguro).length > 180) {
      throw const FormatException('El nombre del archivo no es válido.');
    }
    final bytes = Uint8List.fromList(contenido).asUnmodifiableView();
    final extension = lookupMimeType(seguro);
    final detectado = lookupMimeType(
      seguro,
      headerBytes: bytes.take(32).toList(),
    );
    // ZIP también contiene documentos Office/OpenDocument; WebM y MP4 pueden
    // contener audio o vídeo. Su extensión distingue el uso del contenedor.
    final tipo = extension ?? detectado;
    return Adjunto._(
      _huella(seguro, bytes),
      seguro,
      bytes,
      tipo ?? 'application/octet-stream',
    );
  }

  static String _huella(String nombre, Uint8List bytes) {
    final salida = _ReceptorHuella<Digest>();
    final calculo = sha256.startChunkedConversion(salida);
    calculo.add(utf8.encode(nombre));
    calculo.add([0]);
    calculo.add(bytes);
    calculo.close();
    return salida.valores.single.toString();
  }

  static void validarId(String id) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(id)) {
      throw const FormatException('Identificador de adjunto no válido.');
    }
  }

  bool get esImagen => tipoMime.startsWith('image/');
  bool get esAudio => tipoMime.startsWith('audio/');
  bool get esVideo => tipoMime.startsWith('video/');
  String get enlace => 'adjunto:$id';
  String get rutaExportada => 'adjuntos/$id/$nombre';
  String get enlaceExportado =>
      Uri(path: rutaExportada)
          .toString()
          .replaceAll('(', '%28')
          .replaceAll(')', '%29');
  String get markdown {
    final etiqueta = nombre.replaceAllMapped(
      RegExp(r'[\\\[\]]'),
      (coincidencia) => '\\${coincidencia[0]}',
    );
    return '${esImagen ? '!' : ''}[$etiqueta]($enlace)';
  }

  Map<String, Object?> aJson({bool incluirDatos = true}) => {
    'id': id,
    'name': nombre,
    'size': bytes.length,
    if (incluirDatos) 'data': base64Encode(bytes),
  };

  factory Adjunto.desdeJson(Map<String, dynamic> json, {Uint8List? bytes}) {
    final id = json['id'] as String;
    validarId(id);
    final fuente = json['data'] as String?;
    if (bytes == null &&
        (fuente == null || fuente.length > ((maximoBytes + 2) ~/ 3) * 4)) {
      throw const FormatException('Contenido del adjunto no válido.');
    }
    final adjunto = Adjunto.crear(
      json['name'] as String,
      bytes ?? base64Decode(fuente!),
    );
    if (adjunto.id != id || adjunto.bytes.length != json['size']) {
      throw const FormatException('El adjunto está incompleto o dañado.');
    }
    return adjunto;
  }
}

/// Evita concatenar los archivos grandes para calcular su huella.
class _ReceptorHuella<T> implements Sink<T> {
  final valores = <T>[];
  @override
  void add(T dato) => valores.add(dato);
  @override
  void close() {}
}
