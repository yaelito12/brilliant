# Servidor de autenticación de Brilliant

Servidor aparte (Node.js + Express + SQLite integrado de Node) donde se registran los clientes
(la app Flutter de la carpeta raíz). Permite **crear cuenta, iniciar sesión,
cerrar sesión y borrar la cuenta**.

## Arranque rápido

```bash
cd server
npm install
cp .env.example .env
npm run gen-secret        # copia el resultado en JWT_SECRET dentro de .env
npm start                 # http://localhost:3000
npm test                  # 19 pruebas
```

Requiere Node 22.13 o superior (usa el SQLite incluido en Node, no hay que compilar nada).

## API

Todas las respuestas son JSON. Los errores tienen la forma
`{"error": {"code": "...", "message": "..."}}`.

| Método | Ruta | Cuerpo | Respuesta |
|---|---|---|---|
| POST | `/auth/register` | `nametag`, `password` | 201 + sesión |
| POST | `/auth/login` | `nametag`, `password` | 200 + sesión |
| POST | `/auth/refresh` | `refreshToken` | 200 + sesión nueva |
| POST | `/auth/logout` | `refreshToken` | 204 |
| POST | `/auth/logout-all` | — (Bearer) | 204 |
| GET | `/account/me` | — (Bearer) | 200 `{user}` |
| POST | `/account/delete` | `password` (Bearer) | 204 |
| GET | `/health` | — | 200 |

"Sesión" = `{accessToken, refreshToken, expiresIn, user: {id, nametag}}`.
Las rutas protegidas llevan `Authorization: Bearer <accessToken>`.

## Qué hace para ser seguro

| Amenaza | Medida |
|---|---|
| Robo de la base de datos | Contraseñas con **Argon2id** (64 MiB, t=3) y sal propia por usuario; pepper opcional fuera de la BD. Los refresh tokens se guardan como SHA-256. |
| Fuerza bruta | Bloqueo de 15 min tras 5 fallos por nametag (existan o no) + límite por IP (20 peticiones/15 min en rutas de auth). |
| Enumeración de usuarios | Mismo mensaje y mismo tiempo de respuesta si el nametag no existe (hash señuelo). El bloqueo también aplica a nametags inexistentes. |
| Robo de tokens | Access token JWT de 15 min (HS256, con `iss`/`aud`/`exp`, algoritmo fijado). Refresh token aleatorio de 256 bits, **de un solo uso con rotación**: si se reutiliza uno viejo se revoca toda la sesión. |
| Cuenta borrada | El access token se valida contra la BD en cada petición, así que deja de servir al instante. Borrar la cuenta exige la contraseña de nuevo. |
| Inyección / abuso | Consultas SQL preparadas, validación con Zod, cuerpo máximo 10 KB, `helmet`, sin `X-Powered-By`, `Cache-Control: no-store`. |
| Tráfico en claro | En `NODE_ENV=production` rechaza peticiones que no lleguen por HTTPS. |
| Mala configuración | No arranca sin `JWT_SECRET` de 32+ caracteres. Errores internos solo van al log. |

Paquetes de seguridad usados (no se implementó criptografía propia):
`argon2`, `jose`, `helmet`, `express-rate-limit`, `zod`.

## Puesta en producción

1. Pon el servidor detrás de un proxy con **TLS** (Caddy, nginx, Render, Fly...).
2. Variables: `NODE_ENV=production`, `TRUST_PROXY=1`, `JWT_SECRET=...`.
3. Respalda el archivo `DB_PATH` y no lo expongas.
4. Si cambias `JWT_SECRET` los access tokens vigentes dejan de valer, pero la app los renueva
   sola con el refresh token (que no depende de ese secreto); nadie tiene que volver a entrar.

## Límites conocidos (a propósito, para esta entrega)

- **No hay correo:** la cuenta es solo nametag y contraseña, así que **no existe "olvidé mi
  contraseña"**. Si alguien la pierde, pierde la cuenta.
- **Contraseña mínima de 6 caracteres** (se rechazan las más obvias como `123456` o `qwerty`).
  Es una política débil a propósito; lo que la protege es Argon2id, el bloqueo tras 5 fallos y el
  límite por IP. Si algún día quieres más seguridad, basta subir el mínimo en
  `server/src/validation.js` y en `lib/auth/validadores.dart`.
- El nametag es público y único (sin distinguir mayúsculas), así que registrar uno ya usado responde
  409. Es inevitable en cualquier juego con nombres públicos; está protegido por el límite por IP.
- El bloqueo por nametag permite que alguien bloquee 15 min a otra persona a propósito; es el
  coste habitual de este tipo de protección.
- SQLite sirve para un solo servidor. Para varias instancias habría que pasar a PostgreSQL.
