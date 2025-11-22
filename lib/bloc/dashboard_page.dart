import 'package:citas_medicas/bloc/dashboard_bloc.dart';
import 'package:citas_medicas/bloc/dashboard_state.dart';
import 'package:citas_medicas/bloc/dashboard_event.dart';
import 'package:flutter/material.dart';
import '../routes.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/firebase_service.dart';
import '../services/firebase_constants.dart';

/// Página del Dashboard Médico
/// 
/// FLUJO DE DATOS DESDE FIREBASE:
/// 
/// 1. **Verificación de Usuario**:
///    - Usa `FirebaseService.getCurrentUser()` para obtener el usuario autenticado
///    - Usa `FirebaseService.getUser(uid)` para obtener información completa del usuario desde Firestore
///    - Verifica que el usuario tenga rol de 'doctor'
/// 
/// 2. **Carga de Estadísticas**:
///    - El `DashboardBloc` maneja la carga de estadísticas mediante eventos:
///      - `LoadDashboardStats`: Carga estadísticas del médico autenticado
///      - `LoadDashboardStatsFor`: Carga estadísticas de un médico específico
/// 
/// 3. **Obtención de Datos**:
///    - El `DashboardBloc` usa `FirebaseService.getAppointmentStats()` para obtener:
///      - Total de citas
///      - Citas pendientes
///      - Citas de hoy
///      - Total de pacientes
///    - Los datos se actualizan en tiempo real mediante streams de Firebase
/// 
/// 4. **Actualización en Tiempo Real**:
///    - `FirebaseService.getAppointmentsStream()` proporciona un stream que emite
///      actualizaciones automáticas cuando cambian las citas en Firestore
///    - El BLoC recalcula las estadísticas cada vez que hay cambios
/// 
/// VENTAJAS DE USAR EL SERVICIO UNIFICADO:
/// - Código más limpio y mantenible
/// - Manejo consistente de errores
/// - Fácil de testear
/// - Centralización de la lógica de Firebase

class DashboardPage extends StatefulWidget {
  final String? doctorId;
  final String? specialty;
  const DashboardPage({Key? key, this.doctorId, this.specialty}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _checkingRole = true;

  @override
  void initState() {
    super.initState();
    if (widget.doctorId != null) {
      // Si se pasa doctorId, cargar dashboard filtrado para ese médico/especialidad
      // No necesita verificar rol porque ya se conoce el médico
      context.read<DashboardBloc>().add(LoadDashboardStatsFor(widget.doctorId!, specialty: widget.specialty));
      setState(() => _checkingRole = false);
    } else {
      // Verificar rol del usuario actual y cargar estadísticas
      _checkRoleAndLoad();
    }
  }


  /// Verifica el rol del usuario usando el servicio unificado de Firebase
  /// 
  /// Si el usuario no está autenticado o no es médico, redirige a la página correspondiente.
  /// Si es médico, carga las estadísticas del dashboard.
  Future<void> _checkRoleAndLoad() async {
    if (widget.doctorId != null) return; // No comprobar rol si se pasa doctorId
    
    try {
      // Obtener usuario actual usando el servicio unificado
      final user = FirebaseService.getCurrentUser();
      if (user == null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, Routes.login);
        }
        return;
      }
      
      // Obtener información del usuario desde Firestore usando el servicio unificado
      final userModel = await FirebaseService.getUser(user.uid);
      
      if (userModel == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo obtener la información del usuario.'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pushReplacementNamed(context, Routes.login);
        }
        return;
      }
      
