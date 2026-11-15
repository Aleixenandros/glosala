import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../datos/repositorio_boveda.dart';
import '../datos/notas_bienvenida.dart';
import '../dominio/nota.dart';
import '../dominio/boveda.dart';
import '../dominio/tarea.dart';

enum FiltroNotas { todas, favoritas, papelera }

enum EstadoGuardado { guardado, guardando, error }

enum ModoEditor { editar, dividir, leer }

enum OrdenNotas { modificadas, creadas, tituloAscendente, tituloDescendente }

class ControladorBoveda extends ChangeNotifier {
  ControladorBoveda(this.repositorio);

  final RepositorioBoveda repositorio;
  final List<Nota> _notas = [];
  final List<String> _carpetas = [];
  final List<String> _idsAbiertas = [];
  final Set<String> _idsMarcadas = {};
  String? _idAnclaSeleccion;
  final List<Tarea> _tareas = [];
  final Map<String, dynamic> _preferencias = {};
  List<Tarea> get tareas => List.unmodifiable(_tareas);
  Map<String, dynamic> get preferencias => Map.unmodifiable(_preferencias);
  bool get exportacionHabilitada =>
      _preferencias['plugin_exportacion'] as bool? ?? true;
  OrdenNotas get ordenNotas =>
      OrdenNotas.values
          .where((orden) => orden.name == _preferencias['orden_notas'])
          .firstOrNull ??
      OrdenNotas.modificadas;

  void cambiarOrdenNotas(OrdenNotas orden) {
    _idAnclaSeleccion = null;
    configurar('orden_notas', orden.name);
  }

  void configurar(String clave, dynamic valor) {
    _preferencias[clave] = valor;
    _cambio();
  }

  void anadirTarea(String titulo, {String? padre}) {
    if (titulo.trim().isEmpty) return;
    final nueva = Tarea(id: const Uuid().v4(), titulo: titulo.trim());
    if (padre == null) {
      _tareas.add(nueva);
    } else {
      _transformarTarea(
        padre,
        (tarea) => tarea.copiar(
          completada: false,
          subtareas: [...tarea.subtareas, nueva],
        ),
      );
    }
    _cambio();
  }

  void editarTarea(String id, String titulo) {
    if (titulo.trim().isEmpty) return;
    _transformarTarea(id, (tarea) => tarea.copiar(titulo: titulo.trim()));
    _cambio();
  }

  void completarTarea(String id, bool completada) {
    Tarea completar(Tarea tarea) => tarea.copiar(
      completada: completada,
      subtareas: tarea.subtareas.map(completar).toList(),
    );
    _transformarTarea(id, completar);
    _cambio();
  }

  void eliminarTarea(String id) {
    List<Tarea> eliminar(List<Tarea> tareas) =>
        tareas.where((t) => t.id != id).map((t) {
          final hijas = eliminar(t.subtareas);
          return t.copiar(
            subtareas: hijas,
            completada: hijas.isEmpty
                ? t.completada
                : hijas.every((h) => h.completada),
          );
        }).toList();
    final resultado = eliminar(_tareas);
    _tareas
      ..clear()
      ..addAll(resultado);
    _cambio();
  }

  void _transformarTarea(String id, Tarea Function(Tarea) transformar) {
    Tarea visitar(Tarea tarea) {
      if (tarea.id == id) return transformar(tarea);
      final hijas = tarea.subtareas.map(visitar).toList();
      return tarea.copiar(
        subtareas: hijas,
        completada: hijas.isEmpty
            ? tarea.completada
            : hijas.every((h) => h.completada),
      );
    }

    final resultado = _tareas.map(visitar).toList();
    _tareas
      ..clear()
      ..addAll(resultado);
  }

  void aplicarSincronizacion(List<Nota> notas, List<String> carpetas) {
    _notas
      ..clear()
      ..addAll(notas);
    _carpetas
      ..clear()
      ..addAll(carpetas);
    if (carpeta != null && !this.carpetas.contains(carpeta)) carpeta = null;
    _cambio();
  }

  String? _idSeleccionada;
  String busqueda = '';
  String? carpeta;
  String? tag;
  FiltroNotas filtro = FiltroNotas.todas;
  ModoEditor modoEditor = ModoEditor.leer;
  bool modoOscuro = true;
  bool mapaVisible = false;
  bool cargada = false;
  EstadoGuardado estadoGuardado = EstadoGuardado.guardado;
  String? errorLectura;
  String? errorGuardado;
  int _revision = 0;
  int _revisionGuardada = 0;
  Future<void>? _guardadoEnCurso;
  bool _cerrado = false;

