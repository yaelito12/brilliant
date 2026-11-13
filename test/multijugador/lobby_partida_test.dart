import 'package:brilliant/multijugador/lobby_bloc.dart';
import 'package:brilliant/multijugador/modelos.dart';
import 'package:brilliant_reglas/brilliant_reglas.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late FakeServidor servidor;
  late LobbyBloc bloc;
  LobbyBloc? abierto;

  /// Bloc de Ana dentro de una sala con la partida en curso.
  Future<FakeTransporte> enPartida({Map<String, Object?>? partida}) async {
    servidor = FakeServidor();
    abierto = bloc = LobbyBloc(conexionFalsa(servidor, FakeToken()))..add(LobbyIniciado());
    await pasa();
    final ws = servidor.ultimo..autenticar(sala: salaJson(estado: 'jugando'));
    ws.servidor({'tipo': 'partida', 'partida': partida ?? partidaJson()});
    await pasa();
    return ws;
  }

  Future<void> llega(FakeTransporte ws, Map<String, Object?> m) async {
    ws.servidor(m);
    await pasa();
  }

  tearDown(() async {
    await abierto?.close();
    abierto = null;
  });

  group('modelo', () {
    test('PartidaInfo lee el JSON del servidor', () {
      final p = PartidaInfo.fromJson(
        partidaJson(jugadores: [
          jugadorPartidaJson('u1', 'Ana', celdas: iniciales1, lugares: {'az1': 2}, puntos: 5, yaJugo: true),
          jugadorPartidaJson('u2', 'Beto', estado: 'concedio'),
          jugadorPartidaJson('u3', 'Carla'),
        ]),
      );
      expect(p.jugando, isTrue);
      expect(p.dados, [1, 3]);
      final ana = p.jugador('u1')!;
      expect(ana.celdas[const Coordenada(0, 2)], 1);
      expect(ana.lugares, {'az1': 2});
      expect(ana.tablero().zonaEn(const Coordenada(0, 2))!.valores, [1]);
      expect(p.jugador('u2')!.activo, isFalse);
      expect(p.faltan, 1, reason: 'solo Carla: Ana ya jugó y Beto se rindió');
    });

    test('PartidaInfo sin reloj no trae límite; con reloj lo calcula', () {
      expect(PartidaInfo.fromJson(partidaJson()).limite, isNull);
      final ahora = DateTime(2026, 1, 1, 12);
      final p = PartidaInfo.fromJson(
        partidaJson(msRestantes: 30000),
        recibido: ahora,
      );
      expect(p.limite, ahora.add(const Duration(seconds: 30)));
    });

    test('SalaInfo lee el tiempo por ronda que eligió el anfitrión', () {
      expect(SalaInfo.fromJson(salaJson()).conReloj, isFalse);
      final sala = SalaInfo.fromJson(salaJson(segundosTurno: 60));
      expect(sala.segundosTurno, 60);
      expect(sala.conReloj, isTrue);
    });
  });

  group('mensajes que manda la app', () {
    test('iniciales, jugada, pasar y conceder', () async {
      final ws = await enPartida();
      bloc
        ..add(LobbyIniciales({const Coordenada(0, 2): 1, const Coordenada(1, 5): 2}))
        ..add(LobbyJugada(const Coordenada(0, 2), const Coordenada(0, 1)))
        ..add(LobbyPasar())
        ..add(LobbyConceder());
      await pasa();
      expect(ws.enviados.sublist(1), [
        {'tipo': 'iniciales', 'valores': [[0, 2, 1], [1, 5, 2]]},
        {'tipo': 'jugada', 'ancla': [0, 2], 'destino': [0, 1]},
        {'tipo': 'pasar'},
        {'tipo': 'conceder'},
      ]);
    });

    test('mientras espera la respuesta queda "esperando"; la respuesta lo quita', () async {
      final ws = await enPartida();
      bloc.add(LobbyPasar());
      await pasa();
      expect(bloc.state.esperando, isTrue);
      await llega(ws, {'tipo': 'partida', 'partida': partidaJson()});
      expect(bloc.state.esperando, isFalse);

      bloc.add(LobbyJugada(const Coordenada(0, 0), const Coordenada(0, 1)));
      await pasa();
      await llega(ws, {'tipo': 'error', 'code': 'jugada_invalida', 'message': 'Esa jugada no es válida con estos dados.'});
      expect(bloc.state.esperando, isFalse);
      expect(bloc.state.aviso!.esError, isTrue);
    });
  });

  group('avisos de la partida', () {
    Future<List<String>> avisosDe(List<Map<String, Object?>> eventos, {Map<String, Object?>? partida}) async {
      final ws = await enPartida();
      final avisos = <String>[];
      final sub = bloc.stream.map((s) => s.aviso).where((a) => a != null).distinct().listen((a) => avisos.add(a!.texto));
      for (final e in eventos) {
        ws.servidor({'tipo': 'partida', 'partida': partida ?? partidaJson(ronda: 2), 'evento': e});
      }
      await pasa();
      await sub.cancel();
      return avisos;
    }

    test('mis puntos y mi tablero completo', () async {
      expect(await avisosDe([
        // Sin zonas llenas no se avisa cada jugada.
        {'tipo': 'jugada', 'nametag': 'Ana', 'puntosGanados': 0},
        {
          'tipo': 'jugada',
          'nametag': 'Ana',
          'puntosGanados': 7,
          'zonas': [
            {'zona': 'mo1', 'lugar': 1, 'puntos': 7},
          ],
        },
        {'tipo': 'jugada', 'nametag': 'Ana', 'puntosGanados': 4, 'completo': true},
      ]), [
        '¡Llenaste la zona morada (1.º lugar, +7)! Ganaste 7 puntos.',
        '¡Completaste tu tablero! La partida termina al acabar la ronda.',
      ]);
    });

    test('lo que hacen los demás (sin avisar cada jugada)', () async {
      expect(await avisosDe([
        {'tipo': 'jugada', 'nametag': 'Beto', 'puntosGanados': 7},
        {'tipo': 'paso', 'nametag': 'Beto'},
        {'tipo': 'desconectado', 'nametag': 'Beto', 'graciaSegundos': 10},
        {'tipo': 'reconectado', 'nametag': 'Beto'},
        {'tipo': 'concedio', 'nametag': 'Beto'},
        {'tipo': 'abandono', 'nametag': 'Carla'},
        {'tipo': 'jugada', 'nametag': 'Carla', 'completo': true},
      ]), [
        'Beto se salió del juego. A nadie se le pasan los turnos: la partida '
            'queda en pausa 10 segundos esperando a que vuelva. Si no vuelve, '
            'pierde y queda fuera.',
        'Beto volvió. ¡Sigue la partida!',
        'Beto se rindió.',
        'Carla no volvió a tiempo: pierde y queda fuera de la partida.',
        'Carla completó su tablero: esta es la última ronda.',
      ]);
    });

    test('se me acabó el tiempo', () async {
      expect(await avisosDe([
        {'tipo': 'ronda', 'pasaronPorTiempo': ['Beto']},
        {'tipo': 'ronda', 'pasaronPorTiempo': ['Ana', 'Beto']},
      ]), ['Se acabó el tiempo: pasaste la ronda 1.']);
    });

    test('me rendí', () async {
      expect(await avisosDe([{'tipo': 'concedio', 'nametag': 'Ana'}]),
          ['Te rendiste. Puedes seguir viendo la partida.']);
    });
  });

  group('fin de la partida', () {
    final terminada = {
      'tipo': 'partida_terminada',
      'motivo': 'tablero_completo',
      'resultados': [
        {'id': 'u2', 'nametag': 'Beto', 'nivel': 3, 'puntos': 30, 'estado': 'jugando', 'posicion': 1},
        {'id': 'u1', 'nametag': 'Ana', 'nivel': 1, 'puntos': 20, 'estado': 'jugando', 'posicion': 2},
      ],
      'partida': partidaJson(fase: 'terminada'),
    };

    test('guarda los resultados y los muestra al volver al lobby hasta cerrarlos', () async {
      final ws = await enPartida();
      await llega(ws, terminada);
      expect(bloc.state.partida!.terminada, isTrue);
      final res = bloc.state.resultados!;
      expect(res.motivo, 'tablero_completo');
      expect(res.de('u1')!.posicion, 2);

      await llega(ws, {'tipo': 'sala', 'sala': salaJson(), 'evento': {'tipo': 'fin_partida'}});
      expect(bloc.state.sala!.enLobby, isTrue);
      expect(bloc.state.partida, isNull);
      expect(bloc.state.resultados, isNotNull, reason: 'siguen a la vista en el lobby');

      bloc.add(LobbyCerrarResultados());
      await pasa();
      expect(bloc.state.resultados, isNull);
    });

    test('la revancha borra los resultados viejos', () async {
      final ws = await enPartida();
      await llega(ws, terminada);
      await llega(ws, {'tipo': 'sala', 'sala': salaJson()});
      await llega(ws, {'tipo': 'partida_iniciada', 'sala': salaJson(estado: 'jugando')});
      expect(bloc.state.resultados, isNull);
    });

    test('si al reconectar ya no está en la sala, se limpia todo', () async {
      final ws = await enPartida();
      ws.cortar();
      await pasa(20);
      servidor.ultimo.autenticar();
      await pasa();
      expect(bloc.state.sala, isNull);
      expect(bloc.state.partida, isNull);
    });

    test('al reconectar en plena partida recupera el estado', () async {
      final ws = await enPartida();
      ws.cortar();
      await pasa(20);
      final nuevo = servidor.ultimo..autenticar(sala: salaJson(estado: 'jugando'));
      await llega(nuevo, {'tipo': 'partida', 'partida': partidaJson(ronda: 5)});
      expect(bloc.state.partida!.ronda, 5);
      expect(bloc.state.sala!.jugando, isTrue);
    });
  });
}
