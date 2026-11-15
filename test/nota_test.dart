import 'package:flutter_test/flutter_test.dart';
import 'package:glosala/dominio/nota.dart';
import 'package:markdown/markdown.dart' as md;

void main() {
  test(
    'Extrae enlaces, etiquetas Unicode y encabezados, excluyendo código',
    () {
      final nota = Nota(
        id: 'prueba',
        titulo: 'Prueba',
        creadaEl: DateTime(2026),
        modificadaEl: DateTime(2026),
        contenido: '''
# Encabezado
[[Otra nota|alias]] #diseño #acción
`[[No es enlace]] #codigo`
```dart
[[Tampoco]] #oculta
## Oculto
```
## Segundo
''',
      );
      expect(nota.enlaces, ['Otra nota']);
      expect(nota.etiquetas, ['acción', 'diseño']);
      expect(nota.encabezados.map((h) => h.text), ['Encabezado', 'Segundo']);
      expect(
        nota.contenido.substring(nota.encabezados.last.offset),
        startsWith('## Segundo'),
      );
    },
  );

  test('Renderiza enlaces con alias sin convertir el código inline', () {
    final html = md.markdownToHtml(
      '[[Otra nota|Ir]] `[[Código]]`',
      inlineSyntaxes: [SintaxisEnlaceInterno()],
    );
    expect(html, contains('href="glosala:Otra%20nota"'));
    expect(html, contains('>Ir</a>'));
    expect(html, contains('<code>[[Código]]</code>'));
  });

  test('Renombrar conserva alias y no modifica ejemplos de código', () {
    expect(
      SintaxisEnlaceInterno.renombrarDestino(
        '[[Antes|alias]] y `[[Antes]]`',
        'Antes',
        'Después',
      ),
      '[[Después|alias]] y `[[Antes]]`',
    );
  });

  test('Rechaza identificadores que intentan salir de la bóveda', () {
    expect(
      () => Nota.desdeJson({'id': '../../secreto'}),
      throwsFormatException,
    );
  });
}
