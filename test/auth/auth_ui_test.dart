// Pruebas de la interfaz de cuenta: crear cuenta, iniciar sesión y borrar cuenta.
// Usan el AuthBloc real con una API falsa (sin red).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/auth/auth_gate.dart';
import 'package:brilliant/auth/auth_models.dart';
import 'package:brilliant/bloc/auth_bloc.dart';
import 'package:brilliant/bloc/auth_event.dart';
import 'package:brilliant/main.dart';

import '../helpers/widget_helpers.dart' show usarPantalla, pantallaAncha;
import 'helpers.dart';

/// Abre la app real (con el AuthGate) sin sesión guardada.
Future<FakeApi> abrir(WidgetTester tester) async {
  usarPantalla(tester, pantallaAncha);
  final t = crearRepo();
  final bloc = AuthBloc(t.repo)..add(AuthIniciada());
  addTearDown(bloc.close);
  await tester.pumpWidget(
    BlocProvider.value(
      value: bloc,
      child: const MyApp(home: AuthGate()),
    ),
  );
  await tester.pumpAndSettle();
  t.api.onLogin = () async => sesion();
  t.api.onRegistro = () async => sesion();
  t.api.onBorrar = (_, __) async {};
  return t.api;
}
 
Finder campo(int i) => find.byType(TextFormField).at(i);

Future<void> iniciarSesion(WidgetTester tester) async {
  await tester.enterText(campo(0), 'Ana');
  await tester.enterText(campo(1), 'clave-larga-123');
  await tester.tap(find.text('Entrar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin sesión se muestra el inicio de sesión', (tester) async {
    await abrir(tester);
    expect(find.text('Inicia sesión'), findsOneWidget);
    expect(find.text('Elige un mapa'), findsNothing);
  });

  testWidgets('el login valida campos vacíos antes de llamar al servidor', (
    tester,
  ) async {
    final api = await abrir(tester);
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    expect(find.text('Escribe tu nametag.'), findsOneWidget);
    expect(find.text('Escribe tu contraseña.'), findsOneWidget);
    expect(api.llamadas, isEmpty);
  });

  testWidgets('iniciar sesión lleva al menú de mapas', (tester) async {
    await abrir(tester);
    await iniciarSesion(tester);
    expect(find.text('Elige un mapa'), findsOneWidget);
    expect(find.byIcon(Icons.account_circle), findsOneWidget);
  });

  testWidgets('credenciales incorrectas muestran el error y siguen en login', (
    tester,
  ) async {
    final api = await abrir(tester);
    api.onLogin = () async => throw errorApi(
      401,
      'credenciales_invalidas',
      'Nametag o contraseña incorrectos.',
    );
    await iniciarSesion(tester);
    expect(find.text('Nametag o contraseña incorrectos.'), findsOneWidget);
    expect(find.text('Elige un mapa'), findsNothing);
  });

  testWidgets('crear cuenta: valida y entra al juego', (tester) async {
    final api = await abrir(tester);
    await tester.tap(find.text('¿No tienes cuenta? Crea una'));
    await tester.pumpAndSettle();
    expect(find.text('Crea tu cuenta'), findsOneWidget);

    await tester.enterText(campo(0), 'Ana');
    await tester.enterText(campo(1), 'clave-larga-123');
    await tester.enterText(campo(2), 'otra-distinta-123');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pump();
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    expect(api.llamadas, isEmpty);

    await tester.enterText(campo(2), 'clave-larga-123');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    expect(api.llamadas, ['registrar']);
    expect(find.text('Elige un mapa'), findsOneWidget);
  });

  testWidgets('crear cuenta con nametag repetido marca el campo', (
    tester,
  ) async {
    final api = await abrir(tester);
    api.onRegistro = () async =>
        throw errorApi(409, 'nametag_en_uso', 'Ese nametag ya está en uso.');
    await tester.tap(find.text('¿No tienes cuenta? Crea una'));
    await tester.pumpAndSettle();
    await tester.enterText(campo(0), 'Ana');
    await tester.enterText(campo(1), 'clave-larga-123');
    await tester.enterText(campo(2), 'clave-larga-123');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Ese nametag ya está en uso.'), findsOneWidget);
  });

  testWidgets('cerrar sesión vuelve al login', (tester) async {
    await abrir(tester);
    await iniciarSesion(tester);
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Inicia sesión'), findsOneWidget);
  });

  testWidgets('borrar cuenta: pide contraseña, borra y vuelve al login', (
    tester,
  ) async {
    final api = await abrir(tester);
    await iniciarSesion(tester);
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar cuenta'));
    await tester.pumpAndSettle();

    // Sin contraseña no se llama al servidor.
    await tester.tap(find.text('Borrar mi cuenta'));
    await tester.pump();
    expect(find.text('Escribe tu contraseña.'), findsOneWidget);
    expect(api.llamadas.where((l) => l.startsWith('borrar')), isEmpty);

    await tester.enterText(find.byType(TextFormField), 'clave-larga-123');
    await tester.tap(find.text('Borrar mi cuenta'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Inicia sesión'), findsOneWidget);
    expect(find.text('Tu cuenta fue eliminada.'), findsOneWidget);
  });

  testWidgets(
    'borrar cuenta con contraseña incorrecta deja el diálogo abierto',
    (tester) async {
      final api = await abrir(tester);
      api.onBorrar = (_, __) async => throw errorApi(
        403,
        'password_incorrecta',
        'La contraseña es incorrecta.',
      );
      await iniciarSesion(tester);
      await tester.tap(find.byIcon(Icons.account_circle));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Borrar cuenta'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'mala-clave-123');
      await tester.tap(find.text('Borrar mi cuenta'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('La contraseña es incorrecta.'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Elige un mapa'), findsOneWidget); // sigue con su sesión
    },
  );
}
