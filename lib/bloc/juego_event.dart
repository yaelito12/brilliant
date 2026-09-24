import '../tablero.dart';

abstract class JuegoEvent {}

class ValoresInicialesActualizados extends JuegoEvent {
  final Map<Coordenada, int> valores;
  ValoresInicialesActualizados(this.valores);
}

class ValoresInicialesProporcionados extends JuegoEvent {}

class ValoresInicialesIncompletos extends JuegoEvent {}

class IntentarAvanzar extends JuegoEvent {}
