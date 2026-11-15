import 'dart:convert';

import 'package:idb_shim/idb_browser.dart';

import '../dominio/boveda.dart';
import 'repositorio_boveda.dart';

Future<RepositorioBoveda> crearRepositorioBoveda() async {
  // Nunca sustituir silenciosamente el almacenamiento persistente por memoria.
  final baseDatos = await idbFactoryWeb.open(
    'glosala',
    version: 1,
    onUpgradeNeeded: (event) => event.database.createObjectStore('workspace'),
  );
  return RepositorioBovedaWeb(baseDatos);
}

class RepositorioBovedaWeb implements RepositorioBoveda {
  RepositorioBovedaWeb(this.baseDatos);
  final Database baseDatos;

  @override
  String get location => 'IndexedDB · almacenamiento de este navegador';

  @override
  Future<Boveda?> cargar() async {
    final transaccion = baseDatos.transaction('workspace', idbModeReadOnly);
    final fuente = await transaccion
        .objectStore('workspace')
        .getObject('vault');
    await transaccion.completed;
    return fuente == null
        ? null
        : Boveda.desdeJson(
            Map<String, dynamic>.from(jsonDecode(fuente as String) as Map),
          );
  }

  @override
  Future<void> guardar(Boveda boveda) async {
    final transaccion = baseDatos.transaction('workspace', idbModeReadWrite);
    await transaccion
        .objectStore('workspace')
        .put(jsonEncode(boveda.aJson()), 'vault');
    await transaccion.completed;
  }

  @override
  Future<void> cerrar() async => baseDatos.close();
}
