import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../auth/auth_models.dart';

/// Lo mínimo que se necesita de un WebSocket. Permite usar uno falso en las
/// pruebas.
abstract class TransporteWs {
  /// Termina cuando la conexión queda lista; falla si no se pudo abrir.
  Future<void> get listo;
  Stream<dynamic> get mensajes;
  void enviar(String texto);
  Future<void> cerrar();

  /// Código con que la cerró el servidor (null si se cortó la red).
  int? get codigoCierre;
}

typedef AbrirTransporte = TransporteWs Function(Uri url);

class _TransporteCanal implements TransporteWs {
  final WebSocketChannel _canal;
  _TransporteCanal(this._canal);

  @override
  Future<void> get listo => _canal.ready;
  @override
  Stream<dynamic> get mensajes => _canal.stream;
  @override
  void enviar(String texto) => _canal.sink.add(texto);
  @override
  Future<void> cerrar() => _canal.sink.close();
  @override
  int? get codigoCierre => _canal.closeCode;
}

/// WebSocket real (sirve en móvil, escritorio y web).
TransporteWs abrirWebSocket(Uri url) => _TransporteCanal(WebSocketChannel.connect(url));

enum EstadoConexion {
  /// Abriendo la primera conexión.
  conectando,

  /// Conectado y autenticado: se pueden mandar mensajes.
  conectado,

  /// Se perdió la conexión y se está reintentando solo.
  reconectando,

  /// La cuenta se abrió en otra conexión. No se reintenta solo.
  sesionReemplazada,

  /// La sesión venció (hay que volver a iniciar sesión).
  sinSesion,

  /// Se entró con la cuenta en otro dispositivo: esta sesión se cerró.
  sesionCerrada,

  /// Cerrada a propósito.
  cerrada,
}

/// Códigos de cierre del servidor (ver MULTIJUGADOR.md en brilliant_server).
abstract final class CodigoCierre {
  static const apagando = 4000;
  static const noAutenticado = 4001;
  static const sesionReemplazada = 4002;
  static const protocolo = 4003;
  static const sesionCerrada = 4004;
}

/// Conexión al multijugador que se mantiene sola:
///
/// - Se autentica con el access token de la cuenta.
/// - Si se corta (Wi-Fi, datos, servidor reiniciado) reintenta con espera
///   creciente: 1 s, 2 s, 4 s, 8 s y después cada 15 s.
/// - Manda un `ping` cada [intervaloPing]. Si no llega nada del servidor en
///   [tiempoSinRespuesta], da la conexión por muerta y reconecta (en algunos
///   cortes de red el socket no avisa nunca).
/// - Si el servidor rechaza el token (4001) pide uno nuevo y reintenta.
class ConexionMultijugador {
  final Uri url;
  final Future<String> Function({bool forzarRenovacion}) _token;
  final AbrirTransporte _abrir;
  final Duration intervaloPing;
  final Duration tiempoSinRespuesta;
  final Duration tiempoParaAbrir;
  final List<Duration> esperas;

  final _mensajes = StreamController<Map<String, dynamic>>.broadcast();
  final _estados = StreamController<EstadoConexion>.broadcast();

  EstadoConexion _estado = EstadoConexion.conectando;
  TransporteWs? _transporte;
  StreamSubscription<dynamic>? _sub;
  Timer? _reintento;
  Timer? _ping;
  DateTime _ultimoRecibido = DateTime.now();
  bool _forzarToken = false;
  int _rechazosSeguidos = 0;
  bool _cerrada = false;
  bool _iniciada = false;

  /// Reintentos seguidos sin lograr conectar.
  int intentos = 0;

