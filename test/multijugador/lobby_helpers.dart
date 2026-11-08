import 'dart:async';

import 'package:brilliant/multijugador/lobby_bloc.dart';
import 'package:brilliant/multijugador/lobby_page.dart';
import 'package:brilliant_reglas/brilliant_reglas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/widget_helpers.dart' show usarPantalla, pantallaAncha;
import 'fakes.dart';

late FakeServidor servidor;
late LobbyBloc bloc;

/// Abre el lobby con una conexión falsa ya autenticada como Ana.
Future<FakeTransporte> abrirLobby(
  WidgetTester tester, {
  Nivel? nivel,
  Map<String, Object?>? sala,
  Size tamano = pantallaAncha,
}) async {
  usarPantalla(tester, tamano);
  servidor = FakeServidor();
  bloc = LobbyBloc(conexionFalsa(servidor, FakeToken()))..add(LobbyIniciado());
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => LobbyPage(bloc: bloc, nivelInicial: nivel),
            )),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await avanzar(tester);
  servidor.ultimo.autenticar(sala: sala);
  await avanzar(tester);
  return servidor.ultimo;
}

/// Cierra el bloc (y sus timers) antes de que termine la prueba.
Future<void> cerrar(WidgetTester tester) async {
  // No se espera a close(): en el reloj falso de testWidgets no termina, pero
  // su parte síncrona ya corta los timers de la conexión.
  unawaited(bloc.close());
  await avanzar(tester);
}

Future<void> servidorDice(WidgetTester tester, FakeTransporte ws, Map<String, Object?> m) async {
  ws.servidor(m);
  await avanzar(tester);
}

Map<String, Object?> salaConBeto({bool anaLista = false, bool betoConectado = true}) => salaJson(jugadores: [
  jugadorJson('u1', 'Ana', listo: anaLista),
  jugadorJson('u2', 'Beto', nivel: 3, listo: true, conectado: betoConectado),
]);

/// Como pumpAndSettle, pero con tiempo fijo: el indicador de "conectando"
/// gira sin parar y pumpAndSettle no terminaría nunca.
Future<void> avanzar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}
