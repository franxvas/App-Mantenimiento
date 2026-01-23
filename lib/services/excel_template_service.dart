import 'package:excel/excel.dart';
import 'package:flutter/services.dart';

class ExcelTemplateLoadResult {
  final Excel excel;
  final Sheet sheet;
  final List<String> headers;

  ExcelTemplateLoadResult({
    required this.excel,
    required this.sheet,
    required this.headers,
  });
}

class ExcelTemplateService {
  const ExcelTemplateService();

  Future<ExcelTemplateLoadResult> loadTemplate(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final excel = Excel.decodeBytes(bytes);
    final sheet = _resolveSheet(excel);
    final headers = _readHeaders(sheet);
    return ExcelTemplateLoadResult(excel: excel, sheet: sheet, headers: headers);
  }

  Sheet _resolveSheet(Excel excel) {
    if (excel.tables.isNotEmpty) {
      return excel.tables.values.first;
    }
    return excel['Sheet1'];
  }

  List<String> _readHeaders(Sheet sheet) {
    final headerRow = sheet.row(0);
    if (headerRow.isEmpty) {
      return [];
    }
    return headerRow
        .map((cell) => cell?.value?.toString() ?? '')
        .where((value) => value.trim().isNotEmpty)
        .toList();
  }
}
