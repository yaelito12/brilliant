import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';
import '../menu_mapas.dart';
import 'auth_page.dart';
import 'menu_cuenta.dart';

/// Pantalla raíz: según haya sesión o no muestra el juego o el inicio de sesión.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (antes, ahora) => antes.estado != ahora.estado,
      builder: (context, state) {
        switch (state.estado) {
          case AuthEstado.desconocido:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          case AuthEstado.autenticado:
            return const MenuMapasPage(acciones: [MenuCuenta()]);
          case AuthEstado.noAutenticado:
            return const AuthPage();
        }
      },
    );
  }
}
