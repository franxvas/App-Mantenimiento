import 'package:flutter/material.dart';

import '../services/parametros_schema_service.dart';
import 'parametros_viewer_screen.dart';

typedef DisciplinaOption = ({String key, String label, bool enabled});

class ParametrosScreen extends StatefulWidget {
  const ParametrosScreen({super.key});

  @override
  State<ParametrosScreen> createState() => _ParametrosScreenState();
}

class _ParametrosScreenState extends State<ParametrosScreen> {
  final List<DisciplinaOption> _options = const [
    (key: 'electricas', label: 'Eléctricas', enabled: true),
    (key: 'arquitectura', label: 'Arquitectura', enabled: true),
    (key: 'sanitarias', label: 'Sanitarias', enabled: true),
    (key: 'estructuras', label: 'Estructuras', enabled: true),
    (key: 'mecanicas', label: 'Mecánicas', enabled: false),
    (key: 'gas', label: 'Gas', enabled: false),
  ];

  late String _selectedDisciplina;
  final _schemaService = ParametrosSchemaService();

  @override
  void initState() {
    super.initState();
    _selectedDisciplina = _options.firstWhere((option) => option.enabled).key;
    _schemaService.seedSchemasIfMissing();
  }

  @override
  Widget build(BuildContext context) {
    final disabledOptions = _options.where((option) => !option.enabled).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Parámetros", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2C3E50),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Disciplina',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _options
                  .where((option) => option.enabled)
                  .map((option) => ChoiceChip(
                        label: Text(option.label),
                        selected: _selectedDisciplina == option.key,
                        onSelected: (_) {
                          setState(() {
                            _selectedDisciplina = option.key;
                          });
                        },
                      ))
                  .toList(),
            ),
            if (disabledOptions.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Próximamente',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: disabledOptions
                    .map((option) => ChoiceChip(
                          label: Text(option.label),
                          selected: false,
                          onSelected: null,
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Acciones',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openViewer(context, tipo: 'base'),
                icon: const Icon(Icons.table_view),
                label: const Text('Ver Base'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3498DB),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openViewer(context, tipo: 'reportes'),
                icon: const Icon(Icons.description_outlined),
                label: const Text('Ver Reportes'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, {required String tipo}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParametrosViewerScreen(
          disciplina: _selectedDisciplina,
          tipo: tipo,
        ),
      ),
    );
  }
}
