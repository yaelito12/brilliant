import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:brilliant/tablero.dart';
import 'package:brilliant/nivel1.dart';
import 'package:brilliant/tipo.dart';
import 'package:brilliant/zona.dart';
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
    late PartidaBloc bloc;

    /// Crea la partida con los valores iniciales; si se pasan [dados],
    /// las tiradas saldrán en ese orden.
    void iniciar([List<int>? dados]) {
      bloc = PartidaBloc(random: dados == null ? null : _DadosFijos(dados));
      bloc.add(PartidaIniciada(construirTableroNivel1(), _iniciales));
    }

    tearDown(() => bloc.close());

    group('Inicio de partida', () {
      test('coloca los valores iniciales y los dados están sin tirar', () async {
        iniciar();
        await _esperar();

        expect(bloc.state.iniciada, isTrue);
        expect(bloc.state.celdas, _iniciales);
        expect(bloc.state.tablero!.zonas['az1']!.valores, [1]);
        expect(bloc.state.puntuacion, 0);
        expect(bloc.state.dados, isNull);
      });
    });

    group('Tirar dados', () {
      test('calcula anclas pero aún no hay número ancla elegido', () async {
        iniciar([1, 3]);
        bloc.add(DadosLanzados());
        await _esperar();

        expect(bloc.state.dados, [1, 3]);
        expect(bloc.state.valorAncla, isNull);
        expect(bloc.state.anclasPosibles,
            {const Coordenada(0, 2), const Coordenada(3, 1)});
      });

      test('con dados dobles el número ancla se elige solo', () async {
        iniciar([4, 4]);
        bloc.add(DadosLanzados());
        await _esperar();

        expect(bloc.state.valorAncla, 4);
        expect(bloc.state.numeroAColocar, 4);
      });
    });

    group('Elegir ancla', () {
      test('elegir el dado define el ancla y el número a colocar', () async {
        iniciar([1, 3]);
        bloc.add(DadosLanzados());
        bloc.add(ValorAnclaElegido(1));
        await _esperar();

        expect(bloc.state.valorAncla, 1);
        expect(bloc.state.numeroAColocar, 3);
      });

      test('con un dado elegido, tocar el número del otro dado cambia a ese dado',
          () async {
        iniciar([1, 3]);
        bloc.add(DadosLanzados());
        bloc.add(ValorAnclaElegido(1));
        bloc.add(AnclaSeleccionada(const Coordenada(3, 1))); // tiene un 3
        await _esperar();

        expect(bloc.state.ancla, const Coordenada(3, 1));
        expect(bloc.state.valorAncla, 3);
        expect(bloc.state.numeroAColocar, 1);
      });

      test('marca solo los vecinos cuya zona acepta el otro número', () async {
        iniciar([1, 3]);
        bloc.add(DadosLanzados());
        bloc.add(ValorAnclaElegido(1));
        bloc.add(AnclaSeleccionada(const Coordenada(0, 2)));
        await _esperar();

        // (1,2) es azul con un 1: no acepta un 3
        expect(bloc.state.destinosPosibles,
            {const Coordenada(0, 1), const Coordenada(0, 3)});
      });

      test('tocar la misma ancla la deselecciona', () async {
        iniciar([1, 3]);
        bloc.add(DadosLanzados());
        bloc.add(ValorAnclaElegido(1));
        bloc.add(AnclaSeleccionada(const Coordenada(0, 2)));
        bloc.add(AnclaSeleccionada(const Coordenada(0, 2)));
        await _esperar();

        expect(bloc.state.ancla, isNull);
        expect(bloc.state.destinosPosibles, isEmpty);
      });
    });

    group('Elegir ancla desde el tablero', () {
      test('tocar un número que salió lo toma como ancla sin elegir el dado',
          () async {
        iniciar([1, 3]);
        bloc.add(DadosLanzados());
        bloc.add(AnclaSeleccionada(const Coordenada(0, 2))); // tiene un 1
        await _esperar();

        expect(bloc.state.ancla, const Coordenada(0, 2));
        expect(bloc.state.valorAncla, 1);
        expect(bloc.state.numeroAColocar, 3);
        expect(bloc.state.destinosPosibles,
            {const Coordenada(0, 1), const Coordenada(0, 3)});
      });

      test('tocar el número del otro dado usa ese dado como ancla', () async {
        iniciar([1, 3]);
        bloc.add(DadosLanzados());
        bloc.add(AnclaSeleccionada(const Coordenada(3, 1))); // tiene un 3
        await _esperar();

        expect(bloc.state.valorAncla, 3);
        expect(bloc.state.numeroAColocar, 1);
      });

      test('tocar un número que no salió en los dados no hace nada', () async {
        iniciar([1, 3]);
        bloc.add(DadosLanzados());
        bloc.add(AnclaSeleccionada(const Coordenada(1, 5))); // tiene un 2
        await _esperar();

        expect(bloc.state.ancla, isNull);
        expect(bloc.state.valorAncla, isNull);
      });

      test('tocar una casilla vacía no hace nada', () async {
        iniciar([1, 3]);
        bloc.add(DadosLanzados());
        bloc.add(AnclaSeleccionada(const Coordenada(0, 1)));
        await _esperar();

        expect(bloc.state.ancla, isNull);
      });

      test('antes de tirar los dados no se puede tocar un ancla', () async {
        iniciar();
        bloc.add(AnclaSeleccionada(const Coordenada(0, 2)));
        await _esperar();

        expect(bloc.state.ancla, isNull);
      });

      test('se puede colocar sin haber tocado nunca un dado', () async {
        iniciar([1, 3, 2, 5]);
        bloc.add(DadosLanzados());
        bloc.add(AnclaSeleccionada(const Coordenada(0, 2)));
        bloc.add(NumeroColocado(const Coordenada(0, 1)));
        await _esperar();

        expect(bloc.state.celdas[const Coordenada(0, 1)], 3);
        expect(bloc.state.turno, 2);
      });
    });

    group('Colocar número', () {
      test('pasa solo al siguiente turno y tira los dados', () async {
        iniciar([1, 3, 3, 5]);
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
      });

      test('no se puede colocar en el turno nuevo sin elegir ancla', () async {
        iniciar([1, 3, 3, 5]);
        bloc.add(DadosLanzados());
        bloc.add(ValorAnclaElegido(1));
        bloc.add(AnclaSeleccionada(const Coordenada(0, 2)));
        bloc.add(NumeroColocado(const Coordenada(0, 1)));
        bloc.add(NumeroColocado(const Coordenada(0, 0)));
        await _esperar();

        expect(bloc.state.celdas.containsKey(const Coordenada(0, 0)), isFalse);
      });
    });

    group('Puntuación', () {
      test('un solo amarillo no puntúa', () async {
        iniciar([1, 3, 3, 5, 2, 2]);
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
      });
    });

    group('Pasar turno', () {
      test('se puede pasar sin colocar número', () async {
        iniciar([1, 3, 2, 5]);
        bloc.add(DadosLanzados());
        bloc.add(SiguienteTurno());
        await _esperar();

        expect(bloc.state.turno, 2);
        expect(bloc.state.dados, [2, 5]);
        expect(bloc.state.celdas, _iniciales);
      });

      test('no se puede pasar sin haber tirado los dados', () async {
        iniciar();
        bloc.add(SiguienteTurno());
        await _esperar();

        expect(bloc.state.turno, 1);
      });
    });

    group('Eventos ignorados', () {
      test('tirar dados antes de iniciar la partida no hace nada', () async {
        bloc = PartidaBloc(random: _DadosFijos([1, 3]));
        bloc.add(DadosLanzados());
        await _esperar();

        expect(bloc.state.iniciada, isFalse);
        expect(bloc.state.dados, isNull);
      });

      test('tirar dos veces en el mismo turno no vuelve a tirar', () async {
        iniciar([1, 3, 6, 6]);
        bloc.add(DadosLanzados());
        bloc.add(DadosLanzados());
        await _esperar();

        expect(bloc.state.dados, [1, 3]);
      });

      test('elegir ancla antes de tirar los dados no hace nada', () async {
        iniciar();
        bloc.add(ValorAnclaElegido(1));
        await _esperar();

        expect(bloc.state.valorAncla, isNull);
      });

      test('elegir como ancla un número que no salió no hace nada', () async {
        iniciar([1, 3]);
        bloc.add(DadosLanzados());
        bloc.add(ValorAnclaElegido(5));
        await _esperar();

        expect(bloc.state.valorAncla, isNull);
      });

      test('colocar en una casilla no marcada no hace nada', () async {
        iniciar([1, 3]);
        bloc.add(DadosLanzados());
        bloc.add(ValorAnclaElegido(1));
        bloc.add(AnclaSeleccionada(const Coordenada(0, 2)));
        bloc.add(NumeroColocado(const Coordenada(1, 2))); // azul con un 1
        await _esperar();

        expect(bloc.state.celdas, _iniciales);
        expect(bloc.state.turno, 1);
      });

      test('colocar sin haber seleccionado casilla ancla no hace nada', () async {
        iniciar([1, 3]);
        bloc.add(DadosLanzados());
        bloc.add(ValorAnclaElegido(1));
        bloc.add(NumeroColocado(const Coordenada(0, 1)));
        await _esperar();

        expect(bloc.state.celdas, _iniciales);
      });
    });

    group('Cambiar de ancla', () {
      test('elegir el otro dado borra la casilla ancla y los destinos', () async {
        iniciar([1, 3]);
        bloc.add(DadosLanzados());
        bloc.add(ValorAnclaElegido(1));
        bloc.add(AnclaSeleccionada(const Coordenada(0, 2)));
        bloc.add(ValorAnclaElegido(3));
        await _esperar();

        expect(bloc.state.valorAncla, 3);
        expect(bloc.state.numeroAColocar, 1);
        expect(bloc.state.ancla, isNull);
        expect(bloc.state.destinosPosibles, isEmpty);
      });

      test('con el nuevo dado se calculan los destinos del otro número', () async {
        iniciar([1, 3]);
        bloc.add(DadosLanzados());
        bloc.add(ValorAnclaElegido(1));
        bloc.add(ValorAnclaElegido(3));
        bloc.add(AnclaSeleccionada(const Coordenada(3, 1)));
        await _esperar();

        // El 1 cabe en los 4 vecinos del 3 en (3,1)
        expect(bloc.state.destinosPosibles, {
          const Coordenada(2, 1),
          const Coordenada(4, 1),
          const Coordenada(3, 0),
          const Coordenada(3, 2),
        });
      });
    });

    group('Sin jugadas posibles', () {
      // Zona roja de 2 casillas con un 3: otro 3 no cabe
      final tableroSinJugadas = Tablero(
        zonas: {'r': Zona(id: 'r', tipo: TipoRojo(), capacidad: 2)},
        mapeo: {const Coordenada(0, 0): 'r', const Coordenada(0, 1): 'r'},
      );

      test('si ningún ancla tiene espacio no hay anclas y lo avisa', () async {
        bloc = PartidaBloc(random: _DadosFijos([3, 3, 3, 3]));
        bloc.add(PartidaIniciada(tableroSinJugadas, {const Coordenada(0, 0): 3}));
        bloc.add(DadosLanzados());
        await _esperar();

        expect(bloc.state.anclasPosibles, isEmpty);
        expect(bloc.state.mensaje, contains('No hay jugadas'));
      });

      test('se puede pasar al siguiente turno', () async {
        bloc = PartidaBloc(random: _DadosFijos([3, 3, 3, 3]));
        bloc.add(PartidaIniciada(tableroSinJugadas, {const Coordenada(0, 0): 3}));
        bloc.add(DadosLanzados());
        bloc.add(SiguienteTurno());
        await _esperar();

        expect(bloc.state.turno, 2);
      });
    });

    group('Fin de partida', () {
      // Zona verde de 2 casillas con un 2: al poner el 5 se llena todo
      final tableroCasiLleno = Tablero(
        zonas: {'v': Zona(id: 'v', tipo: TipoVerde(), capacidad: 2)},
        mapeo: {const Coordenada(0, 0): 'v', const Coordenada(0, 1): 'v'},
      );

      void llenarTablero() {
        bloc = PartidaBloc(random: _DadosFijos([2, 5]));
        bloc.add(PartidaIniciada(tableroCasiLleno, {const Coordenada(0, 0): 2}));
        bloc.add(DadosLanzados());
        bloc.add(ValorAnclaElegido(2));
        bloc.add(AnclaSeleccionada(const Coordenada(0, 0)));
        bloc.add(NumeroColocado(const Coordenada(0, 1)));
      }

      test('al llenar el tablero la partida termina con su puntuación', () async {
        llenarTablero();
        await _esperar();

        expect(bloc.state.terminada, isTrue);
        expect(bloc.state.puntuacion, 4); // verde, 1er lugar
        expect(bloc.state.mensaje, contains('Tablero completo'));
      });

      test('al terminar no se vuelven a tirar los dados', () async {
        llenarTablero();
        await _esperar();

        expect(bloc.state.turno, 1);
        expect(bloc.state.dados, [2, 5]);
      });

      test('al terminar no se puede pasar de turno', () async {
        llenarTablero();
        bloc.add(SiguienteTurno());
        await _esperar();

        expect(bloc.state.turno, 1);
      });
    });

    group('Mensajes', () {
      test('al iniciar pide tirar los dados', () async {
        iniciar();
        await _esperar();

        expect(bloc.state.mensaje, contains('tira los dados'));
      });

      test('al tirar dice qué salió y pide tocar un dado', () async {
        iniciar([1, 3]);
        bloc.add(DadosLanzados());
        await _esperar();

        expect(bloc.state.mensaje, contains('salió 1 y 3'));
        expect(bloc.state.mensaje, contains('Toca un dado'));
        expect(bloc.state.mensaje, contains('un 1 o un 3 del tablero'));
      });

      test('al elegir el dado indica qué número buscar en el tablero', () async {
        iniciar([1, 3]);
        bloc.add(DadosLanzados());
        bloc.add(ValorAnclaElegido(1));
        await _esperar();

        expect(bloc.state.mensaje, contains('Toca un 1'));
        expect(bloc.state.mensaje, contains('poner el 3'));
      });
    });
  });
}
