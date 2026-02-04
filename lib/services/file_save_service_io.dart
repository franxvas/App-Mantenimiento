import 'dart:io';

import 'package:file_picker/file_picker.dart';

Future<void> saveFileBytes({
  required List<int> bytes,
  required String filename,
  required String mimeType,
}) async {
  final extension = _extensionFor(filename);
  final type = extension.isEmpty ? FileType.any : FileType.custom;
  final allowed = extension.isEmpty ? null : <String>[extension];

  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Guardar archivo',
    fileName: filename,
    type: type,
    allowedExtensions: allowed,
  );
  if (path == null || path.trim().isEmpty) {
    return;
  }

  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
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
