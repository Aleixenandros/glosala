import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../dominio/adjunto.dart';
import 'recurso_adjunto.dart';

Future<RecursoAdjunto> prepararAdjunto(Adjunto adjunto) async {
  final blob = web.Blob(
    [adjunto.bytes.toJS].toJS,
    web.BlobPropertyBag(type: adjunto.tipoMime),
  );
  final uri = web.URL.createObjectURL(blob);
  return RecursoAdjunto(uri, () async => web.URL.revokeObjectURL(uri));
}

Future<void> abrirDocumento(Adjunto adjunto) async {
  final recurso = await prepararAdjunto(adjunto);
  final enlace = web.HTMLAnchorElement()
    ..href = recurso.uri
    ..target = '_blank'
    ..rel = 'noopener noreferrer';
  enlace.click();
  // Dar tiempo al visor PDF de la pestaña nueva para consumir el Blob.
  Future<void>.delayed(const Duration(minutes: 1), recurso.liberar);
}
