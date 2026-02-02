import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:appmantflutter/services/date_utils.dart';

class GenerarReporteScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final String productCategory;
  final String initialStatus;
  final Map<String, dynamic> productLocation;

  const GenerarReporteScreen({
    super.key,
    required this.productId,
    required this.productName,
    required this.productCategory,
    required this.initialStatus,
    required this.productLocation,
  });

  @override
  State<GenerarReporteScreen> createState() => _GenerarReporteScreenState();
}

class _GenerarReporteScreenState extends State<GenerarReporteScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _descripcionCtrl = TextEditingController();
  final TextEditingController _comentariosCtrl = TextEditingController();
  final TextEditingController _encargadoCtrl = TextEditingController();
  final TextEditingController _estadoDetectadoCtrl = TextEditingController();
  final TextEditingController _riesgoElectricoCtrl = TextEditingController();
  final TextEditingController _nivelDesgasteCtrl = TextEditingController();
  final TextEditingController _riesgoUsuarioCtrl = TextEditingController();
  final TextEditingController _accionRecomendadaCtrl = TextEditingController();
  final TextEditingController _costoEstimadoCtrl = TextEditingController();

  String _nuevoEstado = 'OPERATIVO';
  String _condicionFisica = 'buena';
  String? _tipoReporte;
  String? _tipoMantenimiento;
  String _nivelCriticidad = 'medio';
  String _impactoFalla = 'operacion';
  String _riesgoNormativo = 'cumple';
  bool _requiereReemplazo = false;

  DateTime _fechaInspeccion = DateTime.now();
  
  bool _isSaving = false; 
  String _disciplinaKey = '';

  @override
  void initState() {
    super.initState();
    _nuevoEstado = widget.initialStatus.toUpperCase();
    _loadDisciplina();
    _autoFillEncargado();
  }

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    _comentariosCtrl.dispose();
    _encargadoCtrl.dispose();
    _estadoDetectadoCtrl.dispose();
    _riesgoElectricoCtrl.dispose();
    _nivelDesgasteCtrl.dispose();
    _riesgoUsuarioCtrl.dispose();
    _accionRecomendadaCtrl.dispose();
    _costoEstimadoCtrl.dispose();
    super.dispose();
  }

  Future<void> _autoFillEncargado() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      final name = await _resolveResponsableNombre(user);
      if (mounted) {
        setState(() {
          _encargadoCtrl.text = name;
        });
      }
    }
  }

  Future<String> _resolveResponsableNombre(User user) async {
    final email = user.email;
    if (email != null && email.isNotEmpty) {
      final snapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final nombre = snapshot.docs.first.data()['nombre']?.toString().trim();
        if (nombre != null && nombre.isNotEmpty) {
          return nombre;
        }
      }
    }
    return user.displayName ?? user.email ?? _encargadoCtrl.text.trim();
  }

  Future<void> _loadDisciplina() async {
    final productDoc = await FirebaseFirestore.instance
        .collection('productos')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        )
        .doc(widget.productId)
        .get();
    if (!productDoc.exists) {
      return;
    }
    final disciplina = productDoc.data()?['disciplina']?.toString().toLowerCase() ?? '';
    if (mounted) {
      setState(() {
        _disciplinaKey = disciplina;
        if (_isMobiliarios) {
          _tipoReporte = null;
          _tipoMantenimiento = null;
          _requiereReemplazo = false;
        }
      });
    }
  }

  Future<int> _getAndIncrementReportCounter() async {
    final counterRef = FirebaseFirestore.instance
        .collection('metadata')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        )
        .doc('counters');

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      int currentNumber;

      if (!snapshot.exists || snapshot.data()?['report_nro'] == null) {
        currentNumber = 1; 
      } else {
        currentNumber = (snapshot.data()!['report_nro'] as int) + 1;
      }

      transaction.set(counterRef, {'report_nro': currentNumber});
      return currentNumber;
    });
  }

  Future<void> _saveReport() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isSaving = true;
    });
    if (_requiresTipoReporte && _tipoReporte == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleccione el tipo de reporte.')),
        );
        setState(() {
          _isSaving = false;
        });
      }
      return;
    }
    
    try {
      final int nextReportNumber = await _getAndIncrementReportCounter();
      final String reportNumber = nextReportNumber.toString().padLeft(4, '0');
      
      final fechaInspeccion = Timestamp.fromDate(_fechaInspeccion);
      final double? costoEstimado = _parseDouble(_costoEstimadoCtrl.text);
      final user = FirebaseAuth.instance.currentUser;
      final responsableNombre = user != null
          ? await _resolveResponsableNombre(user)
          : _encargadoCtrl.text.trim();
      final responsableUid = user?.uid ?? '';

      final productsRef = FirebaseFirestore.instance
          .collection('productos')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snapshot, _) => snapshot.data() ?? {},
            toFirestore: (data, _) => data,
          );

      final productRef = productsRef.doc(widget.productId);
      final productSnap = await productRef.get();
      final productData = productSnap.data() ?? {};
      final reportRef = productRef.collection('reportes').doc();
      final reportData = <String, dynamic>{
        'nro': reportNumber,
        'productId': widget.productId,
        'codigoQR': productData['codigoQR'],
        'nombreProducto': productData['nombreProducto'] ?? widget.productName,
        'activo_nombre': widget.productName,
        'activoNombre': widget.productName,
        'disciplina': productData['disciplina'],
        'categoria': productData['categoria'] ?? widget.productCategory,
        'fechaInspeccion': fechaInspeccion,
        'estadoDetectado': _estadoDetectadoCtrl.text.trim(),
        'accionRecomendada': _accionRecomendadaCtrl.text.trim(),
        'costoEstimado': costoEstimado,
        'responsable': responsableNombre,
        'responsableNombre': responsableNombre,
        'responsableUid': responsableUid,
        'encargado': responsableNombre,
        'fechaDisplay': DateFormat('dd/MM/yyyy').format(_fechaInspeccion),
        'ubicacion': widget.productLocation,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_isMobiliarios) {
        reportData['nivelDesgaste'] = _nivelDesgasteCtrl.text.trim();
        reportData['riesgoUsuario'] = _riesgoUsuarioCtrl.text.trim();
      } else {
        reportData.addAll({
          'riesgoElectrico': _riesgoElectricoCtrl.text.trim(),
          'tipoReporte': _tipoReporte,
          'descripcion': _descripcionCtrl.text.trim(),
          'comentarios': _comentariosCtrl.text.trim(),
          'estadoAnterior': widget.initialStatus.toLowerCase(),
          'estadoNuevo': _nuevoEstado.toLowerCase(),
          'estadoOperativo': _nuevoEstado.toLowerCase(),
          'condicionFisica': _condicionFisica,
          'tipoMantenimiento': _showTipoMantenimiento ? _tipoMantenimiento : null,
          'nivelCriticidad': _nivelCriticidad,
          'impactoFalla': _impactoFalla,
          'riesgoNormativo': _riesgoNormativo,
          'requiereReemplazo': _showRequiereReemplazo ? _requiereReemplazo : false,
        });
      }

      await reportRef.set(reportData);
      await FirebaseFirestore.instance
          .collection('reportes')
          .doc(reportRef.id)
          .set(reportData);
      final frecuencia = _parseFrecuenciaMeses(productData['frecuenciaMantenimientoMeses']);
      final fechaProximo =
          frecuencia != null ? addMonthsDouble(_fechaInspeccion, frecuencia) : null;

      final updateData = <String, dynamic>{
        'fechaUltimaInspeccion': fechaInspeccion,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!_isMobiliarios) {
        updateData.addAll({
          'estado': _nuevoEstado.toLowerCase(),
          'estadoOperativo': _nuevoEstado.toLowerCase(),
          'condicionFisica': _condicionFisica,
          'tipoMantenimiento': _showTipoMantenimiento ? _tipoMantenimiento : null,
          'nivelCriticidad': _nivelCriticidad,
          'impactoFalla': _impactoFalla,
          'riesgoNormativo': _riesgoNormativo,
          'requiereReemplazo': _showRequiereReemplazo ? _requiereReemplazo : false,
        });
      }

      if (fechaProximo != null) {
        updateData['fechaProximoMantenimiento'] = Timestamp.fromDate(fechaProximo);
      }
      if (costoEstimado != null) {
        updateData['costoMantenimiento'] = FieldValue.increment(costoEstimado);
      }

      await productRef.update(updateData);

      if (mounted) {
        Navigator.of(context).pop(); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reporte N° $reportNumber guardado con éxito!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Generar Reporte"),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 20.0),
              child: Text(
                "El número de reporte será asignado automáticamente al guardar.", 
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
            ),
            
            if (_requiresTipoReporte) _buildTipoReporteDropdown(),
            
            _buildReadOnlyField("Activo*", "${widget.productName}"),
            _buildReadOnlyField(
              "Ubicación",
              "Bloque: ${widget.productLocation['bloque'] ?? '--'} - Nivel: ${widget.productLocation['nivel'] ?? widget.productLocation['piso'] ?? '--'}",
            ),
            _buildReadOnlyField("Categoría", widget.productCategory),
            _buildReadOnlyField("Estado Actual", _formatEstadoLabel(widget.initialStatus)),

            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Fecha de Inspección"),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_fechaInspeccion)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _fechaInspeccion,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2101),
                );
                if (picked != null && mounted) {
                  setState(() => _fechaInspeccion = picked);
                }
              },
            ),

            _buildTextField(
              controller: _estadoDetectadoCtrl,
              label: "Estado Detectado*",
              hint: "EJ: Operativo con falla",
            ),
            if (_isMobiliarios)
              _buildTextField(
                controller: _nivelDesgasteCtrl,
                label: "Nivel de Desgaste*",
                hint: "EJ: Medio",
              ),
            if (_isMobiliarios)
              _buildTextField(
                controller: _riesgoUsuarioCtrl,
                label: "Riesgo al Usuario*",
                hint: "EJ: Bajo",
              ),
            if (!_isMobiliarios)
              _buildTextField(
                controller: _riesgoElectricoCtrl,
                label: "Riesgo Eléctrico*",
                hint: "EJ: Alto",
              ),
            _buildTextField(
              controller: _accionRecomendadaCtrl,
              label: "Acción Recomendada*",
              hint: "EJ: Reemplazar componente",
            ),
            _buildTextField(
              controller: _costoEstimadoCtrl,
              label: "Costo Estimado",
              hint: "EJ: 1500",
              keyboardType: TextInputType.number,
            ),
            _buildReadOnlyField(_isMobiliarios ? "Responsable" : "Encargado (usuario)", _encargadoCtrl.text),

            if (!_isMobiliarios)
              _buildTextField(
                controller: _descripcionCtrl,
                label: "Descripción del Reporte*",
                hint: "Describa el problema o la tarea realizada...",
                maxLines: 4,
              ),

            if (!_isMobiliarios)
              _buildSegmentedControl(
                label: "Estado operativo del activo*",
                options: const ['OPERATIVO', 'DEFECTUOSO', 'FUERA_SERVICIO'],
                value: _nuevoEstado,
                onChanged: (newValue) => setState(() => _nuevoEstado = newValue),
              ),

            if (!_isMobiliarios)
              _buildDropdownField(
                label: "Condición Física",
                value: _condicionFisica,
                items: const ['buena', 'regular', 'mala'],
                onChanged: (value) => setState(() => _condicionFisica = value ?? _condicionFisica),
              ),
            if (!_isMobiliarios && _showTipoMantenimiento)
              _buildSegmentedControl(
                label: "Tipo de mantenimiento*",
                options: const ['preventivo', 'correctivo', 'situacional'],
                value: _tipoMantenimiento ?? 'preventivo',
                onChanged: (newValue) => setState(() => _tipoMantenimiento = newValue),
              ),
            if (!_isMobiliarios)
              _buildDropdownField(
                label: "Nivel de Criticidad",
                value: _nivelCriticidad,
                items: const ['alto', 'medio', 'bajo'],
                onChanged: (value) => setState(() => _nivelCriticidad = value ?? _nivelCriticidad),
              ),
            if (!_isMobiliarios)
              _buildDropdownField(
                label: "Impacto de Falla",
                value: _impactoFalla,
                items: const ['seguridad', 'operacion', 'confort'],
                onChanged: (value) => setState(() => _impactoFalla = value ?? _impactoFalla),
              ),
            if (!_isMobiliarios)
              _buildDropdownField(
                label: "Riesgo Normativo",
                value: _riesgoNormativo,
                items: const ['cumple', 'no_cumple', 'evaluar'],
                onChanged: (value) => setState(() => _riesgoNormativo = value ?? _riesgoNormativo),
              ),
            if (!_isMobiliarios && _showRequiereReemplazo)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Requiere Reemplazo"),
                value: _requiereReemplazo,
                onChanged: _isSaving ? null : (value) => setState(() => _requiereReemplazo = value),
              ),

            if (!_isMobiliarios)
              _buildTextField(
                controller: _comentariosCtrl,
                label: "Acciones Tomadas / Comentarios",
                hint: "Añada comentarios sobre las acciones tomadas o la solución...",
                maxLines: 3,
                isRequired: false,
              ),
            
            const SizedBox(height: 30),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  child: Text('CANCELAR', style: TextStyle(fontWeight: FontWeight.bold, color: _isSaving ? Colors.grey : const Color(0xFF7F8C8D))),
                ),
                const SizedBox(width: 10),
                
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveReport,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    disabledBackgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                  ),
                  child: _isSaving 
                    ? const SizedBox(
                        width: 20, 
                        height: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : const Text('GUARDAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label, 
    required String hint, 
    int maxLines = 1, 
    bool isRequired = true,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        ),
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return 'Campo requerido';
          }
          return null;
        },
        enabled: !_isSaving,
        readOnly: readOnly,
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
              color: Colors.grey.shade100,
            ),
            child: Text(value, style: const TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildTipoReporteDropdown() {
    const options = [
      {'value': 'mantenimiento', 'label': 'Mantenimiento'},
      {'value': 'inspeccion', 'label': 'Inspección'},
      {'value': 'incidente_falla', 'label': 'Incidente/Falla'},
      {'value': 'auditoria', 'label': 'Auditoría'},
      {'value': 'reemplazo', 'label': 'Reemplazo'},
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        value: _tipoReporte,
        decoration: const InputDecoration(
          labelText: "Tipo de Reporte*",
          border: OutlineInputBorder(),
        ),
        items: options
            .map((item) => DropdownMenuItem(value: item['value'], child: Text(item['label'] ?? '')))
            .toList(),
        onChanged: _isSaving
            ? null
            : (value) {
                setState(() {
                  _tipoReporte = value;
                  if (_showTipoMantenimiento && _tipoMantenimiento == null) {
                    _tipoMantenimiento = 'preventivo';
                  }
                  if (!_showRequiereReemplazo) {
                    _requiereReemplazo = false;
                  }
                  if (!_showTipoMantenimiento) {
                    _tipoMantenimiento = null;
                  }
                });
              },
        validator: (value) => value == null || value.isEmpty ? 'Campo requerido' : null,
      ),
    );
  }

  double? _parseDouble(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return double.tryParse(trimmed.replaceAll(',', '.'));
  }

  int? _parseInt(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return int.tryParse(trimmed);
  }

  double? _parseFrecuenciaMeses(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString().replaceAll(',', '.'));
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        value: items.contains(value) ? value : items.first,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(_formatEstadoLabel(item))))
            .toList(),
        onChanged: _isSaving ? null : onChanged,
      ),
    );
  }

  Widget _buildSegmentedControl({
    required String label,
    required List<String> options,
    required String value,
    required Function(String) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: options.map((option) {
                final bool isSelected = value == option;
                return Expanded(
                  child: InkWell(
                    onTap: _isSaving ? null : () => onChanged(option),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(option == options.first ? 8 : 0),
                          right: Radius.circular(option == options.last ? 8 : 0),
                        ),
                        border: Border(
                          right: option != options.last
                              ? BorderSide(color: Colors.grey.shade300)
                              : BorderSide.none,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _formatEstadoLabel(option),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatEstadoLabel(String estado) {
    final normalized = estado.replaceAll('_', ' ');
    if (normalized.isEmpty) {
      return estado;
    }
    return normalized
        .split(' ')
        .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  bool get _showTipoMantenimiento => !_isMobiliarios && _tipoReporte == 'mantenimiento';

  bool get _showRequiereReemplazo =>
      !_isMobiliarios &&
      (_tipoReporte == 'mantenimiento' ||
          _tipoReporte == 'inspeccion' ||
          _tipoReporte == 'incidente_falla');

  bool get _requiresTipoReporte => !_isMobiliarios;

  bool get _isMobiliarios => _disciplinaKey == 'mobiliarios';
}
