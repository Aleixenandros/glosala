import 'package:flutter_test/flutter_test.dart';
import 'package:glosala/actualizaciones/servicio_actualizaciones.dart';

void main() {
  test('Compara versiones semánticas numéricamente', () {
    expect(ServicioActualizaciones.esMasReciente('0.10.0', '0.9.9'), isTrue);
    expect(ServicioActualizaciones.esMasReciente('1.0.0', '0.99.0'), isTrue);
    expect(ServicioActualizaciones.esMasReciente('0.1.0', '0.1.0'), isFalse);
    expect(ServicioActualizaciones.esMasReciente('0.1.0', '0.2.0'), isFalse);
  });
}
