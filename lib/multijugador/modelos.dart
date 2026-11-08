/// Datos del lobby tal como los manda el servidor (ver server/MULTIJUGADOR.md).
library;

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
  int get listos => jugadores.where((j) => j.listo).length;

  JugadorEnSala? jugador(String id) {
    for (final j in jugadores) {
      if (j.id == id) return j;
    }
    return null;
  }
}
