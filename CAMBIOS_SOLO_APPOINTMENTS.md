# ✅ Cambios Realizados: Usar Solo Colección `appointments`

## 🎯 Objetivo

Simplificar el código para usar **solo la colección `appointments`** en lugar de duplicar datos en `citas` y `appointments`.

## 📋 Cambios Implementados

### 1. ✅ Eliminado guardado en `citas`
- **Antes:** Al crear una cita, se guardaba en `appointments` Y en `citas`
- **Ahora:** Solo se guarda en `appointments`
- **Ubicación:** `lib/pages/calendar_page.dart` - Método `_agendarCita()`

### 2. ✅ Actualizado lectura de citas
- **Antes:** Leía de la colección `citas` con campos en español
- **Ahora:** Lee de `appointments` con campos en inglés
- **Cambio:** 
  ```dart
  // Antes
  .collection('citas')
  .where('pacienteId', isEqualTo: _userId)
  
  // Ahora
  .collection('appointments')
  .where('patientId', isEqualTo: _userId)
  ```

### 3. ✅ Actualizado visualización de citas
- **Antes:** Usaba campos como `horaInicio`, `motivo`, `estado`
- **Ahora:** Usa campos como `date`, `time`, `notes`, `status`
- **Conversión automática:** El código convierte los estados de inglés a español para mostrar

### 4. ✅ Actualizado cancelación de citas
- **Antes:** Eliminaba el documento de `citas`
- **Ahora:** Actualiza el estado en `appointments` a `cancelled`
- **Mejor práctica:** No eliminar, solo cambiar estado

### 5. ✅ Actualizado edición de citas
- **Antes:** Actualizaba solo en `citas`
- **Ahora:** Actualiza solo en `appointments`
- **Campos:** Usa `date`, `time`, `notes` en lugar de `fechaCita`, `horaInicio`, `motivo`

## 🔄 Estructura de Datos

### Colección `appointments` (Única que se usa ahora)

```json
{
  "id": "abc123",
  "doctorId": "uid_del_medico",
  "patientId": "uid_del_paciente",
  "doctorDocId": "docId_del_medico",
  "patientDocId": "uid_del_paciente",
  "doctorName": "Dr. Juan Pérez",
  "patientName": "María García",
  "specialty": "Cardiología",
  "date": "2024-01-15T10:00:00",
  "time": "10:00",
  "status": "pending",
  "notes": "Consulta general",
  "createdAt": "2024-01-10T...",
  "updatedAt": "2024-01-15T..."
}
```

## 📊 Estado Actual

### ✅ Colecciones Activas
- **`appointments`** - Única colección para citas (CREAR, LEER, ACTUALIZAR)
- **`usuarios`** - Usuarios registrados
- **`medicos`** - Médicos (para compatibilidad)
- **`hospitales`** - Hospitales disponibles

### ⚠️ Colección Legacy (Ya no se usa)
- **`citas`** - Ya NO se crean nuevas citas aquí
- ⚠️ Las citas existentes en `citas` seguirán existiendo pero no se crearán nuevas
- 💡 Opcional: Puedes eliminar esta colección después de migrar las citas existentes

## 🎯 Beneficios

1. ✅ **Sin duplicación** - Cada cita solo existe una vez
2. ✅ **Menos almacenamiento** - Ahorro de espacio en Firebase
3. ✅ **Código más simple** - Un solo lugar para leer/escribir
4. ✅ **Más mantenible** - Fácil de actualizar y depurar
5. ✅ **Formato estándar** - Usa nombres en inglés, más universal

## 📝 Próximos Pasos (Opcional)

### Migrar citas existentes de `citas` a `appointments`

Si tienes citas antiguas en `citas` y quieres migrarlas:

1. Usa el script de migración existente (si existe)
2. O crea un script manual para copiar las citas
3. Después de migrar, puedes eliminar la colección `citas`

### Limpiar código

- [ ] Eliminar métodos que solo trabajan con `citas`
- [ ] Actualizar comentarios que mencionen `citas`
- [ ] Simplificar código de conversión

## ✅ Verificación

Para verificar que todo funciona:

1. ✅ Crear una nueva cita
2. ✅ Verificar que aparece en Firebase → `appointments`
3. ✅ Verificar que NO aparece en Firebase → `citas` (nuevas)
4. ✅ Editar una cita existente
5. ✅ Cancelar una cita
6. ✅ Ver las citas en la lista

---

**Estado:** ✅ **Implementado** - El código ahora usa solo `appointments`

