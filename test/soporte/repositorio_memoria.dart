import 'dart:convert';

import 'package:glosala/datos/repositorio_boveda.dart';
import 'package:glosala/dominio/boveda.dart';

class RepositorioMemoria implements RepositorioBoveda {
  Boveda? guardada;
  bool fallar = false;
  int escrituras = 0;
  @override
  String get location => 'Memoria de pruebas';
  @override
  Future<Boveda?> cargar() async => guardada;
  @override
  Future<void> guardar(Boveda boveda) async {
    if (fallar) throw StateError('Disco lleno');
    await Future<void>.value();
    guardada = Boveda.desdeJson(
      jsonDecode(jsonEncode(boveda.aJson())) as Map<String, dynamic>,
    );
    escrituras++;
  }

  @override
  Future<void> cerrar() async {}
}
