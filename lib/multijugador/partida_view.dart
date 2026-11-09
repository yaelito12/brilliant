import 'dart:async';
import 'dart:math';

import 'package:brilliant_reglas/brilliant_reglas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../aviso_sin_salida.dart';
import '../tablero_ui.dart'
    show Dado, DadoAnimado, IndicadorZona, colorDeTipo, colorTextoTablero;
import 'lobby_bloc.dart';
import 'modelos.dart';

const _anchoIndicadores = 48.0;

/// Pantalla de una partida multijugador: mi tablero (o el de otro jugador, si
/// lo elijo en el marcador), los dados de la ronda, el tiempo que queda, los
/// botones de pasar y rendirse y el marcador de todos.
///
/// La app solo propone jugadas: el servidor las valida y manda el estado
/// nuevo. Lo único local es el ancla elegida y los números iniciales que se
/// están escribiendo.
class PartidaMultijugadorView extends StatefulWidget {
  final LobbyState state;
  const PartidaMultijugadorView({super.key, required this.state});

  @override
  State<PartidaMultijugadorView> createState() =>
      _PartidaMultijugadorViewState();
}

class _PartidaMultijugadorViewState extends State<PartidaMultijugadorView> {
  Coordenada? _ancla;
  final Map<Coordenada, int> _iniciales = {};

  /// Casilla inicial elegida a mano (null = la primera vacía).
  Coordenada? _casillaElegida;

  /// Jugador cuyo tablero se está viendo (null = el mío).
  String? _viendo;

  PartidaInfo get _partida => widget.state.partida!;
  JugadorPartidaInfo? get _yo => widget.state.yoEnPartida;

  @override
  void didUpdateWidget(PartidaMultijugadorView viejo) {
    super.didUpdateWidget(viejo);
    final antes = viejo.state.partida;
    // Ronda nueva (dados nuevos): el ancla de la ronda anterior ya no sirve.
    if (antes?.ronda != _partida.ronda || antes?.fase != _partida.fase)
      _ancla = null;
  }

  /// Puedo tocar mi tablero ahora mismo.
  bool get _puedoJugar {
    final yo = _yo;
    return yo != null &&
        _viendo == null &&
        yo.activo &&
        !yo.yaJugo &&
        !yo.completo &&
        widget.state.conectado &&
        !widget.state.esperando &&
        !_partida.terminada;
  }

