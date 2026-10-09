import '../tablero.dart';

abstract class PartidaEvent {}

/// Arranca la partida con el tablero vacío y los 6 valores iniciales
/// que eligió el jugador. Los dados empiezan sin tirar.
class PartidaIniciada extends PartidaEvent {
  final Tablero tablero;
  final Map<Coordenada, int> valoresIniciales;

  PartidaIniciada(this.tablero, this.valoresIniciales);
}

/// El jugador tira los 2 dados del primer turno.
class DadosLanzados extends PartidaEvent {}

/// El jugador elige cuál de los 2 dados usa como número ancla;
/// el otro dado será el número a colocar.
class ValorAnclaElegido extends PartidaEvent {
  final int valor;

  ValorAnclaElegido(this.valor);
}

/// El jugador toca una casilla con número para usarla como ancla.
/// Si la casilla ya era el ancla seleccionada, se deselecciona.
class AnclaSeleccionada extends PartidaEvent {
  final Coordenada coordenada;

  AnclaSeleccionada(this.coordenada);
}

/// El jugador coloca el otro número en una casilla marcada.
class NumeroColocado extends PartidaEvent {
  final Coordenada coordenada;

  NumeroColocado(this.coordenada);
}

/// Avanza al siguiente turno (con o sin haber colocado número)
/// y se vuelven a tirar los dados.
class SiguienteTurno extends PartidaEvent {}
