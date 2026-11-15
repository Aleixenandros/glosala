// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

import '../../aplicacion/controlador_boveda.dart';
import '../../dominio/tarea.dart';
import '../../idiomas/gestor_idiomas.dart';
import '../componentes/dialogo_texto.dart';

class PanelTareas extends StatefulWidget {
  const PanelTareas({super.key, required this.controlador});
  final ControladorBoveda controlador;
  @override
  State<PanelTareas> createState() => _EstadoPanelTareas();
}

class _EstadoPanelTareas extends State<PanelTareas> {
  String _filtro = 'todas';
  Future<void> _anadir({String? padre}) async {
    final titulo = await showDialog<String>(
      context: context,
      builder: (_) => DialogoTexto(
        titulo: t(padre == null ? 'Nueva tarea' : 'Nueva subtarea'),
      ),
    );
    if (titulo != null) widget.controlador.anadirTarea(titulo, padre: padre);
  }

  @override
  Widget build(BuildContext context) {
    final tareas = widget.controlador.tareas
        .where(
          (tarea) =>
              _filtro == 'todas' ||
              tarea.completada == (_filtro == 'completadas'),
        )
        .toList();
    final completadas = widget.controlador.tareas
        .where((tarea) => tarea.completada)
        .length;
    return ListView(
      padding: const EdgeInsets.all(26),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 20,
          runSpacing: 16,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('De la idea a la acción.'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  t('{cantidad} tareas completadas', {'cantidad': completadas}),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: () => _anadir(),
              icon: const Icon(Icons.add),
              label: Text(t('Nueva tarea')),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 8,
          children: [
            for (final entrada in {
              'todas': 'Todas',
              'pendientes': 'Pendientes',
              'completadas': 'Completadas',
            }.entries)
              ChoiceChip(
                label: Text(t(entrada.value)),
                selected: _filtro == entrada.key,
                onSelected: (_) => setState(() => _filtro = entrada.key),
              ),
          ],
        ),
        const SizedBox(height: 22),
        if (tareas.isEmpty)
          Padding(
            padding: const EdgeInsets.all(50),
            child: Center(child: Text(t('No hay tareas en esta vista.'))),
          ),
        for (final tarea in tareas)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _fila(tarea, 0),
            ),
          ),
      ],
    );
  }

  Widget _fila(Tarea tarea, int nivel) => Column(
    children: [
      Row(
        children: [
          Checkbox(
            value: tarea.completada,
            onChanged: (valor) =>
                widget.controlador.completarTarea(tarea.id, valor ?? false),
          ),
          Expanded(
            child: Text(
              tarea.titulo,
              style: TextStyle(
                fontSize: 14,
                decoration: tarea.completada
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: t('Opciones de tarea'),
            onSelected: (accion) async {
              if (accion == 'anadir') {
                await _anadir(padre: tarea.id);
                return;
              }
              if (accion == 'editar') {
                final titulo = await showDialog<String>(
                  context: context,
                  builder: (_) => DialogoTexto(
                    titulo: t('Editar tarea'),
                    inicial: tarea.titulo,
                  ),
                );
                if (titulo != null) {
                  widget.controlador.editarTarea(tarea.id, titulo);
                }
              }
              if (accion == 'eliminar' && mounted) {
                final confirmar = await showDialog<bool>(
                  context: context,
                  builder: (contexto) => AlertDialog(
                    title: Text(t('Eliminar tarea')),
                    content: Text(t('Se eliminarán la tarea y sus subtareas.')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(contexto, false),
                        child: Text(t('Cancelar')),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(contexto, true),
                        child: Text(t('Eliminar')),
                      ),
                    ],
                  ),
                );
                if (confirmar == true) {
                  widget.controlador.eliminarTarea(tarea.id);
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'anadir', child: Text(t('Nueva subtarea'))),
              PopupMenuItem(value: 'editar', child: Text(t('Editar tarea'))),
              PopupMenuItem(
                value: 'eliminar',
                child: Text(t('Eliminar tarea')),
              ),
            ],
          ),
        ],
      ),
      for (final subtarea in tarea.subtareas)
        Padding(
          padding: EdgeInsets.only(left: nivel < 3 ? 20 : 0),
          child: _fila(subtarea, nivel + 1),
        ),
    ],
  );
}
