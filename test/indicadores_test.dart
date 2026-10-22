// Widget tests de los indicadores de zona a los lados del tablero: símbolo
// de la regla, puntos del 1º, 2º y 3º y palomita al llenar la zona.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brilliant/niveles.dart';
import 'package:brilliant/tablero.dart';
import 'package:brilliant/tablero_ui.dart';
import 'package:brilliant/tipo.dart';

import 'helpers/widget_helpers.dart';

/// Todos los indicadores de zona (se reconocen por su ayuda "Zona ...").
Finder indicadores() => find.byWidgetPredicate(
      (w) => w is Tooltip && (w.message?.startsWith('Zona ') ?? false),
    );

/// Indicadores de las zonas de [tipo] (ej. "Zona amarillo: ...").
Finder indicadoresDe(Tipo tipo) => find.byTooltip(
      'Zona ${nombreDeTipo(tipo).toLowerCase()}: ${tipo.descripcion}',
    );

Finder textoEnIndicadores(String texto) =>
    find.descendant(of: indicadores(), matching: find.text(texto));

void main() {
  group('Datos de los indicadores', () {
    for (final nivel in nivelesOficiales) {
      test('${nivel.nombre}: cada zona tiene exactamente un indicador', () {
        final ids = [
          ...nivel.indicadoresIzquierda,
          ...nivel.indicadoresDerecha,
        ];
        expect(ids.toSet(), hasLength(ids.length), reason: 'repetidos');
        expect(ids.toSet(), nivel.construirTablero().zonas.keys.toSet());
      });
    }

    test('simboloDeTipo usa los símbolos de la hoja', () {
      expect(simboloDeTipo(TipoVerde()), '?');
      expect(simboloDeTipo(TipoAzul()), '=');
      expect(simboloDeTipo(TipoGris()), '=');
      expect(simboloDeTipo(TipoRojo()), '≠');
      expect(simboloDeTipo(TipoAmarillo()), '≠');
      expect(simboloDeTipo(TipoMorado()), 'XO');
      expect(simboloDeTipo(TipoNaranjaBajo()), '1-3');
      expect(simboloDeTipo(TipoNaranjaAlto()), '4-6');
    });
  });

  group('Indicadores en el tablero', () {
    for (final nivel in nivelesOficiales) {
      testWidgets('${nivel.nombre}: uno por zona, a cada lado del tablero', (
        tester,
      ) async {
        await abrirMapa(tester, nivel.nombre);

        expect(indicadores(),
            findsNWidgets(nivel.construirTablero().zonas.length));

        final cuadricula = tester.getRect(tablero());
        final centros = indicadores()
            .evaluate()
            .map((e) => tester.getCenter(find.byWidget(e.widget)));
        final izquierda = centros.where((c) => c.dx < cuadricula.left);
        final derecha = centros.where((c) => c.dx > cuadricula.right);
        expect(izquierda, hasLength(nivel.indicadoresIzquierda.length));
        expect(derecha, hasLength(nivel.indicadoresDerecha.length));
      });

      testWidgets('${nivel.nombre}: sin desbordes en pantalla angosta', (
        tester,
      ) async {
        await abrirMapa(tester, nivel.nombre, tamano: pantallaAngosta);

        expect(indicadores(), findsWidgets);
        expect(tester.takeException(), isNull);
        // El tablero sigue siendo cuadrado
        final tamano = tester.getSize(tablero());
        expect(tamano.width, closeTo(tamano.height, 0.01));
      });
    }

    testWidgets('Nivel 1: muestra el símbolo de cada regla', (tester) async {
      await abrirMapa(tester, 'Nivel 1');

      expect(textoEnIndicadores('='), findsNWidgets(2)); // 2 azules
      expect(textoEnIndicadores('?'), findsNWidgets(2)); // 2 verdes
      expect(textoEnIndicadores('XO'), findsNWidgets(2)); // 2 moradas
      expect(textoEnIndicadores('≠'), findsNWidgets(3)); // 2 rojas + amarilla
    });

    testWidgets('Nivel 4: las naranjas muestran su rango', (tester) async {
      await abrirMapa(tester, 'Nivel 4');

      expect(textoEnIndicadores('1-3'), findsOneWidget);
      expect(textoEnIndicadores('4-6'), findsOneWidget);
    });

    testWidgets('Nivel 1: el amarillo muestra sus puntos 8, 6 y 4', (
      tester,
    ) async {
      await abrirMapa(tester, 'Nivel 1');

      final amarillo = indicadoresDe(TipoAmarillo());
      expect(amarillo, findsOneWidget);
      for (final puntos in ['8', '6', '4']) {
        expect(find.descendant(of: amarillo, matching: find.text(puntos)),
            findsOneWidget);
      }
    });

    testWidgets('Nivel 2: el amarillo muestra los puntos de su hoja', (
      tester,
    ) async {
      await abrirMapa(tester, 'Nivel 2');

      final amarillo = indicadoresDe(TipoAmarillo());
      for (final puntos in ['6', '4', '2']) {
        expect(find.descendant(of: amarillo, matching: find.text(puntos)),
            findsOneWidget);
      }
      expect(find.descendant(of: amarillo, matching: find.text('8')),
          findsNothing);
    });

    testWidgets('tocar un indicador no atenúa las casillas', (tester) async {
      await abrirMapa(tester, 'Nivel 1');
      await tester.tap(indicadoresDe(TipoAmarillo()));
      await tester.pumpAndSettle();

      final atenuadas = find.descendant(
        of: tablero(),
        matching: find.byWidgetPredicate((w) =>
            (w is Opacity && w.opacity < 1) ||
            (w is AnimatedOpacity && w.opacity < 1)),
      );
      expect(atenuadas, findsNothing);
    });

    testWidgets('mantener presionado muestra la regla de la zona', (
      tester,
    ) async {
      await abrirMapa(tester, 'Nivel 3');
      await tester.longPress(indicadoresDe(TipoGris()));
      await tester.pumpAndSettle();

      expect(find.text('Zona gris: Todos los números deben de ser iguales'),
          findsOneWidget);
    });
  });

  group('Zona llena', () {
    testWidgets('al llenar la zona gris su indicador lleva palomita', (
      tester,
    ) async {
      // Turno 1: 1 y 3. Turno 2: 6 y 3. Luego dados de sobra.
      await abrirMapa(tester, 'Nivel 2', dados: [1, 3, 6, 3, 2, 2]);
      final iniciales = {
        const Coordenada(0, 4): 1,
        const Coordenada(2, 0): 2,
        const Coordenada(3, 2): 3,
        const Coordenada(4, 5): 4,
        const Coordenada(5, 1): 5,
        const Coordenada(6, 4): 6,
      };
      for (final MapEntry(key: c, value: n) in iniciales.entries) {
        await ponerNumeroEn(tester, c, n);
      }
      await pulsar(tester, 'Comenzar juego');
      await tirarDados(tester);
      expect(find.byIcon(Icons.done), findsNothing);

      await tocarCelda(tester, const Coordenada(0, 4));
      await tocarCelda(tester, const Coordenada(0, 3));
      await asentar(tester);
      await tocarCelda(tester, const Coordenada(6, 4));
      await tocarCelda(tester, const Coordenada(6, 3));
      await asentar(tester);

      final palomita = find.byIcon(Icons.done);
      expect(palomita, findsOneWidget);
      expect(
        find.descendant(
            of: indicadoresDe(TipoGris()), matching: find.byIcon(Icons.done)),
        findsOneWidget,
      );
    });
  });
}
