import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Efecto de sonido del juego.
enum Sonido {
  /// Alguien llenó una zona.
  zona('sonidos/zona.wav'),

  /// Terminó la partida (alguien ganó).
  victoria('sonidos/victoria.wav'),

  /// Alguien abandonó (o se rindió).
  abandono('sonidos/abandono.wav');

  final String ruta;
  const Sonido(this.ruta);
}

/// Reproduce los efectos de sonido. Un reproductor por efecto, así un
/// sonido nuevo del mismo tipo corta al anterior pero no a los demás.
class Sonidos {
  static final _reproductores = <Sonido, AudioPlayer>{};
  static bool silenciado = false;

  /// Suena [s]. Nunca lanza: si el audio falla (por ejemplo, el navegador
  /// bloquea el sonido antes del primer toque), el juego sigue igual.
  static Future<void> tocar(Sonido s) async {
    if (silenciado) return;
    try {
      final p = _reproductores.putIfAbsent(
        s,
        () => AudioPlayer()..setReleaseMode(ReleaseMode.stop),
      );
      await p.stop();
      await p.play(AssetSource(s.ruta));
    } catch (e) {
      debugPrint('No se pudo tocar el sonido ${s.name}: $e');
    }
  }
}
