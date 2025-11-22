# Documentación: Implementación de Gráficas Interactivas

## Resumen
Este documento explica en detalle cómo se implementaron las gráficas interactivas y funcionales en la aplicación MediConnect, incluyendo la obtención de datos desde Firebase, el procesamiento de información, y las características de interactividad.

---

## 1. Arquitectura General

### 1.1 Dependencias Utilizadas
- **fl_chart (^0.68.0)**: Biblioteca principal para crear gráficas interactivas
- **cloud_firestore (^4.7.1)**: Para obtener datos de Firebase
- **intl (^0.19.0)**: Para formateo de fechas en español
- **flutter/material.dart**: Para la UI y animaciones

### 1.2 Estructura del Código
El archivo `lib/pages/graphics_page.dart` contiene toda la lógica de las gráficas:
- Estado de la página con `StatefulWidget`
- Manejo de animaciones con `TickerProviderStateMixin`
- Estados para interactividad (`_touchedIndex`, `_touchedPieIndex`, `_touchedBarIndex`)

---

## 2. Obtención de Datos desde Firebase

### 2.1 Proceso de Carga de Datos

```dart
Future<void> _loadChartData() async
```

Este método es el punto de entrada para obtener todos los datos necesarios:

#### Paso 1: Obtener citas de la colección 'appointments'
```dart
final appointmentsSnapshot = await _firestore
    .collection('appointments')
    .get();
```

#### Paso 2: Obtener citas de la colección 'citas' (legacy)
```dart
final citasSnapshot = await _firestore
    .collection('citas')
    .get();
```

**Nota importante**: La aplicación maneja dos colecciones diferentes:
- `appointments`: Colección principal con formato estándar
- `citas`: Colección legacy que requiere conversión de formato

#### Paso 3: Conversión y Unificación
- Las citas de `citas` se convierten al formato `AppointmentModel`
- Se combinan ambas colecciones evitando duplicados
- Se procesan los datos para cada tipo de gráfica

### 2.2 Modelo de Datos

Los datos se almacenan en estructuras específicas:

```dart
// Datos mensuales
List<MonthlyAppointmentData> _monthlyAppointments = [];

// Contadores de estado
int _completedCount = 0;
int _cancelledCount = 0;

// Datos de doctores y pacientes
List<DoctorPatientData> _doctorPatients = [];
```

---

## 3. Procesamiento de Datos

### 3.1 Gráfica de Líneas: Citas por Mes

**Método**: `_processMonthlyData(List<AppointmentModel> appointments)`

**Proceso**:
1. Agrupa las citas por mes usando `DateFormat('yyyy-MM')`
2. Cuenta el número de citas por mes
3. Formatea los meses en español (ej: "Ene 2024")
4. Ordena cronológicamente

**Código clave**:
```dart
final monthKey = DateFormat('yyyy-MM').format(appointment.createdAt);
monthlyMap[monthKey] = (monthlyMap[monthKey] ?? 0) + 1;
```

### 3.2 Gráfica de Pastel: Completadas vs Canceladas

**Método**: `_processStatusData(List<AppointmentModel> appointments)`

**Proceso**:
1. Filtra citas con estado 'completed'
2. Filtra citas con estado 'cancelled'
3. Calcula totales para mostrar porcentajes

**Código clave**:
```dart
_completedCount = appointments.where((a) => a.status == 'completed').length;
_cancelledCount = appointments.where((a) => a.status == 'cancelled').length;
```

### 3.3 Gráfica de Barras: Pacientes por Médico

**Método**: `_processDoctorPatientData(List<AppointmentModel> appointments)`

**Proceso**:
1. Filtra solo citas completadas
2. Agrupa por `doctorId`
3. Cuenta pacientes únicos por doctor (usando `Set<String>`)
4. Obtiene nombres de doctores desde Firebase
5. Ordena por cantidad de pacientes (descendente)
6. Toma los top 10

**Código clave**:
```dart
if (!doctorPatientsMap.containsKey(appointment.doctorId)) {
  doctorPatientsMap[appointment.doctorId] = <String>{};
}
doctorPatientsMap[appointment.doctorId]!.add(appointment.patientId);
```

---

## 4. Gráficas Interactivas

### 4.1 Gráfica de Líneas Interactiva

