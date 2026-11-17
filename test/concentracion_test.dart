// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glosala/aplicacion/controlador_boveda.dart';
import 'package:glosala/aplicacion_glosala.dart';
import 'package:glosala/idiomas/gestor_idiomas.dart';
import 'package:glosala/interfaz/componentes/editor_nota.dart';
import 'package:glosala/interfaz/componentes/pestanas_notas.dart';

import 'soporte/repositorio_memoria.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GestorIdiomas.instancia.cargar());

  Future<ControladorBoveda> preparar(WidgetTester probador, Size tamano) async {
    probador.view.devicePixelRatio = 1;
    probador.view.physicalSize = tamano;
    addTearDown(probador.view.resetPhysicalSize);
    addTearDown(probador.view.resetDevicePixelRatio);
    GestorIdiomas.instancia.actual = 'es';
    final c = ControladorBoveda(RepositorioMemoria());
    await c.inicializar();
    addTearDown(c.dispose);
    await probador.pumpWidget(AplicacionGlosala(controller: c));
    await probador.pumpAndSettle();
    return c;
  }

  Future<void> atajo(
    WidgetTester probador,
    LogicalKeyboardKey tecla, {
    bool mayus = false,
  }) async {
    await probador.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (mayus) await probador.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await probador.sendKeyEvent(tecla);
    if (mayus) await probador.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await probador.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await probador.pumpAndSettle();
  }

  testWidgets(
    'Concentración conserva selección, historial y disposición; Escape respeta la búsqueda',
    (probador) async {
      final c = await preparar(probador, const Size(1440, 900));
      await probador.tap(find.byTooltip('Cerrar panel de detalles'));
      await probador.drag(
        find.byKey(const Key('separador-boveda')),
        const Offset(90, 0),
      );
      await probador.pumpAndSettle();
      final ancho = probador
          .getSize(find.byKey(const Key('columna-boveda')))
          .width;
      await probador.tap(find.text('CARPETAS'));
      await probador.pumpAndSettle();
      final carpeta = find.byKey(ValueKey('carpeta-${c.carpetas.first}'));
      expect(carpeta, findsNothing);
      c.cambiarModoEditor(ModoEditor.editar);
      const contenido = '# Trabajo\n\nTexto para escribir.';
      c.actualizarContenido(c.notaSeleccionada!.id, contenido);
      await probador.pumpAndSettle();
      final campo = find.byKey(const Key('markdown-editor'));
      await probador.tap(campo);
      final texto = probador.widget<TextField>(campo).controller!;
      final inicio = contenido.indexOf('Texto');
      final seleccion = TextSelection(
        baseOffset: inicio,
        extentOffset: inicio + 5,
      );
      texto.selection = seleccion;
      final estado = probador.state(find.byType(EditorNota));
      final preferencias = Map.of(c.preferencias);
      await atajo(probador, LogicalKeyboardKey.keyF, mayus: true);
      expect(find.byKey(const Key('cabecera-concentracion')), findsOneWidget);
      expect(find.byKey(const Key('columna-boveda')), findsNothing);
      expect(find.byType(PestanasNotas), findsNothing);
      expect(find.byTooltip('Opciones'), findsNothing);
      expect(find.byKey(const Key('herramientas-nota')), findsNothing);
      expect(find.byTooltip('Negrita (Ctrl/Cmd+B)'), findsNothing);
      expect(probador.state(find.byType(EditorNota)), same(estado));
      expect(texto.selection, seleccion);
      expect(c.preferencias, preferencias);
      expect(probador.getSize(campo).width, lessThanOrEqualTo(860));
      await atajo(probador, LogicalKeyboardKey.keyB);
      expect(c.notaSeleccionada!.contenido, contains('**Texto**'));
      await atajo(probador, LogicalKeyboardKey.keyF);
      expect(find.byKey(const Key('buscar-en-nota')), findsOneWidget);
      await probador.sendKeyEvent(LogicalKeyboardKey.escape);
      await probador.pumpAndSettle();
      expect(find.byKey(const Key('buscar-en-nota')), findsNothing);
      expect(find.byKey(const Key('cabecera-concentracion')), findsOneWidget);
      await probador.sendKeyEvent(LogicalKeyboardKey.escape);
      await probador.pumpAndSettle();
      expect(find.byKey(const Key('cabecera-concentracion')), findsNothing);
      expect(
        probador.getSize(find.byKey(const Key('columna-boveda'))).width,
        ancho,
      );
      expect(find.byKey(const Key('columna-detalles')), findsNothing);
      expect(carpeta, findsNothing);
      expect(probador.state(find.byType(EditorNota)), same(estado));
      expect(c.preferencias, preferencias);
      await atajo(probador, LogicalKeyboardKey.keyZ);
      expect(c.notaSeleccionada!.contenido, contenido);
      await c.guardarPendientes();
      final guardada = (c.repositorio as RepositorioMemoria).guardada!;
      expect(
        guardada.notas
            .firstWhere((n) => n.id == c.notaSeleccionada!.id)
            .contenido,
        contenido,
      );
      expect(probador.takeException(), isNull);
    },
  );

  testWidgets(
    'Al salir restaura la vista dividida y permite leer dentro del modo',
    (probador) async {
      final c = await preparar(probador, const Size(1440, 900));
      c.cambiarModoEditor(ModoEditor.dividir);
      await probador.pumpAndSettle();
      await probador.tap(find.byKey(const Key('activar-concentracion')));
      await probador.pumpAndSettle();
      expect(c.modoEditor, ModoEditor.dividir);
      expect(find.byKey(const Key('markdown-editor')), findsOneWidget);
      await probador.tap(find.byKey(const Key('salir-concentracion')));
      await probador.pumpAndSettle();
      expect(c.modoEditor, ModoEditor.dividir);
      expect(find.byKey(const Key('columna-detalles')), findsOneWidget);
      await probador.tap(find.byKey(const Key('activar-concentracion')));
      await probador.pumpAndSettle();
      await probador.tap(find.byTooltip('Leer'));
      await probador.pumpAndSettle();
      expect(c.modoEditor, ModoEditor.leer);
      expect(find.byKey(const Key('markdown-editor')), findsNothing);
      await probador.tap(find.byTooltip('Editar'));
      await probador.pumpAndSettle();
      expect(find.byKey(const Key('markdown-editor')), findsOneWidget);
      expect(probador.takeException(), isNull);
    },
  );

  testWidgets(
    'Móvil: escribir con el teclado abierto y salir sin perder la nota',
    (probador) async {
      final c = await preparar(probador, const Size(360, 640));
      await probador.tap(find.byKey(const Key('activar-concentracion')));
      await probador.pumpAndSettle();
      expect(find.byTooltip('Módulos'), findsNothing);
      expect(find.byTooltip('Abrir bóveda'), findsNothing);
      await probador.tap(find.byTooltip('Editar'));
      probador.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(probador.view.resetViewInsets);
      await probador.pumpAndSettle();
      await probador.enterText(
        find.byKey(const Key('markdown-editor')),
        'Nota desde el teléfono',
      );
      await probador.pumpAndSettle();
      await probador.tap(find.byKey(const Key('salir-concentracion')));
      await probador.pumpAndSettle();
      expect(find.byTooltip('Módulos'), findsOneWidget);
      expect(c.notaSeleccionada!.contenido, 'Nota desde el teléfono');
      expect(probador.takeException(), isNull);
    },
  );
}
