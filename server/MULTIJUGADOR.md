# Multijugador

Las partidas multijugador usan un WebSocket en `/ws` (en producción, `wss://…/ws`).
Todos los mensajes son objetos JSON con un campo `tipo`.

Estado: **lobby listo** (paso 3). La partida en sí (dados, jugadas, conceder) llega en el paso 4.

## Conexión y autenticación

1. Abrir `ws://servidor:3000/ws`.
2. Antes de 10 s, mandar `{"tipo":"auth","token":"<accessToken>"}`.
   El token va en un mensaje, no en la URL (las URLs quedan en logs) ni en una cabecera
   (Flutter Web no deja poner cabeceras a un WebSocket).
3. Respuesta: `{"tipo":"autenticado","user":{id,nametag},"sala":<sala>|null}`.
   Si `sala` no es null, el jugador ya estaba en una sala (se había caído) y vuelve a ella.

## Mensajes del cliente

| tipo | campos | qué hace |
|---|---|---|
| `crear_sala` | `nivel` (1-4) | Crea una sala con código y entra en ella. |
| `unirse` | `codigo`, `nivel` | Entra a una sala (el código no distingue mayúsculas ni espacios). |
| `elegir_mapa` | `nivel` | Cambia el mapa propio. Quita el "listo". |
| `listo` | `listo` (bool) | Marca o desmarca "listo". |
| `salir` | — | Sale de la sala. Responde `{"tipo":"saliste"}`. |
| `ping` | — | Responde `{"tipo":"pong"}` (además del ping propio de WebSocket). |

## Mensajes del servidor

- `{"tipo":"sala","sala":<sala>,"evento":<evento>?}` cada vez que cambia algo, a todos los de la sala.
- `{"tipo":"partida_iniciada","sala":<sala>}` cuando todos están listos.
- `{"tipo":"error","code","message","en":<tipo del mensaje que lo causó>}`. La conexión sigue abierta.

`<sala>`:
```json
{
  "codigo": "K7M2QX", "estado": "lobby" | "jugando",
  "minJugadores": 2, "maxJugadores": 6,
  "jugadores": [{"id": "...", "nametag": "Ana", "nivel": 2, "listo": true, "conectado": true}]
}
```

`<evento>` (para mostrar avisos): `{"tipo": "creada"|"unido"|"salio"|"desconectado"|"reconectado"|"abandono", "nametag": "..."}`.

Códigos de error: `mapa_invalido`, `sala_no_encontrada`, `sala_llena`, `partida_en_curso`,
`ya_en_sala`, `no_en_sala`, `mensaje_invalido`, `mensaje_desconocido`.

## Reglas del lobby

- Cada jugador elige **su propio mapa** (pueden ser distintos).
- Entre **2 y 6** jugadores. El 7.º recibe `sala_llena`.
- La partida empieza sola cuando hay al menos 2 jugadores, **todos conectados y con "listo"**.
  Si el único que faltaba sale de la sala, los demás empiezan.
- Un usuario solo puede estar en una sala a la vez.
- La sala se borra cuando se va el último jugador.

## Desconexiones

| Situación | Qué pasa |
|---|---|
| Se cae la conexión (Wi-Fi, app cerrada, sin batería) | El servidor lo detecta (cierre o ping de WebSocket sin respuesta cada 15 s). El jugador queda `conectado: false` y **pierde el "listo"**, así nadie empieza con un jugador caído. Los demás reciben el evento `desconectado`. |
| Vuelve antes de 30 s (`RECONNECT_GRACE_SECONDS`) | Al autenticarse recibe su sala en `autenticado.sala` y los demás reciben `reconectado`. |
| No vuelve a tiempo | Sale de la sala (evento `abandono`). |
| Abre la cuenta en otra conexión | La vieja recibe el error `sesion_reemplazada` y se cierra con código 4002; la nueva conserva la sala. |
| Token vencido al reconectar | Cierre 4001: la app debe renovar el token (`/auth/refresh`) y volver a conectar. |

## Códigos de cierre

| Código | Motivo | Qué debe hacer la app |
|---|---|---|
| 4000 | El servidor se apaga | Reintentar más tarde. |
| 4001 | No autenticado (token inválido/vencido o no llegó a tiempo) | Renovar token y reconectar. |
| 4002 | Sesión reemplazada por otra conexión | No reconectar automáticamente. |
| 4003 | Mensaje inválido: >4 KB, binario o >20 mensajes/s | Es un error de la app. |
| otro / sin código | Se cortó la red | Reconectar con espera creciente (1 s, 2 s, 4 s… máx. 15 s). |

## Seguridad

- Cada mensaje: máximo 4 KB, solo texto JSON, máximo 20 por segundo por conexión.
- Códigos de sala de 6 caracteres aleatorios (`Random.secure`) de un alfabeto de 31 símbolos
  (887 millones de combinaciones), sin caracteres que se confundan (0/O, 1/I/L).
- `/ws` pasa por los mismos filtros que la API: HTTPS obligatorio en producción y límite por IP.
- Las reglas de las jugadas se validarán en el servidor con el paquete `brilliant_reglas`
  (el mismo código que usa la app).
