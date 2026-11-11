/// Datos del lobby y de la partida tal como los manda el servidor
/// (ver MULTIJUGADOR.md en brilliant_server).
library;

import 'package:brilliant_reglas/brilliant_reglas.dart';

class JugadorEnSala {
  final String id;
  final String nametag;
  final int nivel;
  final bool listo;
  final bool conectado;

  const JugadorEnSala({
    required this.id,
    required this.nametag,
    required this.nivel,
    required this.listo,
    required this.conectado,
  });

  factory JugadorEnSala.fromJson(Map<String, dynamic> j) => JugadorEnSala(
    id: j['id'] as String,
    nametag: j['nametag'] as String,
    nivel: j['nivel'] as int,
    listo: j['listo'] as bool? ?? false,
    conectado: j['conectado'] as bool? ?? true,
  );
}

class SalaInfo {
  final String codigo;

  /// `lobby` o `jugando`.
  final String estado;
  final int minJugadores;
  final int maxJugadores;
  final List<JugadorEnSala> jugadores;

  const SalaInfo({
    required this.codigo,
    required this.estado,
    required this.minJugadores,
    required this.maxJugadores,
    required this.jugadores,
  });

  factory SalaInfo.fromJson(Map<String, dynamic> j) => SalaInfo(
    codigo: j['codigo'] as String,
    estado: j['estado'] as String,
    minJugadores: j['minJugadores'] as int,
    maxJugadores: j['maxJugadores'] as int,
    jugadores: [
      for (final x in j['jugadores'] as List) JugadorEnSala.fromJson(x as Map<String, dynamic>),
    ],
  );

  bool get enLobby => estado == 'lobby';
  bool get jugando => estado == 'jugando';
  bool get llena => jugadores.length >= maxJugadores;

  /// Quien creó la sala (el primero): es el único que puede cambiar el mapa.
  JugadorEnSala? get anfitrion => jugadores.isEmpty ? null : jugadores.first;

  /// Mapa de la sala: todos juegan el mismo.
  int? get nivel => anfitrion?.nivel;
  int get listos => jugadores.where((j) => j.listo).length;

