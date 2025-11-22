import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'routes.dart';
import 'services/firebase_service.dart';

class LoginPage extends StatefulWidget{
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  // Controllers para formularios
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  
  // Controllers para registro
  final TextEditingController registerNameController = TextEditingController();
  final TextEditingController registerEmailController = TextEditingController();
  final TextEditingController registerPasswordController = TextEditingController();
  final TextEditingController registerConfirmPasswordController = TextEditingController();
  final TextEditingController registerPhoneController = TextEditingController();
  final TextEditingController registerSpecialtyController = TextEditingController();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late TabController _tabController;

  String _selectedRole = 'patient';
  String _registerRole = 'patient';
  bool _obscurePassword = true;
  bool _obscureRegisterPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose(){
    _tabController.dispose();
    emailController.dispose();
    passwordController.dispose();
    registerNameController.dispose();
    registerEmailController.dispose();
    registerPasswordController.dispose();
    registerConfirmPasswordController.dispose();
    registerPhoneController.dispose();
    registerSpecialtyController.dispose();
    super.dispose();
  }
  // Guardar datos del usuario en Firestore con rol - UNIFICADO en usuarios
  Future<void> saveUserData(User user) async {
    try {
      // Obtener el rol del usuario desde Firestore si ya existe
      final usuariosRef = FirebaseFirestore.instance.collection('usuarios').doc(user.uid);
      final userDoc = await usuariosRef.get();
      
      // Si el usuario ya existe, usar su rol existente, sino usar el seleccionado
      String userRole = _selectedRole;
      if (userDoc.exists && userDoc.data() != null) {
        userRole = userDoc.data()!['role'] ?? _selectedRole;
      }

      final userData = {
        'email': user.email,
        'uid': user.uid,
        'role': userRole,
        'displayName': user.displayName ?? user.email?.split('@')[0] ?? 'Usuario',
        'nombre': user.displayName ?? user.email?.split('@')[0] ?? 'Usuario',
        'lastLogin': FieldValue.serverTimestamp(),
      };

      // Solo agregar createdAt si el documento no existe
      if (!userDoc.exists) {
        userData['createdAt'] = FieldValue.serverTimestamp();
      }

      await usuariosRef.set(userData, SetOptions(merge: true));
      
      // Si es médico, también crear en la colección medicos para compatibilidad
      if (userRole == 'doctor') {
        final medicosRef = FirebaseFirestore.instance.collection('medicos').doc(user.uid);
        await medicosRef.set({
          'email': user.email,
          'uid': user.uid,
          'nombre': user.displayName ?? user.email?.split('@')[0] ?? 'Médico',
          'especialidad': 'General',
          'specialty': 'General',
        }, SetOptions(merge: true));
      }
      
      debugPrint('✅ Datos del usuario guardados correctamente');
    } catch (e, stackTrace) {
      debugPrint('❌ Error al guardar datos del usuario: $e');
      debugPrint('Stack trace: $stackTrace');
      // Re-lanzar la excepción para que el login pueda manejarla
      rethrow;
    }
  }
  
