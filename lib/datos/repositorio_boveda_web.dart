import 'dart:convert';
import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';

import '../dominio/boveda.dart';
import '../dominio/adjunto.dart';
import 'repositorio_boveda.dart';

Future<RepositorioBoveda> crearRepositorioBoveda() async {
  // Nunca sustituir silenciosamente el almacenamiento persistente por memoria.
  final baseDatos = await idbFactoryWeb.open(
    'glosala',
    version: 2,
    onUpgradeNeeded: (event) {
      if (event.oldVersion < 1) event.database.createObjectStore('workspace');
      if (event.oldVersion < 2) event.database.createObjectStore('attachments');
    },
  );
  return RepositorioBovedaWeb(baseDatos);
}

class RepositorioBovedaWeb implements RepositorioBoveda {
  RepositorioBovedaWeb(this.baseDatos);
  final Database baseDatos;
  final Set<String> _adjuntosGuardados = {};

  @override
  String get location => 'IndexedDB · almacenamiento de este navegador';

  @override
  Future<Boveda?> cargar() async {
    final transaccion = baseDatos.transactionList([
      'workspace',
      'attachments',
    ], idbModeReadOnly);
    final fuente = await transaccion
        .objectStore('workspace')
        .getObject('vault');
    if (fuente == null) {
      await transaccion.completed;
      return null;
    }
    final json = Map<String, dynamic>.from(jsonDecode(fuente as String) as Map);
    final adjuntos = <Adjunto>[];
    for (final valor in json['attachments'] as List? ?? []) {
      final metadatos = Map<String, dynamic>.from(valor as Map);
      final bytes = await transaccion
          .objectStore('attachments')
          .getObject(metadatos['id']);
      if (bytes is! List<int>) {
        throw const FormatException('Faltan los datos de un adjunto.');
      }
      adjuntos.add(
        Adjunto.desdeJson(metadatos, bytes: Uint8List.fromList(bytes)),
      );
    }
    await transaccion.completed;
    final boveda = Boveda.desdeJson(json, adjuntosCargados: adjuntos);
    _adjuntosGuardados.addAll(adjuntos.map((a) => a.id));
    return boveda;
  }

  @override
  Future<void> guardar(Boveda boveda) async {
    final transaccion = baseDatos.transactionList([
      'workspace',
      'attachments',
    ], idbModeReadWrite);
    final nuevos = boveda.adjuntos
        .where((a) => !_adjuntosGuardados.contains(a.id))
        .toList();
    // Atender también el error de la transacción cuando se agota la cuota.
    final escrituras = <Future<dynamic>>[transaccion.completed];
    for (final adjunto in nuevos) {
      escrituras.add(
        transaccion.objectStore('attachments').put(adjunto.bytes, adjunto.id),
      );
    }
    escrituras.add(
      transaccion
          .objectStore('workspace')
          .put(jsonEncode(boveda.aJson(incluirDatosAdjuntos: false)), 'vault'),
    );
    await Future.wait(escrituras);
    _adjuntosGuardados.addAll(nuevos.map((a) => a.id));
  }

  @override
  Future<void> cerrar() async => baseDatos.close();
}
