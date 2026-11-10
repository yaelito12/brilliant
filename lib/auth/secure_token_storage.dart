import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_storage.dart';

/// Guarda el refresh token en el almacén seguro del sistema
/// (Keychain en iOS/macOS, Keystore en Android, WebCrypto en web).
///
/// En web, WebCrypto solo existe en "contextos seguros" (https o localhost).
/// Si se abre el juego desde otro equipo con `http://<IP>:5000`, el almacén
/// seguro falla; en ese caso el token se guarda solo en memoria: se puede
/// jugar normalmente, pero al recargar la página hay que volver a entrar.
class SecureTokenStorage implements TokenStorage {
  static const _clave = 'brilliant_refresh_token';
  final FlutterSecureStorage _storage;

  /// Se activa la primera vez que el almacén seguro falla.
  TokenStorage? _respaldo;

  SecureTokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  Future<T> _usar<T>(
    Future<T> Function() seguro,
    Future<T> Function(TokenStorage respaldo) enMemoria,
  ) async {
    final respaldo = _respaldo;
    if (respaldo != null) return enMemoria(respaldo);
    try {
      return await seguro();
    } catch (_) {
      // Errores de JS (p. ej. crypto.subtle no existe) no son Exception.
      return enMemoria(_respaldo = MemoryTokenStorage());
    }
  }

  @override
  Future<String?> leerRefreshToken() => _usar(
    () => _storage.read(key: _clave),
    (r) => r.leerRefreshToken(),
  );

  @override
  Future<void> guardarRefreshToken(String token) => _usar(
    () => _storage.write(key: _clave, value: token),
    (r) => r.guardarRefreshToken(token),
  );

  @override
  Future<void> borrar() => _usar(
    () => _storage.delete(key: _clave),
    (r) => r.borrar(),
  );
}
