import 'package:dio/dio.dart';

const versionAplicacion = '0.2.1';
const repositorioProyecto = 'https://github.com/Aleixenandros/glosala';

class Actualizacion {
  const Actualizacion(this.version, this.direccion, this.disponible);
  final String version;
  final Uri direccion;
  final bool disponible;
}

class ServicioActualizaciones {
  Future<Actualizacion?> comprobar() async {
    final cliente = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    try {
      final respuesta = await cliente.get<Map<String, dynamic>>(
        'https://api.github.com/repos/Aleixenandros/glosala/releases/latest',
        options: Options(
          headers: {'Accept': 'application/vnd.github+json'},
          validateStatus: (estado) => estado == 200 || estado == 404,
        ),
      );
      if (respuesta.statusCode == 404) return null;
      final datos = respuesta.data!;
      final version = (datos['tag_name'] as String).replaceFirst(
        RegExp('^v'),
        '',
      );
      final direccion = Uri.parse(datos['html_url'] as String);
      if (direccion.scheme != 'https' || direccion.host != 'github.com') {
        throw const FormatException('Dirección de actualización no válida.');
      }
      return Actualizacion(
        version,
        direccion,
        esMasReciente(version, versionAplicacion),
      );
    } finally {
      cliente.close();
    }
  }

  static bool esMasReciente(String candidata, String actual) {
    List<int> partes(String valor) => valor
        .split('+')
        .first
        .split('-')
        .first
        .split('.')
        .map(int.parse)
        .toList();
    final nueva = partes(candidata);
    final instalada = partes(actual);
    for (var i = 0; i < 3; i++) {
      final a = i < nueva.length ? nueva[i] : 0;
      final b = i < instalada.length ? instalada[i] : 0;
      if (a != b) return a > b;
    }
    return actual.contains('-') && !candidata.contains('-');
  }
}
