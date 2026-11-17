import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdf;
import 'package:xml/xml.dart';

import '../dominio/nota.dart';
import '../dominio/adjunto.dart';

enum FormatoExportacion { markdown, html, pdf, ods }

class ArchivoExportado {
  const ArchivoExportado(this.nombre, this.tipoMime, this.bytes);
  final String nombre;
  final String tipoMime;
  final Uint8List bytes;
}

abstract interface class PluginGlosala {
  String get identificador;
  String get nombre;
  String get descripcion;
}

class PluginExportacion implements PluginGlosala {
  @override
  String get identificador => 'exportacion';
  @override
  String get nombre => 'Exportación de notas';
  @override
  String get descripcion => 'Exporta tus notas a Markdown, HTML, PDF y ODS.';

  Future<ArchivoExportado> exportar(
    List<Nota> notas,
    FormatoExportacion formato, {
    List<Adjunto> adjuntos = const [],
  }) async {
    if (notas.isEmpty) throw ArgumentError('Selecciona al menos una nota.');
    final ids = notas.expand((n) => n.idsAdjuntos).toSet();
    if (ids.isNotEmpty) {
      final archivos = {for (final a in adjuntos) a.id: a};
      if (!ids.every(archivos.containsKey)) {
        throw const FormatException('Faltan adjuntos de estas notas.');
      }
      final portables = notas.map((nota) {
        var texto = nota.contenido;
        for (final id in nota.idsAdjuntos) {
          final adjunto = archivos[id]!;
          texto = texto.replaceAll(adjunto.enlace, adjunto.enlaceExportado);
        }
        return nota.copiar(contenido: texto);
      }).toList();
      final documento = await exportar(portables, formato);
      final paquete = documento.tipoMime == 'application/zip'
          ? ZipDecoder().decodeBytes(documento.bytes)
          : (Archive()..addFile(
              ArchiveFile(
                documento.nombre,
                documento.bytes.length,
                documento.bytes,
              ),
            ));
      for (final id in ids) {
        final adjunto = archivos[id]!;
        paquete.addFile(
          ArchiveFile(
            adjunto.rutaExportada,
            adjunto.bytes.length,
            adjunto.bytes,
          ),
        );
      }
      final nombre = documento.nombre.replaceFirst(RegExp(r'\.[^.]+$'), '');
      return ArchivoExportado(
        '$nombre.zip',
        'application/zip',
        Uint8List.fromList(ZipEncoder().encode(paquete)),
      );
    }
    final nombre = notas.length == 1
        ? notas.first.titulo.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        : 'Glosala';
    switch (formato) {
      case FormatoExportacion.markdown:
        if (notas.length == 1) {
          return ArchivoExportado(
            '$nombre.md',
            'text/markdown',
            Uint8List.fromList(utf8.encode(notas.first.contenido)),
          );
        }
        final archivo = Archive();
        for (final nota in notas) {
          final titulo = nota.titulo.replaceAll(
            RegExp(r'[<>:"/\\|?*\x00-\x1F]'),
            '_',
          );
          archivo.addFile(
            ArchiveFile.string('$titulo-${nota.id}.md', nota.contenido),
          );
        }
        return ArchivoExportado(
          '$nombre.zip',
          'application/zip',
          Uint8List.fromList(ZipEncoder().encode(archivo)),
        );
      case FormatoExportacion.html:
        final contenido =
            '<!doctype html><html lang="es"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; style-src \'unsafe-inline\'; img-src \'self\'">'
            '<title>${_escapar(nombre)}</title><style>body{font:16px/1.8 system-ui;max-width:850px;margin:48px auto;padding:24px;color:#262330}'
            'h1,h2,h3{line-height:1.3}article{margin-bottom:64px}pre,blockquote{padding:18px;background:#f5f2fa;border-radius:8px}'
            'pre{white-space:pre-wrap}img{max-width:100%;height:auto}a{color:#7051b8}table{border-collapse:collapse}td,th{border:1px solid #ddd;padding:10px}</style></head><body>'
            '${notas.map((nota) => '<article id="${nota.id}"><h1>${_escapar(nota.titulo)}</h1>${_htmlSeguro(_analizar(nota.contenido))}</article>').join()}'
            '</body></html>';
        return ArchivoExportado(
          '$nombre.html',
          'text/html',
          Uint8List.fromList(utf8.encode(contenido)),
        );
      case FormatoExportacion.pdf:
        return ArchivoExportado(
          '$nombre.pdf',
          'application/pdf',
          await _pdf(notas),
        );
      case FormatoExportacion.ods:
        return ArchivoExportado(
          '$nombre.ods',
          'application/vnd.oasis.opendocument.spreadsheet',
          _ods(notas),
        );
    }
  }

