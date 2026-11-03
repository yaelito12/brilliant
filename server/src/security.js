import argon2 from 'argon2';
import crypto from 'node:crypto';
import { SignJWT, jwtVerify } from 'jose';

const ISSUER = 'brilliant-auth';
const AUDIENCE = 'brilliant-app';

export function crearSeguridad(config) {
  const secretoJwt = new TextEncoder().encode(config.jwtSecret);
  const pepper = config.passwordPepper ? Buffer.from(config.passwordPepper) : undefined;

  const opcionesHash = {
    type: argon2.argon2id,
    memoryCost: config.argon2.memoryCost,
    timeCost: config.argon2.timeCost,
    parallelism: config.argon2.parallelism,
    ...(pepper ? { secret: pepper } : {}),
  };

  // Hash "señuelo": cuando el nametag no existe también se hace una verificación
  // de Argon2 para que la respuesta tarde lo mismo (evita enumerar usuarios por tiempo).
  let hashSenuelo;
  const obtenerSenuelo = async () =>
    (hashSenuelo ??= await argon2.hash(crypto.randomBytes(16).toString('hex'), opcionesHash));

  return {
    hashearPassword: (password) => argon2.hash(password, opcionesHash),

    async verificarPassword(hash, password) {
      try {
        return await argon2.verify(hash, password, pepper ? { secret: pepper } : undefined);
      } catch {
        return false;
      }
    },

    async verificarContraSenuelo(password) {
      await argon2.verify(await obtenerSenuelo(), password, pepper ? { secret: pepper } : undefined);
    },

    async crearAccessToken(userId) {
      return new SignJWT({})
        .setProtectedHeader({ alg: 'HS256' })
        .setSubject(userId)
        .setIssuer(ISSUER)
        .setAudience(AUDIENCE)
        .setJti(crypto.randomUUID())
        .setIssuedAt()
        .setExpirationTime(`${config.accessTtlSeg}s`)
        .sign(secretoJwt);
    },

    /** Devuelve el id de usuario o null si el token no es válido/está vencido. */
    async verificarAccessToken(token) {
      try {
        const { payload } = await jwtVerify(token, secretoJwt, {
          algorithms: ['HS256'],
          issuer: ISSUER,
          audience: AUDIENCE,
        });
        return typeof payload.sub === 'string' ? payload.sub : null;
      } catch {
        return null;
      }
    },

    nuevoRefreshToken: () => crypto.randomBytes(32).toString('base64url'),
    hashToken: (token) => crypto.createHash('sha256').update(token).digest('hex'),
    // Clave (anónima) para contar intentos fallidos de un nametag.
    hashClaveUsuario: (nametagMinusculas) =>
      crypto.createHmac('sha256', config.jwtSecret).update(nametagMinusculas).digest('hex'),
  };
}
