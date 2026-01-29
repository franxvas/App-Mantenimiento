import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:appmantflutter/services/parametros_dataset_service.dart';
import 'package:appmantflutter/services/parametros_schema_service.dart';
import 'package:appmantflutter/services/schema_service.dart';

class AgregarProductoScreen extends StatefulWidget {
  const AgregarProductoScreen({super.key});

  @override
  State<AgregarProductoScreen> createState() => _AgregarProductoScreenState();
}

class _AgregarProductoScreenState extends State<AgregarProductoScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isUploading = false;

  final _schemaService = SchemaService();
  final _parametrosSchemaService = ParametrosSchemaService();
  final _datasetService = ParametrosDatasetService();

  // Controladores de texto
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  // Ubicación
  final _bloqueCtrl = TextEditingController();
  final _nivelCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _tipoActivoCtrl = TextEditingController();
  final _frecuenciaMantenimientoCtrl = TextEditingController();
  final _costoReemplazoCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();
  final _nivelCriticidadCtrl = TextEditingController();
  final _impactoFallaCtrl = TextEditingController();
  final _riesgoNormativoCtrl = TextEditingController();

  final Map<String, TextEditingController> _dynamicControllers = {};

  // Valores por defecto / Dropdowns
  String _categoria = 'luminarias';
  String _disciplina = 'Electricas';
  String _subcategoria = 'luces_emergencia';
  String _estado = 'operativo';
  String _condicionFisica = 'buena';
  
  DateTime _fechaCompra = DateTime.now();
  File? _imageFile;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _bloqueCtrl.dispose();
    _nivelCtrl.dispose();
    _areaCtrl.dispose();
    _tipoActivoCtrl.dispose();
    _frecuenciaMantenimientoCtrl.dispose();
    _costoReemplazoCtrl.dispose();
    _observacionesCtrl.dispose();
    _nivelCriticidadCtrl.dispose();
    _impactoFallaCtrl.dispose();
    _riesgoNormativoCtrl.dispose();
    for (final controller in _dynamicControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _parametrosSchemaService.seedSchemasIfMissing();
  }

  // --- 1. SELECCIONAR IMAGEN ---
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  // --- 2. SUBIR A SUPABASE ---
  Future<String?> _uploadImageToSupabase() async {
    if (_imageFile == null) return null;

    final supabase = Supabase.instance.client;
    final fileExt = _imageFile!.path.split('.').last;
    // Usamos timestamp para nombre único
    final fileName = 'productos/new_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

    try {
      await supabase.storage.from('AppMant').upload(fileName, _imageFile!);
      final publicUrl = supabase.storage.from('AppMant').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      print("Error subiendo imagen: $e");
      return null;
    }
  }

  // --- 3. GUARDAR EN FIRESTORE ---
  Future<void> _guardarProducto() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isUploading = true);

    try {
      // A. Subir imagen
      final String? imageUrl = await _uploadImageToSupabase();

      // Generar el código QR de manera automática y atómica.
      final disciplinaKey = _disciplina.toLowerCase();
      final int activoCounter = await _getAndIncrementActivoCounter(disciplinaKey);
      final String codigoQr = _buildCodigoQr(
        counter: activoCounter,
        disciplinaKey: disciplinaKey,
        nombre: _nombreCtrl.text.trim(),
      );

      // B. Guardar documento
      final schema = await _schemaService.fetchSchema(_disciplina.toLowerCase());
      final attrs = _collectDynamicAttrs(schema?.fields ?? []);
      final topLevelValues = _extractTopLevel(attrs);
      final nivelValue = _nivelCtrl.text;

      final productRef = FirebaseFirestore.instance.collection('productos').doc();
      final productData = {
        'nombre': _nombreCtrl.text,
        'descripcion': _descripcionCtrl.text,
        'categoria': _categoria,
        'categoriaActivo': _categoria,
        'disciplina': disciplinaKey,
        'subcategoria': _subcategoria,
        'estado': _estado,
        'estadoOperativo': _estado,
        'fechaCompra': _fechaCompra, // Se guarda como Timestamp
        'fechaCreacion': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'nivel': nivelValue,
        'tipoActivo': _tipoActivoCtrl.text.trim(),
        'bloque': _bloqueCtrl.text.trim(),
        'espacio': _areaCtrl.text.trim(),
        'condicionFisica': _condicionFisica.toLowerCase(),
        'frecuenciaMantenimientoMeses': _parseDouble(_frecuenciaMantenimientoCtrl.text),
        'costoMantenimiento': 0.0,
        'costoReemplazo': _parseDouble(_costoReemplazoCtrl.text),
        'observaciones': _observacionesCtrl.text.trim(),
        'nivelCriticidad': _parseInt(_nivelCriticidadCtrl.text),
        'impactoFalla': _impactoFallaCtrl.text.trim(),
        'riesgoNormativo': _riesgoNormativoCtrl.text.trim(),
        ...topLevelValues,
        'codigoQR': codigoQr,
        // Mapa de ubicación
        'ubicacion': {
          'bloque': _bloqueCtrl.text,
          'nivel': nivelValue,
          'area': _areaCtrl.text,
        }
      };
      if (imageUrl != null && imageUrl.isNotEmpty) {
        productData['imagenUrl'] = imageUrl;
      }

      final columns = await _parametrosSchemaService.fetchColumns(_disciplina.toLowerCase(), 'base');
      await _datasetService.createProductoWithDataset(
        productRef: productRef,
        productData: productData,
        disciplina: _disciplina,
        columns: columns,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto agregado correctamente")));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // Selector de Fecha
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaCompra,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _fechaCompra) {
      setState(() => _fechaCompra = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Agregar Producto"), backgroundColor: const Color(0xFF2C3E50), iconTheme: const IconThemeData(color: Colors.white), titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20)),
      body: _isUploading 
        ? const Center(child: CircularProgressIndicator()) 
        : Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // FOTO
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _imageFile != null
                      ? Image.file(_imageFile!, fit: BoxFit.cover)
                      : const Center(
                          child: Text(
                            "Sin foto",
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              const Text("Datos Generales", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              _buildTextField(_nombreCtrl, "Nombre del Equipo"),
              
              // Dropdowns simples para categorías (puedes hacerlos más complejos si quieres)
              _buildDropdown("Disciplina", _disciplina, ['Electricas', 'Sanitarias', 'Estructuras', 'Arquitectura'], (v) => setState(() => _disciplina = v!)),
              _buildDropdown("Categoría", _categoria, ['luminarias', 'tableros', 'bombas', 'otros'], (v) => setState(() => _categoria = v!)),
              _buildDropdown("Estado Operativo", _estado, ['operativo', 'fuera de servicio', 'defectuoso'], (v) => setState(() => _estado = v!)),
              _buildTextField(null, "Subcategoría (Escribir manual)", isManual: true, onChanged: (val) => _subcategoria = val),
              
              const SizedBox(height: 20),
              const Text("Ubicación", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Row(children: [
                Expanded(child: _buildTextField(_bloqueCtrl, "Bloque")),
                const SizedBox(width: 10),
                Expanded(child: _buildTextField(_nivelCtrl, "Nivel")),
              ]),
              _buildTextField(_areaCtrl, "Espacio"),

              const SizedBox(height: 20),
              const Text("Parámetros Excel", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              _buildTextField(_tipoActivoCtrl, "Tipo de Activo"),
              _buildDropdown("Condición Física", _condicionFisica, ['buena', 'regular', 'mala'], (v) => setState(() => _condicionFisica = v!)),
              _buildTextField(_frecuenciaMantenimientoCtrl, "Frecuencia Mantenimiento (meses)", keyboardType: TextInputType.number),
              _buildTextField(_costoReemplazoCtrl, "Costo Reemplazo", keyboardType: TextInputType.number),
              _buildTextField(_observacionesCtrl, "Observaciones"),
              _buildTextField(_nivelCriticidadCtrl, "Nivel de Criticidad", keyboardType: TextInputType.number),
              _buildTextField(_impactoFallaCtrl, "Impacto de Falla"),
              _buildTextField(_riesgoNormativoCtrl, "Riesgo Normativo"),

              const SizedBox(height: 20),
              ListTile(
                title: const Text("Fecha de Compra"),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(_fechaCompra)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
              ),

              _buildTextField(_descripcionCtrl, "Descripción", maxLines: 3),

              StreamBuilder<SchemaSnapshot?>(
                stream: _schemaService.streamSchema(_disciplina),
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
                onPressed: _guardarProducto,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3498DB), padding: const EdgeInsets.symmetric(vertical: 15)),
                child: const Text("GUARDAR PRODUCTO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
    );
  }

  Widget _buildTextField(
    TextEditingController? ctrl,
    String label, {
    int maxLines = 1,
    bool isManual = false,
    Function(String)? onChanged,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        onChanged: onChanged,
        keyboardType: keyboardType,
        initialValue: isManual && ctrl == null ? _subcategoria : null, // Para el caso manual simple
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: (v) => (v == null || v.isEmpty) && !isManual ? 'Campo requerido' : null,
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: items.contains(value) ? value : items.first,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
        onChanged: onChanged,
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

      if (field.key == 'estado') {
        return _buildDropdown(
          field.displayName,
          _estado,
          ['operativo', 'fuera de servicio', 'defectuoso'],
          (value) => setState(() => _estado = value ?? _estado),
        );
      }

      final isNumber = field.type.toLowerCase() == 'number';
      return _buildTextField(
        controller,
        field.displayName,
        onChanged: (value) => controller.text = value,
        maxLines: 1,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
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

  Future<int> _getAndIncrementActivoCounter(String disciplinaKey) async {
    final counterRef = FirebaseFirestore.instance.collection('metadata').doc('counters');
    final counterKey = 'activo_$disciplinaKey';

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      final data = snapshot.data() ?? <String, dynamic>{};
      final currentNumber = (data[counterKey] as int?) ?? 0;
      final nextNumber = currentNumber + 1;
      transaction.set(counterRef, {counterKey: nextNumber}, SetOptions(merge: true));
      return nextNumber;
    });
  }

  String _buildCodigoQr({
    required int counter,
    required String disciplinaKey,
    required String nombre,
  }) {
    final disciplinaCode = _disciplinaCodeMap[disciplinaKey] ?? 'GEN';
    final firstWord = _extractFirstWord(nombre);
    final padded = counter.toString().padLeft(4, '0');
    return 'A-$padded-$disciplinaCode-$firstWord-$padded';
  }

  String _extractFirstWord(String nombre) {
    final normalized = _removeDiacritics(nombre.trim());
    final parts = normalized.split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return 'ACTIVO';
    }
    final sanitized = parts.first.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return sanitized.isEmpty ? 'ACTIVO' : sanitized;
  }

  String _removeDiacritics(String input) {
    const replacements = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'Á': 'A',
      'À': 'A',
      'Ä': 'A',
      'Â': 'A',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'É': 'E',
      'È': 'E',
      'Ë': 'E',
      'Ê': 'E',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'Í': 'I',
      'Ì': 'I',
      'Ï': 'I',
      'Î': 'I',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'Ó': 'O',
      'Ò': 'O',
      'Ö': 'O',
      'Ô': 'O',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'Ú': 'U',
      'Ù': 'U',
      'Ü': 'U',
      'Û': 'U',
      'ñ': 'n',
      'Ñ': 'N',
    };
    var output = input;
    replacements.forEach((key, value) {
      output = output.replaceAll(key, value);
    });
    return output;
  }

  static const Map<String, String> _disciplinaCodeMap = {
    'electricas': 'ELECT',
    'sanitarias': 'SAN',
    'arquitectura': 'ARQ',
    'estructuras': 'EST',
  };
}
