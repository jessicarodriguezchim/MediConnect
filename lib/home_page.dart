import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pages/messages_page.dart';
import 'pages/settings_page.dart';
import 'pages/calendar_page.dart';
import 'routes.dart';
import 'bloc/dashboard_page.dart';
import 'services/firebase_service.dart';
import 'services/firebase_constants.dart';
import 'utils/app_colors.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _specialists = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _userRole;
  bool _loadingRole = true;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadSpecialists();
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) {
      setState(() {
        _userRole = UserRole.patient;
        _loadingRole = false;
      });
      return;
    }

    try {
      // Usar el servicio unificado para obtener el rol
      final userModel = await FirebaseService.getUser(user.uid);
      setState(() {
        _userRole = userModel?.role ?? UserRole.patient;
        _loadingRole = false;
      });
    } catch (e) {
      setState(() {
        _userRole = UserRole.patient;
        _loadingRole = false;
      });
    }
  }

  Future<void> _loadSpecialists() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Obtener médicos desde la colección medicos - SOLO los que tienen uid (doctores reales)
      // También obtener de usuarios con role='doctor'
      final medicosSnapshot = await _firestore
          .collection(FirebaseCollections.medicos)
          .get();
      
      // Filtrar solo documentos que tienen 'uid' (doctores reales), no especialidades
      final medicosReales = medicosSnapshot.docs.where((doc) {
        final data = doc.data();
        return data.containsKey('uid') && data['uid'] != null;
      }).toList();
      
      // También obtener doctores de la colección usuarios
      final usuariosSnapshot = await _firestore
          .collection(FirebaseCollections.usuarios)
          .where('role', isEqualTo: 'doctor')
          .get();
      
      setState(() {
        // Combinar médicos de ambas colecciones
        final allSpecialists = <Map<String, dynamic>>[];
        
        // Agregar médicos de la colección medicos
        for (var doc in medicosReales) {
          final data = doc.data();
          data['id'] = doc.id;
          allSpecialists.add(data);
        }
        
        // Agregar médicos de la colección usuarios (evitar duplicados)
        for (var doc in usuariosSnapshot.docs) {
          final data = doc.data();
          final uid = data['uid'] as String?;
          // Solo agregar si no existe ya en la lista
          if (uid != null && !allSpecialists.any((s) => s['uid'] == uid)) {
            data['id'] = doc.id;
            // Asegurar que tenga el campo especialidad (puede ser 'specialty' o 'especialidad')
            if (!data.containsKey('especialidad') && data.containsKey('specialty')) {
              data['especialidad'] = data['specialty'];
            }
            allSpecialists.add(data);
          }
        }
        
        _specialists = allSpecialists;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar especialistas: $e. Verifica tu conexión e intenta de nuevo.';
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildHomeContent() {
    final user = _auth.currentUser;
    final userName = user?.email?.split('@')[0] ?? 'Usuario';

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.backgroundGradient,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppStyles.cardRadius),
                boxShadow: AppColors.elevatedShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡Hola, $userName! 👋',
                    style: AppTextStyles.heading2.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '¿En qué podemos ayudarte hoy?',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.white.withOpacity(0.95),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // Mostrar widgets diferentes según el rol
            _loadingRole
                ? const Center(child: CircularProgressIndicator())
                : _userRole == 'doctor'
                    ? _buildDoctorOptions()
                    : _buildPatientOptions(),
            const SizedBox(height: 35),
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Nuestros Especialistas',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _specialistList(),
            const SizedBox(height: 20), // Reducido el padding inferior
          ],
        ),
      ),
    );
  }

  // Widgets para pacientes
  Widget _buildPatientOptions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _optionCard(
          icon: Icons.calendar_month_rounded,
          title: 'Agendar\nCita',
          gradient: AppColors.primaryGradient,
          onTap: () {
            if (_specialists.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Selecciona un especialista abajo')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No hay especialistas disponibles'),
                  backgroundColor: AppColors.softPurple,
                ),
              );
            }
          },
        ),
        _optionCard(
          icon: Icons.healing_rounded,
          title: 'Consejos\nMédicos',
          gradient: AppColors.purpleGradient,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Consejos de salud próximamente'),
                backgroundColor: AppColors.softPurple,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // Widgets para médicos
  Widget _buildDoctorOptions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _optionCard(
          icon: Icons.dashboard_rounded,
          title: 'Ver\nCitas',
          gradient: AppColors.primaryGradient,
          onTap: () {
            Navigator.pushNamed(
              context,
              Routes.dashboard,
            );
          },
        ),
        _optionCard(
          icon: Icons.analytics_rounded,
          title: 'Estadísticas',
          gradient: AppColors.bluePurpleGradient,
          onTap: () {
            Navigator.pushNamed(context, Routes.graphics);
          },
        ),
      ],
    );
  }

  Widget _optionCard({
    required IconData icon,
    required String title,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        height: 140,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppStyles.cardRadius),
          boxShadow: AppColors.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Función auxiliar para obtener el icono del especialista
  IconData _getSpecialistIcon(Map<String, dynamic> specialist) {
    // Intentar obtener icono desde Firebase
    try {
      final iconoString = specialist['icono']?.toString();
      if (iconoString != null && iconoString.isNotEmpty) {
        // Intentar parsear como hex string
        if (iconoString.startsWith('0x')) {
          final iconCode = int.tryParse(iconoString);
          if (iconCode != null) {
            return IconData(iconCode, fontFamily: 'MaterialIcons');
          }
        } else {
          // Si es solo un número, agregar 0x
          final iconCode = int.tryParse('0x$iconoString');
          if (iconCode != null) {
            return IconData(iconCode, fontFamily: 'MaterialIcons');
          }
        }
      }
    } catch (e) {
      debugPrint('Error parseando icono: $e');
    }
    
    // Si no hay icono válido, usar icono por defecto basado en especialidad
    final especialidad = (specialist['especialidad'] ?? specialist['specialty'] ?? '').toString().toLowerCase();
    
    // Mapear especialidades a iconos (usando iconos comunes de Material Icons)
    if (especialidad.contains('cardio')) {
      return Icons.favorite;
    } else if (especialidad.contains('pediatr') || especialidad.contains('pediatra')) {
      return Icons.child_care;
    } else if (especialidad.contains('ginecolog')) {
      return Icons.female;
    } else if (especialidad.contains('dermatolog')) {
      return Icons.medical_services;
    } else if (especialidad.contains('neurolog')) {
      return Icons.psychology;
    } else if (especialidad.contains('oftalmolog') || especialidad.contains('ojo')) {
      return Icons.remove_red_eye;
    } else if (especialidad.contains('traumatolog') || especialidad.contains('ortoped')) {
      return Icons.healing;
    } else if (especialidad.contains('psiquiatr')) {
      return Icons.psychology;
    } else if (especialidad.contains('general')) {
      return Icons.local_hospital;
    } else if (especialidad.contains('urgenc')) {
      return Icons.emergency;
    } else {
      return Icons.medical_services; // Icono por defecto siempre válido
    }
  }

  Widget _specialistList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando especialistas...', style: TextStyle(color: AppColors.mediumGrey)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          children: [
            Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: AppColors.error)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSpecialists,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_specialists.isEmpty) {
      return const Center(
        child: Text('No hay especialistas disponibles.', style: TextStyle(color: AppColors.mediumGrey)),
      );
    }

    return Column(
      children: _specialists.map((specialist) {
        final color = Color(int.parse(specialist['color'] ?? '0xFF2196F3'));
        final iconData = _getSpecialistIcon(specialist);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                iconData,
                color: color,
                size: 28,
              ),
            ),
            title: Text(
              specialist['nombre'] ?? specialist['displayName'] ?? 'Sin nombre',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                // Mostrar especialidad de forma más visible
                Row(
                  children: [
                    Icon(
                      Icons.medical_services,
                      size: 16,
                      color: AppColors.primaryBlue.withOpacity(0.7),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        specialist['especialidad'] ?? 
                        specialist['specialty'] ?? 
                        'Sin especialidad',
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.lightGrey,
              size: 18,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CalendarPage(medicoId: specialist['id']),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'MediConnect',
          style: AppTextStyles.heading2.copyWith(
            color: AppColors.primaryBlue,
          ),
        ),
        centerTitle: true,
      ),
      body: _selectedIndex == 0
        ? _buildHomeContent()
        : _selectedIndex == 1
            ? const MessagesPage()
            : const SettingsPage(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: AppColors.cardShadow,
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: AppColors.primaryBlue,
          unselectedItemColor: AppColors.mediumGrey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          backgroundColor: AppColors.white,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Inicio'),
            BottomNavigationBarItem(icon: Icon(Icons.message_rounded), label: 'Mensajes'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Configuración'),
          ],
        ),
      ),
    );
  }
}