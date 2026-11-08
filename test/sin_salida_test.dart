// Casillas iniciales "sin salida": cuando en una casilla ya no cabe ningún
// número (por ejemplo, la naranja 1-3 del nivel 4 con el 1, el 2 y el 3 ya
// usados en otras casillas), el juego lo explica y permite arreglarlo.
import 'package:brilliant_reglas/brilliant_reglas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/widget_helpers.dart';

const _abajo = Coordenada(6, 1); // naranja 1-3

/// El caso de la captura: el 1, el 2 y el 3 quedaron en otras casillas.
final _sinSalida = {
  const Coordenada(0, 4): 6,
  const Coordenada(2, 2): 2,
  const Coordenada(2, 5): 3,
  const Coordenada(3, 0): 1,
  const Coordenada(5, 4): 5,
};

Finder enHoja(Finder f) =>
    find.descendant(of: find.byType(BottomSheet), matching: f);

void main() {
  testWidgets(
    'avisa antes de llegar a la casilla y marca la casilla con alerta',
    (tester) async {
      await abrirMapa(tester, 'Nivel 4');
      // Mientras quede un 1, 2 o 3 libre no hay aviso.
      await ponerNumeroEn(tester, const Coordenada(0, 4), 6);
      await ponerNumeroEn(tester, const Coordenada(2, 2), 2);
      expect(find.byKey(const Key('aviso-anticipado')), findsNothing);

      for (final MapEntry(key: c, value: n) in _sinSalida.entries.skip(2)) {
        await ponerNumeroEn(tester, c, n);
      }
      expect(find.byKey(const Key('aviso-anticipado')), findsOneWidget);
      expect(find.textContaining('zona naranja 1-3'), findsOneWidget);
      expect(find.textContaining('fila 7, columna 2'), findsOneWidget);
      expect(find.byKey(const Key('alerta-sin-salida')), findsOneWidget);
    },
  );

  testWidgets('en la casilla explica por qué y "Mover el N aquí" lo arregla', (
    tester,
  ) async {
    await abrirMapa(tester, 'Nivel 4');
    for (final MapEntry(key: c, value: n) in _sinSalida.entries) {
      await ponerNumeroEn(tester, c, n);
    }
    await tocarCelda(tester, _abajo);
    expect(enHoja(find.byKey(const Key('aviso-sin-salida'))), findsOneWidget);
    expect(
      enHoja(
        find.textContaining('el 1, el 2 y el 3 ya están en otras casillas'),
      ),
      findsOneWidget,
    );
    for (final n in [1, 2, 3]) {
      expect(enHoja(find.byKey(Key('mover-$n'))), findsOneWidget);
    }

    await tester.tap(enHoja(find.byKey(const Key('mover-1'))));
    await tester.pumpAndSettle();

    // El 1 pasó a la naranja y la amarilla (3,0) quedó vacía, con salida.
    expect(find.byType(BottomSheet), findsNothing);
    expect(textoEnTablero('1'), findsOneWidget);
    expect(find.byKey(const Key('aviso-anticipado')), findsNothing);
    expect(find.byKey(const Key('alerta-sin-salida')), findsNothing);
    expect(find.textContaining('Faltan 1'), findsOneWidget);

    await ponerNumeroEn(tester, const Coordenada(3, 0), 4);
    expect(find.text('Comenzar juego'), findsOneWidget);
  });

  testWidgets('en un teléfono el aviso cabe (la hoja se desplaza)', (tester) async {
    await abrirMapa(tester, 'Nivel 4', tamano: pantallaAngosta);
    for (final MapEntry(key: c, value: n) in _sinSalida.entries) {
      await ponerNumeroEn(tester, c, n);
    }
    await tocarCelda(tester, _abajo);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(enHoja(find.byKey(const Key('mover-3'))));
    await tester.tap(enHoja(find.byKey(const Key('mover-3'))));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });
}
