import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';

import 'multijugador/lobby_bloc.dart' show Aviso, TipoAviso;

export 'multijugador/lobby_bloc.dart' show TipoAviso;

/// Botón opcional dentro de una notificación ("Reintentar", "Ver"…).
class AccionAviso {
  final String texto;
  final VoidCallback onPulsar;
  const AccionAviso(this.texto, this.onPulsar);
}

/// Muestra el [aviso] del lobby como notificación flotante.
void mostrarAviso(BuildContext context, Aviso aviso) =>
    mostrarNotificacion(context, aviso.texto, tipo: aviso.tipo);

/// Notificación flotante del juego: tarjeta blanca con una franja de color,
/// ícono y texto, justo debajo de la barra del título.
///
/// No usa `SnackBar`: va en el [Overlay] de la app, así sale igual en el
/// teléfono y en la computadora (y aunque el aviso se lance desde arriba de
/// la pantalla de juego, donde no hay ningún `Scaffold` todavía).
void mostrarNotificacion(
  BuildContext context,
  String texto, {
  TipoAviso tipo = TipoAviso.info,
  IconData? icono,
  AccionAviso? accion,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _PilaAvisos.de(overlay).agregar(
    _Nota(texto: texto, tipo: tipo, icono: icono, accion: accion),
  );
}

/// Cierra las notificaciones que estén a la vista (al salir de una pantalla).
void cerrarNotificaciones(BuildContext context) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay != null) _PilaAvisos.cerrar(overlay);
}

/// Color y ícono de cada clase de aviso.
(Color, IconData) estiloDeAviso(TipoAviso tipo) => switch (tipo) {
  TipoAviso.info => (const Color(0xFF00897B), Icons.info_outline),
  TipoAviso.exito => (const Color(0xFF2E9E5B), Icons.star_rounded),
  TipoAviso.alerta => (const Color(0xFFE06C00), Icons.warning_amber_rounded),
  TipoAviso.error => (const Color(0xFFD32F2F), Icons.error_outline),
};

// ---------------------------------------------------------------------------
// Pila de notificaciones (como máximo 3 a la vez, la más nueva abajo)
// ---------------------------------------------------------------------------

const _maxNotas = 3;
const _anchoNota = 420.0;

class _Nota {
  static int _siguienteId = 0;

  final int id = ++_siguienteId;
  final String texto;
  final TipoAviso tipo;
  final IconData? icono;
  final AccionAviso? accion;

  _Nota({
    required this.texto,
    required this.tipo,
    this.icono,
    this.accion,
  });
}

/// Una pila por [Overlay] (la app tiene uno; en las pruebas, uno por prueba).
final _pilas = HashMap<OverlayState, _PilaAvisos>();

class _PilaAvisos {
  final OverlayState overlay;
  final notas = ValueNotifier<List<_Nota>>(const []);
  OverlayEntry? _capa;

  _PilaAvisos._(this.overlay);

  static _PilaAvisos de(OverlayState overlay) {
    final pila = _pilas[overlay];
    if (pila != null && overlay.mounted) return pila;
    _pilas.remove(overlay);
    return _pilas[overlay] = _PilaAvisos._(overlay);
  }

  static void cerrar(OverlayState overlay) => _pilas[overlay]?._vaciar();

  void agregar(_Nota nota) {
    if (!overlay.mounted) {
      _pilas.remove(overlay);
      return;
    }
    // El mismo aviso repetido no se apila dos veces.
    final previas = notas.value
        .where((n) => n.texto != nota.texto)
        .toList();
    notas.value = [
      ...previas.skip(max(0, previas.length - (_maxNotas - 1))),
      nota,
    ];
    if (_capa == null) {
      _capa = OverlayEntry(builder: (_) => _CapaAvisos(pila: this));
      overlay.insert(_capa!);
    }
  }

  void quitar(int id) {
    notas.value = [
      for (final n in notas.value)
        if (n.id != id) n,
    ];
    if (notas.value.isEmpty) _vaciar();
  }

  void _vaciar() {
    notas.value = const [];
    if (_capa != null && overlay.mounted) _capa!.remove();
    _capa = null;
    _pilas.remove(overlay);
  }
}

/// Las notificaciones van arriba (debajo de la barra del título), centradas
/// y sin estorbar los toques de lo que haya detrás.
class _CapaAvisos extends StatelessWidget {
  final _PilaAvisos pila;

  const _CapaAvisos({required this.pila});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, kToolbarHeight + 8, 12, 12),
          child: Align(
            alignment: Alignment.topCenter,
            child: ValueListenableBuilder<List<_Nota>>(
              valueListenable: pila.notas,
              builder: (context, notas, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final nota in notas)
                    _TarjetaAviso(
                      key: ValueKey(nota.id),
                      nota: nota,
                      alCerrar: () => pila.quitar(nota.id),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de una notificación: entra deslizándose desde arriba, se queda
/// unos segundos y se va sola (o al tocarla).
class _TarjetaAviso extends StatefulWidget {
  final _Nota nota;
  final VoidCallback alCerrar;

  const _TarjetaAviso({
    super.key,
    required this.nota,
    required this.alCerrar,
  });

  @override
  State<_TarjetaAviso> createState() => _TarjetaAvisoState();
}

class _TarjetaAvisoState extends State<_TarjetaAviso>
    with SingleTickerProviderStateMixin {
  /// El tiempo que se queda a la vista va en un temporizador (no en la
  /// animación) para que entre y salga suave sin tener la pantalla animada
  /// mientras se lee, como hacen las notificaciones del sistema.
  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 240),
  );

  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    // Los avisos importantes se quedan más tiempo; los de siempre, menos.
    final visible = switch (widget.nota.tipo) {
      TipoAviso.alerta || TipoAviso.error => const Duration(seconds: 7),
      _ => const Duration(milliseconds: 4500),
    };
    _control.forward();
    _reloj = Timer(visible, _cerrarYa);
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _control.dispose();
    super.dispose();
  }

  /// Se va con una salida suave (al acabarse su tiempo o al pulsar su botón).
  void _cerrarYa() {
    _reloj?.cancel();
    if (!mounted || _control.status == AnimationStatus.reverse) return;
    _control.reverse().whenComplete(() {
      if (mounted) widget.alCerrar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final (color, iconoBase) = estiloDeAviso(widget.nota.tipo);
    final accion = widget.nota.accion;


    return AnimatedBuilder(
      animation: _control,
      builder: (context, hijo) {
        final t = Curves.easeOutCubic.transform(_control.value);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -18 * (1 - t)),
            child: hijo,
          ),
        );
      },
      // Sin toque: el aviso no se queda nunca en medio de una jugada (un
      // recuadro encima del tablero se comería el toque de la casilla).
      child: IgnorePointer(
        ignoring: accion == null,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _anchoNota),
            child: Semantics(
              liveRegion: true,
              child: Material(
                color: Colors.white,
                elevation: 8,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Franja con el color del aviso
                      Container(width: 6, color: color),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.13),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  widget.nota.icono ?? iconoBase,
                                  color: color,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.nota.texto,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.25,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1B3B4D),
                                  ),
                                ),
                              ),
                              if (accion != null) ...[
                                const SizedBox(width: 4),
                                TextButton(
                                  onPressed: () {
                                    accion.onPulsar();
                                    _cerrarYa();
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: color,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                  ),
                                  child: Text(
                                    accion.texto,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
