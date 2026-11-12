import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_config.dart';

/// Dónde queda guardada la dirección del servidor entre arranques de la app.
abstract class AlmacenServidor {
  Future<String?> leer();
  Future<void> guardar(String url);
}

/// Solo en memoria: para pruebas y como respaldo si el almacén del sistema falla.
class AlmacenServidorEnMemoria implements AlmacenServidor {
  String? url;

  AlmacenServidorEnMemoria([this.url]);

  @override
  Future<String?> leer() async => url;

  @override
  Future<void> guardar(String nueva) async => url = nueva;
}

/// Guarda la dirección en el almacén del sistema (el mismo que el refresh
/// token). No es un secreto, pero así no hay que sumar otra dependencia.
class AlmacenServidorSeguro implements AlmacenServidor {
  static const _clave = 'brilliant_servidor_url';
  final FlutterSecureStorage _storage;

  AlmacenServidorSeguro([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> leer() async {
    try {
      return await _storage.read(key: _clave);
    } catch (_) {
      // En web sin HTTPS el almacén seguro no existe; no es un error fatal.
      return null;
    }
  }

  @override
  Future<void> guardar(String url) async {
    try {
      await _storage.write(key: _clave, value: url);
    } catch (_) {
      // Se sigue jugando con la dirección en memoria hasta cerrar la app.
    }
  }
}

/// La dirección del servidor que está usando la app.
///
/// En web se detecta sola y no se puede cambiar ([sePuedeCambiar] es `false`).
/// En móvil y escritorio el jugador la escribe en la pantalla "Servidor" y
/// queda guardada en el dispositivo, así que no hay que recompilar la app
/// cuando la PC que hace de servidor cambia de IP.
class ConfigServidor extends ChangeNotifier {
  final AlmacenServidor _almacen;

  /// Si el jugador puede escribir la dirección a mano.
  final bool sePuedeCambiar;

  String _url;

  ConfigServidor({
    String urlInicial = '',
    AlmacenServidor? almacen,
    bool? sePuedeCambiar,
  }) : _url = normalizarDireccionServidor(urlInicial) ?? '',
       _almacen = almacen ?? AlmacenServidorEnMemoria(),
       sePuedeCambiar = sePuedeCambiar ?? sePuedeElegirServidor;

  /// Dirección completa de la API, por ejemplo `http://192.168.1.9:3000`.
  /// Vacía si todavía no hay ninguna.
  String get url => _url;

  /// Si ya hay una dirección con la que intentar conectarse.
  bool get configurado => _url.isNotEmpty;

  /// Dirección del WebSocket del multijugador.
  Uri get ws => wsUrlDesde(_url);

  /// Versión corta para mostrar y para editar: sin el `http://` de más.
  String get paraMostrar => _url.startsWith('http://')
      ? _url.substring('http://'.length)
      : _url;

  /// Lee la dirección que el jugador guardó la última vez. Lo que haya
  /// guardado manda sobre el valor con el que se compiló la app.
  Future<void> cargar() async {
    if (!sePuedeCambiar) return;
    final guardada = normalizarDireccionServidor(await _almacen.leer() ?? '');
    if (guardada != null && guardada != _url) {
      _url = guardada;
      notifyListeners();
    }
  }

  /// Guarda la dirección que escribió el jugador. Devuelve `false` (y no
  /// cambia nada) si no se entiende lo que escribió.
  Future<bool> guardar(String entrada) async {
    final nueva = normalizarDireccionServidor(entrada);
    if (nueva == null) return false;
    await _almacen.guardar(nueva);
    if (nueva != _url) {
      _url = nueva;
      notifyListeners();
    }
    return true;
  }
}
