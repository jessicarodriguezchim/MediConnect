import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/appointment_model.dart';
import '../services/firebase_service.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppointmentsPage extends StatefulWidget {
  const AppointmentsPage({super.key});

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No hay usuario autenticado')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Citas'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filtros
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey[100],
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Todas', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pendientes', 'pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Confirmadas', 'confirmed'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Completadas', 'completed'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Canceladas', 'cancelled'),
                ],
              ),
            ),
          ),
          // Lista de citas
          Expanded(
            child: FutureBuilder<String?>(
              future: FirebaseService.getDoctorDocId(user.uid),
              builder: (context, doctorDocIdSnapshot) {
                if (!doctorDocIdSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final doctorDocId = doctorDocIdSnapshot.data;
                if (doctorDocId == null) {
                  return const Center(child: Text('No se encontró el documento del médico'));
                }
                
                return StreamBuilder<List<AppointmentModel>>(
                  stream: FirebaseService.getAppointmentsStream(doctorDocId, doctorUid: user.uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<AppointmentModel> allAppointments = snapshot.data!;

                if (_selectedFilter != 'all') {
                  allAppointments = allAppointments
                      .where((apt) => apt.status == _selectedFilter)
                      .toList();
                }

                allAppointments.sort((a, b) => a.date.compareTo(b.date));

                if (allAppointments.isEmpty) {
                  return const Center(child: Text("No hay citas"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: allAppointments.length,
                  itemBuilder: (context, i) {
                    final appointment = allAppointments[i];
                    return _buildAppointmentCard(appointment);
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: Colors.teal,
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildAppointmentCard(AppointmentModel appointment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.patientName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appointment.specialty,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: appointment.statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    appointment.statusText,
                    style: TextStyle(
                      color: appointment.statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Fecha: ${DateFormat('dd/MM/yyyy').format(appointment.date)}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Hora: ${appointment.time}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Notas: ${appointment.notes}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
            // Botones de acción
            if (appointment.status == 'pending') ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _confirmarCita(appointment.id),
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    label: const Text('Confirmar'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _cancelarCita(appointment.id),
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: const Text('Cancelar'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
            if (appointment.status == 'confirmed') ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _completarCita(appointment.id),
                    icon: const Icon(Icons.check, color: Colors.blue),
                    label: const Text('Marcar como Completada'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _cancelarCita(appointment.id),
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: const Text('Cancelar'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarCita(String appointmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar cita'),
        content: const Text('¿Deseas confirmar esta cita?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, confirmar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseService.updateAppointmentStatus(appointmentId, 'confirmed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cita confirmada'),
            backgroundColor: Colors.green,
          ),
        );
      }
      // Recargar el dashboard
      context.read<DashboardBloc>().add(LoadDashboardStats());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al confirmar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelarCita(String appointmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: const Text('¿Estás seguro de cancelar esta cita?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cancelar'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseService.updateAppointmentStatus(appointmentId, 'cancelled');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cita cancelada'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      // Recargar el dashboard
      context.read<DashboardBloc>().add(LoadDashboardStats());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cancelar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completarCita(String appointmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Completar cita'),
        content: const Text('¿Deseas marcar esta cita como completada?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, completar'),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseService.updateAppointmentStatus(appointmentId, 'completed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cita completada'),
            backgroundColor: Colors.green,
          ),
        );
      }
      // Recargar el dashboard
      context.read<DashboardBloc>().add(LoadDashboardStats());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al completar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
