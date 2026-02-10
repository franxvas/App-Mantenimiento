import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; 
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Para generar el QR

// IMPORTACIONES DE TUS OTRAS PANTALLAS Y SERVICIOS
import 'package:appmantflutter/reportes/generar_reporte_screen.dart'; 
import 'package:appmantflutter/productos/editar_producto_screen.dart'; 
import 'package:appmantflutter/services/pdf_service.dart'; 
import 'package:appmantflutter/productos/reportes_del_producto_screen.dart';
import 'package:appmantflutter/reportes/detalle_reporte_screen.dart';
import 'package:appmantflutter/services/categorias_service.dart';
import 'package:appmantflutter/shared/text_formatters.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text("Detalle del Activo"),
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
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ficha técnica guardada correctamente.')),
                          );
                        }
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
                      ).then((value) {
                        if (value is String && value.trim().isNotEmpty && value != productId) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetalleProductoScreen(productId: value),
                            ),
                          );
                        }
                      });
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
          final String productCategory = data['categoria'] ?? 'N/A';
          final String disciplinaKey = (data['disciplina'] ?? '').toString().toLowerCase();
          final Map<String, dynamic> ubicacion = data['ubicacion'] ?? {};
          final Map<String, dynamic> attrs = data['attrs'] ?? {};
          final String imageUrl = data['imagenUrl'] ?? ''; 
          final String codigoQR = productId;
          final String estadoOperativo = (data['estado'] ?? 'operativo').toString().toLowerCase();

          final Timestamp? tsInstalacion = data['fechaInstalacion'];
          final String fechaInstalacion = tsInstalacion != null
              ? DateFormat('dd/MM/yyyy').format(tsInstalacion.toDate())
              : '--/--/----';

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen y Cabecera
                _buildProductHeader(data, estadoOperativo, imageUrl),

                // Descripción
                _buildSectionCard(
                  title: "Descripción",
                  content: Text(data['descripcion'] ?? 'Sin descripción.', style: const TextStyle(fontSize: 15, color: Color(0xFF666666))),
                ),

                // Detalles
                _buildSectionCard(
                  title: "Detalles del Equipo",
                  content: Column(
                    children: [
                      _DetailRow(
                        icon: FontAwesomeIcons.barcode,
                        label: "Serie",
                        value: _formatUpperFallback(data['serie'] ?? attrs['serie']),
                      ),
                      _DetailRow(
                        icon: FontAwesomeIcons.tag,
                        label: "Marca",
                        value: _formatUpperFallback(data['marca'] ?? attrs['marca']),
                      ),
                      _DetailRow(
                        icon: FontAwesomeIcons.gears,
                        label: "Disciplina",
                        value: _formatTitleFallback(data['disciplinaDisplay'] ?? data['disciplina']),
                      ),
                      _CategoriaDetailRow(
                        disciplinaKey: disciplinaKey,
                        categoriaValue: productCategory,
                      ),
                      _DetailRow(
                        icon: FontAwesomeIcons.layerGroup,
                        label: "Subcategoría",
                        value: _formatSubcategoriaFallback(data['subcategoria']),
                      ),
                      _DetailRow(
                        icon: FontAwesomeIcons.calendarDay,
                        label: "Fecha de Instalación",
                        value: fechaInstalacion,
                      ),
                    ],
                  ),
                ),

                // Ubicación
                _buildSectionCard(
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
                
                // Lista de Reportes
                _buildReportsList(
                  context: context,
                  productId: productId,
                  productName: productName,
                ),

                _buildQrSection(codigoQR),

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
            child: const Icon(Icons.add, size: 32, color: Colors.white),
          );
        },
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildProductHeader(Map<String, dynamic> data, String estadoOperativo, String imageUrl) {
    final estadoLabel = estadoOperativo.toUpperCase();
    final estadoColor = _estadoColor(estadoOperativo);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            height: 230,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(Icons.broken_image, size: 60, color: Colors.grey[400]),
                      ),
                    )
                  : const Center(
                      child: Text('Sin foto', style: TextStyle(color: Colors.grey)),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              data['nombre'] ?? 'Activo sin nombre',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
          Chip(
            label: Text(estadoLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: estadoColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget content}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
    return _buildSectionCard(
      title: "Lista de Reportes",
      content: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: productRef
            .collection('reportes')
            .withConverter<Map<String, dynamic>>(
              fromFirestore: (snapshot, _) => snapshot.data() ?? {},
              toFirestore: (data, _) => data,
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2)));
          }
          if (snapshot.hasError) return Text('Error al cargar reportes: ${snapshot.error}');

          final reports = snapshot.data?.docs ?? [];

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

          return Column(
            children: [
              ...visibleReports.map((doc) {
                final data = doc.data();
                return _ReportPill(
                  reportId: doc.id,
                  productId: productId,
                  tipoReporte: data['tipoReporte'] ?? data['tipo_reporte'] ?? 'General',
                  estadoOperativo: data['estadoNuevo'] ?? data['estado'] ?? '',
                  fecha: _resolveReportDate(data),
                );
              }),
              if (hasMore)
                Align(
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
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ReportPill extends StatelessWidget {
  final String reportId;
  final String productId;
  final String tipoReporte;
  final String estadoOperativo;
  final DateTime fecha;

  const _ReportPill({
    required this.reportId,
    required this.productId,
    required this.tipoReporte,
    required this.estadoOperativo,
    required this.fecha,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd/MM/yyyy').format(fecha);
    final estadoLabel = estadoOperativo.isEmpty ? 'N/A' : estadoOperativo.toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetalleReporteScreen(
                reportId: reportId,
                productId: productId,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _estadoColor(estadoOperativo.toLowerCase()),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatLabel(tipoReporte),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                    ),
                    const SizedBox(height: 4),
                    Text('Fecha: $dateLabel', style: const TextStyle(color: Color(0xFF666666))),
                  ],
                ),
              ),
              Text(
                estadoLabel,
                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF555555)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildQrSection(String codigoQR) {
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            const Text(
              "Código QR",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF444444)),
            ),
            const SizedBox(height: 16),
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
              style: TextStyle(
                color: codigoQR.isNotEmpty ? const Color(0xFF8B1E1E) : Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
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

Color _estadoColor(String estado) {
  switch (estado.toLowerCase()) {
    case 'operativo':
      return const Color(0xFF2ECC71);
    case 'defectuoso':
      return const Color(0xFFF39C12);
    case 'fuera_servicio':
    case 'fuera de servicio':
      return const Color(0xFFE74C3C);
    default:
      return const Color(0xFF95A5A6);
  }
}

String _formatLabel(String value) {
  final normalized = value.replaceAll('_', ' ');
  if (normalized.isEmpty) {
    return value;
  }
  return normalized
      .split(' ')
      .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String _formatUpperFallback(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return '--';
  return formatUpperCase(text);
}

String _formatTitleFallback(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return '--';
  return formatTitleCase(text);
}

String _formatSubcategoriaFallback(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return '--';
  return formatSubcategoriaDisplay(text);
}

class _CategoriaDetailRow extends StatelessWidget {
  final String disciplinaKey;
  final String categoriaValue;

  const _CategoriaDetailRow({
    required this.disciplinaKey,
    required this.categoriaValue,
  });

  @override
  Widget build(BuildContext context) {
    if (disciplinaKey.isEmpty) {
      return _DetailRow(
        icon: FontAwesomeIcons.shapes,
        label: "Categoría",
        value: _formatTitleFallback(categoriaValue),
      );
    }
    return FutureBuilder<List<CategoriaItem>>(
      future: CategoriasService.instance.fetchByDisciplina(disciplinaKey),
      builder: (context, snapshot) {
        final label =
            CategoriasService.instance.resolveLabel(disciplinaKey, categoriaValue) ?? categoriaValue;
        return _DetailRow(
          icon: FontAwesomeIcons.shapes,
          label: "Categoría",
          value: _formatTitleFallback(label),
        );
      },
    );
  }
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
