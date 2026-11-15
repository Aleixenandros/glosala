import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'transporte.dart';

TransporteSincronizacion crearTransporteCarpeta(String ruta) =>
    TransporteCarpeta(ruta);

class TransporteCarpeta implements TransporteSincronizacion {
  TransporteCarpeta(this.ruta);
  final String ruta;
  File get _archivo => File(p.join(ruta, 'glosala-boveda.json'));

  @override
  Future<DocumentoRemoto> leer() async {
    if (!await Directory(ruta).exists()) {
      throw const FileSystemException(
        'La carpeta de sincronización no está disponible.',
      );
    }
    if (!await _archivo.exists()) return const DocumentoRemoto(null, null);
    final contenido = await _archivo.readAsString();
    return DocumentoRemoto(
      contenido,
      sha256.convert(utf8.encode(contenido)).toString(),
    );
  }

  @override
  Future<void> escribir(String contenido, String? versionAnterior) async {
    final bloqueo = await File(p.join(ruta, '.glosala-bloqueo'))
        .open(mode: FileMode.append);
    var bloqueado = false;
    try {
      await bloqueo.lock(FileLock.exclusive);
      bloqueado = true;
      final actual = await leer();
      if (actual.version != versionAnterior) {
        throw StateError(
          'Otra instancia ha modificado la bóveda. Vuelve a sincronizar.',
        );
      }
      final temporal = File('${_archivo.path}.tmp');
      await temporal.writeAsString(contenido, flush: true);
      await temporal.rename(_archivo.path);
    } finally {
      if (bloqueado) await bloqueo.unlock();
      await bloqueo.close();
    }
  }

  @override
  void cerrar() {}
}
