// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:flutter/foundation.dart' show Key, ValueKey;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glosala/aplicacion/controlador_boveda.dart';
import 'package:glosala/aplicacion_glosala.dart';
import 'package:glosala/idiomas/gestor_idiomas.dart';
import 'package:glosala/interfaz/componentes/controles_ventana.dart';
import 'package:glosala/interfaz/ventana_escritorio.dart';

import 'soporte/repositorio_memoria.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const canal = MethodChannel('window_manager');
  final llamadas = <String>[];

  setUpAll(() => GestorIdiomas.instancia.cargar());
  setUp(() {
    llamadas.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (llamada) async {
          llamadas.add(llamada.method);
          return false;
        });
  });
  tearDown(() {
    VentanaEscritorio.instancia.activa = false;
    VentanaEscritorio.instancia.maximizada = false;
    VentanaEscritorio.instancia.antesDeCerrar = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
  });

  test(
    'El cierre espera el guardado y evita solicitudes simultáneas',
    () async {
      final ventana = VentanaEscritorio();
      final guardado = Completer<bool>();
      ventana.antesDeCerrar = () => guardado.future;
      final cierre = ventana.cerrar();
      await ventana.cerrar();
      expect(llamadas, isEmpty);
      guardado.complete(true);
      await cierre;
      expect(llamadas, ['destroy']);
      ventana.dispose();
    },
  );

  testWidgets('Los controles funcionan y un fallo al guardar impide cerrar', (
    probador,
  ) async {
    probador.view.devicePixelRatio = 1;
    probador.view.physicalSize = const Size(1280, 720);
    addTearDown(probador.view.resetPhysicalSize);
    addTearDown(probador.view.resetDevicePixelRatio);
    final repositorio = RepositorioMemoria();
    final controlador = ControladorBoveda(repositorio);
    await controlador.inicializar();
    addTearDown(controlador.dispose);
    final ventana = VentanaEscritorio.instancia;
    ventana.activa = true;
    await probador.pumpWidget(AplicacionGlosala(controller: controlador));
    await probador.pumpAndSettle();
    final pestana = find.byKey(
      ValueKey('pestana-${controlador.notaSeleccionada!.id}'),
    );
    expect(probador.getTopLeft(pestana).dy, 0);
    expect(probador.getRect(pestana).bottom, 44);
    await probador.tap(pestana);
    await probador.pumpAndSettle();
    expect(llamadas, isNot(contains('startDragging')));
    await probador.drag(
      find.ancestor(
        of: find.byKey(const Key('arrastre-cabecera')),
        matching: find.byType(ZonaArrastreVentana),
      ),
      const Offset(40, 0),
    );
    await probador.pumpAndSettle();
    expect(llamadas, contains('startDragging'));
    llamadas.clear();
    await probador.drag(
      find.ancestor(
        of: find.byKey(const Key('espacio-libre-pestanas')),
        matching: find.byType(ZonaArrastreVentana),
      ),
      const Offset(40, 0),
    );
    await probador.pumpAndSettle();
    expect(llamadas, contains('startDragging'));
    await probador.tap(find.byTooltip('Minimizar'));
    await probador.tap(find.byTooltip('Maximizar'));
    await probador.pumpAndSettle();
    expect(llamadas, containsAll(['minimize', 'maximize']));
    ventana.onWindowMaximize();
    await probador.pumpAndSettle();
    expect(find.byTooltip('Restaurar ventana'), findsOneWidget);

    await probador.tap(find.byKey(const Key('activar-concentracion')));
    await probador.pumpAndSettle();
    expect(find.byKey(const Key('cabecera-concentracion')), findsOneWidget);
    expect(find.byTooltip('Minimizar'), findsOneWidget);
    expect(find.byTooltip('Restaurar ventana'), findsOneWidget);
    expect(find.byTooltip('Cerrar'), findsOneWidget);

    repositorio.fallar = true;
    controlador.crearNota();
    await probador.pumpAndSettle();
    await probador.tap(find.byTooltip('Cerrar'));
    await probador.pumpAndSettle();
    expect(llamadas, isNot(contains('destroy')));
    expect(
      find.textContaining('No se han guardado los últimos cambios.'),
      findsOneWidget,
    );
    repositorio.fallar = false;
    await probador.tap(find.byTooltip('Cerrar'));
    await probador.pumpAndSettle();
    expect(llamadas.where((llamada) => llamada == 'destroy'), hasLength(1));
    expect(probador.takeException(), isNull);
  });
}
