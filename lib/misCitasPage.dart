import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class MisCitasPage extends StatefulWidget {
  const MisCitasPage({super.key});

  @override
  State<MisCitasPage> createState() => _MisCitasPageState();
}

class _MisCitasPageState extends State<MisCitasPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? 'anon';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Citas')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('citas')
            .where('pacienteId', isEqualTo: _userId)
            .orderBy('fechaCita')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No tienes citas programadas.'));
          }

          final citas = snapshot.data!.docs;

          return ListView.builder(
            itemCount: citas.length,
            itemBuilder: (context, index) {
              final cita = citas[index];
              final fecha = (cita['fechaCita'] as Timestamp).toDate();
              final horaInicio = cita['horaInicio'] ?? '';
              final horaFin = cita['horaFin'] ?? '';
              final motivo = cita['motivo'] ?? '';
              final estado = cita['estado'] ?? '';
              final clinica = cita['clinica'] ?? 'No disponible';
              final instrucciones = cita['instruccionesPrevias'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(
                      '${DateFormat('dd/MM/yyyy').format(fecha)} | $horaInicio - $horaFin'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Motivo: $motivo'),
                      Text('Estado: $estado'),
                      Text('Clínica: $clinica'),
                      if (instrucciones.isNotEmpty)
                        Text('Instrucciones: $instrucciones'),
                    ],
                  ),
                  isThreeLine: true,
                  onTap: () {
                    // Opcional: abrir pantalla con más detalle
                    _mostrarDetalleCita(cita);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _mostrarDetalleCita(QueryDocumentSnapshot cita) {
    final fecha = (cita['fechaCita'] as Timestamp).toDate();
    final horaInicio = cita['horaInicio'] ?? '';
    final horaFin = cita['horaFin'] ?? '';
    final motivo = cita['motivo'] ?? '';
    final estado = cita['estado'] ?? '';
    final clinica = cita['clinica'] ?? 'No disponible';
    final instrucciones = cita['instruccionesPrevias'] ?? '';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Detalle de la cita'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fecha: ${DateFormat('dd/MM/yyyy').format(fecha)}'),
            Text('Hora: $horaInicio - $horaFin'),
            Text('Motivo: $motivo'),
            Text('Estado: $estado'),
            Text('Clínica: $clinica'),
            if (instrucciones.isNotEmpty) Text('Instrucciones: $instrucciones'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
