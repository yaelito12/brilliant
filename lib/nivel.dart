import 'tablero.dart';

/// Un mapa oficial del juego: su tablero vacío y las 6 casillas donde el
/// jugador pone los números iniciales antes de empezar.
class Nivel {
  final int numero;

  /// Crea el tablero vacío del nivel (uno nuevo en cada partida).
  final Tablero Function() construirTablero;

  final Set<Coordenada> casillasIniciales;

  const Nivel({
    required this.numero,
    required this.construirTablero,
    required this.casillasIniciales,
  });

  String get nombre => 'Nivel $numero';
}
