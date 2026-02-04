import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../parametros/parametros_templates.dart';
import '../shared/text_formatters.dart';
import 'categorias_service.dart';

enum ImportAction { create, update, skip }

enum ImportMessageType { warning, error }

enum ImportStage { reading, validating, processing }

class ImportProgress {
  final ImportStage stage;
  final int processed;
  final int total;
  final bool dryRun;

  const ImportProgress({
    required this.stage,
    required this.processed,
    required this.total,
    required this.dryRun,
  });
}

class ImportMessage {
  final ImportMessageType type;
  final String sheetName;
  final int? rowNumber;
  final String? idActivo;
  final String message;

  const ImportMessage({
    required this.type,
    required this.sheetName,
    required this.message,
    this.rowNumber,
    this.idActivo,
  });
}

class ImportRowChange {
  final String sheetName;
  final int rowNumber;
  final String idActivo;
  final ImportAction action;
  final String categoria;
  final List<String> changedFields;
  final String? reason;

  const ImportRowChange({
    required this.sheetName,
    required this.rowNumber,
    required this.idActivo,
    required this.action,
    required this.categoria,
    required this.changedFields,
    this.reason,
  });
}

class ImportResult {
  final int totalRows;
  final int created;
  final int updated;
  final int skipped;
  final int categoriesCreated;
  final int categoriesPending;
  final List<ImportRowChange> rowChanges;
  final List<ImportMessage> messages;

  const ImportResult({
    required this.totalRows,
    required this.created,
    required this.updated,
    required this.skipped,
    required this.categoriesCreated,
    required this.categoriesPending,
    required this.rowChanges,
    required this.messages,
  });
}

class ParametrosImportService {
  ParametrosImportService({FirebaseFirestore? firestore, CategoriasService? categoriasService})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _categoriasService = categoriasService ?? CategoriasService.instance;

  final FirebaseFirestore _firestore;
  final CategoriasService _categoriasService;

