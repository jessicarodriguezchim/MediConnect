import 'package:flutter/material.dart';
import 'home_page.dart';
import 'pages/profile_page.dart';
import 'login_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:citas_medicas/bloc/dashboard_bloc.dart';
import 'package:citas_medicas/bloc/dashboard_page.dart';

class Routes {
  static const String login = '/login';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String dashboard = '/dashboard';


  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => LoginPage());
      case home:
        return MaterialPageRoute(builder: (_) => const HomePage());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfilePage());
      case dashboard:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => DashboardBloc(),
            child: const DashboardPage(),
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}