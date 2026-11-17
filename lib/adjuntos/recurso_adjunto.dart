import '../dominio/adjunto.dart';
import 'recurso_adjunto_nativo.dart'
    if (dart.library.js_interop) 'recurso_adjunto_web.dart'
    as plataforma;

class RecursoAdjunto {
  const RecursoAdjunto(this.uri, this.liberar);
  final String uri;
  final Future<void> Function() liberar;
}

Future<RecursoAdjunto> prepararAdjunto(Adjunto adjunto) =>
    plataforma.prepararAdjunto(adjunto);
Future<void> abrirDocumento(Adjunto adjunto) =>
    plataforma.abrirDocumento(adjunto);