  Future<ImportResult> processExcel({
    required Uint8List bytes,
    required String fileName,
    required String disciplinaKey,
    required bool dryRun,
    required bool overwriteEmpty,
    void Function(ImportProgress progress)? onProgress,
  }) async {
    onProgress?.call(ImportProgress(stage: ImportStage.reading, processed: 0, total: 0, dryRun: dryRun));
    final excel = Excel.decodeBytes(bytes);

    onProgress?.call(ImportProgress(stage: ImportStage.validating, processed: 0, total: 0, dryRun: dryRun));

    final expectedHeaders = headersFor(disciplinaKey, 'base');
    final expectedNormalized = expectedHeaders.map(_normalizeToken).toSet();

    final categorias = await _categoriasService.fetchByDisciplina(disciplinaKey);
    final categoriaIndex = _CategoryIndex.fromItems(categorias);
    final pendingCategorias = <String, _PendingCategoria>{};

    final parsedRows = <_ParsedRow>[];
    final messages = <ImportMessage>[];

    for (final entry in excel.tables.entries) {
      final sheetName = entry.key;
      final sheet = entry.value;
      if (sheet.rows.isEmpty) {
        continue;
      }

      final headerResult = _findHeaderRow(sheet.rows, expectedNormalized);
      if (headerResult == null) {
        messages.add(
          ImportMessage(
            type: ImportMessageType.warning,
            sheetName: sheetName,
            message: 'Hoja sin headers validos (falta ID_Activo o Disciplina).',
          ),
        );
        continue;
      }

      final headerRowIndex = headerResult.headerRowIndex;
      final columnMap = headerResult.columnMap;
      final foundHeaders = headerResult.foundHeaders;

      final missingHeaders = expectedNormalized.difference(foundHeaders);
      if (missingHeaders.isNotEmpty) {
        final missingLabels = expectedHeaders
            .where((header) => missingHeaders.contains(_normalizeToken(header)))
            .toList(growable: false);
        if (missingLabels.isNotEmpty) {
          messages.add(
            ImportMessage(
              type: ImportMessageType.warning,
              sheetName: sheetName,
              message: 'Columnas faltantes: ${missingLabels.join(', ')}.',
            ),
          );
        }
      }

      for (var rowIndex = headerRowIndex + 1; rowIndex < sheet.rows.length; rowIndex++) {
        final row = sheet.rows[rowIndex];
        final parsed = _parseRow(
          row,
          columnMap,
          sheetName: sheetName,
          rowNumber: rowIndex + 1,
          disciplinaKey: disciplinaKey,
        );
        if (parsed == null) {
          continue;
        }
        parsedRows.add(parsed);
      }
    }

    final totalRows = parsedRows.length;
    onProgress?.call(ImportProgress(stage: ImportStage.processing, processed: 0, total: totalRows, dryRun: dryRun));

    final idsToFetch = <String>{};
    for (final row in parsedRows) {
      if (row.preValidationError != null) {
        continue;
      }
      if (row.idActivo != null && row.idActivo!.isNotEmpty) {
        idsToFetch.add(row.idActivo!);
      }
    }

    final existingDocs = await _fetchExistingDocs(_firestore, idsToFetch.toList());

    int created = 0;
    int updated = 0;
    int skipped = 0;
    int categoriesCreated = 0;

    final rowChanges = <ImportRowChange>[];

    WriteBatch? batch;
    int batchCount = 0;

    Future<void> commitBatchIfNeeded({bool force = false}) async {
      if (batch == null || batchCount == 0) return;
      if (!force && batchCount < 400) return;
      await batch!.commit();
      batch = null;
      batchCount = 0;
    }

    final user = FirebaseAuth.instance.currentUser;
    final updatedBy = user?.email ?? user?.uid;

    int processed = 0;

    for (final row in parsedRows) {
      processed += 1;
      onProgress?.call(ImportProgress(stage: ImportStage.processing, processed: processed, total: totalRows, dryRun: dryRun));

      if (row.preValidationError != null) {
        skipped += 1;
        messages.add(
          ImportMessage(
            type: ImportMessageType.error,
            sheetName: row.sheetName,
            rowNumber: row.rowNumber,
            idActivo: row.idActivo,
            message: row.preValidationError!,
          ),
        );
        rowChanges.add(
          ImportRowChange(
            sheetName: row.sheetName,
            rowNumber: row.rowNumber,
            idActivo: row.idActivo ?? '',
            action: ImportAction.skip,
            categoria: '',
            changedFields: const [],
            reason: row.preValidationError,
          ),
        );
        continue;
      }

      final idActivo = row.idActivo ?? '';
      final existingDoc = existingDocs[idActivo];
      final existingData = existingDoc?.data() ?? const <String, dynamic>{};
      final existingDisciplina = existingData['disciplina']?.toString().trim() ?? '';
      if (existingDisciplina.isNotEmpty && !_disciplinaMatches(existingDisciplina, disciplinaKey)) {
        skipped += 1;
        const message = 'ID_Activo pertenece a otra disciplina; no se actualiza.';
        messages.add(
          ImportMessage(
            type: ImportMessageType.error,
            sheetName: row.sheetName,
            rowNumber: row.rowNumber,
            idActivo: idActivo,
            message: message,
          ),
        );
        rowChanges.add(
          ImportRowChange(
            sheetName: row.sheetName,
            rowNumber: row.rowNumber,
            idActivo: idActivo,
            action: ImportAction.skip,
            categoria: '',
            changedFields: const [],
            reason: message,
          ),
        );
        continue;
      }

      final categoriaResolved = _resolveCategoria(
        row: row,
        sheetName: row.sheetName,
        categoriaIndex: categoriaIndex,
        pendingCategorias: pendingCategorias,
      );

      final isCreate = existingDoc == null;
      final updateData = <String, dynamic>{};
      final ubicacionUpdates = <String, dynamic>{};
      final changedHeaders = <String>[];

      final idChanged = _isDifferent(existingData['idActivo'], idActivo);
      updateData['idActivo'] = idActivo;
      if (idChanged || isCreate) {
        _addChangedHeader(changedHeaders, _headerLabels[ImportField.idActivo]!);
      }

      if (isCreate || existingDisciplina.isEmpty) {
        updateData['disciplina'] = disciplinaKey.toLowerCase();
        _addChangedHeader(changedHeaders, _headerLabels[ImportField.disciplina]!);
      }

      final categoriaValue = categoriaResolved.value;
      final existingCategoria = existingData['categoria'] ?? existingData['categoriaActivo'];
      if (_isDifferent(existingCategoria, categoriaValue) || isCreate) {
        _addChangedHeader(changedHeaders, _headerLabels[ImportField.categoriaActivo]!);
      }
      updateData['categoria'] = categoriaValue;
      updateData['categoriaActivo'] = categoriaValue;

      for (final entry in row.cells.entries) {
        final field = entry.key;
        if (field == ImportField.idActivo || field == ImportField.disciplina || field == ImportField.categoriaActivo) {
          continue;
        }
        _applyField(
          field: field,
          cell: entry.value,
          existingData: existingData,
          updateData: updateData,
          ubicacionUpdates: ubicacionUpdates,
          changedHeaders: changedHeaders,
          overwriteEmpty: overwriteEmpty,
        );
      }

      if (ubicacionUpdates.isNotEmpty) {
        updateData['ubicacion'] = ubicacionUpdates;
      }

      if (isCreate) {
        updateData['codigoQR'] = idActivo;
        updateData['fechaCreacion'] = FieldValue.serverTimestamp();
      }

      if (!dryRun) {
        updateData['updatedAt'] = FieldValue.serverTimestamp();
        if (updatedBy != null && updatedBy.trim().isNotEmpty) {
          updateData['updatedBy'] = updatedBy.trim();
        }
        updateData['importSource'] = 'revit_excel';
        if (fileName.trim().isNotEmpty) {
          updateData['importFileName'] = fileName.trim();
        }
      }

      final action = isCreate ? ImportAction.create : ImportAction.update;
      if (action == ImportAction.create) {
        created += 1;
      } else {
        updated += 1;
      }

      rowChanges.add(
        ImportRowChange(
          sheetName: row.sheetName,
          rowNumber: row.rowNumber,
          idActivo: idActivo,
          action: action,
          categoria: categoriaResolved.label,
          changedFields: List<String>.from(changedHeaders),
        ),
      );

      if (!dryRun) {
        batch ??= _firestore.batch();
        final docRef = _firestore.collection('productos').doc(idActivo);
        batch!.set(docRef, updateData, SetOptions(merge: true));
        batchCount += 1;
        await commitBatchIfNeeded();
      }
    }

    if (!dryRun) {
      await commitBatchIfNeeded(force: true);

      if (pendingCategorias.isNotEmpty) {
        for (final categoria in pendingCategorias.values) {
          await _categoriasService.createCategoria(
            disciplinaKey: disciplinaKey,
            value: categoria.value,
            label: categoria.label,
            icon: Icons.category,
          );
          categoriesCreated += 1;
        }
      }
    }

    return ImportResult(
      totalRows: totalRows,
      created: created,
      updated: updated,
      skipped: skipped,
      categoriesCreated: categoriesCreated,
      categoriesPending: dryRun ? pendingCategorias.length : 0,
      rowChanges: rowChanges,
      messages: messages,
    );
  }
}

