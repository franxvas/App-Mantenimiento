import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class ParametrosScreen extends StatelessWidget {
  const ParametrosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Parámetros", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2C3E50),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('parametros_excels')
            .orderBy('disciplina')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text("No hay parámetros disponibles."));
          }

          final grouped = <String, List<QueryDocumentSnapshot>>{};
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final disciplina = data['disciplina'] ?? 'sin_disciplina';
            grouped.putIfAbsent(disciplina, () => []).add(doc);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: grouped.entries.map((entry) {
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key.toString().toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      ...(() {
                        final sorted = [...entry.value];
                        sorted.sort((a, b) {
                          final dataA = a.data() as Map<String, dynamic>;
                          final dataB = b.data() as Map<String, dynamic>;
                          final tipoA = (dataA['tipo'] ?? '').toString();
                          final tipoB = (dataB['tipo'] ?? '').toString();
                          return tipoA.compareTo(tipoB);
                        });
                        return sorted;
                      })().map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final filename = data['filename'] ?? doc.id;
                        final tipo = data['tipo'] ?? '';
                        final generatedAt = data['generatedAt'] as Timestamp?;
                        final generatedLabel = generatedAt != null
                            ? formatter.format(generatedAt.toDate())
                            : 'Pendiente';
                        return _ParametroItem(
                          filename: filename,
                          tipo: tipo,
                          generatedAt: generatedLabel,
                          storagePath: data['storagePath'],
                          downloadUrl: data['downloadUrl'],
                        );
                      }),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _ParametroItem extends StatelessWidget {
  final String filename;
  final String tipo;
  final String generatedAt;
  final String? storagePath;
  final String? downloadUrl;

  const _ParametroItem({
    required this.filename,
    required this.tipo,
    required this.generatedAt,
    this.storagePath,
    this.downloadUrl,
  });

  Future<void> _openOrDownload(BuildContext context, {required bool open}) async {
    try {
      final uri = await _resolveDownloadUrl();
      if (uri == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Archivo pendiente de generación.")),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final filePath = "${dir.path}/$filename";
      final file = File(filePath);
      if (!await file.exists()) {
        final bytes = await HttpClient().getUrl(Uri.parse(uri)).then((req) => req.close());
        final data = await consolidateHttpClientResponseBytes(bytes);
        await file.writeAsBytes(data, flush: true);
      }

      if (open) {
        await OpenFilex.open(filePath);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Descargado en $filePath")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al descargar: $e")),
      );
    }
  }

  Future<String?> _resolveDownloadUrl() async {
    if (downloadUrl != null && downloadUrl!.isNotEmpty) {
      return downloadUrl;
    }
    if (storagePath == null || storagePath!.isEmpty) {
      return null;
    }
    final ref = FirebaseStorage.instance.ref(storagePath);
    return ref.getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$filename (${tipo.toString().toUpperCase()})", style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text("Actualizado: $generatedAt", style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _openOrDownload(context, open: true),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text("Abrir"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3498DB)),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => _openOrDownload(context, open: false),
                icon: const Icon(Icons.download, size: 16),
                label: const Text("Descargar"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
