import 'package:brilliant/multijugador/partida_view.dart';
import 'package:brilliant/tablero_ui.dart' show DadoAnimado;
import 'package:brilliant_reglas/brilliant_reglas.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/widget_helpers.dart' show pantallaAngosta;
import 'fakes.dart';
import 'lobby_helpers.dart';

/// Lobby de Ana con la partida en el estado [partida].
Future<FakeTransporte> enPartida(
  WidgetTester tester,
  Map<String, Object?> partida, {
  Size? tamano,
}) async {
  final ws = tamano == null
      ? await abrirLobby(tester, sala: salaJson(estado: 'jugando'))
      : await abrirLobby(tester, sala: salaJson(estado: 'jugando'), tamano: tamano);
  await servidorDice(tester, ws, {'tipo': 'partida', 'partida': partida});
  return ws;
}

Finder celda(int f, int c) => find.byKey(Key('celda-$f-$c'));
String mensaje(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('mensaje-partida'))).data!;

void main() {
  group('números iniciales', () {
    Finder tecla(int n) => find.byKey(Key('tecla-$n'));
    bool activa(WidgetTester t, Finder f) => t.widget<FilledButton>(f).onPressed != null;

    Future<void> pulsar(WidgetTester tester, Finder f) async {
      await tester.ensureVisible(f);
      await tester.tap(f);
      await avanzar(tester);
    }

    testWidgets('con el teclado se llenan en orden: 6 toques y Confirmar', (tester) async {
      final ws = await enPartida(tester, partidaJson(fase: 'iniciales', ronda: 0));
      expect(mensaje(tester), contains('Faltan 6'));
      final confirmar = find.byKey(const Key('confirmar-iniciales'));
      expect(tester.widget<FilledButton>(confirmar).onPressed, isNull);

      await pulsar(tester, tecla(1));
      expect(activa(tester, tecla(1)), isFalse, reason: 'el 1 ya se usó');
      expect(mensaje(tester), contains('Faltan 5'));
      for (var n = 2; n <= 6; n++) {
        await pulsar(tester, tecla(n));
      }
      // La selección avanzó sola por las casillas en orden de lectura.
      expect(mensaje(tester), contains('pulsa Confirmar'));

      await pulsar(tester, confirmar);
      expect(ws.enviados.last, {'tipo': 'iniciales', 'valores': iniciales1});

      await servidorDice(tester, ws, {
        'tipo': 'partida',
        'partida': partidaJson(fase: 'iniciales', ronda: 0, jugadores: [
          jugadorPartidaJson('u1', 'Ana', yaJugo: true, celdas: iniciales1),
          jugadorPartidaJson('u2', 'Beto', nivel: 3),
        ]),
      });
      expect(mensaje(tester), contains('Esperando a que los demás'));
      expect(confirmar, findsNothing);
      expect(tecla(1), findsNothing, reason: 'sin teclado una vez enviados');
      await cerrar(tester);
    });

    testWidgets('tocar una casilla la elige para cambiarla; Borrar la vacía', (tester) async {
      await enPartida(tester, partidaJson(fase: 'iniciales', ronda: 0));
      for (var n = 1; n <= 6; n++) {
        await pulsar(tester, tecla(n));
      }
      await pulsar(tester, celda(0, 2)); // tenía el 1
      await pulsar(tester, find.byKey(const Key('borrar-inicial')));
      expect(mensaje(tester), contains('Faltan 1'));
      expect(activa(tester, tecla(1)), isTrue, reason: 'el 1 vuelve a estar libre');
      expect(activa(tester, tecla(2)), isFalse);
      await pulsar(tester, tecla(1));
      expect(mensaje(tester), contains('pulsa Confirmar'));
      await cerrar(tester);
    });

    testWidgets('"Al azar" rellena todo con números válidos', (tester) async {
      final ws = await enPartida(tester, partidaJson(fase: 'iniciales', ronda: 0));
      await pulsar(tester, find.byKey(const Key('al-azar')));
      expect(mensaje(tester), contains('pulsa Confirmar'));
      await pulsar(tester, find.byKey(const Key('confirmar-iniciales')));
      final valores = {
        for (final v in ws.enviados.last['valores'] as List)
          Coordenada((v as List)[0] as int, v[1] as int): v[2] as int,
      };
      expect(errorEnValoresIniciales(nivel1, valores), isNull);
      await cerrar(tester);
    });

    testWidgets('también con el teclado físico (1-6 y Retroceso)', (tester) async {
      await enPartida(tester, partidaJson(fase: 'iniciales', ronda: 0));
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await avanzar(tester);
      expect(mensaje(tester), contains('Faltan 5'));
      expect(activa(tester, tecla(3)), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit9); // se ignora
      await avanzar(tester);
      expect(mensaje(tester), contains('Faltan 5'));
      await tester.tap(celda(0, 2));
      await avanzar(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await avanzar(tester);
      expect(mensaje(tester), contains('Faltan 6'));
      await cerrar(tester);
    });
  });

  testWidgets('elegir un ancla no hace "rebotar" otra vez su número', (tester) async {
    await enPartida(tester, partidaJson(dados: [1, 3]));
    double escala() => tester
        .widgetList<Transform>(find.descendant(of: celda(0, 2), matching: find.byType(Transform)))
        .last
        .transform
        .storage[0];
    expect(escala(), 1);
    await tester.tap(celda(0, 2));
    await tester.pump(); // un solo cuadro, sin dejar pasar tiempo
    expect(escala(), 1, reason: 'el número no se recrea al marcar el ancla');
    await cerrar(tester);
  });

  testWidgets('casilla sin salida: lo explica y "Mover el N aquí" lo arregla', (tester) async {
    await enPartida(
      tester,
      partidaJson(fase: 'iniciales', ronda: 0, jugadores: [
        jugadorPartidaJson('u1', 'Ana', nivel: 4),
        jugadorPartidaJson('u2', 'Beto', nivel: 3),
      ]),
    );
    Future<void> tocar(Finder f) async {
      await tester.ensureVisible(f);
      await tester.tap(f);
      await avanzar(tester);
    }

    // Orden de lectura: (0,4) (2,2) (2,5) (3,0) (5,4) y por último la naranja 1-3.
    for (final n in [6, 2, 3]) {
      await tocar(find.byKey(Key('tecla-$n')));
    }
    expect(find.byKey(const Key('aviso-anticipado')), findsNothing);
    await tocar(find.byKey(const Key('tecla-1')));
    expect(find.byKey(const Key('aviso-anticipado')), findsOneWidget, reason: 'avisa en cuanto pasa');
    expect(find.byKey(const Key('alerta-sin-salida')), findsOneWidget);
    await tocar(find.byKey(const Key('tecla-5')));

    // Llegó a la naranja: ninguna tecla sirve, pero se explica y se ofrece moverlo.
    expect(find.byKey(const Key('aviso-sin-salida')), findsOneWidget);
    for (var n = 1; n <= 6; n++) {
      expect(tester.widget<FilledButton>(find.byKey(Key('tecla-$n'))).onPressed, isNull);
    }
    await tocar(find.byKey(const Key('mover-1')));
    expect(find.byKey(const Key('aviso-sin-salida')), findsNothing);
    expect(mensaje(tester), contains('Faltan 1'));
    // Quedó elegida la casilla que se vació (3,0): el 4 sí cabe.
    await tocar(find.byKey(const Key('tecla-4')));
    expect(mensaje(tester), contains('pulsa Confirmar'));
    await cerrar(tester);
  });

  group('dados', () {
    testWidgets('caen al empezar la ronda y marcan el ancla elegida', (tester) async {
      await enPartida(tester, partidaJson(dados: [1, 3]));
      expect(find.byType(DadoAnimado), findsNWidgets(2));
      await tester.tap(celda(0, 2)); // un 1: ancla
      await avanzar(tester);
      expect(find.text('Ancla: 1 · colocas el 3'), findsOneWidget);
      await cerrar(tester);
    });
  });

  group('rondas', () {
    testWidgets('elegir ancla y destino manda la jugada', (tester) async {
      final ws = await enPartida(tester, partidaJson(dados: [1, 3]));
      expect(find.text('Ronda 1 de 100'), findsOneWidget);
      expect(mensaje(tester), 'Toca un 1 o un 3 de tu tablero como ancla.');

      await tester.tap(celda(0, 0)); // casilla vacía: no hace nada
      await avanzar(tester);
      expect(mensaje(tester), startsWith('Toca'));

      await tester.tap(celda(0, 2)); // el 1 de la zona azul
      await avanzar(tester);
      expect(mensaje(tester), 'Coloca el 3 en una casilla marcada.');

      await tester.tap(celda(0, 1));
      await avanzar(tester);
      expect(ws.enviados.last, {'tipo': 'jugada', 'ancla': [0, 2], 'destino': [0, 1]});
      await cerrar(tester);
    });

    testWidgets('pasar con jugadas posibles pide confirmar', (tester) async {
      final ws = await enPartida(tester, partidaJson(dados: [1, 3]));
      await tester.ensureVisible(find.byKey(const Key('pasar')));
      await tester.tap(find.byKey(const Key('pasar')));
      await avanzar(tester);
      expect(find.text('¿Pasar la ronda?'), findsOneWidget);
      await tester.tap(find.text('Sí, pasar'));
      await avanzar(tester);
      expect(ws.enviados.last, {'tipo': 'pasar'});
      await cerrar(tester);
    });

    testWidgets('sin jugadas posibles lo dice y pasa sin preguntar', (tester) async {
      final ws = await enPartida(tester, partidaJson(jugadores: [
        jugadorPartidaJson('u1', 'Ana'), // tablero vacío: ningún ancla
        jugadorPartidaJson('u2', 'Beto', nivel: 3),
      ]));
      expect(mensaje(tester), contains('No hay jugadas posibles'));
      await tester.ensureVisible(find.byKey(const Key('pasar')));
      await tester.tap(find.byKey(const Key('pasar')));
      await avanzar(tester);
      expect(ws.enviados.last, {'tipo': 'pasar'});
      await cerrar(tester);
    });

    testWidgets('después de jugar espera a los demás', (tester) async {
      await enPartida(tester, partidaJson(jugadores: [
        jugadorPartidaJson('u1', 'Ana', yaJugo: true, celdas: iniciales1),
        jugadorPartidaJson('u2', 'Beto', nivel: 3),
      ]));
      expect(mensaje(tester), 'Esperando a los demás (faltan 1)…');
      expect(find.byKey(const Key('pasar')), findsNothing);
      await cerrar(tester);
    });

    testWidgets('muestra el tiempo que queda', (tester) async {
      await enPartida(tester, partidaJson(msRestantes: 45000));
      final texto = tester.widget<Text>(find.byKey(const Key('cuenta-regresiva'))).data!;
      expect(texto, anyOf('0:45', '0:44'));
      await cerrar(tester);
    });

    testWidgets('rendirse pide confirmar y manda conceder', (tester) async {
      final ws = await enPartida(tester, partidaJson());
      await tester.ensureVisible(find.byKey(const Key('rendirse')));
      await tester.tap(find.byKey(const Key('rendirse')));
      await avanzar(tester);
      await tester.tap(find.text('Sí, rendirme'));
      await avanzar(tester);
      expect(ws.enviados.last, {'tipo': 'conceder'});

      await servidorDice(tester, ws, {
        'tipo': 'partida',
        'partida': partidaJson(jugadores: [
          jugadorPartidaJson('u1', 'Ana', estado: 'concedio', celdas: iniciales1),
          jugadorPartidaJson('u2', 'Beto', nivel: 3),
          jugadorPartidaJson('u3', 'Carla'),
        ]),
      });
      expect(mensaje(tester), contains('Te rendiste'));
      expect(find.byKey(const Key('rendirse')), findsNothing);
      await cerrar(tester);
    });
  });

  group('marcador', () {
    testWidgets('ordena por puntos y permite ver el tablero de otro', (tester) async {
      await enPartida(tester, partidaJson(jugadores: [
        jugadorPartidaJson('u1', 'Ana', puntos: 4, celdas: iniciales1),
        jugadorPartidaJson('u2', 'Beto', nivel: 3, puntos: 11, conectado: false),
        jugadorPartidaJson('u3', 'Carla', estado: 'concedio', puntos: 20),
      ]));
      final orden = tester
          .widgetList<ListTile>(find.descendant(of: find.byType(Marcador), matching: find.byType(ListTile)))
          .map((t) => (t.key as ValueKey<String>).value)
          .toList();
      expect(orden, ['marcador-Beto', 'marcador-Ana', 'marcador-Carla'],
          reason: 'los que se rinden van al final aunque tengan más puntos');
      expect(find.textContaining('sin conexión'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('marcador-Beto')));
      await tester.tap(find.byKey(const Key('marcador-Beto')));
      await avanzar(tester);
      expect(mensaje(tester), 'Estás viendo el tablero de Beto.');
      expect(find.byKey(const Key('pasar')), findsNothing);

      await tester.ensureVisible(find.text('Volver a mi tablero'));
      await tester.tap(find.text('Volver a mi tablero'));
      await avanzar(tester);
      expect(mensaje(tester), startsWith('Toca'));
      await cerrar(tester);
    });
  });

  group('conexión y final', () {
    testWidgets('si se corta la conexión no deja jugar hasta volver', (tester) async {
      final ws = await enPartida(tester, partidaJson());
      ws.cortar();
      await avanzar(tester);
      expect(find.textContaining('Reconectando'), findsOneWidget);
      expect(find.byKey(const Key('pasar')), findsNothing);
      expect(find.byKey(const Key('tablero-mp')), findsOneWidget, reason: 'el tablero sigue a la vista');

      servidor.ultimo.autenticar(sala: salaJson(estado: 'jugando'));
      await servidorDice(tester, servidor.ultimo, {'tipo': 'partida', 'partida': partidaJson(ronda: 3)});
      expect(find.text('Ronda 3 de 100'), findsOneWidget);
      expect(find.byKey(const Key('pasar')), findsOneWidget);
      await cerrar(tester);
    });

    testWidgets('al terminar muestra los resultados en la sala', (tester) async {
      final ws = await enPartida(tester, partidaJson());
      await servidorDice(tester, ws, {
        'tipo': 'partida_terminada',
        'motivo': 'tablero_completo',
        'resultados': [
          {'id': 'u2', 'nametag': 'Beto', 'nivel': 3, 'puntos': 30, 'estado': 'jugando', 'posicion': 1},
          {'id': 'u1', 'nametag': 'Ana', 'nivel': 1, 'puntos': 20, 'estado': 'jugando', 'posicion': 2},
        ],
        'partida': partidaJson(fase: 'terminada'),
      });
      await servidorDice(tester, ws, {'tipo': 'sala', 'sala': salaJson(), 'evento': {'tipo': 'fin_partida'}});

      expect(find.byKey(const Key('resultados')), findsOneWidget);
      expect(find.text('Quedaste en el lugar 2'), findsOneWidget);
      expect(find.text('Alguien completó su tablero.'), findsOneWidget);
      expect(find.text('30 pts'), findsOneWidget);
      expect(find.text('¡Estoy listo!'), findsOneWidget, reason: 'se puede pedir la revancha');

      await tester.tap(find.byTooltip('Cerrar'));
      await avanzar(tester);
      expect(find.byKey(const Key('resultados')), findsNothing);
      await cerrar(tester);
    });

    testWidgets('ganar', (tester) async {
      final ws = await enPartida(tester, partidaJson());
      await servidorDice(tester, ws, {
        'tipo': 'partida_terminada',
        'motivo': 'rendicion',
        'resultados': [
          {'id': 'u1', 'nametag': 'Ana', 'nivel': 1, 'puntos': 5, 'estado': 'jugando', 'posicion': 1},
          {'id': 'u2', 'nametag': 'Beto', 'nivel': 3, 'puntos': 9, 'estado': 'concedio', 'posicion': 2},
        ],
        'partida': partidaJson(fase: 'terminada'),
      });
      await servidorDice(tester, ws, {'tipo': 'sala', 'sala': salaJson()});
      expect(find.text('¡Ganaste!'), findsOneWidget);
      expect(find.text('Nivel 3 · se rindió'), findsOneWidget);
      await cerrar(tester);
    });

    testWidgets('sin desbordes en un teléfono', (tester) async {
      await enPartida(tester, partidaJson(), tamano: pantallaAngosta);
      expect(tester.takeException(), isNull);
      await cerrar(tester);
    });
  });
}
