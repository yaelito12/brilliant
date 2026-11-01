import 'auth_api.dart';
import 'auth_models.dart';
import 'token_storage.dart';

/// Maneja la sesión: guarda el refresh token, mantiene el access token en
/// memoria y lo renueva solo cuando está por vencer.
class AuthRepository {
  final AuthApi _api;
  final TokenStorage _almacen;
  final DateTime Function() _ahora;

  String? _accessToken;
  DateTime? _accessExpira;
  Future<String>? _renovando;

  AuthRepository({
    required AuthApi api,
    required TokenStorage almacen,
    DateTime Function()? ahora,
  }) : _api = api,
       _almacen = almacen,
       _ahora = ahora ?? DateTime.now;

  Future<Usuario> registrar({
    required String email,
    required String nombre,
    required String password,
  }) async {
    final s = await _api.registrar(
      email: email,
      nombre: nombre,
      password: password,
    );
    await _guardar(s);
    return s.usuario;
  }

  Future<Usuario> iniciarSesion({
    required String email,
    required String password,
  }) async {
    final s = await _api.iniciarSesion(email: email, password: password);
    await _guardar(s);
    return s.usuario;
  }

  /// Al abrir la app: intenta continuar la sesión anterior.
  /// Devuelve null si no había sesión o ya no es válida. Si no hay red lanza
  /// [AuthException] y conserva el token para intentarlo la próxima vez.
  Future<Usuario?> restaurarSesion() async {
    final refresh = await _almacen.leerRefreshToken();
    if (refresh == null) return null;
    try {
      final s = await _api.refrescar(refresh);
      await _guardar(s);
      return s.usuario;
    } on AuthException catch (e) {
      if (e.status == 401) {
        await _limpiar();
        return null;
      }
      rethrow;
    }
  }

  /// Siempre cierra la sesión local, aunque el servidor no responda.
  Future<void> cerrarSesion() async {
    final refresh = await _almacen.leerRefreshToken();
    await _limpiar();
    if (refresh != null) {
      try {
        await _api.cerrarSesion(refresh);
      } on AuthException {
        // Mejor esfuerzo: el token del servidor vencerá solo.
      }
    }
  }

  /// Borra la cuenta del servidor (pide la contraseña) y la sesión local.
  Future<void> borrarCuenta(String password) async {
    var token = await _tokenDeAcceso();
    try {
      await _api.borrarCuenta(accessToken: token, password: password);
    } on AuthException catch (e) {
      if (e.status != 401) rethrow;
      // El access token venció justo ahora: se renueva y se reintenta una vez.
      token = await _renovar();
      await _api.borrarCuenta(accessToken: token, password: password);
    }
    await _limpiar();
  }

  /// Token de acceso vigente (lo renueva si está por vencer). Es lo que
  /// presentará la app al conectarse a una partida online.
  Future<String> tokenDeAcceso() => _tokenDeAcceso();

  Future<String> _tokenDeAcceso() async {
    final token = _accessToken;
    final expira = _accessExpira;
    if (token != null &&
        expira != null &&
        expira.isAfter(_ahora().add(const Duration(seconds: 30)))) {
      return token;
    }
    return _renovar();
  }

  Future<String> _renovar() =>
      _renovando ??= _hacerRenovacion().whenComplete(() => _renovando = null);

  Future<String> _hacerRenovacion() async {
    final refresh = await _almacen.leerRefreshToken();
    if (refresh == null) throw const AuthException.sesionExpirada();
    try {
      final s = await _api.refrescar(refresh);
      await _guardar(s);
      return s.accessToken;
    } on AuthException catch (e) {
      if (e.status == 401) {
        await _limpiar();
        throw const AuthException.sesionExpirada();
      }
      rethrow;
    }
  }

  Future<void> _guardar(Sesion s) async {
    _accessToken = s.accessToken;
    _accessExpira = _ahora().add(Duration(seconds: s.expiresIn));
    await _almacen.guardarRefreshToken(s.refreshToken);
  }

  Future<void> _limpiar() async {
    _accessToken = null;
    _accessExpira = null;
    await _almacen.borrar();
  }
}
