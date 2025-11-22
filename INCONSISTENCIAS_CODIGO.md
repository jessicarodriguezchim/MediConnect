# Análisis de Inconsistencias en el Código

## 🔴 INCONSISTENCIAS CRÍTICAS

### 1. **Múltiples Colecciones para el Mismo Concepto**

#### Problema:
El código usa **3 colecciones diferentes** para almacenar citas:
- `appointments` (formato nuevo)
- `citas` (formato legacy)
- A veces se busca en ambas simultáneamente

#### Ubicaciones:
```dart
// dashboard_bloc.dart - líneas 17, 26, 32, 38, 47
.collection('appointments')
.collection('citas')

// graphics_page.dart - líneas 97, 107
.collection('appointments')
.collection('citas')

// appointments_page.dart - líneas 95, 100, 105
.collection('appointments')
.collection('citas')
```

#### Impacto:
- **Duplicación de datos**
- **Lógica compleja** para combinar ambas colecciones
- **Riesgo de inconsistencias** entre colecciones
- **Rendimiento degradado** (múltiples queries)

---

### 2. **Múltiples Colecciones para Usuarios**

#### Problema:
Los usuarios se almacenan en **2 colecciones diferentes**:
- `usuarios` (principal)
- `medicos` (específica para médicos)

#### Ubicaciones:
```dart
// dashboard_bloc.dart - líneas 54, 125, 146, 168, 213, 289, 442, 595, 601, 611, 622, 631, 645, 662, 684, 696, 716, 732, 746, 776
.collection('usuarios')
.collection('medicos')

// profile_page.dart - líneas 47, 99, 106
.collection('usuarios')
.collection('medicos')

// home_page.dart - líneas 48, 69
.collection('usuarios')
.collection('medicos')
```

#### Impacto:
- **Datos duplicados** entre colecciones
- **Lógica compleja** para buscar en ambas
- **Riesgo de desincronización**

---

### 3. **Inconsistencia en Nombres de Campos**

#### Problema:
El mismo concepto tiene **diferentes nombres** en diferentes colecciones:

**Para citas:**
- `appointments`: `doctorId`, `patientId`, `date`, `time`, `status`
- `citas`: `medicoId`, `medicoDocId`, `pacienteId`, `fechaCita`, `horaInicio`, `estado`

**Para usuarios:**
- `usuarios`: `displayName`, `nombre`, `telefono`, `phone`
- `medicos`: `nombre`, `email`, `uid`

#### Ejemplos:
```dart
// appointments_page.dart - línea 144
final citaMedicoId = data['medicoId'] ?? '';  // En 'citas'
final doctorId = data['doctorId'] ?? '';      // En 'appointments'

// profile_page.dart - líneas 55, 57
data['displayName'] ?? data['nombre']         // Dos nombres para lo mismo
data['telefono'] ?? data['phone']             // Dos nombres para lo mismo
```

---

### 4. **Inconsistencia en Manejo de Errores**

#### Problema:
Diferentes formas de manejar errores en Firebase:

**Patrón 1: Try-catch con setState**
```dart
// profile_page.dart - líneas 67-70
try {
  // código
} catch (e) {
  setState(() {
    _isLoading = false;
  });
}
```

**Patrón 2: Try-catch con emit**
```dart
// dashboard_bloc.dart - líneas 585-587
try {
  // código
} catch (e) {
  emit(DashboardError('Error: $e'));
}
```

**Patrón 3: Sin manejo de errores**
```dart
// Algunos lugares no tienen try-catch
```

---

### 5. **Inconsistencia en Instancias de Firebase**

#### Problema:
Diferentes formas de obtener instancias:

**Patrón 1: Variable de instancia**
```dart
// dashboard_bloc.dart - líneas 11-12
final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseFirestore _firestore = FirebaseFirestore.instance;
```

**Patrón 2: Acceso directo**
```dart
// profile_page.dart - línea 46
FirebaseFirestore.instance.collection('usuarios')

// main.dart - línea 94
FirebaseFirestore.instance.collection('usuarios')
```

**Patrón 3: Variable local**
```dart
// home_page.dart - líneas 19-20
final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseFirestore _firestore = FirebaseFirestore.instance;
```

---

### 6. **Inconsistencia en Conversión de Estados**

#### Problema:
El estado de las citas se maneja de forma diferente:

**En `appointments`:**
- `'pending'`, `'confirmed'`, `'completed'`, `'cancelled'`

**En `citas`:**
- `'Pendiente'`, `'Confirmada'`, `'Completada'`, `'Cancelada'` (en español)
- Requiere conversión con `_convertStatus()`

#### Ubicaciones:
```dart
// dashboard_bloc.dart - línea 249
status: _convertStatus(data['estado'] ?? 'Pendiente'),

// graphics_page.dart - línea 104
status: _convertStatus(data['estado'] ?? 'Pendiente'),
```

---

### 7. **Inconsistencia en Búsqueda de Médicos**

#### Problema:
Múltiples formas de buscar médicos:

**Método 1: Por email**
```dart
// dashboard_bloc.dart - líneas 594-598
.where('email', isEqualTo: user.email)
```

**Método 2: Por UID (documento ID)**
```dart
// dashboard_bloc.dart - línea 601
.collection('medicos').doc(user.uid).get()
```

**Método 3: Por campo uid**
```dart
// dashboard_bloc.dart - líneas 627-630
.where('uid', isEqualTo: user.uid)
```

