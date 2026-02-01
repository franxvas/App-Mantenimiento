import 'package:flutter/material.dart';
import 'package:appmantflutter/reportes/categorias_reporte_screen.dart';
import 'package:appmantflutter/shared/disciplinas_config.dart';

class ReportesScreen extends StatelessWidget {
  const ReportesScreen({super.key});

  static final List<Map<String, dynamic>> disciplinasReporte = [
    {'id': 'arquitectura', 'nombre': 'Arquitectura', 'icon': Icons.account_balance, 'color': primaryRed},
    {'id': 'electricas', 'nombre': 'Eléctricas', 'icon': Icons.bolt, 'color': primaryRed},
    {'id': 'estructuras', 'nombre': 'Estructuras', 'icon': Icons.apartment, 'color': primaryRed},
    {'id': 'mecanica', 'nombre': 'Mecánica', 'icon': Icons.miscellaneous_services, 'color': primaryRed},
    {'id': 'sanitarias', 'nombre': 'Sanitarias', 'icon': Icons.water_drop, 'color': primaryRed},
    {'id': 'mobiliarios', 'nombre': 'Mobiliarios', 'icon': Icons.chair, 'color': primaryRed},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Reportes"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Filtrar Reportes por Disciplina",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF34495E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: disciplinasReporte.map((item) {
                return _ReportCard(
                  title: item['nombre'],
                  icon: item['icon'],
                  color: item['color'],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoriasReporteScreen(
                          disciplinaId: item['id'],
                          disciplinaNombre: item['nombre'],
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ReportCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    final double cardSize = (MediaQuery.of(context).size.width / 2) - 30;

    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: cardSize,
          height: cardSize * 0.85,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 50, color: color),
              const SizedBox(height: 15),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