class _ParsedRow {
  final String sheetName;
  final int rowNumber;
  final Map<ImportField, _ParsedCell> cells;
  final String? idActivo;
  final String? preValidationError;

  _ParsedRow({
    required this.sheetName,
    required this.rowNumber,
    required this.cells,
    required this.idActivo,
    required this.preValidationError,
  });
}

class _ParsedCell {
  final dynamic value;
  final bool isEmpty;

  _ParsedCell({required this.value, required this.isEmpty});
}

class _HeaderResult {
  final int headerRowIndex;
  final Map<int, ImportField> columnMap;
  final Set<String> foundHeaders;

  _HeaderResult({
    required this.headerRowIndex,
    required this.columnMap,
    required this.foundHeaders,
  });
}

class _TargetField {
  final String key;
  final bool isUbicacion;

  const _TargetField(this.key, {this.isUbicacion = false});
}

class _PendingCategoria {
  final String value;
  final String label;

  const _PendingCategoria({required this.value, required this.label});
}

class _CategoryIndex {
  final Map<String, CategoriaItem> byNormalized;

  const _CategoryIndex(this.byNormalized);

  factory _CategoryIndex.fromItems(List<CategoriaItem> items) {
    final map = <String, CategoriaItem>{};
    for (final item in items) {
      final normalizedValue = _normalizeCategoryKey(item.value);
      final normalizedLabel = _normalizeCategoryKey(item.label);
      if (normalizedValue.isNotEmpty) {
        map[normalizedValue] = item;
      }
      if (normalizedLabel.isNotEmpty) {
        map[normalizedLabel] = item;
      }
    }
    return _CategoryIndex(map);
  }

