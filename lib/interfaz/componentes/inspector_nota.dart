import '../../idiomas/gestor_idiomas.dart';
// Compatibilidad con el renderizador Markdown hasta su migración a material_ui.
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../aplicacion/controlador_boveda.dart';
import '../../dominio/nota.dart';
import '../tema_aplicacion.dart';

class InspectorNota extends StatelessWidget {
  const InspectorNota({
    super.key,
    required this.controller,
    required this.nota,
    required this.alEncabezado,
  });
  final ControladorBoveda controller;
  final Nota nota;
  final ValueChanged<int> alEncabezado;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final enlacesEntrantes = controller.enlacesEntrantes(nota);
    return ColoredBox(
      color: TemaAplicacion.sidebar(context),
      child: ListView(
        padding: EdgeInsets.all(22),
        children: [
          SizedBox(height: 9),
          _encabezado('EN ESTA NOTA', Icons.subject_rounded),
          SizedBox(height: 20),
          if (nota.encabezados.isEmpty)
            _ayudaTexto('Los encabezados de tu nota aparecerán aquí.'),
          for (final encabezado in nota.encabezados)
            Padding(
              padding: EdgeInsets.only(
                left: (encabezado.level - 1) * 10.0,
                bottom: 3,
              ),
              child: InkWell(
                onTap: nota.eliminada
                    ? null
                    : () => alEncabezado(encabezado.offset),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    encabezado.text,
                    style: TextStyle(
                      fontSize: 11,
                      color: encabezado.level == 1
                          ? color.onSurface
                          : color.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          SizedBox(height: 27),
          Divider(),
          SizedBox(height: 27),
          _encabezado('ENLACES ENTRANTES', Icons.link_rounded),
          SizedBox(height: 17),
          if (enlacesEntrantes.isEmpty)
            _ayudaTexto('Cuando otra nota enlace a esta, la encontrarás aquí.'),
          for (final enlazada in enlacesEntrantes)
            Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => controller.seleccionarNota(enlazada.id),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 13,
                            color: color.primary,
                          ),
                          SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              enlazada.titulo,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: color.primary,
                                fontSize: 11,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 7),
                      Text(
                        enlazada.extracto,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.6,
                          color: color.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SizedBox(height: 25),
          Divider(),
          SizedBox(height: 25),
          _encabezado('ETIQUETAS', Icons.tag_rounded),
          SizedBox(height: 16),
          if (nota.etiquetas.isEmpty)
            _ayudaTexto('Añade #etiquetas para organizar tus ideas.'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: nota.etiquetas
                .map(
                  (tag) => ActionChip(
                    onPressed: () => controller.cambiarFiltro(
                      FiltroNotas.todas,
                      conEtiqueta: tag,
                    ),
                    label: Text(
                      '#$tag',
                      style: TextStyle(fontSize: 10, color: color.primary),
                    ),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                    backgroundColor: color.primary.withValues(alpha: .09),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: 40),
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.primary.withValues(alpha: .045),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: color.primary,
                ),
                SizedBox(height: 10),
                _ayudaTexto(
                  'Las ideas crecen cuando se conectan. Usa [[nombre de nota]] para crear un enlace.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _encabezado(String title, IconData icon) => Row(
    children: [
      Icon(icon, size: 15),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          t(title),
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
  Widget _ayudaTexto(String text) => Text(
    t(text),
    style: TextStyle(fontSize: 11, height: 1.8, color: Color(0xFF8D899A)),
  );
}
