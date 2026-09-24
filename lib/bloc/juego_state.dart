import '../tablero.dart';

abstract class JuegoState {
  final String mensaje;
  final Map<Coordenada, int> valoresIniciales;

  JuegoState(this.mensaje, this.valoresIniciales);
}

class JuegoEsperandoValores extends JuegoState {
  JuegoEsperandoValores([String mensaje = 'Esperando que se configuren los valores iniciales.', Map<Coordenada, int> valores = const {}]) 
      : super(mensaje, valores);
}

class JuegoListo extends JuegoState {
  JuegoListo([String mensaje = '¡Valores listos! Puedes empezar a jugar.', Map<Coordenada, int> valores = const {}]) 
      : super(mensaje, valores);
}
