import 'dart:math';

import 'package:flutter/material.dart';

import 'aviso_sin_salida.dart';
import 'avisos.dart';
import 'fondo.dart';
import 'sonidos.dart';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:brilliant_reglas/brilliant_reglas.dart';

import 'bloc/juego_bloc.dart';
import 'bloc/juego_event.dart';
import 'bloc/juego_state.dart';
import 'bloc/partida_bloc.dart';
import 'bloc/partida_event.dart';
import 'bloc/partida_state.dart';

/// Pantalla de juego del mapa [nivel] (se elige en el menú de mapas).
/// Usa la misma interfaz que la partida en línea: el mismo tablero, el mismo
/// teclado de números iniciales y las mismas notificaciones.
class TableroPage extends StatelessWidget {
  /// Mapa a jugar; por defecto, el primero de los oficiales.
  final Nivel? nivel;

  /// Generador de los dados (en los tests, para que salgan valores fijos).
  final Random? random;

  const TableroPage({super.key, this.nivel, this.random});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => JuegoBloc()),
        BlocProvider(create: (_) => PartidaBloc(random: random)),
      ],
      child: _TableroView(nivel: nivel ?? nivelesOficiales.first),
    );
  }
}

class _TableroView extends StatefulWidget {
  final Nivel nivel;

  const _TableroView({required this.nivel});

  @override
  State<_TableroView> createState() => _TableroViewState();
}

class _TableroViewState extends State<_TableroView> {
  late Tablero _tablero;

  /// Mapa de qué número el jugador ha puesto en cada casilla inicial
  final Map<Coordenada, int> _valoresIniciales = {};

  /// Casilla inicial que el jugador tocó (null = ninguna): el próximo
  /// número del teclado va ahí, como en la partida en línea.
  Coordenada? _casillaElegida;

  @override
  void initState() {
    super.initState();
    _tablero = widget.nivel.construirTablero();
  }

  Set<Coordenada> get _casillasIniciales => widget.nivel.casillasIniciales;

  bool get _todasLasCasillasInicalesLlenas {
    return _casillasIniciales.every((c) => _valoresIniciales.containsKey(c));
  }

  /// Tablero base con los números iniciales puestos hasta ahora.
  Tablero _tableroConIniciales() {
    var t = _tablero;
    _valoresIniciales.forEach((c, n) => t = t.agregarNumero(c, n));
    return t;
  }

