import 'package:cloud_firestore/cloud_firestore.dart';

class ParametrosSchemaColumn {
  final String key;
  final String displayName;
  final int order;
  final String type;
  final bool required;

  const ParametrosSchemaColumn({
    required this.key,
    required this.displayName,
    required this.order,
    required this.type,
    this.required = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'displayName': displayName,
      'order': order,
      'type': type,
      'required': required,
    };
  }
}

class ParametrosSchemaDefinition {
  final String disciplina;
  final String tipo;
  final String filenameDefault;
  final List<ParametrosSchemaColumn> columns;

  const ParametrosSchemaDefinition({
    required this.disciplina,
    required this.tipo,
    required this.filenameDefault,
    required this.columns,
  });

  String get id => '${disciplina}_$tipo';

  Map<String, dynamic> toMap() {
    return {
      'disciplina': disciplina,
      'tipo': tipo,
      'filenameDefault': filenameDefault,
      'columns': columns.map((column) => column.toMap()).toList(),
      'aliases': {'nivel': 'piso'},
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class ParametrosSchemaService {
  ParametrosSchemaService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static bool _seeded = false;

  Future<void> seedSchemasIfMissing() async {
    if (_seeded) {
      return;
    }

    final definitions = _schemaDefinitions;
    bool hasChanges = false;
    final batch = _firestore.batch();

    for (final definition in definitions) {
      final schemaRef = _firestore.collection('parametros_schemas').doc(definition.id);
      final schemaSnap = await schemaRef.get();
      if (!schemaSnap.exists) {
        batch.set(schemaRef, definition.toMap());
        hasChanges = true;
      }

      final datasetRef = _firestore.collection('parametros_datasets').doc(definition.id);
      final datasetSnap = await datasetRef.get();
      if (!datasetSnap.exists) {
        batch.set(
          datasetRef,
          {
            'disciplina': definition.disciplina,
            'tipo': definition.tipo,
            'schemaRef': schemaRef.path,
            'rowCount': 0,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
        hasChanges = true;
      }
    }

    if (hasChanges) {
      await batch.commit();
    }

    _seeded = true;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getSchema(String disciplina, String tipo) {
    return _firestore.collection('parametros_schemas').doc('${disciplina}_$tipo').get();
  }

  Future<List<ParametrosSchemaColumn>> fetchColumns(String disciplina, String tipo) async {
    final doc = await getSchema(disciplina, tipo);
    if (!doc.exists) {
      return [];
    }
    final data = doc.data() ?? {};
    final columns = (data['columns'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(
          (map) => ParametrosSchemaColumn(
            key: map['key']?.toString() ?? '',
            displayName: map['displayName']?.toString() ?? '',
            order: map['order'] is int ? map['order'] as int : int.tryParse(map['order']?.toString() ?? '') ?? 0,
            type: map['type']?.toString() ?? 'text',
            required: map['required'] == true,
          ),
        )
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return columns;
  }

  static List<ParametrosSchemaDefinition> get _schemaDefinitions {
    const baseColumns = [
      ParametrosSchemaColumn(
        key: 'id',
        displayName: 'ID',
        order: 0,
        type: 'text',
        required: true,
      ),
      ParametrosSchemaColumn(
        key: 'nombre',
        displayName: 'Nombre',
        order: 1,
        type: 'text',
        required: true,
      ),
      ParametrosSchemaColumn(
        key: 'piso',
        displayName: 'Piso',
        order: 2,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'estado',
        displayName: 'Estado',
        order: 3,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'categoria',
        displayName: 'Categoría',
        order: 4,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'subcategoria',
        displayName: 'Subcategoría',
        order: 5,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'descripcion',
        displayName: 'Descripción',
        order: 6,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'bloque',
        displayName: 'Bloque',
        order: 7,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'area',
        displayName: 'Área',
        order: 8,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'fechaCompra',
        displayName: 'Fecha de Compra',
        order: 9,
        type: 'date',
      ),
    ];

    const disciplinas = [
      'electricas',
      'arquitectura',
      'sanitarias',
      'estructuras',
    ];

    return disciplinas
        .expand(
          (disciplina) => [
            ParametrosSchemaDefinition(
              disciplina: disciplina,
              tipo: 'base',
              filenameDefault: _filenameFor(disciplina, 'base'),
              columns: baseColumns,
            ),
            ParametrosSchemaDefinition(
              disciplina: disciplina,
              tipo: 'reportes',
              filenameDefault: _filenameFor(disciplina, 'reportes'),
              columns: baseColumns,
            ),
          ],
        )
        .toList();
  }

  static String _filenameFor(String disciplina, String tipo) {
    final label = disciplina[0].toUpperCase() + disciplina.substring(1);
    final tipoLabel = tipo == 'base' ? 'Base' : 'Reportes';
    return '${label}_${tipoLabel}_ES.xlsx';
  }
}
