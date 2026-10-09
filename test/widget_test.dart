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
  group('Pantalla del juego', () {
    group('Inicio', () {
      testWidgets('arranca esperando los valores iniciales', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(const MyApp());

        expect(find.text('Faltan números'), findsOneWidget);
        expect(find.text('Reglas'), findsOneWidget);
        // El botón de turno solo aparece cuando la partida empieza
        expect(find.text('Siguiente'), findsNothing);
      });
    });

    group('Partida completa sin desbordes', () {
      for (final tamano in const [Size(1280, 800), Size(390, 844)]) {
        testWidgets('en ${tamano.width.toInt()}x${tamano.height.toInt()}', (
          WidgetTester tester,
        ) async {
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

          // Sin ventana emergente: el ancla se elige tocando un dado
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.text('Siguiente'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    });

    group('Animación de dados', () {
      testWidgets('los dados se animan en cada tirada', (
        WidgetTester tester,
      ) async {
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
            if (s.valorAncla == null) {
              bloc.add(ValorAnclaElegido(s.celdas[ancla]!));
            }
            bloc.add(AnclaSeleccionada(ancla));
            await tester.pump();
            bloc.add(NumeroColocado(bloc.state.destinosPosibles.first));
          } else {
            bloc.add(SiguienteTurno());
          }
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(bloc.state.turno, turno);
          expect(
            tester.hasRunningAnimations,
            isTrue,
            reason: 'tirada del turno $turno',
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      });
    });

    group('Números iniciales', () {
      /// Toca una casilla inicial y elige [numero] en la hoja de abajo.
      Future<void> ponerNumero(
        WidgetTester tester,
        int indice,
        int numero,
      ) async {
        final c = casillasInicialesNivel1.elementAt(indice);
        await _tocarCelda(tester, c.fila, c.columna);
        await tester.tap(find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('$numero'),
        ));
        await tester.pumpAndSettle();
      }

      testWidgets('cuenta las casillas que faltan', (tester) async {
        await tester.pumpWidget(const MyApp());
        expect(find.textContaining('Faltan 6.'), findsOneWidget);

        await ponerNumero(tester, 0, 1);
        expect(find.textContaining('Faltan 5.'), findsOneWidget);
      });

      testWidgets('no deja repetir un número ya usado', (tester) async {
        await tester.pumpWidget(const MyApp());
        await ponerNumero(tester, 0, 1);

        // En otra casilla, el 1 está ocupado: la hoja no se cierra
        await ponerNumero(tester, 1, 1);
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.textContaining('Faltan 5.'), findsOneWidget);
      });

      testWidgets('se puede borrar un número puesto', (tester) async {
        await tester.pumpWidget(const MyApp());
        await ponerNumero(tester, 0, 1);

        final c = casillasInicialesNivel1.first;
        await _tocarCelda(tester, c.fila, c.columna);
        await tester.tap(find.text('Borrar número (Supr)'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Faltan 6.'), findsOneWidget);
      });

      testWidgets('solo se puede comenzar con los 6 números', (tester) async {
        await tester.pumpWidget(const MyApp());
        for (var i = 0; i < 5; i++) {
          await ponerNumero(tester, i, i + 1);
        }
        expect(find.text('Faltan números'), findsOneWidget);
        expect(find.text('Comenzar juego'), findsNothing);

        await ponerNumero(tester, 5, 6);
        expect(find.text('Comenzar juego'), findsOneWidget);
      });
    });

    group('Botón Siguiente', () {
      Future<void> tirarDados(WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const MyApp());
        await _comenzarPartida(tester);
        await tester.tap(find.text('Tirar dados'));
        await tester.pumpAndSettle();
      }

      testWidgets('sin colocar número pide confirmación', (tester) async {
        await tirarDados(tester);
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('¿Pasar turno?'), findsOneWidget);
      });

      testWidgets('cancelar no cambia el turno', (tester) async {
        await tirarDados(tester);
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Turno 1'), findsOneWidget);
      });

      testWidgets('confirmar pasa al siguiente turno', (tester) async {
        await tirarDados(tester);
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sí, pasar'));
        await tester.pumpAndSettle();

        expect(find.text('Turno 2'), findsOneWidget);
      });
    });

    group('Reglas', () {
      testWidgets('el botón Reglas muestra los puntos de cada color', (
        tester,
      ) async {
        await tester.pumpWidget(const MyApp());
        await tester.tap(find.text('Reglas'));
        await tester.pumpAndSettle();

        expect(find.text('Puntos al completar una zona'), findsOneWidget);
        for (final color in ['Amarillo', 'Azul', 'Morado', 'Rojo', 'Verde']) {
          expect(find.textContaining('$color:'), findsOneWidget);
        }
      });

      testWidgets('muestra los puntos para el 1º, 2º y 3º en llenar', (
        tester,
      ) async {
        await tester.pumpWidget(const MyApp());
        await tester.tap(find.text('Reglas'));
        await tester.pumpAndSettle();

        for (final lugar in ['1º', '2º', '3º']) {
          expect(find.text(lugar), findsOneWidget);
        }
        // Amarillo es el único con 8 (1º) y azul el único con 7 (1º)
        expect(find.text('8'), findsOneWidget);
        expect(find.text('7'), findsOneWidget);
      });
    });
  });
}