  List<md.Node> _analizar(String contenido) => md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    inlineSyntaxes: [SintaxisEnlaceInterno()],
    encodeHtml: false,
  ).parseLines(contenido.split('\n'));

  String _escapar(String texto) => const HtmlEscape().convert(texto);

  String _htmlSeguro(List<md.Node> nodos) => nodos.map((nodo) {
    if (nodo is md.Text) return _escapar(nodo.text);
    if (nodo is! md.Element) return '';
    const permitidas = {
      'p',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'strong',
      'em',
      'del',
      'blockquote',
      'ul',
      'ol',
      'li',
      'pre',
      'code',
      'table',
      'thead',
      'tbody',
      'tr',
      'th',
      'td',
      'a',
      'hr',
      'br',
      'input',
      'img',
    };
    if (!permitidas.contains(nodo.tag)) return _escapar(nodo.textContent);
    if (nodo.tag == 'input') {
      return nodo.attributes.containsKey('checked') ? '[x] ' : '[ ] ';
    }
    if (nodo.tag == 'br' || nodo.tag == 'hr') return '<${nodo.tag}>';
    if (nodo.tag == 'img') {
      final origen = nodo.attributes['src'] ?? '';
      return _rutaAdjunto(origen)
          ? '<img src="${_escapar(origen)}" alt="${_escapar(nodo.attributes['alt'] ?? '')}">'
          : _escapar(nodo.attributes['alt'] ?? '');
    }
    var atributos = '';
    if (nodo.tag == 'a') {
      final enlace = nodo.attributes['href'] ?? '';
      final uri = Uri.tryParse(enlace);
      if (uri != null &&
          ({'http', 'https', 'mailto'}.contains(uri.scheme) ||
              _rutaAdjunto(enlace))) {
        atributos = ' href="${_escapar(enlace)}" rel="noopener noreferrer"';
      }
    }
    return '<${nodo.tag}$atributos>${_htmlSeguro(nodo.children ?? [])}</${nodo.tag}>';
  }).join();

  bool _rutaAdjunto(String ruta) =>
      RegExp(r'^adjuntos/[a-f0-9]{64}/[^/]+$').hasMatch(ruta);

  Future<Uint8List> _pdf(List<Nota> notas) async {
    final fuente = pdf.Font.ttf(
      await rootBundle.load('recursos/fuentes/Inter.ttf'),
    );
    final mono = pdf.Font.ttf(
      await rootBundle.load('recursos/fuentes/JetBrainsMono.ttf'),
    );
    final documento = pdf.Document(
      title: notas.length == 1 ? notas.first.titulo : 'Glosala',
      author: 'Glosala',
    );
    for (final nota in notas) {
      documento.addPage(
        pdf.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pdf.ThemeData.withFont(
            base: fuente,
            bold: fuente,
            italic: fuente,
            boldItalic: fuente,
          ),
          margin: const pdf.EdgeInsets.all(42),
          maxPages: 500,
          footer: (contexto) => pdf.Align(
            alignment: pdf.Alignment.centerRight,
            child: pdf.Text(
              'Glosala · ${contexto.pageNumber}',
              style: const pdf.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
          ),
          build: (_) => [
            pdf.Text(
              nota.titulo,
              style: pdf.TextStyle(
                fontSize: 25,
                fontWeight: pdf.FontWeight.bold,
              ),
            ),
            pdf.SizedBox(height: 20),
            ..._bloquesPdf(_analizar(nota.contenido), mono),
          ],
        ),
      );
    }
    return documento.save();
  }

  List<pdf.Widget> _bloquesPdf(List<md.Node> nodos, pdf.Font mono) {
    final resultado = <pdf.Widget>[];
    for (final nodo in nodos) {
      if (nodo is! md.Element) {
        resultado.add(pdf.Paragraph(text: nodo.textContent));
        continue;
      }
      if (RegExp(r'^h[1-6]$').hasMatch(nodo.tag)) {
        resultado.add(
          pdf.Header(
            level: int.parse(nodo.tag.substring(1)) - 1,
            text: nodo.textContent,
          ),
        );
      } else if (nodo.tag == 'ul' || nodo.tag == 'ol') {
        var numero = 0;
        for (final hijo in nodo.children ?? <md.Node>[]) {
          resultado.add(
            pdf.Paragraph(
              text:
                  '${nodo.tag == 'ol' ? '${++numero}.' : '•'} ${hijo.textContent}',
            ),
          );
        }
      } else if (nodo.tag == 'pre') {
        for (final linea in nodo.textContent.split('\n')) {
          resultado.add(
            pdf.Text(linea, style: pdf.TextStyle(font: mono, fontSize: 9)),
          );
        }
        resultado.add(pdf.SizedBox(height: 12));
      } else if (nodo.tag == 'table') {
        final filas = <List<String>>[];
        void recorrer(md.Node n) {
          if (n is md.Element && n.tag == 'tr') {
            filas.add(
              (n.children ?? []).map((celda) => celda.textContent).toList(),
            );
          } else if (n is md.Element) {
            for (final hijo in n.children ?? <md.Node>[]) {
              recorrer(hijo);
            }
          }
        }

        recorrer(nodo);
        if (filas.isNotEmpty) {
          resultado.add(
            pdf.TableHelper.fromTextArray(
              headers: filas.first,
              data: filas.skip(1).toList(),
              cellStyle: const pdf.TextStyle(fontSize: 9),
            ),
          );
        }
      } else if (nodo.tag == 'hr') {
        resultado.add(pdf.Divider());
      } else {
        resultado.add(
          pdf.Paragraph(
            text: nodo.textContent,
            style: const pdf.TextStyle(fontSize: 11, lineSpacing: 4),
          ),
        );
      }
    }
    return resultado;
  }

  Uint8List _ods(List<Nota> notas) {
    final constructor = XmlBuilder();
    constructor.processing('xml', 'version="1.0" encoding="UTF-8"');
    constructor.element(
      'office:document-content',
      attributes: {
        'xmlns:office': 'urn:oasis:names:tc:opendocument:xmlns:office:1.0',
        'xmlns:table': 'urn:oasis:names:tc:opendocument:xmlns:table:1.0',
        'xmlns:text': 'urn:oasis:names:tc:opendocument:xmlns:text:1.0',
        'office:version': '1.3',
      },
      nest: () => constructor.element(
        'office:body',
        nest: () => constructor.element(
          'office:spreadsheet',
          nest: () => constructor.element(
            'table:table',
            attributes: {'table:name': 'Notas'},
            nest: () {
              final filas = [
                [
                  'Título',
                  'Carpeta',
                  'Contenido Markdown',
                  'Etiquetas',
                  'Modificada',
                ],
                ...notas.map(
                  (nota) => [
                    nota.titulo,
                    nota.carpeta,
                    nota.contenido,
                    nota.etiquetas.join(', '),
                    nota.modificadaEl.toIso8601String(),
                  ],
                ),
              ];
              for (final fila in filas) {
                constructor.element(
                  'table:table-row',
                  nest: () {
                    for (final celda in fila) {
                      constructor.element(
                        'table:table-cell',
                        attributes: {'office:value-type': 'string'},
                        nest: () {
                          for (final linea in celda.split('\n')) {
                            constructor.element(
                              'text:p',
                              nest: () => constructor.text(linea),
                            );
                          }
                        },
                      );
                    }
                  },
                );
              }
            },
          ),
        ),
      ),
    );
    final archivo = Archive();
    archivo.addFile(
      ArchiveFile.string(
        'mimetype',
        'application/vnd.oasis.opendocument.spreadsheet',
      )..compression = CompressionType.none,
    );
    archivo.addFile(
      ArchiveFile.string(
        'content.xml',
        constructor.buildDocument().toXmlString(),
      ),
    );
    archivo.addFile(
      ArchiveFile.string(
        'META-INF/manifest.xml',
        '<?xml version="1.0" encoding="UTF-8"?>'
            '<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.3">'
            '<manifest:file-entry manifest:full-path="/" manifest:media-type="application/vnd.oasis.opendocument.spreadsheet"/>'
            '<manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>'
            '</manifest:manifest>',
      ),
    );
    return Uint8List.fromList(ZipEncoder().encode(archivo));
  }
}
