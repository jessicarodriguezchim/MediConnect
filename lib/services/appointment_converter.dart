import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';
import 'firebase_constants.dart';

/// Servicio para convertir documentos de Firebase a AppointmentModel
/// 
/// Centraliza toda la lógica de conversión para evitar código duplicado
/// y manejar las diferencias entre las colecciones 'appointments' y 'citas'
class AppointmentConverter {
  /// Convierte un DocumentSnapshot de la colección 'appointments' a AppointmentModel
  /// 
  /// Esta es la forma estándar y preferida de obtener citas.
  static AppointmentModel fromAppointmentsDocument(DocumentSnapshot doc) {
    return AppointmentModel.fromFirestore(doc);
  }
  
  /// Convierte un DocumentSnapshot de la colección 'citas' (legacy) a AppointmentModel
  /// 
  /// ⚠️ DEPRECATED: Esta colección se está eliminando gradualmente.
  /// Usa fromAppointmentsDocument() cuando sea posible.
  /// 
  /// [doc] - DocumentSnapshot de la colección 'citas'
  /// [defaultDoctorId] - ID del doctor por defecto si no se encuentra en el documento
  static AppointmentModel fromCitasDocument(
    DocumentSnapshot doc,
    String defaultDoctorId,
  ) {
    final data = doc.data();
    if (data == null || data is! Map<String, dynamic>) {
      throw Exception('Documento de cita inválido: ${doc.id}');
    }
    
    // Obtener campos con valores por defecto
    final citaMedicoId = data[FirebaseFields.medicoId] as String? ?? '';
    final citaMedicoDocId = data[FirebaseFields.medicoDocId] as String? ?? '';
    final pacienteId = data[FirebaseFields.pacienteId] as String? ?? '';
    final pacienteNombre = data[FirebaseFields.pacienteNombre] as String? ?? 'Paciente';
    final medicoNombre = data[FirebaseFields.medicoNombre] as String? ?? 'Médico';
    
    // Determinar especialidad (puede estar en diferentes campos)
    String specialty = data[FirebaseFields.especialidad] as String? ?? 
                      data[FirebaseFields.motivo] as String? ?? 
                      data[FirebaseFields.clinica] as String? ?? 
                      'General';
    
    // Convertir fecha
    DateTime appointmentDate;
    try {
      final fechaCita = data[FirebaseFields.fechaCita];
      if (fechaCita is Timestamp) {
        appointmentDate = fechaCita.toDate();
      } else if (fechaCita is DateTime) {
        appointmentDate = fechaCita;
      } else {
        appointmentDate = DateTime.now();
      }
    } catch (e) {
      appointmentDate = DateTime.now();
    }
    
    // Convertir hora
    String appointmentTime;
    try {
      final horaInicio = data[FirebaseFields.horaInicio];
      if (horaInicio is String) {
        appointmentTime = horaInicio;
      } else if (horaInicio is Timestamp) {
        final timeStr = horaInicio.toDate().toString();
        appointmentTime = timeStr.substring(11, 16);
      } else {
        appointmentTime = '00:00';
      }
    } catch (e) {
      appointmentTime = '00:00';
    }
    
    // Convertir estado (de español a inglés)
    final estado = data[FirebaseFields.estado] as String? ?? 'Pendiente';
    final status = AppointmentStatus.convertFromSpanish(estado);
    
    // Convertir fecha de creación
    DateTime createdAt;
    try {
      final creadoEn = data[FirebaseFields.creadoEn];
      if (creadoEn is Timestamp) {
        createdAt = creadoEn.toDate();
      } else if (creadoEn is DateTime) {
        createdAt = creadoEn;
      } else {
        createdAt = DateTime.now();
      }
    } catch (e) {
      createdAt = DateTime.now();
    }
    
    // Determinar doctorId (prioridad: medicoId > medicoDocId > defaultDoctorId)
    final finalDoctorId = citaMedicoId.isNotEmpty && citaMedicoId != 'Por asignar'
        ? citaMedicoId
        : (citaMedicoDocId.isNotEmpty ? citaMedicoDocId : defaultDoctorId);
    
    return AppointmentModel(
      id: doc.id,
      doctorId: finalDoctorId, // Para Dashboard (igual a doctorDocId)
      patientId: pacienteId, // Para Dashboard (igual a patientDocId)
      doctorDocId: finalDoctorId, // El finalDoctorId es el docId en /medicos
      patientDocId: pacienteId, // El pacienteId es el docId en /usuarios
      doctorName: medicoNombre,
      patientName: pacienteNombre,
      specialty: specialty,
      date: appointmentDate,
      time: appointmentTime,
      status: status,
      notes: data[FirebaseFields.motivo] as String?,
      symptoms: null,
      createdAt: createdAt,
      updatedAt: null,
    );
  }
  
  /// Verifica si una cita de la colección 'citas' pertenece a un médico específico
  /// 
  /// [data] - Datos del documento de la cita
  /// [doctorId] - UID del médico
  /// [medicoDocId] - ID del documento del médico (opcional)
  /// 
  /// Retorna true si la cita pertenece al médico
  static bool belongsToDoctor(
    Map<String, dynamic> data,
    String doctorId, {
    String? medicoDocId,
  }) {
    final citaMedicoId = data[FirebaseFields.medicoId] as String? ?? '';
    final citaMedicoDocId = data[FirebaseFields.medicoDocId] as String? ?? '';
    
    // Coincidencia directa
    if (citaMedicoId == doctorId || citaMedicoDocId == doctorId) {
      return true;
    }
    
    // Coincidencia con documento ID del médico
    if (medicoDocId != null) {
      if (citaMedicoId == medicoDocId || citaMedicoDocId == medicoDocId) {
        return true;
      }
    }
    
    // Incluir citas sin médico asignado (para que los médicos las vean)
    if (citaMedicoId.isEmpty || 
        citaMedicoId == '' || 
        citaMedicoId == 'Por asignar') {
      return true;
    }
    
    return false;
  }
}