  @override
  Widget build(BuildContext context) {
    final yo = _yo;
    final viendo = (_viendo == null ? null : _partida.jugador(_viendo!)) ?? yo;
    if (viendo == null || viendo.mapa == null) {
      return const Center(child: Text('Ya no participas en esta partida.'));
    }

    final tablero = viendo.tablero();
    final celdas = viendo.id == yo?.id && _partida.enIniciales && !viendo.yaJugo
        ? {...viendo.celdas, ..._iniciales}
        : viendo.celdas;
    final jugadas = _jugadasPosibles(tablero, celdas);

    final vistaTablero = TableroMultijugador(
      nivel: viendo.mapa!,
      tablero: tablero,
      celdas: celdas,
      iniciales: viendo.mapa!.casillasIniciales,
      pendientesIniciales: _poniendoIniciales
          ? viendo.mapa!.casillasIniciales
                .where((c) => !_iniciales.containsKey(c))
                .toSet()
          : const {},
      seleccionada: _casillaActiva(viendo.mapa!),
      sinSalida: _poniendoIniciales
          ? inicialesSinSalida(viendo.mapa!, _iniciales).toSet()
          : const {},
      anclas: jugadas.anclas,
      ancla: _ancla,
      destinos: jugadas.destinos,
      onTap: _puedoJugar ? (c) => _tocar(context, c, viendo, tablero) : null,
    );
    final panel = _panel(context, viendo, jugadas.anclas);
    final marcador = Marcador(
      partida: _partida,
      yoId: yo?.id,
      viendo: viendo.id,
      onElegir: (id) => setState(() {
        _viendo = id == yo?.id ? null : id;
        _ancla = null;
      }),
    );

    final nivel = viendo.mapa!;
    return Focus(
      autofocus: true,
      onKeyEvent: (_, e) => _alPulsarTecla(e, nivel),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 900) {
            return Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(child: vistaTablero),
                  ),
                ),
                SizedBox(
                  width: 360,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                    child: Column(
                      children: [panel, const SizedBox(height: 12), marcador],
                    ),
                  ),
                ),
              ],
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    panel,
                    const SizedBox(height: 12),
                    vistaTablero,
                    const SizedBox(height: 12),
                    marcador,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  ({Set<Coordenada> anclas, Set<Coordenada> destinos}) _jugadasPosibles(
    Tablero tablero,
    Map<Coordenada, int> celdas,
  ) {
    final dados = _partida.dados;
    if (!_puedoJugar || !_partida.jugando || dados == null) {
      return (anclas: const {}, destinos: const {});
    }
    final anclas = anclasPosibles(tablero, celdas, dados);
    final ancla = _ancla;
    final destinos = ancla == null || !anclas.contains(ancla)
        ? const <Coordenada>{}
        : destinosPosibles(
            tablero,
            celdas,
            ancla,
            otroDado(dados, celdas[ancla]!),
          );
    return (anclas: anclas, destinos: destinos);
  }

  void _tocar(
    BuildContext context,
    Coordenada c,
    JugadorPartidaInfo yo,
    Tablero tablero,
  ) {
    if (_partida.enIniciales) {
      // Tocar una casilla inicial la elige; el número se pone con el teclado.
      if (yo.mapa!.casillasIniciales.contains(c))
        setState(() => _casillaElegida = c);
      return;
    }
    final jugadas = _jugadasPosibles(tablero, yo.celdas);
    if (jugadas.destinos.contains(c)) {
      context.read<LobbyBloc>().add(LobbyJugada(_ancla!, c));
      setState(() => _ancla = null);
    } else if (jugadas.anclas.contains(c)) {
      setState(() => _ancla = _ancla == c ? null : c);
    }
  }

  // ---------------------------------------------------------------------------
  // Números iniciales: se elige una casilla (o la primera vacía) y se toca un
  // número del teclado; la selección pasa sola a la siguiente casilla vacía.
  // ---------------------------------------------------------------------------

  bool get _poniendoIniciales => _puedoJugar && _partida.enIniciales;

  /// Casillas iniciales en orden de lectura (de arriba abajo, de izquierda a derecha).
  List<Coordenada> _orden(Nivel n) => n.casillasIniciales.toList()
    ..sort(
      (a, b) => a.fila != b.fila ? a.fila - b.fila : a.columna - b.columna,
    );

  /// Casilla a la que va el próximo número.
  Coordenada? _casillaActiva(Nivel n) {
    if (!_poniendoIniciales) return null;
    final elegida = _casillaElegida;
    if (elegida != null) return elegida;
    for (final c in _orden(n)) {
      if (!_iniciales.containsKey(c)) return c;
    }
    return null;
  }

  Coordenada? _siguienteVacia(Nivel n, Coordenada desde) {
    final orden = _orden(n);
    final i = orden.indexOf(desde);
    for (var k = 1; k <= orden.length; k++) {
      final c = orden[(i + k) % orden.length];
      if (!_iniciales.containsKey(c)) return c;
    }
    return null;
  }

  /// Números que se pueden poner en [c]: sin repetir y que su zona los acepte.
  Set<int> _permitidos(Nivel nivel, Coordenada c) {
    final tablero = nivel.construirTablero();
    final zona = tablero.zonaEn(c)!;
    final usados = {
      for (final e in _iniciales.entries)
        if (e.key != c) e.value,
    };
    final enLaZona = [
      for (final e in _iniciales.entries)
        if (e.key != c && tablero.zonaEn(e.key)?.id == zona.id) e.value,
    ];
    return {
      for (var n = 1; n <= 6; n++)
        if (!usados.contains(n) && zona.tipo.esPosibleAgregar(enLaZona, n)) n,
    };
  }

  void _poner(Nivel nivel, int numero) {
    final c = _casillaActiva(nivel);
    if (c == null || !_permitidos(nivel, c).contains(numero)) return;
    setState(() {
      _iniciales[c] = numero;
      _casillaElegida = _siguienteVacia(nivel, c);
    });
  }

  void _borrar(Nivel nivel) {
    final c = _casillaActiva(nivel);
    if (c == null || !_iniciales.containsKey(c)) return;
    setState(() {
      _iniciales.remove(c);
      _casillaElegida = c;
    });
  }

  /// Rellena las casillas con números válidos al azar.
  void _alAzar(Nivel nivel) {
    final casillas = _orden(nivel);
    final random = Random();
    for (var intento = 0; intento < 2000; intento++) {
      final numeros = [1, 2, 3, 4, 5, 6]..shuffle(random);
      final valores = {
        for (var i = 0; i < casillas.length; i++) casillas[i]: numeros[i % 6],
      };
      if (errorEnValoresIniciales(nivel, valores) == null) {
        setState(() {
          _iniciales
            ..clear()
            ..addAll(valores);
          _casillaElegida = null;
        });
        return;
      }
    }
  }

  /// Avisos mientras se ponen los iniciales:
  /// - Si en la casilla elegida no cabe ningún número, explica por qué y
  ///   ofrece "Mover el N aquí" (lo quita de su casilla y lo pone en esta).
  /// - Si otra casilla vacía se quedó sin números posibles, avisa ya.
  List<Widget> _avisosIniciales(Nivel nivel) {
    final activa = _casillaActiva(nivel);
    final bloqueo = activa == null
        ? null
        : bloqueoInicial(nivel, _iniciales, activa);
    final sinSalida = inicialesSinSalida(nivel, _iniciales)..remove(activa);
    return [
      if (bloqueo != null) ...[
        AvisoSinSalida(
          bloqueo: bloqueo,
          onMover: (n) => setState(() {
            final origen = bloqueo.usadoEn[n]!;
            _iniciales
              ..remove(origen)
              ..[activa!] = n;
            _casillaElegida = origen; // la casilla que quedó vacía
          }),
        ),
        const SizedBox(height: 10),
      ],
      if (sinSalida.isNotEmpty) ...[
        AvisoAnticipado(
          texto: avisoCasillasSinSalida(nivel.construirTablero(), sinSalida),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  /// Teclado físico: 1-6 ponen el número; Retroceso o Supr lo borran.
  KeyEventResult _alPulsarTecla(KeyEvent e, Nivel nivel) {
    if (!_poniendoIniciales || e is! KeyDownEvent)
      return KeyEventResult.ignored;
    final n = int.tryParse(e.character ?? '');
    if (n != null && n >= 1 && n <= 6) {
      _poner(nivel, n);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace ||
        e.logicalKey == LogicalKeyboardKey.delete) {
      _borrar(nivel);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _panel(
    BuildContext context,
    JugadorPartidaInfo viendo,
    Set<Coordenada> anclas,
  ) {
    final bloc = context.read<LobbyBloc>();
    final yo = _yo;
    final p = _partida;
    final dados = p.dados;
    final esMio = viendo.id == yo?.id;

    final String mensaje;
    if (!esMio) {
      mensaje = 'Estás viendo el tablero de ${viendo.nametag}.';
    } else if (p.terminada) {
      mensaje = 'La partida terminó.';
    } else if (!(yo?.activo ?? false)) {
      mensaje = yo?.estado == 'concedio'
          ? 'Te rendiste. Sigues viendo la partida.'
          : 'Ya no participas en esta partida.';
    } else if (p.enIniciales) {
      final faltan = viendo.mapa!.casillasIniciales.length - _iniciales.length;
      mensaje = yo!.yaJugo
          ? 'Listo. Esperando a que los demás pongan sus números…'
          : faltan > 0
          ? 'Toca un número para la casilla marcada (del 1 al 6, sin repetir). Faltan $faltan.'
          : 'Revisa tus números y pulsa Confirmar.';
    } else if (yo!.completo) {
      mensaje =
          '¡Completaste tu tablero! La partida termina al acabar esta ronda.';
    } else if (yo.yaJugo) {
      mensaje = 'Esperando a los demás (faltan ${p.faltan})…';
    } else if (anclas.isEmpty) {
      mensaje =
          'No hay jugadas posibles con ${dados![0]} y ${dados[1]}. Pasa la ronda.';
    } else if (_ancla == null) {
      mensaje =
          'Toca un ${dados![0]} o un ${dados[1]} de tu tablero como ancla.';
    } else {
      mensaje =
          'Coloca el ${otroDado(dados!, viendo.celdas[_ancla]!)} en una casilla marcada.';
    }

    final inicialesListos =
        esMio &&
        p.enIniciales &&
        _puedoJugar &&
        errorEnValoresIniciales(viendo.mapa!, _iniciales) == null;

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.enIniciales
                        ? 'Números iniciales'
                        : 'Ronda ${p.ronda} de ${p.maxRondas}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: colorTextoTablero,
                    ),
                  ),
                ),
                if (!p.terminada && p.limite != null)
                  CuentaRegresiva(limite: p.limite!),
              ],
            ),
            Text(
              'Gana quien llegue a ${p.puntosMeta} puntos',
              key: const Key('meta-puntos'),
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (p.jugando && dados != null) ...[
              const SizedBox(height: 10),
              DadosRonda(
                dados: dados,
                ronda: p.ronda,
                valorAncla: esMio && _ancla != null
                    ? viendo.celdas[_ancla]
                    : null,
                apagados: esMio && _puedoJugar && anclas.isEmpty,
              ),
            ],
            const SizedBox(height: 10),
            Text(
              mensaje,
              key: const Key('mensaje-partida'),
              textAlign: TextAlign.center,
            ),
            if (widget.state.esperando)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            if (!esMio)
              OutlinedButton.icon(
                onPressed: () => setState(() => _viendo = null),
                icon: const Icon(Icons.person),
                label: const Text('Volver a mi tablero'),
              )
            else ...[
              if (_poniendoIniciales) ...[
                ..._avisosIniciales(viendo.mapa!),
                TecladoIniciales(
                  permitidos: switch (_casillaActiva(viendo.mapa!)) {
                    final c? => _permitidos(viendo.mapa!, c),
                    null => const {},
                  },
                  hayElegida: _iniciales.containsKey(
                    _casillaActiva(viendo.mapa!),
                  ),
                  onNumero: (n) => _poner(viendo.mapa!, n),
                  onBorrar: () => _borrar(viendo.mapa!),
                  onAlAzar: () => _alAzar(viendo.mapa!),
                ),
                const SizedBox(height: 10),
              ],
              if (p.enIniciales && !(yo?.yaJugo ?? true))
                FilledButton.icon(
                  key: const Key('confirmar-iniciales'),
                  onPressed: inicialesListos
                      ? () => bloc.add(LobbyIniciales(Map.of(_iniciales)))
                      : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Confirmar números'),
                ),
              if (p.jugando && _puedoJugar)
                FilledButton.icon(
                  key: const Key('pasar'),
                  onPressed: () =>
                      _pasar(context, hayJugadas: anclas.isNotEmpty),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                  ),
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Pasar ronda'),
                ),
              if ((yo?.activo ?? false) && !p.terminada) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  key: const Key('rendirse'),
                  onPressed: widget.state.conectado
                      ? () => _rendirse(context)
                      : null,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                  ),
                  icon: const Icon(Icons.flag),
                  label: const Text('Rendirse'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pasar(BuildContext context, {required bool hayJugadas}) async {
    final bloc = context.read<LobbyBloc>();
    if (hayJugadas) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Pasar la ronda?'),
          content: const Text('Todavía puedes colocar un número.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sí, pasar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    bloc.add(LobbyPasar());
    if (mounted) setState(() => _ancla = null);
  }

  Future<void> _rendirse(BuildContext context) async {
    final bloc = context.read<LobbyBloc>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.flag, color: Colors.red.shade700, size: 40),
        title: const Text('¿Rendirse?'),
        content: const Text(
          'Quedarás al final de la clasificación. Podrás seguir viendo la partida.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Sí, rendirme'),
          ),
        ],
      ),
    );
    if (ok == true) bloc.add(LobbyConceder());
  }
}

