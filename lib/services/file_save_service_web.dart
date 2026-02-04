import 'dart:html' as html;
import 'dart:typed_data';

Future<void> saveFileBytes({
  required List<int> bytes,
  required String filename,
  required String mimeType,
}) async {
  final data = Uint8List.fromList(bytes);
  final blob = html.Blob([data], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
