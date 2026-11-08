import 'package:brilliant_reglas/brilliant_reglas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../auth/auth_config.dart';
import '../auth/auth_models.dart' show mensajeSesionReemplazada, mensajeSesionVencida;
import '../auth/auth_repository.dart';
import '../menu_mapas.dart';
import 'conexion_multijugador.dart';
import 'lobby_bloc.dart';
import 'modelos.dart';
import 'partida_view.dart';
import 'resultados_view.dart';

const _colorTexto = Color(0xFF1B3B4D);
const _fondo = Color(0xFFE8F2ED);

/// Pantalla "Jugar en línea": crear una sala o unirse con un código, elegir
/// el mapa, ver a los demás jugadores y marcar "listo".
class LobbyPage extends StatelessWidget {
  /// Mapa que venía elegido en el menú.
  final Nivel? nivelInicial;

  /// Para las pruebas: un bloc ya creado (con una conexión falsa).
  final LobbyBloc? bloc;

  /// Se llama si el servidor cierra la sesión (se entró con la cuenta en otro
  /// dispositivo o venció). La app vuelve al inicio de sesión con [mensaje].
  final void Function(String mensaje)? alCerrarSesion;

  const LobbyPage({super.key, this.nivelInicial, this.bloc, this.alCerrarSesion});

  /// Abre el lobby conectándose al servidor con la sesión actual.
  static Route<void> ruta(
    AuthRepository repo, {
    Nivel? nivelInicial,
    void Function(String mensaje)? alCerrarSesion,
  }) =>
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => LobbyBloc(
            ConexionMultijugador(url: wsUrl, token: repo.tokenDeAcceso),
          )..add(LobbyIniciado()),
          child: LobbyPage(nivelInicial: nivelInicial, alCerrarSesion: alCerrarSesion),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final b = bloc;
    final vista = _VistaLobby(nivelInicial: nivelInicial, alCerrarSesion: alCerrarSesion);
    return b == null ? vista : BlocProvider.value(value: b, child: vista);
  }
}

class _VistaLobby extends StatefulWidget {
  final Nivel? nivelInicial;
  final void Function(String mensaje)? alCerrarSesion;
  const _VistaLobby({this.nivelInicial, this.alCerrarSesion});

  @override
  State<_VistaLobby> createState() => _VistaLobbyState();
}

