import 'package:flutter/material.dart';

import '../tablero_ui.dart' show colorTextoTablero;
import 'modelos.dart';

/// Clasificación de la última partida. Se muestra en la sala al terminar,
/// hasta que se cierra o empieza la revancha.
class TarjetaResultados extends StatelessWidget {
  final ResultadosPartida resultados;
  final String? yoId;
  final VoidCallback onCerrar;

  const TarjetaResultados({
    super.key,
    required this.resultados,
    required this.yoId,
    required this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    final mio = yoId == null ? null : resultados.de(yoId!);
    final String titulo;
    if (mio == null) {
      titulo = 'Partida terminada';
    } else if (mio.estado == 'concedio') {
      titulo = 'Te rendiste';
    } else if (mio.posicion == 1) {
      final empate = resultados.lista.where((r) => r.posicion == 1).length > 1;
      titulo = empate ? '¡Empate en el primer lugar!' : '¡Ganaste!';
    } else {
      titulo = 'Quedaste en el lugar ${mio.posicion}';
    }

    final motivo = switch (resultados.motivo) {
      'meta_puntos' => 'Alguien llegó a la meta de puntos.',
      'tablero_completo' => 'Alguien completó su tablero.',
      'max_rondas' => 'Se acabaron las rondas.',
      'rendicion' => 'Los demás se rindieron.',
      'abandono' => 'Los demás abandonaron la partida.',
      _ => '',
    };

    return Card(
      key: const Key('resultados'),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  mio?.posicion == 1 && mio?.estado == 'jugando' ? Icons.emoji_events : Icons.sports_score,
                  color: Colors.amber.shade700,
                  size: 32,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: colorTextoTablero),
                      ),
                      if (motivo.isNotEmpty) Text(motivo, style: TextStyle(color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                IconButton(tooltip: 'Cerrar', onPressed: onCerrar, icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 4),
            for (final r in resultados.lista)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(right: 8),
                leading: _Medalla(posicion: r.posicion),
                title: Text(
                  r.id == yoId ? '${r.nametag} (tú)' : r.nametag,
                  style: TextStyle(fontWeight: r.id == yoId ? FontWeight.bold : FontWeight.w500),
                ),
                subtitle: Text(switch (r.estado) {
                  'concedio' => 'Nivel ${r.nivel} · se rindió',
                  'abandono' => 'Nivel ${r.nivel} · abandonó',
                  _ => 'Nivel ${r.nivel}',
                }),
                trailing: Text(
                  '${r.puntos} pts',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: colorTextoTablero),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Para la revancha, todos pulsan "¡Estoy listo!" otra vez.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _Medalla extends StatelessWidget {
  final int posicion;
  const _Medalla({required this.posicion});

  @override
  Widget build(BuildContext context) {
    final color = switch (posicion) {
      1 => Colors.amber.shade600,
      2 => Colors.blueGrey.shade300,
      3 => Colors.brown.shade300,
      _ => Colors.grey.shade200,
    };
    return CircleAvatar(
      radius: 16,
      backgroundColor: color,
      child: Text('$posicion', style: const TextStyle(fontWeight: FontWeight.bold, color: colorTextoTablero)),
    );
  }
}
