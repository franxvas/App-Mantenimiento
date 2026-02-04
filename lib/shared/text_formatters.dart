import 'package:intl/intl.dart';

String formatTitleCase(String? value) {
  if (value == null) return '';
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.contains('@') || trimmed.contains('/')) {
    return trimmed;
  }
  final normalized = trimmed.replaceAll('_', ' ').replaceAll('-', ' ');
  return normalized
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        final lower = word.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

String formatUpperCase(String? value) {
  if (value == null) return '';
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.toUpperCase();
}

String formatSubcategoriaDisplay(String? value) {
  return formatTitleCase(value);
}

String normalizeCategoriaValue(String value) {
  var text = value.trim().toLowerCase();
  if (text.isEmpty) return '';
  const replacements = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
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

String formatDateTimeDMYHM(DateTime dateTime) {
  return DateFormat('dd/MM/yyyy - HH:mm').format(dateTime);
}
