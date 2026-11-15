import 'package:flutter_test/flutter_test.dart';
import 'package:glosala/aplicacion/controlador_boveda.dart';
import 'package:glosala/dominio/nota.dart';

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
  test(
    'La ordenación respeta acentos, conserva la selección y persiste',
    () async {
      controlador.aplicarSincronizacion([
        for (final (indice, titulo) in ['Zeta', 'Ñu', 'Álamo', 'nube'].indexed)
          Nota(
            id: 'orden-$indice',
            titulo: titulo,
            contenido: '',
            creadaEl: DateTime(2026, 1, indice + 1),
            modificadaEl: DateTime(2026, 1, 4 - indice),
          ),
      ], []);
      expect(controlador.notasVisibles.first.titulo, 'Zeta');
      controlador.marcarNota('orden-0');
      controlador.cambiarOrdenNotas(OrdenNotas.tituloAscendente);
      expect(controlador.notasVisibles.map((nota) => nota.titulo), [
        'Álamo',
        'nube',
        'Ñu',
        'Zeta',
      ]);
      expect(controlador.notasMarcadas.single.id, 'orden-0');
      controlador.cambiarOrdenNotas(OrdenNotas.creadas);
      expect(controlador.notasVisibles.first.titulo, 'nube');
      controlador.cambiarOrdenNotas(OrdenNotas.tituloDescendente);
      await controlador.guardarPendientes();
      final reabierto = ControladorBoveda(repositorio);
      await reabierto.inicializar();
      expect(reabierto.ordenNotas, OrdenNotas.tituloDescendente);
      expect(reabierto.notasVisibles.map((nota) => nota.titulo), [
        'Zeta',
        'Ñu',
        'nube',
        'Álamo',
      ]);
      reabierto.dispose();
    },
  );

  test(
    'Duplicar un lote crea copias independientes con títulos únicos',
    () async {
      final primera = controlador.crearNota(
        titulo: 'Proyecto',
        contenido: '[[Destino]]',
        enCarpeta: 'Trabajo',
      );
      controlador.alternarFavorita(primera.id);
      final segunda = controlador.crearNota(
        titulo: 'Proyecto',
        contenido: 'Dos',
      );
      final papelera = controlador.crearNota(titulo: 'Eliminada');
      controlador.enviarPapelera(papelera.id);
      final copias = controlador.duplicarNotas([
        primera.id,
        primera.id,
        segunda.id,
        papelera.id,
      ]);
      expect(copias, hasLength(2));
      expect(copias.first.titulo, 'Proyecto (3)');
      expect(copias.first.carpeta, 'Trabajo');
      expect(copias.first.favorita, isTrue);
      expect(
        controlador.notasMarcadas.map((nota) => nota.id),
        unorderedEquals(copias.map((nota) => nota.id)),
      );
      controlador.actualizarContenido(copias.first.id, 'Copia editada');
      await controlador.guardarPendientes();
      expect(controlador.notaPorId(primera.id)!.contenido, '[[Destino]]');
      expect(
        repositorio.guardada!.notas.map((nota) => nota.id).toSet().length,
        controlador.notas.length,
      );
    },
  );

  test(
    'Añadir ejemplos conserva las notas existentes y enlaza las nuevas copias',
    () {
      final existentes = {
        for (final nota in controlador.notas) nota.id: nota.aJson(),
      };
      controlador.anadirNotasEjemplo();
      final nuevas = controlador.notas
          .where((nota) => !existentes.containsKey(nota.id))
          .toList();
      expect(nuevas, hasLength(3));
      for (final anterior in existentes.entries) {
        expect(controlador.notaPorId(anterior.key)!.aJson(), anterior.value);
      }
      final titulos = nuevas.map((nota) => nota.titulo).toSet();
      for (final nota in nuevas) {
        expect(titulos.containsAll(nota.enlaces), isTrue);
      }
    },
  );
}
