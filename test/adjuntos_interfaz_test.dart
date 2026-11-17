// ignore_for_file: deprecated_member_use
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glosala/aplicacion/controlador_boveda.dart';
import 'package:glosala/aplicacion_glosala.dart';
import 'package:glosala/dominio/adjunto.dart';
import 'package:glosala/idiomas/gestor_idiomas.dart';
import 'package:glosala/interfaz/componentes/visor_adjunto.dart';
import 'package:glosala/interfaz/componentes/boton_reproduccion.dart';

import 'soporte/repositorio_memoria.dart';
import 'soporte/selector_archivos_memoria.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GestorIdiomas.instancia.cargar());

  testWidgets(
    'El botón conserva su acción accesible con la ayuda emergente visible',
    (probador) async {
      final semantica = probador.ensureSemantics();
      final reproduciendo = ValueNotifier(false);
      addTearDown(reproduciendo.dispose);
      await probador.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: reproduciendo,
                builder: (_, valor, _) => BotonReproduccion(
                  reproduciendo: valor,
                  alPulsar: () => reproduciendo.value = !reproduciendo.value,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Reproducir'), findsOneWidget);
      await probador.tap(find.byType(BotonReproduccion));
      await probador.pumpAndSettle();
      expect(find.bySemanticsLabel('Pausar'), findsOneWidget);
      await probador.longPress(find.byType(BotonReproduccion));
      await probador.pumpAndSettle();
      expect(find.text('Reproducir / Pausar'), findsOneWidget);
      expect(find.bySemanticsLabel('Pausar'), findsOneWidget);
      await probador.tap(find.byType(BotonReproduccion));
      await probador.pumpAndSettle();
      expect(reproduciendo.value, isFalse);
      expect(find.bySemanticsLabel('Reproducir'), findsOneWidget);
      semantica.dispose();
    },
  );

  Future<(ControladorBoveda, SelectorArchivosMemoria)> preparar(
    WidgetTester probador,
  ) async {
    probador.view.devicePixelRatio = 1;
    probador.view.physicalSize = const Size(390, 844);
    addTearDown(probador.view.resetPhysicalSize);
    addTearDown(probador.view.resetDevicePixelRatio);
    final anterior = FilePickerPlatform.instance;
    final selector = SelectorArchivosMemoria();
    FilePickerPlatform.instance = selector;
    addTearDown(() => FilePickerPlatform.instance = anterior);
    final c = ControladorBoveda(RepositorioMemoria());
    await c.inicializar();
    addTearDown(c.dispose);
    c.crearNota(titulo: 'Archivos', contenido: 'Conservar texto');
    await probador.pumpWidget(AplicacionGlosala(controller: c));
    await probador.pumpAndSettle();
    return (c, selector);
  }

  testWidgets(
    'Adjuntar, guardar, quitar y deshacer conserva el archivo en móvil',
    (probador) async {
      final (c, selector) = await preparar(probador);
      final pdf = Uint8List.fromList(utf8.encode('%PDF-1.7\nprueba'));
      selector.seleccionados = [ArchivoSeleccionadoMemoria('informe.pdf', pdf)];
      await probador.tap(find.byTooltip('Adjuntos'));
      await probador.pumpAndSettle();
      await probador.tap(find.text('Añadir archivos'));
      await probador.pumpAndSettle();
      expect(c.adjuntos, hasLength(1));
      expect(c.notaSeleccionada!.contenido, contains('Conservar texto'));
      expect(c.notaSeleccionada!.idsAdjuntos, contains(c.adjuntos.single.id));
      await probador.tap(find.text('informe.pdf'));
      await probador.pumpAndSettle();
      expect(find.byType(VisorAdjunto), findsOneWidget);
      await probador.tap(find.text('Guardar una copia'));
      await probador.pumpAndSettle();
      expect(selector.archivos.single.bytes, pdf);
      await probador.tap(find.byTooltip('Cerrar').last);
      await probador.pumpAndSettle();
      await probador.tap(find.byTooltip('Quitar de la nota'));
      await probador.pumpAndSettle();
      expect(c.notaSeleccionada!.idsAdjuntos, isEmpty);
      await probador.tap(find.byTooltip('Cerrar').last);
      await probador.pumpAndSettle();
      await probador.tap(find.byKey(const Key('markdown-editor')));
      await probador.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await probador.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await probador.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await probador.pumpAndSettle();
      expect(c.notaSeleccionada!.idsAdjuntos, contains(c.adjuntos.single.id));
      expect(c.adjuntosDe(c.notaSeleccionada!).single.bytes, pdf);
      await c.guardarPendientes();
      expect(
        (c.repositorio as RepositorioMemoria).guardada!.adjuntos.single.bytes,
        pdf,
      );
      expect(probador.takeException(), isNull);
    },
  );

  testWidgets(
    'Cancelar o fallar en un lote no deja adjuntos ni enlaces parciales',
    (probador) async {
      final (c, selector) = await preparar(probador);
      final contenido = c.notaSeleccionada!.contenido;
      await probador.tap(find.byTooltip('Adjuntos'));
      await probador.pumpAndSettle();
      selector.cancelar = true;
      await probador.tap(find.text('Añadir archivos'));
      await probador.pumpAndSettle();
      expect(c.adjuntos, isEmpty);
      selector.cancelar = false;
      selector.seleccionados = [
        ArchivoSeleccionadoMemoria('bueno.txt', Uint8List.fromList([65])),
        ArchivoSeleccionadoMemoria(
          'grande.mp4',
          Uint8List(0),
          tamanoDeclarado: Adjunto.maximoBytes + 1,
        ),
      ];
      await probador.tap(find.text('Añadir archivos'));
      await probador.pumpAndSettle();
      expect(
        find.text('El archivo supera el límite de 100 MB.'),
        findsOneWidget,
      );
      expect(c.adjuntos, isEmpty);
      expect(c.notaSeleccionada!.contenido, contenido);
      expect(probador.takeException(), isNull);
    },
  );
}
