// models/appointment_model.dart
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AppointmentModel {
  final String id;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String specialty;
  final DateTime date;
  final String time;
  final String status; // 'pending', 'confirmed', 'completed', 'cancelled'
  final String? notes;
  final String? symptoms;
  final DateTime createdAt;
  final DateTime? updatedAt;

  AppointmentModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.specialty,
    required this.date,
    required this.time,
    this.status = 'pending',
    this.notes,
    this.symptoms,
    required this.createdAt,
    this.updatedAt,
  });

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'doctorId': doctorId,
      'doctorName': doctorName,
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

  // Crear desde Map de Firestore
  factory AppointmentModel.fromMap(Map<String, dynamic> map) {
    return AppointmentModel(
      id: map['id'] ?? '',
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? '',
      doctorId: map['doctorId'] ?? '',
      doctorName: map['doctorName'] ?? '',
      specialty: map['specialty'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      time: map['time'] ?? '',
      status: map['status'] ?? 'pending',
      notes: map['notes'],
      symptoms: map['symptoms'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Crear desde DocumentSnapshot
  factory AppointmentModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppointmentModel.fromMap({...data, 'id': doc.id});
  }

  // Copiar con cambios
  AppointmentModel copyWith({
    String? id,
    String? patientId,
    String? patientName,
    String? doctorId,
    String? doctorName,
    String? specialty,
    DateTime? date,
    String? time,
    String? status,
    String? notes,
    String? symptoms,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      specialty: specialty ?? this.specialty,
      date: date ?? this.date,
      time: time ?? this.time,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      symptoms: symptoms ?? this.symptoms,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper para verificar si la cita es hoy
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // Helper para verificar si la cita es próxima (en los próximos 7 días)
  bool get isUpcoming {
    final now = DateTime.now();
    final sevenDaysFromNow = now.add(const Duration(days: 7));
    return date.isAfter(now) && date.isBefore(sevenDaysFromNow);
  }

  // Helper para obtener fecha formateada
  String get formattedDate {
    return '${_getDayName(date.weekday)}, ${date.day}/${date.month}/${date.year}';
  }

  String _getDayName(int weekday) {
    const days = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    return days[weekday % 7];
  }

  // Helper para obtener color según el estado
  Color get statusColor {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Helper para obtener texto del estado
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
        return 'Desconocido';
    }
  }

  @override
  String toString() {
    return 'AppointmentModel(id: $id, patientName: $patientName, doctorName: $doctorName, date: $date, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is AppointmentModel &&
      other.id == id &&
      other.patientId == patientId &&
      other.doctorId == doctorId &&
      other.date == date &&
      other.status == status;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      patientId.hashCode ^
      doctorId.hashCode ^
      date.hashCode ^
      status.hashCode;
  }
}