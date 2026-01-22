import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; 
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Para generar el QR
import 'package:appmantflutter/services/schema_service.dart';

// IMPORTACIONES DE TUS OTRAS PANTALLAS Y SERVICIOS
import 'package:appmantflutter/reportes/generar_reporte_screen.dart'; 
import 'package:appmantflutter/productos/editar_producto_screen.dart'; 
import 'package:appmantflutter/services/pdf_service.dart'; 
import 'package:appmantflutter/reportes/detalle_reporte_screen.dart'; // <--- NUEVA IMPORTACIÓN NECESARIA

class DetalleProductoScreen extends StatelessWidget {
  final String productId;

  const DetalleProductoScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    final productDocRef = FirebaseFirestore.instance.collection('productos').doc(productId);
    final schemaService = SchemaService();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text("Detalle del Producto", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2C3E50),
        iconTheme: const IconThemeData(color: Colors.white),
        // BOTONES EN LA BARRA SUPERIOR (PDF y EDITAR)
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: productDocRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return Container();
              if (!snapshot.hasData || !snapshot.data!.exists) return Container();
              
              final data = snapshot.data!.data() as Map<String, dynamic>;
              
              return Row(
                children: [
                  // --- BOTÓN EXPORTAR FICHA TÉCNICA (PDF) ---
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                    tooltip: "Exportar Ficha Técnica",
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Generando Ficha Técnica...')),
                      );

                      try {
                        // Obtener los últimos 5 reportes para el PDF
                        final reportesQuery = await FirebaseFirestore.instance
                            .collection('reportes')
                            .where('productId', isEqualTo: productId)
                            .orderBy('fecha', descending: true)
                            .limit(5)
                            .get();
                        
                        final listaReportes = reportesQuery.docs.map((d) => d.data()).toList();

                        await PdfService.generarFichaTecnica(
                          producto: data,
                          productId: productId,
                          ultimosReportes: listaReportes,
                        );
                      } catch (e) {
                        print("Error PDF: $e");
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al generar PDF: $e')),
                        );
                      }
                    },
                  ),

                  // --- BOTÓN EDITAR ---
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    tooltip: "Editar Producto",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditarProductoScreen(
                            productId: productId,
                            initialData: data,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
      
      // CUERPO PRINCIPAL
      body: StreamBuilder<DocumentSnapshot>(
        stream: productDocRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Producto no encontrado."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String productName = data['nombre'] ?? 'N/A';
          final String initialStatus = data['estado'] ?? 'operativo';
          final String productCategory = data['categoria'] ?? 'N/A';
          final bool isOperativo = initialStatus.toLowerCase() == 'operativo';
          final Map<String, dynamic> ubicacion = data['ubicacion'] ?? {};
          final Map<String, dynamic> attrs = data['attrs'] ?? {};
          final String imageUrl = data['imagenUrl'] ?? ''; 
          final String codigoQR = (data['codigoQR'] ?? attrs['codigoQR'] ?? '').toString(); 
          final String disciplina = data['disciplina'] ?? '';

          final Timestamp? tsCompra = data['fechaCompra'];
          final String fechaCompra = tsCompra != null
              ? DateFormat('dd/MM/yyyy').format(tsCompra.toDate())
              : '--/--/----';

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen y Cabecera
                _buildProductHeader(data, isOperativo, imageUrl),

                // Descripción
                _buildSection(
                  title: "Descripción",
                  content: Text(data['descripcion'] ?? 'Sin descripción.', style: const TextStyle(fontSize: 15, color: Color(0xFF666666))),
                ),

                // Código QR
                _buildSection(
                  title: "Código QR",
                  content: Center(
                    child: Column(
                      children: [
                        if (codigoQR.isNotEmpty)
                          QrImageView(
                            data: codigoQR,
                            version: QrVersions.auto,
                            size: 120.0,
                            padding: const EdgeInsets.all(10),
                            backgroundColor: Colors.white,
                          )
                        else
                          Icon(FontAwesomeIcons.qrcode, size: 80, color: Colors.grey[300]),
                        
                        const SizedBox(height: 10),
                        Text(
                          codigoQR.isNotEmpty ? codigoQR : "No hay código QR asignado",
                          style: TextStyle(color: codigoQR.isNotEmpty ? const Color(0xFF3498DB) : Colors.grey[600], fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

                // Detalles
                _buildSection(
                  title: "Detalles del Equipo",
                  content: Column(
                    children: [
                      _DetailRow(icon: FontAwesomeIcons.barcode, label: "Serie", value: data['serie'] ?? attrs['serie'] ?? '--'),
                      _DetailRow(icon: FontAwesomeIcons.tag, label: "Marca", value: data['marca'] ?? attrs['marca'] ?? '--'),
                      _DetailRow(icon: FontAwesomeIcons.gears, label: "Disciplina", value: data['disciplinaDisplay'] ?? data['disciplina'] ?? '--'),
                      _DetailRow(icon: FontAwesomeIcons.shapes, label: "Categoría", value: productCategory),
                      _DetailRow(icon: FontAwesomeIcons.layerGroup, label: "Subcategoría", value: data['subcategoria'] ?? '--'),
                      _DetailRow(icon: FontAwesomeIcons.calendarDay, label: "Fecha de Compra", value: fechaCompra),
                    ],
                  ),
                ),

                // Ubicación
                _buildSection(
                  title: "Ubicación",
                  content: Column(
                    children: [
                      _DetailRow(icon: FontAwesomeIcons.building, label: "Bloque", value: ubicacion['bloque'] ?? '--'),
                      _DetailRow(icon: FontAwesomeIcons.layerGroup, label: "Piso", value: ubicacion['piso'] ?? data['piso'] ?? ubicacion['nivel'] ?? data['nivel'] ?? '--'),
                      _DetailRow(icon: FontAwesomeIcons.mapPin, label: "Área", value: ubicacion['area'] ?? '--'),
                    ],
                  ),
                ),

                StreamBuilder<SchemaSnapshot?>(
                  stream: disciplina.isNotEmpty ? schemaService.streamSchema(disciplina) : Stream.empty(),
                  builder: (context, schemaSnap) {
                    final schema = schemaSnap.data;
                    if (schema == null) {
                      return const SizedBox.shrink();
                    }
                    final dynamicRows = _buildDynamicDetails(schema.fields, data, attrs);
                    if (dynamicRows.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return _buildSection(
                      title: "Parámetros",
                      content: Column(children: dynamicRows),
                    );
                  },
                ),
                
                // Lista de Reportes
                _buildReportsList(productId),

                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
      // FAB para generar NUEVO reporte
      floatingActionButton: StreamBuilder<DocumentSnapshot>(
        stream: productDocRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) return Container();
          
          final data = snapshot.data!.data() as Map<String, dynamic>;
          
          return FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GenerarReporteScreen(
                    productId: productId,
                    productName: data['nombre'] ?? 'N/A',
                    productCategory: data['categoria'] ?? 'N/A',
                    initialStatus: data['estado'] ?? 'operativo',
                    productLocation: data['ubicacion'] ?? {},
                  ),
                ),
              );
            },
            backgroundColor: const Color(0xFF3498DB),
            child: const Icon(Icons.add, size: 32, color: Colors.white),
          );
        },
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildProductHeader(Map<String, dynamic> data, bool isOperativo, String imageUrl) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          width: double.infinity,
          height: 250,
          child: imageUrl.isNotEmpty
              ? Image.network( 
                  imageUrl, 
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) => Center(child: Icon(Icons.broken_image, size: 60, color: Colors.grey[400])),
                )
              : Center(child: Icon(Icons.image_not_supported, size: 60, color: Colors.grey[300])),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['nombre'] ?? 'Producto Desconocido', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                decoration: BoxDecoration(
                  color: isOperativo ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isOperativo ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.circleXmark, color: Colors.white, size: 14),
                    const SizedBox(width: 8),
                    Text(data['estado']?.toUpperCase() ?? 'DESCONOCIDO', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection({required String title, required Widget content}) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF444444))),
          const SizedBox(height: 15),
          content,
        ],
      ),
    );
  }
  
  Widget _buildReportsList(String productId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 15),
          const Text("Lista de Reportes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF444444))),
          const SizedBox(height: 10),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reportes')
                .where('productId', isEqualTo: productId)
                .orderBy('fecha', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2)));
              }
              if (snapshot.hasError) return Text('Error al cargar reportes: ${snapshot.error}');
              
              final reports = snapshot.data!.docs;
              
              if (reports.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('Este equipo no tiene reportes registrados.', textAlign: TextAlign.center),
                );
              }
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final reportDoc = reports[index]; // Documento completo
                  final reportData = reportDoc.data() as Map<String, dynamic>;
                  
                  // Pasamos el ID del documento para la navegación
                  return _ReportCard(
                    reporte: reportData,
                    reportId: reportDoc.id, 
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

List<Widget> _buildDynamicDetails(
  List<SchemaField> fields,
  Map<String, dynamic> data,
  Map<String, dynamic> attrs,
) {
  const excluded = <String>{
    'nombre',
    'estado',
    'piso',
    'bloque',
    'area',
    'disciplina',
    'categoria',
    'subcategoria',
    'descripcion',
    'fechaCompra',
    'updatedAt',
    'imagenUrl',
  };

  return fields
      .where((field) => !excluded.contains(field.key))
      .map((field) {
        final value = attrs[field.key] ?? data[field.key] ?? '--';
        return _DetailRow(icon: FontAwesomeIcons.list, label: field.displayName, value: value.toString());
      })
      .toList();
}

class _DetailRow extends StatelessWidget {
    final IconData icon;
    final String label;
    final String value;

    const _DetailRow({required this.icon, required this.label, required this.value, super.key});

    @override
    Widget build(BuildContext context) {
        return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
                children: [
                    SizedBox(
                        width: 30,
                        child: Icon(icon, size: 20, color: const Color(0xFF555555)),
                    ),
                    Text("$label: ", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
                    Expanded(
                        child: Text(value, style: const TextStyle(fontSize: 16, color: Color(0xFF666666))),
                    ),
                ],
            ),
        );
    }
}

