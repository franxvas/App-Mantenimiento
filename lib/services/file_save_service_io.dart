import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

Future<void> saveFileBytes({
  required List<int> bytes,
  required String filename,
  required String mimeType,
}) async {
  final extension = _extensionFor(filename);
  final type = extension.isEmpty ? FileType.any : FileType.custom;
  final allowed = extension.isEmpty ? null : <String>[extension];
  final data = Uint8List.fromList(bytes);

  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Guardar archivo',
    fileName: filename,
    type: type,
    allowedExtensions: allowed,
    bytes: Platform.isIOS || Platform.isAndroid ? data : null,
  );
  if (path == null || path.trim().isEmpty) {
    debugPrint('Guardar archivo cancelado por el usuario.');
    return;
  }

  if (Platform.isIOS || Platform.isAndroid) {
    // En iOS/Android, el plugin guarda los bytes al usar saveFile con bytes.
    debugPrint('Archivo guardado en: $path');
    return;
  }

  try {
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    debugPrint('Archivo guardado en: $path');
  } catch (e) {
    // En iOS/Android el plugin ya persiste los bytes al usar saveFile con bytes.
    debugPrint('Aviso guardando archivo ($path): $e');
  }
}

String _extensionFor(String filename) {
  final trimmed = filename.trim();
  if (trimmed.isEmpty || !trimmed.contains('.')) {
    return '';
  }
  final parts = trimmed.split('.');
  final ext = parts.isNotEmpty ? parts.last.trim() : '';
  return ext;
}
