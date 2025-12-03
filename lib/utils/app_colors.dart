import 'package:flutter/material.dart';

/// Paleta de colores médica moderna para MediConnect
/// 
/// Diseño: Limpio, profesional, moderno y tecnológico
/// Inspirado en interfaces médicas de vanguardia
class AppColors {
  // Azul principal (color primario)
  static const Color primaryBlue = Color(0xFF276EF1); // Azul principal del diseño
  
  // Azul claro para fondos
  static const Color lightBlue = Color(0xFFE9F0FF); // Azul claro para fondos
  
  // Lila suave para acentos
  static const Color softPurple = Color(0xFFA78BFA); // Lila suave para acentos
  
  // Colores neutros
  static const Color white = Color(0xFFFFFFFF); // Blanco para fondos principales
  static const Color lightGrey = Color(0xFFF2F2F2); // Gris claro para tarjetas y separadores
  static const Color mediumGrey = Color(0xFF9E9E9E); // Gris medio para texto secundario
  static const Color softBlack = Color(0xFF1A1A1A); // Negro suave para títulos
  
  // Variaciones de azul para gradientes
  static const Color blueLight = Color(0xFF4A90E2);
  static const Color blueLighter = Color(0xFF6BA3F5);
  
  // Variaciones de lila para gradientes
  static const Color purpleLight = Color(0xFFB794F6);
  static const Color purpleLighter = Color(0xFFC4A5F7);
  
  // Colores de estado (mantener sutiles)
  static const Color success = Color(0xFF10B981); // Verde suave para éxito
  static const Color warning = Color(0xFFF59E0B); // Amarillo suave para advertencia
  static const Color error = Color(0xFFEF4444); // Rojo suave para errores
  
  // Degradados suaves en azules
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, blueLight],
  );
  
  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, blueLighter],
  );
  
  // Degradados suaves en lilas
  static const LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [softPurple, purpleLight],
  );
  
  // Degradado azul-lila (combinación elegante)
  static const LinearGradient bluePurpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, softPurple],
  );
  
  // Degradado para fondos (muy suave)
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [lightBlue, white],
  );
  
  // Degradado suave para cards
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [white, lightBlue],
  );
  
  // Sombra suave para tarjetas (estilo médico moderno)
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: primaryBlue.withOpacity(0.08),
      blurRadius: 20,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];
  
  // Sombra más pronunciada para elementos elevados
  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: primaryBlue.withOpacity(0.12),
      blurRadius: 30,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
  ];
  
  // Sombra sutil para hover
  static List<BoxShadow> get hoverShadow => [
    BoxShadow(
      color: primaryBlue.withOpacity(0.15),
      blurRadius: 25,
      offset: const Offset(0, 6),
      spreadRadius: 2,
    ),
  ];
}

/// Estilos de texto médicos modernos
class AppTextStyles {
  // Títulos principales (grandes y bold)
  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.softBlack,
    letterSpacing: -0.5,
    height: 1.2,
  );
  
  // Títulos secundarios
  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.softBlack,
    letterSpacing: -0.3,
    height: 1.3,
  );
  
  // Títulos terciarios
  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.softBlack,
    letterSpacing: -0.2,
    height: 1.4,
  );
  
  // Texto de cuerpo (principal)
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.softBlack,
    letterSpacing: 0,
    height: 1.5,
  );
  
  // Texto de cuerpo (mediano)
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.softBlack,
    letterSpacing: 0,
    height: 1.5,
  );
  
  // Texto secundario
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.mediumGrey,
    letterSpacing: 0.2,
    height: 1.5,
  );
  
  // Texto de botones
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.2,
  );
  
  // Texto de etiquetas
  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.mediumGrey,
    letterSpacing: 0.5,
    height: 1.4,
  );
}

/// Estilos de componentes médicos modernos
class AppStyles {
  // Radio de borde para tarjetas (suave)
  static const double cardRadius = 16.0;
  
  // Radio de borde para botones (redondeado)
  static const double buttonRadius = 12.0;
  
  // Radio de borde para inputs (redondeado)
  static const double inputRadius = 12.0;
  
  // Padding estándar
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;
  
  // Espaciado entre elementos
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;
  
  // Altura de botones
  static const double buttonHeight = 56.0;
  static const double buttonHeightSmall = 48.0;
}
