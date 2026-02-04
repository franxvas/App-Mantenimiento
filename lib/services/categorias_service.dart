import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:appmantflutter/shared/disciplinas_categorias.dart';

// Flutter necesita IconData const para permitir tree shaking de fuentes.
const Map<String, IconData> _materialIconsById = {
  'lightbulb': Icons.lightbulb,
  'smart_toy': Icons.smart_toy,
  'flash_on': Icons.flash_on,
  'format_paint': Icons.format_paint,
  'door_front_door': Icons.door_front_door,
  'view_column': Icons.view_column,
  'cyclone': Icons.cyclone,
  'water_drop': Icons.water_drop,
  'chair': Icons.chair,
  'table_restaurant': Icons.table_restaurant,
  'inventory_2': Icons.inventory_2,
  'build': Icons.build,
  'construction': Icons.construction,
  'storage': Icons.storage,
  'widgets': Icons.widgets,
};

final Map<int, String> _materialIconIdByCodePoint = {
  Icons.lightbulb.codePoint: 'lightbulb',
  Icons.smart_toy.codePoint: 'smart_toy',
  Icons.flash_on.codePoint: 'flash_on',
  Icons.format_paint.codePoint: 'format_paint',
  Icons.door_front_door.codePoint: 'door_front_door',
  Icons.view_column.codePoint: 'view_column',
  Icons.cyclone.codePoint: 'cyclone',
  Icons.water_drop.codePoint: 'water_drop',
  Icons.chair.codePoint: 'chair',
  Icons.table_restaurant.codePoint: 'table_restaurant',
  Icons.inventory_2.codePoint: 'inventory_2',
  Icons.build.codePoint: 'build',
  Icons.construction.codePoint: 'construction',
  Icons.storage.codePoint: 'storage',
  Icons.widgets.codePoint: 'widgets',
};

class CategoriaItem {
  final String id;
  final String disciplina;
  final String value;
  final String label;
  final IconData icon;

  const CategoriaItem({
    required this.id,
    required this.disciplina,
    required this.value,
    required this.label,
    required this.icon,
  });

  factory CategoriaItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final iconId = data['iconId']?.toString();
    final iconCodePoint = (data['iconCodePoint'] as num?)?.toInt();
    final iconFontFamily = data['iconFontFamily']?.toString() ?? 'MaterialIcons';
    final resolvedId = iconId ??
        (iconCodePoint != null && iconFontFamily == 'MaterialIcons'
            ? _materialIconIdByCodePoint[iconCodePoint]
            : null);
    final iconData = resolvedId != null ? (_materialIconsById[resolvedId] ?? Icons.category) : Icons.category;
    return CategoriaItem(
      id: doc.id,
      disciplina: data['disciplina']?.toString() ?? '',
      value: data['value']?.toString() ?? data['nombre']?.toString() ?? '',
      label: data['label']?.toString() ?? data['nombre']?.toString() ?? data['value']?.toString() ?? '',
      icon: iconData,
    );
  }
}

class CategoriasService {
  CategoriasService._();

  static final CategoriasService instance = CategoriasService._();

  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('categorias').withConverter<Map<String, dynamic>>(
            fromFirestore: (snapshot, _) => snapshot.data() ?? {},
            toFirestore: (data, _) => data,
          );

  final Map<String, List<CategoriaItem>> _cache = {};

  Future<void> ensureSeededForDisciplina(String disciplinaKey) async {
    final key = disciplinaKey.toLowerCase().trim();
    if (key.isEmpty) return;
    final existing = await _collection.where('disciplina', isEqualTo: key).limit(1).get();
    if (existing.docs.isNotEmpty) return;
    final defaults = categoriasPorDisciplina(key);
    if (defaults.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final item in defaults) {
      final doc = _collection.doc();
      final iconId = _iconIdFromIconData(item.icon);
      batch.set(doc, {
        'disciplina': key,
        'value': item.value,
        'label': item.label,
        if (iconId != null) 'iconId': iconId,
        'iconCodePoint': item.icon.codePoint,
        'iconFontFamily': item.icon.fontFamily,
        'iconFontPackage': item.icon.fontPackage,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Stream<List<CategoriaItem>> streamByDisciplina(String disciplinaKey) {
    final key = disciplinaKey.toLowerCase().trim();
    if (key.isEmpty) {
      return Stream.value(const <CategoriaItem>[]);
    }
    return _collection.where('disciplina', isEqualTo: key).snapshots().map((snapshot) {
      final items = snapshot.docs.map(CategoriaItem.fromDoc).toList()
        ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
      _cache[key] = items;
      return items;
    });
  }

  Future<List<CategoriaItem>> fetchByDisciplina(String disciplinaKey) async {
    final key = disciplinaKey.toLowerCase().trim();
    if (key.isEmpty) return const <CategoriaItem>[];
    await ensureSeededForDisciplina(key);
    final snapshot = await _collection.where('disciplina', isEqualTo: key).get();
    final items = snapshot.docs.map(CategoriaItem.fromDoc).toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    _cache[key] = items;
    return items;
  }

  CategoriaItem? resolveByValue(String disciplinaKey, String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final key = disciplinaKey.toLowerCase().trim();
    final list = _cache[key];
    if (list == null) return null;
    for (final item in list) {
      if (item.value == value) {
        return item;
      }
    }
    return null;
  }

  String? resolveLabel(String disciplinaKey, String? value) {
    return resolveByValue(disciplinaKey, value)?.label;
  }

  Future<bool> existsValue(String disciplinaKey, String value) async {
    final key = disciplinaKey.toLowerCase().trim();
    if (key.isEmpty || value.trim().isEmpty) return false;
    final snapshot = await _collection
        .where('disciplina', isEqualTo: key)
        .where('value', isEqualTo: value)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> createCategoria({
    required String disciplinaKey,
    required String value,
    required String label,
    required IconData icon,
  }) async {
    final key = disciplinaKey.toLowerCase().trim();
    final iconId = _iconIdFromIconData(icon);
    await _collection.add({
      'disciplina': key,
      'value': value,
      'label': label,
      if (iconId != null) 'iconId': iconId,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'iconFontPackage': icon.fontPackage,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCategoria({
    required String categoriaId,
    required String label,
    required IconData icon,
  }) async {
    final iconId = _iconIdFromIconData(icon);
    await _collection.doc(categoriaId).set({
      'label': label,
      if (iconId != null) 'iconId': iconId,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'iconFontPackage': icon.fontPackage,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteCategoria(String categoriaId) async {
    await _collection.doc(categoriaId).delete();
  }
}

String? _iconIdFromIconData(IconData icon) {
  if (icon.fontFamily != 'MaterialIcons') {
    return null;
  }
  return _materialIconIdByCodePoint[icon.codePoint];
}