  List<Nota> get notas => List.unmodifiable(_notas);
  List<Nota> get notasActivas =>
      _notas.where((nota) => !nota.eliminada).toList();
  List<String> get carpetas => {
    ..._carpetas,
    ..._notas.map((n) => n.carpeta),
  }.where((carpeta) => carpeta.isNotEmpty).toList()..sort();
  List<String> get etiquetas =>
      notasActivas.expand((nota) => nota.etiquetas).toSet().toList()..sort();
  Nota? get notaSeleccionada => notaPorId(_idSeleccionada);
  List<Nota> get notasAbiertas =>
      _idsAbiertas.map(notaPorId).whereType<Nota>().toList();
  List<Nota> get notasMarcadas => _idsMarcadas.isEmpty
      ? []
      : notasVisibles.where((nota) => _idsMarcadas.contains(nota.id)).toList();

  void marcarNota(String id, {bool rango = false, bool acumular = true}) {
    final visibles = notasVisibles.map((nota) => nota.id).toList();
    final indice = visibles.indexOf(id);
    if (indice < 0) return;
    final ancla = visibles.indexOf(_idAnclaSeleccion ?? _idSeleccionada ?? id);
    if (rango && ancla >= 0) {
      if (!acumular) _idsMarcadas.clear();
      final inicio = indice < ancla ? indice : ancla;
      final fin = indice > ancla ? indice : ancla;
      _idsMarcadas.addAll(visibles.sublist(inicio, fin + 1));
    } else {
      if (!_idsMarcadas.remove(id)) _idsMarcadas.add(id);
      _idAnclaSeleccion = id;
    }
    _notificar();
  }

  void marcarTodasVisibles() {
    _idsMarcadas
      ..clear()
      ..addAll(notasVisibles.map((nota) => nota.id));
    _notificar();
  }

  void limpiarSeleccion() {
    _idsMarcadas.clear();
    _idAnclaSeleccion = null;
    _notificar();
  }

  Nota? notaPorId(String? id) {
    for (final nota in _notas) {
      if (nota.id == id) return nota;
    }
    return null;
  }

  Nota? notaPorTitulo(String titulo) {
    for (final nota in notasActivas) {
      if (nota.titulo.toLowerCase() == titulo.trim().toLowerCase()) return nota;
    }
    return null;
  }

  List<Nota> get notasVisibles {
    final palabras = busqueda.toLowerCase().trim().split(RegExp(r'\s+'));
    final visibles = _notas.where((nota) {
      if (nota.eliminada != (filtro == FiltroNotas.papelera)) return false;
      if (filtro == FiltroNotas.favoritas && !nota.favorita) return false;
      if (carpeta != null && nota.carpeta != carpeta) return false;
      if (tag != null && !nota.etiquetas.contains(tag)) return false;
      final textoBuscable = '${nota.titulo}\n${nota.contenido}'.toLowerCase();
      return palabras.every(textoBuscable.contains);
    }).toList();
    final orden = ordenNotas;
    final titulos = {
      for (final nota in visibles) nota.id: _claveTitulo(nota.titulo),
    };
    return visibles..sort((a, b) {
      final comparacion = switch (orden) {
        OrdenNotas.modificadas => b.modificadaEl.compareTo(a.modificadaEl),
        OrdenNotas.creadas => b.creadaEl.compareTo(a.creadaEl),
        OrdenNotas.tituloAscendente => titulos[a.id]!.compareTo(titulos[b.id]!),
        OrdenNotas.tituloDescendente => titulos[b.id]!.compareTo(
          titulos[a.id]!,
        ),
      };
      if (comparacion != 0) return comparacion;
      final titulo = titulos[a.id]!.compareTo(titulos[b.id]!);
      return titulo != 0 ? titulo : a.id.compareTo(b.id);
    });
  }

