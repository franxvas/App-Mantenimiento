import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:appmantflutter/usuarios/nuevo_usuario_screen.dart';
import 'package:appmantflutter/usuarios/detalle_usuario_screen.dart';

class ListaUsuariosScreen extends StatelessWidget {
  const ListaUsuariosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Personal", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2C3E50),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('usuarios')
            .withConverter<Map<String, dynamic>>(
              fromFirestore: (snapshot, _) => snapshot.data() ?? {},
              toFirestore: (data, _) => data,
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No hay usuarios registrados."));
          }

          // USAMOS GRIDVIEW EN LUGAR DE LISTVIEW
          return GridView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: docs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // 2 Columnas
              crossAxisSpacing: 15, // Espacio horizontal
              mainAxisSpacing: 15,  // Espacio vertical
              childAspectRatio: 0.75, // Relación de aspecto (Alto vs Ancho) para que quepan los datos
            ),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final userId = doc.id;
              
              return _UserGridCard(data: data, userId: userId);
            },
          );
        },
      ),
      // FAB para agregar usuario
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const NuevoUsuarioScreen()));
        },
        backgroundColor: const Color(0xFF3498DB),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// --- WIDGET DE LA TARJETA DE USUARIO ---
class _UserGridCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String userId;

  const _UserGridCard({required this.data, required this.userId});

  @override
  Widget build(BuildContext context) {
    final String nombre = data['nombre'] ?? 'Sin Nombre';
    final String cargo = data['cargo'] ?? 'N/A';
    final String area = data['area'] ?? 'General';
    final String rol = data['rol'] ?? 'Usuario';
    final String avatarUrl = data['avatarUrl'] ?? '';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          // Navegar al detalle
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetalleUsuarioScreen(userId: userId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. IMAGEN / AVATAR
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                  image: (avatarUrl.isNotEmpty) 
                      ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                      : null,
                ),
                child: avatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 40, color: Colors.grey)
                    : null,
              ),
              
              const SizedBox(height: 10),

              // 2. NOMBRE
              Text(
                nombre,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold, 
                  color: Color(0xFF2C3E50)
                ),
              ),

              const SizedBox(height: 6),

              // 3. CARGO (Texto azul)
              Text(
                cargo.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11, 
                  fontWeight: FontWeight.bold, 
                  color: Color(0xFF3498DB)
                ),
              ),

              const SizedBox(height: 8),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 8),

              // 4. AREA Y ROL
              _infoRow(Icons.apartment, area),
              const SizedBox(height: 4),
              _infoRow(Icons.shield_outlined, rol),
            ],
          ),
        ),
      ),
    );
  }

  // Helper pequeño para las filas de Area y Rol
  Widget _infoRow(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 12, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }
}
