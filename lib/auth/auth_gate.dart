import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';
import '../menu_mapas.dart';
import '../multijugador/lobby_page.dart';
import 'auth_page.dart';
import 'auth_repository.dart';
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
            return MenuMapasPage(
              acciones: const [MenuCuenta()],
              alJugarEnLinea: (context, nivel) => Navigator.of(context).push(
                LobbyPage.ruta(
                  context.read<AuthRepository>(),
                  nivelInicial: nivel,
                ),
              ),
            );
          case AuthEstado.noAutenticado:
            return const AuthPage();
        }
      },
    );
  }
}
