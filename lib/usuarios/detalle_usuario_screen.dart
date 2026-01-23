import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Necesario para el ID actual
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:appmantflutter/usuarios/editar_usuario_screen.dart'; // Importar pantalla de edición

class DetalleUsuarioScreen extends StatelessWidget {
  final String userId;

  const DetalleUsuarioScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    // Obtener ID del usuario actual logueado
    final String currentAuthId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final usersRef = FirebaseFirestore.instance
        .collection('usuarios')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Perfil de Usuario", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2C3E50),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // --- BOTÓN ELIMINAR (Solo Admin debería ver esto, lógica futura) ---
          IconButton(icon: const Icon(FontAwesomeIcons.trash, size: 18, color: Color(0xFFE74C3C)), onPressed: () {
             // Lógica de eliminar (requiere validar rol de admin también)
          }),
          
          // --- BOTÓN EDITAR (Con Lógica de Permisos) ---
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            // Escuchamos el perfil del usuario LOGUEADO para saber su rol
            stream: usersRef.doc(currentAuthId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Container(); // Cargando o error
              
              final currentUserData = snapshot.data!.data();
              final String myRole = currentUserData?['rol'] ?? 'user';
              
              // CONDICIÓN DE PERMISO:
              // 1. Soy Admin
              // 2. O El perfil que estoy viendo es el mío
              // NOTA: Para que esto funcione perfecto, el documento en 'usuarios' debe tener el mismo ID que el UID de Auth.
              // Si no es así, tendrías que buscar el documento donde email == currentUser.email.
              
              // ASUMIENDO BÚSQUEDA POR EMAIL PARA SEGURIDAD ROBUSTA SI LOS IDS NO COINCIDEN
              final String myEmail = FirebaseAuth.instance.currentUser?.email ?? '';
              
              return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future: usersRef.where('email', isEqualTo: myEmail).get(),
                builder: (context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> myProfileSnap) {
                   bool canEdit = false;
                   
                   if (myProfileSnap.hasData && myProfileSnap.data!.docs.isNotEmpty) {
                      final myProfileDoc = myProfileSnap.data!.docs.first;
                      final myProfile = myProfileDoc.data();
                      final String myRoleReal = myProfile['rol'] ?? 'user';
                      final String myDocId = myProfileDoc.id;
                      
                      // Si soy admin O si este perfil es el mío
                      if (myRoleReal == 'admin' || userId == myDocId) {
                        canEdit = true;
                      }
                   }

                   if (canEdit) {
                     return IconButton(
                       icon: const Icon(FontAwesomeIcons.pencil, size: 18, color: Colors.white),
                       onPressed: () {
                         // Para editar, necesitamos los datos actuales. Los obtenemos del FutureBuilder principal del body
                         // Pero como no podemos acceder a ese snapshot desde aquí, hacemos una navegación simple
                         // y que la pantalla de editar cargue sus datos o se los pasamos si reestructuramos.
                         
                         // MEJOR ESTRATEGIA: Pasarle los datos desde el body (usando un FloatingActionButton o moviendo este botón)
                         // O simplemente leerlos de nuevo en la pantalla de editar.
                         
                         // Vamos a leerlos aquí rápido para pasarlos:
                         usersRef.doc(userId).get().then((doc) {
                           final userData = doc.data();
                           if (doc.exists && userData != null) {
                             Navigator.push(
                               context,
                               MaterialPageRoute(
                                 builder: (context) => EditarUsuarioScreen(
                                   userId: userId,
                                   userData: userData,
                                 ),
                               ),
                             );
                           }
                         });
                       },
                     );
                   } else {
                     return Container(); // No mostrar botón si no tiene permiso
                   }
                }
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: usersRef.doc(userId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Usuario no encontrado"));
          }

          final user = snapshot.data!.data() ?? <String, dynamic>{};

          return SingleChildScrollView(
            child: Column(
              children: [
                // CABECERA DE PERFIL
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: const Color(0xFFE9ECEF),
                        backgroundImage: (user['avatarUrl'] != null && user['avatarUrl'] != '') 
                            ? NetworkImage(user['avatarUrl']) 
                            : null,
                        child: (user['avatarUrl'] == null || user['avatarUrl'] == '') 
                            ? const Icon(Icons.person, size: 60, color: Colors.grey) 
                            : null,
                      ),
                      const SizedBox(height: 15),
                      Text(user['nombre'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF212529))),
                      Text(user['dni'] ?? '', style: const TextStyle(fontSize: 16, color: Color(0xFF6C757D))),
                      Text(user['cargo'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF495057))),
                      
                      const SizedBox(height: 5),
                      // Mostrar Rol (Badge)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (user['rol'] == 'admin') ? Colors.red[100] : Colors.blue[100],
                          borderRadius: BorderRadius.circular(4)
                        ),
                        child: Text(user['rol']?.toUpperCase() ?? 'USER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: (user['rol'] == 'admin') ? Colors.red : Colors.blue)),
                      )
                    ],
                  ),
                ),
                
                const SizedBox(height: 10),

                // SECCIÓN DE DETALLES
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Column(
                    children: [
                      _DetailRow(icon: FontAwesomeIcons.building, label: "Área", value: user['area']),
                      _DetailRow(icon: FontAwesomeIcons.phone, label: "Celular", value: user['celular']),
                      _DetailRow(icon: FontAwesomeIcons.envelope, label: "Email", value: user['email']),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // SECCIÓN DE FIRMA
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Firma", style: TextStyle(color: Color(0xFF6C757D), fontSize: 14)),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 100,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE9ECEF)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: (user['firmaUrl'] != null && user['firmaUrl'] != '')
                          ? Image.network(user['firmaUrl'], fit: BoxFit.contain)
                          : const Center(child: Text("No hay firma registrada", style: TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF6C757D)))),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Widget auxiliar para fila de detalle
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const _DetailRow({required this.icon, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE9ECEF))),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: const Color(0xFF555555)),
          const SizedBox(width: 20),
          Expanded( // Agregado Expanded para evitar overflow si el email es largo
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF6C757D))),
                Text(value ?? 'No especificado', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF212529))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
