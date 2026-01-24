import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';

import '../services/excel_export_service.dart';
import 'parametros_templates.dart';

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

  @override
  Widget build(BuildContext context) {
    final headers = headersFor(widget.disciplinaKey, widget.tipo);
    final columns = headers.asMap().entries.map((entry) => DatasetColumn(header: entry.value, order: entry.key)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.disciplinaLabel.toUpperCase()} - ${widget.tipo.toUpperCase()}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2C3E50),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: widget.tipo == 'reportes'
          ? _ReportesViewer(
              disciplinaLabel: widget.disciplinaLabel,
              disciplinaKey: widget.disciplinaKey,
              columns: columns,
              selectedProductId: _selectedProductId,
              onProductSelected: (productId) => setState(() => _selectedProductId = productId),
            )
          : _BaseViewer(
              disciplinaLabel: widget.disciplinaLabel,
              disciplinaKey: widget.disciplinaKey,
              columns: columns,
            ),
    );
  }
}

class _BaseViewer extends StatelessWidget {
  final String disciplinaLabel;
  final String disciplinaKey;
  final List<DatasetColumn> columns;

  const _BaseViewer({
    required this.disciplinaLabel,
    required this.disciplinaKey,
    required this.columns,
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
      stream: productsRef.where('disciplina', isEqualTo: disciplinaKey).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('No hay parámetros disponibles.'));
        }

        final rows = snapshot.data!.docs
            .map((doc) => DatasetRow.fromBaseDocument(doc, columns))
            .toList()
          ..sort(DatasetRow.sortByNombre);

        return _ViewerContent(
          columns: columns,
          rows: rows,
          disciplinaLabel: disciplinaLabel,
          tipo: 'base',
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

  const _ReportesViewer({
    required this.disciplinaLabel,
    required this.disciplinaKey,
    required this.columns,
    required this.selectedProductId,
    required this.onProductSelected,
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
      stream: productsRef.where('disciplina', isEqualTo: disciplinaKey).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('No hay productos para reportes.'));
        }

        final products = snapshot.data!.docs
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
                          currentProductDoc,
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

  const _ViewerContent({
    required this.columns,
    required this.rows,
    required this.disciplinaLabel,
    required this.tipo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: columns.map((column) => DataColumn(label: Text(column.header))).toList(),
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
      final excel = Excel.createExcel();
      if (excel.sheets.keys.contains('Sheet1')) {
        excel.rename('Sheet1', 'Parametros');
      }
      final sheet = excel['Parametros'];
      final headers = columns.map((column) => column.header).toList();
      sheet.appendRow(headers.map(TextCellValue.new).toList());
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
}

class DatasetRow {
  final Map<String, dynamic> values;
  final String sortKey;

  DatasetRow({required this.values, required this.sortKey});

  static int sortByNombre(DatasetRow a, DatasetRow b) {
    return a.sortKey.compareTo(b.sortKey);
  }

  factory DatasetRow.fromBaseDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    List<DatasetColumn> columns,
  ) {
    final values = <String, dynamic>{};
    final nombre = doc.data()['nombre']?.toString() ?? '';

    for (final column in columns) {
      values[column.header] = valueForHeader(
        column.header,
        productDoc: doc,
      );
    }

    final sortKey = nombre.isNotEmpty ? nombre.toLowerCase() : doc.id.toLowerCase();
    return DatasetRow(values: values, sortKey: sortKey);
  }

  factory DatasetRow.fromReporteDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    QueryDocumentSnapshot<Map<String, dynamic>> product,
    List<DatasetColumn> columns,
  ) {
    final values = <String, dynamic>{};
    final nombre = product.data()['nombre']?.toString() ?? '';

    for (final column in columns) {
      values[column.header] = valueForHeader(
        column.header,
        productDoc: product,
        reportDoc: doc,
      );
    }

    final sortKey = nombre.isNotEmpty ? '${nombre.toLowerCase()}-${doc.id.toLowerCase()}' : doc.id.toLowerCase();
    return DatasetRow(values: values, sortKey: sortKey);
  }
}
