import 'package:cloud_firestore/cloud_firestore.dart';

import 'parametros_schema_service.dart';

class ParametrosDatasetService {
  ParametrosDatasetService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> createProductoWithDataset({
    required DocumentReference<Map<String, dynamic>> productRef,
    required Map<String, dynamic> productData,
    required String disciplina,
    required List<ParametrosSchemaColumn> columns,
  }) async {
    final batch = _firestore.batch();
    final datasetRef = _datasetRef(disciplina, 'base');
    final rowRef = datasetRef.collection('rows').doc(productRef.id);
    final rowData = _buildRowFromProducto(productRef.id, productData, columns);

    batch.set(productRef, productData);
    batch.set(rowRef, rowData);
    batch.set(
      datasetRef,
      {
        'disciplina': disciplina,
        'tipo': 'base',
        'schemaRef': 'parametros_schemas/${disciplina}_base',
        'rowCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> updateProductoWithDataset({
    required DocumentReference<Map<String, dynamic>> productRef,
    required Map<String, dynamic> productData,
    required String disciplina,
    required List<ParametrosSchemaColumn> columns,
    String? previousDisciplina,
    Map<String, dynamic>? productUpdateData,
  }) async {
    final batch = _firestore.batch();
    final rowData = _buildRowFromProducto(productRef.id, productData, columns);

    batch.update(productRef, productUpdateData ?? productData);

    if (previousDisciplina != null && previousDisciplina != disciplina) {
      final previousDataset = _datasetRef(previousDisciplina, 'base');
      final previousRow = previousDataset.collection('rows').doc(productRef.id);
      batch.delete(previousRow);
      batch.set(
        previousDataset,
        {
          'rowCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final newDataset = _datasetRef(disciplina, 'base');
      final newRow = newDataset.collection('rows').doc(productRef.id);
      batch.set(newRow, rowData);
      batch.set(
        newDataset,
        {
          'disciplina': disciplina,
          'tipo': 'base',
          'schemaRef': 'parametros_schemas/${disciplina}_base',
          'rowCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } else {
      final datasetRef = _datasetRef(disciplina, 'base');
      final rowRef = datasetRef.collection('rows').doc(productRef.id);
      batch.set(rowRef, rowData, SetOptions(merge: true));
      batch.set(
        datasetRef,
        {
          'disciplina': disciplina,
          'tipo': 'base',
          'schemaRef': 'parametros_schemas/${disciplina}_base',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<void> deleteProductoWithDataset({
    required String productId,
    required String disciplina,
  }) async {
    final batch = _firestore.batch();
    final productRef = _firestore.collection('productos').doc(productId);
    final datasetRef = _datasetRef(disciplina, 'base');
    final rowRef = datasetRef.collection('rows').doc(productId);

    batch.delete(productRef);
    batch.delete(rowRef);
    batch.set(
      datasetRef,
      {
        'rowCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> renameProductoWithDataset({
    required String oldProductId,
    required String newProductId,
    required Map<String, dynamic> productData,
    required String disciplina,
    required List<ParametrosSchemaColumn> columns,
  }) async {
    final batch = _firestore.batch();
    final datasetRef = _datasetRef(disciplina, 'base');
    final oldRowRef = datasetRef.collection('rows').doc(oldProductId);
    final newRowRef = datasetRef.collection('rows').doc(newProductId);
    final rowData = _buildRowFromProducto(newProductId, productData, columns);

    batch.set(newRowRef, rowData);
    batch.delete(oldRowRef);
    batch.set(
      datasetRef,
      {
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  DocumentReference<Map<String, dynamic>> _datasetRef(String disciplina, String tipo) {
    return _firestore.collection('parametros_datasets').doc('${disciplina}_$tipo');
  }

  Map<String, dynamic> _buildRowFromProducto(
    String productId,
    Map<String, dynamic> productData,
    List<ParametrosSchemaColumn> columns,
  ) {
    final attrs = (productData['attrs'] as Map<String, dynamic>?) ?? {};
    final ubicacion = (productData['ubicacion'] as Map<String, dynamic>?) ?? {};
    final values = <String, String>{};

    String resolveValue(String key) {
      if (key == 'idActivo') {
        return _stringify(productId);
      }
      if (key == 'tipoActivo') {
        return _stringify(productData['nombre'] ?? productData['nombreProducto']);
      }
      if (key == 'estadoOperativo') {
        return _stringify(productData['estado']);
      }
      final value = attrs[key] ?? productData[key];
      return _stringify(value);
    }

    final row = <String, dynamic>{
      'id': productId,
      'nombre': _stringify(productData['nombre']),
      'estado': _stringify(productData['estado']),
      'nivel': _stringify(productData['nivel'] ?? productData['piso'] ?? ubicacion['nivel'] ?? ubicacion['piso']),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    for (final column in columns) {
      if (_directKeys.contains(column.key)) {
        continue;
      }
      values[column.key] = resolveValue(column.key);
    }

    row['values'] = values;
    return row;
  }

  String _stringify(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    return value.toString();
  }

  static const Set<String> _directKeys = {
    'id',
    'nombre',
    'nivel',
    'estado',
  };
}
