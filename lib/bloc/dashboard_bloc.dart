import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../services/firebase_service.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc() : super(DashboardLoading()) {
    on<LoadDashboardStats>(_onLoadDashboardStats);
  }

  Future<void> _onLoadDashboardStats(
      LoadDashboardStats event, Emitter<DashboardState> emit) async {
    try {
      emit(DashboardLoading());

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        emit(DashboardError("No hay usuario autenticado"));
        return;
      }

      // Obtener el doctorDocId del médico (ID del documento en /medicos)
      final doctorDocId = await FirebaseService.getDoctorDocId(user.uid);
      
      // Si no se encuentra doctorDocId, usar el UID directamente como fallback
      final finalDoctorDocId = doctorDocId ?? user.uid;
      
      debugPrint('🔐 Dashboard: Usando doctorDocId: $finalDoctorDocId (UID: ${user.uid})');

      // Pasar también el UID para buscar por ambos valores
      final stats = await FirebaseService.getDashboardStats(finalDoctorDocId, doctorUid: user.uid);

      emit(DashboardLoaded(stats));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }
}
