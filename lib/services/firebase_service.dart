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
  static Future<void> updateAppointmentStatus(
      String appointmentId, String status) async {
    try {
      // Actualizar en appointments
      await firestore
          .collection('appointments')
          .doc(appointmentId)
          .update({
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      debugPrint('✅ Cita $appointmentId actualizada a estado: $status en appointments');
      
      // También actualizar en citas (legacy) si existe
      // Convertir estado de inglés a español para la colección legacy
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
      
      // Intentar actualizar en citas (puede que no exista)
      try {
        await firestore
            .collection('citas')
            .doc(appointmentId)
            .update({
              'estado': estadoEspanol,
              'actualizadoEn': FieldValue.serverTimestamp(),
            });
        debugPrint('✅ Cita $appointmentId actualizada a estado: $estadoEspanol en citas (legacy)');
      } catch (e) {
        // Si no existe en citas, no es un error crítico
        debugPrint('⚠️ Cita $appointmentId no encontrada en citas (legacy), solo actualizada en appointments');
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
    
    // Filtrar citas de appointments
    for (var doc in allAppointmentsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final docDoctorDocId = (data['doctorDocId'] as String? ?? '').trim();
      final docDoctorId = (data['doctorId'] as String? ?? '').trim();
      final trimmedDoctorDocId = doctorDocId.trim();
      final trimmedDoctorUid = doctorUid?.trim() ?? '';
      
      // Incluir si coincide con doctorDocId, doctorId, o UID (si se proporciona)
      final matches = docDoctorDocId == trimmedDoctorDocId || 
                     docDoctorId == trimmedDoctorDocId ||
                     (trimmedDoctorUid.isNotEmpty && (docDoctorDocId == trimmedDoctorUid || docDoctorId == trimmedDoctorUid));
      
      if (matches) {
        allDocs[doc.id] = doc;
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
    
    // Filtrar citas de citas (legacy)
    for (var doc in allCitasSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final docMedicoDocId = (data['medicoDocId'] as String? ?? '').trim();
      final docMedicoId = (data['medicoId'] as String? ?? '').trim();
      final trimmedDoctorDocId = doctorDocId.trim();
      final trimmedDoctorUid = doctorUid?.trim() ?? '';
      
      // Incluir si coincide con medicoDocId, medicoId, o UID (si se proporciona)
      final matches = docMedicoDocId == trimmedDoctorDocId || 
                     docMedicoId == trimmedDoctorDocId ||
                     (trimmedDoctorUid.isNotEmpty && (docMedicoDocId == trimmedDoctorUid || docMedicoId == trimmedDoctorUid));
      
      if (matches) {
        allDocs['citas_${doc.id}'] = doc; // Prefijo para evitar conflictos
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
        status = data['status'] as String? ?? 'pending';
      } else if (data.containsKey('estado')) {
        // Convertir estado de español a inglés
        final estado = (data['estado'] as String? ?? 'Pendiente').toLowerCase();
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
      final patientDocId = data['patientDocId'] as String? ?? 
                          data['patientId'] as String? ?? 
                          data['pacienteId'] as String? ?? '';
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

      // Guardar datos en Firestore
      await firestore.collection('usuarios').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'email': email,
        'nombre': finalName,
        'displayName': finalName,
        'role': role,
        'phone': phone ?? '',
        'specialty': specialty ?? '',
        'especialidad': specialty ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creando usuario: $e');
      rethrow;
    }
  }
}
