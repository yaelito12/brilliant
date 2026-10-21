// Widget tests del selector de mapas: botón de la barra superior, diálogo
// con las miniaturas y cambio de mapa (con confirmación si hay progreso).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brilliant/bloc/partida_bloc.dart';
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

/// Abre la pantalla con el Nivel 1 y el mapa de prueba como opciones.
Future<void> abrirConDosMapas(WidgetTester tester) async {
  usarPantalla(tester, pantallaAncha);
  await tester.pumpWidget(MaterialApp(
    home: TableroPage(niveles: [nivel1, nivelDePrueba]),
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

void main() {
  group('Niveles oficiales', () {
    test('el primero es el Nivel 1', () {
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

  group('Botón de mapa en la barra superior', () {
    testWidgets('muestra el nivel actual con ícono de mapa', (tester) async {
      await abrirApp(tester);

      expect(botonMapa(), findsOneWidget);
      expect(nivelEnBarra(tester), 'Nivel 1');
      expect(find.byTooltip('Elegir mapa'), findsOneWidget);
    });

    testWidgets('se puede usar también en pantalla angosta', (tester) async {
      await abrirApp(tester, tamano: pantallaAngosta);
      await abrirSelector(tester);

      expect(find.text('Elige un mapa'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Diálogo "Elige un mapa"', () {
    testWidgets('muestra una miniatura por cada mapa oficial', (tester) async {
      await abrirApp(tester);
      await abrirSelector(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Elige un mapa'), findsOneWidget);
      expect(find.byType(MiniMapa), findsNWidgets(nivelesOficiales.length));
      for (final nivel in nivelesOficiales) {
        expect(enDialogo(find.text(nivel.nombre)), findsOneWidget);
      }
    });

    testWidgets('la miniatura tiene 49 casillas y marca las 6 iniciales', (
      tester,
    ) async {
      await abrirApp(tester);
      await abrirSelector(tester);

      final miniatura = find.byType(MiniMapa).first;
      expect(casillasDeMiniatura(miniatura), findsNWidgets(49));
      expect(puntosIniciales(miniatura), findsNWidgets(6));
    });

    testWidgets('la miniatura usa los colores de las zonas del mapa', (
      tester,
    ) async {
      await abrirApp(tester);
      await abrirSelector(tester);

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

    testWidgets('el mapa actual se marca con borde verde azulado', (
      tester,
    ) async {
      await abrirConDosMapas(tester);
      await abrirSelector(tester);

      Border bordeDe(String nombre) {
        final tarjeta = find.ancestor(
          of: enDialogo(find.text(nombre)),
          matching: find.byWidgetPredicate((w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).border != null),
        );
        final d = tester.widget<Container>(tarjeta.first).decoration
            as BoxDecoration;
        return d.border! as Border;
      }

      expect(bordeDe('Nivel 1').top.color, Colors.teal.shade700);
      expect(bordeDe('Nivel 9').top.color, Colors.grey.shade300);
    });

    testWidgets('"Cerrar" lo cierra sin cambiar de mapa', (tester) async {
      await abrirConDosMapas(tester);
      await abrirSelector(tester);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(nivelEnBarra(tester), 'Nivel 1');
    });

    testWidgets('elegir el mismo mapa no borra los números puestos', (
      tester,
    ) async {
      await abrirApp(tester);
      await ponerNumeroInicial(tester, 0, 4);
      await elegirMapa(tester, 'Nivel 1');

      expect(find.byType(AlertDialog), findsNothing);
      expect(textoEnTablero('4'), findsOneWidget);
      expect(find.textContaining('Faltan 5.'), findsOneWidget);
    });
  });

  group('Cambiar de mapa', () {
    testWidgets('sin números puestos cambia directo, sin preguntar', (
      tester,
    ) async {
      await abrirConDosMapas(tester);
      await elegirMapa(tester, 'Nivel 9');

      expect(find.byType(AlertDialog), findsNothing);
      expect(nivelEnBarra(tester), 'Nivel 9');
    });

    testWidgets('el tablero se dibuja con las zonas del mapa nuevo', (
      tester,
    ) async {
      await abrirConDosMapas(tester);
      await elegirMapa(tester, 'Nivel 9');

      expect(celdasDeColor(colorDeTipo(TipoVerde())), findsNWidgets(49));
      expect(celdasDeColor(colorDeTipo(TipoAmarillo())), findsNothing);
      // La leyenda solo muestra el color del mapa nuevo
      expect(find.text('0/1'), findsOneWidget);
      expect(find.text('+4'), findsOneWidget);
    });

    testWidgets('las casillas iniciales son las del mapa nuevo', (
      tester,
    ) async {
      await abrirConDosMapas(tester);
      await elegirMapa(tester, 'Nivel 9');

      // Una casilla inicial del Nivel 1 ya no abre el selector de número
      await tocarCelda(tester, casillasInicialesNivel1.first);
      expect(find.byType(BottomSheet), findsNothing);

      await tocarCelda(tester, const Coordenada(6, 0));
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('se puede jugar el mapa nuevo hasta tirar los dados', (
      tester,
    ) async {
      await abrirConDosMapas(tester);
      await elegirMapa(tester, 'Nivel 9');

      for (var c = 0; c < 6; c++) {
        await tocarCelda(tester, Coordenada(6, c));
        await tester.tap(find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('${c + 1}'),
        ));
        await tester.pumpAndSettle();
      }
      await pulsar(tester, 'Comenzar juego');
      await tirarDados(tester);

      final partida = partidaBloc(tester).state;
      expect(partida.iniciada, isTrue);
      expect(partida.casillasIniciales, nivelDePrueba.casillasIniciales);
      expect(partida.dados, isNotNull);
      expect(find.text('Siguiente'), findsOneWidget);
    });

    testWidgets('con números puestos pide confirmación', (tester) async {
      await abrirConDosMapas(tester);
      await ponerNumeroInicial(tester, 0, 2);
      await elegirMapa(tester, 'Nivel 9');

      expect(find.text('¿Cambiar al Nivel 9?'), findsOneWidget);
      expect(
        find.text('Se perderán los números puestos en el mapa actual.'),
        findsOneWidget,
      );
    });

    testWidgets('cancelar deja el mapa y los números como estaban', (
      tester,
    ) async {
      await abrirConDosMapas(tester);
      await ponerNumeroInicial(tester, 0, 2);
      await elegirMapa(tester, 'Nivel 9');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(nivelEnBarra(tester), 'Nivel 1');
      expect(textoEnTablero('2'), findsOneWidget);
      expect(find.textContaining('Faltan 5.'), findsOneWidget);
    });

    testWidgets('confirmar cambia de mapa y empieza sin números', (
      tester,
    ) async {
      await abrirConDosMapas(tester);
      await ponerNumeroInicial(tester, 0, 2);
      await elegirMapa(tester, 'Nivel 9');
      await tester.tap(find.text('Sí, cambiar'));
      await tester.pumpAndSettle();

      expect(nivelEnBarra(tester), 'Nivel 9');
      expect(textoEnTablero('2'), findsNothing);
      expect(find.textContaining('Faltan 6.'), findsOneWidget);
    });

    testWidgets('con la partida en curso, confirmar empieza una partida nueva',
        (tester) async {
      await abrirConDosMapas(tester);
      await comenzarPartida(tester);
      await tirarDados(tester);
      final blocAnterior = partidaBloc(tester);

      await elegirMapa(tester, 'Nivel 9');
      await tester.tap(find.text('Sí, cambiar'));
      await tester.pumpAndSettle();

      final blocNuevo = partidaBloc(tester);
      expect(identical(blocNuevo, blocAnterior), isFalse);
      expect(blocNuevo.state.iniciada, isFalse);
      expect(find.text('Faltan números'), findsOneWidget);
      expect(find.text('Siguiente'), findsNothing);
      expect(BlocProvider.of<PartidaBloc>(tester.element(tablero())),
          same(blocNuevo));
    });

    testWidgets('se puede volver al Nivel 1', (tester) async {
      await abrirConDosMapas(tester);
      await elegirMapa(tester, 'Nivel 9');
      await elegirMapa(tester, 'Nivel 1');

      expect(nivelEnBarra(tester), 'Nivel 1');
      expect(celdasDeColor(colorDeTipo(TipoAmarillo())), findsNWidgets(5));
    });
  });
}
