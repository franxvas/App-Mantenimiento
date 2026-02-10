import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:appmantflutter/reportes/generar_reporte_screen.dart'; // Tu formulario existente
import 'package:appmantflutter/scan/qr_scanner_screen.dart';

class SeleccionarProductoReporteScreen extends StatefulWidget {
  final String categoriaFilter;

  const SeleccionarProductoReporteScreen({super.key, required this.categoriaFilter});

  @override
  State<SeleccionarProductoReporteScreen> createState() => _SeleccionarProductoReporteScreenState();
}

class _SeleccionarProductoReporteScreenState extends State<SeleccionarProductoReporteScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Seleccionar Producto"),
        titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre, categoría o QR',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase().trim()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('productos')
                  .withConverter<Map<String, dynamic>>(
                    fromFirestore: (snapshot, _) => snapshot.data() ?? {},
                    toFirestore: (data, _) => data,
                  )
                  .where('categoria', isEqualTo: widget.categoriaFilter)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(child: Text("No hay productos en esta categoría."));
                }

                final filteredDocs = docs.where((doc) {
                  final data = doc.data();
                  final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                  final categoria = (data['categoria'] ?? '').toString().toLowerCase();
                  final codigoQr =
                      doc.id.toLowerCase();
                  return nombre.contains(_searchQuery) ||
                      categoria.contains(_searchQuery) ||
                      codigoQr.contains(_searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text("No hay productos que coincidan con la búsqueda."));
                }

                return ListView.separated(
                  itemCount: filteredDocs.length,
                  separatorBuilder: (_,__) => const Divider(),
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
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
                      subtitle: Text("Estado actual: ${estado.toUpperCase()}"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // NAVEGAR AL FORMULARIO DE REPORTE
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GenerarReporteScreen(
                              productId: productId,
                              productName: nombre,
                              productCategory: widget.categoriaFilter,
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const QRScannerScreen(goToReport: true),
            ),
          );
        },
        label: const Text('Escanear QR'),
        icon: const Icon(Icons.qr_code_scanner),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
