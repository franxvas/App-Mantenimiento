import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:appmantflutter/productos/detalle_producto_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  
  int _totalOperativos = 0;
  int _totalDefectuosos = 0;
  int _totalFueraServicio = 0;
  List<int> _reportesPorDia = List.filled(7, 0);
  List<String> _labelsDias = List.filled(7, '');
  List<_TopEquipo> _topEquipos = [];

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

      final operativosSnapshot = await productosRef.where('estado', isEqualTo: 'operativo').count().get();
      final defectuososSnapshot = await productosRef.where('estado', isEqualTo: 'defectuoso').count().get();
      final fueraServicioSnapshot = await productosRef
          .where('estado', whereIn: ['fuera de servicio', 'fuera_servicio'])
          .count()
          .get();

      _totalOperativos = operativosSnapshot.count ?? 0;
      _totalDefectuosos = defectuososSnapshot.count ?? 0;
      _totalFueraServicio = fueraServicioSnapshot.count ?? 0;

      final hoy = DateTime.now();
      final inicio = DateTime(hoy.year, hoy.month, hoy.day).subtract(const Duration(days: 6));
      final labelsDias = List.generate(
        7,
        (index) => DateFormat('E').format(inicio.add(Duration(days: index))).substring(0, 1).toUpperCase(),
      );

      final snapshots = await Future.wait([
        reportesRef.where('fechaInspeccion', isGreaterThanOrEqualTo: inicio).get(),
        reportesRef.where('fecha', isGreaterThanOrEqualTo: inicio).get(),
      ]);

      final uniqueDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          uniqueDocs[doc.reference.path] = doc;
        }
      }

      final tempReportesPorDia = List<int>.filled(7, 0);
      final conteoPorEquipo = <String, int>{};

      for (final doc in uniqueDocs.values) {
        final data = doc.data();
        final rawDate = data['fechaInspeccion'] ?? data['fecha'];
        final date = _resolveReportDate(rawDate);
        if (date == null) {
          continue;
        }
        final difference = date.difference(inicio).inDays;
        if (difference >= 0 && difference < 7) {
          tempReportesPorDia[difference]++;
        }

        final productId = data['productId'] ?? doc.reference.parent.parent?.id;
        if (productId == null) {
          continue;
        }
        conteoPorEquipo[productId] = (conteoPorEquipo[productId] ?? 0) + 1;
      }

      final top5Ids = conteoPorEquipo.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topIds = top5Ids.take(5).map((entry) => entry.key).toList();
      final topEquipos = <_TopEquipo>[];
      if (topIds.isNotEmpty) {
        final docs = await Future.wait(
          topIds.map((id) => productosRef.doc(id).get()),
        );
        for (var i = 0; i < docs.length; i++) {
          final doc = docs[i];
          if (!doc.exists) continue;
          final data = doc.data() ?? {};
          topEquipos.add(
            _TopEquipo(
              productId: doc.id,
              nombre: (data['nombre'] ?? data['nombreProducto'] ?? 'Activo').toString(),
              imagenUrl: data['imagenUrl']?.toString(),
              totalReportes: conteoPorEquipo[doc.id] ?? 0,
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _reportesPorDia = tempReportesPorDia;
          _labelsDias = labelsDias;
          _topEquipos = topEquipos;
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
    final totalInventario = _totalOperativos + _totalDefectuosos + _totalFueraServicio;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Dashboard Gerencial"),
        titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(fontWeight: FontWeight.bold),
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
                  const Text("Estado del Inventario", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: totalInventario == 0 
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
                              color: const Color(0xFFF39C12),
                              value: _totalDefectuosos.toDouble(),
                              title: '$_totalDefectuosos\nDef',
                              radius: 60,
                              titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            PieChartSectionData(
                              color: const Color(0xFFE74C3C),
                              value: _totalFueraServicio.toDouble(),
                              title: '$_totalFueraServicio\nFS',
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
                      _LegendItem(color: Color(0xFFF39C12), text: "Defectuoso"),
                      SizedBox(width: 20),
                      _LegendItem(color: Color(0xFFE74C3C), text: "Fuera de Servicio"),
                    ],
                  ),

                  const Divider(height: 40),

                  const Text("Reportes: Últimos 7 Días", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 250,
                    child: _reportesPorDia.every((value) => value == 0)
                        ? const Center(child: Text("No hay reportes recientes."))
                        : BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: (_reportesPorDia.reduce((curr, next) => curr > next ? curr : next) + 2).toDouble(),
                              barTouchData: BarTouchData(
                                enabled: true,
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                    final value = rod.toY.round();
                                    return BarTooltipItem(
                                      '$value',
                                      const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        backgroundColor: Color(0xFF8B1E1E),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (double value, TitleMeta meta) {
                                      const style = TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12);
                                      final index = value.toInt();
                                      if (index < 0 || index >= _labelsDias.length) {
                                        return const Text('', style: style);
                                      }
                                      return Text(_labelsDias[index], style: style);
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
                                      color: const Color(0xFF8B1E1E),
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

                  const Text("Top Equipos con Reportes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                  const SizedBox(height: 10),

                  if (_topEquipos.isEmpty)
                    const Padding(padding: EdgeInsets.all(10), child: Text("No hay reportes recientes."))
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _topEquipos.map((equipo) {
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetalleProductoScreen(productId: equipo.productId),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 160,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: equipo.imagenUrl != null && equipo.imagenUrl!.isNotEmpty
                                      ? Image.network(
                                          equipo.imagenUrl!,
                                          height: 80,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          height: 80,
                                          color: Colors.grey.shade200,
                                          child: const Center(
                                            child: Icon(Icons.image_not_supported, color: Colors.grey),
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  equipo.nombre,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text('${equipo.totalReportes} reportes', style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    
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

class _TopEquipo {
  final String productId;
  final String nombre;
  final String? imagenUrl;
  final int totalReportes;

  _TopEquipo({
    required this.productId,
    required this.nombre,
    required this.imagenUrl,
    required this.totalReportes,
  });
}

DateTime? _resolveReportDate(dynamic rawDate) {
  if (rawDate is Timestamp) {
    return rawDate.toDate();
  }
  if (rawDate is DateTime) {
    return rawDate;
  }
  if (rawDate is String) {
    return DateTime.tryParse(rawDate);
  }
  return null;
}
