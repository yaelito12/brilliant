import 'package:flutter/material.dart';

import '../teclado_web.dart';
import 'auth_api.dart';
import 'auth_config.dart';
import 'auth_models.dart';
import 'auth_widgets.dart';
import 'config_servidor.dart';

/// Pantalla "Servidor": el jugador escribe la IP de la PC que tiene el
/// servidor encendido. Hace falta en móvil (y sirve en escritorio), porque la
/// app instalada no puede adivinar en qué equipo de la red está el servidor.
class ServidorPage extends StatefulWidget {
  final ConfigServidor config;

  /// No hay dirección guardada todavía: es la primera pantalla de la app y no
  /// se puede cancelar.
  final bool primeraVez;

  /// Se llama al guardar una dirección distinta a la que había. La sesión
  /// anterior era de otro servidor, así que ya no sirve.
  final void Function(String nueva)? alCambiar;

  const ServidorPage({
    super.key,
    required this.config,
    this.primeraVez = false,
    this.alCambiar,
  });

  /// Abre la pantalla encima de la actual (desde el menú de la cuenta o desde
  /// el inicio de sesión).
  static Future<void> abrir(
    BuildContext context,
    ConfigServidor config, {
    void Function(String nueva)? alCambiar,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ServidorPage(config: config, alCambiar: alCambiar),
    ),
  );

  @override
  State<ServidorPage> createState() => _ServidorPageState();
}

class _ServidorPageState extends State<ServidorPage> {
  final _direccion = TextEditingController();
  final _foco = FocusNode();
  bool _probando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _direccion.text = widget.config.paraMostrar;
  }

  @override
  void dispose() {
    _direccion.dispose();
    _foco.dispose();
    super.dispose();
  }

  /// Comprueba que el servidor contesta y, si contesta, la guarda.
  Future<void> _probarYGuardar() async {
    final direccion = normalizarDireccionServidor(_direccion.text);
    if (direccion == null) {
      setState(() => _error = 'Escribe una dirección como 192.168.1.9:3000');
      return;
    }
    setState(() {
      _probando = true;
      _error = null;
    });
    try {
      await AuthApi.comprobar(direccion);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _probando = false;
        _error = e.code == 'sin_conexion'
            ? 'No contesta nadie en $direccion.'
            : e.mensajeParaUsuario;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _probando = false);
    await _guardar(direccion);
  }

  /// Guarda sin comprobar (por si el servidor se enciende después).
  Future<void> _guardarIgual() async {
    final direccion = normalizarDireccionServidor(_direccion.text);
    if (direccion == null) {
      setState(() => _error = 'Escribe una dirección como 192.168.1.9:3000');
      return;
    }
    await _guardar(direccion);
  }

  Future<void> _guardar(String direccion) async {
    final cambio = direccion != widget.config.url;
    if (!await widget.config.guardar(direccion)) {
      if (mounted) {
        setState(() => _error = 'Escribe una dirección como 192.168.1.9:3000');
      }
      return;
    }
    if (cambio) widget.alCambiar?.call(direccion);
    if (!mounted) return;
    // En la primera vez no hay nada debajo: el AuthGate cambia solo de
    // pantalla al quedar configurado el servidor.
    if (!widget.primeraVez) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return AuthScaffold(
      titulo: 'Servidor',
      subtitulo: widget.primeraVez
          ? 'Para jugar en línea, dime dónde está el servidor.'
          : 'Dirección de la PC que tiene el servidor encendido.',
      children: [
        if (error != null) BannerMensaje(texto: error),
        TextField(
          controller: _direccion,
          focusNode: _foco,
          onTap: () => reabrirTecladoAlTocar(_foco),
          readOnly: _probando,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _probando ? null : _probarYGuardar(),
          decoration: const InputDecoration(
            labelText: 'Dirección del servidor',
            hintText: '192.168.1.9:3000',
            helperText: 'Si no pones el puerto, se usa el 3000.',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.dns_outlined),
          ),
        ),
        const SizedBox(height: 20),
        BotonPrincipal(
          texto: 'Probar y guardar',
          cargando: _probando,
          onPressed: _probarYGuardar,
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _probando ? null : _guardarIgual,
          child: const Text('Guardar sin probar'),
        ),
        if (!widget.primeraVez)
          TextButton(
            onPressed: _probando
                ? null
                : () => Navigator.of(context).maybePop(),
            child: const Text('Cancelar'),
          ),
        const Divider(height: 28),
        Text(
          'Es la dirección que aparece en la ventana del servidor, en la PC '
          'donde lo abriste. El teléfono tiene que estar en la misma red '
          'Wi‑Fi que esa PC (no con datos móviles).',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}

/// Pie de las pantallas de cuenta: a qué servidor se va a conectar, y un toque
/// para cambiarlo. No aparece en web, donde la dirección se detecta sola.
class BotonServidor extends StatelessWidget {
  final ConfigServidor config;

  /// Se llama al guardar una dirección distinta a la que había.
  final void Function(String nueva)? alCambiar;

  const BotonServidor({super.key, required this.config, this.alCambiar});

  @override
  Widget build(BuildContext context) {
    if (!config.sePuedeCambiar) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: config,
      builder: (context, _) => TextButton.icon(
        icon: const Icon(Icons.dns_outlined, size: 18),
        label: Text(
          config.configurado
              ? 'Servidor: ${config.paraMostrar}'
              : 'Elegir servidor',
        ),
        onPressed: () =>
            ServidorPage.abrir(context, config, alCambiar: alCambiar),
      ),
    );
  }
}
