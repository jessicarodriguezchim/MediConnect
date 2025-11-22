// models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? nombre;
  final String role;
  final DateTime? lastLogin;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.nombre,
    required this.role,
    this.lastLogin,
    this.createdAt,
  });

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'nombre': nombre,
      'role': role,
      'lastLogin': lastLogin,
      'createdAt': createdAt,
    };
  }

  // Crear desde Map de Firestore
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'],
      nombre: map['nombre'],
      role: map['role'] ?? 'patient',
      lastLogin: map['lastLogin'] != null 
          ? (map['lastLogin'] as Timestamp).toDate()
          : null,
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Crear desde DocumentSnapshot de Firestore
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap({...data, 'uid': doc.id});
  }

  // Copiar con cambios
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? nombre,
    String? role,
    DateTime? lastLogin,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      nombre: nombre ?? this.nombre,
      role: role ?? this.role,
      lastLogin: lastLogin ?? this.lastLogin,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, displayName: $displayName, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is UserModel &&
      other.uid == uid &&
      other.email == email &&
      other.displayName == displayName &&
      other.nombre == nombre &&
      other.role == role;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
      email.hashCode ^
      displayName.hashCode ^
      nombre.hashCode ^
      role.hashCode;
  }
}