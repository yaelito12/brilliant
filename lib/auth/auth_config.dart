/// Dirección del servidor de autenticación.
///
/// Se cambia al compilar/ejecutar:
///   flutter run --dart-define=API_URL=http://10.0.2.2:3000   (emulador Android)
///   flutter run --dart-define=API_URL=https://api.tudominio.com   (producción)
const String apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:3000',
);

/// Dirección del WebSocket del multijugador: la misma que [apiUrl] pero con
/// `ws://` (o `wss://` si la API usa HTTPS) y la ruta `/ws`.
Uri wsUrlDesde(String api) {
  final u = Uri.parse(api);
  return u.replace(scheme: u.scheme == 'https' ? 'wss' : 'ws', path: '/ws');
}

final Uri wsUrl = wsUrlDesde(apiUrl);
