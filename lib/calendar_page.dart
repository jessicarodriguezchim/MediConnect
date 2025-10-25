import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CalendarPage extends StatefulWidget {
  final String? medicoId; // Opcional: se puede pasar un médico
  const CalendarPage({super.key, this.medicoId});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  TimeOfDay? _selectedTime;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? 'anon';

  List<Map<String, dynamic>> _horariosDisponibles = [];
  List<Map<String, dynamic>> _medicos = [];
  String? _medicoSeleccionado;
  String _motivo = '';

  List<Map<String, dynamic>> _misCitas = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _cargarMedicos();
    _cargarMisCitas();
    if (widget.medicoId != null) {
      _medicoSeleccionado = widget.medicoId;
      _cargarDisponibilidad();
    }
  }

  Future<void> _cargarMedicos() async {
    final snapshot = await _firestore.collection('medicos').get();
    setState(() {
      _medicos = snapshot.docs
          .map((d) => {'id': d.id, 'nombre': d['nombre'] ?? 'Sin nombre'})
          .toList();
    });
  }

  Future<void> _cargarDisponibilidad() async {
    if (_selectedDay == null || _medicoSeleccionado == null) return;

    final startOfDay =
        DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final endOfDay =
        DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day, 23, 59);

    final snapshot = await _firestore
        .collection('medicos')
        .doc(_medicoSeleccionado)
        .collection('disponibilidad')
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
        .where('timestamp', isLessThanOrEqualTo: endOfDay)
        .orderBy('timestamp')
        .get();

    setState(() {
      _horariosDisponibles = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Future<void> _cargarMisCitas() async {
    final snapshot = await _firestore
        .collection('citas')
        .where('pacienteId', isEqualTo: _userId)
        .orderBy('fechaCita', descending: false)
        .get();

    setState(() {
      _misCitas = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Future<void> _mostrarFormularioMotivo() async {
    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Motivo de la cita'),
          content: TextField(
            onChanged: (val) => _motivo = val,
            decoration: const InputDecoration(
              hintText: 'Describe brevemente el motivo de tu cita',
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _confirmarCita();
                },
                child: const Text('Guardar cita')),
          ],
        );
      },
    );
  }

  Future<void> _confirmarCita() async {
    if (_selectedTime == null || _selectedDay == null || _medicoSeleccionado == null) return;

    final horarioSeleccionado = _horariosDisponibles.firstWhere((horario) {
      final horaCompleta = (horario['timestamp'] as Timestamp).toDate();
      return horaCompleta.hour == _selectedTime!.hour &&
          horaCompleta.minute == _selectedTime!.minute;
    });

    final fechaCita = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    await _firestore.collection('citas').add({
      'fechaCita': fechaCita,
      'horaInicio': _selectedTime!.format(context),
      'horaFin':
          '${_selectedTime!.hour + 1}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
      'motivo': _motivo,
      'medicoId': _medicoSeleccionado,
      'pacienteId': _userId,
      'estado': 'pendiente',
    });

    final docId = horarioSeleccionado['id'];
    await _firestore
        .collection('medicos')
        .doc(_medicoSeleccionado)
        .collection('disponibilidad')
        .doc(docId)
        .update({'estaDisponible': false});

    setState(() {
      _selectedTime = null;
      _motivo = '';
    });

    _cargarDisponibilidad();
    _cargarMisCitas();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cita agendada con éxito')),
    );
  }

  Future<void> _cancelarCita(Map<String, dynamic> cita) async {
    bool confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar cancelación'),
        content: const Text('¿Deseas cancelar esta cita?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí')),
        ],
      ),
    );

    if (!confirm) return;

    final citaId = cita['id'];
    final medicoId = cita['medicoId'];
    final fechaCita = (cita['fechaCita'] as Timestamp).toDate();

    // Eliminar cita
    await _firestore.collection('citas').doc(citaId).delete();

    // Liberar disponibilidad
    final snapshot = await _firestore
        .collection('medicos')
        .doc(medicoId)
        .collection('disponibilidad')
        .where('timestamp', isEqualTo: fechaCita)
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.update({'estaDisponible': true});
    }

    _cargarMisCitas();
    _cargarDisponibilidad();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cita cancelada')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agendar Cita')),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _horariosDisponibles = [];
                _selectedTime = null;
              });
              _cargarDisponibilidad();
            },
          ),
          const SizedBox(height: 10),
          DropdownButton<String>(
            hint: const Text('Selecciona un médico'),
            value: _medicoSeleccionado,
            isExpanded: true,
            items: _medicos.map((m) {
              return DropdownMenuItem<String>(
                value: m['id'],
                child: Text(m['nombre']),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _medicoSeleccionado = val;
                _cargarDisponibilidad();
              });
            },
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _horariosDisponibles.isEmpty
                ? const Center(child: Text('Selecciona una fecha y médico'))
                : ListView.builder(
                    itemCount: _horariosDisponibles.length,
                    itemBuilder: (context, index) {
                      final horario = _horariosDisponibles[index];
                      final horaCompleta = (horario['timestamp'] as Timestamp).toDate();
                      final disponible = horario['estaDisponible'] as bool? ?? true;

                      final horaString =
                          '${horaCompleta.hour.toString().padLeft(2, '0')}:${horaCompleta.minute.toString().padLeft(2, '0')}';
                      final isPast = isSameDay(horaCompleta, DateTime.now()) &&
                          horaCompleta.isBefore(DateTime.now());

                      return ListTile(
                        title: Text(horaString),
                        trailing: !disponible || isPast
                            ? Text(isPast ? 'Pasada' : 'Ocupado',
                                style: TextStyle(
                                    color:
                                        isPast ? Colors.grey : Colors.redAccent))
                            : (_selectedTime != null &&
                                    _selectedTime!.hour == horaCompleta.hour &&
                                    _selectedTime!.minute == horaCompleta.minute
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : null),
                        onTap: disponible && !isPast
                            ? () {
                                setState(() {
                                  _selectedTime = TimeOfDay.fromDateTime(horaCompleta);
                                });
                              }
                            : null,
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.event_available),
              label: const Text('Confirmar cita'),
              onPressed: (_selectedDay != null &&
                      _selectedTime != null &&
                      _medicoSeleccionado != null)
                  ? _mostrarFormularioMotivo
                  : null,
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Mis citas', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _misCitas.isEmpty
                ? const Center(child: Text('No tienes citas agendadas'))
                : ListView.builder(
                    itemCount: _misCitas.length,
                    itemBuilder: (context, index) {
                      final cita = _misCitas[index];
                      final fecha = (cita['fechaCita'] as Timestamp).toDate();
                      return ListTile(
                        title: Text('Cita con ${cita['medicoId']}'),
                        subtitle: Text(
                            '${fecha.day}/${fecha.month}/${fecha.year} - ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => _cancelarCita(cita),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
