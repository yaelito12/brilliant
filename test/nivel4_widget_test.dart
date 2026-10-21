// Widget tests para jugar el Nivel 4: elegirlo en el selector, cómo se
// dibuja, el selector de números con las zonas naranjas (1-3 y 4-6) y una
// partida corta en las filas naranjas.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brilliant/nivel4.dart';
import 'package:brilliant/tablero.dart';
import 'package:brilliant/tablero_ui.dart';
import 'package:brilliant/tipo.dart';

import 'helpers/widget_helpers.dart';

const _arriba = Coordenada(0, 4); // naranja 4-6
const _abajo = Coordenada(6, 1); // naranja 1-3

final _iniciales = {
  _arriba: 5,
  const Coordenada(2, 2): 4,
  const Coordenada(2, 5): 6,
  const Coordenada(3, 0): 1,
  const Coordenada(5, 4): 2,
  _abajo: 3,
};

Future<void> _ponerIniciales(WidgetTester tester) async {
  for (final MapEntry(key: c, value: n) in _iniciales.entries) {
    await ponerNumeroEn(tester, c, n);
  }
}

Finder enHoja(Finder f) =>
    find.descendant(of: find.byType(BottomSheet), matching: f);

/// Botones de número de la hoja que están en gris (no se pueden elegir).
Finder numerosBloqueados() => find.byWidgetPredicate((w) {
      if (w is! Container) return false;
      final d = w.decoration;
      return d is BoxDecoration &&
          d.color == Colors.grey.shade300 &&
          w.constraints?.maxWidth == 44;
    });

/// Números de la hoja que se ven en gris, ej. {1, 2, 3}.
Set<int> valoresBloqueados(WidgetTester tester) {
  return {
    for (final e in numerosBloqueados().evaluate())
      int.parse((tester.widget<Text>(find.descendant(
        of: find.byWidget(e.widget),
        matching: find.byType(Text),
      ))).data!),
  };
}

