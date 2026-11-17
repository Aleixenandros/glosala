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
    await probador.tap(find.byKey(const Key('opciones-idiomas')));
    await probador.pumpAndSettle();
    expect(find.text('App language'), findsOneWidget);
    expect(find.text('XML translation editor'), findsOneWidget);
    expect(probador.takeException(), isNull);
  });

  testWidgets('La búsqueda móvil sigue accesible con el teclado abierto', (
    probador,
  ) async {
    await preparar(probador, const Size(360, 640));
    await probador.tap(find.byTooltip('Abrir bóveda'));
    await probador.pumpAndSettle();
    probador.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(probador.view.resetViewInsets);
    await probador.pumpAndSettle();
    await probador.enterText(find.byKey(const Key('sidebar-search')), 'idea');
    await probador.pumpAndSettle();
    expect(probador.takeException(), isNull);
  });

  testWidgets('La bóveda se puede plegar y conserva la búsqueda al volver', (
    probador,
  ) async {
    final controlador = await preparar(probador, const Size(1280, 720));
    await probador.tap(find.text('CARPETAS'));
    await probador.pumpAndSettle();
    expect(find.byTooltip('Nueva carpeta'), findsOneWidget);
    await probador.enterText(find.byKey(const Key('sidebar-search')), 'idea');
    await probador.tap(find.byTooltip('Ocultar bóveda'));
    await probador.pumpAndSettle();
    expect(find.byKey(const Key('sidebar-search')), findsNothing);
    await probador.tap(find.byTooltip('Mostrar bóveda'));
    await probador.pumpAndSettle();
    expect(controlador.busqueda, 'idea');
    expect(
      probador
          .widget<TextField>(find.byKey(const Key('sidebar-search')))
          .controller!
          .text,
      'idea',
    );
    expect(probador.takeException(), isNull);
  });

  testWidgets('Opciones separa secciones y sitúa sincronización al final', (
    probador,
  ) async {
    await preparar(probador, const Size(1280, 720));
    expect(find.byTooltip('Sincronización'), findsNothing);
    await probador.tap(find.byTooltip('Opciones'));
    await probador.pumpAndSettle();
    expect(find.text('Tema de color'), findsOneWidget);
    expect(find.byKey(const Key('editor-xml')), findsNothing);
    expect(find.byKey(const Key('activar-plugin-exportacion')), findsNothing);
    final sincronizacion = find.byKey(const Key('opciones-sincronizacion'));
    expect(
      probador.getTopLeft(sincronizacion).dy,
      greaterThan(
        probador.getBottomLeft(find.byKey(const Key('opciones-acerca'))).dy,
      ),
    );
    await probador.tap(sincronizacion);
    await probador.pumpAndSettle();
    expect(find.text('URL de la carpeta WebDAV'), findsOneWidget);
    expect(find.text('Tema de color'), findsNothing);
    await probador.tap(find.byKey(const Key('opciones-idiomas')));
    await probador.pumpAndSettle();
    final xml = find.byKey(const Key('editor-xml'));
    await probador.enterText(xml, '<borrador/>');
    await probador.tap(find.byKey(const Key('opciones-apariencia')));
    await probador.pumpAndSettle();
    await probador.tap(find.byKey(const Key('opciones-idiomas')));
    await probador.pumpAndSettle();
    expect(probador.widget<TextField>(xml).controller!.text, '<borrador/>');
    expect(probador.takeException(), isNull);
  });

  testWidgets(
    'El ancho y la visibilidad de las columnas se conservan al reabrir',
    (probador) async {
      final c = await preparar(probador, const Size(1440, 900));
      final columna = find.byKey(const Key('columna-boveda'));
      final separador = find.byKey(const Key('separador-boveda'));
      final detalles = find.byKey(const Key('columna-detalles'));
      final anchoInicial = probador.getSize(columna).width;
      await probador.drag(separador, const Offset(110, 0));
      await probador.pumpAndSettle();
      final anchoElegido = probador.getSize(columna).width;
      expect(anchoElegido, greaterThan(anchoInicial + 70));
      expect(c.preferencias['ancho_boveda'], anchoElegido);
      await probador.tap(find.byTooltip('Cerrar panel de detalles'));
      await probador.pumpAndSettle();
      expect(detalles, findsNothing);
      await probador.tap(find.byTooltip('Ocultar bóveda'));
      await probador.pumpAndSettle();
      expect(columna, findsNothing);
      await c.guardarPendientes();
      await probador.pumpWidget(const SizedBox());
      final reabierto = ControladorBoveda(c.repositorio);
      await reabierto.inicializar();
      addTearDown(reabierto.dispose);
      await probador.pumpWidget(AplicacionGlosala(controller: reabierto));
      await probador.pumpAndSettle();
      expect(columna, findsNothing);
      expect(detalles, findsNothing);
      await probador.tap(find.byTooltip('Mostrar bóveda'));
      await probador.pumpAndSettle();
      expect(probador.getSize(columna).width, anchoElegido);
      await probador.tap(find.byTooltip('Mostrar detalles'));
      await probador.pumpAndSettle();
      expect(detalles, findsOneWidget);
      // El límite del arrastre protege el espacio central al reducir la ventana.
      probador.view.physicalSize = const Size(1000, 720);
      await probador.pumpAndSettle();
      await probador.drag(separador, const Offset(500, 0));
      await probador.pumpAndSettle();
      final espacioCentral =
          probador.getTopLeft(detalles).dx -
          probador.getTopRight(separador).dx -
          1;
      expect(espacioCentral, greaterThanOrEqualTo(440));
      await probador.tap(separador);
      await probador.pump(const Duration(milliseconds: 100));
      await probador.tap(separador);
      await probador.pumpAndSettle();
      expect(probador.getSize(columna).width, 256);
      expect(probador.takeException(), isNull);
    },
  );

  testWidgets(
    'Las pestañas comparten cabecera y la seleccionada sigue visible',
    (probador) async {
      final c = await preparar(probador, const Size(1280, 720));
      for (var i = 0; i < 12; i++) {
        c.crearNota();
      }
      await probador.pumpAndSettle();
      var seleccionada = c.notaSeleccionada!;
      var pestana = find.byKey(ValueKey('pestana-${seleccionada.id}'));
      final cabecera = find.byKey(const Key('cabecera-espacio'));
      expect(probador.getTopLeft(pestana).dy, probador.getTopLeft(cabecera).dy);
      expect(pestana.hitTestable(), findsOneWidget);
      await probador.tap(find.byTooltip('Cerrar ${seleccionada.titulo}'));
      await probador.pumpAndSettle();
      expect(
        c.notasAbiertas.any((nota) => nota.id == seleccionada.id),
        isFalse,
      );
      seleccionada = c.notaSeleccionada!;
      pestana = find.byKey(ValueKey('pestana-${seleccionada.id}'));
      probador.view.physicalSize = const Size(390, 844);
      await probador.pumpAndSettle();
      expect(pestana.hitTestable(), findsOneWidget);
      expect(probador.getRect(pestana).bottom, lessThanOrEqualTo(44));
      expect(probador.takeException(), isNull);
    },
  );

  testWidgets('Móvil: sincronización se abre desde la sección de Opciones', (
    probador,
  ) async {
    await preparar(probador, const Size(390, 844));
    await probador.tap(find.byTooltip('Módulos'));
    await probador.pumpAndSettle();
    expect(find.text('Sincronización'), findsNothing);
    await probador.tap(find.text('Opciones'));
    await probador.pumpAndSettle();
    await probador.tap(find.byKey(const Key('seccion-opciones')));
    await probador.pumpAndSettle();
    await probador.tap(find.text('Sincronización').last);
    await probador.pumpAndSettle();
    expect(find.text('URL de la carpeta WebDAV'), findsOneWidget);
    expect(probador.takeException(), isNull);
  });
}
