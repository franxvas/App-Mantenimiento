import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProductRecord {
  final String id;
  final Map<String, dynamic> data;

  const ProductRecord({required this.id, required this.data});

  Map<String, dynamic> get ubicacion => data['ubicacion'] as Map<String, dynamic>? ?? {};
}

class ReportRecord {
  final String id;
  final Map<String, dynamic> data;

  const ReportRecord({required this.id, required this.data});
}

class ExcelRowMapper {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  static Map<String, dynamic> buildRowForHeader(
    String header,
    ProductRecord product, {
    ReportRecord? report,
  }) {
    return {header: valueForHeader(header, product, report: report)};
  }

  static dynamic valueForHeader(
    String header,
    ProductRecord product, {
    ReportRecord? report,
  }) {
    final normalized = normalizeHeader(header);
    final data = product.data;
    final ubicacion = product.ubicacion;
    final reportData = report?.data ?? const <String, dynamic>{};

    switch (normalized) {
      case 'idactivo':
        return product.id;
      case 'nombre':
        return data['nombre'];
      case 'disciplina':
        return _resolveDisciplina(data);
      case 'categoriaactivo':
      case 'categoria':
        return data['categoriaActivo'] ?? data['categoria'];
      case 'tipoactivo':
      case 'tipo':
        return _resolveTipoActivo(data);
      case 'bloque':
        return data['bloque'] ?? ubicacion['bloque'];
      case 'nivel':
      case 'piso':
        return _resolveNivel(data, ubicacion);
      case 'espacio':
      case 'area':
      case 'oficina':
        return _resolveEspacio(data, ubicacion);
      case 'estadooperativo':
      case 'estado':
        return data['estadoOperativo'] ?? data['estado'];
      case 'condicionfisica':
        return data['condicionFisica'];
      case 'fechaultimainspeccion':
        return _formatDate(reportData['fechaInspeccion'] ?? data['fechaUltimaInspeccion']);
      case 'nivelcriticidad':
        return data['nivelCriticidad'];
      case 'impactofalla':
        return data['impactoFalla'];
      case 'riesgonormativo':
        return data['riesgoNormativo'];
      case 'frecuenciamantenimientomeses':
        return data['frecuenciaMantenimientoMeses'];
      case 'fechaproximomantenimiento':
        return _formatDate(data['fechaProximoMantenimiento']);
      case 'costomantenimiento':
        return data['costoMantenimiento'];
      case 'costoreemplazo':
        return data['costoReemplazo'];
      case 'observaciones':
        return data['observaciones'] ?? data['descripcion'];
      case 'idreporte':
        return report?.id;
      case 'fechainspeccion':
      case 'fecha':
        return _formatDate(reportData['fechaInspeccion'] ?? reportData['fecha']);
      case 'estadodetectado':
        return reportData['estadoDetectado'];
      case 'riesgoelectrico':
        return reportData['riesgoElectrico'];
      case 'accionrecomendada':
        return reportData['accionRecomendada'];
      case 'costoestimado':
        return reportData['costoEstimado'];
      case 'responsable':
        return reportData['responsable'] ?? reportData['encargado'];
      default:
        return data[header] ?? reportData[header];
    }
  }

  static String normalizeHeader(String header) {
    final lower = header.toLowerCase();
    final buffer = StringBuffer();
    for (final codeUnit in lower.runes) {
      final char = String.fromCharCode(codeUnit);
      buffer.write(_accentMap[char] ?? char);
    }
    return buffer.toString().replaceAll(RegExp(r'[\s_\-]'), '').replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static String _resolveNivel(Map<String, dynamic> data, Map<String, dynamic> ubicacion) {
    return (data['nivel'] ?? data['piso'] ?? ubicacion['nivel'] ?? ubicacion['piso'] ?? '').toString();
  }

  static String _resolveDisciplina(Map<String, dynamic> data) {
    final raw = data['disciplina'] ??
        data['disciplinaLabel'] ??
        data['disciplinaKey'] ??
        (data['attrs'] as Map<String, dynamic>?)?['disciplinaKey'] ??
        (data['attrs'] as Map<String, dynamic>?)?['disciplina'];
    final key = raw?.toString().toLowerCase() ?? '';
    return _disciplinaLabels[key] ?? raw?.toString() ?? '';
  }

  static String _resolveTipoActivo(Map<String, dynamic> data) {
    return data['tipoActivo']?.toString() ?? data['subcategoria']?.toString() ?? '';
  }

  static String _resolveEspacio(Map<String, dynamic> data, Map<String, dynamic> ubicacion) {
    return (data['espacio'] ??
            data['area'] ??
            data['oficina'] ??
            ubicacion['espacio'] ??
            ubicacion['area'] ??
            ubicacion['oficina'] ??
            '')
        .toString();
  }

  static String _formatDate(dynamic value) {
    final date = _resolveDate(value);
    if (date == null) {
      return '';
    }
    return _dateFormat.format(date);
  }

  static DateTime? _resolveDate(dynamic value) {
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

  static const Map<String, String> _accentMap = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'ã': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
    'ç': 'c',
  };

  static const Map<String, String> _disciplinaLabels = {
    'electricas': 'Electricas',
    'arquitectura': 'Arquitectura',
    'sanitarias': 'Sanitarias',
    'estructuras': 'Estructuras',
  };
}
