import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'auth_widgets.dart';
import '../teclado_web.dart';
import 'validadores.dart';

class RegisterPage extends StatefulWidget {
  final VoidCallback onIrALogin;

  /// Fila extra al final de la tarjeta: el servidor elegido (solo en móvil
  /// y escritorio, donde la dirección se escribe a mano).
  final Widget? pie;

  const RegisterPage({super.key, required this.onIrALogin, this.pie});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _nametag = TextEditingController();
  final _focoNametag = FocusNode();
  final _password = TextEditingController();
  final _confirmar = TextEditingController();

  @override
  void dispose() {
    _nametag.dispose();
    _focoNametag.dispose();
    _password.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  void _enviar() {
    if (!_form.currentState!.validate()) return;
    context.read<AuthBloc>().add(
      AuthRegistroSolicitado(
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
                      controller: _nametag,
                      focusNode: _focoNametag,
                      onTap: () => reabrirTecladoAlTocar(_focoNametag),
                      readOnly: state.cargando, // no enabled: ver CampoPassword
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newUsername],
                      autocorrect: false,
                      enableSuggestions: false,
                      validator: validarNametag,
                      forceErrorText: state.errores['nametag'],
                      onChanged: _alEscribir,
                      decoration: const InputDecoration(
                        labelText: 'Nametag',
                        helperText: '3 a 20 caracteres: letras, números, . - _',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CampoPassword(
                      controller: _password,
                      etiqueta: 'Contraseña',
                      ayuda: 'Mínimo 6 caracteres.',
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
            if (widget.pie != null) widget.pie!,
          ],
        );
      },
    );
  }
}
