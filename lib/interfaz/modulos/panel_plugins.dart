// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

import '../../aplicacion/controlador_boveda.dart';
import '../../idiomas/gestor_idiomas.dart';
import '../../plugins/plugin_exportacion.dart';

/// Sección de Opciones que activa las capacidades añadidas por los plugins.
class PanelPlugins extends StatelessWidget {
  const PanelPlugins({super.key, required this.controlador});
  final ControladorBoveda controlador;

  @override
  Widget build(BuildContext context) {
    final plugin = PluginExportacion();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('Plugins'),
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  key: const Key('activar-plugin-exportacion'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(t(plugin.nombre)),
                  subtitle: Text(t(plugin.descripcion)),
                  value: controlador.exportacionHabilitada,
                  onChanged: (valor) =>
                      controlador.configurar('plugin_exportacion', valor),
                ),
                const SizedBox(height: 12),
                Text(
                  t(
                    'Haz clic derecho sobre una nota y elige «Exportar a…». En móvil, mantén pulsada la nota o usa su botón de opciones.',
                  ),
                  style: const TextStyle(fontSize: 12, height: 1.7),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
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