  CategoriaItem? resolve(String value) {
    final key = _normalizeCategoryKey(value);
    if (key.isEmpty) return null;
    return byNormalized[key];
  }

  void register(String value, CategoriaItem item) {
    final key = _normalizeCategoryKey(value);
    if (key.isEmpty) return;
    byNormalized[key] = item;
  }
}

enum ImportField {
  idActivo,
  disciplina,
  categoriaActivo,
  tipoActivo,
  bloque,
  nivel,
  espacio,
  estadoOperativo,
  condicionFisica,
  fechaUltimaInspeccion,
  nivelCriticidad,
  impactoFalla,
  riesgoNormativo,
  frecuenciaMantenimientoMeses,
  fechaProximoMantenimiento,
  costoMantenimiento,
  costoReemplazo,
  observaciones,
  fechaInstalacion,
  vidaUtilEsperadaAnios,
  requiereReemplazo,
  tipoMobiliario,
  materialPrincipal,
  usoIntensivo,
  movilidad,
  fabricante,
  modelo,
  fechaAdquisicion,
  proveedor,
}

enum _FieldType { text, number, date, boolean }

const Map<ImportField, String> _headerLabels = {
  ImportField.idActivo: 'ID_Activo',
  ImportField.disciplina: 'Disciplina',
  ImportField.categoriaActivo: 'Categoria_Activo',
  ImportField.tipoActivo: 'Tipo_Activo',
  ImportField.bloque: 'Bloque',
  ImportField.nivel: 'Nivel',
  ImportField.espacio: 'Espacio',
  ImportField.estadoOperativo: 'Estado_Operativo',
  ImportField.condicionFisica: 'Condicion_Fisica',
  ImportField.fechaUltimaInspeccion: 'Fecha_Ultima_Inspeccion',
  ImportField.nivelCriticidad: 'Nivel_Criticidad',
  ImportField.impactoFalla: 'Impacto_Falla',
  ImportField.riesgoNormativo: 'Riesgo_Normativo',
  ImportField.frecuenciaMantenimientoMeses: 'Frecuencia_Mantenimiento_Meses',
  ImportField.fechaProximoMantenimiento: 'Fecha_Proximo_Mantenimiento',
  ImportField.costoMantenimiento: 'Costo_Mantenimiento',
  ImportField.costoReemplazo: 'Costo_Reemplazo',
  ImportField.observaciones: 'Observaciones',
  ImportField.fechaInstalacion: 'Fecha_Instalacion',
  ImportField.vidaUtilEsperadaAnios: 'Vida_Util_Esperada_Anios',
  ImportField.requiereReemplazo: 'Requiere_Reemplazo',
  ImportField.tipoMobiliario: 'Tipo_Mobiliario',
  ImportField.materialPrincipal: 'Material_Principal',
  ImportField.usoIntensivo: 'Uso_Intensivo',
  ImportField.movilidad: 'Movilidad',
  ImportField.fabricante: 'Fabricante',
  ImportField.modelo: 'Modelo',
  ImportField.fechaAdquisicion: 'Fecha_Adquisicion',
  ImportField.proveedor: 'Proveedor',
};