#### Características de Interactividad:

1. **Tooltips al tocar**:
   - Muestra mes y cantidad de citas
   - Tooltip con fondo teal y texto blanco
   - Posicionamiento automático

2. **Indicador visual del punto tocado**:
   - Línea vertical punteada en el punto seleccionado
   - Punto más grande y destacado
   - Cambio de color del punto

3. **Panel de información**:
   - Muestra detalles del mes seleccionado
   - Se actualiza dinámicamente al tocar diferentes puntos

**Implementación**:
```dart
lineTouchData: LineTouchData(
  enabled: true,
  touchTooltipData: LineTouchTooltipData(
    getTooltipColor: (touchedSpot) => Colors.teal[700]!,
    getTooltipItems: (List<LineBarSpot> touchedSpots) {
      // Genera tooltips personalizados
    },
  ),
  touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
    // Actualiza _touchedIndex para mostrar información
  },
)
```

#### Configuración Visual:
- **Línea curva** (`isCurved: true`) para mejor estética
- **Área sombreada** debajo de la línea (`belowBarData`)
- **Puntos redondos** con borde blanco
- **Grid horizontal** para facilitar lectura

### 4.2 Gráfica de Pastel Interactiva

#### Características de Interactividad:

1. **Expansión al tocar**:
   - El segmento tocado aumenta de tamaño (radius: 80 → 90)
   - Cambio de color más intenso
   - Muestra cantidad absoluta además del porcentaje

2. **Feedback visual inmediato**:
   - Cambio de color al tocar
   - Animación suave de expansión

**Implementación**:
```dart
PieChartSectionData(
  value: _completedCount.toDouble(),
  title: _touchedPieIndex == 0 
      ? '${_completedCount}\n(${((_completedCount / total) * 100).toStringAsFixed(1)}%)'
      : '${((_completedCount / total) * 100).toStringAsFixed(1)}%',
  color: _touchedPieIndex == 0 ? Colors.green[700] : Colors.green,
  radius: _touchedPieIndex == 0 ? 90 : 80,
)
```

#### Configuración Visual:
- **Espacio entre secciones** (sectionsSpace: 2)
- **Centro vacío** (centerSpaceRadius: 60) para diseño moderno
- **Colores semánticos**: Verde para completadas, Rojo para canceladas
- **Leyenda interactiva** con contadores

### 4.3 Gráfica de Barras Interactiva

#### Características de Interactividad:

1. **Tooltips detallados**:
   - Muestra nombre del doctor
   - Muestra cantidad de pacientes
   - Tooltip con fondo teal

2. **Resaltado de barra tocada**:
   - Barra se hace más ancha (20 → 24)
   - Cambio de color más intenso
   - Feedback visual inmediato

**Implementación**:
```dart
barTouchData: BarTouchData(
  enabled: true,
  touchTooltipData: BarTouchTooltipData(
    getTooltipItem: (group, groupIndex, rod, rodIndex) {
      // Tooltip personalizado con nombre y cantidad
    },
  ),
  touchCallback: (FlTouchEvent event, barTouchResponse) {
    // Actualiza _touchedBarIndex
  },
)
```

#### Configuración Visual:
- **Barras redondeadas** en la parte superior
- **Fondo gris claro** para todas las barras
- **Nombres rotados** 90° para mejor legibilidad
- **Grid horizontal** para facilitar lectura

---

## 5. Animaciones

### 5.1 Sistema de Animaciones

Se utiliza `AnimationController` con `TickerProviderStateMixin`:

```dart
_animationController = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 1500),
);
_animation = CurvedAnimation(
  parent: _animationController,
  curve: Curves.easeInOut,
);
```

### 5.2 Aplicación de Animaciones

Todas las gráficas están envueltas en `FadeTransition`:

```dart
FadeTransition(
  opacity: _animation,
  child: LineChart(...),
)
```

**Efecto**: Las gráficas aparecen con una animación de fade-in suave al cargar los datos.

---

## 6. Diseño Visual

### 6.1 Paleta de Colores

- **Color principal**: Teal (Colors.teal)
- **Completadas**: Verde (Colors.green)
- **Canceladas**: Rojo (Colors.red)
- **Fondos**: Grises suaves para contraste

### 6.2 Componentes de Diseño