// TARJETA CLIQUEABLE DEL REPORTE
class _ReportCard extends StatelessWidget {
    final Map<String, dynamic> reporte;
    final String reportId; // ID necesario para navegar

    const _ReportCard({required this.reporte, required this.reportId, super.key});

    @override
    Widget build(BuildContext context) {
        final String estadoDisplay = reporte['estado_nuevo'] ?? reporte['estado'] ?? 'Pendiente';
        final bool isCompleted = estadoDisplay.toLowerCase() == 'completado' || estadoDisplay.toLowerCase() == 'operativo';
        
        final Color badgeColor = isCompleted ? const Color(0xFFD4EDDA) : const Color(0xFFF8D7DA);
        final Color textColor = isCompleted ? const Color(0xFF155724) : const Color(0xFF721C24);
        
        final String fechaDisplay = reporte['fechaDisplay'] ?? DateFormat('dd/MM/yyyy').format((reporte['fecha'] as Timestamp?)?.toDate() ?? DateTime.now());

        // ENVOLVEMOS EN INKWELL O GESTURE DETECTOR PARA NAVEGAR
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () {
              // Navegar a la pantalla de Detalle de Reporte
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
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Reporte N° ${reporte['nro'] ?? '0000'}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3498DB))),
                      Text(fechaDisplay, style: const TextStyle(fontSize: 14, color: Color(0xFF777777))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("Encargado: ${reporte['encargado'] ?? 'N/A'}", style: const TextStyle(fontSize: 15, color: Color(0xFF555555))),
                  Text("Motivo: ${reporte['descripcion'] ?? reporte['motivo'] ?? 'Sin descripción.'}", style: const TextStyle(fontSize: 15, color: Color(0xFF555555))),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: badgeColor,
                      ),
                      child: Row( // Añadimos un icono pequeño
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            estadoDisplay,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
                          ),
                          const SizedBox(width: 5),
                          const Icon(Icons.chevron_right, size: 14, color: Colors.grey)
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    }
}
