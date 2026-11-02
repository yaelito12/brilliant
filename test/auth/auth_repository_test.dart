import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/auth/auth_models.dart';

import 'helpers.dart';

void main() {
  test('iniciar sesión guarda el refresh token', () async {
    final t = crearRepo();
    t.api.onLogin = () async => sesion();

    final u = await t.repo.iniciarSesion(email: 'a', password: 'b');

    expect(u, usuarioAna);
    expect(await t.almacen.leerRefreshToken(), 'refresh-1');
  });

  test('restaurar sin token guardado → null y no llama al servidor', () async {
    final t = crearRepo();
    expect(await t.repo.restaurarSesion(), isNull);
    expect(t.api.llamadas, isEmpty);
  });

  test('restaurar con token válido rota el refresh token', () async {
    final t = crearRepo();
    await t.almacen.guardarRefreshToken('viejo');
    t.api.onRefresh = (_) async => sesion(n: 2);

    expect(await t.repo.restaurarSesion(), usuarioAna);
    expect(t.api.llamadas, ['refrescar:viejo']);
    expect(await t.almacen.leerRefreshToken(), 'refresh-2');
  });

  test('restaurar con token rechazado (401) borra el token', () async {
    final t = crearRepo();
    await t.almacen.guardarRefreshToken('viejo');
    t.api.onRefresh = (_) async => throw errorApi(401, 'refresh_invalido');

    expect(await t.repo.restaurarSesion(), isNull);
    expect(await t.almacen.leerRefreshToken(), isNull);
  });

  test('restaurar sin red conserva el token y avisa', () async {
    final t = crearRepo();
    await t.almacen.guardarRefreshToken('viejo');
    t.api.onRefresh = (_) async => throw const AuthException.red();

    await expectLater(t.repo.restaurarSesion(), throwsA(isA<AuthException>()));
    expect(await t.almacen.leerRefreshToken(), 'viejo');
  });

  test('cerrar sesión limpia lo local aunque el servidor falle', () async {
    final t = crearRepo();
    t.api.onLogin = () async => sesion();
    await t.repo.iniciarSesion(email: 'a', password: 'b');
    t.api.onLogout = () async => throw const AuthException.red();

    await t.repo.cerrarSesion();

    expect(await t.almacen.leerRefreshToken(), isNull);
    expect(t.api.llamadas, contains('logout:refresh-1'));
  });

  test('borrar cuenta usa el access token vigente y limpia todo', () async {
    final t = crearRepo();
    t.api.onLogin = () async => sesion();
    t.api.onBorrar = (_, __) async {};
    await t.repo.iniciarSesion(email: 'a', password: 'b');

    await t.repo.borrarCuenta('clave');

    expect(t.api.llamadas.last, 'borrar:access-1');
    expect(await t.almacen.leerRefreshToken(), isNull);
  });

  test('borrar cuenta con access token vencido renueva primero', () async {
    final t = crearRepo();
    t.api.onLogin = () async => sesion();
    t.api.onRefresh = (_) async => sesion(n: 2);
    t.api.onBorrar = (_, __) async {};
    await t.repo.iniciarSesion(email: 'a', password: 'b');
    t.reloj.avanzar(const Duration(minutes: 20)); // pasó la vida del token

    await t.repo.borrarCuenta('clave');

    expect(t.api.llamadas, ['login', 'refrescar:refresh-1', 'borrar:access-2']);
  });

  test(
    'borrar cuenta: si el servidor da 401 renueva y reintenta una vez',
    () async {
      final t = crearRepo();
      t.api.onLogin = () async => sesion();
      t.api.onRefresh = (_) async => sesion(n: 2);
      var intentos = 0;
      t.api.onBorrar = (token, _) async {
        if (++intentos == 1) throw errorApi(401, 'no_autenticado');
      };
      await t.repo.iniciarSesion(email: 'a', password: 'b');

      await t.repo.borrarCuenta('clave');

      expect(t.api.llamadas.last, 'borrar:access-2');
    },
  );

  test(
    'borrar cuenta con contraseña incorrecta (403) no toca la sesión',
    () async {
      final t = crearRepo();
      t.api.onLogin = () async => sesion();
      t.api.onBorrar = (_, __) async =>
          throw errorApi(403, 'password_incorrecta');
      await t.repo.iniciarSesion(email: 'a', password: 'b');

      await expectLater(
        t.repo.borrarCuenta('mala'),
        throwsA(isA<AuthException>()),
      );
      expect(await t.almacen.leerRefreshToken(), 'refresh-1');
    },
  );

  test('borrar sin sesión guardada → sesión expirada', () async {
    final t = crearRepo();
    await expectLater(
      t.repo.borrarCuenta('x'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.esSesionInvalida,
          'inválida',
          true,
        ),
      ),
    );
  });

  test('tokenDeAcceso reutiliza el vigente y renueva el vencido', () async {
    final t = crearRepo();
    t.api.onLogin = () async => sesion();
    t.api.onRefresh = (_) async => sesion(n: 2);
    await t.repo.iniciarSesion(email: 'a', password: 'b');

    expect(await t.repo.tokenDeAcceso(), 'access-1');
    expect(t.api.llamadas, ['login']); // sin llamadas extra

    t.reloj.avanzar(const Duration(minutes: 20));
    expect(await t.repo.tokenDeAcceso(), 'access-2');
  });
}
