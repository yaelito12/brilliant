import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:brilliant_reglas/brilliant_reglas.dart';

import '../auth/auth_models.dart';
import '../sonidos.dart' show Sonido;
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
  /// Basta el código: se juega el mapa que eligió quien creó la sala.
  final String codigo;
  LobbyUnirse(this.codigo);
}

class LobbyElegirMapa extends LobbyEvent {
  final int nivel;
  LobbyElegirMapa(this.nivel);
}

/// Solo el anfitrión: segundos por ronda, o 0 para jugar sin reloj.
class LobbyElegirTiempo extends LobbyEvent {
  final int segundos;
  LobbyElegirTiempo(this.segundos);
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

/// Qué clase de aviso es: cambia el color y el ícono con que se muestra.
enum TipoAviso { info, exito, alerta, error }

/// Mensaje para mostrar una sola vez (notificación flotante). [id] cambia
/// con cada uno.
class Aviso {
  final int id;
  final String texto;
  final TipoAviso tipo;
  const Aviso(this.id, this.texto, {this.tipo = TipoAviso.info});

  bool get esError => tipo == TipoAviso.error;
}

/// Segundos que se espera a quien pierde la conexión en plena partida, si el
/// servidor no los dice (es lo que trae el evento `desconectado`). Pasado ese
/// tiempo sin volver, pierde y queda fuera.
const graciaReconexionPorDefecto = 10;

/// Efecto de sonido para tocar una sola vez. [id] cambia con cada uno.
class EfectoSonido {
  final int id;
  final Sonido sonido;
  const EfectoSonido(this.id, this.sonido);
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

  /// Efecto de sonido pendiente de tocar (una sola vez).
  final EfectoSonido? sonido;

  /// Hasta cuándo se espera a cada jugador que perdió la conexión en plena
  /// partida (nametag → límite, según el reloj de este dispositivo). Mientras
  /// haya alguno, la ronda está en pausa: a nadie se le pasan los turnos.
  final Map<String, DateTime> esperaReconexion;

