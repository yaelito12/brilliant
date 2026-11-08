import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:brilliant_reglas/brilliant_reglas.dart' show Coordenada;

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

/// Los 6 números iniciales de mi tablero.
class LobbyIniciales extends LobbyEvent {
  final Map<Coordenada, int> valores;
  LobbyIniciales(this.valores);
}

class LobbyJugada extends LobbyEvent {
  final Coordenada ancla;
  final Coordenada destino;
  LobbyJugada(this.ancla, this.destino);
}

class LobbyPasar extends LobbyEvent {}

class LobbyConceder extends LobbyEvent {}

/// Cierra la tarjeta de resultados de la última partida.
class LobbyCerrarResultados extends LobbyEvent {}

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

  /// Partida en curso (o la que acaba de terminar), según el servidor.
  final PartidaInfo? partida;

  /// Clasificación de la última partida (se muestra al volver al lobby).
  final ResultadosPartida? resultados;

  /// Se mandó crear/unirse o una jugada y aún no hay respuesta.
  final bool esperando;
  final Aviso? aviso;

  const LobbyState({
    this.conexion = EstadoConexion.conectando,
    this.yo,
    this.sala,
    this.partida,
    this.resultados,
    this.esperando = false,
    this.aviso,
  });

  bool get conectado => conexion == EstadoConexion.conectado;
  JugadorEnSala? get miJugador => yo == null ? null : sala?.jugador(yo!.id);
  JugadorPartidaInfo? get yoEnPartida => yo == null ? null : partida?.jugador(yo!.id);

  LobbyState copyWith({
    EstadoConexion? conexion,
    Usuario? yo,
    SalaInfo? Function()? sala,
    PartidaInfo? Function()? partida,
    ResultadosPartida? Function()? resultados,
    bool? esperando,
    Aviso? aviso,
  }) => LobbyState(
    conexion: conexion ?? this.conexion,
    yo: yo ?? this.yo,
    sala: sala != null ? sala() : this.sala,
    partida: partida != null ? partida() : this.partida,
    resultados: resultados != null ? resultados() : this.resultados,
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
    on<LobbyIniciales>((e, emit) => _pedir(
      emit,
      {
        'tipo': 'iniciales',
        'valores': [
          for (final MapEntry(key: c, value: n) in e.valores.entries) [c.fila, c.columna, n],
        ],
      },
      esperar: true,
    ));
    on<LobbyJugada>((e, emit) => _pedir(
      emit,
      {
        'tipo': 'jugada',
        'ancla': [e.ancla.fila, e.ancla.columna],
        'destino': [e.destino.fila, e.destino.columna],
      },
      esperar: true,
    ));
    on<LobbyPasar>((_, emit) => _pedir(emit, {'tipo': 'pasar'}, esperar: true));
    on<LobbyConceder>((_, emit) => _pedir(emit, {'tipo': 'conceder'}));
    on<LobbyCerrarResultados>((_, emit) => emit(state.copyWith(resultados: () => null)));
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
    emit(_fueraDeSala());
  }

  LobbyState _fueraDeSala() => state.copyWith(
    sala: () => null,
    partida: () => null,
    resultados: () => null,
    esperando: false,
  );

  void _alCambiarConexion(_ConexionCambio e, Emitter<LobbyState> emit) {
    emit(state.copyWith(conexion: e.estado, esperando: false));
  }

  void _alRecibir(_MensajeRecibido e, Emitter<LobbyState> emit) {
    final m = e.msg;
    try {
      switch (m['tipo']) {
        case 'autenticado':
          final sala = m['sala'];
          final yo = Usuario.fromJson(m['user'] as Map<String, dynamic>);
          if (sala == null) {
            // Ya no está en ninguna sala (por ejemplo, tardó demasiado en volver).
            emit(_fueraDeSala().copyWith(yo: yo));
          } else {
            emit(state.copyWith(
              yo: yo,
              sala: () => SalaInfo.fromJson(sala as Map<String, dynamic>),
            ));
          }
        case 'sala' || 'partida_iniciada':
          final sala = SalaInfo.fromJson(m['sala'] as Map<String, dynamic>);
          final iniciada = m['tipo'] == 'partida_iniciada';
          final texto = iniciada ? '¡Todos listos! Empieza la partida.' : _textoEvento(m['evento']);
          emit(state.copyWith(
            sala: () => sala,
            partida: sala.enLobby ? () => null : null,
            resultados: iniciada ? () => null : null,
            esperando: false,
            aviso: texto == null ? null : _aviso(texto),
          ));
        case 'partida':
          final partida = PartidaInfo.fromJson(m['partida'] as Map<String, dynamic>);
          final texto = _textoEventoPartida(m['evento'], partida);
          emit(state.copyWith(
            partida: () => partida,
            esperando: false,
            aviso: texto == null ? null : _aviso(texto),
          ));
        case 'partida_terminada':
          emit(state.copyWith(
            partida: () => PartidaInfo.fromJson(m['partida'] as Map<String, dynamic>),
            resultados: () => ResultadosPartida.fromJson(m),
            esperando: false,
          ));
        case 'saliste':
          emit(_fueraDeSala());
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

  /// Avisos durante la partida: los puntos que gané, si se me acabó el
  /// tiempo y lo que les pasa a los demás (sin avisar cada jugada ajena,
  /// que con 6 jugadores serían demasiados).
  String? _textoEventoPartida(Object? evento, PartidaInfo partida) {
    if (evento is! Map) return null;
    final quien = evento['nametag'];
    final soyYo = quien == state.yo?.nametag;
    switch (evento['tipo']) {
      case 'jugada' when soyYo:
        final puntos = evento['puntosGanados'];
        if (evento['completo'] == true) {
          return '¡Completaste tu tablero! La partida termina al acabar la ronda.';
        }
        return puntos is int && puntos > 0 ? '¡Zona completada! +$puntos puntos.' : null;
      case 'jugada' when evento['completo'] == true:
        return '$quien completó su tablero: esta es la última ronda.';
      case 'ronda':
        final pasaron = evento['pasaronPorTiempo'];
        if (pasaron is List && pasaron.contains(state.yo?.nametag)) {
          return 'Se acabó el tiempo: pasaste la ronda ${partida.ronda - 1}.';
        }
        return null;
      case 'desconectado' when !soyYo:
        return '$quien perdió la conexión. Sus turnos se pasan solos.';
      case 'reconectado' when !soyYo:
        return '$quien volvió.';
      case 'concedio':
        return soyYo ? 'Te rendiste. Puedes seguir viendo la partida.' : '$quien se rindió.';
      case 'abandono' when !soyYo:
        return '$quien no volvió: abandonó la partida.';
    }
    return null;
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