const Map<ImportField, _FieldType> _fieldTypes = {
  ImportField.idActivo: _FieldType.text,
  ImportField.disciplina: _FieldType.text,
  ImportField.categoriaActivo: _FieldType.text,
  ImportField.tipoActivo: _FieldType.text,
  ImportField.bloque: _FieldType.text,
  ImportField.nivel: _FieldType.text,
  ImportField.espacio: _FieldType.text,
  ImportField.estadoOperativo: _FieldType.text,
  ImportField.condicionFisica: _FieldType.text,
  ImportField.fechaUltimaInspeccion: _FieldType.date,
  ImportField.nivelCriticidad: _FieldType.text,
  ImportField.impactoFalla: _FieldType.text,
  ImportField.riesgoNormativo: _FieldType.text,
  ImportField.frecuenciaMantenimientoMeses: _FieldType.number,
  ImportField.fechaProximoMantenimiento: _FieldType.date,
  ImportField.costoMantenimiento: _FieldType.number,
  ImportField.costoReemplazo: _FieldType.number,
  ImportField.observaciones: _FieldType.text,
  ImportField.fechaInstalacion: _FieldType.date,
  ImportField.vidaUtilEsperadaAnios: _FieldType.number,
  ImportField.requiereReemplazo: _FieldType.boolean,
  ImportField.tipoMobiliario: _FieldType.text,
  ImportField.materialPrincipal: _FieldType.text,
  ImportField.usoIntensivo: _FieldType.text,
  ImportField.movilidad: _FieldType.text,
  ImportField.fabricante: _FieldType.text,
  ImportField.modelo: _FieldType.text,
  ImportField.fechaAdquisicion: _FieldType.date,
  ImportField.proveedor: _FieldType.text,
};

final Map<String, ImportField> _headerLookup = {
  for (final entry in _headerLabels.entries) _normalizeToken(entry.value): entry.key,
};

final Map<ImportField, List<_TargetField>> _targets = {
  ImportField.tipoActivo: const [
    _TargetField('nombre'),
    _TargetField('nombreProducto'),
    _TargetField('tipoActivo'),
  ],
  ImportField.bloque: const [
    _TargetField('bloque'),
    _TargetField('bloque', isUbicacion: true),
  ],
  ImportField.nivel: const [
    _TargetField('nivel'),
    _TargetField('nivel', isUbicacion: true),
  ],
  ImportField.espacio: const [
    _TargetField('espacio'),
    _TargetField('area', isUbicacion: true),
  ],
  ImportField.estadoOperativo: const [
    _TargetField('estadoOperativo'),
    _TargetField('estado'),
  ],
};

_HeaderResult? _findHeaderRow(List<List<Data?>> rows, Set<String> expectedNormalized) {
  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    final row = rows[rowIndex];
    final columnMap = <int, ImportField>{};
    final foundHeaders = <String>{};

    for (var colIndex = 0; colIndex < row.length; colIndex++) {
      final cellValue = _stringifyCell(row[colIndex]?.value);
      if (cellValue.isEmpty) {
        continue;
      }
      final normalized = _normalizeToken(cellValue);
      final field = _headerLookup[normalized];
      if (field != null) {
        columnMap[colIndex] = field;
        foundHeaders.add(normalized);
      }
    }

    if (foundHeaders.contains(_normalizeToken(_headerLabels[ImportField.idActivo]!)) &&
        foundHeaders.contains(_normalizeToken(_headerLabels[ImportField.disciplina]!))) {
      return _HeaderResult(
        headerRowIndex: rowIndex,
        columnMap: columnMap,
        foundHeaders: foundHeaders,
      );
    }

    if (foundHeaders.any(expectedNormalized.contains)) {
      continue;
    }
  }
  return null;
}

