// Widget tests para jugar el Nivel 2: elegirlo en el selector, cómo se
// dibuja (con la zona gris), sus casillas iniciales y una partida corta.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brilliant/nivel2.dart';
import 'package:brilliant/tablero.dart';
import 'package:brilliant/tablero_ui.dart';
import 'package:brilliant/tipo.dart';

import 'helpers/widget_helpers.dart';

/// Números iniciales: 1 en (0,4) junto a la gris de arriba y 6 en (6,4)
/// junto a la gris de abajo.
final _iniciales = {
  const Coordenada(0, 4): 1,
  const Coordenada(2, 0): 2,
  const Coordenada(3, 2): 3,
  const Coordenada(4, 5): 4,
  const Coordenada(5, 1): 5,
  const Coordenada(6, 4): 6,
};

Future<void> _ponerIniciales(WidgetTester tester) async {
  for (final MapEntry(key: c, value: n) in _iniciales.entries) {
    await ponerNumeroEn(tester, c, n);
  }
}

void main() {
  group('Elegir el Nivel 2', () {
    testWidgets('aparece en el selector con su miniatura', (tester) async {
      await abrirApp(tester);
      await abrirSelector(tester);

      expect(enDialogo(find.text('Nivel 2')), findsOneWidget);
      final grises = find.descendant(
        of: find.byType(MiniMapa).at(1),
        matching: find.byWidgetPredicate((w) {
          if (w is! Container) return false;
          final d = w.decoration;
          return d is BoxDecoration && d.color == colorDeTipo(TipoGris());
        }),
      );
      expect(grises, findsNWidgets(2));
    });

    testWidgets('al elegirlo la barra muestra "Nivel 2"', (tester) async {
      await abrirMapa(tester, 'Nivel 2');

      expect(find.byType(AlertDialog), findsNothing);
      expect(nivelEnBarra(tester), 'Nivel 2');
    });

    testWidgets('sin desbordes en pantalla angosta', (tester) async {
      await abrirMapa(tester, 'Nivel 2', tamano: pantallaAngosta);

      expect(nivelEnBarra(tester), 'Nivel 2');
      expect(tester.takeException(), isNull);
    });
  });

  group('Tablero del Nivel 2', () {
    testWidgets('pinta cada casilla con el color de su zona', (tester) async {
      await abrirMapa(tester, 'Nivel 2');

      expect(celdasDeColor(colorDeTipo(TipoAmarillo())), findsNWidgets(5));
      expect(celdasDeColor(colorDeTipo(TipoGris())), findsNWidgets(2));
      expect(celdasDeColor(colorDeTipo(TipoVerde())), findsNWidgets(10));
      expect(celdasDeColor(colorDeTipo(TipoAzul())), findsNWidgets(10));
      expect(celdasDeColor(colorDeTipo(TipoMorado())), findsNWidgets(10));
      expect(celdasDeColor(colorDeTipo(TipoRojo())), findsNWidgets(12));
    });

    testWidgets('los chips muestran los puntos del nivel 2', (tester) async {
      await abrirMapa(tester, 'Nivel 2');

      expect(find.text('+8'), findsNothing); // el amarillo ya no da 8
      expect(find.text('+7'), findsOneWidget); // azul
      expect(find.text('+6'), findsNWidgets(3)); // amarillo, morado y rojo
      expect(find.text('+4'), findsOneWidget); // verde
      expect(find.text('+3'), findsOneWidget); // gris
      expect(find.text('0/1'), findsNWidgets(2)); // amarillo y gris
      expect(find.text('0/2'), findsNWidgets(4));
    });

    testWidgets('el chip gris explica su regla y sus puntos', (tester) async {
      await abrirMapa(tester, 'Nivel 2');

      expect(
        find.byTooltip('Gris: Todos los números deben de ser iguales\n'
            'Puntos por zona: 1º 3 · 2º 2 · 3º 1'),
        findsOneWidget,
      );
      expect(
        find.byTooltip('Amarillo: Todos los números deben ser diferentes\n'
            'Puntos por zona: 1º 6 · 2º 4 · 3º 2'),
        findsOneWidget,
      );
    });

    testWidgets('las Reglas incluyen la zona gris', (tester) async {
      await abrirMapa(tester, 'Nivel 2');
      await pulsar(tester, 'Reglas');

      expect(find.textContaining('Gris: Todos los números deben de ser iguales'),
          findsOneWidget);
    });
  });

  group('Casillas iniciales del Nivel 2', () {
    testWidgets('las 6 casillas marcadas llevan lápiz', (tester) async {
      await abrirMapa(tester, 'Nivel 2');

      // 6 en las casillas + 1 en el mensaje del panel
      expect(find.byIcon(Icons.edit), findsNWidgets(7));
      expect(find.textContaining('Faltan 6.'), findsOneWidget);
    });

    testWidgets('cada casilla marcada abre el selector de número', (
      tester,
    ) async {
      await abrirMapa(tester, 'Nivel 2');

      for (final c in casillasInicialesNivel2) {
        await tocarCelda(tester, c);
        expect(find.byType(BottomSheet), findsOneWidget, reason: '$c');
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('una casilla inicial del Nivel 1 no abre el selector', (
      tester,
    ) async {
      await abrirMapa(tester, 'Nivel 2');
      await tocarCelda(tester, const Coordenada(0, 2));

      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('con los 6 números se puede comenzar', (tester) async {
      await abrirMapa(tester, 'Nivel 2');
      await _ponerIniciales(tester);

      expect(find.text('Todos los números iniciales están puestos.'),
          findsOneWidget);
      expect(botonHabilitado(tester, 'Comenzar juego'), isTrue);
    });
  });

  group('Partida en el Nivel 2', () {
    testWidgets('comienza con las casillas iniciales del nivel', (
      tester,
    ) async {
      await abrirMapa(tester, 'Nivel 2');
      await _ponerIniciales(tester);
      await pulsar(tester, 'Comenzar juego');

      final partida = partidaBloc(tester).state;
      expect(partida.iniciada, isTrue);
      expect(partida.celdas, _iniciales);
      expect(partida.casillasIniciales, casillasInicialesNivel2);
      expect(find.text('Tirar dados'), findsOneWidget);
    });

    testWidgets('llenar la zona gris con números iguales da 3 puntos', (
      tester,
    ) async {
      // Turno 1: 1 y 3. Turno 2: 6 y 3. Luego dados de sobra.
      await abrirMapa(tester, 'Nivel 2', dados: [1, 3, 6, 3, 2, 2]);
      await _ponerIniciales(tester);
      await pulsar(tester, 'Comenzar juego');
      await tirarDados(tester);

      // Ancla el 1 de (0,4) y pone el 3 en la gris de arriba
      await tocarCelda(tester, const Coordenada(0, 4));
      expect(partidaBloc(tester).state.destinosPosibles,
          contains(const Coordenada(0, 3)));
      await tocarCelda(tester, const Coordenada(0, 3));
      expect(textoEnTablero('3'), findsNWidgets(2));
      expect(textoPuntos(tester), '0');
      await asentar(tester);

      // Ancla el 6 de (6,4) y pone otro 3 en la gris de abajo
      await tocarCelda(tester, const Coordenada(6, 4));
      await tocarCelda(tester, const Coordenada(6, 3));

      expect(find.text('¡Zona gris completada! +3 puntos'), findsOneWidget);
      expect(textoPuntos(tester), '3');
      expect(find.text('1/1'), findsOneWidget); // chip gris
      await asentar(tester);
    });

    testWidgets('la zona gris no acepta un número distinto', (tester) async {
      // Turno 1: 1 y 3 (pone 3 en la gris). Turno 2: 6 y 4.
      await abrirMapa(tester, 'Nivel 2', dados: [1, 3, 6, 4, 2, 2]);
      await _ponerIniciales(tester);
      await pulsar(tester, 'Comenzar juego');
      await tirarDados(tester);
      await tocarCelda(tester, const Coordenada(0, 4));
      await tocarCelda(tester, const Coordenada(0, 3));
      await asentar(tester);

      await tocarCelda(tester, const Coordenada(6, 4));
      final partida = partidaBloc(tester).state;
      expect(partida.numeroAColocar, 4);
      expect(partida.destinosPosibles,
          isNot(contains(const Coordenada(6, 3))));
    });
  });
}
