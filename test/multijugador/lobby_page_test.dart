import 'package:brilliant/auth/auth_models.dart' show mensajeSesionReemplazada;
import 'package:brilliant/menu_mapas.dart';
import 'package:brilliant/multijugador/conexion_multijugador.dart';
import 'package:brilliant/multijugador/lobby_page.dart';
import 'package:brilliant_reglas/brilliant_reglas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/widget_helpers.dart' show pantallaAngosta;
import 'fakes.dart';
import 'lobby_helpers.dart';

void main() {
  testWidgets('sin mapa no se puede crear; con mapa crea la sala y muestra el código', (tester) async {
    final ws = await abrirLobby(tester);
    final crear = find.byKey(const Key('crear-sala'));
    expect(tester.widget<FilledButton>(crear).onPressed, isNull);
    expect(find.text('Primero elige un mapa.'), findsOneWidget);

    await tester.tap(find.text('Nivel 2'));
    await tester.pump();
    await tester.tap(crear);
    await tester.pump();
    expect(ws.enviados.last, {'tipo': 'crear_sala', 'nivel': 2});

    await servidorDice(tester, ws, {'tipo': 'sala', 'sala': salaJson()});
    expect(find.text('K7M2QX'), findsOneWidget);
    expect(find.text('Ana (tú)'), findsOneWidget);
    expect(find.textContaining('mínimo 2'), findsOneWidget);
    await cerrar(tester);
  });

  testWidgets('unirse con código: lo pasa a mayúsculas y lo manda con el mapa', (tester) async {
    final ws = await abrirLobby(tester, nivel: nivel4);
    final unirse = find.byKey(const Key('unirse'));
    await tester.enterText(find.byKey(const Key('codigo')), 'k7m2');
    await tester.pump();
    expect(tester.widget<OutlinedButton>(unirse).onPressed, isNull, reason: 'faltan letras');

    await tester.enterText(find.byKey(const Key('codigo')), 'k7m2qx');
    await tester.pump();
    expect(find.text('K7M2QX'), findsOneWidget);
    await tester.tap(unirse);
    await tester.pump();
    expect(ws.enviados.last, {'tipo': 'unirse', 'codigo': 'K7M2QX', 'nivel': 4});

    await servidorDice(tester, ws, {'tipo': 'error', 'code': 'sala_no_encontrada', 'message': 'No existe una sala con ese código.'});
    expect(find.text('No existe una sala con ese código.'), findsOneWidget);
    await cerrar(tester);
  });

  testWidgets('en la sala: jugadores, listo, cambiar mapa y salir', (tester) async {
    final ws = await abrirLobby(tester, sala: salaConBeto(betoConectado: false));
    expect(find.text('Jugadores (2/6)'), findsOneWidget);
    expect(find.text('Beto'), findsOneWidget);
    expect(find.textContaining('sin conexión'), findsOneWidget);
    expect(find.text('Listo'), findsOneWidget); // Beto
    expect(find.text('Esperando'), findsOneWidget); // Ana

    await tester.ensureVisible(find.text('¡Estoy listo!'));
    await tester.tap(find.text('¡Estoy listo!'));
    await tester.pump();
    expect(ws.enviados.last, {'tipo': 'listo', 'listo': true});
    await servidorDice(tester, ws, {'tipo': 'sala', 'sala': salaConBeto(anaLista: true)});
    expect(find.text('Ya no estoy listo'), findsOneWidget);
    expect(find.text('¡Todos listos!'), findsOneWidget);

    final mapa3 = find.descendant(of: find.byType(SelectorMapa), matching: find.text('Nivel 3'));
    await tester.ensureVisible(mapa3);
    await tester.tap(mapa3);
    await tester.pump();
    expect(ws.enviados.last, {'tipo': 'elegir_mapa', 'nivel': 3});

    await tester.ensureVisible(find.byKey(const Key('salir-sala')));
    await tester.tap(find.byKey(const Key('salir-sala')));
    await avanzar(tester);
    expect(ws.enviados.last, {'tipo': 'salir'});
    expect(find.byKey(const Key('crear-sala')), findsOneWidget);
    await cerrar(tester);
  });

  testWidgets('avisos de lo que hacen los demás', (tester) async {
    final ws = await abrirLobby(tester, sala: salaConBeto());
    await servidorDice(tester, ws, {
      'tipo': 'sala',
      'sala': salaConBeto(betoConectado: false),
      'evento': {'tipo': 'desconectado', 'nametag': 'Beto'},
    });
    expect(find.text('Beto perdió la conexión.'), findsOneWidget);
    await cerrar(tester);
  });

  testWidgets('se corta la conexión: aviso de reconexión y vuelve sola', (tester) async {
    final ws = await abrirLobby(tester, sala: salaConBeto());
    ws.cortar();
    await avanzar(tester);
    expect(find.textContaining('Reconectando'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('listo'))).onPressed, isNull);
    expect(find.text('K7M2QX'), findsOneWidget, reason: 'la sala sigue a la vista');

    await tester.pump(const Duration(milliseconds: 20));
    servidor.ultimo.autenticar(sala: salaConBeto());
    await avanzar(tester);
    expect(find.textContaining('Reconectando'), findsNothing);
    expect(tester.widget<FilledButton>(find.byKey(const Key('listo'))).onPressed, isNotNull);
    await cerrar(tester);
  });

  testWidgets('sesión abierta en otro lado: botón para usarla aquí', (tester) async {
    final ws = await abrirLobby(tester);
    ws.cortar(CodigoCierre.sesionReemplazada);
    await avanzar(tester);
    expect(find.textContaining('otro dispositivo'), findsOneWidget);

    await tester.tap(find.text('Usar aquí'));
    await tester.pump();
    expect(servidor.abiertos, hasLength(2));
    await cerrar(tester);
  });

  testWidgets('volver estando en una sala pide confirmar y sale de ella', (tester) async {
    final ws = await abrirLobby(tester, sala: salaConBeto());
    await tester.tap(find.byType(BackButton));
    await avanzar(tester);
    expect(find.text('¿Salir de la sala?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await avanzar(tester);
    expect(find.byType(LobbyPage), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await avanzar(tester);
    await tester.tap(find.text('Salir'));
    await avanzar(tester);
    expect(ws.enviados.last, {'tipo': 'salir'});
    expect(find.byType(LobbyPage), findsNothing);
    await cerrar(tester);
  });

  testWidgets('cuando empieza la partida pasa a la pantalla de juego', (tester) async {
    final ws = await abrirLobby(tester, sala: salaConBeto(anaLista: true));
    await servidorDice(tester, ws, {'tipo': 'partida_iniciada', 'sala': salaJson(estado: 'jugando')});
    expect(find.textContaining('Preparando el tablero'), findsOneWidget);
    await servidorDice(tester, ws, {'tipo': 'partida', 'partida': partidaJson(fase: 'iniciales', ronda: 0)});
    expect(find.byKey(const Key('tablero-mp')), findsOneWidget);
    expect(find.text('Números iniciales'), findsOneWidget);
    await cerrar(tester);
  });

  testWidgets('sin desbordes en un teléfono', (tester) async {
    final ws = await abrirLobby(tester, tamano: pantallaAngosta);
    expect(tester.takeException(), isNull);
    await servidorDice(tester, ws, {'tipo': 'sala', 'sala': salaConBeto()});
    expect(tester.takeException(), isNull);
    await cerrar(tester);
  });

  testWidgets('si se entra con la cuenta en otro dispositivo, avisa y cierra la sesión', (tester) async {
    final avisos = <String>[];
    final ws = await abrirLobby(tester, sala: salaConBeto(), alCerrarSesion: avisos.add);
    ws.cortar(CodigoCierre.sesionCerrada);
    await avanzar(tester);
    expect(find.text('Se inició sesión con tu cuenta en otro dispositivo.'), findsOneWidget);
    expect(avisos, [mensajeSesionReemplazada]);
    expect(servidor.abiertos, hasLength(1), reason: 'no intenta reconectar');
    await cerrar(tester);
  });

  group('menú', () {
    testWidgets('"Jugar en línea" solo aparece si hay sesión y pasa el mapa elegido', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MenuMapasPage()));
      expect(find.text('Jugar en línea'), findsNothing);

      Nivel? recibido;
      var llamado = false;
      await tester.pumpWidget(MaterialApp(
        home: MenuMapasPage(alJugarEnLinea: (_, n) {
          llamado = true;
          recibido = n;
        }),
      ));
      await tester.tap(find.text('Nivel 2'));
      await tester.pump();
      await tester.ensureVisible(find.text('Jugar en línea'));
      await tester.tap(find.text('Jugar en línea'));
      expect(llamado, isTrue);
      expect(recibido, nivel2);
    });
  });
}
