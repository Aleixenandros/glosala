// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../actualizaciones/servicio_actualizaciones.dart';
import '../../idiomas/gestor_idiomas.dart';

class PanelAcerca extends StatefulWidget {
  const PanelAcerca({super.key});
  @override
  State<PanelAcerca> createState() => _EstadoPanelAcerca();
}

class _EstadoPanelAcerca extends State<PanelAcerca> {
  bool _comprobando = false;
  String? _estado;
  Actualizacion? _actualizacion;

  Future<void> _comprobar() async {
    setState(() {
      _comprobando = true;
      _estado = null;
    });
    try {
      final resultado = await ServicioActualizaciones().comprobar();
      if (mounted) {
        setState(() {
          _actualizacion = resultado;
          _estado = resultado == null
              ? 'Todavía no hay versiones publicadas.'
              : resultado.disponible
              ? 'Hay una nueva versión disponible.'
              : 'Tienes la última versión.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _estado =
              'No se pudo comprobar. Revisa tu conexión o inténtalo más tarde.',
        );
      }
    } finally {
      if (mounted) setState(() => _comprobando = false);
    }
  }

  Future<void> _abrir(Uri direccion) async {
    try {
      if (!await launchUrl(direccion)) throw StateError('enlace');
    } catch (_) {
      if (mounted) setState(() => _estado = 'No se ha podido abrir el enlace.');
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(32),
    children: [
      const SizedBox(height: 30),
      Icon(
        Icons.auto_stories_rounded,
        size: 60,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(height: 22),
      const Text(
        'Glosala',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      Text(
        t('Un espacio para tus notas y tus ideas conectadas.'),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 10),
      Text('v$versionAplicacion', textAlign: TextAlign.center),
      const SizedBox(height: 28),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton.icon(
            onPressed: _comprobando ? null : _comprobar,
            icon: const Icon(Icons.system_update_alt),
            label: Text(
              t(_comprobando ? 'Comprobando…' : 'Comprobar actualizaciones'),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _abrir(Uri.parse(repositorioProyecto)),
            icon: const Icon(Icons.code),
            label: Text(t('Ver repositorio')),
          ),
        ],
      ),
      if (_estado != null)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(t(_estado!), textAlign: TextAlign.center),
        ),
      if (_actualizacion?.disponible == true)
        Center(
          child: TextButton(
            onPressed: () => _abrir(_actualizacion!.direccion),
            child: Text(
              t('Abrir versión {version}', {
                'version': _actualizacion!.version,
              }),
            ),
          ),
        ),
      const SizedBox(height: 24),
      Text(
        t(
          'Las actualizaciones se consultan en GitHub Releases. La descarga e instalación son manuales.',
        ),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, height: 1.8),
      ),
      const SizedBox(height: 20),
      Center(
        child: TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'Glosala',
            applicationVersion: versionAplicacion,
          ),
          child: Text(t('Licencias de terceros')),
        ),
      ),
    ],
  );
}