/// Tablero de un jugador con los indicadores de zona a los lados.
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
  final void Function(Coordenada c)? onTap;

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
    this.onTap,
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

  bool get _hayQueLatir =>
      widget.destinos.isNotEmpty || widget.seleccionada != null;

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
    if (_hayQueLatir && !_pulso.isAnimating) {
      _pulso.repeat(reverse: true);
    } else if (!_hayQueLatir && _pulso.isAnimating) {
      _pulso
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tablero;
    Widget columna(List<String> ids) => SizedBox(
      width: _anchoIndicadores,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final id in ids)
            if (t.zonas[id] != null) IndicadorZona(zona: t.zonas[id]!),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        final alto = c.maxHeight.isFinite ? c.maxHeight : double.infinity;
        final lado = min(min(c.maxWidth - 2 * _anchoIndicadores, alto), 640.0);
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
            pulso: _pulso.value,
            claveValor: 'c${c.fila}-${c.columna}',
          ),
        ),
      ),
    );
  }
}

/// Una casilla del tablero multijugador.
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
    required this.pulso,
    required this.claveValor,
  });

  @override
  Widget build(BuildContext context) {
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
      (borde, grosor) = (colorTextoTablero, 2.5 + 2 * latido);
    } else if (esAncla) {
      (borde, grosor) = (Colors.white, 4);
    } else if (esAnclaPosible) {
      (borde, grosor) = (colorTextoTablero.withValues(alpha: 0.75), 2);
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
          if (seleccionada || esDestino)
            BoxShadow(
              color: (seleccionada ? Colors.orange : Colors.white).withValues(
                alpha: 0.35 + 0.35 * latido,
              ),
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
                    color: esDestino ? Colors.white : colorTextoTablero,
                    width: 1.5,
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
          if (seleccionada)
            const Positioned(
              top: 3,
              right: 3,
              child: Icon(Icons.edit, size: 12, color: colorTextoTablero),
            ),
          if (esAncla)
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

/// Los 2 dados de la ronda. Caen rodando cada vez que empieza una ronda.
/// Con un ancla elegida, su dado se marca y abajo dice qué número se coloca.
class DadosRonda extends StatelessWidget {
  final List<int> dados;
  final int ronda;
  final int? valorAncla;

  /// No hay jugada posible con estos dados.
  final bool apagados;

  const DadosRonda({
    super.key,
    required this.dados,
    required this.ronda,
    this.valorAncla,
    this.apagados = false,
  });

  @override
  Widget build(BuildContext context) {
    final anclaEn = valorAncla == null ? -1 : dados.indexOf(valorAncla!);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 2; i++) ...[
              if (i == 1) const SizedBox(width: 14),
              DadoAnimado(
                key: ValueKey('dado-$i'),
                valor: dados[i],
                tirada: ronda,
                retraso: Duration(milliseconds: i * 180), // no caen a la vez
                animarAlAparecer: true,
                builder: (cara, rodando) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: i == anclaEn && !rodando
                          ? Colors.orange.shade700
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: Opacity(
                    opacity: apagados && !rodando ? 0.4 : 1,
                    child: Dado(valor: cara),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (anclaEn >= 0) ...[
          const SizedBox(height: 4),
          Text(
            'Ancla: ${dados[anclaEn]} · colocas el ${dados[1 - anclaEn]}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }
}

/// Teclado para los números iniciales: 1 a 6 (los que no se pueden poner en
/// la casilla elegida salen apagados), Borrar y Al azar.
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
                  child: Text(
                    '$n',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              key: const Key('borrar-inicial'),
              onPressed: hayElegida ? onBorrar : null,
              icon: const Icon(Icons.backspace_outlined, size: 18),
              label: const Text('Borrar'),
            ),
            const SizedBox(width: 8),
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

/// Marcador: todos los jugadores ordenados por puntos, con lo que está
/// haciendo cada uno. Tocar a alguien muestra su tablero.
class Marcador extends StatelessWidget {
  final PartidaInfo partida;
  final String? yoId;
  final String viendo;
  final ValueChanged<String> onElegir;

  const Marcador({
    super.key,
    required this.partida,
    required this.yoId,
    required this.viendo,
    required this.onElegir,
  });

  @override
  Widget build(BuildContext context) {
    final orden = [...partida.jugadores]
      ..sort((a, b) {
        final grupo = (a.activo ? 0 : 1) - (b.activo ? 0 : 1);
        return grupo != 0 ? grupo : b.puntos - a.puntos;
      });

    return Card(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Marcador',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: colorTextoTablero,
              ),
            ),
          ),
          for (final j in orden)
            ListTile(
              key: Key('marcador-${j.nametag}'),
              dense: true,
              selected: j.id == viendo,
              onTap: () => onElegir(j.id),
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: j.activo && j.conectado
                    ? Colors.teal.shade100
                    : Colors.grey.shade300,
                child: Text(j.nametag.substring(0, 1).toUpperCase()),
              ),
              title: Text(
                j.id == yoId ? '${j.nametag} (tú)' : j.nametag,
                style: TextStyle(
                  fontWeight: j.id == yoId ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              subtitle: Text('Nivel ${j.nivel} · ${_estado(j)}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _icono(j),
                  const SizedBox(width: 8),
                  Text(
                    '${j.puntos}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: colorTextoTablero,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  String _estado(JugadorPartidaInfo j) {
    if (j.estado == 'concedio') return 'se rindió';
    if (j.estado == 'abandono') return 'abandonó';
    if (!j.conectado) return 'sin conexión';
    if (j.completo) return '¡tablero completo!';
    if (partida.terminada) return 'terminó';
    return j.yaJugo ? 'ya jugó' : 'pensando…';
  }

  Widget _icono(JugadorPartidaInfo j) {
    final (icono, color) = switch (j) {
      _ when j.estado == 'concedio' => (Icons.flag, Colors.red.shade400),
      _ when j.estado == 'abandono' => (Icons.logout, Colors.grey),
      _ when !j.conectado => (Icons.wifi_off, Colors.orange.shade800),
      _ when j.completo => (Icons.emoji_events, Colors.amber.shade700),
      _ when j.yaJugo => (Icons.check_circle, Colors.green.shade600),
      _ => (Icons.hourglass_top, Colors.blueGrey),
    };
    return Icon(icono, color: color, size: 20);
  }
}

/// Cuenta atrás hasta [limite] (mm:ss); en rojo los últimos 10 segundos.
class CuentaRegresiva extends StatefulWidget {
  final DateTime limite;
  const CuentaRegresiva({super.key, required this.limite});

  @override
  State<CuentaRegresiva> createState() => _CuentaRegresivaState();
}

class _CuentaRegresivaState extends State<CuentaRegresiva> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resta = widget.limite.difference(DateTime.now());
    final s = max(0, (resta.inMilliseconds / 1000).ceil());
    final urgente = s <= 10;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.timer,
          size: 18,
          color: urgente ? Colors.red.shade700 : Colors.blueGrey,
        ),
        const SizedBox(width: 4),
        Text(
          '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}',
          key: const Key('cuenta-regresiva'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: urgente ? Colors.red.shade700 : colorTextoTablero,
          ),
        ),
      ],
    );
  }
}
