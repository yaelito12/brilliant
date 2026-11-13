import 'dart:async';
import 'dart:convert';

import 'package:brilliant/auth/auth_models.dart';
import 'package:brilliant/multijugador/conexion_multijugador.dart';

/// Un WebSocket falso: lo que manda la app queda en [enviados] y con
/// [servidor] se simulan mensajes del servidor.
class FakeTransporte implements TransporteWs {
  final _ctrl = StreamController<dynamic>();
  final _listo = Completer<void>();
  final enviados = <Map<String, dynamic>>[];
  bool cerrado = false;

  @override
  int? codigoCierre;

  FakeTransporte({bool falla = false}) {
    falla ? _listo.completeError(Exception('no se pudo abrir')) : _listo.complete();
  }

  @override
  Future<void> get listo => _listo.future;
  @override
  Stream<dynamic> get mensajes => _ctrl.stream;
  @override
  void enviar(String texto) => enviados.add(jsonDecode(texto) as Map<String, dynamic>);
  @override
  Future<void> cerrar() async {
    cerrado = true;
    if (!_ctrl.isClosed) await _ctrl.close();
  }

  List<String> get tipos => [for (final m in enviados) m['tipo'] as String];

  void servidor(Map<String, Object?> m) => _ctrl.add(jsonEncode(m));

  /// El servidor cierra con [codigo] (null = se cortó la red).
  void cortar([int? codigo]) {
    codigoCierre = codigo;
    _ctrl.close();
  }

  void autenticar({String id = 'u1', String nametag = 'Ana', Map<String, Object?>? sala}) =>
      servidor({
        'tipo': 'autenticado',
        'user': {'id': id, 'nametag': nametag},
        'sala': sala,
      });
}

/// Abre [FakeTransporte]s y los guarda para inspeccionarlos.
class FakeServidor {
  final abiertos = <FakeTransporte>[];
  bool fallar = false;

  FakeTransporte get ultimo => abiertos.last;

  TransporteWs abrir(Uri url) {
    final t = FakeTransporte(falla: fallar);
    abiertos.add(t);
    return t;
  }
}

/// Token de prueba: anota si se pidió renovar.
class FakeToken {
  final pedidos = <bool>[];
  AuthException? error;
  int n = 0;

  Future<String> call({bool forzarRenovacion = false}) async {
    pedidos.add(forzarRenovacion);
    final e = error;
    if (e != null) throw e;
    return 'token-${++n}';
  }
}

ConexionMultijugador conexionFalsa(
  FakeServidor servidor,
  FakeToken token, {
  Duration intervaloPing = const Duration(seconds: 10),
  Duration tiempoSinRespuesta = const Duration(seconds: 25),
}) => ConexionMultijugador(
  url: Uri.parse('ws://prueba/ws'),
  token: token.call,
  abrir: servidor.abrir,
  intervaloPing: intervaloPing,
  tiempoSinRespuesta: tiempoSinRespuesta,
  esperas: const [Duration(milliseconds: 5), Duration(milliseconds: 10)],
);

Map<String, Object?> salaJson({
  String codigo = 'K7M2QX',
  String estado = 'lobby',
  int segundosTurno = 0,
  List<Map<String, Object?>>? jugadores,
}) => {
  'codigo': codigo,
  'estado': estado,
  'segundosTurno': segundosTurno,
  'minJugadores': 2,
  'maxJugadores': 6,
  'jugadores': jugadores ??
      [
        {'id': 'u1', 'nametag': 'Ana', 'nivel': 1, 'listo': false, 'conectado': true},
      ],
};

Map<String, Object?> jugadorJson(String id, String nametag,
        {int nivel = 1, bool listo = false, bool conectado = true}) =>
    {'id': id, 'nametag': nametag, 'nivel': nivel, 'listo': listo, 'conectado': conectado};

/// Deja correr los microtasks y timers pendientes.
Future<void> pasa([int ms = 0]) => Future<void>.delayed(Duration(milliseconds: ms));

Map<String, Object?> jugadorPartidaJson(
  String id,
  String nametag, {
  int nivel = 1,
  String estado = 'jugando',
  bool conectado = true,
  bool yaJugo = false,
  int puntos = 0,
  bool completo = false,
  List<List<int>> celdas = const [],
  Map<String, int> lugares = const {},
}) => {
  'id': id,
  'nametag': nametag,
  'nivel': nivel,
  'estado': estado,
  'conectado': conectado,
  'yaJugo': yaJugo,
  'puntos': puntos,
  'completo': completo,
  'celdas': celdas,
  'lugares': lugares,
};

/// Iniciales válidos del nivel 1.
const iniciales1 = [[0, 2, 1], [1, 5, 2], [3, 1, 3], [3, 4, 4], [5, 2, 5], [6, 4, 6]];

Map<String, Object?> partidaJson({
  String fase = 'jugando',
  int ronda = 1,
  List<int>? dados = const [1, 3],
  int? msRestantes,
  List<Map<String, Object?>>? jugadores,
}) => {
  'fase': fase,
  'ronda': ronda,
  'maxRondas': 100,
  'puntosMeta': 26,
  'dados': fase == 'iniciales' ? null : dados,
  'msRestantes': msRestantes,
  'jugadores': jugadores ??
      [
        jugadorPartidaJson('u1', 'Ana', celdas: fase == 'iniciales' ? [] : iniciales1),
        jugadorPartidaJson('u2', 'Beto', nivel: 3),
      ],
};
