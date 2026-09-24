import 'package:bloc/bloc.dart';
import 'juego_event.dart';
import 'juego_state.dart';

class JuegoBloc extends Bloc<JuegoEvent, JuegoState> {
  JuegoBloc() : super(JuegoEsperandoValores()) {
    
    // Cuando el juego (o el tablero) nos avisa que ya se colocaron los valores iniciales
    on<ValoresInicialesProporcionados>((event, emit) {
      emit(JuegoListo());
    });

    on<ValoresInicialesIncompletos>((event, emit) {
      emit(JuegoEsperandoValores());
    });

    // Cuando el usuario intenta avanzar (ej. presionar un botón de "Jugar" o "Siguiente")
    on<IntentarAvanzar>((event, emit) {
      if (state is JuegoEsperandoValores) {
        // Bloqueamos el avance y mandamos un mensaje de error
        emit(JuegoEsperandoValores('No puedes avanzar. Aún faltan los valores iniciales.'));
      } else if (state is JuegoListo) {
        // Permitimos el avance
        emit(JuegoListo('Avanzando al juego...'));
      }
    });
  }
}
