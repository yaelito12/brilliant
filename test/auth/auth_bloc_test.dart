import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/auth/auth_models.dart';
import 'package:brilliant/bloc/auth_bloc.dart';
import 'package:brilliant/bloc/auth_event.dart';
import 'package:brilliant/bloc/auth_state.dart';

import 'helpers.dart';

/// Envía [evento] y devuelve los estados que se emitieron.
Future<List<AuthState>> _correr(AuthBloc bloc, AuthEvent evento) async {
  final estados = <AuthState>[];
  final sub = bloc.stream.listen(estados.add);
  bloc.add(evento);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  await sub.cancel();
  return estados;
}

AuthEvent _login() => AuthLoginSolicitado(nametag: 'Ana', password: 'x');

void main() {
  late ({FakeApi api, AuthBloc bloc, dynamic almacen}) t;

  setUp(() {
    final r = crearRepo();
    t = (api: r.api, bloc: AuthBloc(r.repo), almacen: r.almacen);
  });

  test('empieza en desconocido', () {
    expect(t.bloc.state.estado, AuthEstado.desconocido);
  });

  test('arranque sin sesión → no autenticado', () async {
    final s = await _correr(t.bloc, AuthIniciada());
    expect(s.single.estado, AuthEstado.noAutenticado);
  });

  test('arranque sin red → no autenticado con mensaje', () async {
    await t.almacen.guardarRefreshToken('x');
    t.api.onRefresh = (_) async => throw const AuthException.red();
    final s = await _correr(t.bloc, AuthIniciada());
    expect(s.single.estado, AuthEstado.noAutenticado);
    expect(s.single.error, contains('conectar'));
  });

  test('login correcto: cargando → autenticado', () async {
    t.api.onLogin = () async => sesion();
    await _correr(t.bloc, AuthIniciada()); // la app arranca sin sesión
    final s = await _correr(t.bloc, _login());
    expect(s.map((e) => e.estado).toList(), [
      AuthEstado.noAutenticado,
      AuthEstado.autenticado,
    ]);
    expect(s.first.cargando, isTrue);
    expect(s.last.usuario, usuarioAna);
    expect(s.last.cargando, isFalse);
  });

  test('login con credenciales malas muestra el error', () async {
    t.api.onLogin = () async => throw errorApi(
      401,
      'credenciales_invalidas',
      'Nametag o contraseña incorrectos.',
    );
    final s = await _correr(t.bloc, _login());
    expect(s.last.estado, AuthEstado.noAutenticado);
    expect(s.last.error, 'Nametag o contraseña incorrectos.');
    expect(s.last.cargando, isFalse);
  });

  test('registro con nametag repetido marca el campo nametag', () async {
    t.api.onRegistro = () async =>
        throw errorApi(409, 'nametag_en_uso', 'Ese nametag ya está en uso.');
    final s = await _correr(
      t.bloc,
      AuthRegistroSolicitado(nametag: 'Ana', password: 'clave-larga-123'),
    );
    expect(s.last.errores['nametag'], contains('ya está en uso'));
    expect(s.last.error, isNull);
  });

  test('errores de validación del servidor van por campo', () async {
    t.api.onRegistro = () async => throw const AuthException(
      status: 400,
      code: 'validacion',
      message: 'x',
      campos: {'password': 'Muy fácil.'},
    );
    final s = await _correr(
      t.bloc,
      AuthRegistroSolicitado(nametag: 'Ana', password: 'clave-larga-123'),
    );
    expect(s.last.errores, {'password': 'Muy fácil.'});
  });

  test('cerrar sesión → no autenticado', () async {
    t.api.onLogin = () async => sesion();
    await _correr(t.bloc, _login());
    final s = await _correr(t.bloc, AuthLogoutSolicitado());
    expect(s.last.estado, AuthEstado.noAutenticado);
  });

  test('borrar cuenta con éxito → no autenticado con aviso', () async {
    t.api.onLogin = () async => sesion();
    t.api.onBorrar = (_, __) async {};
    await _correr(t.bloc, _login());
    final s = await _correr(t.bloc, AuthBorrarCuentaSolicitado('clave'));
    expect(s.last.estado, AuthEstado.noAutenticado);
    expect(s.last.info, contains('eliminada'));
  });

  test(
    'borrar cuenta con contraseña mala sigue autenticado y muestra error',
    () async {
      t.api.onLogin = () async => sesion();
      t.api.onBorrar = (_, __) async => throw errorApi(
        403,
        'password_incorrecta',
        'La contraseña es incorrecta.',
      );
      await _correr(t.bloc, _login());
      final s = await _correr(t.bloc, AuthBorrarCuentaSolicitado('mala'));
      expect(s.last.estado, AuthEstado.autenticado);
      expect(s.last.error, 'La contraseña es incorrecta.');
      expect(s.last.cargando, isFalse);
    },
  );

  test('borrar cuenta con sesión vencida lleva al login', () async {
    t.api.onLogin = () async => sesion();
    t.api.onBorrar = (_, __) async => throw errorApi(401, 'no_autenticado');
    t.api.onRefresh = (_) async => throw errorApi(401, 'refresh_invalido');
    await _correr(t.bloc, _login());
    final s = await _correr(t.bloc, AuthBorrarCuentaSolicitado('clave'));
    expect(s.last.estado, AuthEstado.noAutenticado);
    expect(s.last.info, contains('venció'));
  });

  test('limpiar mensajes quita el error', () async {
    t.api.onLogin = () async => throw errorApi(401, 'credenciales_invalidas');
    await _correr(t.bloc, _login());
    final s = await _correr(t.bloc, AuthMensajesLimpiados());
    expect(s.last.error, isNull);
  });
}
