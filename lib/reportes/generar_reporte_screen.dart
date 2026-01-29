import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
    required this.productLocation, // Requerido en constructor
  });

  @override
  State<GenerarReporteScreen> createState() => _GenerarReporteScreenState();
}

class _GenerarReporteScreenState extends State<GenerarReporteScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // --- 1. CONTROLADORES PARA TODOS LOS CAMPOS DE TEXTO ---
  // Usamos controladores en lugar de variables String para asegurar la captura del texto
  final TextEditingController _tipoReporteCtrl = TextEditingController();
  final TextEditingController _descripcionCtrl = TextEditingController();
  final TextEditingController _comentariosCtrl = TextEditingController();
  final TextEditingController _encargadoCtrl = TextEditingController(); // Ya existía
  final TextEditingController _estadoDetectadoCtrl = TextEditingController();
  final TextEditingController _riesgoElectricoCtrl = TextEditingController();
  final TextEditingController _accionRecomendadaCtrl = TextEditingController();
  final TextEditingController _costoEstimadoCtrl = TextEditingController();
  final TextEditingController _responsableCtrl = TextEditingController();
  final TextEditingController _nivelCriticidadCtrl = TextEditingController();
  final TextEditingController _impactoFallaCtrl = TextEditingController();
  final TextEditingController _riesgoNormativoCtrl = TextEditingController();
  
  // Variables para Dropdowns/Selectores (estos sí se quedan como variables)
  String _nuevoEstado = 'OPERATIVO';
  String _reposicion = 'NO';
  String _condicionFisica = 'buena';

  DateTime _fechaInspeccion = DateTime.now();
  
  bool _isSaving = false; 

  @override
  void initState() {
    super.initState();
    _autoFillEncargado();
  }

  @override
  void dispose() {
    // Limpiamos los controladores al salir para liberar memoria
    _tipoReporteCtrl.dispose();
    _descripcionCtrl.dispose();
    _comentariosCtrl.dispose();
    _encargadoCtrl.dispose();
    _estadoDetectadoCtrl.dispose();
    _riesgoElectricoCtrl.dispose();
    _accionRecomendadaCtrl.dispose();
    _costoEstimadoCtrl.dispose();
    _responsableCtrl.dispose();
    _nivelCriticidadCtrl.dispose();
    _impactoFallaCtrl.dispose();
    _riesgoNormativoCtrl.dispose();
    super.dispose();
  }

  // --- FUNCIÓN DE AUTOLLENADO DE ENCARGADO ---
  Future<void> _autoFillEncargado() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      if (mounted) setState(() => _encargadoCtrl.text = "Cargando...");

      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('usuarios')
            .withConverter<Map<String, dynamic>>(
              fromFirestore: (snapshot, _) => snapshot.data() ?? {},
              toFirestore: (data, _) => data,
            )
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final userData = querySnapshot.docs.first.data();
          if (mounted) {
            final name = userData['nombre'] ?? user.email ?? '';
            setState(() {
              _encargadoCtrl.text = name;
              _responsableCtrl.text = name;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _encargadoCtrl.text = user.email ?? '';
              _responsableCtrl.text = user.email ?? '';
            });
          }
        }
      } catch (e) {
        print("Error obteniendo usuario: $e");
        if (mounted) {
          setState(() {
            _encargadoCtrl.text = user.email ?? '';
            _responsableCtrl.text = user.email ?? '';
          });
        }
      }
    }
  }

  // --- FUNCIÓN DE CONTADOR ATÓMICO ---
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

  // --- FUNCIÓN PARA GUARDAR REPORTE ---
  Future<void> _saveReport() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) return;
    // Ya no necesitamos _formKey.currentState!.save() porque usamos controladores
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      final int nextReportNumber = await _getAndIncrementReportCounter();
      final String reportNumber = nextReportNumber.toString().padLeft(4, '0');
      
      final fechaInspeccion = Timestamp.fromDate(_fechaInspeccion);
      final double? costoEstimado = _parseDouble(_costoEstimadoCtrl.text);

      final productsRef = FirebaseFirestore.instance
          .collection('productos')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snapshot, _) => snapshot.data() ?? {},
            toFirestore: (data, _) => data,
          );

      await productsRef
          .doc(widget.productId)
          .collection('reportes')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snapshot, _) => snapshot.data() ?? {},
            toFirestore: (data, _) => data,
          )
          .add({
        'nro': reportNumber,
        'fechaInspeccion': fechaInspeccion,
        'estadoDetectado': _estadoDetectadoCtrl.text.trim(),
        'riesgoElectrico': _riesgoElectricoCtrl.text.trim(),
        'accionRecomendada': _accionRecomendadaCtrl.text.trim(),
        'costoEstimado': costoEstimado,
        'responsable': _responsableCtrl.text.trim(),
        'tipoReporte': _tipoReporteCtrl.text.trim(),
        'descripcion': _descripcionCtrl.text.trim(),
        'comentarios': _comentariosCtrl.text.trim(),
        'estadoAnterior': widget.initialStatus.toLowerCase(),
        'estadoNuevo': _nuevoEstado.toLowerCase(),
        'reposicion': _reposicion,
        'fechaDisplay': DateFormat('dd/MM/yyyy').format(_fechaInspeccion),
        'ubicacion': widget.productLocation,
      });

      final productRef = productsRef.doc(widget.productId);
      final productSnap = await productRef.get();
      final productData = productSnap.data() ?? {};
      final frecuencia = _parseFrecuenciaMeses(productData['frecuenciaMantenimientoMeses']);
      final fechaProximo =
          frecuencia != null ? _addMonthsDouble(_fechaInspeccion, frecuencia) : null;

      final updateData = <String, dynamic>{
        'estado': _nuevoEstado.toLowerCase(),
        'estadoOperativo': _nuevoEstado.toLowerCase(),
        'condicionFisica': _condicionFisica.toLowerCase(),
        'fechaUltimaInspeccion': fechaInspeccion,
        'nivelCriticidad': _parseInt(_nivelCriticidadCtrl.text),
        'impactoFalla': _impactoFallaCtrl.text.trim(),
        'riesgoNormativo': _riesgoNormativoCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (fechaProximo != null) {
        updateData['fechaProximoMantenimiento'] = Timestamp.fromDate(fechaProximo);
      }
      if (costoEstimado != null) {
        // Acumula el costo de mantenimiento de forma atómica.
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
        title: const Text("Generar Reporte", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2C3E50),
        iconTheme: const IconThemeData(color: Colors.white),
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
            
            // Usamos el nuevo helper que acepta controller
            _buildTextField(
              controller: _tipoReporteCtrl, // Asignamos controlador
              label: "Tipo de Reporte*",
              hint: "EJ: Mantenimiento Correctivo",
            ),
            
            _buildReadOnlyField("Activo*", "${widget.productName}\n${widget.productCategory}"),
            _buildReadOnlyField(
              "Ubicación",
              "Bloque: ${widget.productLocation['bloque'] ?? '--'} - Nivel: ${widget.productLocation['nivel'] ?? widget.productLocation['piso'] ?? '--'}",
            ),
            _buildReadOnlyField("Categoría", widget.productCategory),
            _buildReadOnlyField("Estado Actual", widget.initialStatus.toUpperCase()),

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
            _buildTextField(
              controller: _responsableCtrl,
              label: "Responsable",
              hint: "Nombre del responsable",
            ),
            
            _buildTextField(
              controller: _descripcionCtrl, // Asignamos controlador
              label: "Descripción del Reporte*",
              hint: "Describa el problema o la tarea realizada...",
              maxLines: 4,
            ),
            
            _buildSegmentedControl(
              label: "Estado*",
              options: const ['OPERATIVO', 'FUERA DE SERVICIO', 'DEFECTUOSO'],
              value: _nuevoEstado,
              onChanged: (newValue) => setState(() => _nuevoEstado = newValue),
            ),
            
            _buildSegmentedControl(
              label: "Reposición",
              options: const ['NO', 'SI'],
              value: _reposicion,
              onChanged: (newValue) => setState(() => _reposicion = newValue),
            ),

            _buildDropdownField(
              label: "Condición Física",
              value: _condicionFisica,
              items: const ['buena', 'regular', 'mala'],
              onChanged: (value) => setState(() => _condicionFisica = value ?? _condicionFisica),
            ),
            _buildTextField(
              controller: _nivelCriticidadCtrl,
              label: "Nivel de Criticidad",
              hint: "EJ: 3",
              keyboardType: TextInputType.number,
            ),
            _buildTextField(
              controller: _impactoFallaCtrl,
              label: "Impacto de Falla",
              hint: "EJ: Medio",
            ),
            _buildTextField(
              controller: _riesgoNormativoCtrl,
              label: "Riesgo Normativo",
              hint: "EJ: Bajo",
            ),

            // Campo Encargado (Ya usaba controller, solo ajustamos el widget)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: TextFormField(
                controller: _encargadoCtrl,
                decoration: const InputDecoration(
                  labelText: "Encargado*",
                  hintText: "Cargando...",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  filled: true,
                  fillColor: Color(0xFFF5F6FA),
                  suffixIcon: Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                ),
                validator: (value) => (value == null || value.isEmpty) ? 'Campo requerido' : null,
                enabled: !_isSaving, // Bloquear si guarda
                readOnly: true, // Preferiblemente solo lectura si es automático
              ),
            ),
            
            _buildTextField(
              controller: _comentariosCtrl, // Asignamos controlador
              label: "Acciones Tomadas / Comentarios",
              hint: "Añada comentarios sobre las acciones tomadas o la solución...",
              maxLines: 3,
              isRequired: false, // Hacemos este opcional
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
                    backgroundColor: const Color(0xFF3498DB),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    disabledBackgroundColor: const Color(0xFF3498DB).withOpacity(0.6),
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

  // --- 3. HELPER DE TEXTFIELD MODIFICADO PARA USAR CONTROLLER ---
  Widget _buildTextField({
    required TextEditingController controller, // Ahora el controlador es obligatorio
    required String label, 
    required String hint, 
    int maxLines = 1, 
    bool isRequired = true,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller, // Conectamos el controlador
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

  DateTime _addMonths(DateTime date, int months) {
    final newYear = date.year + ((date.month - 1 + months) ~/ 12);
    final newMonth = ((date.month - 1 + months) % 12) + 1;
    final day = date.day;
    final lastDay = DateTime(newYear, newMonth + 1, 0).day;
    final newDay = day > lastDay ? lastDay : day;
    return DateTime(newYear, newMonth, newDay);
  }

  DateTime _addMonthsDouble(DateTime date, double months) {
    final wholeMonths = months.floor();
    final fraction = months - wholeMonths;
    final baseDate = _addMonths(date, wholeMonths);
    // Aproximamos la fracción del mes usando 30 días.
    final extraDays = (fraction * 30).round();
    return baseDate.add(Duration(days: extraDays));
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
            .map((item) => DropdownMenuItem(value: item, child: Text(item.toUpperCase())))
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
                        color: isSelected ? const Color(0xFF3498DB) : Colors.white,
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
                        option,
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
}
