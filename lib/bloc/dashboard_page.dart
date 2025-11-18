import 'package:citas_medicas/bloc/dashboard_bloc.dart';
import 'package:citas_medicas/bloc/dashboard_state.dart';
import 'package:citas_medicas/bloc/dashboard_event.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../routes.dart';
import 'package:flutter_bloc/flutter_bloc.dart';



class DashboardPage extends StatefulWidget {
  final String? doctorId;
  final String? specialty;
  const DashboardPage({Key? key, this.doctorId, this.specialty}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _checkingRole = true;

  @override
  void initState() {
    super.initState();
    if (widget.doctorId != null) {
      // Si se pasa doctorId, cargar dashboard filtrado para ese médico/especialidad
      context.read<DashboardBloc>().add(LoadDashboardStatsFor(widget.doctorId!, specialty: widget.specialty));
      setState(() => _checkingRole = false);
    } else {
      _checkRoleAndLoad();
    }
  }

  Future<void> _checkRoleAndLoad() async {
    if (widget.doctorId != null) return; // No comprobar rol si se pasa doctorId
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, Routes.login);
      return;
    }
    try {
      final doc = await _firestore.collection('usuarios').doc(user.uid).get();
      final role = doc.data()?['role'] ?? 'patient';
      if (role != 'doctor') {
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
      if (mounted) {
        context.read<DashboardBloc>().add(LoadDashboardStats());
        setState(() => _checkingRole = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error comprobando rol: $e')),
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
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is DashboardError) {
            // Mostrar la pantalla de error usando el mensaje del estado
            return _buildErrorScreen('Error: ${state.message}');
          }

          if (state is DashboardLoaded) {
            final stats = state.stats;
            // Llamar a la función que construye la interfaz con los datos cargados
            return _buildDashboardContent(stats);
          }

          // Estado inicial o caso por defecto
          return const Center(child: Text('Cargando resumen...'));
        },
      ),
    );
  }

  // Nuevo método para construir el contenido del Dashboard
  Widget _buildDashboardContent(Map<String, int> stats) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen de Actividad',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade800,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildStatCard(
                  'Total de Citas',
                  stats['totalAppointments'].toString(),
                  Icons.calendar_today,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Citas Pendientes',
                  stats['pendingAppointments'].toString(),
                  Icons.pending_actions,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Pacientes Registrados',
                  stats['totalPatients'].toString(),
                  Icons.people,
                  Colors.green,
                ),
                _buildStatCard(
                  'Citas Hoy',
                  stats['todayAppointments'].toString(),
                  Icons.today,
                  Colors.purple,
                ),
              ],
            ),
          ),
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

  /// Tarjeta de estadística para el dashboard médico
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}