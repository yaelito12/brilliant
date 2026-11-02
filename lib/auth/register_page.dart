import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'auth_widgets.dart';
import 'validadores.dart';

class RegisterPage extends StatefulWidget {
  final VoidCallback onIrALogin;

  const RegisterPage({super.key, required this.onIrALogin});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmar = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _password.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  void _enviar() {
    if (!_form.currentState!.validate()) return;
    context.read<AuthBloc>().add(
      AuthRegistroSolicitado(
        email: _email.text.trim(),
        nombre: _nombre.text.trim(),
        password: _password.text,
      ),
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
        final error = state.error;
        return AuthScaffold(
          titulo: 'Crea tu cuenta',
          subtitulo: 'Solo te tomará un minuto.',
          children: [
            if (error != null) BannerMensaje(texto: error),
            Form(
              key: _form,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nombre,
                      enabled: !state.cargando,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.nickname],
                      textCapitalization: TextCapitalization.words,
                      validator: validarNombre,
                      forceErrorText: state.errores['nombre'],
                      onChanged: _alEscribir,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _email,
                      enabled: !state.cargando,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newUsername],
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
                      ayuda: 'Mínimo 10 caracteres.',
                      habilitado: !state.cargando,
                      autofill: const [AutofillHints.newPassword],
                      accion: TextInputAction.next,
                      validator: validarPasswordNueva,
                      errorServidor: state.errores['password'],
                      onChanged: _alEscribir,
                    ),
                    const SizedBox(height: 8),
                    CampoPassword(
                      controller: _confirmar,
                      etiqueta: 'Repite la contraseña',
                      habilitado: !state.cargando,
                      autofill: const [AutofillHints.newPassword],
                      validator: validarConfirmacion(() => _password.text),
                      onSubmitted: (_) => _enviar(),
                    ),
                    const SizedBox(height: 20),
                    BotonPrincipal(
                      texto: 'Crear cuenta',
                      cargando: state.cargando,
                      onPressed: _enviar,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: state.cargando ? null : widget.onIrALogin,
              child: const Text('¿Ya tienes cuenta? Inicia sesión'),
            ),
          ],
        );
      },
    );
  }
}