_ParsedRow? _parseRow(
  List<Data?> row,
  Map<int, ImportField> columnMap, {
  required String sheetName,
  required int rowNumber,
  required String disciplinaKey,
}) {
  if (columnMap.isEmpty) return null;

  final cells = <ImportField, _ParsedCell>{};
  bool hasValue = false;

  for (final entry in columnMap.entries) {
    final colIndex = entry.key;
    if (colIndex >= row.length) {
      continue;
    }
    final field = entry.value;
    final cell = row[colIndex];
    final parsed = _parseCell(field, cell?.value);
    cells[field] = parsed;
    if (!parsed.isEmpty) {
      hasValue = true;
    }
  }

  if (!hasValue) {
    return null;
  }

  final idActivo = _stringifyCell(cells[ImportField.idActivo]?.value);
  final disciplinaValue = _stringifyCell(cells[ImportField.disciplina]?.value);

  String? error;
  if (idActivo.isEmpty) {
    error = 'ID_Activo vacio.';
  } else if (disciplinaValue.isEmpty) {
    error = 'Disciplina vacia.';
  } else if (!_disciplinaMatches(disciplinaValue, disciplinaKey)) {
    error = 'Disciplina no coincide.';
  }

  return _ParsedRow(
    sheetName: sheetName,
    rowNumber: rowNumber,
    cells: cells,
    idActivo: idActivo.isEmpty ? null : idActivo,
    preValidationError: error,
  );
}

void _applyField({
  required ImportField field,
  required _ParsedCell cell,
  required Map<String, dynamic> existingData,
  required Map<String, dynamic> updateData,
  required Map<String, dynamic> ubicacionUpdates,
  required List<String> changedHeaders,
  required bool overwriteEmpty,
}) {
  if (cell.isEmpty && !overwriteEmpty) {
    return;
  }

  final type = _fieldTypes[field] ?? _FieldType.text;
  final value = cell.isEmpty ? _emptyValueFor(type) : cell.value;
  final targets = _targets[field] ?? [
    _TargetField(_fieldKeyFor(field)),
  ];

  bool changed = false;
  for (final target in targets) {
    final existingValue = target.isUbicacion
        ? (existingData['ubicacion'] as Map<String, dynamic>? ?? const <String, dynamic>{})[target.key]
        : existingData[target.key];
    if (_isDifferent(existingValue, value)) {
      changed = true;
    }
    if (target.isUbicacion) {
      ubicacionUpdates[target.key] = value;
    } else {
      updateData[target.key] = value;
    }
  }

  if (changed) {
    _addChangedHeader(changedHeaders, _headerLabels[field]!);
  }
}

String _fieldKeyFor(ImportField field) {
  switch (field) {
    case ImportField.idActivo:
      return 'idActivo';
    case ImportField.disciplina:
      return 'disciplina';
    case ImportField.categoriaActivo:
      return 'categoriaActivo';
    case ImportField.tipoActivo:
      return 'nombre';
    case ImportField.bloque:
      return 'bloque';
    case ImportField.nivel:
      return 'nivel';
    case ImportField.espacio:
      return 'espacio';
    case ImportField.estadoOperativo:
      return 'estadoOperativo';
    case ImportField.condicionFisica:
      return 'condicionFisica';
    case ImportField.fechaUltimaInspeccion:
      return 'fechaUltimaInspeccion';
    case ImportField.nivelCriticidad:
      return 'nivelCriticidad';
    case ImportField.impactoFalla:
      return 'impactoFalla';
    case ImportField.riesgoNormativo:
      return 'riesgoNormativo';
    case ImportField.frecuenciaMantenimientoMeses:
      return 'frecuenciaMantenimientoMeses';
    case ImportField.fechaProximoMantenimiento:
      return 'fechaProximoMantenimiento';
    case ImportField.costoMantenimiento:
      return 'costoMantenimiento';
    case ImportField.costoReemplazo:
      return 'costoReemplazo';
    case ImportField.observaciones:
      return 'observaciones';
    case ImportField.fechaInstalacion:
      return 'fechaInstalacion';
    case ImportField.vidaUtilEsperadaAnios:
      return 'vidaUtilEsperadaAnios';
    case ImportField.requiereReemplazo:
      return 'requiereReemplazo';
    case ImportField.tipoMobiliario:
      return 'tipoMobiliario';
    case ImportField.materialPrincipal:
      return 'materialPrincipal';
    case ImportField.usoIntensivo:
      return 'usoIntensivo';
    case ImportField.movilidad:
      return 'movilidad';
    case ImportField.fabricante:
      return 'fabricante';
    case ImportField.modelo:
      return 'modelo';
    case ImportField.fechaAdquisicion:
      return 'fechaAdquisicion';
    case ImportField.proveedor:
      return 'proveedor';
  }
}

