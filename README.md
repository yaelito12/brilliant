# Brilliant

Juego de tablero en Flutter con cuentas de usuario.

- **App (Flutter)**: carpeta raíz. Pantallas de crear cuenta, iniciar sesión, cerrar sesión y borrar cuenta.
- **Servidor de autenticación (Node.js)**: carpeta [`server/`](server/README.md). Programa aparte donde se registran los clientes.

## Cómo ejecutarlo

1. Servidor (ver `server/README.md` para el detalle):
   ```bash
   cd server && npm install && cp .env.example .env
   npm run gen-secret      # pega el resultado en JWT_SECRET dentro de .env
   npm start               # http://localhost:3000
   ```
2. App:
   ```bash
   flutter pub get
   flutter run                                          # escritorio / web / iOS simulator
   flutter run --dart-define=API_URL=http://10.0.2.2:3000   # emulador Android
   flutter run --dart-define=API_URL=https://api.tudominio.com   # producción (HTTPS)
   ```

## Pruebas

```bash
cd server && npm test     # servidor: 19 pruebas
flutter test              # app: incluye test/auth/
```

## Cómo se guarda la sesión en la app

- El *access token* (15 min) vive solo en memoria.
- El *refresh token* se guarda con `flutter_secure_storage` (Keychain / Keystore) y se
  usa para continuar la sesión al reabrir la app. Cada uso lo rota el servidor.
- La contraseña nunca se guarda en el dispositivo.