  static const _letrasOrden = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'å': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n\uffff',
  };
  static final _acentosOrden = RegExp('[${_letrasOrden.keys.join()}]');
  String _claveTitulo(String titulo) => titulo.toLowerCase().replaceAllMapped(
    _acentosOrden,
    (coincidencia) => _letrasOrden[coincidencia[0]]!,
  );

  List<Nota> enlacesEntrantes(Nota destino) => notasActivas
      .where(
        (nota) =>
            nota.id != destino.id &&
            nota.enlaces.any(
              (link) => link.toLowerCase() == destino.titulo.toLowerCase(),
            ),
      )
      .toList();

  Boveda get instantanea => Boveda(
    notas: List.of(_notas),
    carpetas: List.of(_carpetas),
    idSeleccionada: _idSeleccionada,
    modoOscuro: modoOscuro,
    tareas: List.of(_tareas),
    preferencias: Map.of(_preferencias),
  );

  Future<void> inicializar() async {
    errorLectura = null;
    _notificar();
    try {
      final almacenada = await repositorio.cargar();
      final boveda = almacenada ?? bovedaBienvenida();
      _notas
        ..clear()
        ..addAll(boveda.notas);
      _carpetas
        ..clear()
        ..addAll(boveda.carpetas);
      _tareas
        ..clear()
        ..addAll(boveda.tareas);
      _preferencias
        ..clear()
        ..addAll(boveda.preferencias);
      modoOscuro = boveda.modoOscuro;
      _idSeleccionada =
          notaPorId(boveda.idSeleccionada)?.id ?? notasActivas.firstOrNull?.id;
      _idsAbiertas.clear();
      if (_idSeleccionada != null) _idsAbiertas.add(_idSeleccionada!);
      cargada = true;
      if (almacenada == null) {
        _revision++;
        await guardarPendientes();
      }
    } catch (error) {
      errorLectura = error.toString();
    }
    _notificar();
  }

  void cambiarBusqueda(String value) {
    busqueda = value;
    limpiarSeleccion();
  }

  void cambiarFiltro(
    FiltroNotas value, {
    String? enCarpeta,
    String? conEtiqueta,
  }) {
    filtro = value;
    carpeta = enCarpeta;
    tag = conEtiqueta;
    mapaVisible = false;
    limpiarSeleccion();
  }

  void mostrarMapa(bool value) {
    mapaVisible = value;
    _notificar();
  }

  void cambiarModoEditor(ModoEditor mode) {
    modoEditor = mode;
    _notificar();
  }

  void alternarTema() {
    modoOscuro = !modoOscuro;
    _preferencias['apariencia'] = modoOscuro ? 'oscuro' : 'claro';
    _cambio();
  }

  void seleccionarNota(String id) {
    if (notaPorId(id) == null) return;
    _idSeleccionada = id;
    if (!_idsAbiertas.contains(id)) _idsAbiertas.add(id);
    mapaVisible = false;
    _cambio();
  }

  void cerrarPestana(String id) {
    _idsAbiertas.remove(id);
    if (_idSeleccionada == id) _idSeleccionada = _idsAbiertas.lastOrNull;
    _cambio();
  }

  String _tituloUnico(String candidato) {
    final base = candidato.trim().isEmpty ? 'Sin título' : candidato.trim();
    var titulo = base;
    var sufijo = 2;
    while (notaPorTitulo(titulo) != null) {
      titulo = '$base (${sufijo++})';
    }
    return titulo;
  }

  Nota crearNota({
    String titulo = 'Sin título',
    String contenido = '',
    String? enCarpeta,
  }) {
    final ahora = DateTime.now();
    final nota = Nota(
      id: const Uuid().v4(),
      titulo: _tituloUnico(titulo),
      contenido: contenido,
      carpeta: enCarpeta ?? carpeta ?? '',
      creadaEl: ahora,
      modificadaEl: ahora,
    );
    _notas.add(nota);
    _idSeleccionada = nota.id;
    _idsAbiertas.add(nota.id);
    filtro = FiltroNotas.todas;
    carpeta = null;
    tag = null;
    busqueda = '';
    mapaVisible = false;
    modoEditor = ModoEditor.editar;
    _idsMarcadas.clear();
    _idAnclaSeleccion = null;
    _cambio();
    return nota;
  }

  void abrirEnlaceInterno(String titulo) {
    final existente = notaPorTitulo(titulo);
    if (existente != null) {
      seleccionarNota(existente.id);
    } else if (titulo.trim().isNotEmpty) {
      crearNota(titulo: titulo.trim());
    }
  }

  List<Nota> duplicarNotas(Iterable<String> ids) {
    final seleccion = ids.toSet();
    final originales = notasActivas
        .where((nota) => seleccion.contains(nota.id))
        .toList();
    final nuevas = <Nota>[];
    final ahora = DateTime.now();
    for (final original in originales) {
      final copia = Nota(
        id: const Uuid().v4(),
        titulo: _tituloUnico(original.titulo),
        contenido: original.contenido,
        carpeta: original.carpeta,
        favorita: original.favorita,
        creadaEl: ahora,
        modificadaEl: ahora,
      );
      _notas.add(copia);
      nuevas.add(copia);
    }
    if (nuevas.isEmpty) return nuevas;
    filtro = FiltroNotas.todas;
    carpeta = null;
    tag = null;
    busqueda = '';
    mapaVisible = false;
    _idsMarcadas.clear();
    if (nuevas.length > 1) _idsMarcadas.addAll(nuevas.map((nota) => nota.id));
    _idAnclaSeleccion = nuevas.first.id;
    _idSeleccionada = nuevas.first.id;
    _idsAbiertas.add(nuevas.first.id);
    modoEditor = ModoEditor.editar;
    _cambio();
    return nuevas;
  }

  void anadirNotasEjemplo() {
    final ejemplos = bovedaBienvenida().notas;
    final nuevas = <Nota>[];
    final titulos = <String, String>{};
    for (final ejemplo in ejemplos) {
      final nueva = crearNota(
        titulo: ejemplo.titulo,
        contenido: ejemplo.contenido,
        enCarpeta: ejemplo.carpeta,
      );
      titulos[ejemplo.titulo] = nueva.titulo;
      nuevas.add(nueva);
    }
    for (final nota in nuevas) {
      var contenido = nota.contenido;
      for (final entrada in titulos.entries) {
        contenido = SintaxisEnlaceInterno.renombrarDestino(
          contenido,
          entrada.key,
          entrada.value,
        );
      }
      actualizarContenido(nota.id, contenido);
    }
    seleccionarNota(nuevas.first.id);
    cambiarModoEditor(ModoEditor.leer);
  }

  void actualizarContenido(String id, String contenido) {
    final nota = notaPorId(id);
    if (nota == null || nota.eliminada || nota.contenido == contenido) return;
    _reemplazar(
      nota.copiar(contenido: contenido, modificadaEl: DateTime.now()),
    );
    _cambio();
  }

  /// Los títulos son únicos para que los enlaces internos se resuelvan sin ambigüedad.
  String? renombrarNota(String id, String titulo) {
    final nota = notaPorId(id);
    final recortado = titulo.trim();
    if (nota == null) return 'No se ha encontrado la nota.';
    if (recortado.isEmpty) return 'Escribe un título.';
    if (recortado.contains(RegExp(r'[\[\]|\n\r]'))) {
      return 'El título no puede contener corchetes, | ni saltos de línea.';
    }
    final existente = notaPorTitulo(recortado);
    if (existente != null && existente.id != id) {
      return 'Ya existe una nota con ese título.';
    }
    final ahora = DateTime.now();
    for (var i = 0; i < _notas.length; i++) {
      final actual = _notas[i];
      final contenido = SintaxisEnlaceInterno.renombrarDestino(
        actual.contenido,
        nota.titulo,
        recortado,
      );
      if (contenido != actual.contenido || actual.id == id) {
        _notas[i] = actual.copiar(
          titulo: actual.id == id ? recortado : actual.titulo,
          contenido: contenido,
          modificadaEl: ahora,
        );
      }
    }
    _cambio();
    return null;
  }

  String? anadirCarpeta(String value) {
    final name = value.trim();
    if (name.isEmpty) return 'Escribe un nombre para la carpeta.';
    if (carpetas.any((f) => f.toLowerCase() == name.toLowerCase())) {
      return 'Esa carpeta ya existe.';
    }
    _carpetas.add(name);
    cambiarFiltro(FiltroNotas.todas, enCarpeta: name);
    _cambio();
    return null;
  }

  void moverNota(String id, String destino) {
    moverNotas([id], destino);
  }

  void moverNotas(Iterable<String> ids, String destino) {
    final seleccion = ids.toSet();
    final ahora = DateTime.now();
    for (var i = 0; i < _notas.length; i++) {
      if (seleccion.contains(_notas[i].id) && !_notas[i].eliminada) {
        _notas[i] = _notas[i].copiar(carpeta: destino, modificadaEl: ahora);
      }
    }
    _cambio();
  }

  String? renombrarCarpeta(String origen, String nombre) {
    final destino = nombre.trim();
    if (!carpetas.contains(origen)) return 'No se ha encontrado la carpeta.';
    if (destino.isEmpty) return 'Escribe un nombre para la carpeta.';
    if (carpetas.any(
      (actual) =>
          actual != origen && actual.toLowerCase() == destino.toLowerCase(),
    )) {
      return 'Esa carpeta ya existe.';
    }
    if (origen == destino) return null;
    _carpetas.remove(origen);
    _carpetas.add(destino);
    _trasladarContenidoCarpeta(origen, destino);
    if (carpeta == origen) carpeta = destino;
    _cambio();
    return null;
  }

  /// Elimina la agrupación y conserva todas las notas, incluidas las eliminadas.
  void eliminarCarpeta(String nombre) {
    if (!carpetas.contains(nombre)) return;
    _carpetas.remove(nombre);
    _trasladarContenidoCarpeta(nombre, '');
    if (carpeta == nombre) carpeta = null;
    _cambio();
  }

  void _trasladarContenidoCarpeta(String origen, String destino) {
    final ahora = DateTime.now();
    for (var i = 0; i < _notas.length; i++) {
      if (_notas[i].carpeta == origen) {
        _notas[i] = _notas[i].copiar(carpeta: destino, modificadaEl: ahora);
      }
    }
  }

  void alternarFavorita(String id) {
    final nota = notaPorId(id);
    if (nota == null) return;
    marcarFavoritas([id], !nota.favorita);
  }

  void marcarFavoritas(Iterable<String> ids, bool favorita) {
    final seleccion = ids.toSet();
    final ahora = DateTime.now();
    for (var i = 0; i < _notas.length; i++) {
      if (seleccion.contains(_notas[i].id) && !_notas[i].eliminada) {
        _notas[i] = _notas[i].copiar(favorita: favorita, modificadaEl: ahora);
      }
    }
    _cambio();
  }

  void enviarPapelera(String id) {
    enviarNotasPapelera([id]);
  }

  void enviarNotasPapelera(Iterable<String> ids) {
    final seleccion = ids.toSet();
    final ahora = DateTime.now();
    for (var i = 0; i < _notas.length; i++) {
      if (seleccion.contains(_notas[i].id)) {
        _notas[i] = _notas[i].copiar(eliminada: true, modificadaEl: ahora);
      }
    }
    _idsAbiertas.removeWhere(seleccion.contains);
    _idsMarcadas.removeAll(seleccion);
    if (seleccion.contains(_idSeleccionada)) {
      _idSeleccionada = _idsAbiertas.lastOrNull;
    }
    _cambio();
  }

  void restaurarNota(String id) {
    restaurarNotas([id]);
  }

  void restaurarNotas(Iterable<String> ids) {
    String? ultima;
    for (final id in ids.toSet()) {
      final nota = notaPorId(id);
      if (nota == null || !nota.eliminada) continue;
      _reemplazar(
        nota.copiar(
          titulo: _tituloUnico(nota.titulo),
          eliminada: false,
          modificadaEl: DateTime.now(),
        ),
      );
      ultima = id;
    }
    if (ultima == null) return;
    cambiarFiltro(FiltroNotas.todas);
    seleccionarNota(ultima);
  }

  void _reemplazar(Nota nota) =>
      _notas[_notas.indexWhere((n) => n.id == nota.id)] = nota;

  void _cambio() {
    if (_idsMarcadas.isNotEmpty) {
      _idsMarcadas.retainAll(notasVisibles.map((nota) => nota.id));
    }
    _revision++;
    _notificar();
    // Las escrituras serializadas agrupan los cambios recibidos durante un guardado.
    unawaited(guardarPendientes());
  }

  Future<void> guardarPendientes() {
    if (!cargada || _revision == _revisionGuardada) return Future.value();
    return _guardadoEnCurso ??= _vaciarGuardados().whenComplete(
      () => _guardadoEnCurso = null,
    );
  }

  Future<void> _vaciarGuardados() async {
    estadoGuardado = EstadoGuardado.guardando;
    errorGuardado = null;
    _notificar();
    try {
      while (_revisionGuardada != _revision) {
        final revision = _revision;
        await repositorio.guardar(instantanea);
        _revisionGuardada = revision;
      }
      estadoGuardado = EstadoGuardado.guardado;
    } catch (error) {
      estadoGuardado = EstadoGuardado.error;
      errorGuardado = error.toString();
    }
    _notificar();
  }

  void _notificar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    unawaited(guardarPendientes().then((_) => repositorio.cerrar()));
    super.dispose();
  }
}
