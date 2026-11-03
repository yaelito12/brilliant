# Plan para las partidas online con ranking (siguiente entrega)

Esta entrega solo resuelve **quién es cada jugador**. Lo de abajo es el plan para
que varias personas jueguen entre sí y cada una tenga su ranking.

## Cómo encaja con el juego

El juego es un rompecabezas de puntuación: cada turno salen 2 dados, se elige un ancla, se coloca
el otro número y las zonas completas dan puntos. No hay "ataque" entre jugadores, así que el modo
online natural es una **carrera de puntuación**:

1. Se crea una sala (nivel + 2 a 4 jugadores).
2. Todos juegan **su propio tablero** con **la misma secuencia de dados**.
3. Cada jugador ve en vivo el progreso de los demás (turno y puntos).
4. Al completar el tablero termina su partida. Cuando terminan todos, gana la puntuación más alta
   (empate: menos turnos).
5. El resultado actualiza el ranking de cada jugador.

## Lo que ya está listo

| Pieza | Dónde |
|---|---|
| `autenticarToken(token)` → usuario o `null` | `server/src/app.js` |
| Servidor `http` explícito, listo para WebSocket | `server/src/index.js` |
| `AuthRepository.tokenDeAcceso()` en la app | `lib/auth/auth_repository.dart` |
| `PartidaBloc` ya recibe un `Random` | `lib/bloc/partida_bloc.dart` |

## Anti-trampas (lo más importante)

- **Los dados los genera el servidor.** Al crear la sala se generan todas las tiradas y se guardan.
  Cada jugador recibe la tirada del turno *k* solo después de enviar su jugada del turno *k-1*.
  No se manda ninguna semilla: si no, la app podría calcular dados futuros.
- **El servidor valida cada jugada** con las mismas reglas del juego (ancla válida, destino vecino
  y vacío, la zona acepta el número) y calcula la puntuación. La puntuación que diga el cliente se ignora.
- Cada mensaje del cliente: validado con Zod, tamaño máximo, límite de mensajes por segundo.

## Reglas del juego en el servidor

`lib/tipo.dart` importa `dart:ui`, así que no corre en un servidor Dart sin cambios. Dos caminos:

- **Portar a JavaScript** (recomendado): `Tipo` (7 tipos de zona), `Zona`, `Tablero` y la lógica de
  `PartidaBloc`, unas 800 líneas. Para asegurar que ambas copias den lo mismo: grabar partidas del
  juego en Dart (dados + jugadas + puntuación final) y repetirlas en una prueba del servidor.
- **Separar los colores** de `Tipo` y hacer el servidor en Dart con el mismo código.

## Ranking

- **Rating por jugador** (tipo Elo): al terminar una sala, cada jugador se compara con los demás
  según la posición final. Además, **mejor puntuación por nivel**.
- Tablas nuevas: `partidas` (sala, nivel, fecha), `partida_jugadores` (partida, usuario, puntos,
  turnos, posición) y `ranking` (usuario, rating, partidas jugadas, ganadas).
- Rutas: `GET /ranking` (top 100), `GET /ranking/yo` (mi posición) y `GET /ranking/nivel/:n`.
- Se muestra el **nametag**, que ya es único (sin distinguir mayúsculas), así que no habrá dos
  jugadores iguales en el ranking. No hay correo ni otro dato personal.
- Si alguien borra su cuenta, sus resultados deben anonimizarse o borrarse (ya existe `ON DELETE CASCADE`
  para los datos de la cuenta; las tablas nuevas deben seguir la misma regla).

## Pasos sugeridos

1. Portar las reglas a JS con la prueba de partidas grabadas.
2. WebSocket con autenticación por cabecera (`Authorization: Bearer ...`, nunca en la URL).
   ```js
   import { WebSocketServer } from 'ws';
   const wss = new WebSocketServer({ noServer: true, maxPayload: 4096 });
   server.on('upgrade', async (req, socket, head) => {
     const m = /^Bearer (.+)$/.exec(req.headers.authorization ?? '');
     const usuario = m && (await autenticarToken(m[1]));
     if (!usuario) { socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n'); return socket.destroy(); }
     wss.handleUpgrade(req, socket, head, (ws) => alConectar(ws, usuario));
   });
   ```
   En móvil funciona; Flutter Web no permite cabeceras en WebSocket (habría que usar un ticket de un solo uso).
3. Salas: crear, unirse con código, empezar, jugada, terminar.
4. Reconexión: el access token dura 15 min; pedir uno nuevo con `tokenDeAcceso()` antes de reconectar.
   Tiempo límite por turno y abandono (el jugador que se va queda con los puntos que llevaba).
5. Ranking y rutas `GET /ranking`.
6. App: `flutter pub add web_socket_channel`, pantalla de salas y pantalla de ranking.
