import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:appmantflutter/services/parametros_dataset_service.dart';
import 'package:appmantflutter/services/parametros_schema_service.dart';
import 'package:appmantflutter/services/schema_service.dart';
import 'package:appmantflutter/services/activo_id_helper.dart';

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

  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _serieCtrl = TextEditingController();

  final _bloqueCtrl = TextEditingController();
  final _nivelCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _idActivoCtrl = TextEditingController();
  final _frecuenciaMantenimientoCtrl = TextEditingController();
  final _costoReemplazoCtrl = TextEditingController();
  final _vidaUtilEsperadaCtrl = TextEditingController();

  final Map<String, TextEditingController> _dynamicControllers = {};

  String _categoria = 'luminarias';
  String _disciplina = 'Electricas';
  String _subcategoria = 'luces_emergencia';
  String _estado = 'operativo';
  String _condicionFisica = 'buena';
  String _tipoMantenimiento = 'preventivo';
  String _nivelCriticidad = 'medio';
  String _impactoFalla = 'operacion';
  String _riesgoNormativo = 'cumple';
  bool _requiereReemplazo = false;
  
  DateTime _fechaInstalacion = DateTime.now();
  bool _fechaInstalacionCustom = false;
  File? _imageFile;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _marcaCtrl.dispose();
    _serieCtrl.dispose();
    _bloqueCtrl.dispose();
    _nivelCtrl.dispose();
    _areaCtrl.dispose();
    _idActivoCtrl.dispose();
    _frecuenciaMantenimientoCtrl.dispose();
    _costoReemplazoCtrl.dispose();
    _vidaUtilEsperadaCtrl.dispose();
    for (final controller in _dynamicControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _parametrosSchemaService.seedSchemasIfMissing();
    _updateIdActivoPreview();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<String?> _uploadImageToSupabase() async {
    if (_imageFile == null) return null;

    final supabase = Supabase.instance.client;
    final fileExt = _imageFile!.path.split('.').last;
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

  Future<void> _guardarProducto() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isUploading = true);

    try {
      final String? imageUrl = await _uploadImageToSupabase();

      final disciplinaKey = _disciplina.toLowerCase();
      final int activoCounter = await _getAndIncrementActivoCounter(disciplinaKey);
      final correlativo = ActivoIdHelper.formatCorrelativo(activoCounter);
      final String idActivo = ActivoIdHelper.buildId(
        disciplinaKey: disciplinaKey,
        nombre: _nombreCtrl.text.trim(),
        bloque: _bloqueCtrl.text.trim(),
        nivel: _nivelCtrl.text.trim(),
        correlativo: correlativo,
      );
      final String codigoQr = idActivo;

      final schema = await _schemaService.fetchSchema(_disciplina.toLowerCase());
      final attrs = _collectDynamicAttrs(schema?.fields ?? []);
      final topLevelValues = _extractTopLevel(attrs);
      final nivelValue = _nivelCtrl.text;

      final productRef = FirebaseFirestore.instance.collection('productos').doc();
      final productData = {
        'nombre': _nombreCtrl.text,
        'nombreProducto': _nombreCtrl.text,
        'descripcion': _descripcionCtrl.text,
        'categoria': _categoria,
        'categoriaActivo': _categoria,
        'disciplina': disciplinaKey,
        'subcategoria': _subcategoria,
        'estado': _estado,
        'estadoOperativo': _estado,
        'fechaInstalacion': _fechaInstalacionCustom ? _fechaInstalacion : FieldValue.serverTimestamp(),
        'fechaCreacion': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'nivel': nivelValue,
        'idActivo': idActivo,
        'bloque': _bloqueCtrl.text.trim(),
        'espacio': _areaCtrl.text.trim(),
        'frecuenciaMantenimientoMeses': _parseDouble(_frecuenciaMantenimientoCtrl.text),
        'costoMantenimiento': 0.0,
        'costoReemplazo': _parseDouble(_costoReemplazoCtrl.text),
        'vidaUtilEsperadaAnios': _parseDouble(_vidaUtilEsperadaCtrl.text),
        ...topLevelValues,
        'marca': _marcaCtrl.text.trim(),
        'serie': _serieCtrl.text.trim(),
        'codigoQR': codigoQr,
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

  void _updateIdActivoPreview() {
    final disciplinaKey = _disciplina.toLowerCase();
    final preview = ActivoIdHelper.buildPreview(
      disciplinaKey: disciplinaKey,
      nombre: _nombreCtrl.text.trim(),
      bloque: _bloqueCtrl.text.trim(),
      nivel: _nivelCtrl.text.trim(),
    );
    setState(() {
      _idActivoCtrl.text = preview;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Agregar Producto"),
        titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle,
      ),
      body: _isUploading 
        ? const Center(child: CircularProgressIndicator()) 
        : Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
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
              
              _buildDropdown(
                "Disciplina",
                _disciplina,
                ['Electricas', 'Sanitarias', 'Estructuras', 'Arquitectura', 'Mecanica', 'Mobiliarios'],
                (v) {
                  _disciplina = v!;
                  _updateIdActivoPreview();
                },
              ),
              _buildDropdown(
                "Categoría",
                _categoria,
                ['luminarias', 'tableros', 'bombas', 'sillas', 'mesas', 'estantes', 'otros'],
                (v) => setState(() => _categoria = v!),
              ),
              _buildTextField(
                null,
                "Subcategoría (Escribir manual)",
                isManual: true,
                onChanged: (val) => _subcategoria = val,
              ),
              _buildTextField(_marcaCtrl, "Marca"),
              _buildTextField(_serieCtrl, "Serie"),
              
              const SizedBox(height: 20),
              const Text("Ubicación", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Row(children: [
                Expanded(
                  child: _buildTextField(
                    _bloqueCtrl,
                    "Bloque",
                    onChanged: (_) => _updateIdActivoPreview(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(
                    _nivelCtrl,
                    "Nivel",
                    onChanged: (_) => _updateIdActivoPreview(),
                  ),
                ),
              ]),
              _buildTextField(_areaCtrl, "Espacio"),

              const SizedBox(height: 20),
              const Text("Datos del Activo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _idActivoCtrl,
                decoration: const InputDecoration(
                  labelText: 'ID Activo (autogenerado)',
                ),
                readOnly: true,
                enabled: false,
              ),
              _buildTextField(_frecuenciaMantenimientoCtrl, "Frecuencia Mantenimiento (meses)", keyboardType: TextInputType.number),
              _buildTextField(_costoReemplazoCtrl, "Costo Reemplazo", keyboardType: TextInputType.number),
              _buildTextField(_vidaUtilEsperadaCtrl, "Vida Útil Esperada (Años)", keyboardType: TextInputType.number),

              const SizedBox(height: 20),
              ListTile(
                title: const Text("Fecha de Instalación"),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(_fechaInstalacion)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectOptionalDate(
                  initialDate: _fechaInstalacion,
                  onSelected: (date) => setState(() {
                    _fechaInstalacion = date;
                    _fechaInstalacionCustom = true;
                  }),
                ),
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
                    children: _buildDynamicFields(schema.fields),
                  );
                },
              ),

              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _guardarProducto,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
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
        onChanged: (value) {
          if (onChanged != null) {
            onChanged(value);
          }
          if (ctrl == _nombreCtrl || ctrl == _bloqueCtrl || ctrl == _nivelCtrl) {
            _updateIdActivoPreview();
          }
        },
        keyboardType: keyboardType,
        initialValue: isManual && ctrl == null ? _subcategoria : null,
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
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(_formatLabel(e)))).toList(),
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
      'idActivo',
      'subcategoria',
      'descripcion',
      'fechaCompra',
      'estadoOperativo',
      'condicionFisica',
      'tipoMantenimiento',
      'frecuenciaMantenimientoMeses',
      'fechaUltimaInspeccion',
      'fechaProximoMantenimiento',
      'costoMantenimiento',
      'costoReemplazo',
      'observaciones',
      'nivelCriticidad',
      'impactoFalla',
      'riesgoNormativo',
      'fechaInstalacion',
      'vidaUtilEsperadaAnios',
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

  Future<void> _selectOptionalDate({
    required DateTime? initialDate,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  String _formatLabel(String value) {
    final normalized = value.replaceAll('_', ' ');
    if (normalized.isEmpty) {
      return value;
    }
    return normalized
        .split(' ')
        .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  Future<int> _getAndIncrementActivoCounter(String disciplinaKey) async {
    final counterRef = FirebaseFirestore.instance
        .collection('metadata')
        .doc('counters')
        .collection('activos')
        .doc(disciplinaKey);

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      final data = snapshot.data() ?? <String, dynamic>{};
      final currentNumber = (data['seq'] as int?) ?? 0;
      final nextNumber = currentNumber + 1;
      transaction.set(counterRef, {'seq': nextNumber}, SetOptions(merge: true));
      return nextNumber;
    });
  }

}
