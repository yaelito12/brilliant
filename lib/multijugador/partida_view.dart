import 'dart:async';
import 'dart:math';

import 'package:brilliant_reglas/brilliant_reglas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../tablero_ui.dart' show Dado, IndicadorZona, colorDeTipo, colorTextoTablero;
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
  State<PartidaMultijugadorView> createState() => _PartidaMultijugadorViewState();
}

class _PartidaMultijugadorViewState extends State<PartidaMultijugadorView> {
  Coordenada? _ancla;
  final Map<Coordenada, int> _iniciales = {};

  /// Jugador cuyo tablero se está viendo (null = el mío).
  String? _viendo;

  PartidaInfo get _partida => widget.state.partida!;
  JugadorPartidaInfo? get _yo => widget.state.yoEnPartida;

  @override
  void didUpdateWidget(PartidaMultijugadorView viejo) {
    super.didUpdateWidget(viejo);
    final antes = viejo.state.partida;
    // Ronda nueva (dados nuevos): el ancla de la ronda anterior ya no sirve.
    if (antes?.ronda != _partida.ronda || antes?.fase != _partida.fase) _ancla = null;
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
      pendientesIniciales: _puedoJugar && _partida.enIniciales
          ? viendo.mapa!.casillasIniciales.where((c) => !_iniciales.containsKey(c)).toSet()
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

    return LayoutBuilder(
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
                  child: Column(children: [panel, const SizedBox(height: 12), marcador]),
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
        : destinosPosibles(tablero, celdas, ancla, otroDado(dados, celdas[ancla]!));
    return (anclas: anclas, destinos: destinos);
  }

  void _tocar(BuildContext context, Coordenada c, JugadorPartidaInfo yo, Tablero tablero) {
    if (_partida.enIniciales) {
      if (yo.mapa!.casillasIniciales.contains(c)) _elegirInicial(context, c, yo);
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

  Future<void> _elegirInicial(BuildContext context, Coordenada c, JugadorPartidaInfo yo) async {
    final tablero = yo.mapa!.construirTablero();
    final zona = tablero.zonaEn(c)!;
    final usados = {
      for (final e in _iniciales.entries)
        if (e.key != c) e.value,
    };
    final enLaZona = [
      for (final e in _iniciales.entries)
        if (e.key != c && tablero.zonaEn(e.key)?.id == zona.id) e.value,
    ];
    bool permitido(int n) => !usados.contains(n) && zona.tipo.esPosibleAgregar(enLaZona, n);

    final elegido = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Número inicial'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var n = 1; n <= 6; n++)
              SizedBox(
                width: 52,
                height: 52,
                child: FilledButton(
                  key: Key('inicial-$n'),
                  onPressed: permitido(n) ? () => Navigator.pop(ctx, n) : null,
                  style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                  child: Text('$n', style: const TextStyle(fontSize: 20)),
                ),
              ),
          ],
        ),
        actions: [
          if (_iniciales.containsKey(c))
            TextButton(onPressed: () => Navigator.pop(ctx, 0), child: const Text('Borrar')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        ],
      ),
    );
    if (elegido == null || !mounted) return;
    setState(() => elegido == 0 ? _iniciales.remove(c) : _iniciales[c] = elegido);
  }

  Widget _panel(BuildContext context, JugadorPartidaInfo viendo, Set<Coordenada> anclas) {
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
              ? 'Pon un número del 1 al 6 (sin repetir) en cada casilla marcada. Faltan $faltan.'
              : 'Revisa tus números y pulsa Confirmar.';
    } else if (yo!.completo) {
      mensaje = '¡Completaste tu tablero! La partida termina al acabar esta ronda.';
    } else if (yo.yaJugo) {
      mensaje = 'Esperando a los demás (faltan ${p.faltan})…';
    } else if (anclas.isEmpty) {
      mensaje = 'No hay jugadas posibles con ${dados![0]} y ${dados[1]}. Pasa la ronda.';
    } else if (_ancla == null) {
      mensaje = 'Toca un ${dados![0]} o un ${dados[1]} de tu tablero como ancla.';
    } else {
      mensaje = 'Coloca el ${otroDado(dados!, viendo.celdas[_ancla]!)} en una casilla marcada.';
    }

