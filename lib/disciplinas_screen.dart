import 'package:flutter/material.dart';
import 'package:appmantflutter/productos/lista_productos_screen.dart';
import 'package:appmantflutter/shared/disciplinas_config.dart';

class DisciplinaData {
  final String id;
  final String nombre;
  final IconData icon;
  final Color color;

  DisciplinaData(this.id, this.nombre, this.icon, this.color);
}

class DisciplinasScreen extends StatelessWidget {
  const DisciplinasScreen({super.key});

  static final List<DisciplinaData> disciplinas = [
    DisciplinaData('arquitectura', 'Arquitectura', Icons.account_balance, primaryRed),
    DisciplinaData('electricas', 'Eléctricas', Icons.bolt, primaryRed),
    DisciplinaData('estructuras', 'Estructuras', Icons.domain, primaryRed),
    DisciplinaData('mecanica', 'Mecánica', Icons.settings, primaryRed),
    DisciplinaData('sanitarias', 'Sanitarias', Icons.water_drop, primaryRed),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Disciplinas'),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Seleccione una Disciplina',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF34495e),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(15),
              child: Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: disciplinas.map((item) {
                  return _DisciplinaCard(item: item);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisciplinaCard extends StatelessWidget {
  final DisciplinaData item;

  const _DisciplinaCard({required this.item, super.key});

  @override
  Widget build(BuildContext context) {
    final double cardSize = (MediaQuery.of(context).size.width / 2) - 30;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ListaProductosScreen(
                filterBy: 'disciplina',
                filterValue: item.id,
                title: item.nombre,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: cardSize,
          height: cardSize * 0.85,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                size: 40,
                color: item.color,
              ),
              const SizedBox(height: 15),
              Text(
                item.nombre,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF34495e),
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
