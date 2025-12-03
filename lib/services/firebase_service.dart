import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/appointment_model.dart';
import '../models/user_model.dart';
import 'firebase_constants.dart';
import 'appointment_converter.dart';

/// Servicio unificado para todas las operaciones de Firebase
/// 
/// Este servicio centraliza:
/// - Acceso a colecciones
/// - Consultas comunes
/// - Manejo de errores consistente
/// - Conversión de datos
/// 
/// BENEFICIOS:
/// - Código más limpio y mantenible
/// - Menos duplicación
/// - Manejo de errores consistente
/// - Fácil de testear
class FirebaseService {
  static final firestore = FirebaseFirestore.instance;

  /// Obtener citas del doctor en tiempo real
  /// [doctorDocId] - ID del documento del médico en la colección /medicos
  /// [doctorUid] - UID del médico (opcional, para búsqueda adicional)
  static Stream<List<AppointmentModel>> getAppointmentsStream(String doctorDocId, {String? doctorUid}) {
    // Obtener todas las citas y filtrar por doctorDocId, doctorId, o UID
    return firestore
        .collection('appointments')
        .snapshots()
        .map((snapshot) {
          final appointments = <String, AppointmentModel>{};
          
          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final docDoctorDocId = data['doctorDocId'] as String? ?? '';
            final docDoctorId = data['doctorId'] as String? ?? '';
            
            // Incluir si coincide con doctorDocId, doctorId, o UID (si se proporciona)
            final matches = docDoctorDocId == doctorDocId || 
                           docDoctorId == doctorDocId ||
                           (doctorUid != null && (docDoctorDocId == doctorUid || docDoctorId == doctorUid));
            
            if (matches) {
              try {
                final apt = AppointmentModel.fromFirestore(doc);
                appointments[apt.id] = apt;
              } catch (e) {
                debugPrint('Error convirtiendo cita ${doc.id}: $e');
              }
            }
          }
          
          return appointments.values.toList();
        });
  }

  /// Actualizar estado de cita
  /// Actualiza tanto en 'appointments' como en 'citas' (legacy) si existe
  /// Busca la cita correspondiente en 'citas' usando los datos del appointment
  static Future<void> updateAppointmentStatus(
      String appointmentId, String status) async {
    try {
      // 1. Obtener los datos del appointment para buscar la cita correspondiente en 'citas'
      final appointmentDoc = await firestore
          .collection('appointments')
          .doc(appointmentId)
          .get();
      
      if (!appointmentDoc.exists) {
        throw Exception('No se encontró la cita con ID: $appointmentId');
      }
      
      final appointmentData = appointmentDoc.data() as Map<String, dynamic>;
      
      // 2. Actualizar en appointments
      await firestore
          .collection('appointments')
          .doc(appointmentId)
          .update({
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      debugPrint('✅ Cita $appointmentId actualizada a estado: $status en appointments');
      
      // 3. Convertir estado de inglés a español para la colección legacy
      String estadoEspanol = 'Pendiente';
      switch (status.toLowerCase()) {
        case 'pending':
          estadoEspanol = 'Pendiente';
          break;
        case 'confirmed':
          estadoEspanol = 'Confirmada';
          break;
        case 'completed':
          estadoEspanol = 'Completada';
          break;
        case 'cancelled':
          estadoEspanol = 'Cancelada';
          break;
      }
      
      // 4. Buscar y actualizar la cita correspondiente en 'citas' (legacy)
      try {
        // Obtener datos del appointment para buscar la cita correspondiente
        final patientDocId = appointmentData['patientDocId'] ?? appointmentData['patientId'] ?? '';
        final doctorDocId = appointmentData['doctorDocId'] ?? appointmentData['doctorId'] ?? '';
        final doctorId = appointmentData['doctorId'] ?? '';
        final appointmentDate = appointmentData['date'];
        final appointmentTime = appointmentData['time'] ?? '';
        
        if (patientDocId.toString().isNotEmpty && appointmentDate != null) {
          // Convertir la fecha del appointment a DateTime para comparar
          DateTime appointmentDateTime;
          if (appointmentDate is Timestamp) {
            appointmentDateTime = appointmentDate.toDate();
          } else if (appointmentDate is DateTime) {
            appointmentDateTime = appointmentDate;
          } else {
            throw Exception('Formato de fecha no válido');
          }
          
          // Construir fecha y hora completa para comparar
          DateTime fechaHoraCompleta = appointmentDateTime;
          
          // Si tenemos el tiempo como string, actualizar la hora
          if (appointmentTime.isNotEmpty) {
            final partesHora = appointmentTime.split(':');
            if (partesHora.length == 2) {
              fechaHoraCompleta = DateTime(
                appointmentDateTime.year,
                appointmentDateTime.month,
                appointmentDateTime.day,
                int.parse(partesHora[0]),
                int.parse(partesHora[1]),
              );
            }
          }
          
          debugPrint('🔍 Buscando cita correspondiente en citas (legacy)...');
          debugPrint('   patientDocId: $patientDocId');
          debugPrint('   fecha/hora: ${fechaHoraCompleta}');
          
          // Buscar la cita en 'citas' usando pacienteId
          final citasQuery = await firestore
              .collection('citas')
              .where('pacienteId', isEqualTo: patientDocId)
              .get();
          
          debugPrint('📋 Citas encontradas del paciente: ${citasQuery.docs.length}');
          
          // Buscar la cita que coincida con fecha y hora
          DocumentSnapshot? citaEncontrada;
          
          for (var doc in citasQuery.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final horaInicio = data['horaInicio'] as Timestamp?;
            
            if (horaInicio != null) {
              final horaInicioDate = horaInicio.toDate();
              
              // Comparar fecha y hora (ignorando segundos y milisegundos)
              final fechaCoincide = horaInicioDate.year == fechaHoraCompleta.year &&
                                   horaInicioDate.month == fechaHoraCompleta.month &&
                                   horaInicioDate.day == fechaHoraCompleta.day &&
                                   horaInicioDate.hour == fechaHoraCompleta.hour &&
                                   horaInicioDate.minute == fechaHoraCompleta.minute;
              
              // También verificar médico si está disponible (para mayor precisión)
              bool medicoCoincide = true;
              if (doctorDocId.isNotEmpty || doctorId.isNotEmpty) {
                final citaMedicoId = data['medicoId'] ?? '';
                final citaMedicoDocId = data['medicoDocId'] ?? '';
                medicoCoincide = citaMedicoId == doctorId || 
                               citaMedicoId == doctorDocId ||
                               citaMedicoDocId == doctorDocId ||
                               citaMedicoDocId == doctorId;
              }
              
              if (fechaCoincide && medicoCoincide) {
                citaEncontrada = doc;
                debugPrint('✅ Cita encontrada por fecha, hora y médico: ${doc.id}');
                break;
              }
            }
          }
          
          // Si no encontramos por fecha y hora exacta, intentar solo por fecha (día completo)
          if (citaEncontrada == null && citasQuery.docs.isNotEmpty) {
            for (var doc in citasQuery.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final horaInicio = data['horaInicio'] as Timestamp?;
              
              if (horaInicio != null) {
                final horaInicioDate = horaInicio.toDate();
                
                // Comparar solo fecha (día, mes, año)
                final fechaCoincide = horaInicioDate.year == fechaHoraCompleta.year &&
                                     horaInicioDate.month == fechaHoraCompleta.month &&
                                     horaInicioDate.day == fechaHoraCompleta.day;
                
                if (fechaCoincide) {
                  citaEncontrada = doc;
                  debugPrint('⚠️ Cita encontrada solo por fecha (sin coincidencia de hora exacta): ${doc.id}');
                  break;
                }
              }
            }
          }
          
          if (citaEncontrada != null) {
            // Actualizar la cita encontrada
            await citaEncontrada.reference.update({
              'estado': estadoEspanol,
              'actualizadoEn': FieldValue.serverTimestamp(),
            });
            debugPrint('✅ Cita ${citaEncontrada.id} actualizada a estado: $estadoEspanol en citas (legacy)');
            debugPrint('   Appointment ID: $appointmentId → Cita ID: ${citaEncontrada.id}');
          } else {
            debugPrint('⚠️ No se encontró cita correspondiente en citas (legacy) para appointment $appointmentId');
            debugPrint('   Esto es normal si la cita solo existe en appointments');
          }
        } else {
          debugPrint('⚠️ No se pueden obtener datos suficientes para buscar en citas (legacy)');
        }
      } catch (e) {
        // Si hay error buscando en citas, no es crítico (la cita puede no existir ahí)
        debugPrint('⚠️ Error buscando/actualizando en citas (legacy): $e (no crítico)');
        debugPrint('   La cita fue actualizada exitosamente en appointments');
      }
    } catch (e) {
      debugPrint('❌ Error actualizando estado de cita $appointmentId: $e');
      rethrow;
    }
  }

  /// Contadores para Dashboard
  /// [doctorDocId] - ID del documento del médico en la colección /medicos (puede ser UID o docId)
  /// [doctorUid] - UID del médico (opcional, para búsqueda adicional)
  static Future<Map<String, int>> getDashboardStats(String doctorDocId, {String? doctorUid}) async {
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('📊 getDashboardStats: Buscando citas');
    debugPrint('   doctorDocId: "$doctorDocId"');
    debugPrint('   doctorUid: "$doctorUid"');
    debugPrint('═══════════════════════════════════════════════════════════');
    
    // Obtener TODAS las citas de appointments y filtrar en memoria
    final allAppointmentsSnapshot = await firestore
        .collection('appointments')
        .get();
    
    debugPrint('📋 Total de citas en appointments: ${allAppointmentsSnapshot.docs.length}');
    
    // Obtener TODAS las citas de citas (legacy) y filtrar en memoria
    final allCitasSnapshot = await firestore
        .collection('citas')
        .get();
    
    debugPrint('📋 Total de citas en citas (legacy): ${allCitasSnapshot.docs.length}');
    
    // Combinar resultados sin duplicados - filtrar en memoria
    final allDocs = <String, DocumentSnapshot>{};
    // Mapa para detectar duplicados basado en datos de la cita (paciente, fecha, hora, médico)
    final duplicateKeys = <String, DocumentSnapshot>{};
    
    // Función auxiliar para generar clave única de una cita
    String? getAppointmentKey(Map<String, dynamic> data) {
      // Obtener paciente
      String patientId = '';
      if (data.containsKey('patientDocId') && data['patientDocId'] is String) {
        patientId = (data['patientDocId'] as String).trim();
      } else if (data.containsKey('patientId') && data['patientId'] is String) {
        patientId = (data['patientId'] as String).trim();
      } else if (data.containsKey('pacienteId') && data['pacienteId'] is String) {
        patientId = (data['pacienteId'] as String).trim();
      }
      
      // Obtener fecha
      DateTime? appointmentDate;
      if (data.containsKey('date')) {
        final dateField = data['date'];
        if (dateField is Timestamp) {
          appointmentDate = dateField.toDate();
        } else if (dateField is DateTime) {
          appointmentDate = dateField;
        }
      } else if (data.containsKey('fechaCita')) {
        final dateField = data['fechaCita'];
        if (dateField is Timestamp) {
          appointmentDate = dateField.toDate();
        } else if (dateField is DateTime) {
          appointmentDate = dateField;
        }
      }
      
      // Obtener hora - puede ser String o Timestamp
      String time = '';
      if (data.containsKey('time')) {
        final timeField = data['time'];
        if (timeField is String) {
          time = timeField.trim();
        } else if (timeField is Timestamp) {
          // Convertir Timestamp a String HH:mm
          final dateTime = timeField.toDate();
          time = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
        }
      } else if (data.containsKey('horaInicio')) {
        final horaInicioField = data['horaInicio'];
        if (horaInicioField is String) {
          time = horaInicioField.trim();
        } else if (horaInicioField is Timestamp) {
          // Convertir Timestamp a String HH:mm
          final dateTime = horaInicioField.toDate();
          time = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
        }
      }
      
      // Obtener médico
      String doctorId = '';
      if (data.containsKey('doctorDocId') && data['doctorDocId'] is String) {
        doctorId = (data['doctorDocId'] as String).trim();
      } else if (data.containsKey('doctorId') && data['doctorId'] is String) {
        doctorId = (data['doctorId'] as String).trim();
      } else if (data.containsKey('medicoDocId') && data['medicoDocId'] is String) {
        doctorId = (data['medicoDocId'] as String).trim();
      } else if (data.containsKey('medicoId') && data['medicoId'] is String) {
        doctorId = (data['medicoId'] as String).trim();
      }
      
      if (patientId.isEmpty || appointmentDate == null || time.isEmpty || doctorId.isEmpty) {
        return null; // No se puede crear una clave única sin estos datos
      }
      
      // Crear clave única: doctor_patient_date_time
      final dateStr = '${appointmentDate.year}-${appointmentDate.month.toString().padLeft(2, '0')}-${appointmentDate.day.toString().padLeft(2, '0')}';
      return '$doctorId|$patientId|$dateStr|$time';
    }
    
    // Primero, agregar todas las citas de appointments (colección nueva tiene prioridad)
    for (var doc in allAppointmentsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      String docDoctorDocId = '';
      String docDoctorId = '';
      if (data.containsKey('doctorDocId') && data['doctorDocId'] is String) {
        docDoctorDocId = (data['doctorDocId'] as String).trim();
      }
      if (data.containsKey('doctorId') && data['doctorId'] is String) {
        docDoctorId = (data['doctorId'] as String).trim();
      }
      final trimmedDoctorDocId = doctorDocId.trim();
      final trimmedDoctorUid = doctorUid?.trim() ?? '';
      
      // Incluir si coincide con doctorDocId, doctorId, o UID (si se proporciona)
      final matches = docDoctorDocId == trimmedDoctorDocId || 
                     docDoctorId == trimmedDoctorDocId ||
                     (trimmedDoctorUid.isNotEmpty && (docDoctorDocId == trimmedDoctorUid || docDoctorId == trimmedDoctorUid));
      
      if (matches) {
        allDocs[doc.id] = doc;
        // Guardar clave única para detección de duplicados
        final key = getAppointmentKey(data);
        if (key != null) {
          duplicateKeys[key] = doc;
        }
        debugPrint('   ✅ appointments/${doc.id}: doctorDocId="$docDoctorDocId", doctorId="$docDoctorId"');
      } else {
        // Log detallado para debugging
        debugPrint('   ❌ appointments/${doc.id}: NO coincide');
        debugPrint('      doctorDocId: "$docDoctorDocId" (length: ${docDoctorDocId.length})');
        debugPrint('      doctorId: "$docDoctorId" (length: ${docDoctorId.length})');
        debugPrint('      doctorDocId buscado: "$trimmedDoctorDocId" (length: ${trimmedDoctorDocId.length})');
        debugPrint('      doctorUid buscado: "$trimmedDoctorUid" (length: ${trimmedDoctorUid.length})');
      }
    }
    
    // Luego, agregar citas de citas (legacy) solo si no son duplicados
    for (var doc in allCitasSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      String docMedicoDocId = '';
      String docMedicoId = '';
      if (data.containsKey('medicoDocId') && data['medicoDocId'] is String) {
        docMedicoDocId = (data['medicoDocId'] as String).trim();
      }
      if (data.containsKey('medicoId') && data['medicoId'] is String) {
        docMedicoId = (data['medicoId'] as String).trim();
      }
      final trimmedDoctorDocId = doctorDocId.trim();
      final trimmedDoctorUid = doctorUid?.trim() ?? '';
      
      // Incluir si coincide con medicoDocId, medicoId, o UID (si se proporciona)
      final matches = docMedicoDocId == trimmedDoctorDocId || 
                     docMedicoId == trimmedDoctorDocId ||
                     (trimmedDoctorUid.isNotEmpty && (docMedicoDocId == trimmedDoctorUid || docMedicoId == trimmedDoctorUid));
      
      if (matches) {
        // Verificar si es duplicado antes de agregar
        final key = getAppointmentKey(data);
        if (key != null && duplicateKeys.containsKey(key)) {
          debugPrint('   ⏭️ citas/${doc.id}: DUPLICADO detectado, omitiendo (ya existe en appointments)');
          continue; // Omitir duplicado
        }
        
        allDocs['citas_${doc.id}'] = doc; // Prefijo para evitar conflictos
        if (key != null) {
          duplicateKeys[key] = doc;
        }
        debugPrint('   ✅ citas/${doc.id}: medicoDocId="$docMedicoDocId", medicoId="$docMedicoId"');
      } else {
        // Log detallado para debugging
        debugPrint('   ❌ citas/${doc.id}: NO coincide');
        debugPrint('      medicoDocId: "$docMedicoDocId" (length: ${docMedicoDocId.length})');
        debugPrint('      medicoId: "$docMedicoId" (length: ${docMedicoId.length})');
        debugPrint('      doctorDocId: "$trimmedDoctorDocId" (length: ${trimmedDoctorDocId.length})');
        debugPrint('      doctorUid: "$trimmedDoctorUid" (length: ${trimmedDoctorUid.length})');
      }
    }

    int total = allDocs.length;
    int pending = 0;
    int confirmed = 0;
    int completed = 0;
    int cancelled = 0;
    int todayAppointments = 0;
    final patientIds = <String>{};

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    for (var doc in allDocs.values) {
      final data = doc.data() as Map<String, dynamic>;
      
      // Manejar status de ambas colecciones
      String status = 'pending';
      if (data.containsKey('status')) {
        final statusField = data['status'];
        if (statusField is String) {
          status = statusField;
        } else {
          status = 'pending';
        }
      } else if (data.containsKey('estado')) {
        // Convertir estado de español a inglés
        final estadoField = data['estado'];
        String estadoStr = 'Pendiente';
        if (estadoField is String) {
          estadoStr = estadoField;
        }
        final estado = estadoStr.toLowerCase();
        switch (estado) {
          case 'pendiente':
            status = 'pending';
            break;
          case 'confirmada':
          case 'confirmed':
            status = 'confirmed';
            break;
          case 'completada':
          case 'completed':
            status = 'completed';
            break;
          case 'cancelada':
          case 'cancelled':
            status = 'cancelled';
            break;
          default:
            status = 'pending';
        }
      }

      if (status == 'pending') pending++;
      if (status == 'confirmed') confirmed++;
      if (status == 'completed') completed++;
      if (status == 'cancelled') cancelled++;
      
      // Contar citas de hoy - manejar ambos formatos
      DateTime? appointmentDate;
      if (data.containsKey('date')) {
        final dateField = data['date'];
        if (dateField is Timestamp) {
          appointmentDate = dateField.toDate();
        }
      } else if (data.containsKey('fechaCita')) {
        final dateField = data['fechaCita'];
        if (dateField is Timestamp) {
          appointmentDate = dateField.toDate();
        }
      }
      
      if (appointmentDate != null) {
        if (appointmentDate.isAfter(todayStart.subtract(const Duration(milliseconds: 1))) &&
            appointmentDate.isBefore(todayEnd)) {
          todayAppointments++;
        }
      }
      
      // Contar pacientes únicos - manejar ambos formatos
      String patientDocId = '';
      if (data.containsKey('patientDocId') && data['patientDocId'] is String) {
        patientDocId = data['patientDocId'] as String;
      } else if (data.containsKey('patientId') && data['patientId'] is String) {
        patientDocId = data['patientId'] as String;
      } else if (data.containsKey('pacienteId') && data['pacienteId'] is String) {
        patientDocId = data['pacienteId'] as String;
      }
      if (patientDocId.isNotEmpty) {
        patientIds.add(patientDocId);
      }
    }

    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('📊 Estadísticas calculadas:');
    debugPrint('   total: $total');
    debugPrint('   pending: $pending');
    debugPrint('   confirmed: $confirmed');
    debugPrint('   completed: $completed');
    debugPrint('   cancelled: $cancelled');
    debugPrint('   today: $todayAppointments');
    debugPrint('   patients: ${patientIds.length}');
    debugPrint('═══════════════════════════════════════════════════════════');

    return {
      'totalAppointments': total,
      'pendingAppointments': pending,
      'confirmedAppointments': confirmed,
      'completedAppointments': completed,
      'cancelledAppointments': cancelled,
      'todayAppointments': todayAppointments,
      'totalPatients': patientIds.length,
    };
  }

  /// Obtener citas del doctor (una sola vez)
  /// [doctorDocId] - ID del documento del médico en la colección /medicos
  /// [doctorUid] - UID del médico (opcional, para búsqueda adicional)
  static Future<List<AppointmentModel>> getAppointments(String doctorDocId, {String? doctorUid}) async {
    // Obtener TODAS las citas y filtrar en memoria
    final allAppointmentsSnapshot = await firestore
        .collection('appointments')
        .get();
    
    // Combinar resultados sin duplicados
    final allAppointments = <String, AppointmentModel>{};
    
    for (var doc in allAppointmentsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final docDoctorDocId = data['doctorDocId'] as String? ?? '';
      final docDoctorId = data['doctorId'] as String? ?? '';
      
      // Incluir si coincide con doctorDocId, doctorId, o UID (si se proporciona)
      final matches = docDoctorDocId == doctorDocId || 
                     docDoctorId == doctorDocId ||
                     (doctorUid != null && (docDoctorDocId == doctorUid || docDoctorId == doctorUid));
      
      if (matches) {
        try {
          final apt = AppointmentModel.fromFirestore(doc);
          allAppointments[apt.id] = apt;
        } catch (e) {
          debugPrint('Error convirtiendo cita ${doc.id}: $e');
        }
      }
    }

    return allAppointments.values.toList();
  }

  /// Obtener usuario actual de Firebase Auth
  static User? getCurrentUser() {
    return FirebaseAuth.instance.currentUser;
  }

  /// Obtener el ID del documento del médico en la colección /medicos
  /// Busca por UID del usuario autenticado
  /// Retorna el docId del médico o null si no se encuentra
  static Future<String?> getDoctorDocId(String userUid) async {
    try {
      debugPrint('🔍 getDoctorDocId: Buscando para UID: $userUid');
      
      // 1. Buscar en la colección medicos por el campo uid
      final query = await firestore
          .collection('medicos')
          .where('uid', isEqualTo: userUid)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final data = doc.data();
        // Verificar que el documento tenga uid (no es una especialidad)
        if (data.containsKey('uid') && data['uid'] == userUid) {
          final docId = doc.id;
          debugPrint('✅ Encontrado en medicos por uid: $docId');
          return docId;
        }
      }
      
      // 2. Si no se encuentra, buscar si el docId es el mismo que el UID
      final doc = await firestore.collection('medicos').doc(userUid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        // Verificar que el documento tenga uid (no es una especialidad)
        if (data != null && data.containsKey('uid') && data['uid'] == userUid) {
          debugPrint('✅ Encontrado en medicos por docId=UID: $userUid');
          return userUid;
        }
      }
      
      // 3. Buscar en usuarios con role='doctor'
      final usuarioDoc = await firestore.collection('usuarios').doc(userUid).get();
      if (usuarioDoc.exists) {
        final data = usuarioDoc.data() as Map<String, dynamic>?;
        final role = data?['role'] as String?;
        if (role == 'doctor') {
          // Si es doctor en usuarios, buscar o crear en medicos
          debugPrint('✅ Usuario es doctor en usuarios, buscando en medicos...');
          
          // Intentar encontrar en medicos por cualquier campo
          final medicosQuery = await firestore
              .collection('medicos')
              .where('uid', isEqualTo: userUid)
              .limit(1)
              .get();
          
          if (medicosQuery.docs.isNotEmpty) {
            return medicosQuery.docs.first.id;
          }
          
          // Si no existe en medicos, usar el UID como docId (compatibilidad)
          debugPrint('⚠️ No encontrado en medicos, usando UID como docId: $userUid');
          return userUid;
        }
      }
      
      debugPrint('❌ No se encontró doctorDocId para UID: $userUid');
      return null;
    } catch (e) {
      debugPrint('❌ Error obteniendo doctorDocId: $e');
      return null;
    }
  }

  /// Obtener datos de usuario de Firestore
  static Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await firestore.collection('usuarios').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error obteniendo usuario: $e');
      return null;
    }
  }

  /// Actualizar perfil de usuario
  static Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await firestore.collection('usuarios').doc(uid).update(data);
  }

  /// Crear nuevo usuario
  static Future<void> createUser({
    required String email,
    required String password,
    required String name,
    String? displayName,
    required String role,
    String? phone,
    String? specialty,
  }) async {
    final finalName = displayName ?? name;
    try {
      // Crear usuario en Auth
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userUid = credential.user!.uid;
      
      // Guardar datos en Firestore - colección usuarios
      try {
        debugPrint('🔵 Intentando guardar usuario en Firestore...');
        debugPrint('   UID: $userUid');
        debugPrint('   Email: $email');
        debugPrint('   Nombre: $finalName');
        debugPrint('   Rol: $role');
        
        final userData = {
          'uid': userUid,
          'email': email,
          'nombre': finalName,
          'displayName': finalName,
          'role': role,
          'phone': phone ?? '',
          'specialty': specialty ?? '',
          'especialidad': specialty ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        };
        
        await firestore.collection('usuarios').doc(userUid).set(userData);
        
        debugPrint('✅ Usuario creado exitosamente en colección usuarios: $userUid');
        
        // Verificar que se guardó correctamente
        final verifyDoc = await firestore.collection('usuarios').doc(userUid).get();
        if (verifyDoc.exists) {
          debugPrint('✅ Verificación: Usuario existe en Firestore');
        } else {
          debugPrint('❌ ERROR: Usuario NO se encontró después de guardar');
        }
      } catch (e, stackTrace) {
        debugPrint('❌ ERROR al guardar usuario en usuarios: $e');
        debugPrint('Stack trace: $stackTrace');
        rethrow;
      }
      
      // Si es médico, también crear en la colección medicos para compatibilidad inmediata
      if (role == 'doctor') {
        try {
          debugPrint('🔵 Intentando guardar médico en colección medicos...');
          
          final medicoData = {
            'uid': userUid,
            'email': email,
            'nombre': finalName,
            'especialidad': specialty ?? 'General',
            'specialty': specialty ?? 'General',
            'createdAt': FieldValue.serverTimestamp(),
          };
          
          await firestore.collection('medicos').doc(userUid).set(medicoData, SetOptions(merge: true));
          
          debugPrint('✅ Médico creado exitosamente en colección medicos: $userUid');
          
          // Verificar que se guardó
          final verifyMedicoDoc = await firestore.collection('medicos').doc(userUid).get();
          if (verifyMedicoDoc.exists) {
            debugPrint('✅ Verificación: Médico existe en Firestore');
          } else {
            debugPrint('❌ ERROR: Médico NO se encontró después de guardar');
          }
        } catch (e, stackTrace) {
          debugPrint('❌ ERROR al guardar médico en medicos: $e');
          debugPrint('Stack trace: $stackTrace');
          // No rethrow aquí, el usuario ya fue creado en usuarios
        }
      }
    } catch (e) {
      debugPrint('❌ Error creando usuario: $e');
      rethrow;
    }
  }
}
