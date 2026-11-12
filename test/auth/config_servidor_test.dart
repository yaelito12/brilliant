import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:brilliant/auth/auth_api.dart';
import 'package:brilliant/auth/auth_config.dart';
import 'package:brilliant/auth/auth_models.dart';
import 'package:brilliant/auth/config_servidor.dart';

ConfigServidor _config({String inicial = '', String? guardada}) =>
    ConfigServidor(
      urlInicial: inicial,
      almacen: AlmacenServidorEnMemoria(guardada),
      sePuedeCambiar: true,
    );

Future<AuthException> _falla(Future<void> Function() f) async {
  try {
    await f();
  } on AuthException catch (e) {
    return e;
  }
  throw StateError('Se esperaba una AuthException');
}

void main() {
  group('normalizarDireccionServidor', () {
    test('a una IP suelta le pone http y el puerto 3000', () {
      expect(
        normalizarDireccionServidor('192.168.1.9'),
        'http://192.168.1.9:3000',
      );
    });

    test('acepta IP con puerto, con espacios de más', () {
      expect(
        normalizarDireccionServidor('  192.168.1.9:4000  '),
        'http://192.168.1.9:4000',
      );
    });

    test('acepta la dirección completa y le quita la barra final', () {
      expect(
        normalizarDireccionServidor('http://192.168.1.9:3000/'),
        'http://192.168.1.9:3000',
      );
    });

    test('en https sin puerto no inventa el 3000', () {
      expect(
        normalizarDireccionServidor('https://api.midominio.com'),
        'https://api.midominio.com',
      );
    });

    test('acepta un nombre de equipo', () {
      expect(normalizarDireccionServidor('localhost'), 'http://localhost:3000');
    });

    test('rechaza lo que no se entiende', () {
      for (final mala in [
        '',
        '   ',
        'no es una ip',
        'ftp://192.168.1.9',
        'http://',
        '192.168.1.9:0',
        '192.168.1.9:99999',
      ]) {
        expect(
          normalizarDireccionServidor(mala),
          isNull,
          reason: 'debería rechazar "$mala"',
        );
      }
    });
  });

  group('ConfigServidor', () {
    test('sin dirección no está configurado', () {
      final c = _config();
      expect(c.configurado, isFalse);
      expect(c.url, '');
    });

    test('guarda lo que escribe el jugador y avisa del cambio', () async {
      final c = _config();
      var avisos = 0;
      c.addListener(() => avisos++);

      expect(await c.guardar('192.168.1.9'), isTrue);

      expect(c.url, 'http://192.168.1.9:3000');
      expect(c.paraMostrar, '192.168.1.9:3000');
      expect(c.ws.toString(), 'ws://192.168.1.9:3000/ws');
      expect(c.configurado, isTrue);
      expect(avisos, 1);
    });

    test('no avisa si la dirección es la misma', () async {
      final c = _config(inicial: 'http://192.168.1.9:3000');
      var avisos = 0;
      c.addListener(() => avisos++);

      expect(await c.guardar('192.168.1.9:3000'), isTrue);

      expect(avisos, 0);
    });

    test('una dirección mala no cambia nada', () async {
      final c = _config(inicial: '192.168.1.9');

      expect(await c.guardar('xx yy'), isFalse);

      expect(c.url, 'http://192.168.1.9:3000');
    });

    test('la dirección guardada manda sobre la que trae la app', () async {
      final c = _config(inicial: '10.0.0.1', guardada: '192.168.1.9:3000');

      await c.cargar();

      expect(c.url, 'http://192.168.1.9:3000');
    });

    test('sin nada guardado se queda con la de la app', () async {
      final c = _config(inicial: '10.0.0.1');

      await c.cargar();

      expect(c.url, 'http://10.0.0.1:3000');
    });

    test('lo guardado sobrevive a otro arranque', () async {
      final almacen = AlmacenServidorEnMemoria();
      await ConfigServidor(
        almacen: almacen,
        sePuedeCambiar: true,
      ).guardar('192.168.1.9');

      final otroArranque = ConfigServidor(
        almacen: almacen,
        sePuedeCambiar: true,
      );
      await otroArranque.cargar();

      expect(otroArranque.url, 'http://192.168.1.9:3000');
    });

    test('en web no se elige ni se lee nada guardado', () async {
      final c = ConfigServidor(
        urlInicial: 'http://localhost:3000',
        almacen: AlmacenServidorEnMemoria('http://192.168.1.9:3000'),
        sePuedeCambiar: false,
      );

      await c.cargar();

      expect(c.url, 'http://localhost:3000');
    });
  });

  group('AuthApi.comprobar', () {
    test('acepta el servidor de Brilliant', () async {
      late http.Request visto;
      await AuthApi.comprobar(
        'http://192.168.1.9:3000',
        client: MockClient((req) async {
          visto = req;
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      );
      expect(visto.method, 'GET');
      expect(visto.url.toString(), 'http://192.168.1.9:3000/health');
    });

    test('avisa si en esa dirección contesta otra cosa', () async {
      final e = await _falla(
        () => AuthApi.comprobar(
          'http://192.168.1.9:3000',
          client: MockClient((_) async => http.Response('<html>', 200)),
        ),
      );
      expect(e.code, 'no_es_brilliant');
    });

    test('avisa si no contesta nadie', () async {
      final e = await _falla(
        () => AuthApi.comprobar(
          'http://192.168.1.9:3000',
          client: MockClient(
            (_) async => throw http.ClientException('sin ruta'),
          ),
        ),
      );
      expect(e.code, 'sin_conexion');
    });
  });

  test('sin dirección, la API no intenta conectarse', () async {
    final api = AuthApi(
      baseUrl: '',
      client: MockClient((_) async => throw StateError('no debería llamar')),
    );

    final e = await _falla(
      () => api.iniciarSesion(nametag: 'Ana', password: 'clave-larga-123'),
    );

    expect(e.code, 'sin_servidor');
  });

  test('se puede cambiar la dirección de la API en marcha', () async {
    final urls = <String>[];
    final api = AuthApi(
      baseUrl: 'http://10.0.0.1:3000',
      client: MockClient((req) async {
        urls.add(req.url.toString());
        return http.Response(
          jsonEncode({
            'user': {'id': 'u1', 'nametag': 'Ana'},
          }),
          200,
        );
      }),
    );

    await api.yo('token');
    // Con la barra final de más: la API la quita igual.
    api.baseUrl = 'http://192.168.1.9:3000/';
    await api.yo('token');

    expect(urls, [
      'http://10.0.0.1:3000/account/me',
      'http://192.168.1.9:3000/account/me',
    ]);
  });
}
