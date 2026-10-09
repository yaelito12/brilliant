import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/main.dart';
import 'package:brilliant/nivel1.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brilliant/bloc/partida_bloc.dart';
import 'package:brilliant/bloc/partida_event.dart';

/// Toca la casilla (fila, columna) del tablero 7x7.
Future<void> _tocarCelda(WidgetTester tester, int fila, int columna) async {
  final grid = tester.getRect(find.byType(GridView));
  const espacio = 3.0;
  final lado = (grid.width - espacio * 6) / 7;
  await tester.tapAt(Offset(
    grid.left + columna * (lado + espacio) + lado / 2,
    grid.top + fila * (lado + espacio) + lado / 2,
  ));
  await tester.pumpAndSettle();
}

/// Pone los 6 números iniciales y comienza la partida.
Future<void> _comenzarPartida(WidgetTester tester) async {
  var numero = 1;
  for (final c in casillasInicialesNivel1) {
    await _tocarCelda(tester, c.fila, c.columna);
    await tester.tap(find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text('$numero'),
    ));
    await tester.pumpAndSettle();
    numero++;
  }
  await tester.tap(find.text('Comenzar juego'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('La app arranca esperando los valores iniciales', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Faltan números'), findsOneWidget);
    expect(find.text('Reglas'), findsOneWidget);
    // El botón de turno solo aparece cuando la partida empieza
    expect(find.text('Siguiente'), findsNothing);
  });

  for (final tamano in const [Size(1280, 800), Size(390, 844)]) {
    testWidgets('Partida completa sin desbordes en ${tamano.width.toInt()}x${tamano.height.toInt()}',
        (WidgetTester tester) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MyApp());
      await _comenzarPartida(tester);

      expect(find.text('Turno 1'), findsOneWidget);
      expect(find.text('Tirar dados'), findsOneWidget);

      await tester.ensureVisible(find.text('Tirar dados'));
      await tester.tap(find.text('Tirar dados'));
      await tester.pumpAndSettle();

      // Sin ventana emergente: el ancla se elige tocando un dado de la barra
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Siguiente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Los dados se animan en cada tirada', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MyApp());
    await _comenzarPartida(tester);
    final bloc = BlocProvider.of<PartidaBloc>(
      tester.element(find.byType(GridView).first),
    );

    await tester.tap(find.text('Tirar dados'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.hasRunningAnimations, isTrue, reason: 'primera tirada');
    await tester.pumpAndSettle();

    for (var turno = 2; turno <= 15; turno++) {
      final s = bloc.state;
      if (s.anclasPosibles.isNotEmpty) {
        // Jugar: elegir ancla, tocarla y colocar (tira los dados solo)
        final ancla = s.anclasPosibles.first;
        if (s.valorAncla == null) bloc.add(ValorAnclaElegido(s.celdas[ancla]!));
        bloc.add(AnclaSeleccionada(ancla));
        await tester.pump();
        bloc.add(NumeroColocado(bloc.state.destinosPosibles.first));
      } else {
        bloc.add(SiguienteTurno());
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(bloc.state.turno, turno);
      expect(tester.hasRunningAnimations, isTrue, reason: 'tirada del turno $turno');
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}
