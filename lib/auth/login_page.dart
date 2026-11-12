import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'auth_widgets.dart';
import '../teclado_web.dart';
import 'validadores.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onIrARegistro;

  /// Fila extra al final de la tarjeta: el servidor elegido (solo en móvil
  /// y escritorio, donde la dirección se escribe a mano).
  final Widget? pie;

  const LoginPage({super.key, required this.onIrARegistro, this.pie});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _nametag = TextEditingController();
  final _focoNametag = FocusNode();
  final _password = TextEditingController();

  @override
  void dispose() {
    _nametag.dispose();
    _focoNametag.dispose();
    _password.dispose();
    super.dispose();
  }

  void _enviar() {
    if (!_form.currentState!.validate()) return;
    context.read<AuthBloc>().add(
      AuthLoginSolicitado(
        nametag: _nametag.text.trim(),
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
                      controller: _nametag,
                      focusNode: _focoNametag,
                      onTap: () => reabrirTecladoAlTocar(_focoNametag),
                      readOnly: state.cargando, // no enabled: ver CampoPassword
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      autocorrect: false,
                      enableSuggestions: false,
                      validator: validarNametagExistente,
                      forceErrorText: state.errores['nametag'],
                      onChanged: _alEscribir,
                      decoration: const InputDecoration(
                        labelText: 'Nametag',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
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
            if (widget.pie != null) widget.pie!,
          ],
        );
      },
    );
  }
}
