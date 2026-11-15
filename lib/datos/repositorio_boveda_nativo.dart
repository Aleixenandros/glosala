import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';

import '../dominio/nota.dart';
import '../dominio/boveda.dart';
import 'repositorio_boveda.dart';

Future<RepositorioBoveda> crearRepositorioBoveda() async {
  final soporte = await getApplicationSupportDirectory();
  return RepositorioBovedaNativo(
    Directory(p.join(soporte.path, 'Glosala', 'vault')),
  );
}

/// Cada nota es un documento Markdown independiente con metadatos YAML.
/// Las notas eliminadas se conservan en la papelera y pueden restaurarse.
class RepositorioBovedaNativo implements RepositorioBoveda {
  RepositorioBovedaNativo(this.directorio);

  final Directory directorio;
  final Map<String, String> _archivosGuardados = {};

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
    return Boveda.desdeJson({
      ...opciones,
      'notes': notas.map((n) => n.aJson()).toList(),
    });
  }

  @override
  Future<void> guardar(Boveda boveda) async {
    await directorio.create(recursive: true);
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
      const JsonEncoder.withIndent('  ')
          .convert(boveda.aJson(incluirNotas: false)),
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
