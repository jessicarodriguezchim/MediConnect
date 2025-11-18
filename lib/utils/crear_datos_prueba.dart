import 'package:cloud_firestore/cloud_firestore.dart';

/// Ejecuta esta función una sola vez para poblar Firestore con datos de prueba.
Future<void> crearDatosPrueba() async {
  final firestore = FirebaseFirestore.instance;

  // Crear usuario paciente
  final pacienteRef = await firestore.collection('usuarios').add({
    'displayName': 'Paciente Ejemplo',
    'email': 'paciente@ejemplo.com',
    'role': 'patient',
  });

  // Crear usuario doctor
  final doctorRef = await firestore.collection('usuarios').add({
    'displayName': 'Doctor Ejemplo',
    'nombre': 'Dr. Juan Pérez',
    'email': 'doctor@ejemplo.com',
    'role': 'doctor',
    'specialty': 'Ortopedia',
    'especialidad': 'Ortopedia',
    'color': '0xFF1976D2', // Azul
    'icono': '0xe3af', // MaterialIcons.medical_services
  });

  // Crear cita de prueba (pendiente)
  await firestore.collection('appointments').add({
    'doctorId': doctorRef.id,
    'patientId': pacienteRef.id,
    'specialty': 'Ortopedia',
    'date': Timestamp.fromDate(DateTime.now().add(Duration(days: 1))),
    'status': 'pending',
    'createdAt': Timestamp.now(),
  });

  // Crear cita de prueba (completada)
  await firestore.collection('appointments').add({
    'doctorId': doctorRef.id,
    'patientId': pacienteRef.id,
    'specialty': 'Ortopedia',
    'date': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 2))),
    'status': 'completed',
    'createdAt': Timestamp.now(),
  });

  // Crear cita de prueba (hoy)
  await firestore.collection('appointments').add({
    'doctorId': doctorRef.id,
    'patientId': pacienteRef.id,
    'specialty': 'Ortopedia',
    'date': Timestamp.fromDate(DateTime.now()),
    'status': 'pending',
    'createdAt': Timestamp.now(),
  });

  print('Datos de prueba creados correctamente.');
}
