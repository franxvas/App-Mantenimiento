import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart'; // Importar Supabase

class EditarProductoScreen extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> initialData;

  const EditarProductoScreen({
    super.key,
    required this.productId,
    required this.initialData,
  });

  @override
  State<EditarProductoScreen> createState() => _EditarProductoScreenState();
}

class _EditarProductoScreenState extends State<EditarProductoScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  
  File? _imageFile; // Archivo local seleccionado
  String? _currentImageUrl; // URL de imagen actual en Firebase/Supabase

  @override
  void initState() {
    super.initState();
    // Precargar datos iniciales
    _nombreController.text = widget.initialData['nombre'] ?? '';
    _descripcionController.text = widget.initialData['descripcion'] ?? '';
    // Asumimos que la base de datos guarda la URL COMPLETA ahora
    _currentImageUrl = widget.initialData['imagenUrl']; 
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  // --- FUNCIÓN CLAVE: SELECCIONAR IMAGEN ---
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // --- FUNCIÓN CLAVE: SUBIR A SUPABASE STORAGE Y OBTENER URL ---
// En lib/productos/editar_producto_screen.dart

// --- FUNCIÓN CLAVE: SUBIR A SUPABASE STORAGE Y OBTENER URL ---
Future<String?> _uploadToSupabase() async {
  if (_imageFile == null) return _currentImageUrl; // No hay nuevo archivo, retorna URL actual

  final supabase = Supabase.instance.client;
  final fileExtension = _imageFile!.path.split('.').last;
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final fileName = 'productos/${widget.productId}-$timestamp.$fileExtension';  
  try {
    // 1. Subir el archivo (Este paso sí puede fallar y lo envolvemos en try/catch)
    await supabase.storage
        .from('AppMant') // Nombre del bucket (Debe existir en Supabase)
        .upload(
          fileName, // Usamos la ruta completa (productos/...)
          _imageFile!,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    
    // 2. Obtener la URL pública: La función getPublicUrl devuelve el string de la URL directamente.
    final String publicUrl = supabase.storage
        .from('AppMant')
        .getPublicUrl(fileName);

    return publicUrl; // Retornamos el string de la URL
  } catch (e) {
    // Si falla la subida o la obtención de la URL, el catch maneja el error
    print('Excepción durante la subida a Supabase: $e');
    return null; // Indicamos que falló
  }
}


  // --- FUNCIÓN CLAVE: GUARDAR CAMBIOS ---
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Guardando cambios...')),
    );
    
    // 1. Subir imagen a Supabase (solo si _imageFile no es null)
    String? newImageUrl = await _uploadToSupabase(); 

    if (newImageUrl == null && _imageFile != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fallo en la subida de imagen. Intente de nuevo.')),
        );
        return;
    }

    // 2. Actualizar el documento en Firestore
    await FirebaseFirestore.instance.collection('productos').doc(widget.productId).update({
      'nombre': _nombreController.text,
      'descripcion': _descripcionController.text,
      'imagenUrl': newImageUrl, // Guardamos la nueva URL (o la anterior si no se subió nada)
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto actualizado con éxito!')),
      );
      Navigator.pop(context); // Regresar a la vista de detalle
    }
  }

  @override
  Widget build(BuildContext context) {
    // URL/Ruta de la imagen a mostrar (nueva local o actual remota)
    final imageUrlToDisplay = _imageFile != null 
        ? _imageFile!.path 
        : _currentImageUrl; 
        
    final isNewLocalFile = _imageFile != null;


    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Producto'),
        backgroundColor: const Color(0xFF2C3E50),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Sección de Imagen
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade400)
                ),
                child: Center(
                  child: isNewLocalFile
                      ? Image.file(File(imageUrlToDisplay!), fit: BoxFit.cover) // Mostrar archivo local
                      : imageUrlToDisplay != null && imageUrlToDisplay!.isNotEmpty
                          ? Image.network( // Mostrar URL remota
                              imageUrlToDisplay!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(child: CircularProgressIndicator());
                              },
                            )
                          : const Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(child: Text(isNewLocalFile ? 'Nueva imagen seleccionada' : 'Toca para cambiar la imagen', style: const TextStyle(color: Color(0xFF3498DB)))),
            
            const SizedBox(height: 30),

            // Campos de Edición
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre del Producto'),
              validator: (v) => v!.isEmpty ? 'Ingrese un nombre' : null,
            ),
            
            TextFormField(
              controller: _descripcionController,
              decoration: const InputDecoration(labelText: 'Descripción'),
              maxLines: 3,
            ),
            
            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6EFD),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('GUARDAR CAMBIOS', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
