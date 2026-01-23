import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../services/parametros_schema_service.dart';

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
  late final Future<void> _seedFuture;
  final _schemaService = ParametrosSchemaService();
  String? _selectedProductId;

  String get _docId => '${widget.disciplinaKey}_${widget.tipo}';

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
          '${widget.disciplinaLabel.toUpperCase()} - ${widget.tipo.toUpperCase()}',
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

              if (widget.tipo == 'reportes') {
                return _ReportesViewer(
                  disciplinaLabel: widget.disciplinaLabel,
                  columns: columns,
                  selectedProductId: _selectedProductId,
                  onProductSelected: (productId) => setState(() => _selectedProductId = productId),
                );
              }

              return _BaseViewer(
                disciplinaLabel: widget.disciplinaLabel,
                columns: columns,
              );
            },
          );
        },
      ),
    );
  }
}

class _BaseViewer extends StatelessWidget {
  final String disciplinaLabel;
  final List<DatasetColumn> columns;

  const _BaseViewer({
    required this.disciplinaLabel,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('productos')
          .where('disciplina', isEqualTo: disciplinaLabel)
          .snapshots(),
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
  final List<DatasetColumn> columns;
  final String? selectedProductId;
  final ValueChanged<String?> onProductSelected;

  const _ReportesViewer({
    required this.disciplinaLabel,
    required this.columns,
    required this.selectedProductId,
    required this.onProductSelected,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('productos')
          .where('disciplina', isEqualTo: disciplinaLabel)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No hay productos para reportes.'));
        }

        final products = snapshot.data!.docs;
        final currentProductId = selectedProductId ?? products.first.id;
        final currentProductDoc = products.firstWhere((doc) => doc.id == currentProductId, orElse: () => products.first);
        final productName = currentProductDoc['nombre']?.toString() ?? currentProductId;
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
                        child: Text(doc['nombre']?.toString() ?? doc.id),
                      ),
                    )
                    .toList(),
                onChanged: onProductSelected,
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('productos')
                    .doc(currentProductId)
                    .collection('reportes')
                    .snapshots(),
                builder: (context, reportSnapshot) {
                  if (reportSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!reportSnapshot.hasData) {
                    return const Center(child: Text('No hay reportes disponibles.'));
                  }

                  final rows = reportSnapshot.data!.docs
                      .map((doc) =>
                          DatasetRow.fromReporteDocument(doc, currentProductId, disciplinaLabel, productName, columns))
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

      sheet.appendRow(columns.map((column) => _cellValue(column.displayName)).toList());

      for (final row in rows) {
        final rowValues = columns.map((column) => _cellValue(row.values[column.key])).toList();
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

  CellValue? _cellValue(dynamic value) {
    if (value == null) {
      return const TextCellValue('');
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

  static int sortByNombre(DatasetRow a, DatasetRow b) {
    final nombreA = (a.values['nombre']?.toString() ?? '').toLowerCase();
    final nombreB = (b.values['nombre']?.toString() ?? '').toLowerCase();
    final nameCompare = nombreA.compareTo(nombreB);
    if (nameCompare != 0) {
      return nameCompare;
    }
    final idA = a.values['idActivo']?.toString() ?? a.values['idReporte']?.toString() ?? '';
    final idB = b.values['idActivo']?.toString() ?? b.values['idReporte']?.toString() ?? '';
    return idA.compareTo(idB);
  }

  factory DatasetRow.fromBaseDocument(QueryDocumentSnapshot doc, List<DatasetColumn> columns) {
    final data = doc.data() as Map<String, dynamic>;
    final ubicacion = data['ubicacion'] as Map<String, dynamic>? ?? {};
    final values = <String, dynamic>{};
    values['nombre'] = data['nombre']?.toString() ?? '';
    final nivel = _resolveNivel(data);

    for (final column in columns) {
      values[column.key] = switch (column.key) {
        'idActivo' => doc.id,
        'disciplina' => data['disciplina'],
        'categoriaActivo' => data['categoriaActivo'] ?? data['categoria'],
        'tipoActivo' => data['tipoActivo'],
        'bloque' => data['bloque'] ?? ubicacion['bloque'],
        'nivel' => nivel,
        'espacio' => data['espacio'] ?? ubicacion['area'],
        'estadoOperativo' => data['estadoOperativo'] ?? data['estado'],
        'condicionFisica' => data['condicionFisica'],
        'fechaUltimaInspeccion' => _formatTimestamp(data['fechaUltimaInspeccion']),
        'nivelCriticidad' => data['nivelCriticidad'],
        'impactoFalla' => data['impactoFalla'],
        'riesgoNormativo' => data['riesgoNormativo'],
        'frecuenciaMantenimientoMeses' => data['frecuenciaMantenimientoMeses'],
        'fechaProximoMantenimiento' => _formatTimestamp(data['fechaProximoMantenimiento']),
        'costoMantenimiento' => data['costoMantenimiento'],
        'costoReemplazo' => data['costoReemplazo'],
        'observaciones' => data['observaciones'],
        _ => data[column.key],
      };
    }

    return DatasetRow(values: values);
  }

  factory DatasetRow.fromReporteDocument(
    QueryDocumentSnapshot doc,
    String productId,
    String disciplina,
    String productName,
    List<DatasetColumn> columns,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final values = <String, dynamic>{};
    values['nombre'] = productName;

    for (final column in columns) {
      values[column.key] = switch (column.key) {
        'idReporte' => doc.id,
        'idActivo' => productId,
        'disciplina' => disciplina,
        'fechaInspeccion' => _formatTimestamp(data['fechaInspeccion']),
        'estadoDetectado' => data['estadoDetectado'],
        'riesgoElectrico' => data['riesgoElectrico'],
        'accionRecomendada' => data['accionRecomendada'],
        'costoEstimado' => data['costoEstimado'],
        'responsable' => data['responsable'],
        _ => data[column.key],
      };
    }

    return DatasetRow(values: values);
  }
}

String _resolveNivel(Map<String, dynamic> data) {
  final ubicacion = data['ubicacion'] as Map<String, dynamic>? ?? {};
  return (data['nivel'] ?? data['piso'] ?? ubicacion['nivel'] ?? ubicacion['piso'] ?? '').toString();
}

String _formatTimestamp(dynamic value) {
  if (value is Timestamp) {
    final date = value.toDate();
    return '${date.year.toString().padLeft(4, '0')}'
        '-${date.month.toString().padLeft(2, '0')}'
        '-${date.day.toString().padLeft(2, '0')}';
  }
  return value?.toString() ?? '';
}
