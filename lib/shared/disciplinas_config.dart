import 'package:flutter/material.dart';

const Map<String, Color> disciplinaColors = {
  'arquitectura': Color(0xFF3498db),
  'electricas': Color(0xFFf1c40f),
  'estructuras': Color(0xFF95a5a6),
  'mecanica': Color(0xFFe67e22),
  'sanitarias': Color(0xFF1abc9c),
};

const Color primaryRed = Color(0xFF8B1E1E);

Color disciplinaColor(String id) {
  return disciplinaColors[id] ?? const Color(0xFF3498db);
}
