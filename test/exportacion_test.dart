import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glosala/dominio/nota.dart';
import 'package:glosala/plugins/plugin_exportacion.dart';
import 'package:xml/xml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final nota = Nota(
    id: 'exportacion',
    titulo: 'Diseño y acción',
    creadaEl: DateTime(2026),
    modificadaEl: DateTime(2026),
    contenido: '# Título\n\nUna **idea** con ñ y áéíóú.\n\n- Uno\n- Dos\n\n| Columna | Valor |\n| --- | --- |\n| Prueba | 42 |',
  );
  final plugin = PluginExportacion();

  test('Exporta Markdown sin modificar el contenido', () async {
    final archivo = await plugin.exportar([nota], FormatoExportacion.markdown);
    expect(utf8.decode(archivo.bytes), nota.contenido);
    expect(archivo.nombre, 'Diseño y acción.md');
  });

  test('HTML elimina scripts y enlaces ejecutables', () async {
    final maliciosa = nota.copiar(
      contenido: '<script>alert(1)</script>\n\n[Mal](javascript:alert%281%29)\n\n**Bien**',
    );
    final archivo = await plugin.exportar([maliciosa], FormatoExportacion.html);
    final html = utf8.decode(archivo.bytes);
    expect(html, isNot(contains('<script>')));
    expect(html, isNot(contains('href="javascript:')));
    expect(html, contains('<strong>Bien</strong>'));
    expect(html, contains('Content-Security-Policy'));
  });

  test(
    'ODS contiene un manifiesto y celdas de texto Unicode, sin fórmulas',
    () async {
      final archivo = await plugin.exportar([
        nota.copiar(titulo: '=1+1'),
      ], FormatoExportacion.ods);
      final zip = ZipDecoder().decodeBytes(archivo.bytes, verify: true);
      expect(zip.files.first.name, 'mimetype');
      final contenido = utf8.decode(zip.findFile('content.xml')!.content);
      final xml = XmlDocument.parse(contenido);
      expect(xml.findAllElements('table:table-row'), hasLength(2));
      expect(contenido, contains('office:value-type="string"'));
      expect(contenido, contains('=1+1'));
      expect(contenido, isNot(contains('table:formula')));
      expect(zip.findFile('META-INF/manifest.xml'), isNotNull);
      await Directory('build/pruebas').create(recursive: true);
      await File('build/pruebas/notas.ods').writeAsBytes(archivo.bytes);
    },
  );

  test('PDF genera un documento paginado con fuentes y acentos', () async {
    final archivo = await plugin.exportar([nota], FormatoExportacion.pdf);
    expect(ascii.decode(archivo.bytes.take(5).toList()), '%PDF-');
    expect(archivo.bytes.length, greaterThan(2000));
    await Directory('build/pruebas').create(recursive: true);
    await File('build/pruebas/notas.pdf').writeAsBytes(archivo.bytes);
  });
}
