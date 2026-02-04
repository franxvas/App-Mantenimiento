import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:appmantflutter/shared/text_formatters.dart';

import 'package:appmantflutter/reportes/seleccionar_producto_reporte_screen.dart';
import 'package:appmantflutter/reportes/detalle_reporte_screen.dart';

class ListaReportesPorCategoriaScreen extends StatelessWidget {
  final String categoriaFilter;
  final String categoriaTitle;

  const ListaReportesPorCategoriaScreen({
    super.key,
    required this.categoriaFilter,
    required this.categoriaTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text("Reportes: $categoriaTitle"),
        titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(fontWeight: FontWeight.bold),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('reportes')
            .withConverter<Map<String, dynamic>>(
              fromFirestore: (snapshot, _) => snapshot.data() ?? {},
              toFirestore: (data, _) => data,
            )
            .where('categoria', isEqualTo: categoriaFilter)
            .orderBy('fechaInspeccion', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final errorMessage = snapshot.error.toString();
            final needsIndex = errorMessage.contains('failed-precondition') ||
                errorMessage.contains('requires an index');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber, size: 48, color: Colors.orange),
                    const SizedBox(height: 12),
                    Text(
                      needsIndex
                          ? 'Falta crear un índice compuesto para reportes por categoría.'
                          : 'Ocurrió un error al cargar los reportes.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      needsIndex
                          ? 'Crea un índice con: categoria ASC + fechaInspeccion DESC.'
                          : errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_outlined, size: 60, color: Colors.grey),
                  const SizedBox(height: 10),
                  Text("No hay reportes de $categoriaTitle", style: const TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              
              return _ReporteListCard(
                reporte: data, 
                reportId: doc.id
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SeleccionarProductoReporteScreen(
                categoriaFilter: categoriaFilter,
              ),
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Crear Nuevo Reporte',
      ),
    );
  }
}

class _ReporteListCard extends StatelessWidget {
  final Map<String, dynamic> reporte;
  final String reportId;

  const _ReporteListCard({
    required this.reporte, 
    required this.reportId, 
    super.key
  });

  @override
  Widget build(BuildContext context) {
    final String estado = reporte['estadoOperativo'] ??
        reporte['estadoNuevo'] ??
        reporte['estadoDetectado'] ??
        reporte['estado_nuevo'] ??
        reporte['estado'] ??
        'registrado';
    final bool isOk = estado.toLowerCase() == 'operativo' || estado.toLowerCase() == 'completado';
    final bool isDefectuoso = estado.toLowerCase() == 'defectuoso';
    final Color statusColor = isOk
        ? Colors.green
        : isDefectuoso
            ? Colors.orange
            : Colors.red;
    
    final DateTime? fecha = _resolveFechaHora(reporte);
    final String fechaDisplay = fecha == null ? '--/--/----' : formatDateTimeDMYHM(fecha);
    final String tipoReporte = (reporte['tipoReporte'] ?? reporte['tipo_reporte'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetalleReporteScreen(
                reportId: reportId,
                initialReportData: reporte,
              ),
            ),
          );
        },
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          leading: CircleAvatar(
            backgroundColor: statusColor.withOpacity(0.1),
            child: Icon(isOk ? Icons.check : Icons.warning, color: statusColor),
          ),
          title: Text(
            reporte['nombreProducto'] ??
                reporte['activo_nombre'] ??
                reporte['activoNombre'] ??
                'Producto desconocido', 
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("N° ${reporte['nro']} • $fechaDisplay"),
              Text('Tipo: ${_formatDisplay(tipoReporte)}', maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatEstadoLabel(estado),
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatEstadoLabel(String estado) {
  final normalized = estado.replaceAll('_', ' ');
  if (normalized.isEmpty) {
    return estado;
  }
  return normalized
      .split(' ')
      .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

DateTime? _resolveFechaHora(Map<String, dynamic> reporte) {
  final value = reporte['createdAt'] ?? reporte['fechaEmision'] ?? reporte['fechaInspeccion'] ?? reporte['fecha'];
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

String _formatDisplay(String value) {
  final normalized = value.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) {
    return value;
  }
  return normalized
      .split(' ')
      .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
