import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// La integración nativa solo se activa desde el arranque de escritorio.
class VentanaEscritorio extends ChangeNotifier with WindowListener {
  static final instancia = VentanaEscritorio();

  bool activa = false;
  bool maximizada = false;
  bool _cerrando = false;
  Future<bool> Function()? antesDeCerrar;

  Future<void> inicializar() async {
    if (kIsWeb ||
        !{
          TargetPlatform.linux,
          TargetPlatform.windows,
          TargetPlatform.macOS,
        }.contains(defaultTargetPlatform)) {
      return;
    }
    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        title: 'Glosala',
        minimumSize: Size(640, 480),
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
      ),
    );
    maximizada = await windowManager.isMaximized();
    activa = true;
  }

  Future<void> minimizar() => windowManager.minimize();
  Future<void> arrastrar() => windowManager.startDragging();

  Future<void> alternarMaximizada() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  /// También cubre Alt+F4 y el cierre solicitado por el sistema.
  Future<void> cerrar() async {
    if (_cerrando) return;
    _cerrando = true;
    try {
      if (await antesDeCerrar?.call() ?? true) {
        await windowManager.destroy();
      }
    } finally {
      _cerrando = false;
    }
  }

  @override
  void onWindowClose() => cerrar();

  @override
  void onWindowMaximize() {
    maximizada = true;
    notifyListeners();
  }

  @override
  void onWindowUnmaximize() {
    maximizada = false;
    notifyListeners();
  }
}

class BordeVentana extends StatelessWidget {
  const BordeVentana({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ventana = VentanaEscritorio.instancia;
    if (!ventana.activa) return child;
    return ListenableBuilder(
      listenable: ventana,
      builder: (_, _) => DragToResizeArea(
        resizeEdgeSize: 4,
        enableResizeEdges: ventana.maximizada ? [] : null,
        child: child,
      ),
    );
  }
}
