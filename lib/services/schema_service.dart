import 'package:cloud_firestore/cloud_firestore.dart';

class SchemaField {
  final String key;
  final String displayName;
  final String type;
  final bool required;
  final int order;

  const SchemaField({
    required this.key,
    required this.displayName,
    required this.type,
    required this.required,
    required this.order,
  });

  factory SchemaField.fromMap(Map<String, dynamic> data) {
    return SchemaField(
      key: data['key'] ?? '',
      displayName: data['displayName'] ?? data['key'] ?? '',
      type: data['type'] ?? 'string',
      required: data['required'] ?? false,
      order: data['order'] ?? 0,
    );
  }
}

class SchemaSnapshot {
  final List<SchemaField> fields;
  final Map<String, String> aliases;

  const SchemaSnapshot({required this.fields, required this.aliases});
}

class SchemaService {
  SchemaService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<SchemaSnapshot?> streamSchema(String disciplina) {
    return _firestore
        .collection('parametros_schemas')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        )
        .doc(_schemaIdForDisciplina(disciplina))
        .snapshots()
        .map((doc) => _mapSnapshot(doc));
  }

  Future<SchemaSnapshot?> fetchSchema(String disciplina) async {
    final doc = await _firestore
        .collection('parametros_schemas')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        )
        .doc(_schemaIdForDisciplina(disciplina))
        .get();
    return _mapSnapshot(doc);
  }

  SchemaSnapshot? _mapSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists) {
      return null;
    }
    final data = doc.data() ?? {};
    final rawFields = (data['columns'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(SchemaField.fromMap)
        .toList();
    rawFields.sort((a, b) => a.order.compareTo(b.order));
    final rawAliases = (data['aliases'] as Map<String, dynamic>? ?? {})
        .map((key, value) => MapEntry(key, value.toString()));
    return SchemaSnapshot(fields: rawFields, aliases: rawAliases);
  }

  String resolveAlias(Map<String, String> aliases, String key) {
    return aliases[key] ?? key;
  }

  String _schemaIdForDisciplina(String disciplina) {
    return '${disciplina}_base';
  }
}
