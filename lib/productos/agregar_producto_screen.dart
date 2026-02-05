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
import 'package:appmantflutter/services/categorias_service.dart';
import 'package:appmantflutter/services/audit_service.dart';
import 'dart:async';

class AgregarProductoScreen extends StatefulWidget {
  final String? initialDisciplinaKey;
  final String? initialCategoriaValue;

  const AgregarProductoScreen({
    super.key,
    this.initialDisciplinaKey,
    this.initialCategoriaValue,
  });

  @override
  State<AgregarProductoScreen> createState() => _AgregarProductoScreenState();
}

class _AgregarProductoScreenState extends State<AgregarProductoScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isUploading = false;
  bool _autoGenerarId = true;
  bool _isCheckingId = false;
  String? _idActivoError;
  Timer? _idCheckDebounce;
  String? _lastCheckedId;
  bool? _lastCheckedUnique;
  bool _initialCategoriaAplicada = false;

  final _schemaService = SchemaService();
  final _parametrosSchemaService = ParametrosSchemaService();
  final _datasetService = ParametrosDatasetService();

  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _serieCtrl = TextEditingController();
  final _subcategoriaCtrl = TextEditingController();

  final _bloqueCtrl = TextEditingController();
  final _nivelCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _idActivoCtrl = TextEditingController();
  final _frecuenciaMantenimientoCtrl = TextEditingController();
  final _costoReemplazoCtrl = TextEditingController();
  final _vidaUtilEsperadaCtrl = TextEditingController();
  final _tipoMobiliarioCtrl = TextEditingController();
  final _materialPrincipalCtrl = TextEditingController();
  final _usoIntensivoCtrl = TextEditingController();
  final _movilidadCtrl = TextEditingController();
  final _fabricanteCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _proveedorCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  final Map<String, TextEditingController> _dynamicControllers = {};

  final _categoriasService = CategoriasService.instance;
  StreamSubscription<List<CategoriaItem>>? _categoriasSub;
  List<CategoriaItem> _categorias = [];
  String? _categoria;
  String _disciplina = 'Electricas';
  String _estado = 'operativo';
  String _condicionFisica = 'buena';
  String _tipoMantenimiento = 'preventivo';
  String _nivelCriticidad = 'medio';
  String _impactoFalla = 'operacion';
  String _riesgoNormativo = 'cumple';
  bool _requiereReemplazo = false;
  
  DateTime _fechaInstalacion = DateTime.now();
  bool _fechaInstalacionCustom = false;
  DateTime? _fechaAdquisicion;
  bool _fechaAdquisicionCustom = false;
  File? _imageFile;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _marcaCtrl.dispose();
    _serieCtrl.dispose();
    _subcategoriaCtrl.dispose();
    _bloqueCtrl.dispose();
    _nivelCtrl.dispose();
    _areaCtrl.dispose();
    _idActivoCtrl.dispose();
    _frecuenciaMantenimientoCtrl.dispose();
    _costoReemplazoCtrl.dispose();
    _vidaUtilEsperadaCtrl.dispose();
    _tipoMobiliarioCtrl.dispose();
    _materialPrincipalCtrl.dispose();
    _usoIntensivoCtrl.dispose();
    _movilidadCtrl.dispose();
    _fabricanteCtrl.dispose();
    _modeloCtrl.dispose();
    _proveedorCtrl.dispose();
    _observacionesCtrl.dispose();
    for (final controller in _dynamicControllers.values) {
      controller.dispose();
    }
    _categoriasSub?.cancel();
    _idCheckDebounce?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _parametrosSchemaService.seedSchemasIfMissing();
    _setInitialDisciplina();
    _updateIdActivoPreview();
    _subscribeCategorias();
  }

  void _setInitialDisciplina() {
    final initialKey = widget.initialDisciplinaKey?.toLowerCase().trim();
    if (initialKey == null || initialKey.isEmpty) {
      return;
    }
    final label = _disciplinaLabelForKey(initialKey);
    if (label.isNotEmpty) {
      _disciplina = label;
    }
  }

  Future<void> _subscribeCategorias() async {
    final disciplinaKey = _disciplina.toLowerCase();
    await _categoriasService.ensureSeededForDisciplina(disciplinaKey);
    await _categoriasSub?.cancel();
    _categoriasSub = _categoriasService.streamByDisciplina(disciplinaKey).listen((items) {
      if (!mounted) return;
      setState(() {
        _categorias = items;
        final initialValue = widget.initialCategoriaValue?.trim();
        if (!_initialCategoriaAplicada && initialValue != null && initialValue.isNotEmpty) {
          final exists = _categorias.any((item) => item.value == initialValue);
          if (exists) {
            _categoria = initialValue;
          }
          _initialCategoriaAplicada = true;
        }
        if (_categoria == null || !_categorias.any((item) => item.value == _categoria)) {
          _categoria = _categorias.isNotEmpty ? _categorias.first.value : null;
        }
      });
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (!mounted) return;
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
    if (!_isCategoriaValida()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione una categoría válida para la disciplina.')),
      );
      return;
    }
    if (!_autoGenerarId) {
      final manualId = _idActivoCtrl.text.trim();
      final unique = await _checkIdActivoUnique(manualId);
      if (!unique) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ese ID ya existe, usa otro.')),
          );
        }
        return;
      }
    }
    setState(() => _isUploading = true);

    try {
      final String? imageUrl = await _uploadImageToSupabase();

      final disciplinaKey = _disciplina.toLowerCase();
      String idActivo;
      if (_autoGenerarId) {
        final int activoCounter = await _getAndIncrementActivoCounter(disciplinaKey);
        final correlativo = ActivoIdHelper.formatCorrelativo(activoCounter);
        idActivo = ActivoIdHelper.buildId(
          disciplinaKey: disciplinaKey,
          nombre: _nombreCtrl.text.trim(),
          bloque: _bloqueCtrl.text.trim(),
          nivel: _nivelCtrl.text.trim(),
          correlativo: correlativo,
        );
        final unique = await _checkIdActivoUnique(idActivo);
        if (!unique) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ese ID ya existe, usa otro.')),
            );
            setState(() => _isUploading = false);
          }
          return;
        }
      } else {
        idActivo = _idActivoCtrl.text.trim();
      }
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
        'subcategoria': _subcategoriaCtrl.text.trim().isEmpty ? null : _subcategoriaCtrl.text.trim(),
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
        'tipoMobiliario': _isMobiliarios ? _tipoMobiliarioCtrl.text.trim() : null,
        'materialPrincipal': _isMobiliarios ? _materialPrincipalCtrl.text.trim() : null,
        'usoIntensivo': _isMobiliarios ? _usoIntensivoCtrl.text.trim() : null,
        'movilidad': _isMobiliarios ? _movilidadCtrl.text.trim() : null,
        'fabricante': _isMobiliarios ? _fabricanteCtrl.text.trim() : null,
        'modelo': _isMobiliarios ? _modeloCtrl.text.trim() : null,
        'fechaAdquisicion': _isMobiliarios && _fechaAdquisicionCustom && _fechaAdquisicion != null
            ? Timestamp.fromDate(_fechaAdquisicion!)
            : null,
        'proveedor': _isMobiliarios ? _proveedorCtrl.text.trim() : null,
        'observaciones': _isMobiliarios ? _observacionesCtrl.text.trim() : null,
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

      await AuditService.logEvent(
        action: 'asset.create',
        message: 'creó un nuevo activo ($idActivo)',
        disciplina: disciplinaKey,
        categoria: _categoria,
        productDocId: productRef.id,
        idActivo: idActivo,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto agregado correctamente")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _updateIdActivoPreview() {
    if (!_autoGenerarId) {
      return;
    }
    final disciplinaKey = _disciplina.toLowerCase();
    final preview = ActivoIdHelper.buildPreview(
      disciplinaKey: disciplinaKey,
      nombre: _nombreCtrl.text.trim(),
      bloque: _bloqueCtrl.text.trim(),
      nivel: _nivelCtrl.text.trim(),
    );
    setState(() {
      _idActivoCtrl.text = preview;
      _idActivoError = null;
    });
  }

  String _disciplinaLabelForKey(String disciplinaKey) {
    switch (disciplinaKey.toLowerCase()) {
      case 'electricas':
        return 'Electricas';
      case 'sanitarias':
        return 'Sanitarias';
      case 'estructuras':
        return 'Estructuras';
      case 'arquitectura':
        return 'Arquitectura';
      case 'mecanica':
        return 'Mecanica';
      case 'mobiliarios':
        return 'Mobiliarios';
      default:
        return '';
    }
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
        .limit(1)
        .get();
    final unique = snapshot.docs.isEmpty;
    if (!mounted) return unique;
    setState(() {
      _isCheckingId = false;
      _idActivoError = unique ? null : 'Ese ID ya existe, usa otro.';
      _lastCheckedId = value;
      _lastCheckedUnique = unique;
    });
    return unique;
  }

  @override
  Widget build(BuildContext context) {
    final categorias = _categorias;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Agregar Activo"),
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
                  setState(() {
                    _disciplina = v!;
                    if (!_isMobiliarios) {
                      _resetMobiliariosFields();
                    }
                    _updateIdActivoPreview();
                  });
                  _subscribeCategorias();
                },
              ),
              _buildDropdown(
                "Categoría",
                _categoria,
                categorias.map((item) => item.value).toList(),
                (v) => setState(() => _categoria = v),
                hintText: categorias.isEmpty ? 'Sin categorías disponibles' : 'Seleccione una categoría',
                itemLabels: {for (final item in categorias) item.value: item.label},
              ),
              if (categorias.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'No hay categorías disponibles para esta disciplina.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              _buildTextField(
                _subcategoriaCtrl,
                "Subcategoría (Escribir manual)",
                hintText: _subcategoriaHint(_disciplina),
                isManual: true,
              ),
              _buildTextField(_marcaCtrl, "Marca"),
              _buildTextField(
                _serieCtrl,
                "Serie",
                hintText: _serieHint(_disciplina),
              ),
              
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
                controller: _idActivoCtrl,
                decoration: InputDecoration(
                  labelText: _autoGenerarId ? 'ID Activo (autogenerado)' : 'ID Activo',
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
              _buildTextField(_frecuenciaMantenimientoCtrl, "Frecuencia Mantenimiento (meses)", keyboardType: TextInputType.number),
              _buildTextField(_costoReemplazoCtrl, "Costo Reemplazo", keyboardType: TextInputType.number),
              _buildTextField(_vidaUtilEsperadaCtrl, "Vida Útil Esperada (Años)", keyboardType: TextInputType.number),

              if (_isMobiliarios) ...[
                const SizedBox(height: 20),
                const Text("Datos de Mobiliario", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10),
                _buildTextField(_tipoMobiliarioCtrl, "Tipo de Mobiliario"),
                _buildTextField(_materialPrincipalCtrl, "Material Principal"),
                _buildTextField(_usoIntensivoCtrl, "Uso Intensivo"),
                _buildTextField(_movilidadCtrl, "Movilidad"),
                _buildTextField(_fabricanteCtrl, "Fabricante"),
                _buildTextField(_modeloCtrl, "Modelo"),
                ListTile(
                  title: const Text("Fecha de Adquisición"),
                  subtitle: Text(_fechaAdquisicion == null
                      ? '--/--/----'
                      : DateFormat('dd/MM/yyyy').format(_fechaAdquisicion!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectOptionalDate(
                    initialDate: _fechaAdquisicion ?? DateTime.now(),
                    onSelected: (date) => setState(() {
                      _fechaAdquisicion = date;
                      _fechaAdquisicionCustom = true;
                    }),
                  ),
                ),
                _buildTextField(_proveedorCtrl, "Proveedor"),
                _buildTextField(_observacionesCtrl, "Observaciones", maxLines: 3),
              ],

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
    String? hintText,
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
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: const OutlineInputBorder(),
        ),
        validator: (v) => (v == null || v.isEmpty) && !isManual ? 'Campo requerido' : null,
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged, {
    String? hintText,
    Map<String, String>? itemLabels,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value != null && items.contains(value) ? value : null,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: items
            .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(itemLabels?[e] ?? _formatLabel(e)),
                ))
            .toList(),
        hint: hintText != null ? Text(hintText) : null,
        onChanged: onChanged,
        validator: (val) {
          if (val == null || val.isEmpty) {
            return 'Campo requerido';
          }
          if (items.isNotEmpty && !items.contains(val)) {
            return 'Categoría inválida';
          }
          return null;
        },
      ),
    );
  }

  bool get _isMobiliarios => _disciplina.toLowerCase() == 'mobiliarios';

  bool _isCategoriaValida() {
    if (_categorias.isEmpty) {
      return false;
    }
    return _categoria != null && _categorias.any((item) => item.value == _categoria);
  }

  void _resetMobiliariosFields() {
    _tipoMobiliarioCtrl.clear();
    _materialPrincipalCtrl.clear();
    _usoIntensivoCtrl.clear();
    _movilidadCtrl.clear();
    _fabricanteCtrl.clear();
    _modeloCtrl.clear();
    _proveedorCtrl.clear();
    _observacionesCtrl.clear();
    _fechaAdquisicion = null;
    _fechaAdquisicionCustom = false;
  }

  String _subcategoriaHint(String disciplina) {
    final key = disciplina.toLowerCase();
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

  String _serieHint(String disciplina) {
    final key = disciplina.toLowerCase();
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
      'tipoMobiliario',
      'materialPrincipal',
      'usoIntensivo',
      'movilidad',
      'fabricante',
      'modelo',
      'fechaAdquisicion',
      'proveedor',
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
