// Widget tests del menú de mapas: es la pantalla inicial, se elige uno de
// los mapas y "Jugar" abre la partida en ese mapa.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brilliant/main.dart';
import 'package:brilliant/menu_mapas.dart';
import 'package:brilliant/nivel.dart';
import 'package:brilliant/nivel1.dart';
import 'package:brilliant/niveles.dart';
import 'package:brilliant/tablero.dart';
import 'package:brilliant/tablero_ui.dart';
import 'package:brilliant/tipo.dart';
import 'package:brilliant/zona.dart';

import 'helpers/widget_helpers.dart';

/// Mapa de prueba: una sola zona verde y las casillas iniciales en la
/// última fila, para distinguirlo del Nivel 1.
final nivelDePrueba = Nivel(
  numero: 9,
  construirTablero: () => Tablero(
    zonas: {'ve': Zona(id: 've', tipo: TipoVerde(), capacidad: 49)},
    mapeo: {
      for (var f = 0; f < 7; f++)
        for (var c = 0; c < 7; c++) Coordenada(f, c): 've',
    },
  ),
  casillasIniciales: {for (var c = 0; c < 6; c++) Coordenada(6, c)},
);

/// Abre el menú con el Nivel 1 y el mapa de prueba como opciones.
Future<void> abrirConDosMapas(WidgetTester tester) async {
  usarPantalla(tester, pantallaAncha);
  await tester.pumpWidget(MaterialApp(
    home: MenuMapasPage(niveles: [nivel1, nivelDePrueba]),
  ));
}

/// Puntos blancos que marcan las casillas iniciales en una miniatura.
Finder puntosIniciales(Finder miniatura) => find.descendant(
      of: miniatura,
      matching: find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final d = w.decoration;
        return d is BoxDecoration &&
            d.shape == BoxShape.circle &&
            d.color == Colors.white;
      }),
    );

/// Casillas de color en una miniatura (las que tienen esquinas redondeadas).
Finder casillasDeMiniatura(Finder miniatura) => find.descendant(
      of: miniatura,
      matching: find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final d = w.decoration;
        return d is BoxDecoration && d.borderRadius != null;
      }),
    );

/// Color del borde de la tarjeta del mapa [nombre].
Color bordeDe(WidgetTester tester, String nombre) {
  final tarjeta = find.ancestor(
    of: enMenu(find.text(nombre)),
    matching: find.byType(TarjetaMapa),
  );
  final contenedor = find
      .descendant(
        of: tarjeta,
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).border != null),
      )
      .first;
  final d = tester.widget<Container>(contenedor).decoration as BoxDecoration;
  return (d.border! as Border).top.color;
}

bool jugarHabilitado(WidgetTester tester) =>
    tester.widget<ElevatedButton>(botonJugar()).onPressed != null;

