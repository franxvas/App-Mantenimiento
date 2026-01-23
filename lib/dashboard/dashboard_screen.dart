import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  
  // Datos para Gráficos
  int _totalOperativos = 0;
  int _totalFalla = 0;
  List<int> _reportesPorDia = List.filled(7, 0); // Lun-Dom
  Map<String, int> _topFallas = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final db = FirebaseFirestore.instance;
      final productosRef = db.collection('productos').withConverter<Map<String, dynamic>>(
            fromFirestore: (snapshot, _) => snapshot.data() ?? {},
            toFirestore: (data, _) => data,
          );
      final reportesRef = db.collection('reportes').withConverter<Map<String, dynamic>>(
            fromFirestore: (snapshot, _) => snapshot.data() ?? {},
            toFirestore: (data, _) => data,
          );

      // 1. CARGAR ESTADO DE EQUIPOS
      final operativosSnapshot = await productosRef.where('estado', isEqualTo: 'operativo').count().get();
      final fallasSnapshot = await productosRef.where('estado', isEqualTo: 'fuera de servicio').count().get();

      _totalOperativos = operativosSnapshot.count ?? 0;
      _totalFalla = fallasSnapshot.count ?? 0;

      // 2. CARGAR REPORTES DE LA ÚLTIMA SEMANA
      final hoy = DateTime.now();
      final hace7dias = hoy.subtract(const Duration(days: 7));
      
      final reportesSnapshot = await reportesRef
          .where('fecha', isGreaterThanOrEqualTo: hace7dias)
          .get();

      List<int> tempReportesPorDia = List.filled(7, 0);
      Map<String, int> tempFallas = {};

      for (var doc in reportesSnapshot.docs) {
        final data = doc.data();
        final Timestamp? ts = data['fecha'];
        final String nombreEquipo = data['activo_nombre'] ?? 'Desconocido';

        if (ts != null) {
          final fecha = ts.toDate();
          int diaIndex = fecha.weekday - 1; 
          if (diaIndex >= 0 && diaIndex < 7) {
             tempReportesPorDia[diaIndex]++;
          }
        }

        // Contar para Top Fallas
        if (tempFallas.containsKey(nombreEquipo)) {
          tempFallas[nombreEquipo] = tempFallas[nombreEquipo]! + 1;
        } else {
          tempFallas[nombreEquipo] = 1;
        }
      }

      if (mounted) {
        setState(() {
          _reportesPorDia = tempReportesPorDia;
          _topFallas = tempFallas;
          _isLoading = false;
        });
      }

    } catch (e) {
      print("Error cargando dashboard: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- CORRECCIÓN AQUÍ: Preparamos la lista ordenada antes de usarla ---
    final topFallasList = _topFallas.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Ordenamos de mayor a menor
    
    // Tomamos solo los 5 primeros
    final top5Fallas = topFallasList.take(5).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Dashboard Gerencial"),
        backgroundColor: const Color(0xFF2C3E50),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        actions: [
          IconButton(onPressed: _cargarDatos, icon: const Icon(Icons.refresh, color: Colors.white))
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- GRÁFICO DE PASTEL ---
                  const Text("Estado del Inventario", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: _totalOperativos == 0 && _totalFalla == 0 
                      ? const Center(child: Text("No hay datos de productos"))
                      : PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: [
                            PieChartSectionData(
                              color: const Color(0xFF2ECC71),
                              value: _totalOperativos.toDouble(),
                              title: '$_totalOperativos\nOK',
                              radius: 60,
                              titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            PieChartSectionData(
                              color: const Color(0xFFE74C3C),
                              value: _totalFalla.toDouble(),
                              title: '$_totalFalla\nMal',
                              radius: 60,
                              titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LegendItem(color: Color(0xFF2ECC71), text: "Operativo"),
                      SizedBox(width: 20),
                      _LegendItem(color: Color(0xFFE74C3C), text: "Fuera de Servicio"),
                    ],
                  ),

                  const Divider(height: 40),

                  // --- GRÁFICO DE BARRAS ---
                  const Text("Reportes: Últimos 7 Días", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 250,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: (_reportesPorDia.reduce((curr, next) => curr > next ? curr : next) + 2).toDouble(),
                        barTouchData: BarTouchData(enabled: true),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                const style = TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12);
                                switch (value.toInt()) {
                                  case 0: return const Text('L', style: style);
                                  case 1: return const Text('M', style: style);
                                  case 2: return const Text('M', style: style);
                                  case 3: return const Text('J', style: style);
                                  case 4: return const Text('V', style: style);
                                  case 5: return const Text('S', style: style);
                                  case 6: return const Text('D', style: style);
                                  default: return const Text('', style: style);
                                }
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: _reportesPorDia.asMap().entries.map((entry) {
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY: entry.value.toDouble(),
                                color: const Color(0xFF3498DB),
                                width: 16,
                                borderRadius: BorderRadius.circular(4),
                              )
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const Divider(height: 40),

                  // --- TOP FALLAS (CORREGIDO) ---
                  const Text("Top Equipos con Reportes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                  const SizedBox(height: 10),
                  
                  // Usamos la lista ya preparada 'top5Fallas'
                  ...top5Fallas.map((entry) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(backgroundColor: Color(0xFFFAD7A0), child: Icon(Icons.warning_amber, color: Color(0xFFE67E22))),
                          title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Text("${entry.value} reportes", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      );
                  }),
                    
                  if (top5Fallas.isEmpty)
                    const Padding(padding: EdgeInsets.all(10), child: Text("No hay reportes recientes.")),
                    
                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;
  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
