import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:appmantflutter/services/date_utils.dart';

const Map<String, Map<String, List<String>>> parametrosHeaders = {
  'electricas': {
    'base': [
      'ID_Activo',
      'Disciplina',
      'Categoria_Activo',
      'Tipo_Activo',
      'Bloque',
      'Nivel',
      'Espacio',
      'Estado_Operativo',
      'Condicion_Fisica',
      'Fecha_Ultima_Inspeccion',
      'Nivel_Criticidad',
      'Impacto_Falla',
      'Riesgo_Normativo',
      'Frecuencia_Mantenimiento_Meses',
      'Fecha_Proximo_Mantenimiento',
      'Costo_Mantenimiento',
      'Costo_Reemplazo',
      'Observaciones',
    ],
    'reportes': [
      'ID_Reporte',
      'ID_Activo',
      'Disciplina',
      'Fecha_Inspeccion',
      'Estado_Detectado',
      'Riesgo_Electrico',
      'Accion_Recomendada',
      'Costo_Estimado',
      'Responsable',
    ],
  },
  'sanitarias': {
    'base': [
      'ID_Activo',
      'Disciplina',
      'Categoria_Activo',
      'Tipo_Activo',
      'Bloque',
      'Nivel',
      'Espacio',
      'Estado_Operativo',
      'Condicion_Fisica',
      'Fecha_Ultima_Inspeccion',
      'Nivel_Criticidad',
      'Impacto_Falla',
      'Riesgo_Normativo',
      'Frecuencia_Mantenimiento_Meses',
      'Fecha_Proximo_Mantenimiento',
      'Costo_Mantenimiento',
      'Observaciones',
    ],
    'reportes': [
      'ID_Reporte',
      'ID_Activo',
      'Disciplina',
      'Fecha_Inspeccion',
      'Estado_Detectado',
      'Riesgo_Sanitario',
      'Accion_Recomendada',
      'Costo_Estimado',
      'Responsable',
    ],
  },
  'arquitectura': {
    'base': [
      'ID_Activo',
      'Disciplina',
      'Categoria_Activo',
      'Tipo_Activo',
      'Bloque',
      'Nivel',
      'Espacio',
      'Estado_Operativo',
      'Condicion_Fisica',
      'Fecha_Ultima_Inspeccion',
      'Nivel_Criticidad',
      'Fecha_Instalacion',
      'Vida_Util_Esperada_Anios',
      'Costo_Mantenimiento',
      'Observaciones',
    ],
    'reportes': [
      'ID_Reporte',
      'ID_Activo',
      'Disciplina',
      'Fecha_Inspeccion',
      'Estado_Detectado',
      'Accion_Recomendada',
      'Costo_Estimado',
      'Responsable',
    ],
  },
  'estructuras': {
    'base': [
      'ID_Activo',
      'Disciplina',
      'Categoria_Activo',
      'Tipo_Activo',
      'Bloque',
      'Nivel',
      'Espacio',
      'Estado_Operativo',
      'Condicion_Fisica',
      'Fecha_Ultima_Inspeccion',
      'Nivel_Criticidad',
      'Fecha_Instalacion',
      'Vida_Util_Esperada_Anios',
      'Requiere_Reemplazo',
      'Costo_Reemplazo',
      'Observaciones',
    ],
    'reportes': [
      'ID_Reporte',
      'ID_Activo',
      'Disciplina',
      'Fecha_Inspeccion',
      'Estado_Detectado',
      'Accion_Recomendada',
      'Costo_Estimado',
      'Responsable',
    ],
  },
};

List<String> headersFor(String disciplinaKey, String tipo) {
  return List<String>.from(parametrosHeaders[disciplinaKey]?[tipo] ?? const []);
}