  ConexionMultijugador({
    required this.url,
    required Future<String> Function({bool forzarRenovacion}) token,
    AbrirTransporte? abrir,
    this.intervaloPing = const Duration(seconds: 10),
    this.tiempoSinRespuesta = const Duration(seconds: 25),
    this.tiempoParaAbrir = const Duration(seconds: 10),
    this.esperas = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 15),
    ],
  }) : _token = token,
       _abrir = abrir ?? abrirWebSocket;

  /// Mensajes del servidor (sin los `pong`).
  Stream<Map<String, dynamic>> get mensajes => _mensajes.stream;
  Stream<EstadoConexion> get estados => _estados.stream;
  EstadoConexion get estado => _estado;

  void iniciar() {
    if (_iniciada) return;
    _iniciada = true;
    _conectar();
  }

  /// Manda un mensaje. Devuelve false si ahora mismo no hay conexión.
  bool enviar(Map<String, Object?> mensaje) {
    final t = _transporte;
    if (_estado != EstadoConexion.conectado || t == null) return false;
    t.enviar(jsonEncode(mensaje));
    return true;
  }

  /// Reconecta ya, sin esperar (por ejemplo después de "sesión reemplazada").
  void reconectarAhora() {
    if (_cerrada) return;
    _reintento?.cancel();
    intentos = 0;
    _rechazosSeguidos = 0;
    _soltarTransporte();
    _conectar();
  }

  Future<void> cerrar() async {
    if (_cerrada) return;
    _cerrada = true;
    _reintento?.cancel();
    _cambiar(EstadoConexion.cerrada);
    _soltarTransporte();
    await _mensajes.close();
    await _estados.close();
  }

  Future<void> _conectar() async {
    if (_cerrada) return;
    _cambiar(intentos == 0 && _estado == EstadoConexion.conectando
        ? EstadoConexion.conectando
        : EstadoConexion.reconectando);
    try {
      final token = await _token(forzarRenovacion: _forzarToken);
      _forzarToken = false;
      if (_cerrada) return;
      final t = _abrir(url);
      _transporte = t;
      _sub = t.mensajes.listen(
        (dato) => _alRecibir(t, dato),
        onDone: () => _alCerrarse(t),
        onError: (_) {}, // termina en onDone
      );
      await t.listo.timeout(tiempoParaAbrir);
      if (_cerrada || !identical(_transporte, t)) return;
      _ultimoRecibido = DateTime.now();
      t.enviar(jsonEncode({'tipo': 'auth', 'token': token}));
      _iniciarPing(t);
    } on AuthException catch (e) {
      if (e.esSesionInvalida) {
        _soltarTransporte();
        return _cambiar(
          e.esSesionReemplazada ? EstadoConexion.sesionCerrada : EstadoConexion.sinSesion,
        );
      }
      _reintentarLuego(); // sin red para renovar el token
    } catch (_) {
      _soltarTransporte();
      if (!(_reintento?.isActive ?? false)) _reintentarLuego(); // onDone pudo adelantarse
    }
  }

  void _alRecibir(TransporteWs t, dynamic dato) {
    if (!identical(_transporte, t) || dato is! String) return;
    _ultimoRecibido = DateTime.now();
    final Object? msg;
    try {
      msg = jsonDecode(dato);
    } on FormatException {
      return;
    }
    if (msg is! Map<String, dynamic>) return;
    final tipo = msg['tipo'];
    if (tipo == 'pong') return;
    if (tipo == 'autenticado') {
      intentos = 0;
      _rechazosSeguidos = 0;
      _cambiar(EstadoConexion.conectado);
    }
    _mensajes.add(msg);
  }

  void _alCerrarse(TransporteWs t) {
    if (!identical(_transporte, t)) return; // una conexión vieja que ya soltamos
    final codigo = t.codigoCierre;
    _soltarTransporte();
    if (_cerrada) return;

    switch (codigo) {
      case CodigoCierre.sesionReemplazada:
        _cambiar(EstadoConexion.sesionReemplazada);
      case CodigoCierre.sesionCerrada:
        // Se entró con la cuenta en otro dispositivo: no se reintenta.
        _cambiar(EstadoConexion.sesionCerrada);
      case CodigoCierre.noAutenticado:
        // Token rechazado: se pide uno nuevo. Si lo rechaza otra vez, la
        // sesión ya no sirve.
        if (++_rechazosSeguidos > 2) return _cambiar(EstadoConexion.sinSesion);
        _forzarToken = true;
        _reintentarLuego();
      default:
        _reintentarLuego();
    }
  }

  void _reintentarLuego() {
    if (_cerrada) return;
    _cambiar(EstadoConexion.reconectando);
    final espera = esperas[intentos < esperas.length ? intentos : esperas.length - 1];
    intentos++;
    _reintento?.cancel();
    _reintento = Timer(espera, _conectar);
  }

  void _iniciarPing(TransporteWs t) {
    _ping?.cancel();
    _ping = Timer.periodic(intervaloPing, (_) {
      if (!identical(_transporte, t)) return;
      if (DateTime.now().difference(_ultimoRecibido) > tiempoSinRespuesta) {
        // Conexión muerta sin aviso: se descarta y se reconecta.
        _soltarTransporte();
        _reintentarLuego();
        return;
      }
      t.enviar(jsonEncode({'tipo': 'ping'}));
    });
  }

  void _soltarTransporte() {
    _ping?.cancel();
    _ping = null;
    _sub?.cancel();
    _sub = null;
    final t = _transporte;
    _transporte = null;
    if (t != null) unawaited(t.cerrar().catchError((_) {}));
  }

  void _cambiar(EstadoConexion e) {
    if (_estado == e) return;
    _estado = e;
    if (!_estados.isClosed) _estados.add(e);
  }
}
