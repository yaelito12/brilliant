import 'dart:math';

import 'package:flutter/material.dart';

/// Colores de las zonas del juego (los mismos del tablero).
const _verde = Color(0xFF66BB6A);
const _azul = Color(0xFF42A5F5);
const _rojo = Color(0xFFEF5350);
const _amarillo = Color(0xFFFFCA28);
const _morado = Color(0xFFAB47BC);

/// Fondo de las pantallas: degradado azul claro, cuadritos translúcidos,
/// cintas de colores en las esquinas y bloques "de caramelo" con los colores
/// de las zonas. Va detrás de todo y no se puede tocar.
///
/// Los bloques entran con una animación corta al abrir la pantalla y luego
/// quedan quietos (una animación sin fin gastaría batería).
class FondoBrilliant extends StatefulWidget {
  final Widget child;
  const FondoBrilliant({super.key, required this.child});

  @override
  State<FondoBrilliant> createState() => _FondoBrilliantState();
}

class _FondoBrilliantState extends State<FondoBrilliant>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _entrada,
                builder: (context, _) => CustomPaint(
                  painter: PintorFondo(
                    entrada: Curves.easeOutBack.transform(_entrada.value),
                  ),
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// Un bloque decorativo. La posición es relativa al tamaño de la pantalla
/// (0..1) y el lado, relativo al lado menor; así se adapta a teléfono y PC.
class _Bloque {
  final double x, y, lado, giro;
  final Color color;

  /// De dónde entra (desplazamiento relativo) durante la animación.
  final double dx, dy;
  const _Bloque(
    this.x,
    this.y,
    this.lado,
    this.giro,
    this.color, {
    this.dx = 0,
    this.dy = 0,
  });
}

class PintorFondo extends CustomPainter {
  /// 0..1 (puede pasar un poco de 1 por el rebote): avance de la entrada.
  final double entrada;
  PintorFondo({this.entrada = 1});

  // Grandes en las esquinas (asomando) y pequeños flotando cerca de los bordes.
  static const _bloques = [
    _Bloque(0.04, 0.10, 0.20, -0.30, _verde, dx: -0.3, dy: -0.2),
    _Bloque(0.95, 0.09, 0.20, 0.32, _morado, dx: 0.3, dy: -0.2),
    _Bloque(0.03, 0.92, 0.22, 0.25, _rojo, dx: -0.3, dy: 0.2),
    _Bloque(0.97, 0.93, 0.22, -0.20, _amarillo, dx: 0.3, dy: 0.2),
    _Bloque(0.16, 0.62, 0.11, 0.35, _azul, dx: -0.4),
    _Bloque(0.86, 0.60, 0.10, -0.28, _amarillo, dx: 0.4),
    _Bloque(0.07, 0.43, 0.065, 0.20, _rojo, dx: -0.4),
    _Bloque(0.89, 0.36, 0.06, 0.15, _azul, dx: 0.4),
    _Bloque(0.15, 0.10, 0.045, -0.15, _verde, dy: -0.4),
    _Bloque(0.83, 0.10, 0.05, 0.30, _morado, dy: -0.4),
    _Bloque(0.10, 0.73, 0.04, 0.10, _verde, dx: -0.4),
    _Bloque(0.80, 0.80, 0.04, -0.25, _amarillo, dy: 0.4),
    _Bloque(0.17, 0.86, 0.035, 0.30, _rojo, dy: 0.4),
    _Bloque(0.93, 0.47, 0.045, 0.20, _morado, dx: 0.4),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Degradado azul claro.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE3EEFF), Color(0xFFF6F9FF), Color(0xFFE6EEFF)],
          stops: [0, 0.5, 1],
        ).createShader(rect),
    );

    final menor = min(size.width, size.height);

    // 2. Cintas curvas de colores en las esquinas.
    void cinta(
      Offset centro,
      double radio,
      double inicio,
      double barrido,
      Color color,
    ) {
      canvas.drawArc(
        Rect.fromCircle(center: centro, radius: radio),
        inicio,
        barrido,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = menor * 0.07
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.22),
      );
    }

    final w = size.width, h = size.height;
    cinta(Offset(-w * 0.05, h * 0.45), menor * 0.55, -1.3, 1.2, _verde);
    cinta(Offset(w * 1.05, h * 0.45), menor * 0.55, pi + 0.1, 1.2, _morado);
    cinta(Offset(-w * 0.02, h * 1.12), menor * 0.6, -1.4, 1.3, _rojo);
    cinta(Offset(w * 1.02, h * 1.12), menor * 0.6, pi + 0.1, 1.3, _amarillo);

    // 3. Cuadritos translúcidos (siempre los mismos: semilla fija).
    final r = Random(7);
    final cuadrito = Paint()..color = Colors.white.withValues(alpha: 0.55);
    final cuadritoAzul = Paint()
      ..color = const Color(0xFFCFE0FF).withValues(alpha: 0.45);
    for (var i = 0; i < 46; i++) {
      final lado = menor * (0.02 + r.nextDouble() * 0.04);
      final c = Offset(r.nextDouble() * w, r.nextDouble() * h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: lado, height: lado),
          Radius.circular(lado * 0.22),
        ),
        i.isEven ? cuadrito : cuadritoAzul,
      );
    }

    // 4. Bloques de caramelo (entran desde fuera de la pantalla).
    final t = entrada.clamp(0.0, 1.2);
    for (final b in _bloques) {
      final lado = menor * b.lado;
      final desde = Offset(b.dx * w, b.dy * h) * (1 - t);
      final centro = Offset(b.x * w, b.y * h) + desde;
      _bloque(
        canvas,
        centro,
        lado,
        b.giro * (0.6 + 0.4 * t),
        b.color,
        opacidad: t.clamp(0.0, 1.0),
      );
    }
  }

  /// Un bloque con volumen: sombra, base más oscura, cara con degradado y
  /// un brillo arriba, como una ficha de caramelo.
  void _bloque(
    Canvas canvas,
    Offset centro,
    double lado,
    double giro,
    Color color, {
    double opacidad = 1,
  }) {
    if (opacidad <= 0) return;
    canvas.save();
    canvas.translate(centro.dx, centro.dy);
    canvas.rotate(giro);

    final radio = Radius.circular(lado * 0.24);
    final cara = Rect.fromCenter(
      center: Offset.zero,
      width: lado,
      height: lado,
    );
    final hsl = HSLColor.fromColor(color);
    Color tono(double d) => hsl
        .withLightness((hsl.lightness + d).clamp(0.0, 1.0))
        .toColor()
        .withValues(alpha: opacidad);

    // Sombra suave.
    canvas.drawRRect(
      RRect.fromRectAndRadius(cara.shift(Offset(0, lado * 0.10)), radio),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.16 * opacidad)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, lado * 0.08),
    );
    // Base (da grosor).
    canvas.drawRRect(
      RRect.fromRectAndRadius(cara.shift(Offset(0, lado * 0.06)), radio),
      Paint()..color = tono(-0.14),
    );
    // Cara.
    canvas.drawRRect(
      RRect.fromRectAndRadius(cara, radio),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tono(0.12), tono(0), tono(-0.05)],
        ).createShader(cara),
    );
    // Cara interior (bisel).
    final interior = cara.deflate(lado * 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(interior, Radius.circular(lado * 0.16)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tono(0.08), tono(-0.02)],
        ).createShader(interior),
    );
    // Brillo.
    final brillo = Rect.fromLTWH(
      interior.left + lado * 0.04,
      interior.top + lado * 0.04,
      interior.width * 0.55,
      lado * 0.12,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(brillo, Radius.circular(lado * 0.06)),
      Paint()..color = Colors.white.withValues(alpha: 0.45 * opacidad),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(PintorFondo vieja) => vieja.entrada != entrada;
}