_ParsedCell _parseCell(ImportField field, dynamic rawValue) {
  if (_isEmptyValue(rawValue)) {
    return _ParsedCell(value: null, isEmpty: true);
  }

  switch (_fieldTypes[field]) {
    case _FieldType.number:
      final number = _parseNumber(rawValue);
      return _ParsedCell(value: number ?? rawValue.toString().trim(), isEmpty: false);
    case _FieldType.date:
      final date = _parseDate(rawValue);
      return _ParsedCell(value: date ?? rawValue.toString().trim(), isEmpty: false);
    case _FieldType.boolean:
      final parsed = _parseBool(rawValue);
      return _ParsedCell(value: parsed ?? rawValue.toString().trim(), isEmpty: false);
    case _FieldType.text:
    default:
      return _ParsedCell(value: rawValue.toString().trim(), isEmpty: false);
  }
}

Future<Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchExistingDocs(
  FirebaseFirestore firestore,
  List<String> ids,
) async {
  final result = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
  if (ids.isEmpty) return result;
  const chunkSize = 10;
  for (var i = 0; i < ids.length; i += chunkSize) {
    final chunk = ids.sublist(i, i + chunkSize > ids.length ? ids.length : i + chunkSize);
    final snapshot = await firestore
        .collection('productos')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        )
        .where(FieldPath.documentId, whereIn: chunk)
        .get();
    for (final doc in snapshot.docs) {
      result[doc.id] = doc;
    }
  }
  return result;
}

class _ResolvedCategoria {
  final String value;
  final String label;

  const _ResolvedCategoria({required this.value, required this.label});
}

_ResolvedCategoria _resolveCategoria({
  required _ParsedRow row,
  required String sheetName,
  required _CategoryIndex categoriaIndex,
  required Map<String, _PendingCategoria> pendingCategorias,
}) {
  final categoriaCell = row.cells[ImportField.categoriaActivo];
  String? rawCategoria = categoriaCell?.value?.toString().trim();
  if (rawCategoria != null && _isEmptyValue(rawCategoria)) {
    rawCategoria = null;
  }

  String resolvedLabel;
  if (rawCategoria != null && rawCategoria.trim().isNotEmpty) {
    resolvedLabel = rawCategoria.trim();
  } else {
    final isGeneric = _isGenericSheetName(sheetName);
    resolvedLabel = isGeneric ? 'Otros' : sheetName.trim();
  }

  if (resolvedLabel.isEmpty) {
    resolvedLabel = 'Otros';
  }

  final existing = categoriaIndex.resolve(resolvedLabel);
  if (existing != null) {
    return _ResolvedCategoria(value: existing.value, label: existing.label);
  }

  final normalizedLabel = normalizeCategoriaValue(resolvedLabel);
  final value = normalizedLabel.isEmpty ? normalizeCategoriaValue('Otros') : normalizedLabel;
  final label = resolvedLabel.trim().isEmpty ? 'Otros' : resolvedLabel.trim();
  final pendingKey = _normalizeCategoryKey(label);
  pendingCategorias.putIfAbsent(pendingKey, () => _PendingCategoria(value: value, label: label));

  final pendingItem = CategoriaItem(id: '', disciplina: '', value: value, label: label, icon: Icons.category);
  categoriaIndex.register(label, pendingItem);
  categoriaIndex.register(value, pendingItem);

  return _ResolvedCategoria(value: value, label: label);
}

bool _isGenericSheetName(String sheetName) {
  final normalized = _normalizeToken(sheetName);
  if (normalized.isEmpty) return true;
  final compact = normalized.replaceAll('_', '');
  return RegExp(r'^(sheet|hoja)\d*$').hasMatch(compact);
}

