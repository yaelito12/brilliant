import 'package:flutter/material.dart';

import '../fondo.dart';

const colorTextoAuth = Color(0xFF1B3B4D);

/// Marco común de las pantallas de cuenta: barra verde azulada y una tarjeta
/// blanca centrada (mismo estilo que el menú de mapas).
class AuthScaffold extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final List<Widget> children;

  const AuthScaffold({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return FondoBrilliant(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Brilliant',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.teal.shade700,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: colorTextoAuth,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitulo,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Recuadro de aviso: rojo para errores, verde azulado para información.
class BannerMensaje extends StatelessWidget {
  final String texto;
  final bool esError;

  const BannerMensaje({super.key, required this.texto, this.esError = true});

  @override
  Widget build(BuildContext context) {
    final color = esError ? Colors.red : Colors.teal;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            esError ? Icons.error_outline : Icons.info_outline,
            size: 20,
            color: color.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: color.shade900, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de contraseña con botón para mostrar/ocultar.
class CampoPassword extends StatefulWidget {
  final TextEditingController controller;
  final String etiqueta;
  final String? ayuda;
  final String? Function(String?)? validator;
  final String? errorServidor;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction accion;
  final Iterable<String> autofill;
  final bool habilitado;

  const CampoPassword({
    super.key,
    required this.controller,
    required this.etiqueta,
    this.ayuda,
    this.validator,
    this.errorServidor,
    this.onChanged,
    this.onSubmitted,
    this.accion = TextInputAction.done,
    this.autofill = const [AutofillHints.password],
    this.habilitado = true,
  });

  @override
  State<CampoPassword> createState() => _CampoPasswordState();
}

class _CampoPasswordState extends State<CampoPassword> {
  bool _oculta = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.habilitado,
      obscureText: _oculta,
      enableSuggestions: false,
      autocorrect: false,
      autofillHints: widget.autofill,
      textInputAction: widget.accion,
      validator: widget.validator,
      forceErrorText: widget.errorServidor,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.etiqueta,
        helperText: widget.ayuda,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
          icon: Icon(_oculta ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _oculta = !_oculta),
        ),
      ),
    );
  }
}

/// Botón principal con spinner mientras se espera al servidor.
class BotonPrincipal extends StatelessWidget {
  final String texto;
  final bool cargando;
  final VoidCallback onPressed;
  final Color? color;

  const BotonPrincipal({
    super.key,
    required this.texto,
    required this.cargando,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: cargando ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Colors.teal.shade700,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: cargando
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Text(
                texto,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
