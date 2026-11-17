import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../dominio/adjunto.dart';
import 'recurso_adjunto.dart';

Future<File> _copiaTemporal(Adjunto adjunto) async {
  final temporal = await getTemporaryDirectory();
  final carpeta = await Directory(
    p.join(temporal.path, 'glosala-adjuntos', adjunto.id),
  ).create(recursive: true);
  final archivo = File(p.join(carpeta.path, 'adjunto-${adjunto.nombre}'));
  await archivo.writeAsBytes(adjunto.bytes, flush: true);
  return archivo;
}

Future<RecursoAdjunto> prepararAdjunto(Adjunto adjunto) async {
  final archivo = await _copiaTemporal(adjunto);
  // La caché puede estar siendo usada por una aplicación externa.
  return RecursoAdjunto(archivo.uri.toString(), () async {});
}

Future<void> abrirDocumento(Adjunto adjunto) async {
  final archivo = await _copiaTemporal(adjunto);
  final resultado = await OpenFilex.open(archivo.path, type: adjunto.tipoMime);
  if (resultado.type != ResultType.done) {
    throw StateError(
      'No se ha podido abrir el archivo. Guarda una copia para abrirlo con otra aplicación.',
    );
  }
}
