# 🔥 Reglas de Firestore Necesarias

El problema que estás experimentando (no se guardan usuarios, médicos ni citas) generalmente se debe a **reglas de seguridad de Firestore** que están bloqueando las escrituras.

## 📋 Reglas Recomendadas (Temporal para Desarrollo)

Para solucionar el problema rápidamente, usa estas reglas **SOLO PARA DESARROLLO**:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Permitir lectura/escritura a usuarios autenticados
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
    
    // O más permisivo para desarrollo (NO USAR EN PRODUCCIÓN):
    // match /{document=**} {
    //   allow read, write: if true;
    // }
  }
}
```

## 🔧 Cómo Configurar las Reglas

1. **Abre Firebase Console**: https://console.firebase.google.com/
2. **Selecciona tu proyecto**
3. Ve a **Firestore Database** > **Reglas**
4. **Copia y pega** las reglas de arriba
5. **Publica** las reglas

## ⚠️ IMPORTANTE

- Estas reglas son **SOLO PARA DESARROLLO**
- En producción, debes tener reglas más restrictivas
- Verifica que estás en el proyecto correcto de Firebase

## 🔍 Verificar Conexión

También verifica:
1. Que estás conectado al proyecto correcto de Firebase
2. Que las credenciales en `firebase_options.dart` son correctas
3. Que tienes permisos en el proyecto de Firebase

## 📝 Reglas Recomendadas para Producción (Más Seguras)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Usuarios: Solo pueden leer/escribir su propio documento
    match /usuarios/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Médicos: Lectura para todos, escritura solo para el mismo médico
    match /medicos/{medicoId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == medicoId;
    }
    
    // Citas: Los pacientes pueden leer/escribir sus citas, los médicos las suyas
    match /appointments/{appointmentId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && 
        (resource.data.patientId == request.auth.uid || 
         resource.data.doctorId == request.auth.uid);
    }
    
    // Citas legacy: Similar a appointments
    match /citas/{citaId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null;
    }
    
    // Hospitales: Solo lectura
    match /hospitales/{hospitalId} {
      allow read: if request.auth != null;
      allow write: if false; // Solo lectura
    }
  }
}
```

