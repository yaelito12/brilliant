import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/bloc/partida_bloc.dart';
import 'package:brilliant/bloc/partida_state.dart';
import 'package:brilliant/main.dart';
import 'package:brilliant/nivel1.dart';
import 'package:brilliant/tablero.dart';

/// Color de texto/contornos que usa la interfaz (_colorTexto en tablero_ui).
const colorTexto = Color(0xFF1B3B4D);

const pantallaAncha = Size(1280, 800);
const pantallaAngosta = Size(390, 844);

/// Ajusta el tamaño de la ventana de prueba y lo restaura al terminar.
void usarPantalla(WidgetTester tester, Size tamano) {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Abre la app completa en la pantalla indicada.
Future<void> abrirApp(
  WidgetTester tester, {
  Size tamano = pantallaAncha,
}) async {
  usarPantalla(tester, tamano);
  await tester.pumpWidget(const MyApp());
}

/// El GridView del tablero (el primero del árbol; los dados tienen otro).
Finder tablero() => find.byType(GridView).first;

/// Textos con [texto] dentro del tablero (números de las casillas).
Finder textoEnTablero(String texto) =>
    find.descendant(of: tablero(), matching: find.text(texto));

/// Bloc de la partida que usa la pantalla.
PartidaBloc partidaBloc(WidgetTester tester) =>
    BlocProvider.of<PartidaBloc>(tester.element(tablero()));

/// Botón elevado (ElevatedButton.icon) que contiene [texto].
Finder boton(String texto) => find.ancestor(
      of: find.text(texto),
      matching: find.byWidgetPredicate((w) => w is ElevatedButton),
    );

bool botonHabilitado(WidgetTester tester, String texto) =>
    tester.widget<ElevatedButton>(boton(texto)).onPressed != null;

/// Toca la casilla [c] del tablero 7x7.
Future<void> tocarCelda(WidgetTester tester, Coordenada c) async {
  final grid = tester.getRect(tablero());
  const espacio = 3.0;
  final lado = (grid.width - espacio * 6) / 7;
  await tester.tapAt(Offset(
    grid.left + c.columna * (lado + espacio) + lado / 2,
    grid.top + c.fila * (lado + espacio) + lado / 2,
  ));
  await tester.pumpAndSettle();
}

/// Toca [texto] (haciéndolo visible antes) y espera a que termine todo.
Future<void> pulsar(WidgetTester tester, String texto) async {
  await tester.ensureVisible(find.text(texto));
  await tester.tap(find.text(texto));
  await tester.pumpAndSettle();
}

/// Deja pasar el tiempo para que desaparezcan los avisos (SnackBar) y
/// terminen las animaciones de los dados.
Future<void> asentar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

/// Casillas iniciales del nivel 1 en un orden fijo.
List<Coordenada> casillasIniciales() => casillasInicialesNivel1.toList();

/// Toca una casilla inicial y elige [numero] en la hoja de abajo.
Future<void> ponerNumeroInicial(
  WidgetTester tester,
  int indice,
  int numero,
) async {
  await tocarCelda(tester, casillasIniciales()[indice]);
  await tester.tap(find.descendant(
    of: find.byType(BottomSheet),
    matching: find.text('$numero'),
  ));
  await tester.pumpAndSettle();
}

/// Pone los 6 números iniciales (1 a 6) y pulsa "Comenzar juego".
Future<void> comenzarPartida(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await ponerNumeroInicial(tester, i, i + 1);
  }
  await tester.tap(find.text('Comenzar juego'));
  await tester.pumpAndSettle();
}

/// Pulsa "Tirar dados" y espera a que terminen de caer.
Future<void> tirarDados(WidgetTester tester) async {
  await asentar(tester);
  await pulsar(tester, 'Tirar dados');
  await asentar(tester);
}

/// Pasa turnos (Siguiente + confirmar) hasta que [condicion] sea cierta.
/// Los dados son aleatorios, así que esto evita tests que dependan de la suerte.
Future<void> avanzarHasta(
  WidgetTester tester,
  bool Function(PartidaState) condicion, {
  int maximoTurnos = 60,
}) async {
  final bloc = partidaBloc(tester);
  for (var i = 0; i < maximoTurnos; i++) {
    if (condicion(bloc.state)) return;
    await asentar(tester);
    await pulsar(tester, 'Siguiente');
    await pulsar(tester, 'Sí, pasar');
  }
  await asentar(tester);
  if (!condicion(bloc.state)) {
    fail('No salió la tirada buscada en $maximoTurnos turnos.');
  }
}

/// Texto del contador de puntos (el único Text con tamaño 24).
String textoPuntos(WidgetTester tester) {
  final texto = tester.widget<Text>(
    find.byWidgetPredicate((w) => w is Text && w.style?.fontSize == 24),
  );
  return texto.data!;
}

/// Puntos dibujados en las caras de los 2 dados.
Finder puntosDeDados() => find.byWidgetPredicate((w) {
      if (w is! Container) return false;
      final d = w.decoration;
      return d is BoxDecoration &&
          d.shape == BoxShape.circle &&
          w.constraints?.maxWidth == 9;
    });

/// Comprueba que los números dibujados en el tablero son los del estado.
void tableroCoincideConEstado(PartidaState estado) {
  for (var n = 1; n <= 6; n++) {
    final esperados = estado.celdas.values.where((v) => v == n).length;
    expect(
      textoEnTablero('$n'),
      findsNWidgets(esperados),
      reason: 'cantidad de números $n en el tablero',
    );
  }
}
