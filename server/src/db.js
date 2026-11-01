import Database from 'better-sqlite3';
import fs from 'node:fs';
import path from 'node:path';

export function abrirDb(dbPath) {
  if (dbPath !== ':memory:') {
    fs.mkdirSync(path.dirname(path.resolve(dbPath)), { recursive: true });
  }
  const db = new Database(dbPath);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');

  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id            TEXT PRIMARY KEY,
      email         TEXT NOT NULL UNIQUE,
      nombre        TEXT NOT NULL,
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

    -- Intentos de login fallidos por correo (existan o no en la base, para
    -- no revelar qué correos están registrados).
    CREATE TABLE IF NOT EXISTS login_failures (
      email_key    TEXT PRIMARY KEY,
      count        INTEGER NOT NULL,
      locked_until INTEGER NOT NULL DEFAULT 0,
      updated_at   INTEGER NOT NULL
    );
  `);
  return db;
}
