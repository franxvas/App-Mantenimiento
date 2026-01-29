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
import 'package:appmantflutter/productos/reportes_del_producto_screen.dart';
import 'package:appmantflutter/reportes/reporte_card.dart';

class DetalleProductoScreen extends StatelessWidget {
  final String productId;

  const DetalleProductoScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    final productDocRef = FirebaseFirestore.instance
        .collection('productos')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        )
        .doc(productId);
    final schemaService = SchemaService();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text("Detalle del Producto", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2C3E50),
        iconTheme: const IconThemeData(color: Colors.white),
        // BOTONES EN LA BARRA SUPERIOR (PDF y EDITAR)
        actions: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: productDocRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return Container();
              if (!snapshot.hasData || !snapshot.data!.exists) return Container();
              
              final data = snapshot.data!.data() ?? <String, dynamic>{};
              
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
                        final reportesQuery = await productDocRef
                            .collection('reportes')
                            .withConverter<Map<String, dynamic>>(
                              fromFirestore: (snapshot, _) => snapshot.data() ?? {},
                              toFirestore: (data, _) => data,
                            )
                            .orderBy('fechaInspeccion', descending: true)
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
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: productDocRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Producto no encontrado."));
          }

          final data = snapshot.data!.data() ?? <String, dynamic>{};
          final String productName = data['nombre'] ?? 'N/A';
          final String initialStatus = data['estado'] ?? 'operativo';
          final String productCategory = data['categoria'] ?? 'N/A';
          final bool isOperativo = initialStatus.toLowerCase() == 'operativo';
          final Map<String, dynamic> ubicacion = data['ubicacion'] ?? {};
          final Map<String, dynamic> attrs = data['attrs'] ?? {};
          final String imageUrl = data['imagenUrl'] ?? ''; 
          final String codigoQR = (data['codigoQR'] ?? attrs['codigoQR'] ?? '').toString(); 
          final String disciplina = data['disciplina'] ?? '';

          final Timestamp? tsInstalacion = data['fechaInstalacion'];
          final String fechaInstalacion = tsInstalacion != null
              ? DateFormat('dd/MM/yyyy').format(tsInstalacion.toDate())
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
                      _DetailRow(
                        icon: FontAwesomeIcons.calendarDay,
                        label: "Fecha de Instalación",
                        value: fechaInstalacion,
                      ),
                    ],
                  ),
                ),

                // Ubicación
                _buildSection(
                  title: "Ubicación",
                  content: Column(
                    children: [
                      _DetailRow(icon: FontAwesomeIcons.building, label: "Bloque", value: ubicacion['bloque'] ?? '--'),
                      _DetailRow(
                        icon: FontAwesomeIcons.layerGroup,
                        label: "Nivel",
                        value: data['nivel'] ?? data['piso'] ?? ubicacion['nivel'] ?? ubicacion['piso'] ?? '--',
                      ),
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
                _buildReportsList(
                  context: context,
                  productId: productId,
                  productName: productName,
                ),

                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
      // FAB para generar NUEVO reporte
      floatingActionButton: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: productDocRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) return Container();
          
          final data = snapshot.data!.data() ?? <String, dynamic>{};
          
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
              : const Center(child: Text('Sin foto', style: TextStyle(color: Colors.grey))),
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
  
  Widget _buildReportsList({
    required BuildContext context,
    required String productId,
    required String productName,
  }) {
    final productRef = FirebaseFirestore.instance
        .collection('productos')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        )
        .doc(productId);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 15),
          const Text("Lista de Reportes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF444444))),
          const SizedBox(height: 10),

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: productRef
                .collection('reportes')
                .withConverter<Map<String, dynamic>>(
                  fromFirestore: (snapshot, _) => snapshot.data() ?? {},
                  toFirestore: (data, _) => data,
                )
                .orderBy('fechaInspeccion', descending: true)
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

              final sortedReports = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(reports)
                ..sort((a, b) {
                  final dateA = _resolveReportDate(a.data());
                  final dateB = _resolveReportDate(b.data());
                  return dateB.compareTo(dateA);
                });
              final visibleReports = sortedReports.take(4).toList();
              final hasMore = sortedReports.length > 4;

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visibleReports.length + (hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (hasMore && index == visibleReports.length) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReportesDelProductoScreen(
                                productId: productId,
                                nombreProducto: productName,
                              ),
                            ),
                          );
                        },
                        child: const Text('Ver todos'),
                      ),
                    );
                  }

                  final reportDoc = visibleReports[index];
                  final reportData = reportDoc.data();
                  return ReportCard(
                    reporte: reportData,
                    reportId: reportDoc.id,
                    productId: productId,
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

List<Widget> _buildDynamicDetails(
  List<SchemaField> fields,
  Map<String, dynamic> data,
  Map<String, dynamic> attrs,
) {
  const excluded = <String>{
    'idActivo',
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
