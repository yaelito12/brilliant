import 'package:brilliant/multijugador/partida_view.dart';
import 'package:brilliant/tablero_ui.dart' show CeldaTablero, DadoAnimado;
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

    /// Toca la casilla (f, c) y luego la tecla [n].
    Future<void> poner(WidgetTester tester, int f, int c, int n) async {
      await pulsar(tester, celda(f, c));
      await pulsar(tester, tecla(n));
    }

    Future<void> ponerTodos(WidgetTester tester) async {
      for (final [f, c, n] in iniciales1) {
        await poner(tester, f, c, n);
      }
    }

    testWidgets('nada se selecciona solo: casilla y luego número', (tester) async {
      final ws = await enPartida(tester, partidaJson(fase: 'iniciales', ronda: 0));
      expect(mensaje(tester), contains('Toca una casilla inicial'));
      expect(mensaje(tester), contains('Faltan 6'));
      final confirmar = find.byKey(const Key('confirmar-iniciales'));
      expect(tester.widget<FilledButton>(confirmar).onPressed, isNull);
      for (var n = 1; n <= 6; n++) {
        expect(activa(tester, tecla(n)), isFalse, reason: 'sin casilla elegida no hay teclas');
      }

      await pulsar(tester, celda(0, 2));
      expect(mensaje(tester), contains('casilla marcada'));
      await pulsar(tester, tecla(1));
      expect(mensaje(tester), contains('Faltan 5'));
      // Tras poner el número no se elige otra casilla sola.
      expect(mensaje(tester), contains('Toca una casilla inicial'));
      expect(activa(tester, tecla(2)), isFalse);

      await pulsar(tester, celda(1, 5));
      expect(activa(tester, tecla(1)), isFalse, reason: 'el 1 ya se usó');
      await pulsar(tester, tecla(2));
      for (final [f, c, n] in iniciales1.skip(2)) {
        await poner(tester, f, c, n);
      }
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
      await ponerTodos(tester);
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
      expect(mensaje(tester), contains('Faltan 6'), reason: 'sin casilla elegida no pone nada');
      await tester.tap(celda(0, 2));
      await avanzar(tester);
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
    final orden = nivel4.casillasIniciales.toList()
      ..sort((a, b) => a.fila != b.fila ? a.fila - b.fila : a.columna - b.columna);
    Future<void> poner(int i, int n) async {
      await tocar(celda(orden[i].fila, orden[i].columna));
      await tocar(find.byKey(Key('tecla-$n')));
    }

    await poner(0, 6);
    await poner(1, 2);
    await poner(2, 3);
    expect(find.byKey(const Key('aviso-anticipado')), findsNothing);
    await poner(3, 1);
    expect(find.byKey(const Key('aviso-anticipado')), findsOneWidget, reason: 'avisa en cuanto pasa');
    expect(find.byKey(const Key('alerta-sin-salida')), findsOneWidget);
    await poner(4, 5);

    // En la naranja ninguna tecla sirve, pero se explica y se ofrece moverlo.
    await tocar(celda(orden[5].fila, orden[5].columna));
    expect(find.byKey(const Key('aviso-sin-salida')), findsOneWidget);
    for (var n = 1; n <= 6; n++) {
      expect(tester.widget<FilledButton>(find.byKey(Key('tecla-$n'))).onPressed, isNull);
    }
    await tocar(find.byKey(const Key('mover-1')));
    expect(find.byKey(const Key('aviso-sin-salida')), findsNothing);
    expect(mensaje(tester), contains('Faltan 1'));
    // La casilla que se vació (3,0) no queda elegida sola: se toca y el 4 sí cabe.
    await poner(3, 4);
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

    testWidgets('tocar un dado contornea suave las opciones de colocación', (tester) async {
      await enPartida(tester, partidaJson(dados: [1, 3]));
      await tester.pump(const Duration(seconds: 2)); // que terminen de caer
      CeldaTablero celdaDe(int f, int c) => tester.widget<CeldaTablero>(
          find.descendant(of: celda(f, c), matching: find.byType(CeldaTablero)));
      expect(celdaDe(0, 1).esDestinoTentativo, isFalse, reason: 'sin dado elegido no hay opciones');

      await tester.tap(find.byKey(const ValueKey('dado-0'))); // el 1
      await avanzar(tester);
      expect(mensaje(tester), 'Toca un 1 de tu tablero como ancla para poner el 3.');
      expect(find.text('Ancla: 1 · colocas el 3'), findsOneWidget);
      // Junto al 1 de (0,2) el 3 cabe en (0,1) y (0,3).
      expect(celdaDe(0, 1).esDestinoTentativo, isTrue);
      expect(celdaDe(0, 3).esDestinoTentativo, isTrue);
      expect(celdaDe(0, 1).esDestino, isFalse, reason: 'aún no hay casilla ancla');

      // Con la casilla ancla elegida quedan solo los destinos reales.
      await tester.tap(celda(0, 2));
      await avanzar(tester);
      expect(celdaDe(0, 1).esDestino, isTrue);
      expect(celdaDe(0, 1).esDestinoTentativo, isFalse);

      // Tocar el mismo dado otra vez lo suelta.
      await tester.tap(find.byKey(const ValueKey('dado-0')));
      await avanzar(tester);
      await tester.tap(find.byKey(const ValueKey('dado-0')));
      await avanzar(tester);
      expect(celdaDe(0, 1).esDestinoTentativo, isFalse);
      expect(mensaje(tester), 'Toca un 1 o un 3 de tu tablero como ancla.');
      await cerrar(tester);
    });
  });

  group('rondas', () {
    testWidgets('elegir ancla y destino manda la jugada', (tester) async {
      final ws = await enPartida(tester, partidaJson(dados: [1, 3]));
      expect(find.text('Ronda 1 de 100'), findsOneWidget);
      expect(find.text('Gana quien llegue a 26 puntos'), findsOneWidget);
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
    testWidgets('ordena por puntos y no deja ver el tablero de otro', (tester) async {
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
      expect(mensaje(tester), startsWith('Toca'), reason: 'sigue en su propio tablero');
      expect(find.byKey(const Key('pasar')), findsOneWidget);
      expect(find.textContaining('Estás viendo'), findsNothing);
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

  group('alguien pierde la conexión', () {
    /// La partida con Beto sin conexión (o de vuelta, con [conectado]).
    Map<String, Object?> conBetoCaido({bool conectado = false}) => partidaJson(
      jugadores: [
        jugadorPartidaJson('u1', 'Ana', celdas: iniciales1),
        jugadorPartidaJson('u2', 'Beto', nivel: 3, conectado: conectado),
      ],
    );

    testWidgets('la partida queda en pausa con cuenta atrás, y no pasa el turno', (
      tester,
    ) async {
      final ws = await enPartida(tester, partidaJson());
      final pausa = find.byKey(const Key('aviso-en-pausa'));
      expect(pausa, findsNothing);

      await servidorDice(tester, ws, {
        'tipo': 'partida',
        'partida': conBetoCaido(),
        'evento': {
          'tipo': 'desconectado',
          'nametag': 'Beto',
          'graciaSegundos': 10,
        },
      });

      expect(pausa, findsOneWidget);
      expect(find.byKey(const Key('cuenta-pausa')), findsOneWidget);
      expect(
        find.descendant(
          of: pausa,
          matching: find.textContaining('Nadie pasa de turno'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: pausa,
          matching: find.textContaining('pierde y queda fuera'),
        ),
        findsOneWidget,
      );

      // Al volver se quita el aviso y la partida sigue.
      await servidorDice(tester, ws, {
        'tipo': 'partida',
        'partida': conBetoCaido(conectado: true),
        'evento': {'tipo': 'reconectado', 'nametag': 'Beto'},
      });
      expect(pausa, findsNothing);
      await cerrar(tester);
    });

    testWidgets('si no vuelve, pierde y queda fuera', (tester) async {
      final ws = await enPartida(tester, partidaJson());
      await servidorDice(tester, ws, {
        'tipo': 'partida',
        'partida': conBetoCaido(),
        'evento': {
          'tipo': 'desconectado',
          'nametag': 'Beto',
          'graciaSegundos': 10,
        },
      });
      expect(find.byKey(const Key('aviso-en-pausa')), findsOneWidget);

      // Vencida la espera, el servidor lo saca: ya no se espera a nadie.
      await servidorDice(tester, ws, {
        'tipo': 'partida',
        'partida': partidaJson(
          jugadores: [
            jugadorPartidaJson('u1', 'Ana', celdas: iniciales1),
            jugadorPartidaJson(
              'u2',
              'Beto',
              nivel: 3,
              conectado: false,
              estado: 'abandono',
            ),
          ],
        ),
        'evento': {'tipo': 'abandono', 'nametag': 'Beto'},
      });

      expect(find.byKey(const Key('aviso-en-pausa')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('marcador-Beto')),
          matching: find.text('abandonó'),
        ),
        findsOneWidget,
      );
      await cerrar(tester);
    });
  });
}
