// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart' show CupertinoSlider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../adjuntos/recurso_adjunto.dart';
import '../../dominio/adjunto.dart';
import '../../idiomas/gestor_idiomas.dart';
import 'boton_reproduccion.dart';

String tamanoAdjunto(int bytes) => bytes < 1024
    ? '$bytes B'
    : bytes < 1024 * 1024
    ? '${(bytes / 1024).toStringAsFixed(1)} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

IconData iconoAdjunto(Adjunto adjunto) => adjunto.esImagen
    ? Icons.image_outlined
    : adjunto.esAudio
    ? Icons.audiotrack_outlined
    : adjunto.esVideo
    ? Icons.movie_outlined
    : adjunto.tipoMime == 'application/pdf'
    ? Icons.picture_as_pdf_outlined
    : Icons.insert_drive_file_outlined;

Future<void> guardarAdjunto(Adjunto adjunto) => FilePicker.saveFile(
  fileName: adjunto.nombre,
  bytes: adjunto.bytes,
  mimeType: adjunto.tipoMime,
);

Future<void> mostrarAdjunto(BuildContext context, Adjunto adjunto) =>
    showDialog<void>(
      context: context,
      builder: (_) => VisorAdjunto(adjunto: adjunto),
    );

class VisorAdjunto extends StatefulWidget {
  const VisorAdjunto({super.key, required this.adjunto});
  final Adjunto adjunto;

  @override
  State<VisorAdjunto> createState() => _EstadoVisorAdjunto();
}

