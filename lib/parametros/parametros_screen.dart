import 'package:flutter/material.dart';

import '../services/parametros_schema_service.dart';
import 'parametros_viewer_screen.dart';

typedef DisciplinaOption = ({
  String key,
  String label,
  String disciplinaValue,
  bool enabled
});

class ParametrosScreen extends StatefulWidget {
  const ParametrosScreen({super.key});

  @override
  State<ParametrosScreen> createState() => _ParametrosScreenState();
}

class _ParametrosScreenState extends State<ParametrosScreen> {
  final List<DisciplinaOption> _options = const [
    (key: 'electricas', label: 'Eléctricas', disciplinaValue: 'Electricas', enabled: true),
    (key: 'arquitectura', label: 'Arquitectura', disciplinaValue: 'Arquitectura', enabled: true),
    (key: 'sanitarias', label: 'Sanitarias', disciplinaValue: 'Sanitarias', enabled: true),
    (key: 'estructuras', label: 'Estructuras', disciplinaValue: 'Estructuras', enabled: true),
  ];

  final _schemaService = ParametrosSchemaService();

  @override
  void initState() {
    super.initState();
    _schemaService.seedSchemasIfMissing();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Parámetros", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2C3E50),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.separated(
          itemCount: _options.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final option = _options[index];
            return _DisciplinaCard(
              option: option,
              onOpen: () => _openDisciplina(context, option),
            );
          },
        ),
      ),
    );
  }

  void _openDisciplina(BuildContext context, DisciplinaOption option) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParametrosDisciplinaScreen(
          disciplinaKey: option.key,
          disciplinaLabel: option.disciplinaValue,
          disciplinaTitle: option.label,
        ),
      ),
    );
  }
}

class _DisciplinaCard extends StatelessWidget {
  final DisciplinaOption option;
  final VoidCallback onOpen;

  const _DisciplinaCard({
    required this.option,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onOpen,
        title: Text(option.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class ParametrosDisciplinaScreen extends StatelessWidget {
  final String disciplinaKey;
  final String disciplinaLabel;
  final String disciplinaTitle;

  const ParametrosDisciplinaScreen({
    super.key,
    required this.disciplinaKey,
    required this.disciplinaLabel,
    required this.disciplinaTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(disciplinaTitle, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2C3E50),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
          disciplinaKey: disciplinaKey,
          disciplinaLabel: disciplinaLabel,
          tipo: tipo,
        ),
      ),
    );
  }
}

class _DisciplinaCard extends StatelessWidget {
  final DisciplinaOption option;
  final void Function(String tipo) onOpenViewer;

  const _DisciplinaCard({
    required this.option,
    required this.onOpenViewer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(option.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onOpenViewer('base'),
                    icon: const Icon(Icons.table_view),
                    label: const Text('Ver Base'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3498DB),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onOpenViewer('reportes'),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Ver Reportes'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
