import '../dominio/boveda.dart';

abstract interface class RepositorioBoveda {
  String get location;
  Future<Boveda?> cargar();
  Future<void> guardar(Boveda boveda);
  Future<void> cerrar();
}
