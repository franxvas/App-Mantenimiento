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
  final String disciplinaKey;
  final String disciplinaLabel;
  final String tipo;
  final String filenameDefault;
  final List<ParametrosSchemaColumn> columns;

  const ParametrosSchemaDefinition({
    required this.disciplinaKey,
    required this.disciplinaLabel,
    required this.tipo,
    required this.filenameDefault,
    required this.columns,
  });

  String get id => '${disciplinaKey}_$tipo';

  Map<String, dynamic> toMap() {
    return {
      'disciplina': disciplinaLabel,
      'disciplinaKey': disciplinaKey,
      'tipo': tipo,
      'filenameDefault': filenameDefault,
      'columns': columns.map((column) => column.toMap()).toList(),
      'aliases': {},
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
    final schemasRef = _firestore.collection('parametros_schemas').withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        );
    final datasetsRef = _firestore.collection('parametros_datasets').withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        );

    for (final definition in definitions) {
      final schemaRef = schemasRef.doc(definition.id);
      final schemaSnap = await schemaRef.get();
      if (!schemaSnap.exists) {
        batch.set(schemaRef, definition.toMap());
        hasChanges = true;
      } else {
        batch.set(schemaRef, definition.toMap(), SetOptions(merge: true));
        hasChanges = true;
      }

      final datasetRef = datasetsRef.doc(definition.id);
      final datasetSnap = await datasetRef.get();
      if (!datasetSnap.exists) {
        batch.set(
          datasetRef,
          {
            'disciplina': definition.disciplinaLabel,
            'disciplinaKey': definition.disciplinaKey,
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
    return _firestore
        .collection('parametros_schemas')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        )
        .doc('${disciplina}_$tipo')
        .get();
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
        key: 'idActivo',
        displayName: 'ID_Activo',
        order: 0,
        type: 'text',
        required: true,
      ),
      ParametrosSchemaColumn(
        key: 'disciplina',
        displayName: 'Disciplina',
        order: 1,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'categoriaActivo',
        displayName: 'Categoria_Activo',
        order: 2,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'tipoActivo',
        displayName: 'Tipo_Activo',
        order: 3,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'marca',
        displayName: 'Marca',
        order: 4,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'modelo',
        displayName: 'Modelo',
        order: 5,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'descripcion',
        displayName: 'Descripcion_Activo',
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
        key: 'nivel',
        displayName: 'Nivel',
        order: 8,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'espacio',
        displayName: 'Espacio',
        order: 9,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'estadoOperativo',
        displayName: 'Estado_Operativo',
        order: 10,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'condicionFisica',
        displayName: 'Condicion_Fisica',
        order: 11,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'nivelCriticidad',
        displayName: 'Nivel_Criticidad',
        order: 12,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'riesgoNormativo',
        displayName: 'Riesgo_Normativo',
        order: 13,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'accionRecomendada',
        displayName: 'Accion_Recomendada',
        order: 14,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'costoEstimado',
        displayName: 'Costo_Estimado',
        order: 15,
        type: 'number',
      ),
      ParametrosSchemaColumn(
        key: 'fechaUltimaInspeccion',
        displayName: 'Fecha_Ultima_Inspeccion',
        order: 16,
        type: 'date',
      ),
    ];

    const reportesColumns = [
      ParametrosSchemaColumn(
        key: 'idReporte',
        displayName: 'ID_Reporte',
        order: 0,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'idActivo',
        displayName: 'ID_Activo',
        order: 1,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'disciplina',
        displayName: 'Disciplina',
        order: 2,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'fechaInspeccion',
        displayName: 'Fecha_Inspeccion',
        order: 3,
        type: 'date',
      ),
      ParametrosSchemaColumn(
        key: 'tipoMantenimiento',
        displayName: 'Tipo_Mantenimiento',
        order: 4,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'estadoOperativo',
        displayName: 'Estado_Operativo',
        order: 5,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'condicionFisica',
        displayName: 'Condicion_Fisica',
        order: 6,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'nivelCriticidad',
        displayName: 'Nivel_Criticidad',
        order: 7,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'riesgoNormativo',
        displayName: 'Riesgo_Normativo',
        order: 8,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'accionRecomendada',
        displayName: 'Accion_Recomendada',
        order: 9,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'costoEstimado',
        displayName: 'Costo_Estimado',
        order: 10,
        type: 'number',
      ),
      ParametrosSchemaColumn(
        key: 'descripcion',
        displayName: 'Descripcion_Reporte',
        order: 11,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'responsable',
        displayName: 'Responsable_Reporte',
        order: 12,
        type: 'text',
      ),
    ];

    const disciplinas = [
      'electricas',
      'arquitectura',
      'sanitarias',
      'estructuras',
      'mecanica',
      'mobiliarios',
    ];

    return disciplinas
        .expand(
          (disciplina) {
            return [
              ParametrosSchemaDefinition(
                disciplinaKey: disciplina,
                disciplinaLabel: _labelFor(disciplina),
                tipo: 'base',
                filenameDefault: _filenameFor(disciplina, 'base'),
                columns: baseColumns,
              ),
              ParametrosSchemaDefinition(
                disciplinaKey: disciplina,
                disciplinaLabel: _labelFor(disciplina),
                tipo: 'reportes',
                filenameDefault: _filenameFor(disciplina, 'reportes'),
                columns: reportesColumns,
              ),
            ];
          },
        )
        .toList();
  }

  static String _filenameFor(String disciplina, String tipo) {
    final label = _labelFor(disciplina);
    final tipoLabel = tipo == 'base' ? 'Base' : 'Reportes';
    return '${label}_${tipoLabel}_ES.xlsx';
  }

  static String _labelFor(String disciplina) {
    return disciplina[0].toUpperCase() + disciplina.substring(1);
  }
}