dynamic valueForHeader(
  String header, {
  required QueryDocumentSnapshot<Map<String, dynamic>> productDoc,
  QueryDocumentSnapshot<Map<String, dynamic>>? reportDoc,
}) {
  final productData = productDoc.data();
  final reportData = reportDoc?.data() ?? const <String, dynamic>{};
  final ubicacion = productData['ubicacion'] as Map<String, dynamic>? ?? const <String, dynamic>{};

  switch (header) {
    case 'ID_Activo':
      return productData['idActivo'] ?? productDoc.id;
    case 'Disciplina':
      return productData['disciplina'] ?? '';
    case 'Categoria_Activo':
      return productData['categoria'] ?? '';
    case 'Tipo_Activo':
      return productData['tipoActivo'] ?? productData['subcategoria'] ?? '';
    case 'Bloque':
      return ubicacion['bloque'] ?? productData['bloque'] ?? '';
    case 'Nivel':
      return ubicacion['nivel'] ?? productData['nivel'] ?? productData['piso'] ?? '';
    case 'Espacio':
      return ubicacion['area'] ?? productData['area'] ?? productData['espacio'] ?? '';
    case 'Estado_Operativo':
      return _formatEnum(productData['estadoOperativo'] ?? productData['estado']);
    case 'Condicion_Fisica':
      return _formatEnum(productData['condicionFisica']);
    case 'Observaciones':
      return productData['observaciones'] ?? '';
    case 'Costo_Mantenimiento':
      return _formatNumber(productData['costoMantenimiento']);
    case 'Costo_Reemplazo':
      return _formatNumber(productData['costoReemplazo']);
    case 'Frecuencia_Mantenimiento_Meses':
      return _formatNumber(productData['frecuenciaMantenimientoMeses']);
    case 'Impacto_Falla':
      return _formatEnum(productData['impactoFalla']);
    case 'Riesgo_Normativo':
      return _formatEnum(productData['riesgoNormativo']);
    case 'Nivel_Criticidad':
      return _formatEnum(productData['nivelCriticidad']);
    case 'Tipo_Mantenimiento':
      return _formatEnum(productData['tipoMantenimiento']);
    case 'Fecha_Ultima_Inspeccion':
      return _formatDate(productData['fechaUltimaInspeccion'] ?? productData['ultimaInspeccionFecha']);
    case 'Fecha_Proximo_Mantenimiento':
      return _formatDate(
        _resolveNextMaintenanceDate(
          fechaProximoMantenimiento: productData['fechaProximoMantenimiento'],
          fechaUltimaInspeccion: productData['fechaUltimaInspeccion'] ?? productData['ultimaInspeccionFecha'],
          frecuenciaMantenimientoMeses: productData['frecuenciaMantenimientoMeses'],
        ),
      );
    case 'Fecha_Instalacion':
      return _formatDate(productData['fechaInstalacion']);
    case 'Vida_Util_Esperada_Anios':
      return _formatNumber(productData['vidaUtilEsperadaAnios']);
    case 'Requiere_Reemplazo':
      return _formatBool(productData['requiereReemplazo']);
    case 'ID_Reporte':
      return reportDoc?.id ?? '';
    case 'Fecha_Inspeccion':
      return _formatDate(reportData['fechaInspeccion'] ?? reportData['fecha']);
    case 'Estado_Detectado':
      return _formatEnum(reportData['estadoDetectado'] ?? reportData['estado']);
    case 'Accion_Recomendada':
      return reportData['accionRecomendada'] ?? reportData['accion'] ?? '';
    case 'Costo_Estimado':
      return _formatNumber(reportData['costoEstimado'] ?? reportData['costo']);
    case 'Responsable':
      return reportData['responsable'] ?? '';
    case 'Riesgo_Electrico':
      return reportData['riesgoElectrico'] ?? '';
    case 'Riesgo_Sanitario':
      return reportData['riesgoSanitario'] ?? '';
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

String _formatBool(dynamic value) {
  if (value == null) {
    return '';
  }
  if (value is bool) {
    return value ? 'Sí' : 'No';
  }
  return value.toString();
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

DateTime? _resolveNextMaintenanceDate({
  required dynamic fechaProximoMantenimiento,
  required dynamic fechaUltimaInspeccion,
  required dynamic frecuenciaMantenimientoMeses,
}) {
  final fechaProximo = _resolveDate(fechaProximoMantenimiento);
  if (fechaProximo != null) {
    return fechaProximo;
  }
  final fechaUltima = _resolveDate(fechaUltimaInspeccion);
  final frecuencia = _resolveDouble(frecuenciaMantenimientoMeses);
  if (fechaUltima == null || frecuencia == null) {
    return null;
  }
  return addMonthsDouble(fechaUltima, frecuencia);
}

double? _resolveDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString().replaceAll(',', '.'));
}
