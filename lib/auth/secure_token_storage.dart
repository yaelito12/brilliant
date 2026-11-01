import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_storage.dart';

/// Guarda el refresh token en el almacén seguro del sistema
/// (Keychain en iOS/macOS, Keystore en Android).
class SecureTokenStorage implements TokenStorage {
  static const _clave = 'brilliant_refresh_token';
  final FlutterSecureStorage _storage;

  SecureTokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> leerRefreshToken() => _storage.read(key: _clave);

  @override
  Future<void> guardarRefreshToken(String token) =>
      _storage.write(key: _clave, value: token);

  @override
  Future<void> borrar() => _storage.delete(key: _clave);
}
