import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';

import '../services/categorias_service.dart';
import '../services/excel_export_service.dart';
import '../services/usuarios_cache_service.dart';
import '../services/audit_service.dart';
import '../scan/qr_scanner_screen.dart';
import '../shared/text_formatters.dart';
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
        ),
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
    return FutureBuilder<List<CategoriaItem>>(
      future: CategoriasService.instance.fetchByDisciplina(disciplinaKey),
      builder: (context, categoriaSnapshot) {
        if (categoriaSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final categoriaMap = _buildCategoriaLabelMap(categoriaSnapshot.data ?? const []);
        String? resolveCategoria(String? value) {
          if (value == null || value.trim().isEmpty) {
            return null;
          }
          final key = normalizeCategoriaValue(value);
          if (key.isEmpty) return value;
          return categoriaMap[key] ?? value;
        }
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
                .map((doc) => DatasetRow.fromBaseDocument(
                      doc,
                      columns,
                      categoriaLabelResolver: resolveCategoria,
                    ))
                .toList()
              ..sort(DatasetRow.sortByNombre);

            return _ViewerContent(
              columns: columns,
              rows: rows,
              disciplinaKey: disciplinaKey,
              disciplinaLabel: disciplinaLabel,
              tipo: 'base',
            );
          },
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
    return FutureBuilder<void>(
      future: UsuariosCacheService.instance.preload(),
      builder: (context, cacheSnapshot) {
        if (cacheSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: productsRef.where('disciplina', isEqualTo: disciplinaKey).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData) {
              return const Center(child: Text('No hay productos para reportes.'));
            }

            final products = snapshot.data!.docs.toList();
            if (products.isEmpty) {
              return const Center(child: Text('No hay productos para reportes.'));
            }
            final currentProductId = selectedProductId ?? products.first.id;
            final currentProductDoc =
                products.firstWhere((doc) => doc.id == currentProductId, orElse: () => products.first);
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
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Activo'),
                    items: products
                        .map(
                          (doc) => DropdownMenuItem(
                            value: doc.id,
                            child: Text(
                              doc.data()['nombreProducto']?.toString() ?? doc.data()['nombre']?.toString() ?? doc.id,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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

                      final sortedDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(reportSnapshot.data!.docs)
                        ..sort((a, b) {
                          final dateA = _resolveReportDate(a.data());
                          final dateB = _resolveReportDate(b.data());
                          return dateB.compareTo(dateA);
                        });

                      final rows = sortedDocs
                          .map(
                            (doc) => DatasetRow.fromReporteDocument(
                              doc,
                              currentProductDoc,
                              columns,
                            ),
                          )
                          .toList();

                      return _ViewerContent(
                        columns: columns,
                        rows: rows,
                        disciplinaKey: disciplinaKey,
                        disciplinaLabel: disciplinaLabel,
                        tipo: 'reportes',
                        footerBuilder: (context, onGenerateExcel) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => QRScannerScreen(
                                            onProductFound: (productId) {
                                              final matchesDisciplina = products.any((doc) => doc.id == productId);
                                              if (!matchesDisciplina) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('El activo escaneado no pertenece a esta disciplina.'),
                                                  ),
                                                );
                                                return;
                                              }
                                              onProductSelected(productId);
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.qr_code_scanner),
                                    label: const Text('Escanear Activo'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: onGenerateExcel,
                                    icon: const Icon(Icons.download),
                                    label: const Text('Generar Excel'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ViewerContent extends StatelessWidget {
  final List<DatasetColumn> columns;
  final List<DatasetRow> rows;
  final String disciplinaKey;
  final String disciplinaLabel;
  final String tipo;
  final Widget Function(BuildContext, Future<void> Function())? footerBuilder;

  const _ViewerContent({
    required this.columns,
    required this.rows,
    required this.disciplinaKey,
    required this.disciplinaLabel,
    required this.tipo,
    this.footerBuilder,
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
        footerBuilder?.call(context, () => _generateExcel(context)) ??
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
      final headers = columns.map((column) => column.header).toList();
      if (tipo == 'base') {
        final grouped = _groupRowsByCategoria(rows);
        if (grouped.isEmpty) {
          if (excel.sheets.keys.contains('Sheet1')) {
            excel.rename('Sheet1', 'Parametros');
          }
          final sheet = excel['Parametros'];
          sheet.appendRow(headers.map(TextCellValue.new).toList());
        } else {
          final usedNames = <String>{};
          var index = 0;
          grouped.forEach((categoria, categoriaRows) {
            final baseName = _sanitizeSheetName(categoria);
            final sheetName = _uniqueSheetName(baseName, usedNames);
            usedNames.add(sheetName);
            if (index == 0 && excel.sheets.keys.contains('Sheet1')) {
              excel.rename('Sheet1', sheetName);
            }
            final sheet = excel[sheetName];
            sheet.appendRow(headers.map(TextCellValue.new).toList());
            for (final row in categoriaRows) {
              final rowValues = headers.map((header) => _cellValue(row.values[header])).toList();
              sheet.appendRow(rowValues);
            }
            index += 1;
          });
        }
      } else {
        if (excel.sheets.keys.contains('Sheet1')) {
          excel.rename('Sheet1', 'Parametros');
        }
        final sheet = excel['Parametros'];
        sheet.appendRow(headers.map(TextCellValue.new).toList());
        for (final row in rows) {
          final rowValues = headers.map((header) => _cellValue(row.values[header])).toList();
          sheet.appendRow(rowValues);
        }
      }

      final bytes = excel.save();
      if (bytes == null) {
        throw Exception('No se pudo generar el archivo.');
      }

      final filename = _buildFilename();
      await exportExcelFile(bytes, filename);
      await AuditService.logEvent(
        action: 'excel.export_success',
        message: 'exportó EXCEL (${disciplinaKey}) ${tipo == 'base' ? 'base' : 'reportes'} OK',
        disciplina: disciplinaKey,
        meta: {
          'filename': filename,
          'tipo': tipo,
        },
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel guardado correctamente.')),
        );
      }
    } catch (e) {
      await AuditService.logEvent(
        action: 'excel.export_failed',
        message: 'falló exportación EXCEL (${disciplinaKey}): ${_shortError(e)}',
        disciplina: disciplinaKey,
        meta: {
          'tipo': tipo,
          'error': e.toString(),
        },
      );
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

  Map<String, List<DatasetRow>> _groupRowsByCategoria(List<DatasetRow> rows) {
    const categoriaHeader = 'Categoria_Activo';
    final Map<String, List<DatasetRow>> grouped = {};
    for (final row in rows) {
      final raw = row.values[categoriaHeader]?.toString().trim() ?? '';
      final categoria = raw.isEmpty ? 'Otros' : raw;
      grouped.putIfAbsent(categoria, () => []).add(row);
    }
    return grouped;
  }

  String _sanitizeSheetName(String name) {
    var cleaned = name.trim();
    if (cleaned.isEmpty) {
      cleaned = 'Otros';
    }
    cleaned = cleaned.replaceAll(RegExp(r'[:\\\\/?*\\[\\]]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\\s+'), ' ').trim();
    if (cleaned.isEmpty) {
      cleaned = 'Otros';
    }
    if (cleaned.length > 31) {
      cleaned = cleaned.substring(0, 31);
    }
    return cleaned;
  }

  String _uniqueSheetName(String base, Set<String> used) {
    if (!used.contains(base)) {
      return base;
    }
    var index = 2;
    while (true) {
      final suffix = ' ($index)';
      final maxLen = 31 - suffix.length;
      final prefix = base.length > maxLen ? base.substring(0, maxLen) : base;
      final candidate = '$prefix$suffix';
      if (!used.contains(candidate)) {
        return candidate;
      }
      index += 1;
    }
  }

  String _buildFilename() {
    if (tipo == 'base') {
      final key = normalizeCategoriaValue(disciplinaLabel);
      final map = <String, String>{
        'electricas': 'Electricas',
        'mobiliarios': 'Mobiliario',
        'mecanica': 'Mecanica',
        'arquitectura': 'Arquitectura',
        'sanitarias': 'Sanitarias',
        'estructuras': 'Estructuras',
      };
      final label = map[key] ?? disciplinaLabel;
      return '${label}_Base_ES.xlsx';
    }
    return '${disciplinaLabel}_Reportes_ES.xlsx';
  }

  String _shortError(Object error) {
    final raw = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (raw.length <= 120) return raw;
    return '${raw.substring(0, 120)}...';
  }

  String _stringify(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString();
  }
}

DateTime _resolveReportDate(Map<String, dynamic> data) {
  final dynamic rawDate = data['fechaInspeccion'] ?? data['fecha'];
  if (rawDate is Timestamp) {
    return rawDate.toDate();
  }
  if (rawDate is DateTime) {
    return rawDate;
  }
  if (rawDate is String) {
    return DateTime.tryParse(rawDate) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

Map<String, String> _buildCategoriaLabelMap(List<CategoriaItem> items) {
  final map = <String, String>{};
  for (final item in items) {
    final valueKey = normalizeCategoriaValue(item.value);
    if (valueKey.isNotEmpty) {
      map[valueKey] = item.label;
    }
    final labelKey = normalizeCategoriaValue(item.label);
    if (labelKey.isNotEmpty) {
      map[labelKey] = item.label;
    }
  }
  return map;
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
    List<DatasetColumn> columns, {
    String? Function(String? value)? categoriaLabelResolver,
  }
  ) {
    final values = <String, dynamic>{};
    final nombre = doc.data()['nombre']?.toString() ?? '';

    for (final column in columns) {
      var value = valueForHeader(
        column.header,
        productDoc: doc,
      );
      if (column.header == 'Categoria_Activo' && categoriaLabelResolver != null) {
        final resolved = categoriaLabelResolver(value?.toString());
        if (resolved != null && resolved.trim().isNotEmpty) {
          value = resolved;
        }
      }
      values[column.header] = value;
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
