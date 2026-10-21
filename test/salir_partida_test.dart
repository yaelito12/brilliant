// Widget tests del botón Rendirse/Salir: vuelve al menú de mapas, con
// confirmación cuando se perdería algo, y también con el "atrás" del sistema.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brilliant/menu_mapas.dart';
import 'package:brilliant/nivel.dart';
import 'package:brilliant/tablero.dart';
import 'package:brilliant/tablero_ui.dart';
import 'package:brilliant/tipo.dart';
import 'package:brilliant/zona.dart';

import 'helpers/widget_helpers.dart';

/// Mapa mínimo: solo la última fila (una zona verde de 7). Con las 6
/// iniciales puestas basta una jugada para terminar la partida.
final nivelCorto = Nivel(
  numero: 8,
  construirTablero: () => Tablero(
    zonas: {'ve': Zona(id: 've', tipo: TipoVerde(), capacidad: 7)},
    mapeo: {for (var c = 0; c < 7; c++) Coordenada(6, c): 've'},
  ),
  casillasIniciales: {for (var c = 0; c < 6; c++) Coordenada(6, c)},
);

Finder botonSalir(String texto) => find.descendant(
      of: find.byType(AppBar),
      matching: find.text(texto),
    );

Future<void> tocarBoton(WidgetTester tester, String texto) async {
  await tester.tap(botonSalir(texto));
  await tester.pumpAndSettle();
}

/// true si se ve el menú de mapas y ya no la partida.
void estaEnElMenu() {
  expect(find.text('Elige un mapa'), findsOneWidget);
  expect(find.byType(TableroPage), findsNothing);
}

/// Simula el botón "atrás" del sistema (Android).
Future<void> atrasDelSistema(WidgetTester tester) async {
  await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
  await tester.pumpAndSettle();
}

