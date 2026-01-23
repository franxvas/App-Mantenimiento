import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';

import '../services/excel_row_mapper.dart';
import '../services/excel_template_service.dart';
import '../services/excel_export_service.dart';

class ParametrosViewerScreen extends StatefulWidget {
  final String disciplinaKey;
  final String disciplinaLabel;
  final String tipo;

  const ParametrosViewerScreen({
    super.key,
    required this.disciplinaKey,
    required this.disciplinaLabel,
    required this.tipo,
  });

  @override
  State<ParametrosViewerScreen> createState() => _ParametrosViewerScreenState();
}

class _ParametrosViewerScreenState extends State<ParametrosViewerScreen> {
  String? _selectedProductId;
  late final Future<ExcelTemplateLoadResult> _templateFuture;

  String get _templateAssetPath => _buildTemplatePath(widget.disciplinaLabel, widget.tipo);

  @override
  void initState() {
    super.initState();
    _templateFuture = const ExcelTemplateService().loadTemplate(_templateAssetPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.disciplinaLabel.toUpperCase()} - ${widget.tipo.toUpperCase()}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2C3E50),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<ExcelTemplateLoadResult>(
        future: _templateFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('No se pudo cargar la plantilla.'));
          }

          final template = snapshot.data;
          final headers = template?.headers ?? [];
          final columns = headers.asMap().entries.map((entry) => DatasetColumn.fromHeader(entry.value, entry.key)).toList();

          if (widget.tipo == 'reportes') {
            return _ReportesViewer(
              disciplinaLabel: widget.disciplinaLabel,
              disciplinaKey: widget.disciplinaKey,
              columns: columns,
              selectedProductId: _selectedProductId,
              onProductSelected: (productId) => setState(() => _selectedProductId = productId),
              templateAssetPath: _templateAssetPath,
            );
          }

          return _BaseViewer(
            disciplinaLabel: widget.disciplinaLabel,
            disciplinaKey: widget.disciplinaKey,
            columns: columns,
            templateAssetPath: _templateAssetPath,
          );
        },
      ),
    );
  }
}

class _BaseViewer extends StatelessWidget {
  final String disciplinaLabel;
  final String disciplinaKey;
  final List<DatasetColumn> columns;
  final String templateAssetPath;

  const _BaseViewer({
    required this.disciplinaLabel,
    required this.disciplinaKey,
    required this.columns,
    required this.templateAssetPath,
  });

  @override
  Widget build(BuildContext context) {
    final productsRef = FirebaseFirestore.instance
        .collection('productos')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        );
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: productsRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('No hay parámetros disponibles.'));
        }

        final rows = snapshot.data!.docs
            .where(
              (doc) => _matchesDisciplina(
                doc.data(),
                disciplinaKey: disciplinaKey,
                disciplinaLabel: disciplinaLabel,
              ),
            )
            .map((doc) => DatasetRow.fromBaseDocument(doc, columns))
            .toList()
          ..sort(DatasetRow.sortByNombre);

        return _ViewerContent(
          columns: columns,
          rows: rows,
          disciplinaLabel: disciplinaLabel,
          tipo: 'base',
          templateAssetPath: templateAssetPath,
        );
      },
    );
  }
}

class _ReportesViewer extends StatelessWidget {
  final String disciplinaLabel;
  final String disciplinaKey;
  final List<DatasetColumn> columns;
  final String? selectedProductId;
  final ValueChanged<String?> onProductSelected;
  final String templateAssetPath;

  const _ReportesViewer({
    required this.disciplinaLabel,
    required this.disciplinaKey,
    required this.columns,
    required this.selectedProductId,
    required this.onProductSelected,
    required this.templateAssetPath,
  });

