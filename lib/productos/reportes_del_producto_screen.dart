import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../reportes/reporte_card.dart';

class ReportesDelProductoScreen extends StatelessWidget {
  final String productId;
  final String nombreProducto;

  const ReportesDelProductoScreen({
    super.key,
    required this.productId,
    required this.nombreProducto,
  });

  @override
  Widget build(BuildContext context) {
    final productRef = FirebaseFirestore.instance
        .collection('productos')
        .doc(productId)
        .collection('reportes')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text('Reportes - $nombreProducto', style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2C3E50),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: productRef.orderBy('fechaInspeccion', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar reportes: ${snapshot.error}'));
          }

          final reports = snapshot.data?.docs ?? [];
          if (reports.isEmpty) {
            return const Center(child: Text('Este equipo no tiene reportes registrados.'));
          }

          final sortedReports = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(reports)
            ..sort((a, b) {
              final dateA = _resolveReportDate(a.data());
              final dateB = _resolveReportDate(b.data());
              return dateB.compareTo(dateA);
            });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedReports.length,
            itemBuilder: (context, index) {
              final reportDoc = sortedReports[index];
              return ReportCard(
                reporte: reportDoc.data(),
                reportId: reportDoc.id,
                productId: productId,
              );
            },
          );
        },
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
