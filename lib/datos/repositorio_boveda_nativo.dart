import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';

import '../dominio/nota.dart';
import '../dominio/boveda.dart';
import '../dominio/adjunto.dart';
import 'repositorio_boveda.dart';

Future<RepositorioBoveda> crearRepositorioBoveda() async {
  final portable = await directorioBovedaPortable(
    Directory(p.dirname(Platform.resolvedExecutable)),
    esWindows: Platform.isWindows,
  );
  if (portable != null) return RepositorioBovedaNativo(portable);
  final soporte = await getApplicationSupportDirectory();
  return RepositorioBovedaNativo(
    Directory(p.join(soporte.path, 'Glosala', 'vault')),
  );
}

/// El ZIP portable incluye este marcador; los instaladores no lo distribuyen.
/// Una carpeta sin permisos de escritura produce el error habitual de guardado,
/// sin cambiar silenciosamente a otra bóveda en el perfil del usuario.
Future<Directory?> directorioBovedaPortable(
  Directory aplicacion, {
  required bool esWindows,
}) async {
  if (!esWindows ||
      !await File(p.join(aplicacion.path, 'glosala.portable')).exists()) {
    return null;
  }
  return Directory(p.join(aplicacion.path, 'datos', 'boveda'));
}

/// Cada nota es un documento Markdown independiente con metadatos YAML.
/// Las notas eliminadas se conservan en la papelera y pueden restaurarse.
class RepositorioBovedaNativo implements RepositorioBoveda {
  RepositorioBovedaNativo(this.directorio);

  final Directory directorio;
  final Map<String, String> _archivosGuardados = {};
  final Set<String> _adjuntosGuardados = {};

  @override
  String get location => directorio.path;

  @override
  Future<Boveda?> cargar() async {
    if (!await directorio.exists()) return null;
    final archivoOpciones = File(p.join(directorio.path, 'workspace.json'));
    final opciones = await archivoOpciones.exists()
        ? Map<String, dynamic>.from(
            jsonDecode(await archivoOpciones.readAsString()) as Map,
          )
        : <String, dynamic>{'version': 1};
    final carpetaNotas = Directory(p.join(directorio.path, 'notes'));
    final notas = <Nota>[];
    if (await carpetaNotas.exists()) {
      await for (final entry in carpetaNotas.list(followLinks: false)) {
        if (entry is! File || p.extension(entry.path) != '.md') continue;
        final fuente = await entry.readAsString();
        final normalizado = fuente.replaceAll('\r\n', '\n');
        final header = RegExp(r'^---\n([\s\S]*?)\n---\n')
            .firstMatch(normalizado);
        if (header == null) {
          throw FormatException(
            'Metadatos de nota no válidos: ${p.basename(entry.path)}',
          );
        }
        final metadatos = loadYaml(header[1]!);
        final nota = Nota.desdeJson({
          ...Map<String, dynamic>.from(metadatos as Map),
          'content': normalizado.substring(header.end),
        });
        if (p.basenameWithoutExtension(entry.path) != nota.id) {
          throw FormatException(
            'El identificador no coincide con ${p.basename(entry.path)}',
          );
        }
        notas.add(nota);
        _archivosGuardados[nota.id] = fuente;
      }
    }
    if (notas.isEmpty && !await archivoOpciones.exists()) return null;
    final adjuntos = <Adjunto>[];
    for (final valor in opciones['attachments'] as List? ?? []) {
      final metadatos = Map<String, dynamic>.from(valor as Map);
      final id = metadatos['id'] as String;
      Adjunto.validarId(id);
      final archivo = File(p.join(directorio.path, 'attachments', id));
      if (await archivo.length() > Adjunto.maximoBytes) {
        throw const FormatException('El archivo supera el límite de 100 MB.');
      }
      adjuntos.add(
        Adjunto.desdeJson(metadatos, bytes: await archivo.readAsBytes()),
      );
      _adjuntosGuardados.add(id);
    }
    return Boveda.desdeJson({
      ...opciones,
      'notes': notas.map((n) => n.aJson()).toList(),
    }, adjuntosCargados: adjuntos);
  }

  @override
  Future<void> guardar(Boveda boveda) async {
    await directorio.create(recursive: true);
    // Publicar los binarios antes que las referencias de las notas.
    if (boveda.adjuntos.isNotEmpty) {
      final carpeta = await Directory(p.join(directorio.path, 'attachments'))
          .create(recursive: true);
      for (final adjunto in boveda.adjuntos) {
        if (_adjuntosGuardados.contains(adjunto.id)) continue;
        final archivo = File(p.join(carpeta.path, adjunto.id));
        final temporal = File('${archivo.path}.tmp');
        await temporal.writeAsBytes(adjunto.bytes, flush: true);
        await temporal.rename(archivo.path);
        _adjuntosGuardados.add(adjunto.id);
      }
    }
    final carpetaNotas = await Directory(p.join(directorio.path, 'notes'))
        .create(recursive: true);
    for (final nota in boveda.notas) {
      // Los escalares JSON son YAML válido y escapan los títulos del usuario.
      final metadatos = nota
          .aJson(incluirContenido: false)
          .entries
          .map((entry) => '${entry.key}: ${jsonEncode(entry.value)}')
          .join('\n');
      final fuente = '---\n$metadatos\n---\n${nota.contenido}';
      if (_archivosGuardados[nota.id] == fuente) continue;
      if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(nota.id)) {
        throw const FormatException('Identificador de nota no válido.');
      }
      await _escribirAtomico(
        File(p.join(carpetaNotas.path, '${nota.id}.md')),
        fuente,
      );
      _archivosGuardados[nota.id] = fuente;
    }
    await _escribirAtomico(
      File(p.join(directorio.path, 'workspace.json')),
      const JsonEncoder.withIndent(
        '  ',
      ).convert(boveda.aJson(incluirNotas: false, incluirDatosAdjuntos: false)),
    );
  }

  Future<void> _escribirAtomico(File destino, String content) async {
    final temporal = File('${destino.path}.tmp');
    await temporal.writeAsString(content, flush: true);
    await temporal.rename(destino.path);
  }

  @override
  Future<void> cerrar() async {}
}
