import 'package:brilliant/auth/auth_config.dart';
import 'package:brilliant/auth/auth_models.dart';
import 'package:brilliant/multijugador/conexion_multijugador.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late FakeServidor servidor;
  late FakeToken token;
  ConexionMultijugador? abierta;
  late ConexionMultijugador conexion;
  late List<Map<String, dynamic>> recibidos;

  setUp(() {
    servidor = FakeServidor();
    token = FakeToken();
    recibidos = [];
  });
  tearDown(() async => abierta?.cerrar());

  Future<void> iniciar({Duration? ping, Duration? sinRespuesta}) async {
    abierta = conexion = conexionFalsa(
      servidor,
      token,
      intervaloPing: ping ?? const Duration(seconds: 10),
      tiempoSinRespuesta: sinRespuesta ?? const Duration(seconds: 25),
    );
    conexion.mensajes.listen(recibidos.add);
    conexion.iniciar();
    await pasa();
  }

  test('la URL del WebSocket sale de la API (ws o wss)', () {
    expect(wsUrlDesde('http://localhost:3000').toString(), 'ws://localhost:3000/ws');
    expect(wsUrlDesde('https://api.x.com').toString(), 'wss://api.x.com/ws');
  });

  test('se autentica con el token y queda conectada', () async {
    await iniciar();
    expect(conexion.estado, EstadoConexion.conectando);
    expect(servidor.ultimo.enviados.single, {'tipo': 'auth', 'token': 'token-1'});
    expect(conexion.enviar({'tipo': 'ping'}), isFalse, reason: 'aún no autenticada');

    servidor.ultimo.autenticar();
    await pasa();
    expect(conexion.estado, EstadoConexion.conectado);
    expect(recibidos.single['tipo'], 'autenticado');

    expect(conexion.enviar({'tipo': 'crear_sala', 'nivel': 1}), isTrue);
    expect(servidor.ultimo.tipos.last, 'crear_sala');

    servidor.ultimo.servidor({'tipo': 'pong'});
    await pasa();
    expect(recibidos, hasLength(1), reason: 'los pong no se reenvían');
  });

  test('si se corta la red reconecta sola y se vuelve a autenticar', () async {
    await iniciar();
    servidor.ultimo.autenticar();
    await pasa();

    final estados = <EstadoConexion>[];
    conexion.estados.listen(estados.add);
    servidor.ultimo.cortar();
    await pasa();
    expect(conexion.estado, EstadoConexion.reconectando);

    await pasa(20);
    expect(servidor.abiertos, hasLength(2));
    expect(servidor.ultimo.tipos, ['auth']);
    servidor.ultimo.autenticar();
    await pasa();
    expect(conexion.estado, EstadoConexion.conectado);
    expect(conexion.intentos, 0);
    expect(estados, [EstadoConexion.reconectando, EstadoConexion.conectado]);
  });

  test('si no se puede abrir, sigue reintentando', () async {
    servidor.fallar = true;
    await iniciar();
    await pasa(60);
    expect(servidor.abiertos.length, greaterThanOrEqualTo(3));
    expect(conexion.estado, EstadoConexion.reconectando);

    servidor.fallar = false;
    await pasa(30);
    servidor.ultimo.autenticar();
    await pasa();
    expect(conexion.estado, EstadoConexion.conectado);
  });

  test('sesión reemplazada (4002): no reintenta hasta que se pida', () async {
    await iniciar();
    servidor.ultimo.autenticar();
    await pasa();
    servidor.ultimo.cortar(CodigoCierre.sesionReemplazada);
    await pasa(40);
    expect(conexion.estado, EstadoConexion.sesionReemplazada);
    expect(servidor.abiertos, hasLength(1));

    conexion.reconectarAhora();
    await pasa();
    expect(servidor.abiertos, hasLength(2));
    servidor.ultimo.autenticar();
    await pasa();
    expect(conexion.estado, EstadoConexion.conectado);
  });

  test('token rechazado (4001): pide uno nuevo y reintenta', () async {
    await iniciar();
    servidor.ultimo.cortar(CodigoCierre.noAutenticado);
    await pasa(20);
    expect(token.pedidos, [false, true]);
    expect(servidor.ultimo.enviados.single['token'], 'token-2');
  });

  test('token rechazado una y otra vez: sin sesión', () async {
    await iniciar();
    for (var i = 0; i < 3; i++) {
      servidor.ultimo.cortar(CodigoCierre.noAutenticado);
      await pasa(20);
    }
    expect(conexion.estado, EstadoConexion.sinSesion);
  });

  test('si la sesión venció: sin sesión, sin reintentar', () async {
    token.error = const AuthException.sesionExpirada();
    await iniciar();
    await pasa(30);
    expect(conexion.estado, EstadoConexion.sinSesion);
    expect(servidor.abiertos, isEmpty);
  });

  test('sin red para renovar el token: reintenta', () async {
    token.error = const AuthException.red();
    await iniciar();
    expect(conexion.estado, EstadoConexion.reconectando);
    token.error = null;
    await pasa(30);
    expect(servidor.abiertos, isNotEmpty);
  });

  test('manda ping y, si el servidor deja de responder, reconecta', () async {
    await iniciar(
      ping: const Duration(milliseconds: 15),
      sinRespuesta: const Duration(milliseconds: 40),
    );
    final primero = servidor.ultimo..autenticar();
    await pasa(20);
    expect(primero.tipos, contains('ping'));

    // El servidor "desaparece" sin cerrar el socket.
    await pasa(80);
    expect(primero.cerrado, isTrue);
    expect(servidor.abiertos.length, greaterThanOrEqualTo(2));
  });

  test('cerrar() la deja cerrada y no reintenta', () async {
    await iniciar();
    servidor.ultimo.autenticar();
    await pasa();
    await conexion.cerrar();
    expect(conexion.estado, EstadoConexion.cerrada);
    expect(servidor.ultimo.cerrado, isTrue);
    await pasa(30);
    expect(servidor.abiertos, hasLength(1));
  });
}
