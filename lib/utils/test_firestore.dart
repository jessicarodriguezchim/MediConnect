import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Script de diagnóstico para probar la conexión con Firestore
/// 
/// Usa este script para verificar:
/// - Si puedes leer de Firestore
/// - Si puedes escribir en Firestore
/// - Si las reglas de seguridad están correctas
/// - Si hay problemas de autenticación
class FirestoreTest {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Prueba completa de conexión y permisos
  static Future<void> runFullTest() async {
    debugPrint('🧪 ========================================');
    debugPrint('🧪 INICIANDO PRUEBA DE FIRESTORE');
    debugPrint('🧪 ========================================');

    // 1. Verificar autenticación
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('❌ ERROR: Usuario NO autenticado');
      debugPrint('   Por favor, inicia sesión primero');
      return;
    }

    debugPrint('✅ Usuario autenticado: ${user.uid}');
    debugPrint('   Email: ${user.email}');

    // 2. Probar lectura
    await _testRead();

    // 3. Probar escritura
    await _testWrite();

    debugPrint('🧪 ========================================');
    debugPrint('🧪 PRUEBA COMPLETADA');
    debugPrint('🧪 ========================================');
  }

  /// Prueba de lectura
  static Future<void> _testRead() async {
    debugPrint('\n📖 Probando LECTURA de Firestore...');

    try {
      // Probar leer usuarios
      final usuariosSnapshot = await _firestore.collection('usuarios').limit(1).get();
      debugPrint('✅ Lectura de usuarios: OK (${usuariosSnapshot.docs.length} documentos)');

      // Probar leer medicos
      final medicosSnapshot = await _firestore.collection('medicos').limit(1).get();
      debugPrint('✅ Lectura de medicos: OK (${medicosSnapshot.docs.length} documentos)');

      // Probar leer appointments
      final appointmentsSnapshot = await _firestore.collection('appointments').limit(1).get();
      debugPrint('✅ Lectura de appointments: OK (${appointmentsSnapshot.docs.length} documentos)');

      // Probar leer citas
      final citasSnapshot = await _firestore.collection('citas').limit(1).get();
      debugPrint('✅ Lectura de citas: OK (${citasSnapshot.docs.length} documentos)');

      // Probar leer hospitales
      final hospitalesSnapshot = await _firestore.collection('hospitales').limit(1).get();
      debugPrint('✅ Lectura de hospitales: OK (${hospitalesSnapshot.docs.length} documentos)');
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR en lectura: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Prueba de escritura
  static Future<void> _testWrite() async {
    debugPrint('\n📝 Probando ESCRITURA en Firestore...');

    final user = _auth.currentUser!;
    final testId = 'test_${DateTime.now().millisecondsSinceEpoch}';

    try {
      // 1. Probar escribir en usuarios (test)
      debugPrint('🔵 Intentando escribir en usuarios/test...');
      await _firestore.collection('usuarios').doc('test_$testId').set({
        'test': true,
        'timestamp': FieldValue.serverTimestamp(),
        'uid': user.uid,
      }, SetOptions(merge: true));
      debugPrint('✅ Escritura en usuarios: OK');

      // Verificar que se guardó
      final verifyDoc = await _firestore.collection('usuarios').doc('test_$testId').get();
      if (verifyDoc.exists) {
        debugPrint('✅ Verificación: Documento existe en usuarios');
      } else {
        debugPrint('❌ ERROR: Documento NO se encontró después de escribir');
      }

      // Limpiar test
      await _firestore.collection('usuarios').doc('test_$testId').delete();
      debugPrint('✅ Documento de prueba eliminado');

    } catch (e, stackTrace) {
      debugPrint('❌ ERROR en escritura de usuarios: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (e.toString().contains('PERMISSION_DENIED') || 
          e.toString().contains('permission-denied')) {
        debugPrint('⚠️ PROBLEMA: Reglas de Firestore bloquean la escritura');
        debugPrint('   Solución: Configura las reglas en Firebase Console');
      }
    }

    try {
      // 2. Probar escribir en appointments (test)
      debugPrint('🔵 Intentando escribir en appointments/test...');
      await _firestore.collection('appointments').doc('test_$testId').set({
        'test': true,
        'timestamp': FieldValue.serverTimestamp(),
        'patientId': user.uid,
        'doctorId': 'test_doctor',
        'status': 'pending',
      });
      debugPrint('✅ Escritura en appointments: OK');

      // Verificar que se guardó
      final verifyAppointment = await _firestore.collection('appointments').doc('test_$testId').get();
      if (verifyAppointment.exists) {
        debugPrint('✅ Verificación: Documento existe en appointments');
      } else {
        debugPrint('❌ ERROR: Documento NO se encontró después de escribir');
      }

      // Limpiar test
      await _firestore.collection('appointments').doc('test_$testId').delete();
      debugPrint('✅ Documento de prueba eliminado');

    } catch (e, stackTrace) {
      debugPrint('❌ ERROR en escritura de appointments: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (e.toString().contains('PERMISSION_DENIED') || 
          e.toString().contains('permission-denied')) {
        debugPrint('⚠️ PROBLEMA: Reglas de Firestore bloquean la escritura en appointments');
        debugPrint('   Solución: Configura las reglas en Firebase Console');
      }
    }

    try {
      // 3. Probar escribir en citas (test)
      debugPrint('🔵 Intentando escribir en citas/test...');
      await _firestore.collection('citas').doc('test_$testId').set({
        'test': true,
        'timestamp': FieldValue.serverTimestamp(),
        'pacienteId': user.uid,
        'medicoId': 'test_doctor',
        'estado': 'Pendiente',
      });
      debugPrint('✅ Escritura en citas: OK');

      // Verificar que se guardó
      final verifyCita = await _firestore.collection('citas').doc('test_$testId').get();
      if (verifyCita.exists) {
        debugPrint('✅ Verificación: Documento existe en citas');
      } else {
        debugPrint('❌ ERROR: Documento NO se encontró después de escribir');
      }

      // Limpiar test
      await _firestore.collection('citas').doc('test_$testId').delete();
      debugPrint('✅ Documento de prueba eliminado');

    } catch (e, stackTrace) {
      debugPrint('❌ ERROR en escritura de citas: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (e.toString().contains('PERMISSION_DENIED') || 
          e.toString().contains('permission-denied')) {
        debugPrint('⚠️ PROBLEMA: Reglas de Firestore bloquean la escritura en citas');
        debugPrint('   Solución: Configura las reglas en Firebase Console');
      }
    }
  }

  /// Verificar conexión básica
  static Future<bool> checkConnection() async {
    try {
      await _firestore.collection('test').limit(1).get();
      return true;
    } catch (e) {
      debugPrint('❌ Error de conexión: $e');
      return false;
    }
  }
}

