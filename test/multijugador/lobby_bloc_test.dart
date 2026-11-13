import 'package:brilliant/multijugador/conexion_multijugador.dart';
import 'package:brilliant/multijugador/lobby_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late FakeServidor servidor;
  late LobbyBloc bloc;

  /// Bloc conectado y autenticado como Ana (u1).
  Future<FakeTransporte> conectado({Map<String, Object?>? sala}) async {
    servidor = FakeServidor();
    bloc = LobbyBloc(conexionFalsa(servidor, FakeToken()))..add(LobbyIniciado());
    await pasa();
    servidor.ultimo.autenticar(sala: sala);
    await pasa();
    return servidor.ultimo;
  }

  tearDown(() => bloc.close());

  test('al autenticarse sabe quién es y que no está en sala', () async {
    await conectado();
    expect(bloc.state.conexion, EstadoConexion.conectado);
    expect(bloc.state.yo!.nametag, 'Ana');
    expect(bloc.state.sala, isNull);
  });

  test('crear sala: manda el mensaje y muestra la sala que contesta el servidor', () async {
    final ws = await conectado();
    bloc.add(LobbyCrearSala(2));
    await pasa();
    expect(ws.enviados.last, {'tipo': 'crear_sala', 'nivel': 2});
    expect(bloc.state.esperando, isTrue);

    ws.servidor({'tipo': 'sala', 'sala': salaJson(), 'evento': {'tipo': 'creada', 'nametag': 'Ana'}});
    await pasa();
    expect(bloc.state.esperando, isFalse);
    expect(bloc.state.sala!.codigo, 'K7M2QX');
    expect(bloc.state.miJugador!.nametag, 'Ana');
    expect(bloc.state.aviso, isNull, reason: 'los eventos propios no se avisan');
  });

  test('unirse normaliza el código', () async {
    final ws = await conectado();
    bloc.add(LobbyUnirse(' k7m2qx '));
    await pasa();
    expect(ws.enviados.last, {'tipo': 'unirse', 'codigo': 'K7M2QX'});
  });

  test('un error del servidor se muestra y deja de esperar', () async {
    final ws = await conectado();
    bloc.add(LobbyUnirse('ZZZZZZ'));
    await pasa();
    ws.servidor({'tipo': 'error', 'code': 'sala_no_encontrada', 'message': 'No existe una sala con ese código.'});
    await pasa();
    expect(bloc.state.esperando, isFalse);
    expect(bloc.state.aviso!.esError, isTrue);
    expect(bloc.state.aviso!.texto, 'No existe una sala con ese código.');
  });

  test('avisa lo que hacen los demás', () async {
    final ws = await conectado(sala: salaJson());
    final avisos = <String>[];
    bloc.stream.map((s) => s.aviso).distinct().listen((a) => avisos.add(a!.texto));
    for (final tipo in ['unido', 'desconectado', 'reconectado', 'salio', 'abandono']) {
      ws.servidor({'tipo': 'sala', 'sala': salaJson(), 'evento': {'tipo': tipo, 'nametag': 'Beto'}});
    }
    await pasa();
    expect(avisos, [
      'Beto se unió a la sala.',
      'Beto perdió la conexión.',
      'Beto volvió.',
      'Beto salió de la sala.',
      'Beto no volvió y salió de la sala.',
    ]);
  });

  test('listo, cambiar mapa, cambiar el tiempo y salir', () async {
    final ws = await conectado(sala: salaJson());
    expect(bloc.state.sala, isNotNull, reason: 'el autenticado ya traía la sala');

    bloc
      ..add(LobbyListo(true))
      ..add(LobbyElegirMapa(4))
      ..add(LobbyElegirTiempo(60))
      ..add(LobbySalir());
    await pasa();
    expect(ws.tipos.sublist(1), ['listo', 'elegir_mapa', 'elegir_tiempo', 'salir']);
    expect(ws.enviados[3], {'tipo': 'elegir_tiempo', 'segundos': 60});
    expect(bloc.state.sala, isNull);
  });

  test('tras una reconexión recupera la sala que dice el servidor', () async {
    final ws = await conectado(sala: salaJson());
    ws.cortar();
    await pasa();
    expect(bloc.state.conexion, EstadoConexion.reconectando);
    expect(bloc.state.sala, isNotNull, reason: 'mientras reconecta se sigue mostrando');

    await pasa(20);
    servidor.ultimo.autenticar(sala: salaJson(jugadores: [
      jugadorJson('u1', 'Ana'),
      jugadorJson('u2', 'Beto', listo: true),
    ]));
    await pasa();
    expect(bloc.state.conexion, EstadoConexion.conectado);
    expect(bloc.state.sala!.jugadores, hasLength(2));
  });

  test('sin conexión no manda nada y avisa', () async {
    final ws = await conectado(sala: salaJson());
    ws.cortar();
    await pasa();
    bloc.add(LobbyListo(true));
    await pasa();
    expect(bloc.state.aviso!.esError, isTrue);
    expect(ws.tipos, ['auth']);
  });

  test('partida iniciada y estado de la partida', () async {
    final ws = await conectado(sala: salaJson());
    ws.servidor({'tipo': 'partida_iniciada', 'sala': salaJson(estado: 'jugando')});
    ws.servidor({'tipo': 'partida', 'partida': partidaJson(fase: 'iniciales', ronda: 0)});
    await pasa();
    expect(bloc.state.sala!.jugando, isTrue);
    expect(bloc.state.aviso!.texto, contains('Empieza la partida'));
    expect(bloc.state.partida!.enIniciales, isTrue);
    expect(bloc.state.yoEnPartida!.nametag, 'Ana');
  });

  test('un mensaje con formato raro se ignora', () async {
    final ws = await conectado();
    ws.servidor({'tipo': 'sala', 'sala': {'codigo': 5}});
    await pasa();
    expect(bloc.state.sala, isNull);
  });

  test('cerrar el bloc cierra la conexión', () async {
    final ws = await conectado();
    await bloc.close();
    expect(ws.cerrado, isTrue);
  });
}
