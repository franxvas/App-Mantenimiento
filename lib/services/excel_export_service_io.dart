import 'file_save_service.dart';

Future<void> exportExcelFile(List<int> bytes, String filename) async {
  await saveFileBytes(
    bytes: bytes,
    filename: filename,
    mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
}
