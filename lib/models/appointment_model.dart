import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';

class AppointmentModel {
  final String id;

  // IDs necesarios para el dashboard
  final String doctorId;
  final String patientId;

  // IDs originales (compatibilidad)
  final String doctorDocId;
  final String patientDocId;

  final String doctorName;
  final String patientName;
  final String specialty;
  final DateTime date;
  final String time;
  final String status;
  final String? notes;
  final String? symptoms;
  final DateTime createdAt;
  final DateTime? updatedAt;

  AppointmentModel({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.doctorDocId,
    required this.doctorName,
    required this.patientDocId,
    required this.patientName,
    required this.specialty,
    required this.date,
    required this.time,
    required this.status,
    this.notes,
    this.symptoms,
    required this.createdAt,
    this.updatedAt,
  });

  factory AppointmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final dId = data['doctorDocId'] ?? data['doctorId'] ?? '';
    final pId = data['patientDocId'] ?? data['patientId'] ?? '';

    return AppointmentModel(
      id: doc.id,

      // IDs unificados
      doctorId: data['doctorId'] ?? dId,
      patientId: data['patientId'] ?? pId,

      // IDs originales
      doctorDocId: dId,
      patientDocId: pId,

      doctorName: data['doctorName'] ?? '',
      patientName: data['patientName'] ?? '',
      specialty: data['specialty'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      time: data['time'] ?? '',
      status: data['status'] ?? 'pending',
      notes: data['notes'],
      symptoms: data['symptoms'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,

      // Campos que el dashboard NECESITA (usar doctorId y patientId del constructor)
      'doctorId': doctorId,  // ← Usar doctorId (puede ser UID o docId)
      'patientId': patientId,  // ← Usar patientId (puede ser UID o docId)

      // Campos originales (compatibilidad)
      'doctorDocId': doctorDocId,
      'patientDocId': patientDocId,

      'doctorName': doctorName,
      'patientName': patientName,
      'specialty': specialty,
      'date': Timestamp.fromDate(date),
      'time': time,
      'status': status,
      'notes': notes,
      'symptoms': symptoms,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Getters para estado
  Color get statusColor {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get statusText {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'confirmed':
        return 'Confirmada';
      case 'completed':
        return 'Completada';
      case 'cancelled':
        return 'Cancelada';
      default:
        return status;
    }
  }
}
