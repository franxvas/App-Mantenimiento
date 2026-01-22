import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:appmantflutter/services/pdf_service.dart'; 

class DetalleReporteScreen extends StatelessWidget {
  final String reportId;
  final Map<String, dynamic>? initialReportData;

  const DetalleReporteScreen({
    super.key,
    required this.reportId,
    this.initialReportData,
  });

  @override
  Widget build(BuildContext context) {
    final reportDocRef = FirebaseFirestore.instance.collection('reportes').doc(reportId);

    return StreamBuilder<DocumentSnapshot>(
      stream: reportDocRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) return Scaffold(appBar: AppBar(), body: Center(child: Text("Error: ${snapshot.error}")));
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text("Reporte no encontrado.")));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String estado = data['estado_nuevo'] ?? data['estado'] ?? 'Desconocido';
        final bool isCompleted = estado.toLowerCase() == 'completado' || estado.toLowerCase() == 'operativo';
        
        // Manejo de Fechas
        final Timestamp? tsFecha = data['fecha'];
        final String fechaDisplay = tsFecha != null
            ? DateFormat('dd/MM/yyyy - HH:mm').format(tsFecha.toDate())
            : '--/--/----';

        // --- LÓGICA CORREGIDA PARA COMENTARIOS/SOLUCIÓN ---
        final String comentarios = data['comentarios'] ?? '';
        final bool haySolucion = comentarios.isNotEmpty;

        return Scaffold(
          backgroundColor: const Color(0xFFF0F2F5),
          appBar: AppBar(
            title: const Text("Detalle del Reporte", style: TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF2C3E50),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generando PDF del reporte...')),
                );

                try {
                  await PdfService.generarReporte(
                    reporte: data, 
                    reportId: reportId,
                  );
                } catch (e) {
                  print("Error PDF Reporte: $e");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al generar PDF: $e')),
                  );
                }
            },
            label: const Text("Exportar PDF", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            backgroundColor: const Color(0xFFE74C3C), 
          ),

          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(data, estado, isCompleted, fechaDisplay),
                
                _buildSection(
                  title: "Problema Reportado",
                  icon: FontAwesomeIcons.triangleExclamation,
                  content: Text(data['descripcion'] ?? data['motivo'] ?? 'Sin descripción del problema.', style: const TextStyle(fontSize: 15, color: Color(0xFF666666))),
                ),
                
                // --- AQUÍ ESTÁ EL CAMBIO ---
                _buildSection(
                  title: "Acciones Tomadas / Solución",
                  icon: FontAwesomeIcons.screwdriverWrench,
                  // Ahora mostramos 'comentarios'. Si está vacío, mostramos el mensaje rojo.
                  content: Text(
                    haySolucion ? comentarios : 'Pendiente de solución o acciones no registradas.', 
                    style: TextStyle(
                      fontSize: 15, 
                      // Si hay texto es gris oscuro, si no hay es rojo
                      color: haySolucion ? const Color(0xFF666666) : Colors.red[700]
                    ),
                  ),
                ),

                _buildDetails(data),
                const SizedBox(height: 50),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- WIDGETS AUXILIARES ---
  
  Widget _buildHeader(Map<String, dynamic> data, String estado, bool isCompleted, String fecha) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Reporte N° ${data['nro'] ?? '0000'}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text("Equipo: ${data['activo_nombre'] ?? 'N/A'}", style: const TextStyle(fontSize: 16, color: Color(0xFF666666))),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                decoration: BoxDecoration(
                  color: isCompleted ? const Color(0xFF2ECC71) : const Color(0xFFF1C40F),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isCompleted ? FontAwesomeIcons.check : FontAwesomeIcons.exclamation, color: Colors.white, size: 14),
                    const SizedBox(width: 8),
                    Text(estado.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Text(fecha, style: const TextStyle(fontSize: 14, color: Color(0xFF777777))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required Widget content}) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF3498DB)),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF444444))),
            ],
          ),
          const Divider(height: 20, thickness: 1),
          content,
        ],
      ),
    );
  }
  
  Widget _buildDetails(Map<String, dynamic> data) {
    // Leemos la ubicación del mapa guardado
    final ubicacion = data['ubicacion'] ?? {};

    return _buildSection(
      title: "Información General",
      icon: FontAwesomeIcons.circleInfo,
      content: Column(
        children: [
          _DetailRow(icon: FontAwesomeIcons.userTag, label: "Encargado", value: data['encargado'] ?? '--'),
          _DetailRow(icon: FontAwesomeIcons.tag, label: "Tipo de Reporte", value: data['tipo_reporte'] ?? 'General'),
          // Mostramos el Bloque correcto
          _DetailRow(icon: FontAwesomeIcons.building, label: "Bloque", value: ubicacion['bloque'] ?? '--'),
          _DetailRow(icon: FontAwesomeIcons.layerGroup, label: "Piso", value: ubicacion['piso'] ?? ubicacion['nivel'] ?? '--'),
        ],
      ),
    );
  }
  
  Widget _DetailRow({required IconData icon, required String label, required String value}) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
            children: [
                SizedBox(
                    width: 30,
                    child: Icon(icon, size: 18, color: const Color(0xFF555555)),
                ),
                Text("$label: ", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
                Expanded(
                    child: Text(value, style: const TextStyle(fontSize: 15, color: Color(0xFF666666))),
                ),
            ],
        ),
    );
  }
}
