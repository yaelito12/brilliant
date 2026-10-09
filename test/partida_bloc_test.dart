import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:brilliant/tablero.dart';
import 'package:brilliant/nivel1.dart';
import 'package:brilliant/bloc/partida_bloc.dart';
import 'package:brilliant/bloc/partida_event.dart';

/// Random que devuelve los dados indicados, en orden.
class _DadosFijos implements Random {
  final List<int> _valores;
  int _i = 0;

  _DadosFijos(this._valores);

  @override
  int nextInt(int max) => _valores[_i++] - 1;

  @override
  double nextDouble() => throw UnimplementedError();

  @override
  bool nextBool() => throw UnimplementedError();
}

final _iniciales = {
  const Coordenada(0, 2): 1, // az1
  const Coordenada(1, 5): 2, // mo1
  const Coordenada(3, 1): 3, // ro1
  const Coordenada(3, 4): 4, // ve2
  const Coordenada(5, 2): 5, // mo2
  const Coordenada(6, 4): 6, // ro2
};

Future<void> _esperar() => Future<void>.delayed(Duration.zero);

void main() {
  group('PartidaBloc', () {
    test('al iniciar coloca los valores iniciales y los dados están sin tirar', () async {
      final bloc = PartidaBloc();
      bloc.add(PartidaIniciada(construirTableroNivel1(), _iniciales));
      await _esperar();

      expect(bloc.state.iniciada, isTrue);
      expect(bloc.state.celdas, _iniciales);
      expect(bloc.state.tablero!.zonas['az1']!.valores, [1]);
      expect(bloc.state.puntuacion, 0);
      expect(bloc.state.dados, isNull);
      await bloc.close();
    });

    test('tirar dados calcula anclas pero aún no hay número ancla elegido', () async {
      final bloc = PartidaBloc(random: _DadosFijos([1, 3]));
      bloc.add(PartidaIniciada(construirTableroNivel1(), _iniciales));
      bloc.add(DadosLanzados());
      await _esperar();

      expect(bloc.state.dados, [1, 3]);
      expect(bloc.state.valorAncla, isNull);
      expect(bloc.state.anclasPosibles,
          {const Coordenada(0, 2), const Coordenada(3, 1)});

      // Sin elegir el número ancla no se puede tocar una casilla
      bloc.add(AnclaSeleccionada(const Coordenada(0, 2)));
      await _esperar();
      expect(bloc.state.ancla, isNull);
      await bloc.close();
    });

    test('solo se puede usar como ancla una casilla con el número elegido', () async {
      final bloc = PartidaBloc(random: _DadosFijos([1, 3]));
      bloc.add(PartidaIniciada(construirTableroNivel1(), _iniciales));
      bloc.add(DadosLanzados());
      bloc.add(ValorAnclaElegido(1));
      await _esperar();

      expect(bloc.state.valorAncla, 1);
      expect(bloc.state.numeroAColocar, 3);

      // (3,1) tiene un 3, no un 1
      bloc.add(AnclaSeleccionada(const Coordenada(3, 1)));
      await _esperar();
      expect(bloc.state.ancla, isNull);

      bloc.add(AnclaSeleccionada(const Coordenada(0, 2)));
      await _esperar();
      // (1,2) es azul con un 1: no acepta un 3
      expect(bloc.state.destinosPosibles,
          {const Coordenada(0, 1), const Coordenada(0, 3)});

      // Tocar la misma ancla la deselecciona
      bloc.add(AnclaSeleccionada(const Coordenada(0, 2)));
      await _esperar();
      expect(bloc.state.ancla, isNull);
      expect(bloc.state.destinosPosibles, isEmpty);
      await bloc.close();
    });

    test('con dados dobles el número ancla se elige solo', () async {
      final bloc = PartidaBloc(random: _DadosFijos([4, 4]));
      bloc.add(PartidaIniciada(construirTableroNivel1(), _iniciales));
      bloc.add(DadosLanzados());
      await _esperar();

      expect(bloc.state.valorAncla, 4);
      expect(bloc.state.numeroAColocar, 4);
      await bloc.close();
    });

    test('al colocar un número pasa solo al siguiente turno y tira los dados', () async {
      final bloc = PartidaBloc(random: _DadosFijos([1, 3, 3, 5]));
      bloc.add(PartidaIniciada(construirTableroNivel1(), _iniciales));
      bloc.add(DadosLanzados());
      bloc.add(ValorAnclaElegido(1));
      bloc.add(AnclaSeleccionada(const Coordenada(0, 2)));
      bloc.add(NumeroColocado(const Coordenada(0, 1)));
      await _esperar();

      expect(bloc.state.celdas[const Coordenada(0, 1)], 3);
      expect(bloc.state.ultimaColocada, const Coordenada(0, 1));
      expect(bloc.state.turno, 2);
      expect(bloc.state.dados, [3, 5]);
      expect(bloc.state.valorAncla, isNull);
      expect(bloc.state.numeroColocado, isFalse);

      // Colocar otra vez sin elegir ancla en el turno nuevo no hace nada
      bloc.add(NumeroColocado(const Coordenada(0, 0)));
      await _esperar();
      expect(bloc.state.celdas.containsKey(const Coordenada(0, 0)), isFalse);
      await bloc.close();
    });

    test('un solo amarillo no puntúa', () async {
      final bloc = PartidaBloc(random: _DadosFijos([1, 3, 3, 5, 2, 2]));
      bloc.add(PartidaIniciada(construirTableroNivel1(), _iniciales));
      bloc.add(DadosLanzados());
      bloc.add(ValorAnclaElegido(1));
      bloc.add(AnclaSeleccionada(const Coordenada(0, 2)));
      bloc.add(NumeroColocado(const Coordenada(0, 1)));
      bloc.add(ValorAnclaElegido(3));
      bloc.add(AnclaSeleccionada(const Coordenada(0, 1))); // el 3 recién puesto
      bloc.add(NumeroColocado(const Coordenada(0, 0))); // 1 de las 5 amarillas
      await _esperar();

      expect(bloc.state.tablero!.zonas['am']!.valores, [5]);
      expect(bloc.state.tablero!.zonas['am']!.estaCompleta, isFalse);
      expect(bloc.state.puntosUltimaJugada, 0);
      expect(bloc.state.puntuacion, 0);
      expect(bloc.state.turno, 3);
      await bloc.close();
    });

    test('la zona amarilla solo puntúa al llenar sus 5 casillas', () {
      var tablero = construirTableroNivel1();
      final amarillas = [
        const Coordenada(0, 0),
        const Coordenada(0, 6),
        const Coordenada(3, 3),
        const Coordenada(6, 0),
        const Coordenada(6, 6),
      ];

      for (var i = 0; i < 4; i++) {
        tablero = tablero.agregarNumero(amarillas[i], i + 1);
      }
      expect(tablero.puntuacion, 0);

      // Las amarillas no pueden repetir número entre ellas
      expect(identical(tablero.agregarNumero(amarillas[4], 1), tablero), isTrue);

      tablero = tablero.agregarNumero(amarillas[4], 5);
      expect(tablero.zonas['am']!.estaCompleta, isTrue);
      expect(tablero.puntuacion, 8);
    });

    test('se puede pasar sin colocar número', () async {
      final bloc = PartidaBloc(random: _DadosFijos([1, 3, 2, 5]));
      bloc.add(PartidaIniciada(construirTableroNivel1(), _iniciales));
      bloc.add(DadosLanzados());
      bloc.add(SiguienteTurno());
      await _esperar();

      expect(bloc.state.turno, 2);
      expect(bloc.state.dados, [2, 5]);
      expect(bloc.state.celdas, _iniciales);
      await bloc.close();
    });

    test('no se puede pasar sin haber tirado los dados', () async {
      final bloc = PartidaBloc();
      bloc.add(PartidaIniciada(construirTableroNivel1(), _iniciales));
      bloc.add(SiguienteTurno());
      await _esperar();

      expect(bloc.state.turno, 1);
      await bloc.close();
    });
  });
}
