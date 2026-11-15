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
}
