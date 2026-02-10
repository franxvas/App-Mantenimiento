import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/parametros_schema_service.dart';
import '../services/audit_service.dart';
import 'parametros_import_screen.dart';
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
    (key: 'mecanica', label: 'Mecánica', disciplinaValue: 'Mecanica', enabled: true),
    (key: 'mobiliarios', label: 'Mobiliarios', disciplinaValue: 'Mobiliarios', enabled: true),
  ];

  final _schemaService = ParametrosSchemaService();
  final _firestore = FirebaseFirestore.instance;
  final Set<String> _deletingDisciplinas = <String>{};

  @override
  void initState() {
    super.initState();
    _schemaService.seedSchemasIfMissing();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Parámetros"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.separated(
          itemCount: _options.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final option = _options[index];
            return _ParametrosDisciplinaCard(
              option: option,
              onOpenViewer: (tipo) => _openViewer(context, option, tipo),
              onOpenImport: () => _openImport(context, option),
              onDeleteAll: () => _confirmAndDeleteAll(context, option),
              isDeleting: _deletingDisciplinas.contains(option.key),
            );
          },
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, DisciplinaOption option, String tipo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParametrosViewerScreen(
          disciplinaKey: option.key,
          disciplinaLabel: option.disciplinaValue,
          tipo: tipo,
        ),
      ),
    );
  }

  void _openImport(BuildContext context, DisciplinaOption option) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParametrosImportScreen(
          disciplinaKey: option.key,
          disciplinaLabel: option.label,
        ),
      ),
    );
  }

  Future<void> _confirmAndDeleteAll(BuildContext context, DisciplinaOption option) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar borrado total'),
          content: Text(
            'Se eliminarán TODOS los activos de ${option.label} y todos sus reportes asociados. '
            'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirmar borrado'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    if (!mounted) return;

    setState(() => _deletingDisciplinas.add(option.key));
    try {
      final result = await _deleteAllForDisciplina(option.key);
      await AuditService.logEvent(
        action: 'asset.bulk_delete',
        message: 'eliminó todos los activos de ${option.label} desde parámetros',
        disciplina: option.key,
        meta: {
          'source': 'parametros.delete_all',
          'deletedAssets': result.deletedAssets,
          'deletedReports': result.deletedReports,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Borrado completado: ${result.deletedAssets} activos y ${result.deletedReports} reportes.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al borrar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingDisciplinas.remove(option.key));
      }
    }
  }

  Future<({int deletedAssets, int deletedReports})> _deleteAllForDisciplina(String disciplinaKey) async {
    final productsQuery = await _firestore
        .collection('productos')
        .where('disciplina', isEqualTo: disciplinaKey)
        .get();

    int deletedAssets = 0;
    int deletedReports = 0;
    WriteBatch? batch;
    int batchOps = 0;

    Future<void> commitIfNeeded({bool force = false}) async {
      if (batch == null || batchOps == 0) return;
      if (!force && batchOps < 400) return;
      await batch!.commit();
      batch = null;
      batchOps = 0;
    }

    void enqueueDelete(DocumentReference ref) {
      batch ??= _firestore.batch();
      batch!.delete(ref);
      batchOps += 1;
    }

    for (final productDoc in productsQuery.docs) {
      final productId = productDoc.id;

      final reportsSnapshot = await _firestore
          .collection('productos')
          .doc(productId)
          .collection('reportes')
          .get();

      for (final reportDoc in reportsSnapshot.docs) {
        enqueueDelete(reportDoc.reference);
        enqueueDelete(_firestore.collection('reportes').doc(reportDoc.id));
        deletedReports += 1;
        await commitIfNeeded();
      }

      enqueueDelete(_firestore.collection('productos').doc(productId));
      enqueueDelete(_firestore.collection('parametros_datasets').doc('${disciplinaKey}_base').collection('rows').doc(productId));
      deletedAssets += 1;
      await commitIfNeeded();
    }

    if (deletedAssets > 0) {
      batch ??= _firestore.batch();
      batch!.set(
        _firestore.collection('parametros_datasets').doc('${disciplinaKey}_base'),
        {
          'rowCount': FieldValue.increment(-deletedAssets),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      batchOps += 1;
    }

    await commitIfNeeded(force: true);
    return (deletedAssets: deletedAssets, deletedReports: deletedReports);
  }
}

class _ParametrosDisciplinaCard extends StatelessWidget {
  final DisciplinaOption option;
  final void Function(String tipo) onOpenViewer;
  final VoidCallback onOpenImport;
  final VoidCallback onDeleteAll;
  final bool isDeleting;

  const _ParametrosDisciplinaCard({
    required this.option,
    required this.onOpenViewer,
    required this.onOpenImport,
    required this.onDeleteAll,
    this.isDeleting = false,
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
                    onPressed: isDeleting ? null : () => onOpenViewer('base'),
                    icon: const Icon(Icons.table_view),
                    label: const Text('Ver Base'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isDeleting ? null : () => onOpenViewer('reportes'),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Ver Reportes'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isDeleting ? null : onOpenImport,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Importar'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isDeleting ? null : onDeleteAll,
                    icon: isDeleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.delete_forever),
                    label: Text(isDeleting ? 'Borrando...' : 'Borrar Todo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
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
