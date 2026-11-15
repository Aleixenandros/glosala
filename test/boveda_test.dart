import 'package:flutter_test/flutter_test.dart';
import 'package:glosala/aplicacion/controlador_boveda.dart';

import 'soporte/repositorio_memoria.dart';

void main() {
  late RepositorioMemoria repositorio;
  late ControladorBoveda controlador;
  setUp(() async {
    repositorio = RepositorioMemoria();
    controlador = ControladorBoveda(repositorio);
    await controlador.inicializar();
  });
  tearDown(() async {
    await controlador.guardarPendientes();
    controlador.dispose();
  });

  test(
    'Guarda la última edición al escribir y cambiar de nota rápidamente',
    () async {
      final primera = controlador.crearNota(titulo: 'Primera');
      controlador.actualizarContenido(primera.id, 'uno');
      controlador.actualizarContenido(primera.id, 'dos');
      final segunda = controlador.crearNota(titulo: 'Segunda');
      controlador.actualizarContenido(segunda.id, 'tres');
      await controlador.guardarPendientes();
      expect(
        repositorio.guardada!.notas
            .firstWhere((n) => n.id == primera.id)
            .contenido,
        'dos',
      );
      expect(
        repositorio.guardada!.notas
            .firstWhere((n) => n.id == segunda.id)
            .contenido,
        'tres',
      );
      expect(controlador.estadoGuardado, EstadoGuardado.guardado);
    },
  );

  test(
    'Un fallo de guardado mantiene los cambios y permite reintentar',
    () async {
      repositorio.fallar = true;
      final nota = controlador.crearNota(contenido: 'No perder');
      await controlador.guardarPendientes();
      expect(controlador.estadoGuardado, EstadoGuardado.error);
      expect(controlador.notaPorId(nota.id)!.contenido, 'No perder');
      repositorio.fallar = false;
      await controlador.guardarPendientes();
      expect(controlador.estadoGuardado, EstadoGuardado.guardado);
      expect(
        repositorio.guardada!.notas.any((n) => n.contenido == 'No perder'),
        isTrue,
      );
    },
  );

  test('Renombrado actualiza enlaces y resuelve duplicados', () {
    final destino = controlador.crearNota(titulo: 'Destino');
    final origen = controlador.crearNota(
      titulo: 'Origen',
      contenido: '[[Destino|alias]]',
    );
    expect(controlador.renombrarNota(destino.id, 'Origen'), isNotNull);
    expect(controlador.renombrarNota(destino.id, 'Nuevo'), isNull);
    expect(controlador.notaPorId(origen.id)!.contenido, '[[Nuevo|alias]]');
    expect(
      controlador
          .enlacesEntrantes(controlador.notaPorId(destino.id)!)
          .single
          .id,
      origen.id,
    );
  });

  test(
    'Papelera y restauración conservan contenido y evitan títulos repetidos',
    () {
      final nota = controlador.crearNota(
        titulo: 'Idea',
        contenido: 'Importante',
      );
      controlador.enviarPapelera(nota.id);
      expect(controlador.notasActivas.any((n) => n.id == nota.id), isFalse);
      controlador.crearNota(titulo: 'Idea');
      controlador.restaurarNota(nota.id);
      expect(controlador.notaPorId(nota.id)!.titulo, 'Idea (2)');
      expect(controlador.notaPorId(nota.id)!.contenido, 'Importante');
    },
  );

  test('Búsqueda por contenido, carpeta, etiqueta y favorita', () {
    controlador.anadirCarpeta('Investigación');
    final nota = controlador.crearNota(
      titulo: 'Lectura',
      contenido: 'Árbol de ideas #aprendizaje',
      enCarpeta: 'Investigación',
    );
    controlador.alternarFavorita(nota.id);
    controlador.cambiarFiltro(
      FiltroNotas.favoritas,
      enCarpeta: 'Investigación',
      conEtiqueta: 'aprendizaje',
    );
    controlador.cambiarBusqueda('árbol ideas');
    expect(controlador.notasVisibles.single.id, nota.id);
  });

  test('Tareas recursivas actualizan sus padres y persisten', () async {
    controlador.anadirTarea('Proyecto');
    final padre = controlador.tareas.single.id;
    controlador.anadirTarea('Diseño', padre: padre);
    controlador.anadirTarea('Código', padre: padre);
    var tareas = controlador.tareas.single.subtareas;
    controlador.completarTarea(tareas.first.id, true);
    expect(controlador.tareas.single.completada, isFalse);
    controlador.completarTarea(tareas.last.id, true);
    expect(controlador.tareas.single.completada, isTrue);
    controlador.anadirTarea('Pruebas', padre: padre);
    expect(controlador.tareas.single.completada, isFalse);
    await controlador.guardarPendientes();
    expect(repositorio.guardada!.tareas.single.subtareas, hasLength(3));
    controlador.completarTarea(padre, true);
    expect(
      controlador.tareas.single.subtareas.every((t) => t.completada),
      isTrue,
    );
  });

  test(
    'Renombrar y eliminar carpetas conserva notas y papelera al reabrir',
    () async {
      controlador.anadirCarpeta('Borradores');
      final activa = controlador.crearNota(
        enCarpeta: 'Borradores',
        contenido: 'Conservar',
      );
      final eliminada = controlador.crearNota(enCarpeta: 'Borradores');
      controlador.enviarPapelera(eliminada.id);
      controlador.anadirCarpeta('Archivo');
      controlador.cambiarFiltro(FiltroNotas.todas, enCarpeta: 'Borradores');
      expect(controlador.renombrarCarpeta('Borradores', ' '), isNotNull);
      expect(controlador.renombrarCarpeta('Borradores', 'archivo'), isNotNull);
      expect(controlador.renombrarCarpeta('Borradores', 'Revisados'), isNull);
      expect(controlador.carpeta, 'Revisados');
      expect(controlador.notaPorId(eliminada.id)!.carpeta, 'Revisados');
      controlador.eliminarCarpeta('Revisados');
      await controlador.guardarPendientes();
      final reabierto = ControladorBoveda(repositorio);
      await reabierto.inicializar();
      expect(reabierto.carpetas, isNot(contains('Revisados')));
      expect(reabierto.carpetas, isNot(contains('Borradores')));
      expect(reabierto.notaPorId(activa.id)!.carpeta, '');
      expect(reabierto.notaPorId(activa.id)!.contenido, 'Conservar');
      expect(reabierto.notaPorId(eliminada.id)!.eliminada, isTrue);
      expect(controlador.carpeta, isNull);
      reabierto.dispose();
    },
  );

  test('La selección por rango y todos solo incluye las notas visibles', () {
    controlador.crearNota(titulo: 'Selección A', enCarpeta: 'Grupo');
    controlador.crearNota(titulo: 'Selección B', enCarpeta: 'Grupo');
    controlador.crearNota(titulo: 'Selección C', enCarpeta: 'Grupo');
    controlador.cambiarFiltro(FiltroNotas.todas, enCarpeta: 'Grupo');
    final visibles = controlador.notasVisibles;
    controlador.marcarNota(visibles.first.id);
    controlador.marcarNota(visibles.last.id, rango: true, acumular: false);
    expect(controlador.notasMarcadas, hasLength(3));
    controlador.marcarNota(visibles[1].id);
    expect(controlador.notasMarcadas, hasLength(2));
    controlador.cambiarBusqueda('Selección B');
    expect(controlador.notasMarcadas, isEmpty);
    controlador.marcarTodasVisibles();
    expect(controlador.notasMarcadas.single.titulo, 'Selección B');
    controlador.cambiarFiltro(FiltroNotas.papelera);
    expect(controlador.notasMarcadas, isEmpty);
  });

  test(
    'Acciones por lote y restauración afectan solo a sus identificadores',
    () async {
      final primera = controlador.crearNota(titulo: 'Lote A', contenido: 'Uno');
      final segunda = controlador.crearNota(titulo: 'Lote B', contenido: 'Dos');
      final tercera = controlador.crearNota(titulo: 'Fuera del lote');
      final ids = [primera.id, segunda.id];
      controlador.moverNotas(ids, 'Destino');
      controlador.marcarFavoritas(ids, true);
      controlador.enviarNotasPapelera(ids);
      controlador.crearNota(titulo: 'Lote A');
      controlador.restaurarNotas(ids);
      await controlador.guardarPendientes();
      final guardadas = repositorio.guardada!.notas;
      for (final id in ids) {
        final nota = guardadas.firstWhere((nota) => nota.id == id);
        expect(nota.favorita, isTrue);
        expect(nota.carpeta, 'Destino');
        expect(nota.eliminada, isFalse);
      }
      expect(controlador.notaPorId(primera.id)!.titulo, 'Lote A (2)');
      expect(controlador.notaPorId(tercera.id)!.carpeta, '');
      expect(controlador.notaPorId(tercera.id)!.favorita, isFalse);
    },
  );
}
