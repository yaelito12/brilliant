// Configuración del servidor. Todo sale de variables de entorno (ver .env.example).
// Si falta algo crítico (por ejemplo JWT_SECRET) el servidor NO arranca.

const MIN_SECRET_LENGTH = 32;

function entero(valor, porDefecto) {
  if (valor === undefined || valor === '') return porDefecto;
  const n = Number.parseInt(valor, 10);
  if (!Number.isFinite(n) || n <= 0) {
    throw new Error(`Valor numérico inválido en la configuración: "${valor}"`);
  }
  return n;
}

export function cargarConfig(env = process.env) {
  const produccion = env.NODE_ENV === 'production';

  const jwtSecret = env.JWT_SECRET ?? '';
  if (jwtSecret.length < MIN_SECRET_LENGTH) {
    throw new Error(
      `JWT_SECRET es obligatorio y debe tener al menos ${MIN_SECRET_LENGTH} caracteres. ` +
        'Genera uno con: npm run gen-secret',
    );
  }

  return {
    produccion,
    puerto: entero(env.PORT, 3000),
    dbPath: env.DB_PATH || './data/brilliant.db',
    jwtSecret,
    // Pepper opcional: secreto extra que se mezcla con el hash de Argon2.
    // OJO: si lo cambias, todas las contraseñas existentes dejan de funcionar.
    passwordPepper: env.PASSWORD_PEPPER || null,

    accessTtlSeg: entero(env.ACCESS_TOKEN_TTL_SECONDS, 15 * 60), // 15 min
    refreshTtlSeg: entero(env.REFRESH_TOKEN_TTL_SECONDS, 30 * 24 * 3600), // 30 días

    // Argon2id (OWASP recomienda como mínimo m=19MiB,t=2,p=1).
    argon2: {
      memoryCost: entero(env.ARGON2_MEMORY_KIB, 65536),
      timeCost: entero(env.ARGON2_TIME_COST, 3),
      parallelism: entero(env.ARGON2_PARALLELISM, 1),
    },

    // Bloqueo de cuenta por intentos fallidos (por correo, exista o no).
    maxIntentosFallidos: entero(env.MAX_FAILED_LOGINS, 5),
    bloqueoSeg: entero(env.LOCKOUT_SECONDS, 15 * 60),

    // Límite de peticiones por IP.
    limiteGlobal: entero(env.RATE_LIMIT_GLOBAL, 300), // por 15 min
    limiteAuth: entero(env.RATE_LIMIT_AUTH, 20), // por 15 min

    // Orígenes permitidos para CORS (solo necesario si usas Flutter Web).
    corsOrigins: (env.CORS_ORIGINS ?? '')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean),

    // Detrás de un proxy inverso (nginx, Caddy, Render, Fly...) pon TRUST_PROXY=1
    // para que el límite por IP y la detección de HTTPS usen la IP/protocolo reales.
    trustProxy: env.TRUST_PROXY ? entero(env.TRUST_PROXY, 1) : false,
    requireHttps: env.REQUIRE_HTTPS ? env.REQUIRE_HTTPS === 'true' : produccion,
  };
}
