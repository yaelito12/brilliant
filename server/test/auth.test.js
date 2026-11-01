import { test, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { SignJWT } from 'jose';

import { cargarConfig } from '../src/config.js';
import { abrirDb } from '../src/db.js';
import { crearApp } from '../src/app.js';

const SECRET = 'x'.repeat(48);
const PASS = 'una-clave-larga-123';
let server, base, db, config;

function nuevoEntorno(extra = {}) {
  config = {
    ...cargarConfig({ JWT_SECRET: SECRET }),
    // Argon2 liviano solo para que los tests corran rápido.
    argon2: { memoryCost: 1024, timeCost: 1, parallelism: 1 },
    limiteGlobal: 10_000,
    limiteAuth: 10_000,
    ...extra,
  };
  db = abrirDb(':memory:');
  return crearApp({ config, db });
}

let autenticarToken;

async function arrancar(extra) {
  const entorno = nuevoEntorno(extra);
  autenticarToken = entorno.autenticarToken;
  const { app } = entorno;
  await new Promise((r) => (server = app.listen(0, '127.0.0.1', r)));
  base = `http://127.0.0.1:${server.address().port}`;
}
const parar = () => new Promise((r) => server.close(r));

async function api(method, path, body, token, rawBody) {
  const res = await fetch(base + path, {
    method,
    headers: {
      ...(body !== undefined || rawBody ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: rawBody ?? (body !== undefined ? JSON.stringify(body) : undefined),
  });
  const text = await res.text();
  return { status: res.status, headers: res.headers, json: text ? JSON.parse(text) : null };
}

const registrar = (email = 'ana@example.com', extra = {}) =>
  api('POST', '/auth/register', { email, nombre: 'Ana', password: PASS, ...extra });

before(() => arrancar());
after(parar);
beforeEach(async () => {
  db.exec('DELETE FROM users; DELETE FROM refresh_tokens; DELETE FROM login_failures;');
});

test('registro devuelve sesión y NO guarda la contraseña en claro', async () => {
  const r = await registrar();
  assert.equal(r.status, 201);
  assert.ok(r.json.accessToken && r.json.refreshToken);
  assert.equal(r.json.user.email, 'ana@example.com');
  assert.equal(r.json.user.password, undefined);

  const fila = db.prepare('SELECT * FROM users').get();
  assert.match(fila.password_hash, /^\$argon2id\$/);
  assert.ok(!fila.password_hash.includes(PASS));
  const rt = db.prepare('SELECT token_hash FROM refresh_tokens').get();
  assert.notEqual(rt.token_hash, r.json.refreshToken); // solo se guarda el hash
});

test('registro normaliza el correo y rechaza duplicados', async () => {
  assert.equal((await registrar('  ANA@Example.com ')).status, 201);
  const dup = await registrar('ana@example.com');
  assert.equal(dup.status, 409);
  assert.equal(dup.json.error.code, 'email_en_uso');
});

test('registro valida los datos', async () => {
  const malos = [
    { email: 'no-es-correo' },
    { password: 'corta' },
    { password: 'a'.repeat(129) },
    { password: 'password123' },
    { password: 'aaaaaaaaaaaa' },
    { nombre: '<script>' },
    { nombre: 'A' },
  ];
  for (const m of malos) {
    const r = await registrar('x@example.com', m);
    assert.equal(r.status, 400, JSON.stringify(m));
    assert.equal(r.json.error.code, 'validacion');
  }
  assert.equal((await api('POST', '/auth/register', {})).status, 400);
});

test('login correcto e incorrecto (mismo mensaje exista o no el usuario)', async () => {
  await registrar();
  const ok = await api('POST', '/auth/login', { email: 'ana@example.com', password: PASS });
  assert.equal(ok.status, 200);
  assert.ok(ok.json.accessToken);

  const malaPass = await api('POST', '/auth/login', { email: 'ana@example.com', password: 'otra-clave-123' });
  const noExiste = await api('POST', '/auth/login', { email: 'nadie@example.com', password: 'otra-clave-123' });
  assert.equal(malaPass.status, 401);
  assert.equal(noExiste.status, 401);
  assert.deepEqual(malaPass.json, noExiste.json);
});

test('bloqueo tras varios intentos fallidos (también para correos inexistentes)', async () => {
  await registrar();
  for (const email of ['ana@example.com', 'fantasma@example.com']) {
    for (let i = 0; i < config.maxIntentosFallidos; i++) {
      assert.equal((await api('POST', '/auth/login', { email, password: 'mala-clave-123' })).status, 401);
    }
    const bloqueado = await api('POST', '/auth/login', { email, password: PASS });
    assert.equal(bloqueado.status, 429);
    assert.equal(bloqueado.json.error.code, 'cuenta_bloqueada');
    assert.ok(bloqueado.headers.get('retry-after'));
  }
});

test('un login correcto reinicia el contador de fallos', async () => {
  await registrar();
  for (let i = 0; i < config.maxIntentosFallidos - 1; i++) {
    await api('POST', '/auth/login', { email: 'ana@example.com', password: 'mala-clave-123' });
  }
  assert.equal((await api('POST', '/auth/login', { email: 'ana@example.com', password: PASS })).status, 200);
  for (let i = 0; i < config.maxIntentosFallidos - 1; i++) {
    await api('POST', '/auth/login', { email: 'ana@example.com', password: 'mala-clave-123' });
  }
  assert.equal((await api('POST', '/auth/login', { email: 'ana@example.com', password: PASS })).status, 200);
});

test('/account/me exige un access token válido', async () => {
  const { json } = await registrar();
  assert.equal((await api('GET', '/account/me')).status, 401);
  assert.equal((await api('GET', '/account/me', undefined, 'basura')).status, 401);
  const me = await api('GET', '/account/me', undefined, json.accessToken);
  assert.equal(me.status, 200);
  assert.equal(me.json.user.nombre, 'Ana');
});

test('rechaza JWT firmado con otra clave, vencido o con alg=none', async () => {
  const { json } = await registrar();
  const id = json.user.id;
  const firmar = (secret, exp) =>
    new SignJWT({}).setProtectedHeader({ alg: 'HS256' }).setSubject(id)
      .setIssuer('brilliant-auth').setAudience('brilliant-app').setExpirationTime(exp)
      .sign(new TextEncoder().encode(secret));

  assert.equal((await api('GET', '/account/me', undefined, await firmar('y'.repeat(48), '5m'))).status, 401);
  assert.equal((await api('GET', '/account/me', undefined, await firmar(SECRET, Math.floor(Date.now() / 1000) - 60))).status, 401);
  assert.equal((await api('GET', '/account/me', undefined, await firmar(SECRET, '5m'))).status, 200);

  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const none = `${b64({ alg: 'none', typ: 'JWT' })}.${b64({ sub: id, iss: 'brilliant-auth', aud: 'brilliant-app', exp: 9999999999 })}.`;
  assert.equal((await api('GET', '/account/me', undefined, none)).status, 401);
});

test('refresh rota el token y detecta reutilización (revoca toda la sesión)', async () => {
  const s1 = (await registrar()).json;
  const r2 = await api('POST', '/auth/refresh', { refreshToken: s1.refreshToken });
  assert.equal(r2.status, 200);
  assert.notEqual(r2.json.refreshToken, s1.refreshToken);

  // Reutilizar el token viejo = posible robo: falla y mata la familia.
  const reuso = await api('POST', '/auth/refresh', { refreshToken: s1.refreshToken });
  assert.equal(reuso.status, 401);
  const nuevoTrasReuso = await api('POST', '/auth/refresh', { refreshToken: r2.json.refreshToken });
  assert.equal(nuevoTrasReuso.status, 401);
});

test('refresh con token inventado o vencido falla', async () => {
  assert.equal((await api('POST', '/auth/refresh', { refreshToken: 'a'.repeat(43) })).status, 401);
  const s = (await registrar()).json;
  db.prepare('UPDATE refresh_tokens SET expires_at = 1').run();
  assert.equal((await api('POST', '/auth/refresh', { refreshToken: s.refreshToken })).status, 401);
});

test('logout revoca el refresh token', async () => {
  const s = (await registrar()).json;
  assert.equal((await api('POST', '/auth/logout', { refreshToken: s.refreshToken })).status, 204);
  assert.equal((await api('POST', '/auth/refresh', { refreshToken: s.refreshToken })).status, 401);
  // Con un token desconocido también responde 204 (no filtra información).
  assert.equal((await api('POST', '/auth/logout', { refreshToken: 'b'.repeat(43) })).status, 204);
});

test('logout-all cierra todas las sesiones', async () => {
  const a = (await registrar()).json;
  const b = (await api('POST', '/auth/login', { email: 'ana@example.com', password: PASS })).json;
  assert.equal((await api('POST', '/auth/logout-all', undefined, a.accessToken)).status, 204);
  assert.equal((await api('POST', '/auth/refresh', { refreshToken: a.refreshToken })).status, 401);
  assert.equal((await api('POST', '/auth/refresh', { refreshToken: b.refreshToken })).status, 401);
});

test('borrar cuenta: exige contraseña, borra todo y el token deja de servir', async () => {
  const s = (await registrar()).json;
  assert.equal((await api('POST', '/account/delete', { password: PASS })).status, 401); // sin token
  const mala = await api('POST', '/account/delete', { password: 'incorrecta-123' }, s.accessToken);
  assert.equal(mala.status, 403);
  assert.equal((await api('GET', '/account/me', undefined, s.accessToken)).status, 200);

  assert.equal((await api('POST', '/account/delete', { password: PASS }, s.accessToken)).status, 204);
  assert.equal(db.prepare('SELECT COUNT(*) c FROM users').get().c, 0);
  assert.equal(db.prepare('SELECT COUNT(*) c FROM refresh_tokens').get().c, 0);
  assert.equal((await api('GET', '/account/me', undefined, s.accessToken)).status, 401);
  assert.equal((await api('POST', '/auth/refresh', { refreshToken: s.refreshToken })).status, 401);
  assert.equal((await api('POST', '/auth/login', { email: 'ana@example.com', password: PASS })).status, 401);
  // Se puede volver a registrar con el mismo correo.
  assert.equal((await registrar()).status, 201);
});

test('JSON inválido, cuerpo enorme y rutas inexistentes dan errores limpios', async () => {
  assert.equal((await api('POST', '/auth/login', undefined, undefined, '{no es json')).json.error.code, 'json_invalido');
  const grande = await api('POST', '/auth/login', { email: 'a@b.co', password: 'x'.repeat(20_000) });
  assert.equal(grande.status, 413);
  assert.equal((await api('GET', '/nada')).status, 404);
});

test('cabeceras de seguridad presentes y sin x-powered-by', async () => {
  const r = await api('GET', '/health');
  assert.equal(r.headers.get('x-powered-by'), null);
  assert.equal(r.headers.get('x-content-type-options'), 'nosniff');
  assert.equal(r.headers.get('cache-control'), 'no-store');
});

test('inyección SQL en el correo no funciona', async () => {
  await registrar();
  const r = await api('POST', '/auth/login', { email: "' OR 1=1 --", password: PASS });
  assert.equal(r.status, 400);
});

test('límite de peticiones por IP en rutas de autenticación', async () => {
  await parar();
  await arrancar({ limiteAuth: 3 });
  const estados = [];
  for (let i = 0; i < 5; i++) {
    estados.push((await api('POST', '/auth/login', { email: 'a@b.co', password: 'x' })).status);
  }
  assert.deepEqual(estados, [401, 401, 401, 429, 429]);
  await parar();
  await arrancar();
});

test('con HTTPS obligatorio rechaza peticiones HTTP', async () => {
  await parar();
  await arrancar({ requireHttps: true });
  assert.equal((await api('GET', '/health')).status, 400);
  await parar();
  await arrancar();
});

test('la configuración exige un JWT_SECRET largo', () => {
  assert.throws(() => cargarConfig({}), /JWT_SECRET/);
  assert.throws(() => cargarConfig({ JWT_SECRET: 'corto' }), /JWT_SECRET/);
});

test('autenticarToken (para el futuro servidor de partidas)', async () => {
  const s = (await registrar()).json;
  assert.equal((await autenticarToken(s.accessToken)).email, 'ana@example.com');
  assert.equal(await autenticarToken('basura'), null);
  assert.equal(await autenticarToken(undefined), null);
  assert.equal(await autenticarToken(s.refreshToken), null); // un refresh token no es un access token

  await api('POST', '/account/delete', { password: PASS }, s.accessToken);
  assert.equal(await autenticarToken(s.accessToken), null); // cuenta borrada
});
