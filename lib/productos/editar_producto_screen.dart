import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart'; // Importar Supabase
import 'package:appmantflutter/services/parametros_dataset_service.dart';
import 'package:appmantflutter/services/parametros_schema_service.dart';
import 'package:appmantflutter/services/schema_service.dart';

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
  final _schemaService = SchemaService();
  final _parametrosSchemaService = ParametrosSchemaService();
  final _datasetService = ParametrosDatasetService();
  
  // Controllers
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _nivelController = TextEditingController();
  final _bloqueController = TextEditingController();
  final _espacioController = TextEditingController();
  final _tipoActivoController = TextEditingController();
  final _frecuenciaMantenimientoController = TextEditingController();
  final _costoMantenimientoController = TextEditingController();
  final _costoReemplazoController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _nivelCriticidadController = TextEditingController();
  final _impactoFallaController = TextEditingController();
  final _riesgoNormativoController = TextEditingController();
  final Map<String, TextEditingController> _dynamicControllers = {};

  String _estado = 'operativo';
  String _condicionFisica = 'buena';
  static const List<String> _condicionOptions = ['buena', 'regular', 'mala'];
  
  File? _imageFile; // Archivo local seleccionado
  String? _currentImageUrl; // URL de imagen actual en Firebase/Supabase

  @override
  void initState() {
    super.initState();
    // Precargar datos iniciales
    _nombreController.text = widget.initialData['nombre'] ?? '';
    _descripcionController.text = widget.initialData['descripcion'] ?? '';
    _nivelController.text = _resolveNivel(widget.initialData);
    _bloqueController.text = widget.initialData['bloque']?.toString() ??
        widget.initialData['ubicacion']?['bloque']?.toString() ??
        '';
    _espacioController.text = widget.initialData['espacio']?.toString() ??
        widget.initialData['ubicacion']?['area']?.toString() ??
        '';
    final estadoInicial = widget.initialData['estado']?.toString().toLowerCase() ?? 'operativo';
    _estado = ['operativo', 'fuera de servicio', 'defectuoso'].contains(estadoInicial)
        ? estadoInicial
        : 'operativo';
    // Asumimos que la base de datos guarda la URL COMPLETA ahora
    _currentImageUrl = widget.initialData['imagenUrl']; 

    _parametrosSchemaService.seedSchemasIfMissing();

    final attrs = widget.initialData['attrs'] as Map<String, dynamic>? ?? {};
    for (final entry in attrs.entries) {
      _dynamicControllers[entry.key] = TextEditingController(text: entry.value?.toString() ?? '');
    }

    _tipoActivoController.text = widget.initialData['tipoActivo']?.toString() ?? '';
    final condicionInicial = widget.initialData['condicionFisica']?.toString().toLowerCase();
    if (condicionInicial != null && _condicionOptions.contains(condicionInicial)) {
      _condicionFisica = condicionInicial;
    }
    _frecuenciaMantenimientoController.text =
        widget.initialData['frecuenciaMantenimientoMeses']?.toString() ?? '';
    _costoMantenimientoController.text = widget.initialData['costoMantenimiento']?.toString() ?? '';
    _costoReemplazoController.text = widget.initialData['costoReemplazo']?.toString() ?? '';
    _observacionesController.text = widget.initialData['observaciones']?.toString() ?? '';
    _nivelCriticidadController.text = widget.initialData['nivelCriticidad']?.toString() ?? '';
    _impactoFallaController.text = widget.initialData['impactoFalla']?.toString() ?? '';
    _riesgoNormativoController.text = widget.initialData['riesgoNormativo']?.toString() ?? '';
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _nivelController.dispose();
    _bloqueController.dispose();
    _espacioController.dispose();
    _tipoActivoController.dispose();
    _frecuenciaMantenimientoController.dispose();
    _costoMantenimientoController.dispose();
    _costoReemplazoController.dispose();
    _observacionesController.dispose();
    _nivelCriticidadController.dispose();
    _impactoFallaController.dispose();
    _riesgoNormativoController.dispose();
    for (final controller in _dynamicControllers.values) {
      controller.dispose();
    }
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
    final disciplinaKey = _resolveDisciplinaKey(widget.initialData);
    final schema = disciplinaKey.isNotEmpty ? await _schemaService.fetchSchema(disciplinaKey) : null;
    final attrs = _collectDynamicAttrs(schema?.fields ?? []);
    final topLevelValues = _extractTopLevel(attrs);
    final productRef = FirebaseFirestore.instance.collection('productos').doc(widget.productId);
    final currentSnapshot = await productRef.get();
    final currentCostoMantenimiento = currentSnapshot.data()?['costoMantenimiento'];

    final productData = {
      'nombre': _nombreController.text,
      'nombreProducto': _nombreController.text,
      'descripcion': _descripcionController.text,
      'estado': _estado,
      'estadoOperativo': _estado,
      'nivel': _nivelController.text,
      'disciplina': disciplinaKey,
      'categoria': widget.initialData['categoria'] ?? widget.initialData['categoriaActivo'],
      'categoriaActivo': widget.initialData['categoria'] ?? widget.initialData['categoriaActivo'],
      'subcategoria': widget.initialData['subcategoria'],
      'tipoActivo': _tipoActivoController.text.trim(),
      'bloque': _bloqueController.text.trim(),
      'espacio': _espacioController.text.trim(),
      'condicionFisica': _condicionFisica.toLowerCase(),
      'frecuenciaMantenimientoMeses': _parseDouble(_frecuenciaMantenimientoController.text),
      'costoMantenimiento': currentCostoMantenimiento ?? _parseDouble(_costoMantenimientoController.text),
      'costoReemplazo': _parseDouble(_costoReemplazoController.text),
      'observaciones': _observacionesController.text.trim(),
      'nivelCriticidad': _parseInt(_nivelCriticidadController.text),
      'impactoFalla': _impactoFallaController.text.trim(),
      'riesgoNormativo': _riesgoNormativoController.text.trim(),
      ...topLevelValues,
      'ubicacion': {
        'nivel': _nivelController.text,
        'bloque': _bloqueController.text.trim(),
        'area': _espacioController.text.trim(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (newImageUrl != null && newImageUrl.isNotEmpty) {
      productData['imagenUrl'] = newImageUrl;
    }

    final columns = await _parametrosSchemaService.fetchColumns(disciplinaKey, 'base');
    await _datasetService.updateProductoWithDataset(
      productRef: productRef,
      productData: productData,
      disciplina: disciplinaKey,
      columns: columns,
    );

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
                          : const Text(
                              'Sin foto',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
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

            TextFormField(
              controller: _bloqueController,
              decoration: const InputDecoration(labelText: 'Bloque'),
            ),

            TextFormField(
              controller: _nivelController,
              decoration: const InputDecoration(labelText: 'Nivel'),
            ),

            TextFormField(
              controller: _espacioController,
              decoration: const InputDecoration(labelText: 'Espacio'),
            ),

            const SizedBox(height: 16),
            const Text("Parámetros Excel", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            TextFormField(
              controller: _tipoActivoController,
              decoration: const InputDecoration(labelText: 'Tipo de Activo'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _condicionFisica,
              decoration: const InputDecoration(labelText: 'Condición Física'),
              items: const [
                DropdownMenuItem(value: 'buena', child: Text('BUENA')),
                DropdownMenuItem(value: 'regular', child: Text('REGULAR')),
                DropdownMenuItem(value: 'mala', child: Text('MALA')),
              ],
              onChanged: (value) => setState(() => _condicionFisica = value ?? _condicionFisica),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _frecuenciaMantenimientoController,
              decoration: const InputDecoration(labelText: 'Frecuencia Mantenimiento (meses)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _costoMantenimientoController,
              decoration: const InputDecoration(
                labelText: 'Costo Mantenimiento',
                helperText: 'Se calcula automáticamente desde reportes.',
                suffixIcon: Icon(Icons.lock_outline, size: 16),
              ),
              keyboardType: TextInputType.number,
              readOnly: true,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _costoReemplazoController,
              decoration: const InputDecoration(labelText: 'Costo Reemplazo'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _observacionesController,
              decoration: const InputDecoration(labelText: 'Observaciones'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nivelCriticidadController,
              decoration: const InputDecoration(labelText: 'Nivel de Criticidad'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _impactoFallaController,
              decoration: const InputDecoration(labelText: 'Impacto de Falla'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _riesgoNormativoController,
              decoration: const InputDecoration(labelText: 'Riesgo Normativo'),
            ),

            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: DropdownButtonFormField<String>(
                value: _estado,
                decoration: const InputDecoration(labelText: 'Estado'),
                items: const [
                  DropdownMenuItem(value: 'operativo', child: Text('OPERATIVO')),
                  DropdownMenuItem(value: 'fuera de servicio', child: Text('FUERA DE SERVICIO')),
                  DropdownMenuItem(value: 'defectuoso', child: Text('DEFECTUOSO')),
                ],
                onChanged: (value) => setState(() => _estado = value ?? _estado),
              ),
            ),

            StreamBuilder<SchemaSnapshot?>(
              stream: _schemaService.streamSchema(widget.initialData['disciplina'] ?? ''),
              builder: (context, snapshot) {
                final schema = snapshot.data;
                if (schema == null) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Text("Campos de Parámetros", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 10),
                    ..._buildDynamicFields(schema.fields),
                  ],
                );
              },
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

  List<Widget> _buildDynamicFields(List<SchemaField> fields) {
    final excluded = <String>{
      'id',
      'idActivo',
      'nombre',
      'estado',
      'piso',
      'nivel',
      'bloque',
      'area',
      'espacio',
      'disciplina',
      'categoria',
      'categoriaActivo',
      'tipoActivo',
      'subcategoria',
      'descripcion',
      'fechaCompra',
      'estadoOperativo',
      'condicionFisica',
      'frecuenciaMantenimientoMeses',
      'costoMantenimiento',
      'costoReemplazo',
      'observaciones',
      'nivelCriticidad',
      'impactoFalla',
      'riesgoNormativo',
      'updatedAt',
      'imagenUrl',
    };

    return fields.where((field) => !excluded.contains(field.key)).map((field) {
      final controller = _dynamicControllers.putIfAbsent(
        field.key,
        () => TextEditingController(),
      );
      final isNumber = field.type.toLowerCase() == 'number';
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(labelText: field.displayName),
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        ),
      );
    }).toList();
  }

  Map<String, dynamic> _collectDynamicAttrs(List<SchemaField> fields) {
    final attrs = <String, dynamic>{};
    for (final field in fields) {
      final controller = _dynamicControllers[field.key];
      if (controller == null) {
        continue;
      }
      final value = controller.text.trim();
      if (value.isEmpty) {
        continue;
      }
      attrs[field.key] = value;
    }
    return attrs;
  }

  int? _parseInt(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return int.tryParse(trimmed);
  }

  double? _parseDouble(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return double.tryParse(trimmed.replaceAll(',', '.'));
  }

  String _resolveNivel(Map<String, dynamic> data) {
    final ubicacion = data['ubicacion'] as Map<String, dynamic>? ?? {};
    final value = data['nivel'] ?? data['piso'] ?? ubicacion['nivel'] ?? ubicacion['piso'] ?? '';
    return value.toString();
  }

  String _resolveDisciplinaKey(Map<String, dynamic> data) {
    final disciplina = data['disciplina']?.toString();
    if (disciplina != null && disciplina.isNotEmpty) {
      return disciplina.toLowerCase();
    }
    final attrs = data['attrs'] as Map<String, dynamic>? ?? {};
    final fallback = data['disciplinaKey'] ?? attrs['disciplinaKey'] ?? attrs['disciplina'];
    return fallback?.toString().toLowerCase() ?? '';
  }

  Map<String, dynamic> _extractTopLevel(Map<String, dynamic> attrs) {
    const keys = ['marca', 'serie', 'codigoQR'];
    final result = <String, dynamic>{};
    for (final key in keys) {
      if (attrs.containsKey(key)) {
        result[key] = attrs[key];
      }
    }
    return result;
  }
}
