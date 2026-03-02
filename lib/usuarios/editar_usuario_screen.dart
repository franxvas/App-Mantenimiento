import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:appmantflutter/services/auth_user_profile_service.dart';
import 'dart:io';

class EditarUsuarioScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const EditarUsuarioScreen({
    super.key,
    required this.userId,
    required this.userData,
  });

  @override
  State<EditarUsuarioScreen> createState() => _EditarUsuarioScreenState();
}

class _EditarUsuarioScreenState extends State<EditarUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  late final Future<bool> _isAdminFuture;

  late TextEditingController _nombreCtrl;
  late TextEditingController _dniCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _celularCtrl;
  late TextEditingController _emailCtrl;
  late final List<String> _cargoOptions;
  late String _cargoSeleccionado;
  late String _rolSeleccionado;

  File? _newAvatarFile;
  File? _newFirmaFile;
  String? _currentAvatarUrl;
  String? _currentFirmaUrl;

  @override
  void initState() {
    super.initState();
    _isAdminFuture = _isCurrentUserAdmin();
    _nombreCtrl = TextEditingController(text: widget.userData['nombre']);
    _dniCtrl = TextEditingController(text: widget.userData['dni']);
    _areaCtrl = TextEditingController(text: widget.userData['area']);
    _celularCtrl = TextEditingController(text: widget.userData['celular']);
    _emailCtrl = TextEditingController(text: widget.userData['email']);

    _cargoOptions = List<String>.from(AuthUserProfileService.cargoOptions);
    final cargoActual = (widget.userData['cargo'] ?? '').toString().trim();
    if (cargoActual.isNotEmpty && !_cargoOptions.contains(cargoActual)) {
      _cargoOptions.add(cargoActual);
    }
    _cargoSeleccionado = cargoActual.isNotEmpty
        ? cargoActual
        : AuthUserProfileService.defaultCargo;
    _rolSeleccionado = _sanitizeRole(widget.userData['rol']);

    _currentAvatarUrl = widget.userData['avatarUrl'];
    _currentFirmaUrl = widget.userData['firmaUrl'];
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _dniCtrl.dispose();
    _areaCtrl.dispose();
    _celularCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isAvatar) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        if (isAvatar) {
          _newAvatarFile = File(picked.path);
        } else {
          _newFirmaFile = File(picked.path);
        }
      });
    }
  }

  Future<String?> _uploadFileToSupabase(File file, String folder) async {
    try {
      final supabase = Supabase.instance.client;
      final fileExt = file.path.split('.').last;
      final fileName =
          'usuarios/$folder/${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage
          .from('AppMant')
          .upload(
            fileName,
            file,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final String publicUrl = supabase.storage
          .from('AppMant')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      print("Error subiendo $folder: $e");
      return null;
    }
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      String? finalAvatarUrl = _currentAvatarUrl;
      String? finalFirmaUrl = _currentFirmaUrl;

      if (_newAvatarFile != null) {
        final url = await _uploadFileToSupabase(_newAvatarFile!, 'avatars');
        if (url != null) finalAvatarUrl = url;
      }

      if (_newFirmaFile != null) {
        final url = await _uploadFileToSupabase(_newFirmaFile!, 'firmas');
        if (url != null) finalFirmaUrl = url;
      }

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.userId)
          .update({
            'nombre': _nombreCtrl.text.trim(),
            'dni': _dniCtrl.text.trim(),
            'cargo': _cargoSeleccionado,
            'area': _areaCtrl.text.trim(),
            'celular': _celularCtrl.text.trim(),
            'email': _emailCtrl.text.trim(),
            'rol': _rolSeleccionado,
            'avatarUrl': finalAvatarUrl,
            'firmaUrl': finalFirmaUrl,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Perfil actualizado correctamente")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al guardar: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Editar Perfil"),
        actions: [
          FutureBuilder<bool>(
            future: _isAdminFuture,
            builder: (context, snapshot) {
              if (snapshot.data != true) {
                return const SizedBox.shrink();
              }
              if (_isSaving) {
                return const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }
              return IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveUser,
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<bool>(
        future: _isAdminFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data != true) {
            return const Center(
              child: Text("Acceso restringido. Solo administradores."),
            );
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: () => _pickImage(true),
                    child: _buildAvatar(true),
                  ),
                ),
                const SizedBox(height: 20),

                _buildTextField(
                  "Nombre y apellido",
                  _nombreCtrl,
                  readOnly: _isSaving,
                  required: true,
                ),
                _buildTextField(
                  "DNI",
                  _dniCtrl,
                  isNumber: true,
                  readOnly: _isSaving,
                  exactLength: 8,
                  required: true,
                ),
                _buildDropdownField(
                  label: "Cargo",
                  value: _cargoSeleccionado,
                  items: _cargoOptions,
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() => _cargoSeleccionado = value);
                        },
                ),
                _buildDropdownField(
                  label: "Rol",
                  value: _rolSeleccionado,
                  items: const ['tecnico', 'admin'],
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() => _rolSeleccionado = value);
                        },
                ),
                _buildTextField(
                  "Área",
                  _areaCtrl,
                  readOnly: _isSaving,
                  required: false,
                ),
                _buildTextField(
                  "Celular",
                  _celularCtrl,
                  isNumber: true,
                  readOnly: _isSaving,
                  exactLength: 9,
                  required: false,
                ),
                _buildTextField(
                  "Correo",
                  _emailCtrl,
                  isEmail: true,
                  readOnly: true,
                  required: false,
                  borderColor: Colors.grey.shade300,
                ),

                const SizedBox(height: 20),

                const Text(
                  "Firma Digital",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _pickImage(false),
                  child: _buildFirma(),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatar(bool showCamera) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.grey[300],
          backgroundImage: _newAvatarFile != null
              ? FileImage(_newAvatarFile!) as ImageProvider
              : (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty)
              ? NetworkImage(_currentAvatarUrl!)
              : null,
          child:
              (_newAvatarFile == null &&
                  (_currentAvatarUrl == null || _currentAvatarUrl!.isEmpty))
              ? const Icon(Icons.person, size: 60, color: Colors.grey)
              : null,
        ),
        if (showCamera)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF3498DB),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFirma() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _newFirmaFile != null
          ? Image.file(_newFirmaFile!, fit: BoxFit.contain)
          : (_currentFirmaUrl != null && _currentFirmaUrl!.isNotEmpty)
          ? Image.network(_currentFirmaUrl!, fit: BoxFit.contain)
          : const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.draw, color: Colors.grey, size: 30),
                Text(
                  "Toca para subir imagen de firma",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl, {
    bool isNumber = false,
    bool isEmail = false,
    required bool readOnly,
    Color? borderColor,
    int? exactLength,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: ctrl,
        readOnly: readOnly,
        keyboardType: isNumber
            ? TextInputType.number
            : (isEmail ? TextInputType.emailAddress : TextInputType.text),
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderSide: BorderSide(color: borderColor ?? Colors.grey.shade300),
          ),
          filled: true,
          fillColor: readOnly ? Colors.grey[200] : Colors.white,
        ),
        validator: (value) {
          if (required && (value == null || value.isEmpty)) {
            return 'Campo requerido';
          }
          if (readOnly) {
            return null;
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
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: DropdownButtonFormField<String>(
        initialValue: items.contains(value) ? value : items.first,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          filled: true,
          fillColor: onChanged == null ? Colors.grey[200] : Colors.white,
        ),
        items: items
            .map(
              (item) =>
                  DropdownMenuItem<String>(value: item, child: Text(item)),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  String _sanitizeRole(dynamic rawRole) {
    final role = (rawRole ?? '').toString().trim().toLowerCase();
    if (role == 'admin') {
      return 'admin';
    }
    return 'tecnico';
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

  bool _isValidEmail(String value) {
    final regex = RegExp(r'^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$');
    return regex.hasMatch(value);
  }
}
