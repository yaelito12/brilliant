// Una sola sesión por cuenta: si se entra con la cuenta en otro dispositivo,
// este se entera y vuelve al inicio de sesión con un aviso.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/auth/auth_gate.dart';
import 'package:brilliant/auth/auth_models.dart';
import 'package:brilliant/bloc/auth_bloc.dart';
import 'package:brilliant/bloc/auth_event.dart';
import 'package:brilliant/bloc/auth_state.dart';
import 'package:brilliant/main.dart';

import '../helpers/widget_helpers.dart' show usarPantalla, pantallaAncha;
import 'helpers.dart';

const reemplazada = AuthException(
  status: 401,
  code: 'sesion_reemplazada',
  message: 'Se inició sesión con tu cuenta en otro dispositivo.',
);

Future<void> esperar([int ms = 20]) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  group('AuthRepository', () {
    test('verificarSesion: sesión abierta no hace nada', () async {
      final t = crearRepo();
      t.api.onLogin = () async => sesion();
      await t.repo.iniciarSesion(nametag: 'Ana', password: 'x');
      await t.repo.verificarSesion();
      expect(t.api.llamadas.last, 'yo:access-1');
      expect(await t.almacen.leerRefreshToken(), 'refresh-1');
    });

    test('verificarSesion: si se entró en otro dispositivo, borra la sesión local', () async {
      final t = crearRepo();
      t.api.onLogin = () async => sesion();
      t.api.onYo = (_) async => throw reemplazada;
      await t.repo.iniciarSesion(nametag: 'Ana', password: 'x');
      await expectLater(
        t.repo.verificarSesion(),
        throwsA(isA<AuthException>().having((e) => e.esSesionReemplazada, 'reemplazada', isTrue)),
      );
      expect(await t.almacen.leerRefreshToken(), isNull);
    });

    test('verificarSesion: token rechazado y renovación rechazada → sesión reemplazada', () async {
      final t = crearRepo();
      t.api.onLogin = () async => sesion();
      t.api.onYo = (_) async => throw errorApi(401, 'no_autenticado');
      t.api.onRefresh = (_) async => throw reemplazada;
      await t.repo.iniciarSesion(nametag: 'Ana', password: 'x');
      await expectLater(
        t.repo.verificarSesion(),
        throwsA(isA<AuthException>().having((e) => e.esSesionReemplazada, 'reemplazada', isTrue)),
      );
      expect(await t.almacen.leerRefreshToken(), isNull);
    });

    test('al abrir la app, si la sesión se cerró en otro dispositivo, lo dice', () async {
      final t = crearRepo();
      await t.almacen.guardarRefreshToken('refresh-viejo');
      t.api.onRefresh = (_) async => throw reemplazada;
      await expectLater(t.repo.restaurarSesion(), throwsA(isA<AuthException>()));
      expect(await t.almacen.leerRefreshToken(), isNull);
    });
  });

  group('AuthBloc', () {
    Future<AuthBloc> conSesion(FakeApi api, dynamic repo, {Duration? cada}) async {
      api.onLogin = () async => sesion();
      final bloc = AuthBloc(repo, verificarCada: cada);
      addTearDown(bloc.close);
      bloc.add(AuthLoginSolicitado(nametag: 'Ana', password: 'x'));
      await esperar();
      expect(bloc.state.estado, AuthEstado.autenticado);
      return bloc;
    }

    test('la revisión periódica detecta que se entró en otro dispositivo', () async {
      final t = crearRepo();
      final bloc = await conSesion(t.api, t.repo, cada: const Duration(milliseconds: 30));
      await esperar(50);
      expect(bloc.state.estado, AuthEstado.autenticado, reason: 'mientras la sesión siga abierta');

      t.api.onYo = (_) async => throw reemplazada;
      await esperar(60);
      expect(bloc.state.estado, AuthEstado.noAutenticado);
      expect(bloc.state.info, mensajeSesionReemplazada);
    });

    test('sin red la revisión no cierra la sesión', () async {
      final t = crearRepo();
      final bloc = await conSesion(t.api, t.repo, cada: const Duration(milliseconds: 20));
      t.api.onYo = (_) async => throw const AuthException.red();
      await esperar(60);
      expect(bloc.state.estado, AuthEstado.autenticado);
    });

    test('sin "verificarCada" no hay revisión periódica', () async {
      final t = crearRepo();
      await conSesion(t.api, t.repo);
      await esperar(50);
      expect(t.api.llamadas.where((l) => l.startsWith('yo:')), isEmpty);
    });

    test('AuthSesionCerrada (desde el multijugador) borra la sesión y avisa', () async {
      final t = crearRepo();
      final bloc = await conSesion(t.api, t.repo);
      bloc.add(AuthSesionCerrada(mensajeSesionReemplazada));
      await esperar();
      expect(bloc.state.estado, AuthEstado.noAutenticado);
      expect(bloc.state.info, mensajeSesionReemplazada);
      expect(await t.almacen.leerRefreshToken(), isNull);
      expect(t.api.llamadas.where((l) => l.startsWith('logout')), isEmpty,
          reason: 'el servidor ya la cerró: no hace falta avisarle');
    });

    test('al abrir la app con la sesión cerrada en otro lado muestra el aviso', () async {
      final t = crearRepo();
      await t.almacen.guardarRefreshToken('refresh-viejo');
      t.api.onRefresh = (_) async => throw reemplazada;
      final bloc = AuthBloc(t.repo)..add(AuthIniciada());
      addTearDown(bloc.close);
      await esperar();
      expect(bloc.state.estado, AuthEstado.noAutenticado);
      expect(bloc.state.info, mensajeSesionReemplazada);
      expect(bloc.state.error, isNull);
    });
  });

  testWidgets('si la cuenta está abierta en otro dispositivo, no deja entrar y lo explica', (
    tester,
  ) async {
    usarPantalla(tester, pantallaAncha);
    final t = crearRepo();
    const msg =
        'Esta cuenta ya tiene una sesión abierta en otro dispositivo. Cierra sesión allí '
        'para entrar aquí. Si ese dispositivo ya está cerrado, podrás entrar en 3 minutos.';
    t.api.onLogin = () async => throw const AuthException(
      status: 409,
      code: 'sesion_activa',
      message: msg,
      reintentarEnSegundos: 150,
    );
    final bloc = AuthBloc(t.repo)..add(AuthIniciada());
    addTearDown(bloc.close);
    await tester.pumpWidget(BlocProvider.value(value: bloc, child: const MyApp(home: AuthGate())));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'pepe');
    await tester.enterText(find.byType(TextFormField).at(1), 'clave-larga-123');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text(msg), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget, reason: 'sigue en el inicio de sesión');
    expect(bloc.state.estado, AuthEstado.noAutenticado);
    expect(await t.almacen.leerRefreshToken(), isNull, reason: 'no guardó ninguna sesión');
  });

  testWidgets('si se cierra la sesión con una pantalla abierta, vuelve al login con el aviso', (
    tester,
  ) async {
    usarPantalla(tester, pantallaAncha);
    final t = crearRepo();
    t.api.onLogin = () async => sesion();
    final bloc = AuthBloc(t.repo)..add(AuthIniciada());
    addTearDown(bloc.close);
    await tester.pumpWidget(BlocProvider.value(value: bloc, child: const MyApp(home: AuthGate())));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Ana');
    await tester.enterText(find.byType(TextFormField).at(1), 'clave-larga-123');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    // Una pantalla encima del menú (como el lobby o una partida).
    Navigator.of(tester.element(find.text('Elige un mapa'))).push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('pantalla encima'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('pantalla encima'), findsOneWidget);

    bloc.add(AuthSesionCerrada(mensajeSesionReemplazada));
    await tester.pumpAndSettle();
    expect(find.text('pantalla encima'), findsNothing);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text(mensajeSesionReemplazada), findsOneWidget);
  });
}
