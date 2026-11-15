import 'package:flutter/services.dart';

enum FormatoLinea { encabezado, lista, listaNumerada, tarea, cita }

/// Cambios de texto y selección compartidos por botones y atajos del editor.
abstract final class OperacionesMarkdown {
  static TextEditingValue rodear(
    TextEditingValue valor,
    String apertura,
    String cierre,
    String relleno,
  ) {
    final seleccion = valor.selection;
    final inicio = seleccion.isValid ? seleccion.start : valor.text.length;
    final fin = seleccion.isValid ? seleccion.end : inicio;
    final texto = valor.text;
    final elegido = texto.substring(inicio, fin);
    if (inicio >= apertura.length &&
        fin + cierre.length <= texto.length &&
        texto.substring(inicio - apertura.length, inicio) == apertura &&
        texto.substring(fin, fin + cierre.length) == cierre) {
      return TextEditingValue(
        text: texto.replaceRange(
          inicio - apertura.length,
          fin + cierre.length,
          elegido,
        ),
        selection: TextSelection(
          baseOffset: inicio - apertura.length,
          extentOffset: fin - apertura.length,
        ),
      );
    }
    if (elegido.length >= apertura.length + cierre.length &&
        elegido.startsWith(apertura) &&
        elegido.endsWith(cierre)) {
      final interior = elegido.substring(
        apertura.length,
        elegido.length - cierre.length,
      );
      return TextEditingValue(
        text: texto.replaceRange(inicio, fin, interior),
        selection: TextSelection(
          baseOffset: inicio,
          extentOffset: inicio + interior.length,
        ),
      );
    }
    final contenido = elegido.isEmpty ? relleno : elegido;
    return TextEditingValue(
      text: texto.replaceRange(inicio, fin, '$apertura$contenido$cierre'),
      selection: TextSelection(
        baseOffset: inicio + apertura.length,
        extentOffset: inicio + apertura.length + contenido.length,
      ),
    );
  }

  static TextEditingValue formatearLineas(
    TextEditingValue valor,
    FormatoLinea formato,
    String relleno,
  ) {
    final seleccion = valor.selection;
    final inicio = seleccion.isValid ? seleccion.start : valor.text.length;
    var fin = seleccion.isValid ? seleccion.end : inicio;
    if (fin > inicio && valor.text[fin - 1] == '\n') fin--;
    final desde = inicio == 0
        ? 0
        : valor.text.lastIndexOf('\n', inicio - 1) + 1;
    final salto = valor.text.indexOf('\n', fin);
    final hasta = salto < 0 ? valor.text.length : salto;
    final lineas = valor.text.substring(desde, hasta).split('\n');
    final patron = RegExp(switch (formato) {
      FormatoLinea.encabezado => r'^##[ \t]+',
      FormatoLinea.lista => r'^[-+*][ \t]+(?!\[[ xX]\][ \t])',
      FormatoLinea.listaNumerada => r'^\d+[.)][ \t]+',
      FormatoLinea.tarea => r'^[-+*][ \t]+\[[ xX]\][ \t]+',
      FormatoLinea.cita => r'^>[ \t]?',
    });
    final conTexto = lineas.where((linea) => linea.trim().isNotEmpty);
    final quitar =
        conTexto.isNotEmpty &&
        conTexto.every((linea) => patron.hasMatch(linea.trimLeft()));
    var numero = 0;
    final nuevas = <String>[];
    for (final linea in lineas) {
      if (linea.trim().isEmpty && lineas.length > 1) {
        nuevas.add(linea);
        continue;
      }
      final sangria = RegExp(r'^[ \t]*').stringMatch(linea)!;
      var contenido = linea.substring(sangria.length);
      if (quitar) {
        nuevas.add('$sangria${contenido.replaceFirst(patron, '')}');
        continue;
      }
      final anterior = switch (formato) {
        FormatoLinea.encabezado => RegExp(r'^#{1,6}[ \t]+'),
        FormatoLinea.lista ||
        FormatoLinea.listaNumerada ||
        FormatoLinea.tarea => RegExp(
          r'^(?:[-+*][ \t]+(?:\[[ xX]\][ \t]+)?|\d+[.)][ \t]+)',
        ),
        FormatoLinea.cita => RegExp(r'^>[ \t]?'),
      };
      contenido = contenido.replaceFirst(anterior, '');
      if (contenido.isEmpty) contenido = relleno;
      final prefijo = switch (formato) {
        FormatoLinea.encabezado => '## ',
        FormatoLinea.lista => '- ',
        FormatoLinea.listaNumerada => '${++numero}. ',
        FormatoLinea.tarea => '- [ ] ',
        FormatoLinea.cita => '> ',
      };
      nuevas.add('$sangria$prefijo$contenido');
    }
    final resultado = nuevas.join('\n');
    return TextEditingValue(
      text: valor.text.replaceRange(desde, hasta, resultado),
      selection: TextSelection(
        baseOffset: desde,
        extentOffset: desde + resultado.length,
      ),
    );
  }
}