  /// Sale de la partida (o se rinde) y vuelve al menú de mapas. Si hay
  /// progreso pide confirmación, porque la partida se pierde.
  Future<void> _salir(BuildContext context) async {
    final partida = context.read<PartidaBloc>().state;
    final enCurso = partida.iniciada && !partida.terminada;
    final hayProgreso =
        enCurso || (!partida.iniciada && _valoresIniciales.isNotEmpty);

    if (hayProgreso) {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(Icons.flag, color: Colors.red.shade700, size: 40),
          title: Text(enCurso ? '¿Rendirse?' : '¿Salir al menú?'),
          content: const Text(
            'Se perderá esta partida y volverás al menú de mapas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              child: Text(enCurso ? 'Sí, rendirme' : 'Sí, salir'),
            ),
          ],
        ),
      );
      if (confirmado != true || !context.mounted) return;
    }

    final navegador = Navigator.of(context);
    if (navegador.canPop()) navegador.pop();
  }

  void _alTocarCelda(BuildContext context, Coordenada coordenada) {
    final partida = context.read<PartidaBloc>();

    if (partida.state.iniciada) {
      if (partida.state.destinosPosibles.contains(coordenada)) {
        partida.add(NumeroColocado(coordenada));
      } else if (partida.state.anclasPosibles.contains(coordenada)) {
        partida.add(AnclaSeleccionada(coordenada));
      }
      return;
    }

    // Antes de empezar: tocar una casilla inicial la elige; el número se
    // pone con el teclado de abajo (o el del equipo), como en línea.
    if (!_casillasIniciales.contains(coordenada)) return;
    setState(() => _casillaElegida = coordenada);
  }

  // ---------------------------------------------------------------------------
  // Números iniciales (misma mecánica que en la partida en línea)
  // ---------------------------------------------------------------------------

  bool _estaEsperando(JuegoState juego, PartidaState partida) =>
      !partida.iniciada && juego is JuegoEsperandoValores;

  /// Números que se pueden poner en la casilla elegida ahora mismo.
  Set<int> _permitidos(Coordenada? c) => c == null
      ? const {}
      : numerosParaInicial(widget.nivel, _valoresIniciales, c);

  void _ponerNumero(int numero) {
    final c = _casillaElegida;
    if (c == null || !_permitidos(c).contains(numero)) return;
    setState(() {
      _valoresIniciales[c] = numero;
      _casillaElegida = null;
    });
    if (!_todasLasCasillasInicalesLlenas) {
      context.read<JuegoBloc>().add(ValoresInicialesIncompletos());
    }
  }

  void _borrarNumero() {
    final c = _casillaElegida;
    if (c == null || !_valoresIniciales.containsKey(c)) return;
    setState(() => _valoresIniciales.remove(c));
    context.read<JuegoBloc>().add(ValoresInicialesIncompletos());
  }

  /// Rellena las casillas con números válidos al azar.
  void _alAzar() {
    final casillas = _casillasIniciales.toList();
    final random = Random();
    for (var intento = 0; intento < 2000; intento++) {
      final numeros = [1, 2, 3, 4, 5, 6]..shuffle(random);
      final valores = {
        for (var i = 0; i < casillas.length; i++) casillas[i]: numeros[i % 6],
      };
      if (errorEnValoresIniciales(widget.nivel, valores) == null) {
        setState(() {
          _valoresIniciales
            ..clear()
            ..addAll(valores);
          _casillaElegida = null;
        });
        return;
      }
    }
  }

  /// Teclado físico: 1-6 ponen el número; Retroceso o Supr lo borran.
  KeyEventResult _alPulsarTecla(KeyEvent e, JuegoState juego, PartidaState partida) {
    if (!_estaEsperando(juego, partida) || e is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final n = int.tryParse(e.character ?? '');
    if (n != null && n >= 1 && n <= 6) {
      _ponerNumero(n);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace ||
        e.logicalKey == LogicalKeyboardKey.delete) {
      _borrarNumero();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Si ya se colocó el número avanza directo; si no, pide confirmación.
  Future<void> _alPulsarSiguiente(BuildContext context) async {
    final partida = context.read<PartidaBloc>();

    if (partida.state.numeroColocado) {
      partida.add(SiguienteTurno());
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange.shade700,
          size: 40,
        ),
        title: const Text('¿Pasar turno?'),
        content: const Text(
          'Aún no has colocado ningún número en este turno.\n¿Estás seguro de que quieres pasar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
            ),
            child: const Text('Sí, pasar'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      partida.add(SiguienteTurno());
    }
  }

  @override
  Widget build(BuildContext context) {
    // El "atrás" del sistema pasa por la misma confirmación que Rendirse
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _salir(context);
      },
      child: MultiBlocListener(
        listeners: [
          BlocListener<JuegoBloc, JuegoState>(
            listener: (context, state) {
              if (state is JuegoListo) {
                context.read<PartidaBloc>().add(
                  PartidaIniciada(_tablero, Map.of(_valoresIniciales)),
                );
                mostrarNotificacion(
                  context,
                  '¡Valores iniciales listos! El juego puede comenzar.',
                  tipo: TipoAviso.exito,
                  icono: Icons.check_circle,
                );
              }
            },
          ),
          // Al colocar un número: aviso y sonido si completó una zona o el
          // tablero (los dados del siguiente turno ya se tiraron solos)
          BlocListener<PartidaBloc, PartidaState>(
            listenWhen: (anterior, actual) =>
                actual.ultimaColocada != null &&
                anterior.ultimaColocada != actual.ultimaColocada,
            listener: (context, state) {
              final tablero = state.tablero!;
              final completadas = tablero.ordenCompletadas;
              final completoZona =
                  completadas.isNotEmpty &&
                  tablero.zonaEn(state.ultimaColocada!)?.id == completadas.last;

              if (state.terminada) {
                Sonidos.tocar(Sonido.victoria);
                mostrarNotificacion(
                  context,
                  '¡Tablero completo! Puntuación final: ${state.puntuacion}',
                  tipo: TipoAviso.exito,
                  icono: Icons.emoji_events,
                );
              } else if (completoZona) {
                Sonidos.tocar(Sonido.zona);
                final id = completadas.last;
                final color = nombreDeTipo(tablero.zonas[id]!.tipo)
                    .toLowerCase();
                mostrarNotificacion(
                  context,
                  '¡Zona $color completada! +${tablero.puntosDe(id)} puntos',
                  tipo: TipoAviso.exito,
                );
              }
            },
          ),
        ],
        child: BlocBuilder<JuegoBloc, JuegoState>(
          builder: (context, juego) {
            return BlocBuilder<PartidaBloc, PartidaState>(
              builder: (context, partida) {
                return FondoBrilliant(
                  child: Focus(
                    autofocus: true,
                    onKeyEvent: (_, e) => _alPulsarTecla(e, juego, partida),
                    child: Scaffold(
                      backgroundColor: Colors.transparent,
                      appBar: AppBar(
                        title: const Text(
                          'Brilliant',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        // Sin flecha de regreso: se sale con Rendirse/Salir
                        automaticallyImplyLeading: false,
                        actions: [
                          // Mapa que se está jugando
                          const Icon(Icons.map, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            widget.nivel.nombre,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 12),
                          _buildBotonSalir(context, partida),
                          const SizedBox(width: 8),
                        ],
                      ),
                      // Los dados y el botón van pegados al tablero para no
                      // tener que cruzar la pantalla en cada jugada
                      body: LayoutBuilder(
                        builder: (context, constraints) {
                          final tablero = _buildTablero(context, juego, partida);
                          final leyenda = LeyendaChips(
                            tablero: partida.tablero ?? _tableroConIniciales(),
                          );

                          // Pantalla ancha: panel justo a la derecha del tablero
                          if (constraints.maxWidth >= anchoPantallaAncha) {
                            const anchoPanel = 320.0;
                            final lado = min(
                              min(constraints.maxHeight - 32, 640.0),
                              constraints.maxWidth -
                                  anchoPanel -
                                  64 -
                                  2 * _anchoIndicadores,
                            );
                            return Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: lado + 2 * _anchoIndicadores,
                                    height: lado,
                                    child: tablero,
                                  ),
                                  const SizedBox(width: 16),
                                  SizedBox(
                                    width: anchoPanel,
                                    height: lado,
                                    child: Center(
                                      child: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            _buildPanelLateral(
                                              context,
                                              juego,
                                              partida,
                                            ),
                                            const SizedBox(height: 12),
                                            leyenda,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          // Pantalla angosta: tarjeta justo debajo del tablero
                          return Column(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    12,
                                    12,
                                    8,
                                  ),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 560 + 2 * _anchoIndicadores,
                                      ),
                                      child: tablero,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 560,
                                  ),
                                  child: _buildPanelInferior(
                                    context,
                                    juego,
                                    partida,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                                child: leyenda,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// El tablero con los indicadores de cada zona a los lados: el mismo
  /// widget que usa la partida en línea.
  Widget _buildTablero(
    BuildContext context,
    JuegoState juego,
    PartidaState partida,
  ) {
    final estaEsperando = _estaEsperando(juego, partida);
    final tablero = partida.tablero ?? _tableroConIniciales();
    final celdas = partida.iniciada ? partida.celdas : _valoresIniciales;

    return TableroMultijugador(
      nivel: widget.nivel,
      tablero: tablero,
      celdas: celdas,
      iniciales: _casillasIniciales,
      pendientesIniciales: estaEsperando
          ? _casillasIniciales
                .where((c) => !_valoresIniciales.containsKey(c))
                .toSet()
          : const {},
      seleccionada: estaEsperando ? _casillaElegida : null,
      sinSalida: estaEsperando
          ? inicialesSinSalida(widget.nivel, _valoresIniciales).toSet()
          : const {},
      anclas: partida.anclasPosibles,
      ancla: partida.ancla,
      destinos: partida.destinosPosibles,
      destinosTentativos: partida.destinosTentativos,
      onTap: (c) => _alTocarCelda(context, c),
    );
  }

  /// Panel a la derecha del tablero (pantallas anchas): dados arriba,
  /// mensaje, puntos y botón uno debajo de otro.
  Widget _buildPanelLateral(
    BuildContext context,
    JuegoState juego,
    PartidaState partida,
  ) {
    if (!partida.iniciada) {
      return TarjetaPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoPreparacion(juego, partida),
            const SizedBox(height: 14),
            _buildBotonComenzar(context, juego),
          ],
        ),
      );
    }

    return TarjetaPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _buildDados(context, partida)),
          const SizedBox(height: 14),
          _buildMensaje(partida),
          const SizedBox(height: 12),
          Center(child: _buildPuntos(partida)),
          const SizedBox(height: 14),
          _buildBotonTurno(context, partida),
        ],
      ),
    );
  }

  /// Tarjeta debajo del tablero (pantallas angostas): dados, mensaje y
  /// puntos en una fila y el botón abajo.
  Widget _buildPanelInferior(
    BuildContext context,
    JuegoState juego,
    PartidaState partida,
  ) {
    return TarjetaPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (partida.iniciada) ...[
            Row(
              children: [
                _buildDados(context, partida),
                const Spacer(),
                _buildPuntos(partida),
              ],
            ),
            const SizedBox(height: 8),
            _buildMensaje(partida),
          ] else
            _buildInfoPreparacion(juego, partida),
          const SizedBox(height: 10),
          partida.iniciada
              ? _buildBotonTurno(context, partida)
              : _buildBotonComenzar(context, juego),
        ],
      ),
    );
  }

  Widget _buildInfoPreparacion(JuegoState juego, PartidaState partida) {
    final pendientes = _casillasIniciales
        .where((c) => !_valoresIniciales.containsKey(c))
        .length;
    final elegida = _casillaElegida;
    // Si en la casilla elegida ya no cabe ningún número, se explica por qué
    // y se ofrece mover uno aquí; además avisa de otras casillas sin salida.
    final bloqueo = elegida == null
        ? null
        : bloqueoInicial(widget.nivel, _valoresIniciales, elegida);
    final sinSalida = inicialesSinSalida(widget.nivel, _valoresIniciales)
      ..remove(elegida);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.edit, color: Colors.orange.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                pendientes > 0
                    ? elegida == null
                          ? 'Toca una casilla marcada y luego un número del 1 '
                                'al 6, sin repetir. Faltan $pendientes.'
                          : 'Toca un número para la casilla marcada (del 1 al '
                                '6, sin repetir). Faltan $pendientes.'
                    : 'Todos los números iniciales están puestos.',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _colorTexto,
                ),
              ),
            ),
          ],
        ),
        if (bloqueo != null) ...[
          const SizedBox(height: 10),
          AvisoSinSalida(
            bloqueo: bloqueo,
            onMover: (n) => setState(() {
              final origen = bloqueo.usadoEn[n]!;
              _valoresIniciales
                ..remove(origen)
                ..[elegida!] = n;
              _casillaElegida = null;
            }),
          ),
        ],
        if (sinSalida.isNotEmpty) ...[
          const SizedBox(height: 10),
          AvisoAnticipado(
            texto: avisoCasillasSinSalida(_tableroConIniciales(), sinSalida),
          ),
        ],
        const SizedBox(height: 12),
        TecladoIniciales(
          permitidos: _permitidos(elegida),
          hayElegida: _valoresIniciales.containsKey(elegida),
          onNumero: _ponerNumero,
          onBorrar: _borrarNumero,
          onAlAzar: _alAzar,
        ),
      ],
    );
  }

  Widget _buildBotonComenzar(BuildContext context, JuegoState juego) {
    final estaEsperando = juego is JuegoEsperandoValores;

    return _BotonPrincipal(
      texto: !_todasLasCasillasInicalesLlenas
          ? 'Faltan números'
          : 'Comenzar juego',
      icono: Icons.play_arrow,
      onPressed: (_todasLasCasillasInicalesLlenas && estaEsperando)
          ? () =>
                context.read<JuegoBloc>().add(ValoresInicialesProporcionados())
          : null,
    );
  }

  /// Los 2 dados; se tocan para elegir el ancla.
  Widget _buildDados(BuildContext context, PartidaState partida) {
    final bloc = context.read<PartidaBloc>();
    final dados = partida.dados;
    final esDoble = dados != null && dados[0] == dados[1];
    // Se puede elegir (o cambiar) el dado ancla mientras no se haya colocado
    final puedeElegir = dados != null && !esDoble && !partida.numeroColocado;

    bool tieneAnclas(int valor) =>
        partida.anclasPosibles.any((c) => partida.celdas[c] == valor);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 2; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _DadoElegible(
            valor: dados?[i],
            tirada: partida.turno,
            retraso: Duration(milliseconds: 120 * i),
            elegido: dados != null && partida.valorAncla == dados[i],
            apagado:
                dados != null &&
                !partida.numeroColocado &&
                !tieneAnclas(dados[i]),
            onTap: puedeElegir && tieneAnclas(dados[i])
                ? () => bloc.add(ValorAnclaElegido(dados[i]))
                : null,
          ),
        ],
      ],
    );
  }

  /// Número de turno y qué hacer ahora.
  Widget _buildMensaje(PartidaState partida) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Turno ${partida.turno}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          partida.mensaje,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _colorTexto,
          ),
        ),
      ],
    );
  }

  Widget _buildPuntos(PartidaState partida) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Puntos',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, color: Colors.amber.shade600, size: 22),
            const SizedBox(width: 2),
            Text(
              '${partida.puntuacion}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: _colorTexto,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBotonTurno(BuildContext context, PartidaState partida) {
    final sinTirar = partida.dados == null;

    return _BotonPrincipal(
      texto: sinTirar ? 'Tirar dados' : 'Siguiente',
      icono: sinTirar ? Icons.casino : Icons.skip_next,
      destacado: partida.numeroColocado && !partida.terminada,
      onPressed: partida.terminada
          ? null
          : sinTirar
          ? () => context.read<PartidaBloc>().add(DadosLanzados())
          : () => _alPulsarSiguiente(context),
    );
  }

  /// Botón de la barra superior para volver al menú de mapas: "Rendirse"
  /// con la partida en curso y "Salir" antes de empezar o al terminar.
  Widget _buildBotonSalir(BuildContext context, PartidaState partida) {
    final enCurso = partida.iniciada && !partida.terminada;

    return Tooltip(
      message: 'Volver al menú de mapas',
      child: TextButton.icon(
        onPressed: () => _salir(context),
        icon: Icon(enCurso ? Icons.flag : Icons.logout),
        label: Text(enCurso ? 'Rendirse' : 'Salir'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.white.withValues(alpha: 0.15),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tablero compartido por la partida local y la multijugador
// ---------------------------------------------------------------------------

/// Tablero de un jugador con los indicadores de zona a los lados. Es el
/// mismo en la partida local y en la multijugador.
class TableroMultijugador extends StatefulWidget {
  final Nivel nivel;
  final Tablero tablero;
  final Map<Coordenada, int> celdas;
  final Set<Coordenada> iniciales;

  /// Casillas iniciales que faltan por llenar.
  final Set<Coordenada> pendientesIniciales;

  /// Casilla inicial a la que va el próximo número (con anillo naranja).
  final Coordenada? seleccionada;

  /// Casillas iniciales vacías donde ya no cabe ningún número (con alerta).
  final Set<Coordenada> sinSalida;
  final Set<Coordenada> anclas;
  final Coordenada? ancla;
  final Set<Coordenada> destinos;

  /// Opciones de colocación al tocar un dado (sin casilla ancla aún).
  final Set<Coordenada> destinosTentativos;
  final void Function(Coordenada c)? onTap;

  /// Lugar con el que se llenó cada zona (para tachar esos puntos).
  final Map<String, int> lugares;

  /// Lugares de cada zona ya tomados por cualquier jugador de la partida:
  /// se tachan en las reglas de los lados (en línea).
  final Map<String, Set<int>> lugaresOcupados;

  const TableroMultijugador({
    super.key,
    required this.nivel,
    required this.tablero,
    required this.celdas,
    required this.iniciales,
    this.pendientesIniciales = const {},
    this.seleccionada,
    this.sinSalida = const {},
    this.anclas = const {},
    this.ancla,
    this.destinos = const {},
    this.destinosTentativos = const {},
    this.onTap,
    this.lugares = const {},
    this.lugaresOcupados = const {},
  });

  @override
  State<TableroMultijugador> createState() => _TableroMultijugadorState();
}

class _TableroMultijugadorState extends State<TableroMultijugador>
    with SingleTickerProviderStateMixin {
  /// Latido de las casillas que piden atención (destinos, casilla elegida).
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );

  /// Cuántas veces late al marcar casillas nuevas. Después se queda quieto:
  /// llama la atención un rato y no deja el tablero animado toda la partida
  /// (así no gasta batería ni marea).
  static const _latidos = 3;

  /// Qué está latiendo ahora: mientras no cambie, el latido no se reinicia
  /// (la pantalla se redibuja a cada segundo por el reloj de la ronda).
  Object? _razonDelLatido;

  /// Cambia con cada latido nuevo: así el latido viejo, al acabarse, no
  /// interrumpe al que lo sustituyó.
  int _generacion = 0;

  Object? get _razon => widget.destinos.isEmpty && widget.seleccionada == null
      ? null
      : Object.hash(
          widget.seleccionada,
          Object.hashAllUnordered(widget.destinos),
        );

  @override
  void initState() {
    super.initState();
    _actualizarPulso();
  }

  @override
  void didUpdateWidget(TableroMultijugador anterior) {
    super.didUpdateWidget(anterior);
    _actualizarPulso();
  }

  /// Solo anima cuando hace falta (no gasta batería con el tablero quieto).
  void _actualizarPulso() {
    final razon = _razon;
    if (razon == _razonDelLatido) return;
    _razonDelLatido = razon;
    final generacion = ++_generacion;
    _pulso
      ..stop()
      ..value = 0;
    if (razon == null) return;
    _pulso.repeat(reverse: true, count: _latidos).whenComplete(() {
      // Al terminar los latidos, las casillas quedan en reposo.
      if (mounted && generacion == _generacion) _pulso.value = 0;
    });
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tablero;
    // Tantos huecos como indicadores tenga el lado más cargado: los dos
    // lados quedan a la misma altura y, si el tablero es chico, cada
    // indicador se achica en vez de quedar cortado (antes, en pantallas
    // bajas, los últimos de cada lado no se veían).
    final huecos = max(
      widget.nivel.indicadoresIzquierda.length,
      widget.nivel.indicadoresDerecha.length,
    );

    return LayoutBuilder(
      builder: (context, c) {
        final alto = c.maxHeight.isFinite ? c.maxHeight : double.infinity;
        final lado = min(min(c.maxWidth - 2 * _anchoIndicadores, alto), 640.0);

        Widget columna(List<String> ids) => SizedBox(
          width: _anchoIndicadores,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final id in ids)
                if (t.zonas[id] != null)
                  SizedBox(
                    height: huecos == 0 ? null : lado / huecos,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: IndicadorZona(
                        zona: t.zonas[id]!,
                        lugarObtenido: widget.lugares[id],
                        lugaresOcupados: widget.lugaresOcupados[id] ?? const {},
                      ),
                    ),
                  ),
            ],
          ),
        );

        return SizedBox(
          width: lado + 2 * _anchoIndicadores,
          height: lado,
          child: Row(
            children: [
              columna(widget.nivel.indicadoresIzquierda),
              Container(
                width: lado,
                height: lado,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Color(0xFFF1F6F4)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFD5E3DD)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: GridView.builder(
                  key: const Key('tablero-mp'),
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: t.columnas,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: t.filas * t.columnas,
                  itemBuilder: (_, i) =>
                      _celda(Coordenada(i ~/ t.columnas, i % t.columnas)),
                ),
              ),
              columna(widget.nivel.indicadoresDerecha),
            ],
          ),
        );
      },
    );
  }

  Widget _celda(Coordenada c) {
    final w = widget;
    final zona = w.tablero.zonaEn(c);
    if (zona == null) return const SizedBox.shrink();

    final tocable =
        w.onTap != null &&
        (w.anclas.contains(c) ||
            w.destinos.contains(c) ||
            w.pendientesIniciales.contains(c) ||
            (w.iniciales.contains(c) && w.seleccionada != null));

    return MouseRegion(
      cursor: tocable ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        key: Key('celda-${c.fila}-${c.columna}'),
        onTap: w.onTap == null ? null : () => w.onTap!(c),
        child: AnimatedBuilder(
          animation: _pulso,
          builder: (context, _) => CeldaTablero(
            color: colorDeTipo(zona.tipo),
            valor: w.celdas[c],
            esInicial: w.iniciales.contains(c),
            zonaCompleta: zona.estaCompleta,
            pendiente: w.pendientesIniciales.contains(c),
            seleccionada: w.seleccionada == c,
            alerta: w.sinSalida.contains(c),
            esAnclaPosible: w.anclas.contains(c),
            esAncla: w.ancla == c,
            esDestino: w.destinos.contains(c),
            esDestinoTentativo: w.destinosTentativos.contains(c),
            pulso: _pulso.value,
            claveValor: 'c${c.fila}-${c.columna}',
          ),
        ),
      ),
    );
  }
}