  // Manejar registro de nuevo usuario
  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Usar el servicio unificado para crear el usuario
      await FirebaseService.createUser(
        email: registerEmailController.text.trim(),
        password: registerPasswordController.text.trim(),
        name: registerNameController.text.trim(),
        phone: registerPhoneController.text.trim().isNotEmpty 
            ? registerPhoneController.text.trim() 
            : null,
        role: _registerRole,
        specialty: _registerRole == 'doctor' && registerSpecialtyController.text.trim().isNotEmpty
            ? registerSpecialtyController.text.trim()
            : null,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ ${_registerRole == 'doctor' ? 'Médico' : 'Paciente'} registrado exitosamente. Inicia sesión.',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Cambiar a la pestaña de login después del registro exitoso
      _tabController.animateTo(0);
      
      // Limpiar formulario de registro
      registerNameController.clear();
      registerEmailController.clear();
      registerPasswordController.clear();
      registerConfirmPasswordController.clear();
      registerPhoneController.clear();
      registerSpecialtyController.clear();
      _registerRole = 'patient';

    } on FirebaseAuthException catch (e) {
      String message = _getRegisterErrorMessage(e.code);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al registrar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  String _getRegisterErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return '❌ Este correo ya está registrado. Inicia sesión.';
      case 'weak-password':
        return '❌ La contraseña es muy débil. Usa al menos 6 caracteres.';
      case 'invalid-email':
        return '❌ Correo electrónico inválido.';
      case 'operation-not-allowed':
        return '❌ Operación no permitida.';
      default:
        return '❌ Error al registrar. Intenta nuevamente.';
    }
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Obtener el rol del usuario desde Firestore
      String? userRole;
      try {
        await saveUserData(userCredential.user!);
        // Obtener el rol después de guardar
        final userDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(userCredential.user!.uid)
            .get();
        userRole = userDoc.data()?['role'] as String?;
      } catch (e) {
        // Log del error pero no bloquear el login
        debugPrint('⚠️ Error al guardar datos del usuario (no crítico): $e');
        // Intentar obtener el rol de todas formas
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(userCredential.user!.uid)
              .get();
          userRole = userDoc.data()?['role'] as String?;
        } catch (e2) {
          debugPrint('⚠️ No se pudo obtener el rol del usuario: $e2');
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Bienvenido ${userCredential.user!.email}!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // MODIFICADO: Navegación basada en rol del usuario (desde Firestore, no del dropdown)
      final roleToUse = userRole ?? _selectedRole;
      debugPrint('🔐 Rol del usuario: $roleToUse');
      
      if (roleToUse == 'doctor') {
        Navigator.pushReplacementNamed(context, Routes.dashboard);
      } else {
        Navigator.pushReplacementNamed(context, Routes.home);
      }

    } on FirebaseAuthException catch (e) {
      String message = _getErrorMessage(e.code);
      debugPrint('❌ Error de autenticación: ${e.code} - ${e.message}');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error inesperado en login: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al iniciar sesión: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return '❌ Usuario no encontrado. Verifica tu correo electrónico.';
      case 'wrong-password':
        return '❌ Contraseña incorrecta. Verifica tu contraseña.';
      case 'invalid-credential':
        return '❌ Credenciales incorrectas. Verifica tu correo y contraseña.';
      case 'invalid-email':
        return '❌ Correo electrónico inválido.';
      case 'user-disabled':
        return '❌ Esta cuenta ha sido deshabilitada.';
      case 'too-many-requests':
        return '❌ Demasiados intentos. Intenta más tarde.';
      case 'network-request-failed':
        return '❌ Error de conexión. Verifica tu internet.';
      case 'operation-not-allowed':
        return '❌ Operación no permitida. Contacta al administrador.';
      case 'weak-password':
        return '❌ La contraseña es muy débil.';
      default:
        return '❌ Error al iniciar sesión: $code. Verifica tus credenciales.';
    }
  }


  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(icon, color: Colors.blue[700]),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Logo y título
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/login_2opcion.jpg',
                        width: 80,
                        height: 80,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'MediConnect',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1976D2),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            
            // Pestañas
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                  ),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey[600],
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'Iniciar Sesión'),
                  Tab(text: 'Registrarse'),
                ],
              ),
            ),
            
            // Contenido de las pestañas
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Pestaña de Login
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Form(
                      key: _loginFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Bienvenido de nuevo',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // Selector de rol
                          DropdownButtonFormField<String>(
                            value: _selectedRole,
                            decoration: InputDecoration(
                              labelText: 'Rol',
                              labelStyle: TextStyle(color: Colors.grey[600]),
                              prefixIcon: Icon(Icons.badge_outlined, color: Colors.blue[700]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'patient', child: Text('Paciente')),
                              DropdownMenuItem(value: 'doctor', child: Text('Médico')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedRole = v);
                            },
                          ),
                          const SizedBox(height: 24),
                          
                          // Campo de email
                          _buildTextField(
                            controller: emailController,
                            label: 'Correo Electrónico',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor ingrese su correo electrónico';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          
                          // Campo de contraseña
                          _buildTextField(
                            controller: passwordController,
                            label: 'Contraseña',
                            icon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.grey[600],
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor ingrese su contraseña';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),
                          
                          // Botón de iniciar sesión
                          Container(
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Iniciar Sesión',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  
                  // Pestaña de Registro
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Form(
                      key: _registerFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Crea tu cuenta',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // Campo de nombre
                          _buildTextField(
                            controller: registerNameController,
                            label: 'Nombre completo',
                            icon: Icons.person_outline,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Por favor ingresa tu nombre';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          
                          // Campo de email
                          _buildTextField(
                            controller: registerEmailController,
                            label: 'Correo electrónico',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Por favor ingresa tu correo';
                              }
                              if (!value.contains('@')) {
                                return 'Ingresa un correo válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          
                          // Campo de contraseña
                          _buildTextField(
                            controller: registerPasswordController,
                            label: 'Contraseña',
                            icon: Icons.lock_outline,
                            obscureText: _obscureRegisterPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureRegisterPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.grey[600],
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureRegisterPassword = !_obscureRegisterPassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor ingresa una contraseña';
                              }
                              if (value.length < 6) {
                                return 'La contraseña debe tener al menos 6 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          
                          // Campo de confirmar contraseña
                          _buildTextField(
                            controller: registerConfirmPasswordController,
                            label: 'Confirmar contraseña',
                            icon: Icons.lock_outline,
                            obscureText: _obscureConfirmPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.grey[600],
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor confirma tu contraseña';
                              }
                              if (value != registerPasswordController.text) {
                                return 'Las contraseñas no coinciden';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          
                          // Campo de teléfono (opcional)
                          _buildTextField(
                            controller: registerPhoneController,
                            label: 'Teléfono (opcional)',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 20),
                          
                          // Selector de rol
                          DropdownButtonFormField<String>(
                            value: _registerRole,
                            decoration: InputDecoration(
                              labelText: 'Tipo de Usuario',
                              labelStyle: TextStyle(color: Colors.grey[600]),
                              prefixIcon: Icon(Icons.badge_outlined, color: Colors.blue[700]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'patient', child: Text('Paciente')),
                              DropdownMenuItem(value: 'doctor', child: Text('Médico')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _registerRole = v);
                            },
                          ),
                          const SizedBox(height: 20),
                          
                          // Campo de especialidad (solo para médicos)
                          if (_registerRole == 'doctor')
                            _buildTextField(
                              controller: registerSpecialtyController,
                              label: 'Especialidad (opcional)',
                              icon: Icons.medical_services_outlined,
                              hint: 'Ej: Cardiología',
                            ),
                          if (_registerRole == 'doctor') const SizedBox(height: 20),
                          
                          // Botón de registro
                          Container(
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Registrarse como ${_registerRole == 'doctor' ? 'Médico' : 'Paciente'}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}