import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import 'config_servidor.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'servidor_page.dart';

/// Alterna entre "Inicia sesión" y "Crea tu cuenta" sin apilar rutas
/// (así, al entrar, el [AuthGate] solo cambia la pantalla raíz).
class AuthPage extends StatefulWidget {
  /// Si se puede elegir el servidor, al pie se muestra cuál está elegido.
  final ConfigServidor? config;

  const AuthPage({super.key, this.config});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _registro = false;

  void _cambiar(bool registro) {
    context.read<AuthBloc>().add(AuthMensajesLimpiados());
    setState(() => _registro = registro);
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final pie = config == null ? null : BotonServidor(config: config);
    return _registro
        ? RegisterPage(onIrALogin: () => _cambiar(false), pie: pie)
        : LoginPage(onIrARegistro: () => _cambiar(true), pie: pie);
  }
}
