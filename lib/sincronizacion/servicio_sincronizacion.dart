import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../aplicacion/controlador_boveda.dart';
import '../dominio/boveda.dart';
import '../dominio/nota.dart';
import 'transporte.dart';

String huellaNota(Nota nota) =>
    sha256.convert(utf8.encode(jsonEncode(nota.aJson()))).toString();

class ResultadoMezcla {
  const ResultadoMezcla(this.notas, this.conflictos);
  final List<Nota> notas;
  final int conflictos;
}

/// Mezcla de tres versiones. Conserva ambas notas si los dos dispositivos
/// cambiaron el mismo documento desde la última sincronización.
ResultadoMezcla mezclarNotas(
  List<Nota> locales,
  List<Nota> remotas,
  Map<String, String> base,
) {
  final resultado = {for (final nota in locales) nota.id: nota};
  var conflictos = 0;
  for (final remota in remotas) {
    final local = resultado[remota.id];
    if (local == null) {
      resultado[remota.id] = remota;
      continue;
    }
    final huellaLocal = huellaNota(local);
    final huellaRemota = huellaNota(remota);
    if (huellaLocal == huellaRemota || huellaRemota == base[local.id]) continue;
    if (huellaLocal == base[local.id]) {
      resultado[remota.id] = remota;
      continue;
    }
    final idConflicto = '${remota.id}-${huellaRemota.substring(0, 12)}';
    if (!resultado.containsKey(idConflicto)) {
      resultado[idConflicto] = Nota.desdeJson({
        ...remota.aJson(),
        'id': idConflicto,
        'title': '${remota.titulo} (conflicto ${huellaRemota.substring(0, 6)})',
        'isDeleted': false,
      });
      conflictos++;
    }
  }
  // Los títulos son únicos para mantener una resolución inequívoca de [[enlaces]].
  final titulos = <String>{};
  final notas = resultado.values.map((nota) {
    if (nota.eliminada) return nota;
    var titulo = nota.titulo;
    var sufijo = 2;
    while (titulos.contains(titulo.toLowerCase())) {
      titulo = '${nota.titulo} (${sufijo++})';
    }
    titulos.add(titulo.toLowerCase());
    return titulo == nota.titulo ? nota : nota.copiar(titulo: titulo);
  }).toList();
  return ResultadoMezcla(notas, conflictos);
}

class ServicioSincronizacion {
  bool _ocupado = false;

  /// Una carpeta previamente compartida desaparece si se elimina en un lado.
  /// Las notas conservadas o en conflicto vuelven a aportar su carpeta.
  List<String> _mezclarCarpetas(
    List<String> locales,
    List<String> remotas,
    List<String> base,
    List<Nota> notas,
  ) => {
    for (final carpeta in {...locales, ...remotas})
      if (!base.contains(carpeta) ||
          (locales.contains(carpeta) && remotas.contains(carpeta)))
        carpeta,
    ...notas.map((nota) => nota.carpeta).where((carpeta) => carpeta.isNotEmpty),
  }.toList()..sort();

  Future<int> sincronizar(
    ControladorBoveda controlador,
    TransporteSincronizacion transporte,
    String destino,
  ) async {
    if (_ocupado) throw StateError('Ya hay una sincronización en curso.');
    _ocupado = true;
    try {
      final documento = await transporte.leer();
      final remoto = documento.contenido == null
          ? const Boveda(notas: [])
          : Boveda.desdeJson(
              Map<String, dynamic>.from(
                jsonDecode(documento.contenido!) as Map,
              ),
            );
      final clave =
          'base_sincronizacion_${sha256.convert(utf8.encode(destino))}';
      final base = Map<String, String>.from(
        controlador.preferencias[clave] as Map? ?? {},
      );
      final anteriores = controlador.notas;
      final carpetasAnteriores = controlador.carpetas;
      final claveCarpetas = 'carpetas_$clave';
      final baseCarpetas = List<String>.from(
        controlador.preferencias[claveCarpetas] as List? ?? [],
      );
      final mezcla = mezclarNotas(anteriores, remoto.notas, base);
      final carpetas = _mezclarCarpetas(
        carpetasAnteriores,
        remoto.carpetas,
        baseCarpetas,
        mezcla.notas,
      );
      final adjuntos = {
        for (final adjunto in [...controlador.adjuntos, ...remoto.adjuntos])
          adjunto.id: adjunto,
      }.values.toList();
      ControladorBoveda.validarTamanoAdjuntos(adjuntos);
      final compartida = Boveda(
        notas: mezcla.notas,
        carpetas: carpetas,
        adjuntos: adjuntos,
      );
      // Escribir remotamente antes de aplicar; un 412 no modifica la bóveda local.
      await transporte.escribir(
        jsonEncode(compartida.aJson()),
        documento.version,
      );
      // Conservar también las ediciones realizadas mientras se enviaban los datos.
      final posteriores = mezclarNotas(controlador.notas, mezcla.notas, {
        for (final nota in anteriores) nota.id: huellaNota(nota),
      });
      final carpetasPosteriores = _mezclarCarpetas(
        controlador.carpetas,
        carpetas,
        carpetasAnteriores,
        posteriores.notas,
      );
      controlador.aplicarSincronizacion(
        posteriores.notas,
        carpetasPosteriores,
        adjuntos: adjuntos,
      );
      controlador.configurar(claveCarpetas, carpetas);
      controlador.configurar(clave, {
        for (final nota in mezcla.notas) nota.id: huellaNota(nota),
      });
      controlador.configurar(
        'ultima_sincronizacion',
        DateTime.now().toIso8601String(),
      );
      await controlador.guardarPendientes();
      if (controlador.estadoGuardado == EstadoGuardado.error) {
        throw StateError(
          'La copia remota está guardada, pero ha fallado el almacenamiento local.',
        );
      }
      return mezcla.conflictos + posteriores.conflictos;
    } finally {
      _ocupado = false;
      transporte.cerrar();
    }
  }
}
