// ignore_for_file: deprecated_member_use
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glosala/aplicacion/controlador_boveda.dart';
import 'package:glosala/aplicacion_glosala.dart';
import 'package:glosala/dominio/boveda.dart';
import 'package:glosala/dominio/nota.dart';
import 'package:glosala/idiomas/gestor_idiomas.dart';

import 'soporte/repositorio_memoria.dart';
import 'soporte/selector_archivos_memoria.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GestorIdiomas.instancia.cargar());
  late SelectorArchivosMemoria selector;

  Future<ControladorBoveda> preparar(
    WidgetTester probador, {
    bool movil = false,
  }) async {
    probador.view.devicePixelRatio = 1;
    probador.view.physicalSize = movil
        ? const Size(390, 844)
        : const Size(1440, 1000);
    addTearDown(probador.view.resetPhysicalSize);
    addTearDown(probador.view.resetDevicePixelRatio);
    GestorIdiomas.instancia.actual = 'es';
    final anterior = FilePickerPlatform.instance;
    selector = SelectorArchivosMemoria();
    FilePickerPlatform.instance = selector;
    addTearDown(() => FilePickerPlatform.instance = anterior);
    final repositorio = RepositorioMemoria()
      ..guardada = Boveda(
        notas: [
          for (final (indice, id) in ['uno', 'dos', 'tres'].indexed)
            Nota(
              id: id,
              titulo: 'Nota $id',
              contenido: 'Contenido $id',
              creadaEl: DateTime(2026),
              modificadaEl: DateTime(2026, 1, indice + 1),
              carpeta: id == 'tres' ? '' : 'Proyecto',
            ),
        ],
        carpetas: ['Proyecto', 'Destino'],
        idSeleccionada: 'tres',
      );
    final controlador = ControladorBoveda(repositorio);
    await controlador.inicializar();
    addTearDown(controlador.dispose);
    await probador.pumpWidget(AplicacionGlosala(controller: controlador));
    await probador.pumpAndSettle();
    return controlador;
  }

  Future<void> abrir(WidgetTester probador, String id) async {
    await probador.tap(
      find.byKey(ValueKey('nota-$id')),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await probador.pumpAndSettle();
  }

  Future<void> elegir(WidgetTester probador, String texto) async {
    final accion = find.widgetWithText(MenuItemButton, texto);
    await probador.tap(
      accion.evaluate().isNotEmpty ? accion.first : find.text(texto).last,
    );
    await probador.pumpAndSettle();
  }

  testWidgets('Botón derecho: renombra, mueve y restaura la nota pulsada', (
    probador,
  ) async {
    final controlador = await preparar(probador);
    await abrir(probador, 'uno');
    await elegir(probador, 'Renombrar');
    await probador.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Renombrada',
    );
    await elegir(probador, 'Guardar');
    expect(controlador.notaPorId('uno')!.titulo, 'Renombrada');
    expect(controlador.notaSeleccionada!.id, 'tres');
    await abrir(probador, 'uno');
    await elegir(probador, 'Mover a carpeta');
    await elegir(probador, 'Destino');
    expect(controlador.notaPorId('uno')!.carpeta, 'Destino');
    await abrir(probador, 'uno');
    await elegir(probador, 'Mover a la papelera');
    expect(controlador.notaPorId('uno')!.eliminada, isTrue);
    await elegir(probador, 'Papelera');
    await abrir(probador, 'uno');
    expect(find.text('Renombrar'), findsNothing);
    await elegir(probador, 'Restaurar');
    expect(controlador.notaPorId('uno')!.eliminada, isFalse);
    expect(probador.takeException(), isNull);
  });

  testWidgets('Carpetas: crear dentro, renombrar y confirmar eliminación', (
    probador,
  ) async {
    final controlador = await preparar(probador);
    Future<void> abrirCarpeta(String nombre) async {
      await probador.tap(
        find.byKey(ValueKey('carpeta-$nombre')),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await probador.pumpAndSettle();
    }

    await abrirCarpeta('Proyecto');
    await elegir(probador, 'Nueva nota');
    expect(controlador.notaSeleccionada!.carpeta, 'Proyecto');
    await abrirCarpeta('Proyecto');
    await elegir(probador, 'Renombrar carpeta');
    await probador.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Trabajo',
    );
    await elegir(probador, 'Guardar');
    expect(controlador.notaPorId('uno')!.carpeta, 'Trabajo');
    await abrirCarpeta('Trabajo');
    await elegir(probador, 'Eliminar carpeta');
    await elegir(probador, 'Cancelar');
    expect(controlador.carpetas, contains('Trabajo'));
    await abrirCarpeta('Trabajo');
    await elegir(probador, 'Eliminar carpeta');
    await elegir(probador, 'Eliminar');
    expect(controlador.carpetas, isNot(contains('Trabajo')));
    expect(controlador.notaPorId('uno')!.carpeta, '');
    expect(controlador.notaPorId('uno')!.contenido, 'Contenido uno');
    expect(probador.takeException(), isNull);
  });

  testWidgets('El plugin se gestiona en Opciones y exporta la nota del menú', (
    probador,
  ) async {
    final controlador = await preparar(probador);
    expect(find.byTooltip('Plugins'), findsNothing);
    await probador.tap(find.byTooltip('Opciones'));
    await probador.pumpAndSettle();
    expect(find.text('Plugins'), findsOneWidget);
    expect(
      find
          .byType(ChoiceChip)
          .evaluate()
          .any(
            (elemento) =>
                (elemento.widget as ChoiceChip).label is Text &&
                ((elemento.widget as ChoiceChip).label as Text).data == 'PDF',
          ),
      isFalse,
    );
    final interruptor = find.byKey(const Key('activar-plugin-exportacion'));
    await probador.ensureVisible(interruptor);
    await probador.tap(interruptor);
    await probador.pumpAndSettle();
    expect(controlador.exportacionHabilitada, isFalse);
    await probador.tap(find.byTooltip('Notas'));
    await probador.pumpAndSettle();
    await abrir(probador, 'uno');
    expect(find.text('Exportar a…'), findsNothing);
    await probador.sendKeyEvent(LogicalKeyboardKey.escape);
    await probador.pumpAndSettle();
    await probador.tap(find.byTooltip('Opciones'));
    await probador.pumpAndSettle();
    await probador.ensureVisible(interruptor);
    await probador.tap(interruptor);
    await probador.pumpAndSettle();
    await probador.tap(find.byTooltip('Notas'));
    await probador.pumpAndSettle();
    controlador.actualizarContenido('uno', 'Última versión');
    await probador.pumpAndSettle();
    await abrir(probador, 'uno');
    await elegir(probador, 'Exportar a…');
    for (final formato in ['Markdown', 'HTML', 'PDF', 'ODS']) {
      expect(find.widgetWithText(MenuItemButton, formato), findsOneWidget);
    }
    await elegir(probador, 'HTML');
    expect(selector.archivos.single.nombre, 'Nota uno.html');
    expect(
      utf8.decode(selector.archivos.single.bytes),
      contains('Última versión'),
    );
    expect(
      utf8.decode(selector.archivos.single.bytes),
      isNot(contains('Contenido tres')),
    );
    expect(controlador.notaSeleccionada!.id, 'tres');
    expect(probador.takeException(), isNull);
  });

  testWidgets(
    'Ctrl/Cmd y Mayús seleccionan grupos; el menú exporta solo ese grupo',
    (probador) async {
      final controlador = await preparar(probador);
      for (final tecla in [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.metaLeft,
      ]) {
        await probador.sendKeyDownEvent(tecla);
        await probador.tap(find.byKey(const ValueKey('nota-uno')));
        await probador.sendKeyUpEvent(tecla);
        await probador.pumpAndSettle();
      }
      expect(controlador.notasMarcadas, isEmpty);
      await probador.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await probador.tap(find.byKey(const ValueKey('nota-uno')));
      await probador.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await probador.pumpAndSettle();
      await probador.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await probador.tap(find.byKey(const ValueKey('nota-dos')));
      await probador.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await probador.pumpAndSettle();
      expect(
        controlador.notasMarcadas.map((nota) => nota.id),
        unorderedEquals(['uno', 'dos']),
      );
      await abrir(probador, 'uno');
      expect(find.text('2 notas seleccionadas'), findsOneWidget);
      expect(find.text('Renombrar'), findsNothing);
      await elegir(probador, 'Añadir a favoritas');
      expect(controlador.notaPorId('uno')!.favorita, isTrue);
      expect(controlador.notaPorId('dos')!.favorita, isTrue);
      expect(controlador.notaPorId('tres')!.favorita, isFalse);
      await abrir(probador, 'dos');
      await elegir(probador, 'Exportar a…');
      await elegir(probador, 'Markdown (ZIP)');
      final zip = ZipDecoder().decodeBytes(selector.archivos.single.bytes);
      expect(
        zip.files.map((archivo) => archivo.name),
        unorderedEquals(['Nota uno-uno.md', 'Nota dos-dos.md']),
      );
      await probador.tap(find.byTooltip('Acciones de la selección'));
      await probador.pumpAndSettle();
      await elegir(probador, 'Mover a la papelera');
      expect(controlador.notasActivas.single.id, 'tres');
      await elegir(probador, 'Deshacer');
      expect(controlador.notasActivas, hasLength(3));
      expect(probador.takeException(), isNull);
    },
  );

  testWidgets('Móvil: pulsación larga, casillas y acciones de selección', (
    probador,
  ) async {
    final controlador = await preparar(probador, movil: true);
    await probador.tap(find.byTooltip('Abrir bóveda'));
    await probador.pumpAndSettle();
    await probador.longPress(find.byKey(const ValueKey('nota-tres')));
    await probador.pumpAndSettle();
    await elegir(probador, 'Añadir a favoritas');
    expect(controlador.notaPorId('tres')!.favorita, isTrue);
    await probador.tap(find.byTooltip('Seleccionar notas'));
    await probador.pumpAndSettle();
    await probador.tap(
      find.descendant(
        of: find.byKey(const ValueKey('nota-uno')),
        matching: find.byType(Checkbox),
      ),
    );
    await probador.pumpAndSettle();
    await probador.tap(find.byTooltip('Seleccionar todas'));
    await probador.pumpAndSettle();
    expect(controlador.notasMarcadas, hasLength(3));
    await probador.tap(find.byTooltip('Acciones de la selección'));
    await probador.pumpAndSettle();
    await elegir(probador, 'Mover a carpeta');
    await elegir(probador, 'Destino');
    expect(
      controlador.notas.every((nota) => nota.carpeta == 'Destino'),
      isTrue,
    );
    expect(probador.takeException(), isNull);
  });

  testWidgets(
    'Teclado: menú contextual, selección total y Escape dentro del listado',
    (probador) async {
      final controlador = await preparar(probador);
      final boton = probador.widget<IconButton>(
        find.descendant(
          of: find.byKey(const ValueKey('nota-uno')),
          matching: find.byType(IconButton),
        ),
      );
      boton.focusNode!.requestFocus();
      await probador.pumpAndSettle();
      await probador.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await probador.sendKeyEvent(LogicalKeyboardKey.f10);
      await probador.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await probador.pumpAndSettle();
      expect(find.widgetWithText(MenuItemButton, 'Renombrar'), findsOneWidget);
      await probador.sendKeyEvent(LogicalKeyboardKey.escape);
      await probador.pumpAndSettle();
      expect(find.widgetWithText(MenuItemButton, 'Renombrar'), findsNothing);
      await probador.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await probador.sendKeyEvent(LogicalKeyboardKey.keyA);
      await probador.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await probador.pumpAndSettle();
      expect(controlador.notasMarcadas, hasLength(3));
      await probador.sendKeyEvent(LogicalKeyboardKey.escape);
      await probador.pumpAndSettle();
      expect(controlador.notasMarcadas, isEmpty);
      await probador.tap(find.text('Editar'));
      await probador.pumpAndSettle();
      await probador.tap(find.byKey(const Key('markdown-editor')));
      await probador.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await probador.sendKeyEvent(LogicalKeyboardKey.keyA);
      await probador.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await probador.pumpAndSettle();
      expect(controlador.notasMarcadas, isEmpty);
      final editor = probador.widget<TextField>(
        find.byKey(const Key('markdown-editor')),
      );
      expect(
        editor.controller!.selection.textInside(editor.controller!.text),
        'Contenido tres',
      );
      expect(probador.takeException(), isNull);
    },
  );

  testWidgets(
    'Un clic normal abre una nota tras usar Ctrl sin activar las casillas manualmente',
    (probador) async {
      final controlador = await preparar(probador);
      await probador.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await probador.tap(find.byKey(const ValueKey('nota-uno')));
      await probador.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await probador.pumpAndSettle();
      expect(controlador.notasMarcadas.single.id, 'uno');
      await probador.tap(find.byKey(const ValueKey('nota-dos')));
      await probador.pumpAndSettle();
      expect(controlador.notaSeleccionada!.id, 'dos');
      expect(controlador.notasMarcadas, isEmpty);
      expect(probador.takeException(), isNull);
    },
  );

  testWidgets(
    'Cancelar o fallar al exportar conserva la nota y permite reintentar',
    (probador) async {
      final controlador = await preparar(probador);
      Future<void> exportar() async {
        await abrir(probador, 'uno');
        await elegir(probador, 'Exportar a…');
        await elegir(probador, 'Markdown');
      }

      selector.cancelar = true;
      await exportar();
      expect(find.text('Exportación completada.'), findsNothing);
      selector.cancelar = false;
      selector.fallar = true;
      await exportar();
      expect(find.textContaining('No se ha podido exportar.'), findsOneWidget);
      expect(controlador.notaPorId('uno')!.contenido, 'Contenido uno');
      selector.fallar = false;
      await exportar();
      expect(selector.archivos.single.nombre, 'Nota uno.md');
      expect(probador.takeException(), isNull);
    },
  );
}
