import { DatabaseSync } from 'node:sqlite'; // SQLite incluido en Node (sin compilar nada)
import fs from 'node:fs';
import path from 'node:path';

export function abrirDb(dbPath) {
  if (dbPath !== ':memory:') {
    fs.mkdirSync(path.dirname(path.resolve(dbPath)), { recursive: true });
  }
  const db = new DatabaseSync(dbPath);
  db.exec('PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;');

  // Las primeras versiones del proyecto iniciaban sesión con correo. Si la base
  // de datos es de esa época (tiene la columna "email") se reinicia: eran solo
  // cuentas de prueba y el esquema nuevo no es compatible.
  const columnas = db.prepare('PRAGMA table_info(users)').all();
  if (columnas.some((c) => c.name === 'email')) {
    console.warn('AVISO: base de datos con el esquema antiguo (correo). Se reinicia.');
    db.exec('DROP TABLE IF EXISTS refresh_tokens; DROP TABLE IF EXISTS login_failures; DROP TABLE users;');
  }

  db.exec(`
    -- "nametag" es el nombre público (con sus mayúsculas) y también el usuario
    -- con el que se inicia sesión. "nametag_lower" es lo mismo en minúsculas y es
    -- único: así "Ana" y "ana" no pueden existir a la vez.
    CREATE TABLE IF NOT EXISTS users (
      id            TEXT PRIMARY KEY,
      nametag       TEXT NOT NULL,
      nametag_lower TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      created_at    INTEGER NOT NULL
    );

    -- Solo se guarda el SHA-256 del refresh token: si se filtra la base de datos
    -- los tokens no se pueden usar.
    CREATE TABLE IF NOT EXISTS refresh_tokens (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      family_id  TEXT NOT NULL,
      token_hash TEXT NOT NULL UNIQUE,
      expires_at INTEGER NOT NULL,
      used_at    INTEGER,
      revoked_at INTEGER,
      created_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_refresh_user   ON refresh_tokens(user_id);
    CREATE INDEX IF NOT EXISTS idx_refresh_family ON refresh_tokens(family_id);

    -- Intentos de login fallidos por nametag (exista o no en la base, para
    -- no revelar qué nametags están registrados).
    CREATE TABLE IF NOT EXISTS login_failures (
      clave        TEXT PRIMARY KEY,
      count        INTEGER NOT NULL,
      locked_until INTEGER NOT NULL DEFAULT 0,
      updated_at   INTEGER NOT NULL
    );
  `);
  return db;
}
