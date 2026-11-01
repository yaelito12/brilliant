import { z } from 'zod';

const CONTRASENAS_COMUNES = new Set([
  'password1234', '1234567890', '12345678910', 'qwertyuiop', 'contrasena123',
  'contraseña123', 'abcdefghij', 'password123', 'iloveyou123', 'admin12345',
  '0123456789', 'brilliant123', 'brilliant1234',
]);

const email = z
  .string({ error: 'El correo es obligatorio.' })
  .trim()
  .toLowerCase()
  .max(254, 'El correo es demasiado largo.')
  .pipe(z.email({ error: 'El correo no es válido.' }));

const nombre = z
  .string({ error: 'El nombre es obligatorio.' })
  .trim()
  .min(2, 'El nombre debe tener al menos 2 caracteres.')
  .max(30, 'El nombre no puede pasar de 30 caracteres.')
  // Letras (con acentos), números, espacios y . _ -  (evita caracteres de control/HTML)
  .regex(/^[\p{L}\p{N} ._-]+$/u, 'El nombre solo puede tener letras, números, espacios, punto, guion y guion bajo.');

export const registroSchema = z
  .object({
    email,
    nombre,
    password: z
      .string({ error: 'La contraseña es obligatoria.' })
      .min(10, 'La contraseña debe tener al menos 10 caracteres.')
      .max(128, 'La contraseña no puede pasar de 128 caracteres.'),
  })
  .superRefine((d, ctx) => {
    const p = d.password.toLowerCase();
    if (CONTRASENAS_COMUNES.has(p) || p === d.email || /^(.)\1+$/.test(p)) {
      ctx.addIssue({ code: 'custom', path: ['password'], message: 'Esa contraseña es demasiado fácil de adivinar.' });
    }
  });

export const loginSchema = z.object({
  email,
  password: z.string({ error: 'La contraseña es obligatoria.' }).min(1).max(128),
});

export const refreshSchema = z.object({
  refreshToken: z.string().min(20).max(200),
});

export const borrarCuentaSchema = z.object({
  password: z.string({ error: 'La contraseña es obligatoria.' }).min(1).max(128),
});
