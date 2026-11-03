import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'auth/auth_api.dart';
import 'auth/auth_config.dart';
import 'auth/auth_gate.dart';
import 'auth/auth_repository.dart';
import 'auth/secure_token_storage.dart';
import 'bloc/auth_bloc.dart';
import 'bloc/auth_event.dart';
import 'menu_mapas.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final repositorio = AuthRepository(
    api: AuthApi(baseUrl: apiUrl),
    almacen: SecureTokenStorage(),
  );

  runApp(
    BlocProvider(
      create: (_) => AuthBloc(repositorio)..add(AuthIniciada()),
      child: const MyApp(home: AuthGate()),
    ),
  );
}

class MyApp extends StatelessWidget {
  /// Pantalla inicial. En la app real es el [AuthGate] (pide iniciar sesión);
  /// por defecto es el menú de mapas, que es lo que usan las pruebas del juego.
  final Widget home;

  const MyApp({super.key, this.home = const MenuMapasPage()});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brilliant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: home,
    );
  }
}
