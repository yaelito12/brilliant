import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'auth_widgets.dart';
import 'validadores.dart';

/// Pide la contraseña y borra la cuenta de forma permanente.
/// Se cierra solo cuando la cuenta ya se borró (la sesión deja de existir).
class BorrarCuentaDialog extends StatefulWidget {
  const BorrarCuentaDialog({super.key});

  @override
  State<BorrarCuentaDialog> createState() => _BorrarCuentaDialogState();
}

class _BorrarCuentaDialogState extends State<BorrarCuentaDialog> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _borrar() {
    if (!_form.currentState!.validate()) return;
    context.read<AuthBloc>().add(AuthBorrarCuentaSolicitado(_password.text));
  }

  void _cancelar() {
    context.read<AuthBloc>().add(AuthMensajesLimpiados());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Al borrarse la cuenta, AuthGate cierra este diálogo (y cualquier otra
    // pantalla abierta) y muestra el inicio de sesión.
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final error = state.error;
        return AlertDialog(
          title: const Text('Borrar cuenta'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Esta acción es permanente: tu cuenta se eliminará del '
                    'servidor y no se puede deshacer.\n\n'
                    'Escribe tu contraseña para confirmar.',
                  ),
                  const SizedBox(height: 16),
                  if (error != null) BannerMensaje(texto: error),
                  Form(
                    key: _form,
                    child: CampoPassword(
                      controller: _password,
                      etiqueta: 'Contraseña',
                      habilitado: !state.cargando,
                      validator: validarPasswordExistente,
                      onChanged: (_) {
                        final bloc = context.read<AuthBloc>();
                        if (bloc.state.hayMensajes) {
                          bloc.add(AuthMensajesLimpiados());
                        }
                      },
                      onSubmitted: (_) => _borrar(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: state.cargando ? null : _cancelar,
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: state.cargando ? null : _borrar,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              child: state.cargando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Borrar mi cuenta'),
            ),
          ],
        );
      },
    );
  }
}
