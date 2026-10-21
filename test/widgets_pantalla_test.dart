// Widget tests de la interfaz estática: estructura de la pantalla, selector
// de números iniciales, leyenda/reglas y diseño responsivo.
// Los tests del desarrollo de la partida están en widgets_partida_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brilliant/tablero.dart';
import 'package:brilliant/bloc/juego_bloc.dart';
import 'package:brilliant/bloc/juego_state.dart';
import 'package:brilliant/bloc/partida_bloc.dart';
import 'package:brilliant/menu_mapas.dart';
import 'package:brilliant/nivel1.dart';
import 'package:brilliant/tablero_ui.dart';
import 'package:brilliant/tipo.dart';

import 'helpers/widget_helpers.dart';

/// Tipo que la interfaz no conoce, para probar los valores por defecto.
class _TipoDesconocido extends Tipo {
  @override
  Color get color => const Color(0xFF000000);

  @override
  String get descripcion => 'Tipo de prueba';

  @override
  bool esPosibleAgregar(List<int> actuales, int posible) => true;

  @override
  Map<int, int> get puntuaciones => const {};
}

/// Casillas del tablero pintadas con el color [color] (degradado de la celda).
Finder celdasDeColor(Color color) => find.descendant(
      of: tablero(),
      matching: find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final d = w.decoration;
        if (d is! BoxDecoration) return false;
        final g = d.gradient;
        return g is LinearGradient && g.colors[1] == color;
      }),
    );

String ayudaDeChip(String nombre, Tipo tipo) =>
    '$nombre: ${tipo.descripcion}\n'
    'Puntos por zona: 1º ${tipo.puntuaciones[1]} · '
    '2º ${tipo.puntuaciones[2]} · 3º ${tipo.puntuaciones[3]}';

Finder enHoja(Finder f) =>
    find.descendant(of: find.byType(BottomSheet), matching: f);

