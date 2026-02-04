import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:appmantflutter/services/parametros_dataset_service.dart';
import 'package:appmantflutter/services/parametros_schema_service.dart';
import 'package:appmantflutter/services/schema_service.dart';
import 'package:appmantflutter/services/activo_id_helper.dart';

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
  bool _autoGenerarId = true;
  bool _isCheckingId = false;
  String? _idActivoError;
  Timer? _idCheckDebounce;
  String? _lastCheckedId;
  bool? _lastCheckedUnique;
  
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _marcaController = TextEditingController();
  final _serieController = TextEditingController();
  final _subcategoriaController = TextEditingController();
  final _nivelController = TextEditingController();
  final _bloqueController = TextEditingController();
  final _espacioController = TextEditingController();
  final _idActivoController = TextEditingController();
  String _idActivoCorrelativo = '000';
  final _frecuenciaMantenimientoController = TextEditingController();
  final _costoMantenimientoController = TextEditingController();
  final _costoReemplazoController = TextEditingController();
  final _vidaUtilEsperadaController = TextEditingController();
  final _tipoMobiliarioController = TextEditingController();
  final _materialPrincipalController = TextEditingController();
  final _usoIntensivoController = TextEditingController();
  final _movilidadController = TextEditingController();
  final _fabricanteController = TextEditingController();
  final _modeloController = TextEditingController();
  final _proveedorController = TextEditingController();
  final _observacionesController = TextEditingController();
  final Map<String, TextEditingController> _dynamicControllers = {};

  String _estado = 'operativo';
  static const List<String> _estadoOptions = ['operativo', 'defectuoso', 'fuera_servicio'];
  
  DateTime? _fechaInstalacion;
  DateTime? _fechaAdquisicion;
  late final String _disciplinaKey;

  File? _imageFile;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _nombreController.text = widget.initialData['nombre'] ?? '';
    _descripcionController.text = widget.initialData['descripcion'] ?? '';
    _marcaController.text = widget.initialData['marca']?.toString() ??
        (widget.initialData['attrs']?['marca']?.toString() ?? '');
    _serieController.text = widget.initialData['serie']?.toString() ??
        (widget.initialData['attrs']?['serie']?.toString() ?? '');
    _subcategoriaController.text = widget.initialData['subcategoria']?.toString() ?? '';
    _nivelController.text = _resolveNivel(widget.initialData);
    _bloqueController.text = widget.initialData['bloque']?.toString() ??
        widget.initialData['ubicacion']?['bloque']?.toString() ??
        '';
    _espacioController.text = widget.initialData['espacio']?.toString() ??
        widget.initialData['ubicacion']?['area']?.toString() ??
        '';
    final estadoInicial = widget.initialData['estadoOperativo']?.toString().toLowerCase() ??
        widget.initialData['estado']?.toString().toLowerCase() ??
        'operativo';
    _estado = _estadoOptions.contains(estadoInicial) ? estadoInicial : 'operativo';
    _currentImageUrl = widget.initialData['imagenUrl']; 

    _parametrosSchemaService.seedSchemasIfMissing();
    _disciplinaKey = _resolveDisciplinaKey(widget.initialData);

    final attrs = widget.initialData['attrs'] as Map<String, dynamic>? ?? {};
    for (final entry in attrs.entries) {
      _dynamicControllers[entry.key] = TextEditingController(text: entry.value?.toString() ?? '');
    }

    _idActivoController.text = widget.initialData['idActivo']?.toString() ?? '';
    _idActivoCorrelativo =
        ActivoIdHelper.extractCorrelativo(_idActivoController.text) ?? _idActivoCorrelativo;
    _frecuenciaMantenimientoController.text =
        widget.initialData['frecuenciaMantenimientoMeses']?.toString() ?? '';
    _costoMantenimientoController.text = widget.initialData['costoMantenimiento']?.toString() ?? '';
    _costoReemplazoController.text = widget.initialData['costoReemplazo']?.toString() ?? '';
    _vidaUtilEsperadaController.text = widget.initialData['vidaUtilEsperadaAnios']?.toString() ?? '';
    _fechaInstalacion = _resolveDate(widget.initialData['fechaInstalacion']);
    _tipoMobiliarioController.text = widget.initialData['tipoMobiliario']?.toString() ?? '';
    _materialPrincipalController.text = widget.initialData['materialPrincipal']?.toString() ?? '';
    _usoIntensivoController.text = widget.initialData['usoIntensivo']?.toString() ?? '';
    _movilidadController.text = widget.initialData['movilidad']?.toString() ?? '';
    _fabricanteController.text = widget.initialData['fabricante']?.toString() ?? '';
    _modeloController.text = widget.initialData['modelo']?.toString() ?? '';
    _proveedorController.text = widget.initialData['proveedor']?.toString() ?? '';
    _observacionesController.text = widget.initialData['observaciones']?.toString() ?? '';
    _fechaAdquisicion = _resolveDate(widget.initialData['fechaAdquisicion']);
    _updateIdActivoPreview();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _marcaController.dispose();
    _serieController.dispose();
    _subcategoriaController.dispose();
    _nivelController.dispose();
    _bloqueController.dispose();
    _espacioController.dispose();
    _idActivoController.dispose();
    _frecuenciaMantenimientoController.dispose();
    _costoMantenimientoController.dispose();
    _costoReemplazoController.dispose();
    _vidaUtilEsperadaController.dispose();
    _tipoMobiliarioController.dispose();
    _materialPrincipalController.dispose();
    _usoIntensivoController.dispose();
    _movilidadController.dispose();
    _fabricanteController.dispose();
    _modeloController.dispose();
    _proveedorController.dispose();
    _observacionesController.dispose();
    _idCheckDebounce?.cancel();
    for (final controller in _dynamicControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      if (!mounted) return;
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }


