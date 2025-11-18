import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/appointment_model.dart'; // Ajusta la ruta si es necesario
import '../../models/user_model.dart';         // Ajusta la ruta si es necesario
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  /// Stream que escucha cambios en tiempo real en las colecciones de citas y pacientes
  Stream<Map<String, int>> _dashboardStatsStream(String doctorId, {String? specialty}) async* {
    Query appointmentsQuery = _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId);
    if (specialty != null && specialty.isNotEmpty) {
      appointmentsQuery = appointmentsQuery.where('specialty', isEqualTo: specialty);
    }
    final appointmentsStream = appointmentsQuery.snapshots();
    final patientsStream = _firestore
        .collection('usuarios')
        .where('role', isEqualTo: 'patient')
        .snapshots();

    await for (final appointmentsSnapshot in appointmentsStream) {
      final appointments = appointmentsSnapshot.docs
          .map((doc) => AppointmentModel.fromDocument(doc))
          .toList();
      final patientsSnapshot = await patientsStream.first;
      final patients = patientsSnapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .toList();
      final totalAppointments = appointments.length;
      final pendingAppointments = appointments
          .where((appointment) => appointment.status == 'pending')
          .length;
      final todayAppointments = appointments
          .where((appointment) => appointment.isToday)
          .length;
      final totalPatients = patients.length;
      yield {
        'totalAppointments': totalAppointments,
        'pendingAppointments': pendingAppointments,
        'todayAppointments': todayAppointments,
        'totalPatients': totalPatients,
      };
    }
  }

  DashboardBloc() : super(DashboardInitial()) {
    on<LoadDashboardStats>((event, emit) async {
      emit(DashboardLoading());
      final user = _auth.currentUser;
      if (user == null) {
        emit(DashboardError('No hay usuario autenticado.'));
        return;
      }
      await emit.forEach<Map<String, int>>(
        _dashboardStatsStream(user.uid),
        onData: (stats) => DashboardLoaded(stats),
        onError: (e, _) => DashboardError('Error en tiempo real: $e'),
      );
    });

    on<LoadDashboardStatsFor>((event, emit) async {
      emit(DashboardLoading());
      await emit.forEach<Map<String, int>>(
        _dashboardStatsStream(event.doctorId, specialty: event.specialty),
        onData: (stats) => DashboardLoaded(stats),
        onError: (e, _) => DashboardError('Error en tiempo real: $e'),
      );
    });

    // Crear nueva cita
    on<AddAppointment>((event, emit) async {
      emit(DashboardLoading());
      final user = _auth.currentUser;
      if (user == null) {
        emit(DashboardError('No hay usuario autenticado.'));
        return;
      }

      try {
        final collection = _firestore.collection('appointments');
        // Preparamos el map sin el id (Firestore generará uno)
        final map = event.appointment.toMap();
        map.remove('id');
        final docRef = await collection.add(map);
        // Guardar el id dentro del documento para consistencia (opcional)
        await docRef.update({'id': docRef.id});

        final stats = await _getDashboardStats(user.uid);
        emit(DashboardLoaded(stats));
      } catch (e) {
        emit(DashboardError('Error creando la cita: $e'));
      }
    });

    // Actualizar cita existente
    on<UpdateAppointment>((event, emit) async {
      emit(DashboardLoading());
      final user = _auth.currentUser;
      if (user == null) {
        emit(DashboardError('No hay usuario autenticado.'));
        return;
      }

      try {
        final docRef = _firestore.collection('appointments').doc(event.appointmentId);
        final map = event.updatedAppointment.toMap();
        // Asegurar que no sobreescribimos el id con un valor vacío
        map.remove('id');
        await docRef.update(map);

        final stats = await _getDashboardStats(user.uid);
        emit(DashboardLoaded(stats));
      } catch (e) {
        emit(DashboardError('Error actualizando la cita: $e'));
      }
    });

    // Eliminar cita
    on<DeleteAppointment>((event, emit) async {
      emit(DashboardLoading());
      final user = _auth.currentUser;
      if (user == null) {
        emit(DashboardError('No hay usuario autenticado.'));
        return;
      }

      try {
        await _firestore.collection('appointments').doc(event.appointmentId).delete();
        final stats = await _getDashboardStats(user.uid);
        emit(DashboardLoaded(stats));
      } catch (e) {
        emit(DashboardError('Error eliminando la cita: $e'));
      }
    });
  }

  // LÓGICA DE FIREBASE MOVÍDA DESDE DASHBOARD PAGE
  Future<Map<String, int>> _getDashboardStats(String doctorId) async {
    try {
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .get();

      final appointments = appointmentsSnapshot.docs
          .map((doc) => AppointmentModel.fromDocument(doc))
          .toList();

      final patientsSnapshot = await _firestore
          .collection('usuarios')
          .where('role', isEqualTo: 'patient')
          .get();

      final patients = patientsSnapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .toList();

      final totalAppointments = appointments.length;
      final pendingAppointments = appointments
          .where((appointment) => appointment.status == 'pending')
          .length;
      final todayAppointments = appointments
          .where((appointment) => appointment.isToday)
          .length;
      final totalPatients = patients.length;

      return {
        'totalAppointments': totalAppointments,
        'pendingAppointments': pendingAppointments,
        'todayAppointments': todayAppointments,
        'totalPatients': totalPatients,
      };
    } catch (e) {
      // Importante: No silenciar el error, deja que se maneje en el Bloc
      throw Exception('Error al cargar estadísticas: $e');
    }
  }
}