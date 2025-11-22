/// Script de migración para mover datos de 'citas' a 'appointments'
/// 
/// Este script convierte y migra todas las citas de la colección legacy 'citas'
/// a la nueva colección estandarizada 'appointments'.
/// 
/// USO:
/// 1. Ejecutar este script una vez
/// 2. Verificar que los datos se migraron correctamente
/// 3. Eliminar la colección 'citas' de Firebase (opcional)
/// 
/// IMPORTANTE: Hacer backup de Firebase antes de ejecutar

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/firebase_constants.dart';
import '../services/appointment_converter.dart';
import '../models/appointment_model.dart';

class CitasMigrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Migra todas las citas de 'citas' a 'appointments'
  /// 
  /// [dryRun] - Si es true, solo muestra lo que haría sin hacer cambios
  /// [batchSize] - Número de documentos a procesar por lote
  /// 
  /// Retorna un Map con estadísticas de la migración
  static Future<Map<String, dynamic>> migrateAllCitas({
    bool dryRun = false,
    int batchSize = 100,
  }) async {
    debugPrint('🔄 Iniciando migración de citas...');
    debugPrint('   - Modo: ${dryRun ? "DRY RUN (sin cambios)" : "MIGRACIÓN REAL"}');
    debugPrint('   - Tamaño de lote: $batchSize');

    try {
      // 1. Obtener todas las citas de la colección legacy
      final citasSnapshot = await _firestore
          .collection(FirebaseCollections.citas)
          .get();

      debugPrint('📊 Total de citas encontradas: ${citasSnapshot.docs.length}');

      if (citasSnapshot.docs.isEmpty) {
        return {
          'success': true,
          'total': 0,
          'migrated': 0,
          'skipped': 0,
          'errors': 0,
          'message': 'No hay citas para migrar',
        };
      }

      int migrated = 0;
      int skipped = 0;
      int errors = 0;
      final List<String> errorMessages = [];

      // 2. Procesar en lotes
      for (int i = 0; i < citasSnapshot.docs.length; i += batchSize) {
        final batch = _firestore.batch();
        final end = (i + batchSize < citasSnapshot.docs.length)
            ? i + batchSize
            : citasSnapshot.docs.length;

        debugPrint('📦 Procesando lote ${(i ~/ batchSize) + 1}: documentos $i a ${end - 1}');

        for (int j = i; j < end; j++) {
          final doc = citasSnapshot.docs[j];
          final data = doc.data();

          try {
            // 3. Convertir el documento legacy a AppointmentModel
            // Necesitamos un doctorId para la conversión
            // Si no hay médico asignado, usamos un valor por defecto
            final doctorId = data[FirebaseFields.medicoId] as String? ??
                data[FirebaseFields.medicoDocId] as String? ??
                '';

            if (doctorId.isEmpty) {
              debugPrint('⚠️ Cita ${doc.id} sin médico asignado, usando valor por defecto');
            }

            final appointment = AppointmentConverter.fromCitasDocument(
              doc,
              doctorId.isNotEmpty ? doctorId : 'sin_medico',
            );

            // 4. Verificar si ya existe en appointments (por ID o por datos similares)
            final existingQuery = await _firestore
                .collection(FirebaseCollections.appointments)
                .where('patientDocId', isEqualTo: appointment.patientDocId)
                .where(FirebaseFields.date, isEqualTo: Timestamp.fromDate(appointment.date))
                .where(FirebaseFields.time, isEqualTo: appointment.time)
                .limit(1)
                .get();

            if (existingQuery.docs.isNotEmpty) {
              debugPrint('⏭️ Cita ${doc.id} ya existe en appointments, omitiendo');
              skipped++;
              continue;
            }

            // 5. Crear el documento en appointments
            if (!dryRun) {
              final appointmentData = appointment.toMap();
              appointmentData[FirebaseFields.appointmentId] = doc.id; // Mantener el mismo ID
              
              final newDocRef = _firestore
                  .collection(FirebaseCollections.appointments)
                  .doc(doc.id);
              
              batch.set(newDocRef, appointmentData);
            }

            migrated++;
            debugPrint('✅ Cita ${doc.id} preparada para migración');
          } catch (e) {
            errors++;
            final errorMsg = 'Error en cita ${doc.id}: $e';
            errorMessages.add(errorMsg);
            debugPrint('❌ $errorMsg');
          }
        }

        // 6. Ejecutar el batch
        if (!dryRun && batchSize > 0) {
          await batch.commit();
          debugPrint('✅ Lote ${(i ~/ batchSize) + 1} completado');
        }
      }

      final result = {
        'success': errors == 0,
        'total': citasSnapshot.docs.length,
        'migrated': migrated,
        'skipped': skipped,
        'errors': errors,
        'errorMessages': errorMessages,
        'message': dryRun
            ? 'DRY RUN completado. Ejecutar sin dryRun para migrar realmente.'
            : 'Migración completada',
      };

      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('📊 RESUMEN DE MIGRACIÓN:');
      debugPrint('   - Total de citas: ${result['total']}');
      debugPrint('   - Migradas: ${result['migrated']}');
      debugPrint('   - Omitidas (ya existían): ${result['skipped']}');
      debugPrint('   - Errores: ${result['errors']}');
      debugPrint('═══════════════════════════════════════════════════════════');

      return result;
    } catch (e) {
      debugPrint('❌ Error fatal en migración: $e');
      return {
        'success': false,
        'total': 0,
        'migrated': 0,
        'skipped': 0,
        'errors': 1,
        'errorMessages': ['Error fatal: $e'],
        'message': 'Error en la migración',
      };
    }
  }

  /// Verifica cuántas citas hay en cada colección
  static Future<Map<String, int>> checkCollectionCounts() async {
    try {
      final citasCount = (await _firestore
              .collection(FirebaseCollections.citas)
              .count()
              .get())
          .count;
      
      final appointmentsCount = (await _firestore
              .collection(FirebaseCollections.appointments)
              .count()
              .get())
          .count;

      return {
        'citas': citasCount ?? 0,
        'appointments': appointmentsCount ?? 0,
      };
    } catch (e) {
      debugPrint('Error verificando conteos: $e');
      return {
        'citas': 0,
        'appointments': 0,
      };
    }
  }
}

