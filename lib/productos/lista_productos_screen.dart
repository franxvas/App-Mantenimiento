import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:appmantflutter/productos/detalle_producto_screen.dart';
import 'package:appmantflutter/productos/agregar_producto_screen.dart'; // Asegúrate de que este archivo exista

class ListaProductosScreen extends StatelessWidget {
  final String filterBy; // 'disciplina' o 'categoria'
  final String filterValue; // El valor del filtro (ej: 'luminarias', 'electricas')
  final String title; // El título para mostrar en la AppBar

  const ListaProductosScreen({
    super.key,
    required this.filterBy,
    required this.filterValue,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF2C3E50),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white, 
          fontSize: 20, 
          fontWeight: FontWeight.bold
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECCIÓN: FUERA DE SERVICIO ---
            const Padding(
              padding: EdgeInsets.only(top: 20, left: 15, bottom: 5),
              child: Text(
                "❌ FUERA DE SERVICIO", 
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
              ),
            ),
            
            _buildProductStream('fuera de servicio', context),
            
            // --- SECCIÓN: OPERATIVO ---
            const Padding(
              padding: EdgeInsets.only(top: 30, left: 15, bottom: 5),
              child: Text(
                "✅ OPERATIVO", 
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)
              ),
            ),
            
            _buildProductStream('operativo', context),
            
            const SizedBox(height: 80), // Espacio extra al final para que el FAB no tape contenido
          ],
        ),
      ),
      // --- BOTÓN FLOTANTE PARA AGREGAR PRODUCTO ---
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AgregarProductoScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFF3498DB),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  // Helper para construir el Stream de Firestore según el estado
  Widget _buildProductStream(String estado, BuildContext context) {
    // 1. Construir la consulta base
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('productos')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        );
    
    // 2. Aplicar el filtro dinámico (Disciplina o Categoría)
    if (filterBy == 'disciplina') {
      query = query.where('disciplina', isEqualTo: filterValue);
    } else if (filterBy == 'categoria') {
      query = query.where('categoria', isEqualTo: filterValue);
    }
    
    // 3. Aplicar el filtro de estado (operativo / fuera de servicio)
    query = query.where('estado', isEqualTo: estado);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
        }
        
        if (snapshot.hasError) {
          return Padding(padding: const EdgeInsets.all(15), child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Text(
              'No hay productos $estado en esta lista.',
              style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          );
        }

        // Renderizar la lista de tarjetas
        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data();
            return _ProductCard(
              id: doc.id,
              nombre: data['nombre'] ?? 'Sin nombre',
              estado: data['estado'] ?? 'desconocido',
              imagenUrl: data['imagenUrl'], // Pasamos la URL de la imagen
              onTap: () {
                // Navegar al detalle del producto
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetalleProductoScreen(productId: doc.id),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}

// --- WIDGET PRIVADO: TARJETA DE PRODUCTO CON FOTO ---
class _ProductCard extends StatelessWidget {
  final String id;
  final String nombre;
  final String estado;
  final String? imagenUrl; // Puede ser null si no tiene foto
  final VoidCallback onTap;

  const _ProductCard({
    required this.id,
    required this.nombre,
    required this.estado,
    this.imagenUrl,
    required this.onTap,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    final bool isOperativo = estado.toLowerCase() == 'operativo';
    final Color dotColor = isOperativo ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white,
        surfaceTintColor: Colors.white,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                // 1. IMAGEN DEL PRODUCTO (Miniatura)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[100],
                    child: imagenUrl != null && imagenUrl!.isNotEmpty
                        ? Image.network(
                            imagenUrl!,
                            fit: BoxFit.cover,
                            // Manejo de errores si la imagen no carga
                            errorBuilder: (context, error, stackTrace) => 
                                const Icon(Icons.broken_image, color: Colors.grey),
                            // Indicador de carga
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                            },
                          )
                        : const Icon(Icons.image, color: Colors.grey), // Icono por defecto
                  ),
                ),
                
                const SizedBox(width: 15),
                
                // 2. DATOS DEL PRODUCTO
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            estado.toUpperCase(),
                            style: TextStyle(color: dotColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // 3. FLECHA
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
