import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glosala/datos/repositorio_boveda_nativo.dart';
import 'package:glosala/dominio/boveda.dart';
import 'package:glosala/dominio/nota.dart';

void main() {
  late Directory directorio;
  setUp(() async {
    directorio = await Directory.systemTemp.createTemp('glosala-pruebas-');
  });
  tearDown(() async {
    await directorio.delete(recursive: true);
  });

  test('Reabre archivos Markdown, metadatos Unicode y preferencias', () async {
    final repositorio = RepositorioBovedaNativo(directorio);
    final nota = Nota(
      id: 'segura',
      titulo: 'Diseño: "ñ"',
      contenido: '# Hola\n\nTexto con áéíóú y [[Idea]].\n',
      carpeta: 'Personal',
      creadaEl: DateTime(2026),
      modificadaEl: DateTime(2026),
      favorita: true,
    );
    await repositorio.guardar(
      Boveda(
        notas: [nota],
        carpetas: ['Vacía'],
        preferencias: {'idioma': 'fr'},
      ),
    );
    final cargada = await RepositorioBovedaNativo(directorio).cargar();
    expect(cargada!.notas.single.aJson(), nota.aJson());
    expect(cargada.preferencias['idioma'], 'fr');
    expect(cargada.carpetas, ['Vacía']);
    expect(
      await File('${directorio.path}/notes/segura.md').readAsString(),
      contains('# Hola'),
    );
    await repositorio.guardar(
      Boveda(
        notas: [nota.copiar(contenido: 'Segunda versión', eliminada: true)],
      ),
    );
    final actualizada = await RepositorioBovedaNativo(directorio).cargar();
    expect(actualizada!.notas.single.contenido, 'Segunda versión');
    expect(actualizada.notas.single.eliminada, isTrue);
  });

  test(
    'Un archivo dañado no se sustituye por una bóveda de bienvenida',
    () async {
      await Directory('${directorio.path}/notes').create();
      final archivo = File('${directorio.path}/notes/rota.md');
      await archivo.writeAsString('Contenido sin metadatos');
      expect(RepositorioBovedaNativo(directorio).cargar, throwsFormatException);
      expect(await archivo.readAsString(), 'Contenido sin metadatos');
    },
  );
}