      // Verificar que el usuario sea médico
      if (userModel.role != UserRole.doctor) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Acceso restringido: esta pantalla es solo para médicos.'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pushReplacementNamed(context, Routes.home);
        }
        return;
      }
      
      // Si es médico, cargar las estadísticas del dashboard
      if (mounted) {
        context.read<DashboardBloc>().add(LoadDashboardStats());
        setState(() => _checkingRole = false);
      }
    } catch (e) {
      debugPrint('Error en _checkRoleAndLoad: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error comprobando rol: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pushReplacementNamed(context, Routes.home);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mientras comprobamos el rol mostramos indicador
    if (_checkingRole) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Eliminamos la verificación de 'user == null' aquí, ahora está en el Bloc.

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Médico'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () {
              context.read<DashboardBloc>().add(LoadDashboardStats());
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Ver Gráficas',
            onPressed: () {
              Navigator.pushNamed(context, Routes.graphics);
            },
          ),
        ],
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          debugPrint('🎨 BlocBuilder: Construyendo UI con estado: ${state.runtimeType}');
          
          // Estado de carga: esperando datos de Firebase
          if (state is DashboardLoading) {
            debugPrint('⏳ Estado: Loading - Obteniendo datos de Firebase...');
            return const Center(child: CircularProgressIndicator());
          }

          // Estado de error: problema al obtener datos de Firebase
          if (state is DashboardError) {
            debugPrint('❌ Estado: Error - ${state.message}');
            return _buildErrorScreen('Error: ${state.message}');
          }

          // Estado cargado: datos obtenidos exitosamente de Firebase
          if (state is DashboardLoaded) {
            final stats = state.stats;
            debugPrint('═══════════════════════════════════════════════════════════');
            debugPrint('🎨 DASHBOARD UI - Estadísticas desde Firebase:');
            debugPrint('   - totalAppointments: ${stats['totalAppointments']}');
            debugPrint('   - pendingAppointments: ${stats['pendingAppointments']}');
            debugPrint('   - todayAppointments: ${stats['todayAppointments']}');
            debugPrint('   - totalPatients: ${stats['totalPatients']}');
            debugPrint('═══════════════════════════════════════════════════════════');
            // Construir la interfaz con los datos obtenidos de Firebase
            return _buildDashboardContent(stats);
          }

          // Estado inicial: aún no se han solicitado datos
          debugPrint('⚠️ Estado: Desconocido - ${state.runtimeType}');
          return const Center(child: Text('Cargando resumen...'));
        },
      ),
    );
  }

  /// Construye el contenido del Dashboard con las estadísticas obtenidas de Firebase
  /// 
  /// [stats] - Mapa con las estadísticas obtenidas de Firebase:
  ///   - 'totalAppointments': Total de citas del médico
  ///   - 'pendingAppointments': Citas pendientes
  ///   - 'todayAppointments': Citas programadas para hoy
  ///   - 'totalPatients': Total de pacientes únicos
  Widget _buildDashboardContent(Map<String, int> stats) {
    debugPrint('🏗️ _buildDashboardContent: Construyendo UI con stats desde Firebase: $stats');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con saludo
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade600, Colors.teal.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_hospital,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dashboard Médico',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Resumen de tu actividad',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Botón para gestionar citas
          GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, Routes.appointments);
                },
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.teal.shade600,
                          Colors.teal.shade400,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.event_note,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Gestionar Citas',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ver y administrar todas tus citas',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Título de sección
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.teal.shade700,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Indicadores Principales',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Grid con los 3 indicadores requeridos + bonus
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  // 1. Total de citas creadas
                  _buildStatCard(
                'Total de Citas',
                (stats['totalAppointments'] ?? 0).toString(),
                Icons.calendar_today_rounded,
                Colors.blue,
                'Todas las citas registradas',
              ),
              // 2. Citas próximas o pendientes
              _buildStatCard(
                'Citas Pendientes',
                (stats['pendingAppointments'] ?? 0).toString(),
                Icons.pending_actions_rounded,
                Colors.orange,
                'Citas por confirmar',
              ),
              // 3. Total de pacientes registrados
              _buildStatCard(
                'Pacientes',
                (stats['totalPatients'] ?? 0).toString(),
                Icons.people_rounded,
                Colors.green,
                'Pacientes registrados',
              ),
              // Bonus: Citas de hoy
              _buildStatCard(
                'Citas Hoy',
                (stats['todayAppointments'] ?? 0).toString(),
                Icons.today_rounded,
                Colors.purple,
                'Citas programadas hoy',
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Mantenemos los métodos auxiliares:
  Widget _buildErrorScreen(String message) {
    // Pantalla de error simple
    return Scaffold(
      body: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.red, fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Helper para obtener un color más oscuro
  Color _getDarkerColor(Color color) {
    // Si es un MaterialColor, usar shade700, sino oscurecer manualmente
    if (color is MaterialColor) {
      return color.shade700;
    }
    // Oscurecer el color manualmente usando la nueva API
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness * 0.7).clamp(0.0, 1.0)).toColor();
  }

  /// Tarjeta de estadística para el dashboard médico
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    debugPrint('🎴 _buildStatCard: $title = "$value"');
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _getDarkerColor(color),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}