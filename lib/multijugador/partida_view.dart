import 'dart:async';
import 'dart:math';

import 'package:brilliant_reglas/brilliant_reglas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../aviso_sin_salida.dart';
import '../tablero_ui.dart';
import 'lobby_bloc.dart';
import 'modelos.dart';

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

  /// Dado tocado como ancla (sin casilla elegida aún): se contornean suave
  /// las casillas donde podría terminar el otro número.
  int? _valorElegido;
  final Map<Coordenada, int> _iniciales = {};

  /// Casilla inicial que el jugador tocó (null = ninguna).
  Coordenada? _casillaElegida;

  PartidaInfo get _partida => widget.state.partida!;
  JugadorPartidaInfo? get _yo => widget.state.yoEnPartida;

  @override
  void didUpdateWidget(PartidaMultijugadorView viejo) {
    super.didUpdateWidget(viejo);
    final antes = viejo.state.partida;
    // Ronda nueva (dados nuevos): el ancla de la ronda anterior ya no sirve.
    if (antes?.ronda != _partida.ronda || antes?.fase != _partida.fase) {
      _ancla = null;
      _valorElegido = null;
    }
  }

  /// Puedo tocar mi tablero ahora mismo.
  bool get _puedoJugar {
    final yo = _yo;
    return yo != null &&
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
    // Solo se ve el tablero propio: el de los demás no se muestra.
    final viendo = yo;
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
      destinosTentativos: jugadas.tentativos,
      lugares: viendo.lugares,
      lugaresOcupados: _partida.lugaresOcupados,
      onTap: _puedoJugar ? (c) => _tocar(context, c, viendo, tablero) : null,
    );
    final panel = _panel(context, viendo, jugadas.anclas);
    final marcador = Marcador(
      partida: _partida,
      yoId: viendo.id,
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

  ({
    Set<Coordenada> anclas,
    Set<Coordenada> destinos,
    Set<Coordenada> tentativos,
  })
  _jugadasPosibles(Tablero tablero, Map<Coordenada, int> celdas) {
    final dados = _partida.dados;
    if (!_puedoJugar || !_partida.jugando || dados == null) {
      return (anclas: const {}, destinos: const {}, tentativos: const {});
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
    // Dado tocado pero sin casilla ancla: dónde podría terminar el otro
    // número si el ancla fuera cualquier casilla con ese valor.
    final valor = _valorElegido;
    final tentativos = ancla != null || valor == null || !dados.contains(valor)
        ? const <Coordenada>{}
        : {
            for (final a in anclas)
              if (celdas[a] == valor)
                ...destinosPosibles(tablero, celdas, a, otroDado(dados, valor)),
          };
    return (anclas: anclas, destinos: destinos, tentativos: tentativos);
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
      setState(() {
        _ancla = null;
        _valorElegido = null;
      });
    } else if (jugadas.anclas.contains(c)) {
      setState(() {
        if (_ancla == c) {
          // Al deseleccionar vuelven los contornos suaves de ese valor
          _ancla = null;
          _valorElegido = yo.celdas[c];
        } else {
          _ancla = c;
        }
      });
    }
  }

  /// Tocar un dado lo elige (o lo suelta) como ancla tentativa: el tablero
  /// contornea suave dónde podría terminar el otro número.
  void _elegirDado(int valor) {
    setState(() {
      if (_valorElegido == valor && _ancla == null) {
        _valorElegido = null;
      } else {
        _valorElegido = valor;
        _ancla = null;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Números iniciales: se toca una casilla y luego un número del teclado.
  // Nada se selecciona solo: tras poner el número la casilla queda libre.
  // ---------------------------------------------------------------------------

  bool get _poniendoIniciales => _puedoJugar && _partida.enIniciales;

  /// Casillas iniciales en orden de lectura (de arriba abajo, de izquierda a derecha).
  List<Coordenada> _orden(Nivel n) => n.casillasIniciales.toList()
    ..sort(
      (a, b) => a.fila != b.fila ? a.fila - b.fila : a.columna - b.columna,
    );

  /// Casilla a la que va el próximo número: solo la que el jugador tocó.
  Coordenada? _casillaActiva(Nivel n) =>
      _poniendoIniciales ? _casillaElegida : null;

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
      _casillaElegida = null;
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
            _casillaElegida = null;
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
    if (p.terminada) {
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
          ? _casillaElegida == null
                ? 'Toca una casilla inicial y luego un número (del 1 al 6, sin repetir). Faltan $faltan.'
                : 'Toca un número para la casilla marcada (del 1 al 6, sin repetir). Faltan $faltan.'
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
      final v = _valorElegido;
      mensaje = v != null && dados!.contains(v)
          ? 'Toca un $v de tu tablero como ancla para poner el ${otroDado(dados, v)}.'
          : 'Toca un ${dados![0]} o un ${dados[1]} de tu tablero como ancla.';
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
                valorAncla: !esMio
                    ? null
                    : _ancla != null
                    ? viendo.celdas[_ancla]
                    : _valorElegido,
                apagados: esMio && _puedoJugar && anclas.isEmpty,
                onElegir: esMio && _puedoJugar && !(yo?.yaJugo ?? true)
                    ? _elegirDado
                    : null,
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
            ...[
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

/// Los 2 dados de la ronda. Caen rodando cada vez que empieza una ronda.
/// Con un ancla elegida, su dado se marca y abajo dice qué número se coloca.
/// Si [onElegir] no es null, se pueden tocar para elegir el dado ancla.
class DadosRonda extends StatelessWidget {
  final List<int> dados;
  final int ronda;
  final int? valorAncla;

  /// No hay jugada posible con estos dados.
  final bool apagados;

  /// Se llama al tocar un dado (con su valor). Null = no se pueden tocar.
  final void Function(int valor)? onElegir;

  const DadosRonda({
    super.key,
    required this.dados,
    required this.ronda,
    this.valorAncla,
    this.apagados = false,
    this.onElegir,
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
              // Siempre la misma estructura (aunque no se pueda tocar): si
              // cambiara, Flutter recrearía el dado y perdería la caída.
              MouseRegion(
                cursor: onElegir != null
                    ? SystemMouseCursors.click
                    : MouseCursor.defer,
                child: GestureDetector(
                  onTap: onElegir == null ? null : () => onElegir!(dados[i]),
                  child: DadoAnimado(
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

/// Marcador: todos los jugadores ordenados por puntos, con lo que está
/// haciendo cada uno. El tablero de los demás no se puede ver.
class Marcador extends StatelessWidget {
  final PartidaInfo partida;
  final String? yoId;

  const Marcador({super.key, required this.partida, required this.yoId});

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
              subtitle: Text(_estado(j)),
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