/// Una casilla del tablero.
class CeldaTablero extends StatelessWidget {
  final Color color;
  final int? valor;
  final bool esInicial;
  final bool zonaCompleta;
  final bool pendiente;
  final bool seleccionada;

  /// Casilla inicial vacía donde ya no cabe ningún número.
  final bool alerta;
  final bool esAnclaPosible;
  final bool esAncla;
  final bool esDestino;

  /// Con un dado elegido (sin casilla ancla aún): aquí podría terminar el
  /// número a colocar. Lleva un contorno suave.
  final bool esDestinoTentativo;

  /// 0..1: fase del latido (para destinos y la casilla elegida).
  final double pulso;

  /// Identifica la casilla: el número "rebota" al aparecer en ella.
  final String claveValor;

  const CeldaTablero({
    super.key,
    required this.color,
    required this.valor,
    required this.esInicial,
    required this.zonaCompleta,
    required this.pendiente,
    required this.seleccionada,
    this.alerta = false,
    required this.esAnclaPosible,
    required this.esAncla,
    required this.esDestino,
    this.esDestinoTentativo = false,
    required this.pulso,
    required this.claveValor,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // En casillas chicas (teléfono) los íconos de ancla y lápiz taparían el
    // número: se quitan y la casilla se marca con borde y brillo.
    builder: (context, medidas) =>
        _celda(chica: medidas.maxWidth < tamanoMinimoParaIconos),
  );

  Widget _celda({required bool chica}) {
    final latido = Curves.easeInOut.transform(pulso);

    // Contorno según lo que se puede hacer con la casilla.
    final Color? borde;
    final double grosor;
    if (seleccionada) {
      (borde, grosor) = (
        Color.lerp(Colors.orange.shade600, Colors.deepOrange.shade700, latido),
        3.5,
      );
    } else if (esDestino) {
      // Contorno discreto: late apenas para llamar la atención sin tapar
      // la casilla (en teléfonos las casillas son chicas).
      (borde, grosor) = (
        colorTextoTablero.withValues(alpha: 0.85),
        2 + latido,
      );
    } else if (esAncla) {
      (borde, grosor) = (Colors.white, 4);
    } else if (esAnclaPosible) {
      (borde, grosor) = (colorTextoTablero.withValues(alpha: 0.75), 2);
    } else if (esDestinoTentativo) {
      // Opción de colocación al tocar un dado (aún sin casilla ancla)
      (borde, grosor) = (colorTextoTablero.withValues(alpha: 0.4), 2);
    } else {
      (borde, grosor) = (Colors.white.withValues(alpha: 0.45), 1.5);
    }

    final hsl = HSLColor.fromColor(color);
    final claro = hsl
        .withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0))
        .toColor();
    final oscuro = hsl
        .withLightness((hsl.lightness - 0.08).clamp(0.0, 1.0))
        .toColor();

