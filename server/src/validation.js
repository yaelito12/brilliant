import { z } from 'zod';

// Con contraseñas de solo 6 caracteres esta lista importa más: evita las más obvias.
const CONTRASENAS_COMUNES = new Set([
  '123456', '1234567', '12345678', '123456789', '1234567890', '654321', '111111',
  '000000', '123123', '121212', '123321', '112233', 'abc123', 'abcdef', 'qwerty',
  'qwerty1', 'qwerty123', 'qwertyuiop', 'password', 'password1', 'password123',
  'contraseña', 'contrasena', 'contrasena1', 'iloveyou', 'admin123', 'letmein',
  'brilliant', 'brilliant1', 'brilliant123',
]);

const MIN_PASSWORD = 6;
const MAX_PASSWORD = 128;

// 3 a 20 caracteres: letras sin acentos, números, punto, guion y guion bajo.
// Sin espacios ni letras raras, para que nadie pueda hacerse pasar por otro
// usando caracteres que se ven iguales.
const nametag = z
  .string({ error: 'El nametag es obligatorio.' })
  .trim()
  .min(3, 'El nametag debe tener al menos 3 caracteres.')
  .max(20, 'El nametag no puede pasar de 20 caracteres.')
  .regex(/^[A-Za-z0-9_.-]+$/, 'El nametag solo puede tener letras, números, punto, guion y guion bajo.');

export const registroSchema = z
  .object({
    nametag,
    password: z
      .string({ error: 'La contraseña es obligatoria.' })
      .min(MIN_PASSWORD, `La contraseña debe tener al menos ${MIN_PASSWORD} caracteres.`)
      .max(MAX_PASSWORD, `La contraseña no puede pasar de ${MAX_PASSWORD} caracteres.`),
  })
  .superRefine((d, ctx) => {
    const p = d.password.toLowerCase();
    if (CONTRASENAS_COMUNES.has(p) || p === d.nametag.toLowerCase() || /^(.)\1+$/.test(p)) {
      ctx.addIssue({ code: 'custom', path: ['password'], message: 'Esa contraseña es demasiado fácil de adivinar.' });
    }
  });

// Al iniciar sesión no se revisa el formato (solo que no sea absurdo): así nunca
// se revela qué reglas tiene un nametag y se evita trabajo inútil.
export const loginSchema = z.object({
  nametag: z.string({ error: 'El nametag es obligatorio.' }).trim().min(1).max(40),
  password: z.string({ error: 'La contraseña es obligatoria.' }).min(1).max(MAX_PASSWORD),
});

export const refreshSchema = z.object({
  refreshToken: z.string().min(20).max(200),
});

export const borrarCuentaSchema = z.object({
  password: z.string({ error: 'La contraseña es obligatoria.' }).min(1).max(MAX_PASSWORD),
});