  const LobbyState({
    this.conexion = EstadoConexion.conectando,
    this.yo,
    this.sala,
    this.partida,
    this.resultados,
    this.esperando = false,
    this.aviso,
    this.sonido,
    this.esperaReconexion = const {},
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
    EfectoSonido? sonido,
    Map<String, DateTime>? esperaReconexion,
  }) => LobbyState(
    conexion: conexion ?? this.conexion,
    yo: yo ?? this.yo,
    sala: sala != null ? sala() : this.sala,
    partida: partida != null ? partida() : this.partida,
    resultados: resultados != null ? resultados() : this.resultados,
    esperando: esperando ?? this.esperando,
    aviso: aviso ?? this.aviso,
    sonido: sonido ?? this.sonido,
    esperaReconexion: esperaReconexion ?? this.esperaReconexion,
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
  int _sonidos = 0;

  LobbyBloc(this.conexion) : super(const LobbyState()) {
    on<LobbyIniciado>(_alIniciar);
    on<LobbyCrearSala>((e, emit) => _pedir(emit, {'tipo': 'crear_sala', 'nivel': e.nivel}, esperar: true));
    on<LobbyUnirse>((e, emit) => _pedir(
      emit,
      {'tipo': 'unirse', 'codigo': e.codigo.trim().toUpperCase()},
      esperar: true,
    ));
    on<LobbyElegirMapa>((e, emit) => _pedir(emit, {'tipo': 'elegir_mapa', 'nivel': e.nivel}));
    on<LobbyElegirTiempo>((e, emit) =>
        _pedir(emit, {'tipo': 'elegir_tiempo', 'segundos': e.segundos}));
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

  Aviso _aviso(String texto, {TipoAviso tipo = TipoAviso.info}) =>
      Aviso(++_avisos, texto, tipo: tipo);

  EfectoSonido _sonar(Sonido s) => EfectoSonido(++_sonidos, s);

  void _pedir(Emitter<LobbyState> emit, Map<String, Object?> msg, {bool esperar = false}) {
    if (!conexion.enviar(msg)) {
      emit(state.copyWith(
        aviso: _aviso('Sin conexión con el servidor. Reintentando…', tipo: TipoAviso.error),
      ));
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
    esperaReconexion: const {},
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
          final aviso = iniciada
              ? _aviso('¡Todos listos! Empieza la partida.', tipo: TipoAviso.exito)
              : _avisoEvento(m['evento']);
          emit(state.copyWith(
            sala: () => sala,
            partida: sala.enLobby ? () => null : null,
            resultados: iniciada ? () => null : null,
            esperando: false,
            aviso: aviso,
          ));
        case 'partida':
          final partida = PartidaInfo.fromJson(m['partida'] as Map<String, dynamic>);
          final (aviso, sonido) = _avisoEventoPartida(m['evento'], partida);
          emit(state.copyWith(
            partida: () => partida,
            esperando: false,
            aviso: aviso,
            sonido: sonido == null ? null : _sonar(sonido),
            esperaReconexion: _esperas(m['evento'], partida),
          ));
        case 'partida_terminada':
          emit(state.copyWith(
            partida: () => PartidaInfo.fromJson(m['partida'] as Map<String, dynamic>),
            resultados: () => ResultadosPartida.fromJson(m),
            esperando: false,
            sonido: _sonar(Sonido.victoria),
            esperaReconexion: const {},
          ));
        case 'saliste':
          emit(_fueraDeSala());
        case 'error':
          emit(state.copyWith(
            esperando: false,
            aviso: _aviso(
              m['message'] as String? ?? 'Error del servidor.',
              tipo: TipoAviso.error,
            ),
          ));
      }
    } on TypeError {
      // Mensaje con un formato inesperado: se ignora.
    }
  }

  /// Aviso para los eventos de la sala de los demás (los propios no se avisan).
  Aviso? _avisoEvento(Object? evento) {
    if (evento is! Map) return null;
    final quien = evento['nametag'];
    if (quien is! String || quien == state.yo?.nametag) return null;
    final gracia = evento['graciaSegundos'];
    final (texto, tipo) = switch (evento['tipo']) {
      'unido' => ('$quien se unió a la sala.', TipoAviso.info),
      'salio' => ('$quien salió de la sala.', TipoAviso.info),
      'desconectado' => (
        gracia is int
            ? '$quien perdió la conexión. Tiene $gracia s para volver…'
            : '$quien perdió la conexión.',
        TipoAviso.alerta,
      ),
      'reconectado' => ('$quien volvió.', TipoAviso.exito),
      'abandono' => ('$quien no volvió y salió de la sala.', TipoAviso.alerta),
      _ => (null, TipoAviso.info),
    };
    return texto == null ? null : _aviso(texto, tipo: tipo);
  }

  /// A quién se está esperando porque perdió la conexión, y hasta cuándo.
  ///
  /// La cuenta atrás empieza cuando llega el evento `desconectado` (el
  /// servidor manda cuántos segundos de gracia da) y se borra en cuanto el
  /// jugador vuelve, se rinde, abandona o ya no está en la partida. Mientras
  /// haya alguien en la lista, la ronda no avanza: nadie pasa de turno solo.
  Map<String, DateTime> _esperas(Object? evento, PartidaInfo partida) {
    final esperas = {...state.esperaReconexion};
    if (evento is Map && evento['nametag'] is String) {
      final quien = evento['nametag'] as String;
      switch (evento['tipo']) {
        case 'desconectado':
          final gracia = evento['graciaSegundos'];
          esperas[quien] = DateTime.now().add(
            Duration(
              seconds: gracia is int ? gracia : graciaReconexionPorDefecto,
            ),
          );
        case 'reconectado' || 'abandono' || 'concedio':
          esperas.remove(quien);
      }
    }
    // Solo los que siguen jugando y siguen sin conexión (así, tras una
    // reconexión propia, la lista queda como la ve el servidor).
    esperas.removeWhere(
      (nametag, _) => !partida.jugadores.any(
        (j) => j.nametag == nametag && j.activo && !j.conectado && !j.completo,
      ),
    );
    return esperas;
  }

  /// Nombre del color de la zona [id] en el mapa del nivel [nivel].
  String _nombreZona(int nivel, String id) {
    final tipo = nivelPorNumero(nivel)?.construirTablero().zonas[id]?.tipo;
    return switch (tipo) {
      TipoVerde() => 'verde',
      TipoAzul() => 'azul',
      TipoRojo() => 'roja',
      TipoAmarillo() => 'amarilla',
      TipoMorado() => 'morada',
      TipoGris() => 'gris',
      TipoNaranja(:final minimo, :final maximo) => 'naranja $minimo-$maximo',
      _ => id,
    };
  }

  String _ordinal(Object? lugar) => lugar is int ? '$lugar.º' : '';

  /// Aviso y sonido durante la partida: zonas que se llenan (propias y
  /// ajenas, con sus puntos), desconexiones con su cuenta atrás, abandonos
  /// y rendiciones.
  (Aviso?, Sonido?) _avisoEventoPartida(Object? evento, PartidaInfo partida) {
    if (evento is! Map) return (null, null);
    final quien = evento['nametag'];
    final soyYo = quien == state.yo?.nametag;
    switch (evento['tipo']) {
      case 'jugada':
        final puntos = evento['puntosGanados'];
        final zonas = evento['zonas'];
        final llenoZona = zonas is List && zonas.isNotEmpty;

        String? texto;
        if (llenoZona) {
          final nivel = quien is String
              ? partida.jugadores
                    .where((j) => j.nametag == quien)
                    .map((j) => j.nivel)
                    .firstOrNull
              : null;
          final detalle = [
            for (final z in zonas.whereType<Map>())
              '${nivel == null ? z['zona'] : _nombreZona(nivel, z['zona'] as String)}'
                  ' (${_ordinal(z['lugar'])} lugar, +${z['puntos']})',
          ].join(' y ');
          texto = soyYo
              ? '¡Llenaste la zona $detalle! Ganaste $puntos puntos.'
              : '$quien llenó la zona $detalle y recibió $puntos puntos.';
        }
        if (evento['completo'] == true) {
          final fin = soyYo
              ? '¡Completaste tu tablero! La partida termina al acabar la ronda.'
              : '$quien completó su tablero: esta es la última ronda.';
          texto = texto == null ? fin : '$texto $fin';
        }
        if (texto == null) return (null, null);
        return (
          _aviso(texto, tipo: TipoAviso.exito),
          llenoZona ? Sonido.zona : null,
        );
      case 'ronda':
        final pasaron = evento['pasaronPorTiempo'];
        if (pasaron is List && pasaron.contains(state.yo?.nametag)) {
          return (
            _aviso(
              'Se acabó el tiempo: pasaste la ronda ${partida.ronda - 1}.',
              tipo: TipoAviso.alerta,
            ),
            null,
          );
        }
        return (null, null);
      case 'desconectado' when !soyYo:
        final gracia = evento['graciaSegundos'];
        final cuanto = gracia is int ? '$gracia segundos' : 'unos segundos';
        return (
          _aviso(
            '$quien se salió del juego. A nadie se le pasan los turnos: la '
                'partida queda en pausa $cuanto esperando a que vuelva. Si no '
                'vuelve, pierde y queda fuera.',
            tipo: TipoAviso.alerta,
          ),
          null,
        );
      case 'reconectado' when !soyYo:
        return (_aviso('$quien volvió. ¡Sigue la partida!', tipo: TipoAviso.exito), null);
      case 'concedio':
        return (
          _aviso(
            soyYo ? 'Te rendiste. Puedes seguir viendo la partida.' : '$quien se rindió.',
            tipo: TipoAviso.alerta,
          ),
          Sonido.abandono,
        );
      case 'abandono' when !soyYo:
        return (
          _aviso(
            '$quien no volvió a tiempo: pierde y queda fuera de la partida.',
            tipo: TipoAviso.alerta,
          ),
          Sonido.abandono,
        );
    }
    return (null, null);
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
