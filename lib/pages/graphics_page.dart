import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/appointment_model.dart';
import '../services/firebase_service.dart';
import '../services/firebase_constants.dart';

class GraphicsPage extends StatefulWidget {
  const GraphicsPage({super.key});

  @override
  State<GraphicsPage> createState() => _GraphicsPageState();
}

class _GraphicsPageState extends State<GraphicsPage> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = true;
  String? _errorMessage;
  
  // Datos para las gráficas
  List<MonthlyAppointmentData> _monthlyAppointments = [];
  int _pendingCount = 0;
  int _confirmedCount = 0;
  int _cancelledCount = 0;
  
  // Estados para interactividad
  int? _touchedIndex; // Para la gráfica de líneas
  int? _touchedPieIndex; // Para la gráfica de pastel
  
  // Animaciones
  late AnimationController _animationController;
  late Animation<double> _animation;
  

  @override
  void initState() {
    super.initState();
    // Inicializar animación
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    _initializeAndLoad();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeAndLoad() async {
    try {
      // Inicializar formato de fecha para español
      await initializeDateFormatting('es', null);
    } catch (e) {
      debugPrint('Error inicializando formato de fecha: $e');
    }
    _loadChartData();
  }

  Future<void> _loadChartData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'No hay usuario autenticado';
          _isLoading = false;
        });
        return;
      }

      // Obtener el doctorDocId del médico
      final doctorDocId = await FirebaseService.getDoctorDocId(user.uid);
      final finalDoctorDocId = doctorDocId ?? user.uid;

      // Usar el servicio unificado para obtener todas las citas
      final appointments = await FirebaseService.getAppointments(finalDoctorDocId);

      debugPrint('Graphics: Total citas encontradas: ${appointments.length}');
      if (appointments.isNotEmpty) {
        debugPrint('Graphics: Ejemplo - doctorDocId: ${appointments.first.doctorDocId}, status: ${appointments.first.status}, fecha: ${appointments.first.date}');
      } else {
        debugPrint('Graphics: ⚠️ No se encontraron citas.');
      }

      // Procesar datos para gráfica de citas por mes
      _processMonthlyData(appointments);
      
      // Procesar datos para gráfica de completadas vs canceladas
      _processStatusData(appointments);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar datos: $e';
        _isLoading = false;
      });
    }
  }

  void _processMonthlyData(List<AppointmentModel> appointments) {
    final Map<String, int> monthlyMap = {};
    
    for (var appointment in appointments) {
      final monthKey = DateFormat('yyyy-MM').format(appointment.createdAt);
      monthlyMap[monthKey] = (monthlyMap[monthKey] ?? 0) + 1;
    }

    _monthlyAppointments = monthlyMap.entries
        .map((entry) {
          final date = DateTime.parse('${entry.key}-01');
          return MonthlyAppointmentData(
            month: DateFormat('MMM yyyy', 'es').format(date),
            count: entry.value,
            date: date,
          );
        })
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  void _processStatusData(List<AppointmentModel> appointments) {
    _pendingCount = appointments.where((a) {
      final status = a.status.toLowerCase();
      return status == 'pending' || status == 'pendiente';
    }).length;
    
    _confirmedCount = appointments.where((a) {
      final status = a.status.toLowerCase();
      return status == 'confirmed' || status == 'confirmada';
    }).length;
    
    _cancelledCount = appointments.where((a) {
      final status = a.status.toLowerCase();
      return status == 'cancelled' || status == 'cancelada';
    }).length;
    
    debugPrint('📊 Estado de citas procesado:');
    debugPrint('   Pendientes: $_pendingCount');
    debugPrint('   Confirmadas: $_confirmedCount');
    debugPrint('   Canceladas: $_cancelledCount');
    debugPrint('   Total: ${_pendingCount + _confirmedCount + _cancelledCount}');
    
    // Debug: mostrar algunos estados de ejemplo
    if (appointments.isNotEmpty) {
      debugPrint('   Ejemplos de estados encontrados:');
      for (var apt in appointments.take(5)) {
        debugPrint('     - Status: "${apt.status}"');
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gráficas y Estadísticas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChartData,
            tooltip: 'Actualizar datos',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando datos...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadChartData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadChartData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Gráfica 1: Citas creadas por mes
                        _buildMonthlyAppointmentsChart(),
                        const SizedBox(height: 24),
                        
                        // Gráfica 2: Citas completadas vs canceladas
                        _buildStatusPieChart(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildMonthlyAppointmentsChart() {
    if (_monthlyAppointments.isEmpty) {
      return _buildEmptyChartCard(
        title: 'Citas Creadas por Mes',
        message: 'No hay datos disponibles',
      );
    }

    final maxCount = _monthlyAppointments.map((e) => e.count).reduce((a, b) => a > b ? a : b);
    final interval = (maxCount / 5).ceil().toDouble();
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.teal[700]),
                const SizedBox(width: 8),
                const Text(
                  'Citas Creadas por Mes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Total de citas agendadas en cada mes',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            // Mostrar información del punto seleccionado
            if (_touchedIndex != null && _touchedIndex! >= 0 && _touchedIndex! < _monthlyAppointments.length)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal[200]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoItem(
                      'Mes',
                      _monthlyAppointments[_touchedIndex!].month,
                      Colors.teal[700]!,
                    ),
                    _buildInfoItem(
                      'Citas',
                      '${_monthlyAppointments[_touchedIndex!].count}',
                      Colors.teal[700]!,
                    ),
                  ],
                ),
              ),
            SizedBox(
              height: 250,
              child: FadeTransition(
                opacity: _animation,
                child: LineChart(
                  LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300]!,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && 
                              value.toInt() < _monthlyAppointments.length) {
                            final month = _monthlyAppointments[value.toInt()].month;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                month.split(' ')[0],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                        reservedSize: 40,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: interval,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[700],
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  minX: 0,
                  maxX: (_monthlyAppointments.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxCount + interval,
                  lineBarsData: [
                    LineChartBarData(
                      spots: _monthlyAppointments.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.count.toDouble());
                      }).toList(),
                      isCurved: true,
                      color: Colors.teal,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          final isTouched = _touchedIndex == index;
                          return FlDotCirclePainter(
                            radius: isTouched ? 6 : 4,
                            color: isTouched ? Colors.teal[700]! : Colors.teal,
                            strokeWidth: isTouched ? 3 : 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.teal.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => Colors.teal[700]!,
                      tooltipRoundedRadius: 8,
                      tooltipPadding: const EdgeInsets.all(12),
                      tooltipMargin: 8,
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((LineBarSpot touchedSpot) {
                          final index = touchedSpot.x.toInt();
                          if (index >= 0 && index < _monthlyAppointments.length) {
                            final data = _monthlyAppointments[index];
                            return LineTooltipItem(
                              '${data.month}\n${touchedSpot.y.toInt()} citas',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            );
                          }
                          return null;
                        }).toList();
                      },
                    ),
                    handleBuiltInTouches: true,
                    getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                      return spotIndexes.map((index) {
                        return TouchedSpotIndicatorData(
                          FlLine(
                            color: Colors.teal[700]!,
                            strokeWidth: 2,
                            dashArray: [4, 4],
                          ),
                          FlDotData(
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 6,
                                color: Colors.white,
                                strokeWidth: 3,
                                strokeColor: Colors.teal[700]!,
                              );
                            },
                          ),
                        );
                      }).toList();
                    },
                    touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                      if (!event.isInterestedForInteractions ||
                          touchResponse == null ||
                          touchResponse.lineBarSpots == null) {
                        setState(() {
                          _touchedIndex = null;
                        });
                        return;
                      }
                      final spot = touchResponse.lineBarSpots!.first;
                      setState(() {
                        _touchedIndex = spot.x.toInt();
                      });
                    },
                  ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLegend([
              LegendItem('Citas creadas', Colors.teal),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPieChart() {
    final total = _pendingCount + _confirmedCount + _cancelledCount;
    debugPrint('🎨 _buildStatusPieChart: total=$total (pending=$_pendingCount, confirmed=$_confirmedCount, cancelled=$_cancelledCount)');
    
    if (total == 0) {
      debugPrint('⚠️ No hay citas para mostrar en la gráfica');
      return _buildEmptyChartCard(
        title: 'Estado de las Citas',
        message: 'No hay datos disponibles. Crea algunas citas para ver la gráfica.',
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: Colors.teal[700]),
                const SizedBox(width: 8),
                const Text(
                  'Estado de las Citas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Distribución de citas: Confirmadas, Canceladas y Por Confirmar',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: FadeTransition(
                opacity: _animation,
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 60,
                          sections: [
                            // Por Confirmar (Pendientes)
                            PieChartSectionData(
                              value: _pendingCount.toDouble(),
                              title: _touchedPieIndex == 0 
                                  ? '$_pendingCount\n(${((_pendingCount / total) * 100).toStringAsFixed(1)}%)'
                                  : '${((_pendingCount / total) * 100).toStringAsFixed(1)}%',
                              color: _touchedPieIndex == 0 ? Colors.orange[700] : Colors.orange,
                              radius: _touchedPieIndex == 0 ? 90 : 80,
                              titleStyle: TextStyle(
                                fontSize: _touchedPieIndex == 0 ? 12 : 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            // Confirmadas
                            PieChartSectionData(
                              value: _confirmedCount.toDouble(),
                              title: _touchedPieIndex == 1
                                  ? '$_confirmedCount\n(${((_confirmedCount / total) * 100).toStringAsFixed(1)}%)'
                                  : '${((_confirmedCount / total) * 100).toStringAsFixed(1)}%',
                              color: _touchedPieIndex == 1 ? Colors.blue[700] : Colors.blue,
                              radius: _touchedPieIndex == 1 ? 90 : 80,
                              titleStyle: TextStyle(
                                fontSize: _touchedPieIndex == 1 ? 12 : 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            // Canceladas
                            PieChartSectionData(
                              value: _cancelledCount.toDouble(),
                              title: _touchedPieIndex == 2
                                  ? '$_cancelledCount\n(${((_cancelledCount / total) * 100).toStringAsFixed(1)}%)'
                                  : '${((_cancelledCount / total) * 100).toStringAsFixed(1)}%',
                              color: _touchedPieIndex == 2 ? Colors.red[700] : Colors.red,
                              radius: _touchedPieIndex == 2 ? 90 : 80,
                              titleStyle: TextStyle(
                                fontSize: _touchedPieIndex == 2 ? 12 : 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                          pieTouchData: PieTouchData(
                            enabled: true,
                            touchCallback: (FlTouchEvent event, pieTouchResponse) {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                setState(() {
                                  _touchedPieIndex = null;
                                });
                                return;
                              }
                              setState(() {
                                _touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem('Por Confirmar', Colors.orange, _pendingCount),
                        const SizedBox(height: 16),
                        _buildLegendItem('Confirmadas', Colors.blue, _confirmedCount),
                        const SizedBox(height: 16),
                        _buildLegendItem('Canceladas', Colors.red, _cancelledCount),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.teal[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                total.toString(),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildLegend(List<LegendItem> items) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: item.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
        ),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyChartCard({
    required String title,
    required String message,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Clases de datos auxiliares
class MonthlyAppointmentData {
  final String month;
  final int count;
  final DateTime date;

  MonthlyAppointmentData({
    required this.month,
    required this.count,
    required this.date,
  });
}


class LegendItem {
  final String label;
  final Color color;

  LegendItem(this.label, this.color);
}

