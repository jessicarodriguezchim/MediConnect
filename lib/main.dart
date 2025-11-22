import 'package:flutter/material.dart';
import 'package:url_strategy/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'pages/firebase_options.dart';
import 'routes.dart';
import 'bloc/dashboard_bloc.dart';
import 'utils/crear_datos_prueba.dart';

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
          primarySwatch: Colors.teal,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.light,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          cardTheme: const CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        initialRoute: Routes.login,
        onGenerateRoute: Routes.generateRoute,
      ),
    );
  }
}

// LoginPage se encuentra en login_page.dart - no duplicar aquí