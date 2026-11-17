// ignore_for_file: deprecated_member_use
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../aplicacion/controlador_boveda.dart';
import '../../dominio/adjunto.dart';
import '../../idiomas/gestor_idiomas.dart';
import 'visor_adjunto.dart';

class DialogoAdjuntos extends StatefulWidget {
  const DialogoAdjuntos({
    super.key,
    required this.controlador,
    required this.notaId,
    required this.alInsertar,
    required this.alQuitar,
  });
  final ControladorBoveda controlador;
  final String notaId;
  final ValueChanged<List<Adjunto>> alInsertar;
  final ValueChanged<Adjunto> alQuitar;

  @override
  State<DialogoAdjuntos> createState() => _EstadoDialogoAdjuntos();
}

class _EstadoDialogoAdjuntos extends State<DialogoAdjuntos> {
  bool _ocupado = false;
  String? _error;

  Future<void> _anadir() async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final archivos = await FilePicker.pickFiles(
        dialogTitle: t('Añadir archivos'),
      );
      final nuevos = <Adjunto>[];
      var total = widget.controlador.adjuntos.fold<int>(
        0,
        (total, a) => total + a.bytes.length,
      );
      final ids = widget.controlador.adjuntos.map((a) => a.id).toSet();
      for (final archivo in archivos) {
        if ((await archivo.length() ?? 0) > Adjunto.maximoBytes) {
          throw FormatException(t('El archivo supera el límite de 100 MB.'));
        }
        final datos = BytesBuilder(copy: false);
        await for (final bloque in archivo.readAsByteStream()) {
          if (datos.length + bloque.length > Adjunto.maximoBytes) {
            throw FormatException(t('El archivo supera el límite de 100 MB.'));
          }
          datos.add(bloque);
        }
        final adjunto = Adjunto.crear(archivo.name, datos.takeBytes());
        if (ids.add(adjunto.id)) total += adjunto.bytes.length;
        if (total > Adjunto.maximoBovedaBytes) {
          throw FormatException(
            t('La bóveda supera el límite de 512 MB de adjuntos.'),
          );
        }
        nuevos.add(adjunto);
      }
      if (mounted && nuevos.isNotEmpty) widget.alInsertar(nuevos);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message.toString()
              : t('No se han podido añadir los archivos.'),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controlador,
    builder: (context, _) {
      final nota = widget.controlador.notaPorId(widget.notaId);
      final adjuntos = nota == null
          ? <Adjunto>[]
          : widget.controlador.adjuntosDe(nota);
      final editable = nota != null && !nota.eliminada;
      return PopScope(
        canPop: !_ocupado,
        child: Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: SizedBox(
            width: 640,
            height: MediaQuery.sizeOf(context).height * .7,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          t('Adjuntos'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: t('Cerrar'),
                        onPressed: _ocupado
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (_ocupado) const LinearProgressIndicator(),
                Expanded(
                  child: adjuntos.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              t(
                                'Añade imágenes, vídeos, audio o documentos a esta nota.',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: adjuntos.length,
                          itemBuilder: (context, indice) {
                            final adjunto = adjuntos[indice];
                            return ListTile(
                              leading: Icon(iconoAdjunto(adjunto)),
                              title: Text(
                                adjunto.nombre,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                tamanoAdjunto(adjunto.bytes.length),
                              ),
                              onTap: _ocupado
                                  ? null
                                  : () => mostrarAdjunto(context, adjunto),
                              trailing: editable
                                  ? IconButton(
                                      tooltip: t('Quitar de la nota'),
                                      onPressed: _ocupado
                                          ? null
                                          : () => widget.alQuitar(adjunto),
                                      icon: const Icon(
                                        Icons.link_off,
                                        size: 20,
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (editable)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          t('Hasta 100 MB por archivo · 512 MB por bóveda'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _ocupado ? null : _anadir,
                          icon: const Icon(Icons.attach_file),
                          label: Text(t('Añadir archivos')),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
