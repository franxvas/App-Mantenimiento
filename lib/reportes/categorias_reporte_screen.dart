import 'package:flutter/material.dart';
import 'package:appmantflutter/reportes/lista_reportes_por_categoria_screen.dart';
import 'package:appmantflutter/shared/disciplinas_config.dart';
import 'package:appmantflutter/services/categorias_service.dart';

class CategoriasReporteScreen extends StatefulWidget {
  final String disciplinaId;
  final String disciplinaNombre;

  const CategoriasReporteScreen({
    super.key,
    required this.disciplinaId,
    required this.disciplinaNombre,
  });

  @override
  State<CategoriasReporteScreen> createState() => _CategoriasReporteScreenState();
}

class _CategoriasReporteScreenState extends State<CategoriasReporteScreen> {
  final _categoriasService = CategoriasService.instance;

  @override
  void initState() {
    super.initState();
    _categoriasService.ensureSeededForDisciplina(widget.disciplinaId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          "Reportes de ${widget.disciplinaNombre}",
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 25),
            child: Text(
              "Seleccione una Categoría",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF34495E),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<CategoriaItem>>(
              stream: _categoriasService.streamByDisciplina(widget.disciplinaId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final categorias = snapshot.data ?? const <CategoriaItem>[];
                if (categorias.isEmpty) {
                  return const Center(child: Text('No hay categorías disponibles.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: categorias.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 15),
                  itemBuilder: (context, index) {
                    final item = categorias[index];
                    return _CategoriaCard(
                      nombre: item.label,
                      icon: item.icon,
                      color: primaryRed,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ListaReportesPorCategoriaScreen(
                              categoriaFilter: item.value,
                              categoriaTitle: item.label,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoriaCard extends StatelessWidget {
  final String nombre;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CategoriaCard({
    required this.nombre,
    required this.icon,
    required this.color,
    required this.onTap,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
                onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Row(
              children: [
                Icon(icon, size: 30, color: color),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    nombre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
