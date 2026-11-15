import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

/// Catálogos XML sin ejecución de código. Las ediciones locales se guardan en
/// las preferencias; también pueden importarse y exportarse desde Opciones.
class GestorIdiomas {
  static final instancia = GestorIdiomas();
  static const disponibles = {
    'es': 'Español',
    'en': 'English',
    'fr': 'Français',
    'de': 'Deutsch',
    'pt': 'Português',
  };
  final Map<String, Map<String, String>> _catalogos = {};
  final Map<String, String> _originales = {};
  String actual = 'es';

  Future<void> cargar() async {
    for (final codigo in disponibles.keys) {
      final fuente = await rootBundle.loadString(
        'recursos/idiomas/$codigo.xml',
      );
      _originales[codigo] = fuente;
      _catalogos[codigo] = validar(fuente, codigo);
    }
  }

  Map<String, String> validar(String fuente, String codigo) {
    if (fuente.contains('<!DOCTYPE') || fuente.contains('<!ENTITY')) {
      throw const FormatException('No se permiten entidades XML.');
    }
    final documento = XmlDocument.parse(fuente);
    final raiz = documento.rootElement;
    if (raiz.name.local != 'idioma' || raiz.getAttribute('codigo') != codigo) {
      throw const FormatException('El código de idioma del XML no coincide.');
    }
    final resultado = <String, String>{};
    for (final elemento in raiz.childElements) {
      final clave = elemento.getAttribute('clave');
      if (elemento.name.local != 'texto' ||
          clave == null ||
          resultado.containsKey(clave) ||
          elemento.innerText.trim().isEmpty) {
        throw const FormatException(
          'El catálogo contiene claves duplicadas o textos vacíos.',
        );
      }
      final marcadores = RegExp(r'\{\w+\}');
      if (marcadores
          .allMatches(clave)
          .map((m) => m[0])
          .toSet()
          .difference(
            marcadores.allMatches(elemento.innerText).map((m) => m[0]).toSet(),
          )
          .isNotEmpty) {
        throw FormatException('Faltan marcadores de sustitución en: $clave');
      }
      resultado[clave] = elemento.innerText;
    }
    final base = _catalogos['es'];
    if (base != null &&
        (base.keys.toSet().difference(resultado.keys.toSet()).isNotEmpty ||
            resultado.keys.toSet().difference(base.keys.toSet()).isNotEmpty)) {
      throw const FormatException(
        'El XML debe conservar todas las claves del catálogo base.',
      );
    }
    return resultado;
  }

  void aplicar(String codigo, String fuente) {
    _catalogos[codigo] = validar(fuente, codigo);
  }

  String original(String codigo) => _originales[codigo]!;

  String traducir(String clave, [Map<String, Object> valores = const {}]) {
    var texto = _catalogos[actual]?[clave] ?? _catalogos['es']?[clave] ?? clave;
    for (final entrada in valores.entries) {
      texto = texto.replaceAll('{${entrada.key}}', '${entrada.value}');
    }
    return texto;
  }
}

String t(String clave, [Map<String, Object> valores = const {}]) =>
    GestorIdiomas.instancia.traducir(clave, valores);
