import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
    if (_selectedTime == null || _hospitalSeleccionado == null) {
      _mostrarError('Faltan datos para agendar la cita');
      return;
    }

    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final horaInicio = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final horaFin = horaInicio.add(const Duration(hours: 1));

    try {
      await _firestore.collection('citas').add({
        'pacienteId': _userId,
        'medicoId': widget.medicoId,
        'hospitalId': _hospitalSeleccionado,
        'fechaCita': Timestamp.fromDate(_selectedDay),
        'horaInicio': Timestamp.fromDate(horaInicio),
        'horaFin': Timestamp.fromDate(horaFin),
        'motivo': _motivoController.text.isNotEmpty 
            ? _motivoController.text 
            : 'Consulta general',
        'estado': 'Pendiente',
        'creadoEn': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context); // Cerrar indicador de carga

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Cita agendada correctamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      setState(() {
        _selectedTime = null;
        _hospitalSeleccionado = null;
        _motivoController.clear();
      });
    } catch (e) {
      Navigator.pop(context); // Cerrar indicador de carga
      _mostrarError('Error al agendar cita: $e');
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
      await _firestore.collection('citas').doc(citaId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cita cancelada'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
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

  Stream<QuerySnapshot> _streamMisCitas() {
    return _firestore
        .collection('citas')
        .where('pacienteId', isEqualTo: _userId)
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

                // Sort appointments by horaInicio (client-side sorting)
                citas.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aHoraInicio = aData['horaInicio'] as Timestamp?;
                  final bHoraInicio = bData['horaInicio'] as Timestamp?;
                  
                  if (aHoraInicio == null && bHoraInicio == null) return 0;
                  if (aHoraInicio == null) return 1;
                  if (bHoraInicio == null) return -1;
                  
                  return aHoraInicio.compareTo(bHoraInicio);
                });

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: citas.length,
                  itemBuilder: (context, index) {
                    final cita = citas[index];
                    final data = cita.data() as Map<String, dynamic>;
                    final inicio = (data['horaInicio'] as Timestamp).toDate();
                    final fin = (data['horaFin'] as Timestamp).toDate();
                    final hospitalNombre = _obtenerNombreHospital(data['hospitalId']);
                    final estado = data['estado'] ?? 'Pendiente';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          backgroundColor: estado == 'Pendiente' 
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
                            Text('📋 ${data['motivo'] ?? 'Sin motivo'}'),
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
                                color: estado == 'Pendiente' 
                                    ? Colors.orange.shade100 
                                    : Colors.green.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                estado,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: estado == 'Pendiente' 
                                      ? Colors.orange.shade900 
                                      : Colors.green.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => _cancelarCita(cita.id),
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