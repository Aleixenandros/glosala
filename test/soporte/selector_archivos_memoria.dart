import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Captura lo enviado al diálogo del sistema sin abrir una ventana nativa.
class SelectorArchivosMemoria extends FilePickerPlatform {
  final archivos = <({String nombre, String tipo, Uint8List bytes})>[];
  bool cancelar = false;
  bool fallar = false;
  List<PlatformFile> seleccionados = [];

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    if (fallar) throw StateError('Fallo del selector');
    return cancelar ? [] : seleccionados;
  }

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

final class ArchivoSeleccionadoMemoria extends PlatformFile {
  ArchivoSeleccionadoMemoria(this.name, this.bytes, {this.tamanoDeclarado});
  @override
  final String name;
  final Uint8List bytes;
  final int? tamanoDeclarado;
  @override
  Uri get uri => Uri.file('/pruebas/$name');
  @override
  Never get xFile => throw UnimplementedError();
  @override
  int? lengthSync() => tamanoDeclarado ?? bytes.length;
  @override
  Future<int?> length() async => lengthSync();
  @override
  Future<Uint8List> readAsBytes() async => bytes;
  @override
  Stream<Uint8List> readAsByteStream() async* {
    yield bytes;
  }
}
