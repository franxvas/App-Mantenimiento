import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// IMPORTACIONES NECESARIAS
import 'package:appmantflutter/reportes/seleccionar_producto_reporte_screen.dart'; 
import 'package:appmantflutter/reportes/detalle_reporte_screen.dart'; // <--- NUEVO: Para ver el detalle y PDF

class ListaReportesPorCategoriaScreen extends StatelessWidget {
  final String categoriaFilter; // 'luminarias'
  final String categoriaTitle;  // 'Luminarias'

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
        backgroundColor: const Color(0xFF2C3E50),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('reportes')
            .withConverter<Map<String, dynamic>>(
              fromFirestore: (snapshot, _) => snapshot.data() ?? {},
              toFirestore: (data, _) => data,
            )
            .where('categoria', isEqualTo: categoriaFilter) // Filtra reportes por categoría
            .orderBy('fecha', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

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
              
              // Pasamos el ID del documento para poder navegar
              return _ReporteListCard(
                reporte: data, 
                reportId: doc.id // <--- ID NECESARIO PARA EL DETALLE
              );
            },
          );
        },
      ),
      // BOTÓN FLOTANTE: AGREGAR REPORTE
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
        backgroundColor: const Color(0xFF3498DB),
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Crear Nuevo Reporte',
      ),
    );
  }
}

// Tarjeta para mostrar el reporte en la lista (AHORA CLIQUEABLE)
class _ReporteListCard extends StatelessWidget {
  final Map<String, dynamic> reporte;
  final String reportId; // Nuevo parámetro

  const _ReporteListCard({
    required this.reporte, 
    required this.reportId, 
    super.key
  });

  @override
  Widget build(BuildContext context) {
    final String estado = reporte['estado_nuevo'] ?? 'Pendiente';
    final bool isOk = estado.toLowerCase() == 'operativo' || estado.toLowerCase() == 'completado';
    final Color statusColor = isOk ? Colors.green : Colors.red;
    
    // Fecha
    final Timestamp? ts = reporte['fecha'];
    final String fecha = ts != null ? DateFormat('dd/MM/yyyy').format(ts.toDate()) : '--';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell( // Efecto visual al tocar
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          // --- NAVEGACIÓN AL DETALLE (CON PDF INCLUIDO) ---
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetalleReporteScreen(
                reportId: reportId,
                initialReportData: reporte, // Pasamos datos para carga instantánea
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
            reporte['activo_nombre'] ?? 'Producto desconocido', 
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("N° ${reporte['nro']} • $fecha"),
              Text(reporte['descripcion'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
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
                child: Text(estado.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
