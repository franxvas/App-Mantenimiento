import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../productos/detalle_producto_screen.dart';
import '../reportes/detalle_reporte_screen.dart';

class AuditoriaScreen extends StatefulWidget {
  const AuditoriaScreen({super.key});

  @override
  State<AuditoriaScreen> createState() => _AuditoriaScreenState();
}

class _AuditoriaScreenState extends State<AuditoriaScreen> {
  DateTime? _selectedMonth;

  Query<Map<String, dynamic>> _buildQuery() {
    final collection = FirebaseFirestore.instance
        .collection('auditoria')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        );

    if (_selectedMonth == null) {
      final now = DateTime.now();
      final timeMin = now.subtract(const Duration(days: 30));
      return collection
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(timeMin))
          .orderBy('createdAt', descending: true);
    }

    final start = DateTime(_selectedMonth!.year, _selectedMonth!.month, 1);
    final next = _selectedMonth!.month == 12
        ? DateTime(_selectedMonth!.year + 1, 1, 1)
        : DateTime(_selectedMonth!.year, _selectedMonth!.month + 1, 1);

    return collection
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(next))
        .orderBy('createdAt', descending: true);
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final initial = _selectedMonth ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, 1),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'Selecciona un mes',
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      _selectedMonth = DateTime(picked.year, picked.month, 1);
    });
  }

  void _clearMonth() {
    setState(() => _selectedMonth = null);
  }

  String _filterLabel() {
    if (_selectedMonth == null) {
      return 'Mostrando últimos 30 días';
    }
    final label = '${_monthName(_selectedMonth!.month)} ${_selectedMonth!.year}';
    return 'Mes: ${_capitalize(label)}';
  }

  String _formatDayHeader(DateTime date) {
    final label = '${date.day} de ${_monthName(date.month)} del ${date.year}';
    return _capitalize(label);
  }

  String _formatHour(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  String _monthName(int month) {
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    if (month < 1 || month > 12) return '';
    return months[month - 1];
  }

  String _actorLabel(AuditEvent event) {
    return event.actorName ??
        event.actorEmail ??
        'Usuario';
  }

  String _summaryText(AuditEvent event) {
    return '${_actorLabel(event)} ${event.message}';
  }

  String _fieldLabel(String field) {
    const labels = {
      'nombre': 'Nombre',
      'descripcion': 'Descripción',
      'marca': 'Marca',
      'serie': 'Serie',
      'subcategoria': 'Subcategoría',
      'disciplina': 'Disciplina',
      'categoria': 'Categoría',
      'ubicacion.bloque': 'Ubicación: bloque',
      'ubicacion.nivel': 'Ubicación: nivel',
      'ubicacion.area': 'Ubicación: área',
      'estadoOperativo': 'Estado operativo',
      'frecuenciaMantenimientoMeses': 'Frecuencia mant.',
      'costoReemplazo': 'Costo reemplazo',
      'vidaUtilEsperadaAnios': 'Vida útil esperada',
      'fechaInstalacion': 'Fecha de instalación',
      'tipoMobiliario': 'Tipo mobiliario',
      'materialPrincipal': 'Material principal',
      'usoIntensivo': 'Uso intensivo',
      'movilidad': 'Movilidad',
      'fabricante': 'Fabricante',
      'modelo': 'Modelo',
      'fechaAdquisicion': 'Fecha adquisición',
      'proveedor': 'Proveedor',
      'observaciones': 'Observaciones',
      'imagenUrl': 'Foto',
      'idActivo': 'ID Activo',
      'label': 'Nombre',
      'icon': 'Ícono',
    };
    return labels[field] ?? field;
  }

  Future<void> _openProducto(BuildContext context, AuditEvent event) async {
    final productId = event.productDocId;
    if (productId == null || productId.isEmpty) return;
    final snapshot = await FirebaseFirestore.instance.collection('productos').doc(productId).get();
    if (!snapshot.exists) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activo no encontrado.')),
      );
      return;
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalleProductoScreen(productId: productId),
      ),
    );
  }

  Future<void> _openReporte(BuildContext context, AuditEvent event) async {
    final reportId = event.reportId;
    if (reportId == null || reportId.isEmpty) return;

    DocumentSnapshot<Map<String, dynamic>>? snapshot;
    if (event.productDocId != null && event.productDocId!.isNotEmpty) {
      snapshot = await FirebaseFirestore.instance
          .collection('productos')
          .doc(event.productDocId)
          .collection('reportes')
          .doc(reportId)
          .get();
    }
    snapshot ??= await FirebaseFirestore.instance.collection('reportes').doc(reportId).get();

    if (!snapshot.exists) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte no encontrado.')),
      );
      return;
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalleReporteScreen(
          reportId: reportId,
          productId: event.productDocId,
        ),
      ),
    );
  }

  void _showEventDetail(BuildContext parentContext, AuditEvent event) {
    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final dateLabel = DateFormat('dd/MM/yyyy hh:mm a').format(event.createdAt);
        final before = (event.meta['before'] as Map?)?.cast<String, dynamic>() ?? {};
        final after = (event.meta['after'] as Map?)?.cast<String, dynamic>() ?? {};
        final keys = before.keys.toSet()..addAll(after.keys);

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const Text(
                  'Detalle de auditoría',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  _summaryText(event),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text('Usuario: ${_actorLabel(event)}'),
                Text('Acción: ${event.action}'),
                Text('Fecha: $dateLabel'),
                if (event.changes.isNotEmpty && event.action == 'asset.update') ...[
                  const SizedBox(height: 16),
                  const Text('Cambios detectados:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...event.changes.map(
                    (field) => Text('• ${_fieldLabel(field)}'),
                  ),
                ],
                if (keys.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Antes / Después:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...keys.map((field) {
                    final beforeValue = before[field]?.toString() ?? '';
                    final afterValue = after[field]?.toString() ?? '';
                    return Text('• ${_fieldLabel(field)}: $beforeValue → $afterValue');
                  }),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    if (event.productDocId != null && event.productDocId!.isNotEmpty)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _openProducto(parentContext, event);
                          },
                          child: const Text('Ver activo'),
                        ),
                      ),
                    if (event.reportId != null && event.reportId!.isNotEmpty) ...[
                      if (event.productDocId != null && event.productDocId!.isNotEmpty)
                        const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _openReporte(parentContext, event);
                          },
                          child: const Text('Ver reporte'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPill(BuildContext context, AuditEvent event) {
    final isRename = event.action == 'asset.id_renamed';
    final background = isRename ? const Color(0xFFFFF3CD) : Colors.white;
    final border = isRename ? const Color(0xFFFFE4A6) : Colors.grey.shade200;
    final summary = _summaryText(event);
    final hour = _formatHour(event.createdAt);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _showEventDetail(context, event),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Text(
            '$summary - $hour',
            style: const TextStyle(fontSize: 14, color: Color(0xFF2C3E50)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auditoría'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _buildQuery().snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildFilterCard(),
                const SizedBox(height: 24),
                const Center(child: Text('Sin eventos para este rango.')),
              ],
            );
          }

          final events = <AuditEvent>[];
          for (final doc in snapshot.data!.docs) {
            final event = AuditEvent.fromDoc(doc);
            if (event != null) {
              events.add(event);
            }
          }

          final grouped = <DateTime, List<AuditEvent>>{};
          final order = <DateTime>[];

          for (final event in events) {
            final dayKey = DateTime(event.createdAt.year, event.createdAt.month, event.createdAt.day);
            if (!grouped.containsKey(dayKey)) {
              grouped[dayKey] = [];
              order.add(dayKey);
            }
            grouped[dayKey]!.add(event);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFilterCard(),
              const SizedBox(height: 16),
              ...order.map((day) {
                final dayEvents = grouped[day] ?? [];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDayHeader(day),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        ...dayEvents
                            .map(
                              (event) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildPill(context, event),
                              ),
                            )
                            .toList(),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterCard() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _filterLabel(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickMonth,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Elegir mes'),
                ),
                const SizedBox(width: 12),
                if (_selectedMonth != null)
                  TextButton(
                    onPressed: _clearMonth,
                    child: const Text('Últimos 30 días'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AuditEvent {
  final String id;
  final String action;
  final String message;
  final DateTime createdAt;
  final String? actorUid;
  final String? actorEmail;
  final String? actorName;
  final String? disciplina;
  final String? categoria;
  final String? productDocId;
  final String? idActivo;
  final String? reportId;
  final String? reportNro;
  final List<String> changes;
  final Map<String, dynamic> meta;

  AuditEvent({
    required this.id,
    required this.action,
    required this.message,
    required this.createdAt,
    this.actorUid,
    this.actorEmail,
    this.actorName,
    this.disciplina,
    this.categoria,
    this.productDocId,
    this.idActivo,
    this.reportId,
    this.reportNro,
    required this.changes,
    required this.meta,
  });

  static AuditEvent? fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final createdAtRaw = data['createdAt'];
    if (createdAtRaw is! Timestamp) {
      return null;
    }
    final changesRaw = data['changes'] as List?;
    final metaRaw = data['meta'] as Map?;
    return AuditEvent(
      id: doc.id,
      action: data['action']?.toString() ?? '',
      message: data['message']?.toString() ?? '',
      createdAt: createdAtRaw.toDate(),
      actorUid: data['actorUid']?.toString(),
      actorEmail: data['actorEmail']?.toString(),
      actorName: data['actorName']?.toString(),
      disciplina: data['disciplina']?.toString(),
      categoria: data['categoria']?.toString(),
      productDocId: data['productDocId']?.toString(),
      idActivo: data['idActivo']?.toString(),
      reportId: data['reportId']?.toString(),
      reportNro: data['reportNro']?.toString(),
      changes: changesRaw?.map((e) => e.toString()).toList() ?? const [],
      meta: metaRaw?.map((key, value) => MapEntry(key.toString(), value)) ?? const <String, dynamic>{},
    );
  }
}
