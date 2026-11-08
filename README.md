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

En la partida cada uno juega **su propio tablero con los mismos dados**: pone sus 6 números
iniciales y en cada ronda coloca un número o pasa (60 s por ronda). El marcador muestra los puntos
y qué está haciendo cada jugador; tocando a alguien se ve su tablero. Se puede **rendir** en
cualquier momento. Al terminar aparecen los resultados y, si todos vuelven a pulsar "listo",
empieza la revancha.

Solo se puede tener **una sesión abierta por cuenta**: si la cuenta está abierta en otro
dispositivo, no deja entrar hasta que se cierre sesión allí. Si ese dispositivo se cerró sin salir
(o se perdió), la cuenta se libera sola en unos 2,5 minutos.

Para probarlo en una sola computadora, con **cuentas distintas** en Chrome y Edge:

```bash
# server/.env:  CORS_ORIGINS=http://localhost:5000,http://localhost:5001
cd server && dart run bin/server.dart            # terminal 1
flutter run -d chrome --web-port 5000            # terminal 2
flutter run -d edge --web-port 5001              # terminal 3
```

Detalles del protocolo en [`server/MULTIJUGADOR.md`](server/MULTIJUGADOR.md).

## Pruebas

```bash
cd server && dart test   # servidor: 72 pruebas
cd packages/brilliant_reglas && dart test   # reglas del juego: 9 pruebas
flutter test              # app: incluye test/auth/
```

## Cómo se guarda la sesión en la app

- El *access token* (15 min) vive solo en memoria.
- El *refresh token* se guarda con `flutter_secure_storage` (Keychain / Keystore) y se
  usa para continuar la sesión al reabrir la app. Cada uso lo rota el servidor.
- La contraseña nunca se guarda en el dispositivo.