    final celda = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [claro, color, oscuro],
        ),
        border: Border.all(color: borde ?? Colors.transparent, width: grosor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: esAncla || esAnclaPosible ? 0.28 : 0.18,
            ),
            blurRadius: esAncla ? 6 : 2,
            offset: Offset(0, esAncla ? 3 : 1),
          ),
          if (esAncla && chica)
            const BoxShadow(
              color: colorBrilloAncla,
              blurRadius: 8,
              spreadRadius: 2,
            ),
          if (seleccionada)
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.35 + 0.35 * latido),
              blurRadius: 6 + 6 * latido,
            ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Brillo de las zonas ya completas.
          if (zonaCompleta)
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.center,
                  colors: [
                    Colors.white.withValues(alpha: 0.45),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          // Anillo interior: doble contraste, se ve sobre cualquier color.
          if (esDestino || esAncla)
            Padding(
              padding: const EdgeInsets.all(1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: esDestino
                        ? Colors.white.withValues(alpha: 0.85)
                        : colorTextoTablero,
                    width: esDestino ? 1 : 1.5,
                  ),
                ),
              ),
            ),
          if (valor != null)
            // La clave va en el hijo directo del Stack: así, aunque aparezca o
            // desaparezca el anillo de ancla/destino, el número no se recrea
            // ni repite el "rebote" (solo rebota cuando se coloca).
            Center(
              key: ValueKey('$claveValor-$valor'),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.3, end: 1),
                duration: const Duration(milliseconds: 380),
                curve: Curves.elasticOut,
                builder: (_, escala, hijo) =>
                    Transform.scale(scale: escala, child: hijo),
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      '$valor',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: esInicial
                            ? FontWeight.w900
                            : FontWeight.w800,
                        fontStyle: esInicial
                            ? FontStyle.italic
                            : FontStyle.normal,
                        color: colorTextoTablero,
                        shadows: [
                          Shadow(
                            color: Colors.white.withValues(alpha: 0.8),
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          else if (pendiente)
            // Casilla inicial vacía: un punto blanco, como en el mapa en miniatura.
            Center(
              child: FractionallySizedBox(
                widthFactor: 0.28,
                heightFactor: 0.28,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          if (alerta)
            Positioned(
              top: 2,
              left: 2,
              child: Icon(
                Icons.warning_amber_rounded,
                key: const Key('alerta-sin-salida'),
                size: 16,
                color: Colors.orange.shade900,
              ),
            ),
          if (seleccionada && !chica)
            const Positioned(
              top: 3,
              right: 3,
              child: Icon(Icons.edit, size: 12, color: colorTextoTablero),
            ),
          if (esAncla && !chica)
            const Positioned(
              top: 3,
              right: 3,
              child: Icon(Icons.anchor, size: 12, color: colorTextoTablero),
            ),
        ],
      ),
    );

    return AnimatedScale(
      scale: esAncla ? 1.07 : 1,
      duration: const Duration(milliseconds: 160),
      child: celda,
    );
  }
}

