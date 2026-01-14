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
  
  // Variables para Dropdowns/Selectores (estos sí se quedan como variables)
  String _nuevoEstado = 'OPERATIVO';
  String _reposicion = 'NO';
  
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
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final userData = querySnapshot.docs.first.data();
          if (mounted) {
            setState(() => _encargadoCtrl.text = userData['nombre'] ?? user.email ?? '');
          }
        } else {
          if (mounted) setState(() => _encargadoCtrl.text = user.email ?? '');
        }
      } catch (e) {
        print("Error obteniendo usuario: $e");
        if (mounted) setState(() => _encargadoCtrl.text = user.email ?? '');
      }
    }
  }

  // --- FUNCIÓN DE CONTADOR ATÓMICO ---
  Future<int> _getAndIncrementReportCounter() async {
    final counterRef = FirebaseFirestore.instance.collection('metadata').doc('counters');

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      int currentNumber;

      if (!snapshot.exists || snapshot.data() == null || snapshot.data()!['report_nro'] == null) {
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
      
      await FirebaseFirestore.instance.collection('reportes').add({
        'nro': reportNumber,
        'productId': widget.productId,
        'activo_nombre': widget.productName,
        'categoria': widget.productCategory,
        // --- 2. LEEMOS DIRECTAMENTE DEL CONTROLADOR (.text) ---
        'tipo_reporte': _tipoReporteCtrl.text.trim(), 
        'descripcion': _descripcionCtrl.text.trim(),
        'encargado': _encargadoCtrl.text.trim(),
        'comentarios': _comentariosCtrl.text.trim(),
        // -----------------------------------------------------
        'estado_anterior': widget.initialStatus,
        'estado_nuevo': _nuevoEstado,
        'reposicion': _reposicion,
        'fecha': FieldValue.serverTimestamp(),
        'fechaDisplay': DateFormat('dd/MM/yyyy').format(DateTime.now()),
        'ubicacion': widget.productLocation,
      });

      if (_nuevoEstado.toLowerCase() != widget.initialStatus.toLowerCase()) {
        await FirebaseFirestore.instance.collection('productos').doc(widget.productId).update({
          'estado': _nuevoEstado.toLowerCase(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

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
            _buildReadOnlyField("Ubicación", "Bloque: ${widget.productLocation['bloque'] ?? '--'} - Nivel: ${widget.productLocation['nivel'] ?? '--'}"),
            _buildReadOnlyField("Categoría", widget.productCategory),
            _buildReadOnlyField("Estado Actual", widget.initialStatus),
            
            _buildTextField(
              controller: _descripcionCtrl, // Asignamos controlador
              label: "Descripción del Reporte*",
              hint: "Describa el problema o la tarea realizada...",
              maxLines: 4,
            ),
            
            _buildSegmentedControl(
              label: "Estado*",
              options: const ['OPERATIVO', 'FUERA DE SERVICIO'],
              value: _nuevoEstado,
              onChanged: (newValue) => setState(() => _nuevoEstado = newValue),
            ),
            
            _buildSegmentedControl(
              label: "Reposición",
              options: const ['NO', 'SI'],
              value: _reposicion,
              onChanged: (newValue) => setState(() => _reposicion = newValue),
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
