import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'auth_widgets.dart';
import 'validadores.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onIrARegistro;

  const LoginPage({super.key, required this.onIrARegistro});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _enviar() {
    if (!_form.currentState!.validate()) return;
    context.read<AuthBloc>().add(
      AuthLoginSolicitado(email: _email.text.trim(), password: _password.text),
    );
  }

  void _alEscribir(String _) {
    final bloc = context.read<AuthBloc>();
    if (bloc.state.hayMensajes) bloc.add(AuthMensajesLimpiados());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final info = state.info;
        final error = state.error;
        return AuthScaffold(
          titulo: 'Inicia sesión',
          subtitulo: 'Entra con tu cuenta para jugar.',
          children: [
            if (info != null) BannerMensaje(texto: info, esError: false),
            if (error != null) BannerMensaje(texto: error),
            Form(
              key: _form,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _email,
                      enabled: !state.cargando,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      validator: validarEmail,
                      forceErrorText: state.errores['email'],
                      onChanged: _alEscribir,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CampoPassword(
                      controller: _password,
                      etiqueta: 'Contraseña',
                      habilitado: !state.cargando,
                      validator: validarPasswordExistente,
                      errorServidor: state.errores['password'],
                      onChanged: _alEscribir,
                      onSubmitted: (_) => _enviar(),
                    ),
                    const SizedBox(height: 20),
                    BotonPrincipal(
                      texto: 'Entrar',
                      cargando: state.cargando,
                      onPressed: _enviar,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: state.cargando ? null : widget.onIrARegistro,
              child: const Text('¿No tienes cuenta? Crea una'),
            ),
          ],
        );
      },
    );
  }
}