void main() {
  group('Elegir el Nivel 4', () {
    testWidgets('el selector muestra los 4 mapas oficiales', (tester) async {
      await abrirApp(tester);
      await abrirSelector(tester);

      expect(find.byType(MiniMapa), findsNWidgets(4));
      for (var n = 1; n <= 4; n++) {
        expect(enDialogo(find.text('Nivel $n')), findsOneWidget);
      }
    });

    testWidgets('al elegirlo la barra muestra "Nivel 4"', (tester) async {
      await abrirMapa(tester, 'Nivel 4');

      expect(nivelEnBarra(tester), 'Nivel 4');
    });

    testWidgets('se puede elegir en pantalla angosta (desplazando)', (
      tester,
    ) async {
      await abrirMapa(tester, 'Nivel 4', tamano: pantallaAngosta);

      expect(nivelEnBarra(tester), 'Nivel 4');
      expect(tester.takeException(), isNull);
    });
  });

  group('Tablero del Nivel 4', () {
    testWidgets('pinta cada casilla con el color de su zona', (tester) async {
      await abrirMapa(tester, 'Nivel 4');

      expect(celdasDeColor(colorDeTipo(TipoNaranjaAlto())), findsNWidgets(14));
      expect(celdasDeColor(colorDeTipo(TipoAmarillo())), findsNWidgets(6));
      expect(celdasDeColor(colorDeTipo(TipoAzul())), findsNWidgets(6));
      expect(celdasDeColor(colorDeTipo(TipoVerde())), findsNWidgets(4));
      expect(celdasDeColor(colorDeTipo(TipoMorado())), findsNWidgets(7));
      expect(celdasDeColor(colorDeTipo(TipoRojo())), findsNWidgets(12));
    });

    testWidgets('los chips muestran los puntos del nivel 4', (tester) async {
      await abrirMapa(tester, 'Nivel 4');

      expect(find.text('+8'), findsNWidgets(2)); // amarillo y azul
      expect(find.text('+7'), findsOneWidget); // morado
      expect(find.text('+6'), findsNWidgets(3)); // rojo y las 2 naranjas
      expect(find.text('+3'), findsOneWidget); // verde
      expect(find.text('0/2'), findsOneWidget); // rojo
      expect(find.text('0/1'), findsNWidgets(6));
    });

    testWidgets('cada naranja tiene su ayuda con su rango', (tester) async {
      await abrirMapa(tester, 'Nivel 4');

      expect(
        find.byTooltip('Naranja 1-3: Solo números del 1 al 3\n'
            'Puntos por zona: 1º 6 · 2º 4 · 3º 3'),
        findsOneWidget,
      );
      expect(
        find.byTooltip('Naranja 4-6: Solo números del 4 al 6\n'
            'Puntos por zona: 1º 6 · 2º 4 · 3º 3'),
        findsOneWidget,
      );
    });

    testWidgets('las Reglas explican las dos naranjas', (tester) async {
      await abrirMapa(tester, 'Nivel 4');
      await pulsar(tester, 'Reglas');

      expect(find.textContaining('Naranja 1-3: Solo números del 1 al 3'),
          findsOneWidget);
      expect(find.textContaining('Naranja 4-6: Solo números del 4 al 6'),
          findsOneWidget);
    });
  });

  group('Números iniciales en las naranjas', () {
    testWidgets('en la naranja 4-6 el 1, 2 y 3 salen en gris', (
      tester,
    ) async {
      await abrirMapa(tester, 'Nivel 4');
      await tocarCelda(tester, _arriba);

      expect(valoresBloqueados(tester), {1, 2, 3});
      expect(enHoja(find.text('Zona naranja 4-6: solo números del 4 al 6')),
          findsOneWidget);
    });

    testWidgets('en la naranja 1-3 el 4, 5 y 6 salen en gris', (
      tester,
    ) async {
      await abrirMapa(tester, 'Nivel 4');
      await tocarCelda(tester, _abajo);

      expect(valoresBloqueados(tester), {4, 5, 6});
      expect(enHoja(find.text('Zona naranja 1-3: solo números del 1 al 3')),
          findsOneWidget);
    });

    testWidgets('tocar un número fuera del rango no lo pone', (tester) async {
      await abrirMapa(tester, 'Nivel 4');
      await tocarCelda(tester, _arriba);
      await tester.tap(enHoja(find.text('2')));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(textoEnTablero('2'), findsNothing);
      expect(find.textContaining('Faltan 6.'), findsOneWidget);
    });

    testWidgets('con el teclado tampoco se puede poner fuera del rango', (
      tester,
    ) async {
      await abrirMapa(tester, 'Nivel 4');
      await tocarCelda(tester, _abajo);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit6);
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(textoEnTablero('6'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(textoEnTablero('2'), findsOneWidget);
    });

    testWidgets('un número dentro del rango sí se pone', (tester) async {
      await abrirMapa(tester, 'Nivel 4');
      await ponerNumeroEn(tester, _arriba, 5);

      expect(textoEnTablero('5'), findsOneWidget);
      expect(find.textContaining('Faltan 5.'), findsOneWidget);
    });

    testWidgets('se suman los números ya usados y los fuera de rango', (
      tester,
    ) async {
      await abrirMapa(tester, 'Nivel 4');
      await ponerNumeroEn(tester, const Coordenada(2, 2), 2);
      await tocarCelda(tester, _abajo);

      expect(valoresBloqueados(tester), {2, 4, 5, 6});
    });

    testWidgets('las zonas sin rango no muestran aviso ni bloquean', (
      tester,
    ) async {
      await abrirMapa(tester, 'Nivel 4');
      await tocarCelda(tester, const Coordenada(2, 2));

      expect(numerosBloqueados(), findsNothing);
      expect(enHoja(find.textContaining('Zona ')), findsNothing);
    });

    testWidgets('en el Nivel 1 la hoja no muestra aviso de zona', (
      tester,
    ) async {
      await abrirApp(tester);
      await tocarCelda(tester, casillasIniciales().first);

      expect(enHoja(find.textContaining('Zona ')), findsNothing);
    });

    testWidgets('con los 6 números se puede comenzar', (tester) async {
      await abrirMapa(tester, 'Nivel 4');
      await _ponerIniciales(tester);
      await pulsar(tester, 'Comenzar juego');

      final partida = partidaBloc(tester).state;
      expect(partida.iniciada, isTrue);
      expect(partida.celdas, _iniciales);
      expect(partida.casillasIniciales, casillasInicialesNivel4);
    });
  });

  group('Partida en el Nivel 4', () {
    testWidgets('las filas naranjas solo aceptan números de su rango', (
      tester,
    ) async {
      // Turno 1: 5 y 2. Turno 2: 5 y 6. Turno 3: 3 y 5. Luego de sobra.
      await abrirMapa(tester, 'Nivel 4', dados: [5, 2, 5, 6, 3, 5, 1, 1]);
      await _ponerIniciales(tester);
      await pulsar(tester, 'Comenzar juego');
      await tirarDados(tester);

      // El 2 no puede ir a la fila de arriba: solo a la azul de abajo
      await tocarCelda(tester, _arriba);
      expect(partidaBloc(tester).state.destinosPosibles,
          {const Coordenada(1, 4)});

      await asentar(tester);
      await pulsar(tester, 'Siguiente');
      await pulsar(tester, 'Sí, pasar');
      await asentar(tester);

      // El 6 sí entra en la fila de arriba
      await tocarCelda(tester, _arriba);
      expect(partidaBloc(tester).state.destinosPosibles,
          containsAll([const Coordenada(0, 3), const Coordenada(0, 5)]));
      await tocarCelda(tester, const Coordenada(0, 5));
      expect(textoEnTablero('6'), findsNWidgets(2));
      expect(partidaBloc(tester).state.tablero!.zonas['na']!.valores, [5, 6]);
      await asentar(tester);

      // El 5 no puede ir a la fila de abajo (1-3): solo a la roja
      await tocarCelda(tester, _abajo);
      final partida = partidaBloc(tester).state;
      expect(partida.numeroAColocar, 5);
      expect(partida.destinosPosibles, {const Coordenada(5, 1)});
      await asentar(tester);
    });
  });
}
