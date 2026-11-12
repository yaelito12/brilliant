import 'package:flutter/foundation.dart';

const String _apiUrlDefinida = String.fromEnvironment('API_URL');

/// Puerto en el que escucha `brilliant_server` si no se dice otro.
const int puertoServidorPorDefecto = 3000;

/// En web no hace falta preguntar nada: el servidor está en el mismo equipo
/// que sirvió la página. En móvil y escritorio sí, y la dirección se guarda.
final bool sePuedeElegirServidor = !kIsWeb;

bool get _esMovil =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Dirección del servidor con la que arranca la app cuando el jugador todavía
/// no eligió ninguna.
///
/// - Si se compiló con `--dart-define=API_URL=...`, esa (sigue sirviendo para
///   producción: `flutter build apk --dart-define=API_URL=https://api.tudominio.com`).
/// - En web, el mismo equipo desde el que se abrió la página (puerto 3000).
///   Así, quien entra con `http://<IP>:5000` desde otro dispositivo habla con
///   el servidor de esa misma IP, y no con su propio "localhost".
/// - En escritorio, `localhost`: el servidor suele estar en la misma PC.
/// - En móvil, vacía: el servidor está en otra máquina y no hay forma de
///   adivinar su IP, así que la app la pide (ver `ConfigServidor`).
final String apiUrlInicial = _apiUrlDefinida.isNotEmpty
    ? normalizarDireccionServidor(_apiUrlDefinida) ?? ''
    : kIsWeb
    ? 'http://${Uri.base.host}:$puertoServidorPorDefecto'
    : _esMovil
    ? ''
    : 'http://localhost:$puertoServidorPorDefecto';

/// Convierte lo que escribe el jugador en una dirección completa del servidor.
///
/// Acepta `192.168.1.9`, `192.168.1.9:3000`, `http://192.168.1.9:3000/` o
/// `https://api.midominio.com`. Si falta el puerto y es `http`, se usa el
/// [puertoServidorPorDefecto]. Devuelve `null` si no se entiende.
String? normalizarDireccionServidor(String entrada) {
  var texto = entrada.trim();
  if (texto.isEmpty || texto.contains(RegExp(r'\s'))) return null;
  if (!texto.contains('://')) texto = 'http://$texto';

  final Uri u;
  try {
    u = Uri.parse(texto);
  } on FormatException {
    return null;
  }
  if (u.scheme != 'http' && u.scheme != 'https') return null;
  if (u.host.isEmpty) return null;

  if (!u.hasPort) {
    // Un dominio con https usa el 443: no hace falta escribirlo.
    return u.scheme == 'https'
        ? 'https://${u.host}'
        : 'http://${u.host}:$puertoServidorPorDefecto';
  }
  if (u.port < 1 || u.port > 65535) return null;
  return '${u.scheme}://${u.host}:${u.port}';
}

/// Dirección del WebSocket del multijugador: la misma que la de la API pero con
/// `ws://` (o `wss://` si usa HTTPS) y la ruta `/ws`.
Uri wsUrlDesde(String api) {
  final u = Uri.parse(api);
  return u.replace(scheme: u.scheme == 'https' ? 'wss' : 'ws', path: '/ws');
}
