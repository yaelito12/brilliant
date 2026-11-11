import 'package:flutter/material.dart';

import 'multijugador/lobby_bloc.dart' show Aviso, TipoAviso;

export 'multijugador/lobby_bloc.dart' show TipoAviso;

/// Muestra el [aviso] del lobby como notificación flotante.
void mostrarAviso(BuildContext context, Aviso aviso) =>
    mostrarNotificacion(context, aviso.texto, tipo: aviso.tipo);

/// Notificación flotante del juego (online y offline comparten este estilo):
/// tarjeta redondeada con ícono y color según el [tipo] de aviso.
void mostrarNotificacion(
  BuildContext context,
  String texto, {
  TipoAviso tipo = TipoAviso.info,
  IconData? icono,
  SnackBarAction? accion,
}) {
  final (color, iconoBase) = switch (tipo) {
    TipoAviso.info => (Colors.teal.shade700, Icons.info_outline),
    TipoAviso.exito => (Colors.green.shade700, Icons.star_rounded),
    TipoAviso.alerta => (Colors.orange.shade800, Icons.warning_amber_rounded),
    TipoAviso.error => (Colors.red.shade700, Icons.error_outline),
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(milliseconds: 3500),
        action: accion,
        // Con botón, el aviso se queda hasta que se pulse.
        persist: accion != null,
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icono ?? iconoBase, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