Future<String?> _uploadToSupabase() async {
  if (_imageFile == null) return _currentImageUrl;

  final supabase = Supabase.instance.client;
  final fileExtension = _imageFile!.path.split('.').last;
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final fileName = 'productos/${widget.productId}-$timestamp.$fileExtension';  
  try {
    await supabase.storage
        .from('AppMant')
        .upload(
          fileName,
          _imageFile!,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    
    final String publicUrl = supabase.storage
        .from('AppMant')
        .getPublicUrl(fileName);

    return publicUrl;
  } catch (e) {
    print('Excepción durante la subida a Supabase: $e');
    return null;
  }
}


  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Guardando cambios...')),
    );
    
    String? newImageUrl = await _uploadToSupabase(); 

    if (newImageUrl == null && _imageFile != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fallo en la subida de imagen. Intente de nuevo.')),
        );
        return;
    }

    final disciplinaKey = _disciplinaKey;
    final schema = disciplinaKey.isNotEmpty ? await _schemaService.fetchSchema(disciplinaKey) : null;
    final attrs = _collectDynamicAttrs(schema?.fields ?? []);
    final topLevelValues = _extractTopLevel(attrs);
    final productRef = FirebaseFirestore.instance.collection('productos').doc(widget.productId);
    final currentSnapshot = await productRef.get();
    final currentData = currentSnapshot.data() ?? <String, dynamic>{};
    final currentCostoMantenimiento = currentData['costoMantenimiento'];
    final currentEstadoOperativo = currentData['estadoOperativo'] ?? currentData['estado'] ?? _estado;

    String idActivo;
    if (_autoGenerarId) {
      idActivo = ActivoIdHelper.buildId(
        disciplinaKey: disciplinaKey,
        nombre: _nombreController.text.trim(),
        bloque: _bloqueController.text.trim(),
        nivel: _nivelController.text.trim(),
        correlativo: _idActivoCorrelativo,
      );
      final unique = await _checkIdActivoUnique(idActivo);
      if (!unique) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ese ID ya existe, usa otro.')),
          );
        }
        return;
      }
    } else {
      idActivo = _idActivoController.text.trim();
      final unique = await _checkIdActivoUnique(idActivo);
      if (!unique) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ese ID ya existe, usa otro.')),
          );
        }
        return;
      }
    }
    final productData = {
      'nombre': _nombreController.text,
      'nombreProducto': _nombreController.text,
      'descripcion': _descripcionController.text,
      'estado': currentEstadoOperativo,
      'estadoOperativo': currentEstadoOperativo,
      'nivel': _nivelController.text,
      'disciplina': disciplinaKey,
      'categoria': widget.initialData['categoria'] ?? widget.initialData['categoriaActivo'],
      'categoriaActivo': widget.initialData['categoria'] ?? widget.initialData['categoriaActivo'],
      'subcategoria': _subcategoriaController.text.trim().isEmpty ? null : _subcategoriaController.text.trim(),
      'idActivo': idActivo,
      'bloque': _bloqueController.text.trim(),
      'espacio': _espacioController.text.trim(),
      'frecuenciaMantenimientoMeses': _parseDouble(_frecuenciaMantenimientoController.text),
      'costoMantenimiento': currentCostoMantenimiento ?? _parseDouble(_costoMantenimientoController.text),
      'costoReemplazo': _parseDouble(_costoReemplazoController.text),
      'fechaInstalacion': _fechaInstalacion,
      'vidaUtilEsperadaAnios': _parseDouble(_vidaUtilEsperadaController.text),
      'codigoQR': idActivo,
      ...topLevelValues,
      'marca': _marcaController.text.trim(),
      'serie': _serieController.text.trim(),
      'ubicacion': {
        'nivel': _nivelController.text,
        'bloque': _bloqueController.text.trim(),
        'area': _espacioController.text.trim(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (_isMobiliarios) {
      productData.addAll({
        'tipoMobiliario': _tipoMobiliarioController.text.trim(),
        'materialPrincipal': _materialPrincipalController.text.trim(),
        'usoIntensivo': _usoIntensivoController.text.trim(),
        'movilidad': _movilidadController.text.trim(),
        'fabricante': _fabricanteController.text.trim(),
        'modelo': _modeloController.text.trim(),
        'fechaAdquisicion': _fechaAdquisicion,
        'proveedor': _proveedorController.text.trim(),
        'observaciones': _observacionesController.text.trim(),
      });
    }
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
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrlToDisplay = _imageFile != null 
        ? _imageFile!.path 
        : _currentImageUrl; 
        
    final isNewLocalFile = _imageFile != null;


    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Producto'),
      ),
      body: Form(
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
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade400)
                ),
                child: Center(
                  child: isNewLocalFile
                      ? Image.file(File(imageUrlToDisplay!), fit: BoxFit.cover)
                      : imageUrlToDisplay != null && imageUrlToDisplay!.isNotEmpty
                          ? Image.network(
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
            Center(child: Text(isNewLocalFile ? 'Nueva imagen seleccionada' : 'Toca para cambiar la imagen', style: TextStyle(color: Theme.of(context).colorScheme.primary))),
            
            const SizedBox(height: 30),

            const Text("Datos Generales", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _nombreController,
              label: 'Nombre del Equipo',
              onChanged: (_) => _updateIdActivoPreview(),
              validator: (v) => v!.isEmpty ? 'Ingrese un nombre' : null,
            ),
            _buildTextField(
              controller: _descripcionController,
              label: 'Descripción',
              maxLines: 3,
            ),
            _buildTextField(
              controller: _marcaController,
              label: 'Marca',
            ),
            _buildTextField(
              controller: _serieController,
              label: 'Serie',
              hintText: _serieHint(),
            ),
            _buildTextField(
              controller: _subcategoriaController,
              label: 'Subcategoría',
              hintText: _subcategoriaHint(),
            ),

            const SizedBox(height: 20),
            const Text("Ubicación", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _bloqueController,
                    label: 'Bloque',
                    onChanged: (_) => _updateIdActivoPreview(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(
                    controller: _nivelController,
                    label: 'Nivel',
                    onChanged: (_) => _updateIdActivoPreview(),
                  ),
                ),
              ],
            ),
            _buildTextField(
              controller: _espacioController,
              label: 'Espacio',
            ),

            const SizedBox(height: 16),
            const Text("Datos del Activo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            CheckboxListTile(
              value: _autoGenerarId,
              onChanged: (value) {
                setState(() {
                  _autoGenerarId = value ?? true;
                  _idActivoError = null;
                  _lastCheckedId = null;
                  _lastCheckedUnique = null;
                  if (_autoGenerarId) {
                    _updateIdActivoPreview();
                  }
                });
              },
              title: const Text('Autogenerar ID'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            TextFormField(
              controller: _idActivoController,
              decoration: InputDecoration(
                labelText: _autoGenerarId ? 'ID Activo (autogenerado)' : 'ID Activo',
                border: const OutlineInputBorder(),
                errorText: _idActivoError,
                suffixIcon: _isCheckingId
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              readOnly: _autoGenerarId,
              enabled: true,
              onChanged: _autoGenerarId
                  ? null
                  : (value) {
                      setState(() => _idActivoError = null);
                      _scheduleIdActivoCheck(value);
                    },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _frecuenciaMantenimientoController,
              label: 'Frecuencia Mantenimiento (meses)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _costoMantenimientoController,
              label: 'Costo Mantenimiento',
              helperText: 'Se calcula automáticamente desde reportes.',
              suffixIcon: const Icon(Icons.lock_outline, size: 16),
              keyboardType: TextInputType.number,
              readOnly: true,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _costoReemplazoController,
              label: 'Costo Reemplazo',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _vidaUtilEsperadaController,
              label: 'Vida Útil Esperada (Años)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text("Fecha Instalación"),
              subtitle: Text(_formatDate(_fechaInstalacion)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectOptionalDate(
                initialDate: _fechaInstalacion,
                onSelected: (date) => setState(() => _fechaInstalacion = date),
              ),
            ),

            if (_isMobiliarios) ...[
              const SizedBox(height: 20),
              const Text("Datos de Mobiliario", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _tipoMobiliarioController,
                label: 'Tipo de Mobiliario',
              ),
              _buildTextField(
                controller: _materialPrincipalController,
                label: 'Material Principal',
              ),
              _buildTextField(
                controller: _usoIntensivoController,
                label: 'Uso Intensivo',
              ),
              _buildTextField(
                controller: _movilidadController,
                label: 'Movilidad',
              ),
              _buildTextField(
                controller: _fabricanteController,
                label: 'Fabricante',
              ),
              _buildTextField(
                controller: _modeloController,
                label: 'Modelo',
              ),
              ListTile(
                title: const Text("Fecha de Adquisición"),
                subtitle: Text(_formatDate(_fechaAdquisicion)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectOptionalDate(
                  initialDate: _fechaAdquisicion,
                  onSelected: (date) => setState(() => _fechaAdquisicion = date),
                ),
              ),
              _buildTextField(
                controller: _proveedorController,
                label: 'Proveedor',
              ),
              _buildTextField(
                controller: _observacionesController,
                label: 'Observaciones',
                maxLines: 3,
              ),
            ],

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _saveChanges,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('GUARDAR CAMBIOS', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  void _updateIdActivoPreview() {
    if (!_autoGenerarId) {
      return;
    }
    final preview = ActivoIdHelper.buildPreview(
      disciplinaKey: _disciplinaKey,
      nombre: _nombreController.text.trim(),
      bloque: _bloqueController.text.trim(),
      nivel: _nivelController.text.trim(),
      correlativo: _idActivoCorrelativo,
    );
    setState(() {
      _idActivoController.text = preview;
      _idActivoError = null;
    });
  }

  void _scheduleIdActivoCheck(String value) {
    _idCheckDebounce?.cancel();
    _idCheckDebounce = Timer(const Duration(milliseconds: 400), () {
      _checkIdActivoUnique(value);
    });
  }

  Future<bool> _checkIdActivoUnique(String rawValue) async {
    final value = rawValue.trim();
    if (value.isEmpty) {
      if (!mounted) return false;
      setState(() => _idActivoError = 'El ID es requerido.');
      return false;
    }
    if (_lastCheckedId == value && _lastCheckedUnique != null) {
      if (!mounted) return _lastCheckedUnique!;
      setState(() => _idActivoError = _lastCheckedUnique! ? null : 'Ese ID ya existe, usa otro.');
      return _lastCheckedUnique!;
    }
    if (!mounted) return false;
    setState(() {
      _isCheckingId = true;
      _idActivoError = null;
    });
    final snapshot = await FirebaseFirestore.instance
        .collection('productos')
        .where('idActivo', isEqualTo: value)
        .limit(2)
        .get();
    final conflict = snapshot.docs.any((doc) => doc.id != widget.productId);
    final unique = !conflict;
    if (!mounted) return unique;
    setState(() {
      _isCheckingId = false;
      _idActivoError = unique ? null : 'Ese ID ya existe, usa otro.';
      _lastCheckedId = value;
      _lastCheckedUnique = unique;
    });
    return unique;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? helperText,
    Widget? suffixIcon,
    bool readOnly = false,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onChanged: onChanged,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          helperText: helperText,
          suffixIcon: suffixIcon,
          border: const OutlineInputBorder(),
        ),
      ),
    );
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

  DateTime? _resolveDate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '--/--/----';
    }
    return DateFormat('dd/MM/yyyy').format(value);
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

  bool get _isMobiliarios => _disciplinaKey == 'mobiliarios';

  String _subcategoriaHint() {
    final key = _disciplinaKey.toLowerCase();
    const hints = {
      'electricas': 'Ej: luces_emergencia',
      'sanitarias': 'Ej: grifos_lavamanos',
      'estructuras': 'Ej: vigas_concreto',
      'arquitectura': 'Ej: puertas_madera',
      'mecanica': 'Ej: bombas_circulacion',
      'mobiliarios': 'Ej: mesas_estudiante',
    };
    return hints[key] ?? 'Ej: subcategoria_equipo';
  }

  String _serieHint() {
    final key = _disciplinaKey.toLowerCase();
    const hints = {
      'electricas': 'Ej: LE-2026-001',
      'sanitarias': 'Ej: SA-2026-005',
      'estructuras': 'Ej: ES-2026-007',
      'arquitectura': 'Ej: AR-2026-012',
      'mecanica': 'Ej: MC-2026-003',
      'mobiliarios': 'Ej: ME-2026-010',
    };
    return hints[key] ?? 'Ej: EQ-2026-001';
  }
}