class _EstadoVisorAdjunto extends State<VisorAdjunto> {
  Player? _jugador;
  VideoController? _video;
  RecursoAdjunto? _recurso;
  final _suscripciones = <StreamSubscription<dynamic>>[];
  bool _cargando = false;
  bool _ocupado = false;
  final _focoPosicion = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.adjunto.esVideo || widget.adjunto.esAudio) _preparar();
  }

  Future<void> _preparar() async {
    _cargando = true;
    try {
      final recurso = await prepararAdjunto(widget.adjunto);
      if (!mounted) {
        await recurso.liberar();
        return;
      }
      _recurso = recurso;
      // Inicializar al abrir un medio permite usar las notas aunque falte un códec.
      MediaKit.ensureInitialized();
      final jugador = _jugador = Player();
      if (widget.adjunto.esVideo) _video = VideoController(jugador);
      for (final flujo in <Stream<dynamic>>[
        jugador.stream.position,
        jugador.stream.duration,
        jugador.stream.playing,
        jugador.stream.volume,
      ]) {
        _suscripciones.add(
          flujo.listen((_) {
            if (mounted) setState(() {});
          }),
        );
      }
      _suscripciones.add(
        jugador.stream.error.listen((_) {
          if (mounted) {
            setState(
              () => _error = t(
                'No se puede reproducir este formato. Puedes guardar una copia y abrirla con otra aplicación.',
              ),
            );
          }
        }),
      );
      await jugador.open(Media(recurso.uri), play: false);
    } catch (_) {
      if (mounted) {
        _error = t(
          'No se puede reproducir este formato. Puedes guardar una copia y abrirla con otra aplicación.',
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _focoPosicion.dispose();
    for (final suscripcion in _suscripciones) {
      unawaited(suscripcion.cancel());
    }
    final recurso = _recurso;
    unawaited(
      (_jugador?.dispose() ?? Future<void>.value()).whenComplete(() async {
        await recurso?.liberar();
      }),
    );
    super.dispose();
  }

  Future<void> _operacion(Future<void> Function() accion) async {
    setState(() => _ocupado = true);
    try {
      await accion();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = t('No se ha podido abrir o guardar el archivo.'),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  bool get _puedeAbrir => kIsWeb
      ? widget.adjunto.tipoMime == 'application/pdf'
      : RegExp(
          r'\.(pdf|docx?|odt|xlsx?|ods|pptx?|odp|txt|md|csv|rtf|epub|json|xml)$',
          caseSensitive: false,
        ).hasMatch(widget.adjunto.nombre);

  @override
  Widget build(BuildContext context) {
    final adjunto = widget.adjunto;
    final pantalla = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 880,
        height: pantalla.height * .85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 8,
                top: 8,
                bottom: 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      adjunto.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: t('Cerrar'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: adjunto.esImagen
                    ? InteractiveViewer(
                        child: Center(
                          child: Image.memory(
                            adjunto.bytes,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Text(
                              t('No hay vista previa para este archivo.'),
                            ),
                          ),
                        ),
                      )
                    : _video != null
                    ? Video(controller: _video!, controls: NoVideoControls)
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              iconoAdjunto(adjunto),
                              size: 64,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(tamanoAdjunto(adjunto.bytes.length)),
                            if (!adjunto.esAudio) ...[
                              const SizedBox(height: 12),
                              Text(
                                t(
                                  'Abre el documento con tu aplicación habitual o guarda una copia.',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ),
            if (_cargando) const LinearProgressIndicator(),
            if (_jugador != null && _error == null) _controles(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (_puedeAbrir)
                    OutlinedButton.icon(
                      onPressed: _ocupado
                          ? null
                          : () => _operacion(() => abrirDocumento(adjunto)),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(
                        t(kIsWeb ? 'Abrir PDF' : 'Abrir en otra aplicación'),
                      ),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: _ocupado
                        ? null
                        : () => _operacion(() => guardarAdjunto(adjunto)),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: Text(t('Guardar una copia')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _tiempo(Duration duracion) {
    final segundos = duracion.inSeconds;
    final minutos = segundos ~/ 60;
    return '$minutos:${(segundos % 60).toString().padLeft(2, '0')}';
  }

  Widget _controles() {
    final jugador = _jugador!;
    final estado = jugador.state;
    final duracion = estado.duration.inMilliseconds.toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          BotonReproduccion(
            reproduciendo: estado.playing,
            alPulsar: _cargando ? null : () => _operacion(jugador.playOrPause),
          ),
          Expanded(
            // El Slider Material de Flutter 3.50 crea una capa semántica vacía
            // sobre todo el diálogo. Cupertino evita esa capa; mantenemos flechas
            // de teclado, foco visible y la etiqueta accesible del reproductor.
            child: Focus(
              focusNode: _focoPosicion,
              canRequestFocus: duracion > 0,
              onFocusChange: (_) => setState(() {}),
              onKeyEvent: (_, evento) {
                if (evento is! KeyDownEvent) return KeyEventResult.ignored;
                final tecla = evento.logicalKey;
                final avance =
                    tecla == LogicalKeyboardKey.arrowRight ||
                    tecla == LogicalKeyboardKey.arrowUp;
                final retroceso =
                    tecla == LogicalKeyboardKey.arrowLeft ||
                    tecla == LogicalKeyboardKey.arrowDown;
                if (!avance && !retroceso) return KeyEventResult.ignored;
                final destino =
                    (estado.position.inMilliseconds + (avance ? 5000 : -5000))
                        .clamp(0, duracion.toInt());
                unawaited(
                  _operacion(
                    () => jugador.seek(Duration(milliseconds: destino)),
                  ),
                );
                return KeyEventResult.handled;
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: _focoPosicion.hasFocus
                      ? Border.all(color: Theme.of(context).colorScheme.primary)
                      : null,
                ),
                child: Semantics(
                  label: t('Posición de reproducción'),
                  child: SizedBox(
                    height: 48,
                    child: CupertinoSlider(
                      value: estado.position.inMilliseconds.toDouble().clamp(
                        0,
                        duracion,
                      ),
                      max: duracion > 0 ? duracion : 1,
                      activeColor: Theme.of(context).colorScheme.primary,
                      thumbColor: Theme.of(context).colorScheme.primary,
                      onChangeStart: (_) => _focoPosicion.requestFocus(),
                      onChanged: duracion <= 0
                          ? null
                          : (valor) => jugador.seek(
                              Duration(milliseconds: valor.round()),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Text(
            '${_tiempo(estado.position)} / ${_tiempo(estado.duration)}',
            style: const TextStyle(fontSize: 12),
          ),
          IconButton(
            tooltip: t(estado.volume == 0 ? 'Activar sonido' : 'Silenciar'),
            onPressed: () => _operacion(
              () => jugador.setVolume(estado.volume == 0 ? 100 : 0),
            ),
            icon: Icon(
              estado.volume == 0
                  ? Icons.volume_off_outlined
                  : Icons.volume_up_outlined,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
