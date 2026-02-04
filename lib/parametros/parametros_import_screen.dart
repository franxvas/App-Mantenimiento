import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/parametros_import_service.dart';

class ParametrosImportScreen extends StatefulWidget {
  final String disciplinaKey;
  final String disciplinaLabel;

  const ParametrosImportScreen({
    super.key,
    required this.disciplinaKey,
    required this.disciplinaLabel,
  });

  @override
  State<ParametrosImportScreen> createState() => _ParametrosImportScreenState();
}

class _ParametrosImportScreenState extends State<ParametrosImportScreen> {
  final _importService = ParametrosImportService();

  PlatformFile? _selectedFile;
  Uint8List? _fileBytes;
  bool _overwriteEmpty = false;
  bool _dryRun = true;
  bool _isProcessing = false;
  ImportResult? _result;
  bool _lastRunDry = true;
  ImportProgress? _progress;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    if (file.bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer el archivo seleccionado.')),
      );
      return;
    }

    setState(() {
      _selectedFile = file;
      _fileBytes = file.bytes;
      _result = null;
      _progress = null;
    });
  }

  Future<void> _runImport({required bool dryRun}) async {
    if (_fileBytes == null || _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un archivo .xlsx primero.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _result = null;
      _progress = ImportProgress(stage: ImportStage.reading, processed: 0, total: 0, dryRun: dryRun);
    });

    try {
      final result = await _importService.processExcel(
        bytes: _fileBytes!,
        fileName: _selectedFile!.name,
        disciplinaKey: widget.disciplinaKey,
        dryRun: dryRun,
        overwriteEmpty: _overwriteEmpty,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _progress = progress);
        },
      );

      if (!mounted) return;
      setState(() {
        _result = result;
        _lastRunDry = dryRun;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al importar: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Base (Excel)'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Disciplina: ${widget.disciplinaLabel}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isProcessing ? null : _pickFile,
            icon: const Icon(Icons.upload_file),
            label: const Text('Seleccionar archivo (.xlsx)'),
          ),
          if (_selectedFile != null) ...[
            const SizedBox(height: 8),
            Text(
              'Archivo: ${_selectedFile!.name}',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _overwriteEmpty,
            onChanged: _isProcessing
                ? null
                : (value) {
                    setState(() {
                      _overwriteEmpty = value ?? false;
                      _result = null;
                    });
                  },
            title: const Text('Sobrescribir campos vacios'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          SwitchListTile(
            value: _dryRun,
            onChanged: _isProcessing
                ? null
                : (value) {
                    setState(() {
                      _dryRun = value;
                      _result = null;
                    });
                  },
            title: const Text('Simular importacion (no guardar)'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isProcessing || _fileBytes == null
                ? null
                : () {
                    _runImport(dryRun: _dryRun);
                  },
            child: Text(_dryRun ? 'Analizar archivo' : 'Importar'),
          ),
          if (_isProcessing) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(_progressLabel(_progress)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 24),
            _buildSummary(_result!),
            const SizedBox(height: 12),
            _buildRowChanges(_result!),
            const SizedBox(height: 12),
            _buildMessages(_result!),
          ],
          if (_result != null && _lastRunDry && !_isProcessing) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fileBytes == null
                  ? null
                  : () {
                      setState(() => _dryRun = false);
                      _runImport(dryRun: false);
                    },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirmar e Importar'),
            ),
          ],
        ],
      ),
    );
  }

  String _progressLabel(ImportProgress? progress) {
    if (progress == null) return '';
    String label;
    switch (progress.stage) {
      case ImportStage.reading:
        label = 'Leyendo archivo...';
        break;
      case ImportStage.validating:
        label = 'Validando columnas...';
        break;
      case ImportStage.processing:
        label = 'Procesando filas... ${progress.processed}/${progress.total}';
        break;
    }
    if (progress.dryRun) {
      label = '$label (Dry-run)';
    }
    return label;
  }

  Widget _buildSummary(ImportResult result) {
    final categoriaLabel = _lastRunDry ? 'Categorias a crear' : 'Categorias creadas';
    final categoriaCount = _lastRunDry ? result.categoriesPending : result.categoriesCreated;
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resumen', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Total filas: ${result.totalRows}'),
            Text('Creados: ${result.created}'),
            Text('Actualizados: ${result.updated}'),
            Text('Omitidos: ${result.skipped}'),
            Text('$categoriaLabel: $categoriaCount'),
          ],
        ),
      ),
    );
  }

  Widget _buildRowChanges(ImportResult result) {
    if (result.rowChanges.isEmpty) {
      return const SizedBox.shrink();
    }
    return ExpansionTile(
      title: const Text('Cambios por fila'),
      children: result.rowChanges.map((row) {
        final actionLabel = _actionLabel(row.action);
        final fieldsLabel = _formatFields(row.changedFields);
        final reason = row.reason != null ? '\n${row.reason}' : '';
        return ListTile(
          title: Text('$actionLabel - ${row.idActivo.isEmpty ? '(sin ID)' : row.idActivo}'),
          subtitle: Text(
            'Hoja: ${row.sheetName} - Fila: ${row.rowNumber}\n'
            'Categoria: ${row.categoria.isEmpty ? '-' : row.categoria}\n'
            'Cambios: $fieldsLabel$reason',
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMessages(ImportResult result) {
    if (result.messages.isEmpty) {
      return const SizedBox.shrink();
    }
    return ExpansionTile(
      title: const Text('Errores y advertencias'),
      children: result.messages.map((message) {
        final typeLabel = message.type == ImportMessageType.error ? 'Error' : 'Warn';
        final rowLabel = message.rowNumber != null ? message.rowNumber.toString() : '-';
        final idLabel = (message.idActivo == null || message.idActivo!.isEmpty) ? '-' : message.idActivo!;
        return ListTile(
          title: Text('$typeLabel - ${message.sheetName} - Fila $rowLabel'),
          subtitle: Text('ID_Activo: $idLabel\n${message.message}'),
        );
      }).toList(),
    );
  }

  String _actionLabel(ImportAction action) {
    switch (action) {
      case ImportAction.create:
        return 'Crear';
      case ImportAction.update:
        return 'Actualizar';
      case ImportAction.skip:
        return 'Omitir';
    }
  }

  String _formatFields(List<String> fields) {
    if (fields.isEmpty) return 'Sin cambios detectados';
    if (fields.length <= 5) return fields.join(', ');
    final visible = fields.take(5).join(', ');
    final remaining = fields.length - 5;
    return '$visible +$remaining mas';
  }
}
