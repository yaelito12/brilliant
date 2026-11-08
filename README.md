# Brilliant

Juego de tablero en Flutter con cuentas de usuario.

- **App (Flutter)**: carpeta raíz. Pantallas de crear cuenta, iniciar sesión, cerrar sesión y borrar cuenta.
- **Servidor (Dart)**: carpeta [`server/`](server/README.md). Programa aparte donde se registran los clientes.
- **Reglas del juego (Dart puro)**: carpeta [`packages/brilliant_reglas/`](packages/brilliant_reglas/). Tipos de zona, tablero, niveles y reglas de cada turno; las usan la app y el servidor, así el multijugador valida las jugadas con el mismo código.

## Cómo ejecutarlo

1. Servidor (ver `server/README.md` para el detalle):
   ```bash
   cd server && dart pub get && cp .env.example .env
   dart run bin/gen_secret.dart   # pega el resultado en JWT_SECRET dentro de .env
   dart run bin/server.dart       # http://localhost:3000
   ```
2. App:
   ```bash
   flutter pub get
   flutter run                                          # escritorio / web / iOS simulator
   flutter run --dart-define=API_URL=http://10.0.2.2:3000   # emulador Android
   flutter run --dart-define=API_URL=https://api.tudominio.com   # producción (HTTPS)
   ```

## Jugar en línea

Con la sesión iniciada, en el menú aparece **Jugar en línea**: se crea una sala (o se entra con
un código de 6 letras), cada jugador elige su mapa y la partida empieza cuando todos (2 a 6)
pulsan "Estoy listo". Si se corta la conexión, la app reconecta sola y vuelve a la sala.

Para probarlo en una sola computadora: arranca el servidor y abre dos copias de la app con
cuentas distintas (por ejemplo `flutter run -d windows` y `flutter run -d chrome`).
Detalles del protocolo en [`server/MULTIJUGADOR.md`](server/MULTIJUGADOR.md).

## Pruebas

```bash
cd server && dart test   # servidor: 57 pruebas
cd packages/brilliant_reglas && dart test   # reglas del juego: 9 pruebas
flutter test              # app: incluye test/auth/
```

## Cómo se guarda la sesión en la app

- El *access token* (15 min) vive solo en memoria.
- El *refresh token* se guarda con `flutter_secure_storage` (Keychain / Keystore) y se
  usa para continuar la sesión al reabrir la app. Cada uso lo rota el servidor.
- La contraseña nunca se guarda en el dispositivo.
