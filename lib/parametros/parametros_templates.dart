import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:appmantflutter/services/usuarios_cache_service.dart';

const List<String> _baseHeaders = [
  'ID_Activo',
  'Disciplina',
  'Categoria_Activo',
  'Tipo_Activo',
  'Marca',
  'Modelo',
  'Descripcion_Activo',
  'Bloque',
  'Nivel',
  'Espacio',
  'Estado_Operativo',
  'Condicion_Fisica',
  'Nivel_Criticidad',
  'Riesgo_Normativo',
  'Accion_Recomendada',
  'Costo_Estimado',
  'Fecha_Ultima_Inspeccion',
];

const List<String> _reportesHeaders = [
  'ID_Reporte',
  'ID_Activo',
  'Disciplina',
  'Fecha_Inspeccion',
  'Tipo_Mantenimiento',
  'Estado_Operativo',
  'Condicion_Fisica',
  'Nivel_Criticidad',
  'Riesgo_Normativo',
  'Accion_Recomendada',
  'Costo_Estimado',
  'Descripcion_Reporte',
  'Responsable_Reporte',
];

List<String> headersFor(String _disciplinaKey, String tipo) {
  if (tipo == 'base') {
    return List<String>.from(_baseHeaders);
  }
  if (tipo == 'reportes') {
    return List<String>.from(_reportesHeaders);
  }
  return const [];
}

dynamic valueForHeader(
  String header, {
  required QueryDocumentSnapshot<Map<String, dynamic>> productDoc,
  QueryDocumentSnapshot<Map<String, dynamic>>? reportDoc,
}) {
  final productData = productDoc.data();
  final reportData = reportDoc?.data() ?? const <String, dynamic>{};
  final ubicacion = productData['ubicacion'] as Map<String, dynamic>? ?? const <String, dynamic>{};
  final attrs = productData['attrs'] as Map<String, dynamic>? ?? const <String, dynamic>{};

  switch (header) {
    case 'ID_Activo':
      return productDoc.id;
    case 'ID_Reporte':
      return reportDoc?.id ?? '';
    case 'Disciplina':
      return productData['disciplina'] ?? '';
    case 'Categoria_Activo':
      return productData['categoria'] ?? productData['categoriaActivo'] ?? '';
    case 'Tipo_Activo':
      return productData['nombre'] ?? productData['nombreProducto'] ?? '';
    case 'Marca':
      return productData['marca'] ?? attrs['marca'] ?? '';
    case 'Modelo':
      return productData['modelo'] ?? attrs['modelo'] ?? '';
    case 'Descripcion_Activo':
      return productData['descripcion'] ?? '';
    case 'Bloque':
      return ubicacion['bloque'] ?? productData['bloque'] ?? '';
    case 'Nivel':
      return ubicacion['nivel'] ?? productData['nivel'] ?? productData['piso'] ?? '';
    case 'Espacio':
      return ubicacion['area'] ?? productData['area'] ?? productData['espacio'] ?? '';
    case 'Fecha_Inspeccion':
      return _formatDate(reportData['fechaInspeccion'] ?? reportData['fecha']);
    case 'Fecha_Ultima_Inspeccion':
      return _formatDate(productData['fechaUltimaInspeccion'] ?? productData['ultimaInspeccionFecha']);
    case 'Tipo_Mantenimiento':
      return _formatEnum(reportData['tipoMantenimiento'] ?? productData['tipoMantenimiento']);
    case 'Estado_Operativo':
      return _formatEnum(
        reportData['estadoNuevo'] ??
            reportData['estadoOperativo'] ??
            reportData['estadoDetectado'] ??
            reportData['estado'] ??
            productData['estado'],
      );
    case 'Condicion_Fisica':
      return _formatEnum(reportData['condicionFisica'] ?? productData['condicionFisica']);
    case 'Nivel_Criticidad':
      return _formatEnum(reportData['nivelCriticidad'] ?? productData['nivelCriticidad']);
    case 'Riesgo_Normativo':
      return _formatEnum(reportData['riesgoNormativo'] ?? productData['riesgoNormativo']);
    case 'Accion_Recomendada':
      return reportData['accionRecomendada'] ?? reportData['accion'] ?? productData['accionRecomendada'] ?? '';
    case 'Costo_Estimado':
      return _formatNumber(reportData['costoEstimado'] ?? reportData['costo'] ?? productData['costoEstimado']);
    case 'Descripcion_Reporte':
      return reportData['descripcion'] ?? reportData['comentarios'] ?? '';
    case 'Responsable_Reporte':
      if (reportDoc == null) {
        return '';
      }
      return UsuariosCacheService.instance.resolveResponsableName(reportData);
    default:
      return '';
  }
}

String _formatDate(dynamic value) {
  final date = _resolveDate(value);
  if (date == null) {
    return '';
  }
  return DateFormat('dd/MM/yyyy').format(date);
}

String _formatEnum(dynamic value) {
  if (value == null) {
    return '';
  }
  final raw = value.toString();
  if (raw.isEmpty) {
    return '';
  }
  return raw
      .replaceAll('_', ' ')
      .split(' ')
      .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String _formatNumber(dynamic value) {
  if (value == null) {
    return '';
  }
  return value.toString();
}

DateTime? _resolveDate(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
