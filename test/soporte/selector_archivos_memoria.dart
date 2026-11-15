import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Captura lo enviado al diálogo del sistema sin abrir una ventana nativa.
class SelectorArchivosMemoria extends FilePickerPlatform {
  final archivos = <({String nombre, String tipo, Uint8List bytes})>[];
  bool cancelar = false;
  bool fallar = false;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    if (fallar) throw StateError('Fallo del selector');
    if (cancelar) return null;
    archivos.add((nombre: fileName, tipo: mimeType, bytes: bytes));
    return Uri.file('/exportaciones/$fileName');
  }
}