void main() {
  group('Funciones públicas de la interfaz', () {
    test('colorDeTipo devuelve el color de cada zona', () {
      expect(colorDeTipo(TipoVerde()), const Color(0xFF66BB6A));
      expect(colorDeTipo(TipoAzul()), const Color(0xFF42A5F5));
      expect(colorDeTipo(TipoRojo()), const Color(0xFFEF5350));
      expect(colorDeTipo(TipoAmarillo()), const Color(0xFFFFCA28));
      expect(colorDeTipo(TipoMorado()), const Color(0xFFAB47BC));
    });

    test('nombreDeTipo devuelve el nombre de cada zona', () {
      expect(nombreDeTipo(TipoVerde()), 'Verde');
      expect(nombreDeTipo(TipoAzul()), 'Azul');
      expect(nombreDeTipo(TipoRojo()), 'Rojo');
      expect(nombreDeTipo(TipoAmarillo()), 'Amarillo');
      expect(nombreDeTipo(TipoMorado()), 'Morado');
    });

    test('un tipo desconocido usa gris y "?"', () {
      expect(colorDeTipo(_TipoDesconocido()), Colors.grey);
      expect(nombreDeTipo(_TipoDesconocido()), '?');
    });
  });

  group('MyApp', () {
    testWidgets('es una MaterialApp que abre en el menú de mapas', (
      tester,
    ) async {
      await abrirApp(tester);

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.title, 'Brilliant');
      expect(app.debugShowCheckedModeBanner, isFalse);
      expect(app.home, isA<MenuMapasPage>());
      expect(find.byType(TableroPage), findsOneWidget);
    });
  });

  group('TableroPage', () {
    testWidgets('provee JuegoBloc y PartidaBloc a su árbol', (tester) async {
      usarPantalla(tester, pantallaAncha);
      await tester.pumpWidget(const MaterialApp(home: TableroPage()));

      final contexto = tester.element(tablero());
      expect(BlocProvider.of<JuegoBloc>(contexto).state,
          isA<JuegoEsperandoValores>());
      expect(BlocProvider.of<PartidaBloc>(contexto).state.iniciada, isFalse);
    });

    testWidgets('al comenzar, JuegoBloc queda listo y arranca la partida', (
      tester,
    ) async {
      usarPantalla(tester, pantallaAncha);
      await tester.pumpWidget(const MaterialApp(home: TableroPage()));
      await comenzarPartida(tester);

      final contexto = tester.element(tablero());
      expect(BlocProvider.of<JuegoBloc>(contexto).state, isA<JuegoListo>());

      final partida = BlocProvider.of<PartidaBloc>(contexto).state;
      expect(partida.iniciada, isTrue);
      expect(partida.celdas.length, 6);
      expect(partida.casillasIniciales, casillasInicialesNivel1);
    });
  });

  group('Pantalla inicial', () {
    testWidgets('la barra superior muestra "Brilliant" en verde azulado', (
      tester,
    ) async {
      await abrirApp(tester);

      final appBar = find.byType(AppBar);
      expect(find.descendant(of: appBar, matching: find.text('Brilliant')),
          findsOneWidget);
      expect(tester.widget<AppBar>(appBar).backgroundColor,
          Colors.teal.shade700);
    });

    testWidgets('dibuja un tablero cuadrado de 7x7 con 49 casillas', (
      tester,
    ) async {
      await abrirApp(tester);

      final grid = tester.widget<GridView>(tablero());
      final delegado =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegado.crossAxisCount, 7);

      final casillas = find.descendant(
        of: tablero(),
        matching: find.byType(GestureDetector),
      );
      expect(casillas, findsNWidgets(49));

      final tamano = tester.getSize(tablero());
      expect(tamano.width, closeTo(tamano.height, 0.01));
    });

    testWidgets('cada casilla se pinta con el color de su zona', (
      tester,
    ) async {
      await abrirApp(tester);

      // Amarilla: 5 casillas. Verde, morada y roja: 2 zonas de 6. Azul: 2 de 4.
      expect(celdasDeColor(colorDeTipo(TipoAmarillo())), findsNWidgets(5));
      expect(celdasDeColor(colorDeTipo(TipoVerde())), findsNWidgets(12));
      expect(celdasDeColor(colorDeTipo(TipoAzul())), findsNWidgets(8));
      expect(celdasDeColor(colorDeTipo(TipoMorado())), findsNWidgets(12));
      expect(celdasDeColor(colorDeTipo(TipoRojo())), findsNWidgets(12));
    });

    testWidgets('las casillas iniciales llevan un lápiz', (tester) async {
      await abrirApp(tester);

      // 6 lápices en las casillas + 1 en el mensaje del panel
      expect(find.byIcon(Icons.edit), findsNWidgets(7));
    });

    testWidgets('el panel pide los números y el botón está deshabilitado', (
      tester,
    ) async {
      await abrirApp(tester);

      expect(find.textContaining('Faltan 6.'), findsOneWidget);
      expect(find.text('Faltan números'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(botonHabilitado(tester, 'Faltan números'), isFalse);
    });

    testWidgets('no hay dados ni botón de turno antes de comenzar', (
      tester,
    ) async {
      await abrirApp(tester);

      expect(find.text('Tirar dados'), findsNothing);
      expect(find.text('Siguiente'), findsNothing);
      expect(find.byIcon(Icons.question_mark), findsNothing);
      expect(find.text('Puntos'), findsNothing);
    });
  });

  group('Selector de números iniciales', () {
    testWidgets('al tocar una casilla inicial se abre la hoja con 1 al 6', (
      tester,
    ) async {
      await abrirApp(tester);
      await tocarCelda(tester, casillasIniciales().first);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Elige un número (1-6) — sin repetir'), findsOneWidget);
      expect(find.text('Puedes presionar un número en tu teclado'),
          findsOneWidget);
      for (var n = 1; n <= 6; n++) {
        expect(enHoja(find.text('$n')), findsOneWidget);
      }
    });

    testWidgets('con la casilla vacía, "Borrar número" está deshabilitado', (
      tester,
    ) async {
      await abrirApp(tester);
      await tocarCelda(tester, casillasIniciales().first);

      final borrar = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Borrar número (Supr)'),
          matching: find.byWidgetPredicate((w) => w is TextButton),
        ),
      );
      expect(borrar.onPressed, isNull);
    });

    testWidgets('elegir un número lo escribe en la casilla y cierra la hoja', (
      tester,
    ) async {
      await abrirApp(tester);
      await ponerNumeroInicial(tester, 0, 4);

      expect(find.byType(BottomSheet), findsNothing);
      expect(textoEnTablero('4'), findsOneWidget);
      expect(find.textContaining('Faltan 5.'), findsOneWidget);
      // Esa casilla ya no muestra lápiz: quedan 5 + el del panel
      expect(find.byIcon(Icons.edit), findsNWidgets(6));
    });

    testWidgets('el número ya usado aparece gris en las demás casillas', (
      tester,
    ) async {
      await abrirApp(tester);
      await ponerNumeroInicial(tester, 0, 1);
      await tocarCelda(tester, casillasIniciales()[1]);

      final grises = find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final d = w.decoration;
        return d is BoxDecoration &&
            d.color == Colors.grey.shade300 &&
            w.constraints?.maxWidth == 44;
      });
      expect(grises, findsOneWidget);
    });

    testWidgets('al reabrir una casilla llena se marca su número y se puede '
        'cambiar', (tester) async {
      await abrirApp(tester);
      await ponerNumeroInicial(tester, 0, 1);
      await tocarCelda(tester, casillasIniciales().first);

      final seleccionado = find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final d = w.decoration;
        return d is BoxDecoration &&
            d.color == Colors.orange.shade600 &&
            w.constraints?.maxWidth == 44;
      });
      expect(seleccionado, findsOneWidget);

      await tester.tap(enHoja(find.text('5')));
      await tester.pumpAndSettle();

      expect(textoEnTablero('1'), findsNothing);
      expect(textoEnTablero('5'), findsOneWidget);
      expect(find.textContaining('Faltan 5.'), findsOneWidget);
    });

    testWidgets('"Borrar número" quita el número del tablero', (tester) async {
      await abrirApp(tester);
      await ponerNumeroInicial(tester, 0, 3);
      await tocarCelda(tester, casillasIniciales().first);
      await tester.tap(find.text('Borrar número (Supr)'));
      await tester.pumpAndSettle();

      expect(textoEnTablero('3'), findsNothing);
      expect(find.textContaining('Faltan 6.'), findsOneWidget);
    });

    testWidgets('una casilla que no es inicial no abre el selector', (
      tester,
    ) async {
      await abrirApp(tester);
      await tocarCelda(tester, const Coordenada(0, 0));

      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('con los 6 números el panel se completa y se puede comenzar', (
      tester,
    ) async {
      await abrirApp(tester);
      for (var i = 0; i < 6; i++) {
        await ponerNumeroInicial(tester, i, i + 1);
      }

      expect(find.text('Todos los números iniciales están puestos.'),
          findsOneWidget);
      expect(find.text('Comenzar juego'), findsOneWidget);
      expect(botonHabilitado(tester, 'Comenzar juego'), isTrue);
      // Solo queda el lápiz del panel
      expect(find.byIcon(Icons.edit), findsOneWidget);
      for (var n = 1; n <= 6; n++) {
        expect(textoEnTablero('$n'), findsOneWidget);
      }
    });
  });

  group('Leyenda de colores (chips)', () {
    testWidgets('hay un chip por color con los puntos del 1º lugar', (
      tester,
    ) async {
      await abrirApp(tester);

      expect(find.text('+8'), findsOneWidget); // amarillo
      expect(find.text('+7'), findsOneWidget); // azul
      expect(find.text('+6'), findsNWidgets(2)); // morado y rojo
      expect(find.text('+4'), findsOneWidget); // verde
    });

    testWidgets('cada chip cuenta las zonas completas: todas en cero', (
      tester,
    ) async {
      await abrirApp(tester);

      expect(find.text('0/1'), findsOneWidget); // amarillo: 1 zona
      expect(find.text('0/2'), findsNWidgets(4)); // los otros 4 colores
    });

    testWidgets('cada chip tiene su ayuda con la regla y los puntos', (
      tester,
    ) async {
      await abrirApp(tester);

      expect(find.byTooltip(ayudaDeChip('Amarillo', TipoAmarillo())),
          findsOneWidget);
      expect(find.byTooltip(ayudaDeChip('Azul', TipoAzul())), findsOneWidget);
      expect(find.byTooltip(ayudaDeChip('Morado', TipoMorado())),
          findsOneWidget);
      expect(find.byTooltip(ayudaDeChip('Rojo', TipoRojo())), findsOneWidget);
      expect(find.byTooltip(ayudaDeChip('Verde', TipoVerde())),
          findsOneWidget);
    });

    testWidgets('mantener presionado un chip muestra su ayuda', (tester) async {
      await abrirApp(tester);
      final ayuda = ayudaDeChip('Azul', TipoAzul());

      await tester.longPress(find.byTooltip(ayuda));
      await tester.pumpAndSettle();

      expect(find.text(ayuda), findsOneWidget);
    });

    testWidgets('el botón Reglas tiene ícono de información', (tester) async {
      await abrirApp(tester);

      expect(find.text('Reglas'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  });

  group('Hoja de Reglas', () {
    Future<void> abrirReglas(WidgetTester tester) async {
      await abrirApp(tester);
      await tester.tap(find.text('Reglas'));
      await tester.pumpAndSettle();
    }

    testWidgets('muestra el título, la explicación y los encabezados', (
      tester,
    ) async {
      await abrirReglas(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Puntos al completar una zona'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
      expect(find.textContaining('1º, 2º y 3º son los puntos'),
          findsOneWidget);
      expect(find.text('Color y regla'), findsOneWidget);
      expect(find.text('1º'), findsOneWidget);
      expect(find.text('2º'), findsOneWidget);
      expect(find.text('3º'), findsOneWidget);
      expect(find.text('Llenas'), findsOneWidget);
    });

    testWidgets('explica la regla de cada color', (tester) async {
      await abrirReglas(tester);

      expect(find.textContaining('Verde: Se puede colocar cualquier número'),
          findsOneWidget);
      expect(
          find.textContaining(
              'Azul: Todos los números deben de ser iguales'),
          findsOneWidget);
      expect(
          find.textContaining(
              'Morado: Máximo dos números diferentes por zona'),
          findsOneWidget);
      expect(
          find.textContaining('Rojo: Todos los números deben ser diferentes'),
          findsOneWidget);
      expect(
          find.textContaining(
              'Amarillo: Todos los números deben ser diferentes'),
          findsOneWidget);
    });

    testWidgets('lista los puntos del 1º, 2º y 3º de cada color', (
      tester,
    ) async {
      await abrirReglas(tester);

      // Verde 4-3-2, azul 7-5-3, morado 6-4-2, rojo 6-4-2, amarillo 8-6-4
      final esperados = {
        '8': 1,
        '7': 1,
        '6': 3,
        '5': 1,
        '4': 4,
        '3': 2,
        '2': 3,
      };
      esperados.forEach((puntos, veces) {
        expect(enHoja(find.text(puntos)), findsNWidgets(veces),
            reason: 'puntos "$puntos"');
      });
    });

    testWidgets('muestra las zonas llenas de cada color (0 al inicio)', (
      tester,
    ) async {
      await abrirReglas(tester);

      expect(enHoja(find.text('0/1')), findsOneWidget);
      expect(enHoja(find.text('0/2')), findsNWidgets(4));
    });

    testWidgets('se cierra tocando fuera de la hoja', (tester) async {
      await abrirReglas(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Puntos al completar una zona'), findsNothing);
    });

    testWidgets('también se puede abrir con la partida en curso', (
      tester,
    ) async {
      await abrirApp(tester);
      await comenzarPartida(tester);
      await asentar(tester);
      await tester.tap(find.text('Reglas'));
      await tester.pumpAndSettle();

      expect(find.text('Puntos al completar una zona'), findsOneWidget);
    });
  });

  group('Diseño responsivo', () {
    testWidgets('en pantalla ancha el panel va a la derecha del tablero', (
      tester,
    ) async {
      await abrirApp(tester, tamano: pantallaAncha);
      await comenzarPartida(tester);

      final tab = tester.getRect(tablero());
      final boton = tester.getTopLeft(find.text('Tirar dados'));
      expect(boton.dx, greaterThan(tab.right));
    });

    testWidgets('en pantalla angosta el panel va debajo del tablero', (
      tester,
    ) async {
      await abrirApp(tester, tamano: pantallaAngosta);
      await comenzarPartida(tester);

      final tab = tester.getRect(tablero());
      final boton = tester.getTopLeft(find.text('Tirar dados'));
      expect(boton.dy, greaterThan(tab.bottom));
    });

    for (final tamano in const [
      Size(1920, 1080),
      Size(1280, 800),
      Size(768, 1024),
      Size(390, 844),
    ]) {
      testWidgets(
        'sin desbordes en ${tamano.width.toInt()}x${tamano.height.toInt()}',
        (tester) async {
          await abrirApp(tester, tamano: tamano);
          expect(tester.takeException(), isNull);

          await comenzarPartida(tester);
          await tirarDados(tester);

          expect(find.text('Siguiente'), findsOneWidget);
          expect(find.text('Reglas'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
