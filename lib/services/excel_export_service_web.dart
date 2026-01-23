import 'dart:html' as html;
import 'dart:typed_data';

Future<void> exportExcelFile(List<int> bytes, String filename) async {
  final data = Uint8List.fromList(bytes);
  final blob = html.Blob([data], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
