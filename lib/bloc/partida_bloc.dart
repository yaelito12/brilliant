import 'dart:math';

import 'package:bloc/bloc.dart';
import '../tablero.dart';
import 'partida_event.dart';
import 'partida_state.dart';

/// Maneja los turnos de la partida: tirar dados, elegir el número ancla,
/// elegir la casilla ancla, colocar el otro número y calcular la puntuación.
///
/// La partida empieza con los dados sin tirar. Al avanzar con "Siguiente"
/// se vuelven a tirar solos.
///
/// Regla de colocación: el ancla es una casilla con número igual al dado
/// elegido; el otro dado se coloca en una casilla vacía vecina
/// (arriba, abajo, izquierda o derecha) cuya zona acepte ese número.
class PartidaBloc extends Bloc<PartidaEvent, PartidaState> {
  final Random _random;

  PartidaBloc({Random? random})
      : _random = random ?? Random(),
        super(const PartidaState()) {
    on<PartidaIniciada>(_alIniciar);
    on<DadosLanzados>(_alLanzarDados);
    on<ValorAnclaElegido>(_alElegirValorAncla);
    on<AnclaSeleccionada>(_alSeleccionarAncla);
    on<NumeroColocado>(_alColocarNumero);
    on<SiguienteTurno>(_alSiguienteTurno);
  }

  void _alIniciar(PartidaIniciada event, Emitter<PartidaState> emit) {
    var tablero = event.tablero;
    event.valoresIniciales.forEach((coordenada, numero) {
      tablero = tablero.agregarNumero(coordenada, numero);
    });

    emit(PartidaState(
      iniciada: true,
      tablero: tablero,
      celdas: Map.unmodifiable(event.valoresIniciales),
      casillasIniciales: event.valoresIniciales.keys.toSet(),
      mensaje: 'Turno 1: tira los dados.',
    ));
  }

  void _alLanzarDados(DadosLanzados event, Emitter<PartidaState> emit) {
    if (!state.iniciada || state.dados != null || state.terminada) return;
    emit(_tirarDados(state));
  }

  /// Tira los 2 dados sobre [base] y calcula las anclas posibles.
  /// Si sale doble no hace falta elegir: el ancla y el otro número son iguales.
  PartidaState _tirarDados(PartidaState base) {
    final dados = [_random.nextInt(6) + 1, _random.nextInt(6) + 1];
    final anclas = _anclasPosibles(base.tablero!, base.celdas, dados);
    final esDoble = dados[0] == dados[1];
    final prefijo = 'Turno ${base.turno}: salió ${dados[0]} y ${dados[1]}.';

    return base.copyWith(
      dados: () => dados,
      anclasPosibles: anclas,
      valorAncla: () => esDoble ? dados[0] : null,
      numeroAColocar: () => esDoble ? dados[0] : null,
      mensaje: anclas.isEmpty
          ? '$prefijo No hay jugadas posibles, pulsa Siguiente.'
          : esDoble
              ? '$prefijo Toca un ${dados[0]} del tablero como ancla.'
              : '$prefijo Toca el dado que quieres usar como ancla.',
    );
  }

  void _alElegirValorAncla(ValorAnclaElegido event, Emitter<PartidaState> emit) {
    final dados = state.dados;
    if (dados == null || state.numeroColocado || !dados.contains(event.valor)) {
      return;
    }

    final numero = _otroDado(dados, event.valor);
    final hayAnclas = state.anclasPosibles.any((c) => state.celdas[c] == event.valor);

    emit(state.copyWith(
      valorAncla: () => event.valor,
      numeroAColocar: () => numero,
      ancla: () => null,
      destinosPosibles: const {},
      mensaje: hayAnclas
          ? 'Toca un ${event.valor} del tablero como ancla para poner el $numero.'
          : 'Ningún ${event.valor} tiene espacio para el $numero. Elige el otro dado o pulsa Siguiente.',
    ));
  }

  void _alSeleccionarAncla(AnclaSeleccionada event, Emitter<PartidaState> emit) {
    final valorAncla = state.valorAncla;
    if (state.numeroColocado ||
        valorAncla == null ||
        state.celdas[event.coordenada] != valorAncla ||
        !state.anclasPosibles.contains(event.coordenada)) {
      return;
    }

    if (state.ancla == event.coordenada) {
      emit(state.copyWith(
        ancla: () => null,
        destinosPosibles: const {},
        mensaje: 'Toca un $valorAncla del tablero como ancla.',
      ));
      return;
    }

    final numero = state.numeroAColocar!;
    emit(state.copyWith(
      ancla: () => event.coordenada,
      destinosPosibles:
          _destinos(state.tablero!, state.celdas, event.coordenada, numero),
      mensaje: 'Coloca el $numero en una casilla marcada.',
    ));
  }

  void _alColocarNumero(NumeroColocado event, Emitter<PartidaState> emit) {
    if (!state.destinosPosibles.contains(event.coordenada)) return;

    final numero = state.numeroAColocar!;
    final tablero = state.tablero!.agregarNumero(event.coordenada, numero);
    final puntosGanados = tablero.puntuacion - state.tablero!.puntuacion;

    final colocado = state.copyWith(
      tablero: tablero,
      celdas: Map.unmodifiable({...state.celdas, event.coordenada: numero}),
      numeroColocado: true,
      ultimaColocada: () => event.coordenada,
      anclasPosibles: const {},
      ancla: () => null,
      destinosPosibles: const {},
      puntosUltimaJugada: puntosGanados,
      mensaje: '¡Tablero completo! Puntuación final: ${tablero.puntuacion}.',
    );

    // Al colocar se pasa solo al siguiente turno y se tiran los dados
    emit(tablero.estaCompleto ? colocado : _siguienteTurno(colocado));
  }

  /// Pasa al siguiente turno sin haber colocado número.
  void _alSiguienteTurno(SiguienteTurno event, Emitter<PartidaState> emit) {
    if (!state.iniciada || state.dados == null || state.terminada) return;
    emit(_siguienteTurno(state.copyWith(puntosUltimaJugada: 0)));
  }

  /// Avanza el turno y vuelve a tirar los dados.
  PartidaState _siguienteTurno(PartidaState base) {
    return _tirarDados(base.copyWith(
      turno: base.turno + 1,
      ancla: () => null,
      destinosPosibles: const {},
      numeroColocado: false,
    ));
  }

  /// Valor que se coloca si el ancla tiene [valorAncla]: el del otro dado.
  int _otroDado(List<int> dados, int valorAncla) {
    return valorAncla == dados[0] ? dados[1] : dados[0];
  }

  Set<Coordenada> _anclasPosibles(
    Tablero tablero,
    Map<Coordenada, int> celdas,
    List<int> dados,
  ) {
    return celdas.entries
        .where((e) => dados.contains(e.value))
        .where((e) => _destinos(tablero, celdas, e.key, _otroDado(dados, e.value))
            .isNotEmpty)
        .map((e) => e.key)
        .toSet();
  }

  Set<Coordenada> _destinos(
    Tablero tablero,
    Map<Coordenada, int> celdas,
    Coordenada ancla,
    int numero,
  ) {
    return tablero
        .vecinos(ancla)
        .where((c) => !celdas.containsKey(c))
        .where((c) => tablero.zonaEn(c)?.puedeAgregar(numero) ?? false)
        .toSet();
  }
}
