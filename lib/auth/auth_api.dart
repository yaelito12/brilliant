import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_models.dart';

/// Cliente HTTP del servidor de autenticación (proyecto aparte `brilliant_server`).
class AuthApi {
  final Duration timeout;
  final http.Client _client;

  String _baseUrl;

  AuthApi({
    required String baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _baseUrl = _sinBarraFinal(baseUrl),
       _client = client ?? http.Client();

  /// Dirección del servidor. Se puede cambiar en marcha: el jugador la escribe
  /// en la pantalla "Servidor" (ver `ConfigServidor`).
  String get baseUrl => _baseUrl;

  set baseUrl(String url) => _baseUrl = _sinBarraFinal(url);

  static String _sinBarraFinal(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  /// Comprueba que en [baseUrl] haya un servidor de Brilliant escuchando
  /// (`GET /health`). Lanza [AuthException] si no contesta o si contesta otra
  /// cosa. Sirve para avisar en el momento de escribir la dirección, en vez de
  /// fallar después al iniciar sesión.
  static Future<void> comprobar(
    String baseUrl, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final api = AuthApi(baseUrl: baseUrl, client: client, timeout: timeout);
    try {
      final json = await api._enviar('GET', '/health');
      if (json?['ok'] == true) return;
    } on AuthException catch (e) {
      // Sin conexión o sin dirección: ese error ya se explica solo.
      if (e.code == 'sin_conexion' || e.code == 'sin_servidor') rethrow;
    } finally {
      if (client == null) api.close();
    }
    throw const AuthException(
      status: 0,
      code: 'no_es_brilliant',
      message: 'Esa dirección contesta, pero no es el servidor de Brilliant.',
    );
  }

  Future<Sesion> registrar({
    required String nametag,
    required String password,
  }) async {
    final json = await _enviar(
      'POST',
      '/auth/register',
      cuerpo: {'nametag': nametag, 'password': password},
    );
    return _sesion(json);
  }

  Future<Sesion> iniciarSesion({
    required String nametag,
    required String password,
  }) async {
    final json = await _enviar(
      'POST',
      '/auth/login',
      cuerpo: {'nametag': nametag, 'password': password},
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

  /// Comprueba que la sesión siga abierta (GET /account/me).
  Future<Usuario> yo(String accessToken) async {
    final json = await _enviar('GET', '/account/me', token: accessToken);
    try {
      return Usuario.fromJson(json!['user'] as Map<String, dynamic>);
    } catch (_) {
      throw _respuestaInesperada(200);
    }
  }

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
    // Sin dirección no hay a dónde enviar nada (móvil recién instalado).
    if (_baseUrl.isEmpty) throw const AuthException.sinServidor();

    final http.Response res;
    try {
      res = await Future<http.Response>(() async {
        final req = http.Request(metodo, Uri.parse('$_baseUrl$ruta'))
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
