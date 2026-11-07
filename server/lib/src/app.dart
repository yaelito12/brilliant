import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import 'api_error.dart';
import 'config.dart';
import 'http_util.dart';
import 'seguridad.dart';
import 'validacion.dart';

typedef Usuario = ({String id, String nametag});

int _ahora() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

/// Servidor HTTP de cuentas: crear cuenta, iniciar/cerrar sesión, borrar cuenta.
class AppAuth {
  final Config config;
  final Database db;
  final Seguridad seg;
  final LimitePorIp _limiteGlobal;
  final LimitePorIp _limiteAuth;
  late final Handler handler;

  AppAuth({required this.config, required this.db, Router? rutasExtra})
    : seg = Seguridad(config),
      _limiteGlobal = LimitePorIp(
        ventana: const Duration(minutes: 15),
        limite: config.limiteGlobal,
      ),
      _limiteAuth = LimitePorIp(
        ventana: const Duration(minutes: 15),
        limite: config.limiteAuth,
      ) {
    var pipeline = const Pipeline().addMiddleware(manejarErrores());
    if (config.requireHttps) pipeline = pipeline.addMiddleware(exigirHttps(config));
    if (config.corsOrigins.isNotEmpty) {
      pipeline = pipeline.addMiddleware(cors(config.corsOrigins));
    }
    handler = pipeline
        .addMiddleware(limitarPorIp(_limiteGlobal, config))
        .addHandler(_rutas(rutasExtra).call);
    limpiar();
  }

  // ---------- Consultas ----------

  Map<String, Object?>? _fila(String sql, List<Object?> p) {
    final r = db.select(sql, p);
    return r.isEmpty ? null : r.first;
  }

  Map<String, Object?>? _usuarioPorNametag(String clave) =>
      _fila('SELECT * FROM users WHERE nametag_lower = ?', [clave]);

  Usuario? _usuarioPorId(String id) {
    final f = _fila('SELECT id, nametag FROM users WHERE id = ?', [id]);
    return f == null ? null : (id: f['id'] as String, nametag: f['nametag'] as String);
  }

