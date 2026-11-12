import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'auth_widgets.dart';
import 'borrar_cuenta_dialog.dart';
import 'config_servidor.dart';
import 'servidor_page.dart';

enum _Opcion { servidor, cerrarSesion, borrarCuenta }

/// Botón de la barra superior: muestra quién ha entrado y permite
/// cambiar de servidor, cerrar sesión o borrar la cuenta.
class MenuCuenta extends StatelessWidget {
  /// Si el jugador puede elegir el servidor, el menú deja cambiarlo.
  final ConfigServidor? config;

  const MenuCuenta({super.key, this.config});

  @override
  Widget build(BuildContext context) {
    final config = this.config;
    final puedeElegirServidor = config != null && config.sePuedeCambiar;
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final usuario = state.usuario;
        return PopupMenuButton<_Opcion>(
          tooltip: 'Cuenta',
          icon: const Icon(Icons.account_circle),
          onSelected: (opcion) {
            switch (opcion) {
              case _Opcion.servidor:
                final bloc = context.read<AuthBloc>();
                ServidorPage.abrir(
                  context,
                  config!,
                  // La sesión era del servidor anterior: hay que volver a entrar.
                  alCambiar: (_) => bloc.add(
                    AuthSesionCerrada('Cambiaste de servidor. Vuelve a entrar.'),
                  ),
                );
              case _Opcion.cerrarSesion:
                context.read<AuthBloc>().add(AuthLogoutSolicitado());
              case _Opcion.borrarCuenta:
                showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => BlocProvider.value(
                    value: context.read<AuthBloc>(),
                    child: const BorrarCuentaDialog(),
                  ),
                );
            }
          },
          itemBuilder: (_) => [
            if (usuario != null) ...[
              PopupMenuItem<_Opcion>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sesión iniciada como',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      usuario.nametag,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorTextoAuth,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
            ],
            if (puedeElegirServidor)
              PopupMenuItem<_Opcion>(
                value: _Opcion.servidor,
                child: Row(
                  children: [
                    const Icon(Icons.dns_outlined),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Servidor: ${config.paraMostrar}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            const PopupMenuItem<_Opcion>(
              value: _Opcion.cerrarSesion,
              child: Row(
                children: [
                  Icon(Icons.logout),
                  SizedBox(width: 12),
                  Text('Cerrar sesión'),
                ],
              ),
            ),
            PopupMenuItem<_Opcion>(
              value: _Opcion.borrarCuenta,
              child: Row(
                children: [
                  Icon(Icons.delete_forever, color: Colors.red.shade700),
                  const SizedBox(width: 12),
                  Text(
                    'Borrar cuenta',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
