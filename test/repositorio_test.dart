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

  test('Solo el marcador de Windows activa la bóveda portable', () async {
    expect(await directorioBovedaPortable(directorio, esWindows: true), isNull);
    await File('${directorio.path}/glosala.portable').writeAsString('portable');
    expect(
      await directorioBovedaPortable(directorio, esWindows: false),
      isNull,
    );
    final portable = await directorioBovedaPortable(
      directorio,
      esWindows: true,
    );
    // Un destino inaccesible debe fallar sin sustituirlo por otra bóveda.
    await File('${directorio.path}/datos').writeAsString('No es una carpeta');
    await expectLater(
      RepositorioBovedaNativo(portable!).guardar(const Boveda(notas: [])),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('Mover la carpeta portable conserva las notas y preferencias', () async {
    final aplicacion = await Directory('${directorio.path}/Glosala USB')
        .create();
    await File('${aplicacion.path}/glosala.portable').writeAsString('portable');
    final ubicacion = await directorioBovedaPortable(
      aplicacion,
      esWindows: true,
    );
    final nota = Nota(
      id: 'portable',
      titulo: 'Mi nota portátil',
      contenido: 'Conservar al mover la aplicación.',
      creadaEl: DateTime(2026),
      modificadaEl: DateTime(2026),
    );
    await RepositorioBovedaNativo(ubicacion!)
        .guardar(Boveda(notas: [nota], preferencias: {'idioma': 'fr'}));
    final trasladada = await aplicacion.rename('${directorio.path}/Otra ruta');
    final nueva = await directorioBovedaPortable(trasladada, esWindows: true);
    final reabierta = await RepositorioBovedaNativo(nueva!).cargar();
    expect(nueva.path, startsWith(trasladada.path));
    expect(reabierta!.notas.single.aJson(), nota.aJson());
    expect(reabierta.preferencias['idioma'], 'fr');
    expect(await ubicacion.exists(), isFalse);
  });

  test(
    'El lanzador conserva la bóveda fuera del temporal de extracción',
    () async {
      final extraida = await Directory('${directorio.path}/Temporal').create();
      final original = await Directory('${directorio.path}/USB con espacios')
          .create();
      expect(
        await directorioBovedaPortable(
          extraida,
          esWindows: true,
          raizPortable: original.path,
        ),
        isNull,
      );
      await File('${extraida.path}/glosala.portable').writeAsString('portable');
      final boveda = await directorioBovedaPortable(
        extraida,
        esWindows: true,
        raizPortable: original.path,
      );
      await RepositorioBovedaNativo(boveda!)
          .guardar(const Boveda(notas: [], preferencias: {'idioma': 'fr'}));
      await extraida.delete(recursive: true);
      expect(
        (await RepositorioBovedaNativo(
          boveda,
        ).cargar())!.preferencias['idioma'],
        'fr',
      );
      expect(boveda.path, startsWith(original.path));
    },
  );

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