  /// Si [fn] termina bien se guarda todo (incluso si devuelve un "error" de
  /// negocio); si lanza, se deshace. [fn] es síncrona: nadie más toca la base
  /// mientras corre.
  T _enTransaccion<T>(T Function() fn) {
    db.execute('BEGIN IMMEDIATE');
    try {
      final r = fn();
      db.execute('COMMIT');
      return r;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  // ---------- Bloqueo por intentos fallidos ----------

  int _segundosDeBloqueo(String clave) {
    final f = _fila('SELECT * FROM login_failures WHERE clave = ?', [seg.hashClaveUsuario(clave)]);
    final hasta = (f?['locked_until'] as int?) ?? 0;
    return hasta > _ahora() ? hasta - _ahora() : 0;
  }

  void _registrarFallo(String clave) {
    final key = seg.hashClaveUsuario(clave);
    final f = _fila('SELECT * FROM login_failures WHERE clave = ?', [key]);
    final hasta = (f?['locked_until'] as int?) ?? 0;
    // Si el bloqueo anterior ya venció, se empieza de cero.
    final previos = f != null && !(hasta != 0 && hasta <= _ahora()) ? f['count'] as int : 0;
    final cuenta = previos + 1;
    final lock = cuenta >= config.maxIntentosFallidos ? _ahora() + config.bloqueoSeg : 0;
    db.execute(
      '''INSERT INTO login_failures (clave, count, locked_until, updated_at) VALUES (?, ?, ?, ?)
         ON CONFLICT(clave) DO UPDATE SET count = excluded.count,
           locked_until = excluded.locked_until, updated_at = excluded.updated_at''',
      [key, lock != 0 ? 0 : cuenta, lock, _ahora()],
    );
  }

  void _limpiarFallos(String clave) =>
      db.execute('DELETE FROM login_failures WHERE clave = ?', [seg.hashClaveUsuario(clave)]);

  ApiError _bloqueado(int segundos) => ApiError(
    429,
    'cuenta_bloqueada',
    'Demasiados intentos fallidos. Inténtalo de nuevo más tarde.',
    {'reintentarEnSegundos': segundos},
  );

  // ---------- Sesiones (access + refresh con rotación) ----------

  Map<String, Object?> _emitirSesion(Usuario u, [String? familyId]) {
    final refreshToken = seg.nuevoRefreshToken();
    db.execute(
      '''INSERT INTO refresh_tokens (user_id, family_id, token_hash, expires_at, created_at)
         VALUES (?, ?, ?, ?, ?)''',
      [u.id, familyId ?? nuevoUuid(), seg.hashToken(refreshToken), _ahora() + config.refreshTtlSeg, _ahora()],
    );
    return {
      'accessToken': seg.crearAccessToken(u.id),
      'refreshToken': refreshToken,
      'expiresIn': config.accessTtlSeg,
      'user': {'id': u.id, 'nametag': u.nametag},
    };
  }

  /// Devuelve el usuario dueño de un access token, o null si no sirve.
  /// Se consulta la base para que el token de una cuenta ya borrada deje de
  /// servir al instante. La usan las rutas HTTP y el servidor de partidas.
  Usuario? autenticarToken(String? token) {
    if (token == null || !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(token)) return null;
    final id = seg.verificarAccessToken(token);
    return id == null ? null : _usuarioPorId(id);
  }

  Usuario _requiereAuth(Request req) {
    final m = RegExp(r'^Bearer (.+)$').firstMatch(req.headers['authorization'] ?? '');
    final u = m == null ? null : autenticarToken(m.group(1));
    if (u == null) throw ApiError(401, 'no_autenticado', 'Sesión inválida o vencida.');
    return u;
  }

  Handler _conLimiteAuth(Handler h) => (req) {
    final espera = _limiteAuth.registrar(ipCliente(req, config.trustProxy));
    if (espera != null) {
      throw ApiError(
        429,
        'demasiadas_peticiones',
        'Demasiadas peticiones. Espera unos minutos.',
        {'reintentarEnSegundos': espera},
      );
    }
    return h(req);
  };

  // ---------- Rutas ----------

  Router _rutas(Router? extra) {
    final r = Router(
      notFoundHandler: (_) =>
          throw ApiError(404, 'no_encontrado', 'Ruta no encontrada.'),
    );
    r.get('/health', (Request _) => respuestaJson(200, {'ok': true}));
    r.post('/auth/register', _conLimiteAuth(_registrar));
    r.post('/auth/login', _conLimiteAuth(_login));
    r.post('/auth/refresh', _conLimiteAuth(_refresh));
    r.post('/auth/logout', _conLimiteAuth(_logout));
    r.post('/auth/logout-all', _logoutAll);
    r.get('/account/me', (Request req) {
      final u = _requiereAuth(req);
      return respuestaJson(200, {'user': {'id': u.id, 'nametag': u.nametag}});
    });
    r.post('/account/delete', _conLimiteAuth(_borrarCuenta));
    if (extra != null) r.mount('/', extra.call);
    return r;
  }

  Future<Response> _registrar(Request req) async {
    final d = validarRegistro(await leerJson(req));
    final clave = d.nametag.toLowerCase();
    final enUso = ApiError(409, 'nametag_en_uso', 'Ese nametag ya está en uso.');

    if (_usuarioPorNametag(clave) != null) throw enUso;
    final hash = await seg.hashearPassword(d.password);
    final u = (id: nuevoUuid(), nametag: d.nametag);
    try {
      db.execute(
        'INSERT INTO users (id, nametag, nametag_lower, password_hash, created_at) VALUES (?, ?, ?, ?, ?)',
        [u.id, u.nametag, clave, hash, _ahora()],
      );
    } on SqliteException catch (e) {
      // Dos registros simultáneos del mismo nametag: gana el primero.
      if (e.message.contains('UNIQUE constraint failed')) throw enUso;
      rethrow;
    }
    return respuestaJson(201, _emitirSesion(u));
  }

  Future<Response> _login(Request req) async {
    final d = validarLogin(await leerJson(req));
    final clave = d.nametag.toLowerCase();

    final espera = _segundosDeBloqueo(clave);
    if (espera > 0) throw _bloqueado(espera);

    final fila = _usuarioPorNametag(clave);
    var ok = false;
    if (fila != null) {
      ok = await seg.verificarPassword(fila['password_hash'] as String, d.password);
    } else {
      await seg.verificarContraSenuelo(d.password); // mismo coste de tiempo
    }
    if (!ok) {
      _registrarFallo(clave);
      throw ApiError(401, 'credenciales_invalidas', 'Nametag o contraseña incorrectos.');
    }
    _limpiarFallos(clave);
    final u = (id: fila!['id'] as String, nametag: fila['nametag'] as String);
    return respuestaJson(200, _emitirSesion(u));
  }

  Future<Response> _refresh(Request req) async {
    final refreshToken = validarRefresh(await leerJson(req));
    final hash = seg.hashToken(refreshToken);

    // Rotación: cada refresh token sirve UNA vez. Si alguien reutiliza uno ya
    // usado, se asume robo y se revoca toda la familia de sesiones.
    final resultado = _enTransaccion<({String userId, String familyId})?>(() {
      final t = _fila('SELECT * FROM refresh_tokens WHERE token_hash = ?', [hash]);
      if (t == null) return null;
      if (t['revoked_at'] != null || t['used_at'] != null) {
        db.execute(
          'UPDATE refresh_tokens SET revoked_at = ? WHERE family_id = ? AND revoked_at IS NULL',
          [_ahora(), t['family_id']],
        );
        return null;
      }
      if ((t['expires_at'] as int) < _ahora()) return null;
      db.execute(
        'UPDATE refresh_tokens SET used_at = ? WHERE id = ? AND used_at IS NULL',
        [_ahora(), t['id']],
      );
      if (db.updatedRows != 1) return null;
      return (userId: t['user_id'] as String, familyId: t['family_id'] as String);
    });

    final invalido = ApiError(401, 'refresh_invalido', 'Sesión inválida o vencida.');
    if (resultado == null) throw invalido;
    final u = _usuarioPorId(resultado.userId);
    if (u == null) throw invalido;
    return respuestaJson(200, _emitirSesion(u, resultado.familyId));
  }

  Future<Response> _logout(Request req) async {
    final refreshToken = validarRefresh(await leerJson(req));
    final t = _fila(
      'SELECT family_id FROM refresh_tokens WHERE token_hash = ?',
      [seg.hashToken(refreshToken)],
    );
    if (t != null) {
      db.execute(
        'UPDATE refresh_tokens SET revoked_at = ? WHERE family_id = ? AND revoked_at IS NULL',
        [_ahora(), t['family_id']],
      );
    }
    return Response(204); // siempre 204: no revela si el token existía
  }

  Response _logoutAll(Request req) {
    final u = _requiereAuth(req);
    db.execute(
      'UPDATE refresh_tokens SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL',
      [_ahora(), u.id],
    );
    return Response(204);
  }

  // Borrar la cuenta exige la contraseña otra vez (re-autenticación): un token
  // robado por sí solo no basta para destruir la cuenta.
  Future<Response> _borrarCuenta(Request req) async {
    final u = _requiereAuth(req);
    final password = validarBorrarCuenta(await leerJson(req));
    final clave = u.nametag.toLowerCase();

    final espera = _segundosDeBloqueo(clave);
    if (espera > 0) throw _bloqueado(espera);

    final hash = _fila('SELECT password_hash FROM users WHERE id = ?', [u.id])?['password_hash'];
    if (hash is! String || !await seg.verificarPassword(hash, password)) {
      _registrarFallo(clave);
      throw ApiError(403, 'password_incorrecta', 'La contraseña es incorrecta.');
    }
    _limpiarFallos(clave);
    db.execute('DELETE FROM users WHERE id = ?', [u.id]); // ON DELETE CASCADE borra sus tokens
    return Response(204);
  }

  /// Limpieza periódica de datos vencidos.
  void limpiar() {
    final t = _ahora();
    db.execute(
      'DELETE FROM refresh_tokens WHERE expires_at < ? OR (revoked_at IS NOT NULL AND revoked_at < ?)',
      [t, t - 7 * 24 * 3600],
    );
    db.execute('DELETE FROM login_failures WHERE updated_at < ?', [t - 24 * 3600]);
    _limiteGlobal.limpiar();
    _limiteAuth.limpiar();
  }
}
