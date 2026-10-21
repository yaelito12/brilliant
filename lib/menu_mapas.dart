import 'dart:math';

import 'package:flutter/material.dart';

import 'nivel.dart';
import 'niveles.dart';
import 'tablero.dart';
import 'tablero_ui.dart';

const _colorTexto = Color(0xFF1B3B4D);

/// Pantalla inicial: se elige uno de los mapas y se pulsa "Jugar".
/// Al salir de la partida se vuelve aquí.
class MenuMapasPage extends StatefulWidget {
  /// Mapas que se pueden elegir; por defecto, los oficiales.
  final List<Nivel>? niveles;

  /// Generador de los dados que se pasa a la partida (para los tests).
  final Random? random;

  const MenuMapasPage({super.key, this.niveles, this.random});

  @override
  State<MenuMapasPage> createState() => _MenuMapasPageState();
}

class _MenuMapasPageState extends State<MenuMapasPage> {
  Nivel? _elegido;

  List<Nivel> get _niveles => widget.niveles ?? nivelesOficiales;

  void _jugar() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TableroPage(nivel: _elegido, random: widget.random),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final elegido = _elegido;

    return Scaffold(
      backgroundColor: const Color(0xFFE8F2ED),
      appBar: AppBar(
        title: const Text(
          'Brilliant',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Elige un mapa',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: _colorTexto,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toca un mapa y pulsa Jugar.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final nivel in _niveles)
                      TarjetaMapa(
                        nivel: nivel,
                        elegido: nivel == elegido,
                        onTap: () => setState(() => _elegido = nivel),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 280,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: elegido == null ? null : _jugar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      elegido == null ? 'Jugar' : 'Jugar ${elegido.nombre}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Un mapa del menú: su nombre y el tablero en miniatura.
/// El mapa elegido lleva un borde verde azulado y una palomita.
class TarjetaMapa extends StatelessWidget {
  final Nivel nivel;
  final bool elegido;
  final VoidCallback onTap;

  const TarjetaMapa({
    super.key,
    required this.nivel,
    required this.elegido,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: elegido ? Colors.teal.shade700 : Colors.grey.shade300,
              width: elegido ? 3 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MiniMapa(nivel: nivel, lado: 18),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (elegido) ...[
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: Colors.teal.shade700,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    nivel.nombre,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: elegido ? FontWeight.w900 : FontWeight.w600,
                      color: _colorTexto,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
