import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NuevoUsuarioScreen extends StatefulWidget {
  const NuevoUsuarioScreen({super.key});

  @override
  State<NuevoUsuarioScreen> createState() => _NuevoUsuarioScreenState();
}

class _NuevoUsuarioScreenState extends State<NuevoUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nombreCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final _cargoCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _celularCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _rolSeleccionado = 'tecnico';

  Future<void> _guardarUsuario() async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseFirestore.instance.collection('usuarios').add({
          'nombre': _nombreCtrl.text.trim(),
          'dni': _dniCtrl.text.trim(),
          'cargo': _cargoCtrl.text.trim(),
          'area': _areaCtrl.text.trim(),
          'celular': _celularCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'rol': _rolSeleccionado,
          'fechaRegistro': FieldValue.serverTimestamp(),
          'avatarUrl': '',
          'firmaUrl': '',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Usuario guardado exitosamente')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _dniCtrl.dispose(); _cargoCtrl.dispose();
    _areaCtrl.dispose(); _celularCtrl.dispose(); _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Agregar Nuevo Usuario"),
      ),
      body: FutureBuilder<bool>(
        future: _isCurrentUserAdmin(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data != true) {
            return const Center(child: Text("Acceso restringido. Solo administradores."));
          }
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputLabel("Nombre y apellido*"),
                  _buildTextField(_nombreCtrl, "Ingrese nombre y apellido", required: true),

                  _buildInputLabel("DNI*"),
                  _buildTextField(_dniCtrl, "Ingrese DNI (8 dígitos)", required: true, isNumber: true, exactLength: 8),

                  _buildInputLabel("Cargo*"),
                  _buildTextField(_cargoCtrl, "Ej: Técnico Electricista", required: true),

                  _buildInputLabel("Área"),
                  _buildTextField(_areaCtrl, "Ej: Mantenimiento", required: false),

                  _buildInputLabel("Celular"),
                  _buildTextField(_celularCtrl, "Ingrese celular (9 dígitos)", isNumber: true, exactLength: 9),

                  _buildInputLabel("Correo"),
                  _buildTextField(_emailCtrl, "Ingrese correo", isEmail: true),

                  _buildInputLabel("Rol*"),
                  _buildRoleSelector(),

                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancelar"),
                      ),
                      const SizedBox(width: 15),
                      ElevatedButton(
                        onPressed: _guardarUsuario,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Guardar"),
                      ),
                    ],
                  )
                ],
              ),
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

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 15),
      child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF495057))),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    bool required = false,
    bool isNumber = false,
    bool isEmail = false,
    int? exactLength,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber
          ? TextInputType.number
          : (isEmail ? TextInputType.emailAddress : TextInputType.text),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCED4DA))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: (value) {
        if (required && (value == null || value.isEmpty)) {
          return 'Este campo es obligatorio';
        }
        if (value == null || value.isEmpty) {
          return null;
        }
        if (exactLength != null && value.trim().length != exactLength) {
          return 'Debe tener $exactLength dígitos';
        }
        if (isEmail && !_isValidEmail(value.trim())) {
          return 'Correo inválido';
        }
        return null;
      },
    );
  }

  Widget _buildRoleSelector() {
    final isAdmin = _rolSeleccionado == 'admin';
    final isTecnico = _rolSeleccionado == 'tecnico';

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => setState(() => _rolSeleccionado = 'admin'),
            style: OutlinedButton.styleFrom(
              backgroundColor: isAdmin ? const Color(0xFF3498DB) : Colors.white,
              foregroundColor: isAdmin ? Colors.white : const Color(0xFF3498DB),
              side: const BorderSide(color: Color(0xFF3498DB)),
            ),
            child: const Text("Administrador"),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () => setState(() => _rolSeleccionado = 'tecnico'),
            style: OutlinedButton.styleFrom(
              backgroundColor: isTecnico ? const Color(0xFF3498DB) : Colors.white,
              foregroundColor: isTecnico ? Colors.white : const Color(0xFF3498DB),
              side: const BorderSide(color: Color(0xFF3498DB)),
            ),
            child: const Text("Técnico"),
          ),
        ),
      ],
    );
  }

  bool _isValidEmail(String value) {
    final regex = RegExp(r'^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$');
    return regex.hasMatch(value);
  }
}
