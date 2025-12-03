import 'package:citas_medicas/bloc/dashboard_bloc.dart';
import 'package:citas_medicas/bloc/dashboard_state.dart';
import 'package:citas_medicas/bloc/dashboard_event.dart';
import 'package:flutter/material.dart';
import '../routes.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/firebase_service.dart';
import '../services/firebase_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_colors.dart';

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
        title: Text('Dashboard Médico', style: AppTextStyles.heading3),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.softBlack,
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
            padding: const EdgeInsets.all(AppStyles.paddingLarge),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppStyles.cardRadius),
              boxShadow: AppColors.elevatedShadow,
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
                      Text(
                        'Dashboard Médico',
                        style: AppTextStyles.heading2.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Resumen de tu actividad',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.white.withOpacity(0.95),
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
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppStyles.cardRadius),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppStyles.cardRadius),
                      gradient: AppColors.bluePurpleGradient,
                      boxShadow: AppColors.cardShadow,
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
                              Text(
                                'Gestionar Citas',
                                style: AppTextStyles.heading3.copyWith(
                                  color: AppColors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Ver y administrar todas tus citas',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.white.withOpacity(0.95),
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
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Indicadores Principales',
                    style: AppTextStyles.heading3.copyWith(
                      color: AppColors.softBlack,
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
                AppColors.primaryBlue,
                'Todas las citas registradas',
              ),
              // 2. Citas próximas o pendientes
              _buildStatCard(
                'Citas Pendientes',
                (stats['pendingAppointments'] ?? 0).toString(),
                Icons.pending_actions_rounded,
                AppColors.softPurple,
                'Citas por confirmar',
              ),
              // 3. Total de pacientes registrados
              _buildStatCard(
                'Pacientes',
                (stats['totalPatients'] ?? 0).toString(),
                Icons.people_rounded,
                AppColors.primaryBlue,
                'Pacientes registrados',
              ),
              // Bonus: Citas de hoy
              _buildStatCard(
                'Citas Hoy',
                (stats['todayAppointments'] ?? 0).toString(),
                Icons.today_rounded,
                AppColors.softPurple,
                'Citas programadas hoy',
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Botón de salir de sesión
          _buildLogoutButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Construye el botón de salir de sesión
  Widget _buildLogoutButton() {
    return Center(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyles.cardRadius),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppStyles.cardRadius),
            gradient: AppColors.primaryGradient,
            boxShadow: AppColors.cardShadow,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _handleLogout(),
              borderRadius: BorderRadius.circular(AppStyles.cardRadius),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Salir de Sesión',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Maneja el proceso de cierre de sesión
  Future<void> _handleLogout() async {
    // Mostrar diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro de que deseas salir de tu sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
              ),
              child: const Text('Salir'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushReplacementNamed(context, Routes.login);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cerrar sesión: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  // Mantenemos los métodos auxiliares:
  Widget _buildErrorScreen(String message) {
    // Pantalla de error simple
    return Scaffold(
      body: Center(
        child: Text(
          message,
          style: TextStyle(color: AppColors.error, fontSize: 18),
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppStyles.cardRadius),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppStyles.cardRadius),
          boxShadow: AppColors.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppStyles.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: color,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: AppTextStyles.heading1.copyWith(
                  fontSize: 36,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.heading3.copyWith(
                  color: AppColors.softBlack,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.mediumGrey,
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