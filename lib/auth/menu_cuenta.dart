import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'auth_widgets.dart';
import 'borrar_cuenta_dialog.dart';

enum _Opcion { cerrarSesion, borrarCuenta }

/// Botón de la barra superior: muestra quién ha entrado y permite
/// cerrar sesión o borrar la cuenta.
class MenuCuenta extends StatelessWidget {
  const MenuCuenta({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final usuario = state.usuario;
        return PopupMenuButton<_Opcion>(
          tooltip: 'Cuenta',
          icon: const Icon(Icons.account_circle),
          onSelected: (opcion) {
            switch (opcion) {
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
