import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glosala/aplicacion/controlador_boveda.dart';
import 'package:glosala/datos/repositorio_boveda_nativo.dart';
import 'package:glosala/dominio/adjunto.dart';
import 'package:glosala/dominio/boveda.dart';
import 'package:glosala/dominio/nota.dart';
import 'package:glosala/plugins/plugin_exportacion.dart';
import 'package:glosala/sincronizacion/servicio_sincronizacion.dart';
import 'package:glosala/sincronizacion/transporte.dart';

import 'soporte/repositorio_memoria.dart';

Nota nota(String contenido) => Nota(
  id: 'nota',
  titulo: 'Con archivos',
  contenido: contenido,
  creadaEl: DateTime(2026),
  modificadaEl: DateTime(2026),
);
Adjunto archivo(String nombre, String datos) =>
    Adjunto.crear(nombre, Uint8List.fromList(utf8.encode(datos)));

class _TransporteMemoria implements TransporteSincronizacion {
  String? contenido;
  void Function()? alEscribir;
  bool fallar = false;
  @override
  Future<DocumentoRemoto> leer() async => DocumentoRemoto(contenido, null);
  @override
  Future<void> escribir(String fuente, String? versionAnterior) async {
    if (fallar) throw StateError('Conflicto de versión remota');
    alEscribir?.call();
    contenido = fuente;
  }

