import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Utilidad para corregir las citas de un médico específico
/// Actualiza los campos doctorId, doctorDocId, medicoId, medicoDocId con el UID correcto
class FixDoctorAppointments {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Busca un médico por email y retorna su UID y docId
  static Future<Map<String, String?>> findDoctorByEmail(String email) async {
    try {
      debugPrint('🔍 Buscando médico con email: $email');
      
      // Buscar en usuarios
      final usuariosQuery = await _firestore
          .collection('usuarios')
          .where('email', isEqualTo: email)
          .where('role', isEqualTo: 'doctor')
          .limit(1)
          .get();
      
      if (usuariosQuery.docs.isNotEmpty) {
        final doc = usuariosQuery.docs.first;
        final data = doc.data();
        final uid = data['uid'] as String?;
        debugPrint('✅ Encontrado en usuarios: UID=$uid, docId=${doc.id}');
        return {'uid': uid, 'docId': doc.id};
      }
      
      // Buscar en medicos
      final medicosQuery = await _firestore
          .collection('medicos')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (medicosQuery.docs.isNotEmpty) {
        final doc = medicosQuery.docs.first;
        final data = doc.data();
        final uid = data['uid'] as String?;
        debugPrint('✅ Encontrado en medicos: UID=$uid, docId=${doc.id}');
        return {'uid': uid, 'docId': doc.id};
      }
      
      debugPrint('❌ No se encontró médico con email: $email');
      return {'uid': null, 'docId': null};
    } catch (e) {
      debugPrint('❌ Error buscando médico: $e');
      return {'uid': null, 'docId': null};
    }
  }

  /// Busca un médico por nombre y retorna su UID y docId
  static Future<Map<String, String?>> findDoctorByName(String name) async {
    try {
      debugPrint('🔍 Buscando médico con nombre: $name');
      
      // Buscar en usuarios
      final usuariosQuery = await _firestore
          .collection('usuarios')
          .where('nombre', isEqualTo: name)
          .where('role', isEqualTo: 'doctor')
          .limit(1)
          .get();
      
      if (usuariosQuery.docs.isNotEmpty) {
        final doc = usuariosQuery.docs.first;
        final data = doc.data();
        final uid = data['uid'] as String?;
        debugPrint('✅ Encontrado en usuarios: UID=$uid, docId=${doc.id}');
        return {'uid': uid, 'docId': doc.id};
      }
      
      // Buscar en medicos (solo los que tienen uid)
      final medicosQuery = await _firestore
          .collection('medicos')
          .where('nombre', isEqualTo: name)
          .limit(10)
          .get();
      
      for (var doc in medicosQuery.docs) {
        final data = doc.data();
        if (data.containsKey('uid') && data['uid'] != null) {
          final uid = data['uid'] as String?;
          debugPrint('✅ Encontrado en medicos: UID=$uid, docId=${doc.id}');
          return {'uid': uid, 'docId': doc.id};
        }
      }
      
      debugPrint('❌ No se encontró médico con nombre: $name');
      return {'uid': null, 'docId': null};
    } catch (e) {
      debugPrint('❌ Error buscando médico: $e');
      return {'uid': null, 'docId': null};
    }
  }

