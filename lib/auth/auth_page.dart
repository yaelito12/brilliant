import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import 'login_page.dart';
import 'register_page.dart';

/// Alterna entre "Inicia sesión" y "Crea tu cuenta" sin apilar rutas
/// (así, al entrar, el [AuthGate] solo cambia la pantalla raíz).
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

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
    return _registro
        ? RegisterPage(onIrALogin: () => _cambiar(false))
        : LoginPage(onIrARegistro: () => _cambiar(true));
  }
}
