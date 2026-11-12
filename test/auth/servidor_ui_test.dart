// Pruebas de la pantalla "Servidor": en móvil la app pregunta la dirección del
// servidor antes de dejar iniciar sesión, y se puede cambiar después.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/auth/auth_gate.dart';
import 'package:brilliant/auth/config_servidor.dart';
import 'package:brilliant/bloc/auth_bloc.dart';
import 'package:brilliant/bloc/auth_event.dart';
import 'package:brilliant/main.dart';

import '../helpers/widget_helpers.dart' show usarPantalla, pantallaAncha;
import 'helpers.dart';

/// Abre la app con la dirección del servidor que se le pase ([inicial] vacía
/// significa "recién instalada en un móvil").
Future<ConfigServidor> abrir(
  WidgetTester tester, {
  String inicial = '',
}) async {
  usarPantalla(tester, pantallaAncha);
  final t = crearRepo();
  final bloc = AuthBloc(t.repo)..add(AuthIniciada());
  addTearDown(bloc.close);
  final config = ConfigServidor(
    urlInicial: inicial,
    almacen: AlmacenServidorEnMemoria(),
    sePuedeCambiar: true,
  );
  await tester.pumpWidget(
    BlocProvider.value(
      value: bloc,
      child: MyApp(home: AuthGate(config: config)),
    ),
  );
  await tester.pumpAndSettle();
  return config;
}

Future<void> escribir(WidgetTester tester, String texto) async {
  await tester.enterText(find.byType(TextField), texto);
  await tester.tap(find.text('Guardar sin probar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin dirección, lo primero es preguntar por el servidor', (
    tester,
  ) async {
    await abrir(tester);

    expect(find.text('Servidor'), findsOneWidget);
    expect(find.text('Inicia sesión'), findsNothing);
  });

  testWidgets('al guardar la dirección se pasa al inicio de sesión', (
    tester,
  ) async {
    final config = await abrir(tester);

    await escribir(tester, '192.168.1.9');

    expect(config.url, 'http://192.168.1.9:3000');
    expect(find.text('Inicia sesión'), findsOneWidget);
  });

  testWidgets('una dirección que no se entiende no pasa de pantalla', (
    tester,
  ) async {
    final config = await abrir(tester);

    await escribir(tester, 'la pc de papa');

    expect(config.configurado, isFalse);
    expect(find.textContaining('Escribe una dirección'), findsOneWidget);
    expect(find.text('Inicia sesión'), findsNothing);
  });

  testWidgets('con servidor elegido, el inicio de sesión muestra cuál es', (
    tester,
  ) async {
    await abrir(tester, inicial: '192.168.1.9');

    expect(find.text('Inicia sesión'), findsOneWidget);
    expect(find.text('Servidor: 192.168.1.9:3000'), findsOneWidget);
  });

  testWidgets('desde el inicio de sesión se puede cambiar el servidor', (
    tester,
  ) async {
    final config = await abrir(tester, inicial: '10.0.0.1');

    await tester.tap(find.text('Servidor: 10.0.0.1:3000'));
    await tester.pumpAndSettle();
    await escribir(tester, '192.168.1.9:4000');

    expect(config.url, 'http://192.168.1.9:4000');
    expect(find.text('Servidor: 192.168.1.9:4000'), findsOneWidget);
  });
}
