import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:brilliant/auth/auth_api.dart';
import 'package:brilliant/auth/auth_models.dart';

const _sesionJson = {
  'accessToken': 'a',
  'refreshToken': 'r',
  'expiresIn': 900,
  'user': {'id': 'u1', 'email': 'ana@example.com', 'nombre': 'Ana'},
};

http.Response _json(int status, Object body, [Map<String, String>? h]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json', ...?h},
    );

AuthApi _api(MockClient c) => AuthApi(baseUrl: 'http://srv/', client: c);

Future<AuthException> _falla(Future<void> Function() f) async {
  try {
    await f();
  } on AuthException catch (e) {
    return e;
  }
  throw StateError('Se esperaba una AuthException');
}

void main() {
  test('registrar manda los datos como JSON y lee la sesión', () async {
    late http.Request visto;
    final api = _api(
      MockClient((req) async {
        visto = req;
        return _json(201, _sesionJson);
      }),
    );

    final s = await api.registrar(
      email: 'ana@example.com',
      nombre: 'Ana',
      password: 'clave-larga-123',
    );

    expect(visto.method, 'POST');
    expect(visto.url.toString(), 'http://srv/auth/register');
    expect(visto.headers['Content-Type'], contains('application/json'));
    expect(jsonDecode(visto.body), {
      'email': 'ana@example.com',
      'nombre': 'Ana',
      'password': 'clave-larga-123',
    });
    expect(s.accessToken, 'a');
    expect(s.usuario.nombre, 'Ana');
  });

  test('borrarCuenta manda el Bearer y acepta 204', () async {
    late http.Request visto;
    final api = _api(
      MockClient((req) async {
        visto = req;
        return http.Response('', 204);
      }),
    );

    await api.borrarCuenta(accessToken: 'tok', password: 'clave');

    expect(visto.url.path, '/account/delete');
    expect(visto.headers['Authorization'], 'Bearer tok');
  });

  test('errores del servidor se convierten en AuthException', () async {
    final api = _api(
      MockClient(
        (_) async => _json(401, {
          'error': {
            'code': 'credenciales_invalidas',
            'message': 'Correo o contraseña incorrectos.',
          },
        }),
      ),
    );

    final e = await _falla(
      () => api.iniciarSesion(email: 'a@b.co', password: 'x'),
    );
    expect(e.status, 401);
    expect(e.code, 'credenciales_invalidas');
    expect(e.message, 'Correo o contraseña incorrectos.');
  });

  test('errores de validación traen los campos', () async {
    final api = _api(
      MockClient(
        (_) async => _json(400, {
          'error': {
            'code': 'validacion',
            'message': 'Hay datos inválidos.',
            'campos': {'password': 'Muy corta.'},
          },
        }),
      ),
    );

    final e = await _falla(
      () => api.registrar(email: 'a@b.co', nombre: 'Ana', password: 'x'),
    );
    expect(e.campos, {'password': 'Muy corta.'});
  });

  test('bloqueo: lee los segundos de espera y arma el mensaje', () async {
    final api = _api(
      MockClient(
        (_) async => _json(429, {
          'error': {
            'code': 'cuenta_bloqueada',
            'message': 'Demasiados intentos fallidos.',
            'reintentarEnSegundos': 600,
          },
        }),
      ),
    );

    final e = await _falla(
      () => api.iniciarSesion(email: 'a@b.co', password: 'x'),
    );
    expect(e.reintentarEnSegundos, 600);
    expect(e.mensajeParaUsuario, contains('10 minutos'));
  });

  test('sin red → AuthException.red', () async {
    final api = _api(MockClient((_) async => throw http.ClientException('x')));
    final e = await _falla(
      () => api.iniciarSesion(email: 'a@b.co', password: 'x'),
    );
    expect(e.code, 'sin_conexion');
    expect(e.status, 0);
  });

  test('respuesta que no es JSON → respuesta_inesperada', () async {
    final api = _api(MockClient((_) async => http.Response('<html>', 502)));
    final e = await _falla(
      () => api.iniciarSesion(email: 'a@b.co', password: 'x'),
    );
    expect(e.code, 'respuesta_inesperada');
  });

  test('éxito con JSON incompleto → respuesta_inesperada', () async {
    final api = _api(MockClient((_) async => _json(200, {'foo': 1})));
    final e = await _falla(
      () => api.iniciarSesion(email: 'a@b.co', password: 'x'),
    );
    expect(e.code, 'respuesta_inesperada');
  });
}
