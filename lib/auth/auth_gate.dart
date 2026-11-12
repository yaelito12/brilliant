import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../menu_mapas.dart';
import '../multijugador/lobby_page.dart';
import 'auth_config.dart';
import 'auth_page.dart';
import 'auth_repository.dart';
import 'config_servidor.dart';
import 'menu_cuenta.dart';
import 'servidor_page.dart';

/// Pantalla raíz: según haya sesión o no muestra el juego o el inicio de sesión.
class AuthGate extends StatelessWidget {
  /// Dirección del servidor, cuando el jugador la puede elegir (móvil y
  /// escritorio). Si es `null` se usa la que trae la app compilada: así es en
  /// web y en las pruebas.
  final ConfigServidor? config;

  const AuthGate({super.key, this.config});

  @override
  Widget build(BuildContext context) {
    final config = this.config;
    if (config == null || !config.sePuedeCambiar) return _pantalla(null);
    // La pantalla se rehace al elegir (o cambiar) el servidor.
    return ListenableBuilder(
      listenable: config,
      builder: (context, _) => _pantalla(config),
    );
  }

  Widget _pantalla(ConfigServidor? config) {
    // Primera vez en el móvil: sin dirección del servidor no se puede ni
    // iniciar sesión, así que lo primero es preguntarla.
    if (config != null && !config.configurado) {
      return ServidorPage(config: config, primeraVez: true);
    }

    // Si la sesión se cierra (también desde el servidor, porque se entró con
    // la cuenta en otro dispositivo) se cierran las pantallas abiertas encima
    // (partida, multijugador) y queda a la vista el inicio de sesión.
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (antes, ahora) =>
          antes.estado == AuthEstado.autenticado &&
          ahora.estado != AuthEstado.autenticado,
      listener: (context, _) =>
          Navigator.of(context).popUntil((ruta) => ruta.isFirst),
      child: BlocBuilder<AuthBloc, AuthState>(
        buildWhen: (antes, ahora) => antes.estado != ahora.estado,
        builder: (context, state) {
          switch (state.estado) {
            case AuthEstado.desconocido:
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            case AuthEstado.autenticado:
              return MenuMapasPage(
                acciones: [MenuCuenta(config: config)],
                alJugarEnLinea: (context, nivel) => Navigator.of(context).push(
                  LobbyPage.ruta(
                    context.read<AuthRepository>(),
                    url: wsUrlDesde(config?.url ?? apiUrlInicial),
                    nivelInicial: nivel,
                    alCerrarSesion: (mensaje) => context.read<AuthBloc>().add(
                      AuthSesionCerrada(mensaje),
                    ),
                  ),
                ),
              );
            case AuthEstado.noAutenticado:
              return AuthPage(config: config);
          }
        },
      ),
    );
  }
}