void main() {
  group('Niveles oficiales', () {
    test('son 4 y el primero es el Nivel 1', () {
      expect(nivelesOficiales, hasLength(4));
      expect(nivelesOficiales.first, same(nivel1));
      expect(nivel1.nombre, 'Nivel 1');
      expect(nivel1.casillasIniciales, casillasInicialesNivel1);
    });

    test('cada nivel crea un tablero nuevo en cada partida', () {
      for (final nivel in nivelesOficiales) {
        expect(
          identical(nivel.construirTablero(), nivel.construirTablero()),
          isFalse,
        );
      }
    });
  });

  group('Pantalla inicial', () {
    testWidgets('la app abre en el menú de mapas, no en el tablero', (
      tester,
    ) async {
      usarPantalla(tester, pantallaAncha);
      await tester.pumpWidget(const MyApp());

      expect(find.byType(MenuMapasPage), findsOneWidget);
      expect(find.text('Elige un mapa'), findsOneWidget);
      expect(find.text('Toca un mapa y pulsa Jugar.'), findsOneWidget);
      expect(find.byType(TableroPage), findsNothing);
    });

    testWidgets('la barra superior muestra "Brilliant"', (tester) async {
      await abrirMenu(tester);

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Brilliant'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('muestra una tarjeta con miniatura por cada mapa oficial', (
      tester,
    ) async {
      await abrirMenu(tester);

      expect(find.byType(TarjetaMapa), findsNWidgets(4));
      expect(find.byType(MiniMapa), findsNWidgets(4));
      for (var n = 1; n <= 4; n++) {
        expect(enMenu(find.text('Nivel $n')), findsOneWidget);
      }
    });

    testWidgets('sin elegir mapa, "Jugar" está deshabilitado', (tester) async {
      await abrirMenu(tester);

      expect(enMenu(find.text('Jugar')), findsOneWidget);
      expect(jugarHabilitado(tester), isFalse);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('sin desbordes en pantalla angosta', (tester) async {
      await abrirMenu(tester, tamano: pantallaAngosta);

      expect(tester.takeException(), isNull);
      await tester.ensureVisible(botonJugar());
      expect(botonJugar(), findsOneWidget);
    });
  });

  group('Miniaturas', () {
    testWidgets('tienen 49 casillas y marcan las 6 iniciales', (tester) async {
      await abrirMenu(tester);

      for (var i = 0; i < 4; i++) {
        final miniatura = find.byType(MiniMapa).at(i);
        expect(casillasDeMiniatura(miniatura), findsNWidgets(49));
        expect(puntosIniciales(miniatura), findsNWidgets(6));
      }
    });

    testWidgets('usan los colores de las zonas del mapa', (tester) async {
      await abrirMenu(tester);

      final amarillas = find.descendant(
        of: find.byType(MiniMapa).first,
        matching: find.byWidgetPredicate((w) {
          if (w is! Container) return false;
          final d = w.decoration;
          return d is BoxDecoration &&
              d.color == colorDeTipo(TipoAmarillo());
        }),
      );
      expect(amarillas, findsNWidgets(5));
    });
  });

  group('Elegir un mapa', () {
    testWidgets('tocar un mapa lo marca con borde y palomita', (tester) async {
      await abrirMenu(tester);
      await elegirMapa(tester, 'Nivel 2');

      expect(bordeDe(tester, 'Nivel 2'), Colors.teal.shade700);
      expect(bordeDe(tester, 'Nivel 1'), Colors.grey.shade300);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('al elegir, "Jugar" se habilita y dice el mapa', (
      tester,
    ) async {
      await abrirMenu(tester);
      await elegirMapa(tester, 'Nivel 3');

      expect(enMenu(find.text('Jugar Nivel 3')), findsOneWidget);
      expect(jugarHabilitado(tester), isTrue);
    });

    testWidgets('tocar otro mapa cambia la selección', (tester) async {
      await abrirMenu(tester);
      await elegirMapa(tester, 'Nivel 2');
      await elegirMapa(tester, 'Nivel 4');

      expect(bordeDe(tester, 'Nivel 2'), Colors.grey.shade300);
      expect(bordeDe(tester, 'Nivel 4'), Colors.teal.shade700);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(enMenu(find.text('Jugar Nivel 4')), findsOneWidget);
    });

    testWidgets('elegir no abre la partida hasta pulsar "Jugar"', (
      tester,
    ) async {
      await abrirMenu(tester);
      await elegirMapa(tester, 'Nivel 2');

      expect(find.byType(TableroPage), findsNothing);
    });
  });

  group('Jugar', () {
    for (var n = 1; n <= 4; n++) {
      testWidgets('abre la partida del Nivel $n', (tester) async {
        await abrirMapa(tester, 'Nivel $n');

        expect(find.byType(TableroPage), findsOneWidget);
        expect(nivelEnBarra(tester), 'Nivel $n');
        expect(find.text('Faltan números'), findsOneWidget);
        expect(find.textContaining('Faltan 6.'), findsOneWidget);
      });
    }

    testWidgets('en pantalla angosta también abre la partida', (tester) async {
      await abrirMapa(tester, 'Nivel 4', tamano: pantallaAngosta);

      expect(nivelEnBarra(tester), 'Nivel 4');
      expect(tester.takeException(), isNull);
    });

    testWidgets('el tablero se dibuja con las zonas del mapa elegido', (
      tester,
    ) async {
      await abrirConDosMapas(tester);
      await elegirMapa(tester, 'Nivel 9');
      await jugar(tester);

      expect(celdasDeColor(colorDeTipo(TipoVerde())), findsNWidgets(49));
      expect(celdasDeColor(colorDeTipo(TipoAmarillo())), findsNothing);
      expect(find.text('0/1'), findsOneWidget);
      expect(find.text('+4'), findsOneWidget);
    });

    testWidgets('las casillas iniciales son las del mapa elegido', (
      tester,
    ) async {
      await abrirConDosMapas(tester);
      await elegirMapa(tester, 'Nivel 9');
      await jugar(tester);

      // Una casilla inicial del Nivel 1 no abre el selector de número
      await tocarCelda(tester, casillasInicialesNivel1.first);
      expect(find.byType(BottomSheet), findsNothing);

      await tocarCelda(tester, const Coordenada(6, 0));
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('se puede jugar el mapa elegido hasta tirar los dados', (
      tester,
    ) async {
      await abrirConDosMapas(tester);
      await elegirMapa(tester, 'Nivel 9');
      await jugar(tester);

      for (var c = 0; c < 6; c++) {
        await ponerNumeroEn(tester, Coordenada(6, c), c + 1);
      }
      await pulsar(tester, 'Comenzar juego');
      await tirarDados(tester);

      final partida = partidaBloc(tester).state;
      expect(partida.iniciada, isTrue);
      expect(partida.casillasIniciales, nivelDePrueba.casillasIniciales);
      expect(partida.dados, isNotNull);
    });

    testWidgets('cada vez que se juega, la partida empieza de cero', (
      tester,
    ) async {
      await abrirMapa(tester, 'Nivel 1');
      await ponerNumeroInicial(tester, 0, 4);
      final blocAnterior = partidaBloc(tester);

      // Vuelve al menú (sin pasar por el botón de salir)
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.text('Elige un mapa'), findsOneWidget);
      // El menú recuerda el mapa elegido
      expect(enMenu(find.text('Jugar Nivel 1')), findsOneWidget);

      await jugar(tester);
      expect(identical(partidaBloc(tester), blocAnterior), isFalse);
      expect(textoEnTablero('4'), findsNothing);
      expect(find.textContaining('Faltan 6.'), findsOneWidget);
    });
  });
}
