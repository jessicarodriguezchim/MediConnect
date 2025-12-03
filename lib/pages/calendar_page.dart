import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/appointment_model.dart';

class CalendarPage extends StatefulWidget {
  final String medicoId;
  const CalendarPage({super.key, required this.medicoId});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _userId;

  DateTime _selectedDay = DateTime.now();
  TimeOfDay? _selectedTime;
  String? _hospitalSeleccionado;
  final TextEditingController _motivoController = TextEditingController();

  List<Map<String, dynamic>> _hospitales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initUser();
    _cargarHospitales();
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  void _initUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userId = user.uid;
    } else {
      _userId = 'usuario_anonimo_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> _cargarHospitales() async {
    try {
      final snapshot = await _firestore.collection('hospitales').get();
      
      if (snapshot.docs.isEmpty) {
        // Si no hay hospitales, crear algunos de ejemplo
        await _crearHospitalesEjemplo();
        return;
      }

      setState(() {
        _hospitales = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'nombre': doc.data()['nombre'] ?? 'Hospital sin nombre',
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar hospitales: $e');
    }
  }

  Future<void> _crearHospitalesEjemplo() async {
    try {
      final hospitalesEjemplo = [
        {'nombre': 'Hospital General'},
        {'nombre': 'Hospital Central'},
        {'nombre': 'Clínica San José'},
      ];

      for (var hospital in hospitalesEjemplo) {
        await _firestore.collection('hospitales').add(hospital);
      }

      await _cargarHospitales();
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al crear hospitales: $e');
    }
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

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime.now(),
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
    if (picked != null) setState(() => _selectedDay = picked);
  }

  Future<void> _mostrarFormularioMotivo() async {
    if (_selectedTime == null || _hospitalSeleccionado == null) {
      _mostrarError('Por favor selecciona hora y hospital');
      return;
    }

    _motivoController.clear();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Motivo de la cita'),
        content: TextField(
          controller: _motivoController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Describe el motivo de tu cita',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _agendarCita();
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _agendarCita() async {
    // Verificar que el usuario esté autenticado primero
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _mostrarError('❌ No estás autenticado. Por favor, inicia sesión.');
      return;
    }

    if (_selectedTime == null || _hospitalSeleccionado == null) {
      _mostrarError('Faltan datos para agendar la cita');
      return;
    }

    debugPrint('🔵 ========================================');
    debugPrint('🔵 INICIANDO PROCESO DE AGENDAR CITA');
    debugPrint('🔵 Usuario autenticado: ${user.uid}');
    debugPrint('🔵 Email: ${user.email}');
    debugPrint('🔵 ========================================');

    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Obtener datos del paciente
      String patientName = user.email?.split('@')[0] ?? 'Paciente';
      String patientUid = user.uid;
      String patientDocId = patientUid; // Por defecto usar el UID como docId
      
      // Intentar obtener nombre y docId del paciente desde Firestore
      try {
        final patientDoc = await _firestore.collection('usuarios').doc(patientUid).get();
        if (patientDoc.exists) {
          final data = patientDoc.data() as Map<String, dynamic>?;
          patientName = data?['nombre'] ?? data?['displayName'] ?? patientName;
          patientDocId = patientUid; // El docId es el mismo que el UID en usuarios
        }
      } catch (e) {
        debugPrint('Error obteniendo nombre del paciente: $e');
      }

      // Obtener datos del médico - UNIFICADO en usuarios
      String doctorName = 'Médico';
      String specialty = 'General';
      String doctorUserId = widget.medicoId; // Por defecto usar el medicoId
      
      try {
        // Primero buscar en medicos, luego en usuarios
        var doctorDoc = await _firestore.collection('medicos').doc(widget.medicoId).get();
        if (doctorDoc.exists) {
          final data = doctorDoc.data() as Map<String, dynamic>?;
          // Verificar que el documento tenga uid (no es una especialidad)
          if (data != null && data.containsKey('uid') && data['uid'] != null) {
            doctorName = data['nombre'] ?? data['displayName'] ?? doctorName;
            specialty = data['especialidad'] ?? data['specialty'] ?? specialty;
            doctorUserId = data['uid'] ?? widget.medicoId;
            debugPrint('Calendar: Médico encontrado - nombre: $doctorName, UID: $doctorUserId, docId: ${widget.medicoId}');
          } else {
            // Si no tiene uid, buscar en usuarios
            doctorDoc = await _firestore.collection('usuarios').doc(widget.medicoId).get();
            if (doctorDoc.exists) {
              final data = doctorDoc.data() as Map<String, dynamic>?;
              doctorName = data?['nombre'] ?? data?['displayName'] ?? doctorName;
              specialty = data?['especialidad'] ?? data?['specialty'] ?? specialty;
              doctorUserId = data?['uid'] ?? widget.medicoId;
              debugPrint('Calendar: Médico encontrado en usuarios - nombre: $doctorName, UID: $doctorUserId, docId: ${widget.medicoId}');
            } else {
              debugPrint('Calendar: ⚠️ No se encontró el médico con ID: ${widget.medicoId}');
            }
          }
        } else {
          // Si no existe en medicos, buscar en usuarios
          doctorDoc = await _firestore.collection('usuarios').doc(widget.medicoId).get();
          if (doctorDoc.exists) {
            final data = doctorDoc.data() as Map<String, dynamic>?;
            doctorName = data?['nombre'] ?? data?['displayName'] ?? doctorName;
            specialty = data?['especialidad'] ?? data?['specialty'] ?? specialty;
            doctorUserId = data?['uid'] ?? widget.medicoId;
            debugPrint('Calendar: Médico encontrado en usuarios - nombre: $doctorName, UID: $doctorUserId, docId: ${widget.medicoId}');
          } else {
            debugPrint('Calendar: ⚠️ No se encontró el médico con ID: ${widget.medicoId}');
          }
        }
      } catch (e) {
        debugPrint('Error obteniendo datos del médico: $e');
      }

      // Crear AppointmentModel
      // IMPORTANTE: doctorId debe ser el UID del médico para que el Dashboard lo encuentre
      // doctorDocId puede ser el docId o el UID (depende de cómo esté guardado el médico)
      final appointment = AppointmentModel(
        id: '', // Se generará automáticamente
        doctorId: doctorUserId, // Para Dashboard - usar el UID del médico (importante!)
        patientId: patientDocId, // Para Dashboard (igual a patientDocId)
        doctorDocId: widget.medicoId, // ID del documento del médico en /medicos (puede ser docId o UID)
        patientDocId: patientDocId, // ID del documento del paciente en /usuarios
        doctorName: doctorName,
        patientName: patientName,
        specialty: specialty,
        date: _selectedDay,
        time: '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
        status: 'pending',
        notes: _motivoController.text.isNotEmpty 
            ? _motivoController.text 
            : 'Consulta general',
        symptoms: null,
        createdAt: DateTime.now(),
        updatedAt: null,
      );

      // Verificar que el usuario esté autenticado
      if (user == null || patientUid.isEmpty) {
        throw Exception('Usuario no autenticado. Por favor, inicia sesión.');
      }

      debugPrint('🔵 Iniciando guardado de cita...');
      debugPrint('   Paciente: $patientName (UID: $patientUid)');
      debugPrint('   Médico: $doctorName (UID: $doctorUserId)');
      debugPrint('   Fecha: ${_selectedDay.toString()}');
      debugPrint('   Hora: ${_selectedTime!.hour}:${_selectedTime!.minute}');

      // Guardar en la colección appointments
      DocumentReference? appointmentRef;
      try {
        debugPrint('🔵 Guardando en colección appointments...');
        final map = appointment.toMap();
        map.remove('id'); // Firestore generará el ID
        
        debugPrint('   Datos a guardar: ${map.toString()}');
        
        appointmentRef = await _firestore.collection('appointments').add(map);
        await appointmentRef.update({'id': appointmentRef.id});
        
        debugPrint('✅ Cita guardada exitosamente en appointments con ID: ${appointmentRef.id}');
        
        // Verificar que se guardó
        final verifyAppointment = await _firestore.collection('appointments').doc(appointmentRef.id).get();
        if (verifyAppointment.exists) {
          debugPrint('✅ Verificación: Cita existe en appointments');
        } else {
          debugPrint('❌ ERROR: Cita NO se encontró después de guardar en appointments');
        }
      } catch (e, stackTrace) {
        debugPrint('❌ ERROR al guardar en appointments: $e');
        debugPrint('Stack trace: $stackTrace');
        Navigator.pop(context); // Cerrar indicador de carga
        _mostrarError('Error al guardar cita en appointments: ${e.toString()}');
        return;
      }

      Navigator.pop(context); // Cerrar indicador de carga

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Cita agendada correctamente\n'
            'ID: ${appointmentRef?.id ?? "N/A"}',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() {
        _selectedTime = null;
        _hospitalSeleccionado = null;
        _motivoController.clear();
      });
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR GENERAL al agendar cita: $e');
      debugPrint('Stack trace completo: $stackTrace');
      
      // Cerrar indicador de carga si está abierto
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      // Mostrar error detallado al usuario
      String errorMessage = 'Error al agendar cita';
      
      if (e.toString().contains('permission-denied') || 
          e.toString().contains('PERMISSION_DENIED')) {
        errorMessage = '❌ Error de permisos en Firestore. Verifica las reglas de seguridad en Firebase Console.';
      } else if (e.toString().contains('unauthenticated') || 
                 e.toString().contains('UNAUTHENTICATED')) {
        errorMessage = '❌ No estás autenticado. Por favor, inicia sesión nuevamente.';
      } else if (e.toString().contains('network') || 
                 e.toString().contains('NETWORK')) {
        errorMessage = '❌ Error de conexión. Verifica tu conexión a internet.';
      } else {
        errorMessage = '❌ Error al agendar cita: ${e.toString()}';
      }
      
      _mostrarError(errorMessage);
      
      // Mostrar también en SnackBar para que sea más visible
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Ver detalles',
              textColor: Colors.white,
              onPressed: () {
                debugPrint('Detalles del error: $e\n$stackTrace');
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _cancelarCita(String citaId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar cancelación'),
        content: const Text('¿Estás seguro de cancelar esta cita?'),
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
      // Usar solo appointments - actualizar estado a cancelled
      await _firestore.collection('appointments').doc(citaId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Cita cancelada en appointments: $citaId');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Cita cancelada correctamente'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      debugPrint('❌ ERROR al cancelar cita: $e');
      _mostrarError('Error al cancelar: $e');
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

  /// Abre formulario completo para editar la cita
  Future<void> _abrirFormularioEdicionCita(DocumentSnapshot citaDoc) async {
    final data = citaDoc.data() as Map<String, dynamic>;
    final citaId = citaDoc.id;
    
    debugPrint('🔵 Abriendo formulario de edición completa para cita: $citaId');
    
    // Leer datos del formato appointments (nuevo)
    DateTime fechaInicio;
    String horaStr;
    String motivo;
    
    if (data['date'] != null) {
      fechaInicio = data['date'] is Timestamp 
          ? (data['date'] as Timestamp).toDate()
          : data['date'] as DateTime;
      horaStr = data['time'] ?? '10:00';
      motivo = data['notes'] ?? '';
    } else {
      // Fallback al formato antiguo si existe
      fechaInicio = data['horaInicio'] != null
          ? (data['horaInicio'] as Timestamp).toDate()
          : DateTime.now();
      horaStr = '${fechaInicio.hour.toString().padLeft(2, '0')}:${fechaInicio.minute.toString().padLeft(2, '0')}';
      motivo = data['motivo'] ?? '';
    }
    
    // Parsear hora
    final partesHora = horaStr.split(':');
    final hora = partesHora.length > 0 ? int.parse(partesHora[0]) : 10;
    final minuto = partesHora.length > 1 ? int.parse(partesHora[1]) : 0;
    
    // Controladores para el formulario
    final fechaController = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(fechaInicio),
    );
    final horaController = TextEditingController(text: horaStr);
    final motivoController = TextEditingController(text: motivo);
    
    DateTime fechaSeleccionada = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day);
    TimeOfDay horaSeleccionada = TimeOfDay(hour: hora, minute: minuto);
    
    if (!mounted) return;
    
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.edit_calendar, color: Colors.blue),
              SizedBox(width: 8),
              Text('Editar Cita'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Campo de fecha
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: fechaSeleccionada,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      locale: const Locale('es', 'ES'),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        fechaSeleccionada = picked;
                        fechaController.text = DateFormat('dd/MM/yyyy').format(picked);
                      });
                    }
                  },
                  child: TextField(
                    controller: fechaController,
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Fecha',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Campo de hora
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: horaSeleccionada,
                    );
                    if (picked != null) {
                      setDialogState(() {
                        horaSeleccionada = picked;
                        horaController.text = 
                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                  child: TextField(
                    controller: horaController,
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Hora',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Campo de motivo
                TextField(
                  controller: motivoController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Motivo de la consulta',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.medical_information),
                    hintText: 'Ej: Consulta general, Chequeo rutinario...',
                  ),
                  autofocus: false,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                fechaController.dispose();
                horaController.dispose();
                motivoController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                final nuevoMotivo = motivoController.text.trim();
                final nuevaFecha = fechaSeleccionada;
                final nuevaHora = horaController.text.trim();
                
                debugPrint('💾 Guardando cambios en la cita...');
                debugPrint('   Nueva fecha: ${DateFormat('dd/MM/yyyy').format(nuevaFecha)}');
                debugPrint('   Nueva hora: $nuevaHora');
                debugPrint('   Nuevo motivo: "$nuevoMotivo"');
                
                // Cerrar el diálogo primero
                Navigator.pop(context);
                
                // Esperar un momento
                await Future.delayed(const Duration(milliseconds: 100));
                
                // Actualizar la cita
                if (mounted) {
                  await _actualizarCitaCompleta(
                    citaId,
                    nuevaFecha,
                    nuevaHora,
                    nuevoMotivo,
                  );
                }
                
                // Limpiar controladores
                fechaController.dispose();
                horaController.dispose();
                motivoController.dispose();
              },
              child: const Text('Guardar Cambios'),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Actualiza todos los campos de la cita en Firebase
  Future<void> _actualizarCitaCompleta(
    String citaId,
    DateTime nuevaFecha,
    String nuevaHora,
    String nuevoMotivo,
  ) async {
    debugPrint('🔄 Actualizando cita completa: $citaId');
    
    try {
      // Parsear la hora
      final partesHora = nuevaHora.split(':');
      final hora = int.parse(partesHora[0]);
      final minuto = int.parse(partesHora[1]);
      
      // Crear fecha completa con hora
      final fechaInicio = DateTime(
        nuevaFecha.year,
        nuevaFecha.month,
        nuevaFecha.day,
        hora,
        minuto,
      );
      
      // Actualizar en appointments (única colección)
      await _firestore.collection('appointments').doc(citaId).update({
        'date': Timestamp.fromDate(fechaInicio),
        'time': nuevaHora,
        'notes': nuevoMotivo.isEmpty ? 'Consulta general' : nuevoMotivo,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Cita actualizada exitosamente en appointments: $citaId');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cita actualizada correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ ERROR al actualizar cita completa: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al actualizar: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Usar solo appointments - colección moderna y estándar
  Stream<QuerySnapshot> _streamMisCitas() {
    return _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: _userId)
        .snapshots();
  }

  String _formatearFechaHora(DateTime fecha) {
    return DateFormat('dd/MM/yyyy HH:mm').format(fecha);
  }

  String _obtenerNombreHospital(String hospitalId) {
    try {
      return _hospitales.firstWhere(
        (h) => h['id'] == hospitalId,
        orElse: () => {'nombre': 'Hospital no encontrado'},
      )['nombre'];
    } catch (e) {
      return 'Hospital no encontrado';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Agendar Cita')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agendar Cita'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sección de agendar cita
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
                      'Nueva Cita',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Fecha
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
                              child: Text(
                                DateFormat('dd/MM/yyyy').format(_selectedDay),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Hora
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
                              child: Text(
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
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Hospital
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        hint: const Text('Selecciona hospital'),
                        value: _hospitalSeleccionado,
                        isExpanded: true,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.local_hospital, color: Colors.blue),
                        items: _hospitales.map((h) {
                          return DropdownMenuItem<String>(
                            value: h['id'],
                            child: Text(h['nombre']),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _hospitalSeleccionado = val),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Botón agendar
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: (_selectedTime != null && _hospitalSeleccionado != null)
                            ? _mostrarFormularioMotivo
                            : null,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Agendar Cita',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Sección de mis citas
            const Text(
              'Mis Citas Agendadas',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 12),
            
            StreamBuilder<QuerySnapshot>(
              stream: _streamMisCitas(),
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
                    child: Text('Error: ${snapshot.error}'),
                  );
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: const [
                          Icon(Icons.event_busy, size: 64, color: Colors.grey),
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

                final citas = snapshot.data!.docs;

                // Sort appointments by date (client-side sorting)
                citas.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  
                  // Usar formato appointments (date)
                  DateTime? aDate;
                  DateTime? bDate;
                  
                  if (aData['date'] != null) {
                    aDate = aData['date'] is Timestamp 
                        ? (aData['date'] as Timestamp).toDate()
                        : aData['date'] as DateTime;
                  } else if (aData['horaInicio'] != null) {
                    // Fallback al formato antiguo
                    aDate = (aData['horaInicio'] as Timestamp).toDate();
                  }
                  
                  if (bData['date'] != null) {
                    bDate = bData['date'] is Timestamp 
                        ? (bData['date'] as Timestamp).toDate()
                        : bData['date'] as DateTime;
                  } else if (bData['horaInicio'] != null) {
                    // Fallback al formato antiguo
                    bDate = (bData['horaInicio'] as Timestamp).toDate();
                  }
                  
                  if (aDate == null && bDate == null) return 0;
                  if (aDate == null) return 1;
                  if (bDate == null) return -1;
                  
                  return aDate.compareTo(bDate);
                });

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: citas.length,
                  itemBuilder: (context, index) {
                    final cita = citas[index];
                    final data = cita.data() as Map<String, dynamic>;
                    
                    // Usar formato de appointments (nuevo)
                    DateTime inicio;
                    DateTime fin;
                    if (data['date'] != null) {
                      final fecha = data['date'] is Timestamp 
                          ? (data['date'] as Timestamp).toDate()
                          : data['date'] as DateTime;
                      
                      // Parsear hora
                      final timeStr = data['time'] ?? '10:00';
                      final partesHora = timeStr.split(':');
                      final hora = int.parse(partesHora[0]);
                      final minuto = partesHora.length > 1 ? int.parse(partesHora[1]) : 0;
                      
                      inicio = DateTime(
                        fecha.year,
                        fecha.month,
                        fecha.day,
                        hora,
                        minuto,
                      );
                      fin = inicio.add(const Duration(hours: 1));
                    } else {
                      // Fallback al formato antiguo si existe
                      inicio = data['horaInicio'] != null 
                          ? (data['horaInicio'] as Timestamp).toDate()
                          : DateTime.now();
                      fin = data['horaFin'] != null
                          ? (data['horaFin'] as Timestamp).toDate()
                          : inicio.add(const Duration(hours: 1));
                    }
                    
                    final hospitalNombre = data['doctorName'] ?? 'Médico';
                    final motivo = data['notes'] ?? data['motivo'] ?? 'Sin motivo';
                    
                    // Convertir estado de inglés a español
                    String estadoEsp = 'Pendiente';
                    final estadoEn = (data['status'] ?? data['estado'] ?? 'pending').toString().toLowerCase();
                    switch (estadoEn) {
                      case 'pending':
                      case 'pendiente':
                        estadoEsp = 'Pendiente';
                        break;
                      case 'confirmed':
                      case 'confirmada':
                        estadoEsp = 'Confirmada';
                        break;
                      case 'completed':
                      case 'completada':
                        estadoEsp = 'Completada';
                        break;
                      case 'cancelled':
                      case 'cancelada':
                        estadoEsp = 'Cancelada';
                        break;
                    }

                    return InkWell(
                      // 🔵 Hacer que toda la cita sea clickeable para editar
                      onTap: () {
                        debugPrint('🔵 Cita clickeada para editar completa: ${cita.id}');
                        _abrirFormularioEdicionCita(cita);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            backgroundColor: estadoEsp == 'Pendiente' 
                                ? Colors.orange 
                                : Colors.green,
                            child: const Icon(Icons.medical_services, color: Colors.white),
                          ),
                          title: Text(
                            hospitalNombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('📋 $motivo'),
                              const SizedBox(height: 2),
                              Text('📅 ${_formatearFechaHora(inicio)}'),
                              Text('⏰ ${_formatearFechaHora(fin)}'),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: estadoEsp == 'Pendiente' 
                                      ? Colors.orange.shade100 
                                      : Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  estadoEsp,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: estadoEsp == 'Pendiente' 
                                        ? Colors.orange.shade900 
                                        : Colors.green.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Indicador visual de que es clickeable
                              Row(
                                children: [
                                  Icon(
                                    Icons.touch_app,
                                    size: 14,
                                    color: Colors.blue.withOpacity(0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Toca para editar cita completa',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue.withOpacity(0.6),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: GestureDetector(
                            // Prevenir que el clic en el botón active el InkWell del padre
                            onTap: () {}, // Consumir el evento
                            behavior: HitTestBehavior.opaque,
                            child: IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: () => _cancelarCita(cita.id),
                            ),
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