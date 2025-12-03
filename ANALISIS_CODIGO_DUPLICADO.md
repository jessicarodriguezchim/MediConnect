# Análisis de Código Duplicado

## 📋 Resumen

Sí, hay código duplicado en el proyecto. Este documento identifica las duplicaciones encontradas.

---

## 🔴 Duplicaciones Encontradas

### 1. **Archivo de Ejemplo No Usado**

**Archivo:** `lib/pages/citas_crud_page_example.dart`

**Problema:**
- ❌ Este archivo NO está siendo usado en ninguna parte de la aplicación
- ❌ NO está registrado en las rutas (`routes.dart`)
- ❌ NO está siendo importado en ningún otro archivo
- ❌ Es solo un archivo de ejemplo/educativo que creamos

**Recomendación:**
- ✅ **ELIMINAR** este archivo o moverlo a una carpeta `examples/` si quieres mantenerlo como referencia

**Evidencia:**
```bash
# No se encontraron imports de este archivo
grep -r "CitasCrudPageExample\|citas_crud_page_example" lib/
# Solo aparece en el archivo mismo
```

---

### 2. **Funcionalidad Duplicada: "Mis Citas Agendadas"**

**Archivos involucrados:**
1. `lib/pages/misCitasPage.dart` - Clase `CitasPage` con método `_misCitasStream()`
2. `lib/pages/calendar_page.dart` - Método `_streamMisCitas()`

**Problema:**
- Ambos archivos muestran "Mis Citas Agendadas"
- Ambos tienen métodos similares para obtener el stream de citas
- `CitasPage` (misCitasPage.dart) NO está siendo usado en ninguna parte

**Evidencia:**

#### En `misCitasPage.dart`:
```dart
Stream<List<AppointmentModel>> _misCitasStream() {
  return _firestore
      .collection(FirebaseCollections.appointments)
      .where('patientDocId', isEqualTo: _userId)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => AppointmentModel.fromFirestore(doc))
        .toList();
  });
}
```

#### En `calendar_page.dart`:
```dart
Stream<QuerySnapshot> _streamMisCitas() {
  // Lógica similar para obtener citas del paciente
}
```

**Recomendación:**
- ✅ Si `CitasPage` (misCitasPage.dart) NO se usa, considera eliminarlo
- ✅ O consolidar la funcionalidad en un solo lugar
- ✅ Usar un servicio compartido para obtener las citas

---

### 3. **Páginas con Propósitos Similares**

**Archivos:**
- `lib/pages/appointments_page.dart` - Para médicos (ver citas)
- `lib/pages/calendar_page.dart` - Para pacientes (agendar y ver citas)
- `lib/pages/misCitasPage.dart` - Para pacientes (ver y editar citas)

**Análisis:**
- `appointments_page.dart` - ✅ Usado (ruta `/appointments`)
- `calendar_page.dart` - ✅ Usado (navegación desde HomePage)
- `misCitasPage.dart` - ❓ **NO se encontró dónde se usa**

**Pregunta crítica:**
¿`CitasPage` (misCitasPage.dart) se está usando realmente? Si no, es código muerto.

---

## ✅ Archivos en Uso vs No Usados

### ✅ **Archivos en Uso (NO eliminar)**
- `lib/pages/appointments_page.dart` - ✅ Usado en rutas
- `lib/pages/calendar_page.dart` - ✅ Usado en HomePage
- `lib/pages/home_page.dart` - ✅ Página principal
- `lib/pages/profile_page.dart` - ✅ Usado en rutas
- `lib/pages/graphics_page.dart` - ✅ Usado en rutas
- `lib/pages/settings_page.dart` - ✅ Usado en HomePage

### ❓ **Archivos con Dudas**
- `lib/pages/misCitasPage.dart` - ⚠️ **NO se encontró dónde se usa**
  - Contiene `CitasPage` widget
  - Tiene funcionalidad similar a `calendar_page.dart`
  - Tiene la funcionalidad de edición que agregamos

### ❌ **Archivos No Usados (Candidatos a eliminar)**
- `lib/pages/citas_crud_page_example.dart` - ❌ **NO se usa en ninguna parte**
  - Es solo un ejemplo educativo
  - NO está en rutas
  - NO está siendo importado

---

## 🎯 Recomendaciones

### Opción 1: Limpieza Completa (Recomendado)

1. **Eliminar archivo de ejemplo:**
   ```bash
   rm lib/pages/citas_crud_page_example.dart
   ```

2. **Decidir sobre `misCitasPage.dart`:**
   - Si NO se usa, eliminarlo y consolidar en `calendar_page.dart`
   - Si se usa pero no encontramos dónde, agregarlo a las rutas

### Opción 2: Consolidar Funcionalidad

1. **Mover funcionalidad de edición** de `misCitasPage.dart` a `calendar_page.dart`
2. **Eliminar** `misCitasPage.dart` si no se usa
3. **Eliminar** `citas_crud_page_example.dart`

### Opción 3: Organizar Mejor

1. Crear carpeta `lib/pages/examples/` y mover `citas_crud_page_example.dart` allí
2. Documentar qué hace cada página
3. Agregar `misCitasPage.dart` a las rutas si se necesita

---

## 🔍 Verificación Necesaria

**Preguntas para el usuario:**

1. ¿`CitasPage` (misCitasPage.dart) se está usando en algún lugar de la app?
   - Si SÍ: ¿Dónde? Necesitamos encontrarlo y documentarlo
   - Si NO: Podemos eliminarlo o consolidar su funcionalidad

2. ¿Quieres mantener `citas_crud_page_example.dart` como referencia?
   - Si SÍ: Moverlo a carpeta `examples/`
   - Si NO: Eliminarlo

3. ¿Prefieres consolidar la funcionalidad de "Mis Citas" en un solo lugar?

---

## 📊 Estadísticas

- **Archivos analizados:** 13 páginas
- **Archivos no usados encontrados:** 1 (`citas_crud_page_example.dart`)
- **Archivos con uso desconocido:** 1 (`misCitasPage.dart`)
- **Duplicaciones de funcionalidad:** 1 (mostrar citas agendadas)

---

## 🛠️ Comandos para Verificar

```bash
# Buscar dónde se usa CitasPage
grep -r "CitasPage\|misCitasPage" lib/ --exclude-dir=build

# Buscar dónde se usa citas_crud_page_example
grep -r "CitasCrudPageExample\|citas_crud_page_example" lib/

# Ver todas las rutas registradas
grep -A 5 "case.*:" lib/routes.dart
```

---

## ✨ Conclusión

**Sí, hay código duplicado.** Principalmente:
1. Un archivo de ejemplo no usado
2. Posible archivo muerto (`misCitasPage.dart`)
3. Funcionalidad duplicada para mostrar citas agendadas

**Siguiente paso:** Confirmar con el usuario qué archivos realmente necesita y proceder con la limpieza.

