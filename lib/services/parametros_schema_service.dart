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
        key: 'bloque',
        displayName: 'Bloque',
        order: 4,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'nivel',
        displayName: 'Nivel',
        order: 5,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'espacio',
        displayName: 'Espacio',
        order: 6,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'estadoOperativo',
        displayName: 'Estado_Operativo',
        order: 7,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'condicionFisica',
        displayName: 'Condicion_Fisica',
        order: 8,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'fechaUltimaInspeccion',
        displayName: 'Fecha_Ultima_Inspeccion',
        order: 9,
        type: 'date',
      ),
      ParametrosSchemaColumn(
        key: 'nivelCriticidad',
        displayName: 'Nivel_Criticidad',
        order: 10,
        type: 'number',
      ),
      ParametrosSchemaColumn(
        key: 'impactoFalla',
        displayName: 'Impacto_Falla',
        order: 11,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'riesgoNormativo',
        displayName: 'Riesgo_Normativo',
        order: 12,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'frecuenciaMantenimientoMeses',
        displayName: 'Frecuencia_Mantenimiento_Meses',
        order: 13,
        type: 'number',
      ),
      ParametrosSchemaColumn(
        key: 'fechaProximoMantenimiento',
        displayName: 'Fecha_Proximo_Mantenimiento',
        order: 14,
        type: 'date',
      ),
      ParametrosSchemaColumn(
        key: 'costoMantenimiento',
        displayName: 'Costo_Mantenimiento',
        order: 15,
        type: 'number',
      ),
      ParametrosSchemaColumn(
        key: 'costoReemplazo',
        displayName: 'Costo_Reemplazo',
        order: 16,
        type: 'number',
      ),
      ParametrosSchemaColumn(
        key: 'observaciones',
        displayName: 'Observaciones',
        order: 17,
        type: 'text',
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
        key: 'estadoDetectado',
        displayName: 'Estado_Detectado',
        order: 4,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'riesgoElectrico',
        displayName: 'Riesgo_Electrico',
        order: 5,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'accionRecomendada',
        displayName: 'Accion_Recomendada',
        order: 6,
        type: 'text',
      ),
      ParametrosSchemaColumn(
        key: 'costoEstimado',
        displayName: 'Costo_Estimado',
        order: 7,
        type: 'number',
      ),
      ParametrosSchemaColumn(
        key: 'responsable',
        displayName: 'Responsable',
        order: 8,
        type: 'text',
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
          ],
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
