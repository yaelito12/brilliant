import 'package:brilliant_reglas/brilliant_reglas.dart';
import 'package:flutter/material.dart';

import 'tablero_ui.dart' show nombreDeTipo;

/// "fila 7, columna 2" (contando desde 1, como se ve en pantalla).
String nombreCasilla(Coordenada c) =>
    'fila ${c.fila + 1}, columna ${c.columna + 1}';

/// "el 1", "el 1 y el 2", "el 1, el 2 y el 3".
String _lista(Iterable<int> numeros) {
  final t = [for (final n in numeros) 'el $n'];
  if (t.length <= 1) return t.join();
  return '${t.sublist(0, t.length - 1).join(', ')} y ${t.last}';
}

/// Explica por qué en una casilla inicial no cabe ningún número.
String explicarBloqueo(BloqueoInicial b) {
  final zona = 'la zona ${nombreDeTipo(b.zona.tipo).toLowerCase()}';
  if (b.usadoEn.isEmpty) {
    return 'Aquí no cabe ningún número por los que ya pusiste en $zona. '
        'Cambia los números de esa zona.';
  }
  final usados = b.usadoEn.keys.toList()..sort();
  final regla = b.zona.tipo.descripcion.toLowerCase();
  final verbo = usados.length == 1 ? 'ya está' : 'ya están';
  return 'Aquí no cabe ningún número: en $zona van $regla, '
      'y ${_lista(usados)} $verbo en otras casillas. '
      'Mueve uno de ellos aquí (su casilla quedará vacía para otro número).';
}

/// Aviso anticipado: alguna casilla vacía ya no tiene ningún número posible.
String avisoCasillasSinSalida(Tablero tablero, List<Coordenada> sinSalida) {
  final c = sinSalida.first;
  final zona = tablero.zonaEn(c);
  final nombre = zona == null
      ? ''
      : ' de la zona ${nombreDeTipo(zona.tipo).toLowerCase()}';
  return 'Ojo: en la casilla$nombre (${nombreCasilla(c)}) ya no cabe ningún número. '
      'Tócala para ver cómo arreglarlo.';
}

/// Recuadro naranja con la explicación y un botón por cada número que se
/// puede mover a esta casilla ("Mover el 1 aquí").
class AvisoSinSalida extends StatelessWidget {
  final BloqueoInicial bloqueo;
  final ValueChanged<int> onMover;

  const AvisoSinSalida({
    super.key,
    required this.bloqueo,
    required this.onMover,
  });

  @override
  Widget build(BuildContext context) {
    final numeros = bloqueo.usadoEn.keys.toList()..sort();
    return Container(
      key: const Key('aviso-sin-salida'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  explicarBloqueo(bloqueo),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (numeros.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in numeros)
                  Tooltip(
                    message:
                        'Se quita de la ${nombreCasilla(bloqueo.usadoEn[n]!)}',
                    child: FilledButton.icon(
                      key: Key('mover-$n'),
                      onPressed: () => onMover(n),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                      ),
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: Text('Mover el $n aquí'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Aviso corto (una línea con icono) para el panel.
class AvisoAnticipado extends StatelessWidget {
  final String texto;
  const AvisoAnticipado({super.key, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('aviso-anticipado'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: Colors.orange.shade800,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