/// Teclado para los números iniciales: 1 a 6 (los que no se pueden poner en
/// la casilla elegida salen apagados), Borrar y Al azar. Es el mismo en la
/// partida local y en la multijugador.
class TecladoIniciales extends StatelessWidget {
  final Set<int> permitidos;

  /// La casilla elegida ya tiene número (se puede borrar).
  final bool hayElegida;
  final ValueChanged<int> onNumero;
  final VoidCallback onBorrar;
  final VoidCallback onAlAzar;

  const TecladoIniciales({
    super.key,
    required this.permitidos,
    required this.hayElegida,
    required this.onNumero,
    required this.onBorrar,
    required this.onAlAzar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var n = 1; n <= 6; n++)
              SizedBox(
                width: 44,
                height: 44,
                child: FilledButton(
                  key: Key('tecla-$n'),
                  onPressed: permitidos.contains(n) ? () => onNumero(n) : null,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: colorTextoTablero,
                    disabledBackgroundColor: Colors.grey.shade200,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$n',
                      style: const TextStyle(
                        fontSize: 20,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // Wrap y no Row: en el panel angosto de la computadora los dos
        // botones no caben en una línea y antes se desbordaban.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            TextButton.icon(
              key: const Key('borrar-inicial'),
              onPressed: hayElegida ? onBorrar : null,
              icon: const Icon(Icons.backspace_outlined, size: 18),
              label: const Text('Borrar'),
            ),
            TextButton.icon(
              key: const Key('al-azar'),
              onPressed: onAlAzar,
              icon: const Icon(Icons.casino_outlined, size: 18),
              label: const Text('Al azar'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Un dado dibujado con puntos. Si [valor] es null se muestra vacío.
class Dado extends StatelessWidget {
  final int? valor;

  const Dado({super.key, required this.valor});

  /// Posiciones (en una cuadrícula de 3x3) de los puntos de cada cara.
  static const _puntos = {
    1: [4],
    2: [0, 8],
    3: [0, 4, 8],
    4: [0, 2, 6, 8],
    5: [0, 2, 4, 6, 8],
    6: [0, 2, 3, 5, 6, 8],
  };

  @override
  Widget build(BuildContext context) {
    final activos = _puntos[valor] ?? const <int>[];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 56,
      height: 56,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: valor == null ? Colors.grey.shade300 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.teal.shade700, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(1, 2)),
        ],
      ),
      child: valor == null
          ? Center(
              child: Icon(Icons.question_mark, color: Colors.grey.shade500),
            )
          : GridView.count(
              crossAxisCount: 3,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(9, (i) {
                return Center(
                  child: activos.contains(i)
                      ? Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1B3B4D),
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                );
              }),
            ),
    );
  }
}

/// Color con el que se pinta cada tipo de zona en el tablero.
Color colorDeTipo(Tipo tipo) {
  if (tipo is TipoVerde) return const Color(0xFF66BB6A);
  if (tipo is TipoAzul) return const Color(0xFF42A5F5);
  if (tipo is TipoRojo) return const Color(0xFFEF5350);
  if (tipo is TipoAmarillo) return const Color(0xFFFFCA28);
  if (tipo is TipoMorado) return const Color(0xFFAB47BC);
  if (tipo is TipoGris) return const Color(0xFFCFD8DC);
  if (tipo is TipoNaranja) return const Color(0xFFFFA726);
  return Colors.grey;
}

String nombreDeTipo(Tipo tipo) {
  if (tipo is TipoVerde) return 'Verde';
  if (tipo is TipoAzul) return 'Azul';
  if (tipo is TipoRojo) return 'Rojo';
  if (tipo is TipoAmarillo) return 'Amarillo';
  if (tipo is TipoMorado) return 'Morado';
  if (tipo is TipoGris) return 'Gris';
  if (tipo is TipoNaranja) return 'Naranja ${tipo.minimo}-${tipo.maximo}';
  return '?';
}

/// Acotaciones: regla de cada color, puntos al completar una zona de ese
/// color y cuántas zonas de ese color ya están completas.
class _LeyendaZonas extends StatelessWidget {
  final Tablero tablero;

