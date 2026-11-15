import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glosala/idiomas/gestor_idiomas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GestorIdiomas.instancia.cargar());
  tearDown(() => GestorIdiomas.instancia.actual = 'es');

  test(
    'Los cinco catálogos tienen las mismas claves y sustituyen marcadores',
    () {
      final gestor = GestorIdiomas.instancia;
      for (final codigo in GestorIdiomas.disponibles.keys) {
        final textos = gestor.validar(
          File('recursos/idiomas/$codigo.xml').readAsStringSync(),
          codigo,
        );
        expect(textos.length, greaterThan(170));
        gestor.actual = codigo;
        expect(t('{cantidad} palabras', {'cantidad': 12}), startsWith('12 '));
      }
      gestor.actual = 'en';
      expect(t('Nueva nota'), 'New note');
    },
  );

  test(
    'El editor rechaza XML inválido, catálogos incompletos y cambios de idioma',
    () {
      final gestor = GestorIdiomas.instancia;
      expect(
        () => gestor.validar(
          '<idioma codigo="en"><texto clave="x">X</texto></idioma>',
          'en',
        ),
        throwsFormatException,
      );
      expect(
        () => gestor.validar(gestor.original('fr'), 'en'),
        throwsFormatException,
      );
      expect(
        () => gestor.validar('<!DOCTYPE x><idioma codigo="es"/>', 'es'),
        throwsFormatException,
      );
    },
  );

  test('Se aplica una traducción editada sin cambiar las claves', () {
    final gestor = GestorIdiomas.instancia;
    final original = gestor.original('en');
    gestor.aplicar('en', original.replaceFirst('>New note<', '>My new note<'));
    gestor.actual = 'en';
    expect(t('Nueva nota'), 'My new note');
    gestor.aplicar('en', original);
  });

  test('Una actualización completa claves nuevas y conserva ediciones XML', () {
    final gestor = GestorIdiomas.instancia;
    const anterior =
        '<idioma codigo="en"><texto clave="Nueva nota">My note</texto></idioma>';
    final completo = gestor.completarCatalogo('en', anterior);
    final textos = gestor.validar(completo, 'en');
    expect(textos['Nueva nota'], 'My note');
    expect(textos['Exportar a…'], 'Export to…');
    expect(() => gestor.validar(anterior, 'en'), throwsFormatException);
  });
}
