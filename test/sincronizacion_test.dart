import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glosala/aplicacion/controlador_boveda.dart';
import 'package:glosala/dominio/boveda.dart';
import 'package:glosala/dominio/nota.dart';
import 'package:glosala/sincronizacion/servicio_sincronizacion.dart';
import 'package:glosala/sincronizacion/transporte.dart';
import 'package:glosala/sincronizacion/transporte_carpeta_nativo.dart';

import 'soporte/repositorio_memoria.dart';

Nota nota(String contenido) => Nota(
  id: 'compartida',
  titulo: 'Compartida',
  contenido: contenido,
  creadaEl: DateTime(2026),
  modificadaEl: DateTime(2026),
);

void main() {
  test(
    'La mezcla propaga cambios remotos sin perder ediciones concurrentes',
    () {
      final base = nota('base');
      final remota = nota('remota');
      final local = nota('local');
      final huellas = {base.id: huellaNota(base)};
      expect(
        mezclarNotas([base], [remota], huellas).notas.single.contenido,
        'remota',
      );
      expect(
        mezclarNotas([local], [base], huellas).notas.single.contenido,
        'local',
      );
      final conflicto = mezclarNotas([local], [remota], huellas);
      expect(conflicto.conflictos, 1);
      expect(
        conflicto.notas.map((n) => n.contenido),
        containsAll(['local', 'remota']),
      );
      expect(
        mezclarNotas(conflicto.notas, [remota], huellas).notas,
        hasLength(2),
      );
    },
  );

  test('WebDAV real usa autorización y precondiciones; no sobrescribe un ETag nuevo', () async {
    final servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? contenido;
    var version = 0;
    servidor.listen((peticion) async {
      expect(peticion.uri.path, '/boveda/glosala-boveda.json');
      expect(
        peticion.headers.value('authorization'),
        'Basic ${base64Encode(utf8.encode('ana:secreto'))}',
      );
      if (peticion.method == 'GET') {
        peticion.response.statusCode = contenido == null ? 404 : 200;
        if (contenido != null) {
          peticion.response.headers.set('etag', '"$version"');
          peticion.response.write(contenido);
        }
      } else {
        final nueva = await utf8.decoder.bind(peticion).join();
        final coincide = contenido == null
            ? peticion.headers.value('if-none-match') == '*'
            : peticion.headers.value('if-match') == '"$version"';
        if (!coincide) {
          peticion.response.statusCode = 412;
        } else {
          contenido = nueva;
          version++;
          peticion.response.statusCode = 201;
        }
      }
      await peticion.response.close();
    });
    final transporte = TransporteWebDav(
      'http://127.0.0.1:${servidor.port}/boveda',
      'ana',
      'secreto',
    );
    addTearDown(() async {
      transporte.cerrar();
      await servidor.close(force: true);
    });
    expect((await transporte.leer()).contenido, isNull);
    await transporte.escribir('uno', null);
    final remoto = await transporte.leer();
    expect(remoto.contenido, 'uno');
    version++;
    await expectLater(
      transporte.escribir('dos', remoto.version),
      throwsA(isA<DioException>()),
    );
    expect(contenido, 'uno');
  });

  test(
    'Dos bóvedas intercambian notas por carpeta y conservan conflictos',
    () async {
      final carpeta = await Directory.systemTemp.createTemp('glosala-sync-');
      final almacenamientoA = RepositorioMemoria()
        ..guardada = Boveda(notas: [nota('base')]);
      final almacenamientoB = RepositorioMemoria()
        ..guardada = const Boveda(notas: []);
      final a = ControladorBoveda(almacenamientoA);
      final b = ControladorBoveda(almacenamientoB);
      await a.inicializar();
      await b.inicializar();
      final servicio = ServicioSincronizacion();
      Future<int> sincronizar(ControladorBoveda c) =>
          servicio.sincronizar(c, TransporteCarpeta(carpeta.path), 'prueba');
      addTearDown(() async {
        await a.guardarPendientes();
        await b.guardarPendientes();
        a.dispose();
        b.dispose();
        await carpeta.delete(recursive: true);
      });
      await sincronizar(a);
      await sincronizar(b);
      expect(b.notas.single.contenido, 'base');
      a.actualizarContenido('compartida', 'desde A');
      await sincronizar(a);
      await sincronizar(b);
      expect(b.notas.single.contenido, 'desde A');
      a.actualizarContenido('compartida', 'conflicto A');
      b.actualizarContenido('compartida', 'conflicto B');
      await sincronizar(a);
      expect(await sincronizar(b), 1);
      expect(
        b.notas.map((n) => n.contenido),
        containsAll(['conflicto A', 'conflicto B']),
      );
      expect(
        jsonDecode(
          await File('${carpeta.path}/glosala-boveda.json').readAsString(),
        )['preferencias'],
        isEmpty,
      );
    },
  );
}