  @override
  Widget build(BuildContext context) {
    final productsRef = FirebaseFirestore.instance
        .collection('productos')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        );
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: productsRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('No hay productos para reportes.'));
        }

        final products = snapshot.data!.docs
            .where(
              (doc) => _matchesDisciplina(
                doc.data(),
                disciplinaKey: disciplinaKey,
                disciplinaLabel: disciplinaLabel,
              ),
            )
            .toList();
        if (products.isEmpty) {
          return const Center(child: Text('No hay productos para reportes.'));
        }
        final currentProductId = selectedProductId ?? products.first.id;
        final currentProductDoc = products.firstWhere((doc) => doc.id == currentProductId, orElse: () => products.first);
        if (currentProductId != selectedProductId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onProductSelected(currentProductId);
          });
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                value: currentProductId,
                decoration: const InputDecoration(labelText: 'Activo'),
                items: products
                    .map(
                      (doc) => DropdownMenuItem(
                        value: doc.id,
                        child: Text(doc.data()['nombre']?.toString() ?? doc.id),
                      ),
                    )
                    .toList(),
                onChanged: onProductSelected,
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: productsRef
                    .doc(currentProductId)
                    .collection('reportes')
                    .withConverter<Map<String, dynamic>>(
                      fromFirestore: (snapshot, _) => snapshot.data() ?? {},
                      toFirestore: (data, _) => data,
                    )
                    .snapshots(),
                builder: (context, reportSnapshot) {
                  if (reportSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!reportSnapshot.hasData) {
                    return const Center(child: Text('No hay reportes disponibles.'));
                  }

                  final rows = reportSnapshot.data!.docs
                      .map(
                        (doc) => DatasetRow.fromReporteDocument(
                          doc,
                          ProductRecord(id: currentProductId, data: currentProductDoc.data()),
                          columns,
                        ),
                      )
                      .toList()
                    ..sort(DatasetRow.sortByNombre);

                  return _ViewerContent(
                    columns: columns,
                    rows: rows,
                    disciplinaLabel: disciplinaLabel,
                    tipo: 'reportes',
                    templateAssetPath: templateAssetPath,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ViewerContent extends StatelessWidget {
  final List<DatasetColumn> columns;
  final List<DatasetRow> rows;
  final String disciplinaLabel;
  final String tipo;
  final String templateAssetPath;

  const _ViewerContent({
    required this.columns,
    required this.rows,
    required this.disciplinaLabel,
    required this.tipo,
    required this.templateAssetPath,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: rows.isEmpty
              ? const Center(child: Text('No hay parámetros disponibles.'))
              : SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                      child: DataTable(
                      columns: columns
                          .map((column) => DataColumn(label: Text(column.header)))
                          .toList(),
                      rows: rows
                          .map(
                            (row) => DataRow(
                              cells: columns
                                  .map((column) => DataCell(Text(_stringify(row.values[column.header]))))
                                  .toList(),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _generateExcel(context),
              icon: const Icon(Icons.download),
              label: const Text('Generar Excel'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF1ABC9C),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _generateExcel(BuildContext context) async {
    try {
      final template = await const ExcelTemplateService().loadTemplate(templateAssetPath);
      final excel = template.excel;
      final sheet = template.sheet;
      final headers = template.headers;

      _clearDataRows(sheet);

      for (final row in rows) {
        final rowValues = headers.map((header) => _cellValue(row.values[header])).toList();
        sheet.appendRow(rowValues);
      }

      final bytes = excel.save();
      if (bytes == null) {
        throw Exception('No se pudo generar el archivo.');
      }

      final filename = _buildFilename();
      await exportExcelFile(bytes, filename);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar Excel: $e')),
      );
    }
  }

  void _clearDataRows(Sheet sheet) {
    final totalRows = sheet.maxRows;
    for (var index = totalRows - 1; index >= 1; index--) {
      sheet.removeRow(index);
    }
  }

  CellValue? _cellValue(dynamic value) {
    if (value == null) {
      return TextCellValue('');
    }
    if (value is bool) {
      return BoolCellValue(value);
    }
    if (value is num) {
      return DoubleCellValue(value.toDouble());
    }
    return TextCellValue(value.toString());
  }

  String _buildFilename() {
    final now = DateTime.now();
    final date = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final tipoLabel = tipo == 'base' ? 'Base' : 'Reportes';
    return '${disciplinaLabel}_${tipoLabel}_$date.xlsx';
  }

  String _stringify(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString();
  }
}

class DatasetColumn {
  final String header;
  final int order;

  DatasetColumn({
    required this.header,
    required this.order,
  });

  factory DatasetColumn.fromHeader(String header, int order) {
    return DatasetColumn(
      header: header,
      order: order,
    );
  }
}

class DatasetRow {
  final Map<String, dynamic> values;

  DatasetRow({required this.values});

  static int sortByNombre(DatasetRow a, DatasetRow b) {
    final nombreA = (a.values['nombre']?.toString() ?? '').toLowerCase();
    final nombreB = (b.values['nombre']?.toString() ?? '').toLowerCase();
    final nameCompare = nombreA.compareTo(nombreB);
    if (nameCompare != 0) {
      return nameCompare;
    }
    final idA = _findValueByNormalizedHeader(a.values, 'idactivo') ??
        _findValueByNormalizedHeader(a.values, 'idreporte') ??
        '';
    final idB = _findValueByNormalizedHeader(b.values, 'idactivo') ??
        _findValueByNormalizedHeader(b.values, 'idreporte') ??
        '';
    return idA.compareTo(idB);
  }

  factory DatasetRow.fromBaseDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    List<DatasetColumn> columns,
  ) {
    final data = doc.data();
    final values = <String, dynamic>{};
    values['nombre'] = data['nombre']?.toString() ?? '';
    final product = ProductRecord(id: doc.id, data: data);

    for (final column in columns) {
      values[column.header] = ExcelRowMapper.valueForHeader(column.header, product);
    }

    return DatasetRow(values: values);
  }

  factory DatasetRow.fromReporteDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    ProductRecord product,
    List<DatasetColumn> columns,
  ) {
    final data = doc.data();
    final values = <String, dynamic>{};
    values['nombre'] = product.data['nombre']?.toString() ?? '';
    final report = ReportRecord(id: doc.id, data: data);

    for (final column in columns) {
      values[column.header] = ExcelRowMapper.valueForHeader(column.header, product, report: report);
    }

    return DatasetRow(values: values);
  }
}

String? _findValueByNormalizedHeader(Map<String, dynamic> values, String target) {
  for (final entry in values.entries) {
    if (ExcelRowMapper.normalizeHeader(entry.key) == target) {
      return entry.value?.toString();
    }
  }
  return null;
}

String _buildTemplatePath(String disciplinaLabel, String tipo) {
  final tipoLabel = tipo == 'base' ? 'Base' : 'Reportes';
  return 'assets/excel_templates/${disciplinaLabel}_${tipoLabel}_ES.xlsx';
}

bool _matchesDisciplina(
  Map<String, dynamic> data, {
  required String disciplinaKey,
  required String disciplinaLabel,
}) {
  final resolvedKey = _resolveDisciplinaKey(data);
  if (resolvedKey.isNotEmpty) {
    return resolvedKey == disciplinaKey.toLowerCase();
  }
  final labelValue = data['disciplinaLabel']?.toString() ?? data['disciplina']?.toString() ?? '';
  if (labelValue.isEmpty) {
    return false;
  }
  return labelValue.toLowerCase() == disciplinaLabel.toLowerCase();
}

String _resolveDisciplinaKey(Map<String, dynamic> data) {
  final disciplina = data['disciplina']?.toString();
  if (disciplina != null && disciplina.isNotEmpty) {
    return disciplina.toLowerCase();
  }
  final attrs = data['attrs'] as Map<String, dynamic>? ?? {};
  final fallback = data['disciplinaKey'] ?? attrs['disciplinaKey'] ?? attrs['disciplina'];
  return fallback?.toString().toLowerCase() ?? '';
}
