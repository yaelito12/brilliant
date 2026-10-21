import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'tablero.dart';
import 'tipo.dart';
import 'zona.dart';
import 'nivel.dart';
import 'niveles.dart';
import 'bloc/juego_bloc.dart';
import 'bloc/juego_event.dart';
import 'bloc/juego_state.dart';
import 'bloc/partida_bloc.dart';
import 'bloc/partida_event.dart';
import 'bloc/partida_state.dart';

class TableroPage extends StatefulWidget {
  /// Mapas que se pueden elegir; por defecto, los oficiales.
  final List<Nivel>? niveles;

  /// Generador de los dados (en los tests, para que salgan valores fijos).
  final Random? random;

  const TableroPage({super.key, this.niveles, this.random});

  @override
  State<TableroPage> createState() => _TableroPageState();
}

class _TableroPageState extends State<TableroPage> {
  List<Nivel> get _niveles => widget.niveles ?? nivelesOficiales;

  late Nivel _nivel = _niveles.first;

  @override
  Widget build(BuildContext context) {
    // La llave hace que al cambiar de mapa se creen blocs nuevos:
    // la partida empieza de cero en el mapa elegido
    return MultiBlocProvider(
      key: ValueKey(_nivel),
      providers: [
        BlocProvider(create: (_) => JuegoBloc()),
        BlocProvider(create: (_) => PartidaBloc(random: widget.random)),
      ],
      child: _TableroView(
        nivel: _nivel,
        niveles: _niveles,
        onCambiarNivel: (nivel) => setState(() => _nivel = nivel),
      ),
    );
  }
}

class _TableroView extends StatefulWidget {
  final Nivel nivel;
  final List<Nivel> niveles;
  final ValueChanged<Nivel> onCambiarNivel;

  const _TableroView({
    required this.nivel,
    required this.niveles,
    required this.onCambiarNivel,
  });

  @override
  State<_TableroView> createState() => _TableroViewState();
}

class _TableroViewState extends State<_TableroView> {
  late Tablero _tablero;

  /// Mapa de qué número el jugador ha puesto en cada casilla inicial
  final Map<Coordenada, int> _valoresIniciales = {};

  @override
  void initState() {
    super.initState();
    _tablero = widget.nivel.construirTablero();
  }

  Set<Coordenada> get _casillasIniciales => widget.nivel.casillasIniciales;

  bool get _todasLasCasillasInicalesLlenas {
    return _casillasIniciales.every(
      (c) => _valoresIniciales.containsKey(c),
    );
  }

