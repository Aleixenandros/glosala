// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glosala/aplicacion/controlador_boveda.dart';
import 'package:glosala/aplicacion_glosala.dart';
import 'package:glosala/dominio/boveda.dart';
import 'package:glosala/dominio/nota.dart';
import 'package:glosala/idiomas/gestor_idiomas.dart';
import 'package:glosala/interfaz/edicion/controlador_texto_nota.dart';
import 'package:glosala/interfaz/edicion/operaciones_markdown.dart';
import 'package:glosala/interfaz/edicion/historial_edicion.dart';

import 'soporte/repositorio_memoria.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GestorIdiomas.instancia.cargar());

  TextEditingValue seleccionar(String texto, [int inicio = 0, int? fin]) =>
      TextEditingValue(
        text: texto,
        selection: TextSelection(
          baseOffset: inicio,
          extentOffset: fin ?? texto.length,
        ),
      );

  test('Negrita alterna y conserva la selección sin acumular símbolos', () {
    final original = seleccionar('Antes idea después', 6, 10);
    final marcado = OperacionesMarkdown.rodear(original, '**', '**', 'texto');
    expect(marcado.text, 'Antes **idea** después');
    expect(marcado.selection.textInside(marcado.text), 'idea');
    expect(OperacionesMarkdown.rodear(marcado, '**', '**', 'texto'), original);
  });

  test(
    'Formato de línea respeta rangos, sangría y el salto final no seleccionado',
    () {
      final original = seleccionar('Uno\n  Dos\nTres', 1, 10);
      final lista = OperacionesMarkdown.formatearLineas(
        original,
        FormatoLinea.lista,
        'Elemento',
      );
      expect(lista.text, '- Uno\n  - Dos\nTres');
      expect(
        OperacionesMarkdown.formatearLineas(
          lista,
          FormatoLinea.lista,
          'Elemento',
        ).text,
        'Uno\n  Dos\nTres',
      );
    },
  );

  test('Listas numeradas, tareas y citas se aplican a todas las líneas', () {
    var valor = seleccionar('Uno\nDos');
    valor = OperacionesMarkdown.formatearLineas(
      valor,
      FormatoLinea.listaNumerada,
      'Elemento',
    );
    expect(valor.text, '1. Uno\n2. Dos');
    valor = OperacionesMarkdown.formatearLineas(
      valor,
      FormatoLinea.tarea,
      'Tarea',
    );
    expect(valor.text, '- [ ] Uno\n- [ ] Dos');
    final cita = OperacionesMarkdown.formatearLineas(
      seleccionar('Uno\n\nDos'),
      FormatoLinea.cita,
      'Cita',
    );
    expect(cita.text, '> Uno\n\n> Dos');
  });

  test(
    'Encabezado actúa en la línea actual sin añadir saltos ni duplicar niveles',
    () {
      final valor = seleccionar('# Título\nOtro', 4, 4);
      final resultado = OperacionesMarkdown.formatearLineas(
        valor,
        FormatoLinea.encabezado,
        'Encabezado',
      );
      expect(resultado.text, '## Título\nOtro');
      expect(
        OperacionesMarkdown.formatearLineas(
          seleccionar('', 0, 0),
          FormatoLinea.lista,
          'Elemento',
        ).text,
        '- Elemento',
      );
    },
  );

  test('La búsqueda es literal, admite Unicode y se actualiza al editar', () {
    final texto = ControladorTextoNota(text: 'Árbol árbol a.b axb');
    addTearDown(texto.dispose);
    texto.buscar('árbol', distinguirMayusculas: false);
    expect(texto.coincidencias, hasLength(2));
    texto.buscar('árbol', distinguirMayusculas: true);
    expect(texto.coincidencias.single.start, 6);
    texto.buscar('a.b', distinguirMayusculas: false);
    expect(texto.coincidencias, hasLength(1));
    texto.text = 'a.b a.b';
    expect(texto.coincidencias, hasLength(2));
    texto.buscar('', distinguirMayusculas: false);
    expect(texto.coincidencias, isEmpty);
  });

  test('El historial guarda el estado inicial, agrupa escritura y descarta rehacer al editar', () {
    final historial = HistorialEdicion(seleccionar('Base'));
    addTearDown(historial.dispose);
    historial.registrar(seleccionar('Base a'));
    historial.registrar(seleccionar('Base ab'));
    expect(historial.deshacer()!.text, 'Base');
    expect(historial.rehacer()!.text, 'Base ab');
    historial.deshacer();
    historial.registrar(seleccionar('Otra versión'));
    expect(historial.value.canRedo, isFalse);
    expect(historial.deshacer()!.text, 'Base');
  });

  Future<ControladorBoveda> preparar(
    WidgetTester probador, {
    bool movil = false,
  }) async {
    probador.view.devicePixelRatio = 1;
    probador.view.physicalSize = movil
        ? const Size(360, 640)
        : const Size(1440, 1000);
    addTearDown(probador.view.resetPhysicalSize);
    addTearDown(probador.view.resetDevicePixelRatio);
    GestorIdiomas.instancia.actual = 'es';
    final repositorio = RepositorioMemoria()
      ..guardada = Boveda(
        notas: [
          Nota(
            id: 'primera',
            titulo: 'Primera',
            contenido: 'Idea idea IDEA',
            creadaEl: DateTime(2026),
            modificadaEl: DateTime(2026),
          ),
          Nota(
            id: 'segunda',
            titulo: 'Segunda',
            contenido: 'Texto independiente',
            creadaEl: DateTime(2026),
            modificadaEl: DateTime(2026),
          ),
        ],
        idSeleccionada: 'primera',
      );
    final controlador = ControladorBoveda(repositorio);
    await controlador.inicializar();
    controlador.cambiarModoEditor(ModoEditor.editar);
    addTearDown(controlador.dispose);
    await probador.pumpWidget(AplicacionGlosala(controller: controlador));
    await probador.pumpAndSettle();
    return controlador;
  }

  Future<void> atajo(WidgetTester probador, LogicalKeyboardKey tecla) async {
    await probador.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await probador.sendKeyEvent(tecla);
    await probador.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await probador.pumpAndSettle();
  }

  testWidgets(
    'Buscar, navegar, reemplazar todo y deshacer conserva la nota original',
    (probador) async {
      final controlador = await preparar(probador);
      await atajo(probador, LogicalKeyboardKey.keyH);
      await probador.enterText(find.byKey(const Key('buscar-en-nota')), 'idea');
      await probador.pumpAndSettle();
      expect(find.text('1 de 3'), findsOneWidget);
      await probador.tap(find.byTooltip('Coincidencia siguiente'));
      await probador.pumpAndSettle();
      expect(find.text('2 de 3'), findsOneWidget);
      final editor = probador.widget<TextField>(
        find.byKey(const Key('markdown-editor')),
      );
      expect(
        editor.controller!.selection.textInside(editor.controller!.text),
        'idea',
      );
      await probador.enterText(
        find.byKey(const Key('reemplazar-en-nota')),
        r'$1',
      );
      await probador.tap(find.byTooltip('Reemplazar todas'));
      await probador.pumpAndSettle();
      expect(controlador.notaPorId('primera')!.contenido, r'$1 $1 $1');
      expect(
        controlador.notaPorId('segunda')!.contenido,
        'Texto independiente',
      );
      await probador.pump(const Duration(milliseconds: 600));
      await probador.tap(find.byTooltip('Cerrar búsqueda'));
      await probador.pumpAndSettle();
      await probador.tap(find.byTooltip('Deshacer'));
      await probador.pumpAndSettle();
      expect(controlador.notaPorId('primera')!.contenido, 'Idea idea IDEA');
      await probador.tap(find.byTooltip('Rehacer'));
      await probador.pumpAndSettle();
      expect(controlador.notaPorId('primera')!.contenido, r'$1 $1 $1');
      await probador.tap(find.byKey(const Key('markdown-editor')));
      await atajo(probador, LogicalKeyboardKey.keyZ);
      expect(controlador.notaPorId('primera')!.contenido, 'Idea idea IDEA');
      await probador.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await atajo(probador, LogicalKeyboardKey.keyZ);
      await probador.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(controlador.notaPorId('primera')!.contenido, r'$1 $1 $1');
      await atajo(probador, LogicalKeyboardKey.keyZ);
      await atajo(probador, LogicalKeyboardKey.keyY);
      expect(controlador.notaPorId('primera')!.contenido, r'$1 $1 $1');
      expect(probador.takeException(), isNull);
    },
  );

  testWidgets(
    'Cambiar de nota reinicia Deshacer sin recuperar contenido ajeno',
    (probador) async {
      final controlador = await preparar(probador);
      await probador.enterText(
        find.byKey(const Key('markdown-editor')),
        'Edición primera',
      );
      await probador.pump(const Duration(milliseconds: 600));
      controlador.seleccionarNota('segunda');
      await probador.pumpAndSettle();
      final deshacer = find.widgetWithIcon(IconButton, Icons.undo);
      expect(probador.widget<IconButton>(deshacer).onPressed, isNull);
      await probador.tap(find.byKey(const Key('markdown-editor')));
      await atajo(probador, LogicalKeyboardKey.keyZ);
      expect(
        controlador.notaPorId('segunda')!.contenido,
        'Texto independiente',
      );
      await probador.enterText(
        find.byKey(const Key('markdown-editor')),
        'Edición segunda',
      );
      await probador.pumpAndSettle();
      await probador.tap(find.byTooltip('Deshacer'));
      await probador.pumpAndSettle();
      expect(
        controlador.notaPorId('segunda')!.contenido,
        'Texto independiente',
      );
      expect(controlador.notaPorId('primera')!.contenido, 'Edición primera');
      expect(probador.takeException(), isNull);
    },
  );

  testWidgets(
    'Buscar distingue mayúsculas y la papelera solo permite lectura',
    (probador) async {
      final controlador = await preparar(probador);
      await atajo(probador, LogicalKeyboardKey.keyF);
      await probador.enterText(find.byKey(const Key('buscar-en-nota')), 'Idea');
      await probador.tap(find.byTooltip('Distinguir mayúsculas'));
      await probador.pumpAndSettle();
      expect(find.text('1 de 1'), findsOneWidget);
      await probador.tap(find.byKey(const Key('buscar-en-nota')));
      await probador.sendKeyEvent(LogicalKeyboardKey.escape);
      await probador.pumpAndSettle();
      expect(find.byKey(const Key('buscar-en-nota')), findsNothing);
      controlador.enviarPapelera('primera');
      controlador.seleccionarNota('primera');
      await probador.pumpAndSettle();
      await atajo(probador, LogicalKeyboardKey.keyH);
      await probador.pumpAndSettle();
      expect(find.byKey(const Key('reemplazar-en-nota')), findsNothing);
      expect(
        probador
            .widget<TextField>(find.byKey(const Key('markdown-editor')))
            .readOnly,
        isTrue,
      );
      expect(controlador.notaPorId('primera')!.contenido, 'Idea idea IDEA');
      expect(probador.takeException(), isNull);
    },
  );

  testWidgets('Búsqueda y reemplazo móvil siguen accesibles con teclado', (
    probador,
  ) async {
    await preparar(probador, movil: true);
    await probador.tap(find.byTooltip('Buscar en esta nota (Ctrl/Cmd+F)'));
    await probador.pumpAndSettle();
    probador.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(probador.view.resetViewInsets);
    await probador.pumpAndSettle();
    await probador.enterText(find.byKey(const Key('buscar-en-nota')), 'idea');
    await probador.pumpAndSettle();
    await probador.ensureVisible(find.text('Reemplazar'));
    await probador.tap(find.text('Reemplazar'));
    await probador.pumpAndSettle();
    expect(find.byKey(const Key('reemplazar-en-nota')), findsOneWidget);
    expect(probador.takeException(), isNull);
  });
}
