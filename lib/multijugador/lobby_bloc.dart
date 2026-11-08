import 'dart:async';

import 'package:bloc/bloc.dart';

import '../auth/auth_models.dart';
import 'conexion_multijugador.dart';
import 'modelos.dart';

// ---------------------------------------------------------------------------
// Eventos
// ---------------------------------------------------------------------------

sealed class LobbyEvent {}

/// Abre la conexión.
class LobbyIniciado extends LobbyEvent {}

class LobbyCrearSala extends LobbyEvent {
  final int nivel;
  LobbyCrearSala(this.nivel);
}

class LobbyUnirse extends LobbyEvent {
  final String codigo;
  final int nivel;
  LobbyUnirse(this.codigo, this.nivel);
}

class LobbyElegirMapa extends LobbyEvent {
  final int nivel;
  LobbyElegirMapa(this.nivel);
}

class LobbyListo extends LobbyEvent {
  final bool listo;
  LobbyListo(this.listo);
}

class LobbySalir extends LobbyEvent {}

/// Reconectar ya (por ejemplo, después de "abriste tu cuenta en otro lugar").
class LobbyReconectar extends LobbyEvent {}

class _MensajeRecibido extends LobbyEvent {
  final Map<String, dynamic> msg;
  _MensajeRecibido(this.msg);
}

class _ConexionCambio extends LobbyEvent {
  final EstadoConexion estado;
  _ConexionCambio(this.estado);
}

// ---------------------------------------------------------------------------
// Estado
// ---------------------------------------------------------------------------

/// Mensaje para mostrar una sola vez (snackbar). [id] cambia con cada uno.
class Aviso {
  final int id;
  final String texto;
  final bool esError;
  const Aviso(this.id, this.texto, {this.esError = false});
}

class LobbyState {
  final EstadoConexion conexion;
  final Usuario? yo;
  final SalaInfo? sala;

  /// Último estado de la partida tal como lo manda el servidor (paso 6).
  final Map<String, dynamic>? partida;

  /// Se mandó crear/unirse y aún no hay respuesta.
  final bool esperando;
  final Aviso? aviso;

  const LobbyState({
    this.conexion = EstadoConexion.conectando,
    this.yo,
    this.sala,
    this.partida,
    this.esperando = false,
    this.aviso,
  });

  bool get conectado => conexion == EstadoConexion.conectado;
  JugadorEnSala? get miJugador => yo == null ? null : sala?.jugador(yo!.id);

  LobbyState copyWith({
    EstadoConexion? conexion,
    Usuario? yo,
    SalaInfo? Function()? sala,
    Map<String, dynamic>? Function()? partida,
    bool? esperando,
    Aviso? aviso,
  }) => LobbyState(
    conexion: conexion ?? this.conexion,
    yo: yo ?? this.yo,
    sala: sala != null ? sala() : this.sala,
    partida: partida != null ? partida() : this.partida,
    esperando: esperando ?? this.esperando,
    aviso: aviso ?? this.aviso,
  );
}

// ---------------------------------------------------------------------------
// Bloc
// ---------------------------------------------------------------------------

/// Estado del lobby multijugador. Todo lo que muestra la pantalla sale de los
/// mensajes del servidor: la app nunca "adivina" el estado de la sala, así
/// después de una reconexión queda igual que lo ve el resto.
class LobbyBloc extends Bloc<LobbyEvent, LobbyState> {
  final ConexionMultijugador conexion;
  final List<StreamSubscription<dynamic>> _subs = [];
  int _avisos = 0;

  LobbyBloc(this.conexion) : super(const LobbyState()) {
    on<LobbyIniciado>(_alIniciar);
    on<LobbyCrearSala>((e, emit) => _pedir(emit, {'tipo': 'crear_sala', 'nivel': e.nivel}, esperar: true));
    on<LobbyUnirse>((e, emit) => _pedir(
      emit,
      {'tipo': 'unirse', 'codigo': e.codigo.trim().toUpperCase(), 'nivel': e.nivel},
      esperar: true,
    ));
    on<LobbyElegirMapa>((e, emit) => _pedir(emit, {'tipo': 'elegir_mapa', 'nivel': e.nivel}));
    on<LobbyListo>((e, emit) => _pedir(emit, {'tipo': 'listo', 'listo': e.listo}));
    on<LobbySalir>(_alSalir);
    on<LobbyReconectar>((_, _) => conexion.reconectarAhora());
    on<_ConexionCambio>(_alCambiarConexion);
    on<_MensajeRecibido>(_alRecibir);
  }

