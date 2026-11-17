// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../aplicacion/controlador_boveda.dart';
import '../../idiomas/gestor_idiomas.dart';
import 'panel_plugins.dart';
import 'panel_sincronizacion.dart';
import 'panel_acerca.dart';

class PanelOpciones extends StatefulWidget {
  const PanelOpciones({
    super.key,
    required this.controlador,
    required this.alAbrirNotas,
  });
  final ControladorBoveda controlador;
  final VoidCallback alAbrirNotas;
  @override
  State<PanelOpciones> createState() => _EstadoPanelOpciones();
}

class _EstadoPanelOpciones extends State<PanelOpciones> {
  String _seccion = 'apariencia';
  final _xml = TextEditingController();
  String _catalogo = GestorIdiomas.instancia.actual;
  String? _mensaje;
  bool _modificado = false;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();
  }

  @override
  void dispose() {
    _xml.dispose();
    super.dispose();
  }

  void _cargarCatalogo() {
    final guardado = widget.controlador.preferencias['idioma_xml_$_catalogo'];
    final gestor = GestorIdiomas.instancia;
    _xml.text = guardado is String
        ? gestor.completarCatalogo(_catalogo, guardado)
        : gestor.original(_catalogo);
    _modificado = false;
  }

  void _guardar() {
    try {
      GestorIdiomas.instancia.aplicar(_catalogo, _xml.text);
      widget.controlador.configurar('idioma_xml_$_catalogo', _xml.text);
      setState(() {
        _mensaje = t('Traducción guardada.');
        _modificado = false;
      });
    } catch (error) {
      setState(() => _mensaje = '${t('XML no válido.')} $error');
    }
  }

  Future<void> _cambiarCatalogo(String codigo) async {
    if (_modificado) {
      final descartar = await showDialog<bool>(
        context: context,
        builder: (contexto) => AlertDialog(
          title: Text(t('Hay cambios sin guardar.')),
          content: Text(t('¿Quieres descartar los cambios del XML?')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contexto, false),
              child: Text(t('Cancelar')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(contexto, true),
              child: Text(t('Descartar')),
            ),
          ],
        ),
      );
      if (descartar != true) return;
    }
    if (mounted) {
      setState(() {
        _catalogo = codigo;
        _cargarCatalogo();
        _mensaje = null;
      });
    }
  }

  Future<void> _archivo(bool importar) async {
    setState(() => _ocupado = true);
    try {
      if (importar) {
        final archivo = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['xml'],
        );
        if (archivo == null) return;
        final contenido = utf8.decode(await archivo.readAsBytes());
        GestorIdiomas.instancia.validar(contenido, _catalogo);
        if (mounted) {
          setState(() {
            _xml.text = contenido;
            _modificado = true;
            _mensaje = t(
              'XML importado. Pulsa Guardar traducción para aplicarlo.',
            );
          });
        }
      } else {
        await FilePicker.saveFile(
          fileName: '$_catalogo.xml',
          mimeType: 'application/xml',
          bytes: Uint8List.fromList(utf8.encode(_xml.text)),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _mensaje = '$error');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  static const _secciones = {
    'apariencia': (Icons.palette_outlined, 'Apariencia'),
    'idiomas': (Icons.translate_rounded, 'Idiomas'),
    'boveda': (Icons.folder_outlined, 'Bóveda local'),
    'plugins': (Icons.extension_outlined, 'Plugins'),
    'acerca': (Icons.info_outline_rounded, 'Acerca de'),
    'sincronizacion': (Icons.sync_rounded, 'Sincronización'),
  };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      final compacto = limites.maxWidth < 700;
      final contenido = switch (_seccion) {
        'idiomas' => _idiomas(),
        'boveda' => _boveda(),
        'plugins' => _pagina([PanelPlugins(controlador: widget.controlador)]),
        'acerca' => const PanelAcerca(),
        'sincronizacion' => PanelSincronizacion(
          controlador: widget.controlador,
        ),
        _ => _apariencia(),
      };
      if (compacto) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                key: const Key('seccion-opciones'),
                initialValue: _seccion,
                isExpanded: true,
                decoration: InputDecoration(labelText: t('Opciones')),
                items: [
                  for (final entrada in _secciones.entries)
                    DropdownMenuItem(
                      value: entrada.key,
                      child: Text(t(entrada.value.$2)),
                    ),
                ],
                onChanged: (valor) {
                  if (valor != null) setState(() => _seccion = valor);
                },
              ),
            ),
            Expanded(child: contenido),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 208,
            child: LayoutBuilder(
              builder: (context, limites) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: limites.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 14, 12, 22),
                            child: Text(
                              t('Opciones'),
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          for (final clave in _secciones.keys.where(
                            (clave) => clave != 'sincronizacion',
                          ))
                            _destino(clave),
                          const Spacer(),
                          const Divider(),
                          _destino('sincronizacion'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: contenido),
        ],
      );
    },
  );

  Widget _destino(String clave) {
    final (icono, titulo) = _secciones[clave]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        key: ValueKey('opciones-$clave'),
        leading: Icon(icono, size: 20),
        title: Text(t(titulo), style: const TextStyle(fontSize: 13)),
        selected: _seccion == clave,
        selectedTileColor: Theme.of(context).colorScheme.primary
            .withValues(alpha: .1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: () => setState(() => _seccion = clave),
      ),
    );
  }

  Widget _pagina(List<Widget> contenido) => ListView(
    key: ValueKey('contenido-$_seccion'),
    padding: const EdgeInsets.all(24),
    children: contenido,
  );

  Widget _apariencia() {
    final c = widget.controlador;
    return _pagina([
      Text(
        t('Apariencia'),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entrada in {
            'oscuro': 'Oscuro',
            'claro': 'Claro',
            'sistema': 'Sistema',
          }.entries)
            ChoiceChip(
              label: Text(t(entrada.value)),
              selected:
                  (c.preferencias['apariencia'] ??
                      (c.modoOscuro ? 'oscuro' : 'claro')) ==
                  entrada.key,
              onSelected: (_) => c.configurar('apariencia', entrada.key),
            ),
        ],
      ),
      const SizedBox(height: 18),
      Text(t('Tema de color')),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entrada in {
            'amatista': 'Amatista',
            'bosque': 'Bosque',
            'oceano': 'Océano',
            'ambar': 'Ámbar',
          }.entries)
            ChoiceChip(
              label: Text(t(entrada.value)),
              selected: (c.preferencias['tema'] ?? 'amatista') == entrada.key,
              onSelected: (_) => c.configurar('tema', entrada.key),
            ),
        ],
      ),
    ]);
  }

  Widget _idiomas() {
    final c = widget.controlador;
    return _pagina([
      Text(
        t('Idioma de la aplicación'),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: GestorIdiomas.instancia.actual,
        items: GestorIdiomas.disponibles.entries
            .map(
              (entrada) => DropdownMenuItem(
                value: entrada.key,
                child: Text(entrada.value),
              ),
            )
            .toList(),
        onChanged: (valor) {
          if (valor == null) return;
          GestorIdiomas.instancia.actual = valor;
          c.configurar('idioma', valor);
        },
      ),
      const SizedBox(height: 26),
      Text(
        t('Editor de traducciones XML'),
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      Text(
        t(
          'Edita los valores de texto, conserva las claves y los marcadores {cantidad} o {fecha}. Los cambios se aplican al guardar.',
        ),
        style: const TextStyle(height: 1.7),
      ),
      const SizedBox(height: 18),
      DropdownButtonFormField<String>(
        key: ValueKey(_catalogo),
        initialValue: _catalogo,
        items: GestorIdiomas.disponibles.entries
            .map(
              (entrada) => DropdownMenuItem(
                value: entrada.key,
                child: Text(entrada.value),
              ),
            )
            .toList(),
        onChanged: _ocupado
            ? null
            : (valor) {
                if (valor != null) _cambiarCatalogo(valor);
              },
      ),
      const SizedBox(height: 16),
      TextField(
        key: const Key('editor-xml'),
        controller: _xml,
        minLines: 12,
        maxLines: 18,
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 11,
          height: 1.6,
        ),
        onChanged: (_) => _modificado = true,
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton(
            onPressed: _ocupado ? null : _guardar,
            child: Text(t('Guardar traducción')),
          ),
          OutlinedButton(
            onPressed: _ocupado ? null : () => _archivo(true),
            child: Text(t('Importar XML')),
          ),
          OutlinedButton(
            onPressed: _ocupado ? null : () => _archivo(false),
            child: Text(t('Exportar XML')),
          ),
        ],
      ),
      if (_mensaje != null)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: SelectableText(_mensaje!),
        ),
    ]);
  }

  Widget _boveda() {
    final c = widget.controlador;
    return _pagina([
      Text(
        t('Notas de ejemplo'),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      Text(
        t(
          'Añade tres notas con ejemplos de Markdown y un toque de Chiquito Ipsum.',
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        icon: const Icon(Icons.auto_stories_outlined),
        label: Text(t('Añadir notas de ejemplo')),
        onPressed: () {
          c.anadirNotasEjemplo();
          widget.alAbrirNotas();
        },
      ),
      const SizedBox(height: 28),
      const Divider(),
      const SizedBox(height: 22),
      Text(
        t('Ubicación de la bóveda'),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      SelectableText(
        c.repositorio.location,
        style: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 11,
          height: 1.7,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        t(
          'Las notas y tareas se guardan en este dispositivo. Exporta tus notas o sincroniza para conservar otra copia.',
        ),
        style: const TextStyle(fontSize: 12, height: 1.8),
      ),
    ]);
  }
}