  const _LeyendaZonas({required this.tablero});

  @override
  Widget build(BuildContext context) {
    // Una entrada por tipo de zona, de más a menos puntos
    final porTipo = <Type, List<Zona>>{};
    for (final zona in tablero.zonas.values) {
      porTipo.putIfAbsent(zona.tipo.runtimeType, () => []).add(zona);
    }
    final grupos = porTipo.values.toList()
      ..sort(
        (a, b) => (b.first.tipo.puntuaciones[1] ?? 0).compareTo(
          a.first.tipo.puntuaciones[1] ?? 0,
        ),
      );

    return TarjetaPanel(
      titulo: 'Puntos al completar una zona',
      icono: Icons.emoji_events_outlined,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1º, 2º y 3º son los puntos para el primer, segundo y tercer '
            'jugador en llenar esa zona. Por ahora cada zona que llenes '
            'da los del 1º, aunque ya hayas llenado otra del mismo color.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          _buildEncabezado(),
          const Divider(height: 8),
          for (final zonas in grupos) _buildFila(zonas),
        ],
      ),
    );
  }

  static const _anchoLugar = 30.0;
  static const _anchoCompletas = 34.0;

  /// Títulos de las columnas: 1º, 2º, 3º y zonas llenas.
  Widget _buildEncabezado() {
    final estilo = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: Colors.grey.shade600,
    );
    return Row(
      children: [
        Expanded(child: Text('Color y regla', style: estilo)),
        for (final lugar in ['1º', '2º', '3º'])
          SizedBox(
            width: _anchoLugar,
            child: Text(lugar, textAlign: TextAlign.center, style: estilo),
          ),
        const SizedBox(width: 8),
        SizedBox(
          width: _anchoCompletas,
          child: Text('Llenas', textAlign: TextAlign.right, style: estilo),
        ),
      ],
    );
  }

  Widget _buildFila(List<Zona> zonas) {
    final tipo = zonas.first.tipo;
    final completas = zonas.where((z) => z.estaCompleta).length;
    final lugares = tipo.puntuaciones.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: colorDeTipo(tipo),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${nombreDeTipo(tipo)}: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: tipo.descripcion),
                ],
              ),
              style: const TextStyle(fontSize: 12, color: Color(0xFF1B3B4D)),
            ),
          ),
          // Puntos del 1º, 2º y 3º en llenar la zona (el 1º resaltado)
          for (final lugar in lugares.take(3))
            SizedBox(
              width: _anchoLugar,
              child: Text(
                '${tipo.puntuaciones[lugar]}',
                textAlign: TextAlign.center,
                style: lugar == 1
                    ? const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: _colorTexto,
                      )
                    : TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
          const SizedBox(width: 8),
          SizedBox(
            width: _anchoCompletas,
            child: Text(
              '$completas/${zonas.length}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: completas > 0
                    ? Colors.teal.shade700
                    : Colors.grey.shade500,
                fontWeight: completas > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Color de los textos y contornos del tablero.
const colorTextoTablero = Color(0xFF1B3B4D);
const _colorTexto = colorTextoTablero;

/// Ancho de cada columna de indicadores a los lados del tablero.
const _anchoIndicadores = 48.0;

/// A partir de este ancho la pantalla se considera ancha (computadora o
/// tablet acostada): el panel va al lado del tablero en vez de abajo. Lo
/// usan igual la partida de un jugador y la partida en línea, para que las
/// dos cambien de forma en el mismo punto.
const anchoPantallaAncha = 900.0;

/// Símbolo de la regla de cada tipo, como en la hoja del nivel.
String simboloDeTipo(Tipo tipo) {
  if (tipo is TipoVerde) return '?';
  if (tipo is TipoAzul || tipo is TipoGris) return '=';
  if (tipo is TipoRojo || tipo is TipoAmarillo) return '≠';
  if (tipo is TipoMorado) return 'XO';
  if (tipo is TipoNaranja) return '${tipo.minimo}-${tipo.maximo}';
  return '?';
}

/// Indicador de una zona al lado del tablero: cuadro de su color con el
/// símbolo de su regla y, debajo, los puntos del 1º, 2º y 3º en llenarla.
/// Cuando la zona está llena lleva una palomita y se tachan los puntos que
/// se ganaron con ella. Los lugares que ya tomó cualquier otro jugador
/// ([lugaresOcupados]) también se van tachando, como en la hoja de papel.
class IndicadorZona extends StatelessWidget {
  final Zona zona;

  /// Lugar (1, 2 o 3) con el que se llenó la zona. Si es null y la zona
  /// está llena, se toma el 1º (jugando solo siempre se gana el 1º).
  final int? lugarObtenido;

  /// Lugares de esta zona que ya tomó cualquier jugador de la partida.
  final Set<int> lugaresOcupados;

  const IndicadorZona({
    super.key,
    required this.zona,
    this.lugarObtenido,
    this.lugaresOcupados = const {},
  });

  @override
  Widget build(BuildContext context) {
    final tipo = zona.tipo;
    final simbolo = simboloDeTipo(tipo);
    final obtenido = zona.estaCompleta ? (lugarObtenido ?? 1) : null;

    // El lugar que me tocaría si llenara la zona ahora: el más bajo libre.
    final proximo = obtenido != null
        ? null
        : [1, 2, 3].where((l) => !lugaresOcupados.contains(l)).firstOrNull;

    return Tooltip(
      message:
          'Zona ${nombreDeTipo(tipo).toLowerCase()}: '
          '${tipo.descripcion}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 30,
                decoration: BoxDecoration(
                  color: colorDeTipo(tipo),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 2,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    simbolo,
                    style: TextStyle(
                      fontSize: simbolo.length > 1 ? 12 : 17,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: _colorTexto,
                    ),
                  ),
                ),
              ),
              if (zona.estaCompleta)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.done,
                      size: 14,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final lugar in [1, 2, 3])
                _PuntoLugar(
                  key: Key('puntos-${zona.id}-$lugar'),
                  puntos: tipo.puntuaciones[lugar] ?? 0,
                  color: obtenido == lugar
                      ? Colors.teal.shade700
                      : lugaresOcupados.contains(lugar)
                      ? Colors.grey.shade400
                      : obtenido != null
                      ? Colors.grey.shade300
                      : lugar == proximo
                      ? _colorTexto
                      : Colors.grey.shade500,
                  tachado:
                      obtenido == lugar || lugaresOcupados.contains(lugar),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Casillas más angostas que esto (teléfono) no llevan íconos de ancla ni de
/// lápiz encima: taparían el número. Se marcan con borde y brillo.
const tamanoMinimoParaIconos = 56.0;

/// Brillo oscuro alrededor del ancla en casillas chicas (en vez del ícono).
const colorBrilloAncla = Color(0xCC1B3B4D);

/// Circulito con los puntos de un lugar; [tachado] = ese lugar ya se ganó
/// (por mí o por otro jugador).
class _PuntoLugar extends StatelessWidget {
  final int puntos;
  final Color color;
  final bool tachado;

  const _PuntoLugar({
    super.key,
    required this.puntos,
    required this.color,
    required this.tachado,
  });

  @override
  Widget build(BuildContext context) {
    final circulo = Container(
      width: 14,
      height: 14,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$puntos',
          style: const TextStyle(
            fontSize: 9,
            height: 1,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.5),
      child: tachado
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                circulo,
                // Raya diagonal, como al tachar en la hoja de papel. Va
                // posicionada para no agrandar el circulito (14 × 14).
                Positioned(
                  left: -2.5,
                  top: 5.75,
                  child: Transform.rotate(
                    angle: -0.8,
                    child: Container(
                      width: 19,
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : circulo,
    );
  }
}

/// Tarjeta blanca del panel lateral, con título opcional.
class TarjetaPanel extends StatelessWidget {
  final String? titulo;
  final IconData? icono;
  final Widget child;

  const TarjetaPanel({super.key, this.titulo, this.icono, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (titulo != null) ...[
            Row(
              children: [
                if (icono != null) ...[
                  Icon(icono, size: 18, color: Colors.teal.shade700),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    titulo!,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

class _BotonPrincipal extends StatelessWidget {
  final String texto;
  final IconData icono;
  final VoidCallback? onPressed;

  /// Pinta el botón en naranja para indicar que es el siguiente paso.
  final bool destacado;

  const _BotonPrincipal({
    required this.texto,
    required this.icono,
    this.onPressed,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: destacado
              ? Colors.orange.shade700
              : Colors.teal.shade700,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icono),
        label: Text(
          texto,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// Dado de la barra inferior. Se toca para elegirlo como ancla;
/// el elegido queda con borde naranja.
class _DadoElegible extends StatelessWidget {
  final int? valor;
  final bool elegido;

  /// true si con este dado no hay ninguna jugada posible.
  final bool apagado;
  final VoidCallback? onTap;

  /// Identifica la tirada (el turno): al cambiar, el dado vuelve a caer.
  final int tirada;

  /// Espera antes de caer, para que los 2 dados no caigan a la vez.
  final Duration retraso;

  const _DadoElegible({
    required this.valor,
    required this.elegido,
    required this.apagado,
    required this.tirada,
    this.retraso = Duration.zero,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dado = DadoAnimado(
      valor: valor,
      tirada: tirada,
      retraso: retraso,
      builder: (cara, rodando) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: elegido && !rodando
                ? Colors.orange.shade700
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: Opacity(
          opacity: apagado && !rodando ? 0.35 : 1,
          child: Dado(valor: cara),
        ),
      ),
    );

    final conAyuda = Tooltip(
      message: valor == null
          ? 'Aún no se tiran los dados'
          : apagado
          ? 'Ningún $valor del tablero tiene espacio'
          : elegido
          ? 'Este es tu ancla'
          : 'Usar el $valor como ancla',
      child: dado,
    );

    // Siempre la misma estructura (aunque no se pueda tocar): si cambiara,
    // Flutter recrearía el dado y se perdería la animación de la tirada
    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(onTap: onTap, child: conAyuda),
    );
  }
}

/// Leyenda compacta: un chip por color con sus puntos y zonas completas.
/// Al pasar el mouse (o mantener presionado) se ve la regla; el botón
/// "Reglas" abre la explicación completa.
class LeyendaChips extends StatelessWidget {
  final Tablero tablero;

  const LeyendaChips({super.key, required this.tablero});

  @override
  Widget build(BuildContext context) {
    final porTipo = <Type, List<Zona>>{};
    for (final zona in tablero.zonas.values) {
      porTipo.putIfAbsent(zona.tipo.runtimeType, () => []).add(zona);
    }
    final grupos = porTipo.values.toList()
      ..sort(
        (a, b) => (b.first.tipo.puntuaciones[1] ?? 0).compareTo(
          a.first.tipo.puntuaciones[1] ?? 0,
        ),
      );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final zonas in grupos) _buildChip(zonas),
        TextButton.icon(
          onPressed: () => showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            // Desplazable: en pantallas bajas la leyenda no cabe completa
            builder: (_) => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _LeyendaZonas(tablero: tablero),
            ),
          ),
          icon: const Icon(Icons.info_outline, size: 18),
          label: const Text('Reglas'),
          style: TextButton.styleFrom(foregroundColor: Colors.teal.shade800),
        ),
      ],
    );
  }

  Widget _buildChip(List<Zona> zonas) {
    final tipo = zonas.first.tipo;
    final completas = zonas.where((z) => z.estaCompleta).length;

    return Tooltip(
      message:
          '${nombreDeTipo(tipo)}: ${tipo.descripcion}\n'
          'Puntos por zona: 1º ${tipo.puntuaciones[1] ?? 0} · '
          '2º ${tipo.puntuaciones[2] ?? 0} · 3º ${tipo.puntuaciones[3] ?? 0}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: completas > 0 ? Colors.teal.shade400 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colorDeTipo(tipo),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            _PuntosZona(tipo: tipo),
            const SizedBox(width: 6),
            Text(
              '$completas/${zonas.length}',
              style: TextStyle(
                fontSize: 12,
                color: completas > 0
                    ? Colors.teal.shade700
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Puntos que da cada zona de un color al llenarla, ej. "+4".
class _PuntosZona extends StatelessWidget {
  final Tipo tipo;

  const _PuntosZona({required this.tipo});

  @override
  Widget build(BuildContext context) {
    return Text(
      '+${tipo.puntuaciones[1] ?? 0}',
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: _colorTexto,
      ),
    );
  }
}

/// Anima un dado cayendo: baja desde arriba girando, rebota al tocar la
/// barra y cambia de cara mientras rueda hasta mostrar [valor].
/// Se repite cada vez que cambia [tirada] o el dado pasa de vacío a tener valor.
class DadoAnimado extends StatefulWidget {
  final int? valor;
  final int tirada;
  final Duration retraso;

  /// Dibuja el dado con la [cara] visible; [rodando] es true durante la caída.
  final Widget Function(int? cara, bool rodando) builder;

  /// Si es true, el dado también cae la primera vez que aparece (no solo
  /// cuando cambia la tirada).
  final bool animarAlAparecer;

  const DadoAnimado({
    super.key,
    required this.valor,
    required this.tirada,
    required this.retraso,
    required this.builder,
    this.animarAlAparecer = false,
  });

  @override
  State<DadoAnimado> createState() => _DadoAnimadoState();
}

class _DadoAnimadoState extends State<DadoAnimado>
    with SingleTickerProviderStateMixin {
  static const _altura = 90.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1, // Sin animación al aparecer por primera vez
  );

  @override
  void initState() {
    super.initState();
    if (widget.animarAlAparecer && widget.valor != null) _lanzar();
  }

  @override
  void didUpdateWidget(DadoAnimado anterior) {
    super.didUpdateWidget(anterior);
    final nuevaTirada =
        widget.valor != null &&
        (anterior.tirada != widget.tirada || anterior.valor == null);
    if (nuevaTirada) _lanzar();
  }

  Future<void> _lanzar() async {
    _controller.value = 0;
    if (widget.retraso > Duration.zero) {
      await Future<void>.delayed(widget.retraso);
      if (!mounted) return;
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final rodando = t < 1;

        // Cae con rebote y gira cada vez más lento hasta quedar derecho
        final caida = Curves.bounceOut.transform(t);
        final giro = (1 - Curves.easeOutCubic.transform(t)) * pi * 3;

        // Mientras rueda muestra caras al azar; al final, la verdadera
        final int? cara;
        if (widget.valor == null || t >= 0.7) {
          cara = widget.valor;
        } else {
          final paso = (t * 14).floor();
          cara =
              Random(widget.tirada * 97 + paso * 13 + hashCode).nextInt(6) + 1;
        }

        return Opacity(
          opacity: (t * 5).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -_altura * (1 - caida)),
            child: Transform.rotate(
              angle: giro,
              child: widget.builder(cara, rodando),
            ),
          ),
        );
      },
    );
  }
}
