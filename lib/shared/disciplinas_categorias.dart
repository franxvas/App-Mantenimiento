import 'package:flutter/material.dart';

class CategoriaDisciplina {
  final String value;
  final String label;
  final IconData icon;

  const CategoriaDisciplina({
    required this.value,
    required this.label,
    required this.icon,
  });
}

List<CategoriaDisciplina> categoriasPorDisciplina(String disciplinaKey) {
  switch (disciplinaKey.toLowerCase()) {
    case 'electricas':
      return const [
        CategoriaDisciplina(value: 'luminarias', label: 'Luminarias', icon: Icons.lightbulb),
        CategoriaDisciplina(value: 'aparatos eléctricos', label: 'Aparatos Eléctricos', icon: Icons.smart_toy),
        CategoriaDisciplina(value: 'tableros eléctricos', label: 'Tableros Eléctricos', icon: Icons.flash_on),
      ];
    case 'arquitectura':
      return const [
        CategoriaDisciplina(value: 'acabados', label: 'Acabados', icon: Icons.format_paint),
        CategoriaDisciplina(value: 'carpintería', label: 'Carpintería', icon: Icons.door_front_door),
      ];
    case 'estructuras':
      return const [
        CategoriaDisciplina(value: 'vigas y columnas', label: 'Vigas y Columnas', icon: Icons.view_column),
      ];
    case 'mecanica':
      return const [
        CategoriaDisciplina(value: 'bombas de agua', label: 'Bombas de Agua', icon: Icons.cyclone),
      ];
    case 'sanitarias':
      return const [
        CategoriaDisciplina(value: 'griferías', label: 'Griferías', icon: Icons.water_drop),
      ];
    case 'mobiliarios':
      return const [
        CategoriaDisciplina(value: 'sillas', label: 'Sillas', icon: Icons.chair),
        CategoriaDisciplina(value: 'mesas', label: 'Mesas', icon: Icons.table_restaurant),
        CategoriaDisciplina(value: 'estantes', label: 'Estantes', icon: Icons.inventory_2),
      ];
    default:
      return const [];
  }
}