**Método 4: Buscar en todos los documentos**
```dart
// dashboard_bloc.dart - líneas 651-659
final allMedicos = await _firestore.collection('medicos').limit(50).get();
for (var doc in allMedicos.docs) {
  if (data['uid'] == user.uid || data['email'] == user.email) {
    // ...
  }
}
```

---

### 8. **Inconsistencia en Formato de Fechas**

#### Problema:
Las fechas se almacenan de forma diferente:

**En `appointments`:**
```dart
'date': Timestamp.fromDate(date)
```

**En `citas`:**
```dart
'fechaCita': Timestamp.fromDate(date)
// O a veces como String
```

**Conversión inconsistente:**
```dart
// graphics_page.dart - línea 100
date: (data['fechaCita'] as Timestamp?)?.toDate() ?? DateTime.now()
```

---

### 9. **Inconsistencia en Manejo de Streams**

#### Problema:
Algunos lugares usan `.snapshots()` (tiempo real), otros `.get()` (una vez):

**Streams (tiempo real):**
```dart
// dashboard_bloc.dart - línea 22
final appointmentsStream = appointmentsQuery.snapshots();
```

**Get (una vez):**
```dart
// profile_page.dart - línea 46
final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
```

**Mezcla de ambos:**
```dart
// appointments_page.dart - líneas 108, 111, 114
StreamBuilder con .snapshots() y .get()
```

---

### 10. **Código Duplicado para Conversión de Citas**

#### Problema:
La misma lógica de conversión de `citas` a `AppointmentModel` está **duplicada** en múltiples archivos:

**Ubicaciones:**
- `dashboard_bloc.dart` - líneas 214-254
- `graphics_page.dart` - líneas 90-113
- `appointments_page.dart` - líneas 142-180

**Código similar repetido:**
```dart
AppointmentModel(
  id: doc.id,
  patientId: data['pacienteId'] ?? '',
  patientName: data['pacienteNombre'] ?? 'Paciente',
  doctorId: data['medicoId'] ?? doctorId,
  // ... más campos
)
```

---

## 🟡 INCONSISTENCIAS MENORES

### 11. **Inconsistencia en Nombres de Variables**

- `doctorId` vs `medicoId` vs `medicoDocId`
- `patientId` vs `pacienteId`
- `user` vs `usuario`

### 12. **Inconsistencia en Validación de Datos**

Algunos lugares validan si el documento existe, otros no:
```dart
// Con validación
if (doc.exists) { ... }

// Sin validación
final data = doc.data()!;  // Puede fallar si no existe
```

### 13. **Inconsistencia en Manejo de Null Safety**

```dart
// Patrón 1: Null-aware operators
data['campo'] ?? 'default'

// Patrón 2: Force unwrap
data['campo']!

// Patrón 3: Verificación explícita
if (data['campo'] != null) { ... }
```

---

## 📋 RECOMENDACIONES

### Prioridad ALTA:

1. **Unificar colecciones de citas**
   - Migrar todo a `appointments`
   - Eliminar `citas` gradualmente
   - Crear script de migración

2. **Unificar colecciones de usuarios**
   - Usar solo `usuarios` con campo `role`
   - Eliminar `medicos` o usarla solo como vista/cache

3. **Estandarizar nombres de campos**
   - Definir un esquema único
   - Crear constantes para nombres de campos
   - Usar un modelo de datos consistente

### Prioridad MEDIA:

4. **Centralizar lógica de Firebase**
   - Crear un servicio/repositorio para Firebase
   - Unificar instancias de Firebase
   - Estandarizar manejo de errores

5. **Eliminar código duplicado**
   - Extraer conversión de citas a función helper
   - Crear utilidades compartidas

6. **Estandarizar manejo de estados**
   - Usar enum para estados
   - Crear conversor centralizado

### Prioridad BAJA:

7. **Mejorar documentación**
   - Documentar estructura de datos
   - Comentar decisiones de diseño
   - Crear guía de estilo

---

## 🔧 SOLUCIONES PROPUESTAS

### 1. Crear Servicio de Firebase Unificado

```dart
class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Métodos unificados para citas
  static Stream<List<AppointmentModel>> getAppointments(String doctorId) { ... }
  
  // Métodos unificados para usuarios
  static Future<UserModel?> getUser(String uid) { ... }
}
```

### 2. Crear Constantes para Nombres de Colecciones

```dart
class FirebaseCollections {
  static const String appointments = 'appointments';
  static const String usuarios = 'usuarios';
  // Eliminar 'citas' y 'medicos' gradualmente
}
```

### 3. Crear Helper para Conversión de Citas

```dart
class AppointmentConverter {
  static AppointmentModel fromCitasDocument(DocumentSnapshot doc, String doctorId) {
    // Lógica centralizada
  }
}
```

---

## 📊 RESUMEN

- **Inconsistencias críticas**: 10
- **Inconsistencias menores**: 3
- **Archivos afectados**: 11+
- **Líneas de código duplicado**: ~200+

**Impacto estimado:**
- ⚠️ Mantenibilidad: **ALTA** (código difícil de mantener)
- ⚠️ Rendimiento: **MEDIA** (múltiples queries innecesarias)
- ⚠️ Bugs potenciales: **ALTA** (riesgo de inconsistencias)
- ⚠️ Escalabilidad: **ALTA** (difícil agregar nuevas features)