  /// Abre el selector de mapas. Si ya hay números puestos pide
  /// confirmación, porque al cambiar se pierde la partida.
  Future<void> _elegirMapa(BuildContext context) async {
    final elegido = await showDialog<Nivel>(
      context: context,
      builder: (_) => _SelectorMapa(
        niveles: widget.niveles,
        actual: widget.nivel,
      ),
    );
    if (elegido == null || elegido == widget.nivel || !context.mounted) {
      return;
    }

    final hayProgreso = context.read<PartidaBloc>().state.iniciada ||
        _valoresIniciales.isNotEmpty;
    if (hayProgreso) {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(Icons.map, color: Colors.teal.shade700, size: 40),
          title: Text('¿Cambiar al ${elegido.nombre}?'),
          content: const Text(
            'Se perderán los números puestos en el mapa actual.',
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
              child: const Text('Sí, cambiar'),
            ),
          ],
        ),
      );
      if (confirmado != true) return;
    }

    widget.onCambiarNivel(elegido);
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

    // Antes de empezar la partida se pueden corregir los valores iniciales
    if (!_casillasIniciales.contains(coordenada)) return;
    _mostrarSelectorNumero(context, coordenada);
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

  void _mostrarSelectorNumero(BuildContext context, Coordenada coordenada) {
    final bloc = context.read<JuegoBloc>();
    final valorActual = _valoresIniciales[coordenada];
    final ocupadosPorOtros = _valoresIniciales.entries
        .where((e) => e.key != coordenada)
        .map((e) => e.value)
        .toSet();

    final focusNode = FocusNode();
    focusNode.requestFocus();

    void seleccionarNumero(int numero) {
      // No permitir si está ocupado
      if (ocupadosPorOtros.contains(numero)) return;
      Navigator.pop(context);
      setState(() {
        _valoresIniciales[coordenada] = numero;
      });
      if (!_todasLasCasillasInicalesLlenas) {
        bloc.add(ValoresInicialesIncompletos());
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return KeyboardListener(
          focusNode: focusNode,
          onKeyEvent: (event) {
            if (event is KeyDownEvent) {
              final keyLabel = event.logicalKey.keyLabel;
              if (['1', '2', '3', '4', '5', '6'].contains(keyLabel)) {
                seleccionarNumero(int.parse(keyLabel));
              } else if (event.logicalKey.keyLabel == 'Backspace' ||
                  event.logicalKey.keyLabel == 'Delete') {
                if (valorActual != null) {
                  Navigator.pop(context);
                  setState(() {
                    _valoresIniciales.remove(coordenada);
                  });
                  bloc.add(ValoresInicialesIncompletos());
                }
              }
            }
          },
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Elige un número (1-6) — sin repetir',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Puedes presionar un número en tu teclado',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (i) {
                    final numero = i + 1;
                    final estaOcupado = ocupadosPorOtros.contains(numero);
                    final esSeleccionado = valorActual == numero;

                    return GestureDetector(
                      onTap: estaOcupado
                          ? null
                          : () => seleccionarNumero(numero),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: estaOcupado
                              ? Colors.grey.shade300
                              : esSeleccionado
                              ? Colors.orange.shade600
                              : Colors.teal.shade600,
                          shape: BoxShape.circle,
                          border: esSeleccionado
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '$numero',
                            style: TextStyle(
                              color: estaOcupado
                                  ? Colors.grey.shade500
                                  : Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: valorActual == null
                      ? null
                      : () {
                          Navigator.pop(context);
                          setState(() {
                            _valoresIniciales.remove(coordenada);
                          });
                          bloc.add(ValoresInicialesIncompletos());
                        },
                  icon: Icon(
                    Icons.delete,
                    color: valorActual == null ? Colors.grey : Colors.red,
                  ),
                  label: Text(
                    'Borrar número (Supr)',
                    style: TextStyle(
                      color: valorActual == null ? Colors.grey : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() => focusNode.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<JuegoBloc, JuegoState>(
          listener: (context, state) {
            if (state is JuegoListo) {
              context.read<PartidaBloc>().add(
                PartidaIniciada(_tablero, Map.of(_valoresIniciales)),
              );
              _mostrarSnack(
                context,
                Icons.check_circle,
                '¡Valores iniciales listos! El juego puede comenzar.',
              );
            }
          },
        ),
        // Al colocar un número: aviso si completó una zona o el tablero
        // (los dados del siguiente turno ya se tiraron solos)
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
              _mostrarSnack(
                context,
                Icons.emoji_events,
                '¡Tablero completo! Puntuación final: ${state.puntuacion}',
              );
            } else if (completoZona) {
              final id = completadas.last;
              final color = nombreDeTipo(tablero.zonas[id]!.tipo).toLowerCase();
              _mostrarSnack(
                context,
                Icons.star,
                '¡Zona $color completada! +${tablero.puntosDe(id)} puntos',
              );
            }
          },
        ),
      ],
      child: BlocBuilder<JuegoBloc, JuegoState>(
        builder: (context, juego) {
          return BlocBuilder<PartidaBloc, PartidaState>(
            builder: (context, partida) {
              return Scaffold(
                backgroundColor: const Color(0xFFE8F2ED),
                appBar: AppBar(
                  title: const Text(
                    'Brilliant',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  actions: [
                    Tooltip(
                      message: 'Elegir mapa',
                      child: TextButton.icon(
                        onPressed: () => _elegirMapa(context),
                        icon: const Icon(Icons.map),
                        label: Text(widget.nivel.nombre),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                // Los dados y el botón van pegados al tablero para no
                // tener que cruzar la pantalla en cada jugada
                body: LayoutBuilder(
                  builder: (context, constraints) {
                    final tablero = _buildTablero(context, juego, partida);
                    final leyenda = _LeyendaChips(
                      tablero: partida.tablero ?? _tablero,
                    );

                    // Pantalla ancha: panel justo a la derecha del tablero
                    if (constraints.maxWidth >= 860) {
                      const anchoPanel = 320.0;
                      final lado = min(
                        min(constraints.maxHeight - 32, 640.0),
                        constraints.maxWidth - anchoPanel - 64,
                      );
                      return Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: lado, height: lado, child: tablero),
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
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 560,
                                ),
                                child: tablero,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: _buildPanelInferior(context, juego, partida),
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
              );
            },
          );
        },
      ),
    );
  }

  void _mostrarSnack(
    BuildContext context,
    IconData icono,
    String texto, {
    SnackBarAction? accion,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          action: accion,
          // Con botón, el aviso se queda hasta que se pulse Siguiente
          persist: accion != null,
          content: Row(
            children: [
              Icon(icono, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  texto,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.teal.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  /// El tablero 7x7.
  Widget _buildTablero(
    BuildContext context,
    JuegoState juego,
    PartidaState partida,
  ) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _tablero.columnas,
            crossAxisSpacing: 3.0,
            mainAxisSpacing: 3.0,
          ),
          itemCount: _tablero.filas * _tablero.columnas,
          itemBuilder: (context, index) {
            final fila = index ~/ _tablero.columnas;
            final columna = index % _tablero.columnas;
            return _buildCelda(context, fila, columna, juego, partida);
          },
        ),
      ),
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
      return _Tarjeta(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoPreparacion(),
            const SizedBox(height: 14),
            _buildBotonComenzar(context, juego),
          ],
        ),
      );
    }

    return _Tarjeta(
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
    return _Tarjeta(
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
            _buildInfoPreparacion(),
          const SizedBox(height: 10),
          partida.iniciada
              ? _buildBotonTurno(context, partida)
              : _buildBotonComenzar(context, juego),
        ],
      ),
    );
  }

  Widget _buildInfoPreparacion() {
    final pendientes = _casillasIniciales
        .where((c) => !_valoresIniciales.containsKey(c))
        .length;

    return Row(
      children: [
        Icon(Icons.edit, color: Colors.orange.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            pendientes > 0
                ? 'Toca las casillas marcadas y pon los números del 1 al 6 sin repetir. Faltan $pendientes.'
                : 'Todos los números iniciales están puestos.',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _colorTexto,
            ),
          ),
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

  Widget _buildCelda(
    BuildContext context,
    int fila,
    int columna,
    JuegoState juego,
    PartidaState partida,
  ) {
    final coordenada = Coordenada(fila, columna);
    final zona = _tablero.zonaEn(coordenada);

    if (zona == null) {
      return Container(color: Colors.transparent);
    }

    final esInicial = _casillasIniciales.contains(coordenada);
    final valor = partida.iniciada
        ? partida.celdas[coordenada]
        : _valoresIniciales[coordenada];
    final estaEsperando = !partida.iniciada && juego is JuegoEsperandoValores;

    final esAnclaSeleccionada = partida.ancla == coordenada;
    final esDestino = partida.destinosPosibles.contains(coordenada);
    final colorBase = colorDeTipo(zona.tipo);

    final BoxBorder borde;
    // Anillo interior de otro color: el contraste doble (oscuro + blanco)
    // se distingue sobre cualquier color de zona
    Color? anillo;
    // Flutter solo permite borderRadius con bordes de un solo color
    var bordeUniforme = true;
    if (esDestino) {
      // Donde se puede poner el número: oscuro por fuera, blanco por dentro
      borde = Border.all(color: _colorTexto, width: 4);
      anillo = Colors.white;
    } else if (esAnclaSeleccionada) {
      // Ancla elegida: al revés, blanco por fuera, oscuro por dentro
      borde = Border.all(color: Colors.white, width: 4);
      anillo = _colorTexto;
    } else if (esInicial && estaEsperando) {
      // Casillas iniciales mientras se eligen los valores: vacías con el
      // mismo contorno marcado; ya llenas, con un borde oscuro sencillo
      if (valor == null) {
        borde = Border.all(color: _colorTexto, width: 4);
        anillo = Colors.white;
      } else {
        borde = Border.all(color: _colorTexto, width: 2);
      }
    } else {
      bordeUniforme = false;
      borde = Border(
        top: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 2),
        left: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 2),
        bottom: BorderSide(
          color: Colors.black.withValues(alpha: 0.25),
          width: 2,
        ),
        right: BorderSide(
          color: Colors.black.withValues(alpha: 0.25),
          width: 2,
        ),
      );
    }

    return GestureDetector(
      onTap: () => _alTocarCelda(context, coordenada),
      // Sin animación: interpolar entre un borde uniforme con esquinas
      // redondeadas y el borde biselado (4 colores) hace fallar a Flutter
      child: Container(
        decoration: BoxDecoration(
          borderRadius: bordeUniforme ? BorderRadius.circular(6) : null,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorBase.withValues(alpha: 0.5),
              colorBase,
              colorBase.withAlpha(200),
            ],
          ),
          border: borde,
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 2,
              offset: Offset(1, 1),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Número (inicial o colocado)
            Center(
              child: Text(
                valor != null ? '$valor' : '',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: esInicial ? FontWeight.w900 : FontWeight.w700,
                  fontStyle: esInicial ? FontStyle.italic : FontStyle.normal,
                  color: const Color(0xFF1B3B4D),
                  shadows: [
                    Shadow(
                      color: Colors.white.withValues(alpha: 0.8),
                      offset: const Offset(1, 1),
                      blurRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
            // Ícono de lápiz en casillas iniciales vacías (mientras espera)
            if (esInicial && valor == null && estaEsperando)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.edit, size: 14, color: _colorTexto),
              ),
            if (anillo != null)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: anillo, width: 2),
                  ),
                ),
              ),
            // Ícono de ancla en la casilla seleccionada
            if (esAnclaSeleccionada)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.anchor, size: 12, color: Color(0xFF1B3B4D)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Un dado dibujado con puntos. Si [valor] es null se muestra vacío.
class _Dado extends StatelessWidget {
  final int? valor;

  const _Dado({required this.valor});

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
  return Colors.grey;
}

String nombreDeTipo(Tipo tipo) {
  if (tipo is TipoVerde) return 'Verde';
  if (tipo is TipoAzul) return 'Azul';
  if (tipo is TipoRojo) return 'Rojo';
  if (tipo is TipoAmarillo) return 'Amarillo';
  if (tipo is TipoMorado) return 'Morado';
  if (tipo is TipoGris) return 'Gris';
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

    return _Tarjeta(
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

const _colorTexto = Color(0xFF1B3B4D);

/// Tarjeta blanca del panel lateral, con título opcional.
class _Tarjeta extends StatelessWidget {
  final String? titulo;
  final IconData? icono;
  final Widget child;

  const _Tarjeta({this.titulo, this.icono, required this.child});

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
    final dado = _DadoAnimado(
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
          child: _Dado(valor: cara),
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
class _LeyendaChips extends StatelessWidget {
  final Tablero tablero;

  const _LeyendaChips({required this.tablero});

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
      message: '${nombreDeTipo(tipo)}: ${tipo.descripcion}\n'
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
class _DadoAnimado extends StatefulWidget {
  final int? valor;
  final int tirada;
  final Duration retraso;

  /// Dibuja el dado con la [cara] visible; [rodando] es true durante la caída.
  final Widget Function(int? cara, bool rodando) builder;

  const _DadoAnimado({
    required this.valor,
    required this.tirada,
    required this.retraso,
    required this.builder,
  });

  @override
  State<_DadoAnimado> createState() => _DadoAnimadoState();
}

class _DadoAnimadoState extends State<_DadoAnimado>
    with SingleTickerProviderStateMixin {
  static const _altura = 90.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1, // Sin animación al aparecer por primera vez
  );

  @override
  void didUpdateWidget(_DadoAnimado anterior) {
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

/// Diálogo para elegir uno de los mapas; devuelve el [Nivel] tocado.
class _SelectorMapa extends StatelessWidget {
  final List<Nivel> niveles;
  final Nivel actual;

  const _SelectorMapa({required this.niveles, required this.actual});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Elige un mapa'),
      content: SingleChildScrollView(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final nivel in niveles)
              _TarjetaMapa(
                nivel: nivel,
                elegido: nivel == actual,
                onTap: () => Navigator.pop(context, nivel),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

/// Un mapa del selector: su nombre y el tablero en miniatura.
/// El mapa que se está jugando lleva un borde verde azulado.
class _TarjetaMapa extends StatelessWidget {
  final Nivel nivel;
  final bool elegido;
  final VoidCallback onTap;

  const _TarjetaMapa({
    required this.nivel,
    required this.elegido,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: elegido ? Colors.teal.shade700 : Colors.grey.shade300,
            width: elegido ? 3 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MiniMapa(nivel: nivel),
            const SizedBox(height: 6),
            Text(
              nivel.nombre,
              style: TextStyle(
                fontWeight: elegido ? FontWeight.bold : FontWeight.w600,
                color: _colorTexto,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tablero de [nivel] en miniatura: cada casilla con el color de su zona y
/// un punto blanco en las casillas iniciales.
class MiniMapa extends StatelessWidget {
  final Nivel nivel;

  /// Lado de cada casilla.
  final double lado;

  const MiniMapa({super.key, required this.nivel, this.lado = 14});

  @override
  Widget build(BuildContext context) {
    final tablero = nivel.construirTablero();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var f = 0; f < tablero.filas; f++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var c = 0; c < tablero.columnas; c++)
                _buildCasilla(tablero, Coordenada(f, c)),
            ],
          ),
      ],
    );
  }

  Widget _buildCasilla(Tablero tablero, Coordenada coordenada) {
    final zona = tablero.zonaEn(coordenada);

    return Container(
      width: lado,
      height: lado,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: zona == null ? Colors.transparent : colorDeTipo(zona.tipo),
        borderRadius: BorderRadius.circular(3),
      ),
      child: nivel.casillasIniciales.contains(coordenada)
          ? Center(
              child: Container(
                width: lado / 3,
                height: lado / 3,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}