  /// Actualiza todas las citas de un médico con su UID correcto
  /// [doctorUid] - UID del médico
  /// [doctorDocId] - ID del documento del médico (opcional, si no se proporciona se usa el UID)
  /// [dryRun] - Si es true, solo muestra qué se actualizaría sin hacer cambios
  static Future<Map<String, int>> fixDoctorAppointments(
    String doctorUid, {
    String? doctorDocId,
    bool dryRun = false,
  }) async {
    final finalDoctorDocId = doctorDocId ?? doctorUid;
    debugPrint('🔧 FixDoctorAppointments: doctorUid=$doctorUid, doctorDocId=$finalDoctorDocId, dryRun=$dryRun');
    
    int appointmentsUpdated = 0;
    int citasUpdated = 0;
    int errors = 0;
    
    try {
      // 1. Actualizar citas en colección 'appointments'
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .get();
      
      debugPrint('📋 Total de citas en appointments: ${appointmentsSnapshot.docs.length}');
      
      for (var doc in appointmentsSnapshot.docs) {
        final data = doc.data();
        final currentDoctorId = data['doctorId'] as String? ?? '';
        final currentDoctorDocId = data['doctorDocId'] as String? ?? '';
        
        // Verificar si esta cita pertenece al médico (por nombre o por ID actual)
        final doctorName = data['doctorName'] as String? ?? '';
        final shouldUpdate = currentDoctorId == doctorUid || 
                           currentDoctorDocId == doctorUid ||
                           currentDoctorDocId == finalDoctorDocId ||
                           doctorName.toLowerCase().contains('jessica') ||
                           doctorName.toLowerCase().contains('rodriguez');
        
        if (shouldUpdate && (currentDoctorId != doctorUid || currentDoctorDocId != finalDoctorDocId)) {
          debugPrint('   📝 appointments/${doc.id}: Actualizando doctorId=$currentDoctorId -> $doctorUid, doctorDocId=$currentDoctorDocId -> $finalDoctorDocId');
          
          if (!dryRun) {
            try {
              await doc.reference.update({
                'doctorId': doctorUid,
                'doctorDocId': finalDoctorDocId,
              });
              appointmentsUpdated++;
            } catch (e) {
              debugPrint('   ❌ Error actualizando appointments/${doc.id}: $e');
              errors++;
            }
          } else {
            appointmentsUpdated++;
          }
        }
      }
      
      // 2. Actualizar citas en colección 'citas' (legacy)
      final citasSnapshot = await _firestore
          .collection('citas')
          .get();
      
      debugPrint('📋 Total de citas en citas (legacy): ${citasSnapshot.docs.length}');
      
      for (var doc in citasSnapshot.docs) {
        final data = doc.data();
        final currentMedicoId = data['medicoId'] as String? ?? '';
        final currentMedicoDocId = data['medicoDocId'] as String? ?? '';
        final medicoNombre = data['medicoNombre'] as String? ?? '';
        
        // Verificar si esta cita pertenece al médico
        final shouldUpdate = currentMedicoId == doctorUid || 
                           currentMedicoDocId == doctorUid ||
                           currentMedicoDocId == finalDoctorDocId ||
                           medicoNombre.toLowerCase().contains('jessica') ||
                           medicoNombre.toLowerCase().contains('rodriguez');
        
        if (shouldUpdate && (currentMedicoId != doctorUid || currentMedicoDocId != finalDoctorDocId)) {
          debugPrint('   📝 citas/${doc.id}: Actualizando medicoId=$currentMedicoId -> $doctorUid, medicoDocId=$currentMedicoDocId -> $finalDoctorDocId');
          
          if (!dryRun) {
            try {
              await doc.reference.update({
                'medicoId': doctorUid,
                'medicoDocId': finalDoctorDocId,
              });
              citasUpdated++;
            } catch (e) {
              debugPrint('   ❌ Error actualizando citas/${doc.id}: $e');
              errors++;
            }
          } else {
            citasUpdated++;
          }
        }
      }
      
      debugPrint('✅ FixDoctorAppointments completado: appointments=$appointmentsUpdated, citas=$citasUpdated, errores=$errors');
      
      return {
        'appointmentsUpdated': appointmentsUpdated,
        'citasUpdated': citasUpdated,
        'errors': errors,
      };
    } catch (e) {
      debugPrint('❌ Error en FixDoctorAppointments: $e');
      return {
        'appointmentsUpdated': appointmentsUpdated,
        'citasUpdated': citasUpdated,
        'errors': errors + 1,
      };
    }
  }

  /// Función principal para corregir las citas de jessica.rodriguez
  static Future<void> fixJessicaRodriguezAppointments({bool dryRun = true}) async {
    debugPrint('🚀 Iniciando corrección de citas para jessica.rodriguez...');
    
    // Buscar por email
    final doctor1 = await findDoctorByEmail('jessica.rodriguez@tecdesoftware.com');
    final doctor2 = await findDoctorByEmail('jessica.rodriguez@gmail.com');
    
    // Buscar por nombre si no se encontró por email
    Map<String, String?> doctor = doctor1['uid'] != null ? doctor1 : doctor2;
    if (doctor['uid'] == null) {
      doctor = await findDoctorByName('jessica.rodriguez');
    }
    if (doctor['uid'] == null) {
      doctor = await findDoctorByName('jesssica Rodriguez');
    }
    
    if (doctor['uid'] == null) {
      debugPrint('❌ No se pudo encontrar jessica.rodriguez en Firebase');
      return;
    }
    
    final uid = doctor['uid']!;
    final docId = doctor['docId'] ?? uid;
    
    debugPrint('👤 Médico encontrado: UID=$uid, docId=$docId');
    
    // Corregir citas
    final result = await fixDoctorAppointments(
      uid,
      doctorDocId: docId,
      dryRun: dryRun,
    );
    
    debugPrint('📊 Resultado:');
    debugPrint('   - Citas en appointments actualizadas: ${result['appointmentsUpdated']}');
    debugPrint('   - Citas en citas actualizadas: ${result['citasUpdated']}');
    debugPrint('   - Errores: ${result['errors']}');
    
    if (dryRun) {
      debugPrint('⚠️ Modo DRY RUN - No se realizaron cambios reales');
      debugPrint('💡 Para aplicar los cambios, ejecuta con dryRun=false');
    } else {
      debugPrint('✅ Cambios aplicados correctamente');
    }
  }
}

