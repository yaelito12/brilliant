import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// En el navegador de un teléfono (Flutter web en Android/iOS), si se cierra
/// el teclado (botón "atrás", "Listo"…) y se vuelve a tocar el mismo campo,
/// Flutter cree que el campo sigue con el foco y no vuelve a pedir el
/// teclado: el campo queda sin poder editarse.
///
/// Se usa como `onTap` del campo: si ya tenía el foco, lo suelta y lo vuelve
/// a pedir en el siguiente cuadro, y el navegador abre el teclado otra vez.
/// En las demás plataformas no hace nada.
void reabrirTecladoAlTocar(FocusNode nodo) {
  if (!esNavegadorMovil || !nodo.hasFocus) return;
  nodo.unfocus();
  WidgetsBinding.instance
    ..addPostFrameCallback((_) {
      if (nodo.context != null) nodo.requestFocus();
    })
    ..scheduleFrame();
}

/// Se puede cambiar en las pruebas.
@visibleForTesting
bool? forzarNavegadorMovil;

bool get esNavegadorMovil =>
    forzarNavegadorMovil ??
    (kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS));
