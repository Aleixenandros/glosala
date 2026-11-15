// ignore_for_file: deprecated_member_use
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../aplicacion/controlador_boveda.dart';
import '../../idiomas/gestor_idiomas.dart';
import '../../plugins/plugin_exportacion.dart';

class PanelPlugins extends StatefulWidget {
  const PanelPlugins({super.key, required this.controlador});
  final ControladorBoveda controlador;
  @override
  State<PanelPlugins> createState() => _EstadoPanelPlugins();
}

class _EstadoPanelPlugins extends State<PanelPlugins> {
  final _plugin = PluginExportacion();
  FormatoExportacion _formato = FormatoExportacion.pdf;
  bool _todas = false;
  bool _ocupado = false;
  String? _resultado;

  Future<void> _exportar() async {
    setState(() {
      _ocupado = true;
      _resultado = null;
    });
    try {
      final seleccionada = widget.controlador.notaSeleccionada;
      final notas = _todas ? widget.controlador.notasActivas : [?seleccionada];
      final archivo = await _plugin.exportar(notas, _formato);
      final destino = await FilePicker.saveFile(
        fileName: archivo.nombre,
        bytes: archivo.bytes,
        mimeType: archivo.tipoMime,
      );
      if (mounted && destino != null) {
        setState(() => _resultado = t('Exportación completada.'));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _resultado = '${t('No se ha podido exportar.')} $error');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activo =
        widget.controlador.preferencias['plugin_exportacion'] as bool? ?? true;
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Text(
          t('Plugins'),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(t('Amplía Glosala a tu manera.')),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t(_plugin.nombre)),
                  subtitle: Text(t(_plugin.descripcion)),
                  value: activo,
                  onChanged: _ocupado
                      ? null
                      : (valor) => widget.controlador.configurar(
                          'plugin_exportacion',
                          valor,
                        ),
                ),
                const Divider(),
                const SizedBox(height: 18),
                Text(t('Formato de salida')),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: FormatoExportacion.values
                      .map(
                        (formato) => ChoiceChip(
                          label: Text(formato.name.toUpperCase()),
                          selected: _formato == formato,
                          onSelected: !activo || _ocupado
                              ? null
                              : (_) => setState(() => _formato = formato),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('Exportar todas las notas')),
                  subtitle: Text(
                    t('Si se desactiva, se exporta la nota abierta.'),
                  ),
                  value: _todas,
                  onChanged: !activo || _ocupado
                      ? null
                      : (valor) => setState(() => _todas = valor),
                ),
                const SizedBox(height: 12),
                Text(
                  t(
                    'ODS organiza las notas en una hoja de cálculo. Markdown reúne varias notas en un ZIP. PDF conserva títulos, listas, código y tablas; las imágenes no se incrustan.',
                  ),
                  style: const TextStyle(fontSize: 12, height: 1.7),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed:
                      !activo ||
                          _ocupado ||
                          (!_todas &&
                              widget.controlador.notaSeleccionada == null)
                      ? null
                      : _exportar,
                  icon: const Icon(Icons.file_download_outlined),
                  label: Text(t(_ocupado ? 'Exportando…' : 'Exportar notas')),
                ),
                if (_resultado != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: SelectableText(_resultado!),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          t(
            'Los plugins de esta versión están integrados en la aplicación. No se ejecuta código descargado de terceros.',
          ),
          style: const TextStyle(fontSize: 12, height: 1.7),
        ),
      ],
    );
  }
}
