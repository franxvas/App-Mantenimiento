import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:appmantflutter/services/pdf_service.dart';
import 'package:appmantflutter/services/usuarios_cache_service.dart';

class DetalleReporteScreen extends StatelessWidget {
  final String reportId;
  final String? productId;
  final Map<String, dynamic>? initialReportData;

  const DetalleReporteScreen({
    super.key,
    required this.reportId,
    this.productId,
    this.initialReportData,
  });

  @override
  Widget build(BuildContext context) {
    final reportDocRef = productId != null
        ? FirebaseFirestore.instance
            .collection('productos')
            .withConverter<Map<String, dynamic>>(
              fromFirestore: (snapshot, _) => snapshot.data() ?? {},
              toFirestore: (data, _) => data,
            )
            .doc(productId)
            .collection('reportes')
            .withConverter<Map<String, dynamic>>(
              fromFirestore: (snapshot, _) => snapshot.data() ?? {},
              toFirestore: (data, _) => data,
            )
            .doc(reportId)
        : FirebaseFirestore.instance
            .collection('reportes')
            .withConverter<Map<String, dynamic>>(
              fromFirestore: (snapshot, _) => snapshot.data() ?? {},
              toFirestore: (data, _) => data,
            )
            .doc(reportId);

    return FutureBuilder<void>(
      future: UsuariosCacheService.instance.preload(),
      builder: (context, cacheSnapshot) {
        if (cacheSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: reportDocRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) return Scaffold(appBar: AppBar(), body: Center(child: Text("Error: ${snapshot.error}")));
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Scaffold(appBar: AppBar(), body: const Center(child: Text("Reporte no encontrado.")));
            }

            final data = snapshot.data!.data() ?? <String, dynamic>{};
            final String estado = data['estadoOperativo'] ??
                data['estadoDetectado'] ??
                data['estado_nuevo'] ??
                data['estado'] ??
                'registrado';
            final bool isCompleted = estado.toLowerCase() == 'completado' || estado.toLowerCase() == 'operativo';

            final Timestamp? tsFecha = data['fechaInspeccion'] ?? data['fecha'];
            final String fechaDisplay = tsFecha != null
                ? DateFormat('dd/MM/yyyy - HH:mm').format(tsFecha.toDate())
                : '--/--/----';

            final String comentarios = data['comentarios'] ?? '';
            final bool haySolucion = comentarios.isNotEmpty;

            return Scaffold(
              backgroundColor: const Color(0xFFF0F2F5),
              appBar: AppBar(
                title: const Text("Detalle del Reporte"),
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
              ),

              body: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(data, estado, isCompleted, fechaDisplay),

                    _buildSection(
                      title: "Problema Reportado",
                      icon: FontAwesomeIcons.triangleExclamation,
                      content: Text(
                        data['descripcion'] ?? data['motivo'] ?? 'Sin descripción del problema.',
                        style: const TextStyle(fontSize: 15, color: Color(0xFF666666)),
                      ),
                    ),

                    _buildSection(
                      title: "Acciones Tomadas / Solución",
                      icon: FontAwesomeIcons.screwdriverWrench,
                      content: Text(
                        haySolucion ? comentarios : 'Pendiente de solución o acciones no registradas.',
                        style: TextStyle(
                          fontSize: 15,
                          color: haySolucion ? const Color(0xFF666666) : Colors.red[700],
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
      },
    );
  }

  
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
          Text(
            "Equipo: ${data['activo_nombre'] ?? data['activoNombre'] ?? data['activo'] ?? 'N/A'}",
            style: const TextStyle(fontSize: 16, color: Color(0xFF666666)),
          ),
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
                    Text(_formatEstadoLabel(estado), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildDetails(Map<String, dynamic> data) {
    final ubicacion = data['ubicacion'] ?? {};
    final fields = <_DetailField>[
      _DetailField(label: "Responsable", value: UsuariosCacheService.instance.resolveResponsableName(data)),
      _DetailField(label: "Tipo de Reporte", value: _formatDisplayValue(data['tipoReporte'] ?? data['tipo_reporte'])),
      _DetailField(label: "Disciplina", value: _formatDisplayValue(data['disciplina'])),
      _DetailField(label: "Categoría", value: _formatDisplayValue(data['categoria'])),
      _DetailField(label: "ID Sistema", value: data['productId']),
      _DetailField(label: "Bloque", value: _formatDisplayValue(ubicacion['bloque'])),
      _DetailField(label: "Nivel", value: _formatDisplayValue(ubicacion['nivel'] ?? ubicacion['piso'])),
      _DetailField(label: "Área", value: _formatDisplayValue(ubicacion['area'])),
      _DetailField(label: "Estado anterior", value: _formatDisplayValue(data['estadoAnterior'])),
      _DetailField(label: "Estado detectado", value: _formatDisplayValue(data['estadoDetectado'])),
      _DetailField(label: "Estado nuevo", value: _formatDisplayValue(data['estadoNuevo'] ?? data['estadoOperativo'] ?? data['estado'])),
      _DetailField(label: "Condición física", value: _formatDisplayValue(data['condicionFisica'])),
      _DetailField(label: "Tipo mantenimiento", value: _formatDisplayValue(data['tipoMantenimiento'])),
      _DetailField(label: "Nivel criticidad", value: _formatDisplayValue(data['nivelCriticidad'])),
      _DetailField(label: "Impacto falla", value: _formatDisplayValue(data['impactoFalla'])),
      _DetailField(label: "Riesgo normativo", value: _formatDisplayValue(data['riesgoNormativo'])),
      _DetailField(label: "Riesgo eléctrico", value: _formatDisplayValue(data['riesgoElectrico'])),
      _DetailField(label: "Acción recomendada", value: _formatDisplayValue(data['accionRecomendada'])),
      _DetailField(label: "Costo estimado", value: _formatNumber(data['costoEstimado'])),
      _DetailField(
        label: "Requiere reemplazo",
        value: data['requiereReemplazo'] == null ? null : (data['requiereReemplazo'] == true ? 'Sí' : 'No'),
      ),
    ];
    final visibleFields = fields.where((field) => field.value != null && field.value!.toString().trim().isNotEmpty).toList();

    return _buildSection(
      title: "Detalles del Reporte",
      icon: FontAwesomeIcons.circleInfo,
      content: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: visibleFields.map((field) => _InfoPill(label: field.label, value: field.value!)).toList(),
      ),
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is num) {
      if (value % 1 == 0) {
        return value.toInt().toString();
      }
      return value.toString();
    }
    final text = value.toString();
    return text.replaceAll(RegExp(r'\.0$'), '');
  }

  String? _formatDisplayValue(dynamic value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return _formatTitleCase(text);
  }

  String _formatTitleCase(String value) {
    if (value.contains('@') || value.contains('/')) {
      return value;
    }
    final normalized = value.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) {
      return value;
    }
    return normalized
        .split(' ')
        .map((word) {
          if (word.isEmpty) {
            return word;
          }
          final lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }
  
}

class _DetailField {
  final String label;
  final String? value;

  const _DetailField({required this.label, required this.value});
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;

  const _InfoPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Color(0xFF444444)),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
