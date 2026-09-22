abstract class JuegoState {
  final String mensaje;
  JuegoState(this.mensaje);
}

class JuegoEsperandoValores extends JuegoState {
  JuegoEsperandoValores([super.mensaje = 'Esperando que se configuren los valores iniciales.']);
}

class JuegoListo extends JuegoState {
  JuegoListo([super.mensaje = '¡Valores listos! Puedes empezar a jugar.']);
}

