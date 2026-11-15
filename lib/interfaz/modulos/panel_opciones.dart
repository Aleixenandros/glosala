// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../aplicacion/controlador_boveda.dart';
import '../../idiomas/gestor_idiomas.dart';

class PanelOpciones extends StatefulWidget {
  const PanelOpciones({super.key, required this.controlador});
  final ControladorBoveda controlador;
  @override
  State<PanelOpciones> createState() => _EstadoPanelOpciones();
}

class _EstadoPanelOpciones extends State<PanelOpciones> {
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
    _xml.text =
        widget.controlador.preferencias['idioma_xml_$_catalogo'] as String? ??
        GestorIdiomas.instancia.original(_catalogo);
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

  @override
  Widget build(BuildContext context) {
    final c = widget.controlador;
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Text(
          t('Opciones'),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 26),
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
          t('Apariencia'),
          style: const TextStyle(fontWeight: FontWeight.w600),
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
        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 25),
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
      ],
    );
  }
}
