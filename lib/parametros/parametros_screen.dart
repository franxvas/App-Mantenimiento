import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ParametrosScreen extends StatelessWidget {
  const ParametrosScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _parametrosStream() {
    return FirebaseFirestore.instance
        .collection('parametros_excels')
        .orderBy('disciplina')
        .orderBy('tipo')
        .snapshots();
  }

  String _formatGeneratedAt(Timestamp? generatedAt) {
    if (generatedAt == null) {
      return 'Pendiente';
    }
    final DateTime date = generatedAt.toDate();
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String _resolveFileName(String? storagePath, String docId) {
    if (storagePath == null || storagePath.isEmpty) {
      return 'parametro_$docId.xlsx';
    }
    final String baseName = p.basename(storagePath);
    return baseName.isEmpty ? 'parametro_$docId.xlsx' : baseName;
  }

  Future<File> _downloadFile({
    required String storagePath,
    required String fileName,
  }) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final Directory targetDir = Directory(p.join(directory.path, 'parametros'));
    if (!targetDir.existsSync()) {
      await targetDir.create(recursive: true);
    }
    final File localFile = File(p.join(targetDir.path, fileName));
    final Reference ref = FirebaseStorage.instance.ref(storagePath);
    await ref.writeToFile(localFile);
    return localFile;
  }

  Future<void> _handleOpen({
    required BuildContext context,
    required String storagePath,
    required String fileName,
  }) async {
    final File file = await _downloadFile(
      storagePath: storagePath,
      fileName: fileName,
    );
    await OpenFilex.open(file.path);
  }

  Future<void> _handleDownload({
    required BuildContext context,
    required String storagePath,
    required String fileName,
  }) async {
    final File file = await _downloadFile(
      storagePath: storagePath,
      fileName: fileName,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Archivo guardado en ${file.path}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'Parámetros',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2C3E50),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _parametrosStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Ocurrió un error al cargar los parámetros.'),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('No hay parámetros disponibles.'),
            );
          }

          final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
              grouped = {};
          for (final doc in docs) {
            final data = doc.data();
            final String disciplina =
                (data['disciplina'] as String?)?.trim().isNotEmpty == true
                    ? (data['disciplina'] as String).trim()
                    : 'Sin disciplina';
            grouped.putIfAbsent(disciplina, () => []).add(doc);
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: grouped.keys.length,
            itemBuilder: (context, index) {
              final String disciplina = grouped.keys.elementAt(index);
              final items = grouped[disciplina] ?? [];
              return _DisciplinaSection(
                disciplina: disciplina,
                items: items,
                onOpen: (storagePath, fileName) => _handleOpen(
                  context: context,
                  storagePath: storagePath,
                  fileName: fileName,
                ),
                onDownload: (storagePath, fileName) => _handleDownload(
                  context: context,
                  storagePath: storagePath,
                  fileName: fileName,
                ),
                formatGeneratedAt: _formatGeneratedAt,
                resolveFileName: _resolveFileName,
              );
            },
          );
        },
      ),
    );
  }
}

class _DisciplinaSection extends StatelessWidget {
  final String disciplina;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> items;
  final String Function(Timestamp? generatedAt) formatGeneratedAt;
  final String Function(String? storagePath, String docId) resolveFileName;
  final Future<void> Function(String storagePath, String fileName) onOpen;
  final Future<void> Function(String storagePath, String fileName) onDownload;

  const _DisciplinaSection({
    required this.disciplina,
    required this.items,
    required this.formatGeneratedAt,
    required this.resolveFileName,
    required this.onOpen,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(
            disciplina,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF34495E),
            ),
          ),
        ),
        ...items.map((doc) {
          final data = doc.data();
          final String tipo = (data['tipo'] as String?)?.trim().isNotEmpty == true
              ? (data['tipo'] as String).trim()
              : 'Sin tipo';
          final String? storagePath = data['storagePath'] as String?;
          final Timestamp? generatedAt = data['generatedAt'] as Timestamp?;
          final bool hasFile =
              storagePath != null && storagePath.trim().isNotEmpty;
          final String estadoTexto =
              hasFile ? formatGeneratedAt(generatedAt) : 'Pendiente';
          final String fileName = resolveFileName(storagePath, doc.id);

          return Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tipo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hasFile ? 'Generado: $estadoTexto' : 'Estado: $estadoTexto',
                    style: const TextStyle(
                      color: Color(0xFF7F8C8D),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: hasFile
                              ? () => onOpen(storagePath!, fileName)
                              : null,
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Abrir'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: hasFile
                              ? () => onDownload(storagePath!, fileName)
                              : null,
                          icon: const Icon(Icons.download),
                          label: const Text('Descargar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2C3E50),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}
