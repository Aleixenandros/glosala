// ignore_for_file: deprecated_member_use
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../aplicacion/controlador_boveda.dart';
import '../../idiomas/gestor_idiomas.dart';
import '../../sincronizacion/servicio_sincronizacion.dart';
import '../../sincronizacion/transporte.dart';
import '../../sincronizacion/transporte_carpeta.dart';

class PanelSincronizacion extends StatefulWidget {
  const PanelSincronizacion({super.key, required this.controlador});
  final ControladorBoveda controlador;
  @override
  State<PanelSincronizacion> createState() => _EstadoPanelSincronizacion();
}

class _EstadoPanelSincronizacion extends State<PanelSincronizacion> {
  late final _direccion = TextEditingController(
    text: widget.controlador.preferencias['webdav_url'] as String? ?? '',
  );
  late final _usuario = TextEditingController(
    text: widget.controlador.preferencias['webdav_usuario'] as String? ?? '',
  );
  final _contrasena = TextEditingController();
  final _servicio = ServicioSincronizacion();
  late String _carpeta =
      widget.controlador.preferencias['carpeta_sincronizacion'] as String? ??
      '';
  String _tipo = 'webdav';
  bool _ocupado = false;
  String? _resultado;

  @override
  void dispose() {
    _direccion.dispose();
    _usuario.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _sincronizar() async {
    setState(() {
      _ocupado = true;
      _resultado = null;
    });
    try {
      final c = widget.controlador;
      final destino = _tipo == 'webdav' ? _direccion.text.trim() : _carpeta;
      if (destino.isEmpty) {
        throw FormatException(t('Configura un destino de sincronización.'));
      }
      final transporte = _tipo == 'webdav'
          ? TransporteWebDav(destino, _usuario.text, _contrasena.text)
          : crearTransporteCarpeta(destino);
      c.configurar('webdav_url', _direccion.text.trim());
      c.configurar('webdav_usuario', _usuario.text);
      c.configurar('carpeta_sincronizacion', _carpeta);
      final conflictos = await _servicio.sincronizar(
        c,
        transporte,
        '$_tipo:$destino:${_usuario.text}',
      );
      if (mounted) {
        setState(
          () => _resultado = t(
            'Sincronización completada. Conflictos conservados: {cantidad}',
            {'cantidad': conflictos},
          ),
        );
      }
    } on DioException catch (error) {
      final estado = error.response?.statusCode;
      if (mounted) {
        setState(
          () => _resultado = estado == 412
              ? t('El servidor ha cambiado. Vuelve a sincronizar.')
              : t(
                      'No se pudo conectar. Revisa la URL, las credenciales y los permisos del servidor.',
                    ) +
                    (estado == null ? '' : ' HTTP $estado'),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _resultado = error.toString());
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(28),
    children: [
      Text(
        t('Tus notas, en tus dispositivos.'),
        style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 14),
      Text(
        t(
          'Sincronización manual de notas y carpetas. Los conflictos se conservan como copias.',
        ),
      ),
      const SizedBox(height: 25),
      Wrap(
        spacing: 10,
        children: [
          ChoiceChip(
            label: const Text('WebDAV'),
            selected: _tipo == 'webdav',
            onSelected: _ocupado
                ? null
                : (_) => setState(() => _tipo = 'webdav'),
          ),
          if (!kIsWeb &&
              {
                TargetPlatform.linux,
                TargetPlatform.windows,
                TargetPlatform.macOS,
              }.contains(defaultTargetPlatform))
            ChoiceChip(
              label: Text(t('Carpeta / NAS')),
              selected: _tipo == 'carpeta',
              onSelected: _ocupado
                  ? null
                  : (_) => setState(() => _tipo = 'carpeta'),
            ),
        ],
      ),
      const SizedBox(height: 24),
      if (_tipo == 'webdav') ...[
        TextField(
          controller: _direccion,
          enabled: !_ocupado,
          decoration: InputDecoration(
            labelText: t('URL de la carpeta WebDAV'),
            hintText: 'https://servidor/remote.php/dav/files/usuario/Glosala/',
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _usuario,
          enabled: !_ocupado,
          decoration: InputDecoration(labelText: t('Usuario')),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _contrasena,
          enabled: !_ocupado,
          obscureText: true,
          decoration: InputDecoration(labelText: t('Contraseña de aplicación')),
        ),
        const SizedBox(height: 12),
        Text(
          t(
            'La contraseña solo se conserva mientras este panel está abierto. Usa HTTPS para proteger las credenciales.',
          ),
          style: const TextStyle(fontSize: 12, height: 1.7),
        ),
        const SizedBox(height: 12),
        Text(
          t(
            'Compatible con Nextcloud, ownCloud y NAS con WebDAV. Crea primero la carpeta en el servidor.',
          ),
          style: const TextStyle(fontSize: 12, height: 1.7),
        ),
        if (kIsWeb)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              t(
                'En web, el servidor debe permitir CORS para GET/PUT, Authorization, If-Match e If-None-Match, y exponer ETag.',
              ),
            ),
          ),
      ] else ...[
        SelectableText(
          _carpeta.isEmpty ? t('Ninguna carpeta seleccionada') : _carpeta,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _ocupado
              ? null
              : () async {
                  final ruta = await FilePicker.getDirectoryPath();
                  if (ruta != null && mounted) setState(() => _carpeta = ruta);
                },
          icon: const Icon(Icons.folder_open),
          label: Text(t('Elegir carpeta')),
        ),
        const SizedBox(height: 12),
        Text(
          t(
            'Monta tu recurso SMB/NFS en el sistema y selecciona su carpeta. El NAS debe admitir bloqueos de archivo.',
          ),
        ),
      ],
      const SizedBox(height: 25),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: _ocupado ? null : _sincronizar,
          icon: _ocupado
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          label: Text(t(_ocupado ? 'Sincronizando…' : 'Sincronizar ahora')),
        ),
      ),
      if (_resultado != null)
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: SelectableText(_resultado!),
        ),
      const SizedBox(height: 20),
      Text(
        t('Última sincronización: {fecha}', {
          'fecha':
              widget.controlador.preferencias['ultima_sincronizacion']
                  as String? ??
              t('Nunca'),
        }),
        style: const TextStyle(fontSize: 12),
      ),
    ],
  );
}
