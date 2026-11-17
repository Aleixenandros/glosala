import 'dart:convert';

import 'package:dio/dio.dart';

class DocumentoRemoto {
  const DocumentoRemoto(this.contenido, this.version);
  final String? contenido;
  final String? version;
}

abstract interface class TransporteSincronizacion {
  Future<DocumentoRemoto> leer();
  Future<void> escribir(String contenido, String? versionAnterior);
  void cerrar();
}

class TransporteWebDav implements TransporteSincronizacion {
  TransporteWebDav(
    String direccion,
    String usuario,
    String contrasena, {
    Dio? cliente,
  }) : _cliente =
           cliente ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(minutes: 3),
               sendTimeout: const Duration(minutes: 3),
             ),
           ) {
    final uri = Uri.parse(direccion.trim());
    if (!{'https', 'http'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'Introduce la URL de una carpeta WebDAV existente.',
      );
    }
    _direccion =
        '${direccion.trim().replaceFirst(RegExp(r'/+$'), '')}/glosala-boveda.json';
    if (usuario.isNotEmpty || contrasena.isNotEmpty) {
      _cabeceras['Authorization'] =
          'Basic ${base64Encode(utf8.encode('$usuario:$contrasena'))}';
    }
  }
  final Dio _cliente;
  late final String _direccion;
  final Map<String, dynamic> _cabeceras = {};

  @override
  Future<DocumentoRemoto> leer() async {
    final respuesta = await _cliente.get<String>(
      _direccion,
      options: Options(
        headers: _cabeceras,
        responseType: ResponseType.plain,
        followRedirects: false,
        validateStatus: (estado) => estado == 200 || estado == 404,
      ),
    );
    if (respuesta.statusCode == 404) return const DocumentoRemoto(null, null);
    final etiqueta = respuesta.headers.value('etag');
    if (etiqueta == null || etiqueta.startsWith('W/')) {
      throw StateError(
        'El servidor debe ofrecer ETag fuerte para evitar sobrescribir cambios de otro dispositivo.',
      );
    }
    return DocumentoRemoto(respuesta.data!, etiqueta);
  }

  @override
  Future<void> escribir(String contenido, String? versionAnterior) async {
    await _cliente.put<void>(
      _direccion,
      data: contenido,
      options: Options(
        contentType: 'application/json; charset=utf-8',
        followRedirects: false,
        headers: {
          ..._cabeceras,
          if (versionAnterior == null)
            'If-None-Match': '*'
          else
            'If-Match': versionAnterior,
        },
        validateStatus: (estado) =>
            estado == 200 || estado == 201 || estado == 204,
      ),
    );
  }

  @override
  void cerrar() => _cliente.close();
}
