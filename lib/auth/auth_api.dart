import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_models.dart';

/// Cliente HTTP del servidor de autenticación (carpeta `server/`).
class AuthApi {
  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  AuthApi({
    required String baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _client = client ?? http.Client();

  Future<Sesion> registrar({
    required String email,
    required String nombre,
    required String password,
  }) async {
    final json = await _enviar(
      'POST',
      '/auth/register',
      cuerpo: {'email': email, 'nombre': nombre, 'password': password},
    );
    return _sesion(json);
  }

  Future<Sesion> iniciarSesion({
    required String email,
    required String password,
  }) async {
    final json = await _enviar(
      'POST',
      '/auth/login',
      cuerpo: {'email': email, 'password': password},
    );
    return _sesion(json);
  }

  Future<Sesion> refrescar(String refreshToken) async {
    final json = await _enviar(
      'POST',
      '/auth/refresh',
      cuerpo: {'refreshToken': refreshToken},
    );
    return _sesion(json);
  }

  Future<void> cerrarSesion(String refreshToken) =>
      _enviar('POST', '/auth/logout', cuerpo: {'refreshToken': refreshToken});

  /// Borra la cuenta de forma permanente. Exige la contraseña otra vez.
  Future<void> borrarCuenta({
    required String accessToken,
    required String password,
  }) => _enviar(
    'POST',
    '/account/delete',
    cuerpo: {'password': password},
    token: accessToken,
  );

  Sesion _sesion(Map<String, dynamic>? json) {
    if (json == null) throw _respuestaInesperada(200);
    try {
      return Sesion.fromJson(json);
    } catch (_) {
      throw _respuestaInesperada(200);
    }
  }

  AuthException _respuestaInesperada(int status) => AuthException(
    status: status,
    code: 'respuesta_inesperada',
    message: 'El servidor respondió algo inesperado.',
  );

  Future<Map<String, dynamic>?> _enviar(
    String metodo,
    String ruta, {
    Map<String, Object?>? cuerpo,
    String? token,
  }) async {
    final http.Response res;
    try {
      res = await Future<http.Response>(() async {
        final req = http.Request(metodo, Uri.parse('$baseUrl$ruta'))
          ..headers['Accept'] = 'application/json';
        if (cuerpo != null) {
          req.headers['Content-Type'] = 'application/json';
          req.body = jsonEncode(cuerpo);
        }
        if (token != null) req.headers['Authorization'] = 'Bearer $token';
        return http.Response.fromStream(await _client.send(req));
      }).timeout(timeout);
    } on TimeoutException {
      throw const AuthException.red();
    } on Exception {
      // SocketException, ClientException, errores de TLS...
      throw const AuthException.red();
    }

    final ok = res.statusCode >= 200 && res.statusCode < 300;

    Map<String, dynamic>? json;
    if (res.bodyBytes.isNotEmpty) {
      try {
        json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      } catch (_) {
        throw _respuestaInesperada(res.statusCode);
      }
    }
    if (ok) return json;

    final error = json?['error'];
    if (error is! Map) throw _respuestaInesperada(res.statusCode);
    final campos = error['campos'];
    final espera = error['reintentarEnSegundos'];
    throw AuthException(
      status: res.statusCode,
      code: '${error['code'] ?? 'error'}',
      message: '${error['message'] ?? 'Ocurrió un error.'}',
      campos: campos is Map
          ? campos.map((k, v) => MapEntry('$k', '$v'))
          : const {},
      reintentarEnSegundos: espera is int ? espera : null,
    );
  }

  void close() => _client.close();
}
