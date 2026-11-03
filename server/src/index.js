import http from 'node:http';

import { cargarConfig } from './config.js';
import { abrirDb } from './db.js';
import { crearApp } from './app.js';

let config;
try {
  config = cargarConfig();
} catch (e) {
  console.error(`Configuración inválida: ${e.message}`);
  process.exit(1);
}

const db = abrirDb(config.dbPath);
const { app, limpiar, autenticarToken } = crearApp({ config, db });

const timer = setInterval(limpiar, 60 * 60 * 1000);
timer.unref();

// Servidor HTTP explícito: así el servidor de partidas en tiempo real puede
// engancharse al mismo puerto (ver ONLINE.md).
const server = http.createServer(app);
void autenticarToken; // lo usará el servidor de partidas (ver ONLINE.md)

server.listen(config.puerto, () => {
  console.log(`Servidor Brilliant escuchando en el puerto ${config.puerto}`);
  if (!config.requireHttps) {
    console.warn('AVISO: HTTPS no es obligatorio. Úsalo solo en desarrollo.');
  }
});

function apagar() {
  server.close(() => {
    db.close();
    process.exit(0);
  });
}
process.on('SIGINT', apagar);
process.on('SIGTERM', apagar);
