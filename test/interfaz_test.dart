// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glosala/aplicacion/controlador_boveda.dart';
import 'package:glosala/aplicacion_glosala.dart';
import 'package:glosala/idiomas/gestor_idiomas.dart';

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
    final controlador = ControladorBoveda(RepositorioMemoria());
    await controlador.inicializar();
    addTearDown(controlador.dispose);
    await probador.pumpWidget(AplicacionGlosala(controller: controlador));
    await probador.pumpAndSettle();
    return controlador;
  }

  testWidgets(
    'Escritorio: crear, escribir, leer y buscar sin errores de diseño',
    (probador) async {
      final controlador = await preparar(probador, const Size(1440, 1000));
      expect(find.text('Glosala'), findsOneWidget);
      await probador.tap(find.text('Nueva nota'));
      await probador.pumpAndSettle();
      await probador.enterText(
        find.byKey(const Key('markdown-editor')),
        '# Prueba\n\n**Contenido guardado**',
      );
      await probador.pumpAndSettle();
      expect(
        controlador.notaSeleccionada!.contenido,
        contains('Contenido guardado'),
      );
      await probador.tap(find.text('Leer'));
      await probador.pumpAndSettle();
      expect(find.byKey(const Key('markdown-editor')), findsNothing);
      await probador.enterText(
        find.byKey(const Key('sidebar-search')),
        'Contenido guardado',
      );
      await probador.pumpAndSettle();
      expect(controlador.notasVisibles, hasLength(1));
      expect(probador.takeException(), isNull);
    },
  );

  testWidgets('Móvil: bóveda, editor y navegación por módulos', (
    probador,
  ) async {
    await preparar(probador, const Size(390, 844));
    await probador.tap(find.byTooltip('Abrir bóveda'));
    await probador.pumpAndSettle();
    await probador.tap(find.text('Nueva nota'));
    await probador.pumpAndSettle();
    expect(find.byKey(const Key('markdown-editor')), findsOneWidget);
    await probador.tap(find.byTooltip('Módulos'));
    await probador.pumpAndSettle();
    await probador.tap(find.text('Tareas').last);
    await probador.pumpAndSettle();
    await probador.tap(find.text('Nueva tarea'));
    await probador.pumpAndSettle();
    await probador.enterText(find.byType(TextField), 'Preparar proyecto');
    await probador.tap(find.text('Guardar'));
    await probador.pumpAndSettle();
    expect(find.text('Preparar proyecto'), findsOneWidget);
    expect(probador.takeException(), isNull);
  });

  testWidgets('El cambio de idioma y tema se refleja inmediatamente', (
    probador,
  ) async {
    final controlador = await preparar(probador, const Size(1440, 1000));
    GestorIdiomas.instancia.actual = 'en';
    controlador.configurar('idioma', 'en');
    controlador.configurar('apariencia', 'claro');
    controlador.configurar('tema', 'bosque');
    await probador.pumpAndSettle();
    expect(find.text('New note'), findsOneWidget);
    await probador.tap(find.byTooltip('Settings').first);
    await probador.pumpAndSettle();
    expect(find.text('App language'), findsOneWidget);
    expect(find.text('XML translation editor'), findsOneWidget);
    expect(probador.takeException(), isNull);
  });
}
