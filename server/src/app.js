import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import crypto from 'node:crypto';
import { rateLimit } from 'express-rate-limit';

import { crearSeguridad } from './security.js';
import { registroSchema, loginSchema, refreshSchema, borrarCuentaSchema } from './validation.js';

class ApiError extends Error {
  constructor(status, code, message, extra = {}) {
    super(message);
    this.status = status;
    this.code = code;
    this.extra = extra;
  }
}

const ahora = () => Math.floor(Date.now() / 1000);
const asyncH = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

function validar(schema, datos) {
  const r = schema.safeParse(datos ?? {});
  if (r.success) return r.data;
  const campos = {};
  for (const issue of r.error.issues) {
    const campo = issue.path.join('.') || 'body';
    campos[campo] ??= issue.message;
  }
  throw new ApiError(400, 'validacion', 'Hay datos inválidos.', { campos });
}

export function crearApp({ config, db }) {
  const seg = crearSeguridad(config);
  const app = express();

  app.disable('x-powered-by');
  if (config.trustProxy) app.set('trust proxy', config.trustProxy);

  // ---------- Consultas preparadas ----------
  const q = {
    usuarioPorNametag: db.prepare('SELECT * FROM users WHERE nametag_lower = ?'),
    usuarioPorId: db.prepare('SELECT id, nametag FROM users WHERE id = ?'),
    usuarioConHash: db.prepare('SELECT * FROM users WHERE id = ?'),
    insertarUsuario: db.prepare(
      'INSERT INTO users (id, nametag, nametag_lower, password_hash, created_at) VALUES (?, ?, ?, ?, ?)',
    ),
    borrarUsuario: db.prepare('DELETE FROM users WHERE id = ?'),

    insertarRefresh: db.prepare(
      `INSERT INTO refresh_tokens (user_id, family_id, token_hash, expires_at, created_at)
       VALUES (?, ?, ?, ?, ?)`,
    ),
    refreshPorHash: db.prepare('SELECT * FROM refresh_tokens WHERE token_hash = ?'),
    marcarUsado: db.prepare('UPDATE refresh_tokens SET used_at = ? WHERE id = ? AND used_at IS NULL'),
    revocarFamilia: db.prepare(
      'UPDATE refresh_tokens SET revoked_at = ? WHERE family_id = ? AND revoked_at IS NULL',
    ),
    revocarUsuario: db.prepare(
      'UPDATE refresh_tokens SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL',
    ),
    limpiarVencidos: db.prepare(
      'DELETE FROM refresh_tokens WHERE expires_at < ? OR (revoked_at IS NOT NULL AND revoked_at < ?)',
    ),

    fallo: db.prepare('SELECT * FROM login_failures WHERE clave = ?'),
    guardarFallo: db.prepare(
      `INSERT INTO login_failures (clave, count, locked_until, updated_at) VALUES (?, ?, ?, ?)
       ON CONFLICT(clave) DO UPDATE SET count = excluded.count,
         locked_until = excluded.locked_until, updated_at = excluded.updated_at`,
    ),
    borrarFallo: db.prepare('DELETE FROM login_failures WHERE clave = ?'),
    limpiarFallos: db.prepare('DELETE FROM login_failures WHERE updated_at < ?'),
  };

  // node:sqlite no trae db.transaction(): se hace a mano. Si [fn] termina bien se
  // guarda todo (incluso si devuelve un "error" de negocio); si lanza, se deshace.
  function enTransaccion(fn) {
    db.exec('BEGIN IMMEDIATE');
    try {
      const resultado = fn();
      db.exec('COMMIT');
      return resultado;
    } catch (e) {
      db.exec('ROLLBACK');
      throw e;
    }
  }

  // ---------- Bloqueo por intentos fallidos ----------
  function segundosDeBloqueo(clave) {
    const f = q.fallo.get(seg.hashClaveUsuario(clave));
    if (f && f.locked_until > ahora()) return f.locked_until - ahora();
    return 0;
  }
  function registrarFallo(clave) {
    const key = seg.hashClaveUsuario(clave);
    const f = q.fallo.get(key);
    // Si el bloqueo anterior ya venció, se empieza de cero.
    const previos = f && !(f.locked_until && f.locked_until <= ahora()) ? f.count : 0;
    const count = previos + 1;
    const lock = count >= config.maxIntentosFallidos ? ahora() + config.bloqueoSeg : 0;
    q.guardarFallo.run(key, lock ? 0 : count, lock, ahora());
  }
  const limpiarFallos = (clave) => q.borrarFallo.run(seg.hashClaveUsuario(clave));

  function bloqueadoError(segundos) {
    return new ApiError(
      429,
      'cuenta_bloqueada',
      'Demasiados intentos fallidos. Inténtalo de nuevo más tarde.',
      { reintentarEnSegundos: segundos },
    );
  }

  // ---------- Sesiones (access + refresh con rotación) ----------
  async function emitirSesion(userId, familyId = crypto.randomUUID()) {
    const refreshToken = seg.nuevoRefreshToken();
    q.insertarRefresh.run(
      userId,
      familyId,
      seg.hashToken(refreshToken),
      ahora() + config.refreshTtlSeg,
      ahora(),
    );
    const accessToken = await seg.crearAccessToken(userId);
    return { accessToken, refreshToken, expiresIn: config.accessTtlSeg };
  }

  // ---------- Middleware general ----------
  if (config.requireHttps) {
    app.use((req, _res, next) =>
      req.secure ? next() : next(new ApiError(400, 'https_requerido', 'Se requiere HTTPS.')),
    );
  }
  app.use(helmet());
  if (config.corsOrigins.length > 0) {
    app.use(cors({ origin: config.corsOrigins, methods: ['GET', 'POST'], maxAge: 600 }));
  }
  app.use(rateLimit({ windowMs: 15 * 60 * 1000, limit: config.limiteGlobal, standardHeaders: 'draft-7', legacyHeaders: false }));
  app.use(express.json({ limit: '10kb', strict: true, type: 'application/json' }));
  app.use((_req, res, next) => {
    res.set('Cache-Control', 'no-store');
    next();
  });

  const limiteAuth = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: config.limiteAuth,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    handler: (_req, _res, next) =>
      next(new ApiError(429, 'demasiadas_peticiones', 'Demasiadas peticiones. Espera unos minutos.')),
  });

  /**
   * Devuelve el usuario dueño de un access token, o null si no sirve.
   * Se consulta la base para que el token de una cuenta ya borrada deje de
   * servir al instante. La usan las rutas HTTP y, más adelante, el servidor
   * de partidas en tiempo real (WebSocket).
   */
  async function autenticarToken(token) {
    if (typeof token !== 'string' || !/^[A-Za-z0-9._-]+$/.test(token)) return null;
    const userId = await seg.verificarAccessToken(token);
    return (userId && q.usuarioPorId.get(userId)) || null;
  }

  const requiereAuth = asyncH(async (req, _res, next) => {
    const m = /^Bearer (.+)$/.exec(req.get('authorization') ?? '');
    const usuario = m ? await autenticarToken(m[1]) : null;
    if (!usuario) throw new ApiError(401, 'no_autenticado', 'Sesión inválida o vencida.');
    req.usuario = usuario;
    next();
  });

  const publico = (u) => ({ id: u.id, nametag: u.nametag });

  // ---------- Rutas ----------
  app.get('/health', (_req, res) => res.json({ ok: true }));

  app.post('/auth/register', limiteAuth, asyncH(async (req, res) => {
    const { nametag, password } = validar(registroSchema, req.body);
    const clave = nametag.toLowerCase();

    if (q.usuarioPorNametag.get(clave)) {
      throw new ApiError(409, 'nametag_en_uso', 'Ese nametag ya está en uso.');
    }
    const hash = await seg.hashearPassword(password);
    const id = crypto.randomUUID();
    try {
      q.insertarUsuario.run(id, nametag, clave, hash, ahora());
    } catch (e) {
      if (/UNIQUE constraint failed/i.test(String(e.message))) {
        throw new ApiError(409, 'nametag_en_uso', 'Ese nametag ya está en uso.');
      }
      throw e;
    }
    const sesion = await emitirSesion(id);
    res.status(201).json({ ...sesion, user: { id, nametag } });
  }));

  app.post('/auth/login', limiteAuth, asyncH(async (req, res) => {
    const { nametag, password } = validar(loginSchema, req.body);
    const clave = nametag.toLowerCase();

    const espera = segundosDeBloqueo(clave);
    if (espera > 0) throw bloqueadoError(espera);

    const usuario = q.usuarioPorNametag.get(clave);
    let ok = false;
    if (usuario) ok = await seg.verificarPassword(usuario.password_hash, password);
    else await seg.verificarContraSenuelo(password); // mismo coste de tiempo

    if (!ok) {
      registrarFallo(clave);
      throw new ApiError(401, 'credenciales_invalidas', 'Nametag o contraseña incorrectos.');
    }
    limpiarFallos(clave);
    const sesion = await emitirSesion(usuario.id);
    res.json({ ...sesion, user: publico(usuario) });
  }));

  app.post('/auth/refresh', limiteAuth, asyncH(async (req, res) => {
    const { refreshToken } = validar(refreshSchema, req.body);
    const hash = seg.hashToken(refreshToken);

    // Rotación: cada refresh token sirve UNA vez. Si alguien reutiliza uno ya
    // usado, se asume robo y se revoca toda la familia de sesiones.
    const resultado = enTransaccion(() => {
      const t = q.refreshPorHash.get(hash);
      if (!t) return { error: true };
      if (t.revoked_at || t.used_at) {
        q.revocarFamilia.run(ahora(), t.family_id);
        return { error: true };
      }
      if (t.expires_at < ahora()) return { error: true };
      if (q.marcarUsado.run(ahora(), t.id).changes !== 1) return { error: true };
      return { userId: t.user_id, familyId: t.family_id };
    });

    if (resultado.error) throw new ApiError(401, 'refresh_invalido', 'Sesión inválida o vencida.');
    const usuario = q.usuarioPorId.get(resultado.userId);
    if (!usuario) throw new ApiError(401, 'refresh_invalido', 'Sesión inválida o vencida.');

    const sesion = await emitirSesion(usuario.id, resultado.familyId);
    res.json({ ...sesion, user: publico(usuario) });
  }));

  app.post('/auth/logout', limiteAuth, asyncH(async (req, res) => {
    const { refreshToken } = validar(refreshSchema, req.body);
    const t = q.refreshPorHash.get(seg.hashToken(refreshToken));
    if (t) q.revocarFamilia.run(ahora(), t.family_id);
    res.status(204).end(); // siempre 204: no revela si el token existía
  }));

  app.post('/auth/logout-all', requiereAuth, (req, res) => {
    q.revocarUsuario.run(ahora(), req.usuario.id);
    res.status(204).end();
  });

  app.get('/account/me', requiereAuth, (req, res) => res.json({ user: publico(req.usuario) }));

  // Borrar la cuenta exige la contraseña otra vez (re-autenticación): un token
  // robado por sí solo no basta para destruir la cuenta.
  app.post('/account/delete', limiteAuth, requiereAuth, asyncH(async (req, res) => {
    const { password } = validar(borrarCuentaSchema, req.body);
    const clave = req.usuario.nametag.toLowerCase();

    const espera = segundosDeBloqueo(clave);
    if (espera > 0) throw bloqueadoError(espera);

    const completo = q.usuarioConHash.get(req.usuario.id);
    if (!(await seg.verificarPassword(completo.password_hash, password))) {
      registrarFallo(clave);
      throw new ApiError(403, 'password_incorrecta', 'La contraseña es incorrecta.');
    }
    limpiarFallos(clave);
    q.borrarUsuario.run(req.usuario.id); // ON DELETE CASCADE borra sus refresh tokens
    res.status(204).end();
  }));

  // ---------- Errores ----------
  app.use((_req, _res, next) => next(new ApiError(404, 'no_encontrado', 'Ruta no encontrada.')));

  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    let { status, code, message, extra } = err;
    if (err.type === 'entity.parse.failed') {
      status = 400; code = 'json_invalido'; message = 'El cuerpo no es un JSON válido.';
    } else if (err.type === 'entity.too.large') {
      status = 413; code = 'cuerpo_muy_grande'; message = 'El cuerpo es demasiado grande.';
    } else if (!(err instanceof ApiError)) {
      console.error('[error]', err); // el detalle solo va al log, nunca al cliente
      status = 500; code = 'error_interno'; message = 'Error interno del servidor.';
    }
    if (extra?.reintentarEnSegundos) res.set('Retry-After', String(extra.reintentarEnSegundos));
    res.status(status).json({ error: { code, message, ...extra } });
  });

  // Limpieza periódica de datos vencidos.
  const limpiar = () => {
    const t = ahora();
    q.limpiarVencidos.run(t, t - 7 * 24 * 3600);
    q.limpiarFallos.run(t - 24 * 3600);
  };
  limpiar();

  return { app, limpiar, autenticarToken };
}
