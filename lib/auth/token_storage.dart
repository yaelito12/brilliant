/// Dónde se guarda el refresh token entre sesiones de la app.
/// (El access token vive solo en memoria y nunca se guarda en disco.)
abstract class TokenStorage {
  Future<String?> leerRefreshToken();
  Future<void> guardarRefreshToken(String token);
  Future<void> borrar();
}

/// Para pruebas.
class MemoryTokenStorage implements TokenStorage {
  String? _token;

  @override
  Future<String?> leerRefreshToken() async => _token;

  @override
  Future<void> guardarRefreshToken(String token) async => _token = token;

  @override
  Future<void> borrar() async => _token = null;
}