#### Cards
- **Elevación**: 4 (sombra sutil)
- **Bordes redondeados**: 16px
- **Padding**: 20px interno

#### Tipografía
- **Títulos**: 18px, bold
- **Subtítulos**: 14px, gris
- **Tooltips**: 14px, bold, blanco

#### Espaciado
- **Entre gráficas**: 24px
- **Elementos internos**: 8-16px según jerarquía

### 6.3 Estados Vacíos

Cuando no hay datos, se muestra un card especial:
- Icono grande
- Título descriptivo
- Mensaje informativo

---

## 7. Manejo de Errores

### 7.1 Estados de Carga

1. **Loading**: Muestra `CircularProgressIndicator`
2. **Error**: Muestra mensaje de error con botón de reintento
3. **Éxito**: Muestra gráficas con datos

### 7.2 Manejo de Excepciones

```dart
try {
  // Carga de datos
} catch (e) {
  setState(() {
    _errorMessage = 'Error al cargar datos: $e';
    _isLoading = false;
  });
}
```

### 7.3 Validación de Datos

- Verifica que existan datos antes de renderizar
- Maneja casos donde las colecciones están vacías
- Convierte formatos legacy de manera segura

---

## 8. Optimizaciones

### 8.1 Rendimiento

1. **Carga única**: Los datos se cargan una vez al iniciar
2. **Procesamiento eficiente**: Uso de `Map` y `Set` para agrupaciones
3. **Límite de datos**: Top 10 doctores para evitar sobrecarga

### 8.2 Actualización de Datos

- Botón de refresh en el AppBar
- Pull-to-refresh en el contenido
- Re-carga completa de datos al actualizar

---

## 9. Flujo de Usuario

1. **Usuario abre la página de gráficas**
   - Se muestra indicador de carga
   - Se inicializan animaciones

2. **Carga de datos desde Firebase**
   - Obtiene citas de ambas colecciones
   - Procesa y agrupa datos

3. **Renderizado de gráficas**
   - Animación de fade-in
   - Gráficas interactivas listas

4. **Interacción del usuario**
   - Toca un punto/barra/segmento
   - Ve tooltip con información
   - Observa cambios visuales

5. **Actualización**
   - Usuario puede refrescar datos
   - Se recargan desde Firebase

---

## 10. Ejemplos de Uso

### 10.1 Ver tendencia mensual
1. Usuario toca un punto en la gráfica de líneas
2. Ve tooltip con mes y cantidad
3. Panel inferior muestra detalles

### 10.2 Comparar estados
1. Usuario toca segmento de pastel
2. Segmento se expande
3. Ve cantidad absoluta y porcentaje

### 10.3 Ver ranking de doctores
1. Usuario toca una barra
2. Ve tooltip con nombre y cantidad
3. Barra se resalta visualmente

---

## 11. Consideraciones Técnicas

### 11.1 Firebase

- **Colecciones consultadas**: `appointments`, `citas`, `usuarios`
- **Operaciones**: `get()` para carga inicial
- **Filtros**: Por estado, por doctor, por fecha

### 11.2 Formato de Fechas

- **Interno**: `DateTime`
- **Firebase**: `Timestamp`
- **Visualización**: Formato español con `intl`

### 11.3 Memoria

- Los datos se mantienen en memoria durante la sesión
- Se liberan al cerrar la página
- No hay caché persistente

---

## 12. Mejoras Futuras

Posibles mejoras que se podrían implementar:

1. **Filtros de fecha**: Permitir seleccionar rango de fechas
2. **Exportación**: Exportar gráficas como imagen
3. **Más gráficas**: Agregar más tipos de visualizaciones
4. **Tiempo real**: Usar streams de Firebase para actualización automática
5. **Caché**: Implementar caché local para mejor rendimiento

---

## Conclusión

La implementación de las gráficas interactivas en MediConnect proporciona:

✅ **Datos en tiempo real desde Firebase**
✅ **Interactividad completa** (tooltips, selección, feedback visual)
✅ **Diseño profesional y coherente**
✅ **Animaciones suaves**
✅ **Manejo robusto de errores**
✅ **Optimización de rendimiento**

Las gráficas son completamente funcionales y proporcionan una experiencia de usuario rica y profesional para visualizar estadísticas de citas médicas.