void main() {
  group('Botón en la barra superior', () {
    testWidgets('antes de comenzar dice "Salir"', (tester) async {
      await abrirMapa(tester, 'Nivel 1');

      expect(botonSalir('Salir'), findsOneWidget);
      expect(botonSalir('Rendirse'), findsNothing);
      expect(find.byIcon(Icons.logout), findsOneWidget);
      expect(find.byTooltip('Volver al menú de mapas'), findsOneWidget);
    });

    testWidgets('con la partida en curso dice "Rendirse"', (tester) async {
      await abrirMapa(tester, 'Nivel 1');
      await comenzarPartida(tester);

      expect(botonSalir('Rendirse'), findsOneWidget);
      expect(botonSalir('Salir'), findsNothing);
      expect(find.byIcon(Icons.flag), findsOneWidget);
    });

    testWidgets('la partida no tiene flecha de regreso', (tester) async {
      await abrirMapa(tester, 'Nivel 2');

      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('cabe en pantalla angosta con la partida en curso', (
      tester,
    ) async {
      await abrirMapa(tester, 'Nivel 1', tamano: pantallaAngosta);
      await comenzarPartida(tester);

      expect(botonSalir('Rendirse'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Salir antes de comenzar', () {
    testWidgets('sin números puestos vuelve directo al menú', (tester) async {
      await abrirMapa(tester, 'Nivel 3');
      await tocarBoton(tester, 'Salir');

      expect(find.byType(AlertDialog), findsNothing);
      estaEnElMenu();
    });

    testWidgets('con números puestos pide confirmación', (tester) async {
      await abrirMapa(tester, 'Nivel 1');
      await ponerNumeroInicial(tester, 0, 3);
      await tocarBoton(tester, 'Salir');

      expect(find.text('¿Salir al menú?'), findsOneWidget);
      expect(
        find.text('Se perderá esta partida y volverás al menú de mapas.'),
        findsOneWidget,
      );
      expect(find.text('Sí, salir'), findsOneWidget);
    });

    testWidgets('cancelar deja los números como estaban', (tester) async {
      await abrirMapa(tester, 'Nivel 1');
      await ponerNumeroInicial(tester, 0, 3);
      await tocarBoton(tester, 'Salir');
      await pulsar(tester, 'Cancelar');

      expect(find.byType(TableroPage), findsOneWidget);
      expect(textoEnTablero('3'), findsOneWidget);
      expect(find.textContaining('Faltan 5.'), findsOneWidget);
    });

    testWidgets('confirmar vuelve al menú', (tester) async {
      await abrirMapa(tester, 'Nivel 1');
      await ponerNumeroInicial(tester, 0, 3);
      await tocarBoton(tester, 'Salir');
      await pulsar(tester, 'Sí, salir');

      estaEnElMenu();
    });
  });

  group('Rendirse', () {
    testWidgets('pide confirmación', (tester) async {
      await abrirMapa(tester, 'Nivel 1');
      await comenzarPartida(tester);
      await tocarBoton(tester, 'Rendirse');

      expect(find.text('¿Rendirse?'), findsOneWidget);
      expect(find.text('Sí, rendirme'), findsOneWidget);
      expect(find.byIcon(Icons.flag), findsWidgets);
    });

    testWidgets('cancelar sigue la misma partida', (tester) async {
      await abrirMapa(tester, 'Nivel 1');
      await comenzarPartida(tester);
      await tirarDados(tester);
      final antes = partidaBloc(tester).state;

      await tocarBoton(tester, 'Rendirse');
      await pulsar(tester, 'Cancelar');

      final despues = partidaBloc(tester).state;
      expect(despues.turno, antes.turno);
      expect(despues.dados, antes.dados);
      expect(find.text('Siguiente'), findsOneWidget);
    });

    testWidgets('al volver, el menú conserva el mapa elegido', (
      tester,
    ) async {
      await abrirMapa(tester, 'Nivel 2');
      await ponerNumeroEn(tester, const Coordenada(0, 4), 1);
      await tocarBoton(tester, 'Salir');
      await pulsar(tester, 'Sí, salir');

      estaEnElMenu();
      expect(enMenu(find.text('Jugar Nivel 2')), findsOneWidget);
    });

    testWidgets('después de rendirse se puede elegir otro mapa y jugar', (
      tester,
    ) async {
      await abrirMapa(tester, 'Nivel 1');
      await comenzarPartida(tester);
      await tirarDados(tester);
      await tocarBoton(tester, 'Rendirse');
      await pulsar(tester, 'Sí, rendirme');

      estaEnElMenu();
      await elegirMapa(tester, 'Nivel 4');
      await jugar(tester);

      expect(nivelEnBarra(tester), 'Nivel 4');
      expect(partidaBloc(tester).state.iniciada, isFalse);
      expect(find.textContaining('Faltan 6.'), findsOneWidget);
      expect(botonSalir('Salir'), findsOneWidget);
    });

    testWidgets('volver a jugar el mismo mapa empieza de cero', (tester) async {
      await abrirMapa(tester, 'Nivel 1');
      await comenzarPartida(tester);
      await tocarBoton(tester, 'Rendirse');
      await pulsar(tester, 'Sí, rendirme');
      await jugar(tester);

      expect(partidaBloc(tester).state.iniciada, isFalse);
      expect(find.text('Faltan números'), findsOneWidget);
      for (var n = 1; n <= 6; n++) {
        expect(textoEnTablero('$n'), findsNothing);
      }
    });
  });

  group('Partida terminada', () {
    testWidgets('al terminar dice "Salir" y vuelve sin preguntar', (
      tester,
    ) async {
      usarPantalla(tester, pantallaAncha);
      await tester.pumpWidget(MaterialApp(
        home: MenuMapasPage(niveles: [nivelCorto], random: DadosFijos([6, 1])),
      ));
      await elegirMapa(tester, 'Nivel 8');
      await jugar(tester);
      for (var c = 0; c < 6; c++) {
        await ponerNumeroEn(tester, Coordenada(6, c), c + 1);
      }
      await pulsar(tester, 'Comenzar juego');
      await tirarDados(tester);

      // Ancla el 6 de (6,5) y pone el 1 en la última casilla
      await tocarCelda(tester, const Coordenada(6, 5));
      await tocarCelda(tester, const Coordenada(6, 6));
      expect(partidaBloc(tester).state.terminada, isTrue);
      await asentar(tester);

      expect(botonSalir('Salir'), findsOneWidget);
      await tocarBoton(tester, 'Salir');

      expect(find.byType(AlertDialog), findsNothing);
      estaEnElMenu();
    });
  });

  group('Botón "atrás" del sistema', () {
    testWidgets('sin progreso vuelve al menú', (tester) async {
      await abrirMapa(tester, 'Nivel 1');
      await atrasDelSistema(tester);

      estaEnElMenu();
    });

    testWidgets('con la partida en curso pide confirmación', (tester) async {
      await abrirMapa(tester, 'Nivel 1');
      await comenzarPartida(tester);
      await atrasDelSistema(tester);

      expect(find.text('¿Rendirse?'), findsOneWidget);
      await pulsar(tester, 'Cancelar');
      expect(find.byType(TableroPage), findsOneWidget);

      await atrasDelSistema(tester);
      await pulsar(tester, 'Sí, rendirme');
      estaEnElMenu();
    });
  });
}
