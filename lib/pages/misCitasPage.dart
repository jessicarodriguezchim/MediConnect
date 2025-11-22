import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../services/firebase_constants.dart';
import '../models/appointment_model.dart';

class CitasPage extends StatefulWidget {
  const CitasPage({super.key});

  @override
  State<CitasPage> createState() => _CitasPageState();
}

class _CitasPageState extends State<CitasPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _userId;
  String? _patientName;

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay? _selectedTime;
  String? _clinicaSeleccionada;
  String? _motivoSeleccionado;
  
  List<Map<String, dynamic>> _clinicas = [
    {'id': 'clinica1', 'nombre': 'Clínica Central'},
    {'id': 'clinica2', 'nombre': 'Clínica Norte'},
    {'id': 'clinica3', 'nombre': 'Clínica Sur'},
  ];

  final List<String> _motivos = [
    'Consulta general',
    'Chequeo rutinario',
    'Seguimiento',
    'Emergencia',
    'Examen médico',
    'Vacunación',
  ];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initUser(); // Llamar sin await ya que initState no puede ser async
  }

  Future<void> _initUser() async {
    final user = FirebaseService.getCurrentUser();
    if (user != null) {
      _userId = user.uid;
      // Obtener información del paciente desde Firestore
      final userModel = await FirebaseService.getUser(user.uid);
      _patientName = userModel?.displayName ?? userModel?.nombre ?? 'Paciente';
    } else {
      _userId = 'usuario_anonimo_${DateTime.now().millisecondsSinceEpoch}';
      _patientName = 'Paciente';
    }
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _seleccionarHora() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _mostrarFormularioMotivo() async {
    if (_selectedTime == null) {
      _mostrarError('Por favor selecciona una hora');
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 16,
          left: 16,
          right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Detalles de la cita',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 20),
            
            const Text(
              'Motivo de la consulta',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.medical_information),
              ),
              hint: const Text('Selecciona el motivo'),
              value: _motivoSeleccionado,
              items: _motivos.map((m) {
                return DropdownMenuItem(
                  value: m,
                  child: Text(m),
                );
              }).toList(),
              onChanged: (val) => setState(() => _motivoSeleccionado = val),
            ),
            const SizedBox(height: 16),
            
            const Text(
              'Clínica',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.local_hospital),
              ),
              hint: const Text('Selecciona la clínica'),
              value: _clinicaSeleccionada,
              items: _clinicas.map((c) {
                return DropdownMenuItem<String>(
                  value: c['nombre'].toString(),
                  child: Text(c['nombre'].toString()),
                );
              }).toList(),
              onChanged: (val) => setState(() => _clinicaSeleccionada = val),
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: (_motivoSeleccionado != null && _clinicaSeleccionada != null)
                    ? () async {
                        Navigator.pop(context);
                        await _agendarCita();
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Confirmar cita',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _agendarCita() async {
    if (_selectedTime == null || _motivoSeleccionado == null || _clinicaSeleccionada == null) {
      _mostrarError('Por favor completa todos los campos');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Crear fecha completa con hora
      final fechaCita = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Formatear hora como string (HH:mm)
      final horaFormateada = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

      // Crear AppointmentModel con el formato correcto
      // _userId es el UID del usuario, que también es el docId en /usuarios
      final appointment = AppointmentModel(
        id: '', // Se asignará al crear en Firebase
        doctorId: '', // Por asignar (igual a doctorDocId)
        patientId: _userId, // Para Dashboard (igual a patientDocId)
        doctorDocId: '', // Por asignar
        patientDocId: _userId, // ID del documento del paciente en /usuarios
        doctorName: 'Por asignar',
        patientName: _patientName ?? 'Paciente',
        specialty: _clinicaSeleccionada ?? 'General', // Usar clínica como especialidad
        date: fechaCita,
        time: horaFormateada,
        status: 'pending', // Estado pendiente
        notes: _motivoSeleccionado, // Guardar motivo en notes
        symptoms: null,
        createdAt: DateTime.now(),
        updatedAt: null,
      );

      // Guardar la cita en Firebase
      final map = appointment.toMap();
      map.remove('id'); // Firestore generará el ID
      final docRef = await _firestore.collection('appointments').add(map);
      await docRef.update({'id': docRef.id});

      setState(() {
        _selectedTime = null;
        _motivoSeleccionado = null;
        _clinicaSeleccionada = null;
        _selectedDate = DateTime.now().add(const Duration(days: 1));
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cita agendada correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al agendar cita: $e');
    }
  }

  /// Cancela una cita cambiando su estado a 'cancelled'
  Future<void> _cancelarCita(String citaId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar cancelación'),
        content: const Text('¿Deseas cancelar esta cita?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Usar el servicio unificado para ACTUALIZAR el estado (no eliminar)
      await FirebaseService.updateAppointmentStatus(
        citaId,
        'cancelled',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cita cancelada'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      _mostrarError('Error al cancelar: $e');
    }
  }

  /// Confirma una cita cambiando su estado a 'confirmed'
  Future<void> _confirmarCita(String citaId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar cita'),
        content: const Text('¿Deseas confirmar esta cita?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, confirmar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Usar el servicio unificado para actualizar el estado
      await FirebaseService.updateAppointmentStatus(
        citaId,
        'confirmed',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cita confirmada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _mostrarError('Error al confirmar: $e');
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Obtiene el stream de citas del paciente usando el servicio unificado
  /// 
  /// Retorna un Stream de AppointmentModel filtrado por patientId
  Stream<List<AppointmentModel>> _misCitasStream() {
    // Usar el servicio unificado para obtener citas del paciente
    // Nota: getAppointmentsStream está diseñado para médicos, pero podemos filtrar por patientId
    // Alternativamente, podemos usar una query directa pero con la colección correcta
    return _firestore
        .collection(FirebaseCollections.appointments)
        .where('patientDocId', isEqualTo: _userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppointmentModel.fromFirestore(doc))
          .toList();
    });
  }

  String _formatearFecha(Timestamp? timestamp) {
    if (timestamp == null) return 'Sin fecha';
    return DateFormat('dd/MM/yyyy').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Citas'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Agendar Nueva Cita',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          InkWell(
                            onTap: _seleccionarFecha,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, color: Colors.blue),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Fecha',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          DateFormat('dd/MM/yyyy').format(_selectedDate),
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          InkWell(
                            onTap: _seleccionarHora,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, color: Colors.blue),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Hora',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          _selectedTime == null
                                              ? 'Selecciona hora'
                                              : _selectedTime!.format(context),
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: _selectedTime == null
                                                ? Colors.grey
                                                : Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _selectedTime != null
                                  ? _mostrarFormularioMotivo
                                  : null,
                              icon: const Icon(Icons.add),
                              label: const Text(
                                'Agendar cita',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  const Text(
                    'Mis Citas Agendadas',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  StreamBuilder<List<AppointmentModel>>(
                    stream: _misCitasStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text('Error: ${snapshot.error}'),
                          ),
                        );
                      }
                      
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: const [
                                Icon(
                                  Icons.event_busy,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No tienes citas agendadas',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final citas = snapshot.data!;
                      // Ordenar por fecha (más recientes primero)
                      citas.sort((a, b) => b.date.compareTo(a.date));

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: citas.length,
                        itemBuilder: (context, index) {
                          final cita = citas[index];

                          return Dismissible(
                            key: Key(cita.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              // Mostrar diálogo de confirmación
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: const Text('Eliminar cita'),
                                  content: const Text(
                                    '¿Estás seguro de que deseas eliminar esta cita? Esta acción no se puede deshacer.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Eliminar'),
                                    ),
                                  ],
                                ),
                              );
                              return confirm ?? false;
                            },
                            onDismissed: (direction) async {
                              // Cancelar la cita (cambiar estado) en lugar de eliminar
                              try {
                                await FirebaseService.updateAppointmentStatus(
                                  cita.id,
                                  'cancelled',
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✅ Cita cancelada'),
                                      backgroundColor: Colors.orange,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  _mostrarError('Error al cancelar cita: $e');
                                }
                              }
                            },
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                leading: CircleAvatar(
                                  backgroundColor: cita.statusColor,
                                  child: const Icon(
                                    Icons.medical_services,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  cita.specialty.isNotEmpty ? cita.specialty : 'Sin especialidad',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    if (cita.notes != null && cita.notes!.isNotEmpty)
                                      Text('📋 ${cita.notes}'),
                                    const SizedBox(height: 2),
                                    Text('👨‍⚕️ ${cita.doctorName}'),
                                    Text('📅 ${DateFormat('dd/MM/yyyy').format(cita.date)}'),
                                    Text('⏰ ${cita.time}'),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cita.statusColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        cita.statusText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: cita.statusColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Botón para confirmar (solo si está pendiente)
                                    if (cita.status == 'pending')
                                      IconButton(
                                        icon: const Icon(Icons.check_circle, color: Colors.green),
                                        tooltip: 'Confirmar cita',
                                        onPressed: () => _confirmarCita(cita.id),
                                      ),
                                    // Botón para cancelar
                                    IconButton(
                                      icon: const Icon(Icons.cancel, color: Colors.red),
                                      tooltip: 'Cancelar cita',
                                      onPressed: () => _cancelarCita(cita.id),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}