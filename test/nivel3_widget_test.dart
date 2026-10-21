// Widget tests para jugar el Nivel 3: elegirlo en el selector, cómo se
// dibuja, sus casillas iniciales y una partida corta en la fila azul.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brilliant/nivel3.dart';
import 'package:brilliant/tablero.dart';
import 'package:brilliant/tablero_ui.dart';
import 'package:brilliant/tipo.dart';

import 'helpers/widget_helpers.dart';

/// Números iniciales: el 4 queda en (4,1), al inicio de la fila azul.
final _iniciales = {
  const Coordenada(1, 2): 1,
  const Coordenada(1, 5): 2,
  const Coordenada(3, 3): 3,
  const Coordenada(4, 1): 4,
  const Coordenada(4, 6): 5,
  const Coordenada(6, 2): 6,
};

Future<void> _ponerIniciales(WidgetTester tester) async {
  for (final MapEntry(key: c, value: n) in _iniciales.entries) {
    await ponerNumeroEn(tester, c, n);
  }
}

void main() {
  group('Elegir el Nivel 3', () {
    testWidgets('aparece en el selector', (tester) async {
      await abrirApp(tester);
      await abrirSelector(tester);

      expect(enDialogo(find.text('Nivel 3')), findsOneWidget);
    });

    testWidgets('al elegirlo la barra muestra "Nivel 3"', (tester) async {
      await abrirMapa(tester, 'Nivel 3');

      expect(nivelEnBarra(tester), 'Nivel 3');
    });

    testWidgets('sin desbordes en pantalla angosta', (tester) async {
      await abrirMapa(tester, 'Nivel 3', tamano: pantallaAngosta);

      expect(nivelEnBarra(tester), 'Nivel 3');
      expect(tester.takeException(), isNull);
    });
  });

  group('Tablero del Nivel 3', () {
    testWidgets('pinta cada casilla con el color de su zona', (tester) async {
      await abrirMapa(tester, 'Nivel 3');

      expect(celdasDeColor(colorDeTipo(TipoAmarillo())), findsNWidgets(6));
      expect(celdasDeColor(colorDeTipo(TipoGris())), findsNWidgets(5));
      expect(celdasDeColor(colorDeTipo(TipoMorado())), findsNWidgets(12));
      expect(celdasDeColor(colorDeTipo(TipoRojo())), findsNWidgets(12));
      expect(celdasDeColor(colorDeTipo(TipoVerde())), findsNWidgets(9));
      expect(celdasDeColor(colorDeTipo(TipoAzul())), findsNWidgets(5));
    });

    testWidgets('los chips muestran los puntos del nivel 3', (tester) async {
      await abrirMapa(tester, 'Nivel 3');

      expect(find.text('+8'), findsOneWidget); // gris
      expect(find.text('+7'), findsNWidgets(3)); // morado, azul y amarillo
      expect(find.text('+6'), findsNWidgets(2)); // rojo y verde
      // Amarillo, azul, verde y gris tienen 1 zona; morado y rojo, 2
      expect(find.text('0/1'), findsNWidgets(4));
      expect(find.text('0/2'), findsNWidgets(2));
    });

    testWidgets('las Reglas muestran los puntos del verde: 6, 5 y 4', (
      tester,
    ) async {
      await abrirMapa(tester, 'Nivel 3');

      expect(
        find.byTooltip('Verde: Se puede colocar cualquier número\n'
            'Puntos por zona: 1º 6 · 2º 5 · 3º 4'),
        findsOneWidget,
      );
      await pulsar(tester, 'Reglas');
      expect(find.text('Puntos al completar una zona'), findsOneWidget);
      expect(find.textContaining('Gris:'), findsOneWidget);
    });
  });

  group('Casillas iniciales del Nivel 3', () {
    testWidgets('las 6 casillas marcadas llevan lápiz', (tester) async {
      await abrirMapa(tester, 'Nivel 3');

      expect(find.byIcon(Icons.edit), findsNWidgets(7));
    });

    testWidgets('una casilla gris puede ser inicial', (tester) async {
      await abrirMapa(tester, 'Nivel 3');
      await ponerNumeroEn(tester, const Coordenada(3, 3), 3);

      expect(textoEnTablero('3'), findsOneWidget);
      expect(find.textContaining('Faltan 5.'), findsOneWidget);
    });

    testWidgets('una casilla que no es inicial no abre el selector', (
      tester,
    ) async {
      await abrirMapa(tester, 'Nivel 3');
      await tocarCelda(tester, const Coordenada(0, 3));

      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('con los 6 números se puede comenzar la partida', (
      tester,
    ) async {
      await abrirMapa(tester, 'Nivel 3');
      await _ponerIniciales(tester);
      await pulsar(tester, 'Comenzar juego');

      final partida = partidaBloc(tester).state;
      expect(partida.iniciada, isTrue);
      expect(partida.celdas, _iniciales);
      expect(partida.casillasIniciales, casillasInicialesNivel3);
    });
  });

  group('Partida en el Nivel 3', () {
    testWidgets('la fila azul solo acepta el mismo número', (tester) async {
      // Turno 1: 4 y 2. Turno 2: doble 4. Luego dados de sobra.
      await abrirMapa(tester, 'Nivel 3', dados: [4, 2, 4, 4, 1, 1]);
      await _ponerIniciales(tester);
      await pulsar(tester, 'Comenzar juego');
      await tirarDados(tester);

      // Con el 4 de (4,1) como ancla, el 2 no puede ir a la azul (4,2)
      await tocarCelda(tester, const Coordenada(4, 1));
      var partida = partidaBloc(tester).state;
      expect(partida.numeroAColocar, 2);
      expect(partida.destinosPosibles, {
        const Coordenada(3, 1),
        const Coordenada(5, 1),
        const Coordenada(4, 0),
      });

      await asentar(tester);
      await pulsar(tester, 'Siguiente');
      await pulsar(tester, 'Sí, pasar');
      await asentar(tester);

      // Con doble 4, el 4 sí entra en la azul
      await tocarCelda(tester, const Coordenada(4, 1));
      partida = partidaBloc(tester).state;
      expect(partida.destinosPosibles, contains(const Coordenada(4, 2)));
      await tocarCelda(tester, const Coordenada(4, 2));

      expect(textoEnTablero('4'), findsNWidgets(2));
      expect(partidaBloc(tester).state.tablero!.zonas['az']!.valores, [4, 4]);
      expect(find.text('Turno 3'), findsOneWidget);
      await asentar(tester);
    });
  });
}