  void _alIniciar(LobbyIniciado e, Emitter<LobbyState> emit) {
    if (_subs.isNotEmpty) return;
    _subs
      ..add(conexion.estados.listen((s) => add(_ConexionCambio(s))))
      ..add(conexion.mensajes.listen((m) => add(_MensajeRecibido(m))));
    conexion.iniciar();
  }

  Aviso _aviso(String texto, {bool error = false}) => Aviso(++_avisos, texto, esError: error);

  void _pedir(Emitter<LobbyState> emit, Map<String, Object?> msg, {bool esperar = false}) {
    if (!conexion.enviar(msg)) {
      emit(state.copyWith(aviso: _aviso('Sin conexión con el servidor. Reintentando…', error: true)));
      return;
    }
    if (esperar) emit(state.copyWith(esperando: true));
  }

  void _alSalir(LobbySalir e, Emitter<LobbyState> emit) {
    if (state.sala == null) return;
    // Aunque no haya conexión se sale en la pantalla; el servidor lo sacará
    // al vencer el tiempo de gracia.
    conexion.enviar({'tipo': 'salir'});
    emit(state.copyWith(sala: () => null, partida: () => null, esperando: false));
  }

  void _alCambiarConexion(_ConexionCambio e, Emitter<LobbyState> emit) {
    emit(state.copyWith(conexion: e.estado, esperando: false));
  }

  void _alRecibir(_MensajeRecibido e, Emitter<LobbyState> emit) {
    final m = e.msg;
    try {
      switch (m['tipo']) {
        case 'autenticado':
          final sala = m['sala'];
          emit(state.copyWith(
            yo: Usuario.fromJson(m['user'] as Map<String, dynamic>),
            sala: () => sala == null ? null : SalaInfo.fromJson(sala as Map<String, dynamic>),
            partida: sala == null ? () => null : null,
          ));
        case 'sala' || 'partida_iniciada':
          final sala = SalaInfo.fromJson(m['sala'] as Map<String, dynamic>);
          final texto = m['tipo'] == 'partida_iniciada'
              ? '¡Todos listos! Empieza la partida.'
              : _textoEvento(m['evento']);
          emit(state.copyWith(
            sala: () => sala,
            partida: sala.enLobby ? () => null : null,
            esperando: false,
            aviso: texto == null ? null : _aviso(texto),
          ));
        case 'partida' || 'partida_terminada':
          emit(state.copyWith(partida: () => m['partida'] as Map<String, dynamic>?));
        case 'saliste':
          emit(state.copyWith(sala: () => null, partida: () => null, esperando: false));
        case 'error':
          emit(state.copyWith(
            esperando: false,
            aviso: _aviso(m['message'] as String? ?? 'Error del servidor.', error: true),
          ));
      }
    } on TypeError {
      // Mensaje con un formato inesperado: se ignora.
    }
  }

  /// Texto para los eventos de la sala de los demás (los propios no se avisan).
  String? _textoEvento(Object? evento) {
    if (evento is! Map) return null;
    final quien = evento['nametag'];
    if (quien is! String || quien == state.yo?.nametag) return null;
    return switch (evento['tipo']) {
      'unido' => '$quien se unió a la sala.',
      'salio' => '$quien salió de la sala.',
      'desconectado' => '$quien perdió la conexión.',
      'reconectado' => '$quien volvió.',
      'abandono' => '$quien no volvió y salió de la sala.',
      _ => null,
    };
  }

  @override
  Future<void> close() async {
    // Primero la conexión: su parte síncrona corta ya los reintentos y el ping.
    final cierre = conexion.cerrar();
    for (final s in _subs) {
      await s.cancel();
    }
    await cierre;
    return super.close();
  }
}
