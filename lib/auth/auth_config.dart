import 'package:flutter/foundation.dart' show kIsWeb;

const String _apiUrlDefinida = String.fromEnvironment('API_URL');

/// Dirección del servidor de autenticación.
///
/// Se cambia al compilar/ejecutar:
///   flutter run --dart-define=API_URL=http://10.0.2.2:3000   (emulador Android)
///   flutter run --dart-define=API_URL=https://api.tudominio.com   (producción)
///
/// Si no se define, en web se usa el mismo equipo desde el que se abrió la
/// página (puerto 3000). Así, quien entra con `http://<IP>:5000` desde otra PC
/// habla con el servidor de esa misma IP, y no con su propio "localhost".
final String apiUrl = _apiUrlDefinida.isNotEmpty
    ? _apiUrlDefinida
    : kIsWeb
        ? 'http://${Uri.base.host}:3000'
        : 'http://localhost:3000';

/// Dirección del WebSocket del multijugador: la misma que [apiUrl] pero con
/// `ws://` (o `wss://` si la API usa HTTPS) y la ruta `/ws`.
Uri wsUrlDesde(String api) {
  final u = Uri.parse(api);
  return u.replace(scheme: u.scheme == 'https' ? 'wss' : 'ws', path: '/ws');
}

final Uri wsUrl = wsUrlDesde(apiUrl);