class _VistaLobbyState extends State<_VistaLobby> {
  late int? _nivel = widget.nivelInicial?.numero;
  final _codigo = TextEditingController();

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  /// Al salir de la pantalla estando en una sala, se confirma y se sale de ella.
  Future<void> _volver(BuildContext context) async {
    final bloc = context.read<LobbyBloc>();
    final navegador = Navigator.of(context);
    if (bloc.state.sala != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Salir de la sala?'),
          content: Text(
            bloc.state.sala!.jugando
                ? 'La partida está en curso: salir cuenta como rendirse.'
                : 'Dejarás tu lugar en la sala.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salir')),
          ],
        ),
      );
      if (ok != true) return;
      bloc.add(LobbySalir());
    }
    navegador.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _volver(context);
      },
      child: BlocListener<LobbyBloc, LobbyState>(
        // La sesión se cerró desde el servidor: de vuelta al inicio de sesión.
        listenWhen: (a, b) =>
            a.conexion != b.conexion &&
            (b.conexion == EstadoConexion.sesionCerrada || b.conexion == EstadoConexion.sinSesion),
        listener: (context, state) => widget.alCerrarSesion?.call(
          state.conexion == EstadoConexion.sesionCerrada
              ? mensajeSesionReemplazada
              : mensajeSesionVencida,
        ),
        child: BlocListener<LobbyBloc, LobbyState>(
        listenWhen: (a, b) => b.aviso != null && a.aviso?.id != b.aviso!.id,
        listener: (context, state) {
          final aviso = state.aviso!;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(aviso.texto),
              backgroundColor: aviso.esError ? Colors.red.shade700 : null,
              behavior: SnackBarBehavior.floating,
            ));
        },
        child: Scaffold(
          backgroundColor: _fondo,
          appBar: AppBar(
            title: const Text('Jugar en línea', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.teal.shade700,
            foregroundColor: Colors.white,
            leading: BackButton(onPressed: () => _volver(context)),
          ),
          body: BlocBuilder<LobbyBloc, LobbyState>(
            builder: (context, state) {
              final sala = state.sala;
              final enPartida = sala != null && sala.jugando && state.partida != null;
              return Column(
                children: [
                  BarraConexion(estado: state.conexion),
                  Expanded(
                    // La partida usa toda la pantalla; el lobby, una columna centrada.
                    child: enPartida
                        ? PartidaMultijugadorView(state: state)
                        : Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 720),
                                child: sala == null
                                    ? _sinSala(context, state)
                                    : sala.jugando
                                        ? const _Preparando()
                                        : _EnSala(state: state),
                              ),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      ),
    );
  }

  Widget _sinSala(BuildContext context, LobbyState state) {
    final listo = state.conectado && !state.esperando;
    final bloc = context.read<LobbyBloc>();

    // Para unirse basta el código: sin mapa elegido se juega el de quien
    // creó la sala (se puede cambiar dentro).
    void unirse() {
      if (!listo || _codigo.text.trim().length != 6) return;
      bloc.add(LobbyUnirse(_codigo.text, _nivel));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Titulo('¿Te pasaron un código?'),
        const SizedBox(height: 4),
        Text(
          'Escríbelo y entra directo a la partida de tu amigo.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 300,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('codigo'),
                  controller: _codigo,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 20, letterSpacing: 4, fontWeight: FontWeight.bold),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                    _Mayusculas(),
                  ],
                  decoration: const InputDecoration(
                    hintText: 'CÓDIGO',
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => unirse(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 56,
                child: FilledButton(
                  key: const Key('unirse'),
                  onPressed: listo && _codigo.text.length == 6 ? unirse : null,
                  style: FilledButton.styleFrom(backgroundColor: Colors.teal.shade700),
                  child: const Text('Unirse'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('o crea tu propia sala', style: TextStyle(color: Colors.grey.shade700)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        const _Titulo('Elige tu mapa'),
        const SizedBox(height: 12),
        SelectorMapa(
          elegido: _nivel,
          onElegir: (n) => setState(() => _nivel = n),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 300,
          height: 50,
          child: FilledButton.icon(
            key: const Key('crear-sala'),
            onPressed: listo && _nivel != null ? () => bloc.add(LobbyCrearSala(_nivel!)) : null,
            style: FilledButton.styleFrom(backgroundColor: Colors.teal.shade700),
            icon: const Icon(Icons.add),
            label: const Text('Crear sala', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        if (_nivel == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Elige un mapa para crear la sala.', style: TextStyle(color: Colors.grey.shade700)),
          ),
        if (state.esperando)
          const Padding(padding: EdgeInsets.only(top: 16), child: CircularProgressIndicator()),
      ],
    );
  }
}

/// Avisa si la conexión no está lista (conectando, reconectando, etc.).
class BarraConexion extends StatelessWidget {
  final EstadoConexion estado;
  const BarraConexion({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final (texto, color, accion) = switch (estado) {
      EstadoConexion.conectado || EstadoConexion.cerrada => (null, null, null),
      EstadoConexion.conectando => ('Conectando con el servidor…', Colors.blueGrey, null),
      EstadoConexion.reconectando => (
        'Se perdió la conexión. Reconectando… Tu lugar se guarda unos segundos.',
        Colors.orange.shade800,
        null,
      ),
      EstadoConexion.sesionReemplazada => (
        'Abriste tu cuenta en otro dispositivo o pestaña.',
        Colors.red.shade700,
        'Usar aquí',
      ),
      EstadoConexion.sinSesion => (
        'Tu sesión venció. Vuelve a iniciar sesión.',
        Colors.red.shade700,
        null,
      ),
      EstadoConexion.sesionCerrada => (
        'Se inició sesión con tu cuenta en otro dispositivo.',
        Colors.red.shade700,
        null,
      ),
    };
    if (texto == null) return const SizedBox.shrink();
    final trabajando = estado == EstadoConexion.conectando || estado == EstadoConexion.reconectando;

    return Material(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (trabajando)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            else
              const Icon(Icons.wifi_off, color: Colors.white, size: 18),
            const SizedBox(width: 12),
            Expanded(child: Text(texto, style: const TextStyle(color: Colors.white))),
            if (accion != null)
              TextButton(
                onPressed: () => context.read<LobbyBloc>().add(LobbyReconectar()),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: Text(accion),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fila de mapas oficiales para elegir uno.
class SelectorMapa extends StatelessWidget {
  final int? elegido;
  final ValueChanged<int>? onElegir;
  const SelectorMapa({super.key, required this.elegido, required this.onElegir});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final nivel in nivelesOficiales)
          TarjetaMapa(
            nivel: nivel,
            elegido: nivel.numero == elegido,
            onTap: onElegir == null ? () {} : () => onElegir!(nivel.numero),
          ),
      ],
    );
  }
}

class _EnSala extends StatelessWidget {
  final LobbyState state;
  const _EnSala({required this.state});

  @override
  Widget build(BuildContext context) {
    final sala = state.sala!;
    final yo = state.miJugador;
    final bloc = context.read<LobbyBloc>();
    final faltanJugadores = sala.jugadores.length < sala.minJugadores;

    final String estadoTexto;
    if (faltanJugadores) {
      estadoTexto = 'Esperando jugadores: mínimo ${sala.minJugadores}. Comparte el código.';
    } else if (sala.listos < sala.jugadores.length) {
      estadoTexto = 'Listos: ${sala.listos} de ${sala.jugadores.length}. '
          'La partida empieza cuando todos estén listos.';
    } else {
      estadoTexto = '¡Todos listos!';
    }

    final resultados = state.resultados;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (resultados != null) ...[
          TarjetaResultados(
            resultados: resultados,
            yoId: state.yo?.id,
            onCerrar: () => bloc.add(LobbyCerrarResultados()),
          ),
          const SizedBox(height: 16),
        ],
        _TarjetaCodigo(codigo: sala.codigo),
        const SizedBox(height: 16),
        _Titulo('Jugadores (${sala.jugadores.length}/${sala.maxJugadores})'),
        const SizedBox(height: 8),
        Card(
          color: Colors.white,
          child: Column(
            children: [
              for (final j in sala.jugadores) _FilaJugador(jugador: j, soyYo: j.id == state.yo?.id),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(estadoTexto, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade800)),
        const SizedBox(height: 20),
        const _Titulo('Tu mapa'),
        const SizedBox(height: 4),
        Text(
          'Cada jugador juega su propio mapa. Cambiarlo quita tu "listo".',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 10),
        SelectorMapa(
          elegido: yo?.nivel,
          onElegir: state.conectado ? (n) => bloc.add(LobbyElegirMapa(n)) : null,
        ),
        const SizedBox(height: 24),
        Center(
          child: SizedBox(
            width: 300,
            height: 52,
            child: FilledButton.icon(
              key: const Key('listo'),
              onPressed: state.conectado && yo != null ? () => bloc.add(LobbyListo(!yo.listo)) : null,
              style: FilledButton.styleFrom(
                backgroundColor: yo?.listo ?? false ? Colors.grey.shade600 : Colors.green.shade700,
              ),
              icon: Icon(yo?.listo ?? false ? Icons.close : Icons.check),
              label: Text(
                yo?.listo ?? false ? 'Ya no estoy listo' : '¡Estoy listo!',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            key: const Key('salir-sala'),
            onPressed: () => bloc.add(LobbySalir()),
            icon: const Icon(Icons.logout),
            label: const Text('Salir de la sala'),
          ),
        ),
      ],
    );
  }
}

class _TarjetaCodigo extends StatelessWidget {
  final String codigo;
  const _TarjetaCodigo({required this.codigo});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Código de la sala', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SelectableText(
                  codigo,
                  key: const Key('codigo-sala'),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: _colorTexto,
                  ),
                ),
                IconButton(
                  tooltip: 'Copiar código',
                  icon: const Icon(Icons.copy),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: codigo));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Código copiado.'),
                      behavior: SnackBarBehavior.floating,
                    ));
                  },
                ),
              ],
            ),
            Text(
              'Pásalo a tus amigos para que se unan (2 a 6 jugadores).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaJugador extends StatelessWidget {
  final JugadorEnSala jugador;
  final bool soyYo;
  const _FilaJugador({required this.jugador, required this.soyYo});

  @override
  Widget build(BuildContext context) {
    final j = jugador;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: j.conectado ? Colors.teal.shade100 : Colors.grey.shade300,
        child: Text(j.nametag.substring(0, 1).toUpperCase()),
      ),
      title: Text(
        soyYo ? '${j.nametag} (tú)' : j.nametag,
        style: TextStyle(fontWeight: soyYo ? FontWeight.bold : FontWeight.w500),
      ),
      subtitle: Text(
        j.conectado ? 'Nivel ${j.nivel}' : 'Nivel ${j.nivel} · sin conexión, esperando que vuelva…',
        style: TextStyle(color: j.conectado ? null : Colors.orange.shade800),
      ),
      trailing: j.listo
          ? Chip(
              avatar: Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
              label: const Text('Listo'),
              backgroundColor: Colors.green.shade50,
            )
          : Chip(
              label: const Text('Esperando'),
              backgroundColor: Colors.grey.shade100,
            ),
    );
  }
}

/// La sala ya empezó pero aún no llega el estado de la partida (un instante).
class _Preparando extends StatelessWidget {
  const _Preparando();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 12),
        Text('¡La partida comenzó! Preparando el tablero…',
            style: TextStyle(fontWeight: FontWeight.bold, color: _colorTexto)),
      ],
    );
  }
}

class _Titulo extends StatelessWidget {
  final String texto;
  const _Titulo(this.texto);

  @override
  Widget build(BuildContext context) => Text(
    texto,
    textAlign: TextAlign.center,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _colorTexto),
  );
}

class _Mayusculas extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue viejo, TextEditingValue nuevo) =>
      nuevo.copyWith(text: nuevo.text.toUpperCase());
}