  JugadorEnSala? jugador(String id) {
    for (final j in jugadores) {
      if (j.id == id) return j;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Partida
// ---------------------------------------------------------------------------

class JugadorPartidaInfo {
  final String id;
  final String nametag;
  final int nivel;

  /// `jugando`, `concedio` o `abandono`.
  final String estado;
  final bool conectado;

  /// Ya jugó (o pasó) esta ronda; en la fase de iniciales: ya los puso.
  final bool yaJugo;
  final int puntos;
  final bool completo;
  final Map<Coordenada, int> celdas;

  /// Lugar en que completó cada zona (1 = primero).
  final Map<String, int> lugares;

  const JugadorPartidaInfo({
    required this.id,
    required this.nametag,
    required this.nivel,
    required this.estado,
    required this.conectado,
    required this.yaJugo,
    required this.puntos,
    required this.completo,
    required this.celdas,
    required this.lugares,
  });

  factory JugadorPartidaInfo.fromJson(Map<String, dynamic> j) => JugadorPartidaInfo(
    id: j['id'] as String,
    nametag: j['nametag'] as String,
    nivel: j['nivel'] as int,
    estado: j['estado'] as String,
    conectado: j['conectado'] as bool,
    yaJugo: j['yaJugo'] as bool,
    puntos: j['puntos'] as int,
    completo: j['completo'] as bool,
    celdas: {
      for (final c in j['celdas'] as List)
        Coordenada((c as List)[0] as int, c[1] as int): c[2] as int,
    },
    lugares: (j['lugares'] as Map).map((k, v) => MapEntry(k as String, v as int)),
  );

  bool get activo => estado == 'jugando';
  Nivel? get mapa => nivelPorNumero(nivel);

  /// Tablero con los números que tiene ahora. Las reglas de las zonas no
  /// dependen del orden, así que se pueden aplicar en cualquier orden.
  Tablero tablero() {
    var t = mapa!.construirTablero();
    celdas.forEach((c, n) => t = t.agregarNumero(c, n));
    return t;
  }
}

class PartidaInfo {
  /// `iniciales`, `jugando` o `terminada`.
  final String fase;
  final int ronda;
  final int maxRondas;

  /// Puntos con los que se gana (depende de cuántos jugadores empezaron).
  final int puntosMeta;
  final List<int>? dados;

  /// Cuándo se acaba el turno (o el tiempo para los iniciales), según el
  /// reloj de este dispositivo.
  final DateTime? limite;
  final List<JugadorPartidaInfo> jugadores;

  const PartidaInfo({
    required this.fase,
    required this.ronda,
    required this.maxRondas,
    required this.puntosMeta,
    required this.dados,
    required this.limite,
    required this.jugadores,
  });

  /// [recibido] es cuándo llegó el mensaje: el servidor manda los
  /// milisegundos que faltan (no una hora) para no depender de que los
  /// relojes estén sincronizados.
  factory PartidaInfo.fromJson(Map<String, dynamic> j, {DateTime? recibido}) {
    final ms = j['msRestantes'] as int?;
    return PartidaInfo(
      fase: j['fase'] as String,
      ronda: j['ronda'] as int,
      maxRondas: j['maxRondas'] as int,
      puntosMeta: j['puntosMeta'] as int,
      dados: (j['dados'] as List?)?.cast<int>(),
      limite: ms == null ? null : (recibido ?? DateTime.now()).add(Duration(milliseconds: ms)),
      jugadores: [
        for (final x in j['jugadores'] as List)
          JugadorPartidaInfo.fromJson(x as Map<String, dynamic>),
      ],
    );
  }

  bool get enIniciales => fase == 'iniciales';
  bool get jugando => fase == 'jugando';
  bool get terminada => fase == 'terminada';

  JugadorPartidaInfo? jugador(String id) {
    for (final j in jugadores) {
      if (j.id == id) return j;
    }
    return null;
  }

  /// Jugadores que todavía tienen que jugar esta ronda.
  int get faltan => jugadores.where((j) => j.activo && !j.yaJugo && !j.completo).length;

  /// Lugares (1º, 2º, 3º…) ya tomados en cada zona por cualquier jugador.
  /// Sirve para ir tachando esos puntos en las reglas de los lados del
  /// tablero de todos.
  Map<String, Set<int>> get lugaresOcupados {
    final ocupados = <String, Set<int>>{};
    for (final j in jugadores) {
      j.lugares.forEach((zona, lugar) {
        ocupados.putIfAbsent(zona, () => {}).add(lugar);
      });
    }
    return ocupados;
  }
}

class ResultadoInfo {
  final String id;
  final String nametag;
  final int nivel;
  final int puntos;
  final String estado;
  final int posicion;

  const ResultadoInfo({
    required this.id,
    required this.nametag,
    required this.nivel,
    required this.puntos,
    required this.estado,
    required this.posicion,
  });

  factory ResultadoInfo.fromJson(Map<String, dynamic> j) => ResultadoInfo(
    id: j['id'] as String,
    nametag: j['nametag'] as String,
    nivel: j['nivel'] as int,
    puntos: j['puntos'] as int,
    estado: j['estado'] as String,
    posicion: j['posicion'] as int,
  );
}

/// Clasificación final de una partida.
class ResultadosPartida {
  /// `meta_puntos`, `tablero_completo`, `max_rondas`, `rendicion` o `abandono`.
  final String motivo;
  final List<ResultadoInfo> lista;

  const ResultadosPartida({required this.motivo, required this.lista});

  factory ResultadosPartida.fromJson(Map<String, dynamic> m) => ResultadosPartida(
    motivo: m['motivo'] as String,
    lista: [
      for (final r in m['resultados'] as List) ResultadoInfo.fromJson(r as Map<String, dynamic>),
    ],
  );

  ResultadoInfo? de(String id) {
    for (final r in lista) {
      if (r.id == id) return r;
    }
    return null;
  }
}
