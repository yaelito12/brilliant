import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:brilliant/bloc/juego_bloc.dart';
import 'package:brilliant/bloc/juego_event.dart';
import 'package:brilliant/bloc/juego_state.dart';

void main() {
  group('JuegoBloc', () {
    late JuegoBloc juegoBloc;

    setUp(() {
      juegoBloc = JuegoBloc();
    });

    tearDown(() {
      juegoBloc.close();
    });

    test('El estado inicial debe ser JuegoEsperandoValores', () {
      expect(juegoBloc.state, isA<JuegoEsperandoValores>());
    });

    blocTest<JuegoBloc, JuegoState>(
      'Emite error si intenta avanzar SIN valores iniciales',
      build: () => juegoBloc,
      act: (bloc) => bloc.add(IntentarAvanzar()),
      expect: () => [
        isA<JuegoEsperandoValores>().having(
          (state) => state.mensaje, 
          'mensaje', 
          contains('No puedes avanzar')
        ),
      ],
    );

    blocTest<JuegoBloc, JuegoState>(
      'Cambia a JuegoListo cuando se proporcionan los valores iniciales',
      build: () => juegoBloc,
      act: (bloc) => bloc.add(ValoresInicialesProporcionados()),
      expect: () => [
        isA<JuegoListo>(),
      ],
    );

    blocTest<JuegoBloc, JuegoState>(
      'Permite avanzar si los valores YA fueron proporcionados',
      build: () => juegoBloc,
      act: (bloc) {
        bloc.add(ValoresInicialesProporcionados());
        bloc.add(IntentarAvanzar());
      },
      skip: 1, // Saltamos el primer estado (JuegoListo) para solo comprobar el resultado de IntentarAvanzar
      expect: () => [
        isA<JuegoListo>().having(
          (state) => state.mensaje, 
          'mensaje', 
          contains('Avanzando al juego')
        ),
      ],
    );
  });
}

