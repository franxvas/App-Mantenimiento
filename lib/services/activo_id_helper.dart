class ActivoIdHelper {
  static const Map<String, String> _disciplinaCodeMap = {
    'electricas': 'ELE',
    'sanitarias': 'SAN',
    'arquitectura': 'ARQ',
    'estructuras': 'EST',
  };

  static String buildPreview({
    required String disciplinaKey,
    required String nombre,
    required String bloque,
    required String nivel,
    String? correlativo,
  }) {
    final prefix = _buildPrefix(
      disciplinaKey: disciplinaKey,
      nombre: nombre,
      bloque: bloque,
      nivel: nivel,
    );
    final suffix = correlativo?.isNotEmpty == true ? correlativo! : '???';
    return '$prefix-$suffix';
  }

  static String buildId({
    required String disciplinaKey,
    required String nombre,
    required String bloque,
    required String nivel,
    required String correlativo,
  }) {
    final prefix = _buildPrefix(
      disciplinaKey: disciplinaKey,
      nombre: nombre,
      bloque: bloque,
      nivel: nivel,
    );
    return '$prefix-$correlativo';
  }

  static String formatCorrelativo(int counter) {
    return counter.toString().padLeft(3, '0');
  }

  static String? extractCorrelativo(String? idActivo) {
    if (idActivo == null || idActivo.trim().isEmpty) {
      return null;
    }
    final parts = idActivo.split('-');
    if (parts.isEmpty) {
      return null;
    }
    final suffix = parts.last.trim();
    if (suffix.isEmpty) {
      return null;
    }
    return suffix;
  }

  static String _buildPrefix({
    required String disciplinaKey,
    required String nombre,
    required String bloque,
    required String nivel,
  }) {
    final disciplinaCode = _disciplinaCodeMap[disciplinaKey] ?? 'GEN';
    final nombreCode = _nombreCode(nombre);
    final ubicacionCode = _ubicacionCode(bloque, nivel);
    return '$disciplinaCode-$nombreCode-$ubicacionCode';
  }

  static String _nombreCode(String nombre) {
    final normalized = _removeDiacritics(nombre).replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) {
      return 'ACT';
    }
    final sanitized = normalized.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (sanitized.isEmpty) {
      return 'ACT';
    }
    return sanitized.length <= 3 ? sanitized : sanitized.substring(0, 3);
  }

  static String _ubicacionCode(String bloque, String nivel) {
    final bloqueTrim = bloque.trim();
    final nivelTrim = nivel.trim();
    if (bloqueTrim.isEmpty || nivelTrim.isEmpty) {
      return '??';
    }
    final bloqueCode = bloqueTrim[0].toUpperCase();
    final nivelCode = nivelTrim.replaceAll(RegExp(r'\s+'), '');
    return '$bloqueCode$nivelCode';
  }

  static String _removeDiacritics(String input) {
    const replacements = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'Á': 'A',
      'À': 'A',
      'Ä': 'A',
      'Â': 'A',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'É': 'E',
      'È': 'E',
      'Ë': 'E',
      'Ê': 'E',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'Í': 'I',
      'Ì': 'I',
      'Ï': 'I',
      'Î': 'I',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'Ó': 'O',
      'Ò': 'O',
      'Ö': 'O',
      'Ô': 'O',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'Ú': 'U',
      'Ù': 'U',
      'Ü': 'U',
      'Û': 'U',
      'ñ': 'n',
      'Ñ': 'N',
    };
    var output = input;
    replacements.forEach((key, value) {
      output = output.replaceAll(key, value);
    });
    return output;
  }
}
