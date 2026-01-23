import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:appmantflutter/reportes/generar_reporte_screen.dart'; // Tu formulario existente

class SeleccionarProductoReporteScreen extends StatelessWidget {
  final String categoriaFilter;

  const SeleccionarProductoReporteScreen({super.key, required this.categoriaFilter});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Seleccionar Producto"),
        backgroundColor: const Color(0xFF2C3E50),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('productos')
            .withConverter<Map<String, dynamic>>(
              fromFirestore: (snapshot, _) => snapshot.data() ?? {},
              toFirestore: (data, _) => data,
            )
            .where('categoria', isEqualTo: categoriaFilter)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text("No hay productos en esta categoría."));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_,__) => const Divider(),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final productId = doc.id;
              final String nombre = data['nombre'] ?? 'Sin nombre';
              final String estado = data['estado'] ?? 'desconocido';
              final String imageUrl = data['imagenUrl'] ?? '';
              final Map<String, dynamic> ubicacionData = data['ubicacion'] ?? {};

              return ListTile(
                leading: imageUrl.isNotEmpty
                    ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover))
                    : const Icon(Icons.inventory_2, size: 40, color: Colors.grey),
                title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text("Estado actual: $estado"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // NAVEGAR AL FORMULARIO DE REPORTE
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GenerarReporteScreen(
                        productId: productId,
                        productName: nombre,
                        productCategory: categoriaFilter,
                        initialStatus: estado,
                        productLocation: ubicacionData, 
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