  @override
  void cerrar() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Los adjuntos son inmutables, verificables y no colisionan por nombre',
    () {
      final datos = Uint8List.fromList([1, 2, 3]);
      final adjunto = Adjunto.crear('../../información [final].pdf', datos);
      datos[0] = 9;
      expect(adjunto.nombre, 'información [final].pdf');
      expect(adjunto.bytes, [1, 2, 3]);
      expect(() => adjunto.bytes[0] = 9, throwsUnsupportedError);
      expect(adjunto.id, isNot(Adjunto.crear(adjunto.nombre, datos).id));
      expect(
        adjunto.id,
        Adjunto.crear(adjunto.nombre, Uint8List.fromList([1, 2, 3])).id,
      );
      expect(adjunto.markdown, contains(r'información \[final\].pdf'));
      expect(Adjunto.desdeJson(adjunto.aJson()).bytes, adjunto.bytes);
      expect(
        () => Adjunto.desdeJson({...adjunto.aJson(), 'data': 'YWJj'}),
        throwsFormatException,
      );
      expect(
        () => Adjunto.desdeJson({...adjunto.aJson(), 'id': '../fuera'}),
        throwsFormatException,
      );
      expect(Boveda.desdeJson({'version': 1, 'notes': []}).adjuntos, isEmpty);
      expect(
        Boveda.desdeJson(Boveda(notas: [], adjuntos: [adjunto]).aJson())
            .adjuntos
            .single
            .id,
        adjunto.id,
      );
    },
  );

  test('Distingue vídeo WebM y audio M4A aunque compartan contenedor', () {
    final ebml = Uint8List.fromList([0x1a, 0x45, 0xdf, 0xa3, 0x9f]);
    expect(Adjunto.crear('video.webm', ebml).esVideo, isTrue);
    expect(archivo('grabacion.m4a', 'audio').esAudio, isTrue);
    expect(
      Adjunto.crear(
        'informe.docx',
        Uint8List.fromList([0x50, 0x4b, 3, 4]),
      ).tipoMime,
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    final especial = archivo('informe) final.pdf', '%PDF-1.7');
    expect(especial.enlaceExportado, contains('%29%20'));
    expect(archivo('CON.txt', 'texto').nombre, 'archivo-CON.txt');
  });

  test('El repositorio conserva binarios sin reescribirlos al editar; detecta daños', () async {
    final carpeta = await Directory.systemTemp.createTemp('glosala-adjuntos-');
    addTearDown(() => carpeta.delete(recursive: true));
    final adjunto = archivo('informe.pdf', '%PDF-1.7\narchivo');
    final original = nota(adjunto.markdown);
    final repositorio = RepositorioBovedaNativo(carpeta);
    await repositorio.guardar(Boveda(notas: [original], adjuntos: [adjunto]));
    final binario = File('${carpeta.path}/attachments/${adjunto.id}');
    final fecha = DateTime(2000);
    await binario.setLastModified(fecha);
    await repositorio.guardar(
      Boveda(
        notas: [
          original.copiar(
            contenido: '${original.contenido}\nEditada',
            eliminada: true,
          ),
        ],
        adjuntos: [adjunto],
      ),
    );
    expect((await binario.lastModified()).year, 2000);
    final metadatos = jsonDecode(
      await File('${carpeta.path}/workspace.json').readAsString(),
    ) as Map;
    expect(metadatos['version'], 2);
    expect(
      (metadatos['attachments'] as List).single.containsKey('data'),
      isFalse,
    );
    final reabierta = await RepositorioBovedaNativo(carpeta).cargar();
    expect(reabierta!.adjuntos.single.bytes, adjunto.bytes);
    expect(reabierta.notas.single.eliminada, isTrue);
    await binario.writeAsString('dañado');
    await expectLater(
      RepositorioBovedaNativo(carpeta).cargar(),
      throwsFormatException,
    );
    expect(await binario.readAsString(), 'dañado');
  });

  test(
    'Sincroniza conflictos y adjuntos añadidos durante el envío sin pérdidas',
    () async {
      final a = ControladorBoveda(
        RepositorioMemoria()..guardada = Boveda(notas: [nota('base')]),
      );
      final b = ControladorBoveda(
        RepositorioMemoria()..guardada = const Boveda(notas: []),
      );
      await a.inicializar();
      await b.inicializar();
      addTearDown(() async {
        await a.guardarPendientes();
        await b.guardarPendientes();
        a.dispose();
        b.dispose();
      });
      final transporte = _TransporteMemoria();
      final servicio = ServicioSincronizacion();
      Future<int> sincronizar(ControladorBoveda c) =>
          servicio.sincronizar(c, transporte, 'prueba');
      await sincronizar(a);
      await sincronizar(b);
      final primero = archivo('igual.txt', 'desde A');
      final segundo = archivo('igual.txt', 'desde B');
      a.registrarAdjuntos([primero]);
      a.actualizarContenido('nota', primero.markdown);
      b.registrarAdjuntos([segundo]);
      b.actualizarContenido('nota', segundo.markdown);
      await sincronizar(a);
      expect(await sincronizar(b), 1);
      expect(
        b.adjuntos.map((a) => a.id),
        containsAll([primero.id, segundo.id]),
      );
      expect(
        b.notas.expand((n) => n.idsAdjuntos),
        containsAll([primero.id, segundo.id]),
      );
      final durante = archivo('durante.txt', 'Conservar');
      transporte.alEscribir = () {
        b.registrarAdjuntos([durante]);
        b.actualizarContenido(
          'nota',
          '${segundo.markdown}\n${durante.markdown}',
        );
      };
      await sincronizar(b);
      expect(b.adjuntoPorId(durante.id), isNotNull);
      expect(b.notaPorId('nota')!.idsAdjuntos, contains(durante.id));
      transporte.alEscribir = null;
      await sincronizar(b);
      await sincronizar(a);
      expect(a.adjuntoPorId(durante.id)!.bytes, durante.bytes);
      final copia = a.duplicarNotas(['nota']).single;
      expect(a.adjuntosDe(copia), isNotEmpty);
      final antes = a.instantanea.aJson();
      transporte.fallar = true;
      await expectLater(sincronizar(a), throwsStateError);
      expect(a.instantanea.aJson(), antes);
      final remota = jsonDecode(transporte.contenido!) as Map;
      expect(remota['preferencias'], isEmpty);
    },
  );

  test(
    'Las exportaciones incluyen los archivos originales y enlaces relativos',
    () async {
      final adjunto = archivo('informe ñ.pdf', '%PDF-1.7\ntexto');
      final imagen = Adjunto.crear(
        'foto.png',
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        ),
      );
      final fuente = nota('${adjunto.markdown}\n\n${imagen.markdown}');
      final plugin = PluginExportacion();
      for (final formato in FormatoExportacion.values) {
        final salida = await plugin.exportar(
          [fuente],
          formato,
          adjuntos: [adjunto, imagen],
        );
        expect(salida.tipoMime, 'application/zip');
        final zip = ZipDecoder().decodeBytes(salida.bytes, verify: true);
        expect(zip.findFile(adjunto.rutaExportada)!.content, adjunto.bytes);
        expect(zip.findFile(imagen.rutaExportada)!.content, imagen.bytes);
        if (formato == FormatoExportacion.markdown ||
            formato == FormatoExportacion.html) {
          final documento = utf8
              .decode(zip.files.first.content)
              .replaceAll('&#47;', '/');
          expect(documento, isNot(contains('adjunto:')));
          expect(
            documento,
            contains('adjuntos/${adjunto.id}/informe%20%C3%B1.pdf'),
          );
          if (formato == FormatoExportacion.html) {
            expect(documento, contains('<img src="adjuntos/'));
          }
        }
      }
      await expectLater(
        plugin.exportar([fuente], FormatoExportacion.markdown),
        throwsFormatException,
      );
    },
  );
}
