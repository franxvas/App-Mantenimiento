import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../services/parametros_schema_service.dart';

class ParametrosViewerScreen extends StatefulWidget {
  final String disciplina;
  final String tipo;

  const ParametrosViewerScreen({
    super.key,
    required this.disciplina,
    required this.tipo,
  });

  @override
  State<ParametrosViewerScreen> createState() => _ParametrosViewerScreenState();
}

class _ParametrosViewerScreenState extends State<ParametrosViewerScreen> {
  late final Future<void> _seedFuture;
  final _schemaService = ParametrosSchemaService();

  String get _docId => '${widget.disciplina}_${widget.tipo}';

  @override
  void initState() {
    super.initState();
    _seedFuture = _schemaService.seedSchemasIfMissing();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.disciplina.toUpperCase()} - ${widget.tipo.toUpperCase()}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2C3E50),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<void>(
        future: _seedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('parametros_schemas').doc(_docId).snapshots(),
            builder: (context, schemaSnapshot) {
              if (schemaSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!schemaSnapshot.hasData || !schemaSnapshot.data!.exists) {
                return const Center(child: Text('No hay esquema disponible.'));
              }

              final schemaData = schemaSnapshot.data!.data() as Map<String, dynamic>;
              final columns = (schemaData['columns'] as List<dynamic>? ?? [])
                  .map((column) => DatasetColumn.fromMap(column as Map<String, dynamic>))
                  .toList()
                ..sort((a, b) => a.order.compareTo(b.order));

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('parametros_datasets')
                    .doc(_docId)
                    .collection('rows')
                    .snapshots(),
                builder: (context, rowsSnapshot) {
                  if (rowsSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!rowsSnapshot.hasData) {
                    return const Center(child: Text('No hay parámetros disponibles.'));
                  }

                  final rows = rowsSnapshot.data!.docs
                      .map((doc) => DatasetRow.fromMap(doc.data() as Map<String, dynamic>))
                      .toList()
                    ..sort((a, b) => _rowSorter(a, b));

                  return _ViewerContent(
                    columns: columns,
                    rows: rows,
                    disciplina: widget.disciplina,
                    tipo: widget.tipo,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  int _rowSorter(DatasetRow a, DatasetRow b) {
    final nombreA = (a.values['nombre']?.toString() ?? '').toLowerCase();
    final nombreB = (b.values['nombre']?.toString() ?? '').toLowerCase();
    final nameCompare = nombreA.compareTo(nombreB);
    if (nameCompare != 0) {
      return nameCompare;
    }
    final idA = a.values['id']?.toString() ?? '';
    final idB = b.values['id']?.toString() ?? '';
    return idA.compareTo(idB);
  }
}

class _ViewerContent extends StatelessWidget {
  final List<DatasetColumn> columns;
  final List<DatasetRow> rows;
  final String disciplina;
  final String tipo;

  const _ViewerContent({
    required this.columns,
    required this.rows,
    required this.disciplina,
    required this.tipo,
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
                          .map((column) => DataColumn(label: Text(column.displayName)))
                          .toList(),
                      rows: rows
                          .map(
                            (row) => DataRow(
                              cells: columns
                                  .map((column) => DataCell(Text(_stringify(row.values[column.key]))))
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
      final sheet = excel['Parametros'];

      sheet.appendRow(columns.map((column) => column.displayName).toList());

      for (final row in rows) {
        final rowValues = columns
            .map((column) => _cellValue(row.values[column.key]))
            .toList();
        sheet.appendRow(rowValues);
      }

      final bytes = excel.save();
      if (bytes == null) {
        throw Exception('No se pudo generar el archivo.');
      }

      final directory = await getApplicationDocumentsDirectory();
      final filename = _buildFilename();
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);

      await OpenFilex.open(file.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar Excel: $e')),
      );
    }
  }

  dynamic _cellValue(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is num || value is bool) {
      return value;
    }
    return value.toString();
  }

  String _buildFilename() {
    final now = DateTime.now();
    final date = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final tipoLabel = tipo.toUpperCase();
    return '${disciplina}_${tipoLabel}_$date.xlsx';
  }

  String _stringify(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString();
  }
}

class DatasetColumn {
  final String key;
  final String displayName;
  final int order;

  DatasetColumn({
    required this.key,
    required this.displayName,
    required this.order,
  });

  factory DatasetColumn.fromMap(Map<String, dynamic> map) {
    return DatasetColumn(
      key: map['key']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      order: map['order'] is int ? map['order'] as int : int.tryParse(map['order']?.toString() ?? '') ?? 0,
    );
  }
}

class DatasetRow {
  final Map<String, dynamic> values;

  DatasetRow({required this.values});

  factory DatasetRow.fromMap(Map<String, dynamic> map) {
    final values = <String, dynamic>{};
    values['id'] = map['id'];
    values['nombre'] = map['nombre'];
    values['piso'] = map['piso'];
    values['estado'] = map['estado'];
    final extras = Map<String, dynamic>.from(map['values'] as Map? ?? {});
    values.addAll(extras);
    return DatasetRow(values: values);
  }
}
