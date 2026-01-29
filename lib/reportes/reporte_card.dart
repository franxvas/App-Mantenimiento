import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'detalle_reporte_screen.dart';

class ReportCard extends StatelessWidget {
  final Map<String, dynamic> reporte;
  final String reportId;
  final String productId;

  const ReportCard({
    super.key,
    required this.reporte,
    required this.reportId,
    required this.productId,
  });

  @override
  Widget build(BuildContext context) {
    final String estadoDisplay = reporte['estado_nuevo'] ?? reporte['estado'] ?? 'Pendiente';
    final bool isCompleted =
        estadoDisplay.toLowerCase() == 'completado' || estadoDisplay.toLowerCase() == 'operativo';

    final Color badgeColor = isCompleted ? const Color(0xFFD4EDDA) : const Color(0xFFF8D7DA);
    final Color textColor = isCompleted ? const Color(0xFF155724) : const Color(0xFF721C24);

    final String fechaDisplay = reporte['fechaDisplay'] ??
        DateFormat('dd/MM/yyyy')
            .format((reporte['fecha'] as Timestamp?)?.toDate() ?? DateTime.now());

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetalleReporteScreen(
                reportId: reportId,
                productId: productId,
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
                  Text(
                    "Reporte N° ${reporte['nro'] ?? '0000'}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3498DB),
                    ),
                  ),
                  Text(fechaDisplay, style: const TextStyle(fontSize: 14, color: Color(0xFF777777))),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Responsable: ${reporte['responsable'] ?? 'N/A'}",
                style: const TextStyle(fontSize: 15, color: Color(0xFF555555)),
              ),
              Text(
                "Motivo: ${reporte['descripcion'] ?? reporte['motivo'] ?? 'Sin descripción.'}",
                style: const TextStyle(fontSize: 15, color: Color(0xFF555555)),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: badgeColor,
                  ),
                  child: Row(
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
