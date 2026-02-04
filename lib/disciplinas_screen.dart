import 'package:flutter/material.dart';
import 'package:appmantflutter/shared/disciplinas_config.dart';
import 'package:appmantflutter/disciplinas/categorias_disciplina_screen.dart';

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
    DisciplinaData('mobiliarios', 'Mobiliarios', Icons.chair, primaryRed),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Disciplinas'),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Seleccione una Disciplina',
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
              children: disciplinas.map((item) {
                return _DisciplinaCard(item: item);
              }).toList(),
            ),
          ],
        ),
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
    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoriasDisciplinaScreen(
                disciplinaId: item.id,
                disciplinaNombre: item.nombre,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: cardSize,
          height: cardSize * 0.85,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                size: 50,
                color: item.color,
              ),
              const SizedBox(height: 15),
              Text(
                item.nombre,
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
