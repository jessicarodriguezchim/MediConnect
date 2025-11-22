import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../services/firebase_constants.dart';
import 'fix_appointments_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  Map<String, dynamic>? _userData;
  String _selectedRole = 'patient'; // Rol actual del usuario (doctor o patient)
  
  // Controllers para el formulario de registro de nuevos usuarios
  final _newUserFormKey = GlobalKey<FormState>();
  final TextEditingController _newUserNameController = TextEditingController();
  final TextEditingController _newUserEmailController = TextEditingController();
  final TextEditingController _newUserPasswordController = TextEditingController();
  final TextEditingController _newUserPhoneController = TextEditingController();
  final TextEditingController _newUserSpecialtyController = TextEditingController();
  String _newUserRole = 'patient';
  bool _showNewUserForm = false;

  @override
  void initState() {
    super.initState();
  _loadUserData(); // Carga los datos y el rol del usuario al iniciar
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _newUserNameController.dispose();
    _newUserEmailController.dispose();
    _newUserPasswordController.dispose();
    _newUserPhoneController.dispose();
    _newUserSpecialtyController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Usar el servicio unificado para obtener el usuario
      final userModel = await FirebaseService.getUser(user.uid);

      if (userModel != null) {
        setState(() {
          _userData = {
            FirebaseFields.displayName: userModel.displayName,
            FirebaseFields.nombre: userModel.nombre,
            FirebaseFields.email: userModel.email,
            FirebaseFields.telefono: userModel.email, // Se actualizará con el campo correcto
            FirebaseFields.role: userModel.role,
          };
          _nameController.text = userModel.displayName ?? userModel.nombre ?? '';
          _emailController.text = user.email ?? '';
          _phoneController.text = ''; // Se cargará del userData si está disponible
          _selectedRole = userModel.role;
          _isLoading = false;
        });
      } else {
        setState(() {
          _emailController.text = user.email ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Usar el servicio unificado para actualizar el perfil
      final userData = {
        FirebaseFields.displayName: _nameController.text.trim(),
        FirebaseFields.nombre: _nameController.text.trim(),
        FirebaseFields.email: _emailController.text.trim(),
        FirebaseFields.telefono: _phoneController.text.trim(),
        FirebaseFields.phone: _phoneController.text.trim(),
        FirebaseFields.role: _selectedRole,
        FirebaseFields.uid: user.uid,
      };

      // El servicio unificado maneja la actualización en ambas colecciones si es necesario
      await FirebaseService.updateUserProfile(user.uid, userData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado exitosamente'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar perfil: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Registra un nuevo usuario (paciente o médico)
  Future<void> _registerNewUser() async {
    if (!_newUserFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseService.createUser(
        email: _newUserEmailController.text.trim(),
        password: _newUserPasswordController.text.trim(),
        name: _newUserNameController.text.trim(),
        phone: _newUserPhoneController.text.trim().isNotEmpty 
            ? _newUserPhoneController.text.trim() 
            : null,
        role: _newUserRole,
        specialty: _newUserRole == 'doctor' && _newUserSpecialtyController.text.trim().isNotEmpty
            ? _newUserSpecialtyController.text.trim()
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ ${_newUserRole == 'doctor' ? 'Médico' : 'Paciente'} registrado exitosamente',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Limpiar formulario
        _newUserNameController.clear();
        _newUserEmailController.clear();
        _newUserPasswordController.clear();
        _newUserPhoneController.clear();
        _newUserSpecialtyController.clear();
        _newUserRole = 'patient';
        
        setState(() {
          _showNewUserForm = false;
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error al registrar usuario';
        if (e.toString().contains('email-already-in-use')) {
          errorMessage = 'Este correo ya está registrado';
        } else if (e.toString().contains('weak-password')) {
          errorMessage = 'La contraseña es muy débil';
        } else if (e.toString().contains('invalid-email')) {
          errorMessage = 'Correo electrónico inválido';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    if (isIOS) {
      // 👇 CupertinoTextField para iOS
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          CupertinoTextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            placeholder: hint,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(icon, color: CupertinoColors.activeBlue),
            ),
          ),
          const SizedBox(height: 10),
        ],
      );
    }

    // 👇 versión Material (Android)
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
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.blue[700]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Mi Perfil',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1976D2),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1976D2)),
      ),
      body: _isLoading && _userData == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    // Avatar section
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.blue[100],
                          child: Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Nombre completo',
                      icon: Icons.person_outline,
                      hint: 'Ingresa tu nombre',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor ingresa tu nombre';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Correo electrónico',
                      icon: Icons.email_outlined,
                      hint: 'correo@ejemplo.com',
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
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Teléfono',
                      icon: Icons.phone_outlined,
                      hint: 'Número de teléfono',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // Selector de rol para el usuario
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Rol',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'patient', child: Text('Paciente')),
                        DropdownMenuItem(value: 'doctor', child: Text('Médico')),
                      ],
                      onChanged: (v) {
                        // Cambia el rol seleccionado y lo guarda en Firestore
                        if (v != null) setState(() => _selectedRole = v);
                      },
                    ),

                    const SizedBox(height: 24),
                    // Save button
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
                        onPressed: _isLoading ? null : _saveProfile,
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
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Guardar cambios',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Botón para corregir citas (solo visible para doctores)
                    if (_selectedRole == 'doctor' || _userData?['role'] == 'doctor')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Divider(height: 40),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const FixAppointmentsPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.build),
                            label: const Text('Corregir Citas de Jessica Rodriguez'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              backgroundColor: Colors.orange.shade50,
                              foregroundColor: Colors.orange.shade900,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    
                    // Sección para registrar nuevos usuarios
                    const Divider(height: 40),
                    _buildNewUserSection(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildNewUserSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Título y botón para expandir/colapsar
        InkWell(
          onTap: () {
            setState(() {
              _showNewUserForm = !_showNewUserForm;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person_add,
                  color: Colors.blue[700],
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Registrar Nuevo Usuario',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1976D2),
                    ),
                  ),
                ),
                Icon(
                  _showNewUserForm ? Icons.expand_less : Icons.expand_more,
                  color: Colors.blue[700],
                ),
              ],
            ),
          ),
        ),
        
        // Formulario de registro (expandible)
        if (_showNewUserForm) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Form(
              key: _newUserFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Datos del Nuevo Usuario',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1976D2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _newUserNameController,
                    label: 'Nombre completo',
                    icon: Icons.person_outline,
                    hint: 'Ingresa el nombre',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor ingresa el nombre';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _newUserEmailController,
                    label: 'Correo electrónico',
                    icon: Icons.email_outlined,
                    hint: 'correo@ejemplo.com',
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor ingresa el correo';
                      }
                      if (!value.contains('@')) {
                        return 'Ingresa un correo válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _newUserPasswordController,
                    label: 'Contraseña',
                    icon: Icons.lock_outline,
                    hint: 'Mínimo 6 caracteres',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor ingresa una contraseña';
                      }
                      if (value.length < 6) {
                        return 'La contraseña debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _newUserPhoneController,
                    label: 'Teléfono (opcional)',
                    icon: Icons.phone_outlined,
                    hint: 'Número de teléfono',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  
                  // Selector de rol
                  DropdownButtonFormField<String>(
                    value: _newUserRole,
                    decoration: InputDecoration(
                      labelText: 'Tipo de Usuario',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'patient', child: Text('Paciente')),
                      DropdownMenuItem(value: 'doctor', child: Text('Médico')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _newUserRole = v);
                      }
                    },
                  ),
                  
                  // Campo de especialidad (solo para médicos)
                  if (_newUserRole == 'doctor') ...[
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _newUserSpecialtyController,
                      label: 'Especialidad (opcional)',
                      icon: Icons.medical_services_outlined,
                      hint: 'Ej: Cardiología, Pediatría, etc.',
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Botón de registro
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: _newUserRole == 'doctor'
                            ? [Colors.teal, Colors.teal.shade300]
                            : [Colors.green, Colors.green.shade300],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _registerNewUser,
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
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Registrar ${_newUserRole == 'doctor' ? 'Médico' : 'Paciente'}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
