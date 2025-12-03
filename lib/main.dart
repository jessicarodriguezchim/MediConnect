import 'package:flutter/material.dart';
import 'package:url_strategy/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'pages/firebase_options.dart';
import 'routes.dart';
import 'bloc/dashboard_bloc.dart';
import 'utils/crear_datos_prueba.dart';
import 'utils/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use path URL strategy so web URLs are clean (no #).
  // Note: when deploying to production, configure server to rewrite requests to index.html.
  setPathUrlStrategy();

  // Inicializa Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Inicializa el formato de fecha para español
  await initializeDateFormatting('es', null);

  // DESCOMENTA SOLO PARA POBLAR DATOS DE PRUEBA UNA VEZ
  // await crearDatosPrueba();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // BlocProvider global para DashboardBloc
        BlocProvider<DashboardBloc>(
          create: (context) => DashboardBloc(),
        ),
      ],
      child: MaterialApp(
        title: 'MediConnect',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.light(
            primary: AppColors.primaryBlue,
            secondary: AppColors.softPurple,
            surface: AppColors.white,
            background: AppColors.lightBlue,
            error: AppColors.error,
            onPrimary: AppColors.white,
            onSecondary: AppColors.white,
            onSurface: AppColors.softBlack,
            onBackground: AppColors.softBlack,
            onError: AppColors.white,
          ),
          scaffoldBackgroundColor: AppColors.lightBlue,
          fontFamily: 'Inter', // Tipografía moderna (si está disponible)
          textTheme: const TextTheme(
            displayLarge: AppTextStyles.heading1,
            displayMedium: AppTextStyles.heading2,
            displaySmall: AppTextStyles.heading3,
            bodyLarge: AppTextStyles.bodyLarge,
            bodyMedium: AppTextStyles.bodyMedium,
            bodySmall: AppTextStyles.bodySmall,
            labelLarge: AppTextStyles.button,
            labelMedium: AppTextStyles.label,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: AppColors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              minimumSize: const Size(double.infinity, AppStyles.buttonHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppStyles.buttonRadius),
              ),
              textStyle: AppTextStyles.button,
            ),
          ),
          cardTheme: CardThemeData(
            color: AppColors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppStyles.cardRadius),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppStyles.inputRadius),
              borderSide: BorderSide(color: AppColors.lightGrey, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppStyles.inputRadius),
              borderSide: BorderSide(color: AppColors.lightGrey, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppStyles.inputRadius),
              borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppStyles.inputRadius),
              borderSide: BorderSide(color: AppColors.error, width: 1),
            ),
            labelStyle: AppTextStyles.label.copyWith(color: AppColors.mediumGrey),
            hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGrey),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.white,
            foregroundColor: AppColors.softBlack,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: AppTextStyles.heading3.copyWith(color: AppColors.softBlack),
            iconTheme: const IconThemeData(color: AppColors.softBlack),
          ),
        ),
        initialRoute: Routes.login,
        onGenerateRoute: Routes.generateRoute,
      ),
    );
  }
}

// LoginPage se encuentra en login_page.dart - no duplicar aquí