String _normalizeToken(String value) {
  var text = value.trim().toLowerCase();
  if (text.isEmpty) return '';
  const replacements = {
    '\u00e1': 'a',
    '\u00e9': 'e',
    '\u00ed': 'i',
    '\u00f3': 'o',
    '\u00fa': 'u',
    '\u00fc': 'u',
    '\u00f1': 'n',
  };
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(replacements[char] ?? char);
  }
  text = buffer.toString();
  text = text.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  text = text.replaceAll(RegExp(r'_+'), '_');
  text = text.replaceAll(RegExp(r'^_+|_+$'), '');
  return text;
}

String _normalizeCategoryKey(String value) {
  return _normalizeToken(value);
}

bool _disciplinaMatches(String rawValue, String disciplinaKey) {
  if (rawValue.trim().isEmpty) return false;
  return _normalizeToken(rawValue) == _normalizeToken(disciplinaKey);
}

bool _isEmptyValue(dynamic value) {
  if (value == null) return true;
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    final normalized = trimmed.toLowerCase();
    return normalized == 'n/a' || normalized == 'na' || normalized == '-' || normalized == '\u2014';
  }
  return false;
}

String _stringifyCell(dynamic value) {
  if (value == null) return '';
  if (value is num) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toString();
  }
  return value.toString().trim();
}

void _addChangedHeader(List<String> headers, String header) {
  if (!headers.contains(header)) {
    headers.add(header);
  }
}

bool _isDifferent(dynamic existing, dynamic next) {
  if (existing == null && next == null) return false;
  if (existing == null || next == null) return true;

  final existingDate = _parseDate(existing);
  final nextDate = _parseDate(next);
  if (existingDate != null && nextDate != null) {
    return !existingDate.isAtSameMomentAs(nextDate);
  }

  final existingNumber = _parseNumber(existing);
  final nextNumber = _parseNumber(next);
  if (existingNumber != null && nextNumber != null) {
    return (existingNumber - nextNumber).abs() > 0.000001;
  }

  final existingBool = _parseBool(existing);
  final nextBool = _parseBool(next);
  if (existingBool != null && nextBool != null) {
    return existingBool != nextBool;
  }

  return existing.toString().trim() != next.toString().trim();
}

dynamic _emptyValueFor(_FieldType type) {
  switch (type) {
    case _FieldType.text:
      return '';
    case _FieldType.boolean:
    case _FieldType.number:
    case _FieldType.date:
      return null;
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is num) {
    return _excelDateToDateTime(value.toDouble());
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parsedIso = DateTime.tryParse(trimmed);
    if (parsedIso != null) return parsedIso;
    final separator = trimmed.contains('/')
        ? '/'
        : trimmed.contains('-')
            ? '-'
            : null;
    if (separator != null) {
      final parts = trimmed.split(separator);
      if (parts.length == 3) {
        final p0 = int.tryParse(parts[0]);
        final p1 = int.tryParse(parts[1]);
        final p2 = int.tryParse(parts[2]);
        if (p0 != null && p1 != null && p2 != null) {
          if (parts[0].length == 4) {
            return DateTime(p0, p1, p2);
          }
          return DateTime(p2, p1, p0);
        }
      }
    }
  }
  return null;
}

DateTime _excelDateToDateTime(double value) {
  final milliseconds = ((value - 25569) * 86400 * 1000).round();
  return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true).toLocal();
}

double? _parseNumber(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) {
    var text = value.trim();
    if (text.isEmpty) return null;
    text = text.replaceAll(RegExp(r'[^0-9,\.-]'), '');
    if (text.contains(',') && text.contains('.')) {
      text = text.replaceAll(',', '');
    } else if (text.contains(',') && !text.contains('.')) {
      text = text.replaceAll(',', '.');
    }
    return double.tryParse(text);
  }
  return null;
}

bool? _parseBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (['si', 's\u00ed', 's', 'true', '1', 'yes', 'y', 'x'].contains(normalized)) {
      return true;
    }
    if (['no', 'false', '0'].contains(normalized)) {
      return false;
    }
  }
  return null;
}
