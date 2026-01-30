import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:appmantflutter/usuarios/editar_usuario_screen.dart';

class DetalleUsuarioScreen extends StatelessWidget {
  final String userId;

  const DetalleUsuarioScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final usersRef = FirebaseFirestore.instance
        .collection('usuarios')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Perfil de Usuario"),
        actions: [
          FutureBuilder<bool>(
            future: _isCurrentUserAdmin(),
            builder: (context, snapshot) {
              if (snapshot.data != true) {
                return const SizedBox.shrink();
              }
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(FontAwesomeIcons.trash, size: 18, color: Color(0xFFE74C3C)),
                    onPressed: () => _confirmDelete(context, usersRef),
                  ),
                  IconButton(
                    icon: const Icon(FontAwesomeIcons.pencil, size: 18, color: Colors.white),
                    onPressed: () async {
                      final doc = await usersRef.doc(userId).get();
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
                    },
                  ),
                ],
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

                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Column(
                    children: [
                      _DetailRow(icon: FontAwesomeIcons.building, label: "Área", value: user['area']),
                      _DetailRow(icon: FontAwesomeIcons.phone, label: "Celular", value: user['celular']),
                      _DetailRow(icon: FontAwesomeIcons.envelope, label: "Correo", value: user['email']),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

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

  Future<bool> _isCurrentUserAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }
    final email = user.email;
    if (email == null || email.isEmpty) {
      return false;
    }
    final snapshot = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return false;
    }
    return (snapshot.docs.first.data()['rol'] ?? '') == 'admin';
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CollectionReference<Map<String, dynamic>> usersRef,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar usuario"),
        content: const Text("¿Estás seguro de eliminar este usuario?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
    if (shouldDelete != true) {
      return;
    }
    await usersRef.doc(userId).delete();
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Usuario eliminado")),
      );
    }
  }
}

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
          Expanded(
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
