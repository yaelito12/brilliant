import '../tablero.dart';

/// Estado de una partida en curso.
///
/// Flujo de un turno:
/// 1. Se tiran los dados ([dados]) y se calculan [anclasPosibles].
/// 2. Se elige qué dado es el número ancla ([valorAncla]); el otro es
///    el [numeroAColocar].
/// 3. Se toca una casilla con ese número ([ancla]) y se calculan los
///    [destinosPosibles] para [numeroAColocar].
/// 4. Se coloca el número en un destino ([numeroColocado] = true).
/// 5. "Siguiente" avanza el turno y se vuelven a tirar los dados.
class PartidaState {
  final bool iniciada;
  final Tablero? tablero;

  /// Número escrito en cada casilla (iniciales + colocados).
  final Map<Coordenada, int> celdas;

  /// Casillas con los valores iniciales elegidos antes de empezar.
  final Set<Coordenada> casillasIniciales;

  final int turno;

  /// Valores de los 2 dados del turno, o null si aún no se tiran.
  final List<int>? dados;

  /// Casillas con número igual a un dado que tienen al menos un destino válido.
  final Set<Coordenada> anclasPosibles;

  /// Valor del dado elegido como ancla (null si aún no se elige).
  final int? valorAncla;

  final Coordenada? ancla;

  /// Número que se colocará junto al ancla (el del otro dado).
  final int? numeroAColocar;

  /// Casillas vacías vecinas del ancla donde la zona acepta [numeroAColocar].
  final Set<Coordenada> destinosPosibles;

  /// true si ya se colocó un número en este turno.
  final bool numeroColocado;

  final Coordenada? ultimaColocada;

  /// Puntos obtenidos con la última jugada (0 si no completó ninguna zona).
  final int puntosUltimaJugada;

  final String mensaje;

  const PartidaState({
    this.iniciada = false,
    this.tablero,
    this.celdas = const {},
    this.casillasIniciales = const {},
    this.turno = 1,
    this.dados,
    this.anclasPosibles = const {},
    this.valorAncla,
    this.ancla,
    this.numeroAColocar,
    this.destinosPosibles = const {},
    this.numeroColocado = false,
    this.ultimaColocada,
    this.puntosUltimaJugada = 0,
    this.mensaje = '',
  });

  int get puntuacion => tablero?.puntuacion ?? 0;

  bool get terminada => tablero?.estaCompleto ?? false;

  PartidaState copyWith({
    bool? iniciada,
    Tablero? tablero,
    Map<Coordenada, int>? celdas,
    Set<Coordenada>? casillasIniciales,
    int? turno,
    List<int>? Function()? dados,
    Set<Coordenada>? anclasPosibles,
    int? Function()? valorAncla,
    Coordenada? Function()? ancla,
    int? Function()? numeroAColocar,
    Set<Coordenada>? destinosPosibles,
    bool? numeroColocado,
    Coordenada? Function()? ultimaColocada,
    int? puntosUltimaJugada,
    String? mensaje,
  }) {
    return PartidaState(
      iniciada: iniciada ?? this.iniciada,
      tablero: tablero ?? this.tablero,
      celdas: celdas ?? this.celdas,
      casillasIniciales: casillasIniciales ?? this.casillasIniciales,
      turno: turno ?? this.turno,
      dados: dados != null ? dados() : this.dados,
      anclasPosibles: anclasPosibles ?? this.anclasPosibles,
      valorAncla: valorAncla != null ? valorAncla() : this.valorAncla,
      ancla: ancla != null ? ancla() : this.ancla,
      numeroAColocar: numeroAColocar != null ? numeroAColocar() : this.numeroAColocar,
      destinosPosibles: destinosPosibles ?? this.destinosPosibles,
      numeroColocado: numeroColocado ?? this.numeroColocado,
      ultimaColocada: ultimaColocada != null ? ultimaColocada() : this.ultimaColocada,
      puntosUltimaJugada: puntosUltimaJugada ?? this.puntosUltimaJugada,
      mensaje: mensaje ?? this.mensaje,
    );
  }
}
