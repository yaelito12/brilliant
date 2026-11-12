import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'auth/auth_api.dart';
import 'auth/auth_config.dart';
import 'auth/auth_gate.dart';
import 'auth/auth_repository.dart';
import 'auth/config_servidor.dart';
import 'auth/secure_token_storage.dart';
import 'bloc/auth_bloc.dart';
import 'bloc/auth_event.dart';
import 'menu_mapas.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dirección del servidor: en web se detecta sola; en móvil y escritorio es
  // la que escribió el jugador la última vez (pantalla "Servidor").
  final servidor = ConfigServidor(
    urlInicial: apiUrlInicial,
    almacen: AlmacenServidorSeguro(),
  );
  await servidor.cargar();

  final api = AuthApi(baseUrl: servidor.url);
  servidor.addListener(() => api.baseUrl = servidor.url);

  final repositorio = AuthRepository(
    api: api,
    almacen: SecureTokenStorage(),
  );

  runApp(
    RepositoryProvider.value(
      value: repositorio,
      child: BlocProvider(
        create: (_) => AuthBloc(
          repositorio,
          // Si se entra con la cuenta en otro dispositivo, este se entera en
          // menos de un minuto aunque no esté en el multijugador.
          verificarCada: const Duration(minutes: 1),
        )..add(AuthIniciada()),
        child: MyApp(home: AuthGate(config: servidor)),
      ),
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
