import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CalendarPage extends StatefulWidget {
  final String medicoId; // ID del médico seleccionado
  const CalendarPage({super.key, required this.medicoId});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agendar Cita')),
      body: Column(
        children: [
          // Calendario
          TableCalendar(
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) async {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _horariosDisponibles = [];
                _selectedTime = null;
              });
              // Consultar disponibilidad del médico para ese día
              await _cargarDisponibilidad();
            },
          ),
          const SizedBox(height: 20),

          // Horarios disponibles
          if (_horariosDisponibles.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _horariosDisponibles.length,
                itemBuilder: (context, index) {
                  final horario = _horariosDisponibles[index];
                  final horaInicio = (horario['horaInicio'] as Timestamp).toDate();
                  final horaFin = (horario['horaFin'] as Timestamp).toDate();
                  final disponible = horario['estaDisponible'] as bool;

                  return ListTile(
                    title: Text(
                        '${horaInicio.hour.toString().padLeft(2, '0')}:${horaInicio.minute.toString().padLeft(2, '0')} - ${horaFin.hour.toString().padLeft(2, '0')}:${horaFin.minute.toString().padLeft(2, '0')}'),
                    trailing: disponible
                        ? (_selectedTime != null &&
                                _selectedTime!.hour == horaInicio.hour &&
                                _selectedTime!.minute == horaInicio.minute
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null)
                        : const Text('Ocupado', style: TextStyle(color: Colors.red)),
                    onTap: disponible
                        ? () {
                            setState(() {
                              _selectedTime = TimeOfDay.fromDateTime(horaInicio);
                            });
                          }
                        : null,
                  );
                },
              ),
            )
          else if (_selectedDay != null)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No hay horarios disponibles para este día'),
            ),

          // Botón para agendar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: (_selectedDay != null && _selectedTime != null)
                  ? () async {
                      // Encontrar el documento de disponibilidad seleccionado
                      final horarioSeleccionado = _horariosDisponibles.firstWhere((horario) {
                        final horaInicio = (horario['horaInicio'] as Timestamp).toDate();
                        return horaInicio.hour == _selectedTime!.hour &&
                            horaInicio.minute == _selectedTime!.minute;
                      });

                      // Guardar cita
                      await _firestore.collection('citas').add({
                        'fecha': DateTime(
                          _selectedDay!.year,
                          _selectedDay!.month,
                          _selectedDay!.day,
                          _selectedTime!.hour,
                          _selectedTime!.minute,
                        ),
                        'medicoId': widget.medicoId,
                        'usuarioId': _userId,
                        'descripcion': 'Consulta médica',
                      });

                      // Marcar horario como ocupado
                      await _firestore
                          .collection('disponibilidad_medicos')
                          .doc(horarioSeleccionado['id'])
                          .update({'estaDisponible': false});

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cita agendada con éxito')),
                      );

                      setState(() {
                        _selectedTime = null;
                        _cargarDisponibilidad(); // refrescar horarios
                      });
                    }
                  : null,
              child: const Text('Confirmar Cita'),
            ),
          ),
        ],
      ),
    );
  }

  // Cargar disponibilidad del médico en la fecha seleccionada
  Future<void> _cargarDisponibilidad() async {
    if (_selectedDay == null) return;

    final startOfDay = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final endOfDay = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day, 23, 59, 59);

    final snapshot = await _firestore
        .collection('disponibilidad_medicos')
        .where('medicoId', isEqualTo: widget.medicoId)
        .where('fecha', isGreaterThanOrEqualTo: startOfDay)
        .where('fecha', isLessThanOrEqualTo: endOfDay)
        .get();

    setState(() {
      _horariosDisponibles = snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id; // Guardar id para actualizar
            return data;
          })
          .toList();
    });
  }
}
