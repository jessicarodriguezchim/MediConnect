/// Constantes para nombres de colecciones de Firebase
/// 
/// Este archivo centraliza todos los nombres de colecciones para evitar
/// inconsistencias y facilitar cambios futuros.
class FirebaseCollections {
  // Colecciones principales
  static const String appointments = 'appointments';
  static const String usuarios = 'usuarios';
  
  // Colecciones legacy (a eliminar gradualmente)
  static const String citas = 'citas'; // ⚠️ DEPRECATED - usar 'appointments'
  static const String medicos = 'medicos'; // ⚠️ DEPRECATED - usar 'usuarios' con role='doctor'
  static const String hospitales = 'hospitales';
}

/// Constantes para nombres de campos en documentos de Firebase
/// 
/// Estandariza los nombres de campos para evitar inconsistencias
/// entre diferentes colecciones.
class FirebaseFields {
  // Campos de usuarios
  static const String uid = 'uid';
  static const String email = 'email';
  static const String displayName = 'displayName';
  static const String nombre = 'nombre';
  static const String role = 'role';
  static const String telefono = 'telefono';
  static const String phone = 'phone';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  
  // Campos de citas (appointments)
  static const String appointmentId = 'id';
  static const String doctorId = 'doctorId';
  static const String doctorName = 'doctorName';
  static const String patientId = 'patientId';
  static const String patientName = 'patientName';
  static const String specialty = 'specialty';
  static const String date = 'date';
  static const String time = 'time';
  static const String status = 'status';
  static const String notes = 'notes';
  static const String symptoms = 'symptoms';
  
  // Campos legacy de citas (citas collection) - para conversión
  static const String medicoId = 'medicoId';
  static const String medicoDocId = 'medicoDocId';
  static const String medicoNombre = 'medicoNombre';
  static const String pacienteId = 'pacienteId';
  static const String pacienteNombre = 'pacienteNombre';
  static const String especialidad = 'especialidad';
  static const String fechaCita = 'fechaCita';
  static const String horaInicio = 'horaInicio';
  static const String estado = 'estado';
  static const String motivo = 'motivo';
  static const String clinica = 'clinica';
  static const String creadoEn = 'creadoEn';
}

/// Estados estandarizados para citas
/// 
/// Todos los estados deben usar estos valores en inglés
class AppointmentStatus {
  static const String pending = 'pending';
  static const String confirmed = 'confirmed';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
  
  /// Convierte un estado en español a inglés
  static String convertFromSpanish(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return pending;
      case 'confirmada':
      case 'confirmed':
        return confirmed;
      case 'completada':
      case 'completed':
        return completed;
      case 'cancelada':
      case 'cancelled':
        return cancelled;
      default:
        return pending;
    }
  }
  
  /// Convierte un estado en inglés a español (para UI)
  static String toSpanish(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pendiente';
      case 'confirmed':
        return 'Confirmada';
      case 'completed':
        return 'Completada';
      case 'cancelled':
        return 'Cancelada';
      default:
        return 'Pendiente';
    }
  }
}

/// Roles de usuario estandarizados
class UserRole {
  static const String patient = 'patient';
  static const String doctor = 'doctor';
  static const String admin = 'admin';
}