    final inicialesListos = esMio &&
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
                    p.enIniciales ? 'Números iniciales' : 'Ronda ${p.ronda} de ${p.maxRondas}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: colorTextoTablero,
                    ),
                  ),
                ),
                if (!p.terminada && p.limite != null) CuentaRegresiva(limite: p.limite!),
              ],
            ),
            if (p.jugando && dados != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Dado(valor: dados[0]), const SizedBox(width: 12), Dado(valor: dados[1])],
              ),
            ],
            const SizedBox(height: 10),
            Text(mensaje, key: const Key('mensaje-partida'), textAlign: TextAlign.center),
            if (widget.state.esperando)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              ),
            const SizedBox(height: 10),
            if (!esMio)
              OutlinedButton.icon(
                onPressed: () => setState(() => _viendo = null),
                icon: const Icon(Icons.person),
                label: const Text('Volver a mi tablero'),
              )
            else ...[
              if (p.enIniciales && !(yo?.yaJugo ?? true))
                FilledButton.icon(
                  key: const Key('confirmar-iniciales'),
                  onPressed: inicialesListos ? () => bloc.add(LobbyIniciales(Map.of(_iniciales))) : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Confirmar números'),
                ),
              if (p.jugando && _puedoJugar)
                FilledButton.icon(
                  key: const Key('pasar'),
                  onPressed: () => _pasar(context, hayJugadas: anclas.isNotEmpty),
                  style: FilledButton.styleFrom(backgroundColor: Colors.teal.shade700),
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Pasar ronda'),
                ),
              if ((yo?.activo ?? false) && !p.terminada) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  key: const Key('rendirse'),
                  onPressed: widget.state.conectado ? () => _rendirse(context) : null,
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
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
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, pasar')),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
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
class TableroMultijugador extends StatelessWidget {
  final Nivel nivel;
  final Tablero tablero;
  final Map<Coordenada, int> celdas;
  final Set<Coordenada> iniciales;

  /// Casillas iniciales que faltan por llenar (con lápiz).
  final Set<Coordenada> pendientesIniciales;
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
    this.anclas = const {},
    this.ancla,
    this.destinos = const {},
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget columna(List<String> ids) => SizedBox(
      width: _anchoIndicadores,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final id in ids)
            if (tablero.zonas[id] != null) IndicadorZona(zona: tablero.zonas[id]!),
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
              columna(nivel.indicadoresIzquierda),
              Container(
                width: lado,
                height: lado,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
                ),
                child: GridView.builder(
                  key: const Key('tablero-mp'),
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: tablero.columnas,
                    crossAxisSpacing: 3,
                    mainAxisSpacing: 3,
                  ),
                  itemCount: tablero.filas * tablero.columnas,
                  itemBuilder: (_, i) => _celda(Coordenada(i ~/ tablero.columnas, i % tablero.columnas)),
                ),
              ),
              columna(nivel.indicadoresDerecha),
            ],
          ),
        );
      },
    );
  }

  Widget _celda(Coordenada c) {
    final zona = tablero.zonaEn(c);
    if (zona == null) return const SizedBox.shrink();
    final valor = celdas[c];
    final esInicial = iniciales.contains(c);
    final color = colorDeTipo(zona.tipo);

    final Color? borde;
    final double grosor;
    if (destinos.contains(c)) {
      (borde, grosor) = (colorTextoTablero, 4);
    } else if (ancla == c) {
      (borde, grosor) = (Colors.white, 4);
    } else if (anclas.contains(c) || pendientesIniciales.contains(c)) {
      (borde, grosor) = (colorTextoTablero, 2);
    } else {
      (borde, grosor) = (null, 0);
    }

    return GestureDetector(
      key: Key('celda-${c.fila}-${c.columna}'),
      onTap: onTap == null ? null : () => onTap!(c),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: borde == null ? null : Border.all(color: borde, width: grosor),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1))],
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                valor == null ? '' : '$valor',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: esInicial ? FontWeight.w900 : FontWeight.w700,
                  fontStyle: esInicial ? FontStyle.italic : FontStyle.normal,
                  color: colorTextoTablero,
                ),
              ),
            ),
            if (pendientesIniciales.contains(c))
              const Positioned(top: 4, right: 4, child: Icon(Icons.edit, size: 12, color: colorTextoTablero)),
            if (ancla == c)
              const Positioned(top: 4, right: 4, child: Icon(Icons.anchor, size: 12, color: colorTextoTablero)),
          ],
        ),
      ),
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
            child: Text('Marcador', style: TextStyle(fontWeight: FontWeight.w900, color: colorTextoTablero)),
          ),
          for (final j in orden)
            ListTile(
              key: Key('marcador-${j.nametag}'),
              dense: true,
              selected: j.id == viendo,
              onTap: () => onElegir(j.id),
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: j.activo && j.conectado ? Colors.teal.shade100 : Colors.grey.shade300,
                child: Text(j.nametag.substring(0, 1).toUpperCase()),
              ),
              title: Text(
                j.id == yoId ? '${j.nametag} (tú)' : j.nametag,
                style: TextStyle(fontWeight: j.id == yoId ? FontWeight.bold : FontWeight.w500),
              ),
              subtitle: Text('Nivel ${j.nivel} · ${_estado(j)}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _icono(j),
                  const SizedBox(width: 8),
                  Text(
                    '${j.puntos}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colorTextoTablero),
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
        Icon(Icons.timer, size: 18, color: urgente ? Colors.red.shade700 : Colors.blueGrey),
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
